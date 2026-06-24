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

echo "▸ Ad-hoc code signing (keeps the Accessibility grant stable across rebuilds)…"
codesign --force --deep --sign - "$APP_DIR"

echo "✓ Done: $APP_DIR"
echo
echo "Next steps:"
echo "  1. Move $APP_NAME.app to /Applications (recommended)."
echo "  2. Launch it. Grant Accessibility access when prompted"
echo "     (System Settings ▸ Privacy & Security ▸ Accessibility)."
echo "  3. Use <leader> + h/j/k/l to move focus. Default leader is Option (⌥)."
echo "  4. (Optional) Add it to System Settings ▸ General ▸ Login Items."
