#!/bin/bash
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../scripts/manifest.sh
. "$HERE/../scripts/manifest.sh"
TABLE="$HERE/../scripts/tools.tsv"

sandbox="$(make_sandbox)"

# ── absent manifest: everything is wanted ───────────────────────────────
assert_ok "load succeeds with no manifest" manifest_load "$sandbox/nope.conf" "$TABLE"
manifest_load "$sandbox/nope.conf" "$TABLE"
assert_eq "false" "$MANIFEST_ACTIVE" "MANIFEST_ACTIVE is false with no manifest"
assert_ok "want is true with no manifest" want zellij
assert_ok "want_config is true with no manifest" want_config ghostty
assert_ok "want is true for a tool nobody named" want imagemagick

# ── a real manifest ─────────────────────────────────────────────────────
cat > "$sandbox/m.conf" <<'EOF'
# a comment
zellij = no

tmux   = yes
nvim = config-only
   btop	=	yes
EOF

assert_ok "load succeeds on a valid manifest" manifest_load "$sandbox/m.conf" "$TABLE"
manifest_load "$sandbox/m.conf" "$TABLE"
assert_eq "true" "$MANIFEST_ACTIVE" "MANIFEST_ACTIVE is true"
assert_eq "no" "$(manifest_value zellij)" "reads a no value"
assert_eq "yes" "$(manifest_value tmux)" "reads a yes value"
assert_eq "config-only" "$(manifest_value nvim)" "reads config-only"
assert_eq "yes" "$(manifest_value btop)" "tolerates tabs and leading spaces"

assert_fail "want is false for no" want zellij
assert_ok   "want is true for yes" want tmux
assert_fail "want is false for config-only" want nvim
assert_ok   "want_config is true for config-only" want_config nvim
assert_ok   "want_config is true for yes" want_config tmux
assert_fail "want_config is false for no" want_config zellij

# opt-in: a tool absent from an ACTIVE manifest is skipped
assert_fail "absent tool is skipped when manifest is active" want ghostty
assert_fail "absent tool config is skipped too" want_config ghostty

# ── validation: unknown key ─────────────────────────────────────────────
printf 'zsh = yes\nghosty = yes\n' > "$sandbox/bad-key.conf"
assert_fail "unknown key fails the load" manifest_load "$sandbox/bad-key.conf" "$TABLE"
err="$(manifest_load "$sandbox/bad-key.conf" "$TABLE" 2>&1 || true)"
assert_contains "$err" "bad-key.conf:2" "error names the line number"
assert_contains "$err" "ghosty" "error names the offending key"

# ── validation: bad value ───────────────────────────────────────────────
printf 'zsh = maybe\n' > "$sandbox/bad-val.conf"
assert_fail "invalid value fails the load" manifest_load "$sandbox/bad-val.conf" "$TABLE"
err="$(manifest_load "$sandbox/bad-val.conf" "$TABLE" 2>&1 || true)"
assert_contains "$err" "bad-val.conf:1" "value error names the line"
assert_contains "$err" "maybe" "value error names the bad value"

# ── validation: malformed line ──────────────────────────────────────────
printf 'zsh yes\n' > "$sandbox/no-eq.conf"
assert_fail "line without = fails the load" manifest_load "$sandbox/no-eq.conf" "$TABLE"

# ── a failed load leaves the manifest inactive, never half-applied ──────
manifest_load "$sandbox/bad-key.conf" "$TABLE" >/dev/null 2>&1 || true
assert_eq "false" "$MANIFEST_ACTIVE" "a failed load does not activate the manifest"

# ── summary ─────────────────────────────────────────────────────────────
manifest_load "$sandbox/m.conf" "$TABLE" >/dev/null 2>&1
summary="$(manifest_summary)"
assert_contains "$summary" "zellij" "summary lists a skipped tool"
assert_contains "$summary" "2 yes" "summary counts yes entries"
assert_contains "$summary" "1 no" "summary counts no entries"
assert_contains "$summary" "1 config-only" "summary counts config-only entries"

manifest_load "$sandbox/nope.conf" "$TABLE" >/dev/null 2>&1
assert_contains "$(manifest_summary)" "none" "summary says none when there is no manifest"

# ── table lookup ────────────────────────────────────────────────────────
manifest_load "$sandbox/m.conf" "$TABLE" >/dev/null 2>&1
assert_eq "brew:zellij" "$(tool_cell zellij macos)" "tool_cell reads the macos column"
assert_eq "-" "$(tool_cell zellij raspbian)" "tool_cell reads a dash cell"
assert_eq "apt:zsh" "$(tool_cell zsh debian)" "tool_cell reads the debian column"
assert_eq "dnf:neovim" "$(tool_cell nvim fedora)" "tool_cell reads the fedora column"

cleanup_sandbox "$sandbox"
finish_tests
