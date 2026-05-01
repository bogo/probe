import AppKit

enum MenuBarIconChoice: String, CaseIterable {
    case dish
    case moduleDish

    static let defaultChoice = MenuBarIconChoice.moduleDish

    var title: String {
        switch self {
        case .dish:
            "Dish"
        case .moduleDish:
            "Module + Dish"
        }
    }

    var subtitle: String {
        switch self {
        case .dish:
            "Compact antenna silhouette"
        case .moduleDish:
            "Probe module with antenna"
        }
    }

    var resourceName: String {
        switch self {
        case .dish:
            "ProbeStatusIconDish"
        case .moduleDish:
            "ProbeStatusIconModuleDish"
        }
    }

    func image(pointSize: CGFloat) -> NSImage? {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "png"),
            let image = NSImage(contentsOf: url)
        else {
            return nil
        }
        image.accessibilityDescription = "Probe \(title)"
        image.isTemplate = true
        image.size = NSSize(width: pointSize, height: pointSize)
        return image
    }
}

struct MenuBarIconStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> MenuBarIconChoice {
        guard let rawValue = defaults.string(forKey: Key.selectedIcon),
            let choice = MenuBarIconChoice(rawValue: rawValue)
        else {
            return MenuBarIconChoice.defaultChoice
        }
        return choice
    }

    func save(_ choice: MenuBarIconChoice) {
        defaults.set(choice.rawValue, forKey: Key.selectedIcon)
    }

    private enum Key {
        static let selectedIcon = "menuBarIcon.selected"
    }
}

@MainActor
final class ProbeSettingsWindowController: NSWindowController {
    private let settingsView: ProbeSettingsView

    init(selectedIcon: MenuBarIconChoice, onIconSelected: @escaping (MenuBarIconChoice) -> Void) {
        self.settingsView = ProbeSettingsView(selectedIcon: selectedIcon, onIconSelected: onIconSelected)

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 230),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = "Probe Settings"
        window.isReleasedWhenClosed = false
        window.contentView = settingsView
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(selectedIcon: MenuBarIconChoice) {
        settingsView.update(selectedIcon: selectedIcon)
    }
}

private final class ProbeSettingsView: NSView {
    private let onIconSelected: (MenuBarIconChoice) -> Void
    private var selectedIcon: MenuBarIconChoice
    private var buttons: [String: NSButton] = [:]

    init(selectedIcon: MenuBarIconChoice, onIconSelected: @escaping (MenuBarIconChoice) -> Void) {
        self.selectedIcon = selectedIcon
        self.onIconSelected = onIconSelected
        super.init(frame: NSRect(x: 0, y: 0, width: 380, height: 230))
        buildView()
        updateButtons()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(selectedIcon: MenuBarIconChoice) {
        self.selectedIcon = selectedIcon
        updateButtons()
    }

    private func buildView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let title = NSTextField(labelWithString: "Menu Bar Icon")
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.alignment = .center

        let iconRows = NSStackView()
        iconRows.orientation = .vertical
        iconRows.alignment = .leading
        iconRows.spacing = 10

        for choice in MenuBarIconChoice.allCases {
            iconRows.addArrangedSubview(iconRow(for: choice))
        }

        let stack = NSStackView(views: [title, iconRows])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconRows.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func iconRow(for choice: MenuBarIconChoice) -> NSView {
        let imageView = NSImageView()
        imageView.image = choice.image(pointSize: 28)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.contentTintColor = .labelColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 34),
            imageView.heightAnchor.constraint(equalToConstant: 34)
        ])

        let button = NSButton(radioButtonWithTitle: choice.title, target: self, action: #selector(selectIcon))
        button.identifier = NSUserInterfaceItemIdentifier(choice.rawValue)
        button.font = .systemFont(ofSize: 13, weight: .medium)
        buttons[choice.rawValue] = button

        let subtitle = NSTextField(labelWithString: choice.subtitle)
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor

        let textStack = NSStackView(views: [button, subtitle])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let row = NSStackView(views: [imageView, textStack])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func updateButtons() {
        for choice in MenuBarIconChoice.allCases {
            buttons[choice.rawValue]?.state = choice == selectedIcon ? .on : .off
        }
    }

    @objc private func selectIcon(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue,
            let choice = MenuBarIconChoice(rawValue: rawValue)
        else {
            return
        }

        selectedIcon = choice
        updateButtons()
        onIconSelected(choice)
    }
}
