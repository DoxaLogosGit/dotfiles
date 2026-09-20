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
- **Zsh** - Primary shell (oh-my-zsh + autosuggestions/syntax-highlighting,
  starship/atuin/zoxide/mise integrations, fzf key bindings)
- **Bash** - Bash configuration with aliases
- **Nushell** - Modern shell alternative (Linux)

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
- **opencode** - OpenCode CLI configuration
- **codex** - OpenAI Codex CLI configuration
- **pi** - Pi coding agent configuration (`~/.pi/agent`)
- **tallow** - Tallow coding agent settings
- **herdr** - Herdr terminal multiplexer settings
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
│   ├── packages-macos.sh         # macOS package installation (Homebrew)
│   ├── install-homebrew.sh       # macOS: arch-detect prefix + bootstrap Homebrew
│   ├── install-global-packages.sh # Node.js (nvm), bun, Rust, and global CLI tools
│   └── fonts.sh                  # Nerd fonts installation
├── zsh/
│   └── zshrc                     # → ~/.zshrc  (primary shell config)
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
│   ├── gitconfig                 # → ~/.gitconfig (portable settings)
│   └── gitconfig.local.example   # → ~/.gitconfig.local (per-machine, untracked)
├── nushell/
│   └── config.nu                 # → ~/.config/nushell/config.nu
├── python/
│   └── pylintrc                  # → ~/.pylintrc
├── bash/
│   ├── bashrc                    # → ~/.bashrc
│   └── bash_profile              # → ~/.bash_profile
├── htop/                         # → ~/.config/htop/
├── btop/                         # → ~/.config/btop/
├── ollama/
│   └── modelfiles/               # Ollama Modelfiles for local models
├── pi/                           # → ~/.pi/agent/ (pi coding agent)
│   ├── models.json               #   provider config
│   ├── open-tui.json             #   UI preferences
│   ├── extensions/, skills/      #   tracked extensions and skills
│   └── (settings.json untracked) #   per-machine; see install-pi-packages.sh
├── tallow/
│   ├── models.json               # → ~/.tallow/models.json
│   └── settings.json             # → ~/.tallow/settings.json
├── herdr/
│   └── config.toml               # → ~/.config/herdr/config.toml
├── vscode/
│   └── settings.json             # → ~/.config/Code/User/settings.json
├── opencode/
│   └── opencode.json             # → ~/.config/opencode/opencode.json
└── claude/
    ├── settings.json             # → ~/.claude/settings.json
    └── scripts/
        └── context-bar.sh        # → ~/.claude/scripts/context-bar.sh
```

## Post-Installation

### Set Zsh as Default Shell (Linux)
```bash
chsh -s /usr/bin/zsh
```
macOS already defaults to zsh — nothing to do there.

Shell helpers defined in `zsh/zshrc`: `ll`, `c` / `cw` (Claude personal/work
config dirs), `y` (yazi, cd on exit), `zm` / `zw` (attach named zellij
sessions), `zdump` (dump the attached session's layout).

Machine-local additions that shouldn't be committed go in `~/.zshrc.local`,
which `zshrc` sources last if present.

### Machine-Local Config

Two files hold per-machine settings and are deliberately **not** tracked:

- `~/.gitconfig.local` — `user.email` and `credential.helper`. Seeded from
  `git/gitconfig.local.example` on install; edit it for the machine
  (libsecret on Linux, osxkeychain on macOS). The tracked `git/gitconfig`
  pulls it in with `[include]` and falls back to its own defaults if absent.
- `~/.pi/agent/settings.json` — pi's provider/model choice and runtime
  state. The package list that matters lives in
  `scripts/install-pi-packages.sh`; run it with `--personal` (or set
  `DOTFILES_PERSONAL=1`) to also install free-tier routing, which work
  machines should skip.

### Install Tmux Plugins
After starting tmux, press `prefix + I` (that's `Ctrl-A` then `Shift-I`) to install plugins via TPM.

### Neovim Plugins
Plugins are managed by lazy.nvim and will auto-install on first launch.

## Supported Systems

- **Debian/Ubuntu** and derivatives
- **Fedora/RHEL** and derivatives
- **Raspberry Pi OS (Raspbian)**
- **macOS** (Apple Silicon or Intel) — installs everything via Homebrew.
  Differences from the Linux installs: shell setup targets zsh (already the
  macOS default) with oh-my-zsh and does not install nushell, the
  `zellij-snapshot` timer is not set up (macOS has no systemd; the
  snapshot/restore scripts are still linked for manual use), and GUI apps
  install as Homebrew casks (Ghostty, Nerd Fonts) except VS Code, which is
  assumed installed separately — only its config is linked.

## License

BSD 2-Clause License - see [LICENSE](LICENSE) for details.
