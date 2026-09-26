#!/bin/bash
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

# Phase gates are observable through --dry-run output. $1 = manifest contents.
run_dry() {
    local manifest_body="$1" sandbox out
    sandbox="$(make_sandbox)"
    if [ -n "$manifest_body" ]; then
        printf '%s\n' "$manifest_body" > "$sandbox/overlay/manifest.conf"
    fi
    out=$(DOTFILES_OVERLAY="$sandbox/overlay" bash "$REPO/install.sh" --dry-run --all 2>&1 || true)
    cleanup_sandbox "$sandbox"
    printf '%s' "$out"
}

baseline="$(run_dry "")"
assert_contains "$baseline" "Manifest: none" "no manifest reports none"
assert_contains "$baseline" "font" "fonts phase runs with no manifest"

gated="$(run_dry "$(printf 'zsh = yes\nfonts = no\nsystemd = no\nclaude-plugins = no\n')")"
assert_contains "$gated" "Skipping fonts (manifest)" "fonts = no skips the font phase"
assert_contains "$gated" "Skipping Claude plugins (manifest)" "claude-plugins = no skips plugins"
assert_contains "$gated" "skipped:" "summary lists skips"
assert_contains "$gated" "fonts" "summary names fonts as skipped"

# A phase named yes still runs.
kept="$(run_dry "$(printf 'zsh = yes\nfonts = yes\nsystemd = no\nclaude-plugins = no\n')")"
case "$kept" in
    *"Skipping fonts"*) _fail "fonts = yes keeps the font phase" "fonts skipped anyway" ;;
    *) _pass "fonts = yes keeps the font phase" ;;
esac

# An invalid manifest stops the run before anything is planned.
bad="$(run_dry "ghosty = yes")"
assert_contains "$bad" "is not a known tool" "an unknown key stops the run"
case "$bad" in
    *"Would link"*) _fail "a failed manifest plans nothing" "links were still planned" ;;
    *) _pass "a failed manifest plans nothing" ;;
esac

finish_tests
