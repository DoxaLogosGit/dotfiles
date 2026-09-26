#!/bin/bash
# Assertions and sandbox helpers for tests/test_*.sh.
# Bash 3.2 compatible: no associative arrays, no mapfile.

TESTS_RUN=0
TESTS_FAILED=0

_pass() { TESTS_RUN=$((TESTS_RUN + 1)); echo "  ok   - $1"; }
_fail() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL - $1"
    [ -n "${2:-}" ] && echo "         $2"
    return 0
}

assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [ "$expected" = "$actual" ]; then
        _pass "$label"
    else
        _fail "$label" "expected [$expected] got [$actual]"
    fi
}

assert_contains() {
    local haystack="$1" needle="$2" label="$3"
    case "$haystack" in
        *"$needle"*) _pass "$label" ;;
        *) _fail "$label" "[$needle] not found in [$haystack]" ;;
    esac
}

assert_ok() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then _pass "$label"; else _fail "$label" "command failed: $*"; fi
}

assert_fail() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then _fail "$label" "command unexpectedly succeeded: $*"; else _pass "$label"; fi
}

make_sandbox() {
    local dir
    dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test.XXXXXX")"
    mkdir -p "$dir/home" "$dir/repo" "$dir/overlay"
    printf '%s' "$dir"
}

cleanup_sandbox() {
    [ -n "${1:-}" ] && [ -d "$1" ] && rm -rf "$1"
    return 0
}

finish_tests() {
    echo "  $TESTS_RUN run, $TESTS_FAILED failed"
    [ "$TESTS_FAILED" -eq 0 ]
}
