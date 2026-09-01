import AppKit

/// Borderless, non-activating floating panel centred on the active display.
/// `.nonactivatingPanel` is critical: if the panel activated our (agent) app,
/// the "current application" would change mid-session and the Cmd-release
/// commit logic would target the wrong app.
final class OverlayPanel {
    private let panel: NSPanel
    private let view = OverlayView()

    init() {
        panel = NSPanel(
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
        // Needs to see mouse-moved events so the row can be hovered. The panel is
        // still `.nonactivatingPanel` and never made key, so this does not
        // activate our agent app.
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary,
                                    .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = view
    }

    func show(_ targets: [SwitchTarget], on screen: NSScreen, selected: Int) {
        guard !targets.isEmpty else { return }
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
