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
        XCTAssertEqual(diagnostics.lastPairingRequestResult, RawHIDDiagnostics.noWriteAttempt)

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

        diagnostics.pairingRequestsSent = 1
        diagnostics.lastPairingRequestResult = "success"
        XCTAssertEqual(diagnostics.telemetrySummary, "Pairing requested; waiting for reports")

        diagnostics.lastPairingRequestResult = "0xE00002D7"
        XCTAssertEqual(diagnostics.telemetrySummary, "Pairing request failed: 0xE00002D7")

        diagnostics.lastPairingRequestResult = "success"
        diagnostics.reportsReceived = 3
        diagnostics.rejectedReports = 3
        XCTAssertEqual(diagnostics.telemetrySummary, "Receiving undecoded reports")

        diagnostics.decodedReports = 1
        XCTAssertEqual(diagnostics.telemetrySummary, "Receiving reports")
    }

    func testPasteboardReportIncludesPairingRequests() {
        let diagnostics = RawHIDDiagnostics(
            matchedDeviceCount: 1,
            isOpen: true,
            openResult: "success",
            registeredDeviceCount: 1,
            pairingRequestsSent: 2,
            lastPairingRequestResult: "success"
        )

        XCTAssertTrue(diagnostics.pasteboardReport.contains("Pairing requests sent: 2"))
        XCTAssertTrue(diagnostics.pasteboardReport.contains("Last pairing request: success"))
    }
}
