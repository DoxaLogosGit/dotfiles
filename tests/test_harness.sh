#!/bin/bash
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

assert_eq "a" "a" "assert_eq matches equal strings"
assert_contains "hello world" "lo wo" "assert_contains finds a substring"
assert_ok "assert_ok accepts true" true
assert_fail "assert_fail accepts false" false

sandbox="$(make_sandbox)"
assert_ok "make_sandbox creates home/" test -d "$sandbox/home"
assert_ok "make_sandbox creates repo/" test -d "$sandbox/repo"
assert_ok "make_sandbox creates overlay/" test -d "$sandbox/overlay"
cleanup_sandbox "$sandbox"
assert_fail "cleanup_sandbox removes the dir" test -d "$sandbox"

finish_tests
