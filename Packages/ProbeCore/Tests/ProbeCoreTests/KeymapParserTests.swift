import XCTest

@testable import ProbeCore

final class KeymapParserTests: XCTestCase {
    func testParsesSyntheticVoyagerKeymap() throws {
        let layers = try KeymapParser.parse(SyntheticKeymapSource.source)

        XCTAssertEqual(layers.count, 4)
        XCTAssertTrue(layers.allSatisfy { $0.count == VoyagerLayout.keyCount })

        let keymap = LayeredKeymap.voyagerDefault(layers: layers)
        XCTAssertEqual(keymap.label(forKeyID: 0, onLayer: 0).primary, "Esc")
        XCTAssertEqual(keymap.label(forKeyID: 24, onLayer: 0).primary, "Tab")
        XCTAssertEqual(keymap.label(forKeyID: 24, onLayer: 0).secondary, "Shift")
        XCTAssertEqual(keymap.label(forKeyID: 49, onLayer: 0).primary, "Space")
        XCTAssertEqual(keymap.label(forKeyID: 49, onLayer: 0).secondary, "Layer 1")
        XCTAssertEqual(keymap.label(forKeyID: 26, onLayer: 2).primary, "Cmd+Shift+4")
        XCTAssertEqual(keymap.resolvedLabel(forKeyID: 24, onLayer: 1).primary, "Tab")
    }

    func testMatrixLookupUsesVoyagerCoordinates() {
        let keymap = LayeredKeymap.voyagerDefault(layers: [])

        XCTAssertEqual(keymap.keyID(row: 5, column: 0), 48)
        XCTAssertEqual(keymap.keyID(row: 5, column: 1), 49)
        XCTAssertEqual(keymap.keyID(row: 11, column: 5), 50)
        XCTAssertEqual(keymap.keyID(row: 11, column: 6), 51)
        XCTAssertEqual(keymap.keyID(row: 10, column: 2), 42)
        XCTAssertEqual(keymap.keyID(row: 4, column: 4), 41)

        let emptyLabel = keymap.resolvedLabel(forKeyID: 0, onLayer: 0)
        XCTAssertEqual(emptyLabel.primary, "")
        XCTAssertEqual(emptyLabel.role, .noOp)
    }

    func testDisplayLabelUsesShiftedSymbolsWhenShiftIsActive() {
        XCTAssertEqual(KeyLabel(primary: "1", raw: "KC_1").displayLabel(shifted: true).primary, "!")
        XCTAssertEqual(KeyLabel(primary: ";", raw: "KC_SCLN").displayLabel(shifted: true).primary, ":")
        XCTAssertEqual(KeyLabel(primary: "/", raw: "KC_SLASH").displayLabel(shifted: true).primary, "?")
        XCTAssertEqual(KeyLabel(primary: "A", raw: "KC_A").displayLabel(shifted: true).primary, "A")
        XCTAssertEqual(KeyLabel(primary: "Tab", raw: "KC_TAB").displayLabel(shifted: true).primary, "Tab")
    }

}
