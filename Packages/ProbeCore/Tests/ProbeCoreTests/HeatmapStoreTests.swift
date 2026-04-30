import XCTest

@testable import ProbeCore

final class HeatmapStoreTests: XCTestCase {
    func testRecordsKeyDownAndReloadsAllTimeOnly() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("heatmap.json")

        let store = HeatmapStore(fileURL: url)
        store.recordKeyDown(layer: 1, keyID: 49)
        store.recordKeyDown(layer: 1, keyID: 49)

        XCTAssertEqual(store.snapshot().sessionCount(layer: 1, keyID: 49), 2)
        XCTAssertEqual(store.snapshot().allTimeCount(layer: 1, keyID: 49), 2)

        let reloaded = HeatmapStore(fileURL: url)
        XCTAssertEqual(reloaded.snapshot().sessionCount(layer: 1, keyID: 49), 0)
        XCTAssertEqual(reloaded.snapshot().allTimeCount(layer: 1, keyID: 49), 2)
    }

    func testResetModes() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("heatmap.json")

        let store = HeatmapStore(fileURL: url)
        store.recordKeyDown(layer: 0, keyID: 0)
        store.resetSession()

        XCTAssertEqual(store.snapshot().sessionCount(layer: 0, keyID: 0), 0)
        XCTAssertEqual(store.snapshot().allTimeCount(layer: 0, keyID: 0), 1)

        store.resetAllTime()
        XCTAssertEqual(store.snapshot().allTimeCount(layer: 0, keyID: 0), 0)
    }
}
