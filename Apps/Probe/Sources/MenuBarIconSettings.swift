import AppKit
import ProbeCore

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

struct ProbeSettingsState {
    var selectedIcon: MenuBarIconChoice
    var usesSymbolicKeyLabels: Bool
    var keyboardColorTheme: KeyboardColorTheme
    var heatmapColorTheme: HeatmapColorTheme
    var graphColorTheme: GraphColorTheme
    var scale: CGFloat
    var opacity: CGFloat
    var showsHeatmap: Bool
    var showsTypingStats: Bool
    var keymap: LayeredKeymap
    var activeLayer: Int
    var hasUsableKeymap: Bool
}

@MainActor
final class ProbeSettingsWindowController: NSWindowController {
    private let splitController: ProbeSettingsSplitViewController

    init(
        state: ProbeSettingsState,
        onIconSelected: @escaping (MenuBarIconChoice) -> Void,
        onSymbolicKeyLabelsChanged: @escaping (Bool) -> Void,
        onKeyboardColorThemeChanged: @escaping (KeyboardColorTheme) -> Void,
        onHeatmapColorThemeChanged: @escaping (HeatmapColorTheme) -> Void,
        onGraphColorThemeChanged: @escaping (GraphColorTheme) -> Void,
        onScaleChanged: @escaping (CGFloat) -> Void,
        onOpacityChanged: @escaping (CGFloat) -> Void,
        onHeatmapVisibilityChanged: @escaping (Bool) -> Void,
        onTypingStatsVisibilityChanged: @escaping (Bool) -> Void,
        onImportKeymap: @escaping () -> Void,
        onImportKeymapAt: @escaping (URL) -> Void
    ) {
        self.splitController = ProbeSettingsSplitViewController(
            state: state,
            onIconSelected: onIconSelected,
            onSymbolicKeyLabelsChanged: onSymbolicKeyLabelsChanged,
            onKeyboardColorThemeChanged: onKeyboardColorThemeChanged,
            onHeatmapColorThemeChanged: onHeatmapColorThemeChanged,
            onGraphColorThemeChanged: onGraphColorThemeChanged,
            onScaleChanged: onScaleChanged,
            onOpacityChanged: onOpacityChanged,
            onHeatmapVisibilityChanged: onHeatmapVisibilityChanged,
            onTypingStatsVisibilityChanged: onTypingStatsVisibilityChanged,
            onImportKeymap: onImportKeymap,
            onImportKeymapAt: onImportKeymapAt
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Probe Settings"
        window.minSize = NSSize(width: 760, height: 520)
        window.isReleasedWhenClosed = false
        window.contentViewController = splitController
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unified
        }
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(state: ProbeSettingsState) {
        splitController.update(state: state)
    }
}

private enum ProbeSettingsSection: String, CaseIterable {
    case display
    case keyboard
    case menuBar

    var title: String {
        switch self {
        case .display:
            "Display"
        case .keyboard:
            "Keyboard"
        case .menuBar:
            "Menu Bar"
        }
    }

    var symbolName: String {
        switch self {
        case .display:
            "rectangle.on.rectangle"
        case .keyboard:
            "keyboard"
        case .menuBar:
            "menubar.rectangle"
        }
    }
}

@MainActor
private final class ProbeSettingsSplitViewController: NSSplitViewController {
    private let sidebarController: ProbeSettingsSidebarViewController
    private let detailController: ProbeSettingsDetailViewController

    init(
        state: ProbeSettingsState,
        onIconSelected: @escaping (MenuBarIconChoice) -> Void,
        onSymbolicKeyLabelsChanged: @escaping (Bool) -> Void,
        onKeyboardColorThemeChanged: @escaping (KeyboardColorTheme) -> Void,
        onHeatmapColorThemeChanged: @escaping (HeatmapColorTheme) -> Void,
        onGraphColorThemeChanged: @escaping (GraphColorTheme) -> Void,
        onScaleChanged: @escaping (CGFloat) -> Void,
        onOpacityChanged: @escaping (CGFloat) -> Void,
        onHeatmapVisibilityChanged: @escaping (Bool) -> Void,
        onTypingStatsVisibilityChanged: @escaping (Bool) -> Void,
        onImportKeymap: @escaping () -> Void,
        onImportKeymapAt: @escaping (URL) -> Void
    ) {
        let detailController = ProbeSettingsDetailViewController(
            state: state,
            onIconSelected: onIconSelected,
            onSymbolicKeyLabelsChanged: onSymbolicKeyLabelsChanged,
            onKeyboardColorThemeChanged: onKeyboardColorThemeChanged,
            onHeatmapColorThemeChanged: onHeatmapColorThemeChanged,
            onGraphColorThemeChanged: onGraphColorThemeChanged,
            onScaleChanged: onScaleChanged,
            onOpacityChanged: onOpacityChanged,
            onHeatmapVisibilityChanged: onHeatmapVisibilityChanged,
            onTypingStatsVisibilityChanged: onTypingStatsVisibilityChanged,
            onImportKeymap: onImportKeymap,
            onImportKeymapAt: onImportKeymapAt
        )
        self.detailController = detailController
        self.sidebarController = ProbeSettingsSidebarViewController(
            selectedSection: .display,
            onSelectionChanged: { [weak detailController] section in
                detailController?.select(section: section)
            }
        )
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.isVertical = true
        splitView.dividerStyle = .thin

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.minimumThickness = 184
        sidebarItem.maximumThickness = 220
        sidebarItem.canCollapse = false

        let detailItem = NSSplitViewItem(viewController: detailController)
        detailItem.minimumThickness = 520

        addSplitViewItem(sidebarItem)
        addSplitViewItem(detailItem)
    }

    func update(state: ProbeSettingsState) {
        detailController.update(state: state)
    }
}

@MainActor
private final class ProbeSettingsSidebarViewController: NSViewController {
    private let onSelectionChanged: (ProbeSettingsSection) -> Void
    private var selectedSection: ProbeSettingsSection
    private var buttons: [ProbeSettingsSection: SidebarButton] = [:]

    init(selectedSection: ProbeSettingsSection, onSelectionChanged: @escaping (ProbeSettingsSection) -> Void) {
        self.selectedSection = selectedSection
        self.onSelectionChanged = onSelectionChanged
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let effectView = NSVisualEffectView()
        effectView.material = .sidebar
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        view = effectView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        for section in ProbeSettingsSection.allCases {
            let button = SidebarButton(section: section, target: self, action: #selector(selectSection))
            button.identifier = NSUserInterfaceItemIdentifier(section.rawValue)
            buttons[section] = button
            stack.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 66)
        ])
        updateButtons()
    }

    @objc private func selectSection(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue,
            let section = ProbeSettingsSection(rawValue: rawValue)
        else {
            return
        }

        selectedSection = section
        updateButtons()
        onSelectionChanged(section)
    }

    private func updateButtons() {
        for (section, button) in buttons {
            button.isSelected = section == selectedSection
        }
    }
}

private final class SidebarButton: NSButton {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")

    var isSelected = false {
        didSet {
            updateSelectionAppearance()
            needsDisplay = true
        }
    }

    init(section: ProbeSettingsSection, target: AnyObject, action: Selector) {
        super.init(frame: .zero)
        self.target = target
        self.action = action
        title = ""
        isBordered = false
        setButtonType(.momentaryChange)
        alignment = .left
        setAccessibilityLabel(section.title)

        iconView.image = NSImage(systemSymbolName: section.symbolName, accessibilityDescription: section.title)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        addSubview(iconView)

        titleLabel.stringValue = section.title
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 30),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 7),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        updateSelectionAppearance()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        if isSelected {
            NSColor.controlAccentColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 0, dy: 1), xRadius: 6, yRadius: 6).fill()
        }
    }

    private func updateSelectionAppearance() {
        let color: NSColor = isSelected ? .white : .labelColor
        iconView.contentTintColor = color
        titleLabel.textColor = color
    }
}

@MainActor
private final class ProbeSettingsDetailViewController: NSViewController {
    private let onIconSelected: (MenuBarIconChoice) -> Void
    private let onSymbolicKeyLabelsChanged: (Bool) -> Void
    private let onKeyboardColorThemeChanged: (KeyboardColorTheme) -> Void
    private let onHeatmapColorThemeChanged: (HeatmapColorTheme) -> Void
    private let onGraphColorThemeChanged: (GraphColorTheme) -> Void
    private let onScaleChanged: (CGFloat) -> Void
    private let onOpacityChanged: (CGFloat) -> Void
    private let onHeatmapVisibilityChanged: (Bool) -> Void
    private let onTypingStatsVisibilityChanged: (Bool) -> Void
    private let onImportKeymap: () -> Void
    private let onImportKeymapAt: (URL) -> Void

    private var state: ProbeSettingsState
    private var selectedSection = ProbeSettingsSection.display
    private let scrollView = NSScrollView()
    private let contentStack = NSStackView()

    private var glyphCheckbox: NSButton?
    private var heatmapCheckbox: NSButton?
    private var typingStatsCheckbox: NSButton?
    private var scaleControl: NSSegmentedControl?
    private var opacityControl: NSSegmentedControl?
    private var iconButtons: [MenuBarIconChoice: NSButton] = [:]
    private var themeButtons: [KeyboardColorTheme: NSButton] = [:]
    private var heatmapThemeButtons: [HeatmapColorTheme: NSButton] = [:]
    private var graphThemeButtons: [GraphColorTheme: NSButton] = [:]
    private weak var previewView: KeymapPreviewCard?
    private var shouldScrollToTopAfterLayout = false

    init(
        state: ProbeSettingsState,
        onIconSelected: @escaping (MenuBarIconChoice) -> Void,
        onSymbolicKeyLabelsChanged: @escaping (Bool) -> Void,
        onKeyboardColorThemeChanged: @escaping (KeyboardColorTheme) -> Void,
        onHeatmapColorThemeChanged: @escaping (HeatmapColorTheme) -> Void,
        onGraphColorThemeChanged: @escaping (GraphColorTheme) -> Void,
        onScaleChanged: @escaping (CGFloat) -> Void,
        onOpacityChanged: @escaping (CGFloat) -> Void,
        onHeatmapVisibilityChanged: @escaping (Bool) -> Void,
        onTypingStatsVisibilityChanged: @escaping (Bool) -> Void,
        onImportKeymap: @escaping () -> Void,
        onImportKeymapAt: @escaping (URL) -> Void
    ) {
        self.state = state
        self.onIconSelected = onIconSelected
        self.onSymbolicKeyLabelsChanged = onSymbolicKeyLabelsChanged
        self.onKeyboardColorThemeChanged = onKeyboardColorThemeChanged
        self.onHeatmapColorThemeChanged = onHeatmapColorThemeChanged
        self.onGraphColorThemeChanged = onGraphColorThemeChanged
        self.onScaleChanged = onScaleChanged
        self.onOpacityChanged = onOpacityChanged
        self.onHeatmapVisibilityChanged = onHeatmapVisibilityChanged
        self.onTypingStatsVisibilityChanged = onTypingStatsVisibilityChanged
        self.onImportKeymap = onImportKeymap
        self.onImportKeymapAt = onImportKeymapAt
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureScrollView()
        rebuildContent()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        scrollToTopIfNeeded()
    }

    func select(section: ProbeSettingsSection) {
        selectedSection = section
        rebuildContent()
    }

    func update(state: ProbeSettingsState) {
        self.state = state
        updateVisibleControls()
    }

    private func configureScrollView() {
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 16
        contentStack.edgeInsets = NSEdgeInsets(top: 30, left: 28, bottom: 30, right: 30)
        contentStack.setContentHuggingPriority(.required, for: .vertical)
        contentStack.setContentCompressionResistancePriority(.required, for: .vertical)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let documentView = SettingsDocumentView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(contentStack)
        scrollView.documentView = documentView

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            documentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor),
            contentStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: documentView.bottomAnchor)
        ])
    }

    private func rebuildContent() {
        for arrangedSubview in contentStack.arrangedSubviews {
            contentStack.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }
        glyphCheckbox = nil
        heatmapCheckbox = nil
        typingStatsCheckbox = nil
        scaleControl = nil
        opacityControl = nil
        iconButtons = [:]
        themeButtons = [:]
        heatmapThemeButtons = [:]
        graphThemeButtons = [:]
        previewView = nil

        contentStack.addArrangedSubview(pageHeader(title: selectedSection.title, symbolName: selectedSection.symbolName))

        switch selectedSection {
        case .display:
            buildDisplaySection()
        case .keyboard:
            buildKeyboardSection()
        case .menuBar:
            buildMenuBarSection()
        }
        updateVisibleControls()
        shouldScrollToTopAfterLayout = true
        scrollToTopIfNeeded()
    }

    private func scrollToTopIfNeeded() {
        guard shouldScrollToTopAfterLayout,
            let documentView = scrollView.documentView,
            scrollView.contentView.bounds.height > 0
        else {
            return
        }

        let documentBounds = documentView.bounds
        let targetY = documentBounds.minY
        scrollView.contentView.scroll(to: NSPoint(x: documentBounds.minX, y: targetY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        shouldScrollToTopAfterLayout = false
    }

    private func buildDisplaySection() {
        let card = SettingsCard()
        card.stack.addArrangedSubview(
            settingRow(
                title: "Keyboard labels",
                subtitle: "Use standard macOS symbols for keys such as Esc, Tab, Shift, Control, Backspace, and Return.",
                trailingView: checkbox(
                    title: "Use glyphs",
                    action: #selector(toggleSymbolicKeyLabels),
                    assign: { glyphCheckbox = $0 }
                )
            )
        )
        card.stack.addArrangedSubview(separator())
        card.stack.addArrangedSubview(
            settingRow(
                title: "Scale",
                subtitle: "Choose how large the floating keyboard HUD appears.",
                trailingView: segmentedControl(
                    labels: HUDScaleChoice.allCases.map(\.title),
                    action: #selector(selectScale),
                    assign: { scaleControl = $0 }
                ),
                trailingWidth: 184
            )
        )
        card.stack.addArrangedSubview(separator())
        card.stack.addArrangedSubview(
            settingRow(
                title: "Opacity",
                subtitle: "Set the transparency of the floating keyboard HUD.",
                trailingView: segmentedControl(
                    labels: HUDOpacityChoice.allCases.map(\.title),
                    action: #selector(selectOpacity),
                    assign: { opacityControl = $0 }
                ),
                trailingWidth: 184
            )
        )
        card.stack.addArrangedSubview(separator())
        card.stack.addArrangedSubview(
            settingRow(
                title: "Heatmap",
                subtitle: "Show all-time key frequency while keeping live key highlights active.",
                trailingView: checkbox(
                    title: "Show",
                    action: #selector(toggleHeatmap),
                    assign: { heatmapCheckbox = $0 }
                )
            )
        )
        card.stack.addArrangedSubview(separator())
        card.stack.addArrangedSubview(
            settingRow(
                title: "Typing graph",
                subtitle: "Display live strokes, words per minute, and backspace activity between the keyboard halves.",
                trailingView: checkbox(
                    title: "Show",
                    action: #selector(toggleTypingStats),
                    assign: { typingStatsCheckbox = $0 }
                )
            )
        )
        addFullWidth(card)
    }

    private func buildKeyboardSection() {
        let themeCard = SettingsCard()
        themeCard.stack.addArrangedSubview(sectionHeader("Keyboard Theme"))
        themeCard.stack.addArrangedSubview(
            leadingContainer(
                choiceGrid(
                    KeyboardColorTheme.allCases.chunked(into: 2).map { rowThemes in
                        rowThemes.map(themeChoiceView(for:))
                    }
                )
            )
        )

        themeCard.stack.addArrangedSubview(separator())
        themeCard.stack.addArrangedSubview(sectionHeader("Heatmap Theme"))
        themeCard.stack.addArrangedSubview(
            leadingContainer(
                choiceGrid(
                    HeatmapColorTheme.allCases.chunked(into: 2).map { rowThemes in
                        rowThemes.map(heatmapThemeChoiceView(for:))
                    }
                )
            )
        )

        themeCard.stack.addArrangedSubview(separator())
        themeCard.stack.addArrangedSubview(sectionHeader("Typing Graph Theme"))
        themeCard.stack.addArrangedSubview(
            leadingContainer(
                choiceGrid(
                    GraphColorTheme.allCases.chunked(into: 2).map { rowThemes in
                        rowThemes.map(graphThemeChoiceView(for:))
                    }
                )
            )
        )
        addFullWidth(themeCard)

        let preview = KeymapPreviewCard(
            state: state,
            onImportKeymap: onImportKeymap,
            onImportKeymapAt: onImportKeymapAt
        )
        previewView = preview
        addFullWidth(preview)
    }

    private func buildMenuBarSection() {
        let card = SettingsCard()
        card.stack.addArrangedSubview(sectionHeader("Status Item"))
        for choice in MenuBarIconChoice.allCases {
            card.stack.addArrangedSubview(iconRow(for: choice))
            if choice != MenuBarIconChoice.allCases.last! {
                card.stack.addArrangedSubview(separator())
            }
        }
        addFullWidth(card)
    }

    private func pageHeader(title: String, symbolName: String) -> NSView {
        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        imageView.contentTintColor = .labelColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 30),
            imageView.heightAnchor.constraint(equalToConstant: 30)
        ])

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .labelColor

        let stack = NSStackView(views: [imageView, titleLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        return stack
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .labelColor
        return label
    }

    private func sectionHeader(_ text: String) -> NSView {
        let label = sectionLabel(text)
        label.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor)
        ])
        return container
    }

    private func leadingContainer(_ view: NSView) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            view.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor)
        ])
        return container
    }

    private func choiceGrid(_ rows: [[NSView]]) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.distribution = .fill
        stack.spacing = 12
        stack.setContentHuggingPriority(.required, for: .horizontal)
        stack.setContentCompressionResistancePriority(.required, for: .horizontal)
        stack.translatesAutoresizingMaskIntoConstraints = false

        for views in rows {
            let row = NSStackView(views: views)
            row.orientation = .horizontal
            row.alignment = .top
            row.distribution = .fill
            row.spacing = 24
            row.setContentHuggingPriority(.required, for: .horizontal)
            row.setContentCompressionResistancePriority(.required, for: .horizontal)
            row.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(row)
        }

        return stack
    }

    private func settingRow(
        title: String,
        subtitle: String,
        trailingView: NSView,
        trailingWidth: CGFloat = 118
    ) -> NSView {
        let titleLabel = NSTextField(wrappingLabelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        let subtitleLabel = NSTextField(wrappingLabelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let labels = NSStackView(views: [titleLabel, subtitleLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 3
        labels.translatesAutoresizingMaskIntoConstraints = false

        let trailingContainer = NSView()
        trailingContainer.translatesAutoresizingMaskIntoConstraints = false
        trailingView.translatesAutoresizingMaskIntoConstraints = false
        trailingContainer.addSubview(trailingView)

        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(labels)
        row.addSubview(trailingContainer)
        row.setContentHuggingPriority(.required, for: .vertical)
        row.setContentCompressionResistancePriority(.required, for: .vertical)
        labels.setContentHuggingPriority(.defaultLow, for: .horizontal)
        trailingContainer.setContentHuggingPriority(.required, for: .horizontal)
        trailingContainer.setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            labels.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            labels.topAnchor.constraint(equalTo: row.topAnchor),
            labels.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            labels.trailingAnchor.constraint(lessThanOrEqualTo: trailingContainer.leadingAnchor, constant: -18),
            trailingContainer.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            trailingContainer.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            trailingContainer.widthAnchor.constraint(equalToConstant: trailingWidth),
            trailingView.trailingAnchor.constraint(equalTo: trailingContainer.trailingAnchor),
            trailingView.centerYAnchor.constraint(equalTo: trailingContainer.centerYAnchor),
            trailingView.leadingAnchor.constraint(greaterThanOrEqualTo: trailingContainer.leadingAnchor),
            trailingView.topAnchor.constraint(greaterThanOrEqualTo: trailingContainer.topAnchor),
            trailingView.bottomAnchor.constraint(lessThanOrEqualTo: trailingContainer.bottomAnchor)
        ])
        return row
    }

    private func checkbox(title: String, action: Selector, assign: (NSButton) -> Void) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: self, action: action)
        button.font = .systemFont(ofSize: 13, weight: .medium)
        button.lineBreakMode = .byClipping
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        assign(button)
        return button
    }

    private func segmentedControl(
        labels: [String],
        action: Selector,
        assign: (NSSegmentedControl) -> Void
    ) -> NSSegmentedControl {
        let control = NSSegmentedControl(labels: labels, trackingMode: .selectOne, target: self, action: action)
        control.segmentStyle = .rounded
        control.font = .systemFont(ofSize: 12, weight: .medium)
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)
        assign(control)
        return control
    }

    private func themeChoiceView(for theme: KeyboardColorTheme) -> NSView {
        let swatch = ThemeSwatchView(theme: theme)
        swatch.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            swatch.widthAnchor.constraint(equalToConstant: 62),
            swatch.heightAnchor.constraint(equalToConstant: 42)
        ])

        let button = NSButton(radioButtonWithTitle: theme.title, target: self, action: #selector(selectTheme))
        button.identifier = NSUserInterfaceItemIdentifier(theme.rawValue)
        button.font = .systemFont(ofSize: 13, weight: .semibold)
        themeButtons[theme] = button

        let subtitle = NSTextField(wrappingLabelWithString: theme.subtitle)
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 2

        let text = NSStackView(views: [button, subtitle])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 2

        let row = NSStackView(views: [swatch, text])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 250).isActive = true
        return row
    }

    private func heatmapThemeChoiceView(for theme: HeatmapColorTheme) -> NSView {
        let swatch = HeatmapThemeSwatchView(theme: theme)
        swatch.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            swatch.widthAnchor.constraint(equalToConstant: 62),
            swatch.heightAnchor.constraint(equalToConstant: 42)
        ])

        let button = NSButton(radioButtonWithTitle: theme.title, target: self, action: #selector(selectHeatmapTheme))
        button.identifier = NSUserInterfaceItemIdentifier(theme.rawValue)
        button.font = .systemFont(ofSize: 13, weight: .semibold)
        heatmapThemeButtons[theme] = button

        let subtitle = NSTextField(wrappingLabelWithString: theme.subtitle)
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 2

        let text = NSStackView(views: [button, subtitle])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 2

        let row = NSStackView(views: [swatch, text])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 250).isActive = true
        return row
    }

    private func graphThemeChoiceView(for theme: GraphColorTheme) -> NSView {
        let swatch = GraphThemeSwatchView(theme: theme)
        swatch.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            swatch.widthAnchor.constraint(equalToConstant: 62),
            swatch.heightAnchor.constraint(equalToConstant: 42)
        ])

        let button = NSButton(radioButtonWithTitle: theme.title, target: self, action: #selector(selectGraphTheme))
        button.identifier = NSUserInterfaceItemIdentifier(theme.rawValue)
        button.font = .systemFont(ofSize: 13, weight: .semibold)
        graphThemeButtons[theme] = button

        let subtitle = NSTextField(wrappingLabelWithString: theme.subtitle)
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 2

        let text = NSStackView(views: [button, subtitle])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 2

        let row = NSStackView(views: [swatch, text])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 250).isActive = true
        return row
    }

    private func iconRow(for choice: MenuBarIconChoice) -> NSView {
        let imageView = NSImageView()
        imageView.image = choice.image(pointSize: 30)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.contentTintColor = .labelColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 38),
            imageView.heightAnchor.constraint(equalToConstant: 38)
        ])

        let button = NSButton(radioButtonWithTitle: choice.title, target: self, action: #selector(selectIcon))
        button.identifier = NSUserInterfaceItemIdentifier(choice.rawValue)
        button.font = .systemFont(ofSize: 13, weight: .semibold)
        iconButtons[choice] = button

        let subtitle = NSTextField(labelWithString: choice.subtitle)
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor

        let text = NSStackView(views: [button, subtitle])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 2

        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(imageView)
        row.addSubview(text)
        text.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 42),
            imageView.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            imageView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            imageView.topAnchor.constraint(greaterThanOrEqualTo: row.topAnchor),
            imageView.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor),
            text.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 14),
            text.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            text.topAnchor.constraint(greaterThanOrEqualTo: row.topAnchor),
            text.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor),
            text.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor)
        ])
        return row
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func addFullWidth(_ view: NSView) {
        contentStack.addArrangedSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -58).isActive = true
    }

    private func updateVisibleControls() {
        glyphCheckbox?.state = state.usesSymbolicKeyLabels ? .on : .off
        heatmapCheckbox?.state = state.showsHeatmap ? .on : .off
        typingStatsCheckbox?.state = state.showsTypingStats ? .on : .off
        scaleControl?.selectedSegment = HUDScaleChoice.allCases.firstIndex(of: HUDScaleChoice.nearest(to: state.scale)) ?? 1
        opacityControl?.selectedSegment = HUDOpacityChoice.allCases.firstIndex(of: HUDOpacityChoice.nearest(to: state.opacity)) ?? 2

        for (choice, button) in iconButtons {
            button.state = choice == state.selectedIcon ? .on : .off
        }
        for (theme, button) in themeButtons {
            button.state = theme == state.keyboardColorTheme ? .on : .off
        }
        for (theme, button) in heatmapThemeButtons {
            button.state = theme == state.heatmapColorTheme ? .on : .off
        }
        for (theme, button) in graphThemeButtons {
            button.state = theme == state.graphColorTheme ? .on : .off
        }
        previewView?.update(state: state)
    }

    @objc private func toggleSymbolicKeyLabels(_ sender: NSButton) {
        state.usesSymbolicKeyLabels = sender.state == .on
        updateVisibleControls()
        onSymbolicKeyLabelsChanged(state.usesSymbolicKeyLabels)
    }

    @objc private func toggleHeatmap(_ sender: NSButton) {
        state.showsHeatmap = sender.state == .on
        updateVisibleControls()
        onHeatmapVisibilityChanged(state.showsHeatmap)
    }

    @objc private func toggleTypingStats(_ sender: NSButton) {
        state.showsTypingStats = sender.state == .on
        updateVisibleControls()
        onTypingStatsVisibilityChanged(state.showsTypingStats)
    }

    @objc private func selectScale(_ sender: NSSegmentedControl) {
        guard HUDScaleChoice.allCases.indices.contains(sender.selectedSegment) else { return }
        let choice = HUDScaleChoice.allCases[sender.selectedSegment]
        state.scale = choice.value
        updateVisibleControls()
        onScaleChanged(choice.value)
    }

    @objc private func selectOpacity(_ sender: NSSegmentedControl) {
        guard HUDOpacityChoice.allCases.indices.contains(sender.selectedSegment) else { return }
        let choice = HUDOpacityChoice.allCases[sender.selectedSegment]
        state.opacity = choice.value
        updateVisibleControls()
        onOpacityChanged(choice.value)
    }

    @objc private func selectTheme(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue,
            let theme = KeyboardColorTheme(rawValue: rawValue)
        else {
            return
        }

        state.keyboardColorTheme = theme
        updateVisibleControls()
        onKeyboardColorThemeChanged(theme)
    }

    @objc private func selectHeatmapTheme(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue,
            let theme = HeatmapColorTheme(rawValue: rawValue)
        else {
            return
        }

        state.heatmapColorTheme = theme
        updateVisibleControls()
        onHeatmapColorThemeChanged(theme)
    }

    @objc private func selectGraphTheme(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue,
            let theme = GraphColorTheme(rawValue: rawValue)
        else {
            return
        }

        state.graphColorTheme = theme
        updateVisibleControls()
        onGraphColorThemeChanged(theme)
    }

    @objc private func selectIcon(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue,
            let choice = MenuBarIconChoice(rawValue: rawValue)
        else {
            return
        }

        state.selectedIcon = choice
        updateVisibleControls()
        onIconSelected(choice)
    }
}

private final class SettingsDocumentView: NSView {
    override var isFlipped: Bool {
        true
    }
}

private class SettingsCard: NSView {
    let stack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.74).cgColor
        layer?.cornerRadius = 12
        layer?.cornerCurve = .continuous

        stack.orientation = .vertical
        stack.alignment = .width
        stack.distribution = .fill
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class ThemeSwatchView: NSView {
    private let theme: KeyboardColorTheme

    init(theme: KeyboardColorTheme) {
        self.theme = theme
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        theme.keyFill.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()

        let pressedRect = NSRect(x: bounds.minX + 7, y: bounds.midY - 5, width: 18, height: 18)
        theme.pressedFill.setFill()
        NSBezierPath(roundedRect: pressedRect, xRadius: 4, yRadius: 4).fill()

        let badgeRect = NSRect(x: pressedRect.maxX + 5, y: pressedRect.minY, width: 18, height: 18)
        theme.layerBadgeFill.setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: 4, yRadius: 4).fill()

        theme.keyStroke.setStroke()
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        border.lineWidth = 1
        border.stroke()
    }
}

private final class HeatmapThemeSwatchView: NSView {
    private let theme: HeatmapColorTheme

    init(theme: HeatmapColorTheme) {
        self.theme = theme
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.06, green: 0.08, blue: 0.12, alpha: 0.70).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()

        let width = (bounds.width - 22) / 4
        for index in 0..<4 {
            let heat = CGFloat(index + 1) / 4
            let rect = NSRect(
                x: bounds.minX + 7 + CGFloat(index) * (width + 3),
                y: bounds.midY - 8,
                width: width,
                height: 16
            )
            theme.fill(heat: heat).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
        }

        NSColor.white.withAlphaComponent(0.34).setStroke()
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        border.lineWidth = 1
        border.stroke()
    }
}

private final class GraphThemeSwatchView: NSView {
    private let theme: GraphColorTheme

    init(theme: GraphColorTheme) {
        self.theme = theme
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.06, green: 0.08, blue: 0.12, alpha: 0.70).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()

        let heights: [CGFloat] = [9, 17, 12, 24]
        let barWidth: CGFloat = 7
        for (index, height) in heights.enumerated() {
            let rect = NSRect(
                x: bounds.minX + 10 + CGFloat(index) * 10,
                y: bounds.minY + 9,
                width: barWidth,
                height: height
            )
            theme.barFill.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2).fill()
        }

        let markerRect = NSRect(x: bounds.maxX - 15, y: bounds.minY + 9, width: 4, height: 24)
        theme.backspaceFill.setFill()
        NSBezierPath(roundedRect: markerRect, xRadius: 2, yRadius: 2).fill()

        NSColor.white.withAlphaComponent(0.34).setStroke()
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        border.lineWidth = 1
        border.stroke()
    }
}

private final class KeymapPreviewCard: SettingsCard {
    private var state: ProbeSettingsState
    private let onImportKeymap: () -> Void
    private let onImportKeymapAt: (URL) -> Void
    private let titleLabel = NSTextField(labelWithString: "Parsed Keymap")
    private let summaryLabel = NSTextField(labelWithString: "")
    private let layerPopup = NSPopUpButton()
    private let hudView = KeyboardHUDView(frame: .zero)

    init(state: ProbeSettingsState, onImportKeymap: @escaping () -> Void, onImportKeymapAt: @escaping (URL) -> Void) {
        self.state = state
        self.onImportKeymap = onImportKeymap
        self.onImportKeymapAt = onImportKeymapAt
        super.init(frame: .zero)
        buildView()
        update(state: state)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(state: ProbeSettingsState) {
        self.state = state
        titleLabel.stringValue = state.hasUsableKeymap ? "Parsed Keymap" : "Keymap Needed"
        summaryLabel.stringValue =
            state.hasUsableKeymap
            ? "\(state.keymap.layers.count) layers, \(state.keymap.physicalKeys.count) physical keys"
            : "Import a keymap.c file or ZSA source zip to preview labels here."

        rebuildLayerPopup()
        hudView.keymap = state.keymap
        hudView.activeLayer = selectedLayer
        hudView.usesSymbolicKeyLabels = state.usesSymbolicKeyLabels
        hudView.colorTheme = state.keyboardColorTheme
        hudView.heatmapColorTheme = state.heatmapColorTheme
        hudView.graphColorTheme = state.graphColorTheme
        hudView.heatmap = Self.previewHeatmap
        hudView.showsHeatmap = true
        hudView.showsTypingStats = true
        hudView.typingMetrics = Self.previewMetrics
        hudView.needsDisplay = true
    }

    private func buildView() {
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        summaryLabel.font = .systemFont(ofSize: 12)
        summaryLabel.textColor = .secondaryLabelColor

        let importButton = NSButton(title: "Import Keymap...", target: self, action: #selector(importKeymap))
        importButton.bezelStyle = .rounded

        layerPopup.target = self
        layerPopup.action = #selector(selectLayer)

        let headerText = NSStackView(views: [titleLabel, summaryLabel])
        headerText.orientation = .vertical
        headerText.alignment = .leading
        headerText.spacing = 3

        let controls = NSStackView(views: [layerPopup, importButton])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 8

        let header = NSStackView(views: [headerText, controls])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 16
        headerText.setContentHuggingPriority(.defaultLow, for: .horizontal)
        controls.setContentHuggingPriority(.required, for: .horizontal)

        let previewContainer = NSView()
        previewContainer.wantsLayer = true
        previewContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.16).cgColor
        previewContainer.layer?.cornerRadius = 10
        previewContainer.layer?.cornerCurve = .continuous
        previewContainer.layer?.masksToBounds = true
        previewContainer.translatesAutoresizingMaskIntoConstraints = false

        hudView.translatesAutoresizingMaskIntoConstraints = false
        hudView.designCanvasSize = NSSize(width: 900, height: 360)
        hudView.onKeymapDropped = { [weak self] url in
            guard let self else { return }
            self.onImportKeymapAt(url)
        }
        previewContainer.addSubview(hudView)

        stack.addArrangedSubview(header)
        stack.addArrangedSubview(previewContainer)

        NSLayoutConstraint.activate([
            previewContainer.heightAnchor.constraint(equalToConstant: 260),
            hudView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 10),
            hudView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -10),
            hudView.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 10),
            hudView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -10)
        ])
    }

    private func rebuildLayerPopup() {
        let layerCount = max(1, state.keymap.layers.count)
        let currentTitles = layerPopup.itemArray.map(\.title)
        let nextTitles = (0..<layerCount).map { "Layer \($0)" }
        guard currentTitles != nextTitles else {
            layerPopup.selectItem(at: min(selectedLayer, layerCount - 1))
            layerPopup.isEnabled = state.hasUsableKeymap
            return
        }

        layerPopup.removeAllItems()
        layerPopup.addItems(withTitles: nextTitles)
        layerPopup.selectItem(at: min(state.activeLayer, layerCount - 1))
        layerPopup.isEnabled = state.hasUsableKeymap
    }

    private var selectedLayer: Int {
        max(0, layerPopup.indexOfSelectedItem)
    }

    @objc private func selectLayer() {
        hudView.activeLayer = selectedLayer
        hudView.needsDisplay = true
    }

    @objc private func importKeymap() {
        onImportKeymap()
    }

    private static let previewHeatmap = HeatmapSnapshot(
        allTimeCounts: [
            HeatmapSnapshot.key(layer: 0, keyID: 24): 8,
            HeatmapSnapshot.key(layer: 0, keyID: 25): 13,
            HeatmapSnapshot.key(layer: 0, keyID: 26): 6,
            HeatmapSnapshot.key(layer: 0, keyID: 49): 16
        ]
    )

    private static let previewMetrics = TypingMetricsSnapshot(
        strokesPerSecond: 2.1,
        strokesPerMinute: 126,
        wordsPerMinute: 52,
        backspacesPerMinute: 5,
        buckets: (0..<TypingMetricsStore.bucketCount).map {
            if $0 % 5 == 0 || $0 > 20 {
                return TypingMetricsBucket(strokes: 0, backspaces: 0, isFuture: $0 > 20)
            }
            return TypingMetricsBucket(strokes: ($0 % 6) + 1, backspaces: $0 % 9 == 0 ? 1 : 0)
        },
        scrollProgress: 0.35
    )
}

extension Array {
    fileprivate func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
