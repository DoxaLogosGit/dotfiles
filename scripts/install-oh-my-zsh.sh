#!/bin/bash
#
# Install oh-my-zsh plus the external plugins zshrc expects (idempotent, no chsh).
# Sourced by the per-platform package scripts.
#
# A plain git clone is used instead of the official installer script because
# that installer overwrites ~/.zshrc and runs chsh by default; cloning
# sidesteps both, matching how TPM is installed elsewhere in these scripts.

type info >/dev/null 2>&1    || info()    { echo -e "[INFO] $1"; }
type success >/dev/null 2>&1 || success() { echo -e "[OK] $1"; }

# Clone or update a repo. $1 = url, $2 = destination
_clone_or_pull() {
    if [ -d "$2" ]; then
        git -C "$2" pull --ff-only
    else
        git clone --depth=1 "$1" "$2"
    fi
}

install_oh_my_zsh() {
    local ohmyzsh_dir="$HOME/.oh-my-zsh"
    local custom_dir="${ZSH_CUSTOM:-$ohmyzsh_dir/custom}"

    if [ -d "$ohmyzsh_dir" ]; then
        info "oh-my-zsh already installed, updating..."
        git -C "$ohmyzsh_dir" pull --ff-only
    else
        info "Installing oh-my-zsh..."
        git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$ohmyzsh_dir"
        success "oh-my-zsh installed!"
    fi

    # zsh-autosuggestions and zsh-syntax-highlighting are not bundled with
    # oh-my-zsh; zshrc lists them in plugins=() so they must exist on disk.
    info "Installing oh-my-zsh custom plugins..."
    mkdir -p "$custom_dir/plugins"
    _clone_or_pull https://github.com/zsh-users/zsh-autosuggestions \
        "$custom_dir/plugins/zsh-autosuggestions"
    _clone_or_pull https://github.com/zsh-users/zsh-syntax-highlighting \
        "$custom_dir/plugins/zsh-syntax-highlighting"
    success "oh-my-zsh plugins installed!"
}
