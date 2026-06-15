import AppKit
import ApplicationServices

/// Wrapper sobre o `AXUIElement` da janela frontmost, escondendo a verbosidade da
/// Accessibility API por trás de uma interface com tipos do AppKit (`CGRect`).
///
/// IMPORTANTE: a Accessibility API usa coordenadas globais com origem no
/// **canto superior-esquerdo** da tela principal e eixo Y crescendo para baixo —
/// diferente do Cocoa (origem inferior-esquerda, Y para cima). A conversão fica
/// centralizada aqui e em `WindowManager`.
struct AXWindow {

    let element: AXUIElement

    /// Obtém a janela em foco do app frontmost. `nil` se não houver permissão de
    /// acessibilidade ou nenhuma janela focada.
    static func focused() -> AXWindow? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var windowRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &windowRef
        )
        guard status == .success, let windowRef else { return nil }
        // windowRef é um AXUIElement; a checagem de tipo é feita pela API.
        let window = windowRef as! AXUIElement
        return AXWindow(element: window)
    }

    /// Frame atual da janela em coordenadas AX (origem superior-esquerda).
    var axFrame: CGRect? {
        guard let position = copyValue(kAXPositionAttribute, type: .cgPoint, as: CGPoint.self),
              let size = copyValue(kAXSizeAttribute, type: .cgSize, as: CGSize.self)
        else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// Define posição e tamanho (em coordenadas AX). A posição é aplicada antes e
    /// depois do tamanho para acomodar apps que clampam dimensões à posição atual.
    func setAXFrame(_ frame: CGRect) {
        setPosition(frame.origin)
        setSize(frame.size)
        setPosition(frame.origin)
    }

    // MARK: - Leitura/escrita de atributos AX

    private func setPosition(_ point: CGPoint) {
        var p = point
        guard let value = AXValueCreate(.cgPoint, &p) else { return }
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }

    private func setSize(_ size: CGSize) {
        var s = size
        guard let value = AXValueCreate(.cgSize, &s) else { return }
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
    }

    private func copyValue<T>(_ attribute: String, type: AXValueType, as: T.Type) -> T? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success,
              let ref
        else { return nil }
        let axValue = ref as! AXValue
        let result = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { result.deallocate() }
        guard AXValueGetValue(axValue, type, result) else { return nil }
        return result.pointee
    }
}
