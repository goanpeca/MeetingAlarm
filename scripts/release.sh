#!/usr/bin/env bash
# Prepare a release: verify the gate, roll CHANGELOG's [Unreleased] into a dated version
# section, and bump the app's version. It deliberately does NOT commit, tag, or push — those
# irreversible steps are left to you (the script prints them). Usage: make release VERSION=X.Y.Z
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "usage: scripts/release.sh X.Y.Z   (got: '${VERSION}')"
    exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
    echo "working tree not clean — commit or stash first."
    exit 1
fi
if ! command -v changie >/dev/null; then
    echo "changie not found — install it: brew install changie (or 'make tools')."
    exit 1
fi
if [ -z "$(ls -A .changes/unreleased 2>/dev/null)" ]; then
    echo "no changesets in .changes/unreleased — add one with 'make changeset' first."
    exit 1
fi
if git rev-parse "v${VERSION}" >/dev/null 2>&1; then
    echo "tag v${VERSION} already exists."
    exit 1
fi

echo "==> Verifying the full gate (make ci)"
make ci

echo "==> Batching changesets into [${VERSION}] and regenerating CHANGELOG.md (changie)"
changie batch "$VERSION"
changie merge -u "## [Unreleased]"

echo "==> Bumping CFBundleShortVersionString to ${VERSION}"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" Resources/Info.plist

cat <<EOF

==> Release ${VERSION} prepared (not committed). Review, then:

    git add CHANGELOG.md .changes Resources/Info.plist
    git commit -m "chore: release ${VERSION}"
    git tag -a "v${VERSION}" -m "v${VERSION}"
    git push --follow-tags
EOF
