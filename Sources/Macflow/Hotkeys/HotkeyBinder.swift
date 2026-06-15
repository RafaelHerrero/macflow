import Foundation

/// Translates a `Config` into concrete global hotkeys, wiring each one to the right
/// action (focus an app or move a window). Reapplicable on every config hot-reload.
@MainActor
final class HotkeyBinder {

    private let windowManager = WindowManager()
    private let appSwitcher = AppSwitcher()

    /// Rebuilds all hotkeys from the provided configuration.
    func bind(config: Config) {
        HotkeyCenter.shared.unregisterAll()
        bindApps(config)
        bindWindows(config)
    }

    // MARK: - Apps (modifier + key → focus/open app)

    private func bindApps(_ config: Config) {
        let modifiers = HotkeyParser.parseModifiers(config.appModifier)

        for (key, appIdentifier) in config.apps {
            // The app key is usually a digit; we reuse the parser's keyMap by
            // building a "<modifier>+<key>" shortcut.
            guard let hotkey = HotkeyParser.parse("\(config.appModifier)+\(key)") ?? hotkeyFromKey(key, modifiers: modifiers)
            else { continue }

            HotkeyCenter.shared.register(hotkey) { [weak self] in
                self?.appSwitcher.activate(appIdentifier)
            }
        }
    }

    /// Builds a `Hotkey` from a standalone key + modifier mask.
    private func hotkeyFromKey(_ key: String, modifiers: UInt32) -> Hotkey? {
        guard let base = HotkeyParser.parse(key) else { return nil }
        return Hotkey(keyCode: base.keyCode, modifiers: modifiers)
    }

    // MARK: - Windows (hotkey → window management action)

    private func bindWindows(_ config: Config) {
        for (actionName, shortcut) in config.windows {
            guard let action = WindowAction(rawValue: actionName) else {
                Log.info("window: unknown action '\(actionName)' — ignored")
                continue
            }
            guard let hotkey = HotkeyParser.parse(shortcut) else {
                Log.info("window '\(actionName)': could not parse shortcut '\(shortcut)' — ignored")
                continue
            }

            let ok = HotkeyCenter.shared.register(hotkey) { [weak self] in
                self?.windowManager.perform(action)
            }
            if ok {
                Log.info("window '\(actionName)' → '\(shortcut)' registered")
            } else {
                Log.info("window '\(actionName)' → '\(shortcut)' FAILED to register (conflict with another app?)")
            }
        }
    }
}
