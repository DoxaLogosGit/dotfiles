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

_install_prebuilt_zip() {
    local url="$1" inner="$2" name="$3"
    local tmp="/tmp/$name.zip"
    wget -q "$url" -O "$tmp" || { warning "$name download failed"; return 1; }
    unzip -o "$tmp" -d /tmp >/dev/null || { warning "$name unzip failed"; return 1; }
    sudo mv "/tmp/$inner" /usr/bin/ || { warning "$name install failed"; return 1; }
    rm -rf "$tmp" "/tmp/${name:?}"*
}

starship_pkg() {
    # Debian 13 ships starship 1.22; bookworm and the older Ubuntu releases do
    # not. Prefer the package so it stays maintained, and fall back to the
    # upstream installer, which publishes prebuilt ARM binaries.
    sudo apt-get install -yy starship 2>/dev/null && return 0
    info "starship not in this release's repos — using the upstream installer."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
}

atuin_pkg() {
    # Debian 13 ships atuin 18.6. Without a package the only route is a cargo
    # build, which is minutes on a desktop and far worse on a Pi, so a machine
    # without the package and without a toolchain simply goes without.
    sudo apt-get install -yy atuin 2>/dev/null && return 0
    if command -v cargo >/dev/null 2>&1; then
        info "atuin not in this release's repos — building with cargo."
        cargo install atuin
    else
        warning "atuin needs either the distro package or a Rust toolchain — skipping."
        return 1
    fi
}

eza_pkg() {
    # Debian 13 and Ubuntu 24.04 ship eza; bookworm does not. The upstream
    # prebuilt is x86_64/aarch64 only, so on armv7 the package is the only way.
    sudo apt-get install -yy eza 2>/dev/null && return 0
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64)          _eza_from_release x86_64-unknown-linux-gnu ;;
        aarch64|arm64)   _eza_from_release aarch64-unknown-linux-gnu ;;
        *)
            warning "eza has no package here and no prebuilt for $arch — set 'eza = no' on this machine."
            return 1
            ;;
    esac
}

_eza_from_release() {
    info "eza not in this release's repos — installing the upstream binary for $1."
    _install_prebuilt_zip \
        "https://github.com/eza-community/eza/releases/download/v0.21.1/eza_$1.zip" \
        "eza" eza
}

glow_deb() {
    # Debian 13 (trixie) carries glow 2.0; bookworm and the older Ubuntu
    # releases do not, and there is no upstream .deb worth wiring up for it.
    sudo apt-get install -yy glow 2>/dev/null && return 0
    warning "glow not in this release's repos — skipping"
    return 1
}

node_pkg() {
    # The coding agents declare node >= 22.19 and Debian 13 ships 20.19, so
    # "use the distro package" and "run pi" conflict. Take the distro node when
    # it is new enough, and otherwise fall back to NodeSource — but only on an
    # architecture that has builds at all.
    local need_major=22 have arch
    arch="$(uname -m)"

    sudo apt-get install -yy nodejs npm 2>/dev/null || true
    have="$(node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1)"

    if [ -n "$have" ] && [ "$have" -ge "$need_major" ]; then
        info "node $have from the distro package is new enough."
        return 0
    fi

    case "$arch" in
        armv6l|armv7l|i386|i686)
            # Node stopped publishing 32-bit builds after 20.x, and NodeSource
            # has none either, so there is nothing to upgrade to here. The
            # distro node still serves everything that does not demand 22.
            warning "node >= $need_major has no $arch build; staying on ${have:-none}."
            warning "Agents that require it (pi, opencode) cannot run on this machine — set them to 'no' in its manifest."
            [ -n "$have" ] && return 0
            return 1
            ;;
    esac

    info "distro node is ${have:-absent}; installing node $need_major from NodeSource..."
    curl -fsSL "https://deb.nodesource.com/setup_${need_major}.x" | sudo -E bash - || {
        warning "NodeSource setup failed — node stays at ${have:-none}."
        return 1
    }
    # NodeSource's nodejs bundles npm and conflicts with Debian's npm package;
    # apt resolves that by replacing it.
    sudo apt-get install -yy nodejs
}

pi_npm() {
    # npm rather than bun: there is no bun build for this platform. The package
    # name matches every other OS — the old @mariozechner scope was frozen at
    # 0.73.1 and this machine was the only one still installing from it.
    npm install -g --prefix "$HOME/.local" @earendil-works/pi-coding-agent
}

opencode_npm() {
    npm install -g --prefix "$HOME/.local" opencode-ai
}

uv_install() {
    # Standalone installer rather than pip: it needs no Python of its own and
    # sidesteps PEP 668, which makes Debian-based systems refuse system-wide
    # pip installs.
    if command -v uv >/dev/null 2>&1; then
        info "uv already installed"
        return 0
    fi
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
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
