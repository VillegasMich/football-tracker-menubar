#!/usr/bin/env bash
set -euo pipefail

# Build the release binary and assemble it into a signed, menu-bar-only .app
# bundle. Shared by build.sh (the release app) and dev.sh (the dev app), which
# differ only in the identity they pass in:
#
#   scripts/bundle-app.sh --output <path/to/Name.app> --bundle-id <id> \
#       --name <CFBundleName> --display-name <CFBundleDisplayName> \
#       --version <version>
#
# --version sets both CFBundleShortVersionString and CFBundleVersion.
# Any existing bundle at --output is replaced.

cd "$(dirname "$0")/.."

EXECUTABLE="FootballMenuBar"

usage() {
    echo "Usage: scripts/bundle-app.sh --output <Name.app> --bundle-id <id>" \
        "--name <name> --display-name <name> --version <version>" >&2
    exit 2
}

OUTPUT="" BUNDLE_ID="" NAME="" DISPLAY_NAME="" VERSION=""
while [[ $# -gt 0 ]]; do
    [[ $# -ge 2 ]] || usage
    case "$1" in
        --output) OUTPUT="$2" ;;
        --bundle-id) BUNDLE_ID="$2" ;;
        --name) NAME="$2" ;;
        --display-name) DISPLAY_NAME="$2" ;;
        --version) VERSION="$2" ;;
        *) usage ;;
    esac
    shift 2
done
[[ -n "${OUTPUT}" && -n "${BUNDLE_ID}" && -n "${NAME}" && -n "${DISPLAY_NAME}" && -n "${VERSION}" ]] || usage
[[ "${OUTPUT}" == *.app ]] || { echo "Error: --output must end in .app" >&2; exit 2; }

echo "==> Building release binary"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${EXECUTABLE}"
if [[ ! -f "${BIN_PATH}" ]]; then
    echo "Error: built binary not found at ${BIN_PATH}" >&2
    exit 1
fi

echo "==> Assembling ${OUTPUT}"
rm -rf "${OUTPUT}"
mkdir -p "${OUTPUT}/Contents/MacOS"
mkdir -p "${OUTPUT}/Contents/Resources"

cp "${BIN_PATH}" "${OUTPUT}/Contents/MacOS/${EXECUTABLE}"
chmod +x "${OUTPUT}/Contents/MacOS/${EXECUTABLE}"
cp "Resources/AppIcon.icns" "${OUTPUT}/Contents/Resources/AppIcon.icns"

cat > "${OUTPUT}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
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
echo "==> Signing ${OUTPUT} as ${BUNDLE_ID}"
codesign --force --sign - --identifier "${BUNDLE_ID}" "${OUTPUT}"
