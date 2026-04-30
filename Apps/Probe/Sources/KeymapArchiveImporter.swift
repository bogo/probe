import Foundation
import ProbeCore

enum KeymapArchiveImportError: LocalizedError {
    case unsupportedFile
    case unzipFailed(String)
    case noUsableKeymap

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            "Drop a keymap.c file or a .zip archive containing QMK source files."
        case .unzipFailed(let output):
            "Could not unpack the archive. \(output)"
        case .noUsableKeymap:
            "The file did not contain a parseable Voyager keymap."
        }
    }
}

enum KeymapArchiveImporter {
    static func importKeymap(at url: URL, destinationURL: URL) throws -> LayeredKeymap {
        if url.pathExtension.lowercased() == "zip" {
            return try importArchive(at: url, destinationURL: destinationURL)
        }
        return try importKeymapFile(at: url, destinationURL: destinationURL)
    }

    static func importArchive(at archiveURL: URL, destinationURL: URL) throws -> LayeredKeymap {
        guard archiveURL.pathExtension.lowercased() == "zip" else {
            throw KeymapArchiveImportError.unsupportedFile
        }

        let extractionURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Probe-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: extractionURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: extractionURL) }

        try unzip(archiveURL, to: extractionURL)
        let candidates = findKeymapCandidates(in: extractionURL)

        for candidate in candidates {
            guard let source = try? String(contentsOf: candidate, encoding: .utf8) else {
                continue
            }
            do {
                return try importSource(source, destinationURL: destinationURL)
            } catch KeymapArchiveImportError.noUsableKeymap {
                continue
            }
        }

        throw KeymapArchiveImportError.noUsableKeymap
    }

    private static func importKeymapFile(at url: URL, destinationURL: URL) throws -> LayeredKeymap {
        guard isKeymapSourceFile(url) else {
            throw KeymapArchiveImportError.unsupportedFile
        }

        let source = try String(contentsOf: url, encoding: .utf8)
        return try importSource(source, destinationURL: destinationURL)
    }

    private static func importSource(_ source: String, destinationURL: URL) throws -> LayeredKeymap {
        guard let layers = try? KeymapParser.parse(source) else {
            throw KeymapArchiveImportError.noUsableKeymap
        }
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try source.write(to: destinationURL, atomically: true, encoding: .utf8)
        return LayeredKeymap.voyagerDefault(layers: layers)
    }

    private static func isKeymapSourceFile(_ url: URL) -> Bool {
        let filename = url.lastPathComponent.lowercased()
        let pathExtension = url.pathExtension.lowercased()
        return filename == "keymap.c" || pathExtension == "c" || pathExtension == "qmk"
    }

    private static func unzip(_ archiveURL: URL, to destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archiveURL.path, destinationURL.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            throw KeymapArchiveImportError.unzipFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static func findKeymapCandidates(in root: URL) -> [URL] {
        guard
            let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        var candidates: [URL] = []
        for case let url as URL in enumerator where url.lastPathComponent == "keymap.c" {
            candidates.append(url)
        }

        return candidates.sorted { lhs, rhs in
            score(lhs) > score(rhs)
        }
    }

    private static func score(_ url: URL) -> Int {
        let path = url.path.lowercased()
        var score = 0
        if path.contains("zsa") { score += 8 }
        if path.contains("voyager") { score += 8 }
        if path.contains("keymap") { score += 2 }
        return score
    }
}
