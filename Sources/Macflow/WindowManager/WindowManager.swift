import AppKit
import ApplicationServices

/// Applies window actions (move/resize) to the frontmost window.
///
/// Handles the conversion between Cocoa and AX coordinates and multi-monitor support.
@MainActor
final class WindowManager {

    /// Performs an action on the focused window. Silently does nothing if there is no
    /// window or accessibility permission.
    func perform(_ action: WindowAction) {
        guard AXIsProcessTrusted() else {
            Log.info("perform(\(action.rawValue)) ignored: NO Accessibility permission")
            AccessibilityManager.requestIfNeeded()
            return
        }
        guard let window = AXWindow.focused() else {
            Log.info("perform(\(action.rawValue)): no focused window")
            return
        }
        guard let axFrame = window.axFrame else {
            Log.info("perform(\(action.rawValue)): could not read window frame")
            return
        }

        // Current screen = the one containing the window's center (in Cocoa coordinates).
        let cocoaFrame = Self.axToCocoa(axFrame)
        let currentScreen = Self.screen(containing: cocoaFrame) ?? NSScreen.main ?? NSScreen.screens.first
        guard let currentScreen else {
            Log.info("perform(\(action.rawValue)): could not find current screen")
            return
        }
        Log.info("perform(\(action.rawValue)): screens=\(NSScreen.screens.count), window(cocoa)=\(cocoaFrame)")

        let target: NSRect?
        switch action {
        case .center:
            target = centerFrame(for: cocoaFrame, on: currentScreen)
        case .nextMonitor:
            target = frameOnAdjacentScreen(from: cocoaFrame, current: currentScreen, offset: 1)
        case .prevMonitor:
            target = frameOnAdjacentScreen(from: cocoaFrame, current: currentScreen, offset: -1)
        default:
            target = action.frame(in: currentScreen.visibleFrame)
        }

        guard let target else {
            Log.info("perform(\(action.rawValue)): no target frame (e.g. only 1 monitor?) — nothing to do")
            return
        }
        Log.info("perform(\(action.rawValue)): moving to (cocoa)=\(target)")
        window.setAXFrame(Self.cocoaToAX(target))
    }

    // MARK: - Actions with extra context

    /// Centers the window on the screen while keeping its current size.
    private func centerFrame(for frame: NSRect, on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        return NSRect(
            x: visible.minX + (visible.width - frame.width) / 2,
            y: visible.minY + (visible.height - frame.height) / 2,
            width: frame.width,
            height: frame.height
        )
    }

    /// Moves the window to the adjacent screen (offset +1 = next, -1 = previous),
    /// preserving the relative position/size within the visible area.
    private func frameOnAdjacentScreen(from frame: NSRect, current: NSScreen, offset: Int) -> NSRect? {
        let screens = NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }
        guard screens.count > 1,
              let index = screens.firstIndex(of: current)
        else { return nil }

        let targetIndex = ((index + offset) % screens.count + screens.count) % screens.count
        let from = current.visibleFrame
        let to = screens[targetIndex].visibleFrame

        // Relative fraction within the source screen → same fraction on the target screen.
        let fx = (frame.minX - from.minX) / from.width
        let fy = (frame.minY - from.minY) / from.height
        let fw = frame.width / from.width
        let fh = frame.height / from.height

        return NSRect(
            x: to.minX + fx * to.width,
            y: to.minY + fy * to.height,
            width: fw * to.width,
            height: fh * to.height
        )
    }

    // MARK: - Coordinate and screen conversion

    /// Main screen height — reference for the Y-axis flip.
    private static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// Cocoa (bottom-left origin) → AX (top-left origin).
    static func cocoaToAX(_ rect: NSRect) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryHeight - rect.minY - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// AX (top-left origin) → Cocoa (bottom-left origin).
    static func axToCocoa(_ rect: CGRect) -> NSRect {
        NSRect(
            x: rect.minX,
            y: primaryHeight - rect.minY - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// The screen that contains the frame's center (Cocoa coordinates).
    private static func screen(containing frame: NSRect) -> NSScreen? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first { $0.frame.contains(center) }
    }
}
