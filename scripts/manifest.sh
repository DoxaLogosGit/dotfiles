#!/bin/bash
#
# Per-machine install manifest: parsing, validation and the want/want_config
# predicates that gate every install action.
#
# Sourced by install.sh and by scripts/packages-*.sh. Bash 3.2 compatible:
# state lives in newline-delimited strings, not associative arrays, because
# stock macOS bash has none and install.sh runs under /bin/bash there.
#
# Format (see manifest.example, generated from scripts/tools.tsv):
#
#     zellij = no          # skip the package and the config
#     nvim   = config-only # link the config; installed some other way
#     tmux   = yes         # install and link
#
# A machine with no manifest installs everything, exactly as before manifests
# existed. A tool left out of a manifest that DOES exist is skipped, and named
# in the run summary so the omission is visible.

MANIFEST_ACTIVE=false
MANIFEST_DATA=""
MANIFEST_TABLE=""
MANIFEST_FILE=""

# Fallbacks so this file works when sourced without install.sh's helpers.
declare -f warning >/dev/null 2>&1 || warning() { echo "[WARN] $1" >&2; }
type error   >/dev/null 2>&1 || error()   { echo "[ERROR] $1" >&2; }

# Echo the cell for <tool> in <os>, or nothing when the tool is unknown.
# Usage: tool_cell zellij macos
tool_cell() {
    local tool="$1" os="$2" col
    case "$os" in
        fedora)   col=2 ;;
        debian)   col=3 ;;
        raspbian) col=4 ;;
        macos)    col=5 ;;
        *) return 1 ;;
    esac
    grep "^$tool	" "$MANIFEST_TABLE" 2>/dev/null | head -1 | cut -f"$col"
}

# True when <tool> has a row in the table.
_tool_known() {
    grep -q "^$1	" "$MANIFEST_TABLE" 2>/dev/null
}

# manifest_load <manifest_path> <table_path>
# An absent manifest is not an error: it means "install everything".
manifest_load() {
    MANIFEST_FILE="$1"
    MANIFEST_TABLE="$2"
    MANIFEST_DATA=""
    MANIFEST_ACTIVE=false

    if [ ! -f "$MANIFEST_TABLE" ]; then
        error "tool table not found: $MANIFEST_TABLE"
        return 1
    fi

    if [ ! -f "$MANIFEST_FILE" ]; then
        return 0
    fi

    local lineno=0 problems=0 line key value
    while IFS= read -r line || [ -n "$line" ]; do
        lineno=$((lineno + 1))

        # Strip comments and surrounding whitespace.
        line="${line%%#*}"
        line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        [ -z "$line" ] && continue

        case "$line" in
            *=*) ;;
            *)
                error "$(basename "$MANIFEST_FILE"):$lineno: expected 'tool = value', got '$line'"
                problems=$((problems + 1))
                continue
                ;;
        esac

        key="${line%%=*}"
        value="${line#*=}"
        key="$(printf '%s' "$key" | sed 's/[[:space:]]*$//')"
        value="$(printf '%s' "$value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

        if ! _tool_known "$key"; then
            error "$(basename "$MANIFEST_FILE"):$lineno: '$key' is not a known tool (see scripts/tools.tsv)"
            problems=$((problems + 1))
            continue
        fi

        case "$value" in
            yes|no|config-only) ;;
            *)
                error "$(basename "$MANIFEST_FILE"):$lineno: '$value' is not a valid value for '$key' (use yes, no or config-only)"
                problems=$((problems + 1))
                continue
                ;;
        esac

        MANIFEST_DATA="$MANIFEST_DATA$key=$value
"
    done < "$MANIFEST_FILE"

    if [ "$problems" -gt 0 ]; then
        error "$problems problem(s) in $MANIFEST_FILE — nothing was installed"
        MANIFEST_DATA=""
        return 1
    fi

    MANIFEST_ACTIVE=true
    return 0
}

# Echo the value recorded for <tool>, or nothing.
manifest_value() {
    printf '%s' "$MANIFEST_DATA" | grep "^$1=" | head -1 | cut -d= -f2
}

# want <tool> — should this tool be installed?
want() {
    [ "$MANIFEST_ACTIVE" = true ] || return 0
    [ "$(manifest_value "$1")" = "yes" ]
}

# want_config <tool> — should this tool's config be linked?
want_config() {
    [ "$MANIFEST_ACTIVE" = true ] || return 0
    case "$(manifest_value "$1")" in
        yes|config-only) return 0 ;;
        *) return 1 ;;
    esac
}

# One line for the end of a run, so skips are always visible.
manifest_summary() {
    if [ "$MANIFEST_ACTIVE" != true ]; then
        echo "Manifest: none (installing everything)"
        return 0
    fi
    local yes_n no_n cfg_n skipped
    # `grep -c` exits 1 on a zero count, which under `set -e` would abort the
    # installer just as it reports its results. Every count needs `|| true`.
    yes_n=$(printf '%s' "$MANIFEST_DATA" | grep -c '=yes$' || true)
    no_n=$(printf '%s' "$MANIFEST_DATA" | grep -c '=no$' || true)
    cfg_n=$(printf '%s' "$MANIFEST_DATA" | grep -c '=config-only$' || true)
    skipped=$(printf '%s' "$MANIFEST_DATA" | grep '=no$' | cut -d= -f1 | tr '\n' ' ' || true)
    echo "Manifest: $MANIFEST_FILE ($yes_n yes, $no_n no, $cfg_n config-only)"
    [ -n "$skipped" ] && echo "  skipped: ${skipped% }"

    # Opt-in means a tool the manifest never mentions is skipped too. Saying so
    # is the whole safeguard: without it, adding a row to the table silently
    # withholds that tool from every existing machine.
    local omitted="" omitted_n=0 line tool
    while IFS= read -r line; do
        case "$line" in ''|\#*) continue ;; esac
        tool=$(printf '%s' "$line" | cut -f1)
        if [ -z "$(manifest_value "$tool")" ]; then
            omitted_n=$((omitted_n + 1))
            [ "$omitted_n" -le 12 ] && omitted="$omitted $tool"
        fi
    done < "$MANIFEST_TABLE"

    if [ "$omitted_n" -gt 0 ]; then
        if [ "$omitted_n" -gt 12 ]; then
            echo "  not listed, so also skipped:$omitted ... and $((omitted_n - 12)) more"
        else
            echo "  not listed, so also skipped:$omitted"
        fi
    fi
    return 0
}
