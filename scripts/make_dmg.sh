#!/usr/bin/env bash
#
# Wraps dist/vimotion.app in a drag-to-install disk image:
#   dist/vimotion-<version>.dmg  (vimotion.app + a link to /Applications)
# Run after ./scripts/build_app.sh, on macOS.
#
#   ./scripts/make_dmg.sh
#
set -euo pipefail

APP_NAME="vimotion"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"

if [[ ! -d "$APP_DIR" ]]; then
    echo "✗ $APP_DIR not found. Run ./scripts/build_app.sh first." >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_DIR/Contents/Info.plist")"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

echo "▸ Staging disk image contents…"
ditto "$APP_DIR" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"

echo "▸ Creating $DMG_PATH…"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGING" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG_PATH" >/dev/null

echo "✓ Done: $DMG_PATH"
