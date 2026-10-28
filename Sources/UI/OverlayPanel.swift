import AppKit

/// Borderless, non-activating floating panel centred on the active display.
/// `.nonactivatingPanel` is critical: if the panel activated our (agent) app,
/// the "current application" would change mid-session and the Cmd-release
/// commit logic would target the wrong app.
///
/// The window server's space membership for a long-lived `.canJoinAllSpaces`
/// window owned by a never-active agent app can go stale after a display
/// reconfiguration, sleep/wake, or a space change (e.g. into a full-screen
/// space): the panel then orders "front" but is never composited on that
/// display. So the panel is marked stale on those events and rebuilt on the
/// next `show`.
final class OverlayPanel {
    private var panel: NSPanel
    private let view = OverlayView()
    private var needsRebuild = false
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    init() {
        panel = Self.makePanel()
        panel.contentView = view

        let markStale: (Notification) -> Void = { [weak self] _ in self?.needsRebuild = true }
        let ws = NSWorkspace.shared.notificationCenter
        observers = [
            (NotificationCenter.default, NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil, queue: .main, using: markStale)),
            (ws, ws.addObserver(forName: NSWorkspace.didWakeNotification,
                                object: nil, queue: .main, using: markStale)),
            (ws, ws.addObserver(forName: NSWorkspace.screensDidWakeNotification,
                                object: nil, queue: .main, using: markStale)),
            (ws, ws.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
                                object: nil, queue: .main, using: markStale)),
        ]
    }

    deinit {
        for (center, token) in observers { center.removeObserver(token) }
    }

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        // Needs to see mouse-moved events so the row can be hovered. The panel is
        // still `.nonactivatingPanel` and never made key, so this does not
        // activate our agent app.
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary,
                                    .fullScreenAuxiliary, .ignoresCycle]
        return panel
    }

    private func rebuildPanel() {
        let old = panel
        old.orderOut(nil)
        old.contentView = nil
        old.close()
        panel = Self.makePanel()
        panel.contentView = view
        needsRebuild = false
    }

    func show(_ targets: [SwitchTarget], on screen: NSScreen, selected: Int) {
        guard !targets.isEmpty else { return }
        if needsRebuild { rebuildPanel() }
        view.configure(targets: targets, selected: selected)
        let size = view.intrinsicContentSize
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.midY - size.height / 2
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
    }

    /// Forwarded to the content view: fires with the icon slot under the pointer.
    var onHoverSelect: ((Int) -> Void)? {
        get { view.onHoverSelect }
        set { view.onHoverSelect = newValue }
    }

    func select(_ index: Int) { view.highlight(index) }

    func hide() { panel.orderOut(nil) }
}
