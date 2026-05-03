import AppKit
import ProbeCore

enum KeyboardColorTheme: String, CaseIterable {
    case probe
    case graphite
    case aurora
    case mono

    static let defaultTheme = KeyboardColorTheme.probe

    var title: String {
        switch self {
        case .probe:
            "Probe"
        case .graphite:
            "Graphite"
        case .aurora:
            "Aurora"
        case .mono:
            "Mono"
        }
    }

    var subtitle: String {
        switch self {
        case .probe:
            "Deep glass with blue live keys"
        case .graphite:
            "Quiet system gray and aqua"
        case .aurora:
            "Violet keys with magenta highlights"
        case .mono:
            "High-contrast black and white"
        }
    }

    var keyFill: NSColor {
        switch self {
        case .probe:
            NSColor(calibratedRed: 0.06, green: 0.08, blue: 0.12, alpha: 0.58)
        case .graphite:
            NSColor(calibratedWhite: 0.10, alpha: 0.62)
        case .aurora:
            NSColor(calibratedRed: 0.08, green: 0.05, blue: 0.16, alpha: 0.62)
        case .mono:
            NSColor(calibratedWhite: 0.02, alpha: 0.72)
        }
    }

    var keyStroke: NSColor {
        switch self {
        case .probe, .graphite, .aurora:
            NSColor.white.withAlphaComponent(0.55)
        case .mono:
            NSColor.white.withAlphaComponent(0.72)
        }
    }

    var pressedFill: NSColor {
        switch self {
        case .probe:
            NSColor(calibratedRed: 0.08, green: 0.42, blue: 1.0, alpha: 0.88)
        case .graphite:
            NSColor(calibratedRed: 0.05, green: 0.55, blue: 0.72, alpha: 0.88)
        case .aurora:
            NSColor(calibratedRed: 0.72, green: 0.22, blue: 0.95, alpha: 0.88)
        case .mono:
            NSColor(calibratedWhite: 0.92, alpha: 0.88)
        }
    }

    var pressedStroke: NSColor {
        switch self {
        case .probe:
            NSColor(calibratedRed: 0.64, green: 0.82, blue: 1.0, alpha: 0.95)
        case .graphite:
            NSColor(calibratedRed: 0.58, green: 0.90, blue: 1.0, alpha: 0.95)
        case .aurora:
            NSColor(calibratedRed: 0.94, green: 0.72, blue: 1.0, alpha: 0.95)
        case .mono:
            NSColor.white.withAlphaComponent(0.96)
        }
    }

    var labelColor: NSColor {
        switch self {
        case .mono:
            NSColor.white
        default:
            NSColor.white
        }
    }

    var pressedLabelColor: NSColor {
        switch self {
        case .mono:
            NSColor.black
        default:
            NSColor.white
        }
    }

    var secondaryLabelColor: NSColor {
        switch self {
        case .mono:
            NSColor.white.withAlphaComponent(0.78)
        default:
            NSColor.white.withAlphaComponent(0.72)
        }
    }

    var layerBadgeFill: NSColor {
        switch self {
        case .probe:
            NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.22, alpha: 0.74)
        case .graphite:
            NSColor(calibratedWhite: 0.16, alpha: 0.78)
        case .aurora:
            NSColor(calibratedRed: 0.16, green: 0.09, blue: 0.24, alpha: 0.78)
        case .mono:
            NSColor(calibratedWhite: 0.02, alpha: 0.80)
        }
    }

    var statsFill: NSColor {
        switch self {
        case .probe:
            NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.10, alpha: 0.70)
        case .graphite:
            NSColor(calibratedWhite: 0.10, alpha: 0.72)
        case .aurora:
            NSColor(calibratedRed: 0.07, green: 0.04, blue: 0.13, alpha: 0.72)
        case .mono:
            NSColor(calibratedWhite: 0.02, alpha: 0.76)
        }
    }

    var graphFill: NSColor {
        switch self {
        case .probe:
            NSColor(calibratedRed: 0.24, green: 0.67, blue: 1.0, alpha: 0.74)
        case .graphite:
            NSColor(calibratedRed: 0.30, green: 0.84, blue: 0.96, alpha: 0.74)
        case .aurora:
            NSColor(calibratedRed: 0.78, green: 0.36, blue: 1.0, alpha: 0.74)
        case .mono:
            NSColor.white.withAlphaComponent(0.74)
        }
    }

    var backspaceFill: NSColor {
        switch self {
        case .probe:
            NSColor(calibratedRed: 1.0, green: 0.35, blue: 0.30, alpha: 0.88)
        case .graphite:
            NSColor(calibratedRed: 1.0, green: 0.50, blue: 0.34, alpha: 0.88)
        case .aurora:
            NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.64, alpha: 0.88)
        case .mono:
            NSColor.white.withAlphaComponent(0.88)
        }
    }

    func heatFill(heat: CGFloat) -> NSColor {
        let clamped = min(1, max(0.12, heat))
        switch self {
        case .probe:
            return NSColor(
                calibratedRed: 0.95,
                green: 0.24 + 0.22 * (1 - clamped),
                blue: 0.18,
                alpha: 0.20 + 0.46 * clamped
            )
        case .graphite:
            return NSColor(
                calibratedRed: 0.20 + 0.22 * clamped,
                green: 0.72 + 0.12 * clamped,
                blue: 0.82,
                alpha: 0.18 + 0.44 * clamped
            )
        case .aurora:
            return NSColor(
                calibratedRed: 0.94,
                green: 0.24 + 0.16 * (1 - clamped),
                blue: 0.76 + 0.10 * clamped,
                alpha: 0.20 + 0.46 * clamped
            )
        case .mono:
            return NSColor(calibratedWhite: 0.82, alpha: 0.16 + 0.46 * clamped)
        }
    }
}

enum HeatmapColorTheme: String, CaseIterable {
    case flare
    case ember
    case lagoon
    case violet
    case mono

    static let defaultTheme = HeatmapColorTheme.flare

    var title: String {
        switch self {
        case .flare:
            "Flare"
        case .ember:
            "Ember"
        case .lagoon:
            "Lagoon"
        case .violet:
            "Violet"
        case .mono:
            "Mono"
        }
    }

    var subtitle: String {
        switch self {
        case .flare:
            "Warm red-orange frequency"
        case .ember:
            "Soft amber heat"
        case .lagoon:
            "Aqua and blue activity"
        case .violet:
            "Magenta-violet glow"
        case .mono:
            "White intensity only"
        }
    }

    func fill(heat: CGFloat) -> NSColor {
        let clamped = min(1, max(0.12, heat))
        switch self {
        case .flare:
            return NSColor(
                calibratedRed: 0.95,
                green: 0.24 + 0.22 * (1 - clamped),
                blue: 0.18,
                alpha: 0.20 + 0.46 * clamped
            )
        case .ember:
            return NSColor(
                calibratedRed: 1.0,
                green: 0.48 + 0.18 * (1 - clamped),
                blue: 0.08,
                alpha: 0.18 + 0.44 * clamped
            )
        case .lagoon:
            return NSColor(
                calibratedRed: 0.16 + 0.10 * clamped,
                green: 0.66 + 0.18 * clamped,
                blue: 0.88,
                alpha: 0.18 + 0.44 * clamped
            )
        case .violet:
            return NSColor(
                calibratedRed: 0.80 + 0.12 * clamped,
                green: 0.22,
                blue: 0.96,
                alpha: 0.20 + 0.46 * clamped
            )
        case .mono:
            return NSColor(calibratedWhite: 0.82, alpha: 0.16 + 0.46 * clamped)
        }
    }
}

enum GraphColorTheme: String, CaseIterable {
    case signal
    case cyan
    case magenta
    case amber
    case mono

    static let defaultTheme = GraphColorTheme.signal

    var title: String {
        switch self {
        case .signal:
            "Signal"
        case .cyan:
            "Cyan"
        case .magenta:
            "Magenta"
        case .amber:
            "Amber"
        case .mono:
            "Mono"
        }
    }

    var subtitle: String {
        switch self {
        case .signal:
            "Probe blue with red errors"
        case .cyan:
            "Cool strokes, orange deletes"
        case .magenta:
            "Bright violet activity"
        case .amber:
            "Gold strokes, rose deletes"
        case .mono:
            "White strokes and markers"
        }
    }

    var barFill: NSColor {
        switch self {
        case .signal:
            NSColor(calibratedRed: 0.24, green: 0.67, blue: 1.0, alpha: 0.74)
        case .cyan:
            NSColor(calibratedRed: 0.18, green: 0.86, blue: 1.0, alpha: 0.74)
        case .magenta:
            NSColor(calibratedRed: 0.78, green: 0.36, blue: 1.0, alpha: 0.74)
        case .amber:
            NSColor(calibratedRed: 1.0, green: 0.68, blue: 0.18, alpha: 0.76)
        case .mono:
            NSColor.white.withAlphaComponent(0.74)
        }
    }

    var backspaceFill: NSColor {
        switch self {
        case .signal:
            NSColor(calibratedRed: 1.0, green: 0.35, blue: 0.30, alpha: 0.88)
        case .cyan:
            NSColor(calibratedRed: 1.0, green: 0.50, blue: 0.34, alpha: 0.88)
        case .magenta:
            NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.64, alpha: 0.88)
        case .amber:
            NSColor(calibratedRed: 1.0, green: 0.32, blue: 0.45, alpha: 0.88)
        case .mono:
            NSColor.white.withAlphaComponent(0.88)
        }
    }

    func emptyFill(isFuture: Bool) -> NSColor {
        barFill.withAlphaComponent(isFuture ? 0.16 : 0.24)
    }
}

final class KeyboardHUDView: NSView {
    var keymap = LayeredKeymap.voyagerDefault(layers: [])
    var activeLayer = 0
    var shiftActive = false
    var pressedKeys = Set<Int>()
    var heatmap = HeatmapSnapshot()
    var showsHeatmap = true
    var showsTypingStats = false
    var usesSymbolicKeyLabels = false
    var colorTheme = KeyboardColorTheme.defaultTheme
    var heatmapColorTheme = HeatmapColorTheme.defaultTheme
    var graphColorTheme = GraphColorTheme.defaultTheme
    var typingMetrics = TypingMetricsSnapshot.empty
    var designCanvasSize: NSSize?
    var onKeymapDropped: ((URL) -> Void)?
    private var activeDrawingBounds: NSRect?

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
        if let designCanvasSize,
            designCanvasSize.width.isFinite,
            designCanvasSize.height.isFinite,
            designCanvasSize.width > 0,
            designCanvasSize.height > 0
        {
            let targetRect = aspectFitRect(contentSize: designCanvasSize, in: bounds)
            context.saveGState()
            context.translateBy(x: targetRect.minX, y: targetRect.minY)
            context.scaleBy(x: targetRect.width / designCanvasSize.width, y: targetRect.height / designCanvasSize.height)
            activeDrawingBounds = NSRect(origin: .zero, size: designCanvasSize)
            drawContent(in: context)
            activeDrawingBounds = nil
            context.restoreGState()
            return
        }

        activeDrawingBounds = bounds
        drawContent(in: context)
        activeDrawingBounds = nil
    }

    private func drawContent(in context: CGContext) {
        drawKeyboard(in: context)
        if showsTypingStats {
            drawTypingStats()
        }
        drawLayerBadge()
    }

    private func drawKeyboard(in context: CGContext) {
        let bounds = drawingBounds
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
        let stroke = isPressed ? colorTheme.pressedStroke : colorTheme.keyStroke

        let path = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
        fill.setFill()
        path.fill()
        stroke.setStroke()
        path.lineWidth = isPressed ? 2.5 : 1.5
        path.stroke()

        let label = keymap.resolvedLabel(forKeyID: key.id, onLayer: activeLayer).displayLabel(
            shifted: shiftActive,
            usesSymbolicKeyLabels: usesSymbolicKeyLabels
        )
        draw(label: label, in: rect, unit: unit, pressed: isPressed)

        context.restoreGState()
    }

    private func fillColor(pressed: Bool, heat: CGFloat) -> NSColor {
        if pressed {
            return colorTheme.pressedFill
        }
        if heat > 0 {
            return heatmapColorTheme.fill(heat: heat)
        }
        return colorTheme.keyFill
    }

    private func draw(label: KeyLabel, in rect: NSRect, unit: CGFloat, pressed: Bool) {
        guard !label.primary.isEmpty, unit.isFinite, unit > 0 else { return }

        let usesLargePrimaryGlyph = usesLargeSymbolicPrimary(for: label)
        let primaryBaseSize =
            if usesLargePrimaryGlyph {
                max(16, min(32, unit * 0.43))
            } else {
                max(10, min(20, unit * 0.26))
            }
        let secondarySize = max(7, min(10, unit * 0.13))
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byClipping

        let horizontalInset = min(5, max(0, rect.width * 0.18))
        let verticalInsetRatio = usesLargePrimaryGlyph ? 0.20 : 0.30
        let proposedPrimaryRect = rect.insetBy(dx: horizontalInset, dy: max(0, rect.height * verticalInsetRatio))
        guard let primaryRect = textDrawingRect(proposedPrimaryRect) else { return }
        let primaryWeight: NSFont.Weight =
            if usesLargePrimaryGlyph {
                pressed ? .medium : .regular
            } else {
                pressed ? .bold : .semibold
            }
        let primarySize = fittingFontSize(
            for: label.primary,
            baseSize: primaryBaseSize,
            minimumSize: usesLargePrimaryGlyph ? 12 : 7,
            weight: primaryWeight,
            in: primaryRect
        )
        let primaryFont =
            if usesLargePrimaryGlyph {
                systemHUDFont(ofSize: primarySize, weight: primaryWeight)
            } else {
                hudFont(ofSize: primarySize, weight: primaryWeight)
            }
        let primaryAttributes: [NSAttributedString.Key: Any] = [
            .font: primaryFont,
            .foregroundColor: pressed ? colorTheme.pressedLabelColor : colorTheme.labelColor,
            .paragraphStyle: paragraph
        ]

        if usesLargePrimaryGlyph {
            drawCenteredSingleLine(label.primary, in: primaryRect, attributes: primaryAttributes)
        } else {
            label.primary.draw(with: primaryRect, options: [.usesLineFragmentOrigin], attributes: primaryAttributes)
        }

        guard let secondary = label.secondary, !secondary.isEmpty else { return }
        let secondaryAttributes: [NSAttributedString.Key: Any] = [
            .font: hudFont(ofSize: secondarySize, weight: .medium),
            .foregroundColor: pressed ? colorTheme.pressedLabelColor.withAlphaComponent(0.78) : colorTheme.secondaryLabelColor,
            .paragraphStyle: paragraph
        ]
        let secondaryInset = min(5, max(0, rect.width * 0.18))
        let secondaryBottomInset = min(5, max(0, rect.height * 0.08))
        let proposedSecondaryRect = NSRect(
            x: rect.minX + secondaryInset,
            y: rect.minY + secondaryBottomInset,
            width: rect.width - secondaryInset * 2,
            height: secondarySize + 3
        )
        guard let secondaryRect = textDrawingRect(proposedSecondaryRect) else { return }
        secondary.draw(with: secondaryRect, options: [.usesLineFragmentOrigin], attributes: secondaryAttributes)
    }

    private func usesLargeSymbolicPrimary(for label: KeyLabel) -> Bool {
        guard usesSymbolicKeyLabels else { return false }
        let primary = label.primary
        let containsKeyGlyph = primary.unicodeScalars.contains {
            Self.macKeyGlyphScalars.contains($0)
        }
        let containsWordText = primary.rangeOfCharacter(from: .letters) != nil
        return containsKeyGlyph && !containsWordText && primary.count <= 4
    }

    private static let macKeyGlyphScalars = Set("⎋⇥⇧⌃⌥⌘␣⌫⌦↩⌤⇪←→↑↓↖↘⇞⇟".unicodeScalars)

    private func drawCenteredSingleLine(
        _ text: String,
        in rect: NSRect,
        attributes: [NSAttributedString.Key: Any]
    ) {
        let measured = text.size(withAttributes: attributes)
        guard measured.width.isFinite,
            measured.height.isFinite,
            measured.width > 0,
            measured.height > 0
        else {
            return
        }

        let drawRect = NSRect(
            x: rect.midX - measured.width / 2,
            y: rect.midY - measured.height / 2,
            width: measured.width,
            height: measured.height
        )
        text.draw(with: drawRect, options: [.usesLineFragmentOrigin], attributes: attributes)
    }

    private func fittingFontSize(
        for text: String,
        baseSize: CGFloat,
        minimumSize: CGFloat,
        weight: NSFont.Weight,
        in rect: NSRect
    ) -> CGFloat {
        guard !text.isEmpty, let rect = textDrawingRect(rect) else {
            return sanitizedFontSize(minimumSize)
        }

        let minimumSize = sanitizedFontSize(minimumSize)
        var size = max(minimumSize, sanitizedFontSize(baseSize))
        while size > minimumSize {
            let font = hudFont(ofSize: size, weight: weight)
            let measured = text.size(withAttributes: [.font: font])
            if measured.width.isFinite,
                measured.height.isFinite,
                measured.width <= rect.width,
                measured.height <= rect.height
            {
                return size
            }
            size -= 0.5
        }
        return minimumSize
    }

    private func hudFont(ofSize size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let safeSize = sanitizedFontSize(size)
        let monospacedFont: NSFont? = NSFont.monospacedSystemFont(ofSize: safeSize, weight: weight)
        return monospacedFont ?? NSFont.systemFont(ofSize: safeSize, weight: weight)
    }

    private func systemHUDFont(ofSize size: CGFloat, weight: NSFont.Weight) -> NSFont {
        NSFont.systemFont(ofSize: sanitizedFontSize(size), weight: weight)
    }

    private func sanitizedFontSize(_ size: CGFloat) -> CGFloat {
        guard size.isFinite, size > 0 else { return 10 }
        return min(48, max(4, size))
    }

    private func textDrawingRect(_ rect: NSRect) -> NSRect? {
        let rect = rect.standardized
        guard rect.origin.x.isFinite,
            rect.origin.y.isFinite,
            rect.width.isFinite,
            rect.height.isFinite
        else {
            return nil
        }
        return NSRect(
            x: rect.minX,
            y: rect.minY,
            width: max(1, rect.width),
            height: max(1, rect.height)
        )
    }

    private func drawLayerBadge() {
        let bounds = drawingBounds
        let text = "L\(activeLayer)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: hudFont(ofSize: 12, weight: .semibold),
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
        colorTheme.layerBadgeFill.setFill()
        path.fill()
        text.draw(at: CGPoint(x: rect.minX + 7, y: rect.minY + 4), withAttributes: attrs)
    }

    private func drawTypingStats() {
        let bounds = drawingBounds
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
        colorTheme.statsFill.setFill()
        path.fill()

        drawStatsText(in: rect)
        drawStatsGraph(in: statsGraphRect(in: rect))
    }

    private func drawStatsText(in rect: NSRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byClipping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: hudFont(ofSize: 10, weight: .semibold),
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
            graphColorTheme.barFill.setFill()
            path.fill()

            guard bucket.backspaces > 0 else { continue }
            let markerRect = NSRect(x: rect.maxX - 3, y: barRect.minY, width: 3, height: barHeight)
            graphColorTheme.backspaceFill.setFill()
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
        graphColorTheme.emptyFill(isFuture: isFuture).setFill()
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

    private var drawingBounds: NSRect {
        activeDrawingBounds ?? bounds
    }

    private func aspectFitRect(contentSize: NSSize, in rect: NSRect) -> NSRect {
        let scale = min(rect.width / contentSize.width, rect.height / contentSize.height)
        let size = NSSize(width: contentSize.width * scale, height: contentSize.height * scale)
        return NSRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
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
