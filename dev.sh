#!/usr/bin/env bash
set -euo pipefail

# Restart the app with the latest code: kill any running instance, rebuild the
# .app bundle, and launch it again. Handy for seeing UI changes quickly.

cd "$(dirname "$0")"

APP_NAME="FootballMenuBar"
BUNDLE="${APP_NAME}.app"

echo "==> Stopping any running ${APP_NAME}"
# -x matches the exact process name; ignore "no process found" (exit 1).
pkill -x "${APP_NAME}" 2>/dev/null && sleep 1 || true

echo "==> Rebuilding bundle"
./build.sh

echo "==> Launching ${BUNDLE}"
open "${BUNDLE}"
