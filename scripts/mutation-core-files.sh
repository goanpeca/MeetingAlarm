#!/usr/bin/env bash
# Print the pure-core source files to mutation-test: every Sources/*.swift except the
# non-core shells listed in scripts/non-core-files.txt (the same set the coverage gate
# excludes). Passed to `muter run --files-to-mutate`, because Muter's own coverage-based
# filtering doesn't work under our env-wrapped `swift test`, and mutating the untested
# SwiftUI/AppKit shells both fails to compile (ViewBuilder) and is pointless.
set -euo pipefail
cd "$(dirname "$0")/.."

# Basenames to skip (strip comments/blank lines).
skip="$(grep -vE '^\s*(#|$)' scripts/non-core-files.txt)"

find Sources -name '*.swift' | sort | while read -r f; do
    base="$(basename "$f")"
    if ! grep -qxF "$base" <<< "$skip"; then
        echo "$f"
    fi
done
