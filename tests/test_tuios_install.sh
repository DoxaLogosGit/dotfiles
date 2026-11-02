#!/bin/bash
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

# GitHub's stable-release redirect supplies the version without an API token.
version=$(
    TUIOS_VERSION=""
    # shellcheck source=../scripts/install-tuios.sh
    . "$REPO/scripts/install-tuios.sh"
    curl() { printf '%s' 'https://github.com/Gaurav-Gosain/tuios/releases/tag/v0.12.1'; }
    _tuios_resolve_version
    printf '%s' "$TUIOS_VERSION"
)
assert_eq "0.12.1" "$version" "the latest GitHub release supplies the tuios version"

# An explicit version bypasses the network lookup for a reproducible install.
version=$(
    TUIOS_VERSION="0.12.1"
    # shellcheck source=../scripts/install-tuios.sh
    . "$REPO/scripts/install-tuios.sh"
    curl() { return 1; }
    _tuios_resolve_version
    printf '%s' "$TUIOS_VERSION"
)
assert_eq "0.12.1" "$version" "TUIOS_VERSION overrides the latest-release lookup"

# A malformed redirect must fail instead of treating an arbitrary URL as a tag.
if (
    TUIOS_VERSION=""
    # shellcheck source=../scripts/install-tuios.sh
    . "$REPO/scripts/install-tuios.sh"
    curl() { printf '%s' 'https://github.com/Gaurav-Gosain/tuios/releases/latest'; }
    _tuios_resolve_version
); then
    _fail "an invalid release redirect fails"
else
    _pass "an invalid release redirect fails"
fi

finish_tests
