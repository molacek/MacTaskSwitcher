import AppKit
import ApplicationServices
import CoreGraphics

/// What the interceptor tells the switcher to do.
enum SwitchAction {
    case advance(reverse: Bool)   // Cmd+Tab / Cmd+Shift+Tab pressed while Cmd is held
    case commit                   // Cmd released
    case cancel                   // Escape pressed during a session
}

/// Installs a session-level `CGEventTap` and consumes Cmd+Tab so the system
/// switcher never sees it. The tap's run-loop source lives on the main run
/// loop, so the callback fires on the main thread; the consume/pass-through
/// decision is made synchronously there, and `onAction` is invoked directly.
///
/// Requires the process to be Accessibility-trusted. Note that
/// `CGEvent.tapCreate` returns a **non-nil** port even for an untrusted process
/// — the tap simply never fires — so `start()` gates on `AXIsProcessTrusted()`
/// up front and verifies the tap is actually enabled before reporting success.
final class HotkeyInterceptor {
    var onAction: ((SwitchAction) -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var sessionActive = false

    private let kVK_Tab: CGKeyCode = 48
    private let kVK_Escape: CGKeyCode = 53

    /// True once the tap is installed. Safe to call repeatedly — a no-op that
    /// returns `true` if the tap already exists; used by `PermissionsMonitor` as
    /// its "are we allowed yet?" probe.
    var isActive: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }

        // An untrusted process still gets a port back from tapCreate, but the
        // callback never fires. Bail early so PermissionsMonitor takes over.
        guard AXIsProcessTrusted() else { return false }

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let me = Unmanaged<HotkeyInterceptor>.fromOpaque(refcon).takeUnretainedValue()
                return me.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        guard CGEvent.tapIsEnabled(tap: tap) else {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            return false
        }

        self.tap = tap
        self.runLoopSource = source
        NSLog("MacTaskSwitcher: Cmd+Tab interception active")
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)

        case .keyDown:
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags

            if keyCode == kVK_Tab && flags.contains(.maskCommand) {
                sessionActive = true
                onAction?(.advance(reverse: flags.contains(.maskShift)))
                return nil // consume – the system switcher must not see this
            }
            if sessionActive && keyCode == kVK_Escape {
                sessionActive = false
                onAction?(.cancel)
                return nil
            }
            return Unmanaged.passUnretained(event)

        case .flagsChanged:
            // Commit the moment Command is no longer held.
            if sessionActive && !event.flags.contains(.maskCommand) {
                sessionActive = false
                onAction?(.commit)
            }
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }
}
