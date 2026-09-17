import AppKit
import SwiftUI
import UniformTypeIdentifiers

private extension UTType {
    static let icueWidget = UTType(importedAs: "com.corsair.icuewidget", conformingTo: .zip)
}

struct EditorView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var touch: TouchController
    @State private var showingLibrary = false
    @State private var openPickerAfterLibrary = false

    private var palette: EditorPalette { EditorPalette(dark: model.config.darkMode) }

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 260)
            Rectangle().fill(palette.stroke).frame(width: 1)
            GeometryReader { geometry in
                let previewHeight = min(300, max(220, (geometry.size.width - 52) / 4 + 46))
                VStack(alignment: .leading, spacing: 13) {
                    editorToolbar
                    if model.config.touchEnabled && !touch.inputMonitoringGranted {
                        touchWarning
                    }
                    if let page = model.currentPage {
                        pageHeading(page)
                        ZStack {
                            DashboardPreview(model: model, page: page)
                                .id(page.id)
                                .transition(.opacity.combined(with: .offset(y: model.pageNavigationDirection > 0 ? 24 : -24)))
                        }
                        .frame(height: previewHeight)
                        .clipped()
                        Label(page.desktopMode == true
                              ? L("Área de Trabalho do macOS · ⌃⌥↑/↓ troca de página",
                                  "macOS desktop · ⌃⌥↑/↓ switches pages")
                              : L("Arraste widgets para editar · ⌃⌥↑/↓ troca de página",
                                  "Drag widgets to edit · ⌃⌥↑/↓ switches pages"),
                              systemImage: page.desktopMode == true ? "desktopcomputer" : "hand.draw")
                            .font(.caption)
                            .foregroundStyle(palette.muted)
                    } else {
                        ContentUnavailableView(L("Sem página", "No page"), systemImage: "rectangle.stack")
                    }
                    inspectorCard.frame(maxHeight: .infinity, alignment: .top)
                }
                .padding(18)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            }
        }
        .background(palette.background)
        .frame(minWidth: 1000, minHeight: 700)
        .preferredColorScheme(model.config.darkMode ? .dark : .light)
        .sheet(isPresented: $showingLibrary, onDismiss: {
            if openPickerAfterLibrary {
                openPickerAfterLibrary = false
                openWidgetPicker()
            }
        }) { librarySheet.frame(width: 630, height: 510) }
        .onChange(of: model.libraryOpenRequest) { _, _ in showingLibrary = true }
    }

    private var editorToolbar: some View {
        HStack(spacing: 10) {
            EdgeMark().frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text("EDGE PANEL")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .tracking(0.5)
                Text(L("Estúdio XENEON", "XENEON studio"))
                    .font(.caption)
                    .foregroundStyle(palette.muted)
            }
            Spacer(minLength: 8)
            Button { model.displays.refresh() } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.bordered)
                .help(L("Atualizar monitores", "Refresh displays"))
            Button { showingLibrary = true } label: {
                Label(L("Biblioteca iCUE", "iCUE library"), systemImage: "square.stack.3d.up")
            }
            .buttonStyle(.bordered)
            Menu {
                ForEach(WidgetKind.allCases.filter { $0 != .icue }) { kind in
                    if kind == .actionDeck {
                        Button(L("Deck de Ações mini", "Mini Action Deck")) { model.addTile(kind, deckPreset: .mini) }
                        Button(L("Deck de Ações compacto", "Compact Action Deck")) { model.addTile(kind) }
                        Button(L("Deck de Ações em tela cheia", "Full-page Action Deck")) {
                            model.addTile(kind, deckPreset: .fullPage)
                        }
                    } else {
                        Button(kind.title) { model.addTile(kind) }
                    }
                }
            } label: {
                Label(L("Adicionar widget", "Add widget"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.accent)
            .disabled(model.currentPage == nil || model.currentPage?.desktopMode == true)
        }
        .frame(height: 46)
    }

    private var touchWarning: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("O macOS ainda controla o toque", "macOS is still handling touch"))
                    .font(.subheadline.weight(.semibold))
                Text(L("Permita Monitoramento de Entrada para o EdgePanel. Sem essa permissão, os toques continuam a clicar no monitor em foco.",
                       "Allow Input Monitoring for EdgePanel. Without it, touches still click on the focused display."))
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Button(L("Solicitar acesso", "Request access")) { touch.requestPermissions() }
                Button(L("Abrir definição", "Open setting")) { openInputMonitoring() }
                Button(L("Verificar novamente", "Check again")) { touch.refreshPermissions() }
                    .buttonStyle(.link)
            }
        }
        .padding(12)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    private func pageHeading(_ page: DashboardPage) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(page.name)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(page.desktopMode == true
                     ? L("Área de Trabalho e barra de menus do macOS", "macOS desktop and menu bar")
                     : L("\(page.tiles.count) widgets nesta página", "\(page.tiles.count) widgets on this page"))
                    .font(.caption)
                    .foregroundStyle(palette.muted)
            }
            Spacer()
            if let p = model.profileIndex, let q = model.pageIndex,
               model.config.profiles[p].pages.count > 1 {
                HStack(spacing: 5) {
                    Button { model.navigatePage(by: -1) } label: { Image(systemName: "chevron.up") }
                        .help(L("Página anterior · Control Option ↑", "Previous page · Control Option ↑"))
                    Text("\(q) / \(model.config.profiles[p].pages.count - 1)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(palette.muted)
                        .frame(minWidth: 40)
                    Button { model.navigatePage(by: 1) } label: { Image(systemName: "chevron.down") }
                        .help(L("Próxima página · Control Option ↓", "Next page · Control Option ↓"))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            Button { model.selectedTileID = nil } label: {
                Label(L("Configurações da página", "Page settings"), systemImage: "paintpalette")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var inspectorCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(palette.accent)
                Text(L("INSPETOR", "INSPECTOR"))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(palette.muted)
                Spacer()
                Text(model.selectedTile?.kind.title ?? L("Página", "Page"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.muted)
            }
            inspector.frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(14)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(palette.stroke, lineWidth: 1))
    }

    private func openWidgetPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.icueWidget]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                model.importWidget(url)
            }
            model.libraryOpenRequest += 1
        }
    }

    private func openInputMonitoring() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .frame(width: 34, height: 34)
                        .background(palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L("ÁREA DE TRABALHO", "WORKSPACE"))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(palette.muted)
                        Text(L("Organizar painel", "Organize dashboard"))
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(.top, 18)
                .padding(.bottom, 5)
                GroupBox(L("Perfis", "Profiles")) {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(model.config.profiles) { profile in
                            let selected = model.config.selectedProfileID == profile.id
                            HStack(spacing: 7) {
                                Button { model.selectProfile(profile.id) } label: {
                                    Label(profile.name, systemImage: selected ? "square.stack.3d.up.fill" : "square.stack.3d.up")
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                    .buttonStyle(.plain)
                                    .fontWeight(selected ? .semibold : .regular)
                                if model.config.profiles.count > 1 {
                                    Button { model.removeProfile(profile.id) } label: { Image(systemName: "minus.circle") }
                                        .buttonStyle(.plain).help(L("Apagar perfil", "Delete profile"))
                                }
                            }
                            .foregroundStyle(selected ? palette.accent : Color.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .background(selected ? palette.accent.opacity(0.13) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 9))
                        }
                        Button { model.addProfile() } label: { Label(L("Novo perfil", "New profile"), systemImage: "plus") }
                            .buttonStyle(.link)
                        if let p = model.profileIndex {
                            TextField(L("Nome", "Name"), text: Binding(
                                get: { model.config.profiles[p].name },
                                set: { model.renameProfile(model.config.profiles[p].id, $0) }
                            ))
                        }
                    }.padding(5)
                }
                GroupBox(L("Páginas", "Pages")) {
                    VStack(alignment: .leading, spacing: 5) {
                        if let p = model.profileIndex {
                            ForEach(model.config.profiles[p].pages) { page in
                                let selected = model.config.selectedPageID == page.id
                                HStack(spacing: 5) {
                                    Button { model.selectPage(page.id) } label: {
                                        Label(page.name, systemImage: page.desktopMode == true
                                              ? "desktopcomputer" : (selected ? "rectangle.fill" : "rectangle"))
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                        .buttonStyle(.plain)
                                        .fontWeight(selected ? .semibold : .regular)
                                    if page.desktopMode != true {
                                        Button { model.movePage(page.id, by: -1) } label: { Image(systemName: "arrow.up") }
                                            .buttonStyle(.plain)
                                            .disabled(model.config.profiles[p].pages.dropFirst().first?.id == page.id)
                                        Button { model.movePage(page.id, by: 1) } label: { Image(systemName: "arrow.down") }
                                            .buttonStyle(.plain)
                                            .disabled(model.config.profiles[p].pages.last?.id == page.id)
                                        Button { model.removePage(page.id) } label: { Image(systemName: "minus.circle") }
                                            .buttonStyle(.plain).help(L("Apagar página", "Delete page"))
                                    }
                                }
                                .foregroundStyle(selected ? palette.accent : Color.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 7)
                                .background(selected ? palette.accent.opacity(0.13) : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 9))
                            }
                            Button { model.addPage() } label: { Label(L("Nova página", "New page"), systemImage: "plus") }
                                .buttonStyle(.link)
                        }
                    }.padding(5)
                }
                GroupBox(L("Monitor", "Display")) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(model.displays.displays) { display in
                            let selected = model.config.selectedDisplay == display.identity
                            Button {
                                model.selectDisplay(display)
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: selected ? "display.2" : "display")
                                    Text(display.label).lineLimit(2)
                                    Spacer(minLength: 0)
                                    if selected { Image(systemName: "checkmark.circle.fill") }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 7)
                                .background(selected ? palette.accent.opacity(0.13) : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 9))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(selected ? palette.accent : Color.primary)
                        }
                        if model.displays.resolve(model.config.selectedDisplay) == nil {
                            Text(L("Selecione a XENEON. O toque não age em outra tela.", "Select the XENEON. Touch will not target another display."))
                                .font(.caption).foregroundStyle(.orange)
                        }
                        Divider()
                        BrightnessControl(controller: model.brightness)
                    }.padding(5)
                }
                GroupBox(L("Preferências", "Preferences")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(L("Tema escuro", "Dark theme"), isOn: Binding(
                            get: { model.config.darkMode }, set: { model.config.darkMode = $0 }
                        ))
                        Toggle(L("Ativar toque", "Enable touch"), isOn: Binding(
                            get: { model.config.touchEnabled }, set: { model.toggleTouch($0) }
                        ))
                        Text(touch.status).font(.caption)
                            .foregroundStyle(model.config.touchEnabled && (!touch.enabled || !touch.connected || !touch.canPostEvents) ? Color.orange : Color.secondary)
                        if model.config.touchEnabled && (!touch.enabled || !touch.connected || !touch.canPostEvents) {
                            Text(L("Enquanto o controlador não estiver capturado, o macOS pode enviar o toque ao monitor principal.",
                                   "Until the controller is captured, macOS may send touch to the main display."))
                                .font(.caption).foregroundStyle(.orange)
                        }
                        Button(L("Abrir Acessibilidade", "Open Accessibility")) {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
                        }
                        if model.config.touchEnabled && touch.inputMonitoringGranted && !touch.canPostEvents {
                            Button(L("Solicitar Acessibilidade", "Request Accessibility")) { touch.requestPermissions() }
                        }
                        Button(L("Abrir Monitoramento de Entrada", "Open Input Monitoring")) {
                            openInputMonitoring()
                        }
                        Button(L("Calibrar toque", "Calibrate touch")) { model.beginCalibration() }
                            .disabled(model.displays.resolve(model.config.selectedDisplay) == nil)
                        Toggle(L("Trocar eixos", "Swap axes"), isOn: Binding(
                            get: { model.config.touchOrientation.swapAxes }, set: { model.config.touchOrientation.swapAxes = $0 }
                        ))
                        Toggle(L("Inverter horizontal", "Invert horizontal"), isOn: Binding(
                            get: { model.config.touchOrientation.invertX }, set: { model.config.touchOrientation.invertX = $0 }
                        ))
                        Toggle(L("Inverter vertical", "Invert vertical"), isOn: Binding(
                            get: { model.config.touchOrientation.invertY }, set: { model.config.touchOrientation.invertY = $0 }
                        ))
                        Toggle(L("Abrir ao iniciar sessão", "Launch at login"), isOn: Binding(
                            get: { model.config.launchAtLogin }, set: { model.toggleLogin($0) }
                        ))
                    }.padding(5)
                }
                if !model.message.isEmpty {
                    Text(model.message)
                        .font(.caption)
                        .foregroundStyle(palette.accent)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .groupBoxStyle(EditorGroupBoxStyle(palette: palette))
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
        }
        .background(palette.sidebar)
    }

    @ViewBuilder private var inspector: some View {
        if let tile = model.selectedTile {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(L("Editar widget", "Edit widget")).font(.headline)
                        Spacer()
                        Button(role: .destructive) { model.removeTile(tile.id) } label: { Label(L("Remover", "Remove"), systemImage: "trash") }
                    }
                    if tile.kind != .launcher {
                        TextField(L("Título", "Title"), text: tileBinding(tile.id, get: { $0.title }, set: { $0.title = $1 }))
                    }
                    HStack {
                        Text("X \(tile.x) · Y \(tile.y) · \(tile.width) × \(tile.height)")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Spacer()
                    }
                    if tile.kind == .web {
                        HStack {
                            TextField(L("URL da página", "Page URL"), text: tileBinding(tile.id, get: { $0.value }, set: { $0.value = $1 }),
                                      prompt: Text("https://example.com"))
                                .textFieldStyle(.roundedBorder)
                            Button(L("Colar URL", "Paste URL")) {
                                guard let pasted = NSPasteboard.general.string(forType: .string) else { return }
                                model.updateTile(tile.id) { $0.value = pasted.trimmingCharacters(in: .whitespacesAndNewlines) }
                            }
                        }
                    }
                    if tile.kind == .launcher {
                        HStack {
                            Text(tile.value.isEmpty ? L("Nenhum app", "No app") : tile.value).lineLimit(1)
                            Button(L("Escolher…", "Choose…")) { chooseApp(for: tile.id) }
                        }
                    }
                    if tile.kind == .timer {
                        Stepper(value: Binding(
                            get: { max(1, Int(model.selectedTile?.value ?? "") ?? 5) },
                            set: { minutes in model.updateTile(tile.id) { $0.value = String(minutes) } }
                        ), in: 1...240) {
                            Text(L("Duração: \(max(1, Int(tile.value) ?? 5)) minutos", "Duration: \(max(1, Int(tile.value) ?? 5)) minutes"))
                        }
                    }
                    if [.clock, .cpu, .memory, .network, .ssd, .launcher, .timer].contains(tile.kind) {
                        nativeWidgetControls(tile)
                    }
                    if tile.kind == .pixelClock {
                        pixelClockControls(tile)
                    }
                    if tile.kind == .pixelDash {
                        pixelDashControls(tile)
                    }
                    if tile.kind == .actionDeck {
                        ActionDeckEditor(model: model, tile: tile)
                    }
                    if tile.kind == .icue, let imported = model.imported(tile.importedID) {
                        Text("\(imported.name) · \(imported.version)").foregroundStyle(.secondary)
                        ForEach(imported.controls) { control in
                            importedControl(control, tile: tile)
                        }
                    }
                }.padding(.trailing, 8)
            }
        } else if let page = model.currentPage {
            pageInspector(page)
        } else {
            ContentUnavailableView(L("Sem página", "No page"), systemImage: "rectangle.stack")
        }
    }

    private func pageInspector(_ page: DashboardPage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Label(L("Configurações da página", "Page settings"), systemImage: "rectangle.stack")
                    .font(.headline)
                Text(page.desktopMode == true
                     ? L("Nesta página, o EdgePanel libera a XENEON para mostrar a Área de Trabalho e a barra de menus do macOS.",
                         "On this page, EdgePanel reveals the macOS desktop and menu bar on the XENEON.")
                     : L("Selecione um widget para editar seus detalhes. Clique em uma área vazia da prévia para voltar à página.",
                         "Select a widget to edit its details. Click an empty area of the preview to return to the page."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField(L("Nome da página", "Page name"), text: Binding(
                    get: { model.currentPage?.id == page.id ? model.currentPage?.name ?? "" : page.name },
                    set: { model.renamePage(page.id, $0) }
                ))
                .textFieldStyle(.roundedBorder)

                if page.desktopMode == true {
                    Label(L("Use ⌃⌥↑/↓ ou o menu do EdgePanel para voltar aos widgets.",
                            "Use ⌃⌥↑/↓ or the EdgePanel menu to return to widgets."),
                          systemImage: "keyboard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Divider()
                    Text(L("Aparência", "Appearance"))
                        .font(.subheadline.weight(.semibold))
                    ColorPicker(L("Fundo desta página", "This page background"), selection: Binding(
                        get: {
                            Color(hex: model.currentPage?.backgroundHex ??
                                  DashboardColors.backgroundHex(dark: model.config.darkMode))
                        },
                        set: { model.setPageBackground(page.id, hex: $0.hexString) }
                    ), supportsOpacity: false)
                    HStack {
                        Text(model.currentPage?.backgroundHex ??
                             DashboardColors.backgroundHex(dark: model.config.darkMode))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L("Usar fundo padrão", "Use default background")) {
                            model.setPageBackground(page.id, hex: nil)
                        }
                        .buttonStyle(.link)
                        .disabled(model.currentPage?.backgroundHex == nil)
                    }
                    BackgroundImageControls(store: model.store,
                        filename: Binding(
                            get: { model.currentPage?.id == page.id ? model.currentPage?.backgroundImage ?? "" : page.backgroundImage ?? "" },
                            set: { model.setPageBackgroundImage(page.id, filename: $0.isEmpty ? nil : $0) }),
                        scale: Binding(
                            get: { model.currentPage?.backgroundScale ?? "fill" },
                            set: { model.setPageBackgroundPlacement(page.id, scale: $0) }),
                        horizontal: Binding(
                            get: { model.currentPage?.backgroundHorizontal ?? "center" },
                            set: { model.setPageBackgroundPlacement(page.id, horizontal: $0) }),
                        vertical: Binding(
                            get: { model.currentPage?.backgroundVertical ?? "center" },
                            set: { model.setPageBackgroundPlacement(page.id, vertical: $0) }))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 8)
        }
    }

    private func tileBinding(_ id: UUID, get: @escaping (Tile) -> String, set: @escaping (inout Tile, String) -> Void) -> Binding<String> {
        Binding(get: { model.currentPage?.tiles.first(where: { $0.id == id }).map(get) ?? "" },
                set: { newValue in model.updateTile(id) { set(&$0, newValue) } })
    }

    private func pixelSetting(_ tile: Tile, _ key: String, default defaultValue: String) -> Binding<String> {
        tileBinding(tile.id, get: { $0.settings[key] ?? defaultValue }, set: { $0.settings[key] = $1 })
    }

    private func pixelSwitch(_ tile: Tile, _ key: String, default defaultValue: Bool = true) -> Binding<Bool> {
        let value = pixelSetting(tile, key, default: defaultValue ? "true" : "false")
        return Binding(get: { value.wrappedValue == "true" }, set: { value.wrappedValue = $0 ? "true" : "false" })
    }

    private func nativeWidgetControls(_ tile: Tile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text(L("Personalização", "Customization")).font(.headline)

            if tile.kind == .clock {
                TimeZoneSelection(identifier: pixelSetting(tile, "clockTimeZone", default: "local"))
                Picker(L("Formato da hora", "Time format"), selection: pixelSetting(tile, "clockFormat", default: "system")) {
                    Text(L("Sistema", "System")).tag("system")
                    Text("24 h").tag("24")
                    Text("12 h").tag("12")
                }.pickerStyle(.segmented)
                Picker(L("Fonte dos números", "Digit font"), selection: pixelSetting(tile, "clockFont", default: "rounded")) {
                    Text(L("Arredondada", "Rounded")).tag("rounded")
                    Text(L("Clássica", "Classic")).tag("system")
                    Text(L("Mono", "Mono")).tag("mono")
                }.pickerStyle(.segmented)
                Toggle(L("Mostrar data", "Show date"), isOn: pixelSwitch(tile, "clockShowDate"))
                Toggle(L("Mostrar segundos", "Show seconds"), isOn: pixelSwitch(tile, "clockShowSeconds"))
            }

            if [.cpu, .memory, .network, .ssd].contains(tile.kind) {
                Toggle(L("Mostrar gráfico", "Show graph"),
                       isOn: pixelSwitch(tile, "nativeShowGraph", default: tile.kind != .ssd))
            }

            if [.cpu, .memory, .ssd].contains(tile.kind) {
                Stepper(value: Binding(
                    get: { min(100, max(50, Int(pixelSetting(tile, "nativeWarningAt", default: "85").wrappedValue) ?? 85)) },
                    set: { pixelSetting(tile, "nativeWarningAt", default: "85").wrappedValue = String($0) }
                ), in: 50...100, step: 5) {
                    Text(L("Aviso a partir de \(min(100, max(50, Int(tile.settings["nativeWarningAt"] ?? "85") ?? 85)))%",
                           "Warn at \(min(100, max(50, Int(tile.settings["nativeWarningAt"] ?? "85") ?? 85)))%"))
                }
            }

            if tile.kind == .launcher {
                Picker(L("Tamanho do ícone", "Icon size"), selection: pixelSetting(tile, "launcherIconSize", default: "normal")) {
                    Text(L("Normal", "Normal")).tag("normal")
                    Text(L("Grande", "Large")).tag("large")
                }.pickerStyle(.segmented)
            }

            if tile.kind != .launcher {
                tileColorPicker(L("Cor de destaque", "Accent color"), tile: tile,
                                key: "nativeAccent", default: nativeAccentDefault(tile.kind))
                nativeBackgroundPicker(tile)
            }

            Button(L("Restaurar padrão", "Restore defaults")) {
                model.updateTile(tile.id) { updated in
                    for key in ["nativeAccent", "nativeBackground", "nativeShowGraph", "nativeWarningAt", "clockFormat", "clockTimeZone",
                                "clockFont", "clockShowDate", "clockShowSeconds", "launcherShowName",
                                "launcherIconSize"] {
                        updated.settings.removeValue(forKey: key)
                    }
                }
            }
            .font(.caption)
        }
    }

    private func nativeAccentDefault(_ kind: WidgetKind) -> String {
        let dark = model.config.darkMode
        switch kind {
        case .clock: return "#63BFE8"
        case .cpu: return dark ? "#63C2FF" : "#1270B8"
        case .memory: return dark ? "#B894FF" : "#6E42B8"
        case .network: return dark ? "#59DBB8" : "#0A7D63"
        case .ssd: return dark ? "#FFBA57" : "#AD610F"
        case .launcher: return dark ? "#ABE37A" : "#2E7A36"
        case .timer: return dark ? "#FDBA57" : "#A95A0B"
        default: return dark ? "#6BC9F0" : "#166A91"
        }
    }

    private func nativeBackgroundPicker(_ tile: Tile) -> some View {
        let value = tileBinding(tile.id, get: { $0.settings["nativeBackground"] ?? "" },
                                set: { $0.settings["nativeBackground"] = $1 })
        let fallback = [.clock, .cpu, .memory, .network, .ssd].contains(tile.kind) ?
            (model.config.darkMode ? "#101824" : "#F8FBFD") :
            (model.config.darkMode ? "#142033" : "#F8FBFD")

        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                ColorPicker(L("Cor de fundo", "Background color"), selection: Binding(
                    get: { HexColor(hex: value.wrappedValue)?.color ?? Color(hex: fallback) },
                    set: { value.wrappedValue = $0.hexString }
                ), supportsOpacity: false)
                TextField("#RRGGBB", text: value, prompt: Text("#RRGGBB"))
                    .frame(width: 95)
            }
            if value.wrappedValue.isEmpty {
                Text(L("Usando o fundo padrão do tema", "Using the theme's default background"))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Button(L("Usar fundo padrão", "Use default background")) {
                    model.updateTile(tile.id) { $0.settings.removeValue(forKey: "nativeBackground") }
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
    }

    private func pixelClockControls(_ tile: Tile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text(L("Relógio Pixel", "Pixel Clock")).font(.headline)
            Picker(L("Tamanho", "Size"), selection: pixelSetting(tile, "pixelSize", default: "xl")) {
                Text("S").tag("s")
                Text("M").tag("m")
                Text("L").tag("l")
                Text("XL").tag("xl")
            }.pickerStyle(.segmented)
            Picker(L("Formato da hora", "Time format"), selection: pixelSetting(tile, "pixel24Hour", default: "true")) {
                Text("24 h").tag("true")
                Text("12 h").tag("false")
            }.pickerStyle(.segmented)
            TimeZoneSelection(identifier: pixelSetting(tile, "pixelTimeZone", default: "local"))
            Picker(L("Semana começa", "Week starts on"), selection: pixelSetting(tile, "pixelWeekStartsMonday", default: "false")) {
                Text(L("Domingo", "Sunday")).tag("false")
                Text(L("Segunda-feira", "Monday")).tag("true")
            }.pickerStyle(.menu)
            Toggle(L("Mostrar segundos", "Show seconds"), isOn: pixelSwitch(tile, "pixelShowSeconds", default: false))
            Toggle(L("Mostrar AM/PM", "Show AM/PM"), isOn: pixelSwitch(tile, "pixelShowAMPM", default: false))
                .disabled(pixelSetting(tile, "pixel24Hour", default: "true").wrappedValue == "true")
            Toggle(L("Mostrar calendário", "Show calendar"), isOn: pixelSwitch(tile, "pixelShowDate"))
            Toggle(L("Mostrar dias da semana", "Show weekday dashes"), isOn: pixelSwitch(tile, "pixelShowWeek"))
            Toggle(L("Preencher dias anteriores", "Fill past weekdays"), isOn: pixelSwitch(tile, "pixelWeekProgress", default: false))
                .disabled(!pixelSwitch(tile, "pixelShowWeek").wrappedValue)
            Divider()
            Toggle(L("Estilo personalizado", "Custom style"), isOn: pixelSwitch(tile, "pixelCustomStyle"))
            VStack(alignment: .leading, spacing: 12) {
                tileColorPicker(L("Cor do texto", "Text color"), tile: tile, key: "pixelForeground", default: "#FFFFFF")
                tileColorPicker(L("Cor de destaque", "Accent color"), tile: tile, key: "pixelAccent", default: "#FF4048")
                tileColorPicker(L("Cor de fundo", "Background color"), tile: tile, key: "pixelBackground", default: "#080A0D")
                let transparency = pixelSetting(tile, "pixelBackgroundTransparency", default: "100")
                HStack {
                    Text(L("Transparência do fundo", "Background transparency"))
                    Slider(value: Binding(
                        get: { min(100, max(0, Double(transparency.wrappedValue) ?? 100)) },
                        set: { transparency.wrappedValue = String(Int($0.rounded())) }
                    ), in: 0...100, step: 1)
                    Text("\(Int(Double(transparency.wrappedValue) ?? 100))%")
                        .font(.caption.monospacedDigit())
                        .frame(width: 38, alignment: .trailing)
                }
            }
            .disabled(!pixelSwitch(tile, "pixelCustomStyle").wrappedValue)
            Button(L("Restaurar padrão", "Restore defaults")) {
                model.updateTile(tile.id) { updated in
                    for key in ["pixelSize", "pixel24Hour", "pixelTimeZone", "pixelWeekStartsMonday",
                                "pixelShowSeconds", "pixelShowAMPM", "pixelShowDate", "pixelShowWeek",
                                "pixelWeekProgress", "pixelCustomStyle", "pixelForeground", "pixelAccent",
                                "pixelBackground", "pixelBackgroundTransparency"] {
                        updated.settings.removeValue(forKey: key)
                    }
                }
            }
            .font(.caption)
        }
    }

    private func pixelDashControls(_ tile: Tile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text(L("Painel Pixel", "Pixel Dashboard")).font(.headline)
            Text(L("As abas também podem ser trocadas diretamente na XENEON.",
                   "Tabs can also be changed directly on the XENEON."))
                .font(.caption).foregroundStyle(.secondary)
            Picker(L("Aba inicial", "Initial tab"), selection: pixelSetting(tile, "dashMode", default: "clock")) {
                ForEach(PixelDashMode.allCases) { mode in Text(mode.title).tag(mode.rawValue) }
            }.pickerStyle(.menu)
            TextField(L("Mensagem", "Message"), text: pixelSetting(tile, "dashMessage", default: L("OLÁ, XENEON!", "HELLO, XENEON!")))
            Toggle(L("Mensagem em arco-íris", "Rainbow message"), isOn: Binding(
                get: { pixelSetting(tile, "dashRainbow", default: "false").wrappedValue == "true" },
                set: { pixelSetting(tile, "dashRainbow", default: "false").wrappedValue = $0 ? "true" : "false" }
            ))
            Picker(L("Texto longo", "Long text"), selection: pixelSetting(tile, "dashTextBehavior", default: "scale")) {
                Text(L("Ajustar", "Scale to fit")).tag("scale")
                Text(L("Deslizar", "Scroll")).tag("scroll")
            }.pickerStyle(.segmented)
            if tile.settings["dashTextBehavior"] == "scroll" {
                HStack {
                    Text(L("Velocidade do texto", "Text speed"))
                    Slider(value: Binding(
                        get: { min(20, max(2, Double(pixelSetting(tile, "dashScrollSpeed", default: "8").wrappedValue) ?? 8)) },
                        set: { pixelSetting(tile, "dashScrollSpeed", default: "8").wrappedValue = String($0) }), in: 2...20)
                }
            }
            Text(L("Clima e social mostram valores inseridos manualmente; não há contas ou serviços conectados.",
                   "Weather and social show manually entered values; no accounts or providers are connected."))
                .font(.caption).foregroundStyle(.secondary)
            TextField(L("Temperatura exibida (ex.: 24°C)", "Displayed temperature (for example, 24°C)"),
                      text: pixelSetting(tile, "dashWeatherText", default: "--°C"))
            TextField(L("Número social exibido", "Displayed social number"),
                      text: pixelSetting(tile, "dashSocialText", default: "----"))
            Picker(L("Animação", "Animation"), selection: pixelSetting(tile, "dashArt", default: "0")) {
                Text(L("Onda colorida", "Color wave")).tag("0")
                Text(L("Coração", "Heart")).tag("1")
                Text(L("Foguete", "Rocket")).tag("2")
            }.pickerStyle(.menu)
            Picker(L("Formato da hora", "Time format"), selection: pixelSetting(tile, "dash24Hour", default: "true")) {
                Text("24 h").tag("true")
                Text("12 h").tag("false")
            }.pickerStyle(.segmented)
            Toggle(L("Mostrar segundos", "Show seconds"), isOn: pixelSwitch(tile, "dashSeconds"))
            Stepper(value: Binding(
                get: { min(30, max(1, Int(pixelSetting(tile, "dashWaterGoal", default: "8").wrappedValue) ?? 8)) },
                set: { pixelSetting(tile, "dashWaterGoal", default: "8").wrappedValue = String($0) }
            ), in: 1...30) {
                Text(L("Meta diária de água: \(min(30, max(1, Int(tile.settings["dashWaterGoal"] ?? "8") ?? 8))) copos",
                       "Daily water goal: \(min(30, max(1, Int(tile.settings["dashWaterGoal"] ?? "8") ?? 8))) glasses"))
            }
            Stepper(value: Binding(
                get: { min(240, max(1, Int(pixelSetting(tile, "dashTimerMinutes", default: "15").wrappedValue) ?? 15)) },
                set: { minutes in model.updateTile(tile.id) { updated in
                    updated.settings["dashTimerMinutes"] = String(minutes)
                    updated.settings["dashTimerRemaining"] = String(minutes * 60)
                    updated.settings["dashTimerRunning"] = "false"
                    updated.settings.removeValue(forKey: "dashTimerEnd")
                } }
            ), in: 1...240) {
                Text(L("Timer: \(min(240, max(1, Int(tile.settings["dashTimerMinutes"] ?? "15") ?? 15))) minutos",
                       "Timer: \(min(240, max(1, Int(tile.settings["dashTimerMinutes"] ?? "15") ?? 15))) minutes"))
            }
            tileColorPicker(L("Cor dos pixels", "Pixel color"), tile: tile, key: "dashAccent", default: "#51DDE9")
        }
    }

    private func tileColorPicker(_ label: String, tile: Tile, key: String, default defaultValue: String) -> some View {
        let value = pixelSetting(tile, key, default: defaultValue)
        return HStack {
            ColorPicker(label, selection: Binding(
                get: { Color(hex: value.wrappedValue) },
                set: { value.wrappedValue = $0.hexString }
            ))
            TextField("#RRGGBB", text: value).frame(width: 95)
        }
    }

    @ViewBuilder private func importedControl(_ control: ImportedControl, tile: Tile) -> some View {
        let value = tileBinding(tile.id, get: { $0.settings[control.name] ?? simpleDefault(control.defaultExpression) },
                                set: { $0.settings[control.name] = $1 })
        let label = localizedLabel(control.label, importedID: tile.importedID)
        switch control.type {
        case "switch":
            Toggle(label, isOn: Binding(get: { value.wrappedValue == "true" }, set: { value.wrappedValue = $0 ? "true" : "false" }))
        case "slider":
            let low = Double(simpleDefault(control.minExpression ?? "0")) ?? 0
            let high = max(low + 1, Double(simpleDefault(control.maxExpression ?? "100")) ?? 100)
            HStack {
                Text(label)
                Slider(value: Binding(get: { Double(value.wrappedValue) ?? low }, set: { value.wrappedValue = String($0) }), in: low...high)
                Text(value.wrappedValue).frame(width: 45)
            }
        case "color":
            HStack {
                ColorPicker(label, selection: Binding(
                    get: { Color(hex: value.wrappedValue) },
                    set: { value.wrappedValue = $0.hexString }
                ))
                TextField("#RRGGBB", text: value).frame(width: 95)
            }
        case "sensors-combobox":
            Picker(label, selection: value) {
                Text("Mac CPU").tag("mac.cpu.load")
                Text("Mac RAM").tag("mac.memory.load")
            }
        case "combobox", "tab-buttons":
            let options = parseOptions(control.optionsExpression, importedID: tile.importedID)
            if !options.isEmpty {
                if control.type == "tab-buttons" {
                    Picker(label, selection: value) {
                        ForEach(options, id: \.0) { option in Text(option.1).tag(option.0) }
                    }.pickerStyle(.segmented)
                } else {
                    Picker(label, selection: value) {
                        ForEach(options, id: \.0) { option in Text(option.1).tag(option.0) }
                    }.pickerStyle(.menu)
                }
            } else { TextField(label, text: value) }
        default:
            TextField(label, text: value)
        }
    }

    private func simpleDefault(_ expression: String) -> String {
        expression.trimmingCharacters(in: CharacterSet(charactersIn: "'\" "))
    }

    private func translationTable(_ importedID: UUID?) -> [String: String] {
        guard let importedID else { return [:] }
        let url = model.store.libraryURL.appendingPathComponent(importedID.uuidString).appendingPathComponent("translation.json")
        guard let data = try? Data(contentsOf: url),
              let table = try? JSONSerialization.jsonObject(with: data) as? [String: [String: [String: String]]] else { return [:] }
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        return table[language]?["translation"] ?? table["en"]?["translation"] ?? [:]
    }

    private func localizedLabel(_ label: String, importedID: UUID?) -> String {
        guard label.hasPrefix("tr("), label.hasSuffix(")") else { return label }
        let key = String(label.dropFirst(3).dropLast()).trimmingCharacters(in: CharacterSet(charactersIn: "'\" "))
        return translationTable(importedID)[key] ?? key
    }

    private func parseOptions(_ expression: String?, importedID: UUID?) -> [(String, String)] {
        guard let expression else { return [] }
        var normalized = expression.replacingOccurrences(of: "'", with: "\"")
        if let regex = try? NSRegularExpression(pattern: "tr\\(\\\"([^\\\"]+)\\\"\\)") {
            let table = translationTable(importedID)
            let ns = normalized as NSString
            for match in regex.matches(in: normalized, range: NSRange(location: 0, length: ns.length)).reversed() {
                let key = ns.substring(with: match.range(at: 1))
                let translated = table[key] ?? key
                if let data = try? JSONSerialization.data(withJSONObject: [translated]),
                   let wrapped = String(data: data, encoding: .utf8),
                   let range = Range(match.range, in: normalized) {
                    normalized.replaceSubrange(range, with: String(wrapped.dropFirst().dropLast()))
                }
            }
        }
        guard let data = normalized.data(using: .utf8), let values = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return [] }
        return values.compactMap { item in
            if let string = item as? String { return (string, string) }
            if let dict = item as? [String: String], let key = dict["key"] { return (key, dict["value"] ?? key) }
            return nil
        }
    }

    private func chooseApp(for id: UUID) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { model.updateTile(id) { $0.value = url.path } }
    }

    private var librarySheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("Widgets iCUE", "iCUE widgets")).font(.title2.bold())
                Spacer()
                Button(L("Importar .icuewidget…", "Import .icuewidget…")) {
                    openPickerAfterLibrary = true
                    showingLibrary = false
                }
                Button(L("Fechar", "Close")) { showingLibrary = false }
            }
            Text(L("Compatibilidade parcial. O app mostra os recursos que cada widget exige antes de o ativar.", "Partial compatibility. Review each widget's requirements before activation."))
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    ForEach(model.imports) { widget in
                        GroupBox {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(widget.name).font(.headline)
                                    Text("\(widget.version) · \(widget.author)").font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Button(L("Adicionar", "Add")) { model.addTile(.icue, importedID: widget.id); showingLibrary = false }
                                        .disabled(!widget.compatible)
                                }
                                if widget.warnings.isEmpty {
                                    Text(L("Compatível com o subconjunto implementado", "Compatible with the implemented subset"))
                                        .font(.caption).foregroundStyle(.green)
                                } else {
                                    ForEach(widget.warnings, id: \.self) { warning in
                                        Text("• \(warning)").font(.caption).foregroundStyle(.orange)
                                    }
                                }
                                ForEach(widget.requestedDomains, id: \.self) { domain in
                                    Toggle("HTTPS: \(domain)", isOn: Binding(
                                        get: { model.imported(widget.id)?.allowedDomains.contains(domain) ?? false },
                                        set: { model.updateDomain(widget.id, domain: domain, enabled: $0) }
                                    )).font(.caption)
                                }
                            }.padding(6)
                        }
                    }
                    if model.imports.isEmpty { Text(L("Ainda não há widgets importados.", "No imported widgets yet.")).foregroundStyle(.secondary) }
                }
            }
            if !model.message.isEmpty { Text(model.message).font(.caption).foregroundStyle(.cyan) }
        }.padding(20)
    }
}

private struct BrightnessControl: View {
    @ObservedObject var controller: BrightnessController
    @State private var proposedPercent: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "sun.max.fill").foregroundStyle(.yellow)
                Text(L("Brilho físico", "Hardware brightness"))
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 2)
                if controller.applying {
                    ProgressView().controlSize(.mini)
                } else {
                    Text(controller.available ? "\(Int(controller.percent))%" : "—")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            HardwareBrightnessSlider(value: proposedPercent ?? controller.percent, enabled: controller.available) {
                proposedPercent = $0.rounded()
            }
            .frame(height: 18)
            .accessibilityLabel(L("Brilho físico da XENEON", "XENEON hardware brightness"))
            if let proposedPercent, Int(proposedPercent) != Int(controller.percent) {
                HStack(spacing: 7) {
                    Text("\(Int(controller.percent)) → \(Int(proposedPercent))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button { self.proposedPercent = nil } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .help(L("Descartar ajuste", "Discard change"))
                    Button(L("Aplicar", "Apply")) {
                        controller.set(proposedPercent)
                        self.proposedPercent = nil
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                }
            }
            HStack {
                Text("DDC/CI · XENEON")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button { proposedPercent = nil; controller.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help(L("Ler brilho atual", "Read current brightness"))
            }
            if !controller.status.isEmpty {
                Text(controller.status)
                    .font(.caption2)
                    .foregroundStyle(controller.available ? Color.secondary : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { controller.refresh() }
        .onChange(of: controller.available) { _, available in
            if !available { proposedPercent = nil }
        }
    }
}

private struct HardwareBrightnessSlider: NSViewRepresentable {
    let value: Double
    let enabled: Bool
    let onChange: (Double) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(value: value, minValue: 0, maxValue: 100,
                              target: context.coordinator, action: #selector(Coordinator.changed(_:)))
        slider.isContinuous = true
        slider.isEnabled = enabled
        return slider
    }

    func updateNSView(_ slider: NSSlider, context: Context) {
        context.coordinator.onChange = onChange
        slider.isEnabled = enabled
        // Programmatic updates never emit a control action; a gesture only changes the proposed value.
        if abs(slider.doubleValue - value) >= 0.5 { slider.doubleValue = value }
    }

    final class Coordinator: NSObject {
        var onChange: (Double) -> Void
        init(onChange: @escaping (Double) -> Void) { self.onChange = onChange }
        @objc func changed(_ sender: NSSlider) { onChange(sender.doubleValue) }
    }
}

struct DashboardPreview: View {
    @ObservedObject var model: AppModel
    let page: DashboardPage
    private var palette: EditorPalette { EditorPalette(dark: model.config.darkMode) }

    var body: some View {
        GeometryReader { geometry in
            let boardWidth = min(max(0, geometry.size.width - 20), max(0, geometry.size.height - 52) * 4)
            let boardHeight = boardWidth / 4
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: page.desktopMode == true ? "desktopcomputer" : "square.grid.3x3")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(palette.accent)
                    Text(page.desktopMode == true ? L("ÁREA DE TRABALHO", "DESKTOP") : L("ORGANIZAÇÃO", "LAYOUT"))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.7)
                    Spacer()
                    Text(page.desktopMode == true ? "macOS" : "16 × 4")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(palette.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(palette.accent.opacity(0.09), in: Capsule())
                }
                .padding(.horizontal, 14)
                .frame(height: 40)
                Group {
                    if page.desktopMode == true {
                        ZStack {
                            LinearGradient(colors: [Color(red: 0.12, green: 0.22, blue: 0.37),
                                                    Color(red: 0.08, green: 0.11, blue: 0.24)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                            VStack(spacing: 0) {
                                HStack(spacing: 7) {
                                    Image(systemName: "apple.logo")
                                    Text("Finder")
                                    Spacer()
                                    Image(systemName: "wifi")
                                }
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .frame(height: 25)
                                .background(.white.opacity(0.14))
                                Spacer(minLength: 0)
                                Label(page.name, systemImage: "desktopcomputer")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer(minLength: 0)
                            }
                        }
                    } else {
                        BoardView(model: model, page: page, editing: true)
                            .background(DashboardBackdrop(page: page, dark: model.config.darkMode, store: model.store))
                    }
                }
                    .frame(width: boardWidth, height: boardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(palette.stroke, lineWidth: 1))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
                Spacer(minLength: 0)
            }
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(palette.surface)
                    .contentShape(RoundedRectangle(cornerRadius: 16))
                    .onTapGesture { model.selectedTileID = nil }
            }
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(palette.stroke, lineWidth: 1))
        }
    }
}

private extension Color {
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&rgb)
        self.init(.sRGB, red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255,
                  blue: Double(rgb & 255) / 255, opacity: 1)
    }
}
