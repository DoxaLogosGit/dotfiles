#!/bin/bash
#
# Package installation for macOS
# Called by install.sh
#
# Individual tools are NOT listed here: they live in scripts/tools.tsv and are
# installed by pkg_run_table, gated by this machine's manifest. What stays here
# is bootstrap, prerequisites, and the fn: handlers this OS's cells name.
#
# `brew install` of an already-present item exits nonzero and would abort the
# script under set -e, so brew_install and brew_install_cask guard on presence.
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# shellcheck source=manifest.sh
. "$SCRIPT_DIR/manifest.sh"
# shellcheck source=pkg-runner.sh
. "$SCRIPT_DIR/pkg-runner.sh"

# install.sh loads the manifest before calling this script; loading it again
# here keeps the script runnable on its own.
if [ -z "${MANIFEST_TABLE:-}" ]; then
    manifest_load "${DOTFILES_OVERLAY:-$HOME/.dotfiles-local}/manifest.conf" \
                  "$DOTFILES_DIR/scripts/tools.tsv" || exit 1
fi

info "Installing packages for macOS..."

# Homebrew must exist and be on PATH before any brew call.
# shellcheck source=install-homebrew.sh
. "$SCRIPT_DIR/install-homebrew.sh"
install_homebrew

brew update

# Guarded brew install: skip if already present so re-runs don't trip set -e.
# pkg_install_one's brew method calls this, so it must be defined before
# pkg_run_table runs.
brew_install() {
    local formula
    for formula in "$@"; do
        if brew list "$formula" >/dev/null 2>&1; then
            info "$formula already installed"
        else
            info "Installing $formula..."
            brew install "$formula"
        fi
    done
}

# Guarded brew cask install: skip if already present so re-runs don't trip set -e.
brew_install_cask() {
    local cask
    for cask in "$@"; do
        if brew list --cask "$cask" >/dev/null 2>&1; then
            info "$cask already installed"
        else
            info "Installing $cask..."
            brew install --cask "$cask"
        fi
    done
}

# ── Prerequisites (never manifest-gated) ──────────────────────────────────────
brew_install wget curl

# ── fn: handlers named by this OS's cells in tools.tsv ────────────────────────

rustup() {
    # macOS-safe rustup install; must precede any cargo: cell, which is why
    # tools.tsv puts the rust row first.
    # shellcheck source=install-rust.sh
    . "$SCRIPT_DIR/install-rust.sh"
    install_rust
}

ghostty_cask() {
    brew_install_cask ghostty
}

node_nvm() {
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install --lts && nvm use --lts
}

playwright_macos() {
    # Playwright bundles its own browser dependencies on macOS, so no --with-deps.
    bunx playwright install
}

# ── Everything else comes from the table ──────────────────────────────────────
#
# herdr is a brew cell rather than a cargo one: it fails to compile from source
# on macOS. tudiff and tuicr have no formula and stay cargo cells.

pkg_run_table macos

# ── Global packages that are not single tool rows ─────────────────────────────
# shellcheck source=install-global-packages.sh
. "$SCRIPT_DIR/install-global-packages.sh"

# ── Tmux Plugin Manager (part of tmux) ────────────────────────────────────────
if want tmux; then
    TPM_DIR="$HOME/.tmux/plugins/tpm"
    if [ -d "$TPM_DIR" ]; then
        info "TPM already installed, updating..."
        git -C "$TPM_DIR" pull
    else
        info "Installing TPM (Tmux Plugin Manager)..."
        mkdir -p "$HOME/.tmux/plugins"
        git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
        success "TPM installed!"
    fi
fi

# ── oh-my-zsh (part of zsh) ───────────────────────────────────────────────────
if want oh-my-zsh; then
    # shellcheck source=install-oh-my-zsh.sh
    . "$SCRIPT_DIR/install-oh-my-zsh.sh"
    install_oh_my_zsh
fi

# ── Required directories ──────────────────────────────────────────────────────
mkdir -p "$HOME/.vim-tmp"
mkdir -p "$HOME/.tmp"
mkdir -p "$HOME/.local/share/nvim/plugged"

success "Package installation complete!"

echo ""
if want tmux; then
    info "To install tmux plugins, start tmux and press: prefix + I (capital i)"
fi
info "zsh is already the default shell on macOS — nothing to chsh."
