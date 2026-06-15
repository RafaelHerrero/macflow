import Foundation

/// Watches a single file and fires a callback when it changes.
///
/// Uses `DispatchSource` over the file descriptor. Since many editors save
/// atomically (write to a temp file and rename over the original), we handle
/// `.delete`/`.rename` events by re-arming the watcher on the new file. This
/// ensures reliable hot-reload with vim, VS Code, etc.
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

    /// Starts watching. Idempotent.
    func start() {
        queue.async { [weak self] in self?.arm() }
    }

    /// Stops watching and releases resources.
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
            // Atomic save: the original file disappears — re-arm on the new inode.
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
