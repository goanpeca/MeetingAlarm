#!/usr/bin/env bash
# Render the app icon (scripts/generate-icon.swift) and build Resources/AppIcon.icns with
# every size macOS wants. Re-run after changing the icon design.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
MASTER="$TMP/icon_1024.png"
ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET"

echo "==> Rendering master 1024 icon"
swift scripts/generate-icon.swift "$MASTER" >/dev/null

emit() { sips -z "$2" "$2" "$MASTER" --out "$ICONSET/$1" >/dev/null; }
emit icon_16x16.png 16
emit icon_16x16@2x.png 32
emit icon_32x32.png 32
emit icon_32x32@2x.png 64
emit icon_128x128.png 128
emit icon_128x128@2x.png 256
emit icon_256x256.png 256
emit icon_256x256@2x.png 512
emit icon_512x512.png 512
emit icon_512x512@2x.png 1024

mkdir -p Resources
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
echo "==> Wrote Resources/AppIcon.icns"
