import AppKit

/// Orquestra os módulos: carrega config, registra hotkeys e mantém o menu bar.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let configManager = ConfigManager()
    private let hotkeyBinder = HotkeyBinder()
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Pede acessibilidade logo de início (necessária para window management).
        AccessibilityManager.requestIfNeeded()

        menuBar = MenuBarController(onReload: { [weak self] in
            self?.configManager.reloadNow()
        })

        // Toda vez que a config (re)carrega, religamos os atalhos.
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
