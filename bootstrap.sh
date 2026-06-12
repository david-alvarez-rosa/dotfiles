#!/bin/sh

set -eux

PACMAN_PACKAGES="
  acpi
  cloudflared
  dmenu
  dunst
  emacs
  fd
  feh
  firefox
  git
  git-lfs
  gnupg
  gnuplot
  goimapnotify
  graphviz
  hunspell-en_us
  hunspell-es_es
  i3-wm
  i3blocks
  imagemagick
  inter-font
  isync
  keepassxc
  ledger
  libnotify
  maim
  mpc
  mpv
  neovim
  networkmanager
  openssh
  pacman-contrib
  pipewire-alsa
  pipewire-pulse
  plantuml
  poppler-glib
  qutebrowser
  ripgrep
  rsync
  slock
  starship
  sysstat
  tlp
  ttf-dejavu
  ttf-hack-nerd
  unclutter
  upower
  vim
  which
  wireplumber
  xbindkeys
  xcape
  xclip
  xdotool
  xorg-server
  xorg-setxkbmap
  xorg-xinit
  xorg-xinput
  xorg-xmodmap
  xorg-xrandr
  xorg-xrdb
  xorg-xset
  xss-lock
  yt-dlp
  zsh"

AUR_PACKAGES="
  acpilight
  mu
  xremap-x11-bin"

sudo pacman -Syu --needed --noconfirm $PACMAN_PACKAGES

if ! command -v yay >/dev/null; then
  sudo pacman -S --needed --noconfirm git base-devel
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  (cd /tmp/yay && makepkg -si --noconfirm)
fi

yay -S --needed --noconfirm $AUR_PACKAGES

emacs --batch --eval '(progn
  (require (quote package))
  (add-to-list (quote package-archives) (quote ("melpa" . "https://melpa.org/packages/")))
  (package-refresh-contents)
  (setq use-package-always-ensure t)
  (load (locate-user-emacs-file "init.el")))'

sudo systemctl enable NetworkManager.service tlp.service
systemctl --user enable keepassxc.service mbsync.timer

chsh --shell $(which zsh)
