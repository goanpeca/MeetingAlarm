#!/usr/bin/env bash
# Validate that every GitHub Actions workflow file is parseable YAML. A malformed workflow is
# silently rejected by GitHub (it just never runs), so a syntax slip can hide indefinitely —
# especially in schedule-only workflows. Uses Ruby's stdlib YAML (present on macOS + runners,
# no install). Wired into `make scan` / `make ci` / CI.
set -euo pipefail
cd "$(dirname "$0")/.."

shopt -s nullglob
# Workflow files plus top-level .github config YAML (e.g. dependabot.yml).
files=(.github/workflows/*.yml .github/workflows/*.yaml .github/*.yml .github/*.yaml)
if [ ${#files[@]} -eq 0 ]; then
    echo "check-workflows: no workflow files."
    exit 0
fi

status=0
for f in "${files[@]}"; do
    if ! err=$(ruby -ryaml -e "YAML.load_file(ARGV[0])" "$f" 2>&1); then
        echo "check-workflows: invalid YAML in $f"
        echo "$err" | sed 's/^/  /'
        status=1
    fi
done

if [ "$status" -eq 0 ]; then
    echo "check-workflows: OK (${#files[@]} workflow files)"
fi
exit "$status"
