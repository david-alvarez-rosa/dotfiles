(setq gc-cons-threshold most-positive-fixnum)

;; Lower threshold back to 8 MiB (default is 800kB)
(add-hook 'emacs-startup-hook
          (lambda () (setq gc-cons-threshold (expt 2 23))))

;; Single VC backend inscreases booting speed
(setq vc-handled-backends '(Git))

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/"))

;; (setq use-package-always-ensure t)
(setq use-package-always-defer t)

(setq user-full-name "David Álvarez Rosa")
(setq user-mail-address "david@alvarezrosa.com")

(server-start)

(setq custom-file "~/.config/emacs/custom.el")
(load custom-file t)

(setq auth-sources '("~/.local/share/authinfo.gpg"))

(setq-default dired-listing-switches "-alh --group-directories-first")

(use-package dired-narrow
  :after dired
  :bind (:map dired-mode-map
              ("/" . 'dired-narrow-fuzzy)))

(use-package dired-subtree
  :after dired
  :bind
  ( :map dired-mode-map
    ("<tab>" . dired-subtree-toggle))
  :config
  (setq dired-subtree-use-backgrounds nil))

(setq backup-directory-alist
      `((".*" . ,temporary-file-directory)))
(setq auto-save-file-name-transforms
      `((".*" ,temporary-file-directory t)))
(setq lock-file-name-transforms
      `((".*" ,temporary-file-directory t)))

(setq split-width-threshold 210)

(global-set-key (kbd "C-x C-b") 'ibuffer)

(setq ibuffer-expert t)

(global-set-key (kbd "C-x k") 'kill-current-buffer)

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

(defun dalvrosa/kill-all-other-buffers ()
  "Kill all buffers except current and *scratch*."
  (interactive)
  (delete-other-windows)
  (setq scratch (get-buffer "*scratch*"))
  (mapc 'kill-buffer (delq scratch (delq (current-buffer) (buffer-list)))))
(global-set-key (kbd "C-c k") 'dalvrosa/kill-all-other-buffers)

(winner-mode 1)

(global-set-key (kbd "M-o") 'other-window)

(require 'windmove)
(require 'cl-lib)

(setq frame-title-format '("" "%b - GNU Emacs at " system-name))

(defmacro dalvrosa/i3-msg (&rest args)
  `(start-process "emacs-i3-windmove" nil "i3-msg" ,@args))

(defun dalvrosa/emacs-i3-windmove (dir)
  (let ((other-window (windmove-find-other-window dir)))
    (if (or (null other-window) (window-minibuffer-p other-window))
        (dalvrosa/i3-msg "focus" (symbol-name dir))
      (windmove-do-window-select dir))))

(defun dalvrosa/emacs-i3-direction-exists-p (dir)
  (cl-some (lambda (dir)
             (let ((win (windmove-find-other-window dir)))
               (and win (not (window-minibuffer-p win)))))
           (pcase dir
             ('width '(left right))
             ('height '(up down)))))

(defun dalvrosa/emacs-i3-move-window (dir)
  (let ((other-window (windmove-find-other-window dir))
        (other-direction (dalvrosa/emacs-i3-direction-exists-p
                          (pcase dir
                            ('up 'width)
                            ('down 'width)
                            ('left 'height)
                            ('right 'height)))))
    (cond
     ((and other-window (not (window-minibuffer-p other-window)))
      (window-swap-states (selected-window) other-window))
     (other-direction
      (evil-move-window dir))
     (t (dalvrosa/i3-msg "move" (symbol-name dir))))))

(defun dalvrosa/emacs-i3-integration (command)
  (pcase command
    ((rx bos "focus")
     (dalvrosa/emacs-i3-windmove
      (intern (elt (split-string command) 1))))
    ((rx bos "move")
     (dalvrosa/emacs-i3-move-window
      (intern (elt (split-string command) 1))))
    (- (dalvrosa/i3-msg command))))

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

(electric-pair-mode t)

(show-paren-mode 1)

(setq shr-use-fonts nil)
(setq shr-width 72)

(use-package vertico
  :init
  (vertico-mode))

(use-package consult
  :bind (
         ("C-c m" . consult-man)
         ;; ("C-c i" . consult-info)
         ("C-x b" . consult-buffer)                ;; orig. switch-to-buffer
         ("C-x 4 b" . consult-buffer-other-window) ;; orig. switch-to-buffer-other-window
         ("C-x 5 b" . consult-buffer-other-frame)  ;; orig. switch-to-buffer-other-frame
         ("C-x t b" . consult-buffer-other-tab)    ;; orig. switch-to-buffer-other-tab
         ("C-x r b" . consult-bookmark)            ;; orig. bookmark-jump
         ("C-x p b" . consult-project-buffer)      ;; orig. project-switch-Too-buffer
         ("M-y" . consult-yank-pop)                ;; orig. yank-pop
         ("M-g e" . consult-compile-error)
         ("M-g f" . consult-flymake)               ;; Alternative: consult-flycheck
         ("M-g g" . consult-goto-line)             ;; orig. goto-line
         ("M-g M-g" . consult-goto-line)           ;; orig. goto-line
         ("M-g o" . consult-outline)               ;; Alternative: consult-org-heading
         ("M-g m" . consult-mark)
         ("M-g k" . consult-global-mark)
         ("M-g i" . consult-imenu)
         ("M-g I" . consult-imenu-multi)
         ;; M-s bindings in `search-map'
         ("M-s d" . consult-fd)                  ;; Alternative: consult-find
         ("M-s c" . consult-locate)
         ("M-s g" . consult-grep)
         ("M-s G" . consult-git-grep)
         ("M-s r" . consult-ripgrep)
         ("C-s" . consult-line)
         ("M-s L" . consult-line-multi)
         ("M-s k" . consult-keep-lines)
         ("M-s u" . consult-focus-lines)
         ;; Isearch integration
         ("M-s e" . consult-isearch-history)
         :map isearch-mode-map
         ("M-e" . consult-isearch-history)         ;; orig. isearch-edit-string
         ("M-s e" . consult-isearch-history)       ;; orig. isearch-edit-string
         ("M-s l" . consult-line)                  ;; needed by consult-line to detect isearch
         ("M-s L" . consult-line-multi)            ;; needed by consult-line to detect isearch
         ;; Minibuffer history
         :map minibuffer-local-map
         ("M-s" . consult-history)                 ;; orig. next-matching-history-element
         ("M-r" . consult-history))                ;; orig. previous-matching-history-element

  :hook (completion-list-mode . consult-preview-at-point-mode)

  :init
  (setq consult-narrow-key "<")

  (setq orderless-component-separator 'orderless-escapable-split-on-space)
  :config
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)

  (consult-customize
   consult-theme :preview-key '(:debounce 0.2 any)
   consult-buffer consult-buffer-other-tab consult-buffer-other-window
   consult-project-buffer
   consult-buffer-other-frame consult-ripgrep consult-git-grep consult-grep
   consult-man consult-bookmark consult-recent-file consult-xref
   consult--source-bookmark consult--source-file-register
   consult--source-recent-file consult--source-project-recent-file
   :preview-key "M-."))

(savehist-mode)

(use-package corfu
  :init
  (global-corfu-mode)
  :config
  (setq corfu-auto t)
  (setq corfu-auto-delay 0.1)
  (corfu-popupinfo-mode 1)
  (corfu-history-mode 1)
  (add-to-list 'savehist-additional-variables 'corfu-history)
  (setq text-mode-ispell-word-completion nil))

(use-package orderless
  :init
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides '((file (styles . (partial-completion))))))

(use-package marginalia
  :init
  (marginalia-mode))

(use-package cape
  :init
  (add-hook 'completion-at-point-functions #'cape-dabbrev)
  (add-hook 'completion-at-point-functions #'cape-file)
  (add-hook 'completion-at-point-functions #'cape-tex))

(use-package embark
  :bind
  (("C-." . embark-act)
   ("C-;" . embark-dwim)))

(use-package embark-consult
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))

(use-package which-key
  :init (which-key-mode))

(setq ispell-program-name "hunspell")
(setq ispell-dictionary "english")

(add-hook 'text-mode-hook 'flyspell-mode)
;; (add-hook 'prog-mode-hook 'flyspell-prog-mode)

(use-package sudo-edit)

(use-package chronometer)

(setq confirm-kill-processes nil)

(use-package engine-mode
  :config
  (defengine DuckDuckGo
    "https://duckduckgo.com/?q=%s&t=h_"
    :keybinding "d")
  (engine-mode t))

(defun dalvrosa/new-gpt-chat (arg)
  (interactive "P")
  (if arg
      (switch-to-buffer (gptel (generate-new-buffer "*ChatGPT*")))
    (call-interactively 'gptel)))

(use-package gptel
  :bind
  ("C-c h" . dalvrosa/new-gpt-chat)
  :config
  (setq gptel-model 'gpt-4.1)
  (setq gptel-default-mode 'org-mode)
  :hook (gptel-mode . visual-line-mode))

(gptel-make-anthropic "Claude" :stream t :key gptel-api-key)

(setq custom-safe-themes t)

(load-theme 'modus-operandi)
(global-set-key (kbd "C-c d") 'modus-themes-toggle)

(use-package nerd-icons)

(use-package nerd-icons-completion
  :after marginalia
  :init
  (nerd-icons-completion-mode)
  (nerd-icons-completion-marginalia-setup))

(use-package nerd-icons-corfu
  :after corfu
  :config
  (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter))

(use-package nerd-icons-dired
  :hook
  (dired-mode . nerd-icons-dired-mode))

(use-package doom-modeline
  :init (doom-modeline-mode 1)
  :config
  (setq display-time-default-load-average nil)
  (setq doom-modeline-buffer-encoding nil)
  (setq column-number-mode t)
  (setq doom-modeline-buffer-file-name-style 'relative-from-project))

(use-package nyan-mode
  :after doom-modeline
  :init (nyan-mode))

(set-face-attribute 'default nil :font "Hack Nerd Font" :height 90)

(tool-bar-mode 0)
(menu-bar-mode 0)
(scroll-bar-mode 0)
(tooltip-mode 0)

(setq inhibit-splash-screen t)
(setq inhibit-startup-message t)

(when window-system (global-hl-line-mode t))

(use-package olivetti
  :config
  (setq-default olivetti-body-width (+ fill-column 10))
  (setq olivetti-style 'fancy)
  :bind ("C-c o" . 'olivetti-mode))

(use-package treesit-auto
  :demand t
  :custom
  (treesit-auto-install 'prompt)
  :config
  (treesit-auto-add-to-auto-mode-alist 'all)
  (global-treesit-auto-mode))

(global-eldoc-mode)

(use-package flymake
  :hook (prog-mode . flymake-mode)
  :bind (:map flymake-mode-map
              ("C-c ! n" . flymake-goto-next-error)
              ("C-c ! p" . flymake-goto-prev-error)
              ("C-c ! l" . flymake-show-buffer-diagnostics)))

(use-package vterm
  :config
  (add-to-list 'vterm-eval-cmds '("man" man))
  (setq vterm-max-scrollback 10000)
  :bind ("C-c t" . 'vterm))

(setq kill-buffer-query-functions (delq 'process-kill-buffer-query-function kill-buffer-query-functions))

(defun dalvrosa/project-shell ()
  "Start an inferior shell in the current project's root directory.
If a buffer already exists for running a shell in the project's root,
switch to it.  Otherwise, create a new shell buffer.
With \\[universal-argument] prefix arg, create a new inferior shell buffer even
if one already exists."
  (interactive)
  (require 'comint)
  (let* ((default-directory (project-root (project-current t)))
         (default-project-shell-name (project-prefixed-buffer-name "vterm"))
         (shell-buffer (get-buffer default-project-shell-name)))
    (if (and shell-buffer (not current-prefix-arg))
        (if (comint-check-proc shell-buffer)
            (pop-to-buffer shell-buffer (bound-and-true-p display-comint-buffer-action))
          (vterm shell-buffer))
      (vterm (generate-new-buffer-name default-project-shell-name)))))

(with-eval-after-load 'project
  (add-to-list 'project-switch-commands '(consult-project-buffer "Find buffer") t)
  (add-to-list 'project-switch-commands '(magit-project-status "Magit") t)
  (add-to-list 'project-switch-commands '(dalvrosa/project-shell "Vterm") t)
  (keymap-set project-prefix-map "b" #'consult-project-buffer)
  (keymap-set project-prefix-map "g" #'magit-project-status)
  (keymap-set project-prefix-map "v" #'dalvrosa/project-shell))

(use-package eglot
  :config
  (setq eglot-ignored-server-capabilities '(:inlayHintProvider))
  (setq eglot-autoshutdown t)
  :hook ((c++-ts-mode . eglot-ensure)
         (c-ts-mode . eglot-ensure)
         (java-ts-mode . eglot-ensure)
         (ruby-ts-mode . eglot-ensure)
         (rust-ts-mode . eglot-ensure)
         (python-ts-mode . eglot-ensure)
         (LaTeX-mode . eglot-ensure)
         (cmake-ts-mode . eglot-ensure)
         (php-ts-mode . eglot-ensure )
         (typescript-ts-mode . eglot-ensure)
         (js-ts-mode . eglot-ensure))
  :bind (:map eglot-mode-map
	            ("C-c l a" . eglot-code-actions)
	            ("C-c l r" . eglot-rename)
	            ("C-c l h" . eldoc)
	            ("C-c l f" . eglot-format)
	            ("C-c l d" . xref-find-definitions-at-mouse))
  :commands eglot)

(use-package dape
  :hook
  (kill-emacs . dape-breakpoint-save)
  (after-init . dape-breakpoint-load)
  :config
  (setq dape-inlay-hints nil))

(repeat-mode)

(add-hook 'prog-mode-hook 'display-line-numbers-mode)

(setq-default tab-width 2)

(setq-default indent-tabs-mode nil)

(add-hook 'before-save-hook 'delete-trailing-whitespace)

(use-package magit
  :bind ("C-c g" . 'magit-status))

(use-package orgit)

(use-package git-link
  :bind (("C-c w l" . git-link)
         ("C-c w c" . git-link-commit)
         ("C-c w h" . git-link-homepage)))

(use-package yasnippet
  :config
  (use-package yasnippet-snippets)
  (yas-reload-all)
  :hook ((prog-mode . yas-minor-mode)
         (LaTeX-mode . yas-minor-mode)))

(setq ediff-window-setup-function 'ediff-setup-windows-plain)
(setq ediff-split-window-function 'split-window-horizontally)

(require 'ansi-color)
(add-hook 'compilation-filter-hook 'ansi-color-compilation-filter)

(setq compilation-scroll-output t)

(setq compilation-ask-about-save nil)

(use-package cmake-mode)

(use-package eldoc-cmake
  :hook (cmake-mode . eldoc-cmake-enable))

(add-to-list 'auto-mode-alist '("\\.php\\'" . php-ts-mode))

(use-package kotlin-mode)

(use-package swift-mode)

(setq auto-mode-alist
      (cons '("\\.m$" . octave-mode) auto-mode-alist))

(use-package ess)

(use-package groovy-mode)

(use-package vlf
  :init (require 'vlf-setup))

(setq org-use-speed-commands t)

(setq org-refile-targets '((nil :maxlevel . 2)
                                (org-agenda-files :maxlevel . 2)))
(setq org-outline-path-complete-in-steps nil)
(setq org-refile-use-outline-path 'file)

(setq org-default-notes-file "~/docs/Agenda.org")
(define-key global-map (kbd "C-c c") 'org-capture)

(setq org-capture-templates
      '(("t" "Task" entry
         (file+olp "~/docs/Agenda.org" "Refile")
         "* TODO [#C] %?\n%a\n%i" :empty-lines 1)
        ("n" "Text Note" entry
         (file+olp "~/docs/Notes.org" "Refile")
         "* %?" :empty-lines 1)))

(use-package mu4e-org
  :after mu4e)

(global-set-key (kbd "C-c L") 'org-store-link)
(global-set-key (kbd "C-c j") 'org-clock-goto)

(setq org-todo-keywords
      '((sequence "TODO(t!)" "WAIT(w!)" "NEXT(n!)" "|"
                  "DONE(d!)" "CANCELLED(c!)")))

(setq org-log-into-drawer t)

(setq org-lowest-priority ?D)

(with-eval-after-load 'org
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

(use-package ox-jira)
(use-package ox-slack)
(use-package ox-gfm)

(with-eval-after-load 'org
  (require 'ox-md nil t)
  (require 'ox-jira nil t)
  (require 'ox-slack nil t)
  (require 'ox-gfm nil t))

(setq org-agenda-restore-windows-after-quit t)

(setq org-list-allow-alphabetical t)

(setq org-startup-indented t)

(setq org-startup-folded 'content)

(global-set-key (kbd "C-c a") 'org-agenda)

(setq org-agenda-files '("~/docs/Agenda.org"))

(setq org-agenda-custom-commands
      '((" " "Block Agenda"
         ((agenda "" ((org-agenda-span 1)))
          (todo "NEXT"
                ((org-agenda-overriding-header "Next Actions")
                 (org-agenda-skip-function
                  '(org-agenda-skip-entry-if 'scheduled))))
          (tags-todo "+refile" ((org-agenda-overriding-header "Refile")))
          (tags-todo "TODO=\"TODO\"+proj-backlog"
                     ((org-agenda-overriding-header "Projects")
                      (org-agenda-skip-function
                       '(org-agenda-skip-entry-if 'scheduled))))
          (tags-todo "TODO=\"TODO\"+sing-backlog"
                     ((org-agenda-overriding-header "Standalone Tasks")
                      (org-agenda-skip-function
                       '(org-agenda-skip-entry-if 'scheduled))))
          (tags-todo "TODO=\"WAIT\"-backlog" ((org-agenda-overriding-header "Waiting")
                                              (org-agenda-skip-function
                                               '(org-agenda-skip-entry-if 'scheduled))))))
        ("b" "Backlog"
         ((agenda "" ((org-agenda-span 1)))
          (todo "NEXT"
                ((org-agenda-overriding-header "Next Actions")))
          (tags-todo "+refile" ((org-agenda-overriding-header "Refile")))
          (tags-todo "TODO=\"TODO\"+proj-backlog"
                     ((org-agenda-overriding-header "Projects")))
          (tags-todo "TODO=\"TODO\"+sing-backlog"
                     ((org-agenda-overriding-header "Standalone Tasks")))
          (tags-todo "TODO=\"WAIT\"-backlog"
                     ((org-agenda-overriding-header "Waiting")))
          (tags-todo "+backlog"
                     ((org-agenda-overriding-header "Backlog")))))))

(setq org-agenda-log-mode-items '(closed clock state))

(setq org-deadline-warning-days 7)

(setq org-agenda-sticky t)

(setq org-agenda-window-setup 'current-window)

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

(setq org-archive-location "::* Archived Items")

(setq org-archive-tag "archive")

(use-package markdown-mode)

(use-package markdown-preview-mode
  :config
  (setq markdown-preview-stylesheets
        (list "https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/2.9.0/github-markdown.min.css"
              "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/styles/default.min.css" "
  <style>
   .markdown-body {
     box-sizing: border-box;
     min-width: 200px;
     max-width: 980px;
     margin: 0 auto;
     padding: 45px;
   }

   @media (max-width: 767px) {
     .markdown-body {
       padding: 15px;
     }
   }
  </style>
"))
  (setq markdown-preview-javascript
        (list "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/highlight.min.js" "
  <script>
   $(document).on('mdContentChange', function() {
     $('pre code').each(function(i, block) {
       hljs.highlightBlock(block);
     });
   });
  </script>
")))

(use-package quarto-mode
  :mode (("\\.Rmd" . poly-quarto-mode)))

(use-package auctex
  :after latex
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

(use-package cdlatex
  :hook (LaTeX-mode . turn-on-cdlatex))

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

(use-package yaml-mode)

(use-package pdf-tools
  :magic ("%PDF" . pdf-view-mode)
  :config
  (pdf-tools-install)
  :bind (:map pdf-view-mode-map
              ("C-s" . 'isearch-forward)))

(use-package mu4e
  :config (setq mail-user-agent 'mu4e-user-agent)
  :bind ("C-c e" . mu4e))

(setq mu4e-headers-fields '((:human-date . 12)
                            (:flags . 4)
                            (:from . 22)
                            (:maildir . 16)
                            (:subject)))

(with-eval-after-load 'mu4e
(add-to-list 'display-buffer-alist
             `(,(regexp-quote mu4e-main-buffer-name)
               display-buffer-same-window)))

(setq mu4e-search-sort-direction 'ascending)

(setq mu4e-get-mail-command "mbsync -c ~/.config/isync/mbsyncrc personal spam")

(defun dalvrosa/remove-nth-element (nth list)
  (if (zerop nth) (cdr list)
    (let ((last (nthcdr (1- nth) list)))
      (setcdr last (cddr last))
      list)))

(with-eval-after-load 'mu4e
  (setq mu4e-marks (dalvrosa/remove-nth-element 5 mu4e-marks))
  (add-to-list 'mu4e-marks
               '(trash
                 :char ("d" . "▼")
                 :prompt "dtrash"
                 :dyn-target (lambda (target msg) (mu4e-get-trash-folder msg))
                 :action (lambda (docid msg target)
                           (mu4e--server-move docid
                                              (mu4e--mark-check-target target) "-N+S-u")))))

(with-eval-after-load "mm-decode"
  (add-to-list 'mm-discouraged-alternatives "text/html")
  (add-to-list 'mm-discouraged-alternatives "text/richtext")
  (add-to-list 'mm-discouraged-alternatives "multipart/related"))

(setq mu4e-context-policy 'pick-first)

(setq mu4e-sent-messages-behavior 'sent)
(setq smtpmail-stream-type 'starttls)
(setq smtpmail-smtp-service 587)
(setq mu4e-change-filenames-when-moving t)

(setq dalvrosa/smtp-server "mail.alvarezrosa.com")
(setq dalvrosa/smtp-port 587)

(with-eval-after-load 'mu4e
  (setq mu4e-contexts
        `( ,(make-mu4e-context
             :name "Personal"
             :match-func (lambda (msg)
                           (when msg
                             (string-match-p "^/Personal" (mu4e-message-field msg :maildir))))
             :vars `(
                     (message-signature-file . "~/docs/Signature.txt")
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
                     (message-signature-file . nil)
                     (mu4e-inbox-folder . "/Spam/Inbox")
                     (mu4e-sent-folder . "/Spam/Sent")
                     (mu4e-drafts-folder . "/Spam/Drafts")
                     (mu4e-trash-folder . "/Spam/Trash")
                     (mu4e-refile-folder . "/Spam/Archive")
                     (user-mail-address . "davids@alvarezrosa.com")
                     (smtpmail-smtp-service . ,dalvrosa/smtp-port)
                     (smtpmail-smtp-server . ,dalvrosa/smtp-server))))))

(with-eval-after-load 'mu4e
  (add-to-list 'mu4e-bookmarks
               '(:name "All Inboxes"
                       :query "maildir:/Personal/Inbox OR maildir:/Spam/Inbox"
                       :key ?i)))

(defun dalvrosa/mu4e-update-mail-and-index ()
  (interactive)
  (mu4e-update-mail-and-index t))

(with-eval-after-load 'mu4e
  (define-key mu4e-main-mode-map (kbd "U") 'dalvrosa/mu4e-update-mail-and-index)
  (define-key mu4e-update-minor-mode-map (kbd "C-c C-u") 'dalvrosa/mu4e-update-mail-and-index))

(setq mu4e-update-interval (* 60 10))
(setq mu4e-hide-index-messages t)

(setq mu4e-modeline-support nil)

(setq smtpmail-queue-dir "~/.local/share/mail/Queue/cur")

(use-package eudc
  :ensure nil
  :after (ldap bbdb org-msg)
  :init (require 'eudc)
  (require 'eudcb-bbdb)
  :bind (:map message-mode-map
              ("<M-tab>" . eudc-expand-inline)
              :map org-msg-edit-mode-map
              ("<M-tab>" . eudc-expand-inline))
  :config
  (eudc-bbdb-set-server "localhost")
  (setq eudc-server-hotlist
        '(("localhost" . bbdb)))
  (bind-key "<M-tab>" 'eudc-expand-inline org-msg-edit-mode-map)
  (setq eudc-inline-expansion-servers 'hotlist))

(use-package bbdb
  :demand t)

(use-package bbdb-vcard
  :after bbdb)

(with-eval-after-load 'mu4e
  (require 'smtpmail)
  (setq message-send-mail-function 'smtpmail-send-it))

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

(setq mu4e-attachment-dir "~/tmp")

(with-eval-after-load 'dired
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
  (setq gnus-dired-mail-mode 'mu4e-user-agent))
(add-hook 'dired-mode-hook 'turn-on-gnus-dired-mode)

(with-eval-after-load 'mu4e
  (require 'mu4e-icalendar)
  (mu4e-icalendar-setup)
  (setq mu4e-icalendar-trash-after-reply t))

(use-package elfeed
  :bind (("C-c f" . 'elfeed)
         :map elfeed-search-mode-map (("v" . 'dalvrosa/elfeed-play-with-mpv)
                                      ("i" . 'dalvrosa/elfeed-ignore)))
  :config (setq elfeed-db-directory "~/.config/emacs/elfeed"
                elfeed-search-filter "@1.5-week-ago -no "
                elfeed-sort-order 'ascending
                elfeed-search-title-max-width 100))

(use-package elfeed-org
  :after elfeed
  :init (elfeed-org)
  :config (setq rmh-elfeed-org-files (list "~/docs/Subscriptions.org")))

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

(setq erc-server "irc.alvarezrosa.com")
(setq erc-nick "dalvrosa")
(setq erc-user-full-name "David Álvarez Rosa")
(setq erc-prompt-for-password nil)
(setq erc-hide-list '("JOIN" "PART" "QUIT"))

(setq erc-kill-buffer-on-part t)
(setq erc-kill-queries-on-quit t)
(setq erc-kill-server-buffer-on-quit t)

(setq erc-fill-function 'erc-fill-static)
(setq erc-fill-static-center 22)
(setq erc-rename-buffers t)

(setq erc-track-exclude-types '("JOIN" "NICK" "PART" "QUIT" "MODE" "AWAY"))
(setq erc-track-exclude-server-buffer t)

(use-package erc-hl-nicks)
