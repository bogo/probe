import AppKit

struct HUDSettings: Equatable {
    var frame: NSRect
    var scale: CGFloat
    var opacity: CGFloat
    var showsHeatmap: Bool
    var showsTypingStats: Bool
    var cornerAnchor: HUDCornerAnchor? = nil

    static let defaultFrame = NSRect(x: 120, y: 120, width: 900, height: 360)
    static let defaultScale: CGFloat = 1
    static let defaultOpacity: CGFloat = 0.88
    static let defaultShowsHeatmap = true
    static let defaultShowsTypingStats = false

    static let defaults = HUDSettings(
        frame: defaultFrame,
        scale: defaultScale,
        opacity: defaultOpacity,
        showsHeatmap: defaultShowsHeatmap,
        showsTypingStats: defaultShowsTypingStats
    )
}

struct HUDSettingsStore {
    private static let cornerAnchorThreshold: CGFloat = 96

    private let defaults: UserDefaults
    private let visibleScreenFrames: () -> [NSRect]

    init(
        defaults: UserDefaults = .standard,
        visibleScreenFrames: @escaping () -> [NSRect] = { NSScreen.screens.map(\.visibleFrame) }
    ) {
        self.defaults = defaults
        self.visibleScreenFrames = visibleScreenFrames
    }

    func load() -> HUDSettings {
        var settings = HUDSettings.defaults

        if let frameString = defaults.string(forKey: Key.frame),
            let frame = NSRectFromString(frameString).validHUDFrame
        {
            settings.frame = frame
        }

        if defaults.object(forKey: Key.scale) != nil {
            settings.scale = CGFloat(defaults.double(forKey: Key.scale)).clamped(to: 0.6...1.6)
        }

        if defaults.object(forKey: Key.opacity) != nil {
            settings.opacity = CGFloat(defaults.double(forKey: Key.opacity)).clamped(to: 0.35...1.0)
        }

        if defaults.object(forKey: Key.showsHeatmap) != nil {
            settings.showsHeatmap = defaults.bool(forKey: Key.showsHeatmap)
        }

        if defaults.object(forKey: Key.showsTypingStats) != nil {
            settings.showsTypingStats = defaults.bool(forKey: Key.showsTypingStats)
        }

        if let anchor = loadCornerAnchor(),
            let resolvedFrame = resolve(anchor: anchor, size: settings.frame.size)
        {
            settings.frame = resolvedFrame
            settings.cornerAnchor = anchor
        }

        return settings
    }

    func save(_ settings: HUDSettings) {
        defaults.set(NSStringFromRect(settings.frame), forKey: Key.frame)
        defaults.set(Double(settings.scale), forKey: Key.scale)
        defaults.set(Double(settings.opacity), forKey: Key.opacity)
        defaults.set(settings.showsHeatmap, forKey: Key.showsHeatmap)
        defaults.set(settings.showsTypingStats, forKey: Key.showsTypingStats)

        if let anchor = cornerAnchor(for: settings.frame) {
            defaults.set(anchor.corner.rawValue, forKey: Key.anchorCorner)
            defaults.set(Double(anchor.horizontalInset), forKey: Key.anchorHorizontalInset)
            defaults.set(Double(anchor.verticalInset), forKey: Key.anchorVerticalInset)
            defaults.set(NSStringFromRect(anchor.screenFrame), forKey: Key.anchorScreenFrame)
        } else {
            defaults.removeObject(forKey: Key.anchorCorner)
            defaults.removeObject(forKey: Key.anchorHorizontalInset)
            defaults.removeObject(forKey: Key.anchorVerticalInset)
            defaults.removeObject(forKey: Key.anchorScreenFrame)
        }
    }

    private enum Key {
        static let frame = "hud.frame"
        static let scale = "hud.scale"
        static let opacity = "hud.opacity"
        static let showsHeatmap = "hud.showsHeatmap"
        static let showsTypingStats = "hud.showsTypingStats"
        static let anchorCorner = "hud.cornerAnchor.corner"
        static let anchorHorizontalInset = "hud.cornerAnchor.horizontalInset"
        static let anchorVerticalInset = "hud.cornerAnchor.verticalInset"
        static let anchorScreenFrame = "hud.cornerAnchor.screenFrame"
    }

    private func loadCornerAnchor() -> HUDCornerAnchor? {
        guard let cornerName = defaults.string(forKey: Key.anchorCorner),
            let corner = HUDCorner(rawValue: cornerName),
            defaults.object(forKey: Key.anchorHorizontalInset) != nil,
            defaults.object(forKey: Key.anchorVerticalInset) != nil,
            let screenFrameString = defaults.string(forKey: Key.anchorScreenFrame)
        else {
            return nil
        }

        let screenFrame = NSRectFromString(screenFrameString)
        guard let validScreenFrame = screenFrame.validScreenFrame else { return nil }

        return HUDCornerAnchor(
            corner: corner,
            horizontalInset: CGFloat(defaults.double(forKey: Key.anchorHorizontalInset)).clamped(to: 0...10_000),
            verticalInset: CGFloat(defaults.double(forKey: Key.anchorVerticalInset)).clamped(to: 0...10_000),
            screenFrame: validScreenFrame
        )
    }

    private func cornerAnchor(for frame: NSRect) -> HUDCornerAnchor? {
        guard let screenFrame = screenFrame(for: frame) else { return nil }

        let leftInset = frame.minX - screenFrame.minX
        let rightInset = screenFrame.maxX - frame.maxX
        let bottomInset = frame.minY - screenFrame.minY
        let topInset = screenFrame.maxY - frame.maxY

        let candidates: [(HUDCorner, CGFloat, CGFloat)] = [
            (.bottomLeft, leftInset, bottomInset),
            (.bottomRight, rightInset, bottomInset),
            (.topLeft, leftInset, topInset),
            (.topRight, rightInset, topInset)
        ]

        guard
            let closest =
                (candidates
                    .filter { candidate in
                        isNearScreenEdge(candidate.1) && isNearScreenEdge(candidate.2)
                    }
                    .min(by: { lhs, rhs in
                        hypot(lhs.1, lhs.2) < hypot(rhs.1, rhs.2)
                    }))
        else {
            return nil
        }

        return HUDCornerAnchor(
            corner: closest.0,
            horizontalInset: max(0, closest.1),
            verticalInset: max(0, closest.2),
            screenFrame: screenFrame
        )
    }

    private func resolve(anchor: HUDCornerAnchor, size: NSSize) -> NSRect? {
        guard let screenFrame = currentScreenFrame(matching: anchor.screenFrame) else { return nil }

        let x =
            switch anchor.corner {
            case .bottomLeft, .topLeft:
                screenFrame.minX + anchor.horizontalInset
            case .bottomRight, .topRight:
                screenFrame.maxX - size.width - anchor.horizontalInset
            }

        let y =
            switch anchor.corner {
            case .bottomLeft, .bottomRight:
                screenFrame.minY + anchor.verticalInset
            case .topLeft, .topRight:
                screenFrame.maxY - size.height - anchor.verticalInset
            }

        return NSRect(origin: CGPoint(x: x, y: y), size: size).clamped(to: screenFrame)
    }

    private func currentScreenFrame(matching storedScreenFrame: NSRect) -> NSRect? {
        let screens = usableScreenFrames()
        guard !screens.isEmpty else { return nil }

        let storedCenter = CGPoint(x: storedScreenFrame.midX, y: storedScreenFrame.midY)
        if let containingScreen = screens.first(where: { $0.contains(storedCenter) }) {
            return containingScreen
        }

        return screens.max { lhs, rhs in
            let lhsIntersection = lhs.intersection(storedScreenFrame).area
            let rhsIntersection = rhs.intersection(storedScreenFrame).area
            if lhsIntersection == rhsIntersection {
                return lhs.distanceSquared(to: storedCenter) > rhs.distanceSquared(to: storedCenter)
            }
            return lhsIntersection < rhsIntersection
        }
    }

    private func screenFrame(for frame: NSRect) -> NSRect? {
        let screens = usableScreenFrames()
        guard !screens.isEmpty else { return nil }

        let frameCenter = CGPoint(x: frame.midX, y: frame.midY)
        if let containingScreen = screens.first(where: { $0.contains(frameCenter) }) {
            return containingScreen
        }

        return screens.max { lhs, rhs in
            lhs.intersection(frame).area < rhs.intersection(frame).area
        }
    }

    private func usableScreenFrames() -> [NSRect] {
        visibleScreenFrames().compactMap(\.validScreenFrame)
    }

    private func isNearScreenEdge(_ inset: CGFloat) -> Bool {
        inset.isFinite && abs(inset) <= Self.cornerAnchorThreshold
    }
}

enum HUDCorner: String, Equatable {
    case bottomLeft
    case bottomRight
    case topLeft
    case topRight
}

struct HUDCornerAnchor: Equatable {
    let corner: HUDCorner
    let horizontalInset: CGFloat
    let verticalInset: CGFloat
    let screenFrame: NSRect
}

extension NSRect {
    fileprivate var validHUDFrame: NSRect? {
        guard width >= 480, height >= 190, width.isFinite, height.isFinite, origin.x.isFinite, origin.y.isFinite else {
            return nil
        }
        return self
    }

    fileprivate var validScreenFrame: NSRect? {
        guard width > 0, height > 0, width.isFinite, height.isFinite, origin.x.isFinite, origin.y.isFinite else {
            return nil
        }
        return self
    }

    fileprivate var area: CGFloat {
        max(0, width) * max(0, height)
    }

    fileprivate func distanceSquared(to point: CGPoint) -> CGFloat {
        let dx = midX - point.x
        let dy = midY - point.y
        return dx * dx + dy * dy
    }

    fileprivate func clamped(to screenFrame: NSRect) -> NSRect {
        let maximumX = max(screenFrame.minX, screenFrame.maxX - width)
        let maximumY = max(screenFrame.minY, screenFrame.maxY - height)
        let clampedX = min(maximumX, max(screenFrame.minX, minX))
        let clampedY = min(maximumY, max(screenFrame.minY, minY))
        return NSRect(x: clampedX, y: clampedY, width: width, height: height)
    }
}

extension CGFloat {
    fileprivate func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(range.upperBound, Swift.max(range.lowerBound, self))
    }
}
