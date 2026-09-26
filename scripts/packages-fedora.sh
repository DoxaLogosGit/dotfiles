#!/bin/bash
#
# Package installation for Fedora/RHEL systems
# Called by install.sh
#
# Individual tools are NOT listed here: they live in scripts/tools.tsv and are
# installed by pkg_run_table, gated by this machine's manifest. What stays here
# is bootstrap, build prerequisites, and the fn: handlers this OS's cells name.
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

info "Installing packages for Fedora/RHEL..."

sudo dnf update -y

# ── Build prerequisites (never manifest-gated) ────────────────────────────────
# These are not preferences. perl-core, for instance, is needed by openssl-sys
# whenever any cargo: tool builds; a machine that declined it would fail deep
# inside an unrelated crate with an unreadable error.
sudo dnf install -y cmake make gcc-c++ curl wget perl-core clang-devel unzip

# ── fn: handlers named by this OS's cells in tools.tsv ────────────────────────

rustup() {
    # Not the Fedora rust/cargo package: it conflicts with rustup, lags behind,
    # and some crates need a newer compiler. Install this before any cargo:
    # cell runs — tools.tsv puts the rust row first for that reason.
    # shellcheck source=install-rust.sh
    . "$SCRIPT_DIR/install-rust.sh"
    install_rust
}

bun_install() {
    if command -v bun >/dev/null 2>&1; then
        info "bun already installed"
        return 0
    fi
    curl -fsSL https://bun.sh/install | bash
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
}

mise_curl() {
    curl https://mise.run | sh
}

nushell_pkg() {
    # Fedora ships nushell in recent releases; fall back to the upstream
    # installer when it does not.
    sudo dnf install -y nushell 2>/dev/null && return 0
    # shellcheck source=install-nushell.sh
    . "$SCRIPT_DIR/install-nushell.sh"
    install_nushell
}

ffmpeg_fedora() {
    # ffmpeg is not in Fedora's own repositories — it comes from RPM Fusion.
    # The previous `dnf install -y ffmpeg` ran bare under `set -e`, so a fresh
    # Fedora without RPM Fusion aborted the entire install here.
    if ! sudo dnf install -y ffmpeg 2>/dev/null; then
        info "Enabling RPM Fusion (free) for ffmpeg..."
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" ||
            { warning "could not enable RPM Fusion — skipping ffmpeg"; return 1; }
        sudo dnf install -y ffmpeg
    fi
}

lazydocker_copr() {
    sudo dnf copr enable -y atim/lazydocker
    sudo dnf install -y lazydocker
}

# Prebuilt release binaries: these projects publish static x86_64 builds, and
# building them from source costs minutes for no benefit.
_install_prebuilt_zip() {
    local url="$1" inner="$2" name="$3"
    local tmp="/tmp/$name.zip"
    wget -q "$url" -O "$tmp" || { warning "$name download failed"; return 1; }
    unzip -o "$tmp" -d /tmp >/dev/null || { warning "$name unzip failed"; return 1; }
    sudo mv "/tmp/$inner" /usr/bin/ || { warning "$name install failed"; return 1; }
    rm -rf "$tmp" "/tmp/${name:?}"*
}

yazi_prebuilt() {
    _install_prebuilt_zip \
        "https://github.com/sxyazi/yazi/releases/download/v25.4.8/yazi-x86_64-unknown-linux-gnu.zip" \
        "yazi-x86_64-unknown-linux-gnu/yazi" yazi
}

eza_prebuilt() {
    _install_prebuilt_zip \
        "https://github.com/eza-community/eza/releases/download/v0.21.1/eza_x86_64-unknown-linux-gnu.zip" \
        "eza" eza
}

playwright_linux() {
    # --with-deps shells out to dnf for browser system libraries.
    bunx playwright install --with-deps
}

# ── Everything else comes from the table ──────────────────────────────────────

pkg_run_table fedora

# ── Global bun packages that are not single tool rows ─────────────────────────
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
info "Don't forget to set up zsh as your default shell: chsh -s /usr/bin/zsh"

# rust-analyzer comes from `rustup component add` in install-rust.sh, not a
# standalone binary here — that stays version-matched to the active toolchain
# and avoids shadowing the rustup one on PATH.
