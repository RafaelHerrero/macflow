import Foundation

/// Centraliza o ciclo de vida da configuração:
///   • localiza/cria `~/.config/macflow/config.toml`;
///   • carrega e faz parse;
///   • observa o arquivo e recarrega com debounce (hot-reload);
///   • notifica interessados via `onReload`.
@MainActor
final class ConfigManager {

    /// Caminho do diretório de configuração: `~/.config/macflow`.
    static var directory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/macflow", isDirectory: true)
    }

    /// Caminho do arquivo de configuração.
    static var configFile: URL {
        directory.appendingPathComponent("config.toml")
    }

    /// Configuração atualmente carregada.
    private(set) var current: Config = .default

    /// Disparado sempre que a config é (re)carregada, na main actor.
    var onReload: ((Config) -> Void)?

    private var watcher: FileWatcher?
    private var debounce: DispatchWorkItem?

    /// Carrega a configuração inicial e começa a observar o arquivo.
    func start() {
        ensureConfigExists()
        reloadNow()

        let watcher = FileWatcher(url: Self.configFile) { [weak self] in
            // O watcher roda em fila própria; voltamos para a main actor.
            Task { @MainActor in self?.scheduleReload() }
        }
        watcher.start()
        self.watcher = watcher
    }

    /// Recarrega imediatamente (usado pelo menu "Reload").
    func reloadNow() {
        let document: TOMLParser.Document
        if let text = try? String(contentsOf: Self.configFile, encoding: .utf8) {
            document = TOMLParser.parse(text)
        } else {
            document = [:]
        }
        current = Config.from(document: document)
        onReload?(current)
    }

    // MARK: - Internals

    /// Recarrega com debounce de 150ms para evitar múltiplos eventos de save.
    private func scheduleReload() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.reloadNow() }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    /// Cria o diretório e um config inicial a partir do template, se necessário.
    private func ensureConfigExists() {
        let fm = FileManager.default
        try? fm.createDirectory(at: Self.directory, withIntermediateDirectories: true)

        guard !fm.fileExists(atPath: Self.configFile.path) else { return }
        try? DefaultConfig.contents.write(to: Self.configFile, atomically: true, encoding: .utf8)
    }
}
