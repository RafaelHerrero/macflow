import Foundation

/// Conteúdo padrão gravado em `~/.config/macflow/config.toml` na primeira execução,
/// caso o arquivo ainda não exista. Mantido em sincronia com `config.toml.example`.
enum DefaultConfig {
    static let contents = """
    # ~/.config/macflow/config.toml
    # Configuração do Macflow. Salve o arquivo e as mudanças são aplicadas na hora.

    [settings]
    # Modificador para os atalhos de apps. Combine com "+": "Ctrl", "Ctrl+Option", etc.
    app_modifier = "Ctrl"

    # ───────────────────────── Apps ─────────────────────────
    # tecla = "Nome do App" (ou bundle id, ex: "com.apple.Safari")
    # Com app_modifier = "Ctrl", pressionar Ctrl+1 abre/foca o Safari.
    [apps]
    "1" = "Safari"
    "2" = "Visual Studio Code"
    "3" = "iTerm"
    "4" = "Obsidian"

    # ──────────────────────── Janelas ───────────────────────
    # ação = "atalho". Modificadores: Ctrl, Option/Alt, Cmd, Shift.
    [windows]
    # Metades
    left  = "Ctrl+Option+Left"
    right = "Ctrl+Option+Right"
    top   = "Ctrl+Option+Up"
    bottom = "Ctrl+Option+Down"

    # Quadrantes
    top-left     = "Ctrl+Option+Cmd+Left"
    top-right    = "Ctrl+Option+Cmd+Up"
    bottom-left  = "Ctrl+Option+Cmd+Down"
    bottom-right = "Ctrl+Option+Cmd+Right"

    # Maximizar / centralizar
    maximize = "Ctrl+Option+Return"
    center   = "Ctrl+Option+C"

    # Monitores
    next-monitor = "Ctrl+Option+Shift+Right"
    prev-monitor = "Ctrl+Option+Shift+Left"
    """
}
