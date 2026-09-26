#!/bin/bash
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

# install.sh and scripts/*.sh run under /bin/bash, which on macOS is 3.2:
# Apple froze it there over GPLv3 and never shipped 4.x. A bash-4 feature
# therefore fails on the MacBook and nowhere else - the worst place for it,
# since macOS cannot be exercised from the Linux box. This is a static guard
# for what we cannot run.

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
SELF="$(basename "$0")"

# Scan install.sh, every script, and every test EXCEPT this one - this file
# necessarily contains the patterns it searches for.
scan_files() {
    echo "$REPO/install.sh"
    ls "$REPO"/scripts/*.sh 2>/dev/null
    for t in "$HERE"/*.sh; do
        [ "$(basename "$t")" = "$SELF" ] && continue
        echo "$t"
    done
}

# Report lines matching <pattern>, with comments stripped so prose about a
# construct does not count as a use of it.
check_absent() {
    local label="$1" pattern="$2" hits="" f line n
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        n=0
        while IFS= read -r line; do
            n=$((n + 1))
            line="${line%%#*}"
            [ -z "$line" ] && continue
            case "$line" in
                *"check_absent"*) continue ;;
            esac
            if printf '%s' "$line" | grep -qE "$pattern"; then
                hits="$hits $(basename "$f"):$n"
            fi
        done < "$f"
    done <<EOF
$(scan_files)
EOF
    assert_eq "" "$hits" "$label"
}

check_absent "no associative arrays (declare -A) - bash 4.0+"       'declare[[:space:]]+-A|local[[:space:]]+-A'
check_absent "no mapfile/readarray - bash 4.0+"                     'mapfile|readarray'
check_absent "no case-conversion expansions - bash 4.0+"            '\$\{[A-Za-z_][A-Za-z_0-9]*(\^\^|,,)'
check_absent "no 'local -n' nameref - bash 4.3+"                    'local[[:space:]]+-n[[:space:]]'
check_absent "no '&>>' append-both redirect - bash 4.0+"            '&>>'
check_absent "no ';;&' case fallthrough - bash 4.0+"                ';;&'

# Every script that runs standalone must declare bash, not sh.
bad_shebang=""
for f in "$REPO/install.sh" "$REPO"/scripts/*.sh; do
    head -1 "$f" | grep -q '^#!/bin/bash' || bad_shebang="$bad_shebang $(basename "$f")"
done
assert_eq "" "$bad_shebang" "every script declares #!/bin/bash"

finish_tests
