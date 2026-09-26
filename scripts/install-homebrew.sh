#!/bin/bash
#
# Detect the Homebrew prefix for the current architecture and bootstrap
# Homebrew if it is not already installed. Sourced by packages-macos.sh
# (and install.sh's macOS package dispatch).
#
# Apple Silicon (arm64) installs Homebrew at /opt/homebrew; Intel (x86_64)
# at /usr/local. We do NOT hardcode either — the same dotfiles run on both.

# Fallbacks in case this is sourced without the caller's helpers.
declare -f info >/dev/null 2>&1    || info()    { echo -e "[INFO] $1"; }
declare -f success >/dev/null 2>&1 || success() { echo -e "[OK] $1"; }
declare -f warning >/dev/null 2>&1 || warning() { echo -e "[WARN] $1"; }

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

    # Use the brew that actually exists, not the one the prefix predicts. The
    # two can disagree — an Apple Silicon machine running the script under
    # Rosetta reports x86_64 and so guesses /usr/local — and the old code then
    # ran a nonexistent binary, printed "Homebrew ready ()" with an empty
    # version, and carried on with brew missing from PATH.
    local brew_bin=""
    if [ -x "$HOMEBREW_PREFIX/bin/brew" ]; then
        brew_bin="$HOMEBREW_PREFIX/bin/brew"
        info "Homebrew already installed."
    elif command -v brew >/dev/null 2>&1; then
        brew_bin="$(command -v brew)"
        info "Homebrew already installed ($brew_bin)."
    else
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        brew_bin="$HOMEBREW_PREFIX/bin/brew"
    fi

    if [ ! -x "$brew_bin" ]; then
        warning "Homebrew not found at $brew_bin — later brew steps will fail."
        return 1
    fi

    # Put brew (and everything it installs) on PATH for the rest of the run.
    eval "$("$brew_bin" shellenv)"
    success "Homebrew ready ($("$brew_bin" --version | head -1))"
}
