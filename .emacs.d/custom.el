(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(ansi-color-faces-vector
   [default default default italic underline success warning error])
 '(browse-url-browser-function 'browse-url-generic)
 '(browse-url-generic-program "qutebrowser")
 '(custom-enabled-themes '(spacemacs-dark))
 '(custom-safe-themes
   '("bffa9739ce0752a37d9b1eee78fc00ba159748f50dc328af4be661484848e476" default))
 '(display-time-24hr-format t)
 '(display-time-format "%d %B %H:%M")
 '(display-time-mode t)
 '(erc-modules
   '(autojoin button completion fill irccontrols list match menu move-to-prompt netsplit networks noncommands readonly ring stamp track))
 '(helm-completion-style 'emacs)
 '(hl-todo-keyword-faces
   '(("TODO" . "#dc752f")
     ("NEXT" . "#dc752f")
     ("THEM" . "#2d9574")
     ("PROG" . "#3a81c3")
     ("OKAY" . "#3a81c3")
     ("DONT" . "#f2241f")
     ("FAIL" . "#f2241f")
     ("DONE" . "#42ae2c")
     ("NOTE" . "#b1951d")
     ("KLUDGE" . "#b1951d")
     ("HACK" . "#b1951d")
     ("TEMP" . "#b1951d")
     ("FIXME" . "#dc752f")
     ("XXX+" . "#dc752f")
     ("\\?\\?\\?+" . "#dc752f")))
 '(ispell-dictionary "spanish" t)
 '(mml-secure-key-preferences
   '((OpenPGP
      (sign
       ("david@alvarezrosa.com" "2DA972B97E65FC7AEB4F5FD092C293BEB93A70A1"))
      (encrypt
       ("david@alvarezrosa.com" "2DA972B97E65FC7AEB4F5FD092C293BEB93A70A1")))
     (CMS
      (sign)
      (encrypt))))
 '(org-display-custom-times t)
 '(org-time-stamp-custom-formats '("<%d-%m-%Y %a>" . "<%d-%m-%y %a %H:%M>"))
 '(org-todo-keyword-faces nil)
 '(package-selected-packages
   '(sublimity-map sublimity centered-window emms mpdel helm-ag helm-rg doom-modeline fast-scroll pyenv-mode elpy ein web-mode ess php-mode golden-ratio helm-projectile projectile elfeed flycheck company avy elfeed-goodies: yasnippet-snippets org-mime elfeed-goodies dired-narrow paredit winum window-numbering use-package switch-window swiper sudo-edit spacemacs-theme spaceline slime-company rainbow-delimiters pretty-mode popup-kill-ring pdf-tools org-bullets nyan-mode nlinum-relative multiple-cursors memoize markdown-mode magit iedit hungry-delete htmlize highlight-indent-guides helm flycheck-clang-analyzer fancy-battery expand-region elfeed-org diminish company-shell company-jedi company-irony company-c-headers company-auctex calfw-org calfw beacon ace-window))
 '(pdf-view-midnight-colors '("#655370" . "#fbf8ef"))
 '(powerline-default-separator 'arrow-fade)
 '(safe-local-variable-values
   '((TeX-command-extra-options . "-shell-escape -synctex=1 -output-dir ./Build/"))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(default ((t (:inherit nil :stipple nil :background "#292b2e" :foreground "#b2b2b2" :inverse-video nil :box nil :strike-through nil :overline nil :underline nil :slant normal :weight normal :height 105 :width normal :foundry "Cyre" :family "Inconsolata"))))
 '(nlinum-relative-current-face ((t (:foreground "#c56ec3" :weight bold)))))
