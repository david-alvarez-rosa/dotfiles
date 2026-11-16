[[ $TERM == "dumb" ]] && unsetopt zle && PS1="$ " && return

export ZSH=$XDG_DATA_HOME/oh-my-zsh
plugins=()
export ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION"
ZSH_DISABLE_COMPFIX="true"
zstyle ':omz:update' mode disabled
HYPHEN_INSENSITIVE="true"
source $ZSH/oh-my-zsh.sh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

eval "$(starship init zsh)"

bindkey "\C-p" history-beginning-search-backward
bindkey "\C-n" history-beginning-search-forward

# ghostel integration
if [[ "${INSIDE_EMACS%%,*}" = "ghostel" ]]; then
    alias man="ghostel_cmd man"
    open() {
        ghostel_cmd find-file "$(realpath "${@:-.}")"
    }
fi

alias cpc="xclip -selection clipboard"
alias ls="ls --color=auto --group-directories-first"
alias l="ls -N"
alias ll="ls -lahN"
alias claude="claude --dangerously-skip-permissions"

source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
