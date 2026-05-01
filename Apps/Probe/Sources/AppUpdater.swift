import AppKit
import Sparkle

@MainActor
final class AppUpdater: NSObject {
    private let updaterController: SPUStandardUpdaterController?

    override init() {
        if Self.hasRequiredConfiguration {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        } else {
            updaterController = nil
        }
        super.init()
    }

    func checkForUpdatesMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Check for Updates...", action: nil, keyEquivalent: "")
        if let updaterController {
            item.target = updaterController
            item.action = #selector(SPUStandardUpdaterController.checkForUpdates(_:))
        } else {
            item.target = self
            item.action = #selector(showMissingConfigurationAlert(_:))
        }
        return item
    }

    @objc private func showMissingConfigurationAlert(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Updates are not configured yet"
        alert.informativeText = """
            Probe has Sparkle wired in, but it needs a Sparkle public EdDSA key before update checks can run. Generate one with Sparkle's generate_keys tool, keep the private key in your Keychain, and set SPARKLE_PUBLIC_ED_KEY for release builds.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static var hasRequiredConfiguration: Bool {
        guard
            let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            URL(string: feedURL) != nil,
            let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        else {
            return false
        }

        return !feedURL.isEmpty
            && !feedURL.contains("$(")
            && !publicKey.isEmpty
            && !publicKey.contains("$(")
    }
}
