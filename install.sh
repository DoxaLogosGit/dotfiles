#!/bin/bash
#
# Dotfiles Installer
# https://github.com/jgatkinsn/dotfiles
#
# This script installs and configures dotfiles on a new system.
# It supports Debian/Ubuntu and Fedora/RHEL systems.
#

set -e

DOTFILES_DIR="$HOME/.dotfiles"
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
        mkdir -p "$BACKUP_DIR"
        local backup_path="$BACKUP_DIR/$(basename "$file")"
        if [ "$DRY_RUN" = true ]; then
            info "[DRY-RUN] Would backup: $file -> $backup_path"
        else
            cp -P "$file" "$backup_path" 2>/dev/null || true
            info "Backed up: $file -> $backup_path"
        fi
    fi
}

# Create a symlink
create_symlink() {
    local source="$1"
    local target="$2"

    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would link: $source -> $target"
        return
    fi

    # Create parent directory if needed
    mkdir -p "$(dirname "$target")"

    # Backup existing file
    if [ -e "$target" ] || [ -L "$target" ]; then
        backup_file "$target"
        rm -rf "$target"
    fi

    ln -sf "$source" "$target"
    success "Linked: $target -> $source"
}

# Shared symlinks for all platforms; $1 = tmux config filename (e.g. tmux.conf or tmux-raspbian.conf)
install_symlinks_common() {
    local tmux_conf="$1"

    mkdir -p "$HOME/.vim-tmp"
    mkdir -p "$HOME/.tmp"
    mkdir -p "$HOME/.tmux/plugins"
    mkdir -p "$HOME/.local/bin"
    mkdir -p "$HOME/.pi"
    mkdir -p "$HOME/.tallow"

    # Fish (fish manages its own dir — symlink config files only)
    create_symlink "$DOTFILES_DIR/fish/config.fish" "$HOME/.config/fish/config.fish"
    create_symlink "$DOTFILES_DIR/fish/fish_plugins" "$HOME/.config/fish/fish_plugins"
    create_symlink "$DOTFILES_DIR/fish/functions" "$HOME/.config/fish/functions"

    # Starship
    create_symlink "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"

    # Neovim (lua/ dir exists in live but not tracked — symlink known files only)
    create_symlink "$DOTFILES_DIR/nvim/init.lua" "$HOME/.config/nvim/init.lua"
    create_symlink "$DOTFILES_DIR/nvim/lazy-lock.json" "$HOME/.config/nvim/lazy-lock.json"
    create_symlink "$DOTFILES_DIR/nvim/colors" "$HOME/.config/nvim/colors"

    # Vim
    create_symlink "$DOTFILES_DIR/vim/vimrc" "$HOME/.vimrc"

    # Tmux
    create_symlink "$DOTFILES_DIR/tmux/$tmux_conf" "$HOME/.tmux.conf"

    # Yazi
    create_symlink "$DOTFILES_DIR/yazi" "$HOME/.config/yazi"

    # Zellij
    create_symlink "$DOTFILES_DIR/zellij" "$HOME/.config/zellij"

    # Git
    create_symlink "$DOTFILES_DIR/git/gitconfig" "$HOME/.gitconfig"

    # Nushell (nushell writes history.txt — symlink config file only)
    create_symlink "$DOTFILES_DIR/nushell/config.nu" "$HOME/.config/nushell/config.nu"

    # Zsh (legacy)
    create_symlink "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"

    # Python
    create_symlink "$DOTFILES_DIR/python/pylintrc" "$HOME/.pylintrc"

    # Bash
    create_symlink "$DOTFILES_DIR/bash/bashrc" "$HOME/.bashrc"
    create_symlink "$DOTFILES_DIR/bash/bash_profile" "$HOME/.bash_profile"

    # htop
    create_symlink "$DOTFILES_DIR/htop" "$HOME/.config/htop"

    # btop
    create_symlink "$DOTFILES_DIR/btop" "$HOME/.config/btop"

    # Pi coding agent
    create_symlink "$DOTFILES_DIR/pi" "$HOME/.pi/agent"

    # Tallow coding agent (tallow manages ~/.tallow/ — symlink config files only)
    create_symlink "$DOTFILES_DIR/tallow/models.json" "$HOME/.tallow/models.json"
    create_symlink "$DOTFILES_DIR/tallow/settings.json" "$HOME/.tallow/settings.json"

    # Scripts
    create_symlink "$DOTFILES_DIR/scripts/reset_last_tmux_resurrect.sh" "$HOME/.local/bin/reset_last_tmux_resurrect.sh"
}

# Install symlinks (Raspbian — thumbs/Ghostty/Claude/VS Code/OpenCode/Gemini excluded)
install_symlinks_raspbian() {
    info "Creating symlinks (Raspbian)..."
    install_symlinks_common "tmux-raspbian.conf"
    success "Symlinks created!"
}

# Install symlinks
install_symlinks() {
    info "Creating symlinks..."

    mkdir -p "$HOME/.config/Code/User"

    install_symlinks_common "tmux.conf"

    # Ghostty (themes/ is tool-managed, gitignored)
    create_symlink "$DOTFILES_DIR/ghostty" "$HOME/.config/ghostty"

    # Claude (Claude Code manages ~/.claude/ — symlink scripts dir and settings file)
    create_symlink "$DOTFILES_DIR/claude/scripts" "$HOME/.claude/scripts"
    create_symlink "$DOTFILES_DIR/claude/settings.json" "$HOME/.claude/settings.json"

    # VS Code (Code/User is tool-managed — symlink settings file only)
    create_symlink "$DOTFILES_DIR/vscode/settings.json" "$HOME/.config/Code/User/settings.json"

    # OpenCode (opencode manages its own dir — symlink config file only)
    create_symlink "$DOTFILES_DIR/opencode/opencode.json" "$HOME/.config/opencode/opencode.json"

    # Gemini (gemini manages ~/.gemini/ — symlink settings file only)
    create_symlink "$DOTFILES_DIR/gemini/settings.json" "$HOME/.gemini/settings.json"

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
    else
        error "Unsupported OS type: $OS_TYPE"
        exit 1
    fi
}

# Install fonts
install_fonts() {
    info "Installing nerd fonts..."
    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would run: scripts/fonts.sh"
    else
        bash "$DOTFILES_DIR/scripts/fonts.sh"
    fi
}

# Main
main() {
    local DO_PACKAGES=false
    local DO_SYMLINKS=false
    local DO_FONTS=false
    local DO_PLUGINS=false
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
        echo "  6) Exit"
        echo ""
        read -p "Enter choice [1-6]: " choice

        case "$choice" in
            1)
                DO_PACKAGES=true
                DO_SYMLINKS=true
                DO_FONTS=true
                DO_PLUGINS=true
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

    # Execute selected actions
    if [ "$DRY_RUN" = true ]; then
        warning "Running in DRY-RUN mode - no changes will be made"
        echo ""
    fi

    if [ "$DO_PACKAGES" = true ]; then
        install_packages
    fi

    if [ "$DO_SYMLINKS" = true ]; then
        if [ "$OS_TYPE" = "raspbian" ]; then
            install_symlinks_raspbian
        else
            install_symlinks
        fi
    fi

    if [ "$DO_FONTS" = true ]; then
        install_fonts
    fi

    if [ "$DO_PLUGINS" = true ]; then
        install_claude_plugins
    fi

    echo ""
    success "Done!"
}

main "$@"
