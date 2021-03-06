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


(in-package "BOOT")
;;patches for now

;; browser stuff:
(defvar |$standard| 't)
(defvar |$saturn| nil)

(defun CATCHALL (a &rest b) a) ;; not correct but ok for now
(defvar |$demoFlag| nil)

(define-function '|construct| #'list) ;; NEEDED , SPAD-COMPILER generated Lisp code

(defvar |Undef| (function |Undef|)) ;needed in NewbFVectorCopy
(define-function '|spadHash| #'sxhash)

(defun |mkAutoLoad| (fn cname)
   (function (lambda (&rest args)
                 #+:sbcl
                 (handler-bind ((style-warning #'muffle-warning))
                     (|autoLoad| fn cname))
                 #-:sbcl
                 (|autoLoad| fn cname)
                 (apply cname args))))

(setq |$printTimeIfTrue| nil)


(defun clear-highlight ()
  (let ((|$displaySetValue| nil))
    (declare (special |$displaySetValue| |$saveHighlight| |$saveSpecialchars|))
    (setq |$saveHighlight| |$highlightAllowed|
          |$highlightAllowed| nil)
    (setq |$saveSpecialchars| |$specialCharacters|)
    (|setOutputCharacters| '(|plain|))))

(defun reset-highlight ()
  (setq |$highlightAllowed| |$saveHighlight|)
  (setq |$specialCharacters| |$saveSpecialchars|))

(defun |spool| (filename)
  (if (and filename (symbolp (car filename)))
      (setf (car filename) (symbol-name (car filename))))
  (cond ((null filename)
         (dribble) (TERPRI)
         (reset-highlight))
        ((probe-file (car filename))
         (error (format nil "file ~a already exists" (car filename))))
        (t (dribble (car filename))
           (TERPRI)
           (clear-highlight))
    ))

(defun |cd| (args)
    (let ((dname (if (null args)
                     (trim-directory-name (namestring (user-homedir-pathname)))
                     (car args))))
         (if (symbolp dname)
             (setf dname (symbol-name dname)))
         (chdir dname))
    (|sayKeyedMsg| 'S2IZ0070 (list (get-current-directory))))

(defun toplevel (&rest foo) (throw '|top_level| '|restart|))

(DEFUN BUMPCOMPERRORCOUNT () ())

(setq |nullstream| '|nullstream|)
(setq |nonnullstream| '|nonnullstream|)
(setq *print-escape* nil) ;; so stringimage doesn't escape idents?

;;; FIXME: do we need this?
#+(and :GCL :IEEE-FLOATING-POINT)
 (setq system:*print-nans* T)

(defun /RF (&aux (Echo-Meta 'T))
  (declare (special Echo-Meta))
  (/RF-1))
(defun /RQ (&aux (Echo-Meta nil))
  (declare (special Echo-Meta))
  (/RF-1))
(defun |/RQ,LIB| (&aux (Echo-Meta nil) ($LISPLIB T))
  (declare (special Echo-Meta $LISPLIB))
  (/RF-1))

(defun /RF-1 ()
  (let* ((input-file (vmlisp::make-input-filename /EDITFILE))
     (lfile ())
     (type (pathname-type input-file)))
    (cond
     ((string= type "boot")
      (boot input-file
         (setq lfile (make-pathname :type "lisp"
                           :defaults input-file)))
      (load lfile))
     ((string= type "lisp") (load input-file))
     ((string= type "bbin") (load input-file))
     ((string= type "input")
      (|ncINTERPFILE| input-file Echo-Meta))
     (t (|spadCompile| input-file)))))

(setq |$algebraOutputStream|
   (setq |$fortranOutputStream|
      (setq |$texOutputStream|
          (setq |$formulaOutputStream|
              (make-synonym-stream '*standard-output*)))))

;; non-interactive restarts...
(defun restart0 ()
  (|compressOpen|);; set up the compression tables
  (|interpOpen|);; open up the interpreter database
  (|operationOpen|);; all of the operations known to the system
  (|categoryOpen|);; answer hasCategory question
  (|browseOpen|)
  (|makeConstructorsAutoLoad|)
  (let ((asharprootlib (strconc (|getEnv| "AXIOM") "/aldor/lib/")))
    (set-file-getter (strconc asharprootlib "runtime"))
    (set-file-getter (strconc asharprootlib "lang"))
    (set-file-getter (strconc asharprootlib "attrib"))
    (set-file-getter (strconc asharprootlib "axlit"))
    (set-file-getter (strconc asharprootlib "minimach"))
    (set-file-getter (strconc asharprootlib "axextend")))
)

(defun whocalled (n) nil) ;; no way to look n frames up the stack

(defun |eval|(x)
    #-:GCL
    (handler-bind ((warning #'muffle-warning)
                   #+:sbcl (sb-ext::compiler-note #'muffle-warning))
            (eval  x))
    #+:GCL
    (eval  x)
)

;;--------------------> NEW DEFINITION (see cattable.boot.pamphlet)
(defun |compressHashTable| (ht) ht)
(defun GETZEROVEC (n) (MAKE-ARRAY n :initial-element 0))

(setq |$localVars| ())  ;checked by isType

;; following code is to mimic def of MAP in NEWSPAD LISP
;; i.e. MAP in boot package is a self evaluating form
(defmacro map (&rest args) `'(map ,@args))


;; following 3 are replacements for g-util.boot
(define-function '|isLowerCaseLetter| #'LOWER-CASE-P)


(defvar *msghash* nil "hash table keyed by msg number")

(defun cacheKeyedMsg (file)
  (let ((line "") (msg "") key)
   (with-open-file (in file)
    (catch 'done
     (loop
      (setq line (read-line in nil nil))
      (cond
       ((null line)
         (when key
          (setf (gethash key *msghash*) msg))
          (throw 'done nil))
       ((= (length line) 0))
       ((char= (schar line 0) #\S)
         (when key
          (setf (gethash key *msghash*) msg))
         (setq key (intern line "BOOT"))
         (setq msg ""))
       ('else
        (setq msg (concatenate 'string msg line)))))))))

(defun |fetchKeyedMsg| (key)
 (setq key (|object2Identifier| key))
 (unless *msghash*
  (setq *msghash* (make-hash-table))
  (cacheKeyedMsg |$defaultMsgDatabaseName|))
 (gethash key *msghash*))

(setq identity #'identity) ;to make LispVM code for handling constants to work

(|initializeTimedNames| |$interpreterTimedNames| |$interpreterTimedClasses|)

;;; Accesed from HyperDoc
(defun |setViewportProcess| ()
  (setq |$ViewportProcessToWatch|
     (stringimage (CDR
         (|processInteractive|  '(|key| (|%%| -2)) NIL) ))))

;;; Accesed from HyperDoc
(defun |waitForViewport| ()
  (progn
   (do ()
       ((not (zerop (obey
        (concat
         "ps "
         |$ViewportProcessToWatch|
         " > /dev/null")))))
       ())
   (|sockSendInt| |$MenuServer| 1)
   (|setIOindex| (- |$IOindex| 3))
  )
)


(defun |makeVector| (els type)
 (make-array (length els) :element-type (or type t) :initial-contents els))


(defun |makeList| (size el) (make-list size :initial-element el) )

#+:GCL
(defun print-xdr-stream (x y z) (format y "XDR:~A" (xdr-stream-name x)))
#+:GCL
(defstruct (xdr-stream
                (:print-function  print-xdr-stream))
           "A structure to hold XDR streams. The stream is printed out."
           (handle ) ;; this is what is used for xdr-open xdr-read xdr-write
           (name ))  ;; this is used for printing
#+(and :GCL (not (or :dos :win32)))
(defun |xdrOpen| (str dir) (make-xdr-stream :handle (system:xdr-open str) :name str))
#+(and :GCL (or :dos :win32))
(defun |xdrOpen| (str dir) (format t "xdrOpen called"))

#+(and :GCL (not (or :dos :win32)))
(defun |xdrRead| (xstr r) (system:xdr-read (xdr-stream-handle xstr) r) )
#+(and :GCL (or :dos :win32))
(defun |xdrRead| (str) (format t "xdrRead called"))

#+(and :GCL (not (or :dos :win32)))
(defun |xdrWrite| (xstr d) (system:xdr-write (xdr-stream-handle xstr) d) )
#+(and :GCL (or :dos :win32))
(defun |xdrWrite| (str) (format t "xdrWrite called"))

;; here is a test for XDR
;; (setq *print-array* T)
;; (setq foo (open "xdrtest" :direction :output))
;; (setq xfoo (|xdrOpen| foo))
;; (|xdrWrite| xfoo "hello: This contains an integer, a float and a float array")
;; (|xdrWrite| xfoo 42)
;; (|xdrWrite| xfoo 3.14159)
;; (|xdrWrite| xfoo (make-array 10 :element-type 'double-float :initial-element 2.78111D12))
;; (close foo)
;; (setq foo (open "xdrtest" :direction :input))
;; (setq xfoo (|xdrOpen| foo))
;; (|xdrRead| xfoo "")
;; (|xdrRead| xfoo 0)
;; (|xdrRead| xfoo 0.0)
;; (|xdrRead| xfoo (make-array 10 :element-type 'double-float ))
;; (setq *print-array* NIL)

;; clearParserMacro has problems as boot code (package notation)
;; defined here in Lisp

(setq /MAJOR-VERSION 2)
(setq echo-meta nil)
(defun /versioncheck (n) (unless (= n /MAJOR-VERSION) (throw 'versioncheck -1)))
