import AppKit
import Carbon
import Foundation

/// Registers page navigation with the system so it works while another app is focused.
/// Carbon hot keys receive only the two registered combinations; no keyboard stream is observed.
@MainActor final class PageHotkeys {
    private static let signature: OSType = 0x4550_5047 // "EPPG"
    private weak var model: AppModel?
    private var handler: EventHandlerRef?
    private var previous: EventHotKeyRef?
    private var next: EventHotKeyRef?
    private(set) var failedDirections: [Int] = []
    private(set) var usesFallback = false

    init(model: AppModel) { self.model = model }

    func start() {
        guard handler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), pageHotkeyHandler,
                                         1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else {
            failedDirections = [-1, 1]
            NSLog("EdgePanel: could not install page hotkey handler (status %d)", status)
            return
        }
        failedDirections = []
        usesFallback = Self.systemReservesPrimaryShortcut()
        registerPair(modifiers: usesFallback ? Self.fallbackModifiers : Self.primaryModifiers)
        if !usesFallback && !failedDirections.isEmpty {
            unregisterKeys()
            failedDirections = []
            usesFallback = true
            registerPair(modifiers: Self.fallbackModifiers)
        }
    }

    func stop() {
        unregisterKeys()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
        failedDirections = []
        usesFallback = false
    }

    private static let primaryModifiers = UInt32(controlKey) | UInt32(shiftKey)
    private static let fallbackModifiers = UInt32(controlKey) | UInt32(optionKey)

    private func registerPair(modifiers: UInt32) {
        previous = register(keyCode: UInt32(kVK_UpArrow), id: 1, direction: -1, modifiers: modifiers)
        next = register(keyCode: UInt32(kVK_DownArrow), id: 2, direction: 1, modifiers: modifiers)
    }

    private func unregisterKeys() {
        if let previous { UnregisterEventHotKey(previous) }
        if let next { UnregisterEventHotKey(next) }
        previous = nil
        next = nil
    }

    private func register(keyCode: UInt32, id: UInt32, direction: Int,
                          modifiers: UInt32) -> EventHotKeyRef? {
        let identifier = EventHotKeyID(signature: Self.signature, id: id)
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, identifier,
                                          GetApplicationEventTarget(), 0, &reference)
        if status != noErr {
            failedDirections.append(direction)
            NSLog("EdgePanel: could not register page hotkey %d (status %d)", direction, status)
        }
        return reference
    }

    static func systemReservesPrimaryShortcut() -> Bool {
        let shortcuts = UserDefaults(suiteName: "com.apple.symbolichotkeys")?
            .dictionary(forKey: "AppleSymbolicHotKeys") ?? [:]
        return systemReservesPrimaryShortcut(in: shortcuts)
    }

    static func systemReservesPrimaryShortcut(in shortcuts: [String: Any]) -> Bool {
        let modifiers = Int(NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.shift.rawValue)
        let arrows = [Int(kVK_UpArrow), Int(kVK_DownArrow)]
        return shortcuts.values.contains { raw in
            guard let shortcut = raw as? [String: Any],
                  (shortcut["enabled"] as? NSNumber)?.boolValue == true,
                  let value = shortcut["value"] as? [String: Any],
                  let parameters = value["parameters"] as? [NSNumber],
                  parameters.count >= 3 else { return false }
            return arrows.contains(parameters[1].intValue) && parameters[2].intValue == modifiers
        }
    }

    fileprivate func received(id: EventHotKeyID) {
        guard id.signature == Self.signature else { return }
        switch id.id {
        case 1: model?.navigatePage(by: -1)
        case 2: model?.navigatePage(by: 1)
        default: break
        }
    }
}

private let pageHotkeyHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var identifier = EventHotKeyID(signature: 0, id: 0)
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                   EventParamType(typeEventHotKeyID), nil,
                                   MemoryLayout<EventHotKeyID>.size, nil, &identifier)
    guard status == noErr else { return status }
    let receiver = Unmanaged<PageHotkeys>.fromOpaque(userData).takeUnretainedValue()
    let receivedID = identifier
    Task { @MainActor in receiver.received(id: receivedID) }
    return noErr
}
