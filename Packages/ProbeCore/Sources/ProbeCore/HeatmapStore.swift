import Foundation

public struct HeatmapSnapshot: Codable, Equatable, Sendable {
    public var sessionCounts: [String: Int]
    public var allTimeCounts: [String: Int]

    public init(sessionCounts: [String: Int] = [:], allTimeCounts: [String: Int] = [:]) {
        self.sessionCounts = sessionCounts
        self.allTimeCounts = allTimeCounts
    }

    public func sessionCount(layer: Int, keyID: Int) -> Int {
        sessionCounts[Self.key(layer: layer, keyID: keyID), default: 0]
    }

    public func allTimeCount(layer: Int, keyID: Int) -> Int {
        allTimeCounts[Self.key(layer: layer, keyID: keyID), default: 0]
    }

    public static func key(layer: Int, keyID: Int) -> String {
        "\(layer):\(keyID)"
    }
}

public final class HeatmapStore: @unchecked Sendable {
    public let fileURL: URL
    private var snapshotStorage: HeatmapSnapshot

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.snapshotStorage = Self.load(from: self.fileURL)
    }

    public func snapshot() -> HeatmapSnapshot {
        snapshotStorage
    }

    public func recordKeyDown(layer: Int, keyID: Int) {
        let key = HeatmapSnapshot.key(layer: layer, keyID: keyID)
        snapshotStorage.sessionCounts[key, default: 0] += 1
        snapshotStorage.allTimeCounts[key, default: 0] += 1
        try? save()
    }

    public func resetSession() {
        snapshotStorage.sessionCounts.removeAll()
        try? save()
    }

    public func resetAllTime() {
        snapshotStorage.sessionCounts.removeAll()
        snapshotStorage.allTimeCounts.removeAll()
        try? save()
    }

    public func save() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshotStorage).write(to: fileURL, options: .atomic)
    }

    private static func load(from fileURL: URL) -> HeatmapSnapshot {
        guard let data = try? Data(contentsOf: fileURL),
            let snapshot = try? JSONDecoder().decode(HeatmapSnapshot.self, from: data)
        else {
            return HeatmapSnapshot()
        }
        return HeatmapSnapshot(sessionCounts: [:], allTimeCounts: snapshot.allTimeCounts)
    }

    private static func defaultFileURL() -> URL {
        appSupportBase().appendingPathComponent("Probe/heatmap.json")
    }

    private static func appSupportBase() -> URL {
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base
    }
}
