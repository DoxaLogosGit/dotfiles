#!/bin/bash
#
# Dotfiles Installer
# https://github.com/jgatkinsn/dotfiles
#
# This script installs and configures dotfiles on a new system.
# It supports Debian/Ubuntu, Fedora/RHEL, Raspbian, and macOS systems.
#

set -e

# Overridable so the repo can be exercised from another path — a container, a
# worktree — without being cloned to ~/.dotfiles first.
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Detect OS
detect_os() {
    # macOS has none of the Linux /etc/os-release files; detect it first.
    if [ "$(uname -s)" = "Darwin" ]; then
        OS="macos"
        OS_FAMILY="darwin"
        OS_TYPE="macos"
        info "Detected OS: macOS (type: macos)"
        return
    fi

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_FAMILY=$ID_LIKE
    elif [ -f /etc/debian_version ]; then
        OS="debian"
        OS_FAMILY="debian"
    elif [ -f /etc/fedora-release ]; then
        OS="fedora"
        OS_FAMILY="fedora"
    else
        OS=$(uname -s)
        OS_FAMILY="unknown"
    fi

    case "$OS" in
        raspbian)
            OS_TYPE="raspbian"
            ;;
        ubuntu|debian|linuxmint|pop)
            OS_TYPE="debian"
            ;;
        fedora|rhel|centos|rocky|alma)
            OS_TYPE="fedora"
            ;;
        *)
            if [[ "$OS_FAMILY" == *"debian"* ]]; then
                OS_TYPE="debian"
            elif [[ "$OS_FAMILY" == *"fedora"* ]] || [[ "$OS_FAMILY" == *"rhel"* ]]; then
                OS_TYPE="fedora"
            else
                OS_TYPE="unknown"
            fi
            ;;
    esac

    info "Detected OS: $OS (type: $OS_TYPE)"
}

# Show usage
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
    --packages      Install system packages
    --symlinks      Create config symlinks
    --fonts         Install nerd fonts
    --plugins       Install Claude Code plugins
    --all           Do everything (packages + symlinks + fonts + plugins)
    --systemd      Enable systemd user units (snapshot + vault backup timers)
    --dry-run       Show what would be done without making changes
    -h, --help      Show this help message

Examples:
    $(basename "$0") --all              # Full installation
    $(basename "$0") --symlinks         # Only create symlinks
    $(basename "$0") --dry-run --all    # Preview full installation

EOF
}

# Backup a file before replacing
backup_file() {
    local file="$1"
    if [ -e "$file" ] || [ -L "$file" ]; then
        # Mirror the target's path under $BACKUP_DIR instead of flattening to
        # a basename: atuin/herdr both ship config.toml, and ~/.claude and VS
        # Code both ship settings.json, so a flat name let one backup silently
        # overwrite another within a single run.
        local rel="${file#"$HOME"/}"
        rel="${rel#/}"
        local backup_path="$BACKUP_DIR/$rel"
        if [ "$DRY_RUN" = true ]; then
            info "[DRY-RUN] Would backup: $file -> $backup_path"
            return 0
        fi
        mkdir -p "$(dirname "$backup_path")"
        # -a, not -P: targets like ~/.pi/agent and ~/.config/ghostty are
        # directories holding live agent state (auth.json, sessions/). A
        # non-recursive copy silently skipped them, and the caller then
        # removed the original.
        if cp -a "$file" "$backup_path"; then
            info "Backed up: $file -> $backup_path"
        else
            warning "Backup FAILED: $file (leaving it untouched)"
            return 1
        fi
    fi
    return 0
}

# ── Machine-local overlay ─────────────────────────────────────────────────────
#
# Some config is per-machine and cannot be shared: pi/models.json mixes local
# ollama models with per-network gateways, zellij layouts embed absolute paths,
# and herdr may be tuned differently on each box.
#
# An overlay is an optional, separately-hosted directory holding those files for
# *this* machine. It is deliberately anonymous: this script only asks whether one
# exists, never where it came from. That keeps each machine class on its own
# network and its own host (personal devices in one place, employer-provided
# equipment in whatever that employer hosts) with no repo referencing another.
#
# Layout mirrors this repo, so an overlay holding pi/models.json and
# herdr/config.toml shadows exactly those files:
#
#     ~/.dotfiles-local/
#       zsh/zshrc.local
#       git/gitconfig.local
#       vim/vimrc.local
#       pi/models.json
#       herdr/config.toml
#       zellij/layouts/*.kdl
#
# Note that zshrc.local can hold real credentials. An overlay is a backup, not a
# vault: whatever hosts it must be at least as private as the values inside it.
#
# When no overlay is present, every path below behaves exactly as it did before
# overlays existed: templates are seeded from *.example and nothing else changes.
DOTFILES_OVERLAY="${DOTFILES_OVERLAY:-$HOME/.dotfiles-local}"

# Per-machine install manifest. Decides which tools this machine installs and
# configures; absent, everything is installed as it was before manifests.
# shellcheck source=scripts/manifest.sh
. "$DOTFILES_DIR/scripts/manifest.sh"
MANIFEST_TABLE_FILE="$DOTFILES_DIR/scripts/tools.tsv"

# True when an overlay directory is present.
overlay_active() {
    [ -n "$DOTFILES_OVERLAY" ] && [ -d "$DOTFILES_OVERLAY" ]
}

# Echo the overlay's copy of a repo-relative path when it exists, else nothing.
overlay_path() {
    local rel="$1"
    overlay_active || return 1
    [ -e "$DOTFILES_OVERLAY/$rel" ] || return 1
    printf '%s' "$DOTFILES_OVERLAY/$rel"
}

# Link a machine-local file from the overlay when present. Falls back to the
# caller's behaviour (via return 1) when there is no overlay copy, so callers
# keep their existing template-seeding path untouched.
link_from_overlay() {
    local rel="$1"
    local target="$2"
    local src

    src="$(overlay_path "$rel")" || return 1
    create_symlink "$src" "$target"
    return 0
}

# Replace a directory symlink left behind by an older layout with a real
# directory. ~/.config/zellij used to be a symlink to the repo's zellij/, so
# linking a file *inside* it resolved back into the repo: the installer
# overwrote the tracked zellij/config.kdl with a symlink pointing at itself,
# and zellij then failed with "Too many levels of symbolic links".
ensure_real_dir() {
    local dir="$1"

    if [ -L "$dir" ]; then
        if [ "$DRY_RUN" = true ]; then
            info "[DRY-RUN] Would replace stale directory symlink: $dir"
            return 0
        fi
        if ! backup_file "$dir"; then
            warning "Skipped: $dir (could not back up the stale symlink)"
            return 1
        fi
        rm -f "$dir"
        info "Replaced stale directory symlink with a real directory: $dir"
    fi

    if [ "$DRY_RUN" = true ]; then
        [ -d "$dir" ] || info "[DRY-RUN] Would create directory: $dir"
        return 0
    fi
    mkdir -p "$dir"
}

# mkdir -p that honours DRY_RUN, so a preview run writes nothing.
ensure_dir() {
    if [ "$DRY_RUN" = true ]; then
        [ -d "$1" ] || info "[DRY-RUN] Would create directory: $1"
        return 0
    fi
    mkdir -p "$1"
}

# Copy a template into place only if the target does not exist. Used for
# machine-local files that must not be symlinked back into the repo.
copy_template() {
    local source="$1"
    local target="$2"

    if [ -e "$target" ]; then
        info "Kept existing: $target"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would copy template: $source -> $target"
        return
    fi

    mkdir -p "$(dirname "$target")"
    cp "$source" "$target"
    success "Created from template: $target (edit it for this machine)"
}

# Create a symlink
create_symlink() {
    local source="$1"
    local target="$2"

    # A source that no longer exists in the repo must never cost the machine
    # its live config: without this, an untracked-and-deleted source left a
    # dangling symlink where a working file used to be.
    if [ ! -e "$source" ]; then
        warning "Skipped: $source is missing from the repo (kept $target as-is)"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would link: $source -> $target"
        return
    fi

    # Create parent directory if needed
    mkdir -p "$(dirname "$target")"

    # Backup existing file, and keep it if the backup did not succeed
    if [ -e "$target" ] || [ -L "$target" ]; then
        if ! backup_file "$target"; then
            warning "Skipped: $target (could not back it up)"
            return
        fi
        rm -rf "$target"
    fi

    ln -sf "$source" "$target"
    success "Linked: $target -> $source"
}

# Shared symlinks for all platforms. A machine needing a different tmux config
# supplies tmux/tmux.conf in its overlay directory rather than adding a variant
# file and an OS branch here.
install_symlinks_common() {

    if overlay_active; then
        info "Using machine-local overlay: $DOTFILES_OVERLAY"
    fi

    # A dry run must not touch the filesystem at all: these ran unguarded, so
    # --dry-run silently created directories in the real HOME and could not be
    # trusted as a safety boundary when testing.
    ensure_dir "$HOME/.vim-tmp"
    ensure_dir "$HOME/.tmp"
    ensure_dir "$HOME/.tmux/plugins"
    ensure_dir "$HOME/.local/bin"
    ensure_dir "$HOME/.pi"

    # Zsh (primary shell)
    if want_config zsh; then
        create_symlink "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"
        link_from_overlay "zsh/zshrc.local" "$HOME/.zshrc.local" ||
            copy_template "$DOTFILES_DIR/zsh/zshrc.local.example" "$HOME/.zshrc.local"
    fi

    # Starship
    if want_config starship; then
        create_symlink "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"
    fi

    # Neovim (lua/ dir exists in live but not tracked — symlink known files only)
    if want_config nvim; then
        create_symlink "$DOTFILES_DIR/nvim/init.lua" "$HOME/.config/nvim/init.lua"
        create_symlink "$DOTFILES_DIR/nvim/lazy-lock.json" "$HOME/.config/nvim/lazy-lock.json"
        create_symlink "$DOTFILES_DIR/nvim/colors" "$HOME/.config/nvim/colors"
    fi

    # Vim (employer/email are per-machine — see vimrc.local.example)
    if want_config vim; then
        create_symlink "$DOTFILES_DIR/vim/vimrc" "$HOME/.vimrc"
        link_from_overlay "vim/vimrc.local" "$HOME/.vimrc.local" ||
            copy_template "$DOTFILES_DIR/vim/vimrc.local.example" "$HOME/.vimrc.local"
    fi

    # Tmux
    if want_config tmux; then
        link_from_overlay "tmux/tmux.conf" "$HOME/.tmux.conf" ||
            create_symlink "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
    fi

    # Yazi
    if want_config yazi; then
        create_symlink "$DOTFILES_DIR/yazi" "$HOME/.config/yazi"
    fi

    # Zellij (layouts/ are machine-local — they embed absolute cwd paths and
    # per-machine commands — so symlink the config file only)
    if want_config zellij; then
        # Older installs symlinked the whole directory; convert before linking into it.
        ensure_real_dir "$HOME/.config/zellij"
        create_symlink "$DOTFILES_DIR/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
        ensure_dir "$HOME/.config/zellij/layouts"
        # Link each overlay layout individually rather than replacing the directory,
        # so layouts dumped on this machine by `zdump` are never destroyed.
        if overlay_active && [ -d "$DOTFILES_OVERLAY/zellij/layouts" ]; then
            local layout
            for layout in "$DOTFILES_OVERLAY"/zellij/layouts/*.kdl; do
                [ -e "$layout" ] || continue
                create_symlink "$layout" "$HOME/.config/zellij/layouts/$(basename "$layout")"
            done
        fi
    fi

    # Git (identity/credentials are per-machine — see gitconfig.local.example)
    if want_config git; then
        create_symlink "$DOTFILES_DIR/git/gitconfig" "$HOME/.gitconfig"
        link_from_overlay "git/gitconfig.local" "$HOME/.gitconfig.local" ||
            copy_template "$DOTFILES_DIR/git/gitconfig.local.example" "$HOME/.gitconfig.local"
    fi

    # Nushell (nushell writes history.txt — symlink config file only)
    if want_config nushell; then
        create_symlink "$DOTFILES_DIR/nushell/config.nu" "$HOME/.config/nushell/config.nu"
    fi

    # Atuin (atuin manages ~/.config/atuin/ — symlink config file only)
    if want_config atuin; then
        create_symlink "$DOTFILES_DIR/atuin/config.toml" "$HOME/.config/atuin/config.toml"
    fi

    # Atuin — generate nushell integration file
    if command -v atuin &>/dev/null; then
        if [ "$DRY_RUN" = true ]; then
            info "[DRY-RUN] Would generate: ~/.local/share/atuin/init.nu"
        else
            ensure_dir "$HOME/.local/share/atuin"
            atuin init nu > "$HOME/.local/share/atuin/init.nu"
            success "Generated: ~/.local/share/atuin/init.nu"
        fi
    else
        warning "atuin not found — skipping nushell init generation (run after installing atuin)"
    fi

    # Python
    if want_config python; then
        create_symlink "$DOTFILES_DIR/python/pylintrc" "$HOME/.pylintrc"
    fi

    # Bash
    if want_config bash; then
        create_symlink "$DOTFILES_DIR/bash/bashrc" "$HOME/.bashrc"
        create_symlink "$DOTFILES_DIR/bash/bash_profile" "$HOME/.bash_profile"
    fi

    # htop
    if want_config htop; then
        create_symlink "$DOTFILES_DIR/htop" "$HOME/.config/htop"
    fi

    # btop
    if want_config btop; then
        create_symlink "$DOTFILES_DIR/btop" "$HOME/.config/btop"
    fi

    # Pi coding agent
    # models.json and settings.json are untracked (internal endpoints,
    # per-machine model access). An overlay copy is linked in when present;
    # otherwise seed models.json from the example as before.
    if want_config pi; then
        create_symlink "$DOTFILES_DIR/pi" "$HOME/.pi/agent"
        link_from_overlay "pi/models.json" "$DOTFILES_DIR/pi/models.json" ||
            copy_template "$DOTFILES_DIR/pi/models.json.example" "$DOTFILES_DIR/pi/models.json"
    fi

    # Herdr (herdr manages ~/.config/herdr/ logs + sessions — symlink config file
    # only). An overlay copy wins, so a machine can diverge its keybinds.
    if want_config herdr; then
        link_from_overlay "herdr/config.toml" "$HOME/.config/herdr/config.toml" ||
            create_symlink "$DOTFILES_DIR/herdr/config.toml" "$HOME/.config/herdr/config.toml"
    fi

    # Scripts
    if want_config scripts; then
        create_symlink "$DOTFILES_DIR/scripts/reset_last_tmux_resurrect.sh" "$HOME/.local/bin/reset_last_tmux_resurrect.sh"

        # Obsidian vault backup (replaces the Obsidian Git plugin)
        create_symlink "$DOTFILES_DIR/scripts/vault-backup" "$HOME/.local/bin/vault-backup"
    fi

    # Zellij snapshot tool (rotating session-state backups). Part of zellij:
    # a machine without it has nothing for these to drive.
    if want_config zellij; then
        create_symlink "$DOTFILES_DIR/scripts/zellij-snapshot" "$HOME/.local/bin/zellij-snapshot"
        create_symlink "$DOTFILES_DIR/scripts/zellij-restore" "$HOME/.local/bin/zellij-restore"
    fi
}

# Desktop/agent symlinks shared by Linux and macOS (Raspbian omits these).
# $1 = VS Code "User" settings dir (differs by OS).
install_symlinks_desktop() {
    local code_user_dir="$1"

    # Ghostty (themes/ is tool-managed, gitignored)
    if want_config ghostty; then
        create_symlink "$DOTFILES_DIR/ghostty" "$HOME/.config/ghostty"
    fi

    # Claude (Claude Code manages ~/.claude/ — symlink scripts dir and settings
    # file). settings.json routes through the overlay: Claude cannot be installed
    # on every machine, so each one decides whether to supply a config at all.
    if want_config claude; then
        create_symlink "$DOTFILES_DIR/claude/scripts" "$HOME/.claude/scripts"
        link_from_overlay "claude/settings.json" "$HOME/.claude/settings.json" ||
            create_symlink "$DOTFILES_DIR/claude/settings.json" "$HOME/.claude/settings.json"
    fi

    # VS Code (Code/User is tool-managed — symlink settings file only)
    if want_config vscode; then
        create_symlink "$DOTFILES_DIR/vscode/settings.json" "$code_user_dir/settings.json"
    fi

    # OpenCode (opencode manages its own dir — symlink config file only).
    # opencode.json holds gateway URLs and model catalogues, so it is untracked
    # and machine-local: take the overlay copy when there is one, otherwise seed
    # from the template so a fresh clone has a working starting point.
    if want_config opencode; then
        link_from_overlay "opencode/opencode.json" "$DOTFILES_DIR/opencode/opencode.json" ||
            copy_template "$DOTFILES_DIR/opencode/opencode.json.example" "$DOTFILES_DIR/opencode/opencode.json"
        create_symlink "$DOTFILES_DIR/opencode/opencode.json" "$HOME/.config/opencode/opencode.json"
    fi

}

# Install symlinks (Linux)
install_symlinks() {
    info "Creating symlinks..."

    ensure_dir "$HOME/.config/Code/User"

    install_symlinks_common
    install_symlinks_desktop "$HOME/.config/Code/User"

    success "Symlinks created!"
}

# Install symlinks (macOS — VS Code settings live under ~/Library)
install_symlinks_macos() {
    info "Creating symlinks (macOS)..."

    local code_user_dir="$HOME/Library/Application Support/Code/User"
    ensure_dir "$code_user_dir"

    install_symlinks_common
    install_symlinks_desktop "$code_user_dir"

    success "Symlinks created!"
}

# Install Claude plugins
install_claude_plugins() {
    info "Setting up Claude Code plugins..."
    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would run: claude/scripts/setup-plugins.sh"
    else
        bash "$DOTFILES_DIR/claude/scripts/setup-plugins.sh"
    fi
}

# Install packages
install_packages() {
    if [ "$OS_TYPE" = "raspbian" ]; then
        info "Installing packages for Raspbian..."
        if [ "$DRY_RUN" = true ]; then
            info "[DRY-RUN] Would run: scripts/packages-raspbian.sh"
        else
            bash "$DOTFILES_DIR/scripts/packages-raspbian.sh"
        fi
    elif [ "$OS_TYPE" = "debian" ]; then
        info "Installing packages for Debian/Ubuntu..."
        if [ "$DRY_RUN" = true ]; then
            info "[DRY-RUN] Would run: scripts/packages-debian.sh"
        else
            bash "$DOTFILES_DIR/scripts/packages-debian.sh"
        fi
    elif [ "$OS_TYPE" = "fedora" ]; then
        info "Installing packages for Fedora/RHEL..."
        if [ "$DRY_RUN" = true ]; then
            info "[DRY-RUN] Would run: scripts/packages-fedora.sh"
        else
            bash "$DOTFILES_DIR/scripts/packages-fedora.sh"
        fi
    elif [ "$OS_TYPE" = "macos" ]; then
        info "Installing packages for macOS..."
        if [ "$DRY_RUN" = true ]; then
            info "[DRY-RUN] Would run: scripts/packages-macos.sh"
        else
            bash "$DOTFILES_DIR/scripts/packages-macos.sh"
        fi
    else
        error "Unsupported OS type: $OS_TYPE"
        exit 1
    fi
}

# Install fonts
install_fonts() {
    if [ "$OS_TYPE" = "macos" ]; then
        info "Installing Nerd Font casks via Homebrew..."
        if [ "$DRY_RUN" = true ]; then
            info "[DRY-RUN] Would run: brew install --cask <nerd-font casks>"
            return
        fi
        # shellcheck source=scripts/install-homebrew.sh
        source "$DOTFILES_DIR/scripts/install-homebrew.sh"
        install_homebrew
        local casks="font-ubuntu-nerd-font font-ubuntu-mono-nerd-font \
font-symbols-only-nerd-font font-jetbrains-mono-nerd-font \
font-fira-mono-nerd-font font-fira-code-nerd-font font-adwaita-mono-nerd-font"
        local cask
        for cask in $casks; do
            if brew list --cask "$cask" >/dev/null 2>&1; then
                info "$cask already installed"
            else
                info "Installing $cask..."
                brew install --cask "$cask"
            fi
        done
        success "Fonts installed via Homebrew casks."
        return
    fi

    info "Installing nerd fonts..."
    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would run: scripts/fonts.sh"
    else
        bash "$DOTFILES_DIR/scripts/fonts.sh"
    fi
}

install_systemd_units() {
    info "Installing systemd user units..."

    if ! systemctl --user show-environment >/dev/null 2>&1; then
        warning "systemctl --user is not available — skipping systemd units."
        warning "  On WSL: enable systemd in /etc/wsl.conf and restart WSL."
        return 0
    fi

    create_symlink "$DOTFILES_DIR/scripts/zellij-snapshot.service" \
        "$HOME/.config/systemd/user/zellij-snapshot.service"
    create_symlink "$DOTFILES_DIR/scripts/zellij-snapshot.timer" \
        "$HOME/.config/systemd/user/zellij-snapshot.timer"
    create_symlink "$DOTFILES_DIR/scripts/zellij-snapshot-shutdown.service" \
        "$HOME/.config/systemd/user/zellij-snapshot-shutdown.service"

    create_symlink "$DOTFILES_DIR/scripts/vault-backup.service" \
        "$HOME/.config/systemd/user/vault-backup.service"
    create_symlink "$DOTFILES_DIR/scripts/vault-backup.timer" \
        "$HOME/.config/systemd/user/vault-backup.timer"

    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would run: systemctl --user daemon-reload"
        info "[DRY-RUN] Would run: systemctl --user enable --now zellij-snapshot.timer"
        info "[DRY-RUN] Would run: systemctl --user enable zellij-snapshot-shutdown.service"
        info "[DRY-RUN] Would run: systemctl --user enable --now vault-backup.timer"
    else
        systemctl --user daemon-reload
        systemctl --user enable --now zellij-snapshot.timer
        systemctl --user enable zellij-snapshot-shutdown.service
        systemctl --user enable --now vault-backup.timer
        success "Systemd units enabled."
    fi
}

# Main
main() {
    local DO_PACKAGES=false
    local DO_SYMLINKS=false
    local DO_FONTS=false
    local DO_PLUGINS=false
    local DO_SYSTEMD=false
    DRY_RUN=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --packages)
                DO_PACKAGES=true
                shift
                ;;
            --symlinks)
                DO_SYMLINKS=true
                shift
                ;;
            --fonts)
                DO_FONTS=true
                shift
                ;;
            --plugins)
                DO_PLUGINS=true
                shift
                ;;
            --all)
                DO_PACKAGES=true
                DO_SYMLINKS=true
                DO_FONTS=true
                DO_PLUGINS=true
                DO_SYSTEMD=true
                shift
                ;;
            --systemd)
                DO_SYSTEMD=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # If no options specified, show menu
    if [ "$DO_PACKAGES" = false ] && [ "$DO_SYMLINKS" = false ] && [ "$DO_FONTS" = false ] && [ "$DO_PLUGINS" = false ]; then
        echo ""
        echo "Dotfiles Installer"
        echo "=================="
        echo ""
        echo "What would you like to do?"
        echo ""
        echo "  1) Install everything (packages + symlinks + fonts + plugins)"
        echo "  2) Create symlinks only"
        echo "  3) Install packages only"
        echo "  4) Install fonts only"
        echo "  5) Install Claude plugins only"
        echo "  6) Enable systemd user units (snapshot timer)"
        echo "  7) Exit"
        echo ""
        read -p "Enter choice [1-7]: " choice

        case "$choice" in
            1)
                DO_PACKAGES=true
                DO_SYMLINKS=true
                DO_FONTS=true
                DO_PLUGINS=true
                DO_SYSTEMD=true
                ;;
            2)
                DO_SYMLINKS=true
                ;;
            3)
                DO_PACKAGES=true
                ;;
            4)
                DO_FONTS=true
                ;;
            5)
                DO_PLUGINS=true
                ;;
            6)
                DO_SYSTEMD=true
                ;;
            7)
                echo "Bye!"
                exit 0
                ;;
            *)
                error "Invalid choice"
                exit 1
                ;;
        esac
    fi

    # Detect OS
    detect_os

    # Validate the machine's manifest before anything is written: a typo must
    # stop the run, not silently skip a tool.
    if ! manifest_load "$DOTFILES_OVERLAY/manifest.conf" "$MANIFEST_TABLE_FILE"; then
        exit 1
    fi

    # Execute selected actions
    if [ "$DRY_RUN" = true ]; then
        warning "Running in DRY-RUN mode - no changes will be made"
        echo ""
    fi

    if [ "$DO_PACKAGES" = true ]; then
        install_packages
    fi

    if [ "$DO_SYMLINKS" = true ]; then
        if [ "$OS_TYPE" = "macos" ]; then
            install_symlinks_macos
        else
            install_symlinks
        fi
    fi

    if [ "$DO_FONTS" = true ]; then
        if want fonts; then
            install_fonts
        else
            info "Skipping fonts (manifest)."
        fi
    fi

    if [ "$DO_PLUGINS" = true ]; then
        if want claude-plugins; then
            install_claude_plugins
        else
            info "Skipping Claude plugins (manifest)."
        fi
    fi

    if [ "$DO_SYSTEMD" = true ]; then
        # macOS has no systemd at all — that is availability, not preference,
        # so it stays an OS check. The Raspbian skip was a preference and is
        # now 'systemd = no' in that machine's manifest.
        if [ "$OS_TYPE" = "macos" ]; then
            info "Skipping systemd units on macOS (no systemd; zellij-snapshot scripts still symlinked for manual use)."
        elif want systemd; then
            install_systemd_units
        else
            info "Skipping systemd units (manifest)."
        fi
    fi

    echo ""
    manifest_summary
    success "Done!"
}

# Only run main when executed directly, so the functions above can be
# sourced in isolation (e.g. for testing) without kicking off an install.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
