import XCTest

final class RawHIDDiagnosticsTests: XCTestCase {
    func testKeyboardConnectedRequiresOpenRegisteredDevice() {
        var diagnostics = RawHIDDiagnostics()

        XCTAssertFalse(diagnostics.isKeyboardConnected)
        XCTAssertEqual(diagnostics.telemetrySummary, "Unavailable")

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

    func testTelemetrySummaryDescribesReportFlow() {
        var diagnostics = RawHIDDiagnostics(
            matchedDeviceCount: 1,
            isOpen: true,
            openResult: "success",
            registeredDeviceCount: 1
        )

        XCTAssertEqual(diagnostics.telemetrySummary, "Waiting for reports")

        diagnostics.reportsReceived = 3
        diagnostics.rejectedReports = 3
        XCTAssertEqual(diagnostics.telemetrySummary, "Receiving undecoded reports")

        diagnostics.decodedReports = 1
        XCTAssertEqual(diagnostics.telemetrySummary, "Receiving reports")
    }
}
