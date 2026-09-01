import AppKit
import ApplicationServices

/// First-launch permissions flow:
///   1. Trigger the system Accessibility prompt.
///   2. Show an explanatory dialog with "Open System Settings" / "Quit".
///   3. Poll once a second, retrying `attemptActivate` (which actually tries to
///      install the event tap) until it succeeds, then run `onGranted`.
///
/// The poll timer is scheduled in `.common` modes so it keeps firing while
/// menus or other modal panels are open.
final class PermissionsMonitor {
    private let attemptActivate: () -> Bool
    private let onGranted: () -> Void
    private var timer: Timer?

    init(attemptActivate: @escaping () -> Bool, onGranted: @escaping () -> Void) {
        self.attemptActivate = attemptActivate
        self.onGranted = onGranted
    }

    func begin() {
        Permissions.ensureAccessibility(promptIfNeeded: true)
        presentRequestDialog()
        startPolling()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: -

    private func presentRequestDialog() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "MacTaskSwitcher needs permission to run"
        alert.informativeText = """
        To replace Cmd+Tab, MacTaskSwitcher has to observe keyboard input and \
        bring other apps' windows forward.

        In System Settings ▸ Privacy & Security, enable MacTaskSwitcher under \
        Accessibility (and under Input Monitoring, if it is listed). \
        MacTaskSwitcher activates automatically as soon as access is granted — \
        no relaunch needed.
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")

        if alert.runModal() == .alertSecondButtonReturn {
            NSApp.terminate(nil)
        }
        openPrivacySettings()
    }

    private func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func startPolling() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] tick in
            guard let self else { tick.invalidate(); return }
            guard self.attemptActivate() else { return }
            tick.invalidate()
            self.timer = nil
            self.confirmGranted()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func confirmGranted() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "MacTaskSwitcher is active"
        alert.informativeText = "Press ⌘Tab to switch between apps on the display under your pointer."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
