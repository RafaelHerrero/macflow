import AppKit

/// Abre ou foca aplicativos a partir de um identificador (nome ou bundle id).
///
/// Estratégia:
///   1. Se o app já está rodando → traz para frente.
///   2. Senão → procura o `.app` nas pastas de Applications e abre.
///   3. Como fallback → resolve por bundle id via Launch Services.
@MainActor
final class AppSwitcher {

    /// Diretórios padrão onde procurar bundles `.app`, em ordem de prioridade.
    private static let searchPaths = [
        "/Applications",
        "\(NSHomeDirectory())/Applications",
        "/System/Applications",
        "/Applications/Utilities",
        "/System/Applications/Utilities"
    ]

    /// Abre ou foca o app identificado por `identifier` (nome ou bundle id).
    func activate(_ identifier: String) {
        if let running = runningApplication(matching: identifier) {
            running.activate(options: [.activateAllWindows])
            return
        }
        launch(identifier)
    }

    // MARK: - Localizar app em execução

    private func runningApplication(matching identifier: String) -> NSRunningApplication? {
        let apps = NSWorkspace.shared.runningApplications

        // Por bundle id (case-insensitive).
        if let match = apps.first(where: {
            $0.bundleIdentifier?.caseInsensitiveCompare(identifier) == .orderedSame
        }) {
            return match
        }
        // Por nome localizado.
        return apps.first {
            $0.localizedName?.caseInsensitiveCompare(identifier) == .orderedSame
        }
    }

    // MARK: - Lançar app

    private func launch(_ identifier: String) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        if let url = resolveURL(for: identifier) {
            NSWorkspace.shared.openApplication(at: url, configuration: config)
        }
    }

    /// Resolve a URL do bundle `.app`: primeiro procurando por nome nas pastas de
    /// Applications, depois caindo para o Launch Services por bundle id.
    private func resolveURL(for identifier: String) -> URL? {
        let fm = FileManager.default

        // 1. Busca por nome de arquivo "<identifier>.app" nas pastas conhecidas.
        let appName = identifier.hasSuffix(".app") ? identifier : "\(identifier).app"
        for base in Self.searchPaths {
            let candidate = URL(fileURLWithPath: base).appendingPathComponent(appName)
            if fm.fileExists(atPath: candidate.path) { return candidate }
        }

        // 2. Fallback: trata o identificador como bundle id.
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
            return url
        }

        // 3. Último recurso: deixa o Launch Services resolver pelo nome.
        return NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.\(identifier.lowercased())"
        )
    }
}
