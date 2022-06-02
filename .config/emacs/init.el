(setq gc-cons-threshold most-positive-fixnum)

;; Lower threshold back to 8 MiB (default is 800kB)
(add-hook 'emacs-startup-hook
          (lambda () (setq gc-cons-threshold (expt 2 23))))

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/"))

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(eval-when-compile
  (require 'use-package))

(setq use-package-always-ensure t)

(setq user-full-name "David Álvarez Rosa")
(setq user-mail-address "david@alvarezrosa.com")

(server-start)

(setq custom-file "~/.config/emacs/custom.el")
(load custom-file t)

(setq auth-sources '("~/.local/share/authinfo.gpg"))

(use-package exec-path-from-shell
  :config
  (when (eq system-type 'darwin)
    (exec-path-from-shell-initialize)))

(when (eq system-type 'darwin)
  (add-to-list 'load-path "/opt/homebrew/share/emacs/site-lisp/mu/mu4e")
  (setq mac-command-modifier 'meta))

(defalias 'yes-or-no-p 'y-or-n-p)

(setq-default dired-listing-switches "-alh")

(put 'dired-find-alternate-file 'disabled nil)

(use-package dired-narrow
  :bind (:map dired-mode-map
              ("/" . 'dired-narrow-fuzzy)))

(setq backup-directory-alist
      `((".*" . ,temporary-file-directory)))
(setq auto-save-file-name-transforms
      `((".*" ,temporary-file-directory t)))

(global-set-key (kbd "C-x C-b") 'ibuffer)

(setq ibuffer-expert t)

(global-set-key (kbd "C-x k") 'kill-current-buffer)

(defun dalvrosa/kill-all-other-buffers ()
  "Kill all buffers except current and *scratch*."
  (interactive)
  (delete-other-windows)
  (setq scratch (get-buffer "*scratch*"))
  (mapc 'kill-buffer (delq scratch (delq (current-buffer) (buffer-list)))))
(global-set-key (kbd "C-c k") 'dalvrosa/kill-all-other-buffers)

(put 'narrow-to-region 'disabled nil)
(put 'narrow-to-page 'disabled nil)
(put 'LaTeX-narrow-to-environment 'disabled nil)

(defun dalvrosa/split-and-follow-horizontally ()
  (interactive)
  (split-window-below)
  (balance-windows)
  (other-window 1))
(global-set-key (kbd "C-x 2") 'dalvrosa/split-and-follow-horizontally)

(defun dalvrosa/split-and-follow-vertically ()
  (interactive)
  (split-window-right)
  (balance-windows)
  (other-window 1))
(global-set-key (kbd "C-x 3") 'dalvrosa/split-and-follow-vertically)

(global-set-key (kbd "C-x C-k") 'kill-buffer-and-window)

(windmove-default-keybindings)

(windmove-swap-states-default-keybindings '(super meta))

(winner-mode 1)

(use-package ace-window
  :bind ("M-o" . 'ace-window)
  :config (setq aw-scope 'frame))

(add-hook 'text-mode-hook 'turn-on-auto-fill)
(setq-default fill-column 79)

(setq-default sentence-end-double-space nil)

(global-subword-mode 1)

(setq shift-select-mode nil)

(delete-selection-mode 1)

(use-package expand-region
  :bind ("C-=" . 'er/expand-region))

(put 'upcase-region 'disabled nil)
(put 'downcase-region 'disabled nil)

(setq scroll-conservatively 101)

(define-key global-map (kbd "M-n") 'forward-paragraph)
(define-key global-map (kbd "M-p") 'backward-paragraph)

(global-set-key (kbd "C-M-n") 'scroll-up-line)
(global-set-key (kbd "C-M-p") 'scroll-down-line)

(setq scroll-preserve-screen-position t)

(put 'set-goal-column 'disabled nil)

(put 'scroll-left 'disabled nil)

(use-package avy
  :bind (("C-:" . 'avy-goto-char-2)
         ("M-g w" . 'avy-goto-word-1)))

(electric-pair-mode t)

(show-paren-mode 1)

(setq shr-use-fonts nil)
(setq shr-width 72)

(use-package ivy
  :init (ivy-mode)
  :config
  (setq ivy-use-virtual-buffers t)
  (setq enable-recursive-minibuffers t)
  (setq ivy-count-format "%d/%d ")
  (setq ivy-initial-inputs-alist nil)
  :bind ("C-c C-r" . 'ivy-resume))

(use-package ivy-rich
  :init (ivy-rich-mode 1))

(use-package counsel
  :init (counsel-mode)
  :bind ("C-c r" . 'counsel-register))

(use-package swiper
  :bind ("C-s" . 'swiper-isearch))

(use-package which-key
  :init (which-key-mode))

(setq ispell-dictionary "english")

(use-package sudo-edit)

(use-package doom-themes
  :config
  (setq doom-themes-enable-bold t
        doom-themes-enable-italic t)
  (load-theme 'doom-one-light t)
  ;; Corrects (and improves) org-mode's native fontification.
  (doom-themes-org-config))

(setq dalvrosa/themes '(doom-one-light doom-zenburn))
(setq dalvrosa/themes-index 0)

(defun dalvrosa/cycle-theme ()
  "Cycle through themes defined in dalvrosa/themes variable."
  (interactive)
  ;; Disable current themes.
  (mapc #'disable-theme custom-enabled-themes)
  ;; Load new theme.
  (setq dalvrosa/themes-index (% (1+ dalvrosa/themes-index) (length dalvrosa/themes)))
  (setq dalvrosa/theme (nth dalvrosa/themes-index dalvrosa/themes))
  (load-theme dalvrosa/theme t)
  ;; Resets powerline.
  (when (fboundp 'powerline-reset)
    (powerline-reset)))
(global-set-key (kbd "C-c d") 'dalvrosa/cycle-theme)

(setq custom-safe-themes t)

(use-package doom-modeline
  :init (doom-modeline-mode 1)
  :config (setq column-number-mode t)
  (setq doom-modeline-percent-position nil))

(setq display-time-default-load-average nil)

(set-face-attribute 'default nil :font "Hack" :height 110)

(use-package default-text-scale
  :init (default-text-scale-mode))

(tool-bar-mode 0)
(menu-bar-mode 0)
(scroll-bar-mode 0)
(tooltip-mode 0)

(setq inhibit-splash-screen t)
(setq inhibit-startup-message t)

(when window-system (global-hl-line-mode t))

;; (add-to-list 'default-frame-alist '(alpha . (93 . 84)))
(defun dalvrosa/toggle-transparency ()
  "Toggle transparency on and off."
  (interactive)
  (let ((alpha (frame-parameter nil 'alpha)))
    (if (eq
         (if (numberp alpha)
             alpha
           (cdr alpha)) ; may also be nil
         100)
        (set-frame-parameter nil 'alpha '(93 . 84))
      (set-frame-parameter nil 'alpha '(100 . 100)))))
(define-key global-map (kbd "C-c t") 'dalvrosa/toggle-transparency)

(use-package olivetti)

(use-package company
  :config (setq company-show-quick-access t)
  :hook (prog-mode . company-mode))

(use-package lsp-mode
  :hook
  (cc-mode . lsp)
  (java-mode . lsp))

(use-package lsp-ui)

(use-package lsp-treemacs
  :config
  (lsp-treemacs-sync-mode 1))

(use-package clang-format
  :config (global-set-key [C-M-tab] 'clang-format-region))

(add-hook 'prog-mode-hook 'display-line-numbers-mode)

(setq-default tab-width 2)

(setq-default indent-tabs-mode nil)

(add-hook 'before-save-hook 'delete-trailing-whitespace)

(use-package flycheck
  :init
  (add-hook 'prog-mode-hook 'flycheck-mode))

(use-package projectile
  :config (projectile-mode +1)
  (setq projectile-completion-system 'ivy)
  :bind (:map projectile-mode-map ("C-c p" . 'projectile-command-map)))

(use-package ag)

(use-package magit
  :bind ("C-c g" . 'magit-status))

(use-package yasnippet
  :config
  (use-package yasnippet-snippets)
  (yas-reload-all)
  :hook (prog-mode . yas-minor-mode))

(setq ediff-window-setup-function 'ediff-setup-windows-plain)
(setq ediff-split-window-function 'split-window-horizontally)

(use-package treemacs
  :config
  (add-hook 'treemacs-mode-hook  (lambda () (setq-local truncate-lines t)))
  :bind
  (:map global-map
        ("M-0"       . treemacs-select-window)
        ("C-x t 1"   . treemacs-delete-other-windows)
        ("C-x t t"   . treemacs)
        ("C-x t d"   . treemacs-select-directory)
        ("C-x t B"   . treemacs-bookmark)
        ("C-x t C-t" . treemacs-find-file)
        ("C-x t M-t" . treemacs-find-tag)))

(use-package treemacs-all-the-icons
  :config
  (setq treemacs-indentation 1)
  (treemacs-load-theme "all-the-icons"))

(use-package elpy
  :init
  (elpy-enable))

(use-package lsp-java)

(use-package web-mode
  :config
  (add-to-list 'auto-mode-alist '("\\.phtml\\'" . web-mode))
  (add-to-list 'auto-mode-alist '("\\.tpl\\.php\\'" . web-mode))
  (add-to-list 'auto-mode-alist '("\\.[agj]sp\\'" . web-mode))
  (add-to-list 'auto-mode-alist '("\\.as[cp]x\\'" . web-mode))
  (add-to-list 'auto-mode-alist '("\\.erb\\'" . web-mode))
  (add-to-list 'auto-mode-alist '("\\.mustache\\'" . web-mode))
  (add-to-list 'auto-mode-alist '("\\.djhtml\\'" . web-mode))
  (setq web-mode-markup-indent-offset 2))

(setq auto-mode-alist
      (cons '("\\.m$" . octave-mode) auto-mode-alist))

(use-package ess)

(setq org-use-speed-commands t)

(setq org-refile-targets '((nil :maxlevel . 2)
                                (org-agenda-files :maxlevel . 2)))
(setq org-outline-path-complete-in-steps nil)
(setq org-refile-use-outline-path 'file)

(setq org-default-notes-file "~/Documents/Tasks.org")
(define-key global-map (kbd "C-c c") 'org-capture)

(setq org-capture-templates
      '(("t" "Task" entry
         (file+olp "~/Documents/Tasks.org" "Refile")
         "* TODO [#C] %?\n%a\n%i" :empty-lines 1)
        ("n" "Text Note" entry
         (file+olp "~/Documents/Notes.org" "Refile")
         "* %?" :empty-lines 1)))

(require 'org-mu4e)

(global-set-key (kbd "C-c l") 'org-store-link)
(global-set-key (kbd "C-c j") 'org-clock-goto)

(setq org-todo-keywords
      '((sequence "TODO(t!)" "WAIT(w@/!)" "NEXT(n!)" "|"
                  "DONE(d!)" "CANCELLED(c@)")))

(setq org-log-into-drawer t)

(eval-after-load "org"
      (org-babel-do-load-languages
       'org-babel-load-languages
       '((C . t)
         ;; (C++ . t)
         (python . t)
         (latex . t)
         (matlab . t)
         (shell . t)
         (css . t)
         (calc . t)
         (R . t)
         (js . t))))

(setq org-confirm-babel-evaluate nil)

(setq org-agenda-restore-windows-after-quit t)

(setq org-list-allow-alphabetical t)

(setq org-startup-indented t)

(setq org-startup-folded 'content)

(global-set-key (kbd "C-c a") 'org-agenda)

(setq org-agenda-files (quote
                        ("~/Documents/Contacts/Birthdays.org"
                        "~/Documents/Tasks.org")))

(setq org-agenda-custom-commands
      '((" " "Block Agenda"
         ((agenda "" ((org-agenda-span 3)))
          (todo "NEXT"
                ((org-agenda-overriding-header "Next Actions")
                 (org-agenda-skip-function
                  '(org-agenda-skip-entry-if 'deadline 'scheduled))))
          (tags-todo "+REFILE" ((org-agenda-overriding-header "Refile")))
          (tags-todo "TODO=\"TODO\"+AMAZON"
                     ((org-agenda-overriding-header "Amazon")
                      (org-agenda-skip-function
                       '(org-agenda-skip-entry-if 'deadline 'scheduled))))
          (tags-todo "TODO=\"TODO\"+PROJECT"
                     ((org-agenda-overriding-header "Personal Projects")
                      (org-agenda-skip-function
                       '(org-agenda-skip-entry-if 'deadline 'scheduled))))
          (tags-todo "TODO=\"TODO\"+SINGLE"
                     ((org-agenda-overriding-header "Standalone Tasks")
                      (org-agenda-skip-function
                       '(org-agenda-skip-entry-if 'deadline 'scheduled))))
          (todo "WAIT" ((org-agenda-overriding-header "Waiting"))))
         ((org-agenda-start-with-log-mode t)))))

(setq org-agenda-log-mode-items '(closed clock state))

(setq org-deadline-warning-days 7)

(setq org-agenda-sticky t)

(defun dalvrosa/org-agenda-delete-empty-blocks ()
  "Remove empty agenda blocks.
  A block is identified as empty if there are fewer than 2
  non-empty lines in the block (excluding the line with
  `org-agenda-block-separator' characters)."
  (when org-agenda-compact-blocks
    (user-error "Cannot delete empty compact blocks"))
  (setq buffer-read-only nil)
  (save-excursion
    (goto-char (point-min))
    (let* ((blank-line-re "^\\s-*$")
           (content-line-count (if (looking-at-p blank-line-re) 0 1))
           (start-pos (point))
           (block-re (format "%c\\{10,\\}" org-agenda-block-separator)))
      (while (and (not (eobp)) (forward-line))
        (cond
         ((looking-at-p block-re)
          (when (< content-line-count 2)
            (delete-region start-pos (1+ (point-at-bol))))
          (setq start-pos (point))
          (forward-line)
          (setq content-line-count (if (looking-at-p blank-line-re) 0 1)))
         ((not (looking-at-p blank-line-re))
          (setq content-line-count (1+ content-line-count)))))
      (when (< content-line-count 2)
        (delete-region start-pos (point-max)))
      (goto-char (point-min))
      ;; The above strategy can leave a separator line at the beginning
      ;; of the buffer.
      (when (looking-at-p block-re)
        (delete-region (point) (1+ (point-at-eol))))))
  (setq buffer-read-only t))

(add-hook 'org-agenda-finalize-hook #'dalvrosa/org-agenda-delete-empty-blocks)

(require 'org-habit)

(setq org-habit-graph-column 55)

(setq org-archive-location "::* Archived Tasks")

(use-package toc-org
  :hook (org-mode . toc-org-mode))

(use-package markdown-mode)

(use-package latex
  :ensure auctex
  :config
  ;; Always in math mode
  (add-hook 'LaTeX-mode-hook 'LaTeX-math-mode)
  ;; Set PDF viewer to pdf-tools with correlation
  (setq TeX-view-program-selection '((output-pdf "PDF Tools")))
  (add-hook 'LaTeX-mode-hook 'TeX-source-correlate-mode)
  ;; Enable electric behavior.
  (setq TeX-electric-math t)
  (setq TeX-electric-sub-and-superscript t)
  ;; I want \items indented.
  (setq LaTeX-item-indent 0)
  :bind (
         :map LaTeX-mode-map
         ;; Command for cleaning auxiliary files
         ("C-x M-k" . 'TeX-clean)))

(setq reftex-plug-into-AUCTeX t)
(setq reftex-toc-split-windows-fraction 0.2)

(setq TeX-command-extra-options "-shell-escape -synctex=1")

(setq TeX-save-query nil)
(add-hook 'TeX-after-compilation-finished-functions
          #'TeX-revert-document-buffer)

(setq bibtex-align-at-equal-sign t)
(setq bibtex-entry-format `(opts-or-alts required-fields
                            numerical-fields whitespace realign
                            last-comma delimiters unify-case
                            braces sort-fields))
(setq bibtex-autokey-year-title-separator ":")

(use-package ledger-mode)

(use-package pdf-tools
  :config
  (pdf-tools-install)
  :bind (:map pdf-view-mode-map
              ("C-s" . 'isearch-forward)))

(require 'mu4e)
(setq mail-user-agent 'mu4e-user-agent)
(global-set-key (kbd "C-c e") 'mu4e)

(setq mu4e-headers-fields '((:human-date . 10)
                            (:flags . 5)
                            (:from . 20)
                            (:subject)))

(setq mu4e-view-show-addresses t)

(setq mu4e-get-mail-command "mbsync -c ~/.config/isync/mbsyncrc -a -V")
(define-key mu4e-headers-mode-map (kbd "C-c u") 'mu4e-update-index)

(use-package mu4e-column-faces
  :config (mu4e-column-faces-mode))

(setq mu4e-context-policy 'pick-first)

(setq mu4e-maildir "~/.local/share/mail")
(setq mu4e-user-mail-address-list '("david@alvarezrosa.com"
                                    "david.alvarez.rosa@yandex.com"
                                    "dalvarez553@alumno.uned.es"
                                    "dalvrosa@amazon.com"))
(setq mu4e-sent-messages-behavior 'sent)
(setq message-signature-file "~/Documents/Signature.txt")

(setq mu4e-contexts
      `( ,(make-mu4e-context
           :name "Personal"
           :match-func (lambda (msg)
                         (when msg
                           (string-match-p "^/Personal" (mu4e-message-field msg :maildir))))
           :vars '(
                   (mu4e-inbox-folder . "/Personal/Inbox")
                   (mu4e-sent-folder . "/Personal/Sent")
                   (mu4e-drafts-folder . "/Personal/Drafts")
                   (mu4e-trash-folder . "/Personal/Inbox/Trash")
                   (mu4e-refile-folder . "/Personal/Inbox/Junk")
                   (smtpmail-stream-type . starttls)
                   (user-mail-address . "david@alvarezrosa.com")
                   (smtpmail-smtp-server . "alvarezrosa.com")
                   (smtpmail-smtp-service . 587)))
         ,(make-mu4e-context
           :name "Yandex"
           :match-func (lambda (msg)
                         (when msg
                           (string-match-p "^/Yandex" (mu4e-message-field msg :maildir))))
           :vars '(
                   (mu4e-inbox-folder . "/Yandex/Inbox")
                   (mu4e-sent-folder . "/Yandex/Sent")
                   (mu4e-drafts-folder . "/Yandex/Drafts")
                   (mu4e-trash-folder . "/Yandex/Trash")
                   (mu4e-refile-folder . "/Yandex/Spam")
                   (smtpmail-stream-type . ssl)
                   (user-mail-address . "david.alvarez.rosa@yandex.com")
                   (smtpmail-smtp-server . "smtp.yandex.com")
                   (smtpmail-smtp-service . 465)))
         , (make-mu4e-context
            :name "University"
            :match-func (lambda (msg)
                          (when msg
                            (string-match-p "^/University" (mu4e-message-field msg :maildir))))
            :vars '(
                    (mu4e-inbox-folder . "/University/Inbox")
                    (mu4e-sent-folder . "/University/Sent Items")
                    (mu4e-drafts-folder . "/University/Drafts")
                    (mu4e-trash-folder . "/University/Deleted Items")
                    (mu4e-refile-folder . "/University/Junk Email")
                    (smtpmail-stream-type . starttls)
                    (user-mail-address . "dalvarez553@alumno.uned.es")
                    (smtpmail-smtp-server . "smtp.office365.com")
                    (smtpmail-smtp-service . 587)))
         ,(make-mu4e-context
           :name "Amazon"
           :match-func (lambda (msg)
                         (when msg
                           (string-match-p "^/Amazon" (mu4e-message-field msg :maildir))))
           :vars '(
                   (mu4e-inbox-folder . "/Amazon/Inbox")
                   (mu4e-sent-folder . "/Amazon/Sent Items")
                   (mu4e-drafts-folder . "/Amazon/Drafts")
                   (mu4e-trash-folder . "/Amazon/Deleted Items")
                   (mu4e-refile-folder . "/Amazon/Archive")
                   (smtpmail-stream-type . starttls)
                   (user-mail-address . "dalvrosa@amazon.com")
                   (smtpmail-smtp-server . "ballard.amazon.com")
                   (smtpmail-smtp-service . 1587)))))

(add-to-list 'mu4e-bookmarks
             (make-mu4e-bookmark
              :name "All Inboxes"
              ;; :query "maildir:/Personal/Inbox OR maildir:/Amazon/Inbox OR maildir:/University/Inbox OR maildir:/Yandex/Inbox"
              :query "maildir:/Amazon/Inbox"
              :key ?i))

(mu4e t)
(setq mu4e-update-interval (* 10 60))

(setq doom-modeline-mu4e t)

(use-package mu4e-alert
  :config
  (mu4e-alert-enable-mode-line-display)
  (mu4e-alert-enable-notifications))

(setq smtpmail-queue-dir "~/.local/share/mail/Queue/cur")

(setq mml-secure-openpgp-sign-with-sender t)

(setq mu4e-completing-read-function 'ivy-completing-read)

(setq dalvrosa/contact-file "~/Documents/Contacts/Emails.txt")
(defun dalvrosa/read-contact-list ()
  (with-temp-buffer
    (insert-file-contents dalvrosa/contact-file)
    (split-string (buffer-string) "\n" t)))
(defun dalvrosa/complete-emails (&optional start)
  (interactive)

  (let ((eoh ;; end-of-headers
         (save-excursion
           (goto-char (point-min))
           (search-forward-regexp mail-header-separator nil t))))

  ;; Only run if we are in the headers section
  (when (and eoh (> eoh (point)) (mail-abbrev-in-expansion-header-p))
    (let* ((end (point))
           (start
            (or start
                (save-excursion
                  (re-search-backward "\\(\\`\\|[\n:,]\\)[ \t]*")
                  (goto-char (match-end 0))
                  (point))))
           (initial-input (buffer-substring-no-properties start end)))

      (delete-region start end)

      (ivy-read "Contact: "
                (dalvrosa/read-contact-list)
                :action (lambda(contact) (with-ivy-window (insert contact)))
                :initial-input initial-input)))))
(define-key mu4e-compose-mode-map (kbd "<M-tab>") 'dalvrosa/complete-emails)

(require 'smtpmail)
(setq message-send-mail-function 'smtpmail-send-it)

(setq message-citation-line-function 'message-insert-formatted-citation-line)
(setq message-citation-line-format "On %a %d %b %Y at %R, %N wrote:")

(setq message-kill-buffer-on-exit t)

(use-package org-mime
  :config
  (setq org-mime-export-options '(:with-latex dvipng
                                  :section-numbers nil
                                  :with-author nil
                                  :with-toc nil))
  :bind (:map message-mode-map
              (("C-c o" . 'org-mime-edit-mail-in-org-mode)
               ("C-c M-o" . 'org-mime-htmlize))))

(setq mu4e-attachment-dir "~/Downloads")

(require 'gnus-dired)
(defun gnus-dired-mail-buffers ()
  "Return a list of active message buffers."
  (let (buffers)
    (save-current-buffer
      (dolist (buffer (buffer-list t))
        (set-buffer buffer)
        (when (and (derived-mode-p 'message-mode)
                 (null message-sent-message-via))
          (push (buffer-name buffer) buffers))))
    (nreverse buffers)))
(setq gnus-dired-mail-mode 'mu4e-user-agent)
(add-hook 'dired-mode-hook 'turn-on-gnus-dired-mode)

(use-package elfeed
  :bind ("C-c f" . 'elfeed)
  :config (setq elfeed-db-directory "~/.config/emacs/elfeed"
                elfeed-search-filter "@1-week-ago -no "
                elfeed-search-title-max-width 100))

(use-package elfeed-org
  :config
  (elfeed-org)
  (setq rmh-elfeed-org-files (list "~/Documents/Subscriptions.org")))

(use-package elfeed-goodies
  :config
  (elfeed-goodies/setup)
  (setq elfeed-goodies/powerline-default-separator 'utf-8)
  (setq elfeed-goodies/entry-pane-size 0.40))

(defun dalvrosa/elfeed-play-with-mpv ()
  (interactive)
  (setq url (elfeed-entry-link (elfeed-search-selected :single)))
  (start-process "elfeed-mpv" nil "mpv" "--ytdl-format=[height<=720]" url)
  (elfeed-search-untag-all-unread))
(define-key elfeed-search-mode-map (kbd "v") 'dalvrosa/elfeed-play-with-mpv)

(defun dalvrosa/elfeed-ignore ()
  (interactive)
  (setq entry (elfeed-search-selected :single))
  (setq tag (intern "no"))
  (elfeed-tag entry tag)
  (elfeed-search-update-entry entry)
  (forward-line))
(define-key elfeed-search-mode-map (kbd "i") 'dalvrosa/elfeed-ignore)

(global-set-key (kbd "C-c i") 'erc-tls)

(setq erc-server "irc.alvarezrosa.com")
(setq erc-nick "dalvrosa")
(setq erc-user-full-name "David Álvarez Rosa")
(setq erc-prompt-for-password nil)

(setq erc-kill-buffer-on-part t)
(setq erc-kill-queries-on-quit t)
(setq erc-kill-server-buffer-on-quit t)

(setq erc-fill-function 'erc-fill-static)
(setq erc-fill-static-center 22)
(setq erc-rename-buffers t)

(setq erc-track-exclude-types '("JOIN" "NICK" "PART" "QUIT" "MODE" "AWAY"))
(setq erc-track-exclude-server-buffer t)

(use-package erc-hl-nicks)
