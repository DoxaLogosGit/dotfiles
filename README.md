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
- **Bash** - Bash configuration with aliases
- **Nushell** - Modern shell alternative
- **Zsh** - Legacy configuration

### Editors
- **Neovim** - Primary editor with lazy.nvim plugin manager
- **Vim** - Classic configuration

### Terminal Tools
- **zellij** - Terminal multiplexer with custom layouts and keybindings
- **tmux** - Terminal multiplexer with TPM for plugins
- **yazi** - Terminal file manager
- **starship** - Cross-shell prompt
- **htop** - Interactive process viewer
- **btop** - Resource monitor

### AI / Coding Agents
- **claude** - Claude Code CLI customizations
- **gemini** - Gemini CLI settings
- **opencode** - OpenCode CLI configuration
- **codex** - OpenAI Codex CLI configuration
- **pi** - Pi coding agent configuration (`~/.pi/agent`)
- **tallow** - Tallow coding agent settings
- **ollama** - Local model files and Modelfiles for Ollama (omnicoder, qwen3.5:9b)

### Other Configs
- **git** - Global git configuration
- **ghostty** - Terminal emulator settings
- **pylint** - Python linting configuration
- **vscode** - Visual Studio Code settings

## Directory Structure

```
~/.dotfiles/
├── install.sh                    # Main bootstrap script
├── scripts/
│   ├── packages-debian.sh        # Debian/Ubuntu package installation
│   ├── packages-fedora.sh        # Fedora/RHEL package installation
│   ├── packages-raspbian.sh      # Raspberry Pi / Raspbian package installation
│   ├── install-global-packages.sh # Node.js (nvm), bun, Rust, and global CLI tools
│   └── fonts.sh                  # Nerd fonts installation
├── fish/
│   ├── config.fish               # → ~/.config/fish/config.fish
│   ├── fish_plugins              # → ~/.config/fish/fish_plugins
│   └── functions/                # → ~/.config/fish/functions/
│       ├── zeldump.fish          #   dump current zellij session
│       ├── zm.fish               #   attach/create named zellij session
│       └── zw.fish               #   switch zellij session
├── zellij/
│   ├── config.kdl                # → ~/.config/zellij/config.kdl
│   └── layouts/
│       ├── main.kdl              #   default layout
│       └── work.kdl              #   work layout
├── starship/
│   └── starship.toml             # → ~/.config/starship.toml
├── nvim/
│   ├── init.lua                  # → ~/.config/nvim/init.lua
│   ├── lazy-lock.json            # → ~/.config/nvim/lazy-lock.json
│   └── colors/                   # → ~/.config/nvim/colors/
├── vim/
│   └── vimrc                     # → ~/.vimrc
├── tmux/
│   └── tmux.conf                 # → ~/.tmux.conf
├── ghostty/                      # → ~/.config/ghostty/
├── yazi/                         # → ~/.config/yazi/
├── git/
│   └── gitconfig                 # → ~/.gitconfig
├── nushell/
│   └── config.nu                 # → ~/.config/nushell/config.nu
├── zsh/
│   └── zshrc                     # → ~/.zshrc
├── python/
│   └── pylintrc                  # → ~/.pylintrc
├── bash/
│   ├── bashrc                    # → ~/.bashrc
│   └── bash_profile              # → ~/.bash_profile
├── htop/                         # → ~/.config/htop/
├── btop/                         # → ~/.config/btop/
├── ollama/
│   └── modelfiles/               # Ollama Modelfiles for local models
├── pi/
│   └── settings.json             # → ~/.pi/agent/ (pi coding agent)
├── tallow/
│   ├── models.json               # → ~/.tallow/models.json
│   └── settings.json             # → ~/.tallow/settings.json
├── vscode/
│   └── settings.json             # → ~/.config/Code/User/settings.json
├── opencode/
│   └── opencode.json             # → ~/.config/opencode/opencode.json
├── gemini/
│   └── settings.json             # → ~/.gemini/settings.json
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
- **Raspberry Pi OS (Raspbian)**

## License

BSD 2-Clause License - see [LICENSE](LICENSE) for details.
