import AppKit

/// The only persistent UI. A menu-bar item with "Settings…", "Launch at Login"
/// and "Quit".
final class StatusItemController: NSObject {
    var onQuit: () -> Void = {}
    var onOpenSettings: () -> Void = {}

    private var item: NSStatusItem?

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.on.rectangle.angled",
            accessibilityDescription: "MacTaskSwitcher"
        )

        let menu = NSMenu()

        let settings = NSMenuItem(title: "Settings…",
                                  action: #selector(openSettings),
                                  keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let login = NSMenuItem(title: "Launch at Login",
                               action: #selector(toggleLogin(_:)),
                               keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit MacTaskSwitcher",
                              action: #selector(quit),
                              keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        self.item = item
    }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        LoginItem.toggle()
        sender.state = LoginItem.isEnabled ? .on : .off
    }

    @objc private func openSettings() { onOpenSettings() }

    @objc private func quit() { onQuit() }
}
