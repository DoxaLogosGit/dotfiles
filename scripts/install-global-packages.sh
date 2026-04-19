#!/bin/bash
#
# Install Node.js (via nvm), bun, and global coding-agent packages.
# Called by packages-debian.sh and packages-fedora.sh
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

# ── Global packages ───────────────────────────────────────────────────────────

info "Installing global packages via bun..."
bun install -g @anthropic-ai/claude-code
bun install -g @google/gemini-cli
bun install -g @openai/codex
bun install -g @mariozechner/pi-coding-agent
bun install -g playwright
bunx playwright install --with-deps
bun install -g @playwright/mcp

success "Global packages installed!"
