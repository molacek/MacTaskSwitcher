import AppKit
import CoreGraphics

/// Most-recently-used ordering of application PIDs.
///
/// Seeded at launch from the window-server stacking order (best available proxy
/// for focus history before we've seen any activations), then kept exact by
/// watching `NSWorkspace` activate/terminate notifications. `WindowEnumerator`
/// uses this as the sole sort key for the switcher list, so one Cmd+Tab toggles
/// between the two front apps.
final class MRUTracker {
    private var pids: [pid_t] = []

    init() {
        seedFromWindowServer()
        if let front = NSWorkspace.shared.frontmostApplication {
            promote(front.processIdentifier)
        }

        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(appActivated(_:)),
                       name: NSWorkspace.didActivateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(appTerminated(_:)),
                       name: NSWorkspace.didTerminateApplicationNotification, object: nil)
    }

    /// PIDs, most-recently-focused first.
    func order() -> [pid_t] { pids }

    // MARK: -

    private func promote(_ pid: pid_t) {
        pids.removeAll { $0 == pid }
        pids.insert(pid, at: 0)
    }

    @objc private func appActivated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        else { return }
        promote(app.processIdentifier)
    }

    @objc private func appTerminated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        else { return }
        pids.removeAll { $0 == app.processIdentifier }
    }

    /// Front-to-back order of regular apps that currently have an on-screen
    /// window. Only used to prime the list at launch.
    private func seedFromWindowServer() {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
        else { return }

        var seen = Set<pid_t>()
        for dict in list {
            guard let layer = dict[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = dict[kCGWindowOwnerPID as String] as? pid_t,
                  NSRunningApplication(processIdentifier: pid)?.activationPolicy == .regular
            else { continue }
            if seen.insert(pid).inserted {
                pids.append(pid)
            }
        }
    }
}
