#!/usr/bin/env bash
# Ensure a stable, self-signed codesigning identity exists so macOS keeps the
# Calendar (TCC) permission across rebuilds. macOS ties the grant to the code
# signature; ad-hoc signatures change every build, so the grant is re-forgotten.
# This creates a one-time local identity the first time it's needed and is a
# no-op afterwards. It never overrides a real identity you pass via
# CODESIGN_IDENTITY, and only auto-creates the default dev identity.
#
# The generated identity is self-signed (untrusted) — fine for local dev. It is
# per-machine: it lives in your login keychain and is never shared. Anyone who
# clones the repo gets their own on first `make app`.
set -euo pipefail

IDENTITY="${CODESIGN_IDENTITY:-MeetingAlarm Dev}"

if security find-identity -p codesigning 2>/dev/null | grep -qF "$IDENTITY"; then
    exit 0
fi

# Only auto-create the default identity. A user-supplied one must already exist.
if [ "$IDENTITY" != "MeetingAlarm Dev" ]; then
    echo "==> CODESIGN_IDENTITY='$IDENTITY' not found in keychain; using ad-hoc." >&2
    exit 0
fi

echo "==> Creating one-time self-signed identity: $IDENTITY"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

printf '[req]\ndistinguished_name=dn\nx509_extensions=v3\nprompt=no\n[dn]\nCN=%s\n[v3]\nbasicConstraints=critical,CA:false\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=critical,codeSigning\n' \
    "$IDENTITY" > "$WORK/c.cnf"

openssl req -x509 -newkey rsa:2048 -keyout "$WORK/k.pem" -out "$WORK/c.pem" \
    -days 3650 -nodes -config "$WORK/c.cnf" >/dev/null 2>&1

# Legacy PBE so macOS `security import` can read the PKCS#12 (OpenSSL 3 defaults can't).
openssl pkcs12 -export -inkey "$WORK/k.pem" -in "$WORK/c.pem" -out "$WORK/id.p12" \
    -passout pass:tmp -name "$IDENTITY" \
    -macalg sha1 -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES >/dev/null 2>&1

# -A lets codesign use the key without an interactive keychain prompt each build.
security import "$WORK/id.p12" -k "$KEYCHAIN" -P tmp -T /usr/bin/codesign -A >/dev/null 2>&1

if security find-identity -p codesigning 2>/dev/null | grep -qF "$IDENTITY"; then
    echo "==> Identity ready. Calendar permission will now persist across rebuilds."
else
    echo "==> Could not create identity; falling back to ad-hoc signing." >&2
fi
