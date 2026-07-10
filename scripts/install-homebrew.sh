#!/bin/bash
#
# Detect the Homebrew prefix for the current architecture and bootstrap
# Homebrew if it is not already installed. Sourced by packages-macos.sh
# (and install.sh's macOS package dispatch).
#
# Apple Silicon (arm64) installs Homebrew at /opt/homebrew; Intel (x86_64)
# at /usr/local. We do NOT hardcode either — the same dotfiles run on both.

# Fallbacks in case this is sourced without the caller's helpers.
type info >/dev/null 2>&1    || info()    { echo -e "[INFO] $1"; }
type success >/dev/null 2>&1 || success() { echo -e "[OK] $1"; }
type warning >/dev/null 2>&1 || warning() { echo -e "[WARN] $1"; }

set_homebrew_prefix() {
    if [ "$(uname -m)" = "arm64" ]; then
        HOMEBREW_PREFIX="/opt/homebrew"
    else
        HOMEBREW_PREFIX="/usr/local"
    fi
    export HOMEBREW_PREFIX
}

install_homebrew() {
    set_homebrew_prefix

    if [ -x "$HOMEBREW_PREFIX/bin/brew" ] || command -v brew >/dev/null 2>&1; then
        info "Homebrew already installed."
    else
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # Put brew (and everything it installs) on PATH for the rest of the run.
    eval "$("$HOMEBREW_PREFIX/bin/brew" shellenv)"
    success "Homebrew ready ($("$HOMEBREW_PREFIX/bin/brew" --version | head -1))"
}
