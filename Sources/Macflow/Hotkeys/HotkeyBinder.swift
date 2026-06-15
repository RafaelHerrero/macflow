import Foundation

/// Traduz um `Config` em atalhos globais concretos, ligando cada um à ação certa
/// (focar app ou mover janela). Reaplicável a cada hot-reload da configuração.
@MainActor
final class HotkeyBinder {

    private let windowManager = WindowManager()
    private let appSwitcher = AppSwitcher()

    /// Reconstrói todos os atalhos a partir da configuração fornecida.
    func bind(config: Config) {
        HotkeyCenter.shared.unregisterAll()
        bindApps(config)
        bindWindows(config)
    }

    // MARK: - Apps (modificador + tecla → focar/abrir app)

    private func bindApps(_ config: Config) {
        let modifiers = HotkeyParser.parseModifiers(config.appModifier)

        for (key, appIdentifier) in config.apps {
            // A tecla do app costuma ser um dígito; reusamos o keyMap do parser
            // criando um atalho "<modificador>+<tecla>".
            guard let hotkey = HotkeyParser.parse("\(config.appModifier)+\(key)") ?? hotkeyFromKey(key, modifiers: modifiers)
            else { continue }

            HotkeyCenter.shared.register(hotkey) { [weak self] in
                self?.appSwitcher.activate(appIdentifier)
            }
        }
    }

    /// Constrói um `Hotkey` a partir de uma tecla isolada + máscara de modificadores.
    private func hotkeyFromKey(_ key: String, modifiers: UInt32) -> Hotkey? {
        guard let base = HotkeyParser.parse(key) else { return nil }
        return Hotkey(keyCode: base.keyCode, modifiers: modifiers)
    }

    // MARK: - Janelas (atalho → ação de window management)

    private func bindWindows(_ config: Config) {
        for (actionName, shortcut) in config.windows {
            guard let action = WindowAction(rawValue: actionName) else {
                Log.info("janela: ação desconhecida '\(actionName)' — ignorada")
                continue
            }
            guard let hotkey = HotkeyParser.parse(shortcut) else {
                Log.info("janela '\(actionName)': não consegui interpretar o atalho '\(shortcut)' — ignorado")
                continue
            }

            let ok = HotkeyCenter.shared.register(hotkey) { [weak self] in
                self?.windowManager.perform(action)
            }
            if ok {
                Log.info("janela '\(actionName)' → '\(shortcut)' registrada")
            } else {
                Log.info("janela '\(actionName)' → '\(shortcut)' FALHOU ao registrar (conflito com outro app?)")
            }
        }
    }
}
