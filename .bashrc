case $- in
    *i*) ;;
    *) return;;
esac

shopt -s autocd

shopt -s checkwinsize

shopt -s globstar

complete -c man which whereis
complete -cf sudo

PATH="$PATH:$HOME/.local/bin/global"

if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

if [ "$EUID" -ne 0 ]
then
    export PS1="\[$(tput bold)\]\[$(tput setaf 1)\][\[$(tput setaf 3)\]\u\[$(tput setaf 2)\]@\[$(tput setaf 4)\]\h\[$(tput setaf 7)\] Arch Linux  \[$(tput setaf 5)\]\w\[$(tput setaf 1)\]]\[$(tput setaf 7)\]\n  \\$ \[$(tput sgr0)\]"
else
    export PS1="\[$(tput bold)\]\[$(tput setaf 1)\][\[$(tput setaf 3)\]ROOT\[$(tput setaf 2)\]@\[$(tput setaf 4)\]$(hostname | awk '{print toupper($0)}')\[$(tput setaf 7)\] Arch Linux  \[$(tput setaf 5)\]\w\[$(tput setaf 1)\]]\[$(tput setaf 7)\]\n  \\$ \[$(tput sgr0)\]"
fi

export HISTCONTROL=ignoreboth
shopt -s histappend
export HISTSIZE=5000
export HISTFILESIZE=5000

# Colores
eval "$(dircolors)"
alias ls="ls -hN --color=auto --group-directories-first -v --time-style='+%d %b %H:%M'"
alias l="exa --icons --group-directories-first"
alias ll="l -lag"
alias grep="grep --color"
alias diff="diff --color"

alias sp-Syu="sp -Syu --noconfirm && pkill -RTMIN+1 i3blocks"
alias ..='cd ..'
alias ...='cd ../../'
alias mv="mv -i"
alias cp="cp -i"

alias cpc="xclip -selection clipboard"
alias yt="youtube-dl --add-metadata -ic --output \"%(uploader)s%(title)s.%(ext)s\"" # Download video link
alias yta="yt -x -f bestaudio/best" # Download only audio

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share/"

export LESSHISTFILE=-
export HISTFILE="$XDG_DATA_HOME"/history
export INPUTRC="$XDG_CONFIG_HOME"/shell/inputrc
export UNISON="$XDG_CONFIG_HOME"/unison
export XAUTHORITY="$XDG_RUNTIME_DIR"/Xauthority
export XINITRC="$XDG_CONFIG_HOME"/X11/xinitrc
export GNUPGHOME="$XDG_DATA_HOME"/gnupg

[ -x "$(command -v nvim)" ] && alias vim="nvim" vimdiff="nvim -d"

export EDITOR="nvim"
export TERMINAL="alacritty"
export BROWSER="firefox"
