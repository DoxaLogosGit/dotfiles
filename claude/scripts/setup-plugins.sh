#!/bin/bash
#
# Claude Code Plugin Setup
# Run once after installing Claude Code on a new machine.
# Installs user-scoped plugins defined in settings.json extraKnownMarketplaces.
#

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

if ! command -v claude &>/dev/null; then
    warning "claude not found — skipping plugin setup"
    exit 0
fi

# ── Obsidian Skills ────────────────────────────────────────────────────────────
info "Installing obsidian plugin..."
claude plugin install obsidian@obsidian-skills --scope user 2>/dev/null || \
    info "obsidian plugin already installed"
success "Obsidian skills ready"

# ── Excalidraw Skills ──────────────────────────────────────────────────────────
info "Installing excalidraw plugin..."
claude plugin install excalidraw@excalidraw-skills --scope user 2>/dev/null || \
    info "excalidraw plugin already installed"

# Set up Python renderer dependencies
RENDER_DIR="$HOME/.claude/plugins/cache/excalidraw-skills/excalidraw/1.0.0/skills/excalidraw/references"
if [ -d "$RENDER_DIR" ] && command -v uv &>/dev/null; then
    info "Installing excalidraw renderer dependencies..."
    (cd "$RENDER_DIR" && uv sync && uv run playwright install chromium) || \
        warning "Renderer setup failed — run manually: cd $RENDER_DIR && uv sync && uv run playwright install chromium"
else
    warning "Skipping renderer setup (uv not found or plugin not installed yet)"
fi

success "Excalidraw skill ready"
