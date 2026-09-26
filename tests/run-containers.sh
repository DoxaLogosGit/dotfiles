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
#              The image is Alpine, which detect_os would call 'unknown', so a
#              fixture from tests/fixtures/ is mounted over /etc/os-release to
#              give it a supported identity. detect_os still runs for real; only
#              the file it reads is substituted. The whole suite then runs under
#              bash 3.2, once per OS identity — including raspbian, whose
#              routing cannot otherwise be exercised without Pi hardware.
#
#   fedora     A real Fedora userland (GNU coreutils, dnf), so the package
#              scripts can run for real without installing anything on the host.
#
#   trixie     Debian 13, the current stable, and the release Raspbian Trixie is
#              built on — so it is the closest available proxy for the Pi.
#
#   bookworm   Debian 12, oldstable. Kept because the two releases differ where
#              it matters: glow and eza are packaged in trixie and not in
#              bookworm, which is exactly what the fallback handlers exist for.
#
# Every install run here is --dry-run: it writes nothing, which is verified by
# tests/test_dry_run_hermetic.sh.
#
# Usage: tests/run-containers.sh [bash32|fedora|trixie|bookworm|debian|all]

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

# As run_in, but with $1 as the container's /etc/os-release, so detect_os
# resolves to that OS_TYPE.
run_in_as() {
    local osid="$1" image="$2"; shift 2
    local fixture="$REPO/tests/fixtures/os-release.$osid"
    if [ ! -f "$fixture" ]; then
        echo "[ERROR] no fixture for '$osid': $fixture" >&2
        return 1
    fi
    echo ""
    echo "════ $image  (identifying as $osid)"
    "$ENGINE" run --rm \
        -v "$REPO":/dotfiles:ro,Z \
        -v "$fixture":/etc/os-release:ro,Z \
        -w /dotfiles \
        -e DOTFILES_DIR=/dotfiles \
        -e HOME=/root \
        "$image" "$@"
}

rc=0

if [ "$WHICH" = "bash32" ] || [ "$WHICH" = "all" ]; then
    # The full suite under real bash 3.2, once per OS identity.
    for osid in fedora debian raspbian; do
        run_in_as "$osid" docker.io/library/bash:3.2 bash tests/run.sh || rc=1
    done
fi

if [ "$WHICH" = "fedora" ] || [ "$WHICH" = "all" ]; then
    run_in docker.io/library/fedora:latest bash -c '
        dnf install -y -q findutils diffutils >/dev/null 2>&1
        bash tests/run.sh
    ' || rc=1
fi

if [ "$WHICH" = "trixie" ] || [ "$WHICH" = "debian" ] || [ "$WHICH" = "all" ]; then
    run_in docker.io/library/debian:trixie bash -c '
        apt-get update -qq >/dev/null 2>&1
        bash tests/run.sh
    ' || rc=1
fi

if [ "$WHICH" = "bookworm" ] || [ "$WHICH" = "debian" ] || [ "$WHICH" = "all" ]; then
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
