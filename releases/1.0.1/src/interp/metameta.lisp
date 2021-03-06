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


; .META(META PROGRAM)
; .PREFIX 'PARSE-'
; .PACKAGE 'PARSING'
; .DECLARE(METAPGVAR METAVARLST METAKEYLST METARULNAM TRAPFLAG XNAME)
 
(IN-PACKAGE "BOOT")
 
(DEFPARAMETER METAPGVAR NIL)
(DEFPARAMETER METAVARLST NIL)
(DEFPARAMETER METAKEYLST NIL)
(DEFPARAMETER METARULNAM NIL)
(DEFPARAMETER TRAPFLAG NIL)
(DEFPARAMETER XNAME NIL)

; PROGRAM:<HEADER*>! <RULE*>! ='.FIN' ;
 
(DEFUN PARSE-PROGRAM NIL
  (AND (BANG |FIL_TEST| (OPTIONAL (STAR REPEATOR (PARSE-HEADER))))
       (BANG |FIL_TEST| (OPTIONAL (STAR REPEATOR (PARSE-RULE))))
       (MATCH-STRING ".FIN")))
 
; HEADER:       '.META' '(' IDENTIFIER IDENTIFIER <IDENTIFIER>! ')' .(SETQ XNAME ##3)
; / '.DECLARE' '(' IDENTIFIER* ')' .(PRINT-FLUIDS #1)
; / '.PREFIX' STRING .(SET-PREFIX #1)
; / '.PACKAGE' STRING .(PRINT-PACKAGE #1) ;
 
(DEFUN PARSE-HEADER NIL
  (OR (AND (MATCH-ADVANCE-STRING ".META")
           (MUST (MATCH-ADVANCE-STRING "("))
           (MUST (PARSE-IDENTIFIER))
           (MUST (PARSE-IDENTIFIER))
           (BANG |FIL_TEST| (OPTIONAL (PARSE-IDENTIFIER)))
           (MUST (MATCH-ADVANCE-STRING ")"))
           (ACTION (SETQ XNAME (NTH-STACK 3))))
      (AND (MATCH-ADVANCE-STRING ".DECLARE")
           (MUST (MATCH-ADVANCE-STRING "("))
           (MUST (STAR REPEATOR (PARSE-IDENTIFIER)))
           (MUST (MATCH-ADVANCE-STRING ")"))
           (ACTION (PRINT-FLUIDS (POP-STACK-1))))
      (AND (MATCH-ADVANCE-STRING ".PREFIX")
           (MUST (PARSE-STRING))
           (ACTION (SET-PREFIX (POP-STACK-1))))
      (AND (MATCH-ADVANCE-STRING ".PACKAGE")
           (MUST (PARSE-STRING))
           (ACTION (PRINT-PACKAGE (POP-STACK-1))))))
 
; RULE:     RULE1 ';' .(PRINT-RULE #1) / ^='.FIN' .(META-SYNTAX-ERROR) ;
 
(DEFUN PARSE-RULE NIL
  (OR (AND (PARSE-RULE1)
           (MUST (MATCH-ADVANCE-STRING ";"))
           (ACTION (PRINT-RULE (POP-STACK-1))))
      (AND (NOT (MATCH-STRING ".FIN"))
           (ACTION (META-SYNTAX-ERROR)))))
 
; RULE1: IDENTIFIER .(SETQ METARULNAM (INTERN (STRCONC META_PREFIX ##1)))
; <'{' FID* '}'>! ':' EXPR =';'
; < =$METAPGVAR +(PROG =(TRANSPGVAR METAPGVAR) (RETURN #1))
; .(SETQ METAPGVAR NIL) >
; +=(MAKE-DEFUN #3 #2 #1) ;
 
(DEFUN PARSE-RULE1 NIL
  (AND (PARSE-IDENTIFIER)
       (ACTION (SETQ METARULNAM (INTERN (STRCONC |META_PREFIX| (NTH-STACK 1)))))
       (BANG |FIL_TEST|
             (OPTIONAL (AND (MATCH-ADVANCE-STRING "{")
                            (MUST (STAR REPEATOR (PARSE-FID)))
                            (MUST (MATCH-ADVANCE-STRING "}")))))
       (MUST (MATCH-ADVANCE-STRING ":"))
       (MUST (PARSE-EXPR))
       (MUST (MATCH-STRING ";"))
       (OPTIONAL (AND METAPGVAR
                      (PUSH-REDUCTION 'PARSE-RULE1
                                      (CONS 'PROG
                                            (CONS (TRANSPGVAR METAPGVAR)
                                                  (CONS (CONS
                                                         'RETURN
                                                         (CONS (POP-STACK-1) NIL))
                                                        NIL))))
                      (ACTION (SETQ METAPGVAR NIL))))
       (PUSH-REDUCTION 'PARSE-RULE1
                       (MAKE-DEFUN (POP-STACK-3) (POP-STACK-2) (POP-STACK-1)))))
 
; FID:  IDENTIFIER +#1 ;
 
(DEFUN PARSE-FID NIL
  (AND (PARSE-IDENTIFIER)
       (PUSH-REDUCTION 'PARSE-FID (POP-STACK-1))))
 
; EXPR:   SUBEXPR
; <   EXPR1* +(OR #2 -#1)
; / EXPR2* +(OR #2 -#1) >  ;
 
(DEFUN PARSE-EXPR NIL
  (AND (PARSE-SUBEXPR)
       (OPTIONAL (OR (AND (STAR REPEATOR (PARSE-EXPR1))
                          (PUSH-REDUCTION 'PARSE-EXPR
                                          (CONS 'OR
                                                (CONS (POP-STACK-2)
                                                      (APPEND (POP-STACK-1) NIL)))))
                     (AND (STAR REPEATOR (PARSE-EXPR2))
                          (PUSH-REDUCTION 'PARSE-EXPR
                                          (CONS 'OR
                                                (CONS (POP-STACK-2)
                                                      (APPEND (POP-STACK-1) NIL)))))))))
 
; EXPR1:  '/' <^'/'>  SUBEXPR   ;
 
(DEFUN PARSE-EXPR1 NIL
  (AND (MATCH-ADVANCE-STRING "/")
       (OPTIONAL (NOT (MATCH-ADVANCE-STRING "/")))
       (MUST (PARSE-SUBEXPR))))
 
; EXPR2:  '\\' <^'\\'>  SUBEXPR  ;
 
(DEFUN PARSE-EXPR2 NIL
  (AND (MATCH-ADVANCE-STRING "\\")
       (OPTIONAL (NOT (MATCH-ADVANCE-STRING "\\")))
       (MUST (PARSE-SUBEXPR))))
 
; SUBEXPR:FIL_TEST <^?$TRAPFLAG FIL_TEST>*!
; <FIL_TEST <?$TRAPFLAG +(MUST #1)> >*!
; +(#3 -#2 -#1) +=(MAKE-PARSE-FUNCTION #1 "AND) ;
 
(DEFUN PARSE-SUBEXPR NIL
  (AND (PARSE-FIL_TEST)
       (BANG |FIL_TEST|
             (OPTIONAL (STAR |OPT_EXPR|
                             (AND (NOT TRAPFLAG)
                                  (PARSE-FIL_TEST)))))
       (BANG |FIL_TEST|
             (OPTIONAL (STAR |OPT_EXPR|
                             (AND (PARSE-FIL_TEST)
                                  (OPTIONAL (AND TRAPFLAG
                                                 (PUSH-REDUCTION 'PARSE-SUBEXPR
                                                                 (CONS
                                                                  'MUST
                                                                  (CONS (POP-STACK-1) NIL))))))
                             )))
       (PUSH-REDUCTION 'PARSE-SUBEXPR
                       (CONS (POP-STACK-3)
                             (APPEND (POP-STACK-2) (APPEND (POP-STACK-1) NIL))))
       (PUSH-REDUCTION 'PARSE-SUBEXPR (MAKE-PARSE-FUNCTION (POP-STACK-1) 'AND))))
 
; FIL_TEST: REP_TEST <'!' +(BANG FIL_TEST #1)>      ;
 
(DEFUN PARSE-FIL_TEST NIL
  (AND (PARSE-REP_TEST)
       (OPTIONAL (AND (MATCH-ADVANCE-STRING "!")
                      (PUSH-REDUCTION 'PARSE-FIL_TEST
                                      (CONS 'BANG
                                            (CONS '|FIL_TEST| (CONS (POP-STACK-1) NIL))))))))
 
; REP_TEST: N_TEST <REPEATOR>  ;
 
(DEFUN PARSE-REP_TEST NIL
  (AND (PARSE-N_TEST)
       (OPTIONAL (PARSE-REPEATOR))))
 
; N_TEST:   '^' TEST  +(NOT #1) / TEST  ;
 
(DEFUN PARSE-N_TEST NIL
  (OR (AND (MATCH-ADVANCE-STRING "^")
           (MUST (PARSE-TEST))
           (PUSH-REDUCTION 'PARSE-N_TEST (CONS 'NOT (CONS (POP-STACK-1) NIL))))
      (PARSE-TEST)))
 
; TEST:     IDENTIFIER (    '{' <SEXPR*>! '}'
; +(=(INTERN (STRCONC META_PREFIX #2)) -#1)
; / +(=(INTERN (STRCONC META_PREFIX #1))))        .(SETQ TRAPFLAG T)
; / STRING  +(MATCH-ADVANCE-STRING #1)            .(SETQ TRAPFLAG T)
; / '=' REF_SEXPR                                 .(SETQ TRAPFLAG T)
; / '?' REF_SEXPR                                 .(SETQ TRAPFLAG NIL)
; / '.' SEXPR         +(ACTION #1)                .(SETQ TRAPFLAG NIL)
; / '+' CONS_SEXPR    +(PUSH-REDUCTION =(LIST "QUOTE METARULNAM) #1)
; .(SETQ TRAPFLAG NIL)
; / '(' EXPR ')'                                  .(SETQ TRAPFLAG T)
; / '<' EXPR '>'      .(PARSE-OPT_EXPR)           .(SETQ TRAPFLAG NIL) ;
 
(DEFUN PARSE-TEST NIL
  (OR (AND (PARSE-IDENTIFIER)
           (MUST (OR (AND (MATCH-ADVANCE-STRING "{")
                          (BANG |FIL_TEST| (OPTIONAL (STAR REPEATOR (PARSE-SEXPR))))
                          (MUST (MATCH-ADVANCE-STRING "}"))
                          (PUSH-REDUCTION 'PARSE-TEST
                                          (CONS (INTERN (STRCONC
                                                         |META_PREFIX|
                                                         (POP-STACK-2)))
                                                (APPEND (POP-STACK-1) NIL))))
                     (PUSH-REDUCTION 'PARSE-TEST
                                     (CONS (INTERN (STRCONC |META_PREFIX| (POP-STACK-1)))
                                           NIL))))
           (ACTION (SETQ TRAPFLAG T)))
      (AND (PARSE-STRING)
           (PUSH-REDUCTION 'PARSE-TEST
                           (CONS 'MATCH-ADVANCE-STRING (CONS (POP-STACK-1) NIL)))
           (ACTION (SETQ TRAPFLAG T)))
      (AND (MATCH-ADVANCE-STRING "=")
           (MUST (PARSE-REF_SEXPR))
           (ACTION (SETQ TRAPFLAG T)))
      (AND (MATCH-ADVANCE-STRING "?")
           (MUST (PARSE-REF_SEXPR))
           (ACTION (SETQ TRAPFLAG NIL)))
      (AND (MATCH-ADVANCE-STRING ".")
           (MUST (PARSE-SEXPR))
           (PUSH-REDUCTION 'PARSE-TEST (CONS 'ACTION (CONS (POP-STACK-1) NIL)))
           (ACTION (SETQ TRAPFLAG NIL)))
      (AND (MATCH-ADVANCE-STRING "+")
           (MUST (PARSE-CONS_SEXPR))
           (PUSH-REDUCTION 'PARSE-TEST
                           (CONS 'PUSH-REDUCTION
                                 (CONS (LIST 'QUOTE METARULNAM) (CONS (POP-STACK-1) NIL))))
           (ACTION (SETQ TRAPFLAG NIL)))
      (AND (MATCH-ADVANCE-STRING "(")
           (MUST (PARSE-EXPR))
           (MUST (MATCH-ADVANCE-STRING ")"))
           (ACTION (SETQ TRAPFLAG T)))
      (AND (MATCH-ADVANCE-STRING "<")
           (MUST (PARSE-EXPR))
           (MUST (MATCH-ADVANCE-STRING ">"))
           (ACTION (PARSE-OPT_EXPR))
           (ACTION (SETQ TRAPFLAG NIL)))))
 
; SEXPR:          IDENTIFIER / NUMBER / STRING / NON_DEST_REF / DEST_REF / LOCAL_VAR
; / '"' SEXPR +(QUOTE #1) / '=' SEXPR / '(' <SEXPR*>! ')' ;
 
(DEFUN PARSE-SEXPR NIL
  (OR (PARSE-IDENTIFIER)
      (PARSE-NUMBER)
      (PARSE-STRING)
      (PARSE-NON_DEST_REF)
      (PARSE-DEST_REF)
      (PARSE-LOCAL_VAR)
      (AND (MATCH-ADVANCE-STRING "\"")
           (MUST (PARSE-SEXPR))
           (PUSH-REDUCTION 'PARSE-SEXPR (CONS 'QUOTE (CONS (POP-STACK-1) NIL))))
      (AND (MATCH-ADVANCE-STRING "=")
           (MUST (PARSE-SEXPR)))
      (AND (MATCH-ADVANCE-STRING "(")
           (BANG |FIL_TEST| (OPTIONAL (STAR REPEATOR (PARSE-SEXPR))))
           (MUST (MATCH-ADVANCE-STRING ")")))))
 
; REF_SEXPR: STRING +(MATCH-STRING #1) / SEXPR ;
 
(DEFUN PARSE-REF_SEXPR NIL
  (OR (AND (PARSE-STRING)
           (PUSH-REDUCTION 'PARSE-REF_SEXPR (CONS 'MATCH-STRING (CONS (POP-STACK-1) NIL))))
      (PARSE-SEXPR)))
 
; CONS_SEXPR: IDENTIFIER <^=(MEMBER ##1 METAPGVAR) +(QUOTE #1)>
; / LOCAL_VAR +(QUOTE #1)
; / '(' <SEXPR_STRING>! ')'
; / SEXPR ;
 
(DEFUN PARSE-CONS_SEXPR NIL
  (OR (AND (PARSE-IDENTIFIER)
           (OPTIONAL (AND (NOT (MEMBER (NTH-STACK 1) METAPGVAR))
                          (PUSH-REDUCTION 'PARSE-CONS_SEXPR
                                          (CONS 'QUOTE (CONS (POP-STACK-1) NIL))))))
      (AND (PARSE-LOCAL_VAR)
           (PUSH-REDUCTION 'PARSE-CONS_SEXPR (CONS 'QUOTE (CONS (POP-STACK-1) NIL))))
      (AND (MATCH-ADVANCE-STRING "(")
           (BANG |FIL_TEST| (OPTIONAL (PARSE-SEXPR_STRING)))
           (MUST (MATCH-ADVANCE-STRING ")")))
      (PARSE-SEXPR)))
 
; SEXPR_STRING: CONS_SEXPR <SEXPR_STRING>!    +(CONS #2 #1)
; / '-' CONS_SEXPR <SEXPR_STRING>! +(APPEND #2 #1)      ;
 
(DEFUN PARSE-SEXPR_STRING NIL
  (OR (AND (PARSE-CONS_SEXPR)
           (BANG |FIL_TEST| (OPTIONAL (PARSE-SEXPR_STRING)))
           (PUSH-REDUCTION 'PARSE-SEXPR_STRING
                           (CONS 'CONS (CONS (POP-STACK-2) (CONS (POP-STACK-1) NIL)))))
      (AND (MATCH-ADVANCE-STRING "-")
           (MUST (PARSE-CONS_SEXPR))
           (BANG |FIL_TEST| (OPTIONAL (PARSE-SEXPR_STRING)))
           (PUSH-REDUCTION 'PARSE-SEXPR_STRING
                           (CONS 'APPEND (CONS (POP-STACK-2) (CONS (POP-STACK-1) NIL)))))))
 
; NON_DEST_REF: '##' NUMBER +(NTH-STACK #1) ;
 
(DEFUN PARSE-NON_DEST_REF NIL
  (AND (MATCH-ADVANCE-STRING "##")
       (MUST (PARSE-NUMBER))
       (PUSH-REDUCTION 'PARSE-NON_DEST_REF (CONS 'NTH-STACK (CONS (POP-STACK-1) NIL)))))
 
; DEST_REF:     '#' NUMBER +=(LIST (INTERN (STRCONC 'POP-STACK-' (STRINGIMAGE #1)))) ;
 
(DEFUN PARSE-DEST_REF NIL
  (AND (MATCH-ADVANCE-STRING "#")
       (MUST (PARSE-NUMBER))
       (PUSH-REDUCTION 'PARSE-DEST_REF
                       (LIST (INTERN (STRCONC "POP-STACK-" (STRINGIMAGE (POP-STACK-1))))))))
 
; LOCAL_VAR:    '$' (   IDENTIFIER / NUMBER +=(GETGENSYM #1) .(PUSH ##1 METAPGVAR)) ;
 
(DEFUN PARSE-LOCAL_VAR NIL
  (AND (MATCH-ADVANCE-STRING "$")
       (MUST (OR (PARSE-IDENTIFIER)
                 (AND (PARSE-NUMBER)
                      (PUSH-REDUCTION 'PARSE-LOCAL_VAR (GETGENSYM (POP-STACK-1)))
                      (ACTION (PUSH (NTH-STACK 1) METAPGVAR)))))))
 
; OPT_EXPR:     <'*' +(STAR OPT_EXPR #1) / REPEATOR> +(OPTIONAL #1) ;
 
(DEFUN PARSE-OPT_EXPR NIL
  (AND (OPTIONAL (OR (AND (MATCH-ADVANCE-STRING "*")
                          (PUSH-REDUCTION 'PARSE-OPT_EXPR
                                          (CONS 'STAR
                                                (CONS '|OPT_EXPR|
                                                      (CONS (POP-STACK-1) NIL)))))
                     (PARSE-REPEATOR)))
       (PUSH-REDUCTION 'PARSE-OPT_EXPR (CONS 'OPTIONAL (CONS (POP-STACK-1) NIL)))))
 
; REPEATOR:     ('*' / BSTRING +(AND (MATCH-ADVANCE-STRING #1) (MUST ##1)))
; +(STAR REPEATOR #1) ;
 
(DEFUN PARSE-REPEATOR NIL
  (AND (OR (MATCH-ADVANCE-STRING "*")
           (AND (PARSE-BSTRING)
                (PUSH-REDUCTION 'PARSE-REPEATOR
                                (CONS 'AND
                                      (CONS (CONS 'MATCH-ADVANCE-STRING
                                                  (CONS (POP-STACK-1) NIL))
                                            (CONS (CONS 'MUST (CONS (NTH-STACK 1) NIL))
                                                  NIL))))))
       (PUSH-REDUCTION 'PARSE-REPEATOR
                       (CONS 'STAR (CONS 'REPEATOR (CONS (POP-STACK-1) NIL))))))
 
; .FIN ;
