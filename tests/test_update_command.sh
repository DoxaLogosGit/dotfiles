#!/bin/bash
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
sandbox="$(make_sandbox)"
fake_home="$sandbox/home"
mkdir -p "$fake_home"

printf '%s\n' \
    'rust = no' 'bun = no' 'node = no' 'mise = no' 'uv = no' 'pi = no' \
    'playwright = no' 'pi-packages = no' 'claude-plugins = no' \
    > "$sandbox/overlay/manifest.conf"

out="$(HOME="$fake_home" DOTFILES_DIR="$REPO" DOTFILES_OVERLAY="$sandbox/overlay" \
    bash "$REPO/install.sh" --dry-run --update 2>&1)"
case "$out" in
    *"apt-get update"*)
        _pass "--update runs the Debian package update path"
        assert_contains "$out" "apt-get upgrade -yy" "--update upgrades installed Debian packages"
        ;;
    *"dnf upgrade --refresh -y"*)
        _pass "--update runs the Fedora package update path"
        ;;
    *) _fail "--update runs the detected platform update path" "$out" ;;
esac
case "$out" in
    *"Would link"*) _fail "--update does not change symlinks" "a symlink action appeared" ;;
    *) _pass "--update does not change symlinks" ;;
esac

created="$(find "$fake_home" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "0" "$created" "--dry-run --update creates nothing in HOME"

cleanup_sandbox "$sandbox"
finish_tests
