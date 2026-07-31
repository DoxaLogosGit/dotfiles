#!/bin/bash
#
# Install oh-my-zsh (idempotent, no chsh — macOS already defaults to zsh).
# Sourced by packages-macos.sh.
#
# A plain git clone is used instead of the official installer script because
# that installer overwrites ~/.zshrc and runs chsh by default; cloning
# sidesteps both, matching how TPM is installed elsewhere in these scripts.

type info >/dev/null 2>&1    || info()    { echo -e "[INFO] $1"; }
type success >/dev/null 2>&1 || success() { echo -e "[OK] $1"; }

install_oh_my_zsh() {
    local ohmyzsh_dir="$HOME/.oh-my-zsh"
    if [ -d "$ohmyzsh_dir" ]; then
        info "oh-my-zsh already installed, updating..."
        git -C "$ohmyzsh_dir" pull
    else
        info "Installing oh-my-zsh..."
        git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$ohmyzsh_dir"
        success "oh-my-zsh installed!"
    fi
}
