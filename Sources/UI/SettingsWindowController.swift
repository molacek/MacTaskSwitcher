import AppKit
import SwiftUI

/// The Settings window, opened from the status-item menu. Lazily created,
/// reused across opens. The app stays `.accessory` (no Dock icon); deliberately
/// activating for a user-invoked window is fine — the "never activate" rule is
/// about the overlay panel, not this.
final class SettingsWindowController {
    private let settings: Settings
    private var window: NSWindow?

    init(settings: Settings) {
        self.settings = settings
    }

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView(settings: settings))
            let window = NSWindow(contentViewController: host)
            window.styleMask = [.titled, .closable]
            window.title = "MacTaskSwitcher Settings"
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct SettingsView: View {
    @ObservedObject var settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("When you press Cmd+Tab, switch between:")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(SwitchScope.allCases, id: \.self) { scope in
                    Button {
                        settings.scope = scope
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: settings.scope == scope
                                  ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(settings.scope == scope ? Color.accentColor : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(scope.title)
                                Text(scope.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .frame(width: 380, alignment: .leading)
    }
}
