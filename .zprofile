# C/C++ compiler
export CC=clang
export CXX=clang++

# Language
export LC_CTYPE="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"

# GPG
export GPG_TTY=$(tty)

# XDG
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export LESSHISTFILE=-
export HISTFILE="$XDG_DATA_HOME"/shell/history
export INPUTRC="$XDG_CONFIG_HOME"/shell/inputrc
export UNISON="$XDG_CONFIG_HOME"/unison
export XAUTHORITY="$XDG_RUNTIME_DIR"/Xauthority
export XINITRC="$XDG_CONFIG_HOME"/X11/xinitrc
export GNUPGHOME="$XDG_DATA_HOME"/gnupg
export PYTHONHISTFILE="$XDG_DATA_HOME"/python/python_history

# Basic
export EDITOR="nvim"
export TERMINAL="st"
export BROWSER="firefox"
export TERM=xterm-256color

# Path
export PATH="$PATH:$HOME/.local/bin"
export MANPATH="/usr/local/man:$MANPATH"

# Start i3 in tty1
if [ "$(tty)" = "/dev/tty1" ]; then
    pgrep -x i3 || exec startx "$XINITRC"
fi
