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

    func testDisplayLabelUsesMacOSKeyGlyphsWhenEnabled() {
        XCTAssertEqual(KeyLabel(primary: "Esc", raw: "KC_ESC").displayLabel(shifted: false, usesSymbolicKeyLabels: true).primary, "⎋")
        XCTAssertEqual(KeyLabel(primary: "Tab", raw: "KC_TAB").displayLabel(shifted: false, usesSymbolicKeyLabels: true).primary, "⇥")
        XCTAssertEqual(KeyLabel(primary: "Shift", raw: "KC_LSFT").displayLabel(shifted: false, usesSymbolicKeyLabels: true).primary, "⇧")
        XCTAssertEqual(KeyLabel(primary: "Ctrl", raw: "KC_LCTL").displayLabel(shifted: false, usesSymbolicKeyLabels: true).primary, "⌃")
        XCTAssertEqual(KeyLabel(primary: "Delete", raw: "KC_BSPC").displayLabel(shifted: false, usesSymbolicKeyLabels: true).primary, "⌫")
        XCTAssertEqual(KeyLabel(primary: "Return", raw: "KC_ENT").displayLabel(shifted: false, usesSymbolicKeyLabels: true).primary, "↩")
        XCTAssertEqual(
            KeyLabel(primary: "Cmd+Shift+4", raw: "LGUI(LSFT(KC_4))")
                .displayLabel(shifted: false, usesSymbolicKeyLabels: true)
                .primary,
            "⌘⇧4"
        )
        XCTAssertEqual(
            KeyLabel(primary: "Shift", secondary: "2x Tab", raw: "TD(DANCE_0)")
                .displayLabel(shifted: false, usesSymbolicKeyLabels: true)
                .secondary,
            "2x ⇥"
        )
    }

    func testParsesOryxTapDanceHoldAndDoubleTapLabels() throws {
        let source =
            SyntheticKeymapSource.source
            .replacingOccurrences(of: "MT(MOD_LSFT, KC_TAB)", with: "TD(DANCE_0)")
                + """

                enum tap_dance_codes {
                  DANCE_0,
                };

                void dance_0_finished(tap_dance_state_t *state, void *user_data);
                void dance_0_reset(tap_dance_state_t *state, void *user_data);

                void dance_0_finished(tap_dance_state_t *state, void *user_data) {
                    dance_state[0].step = dance_step(state);
                    switch (dance_state[0].step) {
                        case SINGLE_HOLD: register_code16(KC_LEFT_SHIFT); break;
                        case DOUBLE_TAP: register_code16(KC_TAB); break;
                    }
                }

                tap_dance_action_t tap_dance_actions[] = {
                        [DANCE_0] = ACTION_TAP_DANCE_FN_ADVANCED(NULL, dance_0_finished, dance_0_reset),
                };
                """

        let layers = try KeymapParser.parse(source)
        let keymap = LayeredKeymap.voyagerDefault(layers: layers)
        let label = keymap.label(forKeyID: 24, onLayer: 0)

        XCTAssertEqual(label.primary, "Shift")
        XCTAssertEqual(label.secondary, "2x Tab")
        XCTAssertEqual(label.raw, "TD(DANCE_0)")
        XCTAssertEqual(label.role, .modTap)
    }

}
