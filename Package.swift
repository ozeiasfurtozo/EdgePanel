// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EdgePanel",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "EdgePanel", targets: ["EdgePanel"])],
    targets: [
        .target(name: "ZipInflate", path: "Sources/ZipInflate", publicHeadersPath: "include", linkerSettings: [.linkedLibrary("z")]),
        .executableTarget(name: "EdgePanel", dependencies: ["ZipInflate"], path: "Sources/EdgePanel", linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("IOKit"), .linkedFramework("WebKit"), .linkedFramework("CoreGraphics")]),
        .testTarget(name: "EdgePanelTests", dependencies: ["EdgePanel"], path: "Tests/EdgePanelTests")
    ]
)
