;;; -*- lexical-binding: t; -*-

(add-hook 'emacs-startup-hook
          (lambda ()
            (require 'gcmh)
            (setq gcmh-idle-delay 'auto
                  gcmh-high-cons-threshold (* 256 1024 1024))
            (gcmh-mode 1)))

;; Single VC backend inscreases booting speed
(setq vc-handled-backends '(Git))

(with-eval-after-load 'package
  (add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/"))
  (setopt package-native-compile t))
(eval-and-compile (setq use-package-always-defer t))

(add-hook 'org-babel-post-tangle-hook
          (lambda ()
            (when (equal (buffer-file-name) (locate-user-emacs-file "init.el"))
              (byte-compile-file (buffer-file-name)))))

(defvar dalvrosa/preload-queue
  '(;; Org, bottom-up, then Babel and the exporters
    calendar find-func format-spec org-macs org-compat org-faces
    org-entities org-list org-pcomplete org-src org-footnote org-macro
    ob org org-agenda agenda-files org-capture ox
    ;; Magit, with Forge and its database
    dash transient with-editor magit forge
    ispell flyspell
    ghostel dired mu4e latex tramp pdf-tools elfeed bbdb vlf-setup)
  "Libraries to preload while Emacs is idle, in order.")

(defun dalvrosa/preload-next ()
  "Load the next entry in `dalvrosa/preload-queue', then re-arm."
  (let ((inhibit-message t))
    (ignore-errors
      (pcase (pop dalvrosa/preload-queue)
        ('nil)
        ('agenda-files (org-agenda-prepare-buffers (org-agenda-files)))
        (lib (unless (featurep lib) (require lib nil t))))))
  (when dalvrosa/preload-queue
    (if (current-idle-time)
        (run-with-timer 0.2 nil #'dalvrosa/preload-next)
      (run-with-idle-timer 0.75 nil #'dalvrosa/preload-next))))

(run-with-idle-timer 1 nil #'dalvrosa/preload-next)

(setq user-full-name "David Álvarez Rosa")
(setq user-mail-address "david@alvarezrosa.com")

(run-with-idle-timer 0.1 nil
                     (lambda ()
                       (require 'server)
                       (when (server-running-p)
                         (setq server-name (format "server-%d" (emacs-pid))))
                       (unless (server-running-p) (server-start))))

(setq custom-file "~/.config/emacs/custom.el")
(load custom-file t)

(setq auth-sources '("~/.local/share/authinfo.gpg"))

(setq-default dired-listing-switches "-alh --group-directories-first")
(setq dired-auto-revert-buffer t)
(setq dired-guess-shell-alist-user
      '(("\\.\\(png\\|jpe?g\\|webp\\)\\'" "satty -f")))

(defun dalvrosa/dired-goto-top ()
  (goto-char (point-min))
  (while (and (not (eobp)) (not (dired-move-to-filename)))
    (forward-line 1)))

(defun dalvrosa/dired-sort-toggle ()
  (setq dired-actual-switches
        (if (string-match-p dired-sort-by-date-regexp dired-actual-switches)
            dired-listing-switches
          "-alh -t"))
  (dired-sort-set-mode-line)
  (revert-buffer)
  (dalvrosa/dired-goto-top))
(advice-add 'dired-sort-toggle :override #'dalvrosa/dired-sort-toggle)

(use-package dired-narrow
  :after dired
  :bind (:map dired-mode-map
              ("/" . dired-narrow-fuzzy)))

(use-package dired-subtree
  :after dired
  :bind
  ( :map dired-mode-map
    ("<tab>" . dired-subtree-toggle))
  :config
  (setq dired-subtree-use-backgrounds nil)
  (add-hook 'dired-subtree-after-insert-hook #'nerd-icons-dired--refresh))

(setq backup-directory-alist
      `((".*" . ,temporary-file-directory)))
(setq auto-save-file-name-transforms
      `((".*" ,temporary-file-directory t)))
(setq lock-file-name-transforms
      `((".*" ,temporary-file-directory t)))

(setq global-auto-revert-non-file-buffers t)
(setq auto-revert-verbose nil)
(with-eval-after-load 'autorevert
  (setopt auto-revert-avoid-polling t))
(run-with-idle-timer 0.1 nil #'global-auto-revert-mode)

(setq split-width-threshold 210)

(keymap-global-set "C-x C-b" 'ibuffer)
(setq ibuffer-expert t)
(keymap-global-set "C-x k" 'kill-current-buffer)

(put 'narrow-to-region 'disabled nil)
(put 'narrow-to-page 'disabled nil)
(put 'LaTeX-narrow-to-environment 'disabled nil)

(defun dalvrosa/split-and-follow-horizontally ()
  (interactive)
  (split-window-below)
  (balance-windows)
  (other-window 1))
(keymap-global-set "C-x 2" 'dalvrosa/split-and-follow-horizontally)

(defun dalvrosa/split-and-follow-vertically ()
  (interactive)
  (split-window-right)
  (balance-windows)
  (other-window 1))
(keymap-global-set "C-x 3" 'dalvrosa/split-and-follow-vertically)

(keymap-global-set "C-x K" 'kill-buffer-and-window)

(defun dalvrosa/kill-all-other-buffers ()
  "Kill all buffers except current and *scratch*."
  (interactive)
  (delete-other-windows)
  (let ((scratch (get-buffer "*scratch*")))
    (mapc 'kill-buffer (delq scratch (delq (current-buffer) (buffer-list))))))
(keymap-global-set "C-c k" 'dalvrosa/kill-all-other-buffers)

(run-with-idle-timer 0.1 nil #'winner-mode)

(keymap-global-set "M-o" 'other-window)

(setq frame-title-format '("" "%b - GNU Emacs at " system-name))

(defmacro dalvrosa/i3-msg (&rest args)
  `(start-process "emacs-i3-windmove" nil "i3-msg" ,@args))

(defun dalvrosa/emacs-i3-windmove (dir)
  (let ((other-window (windmove-find-other-window dir)))
    (if (or (null other-window) (window-minibuffer-p other-window))
        (dalvrosa/i3-msg "focus" (symbol-name dir))
      (windmove-do-window-select dir))))

(defun dalvrosa/emacs-i3-move-window (dir)
  (let ((other-window (windmove-find-other-window dir)))
    (cond
     ((and other-window (not (window-minibuffer-p other-window)))
      (window-swap-states (selected-window) other-window))
     ;; Already spanning the frame in DIR: let i3 move the frame.
     ((if (memq dir '(up down)) (window-full-width-p) (window-full-height-p))
      (dalvrosa/i3-msg "move" (symbol-name dir)))
     ;; No window in DIR but the split can be rearranged: re-place
     ;; the selected window on that side of the frame, like i3 does
     ;; when moving perpendicular to the current split.
     (t
      (let ((state (window-state-get (selected-window)))
            (side (pcase dir ('up 'above) ('down 'below) (other other))))
        (delete-window)
        (let ((new-window (split-window (frame-root-window) nil side)))
          (window-state-put state new-window t)
          (select-window new-window)))))))

(defun dalvrosa/emacs-i3-integration (command)
  (require 'windmove)
  (pcase command
    ((rx bos "focus")
     (dalvrosa/emacs-i3-windmove
      (intern (elt (split-string command) 1))))
    ((rx bos "move")
     (dalvrosa/emacs-i3-move-window
      (intern (elt (split-string command) 1))))
    (_ (dalvrosa/i3-msg command))))

(setq-default fill-column 79)
(add-hook 'text-mode-hook
          (lambda ()
            (turn-on-auto-fill)
            (setq fill-column 72)))

(keymap-global-set "M-Q" #'unfill-paragraph)

(defun dalvrosa/unfill-paragraph-and-kill (beg end)
  "Save the current region to the kill ring after unfilling it."
  (interactive "r")
  (let ((mode major-mode))
    (copy-region-as-kill beg end)
    (with-temp-buffer
      (funcall mode)
      (yank)
      (unfill-paragraph nil (point-min) (point-max))
      (kill-region (point-min) (point-max)))))
(keymap-global-set "M-W" 'dalvrosa/unfill-paragraph-and-kill)

(keymap-set indent-rigidly-map "<" 'indent-rigidly-left)
(keymap-set indent-rigidly-map "b" 'indent-rigidly-left)
(keymap-set indent-rigidly-map ">" 'indent-rigidly-right)
(keymap-set indent-rigidly-map "f" 'indent-rigidly-right)
(keymap-set indent-rigidly-map "B" 'indent-rigidly-left-to-tab-stop)
(keymap-set indent-rigidly-map "F" 'indent-rigidly-right-to-tab-stop)

(global-subword-mode 1)

(setq use-short-answers t)

(setq shift-select-mode nil)
(delete-selection-mode 1)

(use-package expand-region
  :bind ("C-=" . er/expand-region))

(put 'upcase-region 'disabled nil)
(put 'downcase-region 'disabled nil)

(setq scroll-conservatively 101)
(setq scroll-preserve-screen-position t)
(setq fast-but-imprecise-scrolling t)

(keymap-global-set "M-n" 'forward-paragraph)
(keymap-global-set "M-p" 'backward-paragraph)
(keymap-global-set "M-N" 'scroll-up-line)
(keymap-global-set "M-P" 'scroll-down-line)

(put 'set-goal-column 'disabled nil)
(put 'scroll-left 'disabled nil)

(setq read-process-output-max (* 1024 1024))
(setq inhibit-compacting-font-caches t)
(setq redisplay-skip-fontification-on-input t)
(setq auto-mode-case-fold nil)
(setq-default bidi-paragraph-direction 'left-to-right)
(setq bidi-inhibit-bpa t)
(run-with-idle-timer 0.1 nil #'global-so-long-mode)

(electric-pair-mode t)

(setq shr-use-fonts nil)
(setq shr-width 72)

(use-package vertico
  :init
  (vertico-mode)
  :bind (:map vertico-map
              ("M-DEL" . vertico-directory-delete-word))
  :hook (rfn-eshadow-update-overlay . vertico-directory-tidy))

(use-package consult
  :bind (
         ("C-c m" . consult-man)
         ;; ("C-c i" . consult-info)
         ("C-x b" . consult-buffer)                ;; orig. switch-to-buffer
         ("C-x 4 b" . consult-buffer-other-window) ;; orig. switch-to-buffer-other-window
         ("C-x 5 b" . consult-buffer-other-frame)  ;; orig. switch-to-buffer-other-frame
         ("C-x t b" . consult-buffer-other-tab)    ;; orig. switch-to-buffer-other-tab
         ("C-x r b" . consult-bookmark)            ;; orig. bookmark-jump
         ("C-x p b" . consult-project-buffer)      ;; orig. project-switch-to-buffer
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
  :config
  (consult-customize
   consult-theme :preview-key '(:debounce 0.2 any)
   consult-buffer consult-buffer-other-tab consult-buffer-other-window
   consult-project-buffer
   consult-buffer-other-frame consult-ripgrep consult-git-grep consult-grep
   consult-man consult-bookmark consult-recent-file consult-xref
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
  (setq text-mode-ispell-word-completion nil)
  :hook (org-mode . (lambda () (setq-local corfu-auto nil))))

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
  :ensure nil
  :init (run-with-idle-timer 0.1 nil #'which-key-mode))

(setq ispell-program-name "hunspell")
(setq ispell-dictionary "en_US")

(add-hook 'text-mode-hook 'flyspell-mode)
(with-eval-after-load 'flyspell
  (keymap-unset flyspell-mode-map "C-." t)
  (keymap-unset flyspell-mode-map "C-;" t))
;; (add-hook 'prog-mode-hook 'flyspell-prog-mode)

(defun dalvrosa/flyspell-cycle ()
  (interactive)
  (cond
   ((not flyspell-mode)
    (ispell-change-dictionary "en_US")
    (flyspell-mode 1)
    (flyspell-buffer))
   ((string= (or ispell-local-dictionary ispell-dictionary) "en_US")
    (ispell-change-dictionary "es_ES")
    (flyspell-buffer))
   ((string= (or ispell-local-dictionary ispell-dictionary) "es_ES")
    (flyspell-mode -1))))

(keymap-global-set "C-c s" #'dalvrosa/flyspell-cycle)
(defvar-keymap dalvrosa/flyspell-cycle-repeat-map "s" #'dalvrosa/flyspell-cycle)
(put 'dalvrosa/flyspell-cycle 'repeat-map 'dalvrosa/flyspell-cycle-repeat-map)

(setq confirm-kill-processes nil)

(defun dalvrosa/duckduckgo (query)
  (interactive
   (list (if (use-region-p)
             (buffer-substring-no-properties (region-beginning) (region-end))
           (read-string "DuckDuckGo: "))))
  (browse-url (concat "https://duckduckgo.com/?q=" (url-hexify-string query))))
(keymap-global-set "C-c w d" #'dalvrosa/duckduckgo)

(defun dalvrosa/new-gpt-chat ()
  (interactive)
  (switch-to-buffer (gptel (generate-new-buffer "*ChatGPT*"))))

(defun dalvrosa/gptel-send ()
  (interactive)
  (goto-char (point-max))
  (gptel-send))

(use-package gptel
  :bind
  (("C-c h" . dalvrosa/new-gpt-chat)
   (:map gptel-mode-map
         ("RET" . dalvrosa/gptel-send)))
  :config
  (setq gptel-backend (gptel-make-anthropic "Claude" :stream t :key gptel-api-key))
  (setq gptel-model 'claude-haiku-5-5)
  (setq gptel-default-mode 'org-mode)
  (add-hook 'gptel-post-response-functions #'gptel-end-of-response)
  (setq gptel-system-prompt
        "You are a large language model living in Emacs.  Answer directly and concisely: no preamble, no summary, no unrequested caveats or alternatives.")
  :hook ((gptel-mode . visual-line-mode)
         (gptel-mode . (lambda () (flyspell-mode -1)))))

(setq tramp-default-method "ssh")
(setq tramp-allow-unsafe-temporary-files t)
(setq tramp-use-connection-share nil)
(setq tramp-histfile-override t)
(setq tramp-verbose 1)
(setq remote-file-name-inhibit-locks t)
(setq remote-file-name-inhibit-auto-save-visited t)
(setq backup-enable-predicate
      (lambda (name) (and (normal-backup-enable-predicate name) (not (file-remote-p name)))))

(let ((src (expand-file-name "themes/modus-themes.el" data-directory))
      (elc (locate-user-emacs-file "modus-themes.elc")))
  (when (file-newer-than-file-p src elc)
    (let ((byte-compile-dest-file-function (lambda (_) elc)))
      (byte-compile-file src)))
  (load elc nil t))

(defun dalvrosa/set-background-alpha ()
  (let ((alpha (if (eq (car custom-enabled-themes) 'modus-vivendi) 90 100)))
    (dolist (frame (frame-list))
      (set-frame-parameter frame 'alpha-background alpha))
    (setf (alist-get 'alpha-background default-frame-alist) alpha)))
(add-hook 'modus-themes-after-load-theme-hook #'dalvrosa/set-background-alpha)

(if (string-match-p "prefer-dark"
                    (shell-command-to-string
                     "gsettings get org.gnome.desktop.interface color-scheme"))
    (load-theme 'modus-vivendi)
  (load-theme 'modus-operandi))
(dalvrosa/set-background-alpha)
(keymap-global-set "C-c d" 'modus-themes-toggle)

(use-package nerd-icons)

(use-package nerd-icons-completion
  :init
  (run-with-idle-timer 0.05 nil
                       (lambda ()
                         (nerd-icons-completion-mode)
                         (nerd-icons-completion-marginalia-setup))))

(use-package nerd-icons-corfu
  :init
  (with-eval-after-load 'corfu
    (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter)))

(use-package nerd-icons-dired
  :hook
  (dired-mode . nerd-icons-dired-mode))

(use-package doom-modeline
  :init (run-with-idle-timer 0.05 nil #'doom-modeline-mode)
  :config
  (setq doom-modeline-buffer-encoding nil)
  (defun dalvrosa/doom-modeline-height (&rest _)
    (setq doom-modeline-height (round (* 13 (frame-char-height)) 9))
    (doom-modeline-refresh-bars))
  (dalvrosa/doom-modeline-height)
  (advice-add 'dynamic-setting-handle-config-changed-event
              :after #'dalvrosa/doom-modeline-height)
  (setq doom-modeline-buffer-file-name-style 'relative-from-project))

(column-number-mode 1)

(use-package nyan-mode
  :after doom-modeline
  :init (nyan-mode))

(tooltip-mode 0)
(setq inhibit-startup-screen t)

(when window-system (global-hl-line-mode t))

(use-package olivetti
  :config
  (setq-default olivetti-body-width (+ fill-column 10))
  (setq olivetti-style 'fancy)
  :bind ("C-c o" . olivetti-mode))

(run-with-idle-timer 0.2 nil (lambda () (setopt treesit-enabled-modes t)))

(setq xref-search-program 'ripgrep)

(use-package flymake
  :ensure nil
  :hook (prog-mode . (lambda ()
                       (unless (derived-mode-p 'lisp-interaction-mode)
                         (flymake-mode))))
  :bind (:map flymake-mode-map
              ("C-c ! n" . flymake-goto-next-error)
              ("C-c ! p" . flymake-goto-prev-error)
              ("C-c ! l" . flymake-show-buffer-diagnostics)))

(defun dalvrosa/ghostel-yank-output ()
  "Copy the output of the last command to the kill ring."
  (interactive)
  (let* ((input-end (or (previous-single-property-change (point-max) 'ghostel-input)
                        (user-error "No command found")))
         (start (save-excursion (goto-char input-end) (forward-line 1) (point)))
         (end (or (text-property-any start (point-max) 'ghostel-prompt t) (point-max)))
         (output (string-trim-right (buffer-substring-no-properties start end))))
    (if (string-empty-p output)
        (user-error "Last command produced no output")
      (kill-new output)
      (message "Copied last command output"))))

(use-package ghostel
  :init
  (setq ghostel-module-directory (expand-file-name "ghostel/" user-emacs-directory))
  :config
  (setopt ghostel-keymap-exceptions (cons "M-o" ghostel-keymap-exceptions))
  (setq ghostel-buffer-name-function nil)
  (setq ghostel-query-before-killing nil)
  (setq ghostel-max-scrollback (* 10 1024 1024))
  (setq ghostel-timer-delay 0.005)
  (add-to-list 'ghostel-eval-cmds '("man" man))
  (setf (alist-get "ssh" ghostel-tramp-shells nil nil #'equal) '("zsh"))
  :bind (("C-c t" . ghostel)
         :map ghostel-semi-char-mode-map
         ("C-q" . ghostel-send-next-key)
         ("C-M-p" . ghostel-copy-mode)
         ("M-w" . dalvrosa/ghostel-yank-output)
         :map ghostel-readonly-mode-map
         ("M-w" . (lambda () (interactive)
                    (let (ghostel-readonly-fast-exit) (ghostel-readonly-copy))))))

(defun dalvrosa/ghostel-project-claude (&optional new)
  "Switch to this project's Claude Code session, starting one if needed.
With prefix arg NEW, start an additional session instead."
  (interactive "P")
  (require 'ghostel)
  (let* ((default-directory (project-root (project-current t)))
         (name (project-prefixed-buffer-name "claude"))
         (buffer (and (not new) (get-buffer name))))
    (if buffer
        (pop-to-buffer-same-window buffer)
      (let ((ghostel-shell (list "claude" "--dangerously-skip-permissions")))
        (ghostel-create name '((display-buffer-same-window)))))))

(with-eval-after-load 'project
  (add-to-list 'project-switch-commands '(consult-project-buffer "Find buffer") t)
  (add-to-list 'project-switch-commands '(magit-project-status "Magit") t)
  (add-to-list 'project-switch-commands '(ghostel-project "Ghostel") t)
  (add-to-list 'project-switch-commands '(dalvrosa/ghostel-project-claude "Claude") t)
  (add-to-list 'project-switch-commands '(errand-agents "Errand") t)
  (keymap-set project-prefix-map "b" 'consult-project-buffer)
  (keymap-set project-prefix-map "g" 'magit-project-status)
  (keymap-set project-prefix-map "s" 'project-find-regexp)
  (keymap-set project-prefix-map "h" 'dalvrosa/ghostel-project-claude)
  (keymap-set project-prefix-map "j" 'ghostel-project-list-buffers)
  (keymap-set project-prefix-map "t" 'ghostel-project)
  (keymap-set project-prefix-map "e" 'errand-agents))

(defun dalvrosa/claude-scratch ()
  (interactive)
  (require 'ghostel)
  (let ((default-directory
         (file-name-as-directory
          (make-temp-file (expand-file-name "~/tmp/claude-") t)))
        (ghostel-shell (list "claude" "--dangerously-skip-permissions")))
    (ghostel-create "*claude-scratch*" '((display-buffer-same-window)))))

(keymap-global-set "C-c q" 'dalvrosa/claude-scratch)

(use-package errand
  :ensure nil
  :load-path "~/dev/errand"
  :commands errand-agents
  :custom (errand-workers '("homelab" "local")))

(use-package eglot
  :ensure nil
  :config
  (setq eglot-ignored-server-capabilities '(:inlayHintProvider))
  (setq eglot-autoshutdown t)
  (setq eglot-events-buffer-config '(:size 0 :format full))
  (setf (alist-get '(python-mode python-ts-mode) eglot-server-programs nil nil #'equal)
        '("ty" "server"))
  :hook ((c++-ts-mode . eglot-ensure)
         (c-ts-mode . eglot-ensure)
         (rust-ts-mode . eglot-ensure)
         (python-ts-mode . eglot-ensure)
         (LaTeX-mode . eglot-ensure)
         (cmake-ts-mode . eglot-ensure)
         (php-ts-mode . eglot-ensure)
         (typescript-ts-mode . eglot-ensure)
         (js-ts-mode . eglot-ensure))
  :bind (:map eglot-mode-map
	            ("C-c l a" . eglot-code-actions)
	            ("C-c l r" . eglot-rename)
	            ("C-c l h" . eldoc)
	            ("C-c l f" . eglot-format))
  :commands eglot)

(use-package dape
  :config
  (setq dape-inlay-hints nil)
  (dape-breakpoint-load)
  (add-hook 'kill-emacs-hook #'dape-breakpoint-save))

(run-with-idle-timer 0.1 nil #'repeat-mode)

(add-hook 'prog-mode-hook 'display-line-numbers-mode)

(setq-default tab-width 2)
(setq-default indent-tabs-mode nil)

(add-hook 'before-save-hook
          (lambda () (unless (derived-mode-p 'message-mode)
                       (delete-trailing-whitespace))))

(use-package magit
  :bind ("C-c g" . magit-status)
  :custom (magit-save-repository-buffers 'dontask))

(use-package orgit)

(use-package forge :after magit :defer nil)

(use-package orgit-forge :after forge :demand t)

(use-package git-link
  :bind (("C-c w l" . git-link)
         ("C-c w c" . git-link-commit)
         ("C-c w h" . git-link-homepage)))

(setq ediff-window-setup-function 'ediff-setup-windows-plain)
(setq ediff-split-window-function 'split-window-horizontally)

(add-hook 'compilation-filter-hook 'ansi-color-compilation-filter)
(setq compilation-scroll-output t)
(setq compilation-ask-about-save nil)

(use-package vlf)

(setq org-modules '(ol-bbdb))

(setq org-use-speed-commands t)

(setq org-default-notes-file "~/docs/Agenda.org")
(keymap-global-set "C-c c" 'org-capture)

(setq org-capture-templates
      '(("t" "Task" entry
         (file+olp "~/docs/Agenda.org" "Standalone")
         "* TODO [#B] %?\n%a\n%i" :empty-lines 1)
        ("n" "Text Note" entry
         (file+olp "~/docs/Notes.org" "Notes")
         "* %?" :empty-lines 1)
        ("b" "Blog Post" entry
         (file "~/dev/personal-website/Content.org")
         "* TODO [#B] %?" :empty-lines 1 :prepend t)))

(keymap-global-set "C-c L" 'org-store-link)
(keymap-global-set "C-c j" 'org-clock-goto)

(setq org-todo-keywords
      '((sequence "TODO(t)" "WAIT(w)" "NEXT(n)" "|" "DONE(d)" "CANCELLED(c)")))
(setq org-log-into-drawer t)

(setq org-priority-lowest ?D)

(with-eval-after-load 'org
      (org-babel-do-load-languages
       'org-babel-load-languages
       '((C . t)
         (python . t)
         (latex . t)
         (shell . t)
         (plantuml . t))))

(setq org-confirm-babel-evaluate nil)
(setq org-plantuml-exec-mode 'plantuml)

(setq org-export-backends '(ascii html latex md odt))
(use-package ox-hugo :after ox :demand t)

(setq org-agenda-restore-windows-after-quit t)
(setq org-list-allow-alphabetical t)
(setq org-startup-indented t)
(setq org-startup-folded 'content)

(keymap-global-set "C-c a" 'org-agenda)
(setq org-agenda-files '("~/docs/Agenda.org" "~/docs/Calendar.org" "~/dev/personal-website/Content.org"))

(setq org-agenda-skip-deadline-if-done t)
(setq org-agenda-skip-scheduled-if-done t)

(defun dalvrosa/agenda-blocks (skip-scheduled)
  (let ((opts (when skip-scheduled
                '((org-agenda-skip-function '(org-agenda-skip-entry-if 'scheduled))))))
    `((agenda "" ((org-agenda-span 1)))
      ,@(mapcar (lambda (block)
                  `(,(nth 0 block) ,(nth 1 block)
                    ((org-agenda-overriding-header ,(nth 2 block)) ,@opts)))
                '((todo "NEXT" "Next Actions")
                  (tags-todo "TODO=\"TODO\"-work-blog-unwall-backlog" "Standalone")
                  (tags-todo "TODO=\"TODO\"+unwall-backlog" "Unwall")
                  (tags-todo "TODO=\"TODO\"+blog-backlog" "Blog")
                  (tags-todo "TODO=\"TODO\"+work-backlog" "Work")
                  (tags-todo "TODO=\"WAIT\"-backlog" "Waiting"))))))

(setq org-agenda-custom-commands
      `((" " "Block Agenda" ,(dalvrosa/agenda-blocks t))
        ("b" "Backlog" (,@(dalvrosa/agenda-blocks nil)
                        (tags-todo "+backlog" ((org-agenda-overriding-header "Backlog")))))))

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
  (save-excursion
    (goto-char (point-min))
    (let* ((inhibit-read-only t)
           (blank-line-re "^\\s-*$")
           (content-line-count (if (looking-at-p blank-line-re) 0 1))
           (start-pos (point))
           (block-re (format "%c\\{10,\\}" org-agenda-block-separator)))
      (while (and (not (eobp)) (forward-line))
        (cond
         ((looking-at-p block-re)
          (when (< content-line-count 2)
            (delete-region start-pos (1+ (line-beginning-position))))
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
        (delete-region (point) (1+ (line-end-position)))))))

(add-hook 'org-agenda-finalize-hook #'dalvrosa/org-agenda-delete-empty-blocks)

(setq org-archive-location "::* Archived Items")
(setq org-archive-tag "archive")

(use-package markdown-mode)

(use-package plantuml-mode
  :mode ("\\.puml\\'" . plantuml-mode)
  :config
  (setq plantuml-default-exec-mode 'executable))

(use-package auctex
  :after latex
  :config
  ;; Always in math mode
  (add-hook 'LaTeX-mode-hook 'LaTeX-math-mode)
  ;; Set PDF viewer to pdf-tools with correlation
  (setq TeX-view-program-selection '((output-pdf "PDF Tools")))
  (add-hook 'LaTeX-mode-hook 'TeX-source-correlate-mode)
  ;; Enable electric behavior.
  (setq TeX-electric-sub-and-superscript t)
  ;; I want \items indented.
  (setq LaTeX-item-indent 0)
  :bind (
         :map LaTeX-mode-map
         ;; Command for cleaning auxiliary files
         ("C-x M-k" . TeX-clean)))

(use-package cdlatex
  :hook (LaTeX-mode . turn-on-cdlatex))

(setq TeX-command-extra-options "-shell-escape")
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
  :magic ("%PDF" . pdf-view-mode)
  :config
  (pdf-tools-install)
  :bind (:map pdf-view-mode-map
              ("C-s" . isearch-forward)))

(use-package mu4e
  :ensure nil
  :config
  (setq mail-user-agent 'mu4e-user-agent)
  (setq message-mail-user-agent 'mu4e-user-agent)
  :bind ("C-c e" . dalvrosa/mu4e-inbox))

(defun dalvrosa/mu4e-inbox ()
  "Open mu4e on the All Inboxes view and start a background sync."
  (interactive)
  (require 'mu4e)
  (unless mu4e--initialized
    (mu4e--init-handlers))
  (mu4e--start
   (lambda ()
     (mu4e-search-bookmark (mu4e-get-bookmark-query ?i))
     (dalvrosa/mu4e-update-mail-and-index))))

(defvar dalvrosa/mu4e-headers-fields-wide
  '((:human-date . 12)
    (:flags . 4)
    (:from . 22)
    (:maildir . 16)
    (:subject))
  "Header columns shown in wide windows.")

(setq mu4e-headers-fields dalvrosa/mu4e-headers-fields-wide)

(add-hook 'mu4e-search-hook
          (lambda (_query)
            (let* ((buf (mu4e-get-headers-buffer))
                   (win (and buf (get-buffer-window buf)))
                   (width (if win (window-width win) (window-width))))
              (setq mu4e-headers-fields
                    (if (< width 110)
                        '((:from . 22) (:subject))
                      dalvrosa/mu4e-headers-fields-wide)))))

(with-eval-after-load 'mu4e
(add-to-list 'display-buffer-alist
             `(,(regexp-quote mu4e-main-buffer-name)
               display-buffer-same-window)))

(add-hook 'mu4e-search-hook
          (lambda (query)
            (setq-local mu4e-search-sort-direction
                        (if (string-match-p "/Inbox" (or query ""))
                            'ascending 'descending))))

(setq mu4e-get-mail-command "MAILSYNC_NO_INDEX=1 ~/.local/bin/mailsync")

(setq mu4e-context-policy 'pick-first)
(setq mu4e-compose-context-policy 'pick-first)
(setq smtpmail-stream-type 'ssl)
(setq mu4e-change-filenames-when-moving t)
(setq mu4e-trash-without-flag t)

(with-eval-after-load 'mu4e
  (setq mu4e-contexts
        `( ,(make-mu4e-context
             :name "Personal"
             :match-func (lambda (msg)
                           (when msg
                             (string-match-p "^/Personal" (mu4e-message-field msg :maildir))))
             :vars '(
                     (message-signature-file . "~/docs/Signature.txt")
                     (mu4e-sent-folder . "/Personal/Sent")
                     (mu4e-drafts-folder . "/Personal/Drafts")
                     (mu4e-trash-folder . "/Personal/Trash")
                     (mu4e-refile-folder . "/Personal/Archive")
                     (user-mail-address . "david@alvarezrosa.com")
                     (smtpmail-smtp-server . "mail.alvarezrosa.com")
                     (smtpmail-smtp-service . 465))))))

(with-eval-after-load 'mu4e
  (add-to-list 'mu4e-bookmarks
               '(:name "All Inboxes"
                       :query "maildir:/Personal/Inbox"
                       :key ?i)))

(defun dalvrosa/mu4e-update-mail-and-index ()
  (interactive)
  (mu4e-update-mail-and-index t))

(defun dalvrosa/mu4e-index-soon ()
  "Index mail; the mu server queues it behind a running index."
  (when (and (fboundp 'mu4e-running-p) (mu4e-running-p))
    (let ((inhibit-message t))
      (mu4e-update-index))))

(with-eval-after-load 'mu4e
  (keymap-set mu4e-main-mode-map "U" 'dalvrosa/mu4e-update-mail-and-index)
  (keymap-set mu4e-update-minor-mode-map "C-c C-u" 'dalvrosa/mu4e-update-mail-and-index))

(setq mu4e-headers-auto-update nil)

(defun dalvrosa/mu4e-headers-refresh (&rest _)
  "Rerun the headers search when visible and without pending marks."
  (when-let* ((buf (mu4e-get-headers-buffer))
              (win (get-buffer-window buf t)))
    (with-selected-window win
      (when (zerop (mu4e-mark-marks-num))
        (let ((mu4e--search-background t))
          (mu4e-search-rerun))))))

(with-eval-after-load 'mu4e
  (add-hook 'mu4e-index-updated-hook #'dalvrosa/mu4e-headers-refresh)
  (add-hook 'mu4e-headers-mode-hook
            (lambda ()
              (add-hook 'window-buffer-change-functions
                        #'dalvrosa/mu4e-headers-refresh nil t))))

(setq mu4e-hide-index-messages t)
(setq mu4e-modeline-support nil)

(use-package bbdb
  :custom (bbdb-file "~/.local/state/emacs/bbdb")
  :config
  (with-eval-after-load 'ol-bbdb
    (setq org-bbdb-anniversary-field 'birthday))
  (defvar dalvrosa/contacts-dir "~/.local/share/contacts/"
    "Local vCard mirror synced from Nextcloud by vdirsyncer.")
  (defun dalvrosa/contacts-refresh ()
    "Rebuild BBDB from the Nextcloud-synced vCard mirror."
    (interactive)
    (require 'bbdb-vcard)
    (let ((bbdb-vcard-try-merge nil))
      (bbdb-delete-records (bbdb-records) t)
      (dolist (f (directory-files-recursively dalvrosa/contacts-dir "\\.vcf\\'"))
        (bbdb-vcard-import-file f))
      (bbdb-save))))

(use-package bbdb-vcard
  :after bbdb)

(defun dalvrosa/bbdb-mail-candidates ()
  (let (acc)
    (dolist (r (bbdb-records))
      (dolist (m (bbdb-record-mail r))
        (push (format "%s <%s>" (bbdb-record-name r) m) acc)))
    (nreverse acc)))

(defun dalvrosa/bbdb-capf ()
  (when (and (derived-mode-p 'message-mode)
             (message-point-in-header-p)
             (save-excursion
               (beginning-of-line)
               (looking-at-p "\\(To\\|Cc\\|Bcc\\|Reply-To\\):")))
    (let ((end (point))
          (beg (save-excursion (skip-chars-backward "^:,")
                               (skip-chars-forward " \t") (point))))
      (list beg end (dalvrosa/bbdb-mail-candidates) :exclusive 'no))))

(add-hook 'mu4e-compose-mode-hook
          (lambda () (add-hook 'completion-at-point-functions
                               #'dalvrosa/bbdb-capf -50 t)))

(with-eval-after-load 'mu4e
  (require 'smtpmail)
  (setq message-send-mail-function 'smtpmail-send-it))

(setq message-citation-line-function 'message-insert-formatted-citation-line)
(setq message-citation-line-format "On %a %d %b %Y at %R, %N wrote:")
(setq message-cite-reply-position 'above)

(defun dalvrosa/mu4e-signature-above-citation ()
  (save-excursion
    (when (and (eq mu4e-compose-type 'reply) (message-goto-signature))
      (forward-line -1)
      (let ((sig (delete-and-extract-region (point) (point-max))))
        (message-goto-body)
        (insert "\n" sig "\n")))))

(add-hook 'mu4e-compose-mode-hook #'dalvrosa/mu4e-signature-above-citation)

(setq message-kill-buffer-on-exit t)

(setq mu4e-attachment-dir "~/tmp")

(setq gnus-dired-mail-mode 'message-user-agent)
(add-hook 'dired-mode-hook 'turn-on-gnus-dired-mode)

(defun dalvrosa/calendar-accept (data)
  (unless (eq (cadr data) 'declined)
    (let ((file (make-temp-file "invite" nil ".ics")))
      (mm-save-part-to-file (car data) file)
      (make-process :name "dav-sync" :buffer " *dav-sync*"
                    :command (list "sh" "-c" "dav-sync --accept \"$1\"; rm -f \"$1\"" "sh" file)))))

(with-eval-after-load 'mu4e
  (require 'mu4e-icalendar)
  (gnus-icalendar-setup)
  (advice-add 'mu4e-icalendar-reply :after #'dalvrosa/calendar-accept))

(use-package elfeed
  :bind (("C-c f" . elfeed)
         :map elfeed-search-mode-map (("v" . dalvrosa/elfeed-play-with-mpv)
                                      ("i" . dalvrosa/elfeed-ignore)))
  :init (setq elfeed-search-filter "@1-week-ago -no ")
  :config (setq elfeed-db-directory "~/.config/emacs/elfeed"
                elfeed-search-sort-order 'ascending
                elfeed-search-title-max-width 100))

(use-package elfeed-org
  :after elfeed
  :init (elfeed-org)
  :config (setq rmh-elfeed-org-files (list "~/docs/Subscriptions.org")))

(defun dalvrosa/elfeed-play-with-mpv ()
  (interactive)
  (let ((url (elfeed-entry-link (elfeed-search-selected :single))))
    (start-process "elfeed-mpv" nil "mpv" "--ytdl-format=[height<=720]" url))
  (elfeed-search-untag-unread))

(defun dalvrosa/elfeed-ignore ()
  (interactive)
  (let ((entry (elfeed-search-selected :single)))
    (elfeed-tag entry 'no)
    (elfeed-search-update-entry entry)
    (forward-line)))

(keymap-global-set "C-c i" 'erc-tls)

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

(use-package ement
  :config
  (setopt ement-save-sessions t)
  (setq ement-notify-notification-predicates nil)
  (setq ement-room-send-read-receipts nil))

(defun dalvrosa/ement-connect ()
  "Show the Matrix room list, connecting first if needed.
Reuses a saved session or, on first login, the authentication file."
  (interactive)
  (require 'ement)
  (if ement-sessions
      (ement-room-list)
    (if (ignore-errors (setf ement-sessions (ement--read-sessions)))
        (call-interactively #'ement-connect)
      (ement-connect
       :user-id "@david:matrix.alvarezrosa.com"
       :uri-prefix "https://matrix.alvarezrosa.com"
       :password (auth-source-pick-first-password
                  :host "matrix.alvarezrosa.com"
                  :user "@david:matrix.alvarezrosa.com")))))

(keymap-global-set "C-c x" 'dalvrosa/ement-connect)
