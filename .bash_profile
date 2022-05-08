#!/bin/bash


[ -f ~/.bashrc ] && source ~/.bashrc

# Start i3 in tty1
if [ "$(tty)" = "/dev/tty1" ]; then
    pgrep -x i3 || exec startx "$XINITRC"
fi
