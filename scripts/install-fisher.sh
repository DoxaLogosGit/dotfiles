#!/bin/bash
#
# Install Fisher plugin manager for Fish shell and plugins from fish_plugins.
# Sourced by package install scripts.
#

install_fisher() {
    if ! command -v fish &>/dev/null; then
        warning "Fish shell not found. Fisher will need to be installed manually after fish is available."
        return
    fi
    info "Installing Fisher plugin manager..."
    fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"
    info "Installing Fish plugins from fish_plugins..."
    fish -c "fisher update"
    success "Fisher and plugins installed!"
}
