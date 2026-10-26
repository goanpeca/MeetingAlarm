#!/usr/bin/env bash
# Install the pinned swiftformat + swiftlint (scripts/tool-versions.env) into .tools/bin,
# verifying each release zip's SHA-256 before use. Idempotent: a tool already at the pinned
# version is left alone. The Makefile puts .tools/bin first on PATH; in GitHub Actions this
# also appends it to $GITHUB_PATH so later steps pick up the pinned binaries.
set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck source=scripts/tool-versions.env
source scripts/tool-versions.env

BIN="$PWD/.tools/bin"
mkdir -p "$BIN"

install_tool() {
    local name="$1" version="$2" sha="$3" url="$4"
    if [ -x "$BIN/$name" ] && [ "$("$BIN/$name" --version 2>/dev/null)" = "$version" ]; then
        return 0
    fi
    echo "install-tools: installing $name $version"
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN
    curl -fsSL -o "$tmp/$name.zip" "$url"
    local actual
    actual="$(shasum -a 256 "$tmp/$name.zip" | cut -d' ' -f1)"
    if [ "$actual" != "$sha" ]; then
        echo "install-tools: checksum mismatch for $name $version"
        echo "  expected $sha"
        echo "  actual   $actual"
        return 1
    fi
    unzip -q -o "$tmp/$name.zip" "$name" -d "$tmp"
    install -m 0755 "$tmp/$name" "$BIN/$name"
}

install_tool swiftformat "$SWIFTFORMAT_VERSION" "$SWIFTFORMAT_SHA256" \
    "https://github.com/nicklockwood/SwiftFormat/releases/download/$SWIFTFORMAT_VERSION/swiftformat.zip"
install_tool swiftlint "$SWIFTLINT_VERSION" "$SWIFTLINT_SHA256" \
    "https://github.com/realm/SwiftLint/releases/download/$SWIFTLINT_VERSION/portable_swiftlint.zip"

if [ -n "${GITHUB_PATH:-}" ]; then
    echo "$BIN" >> "$GITHUB_PATH"
fi
