import AppKit

/// Orchestrates the modules: loads config, registers hotkeys, and maintains the menu bar.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let configManager = ConfigManager()
    private let hotkeyBinder = HotkeyBinder()
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request accessibility right away (required for window management).
        AccessibilityManager.requestIfNeeded()

        menuBar = MenuBarController(onReload: { [weak self] in
            self?.configManager.reloadNow()
        })

        // Every time the config (re)loads, we rebind the shortcuts.
        configManager.onReload = { [weak self] config in
            self?.hotkeyBinder.bind(config: config)
            self?.menuBar?.refresh()
        }
        configManager.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyCenter.shared.unregisterAll()
    }
}
