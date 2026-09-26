#!/bin/bash
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

# The Pi cannot be reached from here, and no container emulates its hardware.
# This runs the real packages-raspbian.sh against stubbed apt/npm/curl with
# PKG_DRY_RUN on, which proves the flow: handlers defined before use, the
# raspbian column read, and — the point of this task — that nothing compiles
# from source on a machine where that costs 20-30 minutes.

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

sandbox="$(make_sandbox)"
stub_bin="$sandbox/bin"
mkdir -p "$stub_bin"

for cmd in sudo apt-get npm node nvm curl wget unzip git pip3 pip bun bunx cargo rustc; do
    cat > "$stub_bin/$cmd" <<EOF
#!/usr/bin/env bash
echo "STUB $cmd \$*"
exit 0
EOF
    chmod +x "$stub_bin/$cmd"
done

run_pi() {
    local manifest_body="$1"
    printf '%s\n' "$manifest_body" > "$sandbox/manifest.conf"
    (
        PATH="$stub_bin:$PATH"; export PATH
        HOME="$sandbox/home"; export HOME
        DOTFILES_DIR="$REPO"; export DOTFILES_DIR
        DOTFILES_OVERLAY="$sandbox"; export DOTFILES_OVERLAY
        PKG_DRY_RUN=true; export PKG_DRY_RUN
        bash "$REPO/scripts/packages-raspbian.sh" 2>&1
    )
}

# The Pi's real manifest, as committed to its overlay directory.
pi_manifest="$(printf '%s\n' \
    'zsh = yes' 'bash = yes' 'git = yes' 'vim = yes' 'nvim = yes' \
    'tmux = yes' 'zellij = no' 'rust = no' 'node = yes' \
    'starship = yes' 'atuin = no' 'eza = yes' 'bat = yes' 'fd = yes' \
    'ripgrep = yes' 'fzf = yes' 'jq = yes' 'zoxide = yes' 'htop = yes' \
    'btop = yes' 'lua = yes' 'clang = yes' 'shellcheck = yes' \
    'herdr = no' 'tudiff = no' 'tuicr = no' \
    'pi = yes' 'opencode = yes' 'claude = no' 'codex = no' \
    'python-lsp = yes' 'pi-packages = yes' 'oh-my-zsh = yes' \
    'fonts = no' 'systemd = no' 'claude-plugins = no')"

out="$(run_pi "$pi_manifest")"

assert_contains "$out" "Raspbian package installation complete" "the script runs to completion"

# ── the point of the task: no toolchain, no source builds ───────────────────
case "$out" in
    *"cargo install"*) _fail "nothing is built with cargo on the Pi" \
        "$(printf '%s' "$out" | grep 'cargo install' | head -3)" ;;
    *) _pass "nothing is built with cargo on the Pi" ;;
esac
assert_contains "$out" "Skipping rust (manifest)" "the Rust toolchain is declined"
# zellij prints no skip line: its raspbian cell is '-', so the table skips it
# before the manifest is consulted. Assert the outcome instead of the message.
case "$out" in
    *zellij*) _fail "zellij is never installed on the Pi" "zellij appeared in the run" ;;
    *) _pass "zellij is never installed on the Pi" ;;
esac
assert_contains "$out" "Installing tmux" "tmux is the multiplexer here"

# ── prebuilt binaries and npm, not compilation ──────────────────────────────
assert_contains "$out" "starship_curl" "starship comes from the prebuilt installer"
assert_contains "$out" "eza_raspbian" "eza comes from the prebuilt release"
assert_contains "$out" "pi_npm" "pi is installed with npm, not bun"

# ── the stale package name is gone ──────────────────────────────────────────
handler="$(sed -n '/^pi_npm()/,/^}/p' "$REPO/scripts/packages-raspbian.sh")"
assert_contains "$handler" "@earendil-works/pi-coding-agent" "pi_npm installs the current package"
# Check the install command, not the whole function: the comment above it
# explains why the old scope was dropped and legitimately names it.
installed_pkg="$(printf '%s' "$handler" | grep 'npm install -g')"
case "$installed_pkg" in
    *mariozechner*) _fail "the stale @mariozechner scope is gone" "still installed: $installed_pkg" ;;
    *) _pass "the stale @mariozechner scope is gone" ;;
esac

# ── every fn: cell resolves ─────────────────────────────────────────────────
case "$out" in
    *"is not defined in this OS's package script"*)
        _fail "every fn: cell has a handler defined" \
              "$(printf '%s' "$out" | grep 'not defined' | head -3)" ;;
    *) _pass "every fn: cell has a handler defined" ;;
esac

# ── no other OS's package manager leaks in ──────────────────────────────────
case "$out" in
    *"dnf install"*|*"brew install"*) _fail "the Pi uses only apt and npm" "another manager appeared" ;;
    *) _pass "the Pi uses only apt and npm" ;;
esac

# ── tmux-raspbian.conf is retired; the Pi carries its own in the overlay ────
assert_fail "tmux-raspbian.conf no longer exists in the repo" \
    test -f "$REPO/tmux/tmux-raspbian.conf"
assert_fail "install.sh no longer names it" \
    grep -q "tmux-raspbian" "$REPO/install.sh"

cleanup_sandbox "$sandbox"
finish_tests
