import XCTest

final class RawHIDDiagnosticsTests: XCTestCase {
    func testKeyboardConnectedRequiresOpenRegisteredDevice() {
        var diagnostics = RawHIDDiagnostics()

        XCTAssertFalse(diagnostics.isKeyboardConnected)

        diagnostics.matchedDeviceCount = 1
        XCTAssertFalse(diagnostics.isKeyboardConnected)

        diagnostics.isOpen = true
        XCTAssertFalse(diagnostics.isKeyboardConnected)
        XCTAssertEqual(diagnostics.connectionSummary, "No registered Voyager Raw HID")

        diagnostics.registeredDeviceCount = 1
        XCTAssertTrue(diagnostics.isKeyboardConnected)
        XCTAssertEqual(diagnostics.connectionSummary, "Connected")

        diagnostics.isOpen = false
        XCTAssertFalse(diagnostics.isKeyboardConnected)
    }
}
