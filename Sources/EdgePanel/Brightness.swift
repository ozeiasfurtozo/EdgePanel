import CoreGraphics
import Combine
import Foundation

enum BrightnessError: LocalizedError {
    case helperMissing
    case noDisplay
    case invalidResponse
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .helperMissing:
            return L("Controle DDC indisponível nesta instalação.", "DDC control is unavailable in this installation.")
        case .noDisplay:
            return L("Selecione a XENEON conectada em Monitor.", "Select the connected XENEON under Display.")
        case .invalidResponse:
            return L("A XENEON não informou um valor de brilho válido.", "The XENEON did not report a valid brightness value.")
        case .commandFailed(let detail):
            return L("Não foi possível controlar o brilho por DDC/CI. \(detail)",
                     "Could not control brightness through DDC/CI. \(detail)")
        }
    }
}

enum DDCBrightness {
    static func selector(for display: DisplayIdentity) -> String {
        "basic=\(display.vendor):\(display.model):\(display.serial)"
    }

    static func value(from response: String) throws -> Int {
        guard let value = Int(response.trimmingCharacters(in: .whitespacesAndNewlines)),
              (0...100).contains(value) else { throw BrightnessError.invalidResponse }
        return value
    }

    static func read(_ display: DisplayIdentity) throws -> Int {
        try value(from: run(["display", selector(for: display), "get", "luminance"]))
    }

    static func write(_ display: DisplayIdentity, percent: Int) throws -> Int {
        let clamped = min(100, max(0, percent))
        return try value(from: run(["display", selector(for: display), "set", "luminance", String(clamped)]))
    }

    private static func run(_ arguments: [String]) throws -> String {
        guard let executable = Bundle.main.executableURL?.deletingLastPathComponent()
            .appendingPathComponent("m1ddc"),
              FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw BrightnessError.helperMissing
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()

        let timeout = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timeout.schedule(deadline: .now() + 5)
        timeout.setEventHandler { if process.isRunning { process.terminate() } }
        timeout.resume()
        process.waitUntilExit()
        timeout.cancel()

        let response = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            throw BrightnessError.commandFailed(response)
        }
        return response
    }
}

private actor DDCCommandQueue {
    func read(_ display: DisplayIdentity) throws -> Int { try DDCBrightness.read(display) }
    func write(_ display: DisplayIdentity, percent: Int) throws -> Int {
        try DDCBrightness.write(display, percent: percent)
    }
}

@MainActor final class BrightnessController: ObservableObject {
    @Published private(set) var percent = 0.0
    @Published private(set) var available = false
    @Published private(set) var applying = false
    @Published private(set) var status = ""

    private let targetDisplay: () -> DisplayIdentity?
    private let commands = DDCCommandQueue()
    private var pending: Task<Void, Never>?
    private var generation = 0

    init(targetDisplay: @escaping () -> DisplayIdentity?) {
        self.targetDisplay = targetDisplay
    }

    func refresh() {
        generation += 1
        let request = generation
        pending?.cancel()
        applying = false
        guard let display = targetDisplay() else {
            available = false
            status = BrightnessError.noDisplay.localizedDescription
            return
        }
        available = false
        status = ""
        Task {
            do {
                let current = try await commands.read(display)
                guard request == generation, targetDisplay() == display else { return }
                percent = Double(current)
                available = true
                status = ""
            } catch {
                guard request == generation else { return }
                available = false
                status = error.localizedDescription
            }
        }
    }

    func set(_ value: Double) {
        guard available, let display = targetDisplay() else { return }
        percent = min(100, max(0, value.rounded()))
        generation += 1
        let request = generation
        pending?.cancel()
        applying = true
        status = ""
        let target = Int(percent)
        pending = Task {
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled, targetDisplay() == display else { return }
            do {
                let written = try await commands.write(display, percent: target)
                guard request == generation, targetDisplay() == display else { return }
                percent = Double(written)
                applying = false
            } catch {
                guard request == generation else { return }
                applying = false
                status = error.localizedDescription
            }
        }
    }
}
