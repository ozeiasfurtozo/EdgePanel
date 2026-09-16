import Foundation

enum WidgetKind: String, Codable, CaseIterable, Identifiable {
    case clock, pixelClock, pixelDash, cpu, memory, network, launcher, timer, web, icue
    var id: String { rawValue }

    var title: String {
        switch self {
        case .clock: return L("Relógio", "Clock")
        case .pixelClock: return L("Relógio Pixel", "Pixel Clock")
        case .pixelDash: return L("Painel Pixel", "Pixel Dashboard")
        case .cpu: return "CPU"
        case .memory: return L("Memória", "Memory")
        case .network: return L("Rede", "Network")
        case .launcher: return L("Aplicativo", "Application")
        case .timer: return "Timer"
        case .web: return "Web"
        case .icue: return "iCUE"
        }
    }
}

func L(_ pt: String, _ en: String) -> String {
    Locale.current.language.languageCode?.identifier == "pt" ? pt : en
}

struct Tile: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: WidgetKind
    var title: String
    var x: Int
    var y: Int
    var width: Int
    var height: Int
    var value = ""
    var importedID: UUID? = nil
    var settings: [String: String] = [:]

    init(kind: WidgetKind, x: Int = 0, y: Int = 0, width: Int = 4, height: Int = 2, value: String = "") {
        self.kind = kind
        self.title = kind.title
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.value = value
    }
}

struct DashboardPage: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var tiles: [Tile] = []
    var backgroundHex: String? = nil
}

struct DashboardProfile: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var pages: [DashboardPage]
}

struct DisplayIdentity: Codable, Hashable {
    var vendor: UInt32
    var model: UInt32
    var serial: UInt32
}

struct TouchOrientation: Codable, Equatable {
    var swapAxes = false
    var invertX = false
    var invertY = false
}

struct DashboardConfig: Codable {
    var version = 1
    var deviceID = UUID()
    var profiles: [DashboardProfile]
    var selectedProfileID: UUID
    var selectedPageID: UUID
    var selectedDisplay: DisplayIdentity? = nil
    var darkMode = true
    var touchEnabled = false
    var touchOrientation = TouchOrientation()
    var launchAtLogin = false

    static func initial() -> DashboardConfig {
        let page = DashboardPage(name: L("Página 1", "Page 1"), tiles: [
            Tile(kind: .clock, x: 0, y: 0, width: 4, height: 2),
            Tile(kind: .cpu, x: 4, y: 0, width: 3, height: 2),
            Tile(kind: .memory, x: 7, y: 0, width: 3, height: 2),
            Tile(kind: .network, x: 10, y: 0, width: 6, height: 2),
            Tile(kind: .timer, x: 0, y: 2, width: 4, height: 2),
        ])
        let profile = DashboardProfile(name: L("Principal", "Main"), pages: [page])
        return DashboardConfig(profiles: [profile], selectedProfileID: profile.id, selectedPageID: page.id)
    }
}

struct ImportedControl: Codable, Identifiable {
    var name: String
    var type: String
    var label: String
    var defaultExpression: String
    var optionsExpression: String?
    var minExpression: String?
    var maxExpression: String?
    var id: String { name }
}

struct ImportedWidget: Codable, Identifiable {
    var id: UUID
    var name: String
    var author: String
    var version: String
    var requiredPlugins: [String]
    var requestedDomains: [String]
    var allowedDomains: [String]
    var controls: [ImportedControl]
    var warnings: [String]
    var compatible: Bool
}
