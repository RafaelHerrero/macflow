import AppKit

/// Opens or focuses applications from an identifier (name or bundle id).
///
/// Strategy:
///   1. If the app is already running → bring it to the front.
///   2. Otherwise → look for the `.app` in the Applications folders and open it.
///   3. As a fallback → resolve by bundle id via Launch Services.
@MainActor
final class AppSwitcher {

    /// Default directories to search for `.app` bundles, in priority order.
    private static let searchPaths = [
        "/Applications",
        "\(NSHomeDirectory())/Applications",
        "/System/Applications",
        "/Applications/Utilities",
        "/System/Applications/Utilities"
    ]

    /// Opens or focuses the app identified by `identifier` (name or bundle id).
    func activate(_ identifier: String) {
        if let running = runningApplication(matching: identifier) {
            running.activate(options: [.activateAllWindows])
            return
        }
        launch(identifier)
    }

    // MARK: - Locate running app

    private func runningApplication(matching identifier: String) -> NSRunningApplication? {
        let apps = NSWorkspace.shared.runningApplications

        // By bundle id (case-insensitive).
        if let match = apps.first(where: {
            $0.bundleIdentifier?.caseInsensitiveCompare(identifier) == .orderedSame
        }) {
            return match
        }
        // By localized name.
        return apps.first {
            $0.localizedName?.caseInsensitiveCompare(identifier) == .orderedSame
        }
    }

    // MARK: - Launch app

    private func launch(_ identifier: String) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        if let url = resolveURL(for: identifier) {
            NSWorkspace.shared.openApplication(at: url, configuration: config)
        }
    }

    /// Resolves the `.app` bundle URL: first searching by name in the Applications
    /// folders, then falling back to Launch Services by bundle id.
    private func resolveURL(for identifier: String) -> URL? {
        let fm = FileManager.default

        // 1. Search by file name "<identifier>.app" in the known folders.
        let appName = identifier.hasSuffix(".app") ? identifier : "\(identifier).app"
        for base in Self.searchPaths {
            let candidate = URL(fileURLWithPath: base).appendingPathComponent(appName)
            if fm.fileExists(atPath: candidate.path) { return candidate }
        }

        // 2. Fallback: treat the identifier as a bundle id.
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
            return url
        }

        // 3. Last resort: let Launch Services resolve by name.
        return NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.\(identifier.lowercased())"
        )
    }
}
