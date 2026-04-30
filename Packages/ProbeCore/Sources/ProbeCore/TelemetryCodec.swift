import Foundation

public enum TelemetryEvent: Equatable, Sendable {
    case key(KeyTelemetry)
    case layer(LayerTelemetry)
    case hello(LayerTelemetry)
}

public struct KeyTelemetry: Equatable, Sendable {
    public let pressed: Bool
    public let isTapCandidate: Bool
    public let matrixRow: Int
    public let matrixColumn: Int
    public let activeLayer: Int
    public let keycode: UInt16
    public let mods: UInt8
    public let oneShotMods: UInt8
    public let layerState: UInt32
    public let defaultLayerState: UInt32
    public let eventTime: UInt16
    public let tapCount: UInt8
}

public struct LayerTelemetry: Equatable, Sendable {
    public let activeLayer: Int
    public let layerState: UInt32
    public let defaultLayerState: UInt32
    public let eventTime: UInt16
}

public enum TelemetryCodec {
    public static let reportLength = 32
    public static let protocolVersion: UInt8 = 1
    public static let unspecifiedActiveLayer = -1

    public static func decode(_ bytes: [UInt8]) -> TelemetryEvent? {
        guard bytes.count == reportLength else {
            return nil
        }
        if let event = decodeOryx(bytes) {
            return event
        }

        guard
            bytes[0] == UInt8(ascii: "K"),
            bytes[1] == UInt8(ascii: "H"),
            bytes[2] == protocolVersion
        else {
            return nil
        }

        switch bytes[3] {
        case 1:
            return .key(
                KeyTelemetry(
                    pressed: bytes[4] & 0x01 != 0,
                    isTapCandidate: bytes[4] & 0x02 != 0,
                    matrixRow: Int(bytes[5]),
                    matrixColumn: Int(bytes[6]),
                    activeLayer: Int(bytes[7]),
                    keycode: littleEndianUInt16(bytes[8], bytes[9]),
                    mods: bytes[10],
                    oneShotMods: bytes[11],
                    layerState: littleEndianUInt32(bytes[12], bytes[13], bytes[14], bytes[15]),
                    defaultLayerState: littleEndianUInt32(bytes[16], bytes[17], bytes[18], bytes[19]),
                    eventTime: littleEndianUInt16(bytes[20], bytes[21]),
                    tapCount: bytes[22]
                ))
        case 2:
            return .layer(layerTelemetry(from: bytes))
        case 3:
            return .hello(layerTelemetry(from: bytes))
        default:
            return nil
        }
    }

    private static func decodeOryx(_ bytes: [UInt8]) -> TelemetryEvent? {
        switch bytes[0] {
        case 5 where bytes[2] == 0xFE:
            let layer = Int(bytes[1])
            return .layer(
                LayerTelemetry(
                    activeLayer: layer,
                    layerState: layerState(for: layer),
                    defaultLayerState: 0,
                    eventTime: 0
                ))
        case 6,
            7 where bytes[3] == 0xFE:
            return .key(
                KeyTelemetry(
                    pressed: bytes[0] == 6,
                    isTapCandidate: false,
                    matrixRow: Int(bytes[2]),
                    matrixColumn: Int(bytes[1]),
                    activeLayer: unspecifiedActiveLayer,
                    keycode: 0,
                    mods: 0,
                    oneShotMods: 0,
                    layerState: 0,
                    defaultLayerState: 0,
                    eventTime: 0,
                    tapCount: 0
                ))
        default:
            return nil
        }
    }

    private static func layerTelemetry(from bytes: [UInt8]) -> LayerTelemetry {
        LayerTelemetry(
            activeLayer: Int(bytes[7]),
            layerState: littleEndianUInt32(bytes[12], bytes[13], bytes[14], bytes[15]),
            defaultLayerState: littleEndianUInt32(bytes[16], bytes[17], bytes[18], bytes[19]),
            eventTime: littleEndianUInt16(bytes[20], bytes[21])
        )
    }

    private static func littleEndianUInt16(_ low: UInt8, _ high: UInt8) -> UInt16 {
        UInt16(low) | (UInt16(high) << 8)
    }

    private static func littleEndianUInt32(_ b0: UInt8, _ b1: UInt8, _ b2: UInt8, _ b3: UInt8) -> UInt32 {
        UInt32(b0) | (UInt32(b1) << 8) | (UInt32(b2) << 16) | (UInt32(b3) << 24)
    }

    private static func layerState(for layer: Int) -> UInt32 {
        guard layer >= 0, layer < 32 else { return 0 }
        return UInt32(1) << UInt32(layer)
    }
}
