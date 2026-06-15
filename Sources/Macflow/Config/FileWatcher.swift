import Foundation

/// Observa um único arquivo e dispara um callback quando ele muda.
///
/// Usa `DispatchSource` sobre o file descriptor. Como muitos editores salvam de
/// forma atômica (escrevem em um temp e renomeiam por cima), tratamos eventos de
/// `.delete`/`.rename` re-armando o watcher no novo arquivo. Isso garante
/// hot-reload confiável com vim, VS Code, etc.
final class FileWatcher: @unchecked Sendable {

    private let url: URL
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "com.macflow.filewatcher")

    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1

    init(url: URL, onChange: @escaping @Sendable () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    /// Começa a observar. Idempotente.
    func start() {
        queue.async { [weak self] in self?.arm() }
    }

    /// Para de observar e libera recursos.
    func stop() {
        queue.async { [weak self] in self?.disarm() }
    }

    deinit { disarm() }

    // MARK: - Internals

    private func arm() {
        disarm()

        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .extend],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = self.source?.data ?? []
            self.onChange()
            // Save atômico: o arquivo original some — re-arma no novo inode.
            if flags.contains(.delete) || flags.contains(.rename) {
                self.queue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.arm()
                }
            }
        }

        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        self.source = source
        source.resume()
    }

    private func disarm() {
        source?.cancel()
        source = nil
    }
}
