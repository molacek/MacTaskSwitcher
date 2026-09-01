import AppKit

/// Wires together the long-lived pieces:
///   1. `HotkeyInterceptor` – the CGEventTap that swallows Cmd+Tab.
///   2. `SwitcherController` – session state + the overlay panel.
///   3. `StatusItemController` – the only visible control surface.
///   4. `PermissionsMonitor` – first-launch permission request + polling.
final class AppController: NSObject, NSApplicationDelegate {
    private let settings = Settings()
    private lazy var switcher = SwitcherController(settings: settings)
    private lazy var settingsWindow = SettingsWindowController(settings: settings)
    private let statusItem = StatusItemController()
    private let interceptor = HotkeyInterceptor()
    private var permissions: PermissionsMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.onQuit = { NSApp.terminate(nil) }
        statusItem.onOpenSettings = { [settingsWindow] in settingsWindow.show() }
        statusItem.install()

        interceptor.onAction = { [switcher] action in
            switcher.handle(action)   // delivered on the main run loop
        }

        // If permission is already granted the tap installs immediately;
        // otherwise ask for it and keep retrying until it takes.
        if interceptor.start() { return }

        let monitor = PermissionsMonitor(
            attemptActivate: { [interceptor] in interceptor.start() },
            onGranted: {}
        )
        permissions = monitor
        monitor.begin()
    }
}
