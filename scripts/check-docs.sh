#!/usr/bin/env bash
# Keep the module map honest: fail if any Sources/*.swift file is missing from
# docs/architecture/modules.md, or the map lists a file that no longer exists. This makes
# "document the new module" a mechanical gate, not a good intention — the same way
# check-layers/coverage-gate enforce the other golden rules.
set -euo pipefail
cd "$(dirname "$0")/.."

MAP="docs/architecture/modules.md"
if [ ! -f "$MAP" ]; then
    echo "check-docs: $MAP not found."
    exit 1
fi

actual="$(find Sources -name '*.swift' | sort)"
# Documented paths = backticked `Sources/....swift` tokens in the map.
documented="$(grep -oE '`Sources/[A-Za-z0-9_+./-]+\.swift`' "$MAP" | tr -d '`' | sort -u)"

missing="$(comm -23 <(printf '%s\n' "$actual") <(printf '%s\n' "$documented"))"
stale="$(comm -13 <(printf '%s\n' "$actual") <(printf '%s\n' "$documented"))"

status=0
if [ -n "$missing" ]; then
    echo "check-docs: source files missing from $MAP (add a row):"
    echo "$missing" | sed 's/^/  - /'
    status=1
fi
if [ -n "$stale" ]; then
    echo "check-docs: $MAP lists files that no longer exist (remove the row):"
    echo "$stale" | sed 's/^/  - /'
    status=1
fi

if [ "$status" -eq 0 ]; then
    echo "check-docs: OK ($(printf '%s\n' "$actual" | grep -c . ) files documented)"
fi
exit "$status"
