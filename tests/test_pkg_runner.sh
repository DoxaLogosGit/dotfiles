#!/bin/bash
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

sandbox="$(make_sandbox)"

# A tiny table, so these tests do not depend on the real one's contents.
printf '%s\n' \
  '# tool	fedora	debian	raspbian	macos' \
  'alpha	dnf:alpha-pkg	apt:alpha	-	brew:alpha' \
  'beta	cargo:beta	cargo:beta	-	brew:beta' \
  'gamma	fn:gamma_custom	-	-	-' \
  'delta	dnf:d-one,d-two	apt:d-one,d-two	-	-' \
  > "$sandbox/table.tsv"

# Run pkg_run_table for one OS under a given manifest, in a subshell so the
# stub handlers cannot leak between cases.
run_table() {
    local manifest_body="$1" os="$2"
    (
        # shellcheck source=../scripts/manifest.sh
        . "$REPO/scripts/manifest.sh"
        # shellcheck source=../scripts/pkg-runner.sh
        . "$REPO/scripts/pkg-runner.sh"
        PKG_DRY_RUN=true
        gamma_custom() { echo "CUSTOM gamma ran"; }
        if [ -n "$manifest_body" ]; then
            printf '%s\n' "$manifest_body" > "$sandbox/m.conf"
        else
            rm -f "$sandbox/m.conf"
        fi
        manifest_load "$sandbox/m.conf" "$sandbox/table.tsv" >/dev/null 2>&1
        pkg_run_table "$os" 2>&1
    )
}

# ── no manifest: everything available for the OS installs ───────────────
out="$(run_table "" fedora)"
assert_contains "$out" "dnf install -y alpha-pkg" "dnf cell becomes a dnf install"
assert_contains "$out" "cargo install beta" "cargo cell becomes a cargo install"
assert_contains "$out" "[DRY-RUN] gamma_custom" "fn cell resolves to its handler"
assert_contains "$out" "d-one d-two" "a comma cell installs several packages"

# ── a '-' cell is skipped without the manifest saying so ────────────────
out="$(run_table "" raspbian)"
case "$out" in
    *alpha*) _fail "dash cell is skipped on that OS" "alpha installed on raspbian" ;;
    *) _pass "dash cell is skipped on that OS" ;;
esac

# ── the right column is read per OS ─────────────────────────────────────
out="$(run_table "" debian)"
assert_contains "$out" "apt-get install" "debian reads the apt column"
case "$out" in
    *"dnf install"*) _fail "debian does not read the fedora column" "dnf appeared on debian" ;;
    *) _pass "debian does not read the fedora column" ;;
esac

out="$(run_table "" macos)"
assert_contains "$out" "brew_install alpha" "macos reads the brew column"

# ── a 'no' tool is skipped and reported ─────────────────────────────────
out="$(run_table "$(printf 'alpha = no\nbeta = yes\ngamma = yes\ndelta = yes\n')" fedora)"
case "$out" in
    *"alpha-pkg"*) _fail "manifest no skips the install" "alpha installed anyway" ;;
    *) _pass "manifest no skips the install" ;;
esac
assert_contains "$out" "Skipping alpha" "the skip is reported, not silent"
assert_contains "$out" "cargo install beta" "other tools still install"

# ── config-only installs nothing ────────────────────────────────────────
out="$(run_table "alpha = config-only" fedora)"
case "$out" in
    *"alpha-pkg"*) _fail "config-only installs no package" "alpha installed" ;;
    *) _pass "config-only installs no package" ;;
esac

# ── row order is install order ──────────────────────────────────────────
out="$(run_table "" fedora)"
alpha_at=$(printf '%s' "$out" | grep -n 'alpha-pkg' | head -1 | cut -d: -f1)
beta_at=$(printf '%s' "$out" | grep -n 'cargo install beta' | head -1 | cut -d: -f1)
assert_ok "table rows run top to bottom" test "$alpha_at" -lt "$beta_at"

# ── with PKG_DRY_RUN off, an fn: handler actually runs ──────────────────
# The dry-run cases above prove handlers are not executed while previewing;
# this proves they are executed when not.
out=$(
    # shellcheck source=../scripts/manifest.sh
    . "$REPO/scripts/manifest.sh"
    # shellcheck source=../scripts/pkg-runner.sh
    . "$REPO/scripts/pkg-runner.sh"
    PKG_DRY_RUN=false
    gamma_custom() { echo "CUSTOM gamma ran"; }
    # Only gamma is wanted, so no package manager is invoked.
    printf 'gamma = yes\n' > "$sandbox/live.conf"
    manifest_load "$sandbox/live.conf" "$sandbox/table.tsv" >/dev/null 2>&1
    pkg_run_table fedora 2>&1
)
assert_contains "$out" "CUSTOM gamma ran" "a live run executes the fn: handler"
case "$out" in
    *"dnf install"*) _fail "a live run of only gamma touches no package manager" "dnf was invoked" ;;
    *) _pass "a live run of only gamma touches no package manager" ;;
esac

# ── the info fallback must be a function, not /usr/bin/info (texinfo) ───
out=$(
    . "$REPO/scripts/pkg-runner.sh"
    info "probe-line"
)
assert_contains "$out" "probe-line" "the info fallback prints instead of running texinfo"

# ── an undefined fn: handler warns instead of failing silently ──────────
out=$(
    # shellcheck source=../scripts/manifest.sh
    . "$REPO/scripts/manifest.sh"
    # shellcheck source=../scripts/pkg-runner.sh
    . "$REPO/scripts/pkg-runner.sh"
    PKG_DRY_RUN=true
    rm -f "$sandbox/m.conf"
    manifest_load "$sandbox/m.conf" "$sandbox/table.tsv" >/dev/null 2>&1
    pkg_run_table fedora 2>&1
)
assert_contains "$out" "gamma_custom" "an undefined fn: handler is named in the warning"

# ── an unknown method warns rather than running anything ────────────────
printf '%s\n' \
  '# tool	fedora	debian	raspbian	macos' \
  'weird	bogus:thing	-	-	-' \
  > "$sandbox/bad.tsv"
out=$(
    # shellcheck source=../scripts/manifest.sh
    . "$REPO/scripts/manifest.sh"
    # shellcheck source=../scripts/pkg-runner.sh
    . "$REPO/scripts/pkg-runner.sh"
    PKG_DRY_RUN=true
    manifest_load "$sandbox/none.conf" "$sandbox/bad.tsv" >/dev/null 2>&1
    pkg_run_table fedora 2>&1
)
assert_contains "$out" "unknown install method" "an unknown method is reported"

cleanup_sandbox "$sandbox"
finish_tests
