import AppKit
import ApplicationServices

/// Wrapper over the frontmost window's `AXUIElement`, hiding the verbosity of the
/// Accessibility API behind an interface using AppKit types (`CGRect`).
///
/// IMPORTANT: the Accessibility API uses global coordinates with the origin at the
/// **top-left corner** of the main screen and the Y axis growing downward —
/// unlike Cocoa (bottom-left origin, Y growing upward). The conversion is
/// centralized here and in `WindowManager`.
struct AXWindow {

    let element: AXUIElement

    /// Gets the focused window of the frontmost app. `nil` if there is no
    /// accessibility permission or no focused window.
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
        // windowRef is an AXUIElement; the type check is done by the API.
        let window = windowRef as! AXUIElement
        return AXWindow(element: window)
    }

    /// Current window frame in AX coordinates (top-left origin).
    var axFrame: CGRect? {
        guard let position = copyValue(kAXPositionAttribute, type: .cgPoint, as: CGPoint.self),
              let size = copyValue(kAXSizeAttribute, type: .cgSize, as: CGSize.self)
        else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// Sets position and size (in AX coordinates). The position is applied both before
    /// and after the size to accommodate apps that clamp dimensions to the current position.
    func setAXFrame(_ frame: CGRect) {
        setPosition(frame.origin)
        setSize(frame.size)
        setPosition(frame.origin)
    }

    // MARK: - Reading/writing AX attributes

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
