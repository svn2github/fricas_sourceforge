;; Copyright (c) 1991-2002, The Numerical ALgorithms Group Ltd.
;; All rights reserved.
;;
;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions are
;; met:
;;
;;     - Redistributions of source code must retain the above copyright
;;       notice, this list of conditions and the following disclaimer.
;;
;;     - Redistributions in binary form must reproduce the above copyright
;;       notice, this list of conditions and the following disclaimer in
;;       the documentation and/or other materials provided with the
;;       distribution.
;;
;;     - Neither the name of The Numerical ALgorithms Group Ltd. nor the
;;       names of its contributors may be used to endorse or promote products
;;       derived from this software without specific prior written permission.
;;
;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
;; IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
;; TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
;; PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
;; OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
;; EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
;; PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
;; PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
;; LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;; NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#|
This file is a collection of utility functions that are useful
for system level work. A couple of the functions, {\bf build-depsys}
and {\bf build-interpsys} interface to the src/interp/Makefile.

A second group of related functions allows us to rebuild portions
of the system from the command prompt. This varies from rebuilding
individual files to whole directories. The most complex functions
like {\bf makespad} can rebuild the whole algebra tree.

A third group of related functions are used to set up the 
{\bf autoload} mechanism. These enable whole subsystems to
be kept out of memory until they are used.

A fourth group of related functions are used to construct and
search Emacs TAGS files.

A fifth group of related functions are some translated boot
functions we need to define here so they work and are available
at load time.
|#
(in-package "BOOT")
(export '($spadroot $directory-list reroot
          make-absolute-filename |$msgDatabaseName| |$defaultMsgDatabaseName|))

;;; Get the write date of a file. In GCL we need to check that it
;;; exists first. This is a simple helper function.
(defun our-write-date (file) (and #+kcl (probe-file file)
                                  (file-write-date file)))

;;; Make a directory relative to the {\bf \$spadroot} variable.
(defun make-directory (direc)
  (setq direc (namestring direc))
  (if (string= direc "")  $SPADROOT
   (if (or (memq :unix *features*)
           (memq 'unix *features*))
    (progn
      (if (char/= (char direc 0) #\/)
          (setq direc (concat $SPADROOT "/" direc)))
      (if (char/= (char direc (1- (length direc))) #\/)
          (setq direc (concat direc "/")))
      direc)
    (progn ;; Assume Windows conventions
      (if (not (or (char= (char direc 0) #\/)
                   (char= (char direc 0) #\\)
                   (find #\: direc)))
          (setq direc (concat $SPADROOT "\\" direc)))
      (if (not (or (char= (char direc (1- (length direc))) #\/)
                   (char= (char direc (1- (length direc))) #\\ )))
          (setq direc (concat direc "\\")))
      direc))))

;;; Various lisps use different ``extensions'' on the filename to indicate
;;; that a file has been compiled. We set this variable correctly depending
;;; on the system we are using.
(defvar *lisp-bin-filetype*
  #+:GCL "o"
  #+lucid "bbin"
  #+symbolics "bin"
  #+cmulisp "fasl"
  #+:sbcl "fasl"
  #+:clisp "fas"
  #+:openmcl (subseq (namestring CCL:*.FASL-PATHNAME*) 1)
  #+:ecl "fas"
  #+:ccl "not done this way at all"
  )

;;; Load a whole subdirectory of compiled files
(defun load-directory (dir)
   (let* ((direc (make-directory dir))
          (pattern (make-pathname :directory (pathname-directory direc)
                                  :name :wild :type *lisp-bin-filetype*))
          (files (directory pattern)))
      (mapcar #'load files)))

;;; The {\bf compspadfiles} function will recompile a list of {\bf spad} files.
;;; The filelist should be a file containing names of files to compile.
(defun compspadfiles (filelist ;; should be a file containing files to compile
                      &optional (*default-pathname-defaults*
                                 (pathname (concat $SPADROOT "nalgebra/"))))
   (with-open-file (stream filelist)
        (do ((fname (read-line stream nil nil) (read-line stream nil nil)))
            ((null fname) 'done)
          (setq fname (string-right-trim " *" fname))
          (when (not (equal (elt fname 0) #\*))
              (spad fname (concat (pathname-name fname) ".out"))))))

#|
We occasionally need to completely rebuild the algebra from the spad
files. This function will iterate across a directory containing all
of the spad files and attempt to recompile them. A correct call looks
like:
\begin{verbatim}
(in-package "BOOT")
(recompile-all-algebra-files "nalg")
\end{verbatim}
Note that it will build a pathname from the current {\bf AXIOM}
shell variable. So if the {\bf AXIOM} shell variable had the value
\begin{verbatim}
/spad/mnt/${SYS}
\end{verbatim}
(where the [[${SYS}]] variable is the same one set at build time)
then the wildcard expands to
\begin{verbatim}
/spad/mnt/${SYS}/nalg/*.spad
\end{verbatim}
and all of the matching files would be recompiled.
|#
(defun recompile-all-algebra-files (dir) ;; a desperation measure
   (let* ((direc (make-directory dir))
          (pattern (make-pathname :directory (pathname-directory direc)
                                  :name :wild :type "spad"))
          (files (directory pattern))
          (*default-pathname-defaults* (pathname direc)))
     (mapcar
       #'(lambda (fname) (spad fname (concat (pathname-name fname) ".out")))
       files)))

;;; This function will compile any lisp code that has changed in a directory.
(defun recompile-directory (dir)
  (let* ((direc (make-directory dir))
         (pattern (make-pathname :directory (pathname-directory direc)
                                  :name :wild :type "lisp"))
          (files (directory pattern)))
      (mapcan #'recompile-file-if-necessary files)))

;;; This is a helper function that checks the time stamp between
;;; the given file and its compiled binary. If the file has changed
;;; since it was last compiled this function will recompile it.
(defun recompile-file-if-necessary (lfile)
   (let* ((bfile (make-pathname :type *lisp-bin-filetype* :defaults lfile))
          (bdate (our-write-date bfile))
          (ldate (our-write-date lfile)))
       (if (and bdate ldate (> bdate ldate)) nil
           (progn
             (format t "compiling ~a~%" lfile)
             (compile-file lfile)
             (list bfile)))))

;;; Force recompilation of all lisp files in a directory.
(defun recompile-all-files (dir)
   (let* ((direc (make-directory dir))
          (pattern (make-pathname :directory (pathname-directory direc)
                                  :name :wild :type "lisp"))
          (files (directory pattern)))
     (mapcar #'compile-file files)))

;;; Recompile library lisp code if necessary.
(defun recompile-lib-directory (dir)
   (let* ((direc (make-directory dir))
          (pattern (make-pathname :directory (pathname-directory direc)
                                  :name :wild :type "NRLIB"))
          (files (directory pattern)))
      (mapcan #'recompile-NRLIB-if-necessary files)))

#|
Occasionally it will be necessary to iterate over all of the NRLIB
directories and compile each of the code.lsp files in every NRLIB.
This function will do that. A correct call looks like:
\begin{verbatim}
(in-package "BOOT")
(recompile-all-libs "/spad/mnt/${SYS}/algebra")
\end{verbatim}
where the [[${SYS}]] variable is same as the one set at build time.
|#
(defun recompile-all-libs (dir)
   (let* ((direc (make-directory dir))
          (pattern (make-pathname :directory (pathname-directory direc)
                                  :name :wild :type "NRLIB"))
          (files (directory pattern)))
     (mapcar
       #'(lambda (lib) (compile-lib-file (concat (namestring lib) "/code.lsp")))
       files)))

;;; Translate a directory of boot code to common lisp if the boot code
;;; is newer.
(defun retranslate-directory (dir)
   (let* ((direc (make-directory dir))
          (pattern (make-pathname :directory (pathname-directory direc)
                                  :name :wild :type "boot"))
          (files (directory pattern)))
      (mapcan #'retranslate-file-if-necessary files)))

;;; Retranslate a single boot file if it has been changed.
(defun retranslate-file-if-necessary (bootfile)
   (let* ((lfile (make-pathname :type "lisp" :defaults bootfile))
          (ldate (our-write-date lfile))
          (binfile (make-pathname :type *lisp-bin-filetype* :defaults bootfile))
          (bindate (our-write-date binfile))
          (bootdate (our-write-date   bootfile)))
       (if (and ldate bootdate (> ldate bootdate)) nil
           (if (and bindate bootdate (> bindate bootdate)) nil
               (progn (format t "translating ~a~%" bootfile)
                      (boot bootfile lfile) (list bootfile))))))


;;; TAGS are useful for finding functions if you run Emacs. We have a
;;; set of functions that construct TAGS files for Axiom.

;;; Run the etags command on all of the lisp code. Then run the
;;; {\bf spadtags-from-directory} function on the boot code. The
;;; final TAGS file is constructed in the {\bf tmp} directory.
(defun make-tags-file ()
#+:gcl (system:chdir "/tmp")
#-:gcl (vmlisp::obey (concatenate 'string "cd " "/tmp"))
  (obey (concat "etags " (make-absolute-filename "../../src/interp/*.lisp")))
  (spadtags-from-directory "../../src/interp" "boot")
  (obey "cat /tmp/boot.TAGS >> /tmp/TAGS"))

;;; This function will walk across a directory and call 
;;; {\bf spadtags-from-file} on each file.
(defun spadtags-from-directory (dir type)
   (let* ((direc (make-directory dir))
          (pattern (make-pathname :directory (pathname-directory direc)
                                  :name :wild :type type))
          (files (directory pattern)))
     (with-open-file
      (tagstream (concatenate 'string "/tmp/" type ".TAGS") :direction :output
                 :if-exists :supersede :if-does-not-exist :create)
      (dolist (file files (namestring tagstream))
              (print (list "processing:" file))
              (write-char #\page tagstream)
              (terpri tagstream)
              (write-string (namestring file) tagstream)
              (write-char #\, tagstream)
              (princ (spadtags-from-file file) tagstream)
              (terpri tagstream)
              (with-open-file (stream "/tmp/*TAGS")
                 (do ((line (read-line stream nil nil)
                            (read-line stream nil nil)))
                     ((null line) nil)
                     (write-line line tagstream)))))))

;;; This function knows how to find function names in {\bf boot} code
;;; so we can add them to the TAGS file using standard etags format.
(defun spadtags-from-file (spadfile)
  (with-open-file (tagstream "/tmp/*TAGS" :direction :output
                             :if-exists :supersede :if-does-not-exist :create)
    (with-open-file (stream spadfile)
       (do ((char-count 0 (file-position stream))
            (line (read-line stream nil nil) (read-line stream nil nil))
            (line-count 1 (1+ line-count)))
           ((null line) (file-length tagstream))
           (if (/= (length line) 0)
               (let ((firstchar (elt line 0)) (end nil)
                     (len (length line)))
                 (cond ((member firstchar '(#\space #\{ #\} #\tab )
                                :test #'char= ) "skip")
                       ((string= line ")abb" :end1 (min 4 len))
                        (setq end (position #\space line :from-end t
                                            :test-not #'eql)
                              end (and end (position #\space line :from-end t
                                                     :end end)))
                        (write-tag-line line tagstream end
                                        line-count char-count))
                       ((char= firstchar #\)) "skip")
                       ((and (> len 1) (string= line "--" :end1 2)) "skip")
                       ((and (> len 1) (string= line "++" :end1 2)) "skip")
                       ((search "==>" line) "skip")
                       ((and (setq end (position #\space line)
                                   end (or (position #\( line :end end) end)
                                   end (or (position #\: line :end end) end)
                                   end (or (position #\[ line :end end) end))
                             (equal end 0)) "skip")
                       ((position #\] line :end end) "skip")
                       ((string= line "SETANDFILEQ" :end1 end) "skip")
                       ((string= line "EVALANDFILEACTQ" :end1 end) "skip")
                       (t (write-tag-line line tagstream
                                          (if (numberp end) (+ end 1) end)
                                          line-count char-count))  )))))))

;;; This function knows how to write a single line into a TAGS file
;;; using the etags file format.
(defun write-tag-line (line tagstream endcol line-count char-count)
  (write-string line tagstream :end endcol)
  (write-char #\rubout tagstream)
  (princ line-count tagstream)
  (write-char #\, tagstream)
  (princ char-count tagstream)
  (terpri tagstream))

;;; This is a trivial predicate for calls to {\bf position-if-not} in the
;;; {\bf findtag} function.
(defun blankcharp (c) (char= c #\Space))

;;; The {\bf findtag} function is a user-level function to figure out
;;; which file contains a given tag. This is sometimes useful if Emacs
;;; is not around or TAGS are not loaded.
(defun findtag (tag &optional (tagfile (concat $spadroot "/../../src/interp/TAGS")) )
  ;; tag is an identifier
    (with-open-file (tagstream tagfile)
        (do ((tagline (read-line tagstream nil nil)
                      (read-line tagstream nil nil))
             (*package* (symbol-package tag))
             (sourcefile)
             (stringtag (string tag))
             (pos)
             (tpos)
             (type))
            ((null tagline) ())
            (cond ((char= (char tagline 0) #\Page)
                   (setq tagline (read-line tagstream nil nil))
                   (setq sourcefile (subseq tagline 0
                                            (position #\, tagline)))
                   (setq type (pathname-type sourcefile)))
                  ((string= type "lisp")
                   (if (match-lisp-tag tag tagline)
                       (return (cons sourcefile tagline))))
                  ((> (mismatch ")abb" tagline) 3)
                   (setq pos (position #\Space tagline :start 3))
                   (setq pos (position-if-not #'blankcharp tagline
                                              :start pos))
                   (setq pos (position #\Space tagline :start pos))
                   (setq pos (position-if-not #'blankcharp tagline
                                              :start pos))
                   (setq tpos (mismatch stringtag tagline :start2 pos))
                   (if (and (= tpos (length (string tag)))
                            (member (char tagline (+ pos tpos)) '(#\Space #\Rubout)))
                       (return (cons sourcefile tagline))))
                  ((setq pos (mismatch stringtag tagline))
                   (if (and (= pos (length stringtag))
                            (> (length tagline) pos)
                            (member (char tagline pos)
                                    '( #\Space #\( #\:) ))
                       (return (cons sourcefile tagline))))))))

;;; The {\bf match-lisp-tag} function is used by {\bf findtag}. This
;;; function assumes that \\ can only appear as first character of name.
(defun match-lisp-tag (tag tagline &optional (prefix nil)
                           &aux (stringtag (string tag)) pos tpos)
  (when (and (if prefix
                 (= (mismatch prefix tagline :test #'char-equal)
                    (length prefix))
               t)
             (numberp (setq pos (position #\Space tagline)))
             (numberp (setq pos (position-if-not #'blankcharp tagline
                                                 :start pos))))
        (if (char= (char tagline pos) #\') (incf pos))
        (if (member (char tagline pos) '( #\\ #\|))
            (setq tpos (1+ pos))
          (setq tpos pos))
        (and (= (mismatch stringtag tagline :start2 tpos :test #'char-equal)
                (length stringtag))
             (eq tag (read-from-string tagline nil nil :start pos))) ))

;;; Translate a single boot file to common lisp, compile it
(defun compile-boot-file (file)
  "compile and load a boot file"
  (boot (concat file ".boot") (concat file ".lisp"))
#+:AKCL
  (compile-file (concat file ".lisp"))
#+:AKCL
  (load (concat file "." *lisp-bin-filetype*))
#+:CCL
  (load (concat file ".lisp"))
)

;;; Translate a single boot file to common lisp
(defun translate (file) ;; translates a single boot file
#+:CCL
  (setq *package* (find-package "BOOT"))
#+:AKCL
  (in-package "BOOT")
  (let (*print-level* *print-length* (fn (pathname-name file))
        (bootfile  (merge-pathnames file (concat $spadroot "nboot/.boot"))))
    (boot bootfile (make-pathname :type "lisp" :defaults bootfile))))

;;; Translate a list of boot files to common lisp.
(defun translist (fns)
  (mapcar #'(lambda (f) (format t "translating ~a~%" (concat f ".boot"))
                        (translate f))
          fns))

;;; The relative directory list specifies a search path for files 
;;; for the current directory structure.
(defvar $relative-directory-list
  '("/../../src/input/"
    "/doc/msgs/"
    "/../../src/algebra/"
    "/../../src/interp/"  ; for boot and lisp  files (helps fd)
    "/doc/spadhelp/" ))

;;; The relative directory list specifies how to find the algebra
;;; directory from the current {\bf AXIOM} shell variable.
(defvar $relative-library-directory-list '("/algebra/"))

;;; This is the system-wide list of directories to search.
;;; It is set up in the {\bf reroot} function.
(defvar $directory-list ())

;;; This is the system-wide search path for library files.
;;; It is set up in the {\bf reroot} function.
(defvar $library-directory-list ())

;;; When we are building a {\bf depsys} image for AKCL (now GCL) we need
;;; need to initialize some optimization routines. Each time a file is
;;; compiled in GCL we collect some function information and write it
;;; out to a {\bf .fn} file. If this {\bf .fn} file exists at compile
;;; time then GCL will perform function call optimizations. These can
;;; be significant in terms of performance.
(defun make-depsys (build-interp-dir)
  ;; perform system initializations for building a starter system
  (init-memory-config)
  #+:AKCL
  (let ()
   (mapcar
     #'load
     (directory (concatenate 'string build-interp-dir "/*.fn")))
   (with-open-file
    (out (concatenate 'string build-interp-dir "/proclaims.lisp" )
      :direction :output)
     (compiler::make-proclaims out))
   (load (concatenate 'string build-interp-dir "/proclaims.lisp")))
  )

;;; The {\bf boottocl} function is the workhorse function that translates
;;; {\bf .boot} files to {\bf Common Lisp}. It basically wraps the actual
;;; {\bf boot} function call to ensure that we don't truncate lines 
;;; because of {\bf *print-level*} or {\bf *print-length*}.
(in-package "BOOTTRAN") 

#+:oldboot
(defun boottran::boottocl (file &optional ofile) ;; translates a single boot file
#+:CCL
  (setq *package* (find-package "BOOT"))
#-:CCL
  (in-package "BOOT")
  (let (*print-level* *print-length* (fn (pathname-name file)))
    (boot::boot
      file
      (if ofile ofile
         (merge-pathnames (make-pathname :type "clisp") file)))))


(in-package "BOOT")

;;; This is the {\bf boot parser} subsystem. It is only needed by 
;;; algebra developers and developers who translate boot code to
;;; Common Lisp.
(setq parse-functions
      '(
;;      loadparser
        |oldParserAutoloadOnceTrigger|
        |PARSE-Expression|
        boot-parse-1
        BOOT
        SPAD
        init-boot/spad-reader))

;;; This is the {\bf spad compiler} subsystem. It is only needed by
;;; developers who write or modify algebra code.
(setq comp-functions
      '(
;;      loadcompiler
        |oldCompilerAutoloadOnceTrigger|
        |compileSpad2Cmd|
        |convertSpadToAsFile|
        |compilerDoit|
        |compilerDoitWithScreenedLisplib|
        |mkCategory|
        |cons5|
        |sublisV|))

;;; This is the {\bf browser} subsystem. It will get autoloaded only
;;; if you use the browse function of the {\bf hypertex} system.
(setq browse-functions
      '(
;;      loadbrowse
        |browserAutoloadOnceTrigger|
        |parentsOf|           ;interop.boot
        |getParentsFor|       ;old compiler
        |folks|               ;for astran
        |extendLocalLibdb|    ;)lib needs this
        |oSearch|
        |aokSearch|
        |kSearch|
        |aSearch|
        |genSearch|
        |docSearch|
        |abSearch|
        |detailedSearch|
        |ancestorsOf|
        |aPage|
        |dbGetOrigin|
        |dbGetParams|
        |dbGetKindString|
        |dbGetOrigin|
        |dbComments|
        |grepConstruct|
        |buildLibdb|
        |bcDefiniteIntegrate|
        |bcDifferentiate|
        |bcDraw|
        |bcExpand|
        |bcIndefiniteIntegrate|
        |bcLimit|
        |bcMatrix|
        |bcProduct|
        |bcSeries|
        |bcSolve|
        |bcSum|
        |cSearch|
        |conPage|
        |dbName|
        |dbPart|
        |extendLocalLibdb|
        |form2HtString|
        |htGloss|
        |htGreekSearch|
        |htHistory|
        |htSystemCommands|
        |htSystemVariables|
        |htTextSearch|
        |htTutorialSearch|
        |htUserVariables|
        |htsv|
        |oPage|
        |oPageFrom|
        |spadSys|
        |spadType|
        |syscomPage|
        |unescapeStringsInForm|))

;;; This is a little used subsystem to generate {\bf ALDOR} code
;;; from {\bf Spad} code.
(setq translate-functions '(
;; .spad to .as translator, in particular
;;      loadtranslate
        |spad2AsTranslatorAutoloadOnceTrigger|
        ))

;;; This is part of the {\bf ALDOR subsystem}. These will be loaded
;;; if you compile a {\bf .as} file rather than a {\bf .spad} file.
;;; {\bf ALDOR} is an external compiler that gets automatically called
;;; if the file extension is {\bf .as}.
(setq asauto-functions '(
        loadas
;;      |as|                         ;; now in as.boot
;;      |astran|                     ;; now in as.boot
        |spad2AxTranslatorAutoloadOnceTrigger|
        |sourceFilesToAxcliqueAxFile|
        |sourceFilesToAxFile|
        |setExtendedDomains|
        |makeAxFile|
        |makeAxcliqueAxFile|
        |nrlibsToAxFile|
        |attributesToAxFile| ))

;;; These are some old {\bf debugging} functions.  I can't imagine
;;; why you might autoload them but they don't need to be in a running
;;; system.
(setq debug-functions '(
        loaddebug
        |showSummary|
        |showPredicates|
        |showAttributes|
        |showFrom|
        |showImp|))

#|
There are several subsystems within {\bf AXIOM} that are not normally
loaded into a running system. They will be loaded only if you invoke
one of the functions listed here. Each of these listed functions will
have their definitions replaced by a special ``autoloader'' function.
The first time a function named here is called it will trigger a
load of the associated subsystem, the autoloader functions will get
overwritten, the function call is retried and now succeeds. Files
containing functions listed here are assumed to exist in the 
{\bf autoload} subdirectory. The list of files to load is defined
in the src/interp/Makefile.
|#

#|
This function is called by {\bf build-interpsys}. It takes two lists.
The first is a list of functions that need to be used as 
``autoload triggers''. The second is a list of files to load if one
of the trigger functions is called. At system build time each of the
functions in the first list is set up to load every file in the second
list. In this way we will automatically load a whole subsystem if we
touch any function in that subsystem. We call a helper function
called {\bf setBootAutoLoadProperty} to set up the autoload trigger.
This helper function is listed below.
|#
(defun |setBootAutloadProperties| (fun-list file-list)
#-:CCL
  (mapc #'(lambda (fun) (|setBootAutoLoadProperty| fun file-list)) fun-list)
#+:CCL
  (mapc #'(lambda (fun) (lisp::set-autoload fun file-list)) fun-list)
)

;;; This function knows where the {\bf autoload} subdirectory lives.
;;; It is called by {\bf mkBootAutoLoad} above to find the necessary
;;; files.
(defun boot-load (file)
  (let ((name (concat $SPADROOT "/autoload/" (pathname-name file))))
    (if (eq |$printLoadMsgs| '|on|)
        (format t "   Loading ~A.~%" name))
    (load name)))

;;; This is a helper function to set up the autoload trigger. It sets
;;; the function cell of each symbol to {\bf mkBootAutoLoad} which is
;;; listed below. 
(defun |setBootAutoLoadProperty| (func file-list)
  (setf (symbol-function func) (|mkBootAutoLoad| func file-list)) )

#|
This is how the autoload magic happens. Every function named in the
autoload lists is actually just another name for this function. When
the named function is called we call {\bf boot-load} on all of the
files in the subsystem. This overwrites all of the autoload triggers.
We then look up the new (real) function definition and call it again
with the real arguments. Thus the subsystem loads and the original
call succeeds.
|#
(defun |mkBootAutoLoad| (fn file-list)
   (function (lambda (&rest args)
                 (mapc #'boot-load file-list)
                 (unless (string= (subseq (string fn) 0 4) "LOAD")
                  (apply (symbol-function fn) args)))))

;;; Prefix a filename with the {\bf AXIOM} shell variable.
(defun make-absolute-filename (name)
 (concatenate 'string $spadroot name))

#|
The reroot function is used to reset the important variables used by
the system. In particular, these variables are sensitive to the
{\bf AXIOM} shell variable. That variable is renamed internally to
be {\bf \$spadroot}. The {\bf reroot} function will change the
system to use a new root directory and will have the same effect
as changing the {\bf AXIOM} shell variable and rerunning the system
from scratch.  A correct call looks like:
\begin{verbatim}
(in-package "BOOT")
(reroot "${AXIOM}")
\end{verbatim}
where the [[${AXIOM}]] variable points to installed tree.
|#
(defun reroot (dir)
  (setq $spadroot dir)
  (setq $directory-list
   (mapcar #'make-absolute-filename $relative-directory-list))
  (setq $library-directory-list
   (mapcar #'make-absolute-filename $relative-library-directory-list))
  (setq |$defaultMsgDatabaseName|
        (pathname (make-absolute-filename "/share/msgs/s2-us.msgs")))
  (setq |$msgDatabaseName| ()))

;;; Sets up the system to use the {\bf AXIOM} shell variable if we can
;;; and default to the {\bf \$spadroot} variable (which was the value
;;; of the {\bf AXIOM} shell variable at build time) if we can't.
(defun initroot (&optional (newroot (BOOT::|getEnv| "AXIOM")))
  (reroot (or newroot $spadroot (error "setenv AXIOM or (setq $spadroot)"))))

;;; Gnu Common Lisp (GCL) (at least 2.6.[78]) requires some changes 
;;; to the default memory setup to run Axiom efficently.
;;; This function performs those setup commands. 
(defun init-memory-config (&key
                           (cons 500)
                           (fixnum 200)
                           (symbol 500)
                           (package 8)
                           (array 400)
                           (string 500)
                           (cfun 100)
                           (cpages 3000)
                           (rpages 1000)
                           (hole 2000) )
  ;; initialize AKCL memory allocation parameters
  #+:AKCL
  (progn
    (system:allocate 'cons cons)
    (system:allocate 'fixnum fixnum)
    (system:allocate 'symbol symbol)
    (system:allocate 'package package)
    (system:allocate 'array array)
    (system:allocate 'string string)
    (system:allocate 'cfun cfun)
    (system:allocate-contiguous-pages cpages)
    (system:allocate-relocatable-pages rpages)
    (system:set-hole-size hole))
  #-:AKCL
  nil)

#|
;############################################################################
;# autoload dependencies
;#
;# if you are adding a file which is to be autoloaded the following step
;# information is useful:
;#  there are 2 cases:
;#   1) adding files to currently autoloaded parts
;#      (as of 2/92: browser old parser and old compiler)
;#   2) adding new files
;#   case 1:
;#     a) you have to add the file to the list of files currently there
;#        (e.g. see BROBJS above)
;#     b) add an autolaod rule
;#        (e.g. ${AUTO}/parsing.${O}: ${OUT}/parsing.${O})
;#     c) edit util.lisp to add the 'external' function (those that
;#        should trigger the autoload
;#   case 2:
;#     build-interpsys (in util.lisp) needs an extra argument for the
;#     new autoload things and several functions in util.lisp need hacking.
;############################################################################

The {\bf build-interpsys} function takes a list of files to load
into the image ({\bf load-files}). It also takes several lists of files, 
one for each subsystem which will be autoloaded. Autoloading is explained
below. Next it takes a set of shell variables, the most important of 
which is the {\bf spad} variable. This is normally set to be the same
as the final build location. This function is called in the 
src/interp/Makefile. 

This function calls {\bf initroot} to set up pathnames we need. Next
it sets up the lisp system memory (at present only for AKCL/GCL). Next
it loads all of the named files, resets a few global state variables,
loads the databases, sets up autoload triggers and clears out hash tables.
After this function is called the image is clean and can be saved.
|#
(defun build-interpsys (load-files parse-files comp-files browse-files
             translate-files nagbr-files asauto-files spad)
  (declare (ignore nagbr-files))
  (push :oldboot *features*)
  (initroot spad)
  #+:AKCL
  (init-memory-config :cons 500 :fixnum 200 :symbol 500 :package 8
                      :array 400 :string 500 :cfun 100 :cpages 1000
                      :rpages 1000 :hole 2000)
  #+:AKCL
  (setq compiler::*suppress-compiler-notes* t)
  (mapcar #'load load-files)
  (|resetWorkspaceVariables|)
  (|initHist|)
  (|initNewWorld|)
  (compressopen)
  (interpopen)
  (create-initializers)
  (|start| :fin)
#+:CCL
  (resethashtables)
  (setq *load-verbose* nil)
  (|setBootAutloadProperties| comp-functions comp-files)
  (|setBootAutloadProperties| parse-functions parse-files)
  (|setBootAutloadProperties| browse-functions browse-files)
  (|setBootAutloadProperties| translate-functions translate-files)
  (|setBootAutloadProperties| asauto-functions asauto-files)
  (resethashtables) ; the databases into core, then close the streams
 )

;;; The {\bf depsys} image is one of the two images we build from
;;; the src/interp subdirectory (the other is {\bf interpsys}). We
;;; use {\bf depsys} as a compile-time image as it contains all of
;;; the necessary functions and macros to compile any file. The 
;;; {\bf depsys} image is almost the same as an {\bf interpsys}
;;; image but it does not have any autoload triggers or databases
;;; loaded.
(defun build-depsys (load-files spad build-interp-dir)
#+:CCL
  (setq *package* (find-package "BOOT"))
#+:AKCL
  (in-package "BOOT")
  (push :oldboot *features*)
  (mapcar #'load load-files)
  (make-depsys build-interp-dir)
  (initroot spad)
  #+:AKCL
  (init-memory-config :cons 1000 :fixnum 400 :symbol 1000 :package 16
                      :array 800 :string 1000 :cfun 200 :cpages 2000
                      :rpages 2000 :hole 4000) )
;;  (init-memory-config :cons 500 :fixnum 200 :symbol 500 :package 8
;;                    :array 400 :string 500 :cfun 100 :cpages 1000
;;                    :rpages 1000 :hole 2000) )


(DEFUN |string2BootTree| (S)
  (init-boot/spad-reader)
  (LET* ((BOOT-LINE-STACK (LIST (CONS 1 S)))
     ($BOOT T)
     ($SPAD NIL)
     (XTOKENREADER 'GET-BOOT-TOKEN)
     (LINE-HANDLER 'NEXT-BOOT-LINE)
     (PARSEOUT (PROGN (|PARSE-Expression|) (POP-STACK-1))))
    (DECLARE (SPECIAL BOOT-LINE-STACK $BOOT $SPAD XTOKENREADER LINE-HANDLER))
    (DEF-RENAME (|new2OldLisp| PARSEOUT))))

(DEFUN |string2SpadTree| (LINE)
  (DECLARE (SPECIAL LINE))
  (if (and (> (LENGTH LINE) 0) (EQ (CHAR LINE 0) #\) ))
    (|processSynonyms|))
  (ioclear)
  (LET* ((BOOT-LINE-STACK (LIST (CONS 1 LINE)))
     ($BOOT NIL)
     ($SPAD T)
     (XTOKENREADER 'GET-BOOT-TOKEN)
     (LINE-HANDLER 'NEXT-BOOT-LINE)
     (PARSEOUT (PROG2 (|PARSE-NewExpr|) (POP-STACK-1))))
    (DECLARE (SPECIAL BOOT-LINE-STACK $BOOT $SPAD XTOKENREADER LINE-HANDLER))
    PARSEOUT))

(defun |processSynonyms| () nil) ;;dummy def for depsys, redefined later


;; the following are for conditional reading
(setq |$opSysName| '"shell")
#+:CCL (defun machine-type () "unknown")
(setq |$machineType| (machine-type))
; spad-clear-input patches around fact that akcl clear-input leaves newlines chars
(defun spad-clear-input (st) (clear-input st) (if (listen st) (read-char st)))

#|
We need a way of distinguishing different versions of the system.
There used to be a way to touch the src/timestamp file whenever
you checked in a change to the change control subsystem. 
During make PART=interp (the default for make) we set timestamp
to the filename of this timestamp file. This function converts it
to a luser readable string and sets the *yearweek* variable.

The result of this function is a string that is printed as a banner 
when Axiom starts. The actual printing is done by the function
[[spadStartUpMsgs]] in [[src/interp/msgdb.boot]]. It uses a 
format string from the file [[src/doc/msgs/s2-us.msgs]].
|#
(defun yearweek ()
 "set *yearweek* to the current time string for the version banner"
  (declare (special timestamp) (special *yearweek*))
  (if (and (boundp 'timestamp) (probe-file timestamp))
      (let (sec min hour date month year day dayvec monvec)
        (setq dayvec '("Monday" "Tuesday" "Wednesday" "Thursday"
                       "Friday" "Saturday" "Sunday"))
        (setq monvec '("January" "February" "March" "April" "May" "June"
                       "July" "August" "September" "October" "November"
                       "December"))
        (multiple-value-setq (sec min hour date month year day)
                             (decode-universal-time
                              (file-write-date timestamp)))
        (setq *yearweek*
          (copy-seq
              (format nil "~a ~a ~d, ~d at ~2,'0d:~2,'0d:~2,'0d "
                      (elt dayvec day)
                      (elt monvec (1- month)) date year hour min sec))))
      (setq *yearweek* "no timestamp")))

(defun sourcepath (f)
 "find the sourcefile in the system directories"
 (let (axiom algebra)
  (setq axiom (|getEnv| "AXIOM"))
  (setq algebra (concatenate 'string axiom "/../../src/algebra/" f ".spad"))
  (cond
   ((probe-file algebra) algebra)
   ('else nil))))

(defun srcabbrevs (sourcefile)
 "read spad source files and return the constructor names and abbrevs"
 (let (expr point mark names longnames)
  (catch 'done
   (with-open-file (in sourcefile)
    (loop
     (setq expr (read-line in nil 'done))
     (when (eq expr 'done) (throw 'done nil))
     (when (and (> (length expr) 4) (string= ")abb" (subseq expr 0 4)))
      (setq expr (string-right-trim '(#\space #\tab) expr))
      (setq point (position #\space expr :from-end t :test #'char=))
      (push (subseq expr (1+ point)) longnames)
      (setq expr (string-right-trim '(#\space #\tab)
                       (subseq expr 0 point)))
      (setq mark (position #\space expr  :from-end t))
      (push (subseq expr (1+ mark)) names)))))
  (values longnames names)))


(in-package "BOOT")

(defun |tr| (fn)
  (|oldCompilerAutoloadOnceTrigger|)
  (|browserAutoloadOnceTrigger|)
  (|spad2AsTranslatorAutoloadOnceTrigger|)
  (|convertSpadFile| fn) )

#|
Make will not compare dates across directories.
Rather than copy all of the code.lsp files to the MNT directory
we run this function to compile the files that are out of date
this function assumes that the shell variables INT and MNT are set.

Also of note: on the rt some files (those in the nooptimize list)
need to be compiled without optimize due to compiler bugs
|#
(defun makelib (mid out stype btype)
 "iterate over the NRLIBs, compiling ones that are out of date.
  mid is the directory containing code.lsp
  out is the directory containing code.o"
 (let (libs lspdate odate nooptimize (alphabet #\space))
#+(and :akcl :rt)
  (setq nooptimize '("FFCAT-.NRLIB" "CHVAR.NRLIB" "PFO.NRLIB" "SUP.NRLIB"
                     "INTG0.NRLIB" "FSPRMELT.NRLIB" "VECTOR.NRLIB"
                     "EUCDOM-.NRLIB"))
  (if (and mid out)
   (format t "doing directory on ~s...~%" (concatenate 'string mid "/*"))
   (error "makelib:MID=~a OUT=~a~% these are not set properly~%" mid out))
#+:akcl (compiler::emit-fn nil)
#+:akcl (si::chdir mid)
#-:akcl (vmlisp::obey (concatenate 'string "cd " mid))
  (setq libs (directory "*.NRLIB"))
  (unless libs
   (format t "makelib:directory of ~a returned NIL~%" mid)
   (bye -1))
  (princ "checking ")
  (dolist (lib libs)
   (unless (char= (schar (pathname-name lib) 0) alphabet)
    (setq alphabet (schar (pathname-name lib) 0))
    (princ alphabet)
    (finish-output))
   (let (dotlsp doto mntlib intkaf mntkaf intkafdate mntkafdate)
    (setq dotlsp
      (concatenate 'string mid "/" (file-namestring lib) "/code." stype))
    (setq doto
      (concatenate 'string out "/" (pathname-name lib) ".NRLIB/code." btype))
    (setq mntlib
      (concatenate 'string out "/" (pathname-name lib) ".NRLIB"))
    (setq intkaf
      (concatenate 'string mid "/" (file-namestring lib) "/index.KAF*"))
    (setq mntkaf
      (concatenate 'string out "/" (pathname-name lib) ".NRLIB/index.KAF*"))
    (unless (probe-file mntlib)
     (format t "creating directory ~a~%" mntlib)
     (vmlisp::obey (concatenate 'string "cp -pr " (namestring lib) " " out))
     (when (probe-file (concatenate 'string mntlib "/code." stype))
      (delete-file  (concatenate 'string mntlib "/code." stype))))
    (setq intkafdate (and (probe-file intkaf) (file-write-date intkaf)))
    (setq mntkafdate (and (probe-file mntkaf) (file-write-date mntkaf)))
    (when intkafdate
     (unless (and mntkafdate (> mntkafdate intkafdate))
      (format t "~&copying ~s to ~s" intkaf mntkaf)
      (vmlisp::obey
       (concatenate 'string "cp " 
         (namestring intkaf) " " (namestring mntkaf)))))
    (setq lspdate (and (probe-file dotlsp) (file-write-date dotlsp)))
    (setq odate (and (probe-file doto) (file-write-date doto)))
    (when lspdate
     (unless (and odate (> odate lspdate))
#+(and :akcl :rt)
      (if (member (file-namestring lib) nooptimize :test #'string=)
       (setq compiler::*speed* 0)
       (setq compiler::*speed* 3))
      (compile-lib-file dotlsp :output-file doto)))))))

#|
Make will not compare dates across directories.
In particular, it cannot compare the algebra files because there
is a one-to-many correspondence. This function will walk over
all of the algebra NRLIB files and find all of the spad files
that are out of date and need to be recompiled. This function
creates a file "/tmp/compile.input" to be used later in the
makefile.

Note that the file /tmp/compile.input is not currently used
as algebra source recompiles are not necessarily something
we want done automatically. Nevertheless, in the quest for
quality we check anyway.
|#
(defun makespad (src mid stype)
 "iterate over the spad files, compiling ones that are out of date.
  src is the directory containing .spad
  mid is the directory containing code.lsp
  out is the directory containing code.o"
 (let (mntlibs spadwork (alphabet #\space))
  (labels (
   (findsrc (mid libname)
    "return a string name of the source file given the library file
     name (eg PI) as a string"
    (let (kaffile index alist)
     (setq kaffile 
      (concatenate 'string mid "/" libname ".NRLIB/index.KAF*"))
     (with-open-file (kaf kaffile)
      (setq index (read kaf))
      (file-position kaf index)
      (setq alist (read kaf))
     (setq index (third (assoc "sourceFile" alist :test #'string=)))
      (file-position kaf index)
     (pathname-name (pathname (read kaf index)))))))
  (format t "makespad:src=~s mid=~s stype=~s~%" src mid stype)
  (if (and src mid)
   (format t "doing directory on ~s...~%" (concatenate 'string src "/*"))
   (error "makespad:SRC=~a MID=~a not set properly~%" src mid))
#+:akcl (si::chdir mid)
#-:akcl (vmlisp::obey (concatenate 'string "cd " mid))
  (setq mntlibs (directory "*.NRLIB"))
  (unless mntlibs
   (format t "makespad:directory of ~a returned NIL~%" src)
   (bye 1))
  (princ "checking ")
  (dolist (lib mntlibs)
   (unless (char= (schar (pathname-name lib) 0) alphabet)
    (setq alphabet (schar (pathname-name lib) 0))
    (princ alphabet)
    (finish-output))
   (let (spad spaddate lsp lspdate)
    (setq spad
      (concatenate 'string src "/" (findsrc mid (pathname-name lib)) ".spad"))
    (setq spaddate
      (and (probe-file spad) (file-write-date spad)))
    (setq lsp
      (concatenate 'string mid "/" (pathname-name lib) ".NRLIB/code." stype))
    (setq lspdate
      (and (probe-file lsp) (file-write-date lsp)))
    (cond
     ((and spaddate lspdate (<= spaddate lspdate)))
     ((and spaddate lspdate (> spaddate lspdate))
       (setq spadwork (adjoin spad spadwork :test #'string=)))
     ((and spaddate (not lspdate)) 
       (setq spadwork (adjoin spad spadwork :test #'string=)))
     ((and (not spaddate) lspdate)
       (format t "makespad:missing spad file ~a for lisp file ~a~%" spad lsp))
     ((and (not spaddate) (not lspdate))
       (format t "makespad:NRLIB ~a exist but is spad ~a and lsp ~a don't~%"
         lib spad lsp)))))
   (with-open-file (tmp "/tmp/compile.input" :direction :output)
    (dolist (spad spadwork)
     (format t "~a is out of date~%" spad)
     (format tmp ")co ~a~%" spad))))))

;; We need to ensure that the INTERP.EXPOSED list, which is a list
;; of the exposed constructors, is consistent with the actual libraries.
(defun libcheck (int)
 "check that INTERP.EXPOSED and NRLIBs are consistent"
 (let (interp nrlibs)
 (labels (
  (CONSTRUCTORNAME (nrlib)
   "find the long name of a constructor given an abbreviation string"
   (let (file sourcefile name)
    (setq file (findsrc nrlib))
    (setq sourcefile
      (concatenate 'string int "/" file ".spad"))
    (when (and file (probe-file sourcefile))
     (setq name (searchsource sourcefile nrlib)))))
  (NOCAT (longnames)
   "remove the categories from the list of long names"
   (remove-if 
    #'(lambda (x) 
       (let ((c (schar x (1- (length x)))))
        (or (char= c #\&) (char= c #\-)))) longnames))
  (FINDSRC (libname)
   "return a string name of the source file given the library file
    name (eg PI) as a string"
   (let (kaffile index alist result)
    (setq kaffile 
     (concatenate 'string int "/" libname ".NRLIB/index.KAF*"))
    (if (probe-file kaffile)
     (with-open-file (kaf kaffile)
      (setq index (read kaf))
      (file-position kaf index)
      (setq alist (read kaf))
     (setq index (third (assoc "sourceFile" alist :test #'string=)))
      (file-position kaf index)
     (setq result (pathname-name (pathname (read kaf index))))))
     (format t "~a does not exist~%" kaffile)
    result))
  (READINTERP ()
   "read INTERP.EXPOSED and return a sorted abbreviation list"
   (let (expr names longnames)
    (with-open-file (in (concatenate 'string int "/INTERP.EXPOSED"))
     (catch 'eof
      (loop
       (setq expr (read-line in nil 'eof))
       (when (eq expr 'eof) (throw 'eof nil))
       (when
        (and
         (> (length expr) 58)
         (char= (schar expr 0) #\space) 
         (not (char= (schar expr 8) #\space)))
         (push (string-trim '(#\space) (subseq expr 8 57)) longnames)
         (push (string-right-trim '(#\space) (subseq expr 58)) names)))))
    (setq longnames (sort longnames #'string<))
    (setq names (sort names #'string<))
    (values names longnames)))
  (READLIBS (algebra)
   "read the NRLIB directory and return a sorted abbreviation list"
   (let (libs nrlibs)
#+:akcl (si::chdir algebra)
#-:akcl (vmlisp::obey (concatenate 'string "cd " algebra))
    (setq nrlibs (directory "*.NRLIB"))
    (unless nrlibs
     (error "libcheck: (directory ~s) returned NIL~%" 
         (concatenate 'string algebra "/*.NRLIB")))
    (dolist (lib nrlibs)
     (push (pathname-name lib) libs))
    (sort libs #'string<)))
  (SEARCHSOURCE (sourcefile nrlib)
   "search a sourcefile for the long constructor name of the nrlib string"
   (let (in expr start)
    (setq nrlib (concatenate 'string " " nrlib " "))
    (catch 'done
     (with-open-file (in sourcefile)
      (loop
       (setq expr (read-line in nil 'done))
       (when (eq expr 'done) (throw 'done nil))
       (when (and (> (length expr) 4)
                (string= ")abb" (subseq expr 0 4))
                (search nrlib expr :test #'string=)
                (setq start (position #\space expr :from-end t :test #'char=)))
        (throw 'done (string-trim '(#\space) (subseq expr start)))))))))
  (SRCABBREVS (sourcefile)
   (let (in expr start end names longnames)
    (catch 'done
     (with-open-file (in sourcefile)
      (loop
       (setq expr (read-line in nil 'done))
       (when (eq expr 'done) (throw 'done nil))
       (when (and (> (length expr) 4)
             (string= ")abb" (subseq expr 0 4)))
        (setq point (position #\space expr :from-end t :test #'char=))
        (push (string-trim '(#\space) (subseq expr point)) longnames)
        (setq mark
         (position #\space 
          (string-right-trim '(#\space)
           (subseq expr 0 (1- point))) :from-end t))
        (push (string-trim '(#\space) (subseq expr mark point)) names)))))
    (values names longnames)))
  (SRCSCAN ()
   (let (longnames names)
#+:gcl (system::chdir int)
#-:gcl (vmlisp::obey (concatenate 'string "cd " int))
    (setq spads (directory "*.spad"))
    (dolist (spad spads)
     (multiple-value-setq (short long) (srcabbrevs spad))
     (setq names (nconc names short))
     (setq longnames (nconc longnames long)))
    (setq names (sort names #'string<))
    (setq longnames (sort longnames #'string<))
    (values names longnames))))
  (multiple-value-setq (abbrevs constructors) (readinterp))
  (setq nrlibs (readlibs int))
  (dolist (lib (set-difference nrlibs abbrevs :test #'string=))
    (format t "libcheck:~a/~a.NRLIB is not in INTERP.EXPOSED~%" int lib))
  (dolist (expose (set-difference abbrevs nrlibs :test #'string=))
    (format t "libcheck:~a is in INTERP.EXPOSED with no NRLIB~%" expose))
  (multiple-value-setq (srcabbrevs srcconstructors) (srcscan))
  (setq abbrevs (nocat abbrevs))
  (setq constructors (nocat constructors))
  (dolist (item (set-difference srcabbrevs abbrevs :test #'string=))
    (format t "libcheck:~a is in ~a but not in INTERP.EXPOSED~%" item
     (findsrc item)))
  (dolist (item (set-difference abbrevs srcabbrevs :test #'string=))
    (format t "libcheck:~a is in INTERP.EXPOSED but has no spad sourcfile~%"
      item))
  (dolist (item (set-difference srcconstructors constructors :test #'string=))
    (format t "libcheck:~a is not in INTERP.EXPOSED~%" item))
  (dolist (item (set-difference constructors srcconstructors :test #'string=))
    (format t "libcheck:~a has no spad source file~%" item)))))


;;; moved from bookvol5

(defvar |$historyDirectory| 'A        "vm/370 filename disk component")
(defvar |$HiFiAccess| t               "t means turn on history mechanism")

(defvar |$reportUndo| nil "t means we report the steps undo takes")
(defvar $openServerIfTrue t "t means try starting an open server")
(defparameter $SpadServerName "/tmp/.d" "the name of the spad server socket")
(defvar |$SpadServer| nil "t means Scratchpad acts as a remote server")


#-:CCL
(defun |loadExposureGroupData| ()
 (cond
  ((load "./exposed" :verbose nil :if-does-not-exist nil)
    '|done|)
  ((load (concat (BOOT::|getEnv| "AXIOM") "/algebra/exposed")
     :verbose nil :if-does-not-exist nil)
   '|done|)
  (t '|failed|) ))

#+:CCL
(defun |loadExposureGroupData| ()
 (cond
  ((load "./exposed.lsp" :verbose NIL :if-does-not-exist NIL) '|done|)
  ((load (concat (BOOT::|getEnv| "AXIOM") "/../../src/algebra/exposed.lsp") 
    :verbose nil :if-does-not-exist nil) '|done|)
  (t nil) ))

(defun axiom-restart ()
#+:akcl
  (init-memory-config :cons 500 :fixnum 200 :symbol 500 :package 8
    :array 400 :string 500 :cfun 100 :cpages 3000 :rpages 1000 :hole 2000)
#+:akcl (setq compiler::*compile-verbose* nil)
#+:akcl (setq compiler::*suppress-compiler-warnings* t)
#+:akcl (setq compiler::*suppress-compiler-notes* t)
#-:CCL
  (in-package "BOOT")
#+:CCL
  (setq *package* (find-package "BOOT"))
#+:CCL (setpchar "") ;; Turn off CCL read prompts
  (initroot)
#+:akcl (system:gbc-time 0)
#+:akcl
  (when (and $openServerIfTrue (fboundp '|openServer|))
   (prog (os)
    (setq os (|openServer| $SpadServerName))
    (if (zerop os) 
     (progn 
      (setq $openServerIfTrue nil)
      #+:gcl
      (if (fboundp 'si::readline-off)
          (si::readline-off))
      (setq |$SpadServer| t)))))
#+:sbcl
(let* ((ax-dir (|getEnv| "AXIOM"))
       (spad-lib (concatenate 'string ax-dir "/lib/libspad.so"))
       (sock-fasl (concatenate 'string ax-dir "/autoload/ffi-func.fasl")))
    (format t "Checking for foreign routines~%")
    (format t "AXIOM=~S~%" ax-dir)
    (format t "spad-lib=~S~%" spad-lib)
    (format t "sock-fasl=~S~%" sock-fasl)
    (when (and (axiom-probe-file spad-lib)
               (axiom-probe-file sock-fasl))
        (format t "foreign routines found~%")
        (sb-alien::load-shared-object spad-lib)
        (load sock-fasl)
        (let ((os (|openServer| $SpadServerName)))
             (format t "openServer result ~S~%" os)
             (if (zerop os)
                 (progn
                      (setq $openServerIfTrue nil)
                      (setq |$SpadServer| t))))))
#+:clisp
(let* ((ax-dir (|getEnv| "AXIOM"))
       (spad-lib (concatenate 'string ax-dir "/lib/libspad.so"))
       (sock-fasl (concatenate 'string ax-dir "/autoload/ffi-func2.lisp")))
    (format t "Checking for foreign routines~%")
    (format t "AXIOM=~S~%" ax-dir)
    (format t "spad-lib=~S~%" spad-lib)
    (format t "sock-fasl=~S~%" sock-fasl)
    (when (and (axiom-probe-file spad-lib)
               (axiom-probe-file sock-fasl))
        (defvar *libspad_pathname*)
        (setf *libspad_pathname* spad-lib)
        (format t "foreign routines found~%")
        (load sock-fasl)
        (let ((os (|openServer| $SpadServerName)))
             (format t "openServer result ~S~%" os)
             (if (zerop os)
                 (progn
                      (setq $openServerIfTrue nil)
                      (setq |$SpadServer| t))))))
;; We do the following test at runtime to allow us to use the same images
;; with Saturn and Sman.  MCD 30-11-95
#+:CCL
  (when 
     (and (memq :unix *features*) $openServerIfTrue (fboundp '|openServer|))
   (prog (os)
    (setq os (|openServer| $SpadServerName))
    (if (zerop os) 
     (progn 
      (setq $openServerIfTrue nil) 
      (setq |$SpadServer| t)))))
  (setq |$IOindex| 1)
  (setq |$InteractiveFrame| (|makeInitialModemapFrame|))
  (setq |$printLoadMsgs| '|on|)
  (|loadExposureGroupData|)
  (|statisticsInitialization|)
  (|initHist|)
  (|initializeInterpreterFrameRing|)

  (when |$displayStartMsgs| 
   (|spadStartUpMsgs|))
  (setq |$currentLine| nil)
  (restart0)
  (|readSpadProfileIfThere|)
  #+(or :GCL :CCL)
  (|spad|)
  #-(or :GCL :CCL)
  (handler-bind ((error #'spad-system-error-handler))
     (|spad|))
)


(defun spad-save (save-file do-restart)
  (setq |$SpadServer| nil)
  (setq $openServerIfTrue t)
  #-:openmcl
  (AXIOM-LISP::save-core-restart save-file
         (if do-restart #'boot::axiom-restart nil))
  #+:openmcl
  (AXIOM-LISP::save-core-restart save-file
         (if do-restart "BOOT::axiom-restart" nil))
)

(defun |statisticsInitialization| () 
 "initialize the garbage collection timer"
 #+:akcl (system:gbc-time 0)
 nil)



