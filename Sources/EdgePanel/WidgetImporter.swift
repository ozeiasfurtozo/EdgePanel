import Foundation
import ZipInflate

enum WidgetImportError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let reason): return L("Widget inválido: \(reason)", "Invalid widget: \(reason)") }
    }
}

struct SafeZipEntry {
    let name: String
    let method: UInt16
    let compressedSize: Int
    let size: Int
    let crc: UInt32
    let dataOffset: Int
}

struct SafeZip {
    let data: Data
    let entries: [SafeZipEntry]

    init(data: Data) throws {
        guard data.count <= 25_000_000, data.count >= 22 else { throw WidgetImportError.invalid("archive size") }
        self.data = data
        func u16(_ p: Int) -> UInt16? {
            guard p >= 0, p + 2 <= data.count else { return nil }
            return UInt16(data[p]) | UInt16(data[p + 1]) << 8
        }
        func u32(_ p: Int) -> UInt32? {
            guard let low = u16(p), let high = u16(p + 2) else { return nil }
            return UInt32(low) | UInt32(high) << 16
        }
        let start = max(0, data.count - 65_557)
        guard let end = stride(from: data.count - 22, through: start, by: -1).first(where: { u32($0) == 0x06054b50 }),
              let count = u16(end + 10), let directorySize = u32(end + 12), let directoryOffset = u32(end + 16),
              u16(end + 4) == 0, u16(end + 6) == 0, u16(end + 8) == count,
              count > 0, count <= 128,
              Int(directoryOffset) + Int(directorySize) <= end else { throw WidgetImportError.invalid("ZIP directory") }
        var cursor = Int(directoryOffset)
        var parsed: [SafeZipEntry] = []
        var names = Set<String>()
        var totalSize = 0
        for _ in 0..<count {
            guard u32(cursor) == 0x02014b50,
                  let flags = u16(cursor + 8), flags & 1 == 0,
                  let method = u16(cursor + 10), method == 0 || method == 8,
                  let crc = u32(cursor + 16),
                  let compressed = u32(cursor + 20), let size = u32(cursor + 24),
                  let nameLength = u16(cursor + 28), let extraLength = u16(cursor + 30),
                  let commentLength = u16(cursor + 32),
                  let external = u32(cursor + 38), let localOffset = u32(cursor + 42) else {
                throw WidgetImportError.invalid("ZIP entry")
            }
            let nameStart = cursor + 46
            let next = nameStart + Int(nameLength) + Int(extraLength) + Int(commentLength)
            guard next <= Int(directoryOffset) + Int(directorySize),
                  let name = String(data: data[nameStart..<(nameStart + Int(nameLength))], encoding: .utf8),
                  Self.safePath(name), !names.contains(name),
                  size <= 10_000_000, compressed <= 10_000_000 else {
                throw WidgetImportError.invalid("ZIP path or size")
            }
            names.insert(name)
            totalSize += Int(size)
            guard totalSize <= 20_000_000 else { throw WidgetImportError.invalid("expanded size") }
            let fileType = (external >> 16) & 0o170000
            guard fileType == 0 || fileType == 0o100000 || (fileType == 0o040000 && name.hasSuffix("/")) else {
                throw WidgetImportError.invalid("symbolic links are not allowed")
            }
            let local = Int(localOffset)
            guard u32(local) == 0x04034b50,
                  let localName = u16(local + 26), let localExtra = u16(local + 28),
                  localName == nameLength,
                  local + 30 + Int(localName) + Int(localExtra) <= data.count,
                  String(data: data[(local + 30)..<(local + 30 + Int(localName))], encoding: .utf8) == name else {
                throw WidgetImportError.invalid("local ZIP header")
            }
            let dataOffset = local + 30 + Int(localName) + Int(localExtra)
            guard dataOffset + Int(compressed) <= Int(directoryOffset) else { throw WidgetImportError.invalid("ZIP payload") }
            if !name.hasSuffix("/") {
                parsed.append(SafeZipEntry(name: name, method: method, compressedSize: Int(compressed), size: Int(size), crc: crc, dataOffset: dataOffset))
            }
            cursor = next
        }
        guard cursor == Int(directoryOffset) + Int(directorySize), names.contains("manifest.json"), names.contains("index.html") else {
            throw WidgetImportError.invalid("manifest.json or index.html missing")
        }
        entries = parsed
    }

    static func safePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\"), !path.contains(":"),
              !path.unicodeScalars.contains(where: { $0.value < 32 }) else { return false }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        let body = path.hasSuffix("/") ? components.dropLast() : components.dropLast(0)
        return !body.isEmpty && body.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    func content(of entry: SafeZipEntry) throws -> Data {
        let bytes = data[entry.dataOffset..<(entry.dataOffset + entry.compressedSize)]
        let result: Data
        if entry.method == 0 {
            guard entry.size == bytes.count else { throw WidgetImportError.invalid("stored entry size") }
            result = Data(bytes)
        } else {
            guard entry.compressedSize > 0 else { throw WidgetImportError.invalid("empty DEFLATE payload") }
            var output = Data(count: max(1, entry.size))
            let rc = output.withUnsafeMutableBytes { out in
                bytes.withUnsafeBytes { input in
                    edge_inflate_raw(input.bindMemory(to: UInt8.self).baseAddress!, input.count,
                                     out.bindMemory(to: UInt8.self).baseAddress!, entry.size)
                }
            }
            guard rc == 0 else { throw WidgetImportError.invalid("DEFLATE data") }
            output.count = entry.size
            result = output
        }
        let checksum = result.withUnsafeBytes { raw in edge_crc32(raw.bindMemory(to: UInt8.self).baseAddress, result.count) }
        guard checksum == entry.crc else { throw WidgetImportError.invalid("CRC mismatch") }
        return result
    }
}

enum WidgetImporter {
    static let supportedControls: Set<String> = ["color", "textfield", "switch", "slider", "combobox", "tab-buttons", "sensors-combobox"]
    static let sensorPlugin = "widgetbuilder.sensorsdataprovider:Sensors:1.0"

    static func importFile(_ url: URL, into library: URL) throws -> ImportedWidget {
        guard url.pathExtension.lowercased() == "icuewidget" else { throw WidgetImportError.invalid(".icuewidget required") }
        let archive = try SafeZip(data: Data(contentsOf: url, options: .mappedIfSafe))
        let id = UUID()
        let pending = library.appendingPathComponent(".pending-\(id.uuidString)", isDirectory: true)
        let destination = library.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: pending, withIntermediateDirectories: true)
        do {
            for entry in archive.entries {
                let output = pending.appendingPathComponent(entry.name)
                try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
                try archive.content(of: entry).write(to: output, options: .atomic)
            }
            let manifestURL = pending.appendingPathComponent("manifest.json")
            let object = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL))
            guard let manifest = object as? [String: Any],
                  let name = manifest["name"] as? String, !name.isEmpty,
                  let author = manifest["author"] as? String,
                  let version = manifest["version"] as? String,
                  let supported = manifest["supported_devices"] as? [[String: Any]],
                  supported.contains(where: { $0["type"] as? String == "dashboard_lcd" }) else {
                throw WidgetImportError.invalid("manifest or device type")
            }
            let html = try String(contentsOf: pending.appendingPathComponent("index.html"), encoding: .utf8)
            guard html.range(of: "<head(?:\\s|>)", options: [.regularExpression, .caseInsensitive]) != nil else {
                throw WidgetImportError.invalid("HTML head missing")
            }
            var warnings: [String] = []
            let controls = parseControls(html)
            for control in controls where !supportedControls.contains(control.type) {
                warnings.append("Control \(control.type) unsupported")
            }
            let plugins = manifest["required_plugins"] as? [String] ?? []
            for plugin in plugins where plugin != sensorPlugin { warnings.append("Plugin \(plugin) unsupported") }
            let permissions = manifest["permissions"] as? [[String: Any]] ?? []
            var domains: [String] = []
            for permission in permissions {
                if permission["type"] as? String == "url", let domain = permission["domain"] as? String,
                   domain != "any", domain.range(of: "^[a-zA-Z0-9.-]+$", options: .regularExpression) != nil {
                    domains.append(domain.lowercased())
                } else { warnings.append("Permission \(permission["type"] ?? "unknown") unsupported") }
            }
            if let api = manifest["min_framework_version"] as? String,
               api.compare("1.6.0", options: .numeric) == .orderedDescending {
                warnings.append("Widget API \(api) is newer than supported 1.6.0")
            }
            try FileManager.default.moveItem(at: pending, to: destination)
            return ImportedWidget(id: id, name: name, author: author, version: version,
                                  requiredPlugins: plugins, requestedDomains: Array(Set(domains)).sorted(),
                                  allowedDomains: [], controls: controls, warnings: warnings,
                                  compatible: warnings.isEmpty)
        } catch {
            try? FileManager.default.removeItem(at: pending)
            throw error
        }
    }

    static func parseControls(_ html: String) -> [ImportedControl] {
        guard let attributes = try? NSRegularExpression(pattern: "([\\w-]+)\\s*=\\s*([\\\"'])(.*?)\\2", options: [.dotMatchesLineSeparators]) else { return [] }
        return metaTags(in: html).compactMap { fragment in
            let n = fragment as NSString
            var values: [String: String] = [:]
            for attr in attributes.matches(in: fragment, range: NSRange(location: 0, length: n.length)) {
                values[n.substring(with: attr.range(at: 1)).lowercased()] = n.substring(with: attr.range(at: 3))
            }
            guard values["name"] == "x-icue-property", let name = values["content"],
                  name.range(of: "^[A-Za-z_][A-Za-z0-9_]*$", options: .regularExpression) != nil,
                  let type = values["data-type"] else { return nil }
            return ImportedControl(name: name, type: type, label: values["data-label"] ?? name,
                                   defaultExpression: values["data-default"] ?? "undefined",
                                   optionsExpression: values["data-values"], minExpression: values["data-min"],
                                   maxExpression: values["data-max"])
        }
    }

    private static func metaTags(in html: String) -> [String] {
        var tags: [String] = []
        var search = html.startIndex
        while let start = html.range(of: "<meta", options: .caseInsensitive, range: search..<html.endIndex) {
            var cursor = start.upperBound
            var quote: Character?
            while cursor < html.endIndex {
                let char = html[cursor]
                if let current = quote {
                    if char == current { quote = nil }
                } else if char == "\"" || char == "'" {
                    quote = char
                } else if char == ">" {
                    tags.append(String(html[start.lowerBound...cursor]))
                    cursor = html.index(after: cursor)
                    break
                }
                cursor = html.index(after: cursor)
            }
            search = cursor
        }
        return tags
    }
}
