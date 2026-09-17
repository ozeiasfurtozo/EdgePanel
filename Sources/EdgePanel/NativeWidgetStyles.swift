import AppKit
import SwiftUI

struct NativeClockSettings {
    let timeFormat: String
    let timeZoneID: String
    let showDate: Bool
    let showSeconds: Bool
    let fontStyle: String
    let accentHex: String

    init(_ values: [String: String]) {
        timeFormat = values["clockFormat"] ?? "system"
        timeZoneID = values["clockTimeZone"] ?? "local"
        showDate = values["clockShowDate"] != "false"
        showSeconds = values["clockShowSeconds"] != "false"
        fontStyle = values["clockFont"] ?? "rounded"
        accentHex = values["nativeAccent"] ?? "#63BFE8"
    }

    var fontDesign: Font.Design {
        switch fontStyle {
        case "system": return .default
        case "mono": return .monospaced
        default: return .rounded
        }
    }

    var timeZone: TimeZone {
        timeZoneID == "local" ? .current : TimeZone(identifier: timeZoneID) ?? .current
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    func timeText(at date: Date) -> String {
        guard timeFormat == "12" || timeFormat == "24" else {
            let formatter = DateFormatter()
            formatter.locale = .current
            formatter.timeZone = timeZone
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        if timeFormat == "24" { return String(format: "%02d:%02d", hour, minute) }
        return String(format: "%d:%02d %@", hour % 12 == 0 ? 12 : hour % 12,
                      minute, hour < 12 ? "AM" : "PM")
    }

    func dateText(at date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return formatter.string(from: date)
    }

    func second(at date: Date) -> Int {
        calendar.component(.second, from: date)
    }
}

struct SmokeClockWidget: View {
    let title: String
    let compact: Bool
    let dark: Bool
    let settings: NativeClockSettings

    var body: some View {
        GeometryReader { geometry in
            let ink = dark ? Color.white : Color(red: 0.08, green: 0.13, blue: 0.19)
            let haze = PixelClockSettings.color(settings.accentHex, fallback:
                dark ? Color(red: 0.39, green: 0.75, blue: 0.91) : Color(red: 0.17, green: 0.55, blue: 0.70))
            let timeSize = min(geometry.size.height * 0.47, geometry.size.width * 0.27)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let time = settings.timeText(at: context.date)
                let date = settings.dateText(at: context.date)
                let seconds = settings.second(at: context.date)

                ZStack(alignment: .leading) {
                    Ellipse()
                        .fill(haze.opacity(dark ? 0.16 : 0.13))
                        .frame(width: geometry.size.width * 0.75,
                               height: geometry.size.height * 0.48)
                        .blur(radius: compact ? 18 : 42)
                        .offset(x: -geometry.size.width * 0.15,
                                y: geometry.size.height * 0.10)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(title.uppercased())
                                .lineLimit(1)
                            Spacer(minLength: 5)
                            if settings.timeZoneID == "local" {
                                Circle().fill(haze.opacity(0.8))
                                    .frame(width: compact ? 4 : 6, height: compact ? 4 : 6)
                            } else {
                                Text(settings.timeZone.abbreviation(for: context.date) ?? settings.timeZone.identifier)
                                    .lineLimit(1)
                            }
                        }
                        .font(.system(size: compact ? 9 : 12, weight: .semibold, design: .monospaced))
                        .tracking(compact ? 0.7 : 1.8)
                        .foregroundStyle(ink.opacity(0.52))

                        Spacer(minLength: 2)

                        ZStack(alignment: .leading) {
                            Text(time)
                                .foregroundStyle(haze.opacity(dark ? 0.55 : 0.34))
                                .blur(radius: compact ? 7 : 18)
                                .offset(x: compact ? -3 : -9, y: compact ? -2 : -6)
                            Text(time)
                                .foregroundStyle(ink.opacity(0.23))
                                .blur(radius: compact ? 3 : 8)
                                .offset(x: compact ? -1 : -3, y: compact ? -1 : -2)
                            Text(time)
                                .foregroundStyle(ink)
                                .contentTransition(.numericText())
                                .animation(.easeOut(duration: 0.7), value: time)
                        }
                        .font(.system(size: timeSize, weight: .semibold, design: settings.fontDesign))
                        .tracking(-timeSize * 0.04)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)

                        Spacer(minLength: 2)

                        if settings.showDate || settings.showSeconds {
                            HStack(alignment: .firstTextBaseline) {
                                if settings.showDate {
                                    Text(date.uppercased())
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                Spacer(minLength: 5)
                                if settings.showSeconds {
                                    Text(String(format: "%02d", seconds))
                                        .monospacedDigit()
                                }
                            }
                            .font(.system(size: compact ? 9 : 13, weight: .medium, design: .monospaced))
                            .tracking(compact ? 0 : 1)
                            .foregroundStyle(ink.opacity(0.56))
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}

struct PerformanceWidget: View {
    let tile: Tile
    @ObservedObject var metrics: SystemMetrics
    let compact: Bool
    let dark: Bool

    private var ink: Color {
        dark ? .white : Color(red: 0.08, green: 0.13, blue: 0.19)
    }

    private var accent: Color {
        let fallback: Color
        switch tile.kind {
        case .cpu: fallback = dark ? Color(red: 0.39, green: 0.76, blue: 1) : Color(red: 0.07, green: 0.44, blue: 0.72)
        case .memory: fallback = dark ? Color(red: 0.72, green: 0.58, blue: 1) : Color(red: 0.43, green: 0.26, blue: 0.72)
        default: fallback = dark ? Color(red: 0.35, green: 0.86, blue: 0.72) : Color(red: 0.04, green: 0.49, blue: 0.39)
        }
        return PixelClockSettings.color(tile.settings["nativeAccent"] ?? "", fallback: fallback)
    }

    private var showsGraph: Bool { tile.settings["nativeShowGraph"] != "false" }

    private var warningAt: Double {
        Double(min(100, max(50, Int(tile.settings["nativeWarningAt"] ?? "") ?? 85)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 11) {
            HStack(spacing: compact ? 5 : 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent)
                    .frame(width: compact ? 3 : 4, height: compact ? 11 : 15)
                Text(tile.title.uppercased())
                    .font(.system(size: compact ? 9 : 12, weight: .bold, design: .monospaced))
                    .tracking(compact ? 0.7 : 1.5)
                    .lineLimit(1)
                    .foregroundStyle(ink.opacity(0.76))
                Spacer(minLength: 3)
                Text("LIVE")
                    .font(.system(size: compact ? 8 : 10, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(accent)
            }

            if tile.kind == .network {
                NetworkChannel(label: L("RECEBIDO", "DOWNLOAD"), symbol: "arrow.down",
                               bytesPerSecond: metrics.downloadBytesPerSecond,
                               history: metrics.downloadHistory,
                               accent: accent.opacity(0.78), showGraph: showsGraph,
                               compact: compact, ink: ink)
                NetworkChannel(label: L("ENVIADO", "UPLOAD"), symbol: "arrow.up",
                               bytesPerSecond: metrics.uploadBytesPerSecond,
                               history: metrics.uploadHistory,
                               accent: accent, showGraph: showsGraph, compact: compact, ink: ink)
            } else {
                let value = tile.kind == .cpu ? metrics.cpuPercent : metrics.memoryPercent
                let history = tile.kind == .cpu ? metrics.cpuHistory : metrics.memoryHistory
                let activeAccent = value >= warningAt ? Color(red: 1, green: 0.69, blue: 0.29) : accent

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(value.rounded()))")
                        .font(.system(size: compact ? 31 : 60, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("%")
                        .font(.system(size: compact ? 15 : 25, weight: .medium, design: .rounded))
                        .foregroundStyle(activeAccent)
                    Spacer(minLength: 2)
                    if tile.kind == .memory {
                        Text(String(format: "%.1f GB", metrics.memoryUsedGB))
                            .font(.system(size: compact ? 9 : 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(ink.opacity(0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .foregroundStyle(ink)

                if showsGraph {
                    Sparkline(values: history, ceiling: 100, accent: activeAccent)
                        .frame(maxHeight: .infinity)
                        .accessibilityHidden(true)
                } else {
                    Spacer(minLength: 0)
                    SegmentedGauge(value: value, accent: activeAccent, compact: compact,
                                   inactive: ink.opacity(0.12))
                }

                HStack {
                    Text(L("HISTÓRICO", "HISTORY"))
                    Spacer(minLength: 2)
                    Text(L("AGORA", "NOW"))
                }
                .font(.system(size: compact ? 8 : 10, weight: .medium, design: .monospaced))
                .tracking(compact ? 0 : 0.7)
                .foregroundStyle(ink.opacity(0.42))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct StorageWidget: View {
    let tile: Tile
    @ObservedObject var metrics: SystemMetrics
    let compact: Bool
    let dark: Bool

    private var ink: Color {
        dark ? .white : Color(red: 0.08, green: 0.13, blue: 0.19)
    }

    private var accent: Color {
        PixelClockSettings.color(tile.settings["nativeAccent"] ?? "", fallback:
            dark ? Color(red: 1, green: 0.73, blue: 0.34) : Color(red: 0.68, green: 0.38, blue: 0.06))
    }

    private var warningAt: Double {
        Double(min(100, max(50, Int(tile.settings["nativeWarningAt"] ?? "") ?? 85)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 11) {
            HStack(spacing: compact ? 5 : 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent)
                    .frame(width: compact ? 3 : 4, height: compact ? 11 : 15)
                Text(tile.title.uppercased())
                    .font(.system(size: compact ? 9 : 12, weight: .bold, design: .monospaced))
                    .tracking(compact ? 0.7 : 1.5)
                    .lineLimit(1)
                    .foregroundStyle(ink.opacity(0.76))
                Spacer(minLength: 3)
                Text(metrics.storageSnapshot?.volumeName.uppercased() ?? L("INDISPONÍVEL", "UNAVAILABLE"))
                    .font(.system(size: compact ? 8 : 10, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(ink.opacity(0.52))
            }

            if let storage = metrics.storageSnapshot {
                let used = storage.usedPercent
                let activeAccent = used >= warningAt ? Color(red: 1, green: 0.43, blue: 0.31) : accent

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(used.rounded()))")
                        .font(.system(size: compact ? 31 : 60, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("%")
                        .font(.system(size: compact ? 15 : 25, weight: .medium, design: .rounded))
                        .foregroundStyle(activeAccent)
                    Spacer(minLength: 2)
                    Text("\(StorageSnapshot.formatted(storage.availableBytes)) \(L("LIVRES", "FREE"))")
                        .font(.system(size: compact ? 9 : 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(ink.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
                .foregroundStyle(ink)

                if tile.settings["nativeShowGraph"] == "true" {
                    Sparkline(values: metrics.storageHistory, ceiling: 100, accent: activeAccent)
                        .frame(maxHeight: .infinity)
                        .accessibilityHidden(true)
                } else {
                    Spacer(minLength: 0)
                    SegmentedGauge(value: used, accent: activeAccent, compact: compact,
                                   inactive: ink.opacity(0.12))
                }

                HStack {
                    Text("\(StorageSnapshot.formatted(storage.usedBytes)) \(L("USADOS", "USED"))")
                    Spacer(minLength: 2)
                    Text("\(StorageSnapshot.formatted(storage.totalBytes)) TOTAL")
                }
                .font(.system(size: compact ? 8 : 10, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(ink.opacity(0.5))
            } else {
                Spacer(minLength: 0)
                Text("—")
                    .font(.system(size: compact ? 31 : 60, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink.opacity(0.7))
                Text(L("Não foi possível ler o espaço do disco", "Could not read disk capacity"))
                    .font(.system(size: compact ? 9 : 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(ink.opacity(0.5))
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct NetworkChannel: View {
    let label: String
    let symbol: String
    let bytesPerSecond: Double
    let history: [Double]
    let accent: Color
    let showGraph: Bool
    let compact: Bool
    let ink: Color

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 1 : 4) {
            HStack(spacing: compact ? 4 : 7) {
                Image(systemName: symbol)
                    .font(.system(size: compact ? 9 : 13, weight: .bold))
                    .foregroundStyle(accent)
                Text(label)
                    .font(.system(size: compact ? 8 : 10, weight: .medium, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(ink.opacity(0.55))
                Spacer(minLength: 2)
                Text(Self.rate(bytesPerSecond))
                    .font(.system(size: compact ? 12 : 21, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if showGraph {
                Sparkline(values: history, ceiling: max(1_024, (history.max() ?? 0) * 1.15), accent: accent)
                    .frame(maxHeight: .infinity)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private static func rate(_ bytes: Double) -> String {
        if bytes >= 1_000_000 { return String(format: "%.1f MB/s", bytes / 1_000_000) }
        if bytes >= 1_000 { return String(format: "%.0f KB/s", bytes / 1_000) }
        return String(format: "%.0f B/s", bytes)
    }
}

private struct SegmentedGauge: View {
    let value: Double
    let accent: Color
    let compact: Bool
    let inactive: Color

    var body: some View {
        HStack(spacing: compact ? 2 : 4) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: compact ? 2 : 3)
                    .fill(Double(index + 1) <= value / 5 ? accent : inactive)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: compact ? 12 : 25)
        .accessibilityHidden(true)
    }
}

private struct Sparkline: View {
    let values: [Double]
    let ceiling: Double
    let accent: Color

    var body: some View {
        GeometryReader { geometry in
            let points = points(in: geometry.size)

            ZStack {
                Path { path in
                    for fraction in [0.25, 0.5, 0.75] {
                        let y = geometry.size.height * fraction
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(accent.opacity(0.12), lineWidth: 1)

                Path { path in
                    guard let first = points.first, let last = points.last else { return }
                    path.move(to: CGPoint(x: first.x, y: geometry.size.height))
                    path.addLine(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                    path.addLine(to: CGPoint(x: last.x, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [accent.opacity(0.38), accent.opacity(0.02)],
                                     startPoint: .top, endPoint: .bottom))

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                }
                .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                if let last = points.last {
                    Circle().fill(accent)
                        .frame(width: 5, height: 5)
                        .position(last)
                }
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        let samples = values.isEmpty ? [0.0, 0.0] : (values.count == 1 ? [values[0], values[0]] : values)
        let maximum = max(1, ceiling)
        return samples.enumerated().map { index, value in
            let x = 2 + (size.width - 4) * CGFloat(index) / CGFloat(samples.count - 1)
            let fraction = min(1, max(0, value / maximum))
            let y = size.height - 2 - (size.height - 4) * fraction
            return CGPoint(x: x, y: y)
        }
    }
}

struct ApplicationWidget: View {
    let tile: Tile
    let editing: Bool
    let ink: Color

    private var validApp: Bool {
        !tile.value.isEmpty && FileManager.default.fileExists(atPath: tile.value)
    }

    private var appName: String {
        validApp ? URL(fileURLWithPath: tile.value).deletingPathExtension().lastPathComponent :
            L("Escolha um app", "Choose an app")
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 150 || geometry.size.height < 150
            let largeIcon = tile.settings["launcherIconSize"] == "large"
            let iconSide = min(geometry.size.height * (largeIcon ? 0.64 : 0.54),
                               geometry.size.width * (largeIcon ? 0.72 : 0.60))

            Button {
                guard validApp else { return }
                NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: tile.value),
                                                   configuration: NSWorkspace.OpenConfiguration())
            } label: {
                VStack(spacing: compact ? 3 : 8) {
                    Spacer(minLength: 0)
                    Group {
                        if validApp {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: tile.value))
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Image(systemName: "square.dashed")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(ink.opacity(0.45))
                                .padding(iconSide * 0.20)
                        }
                    }
                    .frame(width: iconSide, height: iconSide)
                    Text(appName)
                        .font(.system(size: compact ? 11 : min(22, geometry.size.width * 0.10),
                                      weight: .medium, design: .rounded))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, compact ? 3 : 10)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(editing || !validApp)
            .accessibilityLabel(validApp ? L("Abrir \(appName)", "Open \(appName)") :
                L("Escolha um app no editor", "Choose an app in the editor"))
        }
    }
}
