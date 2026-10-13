#!/bin/bash
#
# Install the Rust toolchain via rustup (idempotent).
# Sourced by packages-*.sh and install-global-packages.sh.
#
# We deliberately do NOT install the distro rust/cargo package (dnf rust,
# apt rustc/cargo): it tends to conflict with rustup and lags behind, while
# some crates require a newer compiler than the distro ships. rustup owns the
# toolchain instead, and every `cargo install` in the package scripts must run
# AFTER this so the crates build with rustup's toolchain.
#
# Note: install the OpenSSL headers, pkg-config, and perl (Fedora: perl-core)
# BEFORE calling this. Several crates' build scripts (e.g. openssl-sys) need
# them to compile.

# Fallbacks in case this is sourced without the caller's helpers.
declare -f info >/dev/null 2>&1    || info()    { echo -e "[INFO] $1"; }
declare -f success >/dev/null 2>&1 || success() { echo -e "[OK] $1"; }

install_rust() {
    # `command rustup` runs the rustup binary even if a shell function of the
    # same name exists. A package script once named its handler rustup(), and
    # every bare `rustup` below then called the handler again, forever.
    if command -v rustup >/dev/null 2>&1 || [ -x "$HOME/.cargo/bin/rustup" ]; then
        info "rustup already installed, updating toolchain..."
        if [ -x "$HOME/.cargo/bin/rustup" ]; then
            "$HOME/.cargo/bin/rustup" update || true
        else
            command rustup update || true
        fi
    else
        info "Installing Rust via rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    fi

    # Make cargo/rustc available in the current shell for subsequent installs.
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
    export PATH="$HOME/.cargo/bin:$PATH"

    # rust-analyzer via rustup stays version-matched to the active toolchain
    # (nvim's rustaceanvim config relies on this rather than a Mason install).
    command rustup component add rust-analyzer clippy rustfmt

    success "Rust toolchain ready ($(rustc --version 2>/dev/null || echo 'rustc not on PATH'))"
}
