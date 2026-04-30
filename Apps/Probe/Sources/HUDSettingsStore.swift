import AppKit

struct HUDSettings: Equatable {
    var frame: NSRect
    var scale: CGFloat
    var opacity: CGFloat
    var showsHeatmap: Bool
    var showsTypingStats: Bool

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
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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

        return settings
    }

    func save(_ settings: HUDSettings) {
        defaults.set(NSStringFromRect(settings.frame), forKey: Key.frame)
        defaults.set(Double(settings.scale), forKey: Key.scale)
        defaults.set(Double(settings.opacity), forKey: Key.opacity)
        defaults.set(settings.showsHeatmap, forKey: Key.showsHeatmap)
        defaults.set(settings.showsTypingStats, forKey: Key.showsTypingStats)
    }

    private enum Key {
        static let frame = "hud.frame"
        static let scale = "hud.scale"
        static let opacity = "hud.opacity"
        static let showsHeatmap = "hud.showsHeatmap"
        static let showsTypingStats = "hud.showsTypingStats"
    }
}

extension NSRect {
    fileprivate var validHUDFrame: NSRect? {
        guard width >= 480, height >= 190, width.isFinite, height.isFinite, origin.x.isFinite, origin.y.isFinite else {
            return nil
        }
        return self
    }
}

extension CGFloat {
    fileprivate func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(range.upperBound, Swift.max(range.lowerBound, self))
    }
}
