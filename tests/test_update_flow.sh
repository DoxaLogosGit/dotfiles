#!/bin/bash
set -u
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
sandbox="$(make_sandbox)"

run_update() {
    local os="$1" manifest="$2"
    printf '%s\n' "$manifest" > "$sandbox/manifest.conf"
    (
        HOME="$sandbox/home"; export HOME
        DOTFILES_DIR="$REPO"; export DOTFILES_DIR
        DOTFILES_OVERLAY="$sandbox"; export DOTFILES_OVERLAY
        PACKAGE_ACTION=update; export PACKAGE_ACTION
        PKG_DRY_RUN=true; export PKG_DRY_RUN
        bash "$REPO/scripts/packages-$os.sh" 2>&1
    )
}

manifest="rust = yes
zellij = yes
pi = no
playwright = no
tpm = no
oh-my-zsh = no
pi-packages = no
claude-plugins = no"

out="$(run_update debian "$manifest")"
assert_contains "$out" "apt-get update" "Debian updates the package index"
assert_contains "$out" "apt-get upgrade -yy" "Debian upgrades installed packages"
assert_contains "$out" "cargo install --locked --force zellij" "Debian refreshes enabled Cargo tools"
case "$out" in
    *"build-essential"*) _fail "Debian update skips bootstrap prerequisites" "build prerequisites appeared" ;;
    *) _pass "Debian update skips bootstrap prerequisites" ;;
esac

out="$(run_update fedora "$manifest")"
assert_contains "$out" "dnf upgrade --refresh -y" "Fedora refreshes and upgrades installed packages"
assert_contains "$out" "cargo install --locked --force zellij" "Fedora refreshes enabled Cargo tools"
case "$out" in
    *"dnf install"*) _fail "Fedora update skips bootstrap prerequisites" "dnf install appeared" ;;
    *) _pass "Fedora update skips bootstrap prerequisites" ;;
esac

# macOS needs no macOS host: a temporary brew implementation covers the update
# branch and keeps the test independent from the machine that runs it.
stub_bin="$sandbox/bin"
mkdir -p "$stub_bin"
cat > "$stub_bin/brew" <<'EOF'
#!/bin/bash
case "$1" in
    shellenv) printf '%s\n' 'export HOMEBREW_STUB=1' ;;
    *) printf 'STUB brew %s\n' "$*" ;;
esac
EOF
chmod +x "$stub_bin/brew"
out=$(PATH="$stub_bin:$PATH" run_update macos "$manifest")
assert_contains "$out" "[DRY-RUN] brew update" "macOS updates Homebrew metadata"
assert_contains "$out" "[DRY-RUN] brew upgrade" "macOS upgrades installed Homebrew packages"
case "$out" in
    *"cargo install"*) _fail "macOS leaves Homebrew-managed zellij to Homebrew" "cargo appeared" ;;
    *) _pass "macOS leaves Homebrew-managed zellij to Homebrew" ;;
esac

cleanup_sandbox "$sandbox"
finish_tests
