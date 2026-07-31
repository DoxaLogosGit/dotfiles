#!/bin/bash
#
# Install Rust TUI tools via cargo. Requires a cargo toolchain already on
# PATH (install-rust.sh) — sourced by packages-*.sh.
#
# Callers pass the tool list explicitly (e.g. `install_rust_tools tudiff
# tuicr`) since not every tool builds everywhere — herdr fails to compile
# on macOS, so packages-macos.sh installs it via `brew install herdr`
# instead of listing it here.

# Fallbacks in case this is sourced without the caller's helpers.
type info >/dev/null 2>&1    || info()    { echo -e "[INFO] $1"; }
type warning >/dev/null 2>&1 || warning() { echo -e "[WARN] $1"; }

install_rust_tools() {
    local tool
    info "Installing Rust TUI tools via cargo: $*..."
    for tool in "$@"; do
        cargo install "$tool" || warning "$tool install failed"
    done
}
