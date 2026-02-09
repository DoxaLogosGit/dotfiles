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

cd "$TEMP_DIR"

# Download fonts
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

for font in "${FONTS[@]}"; do
    info "Downloading $font..."
    wget -q "https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/${font}.zip" -O "${font}.zip"
done

# Create directories
mkdir -p "$FONTS_DIR"
mkdir -p "$FONTCONFIG_DIR"

# Extract fonts
info "Extracting fonts..."
mkdir -p nerd-fonts
for font in "${FONTS[@]}"; do
    unzip -o "${font}.zip" -d nerd-fonts/ > /dev/null 2>&1
done

# Move font config files
if ls nerd-fonts/*.conf 1> /dev/null 2>&1; then
    mv nerd-fonts/*.conf "$FONTCONFIG_DIR/"
fi

# Move font files
mv nerd-fonts "$FONTS_DIR/nerd-fonts"

# Update font cache
info "Updating font cache..."
fc-cache -fv > /dev/null 2>&1

# Cleanup
cd -
rm -rf "$TEMP_DIR"

success "Fonts installed to $FONTS_DIR/nerd-fonts"
info "You may need to restart your terminal or applications to use the new fonts"
