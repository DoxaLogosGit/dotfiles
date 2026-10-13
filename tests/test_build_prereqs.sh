#!/bin/bash
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

REPO="$(cd "$(dirname "$0")/.." && pwd)"

assert_ok "Fedora installs OpenSSL development headers" \
    grep -q 'openssl-devel' "$REPO/scripts/packages-fedora.sh"
assert_ok "Fedora installs pkg-config" \
    grep -q 'pkgconf-pkg-config' "$REPO/scripts/packages-fedora.sh"
assert_ok "Debian installs OpenSSL development headers" \
    grep -q 'libssl-dev' "$REPO/scripts/packages-debian.sh"
assert_ok "Debian installs pkg-config" \
    grep -q 'pkg-config' "$REPO/scripts/packages-debian.sh"
assert_ok "Raspbian installs OpenSSL development headers" \
    grep -q 'libssl-dev' "$REPO/scripts/packages-raspbian.sh"
assert_ok "Raspbian installs pkg-config" \
    grep -q 'pkg-config' "$REPO/scripts/packages-raspbian.sh"

finish_tests
