#!/usr/bin/env bash
# Run Muter mutation testing on the pure-core files (scripts/mutation-core-files.sh), print
# the full report, and — when MUTATION_MIN is set — fail if the mutation score is below that
# floor. `make mutation` calls this; the CI workflow sets MUTATION_MIN to enforce the minimum.
# Reproduce the CI gate locally with:  MUTATION_MIN=45 make mutation
set -euo pipefail
cd "$(dirname "$0")/.."

# Muter's --files-to-mutate takes a single comma-separated value.
files="$(./scripts/mutation-core-files.sh | paste -sd, -)"
if [ -z "$files" ]; then
    echo "mutation: no core files to mutate."
    exit 1
fi

# Muter copies the project, so a stale module cache bakes in the old path (SwiftShims).
swift package clean

log="$(mktemp)"
# Muter works in a sibling copy of the whole project (<repo>_mutated), which also carries a
# stale MeetingAlarm.app that macOS registers under our bundle id — and then the Menu Bar /
# Control Center settings can resolve to it instead of the real app. Unregister and delete the
# copy on the way out, pass or fail.
mutated="${PWD}_mutated"
cleanup() {
    rm -f "$log"
    if [ -d "$mutated/MeetingAlarm.app" ]; then
        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
            -u "$mutated/MeetingAlarm.app" 2>/dev/null || true
    fi
    rm -rf "$mutated"
}
trap cleanup EXIT

# Tee so the human-readable report streams while we also parse the score from it.
set +e
muter run --skip-update-check --files-to-mutate "$files" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
set -e
if [ "$status" -ne 0 ]; then
    echo "mutation: muter exited non-zero ($status)."
    exit "$status"
fi

score="$(grep -oE 'Mutation Score of Test Suite: [0-9]+' "$log" | grep -oE '[0-9]+' | tail -1)"
if [ -z "$score" ]; then
    echo "mutation: could not parse a mutation score from muter output."
    exit 1
fi

echo "mutation: score ${score}%${MUTATION_MIN:+ (floor ${MUTATION_MIN}%)}"
if [ -n "${MUTATION_MIN:-}" ] && [ "$score" -lt "$MUTATION_MIN" ]; then
    echo "mutation: FAIL — score ${score}% is below the ${MUTATION_MIN}% floor."
    exit 1
fi
