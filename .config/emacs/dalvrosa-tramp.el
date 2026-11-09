;;; dalvrosa-tramp.el --- Fast TRAMP -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'subr-x)
(require 'tramp)
(require 'tramp-sh)
(require 'autorevert)

(defvar project-files-relative-names)

(advice-add 'tramp-remote-acl-p :override #'ignore)
(define-advice tramp-handle-lock-file (:before-while (&rest _) inhibited)
  (not remote-file-name-inhibit-locks))

(define-advice cape-file (:before-while (&optional interactive) dalvrosa/local-only)
  (or interactive (not (file-remote-p default-directory))))
(define-advice tramp-handle-file-modes (:around (fn &rest args) dalvrosa/cached)
  (let ((remote-file-name-inhibit-cache nil))
    (apply fn args)))

(defvar dalvrosa/tramp-deferred nil)
(defvar dalvrosa/tramp-in-setup nil)
(defconst dalvrosa/tramp-deferrable
  (rx bos (or "set +o vi +o emacs" "mesg n " "stty tab0" "stty iutf8 " "unset "
              (: "PATH=" (* nonl) "&& export PATH"))
      (* nonl) eos))
(define-advice tramp-open-connection-setup-interactive-shell (:around (fn &rest args) coalesce)
  (let ((dalvrosa/tramp-in-setup t)) (apply fn args)))
(define-advice tramp-send-command (:around (fn vec command &rest args) coalesce)
  (let ((pending (and dalvrosa/tramp-deferred
                      (tramp-file-name-equal-p vec (car dalvrosa/tramp-deferred))
                      (cdr dalvrosa/tramp-deferred))))
    (if (and dalvrosa/tramp-in-setup (string-match-p dalvrosa/tramp-deferrable command))
        (setq dalvrosa/tramp-deferred (cons vec (cons command pending)))
      (when pending
        (setq command (concat (string-join (reverse pending) "; ") "; " command)
              dalvrosa/tramp-deferred nil))
      (apply fn vec command args))))

(defun dalvrosa/without-process-file-side-effects (fn &rest args)
  (let (process-file-side-effects)
    (apply fn args)))
(dolist (fn '(project-files xref-matches-in-files
              consult--grep-lookahead-p consult--find-make-builder))
  (advice-add fn :around #'dalvrosa/without-process-file-side-effects))

(with-eval-after-load 'project
  (define-advice project-try-vc (:around (fn dir) allow-remote)
    (let ((vc-ignore-dir-regexp locate-dominating-stop-dir-regexp))
      (funcall fn dir)))
  (define-advice project-try-vc--search (:around (fn dir timeout) git-toplevel)
    (or (dalvrosa/tramp-watch-project dir)
        (and (file-remote-p dir)
             (with-temp-buffer
               (let ((default-directory dir) process-file-side-effects)
                 (require 'vc-git)
                 (and (eq 0 (ignore-errors
                              (process-file "git" nil t nil "rev-parse"
                                            "--show-superproject-working-tree" "--show-toplevel")))
                      (list 'vc 'Git (abbreviate-file-name
                                      (file-name-as-directory
                                       (concat (file-remote-p dir)
                                               (car (split-string (buffer-string) "\n" t))))))))))
        (funcall fn dir timeout))))

(define-advice xref--process-file-region (:around (fn start end program &optional buffer display &rest args) remote)
  (if (not (file-remote-p default-directory))
      (apply fn start end program buffer display args)
    (let ((infile (make-temp-name (expand-file-name "xref" (temporary-file-directory)))))
      (unwind-protect
          (progn
            (write-region start end infile nil 'silent)
            (apply #'process-file program infile buffer display args))
        (delete-file infile)))))

(defvar dalvrosa/pfr-lazy nil)
(defvar dalvrosa/pfr-list nil)

(defun dalvrosa/pfr-lazily (fn &rest args)
  (let ((dalvrosa/pfr-lazy t)) (apply fn args)))
(advice-add 'project-find-regexp :around #'dalvrosa/pfr-lazily)
(advice-add 'project-or-external-find-regexp :around #'dalvrosa/pfr-lazily)

(define-advice project-vc--backend (:around (fn project dir) remote-prefix)
  (if (and (file-remote-p dir)
           (string-prefix-p (file-name-as-directory (expand-file-name (nth 2 project)))
                            (file-name-as-directory (expand-file-name dir))))
      (cadr project)
    (funcall fn project dir)))

(defun dalvrosa/pfr-defer (fn dir &rest args)
  (if (not (and dalvrosa/pfr-lazy (file-remote-p dir)))
      (apply fn dir args)
    (let* ((rel project-files-relative-names) cmd
           (res (cl-letf (((symbol-function 'project--git-submodules) #'ignore)
                          ((symbol-function 'vc-git-command)
                           (lambda (_buf _ok _files &rest flags)
                             (setq cmd (concat "test -e .gitmodules && exit 97; "
                                               (mapconcat #'shell-quote-argument
                                                          `(,vc-git-program "--no-pager" ,@flags) " ")))))
                          ((symbol-function 'process-file-shell-command)
                           (lambda (command &rest _) (setq cmd command) 0)))
                  (apply fn dir args))))
      (if (not cmd)
          res
        (list (propertize (file-name-as-directory (expand-file-name dir)) 'dalvrosa/pfr
                          (cons cmd (lambda ()
                                      (let ((project-files-relative-names rel) dalvrosa/pfr-lazy)
                                        (apply fn dir args))))))))))
(advice-add 'vc-git-project-list-files :around #'dalvrosa/pfr-defer)
(advice-add 'project--files-in-directory :around #'dalvrosa/pfr-defer)

(define-advice xref-matches-in-files (:around (fn regexp files) lazy-list)
  (let* ((spec (lambda (f) (get-text-property 0 'dalvrosa/pfr f)))
         (default-directory (if (funcall spec (car files)) (car files) default-directory))
         (res (if (and (funcall spec (car files)) (not (cdr files)))
                  (catch 'dalvrosa/pfr
                    (let ((dalvrosa/pfr-list (car (funcall spec (car files)))))
                      (funcall fn regexp files)))
                'fallback)))
    (if (not (eq res 'fallback))
        res
      (funcall fn regexp (mapcan (lambda (f) (if (funcall spec f) (funcall (cdr (funcall spec f))) (list f)))
                                 files)))))

(define-advice xref--process-file-region (:around (fn start end program &optional buffer display &rest args) lazy-list)
  (if (not dalvrosa/pfr-list)
      (apply fn start end program buffer display args)
    (let ((status (apply #'process-file program nil buffer display
                         (append (butlast args)
                                 (list (concat dalvrosa/pfr-list " | " (car (last args)) " /dev/null"))))))
      (when (eql status 97) (throw 'dalvrosa/pfr 'fallback))
      (with-current-buffer buffer
        (goto-char (point-min))
        (while (re-search-forward "^\\./" nil t) (replace-match "")))
      status)))

(define-advice xref--convert-hits (:around (fn hits regexp) remote-no-read)
  (if (file-remote-p default-directory)
      (cl-letf (((symbol-function 'insert-file-contents) #'ignore))
        (funcall fn hits regexp))
    (funcall fn hits regexp)))

(connection-local-set-profile-variables
 'dalvrosa/direct-async '((tramp-direct-async-process . t)))
(connection-local-set-profiles
 '(:application tramp :protocol "ssh") 'dalvrosa/direct-async)
(with-eval-after-load 'tramp-sh
  (add-to-list 'tramp-remote-path 'tramp-own-remote-path))
(define-advice tramp-handle-make-process (:around (fn &rest args) pipe-without-pty)
  (if (memq (or (plist-get args :connection-type) process-connection-type) '(nil pipe))
      (let ((tramp-methods (copy-tree tramp-methods)))
        (setf (alist-get 'tramp-direct-async (cdr (assoc "ssh" tramp-methods))) '(t))
        (apply fn args))
    (apply fn args)))

(defvar dalvrosa/lookahead-cache nil)
(define-advice consult--grep-lookahead-p (:around (fn &rest cmd) memoize)
  (with-memoization (alist-get (cons (file-remote-p default-directory) cmd)
                               dalvrosa/lookahead-cache nil nil #'equal)
    (apply fn cmd)))

(defvar dalvrosa/tramp-ls nil)
(defvar dalvrosa/tramp-ff-memo nil)

(defun dalvrosa/tramp-ff-prefetch (file)
  (let* ((v (tramp-dissect-file-name file))
         (a (directory-file-name (tramp-file-local-name file)))
         (q (tramp-shell-quote-argument a))
         (null (tramp-get-remote-null-device v))
         (n (or tramp-inline-compress-start-size most-positive-fixnum))
         (test (tramp-get-test-command v))
         (exists (tramp-get-file-exists-command v))
         (keys (mapcar (pcase-lambda (`(,fmt ,f)) (list (format fmt (tramp-shell-quote-argument f)) nil nil))
                       `((,(concat test " -d %s") ,a) (,(concat exists " %s") ,a)
                         (,(concat test " -r %s") ,a) (,(concat test " -w %s") ,a)
                         ("tramp_readlink_file_truename %s" ,a) ("tramp_stat_file_attributes %s" ,a)
                         ("tramp_readlink_file_truename %s" ,(file-name-as-directory a))
                         (,(concat exists " %s") ,(file-name-as-directory a))
                         ("tramp_stat_file_attributes %s" ,(file-name-as-directory a))
                         (,(concat test " -d %s") ,(directory-file-name (file-name-directory a)))
                         (,(concat exists " %s") ,(file-name-directory a))
                         ("tramp_stat_file_attributes %s" ,(file-name-directory a)))))
         (run (lambda (c) (format "%s 2>%s; echo tramp_exit_status $?\n" c null)))
         memo)
    (when (and (tramp-get-remote-readlink v) (tramp-get-remote-stat v)
               (not (tramp-remote-selinux-p v)))
      (file-name-case-insensitive-p file)
      (tramp-maybe-send-script v tramp-readlink-file-truename "tramp_readlink_file_truename")
      (tramp-maybe-send-script v tramp-stat-file-attributes "tramp_stat_file_attributes")
      (tramp-send-command
       v (concat "{\n" (mapconcat (lambda (k) (funcall run (car k))) keys "")
                 (format "t=$(tramp_readlink_file_truename %s | sed 1d)\n" q)
                 (funcall run "tramp_stat_file_attributes \"$t\"")
                 (format "s=$(%s -c %%s %s 2>%s); ! test -d %s && test \"$s\" -gt 0 -a \"$(%s -c %%s \"$t\" 2>%s)\" -le %d 2>%s || s=0; echo tramp_ff $s\n"
                         (tramp-get-remote-stat v) q null q (tramp-get-remote-stat v) null
                         (or large-file-warning-threshold most-positive-fixnum) null)
                 (format "if test $s -gt 0; then if test $s -gt %d; then %s 2>%s; else %s 2>%s; fi; echo tramp_exit_status $?; fi\n}"
                         n (format (tramp-get-inline-coding v "remote-encoding" (1+ n)) "\"$t\"") null
                         (format (tramp-get-inline-coding v "remote-encoding" 0) "\"$t\"") null)))
      (with-current-buffer (tramp-get-connection-buffer v)
        (goto-char (point-min))
        (dolist (k keys)
          (let ((beg (point)))
            (re-search-forward "^tramp_exit_status \\([0-9]+\\)\n")
            (push (cons k (cons (buffer-substring beg (match-beginning 0)) (string-to-number (match-string 1)))) memo)))
        (let* ((truename (tramp-shell-quote-argument (cadr (split-string (cadr (assoc (nth 4 keys) memo)) "\n"))))
               (beg (point)))
          (re-search-forward "^tramp_exit_status \\([0-9]+\\)\n")
          (push (cons (list (concat "tramp_stat_file_attributes " truename) nil nil)
                      (cons (buffer-substring beg (match-beginning 0)) (string-to-number (match-string 1))))
                memo)
          (re-search-forward "\\=tramp_ff \\([0-9]+\\)\n")
          (let ((size (string-to-number (match-string 1))) (beg (point)))
            (when (> size 0)
              (re-search-forward "^tramp_exit_status \\([0-9]+\\)\n")
              (push (cons (list (format (tramp-get-inline-coding v "remote-encoding" size) truename) nil nil)
                          (cons (buffer-substring beg (match-beginning 0)) (string-to-number (match-string 1))))
                    memo))))
        (cons v memo)))))

(define-advice find-file-noselect (:around (fn filename &rest args) dalvrosa/tramp-1rtt)
  (let* ((file (expand-file-name filename))
         (v (and (not dalvrosa/tramp-ls) (tramp-tramp-file-p file) (tramp-dissect-file-name file)))
         (dalvrosa/tramp-ff-memo
          (and v (not (get-file-buffer file)) (tramp-sh-file-name-handler-p v)
               (not (eq t (car (tramp-get-file-property v (directory-file-name (tramp-file-local-name file)) "file-attributes"))))
               (ignore-errors (dalvrosa/tramp-ff-prefetch file)))))
    (apply fn filename args)))

(define-advice tramp-send-command (:before (&rest _) dalvrosa/tramp-1rtt)
  (setq dalvrosa/tramp-ff-memo nil))

(define-advice tramp-send-command-and-check (:around (fn vec cmd &optional sub err exit) dalvrosa/tramp-1rtt)
  (if-let* ((memo dalvrosa/tramp-ff-memo)
            ((tramp-file-name-equal-p vec (car memo)))
            (hit (cdr (assoc (list cmd sub err) (cdr memo)))))
      (with-current-buffer (tramp-get-connection-buffer vec)
        (let ((inhibit-read-only t)) (erase-buffer) (insert (car hit)))
        (if exit (cdr hit) (zerop (cdr hit))))
    (funcall fn vec cmd sub err exit)))

(define-advice tramp-send-command (:around (fn vec command &rest args) dalvrosa/dired)
  (pcase dalvrosa/tramp-ls
    ((and 'capture (guard (not (string-search "tramp_exit_status" command))))
     (throw 'dalvrosa/tramp-ls command))
    ((and `(,v ,(pred (equal command)) ,out . ,_) (guard (tramp-file-name-equal-p v vec)))
     (setq dalvrosa/tramp-ls nil)
     (with-current-buffer (tramp-get-connection-buffer vec)
       (let ((inhibit-read-only t)) (erase-buffer) (insert out))))
    (_ (apply fn vec command args))))
(defun dalvrosa/tramp-dired-fill (v l tl marker attrs entries)
  (let ((remote-file-name-inhibit-cache t))
    (tramp-convert-file-attributes v l nil attrs)
    (when (and (string-prefix-p "/" tl) (not (tramp-tramp-file-p tl)))
      (tramp-set-file-property v l "file-symlink-marker" marker)
      (tramp-set-file-property v l "file-truename" tl)
      (tramp-set-file-property v tl "file-truename" tl)
      (pcase-dolist (`(,n . ,attr) entries)
        (pcase n
          ("." (tramp-convert-file-attributes v tl nil attr)
           (tramp-set-file-property v tl "file-readable-p" t))
          (".." nil)
          (_ (dolist (d (delete-dups (list l tl)))
               (let ((f (concat (file-name-as-directory d) n)))
                 (unless (stringp (car (tramp-convert-file-attributes v f nil attr)))
                   (tramp-set-file-property v f "file-truename"
                                            (concat (file-name-as-directory tl) n)))))))))))
(defun dalvrosa/tramp-dired-prefetch (dir switches)
  (when-let* (((tramp-tramp-file-p dir))
              (v (tramp-dissect-file-name dir))
              ((tramp-sh-file-name-handler-p v))
              (l (directory-file-name (tramp-file-name-localname v)))
              (scripts (mapcar (lambda (s) (tramp-expand-script v s))
                               (list tramp-readlink-file-truename tramp-stat-file-attributes
                                     (concat "cd \"$1\" || exit\n"
                                             tramp-stat-directory-files-and-attributes))))
              ((not (memq nil scripts)))
              (ls (let ((dalvrosa/tramp-ls 'capture))
                    (catch 'dalvrosa/tramp-ls
                      (cl-letf (((symbol-function 'access-file) #'ignore))
                        (with-temp-buffer (tramp-sh-handle-insert-directory dir switches nil t)))
                      nil))))
    (pcase dalvrosa/tramp-ls
      ((and `(,w ,(pred (equal ls)) ,_ ,fill) (guard (tramp-file-name-equal-p v w)))
       (funcall fill)
       dalvrosa/tramp-ls)
      (_
       (tramp-send-command
        v (concat (mapconcat (lambda (s) (format "(set -- %s\n%s\n) 2>/dev/null; echo; echo %s; "
                                                 (tramp-shell-quote-argument l) s tramp-end-of-heredoc))
                             scripts)
                  ls))
       (with-current-buffer (tramp-get-connection-buffer v)
         (goto-char (point-min))
         (let* ((parts (cl-loop repeat 3 for b = (point)
                                do (re-search-forward (concat "^" tramp-end-of-heredoc "\n"))
                                collect (buffer-substring b (match-beginning 0))))
                (args (list v l (cadr (split-string (car parts) "\n"))
                            (ignore-errors (read (car parts)))
                            (ignore-errors (read (nth 1 parts)))
                            (ignore-errors (read (nth 2 parts)))))
                (fill (lambda () (apply #'dalvrosa/tramp-dired-fill args))))
           (delete-region (point-min) (point))
           (funcall fill)
           (list v ls (buffer-string) fill)))))))
(define-advice tramp-sh-handle-insert-directory (:around (fn file switches &optional wildcard full) dalvrosa/prefetch)
  (let ((dalvrosa/tramp-ls (if (or (eq dalvrosa/tramp-ls 'capture) wildcard (not full))
                               dalvrosa/tramp-ls
                             (dalvrosa/tramp-dired-prefetch (expand-file-name file) switches))))
    (funcall fn file switches wildcard full)))
(define-advice dired-readin-insert (:around (fn) dalvrosa/prefetch)
  (let ((dalvrosa/tramp-ls (and (stringp dired-directory)
                                (directory-name-p dired-directory)
                                (dalvrosa/tramp-dired-prefetch (expand-file-name dired-directory)
                                                               dired-actual-switches))))
    (funcall fn)))
(defun dalvrosa/dired-visit-prefetch (fn &rest args)
  (let ((dalvrosa/tramp-ls
         (and (save-excursion (beginning-of-line) (looking-at-p dired-re-dir))
              (when-let* ((f (dired-get-filename nil t))
                          (d (file-name-as-directory (expand-file-name f))))
                (dalvrosa/tramp-dired-prefetch
                 d (if-let* ((b (dired-find-buffer-nocreate d)))
                       (buffer-local-value 'dired-actual-switches b)
                     (connection-local-value dired-listing-switches)))))))
    (apply fn args)))
(dolist (fn '(dired-find-file dired-find-file-other-window dired-find-alternate-file))
  (advice-add fn :around #'dalvrosa/dired-visit-prefetch))
(define-advice tramp-handle-dired-uncache (:around (fn dir) dalvrosa/dirname)
  (if (directory-name-p dir)
      (tramp-flush-directory-properties (tramp-dissect-file-name dir) (tramp-file-local-name dir))
    (funcall fn dir)))
(define-advice nerd-icons-dired--annotate (:around (fn) dired-line)
  (cl-letf (((symbol-function 'file-directory-p)
             (lambda (_) (save-excursion (beginning-of-line) (looking-at-p dired-re-dir)))))
    (funcall fn)))
(define-advice get-free-disk-space (:before-while (dir) local)
  (not (file-remote-p dir)))
(define-advice dired--filename-with-newline-p (:before-while () local)
  (not (file-remote-p default-directory)))

(defvar dalvrosa/tramp-watchers nil)
(defvar dalvrosa/tramp-watch-started (make-hash-table :test #'equal))
(defvar dalvrosa/tramp-watch-pending nil)
(defvar dalvrosa/tramp-watch-timer nil)
(defvar dalvrosa/tramp-watch-trust nil)
(defvar-local dalvrosa/tramp-watch-saved 0)
(add-hook 'after-save-hook (lambda () (setq dalvrosa/tramp-watch-saved (float-time))))
(defconst dalvrosa/tramp-watch-script
  "command -v inotifywait >/dev/null || exit 127
ign=$(git ls-files -zoi --exclude-standard --directory 2>/dev/null | tr '\\0' '\\n')
set -- @./.git/objects
while IFS= read -r d; do
  [ -n \"$d\" ] || continue
  printf 'EXCLUDE %s\\n' \"${d%/}\"
  case $d in */) set -- \"$@\" \"@./${d%/}\";; esac
done <<EOF
$ign
EOF
ex=$(printf '%s\\n' .git/objects \"$ign\" | sed '/^$/d; s|/$||; s/[][\\.*^$()+?{}|]/\\\\&/g' | paste -sd'|' -)
(while sleep 60; do p=$(cut -d' ' -f4 /proc/$$/stat 2>/dev/null) || exit; [ \"$p\" = 1 ] && exec kill $$; done) >/dev/null 2>&1 &
exec inotifywait -mr --format '%e %w%f' -e create,delete,modify,move,attrib,close_write,delete_self,move_self --exclude \"^\\./($ex)(/|\\$)\" \"$@\" . 2>&1")

(defun dalvrosa/tramp-conn (vec)
  (list (tramp-file-name-method vec) (tramp-file-name-user vec)
        (tramp-file-name-host vec) (tramp-file-name-port vec)))

(defun dalvrosa/tramp-watcher (vec file)
  (let ((dir (concat file "/")))
    (cl-dolist (p dalvrosa/tramp-watchers)
      (when (and (string-prefix-p (process-get p 'root) dir)
                 (process-get p 'ready)
                 (equal (process-get p 'conn) (dalvrosa/tramp-conn vec))
                 (not (cl-loop for i in (process-get p 'ignored) thereis (string-prefix-p i dir))))
        (cl-return p)))))

(defun dalvrosa/tramp-watched-p (file)
  (and dalvrosa/tramp-watchers (tramp-tramp-file-p file)
       (let ((v (tramp-dissect-file-name (expand-file-name file))))
         (dalvrosa/tramp-watcher v (directory-file-name (tramp-file-name-localname v))))))

(define-advice tramp-get-file-property (:around (fn key file &rest args) dalvrosa/watch)
  (let ((remote-file-name-inhibit-cache
         (if (and dalvrosa/tramp-watchers (stringp file)
                  (or (numberp remote-file-name-inhibit-cache)
                      dalvrosa/tramp-watch-trust
                      (and (consp remote-file-name-inhibit-cache)
                           (time-less-p remote-file-name-inhibit-cache (time-subtract nil 1))))
                  (dalvrosa/tramp-watcher key file))
             nil
           remote-file-name-inhibit-cache)))
    (apply fn key file args)))

(define-advice tramp-flush-directory-properties (:after (key dir) dalvrosa/watch)
  (dolist (p dalvrosa/tramp-watchers)
    (when (and (string-prefix-p (file-name-as-directory dir) (process-get p 'root))
               (equal (process-get p 'conn) (dalvrosa/tramp-conn key)))
      (process-put p 'dirty t))))

(defun dalvrosa/tramp-watch (project)
  (let* ((dir (expand-file-name (project-root project)))
         (old (seq-find (lambda (p) (equal (process-get p 'dir) dir)) dalvrosa/tramp-watchers)))
    (cond (old (process-put old 'project project))
          ((time-less-p (time-since (gethash dir dalvrosa/tramp-watch-started 0)) 10))
          (t
           (puthash dir (current-time) dalvrosa/tramp-watch-started)
           (let* ((default-directory dir)
                  (vec (tramp-dissect-file-name dir))
                  (p (ignore-errors
                       (make-process :name "dalvrosa-watch" :command (list "sh" "-c" dalvrosa/tramp-watch-script)
                                     :connection-type 'pipe :noquery t :file-handler t
                                     :filter #'dalvrosa/tramp-watch-filter
                                     :sentinel #'dalvrosa/tramp-watch-sentinel))))
             (when p
               (dolist (kv `((dir . ,dir) (vec . ,vec) (conn . ,(dalvrosa/tramp-conn vec))
                             (root . ,(tramp-file-name-localname vec)) (project . ,project) (dirty . t) (sgen . 0)
                             (ignored . ,(list (concat (tramp-file-name-localname vec) ".git/objects/")))))
                 (process-put p (car kv) (cdr kv)))
               (push p dalvrosa/tramp-watchers)))))))

(defun dalvrosa/tramp-watch-sentinel (p _)
  (unless (process-live-p p)
    (setq dalvrosa/tramp-watchers (delq p dalvrosa/tramp-watchers))
    (unless (process-get p 'ready)
      (puthash (process-get p 'dir) (time-add nil 600) dalvrosa/tramp-watch-started))
    (tramp-flush-directory-properties (process-get p 'vec) (process-get p 'root))))

(defun dalvrosa/tramp-watch-filter (p string)
  (let* ((lines (split-string (concat (process-get p 'rest) string) "\n"))
         (root (process-get p 'root))
         (vec (process-get p 'vec))
         (bulk (length> lines 200)))
    (process-put p 'rest (car (last lines)))
    (when bulk (tramp-flush-directory-properties vec root))
    (dolist (line (butlast lines))
      (cond
       ((equal line "Watches established.")
        (tramp-flush-directory-properties vec root)
        (dalvrosa/tramp-watch-stale p)
        (process-put p 'ready t))
       ((string-prefix-p "EXCLUDE " line)
        (process-put p 'ignored (cons (concat root (substring line 8) "/") (process-get p 'ignored))))
       ((string-match "\\`\\([A-Z_,]+\\) \\./\\(.*?\\)/?\\'" line)
        (let* ((ev (match-string 1 line))
               (rel (match-string 2 line))
               (file (directory-file-name (concat root rel)))
               (git (string-prefix-p ".git/" rel))
               (up (directory-file-name (file-name-directory file)))
               (prop (format "file-name-all-completions-%s" tramp-fnac-add-trailing-slash))
               (names (and (not (or bulk git (string-match-p "ISDIR\\|SELF" ev)
                                    (process-live-p (process-get p 'tree))))
                           (tramp-get-file-property vec up prop nil))))
          (unless (and (string-match-p "\\`\\(MODIFY\\|CLOSE_WRITE,CLOSE\\)\\'" ev)
                       (< (- (float-time) (gethash file dalvrosa/tramp-own-writes 0)) 2))
            (unless (or git names) (process-put p 'dirty t))
            (unless (or (string-match-p "\\`\\(MODIFY\\|ATTRIB\\|CLOSE_WRITE,CLOSE\\)\\'" ev)
                        (and (string-prefix-p ".git/" rel)
                             (not (member rel '(".git/index" ".git/info/exclude")))))
              (dalvrosa/tramp-watch-stale p))
            (when (string-suffix-p ".gitignore" rel) (dalvrosa/tramp-watch-stale p))
            (cond (bulk)
                  ((string-match-p "ISDIR\\|SELF" ev) (tramp-flush-directory-properties vec file))
                  (t (tramp-flush-file-properties vec file)))
            (when names
              (let ((n (file-name-nondirectory file))
                    (gone (string-match-p "DELETE\\|MOVED_FROM" ev)))
                (tramp-set-file-property vec up prop (cond (gone (seq-difference names (list n (concat n "/"))))
                                                           ((or (member n names) (member (concat n "/") names)) names)
                                                           (t (cons n names))))
                (tramp-set-file-property vec file "file-exists-p" (not gone))))
            (unless git
              (push (tramp-make-tramp-file-name vec file) dalvrosa/tramp-watch-pending)))))
       ((string-match-p "\\`[A-Z_]+ " line)
        (dalvrosa/tramp-watch-stale p)
        (process-put p 'dirty t)
        (tramp-flush-directory-properties vec root))))
    (when (and dalvrosa/tramp-watch-pending (not dalvrosa/tramp-watch-timer))
      (setq dalvrosa/tramp-watch-timer (run-with-timer 0.02 nil #'dalvrosa/tramp-watch-revert)))))

(defun dalvrosa/tramp-watch-stale (p)
  (process-put p 'files nil)
  (process-put p 'sgen (1+ (or (process-get p 'sgen) 0))))

(defun dalvrosa/tramp-watch-busy-p ()
  (seq-some (lambda (p) (when-let* ((c (tramp-get-connection-process (process-get p 'vec))))
                          (tramp-get-connection-property c "locked")))
            dalvrosa/tramp-watchers))

(defun dalvrosa/tramp-watch-revert ()
  (if (dalvrosa/tramp-watch-busy-p)
      (setq dalvrosa/tramp-watch-timer (run-with-timer 0.05 nil #'dalvrosa/tramp-watch-revert))
    (let ((files (delete-dups dalvrosa/tramp-watch-pending))
          (dalvrosa/tramp-watch-trust t))
      (setq dalvrosa/tramp-watch-pending nil
            dalvrosa/tramp-watch-timer (run-with-timer 1 nil #'dalvrosa/tramp-watch-unlock))
      (dolist (buf (delete-dups
                    (mapcan (lambda (f) (cons (get-file-buffer f)
                                              (dired-buffers-for-dir (file-name-directory f))))
                            files)))
        (when (buffer-live-p buf)
          (with-current-buffer buf
            (when (and (auto-revert-active-p) (not (buffer-modified-p))
                       (if (derived-mode-p 'dired-mode) buffer-read-only
                         (or (< 1 (- (float-time) dalvrosa/tramp-watch-saved)) (not (verify-visited-file-modtime)))))
              (condition-case nil (revert-buffer t t t)
                (remote-file-error (push (or buffer-file-name default-directory) dalvrosa/tramp-watch-pending))
                (error nil)))))))))

(defun dalvrosa/tramp-watch-unlock ()
  (setq dalvrosa/tramp-watch-timer nil)
  (when dalvrosa/tramp-watch-pending (dalvrosa/tramp-watch-revert)))

(defun dalvrosa/tramp-watch-prefetch ()
  (dolist (p (unless (dalvrosa/tramp-watch-busy-p) dalvrosa/tramp-watchers))
    (when (and (process-get p 'ready) (not (process-get p 'files))
               (not (eql (process-get p 'fgen) (process-get p 'sgen))))
      (process-put p 'fgen (process-get p 'sgen))
      (ignore-errors (dalvrosa/tramp-watch-list p)))
    (when (and (process-get p 'ready) (process-get p 'dirty) (not (process-live-p (process-get p 'tree))))
      (process-put p 'dirty nil)
      (let* ((default-directory (process-get p 'dir))
             (root (process-get p 'root))
             (prune (mapcar (lambda (i) (concat "./" (string-remove-prefix root (directory-file-name i))))
                            (cons (concat root ".git/") (process-get p 'ignored))))
             (buf (generate-new-buffer " *dalvrosa-tree*" t)))
        (process-put
         p 'tree
         (make-process
          :name "dalvrosa-tree" :buffer buf :connection-type 'pipe :noquery t :file-handler t
          :command `("find" "." "(" ,@(cdr (mapcan (lambda (d) (list "-o" "-path" d)) prune)) ")"
                     "-prune" "-printf" "%Y- %p\\0" "-o" "-printf" "%Y+ %p\\0")
          :sentinel (lambda (proc _)
                      (unless (process-live-p proc)
                        (when (and (eq (process-exit-status proc) 0) (memq p dalvrosa/tramp-watchers)
                                   (not (process-get p 'dirty)))
                          (with-current-buffer buf
                            (dalvrosa/tramp-watch-fill p (split-string (buffer-string) "\0" t))))
                        (kill-buffer buf)))))))))

(defun dalvrosa/tramp-watch-list (p)
  (let* ((project (process-get p 'project))
         (sgen (process-get p 'sgen))
         (default-directory (process-get p 'dir))
         (cmd (and (not (process-get p 'sync))
                   (car (get-text-property 0 'dalvrosa/pfr
                                           (or (car (let ((dalvrosa/pfr-lazy t) project-files-relative-names)
                                                      (project-files project)))
                                               ""))))))
    (if (not cmd)
        (project-files project)
      (let ((buf (generate-new-buffer " *dalvrosa-ls*" t)))
        (make-process
         :name "dalvrosa-ls" :buffer buf :connection-type 'pipe :noquery t :file-handler t
         :coding 'utf-8-unix :command (list "sh" "-c" (concat cmd " 2>/dev/null"))
         :sentinel (lambda (proc _)
                     (unless (process-live-p proc)
                       (cond ((eql (process-exit-status proc) 97)
                              (process-put p 'sync t)
                              (process-put p 'fgen nil))
                             ((and (eq (process-exit-status proc) 0) (memq p dalvrosa/tramp-watchers)
                                   (eql sgen (process-get p 'sgen)))
                              (let ((out (with-current-buffer buf (buffer-string))))
                                (cl-letf (((symbol-function 'project--git-submodules) #'ignore)
                                          ((symbol-function 'vc-git-command)
                                           (lambda (b &rest _) (princ out b) 0))
                                          ((symbol-function 'process-file-shell-command)
                                           (lambda (&rest _) (insert out) 0)))
                                  (dolist (project-files-relative-names '(nil t))
                                    (project-files project))))))
                       (kill-buffer buf))))))))

(defun dalvrosa/tramp-watch-fill (p entries)
  (let ((vec (process-get p 'vec))
        (root (directory-file-name (process-get p 'root)))
        (prop (format "file-name-all-completions-%s" tramp-fnac-add-trailing-slash))
        (dirs (make-hash-table :test #'equal)))
    (dolist (e entries)
      (let* ((type (aref e 0))
             (file (directory-file-name (concat root (substring e 4)))))
        (when (and (eq type ?d) (eq (aref e 1) ?+))
          (puthash file (or (gethash file dirs) '("./" "../")) dirs))
        (unless (equal (substring e 3) ".")
          (tramp-set-file-property vec file "file-exists-p" (not (eq type ?N)))
          (tramp-set-file-property vec file "file-directory-p" (eq type ?d))
          (push (concat (file-name-nondirectory file) (and tramp-fnac-add-trailing-slash (eq type ?d) "/"))
                (gethash (directory-file-name (file-name-directory file)) dirs)))))
    (tramp-set-file-property vec root "file-directory-p" t)
    (maphash (lambda (dir names)
               (when (dalvrosa/tramp-watcher vec dir)
                 (tramp-set-file-property vec dir prop names)))
             dirs)))

(with-eval-after-load 'project
  (define-advice project-current (:filter-return (pr) dalvrosa/watch)
    (when (and pr (file-remote-p (project-root pr)))
      (dalvrosa/tramp-watch pr))
    pr)
  (define-advice project-files (:around (fn project &optional dirs) dalvrosa/watch)
    (let* ((dir (expand-file-name (project-root project)))
           (p (seq-find (lambda (p) (and (process-get p 'ready) (equal (process-get p 'dir) dir)))
                        dalvrosa/tramp-watchers))
           (key project-files-relative-names))
      (if (not (and p (member dirs (list nil (list (project-root project)) (list dir)))))
          (funcall fn project dirs)
        (copy-sequence
         (or (alist-get key (process-get p 'files))
             (let ((sgen (process-get p 'sgen)) (files (funcall fn project dirs)))
               (when (and (not dalvrosa/pfr-lazy) (eql sgen (process-get p 'sgen)))
                 (process-put p 'files (cons (cons key files) (process-get p 'files))))
               files)))))))

(run-with-idle-timer 1 t #'dalvrosa/tramp-watch-prefetch)
(setq dired-auto-revert-buffer (lambda (dir) (not (dalvrosa/tramp-watched-p dir))))
(define-advice tramp-flush-file-function (:before-while () dalvrosa/watch)
  (not (dalvrosa/tramp-watched-p (or buffer-file-name default-directory))))

(define-advice verify-visited-file-modtime (:around (fn &optional buf) dalvrosa/watch)
  (let ((dalvrosa/tramp-watch-trust
         (or dalvrosa/tramp-watch-trust
             (let ((f (buffer-file-name (if (bufferp buf) buf (current-buffer)))))
               (and f (dalvrosa/tramp-watched-p f) t)))))
    (funcall fn buf)))

(define-advice revert-buffer-insert-file-contents--default-function
    (:around (fn file-name auto-save-p) dalvrosa/tramp-1rtt)
  (let ((dalvrosa/tramp-ff-memo
         (and (not auto-save-p) (tramp-tramp-file-p file-name)
              (tramp-sh-file-name-handler-p (tramp-dissect-file-name file-name))
              (ignore-errors (dalvrosa/tramp-ff-prefetch (expand-file-name file-name))))))
    (funcall fn file-name auto-save-p)))

(define-advice tramp-sh-handle-process-file (:around (fn &rest args) dalvrosa/watch)
  (let ((process-file-side-effects
         (and process-file-side-effects (not (dalvrosa/tramp-watched-p default-directory)))))
    (apply fn args)))

(defvar dalvrosa/tramp-own-writes (make-hash-table :test #'equal))
(defvar dalvrosa/tramp-write-target nil)

(define-advice tramp-sh-handle-write-region (:around (fn start end filename &rest args) dalvrosa/tramp-1rtt)
  (let* ((file (expand-file-name filename))
         (v (tramp-dissect-file-name file))
         (l (tramp-file-local-name file))
         (tn (tramp-get-file-property v l "file-truename" nil))
         dalvrosa/tramp-ff-memo
         (dalvrosa/tramp-write-target
          (and (tramp-get-remote-stat v) (not (tramp-remote-selinux-p v))
               (progn (tramp-maybe-send-script v tramp-stat-file-attributes "tramp_stat_file_attributes")
                      (cons v (tramp-shell-quote-argument l))))))
    (puthash l (float-time) dalvrosa/tramp-own-writes)
    (prog1 (apply fn start end filename args)
      (puthash l (float-time) dalvrosa/tramp-own-writes)
      (when tn (tramp-set-file-property v l "file-truename" tn)))))

(define-advice tramp-send-command-and-check (:around (fn vec cmd &rest args) dalvrosa/tramp-write)
  (let* ((target dalvrosa/tramp-write-target)
         (nl (and target (stringp cmd) (string-search "\n" cmd)))
         (head (and nl (substring cmd 0 nl)))
         (heredoc (format "<<'%s'" tramp-end-of-heredoc)))
    (if (not (and head (tramp-file-name-equal-p vec (car target))
                  (string-suffix-p heredoc head)
                  (string-match-p (concat ">" (regexp-quote (cdr target)) "[) ]") head)))
        (apply fn vec cmd args)
      (setq dalvrosa/tramp-write-target nil)
      (let* ((stat (concat "tramp_stat_file_attributes " (cdr target)))
             (res (apply fn vec (concat head "; s=$?; " stat " 2>/dev/null; echo tramp_ff_stat $?; test $s = 0"
                                        (substring cmd nl))
                         args)))
        (with-current-buffer (tramp-get-connection-buffer vec)
          (goto-char (point-min))
          (when (re-search-forward "^tramp_ff_stat \\([0-9]+\\)\n?" nil t)
            (setq dalvrosa/tramp-ff-memo
                  (cons vec (list (cons (list stat nil nil)
                                        (cons (buffer-substring (point-min) (match-beginning 0))
                                              (string-to-number (match-string 1)))))))
            (let ((inhibit-read-only t)) (erase-buffer))))
        res))))

(defvar dalvrosa/remote-warm '("/ssh:homelab:"))
(defvar dalvrosa/tramp-warm-thread nil)

(defun dalvrosa/tramp-warming-p ()
  (and (threadp dalvrosa/tramp-warm-thread) (thread-live-p dalvrosa/tramp-warm-thread)))

(defun dalvrosa/tramp-warm-connect (remote)
  (let ((v (tramp-dissect-file-name remote)))
    (unless (or (dalvrosa/tramp-warming-p)
                (process-live-p (tramp-get-connection-process v)))
      (setq dalvrosa/tramp-warm-thread
            (make-thread (lambda ()
                           (let ((inhibit-message t))
                             (ignore-errors
                               (let ((home (file-truename (concat remote "~/"))))
                                 (directory-files home)
                                 (with-temp-buffer
                                   (let ((default-directory home))
                                     (insert-directory home (connection-local-value dired-listing-switches) nil t)))
                                 (with-temp-buffer (insert-file-contents (concat remote "/etc/hostname")))))))
                         "dalvrosa/tramp-warm")))))

(defun dalvrosa/tramp-warm-1 (remote)
  (let ((host (tramp-file-name-host (tramp-dissect-file-name remote))))
    (make-process :name (concat "dalvrosa/ssh-master-" host)
                  :command (list "ssh" "-o" "BatchMode=yes" host "true")
                  :connection-type 'pipe :noquery t :buffer nil
                  :sentinel (lambda (p _)
                              (when (and (eq (process-status p) 'exit)
                                         (eq (process-exit-status p) 0))
                                (run-with-idle-timer 0.5 nil #'dalvrosa/tramp-warm-connect remote))))))

(defun dalvrosa/tramp-warm ()
  (mapc #'dalvrosa/tramp-warm-1 dalvrosa/remote-warm))

(defun dalvrosa/tramp-reset ()
  (dolist (remote dalvrosa/remote-warm)
    (let* ((v (tramp-dissect-file-name remote))
           (host (tramp-file-name-host v)))
      (make-process :name (concat "dalvrosa/ssh-check-" host)
                    :command (list "timeout" "4" "ssh" "-o" "BatchMode=yes" host "true")
                    :connection-type 'pipe :noquery t :buffer nil
                    :sentinel (lambda (p _)
                                (unless (process-live-p p)
                                  (unless (eq 0 (process-exit-status p))
                                    (call-process "ssh" nil nil nil "-O" "exit" host)
                                    (when-let* ((c (tramp-get-connection-process v)))
                                      (delete-process c)))
                                  (dalvrosa/tramp-warm-1 remote)))))))

(define-advice tramp-file-name-handler (:before (&rest _) dalvrosa/wait-warm)
  (when (and (dalvrosa/tramp-warming-p)
             (not (eq (current-thread) dalvrosa/tramp-warm-thread)))
    (thread-join dalvrosa/tramp-warm-thread)))

(defvar dalvrosa/tramp-reset-timer nil)
(defun dalvrosa/nm-state-changed (state)
  (when (= state 70)
    (when (timerp dalvrosa/tramp-reset-timer) (cancel-timer dalvrosa/tramp-reset-timer))
    (setq dalvrosa/tramp-reset-timer (run-with-timer 1 nil #'dalvrosa/tramp-reset))))

(ignore-errors
  (require 'dbus)
  (dbus-register-signal :system "org.freedesktop.NetworkManager" "/org/freedesktop/NetworkManager"
                        "org.freedesktop.NetworkManager" "StateChanged" #'dalvrosa/nm-state-changed))
(run-with-idle-timer 2 nil #'dalvrosa/tramp-warm)

(with-eval-after-load 'eglot
  (define-advice eglot--xref-make-match (:around (fn &rest args) remote-no-read)
    (if (file-remote-p default-directory)
        (cl-letf (((symbol-function 'file-readable-p) #'ignore)) (apply fn args))
      (apply fn args)))
  (define-advice xref-location-marker (:around (fn &rest args) skip-remote-verify)
    (if (file-remote-p default-directory)
        (cl-letf (((symbol-function 'verify-visited-file-modtime) #'always)) (apply fn args))
      (apply fn args))))

(defvar dalvrosa/magit-1rtt-plans (make-hash-table :test #'equal))
(defvar dalvrosa/magit-1rtt--scope nil)
(defvar dalvrosa/magit-1rtt--git nil)
(defvar dalvrosa/magit-1rtt--read nil)
(defvar dalvrosa/magit-1rtt--wgit nil)
(defvar dalvrosa/magit-1rtt--stdin nil)
(defvar dalvrosa/magit-1rtt-tops (make-hash-table :test #'equal))
(defvar dalvrosa/magit-1rtt-logs (make-hash-table :test #'equal))

(defun dalvrosa/magit-1rtt--read-only-p (args)
  (while (member (car args) '("-c" "--no-pager" "--literal-pathspecs"))
    (setq args (if (equal (car args) "-c") (cddr args) (cdr args))))
  (pcase args
    (`(,(or "rev-parse" "log" "describe" "status" "diff" "show" "merge-base"
            "for-each-ref" "show-ref" "cat-file" "ls-files" "ls-tree" "rev-list"
            "name-rev" "cherry" "version" "var" "diff-tree" "diff-index" "diff-files")
       . ,_)
     t)
    (`("update-index" "--refresh") t)
    (`("branch" . ,r) (and (seq-some (lambda (a) (member a '("--merged" "--contains" "--no-merged" "--no-contains" "--list" "--show-current"))) r)
                           (not (seq-some (lambda (a) (string-match-p "\\`-[dDmMcC]\\|\\`--\\(delete\\|move\\|copy\\|set\\|unset\\|edit\\)" a)) r))))
    (`("remote" . ,r) (or (null r) (equal (car r) "get-url")))
    (`("symbolic-ref" . ,r) (length< (seq-remove (lambda (a) (string-prefix-p "-" a)) r) 2))
    (`("config" . ,r) (and (seq-some (lambda (a) (string-match-p "\\`--\\(get\\|list\\|default\\)" a)) r)
                           (not (seq-some (lambda (a) (string-match-p "\\`--\\(unset\\|add\\|replace\\|rename\\|remove\\)" a)) r))))))

(defconst dalvrosa/magit-1rtt--var-re "@\\(P[12]\\|N?TAG\\|W[1-6]\\)@")

(defconst dalvrosa/magit-1rtt--dep-re
  (rx (or (seq (not (any " @\\")) "\\^\\{commit\\}") (seq (not (any " @")) "...@REV@") (seq "@REV@..." (not (any " @"))))))

(defun dalvrosa/magit-1rtt--prefetch (vec plan &optional first hdr)
  (let ((memo (make-hash-table :test #'equal)) (dalvrosa/magit-1rtt--read t))
    (ignore-errors
      (tramp-send-command
       vec (concat "(\nd=$(mktemp -d) || exit\n" hdr
                   (cl-loop for (c sub err) in plan for i from 0
                            for cmd = (replace-regexp-in-string dalvrosa/magit-1rtt--var-re "${\\1}" c t)
                            for w = (or (string-search "update-index" cmd) (and first (= i 0)))
                            concat (format "%s{ { %s%s%secho tramp_exit_status $?%s; } </dev/null 2>&1 | base64; echo .; } >\"$d/%d\"%s\n"
                                           (if w "wait; " "") (if sub "( " "") cmd
                                           (if err "; " " 2>/dev/null; ") (if sub " )" "") i (if w "" " &")))
                   "wait\ncat"
                   (cl-loop for i below (length plan) concat (format " \"$d/%d\"" i))
                   "\nrm -rf \"$d\"\n) 2>/dev/null"))
      (with-current-buffer (tramp-get-connection-buffer vec)
        (let* ((coding (car (process-coding-system (tramp-get-connection-process vec))))
               (segs (split-string (buffer-string) "^\\.\n"))
               (vars (and hdr (dalvrosa/magit-1rtt--parse-vars (pop segs)))))
          (when hdr (puthash :vars vars memo))
          (cl-loop for key in (and (length= segs (1+ (length plan))) plan)
                   for b64 in segs
                   for out = (decode-coding-string (base64-decode-string (string-replace "\n" "" b64)) coding)
                   for k = (dalvrosa/magit-1rtt--subst-vars vars key)
                   when (and k (string-match "tramp_exit_status \\([0-9]+\\)\n?\\'" out))
                   do (puthash k (cons (substring out 0 (match-beginning 0))
                                       (string-to-number (match-string 1 out)))
                               memo)))))
    memo))

(defun dalvrosa/magit-1rtt--subst-vars (vars key)
  (let ((cmd (car key)))
    (pcase-dolist (`(,v . ,tag) vars) (setq cmd (string-replace tag v cmd)))
    (and (not (string-match-p dalvrosa/magit-1rtt--var-re cmd)) (cons cmd (cdr key)))))

(defun dalvrosa/magit-1rtt--siblings (key)
  (cons key (cond ((string-search "@W1@" (car key))
                   (mapcar (lambda (i) (cons (string-replace "@W1@" (format "@W%d@" i) (car key)) (cdr key)))
                           (number-sequence 2 6)))
                  ((string-search "@P1@" (car key))
                   (list (cons (string-replace "@P1@" "@P2@" (car key)) (cdr key)))))))

(defun dalvrosa/magit-1rtt--parse-vars (out)
  (sort (cl-loop for line in (split-string (or out "") "\n" t)
                 when (string-match "\\`\\([A-Z]+[0-9]?\\)=\\([[:alnum:]/_+%=.-]\\{2,\\}\\)\\'" line)
                 collect (cons (match-string 2 line) (format "@%s@" (match-string 1 line))))
        (lambda (a b) (> (length (car a)) (length (car b))))))

(defun dalvrosa/magit-1rtt--vars-script (dir rev)
  (format "cd %s 2>/dev/null; set -- $(git rev-list -1 --parents %s 2>/dev/null); P1=$2; P2=$3
TAG=$(git describe --long --tags %s 2>/dev/null | sed 's/-[0-9]*-g[0-9a-z]*$//')
NTAG=$(git describe --contains %s 2>/dev/null | sed 's/[~^].*//')
set -- $(git log -1 --format=%%B %s 2>/dev/null | grep -oE '[[:alnum:]/_+*<>=$%%&|-]{7,}' | grep '[0-9]' | grep -E '^[[:alnum:]/_+%%=-]+$' | awk '!s[$0]++')
W1=$1; W2=$2; W3=$3; W4=$4; W5=$5; W6=$6
for v in P1 P2 TAG NTAG W1 W2 W3 W4 W5 W6; do eval \"echo $v=\\$$v\"; done; echo .
"
          (tramp-shell-quote-argument dir) rev rev rev rev))

(cl-defstruct (dalvrosa/magit-1rtt--s (:constructor dalvrosa/magit-1rtt--s (keys conn plan full dir top)))
  memo log keys conn plan procs flushed tried full dir top vars)

(defun dalvrosa/magit-1rtt--subs (s)
  (let ((dir (dalvrosa/magit-1rtt--s-dir s))
        (top (or (gethash (dalvrosa/magit-1rtt--s-full s) dalvrosa/magit-1rtt-tops) (dalvrosa/magit-1rtt--s-top s))))
    (seq-filter (lambda (x) (equal (tramp-shell-quote-argument (car x)) (car x)))
                (if (equal dir top) `((,top . "@TOP@")) `((,dir . "@DIR@") ,@(and top `((,top . "@TOP@"))))))))

(defun dalvrosa/magit-1rtt--open (name)
  (when-let* ((vec (and (tramp-tramp-file-p default-directory)
                        (tramp-dissect-file-name default-directory)))
              ((tramp-sh-file-name-handler-p vec))
              (full (directory-file-name (expand-file-name default-directory)))
              (dir (tramp-file-local-name full))
              (top (or (gethash full dalvrosa/magit-1rtt-tops)
                       (when-let* ((w (dalvrosa/tramp-watcher vec dir))) (directory-file-name (process-get w 'root)))
                       (and (derived-mode-p 'magit-mode) dir)
                       t))
              (keys (list (list name major-mode default-directory)
                          (list name (if (derived-mode-p 'magit-mode) major-mode 'file))
                          default-directory)))
    (dalvrosa/magit-1rtt--s keys (tramp-make-tramp-file-name vec 'noloc)
                   (pcase-let ((`(,e ,g ,d) (mapcar (lambda (k) (gethash (if (and (consp k) (length= k 2)) (append k (list (equal dir top))) k)
                                                                         dalvrosa/magit-1rtt-plans))
                                                     keys)))
                     (or e (if (and g d) (dalvrosa/magit-1rtt--merge g d) (or g d))))
                   full dir (and (stringp top) top))))

(defun dalvrosa/magit-1rtt--ptmpl (s key)
  (let ((cmd (car key)))
    (pcase-dolist (`(,path . ,tag) (dalvrosa/magit-1rtt--subs s))
      (setq cmd (replace-regexp-in-string (concat (regexp-quote path) "\\([/ ;)]\\|\\'\\)") (concat tag "\\1") cmd t)))
    (pcase-dolist (`(,v . ,tag) (dalvrosa/magit-1rtt--s-vars s))
      (setq cmd (replace-regexp-in-string (concat "\\(\\`\\|[^[:alnum:]_]\\)" (regexp-quote v) "\\([^[:alnum:]_]\\|\\'\\)")
                                          (concat "\\1" tag "\\2") cmd t)))
    (cons cmd (cdr key))))

(defun dalvrosa/magit-1rtt--segments (plan)
  (let ((segs (list nil)))
    (dolist (e plan) (if (eq e :write) (push nil segs) (push e (car segs))))
    (mapcar #'reverse (reverse segs))))

(defun dalvrosa/magit-1rtt--merge (new old)
  (let ((os (dalvrosa/magit-1rtt--segments old)))
    (cdr (mapcan (lambda (seg) (cons :write (append seg (seq-difference (pop os) seg))))
                 (dalvrosa/magit-1rtt--segments new)))))

(defun dalvrosa/magit-1rtt--fetch-vars (s)
  (when-let* ((rev (dalvrosa/magit-1rtt--cur-rev))
              ((not (dalvrosa/magit-1rtt--s-vars s)))
              (conn (dalvrosa/magit-1rtt--s-conn s))
              ((seq-some (lambda (e) (and (consp e) (string-match-p dalvrosa/magit-1rtt--dep-re (car e))))
                         (dalvrosa/magit-1rtt--s-log s))))
    (let ((vec (tramp-dissect-file-name conn)) (dalvrosa/magit-1rtt--read t))
      (ignore-errors
        (tramp-send-command vec (concat "(\n" (dalvrosa/magit-1rtt--vars-script (dalvrosa/magit-1rtt--s-dir s) rev) ")"))
        (with-current-buffer (tramp-get-connection-buffer vec)
          (setf (dalvrosa/magit-1rtt--s-vars s)
                (dalvrosa/magit-1rtt--parse-vars (car (split-string (buffer-string) "^\\.\n")))))))))

(defun dalvrosa/magit-1rtt--close (s)
  (dalvrosa/magit-1rtt--fetch-vars s)
  (when-let* ((plan (mapcar (lambda (e) (if (consp e) (dalvrosa/magit-1rtt--ptmpl s e) e))
                            (reverse (dalvrosa/magit-1rtt--s-log s)))))
    (let ((top-p (equal (mapcar #'cdr (dalvrosa/magit-1rtt--subs s)) '("@TOP@"))))
      (dolist (key (dalvrosa/magit-1rtt--s-keys s))
        (let ((key (if (and (consp key) (length= key 2)) (append key (list top-p)) key)))
          (puthash key (dalvrosa/magit-1rtt--merge plan (gethash key dalvrosa/magit-1rtt-logs)) dalvrosa/magit-1rtt-plans)
          (puthash key plan dalvrosa/magit-1rtt-logs)))))
  (setf (dalvrosa/magit-1rtt--s-memo s) nil (dalvrosa/magit-1rtt--s-conn s) nil))

(defun dalvrosa/magit-1rtt--write (s)
  (setf (dalvrosa/magit-1rtt--s-memo s) nil (dalvrosa/magit-1rtt--s-tried s) nil)
  (unless (eq (car (dalvrosa/magit-1rtt--s-log s)) :write)
    (push :write (dalvrosa/magit-1rtt--s-log s))
    (when-let* ((next (memq :write (dalvrosa/magit-1rtt--s-plan s))))
      (setf (dalvrosa/magit-1rtt--s-plan s) (cdr next)))))

(defun dalvrosa/magit-1rtt--pre-command ()
  (dalvrosa/magit-1rtt--post-command)
  (when (or (derived-mode-p 'magit-mode)
            (and (symbolp this-command) (string-match-p "\\`\\(magit\\|forge\\)-" (symbol-name this-command))))
    (setq dalvrosa/magit-1rtt--scope (dalvrosa/magit-1rtt--open this-command))))

(defun dalvrosa/magit-1rtt--post-command ()
  (when dalvrosa/magit-1rtt--scope
    (dalvrosa/magit-1rtt--close dalvrosa/magit-1rtt--scope)
    (setq dalvrosa/magit-1rtt--scope nil)))

(add-hook 'pre-command-hook #'dalvrosa/magit-1rtt--pre-command)
(add-hook 'post-command-hook #'dalvrosa/magit-1rtt--post-command)

(define-advice magit-refresh (:around (fn &rest args) dalvrosa/magit-1rtt)
  (if dalvrosa/magit-1rtt--scope
      (apply fn args)
    (let ((dalvrosa/magit-1rtt--scope (dalvrosa/magit-1rtt--open 'magit-refresh)))
      (unwind-protect (apply fn args)
        (when dalvrosa/magit-1rtt--scope (dalvrosa/magit-1rtt--close dalvrosa/magit-1rtt--scope))))))

(define-advice magit-process-file (:around (fn prog &optional in out disp &rest args) dalvrosa/magit-1rtt)
  (cond
   ((not (and dalvrosa/magit-1rtt--scope (file-remote-p default-directory) (null in)
              (equal prog (magit-git-executable))))
    (apply fn prog in out disp args))
   ((and (member out '(nil t (t nil))) (dalvrosa/magit-1rtt--read-only-p args))
    (let ((dalvrosa/magit-1rtt--git (mapconcat #'tramp-shell-quote-argument (cons prog args) " "))
          (process-file-side-effects nil))
      (unless (dalvrosa/magit-1rtt--s-flushed dalvrosa/magit-1rtt--scope)
        (setf (dalvrosa/magit-1rtt--s-flushed dalvrosa/magit-1rtt--scope) t)
        (unless (dalvrosa/tramp-watched-p default-directory)
          (tramp-flush-directory-properties (tramp-dissect-file-name default-directory)
                                            (tramp-file-local-name default-directory))))
      (apply fn prog in out disp args)))
   ((bufferp out)
    (let ((dalvrosa/magit-1rtt--wgit (mapconcat #'tramp-shell-quote-argument (cons prog args) " ")))
      (apply fn prog in out disp args)))
   (t (apply fn prog in out disp args))))

(define-advice make-process (:filter-return (proc) dalvrosa/magit-1rtt)
  (when-let* ((s dalvrosa/magit-1rtt--scope))
    (dalvrosa/magit-1rtt--write s)
    (push proc (dalvrosa/magit-1rtt--s-procs s)))
  proc)

(define-advice tramp-send-command (:before (&rest _) dalvrosa/magit-1rtt)
  (when (and dalvrosa/magit-1rtt--scope (not dalvrosa/magit-1rtt--read))
    (dalvrosa/magit-1rtt--write dalvrosa/magit-1rtt--scope)))

(defun dalvrosa/magit-1rtt--replay (vec hit exit)
  (with-current-buffer (tramp-get-connection-buffer vec)
    (let ((inhibit-read-only t)) (erase-buffer) (insert (car hit))))
  (if exit (cdr hit) (zerop (cdr hit))))

(defun dalvrosa/magit-1rtt--fold (s fn vec key exit)
  (let ((seg (seq-filter (apply-partially #'dalvrosa/magit-1rtt--untmpl s)
                         (car (dalvrosa/magit-1rtt--segments
                               (if (eq (car (dalvrosa/magit-1rtt--s-log s)) :write)
                                   (dalvrosa/magit-1rtt--s-plan s)
                                 (cdr (memq :write (dalvrosa/magit-1rtt--s-plan s)))))))))
    (dalvrosa/magit-1rtt--write s)
    (if (not seg)
        (apply fn vec (append key (list exit)))
      (let* ((m (dalvrosa/magit-1rtt--prefetch vec (cons key (mapcar (apply-partially #'dalvrosa/magit-1rtt--untmpl s) seg)) t))
             (hit (gethash key m)))
        (remhash key m)
        (setf (dalvrosa/magit-1rtt--s-memo s) m (dalvrosa/magit-1rtt--s-tried s) seg)
        (unless hit (tramp-error vec 'remote-file-error "Lost output of %s" (car key)))
        (dalvrosa/magit-1rtt--replay vec hit exit)))))

(define-advice tramp-send-command-and-check (:around (fn vec cmd &optional sub err exit) dalvrosa/magit-1rtt)
  (let* ((s dalvrosa/magit-1rtt--scope)
         (git (and s dalvrosa/magit-1rtt--git (stringp cmd) (string-search dalvrosa/magit-1rtt--git cmd)))
         (wgit (and s dalvrosa/magit-1rtt--wgit (stringp cmd) (string-search dalvrosa/magit-1rtt--wgit cmd)))
         (key (list cmd sub err))
         (ok (and s (dalvrosa/magit-1rtt--s-conn s) (stringp cmd)
                  (equal (dalvrosa/magit-1rtt--s-conn s) (tramp-make-tramp-file-name vec 'noloc))
                  (not (seq-some #'process-live-p (dalvrosa/magit-1rtt--s-procs s))))))
    (when git (setq dalvrosa/magit-1rtt--git nil))
    (when wgit (setq dalvrosa/magit-1rtt--wgit nil))
    (cond
     ((and ok wgit) (dalvrosa/magit-1rtt--fold s fn vec key exit))
     ((not (and ok (or git (string-match-p "\\`\\(test -[a-z] \\|tramp_stat_file_attributes\\(?:_with_selinux\\)? \\|tramp_readlink_file_truename \\)" cmd))
                (or git (not (string-search "\n" cmd))) (length< cmd 3000)))
      (funcall fn vec cmd sub err exit))
     (t
      (let* ((lkey (cons (dalvrosa/magit-1rtt--tmpl cmd) (cdr key)))
             (tkey (dalvrosa/magit-1rtt--ptmpl s lkey))
             (memo (dalvrosa/magit-1rtt--s-memo s))
             (hit (and memo (gethash key memo))))
        (unless (member lkey (seq-take-while #'consp (dalvrosa/magit-1rtt--s-log s)))
          (push lkey (dalvrosa/magit-1rtt--s-log s)))
        (unless (or hit (member tkey (dalvrosa/magit-1rtt--s-tried s)))
          (when-let* ((seg (seq-find (apply-partially #'member tkey)
                                     (dalvrosa/magit-1rtt--segments (dalvrosa/magit-1rtt--s-plan s))))
                      (rest (seq-filter (lambda (k) (and (not (member k (dalvrosa/magit-1rtt--s-tried s)))
                                                         (dalvrosa/magit-1rtt--untmpl s k t)))
                                        seg)))
            (let* ((ents (seq-uniq (mapcan (lambda (k) (dalvrosa/magit-1rtt--siblings (dalvrosa/magit-1rtt--untmpl s k t)))
                                           rest)))
                   (m (dalvrosa/magit-1rtt--prefetch
                       vec ents nil
                       (and (seq-some (lambda (e) (string-match-p dalvrosa/magit-1rtt--var-re (car e))) ents)
                            (dalvrosa/magit-1rtt--vars-script (dalvrosa/magit-1rtt--s-dir s) (dalvrosa/magit-1rtt--cur-rev))))))
              (when-let* ((v (gethash :vars m)))
                (setf (dalvrosa/magit-1rtt--s-vars s) v)
                (remhash :vars m))
              (setf (dalvrosa/magit-1rtt--s-tried s) (append rest (dalvrosa/magit-1rtt--s-tried s)))
              (if memo
                  (maphash (lambda (k v) (puthash k v memo)) m)
                (setf (dalvrosa/magit-1rtt--s-memo s) (setq memo m)))
              (setq hit (gethash key memo)))))
        (if hit
            (dalvrosa/magit-1rtt--replay vec hit exit)
          (let ((dalvrosa/magit-1rtt--read t)) (funcall fn vec cmd sub err exit))))))))

(define-advice tramp-send-command-and-check (:around (fn vec cmd &rest args) dalvrosa/magit-stdin)
  (let* ((in dalvrosa/magit-1rtt--stdin)
         (redir (and in (stringp cmd) (concat (car in) " <" (tramp-get-remote-null-device vec)))))
    (if (not (and redir (string-search redir cmd)))
        (apply fn vec cmd args)
      (setq dalvrosa/magit-1rtt--stdin nil)
      (apply fn vec (format "printf %%s '%s' | base64 -d | ( %s )" (cdr in) (string-replace redir (car in) cmd)) args))))

(define-advice magit-run-git-with-input (:around (fn &rest args) dalvrosa/magit-1rtt)
  (if (not (and (file-remote-p default-directory) (< (buffer-size) 65536)
                (tramp-sh-file-name-handler-p (tramp-dissect-file-name default-directory))))
      (apply fn args)
    (run-hooks 'magit-pre-call-git-hook)
    (pcase-let* ((flat (magit-process-git-arguments args))
                 (default-process-coding-system (magit--process-coding-system))
                 (dalvrosa/magit-1rtt--stdin
                  (cons (mapconcat #'tramp-shell-quote-argument (cons (magit-git-executable) flat) " ")
                        (base64-encode-string (encode-coding-string (buffer-string) (cdr default-process-coding-system)))))
                 (`(,buf . ,section) (magit-process-setup (magit-git-executable) flat))
                 (inhibit-read-only t))
      (magit-process-finish (apply #'magit-process-file (magit-git-executable) nil buf nil flat)
                            buf nil default-directory section))))

(define-advice magit-rev-parse-safe (:around (fn &rest args) dalvrosa/magit-1rtt)
  (let ((top (apply fn args)))
    (when (and top (equal args '("--show-toplevel")) (file-remote-p default-directory))
      (puthash (directory-file-name (expand-file-name default-directory)) top dalvrosa/magit-1rtt-tops))
    top))

(defvar magit--refresh-cache)

(defun dalvrosa/magit-1rtt-scoped (name fn &rest args)
  (let ((magit--refresh-cache (or magit--refresh-cache (list (cons 0 0)))))
    (if (or dalvrosa/magit-1rtt--scope (not (file-remote-p default-directory)))
        (apply fn args)
      (let ((dalvrosa/magit-1rtt--scope (dalvrosa/magit-1rtt--open name)))
        (unwind-protect (apply fn args)
          (when dalvrosa/magit-1rtt--scope (dalvrosa/magit-1rtt--close dalvrosa/magit-1rtt--scope)))))))

(defun dalvrosa/magit-1rtt-reading (fn &rest args)
  (let ((dalvrosa/magit-1rtt--read t)) (apply fn args)))
(advice-add 'magit-file-line :around #'dalvrosa/magit-1rtt-reading)
(advice-add 'magit-file-lines :around #'dalvrosa/magit-1rtt-reading)

(with-eval-after-load 'with-editor
  (define-advice with-editor-sleeping-editor-filter (:around (fn process string) dalvrosa/magit-1rtt)
    (if (string-search "WITH-EDITOR: " string)
        (dalvrosa/magit-1rtt-scoped 'with-editor-visit fn process string)
      (funcall fn process string))))

(with-eval-after-load 'magit
  (define-advice magit-process-sentinel (:around (fn process event) dalvrosa/magit-1rtt)
    (let ((default-directory (or (process-get process 'default-dir) default-directory)))
      (if (memq (process-status process) '(exit signal))
          (dalvrosa/magit-1rtt-scoped 'magit-process-sentinel fn process event)
        (funcall fn process event))))
  (define-advice magit-refresh-buffer (:around (fn &rest args) dalvrosa/magit-1rtt)
    (apply #'dalvrosa/magit-1rtt-scoped 'magit-refresh-buffer fn args)))

(defvar dalvrosa/magit-1rtt--rev nil)

(defvar dalvrosa/magit-1rtt--point-rev nil)

(define-advice dalvrosa/magit-1rtt--pre-command (:after () rev)
  (setq dalvrosa/magit-1rtt--point-rev
        (and dalvrosa/magit-1rtt--scope (derived-mode-p 'magit-mode)
             (let ((r (ignore-errors (magit-section-value-if 'commit))))
               (and (stringp r) (string-match-p "\\`[0-9a-f]\\{7,40\\}\\'" r) r)))))

(defun dalvrosa/magit-1rtt--cur-rev () (or dalvrosa/magit-1rtt--rev dalvrosa/magit-1rtt--point-rev))

(defun dalvrosa/magit-1rtt--tmpl (cmd)
  (if-let* ((rev (dalvrosa/magit-1rtt--cur-rev)))
      (replace-regexp-in-string (concat "\\b" (regexp-quote rev) "\\b") "@REV@" cmd t t)
    cmd))

(defun dalvrosa/magit-1rtt--untmpl (s key &optional remote)
  (let ((cmd (car key)) (rev (dalvrosa/magit-1rtt--cur-rev)))
    (pcase-dolist (`(,path . ,tag) (dalvrosa/magit-1rtt--subs s))
      (setq cmd (string-replace tag path cmd)))
    (setq cmd (if rev (string-replace "@REV@" rev cmd) cmd))
    (pcase-dolist (`(,v . ,tag) (dalvrosa/magit-1rtt--s-vars s))
      (setq cmd (string-replace tag v cmd)))
    (and (not (string-match-p "@\\(TOP\\|DIR\\|REV\\)@" cmd))
         (or (and remote rev) (not (string-match-p dalvrosa/magit-1rtt--var-re cmd)))
         (cons cmd (cdr key)))))

(defun dalvrosa/magit-1rtt--with-rev (fn rev &rest args)
  (let ((dalvrosa/magit-1rtt--rev (and (stringp rev) (string-match-p "\\`[0-9a-f]\\{7,40\\}\\'" rev) rev)))
    (apply #'dalvrosa/magit-1rtt-scoped 'magit-show-commit fn rev args)))
(advice-add 'magit-show-commit :around #'dalvrosa/magit-1rtt--with-rev)

(with-eval-after-load 'savehist
  (add-to-list 'savehist-additional-variables 'dalvrosa/magit-1rtt-plans)
  (add-to-list 'savehist-additional-variables 'dalvrosa/magit-1rtt-logs)
  (add-to-list 'savehist-additional-variables 'dalvrosa/magit-1rtt-tops))

(with-eval-after-load 'magit
  (define-advice magit--git-insert (:around (fn return-error &rest args) remote-stderr)
    (if (and return-error (not magit-git-debug) (file-remote-p default-directory))
        (let* ((beg (point)) (exit (apply fn nil args)))
          (if (eq exit 0) exit (delete-region beg (point)) (apply fn return-error args)))
      (apply fn return-error args))))

(defvar dalvrosa/tramp-depth 0)
(defvar dalvrosa/tramp-queue nil)
(defvar dalvrosa/tramp-drain-timer nil)

(defun dalvrosa/tramp-busy-p ()
  (or (> dalvrosa/tramp-depth 0)
      (seq-some (lambda (p) (and (process-get p 'tramp-vector) (process-live-p p)
                                 (tramp-get-connection-property p "locked")))
                (process-list))))

(defun dalvrosa/tramp-drain ()
  (while (and dalvrosa/tramp-queue (not (dalvrosa/tramp-busy-p)))
    (let ((call (car (last dalvrosa/tramp-queue))))
      (setq dalvrosa/tramp-queue (butlast dalvrosa/tramp-queue))
      (with-demoted-errors "dalvrosa/tramp-drain: %S" (apply call))))
  (when (and (not dalvrosa/tramp-queue) dalvrosa/tramp-drain-timer)
    (cancel-timer dalvrosa/tramp-drain-timer)
    (setq dalvrosa/tramp-drain-timer nil)))

(define-advice tramp-file-name-handler (:around (fn &rest args) dalvrosa/queue)
  (unwind-protect
      (let ((dalvrosa/tramp-depth (1+ dalvrosa/tramp-depth))) (apply fn args))
    (when (and dalvrosa/tramp-queue (= dalvrosa/tramp-depth 0)) (dalvrosa/tramp-drain))))

(defun dalvrosa/tramp-defer (fn &rest args)
  (if (or dalvrosa/tramp-queue (dalvrosa/tramp-busy-p))
      (progn (push (cons fn args) dalvrosa/tramp-queue)
             (unless dalvrosa/tramp-drain-timer
               (setq dalvrosa/tramp-drain-timer (run-with-timer 0.1 0.1 #'dalvrosa/tramp-drain))))
    (apply fn args)))
(dolist (fn '(with-editor-process-filter magit-process-sentinel magit-sequencer-process-sentinel
              magit-delete-remote-branch-sentinel magit-blame-process-filter
              magit-blame-process-sentinel magit-blame-process-quickstart-sentinel))
  (advice-add fn :around #'dalvrosa/tramp-defer))

(define-advice tramp-handle-make-process (:around (fn &rest args) dalvrosa/histfile)
  (let ((tramp-histfile-override nil))
    (apply fn args)))

(defvar dalvrosa/ghostel-spawning nil)
(defvar dalvrosa/ghostel-spares nil)
(defvar dalvrosa/ghostel-spare-args nil)
(defconst dalvrosa/ghostel-spare-script
  "stty raw -echo 2>/dev/null; printf 'dalvrosa-spare\\n'; IFS= read -r n; c=$(head -c \"$n\"); eval \"$c\"")

(defun dalvrosa/ghostel-spare-find (args)
  (seq-find (lambda (p) (and (process-live-p p) (equal (process-get p 'args) args)))
            dalvrosa/ghostel-spares))

(defun dalvrosa/ghostel-spare (args)
  (setq dalvrosa/ghostel-spares (seq-filter #'process-live-p dalvrosa/ghostel-spares))
  (unless (dalvrosa/ghostel-spare-find args)
    (let ((p (make-process :name "dalvrosa-ghostel-spare"
                           :command (append args (list dalvrosa/ghostel-spare-script))
                           :connection-type 'pty :noquery t :coding 'binary :sentinel #'ignore
                           :filter (lambda (p s)
                                     (when (string-search "dalvrosa-spare" s) (process-put p 'ready t))))))
      (process-put p 'args args)
      (push p dalvrosa/ghostel-spares))))

(define-advice make-process (:around (fn &rest args) dalvrosa/ghostel-spare)
  (let* ((cmd (plist-get args :command))
         (key (and dalvrosa/ghostel-spawning (equal (plist-get args :name) "ghostel")
                   (equal (car cmd) "ssh") (butlast cmd)))
         (spare (and key (dalvrosa/ghostel-spare-find key))))
    (when key
      (add-to-list 'dalvrosa/ghostel-spare-args key)
      (run-with-timer 0.5 nil #'dalvrosa/ghostel-spare key))
    (if (not (and spare (process-get spare 'ready)))
        (apply fn args)
      (setq dalvrosa/ghostel-spares (delq spare dalvrosa/ghostel-spares))
      (let ((c (encode-coding-string (car (last cmd)) 'utf-8)))
        (set-process-buffer spare (plist-get args :buffer))
        (set-process-filter spare (or (plist-get args :filter) #'internal-default-process-filter))
        (set-process-sentinel spare (or (plist-get args :sentinel) #'internal-default-process-sentinel))
        (set-process-query-on-exit-flag spare (not (plist-get args :noquery)))
        (process-send-string spare (format "%d\n%s" (length c) c)))
      spare)))

(with-eval-after-load 'ghostel
  (define-advice ghostel--spawn-via-emacs (:around (fn program args &optional remote-p) dalvrosa/spare)
    (let ((dalvrosa/ghostel-spawning remote-p))
      (funcall fn program args remote-p))))

(with-eval-after-load 'savehist
  (add-to-list 'savehist-additional-variables 'dalvrosa/ghostel-spare-args))

(define-advice dalvrosa/tramp-warm-connect (:after (&rest _) dalvrosa/ghostel-spare)
  (mapc #'dalvrosa/ghostel-spare dalvrosa/ghostel-spare-args))

(defvar dalvrosa/tramp-setup nil)
(cl-defstruct (dalvrosa/tramp-setup--s (:constructor dalvrosa/tramp-setup--s (proc plan)))
  proc plan rec log memo shell)

(defun dalvrosa/tramp-setup-tmpl (s)
  (string-replace tramp-end-of-heredoc "@H@"
                  (string-replace tramp-end-of-output "@O@"
                                  (string-replace (tramp-shell-quote-argument tramp-end-of-output) "@Q@" s))))

(defun dalvrosa/tramp-setup-untmpl (s)
  (string-replace "@Q@" (tramp-shell-quote-argument tramp-end-of-output)
                  (string-replace "@H@" tramp-end-of-heredoc (string-replace "@O@" tramp-end-of-output s))))

(defun dalvrosa/tramp-setup-batch (fn vec cmds)
  (let ((mark (md5 tramp-end-of-heredoc)))
    (funcall fn vec (concat "{\n" (mapconcat (lambda (c) (concat c "\necho; echo " mark "\n")) cmds) "}") t)
    (with-current-buffer (tramp-get-connection-buffer vec)
      (cl-mapcar #'cons cmds (split-string (buffer-string) (concat "\n" mark "\n"))))))

(defun dalvrosa/tramp-setup-replay (s fn vec command args)
  (if-let* ((memo (dalvrosa/tramp-setup--s-memo s))
            (hit (member (assoc command memo) memo)))
      (progn
        (setf (dalvrosa/tramp-setup--s-memo s) (cdr hit))
        (with-current-buffer (tramp-get-connection-buffer vec)
          (let ((inhibit-read-only t)) (erase-buffer) (insert (cdar hit))))
        t)
    (setf (dalvrosa/tramp-setup--s-memo s) nil)
    (apply fn vec command args)))

(defun dalvrosa/tramp-pipeline-shell (vec)
  (and (not tramp-use-connection-share)
       (not (tramp-get-connection-property vec " process-name"))
       (equal (tramp-get-method-parameter vec 'tramp-login-program) "ssh")
       (null (cdr (tramp-compute-multi-hops vec)))
       (when-let* ((shell (tramp-get-connection-property vec "dalvrosa-setup-shell")))
         (and (eq 0 (apply #'call-process "ssh" nil nil nil "-O" "check"
                           `(,@(when-let* ((u (tramp-file-name-user vec))) (list "-l" u))
                             ,@(when-let* ((p (tramp-file-name-port vec))) (list "-p" p))
                             ,(tramp-file-name-host vec))))
              (dalvrosa/tramp-setup-untmpl shell)))))

(defun dalvrosa/tramp-pipelined-shell-p (p command)
  (when-let* ((shell (process-get p 'dalvrosa/pipelined)))
    (process-put p 'dalvrosa/pipelined nil)
    (if (not (with-current-buffer (process-buffer p)
               (ignore-errors (tramp-wait-for-regexp p 10 (rx (literal tramp-end-of-output))))))
        (ignore (tramp-flush-connection-property (process-get p 'tramp-vector) "dalvrosa-setup-shell"))
      (with-current-buffer (process-buffer p)
        (let ((inhibit-read-only t))
          (delete-region (point-min) (point-max))
          (insert tramp-end-of-output)))
      (equal shell command))))

(define-advice tramp-send-command (:around (fn vec command &rest args) dalvrosa/plan)
  (let* ((s dalvrosa/tramp-setup)
         (p (tramp-get-connection-process vec))
         (login (and (car args) (cadr args) (stringp command)))
         (s (and s (eq p (dalvrosa/tramp-setup--s-proc s)) (stringp command) s)))
    (cond
     ((and login (not s) (not (tramp-get-connection-property p "connected")))
      (if-let* ((shell (dalvrosa/tramp-pipeline-shell vec)))
          (progn (process-put p 'dalvrosa/pipelined shell)
                 (apply fn vec (concat command "\n" shell) args))
        (apply fn vec command args)))
     ((not s) (apply fn vec command args))
     ((and login (string-prefix-p "exec env " command))
      (setf (dalvrosa/tramp-setup--s-shell s) (dalvrosa/tramp-setup-tmpl command))
      (unless (dalvrosa/tramp-pipelined-shell-p p command)
        (apply fn vec command args)))
     ((dalvrosa/tramp-setup--s-rec s)
      (push (dalvrosa/tramp-setup-tmpl command) (dalvrosa/tramp-setup--s-log s))
      (dalvrosa/tramp-setup-replay s fn vec command args))
     ((string-prefix-p "stty -inlcr" command)
      (setf (dalvrosa/tramp-setup--s-rec s) t)
      (when-let* ((plan (dalvrosa/tramp-setup--s-plan s)))
        (setf (dalvrosa/tramp-setup--s-memo s)
              (ignore-errors
                (dalvrosa/tramp-setup-batch
                 fn vec (cons command (mapcar #'dalvrosa/tramp-setup-untmpl plan))))))
      (dalvrosa/tramp-setup-replay s fn vec command args))
     (t (apply fn vec command args)))))

(define-advice tramp-open-connection-setup-interactive-shell (:around (fn proc vec) dalvrosa/plan)
  (if (tramp-get-connection-property vec " process-name")
      (funcall fn proc vec)
    (let ((dalvrosa/tramp-setup
           (dalvrosa/tramp-setup--s proc (tramp-get-connection-property vec "dalvrosa-setup-plan"))))
      (funcall fn proc vec)
      (ignore-errors
        (tramp-remote-selinux-p vec)
        (tramp-get-inline-coding vec "remote-encoding" (1+ (or tramp-inline-compress-start-size 0)))
        (when (tramp-get-remote-readlink vec)
          (tramp-maybe-send-script vec tramp-readlink-file-truename "tramp_readlink_file_truename"))
        (when (tramp-get-remote-stat vec)
          (tramp-maybe-send-script vec tramp-stat-file-attributes "tramp_stat_file_attributes"))
        (when (tramp-get-remote-perl vec)
          (tramp-maybe-send-script vec tramp-perl-file-name-all-completions
                                   "tramp_perl_file_name_all_completions"))
        (tramp-get-remote-uid vec 'integer)
        (when (tramp-get-ls-command vec)
          (tramp-get-ls-command-with vec "--quoting-style=literal --show-control-chars")
          (tramp-get-ls-command-with vec "--dired")))
      (unless (tramp-get-connection-property proc "remote-echo")
        (tramp-set-connection-property vec "dalvrosa-setup-shell"
                                       (dalvrosa/tramp-setup--s-shell dalvrosa/tramp-setup))
        (let ((plan (dalvrosa/tramp-setup--s-plan dalvrosa/tramp-setup))
              (log (reverse (dalvrosa/tramp-setup--s-log dalvrosa/tramp-setup))))
          (tramp-set-connection-property vec "dalvrosa-setup-plan"
                                         (if (dalvrosa/subsequence-p log plan) plan log)))))))

(defun dalvrosa/subsequence-p (a b)
  (while (and a b)
    (when (equal (car a) (pop b)) (pop a)))
  (null a))

(define-advice tramp-cleanup-connection (:around (fn vec &rest args) dalvrosa/keep-plan)
  (let ((keep (and (tramp-file-name-p vec)
                   (mapcar (lambda (k) (cons k (tramp-get-connection-property vec k)))
                           '("dalvrosa-setup-plan" "dalvrosa-setup-shell")))))
    (prog1 (apply fn vec args)
      (pcase-dolist (`(,k . ,v) keep)
        (when v (tramp-set-connection-property vec k v))))))

(define-advice tramp-maybe-send-script (:before (vec &rest _) dalvrosa/open-first)
  (unless (process-live-p (tramp-get-connection-process vec))
    (tramp-maybe-open-connection vec)))
(advice-add 'tramp-remote-selinux-p :before #'tramp-maybe-send-script@dalvrosa/open-first)

(defun dalvrosa/tramp-fnac-prop ()
  (format "file-name-all-completions-%s" tramp-fnac-add-trailing-slash))

(defun dalvrosa/tramp-watch-project (dir)
  (when-let* (((tramp-tramp-file-p dir))
              (v (tramp-dissect-file-name (expand-file-name dir)))
              (l (directory-file-name (tramp-file-name-localname v)))
              (p (dalvrosa/tramp-watcher v l))
              (root (directory-file-name (process-get p 'root))))
    (while (and l (not (equal l root)))
      (let ((names (tramp-get-file-property v l (dalvrosa/tramp-fnac-prop) 'undef)))
        (setq l (and (listp names) (not (member ".git" names)) (not (member ".git/" names))
                     (directory-file-name (file-name-directory l))))))
    (and l (process-get p 'project))))

(defun dalvrosa/tramp-missing-p (v l)
  (let (res)
    (while (and (not res) (string-prefix-p "/" l) (not (equal l "/")))
      (let* ((up (directory-file-name (file-name-directory l)))
             (names (tramp-get-file-property v up (dalvrosa/tramp-fnac-prop) 'undef))
             (n (file-name-nondirectory l)))
        (if (listp names)
            (setq res (if (or (member n names) (member (concat n "/") names)) 'present 'missing))
          (setq l up))))
    (eq res 'missing)))

(defun dalvrosa/tramp-unless-missing (fn filename &rest args)
  (let ((f (expand-file-name filename)))
    (unless (and (tramp-tramp-file-p f)
                 (let ((v (tramp-dissect-file-name f)))
                   (dalvrosa/tramp-missing-p v (directory-file-name (tramp-file-name-localname v)))))
      (apply fn filename args))))
(dolist (fn '(tramp-sh-handle-file-exists-p tramp-sh-handle-file-attributes tramp-sh-handle-file-directory-p
              tramp-sh-handle-file-readable-p tramp-sh-handle-file-executable-p))
  (advice-add fn :around #'dalvrosa/tramp-unless-missing))

(define-advice tramp-sh-handle-file-truename (:before (filename) dalvrosa/missing)
  (let* ((v (tramp-dissect-file-name (expand-file-name filename)))
         (l (tramp-file-name-localname v))
         (up (and (string-prefix-p "/" l) (not (directory-name-p l)) (directory-file-name (file-name-directory l))))
         (tn (and up (dalvrosa/tramp-missing-p v l) (tramp-get-file-property v up "file-truename" nil))))
    (when (and (stringp tn) (string-prefix-p "/" tn) (not (file-name-quoted-p tn)))
      (setq dalvrosa/tramp-ff-memo
            (cons v (cons (cons (list (concat "tramp_readlink_file_truename " (tramp-shell-quote-argument l)) nil nil)
                                (cons (format "nil\n%s\n" (concat (file-name-as-directory tn) (file-name-nondirectory l))) 0))
                          (and dalvrosa/tramp-ff-memo (tramp-file-name-equal-p v (car dalvrosa/tramp-ff-memo))
                               (cdr dalvrosa/tramp-ff-memo))))))))

(define-advice executable-find (:around (fn command &optional remote) dalvrosa/1rtt)
  (if-let* (((and remote (tramp-tramp-file-p default-directory)
                  (not (string-search "/" command)) (equal (exec-suffixes) '(""))))
            (v (tramp-dissect-file-name default-directory))
            ((tramp-sh-file-name-handler-p v))
            (dirs (exec-path)))
      (progn
        (tramp-send-command
         v (format "for d in %s; do test -x \"$d\"/%s && ! test -d \"$d\"/%s && { echo \"$d\"; break; }; done"
                   (mapconcat #'tramp-shell-quote-argument dirs " ")
                   (tramp-shell-quote-argument command) (tramp-shell-quote-argument command)))
        (with-current-buffer (tramp-get-connection-buffer v)
          (let ((d (string-trim (buffer-string))))
            (and (member d dirs) (expand-file-name command d)))))
    (funcall fn command remote)))

(defun dalvrosa/tramp-meta-keys (v q)
  (let ((test (tramp-get-test-command v)))
    (mapcar (lambda (f) (list (format f q) nil nil))
            (list (concat test " -d %s") (concat (tramp-get-file-exists-command v) " %s")
                  (concat test " -r %s") (concat test " -w %s")
                  "tramp_readlink_file_truename %s" "tramp_stat_file_attributes %s"))))

(defun dalvrosa/tramp-meta-script (v keys)
  (concat "{\n" (mapconcat (lambda (k) (format "%s 2>%s; echo tramp_exit_status $?\n"
                                               (car k) (tramp-get-remote-null-device v)))
                           keys "")
          "}"))

(defun dalvrosa/tramp-meta-read (v keys old)
  (let (memo)
    (goto-char (point-min))
    (dolist (k keys)
      (let ((beg (point)))
        (when (re-search-forward "^tramp_exit_status \\([0-9]+\\)\n" nil t)
          (push (cons k (cons (buffer-substring beg (match-beginning 0)) (string-to-number (match-string 1))))
                memo))))
    (setq dalvrosa/tramp-ff-memo (cons v (append memo old)))))

(defun dalvrosa/tramp-meta-prefetch (v q)
  (let ((keys (dalvrosa/tramp-meta-keys v q))
        (old (and dalvrosa/tramp-ff-memo (tramp-file-name-equal-p v (car dalvrosa/tramp-ff-memo))
                  (cdr dalvrosa/tramp-ff-memo))))
    (tramp-send-command v (dalvrosa/tramp-meta-script v keys))
    (with-current-buffer (tramp-get-connection-buffer v)
      (dalvrosa/tramp-meta-read v keys old))))

(defun dalvrosa/tramp-meta-p (vec)
  (let ((scripts (tramp-get-connection-property (tramp-get-connection-process vec) "scripts")))
    (and (not dalvrosa/magit-1rtt--scope) (not (tramp-remote-selinux-p vec))
         (member "tramp_stat_file_attributes" scripts) (member "tramp_readlink_file_truename" scripts))))

(define-advice tramp-send-command-and-check (:around (fn vec cmd &optional sub err exit) dalvrosa/mutate)
  (if-let* (((and (not err) (not exit) (stringp cmd) (not (string-search "\n" cmd))
                  (string-match "\\`\\(?:cp\\|mv\\|mkdir\\|ln\\) .* \\(\\(?:[^ \\\\]\\|\\\\.\\)+\\)\\'" cmd)))
            (q (match-string 1 cmd))
            ((dalvrosa/tramp-meta-p vec))
            (keys (dalvrosa/tramp-meta-keys vec q))
            (script (dalvrosa/tramp-meta-script vec keys)))
      (let ((res (funcall fn vec (format "%s 2>%s; s=$?; %s; echo dalvrosa_meta; test $s = 0"
                                         cmd (tramp-get-remote-null-device vec) script)
                          sub err exit)))
        (with-current-buffer (tramp-get-connection-buffer vec)
          (goto-char (point-min))
          (when (search-forward "dalvrosa_meta\n" nil t)
            (save-restriction
              (narrow-to-region (point-min) (match-beginning 0))
              (dalvrosa/tramp-meta-read vec keys nil))
            (let ((inhibit-read-only t)) (delete-region (point-min) (match-end 0)))))
        res)
    (funcall fn vec cmd sub err exit)))

(define-advice tramp-send-command-and-check (:around (fn vec cmd &optional sub err exit) dalvrosa/meta)
  (when (and (not sub) (not err) (stringp cmd)
             (string-match "\\`\\(test -[derw]\\|tramp_stat_file_attributes\\|tramp_readlink_file_truename\\) \\([^\n]+\\)\\'" cmd)
             (not (and dalvrosa/tramp-ff-memo (tramp-file-name-equal-p vec (car dalvrosa/tramp-ff-memo))
                       (assoc (list cmd nil nil) (cdr dalvrosa/tramp-ff-memo))))
             (dalvrosa/tramp-meta-p vec))
    (ignore-errors (dalvrosa/tramp-meta-prefetch vec (match-string 2 cmd))))
  (funcall fn vec cmd sub err exit))

(defun dalvrosa/tramp-meta-clear (&rest _) (setq dalvrosa/tramp-ff-memo nil))
(add-hook 'pre-command-hook #'dalvrosa/tramp-meta-clear)
(add-hook 'post-command-hook #'dalvrosa/tramp-meta-clear)
(advice-add 'tramp-handle-make-process :before #'dalvrosa/tramp-meta-clear)
(advice-add 'tramp-sh-handle-make-process :before #'dalvrosa/tramp-meta-clear)

(defvar dalvrosa/tramp-cd nil)
(define-advice tramp-sh-handle-insert-directory (:around (fn file switches &optional wildcard full) dalvrosa/cd)
  (let* ((f (expand-file-name file))
         (v (tramp-dissect-file-name f))
         (d (directory-file-name (file-name-directory (tramp-file-name-localname v))))
         (dalvrosa/tramp-cd (and (not wildcard) (not full)
                                 (or (eq t (tramp-get-file-property v d "file-directory-p" nil))
                                     (listp (tramp-get-file-property v d (dalvrosa/tramp-fnac-prop) 'undef)))
                                 'pending)))
    (funcall fn file switches wildcard full)))
(define-advice tramp-send-command-and-check (:around (fn vec cmd &rest args) dalvrosa/cd)
  (if (and (eq dalvrosa/tramp-cd 'pending) (stringp cmd) (string-prefix-p "cd " cmd) (not (string-search "\n" cmd)))
      (progn (setq dalvrosa/tramp-cd cmd) t)
    (apply fn vec cmd args)))
(define-advice tramp-send-command (:around (fn vec command &rest args) dalvrosa/cd)
  (if (and (stringp dalvrosa/tramp-cd) (string-prefix-p (tramp-get-ls-command vec) command))
      (let ((cd dalvrosa/tramp-cd))
        (setq dalvrosa/tramp-cd nil)
        (apply fn vec (concat cd " && " command) args))
    (apply fn vec command args)))

(define-advice tramp-sh-handle-set-file-uid-gid (:before-while (filename &optional uid gid) dalvrosa/noop)
  (let ((v (tramp-dissect-file-name filename)))
    (not (and (natnump uid) (not (zerop uid))
              (eql uid (tramp-get-remote-uid v 'integer))
              (eql gid (tramp-get-remote-gid v 'integer))))))

(provide 'dalvrosa-tramp)
