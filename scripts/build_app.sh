#!/usr/bin/env bash
#
# Builds vimotion in release mode and assembles a macOS .app bundle in ./dist.
# Run on macOS (requires the Swift toolchain / Xcode command line tools).
#
#   ./scripts/build_app.sh
#
set -euo pipefail

APP_NAME="vimotion"
BUNDLE_ID="com.antonioaren.vimotion"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

echo "▸ Building release binary…"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/$APP_NAME"
if [[ ! -f "$BIN_PATH" ]]; then
    echo "✗ Built binary not found at $BIN_PATH" >&2
    exit 1
fi

echo "▸ Assembling app bundle…"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
[[ -f "$ROOT_DIR/Resources/vimotion.icns" ]] && cp "$ROOT_DIR/Resources/vimotion.icns" "$RES_DIR/vimotion.icns"

# macOS ties the Accessibility grant to the app's code signature. An ad-hoc
# signature ("-") is identified by the binary's hash, so every rebuild looks
# like a new app and the existing grant silently stops applying. A real
# identity (self-signed or Apple Development) keeps the grant across rebuilds.
SIGN_IDENTITY="${VIMOTION_SIGN_IDENTITY:-}"
if [[ -z "$SIGN_IDENTITY" ]] && security find-certificate -c "vimotion-codesign" >/dev/null 2>&1; then
    SIGN_IDENTITY="vimotion-codesign"
fi
if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' 'NF > 1 { print $2; exit }' || true)"
fi

if [[ -n "$SIGN_IDENTITY" ]]; then
    echo "▸ Code signing with \"$SIGN_IDENTITY\" (keeps the Accessibility grant across rebuilds)…"
    codesign --force --deep --identifier "$BUNDLE_ID" --sign "$SIGN_IDENTITY" "$APP_DIR"
else
    echo "▸ No signing identity found; falling back to ad-hoc signing…"
    codesign --force --deep --identifier "$BUNDLE_ID" --sign - "$APP_DIR"
    # The previous grant belongs to the old binary; drop it so macOS asks once,
    # cleanly, instead of showing vimotion as enabled while denying access.
    tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
    echo "  ⚠︎ Ad-hoc builds need Accessibility to be granted again after every rebuild."
    echo "    Create a \"vimotion-codesign\" certificate to avoid this (see README)."
fi

echo "✓ Done: $APP_DIR"
echo
echo "Next steps:"
echo "  1. Move $APP_NAME.app to /Applications (recommended)."
echo "  2. Launch it. Grant Accessibility access when prompted"
echo "     (System Settings ▸ Privacy & Security ▸ Accessibility)."
echo "  3. Use <leader> + h/j/k/l to move focus. Default leader is Option (⌥)."
echo "  4. (Optional) Add it to System Settings ▸ General ▸ Login Items."
