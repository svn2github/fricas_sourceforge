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

;;
;; Lisp part of the Scratchpad special function interface.
;; SMW Feb 91
;;

;; Conversion between spad and lisp complex representations
(defun s-to-c (c) (complex (car c) (cdr c)))
(defun c-to-s (c) (cons (realpart c) (imagpart c)))
(defun c-to-r (c)
    (let ((r (realpart c)) (i (imagpart c)))
      (if (or (zerop i) (< (abs i) (* 1.0E-10 (abs r))))
          r
        (|error| "Result is not real.")) ))
(defun C-TO-RF (c) (coerce (c-to-r c) 'DOUBLE-FLOAT))

;; Wrappers for functions in the special function package
(defun rlngamma  (x)           (|lnrgamma| x) )
(defun clngamma  (z)   (c-to-s (|lncgamma| (s-to-c z)) ))

(defun rgamma    (x)           (|rgamma|   x))
(defun cgamma    (z)   (c-to-s (|cgamma|   (s-to-c z)) ))

(defun rpsi      (n x)         (|rPsi|     n x) )
(defun cpsi      (n z) (c-to-s (|cPsi|     n (s-to-c z)) ))

(defun rbesselj  (n x) (c-to-r (|BesselJ| n x)) )
(defun cbesselj  (v z) (c-to-s (|BesselJ| (s-to-c v) (s-to-c z)) ))

(defun rbesseli  (n x) (c-to-r (|BesselI| n x)) )
(defun cbesseli  (v z) (c-to-s (|BesselI| (s-to-c v) (s-to-c z)) ))

(defun chyper0f1 (a z) (c-to-s (|chebf01| (s-to-c a) (s-to-c z)) ))
