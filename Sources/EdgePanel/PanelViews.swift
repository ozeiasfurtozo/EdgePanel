import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DashboardView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 450 || geometry.size.width < 1450
            ZStack {
                if let page = model.currentPage {
                    pageSurface(page: page, compact: compact)
                        .id(page.id)
                        .transition(pageTransition)
                } else {
                    DashboardBackdrop(page: nil, dark: model.config.darkMode, store: model.store)
                }
                if model.calibration {
                    CalibrationView(model: model)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .preferredColorScheme(model.config.darkMode ? .dark : .light)
    }

    private var pageTransition: AnyTransition {
        let down = model.pageNavigationDirection > 0
        return .asymmetric(
            insertion: .offset(y: down ? 72 : -72).combined(with: .opacity),
            removal: .offset(y: down ? -72 : 72).combined(with: .opacity)
        )
    }

    private func pageSurface(page: DashboardPage, compact: Bool) -> some View {
        ZStack {
            DashboardBackdrop(page: page, dark: model.config.darkMode, store: model.store)
            if page.tiles.count == 1, let tile = page.tiles.first,
               [.icue, .pixelClock, .pixelDash, .actionDeck].contains(tile.kind),
               tile.x == 0, tile.y == 0, tile.width == 16, tile.height == 4 {
                BoardView(model: model, page: page, editing: false)
            } else {
                VStack(spacing: 0) {
                    header(page: page, compact: compact)
                        .frame(height: compact ? 52 : 76)
                        .padding(.horizontal, compact ? 8 : 16)
                        .padding(.top, compact ? 4 : 9)
                        .padding(.bottom, compact ? 4 : 9)
                    ZStack {
                        BoardView(model: model, page: page, editing: false)
                        if page.tiles.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: compact ? 30 : 48, weight: .ultraLight))
                                Text(L("Esta página está pronta para widgets", "This page is ready for widgets"))
                                    .font(.system(size: compact ? 15 : 21, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(DashboardColors.foreground(page: page, dark: model.config.darkMode).opacity(0.5))
                        }
                    }
                    .padding(.horizontal, compact ? 8 : 16)
                    .padding(.bottom, compact ? 8 : 16)
                }
            }
        }
    }

    private func header(page: DashboardPage, compact: Bool) -> some View {
        let ink = DashboardColors.foreground(page: page, dark: model.config.darkMode)
        let light = DashboardColors.isLight(page: page, dark: model.config.darkMode)
        return HStack(spacing: compact ? 9 : 15) {
            EdgeMark()
                .frame(width: compact ? 29 : 39, height: compact ? 29 : 39)
            VStack(alignment: .leading, spacing: 2) {
                Text("EDGE / PANEL")
                    .font(.system(size: compact ? 10 : 12, weight: .heavy, design: .monospaced))
                    .tracking(compact ? 1.5 : 2.5)
                    .foregroundStyle(DashboardColors.isLight(page: page, dark: model.config.darkMode) ?
                        Color(red: 0.04, green: 0.43, blue: 0.54) : Color.cyan.opacity(0.85))
                Text(page.name)
                    .font(.system(size: compact ? 16 : 22, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(ink)
            }
            Spacer(minLength: 8)
            Text(L("\(page.tiles.count) WIDGETS", "\(page.tiles.count) WIDGETS"))
                .font(.system(size: compact ? 9 : 11, weight: .bold, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(ink.opacity(0.7))
                .padding(.horizontal, compact ? 7 : 10)
                .padding(.vertical, compact ? 5 : 7)
                .background(ink.opacity(0.08), in: Capsule())
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                Text(timeline.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
                    .font(.system(size: compact ? 10 : 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(ink.opacity(0.62))
                    .lineLimit(1)
            }
            if let profile = model.config.profiles.first(where: { $0.id == model.config.selectedProfileID }),
               let index = profile.pages.firstIndex(where: { $0.id == page.id }), profile.pages.count > 1 {
                HStack(spacing: compact ? 2 : 5) {
                    Button { model.navigatePage(by: -1) } label: {
                        Image(systemName: "chevron.up")
                            .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)
                    }
                    .disabled(index == 0)
                    .help(L("Página anterior · \(model.globalPageShortcutModifiers) ↑",
                            "Previous page · \(model.globalPageShortcutModifiers) ↑"))
                    Text(String(format: "%02d / %02d", index + 1, profile.pages.count))
                        .font(.system(size: compact ? 10 : 12, weight: .bold, design: .monospaced))
                        .frame(minWidth: compact ? 43 : 57)
                    Button { model.navigatePage(by: 1) } label: {
                        Image(systemName: "chevron.down")
                            .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)
                    }
                    .disabled(index == profile.pages.count - 1)
                    .help(L("Próxima página · \(model.globalPageShortcutModifiers) ↓",
                            "Next page · \(model.globalPageShortcutModifiers) ↓"))
                }
                .buttonStyle(.plain)
                .foregroundStyle(ink)
                .background(ink.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 11))
            }
        }
        .padding(.horizontal, compact ? 12 : 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(light ? Color.white.opacity(0.78) : Color.black.opacity(page.backgroundImage == nil ? 0.31 : 0.57),
                    in: RoundedRectangle(cornerRadius: compact ? 12 : 17))
        .overlay(RoundedRectangle(cornerRadius: compact ? 12 : 17)
            .strokeBorder(light ? Color.black.opacity(0.10) : Color.white.opacity(0.14), lineWidth: 1))
    }
}

enum DashboardColors {
    static func backgroundHex(dark: Bool) -> String { dark ? "#090E17" : "#E8F0F7" }

    static func background(page: DashboardPage?, dark: Bool) -> Color {
        PixelClockSettings.color(page?.backgroundHex ?? "", fallback:
            PixelClockSettings.color(backgroundHex(dark: dark), fallback: .black))
    }

    static func isLight(page: DashboardPage?, dark: Bool) -> Bool {
        if page?.backgroundImage != nil { return false }
        let hex = page?.backgroundHex ?? backgroundHex(dark: dark)
        guard hex.hasPrefix("#"), hex.count == 7,
              let rgb = UInt32(hex.dropFirst(), radix: 16) else { return !dark }
        let red = Double((rgb >> 16) & 255) / 255
        let green = Double((rgb >> 8) & 255) / 255
        let blue = Double(rgb & 255) / 255
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue > 0.56
    }

    static func foreground(page: DashboardPage?, dark: Bool) -> Color {
        isLight(page: page, dark: dark) ? Color(red: 0.07, green: 0.11, blue: 0.15) : .white
    }
}

struct DashboardBackdrop: View {
    let page: DashboardPage?
    let dark: Bool
    let store: PanelStore

    var body: some View {
        ZStack {
            DashboardColors.background(page: page, dark: dark)
            if let filename = page?.backgroundImage,
               let image = store.backgroundImage(named: filename) {
                BackgroundImageLayer(image: image,
                                     scale: page?.backgroundScale ?? "fill",
                                     horizontal: page?.backgroundHorizontal ?? "center",
                                     vertical: page?.backgroundVertical ?? "center")
            }
        }
        .ignoresSafeArea()
    }
}

struct EdgeMark: View {
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.25)
                    .fill(Color(red: 0.04, green: 0.16, blue: 0.22))
                RoundedRectangle(cornerRadius: side * 0.25)
                    .strokeBorder(Color.cyan.opacity(0.6), lineWidth: max(1, side * 0.035))
                RoundedRectangle(cornerRadius: side * 0.11)
                    .fill(Color(red: 0.02, green: 0.08, blue: 0.13))
                    .padding(side * 0.19)
                HStack(spacing: side * 0.07) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: side * 0.045)
                            .fill(index == 1 ? Color(red: 0.98, green: 0.72, blue: 0.29) : .cyan)
                    }
                }
                .padding(.horizontal, side * 0.29)
                .padding(.vertical, side * 0.39)
            }
        }
        .accessibilityHidden(true)
    }
}

struct CalibrationView: View {
    @ObservedObject var model: AppModel
    private let positions: [CGPoint] = [CGPoint(x: 0.08, y: 0.14), CGPoint(x: 0.92, y: 0.14), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.08, y: 0.86), CGPoint(x: 0.92, y: 0.86)]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.92)
                Text(L("Toque nos cinco alvos", "Tap the five targets"))
                    .font(.system(size: 25, weight: .semibold)).foregroundStyle(.white)
                    .position(x: geometry.size.width / 2, y: 45)
                Button(L("Cancelar", "Cancel")) { model.calibration = false }
                    .position(x: geometry.size.width - 75, y: 45)
                ForEach(0..<5, id: \.self) { index in
                    Button {
                        model.calibrationHit(index)
                    } label: {
                        Image(systemName: model.calibrationHits.contains(index) ? "checkmark.circle.fill" : "scope")
                            .font(.system(size: 52)).foregroundStyle(model.calibrationHits.contains(index) ? .green : .cyan)
                            .frame(width: 90, height: 90)
                    }
                    .buttonStyle(.plain)
                    .position(x: geometry.size.width * positions[index].x, y: geometry.size.height * positions[index].y)
                }
            }
        }
    }
}

struct BoardView: View {
    @ObservedObject var model: AppModel
    let page: DashboardPage
    let editing: Bool
    private let columns = 16.0
    private let rows = 4.0

    var body: some View {
        GeometryReader { geometry in
            let cellW = geometry.size.width / columns
            let cellH = geometry.size.height / rows
            ZStack(alignment: .topLeading) {
                if editing {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { model.selectedTileID = nil }
                }
                if editing {
                    Path { path in
                        for x in 0...16 {
                            let px = Double(x) * cellW
                            path.move(to: CGPoint(x: px, y: 0)); path.addLine(to: CGPoint(x: px, y: geometry.size.height))
                        }
                        for y in 0...4 {
                            let py = Double(y) * cellH
                            path.move(to: CGPoint(x: 0, y: py)); path.addLine(to: CGPoint(x: geometry.size.width, y: py))
                        }
                    }
                    .stroke(.white.opacity(model.config.darkMode ? 0.08 : 0.15), lineWidth: 1)
                }
                ForEach(page.tiles) { tile in
                    let shown = model.displayedTile(tile)
                    TileSurface(model: model, metrics: model.metrics, tile: shown, editing: editing)
                        .frame(width: Double(shown.width) * cellW - (editing || ![.icue, .pixelClock, .pixelDash, .actionDeck].contains(shown.kind) ? 8 : 0),
                               height: Double(shown.height) * cellH - (editing || ![.icue, .pixelClock, .pixelDash, .actionDeck].contains(shown.kind) ? 8 : 0))
                        .overlay(alignment: .bottomTrailing) {
                            if editing && model.selectedTileID == tile.id {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(model.tilePreviewRejected ? .red : .cyan)
                                    .padding(8)
                                    .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .gesture(editing ? DragGesture(minimumDistance: 4, coordinateSpace: .named("edge-board"))
                            .onChanged { value in previewDrag(value, tile: tile, cellW: cellW, cellH: cellH) }
                            .onEnded { value in
                                previewDrag(value, tile: tile, cellW: cellW, cellH: cellH)
                                model.commitTilePreview(tile.id)
                            } : nil)
                        .position(x: (Double(shown.x) + Double(shown.width) / 2) * cellW,
                                  y: (Double(shown.y) + Double(shown.height) / 2) * cellH)
                }
            }
            .coordinateSpace(name: "edge-board")
        }
    }

    private func previewDrag(_ value: DragGesture.Value, tile: Tile, cellW: CGFloat, cellH: CGFloat) {
        let localX = value.startLocation.x - Double(tile.x) * cellW
        let localY = value.startLocation.y - Double(tile.y) * cellH
        let resize = localX > Double(tile.width) * cellW - 42 &&
            localY > Double(tile.height) * cellH - 42 && model.selectedTileID == tile.id
        model.previewTile(tile.id) { update in
            if resize {
                update.width += Int((value.translation.width / cellW).rounded())
                update.height += Int((value.translation.height / cellH).rounded())
            } else {
                update.x += Int((value.translation.width / cellW).rounded())
                update.y += Int((value.translation.height / cellH).rounded())
            }
        }
    }
}

struct TileSurface: View {
    @ObservedObject var model: AppModel
    @ObservedObject var metrics: SystemMetrics
    let tile: Tile
    let editing: Bool

    private var customBackground: HexColor? {
        guard [.clock, .cpu, .memory, .network, .timer, .web].contains(tile.kind) else { return nil }
        return HexColor(hex: tile.settings["nativeBackground"])
    }

    private var surfaceDark: Bool {
        customBackground.map { !$0.isLight } ?? model.config.darkMode
    }

    private var surfaceInk: Color {
        surfaceDark ? .white : Color(red: 0.08, green: 0.13, blue: 0.19)
    }

    @ViewBuilder var body: some View {
        if tile.kind == .actionDeck {
            ActionDeckTile(model: model, tile: tile, editing: editing)
                .overlay {
                    if editing && model.selectedTileID == tile.id {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(model.tilePreviewRejected ? Color.red : Color.cyan, lineWidth: 2)
                    }
                }
                .gesture(editing ? TapGesture().onEnded { model.selectedTileID = tile.id } : nil)
        } else if tile.kind == .pixelClock {
            PixelClockTile(settings: PixelClockSettings(tile.settings))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .overlay {
                    if editing && model.selectedTileID == tile.id {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(model.tilePreviewRejected ? Color.red : Color.cyan, lineWidth: 2)
                            .allowsHitTesting(false)
                    }
                }
                .gesture(editing ? TapGesture().onEnded { model.selectedTileID = tile.id } : nil)
        } else if tile.kind == .pixelDash {
            PixelDashTile(model: model, metrics: model.metrics, tile: tile)
                .allowsHitTesting(!editing)
                .overlay {
                    if editing && model.selectedTileID == tile.id {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(model.tilePreviewRejected ? Color.red : Color.cyan, lineWidth: 2)
                            .allowsHitTesting(false)
                    }
                }
                .contentShape(Rectangle())
                .gesture(editing ? TapGesture().onEnded { model.selectedTileID = tile.id } : nil)
        } else if !editing && tile.kind == .icue {
            content(compact: false).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if tile.kind == .launcher {
            ApplicationWidget(tile: tile, editing: editing,
                              ink: DashboardColors.foreground(page: model.currentPage, dark: model.config.darkMode))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .overlay {
                    if editing && model.selectedTileID == tile.id {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(model.tilePreviewRejected ? Color.red : Color.cyan, lineWidth: 2)
                    }
                }
                .gesture(editing ? TapGesture().onEnded { model.selectedTileID = tile.id } : nil)
        } else if [.clock, .cpu, .memory, .network].contains(tile.kind) {
            styledContent
        } else {
            framedContent
        }
    }

    private var styledContent: some View {
        GeometryReader { geometry in
            let compact = editing || geometry.size.height < 160 || geometry.size.width < 310
            let inset: CGFloat = editing ? 10 : (compact ? 12 : 19)
            let corner: CGFloat = editing ? 12 : (compact ? 15 : 22)
            let dark = surfaceDark

            styledWidget(compact: compact, dark: dark)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(inset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if let customBackground {
                        RoundedRectangle(cornerRadius: corner).fill(customBackground.color)
                    } else {
                        RoundedRectangle(cornerRadius: corner)
                            .fill(LinearGradient(colors: dark ?
                                [Color(red: 0.075, green: 0.10, blue: 0.15), Color(red: 0.035, green: 0.055, blue: 0.09)] :
                                [Color.white, Color(red: 0.94, green: 0.97, blue: 0.985)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: corner))
                .overlay {
                    RoundedRectangle(cornerRadius: corner)
                        .strokeBorder(model.selectedTileID == tile.id && editing ?
                            (model.tilePreviewRejected ? Color.red : Color.cyan) :
                            (dark ? cardAccent.opacity(0.27) : Color.black.opacity(0.12)),
                            lineWidth: model.selectedTileID == tile.id && editing ? 2 : 1)
                }
                .shadow(color: Color.black.opacity(dark ? 0.25 : 0.08), radius: editing ? 0 : 14, y: editing ? 0 : 5)
                .contentShape(RoundedRectangle(cornerRadius: corner))
                .gesture(editing ? TapGesture().onEnded { model.selectedTileID = tile.id } : nil)
        }
    }

    @ViewBuilder private func styledWidget(compact: Bool, dark: Bool) -> some View {
        switch tile.kind {
        case .clock:
            SmokeClockWidget(title: tile.title, compact: compact, dark: dark,
                             settings: NativeClockSettings(tile.settings))
        case .cpu, .memory, .network:
            PerformanceWidget(tile: tile, metrics: metrics, compact: compact, dark: dark)
        default:
            EmptyView()
        }
    }

    private var framedContent: some View {
        GeometryReader { geometry in
            let compact = editing || geometry.size.height < 160 || geometry.size.width < 310
            let inset: CGFloat = editing ? 10 : (compact ? 12 : 19)
            let corner: CGFloat = editing ? 12 : (compact ? 15 : 22)
            let dark = surfaceDark
            VStack(alignment: .leading, spacing: compact ? 6 : 11) {
                HStack(spacing: compact ? 6 : 10) {
                    Image(systemName: symbol)
                        .font(.system(size: compact ? 12 : 16, weight: .semibold))
                        .foregroundStyle(cardAccent)
                        .frame(width: compact ? 23 : 32, height: compact ? 23 : 32)
                        .background(cardAccent.opacity(dark ? 0.16 : 0.13),
                                    in: RoundedRectangle(cornerRadius: compact ? 6 : 9))
                    Text(tile.title)
                        .font(.system(size: editing ? 11 : (compact ? 13 : 18), weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                    if !editing && [.cpu, .memory, .network].contains(tile.kind) {
                        Circle().fill(cardAccent).frame(width: 5, height: 5)
                    }
                }
                if editing && (tile.kind == .web || tile.kind == .icue) {
                    Text(tile.kind == .web ? tile.value : (model.imported(tile.importedID)?.name ?? "iCUE"))
                        .font(.system(size: 11)).lineLimit(2).foregroundStyle(surfaceInk.opacity(0.65))
                } else {
                    content(compact: compact)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: compact ? .topLeading : .leading)
                }
            }
            .padding(inset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(surfaceInk)
            .background {
                if let customBackground {
                    RoundedRectangle(cornerRadius: corner).fill(customBackground.color)
                } else {
                    RoundedRectangle(cornerRadius: corner)
                        .fill(LinearGradient(colors: dark ?
                            [Color(red: 0.085, green: 0.13, blue: 0.20), Color(red: 0.055, green: 0.085, blue: 0.14)] :
                            [Color.white, Color(red: 0.965, green: 0.982, blue: 0.99)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(cardAccent)
                    .frame(width: compact ? 30 : 52, height: 3)
                    .padding(.leading, inset)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: corner)
                    .strokeBorder(model.selectedTileID == tile.id && editing ?
                        (model.tilePreviewRejected ? Color.red : Color.cyan) :
                        (dark ? cardAccent.opacity(0.17) : cardAccent.opacity(0.21)),
                        lineWidth: model.selectedTileID == tile.id && editing ? 2 : 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.black.opacity(dark ? 0.22 : 0.08), radius: editing ? 0 : 13, y: editing ? 0 : 5)
            .contentShape(RoundedRectangle(cornerRadius: corner))
            .gesture(editing ? TapGesture().onEnded { model.selectedTileID = tile.id } : nil)
        }
    }

    @ViewBuilder private func content(compact: Bool) -> some View {
        switch tile.kind {
        case .clock, .cpu, .memory, .network, .launcher:
            EmptyView() // These native tiles use styledContent instead of the generic frame.
        case .pixelClock:
            PixelClockTile(settings: PixelClockSettings(tile.settings))
        case .pixelDash:
            PixelDashTile(model: model, metrics: model.metrics, tile: tile)
        case .actionDeck:
            ActionDeckTile(model: model, tile: tile, editing: editing)
        case .timer:
            TimerTile(editing: editing, compact: compact, initialMinutes: max(1, Int(tile.value) ?? 5),
                      accent: cardAccent).id(tile.value)
        case .web:
            if !tile.value.isEmpty { WebTileView(urlString: tile.value).clipShape(RoundedRectangle(cornerRadius: 8)) }
            else { Text(L("Configure o endereço no editor", "Set the address in the editor")).foregroundStyle(surfaceInk.opacity(0.65)) }
        case .icue:
            if let imported = model.imported(tile.importedID), imported.compatible {
                ImportedWidgetView(tile: tile, imported: imported, libraryURL: model.store.libraryURL,
                                   deviceID: model.config.deviceID, darkMode: model.config.darkMode,
                                   metrics: model.metrics)
            } else { Text(L("Widget indisponível", "Widget unavailable")) }
        }
    }

    private var cardAccent: Color {
        let fallback: Color
        switch tile.kind {
        case .clock, .pixelClock: fallback = Color(red: 0.31, green: 0.82, blue: 0.96)
        case .pixelDash: fallback = Color(red: 0.99, green: 0.73, blue: 0.34)
        case .actionDeck: fallback = Color(red: 0.30, green: 0.85, blue: 0.94)
        case .timer: fallback = model.config.darkMode ?
            Color(red: 0.99, green: 0.73, blue: 0.34) : Color(red: 0.66, green: 0.35, blue: 0.04)
        case .cpu: fallback = Color(red: 0.39, green: 0.76, blue: 1)
        case .memory: fallback = Color(red: 0.72, green: 0.58, blue: 1)
        case .network: fallback = Color(red: 0.35, green: 0.86, blue: 0.72)
        case .launcher: fallback = Color(red: 0.67, green: 0.89, blue: 0.48)
        case .web, .icue: fallback = model.config.darkMode ?
            Color(red: 0.42, green: 0.79, blue: 0.94) : Color(red: 0.08, green: 0.42, blue: 0.57)
        }
        return PixelClockSettings.color(tile.settings["nativeAccent"] ?? "", fallback: fallback)
    }

    private var symbol: String {
        switch tile.kind {
        case .clock: return "clock"
        case .pixelClock: return "square.grid.3x3.fill"
        case .pixelDash: return "square.grid.3x3.topleft.filled"
        case .actionDeck: return "square.grid.4x3.fill"
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .network: return "network"
        case .launcher: return "app"
        case .timer: return "timer"
        case .web: return "globe"
        case .icue: return "square.grid.2x2"
        }
    }

}

struct TimerTile: View {
    let editing: Bool
    let compact: Bool
    let initialMinutes: Int
    let accent: Color
    @State private var deadline: Date?
    @State private var duration: Double

    init(editing: Bool, compact: Bool, initialMinutes: Int, accent: Color) {
        self.editing = editing
        self.compact = compact
        self.initialMinutes = initialMinutes
        self.accent = accent
        _duration = State(initialValue: Double(initialMinutes * 60))
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = deadline.map { max(0, Int($0.timeIntervalSince(context.date))) } ?? Int(duration)
            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                    .font(.system(size: editing ? 28 : (compact ? 38 : 60), weight: .light, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                    .foregroundStyle(accent)
                if !editing {
                    HStack(spacing: compact ? 8 : 12) {
                        Button(deadline == nil ? L("Iniciar", "Start") : L("Pausar", "Pause")) {
                            if let deadline { duration = max(0, deadline.timeIntervalSinceNow); self.deadline = nil }
                            else { deadline = Date().addingTimeInterval(duration) }
                        }
                        Button(L("Repor", "Reset")) { deadline = nil; duration = Double(initialMinutes * 60) }
                    }
                    .font(.system(size: compact ? 12 : 15, weight: .semibold))
                    .buttonStyle(.borderless)
                    .tint(accent)
                }
            }
        }
    }
}
