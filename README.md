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
│   ├── export-system-ca.sh       # macOS: export keychain CAs for Node/AWS/Python
│   └── fonts.sh                  # Nerd fonts installation
├── zsh/
│   ├── zshrc                     # → ~/.zshrc  (primary shell config)
│   └── zshrc.local.example       # → ~/.zshrc.local (per-machine, untracked)
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
│   ├── vimrc                     # → ~/.vimrc
│   └── vimrc.local.example       # → ~/.vimrc.local (per-machine, untracked)
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
│   ├── models.json.example       #   template for the untracked models.json
│   ├── open-tui.json             #   UI preferences
│   ├── extensions/, skills/      #   tracked extensions and skills
│   └── (models.json,             #   per-machine: internal endpoints and
│        settings.json untracked) #   model access; see install-pi-packages.sh
├── herdr/
│   └── config.toml               # → ~/.config/herdr/config.toml
├── vscode/
│   └── settings.json             # → ~/.config/Code/User/settings.json
├── opencode/                     # untracked: internal endpoints + model access
│   └── (opencode.json)           # → ~/.config/opencode/opencode.json
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
config dirs), `y` (yazi, cd on exit), `zm` (attach the MAIN zellij session),
`zdump` (dump the attached session's layout).

Machine-local additions that shouldn't be committed go in `~/.zshrc.local`,
which `zshrc` sources last if present — see
[Machine-Local Config](#machine-local-config).

### Machine-Local Config

Anything machine-specific stays out of this repo: identity, credentials,
employer details, internal API endpoints and per-account model access. This
repo is public.

Five files hold that state and are deliberately **not** tracked. `install.sh`
seeds each one from a tracked `*.example` and never overwrites an existing file,
so re-running the installer is safe.

| File | Holds | Seeded from |
| --- | --- | --- |
| `~/.gitconfig.local` | `user.email`, `credential.helper` | `git/gitconfig.local.example` |
| `~/.zshrc.local` | credentials, API keys, `AWS_PROFILE` | `zsh/zshrc.local.example` |
| `~/.vimrc.local` | `g:C_Email`, `g:C_Company` | `vim/vimrc.local.example` |
| `pi/models.json` | provider endpoints and model catalogs | `pi/models.json.example` |
| `opencode/opencode.json` | gateway URL, model catalogue, permissions | `opencode/opencode.json.example` |

Each is sourced or included last, so it overrides the shared config above it.
All five can instead be supplied by a
[Machine-Local Overlay](#machine-local-overlay), which is how they get backed up.

On a fresh install, edit all four:

```bash
$EDITOR ~/.gitconfig.local   # email; libsecret on Linux, osxkeychain on macOS
$EDITOR ~/.zshrc.local       # API keys, AWS_PROFILE
$EDITOR ~/.vimrc.local       # employer and work email for file templates
$EDITOR ~/.dotfiles/pi/models.json
```

Verify the git identity resolves from the local file, not the tracked one:

```bash
git config --show-origin --get user.email
```

Two more untracked paths that need no seeding:

- `~/.pi/agent/settings.json` — pi's provider/model choice and runtime state.
  The package list that matters lives in `scripts/install-pi-packages.sh`; run
  it with `--personal` (or set `DOTFILES_PERSONAL=1`) to also install free-tier
  routing, which work machines should skip.
- `~/.config/zellij/layouts/` — zellij layouts embed absolute `cwd` paths and
  per-machine commands, so they do not survive a move between machines. Only
  `zellij/config.kdl` is shared and symlinked; the layouts directory is real and
  local. `zdump` writes the attached session's layout there.

**Why `pi/models.json` and `opencode.json` are fully local rather than split:**
pi reads exactly one `models.json` and has no include mechanism, so a portable
half and a local half cannot coexist. Both files mix provider endpoints with
model lists, so the entire file has to be local. The whole `opencode/` directory
is therefore gitignored apart from the template.

### Machine-Local Overlay

The files above are untracked, which also means they are **unbacked**. Losing
`pi/models.json` means rebuilding a model catalogue by hand. An optional overlay
gives those files somewhere to live without putting them in this repo.

An overlay is a directory whose layout mirrors this repo. When present, its
copies win:

```
~/.dotfiles-local/
  zsh/zshrc.local         # credentials, API keys, AWS_PROFILE
  git/gitconfig.local     # email, credential helper
  vim/vimrc.local         # employer, work email
  pi/models.json          # this machine's model catalogue
  opencode/opencode.json  # gateway URL, model catalogue, permissions
  claude/settings.json    # omit on machines where Claude cannot be installed
  herdr/config.toml       # per-machine keybinds, overrides the shared config
  zellij/layouts/*.kdl    # layouts dumped on this machine
```

`claude/settings.json` is tracked and shared by default, since it holds only
portable preferences. An overlay copy wins where a machine needs to diverge —
useful where Claude Code cannot be installed at all.

`install.sh` links whatever it finds and falls back to the tracked defaults for
everything else, so a partial overlay is fine. Override the location with
`DOTFILES_OVERLAY=/path ./install.sh --symlinks`.

Adopting an overlay on a machine that already has real `~/.zshrc.local` and
friends is safe: each existing file is copied to
`~/.dotfiles-backup/<timestamp>/` before the symlink replaces it.

#### One repo, several machines

Machines that share a security boundary — your own devices on your own network —
belong in one overlay repo with a directory per machine. Splitting them buys no
isolation you do not already have, and the shared files drift apart.

```
~/.dotfiles-<overlay-repo>/
  common/gitconfig.local        # personal email + helper, stored once
  common/vimrc.local
  laptop/  zsh/ git/ vim/ pi/ herdr/ zellij/layouts/
  nas/     zsh/ git/ vim/ zellij/layouts/
  pihole/  zsh/ git/
```

Files that are identical everywhere live once in `common/`, with a relative
symlink from each machine directory:

```bash
cd ~/.dotfiles-<overlay-repo>/laptop/git
ln -s ../../common/gitconfig.local gitconfig.local
```

Git stores those as symlinks (mode `120000`) sharing one blob, so editing
`common/` updates every machine with no duplication.

Point `~/.dotfiles-local` at this machine's directory. `install.sh` follows the
symlink, so there is no environment variable to set or remember:

```bash
# Clone into a directory named for the repo, so the two never drift apart.
git clone <private-overlay-repo> ~/.dotfiles-<overlay-repo>
ln -sfn ~/.dotfiles-<overlay-repo>/laptop ~/.dotfiles-local
./install.sh --symlinks
```

Because every linked file resolves *through* that one symlink, repointing it
switches the whole set at once, with no reinstall:

```bash
ln -sfn ~/.dotfiles-<overlay-repo>/nas ~/.dotfiles-local
```

Use `ln -sfn`, not `ln -sf`. Without `-n`, when the symlink already exists and
points at a directory, `ln` creates the new link *inside* that directory instead
of replacing it.

> Repointing to a machine directory that lacks a file leaves a **dangling
> symlink**: `~/.dotfiles/pi/models.json` still resolves through
> `~/.dotfiles-local`, which no longer has a `pi/` directory. Re-run
> `./install.sh --symlinks` after repointing, which re-seeds from `*.example`
> wherever the new overlay has no copy.

**An overlay is a backup, not a vault.** `zshrc.local` can hold live
credentials, so whatever hosts the overlay must be at least as private as the
values inside it. Nothing here encrypts anything.

**Overlays are deliberately anonymous.** This repo asks only whether one exists,
never where it came from. Keep each machine class on its own host and network:
personal devices in one private repo, employer-provided equipment in whatever
that employer hosts. Do not create an overlay spanning two of them — a work
gateway hostname does not belong in a personal account, and a GFE box may not be
able to reach a public host at all.

With no overlay, behaviour is exactly as it was before overlays existed:
templates are seeded from `*.example` and nothing else changes.

> A `.gitignore` entry does **not** protect a file that is already tracked. If
> you add config that must stay local, check it with
> `git check-ignore -v <path>`, and if it is already tracked run
> `git rm --cached <path>` to untrack it while keeping it on disk.

### Install Manifest

Which machine gets which tools is data, not code. Each machine directory in the
overlay carries a `manifest.conf` naming every tool and what to do with it:

```ini
zellij = no          # skip the package and the config
nvim   = config-only # link the config; installed some other way
tmux   = yes         # install and link
```

An entry covers everything belonging to that tool, not just its package:
`tmux = no` also skips the TPM clone and the `tmux.conf` symlink.

You name the **tool**, never the mechanism. `scripts/tools.tsv` holds what each
tool *is* on each OS — `cargo:zellij` on Fedora, `brew:zellij` on macOS, `-` on
Raspbian, which ships no such package — so `zellij = no` reads the same
everywhere and a `-` needs no line at all.

**The rules:**

- **No manifest → everything installs**, exactly as before manifests existed.
- **With a manifest, a tool left out is skipped** and named in the run summary,
  so an omission is visible rather than silent.
- **An unknown key is an error**, naming the file and line, before anything is
  written. A typo like `ghosty = yes` cannot quietly mean "skip ghostty".

Every run ends with what happened:

```
Manifest: ~/.dotfiles-local/manifest.conf (53 yes, 19 no, 0 config-only)
  skipped: zellij rust herdr tudiff tuicr atuin ...
```

**Availability versus policy.** A tool can be absent for two different reasons,
and they live in different files. *Availability* is a `-` in the table: Raspbian
has no `zellij` package, and no machine should have to say so. *Policy* is a
`no` in a manifest: the work MacBook declines Claude Code because the company
image blocks Anthropic — a fact about that machine, not about macOS, since a
personal Mac would install it fine.

The two non-default machines are mirror images, which is the clearest argument
for naming tools rather than branching on OS:

| | Pi | MacBook |
|---|---|---|
| `tmux` | `yes` | `no` |
| `zellij` | `no` | `yes` |

Same mechanism, opposite answers, no code branch for either. Under the previous
design each would have needed its own hardcoded symlink function.

#### WSL

A WSL instance detects as whatever distribution it runs — a Fedora WSL is
`OS_TYPE=fedora` and installs through `packages-fedora.sh` — so nothing about
the package side is special. What differs is that the graphical half of the
machine lives on the Windows side, which is four manifest lines:

```ini
ghostty = no    # the terminal runs on Windows; only its config would be linked here
vscode  = no    # VS Code runs on Windows and edits through the WSL remote extension
fonts   = no    # fonts are installed on Windows and set in the terminal profile
systemd = no    # unless enabled in /etc/wsl.conf, WSL has no systemd to install units into
```

Each of those is a per-machine decision rather than a platform fact, which is
why they belong in the manifest and not in a WSL branch in `install.sh`: a WSL
instance with systemd enabled in `/etc/wsl.conf` should say `systemd = yes`,
and WSLg can run graphical applications if you want them.

Add whatever else that machine declines — a work instance behind a proxy that
blocks a provider sets `claude = no` for the same reason the work MacBook does.

**Adding a tool:** add one row to `scripts/tools.tsv`, then run
`scripts/gen-manifest-example.sh`. A test fails if the committed
`manifest.example` has fallen behind the table. The new tool then shows up as a
visible skip on every machine until its manifest says otherwise.

### macOS: corporate TLS interception

If TLS is intercepted on the network, Node, Python and the AWS CLI fail with
`unable to get local issuer certificate`. They ship their own root stores and
ignore the macOS keychain, so `curl` and Safari work while `aws` and agent CLIs
do not.

Export the keychain trust store once:

```bash
./scripts/export-system-ca.sh
```

`zsh/zshrc` detects the resulting bundle on Darwin and exports
`NODE_EXTRA_CA_CERTS`, `AWS_CA_BUNDLE` and `REQUESTS_CA_BUNDLE`. Re-run the
script if the proxy CA is rotated.

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
