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
(setq use-package-always-defer t)

(setq user-full-name "David Álvarez Rosa")
(setq user-mail-address "david@alvarezrosa.com")

(load-file "~/.config/emacs/at-work.el")

(server-start)

(setq custom-file "~/.config/emacs/custom.el")
(load custom-file t)

(setq auth-sources '("~/.local/share/authinfo.gpg"))

(when (eq system-type 'darwin)
  (use-package exec-path-from-shell
    :demand t
    :config
    (exec-path-from-shell-initialize)))

(when (eq system-type 'darwin)
  (add-to-list 'load-path "/opt/homebrew/share/emacs/site-lisp/mu/mu4e"))

(defalias 'yes-or-no-p 'y-or-n-p)

(setq-default dired-listing-switches "-alh --group-directories-first --color")
(when (eq system-type 'darwin)
  (setq insert-directory-program "/opt/homebrew/bin/gls"))

(put 'dired-find-alternate-file 'disabled nil)

(use-package dired-narrow
  :after dired
  :bind (:map dired-mode-map
              ("/" . 'dired-narrow-fuzzy)))

(setq backup-directory-alist
      `((".*" . ,temporary-file-directory)))
(setq auto-save-file-name-transforms
      `((".*" ,temporary-file-directory t)))
(setq lock-file-name-transforms
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

(global-set-key (kbd "s-f") 'windmove-right)
(global-set-key (kbd "s-b") 'windmove-left)
(global-set-key (kbd "s-n") 'windmove-down)
(global-set-key (kbd "s-p") 'windmove-up)

(global-set-key (kbd "s-F") 'windmove-swap-states-right)
(global-set-key (kbd "s-B") 'windmove-swap-states-left)
(global-set-key (kbd "s-N") 'windmove-swap-states-down)
(global-set-key (kbd "s-P") 'windmove-swap-states-up)

(winner-mode 1)

(use-package ace-window
  :bind ("M-o" . 'ace-window)
  :config (setq aw-scope 'frame))

(add-hook 'text-mode-hook 'turn-on-auto-fill)
(setq-default fill-column 79)
(add-hook 'text-mode-hook
          (lambda ()
            (set-fill-column 72)))

(defun dalvrosa/unfill-paragraph (&optional region)
  "Takes a multi-line paragraph and makes it into a single line of text."
  (interactive (progn (barf-if-buffer-read-only) '(t)))
  (let ((fill-column (point-max))
        ;; This would override `fill-column' if it's an integer.
        (emacs-lisp-docstring-fill-column t))
    (fill-paragraph nil region)))
(define-key global-map (kbd "M-Q") 'dalvrosa/unfill-paragraph)

(defun dalvrosa/unfill-paragraph-and-kill (beg end)
  "Save the current region to the kill ring after unfilling it."
  (setq dalvrosa/previous-major-mode major-mode)
  (interactive "r")
  (copy-region-as-kill beg end)
  (with-temp-buffer
    (funcall dalvrosa/previous-major-mode)
    (yank)
    (dalvrosa/unfill-paragraph (mark-whole-buffer))
    (mark-whole-buffer)
    (kill-region (point-min) (point-max))))
(define-key global-map (kbd "M-W") 'dalvrosa/unfill-paragraph-and-kill)

(define-key indent-rigidly-map "<" 'indent-rigidly-left)
(define-key indent-rigidly-map "b" 'indent-rigidly-left)
(define-key indent-rigidly-map ">" 'indent-rigidly-right)
(define-key indent-rigidly-map "f" 'indent-rigidly-right)
(define-key indent-rigidly-map "B" 'indent-rigidly-left-to-tab-stop)
(define-key indent-rigidly-map "F" 'indent-rigidly-right-to-tab-stop)

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

(add-hook 'text-mode-hook 'flyspell-mode)
(add-hook 'prog-mode-hook 'flyspell-prog-mode)

(use-package sudo-edit)

(use-package chronometer)

(use-package doom-themes
  :demand t
  :config
  (setq doom-themes-enable-bold t
        doom-themes-enable-italic t)
  (load-theme 'doom-solarized-light t)
  ;; Corrects (and improves) org-mode's native fontification.
  (doom-themes-org-config))

(setq dalvrosa/themes '(doom-solarized-light doom-zenburn))
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
  :demand t
  :init (doom-modeline-mode 1)
  :config (setq column-number-mode t)
  (setq doom-modeline-buffer-file-name-style 'relative-from-project)
  (setq doom-modeline-percent-position nil))

(setq display-time-default-load-average nil)

(use-package nyan-mode
  :after doom-modeline
  :init (nyan-mode)
  :config
  (nyan-start-animation)
  (nyan-toggle-wavy-trail))

(set-face-attribute 'default nil :font "Hack" :height 120)

(use-package default-text-scale
  :init (default-text-scale-mode)
  :config (setq default-text-scale-amount 20)
  (advice-add 'default-text-scale-reset :after 'doom-modeline-refresh-font-width-cache)
  (advice-add 'default-text-scale-decrease :after 'doom-modeline-refresh-font-width-cache)
  (advice-add 'default-text-scale-increase :after 'doom-modeline-refresh-font-width-cache)
  :bind (("s-0" . 'default-text-scale-reset)
         ("s--" . 'default-text-scale-decrease)
         ("s-=" . 'default-text-scale-increase)))

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

(use-package olivetti
  :config
  (setq-default olivetti-body-width (+ fill-column 8))
  :bind ("C-c o" . 'olivetti-mode))

(use-package company
  :config
  (setq company-show-quick-access  t)
  (setq company-idle-delay 0.0)
  (setq company-minimum-prefix-length 1)
  :hook (prog-mode . company-mode))

(use-package tree-sitter
  :config
  (global-tree-sitter-mode)
  (add-hook 'tree-sitter-after-on-hook #'tree-sitter-hl-mode))

(use-package tree-sitter-langs
  :after tree-sitter)

(use-package vterm
  :config
  (setq vterm-max-scrollback 10000))

(use-package lsp-mode
  :config
  (setq lsp-idle-delay 0.1)
  (add-to-list 'lsp-language-id-configuration '(brazil-config-mode . "brazil-config"))
  (lsp-register-client
   (make-lsp-client
    :priority -1
    :new-connection (lsp-stdio-connection "barium")
    :activation-fn (lsp-activate-on "brazil-config")
    :server-id 'barium))
  :hook ((c-mode-common . lsp-deferred)
         (java-mode . lsp-deferred)
         (ruby-mode . lsp-deferred)
         (python-mode . lsp-deferred)
         (brazil-config-mode . lsp-deferred)
         (lsp-mode . lsp-enable-which-key-integration))
  :commands lsp)

(use-package lsp-ui :commands lsp-ui-mode)

(use-package lsp-treemacs
  :commands lsp-treemacs-errors-list
  :config
  (lsp-treemacs-sync-mode 1))

(add-hook 'prog-mode-hook 'display-line-numbers-mode)

(setq-default tab-width 2)

(setq-default indent-tabs-mode nil)

(add-hook 'before-save-hook 'delete-trailing-whitespace)

(use-package flycheck
  :init
  (add-hook 'prog-mode-hook 'flycheck-mode))

(defvar-local my-flycheck-local-cache nil)
(defun my-flycheck-local-checker-get (fn checker property)
  ;; Only check the buffer local cache for the LSP checker, otherwise we get
  ;; infinite loops.
  (if (eq checker 'lsp)
      (or (alist-get property my-flycheck-local-cache)
          (funcall fn checker property))
    (funcall fn checker property)))
(advice-add 'flycheck-checker-get
            :around 'my-flycheck-local-checker-get)
(add-hook 'lsp-managed-mode-hook
          (lambda ()
            (when (derived-mode-p 'haskell-mode)
              (setq my-flycheck-local-cache '((next-checkers . (haskell-hlint)))))))
(add-hook 'lsp-managed-mode-hook
          (lambda ()
            (when (derived-mode-p 'c++-mode)
              (setq my-flycheck-local-cache '((next-checkers . (c/c++-clang-tidy)))))))
(add-hook 'lsp-managed-mode-hook
          (lambda ()
            (when (derived-mode-p 'sh-mode)
              (setq my-flycheck-local-cache '((next-checkers . (sh-shellcheck)))))))
(add-hook 'lsp-managed-mode-hook
          (lambda ()
            (when (derived-mode-p 'tex-mode)
              (setq my-flycheck-local-cache '((next-checkers . (tex-chktex)))))))

(use-package projectile
  :demand t
  :config (projectile-mode +1)
  (setq projectile-ignored-projects '("~/"))
  (setq projectile-project-search-path '(("~/workplace/" . 3)))
  (setq projectile-completion-system 'ivy)
  :bind (:map projectile-mode-map
              ("C-c p" . 'projectile-command-map)
              ("s-r" . 'projectile-command-map)))

(use-package ag)

(use-package magit
  :bind ("C-c g" . 'magit-status))

(use-package git-link
  :demand t
  :config
  (global-set-key (kbd "C-c w l") 'git-link)
  (global-set-key (kbd "C-c w c") 'git-link-commit)
  (global-set-key (kbd "C-c w h") 'git-link-homepage))

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
  :demand t
  :config
  (setq treemacs-indentation 1)
  (treemacs-load-theme "all-the-icons"))

(defun dalvrosa/colorize-compilation ()
  "Colorize from `compilation-filter-start' to `point'."
    (ansi-color-apply-on-region
     compilation-filter-start (point)))
(add-hook 'compilation-filter-hook #'dalvrosa/colorize-compilation)

(if dalvrosa/at-work
    (require 'amz-common))

(use-package google-c-style
  :hook
  (c-mode-common . google-set-c-style)
  (c-mode-common . google-make-newline-indent))

(use-package flycheck-clang-tidy
  :after flycheck
  :hook
  (flycheck-mode . flycheck-clang-tidy-setup))

(use-package cmake-mode)

(use-package typescript-mode
  :demand t
  :config
  (add-to-list 'auto-mode-alist '("\\.tsx\\'" . typescript-mode)))

(use-package elpy
  ;; :init
  ;; (elpy-enable)
  )

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

(setq org-default-notes-file "~/Documents/Agenda.org")
(define-key global-map (kbd "C-c c") 'org-capture)

(setq org-capture-templates
      '(("t" "Task" entry
         (file+olp "~/Documents/Agenda.org" "Refile")
         "* TODO [#C] %?\n%a\n%i" :empty-lines 1)
        ("n" "Text Note" entry
         (file+olp "~/Documents/Notes.org" "Refile")
         "* %?" :empty-lines 1)))

(require 'org-mu4e)

(global-set-key (kbd "C-c l") 'org-store-link)
(global-set-key (kbd "C-c j") 'org-clock-goto)

(setq org-todo-keywords
      '((sequence "TODO(t!)" "WAIT(w!)" "NEXT(n!)" "|"
                  "DONE(d!)" "CANCELLED(c!)")))

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

(setq org-agenda-files '("~/Documents/Agenda.org"))

(setq org-agenda-custom-commands
      '((" " "Block Agenda"
         ((agenda "" ((org-agenda-span 1)))
          (todo "NEXT"
                ((org-agenda-overriding-header "Next Actions")
                 (org-agenda-skip-function
                  '(org-agenda-skip-entry-if 'scheduled))))
          (tags-todo "+refile" ((org-agenda-overriding-header "Refile")))
          (tags-todo "TODO=\"TODO\"+amzn"
                     ((org-agenda-overriding-header "Amazon")
                      (org-agenda-skip-function
                       '(org-agenda-skip-entry-if 'scheduled))))
          (tags-todo "TODO=\"TODO\"+proj"
                     ((org-agenda-overriding-header "Projects")
                      (org-agenda-skip-function
                       '(org-agenda-skip-entry-if'scheduled))))
          (tags-todo "TODO=\"TODO\"+sing"
                     ((org-agenda-overriding-header "Standalone Tasks")
                      (org-agenda-skip-function
                       '(org-agenda-skip-entry-if 'scheduled))))
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

(require 'appt)
(setq appt-time-msg-list nil)
(setq appt-message-warning-time '15
      appt-display-interval '5)

(setq appt-display-mode-line nil
      appt-display-format 'window)
(appt-activate 1)

(org-agenda-to-appt)
(run-at-time "24:01" 1800 'org-agenda-to-appt)
(add-hook 'org-finalize-agenda-hook 'org-agenda-to-appt)

(defun dalvrosa/appt-send-notification (title msg)
  (if dalvrosa/at-work
      (shell-command (concat "terminal-notifier"
                             " -message " msg
                             " -title " title
                             " -sender " "org.gnu.Emacs"))
    (shell-command (concat "notify-send " msg " " title))))

(defun dalvrosa/appt-display (min-to-app new-time msg)
  (dalvrosa/appt-send-notification
   (format "'Meeting in %s minutes'" min-to-app)
   (format "'%s'" msg)))
(setq appt-disp-window-function (function dalvrosa/appt-display))

(setq org-archive-location "::* Archived Items")

(setq org-archive-tag "archive")

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
  :demand t
  :config
  (pdf-tools-install)
  :bind (:map pdf-view-mode-map
              ("C-s" . 'isearch-forward)))

(require 'mu4e)
(setq mail-user-agent 'mu4e-user-agent)
(global-set-key (kbd "C-c e") 'mu4e)

(setq mu4e-completing-read-function 'ivy-completing-read)

(setq mu4e-headers-fields '((:human-date . 12)
                            (:flags . 6)
                            (:maildir . 18)
                            (:from-or-to . 22)
                            (:subject)))

(if dalvrosa/at-work
    (setq dalvrosa/mailboxes "personal spam amazon")
  (setq dalvrosa/mailboxes "personal spam"))
(setq mu4e-get-mail-command
      (concat "mbsync -c ~/.config/isync/mbsyncrc -V " dalvrosa/mailboxes))

(defun dalvrosa/remove-nth-element (nth list)
  (if (zerop nth) (cdr list)
    (let ((last (nthcdr (1- nth) list)))
      (setcdr last (cddr last))
      list)))
(setq mu4e-marks (dalvrosa/remove-nth-element 5 mu4e-marks))
(add-to-list 'mu4e-marks
             '(trash
               :char ("d" . "▼")
               :prompt "dtrash"
               :dyn-target (lambda (target msg) (mu4e-get-trash-folder msg))
               :action (lambda (docid msg target)
                         (mu4e--server-move docid
                                         (mu4e--mark-check-target target) "-N+S-u"))))

(setq mu4e-context-policy 'pick-first)

(setq mu4e-sent-messages-behavior 'sent)
(setq message-signature-file "~/Documents/Signature.txt")
(setq smtpmail-stream-type 'starttls)
(setq smtpmail-smtp-service 587)
(setq mu4e-change-filenames-when-moving t)

(if dalvrosa/at-work
    (progn
      (setq dalvrosa/smtp-server "localhost")
      (setq dalvrosa/smtp-port 1587))
  (progn
    (setq dalvrosa/smtp-server "mail.alvarezrosa.com")
    (setq dalvrosa/smtp-port 587)))

(setq mu4e-contexts
      `( ,(make-mu4e-context
           :name "Personal"
           :match-func (lambda (msg)
                         (when msg
                           (string-match-p "^/Personal" (mu4e-message-field msg :maildir))))
           :vars `(
                   (mu4e-inbox-folder . "/Personal/Inbox")
                   (mu4e-sent-folder . "/Personal/Sent")
                   (mu4e-drafts-folder . "/Personal/Drafts")
                   (mu4e-trash-folder . "/Personal/Trash")
                   (mu4e-refile-folder . "/Personal/Archive")
                   (user-mail-address . "david@alvarezrosa.com")
                   (smtpmail-smtp-service . ,dalvrosa/smtp-port)
                   (smtpmail-smtp-server . ,dalvrosa/smtp-server)))
         ,(make-mu4e-context
           :name "Spam"
           :match-func (lambda (msg)
                         (when msg
                           (string-match-p "^/Spam" (mu4e-message-field msg :maildir))))
           :vars `(
                   (mu4e-inbox-folder . "/Spam/Inbox")
                   (mu4e-sent-folder . "/Spam/Sent")
                   (mu4e-drafts-folder . "/Spam/Drafts")
                   (mu4e-trash-folder . "/Spam/Trash")
                   (mu4e-refile-folder . "/Spam/Archive")
                   (user-mail-address . "davids@alvarezrosa.com")
                   (smtpmail-smtp-service . ,dalvrosa/smtp-port)
                   (smtpmail-smtp-server . ,dalvrosa/smtp-server)))
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
                   (user-mail-address . "dalvrosa@amazon.com")
                   (smtpmail-smtp-server . "ballard.amazon.com")
                   (smtpmail-smtp-service . 1587)))))

(add-to-list 'mu4e-bookmarks
             '(:name "All Inboxes"
              :query "maildir:/Personal/Inbox OR maildir:/Amazon/Inbox OR maildir:/Spam/Inbox"
              :key ?i))

(defun dalvrosa/mu4e-update-mail-and-index ()
  (interactive)
  (mu4e-update-mail-and-index t))

(define-key mu4e-main-mode-map (kbd "U") 'dalvrosa/mu4e-update-mail-and-index)
(define-key mu4e-update-minor-mode-map (kbd "C-c C-u") 'dalvrosa/mu4e-update-mail-and-index)

(mu4e t)
(setq mu4e-update-interval (* 4 60 60))

(setq doom-modeline-mu4e t)

(use-package mu4e-alert
  :config
  (mu4e-alert-enable-mode-line-display)
  (mu4e-alert-enable-notifications))

(setq smtpmail-queue-dir "~/.local/share/mail/Queue/cur")

(use-package eudc
  :ensure nil
  :after (ldap bbdb)
  :init (require 'eudc)
  :bind (:map message-mode-map
              (("<M-tab>" . 'eudc-expand-inline)))
  :config
  (eudc-set-server "ldap.amazon.com" 'ldap t)
  (eudc-bbdb-set-server "localhost")
  (setq eudc-server-hotlist
        '(("localhost" . bbdb)
          ("ldap.amazon.com" . ldap)))
  (setq eudc-inline-expansion-servers 'hotlist))

(use-package ldap
  :ensure nil
  :demand t
  :config
  (setq ldap-default-host "ldap.amazon.com")
  (setq ldap-host-parameters-alist '(("ldap.amazon.com"
                                      base "o=amazon.com"
                                      auth simple))))

(use-package bbdb
  :demand t)

(use-package bbdb-vcard
  :after bbdb)

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

(require 'mu4e-icalendar)
(mu4e-icalendar-setup)
(setq mu4e-icalendar-trash-after-reply t)

(setq gnus-icalendar-org-capture-file "~/Documents/Agenda.org")
(setq gnus-icalendar-org-capture-headline '("Calendar"))
(gnus-icalendar-org-setup)

(defun dalvrosa/mu4e-show-cr-patch (msg)
  (let* ((path (mu4e-message-field msg :path))
         (patches)
         (buf))
    (message "Loading patches...")
    (setq patches (split-string
                   (shell-command-to-string
                    (format "~/.local/bin/cr-get-patch %s" path)) "\n" t))
    (dolist (p patches)
      (find-file p)
      (delete-other-windows)
      (setq buf (get-buffer-create (file-name-nondirectory p)))
      (with-current-buffer buf
        (read-only-mode 1)))))

(add-to-list 'mu4e-view-actions
             '("CR patch view" . dalvrosa/mu4e-show-cr-patch) t)

(use-package elfeed
  :bind (("C-c f" . 'elfeed)
         :map elfeed-search-mode-map (("v" . 'dalvrosa/elfeed-play-with-mpv)
                                   ("i" . 'dalvrosa/elfeed-ignore)))
  :config (setq elfeed-db-directory "~/.config/emacs/elfeed"
                elfeed-search-filter "@1-week-ago -no "
                elfeed-search-title-max-width 100))

(use-package elfeed-org
  :after elfeed
  :init (elfeed-org)
  :config (setq rmh-elfeed-org-files (list "~/Documents/Subscriptions.org")))

(use-package elfeed-goodies
  :after elfeed
  :init (elfeed-goodies/setup)
  :config
  (setq elfeed-goodies/powerline-default-separator 'utf-8)
  (setq elfeed-goodies/entry-pane-size 0.40))

(defun dalvrosa/elfeed-play-with-mpv ()
  (interactive)
  (setq url (elfeed-entry-link (elfeed-search-selected :single)))
  (start-process "elfeed-mpv" nil "mpv" "--ytdl-format=[height<=720]" url)
  (elfeed-search-untag-all-unread))

(defun dalvrosa/elfeed-ignore ()
  (interactive)
  (setq entry (elfeed-search-selected :single))
  (setq tag (intern "no"))
  (elfeed-tag entry tag)
  (elfeed-search-update-entry entry)
  (forward-line))

(global-set-key (kbd "C-c i") 'erc-tls)

(if dalvrosa/at-work
    (setq erc-server "localhost")
  (setq erc-server "irc.alvarezrosa.com"))
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
