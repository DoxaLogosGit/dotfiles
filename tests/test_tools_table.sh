#!/bin/bash
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

TABLE="$(dirname "$0")/../scripts/tools.tsv"

assert_ok "table exists" test -f "$TABLE"

# Every non-comment, non-blank row has exactly 5 tab-separated fields.
bad_width=""
while IFS= read -r line; do
    case "$line" in ''|\#*) continue ;; esac
    n=$(printf '%s' "$line" | awk -F'\t' '{print NF}')
    [ "$n" -eq 5 ] || bad_width="$bad_width $(printf '%s' "$line" | cut -f1)($n)"
done < "$TABLE"
assert_eq "" "$bad_width" "every row has 5 tab-separated fields"

# No duplicate tool names.
dupes="$(grep -vE '^[[:space:]]*(#|$)' "$TABLE" | cut -f1 | sort | uniq -d | tr '\n' ' ')"
assert_eq "" "${dupes% }" "no duplicate tool rows"

# Every cell is '-' or method:name — never empty.
bad_cell=""
while IFS= read -r line; do
    case "$line" in ''|\#*) continue ;; esac
    tool=$(printf '%s' "$line" | cut -f1)
    for col in 2 3 4 5; do
        cell=$(printf '%s' "$line" | cut -f"$col")
        case "$cell" in
            -|*:*) ;;
            *) bad_cell="$bad_cell $tool:col$col" ;;
        esac
    done
done < "$TABLE"
assert_eq "" "$bad_cell" "every cell is '-' or method:name"

# Only known install methods appear.
bad_method=""
while IFS= read -r line; do
    case "$line" in ''|\#*) continue ;; esac
    tool=$(printf '%s' "$line" | cut -f1)
    for col in 2 3 4 5; do
        cell=$(printf '%s' "$line" | cut -f"$col")
        [ "$cell" = "-" ] && continue
        case "${cell%%:*}" in
            dnf|apt|brew|cargo|bun|npm|fn) ;;
            *) bad_method="$bad_method $tool:${cell%%:*}" ;;
        esac
    done
done < "$TABLE"
assert_eq "" "$bad_method" "every method is one pkg_install_one handles"

# Bootstrappers precede their dependents: rust before any cargo:, bun before any bun:.
rust_line=$(grep -n '^rust	' "$TABLE" | cut -d: -f1)
bun_line=$(grep -n '^bun	' "$TABLE" | cut -d: -f1)
first_cargo=$(grep -n '	cargo:' "$TABLE" | head -1 | cut -d: -f1)
first_bun=$(grep -n '	bun:' "$TABLE" | head -1 | cut -d: -f1)
assert_ok "rust row precedes first cargo: cell" test "$rust_line" -lt "$first_cargo"
assert_ok "bun row precedes first bun: cell" test "$bun_line" -lt "$first_bun"

# Every tool that install.sh links a config for must have a row, or the
# manifest could never gate it.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
missing_rows=""
for tool in zsh bash git vim nvim tmux zellij starship atuin yazi htop btop \
            nushell python scripts ghostty claude vscode opencode pi herdr; do
    grep -q "^$tool	" "$TABLE" || missing_rows="$missing_rows $tool"
done
assert_eq "" "$missing_rows" "every config-linked tool has a table row"
assert_ok "repo path resolved for the check" test -d "$REPO"

finish_tests
