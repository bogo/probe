import AppKit
import XCTest

final class HUDSettingsStoreTests: XCTestCase {
    func testPersistsAndClampsHUDSettings() {
        let suiteName = "ProbeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = HUDSettingsStore(defaults: defaults, visibleScreenFrames: { [NSRect(x: 0, y: 0, width: 1440, height: 900)] })
        let settings = HUDSettings(
            frame: NSRect(x: 240, y: 240, width: 720, height: 288),
            scale: 1.22,
            opacity: 0.65,
            showsHeatmap: false,
            showsTypingStats: true
        )

        store.save(settings)

        XCTAssertEqual(store.load(), settings)

        defaults.set(10.0, forKey: "hud.scale")
        defaults.set(0.01, forKey: "hud.opacity")

        let clamped = store.load()
        XCTAssertEqual(clamped.scale, 1.6)
        XCTAssertEqual(clamped.opacity, 0.35)
    }

    func testRestoresCornerAnchoredFrameAgainstCurrentScreenSize() {
        let suiteName = "ProbeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var screens = [NSRect(x: 0, y: 0, width: 1440, height: 900)]
        let store = HUDSettingsStore(defaults: defaults, visibleScreenFrames: { screens })
        let settings = HUDSettings(
            frame: NSRect(x: 696, y: 580, width: 720, height: 288),
            scale: 1,
            opacity: 0.88,
            showsHeatmap: true,
            showsTypingStats: false
        )

        store.save(settings)
        screens = [NSRect(x: 0, y: 0, width: 1920, height: 1080)]

        let restored = store.load()

        XCTAssertEqual(restored.frame, NSRect(x: 1176, y: 760, width: 720, height: 288))
        XCTAssertEqual(restored.cornerAnchor?.corner, .topRight)
        XCTAssertEqual(restored.cornerAnchor?.horizontalInset, 24)
        XCTAssertEqual(restored.cornerAnchor?.verticalInset, 32)
    }

    func testMovingAwayFromCornerClearsCornerAnchor() {
        let suiteName = "ProbeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var screens = [NSRect(x: 0, y: 0, width: 1440, height: 900)]
        let store = HUDSettingsStore(defaults: defaults, visibleScreenFrames: { screens })
        let cornerSettings = HUDSettings(
            frame: NSRect(x: 24, y: 28, width: 720, height: 288),
            scale: 1,
            opacity: 0.88,
            showsHeatmap: true,
            showsTypingStats: false
        )
        let centeredSettings = HUDSettings(
            frame: NSRect(x: 320, y: 260, width: 720, height: 288),
            scale: 1,
            opacity: 0.88,
            showsHeatmap: true,
            showsTypingStats: false
        )

        store.save(cornerSettings)
        store.save(centeredSettings)
        screens = [NSRect(x: 0, y: 0, width: 1920, height: 1080)]

        let restored = store.load()

        XCTAssertEqual(restored.frame, centeredSettings.frame)
        XCTAssertNil(restored.cornerAnchor)
    }
}
