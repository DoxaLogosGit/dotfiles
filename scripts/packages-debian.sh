#!/bin/bash
#
# Package installation for Debian/Ubuntu systems
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

info "Installing packages for Debian/Ubuntu..."

sudo apt-get update

# ── Build prerequisites (never manifest-gated) ────────────────────────────────
# perl is needed by openssl-sys whenever a cargo: tool builds; python3-pip and
# python3-venv back the uv installer and anything that still wants pip.
sudo apt-get install -yy \
    build-essential cmake unzip tar wget curl perl \
    python3-dev python3-pip python3-venv

# ── fn: handlers named by this OS's cells in tools.tsv ────────────────────────

rustup() {
    # Not the distro rustc/cargo package: it conflicts with rustup, lags
    # behind, and some crates need a newer compiler. tools.tsv puts the rust
    # row first so this runs before any cargo: cell.
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

node_pkg() {
    # The coding agents declare node >= 22.19, and Debian 13 ships 20.19, so
    # "use the distro package" and "run pi" genuinely conflict here. Take the
    # distro node when it is new enough and fall back to NodeSource when it is
    # not, rather than silently installing an agent that cannot start.
    local need_major=22 have
    if sudo apt-get install -yy nodejs npm 2>/dev/null; then
        have="$(node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1)"
        if [ -n "$have" ] && [ "$have" -ge "$need_major" ]; then
            info "node $have from the distro package is new enough."
            return 0
        fi
        info "distro node is ${have:-absent}; the agents need >= $need_major."
    fi

    info "Installing node $need_major from NodeSource..."
    curl -fsSL "https://deb.nodesource.com/setup_${need_major}.x" | sudo -E bash - || {
        warning "NodeSource setup failed — node stays at ${have:-none}. Agents needing >= $need_major will not run."
        return 1
    }
    # NodeSource's nodejs bundles npm and conflicts with Debian's npm package;
    # apt resolves that by replacing it.
    sudo apt-get install -yy nodejs
}

mise_curl() {
    curl https://mise.run | sh
}

uv_install() {
    # Standalone installer rather than pip: it needs no Python of its own and
    # sidesteps PEP 668, which makes Debian refuse system-wide pip installs.
    if command -v uv >/dev/null 2>&1; then
        info "uv already installed"
        return 0
    fi
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
}

nushell_pkg() {
    sudo apt-get install -yy nushell 2>/dev/null && return 0
    # shellcheck source=install-nushell.sh
    . "$SCRIPT_DIR/install-nushell.sh"
    install_nushell
}

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

playwright_linux() {
    bunx playwright install --with-deps
}

# ── Everything else comes from the table ──────────────────────────────────────

pkg_run_table debian

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

success "Package installation complete!"

echo ""
if want tmux; then
    info "To install tmux plugins, start tmux and press: prefix + I (capital i)"
fi
info "Don't forget to set up zsh as your default shell: chsh -s /usr/bin/zsh"
