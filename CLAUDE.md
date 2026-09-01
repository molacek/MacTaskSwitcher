# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A native macOS agent app that replaces the built-in Cmd+Tab switcher. Pressing
Cmd+Tab cycles only through apps that have a window on the **display under the
mouse pointer**, and committing raises that app's window on that display (not
whatever window happens to be focused on another monitor).

Status: v1 scaffold. App-level per-display switching works end to end.
Per-window cycling within an app is designed for but not wired up (see below).

## Commands

```sh
xcodegen generate          # regenerate MacTaskSwitcher.xcodeproj from project.yml (run after adding/moving files)
open MacTaskSwitcher.xcodeproj

# Build from CLI
xcodebuild -project MacTaskSwitcher.xcodeproj -scheme MacTaskSwitcher -configuration Debug \
  -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO

# Run the built app (agent app: no Dock icon, look for the menu-bar item)
open ~/Library/Developer/Xcode/DerivedData/MacTaskSwitcher-*/Build/Products/Debug/MacTaskSwitcher.app
```

The `.xcodeproj` is git-ignored and generated; edit `project.yml`, not the
project file. `xcodegen` is installed via Homebrew.

### Production build

```sh
TEAM_ID=XXXXXXXXXX ./Scripts/build-release.sh
```

Archives Release → exports a **Developer ID**–signed `.app` → notarizes and
staples it → packages it into a drag-to-Applications `.dmg` (via `hdiutil`) →
signs, notarizes, and staples the DMG. Output: `build/MacTaskSwitcher-<version>.dmg`.
Notarization uses `--keychain-profile MacTaskSwitcher`, set up once via
`xcrun notarytool store-credentials`.

Not distributable via the Mac App Store: the App Store mandates the App Sandbox,
which the event tap and AX window-raising cannot run under. Direct download /
Developer ID only. A real signing identity also gives a stable TCC identity, so
users grant Accessibility once instead of after every update.

There is no test target yet. When adding one, add it under `targets:` in
`project.yml` and run a single test with
`xcodebuild test ... -only-testing:MacTaskSwitcherTests/SomeTests/testCase`.

## Permissions (required at runtime)

The app is **not sandboxed** (`Sources/MacTaskSwitcher.entitlements`) and cannot
be — both core mechanisms are blocked by the App Sandbox:

- **CGEventTap** to intercept/consume Cmd+Tab — needs **Accessibility** (and, on
  some macOS versions, **Input Monitoring**) granted to the app.
- **Accessibility (AX) API** to raise a specific window on a display.

After each rebuild the code signature changes and macOS may drop the granted
permission; you re-grant in System Settings ▸ Privacy & Security ▸ Accessibility.

On launch `AppController` calls `interceptor.start()`. If it fails (missing
grant), `PermissionsMonitor` fires the system prompt, shows an explanatory
dialog with *Open System Settings* / *Quit*, then polls once a second — each
tick retrying `interceptor.start()` — until the tap installs, then shows a
one-time "MacTaskSwitcher is active" confirmation. `HotkeyInterceptor.start()`
is idempotent (returns `true` immediately if the tap already exists), which is
what makes it usable as the monitor's probe.

## Architecture

Everything is driven from `AppController` (`Sources/App/AppController.swift`),
which owns three long-lived objects. Flow of one Cmd+Tab session:

```
CGEventTap (HotkeyInterceptor)
    │  keyDown: Cmd+Tab  → consume, emit .advance(reverse:)
    │  flagsChanged: Cmd released → emit .commit
    │  keyDown: Esc during session → emit .cancel
    ▼
SwitcherController.handle(SwitchAction)      ← session state machine
    │  begin(): snapshot candidates once, show overlay
    │  .advance → move index, overlay.select()
    │  .commit  → targets[index].activate()
    ▼
DisplayResolver.activeDisplay()   → NSScreen under NSEvent.mouseLocation
WindowEnumerator.appTargets(on:mru:)
    │  CGWindowListCopyWindowInfo (front-to-back), layer 0, size/alpha filtered
    │  CG rect → Cocoa rect (flip by primary-screen height)
    │  keep window if ≥50% of its area is on the target screen
    │  one SwitchTarget per app; first window seen = its frontWindowID
    │  order: MRUTracker order first, then remaining z-order
    ▼
SwitchTarget.activate()
    │  NSRunningApplication.activate()
    └  AXWindowRaiser.raise(windowID:pid:)  ← _AXUIElementGetWindow bridge
```

### Key files

| File | Role |
|---|---|
| `Sources/Input/HotkeyInterceptor.swift` | The CGEventTap. Consume/pass-through decision is synchronous; tap source is on the **main run loop**, so `onAction` fires on the main thread. |
| `Sources/Switching/SwitcherController.swift` | Session lifecycle. Candidate list is snapshotted once per session in `begin()`, never mid-cycle. |
| `Sources/Switching/WindowEnumerator.swift` | The per-display filtering logic — the heart of the product. Coordinate-space flip lives here. |
| `Sources/Switching/DisplayResolver.swift` | "Active display" = screen under the mouse. Change the policy here if that decision is revisited. |
| `Sources/Switching/MRUTracker.swift` | App MRU order: seeded at launch from window-server stacking, then kept exact via NSWorkspace activate/terminate notifications. Sole sort key for the list. |
| `Sources/Switching/AXWindowRaiser.swift` | `@_silgen_name("_AXUIElementGetWindow")` private bridge to match a CGWindowID to an AXUIElement and raise it. |
| `Sources/UI/OverlayPanel.swift` | `.nonactivatingPanel` — must never activate our app or the commit-on-Cmd-release logic targets the wrong app. |
| `Sources/UI/OverlayView.swift` | Hand-drawn HUD, no Auto Layout, no per-frame allocations. |
| `Sources/System/PermissionsMonitor.swift` | First-launch request dialog + 1 Hz poll that retries `interceptor.start()` until it takes. |
| `Sources/System/LoginItem.swift` | `SMAppService.mainApp` self-registration, no helper target. |

### Design constraints to preserve

- **Agent app**: `LSUIElement` + `setActivationPolicy(.accessory)`. No Dock icon,
  no main menu. The `NSStatusItem` is the only persistent UI.
- **Never let the overlay activate the app.** Non-activating panel, and nothing
  in the switch path should call `NSApp.activate()`.
- **Snapshot once per session.** Rebuilding the candidate list on every Tab press
  would let z-order changes reorder the list under the user.
- **`begin()` sets `index = 0` (the current app).** The `.advance` that opened
  the session then moves to index 1, so one Cmd+Tab + release toggles the two
  most-recent apps. Don't pre-advance in `begin()`.
- **Keep the event-tap callback cheap.** It runs on the main run loop; heavy or
  blocking work there risks `tapDisabledByTimeout`. If work grows, move the tap
  to a dedicated thread with its own run loop rather than adding async hops.
- Swift language mode is pinned to **5** (`project.yml`) to keep the C event-tap
  interop simple. Moving to Swift 6 strict concurrency means auditing the tap
  callback and the `@MainActor` boundary in `AppController`.

## Unfinished: per-window cycling

The user asked for "apps + windows". `WindowEnumerator` already sees every
window; only app-level targets are surfaced today. To finish:

1. Give `SwitchTarget` a `.window` case (pid + CGWindowID + title); `activate()`
   already knows how to raise one via `AXWindowRaiser`.
2. Handle backtick (`kVK_ANSI_Grave`, keycode 50) while Cmd is held in
   `HotkeyInterceptor` → a new `SwitchAction` that expands the selected app into
   its windows on the active display.
3. Render the sub-list in `OverlayView`.
