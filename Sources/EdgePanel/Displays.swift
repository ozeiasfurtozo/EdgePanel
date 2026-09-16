import AppKit
import CoreGraphics
import Combine

struct ConnectedDisplay: Identifiable {
    var id: CGDirectDisplayID
    var identity: DisplayIdentity
    var name: String
    var screen: NSScreen

    var label: String { "\(name) · \(Int(screen.frame.width)) × \(Int(screen.frame.height))" }
}

@MainActor final class DisplayCatalog: ObservableObject {
    @Published private(set) var displays: [ConnectedDisplay] = []

    init() { refresh() }

    func refresh() {
        displays = NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            let id = CGDirectDisplayID(number.uint32Value)
            return ConnectedDisplay(
                id: id,
                identity: DisplayIdentity(vendor: CGDisplayVendorNumber(id), model: CGDisplayModelNumber(id), serial: CGDisplaySerialNumber(id)),
                name: screen.localizedName,
                screen: screen
            )
        }
    }

    func resolve(_ identity: DisplayIdentity?) -> ConnectedDisplay? {
        guard let identity else { return nil }
        let matches = displays.filter { $0.identity == identity }
        return matches.count == 1 ? matches[0] : nil
    }
}
