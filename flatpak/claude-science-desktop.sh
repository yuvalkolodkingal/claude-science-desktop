#!/bin/sh
# Launcher inside the Flatpak sandbox.
#
# zypak-wrapper reroutes Chromium's sandbox through the Flatpak portal, which is
# how Electron apps run without --no-sandbox here.
set -e

export TMPDIR="${XDG_RUNTIME_DIR}/app/${FLATPAK_ID}"
mkdir -p "$TMPDIR"

# extra-data lands here at install time; the wrapper prefers this over PATH.
export CLAUDE_SCIENCE_BIN="${CLAUDE_SCIENCE_BIN:-/app/extra/claude-science}"

exec zypak-wrapper /app/electron/electron /app/lib/claude-science-desktop "$@"
