eval "$(/opt/homebrew/bin/brew shellenv)"

# MacPorts Installer addition
export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
export MANPATH="/opt/local/share/man:$MANPATH"

# Added by Toolbox App
export PATH="$PATH:/usr/local/bin"

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
export XDG_DATA_HOME="$HOME/.local/share/"
