import SwiftUI

enum PixelDashMode: String, CaseIterable, Identifiable {
    case text, system, water, art, clock, timer, stopwatch

    var id: String { rawValue }
    var title: String {
        switch self {
        case .text: return L("TEXTO", "TEXT")
        case .system: return L("MAC", "MAC")
        case .water: return L("ÁGUA", "WATER")
        case .art: return L("ARTE", "ART")
        case .clock: return L("RELÓGIO", "CLOCK")
        case .timer: return "TIMER"
        case .stopwatch: return L("CRONÔMETRO", "STOPWATCH")
        }
    }
    var symbol: String {
        switch self {
        case .text: return "textformat"
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

    init(_ values: [String: String]) {
        mode = PixelDashMode(rawValue: values["dashMode"] ?? "clock") ?? .clock
        message = values["dashMessage"] ?? L("OLÁ, XENEON!", "HELLO, XENEON!")
        accent = PixelClockSettings.color(values["dashAccent"] ?? "#F6C85F", fallback: .yellow)
        rainbow = values["dashRainbow"] == "true"
        uses24HourTime = values["dash24Hour"] != "false"
        showSeconds = values["dashSeconds"] != "false"
        waterGoal = min(30, max(1, Int(values["dashWaterGoal"] ?? "8") ?? 8))
        timerMinutes = min(240, max(1, Int(values["dashTimerMinutes"] ?? "15") ?? 15))
        artIndex = max(0, Int(values["dashArt"] ?? "0") ?? 0) % 3
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

    private var settings: PixelDashSettings { PixelDashSettings(tile.settings) }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 950 || geometry.size.height < 320
            let accent = settings.accent
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.system(size: compact ? 13 : 21))
                            .foregroundStyle(accent)
                        Text("PIXEL / EDGE")
                            .font(.system(size: compact ? 11 : 18, weight: .heavy, design: .monospaced))
                            .tracking(compact ? 1 : 3)
                        Text("•  " + settings.mode.title)
                            .font(.system(size: compact ? 9 : 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(accent.opacity(0.8))
                        Spacer(minLength: 3)
                        controls(at: timeline.date, compact: compact)
                        if !compact {
                            Text(timeline.date, format: .dateTime.day().month(.abbreviated).hour().minute())
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.45))
                                .padding(.leading, 15)
                        }
                    }
                    .frame(height: compact ? 39 : 62)
                    .padding(.horizontal, compact ? 12 : 30)

                    PixelDashMatrix(mode: settings.mode, settings: settings, values: tile.settings,
                                    cpu: metrics.cpuPercent, memory: metrics.memoryPercent,
                                    date: timeline.date, openedAt: openedAt)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(red: 0.035, green: 0.07, blue: 0.12),
                                    in: RoundedRectangle(cornerRadius: compact ? 8 : 17))
                        .overlay(RoundedRectangle(cornerRadius: compact ? 8 : 17)
                            .strokeBorder(accent.opacity(0.18), lineWidth: 1))
                        .padding(.horizontal, compact ? 5 : 19)

                    HStack(spacing: compact ? 2 : 6) {
                        ForEach(PixelDashMode.allCases) { mode in
                            Button { setMode(mode) } label: {
                                HStack(spacing: compact ? 0 : 7) {
                                    Image(systemName: mode.symbol)
                                    if !compact { Text(mode.title) }
                                }
                                .font(.system(size: compact ? 11 : 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(settings.mode == mode ? Color.black : Color.white.opacity(0.58))
                                .frame(maxWidth: .infinity)
                                .frame(height: compact ? 34 : 47)
                                .background(settings.mode == mode ? accent : Color.white.opacity(0.055),
                                            in: RoundedRectangle(cornerRadius: compact ? 6 : 9))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(mode.title)
                        }
                    }
                    .padding(.horizontal, compact ? 6 : 23)
                    .frame(height: compact ? 42 : 76)
                }
                .background(Color(red: 0.025, green: 0.035, blue: 0.055))
                .clipShape(RoundedRectangle(cornerRadius: compact ? 9 : 20))
            }
        }
    }

    @ViewBuilder private func controls(at date: Date, compact: Bool) -> some View {
        switch settings.mode {
        case .water:
            controlButton("minus") { changeWater(by: -1, at: date) }
            controlButton("plus") { changeWater(by: 1, at: date) }
        case .art:
            controlButton("chevron.left") { changeArt(by: -1) }
            controlButton("chevron.right") { changeArt(by: 1) }
        case .timer:
            controlButton(tile.settings["dashTimerRunning"] == "true" &&
                          settings.timerRemaining(in: tile.settings, at: date) > 0 ? "pause.fill" : "play.fill") { toggleTimer(at: date) }
            controlButton("arrow.counterclockwise") { resetTimer() }
        case .stopwatch:
            controlButton(tile.settings["dashStopwatchRunning"] == "true" ? "pause.fill" : "play.fill") { toggleStopwatch(at: date) }
            controlButton("arrow.counterclockwise") { resetStopwatch() }
        default:
            EmptyView()
        }
    }

    private func controlButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 40)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func setMode(_ mode: PixelDashMode) {
        model.updateTile(tile.id) { $0.settings["dashMode"] = mode.rawValue }
    }

    private func changeWater(by delta: Int, at date: Date) {
        model.updateTile(tile.id) { updated in
            let current = settings.waterCount(in: updated.settings, at: date)
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
            let remaining = settings.timerRemaining(in: updated.settings, at: date)
            if updated.settings["dashTimerRunning"] == "true" && remaining > 0 {
                updated.settings["dashTimerRemaining"] = String(remaining)
                updated.settings["dashTimerRunning"] = "false"
                updated.settings.removeValue(forKey: "dashTimerEnd")
            } else {
                updated.settings["dashTimerEnd"] = String(date.timeIntervalSince1970 + Double(remaining > 0 ? remaining : settings.timerMinutes * 60))
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

private struct PixelDashMatrix: View {
    let mode: PixelDashMode
    let settings: PixelDashSettings
    let values: [String: String]
    let cpu: Double
    let memory: Double
    let date: Date
    let openedAt: Date

    private let columns = 112
    private let rows = 20

    var body: some View {
        Canvas { context, size in
            let pitch = min(size.width / CGFloat(columns), size.height / CGFloat(rows))
            guard pitch > 0 else { return }
            let origin = CGPoint(x: (size.width - CGFloat(columns) * pitch) / 2,
                                 y: (size.height - CGFloat(rows) * pitch) / 2)
            let background = Color(red: 0.075, green: 0.11, blue: 0.17)
            for y in 0..<rows {
                for x in 0..<columns {
                    dot(x, y, color: background, context: context, pitch: pitch, origin: origin)
                }
            }

            switch mode {
            case .text:
                let message = PixelDashGlyphs.normalized(settings.message)
                let scale = message.count <= 9 ? 2 : 1
                let width = PixelDashGlyphs.width(message, scale: scale)
                let x: Int
                if width <= columns - 4 { x = (columns - width) / 2 }
                else {
                    let distance = columns + width
                    let elapsed = max(0, date.timeIntervalSince(openedAt))
                    x = columns - Int(elapsed * 10) % distance
                }
                drawText(message, x: x, y: (rows - 7 * scale) / 2, scale: scale,
                         color: settings.accent, rainbow: settings.rainbow,
                         context: context, pitch: pitch, origin: origin)
            case .system:
                let cpuText = String(format: "CPU %02d%%", Int(cpu.rounded()))
                let ramText = String(format: "RAM %02d%%", Int(memory.rounded()))
                drawText(cpuText, x: (columns - PixelDashGlyphs.width(cpuText, scale: 1)) / 2, y: 1,
                         scale: 1, color: Color(red: 0.28, green: 0.88, blue: 0.97), rainbow: false,
                         context: context, pitch: pitch, origin: origin)
                drawText(ramText, x: (columns - PixelDashGlyphs.width(ramText, scale: 1)) / 2, y: 11,
                         scale: 1, color: settings.accent, rainbow: false,
                         context: context, pitch: pitch, origin: origin)
            case .water:
                let count = settings.waterCount(in: values, at: date)
                let title = L("AGUA", "WATER")
                drawText(title, x: (columns - PixelDashGlyphs.width(title, scale: 1)) / 2, y: 0,
                         scale: 1, color: Color.cyan, rainbow: false,
                         context: context, pitch: pitch, origin: origin)
                let reading = String(format: "%02d/%02d", min(count, 99), settings.waterGoal)
                drawText(reading, x: (columns - PixelDashGlyphs.width(reading, scale: 1)) / 2, y: 9,
                         scale: 1, color: .white, rainbow: false,
                         context: context, pitch: pitch, origin: origin)
                let filled = Int(80 * min(1, Double(count) / Double(settings.waterGoal)))
                for x in 16..<96 {
                    dot(x, 18, color: x - 16 < filled ? .cyan : .white.opacity(0.13),
                        context: context, pitch: pitch, origin: origin)
                }
            case .art:
                drawArt(context: context, pitch: pitch, origin: origin)
            case .clock:
                let reading = settings.clockText(at: date)
                drawText(reading, x: (columns - PixelDashGlyphs.width(reading, scale: 2)) / 2, y: 3,
                         scale: 2, color: .white, rainbow: false,
                         context: context, pitch: pitch, origin: origin)
            case .timer:
                let remaining = settings.timerRemaining(in: values, at: date)
                let reading = String(format: "%02d:%02d", remaining / 60, remaining % 60)
                drawText(reading, x: (columns - PixelDashGlyphs.width(reading, scale: 2)) / 2, y: 3,
                         scale: 2, color: remaining == 0 ? .red : settings.accent, rainbow: false,
                         context: context, pitch: pitch, origin: origin)
            case .stopwatch:
                let elapsed = settings.stopwatchElapsed(in: values, at: date)
                let reading = String(format: "%02d:%02d:%02d", elapsed / 3600, (elapsed / 60) % 60, elapsed % 60)
                drawText(reading, x: (columns - PixelDashGlyphs.width(reading, scale: 2)) / 2, y: 3,
                         scale: 2, color: settings.accent, rainbow: false,
                         context: context, pitch: pitch, origin: origin)
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch mode {
        case .text: return settings.message
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
        let side = pitch * 0.78
        let rect = CGRect(x: origin.x + CGFloat(x) * pitch + (pitch - side) / 2,
                          y: origin.y + CGFloat(y) * pitch + (pitch - side) / 2,
                          width: side, height: side)
        context.fill(Path(roundedRect: rect, cornerRadius: max(0.5, pitch * 0.07)), with: .color(color))
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
            for x in 7..<105 {
                for band in 0..<shades.count {
                    let wave = Int((sin(Double(x) * 0.15 + date.timeIntervalSince1970 * 0.8) * 2).rounded())
                    dot(x, 7 + band + wave, color: shades[band], context: context, pitch: pitch, origin: origin)
                }
            }
            for x in stride(from: 12, through: 100, by: 17) {
                let y = (x * 7) % 6 + 1
                dot(x, y, color: .white, context: context, pitch: pitch, origin: origin)
                dot(x - 1, y, color: .white.opacity(0.5), context: context, pitch: pitch, origin: origin)
                dot(x + 1, y, color: .white.opacity(0.5), context: context, pitch: pitch, origin: origin)
            }
        case 1:
            let heart = ["01100110", "11111111", "11111111", "11111111", "01111110", "00111100", "00011000"]
            for (y, row) in heart.enumerated() {
                for (x, bit) in row.enumerated() where bit == "1" {
                    for dy in 0..<2 { for dx in 0..<2 {
                        dot(48 + x * 2 + dx, 3 + y * 2 + dy, color: .pink, context: context, pitch: pitch, origin: origin)
                    }}
                }
            }
        default:
            let rocket = ["0001000", "0011100", "0111110", "0111110", "1111111", "1011101", "1011101", "0010100"]
            for (y, row) in rocket.enumerated() {
                for (x, bit) in row.enumerated() where bit == "1" {
                    for dy in 0..<2 { for dx in 0..<2 {
                        dot(49 + x * 2 + dx, 1 + y * 2 + dy, color: y > 5 ? .orange : settings.accent,
                            context: context, pitch: pitch, origin: origin)
                    }}
                }
            }
            for x in stride(from: 10, through: 105, by: 13) {
                dot(x, (x * 3) % 18, color: .white.opacity(0.8), context: context, pitch: pitch, origin: origin)
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
        "%": ["11001", "11010", "00100", "00100", "01011", "10011", "00000"],
        "!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
        ".": ["00000", "00000", "00000", "00000", "00000", "00100", "00100"],
        "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
        " ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"]
    ]
}
