;;; This file contains portablity and support routines which abstract away
;;; differences between Lisp dialects.

(in-package "FRICAS-LISP")
#+:cmu
(progn
     (defvar *saved-terminal-io* *terminal-io*)
     (setf *terminal-io* (make-two-way-stream *standard-input*
                                             *standard-output*))
 )

#+:sbcl
(progn
     (defvar *saved-terminal-io* *terminal-io*)
     (setf *terminal-io* (make-two-way-stream *standard-input*
                                             *standard-output*))
     (setf sb-ext:*evaluator-mode* :interpret)
 )

#-:cmu
(defun set-initial-parameters()
    (setf *print-circle* t)
    (setf *compile-print* nil)
    (setf *read-default-float-format* 'double-float))

#+:cmu
(defun set-initial-parameters()
  (setq debug:*debug-print-length* 1024)
  (setq debug:*debug-print-level* 1024)
  (setf *read-default-float-format* 'double-float))

#-:sbcl
(eval-when (:execute :load-toplevel)
    (set-initial-parameters))

#+:clisp
(eval-when (:execute :compile-toplevel :load-toplevel)
    ;;; clisp wants to search whole "~/lisp" subtree to find a source
    ;;; file, which is insane.  Below we disable this behaviour.
    (setf custom:*load-paths* '(#P"./"))
    ;;; We want ANSI compliance
    (setf custom:*ansi* t)
    ;;; We have our own loading messages
    (setf *LOAD-VERBOSE* nil))

;;
#+:openmcl
(progn

(defclass fricas-application (ccl::application) ())

(defvar *my-toplevel-function* nil)

(defvar *ccl-default-directory* nil)

(defmethod ccl::toplevel-function ((app fricas-application) init-file)
    (declare (ignore init-file))
        (call-next-method) ; this is critical, but shouldn't be.
        (funcall *my-toplevel-function*)
        (let ((ap (make-instance 'ccl::lisp-development-system)))
            (ccl::toplevel-function ap init-file)))

)

;; Save current image on disk as executable and quit.
(defun save-core-restart (core-image restart)
#+:GCL
  (progn
     (if restart
          (setq system::*top-level-hook* restart))
     (system::save-system core-image))
#+:allegro
  (if restart
   (excl::dumplisp :name core-image :restart-function restart)
   (excl::dumplisp :name core-image))
#+Lucid
  (if restart
   (sys::disksave core-image :restart-function restart)
   (sys::disksave core-image))
#+:cmu
  (let* ((restart-fun 
               (if restart
                   restart
                   #'(lambda () nil)))
         (top-fun #'(lambda ()
                       (set-initial-parameters)
                       (funcall restart-fun)
                       (lisp::%top-level))))
        (ext::save-lisp
	 (unix::unix-maybe-prepend-current-directory core-image)
	 :init-function top-fun :executable t :print-herald nil))
#+:sbcl
  (let* ((restart-fun 
               (if restart
                   restart
                   #'(lambda () nil)))
         (top-fun #'(lambda ()
                       (set-initial-parameters)
                       (funcall restart-fun)
                       (sb-impl::toplevel-repl nil)))
         (save-options-keyword (find-symbol "SAVE-RUNTIME-OPTIONS" "KEYWORD"))
         (save-options-arg
             (if save-options-keyword (list save-options-keyword t) nil))
        )
        (apply #'sb-ext::save-lisp-and-die
              (append `(,core-image :toplevel ,top-fun :executable t)
                      save-options-arg))
  )
#+:clisp
  (if restart
     (ext::saveinitmem core-image :INIT-FUNCTION restart :QUIET t
         :NORC t :executable t)
     (ext::saveinitmem core-image :executable t :NORC t :QUIET t))
#+:openmcl
  (let* ((ccl-dir (or *ccl-default-directory*
                 (|getEnv| "CCL_DEFAULT_DIRECTORY"))))
        (setf *ccl-default-directory* ccl-dir)
        (if restart
            (progn
                (setf *my-toplevel-function* restart)
                (CCL::save-application core-image
                                       :PREPEND-KERNEL t
                                       :application-class 'fricas-application))
            (CCL::save-application core-image :PREPEND-KERNEL t))
        (quit))
#+:lispworks
  (progn
    ; LispWorks by default loads a siteinit and an init file.
    ; It complains when saving an image, if init files are already loaded.
    ; LispWorks can be started with  lispworks -siteinit - -init -  and
    ; then doesn't load these init files. That would mean changing
    ; the FriCAS scripts. Here we let LispWorks load the init files,
    ; but use the undocumented system variable preventing LispWorks
    ; from presenting an error.
    (setf SYSTEM::*COMPLAIN-ABOUT-INIT-FILE-LOADED* nil)
    (if restart
        (hcl:save-image core-image :restart-function restart)
      (hcl:save-image core-image)))
#|
  (let ((ccl-dir (|getEnv| "CCL_DEFAULT_DIRECTORY"))
        (core-fname (concatenate 'string core-image ".image"))
        (eval-arg (if restart 
                      (format nil " --eval '(~A)'" restart)
                      ""))
        core-path exe-path)
        ;;; truename works only on existing files, so we
        ;;; create one just to get absolute path
        (with-open-file (ims core-fname 
                          :direction :output :if-exists :supersede)
            (declare (ignore ims))
            (setf core-path (namestring (truename core-fname))))
        (delete-file core-path)
        (with-open-file (ims core-image 
                        :direction :output :if-exists :supersede)
                (setf exe-path (namestring (truename core-image)))
                (format ims "#!/bin/sh~2%")
                (format ims "CCL_DEFAULT_DIRECTORY=~A~%" ccl-dir)
                (format ims "export CCL_DEFAULT_DIRECTORY~%")
                (format ims "exec ~A/~A -I ~A~A~%"
                            ccl-dir (ccl::standard-kernel-name)
                            core-path eval-arg))
        (ccl::run-program "chmod" (list "a+x" exe-path))
        #|
        ;;; We would prefer this version, but due to openmcl bug
        ;;; it does not work
        (if restart
          (ccl::save-application core-path :toplevel-function restart)
          (ccl::save-application core-path))
        |#
        (ccl::save-application core-path)
        )
  |#
)

(defun save-core (core-image)
     (save-core-restart core-image nil))

;; Load Lisp files (any LOADable file), given as a list of file names.
;; The file names are strings, as approrpriate for LOAD.
(defun load-lisp-files (files)
  (mapcar #'(lambda (f) (load f)) files))

;;; How to exit Lisp process
#+:GCL
(defun exit-with-status (s) (lisp::quit s))

#+:cmu
(defun exit-with-status (s)
    (setf *terminal-io* *saved-terminal-io*)
    (unix:unix-exit s))

#+:sbcl
(defun exit-with-status (s)
    (setf *terminal-io* *saved-terminal-io*)
    (sb-ext::quit :UNIX-STATUS s))

#+:clisp
(defun exit-with-status (s) (ext::quit s))

#+:openmcl
(defun exit-with-status (s) (ccl::quit s))

#+:ecl
(defun exit-with-status (s)
    (SI:quit s))

#+:lispworks
(defun exit-with-status (s)
  (lispworks:quit :status s))

;;; #+:poplog
;;; (defun quit() (pop11::sysexit))

(defun quit() (exit-with-status 0))
;;; -----------------------------------------------------------------

;;; Making (linking) program

#-:ecl
(defun make-program (core-image lisp-files)
    (load-lisp-files lisp-files)
    (save-core core-image))

#+:ecl
(defun make-program (core-image lisp-files)
    (if *fricas-initial-lisp-forms*
        (c:build-program core-image
             :lisp-files (append *fricas-initial-lisp-objects* lisp-files)
             :ld-flags *fricas-extra-c-files*
             :epilogue-code *fricas-initial-lisp-forms*)
        (c:build-program core-image
             :lisp-files (append *fricas-initial-lisp-objects* lisp-files)
             :ld-flags *fricas-extra-c-files*))
    (quit))

;;; -----------------------------------------------------------------
;;; For ECL assume :unix, when :netbsd or :darwin
#+(and :ecl (or :darwin :netbsd)) (push :unix *features*)

;;; -----------------------------------------------------------------

;;; Chdir function

#+:GCL
(defun chdir (dir)
 (system::chdir dir))

#+:cmu
(defun chdir (dir)
 (let ((tdir (probe-file dir)))
  (cond
    (tdir
       (unix::unix-chdir dir) 
       (setq *default-pathname-defaults* tdir))
     (t nil))))

#+:sbcl
(eval-when (:execute :compile-toplevel :load-toplevel)
    (require :sb-posix))
#+:sbcl
(defun chdir (dir)
 (let ((tdir (probe-file dir)))
  (cond
    (tdir
       #-:win32 (sb-posix::chdir tdir) 
       (setq *default-pathname-defaults* tdir))
     (t nil))))

#+(and :clisp (or :unix :win32))
(defun chdir (dir)
 (ext::cd dir))

#+:openmcl
(defun chdir (dir)
  (ccl::%chdir dir))

#+:ecl
(defun chdir (dir)
   (SI:CHDIR (pad-directory-name dir) t))

#+:lispworks
(defun chdir (dir)
  (hcl:change-directory dir))

;;; Environment access

(defun |getEnv| (var-name)
  #+:GCL (system::getenv var-name)
  #+:cmu (cdr (ext::assq (intern var-name "KEYWORD" )  ext:*environment-list*))
  #+:sbcl (sb-ext::posix-getenv var-name)
  #+:clisp (ext::getenv var-name)
  #+:openmcl (ccl::getenv var-name)
  #+:ecl (si::getenv var-name)
  #+:lispworks (lispworks:environment-variable var-name)
  )

;;; Silent loading of files

(defun |load_quietly| (f)
    ;;; (format *error-output* "entred load_quietly ~&") 
    #-:GCL
    (handler-bind ((warning #'muffle-warning))
                  (load f))
    #+:GCL
    (load f)
    ;;; (format *error-output* "finished load_quietly ~&") 
)

;;; -------------------------------------------------------
;;;
;;; FriCAS FFI macros
;;;

(eval-when (:compile-toplevel :load-toplevel :execute)

(defvar *c-type-to-ffi*)
(defun c-type-to-ffi (c-type)
   (let ((pp (assoc c-type *c-type-to-ffi*)))
        (if pp (nth 1 pp) (break))))

)

#+:GCL
(eval-when (:compile-toplevel :load-toplevel :execute)
(setf *c-type-to-ffi* '(
    (int LISP::int)
    (c-string LISP::string)
    (double LISP::double)
))               

(defun c-args-to-gcl (arguments)
   (declare (safety 3))
   (mapcar (lambda (x) (c-type-to-ffi (nth 1 x))) arguments))

(defun gcl-foreign-call (name c-name return-type arguments)
    (let ((gcl-args (c-args-to-gcl arguments))
          (gcl-ret (c-type-to-ffi return-type)))
    `(LISP::defentry ,name ,gcl-args (,gcl-ret ,c-name))
  ))

(defmacro fricas-foreign-call (name c-name return-type &rest arguments)
    (gcl-foreign-call name c-name return-type arguments))

)

#+(and :clisp :ffi)
(eval-when (:compile-toplevel :load-toplevel :execute)

(setf *c-type-to-ffi* '(
    (int ffi:int)
    (c-string  ffi:c-string)
    (double ffi:double-float)
))

(defun c-args-to-clisp (arguments)
   (mapcar (lambda (x) (list (nth 0 x) (c-type-to-ffi (nth 1 x)))) arguments))

(defun clisp-foreign-call (name c-name return-type arguments)
    (let ((clisp-args (c-args-to-clisp arguments))
          (clisp-ret (c-type-to-ffi return-type)))
     `(eval (quote (ffi:def-call-out ,name
          ;;; (:library "./libspad.so")
          (:name ,c-name) 
          (:arguments ,@clisp-args)
          (:return-type ,clisp-ret)
          (:language :stdc))))
     ))

(defmacro fricas-foreign-call (name c-name return-type &rest arguments)
     (clisp-foreign-call name c-name return-type arguments))

)

#+:cmu
(eval-when (:compile-toplevel :load-toplevel :execute)

(setf *c-type-to-ffi* '(
    (int c-call:int)
    (c-string c-call:c-string)
    (double c-call:double)
))

(defun c-args-to-cmucl (arguments)
  (mapcar (lambda (x) (list (nth 0 x) (c-type-to-ffi (nth 1 x))))
	  arguments))

(defun cmucl-foreign-call (name c-name return-type arguments)
    (let ((cmucl-args (c-args-to-cmucl arguments))
          (cmucl-ret (c-type-to-ffi return-type)))
       `(alien:def-alien-routine (,c-name ,name) ,cmucl-ret
           ,@cmucl-args)))

(defmacro fricas-foreign-call (name c-name return-type &rest arguments)
       (cmucl-foreign-call name c-name return-type arguments))

)

#+:sbcl
(eval-when (:compile-toplevel :load-toplevel :execute)

(setf *c-type-to-ffi* '(
    (int SB-ALIEN::int)
    (c-string SB-ALIEN::c-string)
    (double SB-ALIEN::double)
))

(defun c-args-to-sbcl (arguments)
       (mapcar (lambda (x) (list (nth 0 x) (c-type-to-ffi (nth 1 x)) :in))
               arguments))

(defun sbcl-foreign-call (name c-name return-type arguments)
    (let ((sbcl-args (c-args-to-sbcl arguments))
          (sbcl-ret (c-type-to-ffi return-type)))
       `(SB-ALIEN::define-alien-routine (,c-name ,name) ,sbcl-ret
           ,@sbcl-args)))

(defmacro fricas-foreign-call (name c-name return-type &rest arguments)
       (sbcl-foreign-call name c-name return-type arguments))

)

#+:openmcl
(eval-when (:compile-toplevel :load-toplevel :execute)

(setf *c-type-to-ffi* '(
    (int :int)
    (c-string :address)
    (double :double-float)
))

(defun c-args-to-openmcl (arguments)
   (let ((strs nil) (fargs nil))
        (mapcar (lambda (x)
                         (if (eq (nth 1 x) 'c-string)
                             (let ((sym (gensym)))
                                   (push (list sym (nth 0 x)) strs)
                                   (push :address fargs)
                                   (push sym fargs))
                             (progn
                                  (push (c-type-to-ffi (nth 1 x)) fargs)
                                  (push (nth 0 x) fargs))))
                     arguments)
         (values (nreverse fargs) strs 
                 (mapcar #'car arguments))))

(defun openmcl-foreign-call (name c-name return-type arguments)
    (multiple-value-bind (fargs strs largs) (c-args-to-openmcl arguments)
        (let* ((l-ret (c-type-to-ffi return-type))
               (call-body
                 `(ccl::external-call ,c-name ,@fargs ,l-ret))
               (fun-body
                  (if strs
                     `(ccl::with-cstrs ,strs ,call-body)
                      call-body)))
               `(defun ,name ,largs ,fun-body))))
            
(defmacro fricas-foreign-call (name c-name return-type &rest arguments)
     (openmcl-foreign-call name c-name return-type arguments))

)

#+:ecl
(eval-when (:compile-toplevel :load-toplevel :execute)

(setf *c-type-to-ffi* '(
                 (int :int)
                 (c-string  :cstring )
                 (double :double)
                 ))

(defun c-args-to-ecl (arguments)
    (let ((strs nil) (fargs nil))
        (mapcar (lambda (x)
                        (if (eq (nth 1 x) 'c-string)
                            (let ((sym (gensym)))
                                (push (list sym (nth 0 x)) strs)
                                (push (list sym :cstring) fargs))
                            (push (list (nth 0 x) (c-type-to-ffi (nth 1 x)))
                                  fargs)))
                arguments)
        (values (nreverse fargs) strs)))

(defun ecl-foreign-call (name c-name return-type arguments)
    (multiple-value-bind (fargs strs) (c-args-to-ecl arguments)
        (let ((l-ret (c-type-to-ffi return-type))
               wrapper)
            (if strs
                (let* ((sym (gensym))
                       (wargs (mapcar #'car fargs))
                       (largs (mapcar #'car arguments))
                       (wrapper `(,sym ,@wargs)))
                    (dolist (el strs)
                        (setf wrapper `(FFI:WITH-CSTRING ,el ,wrapper)))
                    (setf wrapper `(defun ,name ,largs ,wrapper))
                    `(progn (uffi:def-function (,c-name ,sym)
                                ,fargs :returning ,l-ret)
                            ,wrapper))
                `(uffi:def-function (,c-name ,name)
                     ,fargs :returning ,l-ret)))))

(defmacro fricas-foreign-call (name c-name return-type &rest arguments)
    (ecl-foreign-call name c-name return-type arguments))

)

;; LispWorks FFI interface

#+:lispworks
(eval-when (:compile-toplevel :load-toplevel :execute)

(setf *c-type-to-ffi*
      '((int      :int)
        (c-string (:reference-pass :ef-mb-string))
        (double   :double)))

(defun c-args-to-lispworks (arguments)
  (mapcar (lambda (x) (list (nth 0 x) (c-type-to-ffi (nth 1 x))))
          arguments))

(defun lispworks-foreign-call (name c-name return-type arguments)
  (let ((lispworks-args (c-args-to-lispworks arguments))
        (lispworks-ret (c-type-to-ffi return-type)))
    `(fli::define-foreign-function (,name ,c-name)
         ,lispworks-args
       :result-type ,lispworks-ret)))

(defmacro fricas-foreign-call (name c-name return-type &rest arguments)
  (lispworks-foreign-call name c-name return-type arguments))

)

;;;
;;; Foreign routines
;;;

(defmacro foreign-defs (&rest arguments)
    #-:clisp `(progn ,@arguments)
    #+(and :clisp :ffi) `(defun clisp-init-foreign-calls () ,@arguments)
)

(foreign-defs

(fricas-foreign-call |writeablep| "writeablep" int
        (filename c-string))

(fricas-foreign-call |openServer| "open_server" int
        (server_name c-string))

(fricas-foreign-call |sockGetInt| "sock_get_int" int
        (purpose int))

(fricas-foreign-call |sockSendInt| "sock_send_int" int
        (purpose int)
        (val int))

#+:GCL
(LISP::clines "extern double sock_get_float();")

(fricas-foreign-call |sockGetFloat| "sock_get_float" double
        (purpose int))

(fricas-foreign-call |sockSendFloat| "sock_send_float" int
       (purpose int)
       (num double))

;;; (fricas-foreign-call |sockSendString| "sock_send_string" int
;;;       (purpose int)
;;;       (str c-string))

(fricas-foreign-call sock_send_string_len "sock_send_string_len" int
       (purpose int)
       (str c-string)
       (len int))

(defun |sockSendString| (purpose str)
     (sock_send_string_len purpose str (length str)))

(fricas-foreign-call |serverSwitch| "server_switch" int)

(fricas-foreign-call |sockSendSignal| "sock_send_signal" int
       (purpose int)
       (sig int))

#+:GCL
(progn

(LISP::defentry sock_get_string_buf (LISP::int LISP::object LISP::int)
    (LISP::int "sock_get_string_buf_wrapper"))

;; GCL may pass strings by value.  'sock_get_string_buf' should fill
;; string with data read from connection, therefore needs address of
;; actual string buffer. We use 'sock_get_string_buf_wrapper' to
;; resolve the problem
(LISP::clines "int sock_get_string_buf_wrapper(int i, object x, int j)"
    "{ if (type_of(x)!=t_string) FEwrong_type_argument(sLstring,x);"
    "  if (x->st.st_fillp<j)"
    "    FEerror(\"string too small in sock_get_string_buf_wrapper\",0);"
    "  return sock_get_string_buf(i, x->st.st_self, j); }")

(LISP::defentry sock_get_string_buf (LISP::int LISP::object LISP::int)
    (LISP::int "sock_get_string_buf_wrapper"))

(defun |sockGetStringFrom| (type)
    (let ((buf (MAKE-STRING 10000)))
        (sock_get_string_buf type buf 10000)
            buf))

)
#+(and :clisp :ffi)
(eval '(FFI:DEF-CALL-OUT sock_get_string_buf
    (:NAME "sock_get_string_buf")
    (:arguments (purpose ffi:int)
    (buf (FFI:C-POINTER (FFI:C-ARRAY FFI::char 10000)))
    (len ffi:int))
    (:return-type ffi:int)
    (:language :stdc)))

)

#+(and :clisp :ffi)
(defun |sockGetStringFrom| (purpose)
    (let ((buf nil))
        (FFI:WITH-C-VAR (tmp-buf '(FFI:C-ARRAY
                                   FFI::char 10000))
            (sock_get_string_buf purpose (FFI:C-VAR-ADDRESS tmp-buf) 10000)
            (prog ((len2 10000))
                (dotimes (i 10000)
                    (if (eql 0 (FFI:ELEMENT tmp-buf i))
                        (progn
                            (setf len2 i)
                            (go nn1))))
              nn1
                (setf buf (make-string len2))
                (dotimes (i len2)
                    (setf (aref buf i)
                          (code-char (FFI:ELEMENT tmp-buf i)))))
        )
        buf
    )
)

#+:openmcl
(defun |sockGetStringFrom| (purpose)
    (ccl::%stack-block ((tmp-buf 10000))
        (ccl::external-call "sock_get_string_buf"
            :int purpose :address tmp-buf :int 10000)
        (ccl::%get-cstring tmp-buf)))

#+:cmu
(defun |sockGetStringFrom| (purpose)
    (let ((buf nil))
        (alien:with-alien ((tmp-buf (alien:array
                                         c-call:char 10000)))
            (alien:alien-funcall
                (alien:extern-alien
                    "sock_get_string_buf"
                        (alien:function c-call:void
                            c-call:int
                            (alien:* c-call:char)
                            c-call:int))
                purpose
                (alien:addr (alien:deref tmp-buf 0))
                10000)
            (prog ((len2 10000))
                (dotimes (i 10000)
                    (if (eql 0 (alien:deref tmp-buf i))
                        (progn
                            (setf len2 i)
                            (go nn1))))
              nn1
                (setf buf (make-string len2))
                (dotimes (i len2)
                    (setf (aref buf i)
                        (code-char (alien:deref tmp-buf i))))
            )
        )
        buf
    )
)

#+:sbcl
(defun |sockGetStringFrom| (purpose)
    (let ((buf nil))
        (SB-ALIEN::with-alien ((tmp-buf (SB-ALIEN::array
                                         SB-ALIEN::char 10000)))
            (SB-ALIEN::alien-funcall
                (SB-ALIEN::extern-alien
                    "sock_get_string_buf"
                        (SB-ALIEN::function SB-ALIEN::void
                            SB-ALIEN::int
                            (SB-ALIEN::* SB-ALIEN::char)
                            SB-ALIEN::int))
                purpose
                (SB-ALIEN::addr (SB-ALIEN::deref tmp-buf 0))
                10000)
            (prog ((len2 10000))
                (dotimes (i 10000)
                    (if (eql 0 (SB-ALIEN::deref tmp-buf i))
                        (progn
                            (setf len2 i)
                            (go nn1))))
              nn1
                (setf buf (make-string len2))
                (dotimes (i len2)
                    (setf (aref buf i)
                        (code-char (SB-ALIEN::deref tmp-buf i))))
            )
        )
        buf
    )
)

#+:ecl
(progn

(uffi:def-function ("sock_get_string_buf" sock_get_string_buf_wrapper)
                   ((purpose :int) (buf (:array :unsigned-char 10000)) (len :int))
                   :returning :void)

(defun |sockGetStringFrom| (purpose)
    (uffi:with-foreign-object (buf '(:array :unsigned-char 10000))
        (sock_get_string_buf_wrapper purpose buf 10000)
        (uffi:convert-from-foreign-string buf)))

)

#+:lispworks
(progn

(fli:define-foreign-function (sock_get_string_buf_wrapper "sock_get_string_buf")
    ((purpose :int)
     (buf :pointer)
     (len :int))
  :result-type :void)

(defun |sockGetStringFrom| (purpose)
  (fli:with-dynamic-foreign-objects
      ((buf (:ef-mb-string :limit 10000)))
    (sock_get_string_buf_wrapper purpose buf 10000)
    (fli:convert-from-foreign-string buf)))
)
      
;;; -------------------------------------------------------
;;; File and directory support
;;; First version contributed by Juergen Weiss.

#+:GCL
(progn
  (LISP::defentry file_kind (LISP::string)      (LISP::int "directoryp"))
  (LISP::defentry |makedir| (LISP::string)         (LISP::int "makedir")))

#+:ecl
(uffi:def-function ("directoryp" raw_file_kind)
                   ((arg :cstring))
                   :returning :int)
#+:ecl
(defun file_kind (name)
      (FFI:WITH-CSTRING (cname name)
           (raw_file_kind cname)))

#+:ecl
(uffi:def-function ("makedir" raw_makedir)
                   ((arg :cstring))
                   :returning :int)

#+:ecl
(defun |makedir| (name)
      (FFI:WITH-CSTRING (cname name)
          (raw_makedir cname)))

(defun trim-directory-name (name)
    #+(or :unix :win32)
    (if (char= (char name (1- (length name))) #\/)
        (setf name (subseq name 0 (1- (length name)))))
    name)

(defun pad-directory-name (name)
   #+(or :unix :win32)
   (if (char= (char name (1- (length name))) #\/)
       name
       (concatenate 'string name "/"))
   #-(or :unix :win32)
       (error "Not Unix and not Windows, what system it is?")
    )

;;; Make directory

#+(or :GCL :ecl)
(defun makedir (fname) (|makedir| fname))

#+:cmu
(defun makedir (fname)
    (ext::run-program "mkdir" (list fname)))

#+:sbcl
(defun makedir (fname)
    (sb-ext::run-program "mkdir" (list fname) :search t))

#+:openmcl
(defun makedir (fname)
    (ccl::run-program "mkdir" (list fname)))

#+:clisp
(defun makedir (fname)
    (ext:make-dir (pad-directory-name (namestring fname))))

#+:lispworks
(defun makedir (fname)
    (system:call-system (concatenate 'string "mkdir " fname)))

;;;

#+:sbcl
(defmacro sbcl-file-kind(x)
    (let ((file-kind-fun
            (or (find-symbol "NATIVE-FILE-KIND" :sb-impl)
                (find-symbol "UNIX-FILE-KIND" :sb-unix))))
         `(,file-kind-fun ,x)))

(defun file-kind (filename)
   #+(or :GCL :ecl) (file_kind filename)
   #+:cmu
           (case (unix:unix-file-kind filename)
                (:directory 1)
                ((nil) -1)
                (t 0))
   #+:sbcl
           (case (sbcl-file-kind filename)
                (:directory 1)
                ((nil) -1)
                (t 0))
   #+:openmcl (if (ccl::directoryp filename)
                  1
                  (if (probe-file filename)
                      0
                     -1))
   #+:clisp (let* ((fname (trim-directory-name (namestring filename)))
                   (dname (pad-directory-name fname)))
             (if (ignore-errors (truename dname))
                 1
                 (if (ignore-errors (truename fname))
                     0
                     -1)))
   #+:lispworks
   (if filename
       (if (lispworks:file-directory-p filename)
           1
         (if (probe-file filename) 0 -1))
     -1))
 
#+:cmu
(defun get-current-directory ()
  (multiple-value-bind (win dir) (unix::unix-current-directory)
		       (declare (ignore win))  dir))

#+(or :ecl :GCL :sbcl :clisp :openmcl)
(defun get-current-directory ()
    (trim-directory-name (namestring (truename ""))))

#+:poplog
(defun get-current-directory ()
   (let ((name (namestring (truename "."))))
        (trim-directory-name (subseq name 0 (1- (length name))))))

#+lispworks
(defun get-current-directory ()
  (let ((directory (namestring (system:current-directory))))
    (trim-directory-name directory)))


(defun fricas-probe-file (file)
#|
#+:GCL (if (fboundp 'system::stat)
           ;;; gcl-2.6.8
           (and (system::stat file) (truename file))
           ;;; gcl-2.6.7
           (probe-file file))
|#
#+:GCL (let* ((fk (file-kind (namestring file)))
              (fname (trim-directory-name (namestring file)))
              (dname (pad-directory-name fname)))
           (cond
             ((equal fk 1)
                (truename dname))
             ((equal fk 0)
               (truename fname))
             (t nil)))
#+:cmu (if (unix:unix-file-kind file) (truename file))
#+:sbcl (if (sbcl-file-kind file) (truename file))
#+(or :openmcl :ecl :lispworks) (probe-file file)
#+:clisp(let* ((fname (trim-directory-name (namestring file)))
               (dname (pad-directory-name fname)))
                 (or (ignore-errors (truename dname))
                     (ignore-errors (truename fname))))
         )

#-:cmu
(defun relative-to-absolute (name)
    (let ((ns (namestring name)))
         (if (and (consp (pathname-directory name))
                  (eq (car (pathname-directory name))
                      #-:GCL :absolute #+:GCL :root))
             ns
             (concatenate 'string (get-current-directory)  "/" ns))))
#+:cmu
(defun relative-to-absolute (name)
  (unix::unix-maybe-prepend-current-directory name))

;;; Saner version of compile-file
#+:ecl
(defun fricas-compile-file (f &key output-file)
    (if output-file
        (compile-file f :output-file (relative-to-absolute output-file)
                        :system-p t)
        (compile-file f :system-p t)))
#-:ecl
(defun fricas-compile-file (f &key output-file)
    (if output-file
        (compile-file f :output-file (relative-to-absolute output-file))
        (compile-file f)))

(defun maybe-compile (f cf)
    (if (or (not (probe-file cf))
            (< (file-write-date cf) (file-write-date f)))
        (fricas-compile-file f :output-file cf)))

(defun load-maybe-compiling (f cf)
         (maybe-compile f cf)
         (load #-:ecl cf #+:ecl f))

(defmacro DEFCONST (name value)
   `(defconstant ,name (if (boundp ',name) (symbol-value ',name) ,value)))

#+:cmu
(defconstant +list-based-union-limit+ 80)

#+:cmu
(defun union (list1 list2 &key key (test #'eql testp) (test-not nil notp))
  "Return the union of LIST1 and LIST2."
  (declare (inline member))
  (when (and testp notp)
    (error ":TEST and :TEST-NOT were both supplied."))
  ;; We have to possibilities here: for shortish lists we pick up the
  ;; shorter one as the result, and add the other one to it. For long
  ;; lists we use a hash-table when possible.
  (let ((n1 (length list1))
        (n2 (length list2))
        (key (and key (coerce key 'function)))
        (test (if notp
                  (let ((test-not-fun (coerce test-not 'function)))
                    (lambda (x y) (not (funcall test-not-fun x y))))
                  (coerce test 'function))))
    (multiple-value-bind (short long n-short)
        (if (< n1 n2)
            (values list1 list2 n1)
            (values list2 list1 n2))
      (if (or (< n-short +list-based-union-limit+)
              (not (member test (list #'eq #'eql #'equal #'equalp))))
          (let ((orig short))
            (dolist (elt long)
              (unless (member
		       (lisp::apply-key key elt) orig :key key :test test)
                (push elt short)))
            short)
          (let ((table (make-hash-table :test test :size (+ n1 n2)))
                (union nil))
            (dolist (elt long)
              (setf (gethash (lisp::apply-key key elt) table) elt))
            (dolist (elt short)
              (setf (gethash (lisp::apply-key key elt) table) elt))
            (maphash (lambda (k v)
                       (declare (ignore k))
                       (push v union))
                     table)
            union)))))

#+:cmu
(defun nunion (list1 list2 &key key (test #'eql testp) (test-not nil notp))
  "Destructively return the union of LIST1 and LIST2."
  (declare (inline member))
  (when (and testp notp)
    (error ":TEST and :TEST-NOT were both supplied."))
  ;; We have to possibilities here: for shortish lists we pick up the
  ;; shorter one as the result, and add the other one to it. For long
  ;; lists we use a hash-table when possible.
  (let ((n1 (length list1))
        (n2 (length list2))
        (key (and key (coerce key 'function)))
        (test (if notp
                  (let ((test-not-fun (coerce test-not 'function)))
                    (lambda (x y) (not (funcall test-not-fun x y))))
                  (coerce test 'function))))
    (multiple-value-bind (short long n-short)
        (if (< n1 n2)
            (values list1 list2 n1)
            (values list2 list1 n2))
      (if (or (< n-short +list-based-union-limit+)
              (not (member test (list #'eq #'eql #'equal #'equalp))))
          (let ((orig short))
            (do ((elt (car long) (car long)))
                ((endp long))
              (if (not (member
			(lisp::apply-key key elt) orig :key key :test test))
                  (lisp::steve-splice long short)
                  (setf long (cdr long))))
            short)
          (let ((table (make-hash-table :test test :size (+ n1 n2))))
            (dolist (elt long)
              (setf (gethash (lisp::apply-key key elt) table) elt))
            (dolist (elt short)
              (setf (gethash (lisp::apply-key key elt) table) elt))
            (let ((union long)
                  (head long))
              (maphash (lambda (k v)
                         (declare (ignore k))
                         (if head
                             (setf (car head) v
                                   head (cdr head))
                             (push v union)))
                      table)
              union))))))
