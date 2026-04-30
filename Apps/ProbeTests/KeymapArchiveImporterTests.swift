import ProbeCore
import XCTest

final class KeymapArchiveImporterTests: XCTestCase {
    func testImportsKeymapFromZippedSourceExport() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProbeArchiveImport-\(UUID().uuidString)", isDirectory: true)
        let sourceRoot = root.appendingPathComponent("qmk_export", isDirectory: true)
        let keymapDirectory = sourceRoot.appendingPathComponent("keyboard_source", isDirectory: true)
        try FileManager.default.createDirectory(at: keymapDirectory, withIntermediateDirectories: true)

        let keymapSource = SyntheticKeymapSource.source
        try keymapSource.write(to: keymapDirectory.appendingPathComponent("keymap.c"), atomically: true, encoding: .utf8)

        let archiveURL = root.appendingPathComponent("qmk_export.zip")
        try zip(sourceRoot, to: archiveURL)

        let destinationURL =
            root
            .appendingPathComponent("ApplicationSupport", isDirectory: true)
            .appendingPathComponent("ImportedKeymap.c")
        let keymap = try KeymapArchiveImporter.importArchive(at: archiveURL, destinationURL: destinationURL)

        XCTAssertEqual(keymap.layers.count, 4)
        XCTAssertEqual(keymap.layers.first?.count, VoyagerLayout.keyCount)
        XCTAssertEqual(keymap.label(forKeyID: 0, onLayer: 0).primary, "Esc")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
    }

    func testImportsDirectKeymapFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProbeKeymapImport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let sourceURL = root.appendingPathComponent("keymap.c")
        try SyntheticKeymapSource.source.write(to: sourceURL, atomically: true, encoding: .utf8)

        let destinationURL = root.appendingPathComponent("ImportedKeymap.c")
        let keymap = try KeymapArchiveImporter.importKeymap(at: sourceURL, destinationURL: destinationURL)

        XCTAssertEqual(keymap.layers.count, 4)
        XCTAssertEqual(keymap.label(forKeyID: 49, onLayer: 0).primary, "Space")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
    }

    private func zip(_ directory: URL, to archiveURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", directory.path, archiveURL.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            XCTFail("ditto failed: \(output)")
        }
    }

}
