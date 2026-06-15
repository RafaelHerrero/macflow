import AppKit

// Ponto de entrada do Macflow.
//
// Configuramos o app como "accessory" (.accessory) para ele rodar como menu-bar-only:
// sem ícone no Dock e sem aparecer no App Switcher (Cmd+Tab).
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
