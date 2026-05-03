import Foundation

public struct PhysicalKey: Codable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let matrixRow: Int
    public let matrixColumn: Int
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public let rotation: Double

    public init(
        id: Int,
        matrixRow: Int,
        matrixColumn: Int,
        x: Double,
        y: Double,
        width: Double = 0.94,
        height: Double = 0.94,
        rotation: Double = 0
    ) {
        self.id = id
        self.matrixRow = matrixRow
        self.matrixColumn = matrixColumn
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rotation = rotation
    }
}

public enum KeyRole: String, Codable, Sendable {
    case normal
    case transparent
    case noOp
    case modifier
    case modTap
    case layerTap
    case chord
    case layer
    case media
    case pointer
    case rgb
    case bootloader
    case custom
}

public struct KeyLabel: Codable, Hashable, Sendable {
    public let primary: String
    public let secondary: String?
    public let raw: String
    public let role: KeyRole
    public let isTransparent: Bool

    public init(
        primary: String,
        secondary: String? = nil,
        raw: String,
        role: KeyRole = .normal,
        isTransparent: Bool = false
    ) {
        self.primary = primary
        self.secondary = secondary
        self.raw = raw
        self.role = role
        self.isTransparent = isTransparent
    }

    public static func unknown(_ raw: String) -> KeyLabel {
        KeyLabel(primary: raw, raw: raw, role: .custom)
    }

    public func displayLabel(shifted: Bool, usesSymbolicKeyLabels: Bool = false) -> KeyLabel {
        let shiftedLabel =
            if shifted, let shiftedPrimary = Self.shiftedPrimary(for: self) {
                KeyLabel(
                    primary: shiftedPrimary,
                    secondary: secondary,
                    raw: raw,
                    role: role,
                    isTransparent: isTransparent
                )
            } else {
                self
            }

        guard usesSymbolicKeyLabels else {
            return shiftedLabel
        }
        return shiftedLabel.symbolicLabel()
    }

    private static func shiftedPrimary(for label: KeyLabel) -> String? {
        guard label.role != .transparent, label.role != .noOp else { return nil }
        if let shifted = shiftedPrimaryLabels[label.primary] {
            return shifted
        }

        let rawKeycode = label.raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return shiftedRawLabels[rawKeycode]
    }

    private static let shiftedPrimaryLabels: [String: String] = [
        "`": "~", "1": "!", "2": "@", "3": "#", "4": "$", "5": "%", "6": "^",
        "7": "&", "8": "*", "9": "(", "0": ")", "-": "_", "=": "+",
        "[": "{", "]": "}", "\\": "|", ";": ":", "'": "\"", ",": "<",
        ".": ">", "/": "?"
    ]

    private static let shiftedRawLabels: [String: String] = [
        "KC_GRAVE": "~", "KC_GRV": "~", "KC_1": "!", "KC_2": "@", "KC_3": "#",
        "KC_4": "$", "KC_5": "%", "KC_6": "^", "KC_7": "&", "KC_8": "*",
        "KC_9": "(", "KC_0": ")", "KC_MINUS": "_", "KC_MINS": "_",
        "KC_EQUAL": "+", "KC_EQL": "+", "KC_LBRC": "{", "KC_RBRC": "}",
        "KC_BSLS": "|", "KC_SCLN": ":", "KC_QUOTE": "\"", "KC_QUOT": "\"",
        "KC_COMMA": "<", "KC_COMM": "<", "KC_DOT": ">", "KC_SLASH": "?",
        "KC_SLSH": "?"
    ]

    private func symbolicLabel() -> KeyLabel {
        KeyLabel(
            primary: Self.symbolicText(for: primary),
            secondary: secondary.map(Self.symbolicText(for:)),
            raw: raw,
            role: role,
            isTransparent: isTransparent
        )
    }

    private static func symbolicText(for text: String) -> String {
        if let symbol = symbolicLabels[text] {
            return symbol
        }

        if text.hasPrefix("2x ") {
            let tail = String(text.dropFirst(3))
            return "2x \(symbolicText(for: tail))"
        }

        if text.hasPrefix("Hold ") {
            let tail = String(text.dropFirst(5))
            return "Hold \(symbolicText(for: tail))"
        }

        if text.contains("+") {
            let parts = text.split(separator: "+").map { symbolicText(for: String($0)) }
            return parts.joined()
        }

        return text
    }

    private static let symbolicLabels: [String: String] = [
        "Esc": "⎋",
        "Escape": "⎋",
        "Tab": "⇥",
        "Shift": "⇧",
        "Ctrl": "⌃",
        "Control": "⌃",
        "Opt": "⌥",
        "Option": "⌥",
        "Cmd": "⌘",
        "Command": "⌘",
        "Space": "␣",
        "Delete": "⌫",
        "Del": "⌫",
        "Bksp": "⌫",
        "Backspace": "⌫",
        "Forward Delete": "⌦",
        "Return": "↩",
        "Enter": "⌤",
        "Caps Lock": "⇪",
        "Left": "←",
        "Right": "→",
        "Up": "↑",
        "Down": "↓",
        "Home": "↖",
        "End": "↘",
        "Page Up": "⇞",
        "Page Down": "⇟"
    ]
}

public struct LayeredKeymap: Sendable {
    public let physicalKeys: [PhysicalKey]
    public let layers: [[KeyLabel]]
    private let matrixLookup: [MatrixKey: Int]

    public init(physicalKeys: [PhysicalKey], layers: [[KeyLabel]]) {
        self.physicalKeys = physicalKeys
        self.layers = layers
        self.matrixLookup = Dictionary(
            uniqueKeysWithValues: physicalKeys.map {
                (MatrixKey(row: $0.matrixRow, column: $0.matrixColumn), $0.id)
            }
        )
    }

    public static func voyagerDefault(layers: [[KeyLabel]]) -> LayeredKeymap {
        LayeredKeymap(physicalKeys: VoyagerLayout.defaultPhysicalKeys, layers: layers)
    }

    public func keyID(row: Int, column: Int) -> Int? {
        matrixLookup[MatrixKey(row: row, column: column)]
    }

    public func label(forKeyID keyID: Int, onLayer layer: Int) -> KeyLabel {
        if layers.isEmpty {
            return KeyLabel(primary: "", raw: "", role: .noOp)
        }
        guard layers.indices.contains(layer), layers[layer].indices.contains(keyID) else {
            return KeyLabel.unknown("Key \(keyID)")
        }
        return layers[layer][keyID]
    }

    public func resolvedLabel(forKeyID keyID: Int, onLayer layer: Int) -> KeyLabel {
        var currentLayer = min(layer, layers.count - 1)
        while currentLayer >= 0 {
            let label = label(forKeyID: keyID, onLayer: currentLayer)
            if !label.isTransparent {
                return label
            }
            currentLayer -= 1
        }
        return label(forKeyID: keyID, onLayer: layer)
    }

    public func maxHeat(in snapshot: HeatmapSnapshot, layer: Int) -> Int {
        physicalKeys
            .map { snapshot.allTimeCount(layer: layer, keyID: $0.id) }
            .max() ?? 0
    }
}

public struct MatrixKey: Codable, Hashable, Sendable {
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
}
