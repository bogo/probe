import ProbeCore
import XCTest

final class TypingMetricsStoreTests: XCTestCase {
    func testCalculatesMomentaryRatesAndBackspaces() {
        let store = TypingMetricsStore()
        let start = Date(timeIntervalSince1970: 100)
        store.record(label: KeyLabel(primary: "A", raw: "KC_A"), at: start)
        store.record(label: KeyLabel(primary: "Space", raw: "KC_SPC"), at: start.addingTimeInterval(1))
        store.record(label: KeyLabel(primary: "Delete", raw: "KC_BSPC"), at: start.addingTimeInterval(2))

        let snapshot = store.snapshot(now: start.addingTimeInterval(5))

        XCTAssertEqual(snapshot.strokesPerSecond, 0.6, accuracy: 0.001)
        XCTAssertEqual(snapshot.strokesPerMinute, 3)
        XCTAssertEqual(snapshot.wordsPerMinute, 0.4, accuracy: 0.001)
        XCTAssertEqual(snapshot.backspacesPerMinute, 1)
        XCTAssertEqual(snapshot.buckets.reduce(0) { $0 + $1.strokes }, 3)
        XCTAssertEqual(snapshot.buckets.reduce(0) { $0 + $1.backspaces }, 1)
    }

    func testPrunesEventsOutsideTheMinuteWindow() {
        let store = TypingMetricsStore()
        let start = Date(timeIntervalSince1970: 100)
        store.record(label: KeyLabel(primary: "A", raw: "KC_A"), at: start)
        store.record(label: KeyLabel(primary: "B", raw: "KC_B"), at: start.addingTimeInterval(61))

        let snapshot = store.snapshot(now: start.addingTimeInterval(61))

        XCTAssertEqual(snapshot.strokesPerMinute, 1)
        XCTAssertEqual(snapshot.wordsPerMinute, 0.2, accuracy: 0.001)
    }

    func testBucketsStayInFixedWallClockIntervalsAndScrollWhileIdle() {
        let store = TypingMetricsStore()
        let eventTime = Date(timeIntervalSince1970: 100.1)
        store.record(label: KeyLabel(primary: "A", raw: "KC_A"), at: eventTime)

        let firstSnapshot = store.snapshot(now: Date(timeIntervalSince1970: 101.0))
        let sameBucketSnapshot = store.snapshot(now: Date(timeIntervalSince1970: 102.4))
        let scrolledSnapshot = store.snapshot(now: Date(timeIntervalSince1970: 102.6))

        XCTAssertEqual(nonEmptyBucketIndexes(in: firstSnapshot), [23])
        XCTAssertEqual(nonEmptyBucketIndexes(in: sameBucketSnapshot), [23])
        XCTAssertEqual(nonEmptyBucketIndexes(in: scrolledSnapshot), [22])
        XCTAssertEqual(firstSnapshot.scrollProgress, 0.4, accuracy: 0.001)
        XCTAssertEqual(sameBucketSnapshot.scrollProgress, 0.96, accuracy: 0.001)
        XCTAssertEqual(scrolledSnapshot.scrollProgress, 0.04, accuracy: 0.001)
    }

    func testEmptyTimelineContainsEveryBucket() {
        let store = TypingMetricsStore()
        let snapshot = store.snapshot(now: Date(timeIntervalSince1970: 105.0))

        XCTAssertEqual(snapshot.buckets.count, TypingMetricsStore.bucketCount)
        XCTAssertTrue(snapshot.buckets.allSatisfy { !$0.isFuture })
        XCTAssertTrue(snapshot.buckets.allSatisfy { $0.strokes == 0 && $0.backspaces == 0 })
    }

    private func nonEmptyBucketIndexes(in snapshot: TypingMetricsSnapshot) -> [Int] {
        snapshot.buckets.enumerated().compactMap { index, bucket in
            bucket.strokes > 0 ? index : nil
        }
    }
}
