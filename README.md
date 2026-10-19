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
- Swift toolchain (Xcode or the Command Line Tools) — only to build from source

## Download

Grab `vimotion-<version>.dmg` from the
[latest release](https://github.com/antonioaren/vimotion/releases/latest), open
it and drag **vimotion** to **Applications**.

vimotion isn't notarized yet, so the first time macOS may refuse to open it:
right-click the app and choose **Open**. Then grant **Accessibility** access
when prompted.

> **Coming from 1.0.0?** It has no built-in updater. Install a newer `.dmg`
> manually once; from then on updates arrive from the menu bar.

## Updates & beta channel

The menu bar shows the installed version (e.g. `vimotion v1.1.0`, or
`vimotion v1.2.0-beta.3 (Beta)`) and an **Updates** submenu:

| Item | What it does |
|------|--------------|
| **Check for Updates…** | Looks for a newer release on your channel right now |
| **Stable Channel** / **Beta Channel** | Which releases you receive |
| **Check Automatically** | Check on launch and once a day (on by default) |

When an update is found vimotion shows its release notes and offers
**Install and Relaunch**, **Later** (it stays in the menu as
*Update to v…*) or **Skip This Version**. Installing downloads `vimotion.zip`
from GitHub Releases, verifies its SHA-256, replaces the app in place and
relaunches it. vimotion must be able to write to the folder it lives in
(`/Applications` is fine for admin users).

- **Stable** receives only stable releases (`v1.2.0`).
- **Beta** also receives pre-releases (`v1.2.0-beta.7`), built from the
  `beta/v<version>-dev` branches. A stable release always supersedes the betas
  that led to it.
- Switching from **Beta** back to **Stable** offers the latest stable release
  even if it's older than the beta you're running, so you can always go back.

After an update macOS may ask for Accessibility access again (see
[Signing](#signing)).

## Build & install from source

```bash
./scripts/build_app.sh
```

This produces `dist/vimotion.app` (versioned from the `VERSION` file) plus
`dist/vimotion.zip` and its `.sha256`. `./scripts/make_dmg.sh` then wraps the
app in `dist/vimotion-<version>.dmg`. Then:

1. Move `vimotion.app` to `/Applications`.
2. Launch it. Grant **Accessibility** access when prompted
   (System Settings ▸ Privacy & Security ▸ Accessibility) — required to focus
   windows of other apps.
3. Use `⌥ + h/j/k/l` to move focus.
4. (Optional) Add it to **System Settings ▸ General ▸ Login Items** to start at
   login.

The app lives in the menu bar with its version, **Enable**, **Disable**, a
**Leader Key** submenu, the detected displays, an **Updates** submenu, and
**Quit**.

## Develop & test

```bash
swift build          # build
swift test           # run the unit tests (navigation, versions, updater)
```

`swift run` builds have no bundle version, show up as *development build* and
never update themselves.

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

## Releasing

Releases are built and published by GitHub Actions on a macOS runner
(`.github/workflows/`). Each one ships `vimotion-<version>.dmg`,
`vimotion.zip` and `vimotion.zip.sha256`, with generated release notes:

- **What's changed** — a short summary written by an AI model through
  [GitHub Models](https://docs.github.com/en/github-models) (no API key, uses
  the workflow token; prompt in `.github/prompts/release-summary.md`). If the
  model is unavailable, the summary is built from Conventional Commit prefixes
  (`feat:`, `fix:`…) instead.
- **Commits** since the previous release, each with its author.
- **Download** links and the archive's SHA-256.

**Stable:** bump `VERSION`, merge to `master`, then tag:

```bash
git tag v1.2.0 && git push origin v1.2.0
```

The stable workflow also opens a pull request adding the notes to
`CHANGELOG.md` and `docs/releases/v1.2.0.md`. This needs **Settings ▸ Actions ▸
General ▸ Allow GitHub Actions to create and approve pull requests**.

**Beta:** push to a branch named `beta/v<next-version>-dev`:

```bash
git checkout -b beta/v1.2.0-dev && git push -u origin beta/v1.2.0-dev
```

Every push publishes a pre-release `v1.2.0-beta.<run>` for Beta-channel users.
When it's ready, merge it to `master` and tag `v1.2.0`.

To preview the notes locally: `./scripts/release_notes.sh commits v1.1.0` or
`./scripts/release_notes.sh summary v1.1.0`.

### Signing

macOS ties the Accessibility grant to the app's code signature, so with ad-hoc
signing users must re-grant Accessibility after each update (see
[Keeping the Accessibility permission across rebuilds](#keeping-the-accessibility-permission-across-rebuilds)).
To sign releases with a stable identity (a Developer ID, or the self-signed
`vimotion-codesign` certificate):

1. Export the certificate and its private key as a `.p12`.
2. Add repository secrets `MACOS_CERT_P12` (`base64 -i cert.p12`) and
   `MACOS_CERT_PASSWORD`.

The release workflow imports it and passes it to `build_app.sh` as
`VIMOTION_SIGN_IDENTITY`; without the secrets it falls back to ad-hoc signing.

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
| `Updates/` | `AppVersion` (SemVer), `UpdateSelector` (pure: what to offer per channel), GitHub release client, installer, update flow |
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
