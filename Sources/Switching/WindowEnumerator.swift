import AppKit
import CoreGraphics

/// Builds the candidate list for a display from the live on-screen window list.
///
/// `CGWindowListCopyWindowInfo` returns windows front-to-back. We keep only
/// "normal" windows (layer 0, non-trivial size, visible), map each window's
/// CoreGraphics rect (origin top-left of the primary screen) into Cocoa
/// coordinates, and keep it if at least half its area is on the target screen.
/// The first window seen for a PID is its frontmost window on that screen.
enum WindowEnumerator {
    static func appTargets(on screen: NSScreen, mru: [pid_t]) -> [SwitchTarget] {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        let primaryHeight = NSScreen.screens
            .first(where: { $0.frame.origin == .zero })?.frame.height ?? screen.frame.height

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var zOrderPIDs: [pid_t] = []          // front-to-back, deduped
        var frontWindow: [pid_t: CGWindowID] = [:]
        var seen = Set<pid_t>()

        for dict in list {
            guard
                let layer = dict[kCGWindowLayer as String] as? Int, layer == 0,
                let pid = dict[kCGWindowOwnerPID as String] as? pid_t, pid != selfPID,
                let winID = dict[kCGWindowNumber as String] as? CGWindowID,
                let b = dict[kCGWindowBounds as String] as? [String: CGFloat]
            else { continue }

            let alpha = dict[kCGWindowAlpha as String] as? Double ?? 1
            guard alpha > 0.01 else { continue }

            let x = b["X"] ?? 0, y = b["Y"] ?? 0, w = b["Width"] ?? 0, h = b["Height"] ?? 0
            guard w > 48, h > 48 else { continue }

            let cocoa = CGRect(x: x, y: primaryHeight - y - h, width: w, height: h)
            let overlap = cocoa.intersection(screen.frame)
            guard !overlap.isNull,
                  overlap.width * overlap.height >= cocoa.width * cocoa.height * 0.5
            else { continue }

            guard let app = NSRunningApplication(processIdentifier: pid),
                  app.activationPolicy == .regular
            else { continue }

            if seen.insert(pid).inserted {
                zOrderPIDs.append(pid)
                frontWindow[pid] = winID
            }
        }

        // Order: most-recently-used first (restricted to apps on this screen),
        // then anything left over in z-order.
        let onScreen = Set(zOrderPIDs)
        var ordered = mru.filter { onScreen.contains($0) }
        for pid in zOrderPIDs where !ordered.contains(pid) { ordered.append(pid) }

        return ordered.compactMap { pid in
            guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
            return SwitchTarget(
                app: app,
                title: app.localizedName ?? "",
                icon: app.icon,
                frontWindowID: frontWindow[pid]
            )
        }
    }
}
