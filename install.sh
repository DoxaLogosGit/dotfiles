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
    --all           Do everything (packages + symlinks + fonts)
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

# Install symlinks
install_symlinks() {
    info "Creating symlinks..."

    # Create required directories
    mkdir -p "$HOME/.vim-tmp"
    mkdir -p "$HOME/.tmp"
    mkdir -p "$HOME/.config/fish"
    mkdir -p "$HOME/.config/nvim"
    mkdir -p "$HOME/.config/ghostty"
    mkdir -p "$HOME/.config/yazi"
    mkdir -p "$HOME/.config/nushell"
    mkdir -p "$HOME/.config/htop"
    mkdir -p "$HOME/.config/btop"
    mkdir -p "$HOME/.config/Code/User"
    mkdir -p "$HOME/.config/opencode"
    mkdir -p "$HOME/.gemini"
    mkdir -p "$HOME/.claude/scripts"
    mkdir -p "$HOME/.tmux/plugins"

    # Fish
    create_symlink "$DOTFILES_DIR/fish/config.fish" "$HOME/.config/fish/config.fish"

    # Starship
    create_symlink "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"

    # Neovim
    create_symlink "$DOTFILES_DIR/nvim/init.lua" "$HOME/.config/nvim/init.lua"
    create_symlink "$DOTFILES_DIR/nvim/lazy-lock.json" "$HOME/.config/nvim/lazy-lock.json"
    create_symlink "$DOTFILES_DIR/nvim/colors" "$HOME/.config/nvim/colors"

    # Vim
    create_symlink "$DOTFILES_DIR/vim/vimrc" "$HOME/.vimrc"

    # Tmux (TPM will manage plugins)
    create_symlink "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"

    # Ghostty
    create_symlink "$DOTFILES_DIR/ghostty/config" "$HOME/.config/ghostty/config"

    # Yazi
    create_symlink "$DOTFILES_DIR/yazi/yazi.toml" "$HOME/.config/yazi/yazi.toml"
    create_symlink "$DOTFILES_DIR/yazi/keymap.toml" "$HOME/.config/yazi/keymap.toml"
    create_symlink "$DOTFILES_DIR/yazi/theme.toml" "$HOME/.config/yazi/theme.toml"

    # Git
    create_symlink "$DOTFILES_DIR/git/gitconfig" "$HOME/.gitconfig"

    # Nushell
    create_symlink "$DOTFILES_DIR/nushell/config.nu" "$HOME/.config/nushell/config.nu"

    # Zsh (legacy)
    create_symlink "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"

    # Python
    create_symlink "$DOTFILES_DIR/python/pylintrc" "$HOME/.pylintrc"

    # Claude
    create_symlink "$DOTFILES_DIR/claude/scripts/context-bar.sh" "$HOME/.claude/scripts/context-bar.sh"
    create_symlink "$DOTFILES_DIR/claude/settings.json" "$HOME/.claude/settings.json"

    # Bash
    create_symlink "$DOTFILES_DIR/bash/bashrc" "$HOME/.bashrc"
    create_symlink "$DOTFILES_DIR/bash/bash_profile" "$HOME/.bash_profile"

    # htop
    create_symlink "$DOTFILES_DIR/htop/htoprc" "$HOME/.config/htop/htoprc"

    # btop
    create_symlink "$DOTFILES_DIR/btop/btop.conf" "$HOME/.config/btop/btop.conf"

    # VS Code
    create_symlink "$DOTFILES_DIR/vscode/settings.json" "$HOME/.config/Code/User/settings.json"

    # OpenCode
    create_symlink "$DOTFILES_DIR/opencode/opencode.json" "$HOME/.config/opencode/opencode.json"

    # Gemini
    create_symlink "$DOTFILES_DIR/gemini/settings.json" "$HOME/.gemini/settings.json"

    success "Symlinks created!"
}

# Install packages
install_packages() {
    if [ "$OS_TYPE" = "debian" ]; then
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
            --all)
                DO_PACKAGES=true
                DO_SYMLINKS=true
                DO_FONTS=true
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
    if [ "$DO_PACKAGES" = false ] && [ "$DO_SYMLINKS" = false ] && [ "$DO_FONTS" = false ]; then
        echo ""
        echo "Dotfiles Installer"
        echo "=================="
        echo ""
        echo "What would you like to do?"
        echo ""
        echo "  1) Install everything (packages + symlinks + fonts)"
        echo "  2) Create symlinks only"
        echo "  3) Install packages only"
        echo "  4) Install fonts only"
        echo "  5) Exit"
        echo ""
        read -p "Enter choice [1-5]: " choice

        case "$choice" in
            1)
                DO_PACKAGES=true
                DO_SYMLINKS=true
                DO_FONTS=true
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
        install_symlinks
    fi

    if [ "$DO_FONTS" = true ]; then
        install_fonts
    fi

    echo ""
    success "Done!"
}

main "$@"
