#!/bin/bash
#
# Run the test suite inside containers, so nothing touches the host.
#
# Two environments, for two different reasons:
#
#   bash:3.2   bash 3.2.57 — the exact version macOS ships, which Apple froze
#              over GPLv3. install.sh runs under /bin/bash there, so this is
#              the only way to *execute* the bash-3.2 constraint rather than
#              grep for it (tests/test_bash32_compat.sh is the static half).
#              Alpine-based, so OS_TYPE comes out 'unknown' and the tests that
#              drive a full install run are skipped here.
#
#   fedora     A supported OS_TYPE, so the phase gates and the package scripts
#              can run for real without installing anything on the host.
#
# Usage: tests/run-containers.sh [bash32|fedora|debian|all]

set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WHICH="${1:-all}"

ENGINE=""
for e in podman docker; do
    command -v "$e" >/dev/null 2>&1 && { ENGINE="$e"; break; }
done
if [ -z "$ENGINE" ]; then
    echo "[ERROR] neither podman nor docker is installed" >&2
    exit 1
fi

# Tests that do not need a supported OS_TYPE, and so can run on Alpine.
PORTABLE_TESTS="test_harness.sh test_manifest.sh \
test_tools_table.sh test_gen_manifest.sh test_bash32_compat.sh \
test_symlink_gates.sh"

run_in() {
    local image="$1"; shift
    echo ""
    echo "════ $image"
    "$ENGINE" run --rm \
        -v "$REPO":/dotfiles:ro,Z \
        -w /dotfiles \
        -e DOTFILES_DIR=/dotfiles \
        -e HOME=/root \
        "$image" "$@"
}

rc=0

if [ "$WHICH" = "bash32" ] || [ "$WHICH" = "all" ]; then
    # shellcheck disable=SC2086  # PORTABLE_TESTS is an intentional word list
    run_in docker.io/library/bash:3.2 bash tests/run.sh $PORTABLE_TESTS || rc=1
fi

if [ "$WHICH" = "fedora" ] || [ "$WHICH" = "all" ]; then
    run_in docker.io/library/fedora:latest bash -c '
        dnf install -y -q findutils diffutils >/dev/null 2>&1
        bash tests/run.sh
    ' || rc=1
fi

if [ "$WHICH" = "debian" ] || [ "$WHICH" = "all" ]; then
    run_in docker.io/library/debian:bookworm bash -c '
        apt-get update -qq >/dev/null 2>&1
        bash tests/run.sh
    ' || rc=1
fi

echo ""
if [ "$rc" -eq 0 ]; then
    echo "ALL CONTAINER RUNS PASSED"
else
    echo "CONTAINER RUNS FAILED"
fi
exit "$rc"
