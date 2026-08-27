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
if ! grep -q "## \[Unreleased\]" CHANGELOG.md; then
    echo "CHANGELOG.md has no '## [Unreleased]' section."
    exit 1
fi
if git rev-parse "v${VERSION}" >/dev/null 2>&1; then
    echo "tag v${VERSION} already exists."
    exit 1
fi

echo "==> Verifying the full gate (make ci)"
make ci

DATE="$(date +%Y-%m-%d)"
echo "==> Rolling CHANGELOG.md: [Unreleased] -> [${VERSION}] — ${DATE}"
awk -v v="$VERSION" -v d="$DATE" '
    /^## \[Unreleased\]/ && !done { print; print ""; print "## [" v "] — " d; done=1; next }
    { print }
' CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md

echo "==> Bumping CFBundleShortVersionString to ${VERSION}"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" Resources/Info.plist

cat <<EOF

==> Release ${VERSION} prepared (not committed). Review, then:

    git add CHANGELOG.md Resources/Info.plist
    git commit -m "chore: release ${VERSION}"
    git tag -a "v${VERSION}" -m "v${VERSION}"
    git push --follow-tags
EOF
