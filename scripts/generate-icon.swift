import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

private let canvas = CGFloat(1024)

private func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [red, green, blue, alpha])!
}

private func rounded(_ context: CGContext, _ rect: CGRect, radius: CGFloat, fill: CGColor,
                     stroke: CGColor? = nil, width: CGFloat = 0) {
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.addPath(path)
    context.setFillColor(fill)
    context.fillPath()
    if let stroke {
        context.addPath(path)
        context.setStrokeColor(stroke)
        context.setLineWidth(width)
        context.strokePath()
    }
}

private func iconImage(size: Int) -> CGImage {
    let space = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                            bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: CGFloat(size) / canvas, y: CGFloat(size) / canvas)
    context.setAllowsAntialiasing(true)

    let body = CGPath(roundedRect: CGRect(x: 34, y: 34, width: 956, height: 956),
                      cornerWidth: 215, cornerHeight: 215, transform: nil)
    context.saveGState()
    context.addPath(body)
    context.clip()
    let gradient = CGGradient(colorsSpace: space,
                              colors: [color(0.035, 0.13, 0.20), color(0.015, 0.045, 0.085)] as CFArray,
                              locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 70, y: 950), end: CGPoint(x: 900, y: 50), options: [])
    context.setFillColor(color(0.06, 0.30, 0.38, 0.27))
    context.fillEllipse(in: CGRect(x: -120, y: 615, width: 600, height: 520))
    context.restoreGState()

    rounded(context, CGRect(x: 112, y: 285, width: 800, height: 454), radius: 104,
            fill: color(0.02, 0.08, 0.13), stroke: color(0.22, 0.78, 0.88), width: 15)
    rounded(context, CGRect(x: 149, y: 322, width: 726, height: 380), radius: 71,
            fill: color(0.035, 0.12, 0.18), stroke: color(0.10, 0.29, 0.37), width: 5)

    let pixelPattern = ["11111", "10000", "10000", "11110", "10000", "10000", "11111"]
    for (row, line) in pixelPattern.enumerated() {
        for (column, dot) in line.enumerated() where dot == "1" {
            rounded(context, CGRect(x: 225 + CGFloat(column) * 39,
                                    y: 377 + CGFloat(6 - row) * 39,
                                    width: 29, height: 29), radius: 5,
                    fill: color(0.36, 0.88, 0.98))
        }
    }

    let bars: [(CGFloat, CGFloat, CGColor)] = [
        (528, 112, color(0.39, 0.80, 0.98)),
        (627, 188, color(0.98, 0.73, 0.31)),
        (726, 252, color(0.71, 0.59, 1.0))
    ]
    for (x, height, shade) in bars {
        rounded(context, CGRect(x: x, y: 376, width: 60, height: height),
                radius: 13, fill: shade)
    }
    rounded(context, CGRect(x: 449, y: 215, width: 126, height: 22), radius: 11,
            fill: color(0.32, 0.75, 0.83, 0.55))
    return context.makeImage()!
}

private func statusImage() -> CGImage {
    let size = 72
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let ink = color(0, 0, 0)
    rounded(context, CGRect(x: 7, y: 17, width: 58, height: 39), radius: 8,
            fill: color(0, 0, 0, 0), stroke: ink, width: 5)
    for (x, height) in [(20.0, 11.0), (32.0, 20.0), (44.0, 27.0)] {
        rounded(context, CGRect(x: x, y: 23, width: 7, height: height), radius: 1.5, fill: ink)
    }
    return context.makeImage()!
}

private func writePNG(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    precondition(CGImageDestinationFinalize(destination), "Could not write \(url.path)")
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources")
let iconset = resources.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
                         (256, 1), (256, 2), (512, 1), (512, 2)] {
    let filename = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
    writePNG(iconImage(size: points * scale), to: iconset.appendingPathComponent(filename))
}
writePNG(statusImage(), to: resources.appendingPathComponent("StatusIcon.png"))
