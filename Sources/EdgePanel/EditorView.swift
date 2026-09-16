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

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 245)
            Divider()
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("XENEON EDGE").font(.system(size: 23, weight: .bold, design: .rounded))
                    Spacer()
                    Button { model.displays.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    Button(L("Biblioteca iCUE", "iCUE library")) { showingLibrary = true }
                    Menu {
                        ForEach(WidgetKind.allCases.filter { $0 != .icue }) { kind in
                            Button(kind.title) { model.addTile(kind) }
                        }
                    } label: { Label(L("Adicionar widget", "Add widget"), systemImage: "plus") }
                    .disabled(model.currentPage == nil)
                }
                if model.config.touchEnabled && !touch.inputMonitoringGranted {
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
                            Button(L("Abrir definição", "Open setting")) { openInputMonitoring() }
                            Button(L("Verificar novamente", "Check again")) { touch.refreshPermissions() }
                                .buttonStyle(.link)
                        }
                    }
                    .padding(12)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }
                if let page = model.currentPage {
                    Text(page.name).font(.headline)
                    DashboardPreview(model: model, page: page)
                        .frame(maxWidth: .infinity)
                    Text(L("Arraste para mover ou redimensionar. O painel atualiza durante o movimento.",
                           "Drag to move or resize. The dashboard updates as you move."))
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ContentUnavailableView(L("Sem página", "No page"), systemImage: "rectangle.stack")
                }
                Divider()
                inspector.frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(20)
        }
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
            VStack(alignment: .leading, spacing: 18) {
                Label(L("Painel", "Dashboard"), systemImage: "rectangle.3.group")
                    .font(.headline).padding(.top, 16)
                GroupBox(L("Perfis", "Profiles")) {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(model.config.profiles) { profile in
                            HStack {
                                Button(profile.name) { model.selectProfile(profile.id) }
                                    .buttonStyle(.plain)
                                    .fontWeight(model.config.selectedProfileID == profile.id ? .bold : .regular)
                                Spacer()
                                if model.config.profiles.count > 1 {
                                    Button { model.removeProfile(profile.id) } label: { Image(systemName: "minus.circle") }
                                        .buttonStyle(.plain).help(L("Apagar perfil", "Delete profile"))
                                }
                            }
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
                                HStack {
                                    Button(page.name) { model.selectPage(page.id) }
                                        .buttonStyle(.plain)
                                        .fontWeight(model.config.selectedPageID == page.id ? .bold : .regular)
                                    Spacer()
                                    Button { model.movePage(page.id, by: -1) } label: { Image(systemName: "arrow.up") }
                                        .buttonStyle(.plain).disabled(model.config.profiles[p].pages.first?.id == page.id)
                                    Button { model.movePage(page.id, by: 1) } label: { Image(systemName: "arrow.down") }
                                        .buttonStyle(.plain).disabled(model.config.profiles[p].pages.last?.id == page.id)
                                    if model.config.profiles[p].pages.count > 1 {
                                        Button { model.removePage(page.id) } label: { Image(systemName: "minus.circle") }
                                            .buttonStyle(.plain).help(L("Apagar página", "Delete page"))
                                    }
                                }
                            }
                            Button { model.addPage() } label: { Label(L("Nova página", "New page"), systemImage: "plus") }
                                .buttonStyle(.link)
                        }
                    }.padding(5)
                }
                GroupBox(L("Monitor", "Display")) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(model.displays.displays) { display in
                            Button {
                                model.selectDisplay(display)
                            } label: {
                                HStack {
                                    Image(systemName: model.config.selectedDisplay == display.identity ? "checkmark.circle.fill" : "circle")
                                    Text(display.label).lineLimit(2)
                                }
                            }.buttonStyle(.plain)
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
                    Text(model.message).font(.caption).foregroundStyle(.cyan).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 20)
        }
        .background(Color(NSColor.controlBackgroundColor))
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
                    TextField(L("Título", "Title"), text: tileBinding(tile.id, get: { $0.title }, set: { $0.title = $1 }))
                    HStack {
                        Text("X \(tile.x) · Y \(tile.y) · \(tile.width) × \(tile.height)")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Spacer()
                    }
                    if tile.kind == .web {
                        TextField("https://", text: tileBinding(tile.id, get: { $0.value }, set: { $0.value = $1 }))
                            .textFieldStyle(.roundedBorder)
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
                    if [.clock, .cpu, .memory, .network, .launcher, .timer, .web].contains(tile.kind) {
                        nativeWidgetControls(tile)
                    }
                    if tile.kind == .pixelClock {
                        pixelClockControls(tile)
                    }
                    if tile.kind == .pixelDash {
                        pixelDashControls(tile)
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
                Text(L("Selecione um widget para editar seus detalhes. Clique em uma área vazia da prévia para voltar à página.",
                       "Select a widget to edit its details. Click an empty area of the preview to return to the page."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField(L("Nome da página", "Page name"), text: Binding(
                    get: { model.currentPage?.id == page.id ? model.currentPage?.name ?? "" : page.name },
                    set: { model.renamePage(page.id, $0) }
                ))
                .textFieldStyle(.roundedBorder)

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

    private func pixelSwitch(_ tile: Tile, _ key: String) -> Binding<Bool> {
        let value = pixelSetting(tile, key, default: "true")
        return Binding(get: { value.wrappedValue == "true" }, set: { value.wrappedValue = $0 ? "true" : "false" })
    }

    private func nativeWidgetControls(_ tile: Tile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text(L("Personalização", "Customization")).font(.headline)

            if tile.kind == .clock {
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

            if [.cpu, .memory, .network].contains(tile.kind) {
                Toggle(L("Mostrar gráfico", "Show graph"), isOn: pixelSwitch(tile, "nativeShowGraph"))
            }

            if [.cpu, .memory].contains(tile.kind) {
                Stepper(value: Binding(
                    get: { min(100, max(50, Int(pixelSetting(tile, "nativeWarningAt", default: "85").wrappedValue) ?? 85)) },
                    set: { pixelSetting(tile, "nativeWarningAt", default: "85").wrappedValue = String($0) }
                ), in: 50...100, step: 5) {
                    Text(L("Aviso a partir de \(min(100, max(50, Int(tile.settings["nativeWarningAt"] ?? "85") ?? 85)))%",
                           "Warn at \(min(100, max(50, Int(tile.settings["nativeWarningAt"] ?? "85") ?? 85)))%"))
                }
            }

            if tile.kind == .launcher {
                Toggle(L("Mostrar nome do app", "Show app name"), isOn: pixelSwitch(tile, "launcherShowName"))
                Picker(L("Tamanho do ícone", "Icon size"), selection: pixelSetting(tile, "launcherIconSize", default: "normal")) {
                    Text(L("Normal", "Normal")).tag("normal")
                    Text(L("Grande", "Large")).tag("large")
                }.pickerStyle(.segmented)
            }

            tileColorPicker(L("Cor de destaque", "Accent color"), tile: tile,
                             key: "nativeAccent", default: nativeAccentDefault(tile.kind))

            Button(L("Restaurar padrão", "Restore defaults")) {
                model.updateTile(tile.id) { updated in
                    for key in ["nativeAccent", "nativeShowGraph", "nativeWarningAt", "clockFormat",
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
        case .launcher: return dark ? "#ABE37A" : "#2E7A36"
        case .timer: return dark ? "#FDBA57" : "#A95A0B"
        default: return dark ? "#6BC9F0" : "#166A91"
        }
    }

    private func pixelClockControls(_ tile: Tile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text(L("Relógio Pixel", "Pixel Clock")).font(.headline)
            Toggle(L("Mostrar segundos", "Show seconds"), isOn: pixelSwitch(tile, "pixelShowSeconds"))
            Toggle(L("Mostrar data", "Show date"), isOn: pixelSwitch(tile, "pixelShowDate"))
            Toggle(L("Indicadores da semana", "Week indicators"), isOn: pixelSwitch(tile, "pixelShowWeek"))
            Toggle(L("Preencher dias concluídos", "Fill completed weekdays"), isOn: pixelSwitch(tile, "pixelWeekProgress"))
                .disabled(!pixelSwitch(tile, "pixelShowWeek").wrappedValue)
            Toggle(L("Semana começa na segunda-feira", "Week starts on Monday"), isOn: pixelSwitch(tile, "pixelWeekStartsMonday"))
                .disabled(!pixelSwitch(tile, "pixelShowWeek").wrappedValue)
            Picker(L("Formato da hora", "Time format"), selection: pixelSetting(tile, "pixel24Hour", default: "true")) {
                Text("24 h").tag("true")
                Text("12 h").tag("false")
            }.pickerStyle(.segmented)
            Picker(L("Fuso horário", "Time zone"), selection: pixelSetting(tile, "pixelTimeZone", default: "local")) {
                Text(L("Fuso do Mac", "Mac time zone")).tag("local")
                Text("UTC").tag("UTC")
                Text("Lisboa").tag("Europe/Lisbon")
                Text("Londres / London").tag("Europe/London")
                Text("Nova Iorque / New York").tag("America/New_York")
                Text("São Paulo").tag("America/Sao_Paulo")
                Text("Los Angeles").tag("America/Los_Angeles")
                Text("Tóquio / Tokyo").tag("Asia/Tokyo")
            }.pickerStyle(.menu)
            tileColorPicker(L("Cor dos números", "Digit color"), tile: tile, key: "pixelForeground", default: "#F4F3EE")
            tileColorPicker(L("Cor de destaque", "Accent color"), tile: tile, key: "pixelAccent", default: "#FF6464")
            tileColorPicker(L("Cor de fundo", "Background color"), tile: tile, key: "pixelBackground", default: "#080A0D")
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
            tileColorPicker(L("Cor de destaque", "Accent color"), tile: tile, key: "dashAccent", default: "#F6C85F")
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
    var body: some View {
        GeometryReader { geometry in
            let boardWidth = max(0, geometry.size.width - 16)
            let boardHeight = min(geometry.size.height - 52, boardWidth * 0.25)
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Circle().fill(.green).frame(width: 7, height: 7)
                    Text(L("PRÉVIA AO VIVO", "LIVE PREVIEW"))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.7)
                    Spacer()
                    Text("16 × 4")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 13)
                .frame(height: 36)
                BoardView(model: model, page: page, editing: true)
                    .frame(width: boardWidth, height: boardHeight)
                    .background(DashboardColors.background(page: page, dark: model.config.darkMode))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                Spacer(minLength: 0)
            }
            .background(model.config.darkMode ? Color(red: 0.075, green: 0.105, blue: 0.15) : .white,
                        in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(Color.cyan.opacity(0.22), lineWidth: 1))
        }.frame(height: 265)
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
    var hexString: String {
        guard let color = NSColor(self).usingColorSpace(.deviceRGB) else { return "#FFFFFF" }
        return String(format: "#%02X%02X%02X", Int(color.redComponent * 255), Int(color.greenComponent * 255), Int(color.blueComponent * 255))
    }
}
