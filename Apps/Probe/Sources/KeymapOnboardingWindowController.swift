import AppKit

@MainActor
final class KeymapOnboardingWindowController: NSWindowController {
    init(onImport: @escaping (URL) -> Void, onChoose: @escaping () -> Void, onSkip: @escaping () -> Void) {
        let contentView = KeymapOnboardingView(onImport: onImport, onChoose: onChoose, onSkip: onSkip)
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = "Probe Keymap"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.contentView = contentView
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class KeymapOnboardingView: NSView {
    private let onChoose: () -> Void
    private let onSkip: () -> Void
    private let dropZone: KeymapDropZoneView

    init(onImport: @escaping (URL) -> Void, onChoose: @escaping () -> Void, onSkip: @escaping () -> Void) {
        self.onChoose = onChoose
        self.onSkip = onSkip
        self.dropZone = KeymapDropZoneView(onImport: onImport)
        super.init(frame: NSRect(x: 0, y: 0, width: 420, height: 260))
        buildView()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func buildView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let title = NSTextField(labelWithString: "Import your Voyager keymap")
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.alignment = .center

        let subtitle = NSTextField(labelWithString: "Drop keymap.c or a QMK source ZIP.")
        subtitle.font = .systemFont(ofSize: 13, weight: .regular)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center

        let chooseButton = NSButton(title: "Choose File...", target: self, action: #selector(chooseFile))
        chooseButton.bezelStyle = .rounded

        let skipButton = NSButton(title: "Skip", target: self, action: #selector(skip))
        skipButton.bezelStyle = .rounded

        let buttonRow = NSStackView(views: [chooseButton, skipButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8

        let stack = NSStackView(views: [title, subtitle, dropZone, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            dropZone.widthAnchor.constraint(equalTo: stack.widthAnchor),
            dropZone.heightAnchor.constraint(equalToConstant: 106)
        ])
    }

    @objc private func chooseFile() {
        onChoose()
    }

    @objc private func skip() {
        onSkip()
    }
}

private final class KeymapDropZoneView: NSView {
    private let onImport: (URL) -> Void
    private var isHighlighted = false {
        didSet { needsDisplay = true }
    }

    init(onImport: @escaping (URL) -> Void) {
        self.onImport = onImport
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        registerForDraggedTypes([.fileURL])

        let label = NSTextField(labelWithString: "Drop keymap here")
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        (isHighlighted ? NSColor.controlAccentColor.withAlphaComponent(0.10) : NSColor.controlBackgroundColor)
            .setFill()
        path.fill()

        let border = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10)
        border.lineWidth = 1.4
        border.setLineDash([6, 4], count: 2, phase: 0)
        (isHighlighted ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        border.stroke()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard importURL(from: sender) != nil else { return [] }
        isHighlighted = true
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isHighlighted = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        importURL(from: sender) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isHighlighted = false
        guard let url = importURL(from: sender) else { return false }
        onImport(url)
        return true
    }

    private func importURL(from sender: NSDraggingInfo) -> URL? {
        guard
            let item = sender.draggingPasteboard.pasteboardItems?.first,
            let path = item.string(forType: .fileURL),
            let url = URL(string: path)
        else {
            return nil
        }
        return KeymapImportSupport.supports(url) ? url : nil
    }
}
