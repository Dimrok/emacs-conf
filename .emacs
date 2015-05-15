;;
;; emacs configuration
;;
;; Made by mefyl <mefyl@lrde.epita.fr>
;;
;; Based on Nicolas Despres <despre_n@lrde.epita.fr> configuration
;; Thanks go to Micha <micha@lrde.epita.fr> for his help
;;

(defun may-load (path)
  "Load a file iff it exists."
  (when (file-readable-p path)
    (load-file path)))

;; Load local distribution configuration file
(may-load "~/.emacs.site")

(defconst conf-dir (concat (getenv "HOME") "/.emacs.conf/")
  "Location of the configuration files")
(add-to-list 'load-path conf-dir)
(add-to-list 'load-path "~/.emacs.d/")

(set 'generated-autoload-file (concat conf-dir "my-autoload.el"))
(require 'my-autoload)
(require 'my-elisp)
(require 'my-font)
(add-to-list 'load-path "~/emacs.d/site-lisp/magit")
(require 'magit)
(require 'my-lisp-mode)

;; Modes setup
(add-hook 'sh-mode-hook 'sh-mode-setup)
(add-hook 'c++-mode-hook 'c++-mode-setup)
(add-hook 'python-mode-hook 'python-mode-setup)

(defconst has-gnuserv
  (fboundp 'gnuserv-start)
  "Whether gnuserv is available")

;; Version detection

(defconst xemacs (string-match "XEmacs" emacs-version)
  "non-nil iff XEmacs, nil otherwise")

(defconst emacs-major (string-to-int (replace-regexp-in-string "\\..*" "" emacs-version))
  "Emacs major version")

;; CUSTOM FUNCTIONS

;; Reload conf

(defun reload ()
  (interactive)
  (load-file "~/.emacs"))

;; Compilation

(defvar cpu-number 1
  "Number of parallel processing units on this system")

(setq compile-command "")

(defun build ()
  (interactive)
	(if (string-equal compile-command "")
		(let ((path (cwd)))
			(while (not (or (file-readable-p (concat path "/Makefile")) (string-equal path "")))
				(message path)
				(setq path (replace-regexp-in-string "/[^/]*\\'" "" path)))
			(message path)
			(if (string-equal path "")
				(message "No Makefile found.")
				(progn
					(setq path (replace-regexp-in-string " " "\\\\ " path))
					(compile (concat "make -C " path)))))
		(recompile)))

;; Edition

(defun c-switch-hh-cc ()
  (interactive)
  (let ((other
         (let ((file (buffer-file-name)))
           (if (string-match "\\.hh$" file)
               (replace-regexp-in-string "\\.hh$" ".cc" file)
             (replace-regexp-in-string "\\.cc$" ".hh" file)))))
    (find-file other)))

(defun count-word (start end)
  (let ((begin (min start end))(end (max start end)))
    (save-excursion
      (goto-char begin)
      (re-search-forward "\\W*") ; skip blank
      (setq i 0)
      (while (< (point) end)
        (re-search-forward "\\w+")
        (when (<= (point) end)
          (setq i (+ 1 i)))
        (re-search-forward "\\W*"))))
  i)

(defun stat-region (start end)
  (interactive "r")
  (let
      ((words (count-word start end)) (lines (count-lines start end)))
    (message
     (concat "Lines: "
             (int-to-string lines)
             "  Words: "
             (int-to-string words)))
    )
  )

(defun ruby-command (cmd &optional output-buffer error-buffer)
  "Like shell-command, but using ruby."
  (interactive (list (read-from-minibuffer "Ruby command: "
					   nil nil nil 'ruby-command-history)
		     current-prefix-arg
		     shell-command-default-error-buffer))
  (shell-command (concat "ruby -e '" cmd "'") output-buffer error-buffer))

(defun python-command (cmd &optional output-buffer error-buffer)
  "Like shell-command, but using python."
  (interactive (list (read-from-minibuffer "Python command: "
					   nil nil nil 'python-command-history)
		     current-prefix-arg
		     shell-command-default-error-buffer))
  (shell-command
   (concat "python -c '" (replace-regexp-in-string "'" "'\\\\''" cmd) "'")
   output-buffer error-buffer))

;; C/C++

;; Comment boxing

(defun insert-header-guard ()
  (interactive)
  (save-excursion
    (when (buffer-file-name)
        (let*
            ((name (file-name-nondirectory buffer-file-name))
             (macro (replace-regexp-in-string
                     "\\." "_"
                     (replace-regexp-in-string
                      "-" "_"
                      (upcase name)))))
          (goto-char (point-min))
         (insert "#ifndef " macro "\n")
          (insert "# define " macro "\n\n")
          (goto-char (point-max))
          (insert "\n#endif\n")))))

(defun sandbox ()
  "Opens a C++ sandbox in current window."
  (interactive)
  (cd "/tmp")
  (let ((file (make-temp-file "/home/dimrok/.c++/" nil ".cc")))
    (find-file file)
    (insert "#include <iostream>\n#include <string>\n\nint main()\n{\n\n}\n")
    (line-move -2)
    (save-buffer)
    (compile (concat "g++ -std=c++11 -Wall -O2 " file " -o a.out && ./a.out"))))

(defun c-insert-debug (&optional msg)
  (interactive)
  (when (not (looking-at "\\W*$"))
    (beginning-of-line)
    (insert "\n")
    (line-move -1))
  (c-indent-line)
  (insert "std::cerr << \"\" << std::endl;")
  (backward-char 15))

(defun c-insert-block (&optional r b a)
  (interactive "P")
  (unless b (setq b ""))
  (unless a (setq a ""))
  (if r
      (progn
        (save-excursion
          (goto-char (rbegin))
          (beginning-of-line)
          (insert "\n")
          (line-move -1)
          (insert b "{")
          (c-indent-line))
        (save-excursion
          (goto-char (- (rend) 1))
          (end-of-line)
          (insert "\n}" a)
          (c-indent-line)
          (line-move -1)
          (end-of-line))
        (indent-region (rbegin) (rend)))
    (progn
        (beginning-of-line)

        (setq begin (point))

        (insert b "{\n")
        (end-of-line)
        (insert "\n}" a)

        (indent-region begin (point))

        (line-move -1)
        (end-of-line))))

(defun c-insert-braces (&optional r)
  (interactive "P")
  (c-insert-block r))

(defun c-insert-ns (name r)
  (interactive "sName: \nP")
  (c-insert-block r (concat "namespace " name "\n")))

(defun c-insert-switch (value r)
  (interactive "sValue: \nP")
  (c-insert-block r (concat "switch (" value ")\n")))

(defun c-insert-if (c r)
  (interactive "sCondition: \nP")
  (c-insert-block r (concat "if (" c ")\n")))

(defun c-insert-class (name)
  (interactive "sName: ")
  (c-insert-block () (concat "class " name "\n") ";")
  (insert "public:")
  (c-indent-line)
  (insert "\n")
  (c-indent-line))


;; OPTIONS

(setq inhibit-startup-message t)        ; don't show the GNU splash screen
(setq frame-title-format "%b")          ; titlebar shows buffer's name
(global-font-lock-mode t)               ; syntax highlighting
(setq font-lock-maximum-decoration t)   ; max decoration for all modes
;(setq transient-mark-mode 't)          ; highlight selection
(setq line-number-mode 't)              ; line number
(setq column-number-mode 't)            ; column number
(when (display-graphic-p)
  (progn
    (scroll-bar-mode -1)                ; no scroll bar
    (menu-bar-mode -1)                  ; no menu bar
    (tool-bar-mode -1)                  ; no tool bar
    (mouse-wheel-mode t)))              ; enable mouse wheel


(setq delete-auto-save-files t)         ; delete unnecessary autosave files
(setq delete-old-versions t)            ; delete oldversion file
(setq normal-erase-is-backspace-mode t) ; make delete work as it should
(fset 'yes-or-no-p 'y-or-n-p)           ; 'y or n' instead of 'yes or no'
(setq default-major-mode 'text-mode)    ; change default major mode to text
(setq ring-bell-function 'ignore)       ; turn the alarm totally off
(setq make-backup-files nil)            ; no backupfile

;; FIXME: wanted 99.9% of the time, but can cause your death 0.1% of
;; the time =). Todo: save buffer before reverting
;(global-auto-revert-mode t)            ; auto revert modified files

;(pc-selection-mode)                    ; selection with shift
(auto-image-file-mode)                  ; to see picture in emacs
;(dynamic-completion-mode)              ; dynamic completion
(show-paren-mode t)			; match parenthesis
(setq-default indent-tabs-mode nil)	; don't use fucking tabs to indent

;; HOOKS

; Delete trailing whitespaces on save
(add-hook 'write-file-hooks 'delete-trailing-whitespace)
; Auto insert C/C++ header guard
(add-hook 'find-file-hooks
	  (lambda ()
	    (when (and (memq major-mode '(c-mode c++-mode)) (equal (point-min) (point-max)) (string-match ".*\\.hh?" (buffer-file-name)))
	      (insert-header-guard)
	      (goto-line 3)
	      (insert "\n"))))

(add-hook 'ruby-mode-hook
	  (lambda ()
            (insert-shebang-if-empty "/usr/bin/ruby")))


; Start code folding mode in C/C++ mode
(add-hook 'c-mode-common-hook (lambda () (hs-minor-mode 1)))

;; file extensions
(add-to-list 'auto-mode-alist '("\\.l$" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.y$" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.ll$" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.yy$" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.xcc$" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.cc.tmpl$" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.hh.tmpl$" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.xhh$" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.pro$" . sh-mode)) ; Qt .pro files
(add-to-list 'auto-mode-alist '("configure$" . sh-mode))
(add-to-list 'auto-mode-alist '("drakefile$" . python-mode))
(add-to-list 'auto-mode-alist '("COMMIT_EDITMSG" . change-log-mode))

;; Ido

(defconst has-ido (>= emacs-major 22))

(when has-ido
  (ido-mode t)

;; tab means tab, i.e. complete. Not "open this file", stupid.
  (setq ido-confirm-unique-completion t)
;; If the file doesn't exist, do not try to invent one from a
;; transplanar directory. I just want a new file.
  (setq ido-auto-merge-work-directories-length -1)

;; Don't switch to GDB-mode buffers
  (add-to-list 'ido-ignore-buffers "locals"))

;; GNUSERV

(when has-gnuserv
  (gnuserv-start)
;  (global-set-key [(control x) (control c)] 'gnuserv-close-session)
  )

;; BINDINGS

;; BINDINGS :: windows

(global-unset-key [(control s)])
(global-set-key [(control s) (v)] 'split-window-horizontally)
(global-set-key [(control s) (h)] 'split-window-vertically)
(global-set-key [(control s) (d)] 'delete-window)
(global-set-key [(control s) (o)] 'delete-other-windows)

;; BINDINGS :: ido

(when has-ido
  (global-set-key [(control b)] 'ido-switch-buffer)
  (define-key ido-file-completion-map [(control d)] 'ido-make-directory))

;; BINDINGS :: isearch
(global-set-key [(control f)] 'isearch-forward-regexp)  ; search regexp
(global-set-key [(control r)] 'query-replace-regexp)    ; replace regexp
(define-key
  isearch-mode-map
  [(control n)]
  'isearch-repeat-forward)                              ; next occurence
(define-key
  isearch-mode-map
  [(control p)]
  'isearch-repeat-backward)                             ; previous occurence
(define-key
  isearch-mode-map
  [(control z)]
  'isearch-cancel)                                      ; quit and go back to start point
(define-key
  isearch-mode-map
  [(control f)]
  'isearch-exit)                                        ; abort
(define-key
  isearch-mode-map
  [(control r)]
  'isearch-query-replace)                               ; switch to replace mode
(define-key
  isearch-mode-map
  [S-insert]
  'isearch-yank-kill)                                   ; paste
(define-key
  isearch-mode-map
  [(control e)]
  'isearch-toggle-regexp)                               ; toggle regexp
(define-key
  isearch-mode-map
  [(control l)]
  'isearch-yank-line)                                   ; yank line from buffer
(define-key
  isearch-mode-map
  [(control w)]
  'isearch-yank-word)                                   ; yank word from buffer
(define-key
  isearch-mode-map
  [(control c)]
  'isearch-yank-char)                                   ; yank char from buffer

;; BINDINGS :: Lisp

(define-key
  lisp-mode-map
  [(control c) (control f)]
  'insert-fixme)                                      ; insert fixme

;; BINDINGS :: Ruby

;(define-key
;  ruby-mode-map
;  [(control c) (control f)]
;  'insert-fixme)                                      ; insert fixme

;; BINDINGS :: C/C++

(require 'cc-mode)

(define-key
  c-mode-base-map
  [(control c) (w)]
  'c-switch-hh-cc)                                      ; switch between .hh and .cc
(define-key
  c-mode-base-map
  [(control c) (f)]
  'hs-hide-block)                                       ; fold code
(define-key
  c-mode-base-map
  [(control c) (s)]
  'hs-show-block)                                       ; unfold code
(define-key
  c-mode-base-map
  [(control c) (control n)]
  'c-insert-ns)                                         ; insert namespace
(define-key
  c-mode-base-map
  [(control c) (control s)]
  'c-insert-switch)                                     ; insert switch
(define-key
  c-mode-base-map
  [(control c) (control i)]
  'c-insert-if)                                         ; insert if
(define-key
  c-mode-base-map
  [(control c) (control b)]
  'c-insert-braces)                                     ; insert braces
(define-key
  c-mode-base-map
  [(control c) (control f)]
  'insert-fixme)                                      ; insert fixme
(define-key
  c-mode-base-map
  [(control c) (control d)]
  'c-insert-debug)                                      ; insert debug
(define-key
  c-mode-base-map
  [(control c) (control l)]
  'c-insert-class)                                      ; insert class

;; ;; BINDINGS :: C/C++ :: XRefactory

;; (define-key
;;   c-mode-base-map
;;   [(control c) (d)]
;;   'xref-push-and-goto-definition)                       ; goto definition
;; (define-key
;;   c-mode-base-map
;;   [(control c) (b)]
;;   'xref-pop-and-return)                                 ; go back
;; (define-key
;;   c-mode-base-map
;;   [C-return]
;;   'xref-completion)                                     ; complete

;; BINDINGS :: misc

(global-set-key [(meta =)]
                'stat-region)
(if (display-graphic-p)
    (global-set-key [(control z)] 'undo)                ; undo only in graphic mode
)
;; (global-set-key [(control a)] 'mark-whole-buffer)       ; select whole buffer
(global-set-key [(control return)] 'dabbrev-expand)     ; auto completion
(global-set-key [C-home] 'beginning-of-buffer)          ; go to the beginning of buffer
(global-set-key [C-end] 'end-of-buffer)                 ; go to the end of buffer
(global-set-key [(meta g)] 'goto-line)                  ; goto line #
(global-set-key [M-left] 'windmove-left)                ; move to left windnow
(global-set-key [M-right] 'windmove-right)              ; move to right window
(global-set-key [M-up] 'windmove-up)                    ; move to upper window
(global-set-key [M-down] 'windmove-down)
(global-set-key [(control c) (c)] 'build)
(global-set-key [(control c) (e)] 'next-error)
(global-set-key [(control tab)] 'other-window)          ; Ctrl-Tab = Next buffer
(global-set-key [C-S-iso-lefttab]
                '(lambda () (interactive)
                   (other-window -1)))                  ; Ctrl-Shift-Tab = Previous buffer
(global-set-key [(control delete)]
                'kill-word)                             ; kill word forward
(global-set-key [(meta ~)] 'python-command)             ; run python command

;; COLORS

(defun configure-frame ()
  (set-background-color "black")
  (set-foreground-color "white")
  (set-cursor-color "Orangered")
  (custom-set-faces
   ;; custom-set-faces was added by Custom.
   ;; If you edit it by hand, you could mess it up, so be careful.
   ;; Your init file should contain only one such instance.
   ;; If there is more than one, they won't work right.
   )
  (set-font-size))
(configure-frame)
(add-to-list 'after-make-frame-functions
             (lambda (f) (select-frame f) (configure-frame)))

;; Qt

(font-lock-add-keywords 'c++-mode
			'(("foreach\\|forever\\|emit" . 'font-lock-keyword-face)))

;; Lisp mode

(require 'lisp-mode)

(define-key
  lisp-mode-shared-map
  [(control c) (control c)]
  'comment-region)                                      ; comment

;; Conf mode

(require 'conf-mode)

(define-key
  conf-mode-map
  [(control c) (control c)]
  'comment-region)                                      ; comment

;; C / C++ mode

(require 'cc-mode)
(add-to-list 'c-style-alist
             '("epita"
               (c-basic-offset . 2)
               (c-comment-only-line-offset . 0)
               (c-hanging-braces-alist     . ((substatement-open before after)))
               (c-offsets-alist . ((topmost-intro        . 0)
                                   (substatement         . +)
                                   (substatement-open    . 0)
                                   (case-label           . +)
                                   (access-label         . -)
                                   (inclass              . +)
                                   (inline-open          . 0)))))

(setq c-default-style "epita")

;; Compilation

(setq compilation-window-height 14)
(setq compilation-scroll-output t)

;; make C-Q RET insert a \n, not a ^M

(defadvice insert-and-inherit (before ENCULAY activate)
  (when (eq (car args) ?)
    (setcar args ?\n)))



;; Sessions

;; (desktop-load-default)
;; (desktop-read)

;; mmm mode

;; (add-to-list 'load-path "/usr/share/emacs/site-lisp/mmm-mode/")
;; (require 'mmm-mode)
;; (setq mmm-global-mode 'maybe)

;; (defun foo ()
;;   (when (looking-back "^[ \t]*")
;;     (beginning-of-line)))

;; (mmm-add-classes
;;  '((cc-html
;;     :submode html-mode
;;     :face mmm-code-submode-face
;;     :front "\\('@\\|'@xml\\)\n?"
;;     :back "@'"
;;     :back-offset (foo))))


;; (mmm-add-classes
;;  '((ml-ext
;;     :submode text-mode
;;     :face mmm-code-submode-face
;;     :front "<:\\w*<"
;;     :back ">>"
;;     :back-offset (foo))))


;; (mmm-add-mode-ext-class 'c++-mode () 'cc-html)
;; (mmm-add-mode-ext-class 'tuareg-mode () 'ml-ext)

;; (setq mmm-submode-decoration-level 1)

;; (set-face-background 'mmm-default-submode-face "gray16")



(when has-ido
  (custom-set-variables
   '(ido-auto-merge-work-directories-length -1)
   '(ido-confirm-unique-completion t)
   '(ido-create-new-buffer (quote always))
   '(ido-everywhere t)
   '(ido-ignore-buffers (quote ("\\`\\*breakpoints of.*\\*\\'" "\\`\\*stack frames of.*\\*\\'" "\\`\\*gud\\*\\'" "\\`\\*locals of.*\\*\\'" "\\` ")))
   '(ido-mode (quote both) nil (ido))))

(custom-set-variables
  ;; custom-set-variables was added by Custom.
  ;; If you edit it by hand, you could mess it up, so be careful.
  ;; Your init file should contain only one such instance.
  ;; If there is more than one, they won't work right.
 '(after-save-hook (quote (executable-make-buffer-file-executable-if-script-p)))
 '(gdb-max-frames 1024)
 '(ido-auto-merge-work-directories-length -1)
 '(ido-confirm-unique-completion t)
 '(ido-create-new-buffer (quote always))
 '(ido-everywhere t)
 '(ido-ignore-buffers (quote ("\\`\\*breakpoints of.*\\*\\'" "\\`\\*stack frames of.*\\*\\'" "\\`\\*gud\\*\\'" "\\`\\*locals of.*\\*\\'" "\\` ")))
 '(ido-mode (quote both) nil (ido))
 '(js-indent-level 2)
 '(line-move-visual nil)
 '(python-indent 2)
 '(require-final-newline t))

(require 'uniquify)
(setq uniquify-buffer-name-style 'post-forward-angle-brackets)

(setq-default ispell-program-name "aspell")

(setq-default gdb-many-windows t)

;; Recognize test suite output

(require 'compile)
(add-to-list 'compilation-error-regexp-alist '("^\\(PASS\\|SKIP\\|XFAIL\\|TFAIL\\): \\(.*\\)$" 2 () () 0 2))
(add-to-list 'compilation-error-regexp-alist '("^\\(FAIL\\|XPASS\\): \\(.*\\)$" 2 () () 2 2))

;(require 'flymake)
;(add-hook 'find-file-hooks 'flymake-find-file-hook)

;; ;; Xrefactory configuration part ;;
;; ;; some Xrefactory defaults can be set here
;; (defvar xref-current-project nil) ;; can be also "my_project_name"
;; (defvar xref-key-binding 'global) ;; can be also 'local or 'none
;; (setq load-path (cons "/tmp/xref/emacs" load-path))
;; (setq exec-path (cons "/tmp/xref" exec-path))
;; (load "xrefactory")
;; ;; end of Xrefactory configuration part ;;
;; (message "xrefactory loaded")


;; Save and restore window layout

(defvar winconf-ring ())

(defun push-winconf ()
  (interactive)
  (window-configuration-to-register ?%)
  (push (get-register ?%) winconf-ring))

(defun pop-winconf ()
  (interactive)
  (set-register ?% (pop winconf-ring))
  (jump-to-register ?%))

(defun restore-winconf ()
  (interactive)
  (set-register ?% (car winconf-ring))
  (jump-to-register ?%))

(may-load "~/.emacs.local")

(prefer-coding-system 'utf-8)

;; Framemove
(require 'framemove)
(windmove-default-keybindings)
(setq framemove-hook-into-windmove t)

(require 'auto-complete-clang-async)

(defun ac-cc-mode-setup ()
  (setq ac-clang-complete-executable "~/.emacs.d/clang-complete")
  (setq ac-sources '(ac-source-clang-async))
  (ac-clang-launch-completion-process)
)
(defun ac-common-setup ()
  ())
(defun my-ac-config ()
  (add-hook 'c-mode-common-hook 'ac-cc-mode-setup)
  ; (add-hook 'auto-complete-mode-hook 'ac-common-setup)
  ; (global-auto-complete-mode t)
)

(my-ac-config)

; (add-hook 'after-init-hook 'global-company-mode)

(custom-set-faces
  ;; custom-set-faces was added by Custom.
  ;; If you edit it by hand, you could mess it up, so be careful.
  ;; Your init file should contain only one such instance.
  ;; If there is more than one, they won't work right.
 '(magit-diff-add ((((class color) (background dark)) (:foreground "green"))))
 '(magit-diff-file-header ((t (:inherit magit-header :weight bold :height 1.6))))
 '(magit-diff-hunk-header ((t (:inherit magit-header :weight bold :height 1.3))))
 '(magit-diff-none ((t (:foreground "grey80"))))
 '(magit-header ((t nil)))
 '(magit-section-title ((t (:inherit magit-header :underline t :weight bold :height 2.0)))))

;; (add-to-list 'load-path "~/.emacs.d/elpa/company-0.8.7")
;; (autoload 'company-mode "company" nil t)
