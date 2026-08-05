#!/usr/bin/env bash
# Install the AppImage into ~/Applications and register a proper menu entry.
#
# Without this, the running window falls back to its raw app_id ("claude-science")
# and a generic icon, because nothing in ~/.local/share/applications claims it.
#
# Usage: scripts/install-desktop.sh [path/to/Claude-Science-*.AppImage]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPIMAGE="${1:-$(ls -1 "$REPO_DIR"/dist/Claude-Science-*.AppImage 2>/dev/null | head -n1)}"

if [[ -z "${APPIMAGE:-}" || ! -f "$APPIMAGE" ]]; then
  echo "No AppImage found. Build one first: npm run dist" >&2
  exit 1
fi

APP_ID="claude-science"                       # must match the window's app_id / StartupWMClass
INSTALL_DIR="$HOME/Applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
DESKTOP_DIR="$HOME/.local/share/applications"
TARGET="$INSTALL_DIR/Claude-Science.AppImage"

mkdir -p "$INSTALL_DIR" "$ICON_DIR" "$DESKTOP_DIR"

install -m 755 "$APPIMAGE" "$TARGET"
install -m 644 "$REPO_DIR/build/icon.png" "$ICON_DIR/$APP_ID.png"

# AppImages need libfuse2 to self-mount; fall back to extract-and-run without it.
if ldconfig -p 2>/dev/null | grep -q 'libfuse\.so\.2'; then
  EXEC_LINE="$TARGET %U"
else
  EXEC_LINE="$TARGET --appimage-extract-and-run %U"
  echo "note: libfuse.so.2 not found — the launcher will use --appimage-extract-and-run."
  echo "      'sudo apt install libfuse2t64' then re-run this script for a faster start."
fi

cat > "$DESKTOP_DIR/$APP_ID.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Claude Science
GenericName=Local research workspace
Comment=Run Claude on your data, locally
Exec=$EXEC_LINE
Icon=$APP_ID
Terminal=false
StartupNotify=true
StartupWMClass=$APP_ID
Categories=Science;DataVisualization;
Keywords=Claude;AI;Research;Bioinformatics;
EOF
chmod 644 "$DESKTOP_DIR/$APP_ID.desktop"

command -v update-desktop-database >/dev/null && update-desktop-database "$DESKTOP_DIR" || true
command -v gtk-update-icon-cache >/dev/null &&
  gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true

echo "Installed:"
echo "  app     $TARGET"
echo "  icon    $ICON_DIR/$APP_ID.png"
echo "  entry   $DESKTOP_DIR/$APP_ID.desktop"
echo "It should appear as \"Claude Science\" in the app list (log out/in if the menu is cached)."
