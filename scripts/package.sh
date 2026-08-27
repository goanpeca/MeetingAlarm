#!/usr/bin/env bash
# Package MeetingAlarm.app into a shareable zip under dist/, next to SHARE.md open
# instructions. The bundle is signed with a self-signed/ad-hoc cert (not notarized), so the
# recipient clears Gatekeeper once — SHARE.md walks them through it. For friction-free
# distribution, sign with an Apple Developer ID and notarize instead (see SHARE.md).
set -euo pipefail
cd "$(dirname "$0")/.."

# Optimized release build + signed bundle.
CONFIG=release ./scripts/make_app.sh

APP="MeetingAlarm.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP}/Contents/Info.plist")"
OUT="dist"
ZIP="${OUT}/MeetingAlarm-${VERSION}.zip"

mkdir -p "${OUT}"
rm -f "${ZIP}"
# `ditto` preserves the bundle's code signature, symlinks, and resource forks; a plain
# `zip` can silently corrupt a signed .app so it won't launch on the other end.
ditto -c -k --sequesterRsrc --keepParent "${APP}" "${ZIP}"
cp SHARE.md "${OUT}/SHARE.md"

SIZE="$(du -h "${ZIP}" | cut -f1 | tr -d '[:space:]')"
echo "==> Packaged ${ZIP} (${SIZE})"
echo "    Send BOTH files from dist/ to the recipient:"
echo "      - MeetingAlarm-${VERSION}.zip"
echo "      - SHARE.md   (how to open it the first time)"
