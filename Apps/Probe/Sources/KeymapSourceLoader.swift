import Foundation
import ProbeCore

enum KeymapSourceLoader {
    static func load() -> LayeredKeymap {
        guard let keymap = loadImportedKeymap() else {
            return LayeredKeymap.voyagerDefault(layers: [])
        }
        return keymap
    }

    static var hasUsableImportedKeymap: Bool {
        loadImportedKeymap() != nil
    }

    static func importKeymap(at url: URL) throws -> LayeredKeymap {
        try KeymapArchiveImporter.importKeymap(at: url, destinationURL: importedKeymapURL())
    }

    private static func loadImportedKeymap() -> LayeredKeymap? {
        let url = importedKeymapURL()
        guard let source = try? String(contentsOf: url, encoding: .utf8),
            let layers = try? KeymapParser.parse(source)
        else {
            return nil
        }
        return LayeredKeymap.voyagerDefault(layers: layers)
    }

    private static func importedKeymapURL() -> URL {
        appSupportBase()
            .appendingPathComponent("Probe", isDirectory: true)
            .appendingPathComponent("ImportedKeymap.c")
    }

    private static func appSupportBase() -> URL {
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base
    }
}
