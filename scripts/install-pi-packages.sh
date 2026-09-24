#!/bin/bash
#
# Install pi agent packages. Sourced by packages-*.sh, or run directly.
#
# This file is the tracked record of which pi packages belong on a machine.
# ~/.pi/agent/settings.json is deliberately NOT tracked: it mixes this package
# list with per-machine provider/model choices and a lastChangelogVersion that
# pi rewrites on every update. The list lives here instead; pi owns the rest.
#
# Usage:
#   install_pi_packages              # shared set only (work machines)
#   install_pi_packages --personal   # shared set + free-tier routing

# Fallbacks in case this is sourced without the caller's helpers.
type info >/dev/null 2>&1    || info()    { echo -e "[INFO] $1"; }
type warning >/dev/null 2>&1 || warning() { echo -e "[WARN] $1"; }
type success >/dev/null 2>&1 || success() { echo -e "[OK] $1"; }

# Wanted everywhere.
PI_PACKAGES_SHARED=(
    pi-subagents
    "@juicesharp/rpiv-todo"
    pi-lens
    "@narumitw/pi-btw"
    pi-open-tui
    pi-web-access-lean
    pi-markdown-preview
    pi-hermes-memory
)

# Personal machines only. Work and contractor machines use their own models,
# so free-tier routing is not wanted there.
PI_PACKAGES_PERSONAL=(
    pi-free
)

install_pi_packages() {
    local pkg
    local -a packages=("${PI_PACKAGES_SHARED[@]}")

    if [ "${1:-}" = "--personal" ]; then
        packages+=("${PI_PACKAGES_PERSONAL[@]}")
    fi

    if ! command -v pi &>/dev/null; then
        warning "pi not found — skipping pi packages (run again after installing pi)"
        return
    fi

    info "Installing pi packages (${#packages[@]})..."
    for pkg in "${packages[@]}"; do
        pi install "npm:$pkg" || warning "pi package $pkg failed to install"
    done
    success "pi packages installed!"

    # settings.json and models.json are untracked, so a fresh machine starts on
    # pi's defaults with no custom providers.
    if [ ! -s "$HOME/.pi/agent/settings.json" ]; then
        info "No ~/.pi/agent/settings.json yet — set your provider and model in pi (/model)."
    fi
    if [ ! -s "$HOME/.pi/agent/models.json" ]; then
        info "No ~/.pi/agent/models.json yet — copy pi/models.json.example and add local providers."
    fi
}

# Allow running this file directly, not just sourcing it.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    install_pi_packages "$@"
fi
