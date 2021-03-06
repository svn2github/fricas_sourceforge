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


;;
;; Lisp support for cleaned up FileName domain.
;;
;; Created: June 20, 1991 (Stephen Watt)
;; 

(in-package "BOOT")

;; E.g.  "/"  "/u/smwatt"  "../src"
(defun |DirToString| (d)
  (cond
    ((equal d '(:root)) "/")
    ((null d) "")
    ('t (string-right-trim "/" (namestring (make-pathname :directory d)))) ))

(defun |StringToDir| (s)
  (cond
    ((string= s "/") '(:root))
    ((string= s "")  nil)
    ('t 
      (let ((lastc (aref s (- (length s) 1))))
        (if (char= lastc #\/)
          (pathname-directory (concat s "name.type"))
          (pathname-directory (concat s "/name.type")) ))) ))

(defun |myWritable?| (s)
  (if (not (stringp s)) (|error| "``myWritable?'' requires a string arg."))
  (if (string= s "") (setq s "."))
  (if (not (|fnameExists?| s)) (setq s (|fnameDirectory| s)))
  (if (string= s "") (setq s "."))
  (if (> (|writeablep| s) 0) 't nil) )

(defun |fnameMake| (d n e)
  (if (string= e "") (setq e nil))
  (make-pathname :directory (|StringToDir| d) :name  n :type e))

(defun |fnameDirectory| (f)
  (|DirToString| (pathname-directory f)))

(defun |fnameName| (f)
  (let ((s (pathname-name f)))
    (if s s "") ))

(defun |fnameType| (f)
  (let ((s (pathname-type f)))
    (if s s "") ))
 
(defun |fnameExists?| (f)
  (if (vmlisp::fricas-probe-file (namestring f)) 't nil))

(defun |fnameReadable?| (f)
  (let ((s 
          #-:GCL
          (ignore-errors (open f :direction :input :if-does-not-exist nil))
          #+:GCL
          (open f :direction :input :if-does-not-exist nil)
        ))
    (cond (s (close s) 't) ('t nil)) )
  )

(defun |fnameWritable?| (f)
  (|myWritable?| (namestring f)) )

(defun |fnameNew| (d n e)
  (if (not (|myWritable?| d))
    nil
    (do ((fn))
        (nil)
        (setq fn (|fnameMake| d (string (gensym n)) e))
        (if (not (vmlisp::fricas-probe-file (namestring fn)))
           (return-from |fnameNew| fn)) )))
