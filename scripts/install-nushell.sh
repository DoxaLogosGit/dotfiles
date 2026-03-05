#!/bin/bash
#
# Install nushell from GitHub releases.
# Sourced by package install scripts when the package manager doesn't have it.
#

install_nushell() {
    if command -v nu &>/dev/null; then
        info "nushell already installed: $(nu --version)"
        return
    fi
    info "Installing nushell from GitHub releases..."
    NU_VERSION=$(curl -s https://api.github.com/repos/nushell/nushell/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    if [ -z "$NU_VERSION" ]; then
        warning "Could not fetch nushell version, skipping"
        return
    fi
    NU_ARCHIVE="nu-${NU_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
    wget -q "https://github.com/nushell/nushell/releases/download/${NU_VERSION}/${NU_ARCHIVE}" -O /tmp/nushell.tar.gz
    tar -xzf /tmp/nushell.tar.gz -C /tmp
    sudo mv "/tmp/nu-${NU_VERSION}-x86_64-unknown-linux-gnu/nu" /usr/local/bin/nu
    rm -rf /tmp/nushell.tar.gz "/tmp/nu-${NU_VERSION}-x86_64-unknown-linux-gnu"
    if ! grep -qx "/usr/local/bin/nu" /etc/shells; then
        echo "/usr/local/bin/nu" | sudo tee -a /etc/shells > /dev/null
    fi
    success "nushell installed: $(nu --version)"
}
