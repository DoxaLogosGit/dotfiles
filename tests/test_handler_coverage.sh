#!/bin/bash
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

# Every fn: cell in a column must have a handler defined in that OS's package
# script. Without this check the failure is silent until someone runs the
# installer on that OS: pkg_run_table warns and moves on, so the tool simply
# never installs. Fedora shipped for a while requiring node_nvm without
# defining it, and nothing caught it.

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
TABLE="$REPO/scripts/tools.tsv"

# Every package script is table-driven. If one is ever added that is not,
# list it here and the check below asserts it stays that way rather than
# silently half-converting.
UNCONVERTED=""

col_for() {
    case "$1" in
        fedora) echo 2 ;; debian) echo 3 ;; raspbian) echo 4 ;; macos) echo 5 ;;
    esac
}

for os in fedora debian raspbian macos; do
    script="$REPO/scripts/packages-$os.sh"
    col="$(col_for "$os")"

    required="$(cut -f"$col" "$TABLE" | grep '^fn:' | sed 's/fn://' | sort -u)"
    defined="$(grep -oE '^[a-z_]+\(\)' "$script" | tr -d '()' | sort -u)"

    case " $UNCONVERTED " in
        *" $os "*)
            # Assert the state we expect, so this test fails loudly if someone
            # half-converts it rather than silently passing.
            if grep -q 'pkg_run_table' "$script"; then
                _fail "$os is either converted or listed as unconverted" \
                      "packages-$os.sh calls pkg_run_table but is still in UNCONVERTED"
            else
                _pass "$os is knowingly unconverted (its column is unused)"
            fi
            continue
            ;;
    esac

    missing=""
    for fn in $required; do
        echo "$defined" | grep -qx "$fn" || missing="$missing $fn"
    done
    assert_eq "" "$missing" "$os defines every fn: handler its column names"

    assert_ok "$os calls pkg_run_table" grep -q "pkg_run_table $os" "$script"
done

# The reverse direction: a handler defined but named by no cell is dead code.
# Helpers prefixed with _ and the shared log functions are exempt.
for os in fedora debian raspbian macos; do
    script="$REPO/scripts/packages-$os.sh"
    col="$(col_for "$os")"
    required="$(cut -f"$col" "$TABLE" | grep '^fn:' | sed 's/fn://' | sort -u)"
    defined="$(grep -oE '^[a-z_]+\(\)' "$script" | tr -d '()' | sort -u)"

    orphans=""
    for fn in $defined; do
        case "$fn" in
            info|success|warning|error|_*) continue ;;
            brew_install|brew_install_cask) continue ;;  # the brew method's implementation
        esac
        echo "$required" | grep -qx "$fn" || orphans="$orphans $fn"
    done
    assert_eq "" "$orphans" "$os defines no handler that nothing names"
done

# No handler may share its name with a command. A shell function shadows the
# binary of the same name for the whole script, and the scripts the handlers
# source call those binaries by bare name. The rust row's handler was once
# called rustup(): install_rust's `rustup update` then re-entered the handler,
# which updated and re-entered again, forever, on every machine that already
# had rustup. A fresh machine took the curl branch instead, so it never showed
# up there.
#
# Checked two ways. PATH alone is not enough: this test runs on machines that
# lack apt, rustup or bun, and a name missing here is still a command on the
# machine that runs the installer. So every tool a package script invokes, and
# every method in the table, is also listed by name.
KNOWN_COMMANDS="apt apt-get dnf brew rustup rustc cargo bun bunx node npm npx nvm
uv uvx pip pip3 python3 pi curl wget tar git sudo flatpak snap mise starship
atuin eza yazi glow tuios tuios-web herdr zellij nushell nu playwright opencode"
for method in $(cut -f2-5 "$TABLE" | tr '\t' '\n' | grep -v '^#' | cut -d: -f1 | sort -u); do
    KNOWN_COMMANDS="$KNOWN_COMMANDS $method"
done

for os in fedora debian raspbian macos; do
    script="$REPO/scripts/packages-$os.sh"
    defined="$(grep -oE '^[a-z_]+\(\)' "$script" | tr -d '()' | sort -u)"

    shadows=""
    for fn in $defined; do
        case "$fn" in info|success|warning|error) continue ;; esac
        case " $(echo $KNOWN_COMMANDS) " in
            *" $fn "*) shadows="$shadows $fn"; continue ;;
        esac
        if command -v "$fn" >/dev/null 2>&1 && [ -n "$(type -P "$fn" 2>/dev/null)" ]; then
            shadows="$shadows $fn"
        fi
    done
    assert_eq "" "$shadows" "$os defines no handler named after a command it would shadow"
done

finish_tests
