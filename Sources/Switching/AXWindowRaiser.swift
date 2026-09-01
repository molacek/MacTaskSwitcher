import ApplicationServices
import CoreGraphics

/// Private but long-stable CoreGraphics/AX bridge: maps an `AXUIElement`
/// window back to its `CGWindowID` so we can match the window we found via
/// `CGWindowListCopyWindowInfo` to the AX element we can actually raise.
/// Same approach used by AltTab and other switchers.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement,
                                  _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

enum AXWindowRaiser {
    /// Raise and focus the given window. Requires Accessibility permission;
    /// silently no-ops if the window can't be found (e.g. it just closed).
    static func raise(windowID: CGWindowID, pid: pid_t) {
        let appElement = AXUIElementCreateApplication(pid)

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement]
        else { return }

        for window in windows {
            var wid: CGWindowID = 0
            guard _AXUIElementGetWindow(window, &wid) == .success, wid == windowID else { continue }
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            return
        }
    }
}
