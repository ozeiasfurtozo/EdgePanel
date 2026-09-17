import XCTest
import Foundation
import AppKit
import SwiftUI
@testable import EdgePanel

final class EdgePanelTests: XCTestCase {
    @MainActor func testSSDWidgetUsesRealVolumeCapacityAndPersists() throws {
        let snapshot = try XCTUnwrap(StorageSnapshot.read(at: URL(fileURLWithPath: NSHomeDirectory())))
        XCTAssertGreaterThan(snapshot.totalBytes, 0)
        XCTAssertGreaterThanOrEqual(snapshot.availableBytes, 0)
        XCTAssertLessThanOrEqual(snapshot.availableBytes, snapshot.totalBytes)
        XCTAssertEqual(snapshot.usedBytes + snapshot.availableBytes, snapshot.totalBytes)
        XCTAssertEqual(snapshot.usedPercent,
                       100 * Double(snapshot.usedBytes) / Double(snapshot.totalBytes), accuracy: 0.001)
        XCTAssertNil(StorageSnapshot(volumeName: "Invalid", totalBytes: 0, availableBytes: 0))
        XCTAssertNil(StorageSnapshot(volumeName: "Invalid", totalBytes: 100, availableBytes: 101))

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PanelStore(root: directory)
        let model = AppModel(store: store)
        model.addTile(.ssd)
        let tile = try XCTUnwrap(model.selectedTile)
        XCTAssertEqual(tile.width, 4)
        XCTAssertEqual(tile.height, 2)
        XCTAssertEqual(store.load().profiles.flatMap(\.pages).flatMap(\.tiles)
            .first(where: { $0.id == tile.id })?.kind, .ssd)
    }

    @MainActor func testBorderlessDashboardCanReceiveKeyboardFocus() {
        let window = DashboardWindow(contentRect: CGRect(x: 0, y: 0, width: 640, height: 180),
                                     styleMask: [.borderless], backing: .buffered, defer: false)
        XCTAssertTrue(window.canBecomeKey)
        XCTAssertTrue(DashboardWebView().acceptsFirstMouse(for: nil))
    }

    func testBackgroundImageSizingAndAlignment() throws {
        let image = CGSize(width: 400, height: 200)
        let container = CGSize(width: 200, height: 200)
        XCTAssertEqual(BackgroundGeometry.frame(image: image, container: container,
                                                scale: "fill", horizontal: "right", vertical: "center"),
                       CGRect(x: -200, y: 0, width: 400, height: 200))
        XCTAssertEqual(BackgroundGeometry.frame(image: image, container: container,
                                                scale: "fit", horizontal: "left", vertical: "bottom"),
                       CGRect(x: 0, y: 100, width: 200, height: 100))
        XCTAssertEqual(BackgroundGeometry.frame(image: image, container: container,
                                                scale: "stretch", horizontal: "left", vertical: "top"),
                       CGRect(x: 0, y: 0, width: 200, height: 200))
        XCTAssertEqual(BackgroundGeometry.frame(image: image, container: container,
                                                scale: "original", horizontal: "center", vertical: "top"),
                       CGRect(x: -100, y: 0, width: 400, height: 200))

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PanelStore(root: directory)
        var config = DashboardConfig.initial()
        config.profiles[0].pages[1].backgroundImage = "00000000-0000-0000-0000-000000000000.png"
        config.profiles[0].pages[1].backgroundScale = "fit"
        config.profiles[0].pages[1].backgroundHorizontal = "right"
        config.profiles[0].pages[1].backgroundVertical = "bottom"
        store.save(config)
        let restored = store.load().profiles[0].pages[1]
        XCTAssertEqual(restored.backgroundImage, config.profiles[0].pages[1].backgroundImage)
        XCTAssertEqual(restored.backgroundScale, "fit")
        XCTAssertEqual(restored.backgroundHorizontal, "right")
        XCTAssertEqual(restored.backgroundVertical, "bottom")
        XCTAssertNil(store.backgroundImage(named: "../dashboard.json"))

        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/StatusIcon.png")
        let source = directory.appendingPathComponent("background.png")
        try FileManager.default.copyItem(at: fixture, to: source)
        let filename = try store.importBackgroundImage(source)
        XCTAssertNotNil(store.backgroundImage(named: filename))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.backgroundsURL.appendingPathComponent(filename).path))
    }

    @MainActor func testActionDeckFitsAnExistingPageAndPersistsButtons() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PanelStore(root: directory)
        let model = AppModel(store: store)
        let originalPageID = model.currentPage?.id
        model.addTile(.actionDeck)

        let tile = try XCTUnwrap(model.selectedTile)
        XCTAssertEqual(tile.height, 2)
        XCTAssertEqual(tile.width, 4)
        XCTAssertEqual(tile.x, 4)
        XCTAssertEqual(tile.y, 2)
        XCTAssertEqual(model.currentPage?.id, originalPageID)
        XCTAssertEqual(model.currentPage?.tiles.count, 6)
        XCTAssertEqual(DeckSettings.visibleCount(tile.settings), 8)
        XCTAssertEqual(tile.settings["deckColumns"], "4")
        XCTAssertEqual(DeckSettings.buttons(tile.settings).count, 16)

        var buttons = DeckSettings.buttons(tile.settings)
        buttons[0].name = "Build"
        buttons[0].action = .keySequence
        buttons[0].strokes = [DeckStroke(keyCode: 0, modifiers: NSEvent.ModifierFlags.command.rawValue, keyName: "A"),
                              DeckStroke(keyCode: 36, modifiers: 0, keyName: "")]
        buttons[0].icon = .symbol
        buttons[0].iconValue = "hammer.fill"
        buttons[0].colorHex = "#F5C64D"
        model.updateTile(tile.id) { updated in
            DeckSettings.save(buttons, to: &updated.settings)
            updated.settings["deckVisibleCount"] = "12"
        }

        let restored = try XCTUnwrap(store.load().profiles.flatMap(\.pages).flatMap(\.tiles).first(where: { $0.id == tile.id }))
        let restoredButtons = DeckSettings.buttons(restored.settings)
        XCTAssertEqual(restoredButtons[0], buttons[0])
        XCTAssertEqual(restoredButtons[0].colorHex, "#F5C64D")
        XCTAssertNil(restoredButtons[1].colorHex)
        XCTAssertEqual(restoredButtons[0].strokes.map(\.label), ["⌘A", "↩"])
        XCTAssertEqual(DeckSettings.visibleCount(restored.settings), 12)
        XCTAssertEqual(DeckSettings.columns(restored.settings, width: 450), 4)

        model.addTile(.actionDeck, deckPreset: .mini)
        XCTAssertEqual(model.currentPage?.id, originalPageID)
        XCTAssertEqual(model.selectedTile?.width, 2)
        XCTAssertEqual(model.selectedTile?.height, 2)
        XCTAssertEqual(DeckSettings.visibleCount(model.selectedTile?.settings ?? [:]), 4)

        model.addTile(.actionDeck, deckPreset: .fullPage)
        XCTAssertNotEqual(model.currentPage?.id, originalPageID)
        XCTAssertEqual(model.selectedTile?.width, 16)
        XCTAssertEqual(model.selectedTile?.height, 4)

        let wide = DeckGridLayout(count: 16, settings: [:],
                                  available: CGSize(width: 1280, height: 360), editing: false)
        XCTAssertEqual(wide.columns, 8)
        XCTAssertEqual(wide.rows, 2)
        XCTAssertEqual(wide.width, 1280 - 44, accuracy: 1)
        XCTAssertLessThanOrEqual(wide.height, 360)
        let compact = DeckGridLayout(count: 15, settings: ["deckColumns": "5"],
                                     available: CGSize(width: 850, height: 220), editing: true)
        XCTAssertEqual(compact.columns, 5)
        XCTAssertEqual(compact.rows, 3)
        XCTAssertLessThanOrEqual(compact.width, 850)
        XCTAssertLessThanOrEqual(compact.height, 220)

        let embedded = DeckGridLayout(count: 8, settings: ["deckColumns": "4"],
                                      available: CGSize(width: 400, height: 180), editing: true)
        XCTAssertGreaterThan(embedded.side, 60)
        XCTAssertLessThan(embedded.width, 400)
        XCTAssertLessThan(embedded.height, 180)

        let crowded = DeckGridLayout(count: 16, settings: ["deckColumns": "8"],
                                     available: CGSize(width: 180, height: 120), editing: true)
        XCTAssertLessThanOrEqual(crowded.width, 180)
        XCTAssertLessThanOrEqual(crowded.height, 120)

        let legacy = """
        [{"id":"00000000-0000-0000-0000-000000000001","name":"Legacy","action":"none","value":"","strokes":[],"icon":"symbol","iconValue":"bolt.fill"}]
        """
        let decoded = DeckSettings.buttons([DeckSettings.key: legacy])
        XCTAssertEqual(decoded.first?.name, "Legacy")
        XCTAssertNil(decoded.first?.colorHex)
    }

    @MainActor func testPageNavigationLoopsWithinCurrentProfile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PanelStore(root: directory)
        let model = AppModel(store: store)
        let desktop = try XCTUnwrap(model.config.profiles[0].pages.first?.id)
        let first = try XCTUnwrap(model.currentPage?.id)
        model.addPage()
        let second = try XCTUnwrap(model.currentPage?.id)
        model.addPage()
        let third = try XCTUnwrap(model.currentPage?.id)

        XCTAssertEqual(model.adjacentPageID(by: 1), desktop)
        XCTAssertTrue(model.navigatePage(by: 1))
        XCTAssertEqual(model.currentPage?.id, desktop)
        XCTAssertEqual(model.pageNavigationDirection, 1)
        XCTAssertTrue(model.navigatePage(by: -1))
        XCTAssertEqual(model.currentPage?.id, third)
        XCTAssertEqual(model.pageNavigationDirection, -1)
        XCTAssertTrue(model.navigatePage(by: -1))
        XCTAssertEqual(model.currentPage?.id, second)
        XCTAssertTrue(model.navigatePage(by: -1))
        XCTAssertEqual(model.currentPage?.id, first)
        XCTAssertEqual(model.adjacentPageID(by: 1), second)
        XCTAssertTrue(model.navigatePage(by: 2))
        XCTAssertEqual(model.currentPage?.id, third)
        XCTAssertEqual(model.pageNavigationDirection, 1)
        XCTAssertEqual(store.load().selectedPageID, third)

        model.addProfile()
        XCTAssertEqual(model.currentPage?.name, L("Página 1", "Page 1"))
        XCTAssertTrue(model.navigatePage(by: -1))
        XCTAssertEqual(model.currentPage?.desktopMode, true)
        XCTAssertNotEqual(model.currentPage?.id, desktop)
    }

    @MainActor func testDesktopPageIsFixedAtZeroAndCannotContainWidgets() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PanelStore(root: directory)
        let model = AppModel(store: store)
        let widgetPageID = try XCTUnwrap(model.currentPage?.id)
        XCTAssertNil(model.currentPage?.desktopMode)
        let desktopPageID = try XCTUnwrap(model.config.profiles[0].pages.first?.id)
        model.selectPage(desktopPageID)
        XCTAssertEqual(model.currentPage?.desktopMode, true)
        XCTAssertTrue(model.currentPage?.tiles.isEmpty == true)
        model.addTile(.clock)
        XCTAssertTrue(model.currentPage?.tiles.isEmpty == true)
        model.removePage(desktopPageID)
        model.movePage(desktopPageID, by: 1)
        model.movePage(widgetPageID, by: -1)
        XCTAssertEqual(model.config.profiles[0].pages.count, 2)
        XCTAssertEqual(model.config.profiles[0].pages[0].id, desktopPageID)
        XCTAssertEqual(store.load().profiles[0].pages[0].desktopMode, true)

        XCTAssertTrue(model.navigatePage(by: -1))
        XCTAssertEqual(model.currentPage?.id, widgetPageID)
        XCTAssertTrue(model.navigatePage(by: 1))
        XCTAssertEqual(model.currentPage?.id, desktopPageID)
        let restored = AppModel(store: store)
        XCTAssertEqual(restored.currentPage?.desktopMode, true)
        XCTAssertTrue(restored.navigatePage(by: -1))
        XCTAssertEqual(restored.currentPage?.id, widgetPageID)
        XCTAssertTrue(restored.navigatePage(by: -1))
        XCTAssertEqual(restored.currentPage?.id, desktopPageID)
        XCTAssertEqual(restored.pageNavigationDirection, -1)
        XCTAssertTrue(restored.navigatePage(by: 1))
        XCTAssertEqual(restored.currentPage?.id, widgetPageID)
        XCTAssertEqual(restored.pageNavigationDirection, 1)

        model.removePage(widgetPageID)
        XCTAssertEqual(model.config.profiles[0].pages.map(\.id), [desktopPageID])
        XCTAssertEqual(model.currentPage?.desktopMode, true)
        model.addPage()
        XCTAssertEqual(model.currentPage?.name, L("Página 1", "Page 1"))
        XCTAssertEqual(model.config.profiles[0].pages[0].id, desktopPageID)
    }

    @MainActor func testExistingProfilesGainOrMoveDesktopPageWithoutChangingSelection() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PanelStore(root: directory)
        var legacy = DashboardConfig.initial()
        let desktop = legacy.profiles[0].pages.removeFirst()
        let selectedWidgetID = legacy.selectedPageID
        legacy.profiles[0].pages.append(desktop)
        let otherPage = DashboardPage(name: "Other widget page")
        legacy.profiles.append(DashboardProfile(name: "Other profile", pages: [otherPage]))
        store.save(legacy)

        let model = AppModel(store: store)
        XCTAssertEqual(model.currentPage?.id, selectedWidgetID)
        XCTAssertEqual(model.config.profiles[0].pages[0].id, desktop.id)
        XCTAssertEqual(model.config.profiles[0].pages[1].id, selectedWidgetID)
        XCTAssertEqual(model.config.profiles[1].pages[0].desktopMode, true)
        XCTAssertEqual(model.config.profiles[1].pages[1].id, otherPage.id)
        let persisted = try JSONDecoder().decode(DashboardConfig.self, from: Data(contentsOf: store.configURL))
        XCTAssertEqual(persisted.profiles[0].pages[0].id, desktop.id)
        XCTAssertEqual(persisted.profiles[1].pages[0].desktopMode, true)
        XCTAssertEqual(persisted.selectedPageID, selectedWidgetID)
    }

    func testBrightnessTargetsOnlyTheSelectedDisplayAndParsesDDCValues() throws {
        let xeneon = DisplayIdentity(vendor: 0x0E58, model: 0xED00, serial: 16843009)
        XCTAssertEqual(DDCBrightness.selector(for: xeneon), "basic=3672:60672:16843009")
        XCTAssertEqual(try DDCBrightness.value(from: "80\n"), 80)
        XCTAssertThrowsError(try DDCBrightness.value(from: "The specified display does not exist."))
        XCTAssertThrowsError(try DDCBrightness.value(from: "101"))
    }

    @MainActor func testTilePreviewMovesPanelBeforePersistingAndRejectsOverlap() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PanelStore(root: directory)
        store.save(DashboardConfig.initial())
        let model = AppModel(store: store)
        let tile = try XCTUnwrap(model.currentPage?.tiles.first(where: { $0.kind == .cpu }))

        model.previewTile(tile.id) { $0.y = 2 }
        XCTAssertEqual(model.displayedTile(tile).y, 2)
        XCTAssertEqual(model.currentPage?.tiles.first(where: { $0.id == tile.id })?.y, 0)
        XCTAssertEqual(store.load().profiles[0].pages[1].tiles.first(where: { $0.id == tile.id })?.y, 0)

        model.commitTilePreview(tile.id)
        XCTAssertEqual(store.load().profiles[0].pages[1].tiles.first(where: { $0.id == tile.id })?.y, 2)
        model.previewTile(tile.id) { $0.x = 7; $0.y = 0 }
        XCTAssertTrue(model.tilePreviewRejected)
        model.commitTilePreview(tile.id)
        XCTAssertEqual(store.load().profiles[0].pages[1].tiles.first(where: { $0.id == tile.id })?.y, 2)

        let originalPageID = try XCTUnwrap(model.currentPage?.id)
        model.addPage()
        let secondPageID = try XCTUnwrap(model.currentPage?.id)
        model.setPageBackground(secondPageID, hex: "#DDEEFF")
        XCTAssertNil(store.load().profiles[0].pages.first(where: { $0.id == originalPageID })?.backgroundHex)
        XCTAssertEqual(store.load().profiles[0].pages.first(where: { $0.id == secondPageID })?.backgroundHex, "#DDEEFF")
        model.setPageBackground(secondPageID, hex: nil)
        XCTAssertNil(store.load().profiles[0].pages.first(where: { $0.id == secondPageID })?.backgroundHex)
    }

    func testPixelDashKeepsDailyWaterAndTimerStateAcrossReloads() throws {
        let now = Date(timeIntervalSince1970: 1_789_565_600)
        let yesterday = now.addingTimeInterval(-86_400)
        let daily = PixelDashSettings(["dashWaterGoal": "6"])
        XCTAssertEqual(daily.waterCount(in: ["dashWaterDay": PixelDashSettings.dayKey(yesterday),
                                            "dashWaterCount": "4"], at: now), 0)
        XCTAssertEqual(daily.waterCount(in: ["dashWaterDay": PixelDashSettings.dayKey(now),
                                            "dashWaterCount": "4"], at: now), 4)

        let timer = PixelDashSettings(["dashTimerMinutes": "15"])
        let running = ["dashTimerRunning": "true", "dashTimerEnd": String(now.timeIntervalSince1970 + 45)]
        XCTAssertEqual(timer.timerRemaining(in: running, at: now), 45)
        XCTAssertEqual(timer.timerRemaining(in: running, at: now.addingTimeInterval(50)), 0)
        XCTAssertEqual(timer.timerRemaining(in: ["dashTimerRemaining": "30"], at: now), 30)
        XCTAssertEqual(timer.stopwatchElapsed(in: ["dashStopwatchRunning": "true",
                                                  "dashStopwatchStart": String(now.timeIntervalSince1970 - 12),
                                                  "dashStopwatchElapsed": "8"], at: now), 20)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PanelStore(root: directory)
        var config = DashboardConfig.initial()
        var tile = Tile(kind: .pixelDash, width: 16, height: 4)
        tile.settings = running.merging(["dashWaterDay": PixelDashSettings.dayKey(now),
                                         "dashWaterCount": "4", "dashWaterGoal": "6"]) { _, new in new }
        config.profiles[0].pages[1].tiles = [tile]
        store.save(config)
        let loaded = try XCTUnwrap(store.load().profiles[0].pages[1].tiles.first)
        XCTAssertEqual(PixelDashSettings(loaded.settings).waterCount(in: loaded.settings, at: now), 4)
        XCTAssertEqual(PixelDashSettings(loaded.settings).timerRemaining(in: loaded.settings, at: now), 45)
    }

    @MainActor func testPixelDashReferenceModesRenderAtXeneonAspectRatio() throws {
        XCTAssertEqual(PixelDashMode.dashboardTabs, [.text, .weather, .social, .water, .art, .clock, .timer])
        let date = Date(timeIntervalSince1970: 1_789_565_600)
        let variants: [(String, [String: String])] = [
            ("text", ["dashMode": "text", "dashMessage": "PIXEL//EDGE", "dashRainbow": "true"]),
            ("weather", ["dashMode": "weather", "dashWeatherText": "24°C"]),
            ("social", ["dashMode": "social", "dashSocialText": "1600"]),
            ("water", ["dashMode": "water", "dashWaterGoal": "8",
                        "dashWaterDay": PixelDashSettings.dayKey(date), "dashWaterCount": "5"]),
            ("art", ["dashMode": "art"]),
            ("clock", ["dashMode": "clock", "dashSeconds": "false"])
        ]
        for (name, values) in variants {
            let settings = PixelDashSettings(values)
            let renderer = ImageRenderer(content:
                PixelDashMatrix(mode: settings.mode, settings: settings, values: values,
                                cpu: 32, memory: 64, date: date, openedAt: date)
                    .frame(width: 1536, height: 330)
                    .background(Color.black))
            renderer.scale = 1
            let image = try XCTUnwrap(renderer.nsImage)
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
            XCTAssertEqual(bitmap.pixelsWide, 1536)
            XCTAssertEqual(bitmap.pixelsHigh, 330)
            if ProcessInfo.processInfo.environment["EDGE_PIXEL_DASH_SNAPSHOTS"] == "1" {
                let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: URL(fileURLWithPath: "/private/tmp/edgepanel-pixel-dash-\(name).png"))
            }
        }
        XCTAssertEqual(PixelDashSettings(["dashMode": "system"]).mode, .system)
        XCTAssertEqual(PixelDashSettings(["dashMode": "stopwatch"]).mode, .stopwatch)
        XCTAssertEqual(PixelDashSettings([:]).weatherText, "--°C")
        XCTAssertEqual(PixelDashSettings([:]).socialText, "----")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PanelStore(root: directory)
        var config = DashboardConfig.initial()
        var tile = Tile(kind: .pixelDash, width: 16, height: 4)
        tile.settings = variants[0].1
        config.profiles[0].pages[1].tiles = [tile]
        store.save(config)
        let model = AppModel(store: store)
        let dashboard = ImageRenderer(content:
            PixelDashTile(model: model, metrics: model.metrics, tile: tile)
                .frame(width: 1536, height: 446))
        dashboard.scale = 1
        let dashboardImage = try XCTUnwrap(dashboard.nsImage)
        let dashboardBitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(dashboardImage.tiffRepresentation)))
        XCTAssertEqual(dashboardBitmap.pixelsWide, 1536)
        XCTAssertEqual(dashboardBitmap.pixelsHigh, 446)
        if ProcessInfo.processInfo.environment["EDGE_PIXEL_DASH_SNAPSHOTS"] == "1" {
            let png = try XCTUnwrap(dashboardBitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: "/private/tmp/edgepanel-pixel-dash-full.png"))
        }
    }

    func testPixelClockRespectsTimeZoneFormatAndWeekStart() throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-16T13:04:05Z"))
        let utc = PixelClockSettings(["pixelTimeZone": "UTC"])
        XCTAssertEqual(utc.timeText(at: date), "13:04")
        XCTAssertEqual(utc.meridiem(at: date), "")
        XCTAssertEqual(utc.weekdayIndex(at: date), 3) // Wednesday in a Sunday-first week.
        XCTAssertEqual(utc.dayOfMonth(at: date), 16)
        XCTAssertFalse(utc.showSeconds)
        XCTAssertFalse(utc.weekProgress)
        XCTAssertEqual(utc.backgroundTransparency, 100)

        let west = PixelClockSettings(["pixelTimeZone": "America/Los_Angeles",
                                       "pixel24Hour": "false",
                                       "pixelShowSeconds": "false",
                                       "pixelWeekStartsMonday": "false"])
        XCTAssertEqual(west.timeText(at: date), "06:04")
        XCTAssertEqual(west.meridiem(at: date), "AM")
        XCTAssertEqual(west.weekdayIndex(at: date), 3) // Wednesday in a Sunday-first week.

        let nextDay = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-19T16:10:00Z"))
        let tokyo = PixelClockSettings(["pixelTimeZone": "Asia/Tokyo", "pixel24Hour": "false",
                                        "pixelShowSeconds": "false", "pixelWeekStartsMonday": "true"])
        XCTAssertEqual(tokyo.timeText(at: nextDay), "01:10")
        XCTAssertEqual(tokyo.meridiem(at: nextDay), "AM")
        XCTAssertEqual(tokyo.weekdayIndex(at: nextDay), 6) // Sunday in Tokyo, with a Monday-first week.

        let auckland = PixelClockSettings(["pixelTimeZone": "Pacific/Auckland", "pixelShowSeconds": "true"])
        XCTAssertEqual(auckland.timeText(at: date), "01:04:05")

        let referenceSize = CGSize(width: 1552, height: 420)
        let calendarLayout = PixelClockLayout(size: referenceSize, settings: utc,
                                               time: utc.timeText(at: date), meridiem: "")
        XCTAssertNotNil(calendarLayout.calendarOrigin)
        XCTAssertNotNil(calendarLayout.weekOrigin)
        XCTAssertGreaterThan(calendarLayout.unit, 30)
        XCTAssertGreaterThanOrEqual(calendarLayout.contentFrame.minX, 0)
        XCTAssertLessThanOrEqual(calendarLayout.contentFrame.maxX, referenceSize.width)
        XCTAssertLessThanOrEqual(calendarLayout.contentFrame.maxY, referenceSize.height)
        let calendarOrigin = try XCTUnwrap(calendarLayout.calendarOrigin)
        let weekOrigin = try XCTUnwrap(calendarLayout.weekOrigin)
        XCTAssertEqual(weekOrigin.x, calendarOrigin.x + 10 * calendarLayout.unit)
        XCTAssertEqual(weekOrigin.y, calendarOrigin.y + 7 * calendarLayout.unit)
        XCTAssertEqual(calendarLayout.timeOrigin.x, calendarOrigin.x + 16 * calendarLayout.unit)
        XCTAssertEqual(calendarLayout.timeOrigin.y, calendarOrigin.y + calendarLayout.unit)
        XCTAssertEqual((calendarLayout.timeOrigin.x - calendarOrigin.x) / calendarLayout.unit,
                       floor((calendarLayout.timeOrigin.x - calendarOrigin.x) / calendarLayout.unit))

        let meridiemSettings = PixelClockSettings(["pixel24Hour": "false", "pixelShowAMPM": "true"])
        let meridiemLayout = PixelClockLayout(size: referenceSize, settings: meridiemSettings,
                                               time: meridiemSettings.timeText(at: date), meridiem: "AM")
        let meridiemOrigin = try XCTUnwrap(meridiemLayout.meridiemOrigin)
        XCTAssertLessThan(meridiemLayout.meridiemUnit, meridiemLayout.unit)
        XCTAssertEqual(meridiemOrigin.y + 2.5 * meridiemLayout.meridiemUnit,
                       meridiemLayout.timeOrigin.y + 2.5 * meridiemLayout.unit, accuracy: 0.001)
        XCTAssertGreaterThan(meridiemOrigin.x,
                             meridiemLayout.timeOrigin.x + CGFloat(PixelClockGlyphs.columns(for: "01:04")) * meridiemLayout.unit)
        XCTAssertLessThanOrEqual(meridiemOrigin.x + CGFloat(PixelClockGlyphs.columns(for: "AM")) * meridiemLayout.meridiemUnit,
                                 meridiemLayout.contentFrame.maxX)

        let timeOnly = PixelClockSettings(["pixelShowDate": "false", "pixelShowWeek": "false", "pixelSize": "m"])
        let centeredLayout = PixelClockLayout(size: referenceSize, settings: timeOnly,
                                               time: timeOnly.timeText(at: date), meridiem: "")
        XCTAssertNil(centeredLayout.calendarOrigin)
        XCTAssertNil(centeredLayout.weekOrigin)
        XCTAssertLessThan(centeredLayout.unit, calendarLayout.unit)
        XCTAssertEqual(centeredLayout.timeOrigin.y, centeredLayout.contentFrame.minY)
        XCTAssertTrue(PixelClockGlyphs.calendarCutout(day: 16, row: 2, column: 2))
        XCTAssertTrue(PixelClockGlyphs.calendarCutout(day: 16, row: 2, column: 5))
        XCTAssertFalse(PixelClockGlyphs.calendarCutout(day: 16, row: 2, column: 0))
        XCTAssertFalse(PixelClockGlyphs.calendarCutout(day: 16, row: 7, column: 2))
    }

    @MainActor func testPixelClockRendersReferenceLayouts() throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-16T18:57:00Z"))
        let variants: [(String, PixelClockSettings)] = [
            ("calendar", PixelClockSettings(["pixelTimeZone": "UTC"])),
            ("calendar-ampm", PixelClockSettings(["pixelTimeZone": "UTC", "pixel24Hour": "false", "pixelShowAMPM": "true", "pixelShowSeconds": "true"])),
            ("time-week", PixelClockSettings(["pixelTimeZone": "UTC", "pixelShowDate": "false"])),
            ("time-only", PixelClockSettings(["pixelTimeZone": "UTC", "pixelShowDate": "false", "pixelShowWeek": "false"]))
        ]
        for (name, settings) in variants {
            let renderer = ImageRenderer(content: PixelClockFace(settings: settings, date: date)
                .frame(width: 1552, height: 420).background(.black))
            renderer.scale = 1
            let image = try XCTUnwrap(renderer.nsImage)
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
            XCTAssertEqual(bitmap.pixelsWide, 1552)
            XCTAssertEqual(bitmap.pixelsHigh, 420)
            if ProcessInfo.processInfo.environment["EDGE_PIXEL_CLOCK_SNAPSHOTS"] == "1" {
                let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: URL(fileURLWithPath: "/private/tmp/edgepanel-pixel-clock-\(name).png"))
            }
        }
    }

    func testNativeClockSettingsAndWidgetCustomizationPersist() throws {
        XCTAssertTrue(try XCTUnwrap(HexColor(hex: "#FFFFFF")).isLight)
        XCTAssertFalse(try XCTUnwrap(HexColor(hex: "#101824")).isLight)
        XCTAssertNil(HexColor(hex: "not-a-color"))

        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-16T13:04:05Z"))
        let settings = NativeClockSettings(["clockFormat": "12", "clockShowDate": "false",
                                            "clockShowSeconds": "false", "clockFont": "mono",
                                            "nativeAccent": "#AA66CC", "clockTimeZone": "UTC"])
        XCTAssertEqual(settings.timeText(at: date), "1:04 PM")
        XCTAssertEqual(settings.timeZone.secondsFromGMT(for: date), 0)
        XCTAssertFalse(settings.showDate)
        XCTAssertFalse(settings.showSeconds)
        XCTAssertEqual(settings.accentHex, "#AA66CC")
        XCTAssertEqual(NativeClockSettings(["clockFormat": "24", "clockTimeZone": "UTC"]).timeText(at: date), "13:04")

        let midnight = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-16T00:30:00Z"))
        let losAngeles = NativeClockSettings(["clockFormat": "24", "clockTimeZone": "America/Los_Angeles"])
        let tokyo = NativeClockSettings(["clockFormat": "24", "clockTimeZone": "Asia/Tokyo"])
        XCTAssertEqual(losAngeles.timeText(at: midnight), "17:30")
        XCTAssertEqual(tokyo.timeText(at: midnight), "09:30")
        XCTAssertNotEqual(losAngeles.dateText(at: midnight), tokyo.dateText(at: midnight))
        XCTAssertNotEqual(NativeClockSettings(["clockTimeZone": "UTC"]).timeText(at: midnight),
                          NativeClockSettings(["clockTimeZone": "Asia/Tokyo"]).timeText(at: midnight))
        XCTAssertEqual(NativeClockSettings(["clockTimeZone": "unknown/zone"]).timeZone.identifier,
                       TimeZone.current.identifier)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PanelStore(root: directory)
        var config = DashboardConfig.initial()
        config.profiles[0].pages[1].tiles[0].settings = ["clockFormat": "12", "nativeAccent": "#AA66CC",
                                                        "clockTimeZone": "Asia/Tokyo", "nativeBackground": "#F4C842"]
        store.save(config)
        XCTAssertEqual(store.load().profiles[0].pages[1].tiles[0].settings["nativeAccent"], "#AA66CC")
        XCTAssertEqual(store.load().profiles[0].pages[1].tiles[0].settings["clockTimeZone"], "Asia/Tokyo")
        XCTAssertEqual(store.load().profiles[0].pages[1].tiles[0].settings["nativeBackground"], "#F4C842")
        XCTAssertNil(store.load().profiles[0].pages[1].tiles[1].settings["nativeBackground"])
    }

    func testTouchMappingClampsToSelectedDisplay() {
        let bounds = CGRect(x: -1920, y: 300, width: 1920, height: 540)
        XCTAssertEqual(TouchTransform.point(rawX: 0, rawY: 0, in: bounds), CGPoint(x: -1920, y: 300))
        XCTAssertEqual(TouchTransform.point(rawX: 16383, rawY: 9599, in: bounds), CGPoint(x: -1, y: 839))
        XCTAssertEqual(TouchTransform.point(rawX: UInt16.max, rawY: UInt16.max, in: bounds), CGPoint(x: -1, y: 839))
        XCTAssertEqual(TouchTransform.point(rawX: 0, rawY: 0, in: bounds, orientation: TouchOrientation(swapAxes: true, invertX: true, invertY: false)), CGPoint(x: -1, y: 300))
    }

    func testDashboardPersistsProfilesAndDisplay() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PanelStore(root: directory)
        var config = DashboardConfig.initial()
        config.selectedDisplay = DisplayIdentity(vendor: 0x0E58, model: 23, serial: 42)
        config.profiles[0].pages[1].tiles[0].title = "Meu relógio"
        config.profiles[0].pages[1].backgroundHex = "#29435A"
        config.profiles[0].pages.append(DashboardPage(name: "Outra página", backgroundHex: "#EAEAEA"))
        store.save(config)
        let loaded = store.load()
        XCTAssertEqual(loaded.selectedDisplay, config.selectedDisplay)
        XCTAssertEqual(loaded.profiles[0].pages[1].tiles[0].title, "Meu relógio")
        XCTAssertEqual(loaded.profiles[0].pages[1].backgroundHex, "#29435A")
        XCTAssertEqual(loaded.profiles[0].pages[2].backgroundHex, "#EAEAEA")
    }

    func testZIPRejectsUnsafePathsAndDuplicateNames() throws {
        let required = ["manifest.json": Data("{}".utf8), "index.html": Data("ok".utf8)]
        XCTAssertNoThrow(try SafeZip(data: zip(required)))
        for path in ["../outside", "/absolute", "a/../../b", "a\\b", "a//b", "a/./b"] {
            var files = required
            files[path] = Data("x".utf8)
            XCTAssertThrowsError(try SafeZip(data: zip(files)), path)
        }
        XCTAssertThrowsError(try SafeZip(data: zip(["index.html": Data("ok".utf8)])))
    }

    func testImporterReportsUnsupportedPlugins() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let manifest = """
        {"name":"Clock","author":"Test","version":"1.0.0","supported_devices":[{"type":"dashboard_lcd"}],"required_plugins":["widgetbuilder.mediadataprovider:Media:1.0"]}
        """
        let archive = directory.appendingPathComponent("clock.icuewidget")
        try zip(["manifest.json": Data(manifest.utf8), "index.html": Data("<html><head></head><body>Clock</body></html>".utf8)]).write(to: archive)
        let imported = try WidgetImporter.importFile(archive, into: directory)
        XCTAssertFalse(imported.compatible)
        XCTAssertTrue(imported.warnings.contains { $0.contains("Media") })
    }

    func testDeflatedICUEPackageIsReadWithoutExtractingOutsideLibrary() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let manifest = """
        {"name":"Clock","author":"Test","version":"1.0.0","supported_devices":[{"type":"dashboard_lcd"}]}
        """
        try manifest.write(to: directory.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
        try "<html><head></head><body>Clock</body></html>".write(to: directory.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        let archive = directory.appendingPathComponent("clock.icuewidget")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = directory
        process.arguments = ["-q", archive.path, "manifest.json", "index.html"]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        let widget = try WidgetImporter.importFile(archive, into: directory.appendingPathComponent("library"))
        XCTAssertTrue(widget.compatible)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("library/\(widget.id.uuidString)/index.html").path))
    }

    private func zip(_ files: [String: Data]) -> Data {
        var local = Data()
        var central = Data()
        for (name, body) in files.sorted(by: { $0.key < $1.key }) {
            let filename = Data(name.utf8)
            let checksum = crc(body)
            let offset = UInt32(local.count)
            local.u32(0x04034b50); local.u16(20); local.u16(0); local.u16(0); local.u16(0); local.u16(0)
            local.u32(checksum); local.u32(UInt32(body.count)); local.u32(UInt32(body.count))
            local.u16(UInt16(filename.count)); local.u16(0); local.append(filename); local.append(body)
            central.u32(0x02014b50); central.u16(20); central.u16(20); central.u16(0); central.u16(0)
            central.u16(0); central.u16(0); central.u32(checksum); central.u32(UInt32(body.count)); central.u32(UInt32(body.count))
            central.u16(UInt16(filename.count)); central.u16(0); central.u16(0); central.u16(0); central.u16(0)
            central.u32(0); central.u32(offset); central.append(filename)
        }
        var result = local
        let centralOffset = UInt32(result.count)
        result.append(central)
        result.u32(0x06054b50); result.u16(0); result.u16(0); result.u16(UInt16(files.count)); result.u16(UInt16(files.count))
        result.u32(UInt32(central.count)); result.u32(centralOffset); result.u16(0)
        return result
    }

    private func crc(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xedb88320 : 0) }
        }
        return crc ^ 0xffffffff
    }
}

private extension Data {
    mutating func u16(_ value: UInt16) { append(UInt8(value & 0xff)); append(UInt8(value >> 8)) }
    mutating func u32(_ value: UInt32) { u16(UInt16(value & 0xffff)); u16(UInt16(value >> 16)) }
}
