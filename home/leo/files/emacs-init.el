(defun may-load (filename)
  "Load file FILENAME only if it exists."
  (when (file-readable-p filename)
    (load-file filename)))

(setq inhibit-startup-screen t)     ; don't show the GNU splash screen
(setq frame-title-format "%b")      ; titlebar shows buffer's name
(global-font-lock-mode 1)           ; syntax highlighting
(setq font-lock-maximum-decoration t)   ; max decoration for all modes
;; (transient-mark-mode 1)                 ; highlight selection
(size-indication-mode 1)                ; buffer's size
(line-number-mode 1)                    ; line number
(column-number-mode 1)                  ; column number
;; UI settings — applied via hook so they work for both standalone
;; emacs and daemon-created frames (daemon starts headless, so
;; display-graphic-p is nil at init time).
(defun my/setup-gui-frame (frame)
  "Configure GUI chrome for FRAME."
  (with-selected-frame frame
    (when (display-graphic-p frame)
      (scroll-bar-mode -1)
      (menu-bar-mode 1)
      (tool-bar-mode -1)
      (mouse-wheel-mode 1))))
(my/setup-gui-frame (selected-frame))
(add-hook 'after-make-frame-functions #'my/setup-gui-frame)
(setq scroll-step 1)                    ; smooth scrolling

(setq delete-auto-save-files t)    ; delete unnecessary autosave files
(setq delete-old-versions t)       ; delete oldversion file
(setq make-backup-files nil)       ; no backupfile

(if (display-graphic-p)
    (normal-erase-is-backspace-mode 1)) ; make delete work as it should

(defalias 'yes-or-no-p 'y-or-n-p)    ; 'y or n' instead of 'yes or no'
(setq-default major-mode 'text-mode) ; change default major mode to text
(setq ring-bell-function 'ignore)    ; turn the alarm totally off


;; FIXME: wanted 99.9% of the time, but can cause your death 0.1% of
;; the time =). TODO: save buffer before reverting
;;(global-auto-revert-mode t)         ; auto revert modified files

;; (pc-selection-mode)                     ; selection with shift
(auto-image-file-mode)                  ; to see picture in emacs
;; (dynamic-completion-mode)               ; dynamic completion
(show-paren-mode 1)                 ; match parenthesis
(setq-default indent-tabs-mode nil) ; nil == don't use fucking tabs to indent

;;; HOOKS

;; Show trailing whitespace
(setq-default show-trailing-whitespace t)


(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(font-lock-comment-face ((t (:foreground "dark red")))))

;; Shebangs
(defun insert-shebang (bin)
  (interactive "sBin: ")
  (save-excursion
    (goto-char (point-min))
    (insert "#! " bin "\n\n")))


;; Start code folding mode in C/C++ mode
(add-hook 'c-mode-common-hook (lambda () (hs-minor-mode 1)))


;; File extensions
(add-to-list 'auto-mode-alist '("\\.l\\'" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.y\\'" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.ll\\'" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.yy\\'" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.xcc\\'" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.xhh\\'" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.pro\\'" . sh-mode)) ; Qt .pro files
(add-to-list 'auto-mode-alist '("configure\\'" . sh-mode))
(add-to-list 'auto-mode-alist '("Drakefile\\'" . c++-mode))
(add-to-list 'auto-mode-alist '("COMMIT_EDITMSG" . change-log-mode))


;;; ido --- interactively do things
(defconst has-ido (>= emacs-major-version 22))

(when (ido-mode 1)
  (ido-everywhere 1)
  ;; tab means tab, i.e. complete. Not "open this file", stupid.
  (setq ido-confirm-unique-completion t)
  ;; If the file doesn't exist, do not try to invent one from a
  ;; transplanar directory. I just want a new file.
  (setq ido-auto-merge-work-directories-length -1)
  ;; If buffer name doesn't exist, create one.
  (setq ido-create-new-buffer 'always)
  ;; Don't switch to GDB-mode buffers
  (add-to-list 'ido-ignore-buffers "\\`\\*locals of.*\\*\\'")
  (add-to-list 'ido-ignore-buffers "\\`\\*gud\\*\\'")
  (add-to-list 'ido-ignore-buffers "\\`\\*stack frames of.*\\*\\'")
  (add-to-list 'ido-ignore-buffers "\\`\\*breakpoints of.*\\*\\'")
  (add-to-list 'ido-ignore-buffers "locals"))


;;; BINDINGS

;; BINDINGS :: windows
(global-unset-key [(control s)])
(global-set-key [(control s) (v)] 'split-window-horizontally)
(global-set-key [(control s) (h)] 'split-window-vertically)
(global-set-key [(control s) (d)] 'delete-window)
(global-set-key [(control s) (o)] 'delete-other-windows)

;; BINDINGS :: ido
(when (featurep 'ido)
  (global-set-key [(control b)] 'ido-switch-buffer))

;; BINDINGS :: isearch
(global-set-key [(control f)] 'isearch-forward-regexp) ; search regexp
(global-set-key [(control r)] 'query-replace-regexp) ; replace regexp
(define-key isearch-mode-map
  [(control n)] 'isearch-repeat-forward) ; next occurence
(define-key isearch-mode-map
  [(control p)] 'isearch-repeat-backward) ; previous occurence
(define-key isearch-mode-map
  [(control z)] 'isearch-cancel)     ; quit and go back to start point
(define-key isearch-mode-map
  [(control f)] 'isearch-exit)          ; abort
(define-key isearch-mode-map
  [(control r)] 'isearch-query-replace) ; switch to replace mode
(define-key isearch-mode-map
  [S-insert] 'isearch-yank-kill)        ; paste
(define-key isearch-mode-map
  [(control e)] 'isearch-toggle-regexp) ; toggle regexp
(define-key isearch-mode-map
  [(control l)] 'isearch-yank-line)     ; yank line from buffer
(define-key isearch-mode-map
  [(control w)] 'isearch-yank-word)     ; yank word from buffer
(define-key isearch-mode-map
  [(control c)] 'isearch-yank-char)     ; yank char from buffer

(global-set-key [(meta =)] 'stat-region)

;; Remap C-z to undo in graphic frames (must use a hook because the
;; daemon has no frame at init time, so display-graphic-p is nil).
(defun my/setup-graphic-keys (frame)
  "Keybindings that only make sense in a graphical frame."
  (when (display-graphic-p frame)
    (with-selected-frame frame
      (global-set-key [(control z)] 'undo))))
(add-hook 'after-make-frame-functions #'my/setup-graphic-keys)
;; (global-set-key [(control a)] 'mark-whole-buffer) ; select whole buffer
(global-set-key [(control return)] 'hippie-expand) ; auto completion
(global-set-key [C-home] 'beginning-of-buffer) ; go to the beginning of buffer
(global-set-key [C-end] 'end-of-buffer)    ; go to the end of buffer
(global-set-key [(meta g)] 'goto-line)     ; goto line #
(global-set-key [M-left] 'windmove-left)   ; move to left windnow
(global-set-key [M-right] 'windmove-right) ; move to right window
(global-set-key [M-up] 'windmove-up)       ; move to upper window
(global-set-key [M-down] 'windmove-down)   ; move to lower window
(global-set-key [(control c) (c)] 'recompile)
(global-set-key [(control c) (e)] 'next-error)
(global-set-key [(control tab)] 'other-window) ; Ctrl-Tab = Next buffer
(global-set-key [C-S-iso-lefttab]
 '(lambda () (interactive) (other-window -1))) ; Ctrl-Shift-Tab = Previous buffer
(global-set-key [(control delete)] 'kill-word) ; kill word forward
(global-set-key [(meta ~)] 'ruby-command)      ; run ruby command


;;; COLORS
(defun configure-frame (&optional frame)
  "Configure colors for FRAME (defaults to current frame)."
  (with-selected-frame (or frame (selected-frame))
    (set-background-color "black")
    (set-foreground-color "white")
    (set-cursor-color "Orangered")))

;; Apply to existing frames and all future frames
(configure-frame)
(add-hook 'after-make-frame-functions 'configure-frame)

(put 'erase-buffer 'disabled nil)

;; Packages are managed by Nix via programs.emacs.extraPackages in emacs.nix

(add-to-list 'auto-mode-alist '("\\.sls\\'" . yaml-mode))
(put 'downcase-region 'disabled nil)
(put 'upcase-region 'disabled nil)


(defun delete-non-displayable ()
  "Delete characters not contained in the used fonts and therefore non-displayable."
  (interactive)
  (require 'descr-text) ;; for `describe-char-display'
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward "[^[:ascii:]]" nil 1)
      (unless (describe-char-display (1- (point)) (char-before))
        (replace-match "")))))
