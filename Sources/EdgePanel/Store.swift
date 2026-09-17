import Foundation

final class PanelStore {
    let root: URL
    let configURL: URL
    let importsURL: URL
    let libraryURL: URL

    init(root: URL? = nil) {
        let base = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EdgePanel", isDirectory: true)
        self.root = base
        self.configURL = base.appendingPathComponent("dashboard.json")
        self.importsURL = base.appendingPathComponent("imports.json")
        self.libraryURL = base.appendingPathComponent("Widgets", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: libraryURL, withIntermediateDirectories: true)
    }

    func load() -> DashboardConfig {
        guard let data = try? Data(contentsOf: configURL),
              var value = try? JSONDecoder().decode(DashboardConfig.self, from: data), value.version == 1,
              !value.profiles.isEmpty else { return .initial() }
        if value.ensureDesktopPage() { save(value) }
        return value
    }

    func loadImports() -> [ImportedWidget] {
        guard let data = try? Data(contentsOf: importsURL) else { return [] }
        return (try? JSONDecoder().decode([ImportedWidget].self, from: data)) ?? []
    }

    func save(_ config: DashboardConfig) {
        write(config, to: configURL)
    }

    func saveImports(_ imports: [ImportedWidget]) {
        write(imports, to: importsURL)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("EdgePanel save failed: %@", String(describing: error))
        }
    }
}
