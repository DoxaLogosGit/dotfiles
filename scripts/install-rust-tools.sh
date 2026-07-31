#!/bin/bash
#
# Install Rust TUI tools via cargo: tudiff (terminal diff), herdr (AI agent
# workspace manager), tuicr (code review TUI). Requires a cargo toolchain
# already on PATH (install-rust.sh) — sourced by packages-*.sh.
#

# Fallbacks in case this is sourced without the caller's helpers.
type info >/dev/null 2>&1    || info()    { echo -e "[INFO] $1"; }
type warning >/dev/null 2>&1 || warning() { echo -e "[WARN] $1"; }

install_rust_tools() {
    local tool
    info "Installing Rust TUI tools: tudiff, herdr, tuicr..."
    for tool in tudiff herdr tuicr; do
        cargo install "$tool" || warning "$tool install failed"
    done
}
