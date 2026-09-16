import SwiftUI

enum PixelClockSize: String, CaseIterable {
    case s, m, l, xl

    var heightFactor: CGFloat {
        switch self {
        case .s: return 0.04
        case .m: return 0.06
        case .l: return 0.08
        case .xl: return 0.10
        }
    }
}

struct PixelClockSettings {
    let size: PixelClockSize
    let showSeconds: Bool
    let showDate: Bool
    let showWeek: Bool
    let weekProgress: Bool
    let weekStartsMonday: Bool
    let uses24HourTime: Bool
    let showAMPM: Bool
    let customStyle: Bool
    let backgroundTransparency: Double
    let timeZoneID: String
    let foregroundHex: String
    let accentHex: String
    let backgroundHex: String

    init(_ values: [String: String]) {
        size = PixelClockSize(rawValue: values["pixelSize"] ?? "xl") ?? .xl
        showSeconds = values["pixelShowSeconds"] == "true"
        showDate = values["pixelShowDate"] != "false"
        showWeek = values["pixelShowWeek"] != "false"
        weekProgress = values["pixelWeekProgress"] == "true"
        weekStartsMonday = values["pixelWeekStartsMonday"] == "true"
        uses24HourTime = values["pixel24Hour"] != "false"
        showAMPM = values["pixelShowAMPM"] == "true"
        customStyle = values["pixelCustomStyle"] != "false"
        backgroundTransparency = min(100, max(0, Double(values["pixelBackgroundTransparency"] ?? "100") ?? 100))
        timeZoneID = values["pixelTimeZone"] ?? "local"
        foregroundHex = values["pixelForeground"] ?? "#FFFFFF"
        accentHex = values["pixelAccent"] ?? "#FF4048"
        backgroundHex = values["pixelBackground"] ?? "#080A0D"
    }

    var timeZone: TimeZone {
        timeZoneID == "local" ? .current : TimeZone(identifier: timeZoneID) ?? .current
    }

    func timeText(at date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = parts.hour ?? 0
        let displayedHour = uses24HourTime ? hour : (hour % 12 == 0 ? 12 : hour % 12)
        let base = String(format: "%02d:%02d", displayedHour, parts.minute ?? 0)
        return showSeconds ? base + String(format: ":%02d", parts.second ?? 0) : base
    }

    func meridiem(at date: Date) -> String {
        guard !uses24HourTime else { return "" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return (calendar.component(.hour, from: date) < 12) ? "AM" : "PM"
    }

    func weekdayIndex(at date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let weekday = calendar.component(.weekday, from: date) // Sunday = 1.
        return (weekday - (weekStartsMonday ? 2 : 1) + 7) % 7
    }

    func dateText(at date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return formatter.string(from: date).uppercased(with: .current)
    }

    func dayOfMonth(at date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.component(.day, from: date)
    }

    static func color(_ hex: String, fallback: Color) -> Color {
        let value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.hasPrefix("#"), value.count == 7,
              let rgb = UInt32(value.dropFirst(), radix: 16) else { return fallback }
        return Color(.sRGB, red: Double((rgb >> 16) & 255) / 255,
                     green: Double((rgb >> 8) & 255) / 255,
                     blue: Double(rgb & 255) / 255, opacity: 1)
    }
}

struct PixelClockLayout {
    private static let meridiemScale: CGFloat = 0.43
    private static let meridiemGap: CGFloat = 0.4

    let unit: CGFloat
    let meridiemUnit: CGFloat
    let contentFrame: CGRect
    let calendarOrigin: CGPoint?
    let timeOrigin: CGPoint
    let meridiemOrigin: CGPoint?
    let weekOrigin: CGPoint?

    init(size: CGSize, settings: PixelClockSettings, time: String, meridiem: String) {
        let timeColumns = PixelClockGlyphs.columns(for: time)
        let meridiemColumns = meridiem.isEmpty ? 0 : Int(ceil(Self.meridiemGap + CGFloat(PixelClockGlyphs.columns(for: meridiem)) * Self.meridiemScale))
        let rightColumns = max(timeColumns + meridiemColumns, settings.showWeek ? 27 : 0)
        let rightStartColumn = settings.showDate ? 10 : 0
        let totalColumns = rightStartColumn + rightColumns
        let totalRows = settings.showDate ? 8 : (settings.showWeek ? 7 : 5)
        let inset = min(42, max(10, size.height * 0.07))
        let availableWidth = max(1, size.width - inset * 2)
        let availableHeight = max(1, size.height - inset * 2)
        unit = max(1, floor(min(availableWidth / CGFloat(totalColumns),
                                availableHeight / CGFloat(totalRows),
                                size.height * settings.size.heightFactor)))
        meridiemUnit = unit * Self.meridiemScale
        contentFrame = CGRect(x: floor((size.width - CGFloat(totalColumns) * unit) / 2),
                              y: floor((size.height - CGFloat(totalRows) * unit) / 2),
                              width: CGFloat(totalColumns) * unit,
                              height: CGFloat(totalRows) * unit)
        calendarOrigin = settings.showDate ? contentFrame.origin : nil
        // Calendar, time, and weekdays occupy integer cells of the same LED grid.
        // The optional AM/PM label is a smaller annotation beside the time.
        let rightStartX = contentFrame.minX + CGFloat(rightStartColumn) * unit
        let spareColumns = rightColumns - timeColumns - meridiemColumns
        let timeStartColumn = min(spareColumns, (spareColumns + 1) / 2 + (settings.showDate ? 1 : 0))
        timeOrigin = CGPoint(x: rightStartX + CGFloat(timeStartColumn) * unit,
                             y: contentFrame.minY + (settings.showDate ? unit : 0))
        meridiemOrigin = meridiem.isEmpty ? nil : CGPoint(x: timeOrigin.x + (CGFloat(timeColumns) + Self.meridiemGap) * unit,
                                                          y: timeOrigin.y + (5 * (unit - meridiemUnit)) / 2)
        weekOrigin = settings.showWeek ? CGPoint(x: rightStartX, y: contentFrame.minY + CGFloat(totalRows - 1) * unit) : nil
    }
}

struct PixelClockTile: View {
    let settings: PixelClockSettings

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            PixelClockFace(settings: settings, date: timeline.date)
        }
    }
}

struct PixelClockFace: View {
    let settings: PixelClockSettings
    let date: Date

    var body: some View {
        let time = settings.timeText(at: date)
        let meridiem = settings.showAMPM && !settings.uses24HourTime ? settings.meridiem(at: date) : ""
        let foreground = PixelClockSettings.color(settings.customStyle ? settings.foregroundHex : "#FFFFFF", fallback: .white)
        let accent = PixelClockSettings.color(settings.customStyle ? settings.accentHex : "#FF4048", fallback: .red)
        let background = PixelClockSettings.color(settings.customStyle ? settings.backgroundHex : "#080A0D", fallback: .black)

        Canvas { context, size in
            let layout = PixelClockLayout(size: size, settings: settings, time: time, meridiem: meridiem)
            let backgroundOpacity = settings.customStyle ? 1 - settings.backgroundTransparency / 100 : 0
            if backgroundOpacity > 0 {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(background.opacity(backgroundOpacity)))
            }
            if let origin = layout.calendarOrigin {
                PixelClockGlyphs.drawCalendar(day: settings.dayOfMonth(at: date),
                                               at: origin, unit: layout.unit,
                                               context: context, foreground: foreground, accent: accent)
            }
            PixelClockGlyphs.draw(time, at: layout.timeOrigin, unit: layout.unit,
                                  context: context, color: foreground)
            if let origin = layout.meridiemOrigin {
                PixelClockGlyphs.draw(meridiem, at: origin, unit: layout.meridiemUnit,
                                      context: context, color: foreground)
            }
            if let origin = layout.weekOrigin {
                PixelClockGlyphs.drawWeek(current: settings.weekdayIndex(at: date),
                                           fillPast: settings.weekProgress, at: origin,
                                           unit: layout.unit, context: context,
                                           foreground: foreground, accent: accent)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(time) \(meridiem) \(settings.dateText(at: date))")
    }
}

enum PixelClockGlyphs {
    private static let glyphs: [Character: [String]] = [
        "0": ["111", "101", "101", "101", "111"],
        "1": ["010", "110", "010", "010", "111"],
        "2": ["111", "001", "111", "100", "111"],
        "3": ["111", "001", "111", "001", "111"],
        "4": ["101", "101", "111", "001", "001"],
        "5": ["111", "100", "111", "001", "111"],
        "6": ["111", "100", "111", "101", "111"],
        "7": ["111", "001", "001", "001", "001"],
        "8": ["111", "101", "111", "101", "111"],
        "9": ["111", "101", "111", "001", "111"],
        ":": ["0", "1", "0", "1", "0"],
        "A": ["010", "101", "111", "101", "101"],
        "M": ["10001", "11011", "10101", "10001", "10001"],
        "P": ["110", "101", "110", "100", "100"],
        " ": ["000", "000", "000", "000", "000"]
    ]

    static func columns(for text: String) -> Int {
        max(0, text.reduce(0) { $0 + (glyphs[$1] ?? glyphs[" "]!)[0].count + 1 } - 1)
    }

    static func draw(_ text: String, at origin: CGPoint, unit: CGFloat,
                     context: GraphicsContext, color: Color) {
        var column = 0
        for character in text {
            let glyph = glyphs[character] ?? glyphs[" "]!
            for (row, pattern) in glyph.enumerated() {
                for (index, pixel) in pattern.enumerated() where pixel == "1" {
                    square(column: column + index, row: row, at: origin, unit: unit,
                           context: context, color: color)
                }
            }
            column += glyph[0].count + 1
        }
    }

    static func drawCalendar(day: Int, at origin: CGPoint, unit: CGFloat,
                             context: GraphicsContext, foreground: Color, accent: Color) {
        for row in 0..<2 {
            for column in 0..<9 {
                square(column: column, row: row, at: origin, unit: unit, context: context, color: accent)
            }
        }
        for row in 2..<8 {
            for column in 0..<9 where !calendarCutout(day: day, row: row, column: column) {
                square(column: column, row: row, at: origin, unit: unit, context: context, color: foreground)
            }
        }
    }

    static func calendarCutout(day: Int, row: Int, column: Int) -> Bool {
        guard (2..<7).contains(row) else { return false }
        let digits = Array(String(format: "%02d", min(31, max(1, day))))
        let character: Character
        let glyphColumn: Int
        switch column {
        case 1...3:
            character = digits[0]
            glyphColumn = column - 1
        case 5...7:
            character = digits[1]
            glyphColumn = column - 5
        default:
            return false
        }
        return Array(glyphs[character]![row - 2])[glyphColumn] == "1"
    }

    static func drawWeek(current: Int, fillPast: Bool, at origin: CGPoint, unit: CGFloat,
                         context: GraphicsContext, foreground: Color, accent: Color) {
        for day in 0..<7 {
            let color = day == current ? foreground :
                (fillPast && day < current ? accent : foreground.opacity(0.36))
            for segment in 0..<3 {
                square(column: day * 4 + segment, row: 0, at: origin,
                       unit: unit, context: context, color: color)
            }
        }
    }

    private static func square(column: Int, row: Int, at origin: CGPoint, unit: CGFloat,
                               context: GraphicsContext, color: Color) {
        let dot = max(1, floor(unit * 0.88))
        let rect = CGRect(x: floor(origin.x + CGFloat(column) * unit + (unit - dot) / 2),
                          y: floor(origin.y + CGFloat(row) * unit + (unit - dot) / 2),
                          width: dot, height: dot)
        context.fill(Path(rect), with: .color(color))
    }
}
