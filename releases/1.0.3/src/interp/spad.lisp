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


; NAME:    Scratchpad Package
; PURPOSE: This is an initialization and system-building file for Scratchpad.

(in-package "BOOT")

;;; Common  Block

(defvar |$UserLevel| '|development|)
(defvar |$reportInstantiations| nil)
(defvar |$reportEachInstantiation| nil)
(defvar |$reportCounts| nil)
(defvar |$CategoryDefaults| nil)
(defvar |$compForModeIfTrue| nil "checked in compSymbol")
(defvar |$functorForm| nil "checked in addModemap0")
(defvar |$formalArgList| nil "checked in compSymbol")
(defvar |$newCompCompare| nil "compare new compiler with old")
(defvar |$compileOnlyCertainItems| nil "list of functions to compile")
(defvar |$newCompAtTopLevel| nil "if t uses new compiler")
(defvar |$doNotCompileJustPrint| nil "switch for compile")
(defvar |$PrintCompilerMessageIfTrue| t)
(defvar |$Rep| '|$Rep| "should be bound to gensym? checked in coerce")
;; the following initialization of $ must not be a defvar
;; since that make $ special
(setq $ '$) ;; used in def of Ring which is Algebra($)
(defvar |$scanIfTrue| nil "if t continue compiling after errors")
(defvar |$Representation| nil "checked in compNoStacking")
(defvar |$definition| nil "checked in DomainSubstitutionFunction")
(defvar |$Attributes| nil "global attribute list used in JoinInner")
(defvar |$env| nil "checked in isDomainValuedVariable")
(defvar |$e| nil "checked in isDomainValuedVariable")
(defvar |$getPutTrace| nil)
(defvar |$specialCaseKeyList| nil "checked in optCall")
(defvar |$formulaFormat| nil "if true produce script formula output")
(defvar |$texFormat| nil "if true produce tex output")
(defvar |$fortranFormat| nil "if true produce fortran output")
(defvar |$algebraFormat| t "produce 2-d algebra output")
(defvar |$mapReturnTypes| nil)
(defvar /TRACENAMES NIL)

(defvar INPUTSTREAM t "bogus initialization for now")

(setq /WSNAME 'NOBOOT)
(DEFVAR _ '&)
(defvar ind)
(defvar JUNKTOKLIST '(FOR IN AS INTO OF TO))

;************************************************************************
;         SYSTEM COMMANDS
;************************************************************************

(defun TERSYSCOMMAND ()
  (FRESH-LINE)
  (SETQ TOK 'END_UNIT)
  (|spadThrow|))

(defun /READ (L Q)
  (SETQ /EDITFILE L)
  (COND
    (Q  (/RQ))
    ('T (/RF)) )
  (|terminateSystemCommand|)
  (|spadPrompt|))

(defun |fin| ()
  (SETQ *EOF* 'T)
  (THROW 'SPAD_READER NIL))



(FLAG JUNKTOKLIST 'KEY)

(defmacro |report| (L)
  (SUBST (SECOND L) 'x
         '(COND ($reportFlag (sayBrightly x)) ((QUOTE T) NIL))))

(defmacro |DomainSubstitutionMacro| (&rest L)
  (|DomainSubstitutionFunction| (first L) (second L)))

(defun |sort| (seq spadfn)
    (sort (copy-seq seq) (function (lambda (x y) (SPADCALL X Y SPADFN)))))

#-Lucid
(defun QUOTIENT2 (X Y) (values (TRUNCATE X Y)))

#+Lucid
(defun QUOTIENT2 (X Y) ; following to force error check in division by zero
  (values (if (zerop y) (truncate 1 Y) (TRUNCATE X Y))))

#-Lucid
(define-function 'REMAINDER2 #'REM)

#+Lucid
(defun REMAINDER2 (X Y)
  (if (zerop y) (REM 1 Y) (REM X Y)))

#-Lucid
(defun DIVIDE2 (X Y) (multiple-value-call #'cons (TRUNCATE X Y)))

#+Lucid
(defun DIVIDE2 (X Y)
  (if (zerop y) (truncate 1 Y)
    (multiple-value-call #'cons (TRUNCATE X Y))))

(defmacro APPEND2 (x y) `(append ,x ,y))

(defmacro |float| (x &optional (y 0.0d0)) `(float ,x ,y))

(defun |makeSF| (mantissa exponent)
  (|float| (/ mantissa (expt 2 (- exponent)))))

(define-function 'list1 #'list)
(define-function '|not| #'NOT)

(defun |random| () (random (expt 2 26)))

;; This is used in the domain Boolean (BOOLEAN.NRLIB/code.lsp)
(defun |BooleanEquality| (x y) (if x y (null y)))

(defun S-PROCESS (X)
  (let ((|$Index| 0)
        ($MACROASSOC ())
        (|$compUniquelyIfTrue| nil)
        |$currentFunction|
        (|$postStack| nil)
        |$topOp|
        (|$semanticErrorStack| ())
        (|$warningStack| ())
        (|$exitMode| |$EmptyMode|)
        (|$exitModeStack| ())
        (|$returnMode| |$EmptyMode|)
        (|$leaveLevelStack| ())
        $TOP_LEVEL |$insideFunctorIfTrue| |$insideExpressionIfTrue|
        |$insideCoerceInteractiveHardIfTrue| |$insideWhereIfTrue|
        |$insideCategoryIfTrue| |$insideCapsuleFunctionIfTrue| |$form|
        (|$e| |$EmptyEnvironment|)
        (|$genFVar| 0)
        (|$genSDVar| 0)
        (|$previousTime| (TEMPUS-FUGIT))
        )
  (prog ((CURSTRM CUROUTSTREAM) |$s| |$x| |$m| u)
     (declare (special CURSTRM |$s| |$x| |$m| CUROUTSTREAM))
      (if (NOT X) (RETURN NIL))
      (setq X (if $BOOT (DEF-RENAME (|new2OldLisp| X))
                  (|parseTransform| (|postTransform| X))))
      (if |$TranslateOnly| (RETURN (SETQ |$Translation| X)))
      (when |$postStack| (|displayPreCompilationErrors|) (RETURN NIL))
      (COND (|$PrintOnly|
             (format t "~S   =====>~%" |$currentLine|)
             (RETURN (PRETTYPRINT X))))
      (if (NOT $BOOT)
          (if |$InteractiveMode|
              (|processInteractive| X NIL)
            (if (setq U (|compTopLevel|  X |$EmptyMode|
                                         |$InteractiveFrame|))
                (SETQ |$InteractiveFrame| (third U))))
        (DEF-PROCESS X))
      (if |$semanticErrorStack| (|displaySemanticErrors|))
      (TERPRI))))

(MAKEPROP 'END_UNIT 'KEY T)

;;; (defun |evalSharpOne| (x \#1) (declare (special \#1)) (EVAL x))
(defun |evalSharpOne| (x |#1|)
   (declare (special |#1|))
      (EVAL `(let () (declare (special |#1|)) ,x)))


(defun INITIALIZE () (init-boot/spad-reader) (initialize-preparse INPUTSTREAM))

(defun GLESSEQP (X Y) (NOT (GGREATERP X Y)))

(defun LEXLESSEQP (X Y) (NOT (LEXGREATERP X Y)))

(defmacro |rplac| (&rest L)
  (let (a b s)
    (cond
      ((EQCAR (SETQ A (CAR L)) 'ELT)
       (COND ((AND (INTEGERP (SETQ B (CADDR A))) (>= B 0))
              (SETQ S "CA")
              (do ((i 1 (1+ i))) ((> i b)) (SETQ S (STRCONC S "D")))
              (LIST 'RPLAC (LIST (INTERN (STRCONC S "R")) (CADR A)) (CADR L)))
             ((ERROR "rplac"))))
      ((PROGN
         (SETQ A (CARCDREXPAND (CAR L) NIL))
         (SETQ B (CADR L))
         (COND
           ((CDDR L) (ERROR 'RPLAC))
           ((EQCAR A 'CAR) (LIST 'RPLACA (CADR A) B))
           ((EQCAR A 'CDR) (LIST 'RPLACD (CADR A) B))
           ((ERROR 'RPLAC))))))))

(DEFUN ASSOCIATER (FN LST)
  (COND ((NULL LST) NIL)
        ((NULL (CDR LST)) (CAR LST))
        ((LIST FN (CAR LST) (ASSOCIATER FN (CDR LST))))))

; **** X. Random tables

(defvar MATBORCH "*")
(defvar $MARGIN 3)
(defvar TEMPGENSYMLIST '(|s| |r| |q| |p|))
(defvar ALPHLIST '(|a| |b| |c| |d| |e| |f| |g|))
(defvar LITTLEIN " in ")
(defvar INITALPHLIST ALPHLIST)
(defvar INITXPARLST '(|i| |j| |k| |l| |m| |n| |p| |q|))
(defvar PORDLST (COPY-tree INITXPARLST))
(defvar INITPARLST '(|x| |y| |z| |u| |v| |w| |r| |s| |t|))
(defvar LITTLEA '|a|)
(defvar LITTLEI '|i|)
(defvar *TALLPAR NIL)
(defvar ALLSTAR NIL)
(defvar BLANK " ")
(defvar PLUSS "+")
(defvar PERIOD ".")
(defvar SLASH "/")
(defvar COMMA ",")
(defvar LPAR "(")
(defvar RPAR ")")
(defvar EQSIGN "=")
(defvar DASH "-")
(defvar STAR "*")
(defvar DOLLAR "$")
(defvar COLON ":")

(FLAG TEMPGENSYMLIST 'IS-GENSYM)

(MAKEPROP 'COND '|Nud| '(|if| |if| 130 0))
(MAKEPROP 'CONS '|Led| '(CONS CONS 1000 1000))
(MAKEPROP 'APPEND '|Led| '(APPEND APPEND 1000 1000))
(MAKEPROP 'TAG '|Led| '(TAG TAG 122 121))
(MAKEPROP 'EQUATNUM '|Nud| '(|dummy| |dummy| 0 0))
(MAKEPROP 'EQUATNUM '|Led| '(|dummy| |dummy| 10000 0))
(MAKEPROP 'LET '|Led| '(|:=| LET 125 124))
(MAKEPROP 'RARROW '|Led| '(== DEF 122 121))
(MAKEPROP 'SEGMENT '|Led| '(\.\. SEGMENT 401 699 (|boot-Seg|)))
(MAKEPROP 'SEGMENT '|isSuffix| 'T)

;; function to create byte and half-word vectors in new runtime system 8/90

#-:CCL
(defun |makeByteWordVec| (initialvalue)
  (let ((n (cond ((null initialvalue) 7) ('t (reduce #'max initialvalue)))))
    (make-array (length initialvalue)
      :element-type (list 'mod (1+ n))
      :initial-contents initialvalue)))

#+:CCL
(defun |makeByteWordVec| (initialvalue)
   (list-to-vector initialvalue))

#-:CCL
(defun |makeByteWordVec2| (maxelement initialvalue)
  (let ((n (cond ((null initialvalue) 7) ('t maxelement))))
    (make-array (length initialvalue)
      :element-type (list 'mod (1+ n))
      :initial-contents initialvalue)))

#+:CCL
(defun |makeByteWordVec2| (maxelement initialvalue)
   (list-to-vector initialvalue))

(defun |knownEqualPred| (dom)
  (let ((fun (|compiledLookup| '= '((|Boolean|) $ $) dom)))
    (if fun (get (bpiname (car fun)) '|SPADreplace|)
      nil)))

(defun |hashable| (dom)
  (memq (|knownEqualPred| dom)
        #-Lucid '(EQ EQL EQUAL)
        #+Lucid '(EQ EQL EQUAL EQUALP)
        ))

;; simpler interpface to RDEFIOSTREAM
(defun RDEFINSTREAM (&rest fn)
  ;; following line prevents rdefiostream from adding a default filetype
  (if (null (rest fn)) (setq fn (list (pathname (car fn)))))
  (rdefiostream (list (cons 'FILE fn) '(mode . INPUT))))

(defun RDEFOUTSTREAM (&rest fn)
  ;; following line prevents rdefiostream from adding a default filetype
  (if (null (rest fn)) (setq fn (list (pathname (car fn)))))
  (rdefiostream (list (cons 'FILE fn) '(mode . OUTPUT))))

(defmacro |spadConstant| (dollar n)
 `(spadcall (svref ,dollar (the fixnum ,n))))


