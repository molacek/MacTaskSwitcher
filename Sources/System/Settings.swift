import Foundation

/// How wide a net the switcher casts when it builds its candidate list.
enum SwitchScope: String, CaseIterable {
    /// v1 behaviour: apps with a window on the display under the mouse pointer.
    case currentDisplay
    /// Apps with any window on a currently-visible space (any display).
    case visibleSpaces
    /// Apps with any window at all, including windows on other spaces.
    case allWindows

    var title: String {
        switch self {
        case .currentDisplay: return "Apps on the current display"
        case .visibleSpaces:  return "Windows on visible spaces"
        case .allWindows:     return "All app windows"
        }
    }

    var detail: String {
        switch self {
        case .currentDisplay:
            return "Only apps with a window on the display under the pointer. Committing raises that window."
        case .visibleSpaces:
            return "Apps with a window on any space that is currently on screen, across every display."
        case .allWindows:
            return "Every app that has a window anywhere, including on other spaces. Committing may switch spaces."
        }
    }
}

/// The user's persisted preferences. Owned by `AppController`, shared with
/// `SwitcherController` (reads `scope` at the start of each session) and the
/// settings window (binds to it). Backed by `UserDefaults`.
final class Settings: ObservableObject {
    private enum Key {
        static let scope = "switchScope"
    }

    private let defaults: UserDefaults

    @Published var scope: SwitchScope {
        didSet { defaults.set(scope.rawValue, forKey: Key.scope) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Key.scope)
        scope = raw.flatMap(SwitchScope.init(rawValue:)) ?? .currentDisplay
    }
}
