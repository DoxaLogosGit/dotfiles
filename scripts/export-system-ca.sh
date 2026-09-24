#!/bin/bash
#
# Export the macOS system + admin trust stores to a PEM bundle.
#
# Why: corporate TLS interception installs a proxy CA into the macOS keychain.
# Safari and curl honour it, but Node, Python and the AWS CLI ship their own
# root stores and do not, so they fail with:
#     unable to get local issuer certificate
#
# zsh/zshrc picks the output up automatically and exports NODE_EXTRA_CA_CERTS,
# AWS_CA_BUNDLE and REQUESTS_CA_BUNDLE.
#
# macOS only. Re-run if the proxy CA is rotated.

set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
    echo "[INFO] Not macOS — nothing to do."
    exit 0
fi

out_dir="$HOME/.config/certs"
out="$out_dir/system-ca.pem"
mkdir -p "$out_dir"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# System roots plus the admin store, where an MDM-delivered proxy CA lands.
security find-certificate -a -p \
    /System/Library/Keychains/SystemRootCertificates.keychain >> "$tmp"
security find-certificate -a -p /Library/Keychains/System.keychain >> "$tmp"

count=$(grep -c "BEGIN CERTIFICATE" "$tmp" || true)
if [ "$count" -eq 0 ]; then
    echo "[WARN] No certificates exported; leaving any existing bundle alone." >&2
    exit 1
fi

mv "$tmp" "$out"
trap - EXIT
chmod 644 "$out"
echo "[ OK ] Wrote $count certificates to $out"
echo "       Open a new shell, or: export NODE_EXTRA_CA_CERTS=$out"
