#!/usr/bin/env bash
# Enforce architectural import purity per layer.
#
# In a single Swift module the compiler will not stop a lower layer from
# referencing a higher one, so we mechanically forbid the *frameworks* that would
# let that happen: the pure logic in Models/State must stay free of UI, calendar,
# and networking frameworks, keeping it unit-testable without a screen, a calendar
# database, or the network. Services and UI may use platform frameworks freely.
#
# See docs/architecture/overview.md and docs/principles/golden-principles.md.
set -uo pipefail
cd "$(dirname "$0")/.."

ROOT="Sources/MeetingAlarm"
fail=0

# check <folder> <forbidden frameworks...>
check() {
    local dir="$1"; shift
    [ -d "$ROOT/$dir" ] || return 0
    local file fw
    while IFS= read -r file; do
        for fw in "$@"; do
            if grep -Eq "^[[:space:]]*import[[:space:]]+$fw([[:space:]]|$)" "$file"; then
                echo "LAYER VIOLATION: $file imports '$fw' (forbidden in $dir/)."
                echo "  Fix: keep this layer pure — move UI/IO code up a layer, or"
                echo "       represent data as plain values (see RGBAColor for the pattern)."
                fail=1
            fi
        done
    done < <(find "$ROOT/$dir" -name '*.swift')
}

# Models: pure values only.
check Models AppKit SwiftUI EventKit Network Security
# State: persistence only — no UI, calendar, or networking (Security is allowed
# here for the Keychain wrapper).
check State AppKit SwiftUI EventKit Network

if [ "$fail" -ne 0 ]; then
    echo "check-layers: FAILED"
    exit 1
fi
echo "check-layers: OK"
