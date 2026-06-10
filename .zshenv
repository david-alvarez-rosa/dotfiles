# Avoid duplicate entries (this file runs for every zsh, including nested ones)
typeset -U path manpath

# C/C++ compiler
export CC=clang
export CXX=clang++

# Language
export LC_CTYPE="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"

# XDG
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export ZDOTDIR="$XDG_CONFIG_HOME"/zsh
export LESSHISTFILE=-
export HISTFILE="$XDG_DATA_HOME"/shell/history
export INPUTRC="$XDG_CONFIG_HOME"/shell/inputrc
export UNISON="$XDG_CONFIG_HOME"/unison
export XAUTHORITY="$XDG_RUNTIME_DIR"/Xauthority
export XINITRC="$XDG_CONFIG_HOME"/X11/xinitrc
export GNUPGHOME="$XDG_DATA_HOME"/gnupg
export PYTHON_HISTORY="$XDG_STATE_HOME"/python/history
export SQLITE_HISTORY="$XDG_STATE_HOME"/sqlite_history
export CARGO_HOME="$XDG_DATA_HOME"/cargo
export CONAN_HOME="$XDG_DATA_HOME"/conan2
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME"/npm
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME"/npm/npmrc
export AWS_CONFIG_FILE="$XDG_CONFIG_HOME"/aws/config
export AWS_SHARED_CREDENTIALS_FILE="$XDG_CONFIG_HOME"/aws/credentials
export ANDROID_USER_HOME="$XDG_DATA_HOME"/android
export IPYTHONDIR="$XDG_CONFIG_HOME"/ipython
export JUPYTER_PLATFORM_DIRS=1
export JUPYTER_CONFIG_DIR="$XDG_CONFIG_HOME"/jupyter
export KERAS_HOME="$XDG_CACHE_HOME"/keras
export EASYOCR_MODULE_PATH="$XDG_DATA_HOME"/easyocr
export PERF_BUILDID_DIR="$XDG_CACHE_HOME"/perf-debug
export SCREENRC="$XDG_CONFIG_HOME"/screen/screenrc
export SCREENDIR="$XDG_RUNTIME_DIR"/screen
export TEXMFHOME="$XDG_DATA_HOME"/texmf
export TEXMFVAR="$XDG_CACHE_HOME"/texlive/texmf-var
export TEXMFCONFIG="$XDG_CONFIG_HOME"/texlive/texmf-config
export CLAUDE_CONFIG_DIR="$XDG_CONFIG_HOME"/claude

# Basic
export EDITOR="nvim"
export TERMINAL="st"
export BROWSER="firefox"

# Path
export PATH="$PATH:$HOME/.local/bin"
export MANPATH="/usr/local/man:$MANPATH"
