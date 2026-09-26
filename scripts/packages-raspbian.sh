#!/bin/bash
#
# Package installation for Raspbian (Trixie / Debian 13) on Raspberry Pi
# Called by install.sh
#
# Individual tools are NOT listed here: they live in scripts/tools.tsv and are
# installed by pkg_run_table, gated by this machine's manifest. What stays here
# is bootstrap, build prerequisites, and the fn: handlers this OS's cells name.
#
# The Pi runs tmux, not zellij, and needs no Rust toolchain: see the raspbian
# column of tools.tsv, where zellij, atuin, herdr, tudiff and tuicr are all '-'
# because Raspbian ships none of them and building them from source costs
# 20-30 minutes on this hardware.
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# shellcheck source=manifest.sh
. "$SCRIPT_DIR/manifest.sh"
# shellcheck source=pkg-runner.sh
. "$SCRIPT_DIR/pkg-runner.sh"

if [ -z "${MANIFEST_TABLE:-}" ]; then
    manifest_load "${DOTFILES_OVERLAY:-$HOME/.dotfiles-local}/manifest.conf" \
                  "$DOTFILES_DIR/scripts/tools.tsv" || exit 1
fi

ARCH=$(uname -m)
info "Installing packages for Raspbian Trixie (arch: $ARCH)..."

sudo apt-get update

# ── Build prerequisites (never manifest-gated) ────────────────────────────────
sudo apt-get install -yy \
    build-essential cmake unzip tar wget curl git \
    python3-dev python3-pip python3-venv

# ── fn: handlers named by this OS's cells in tools.tsv ────────────────────────

starship_curl() {
    # Raspbian has no starship package, but upstream publishes prebuilt ARM
    # binaries — nothing is compiled here.
    curl -sS https://starship.rs/install.sh | sh -s -- -y
}

node_nvm() {
    local nvm_version
    nvm_version=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest |
        grep '"tag_name"' | cut -d'"' -f4)
    [ -n "$nvm_version" ] || nvm_version="v0.40.1"
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh" | bash
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install --lts && nvm use --lts
}

pi_npm() {
    # npm rather than bun: there is no bun build for this platform. The package
    # name matches every other OS — the old @mariozechner scope was frozen at
    # 0.73.1 and this machine was the only one still installing from it.
    npm install -g @earendil-works/pi-coding-agent
}

opencode_npm() {
    npm install -g opencode-ai
}

eza_raspbian() {
    # Prebuilt release binary. aarch64 only: the armv7 asset is named
    # differently and is not published for every release.
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        wget -q "https://github.com/eza-community/eza/releases/download/v0.21.1/eza_aarch64-unknown-linux-gnu.zip" \
            -O /tmp/eza.zip &&
            unzip -o /tmp/eza.zip -d /tmp >/dev/null &&
            sudo mv /tmp/eza /usr/bin/ &&
            rm -f /tmp/eza.zip
    else
        warning "No eza prebuilt for $ARCH — set 'eza = no' on this machine, or install it with cargo."
        return 1
    fi
}

python_devel() {
    sudo apt-get install -yy python3-dev python3-pip
}

python_lsp_pi() {
    # --break-system-packages: Debian refuses a system-wide pip install without
    # it, and this machine has no virtualenv workflow to put these in.
    pip3 install --break-system-packages jedi_language_server flake8
}

# ── Everything else comes from the table ──────────────────────────────────────

pkg_run_table raspbian

# ── Global packages that are not single tool rows ─────────────────────────────
# shellcheck source=install-global-packages.sh
. "$SCRIPT_DIR/install-global-packages.sh"

# ── Tmux Plugin Manager (part of tmux, which is this machine's multiplexer) ───
if want tmux; then
    TPM_DIR="$HOME/.tmux/plugins/tpm"
    if [ -d "$TPM_DIR" ]; then
        git -C "$TPM_DIR" pull
    else
        git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
        success "TPM installed"
    fi
fi

# ── oh-my-zsh (part of zsh) ───────────────────────────────────────────────────
if want oh-my-zsh; then
    # shellcheck source=install-oh-my-zsh.sh
    . "$SCRIPT_DIR/install-oh-my-zsh.sh"
    install_oh_my_zsh
fi

# ── Required dirs ─────────────────────────────────────────────────────────────
mkdir -p "$HOME/.vim-tmp" "$HOME/.tmp"

success "Raspbian package installation complete!"
echo ""
info "Set zsh as default shell: chsh -s /usr/bin/zsh"
if want tmux; then
    info "Install tmux plugins: start tmux, then prefix + I"
fi
info "Neovim plugins install automatically on first launch via lazy.nvim"
