[[ $TERM == "dumb" ]] && unsetopt zle && PS1='$ ' && return

# GPG
export GPG_TTY=$(tty)

# Basic
export TERM=xterm-256color

# Start i3 in tty1
if [ "$(tty)" = "/dev/tty1" ]; then
    pgrep -x i3 || exec startx "$XINITRC"
fi
