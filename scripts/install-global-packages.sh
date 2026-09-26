#!/bin/bash
#
# Global packages that belong to no single tool row, plus the pi package
# phase. Sourced by packages-debian.sh, packages-fedora.sh and
# packages-macos.sh, after pkg_run_table has installed the table's tools.
#

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# The manifest decides which agents this machine installs. This file is sourced
# by the package scripts, so load the manifest here if the caller has not: a
# missing `want` would abort the run under set -e.
if ! declare -f want >/dev/null 2>&1; then
    _igp_dir="$(dirname "${BASH_SOURCE[0]}")"
    # shellcheck source=manifest.sh
    . "$_igp_dir/manifest.sh"
    manifest_load "${DOTFILES_OVERLAY:-$HOME/.dotfiles-local}/manifest.conf" \
                  "$_igp_dir/tools.tsv" || exit 1
fi

# Node, bun, rust and every coding agent are tool rows in scripts/tools.tsv and
# are installed by pkg_run_table before this file is sourced. What is left here
# is the one package that belongs to no single tool, plus the pi package phase.

# ── Playwright MCP server ─────────────────────────────────────────────────────
# Not a tool row: it is an add-on to whichever agent uses it, and has no config
# or binary of its own to gate.
if want playwright; then
    bun install -g @playwright/mcp
else
    info "Skipping the Playwright MCP server (manifest)."
fi

success "Global packages installed!"

# pi agent packages. The tracked package list lives in install-pi-packages.sh;
# ~/.pi/agent/settings.json is untracked machine state. Set DOTFILES_PERSONAL=1
# to also install free-tier routing (personal machines only).
if want pi-packages && command -v pi &>/dev/null; then
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
