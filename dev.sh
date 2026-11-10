#!/usr/bin/env bash
set -euo pipefail

# Build and run "FootballMenuBar Dev", a separate copy of the app for
# development, alongside any installed FootballMenuBar:
#
#   ./dev.sh               build, install and (re)launch the dev copy
#   ./dev.sh --no-launch   build and install it, but don't launch it
#
# The dev copy has its own bundle ID (so its own settings) and always lives at
# ~/Applications/FootballMenuBar Dev.app, a fixed location so macOS keeps
# remembering its menu bar slot. Only a running dev copy is quit, matched by
# its executable path; the installed app is never touched. No zip is made.

cd "$(dirname "$0")"

LAUNCH=1
case "${1:-}" in
    "") ;;
    --no-launch) LAUNCH=0 ;;
    *) echo "Usage: ./dev.sh [--no-launch]" >&2; exit 2 ;;
esac

NAME="FootballMenuBar Dev"
BUNDLE_ID="com.local.footballmenubar.dev"
INSTALL_DIR="${HOME}/Applications"
APP="${INSTALL_DIR}/${NAME}.app"
EXE="${APP}/Contents/MacOS/FootballMenuBar"
# Assembled here first, so a failed build leaves a running dev copy alone.
STAGED=".build/dev-app/${NAME}.app"

scripts/bundle-app.sh \
    --output "${STAGED}" \
    --bundle-id "${BUNDLE_ID}" \
    --name "${NAME}" \
    --display-name "${NAME}" \
    --version "${VERSION:-1.0.0}"

# PIDs of processes running exactly the dev copy's executable. `ps -o comm`
# prints each process's full executable path on macOS.
dev_pids() {
    ps -axo pid=,comm= | while read -r pid comm; do
        if [[ "${comm}" == "${EXE}" ]]; then echo "${pid}"; fi
    done
}

pids="$(dev_pids)"
if [[ -n "${pids}" ]]; then
    echo "==> Quitting the running ${NAME}"
    # shellcheck disable=SC2086 # one PID per word
    kill ${pids} 2>/dev/null || true
    for _ in {1..50}; do
        [[ -z "$(dev_pids)" ]] && break
        sleep 0.1
    done
    if [[ -n "$(dev_pids)" ]]; then
        echo "Error: ${NAME} didn't quit (PIDs: $(dev_pids | xargs))" >&2
        exit 1
    fi
fi

echo "==> Installing ${APP}"
mkdir -p "${INSTALL_DIR}"
rm -rf "${APP}"
ditto "${STAGED}" "${APP}"

if [[ "${LAUNCH}" == 1 ]]; then
    echo "==> Launching ${APP}"
    open "${APP}"
else
    echo "==> Done: ${APP} (not launched)"
fi
