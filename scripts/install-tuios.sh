#!/bin/bash
#
# Install tuios, preferring the libghostty-vt build where upstream publishes
# one for this platform.
#
# tuios ships two terminal-emulator backends compiled in at build time: its own
# pure-Go emulator, and Ghostty's VT library via the official Go bindings
# (release artifacts named -ghostty). The choice is about emulation
# correctness, not speed — upstream runs a differential harness feeding
# identical bytes to both and asserting the screens, cursor, scrollback and
# modes agree — and it has nothing to do with which terminal you run tuios in.
#
# Both builds install under the same name, so `tuios --version` is the only
# thing that can say which one is present. This converges on the backend this
# platform should have rather than stopping at "some tuios exists".
#
# Bumping the version: set TUIOS_VERSION, or edit the default below and check
# the asset names at
# https://github.com/Gaurav-Gosain/tuios/releases

TUIOS_VERSION="${TUIOS_VERSION:-0.8.5}"
TUIOS_REPO="Gaurav-Gosain/tuios"

declare -f info >/dev/null 2>&1    || info()    { echo -e "[INFO] $1"; }
declare -f success >/dev/null 2>&1 || success() { echo -e "[OK] $1"; }
declare -f warning >/dev/null 2>&1 || warning() { echo -e "[WARN] $1" >&2; }

# Echo the release asset's OS word, or nothing when unsupported.
_tuios_os() {
    case "$(uname -s)" in
        Linux)  echo Linux ;;
        Darwin) echo Darwin ;;
        *)      return 1 ;;
    esac
}

# Echo the release asset's arch word, or nothing when unsupported.
_tuios_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo x86_64 ;;
        aarch64|arm64) echo arm64 ;;
        armv7l)        echo armv7 ;;
        armv6l)        echo armv6 ;;
        *)             return 1 ;;
    esac
}

# Echo "ghostty" when this platform has a libghostty-vt build, else "pure".
# Upstream publishes -ghostty only for x86_64 and arm64, so 32-bit ARM — a
# Pi 2 or 3 on 32-bit Raspbian — stays on the pure-Go emulator.
_tuios_variant() {
    case "$(_tuios_arch)" in
        x86_64|arm64) echo ghostty ;;
        *)            echo pure ;;
    esac
}

# Echo the backend of the tuios already on PATH: "ghostty", "pure", or nothing.
_tuios_installed_variant() {
    command -v tuios >/dev/null 2>&1 || return 1
    local v
    v="$(tuios --version 2>/dev/null | head -1)"
    case "$v" in
        *[Gg]hostty*) echo ghostty ;;
        *) echo pure ;;
    esac
}

install_tuios() {
    local os arch want have asset url tmp dest
    os="$(_tuios_os)" || { warning "tuios: unsupported OS $(uname -s)"; return 1; }
    arch="$(_tuios_arch)" || { warning "tuios: unsupported arch $(uname -m)"; return 1; }
    want="$(_tuios_variant)"
    have="$(_tuios_installed_variant || true)"

    if [ -n "$have" ] && [ "$have" = "$want" ]; then
        info "tuios already installed, $have backend ($(tuios --version 2>/dev/null | head -1))"
        return 0
    fi

    if [ "$want" = ghostty ]; then
        asset="tuios-ghostty_${TUIOS_VERSION}_${os}_${arch}.tar.gz"
    else
        asset="tuios_${TUIOS_VERSION}_${os}_${arch}.tar.gz"
    fi
    url="https://github.com/$TUIOS_REPO/releases/download/v${TUIOS_VERSION}/${asset}"

    if [ -n "$have" ]; then
        info "Replacing the tuios $have backend with $want..."
    else
        info "Installing tuios $TUIOS_VERSION ($want backend)..."
    fi

    tmp="$(mktemp -d)" || return 1
    if ! curl -fsSL "$url" -o "$tmp/tuios.tar.gz"; then
        warning "tuios: could not download $asset"
        rm -rf "$tmp"
        return 1
    fi
    if ! tar -xzf "$tmp/tuios.tar.gz" -C "$tmp"; then
        warning "tuios: could not unpack $asset"
        rm -rf "$tmp"
        return 1
    fi
    if [ ! -f "$tmp/tuios" ]; then
        warning "tuios: no tuios binary inside $asset"
        rm -rf "$tmp"
        return 1
    fi

    # Mirror the upstream installer's choice of destination.
    if [ -w /usr/local/bin ]; then
        dest=/usr/local/bin
    else
        dest="$HOME/.local/bin"
        mkdir -p "$dest"
    fi

    if ! mv "$tmp/tuios" "$dest/tuios"; then
        warning "tuios: could not install into $dest"
        rm -rf "$tmp"
        return 1
    fi
    chmod +x "$dest/tuios"
    rm -rf "$tmp"

    success "tuios installed to $dest ($("$dest/tuios" --version 2>/dev/null | head -1))"

    # Replacing the binary is not enough on its own: a running daemon keeps
    # serving the build it started from, so a successful install can look like
    # it did nothing.
    # -x, matching the process name exactly: `pgrep -f tuios` also matches any
    # command line that merely mentions tuios, including the installer's own.
    if [ -n "$have" ] && pgrep -x tuios >/dev/null 2>&1; then
        warning "A tuios daemon is running and still serving the previous build."
        warning "Run 'tuios kill-server' to pick this one up; sessions' layouts are saved."
    fi
}

# tuios-web is a separate binary from the same releases: it serves the session
# to a browser. There is one build per platform — no ghostty flavour — and it
# covers armv6 and armv7, so a Pi can serve it too.
#
# Note what it is before putting it anywhere reachable: every browser that
# opens it gets a shell on this machine, and the session switcher reaches every
# session. It refuses a non-loopback host without a password for that reason.
install_tuios_web() {
    local os arch asset url tmp dest
    os="$(_tuios_os)" || { warning "tuios-web: unsupported OS $(uname -s)"; return 1; }
    arch="$(_tuios_arch)" || { warning "tuios-web: unsupported arch $(uname -m)"; return 1; }

    if command -v tuios-web >/dev/null 2>&1; then
        info "tuios-web already installed ($(tuios-web --version 2>/dev/null | head -1))"
        return 0
    fi

    asset="tuios-web_${TUIOS_VERSION}_${os}_${arch}.tar.gz"
    url="https://github.com/$TUIOS_REPO/releases/download/v${TUIOS_VERSION}/${asset}"

    info "Installing tuios-web $TUIOS_VERSION..."
    tmp="$(mktemp -d)" || return 1
    if ! curl -fsSL "$url" -o "$tmp/web.tar.gz"; then
        warning "tuios-web: could not download $asset"
        rm -rf "$tmp"; return 1
    fi
    if ! tar -xzf "$tmp/web.tar.gz" -C "$tmp"; then
        warning "tuios-web: could not unpack $asset"
        rm -rf "$tmp"; return 1
    fi
    if [ ! -f "$tmp/tuios-web" ]; then
        warning "tuios-web: no tuios-web binary inside $asset"
        rm -rf "$tmp"; return 1
    fi

    if [ -w /usr/local/bin ]; then
        dest=/usr/local/bin
    else
        dest="$HOME/.local/bin"
        mkdir -p "$dest"
    fi

    if ! mv "$tmp/tuios-web" "$dest/tuios-web"; then
        warning "tuios-web: could not install into $dest"
        rm -rf "$tmp"; return 1
    fi
    chmod +x "$dest/tuios-web"
    rm -rf "$tmp"
    success "tuios-web installed to $dest"
}
