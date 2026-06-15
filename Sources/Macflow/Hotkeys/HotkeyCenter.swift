import Carbon.HIToolbox
import Foundation

/// Thin layer over Carbon's global hotkey API (`RegisterEventHotKey`).
///
/// We chose Carbon over an external dependency because:
///   • it is the API that actually registers global hotkeys on macOS;
///   • zero dependencies = smaller binary and faster build;
///   • the callback runs on the main run loop, so overhead is zero when idle.
///
/// A single `EventHandler` dispatches all hotkeys via an incremental id.
final class HotkeyCenter {

    /// Singleton — the global C handler needs a stable access point.
    nonisolated(unsafe) static let shared = HotkeyCenter()

    private var handlers: [UInt32: @MainActor () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    private init() { installHandler() }

    /// Registers a global hotkey. The action runs on the main actor.
    @discardableResult
    func register(_ hotkey: Hotkey, action: @escaping @MainActor () -> Void) -> Bool {
        let id = nextID
        nextID += 1

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )

        guard status == noErr, let ref else { return false }
        handlers[id] = action
        refs[id] = ref
        return true
    }

    /// Removes all registered hotkeys (used during config hot-reload).
    func unregisterAll() {
        for ref in refs.values { UnregisterEventHotKey(ref) }
        refs.removeAll()
        handlers.removeAll()
        // We don't reset `nextID`: per-session unique ids avoid collisions on re-registration.
    }

    // MARK: - Internals

    /// A 4-char 'MCFL' signature to identify our hotkeys.
    private static let signature: OSType = {
        let chars = "MCFL".utf8
        return chars.reduce(OSType(0)) { ($0 << 8) + OSType($1) }
    }()

    /// Dispatches the key event to the matching action. Runs on the main thread.
    fileprivate func handle(id: UInt32) {
        // `handlers` is touched only on the main thread (registration and this
        // dispatcher callback). We copy the action into a local so we don't capture
        // `self` in the main-actor-isolated closure.
        guard let action = handlers[id] else { return }
        MainActor.assumeIsolated {
            action()
        }
    }

    private func installHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, _ -> OSStatus in
                guard let event else { return OSStatus(eventNotHandledErr) }
                var hkID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                guard status == noErr else { return status }
                HotkeyCenter.shared.handle(id: hkID.id)
                return noErr
            },
            1,
            &spec,
            nil,
            &eventHandler
        )
    }
}
