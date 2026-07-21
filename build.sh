#!/usr/bin/env bash
set -euo pipefail

# Build a menu-bar-only FootballMenuBar.app bundle.

cd "$(dirname "$0")"

APP_NAME="FootballMenuBar"
BUNDLE="${APP_NAME}.app"
BUNDLE_ID="com.local.footballmenubar"
# Must match the git tag / GitHub Release (tag "v1.0.0" => VERSION "1.0.0")
# and the `version` field in the Homebrew cask. Overridable via env so CI can
# derive it from the pushed tag, e.g. `VERSION=1.2.3 ./build.sh`.
VERSION="${VERSION:-1.0.0}"

echo "==> Building release binary"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${APP_NAME}"
if [[ ! -f "${BIN_PATH}" ]]; then
    echo "Error: built binary not found at ${BIN_PATH}" >&2
    exit 1
fi

echo "==> Assembling ${BUNDLE}"
rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS"
mkdir -p "${BUNDLE}/Contents/Resources"

cp "${BIN_PATH}" "${BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Resources/AppIcon.icns" "${BUNDLE}/Contents/Resources/AppIcon.icns"

cat > "${BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>Football Menu Bar</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Re-sign ad-hoc with an explicit identifier so the bundle id is bound into the
# signature. Without this, UNUserNotificationCenter.current() can't resolve the
# running app's bundle and crashes ("bundleProxyForCurrentProcess is nil"), so
# notifications never deliver.
echo "==> Signing ${BUNDLE}"
codesign --force --sign - --identifier "${BUNDLE_ID}" "${BUNDLE}"

# Zip the .app bundle for distribution via the Homebrew cask / GitHub Release.
# `ditto -c -k --keepParent` is the macOS-correct way to zip an .app: it
# preserves the bundle structure, symlinks, and resource forks.
ZIP="${APP_NAME}-${VERSION}.zip"
echo "==> Zipping ${ZIP}"
rm -f "${ZIP}"
ditto -c -k --keepParent "${BUNDLE}" "${ZIP}"

echo "==> Done: ${BUNDLE} and ${ZIP}"
echo "Run it with:      open ${BUNDLE}"
echo "sha256 (for cask):"
shasum -a 256 "${ZIP}"
