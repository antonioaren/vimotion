import AppKit

// Entry point. vimotion runs as a background agent (no Dock icon), presenting
// only a menu-bar item.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

app.run()
