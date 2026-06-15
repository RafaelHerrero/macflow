import ApplicationServices
import AppKit

/// Utilities to check and request the Accessibility permission, required
/// for the Accessibility API to move/resize windows of other apps.
@MainActor
enum AccessibilityManager {

    /// Ensures the system prompt appears at most once per session.
    /// Without this, every window shortcut triggered without permission would fire a new prompt.
    private static var hasPrompted = false

    /// `true` if the app already has the accessibility permission.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Requests the permission by showing the system prompt (if not yet granted).
    /// By default it prompts only once per session; use `force: true` (e.g. from the menu)
    /// to reopen the prompt on demand.
    static func requestIfNeeded(force: Bool = false) {
        guard force || !hasPrompted else { return }
        hasPrompted = true
        // Literal value of the `kAXTrustedCheckOptionPrompt` constant. We use the
        // string directly to avoid referencing the C global (not concurrency-safe in Swift 6).
        let key = "AXTrustedCheckOptionPrompt"
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Opens the Accessibility pane in System Settings.
    static func openSettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
