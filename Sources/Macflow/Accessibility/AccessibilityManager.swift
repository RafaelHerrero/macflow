import ApplicationServices
import AppKit

/// Utilitários para checar e solicitar a permissão de Acessibilidade, necessária
/// para a Accessibility API mover/redimensionar janelas de outros apps.
@MainActor
enum AccessibilityManager {

    /// Garante que o prompt do sistema apareça no máximo uma vez por sessão.
    /// Sem isso, cada atalho de janela acionado sem permissão dispararia um novo prompt.
    private static var hasPrompted = false

    /// `true` se o app já tem permissão de acessibilidade.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Solicita a permissão exibindo o prompt do sistema (caso ainda não concedida).
    /// Por padrão, prompta só uma vez por sessão; use `force: true` (ex.: pelo menu)
    /// para reabrir o prompt sob demanda.
    static func requestIfNeeded(force: Bool = false) {
        guard force || !hasPrompted else { return }
        hasPrompted = true
        // Valor literal da constante `kAXTrustedCheckOptionPrompt`. Usamos a string
        // direta para evitar referenciar o global C (não concurrency-safe no Swift 6).
        let key = "AXTrustedCheckOptionPrompt"
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Abre o painel de Acessibilidade nas Preferências do Sistema.
    static func openSettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
