#!/bin/bash
#
# Install Node.js (via nvm), bun, and global coding-agent packages.
# Sourced by packages-debian.sh, packages-fedora.sh and packages-macos.sh.
# OS-specific package choices live in the guarded block below.
#

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# ── Node.js via nvm ───────────────────────────────────────────────────────────

info "Installing Node.js via nvm..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts

# ── Bun ───────────────────────────────────────────────────────────────────────

info "Installing bun..."
curl -fsSL https://bun.sh/install | bash
export PATH="$HOME/.bun/bin:$PATH"

# ── Rust via rustup ──────────────────────────────────────────────────────────
# Idempotent: the package scripts install rust earlier so cargo installs use
# rustup's toolchain; this is a no-op (just an update) when already installed.

# shellcheck source=install-rust.sh
source "$(dirname "${BASH_SOURCE[0]}")/install-rust.sh"
install_rust

# ── Global packages ───────────────────────────────────────────────────────────

info "Installing global packages via bun..."

# Cross-platform packages.
# pi was renamed from @mariozechner/* to @earendil-works/* at 0.74; the old
# scope is frozen at 0.73.1.
bun install -g @earendil-works/pi-coding-agent
bun install -g @openai/codex
bun install -g opencode-ai
bun install -g @dungle-scrubs/tallow
bun install -g playwright

# ── OS-specific global packages ──────────────────────────────────────────────
if [ "$(uname -s)" = "Darwin" ]; then
    # Claude Code is skipped on macOS: the company image blocks Anthropic.
    # Playwright bundles its own browser dependencies here, so no --with-deps.
    bunx playwright install
else
    bun install -g @anthropic-ai/claude-code
    # --with-deps shells out to apt/dnf for browser system libraries.
    bunx playwright install --with-deps
fi

bun install -g @playwright/mcp


success "Global packages installed!"

# pi agent packages. The tracked package list lives in install-pi-packages.sh;
# ~/.pi/agent/settings.json is untracked machine state. Set DOTFILES_PERSONAL=1
# to also install free-tier routing (personal machines only).
if command -v pi &>/dev/null; then
    # shellcheck source=install-pi-packages.sh
    source "$(dirname "${BASH_SOURCE[0]}")/install-pi-packages.sh"
    if [ "${DOTFILES_PERSONAL:-0}" = "1" ]; then
        install_pi_packages --personal
    else
        install_pi_packages
    fi
else
    info "pi not installed — skipping pi packages"
fi
