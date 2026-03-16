#!/bin/bash
#
# Nerd Fonts installation script
# Called by install.sh
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

FONTS_DIR="$HOME/.local/share/fonts"
FONTCONFIG_DIR="$HOME/.local/share/fontconfig/conf.avail"
TEMP_DIR=$(mktemp -d)

info "Downloading Nerd Fonts from https://www.nerdfonts.com/font-downloads"
warning "If installing on WSL, fonts need to be installed on Windows and configured in the terminal profile"

# Create directories
mkdir -p "$FONTS_DIR/nerd-fonts"
mkdir -p "$FONTCONFIG_DIR"

FONT_VERSION="v3.4.0"
FONTS=(
    "Ubuntu"
    "UbuntuMono"
    "NerdFontsSymbolsOnly"
    "JetBrainsMono"
    "FiraMono"
    "FiraCode"
    "AdwaitaMono"
)

# Download, extract, and clean up one font at a time to keep /tmp usage low
for font in "${FONTS[@]}"; do
    info "Installing $font..."
    wget -q "https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/${font}.zip" -O "$TEMP_DIR/${font}.zip"
    unzip -o "$TEMP_DIR/${font}.zip" -d "$TEMP_DIR/extract/" > /dev/null 2>&1
    rm -f "$TEMP_DIR/${font}.zip"
    # Move conf files if any
    find "$TEMP_DIR/extract/" -name "*.conf" -exec mv {} "$FONTCONFIG_DIR/" \; 2>/dev/null || true
    # Move font files
    find "$TEMP_DIR/extract/" -name "*.ttf" -o -name "*.otf" | xargs -I{} mv {} "$FONTS_DIR/nerd-fonts/" 2>/dev/null || true
    rm -rf "$TEMP_DIR/extract/"
done

# Update font cache
info "Updating font cache..."
fc-cache -fv > /dev/null 2>&1

# Cleanup
rm -rf "$TEMP_DIR"

success "Fonts installed to $FONTS_DIR/nerd-fonts"
info "You may need to restart your terminal or applications to use the new fonts"
