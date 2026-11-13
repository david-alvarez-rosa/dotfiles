#!/bin/sh

set -eux

echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/bootstrap >/dev/null
trap 'sudo rm -f /etc/sudoers.d/bootstrap' EXIT

PACMAN_PACKAGES="
  acpi
  alacritty
  brightnessctl
  clang
  cloudflared
  cmake
  darkman
  dunst
  emacs
  fakeroot
  fd
  feh
  firefox
  gcc
  git
  git-crypt
  git-lfs
  gnupg
  gnuplot
  goimapnotify
  graphviz
  hblock
  hunspell-en_us
  hunspell-es_es
  i3-wm
  i3lock
  i3status-rust
  imagemagick
  inter-font
  isync
  jq
  keepassxc
  ledger
  libnotify
  lm_sensors
  maim
  man-db
  mpc
  mpv
  neovim
  networkmanager
  nextcloud-client
  openssh
  pacman-contrib
  picom
  pipewire-alsa
  pipewire-pulse
  plantuml
  poppler-glib
  ripgrep
  rofi
  satty
  starship
  texlive
  tlp
  tpm2-tools
  ttf-dejavu
  ttf-hack-nerd
  unclutter
  upower
  uv
  vdirsyncer
  vim
  which
  wireplumber
  xclip
  xdg-desktop-portal-gtk
  xdotool
  xorg-server
  xorg-setxkbmap
  xorg-xinit
  xorg-xinput
  xorg-xrandr
  xorg-xrdb
  xorg-xset
  xss-lock
  yt-dlp
  zsh
  zsh-autosuggestions
  zsh-completions
  zsh-syntax-highlighting"

AUR_PACKAGES="
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
systemctl --user enable commit-docs.timer dav-sync.timer lid-mute.service goimapnotify@personal.service darkman.service systemd-tmpfiles-setup.service

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
