#!/bin/bash
#
# Package installation for Raspbian (Trixie / Debian 13) on Raspberry Pi
# Minimal install: neovim, tmux, fish + plugins
# Called by install.sh
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Detect ARM architecture
ARCH=$(uname -m)
case "$ARCH" in
    aarch64|arm64)
        RUST_ARCH="aarch64-unknown-linux-gnu"
        NU_ARCH="aarch64-unknown-linux-gnu"
        EZA_ARCH="aarch64-unknown-linux-gnu"
        YAZI_ARCH="aarch64-unknown-linux-gnu"
        ;;
    armv7l)
        RUST_ARCH="arm-unknown-linux-gnueabihf"
        NU_ARCH="armv7-unknown-linux-gnueabihf"
        EZA_ARCH="arm-unknown-linux-gnueabihf"
        YAZI_ARCH="armv7-unknown-linux-gnueabi"
        ;;
    *)
        warning "Unrecognized architecture: $ARCH — assuming aarch64"
        RUST_ARCH="aarch64-unknown-linux-gnu"
        NU_ARCH="aarch64-unknown-linux-gnu"
        EZA_ARCH="aarch64-unknown-linux-gnu"
        YAZI_ARCH="aarch64-unknown-linux-gnu"
        ;;
esac

info "Installing packages for Raspbian Trixie (arch: $ARCH)..."

# Update package lists
sudo apt-get update

# Core dependencies
sudo apt-get install -yy \
    build-essential \
    cmake \
    unzip \
    tar \
    wget \
    curl \
    git \
    python3-dev \
    python3-pip \
    python3-venv

# Neovim and its runtime dependencies
sudo apt-get install -yy neovim
sudo apt-get install -yy \
    lua5.4 \
    ripgrep \
    fd-find \
    fzf \
    jq \
    bat \
    clang                   # needed by nvim-lspconfig / mason

# Fish shell + zoxide (used in fish config)
sudo apt-get install -yy fish
sudo apt-get install -yy zoxide

# Tmux
sudo apt-get install -yy tmux

# System monitoring (lightweight, nice to have on Pi)
sudo apt-get install -yy htop

# Python LSP tools (used by neovim lspconfig)
pip3 install --break-system-packages jedi_language_server || true
pip3 install --break-system-packages flake8 || true

# Node.js via nvm — needed for neovim LSP servers and tree-sitter parsers
info "Installing Node.js via nvm..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts

# Starship prompt (used by fish config, has ARM builds)
info "Installing starship..."
curl -sS https://starship.rs/install.sh | sh -s -- -y

# eza — used by the ll alias in fish/config.fish (ARM build)
info "Installing eza..."
EZA_VERSION="v0.21.1"
wget -q "https://github.com/eza-community/eza/releases/download/${EZA_VERSION}/eza_${EZA_ARCH}.zip" -O /tmp/eza.zip
unzip -o /tmp/eza.zip -d /tmp
sudo mv /tmp/eza /usr/bin/
rm -f /tmp/eza.zip

# Yazi — optional file manager (ARM build), skip on armv7 if not available
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    info "Installing yazi..."
    YAZI_VERSION="v25.4.8"
    wget -q "https://github.com/sxyazi/yazi/releases/download/${YAZI_VERSION}/yazi-${YAZI_ARCH}.zip" -O /tmp/yazi.zip \
        && unzip -o /tmp/yazi.zip -d /tmp \
        && sudo mv "/tmp/yazi-${YAZI_ARCH}/yazi" /usr/bin/ \
        && rm -rf /tmp/yazi.zip "/tmp/yazi-${YAZI_ARCH}" \
        || warning "yazi install failed, skipping"
else
    warning "Skipping yazi on ARMv7 (no prebuilt binary)"
fi

# TPM — Tmux Plugin Manager
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ -d "$TPM_DIR" ]; then
    info "TPM already installed, updating..."
    git -C "$TPM_DIR" pull
else
    info "Installing TPM..."
    mkdir -p "$HOME/.tmux/plugins"
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    success "TPM installed!"
fi

# Fisher — Fish plugin manager
# shellcheck source=install-fisher.sh
source "$(dirname "${BASH_SOURCE[0]}")/install-fisher.sh"
install_fisher

# Required dirs used by vim/nvim config
mkdir -p "$HOME/.vim-tmp"
mkdir -p "$HOME/.tmp"

success "Raspbian package installation complete!"

echo ""
info "Set fish as your default shell: chsh -s /usr/bin/fish"
info "To install tmux plugins, start tmux and press: prefix + I (capital i)"
info "Neovim plugins will be installed automatically on first launch via lazy.nvim"
