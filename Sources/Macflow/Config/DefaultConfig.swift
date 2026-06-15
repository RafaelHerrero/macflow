import Foundation

/// Default contents written to `~/.config/macflow/config.toml` on first run,
/// if the file does not exist yet. Kept in sync with `config.toml.example`.
enum DefaultConfig {
    static let contents = """
    # ~/.config/macflow/config.toml
    # Macflow configuration. Save the file and changes are applied instantly.

    [settings]
    # Modifier for the app shortcuts. Combine with "+": "Ctrl", "Ctrl+Option", etc.
    app_modifier = "Ctrl"

    # ───────────────────────── Apps ─────────────────────────
    # key = "App Name" (or bundle id, e.g.: "com.apple.Safari")
    # With app_modifier = "Ctrl", pressing Ctrl+1 opens/focuses Safari.
    [apps]
    "1" = "Safari"
    "2" = "Visual Studio Code"
    "3" = "iTerm"
    "4" = "Obsidian"

    # ──────────────────────── Windows ───────────────────────
    # action = "shortcut". Modifiers: Ctrl, Option/Alt, Cmd, Shift.
    [windows]
    # Halves
    left  = "Ctrl+Option+Left"
    right = "Ctrl+Option+Right"
    top   = "Ctrl+Option+Up"
    bottom = "Ctrl+Option+Down"

    # Quadrants
    top-left     = "Ctrl+Option+Cmd+Left"
    top-right    = "Ctrl+Option+Cmd+Up"
    bottom-left  = "Ctrl+Option+Cmd+Down"
    bottom-right = "Ctrl+Option+Cmd+Right"

    # Maximize / center
    maximize = "Ctrl+Option+Return"
    center   = "Ctrl+Option+C"

    # Monitors
    next-monitor = "Ctrl+Option+Shift+Right"
    prev-monitor = "Ctrl+Option+Shift+Left"
    """
}
