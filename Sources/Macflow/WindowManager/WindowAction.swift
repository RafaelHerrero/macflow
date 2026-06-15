import AppKit

/// All supported window actions. The raw name (kebab-case) is the one used in
/// `config.toml` under the `[windows]` section.
enum WindowAction: String, CaseIterable, Sendable {
    // Halves
    case left, right, top, bottom
    // Quadrants
    case topLeft = "top-left"
    case topRight = "top-right"
    case bottomLeft = "bottom-left"
    case bottomRight = "bottom-right"
    // Thirds (horizontal)
    case leftThird = "left-third"
    case centerThird = "center-third"
    case rightThird = "right-third"
    case leftTwoThirds = "left-two-thirds"
    case rightTwoThirds = "right-two-thirds"
    // Fullscreen / center
    case maximize
    case center
    // Monitors
    case nextMonitor = "next-monitor"
    case prevMonitor = "prev-monitor"

    /// Computes the target frame (in Cocoa coordinates, bottom-left origin) for
    /// actions that depend only on the screen's visible area.
    ///
    /// Returns `nil` for actions that need extra context (current window size or
    /// another screen) — those are handled directly in `WindowManager`.
    func frame(in visible: NSRect) -> NSRect? {
        let x = visible.minX, y = visible.minY
        let w = visible.width, h = visible.height
        let halfW = w / 2, halfH = h / 2
        let third = w / 3

        switch self {
        case .left:   return NSRect(x: x, y: y, width: halfW, height: h)
        case .right:  return NSRect(x: x + halfW, y: y, width: halfW, height: h)
        case .top:    return NSRect(x: x, y: y + halfH, width: w, height: halfH)
        case .bottom: return NSRect(x: x, y: y, width: w, height: halfH)

        case .topLeft:     return NSRect(x: x, y: y + halfH, width: halfW, height: halfH)
        case .topRight:    return NSRect(x: x + halfW, y: y + halfH, width: halfW, height: halfH)
        case .bottomLeft:  return NSRect(x: x, y: y, width: halfW, height: halfH)
        case .bottomRight: return NSRect(x: x + halfW, y: y, width: halfW, height: halfH)

        case .leftThird:      return NSRect(x: x, y: y, width: third, height: h)
        case .centerThird:    return NSRect(x: x + third, y: y, width: third, height: h)
        case .rightThird:     return NSRect(x: x + 2 * third, y: y, width: third, height: h)
        case .leftTwoThirds:  return NSRect(x: x, y: y, width: 2 * third, height: h)
        case .rightTwoThirds: return NSRect(x: x + third, y: y, width: 2 * third, height: h)

        case .maximize: return visible

        // Handled in WindowManager (need more context):
        case .center, .nextMonitor, .prevMonitor: return nil
        }
    }
}
