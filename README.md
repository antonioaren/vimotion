# vimotion

Minimal macOS utility to move window focus with Vim-style keys — `Option + h/j/k/l` —
without touching the mouse. No tiling, no resize, no virtual desktops. Just
directional focus between windows, and between displays when you reach an edge.

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

Navigation first looks for a window on the **active display** — the monitor
that holds the currently focused window.

## Multiple displays

vimotion reads the display arrangement you set in **System Settings ▸
Displays** and refreshes it automatically whenever a monitor is connected,
disconnected or rearranged. No extra configuration is needed.

When there is no window left in the requested direction on the active display,
vimotion jumps to the display adjacent in that direction. For example, with the
laptop as the main display and an external monitor arranged right above it,
`⌥ + k` from the topmost laptop window moves to:

1. the **last window you focused** on the external monitor, or
2. if there is none (or it was closed or moved away), the **frontmost window**
   on that monitor.

`⌥ + j` from there brings you back to the window you left on the laptop. The
same applies to monitors arranged to the left, right or below. The menu bar
shows the detected arrangement (e.g. `2 displays: Built-in Retina Display
(primary), DELL U2720Q above`).

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
submenu, the detected displays, and **Quit**.

## Develop & test

```bash
swift build          # build
swift test           # run the navigation unit tests
```

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
          ├─ DisplayLayout          → pure: adjacent display when nothing is left
          ├─ ScreenFocusMemory      → last focused window per display
          └─ WindowFocuser          → raise + activate the target

ScreenChangeObserver (display connected / rearranged)
   └─▶ AppCoordinator.reloadDisplays → rebuild DisplayLayout
```

| Module | Responsibility |
|--------|----------------|
| `Navigation/` | `Direction`, `DirectionalNavigator`, `FocusHistory`, `ScreenFocusMemory` (pure logic) |
| `Windows/` | enumerate windows, display layout and changes, filter by display, focus a window |
| `Hotkeys/` | `LeaderKey`, `Shortcut`, Carbon-based global hotkeys |
| `Permissions/` | Accessibility permission handling |
| `App/` | coordinator, menu bar, preferences, lifecycle |

Services sit behind protocols (`WindowEnumerating`, `HotkeyManaging`,
`ScreenProviding`, `ScreenChangeObserving`) so they can be mocked in tests or swapped later (e.g. a
`CGEventTap` hotkey backend) without touching the core.

See [PRD.md](PRD.md), [REQUIREMENTS.md](REQUIREMENTS.md) and [TASK.md](TASK.md)
for the full design.

## Roadmap (not in v1)

- Config file for custom bindings
- Cyclic / by-number navigation
- Visual highlight of the target window
- Spaces / fullscreen support
