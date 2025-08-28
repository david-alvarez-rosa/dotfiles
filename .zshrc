export ZSH="$XDG_DATA_HOME"/oh-my-zsh
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
)
DISABLE_UNTRACKED_FILES_DIRTY="true"
HYPHEN_INSENSITIVE="true"
source $ZSH/oh-my-zsh.sh

eval "$(starship init zsh)"

bindkey "\e[A" history-beginning-search-backward
bindkey "\e[B" history-beginning-search-forward
bindkey "\C-p" history-beginning-search-backward
bindkey "\C-n" history-beginning-search-forward

# vterm integration
vterm_printf() {
    if [ -n "$TMUX" ] && ([ "${TERM%%-*}" = "tmux" ] || [ "${TERM%%-*}" = "screen" ] ); then
        printf "\ePtmux;\e\e]%s\007\e\\" "$1"
    elif [ "${TERM%%-*}" = "screen" ]; then
        printf "\eP\e]%s\007\e\\" "$1"
    else
        printf "\e]%s\e\\" "$1"
    fi
}
if [[ "$INSIDE_EMACS" = 'vterm' ]]; then
    alias clear='vterm_printf "51;Evterm-clear-scrollback";tput clear'
fi
vterm_prompt_end() {
    vterm_printf "51;A$(whoami)@$(hostname):$(pwd)"
}
setopt PROMPT_SUBST
PROMPT=$PROMPT'%{$(vterm_prompt_end)%}'
vterm_prompt_end(){
    vterm_printf "51;A$(whoami)@$(hostname):$(pwd)"
}

alias cpc="xclip -selection clipboard"
alias yt="youtube-dl --add-metadata -ic --output \"%(uploader)s%(title)s.%(ext)s\""
alias yta="yt -x -f bestaudio/best" # Download only audio
alias ls="ls --color=auto --group-directories-first"
alias l="ls -N"
alias ll="ls -lahN"
