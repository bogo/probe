import AppKit
import XCTest

final class HUDSettingsStoreTests: XCTestCase {
    func testPersistsAndClampsHUDSettings() {
        let suiteName = "ProbeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = HUDSettingsStore(defaults: defaults)
        let settings = HUDSettings(
            frame: NSRect(x: 42, y: 84, width: 720, height: 288),
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
}
