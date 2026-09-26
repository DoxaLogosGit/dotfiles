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

# packages-debian.sh has not been converted to the table yet — it still runs
# its own hardcoded package list and never calls pkg_run_table, so its column
# is unused. Remove it from this list when it is converted.
UNCONVERTED="debian"

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
for os in fedora raspbian macos; do
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

finish_tests
