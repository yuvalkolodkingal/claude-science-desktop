#!/usr/bin/env bash
# Fetch Anthropic's official claude-science build into vendor/ for local dev.
#
# Nothing in this repo redistributes that binary — vendor/ is gitignored and no
# release artifact contains it. The app downloads it the same way at first run.
set -euo pipefail

BASE="https://downloads.claude.ai/claude-science"
PLATFORM="linux-x64"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_DIR/vendor/claude-science"

manifest="$(curl -fsSL "$BASE/latest/manifest.json")"
version="$(printf '%s' "$manifest" | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
expected="$(printf '%s' "$manifest" | tr -d ' \n' | sed -n 's/.*"'"$PLATFORM"'":"\([0-9a-f]\{64\}\)".*/\1/p')"

if [[ -z "$version" || -z "$expected" ]]; then
  echo "could not read version/checksum from $BASE/latest/manifest.json" >&2
  exit 1
fi

echo "claude-science $version ($PLATFORM)"
mkdir -p "$(dirname "$DEST")"
curl -fL --progress-bar "$BASE/$version/$PLATFORM" -o "$DEST.part"

actual="$(sha256sum "$DEST.part" | cut -d' ' -f1)"
if [[ "$actual" != "$expected" ]]; then
  rm -f "$DEST.part"
  echo "checksum mismatch:" >&2
  echo "  expected $expected" >&2
  echo "  got      $actual" >&2
  exit 1
fi

chmod 755 "$DEST.part"
mv "$DEST.part" "$DEST"
echo "verified sha256 $actual"
echo "-> $DEST"
