if status is-interactive
    # Commands to run in interactive sessions can go here
end
starship init fish | source
set -gx NVM_DIR  ~/.nvm
set -gx PATH $PATH ~/projects/Odin ~/.local/bin ~/.local/bin/yubico-authenticator ~/projects/ols  ~/.cargo/bin ~/.nvm /opt/IDriveForLinux/bin
set -gx ODIN_ROOT  ~/projects/Odin
set -gx EDITOR nvim
set -gx ENABLE_TOOL_SEARCH true
alias ll "eza --icons --color=always --color-scale=all -l --git"
alias c "claude-personal"
alias cw "claude-work"

set name_list $(string split "-" $(uname -r))

if string match -qi -- "WSL2" $name_list
    set -gx TERM xterm-256color
else
    set -gx TERM xterm-256color
end

# ~/.config/fish/functions/claude-personal.fish
function claude-personal
    env CLAUDE_CONFIG_DIR=$HOME/.claude $HOME/.local/bin/claude $argv
end

# ~/.config/fish/functions/claude-work.fish
function claude-work
    env CLAUDE_CONFIG_DIR=$HOME/.claude-work $HOME/.local/bin/claude $argv
end

function y
	set tmp (mktemp -t "yazi-cwd.XXXXXX")
	yazi $argv --cwd-file="$tmp"
	if set cwd (command bat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
		builtin cd -- "$cwd"
	end
	rm -f -- "$tmp"
end

#this is help obsidian cli see the flatpak
if set -q TMUX
    # Update environment variables from tmux
    for var in DBUS_SESSION_BUS_ADDRESS DISPLAY WAYLAND_DISPLAY
        set -l val (tmux show-environment | string match "$var=*" | string split -m1 =)[2]
        if test -n "$val"
            set -gx $var $val
        end
    end
end


# Added by LM Studio CLI (lms)
set -gx PATH $PATH /home/jgatkinsn/.lmstudio/bin
# End of LM Studio CLI section


# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

mise activate fish | source

# fzf (PatrickF1/fzf.fish handles key bindings: Ctrl+R history, Ctrl+Alt+F files, Ctrl+Alt+L git log, Ctrl+Alt+S git status)
set -gx FZF_DEFAULT_COMMAND "fd --hidden --follow --exclude .git"
set -gx FZF_DEFAULT_OPTS "--height 40% --layout=reverse --border --preview-window=right:60%:wrap"
set -gx fzf_fd_opts "--hidden --follow --exclude .git"
