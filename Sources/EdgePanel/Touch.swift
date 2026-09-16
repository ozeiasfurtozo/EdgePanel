import AppKit
import CoreGraphics
import IOKit.hid
import ApplicationServices
import Combine

struct TouchTransform {
    static func point(rawX: UInt16, rawY: UInt16, in bounds: CGRect, orientation: TouchOrientation = TouchOrientation()) -> CGPoint {
        var x = min(1, max(0, Double(rawX) / 16383.0))
        var y = min(1, max(0, Double(rawY) / 9599.0))
        if orientation.swapAxes { swap(&x, &y) }
        if orientation.invertX { x = 1 - x }
        if orientation.invertY { y = 1 - y }
        // CGDisplayBounds has an exclusive right/bottom edge. A point exactly on
        // maxX/maxY can belong to the adjacent monitor in the display layout.
        return CGPoint(x: bounds.minX + x * max(0, bounds.width - 1),
                       y: bounds.minY + y * max(0, bounds.height - 1))
    }
}

@MainActor final class TouchController: ObservableObject {
    @Published private(set) var status = L("Desativado", "Disabled")
    @Published private(set) var connected = false
    @Published private(set) var enabled = false
    @Published private(set) var canPostEvents = false
    @Published private(set) var inputMonitoringGranted = false

    private let targetDisplay: () -> CGDirectDisplayID?
    private let orientation: () -> TouchOrientation
    private var manager: IOHIDManager?
    private var reportBuffer: UnsafeMutablePointer<UInt8>?
    private var activeDevice: IOHIDDevice?
    private var receivedTouch = false
    private var pressed = false
    private var lastPoint = CGPoint.zero
    private var oldCursor = CGPoint.zero
    private var hasOldCursor = false

    init(targetDisplay: @escaping () -> CGDirectDisplayID?, orientation: @escaping () -> TouchOrientation) {
        self.targetDisplay = targetDisplay
        self.orientation = orientation
    }

    func start(requestPermissions: Bool = false) {
        guard manager == nil else { return }
        var access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        if requestPermissions && access == kIOHIDAccessTypeUnknown {
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        }
        inputMonitoringGranted = access == kIOHIDAccessTypeGranted
        guard inputMonitoringGranted else {
            status = L("Permita Monitoramento de Entrada nas definições do macOS", "Allow Input Monitoring in macOS Settings")
            return
        }
        let hid = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(hid, [kIOHIDVendorIDKey: 0x27c0, kIOHIDProductIDKey: 0x0859] as CFDictionary)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(hid, { context, _, _, device in
            guard let context else { return }
            let owner = Unmanaged<TouchController>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in owner.attach(device) }
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(hid, { context, _, _, device in
            guard let context else { return }
            let owner = Unmanaged<TouchController>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in owner.detach(device) }
        }, context)
        IOHIDManagerScheduleWithRunLoop(hid, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let result = IOHIDManagerOpen(hid, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        guard result == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(hid, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            // The open result is authoritative when TCC's preflight result is stale.
            inputMonitoringGranted = result != kIOReturnNotPermitted
                && IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
            status = result == kIOReturnNotPermitted
                ? L("Permita Monitoramento de Entrada nas definições do macOS", "Allow Input Monitoring in macOS Settings")
                : L("Controlador de toque indisponível ou em uso (\(result))", "Touch controller unavailable or in use (\(result))")
            return
        }
        manager = hid
        enabled = true
        canPostEvents = AXIsProcessTrusted()
        if !canPostEvents {
            if requestPermissions {
                _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            }
            status = L("Permita Acessibilidade; toque bloqueado", "Allow Accessibility; touch blocked")
        } else {
            status = targetDisplay() == nil
                ? L("XENEON ausente; toque bloqueado", "XENEON missing; touch blocked")
                : L("A procurar o controlador de toque…", "Looking for touch controller…")
        }
    }

    func stop() {
        releasePress()
        if let hid = manager {
            IOHIDManagerUnscheduleFromRunLoop(hid, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDManagerClose(hid, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        manager = nil
        activeDevice = nil
        receivedTouch = false
        reportBuffer?.deallocate()
        reportBuffer = nil
        enabled = false
        connected = false
        canPostEvents = false
        status = L("Desativado", "Disabled")
    }

    func displayChanged() {
        releasePress()
        guard manager != nil else { return }
        if !canPostEvents {
            status = L("Permita Acessibilidade; toque bloqueado", "Allow Accessibility; touch blocked")
        } else if targetDisplay() == nil {
            status = L("XENEON ausente; toque bloqueado", "XENEON missing; touch blocked")
        } else if connected {
            status = receivedTouch
                ? L("Toque redirecionado para a XENEON", "Touch redirected to the XENEON")
                : L("Controlador ligado; a aguardar toque…", "Controller connected; waiting for touch…")
        }
    }

    func refreshPermissions() {
        let granted = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        inputMonitoringGranted = granted
        if !granted {
            if manager != nil { stop() }
            status = L("Permita Monitoramento de Entrada nas definições do macOS", "Allow Input Monitoring in macOS Settings")
            return
        }
        guard manager != nil else { start(); return }
        let trusted = AXIsProcessTrusted()
        guard trusted != canPostEvents else { return }
        canPostEvents = trusted
        displayChanged()
    }

    func requestPermissions() {
        if manager == nil {
            start(requestPermissions: true)
        } else if !AXIsProcessTrusted() {
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            refreshPermissions()
        }
    }

    private func attach(_ device: IOHIDDevice) {
        guard enabled, manager != nil else { return }
        let page = IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsagePageKey as CFString) as? Int ?? 0
        let usage = IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsageKey as CFString) as? Int ?? 0
        guard page == 1, usage == 2, activeDevice == nil else { return }
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        buffer.initialize(repeating: 0, count: 64)
        reportBuffer = buffer
        activeDevice = device
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, buffer, 64, { context, _, _, _, _, report, length in
            guard let context, length >= 6, length <= 64 else { return }
            let owner = Unmanaged<TouchController>.fromOpaque(context).takeUnretainedValue()
            let bytes = Array(UnsafeBufferPointer(start: report, count: length))
            Task { @MainActor in owner.receive(bytes) }
        }, context)
        connected = true
        receivedTouch = false
        if !canPostEvents {
            status = L("Permita Acessibilidade; toque bloqueado", "Allow Accessibility; touch blocked")
        } else {
            status = targetDisplay() == nil
                ? L("XENEON ausente; toque bloqueado", "XENEON missing; touch blocked")
                : L("Controlador ligado; a aguardar toque…", "Controller connected; waiting for touch…")
        }
    }

    private func detach(_ device: IOHIDDevice) {
        guard let activeDevice, activeDevice === device else { return }
        releasePress()
        self.activeDevice = nil
        receivedTouch = false
        reportBuffer?.deallocate()
        reportBuffer = nil
        connected = false
        status = L("Controlador desligado; a aguardar ligação", "Controller disconnected; waiting for connection")
    }

    private func receive(_ bytes: [UInt8]) {
        guard enabled, connected, bytes.count >= 6, bytes[0] == 0x07 else { return }
        let trusted = AXIsProcessTrusted()
        if trusted != canPostEvents {
            canPostEvents = trusted
            displayChanged()
        }
        guard trusted else { releasePress(); return }
        guard let id = targetDisplay(), CGDisplayIsOnline(id) != 0 else { releasePress(); return }
        let down = bytes[1] & 1 == 1
        if !down { releasePress(); return }
        if !receivedTouch {
            receivedTouch = true
            status = L("Toque redirecionado para a XENEON", "Touch redirected to the XENEON")
        }
        let x = UInt16(bytes[2]) | (UInt16(bytes[3]) << 8)
        let y = UInt16(bytes[4]) | (UInt16(bytes[5]) << 8)
        let point = TouchTransform.point(rawX: x, rawY: y, in: CGDisplayBounds(id), orientation: orientation())
        if !pressed {
            if let current = CGEvent(source: nil)?.location { oldCursor = current; hasOldCursor = true }
            lastPoint = point
            post(.mouseMoved, at: point)
            post(.leftMouseDown, at: point)
            pressed = true
        } else {
            lastPoint = point
            post(.leftMouseDragged, at: point)
        }
    }

    private func releasePress() {
        guard pressed else { return }
        post(.leftMouseUp, at: lastPoint)
        pressed = false
        if hasOldCursor { CGWarpMouseCursorPosition(oldCursor); hasOldCursor = false }
    }

    private func post(_ type: CGEventType, at point: CGPoint) {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    }
}
