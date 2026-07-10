#!/bin/bash
#
# Package installation for macOS via Homebrew.
# Called by install.sh
#
# Everything is installed with brew. Brew names here are API-verified; a bare
# `brew install` of an already-present item exits nonzero and would abort the
# run under `set -e`, so every install is guarded with `brew list ... ||`.

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

info "Installing packages for macOS..."

# Homebrew must exist and be on PATH before any brew call.
# shellcheck source=install-homebrew.sh
source "$SCRIPT_DIR/install-homebrew.sh"
install_homebrew

brew update

# Guarded brew install: skip if already present so re-runs don't trip set -e.
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

# Shells
brew_install fish nushell xonsh

# Editors + multiplexers
brew_install neovim vim tmux zellij

# Prompt + shell history
brew_install starship atuin

# Core CLI utilities
brew_install bat fd ripgrep fzf eza zoxide yazi jq yq glow moreutils p7zip asciinema

# System monitoring
brew_install htop btop fastfetch procs progress glances ncdu duf

# Network utilities
brew_install wget curl mtr ipcalc

# Toolchain / runtime / media
brew_install mise rust-analyzer lua imagemagick poppler ffmpeg lazydocker

# Docs + lint
brew_install tldr vale

# uv — Python package/tool manager (replaces the Linux scripts' `sudo pip`)
brew_install uv

# Rust toolchain via rustup (macOS-safe; do this before any cargo use).
# shellcheck source=install-rust.sh
source "$SCRIPT_DIR/install-rust.sh"
install_rust

# Rust TUI tools not in Homebrew (tudiff: terminal diff; herdr: AI agent
# workspace manager) — installed via rustup's cargo.
info "Installing tudiff and herdr..."
cargo install tudiff
cargo install herdr

# Python LSP / lint tools via uv (macOS Python is externally managed — no sudo pip).
info "Installing Python tools via uv..."
uv tool install jedi-language-server || true
uv tool install flake8 || true

# Node (nvm) + bun + global coding-agent packages (shared cross-platform helper).
# shellcheck source=install-global-packages.sh
source "$SCRIPT_DIR/install-global-packages.sh"

# TPM (Tmux Plugin Manager)
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

# Fisher (fish plugin manager) + plugins from fish_plugins.
# shellcheck source=install-fisher.sh
source "$SCRIPT_DIR/install-fisher.sh"
install_fisher

# Required directories
mkdir -p "$HOME/.vim-tmp"
mkdir -p "$HOME/.tmp"
mkdir -p "$HOME/.local/share/nvim/plugged"

success "Package installation complete!"

echo ""
info "To install tmux plugins, start tmux and press: prefix + I (capital i)"
info "Set fish as your default shell:"
info "  echo \"$HOMEBREW_PREFIX/bin/fish\" | sudo tee -a /etc/shells"
info "  chsh -s \"$HOMEBREW_PREFIX/bin/fish\""
