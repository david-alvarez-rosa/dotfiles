[[ $TERM == "dumb" ]] && unsetopt zle && PS1="$ " && return

export ZSH=$XDG_DATA_HOME/oh-my-zsh
export ZSH_CUSTOM=$XDG_DATA_HOME/oh-my-zsh-custom
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
)
fpath+=$ZSH_CUSTOM/plugins/zsh-completions/src
export ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION"
ZSH_DISABLE_COMPFIX="true"
autoload -U compinit && compinit -u -d "$ZSH_COMPDUMP"
DISABLE_UNTRACKED_FILES_DIRTY="true"
HYPHEN_INSENSITIVE="true"
source $ZSH/oh-my-zsh.sh

eval "$(starship init zsh)"

bindkey "\e[A" history-beginning-search-backward
bindkey "\e[B" history-beginning-search-forward
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
