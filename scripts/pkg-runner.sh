#!/bin/bash
#
# Table-driven package installation. Walks scripts/tools.tsv in row order for
# one OS and installs every tool the machine's manifest wants.
#
# Sourced by scripts/packages-*.sh after they source manifest.sh. Each OS
# script defines the fn: handlers its own cells name, so an irregular install
# (a versioned URL, an arch check, a piped upstream installer) stays readable
# shell in the script for that OS while the common cases stay one-line data.
#
# Bash 3.2 compatible: no associative arrays.

PKG_DRY_RUN="${PKG_DRY_RUN:-false}"

declare -f info >/dev/null 2>&1    || info()    { echo "[INFO] $1"; }
declare -f warning >/dev/null 2>&1 || warning() { echo "[WARN] $1" >&2; }

# Run a command, or print it under PKG_DRY_RUN.
_pkg_do() {
    if [ "$PKG_DRY_RUN" = true ]; then
        echo "[DRY-RUN] $*"
        return 0
    fi
    "$@"
}

# pip install that copes with the differences between distros: pip vs pip3,
# and the PEP 668 "externally managed environment" refusal that Debian-based
# systems return for a system-wide install.
_pkg_pip_install() {
    local pip_bin=""
    for candidate in pip3 pip; do
        if command -v "$candidate" >/dev/null 2>&1; then
            pip_bin="$candidate"
            break
        fi
    done
    if [ -z "$pip_bin" ]; then
        warning "no pip or pip3 on PATH — skipping: $*"
        return 1
    fi

    "$pip_bin" install "$@" 2>/dev/null ||
        "$pip_bin" install --break-system-packages "$@" ||
        return 1
}

# uv tool install, one package per call: `uv tool install a b` is a usage
# error. Each gets its own isolated environment with a shim in ~/.local/bin,
# which is why these no longer need sudo or --break-system-packages.
_pkg_uv_tool_install() {
    local pkg rc=0
    if ! command -v uv >/dev/null 2>&1; then
        # uv installs to ~/.local/bin, which may not be on PATH yet in the
        # same shell that just installed it.
        if [ -x "$HOME/.local/bin/uv" ]; then
            PATH="$HOME/.local/bin:$PATH"
            export PATH
        else
            warning "uv is not installed — skipping: $*"
            return 1
        fi
    fi
    for pkg in "$@"; do
        # --force: uv refuses to overwrite an executable it does not own, and
        # on any machine upgraded from the old `pip install` lines that is
        # exactly what it finds. The installer has to converge, not stop at a
        # shim left by its predecessor.
        uv tool install --force "$pkg" || rc=1
    done
    return "$rc"
}

# pkg_install_one <tool> <cell>
# Cell is method:name; a comma-separated name means several packages.
pkg_install_one() {
    local tool="$1" cell="$2" method name oldifs
    method="${cell%%:*}"
    name="${cell#*:}"

    # Split the comma-separated name into positional parameters, so each branch
    # can pass "$@" without an unquoted expansion. tool and cell are already
    # captured, so overwriting the positional parameters here is safe.
    oldifs="$IFS"
    IFS=','
    # shellcheck disable=SC2086  # splitting on commas is the intent
    set -- $name
    IFS="$oldifs"

    case "$method" in
        dnf)   _pkg_do sudo dnf install -y "$@" ;;
        apt)   _pkg_do sudo apt-get install -yy "$@" ;;
        brew)  _pkg_do brew_install "$@" ;;
        cargo) _pkg_do cargo install "$@" ;;
        bun)   _pkg_do bun install -g "$@" ;;
        npm)   _pkg_do npm install -g "$@" ;;
        pip)   _pkg_do _pkg_pip_install "$@" ;;
        uv)    _pkg_do _pkg_uv_tool_install "$@" ;;
        fn)
            if declare -f "$1" >/dev/null 2>&1; then
                _pkg_do "$1"
            else
                warning "$tool: handler '$1' is not defined in this OS's package script"
                return 1
            fi
            ;;
        *)
            warning "$tool: unknown install method '$method'"
            return 1
            ;;
    esac
}

# pkg_run_table <os>
# Walks the table in row order — which is install order, so rust and bun come
# before the tools that need them.
pkg_run_table() {
    local os="$1" line tool cell col

    case "$os" in
        fedora)   col=2 ;;
        debian)   col=3 ;;
        raspbian) col=4 ;;
        macos)    col=5 ;;
        *) warning "pkg_run_table: unknown OS '$os'"; return 1 ;;
    esac

    if [ ! -f "${MANIFEST_TABLE:-}" ]; then
        warning "pkg_run_table: no tool table loaded (call manifest_load first)"
        return 1
    fi

    while IFS= read -r line; do
        case "$line" in ''|\#*) continue ;; esac

        tool=$(printf '%s' "$line" | cut -f1)
        cell=$(printf '%s' "$line" | cut -f"$col")

        # Not available on this OS — nothing for the manifest to decide.
        [ "$cell" = "-" ] && continue

        if ! want "$tool"; then
            info "Skipping $tool (manifest)."
            continue
        fi

        info "Installing $tool ($cell)..."
        pkg_install_one "$tool" "$cell" || warning "$tool install failed"
    done < "$MANIFEST_TABLE"
}
