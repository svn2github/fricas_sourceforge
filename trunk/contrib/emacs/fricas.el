;; this contains a list of all fricas operations and constructors
(require 'fricas-cpl)

(defvar fricas-beg-marker-regexp "<|start[a-zA-Z]*|>\n")
(defvar fricas-end-marker-regexp "<|endOf[a-zA-Z]*|>\n")
;; we set the marker format string such that it always terminates with >
;; followed by newline
(defvar fricas-max-marker-length 40) ;; maximal length of a marker
(defvar fricas-marker-format-function 
  (concat
   "(lambda (x &optional args)                   "
   "  (cond ((and (eq x '|startKeyedMsg|)        "
   "              (or (eq (car args) 'S2GL0012)  "
   "                  (eq (car args) 'S2GL0013)  "
   "                  (eq (car args) 'S2GL0014)))"
   "         (format t \"<|startTypeTime|>~%\")) "
   "        ((and (eq x '|endOfKeyedMsg|)        "
   "              (or (eq (car args) 'S2GL0012)  "
   "                  (eq (car args) 'S2GL0013)  "
   "                  (eq (car args) 'S2GL0014)))"
   "         (format t \"<|endOfTypeTime|>~%\")) "
   "        (t (format t \"<~S>~%\" x))))        "))

(defvar fricas-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?$  ".   " st)
    (modify-syntax-entry ?%  ".   " st)
    (modify-syntax-entry ?!  "w   " st)
    (modify-syntax-entry ??  "w   " st)
    (modify-syntax-entry ?\\ "w   " st)
    (modify-syntax-entry ?_  "\   " st)
    st)
  "Syntax table used while in `fricas-mode'.")

(defvar fricas-input-ring nil)
(defvar fricas-input-ring-index nil
  "Index of last matched history element.")
(defvar fricas-input-ring-size 150
  "Size of input history ring.")
(defvar fricas-stored-incomplete-input nil
  "Stored input for history cycling.")

(defface fricas-algebra '((t (:background "#ffffa0")))
  "Face used for algebra output."
  :group 'fricas)

(defface fricas-typeTime '((t (:background "#ffffa0" :foreground "darkgreen")))
  "Face used for type and time output."
  :group 'fricas)

(defface fricas-message  '((t (:background "#ffffa0" :foreground "palevioletred")))
  "Face used for type and time output."
  :group 'fricas)

(defface fricas-undefined '((t (:background "#ffffa0" :foreground "blue")))
  "Face used for other output."
  :group 'fricas)

(defface fricas-prompt nil
  "Face used for the prompt."
  :group 'fricas)

(defvar fricas-mode-map 
  (let ((map (make-sparse-keymap)))
    (define-key map [(meta k)]         'fricas-copy-to-clipboard)
    (define-key map [(ctrl return)]    'fricas-yank)
    (define-key map "\ep"              'fricas-previous-input)
    (define-key map "\en"              'fricas-next-input)
    (define-key map [C-up]   	       'fricas-previous-input)
    (define-key map [C-down] 	       'fricas-next-input)
    (define-key map [(meta up)]        'fricas-up-input)
    (define-key map (kbd "ESC <up>")   'fricas-up-input)
    (define-key map [(meta down)]      'fricas-down-input)
    (define-key map (kbd "ESC <down>") 'fricas-down-input)

    (define-key map "\er" 	       'fricas-previous-matching-input)
    (define-key map "\es" 	       'fricas-next-matching-input)
    (define-key map [(shift up)]       'fricas-paint-previous-line)
    (define-key map [(shift down)]     'fricas-paint-next-line)
    (define-key map [(shift left)]     'fricas-paint-previous-char)
    (define-key map [(shift right)]    'fricas-paint-next-char)
;;; doesn't work in terminal
;;; (define-key map [return]           'fricas-eval)
    (define-key map "\C-m"             'fricas-eval)
    (define-key map [(shift return)]   'fricas-underscore-newline)
;;; doesn't work in terminal
;;;(define-key fricas-mode-map [(meta return)] 'fricas-eval-append)
    (define-key map "\M-\C-m"          'fricas-eval-append)
    (define-key map "\t"               'fricas-dynamic-complete)
    (define-key map "\C-c\C-c"         'fricas-interrupt)
    map))

(defcustom fricas-input-ignoredups nil
  "*If non-nil, don't add input matching the last on the input ring.
This mirrors the optional behavior of bash.

This variable is buffer-local."
  :type 'boolean
  :group 'fricas)

(define-derived-mode fricas-mode fundamental-mode "FriCAS"
  "Major mode for interacting with the Computer Algebra System FriCAS.
\\[fricas-eval] sends the text in the current input region to FriCAS, and
    displays the output in the following output region.
\\[fricas-eval-append] sends the text in the current input region to FriCAS,
    and displays the output in a new output region at the bottom of the buffer.
\\[fricas-up-input] and \\[fricas-down-input] move point respectively to the previous and 
    the next input region.
\\[fricas-copy-to-clipboard] copies the current input-output combination into the kill-ring.
\\[fricas-yank] writes the front item of the kill ring into a temporary file,
    and then `)read's that file.  With an argument, it reads the file 
    `)quiet'ly.
\\[fricas-paint-next-char], \\[fricas-paint-previous-char], \\[fricas-paint-next-line] and \\[fricas-paint-previous-line] permanently marks point 
    in output region with `fricas-paint-face'.
\\[fricas-change-paint-face] changes the face used thereby.

`)cd' commands given to FriCAS at a prompt are watched by Emacs to, keep this
buffer's default directory the same as the FriCAS's working directory.  FriCAS'
working directory is displayed by \\[list-buffers] or \\[mouse-buffer-menu] in
the `File' field.  If the buffer's default directory and FriCAS working
directory ever get out of sync, use \\[fricas-resync-directory].

You can save your FriCAS session as usual in Emacs with \\[save-buffer] or
\\[write-file].  NOT YET IMPLEMENTED: Loading it will restore the entire state
of your session.

If you want to make multiple FriCAS buffers, rename the `*fricas*' buffer
using \\[rename-buffer] or \\[rename-uniquely] and start a new FriCAS process.

\\{fricas-mode-map}
"
  (make-local-variable 'fricas-process)
  (setq fricas-process (get-buffer-process (current-buffer)))

  (make-local-variable 'fricas-input-ring-size)
  (make-local-variable 'fricas-input-ring)
  (or (and (boundp 'fricas-input-ring) fricas-input-ring)
      (setq fricas-input-ring (make-ring fricas-input-ring-size)))
  (make-local-variable 'fricas-input-ring-index)
  (or (and (boundp 'fricas-input-ring-index) fricas-input-ring-index)
      (setq fricas-input-ring-index nil))

  (set-syntax-table fricas-mode-syntax-table)
  (use-local-map fricas-mode-map)
  (make-local-variable 'fricas-output-buffer)
  (setq fricas-output-buffer "")     ;; contains output yet to be processed
  (make-local-variable 'fricas-last-type)
  (setq fricas-last-type 'fricas-undefined) ;; the type (and face) of the current output
  (make-local-variable 'fricas-state)
  (setq fricas-state 'working)       ;; 'working or 'waiting
  (make-local-variable 'fricas-resync-directory)
  (setq fricas-resync-directory? nil);; are we resyncing the directory?
  (make-local-variable 'fricas-repair-prompt)
  (setq fricas-repair-prompt nil)    ;; did we overwrite old output?
  (make-local-variable 'fricas-query-user)
  (setq fricas-query-user nil)       ;; are we expecting a response to a query?
  (make-local-variable 'fricas-cd)
  (setq fricas-cd nil)               ;; are we changing the directory?
  (make-local-variable 'fricas-yank-file?)
  (setq fricas-yank-file? nil)       ;; did we yank a file?
  (make-local-variable 'fricas-save-history?)
  (setq fricas-save-history? nil)    ;; did we just save the history

  ;; taken from shell.el:
  ;; This is not really correct, since the shell buffer does not really
  ;; edit this directory.  But it is useful in the buffer list and menus.
  (make-local-variable 'list-buffers-directory)
  (setq list-buffers-directory (expand-file-name default-directory))

  (setq font-lock-defaults nil)
  (set-process-filter fricas-process (function fricas-filter))
  (setq buffer-offer-save t)
  (add-hook 'after-save-hook 'fricas-save-history nil t)

  ;;  (let ((inhibit-read-only t))
  (process-send-string fricas-process ")se me au off\n")
  (process-send-string fricas-process 
		       (concat ")lisp (setf |$ioHook| " 
			       fricas-marker-format-function 
			       ")\n"))
  (switch-to-buffer "*fricas*"))

(defun fricas-run ()
  "Run Fricas in a buffer."
  (set-buffer (get-buffer-create "*fricas*"))
  (start-process-shell-command "fricas" "*fricas*" "fricas" "-noclef" "2>>fricas.errors"))

(defun fricas-check-proc (buffer)
  "Return non-nil if there is a living process associated w/buffer BUFFER.
Living means the status is `open', `run', or `stop'.
BUFFER can be either a buffer or the name of one."
  (let ((proc (get-buffer-process buffer)))
    (and proc (memq (process-status proc) '(open run stop)))))

(defun fricas ()
  "Run an inferior FriCAS process, in a BUFFER `*fricas*'.  If BUFFER exists
but FriCAS process is not running, make new FriCAS.  If BUFFER exists and
FriCAS process is running, just switch to BUFFER.  The buffer is put in FriCAS
mode, giving commands for sending input and controlling the subjobs of the
shell.  See `fricas-mode'."
  (interactive)
  (if (fricas-check-proc "*fricas*")
      (pop-to-buffer "*fricas*")
    (fricas-run)
    (fricas-mode)))

(defun fricas-interrupt ()
  (interactive)
  (process-send-string fricas-process "\003"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; some helpers returning region types and positions of nearby regions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun fricas-prompt? (pos)
  "Returns t if pos is in a prompt region."
  (eq (get-text-property pos 'type) 'fricas-prompt))

(defun fricas-input? (pos)
  "Returns t if pos is in an input region."
  (not (get-text-property pos 'type)))

(defun fricas-paintable? (pos)
  "Returns t if pos is in a region where we allow painting."
  (not (or (fricas-prompt? pos)
	   (fricas-input? pos))))

(defun fricas-next-prompt-pos (pos)
  "Returns the beginning position of the first prompt after pos, otherwise nil."
  (when (next-single-property-change pos 'type)
    (text-property-any pos (point-max) 'type 'fricas-prompt)))

(defun fricas-previous-prompt-pos (pos)
  "Returns the beginning position of the first prompt before pos, otherwise nil."
  (while (and (setq pos (previous-single-property-change pos 'type))
	      (not (fricas-prompt? pos))))
  pos)

(defun fricas-beginning-of-region-pos (pos)
  "Returns the beginning position of the current region, even if
it consists only of a single character. Should consider no
property as input, but doesn't yet."
  (cond ((= pos (point-min))
	 pos)
	((eq (get-text-property pos 'type)
	     (get-text-property (1- pos) 'type))
	 (or (previous-single-property-change pos 'type)
	     (point-min)))
	(t pos)))

(defun fricas-end-of-region-pos (pos)
  "Returns the end position of the current region."
  (1- (or (next-single-property-change pos 'type)
	  (1+ (point-max)))))

(defun fricas-can-receive-commands? ()
 "Returns true only if fricas is not working and not awaiting an
answer.  Prints a message otherwise."
 (cond ((eq fricas-state 'working)
	(message "Fricas is working")
	nil)
       (fricas-query-user 
	(message "Fricas expects an answer")
	nil)
       (t)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; painting
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defface fricas-paint-lightblue '((t (:background "lightblue")))
  "Lightblue face to use for painting."
  :group 'fricas)

(defface fricas-paint-red '((t (:background "red")))
  "Red face to use for painting."
  :group 'fricas)

(defface fricas-paint-custom '((t nil))
  "Custom face to use for painting."
  :group 'fricas)

(defvar fricas-paint-face-alist
  '(("lightblue" fricas-paint-lightblue)
    ("red"  fricas-paint-red)
    ("custom"  fricas-paint-custom)
    ("output"  fricas-output)))

(defvar fricas-paint-face 'fricas-paint-lightblue)

(defun fricas-change-paint-face ()
  (interactive)
  (let ((newpaint (completing-read "New paint face: "
                                   fricas-paint-face-alist
                                   nil t)))
    (setq fricas-paint-face (cadr (assoc newpaint fricas-paint-face-alist)))))

(defun fricas-make-space-if-necessary-and-paint ()
  "Make sure that a line does not end with a painted character."
;;; This would have the unwanted effect, that spaces appended by either
;;; fricas-paint-previous-line or fricas-paint-next-line inherit the face of the
;;; last character.
  (when (eolp)
    (insert-char 32 2 t)
    (backward-char 2))
  (forward-char 1)
  (when (eolp)
    (insert-char 32 1 t)
    (backward-char 1))
  (backward-char 1)
  (let ((pos (point)))
    (if (equal (get-text-property pos 'face)
	       fricas-paint-face)
	(put-text-property pos (1+ pos) 
			   'face (get-text-property pos 'type))
      (put-text-property pos (1+ pos) 'face fricas-paint-face))))

(defun fricas-paint-previous-line ()
  (interactive)
  (when (fricas-paintable? (point))
    (let ((inhibit-read-only t)
          (old-column (current-column))
          (old-pos    (point)))
      (fricas-make-space-if-necessary-and-paint)
      (previous-line 1)
      (if (fricas-paintable? (point))
          (let ((difference (- old-column (current-column))))
            (when (> difference 0)
              (insert-char 32 difference t)))
        (goto-char old-pos)))))

(defun fricas-paint-next-line ()
  (interactive)
  (when (fricas-paintable? (point))
    (let ((inhibit-read-only t)
          (old-column (current-column))
          (old-pos    (point)))
      (fricas-make-space-if-necessary-and-paint)
      (next-line 1)
      (if (fricas-paintable? (point))
          (let ((difference (- old-column (current-column))))
            (when (> difference 0)
              (insert-char 32 difference t)))
        (goto-char old-pos)))))

(defun fricas-paint-previous-char ()
  (interactive)
  (when (fricas-paintable? (point))
    (let ((inhibit-read-only t))
      (fricas-make-space-if-necessary-and-paint)
      (when (fricas-paintable? (1- (point)))
        (backward-char 1)))))

(defun fricas-paint-next-char ()
  (interactive)
  (when (fricas-paintable? (point))
    (let ((inhibit-read-only t))
      (fricas-make-space-if-necessary-and-paint)
      (forward-char 1))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; resync directory
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun fricas-resync-directory ()
  "Go to the process mark, send )sys pwd to the fricas process and
 cd to the result."
;;; most of the work is actually done by fricas-resync-directory-post
  (interactive)
  (when (fricas-can-receive-commands?)
    (setq fricas-resync-directory?
	  (marker-position (process-mark fricas-process)))
    (process-send-string fricas-process ")sys pwd\n")))

(defun fricas-resync-directory-post ()
  "parse output from )sys pwd and clean up."
  (let* ((inhibit-read-only t)
	 (begin fricas-resync-directory?)
	 (end (marker-position (process-mark fricas-process)))
	 (dir (buffer-substring-no-properties 
	       begin 
	       (1- (previous-single-property-change end 'type)))))
    (cd dir)
    (setq list-buffers-directory (file-name-as-directory
				  (expand-file-name dir)))
    (setq fricas-resync-directory? nil)
    (delete-region begin end)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; tab completion
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; taken from lisp.el and comint.el

(defun fricas-dynamic-complete ()
  "Dynamically perform completion at point, if in input."
  (interactive)
  (when (fricas-input? (point))
    (let ((beg-of-input (fricas-beginning-of-region-pos (point))))
      (if (and (fricas-prompt? (1- beg-of-input))
	       (save-excursion
		 (goto-char beg-of-input)
		 (looking-at " *)")))
	  (fricas-dynamic-complete-filename)
	(fricas-complete-symbol)))))

(defun fricas-complete-symbol ()
  "Perform completion on Lisp symbol preceding point.
Compare that symbol against the known Lisp symbols.
If no characters can be completed, display a list of possible completions.
Repeating the command at that point scrolls the list."
  (interactive)
  (let ((window (get-buffer-window "*Completions*" 0)))
    (if (and (eq last-command this-command)
	     window (window-live-p window) (window-buffer window)
	     (buffer-name (window-buffer window)))
	;; If this command was repeated, and
	;; there's a fresh completion window with a live buffer,
	;; and this command is repeated, scroll that window.
	(with-current-buffer (window-buffer window)
	  (if (pos-visible-in-window-p (point-max) window)
	      (set-window-start window (point-min))
	    (save-selected-window
	      (select-window window)
	      (scroll-up))))

      ;; Do completion.
      (let* ((end (point))
	     (beg (with-syntax-table fricas-mode-syntax-table
		    (save-excursion
		      (backward-sexp 1)
		      (while (= (char-syntax (following-char)) ?\')
			(forward-char 1))
		      (point))))
	     (pattern (buffer-substring-no-properties beg end))
	     (completion (try-completion pattern fricas-symbol-list)))
	(cond ((eq completion t))
	      ((null completion)
	       (message "Can't find completion for \"%s\"" pattern)
	       (ding))
	      ((not (string= pattern completion))
	       (delete-region beg end)
	       (insert completion)
	       ;; Don't leave around a completions buffer that's out of date.
	       (when (> emacs-major-version 21)
		 (let ((win (get-buffer-window "*Completions*" 0)))
		   (if win (with-selected-window win (bury-buffer))))))
	      (t
	       (let ((minibuf-is-in-use
		      (eq (minibuffer-window) (selected-window))))
		 (unless minibuf-is-in-use
		   (message "Making completion list..."))
		 (let ((list (all-completions pattern fricas-symbol-list)))
		   (setq list (sort list 'string<))
		   (if (> (length list) 1)
		       (with-output-to-temp-buffer "*Completions*"
			 (if (> emacs-major-version 21)
			     (display-completion-list list pattern)
			   (display-completion-list list)))
		     ;; Don't leave around a completions buffer that's
		     ;; out of date.
		     (let ((win (get-buffer-window "*Completions*" 0)))
		       (if win (with-selected-window win (bury-buffer))))))
		 (unless minibuf-is-in-use
		   (message "Making completion list...%s" "done")))))))))

(defun fricas-file-name-all-completions (pathnondir directory)
  "Returns all filenames relevant to fricas"
  (save-match-data
    (remove-if-not 
     (function (lambda (f) 
                 (or (and (string-match "\\.[^.]*\\'" f)
                          (member (match-string 0 f)
                                  (list ".input" ".spad" ".as")))
                     (string= (file-name-directory f) f))))
     (file-name-all-completions pathnondir directory))))

(defun fricas-file-name-completion (file directory)
  "Returns the longest string common to all file names relevant to fricas in
DIRECTORY that start with FILE.  If there is only one and FILE matches it
exactly, returns t.  Returns nil if DIR contains no name starting with FILE."
  (let* ((completions (fricas-file-name-all-completions file directory))
	 (frst (first completions))
	 (len  (length frst))
	 (start      0)
	 (not-done   t))
    (cond ((consp (rest completions))
	   (while (and not-done
		       (> len start))
	     (let ((char (substring frst start (1+ start)))
		   (rst  (rest completions)))
	       (while (and not-done 
			   (consp rst))
		 (if (and (> (length (first rst)) start)
			  (string= (substring (first rst) 
					      start (1+ start))
				   char))
		     (setq rst (rest rst))
		   (setq not-done nil))))
	     (when not-done 
	       (setq start (1+ start))))
	   (substring frst 0 start))
	  ((string= frst file)
	   t)
	  (t
	   frst))))

(defun fricas-dynamic-list-filename-completions ()
  "List in help buffer possible completions of the filename at point."
  (interactive)
  (let* ((completion-ignore-case (memq system-type '(ms-dos windows-nt)))
	 ;; If we bind this, it breaks remote directory tracking in rlogin.el.
	 ;; I think it was originally bound to solve file completion problems,
	 ;; but subsequent changes may have made this unnecessary.  sm.
	 ;;(file-name-handler-alist nil)
	 (filename (or (comint-match-partial-filename) ""))
	 (pathdir (file-name-directory filename))
	 (pathnondir (file-name-nondirectory filename))
	 (directory (if pathdir (comint-directory pathdir) default-directory))
	 (completions (fricas-file-name-all-completions pathnondir directory)))
    (if (not completions)
	(message "No completions of %s" filename)
      (comint-dynamic-list-completions
       (mapcar 'comint-quote-filename completions)))))

(defun fricas-dynamic-complete-filename ()
  "Dynamically complete at point as a filename.
See `comint-dynamic-complete-filename'.  Returns t if successful."
  (interactive)
  (let* ((completion-ignore-case (memq system-type '(ms-dos windows-nt)))
	 (completion-ignored-extensions comint-completion-fignore)
	 ;; If we bind this, it breaks remote directory tracking in rlogin.el.
	 ;; I think it was originally bound to solve file completion problems,
	 ;; but subsequent changes may have made this unnecessary.  sm.
	 ;;(file-name-handler-alist nil)
	 (minibuffer-p (window-minibuffer-p (selected-window)))
	 (success t)
	 (dirsuffix (cond ((not comint-completion-addsuffix)
			   "")
			  ((not (consp comint-completion-addsuffix))
			   (char-to-string directory-sep-char))
			  (t
			   (car comint-completion-addsuffix))))
	 (filesuffix (cond ((not comint-completion-addsuffix)
			    "")
			   ((not (consp comint-completion-addsuffix))
			    " ")
			   (t
			    (cdr comint-completion-addsuffix))))
	 (filename (or (comint-match-partial-filename) ""))
	 (pathdir (file-name-directory filename))
	 (pathnondir (file-name-nondirectory filename))
	 (directory (if pathdir (comint-directory pathdir) default-directory))
	 (completion (fricas-file-name-completion pathnondir directory)))
    (cond ((null completion)
	   (message "No completions of %s" filename)
	   (setq success nil))
	  ((eq completion t)            ; Means already completed "file".
	   (insert filesuffix)
	   (unless minibuffer-p
	     (message "Sole completion")))
	  ((string-equal completion "") ; Means completion on "directory/".
	   (fricas-dynamic-list-filename-completions))
	  (t                            ; Completion string returned.
	   (let ((file (concat (file-name-as-directory directory) completion)))
	     (insert (comint-quote-filename
		      (substring (directory-file-name completion)
				 (length pathnondir))))
	     (cond ((symbolp (fricas-file-name-completion completion directory))
		    ;; We inserted a unique completion.
		    (insert (if (file-directory-p file) dirsuffix filesuffix))
		    (unless minibuffer-p
		      (message "Completed")))
		   ((and comint-completion-recexact comint-completion-addsuffix
			 (string-equal pathnondir completion)
			 (file-exists-p file))
		    ;; It's not unique, but user wants shortest match.
		    (insert (if (file-directory-p file) dirsuffix filesuffix))
		    (unless minibuffer-p
		      (message "Completed shortest")))
		   ((or comint-completion-autolist
			(string-equal pathnondir completion))
		    ;; It's not unique, list possible completions.
		    (fricas-dynamic-list-filename-completions))
		   (t
		    (unless minibuffer-p
		      (message "Partially completed")))))))
    success))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; yanking input
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; from emacs 22
(defun make-temp-file (prefix &optional dir-flag suffix)
  "Create a temporary file.
The returned file name (created by appending some random characters at the end
of PREFIX, and expanding against `temporary-file-directory' if necessary),
is guaranteed to point to a newly created empty file.
You can then use `write-region' to write new data into the file.

If DIR-FLAG is non-nil, create a new empty directory instead of a file.

If SUFFIX is non-nil, add that at the end of the file name."
  (let ((umask (default-file-modes))
        file)
    (unwind-protect
        (progn
          ;; Create temp files with strict access rights.  It's easy to
          ;; loosen them later, whereas it's impossible to close the
          ;; time-window of loose permissions otherwise.
          (set-default-file-modes ?\700)
          (while (condition-case ()
                     (progn
                       (setq file
                             (make-temp-name
                              (expand-file-name prefix temporary-file-directory)))
                       (if suffix
                           (setq file (concat file suffix)))
                       (if dir-flag
                           (make-directory file)
                         (write-region "" nil file nil 'silent nil 'excl))
                       nil)
                   (file-already-exists t))
            ;; the file was somehow created by someone else between
            ;; `make-temp-name' and `write-region', let's try again.
            nil)
          file)
      ;; Reset the umask.
      (set-default-file-modes umask))))

(defun fricas-yank (&optional quiet)
  "Puts the front item of the kill ring into a temporary file and
makes fricas )read it."
  (interactive "P")
  (when (fricas-can-receive-commands?)
    (setq fricas-yank-file? (make-temp-file "fricas" nil ".input"))
    (write-region (car kill-ring-yank-pointer) nil fricas-yank-file?)
    (goto-char (process-mark fricas-process))
    (while (not (file-exists-p fricas-yank-file?))
      (sit-for 0))
    (fricas-send-input (concat ")read " fricas-yank-file?
			       (if quiet " )quiet" ""))
		       t)))

(defun fricas-yank-post ()
  "Deletes the temporary file created by fricas-yank."
  (delete-file fricas-yank-file?))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; moving around
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun fricas-down-input-pos (pos)
  "Returns position just after next prompt after pos, or nil."
  (let ((pos (fricas-next-prompt-pos pos)))
    (when pos (or (next-single-property-change pos 'type)
		  (point-max)))))

(defun fricas-down-input ()
  "Puts point just after the next prompt.  If there is no next prompt, point
stays where it is."
  (interactive)
  (let ((pos (fricas-down-input-pos (point))))
    (when pos (goto-char pos))))

(defun fricas-up-input ()
  "If not in input, or at the first input line, puts point just after the
previous prompt.  If in input, puts point just after the prompt before the
previous prompt.  Otherwise, point stays where it is."
  (interactive)
  (let ((pos (point)))
    (when (fricas-input? pos)
      (setq pos (1- (fricas-beginning-of-region-pos pos)))
      (when (fricas-prompt? pos)
	(setq pos (1- (fricas-previous-prompt-pos pos)))))
    (setq pos (fricas-previous-prompt-pos pos))
    (when pos
      (goto-char (fricas-down-input-pos pos)))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; another input method
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun fricas-eval-append ()
  "Evaluate the current input and append output."
  (interactive)
  (when (fricas-can-receive-commands?)
    (if (not (fricas-input? (point)))
	(message "Not at command line")
      (let ((beg-of-input-pos (fricas-beginning-of-region-pos (point)))
	    (end-of-input-pos (1- (or (next-single-property-change (point) 
								   'type)
				      (1+ (point-max)))))
	    input)
	(setq input (buffer-substring beg-of-input-pos
				      end-of-input-pos))
	(goto-char (process-mark fricas-process))
	(delete-region (point) (point-max))
	(fricas-send-input input)))))

(defun fricas-underscore-newline ()
  "If in input, append an underscore and a newline."
  (interactive)
  (if (not (fricas-input? (point)))
      (message "Not at command line")
    (end-of-line)
    (fricas-insert-ascii "_\n" nil)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; copying
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun fricas-copy-to-clipboard (&optional arg)
   "Copy the arg previous input-output combinations into the kill-ring."
   (interactive "p")
   (when (> arg 0)
     (let ((n arg)
	   (end (or (fricas-next-prompt-pos (point)) (point-max)))
	   (begin (point)))
       (while (and (> n 0)
		   (not (= begin (point-min))))
	 (setq begin (or (fricas-previous-prompt-pos (1- begin))
			 (point-min)))
	 (setq n (1- n)))
       (clipboard-kill-ring-save begin end))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; evaluating input
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun fricas-set-idle ()
  "Emergency function in case emacs thinks that FriCAS is
working, but this is not the case."
  (interactive)
  (setq fricas-state 'waiting))

(defun fricas-prepare-overwrite (beg-of-input-pos end-of-input-pos)
  "Returns the input string"
;;; if there is a prompt further down, we delete old prompt and output, and
;;; write the prompt from the very end of the buffer (which is always the last
;;; one) instead, and the new input instead.  fricas-repair-prompt is checked
;;; also in the output filter, so that the new prompt will be copied to the
;;; bottom of the buffer:

;;; (3) -> input               becomes (10) -> input
;;;
;;; (4) ->                             (4) ->
;;;
;;;
;;; (10) ->                            (11) ->

	    (let ((inhibit-read-only t)
		  input)
;;; is there a prompt further down?
	      (setq fricas-repair-prompt (fricas-next-prompt-pos end-of-input-pos))
	      (when fricas-repair-prompt
;;; delete the old output
		(delete-region (1+ end-of-input-pos) fricas-repair-prompt))
;;; delete and store the input
	      (setq input (delete-and-extract-region beg-of-input-pos 
						     end-of-input-pos))
	      (when fricas-repair-prompt
;;; delete the old prompt before the input
		(delete-region (previous-single-property-change beg-of-input-pos 
								'type)
			       (1+ beg-of-input-pos))
;;; insert the new prompt from the bottom of the buffer - delete any input that
;;; may be left there.  The process mark is always after the last prompt
;;; (except when we are in UserQuery)!
		(delete-region (process-mark fricas-process) (point-max))
		(fricas-insert-ascii 
		 (delete-and-extract-region (previous-single-property-change 
					     (point-max) 'type)
					    (point-max))
		 'fricas-prompt))
	      input))

(defun fricas-send-input (input &optional nohistory)
  (unless nohistory (fricas-add-to-input-history input))
  (fricas-insert-ascii (concat input "\n") nil)
  (setq fricas-input-ring-index nil)
  (set-marker (process-mark fricas-process) (point))
  (setq fricas-cd (string-match " *)cd *" input))
  (process-send-string fricas-process (concat input "\n")))

(defun fricas-eval () 
  (interactive)
  (if (eq fricas-state 'working)
      (message "Fricas is working")
    (let ((pos (point))
	  beg-of-input-pos
	  end-of-input-pos)
      (if (not (fricas-input? pos))
	  (message "Not at command line")
;;; now we know that we are either after a prompt of after a user query.
;;; thus, there should be a previous text property
	(setq beg-of-input-pos (fricas-beginning-of-region-pos pos))
	(if fricas-query-user
;;; we still need to check, whether we are in the right input-region
;;; for user's convenience, we move there if we aren't.
	    (if (not (= beg-of-input-pos (process-mark fricas-process)))
		(goto-char (process-mark fricas-process))
;;; we are in the right place, get the input
	      (setq end-of-input-pos (fricas-end-of-region-pos pos))
	      (delete-region end-of-input-pos (min (1+ end-of-input-pos)
						   (point-max)))
	      (fricas-send-input (delete-and-extract-region beg-of-input-pos 
							    end-of-input-pos)
				 t))
;;; not user query
	  (if (not (fricas-prompt? (1- beg-of-input-pos)))
	      (message "Not after a prompt")
;;; now we know that beg-of-input-pos is truly the first pos after a prompt

	    (setq end-of-input-pos (fricas-end-of-region-pos pos))
;;; now end-of-input-pos is the end of the input, possibly multi-line 
	    (fricas-send-input (fricas-prepare-overwrite beg-of-input-pos 
						       end-of-input-pos))))))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; dealing with output
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun fricas-get-next-output (str ind)
  "str is output to be processed, ind the position of unprocessed output in
str. Returns: 
  nil, if all output from str has been processed,
  (nil    end-pos) if buffer can be inserted up to end-pos,
  (marker end-pos) if there is a marker ending at end-pos."

  (let* ((axMarkBeg (string-match fricas-beg-marker-regexp str ind))
	 (axMarkBegEnd (when axMarkBeg (match-end 0)))
	 (axMarkEnd (string-match fricas-end-marker-regexp str ind))
	 (axMarkEndEnd (when axMarkEnd (match-end 0)))
	 (output-length (length str))
	 (end-pos (or (and (not (eq (aref str (1- output-length)) 
				    ?\n)) ;; last char is a newline
			   (string-match "<" str 
					 (max ind (- output-length 
						     fricas-max-marker-length))))
		      output-length)))
    (cond ((eq axMarkBeg ind)                          ;; begin marker at beginning
	   (list (substring str axMarkBeg axMarkBegEnd) axMarkBegEnd))
	      
	  ((eq axMarkEnd ind)                          ;; end marker   at beginning
	   (list (substring str axMarkEnd axMarkEndEnd) axMarkEndEnd))
	      
	  ((and axMarkBeg 
		(or (not axMarkEnd)                    ;; begin marker before end marker
		    (< axMarkBeg axMarkEnd)))
	   (list nil axMarkBeg))
	      
	  ((and axMarkEnd 
		(or (not axMarkBeg)                    ;; end marker before begin marker
		    (< axMarkEnd axMarkBeg)))
	   (list nil axMarkEnd))

	  ((and (not axMarkBeg) (not axMarkEnd))       ;; no complete marker
	   (unless (= end-pos ind)
	     (list nil end-pos)))

	  (t (error "Cannot happen")))))

(defun fricas-filter (proc str)
  (with-current-buffer (process-buffer proc)
    (let ((output-index 0) 
	  ;; maintains position in fricas-output-buffer yet to be inserted
	  (moving (= (point) (process-mark proc)))
	  ;; detect whether we want to move along the output
	  repair-prompt-move
	  ;; if moving, if we are repairing a prompt
	  query-user-prompt
	  ;; we need to create a prompt for user queries
	  output-type)
      (setq fricas-output-buffer (concat fricas-output-buffer str))
      (save-excursion
        (goto-char (process-mark proc))
        (while (setq output-type
		     (fricas-get-next-output fricas-output-buffer output-index))

          (cond ((null (car output-type))           ;; text to be inserted
		 (fricas-insert-output fricas-output-buffer
				      output-index 
				      (cadr output-type)
				      fricas-last-type))

		((equal (car output-type) "<|startReadLine|>\n")  ;; expect input after prompt
		 (setq fricas-state 'waiting)
		 (setq fricas-last-type nil))
		((equal (car output-type) "<|endOfReadLine|>\n")
		 (setq fricas-state 'working)
		 (setq fricas-last-type 'fricas-undefined))

		((equal (car output-type) "<|startQueryUser|>\n") ;; expect input after system command
		 (setq fricas-state 'waiting)
		 (setq fricas-last-type nil)
		 (setq query-user-prompt t)
		 (setq fricas-query-user t))
		((equal (car output-type) "<|endOfQueryUser|>\n") ;; expect input after system command
		 (setq fricas-state 'working)
		 (setq fricas-last-type 'fricas-undefined)
		 (setq fricas-query-user nil)) ;; should not be necessary

		((equal (car output-type) "<|startAlgebraOutput|>\n") 
		 (setq fricas-last-type 'fricas-algebra))
		((equal (car output-type) "<|endOfAlgebraOutput|>\n") 
		 (setq fricas-last-type 'fricas-undefined))

		((equal (car output-type) "<|startTypeTime|>\n") 
		 (setq fricas-last-type 'fricas-typeTime))
		((equal (car output-type) "<|endOfTypeTime|>\n") 
		 (setq fricas-last-type 'fricas-undefined))

		((equal (car output-type) "<|startKeyedMsg|>\n") 
		 (setq fricas-last-type 'fricas-message))
		((equal (car output-type) "<|endOfKeyedMsg|>\n") 
		 (setq fricas-last-type 'fricas-undefined))

		((equal (car output-type) "<|startPrompt|>\n")
		 (setq fricas-last-type 'fricas-prompt)
		 (when fricas-repair-prompt
		   (goto-char (set-marker (process-mark proc) (point-max)))
		   (setq repair-prompt-move t)
		   (setq fricas-repair-prompt nil)))

		((equal (car output-type) "<|endOfPrompt|>\n")
		 (setq fricas-last-type 'fricas-undefined))

		(t (fricas-insert-output fricas-output-buffer 
					output-index 
					(cadr output-type) 
					fricas-last-type)))

          (setq output-index (cadr output-type))
	  (set-marker (process-mark proc) (point))))
      ;; delete processed output from buffer
      (setq fricas-output-buffer (substring fricas-output-buffer output-index))
      ;; insert a line after user query, if we are overwriting old output
      (when (and query-user-prompt
		 (not (= (process-mark proc)
			 (point-max))))
	(let ((inhibit-read-only t))
	  (goto-char (process-mark proc))
	  (insert "\n")))
      (when (eq fricas-state 'waiting)
	(when fricas-resync-directory?     ;; has to come before fricas-cd
	  (fricas-resync-directory-post))
	(when fricas-cd 
	  (setq fricas-cd nil)
	  (fricas-resync-directory))
	(when fricas-yank-file?
	  (fricas-yank-post)
	  (setq fricas-yank-file? nil))
	(when (and fricas-save-history?
		   (eq fricas-state 'waiting))
	  (message "done")
	  (fricas-save-history-post)
	  (setq fricas-save-history? nil)))
      (when moving (if repair-prompt-move
		       (fricas-down-input)
		     (goto-char (process-mark proc)))))))

(defun fricas-insert-output (str beg end type)
"inserts the substring of str into the buffer"
  (fricas-insert-ascii (substring str beg end) type))

(defun fricas-insert-ascii (str type)
  (let ((inhibit-read-only t) 
	(pos (point)))
    (insert str)
    ;; the type of input is nil
    (put-text-property pos (point) 'type type)
    (put-text-property pos (point) 'face type)
    (put-text-property pos (point) 'rear-nonsticky t)
    (put-text-property pos (point) 'front-sticky t)
    (put-text-property pos (point) 'read-only type)
    ;; the following inhibits deletion of the terminating newline in the input
    ;; area (inserted either by fricas-underscore-newline or fricas-send-input)
    (when (not type)
      (put-text-property (1- (point)) (point) 'front-sticky nil)
      (put-text-property (1- (point)) (point) 'read-only t))
    (when (eq type 'fricas-prompt)
      (put-text-property pos (point) 'field t))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; getting old input - taken and adapted from comint
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun fricas-add-to-input-history (cmd)
  "Add CMD to the input history.
Ignore duplicates if `fricas-input-ignoredups' is non-nil."
  (if (or (null fricas-input-ignoredups)
	  (not (ring-p fricas-input-ring))
	  (ring-empty-p fricas-input-ring)
	  (not (string-equal (ring-ref fricas-input-ring 0)
			     cmd)))
      (ring-insert fricas-input-ring cmd)))


(defun fricas-search-start (arg)
  "Index to start a directional search, starting at `fricas-input-ring-index'."
  (if fricas-input-ring-index
      ;; If a search is running, offset by 1 in direction of arg
      (mod (+ fricas-input-ring-index (if (> arg 0) 1 -1))
	   (ring-length fricas-input-ring))
    ;; For a new search, start from beginning or end, as appropriate
    (if (>= arg 0)
	0				       ; First elt for forward search
      (1- (ring-length fricas-input-ring)))))  ; Last elt for backward search


(defun fricas-previous-matching-input-string-position (regexp arg &optional start)
  "Return the index matching REGEXP ARG places along the input ring.
Moves relative to START, or `fricas-input-ring-index'."
  (if (or (not (ring-p fricas-input-ring))
	  (ring-empty-p fricas-input-ring))
      (error "No history"))
  (let* ((len (ring-length fricas-input-ring))
	 (motion (if (> arg 0) 1 -1))
	 (n (mod (- (or start (fricas-search-start arg)) motion) len))
	 (tried-each-ring-item nil)
	 (prev nil))
    ;; Do the whole search as many times as the argument says.
    (while (and (/= arg 0) (not tried-each-ring-item))
      ;; Step once.
      (setq prev n
	    n (mod (+ n motion) len))
      ;; If we haven't reached a match, step some more.
      (while (and (< n len) (not tried-each-ring-item)
		  (not (string-match regexp (ring-ref fricas-input-ring n))))
	(setq n (mod (+ n motion) len)
	      ;; If we have gone all the way around in this search.
	      tried-each-ring-item (= n prev)))
      (setq arg (if (> arg 0) (1- arg) (1+ arg))))
    ;; Now that we know which ring element to use, if we found it, return that.
    (if (string-match regexp (ring-ref fricas-input-ring n))
	n)))

(defun fricas-delete-input ()
  "Delete all input in the current input region."
  (let ((pos (point)))
    (if (fricas-input? pos)
	(delete-region (fricas-beginning-of-region-pos pos)
		       (fricas-end-of-region-pos pos))
      (error "Not at command line"))))

(defun fricas-previous-input (arg)
  "Cycle backwards through input history, saving input."
  (interactive "*p")
  (if (and fricas-input-ring-index
	   (or		       ;; leaving the "end" of the ring
	    (and (< arg 0)		; going down
		 (eq fricas-input-ring-index 0))
	    (and (> arg 0)		; going up
		 (eq fricas-input-ring-index
		     (1- (ring-length fricas-input-ring)))))
	   fricas-stored-incomplete-input)
      (fricas-restore-input)
    (fricas-previous-matching-input "." arg)))

(defun fricas-next-input (arg)
  "Cycle forwards through input history."
  (interactive "*p")
  (fricas-previous-input (- arg)))

(defun fricas-regexp-arg (prompt)
  "Return list of regexp and prefix arg using PROMPT."
  (let* (;; Don't clobber this.
	 (last-command last-command)
	 (regexp (read-from-minibuffer prompt nil nil nil
				       'minibuffer-history-search-history)))
    (list (if (string-equal regexp "")
	      (setcar minibuffer-history-search-history
		      (nth 1 minibuffer-history-search-history))
	    regexp)
	  (prefix-numeric-value current-prefix-arg))))

(defun fricas-search-arg (arg)
  ;; First make sure there is a ring and that we are in the input region
  (cond ((not (fricas-input? (point)))
	 (error "Not at command line"))
	((or (null fricas-input-ring)
	     (ring-empty-p fricas-input-ring))
	 (error "Empty input ring"))
	((zerop arg)
	 ;; arg of zero resets search from beginning, and uses arg of 1
	 (setq fricas-input-ring-index nil)
	 1)
	(t
	 arg)))

(defun fricas-restore-input ()
  "Restore unfinished input."
  (interactive)
  (when fricas-input-ring-index
    (fricas-delete-input)
    (when (> (length fricas-stored-incomplete-input) 0)
      (insert fricas-stored-incomplete-input)
      (message "Input restored"))
    (setq fricas-input-ring-index nil)))

(defun fricas-previous-matching-input (regexp n)
  "Search backwards through input history for match for REGEXP.
\(Previous history elements are earlier commands.)
With prefix argument N, search for Nth previous match.
If N is negative, find the next or Nth next match."
  (interactive (fricas-regexp-arg "Previous input matching (regexp): "))
  (setq n (fricas-search-arg n))
  (let ((pos (fricas-previous-matching-input-string-position regexp n)))
    ;; Has a match been found?
    (if (null pos)
	(error "Not found")
      ;; If leaving the edit line, save partial input
;;;      (if (null fricas-input-ring-index)	;not yet on ring
;;;	  (setq fricas-stored-incomplete-input
;;;		(funcall fricas-get-old-input)))
      (setq fricas-input-ring-index pos)
      (message "History item: %d" (1+ pos))
      (fricas-delete-input)
      (insert (ring-ref fricas-input-ring pos)))))

(defun fricas-next-matching-input (regexp n)
  "Search forwards through input history for match for REGEXP.
\(Later history elements are more recent commands.)
With prefix argument N, search for Nth following match.
If N is negative, find the previous or Nth previous match."
  (interactive (fricas-regexp-arg "Next input matching (regexp): "))
  (fricas-previous-matching-input regexp (- n)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; storing the worksheet
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun fricas-save-history ()
  "If necessary, removes previous saved histories, since it seems that fricas
does not store the %% facility correctly.  Then issues )history )save."
  (when (fricas-can-receive-commands?)
    (let ((dirname (concat (buffer-file-name) ".axh")))
    (goto-char (process-mark fricas-process))
    (when (file-exists-p dirname)
      (delete-file (concat dirname "/index.KAF"))
      (delete-directory dirname))
    (setq fricas-save-history? t)
    (fricas-send-input (concat ")history )save " (buffer-file-name))))))

(defun fricas-save-history-post ()
  (set-buffer-modified-p nil))

(defun fricas-query-kill ()
  (if (eq major-mode 'fricas-mode)
      (or (not (buffer-modified-p))
          (yes-or-no-p (format "Buffer %s modified; kill anyway? "
                               (buffer-name))))
    t))



(provide 'fricas)
