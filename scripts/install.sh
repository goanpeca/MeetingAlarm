#!/usr/bin/env bash
# Install the built MeetingAlarm.app into /Applications and register it with Launch Services,
# so macOS (Control Center / Menu Bar settings, Login Items, Spotlight) resolves the bundle id
# to ONE copy that carries the current icon. A stale or duplicate copy elsewhere makes the
# system show a generic icon. Run via `make install` (which builds and signs first).
set -euo pipefail
cd "$(dirname "$0")/.."

APP="MeetingAlarm.app"
DEST="/Applications/$APP"
LSR=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

if [ ! -d "$APP" ]; then
    echo "install: $APP not found — run 'make app' first (or use 'make install')."
    exit 1
fi

# Replace the running copy cleanly; ditto preserves the code signature and resource forks.
pkill -x MeetingAlarm 2>/dev/null || true
sleep 0.5
rm -rf "$DEST"
ditto "$APP" "$DEST"

# Register the installed copy and drop the build-tree one so the bundle id resolves only to
# /Applications (best effort — Spotlight may re-index the build copy later).
"$LSR" -f "$DEST"
"$LSR" -u "$PWD/$APP" 2>/dev/null || true

echo "install: installed $DEST"
open "$DEST"
