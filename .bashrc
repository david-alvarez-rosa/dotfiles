# Archivo de configuración de bash.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
    *) return;;
esac

# Acaemia setup.
if [[ $USER != "academia" || $UID -eq 0 ]]
then
    [ $(date +%s) -le $(cat /home/david/.cache/endDate.txt) ] && exit
    time=$(date +%k%M)
#    [ $time -ge 1530 -a $time -le 1630 ] && exit
fi

# No poner lineas duplicadas o empezando con un espacio en la historia.
export HISTCONTROL=ignoreboth
# Añadir al archivo de historia, no sobreescribir.
shopt -s histappend
# Tamaños máximos de la historia.
export HISTSIZE=5000
export HISTFILESIZE=5000
# Definición de variables.
# export BROWSER="qutebrowser"


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
alias l="exa --icons --group-directories-first"
alias ll="l -lag"
alias grep="grep --color"
alias diff="diff --color"
alias p="pacman"
alias sp="sudo pacman"
alias sp-Syu="sp -Syu --noconfirm && pkill -RTMIN+1 i3blocks"
alias sc="systemctl"
alias ssc="sudo systemctl"
alias ..='cd ..'
alias ...='cd ../../'
alias hg="history | grep"
alias mv="mv -i"
alias cp="cp -i"

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
alias nano="vim" # Just for the meme life
alias remainingTime='echo $(( ($(cat ~/.cache/endDate.txt) - $(date +%s))/60 ))'
alias vs='cd ~/.scripts/; vim $(fzf); cd -'


# Configuración de fzf.
export FZF_DEFAULT_OPTS="--layout=reverse --height 40%"

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Añadir atajos a diferentes carpetas.
[ -f ~/.shortcuts ] && source ~/.shortcuts

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
function chrono {
    if [[ $1 == "--help" || $1 == "-h" ]]; then
        echo "Cronómetro con límite de tiempo."
        echo -e "\nAdmite un parámetro tiempo máximo, a partir del cual se bloquea la pantalla."
        echo -e "\nDavid Álvarez Rosa"
        return
    fi
    max=$(echo $1 / 1 | bc)
    x=0; sec=0; min=0;
    while true; do
        [ $sec -le 9 ] && echo -ne "\r$min:0$sec" || echo -ne "\r$min:$sec";
        x=$(( x + 1 )); min=$(( x/60 )); sec=$(( x%60 ));
        if [[ $min%15 -eq 0 && $sec -eq 0 ]]; then
            remaining=$(( $1 - $min ))
            notify-send --urgency normal "Cronómetro" "$min minutos. Quedan $remaining";
        fi
        if [[ $min -eq $max && $sec -eq 0 ]]; then
            betterlockscreen -l;
            notify-send -t 0 --urgency normal "Cronómetro" "Tiempo alcanzado: $min minutos.";
        fi;
        sleep 1;
    done
}

function academia {
    if [[ $1 == "--help" || $1 == "-h" ]]; then
        echo "Academia."
        echo -e "\nPasar como variable el tiempo en minutos."
        echo -e "\nDavid Álvarez Rosa"
        return
    fi
    startDate=$(date +%s)
    endDate=$(( startDate + $1 * 60 ))
    echo $endDate > /home/david/.cache/endDate.txt
    nmcli networking off
    sudo systemctl stop NetworkManager
    chmod -R g=rwX ~/.mail/ ~/.mu/log/ ~/.config/pulse/ ~/.local/share/qutebrowser
    if [[ $2 == "off" ]]; then
        pkill i3
        logout
    fi
}

function jbl {
    sudo systemctl start bluetooth
    bluetoothctl power on
    bluetoothctl connect 00:22:37:46:71:7A
}

# Update Atenea's local copy.
function atenea {
    pass=$(cat /home/david/.cache/atenea.txt)
    wget --save-cookies=$HOME/Documents/UPC/Cuatrimestre\ 8/Atenea\ -\ Versión\ local/cookies.txt \
         --directory-prefix=$HOME/Documents/UPC/Cuatrimestre\ 8/Atenea\ -\ Versión\ local/ \
         --keep-session-cookies \
         --post-data "adAS_i18n_theme=ca&adAS_mode=authn&adAS_username=david.alvarez.rosa&adAS_password=$pass&adAS_submit=" \
         https://sso.upc.edu/CAS/login?service=https%3A%2F%2Fatenea.upc.edu%2Flogin%2Findex.php%3FauthCAS%3DCAS
    rm $HOME/Documents/UPC/Cuatrimestre\ 8/Atenea\ -\ Versión\ local/login*
    wget -m -E -k -p \
         --directory-prefix=$HOME/Documents/UPC/Cuatrimestre\ 8/Atenea\ -\ Versión\ local/ \
         --exclude-directories=calendar,/grade,/recent.php,/enrol,/mod/forum,/wiki,/lib,/repository,/message,/profile,/preferences \
         --reject-regex "(logout|user)" \
         --load-cookies=$HOME/Documents/UPC/Cuatrimestre\ 8/Atenea\ -\ Versión\ local/cookies.txt \
         https://atenea.upc.edu/
    notify-send -t 0 --urgency low "Atenea UPC" "Descarga completa.";
}


export EDITOR="vim"
export GPG_AGENT_INFO=""
