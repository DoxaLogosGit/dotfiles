#!/bin/bash
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

HERE="$(cd "$(dirname "$0")" && pwd)"
GEN="$HERE/../scripts/gen-manifest-example.sh"
TABLE="$HERE/../scripts/tools.tsv"

assert_ok "generator exists and is executable" test -x "$GEN"

sandbox="$(make_sandbox)"
out="$sandbox/manifest.example"
assert_ok "generator runs" bash "$GEN" "$TABLE" "$out"

# Every tool in the table appears exactly once as a 'tool = yes' line.
missing=""
while IFS= read -r line; do
    case "$line" in ''|\#*) continue ;; esac
    tool=$(printf '%s' "$line" | cut -f1)
    grep -qE "^${tool}[[:space:]]*=[[:space:]]*yes" "$out" || missing="$missing $tool"
done < "$TABLE"
assert_eq "" "$missing" "every table tool appears as 'yes' in the example"

# And nothing extra: same count of assignment lines as table rows.
rows=$(grep -cvE '^[[:space:]]*(#|$)' "$TABLE")
assigns=$(grep -cE '^[a-z0-9-]+[[:space:]]*=' "$out")
assert_eq "$rows" "$assigns" "example has one line per table row, no extras"

# The generated file must pass the parser it is meant to seed.
# shellcheck source=../scripts/manifest.sh
. "$HERE/../scripts/manifest.sh"
assert_ok "generated example validates against the table" manifest_load "$out" "$TABLE"

# An all-yes example must leave nothing skipped.
manifest_load "$out" "$TABLE" >/dev/null 2>&1
summary="$(manifest_summary)"
assert_contains "$summary" "0 no" "the generated example skips nothing"

# The committed manifest.example must be in sync with the table, or the
# starter file people copy has silently fallen behind.
committed="$HERE/../manifest.example"
assert_ok "manifest.example is committed" test -f "$committed"
bash "$GEN" "$TABLE" "$sandbox/fresh.example" >/dev/null 2>&1
if diff -q "$committed" "$sandbox/fresh.example" >/dev/null 2>&1; then
    _pass "committed manifest.example matches a fresh generation"
else
    _fail "committed manifest.example matches a fresh generation" \
          "run scripts/gen-manifest-example.sh and commit the result"
fi

cleanup_sandbox "$sandbox"
finish_tests
