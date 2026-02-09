#!/bin/bash
#
# Package installation for Fedora/RHEL systems
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

info "Installing packages for Fedora/RHEL..."

# Update package lists
sudo dnf update -y

# Build tools
sudo dnf install -y cmake
sudo dnf install -y make
sudo dnf install -y gcc-c++

# Languages
sudo dnf install -y clang
sudo dnf install -y rust cargo
sudo dnf install -y clang-devel
sudo dnf install -y python-devel || sudo dnf install -y python3-devel
sudo dnf install -y python-pip || sudo dnf install -y python3-pip
sudo dnf install -y lua

# Editors
sudo dnf install -y vim
sudo dnf install -y neovim

# Tmux
sudo dnf install -y tmux

# General utilities
sudo dnf install -y ImageMagick
sudo dnf install -y glow
sudo dnf install -y poppler
sudo dnf install -y ffmpeg
sudo dnf install -y jq
sudo dnf install -y yq || true
sudo dnf install -y moreutils
sudo dnf install -y asciinema

# Lazydocker
sudo dnf copr enable -y atim/lazydocker
sudo dnf install -y lazydocker

# System monitoring
sudo dnf install -y fastfetch
sudo dnf install -y dstat || true
sudo dnf install -y progress
sudo dnf install -y procs

# File system utilities
sudo dnf install -y zoxide
sudo dnf install -y bat
sudo dnf install -y fd-find
sudo dnf install -y ripgrep
sudo dnf install -y fzf
sudo dnf install -y p7zip || true
sudo dnf install -y iotop

# Disk utilities
sudo dnf install -y ncdu
sudo dnf install -y duf

# Network utilities
sudo dnf install -y wget
sudo dnf install -y curl
sudo dnf install -y lshw
sudo dnf install -y mtr
sudo dnf install -y wireshark-cli || true
sudo dnf install -y ipcalc

# Python system tools
sudo pip install tldr || pip3 install tldr
sudo pip install bpytop || pip3 install bpytop
sudo pip install glances || pip3 install glances
sudo pip install uv || pip3 install uv

# Shells
sudo dnf install -y fish
sudo dnf install -y nushell || info "nushell not in repos, install manually"

# Install starship prompt
info "Installing starship..."
curl -sS https://starship.rs/install.sh | sh -s -- -y

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
mkdir -p $HOME/.local/share/nvim/plugged

success "Package installation complete!"

echo ""
info "To install tmux plugins, start tmux and press: prefix + I (capital i)"
info "Don't forget to set up fish as your default shell: chsh -s /usr/bin/fish"
