import SwiftUI

enum PixelDashMode: String, CaseIterable, Identifiable {
    case text, weather, social, water, art, clock, timer, system, stopwatch

    static let dashboardTabs: [PixelDashMode] = [.text, .weather, .social, .water, .art, .clock, .timer]

    var id: String { rawValue }
    var title: String {
        switch self {
        case .text: return L("TEXTO", "TEXT")
        case .weather: return L("CLIMA", "WEATHER")
        case .social: return "SOCIAL"
        case .system: return L("MAC", "MAC")
        case .water: return L("ÁGUA", "WATER")
        case .art: return L("ANIMAR", "ANIMATE")
        case .clock: return L("RELÓGIO", "CLOCK")
        case .timer: return "TIMER"
        case .stopwatch: return L("CRONÔMETRO", "STOPWATCH")
        }
    }
    var symbol: String {
        switch self {
        case .text: return "textformat"
        case .weather: return "sun.max.fill"
        case .social: return "heart.fill"
        case .system: return "cpu"
        case .water: return "drop.fill"
        case .art: return "sparkles"
        case .clock: return "clock"
        case .timer: return "timer"
        case .stopwatch: return "stopwatch"
        }
    }
}

struct PixelDashSettings {
    let mode: PixelDashMode
    let message: String
    let accent: Color
    let rainbow: Bool
    let uses24HourTime: Bool
    let showSeconds: Bool
    let waterGoal: Int
    let timerMinutes: Int
    let artIndex: Int
    let textBehavior: String
    let scrollSpeed: Double
    let weatherText: String
    let socialText: String

    init(_ values: [String: String]) {
        mode = PixelDashMode(rawValue: values["dashMode"] ?? "clock") ?? .clock
        message = values["dashMessage"] ?? L("OLÁ, XENEON!", "HELLO, XENEON!")
        accent = PixelClockSettings.color(values["dashAccent"] ?? "#51DDE9", fallback: .cyan)
        rainbow = values["dashRainbow"] == "true"
        uses24HourTime = values["dash24Hour"] != "false"
        showSeconds = values["dashSeconds"] != "false"
        waterGoal = min(30, max(1, Int(values["dashWaterGoal"] ?? "8") ?? 8))
        timerMinutes = min(240, max(1, Int(values["dashTimerMinutes"] ?? "15") ?? 15))
        artIndex = max(0, Int(values["dashArt"] ?? "0") ?? 0) % 3
        textBehavior = values["dashTextBehavior"] == "scroll" ? "scroll" : "scale"
        scrollSpeed = min(20, max(2, Double(values["dashScrollSpeed"] ?? "8") ?? 8))
        weatherText = Self.displayValue(values["dashWeatherText"] ?? "--°C", maxLength: 6)
        socialText = Self.displayValue(values["dashSocialText"] ?? "----", maxLength: 8)
    }

    private static func displayValue(_ value: String, maxLength: Int) -> String {
        String(value.folding(options: .diacriticInsensitive, locale: .current).uppercased().prefix(maxLength))
    }

    func clockText(at date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let shownHour = uses24HourTime ? hour : (hour % 12 == 0 ? 12 : hour % 12)
        let base = String(format: "%02d:%02d", shownHour, calendar.component(.minute, from: date))
        return showSeconds ? base + String(format: ":%02d", calendar.component(.second, from: date)) : base
    }

    func waterCount(in values: [String: String], at date: Date) -> Int {
        guard values["dashWaterDay"] == Self.dayKey(date) else { return 0 }
        return max(0, Int(values["dashWaterCount"] ?? "0") ?? 0)
    }

    static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    func timerRemaining(in values: [String: String], at date: Date) -> Int {
        if values["dashTimerRunning"] == "true", let end = Double(values["dashTimerEnd"] ?? "") {
            return max(0, Int(ceil(end - date.timeIntervalSince1970)))
        }
        return max(0, Int(values["dashTimerRemaining"] ?? "") ?? timerMinutes * 60)
    }

    func stopwatchElapsed(in values: [String: String], at date: Date) -> Int {
        let saved = max(0, Int(values["dashStopwatchElapsed"] ?? "0") ?? 0)
        guard values["dashStopwatchRunning"] == "true",
              let started = Double(values["dashStopwatchStart"] ?? "") else { return saved }
        return saved + max(0, Int(date.timeIntervalSince1970 - started))
    }
}

struct PixelDashTile: View {
    @ObservedObject var model: AppModel
    @ObservedObject var metrics: SystemMetrics
    let tile: Tile
    @State private var openedAt = Date()
    @State private var settingsOpen = false

    private var values: [String: String] {
        model.currentPage?.tiles.first(where: { $0.id == tile.id })?.settings ?? tile.settings
    }
    private var settings: PixelDashSettings { PixelDashSettings(values) }
    private var tabs: [PixelDashMode] {
        var result = PixelDashMode.dashboardTabs
        if !result.contains(settings.mode) { result.append(settings.mode) }
        return result
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 950 || geometry.size.height < 300
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                ZStack(alignment: .trailing) {
                    VStack(spacing: 0) {
                        HStack(spacing: compact ? 8 : 13) {
                            Text("EP")
                                .font(.system(size: compact ? 10 : 13, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .frame(width: compact ? 24 : 34, height: compact ? 24 : 34)
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.75), lineWidth: 2))
                            Text("PIXEL//EDGE")
                                .font(.system(size: compact ? 11 : 15, weight: .heavy, design: .monospaced))
                                .tracking(compact ? 1 : 2)
                                .foregroundStyle(Color(red: 0.34, green: 0.91, blue: 0.95))
                            Spacer()
                            Button { settingsOpen = true } label: {
                                Image(systemName: "gearshape")
                                    .font(.system(size: compact ? 12 : 15, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .frame(width: compact ? 28 : 34, height: compact ? 28 : 34)
                                    .background(Color(red: 0.075, green: 0.11, blue: 0.14),
                                                in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(L("Configurações do painel pixel", "Pixel dashboard settings"))
                        }
                        .padding(.horizontal, compact ? 10 : 24)
                        .frame(height: compact ? 36 : 56)
                        .overlay(alignment: .bottom) { Color.white.opacity(0.08).frame(height: 1) }

                        PixelDashMatrix(mode: settings.mode, settings: settings, values: values,
                                        cpu: metrics.cpuPercent, memory: metrics.memoryPercent,
                                        date: timeline.date, openedAt: openedAt)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(red: 0.035, green: 0.055, blue: 0.07))
                            .contentShape(Rectangle())
                            .onTapGesture { activateMatrix(at: timeline.date) }

                        HStack(spacing: compact ? 1 : 3) {
                            ForEach(tabs) { mode in
                                Button { setMode(mode) } label: {
                                    HStack(spacing: compact ? 0 : 8) {
                                        Image(systemName: mode.symbol)
                                        if !compact { Text(mode.title) }
                                    }
                                    .font(.system(size: compact ? 11 : 12, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(settings.mode == mode ? Color(red: 0.30, green: 0.88, blue: 0.93) : Color(red: 0.52, green: 0.61, blue: 0.68))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: compact ? 27 : 40)
                                    .background(settings.mode == mode ? Color(red: 0.09, green: 0.18, blue: 0.21) : .clear,
                                                in: RoundedRectangle(cornerRadius: 7))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(mode.title)
                            }
                        }
                        .padding(3)
                        .frame(maxWidth: compact ? .infinity : 920)
                        .background(Color(red: 0.025, green: 0.035, blue: 0.045),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.10)))
                        .padding(.horizontal, compact ? 5 : 18)
                        .frame(height: compact ? 40 : 62)
                    }
                    .background(Color(red: 0.018, green: 0.025, blue: 0.032))
                    .foregroundStyle(.white)

                    if settingsOpen {
                        Color.black.opacity(0.60)
                            .ignoresSafeArea()
                            .onTapGesture { settingsOpen = false }
                        inspector(at: timeline.date)
                            .frame(width: min(590, max(280, geometry.size.width * 0.39)),
                                   height: geometry.size.height)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: settingsOpen)
                .clipShape(RoundedRectangle(cornerRadius: compact ? 7 : 10))
            }
        }
    }

    private func activateMatrix(at date: Date) {
        switch settings.mode {
        case .water: changeWater(by: 1, at: date)
        case .art: changeArt(by: 1)
        case .timer: toggleTimer(at: date)
        case .stopwatch: toggleStopwatch(at: date)
        default: break
        }
    }

    private func binding(_ key: String, default defaultValue: String = "") -> Binding<String> {
        Binding(get: { values[key] ?? defaultValue },
                set: { newValue in model.updateTile(tile.id) { $0.settings[key] = newValue } })
    }

    private func inspector(at date: Date) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    Text(L("CONFIGURAÇÕES", "SETTINGS"))
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.cyan)
                    Spacer()
                    Button { settingsOpen = false } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L("Fechar configurações", "Close settings"))
                }
                Picker(L("Seção", "Section"), selection: binding("dashMode", default: "clock")) {
                    ForEach(PixelDashMode.allCases) { mode in Text(mode.title).tag(mode.rawValue) }
                }
                .pickerStyle(.menu)
                Divider()
                Text(settings.mode.title)
                    .font(.system(size: 23, weight: .bold, design: .monospaced))

                if settings.mode == .text {
                    TextField(L("Mensagem", "Message"), text: binding("dashMessage", default: L("OLÁ, XENEON!", "HELLO, XENEON!")))
                    Toggle(L("Cores em arco-íris", "Rainbow colors"), isOn: Binding(
                        get: { values["dashRainbow"] == "true" },
                        set: { binding("dashRainbow").wrappedValue = $0 ? "true" : "false" }))
                    Picker(L("Texto longo", "Long text"), selection: binding("dashTextBehavior", default: "scale")) {
                        Text(L("Ajustar", "Scale to fit")).tag("scale")
                        Text(L("Deslizar", "Scroll")).tag("scroll")
                    }.pickerStyle(.segmented)
                    if settings.textBehavior == "scroll" {
                        HStack {
                            Text(L("Velocidade", "Speed"))
                            Slider(value: Binding(
                                get: { settings.scrollSpeed },
                                set: { binding("dashScrollSpeed").wrappedValue = String($0) }), in: 2...20)
                        }
                    }
                }
                if settings.mode == .weather {
                    Text(L("Leitura manual; não há previsão online conectada.",
                           "Manual reading; no online weather provider is connected."))
                        .font(.caption).foregroundStyle(.secondary)
                    TextField(L("Temperatura (ex.: 24°C)", "Temperature (for example, 24°C)"),
                              text: binding("dashWeatherText", default: "--°C"))
                }
                if settings.mode == .social {
                    Text(L("Valor manual; nenhuma conta social está conectada.",
                           "Manual value; no social account is connected."))
                        .font(.caption).foregroundStyle(.secondary)
                    TextField(L("Número exibido", "Displayed number"), text: binding("dashSocialText", default: "----"))
                }
                if settings.mode == .water {
                    Text(L("\(settings.waterCount(in: values, at: date)) de \(settings.waterGoal) copos hoje",
                           "\(settings.waterCount(in: values, at: date)) of \(settings.waterGoal) glasses today"))
                    HStack {
                        Button { changeWater(by: -1, at: date) } label: { Image(systemName: "minus") }
                        Button { changeWater(by: 1, at: date) } label: { Image(systemName: "plus") }
                    }
                    .buttonStyle(.bordered)
                    Text(L("Toque na matriz para adicionar um copo.", "Tap the matrix to add a glass."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if settings.mode == .art {
                    Button(L("Próxima animação", "Next animation")) { changeArt(by: 1) }
                        .buttonStyle(.bordered)
                }
                if settings.mode == .timer {
                    HStack {
                        Button(values["dashTimerRunning"] == "true" ? L("Pausar", "Pause") : L("Iniciar", "Start")) { toggleTimer(at: date) }
                        Button(L("Reiniciar", "Reset")) { resetTimer() }
                    }.buttonStyle(.bordered)
                }
                if settings.mode == .stopwatch {
                    HStack {
                        Button(values["dashStopwatchRunning"] == "true" ? L("Pausar", "Pause") : L("Iniciar", "Start")) { toggleStopwatch(at: date) }
                        Button(L("Reiniciar", "Reset")) { resetStopwatch() }
                    }.buttonStyle(.bordered)
                }

                Text(L("COR DOS PIXELS", "PIXEL COLOR"))
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                HStack(spacing: 11) {
                    ForEach(["#51DDE9", "#55E3B1", "#F5BD4B", "#FF4E5F", "#F25CAF", "#A885F7", "#FFFFFF"], id: \.self) { hex in
                        colorSwatch(hex)
                    }
                }
                ColorPicker(L("Cor personalizada", "Custom color"), selection: Binding(
                    get: { HexColor(hex: values["dashAccent"] ?? "#51DDE9")?.color ?? .cyan },
                    set: { binding("dashAccent").wrappedValue = $0.hexString }))
                Text(L("Alterações salvas automaticamente", "Changes are saved automatically"))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.cyan.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.cyan.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
            }
            .textFieldStyle(.roundedBorder)
            .padding(24)
        }
        .background(Color(red: 0.055, green: 0.075, blue: 0.09))
        .overlay(alignment: .leading) { Color.white.opacity(0.14).frame(width: 1) }
    }

    private func colorSwatch(_ hex: String) -> some View {
        Button { binding("dashAccent").wrappedValue = hex } label: {
            Circle()
                .fill(HexColor(hex: hex)?.color ?? .cyan)
                .frame(width: 27, height: 27)
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(values["dashAccent"] == hex ? 1 : 0.18), lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
    }

    private func setMode(_ mode: PixelDashMode) {
        model.updateTile(tile.id) { $0.settings["dashMode"] = mode.rawValue }
    }

    private func changeWater(by delta: Int, at date: Date) {
        model.updateTile(tile.id) { updated in
            let current = PixelDashSettings(updated.settings).waterCount(in: updated.settings, at: date)
            updated.settings["dashWaterCount"] = String(max(0, current + delta))
            updated.settings["dashWaterDay"] = PixelDashSettings.dayKey(date)
        }
    }

    private func changeArt(by delta: Int) {
        model.updateTile(tile.id) { updated in
            let current = Int(updated.settings["dashArt"] ?? "0") ?? 0
            updated.settings["dashArt"] = String((current + delta + 3) % 3)
        }
    }

    private func toggleTimer(at date: Date) {
        model.updateTile(tile.id) { updated in
            let currentSettings = PixelDashSettings(updated.settings)
            let remaining = currentSettings.timerRemaining(in: updated.settings, at: date)
            if updated.settings["dashTimerRunning"] == "true" && remaining > 0 {
                updated.settings["dashTimerRemaining"] = String(remaining)
                updated.settings["dashTimerRunning"] = "false"
                updated.settings.removeValue(forKey: "dashTimerEnd")
            } else {
                updated.settings["dashTimerEnd"] = String(date.timeIntervalSince1970 + Double(remaining > 0 ? remaining : currentSettings.timerMinutes * 60))
                updated.settings["dashTimerRunning"] = "true"
            }
        }
    }

    private func resetTimer() {
        model.updateTile(tile.id) { updated in
            updated.settings["dashTimerRunning"] = "false"
            updated.settings["dashTimerRemaining"] = String(settings.timerMinutes * 60)
            updated.settings.removeValue(forKey: "dashTimerEnd")
        }
    }

    private func toggleStopwatch(at date: Date) {
        model.updateTile(tile.id) { updated in
            if updated.settings["dashStopwatchRunning"] == "true" {
                updated.settings["dashStopwatchElapsed"] = String(settings.stopwatchElapsed(in: updated.settings, at: date))
                updated.settings["dashStopwatchRunning"] = "false"
                updated.settings.removeValue(forKey: "dashStopwatchStart")
            } else {
                updated.settings["dashStopwatchStart"] = String(date.timeIntervalSince1970)
                updated.settings["dashStopwatchRunning"] = "true"
            }
        }
    }

    private func resetStopwatch() {
        model.updateTile(tile.id) { updated in
            updated.settings["dashStopwatchRunning"] = "false"
            updated.settings["dashStopwatchElapsed"] = "0"
            updated.settings.removeValue(forKey: "dashStopwatchStart")
        }
    }
}

struct PixelDashMatrix: View {
    let mode: PixelDashMode
    let settings: PixelDashSettings
    let values: [String: String]
    let cpu: Double
    let memory: Double
    let date: Date
    let openedAt: Date

    private let columns = 76
    private let rows = 16

    var body: some View {
        Canvas { context, size in
            let pitch = min(size.width / CGFloat(columns), size.height / CGFloat(rows))
            guard pitch > 0 else { return }
            let origin = CGPoint(x: (size.width - CGFloat(columns) * pitch) / 2,
                                 y: (size.height - CGFloat(rows) * pitch) / 2)
            let background = Color(red: 0.075, green: 0.11, blue: 0.135)
            for y in 0..<rows {
                for x in 0..<columns {
                    dot(x, y, color: background, context: context, pitch: pitch, origin: origin)
                }
            }

            switch mode {
            case .text:
                let message = PixelDashGlyphs.normalized(settings.message)
                let largeWidth = PixelDashGlyphs.width(message, scale: 2)
                let scale = settings.textBehavior == "scroll" || largeWidth <= columns - 4 ? 2 : 1
                let width = PixelDashGlyphs.width(message, scale: scale)
                let x: Int
                if width <= columns - 4 { x = (columns - width) / 2 }
                else {
                    let distance = columns + width
                    let elapsed = max(0, date.timeIntervalSince(openedAt))
                    x = columns - Int(elapsed * settings.scrollSpeed) % distance
                }
                drawText(message, x: x, y: (rows - 7 * scale) / 2, scale: scale,
                         color: settings.accent, rainbow: settings.rainbow,
                         context: context, pitch: pitch, origin: origin)
            case .weather:
                let sun = ["00000100000", "00000100000", "00100100100", "00011111000", "00011111000",
                           "11111111111", "00011111000", "00011111000", "00100100100", "00000100000", "00000100000"]
                drawShape(sun, x: 10, y: 2, color: Color(red: 1, green: 0.76, blue: 0.25),
                          context: context, pitch: pitch, origin: origin)
                drawReading(settings.weatherText, x: 28, color: .white,
                            context: context, pitch: pitch, origin: origin)
            case .social:
                let heart = ["01100000110", "11110001111", "11111011111", "11111111111", "11111111111",
                             "01111111110", "00111111100", "00011111000", "00001110000", "00000100000"]
                drawShape(heart, x: 10, y: 3, color: Color(red: 0.98, green: 0.20, blue: 0.28),
                          context: context, pitch: pitch, origin: origin)
                drawReading(settings.socialText, x: 28, color: .white,
                            context: context, pitch: pitch, origin: origin)
            case .system:
                let cpuText = String(format: "CPU %02d%%", Int(cpu.rounded()))
                let ramText = String(format: "RAM %02d%%", Int(memory.rounded()))
                drawText(cpuText, x: (columns - PixelDashGlyphs.width(cpuText, scale: 1)) / 2, y: 1,
                         scale: 1, color: Color(red: 0.28, green: 0.88, blue: 0.97), rainbow: false,
                         context: context, pitch: pitch, origin: origin)
                drawText(ramText, x: (columns - PixelDashGlyphs.width(ramText, scale: 1)) / 2, y: 9,
                         scale: 1, color: settings.accent, rainbow: false,
                         context: context, pitch: pitch, origin: origin)
            case .water:
                let count = settings.waterCount(in: values, at: date)
                let title = L("AGUA", "WATER") + " " + String(min(count, 99))
                drawText(title, x: (columns - PixelDashGlyphs.width(title, scale: 1)) / 2, y: 1,
                         scale: 1, color: settings.accent, rainbow: false,
                         context: context, pitch: pitch, origin: origin)
                let filled = Int((Double(min(count, settings.waterGoal)) / Double(settings.waterGoal) * 8).rounded(.up))
                for glass in 0..<8 {
                    for y in 10..<15 {
                        for x in 0..<6 {
                            dot(8 + glass * 8 + x, y,
                                color: glass < filled ? Color(red: 0.31, green: 0.83, blue: 0.90) : Color(red: 0.20, green: 0.32, blue: 0.40),
                                context: context, pitch: pitch, origin: origin)
                        }
                    }
                }
            case .art:
                drawArt(context: context, pitch: pitch, origin: origin)
            case .clock:
                let reading = settings.clockText(at: date)
                drawCentered(reading, color: .white, context: context, pitch: pitch, origin: origin)
            case .timer:
                let remaining = settings.timerRemaining(in: values, at: date)
                let reading = String(format: "%02d:%02d", remaining / 60, remaining % 60)
                drawCentered(reading, color: remaining == 0 ? .red : settings.accent,
                             context: context, pitch: pitch, origin: origin)
            case .stopwatch:
                let elapsed = settings.stopwatchElapsed(in: values, at: date)
                let reading = String(format: "%02d:%02d:%02d", elapsed / 3600, (elapsed / 60) % 60, elapsed % 60)
                drawCentered(reading, color: settings.accent, context: context, pitch: pitch, origin: origin)
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch mode {
        case .text: return settings.message
        case .weather: return L("Clima manual: \(settings.weatherText)", "Manual weather: \(settings.weatherText)")
        case .social: return L("Valor social manual: \(settings.socialText)", "Manual social value: \(settings.socialText)")
        case .system: return "CPU \(Int(cpu.rounded()))%, RAM \(Int(memory.rounded()))%"
        case .water: return L("Água \(settings.waterCount(in: values, at: date)) de \(settings.waterGoal)",
                              "Water \(settings.waterCount(in: values, at: date)) of \(settings.waterGoal)")
        case .art: return L("Arte em pixels", "Pixel art")
        case .clock: return settings.clockText(at: date)
        case .timer: return L("Timer \(settings.timerRemaining(in: values, at: date)) segundos", "Timer \(settings.timerRemaining(in: values, at: date)) seconds")
        case .stopwatch: return L("Cronômetro \(settings.stopwatchElapsed(in: values, at: date)) segundos", "Stopwatch \(settings.stopwatchElapsed(in: values, at: date)) seconds")
        }
    }

    private func dot(_ x: Int, _ y: Int, color: Color, context: GraphicsContext, pitch: CGFloat, origin: CGPoint) {
        guard x >= 0, x < columns, y >= 0, y < rows else { return }
        let side = pitch * 0.82
        let rect = CGRect(x: origin.x + CGFloat(x) * pitch + (pitch - side) / 2,
                          y: origin.y + CGFloat(y) * pitch + (pitch - side) / 2,
                          width: side, height: side)
        context.fill(Path(roundedRect: rect, cornerRadius: max(0.25, pitch * 0.035)), with: .color(color))
    }

    private func drawCentered(_ text: String, color: Color, context: GraphicsContext,
                              pitch: CGFloat, origin: CGPoint) {
        let scale = PixelDashGlyphs.width(text, scale: 2) <= columns - 4 ? 2 : 1
        drawText(text, x: (columns - PixelDashGlyphs.width(text, scale: scale)) / 2,
                 y: (rows - 7 * scale) / 2, scale: scale, color: color, rainbow: false,
                 context: context, pitch: pitch, origin: origin)
    }

    private func drawReading(_ text: String, x: Int, color: Color, context: GraphicsContext,
                             pitch: CGFloat, origin: CGPoint) {
        let scale = PixelDashGlyphs.width(text, scale: 2) <= columns - x ? 2 : 1
        drawText(text, x: x, y: (rows - 7 * scale) / 2, scale: scale,
                 color: color, rainbow: false, context: context, pitch: pitch, origin: origin)
    }

    private func drawShape(_ pattern: [String], x: Int, y: Int, color: Color,
                           context: GraphicsContext, pitch: CGFloat, origin: CGPoint) {
        for (row, bits) in pattern.enumerated() {
            for (column, bit) in bits.enumerated() where bit == "1" {
                dot(x + column, y + row, color: color, context: context, pitch: pitch, origin: origin)
            }
        }
    }

    private func drawText(_ text: String, x: Int, y: Int, scale: Int, color: Color, rainbow: Bool,
                          context: GraphicsContext, pitch: CGFloat, origin: CGPoint) {
        for (letterIndex, letter) in text.enumerated() {
            guard let glyph = PixelDashGlyphs.pattern(for: letter) else { continue }
            for (row, pattern) in glyph.enumerated() {
                for (column, bit) in pattern.enumerated() where bit == "1" {
                    for dy in 0..<scale {
                        for dx in 0..<scale {
                            let px = x + (letterIndex * 6 + column) * scale + dx
                            let py = y + row * scale + dy
                            let shade = rainbow ? Color(hue: Double((px + columns) % columns) / Double(columns), saturation: 0.78, brightness: 1) : color
                            dot(px, py, color: shade, context: context, pitch: pitch, origin: origin)
                        }
                    }
                }
            }
        }
    }

    private func drawArt(context: GraphicsContext, pitch: CGFloat, origin: CGPoint) {
        switch settings.artIndex {
        case 0:
            let shades: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple]
            for x in 2..<74 {
                for band in 0..<shades.count {
                    let wave = Int((sin(Double(x) * 0.18 + date.timeIntervalSince1970 * 0.8) * 1.5).rounded())
                    dot(x, 7 + band + wave, color: shades[band], context: context, pitch: pitch, origin: origin)
                }
            }
            for x in stride(from: 8, through: 69, by: 11) {
                let y = (x * 7) % 5 + 1
                dot(x, y, color: .white, context: context, pitch: pitch, origin: origin)
            }
        case 1:
            let heart = ["01100110", "11111111", "11111111", "11111111", "01111110", "00111100", "00011000"]
            for (y, row) in heart.enumerated() {
                for (x, bit) in row.enumerated() where bit == "1" {
                    for dy in 0..<2 { for dx in 0..<2 {
                        dot(30 + x * 2 + dx, 1 + y * 2 + dy, color: .pink, context: context, pitch: pitch, origin: origin)
                    }}
                }
            }
        default:
            let rocket = ["0001000", "0011100", "0111110", "0111110", "1111111", "1011101", "1011101", "0010100"]
            for (y, row) in rocket.enumerated() {
                for (x, bit) in row.enumerated() where bit == "1" {
                    for dy in 0..<2 { for dx in 0..<2 {
                        dot(31 + x * 2 + dx, y * 2 + dy, color: y > 5 ? .orange : settings.accent,
                            context: context, pitch: pitch, origin: origin)
                    }}
                }
            }
            for x in stride(from: 6, through: 72, by: 12) {
                dot(x, (x * 3) % 15, color: .white.opacity(0.8), context: context, pitch: pitch, origin: origin)
            }
        }
    }
}

enum PixelDashGlyphs {
    static func normalized(_ text: String) -> String {
        text.folding(options: .diacriticInsensitive, locale: .current).uppercased()
    }

    static func width(_ text: String, scale: Int) -> Int { max(0, text.count * 6 - 1) * scale }

    static func pattern(for letter: Character) -> [String]? { glyphs[letter] ?? glyphs[" "] }

    private static let glyphs: [Character: [String]] = [
        "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
        "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
        "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
        "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
        "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
        "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
        "G": ["01111", "10000", "10000", "10111", "10001", "10001", "01111"],
        "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
        "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
        "J": ["00111", "00010", "00010", "00010", "10010", "10010", "01100"],
        "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
        "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
        "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
        "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
        "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
        "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
        "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
        "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
        "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
        "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
        "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
        "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
        "W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
        "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
        "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
        "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
        "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
        "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
        "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
        "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
        "5": ["11111", "10000", "10000", "11110", "00001", "00001", "11110"],
        "6": ["01111", "10000", "10000", "11110", "10001", "10001", "01110"],
        "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
        "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        "9": ["01110", "10001", "10001", "01111", "00001", "00001", "11110"],
        ":": ["00000", "00100", "00100", "00000", "00100", "00100", "00000"],
        "/": ["00001", "00001", "00010", "00100", "01000", "10000", "10000"],
        "°": ["00100", "01010", "00100", "00000", "00000", "00000", "00000"],
        "%": ["11001", "11010", "00100", "00100", "01011", "10011", "00000"],
        "!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
        ".": ["00000", "00000", "00000", "00000", "00000", "00100", "00100"],
        "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
        " ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"]
    ]
}
