import AppKit
import ApplicationServices

/// Aplica ações de janela (mover/redimensionar) à janela frontmost.
///
/// Lida com a conversão entre coordenadas Cocoa e AX e com o suporte multi-monitor.
@MainActor
final class WindowManager {

    /// Executa uma ação na janela em foco. Silenciosamente não faz nada se não há
    /// janela ou permissão de acessibilidade.
    func perform(_ action: WindowAction) {
        guard AXIsProcessTrusted() else {
            Log.info("perform(\(action.rawValue)) ignorado: SEM permissão de Acessibilidade")
            AccessibilityManager.requestIfNeeded()
            return
        }
        guard let window = AXWindow.focused() else {
            Log.info("perform(\(action.rawValue)): nenhuma janela em foco")
            return
        }
        guard let axFrame = window.axFrame else {
            Log.info("perform(\(action.rawValue)): não consegui ler o frame da janela")
            return
        }

        // Tela atual = aquela que contém o centro da janela (em coordenadas Cocoa).
        let cocoaFrame = Self.axToCocoa(axFrame)
        let currentScreen = Self.screen(containing: cocoaFrame) ?? NSScreen.main ?? NSScreen.screens.first
        guard let currentScreen else {
            Log.info("perform(\(action.rawValue)): não achei a tela atual")
            return
        }
        Log.info("perform(\(action.rawValue)): telas=\(NSScreen.screens.count), janela(cocoa)=\(cocoaFrame)")

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
            Log.info("perform(\(action.rawValue)): sem frame-alvo (ex.: só 1 monitor?) — nada a fazer")
            return
        }
        Log.info("perform(\(action.rawValue)): movendo para (cocoa)=\(target)")
        window.setAXFrame(Self.cocoaToAX(target))
    }

    // MARK: - Ações com contexto extra

    /// Centraliza a janela na tela mantendo seu tamanho atual.
    private func centerFrame(for frame: NSRect, on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        return NSRect(
            x: visible.minX + (visible.width - frame.width) / 2,
            y: visible.minY + (visible.height - frame.height) / 2,
            width: frame.width,
            height: frame.height
        )
    }

    /// Move a janela para a tela adjacente (offset +1 = próxima, -1 = anterior),
    /// preservando a posição/tamanho relativos dentro da área visível.
    private func frameOnAdjacentScreen(from frame: NSRect, current: NSScreen, offset: Int) -> NSRect? {
        let screens = NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }
        guard screens.count > 1,
              let index = screens.firstIndex(of: current)
        else { return nil }

        let targetIndex = ((index + offset) % screens.count + screens.count) % screens.count
        let from = current.visibleFrame
        let to = screens[targetIndex].visibleFrame

        // Fração relativa dentro da tela de origem → mesma fração na tela de destino.
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

    // MARK: - Conversão de coordenadas e telas

    /// Altura da tela principal — referência para o flip do eixo Y.
    private static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// Cocoa (origem inferior-esquerda) → AX (origem superior-esquerda).
    static func cocoaToAX(_ rect: NSRect) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryHeight - rect.minY - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// AX (origem superior-esquerda) → Cocoa (origem inferior-esquerda).
    static func axToCocoa(_ rect: CGRect) -> NSRect {
        NSRect(
            x: rect.minX,
            y: primaryHeight - rect.minY - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// Tela que contém o centro do frame (coordenadas Cocoa).
    private static func screen(containing frame: NSRect) -> NSScreen? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first { $0.frame.contains(center) }
    }
}
