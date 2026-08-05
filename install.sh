#!/bin/sh
# Claude Science Desktop installer (Linux, macOS) — unofficial wrapper.
#
#   curl -fsSL https://raw.githubusercontent.com/yuvalkolodkingal/claude-science-desktop/main/install.sh | sh
#
# On Linux it detects your distro and offers the matching native package
# (.deb / .rpm / pacman), a Flatpak, or a self-contained directory in $HOME.
# Pick non-interactively with a flag:
#
#   ... | sh -s -- --native      distro package (needs sudo)
#   ... | sh -s -- --flatpak     Flatpak bundle (per-user, no sudo)
#   ... | sh -s -- --portable    unpack into ~/.local/share (no sudo)
#   ... | sh -s -- --uninstall
#
# This installs the wrapper only. Claude Science itself is Anthropic's and is
# downloaded by the app from downloads.claude.ai on first run, verified against
# Anthropic's published checksum.
set -eu

REPO="yuvalkolodkingal/claude-science-desktop"
APP_ID="claude-science-desktop"
FLATPAK_ID="io.github.yuvalkolodkingal.ClaudeScienceDesktop"
APP_NAME="Claude Science Desktop"

PREFIX="${CSD_PREFIX:-$HOME/.local}"
APP_DIR="$PREFIX/share/$APP_ID"
BIN_DIR="$PREFIX/bin"
DESKTOP_DIR="$PREFIX/share/applications"
ICON_DIR="$PREFIX/share/icons/hicolor/512x512/apps"
MAC_APP_DIR="${CSD_MAC_PREFIX:-$HOME/Applications}"

MODE=""

say()  { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
need() { have "$1" || die "$1 is required but not installed"; }

# --- platform + distro ------------------------------------------------------

detect_platform() {
  case "$(uname -s)" in
    Linux)  OS=linux ;;
    Darwin) OS=mac ;;
    *) die "unsupported OS: $(uname -s). Windows users: see install.ps1" ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64)  ARCH=x64 ;;
    aarch64|arm64) ARCH=arm64 ;;
    *) die "unsupported architecture: $(uname -m)" ;;
  esac
  [ "$OS" = linux ] && [ "$ARCH" != x64 ] &&
    die "Claude Science only ships a linux-x64 build, so the wrapper is x64-only too"
  return 0
}

# Sets FAMILY (debian|rpm|arch|unknown), DISTRO (pretty name) and NATIVE_ASSET.
detect_distro() {
  DISTRO="Linux"
  [ -r /etc/os-release ] && DISTRO="$(. /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-${NAME:-Linux}}")"

  if have apt-get || have dpkg; then
    FAMILY=debian; NATIVE_ASSET="$APP_ID-linux-amd64.deb"; NATIVE_CMD="apt"
  elif have dnf || have zypper || have rpm; then
    FAMILY=rpm; NATIVE_ASSET="$APP_ID-linux-x86_64.rpm"
    if have dnf; then NATIVE_CMD="dnf"; elif have zypper; then NATIVE_CMD="zypper"; else NATIVE_CMD="rpm"; fi
  elif have pacman; then
    FAMILY=arch; NATIVE_ASSET="$APP_ID-linux-x64.pacman"; NATIVE_CMD="pacman"
  else
    FAMILY=unknown; NATIVE_ASSET=""; NATIVE_CMD=""
  fi
}

# --- uninstall --------------------------------------------------------------

uninstall() {
  detect_platform
  removed=0

  if [ "$OS" = mac ]; then
    if [ -d "$MAC_APP_DIR/$APP_NAME.app" ]; then
      rm -rf "$MAC_APP_DIR/$APP_NAME.app"; say "Removed $MAC_APP_DIR/$APP_NAME.app"; removed=1
    fi
  else
    if have flatpak && flatpak info "$FLATPAK_ID" >/dev/null 2>&1; then
      flatpak uninstall -y "$FLATPAK_ID" && say "Removed the Flatpak."; removed=1
    fi
    if have dpkg && dpkg -s "$APP_ID" >/dev/null 2>&1; then
      sudo dpkg -r "$APP_ID" && say "Removed the .deb."; removed=1
    fi
    if have rpm && rpm -q "$APP_ID" >/dev/null 2>&1; then
      sudo rpm -e "$APP_ID" && say "Removed the .rpm."; removed=1
    fi
    if have pacman && pacman -Q "$APP_ID" >/dev/null 2>&1; then
      sudo pacman -R --noconfirm "$APP_ID" && say "Removed the pacman package."; removed=1
    fi
    if [ -d "$APP_DIR" ]; then
      rm -rf "$APP_DIR"
      rm -f "$BIN_DIR/$APP_ID" "$DESKTOP_DIR/$APP_ID.desktop" "$ICON_DIR/$APP_ID.png"
      have update-desktop-database && update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
      say "Removed the portable install."; removed=1
    fi
  fi

  [ "$removed" = 1 ] || say "Nothing to uninstall."
  say ""
  say "Claude Science itself and your data were not touched. To remove those too:"
  say "  claude-science stop  &&  rm -rf ~/.claude-science"
  exit 0
}

# --- download + verify ------------------------------------------------------

# Version-free asset names let /releases/latest/download/<asset> stay valid
# forever, so the installer never touches the rate-limited GitHub API.
asset_url() {
  if [ -n "${CSD_BASE_URL:-}" ]; then printf '%s/%s' "$CSD_BASE_URL" "$1"
  elif [ -n "${CSD_VERSION:-}" ]; then printf 'https://github.com/%s/releases/download/%s/%s' "$REPO" "$CSD_VERSION" "$1"
  else printf 'https://github.com/%s/releases/latest/download/%s' "$REPO" "$1"
  fi
}

asset_exists() {
  curl -fsIL -o /dev/null --max-time 15 "$(asset_url "$1")" 2>/dev/null
}

sha256_of() {
  if have sha256sum; then sha256sum "$1" | cut -d' ' -f1
  elif have shasum; then shasum -a 256 "$1" | cut -d' ' -f1
  else die "need sha256sum or shasum to verify the download"
  fi
}

fetch() {
  name="$1"; dest="$2"
  say "  downloading $name"
  curl -fL --progress-bar "$(asset_url "$name")" -o "$dest" || die "$name is not in this release.
Some packages are built by CI and land a few minutes after the release is cut.
Try another install mode — sh -s -- --portable  (or --native) — or see
  https://github.com/$REPO/releases/latest"

  if curl -fsSL "$(asset_url SHA256SUMS)" -o "$dest.sums" 2>/dev/null; then
    expected="$(grep -F "  $name" "$dest.sums" | cut -d' ' -f1 | head -n1)"
    [ -n "$expected" ] || die "$name is missing from SHA256SUMS"
    actual="$(sha256_of "$dest")"
    [ "$actual" = "$expected" ] || die "checksum mismatch for $name
  expected $expected
  got      $actual"
    say "  verified sha256 $actual"
  else
    warn "  warning: no SHA256SUMS in this release — cannot verify the download"
  fi
}

# --- install modes ----------------------------------------------------------

install_native() {
  tmp="$1"
  fetch "$NATIVE_ASSET" "$tmp/$NATIVE_ASSET"
  say ""
  say "Installing with sudo $NATIVE_CMD…"
  case "$FAMILY" in
    debian)
      if have apt; then sudo apt install -y "$tmp/$NATIVE_ASSET"
      else sudo dpkg -i "$tmp/$NATIVE_ASSET" || sudo apt-get -f install -y; fi ;;
    rpm)
      case "$NATIVE_CMD" in
        dnf)    sudo dnf install -y "$tmp/$NATIVE_ASSET" ;;
        zypper) sudo zypper --non-interactive install --allow-unsigned-rpm "$tmp/$NATIVE_ASSET" ;;
        *)      sudo rpm -i "$tmp/$NATIVE_ASSET" ;;
      esac ;;
    arch) sudo pacman -U --noconfirm "$tmp/$NATIVE_ASSET" ;;
  esac
  say ""
  say "Installed $APP_NAME — launch it from your app menu or run: $APP_ID"
}

install_flatpak() {
  tmp="$1"
  need flatpak
  bundle="$APP_ID-x86_64.flatpak"
  fetch "$bundle" "$tmp/$bundle"
  say ""
  say "Installing the Flatpak (per-user)…"
  flatpak install --user -y --noninteractive "$tmp/$bundle" ||
    die "flatpak install failed — you may need the Flathub remote:
  flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo"
  say ""
  say "Installed. Launch it from your app menu, or: flatpak run $FLATPAK_ID"
}

install_portable() {
  tmp="$1"
  tarball="$APP_ID-linux-$ARCH.tar.gz"
  fetch "$tarball" "$tmp/$tarball"

  rm -rf "$APP_DIR"
  mkdir -p "$APP_DIR" "$BIN_DIR" "$DESKTOP_DIR" "$ICON_DIR"
  tar -xzf "$tmp/$tarball" -C "$APP_DIR" --strip-components=1

  exe="$APP_DIR/$APP_ID"
  [ -x "$exe" ] || exe="$(find "$APP_DIR" -maxdepth 1 -type f -perm -u+x | head -n1)"
  [ -n "$exe" ] || die "no executable found in the release archive"
  ln -sf "$exe" "$BIN_DIR/$APP_ID"

  icon="$(find "$APP_DIR" -maxdepth 4 -name "$APP_ID.png" -o -maxdepth 4 -name 'icon.png' 2>/dev/null | head -n1)"
  [ -n "$icon" ] && cp -f "$icon" "$ICON_DIR/$APP_ID.png"

  cat > "$DESKTOP_DIR/$APP_ID.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=$APP_NAME
GenericName=Local research workspace
Comment=Unofficial desktop window for Claude Science
Exec=$BIN_DIR/$APP_ID %U
Icon=$APP_ID
Terminal=false
StartupNotify=true
StartupWMClass=$APP_ID
Categories=Science;
Keywords=Claude;AI;Research;
EOF

  have update-desktop-database && update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
  have gtk-update-icon-cache &&
    gtk-update-icon-cache -f -t "$PREFIX/share/icons/hicolor" >/dev/null 2>&1 || true

  say ""
  say "Installed $APP_NAME"
  say "  app     $APP_DIR"
  say "  command $BIN_DIR/$APP_ID"
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) warn "note: $BIN_DIR is not on your PATH — launch from the app menu, or add it." ;;
  esac
}

install_mac() {
  tmp="$1"
  need unzip
  zipname="$APP_ID-mac-$ARCH.zip"
  fetch "$zipname" "$tmp/$zipname"

  mkdir -p "$MAC_APP_DIR"
  rm -rf "$MAC_APP_DIR/$APP_NAME.app"
  unzip -q "$tmp/$zipname" -d "$tmp/unpacked"
  bundle="$(find "$tmp/unpacked" -maxdepth 2 -name '*.app' | head -n1)"
  [ -n "$bundle" ] || die "no .app bundle in the release archive"
  mv "$bundle" "$MAC_APP_DIR/$APP_NAME.app"

  # The build is unsigned, so Gatekeeper would refuse it on first open.
  xattr -dr com.apple.quarantine "$MAC_APP_DIR/$APP_NAME.app" 2>/dev/null || true

  say ""
  say "Installed $MAC_APP_DIR/$APP_NAME.app"
  say "Unsigned build: if macOS still blocks it, right-click the app → Open → confirm."
}

# --- choosing ---------------------------------------------------------------

choose_mode() {
  [ -n "$MODE" ] && return 0

  # Only offer what this release actually published — CI-built packages can lag
  # the release by a few minutes.
  say "  checking which packages this release has…"
  NATIVE_OK=no; FLATPAK_OK=no
  [ "$FAMILY" != unknown ] && asset_exists "$NATIVE_ASSET" && NATIVE_OK=yes
  asset_exists "$APP_ID-x86_64.flatpak" && FLATPAK_OK=yes
  have flatpak || FLATPAK_OK=no

  # `curl | sh` leaves stdin as the pipe, so ask the terminal directly.
  if [ -r /dev/tty ]; then
    say ""
    say "Detected: $DISTRO"
    n=0
    if [ "$NATIVE_OK" = yes ]; then
      n=$((n + 1)); OPT_NATIVE=$n
      say "  $n) Native     $NATIVE_ASSET via $NATIVE_CMD (needs sudo)"
    fi
    if [ "$FLATPAK_OK" = yes ]; then
      n=$((n + 1)); OPT_FLATPAK=$n
      say "  $n) Flatpak    per-user, sandboxed"
    fi
    n=$((n + 1)); OPT_PORTABLE=$n
    say "  $n) Portable   unpack into $APP_DIR, no sudo"

    if [ "$FAMILY" != unknown ] && [ "$NATIVE_OK" = no ]; then
      say "     (no $NATIVE_ASSET in this release yet)"
    fi
    if [ "$FLATPAK_OK" = no ]; then
      if have flatpak; then say "     (no Flatpak bundle in this release yet)"
      else say "     (Flatpak not installed on this system)"; fi
    fi

    printf 'Choice [1]: '
    read -r choice </dev/tty || choice=""
    choice="${choice:-1}"

    case "$choice" in
      "${OPT_NATIVE:-_}")   MODE=native ;;
      "${OPT_FLATPAK:-_}")  MODE=flatpak ;;
      "${OPT_PORTABLE:-_}") MODE=portable ;;
      *) die "no such choice: $choice" ;;
    esac
  else
    # Non-interactive: native where available, else Flatpak, else portable.
    if [ "$NATIVE_OK" = yes ]; then MODE=native
    elif [ "$FLATPAK_OK" = yes ]; then MODE=flatpak
    else MODE=portable
    fi
    say "No terminal to prompt on — choosing: $MODE (override with --native/--flatpak/--portable)"
  fi
}

main() {
  for arg in "$@"; do
    case "$arg" in
      --uninstall) uninstall ;;
      --native)   MODE=native ;;
      --flatpak)  MODE=flatpak ;;
      --portable) MODE=portable ;;
      -h|--help)  sed -n '2,20p' "$0" 2>/dev/null || say "see the header of install.sh"; exit 0 ;;
      *) die "unknown option: $arg" ;;
    esac
  done

  need curl
  need tar
  detect_platform

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  say "$APP_NAME — unofficial wrapper for Claude Science"

  if [ "$OS" = mac ]; then
    install_mac "$tmp"
  else
    detect_distro
    choose_mode
    case "$MODE" in
      native)
        [ "$FAMILY" != unknown ] || die "no native package for this distro — use --flatpak or --portable"
        install_native "$tmp" ;;
      flatpak)  install_flatpak "$tmp" ;;
      portable) install_portable "$tmp" ;;
    esac
  fi

  say ""
  say "Unofficial wrapper — not affiliated with, endorsed by, or supported by Anthropic."
  say "Claude Science downloads on first launch from downloads.claude.ai (~152 MB)."
}

main "$@"
