# Dotfiles

Personal dotfiles for setting up a new development environment.

## Quick Start

```bash
# One-liner: clone and install
git clone git@github.com:DoxaLogosGit/dotfiles.git ~/.dotfiles && ~/.dotfiles/install.sh
```

## Installation Options

The installer supports several modes:

```bash
./install.sh --all          # Full installation (packages + symlinks + fonts)
./install.sh --packages     # Install system packages only
./install.sh --symlinks     # Create config symlinks only
./install.sh --fonts        # Install nerd fonts only
./install.sh --dry-run      # Preview changes without making them
```

Or run interactively:
```bash
./install.sh                # Shows interactive menu
```

## What's Included

### Shells
- **Fish** - Primary shell with starship prompt
- **Nushell** - Modern shell alternative
- **Zsh** - Legacy configuration

### Editors
- **Neovim** - Primary editor with lazy.nvim plugin manager
- **Vim** - Classic configuration

### Terminal Tools
- **tmux** - Terminal multiplexer with TPM for plugins
- **yazi** - Terminal file manager
- **starship** - Cross-shell prompt

### Other Configs
- **git** - Global git configuration
- **ghostty** - Terminal emulator settings
- **pylint** - Python linting configuration
- **claude** - Claude Code CLI customizations

## Directory Structure

```
~/.dotfiles/
├── install.sh                    # Main bootstrap script
├── scripts/
│   ├── packages-debian.sh        # Debian/Ubuntu package installation
│   ├── packages-fedora.sh        # Fedora/RHEL package installation
│   └── fonts.sh                  # Nerd fonts installation
├── fish/
│   └── config.fish               # → ~/.config/fish/config.fish
├── starship/
│   └── starship.toml             # → ~/.config/starship.toml
├── nvim/
│   ├── init.lua                  # → ~/.config/nvim/init.lua
│   ├── lazy-lock.json            # → ~/.config/nvim/lazy-lock.json
│   ├── colors/                   # → ~/.config/nvim/colors/
│   └── autoload/                 # → ~/.config/nvim/autoload/
├── vim/
│   └── vimrc                     # → ~/.vimrc
├── tmux/
│   └── tmux.conf                 # → ~/.tmux.conf
├── ghostty/
│   └── config                    # → ~/.config/ghostty/config
├── yazi/
│   ├── yazi.toml                 # → ~/.config/yazi/yazi.toml
│   ├── keymap.toml               # → ~/.config/yazi/keymap.toml
│   └── theme.toml                # → ~/.config/yazi/theme.toml
├── git/
│   └── gitconfig                 # → ~/.gitconfig
├── nushell/
│   └── config.nu                 # → ~/.config/nushell/config.nu
├── zsh/
│   └── zshrc                     # → ~/.zshrc
├── python/
│   └── pylintrc                  # → ~/.pylintrc
└── claude/
    ├── settings.json             # → ~/.claude/settings.json
    └── scripts/
        └── context-bar.sh        # → ~/.claude/scripts/context-bar.sh
```

## Post-Installation

### Set Fish as Default Shell
```bash
chsh -s /usr/bin/fish
```

### Install Tmux Plugins
After starting tmux, press `prefix + I` (that's `Ctrl-A` then `Shift-I`) to install plugins via TPM.

### Neovim Plugins
Plugins are managed by lazy.nvim and will auto-install on first launch.

## Supported Systems

- **Debian/Ubuntu** and derivatives
- **Fedora/RHEL** and derivatives

## License

BSD 2-Clause License - see [LICENSE](LICENSE) for details.
