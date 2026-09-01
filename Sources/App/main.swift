import AppKit

// Agent app: no Dock icon, no menu bar. All UI is the status item + the overlay panel.
let app = NSApplication.shared
let controller = AppController()
app.delegate = controller
app.setActivationPolicy(.accessory)
app.run()
