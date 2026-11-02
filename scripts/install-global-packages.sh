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

_global_do() {
    if [ "${PKG_DRY_RUN:-false}" = true ]; then
        echo "[DRY-RUN] $*"
        return 0
    fi
    "$@"
}

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
    if ! command -v bun >/dev/null 2>&1; then
        warning "bun is not installed — skipping the Playwright MCP server"
    elif [ "${PACKAGE_ACTION:-install}" = "update" ]; then
        _global_do bun update -g --latest @playwright/mcp
    else
        bun install -g @playwright/mcp
    fi
else
    info "Skipping the Playwright MCP server (manifest)."
fi

if [ "${PACKAGE_ACTION:-install}" = "update" ]; then
    success "Global packages updated!"
else
    success "Global packages installed!"
fi

# pi agent packages. The tracked package list lives in install-pi-packages.sh;
# ~/.pi/agent/settings.json is untracked machine state. Set DOTFILES_PERSONAL=1
# to also install free-tier routing (personal machines only).
if [ "${PACKAGE_ACTION:-install}" != "update" ]; then
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
fi

# pi owns extension update behavior and reads the extension list from its
# settings. This refreshes only packages that pi already manages.
if [ "${PACKAGE_ACTION:-install}" = "update" ]; then
    if want pi-packages && command -v pi &>/dev/null; then
        # shellcheck source=install-pi-packages.sh
        . "$(dirname "${BASH_SOURCE[0]}")/install-pi-packages.sh"
        pi_use_local_node_headers
        _global_do pi update || warning "pi package update failed"
    else
        info "pi not installed — skipping pi package update"
    fi

    if want claude-plugins && command -v claude &>/dev/null; then
        _global_do claude plugin update --all || warning "Claude plugin update failed"
    fi

    if want tmux; then
        tpm_dir="$HOME/.tmux/plugins/tpm"
        if [ -d "$tpm_dir" ]; then
            _global_do git -C "$tpm_dir" pull --ff-only ||
                warning "TPM update failed; keeping the current checkout"
        else
            info "TPM not installed — skipping update"
        fi
    fi

    if want oh-my-zsh; then
        if [ -d "$HOME/.oh-my-zsh" ]; then
            _global_do git -C "$HOME/.oh-my-zsh" pull --ff-only ||
                warning "oh-my-zsh update failed; keeping the current checkout"
            for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
                plugin_dir="$HOME/.oh-my-zsh/custom/plugins/$plugin"
                if [ -d "$plugin_dir" ]; then
                    _global_do git -C "$plugin_dir" pull --ff-only ||
                        warning "$plugin update failed; keeping the current checkout"
                fi
            done
        else
            info "oh-my-zsh not installed — skipping update"
        fi
    fi
fi
