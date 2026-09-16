import AppKit
import ApplicationServices
import SwiftUI
import UniformTypeIdentifiers

enum DeckAction: String, Codable, CaseIterable, Identifiable {
    case none, application, url, shortcut, keyChord, keySequence, page
    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return L("Nenhuma", "None")
        case .application: return L("Abrir aplicativo", "Open application")
        case .url: return L("Abrir URL", "Open URL")
        case .shortcut: return L("Atalho do macOS", "macOS Shortcut")
        case .keyChord: return L("Combinação de teclas", "Keyboard shortcut")
        case .keySequence: return L("Sequência de teclas", "Key sequence")
        case .page: return L("Mudar página", "Switch page")
        }
    }
}

enum DeckIcon: String, Codable, CaseIterable, Identifiable {
    case symbol, application, image
    var id: String { rawValue }
    var title: String {
        switch self {
        case .symbol: return L("Símbolo", "Symbol")
        case .application: return L("Ícone do app", "App icon")
        case .image: return L("Imagem", "Image")
        }
    }
}

struct DeckStroke: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt
    var keyName: String

    init(keyCode: UInt16, modifiers: UInt, keyName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyName = keyName
    }

    init(event: NSEvent) {
        keyCode = event.keyCode
        modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift]).rawValue
        keyName = (event.charactersIgnoringModifiers ?? "").uppercased()
    }

    var label: String {
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        let special: [UInt16: String] = [36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "Esc",
                                         123: "←", 124: "→", 125: "↓", 126: "↑"]
        return result + (special[keyCode] ?? (keyName.isEmpty ? "Key \(keyCode)" : keyName))
    }

    var eventFlags: CGEventFlags {
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        var result: CGEventFlags = []
        if flags.contains(.control) { result.insert(.maskControl) }
        if flags.contains(.option) { result.insert(.maskAlternate) }
        if flags.contains(.shift) { result.insert(.maskShift) }
        if flags.contains(.command) { result.insert(.maskCommand) }
        return result
    }
}

struct DeckButton: Codable, Equatable, Identifiable {
    var id = UUID()
    var name = ""
    var action: DeckAction = .none
    var value = ""
    var strokes: [DeckStroke] = []
    var icon: DeckIcon = .symbol
    var iconValue = "bolt.fill"
    var colorHex: String? = nil
}

enum DeckSettings {
    static let key = "actionDeckButtons"
    static let symbols = ["bolt.fill", "app.fill", "globe", "play.fill", "pause.fill", "stop.fill",
                          "music.note", "speaker.wave.2.fill", "mic.fill", "camera.fill", "video.fill",
                          "folder.fill", "terminal.fill", "keyboard", "link", "star.fill", "heart.fill",
                          "lightbulb.fill", "moon.fill", "sun.max.fill", "timer", "clock.fill",
                          "envelope.fill", "message.fill", "square.grid.2x2.fill", "arrow.right.circle.fill"]
    private static let automaticColors: [Color] = [
        Color(red: 0.08, green: 0.70, blue: 0.69), Color(red: 0.85, green: 0.37, blue: 0.19),
        Color(red: 0.36, green: 0.42, blue: 0.88), Color(red: 0.15, green: 0.55, blue: 0.91),
        Color(red: 0.74, green: 0.28, blue: 0.57), Color(red: 0.43, green: 0.69, blue: 0.19),
        Color(red: 0.85, green: 0.59, blue: 0.17), Color(red: 0.27, green: 0.63, blue: 0.77)
    ]

    static func automaticColor(index: Int, active: Bool) -> Color {
        active ? automaticColors[index % automaticColors.count] :
            Color(red: 0.075, green: 0.105, blue: 0.13)
    }

    static func buttons(_ settings: [String: String]) -> [DeckButton] {
        if let json = settings[key], let data = json.data(using: .utf8),
           let stored = try? JSONDecoder().decode([DeckButton].self, from: data) {
            return Array(stored.prefix(32))
        }
        return (0..<16).map { index in
            var button = DeckButton()
            button.iconValue = symbols[index % symbols.count]
            return button
        }
    }

    static func save(_ buttons: [DeckButton], to settings: inout [String: String]) {
        guard let data = try? JSONEncoder().encode(Array(buttons.prefix(32))),
              let json = String(data: data, encoding: .utf8) else { return }
        settings[key] = json
    }

    static func visibleCount(_ settings: [String: String]) -> Int {
        min(32, max(4, Int(settings["deckVisibleCount"] ?? "16") ?? 16))
    }

    static func columns(_ settings: [String: String], width: CGFloat, editing: Bool = false) -> Int {
        let preferred = min(8, max(2, Int(settings["deckColumns"] ?? "8") ?? 8))
        return min(preferred, max(2, Int(width / (editing ? 50 : 72))))
    }
}

struct DeckGridLayout {
    let columns: Int
    let rows: Int
    let side: CGFloat
    let spacing: CGFloat
    let width: CGFloat
    let height: CGFloat

    init(count: Int, settings: [String: String], available: CGSize, editing: Bool) {
        columns = DeckSettings.columns(settings, width: available.width, editing: editing)
        rows = Int(ceil(Double(count) / Double(columns)))
        let shortestEdge = min(available.width, available.height)
        spacing = min(editing ? 8 : 16, max(1, shortestEdge / 20))
        let margin = min(editing ? 8 : 22, max(0, shortestEdge / 12))
        let byWidth = (available.width - margin * 2 - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        let byHeight = (available.height - margin * 2 - CGFloat(rows - 1) * spacing) / CGFloat(rows)
        side = max(1, min(210, byWidth, byHeight))
        width = CGFloat(columns) * side + CGFloat(columns - 1) * spacing
        height = CGFloat(rows) * side + CGFloat(rows - 1) * spacing
    }
}

extension PanelStore {
    var actionIconsURL: URL { root.appendingPathComponent("ActionIcons", isDirectory: true) }

    func importActionIcon(_ url: URL) throws -> String {
        let limit = 5_000_000
        let ext = url.pathExtension.lowercased()
        guard ["png", "jpg", "jpeg", "heic", "webp", "gif", "tiff"].contains(ext),
              let image = NSImage(contentsOf: url), image.size.width > 0, image.size.height > 0,
              let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= limit else {
            throw NSError(domain: "EdgePanel", code: 1, userInfo: [NSLocalizedDescriptionKey:
                L("Escolha uma imagem válida de até 5 MB.", "Choose a valid image up to 5 MB.")])
        }
        try FileManager.default.createDirectory(at: actionIconsURL, withIntermediateDirectories: true)
        let filename = "\(UUID().uuidString).\(ext)"
        try FileManager.default.copyItem(at: url, to: actionIconsURL.appendingPathComponent(filename))
        return filename
    }

    func actionIcon(named filename: String) -> NSImage? {
        guard filename.range(of: "^[0-9A-Fa-f-]{36}\\.(png|jpg|jpeg|heic|webp|gif|tiff)$",
                             options: .regularExpression) != nil else { return nil }
        return NSImage(contentsOf: actionIconsURL.appendingPathComponent(filename))
    }
}

@MainActor enum DeckRunner {
    private static func fail(_ message: String, model: AppModel) {
        model.message = message
        model.deckMessage = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if model.deckMessage == message { model.deckMessage = "" }
        }
    }

    static func run(_ button: DeckButton, model: AppModel) {
        switch button.action {
        case .none: break
        case .application:
            let url = URL(fileURLWithPath: button.value)
            guard url.pathExtension.lowercased() == "app", FileManager.default.fileExists(atPath: url.path) else {
                fail(L("Aplicativo não encontrado.", "Application not found."), model: model); return
            }
            if !NSWorkspace.shared.open(url) { fail(L("Não foi possível abrir o aplicativo.", "Could not open the application."), model: model) }
        case .url:
            guard let url = URL(string: button.value), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  url.host != nil else {
                fail(L("URL inválida. Use http ou https.", "Invalid URL. Use http or https."), model: model); return
            }
            if !NSWorkspace.shared.open(url) { fail(L("Não foi possível abrir a URL.", "Could not open the URL."), model: model) }
        case .shortcut:
            let name = button.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { fail(L("Escolha um Atalho.", "Choose a Shortcut."), model: model); return }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", name]
            process.terminationHandler = { finished in
                if finished.terminationStatus != 0 {
                    Task { @MainActor in fail(L("O Atalho falhou ou não foi encontrado.", "The Shortcut failed or was not found."), model: model) }
                }
            }
            do { try process.run() }
            catch { fail(error.localizedDescription, model: model) }
        case .page:
            guard let id = UUID(uuidString: button.value) else { return }
            model.selectPage(id)
        case .keyChord, .keySequence:
            guard !button.strokes.isEmpty else { return }
            guard AXIsProcessTrusted() else {
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(options)
                fail(L("Ative Acessibilidade para enviar teclas.", "Enable Accessibility to send keystrokes."), model: model)
                return
            }
            guard let app = model.lastExternalApplication, !app.isTerminated,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else {
                fail(L("Abra um aplicativo de destino antes de usar este botão.",
                       "Open a target application before using this button."), model: model)
                return
            }
            guard app.activate() else {
                fail(L("Não foi possível ativar o aplicativo de destino.",
                       "Could not activate the target application."), model: model)
                return
            }
            let strokes = button.action == .keyChord ? Array(button.strokes.prefix(1)) : button.strokes
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else {
                    fail(L("O aplicativo de destino não recebeu foco.", "The target application did not gain focus."), model: model)
                    return
                }
                let source = CGEventSource(stateID: .hidSystemState)
                for stroke in strokes {
                    guard let down = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode, keyDown: true),
                          let up = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode, keyDown: false) else { break }
                    down.flags = stroke.eventFlags
                    up.flags = stroke.eventFlags
                    down.post(tap: .cghidEventTap)
                    up.post(tap: .cghidEventTap)
                    try? await Task.sleep(nanoseconds: 130_000_000)
                }
            }
        }
    }
}

struct DeckButtonIcon: View {
    let button: DeckButton
    let store: PanelStore

    var body: some View {
        Group {
            if button.icon == .application, button.action == .application,
               FileManager.default.fileExists(atPath: button.value) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: button.value)).resizable().scaledToFit()
            } else if button.icon == .image, let image = store.actionIcon(named: button.iconValue) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: button.icon == .symbol ? button.iconValue : "bolt.fill")
                    .resizable().scaledToFit().symbolRenderingMode(.hierarchical)
            }
        }
    }
}

private struct DeckButtonCell: View {
    let button: DeckButton
    let index: Int
    let side: CGFloat
    let editing: Bool
    let store: PanelStore
    let action: () -> Void

    private var customColor: HexColor? { HexColor(hex: button.colorHex) }

    var body: some View {
        let radius = side * 0.17
        let bezel = min(max(3, side * 0.055), side * 0.22)
        return Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: radius)
                    .fill(LinearGradient(colors: [Color(red: 0.32, green: 0.38, blue: 0.42),
                                                 Color(red: 0.09, green: 0.12, blue: 0.15),
                                                 Color(red: 0.015, green: 0.025, blue: 0.035)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                DeckKeyFace(button: button, index: index, side: side - bezel * 2,
                            editing: editing, store: store)
                    .padding(bezel)
            }
            .frame(width: side, height: side)
            .overlay(RoundedRectangle(cornerRadius: radius)
                .strokeBorder(customColor?.color.opacity(0.75) ?? Color.white.opacity(0.17),
                              lineWidth: max(1, side * 0.012)))
            .shadow(color: .black.opacity(0.70), radius: max(4, side * 0.08), y: max(3, side * 0.055))
        }
        .buttonStyle(DeckKeyPressStyle())
        .disabled(!editing && button.action == .none)
        .accessibilityLabel(button.name.isEmpty ? L("Botão \(index + 1)", "Button \(index + 1)") : button.name)
    }
}

private struct DeckKeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct DeckKeyFace: View {
    let button: DeckButton
    let index: Int
    let side: CGFloat
    let editing: Bool
    let store: PanelStore

    private var active: Bool { button.action != .none }
    private var customColor: HexColor? { HexColor(hex: button.colorHex) }
    private var faceColor: Color { customColor?.color ?? DeckSettings.automaticColor(index: index, active: active) }
    private var iconColor: Color { customColor?.isLight == true ? Color.black.opacity(0.82) : .white }

    var body: some View {
        let radius = side * 0.14
        ZStack {
            RoundedRectangle(cornerRadius: radius)
                .fill(faceColor.gradient)
            artwork
            LinearGradient(colors: [.white.opacity(active ? 0.20 : 0.06), .clear, .black.opacity(0.25)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .allowsHitTesting(false)
            if !button.name.isEmpty {
                VStack {
                    Spacer(minLength: 0)
                    Text(button.name)
                        .font(.system(size: max(9, min(17, side * 0.13)), weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.9), radius: 3, y: 1)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, side * 0.05)
                        .padding(.vertical, side * 0.055)
                        .background(LinearGradient(colors: [.clear, .black.opacity(0.60)],
                                                   startPoint: .top, endPoint: .bottom))
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .overlay(RoundedRectangle(cornerRadius: radius)
            .strokeBorder(Color.white.opacity(active ? 0.25 : 0.10), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: radius)
            .strokeBorder(Color.black.opacity(0.45), lineWidth: max(1, side * 0.035))
            .padding(1))
    }

    @ViewBuilder private var artwork: some View {
        if button.icon == .image, let image = store.actionIcon(named: button.iconValue) {
            Image(nsImage: image).resizable().scaledToFill()
                .frame(width: side, height: side).clipped()
        } else if button.icon == .application, button.action == .application,
                  FileManager.default.fileExists(atPath: button.value) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: button.value))
                .resizable().scaledToFit()
                .frame(width: side * 0.76, height: side * 0.76)
        } else if active {
            Image(systemName: button.icon == .symbol ? button.iconValue : "bolt.fill")
                .resizable().scaledToFit().symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconColor)
                .frame(width: side * 0.50, height: side * 0.50)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
        } else if editing {
            Image(systemName: "plus")
                .font(.system(size: side * 0.27, weight: .ultraLight))
                .foregroundStyle(iconColor.opacity(0.28))
        }
    }
}

struct ActionDeckTile: View {
    @ObservedObject var model: AppModel
    let tile: Tile
    let editing: Bool

    var body: some View {
        GeometryReader { geometry in
            let buttons = DeckSettings.buttons(tile.settings)
            let count = DeckSettings.visibleCount(tile.settings)
            let layout = DeckGridLayout(count: count, settings: tile.settings,
                                        available: geometry.size, editing: editing)
            ZStack {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(layout.side), spacing: layout.spacing),
                                                 count: layout.columns), spacing: layout.spacing) {
                    ForEach(0..<count, id: \.self) { index in
                        let button = index < buttons.count ? buttons[index] : DeckButton()
                        DeckButtonCell(button: button, index: index, side: layout.side,
                                       editing: editing, store: model.store) {
                            if editing { model.selectedTileID = tile.id }
                            else { DeckRunner.run(button, model: model) }
                        }
                    }
                }
                .frame(width: layout.width)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlay(alignment: .bottom) {
                if !editing && !model.deckMessage.isEmpty {
                    Text(model.deckMessage)
                        .font(.caption.weight(.medium))
                        .padding(10)
                        .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 9))
                        .foregroundStyle(.white)
                        .padding(16)
                }
            }
        }
    }
}

struct ActionDeckEditor: View {
    @ObservedObject var model: AppModel
    let tile: Tile
    @State private var selectedIndex = 0
    @State private var recording = false
    @State private var keyMonitor: Any?
    @State private var availableShortcuts: [String] = []

    private var buttons: [DeckButton] { DeckSettings.buttons(model.currentPage?.tiles.first(where: { $0.id == tile.id })?.settings ?? tile.settings) }
    private var button: DeckButton { selectedIndex < buttons.count ? buttons[selectedIndex] : DeckButton() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text(L("Botões", "Buttons")).font(.headline)
            HStack {
                Picker(L("Visíveis", "Visible"), selection: setting("deckVisibleCount", default: "16")) {
                    ForEach([4, 8, 12, 15, 16, 20, 24, 32], id: \.self) { count in Text("\(count)").tag(String(count)) }
                }
                Picker(L("Colunas", "Columns"), selection: setting("deckColumns", default: "8")) {
                    ForEach([2, 4, 5, 6, 8], id: \.self) { count in Text("\(count)").tag(String(count)) }
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(0..<DeckSettings.visibleCount(tile.settings), id: \.self) { index in
                    Button {
                        stopRecording()
                        selectedIndex = index
                    } label: {
                        VStack(spacing: 3) {
                            DeckButtonIcon(button: index < buttons.count ? buttons[index] : DeckButton(), store: model.store)
                                .frame(width: 20, height: 20)
                            Text(index < buttons.count && !buttons[index].name.isEmpty ? buttons[index].name : "\(index + 1)")
                                .lineLimit(1).font(.caption2)
                        }
                        .frame(maxWidth: .infinity).frame(height: 49)
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedIndex == index ? .cyan : .gray)
                }
            }
            Text(L("Botão \(selectedIndex + 1)", "Button \(selectedIndex + 1)"))
                .font(.subheadline.weight(.semibold))
            TextField(L("Nome", "Name"), text: buttonText(\.name)).textFieldStyle(.roundedBorder)
            HStack {
                ColorPicker(L("Cor do botão", "Button color"), selection: Binding(
                    get: { HexColor(hex: button.colorHex)?.color ??
                        DeckSettings.automaticColor(index: selectedIndex, active: button.action != .none) },
                    set: { color in updateButton { $0.colorHex = color.hexString } }
                ), supportsOpacity: false)
                TextField("#RRGGBB", text: buttonColor)
                    .frame(width: 95)
            }
            if button.colorHex != nil {
                Button(L("Usar cor automática", "Use automatic color")) {
                    updateButton { $0.colorHex = nil }
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            Picker(L("Ação", "Action"), selection: Binding(
                get: { button.action }, set: { action in updateButton { $0.action = action; $0.value = ""; $0.strokes = [] } }
            )) {
                ForEach(DeckAction.allCases) { action in Text(action.title).tag(action) }
            }
            .pickerStyle(.menu)
            actionFields
            Picker(L("Ícone", "Icon"), selection: Binding(
                get: { button.icon }, set: { icon in updateButton { $0.icon = icon; if icon == .symbol { $0.iconValue = "bolt.fill" } } }
            )) {
                ForEach(DeckIcon.allCases) { icon in Text(icon.title).tag(icon) }
            }
            .pickerStyle(.segmented)
            if button.icon == .symbol {
                Picker(L("Símbolo", "Symbol"), selection: buttonText(\.iconValue)) {
                    ForEach(DeckSettings.symbols, id: \.self) { symbol in
                        Label(symbol, systemImage: symbol).tag(symbol)
                    }
                }.pickerStyle(.menu)
            } else if button.icon == .image {
                HStack {
                    DeckButtonIcon(button: button, store: model.store).frame(width: 26, height: 26)
                    Button(L("Escolher imagem…", "Choose image…")) { chooseImage() }
                }
            } else if button.action != .application {
                Text(L("Selecione a ação Aplicativo para usar seu ícone.", "Choose the Application action to use its icon."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onDisappear { stopRecording() }
        .onAppear { loadShortcuts() }
        .onChange(of: DeckSettings.visibleCount(tile.settings)) { _, count in
            if selectedIndex >= count { selectedIndex = count - 1 }
        }
    }

    @ViewBuilder private var actionFields: some View {
        switch button.action {
        case .none: Text(L("Escolha uma ação para ativar este botão.", "Choose an action to enable this button."))
                .font(.caption).foregroundStyle(.secondary)
        case .application:
            HStack {
                Text(button.value.isEmpty ? L("Nenhum app", "No app") : URL(fileURLWithPath: button.value).deletingPathExtension().lastPathComponent)
                    .lineLimit(1).font(.caption)
                Spacer()
                Button(L("Escolher…", "Choose…")) { chooseApplication() }
            }
        case .url:
            TextField("https://example.com", text: buttonText(\.value)).textFieldStyle(.roundedBorder)
            Button(L("Colar URL", "Paste URL")) {
                if let text = NSPasteboard.general.string(forType: .string) { updateButton { $0.value = text.trimmingCharacters(in: .whitespacesAndNewlines) } }
            }.buttonStyle(.link)
        case .shortcut:
            if !availableShortcuts.isEmpty {
                Picker(L("Atalho instalado", "Installed Shortcut"), selection: buttonText(\.value)) {
                    Text(L("Escolha…", "Choose…")).tag("")
                    ForEach(availableShortcuts, id: \.self) { name in Text(name).tag(name) }
                }.pickerStyle(.menu)
            }
            TextField(L("Nome exato do Atalho", "Exact Shortcut name"), text: buttonText(\.value))
                .textFieldStyle(.roundedBorder)
            Text(L("Crie o Atalho no app Atalhos do macOS; o nome deve corresponder.",
                   "Create the Shortcut in the macOS Shortcuts app; the name must match."))
                .font(.caption).foregroundStyle(.secondary)
        case .keyChord, .keySequence:
            Text(button.strokes.map(\.label).joined(separator: " → ").isEmpty ? L("Nenhuma tecla gravada", "No keys recorded") : button.strokes.map(\.label).joined(separator: " → "))
                .font(.caption.monospaced()).textSelection(.enabled)
            HStack {
                Button(recording ? L("Concluir", "Done") : L("Gravar teclas", "Record keys")) {
                    if recording { stopRecording() } else { startRecording() }
                }
                if !button.strokes.isEmpty {
                    Button(L("Limpar", "Clear")) { updateButton { $0.strokes = [] } }
                }
            }
            if recording {
                Text(button.action == .keyChord ? L("Pressione a combinação. Esc cancela.", "Press the shortcut. Esc cancels.") :
                        L("Pressione as teclas em ordem; clique Concluir ao terminar. Esc cancela.",
                          "Press keys in order; click Done when finished. Esc cancels."))
                    .font(.caption).foregroundStyle(.orange)
            }
            Text(L("As teclas são enviadas ao último aplicativo ativo. Requer Acessibilidade.",
                   "Keys go to the last active application. Accessibility is required."))
                .font(.caption).foregroundStyle(.secondary)
        case .page:
            if let profile = model.config.profiles.first(where: { $0.id == model.config.selectedProfileID }) {
                Picker(L("Página", "Page"), selection: buttonText(\.value)) {
                    Text(L("Escolha…", "Choose…")).tag("")
                    ForEach(profile.pages) { page in Text(page.name).tag(page.id.uuidString) }
                }
            }
        }
    }

    private func setting(_ key: String, default fallback: String) -> Binding<String> {
        Binding(get: { model.currentPage?.tiles.first(where: { $0.id == tile.id })?.settings[key] ?? fallback },
                set: { value in model.updateTile(tile.id) { $0.settings[key] = value } })
    }

    private func buttonText(_ keyPath: WritableKeyPath<DeckButton, String>) -> Binding<String> {
        Binding(get: { button[keyPath: keyPath] }, set: { value in updateButton { $0[keyPath: keyPath] = value } })
    }

    private var buttonColor: Binding<String> {
        Binding(get: { button.colorHex ?? "" },
                set: { value in updateButton { $0.colorHex = value.isEmpty ? nil : value } })
    }

    private func updateButton(_ edit: (inout DeckButton) -> Void) {
        model.updateTile(tile.id) { updated in
            var all = DeckSettings.buttons(updated.settings)
            while all.count <= selectedIndex { all.append(DeckButton()) }
            edit(&all[selectedIndex])
            DeckSettings.save(all, to: &updated.settings)
        }
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            updateButton { $0.value = url.path; if $0.name.isEmpty { $0.name = url.deletingPathExtension().lastPathComponent }; $0.icon = .application }
        }
    }

    private func loadShortcuts() {
        Task.detached {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["list"]
            process.standardOutput = pipe
            process.standardError = Pipe()
            guard (try? process.run()) != nil else { return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0, let output = String(data: data, encoding: .utf8) else { return }
            let names = output.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
            await MainActor.run { availableShortcuts = names }
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .gif, .tiff, .webP]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do { let name = try model.store.importActionIcon(url); updateButton { $0.icon = .image; $0.iconValue = name } }
            catch { model.message = error.localizedDescription }
        }
    }

    private func startRecording() {
        stopRecording()
        updateButton { $0.strokes = [] }
        recording = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                DispatchQueue.main.async { stopRecording() }
                return nil
            }
            if event.isARepeat { return nil }
            let stroke = DeckStroke(event: event)
            DispatchQueue.main.async {
                updateButton { $0.strokes.append(stroke) }
                if button.action == .keyChord || button.strokes.count >= 31 { stopRecording() }
            }
            return nil
        }
    }

    private func stopRecording() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
        recording = false
    }
}
