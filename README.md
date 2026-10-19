# vimotion

Minimal macOS utility to move window focus with Vim-style keys — `Option + h/j/k/l` —
without touching the mouse. No tiling, no resize, no virtual desktops. Just
directional focus between windows on the active display.

## Why

Tools like `aerospace` or `yabai` solve window navigation but bring a lot of
machinery (tiling, workspaces, resize) you may not need. vimotion does exactly
one thing: move focus directionally.

## Keys

| Shortcut        | Action                  |
|-----------------|-------------------------|
| `⌥ + h`         | Focus window to the left  |
| `⌥ + j`         | Focus window below        |
| `⌥ + k`         | Focus window above        |
| `⌥ + l`         | Focus window to the right |

The direction keys (`h/j/k/l`) are fixed. The **leader key** (`Option` by
default) can be changed from the menu bar (Option / Command / Control /
Control+Option) for anyone who'd rather not use Option.

Navigation is restricted to the **active display** — the monitor that holds the
currently focused app. It won't jump between monitors.

## Requirements

- macOS 13 (Ventura) or newer
- Swift toolchain (Xcode or the Command Line Tools)

## Build & install

```bash
./scripts/build_app.sh
```

This produces `dist/vimotion.app`. Then:

1. Move `vimotion.app` to `/Applications`.
2. Launch it. Grant **Accessibility** access when prompted
   (System Settings ▸ Privacy & Security ▸ Accessibility) — required to focus
   windows of other apps.
3. Use `⌥ + h/j/k/l` to move focus.
4. (Optional) Add it to **System Settings ▸ General ▸ Login Items** to start at
   login.

The app lives in the menu bar with **Enable**, **Disable**, a **Leader Key**
submenu, and **Quit**.

## Develop & test

```bash
swift build          # build
swift test           # run the navigation unit tests
```

### Keeping the Accessibility permission across rebuilds

macOS ties the Accessibility grant to the app's code signature. With an ad-hoc
signature every rebuild counts as a new app: System Settings still lists
vimotion as enabled, but the new build is denied and asks again.

To avoid that, create a self-signed certificate once and `build_app.sh` will use
it automatically:

1. Open **Keychain Access ▸ Certificate Assistant ▸ Create a Certificate…**
2. Name: `vimotion-codesign`, Identity Type: **Self Signed Root**,
   Certificate Type: **Code Signing**. Create it in the **login** keychain.
3. Rebuild with `./scripts/build_app.sh`. If macOS asks whether `codesign` may
   use the key, choose **Always Allow**.
4. Grant Accessibility one last time. Later rebuilds keep it.

The script picks, in order: `$VIMOTION_SIGN_IDENTITY`, the `vimotion-codesign`
certificate, the first valid signing identity in your keychain (e.g. an Apple
Development certificate), and finally ad-hoc. With ad-hoc it resets the stale
grant (`tccutil reset Accessibility com.antonioaren.vimotion`) so macOS asks
cleanly once.

## Architecture

A thin coordinator wires together independent, protocol-backed pieces. The
navigation logic is a pure function with no system dependencies, so it's fully
unit-tested.

```
Hotkey (Option+h/j/k/l)
   └─▶ AppCoordinator
          ├─ WindowEnumerating      → on-screen windows + focused window
          ├─ ScreenFiltering        → keep only the active display
          ├─ DirectionalNavigator   → pure: pick the target window
          └─ WindowFocuser          → raise + activate the target
```

| Module | Responsibility |
|--------|----------------|
| `Navigation/` | `Direction`, `DirectionalNavigator` (pure selection logic) |
| `Windows/` | enumerate windows, filter by display, focus a window |
| `Hotkeys/` | `LeaderKey`, `Shortcut`, Carbon-based global hotkeys |
| `Permissions/` | Accessibility permission handling |
| `App/` | coordinator, menu bar, preferences, lifecycle |

Services sit behind protocols (`WindowEnumerating`, `HotkeyManaging`,
`ScreenProviding`) so they can be mocked in tests or swapped later (e.g. a
`CGEventTap` hotkey backend) without touching the core.

See [PRD.md](PRD.md), [REQUIREMENTS.md](REQUIREMENTS.md) and [TASK.md](TASK.md)
for the full design.

## Roadmap (not in v1)

- Config file for custom bindings
- Cyclic / by-number navigation
- Visual highlight of the target window
- Spaces / fullscreen support
