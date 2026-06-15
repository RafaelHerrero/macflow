import Carbon.HIToolbox
import Foundation

/// Camada fina sobre a API de hotkeys globais do Carbon (`RegisterEventHotKey`).
///
/// Escolhemos Carbon em vez de uma dependência externa porque:
///   • é a API que de fato registra atalhos globais no macOS;
///   • zero dependências = binário menor e build mais rápido;
///   • o callback roda na main run loop, então o overhead é nulo quando ocioso.
///
/// Um único `EventHandler` despacha todos os atalhos via um id incremental.
final class HotkeyCenter {

    /// Singleton — o handler C global precisa de um ponto de acesso estável.
    nonisolated(unsafe) static let shared = HotkeyCenter()

    private var handlers: [UInt32: @MainActor () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    private init() { installHandler() }

    /// Registra um atalho global. A ação roda na main actor.
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

    /// Remove todos os atalhos registrados (usado no hot-reload da config).
    func unregisterAll() {
        for ref in refs.values { UnregisterEventHotKey(ref) }
        refs.removeAll()
        handlers.removeAll()
        // Não reiniciamos `nextID`: ids únicos por sessão evitam colisões em re-registros.
    }

    // MARK: - Internals

    /// Assinatura de 4 chars 'MCFL' para identificar nossos hotkeys.
    private static let signature: OSType = {
        let chars = "MCFL".utf8
        return chars.reduce(OSType(0)) { ($0 << 8) + OSType($1) }
    }()

    /// Despacha o evento de tecla para a ação correspondente. Roda na main thread.
    fileprivate func handle(id: UInt32) {
        // `handlers` é tocado apenas na main thread (registro e este callback do
        // dispatcher). Copiamos a ação para um local para não capturar `self` na
        // closure isolada à main actor.
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
