import AppKit

/// Controla o ícone e o menu na barra de status. Mantém a UI mínima — o Macflow é
/// configurado por arquivo, então o menu serve só para utilidades rápidas.
@MainActor
final class MenuBarController {

    private let statusItem: NSStatusItem
    private let onReload: () -> Void

    init(onReload: @escaping () -> Void) {
        self.onReload = onReload
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton()
        buildMenu()
    }

    /// Reconstrói o menu (ex.: para atualizar o status de acessibilidade).
    func refresh() {
        buildMenu()
    }

    // MARK: - UI

    private func configureButton() {
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.3.group",
                accessibilityDescription: "Macflow"
            )
            button.image?.isTemplate = true
        }
    }

    private func buildMenu() {
        let menu = NSMenu()

        let header = NSMenuItem(title: "Macflow", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        // Status de acessibilidade
        let trusted = AccessibilityManager.isTrusted
        let accessibilityTitle = trusted
            ? "Acessibilidade: concedida"
            : "Acessibilidade: conceder permissão…"
        let accessibilityItem = NSMenuItem(
            title: accessibilityTitle,
            action: trusted ? nil : #selector(grantAccessibility),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        accessibilityItem.isEnabled = !trusted
        menu.addItem(accessibilityItem)
        menu.addItem(.separator())

        addItem(to: menu, title: "Recarregar configuração", action: #selector(reload), key: "r")
        addItem(to: menu, title: "Editar config.toml", action: #selector(editConfig), key: "e")
        addItem(to: menu, title: "Abrir pasta de configuração", action: #selector(openConfigFolder), key: "")
        menu.addItem(.separator())
        addItem(to: menu, title: "Sair", action: #selector(quit), key: "q")

        statusItem.menu = menu
    }

    private func addItem(to menu: NSMenu, title: String, action: Selector, key: String) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    // MARK: - Ações do menu

    @objc private func grantAccessibility() {
        AccessibilityManager.requestIfNeeded(force: true)
        AccessibilityManager.openSettings()
    }

    @objc private func reload() {
        onReload()
        refresh()
    }

    @objc private func editConfig() {
        NSWorkspace.shared.open(ConfigManager.configFile)
    }

    @objc private func openConfigFolder() {
        NSWorkspace.shared.open(ConfigManager.directory)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
