import AppKit

/// Todas as ações de janela suportadas. O nome cru (kebab-case) é o usado no
/// `config.toml` na seção `[windows]`.
enum WindowAction: String, CaseIterable, Sendable {
    // Metades
    case left, right, top, bottom
    // Quadrantes
    case topLeft = "top-left"
    case topRight = "top-right"
    case bottomLeft = "bottom-left"
    case bottomRight = "bottom-right"
    // Terços (horizontais)
    case leftThird = "left-third"
    case centerThird = "center-third"
    case rightThird = "right-third"
    case leftTwoThirds = "left-two-thirds"
    case rightTwoThirds = "right-two-thirds"
    // Tela cheia / centralizar
    case maximize
    case center
    // Monitores
    case nextMonitor = "next-monitor"
    case prevMonitor = "prev-monitor"

    /// Calcula o frame-alvo (em coordenadas Cocoa, origem inferior-esquerda) para
    /// ações que dependem apenas da área visível da tela.
    ///
    /// Retorna `nil` para ações que precisam de contexto extra (tamanho atual da
    /// janela ou outra tela) — essas são tratadas diretamente no `WindowManager`.
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

        // Tratadas no WindowManager (precisam de mais contexto):
        case .center, .nextMonitor, .prevMonitor: return nil
        }
    }
}
