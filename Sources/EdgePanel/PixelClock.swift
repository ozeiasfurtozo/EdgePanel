import SwiftUI

struct PixelClockSettings {
    let showSeconds: Bool
    let showDate: Bool
    let showWeek: Bool
    let weekProgress: Bool
    let weekStartsMonday: Bool
    let uses24HourTime: Bool
    let timeZoneID: String
    let foregroundHex: String
    let accentHex: String
    let backgroundHex: String

    init(_ values: [String: String]) {
        showSeconds = values["pixelShowSeconds"] != "false"
        showDate = values["pixelShowDate"] != "false"
        showWeek = values["pixelShowWeek"] != "false"
        weekProgress = values["pixelWeekProgress"] != "false"
        weekStartsMonday = values["pixelWeekStartsMonday"] != "false"
        uses24HourTime = values["pixel24Hour"] != "false"
        timeZoneID = values["pixelTimeZone"] ?? "local"
        foregroundHex = values["pixelForeground"] ?? "#F4F3EE"
        accentHex = values["pixelAccent"] ?? "#FF6464"
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

    static func color(_ hex: String, fallback: Color) -> Color {
        let value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.hasPrefix("#"), value.count == 7,
              let rgb = UInt32(value.dropFirst(), radix: 16) else { return fallback }
        return Color(.sRGB, red: Double((rgb >> 16) & 255) / 255,
                     green: Double((rgb >> 8) & 255) / 255,
                     blue: Double(rgb & 255) / 255, opacity: 1)
    }
}

struct PixelClockTile: View {
    let settings: PixelClockSettings

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            GeometryReader { geometry in
                let compact = geometry.size.height < 230
                let inset = max(12, min(46, geometry.size.height * 0.065))
                let foreground = PixelClockSettings.color(settings.foregroundHex, fallback: .white)
                let accent = PixelClockSettings.color(settings.accentHex, fallback: .red)
                let background = PixelClockSettings.color(settings.backgroundHex, fallback: .black)

                ZStack {
                    RoundedRectangle(cornerRadius: max(10, min(28, geometry.size.height * 0.055)))
                        .fill(background)
                    RoundedRectangle(cornerRadius: max(10, min(28, geometry.size.height * 0.055)))
                        .strokeBorder(foreground.opacity(0.10), lineWidth: 1)

                    VStack(spacing: max(5, geometry.size.height * 0.018)) {
                        if !compact {
                            HStack(spacing: 10) {
                                PixelMark(color: accent)
                                    .frame(width: 24, height: 18)
                                Text(L("RELÓGIO // PIXEL", "PIXEL // CLOCK"))
                                    .tracking(2.5)
                                Spacer()
                                Text(settings.timeZone.abbreviation(for: timeline.date) ?? settings.timeZone.identifier)
                                    .tracking(1.5)
                            }
                            .font(.system(size: max(10, min(15, geometry.size.height * 0.028)), weight: .bold, design: .monospaced))
                            .foregroundStyle(foreground.opacity(0.55))
                        }

                        HStack(alignment: .bottom, spacing: max(8, geometry.size.width * 0.008)) {
                            PixelDigits(text: settings.timeText(at: timeline.date), color: foreground)
                                .shadow(color: foreground.opacity(0.17), radius: 8)
                            if !settings.uses24HourTime {
                                Text(settings.meridiem(at: timeline.date))
                                    .font(.system(size: max(12, min(34, geometry.size.height * 0.08)), weight: .bold, design: .monospaced))
                                    .foregroundStyle(foreground)
                                    .padding(.bottom, max(3, geometry.size.height * 0.03))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if settings.showDate && geometry.size.height >= 150 {
                            Text(settings.dateText(at: timeline.date))
                                .font(.system(size: max(11, min(23, geometry.size.height * 0.043)), weight: .semibold, design: .monospaced))
                                .tracking(2)
                                .foregroundStyle(foreground.opacity(0.83))
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                        }

                        if settings.showWeek && geometry.size.height >= 130 {
                            PixelWeekBar(currentDay: settings.weekdayIndex(at: timeline.date),
                                         fillsPastDays: settings.weekProgress,
                                         accent: accent, foreground: foreground)
                                .frame(width: min(geometry.size.width * 0.62, geometry.size.height * 1.15),
                                       height: max(5, min(13, geometry.size.height * 0.018)))
                        }
                    }
                    .padding(inset)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(settings.timeText(at: timeline.date)) \(settings.meridiem(at: timeline.date)) \(settings.dateText(at: timeline.date))")
            }
        }
    }
}

private struct PixelMark: View {
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width / 4.5, geometry.size.height / 3.5)
            ForEach(0..<12, id: \.self) { index in
                RoundedRectangle(cornerRadius: 0.6)
                    .fill(color.opacity(index == 3 || index == 8 ? 0.35 : 1))
                    .frame(width: side, height: side)
                    .position(x: CGFloat(index % 4) * side * 1.22 + side / 2,
                              y: CGFloat(index / 4) * side * 1.22 + side / 2)
            }
        }
    }
}

private struct PixelWeekBar: View {
    let currentDay: Int
    let fillsPastDays: Bool
    let accent: Color
    let foreground: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { day in
                RoundedRectangle(cornerRadius: 2)
                    .fill(day == currentDay ? accent : (fillsPastDays && day < currentDay ? accent.opacity(0.48) : foreground.opacity(0.20)))
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct PixelDigits: View {
    let text: String
    let color: Color

    var body: some View {
        Canvas { context, size in
            let glyphs = text.map { Self.glyphs[$0] ?? Self.glyphs[" "]! }
            let columnCount = glyphs.reduce(0) { $0 + $1[0].count } + max(0, glyphs.count - 1)
            guard columnCount > 0, size.width > 0, size.height > 0 else { return }
            let pitch = min(size.width / CGFloat(columnCount), size.height / 7)
            let dot = max(1, pitch * 0.78)
            let left = (size.width - CGFloat(columnCount) * pitch) / 2
            let top = (size.height - 7 * pitch) / 2
            var column = 0

            for glyph in glyphs {
                for (row, pattern) in glyph.enumerated() {
                    for (index, pixel) in pattern.enumerated() where pixel == "1" {
                        let rect = CGRect(x: left + CGFloat(column + index) * pitch + (pitch - dot) / 2,
                                          y: top + CGFloat(row) * pitch + (pitch - dot) / 2,
                                          width: dot, height: dot)
                        context.fill(Path(roundedRect: rect, cornerRadius: max(0.5, dot * 0.07)), with: .color(color))
                    }
                }
                column += glyph[0].count + 1
            }
        }
        .accessibilityHidden(true)
    }

    private static let glyphs: [Character: [String]] = [
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
        ":": ["0", "1", "1", "0", "1", "1", "0"],
        " ": ["000", "000", "000", "000", "000", "000", "000"]
    ]
}
