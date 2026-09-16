import AppKit
import SwiftUI

struct HexColor {
    let red: Double
    let green: Double
    let blue: Double

    init?(hex: String?) {
        guard let hex = hex?.trimmingCharacters(in: .whitespacesAndNewlines),
              hex.hasPrefix("#"), hex.count == 7,
              let rgb = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        red = Double((rgb >> 16) & 255) / 255
        green = Double((rgb >> 8) & 255) / 255
        blue = Double(rgb & 255) / 255
    }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
    var isLight: Bool { 0.2126 * red + 0.7152 * green + 0.0722 * blue > 0.56 }
}

extension Color {
    var hexString: String {
        guard let color = NSColor(self).usingColorSpace(.deviceRGB) else { return "#FFFFFF" }
        return String(format: "#%02X%02X%02X", Int(color.redComponent * 255),
                      Int(color.greenComponent * 255), Int(color.blueComponent * 255))
    }
}
