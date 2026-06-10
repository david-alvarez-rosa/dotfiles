[[ $TERM == "dumb" ]] && unsetopt zle && PS1='$ ' && return

# GPG
export GPG_TTY=$(tty)

# Basic
export TERM=xterm-256color
export QT_AUTO_SCREEN_SCALE_FACTOR=1

# Start i3 in tty1
if [ "$(tty)" = "/dev/tty1" ]; then
    pgrep -x i3 || exec startx "$XINITRC"
fi
