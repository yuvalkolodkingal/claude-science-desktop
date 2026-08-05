#!/bin/sh
# Launcher inside the Flatpak sandbox.
#
# zypak-wrapper reroutes Chromium's sandbox through the Flatpak portal, which is
# how Electron apps run here without --no-sandbox.
set -e

export TMPDIR="${XDG_RUNTIME_DIR}/app/${FLATPAK_ID}"
mkdir -p "$TMPDIR"

# The daemon is kept on the host filesystem (not inside the sandbox) because it
# is executed on the host via flatpak-spawn — see main.js.
export CLAUDE_SCIENCE_HOST_BIN="${CLAUDE_SCIENCE_HOST_BIN:-$HOME/.local/share/claude-science-desktop/bin/claude-science}"

exec zypak-wrapper /app/electron/electron /app/lib/claude-science-desktop "$@"
