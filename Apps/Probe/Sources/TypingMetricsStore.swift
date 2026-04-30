import Foundation
import ProbeCore

struct TypingMetricsBucket: Equatable {
    var strokes: Int
    var backspaces: Int
    var isFuture: Bool = false
}

struct TypingMetricsSnapshot: Equatable {
    var strokesPerSecond: Double
    var strokesPerMinute: Int
    var wordsPerMinute: Double
    var backspacesPerMinute: Int
    var buckets: [TypingMetricsBucket]
    var scrollProgress: Double = 0

    static let empty = TypingMetricsSnapshot(
        strokesPerSecond: 0,
        strokesPerMinute: 0,
        wordsPerMinute: 0,
        backspacesPerMinute: 0,
        buckets: Array(repeating: TypingMetricsBucket(strokes: 0, backspaces: 0), count: TypingMetricsStore.bucketCount),
        scrollProgress: 0
    )
}

final class TypingMetricsStore {
    static let bucketCount = 24
    static let bucketDuration: TimeInterval = 2.5

    private let historyWindow: TimeInterval = 60
    private let instantWindow: TimeInterval = 5
    private var events: [TypingEvent] = []

    func record(label: KeyLabel, at date: Date = Date()) {
        events.append(
            TypingEvent(
                date: date,
                textUnits: Self.textUnits(for: label),
                isBackspace: Self.isBackspace(label)
            )
        )
        prune(now: date)
    }

    func snapshot(now: Date = Date()) -> TypingMetricsSnapshot {
        prune(now: now)
        let recentEvents = events.filter { now.timeIntervalSince($0.date) <= historyWindow }
        let instantCount = recentEvents.filter { now.timeIntervalSince($0.date) <= instantWindow }.count
        let textUnits = recentEvents.reduce(0) { $0 + $1.textUnits }
        let backspaces = recentEvents.filter(\.isBackspace).count

        return TypingMetricsSnapshot(
            strokesPerSecond: Double(instantCount) / instantWindow,
            strokesPerMinute: recentEvents.count,
            wordsPerMinute: Double(textUnits) / 5,
            backspacesPerMinute: backspaces,
            buckets: buckets(now: now),
            scrollProgress: Self.scrollProgress(containing: now.timeIntervalSince1970)
        )
    }

    func reset() {
        events.removeAll()
    }

    private func prune(now: Date) {
        events.removeAll { now.timeIntervalSince($0.date) > historyWindow }
    }

    private func buckets(now: Date) -> [TypingMetricsBucket] {
        let nowTime = now.timeIntervalSince1970
        let currentBucket = Self.bucketNumber(containing: nowTime)
        let firstBucket = currentBucket - Self.bucketCount + 1
        var buckets = (0..<Self.bucketCount).map { index in
            let bucketNumber = firstBucket + index
            return TypingMetricsBucket(strokes: 0, backspaces: 0, isFuture: bucketNumber > currentBucket)
        }

        for event in events {
            let eventBucket = Self.bucketNumber(containing: event.date.timeIntervalSince1970)
            guard eventBucket >= firstBucket, eventBucket <= currentBucket else { continue }
            let index = eventBucket - firstBucket
            buckets[index].strokes += 1
            if event.isBackspace {
                buckets[index].backspaces += 1
            }
        }
        return buckets
    }

    private static func bucketNumber(containing time: TimeInterval) -> Int {
        Int(floor(time / bucketDuration))
    }

    private static func scrollProgress(containing time: TimeInterval) -> Double {
        let remainder = time - floor(time / bucketDuration) * bucketDuration
        return min(1, max(0, remainder / bucketDuration))
    }

    private static func textUnits(for label: KeyLabel) -> Int {
        let primary = label.primary.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = label.raw.uppercased()

        if isBackspace(label) || label.role == .modifier || label.role == .layer || label.role == .rgb || label.role == .pointer {
            return 0
        }
        if primary.caseInsensitiveCompare("Space") == .orderedSame || raw.contains("KC_SPC") {
            return 1
        }
        if primary.count == 1 {
            return 1
        }
        return 0
    }

    private static func isBackspace(_ label: KeyLabel) -> Bool {
        let primary = label.primary.lowercased()
        let raw = label.raw.uppercased()
        return primary.contains("delete")
            || primary.contains("backspace")
            || raw.contains("KC_BSPC")
            || raw.contains("KC_DEL")
            || raw.contains("KC_BACKSPACE")
            || raw.contains("KC_DELETE")
    }
}

private struct TypingEvent {
    let date: Date
    let textUnits: Int
    let isBackspace: Bool
}
