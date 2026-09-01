# MacTaskSwitcher

A native macOS replacement for the Cmd+Tab app switcher that only cycles through
apps on the **active display** — the screen your mouse pointer is on.

## Why

With multiple monitors, the built-in switcher mixes every app together and often
brings a window forward on the wrong screen. MacTaskSwitcher scopes Cmd+Tab to
one display and raises the app's window that actually lives there.

## Requirements

- macOS 14+
- Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build & run

```sh
xcodegen generate
open MacTaskSwitcher.xcodeproj   # then Run, or:
xcodebuild -project MacTaskSwitcher.xcodeproj -scheme MacTaskSwitcher \
  -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
```

On first launch, grant **Accessibility** access in
System Settings ▸ Privacy & Security ▸ Accessibility (also **Input Monitoring**
if prompted). The app runs as a menu-bar item with no Dock icon.

## Production build

```sh
TEAM_ID=XXXXXXXXXX ./Scripts/build-release.sh
```

Produces a Developer ID–signed, notarized, stapled installer DMG at
`build/MacTaskSwitcher-<version>.dmg` (drag the app to the Applications alias).
Requires an Apple Developer account and a one-time
`xcrun notarytool store-credentials MacTaskSwitcher …` (see the script header).
Distribution is direct-download only — not the Mac App Store (which requires the
sandbox this app can't use).

## Usage

- **Cmd+Tab** / **Cmd+Shift+Tab** — cycle forward / backward through apps on the
  display under the pointer.
- Release **Cmd** to switch. **Esc** cancels.
- Menu-bar item: toggle *Launch at Login*, quit.

## Status

v1: per-display app switching works. Per-window cycling within an app is planned
(see `CLAUDE.md`).
