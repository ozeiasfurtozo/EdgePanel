import AppKit
import SwiftUI
import WebKit

private func jsonString(_ object: Any) -> String {
    guard JSONSerialization.isValidJSONObject(object),
          let data = try? JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed, .sortedKeys]),
          let string = String(data: data, encoding: .utf8) else { return "{}" }
    return string
}

private func safeDomain(_ domain: String) -> Bool {
    domain.range(of: "^[a-zA-Z0-9.-]+$", options: .regularExpression) != nil && !domain.contains("..")
}

struct ImportedWidgetView: NSViewRepresentable {
    let tile: Tile
    let imported: ImportedWidget
    let libraryURL: URL
    let deviceID: UUID
    let darkMode: Bool
    @ObservedObject var metrics: SystemMetrics

    func makeCoordinator() -> Coordinator { Coordinator(tileID: tile.id, importedID: imported.id, libraryURL: libraryURL) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.userContentController.add(context.coordinator, name: "storage")
        config.userContentController.addUserScript(WKUserScript(source: runtimeScript(), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.underPageBackgroundColor = backdropColor
        context.coordinator.widgetRoot = libraryURL.appendingPathComponent(imported.id.uuidString, isDirectory: true)
        context.coordinator.domains = Set(imported.allowedDomains.filter(safeDomain))
        context.coordinator.signature = signature
        if let entry = try? renderHTML() { view.loadFileURL(entry, allowingReadAccessTo: context.coordinator.widgetRoot!) }
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        view.underPageBackgroundColor = backdropColor
        context.coordinator.domains = Set(imported.allowedDomains.filter(safeDomain))
        if context.coordinator.signature != signature {
            context.coordinator.signature = signature
            if let entry = try? renderHTML() { view.loadFileURL(entry, allowingReadAccessTo: context.coordinator.widgetRoot!) }
        }
        let payload = jsonString(["mac.cpu.load": String(format: "%.1f", metrics.cpuPercent),
                                  "mac.memory.load": String(format: "%.1f", metrics.memoryPercent)])
        view.evaluateJavaScript("window.__edgePanelUpdateSensors && window.__edgePanelUpdateSensors(\(payload));", completionHandler: nil)
    }

    private var signature: String {
        let settings = tile.settings.filter { !$0.key.hasPrefix("_ls:") }
        return jsonString(settings) + imported.allowedDomains.sorted().joined(separator: ",") + String(darkMode)
    }

    private var backdropColor: NSColor {
        darkMode ? NSColor(srgbRed: 0.035, green: 0.055, blue: 0.09, alpha: 1)
                 : NSColor(srgbRed: 0.91, green: 0.94, blue: 0.97, alpha: 1)
    }

    private func renderHTML() throws -> URL {
        let root = libraryURL.appendingPathComponent(imported.id.uuidString, isDirectory: true)
        let source = try String(contentsOf: root.appendingPathComponent("index.html"), encoding: .utf8)
        let domains = imported.allowedDomains.filter(safeDomain).map { "https://\($0) https://*.\($0)" }.joined(separator: " ")
        let policy = "default-src 'self' data: blob:; script-src 'self' 'unsafe-inline' 'unsafe-eval' \(domains); style-src 'self' 'unsafe-inline' \(domains); img-src 'self' data: blob: \(domains); connect-src 'self' \(domains); frame-src \(domains); media-src 'self' data: blob: \(domains); object-src 'none'; form-action 'none'; base-uri 'none'"
        let escapedPolicy = policy.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;")
        let meta = "<meta http-equiv=\"Content-Security-Policy\" content=\"\(escapedPolicy)\">"
        // Transparent widget pages should reveal the panel, never WebKit's white canvas.
        // An explicit package body background still paints over this HTML backdrop.
        let backdrop = darkMode ? "#090E17" : "#E8F0F7"
        let style = "<style>html { background-color: \(backdrop) !important; }</style>"
        let html: String
        guard let range = source.range(of: "<head(?:\\s[^>]*)?>", options: [.regularExpression, .caseInsensitive]) else {
            throw WidgetImportError.invalid("HTML head missing")
        }
        html = source.replacingCharacters(in: range, with: String(source[range]) + meta + style)
        let url = root.appendingPathComponent(".edgepanel-\(tile.id.uuidString).html")
        try html.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func runtimeScript() -> String {
        let root = libraryURL.appendingPathComponent(imported.id.uuidString, isDirectory: true)
        let translationURL = root.appendingPathComponent("translation.json")
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        var translation: [String: String] = [:]
        if let data = try? Data(contentsOf: translationURL),
           let table = try? JSONSerialization.jsonObject(with: data) as? [String: [String: [String: String]]] {
            translation = table[language]?["translation"] ?? table["en"]?["translation"] ?? [:]
        }
        let savedStorage = (try? Data(contentsOf: Coordinator.storageURL(tileID: tile.id, importedID: imported.id, libraryURL: libraryURL)))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] } ?? [:]
        let definitions = imported.controls.map { ["name": $0.name, "type": $0.type, "expression": $0.defaultExpression] }
        let settings = tile.settings.filter { !$0.key.hasPrefix("_ls:") }
        let script = #"""
        (() => {
          const definitions = __DEFINITIONS__;
          const saved = __SETTINGS__;
          const language = __LANGUAGE__;
          const translations = __TRANSLATIONS__;
          const sensorValues = {"mac.cpu.load":"0", "mac.memory.load":"0"};
          const sensorIds = ["mac.cpu.load", "mac.memory.load"];
          const signals = () => { const listeners=[]; return {connect(fn){if(typeof fn==='function') listeners.push(fn);},disconnect(fn){const i=listeners.indexOf(fn);if(i>=0)listeners.splice(i,1);},emit(...args){listeners.slice().forEach(fn=>{try{fn(...args)}catch(e){console.error(e)}})}}; };
          const asyncResponse=signals(), sensorValueChanged=signals(), sensorAdded=signals(), sensorRemoved=signals(), sensorDataChanged=signals(), sensorUnitsChanged=signals();
          function sensorMeta(id) { return id === "mac.cpu.load" ? {name:"Mac CPU",kind:"package"} : id === "mac.memory.load" ? {name:"Mac Memory",kind:"memory-load"} : null; }
          function reply(requestId,value) { setTimeout(()=>asyncResponse.emit(requestId,value),0); }
          function defaultSensor(type,kind) { if(type !== 'load')return ''; return kind === 'memory-load' ? 'mac.memory.load' : 'mac.cpu.load'; }
          const sensors = {
            asyncResponse,sensorValueChanged,sensorAdded,sensorRemoved,sensorDataChanged,sensorUnitsChanged,
            getAllSensorIds(id){reply(id,sensorIds.slice())},
            getSensorValue(id,s){reply(id,sensorValues[s] ?? '')},
            getSensorUnits(id,s){reply(id,sensorMeta(s) ? '%' : '')},
            getSensorName(id,s){reply(id,sensorMeta(s)?.name ?? '')},
            getSensorDeviceName(id,s){reply(id,sensorMeta(s) ? 'Mac' : '')},
            getSensorType(id,s){reply(id,sensorMeta(s) ? 'load' : '')},
            getSensorKind(id,s){reply(id,sensorMeta(s)?.kind ?? '')},
            sensorIsConnected(id,s){reply(id,!!sensorMeta(s))},
            getDefaultSensorId(id,type,kind){reply(id,defaultSensor(type,kind))},
            getDefaultSensorIdBlock(type,kind){return defaultSensor(type,kind)}
          };
          window.__edgePanelUpdateSensors = values => {
            for(const id of sensorIds) if(values[id] !== undefined && values[id] !== sensorValues[id]) {
              sensorValues[id] = String(values[id]); sensorValueChanged.emit(id,sensorValues[id]); sensorDataChanged.emit(id);
            }
          };
          window.plugins = {Sensorsdataprovider:sensors};
          window.pluginSensorsdataprovider_initialized = false;
          window.tr = key => Promise.resolve(translations[key] ?? key);
          window.iCUE = {iCUELanguage:language,fpsLimit:30,isPreview:false,defaultTemperatureUnit(){return '°C'}};
          window.device = {deviceId:__DEVICE_ID__};
          window.uniqueId = __UNIQUE_ID__;
          window.iCUE_initialized = false;
          const storage = {...__STORAGE__};
          const local = {
            get length(){return Object.keys(storage).length},
            key(i){return Object.keys(storage)[i] ?? null},
            getItem(k){return Object.prototype.hasOwnProperty.call(storage,String(k)) ? storage[String(k)] : null},
            setItem(k,v){k=String(k);v=String(v);storage[k]=v;window.webkit.messageHandlers.storage.postMessage({action:'set',key:k,value:v})},
            removeItem(k){k=String(k);delete storage[k];window.webkit.messageHandlers.storage.postMessage({action:'remove',key:k})},
            clear(){for(const k of Object.keys(storage))delete storage[k];window.webkit.messageHandlers.storage.postMessage({action:'clear'})}
          };
          try { Object.defineProperty(window,'localStorage',{value:local,configurable:false}); } catch(e) { console.warn('localStorage shim unavailable',e); }
          function evaluate(expression) {try{return Function('return ('+expression+')')()}catch(e){return undefined}}
          for(const control of definitions) {
            let value=Object.prototype.hasOwnProperty.call(saved,control.name) ? saved[control.name] : evaluate(control.expression);
            if(control.type==='switch') value=(value===true || value==='true');
            if(control.type==='slider') value=Number(value)||0;
            window[control.name]=value;
          }
          window.addEventListener('DOMContentLoaded', () => {
            window.iCUE_initialized = true;
            window.pluginSensorsdataprovider_initialized = true;
            try { window.icueEvents?.onICUEInitialized?.(); window.icueEvents?.onDataUpdated?.(); } catch(e) { console.error(e); }
            try { window.pluginSensorsdataproviderEvents?.onInitialized?.(); } catch(e) { console.error(e); }
          }, {once:true});
        })();
        """#
        let values = [
            "__DEFINITIONS__": jsonString(definitions),
            "__SETTINGS__": jsonString(settings),
            "__LANGUAGE__": String(jsonString([language]).dropFirst().dropLast()),
            "__TRANSLATIONS__": jsonString(translation),
            "__STORAGE__": jsonString(savedStorage),
            "__DEVICE_ID__": "\"\(deviceID.uuidString.lowercased())\"",
            "__UNIQUE_ID__": "\"\(tile.id.uuidString)\""
        ]
        guard let pattern = try? NSRegularExpression(pattern: "__[A-Z_]+__") else { return script }
        let ns = script as NSString
        var output = ""
        var cursor = 0
        for match in pattern.matches(in: script, range: NSRange(location: 0, length: ns.length)) {
            output += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let token = ns.substring(with: match.range)
            output += values[token] ?? token
            cursor = match.range.location + match.range.length
        }
        output += ns.substring(from: cursor)
        return output
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let tileID: UUID
        let importedID: UUID
        let libraryURL: URL
        var widgetRoot: URL?
        var domains = Set<String>()
        var signature = ""

        init(tileID: UUID, importedID: UUID, libraryURL: URL) {
            self.tileID = tileID; self.importedID = importedID; self.libraryURL = libraryURL
        }

        static func storageURL(tileID: UUID, importedID: UUID, libraryURL: URL) -> URL {
            libraryURL.deletingLastPathComponent()
                .appendingPathComponent("WidgetStorage", isDirectory: true)
                .appendingPathComponent("\(tileID.uuidString).json")
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, message.name == "storage", let body = message.body as? [String: String],
                  let action = body["action"] else { return }
            let url = Self.storageURL(tileID: tileID, importedID: importedID, libraryURL: libraryURL)
            var storage = (try? Data(contentsOf: url)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] } ?? [:]
            switch action {
            case "set":
                guard let key = body["key"], key.count <= 256, let value = body["value"], value.utf8.count <= 100_000 else { return }
                storage[key] = value
            case "remove": if let key = body["key"] { storage.removeValue(forKey: key) }
            case "clear": storage.removeAll()
            default: return
            }
            guard let data = try? JSONSerialization.data(withJSONObject: storage), data.count <= 1_000_000 else { return }
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
            if url.isFileURL, let root = widgetRoot, url.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path + "/") {
                decisionHandler(.allow); return
            }
            if url.scheme == "about" { decisionHandler(.allow); return }
            if navigationAction.targetFrame?.isMainFrame == false, url.scheme == "https", let host = url.host?.lowercased(),
               domains.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
                decisionHandler(.allow); return
            }
            decisionHandler(.cancel)
        }
    }
}

final class DashboardWebView: WKWebView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

struct WebTileView: NSViewRepresentable {
    let urlString: String

    final class Coordinator {
        var configuredURLString: String?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> DashboardWebView {
        let view = DashboardWebView()
        view.underPageBackgroundColor = .clear
        loadConfiguredURL(in: view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ view: DashboardWebView, context: Context) {
        loadConfiguredURL(in: view, coordinator: context.coordinator)
    }

    private func loadConfiguredURL(in view: DashboardWebView, coordinator: Coordinator) {
        guard coordinator.configuredURLString != urlString else { return }
        coordinator.configuredURLString = urlString
        guard let url = URL(string: urlString), ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return }
        view.load(URLRequest(url: url))
    }
}
