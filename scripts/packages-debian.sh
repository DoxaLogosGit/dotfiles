#!/bin/bash
#
# Package installation for Debian/Ubuntu systems
# Called by install.sh
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

info "Installing packages for Debian/Ubuntu..."

# Update package lists
sudo apt-get update

# Python development
sudo apt-get install -yy python-dev || true
sudo apt-get install -yy python-pip || true
sudo apt-get install -yy python3-dev
sudo apt-get install -yy python3-pip
sudo apt-get install -yy python3-venv

# Build tools
sudo apt-get install -yy build-essential
sudo apt-get install -yy cmake

# General utilities
sudo apt-get install -yy wget
sudo apt-get install -yy curl
sudo apt-get install -yy vifm

# Editors
sudo apt-get install -yy vim-gtk
sudo apt-get install -yy neovim

# Terminal utilities
sudo apt-get install -yy glow
sudo apt-get install -yy lua5.4 || sudo apt-get install -yy lua
sudo apt-get install -yy bat
sudo apt-get install -yy ffmpeg
sudo apt-get install -yy p7zip-full || sudo apt-get install -yy 7zip
sudo apt-get install -yy jq
sudo apt-get install -yy poppler-utils
sudo apt-get install -yy fd-find
sudo apt-get install -yy ripgrep
sudo apt-get install -yy fzf
sudo apt-get install -yy zoxide
sudo apt-get install -yy imagemagick

# Shells
sudo apt-get install -yy fish
sudo apt-get install -yy nushell || info "nushell not in repos, install manually"

# Tmux
sudo apt-get install -yy tmux

# Development tools
sudo apt-get install -yy clang
sudo apt-get install -yy rustc cargo || true

# Python tools
sudo pip3 install tldr || true

# Install starship prompt
info "Installing starship..."
curl -sS https://starship.rs/install.sh | sh -s -- -y

# Install rust-analyzer
info "Installing rust-analyzer..."
mkdir -p ~/.local/bin
curl -L https://github.com/rust-lang/rust-analyzer/releases/latest/download/rust-analyzer-x86_64-unknown-linux-gnu.gz | gunzip -c - > ~/.local/bin/rust-analyzer
chmod +x ~/.local/bin/rust-analyzer

# Python LSP tools
pip install jedi_language_server || pip3 install jedi_language_server
pip install flake8 || pip3 install flake8
pip install vale || pip3 install vale

# Install Node.js via nvm
info "Installing Node.js via nvm..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts

# Install bun
info "Installing bun..."
curl -fsSL https://bun.sh/install | bash

# Install npm global packages
info "Installing npm global packages..."
npm install -g @anthropic-ai/claude-code
npm install -g playwright
npx playwright install --with-deps
npm install -g @playwright/mcp

# Install yazi
info "Installing yazi..."
wget -q https://github.com/sxyazi/yazi/releases/download/v25.4.8/yazi-x86_64-unknown-linux-gnu.zip -O /tmp/yazi.zip
unzip -o /tmp/yazi.zip -d /tmp
sudo mv /tmp/yazi-x86_64-unknown-linux-gnu/yazi /usr/bin/
rm -rf /tmp/yazi*

# Install eza
info "Installing eza..."
wget -q https://github.com/eza-community/eza/releases/download/v0.21.1/eza_x86_64-unknown-linux-gnu.zip -O /tmp/eza.zip
unzip -o /tmp/eza.zip -d /tmp
sudo mv /tmp/eza /usr/bin/
rm -rf /tmp/eza*

# Install mise
info "Installing mise..."
curl https://mise.run | sh

# Install TPM (Tmux Plugin Manager)
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ -d "$TPM_DIR" ]; then
    info "TPM already installed, updating..."
    cd "$TPM_DIR" && git pull
    cd -
else
    info "Installing TPM (Tmux Plugin Manager)..."
    mkdir -p "$HOME/.tmux/plugins"
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    success "TPM installed!"
fi

# Install Oh My Fish
if [ -d "$HOME/.local/share/omf" ]; then
    info "Oh My Fish already installed"
else
    info "Installing Oh My Fish..."
    if command -v fish &> /dev/null; then
        curl -L https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install > /tmp/omf-install.fish
        fish /tmp/omf-install.fish --noninteractive --yes
        rm -f /tmp/omf-install.fish
        success "Oh My Fish installed!"
    else
        warning "Fish shell not found. Oh My Fish will need to be installed manually after fish is available."
    fi
fi

# Create required directories
mkdir -p $HOME/.vim-tmp
mkdir -p $HOME/.tmp

success "Package installation complete!"

echo ""
info "To install tmux plugins, start tmux and press: prefix + I (capital i)"
info "Don't forget to set up fish as your default shell: chsh -s /usr/bin/fish"
