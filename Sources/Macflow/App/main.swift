import AppKit

// Macflow entry point.
//
// We configure the app as "accessory" (.accessory) so it runs as menu-bar-only:
// no Dock icon and not shown in the App Switcher (Cmd+Tab).
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
