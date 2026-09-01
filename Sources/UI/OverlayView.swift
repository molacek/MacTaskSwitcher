import AppKit

/// Minimal, allocation-light HUD: a dark rounded panel, a row of app icons, a
/// highlight behind the selected icon, and the selected app's name beneath.
/// Everything is painted in `draw(_:)` — no subviews, no Auto Layout, no
/// per-frame allocations.
final class OverlayView: NSView {
    private enum Metric {
        static let icon: CGFloat = 64
        static let spacing: CGFloat = 16
        static let padding: CGFloat = 22       // top + sides
        static let bottomInset: CGFloat = 16   // below the name label
        static let labelHeight: CGFloat = 16
        static let labelGap: CGFloat = 12      // clear space between label and icons
        static let corner: CGFloat = 18
    }

    private var targets: [SwitchTarget] = []
    private var selected = 0

    /// Called when the pointer moves over a different app icon. The controller
    /// owns the selection index, so the view only reports the hovered slot and
    /// lets `highlight(_:)` come back around.
    var onHoverSelect: ((Int) -> Void)?

    func configure(targets: [SwitchTarget], selected: Int) {
        self.targets = targets
        self.selected = selected
        invalidateIntrinsicContentSize()
        setFrameSize(intrinsicContentSize)
        needsDisplay = true
    }

    func highlight(_ index: Int) {
        selected = index
        needsDisplay = true
    }

    override var intrinsicContentSize: NSSize {
        let n = max(targets.count, 1)
        let width = Metric.padding * 2
            + CGFloat(n) * Metric.icon
            + CGFloat(n - 1) * Metric.spacing
        let height = Metric.padding + Metric.icon + Metric.labelGap
            + Metric.labelHeight + Metric.bottomInset
        return NSSize(width: width, height: height)
    }

    override var isFlipped: Bool { false }

    // MARK: - Mouse hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) { hover(event) }
    override func mouseMoved(with event: NSEvent) { hover(event) }

    private func hover(_ event: NSEvent) {
        guard let i = iconIndex(at: convert(event.locationInWindow, from: nil)),
              i != selected else { return }
        onHoverSelect?(i)
    }

    /// Icon slot under `point` (view coordinates), or nil. Hit rects are widened
    /// into the inter-icon gaps so the selection tracks the pointer smoothly.
    private func iconIndex(at point: NSPoint) -> Int? {
        let iconY = Metric.bottomInset + Metric.labelHeight + Metric.labelGap
        for i in targets.indices {
            let x = Metric.padding + CGFloat(i) * (Metric.icon + Metric.spacing)
            let rect = NSRect(x: x, y: iconY, width: Metric.icon, height: Metric.icon)
                .insetBy(dx: -Metric.spacing / 2, dy: -Metric.labelGap / 2)
            if rect.contains(point) { return i }
        }
        return nil
    }

    override func draw(_ dirtyRect: NSRect) {
        // Panel background.
        let bg = NSBezierPath(roundedRect: bounds, xRadius: Metric.corner, yRadius: Metric.corner)
        NSColor(calibratedWhite: 0.12, alpha: 0.92).setFill()
        bg.fill()
        NSColor(calibratedWhite: 1.0, alpha: 0.08).setStroke()
        bg.lineWidth = 1
        bg.stroke()

        guard !targets.isEmpty else { return }

        let iconY = Metric.bottomInset + Metric.labelHeight + Metric.labelGap
        for (i, target) in targets.enumerated() {
            let x = Metric.padding + CGFloat(i) * (Metric.icon + Metric.spacing)
            let rect = NSRect(x: x, y: iconY, width: Metric.icon, height: Metric.icon)

            if i == selected {
                let hl = NSBezierPath(roundedRect: rect.insetBy(dx: -8, dy: -8), xRadius: 12, yRadius: 12)
                NSColor(calibratedWhite: 1.0, alpha: 0.22).setFill()
                hl.fill()
            }
            target.icon?.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        }

        let title = targets.indices.contains(selected) ? targets[selected].title : ""
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = title.size(withAttributes: attrs)
        title.draw(
            at: NSPoint(x: (bounds.width - size.width) / 2,
                        y: Metric.bottomInset + (Metric.labelHeight - size.height) / 2),
            withAttributes: attrs
        )
    }
}
