import XCTest

@testable import ProbeCore

final class TelemetryCodecTests: XCTestCase {
    func testDecodesKeyEvent() {
        var packet = validPacket(type: 1)
        packet[4] = 0x03
        packet[5] = 5
        packet[6] = 1
        packet[7] = 2
        packet[8] = 0x34
        packet[9] = 0x12
        packet[10] = 0x08
        packet[11] = 0x02
        packet[12] = 0x05
        packet[16] = 0x01
        packet[20] = 0xEF
        packet[21] = 0xBE
        packet[22] = 1

        guard case .key(let event) = TelemetryCodec.decode(packet) else {
            return XCTFail("Expected key event")
        }

        XCTAssertTrue(event.pressed)
        XCTAssertTrue(event.isTapCandidate)
        XCTAssertEqual(event.matrixRow, 5)
        XCTAssertEqual(event.matrixColumn, 1)
        XCTAssertEqual(event.activeLayer, 2)
        XCTAssertEqual(event.keycode, 0x1234)
        XCTAssertEqual(event.mods, 0x08)
        XCTAssertEqual(event.oneShotMods, 0x02)
        XCTAssertEqual(event.layerState, 0x05)
        XCTAssertEqual(event.defaultLayerState, 0x01)
        XCTAssertEqual(event.eventTime, 0xBEEF)
        XCTAssertEqual(event.tapCount, 1)
    }

    func testDecodesLayerAndHelloEvents() {
        var layerPacket = validPacket(type: 2)
        layerPacket[7] = 3
        layerPacket[12] = 0x08
        layerPacket[16] = 0x01

        var helloPacket = validPacket(type: 3)
        helloPacket[7] = 0
        helloPacket[12] = 0x01

        XCTAssertEqual(
            TelemetryCodec.decode(layerPacket),
            .layer(LayerTelemetry(activeLayer: 3, layerState: 0x08, defaultLayerState: 0x01, eventTime: 0))
        )
        XCTAssertEqual(
            TelemetryCodec.decode(helloPacket),
            .hello(LayerTelemetry(activeLayer: 0, layerState: 0x01, defaultLayerState: 0, eventTime: 0))
        )
    }

    func testDecodesOryxRawHIDKeyEvents() {
        var keyDown = [UInt8](repeating: 0, count: TelemetryCodec.reportLength)
        keyDown[0] = 6
        keyDown[1] = 4
        keyDown[2] = 2
        keyDown[3] = 0xFE

        guard case .key(let downEvent) = TelemetryCodec.decode(keyDown) else {
            return XCTFail("Expected Oryx key down")
        }
        XCTAssertTrue(downEvent.pressed)
        XCTAssertEqual(downEvent.matrixColumn, 4)
        XCTAssertEqual(downEvent.matrixRow, 2)
        XCTAssertEqual(downEvent.activeLayer, TelemetryCodec.unspecifiedActiveLayer)

        var keyUp = keyDown
        keyUp[0] = 7
        guard case .key(let upEvent) = TelemetryCodec.decode(keyUp) else {
            return XCTFail("Expected Oryx key up")
        }
        XCTAssertFalse(upEvent.pressed)
    }

    func testDecodesOryxRawHIDLayerEvents() {
        var packet = [UInt8](repeating: 0, count: TelemetryCodec.reportLength)
        packet[0] = 5
        packet[1] = 3
        packet[2] = 0xFE

        XCTAssertEqual(
            TelemetryCodec.decode(packet),
            .layer(LayerTelemetry(activeLayer: 3, layerState: 0x08, defaultLayerState: 0, eventTime: 0))
        )
    }

    func testRejectsWrongMagicAndVersion() {
        var packet = validPacket(type: 1)
        packet[0] = UInt8(ascii: "X")
        XCTAssertNil(TelemetryCodec.decode(packet))

        packet = validPacket(type: 1)
        packet[2] = 2
        XCTAssertNil(TelemetryCodec.decode(packet))
    }

    private func validPacket(type: UInt8) -> [UInt8] {
        var packet = [UInt8](repeating: 0, count: TelemetryCodec.reportLength)
        packet[0] = UInt8(ascii: "K")
        packet[1] = UInt8(ascii: "H")
        packet[2] = TelemetryCodec.protocolVersion
        packet[3] = type
        return packet
    }
}
