#!/bin/bash
# Post-install hook for the .deb and .rpm packages.
#
# Replaces electron-builder's default after-install script, so it must also do
# what that one did: the /usr/bin symlink and the chrome-sandbox setuid bit.
#
# On top of that it fetches Claude Science itself, so the app is ready to use the
# first time it opens instead of downloading ~152 MB on first launch. Nothing
# Anthropic-authored ships inside the package — this downloads it, on the user's
# own machine, from Anthropic's servers, and refuses anything whose SHA-256 does
# not match Anthropic's published manifest.
#
# Network failures here are not fatal: the app falls back to downloading at
# first run.

APP_DIR="/opt/Claude Science Desktop"
BIN_DIR="$APP_DIR/bin"
DEST="$BIN_DIR/claude-science"
BASE="https://downloads.claude.ai/claude-science"
PLATFORM="linux-x64"

# --- electron-builder's standard post-install work --------------------------

ln -sf "$APP_DIR/claude-science-desktop" "/usr/bin/claude-science-desktop" 2>/dev/null || true

# Chromium's sandbox helper needs to be setuid root.
if [ -f "$APP_DIR/chrome-sandbox" ]; then
  chmod 4755 "$APP_DIR/chrome-sandbox" || true
fi

update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi

# --- fetch Claude Science ----------------------------------------------------

if [ -x "$DEST" ]; then
  exit 0                                  # an upgrade already has it
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "claude-science-desktop: curl not found; Claude Science will download on first launch."
  exit 0
fi

echo "claude-science-desktop: fetching Claude Science from Anthropic…"

manifest="$(curl -fsSL --max-time 30 "$BASE/latest/manifest.json" 2>/dev/null)" || manifest=""
if [ -z "$manifest" ]; then
  echo "claude-science-desktop: could not reach downloads.claude.ai; the app will download it on first launch."
  exit 0
fi

version="$(printf '%s' "$manifest" | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
expected="$(printf '%s' "$manifest" | tr -d ' \n' | sed -n 's/.*"'"$PLATFORM"'":"\([0-9a-f]\{64\}\)".*/\1/p')"

if [ -z "$version" ] || [ -z "$expected" ]; then
  echo "claude-science-desktop: release manifest was unreadable; the app will download it on first launch."
  exit 0
fi

mkdir -p "$BIN_DIR"
if ! curl -fsSL --max-time 900 "$BASE/$version/$PLATFORM" -o "$DEST.part" 2>/dev/null; then
  rm -f "$DEST.part"
  echo "claude-science-desktop: download failed; the app will retry on first launch."
  exit 0
fi

actual="$(sha256sum "$DEST.part" 2>/dev/null | cut -d' ' -f1)"
if [ "$actual" != "$expected" ]; then
  rm -f "$DEST.part"
  echo "claude-science-desktop: checksum mismatch — refusing it. The app will retry on first launch."
  exit 0
fi

chmod 755 "$DEST.part"
mv "$DEST.part" "$DEST"
echo "claude-science-desktop: Claude Science $version installed and verified."

exit 0
