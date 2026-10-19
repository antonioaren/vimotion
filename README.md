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
**Leader Key** submenu, an **Updates** submenu, and **Quit**.

## Develop & test

```bash
swift build          # build
swift test           # run the unit tests (navigation, versions, updater)
```

`swift run` builds have no bundle version, show up as *development build* and
never update themselves.

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

macOS ties the Accessibility grant to the app's code signature. With the
default ad-hoc signature every build looks like a new app, so users must
re-grant Accessibility after each update. To avoid that, sign releases with a
stable identity (a Developer ID, or a self-signed code-signing certificate
created in Keychain Access ▸ Certificate Assistant):

1. Export the certificate and its private key as a `.p12`.
2. Add repository secrets `MACOS_CERT_P12` (`base64 -i cert.p12`) and
   `MACOS_CERT_PASSWORD`.

The release workflow imports it and passes it to `build_app.sh` as
`SIGN_IDENTITY`; without the secrets it falls back to ad-hoc signing. Locally:
`SIGN_IDENTITY="My Cert" ./scripts/build_app.sh`.

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
| `Updates/` | `AppVersion` (SemVer), `UpdateSelector` (pure: what to offer per channel), GitHub release client, installer, update flow |
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
