#!/usr/bin/env bash
# Fail if any relative Markdown link points to a file that doesn't exist — catches broken
# cross-links between docs (e.g. after a move/rename). Skips external (http/mailto) and pure
# anchor links. Wired into `make scan` / `make ci` / CI.
set -euo pipefail
cd "$(dirname "$0")/.."

broken=0
checked=0
while IFS= read -r md; do
    dir=$(dirname "$md")
    while IFS= read -r target; do
        t="${target%% *}"   # drop optional "title"
        t="${t%%#*}"        # drop #anchor
        t="${t%%\?*}"       # drop ?query
        [ -z "$t" ] && continue
        case "$t" in
            http://* | https://* | mailto:* | tel:*) continue ;;
        esac
        checked=$((checked + 1))
        if [ ! -e "$dir/$t" ]; then
            echo "check-links: broken link in $md -> $t"
            broken=$((broken + 1))
        fi
    done < <(grep -oE '\]\([^)]+\)' "$md" | sed -E 's/^\]\(//; s/\)$//')
done < <(git ls-files '*.md')

if [ "$broken" -gt 0 ]; then
    echo "check-links: $broken broken link(s)"
    exit 1
fi
echo "check-links: OK ($checked relative links)"
