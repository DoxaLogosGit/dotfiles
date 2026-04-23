function zdump
    zellij action dump-layout > ~/.dotfiles/zellij/layouts/(zellij list-sessions | grep ATTACHED | awk '{print $1}').kdl
end
