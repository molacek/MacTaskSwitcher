import AppKit

/// Owns a switching *session*: the window list snapshot taken on the first
/// Cmd+Tab, the current selection index, and the overlay panel. A session
/// starts on the first `.advance` and ends on `.commit` or `.cancel`.
final class SwitcherController {
    private let overlay = OverlayPanel()
    private let mru = MRUTracker()

    private var targets: [SwitchTarget] = []
    private var index = 0
    private var active = false

    init() {
        // Hovering an icon just moves the selection; the pending `.commit` on
        // Cmd-release then activates whatever is selected.
        overlay.onHoverSelect = { [weak self] hovered in
            guard let self, self.active, self.targets.indices.contains(hovered) else { return }
            self.index = hovered
            self.overlay.select(hovered)
        }
    }

    func handle(_ action: SwitchAction) {
        switch action {
        case .advance(let reverse):
            if !active { begin() }
            guard !targets.isEmpty else { return }
            index = (index + (reverse ? -1 : 1) + targets.count) % targets.count
            overlay.select(index)

        case .commit:
            end(commit: true)

        case .cancel:
            end(commit: false)
        }
    }

    private func begin() {
        active = true
        guard let screen = DisplayResolver.activeDisplay() else {
            targets = []
            return
        }
        targets = WindowEnumerator.appTargets(on: screen, mru: mru.order())
        // Start on the current app (index 0). The `.advance` that opened this
        // session then steps to index 1 – the previously-focused app – so a
        // single Cmd+Tab + release toggles between the two most-recent apps.
        index = 0
        overlay.show(targets, on: screen, selected: index)
    }

    private func end(commit: Bool) {
        active = false
        overlay.hide()
        defer { targets = [] }
        guard commit, targets.indices.contains(index) else { return }
        targets[index].activate()
    }
}
