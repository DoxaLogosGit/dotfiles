#!/bin/bash
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

# --dry-run must write nothing. It used to: five mkdir -p calls in
# install_symlinks_common ran unguarded, so a preview created directories in
# the real HOME — and the phase-gate tests, which drive a full --dry-run --all,
# were writing there on every run. Dry run is a safety boundary the container
# runs and those tests both depend on, so it gets its own test.

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

sandbox="$(make_sandbox)"
fake_home="$sandbox/fakehome"
mkdir -p "$fake_home"

out="$(HOME="$fake_home" \
       DOTFILES_DIR="$REPO" \
       DOTFILES_OVERLAY="$sandbox/overlay" \
       bash "$REPO/install.sh" --dry-run --all 2>&1 || true)"

assert_contains "$out" "DRY-RUN" "the run reported itself as a dry run"

created="$(find "$fake_home" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')"
if [ "$created" = "0" ]; then
    _pass "--dry-run --all creates nothing in HOME"
else
    _fail "--dry-run --all creates nothing in HOME" \
          "$created entr(ies) created: $(find "$fake_home" -mindepth 1 2>/dev/null | head -5 | tr '\n' ' ')"
fi

# Nor may it write into the overlay or the repo.
overlay_created="$(find "$sandbox/overlay" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "0" "$overlay_created" "--dry-run --all creates nothing in the overlay"

repo_dirty="$(cd "$REPO" && git status --porcelain -- pi/ opencode/ 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "0" "$repo_dirty" "--dry-run --all does not seed files into the repo"

cleanup_sandbox "$sandbox"
finish_tests
