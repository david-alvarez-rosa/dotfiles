#!/bin/sh

set -eux

echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/bootstrap >/dev/null
trap 'sudo rm -f /etc/sudoers.d/bootstrap' EXIT

PACMAN_PACKAGES="
  acpi
  cloudflared
  rofi
  dunst
  emacs
  fd
  feh
  firefox
  alacritty
  cmake
  gcc
  clang
  git
  git-crypt
  git-lfs
  gnupg
  gnuplot
  goimapnotify
  graphviz
  hunspell-en_us
  hunspell-es_es
  i3-wm
  i3blocks
  i3lock
  picom
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
  rm -rf /tmp/yay
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  (cd /tmp/yay && makepkg -si --noconfirm)
fi

yay -S --needed --noconfirm $AUR_PACKAGES

cd ~
git init
git remote add origin https://github.com/david-alvarez-rosa/dotfiles.git || true
git fetch
git checkout -ft origin/main
git submodule update --init --recursive
git config status.showUntrackedFiles no

if [ -f ~/gpg-key.asc ]; then
  export GNUPGHOME="$HOME/.local/share/gnupg"
  mkdir -p "$GNUPGHOME"
  chmod 700 "$GNUPGHOME"
  gpg --import ~/gpg-key.asc
  git-crypt unlock
fi

sudo systemctl enable NetworkManager.service tlp.service
systemctl --user enable keepassxc.service mbsync.timer commit-docs.timer imapnotify@personal.service imapnotify@spam.service

mkdir -p ~/.local/share/mail
mu init --maildir=~/.local/share/mail --my-address=david@alvarezrosa.com --my-address=davids@alvarezrosa.com

sudo chsh -s "$(which zsh)" "$USER"

emacs --batch --eval '(progn
  (require (quote package))
  (add-to-list (quote package-archives) (quote ("melpa" . "https://melpa.org/packages/")))
  (package-refresh-contents)
  (require (quote use-package))
  (setq use-package-always-ensure t)
  (defalias (quote y-or-n-p) (lambda (&rest _) t))
  (defalias (quote yes-or-no-p) (lambda (&rest _) t))
  (load (locate-user-emacs-file "init.el")))'

[ -e .bashrc ] && mv .bash* ~/tmp

reboot
