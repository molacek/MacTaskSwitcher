import AppKit

/// One row in the switcher. v1 lists one target per application that has a
/// window on the active display; committing activates the app and raises the
/// specific window that lives on that display (so Safari on the left monitor
/// comes forward even if another Safari window is focused on the right monitor).
///
/// Per-window cycling within an app (native `Cmd+``` behaviour) is not wired up
/// yet – `WindowEnumerator` already collects the data; add a `.window` case here
/// and a backtick handler in `HotkeyInterceptor` to finish it.
struct SwitchTarget {
    let app: NSRunningApplication
    let title: String
    let icon: NSImage?
    /// Frontmost on-screen window of `app` on the active display, if known.
    let frontWindowID: CGWindowID?

    func activate() {
        app.activate()
        if let frontWindowID {
            AXWindowRaiser.raise(windowID: frontWindowID, pid: app.processIdentifier)
        }
    }
}
