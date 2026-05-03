import Foundation

public enum KeymapParserError: Error, Equatable, Sendable {
    case noLayoutsFound
    case wrongKeyCount(layer: Int, expected: Int, actual: Int)
    case unbalancedLayout(layer: Int)
}

public enum KeymapParser {
    public static func parse(_ source: String) throws -> [[KeyLabel]] {
        let layoutCalls = try extractLayoutCalls(from: source)
        let tapDanceDefinitions = TapDanceParser.definitions(in: source)
        let parsed = layoutCalls.enumerated().map { _, body in
            splitTopLevel(body).map { KeyExpressionParser.label(for: $0, tapDanceDefinitions: tapDanceDefinitions) }
        }

        for (index, layer) in parsed.enumerated() where layer.count != VoyagerLayout.keyCount {
            throw KeymapParserError.wrongKeyCount(
                layer: index,
                expected: VoyagerLayout.keyCount,
                actual: layer.count
            )
        }

        return parsed
    }

    private static func extractLayoutCalls(from source: String) throws -> [String] {
        let markers = ["LAYOUT_voyager(", "LAYOUT("]
        var searchIndex = source.startIndex
        var layers: [String] = []

        while searchIndex < source.endIndex {
            let match = markers.compactMap { marker -> (Range<String.Index>, String)? in
                guard let range = source.range(of: marker, range: searchIndex..<source.endIndex) else {
                    return nil
                }
                return (range, marker)
            }
            .min { $0.0.lowerBound < $1.0.lowerBound }

            guard let (range, marker) = match else { break }

            let bodyStart = range.upperBound
            let openParen = source.index(range.upperBound, offsetBy: -1)
            guard let closeParen = matchingParen(in: source, openParen: openParen) else {
                throw KeymapParserError.unbalancedLayout(layer: layers.count)
            }

            layers.append(String(source[bodyStart..<closeParen]))
            searchIndex = source.index(after: closeParen)

            if marker == "LAYOUT(" {
                continue
            }
        }

        guard !layers.isEmpty else {
            throw KeymapParserError.noLayoutsFound
        }
        return layers
    }

    private static func matchingParen(in source: String, openParen: String.Index) -> String.Index? {
        var depth = 0
        var index = openParen
        while index < source.endIndex {
            switch source[index] {
            case "(":
                depth += 1
            case ")":
                depth -= 1
                if depth == 0 {
                    return index
                }
            default:
                break
            }
            index = source.index(after: index)
        }
        return nil
    }

    private static func splitTopLevel(_ body: String) -> [String] {
        var tokens: [String] = []
        var start = body.startIndex
        var depth = 0
        var index = body.startIndex

        while index < body.endIndex {
            switch body[index] {
            case "(":
                depth += 1
            case ")":
                depth -= 1
            case "," where depth == 0:
                appendToken(body[start..<index], to: &tokens)
                start = body.index(after: index)
            default:
                break
            }
            index = body.index(after: index)
        }

        appendToken(body[start..<body.endIndex], to: &tokens)
        return tokens
    }

    private static func appendToken(_ slice: Substring, to tokens: inout [String]) {
        let token = slice.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        tokens.append(token)
    }
}

enum KeyExpressionParser {
    static func label(
        for expression: String,
        tapDanceDefinitions: [String: TapDanceDefinition] = [:]
    ) -> KeyLabel {
        let raw = expression.trimmingCharacters(in: .whitespacesAndNewlines)

        if let call = FunctionCall(raw) {
            return label(for: call, raw: raw, tapDanceDefinitions: tapDanceDefinitions)
        }

        if let basic = basicLabel(raw) {
            return basic
        }

        return KeyLabel.unknown(raw)
    }

    private static func label(
        for call: FunctionCall,
        raw: String,
        tapDanceDefinitions: [String: TapDanceDefinition]
    ) -> KeyLabel {
        switch call.name {
        case "MT":
            guard call.arguments.count == 2 else { return KeyLabel.unknown(raw) }
            let tap = label(for: call.arguments[1], tapDanceDefinitions: tapDanceDefinitions)
            return KeyLabel(
                primary: tap.primary,
                secondary: modifierLabel(call.arguments[0]),
                raw: raw,
                role: .modTap
            )
        case "LT":
            guard call.arguments.count == 2 else { return KeyLabel.unknown(raw) }
            let tap = label(for: call.arguments[1], tapDanceDefinitions: tapDanceDefinitions)
            return KeyLabel(
                primary: tap.primary,
                secondary: "Layer \(call.arguments[0].trimmed())",
                raw: raw,
                role: .layerTap
            )
        case "MO", "TO", "TG", "DF", "OSL":
            return KeyLabel(
                primary: call.name,
                secondary: call.arguments.first.map { "Layer \($0.trimmed())" },
                raw: raw,
                role: .layer
            )
        case "LGUI", "RGUI", "LCMD", "RCMD", "LCTL", "RCTL", "LSFT", "RSFT", "LALT", "RALT":
            guard call.arguments.count == 1 else { return KeyLabel.unknown(raw) }
            let inner = label(for: call.arguments[0], tapDanceDefinitions: tapDanceDefinitions)
            let modifier = wrapperModifierLabel(call.name)
            return KeyLabel(
                primary: "\(modifier)+\(inner.primary)",
                secondary: inner.secondary,
                raw: raw,
                role: .chord
            )
        case "TD":
            guard
                call.arguments.count == 1,
                let definition = tapDanceDefinitions[call.arguments[0].trimmed()]
            else {
                return KeyLabel.unknown(raw)
            }
            return definition.label(raw: raw)
        default:
            return KeyLabel.unknown(raw)
        }
    }

    private static func basicLabel(_ keycode: String) -> KeyLabel? {
        if ["KC_TRANSPARENT", "KC_TRNS", "_______"].contains(keycode) {
            return KeyLabel(primary: "", raw: keycode, role: .transparent, isTransparent: true)
        }
        if ["KC_NO", "XXXXXXX"].contains(keycode) {
            return KeyLabel(primary: "", raw: keycode, role: .noOp)
        }
        if keycode == "QK_BOOT" {
            return KeyLabel(primary: "Boot", raw: keycode, role: .bootloader)
        }
        if keycode.hasPrefix("RGB_") {
            return KeyLabel(primary: rgbLabel(keycode), raw: keycode, role: .rgb)
        }
        if keycode.hasPrefix("KC_MS_") || keycode.hasPrefix("NAVIGATOR_") || keycode == "DRAG_SCROLL" {
            return KeyLabel(primary: pointerLabel(keycode), raw: keycode, role: .pointer)
        }
        if keycode.hasPrefix("KC_MEDIA_") || keycode.hasPrefix("KC_AUDIO_") {
            return KeyLabel(primary: mediaLabel(keycode), raw: keycode, role: .media)
        }
        if let label = keycodeLabels[keycode] {
            return KeyLabel(primary: label.primary, secondary: label.secondary, raw: keycode, role: label.role)
        }
        return nil
    }

    private static func modifierLabel(_ modifier: String) -> String {
        modifier
            .split(separator: "|")
            .map { modifierTokenLabel(String($0).trimmed()) }
            .joined(separator: "+")
    }

    private static func modifierTokenLabel(_ token: String) -> String {
        switch token {
        case "MOD_LCTL", "MOD_RCTL": "Ctrl"
        case "MOD_LSFT", "MOD_RSFT": "Shift"
        case "MOD_LALT", "MOD_RALT": "Opt"
        case "MOD_LGUI", "MOD_RGUI": "Cmd"
        case "MOD_HYPR": "Hyper"
        case "MOD_MEH": "Meh"
        default: token.replacingOccurrences(of: "MOD_", with: "")
        }
    }

    private static func wrapperModifierLabel(_ function: String) -> String {
        switch function {
        case "LGUI", "RGUI", "LCMD", "RCMD": "Cmd"
        case "LCTL", "RCTL": "Ctrl"
        case "LSFT", "RSFT": "Shift"
        case "LALT", "RALT": "Opt"
        default: function
        }
    }

    private static func rgbLabel(_ keycode: String) -> String {
        switch keycode {
        case "RGB_TOG": "RGB"
        case "RGB_MODE_FORWARD": "RGB Mode"
        case "RGB_HUD": "Hue -"
        case "RGB_HUI": "Hue +"
        case "RGB_SAD": "Sat -"
        case "RGB_SAI": "Sat +"
        case "RGB_VAD": "Bright -"
        case "RGB_VAI": "Bright +"
        default: keycode.replacingOccurrences(of: "RGB_", with: "RGB ")
        }
    }

    private static func pointerLabel(_ keycode: String) -> String {
        switch keycode {
        case "KC_MS_BTN1": "Mouse 1"
        case "KC_MS_BTN2": "Mouse 2"
        case "DRAG_SCROLL": "Scroll"
        case "NAVIGATOR_INC_CPI": "CPI +"
        case "NAVIGATOR_DEC_CPI": "CPI -"
        case "NAVIGATOR_TURBO": "Turbo"
        case "NAVIGATOR_AIM": "Aim"
        default: keycode.replacingOccurrences(of: "KC_MS_", with: "")
        }
    }

    private static func mediaLabel(_ keycode: String) -> String {
        switch keycode {
        case "KC_MEDIA_PREV_TRACK": "Prev"
        case "KC_MEDIA_PLAY_PAUSE": "Play"
        case "KC_MEDIA_NEXT_TRACK": "Next"
        case "KC_AUDIO_MUTE": "Mute"
        case "KC_AUDIO_VOL_DOWN": "Vol -"
        case "KC_AUDIO_VOL_UP": "Vol +"
        default: keycode.replacingOccurrences(of: "KC_MEDIA_", with: "")
        }
    }

    private static let keycodeLabels: [String: (primary: String, secondary: String?, role: KeyRole)] = [
        "KC_ESCAPE": ("Esc", nil, .normal), "KC_ESC": ("Esc", nil, .normal),
        "KC_TAB": ("Tab", nil, .normal), "KC_SPACE": ("Space", nil, .normal), "KC_SPC": ("Space", nil, .normal),
        "KC_ENTER": ("Return", nil, .normal), "KC_ENT": ("Return", nil, .normal),
        "KC_BSPC": ("Delete", nil, .normal), "KC_BACKSPACE": ("Delete", nil, .normal),
        "KC_GRAVE": ("`", nil, .normal), "KC_GRV": ("`", nil, .normal),
        "KC_BSLS": ("\\", nil, .normal), "KC_QUOTE": ("'", nil, .normal), "KC_QUOT": ("'", nil, .normal),
        "KC_SCLN": (";", nil, .normal), "KC_COMMA": (",", nil, .normal), "KC_DOT": (".", nil, .normal),
        "KC_SLASH": ("/", nil, .normal), "KC_MINUS": ("-", nil, .normal), "KC_EQUAL": ("=", nil, .normal),
        "KC_LBRC": ("[", nil, .normal), "KC_RBRC": ("]", nil, .normal), "KC_LCBR": ("{", nil, .normal),
        "KC_RCBR": ("}", nil, .normal), "KC_EXLM": ("!", nil, .normal), "KC_AT": ("@", nil, .normal),
        "KC_HASH": ("#", nil, .normal), "KC_DLR": ("$", nil, .normal), "KC_PERC": ("%", nil, .normal),
        "KC_CIRC": ("^", nil, .normal), "KC_AMPR": ("&", nil, .normal), "KC_ASTR": ("*", nil, .normal),
        "KC_LPRN": ("(", nil, .normal), "KC_RPRN": (")", nil, .normal), "KC_PLUS": ("+", nil, .normal),
        "KC_TILD": ("~", nil, .normal), "KC_TILDE": ("~", nil, .normal), "KC_UNDS": ("_", nil, .normal),
        "KC_PIPE": ("|", nil, .normal), "KC_COLN": (":", nil, .normal), "KC_DQUO": ("\"", nil, .normal),
        "KC_LT": ("<", nil, .normal), "KC_GT": (">", nil, .normal), "KC_QUES": ("?", nil, .normal),
        "KC_LEFT": ("Left", nil, .normal), "KC_RIGHT": ("Right", nil, .normal), "KC_UP": ("Up", nil, .normal),
        "KC_DOWN": ("Down", nil, .normal), "KC_HOME": ("Home", nil, .normal), "KC_END": ("End", nil, .normal),
        "KC_PGDN": ("Page Down", nil, .normal), "KC_PAGE_UP": ("Page Up", nil, .normal),
        "KC_LEFT_CTRL": ("Ctrl", nil, .modifier), "KC_LCTL": ("Ctrl", nil, .modifier),
        "KC_RIGHT_CTRL": ("Ctrl", nil, .modifier), "KC_RCTL": ("Ctrl", nil, .modifier),
        "KC_LEFT_ALT": ("Opt", nil, .modifier), "KC_LALT": ("Opt", nil, .modifier),
        "KC_RIGHT_ALT": ("Opt", nil, .modifier), "KC_RALT": ("Opt", nil, .modifier),
        "KC_LEFT_GUI": ("Cmd", nil, .modifier), "KC_LGUI": ("Cmd", nil, .modifier),
        "KC_RIGHT_GUI": ("Cmd", nil, .modifier), "KC_RGUI": ("Cmd", nil, .modifier),
        "KC_LEFT_SHIFT": ("Shift", nil, .modifier), "KC_LSFT": ("Shift", nil, .modifier),
        "KC_RIGHT_SHIFT": ("Shift", nil, .modifier), "KC_RSFT": ("Shift", nil, .modifier)
    ]
    .merging(letterLabels) { first, _ in first }
    .merging(numberLabels) { first, _ in first }
    .merging(functionLabels) { first, _ in first }

    private static let letterLabels: [String: (primary: String, secondary: String?, role: KeyRole)] =
        Dictionary(
            uniqueKeysWithValues: "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map {
                ("KC_\($0)", (String($0), nil, .normal))
            })

    private static let numberLabels: [String: (primary: String, secondary: String?, role: KeyRole)] =
        Dictionary(
            uniqueKeysWithValues: (0...9).map {
                ("KC_\($0)", (String($0), nil, .normal))
            })

    private static let functionLabels: [String: (primary: String, secondary: String?, role: KeyRole)] =
        Dictionary(
            uniqueKeysWithValues: (1...24).map {
                ("KC_F\($0)", ("F\($0)", nil, .normal))
            })
}

struct TapDanceDefinition {
    private let singleTap: KeyLabel?
    private let singleHold: KeyLabel?
    private let doubleTap: KeyLabel?
    private let doubleHold: KeyLabel?

    init(actions: [TapDanceStep: KeyLabel]) {
        singleTap = actions[.singleTap]
        singleHold = actions[.singleHold]
        doubleTap = actions[.doubleTap]
        doubleHold = actions[.doubleHold]
    }

    func label(raw: String) -> KeyLabel {
        guard let primary = primaryLabel else {
            return KeyLabel.unknown(raw)
        }

        return KeyLabel(
            primary: primary,
            secondary: secondaryLabel,
            raw: raw,
            role: role
        )
    }

    private var primaryLabel: String? {
        if let singleHold {
            return singleHold.primary
        }
        if let singleTap {
            return singleTap.primary
        }
        if let doubleTap {
            return "2x \(doubleTap.primary)"
        }
        if let doubleHold {
            return "2x Hold \(doubleHold.primary)"
        }
        return nil
    }

    private var secondaryLabel: String? {
        if let doubleTap {
            return "2x \(doubleTap.primary)"
        }
        if let singleTap {
            return singleTap.primary
        }
        if let doubleHold {
            return "2x Hold \(doubleHold.primary)"
        }
        return nil
    }

    private var role: KeyRole {
        if singleHold?.role == .modifier {
            return .modTap
        }
        return .custom
    }
}

enum TapDanceStep: String {
    case singleTap = "SINGLE_TAP"
    case singleHold = "SINGLE_HOLD"
    case doubleTap = "DOUBLE_TAP"
    case doubleHold = "DOUBLE_HOLD"
    case doubleSingleTap = "DOUBLE_SINGLE_TAP"
}

enum TapDanceParser {
    static func definitions(in source: String) -> [String: TapDanceDefinition] {
        let functions = finishedFunctions(in: source)
        return Dictionary(
            uniqueKeysWithValues: functions.compactMap { danceCode, functionName in
                let actions = actions(in: source, functionName: functionName)
                guard !actions.isEmpty else { return nil }
                return (danceCode, TapDanceDefinition(actions: actions))
            }
        )
    }

    private static func finishedFunctions(in source: String) -> [String: String] {
        let pattern = #"\[(DANCE_[A-Za-z0-9_]+)\]\s*=\s*ACTION_TAP_DANCE_FN_ADVANCED\([^,]*,\s*([A-Za-z_][A-Za-z0-9_]*)\s*,"#
        return matches(pattern: pattern, in: source).reduce(into: [:]) { result, match in
            guard match.count == 3 else { return }
            result[match[1]] = match[2]
        }
    }

    private static func actions(in source: String, functionName: String) -> [TapDanceStep: KeyLabel] {
        guard let body = functionBody(named: functionName, in: source) else { return [:] }
        let pattern = #"case\s+(SINGLE_TAP|SINGLE_HOLD|DOUBLE_TAP|DOUBLE_HOLD|DOUBLE_SINGLE_TAP)\s*:\s*(.*?)\s*break\s*;"#
        return matches(pattern: pattern, in: body, dotMatchesLineSeparators: true).reduce(into: [:]) { result, match in
            guard
                match.count == 3,
                let step = TapDanceStep(rawValue: match[1]),
                let keycode = firstKeycode(in: match[2])
            else {
                return
            }
            result[step] = KeyExpressionParser.label(for: keycode)
        }
    }

    private static func functionBody(named functionName: String, in source: String) -> String? {
        var searchRange = source.startIndex..<source.endIndex
        while let nameRange = source.range(of: functionName, range: searchRange) {
            guard
                let brace = source[nameRange.upperBound...].firstIndex(of: "{"),
                let closeBrace = matchingBrace(in: source, openBrace: brace)
            else {
                return nil
            }

            let prefix = source[..<nameRange.lowerBound]
                .split(whereSeparator: { $0.isWhitespace || $0 == "\n" || $0 == ";" })
                .last
                .map(String.init)
            if prefix == "void" {
                let bodyStart = source.index(after: brace)
                return String(source[bodyStart..<closeBrace])
            }

            searchRange = source.index(after: nameRange.lowerBound)..<source.endIndex
        }
        return nil
    }

    private static func firstKeycode(in statement: String) -> String? {
        for functionName in ["register_code16", "register_code", "tap_code16", "tap_code"] {
            guard
                let nameRange = statement.range(of: functionName),
                let openParen = statement[nameRange.upperBound...].firstIndex(of: "("),
                let closeParen = matchingParen(in: statement, openParen: openParen)
            else {
                continue
            }
            let argumentStart = statement.index(after: openParen)
            return String(statement[argumentStart..<closeParen]).trimmed()
        }
        return nil
    }

    private static func matchingParen(in source: String, openParen: String.Index) -> String.Index? {
        matchingDelimiter(in: source, open: "(", close: ")", openIndex: openParen)
    }

    private static func matchingBrace(in source: String, openBrace: String.Index) -> String.Index? {
        matchingDelimiter(in: source, open: "{", close: "}", openIndex: openBrace)
    }

    private static func matchingDelimiter(
        in source: String,
        open: Character,
        close: Character,
        openIndex: String.Index
    ) -> String.Index? {
        var depth = 0
        var index = openIndex
        while index < source.endIndex {
            switch source[index] {
            case open:
                depth += 1
            case close:
                depth -= 1
                if depth == 0 {
                    return index
                }
            default:
                break
            }
            index = source.index(after: index)
        }
        return nil
    }

    private static func matches(
        pattern: String,
        in source: String,
        dotMatchesLineSeparators: Bool = false
    ) -> [[String]] {
        let options: NSRegularExpression.Options = dotMatchesLineSeparators ? [.dotMatchesLineSeparators] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return []
        }
        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        return regex.matches(in: source, range: nsRange).map { match in
            (0..<match.numberOfRanges).map { index in
                guard let range = Range(match.range(at: index), in: source) else { return "" }
                return String(source[range])
            }
        }
    }
}

struct FunctionCall {
    let name: String
    let arguments: [String]

    init?(_ expression: String) {
        let trimmed = expression.trimmed()
        guard let open = trimmed.firstIndex(of: "("), trimmed.last == ")" else {
            return nil
        }
        name = String(trimmed[..<open]).trimmed()
        let innerStart = trimmed.index(after: open)
        let innerEnd = trimmed.index(before: trimmed.endIndex)
        arguments = Self.splitArguments(String(trimmed[innerStart..<innerEnd]))
    }

    private static func splitArguments(_ text: String) -> [String] {
        var args: [String] = []
        var start = text.startIndex
        var depth = 0
        var index = text.startIndex
        while index < text.endIndex {
            switch text[index] {
            case "(":
                depth += 1
            case ")":
                depth -= 1
            case "," where depth == 0:
                args.append(String(text[start..<index]).trimmed())
                start = text.index(after: index)
            default:
                break
            }
            index = text.index(after: index)
        }
        let tail = String(text[start..<text.endIndex]).trimmed()
        if !tail.isEmpty {
            args.append(tail)
        }
        return args
    }
}

extension String {
    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
