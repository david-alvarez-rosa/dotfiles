;;; package --- Configuración de Emacs de David Álvarez
;;; Commentary:
;;   - Toda la configuración se encuentra en 'config.org'.
;;; Code:

(package-initialize)

(defun david/load-config ()
  "Cargar la configuración."
  (interactive)
  (org-babel-load-file "~/.emacs.d/config.org"))

(david/load-config)

;;; init.el ends here
