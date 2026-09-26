#!/bin/bash
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

# packages-macos.sh cannot be executed on any machine available here, and no
# container runs macOS. `bash -n` only proves it parses. This runs the real
# script end to end against stubbed brew/uv/bunx binaries with PKG_DRY_RUN on,
# which does prove: the handlers its table cells name are defined before
# pkg_run_table needs them, the macos column is the one read, and the manifest
# gates what it should.
#
# Run this under bash 3.2 too (tests/run-containers.sh does), since that is the
# bash the MacBook will use.

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

sandbox="$(make_sandbox)"
stub_bin="$sandbox/bin"
mkdir -p "$stub_bin"

# Stubs: echo what was asked for, succeed, touch nothing.
# bun belongs in this list: without it the test silently depended on the host
# having bun installed, and only failed once run in a container that did not.
for cmd in brew bun bunx uv npm node cargo rustup nvm git pip pip3; do
    cat > "$stub_bin/$cmd" <<EOF
#!/usr/bin/env bash
echo "STUB $cmd \$*"
exit 0
EOF
    chmod +x "$stub_bin/$cmd"
done
# brew list must fail, or brew_install reports everything already installed.
cat > "$stub_bin/brew" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    list) exit 1 ;;
    shellenv) echo "export HOMEBREW_STUB=1" ;;
    --version) echo "Homebrew 4.0.0-stub" ;;
    *) echo "STUB brew $*" ;;
esac
exit 0
EOF
chmod +x "$stub_bin/brew"

run_macos() {
    local manifest_body="$1"
    printf '%s\n' "$manifest_body" > "$sandbox/manifest.conf"
    (
        PATH="$stub_bin:$PATH"
        export PATH
        HOME="$sandbox/home"
        export HOME
        DOTFILES_DIR="$REPO"
        export DOTFILES_DIR
        DOTFILES_OVERLAY="$sandbox"
        export DOTFILES_OVERLAY
        PKG_DRY_RUN=true
        export PKG_DRY_RUN
        bash "$REPO/scripts/packages-macos.sh" 2>&1
    )
}

# ── a full manifest ─────────────────────────────────────────────────────────
all_yes="$(grep -vE '^[[:space:]]*(#|$)' "$REPO/manifest.example" | sed 's/#.*//')"
out="$(run_macos "$all_yes")"

assert_contains "$out" "Package installation complete" "the script runs to completion"
assert_contains "$out" "brew_install neovim" "a brew cell dispatches to brew_install"
assert_contains "$out" "ghostty_cask" "the ghostty cask handler is reached"
# The python LSP tools come through the table's uv cell now, not a macOS-only
# handler: uv tool install gives the same isolated environments on every OS.
assert_contains "$out" "jedi-language-server" "the python LSP tools install via uv"
assert_contains "$out" "cargo install tudiff" "cargo-only tools still use cargo on macOS"
assert_contains "$out" "brew_install herdr" "herdr comes from brew on macOS, not cargo"

# No handler may be missing: that warning means a cell names something undefined.
case "$out" in
    *"is not defined in this OS's package script"*)
        _fail "every fn: cell has a handler defined" \
              "$(printf '%s' "$out" | grep 'not defined' | head -3)" ;;
    *) _pass "every fn: cell has a handler defined" ;;
esac

# The fedora column must not leak in.
case "$out" in
    *"dnf install"*) _fail "macOS never runs dnf" "dnf appeared" ;;
    *) _pass "macOS never runs dnf" ;;
esac

# ── the MacBook's actual manifest: no tmux, no claude ───────────────────────
out="$(run_macos "$(printf 'zsh = yes\nnvim = yes\nzellij = yes\ntmux = no\nclaude = no\n')")"
assert_contains "$out" "Skipping tmux (manifest)" "tmux = no skips the package"
case "$out" in
    *"prefix + I"*) _fail "tmux = no suppresses the TPM hint" "the hint was printed anyway" ;;
    *) _pass "tmux = no suppresses the TPM hint" ;;
esac
case "$out" in
    *"tmux/plugins/tpm"*) _fail "tmux = no skips the TPM clone" "TPM was cloned" ;;
    *) _pass "tmux = no skips the TPM clone" ;;
esac
assert_contains "$out" "brew_install zellij" "zellij is still installed on the MacBook"

cleanup_sandbox "$sandbox"
finish_tests
