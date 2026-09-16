// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EdgePanel",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "EdgePanel", targets: ["EdgePanel"])],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .target(name: "ZipInflate", path: "Sources/ZipInflate", publicHeadersPath: "include", linkerSettings: [.linkedLibrary("z")]),
        .executableTarget(name: "EdgePanel", dependencies: ["ZipInflate", .product(name: "Sparkle", package: "Sparkle")], path: "Sources/EdgePanel", linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("Carbon"), .linkedFramework("IOKit"), .linkedFramework("WebKit"), .linkedFramework("CoreGraphics"), .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "EdgePanelTests", dependencies: ["EdgePanel"], path: "Tests/EdgePanelTests")
    ]
)
