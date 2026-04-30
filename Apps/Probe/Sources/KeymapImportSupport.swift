import Foundation
import UniformTypeIdentifiers

enum KeymapImportSupport {
    static let acceptedExtensions = Set(["zip", "c", "qmk"])

    static var panelContentTypes: [UTType] {
        [
            .zip,
            UTType(filenameExtension: "c") ?? .plainText,
            UTType(filenameExtension: "qmk") ?? .plainText
        ]
    }

    static func supports(_ url: URL) -> Bool {
        acceptedExtensions.contains(url.pathExtension.lowercased())
            || url.lastPathComponent.lowercased() == "keymap.c"
    }
}
