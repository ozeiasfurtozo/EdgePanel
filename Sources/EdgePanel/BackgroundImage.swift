import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum BackgroundGeometry {
    static let scales = ["fill", "fit", "stretch", "original"]
    static let horizontal = ["left", "center", "right"]
    static let vertical = ["top", "center", "bottom"]

    static func frame(image: CGSize, container: CGSize, scale: String,
                      horizontal: String, vertical: String) -> CGRect {
        guard image.width > 0, image.height > 0, container.width > 0, container.height > 0 else { return .zero }
        let size: CGSize
        switch scale {
        case "fit":
            let factor = min(container.width / image.width, container.height / image.height)
            size = CGSize(width: image.width * factor, height: image.height * factor)
        case "stretch":
            size = container
        case "original":
            size = image
        default:
            let factor = max(container.width / image.width, container.height / image.height)
            size = CGSize(width: image.width * factor, height: image.height * factor)
        }
        let x = horizontal == "left" ? 0.0 : horizontal == "right" ? 1.0 : 0.5
        let y = vertical == "top" ? 0.0 : vertical == "bottom" ? 1.0 : 0.5
        return CGRect(x: (container.width - size.width) * x,
                      y: (container.height - size.height) * y,
                      width: size.width, height: size.height)
    }
}

private enum BackgroundImageCache {
    static let images = NSCache<NSString, NSImage>()
}

extension PanelStore {
    var backgroundsURL: URL { root.appendingPathComponent("Backgrounds", isDirectory: true) }

    func importBackgroundImage(_ url: URL) throws -> String {
        let ext = url.pathExtension.lowercased()
        guard ["png", "jpg", "jpeg", "heic", "webp", "gif", "tiff"].contains(ext),
              let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= 20_000_000, size > 0,
              let image = NSImage(contentsOf: url), image.size.width > 0, image.size.height > 0 else {
            throw NSError(domain: "EdgePanel", code: 2, userInfo: [NSLocalizedDescriptionKey:
                L("Escolha uma imagem válida de até 20 MB.", "Choose a valid image up to 20 MB.")])
        }
        try FileManager.default.createDirectory(at: backgroundsURL, withIntermediateDirectories: true)
        let filename = "\(UUID().uuidString).\(ext)"
        try FileManager.default.copyItem(at: url, to: backgroundsURL.appendingPathComponent(filename))
        return filename
    }

    func backgroundImage(named filename: String) -> NSImage? {
        guard filename.range(of: "^[0-9A-Fa-f-]{36}\\.(png|jpg|jpeg|heic|webp|gif|tiff)$",
                             options: .regularExpression) != nil else { return nil }
        let url = backgroundsURL.appendingPathComponent(filename)
        let key = url.path as NSString
        if let cached = BackgroundImageCache.images.object(forKey: key) { return cached }
        guard let image = NSImage(contentsOf: url) else { return nil }
        BackgroundImageCache.images.setObject(image, forKey: key)
        return image
    }
}

struct BackgroundImageLayer: View {
    let image: NSImage
    let scale: String
    let horizontal: String
    let vertical: String

    var body: some View {
        GeometryReader { geometry in
            let frame = BackgroundGeometry.frame(image: image.size, container: geometry.size,
                                                 scale: scale, horizontal: horizontal, vertical: vertical)
            Image(nsImage: image)
                .resizable()
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct BackgroundImageControls: View {
    let store: PanelStore
    let filename: Binding<String>
    let scale: Binding<String>
    let horizontal: Binding<String>
    let vertical: Binding<String>
    @State private var error = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(L("Imagem de fundo", "Background image")).font(.subheadline.weight(.semibold))
            HStack {
                Button(L("Escolher imagem…", "Choose image…")) { chooseImage() }
                if !filename.wrappedValue.isEmpty {
                    Button(L("Remover", "Remove")) { filename.wrappedValue = "" }
                        .buttonStyle(.link)
                }
            }
            if let image = store.backgroundImage(named: filename.wrappedValue) {
                BackgroundImageLayer(image: image, scale: scale.wrappedValue,
                                     horizontal: horizontal.wrappedValue, vertical: vertical.wrappedValue)
                    .frame(height: 90)
                    .background(Color.black.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Picker(L("Ajuste", "Sizing"), selection: scale) {
                    Text(L("Preencher", "Fill")).tag("fill")
                    Text(L("Conter", "Contain")).tag("fit")
                    Text(L("Esticar", "Stretch")).tag("stretch")
                    Text(L("Original", "Original")).tag("original")
                }
                HStack {
                    Picker(L("Horizontal", "Horizontal"), selection: horizontal) {
                        Text(L("Esquerda", "Left")).tag("left")
                        Text(L("Centro", "Center")).tag("center")
                        Text(L("Direita", "Right")).tag("right")
                    }
                    Picker(L("Vertical", "Vertical"), selection: vertical) {
                        Text(L("Topo", "Top")).tag("top")
                        Text(L("Centro", "Center")).tag("center")
                        Text(L("Base", "Bottom")).tag("bottom")
                    }
                }
            }
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(.orange) }
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .gif, .tiff, .webP]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                filename.wrappedValue = try store.importBackgroundImage(url)
                error = ""
            } catch { self.error = error.localizedDescription }
        }
    }
}
