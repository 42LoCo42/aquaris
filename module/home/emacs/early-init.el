;;; -*- lexical-binding: t -*-

;; speed up startup
(setq my/old-gc-cons-treshold 100000000)
(setq gc-cons-threshold 500000000)
(message "gc-cons-threshold raised to %s" gc-cons-threshold)

(run-with-idle-timer
 3 nil
 (lambda ()
   (setq gc-cons-threshold my/old-gc-cons-treshold)
   (message "gc-cons-threshold restored to %s" gc-cons-threshold)))

(setq package-enable-at-startup nil)
