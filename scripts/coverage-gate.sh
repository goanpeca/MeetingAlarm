#!/usr/bin/env bash
# Enforce a minimum line-coverage on the pure-logic core.
#
# Run `swift test --enable-code-coverage` first. The gate measures only the
# testable core (files under CORE_GLOB) so thin AppKit/EventKit/URLSession shells
# don't dilute or inflate the number. Threshold is recorded in
# docs/quality/quality.md and ratcheted upward over time.
set -euo pipefail
cd "$(dirname "$0")/.."

THRESHOLD="${COVERAGE_THRESHOLD:-70}"
CORE_GLOB="${CORE_GLOB:-/Sources/MeetingAlarm/}"
# Thin AppKit/EventKit/URLSession/SwiftUI shells are verified manually (design §13),
# so they are excluded from the measured pure-logic denominator.
EXCLUDE="${EXCLUDE:-App.swift Logging.swift Keychain.swift LoginItem.swift SoundPlayer.swift OverlayController.swift OverlayView.swift ChallengeGateView.swift NotesView.swift MeetingProvider.swift EventKitSource.swift GoogleCalendarSource.swift GoogleAuth.swift LoopbackServer.swift AlarmScheduler.swift AppCoordinator.swift AppCoordinator+Sources.swift AppCoordinator+UI.swift AppCoordinator+Scheduling.swift MenuContentView.swift MeetingRow.swift MeetingDetailView.swift ScopePromptView.swift HTMLText.swift SystemAccent.swift ColorPanelController.swift GlobalHotKey.swift QuickPanel.swift SettingsView.swift}"

BIN="$(swift build --show-bin-path)"
PROFDATA="$BIN/codecov/default.profdata"
if [ ! -f "$PROFDATA" ]; then
    echo "No coverage data at $PROFDATA."
    echo "Run: swift test --enable-code-coverage"
    exit 1
fi

XCTEST="$(/usr/bin/find "$BIN" -maxdepth 1 -name '*.xctest' | head -n1)"
if [ -z "$XCTEST" ]; then
    echo "No .xctest bundle found under $BIN"
    exit 1
fi
TEST_BIN="$XCTEST/Contents/MacOS/$(basename "${XCTEST%.xctest}")"

xcrun llvm-cov export -instr-profile "$PROFDATA" "$TEST_BIN" \
    | CORE_GLOB="$CORE_GLOB" THRESHOLD="$THRESHOLD" EXCLUDE="$EXCLUDE" python3 -c '
import json, os, sys
data = json.load(sys.stdin)
glob = os.environ["CORE_GLOB"]
threshold = float(os.environ["THRESHOLD"])
excluded = os.environ.get("EXCLUDE", "").split()
covered = total = 0
for f in data["data"][0]["files"]:
    name = f["filename"]
    if glob in name and not any(name.endswith(e) for e in excluded):
        lines = f["summary"]["lines"]
        covered += lines["covered"]
        total += lines["count"]
if total == 0:
    print(f"ERROR: no coverage regions matched CORE_GLOB ({glob}).")
    print("Cannot verify coverage — failing rather than passing vacuously.")
    print("Check the path, or that the core has executable (not just declarative) code.")
    sys.exit(1)
pct = 100.0 * covered / total
print(f"Core line coverage ({glob}): {pct:.1f}% ({covered}/{total}); threshold {threshold:.0f}%")
sys.exit(0 if pct >= threshold else 1)
'
