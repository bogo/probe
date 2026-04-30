import Foundation
import IOKit.hid
import ProbeCore

struct RawHIDDiagnostics: Equatable {
    static let noWriteAttempt = "not sent"

    var matchedDeviceCount = 0
    var isOpen = false
    var openResult = "not started"
    var registeredDeviceCount = 0
    var pairingRequestsSent = 0
    var lastPairingRequestResult = noWriteAttempt
    var reportsReceived = 0
    var decodedReports = 0
    var rejectedReports = 0
    var lastReportAt: Date?
    var lastPacketSummary = "none"
    var lastEventSummary = "none"

    var isKeyboardConnected: Bool {
        isOpen && registeredDeviceCount > 0
    }

    var connectionSummary: String {
        if matchedDeviceCount == 0 {
            return "No Voyager Raw HID"
        }
        if !isOpen {
            return "Open failed: \(openResult)"
        }
        if registeredDeviceCount == 0 {
            return "No registered Voyager Raw HID"
        }
        return "Connected"
    }

    var telemetrySummary: String {
        guard isKeyboardConnected else {
            return "Unavailable"
        }
        if reportsReceived == 0 {
            if lastPairingRequestResult != Self.noWriteAttempt && lastPairingRequestResult != "success" {
                return "Pairing request failed: \(lastPairingRequestResult)"
            }
            if pairingRequestsSent > 0 {
                return "Pairing requested; waiting for reports"
            }
            return "Waiting for reports"
        }
        return decodedReports > 0 ? "Receiving reports" : "Receiving undecoded reports"
    }

    var pasteboardReport: String {
        [
            "Probe HID Diagnostics",
            "Connection: \(connectionSummary)",
            "Telemetry: \(telemetrySummary)",
            "Open result: \(openResult)",
            "Matched devices: \(matchedDeviceCount)",
            "Registered devices: \(registeredDeviceCount)",
            "Pairing requests sent: \(pairingRequestsSent)",
            "Last pairing request: \(lastPairingRequestResult)",
            "Reports received: \(reportsReceived)",
            "Decoded reports: \(decodedReports)",
            "Rejected reports: \(rejectedReports)",
            "Last report: \(lastReportAt.map(Self.timestamp) ?? "never")",
            "Last packet: \(lastPacketSummary)",
            "Last event: \(lastEventSummary)"
        ].joined(separator: "\n")
    }

    private static func timestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

final class RawHIDMonitor {
    private let onEvent: (TelemetryEvent) -> Void
    private let onDiagnostics: (RawHIDDiagnostics) -> Void
    private var manager: IOHIDManager?
    private var diagnostics = RawHIDDiagnostics()
    private var devices: [UInt: DeviceRegistration] = [:]

    init(onEvent: @escaping (TelemetryEvent) -> Void, onDiagnostics: @escaping (RawHIDDiagnostics) -> Void) {
        self.onEvent = onEvent
        self.onDiagnostics = onDiagnostics
    }

    func start() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager
        diagnostics = RawHIDDiagnostics()
        emitDiagnostics()

        let matching: [String: Any] = [
            kIOHIDVendorIDKey: 0x3297,
            kIOHIDProductIDKey: 0x1977,
            kIOHIDPrimaryUsagePageKey: 0xFF60,
            kIOHIDPrimaryUsageKey: 0x61
        ]

        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(
            manager,
            { context, _, _, device in
                guard let context else { return }
                let monitor = Unmanaged<RawHIDMonitor>.fromOpaque(context).takeUnretainedValue()
                monitor.register(device)
            }, opaqueSelf)
        IOHIDManagerRegisterDeviceRemovalCallback(
            manager,
            { context, _, _, device in
                guard let context else { return }
                let monitor = Unmanaged<RawHIDMonitor>.fromOpaque(context).takeUnretainedValue()
                monitor.unregister(device)
            }, opaqueSelf)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        diagnostics.openResult = Self.describe(result: openResult)
        diagnostics.isOpen = openResult == kIOReturnSuccess
        for device in matchedDevices(from: manager) {
            register(device)
        }
        refreshDeviceCounts()
        emitDiagnostics()
    }

    func requestLiveViewPairing() {
        for registration in devices.values {
            sendOryxPairingInit(to: registration)
        }
    }

    func stop() {
        guard let manager else { return }
        for registration in devices.values {
            registration.stop()
        }
        devices.removeAll()
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
        diagnostics.isOpen = false
        diagnostics.registeredDeviceCount = 0
        emitDiagnostics()
    }

    private func register(_ device: IOHIDDevice) {
        let key = Self.deviceKey(device)
        guard devices[key] == nil else { return }

        let registration = DeviceRegistration(device: device)
        devices[key] = registration
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(
            device,
            registration.buffer,
            TelemetryCodec.reportLength,
            { context, result, _, _, _, report, reportLength in
                guard let context else { return }
                let monitor = Unmanaged<RawHIDMonitor>.fromOpaque(context).takeUnretainedValue()
                monitor.handleReport(result: result, report: report, reportLength: reportLength)
            },
            opaqueSelf
        )
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        refreshDeviceCounts()
        emitDiagnostics()
        sendOryxPairingInit(to: registration)
    }

    private func unregister(_ device: IOHIDDevice) {
        let key = Self.deviceKey(device)
        devices.removeValue(forKey: key)?.stop()
        refreshDeviceCounts()
        emitDiagnostics()
    }

    private func handleReport(result: IOReturn, report: UnsafeMutablePointer<UInt8>?, reportLength: CFIndex) {
        diagnostics.reportsReceived += 1
        diagnostics.lastReportAt = Date()

        guard result == kIOReturnSuccess, let report else {
            diagnostics.rejectedReports += 1
            diagnostics.lastPacketSummary = "result \(Self.describe(result: result))"
            emitDiagnostics()
            return
        }

        let bytes = Array(UnsafeBufferPointer(start: report, count: reportLength))
        diagnostics.lastPacketSummary = Self.packetSummary(bytes)

        guard reportLength == TelemetryCodec.reportLength, let event = TelemetryCodec.decode(bytes) else {
            diagnostics.rejectedReports += 1
            emitDiagnostics()
            return
        }

        diagnostics.decodedReports += 1
        diagnostics.lastEventSummary = Self.eventSummary(event)
        emitDiagnostics()
        onEvent(event)
    }

    private func refreshDeviceCounts() {
        guard let manager else {
            diagnostics.matchedDeviceCount = 0
            diagnostics.registeredDeviceCount = 0
            return
        }
        diagnostics.matchedDeviceCount = matchedDevices(from: manager).count
        diagnostics.registeredDeviceCount = devices.count
    }

    private func emitDiagnostics() {
        onDiagnostics(diagnostics)
    }

    private func sendOryxPairingInit(to registration: DeviceRegistration) {
        var bytes = [UInt8](repeating: 0, count: TelemetryCodec.reportLength)
        bytes[0] = OryxCommand.pairingInit
        bytes[1] = OryxCommand.stopBit

        let result = bytes.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return kIOReturnBadArgument
            }
            return IOHIDDeviceSetReport(
                registration.device,
                kIOHIDReportTypeOutput,
                CFIndex(0),
                baseAddress,
                CFIndex(buffer.count)
            )
        }

        diagnostics.pairingRequestsSent += 1
        diagnostics.lastPairingRequestResult = Self.describe(result: result)
        emitDiagnostics()
    }

    private func matchedDevices(from manager: IOHIDManager) -> [IOHIDDevice] {
        guard let set = IOHIDManagerCopyDevices(manager) else { return [] }
        let count = CFSetGetCount(set)
        var pointers = [UnsafeRawPointer?](repeating: nil, count: count)
        CFSetGetValues(set, &pointers)
        return pointers.compactMap { pointer in
            guard let pointer else { return nil }
            return Unmanaged<IOHIDDevice>.fromOpaque(pointer).takeUnretainedValue()
        }
    }

    private static func deviceKey(_ device: IOHIDDevice) -> UInt {
        UInt(bitPattern: Unmanaged.passUnretained(device).toOpaque())
    }

    private static func describe(result: IOReturn) -> String {
        if result == kIOReturnSuccess {
            return "success"
        }
        return String(format: "0x%08X", UInt32(bitPattern: result))
    }

    private static func packetSummary(_ bytes: [UInt8]) -> String {
        let prefix = bytes.prefix(12).map { String(format: "%02X", $0) }.joined(separator: " ")
        return "\(bytes.count) bytes [\(prefix)]"
    }

    private static func eventSummary(_ event: TelemetryEvent) -> String {
        switch event {
        case .key(let key):
            let direction = key.pressed ? "down" : "up"
            let layer = key.activeLayer == TelemetryCodec.unspecifiedActiveLayer ? "current layer" : "L\(key.activeLayer)"
            return "key \(direction) row \(key.matrixRow) col \(key.matrixColumn) \(layer) kc \(key.keycode)"
        case .layer(let layer):
            return "layer L\(layer.activeLayer) mask \(String(format: "0x%08X", layer.layerState))"
        case .hello(let layer):
            return "hello L\(layer.activeLayer) mask \(String(format: "0x%08X", layer.layerState))"
        }
    }
}

private enum OryxCommand {
    static let pairingInit: UInt8 = 0x01
    static let stopBit: UInt8 = 0xFE
}

private final class DeviceRegistration {
    let device: IOHIDDevice
    let buffer: UnsafeMutablePointer<UInt8>

    init(device: IOHIDDevice) {
        self.device = device
        buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: TelemetryCodec.reportLength)
        buffer.initialize(repeating: 0, count: TelemetryCodec.reportLength)
    }

    func stop() {
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }

    deinit {
        buffer.deinitialize(count: TelemetryCodec.reportLength)
        buffer.deallocate()
    }
}
