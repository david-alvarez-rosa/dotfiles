# Archivo de configuración de bash.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
    *) return;;
esac

# No poner lineas duplicadas o empezando con un espacio en la historia.
export HISTCONTROL=ignoreboth
# Añadir al archivo de historia, no sobreescribir.
shopt -s histappend
# Tamaños máximos de la historia.
export HISTSIZE=5000
export HISTFILESIZE=5000
# Definición de variables.
export BROWSER="qutebrowser"


# Configuración de "Bash prompt".
if [ "$EUID" -ne 0 ]
then export PS1="\[$(tput bold)\]\[$(tput setaf 1)\][\[$(tput setaf 3)\]\u\[$(tput setaf 2)\]@\[$(tput setaf 4)\]\h\[$(tput setaf 7)\] Arch Linux  \[$(tput setaf 5)\]\w\[$(tput setaf 1)\]]\[$(tput setaf 7)\]\n  \\$ \[$(tput sgr0)\]"
else export PS1="\[$(tput bold)\]\[$(tput setaf 1)\][\[$(tput setaf 3)\]ROOT\[$(tput setaf 2)\]@\[$(tput setaf 4)\]$(hostname | awk '{print toupper($0)}')\[$(tput setaf 7)\] Arch Linux  \[$(tput setaf 5)\]\w\[$(tput setaf 1)\]]\[$(tput setaf 7)\]\n  \\$ \[$(tput sgr0)\]"
fi

# # Configuración de "powerline" (solo en emulador).
# if [ "$TERM" == "st-256color" ]; then
#     powerline-daemon -q
#     POWERLINE_BASH_CONTINUATION=1
#     POWERLINE_BASH_SELECT=1
#     . /usr/share/powerline/bindings/bash/powerline.sh
# fi

# Permitir acceder a una carpeta escribiendo el nombre.
shopt -s autocd

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# Mejora (globstar matching).
shopt -s globstar


# Completar también con los siguientes comandos.
complete -c man which whereis
complete -cf sudo

# Cambiar la variable "PATH".
PATH="$PATH:/usr/local/AMPL/:/usr/local/AMPL/amplide:/home/david/.scripts/global"

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# "Mejorar" los colores de listado.
eval "$(dircolors)"

# Algunos alias básicos.
alias ls="ls -hN --color=auto --group-directories-first -v --time-style='+%d %b %H:%M'"
alias ll="ls -la"
alias l="ls"
alias grep="grep --color"
alias diff="diff --color"
alias p="pacman"
alias sp="sudo pacman"
alias sp-Syu="sp -Syu --noconfirm && pkill -RTMIN+1 i3blocks"
alias sc="systemctl"
alias ssc="sudo systemctl"
alias ..='cd ..'
alias ...='cd ../../../'
alias hg="history | grep"

# Más alias.
alias q="qutebrowser &"
alias f="firefox &"
alias e="emacs"
alias se="emacs"
alias ec="emacsclient"
alias sec="sudo emacsclient"
alias v="vim"
alias sv="sudo vim"
alias r="ranger"
alias sr="sudo ranger"
alias cpc="xclip -selection clipboard"
alias sdn="shutdown -h now"
alias yt="youtube-dl --add-metadata -ic --output \"%(uploader)s%(title)s.%(ext)s\"" # Download video link
alias yta="yt -x -f bestaudio/best" # Download only audio
alias atenea="wget -m -E -k --reject=logout* --exclude-directories=/calendar,/user,/grade,/pluginfile.php,/mod/forum,/lib,/repository,/message --load-cookies=cookies.txt --save-cookies=cookies.txt --keep-session-cookies https://atenea.upc.edu/"

# Configuración de fzf.
export FZF_DEFAULT_OPTS="--layout=reverse --height 40%"

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Añadir atajos a diferentes carpetas.
if [ -f ~/.shortcuts ]; then
    source ~/.shortcuts
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
	. /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
	. /etc/bash_completion
    fi
fi

# Cronómetro con límite de tiempo.
function cronómetro {
    if [[ $1 == "--help" || $1 == "-h" ]]; then
        echo "Cronómetro con límite de tiempo."
        echo -e "\nAdmite un parámetro tiempo máximo, a partir del cual se bloquea la pantalla."
        echo -e "\nDavid Álvarez Rosa"
        return
    fi
    x=0; sec=0; min=0;
    while true; do
        if [ $sec -le 9 ]; then
            echo -ne "\r$min:0$sec";
        else
            echo -ne "\r$min:$sec";
        fi
        x=$(( x + 1 )); min=$(( x/60 )); sec=$(( x%60 ));
        if [[ $min%15 -eq 0 && $sec -eq 0 ]]; then
            notify-send --urgency normal "Cronómetro" "$min minutos.";
        fi
        if [[ $min -eq $1 && $sec -eq 0 ]]; then
            betterlockscreen -l;
            notify-send -t 0 --urgency normal "Cronómetro" "Tiempo alcanzado: $min minutos.";
        fi;
        sleep 1;
    done
}
