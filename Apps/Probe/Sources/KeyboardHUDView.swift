import AppKit
import ProbeCore

final class KeyboardHUDView: NSView {
    var keymap = LayeredKeymap.voyagerDefault(layers: [])
    var activeLayer = 0
    var shiftActive = false
    var pressedKeys = Set<Int>()
    var heatmap = HeatmapSnapshot()
    var showsHeatmap = true
    var showsTypingStats = false
    var typingMetrics = TypingMetricsSnapshot.empty
    var onKeymapDropped: ((URL) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureDragAndDrop()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureDragAndDrop()
    }

    override var isOpaque: Bool { false }
    override var mouseDownCanMoveWindow: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.clear(bounds)
        drawKeyboard(in: context)
        if showsTypingStats {
            drawTypingStats()
        }
        drawLayerBadge()
    }

    private func drawKeyboard(in context: CGContext) {
        let unitWidth = bounds.width / 17.2
        let unitHeight = bounds.height / 6.2
        let unit = min(unitWidth, unitHeight)
        let origin = CGPoint(
            x: bounds.midX - unit * 8,
            y: bounds.midY + unit * 2.45
        )
        let maxHeat = max(1, keymap.maxHeat(in: heatmap, layer: activeLayer))

        for key in keymap.physicalKeys {
            let rect = NSRect(
                x: origin.x + key.x * unit,
                y: origin.y - (key.y + key.height) * unit,
                width: key.width * unit,
                height: key.height * unit
            )
            draw(key: key, rect: rect, unit: unit, maxHeat: maxHeat, context: context)
        }
    }

    private func draw(key: PhysicalKey, rect: NSRect, unit: CGFloat, maxHeat: Int, context: CGContext) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: CGFloat(key.rotation * .pi / 180))
        context.translateBy(x: -center.x, y: -center.y)

        let isPressed = pressedKeys.contains(key.id)
        let count = heatmap.allTimeCount(layer: activeLayer, keyID: key.id)
        let heat = showsHeatmap ? CGFloat(count) / CGFloat(maxHeat) : 0
        let fill = fillColor(pressed: isPressed, heat: heat)
        let stroke = isPressed ? NSColor(calibratedRed: 0.64, green: 0.82, blue: 1.0, alpha: 0.95) : NSColor.white.withAlphaComponent(0.55)

        let path = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
        fill.setFill()
        path.fill()
        stroke.setStroke()
        path.lineWidth = isPressed ? 2.5 : 1.5
        path.stroke()

        let label = keymap.resolvedLabel(forKeyID: key.id, onLayer: activeLayer).displayLabel(shifted: shiftActive)
        draw(label: label, in: rect, unit: unit, pressed: isPressed)

        context.restoreGState()
    }

    private func fillColor(pressed: Bool, heat: CGFloat) -> NSColor {
        if pressed {
            return NSColor(calibratedRed: 0.08, green: 0.42, blue: 1.0, alpha: 0.88)
        }
        if heat > 0 {
            let clamped = min(1, max(0.12, heat))
            return NSColor(
                calibratedRed: 0.95,
                green: 0.24 + 0.22 * (1 - clamped),
                blue: 0.18,
                alpha: 0.20 + 0.46 * clamped
            )
        }
        return NSColor(calibratedRed: 0.06, green: 0.08, blue: 0.12, alpha: 0.58)
    }

    private func draw(label: KeyLabel, in rect: NSRect, unit: CGFloat, pressed: Bool) {
        guard !label.primary.isEmpty else { return }

        let primaryBaseSize = max(10, min(20, unit * 0.26))
        let secondarySize = max(7, min(10, unit * 0.13))
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byClipping

        let primaryRect = rect.insetBy(dx: 5, dy: rect.height * 0.30)
        let primarySize = fittingFontSize(
            for: label.primary,
            baseSize: primaryBaseSize,
            minimumSize: 7,
            weight: pressed ? .bold : .semibold,
            in: primaryRect
        )
        let primaryAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: primarySize, weight: pressed ? .bold : .semibold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]

        label.primary.draw(with: primaryRect, options: [.usesLineFragmentOrigin], attributes: primaryAttributes)

        guard let secondary = label.secondary, !secondary.isEmpty else { return }
        let secondaryAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: secondarySize, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.72),
            .paragraphStyle: paragraph
        ]
        let secondaryRect = NSRect(
            x: rect.minX + 5,
            y: rect.minY + 5,
            width: rect.width - 10,
            height: secondarySize + 3
        )
        secondary.draw(with: secondaryRect, options: [.usesLineFragmentOrigin], attributes: secondaryAttributes)
    }

    private func fittingFontSize(
        for text: String,
        baseSize: CGFloat,
        minimumSize: CGFloat,
        weight: NSFont.Weight,
        in rect: NSRect
    ) -> CGFloat {
        var size = baseSize
        while size > minimumSize {
            let font = NSFont.monospacedSystemFont(ofSize: size, weight: weight)
            let measured = text.size(withAttributes: [.font: font])
            if measured.width <= rect.width && measured.height <= rect.height {
                return size
            }
            size -= 0.5
        }
        return minimumSize
    }

    private func drawLayerBadge() {
        let text = "L\(activeLayer)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attrs)
        let bottomInset = min(16, max(8, bounds.height * 0.035))
        let rect = NSRect(
            x: bounds.midX - (size.width + 14) / 2,
            y: bounds.minY + bottomInset,
            width: size.width + 14,
            height: size.height + 8
        )
        let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.22, alpha: 0.74).setFill()
        path.fill()
        text.draw(at: CGPoint(x: rect.minX + 7, y: rect.minY + 4), withAttributes: attrs)
    }

    private func drawTypingStats() {
        let unitWidth = bounds.width / 17.2
        let unitHeight = bounds.height / 6.2
        let unit = min(unitWidth, unitHeight)
        let width = min(88, max(74, unit * 1.42))
        let height = min(bounds.height * 0.72, max(212, unit * 4.2))
        let rect = NSRect(
            x: bounds.midX - width / 2,
            y: bounds.midY - height / 2,
            width: width,
            height: height
        )

        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.10, alpha: 0.70).setFill()
        path.fill()

        drawStatsText(in: rect)
        drawStatsGraph(in: statsGraphRect(in: rect))
    }

    private func drawStatsText(in rect: NSRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byClipping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.90),
            .paragraphStyle: paragraph
        ]
        let rows = [
            String(format: "%.1f/s", typingMetrics.strokesPerSecond),
            "\(typingMetrics.strokesPerMinute)/m",
            String(format: "%.0f WPM", typingMetrics.wordsPerMinute),
            String(format: "BK %02d/m", typingMetrics.backspacesPerMinute)
        ]
        for (index, row) in rows.enumerated() {
            let rowRect = NSRect(
                x: rect.minX + 6,
                y: rect.maxY - 22 - CGFloat(index) * 23,
                width: rect.width - 12,
                height: 14
            )
            row.draw(with: rowRect, options: [.usesLineFragmentOrigin], attributes: attrs)
        }
    }

    private func drawStatsGraph(in rect: NSRect) {
        let maxCount = max(1, typingMetrics.buckets.map(\.strokes).max() ?? 0)
        let bucketCount = max(1, typingMetrics.buckets.count)
        let gap: CGFloat = 1
        let barHeight = max(2, (rect.height - gap * CGFloat(bucketCount - 1)) / CGFloat(bucketCount))
        let scrollProgress = CGFloat(min(1, max(0, typingMetrics.scrollProgress)))
        let slotHeight = barHeight + gap

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()
        defer { NSGraphicsContext.restoreGraphicsState() }

        for index in 0...bucketCount {
            let bucket =
                index < bucketCount
                ? typingMetrics.buckets[index]
                : TypingMetricsBucket(strokes: 0, backspaces: 0, isFuture: true)
            let y = rect.minY + (CGFloat(index) - scrollProgress) * slotHeight
            guard y + barHeight >= rect.minY, y <= rect.maxY else { continue }
            if bucket.strokes == 0 {
                drawEmptyStatsBucket(in: rect, y: y, height: barHeight, isFuture: bucket.isFuture)
                continue
            }

            let width = max(6, rect.width * CGFloat(bucket.strokes) / CGFloat(maxCount))
            let barRect = NSRect(
                x: rect.midX - width / 2,
                y: y,
                width: width,
                height: barHeight
            )
            let path = NSBezierPath(roundedRect: barRect, xRadius: 1.2, yRadius: 1.2)
            NSColor(calibratedRed: 0.24, green: 0.67, blue: 1.0, alpha: 0.74).setFill()
            path.fill()

            guard bucket.backspaces > 0 else { continue }
            let markerRect = NSRect(x: rect.maxX - 3, y: barRect.minY, width: 3, height: barHeight)
            NSColor(calibratedRed: 1.0, green: 0.35, blue: 0.30, alpha: 0.88).setFill()
            NSBezierPath(roundedRect: markerRect, xRadius: 1, yRadius: 1).fill()
        }
    }

    private func drawEmptyStatsBucket(in rect: NSRect, y: CGFloat, height: CGFloat, isFuture: Bool) {
        let diameter = min(3.5, max(2.2, height * 0.72))
        let dotRect = NSRect(
            x: rect.midX - diameter / 2,
            y: y + (height - diameter) / 2,
            width: diameter,
            height: diameter
        )
        NSColor(calibratedRed: 0.24, green: 0.67, blue: 1.0, alpha: isFuture ? 0.16 : 0.24).setFill()
        NSBezierPath(ovalIn: dotRect).fill()
    }

    private func statsGraphRect(in rect: NSRect) -> NSRect {
        NSRect(
            x: rect.minX + 11,
            y: rect.minY + 12,
            width: rect.width - 22,
            height: max(52, rect.height - 116)
        )
    }

    private func configureDragAndDrop() {
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        importURL(from: sender) == nil ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = importURL(from: sender) else { return false }
        onKeymapDropped?(url)
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
