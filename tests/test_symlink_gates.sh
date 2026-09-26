#!/bin/bash
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

# Run install_symlinks_common against a sandbox HOME and echo the resulting
# entries under that HOME, sorted. $1 = manifest contents ('' for none).
#
# install.sh guards its main() behind a BASH_SOURCE check, so sourcing it
# only defines functions. It also sets `set -e`, hence the subshell.
run_symlinks() {
    local manifest_body="$1" sandbox result
    sandbox="$(make_sandbox)"

    result=$(
        set +e
        # shellcheck source=/dev/null
        . "$REPO/install.sh" >/dev/null 2>&1
        set +e
        # These configure the install.sh sourced just above. shellcheck cannot
        # follow that dynamic source, so it reports them unused.
        # shellcheck disable=SC2034
        {
            HOME="$sandbox/home"
            DOTFILES_DIR="$REPO"
            DOTFILES_OVERLAY="$sandbox/overlay"
            BACKUP_DIR="$sandbox/backup"
            DRY_RUN=false
        }

        if [ -n "$manifest_body" ]; then
            printf '%s\n' "$manifest_body" > "$sandbox/overlay/manifest.conf"
        fi
        manifest_load "$sandbox/overlay/manifest.conf" "$REPO/scripts/tools.tsv" >/dev/null 2>&1

        install_symlinks_common "tmux.conf" >/dev/null 2>&1
        find "$sandbox/home" -maxdepth 4 \( -type l -o -type f \) 2>/dev/null \
            | sed "s|$sandbox/home/||" | sort
    )

    cleanup_sandbox "$sandbox"
    printf '%s' "$result"
}

# ── an all-yes manifest must equal no manifest at all ───────────────────
none="$(run_symlinks "")"
all_yes_body="$(grep -vE '^[[:space:]]*(#|$)' "$REPO/manifest.example" | sed 's/#.*//')"
all_yes="$(run_symlinks "$all_yes_body")"

assert_contains "$none" ".zshrc" "baseline links .zshrc"
assert_eq "$none" "$all_yes" "all-yes manifest produces the same tree as no manifest"

# ── a no line actually removes something ───────────────────────────────
no_btop="$(run_symlinks "$(printf 'zsh = yes\nbtop = no\n')")"
assert_contains "$no_btop" ".zshrc" "zsh still linked when named yes"
case "$no_btop" in
    *btop*) _fail "btop = no skips the btop config" "btop still present" ;;
    *) _pass "btop = no skips the btop config" ;;
esac

# ── opt-in: a tool absent from an active manifest is skipped ───────────
only_zsh="$(run_symlinks "zsh = yes")"
assert_contains "$only_zsh" ".zshrc" "the named tool is linked"
case "$only_zsh" in
    *.vimrc*) _fail "unnamed tools are skipped under an active manifest" "vim was linked anyway" ;;
    *) _pass "unnamed tools are skipped under an active manifest" ;;
esac

# ── config-only links the config ───────────────────────────────────────
cfg="$(run_symlinks "btop = config-only")"
assert_contains "$cfg" "btop" "config-only still links the config"

finish_tests
