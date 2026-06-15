import Foundation

/// Centralizes the configuration lifecycle:
///   • locates/creates `~/.config/macflow/config.toml`;
///   • loads and parses it;
///   • watches the file and reloads with debounce (hot-reload);
///   • notifies interested parties via `onReload`.
@MainActor
final class ConfigManager {

    /// Path of the configuration directory: `~/.config/macflow`.
    static var directory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/macflow", isDirectory: true)
    }

    /// Path of the configuration file.
    static var configFile: URL {
        directory.appendingPathComponent("config.toml")
    }

    /// Currently loaded configuration.
    private(set) var current: Config = .default

    /// Fired whenever the config is (re)loaded, on the main actor.
    var onReload: ((Config) -> Void)?

    private var watcher: FileWatcher?
    private var debounce: DispatchWorkItem?

    /// Loads the initial configuration and starts watching the file.
    func start() {
        ensureConfigExists()
        reloadNow()

        let watcher = FileWatcher(url: Self.configFile) { [weak self] in
            // The watcher runs on its own queue; we hop back to the main actor.
            Task { @MainActor in self?.scheduleReload() }
        }
        watcher.start()
        self.watcher = watcher
    }

    /// Reloads immediately (used by the "Reload" menu).
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

    /// Reloads with a 150ms debounce to avoid multiple save events.
    private func scheduleReload() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.reloadNow() }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    /// Creates the directory and an initial config from the template, if needed.
    private func ensureConfigExists() {
        let fm = FileManager.default
        try? fm.createDirectory(at: Self.directory, withIntermediateDirectories: true)

        guard !fm.fileExists(atPath: Self.configFile.path) else { return }
        try? DefaultConfig.contents.write(to: Self.configFile, atomically: true, encoding: .utf8)
    }
}
