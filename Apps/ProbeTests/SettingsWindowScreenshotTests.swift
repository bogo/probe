import AppKit
import ProbeCore
import XCTest

@MainActor
final class SettingsWindowScreenshotTests: XCTestCase {
    func testSettingsDisplaySnapshotRendersSystemStylePane() throws {
        let controller = try makeController()
        let bitmap = try render(controller)

        XCTAssertEqual(bitmap.pixelsWide, 900)
        XCTAssertEqual(bitmap.pixelsHigh, 620)
        XCTAssertGreaterThan(nonTransparentPixels(in: bitmap), 420_000)

        let screenshotURL = try writeScreenshot(bitmap, name: "ProbeSettings-display.png")
        let attachment = XCTAttachment(contentsOfFile: screenshotURL)
        attachment.name = "ProbeSettings-display"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSettingsDisplayWideSnapshotKeepsControlsNearRows() throws {
        let controller = try makeController()
        let bitmap = try render(controller, size: NSSize(width: 1200, height: 900))

        let glyphButton = try XCTUnwrap(
            findButton(title: "Use glyphs", in: try XCTUnwrap(controller.window?.contentView))
        )
        let glyphFrame = glyphButton.convert(glyphButton.bounds, to: controller.window?.contentView)
        XCTAssertGreaterThan(glyphFrame.minY, 600)
        XCTAssertEqual(bitmap.pixelsWide, 1200)
        XCTAssertEqual(bitmap.pixelsHigh, 900)
        XCTAssertGreaterThan(nonTransparentPixels(in: bitmap), 800_000)

        let screenshotURL = try writeScreenshot(bitmap, name: "ProbeSettings-display-wide.png")
        let attachment = XCTAttachment(contentsOfFile: screenshotURL)
        attachment.name = "ProbeSettings-display-wide"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSettingsKeyboardSnapshotRendersThemeControlsAndKeymapPreview() throws {
        let controller = try makeController()
        try selectSection("keyboard", in: controller)
        let bitmap = try render(controller)

        XCTAssertEqual(bitmap.pixelsWide, 900)
        XCTAssertEqual(bitmap.pixelsHigh, 620)
        XCTAssertGreaterThan(nonTransparentPixels(in: bitmap), 440_000)

        let screenshotURL = try writeScreenshot(bitmap, name: "ProbeSettings-keyboard-themes.png")
        let attachment = XCTAttachment(contentsOfFile: screenshotURL)
        attachment.name = "ProbeSettings-keyboard-themes"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSettingsKeyboardWideSnapshotKeepsThemesLeadingAligned() throws {
        let controller = try makeController()
        try selectSection("keyboard", in: controller)
        let bitmap = try render(controller, size: NSSize(width: 1200, height: 900))

        let probeButton = try XCTUnwrap(
            findButton(identifier: KeyboardColorTheme.probe.rawValue, in: try XCTUnwrap(controller.window?.contentView))
        )
        let signalButton = try XCTUnwrap(
            findButton(identifier: GraphColorTheme.signal.rawValue, in: try XCTUnwrap(controller.window?.contentView))
        )
        let probeFrame = probeButton.convert(probeButton.bounds, to: controller.window?.contentView)
        let signalFrame = signalButton.convert(signalButton.bounds, to: controller.window?.contentView)
        XCTAssertLessThan(probeFrame.minX, 450)
        XCTAssertLessThan(signalFrame.minX, 450)
        XCTAssertEqual(bitmap.pixelsWide, 1200)
        XCTAssertEqual(bitmap.pixelsHigh, 900)
        XCTAssertGreaterThan(nonTransparentPixels(in: bitmap), 800_000)

        let screenshotURL = try writeScreenshot(bitmap, name: "ProbeSettings-keyboard-themes-wide.png")
        let attachment = XCTAttachment(contentsOfFile: screenshotURL)
        attachment.name = "ProbeSettings-keyboard-themes-wide"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSettingsMenuBarSnapshotKeepsIconRowsLeadingAligned() throws {
        let controller = try makeController()
        try selectSection("menuBar", in: controller)
        let bitmap = try render(controller, size: NSSize(width: 1200, height: 620))

        let moduleButton = try XCTUnwrap(
            findButton(identifier: MenuBarIconChoice.moduleDish.rawValue, in: try XCTUnwrap(controller.window?.contentView))
        )
        let moduleButtonFrame = moduleButton.convert(moduleButton.bounds, to: controller.window?.contentView)
        XCTAssertLessThan(moduleButtonFrame.minX, 360)
        XCTAssertGreaterThan(moduleButtonFrame.minX, 220)
        XCTAssertEqual(bitmap.pixelsWide, 1200)
        XCTAssertEqual(bitmap.pixelsHigh, 620)
        XCTAssertGreaterThan(nonTransparentPixels(in: bitmap), 410_000)

        let screenshotURL = try writeScreenshot(bitmap, name: "ProbeSettings-menu-bar-wide.png")
        let attachment = XCTAttachment(contentsOfFile: screenshotURL)
        attachment.name = "ProbeSettings-menu-bar-wide"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func makeController() throws -> ProbeSettingsWindowController {
        let controller = ProbeSettingsWindowController(
            state: ProbeSettingsState(
                selectedIcon: .moduleDish,
                usesSymbolicKeyLabels: true,
                keyboardColorTheme: .aurora,
                heatmapColorTheme: .lagoon,
                graphColorTheme: .amber,
                scale: HUDScaleChoice.medium.value,
                opacity: HUDOpacityChoice.vivid.value,
                showsHeatmap: true,
                showsTypingStats: true,
                keymap: try SyntheticKeymapSource.layeredKeymap(),
                activeLayer: 0,
                hasUsableKeymap: true
            ),
            onIconSelected: { _ in },
            onSymbolicKeyLabelsChanged: { _ in },
            onKeyboardColorThemeChanged: { _ in },
            onHeatmapColorThemeChanged: { _ in },
            onGraphColorThemeChanged: { _ in },
            onScaleChanged: { _ in },
            onOpacityChanged: { _ in },
            onHeatmapVisibilityChanged: { _ in },
            onTypingStatsVisibilityChanged: { _ in },
            onImportKeymap: {},
            onImportKeymapAt: { _ in }
        )
        controller.window?.appearance = NSAppearance(named: .darkAqua)
        return controller
    }

    private func selectSection(_ identifier: String, in controller: ProbeSettingsWindowController) throws {
        guard let contentView = controller.window?.contentView,
            let button = findButton(identifier: identifier, in: contentView)
        else {
            throw SettingsScreenshotError.sectionUnavailable
        }

        button.performClick(nil)
        contentView.layoutSubtreeIfNeeded()
    }

    private func findButton(identifier: String, in view: NSView) -> NSButton? {
        if let button = view as? NSButton, button.identifier?.rawValue == identifier {
            return button
        }

        for subview in view.subviews {
            if let button = findButton(identifier: identifier, in: subview) {
                return button
            }
        }
        return nil
    }

    private func findButton(title: String, in view: NSView) -> NSButton? {
        if let button = view as? NSButton, button.title == title {
            return button
        }

        for subview in view.subviews {
            if let button = findButton(title: title, in: subview) {
                return button
            }
        }
        return nil
    }

    private func render(
        _ controller: ProbeSettingsWindowController,
        size: NSSize = NSSize(width: 900, height: 620)
    ) throws -> NSBitmapImageRep {
        guard let window = controller.window,
            let view = window.contentView
        else {
            throw SettingsScreenshotError.renderContextUnavailable
        }

        window.setFrame(NSRect(origin: .zero, size: size), display: false)
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()

        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(size.width),
                pixelsHigh: Int(size.height),
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
            throw SettingsScreenshotError.renderContextUnavailable
        }

        bitmap.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        view.displayIgnoringOpacity(view.bounds, in: context)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        return bitmap
    }

    private func writeScreenshot(_ bitmap: NSBitmapImageRep, name: String) throws -> URL {
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw SettingsScreenshotError.pngEncodingFailed
        }

        let directory = try Self.repoRoot()
            .appendingPathComponent(".derivedData", isDirectory: true)
            .appendingPathComponent("TestScreenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent(name)
        try png.write(to: url, options: .atomic)
        return url
    }

    private func nonTransparentPixels(in bitmap: NSBitmapImageRep) -> Int {
        var count = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                if color.alphaComponent > 0.02 {
                    count += 1
                }
            }
        }
        return count
    }

    private static func repoRoot() throws -> URL {
        var cursor = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while cursor.path != "/" {
            if FileManager.default.fileExists(atPath: cursor.appendingPathComponent("project.yml").path) {
                return cursor
            }
            cursor.deleteLastPathComponent()
        }
        throw SettingsScreenshotError.repoRootUnavailable
    }
}

private enum SettingsScreenshotError: Error {
    case pngEncodingFailed
    case renderContextUnavailable
    case repoRootUnavailable
    case sectionUnavailable
}
