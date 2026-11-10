#!/usr/bin/env bash
set -euo pipefail

# Build the release FootballMenuBar.app bundle (com.local.footballmenubar) in
# the project root and zip it for the GitHub Release / Homebrew cask. For
# day-to-day development use ./dev.sh, which builds a separate dev copy.

cd "$(dirname "$0")"

APP_NAME="FootballMenuBar"
BUNDLE="${APP_NAME}.app"
BUNDLE_ID="com.local.footballmenubar"
# Must match the git tag / GitHub Release (tag "v1.0.0" => VERSION "1.0.0")
# and the `version` field in the Homebrew cask. Overridable via env so CI can
# derive it from the pushed tag, e.g. `VERSION=1.2.3 ./build.sh`. It is also
# the app's displayed version (CFBundleShortVersionString and CFBundleVersion).
VERSION="${VERSION:-1.0.0}"

scripts/bundle-app.sh \
    --output "${BUNDLE}" \
    --bundle-id "${BUNDLE_ID}" \
    --name "${APP_NAME}" \
    --display-name "Football Menu Bar" \
    --version "${VERSION}"

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
