import AppKit
import Combine
import ServiceManagement
import SwiftUI

enum ActionDeckPreset {
    case mini, compact, fullPage
}

@MainActor final class AppModel: ObservableObject {
    let store: PanelStore
    let metrics = SystemMetrics()
    let displays = DisplayCatalog()
    lazy var brightness = BrightnessController(targetDisplay: { [weak self] in
        guard let self,
              let display = self.displays.resolve(self.config.selectedDisplay),
              display.identity.vendor == 0x0E58,
              display.name.localizedCaseInsensitiveContains("XENEON") else { return nil }
        return display.identity
    })
    lazy var touch = TouchController(
        targetDisplay: { [weak self] in
            guard let self,
                  let display = self.displays.resolve(self.config.selectedDisplay),
                  display.identity.vendor == 0x0E58 else { return nil }
            return display.id
        },
        orientation: { [weak self] in self?.config.touchOrientation ?? TouchOrientation() }
    )

    @Published var config: DashboardConfig { didSet { store.save(config); onDashboardChange?() } }
    @Published var imports: [ImportedWidget] { didSet { store.saveImports(imports) } }
    @Published var selectedTileID: UUID?
    @Published private(set) var tilePreview: Tile?
    @Published private(set) var tilePreviewRejected = false
    @Published var message = ""
    @Published var globalPageShortcutModifiers = "Control–Shift"
    @Published var deckMessage = ""
    @Published var libraryOpenRequest = 0
    @Published var calibration = false
    @Published var calibrationHits: Set<Int> = []
    private(set) var pageNavigationDirection = 1
    var onDashboardChange: (() -> Void)?
    var lastExternalApplication: NSRunningApplication?

    init(store: PanelStore = PanelStore()) {
        self.store = store
        config = store.load()
        imports = store.loadImports()
    }

    var profileIndex: Int? { config.profiles.firstIndex { $0.id == config.selectedProfileID } }
    var pageIndex: Int? {
        guard let p = profileIndex else { return nil }
        return config.profiles[p].pages.firstIndex { $0.id == config.selectedPageID }
    }
    var currentPage: DashboardPage? {
        guard let p = profileIndex, let q = pageIndex else { return nil }
        return config.profiles[p].pages[q]
    }
    var selectedTile: Tile? { currentPage?.tiles.first { $0.id == selectedTileID } }

    func selectProfile(_ id: UUID) {
        guard let profile = config.profiles.first(where: { $0.id == id }), let first = profile.pages.first else { return }
        cancelTilePreview()
        config.selectedProfileID = id
        config.selectedPageID = first.id
        selectedTileID = nil
    }

    func selectPage(_ id: UUID) {
        guard let p = profileIndex,
              let destination = config.profiles[p].pages.firstIndex(where: { $0.id == id }),
              id != config.selectedPageID else { return }
        pageNavigationDirection = destination < (pageIndex ?? destination) ? -1 : 1
        cancelTilePreview()
        withAnimation(.easeInOut(duration: 0.32)) {
            config.selectedPageID = id
            selectedTileID = nil
        }
    }

    func adjacentPageID(by offset: Int) -> UUID? {
        guard let p = profileIndex, let q = pageIndex,
              offset != 0,
              config.profiles[p].pages.indices.contains(q + offset) else { return nil }
        return config.profiles[p].pages[q + offset].id
    }

    @discardableResult func navigatePage(by offset: Int) -> Bool {
        guard let id = adjacentPageID(by: offset) else { return false }
        selectPage(id)
        return true
    }

    func addProfile() {
        let page = DashboardPage(name: L("Página 1", "Page 1"))
        let profile = DashboardProfile(name: L("Perfil \(config.profiles.count + 1)", "Profile \(config.profiles.count + 1)"), pages: [page])
        config.profiles.append(profile)
        selectProfile(profile.id)
    }

    func addPage() {
        guard let p = profileIndex else { return }
        let page = DashboardPage(name: L("Página \(config.profiles[p].pages.count + 1)", "Page \(config.profiles[p].pages.count + 1)"))
        config.profiles[p].pages.append(page)
        selectPage(page.id)
    }

    func renameProfile(_ id: UUID, _ name: String) {
        guard let i = config.profiles.firstIndex(where: { $0.id == id }) else { return }
        config.profiles[i].name = name
    }

    func renamePage(_ id: UUID, _ name: String) {
        guard let p = profileIndex, let q = config.profiles[p].pages.firstIndex(where: { $0.id == id }) else { return }
        config.profiles[p].pages[q].name = name
    }

    func setPageBackground(_ id: UUID, hex: String?) {
        guard let p = profileIndex, let q = config.profiles[p].pages.firstIndex(where: { $0.id == id }) else { return }
        config.profiles[p].pages[q].backgroundHex = hex
    }

    func setPageBackgroundImage(_ id: UUID, filename: String?) {
        guard let p = profileIndex, let q = config.profiles[p].pages.firstIndex(where: { $0.id == id }) else { return }
        config.profiles[p].pages[q].backgroundImage = filename
    }

    func setPageBackgroundPlacement(_ id: UUID, scale: String? = nil,
                                    horizontal: String? = nil, vertical: String? = nil) {
        guard let p = profileIndex, let q = config.profiles[p].pages.firstIndex(where: { $0.id == id }) else { return }
        if let scale { config.profiles[p].pages[q].backgroundScale = scale }
        if let horizontal { config.profiles[p].pages[q].backgroundHorizontal = horizontal }
        if let vertical { config.profiles[p].pages[q].backgroundVertical = vertical }
    }

    func removeProfile(_ id: UUID) {
        guard config.profiles.count > 1 else { return }
        config.profiles.removeAll { $0.id == id }
        if config.selectedProfileID == id { selectProfile(config.profiles[0].id) }
    }

    func removePage(_ id: UUID) {
        guard let p = profileIndex, config.profiles[p].pages.count > 1 else { return }
        config.profiles[p].pages.removeAll { $0.id == id }
        if config.selectedPageID == id { selectPage(config.profiles[p].pages[0].id) }
    }

    func movePage(_ id: UUID, by offset: Int) {
        guard let p = profileIndex,
              let index = config.profiles[p].pages.firstIndex(where: { $0.id == id }),
              (0..<config.profiles[p].pages.count).contains(index + offset) else { return }
        config.profiles[p].pages.swapAt(index, index + offset)
    }

    private func intersects(_ a: Tile, _ b: Tile) -> Bool {
        a.x < b.x + b.width && a.x + a.width > b.x && a.y < b.y + b.height && a.y + a.height > b.y
    }

    func displayedTile(_ tile: Tile) -> Tile {
        if let preview = tilePreview, preview.id == tile.id { return preview }
        return tile
    }

    func previewTile(_ id: UUID, _ edit: (inout Tile) -> Void) {
        guard let page = currentPage, let original = page.tiles.first(where: { $0.id == id }) else {
            cancelTilePreview()
            return
        }
        var proposal = original
        edit(&proposal)
        proposal = normalized(proposal)
        let blocked = page.tiles.contains { $0.id != id && intersects($0, proposal) }
        if blocked {
            if tilePreview != nil { tilePreview = nil }
            if !tilePreviewRejected { tilePreviewRejected = true }
        } else {
            if tilePreviewRejected { tilePreviewRejected = false }
            if tilePreview != proposal { tilePreview = proposal }
        }
    }

    func commitTilePreview(_ id: UUID) {
        if let preview = tilePreview, preview.id == id, !tilePreviewRejected {
            updateTile(id) { $0 = preview }
        }
        cancelTilePreview()
    }

    func cancelTilePreview() {
        if tilePreview != nil { tilePreview = nil }
        if tilePreviewRejected { tilePreviewRejected = false }
    }

    private func normalized(_ tile: Tile) -> Tile {
        var tile = tile
        tile.width = max(2, min(16, tile.width))
        tile.height = max(1, min(4, tile.height))
        tile.x = max(0, min(16 - tile.width, tile.x))
        tile.y = max(0, min(4 - tile.height, tile.y))
        return tile
    }

    func addTile(_ kind: WidgetKind, importedID: UUID? = nil,
                 deckPreset: ActionDeckPreset = .compact) {
        guard let p = profileIndex, let q = pageIndex else { return }
        let fullDeck = kind == .actionDeck && deckPreset == .fullPage
        let width: Int
        switch kind {
        case .pixelDash: width = 16
        case .actionDeck: width = fullDeck ? 16 : (deckPreset == .mini ? 2 : 4)
        case .pixelClock: width = 8
        case .web, .icue: width = 6
        case .launcher: width = 2
        default: width = 4
        }
        var tile = Tile(kind: kind, width: width, height: kind == .pixelDash || fullDeck ? 4 : 2)
        if kind == .actionDeck && !fullDeck {
            tile.settings["deckVisibleCount"] = deckPreset == .mini ? "4" : "8"
            tile.settings["deckColumns"] = deckPreset == .mini ? "2" : "4"
        }
        tile.importedID = importedID
        if let importedID, let imported = imports.first(where: { $0.id == importedID }) { tile.title = imported.name }
        var found = false
        for y in 0...(4 - tile.height) {
            for x in 0...(16 - tile.width) {
                tile.x = x; tile.y = y
                if !config.profiles[p].pages[q].tiles.contains(where: { intersects($0, tile) }) { found = true; break }
            }
            if found { break }
        }
        if !found { addPage(); tile.x = 0; tile.y = 0 }
        guard let np = profileIndex, let nq = pageIndex else { return }
        config.profiles[np].pages[nq].tiles.append(tile)
        selectedTileID = tile.id
    }

    func updateTile(_ id: UUID, _ edit: (inout Tile) -> Void) {
        guard let p = profileIndex, let q = pageIndex,
              let i = config.profiles[p].pages[q].tiles.firstIndex(where: { $0.id == id }) else { return }
        var updated = config.profiles[p].pages[q].tiles[i]
        edit(&updated)
        updated = normalized(updated)
        if config.profiles[p].pages[q].tiles.enumerated().contains(where: { $0.offset != i && intersects($0.element, updated) }) { return }
        config.profiles[p].pages[q].tiles[i] = updated
    }

    func removeTile(_ id: UUID) {
        guard let p = profileIndex, let q = pageIndex else { return }
        if tilePreview?.id == id { cancelTilePreview() }
        config.profiles[p].pages[q].tiles.removeAll { $0.id == id }
        if selectedTileID == id { selectedTileID = nil }
    }

    func selectDisplay(_ display: ConnectedDisplay) {
        config.selectedDisplay = display.identity
        touch.displayChanged()
        brightness.refresh()
        if config.touchEnabled && !touch.enabled { touch.start() }
    }

    func toggleTouch(_ enabled: Bool) {
        config.touchEnabled = enabled
        if enabled { touch.start(requestPermissions: true) } else { touch.stop() }
    }

    func toggleLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            config.launchAtLogin = enabled
        } catch { message = error.localizedDescription }
    }

    func beginCalibration() {
        calibrationHits = []
        calibration = true
    }

    func calibrationHit(_ index: Int) {
        calibrationHits.insert(index)
        if calibrationHits.count == 5 { calibration = false; message = L("Toque alinhado nos cinco alvos.", "Touch aligned on all five targets.") }
    }

    @discardableResult func importWidget(_ url: URL) -> Bool {
        do {
            let widget = try WidgetImporter.importFile(url, into: store.libraryURL)
            imports.append(widget)
            message = widget.compatible ? L("Widget importado. Revise permissões de rede antes de adicionar.", "Widget imported. Review network permissions before adding.") : L("Widget importado com dependências incompatíveis.", "Widget imported with unsupported dependencies.")
            return true
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    func imported(_ id: UUID?) -> ImportedWidget? { imports.first { $0.id == id } }

    func updateDomain(_ id: UUID, domain: String, enabled: Bool) {
        guard let i = imports.firstIndex(where: { $0.id == id }) else { return }
        if enabled {
            if !imports[i].allowedDomains.contains(domain) { imports[i].allowedDomains.append(domain) }
        } else { imports[i].allowedDomains.removeAll { $0 == domain } }
        // Force tiles to rebuild their WebView after the permission change.
        objectWillChange.send()
    }
}
