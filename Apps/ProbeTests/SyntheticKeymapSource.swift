import ProbeCore

enum SyntheticKeymapSource {
    static let source = makeSource()

    static func layeredKeymap() throws -> LayeredKeymap {
        LayeredKeymap.voyagerDefault(layers: try KeymapParser.parse(source))
    }

    private static func makeSource() -> String {
        let layers = [baseLayer, symbolLayer, navigationLayer, emptyLayer]
        let body = layers.enumerated()
            .map { index, keys in
                """
                  [\(index)] = LAYOUT_voyager(
                    \(keys.joined(separator: ", "))
                  )
                """
            }
            .joined(separator: ",\n")

        return """
            #include QMK_KEYBOARD_H

            const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
            \(body)
            };
            """
    }

    private static let baseLayer = [
        "KC_ESCAPE", "KC_1", "KC_2", "KC_3", "KC_4", "KC_5",
        "KC_6", "KC_7", "KC_8", "KC_9", "KC_0", "KC_BSPC",
        "KC_GRAVE", "KC_Q", "KC_W", "KC_E", "KC_R", "KC_T",
        "KC_Y", "KC_U", "KC_I", "KC_O", "KC_P", "KC_BSLS",
        "MT(MOD_LSFT, KC_TAB)", "KC_A", "KC_S", "KC_D", "KC_F", "KC_G",
        "KC_H", "KC_J", "KC_K", "KC_L", "KC_SCLN", "KC_QUOTE",
        "KC_LEFT_CTRL", "KC_Z", "KC_X", "KC_C", "KC_V", "KC_B",
        "KC_N", "KC_M", "KC_COMMA", "KC_DOT", "KC_SLASH", "KC_ENTER",
        "KC_TAB", "LT(1, KC_SPACE)", "LT(2, KC_SPACE)", "KC_BSPC"
    ]

    private static let emptyLayer = Array(repeating: "KC_TRANSPARENT", count: VoyagerLayout.keyCount)
    private static let symbolLayer = replace(base: emptyLayer, at: 24, with: "KC_TRANSPARENT")
    private static let navigationLayer = replace(base: emptyLayer, at: 26, with: "LGUI(LSFT(KC_4))")

    private static func replace(base: [String], at index: Int, with value: String) -> [String] {
        var copy = base
        copy[index] = value
        return copy
    }
}
