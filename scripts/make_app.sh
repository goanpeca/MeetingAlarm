#!/usr/bin/env bash
# Assemble MeetingAlarm.app from the built binary + Info.plist, ad-hoc sign it
# (so EventKit/TCC permission prompts work), and leave it ready to `open`.
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

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "${APP}"

echo "==> Done: ${APP} (run: open ${APP})"
