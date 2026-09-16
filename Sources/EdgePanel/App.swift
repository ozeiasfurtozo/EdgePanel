import AppKit
import SwiftUI

@MainActor @main enum EdgePanelMain {
    static let delegate = PanelAppDelegate()
    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}

@MainActor final class PanelAppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var editorWindowController: NSWindowController?
    private var dashboardWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var observers: [NSObjectProtocol] = []
    private var readyForImports = false
    private var pendingImports: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        installAppMenu()
        makeEditor()
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let url = Bundle.main.url(forResource: "StatusIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            status.button?.image = image
        } else {
            status.button?.title = "▤"
        }
        status.button?.toolTip = "EdgePanel"
        statusItem = status
        model.onDashboardChange = { [weak self] in self?.syncDashboard() }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.model.displays.refresh()
                self?.model.touch.displayChanged()
                self?.model.brightness.refresh()
                self?.syncDashboard()
            }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.model.touch.stop() }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.model.displays.refresh()
                self?.syncDashboard()
                self?.model.brightness.refresh()
                if self?.model.config.touchEnabled == true { self?.model.touch.start() }
            }
        })
        syncDashboard()
        if model.config.touchEnabled { model.touch.start() }
        showEditor()
        readyForImports = true
        pendingImports.forEach(importWidget)
        pendingImports.removeAll()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if readyForImports {
            urls.forEach(importWidget)
        } else {
            pendingImports.append(contentsOf: urls)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.touch.stop()
        observers.forEach { NotificationCenter.default.removeObserver($0); NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard readyForImports else { return }
        model.brightness.refresh()
        if model.config.touchEnabled { model.touch.refreshPermissions() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showEditor()
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? { actionsMenu(includeQuit: false) }

    private func installAppMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem(title: "EdgePanel", action: nil, keyEquivalent: "")
        appItem.submenu = actionsMenu(includeQuit: true)
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem(title: L("Editar", "Edit"), action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: editItem.title)
        editMenu.addItem(withTitle: L("Cortar", "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L("Copiar", "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L("Colar", "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L("Selecionar tudo", "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }

    private func actionsMenu(includeQuit: Bool) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: L("Abrir editor", "Open editor"), action: #selector(showEditor), keyEquivalent: includeQuit ? "e" : "").target = self
        menu.addItem(withTitle: L("Mostrar painel", "Show dashboard"), action: #selector(showDashboard), keyEquivalent: includeQuit ? "d" : "").target = self
        if includeQuit {
            menu.addItem(.separator())
            menu.addItem(withTitle: L("Sair", "Quit"), action: #selector(quit), keyEquivalent: "q").target = self
        }
        return menu
    }

    private func makeEditor() {
        let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 1120, height: 760),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "EdgePanel · XENEON EDGE"
        window.minSize = NSSize(width: 1000, height: 700)
        window.center()
        // The menu and Dock reopen this same window after the close button is used.
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: EditorView(model: model, touch: model.touch))
        editorWindowController = NSWindowController(window: window)
    }

    private func importWidget(_ url: URL) {
        showEditor()
        if model.importWidget(url) { model.libraryOpenRequest += 1 }
    }

    private func syncDashboard() {
        rebuildStatusMenu()
        guard let display = model.displays.resolve(model.config.selectedDisplay) else {
            dashboardWindow?.close()
            dashboardWindow = nil
            return
        }
        if let window = dashboardWindow {
            if window.frame != display.screen.frame {
                window.setFrame(display.screen.frame, display: true)
            }
            return
        }
        let window = NSWindow(contentRect: display.screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.title = "EdgePanel Dashboard"
        window.backgroundColor = .black
        window.isOpaque = true
        // Cover menu and status items on this display without changing the app-wide menu-bar setting.
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: DashboardView(model: model))
        window.orderFrontRegardless()
        dashboardWindow = window
    }

    private func rebuildStatusMenu() {
        let menu = actionsMenu(includeQuit: false)
        menu.addItem(.separator())
        for profile in model.config.profiles {
            let item = NSMenuItem(title: profile.name, action: #selector(selectProfile(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = profile.id
            item.state = profile.id == model.config.selectedProfileID ? .on : .off
            menu.addItem(item)
        }
        if let profile = model.config.profiles.first(where: { $0.id == model.config.selectedProfileID }),
           profile.pages.count > 1 {
            menu.addItem(.separator())
            let heading = NSMenuItem(title: L("Páginas", "Pages"), action: nil, keyEquivalent: "")
            heading.isEnabled = false
            menu.addItem(heading)
            for page in profile.pages {
                let item = NSMenuItem(title: page.name, action: #selector(selectPage(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = page.id
                item.state = page.id == model.config.selectedPageID ? .on : .off
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: L("Sair", "Quit"), action: #selector(quit), keyEquivalent: "q").target = self
        statusItem?.menu = menu
    }

    @objc private func showEditor() {
        if editorWindowController?.window == nil { makeEditor() }
        editorWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func showDashboard() {
        syncDashboard()
        dashboardWindow?.orderFrontRegardless()
    }
    @objc private func selectProfile(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? UUID { model.selectProfile(id) }
    }
    @objc private func selectPage(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? UUID { model.selectPage(id) }
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
