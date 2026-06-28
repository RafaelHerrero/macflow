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
    ///
    /// We always go through `openApplication`, even when the app is already
    /// running. This mirrors clicking the app's Dock icon: it focuses the app AND
    /// reopens a window if none is open. Using `NSRunningApplication.activate()`
    /// alone would only bring a windowless app forward (e.g. one whose window you
    /// closed with Cmd-W), showing nothing — which is why it "didn't open".
    func activate(_ identifier: String) {
        let running = runningApplication(matching: identifier)
        guard let url = running?.bundleURL ?? resolveURL(for: identifier) else {
            Log.info("activate('\(identifier)'): no .app found to open")
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        // LaunchServices invokes this completion handler on a background queue
        // (com.apple.launchservices.open-queue), NOT the main thread. It must be a
        // `@Sendable`, non-isolated closure: if it inherited `AppSwitcher`'s
        // `@MainActor` isolation, the Swift 6 runtime would assert it is running on
        // the main executor, fail the check off-main, and trap (SIGTRAP) — crashing
        // the app on every app-switch shortcut. We capture only Sendable values and
        // call the non-isolated `Log.info`, so no main-actor hop is needed.
        let fallbackName = url.lastPathComponent
        let completion: @Sendable (NSRunningApplication?, Error?) -> Void = { app, error in
            if let error {
                Log.info("activate('\(identifier)'): open failed — \(error.localizedDescription)")
            } else {
                Log.info("activate('\(identifier)'): opened \(app?.localizedName ?? fallbackName)")
            }
        }
        NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: completion)
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

    // MARK: - Resolve app URL

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
