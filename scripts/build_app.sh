#!/usr/bin/env bash
#
# Builds vimotion in release mode and assembles a macOS .app bundle in ./dist,
# plus the zip + sha256 consumed by the in-app updater.
# Run on macOS (requires the Swift toolchain / Xcode command line tools).
#
#   ./scripts/build_app.sh
#   VERSION=1.2.0-beta.3 BUILD_NUMBER=42 ./scripts/build_app.sh
#
# Signing: uses $VIMOTION_SIGN_IDENTITY, else a "vimotion-codesign" certificate,
# else the first codesigning identity in the keychain, else ad-hoc (see README).
#
set -euo pipefail

APP_NAME="vimotion"
BUNDLE_ID="com.antonioaren.vimotion"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"
PLIST="$APP_DIR/Contents/Info.plist"
ZIP_PATH="$DIST_DIR/$APP_NAME.zip"

VERSION="${VERSION:-$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || echo 1)}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
    echo "✗ VERSION '$VERSION' is not SemVer (X.Y.Z or X.Y.Z-pre)" >&2
    exit 1
fi

echo "▸ Building release binary (v$VERSION, build $BUILD_NUMBER)…"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/$APP_NAME"
if [[ ! -f "$BIN_PATH" ]]; then
    echo "✗ Built binary not found at $BIN_PATH" >&2
    exit 1
fi

echo "▸ Assembling app bundle…"
rm -rf "$APP_DIR" "$ZIP_PATH" "$ZIP_PATH.sha256"
mkdir -p "$MACOS_DIR" "$RES_DIR"
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$PLIST"
[[ -f "$ROOT_DIR/Resources/vimotion.icns" ]] && cp "$ROOT_DIR/Resources/vimotion.icns" "$RES_DIR/vimotion.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST"

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

echo "▸ Packaging update archive…"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
(cd "$DIST_DIR" && shasum -a 256 "$APP_NAME.zip" | awk '{print $1}' > "$APP_NAME.zip.sha256")

echo "✓ Done: $APP_DIR (v$VERSION)"
echo "  Update archive: $ZIP_PATH"
echo "  SHA-256: $(cat "$ZIP_PATH.sha256")"
echo
echo "Next steps:"
echo "  1. Move $APP_NAME.app to /Applications (recommended)."
echo "  2. Launch it. Grant Accessibility access when prompted"
echo "     (System Settings ▸ Privacy & Security ▸ Accessibility)."
echo "  3. Use <leader> + h/j/k/l to move focus. Default leader is Option (⌥)."
echo "  4. (Optional) Add it to System Settings ▸ General ▸ Login Items."
