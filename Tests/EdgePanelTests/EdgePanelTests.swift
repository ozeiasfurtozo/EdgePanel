import XCTest
import Foundation
@testable import EdgePanel

final class EdgePanelTests: XCTestCase {
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
        XCTAssertEqual(store.load().profiles[0].pages[0].tiles.first(where: { $0.id == tile.id })?.y, 0)

        model.commitTilePreview(tile.id)
        XCTAssertEqual(store.load().profiles[0].pages[0].tiles.first(where: { $0.id == tile.id })?.y, 2)
        model.previewTile(tile.id) { $0.x = 7; $0.y = 0 }
        XCTAssertTrue(model.tilePreviewRejected)
        model.commitTilePreview(tile.id)
        XCTAssertEqual(store.load().profiles[0].pages[0].tiles.first(where: { $0.id == tile.id })?.y, 2)

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
        config.profiles[0].pages[0].tiles = [tile]
        store.save(config)
        let loaded = try XCTUnwrap(store.load().profiles[0].pages[0].tiles.first)
        XCTAssertEqual(PixelDashSettings(loaded.settings).waterCount(in: loaded.settings, at: now), 4)
        XCTAssertEqual(PixelDashSettings(loaded.settings).timerRemaining(in: loaded.settings, at: now), 45)
    }

    func testPixelClockRespectsTimeZoneFormatAndWeekStart() throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-16T13:04:05Z"))
        let utc = PixelClockSettings(["pixelTimeZone": "UTC"])
        XCTAssertEqual(utc.timeText(at: date), "13:04:05")
        XCTAssertEqual(utc.meridiem(at: date), "")
        XCTAssertEqual(utc.weekdayIndex(at: date), 2) // Wednesday in a Monday-first week.

        let west = PixelClockSettings(["pixelTimeZone": "America/Los_Angeles",
                                       "pixel24Hour": "false",
                                       "pixelShowSeconds": "false",
                                       "pixelWeekStartsMonday": "false"])
        XCTAssertEqual(west.timeText(at: date), "06:04")
        XCTAssertEqual(west.meridiem(at: date), "AM")
        XCTAssertEqual(west.weekdayIndex(at: date), 3) // Wednesday in a Sunday-first week.

        let nextDay = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-19T16:10:00Z"))
        let tokyo = PixelClockSettings(["pixelTimeZone": "Asia/Tokyo", "pixel24Hour": "false", "pixelShowSeconds": "false"])
        XCTAssertEqual(tokyo.timeText(at: nextDay), "01:10")
        XCTAssertEqual(tokyo.meridiem(at: nextDay), "AM")
        XCTAssertEqual(tokyo.weekdayIndex(at: nextDay), 6) // Sunday in Tokyo, with a Monday-first week.
    }

    func testNativeClockSettingsAndWidgetCustomizationPersist() throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-16T13:04:05Z"))
        let utc = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let settings = NativeClockSettings(["clockFormat": "12", "clockShowDate": "false",
                                            "clockShowSeconds": "false", "clockFont": "mono",
                                            "nativeAccent": "#AA66CC"])
        XCTAssertEqual(settings.timeText(at: date, timeZone: utc), "1:04 PM")
        XCTAssertFalse(settings.showDate)
        XCTAssertFalse(settings.showSeconds)
        XCTAssertEqual(settings.accentHex, "#AA66CC")
        XCTAssertEqual(NativeClockSettings(["clockFormat": "24"]).timeText(at: date, timeZone: utc), "13:04")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PanelStore(root: directory)
        var config = DashboardConfig.initial()
        config.profiles[0].pages[0].tiles[0].settings = ["clockFormat": "12", "nativeAccent": "#AA66CC"]
        store.save(config)
        XCTAssertEqual(store.load().profiles[0].pages[0].tiles[0].settings["nativeAccent"], "#AA66CC")
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
        config.profiles[0].pages[0].tiles[0].title = "Meu relógio"
        config.profiles[0].pages[0].backgroundHex = "#29435A"
        config.profiles[0].pages.append(DashboardPage(name: "Outra página", backgroundHex: "#EAEAEA"))
        store.save(config)
        let loaded = store.load()
        XCTAssertEqual(loaded.selectedDisplay, config.selectedDisplay)
        XCTAssertEqual(loaded.profiles[0].pages[0].tiles[0].title, "Meu relógio")
        XCTAssertEqual(loaded.profiles[0].pages[0].backgroundHex, "#29435A")
        XCTAssertEqual(loaded.profiles[0].pages[1].backgroundHex, "#EAEAEA")
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
