#!/usr/bin/env bash
# Assemble MeetingAlarm.app from the built binary + Info.plist, code-sign it, and leave
# it ready to `open`. Signs with a stable self-signed identity ("MeetingAlarm Dev") when
# available so macOS keeps the Calendar (TCC) permission across rebuilds; otherwise falls
# back to ad-hoc (e.g. in CI). Create the identity once — see README "Stable signing".
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-debug}"
APP="MeetingAlarm.app"
BIN=".build/${CONFIG}/MeetingAlarm"

echo "==> Building (${CONFIG})"
swift build -c "${CONFIG}"

echo "==> Assembling ${APP}"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "${BIN}" "${APP}/Contents/MacOS/MeetingAlarm"
cp Resources/Info.plist "${APP}/Contents/Info.plist"
if compgen -G "Resources/Sounds/*.m4a" > /dev/null; then
    cp Resources/Sounds/*.m4a "${APP}/Contents/Resources/"
fi

IDENTITY="${CODESIGN_IDENTITY:-MeetingAlarm Dev}"
if security find-identity -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
    echo "==> Signing with stable identity: $IDENTITY"
    codesign --force --deep --sign "$IDENTITY" "${APP}"
else
    echo "==> Ad-hoc signing (stable identity '$IDENTITY' not found)"
    codesign --force --deep --sign - "${APP}"
fi

echo "==> Done: ${APP} (run: open ${APP})"
