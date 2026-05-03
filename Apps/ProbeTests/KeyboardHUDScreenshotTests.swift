import AppKit
import ProbeCore
import XCTest

@MainActor
final class KeyboardHUDScreenshotTests: XCTestCase {
    func testKeyboardHUDSnapshotLooksLikeExpectedLayout() throws {
        let view = KeyboardHUDView(frame: NSRect(x: 0, y: 0, width: 900, height: 360))
        view.keymap = try Self.sampleKeymap()
        view.activeLayer = 0
        view.pressedKeys = [0, 49]
        view.heatmap = HeatmapSnapshot(
            allTimeCounts: [
                HeatmapSnapshot.key(layer: 0, keyID: 24): 9,
                HeatmapSnapshot.key(layer: 0, keyID: 25): 7,
                HeatmapSnapshot.key(layer: 0, keyID: 26): 4,
                HeatmapSnapshot.key(layer: 0, keyID: 49): 12
            ]
        )

        let bitmap = try render(view)
        let metrics = PixelMetrics(bitmap: bitmap)

        XCTAssertEqual(bitmap.pixelsWide, 900)
        XCTAssertEqual(bitmap.pixelsHigh, 360)
        XCTAssertGreaterThan(metrics.nonTransparentPixels, 60_000)
        XCTAssertGreaterThan(metrics.transparentPixels, 120_000)
        XCTAssertGreaterThan(metrics.bluePixels, 1_500)
        XCTAssertGreaterThan(metrics.heatPixels, 1_500)
        XCTAssertLessThan(metrics.contentBounds.width, 880)
        XCTAssertLessThan(metrics.contentBounds.height, 340)

        let screenshotURL = try writeScreenshot(bitmap, name: "ProbeHUD-layer0.png")
        let attachment = XCTAttachment(contentsOfFile: screenshotURL)
        attachment.name = "ProbeHUD-layer0"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testKeyboardHUDEmptyKeymapStillHighlightsPressedKeys() throws {
        let view = KeyboardHUDView(frame: NSRect(x: 0, y: 0, width: 900, height: 360))
        view.keymap = LayeredKeymap.voyagerDefault(layers: [])
        view.activeLayer = 0
        view.pressedKeys = [0, 49]
        view.showsHeatmap = false

        let bitmap = try render(view)
        let metrics = PixelMetrics(bitmap: bitmap)

        XCTAssertGreaterThan(metrics.nonTransparentPixels, 50_000)
        XCTAssertGreaterThan(metrics.bluePixels, 1_500)
        XCTAssertLessThan(metrics.heatPixels, 250)
        XCTAssertLessThan(metrics.contentBounds.width, 880)
        XCTAssertLessThan(metrics.contentBounds.height, 340)

        let screenshotURL = try writeScreenshot(bitmap, name: "ProbeHUD-empty-keymap-highlight.png")
        let attachment = XCTAttachment(contentsOfFile: screenshotURL)
        attachment.name = "ProbeHUD-empty-keymap-highlight"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testKeyboardHUDStatsSnapshotRendersWithHeatmapHidden() throws {
        let view = KeyboardHUDView(frame: NSRect(x: 0, y: 0, width: 900, height: 360))
        view.keymap = try Self.sampleKeymap()
        view.activeLayer = 0
        view.pressedKeys = [25]
        view.showsHeatmap = false
        view.showsTypingStats = true
        view.heatmap = HeatmapSnapshot(
            allTimeCounts: [
                HeatmapSnapshot.key(layer: 0, keyID: 24): 50,
                HeatmapSnapshot.key(layer: 0, keyID: 25): 50,
                HeatmapSnapshot.key(layer: 0, keyID: 26): 50
            ]
        )
        view.typingMetrics = TypingMetricsSnapshot(
            strokesPerSecond: 2.4,
            strokesPerMinute: 144,
            wordsPerMinute: 58,
            backspacesPerMinute: 7,
            buckets: (0..<TypingMetricsStore.bucketCount).map {
                if $0 % 5 == 0 || $0 > 20 {
                    return TypingMetricsBucket(strokes: 0, backspaces: 0, isFuture: $0 > 20)
                }
                return TypingMetricsBucket(strokes: ($0 % 6) + 1, backspaces: $0 % 8 == 0 ? 1 : 0)
            },
            scrollProgress: 0.42
        )

        let bitmap = try render(view)
        let metrics = PixelMetrics(bitmap: bitmap)
        let statsPixels = nonTransparentPixels(
            in: CGRect(x: 404, y: 64, width: 92, height: 232),
            bitmap: bitmap
        )

        XCTAssertGreaterThan(metrics.nonTransparentPixels, 55_000)
        XCTAssertGreaterThan(metrics.bluePixels, 1_200)
        XCTAssertGreaterThan(statsPixels, 1_400)
        XCTAssertLessThan(metrics.heatPixels, 1_000)

        let screenshotURL = try writeScreenshot(bitmap, name: "ProbeHUD-stats-no-heat.png")
        let attachment = XCTAttachment(contentsOfFile: screenshotURL)
        attachment.name = "ProbeHUD-stats-no-heat"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testKeyboardHUDShiftSnapshotRendersAlternateSymbols() throws {
        let view = KeyboardHUDView(frame: NSRect(x: 0, y: 0, width: 900, height: 360))
        view.keymap = try Self.sampleKeymap()
        view.activeLayer = 0
        view.shiftActive = true
        view.pressedKeys = [24]

        let bitmap = try render(view)
        let metrics = PixelMetrics(bitmap: bitmap)

        XCTAssertGreaterThan(metrics.nonTransparentPixels, 50_000)
        XCTAssertGreaterThan(metrics.bluePixels, 1_000)
        XCTAssertLessThan(metrics.contentBounds.width, 880)
        XCTAssertLessThan(metrics.contentBounds.height, 340)

        let screenshotURL = try writeScreenshot(bitmap, name: "ProbeHUD-shifted.png")
        let attachment = XCTAttachment(contentsOfFile: screenshotURL)
        attachment.name = "ProbeHUD-shifted"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testKeyboardHUDSymbolicKeyLabelsSnapshotRendersMacOSGlyphs() throws {
        let view = KeyboardHUDView(frame: NSRect(x: 0, y: 0, width: 900, height: 360))
        view.keymap = try Self.sampleKeymap()
        view.activeLayer = 0
        view.usesSymbolicKeyLabels = true
        view.pressedKeys = [0, 24, 47]

        let bitmap = try render(view)
        let metrics = PixelMetrics(bitmap: bitmap)

        XCTAssertGreaterThan(metrics.nonTransparentPixels, 50_000)
        XCTAssertGreaterThan(metrics.bluePixels, 1_000)
        XCTAssertLessThan(metrics.contentBounds.width, 880)
        XCTAssertLessThan(metrics.contentBounds.height, 340)

        let screenshotURL = try writeScreenshot(bitmap, name: "ProbeHUD-symbolic-labels.png")
        let attachment = XCTAttachment(contentsOfFile: screenshotURL)
        attachment.name = "ProbeHUD-symbolic-labels"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testKeyboardHUDThemeSnapshotRendersAlternatePalette() throws {
        let view = KeyboardHUDView(frame: NSRect(x: 0, y: 0, width: 900, height: 360))
        view.keymap = try Self.sampleKeymap()
        view.activeLayer = 0
        view.colorTheme = .aurora
        view.heatmapColorTheme = .lagoon
        view.graphColorTheme = .amber
        view.showsTypingStats = true
        view.pressedKeys = [25]
        view.heatmap = HeatmapSnapshot(
            allTimeCounts: [
                HeatmapSnapshot.key(layer: 0, keyID: 24): 8,
                HeatmapSnapshot.key(layer: 0, keyID: 25): 12,
                HeatmapSnapshot.key(layer: 0, keyID: 26): 5
            ]
        )
        view.typingMetrics = TypingMetricsSnapshot(
            strokesPerSecond: 2.2,
            strokesPerMinute: 132,
            wordsPerMinute: 54,
            backspacesPerMinute: 6,
            buckets: (0..<TypingMetricsStore.bucketCount).map {
                if $0 % 5 == 0 || $0 > 20 {
                    return TypingMetricsBucket(strokes: 0, backspaces: 0, isFuture: $0 > 20)
                }
                return TypingMetricsBucket(strokes: ($0 % 6) + 1, backspaces: $0 % 9 == 0 ? 1 : 0)
            },
            scrollProgress: 0.35
        )

        let bitmap = try render(view)
        let metrics = PixelMetrics(bitmap: bitmap)

        XCTAssertGreaterThan(metrics.nonTransparentPixels, 50_000)
        XCTAssertLessThan(metrics.contentBounds.width, 880)
        XCTAssertLessThan(metrics.contentBounds.height, 340)

        let screenshotURL = try writeScreenshot(bitmap, name: "ProbeHUD-separated-color-themes.png")
        let attachment = XCTAttachment(contentsOfFile: screenshotURL)
        attachment.name = "ProbeHUD-separated-color-themes"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testKeyboardHUDTinyDanceLabelRenderDoesNotCrash() throws {
        let labels = (0..<VoyagerLayout.keyCount).map { index in
            if index == 24 {
                return KeyLabel(
                    primary: "When held Left shift",
                    secondary: "When double-tapped Tab",
                    raw: "TD(LSFT_TAB)",
                    role: .modTap
                )
            }
            return KeyLabel(primary: "", raw: "KC_NO", role: .noOp)
        }
        let view = KeyboardHUDView(frame: NSRect(x: 0, y: 0, width: 96, height: 40))
        view.keymap = LayeredKeymap.voyagerDefault(layers: [labels])
        view.activeLayer = 0
        view.pressedKeys = [24]
        view.showsHeatmap = false
        view.usesSymbolicKeyLabels = true

        let bitmap = try render(view)
        let metrics = PixelMetrics(bitmap: bitmap)

        XCTAssertEqual(bitmap.pixelsWide, 96)
        XCTAssertEqual(bitmap.pixelsHigh, 40)
        XCTAssertGreaterThan(metrics.nonTransparentPixels, 0)
    }

    private func render(_ view: KeyboardHUDView) throws -> NSBitmapImageRep {
        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(view.bounds.width),
                pixelsHigh: Int(view.bounds.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bitmapFormat: [.alphaFirst],
                bytesPerRow: 0,
                bitsPerPixel: 32
            ),
            let context = NSGraphicsContext(bitmapImageRep: bitmap)
        else {
            throw ScreenshotTestError.renderContextUnavailable
        }

        bitmap.size = view.bounds.size
        view.layoutSubtreeIfNeeded()

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        view.displayIgnoringOpacity(view.bounds, in: context)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        return bitmap
    }

    private func writeScreenshot(_ bitmap: NSBitmapImageRep, name: String) throws -> URL {
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw ScreenshotTestError.pngEncodingFailed
        }

        let directory = try Self.repoRoot()
            .appendingPathComponent(".derivedData", isDirectory: true)
            .appendingPathComponent("TestScreenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent(name)
        try png.write(to: url, options: .atomic)
        return url
    }

    private static func sampleKeymap() throws -> LayeredKeymap {
        try SyntheticKeymapSource.layeredKeymap()
    }

    private static func repoRoot() throws -> URL {
        var cursor = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while cursor.path != "/" {
            if FileManager.default.fileExists(atPath: cursor.appendingPathComponent("project.yml").path) {
                return cursor
            }
            cursor.deleteLastPathComponent()
        }
        throw ScreenshotTestError.repoRootUnavailable
    }
}

private func nonTransparentPixels(in rect: CGRect, bitmap: NSBitmapImageRep) -> Int {
    let minX = max(0, Int(rect.minX))
    let maxX = min(bitmap.pixelsWide - 1, Int(rect.maxX))
    let minY = max(0, Int(rect.minY))
    let maxY = min(bitmap.pixelsHigh - 1, Int(rect.maxY))
    var count = 0

    for x in minX...maxX {
        for y in minY...maxY {
            guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                continue
            }
            if color.alphaComponent > 0.02 {
                count += 1
            }
        }
    }
    return count
}

private struct PixelMetrics {
    let nonTransparentPixels: Int
    let transparentPixels: Int
    let bluePixels: Int
    let heatPixels: Int
    let contentBounds: CGRect

    init(bitmap: NSBitmapImageRep) {
        var nonTransparentPixels = 0
        var transparentPixels = 0
        var bluePixels = 0
        var heatPixels = 0
        var minX = bitmap.pixelsWide
        var minY = bitmap.pixelsHigh
        var maxX = 0
        var maxY = 0

        for x in 0..<bitmap.pixelsWide {
            for y in 0..<bitmap.pixelsHigh {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }

                if color.alphaComponent > 0.02 {
                    nonTransparentPixels += 1
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                } else {
                    transparentPixels += 1
                }

                if color.alphaComponent > 0.20,
                    color.blueComponent > 0.70,
                    color.redComponent < 0.35
                {
                    bluePixels += 1
                }

                if color.alphaComponent > 0.12,
                    color.redComponent > 0.60,
                    color.greenComponent < 0.55,
                    color.blueComponent < 0.40
                {
                    heatPixels += 1
                }
            }
        }

        self.nonTransparentPixels = nonTransparentPixels
        self.transparentPixels = transparentPixels
        self.bluePixels = bluePixels
        self.heatPixels = heatPixels
        self.contentBounds = CGRect(
            x: minX,
            y: minY,
            width: max(0, maxX - minX + 1),
            height: max(0, maxY - minY + 1)
        )
    }
}

private enum ScreenshotTestError: Error {
    case renderContextUnavailable
    case pngEncodingFailed
    case repoRootUnavailable
}
