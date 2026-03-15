#!/bin/bash
#
# Package installation for Raspbian (Trixie / Debian 13) on Raspberry Pi
# Core: neovim, tmux, fish. Everything else is best-effort.
# Called by install.sh
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

ARCH=$(uname -m)
info "Installing packages for Raspbian Trixie (arch: $ARCH)..."

# ── Core (required) ──────────────────────────────────────────────────────────

sudo apt-get update

sudo apt-get install -yy \
    build-essential cmake unzip tar wget curl git \
    python3-dev python3-pip python3-venv

# Neovim + deps needed by the lua/lsp config
sudo apt-get install -yy neovim lua5.4 ripgrep fd-find fzf jq bat clang

# Fish
sudo apt-get install -yy fish

# Tmux
sudo apt-get install -yy tmux

# ── TPM (Tmux Plugin Manager) ────────────────────────────────────────────────

TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ -d "$TPM_DIR" ]; then
    git -C "$TPM_DIR" pull
else
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    success "TPM installed"
fi

# ── Fisher (Fish plugin manager) ─────────────────────────────────────────────

# shellcheck source=install-fisher.sh
source "$(dirname "${BASH_SOURCE[0]}")/install-fisher.sh"
install_fisher

# ── Best-effort extras ───────────────────────────────────────────────────────

# zoxide — used in fish config
sudo apt-get install -yy zoxide || warning "zoxide not available, skipping"

# htop
sudo apt-get install -yy htop || true

# Starship prompt — has ARM builds
info "Installing starship..."
curl -sS https://starship.rs/install.sh | sh -s -- -y || warning "starship install failed"

# Node.js via nvm — needed for nvim LSP servers / tree-sitter
info "Installing Node.js via nvm..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash || warning "nvm install failed"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts && nvm use --lts || warning "node install failed"

# Python LSP tools
pip3 install --break-system-packages jedi_language_server flake8 || true

# eza (ll alias in fish config) — aarch64 only; armv7 build name differs
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    info "Installing eza..."
    wget -q "https://github.com/eza-community/eza/releases/download/v0.21.1/eza_aarch64-unknown-linux-gnu.zip" -O /tmp/eza.zip \
        && unzip -o /tmp/eza.zip -d /tmp \
        && sudo mv /tmp/eza /usr/bin/ \
        && rm -f /tmp/eza.zip \
        || warning "eza install failed, skipping"
else
    warning "Skipping eza prebuilt on ARMv7 — install via 'cargo install eza' if needed"
fi

# ── Required dirs ────────────────────────────────────────────────────────────

mkdir -p "$HOME/.vim-tmp" "$HOME/.tmp"

success "Raspbian package installation complete!"
echo ""
info "Set fish as default shell: chsh -s /usr/bin/fish"
info "Install tmux plugins: start tmux, then prefix + I"
info "Neovim plugins install automatically on first launch via lazy.nvim"
