;;; -*- lexical-binding: t; -*-

(setq gc-cons-threshold most-positive-fixnum)

(defvar dalvrosa/file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)
(add-hook 'after-init-hook
          (lambda ()
            (setq file-name-handler-alist dalvrosa/file-name-handler-alist))
          -100)

(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(setq frame-inhibit-implied-resize t)

(setq package-quickstart t)
(setq native-comp-async-report-warnings-errors nil)
(setq load-prefer-newer t)

(push '(font . "monospace-9") default-frame-alist)
