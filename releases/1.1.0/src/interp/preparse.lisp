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
NAME:    Pre-Parsing Code
PURPOSE: BOOT lines are massaged by PREPARSE to make them easier to parse:
       1. Trailing -- comments are removed (this is already done, actually).
       2. Comments between { and } are removed.
       3. BOOT code is column-sensitive. Code which lines up columnarly is
          parenthesized and semicolonized accordingly.  For example,

               a
                       b
                       c
                               d
               e

          becomes

               a
                       (b;
                        c
                               d)
               e

          Note that to do this correctly, we also need to keep track of
          parentheses already in the code.
|#

(provide 'Boot)

(in-package "BOOT")

; Global storage

(defparameter $INDEX 0                          "File line number of most recently read line.")
(defparameter $preparse-last-line ()            "Most recently read line.")
(defparameter $preparseReportIfTrue NIL         "Should we print listings?")
(defparameter $LineList nil                     "Stack of preparsed lines.")
(defparameter $EchoLineStack nil                "Stack of lines to list.")
(defparameter $IOIndex 0                        "Number of latest terminal input line.")

(defun Initialize-Preparse (strm)
  (setq $INDEX 0 $LineList nil $EchoLineStack nil)
  (setq $preparse-last-line (get-a-line strm)))

(defun PREPARSE (Strm &aux (stack ()))
  (SETQ $COMBLOCKLIST NIL $skipme NIL)
  (when $preparse-last-line
        (if (pairp $preparse-last-line)
            (setq stack $preparse-last-line)
          (push $preparse-last-line stack))
        (setq $INDEX (- $INDEX (length stack))))
  (let ((U (PREPARSE1 stack)))
    (if $skipme (preparse strm)
      (progn
        (if $preparseReportIfTrue (PARSEPRINT U))
        (setq |$headerDocumentation| NIL)
        (SETQ |$docList| NIL)
        (SETQ |$maxSignatureLineNumber| 0)
        U))))

(defmacro DCQPAIR (x y)
   (let ((sym (gensym)))
     `(let ((,sym ,y))
	    (setf ,(car x) (car ,sym))
	    (setf ,(cdr x) (cdr ,sym)))))

(defun PREPARSE1 (LineList)
 (PROG (($LINELIST LineList) $EchoLineStack NUM A I L PSLOC
        INSTRING PCOUNT COMSYM STRSYM OPARSYM CPARSYM N NCOMSYM
        (SLOC -1) (CONTINUE NIL)  (PARENLEV 0) (NCOMBLOCK ())
        (LINES ()) (LOCS ()) (NUMS ()) functor  )
 READLOOP (DCQPAIR (NUM . A) (preparseReadLine LineList))
         (cond ((atEndOfUnit A)
                (PREPARSE-ECHO LineList)
                (COND ((NULL LINES) (RETURN NIL))
                      (NCOMBLOCK
                       (FINCOMBLOCK NIL NUMS LOCS NCOMBLOCK NIL)))
                (RETURN (PAIR (NREVERSE NUMS)
                              (PARSEPILES (NREVERSE LOCS) (NREVERSE LINES))))))
         (cond ((and (NULL LINES) (> (LENGTH A) 0) (EQ (CHAR A 0) #\) ))
                ; this is a command line, don't parse it
                (PREPARSE-ECHO LineList)
                (setq $preparse-last-line nil) ;don't reread this line
                (SETQ LINE a)
                (CATCH 'SPAD_READER (|doSystemCommand| (subseq LINE 1)))
                (GO READLOOP)))
         (setq L (LENGTH A))
         (if (EQ L 0) (GO READLOOP))
         (setq PSLOC SLOC)
         (setq I 0 INSTRING () PCOUNT 0)
 STRLOOP (setq STRSYM (OR (position #\" A :start I ) L))
         (setq COMSYM (OR (search "--" A :start2 I ) L))
         (setq NCOMSYM (OR (search "++" A :start2 I ) L))
         (setq OPARSYM (OR (position #\( A :start I ) L))
         (setq CPARSYM (OR (position #\) A :start I ) L))
         (setq N (MIN STRSYM COMSYM NCOMSYM OPARSYM CPARSYM))
         (cond ((= N L) (GO NOCOMS))
               ((ESCAPED A N))
               ((= N STRSYM) (setq INSTRING (NOT INSTRING)))
               (INSTRING)
               ((= N COMSYM) (setq A (subseq A 0 N)) (GO NOCOMS)) ; discard trailing comment
               ((= N NCOMSYM)
                (setq SLOC (INDENT-POS A))
                (COND
                  ((= SLOC N)
                   (COND ((AND NCOMBLOCK (NOT (= N (CAR NCOMBLOCK))))
                          (FINCOMBLOCK NUM NUMS LOCS NCOMBLOCK linelist)
                          (SETQ NCOMBLOCK NIL)))
                   (SETQ NCOMBLOCK (CONS N (CONS A (IFCDR NCOMBLOCK))))
                   (SETQ A ""))
                  ('T (PUSH (STRCONC (GETFULLSTR N " ")
                                  (SUBSTRING A N ())) $LINELIST)
                      (SETQ $INDEX (SUB1 $INDEX))
                      (SETQ A (SUBSEQ A 0 N))))
         (GO NOCOMS))
               ((= N OPARSYM) (setq PCOUNT (1+ PCOUNT)))
               ((= N CPARSYM) (setq PCOUNT (1- PCOUNT))))
         (setq I (1+ N))
         (GO STRLOOP)
 NOCOMS  (setq SLOC (INDENT-POS A))
         (setq A (DROPTRAILINGBLANKS A))
         (cond ((NULL SLOC) (setq SLOC PSLOC) (GO READLOOP)))
         (cond ((EQ (ELT A (MAXINDEX A)) XCAPE)
                (setq CONTINUE T a (subseq A (MAXINDEX A))))
               ((setq CONTINUE NIL)))
         (if (and (null LINES) (= SLOC 0)) ;;test for skipping constructors
             (if (and |$byConstructors|
                      (null (search "==>" a))
                      (not (member (setq functor (intern
                                    (substring a 0 (STRPOSL ": (=" A 0 NIL))))
                                   |$byConstructors|)))
                 (setq $skipme 't)
               (progn (push functor |$constructorsSeen|) (setq $skipme nil))))
         (when (and LINES (EQL SLOC 0))
             (IF (AND NCOMBLOCK (NOT (ZEROP (CAR NCOMBLOCK))))
               (FINCOMBLOCK NUM NUMS LOCS NCOMBLOCK linelist))
             (IF (NOT (IS-CONSOLE in-stream))
                 (setq $preparse-last-line
                       (nreverse $echolinestack)))
             (RETURN (PAIR (NREVERSE NUMS)
                        (PARSEPILES (NREVERSE LOCS) (NREVERSE LINES)))))
         (cond ((> PARENLEV 0) (PUSH NIL LOCS) (setq SLOC PSLOC) (GO REREAD)))
         (COND (NCOMBLOCK
                (FINCOMBLOCK NUM NUMS LOCS NCOMBLOCK linelist)
                (setq NCOMBLOCK ())))
         (PUSH SLOC LOCS)
 REREAD  (PREPARSE-ECHO LineList)
         (PUSH A LINES)
         (PUSH NUM NUMS)
         (setq PARENLEV (+ PARENLEV PCOUNT))
         (when (and (is-console in-stream) (not continue))
            (setq $preparse-last-line nil)
             (RETURN (PAIR (NREVERSE NUMS)
                           (PARSEPILES (NREVERSE LOCS) (NREVERSE LINES)))))

         (GO READLOOP)))

;; NUM is the line number of the current line
;; OLDNUMS is the list of line numbers of previous lines
;; OLDLOCS is the list of previous indentation locations
;; NCBLOCK is the current comment block
(DEFUN FINCOMBLOCK (NUM OLDNUMS OLDLOCS NCBLOCK linelist)
  (PUSH
    (COND ((EQL (CAR NCBLOCK) 0) (CONS (1- NUM) (REVERSE (CDR NCBLOCK))))
              ;; comment for constructor itself paired with 1st line -1
          ('T
           (COND ($EchoLineStack
                  (setq NUM (POP $EchoLineStack))
                  (PREPARSE-ECHO linelist)
                  (SETQ $EchoLineStack (LIST NUM))))
           (cons
            ;; scan backwards for line to left of current
            (DO ((onums oldnums (cdr onums))
                 (olocs oldlocs (cdr olocs))
                 (sloc (car ncblock)))
                ((null onums) nil)
                (if (and (numberp (car olocs))
                         (<= (car olocs) sloc))
                    (return (car onums))))
            (REVERSE (CDR NCBLOCK)))))
    $COMBLOCKLIST))

(defun PARSEPRINT (L)
  (if L
      (progn (format t "~&~%       ***       PREPARSE      ***~%~%")
             (dolist (X L) (format t "~5d. ~a~%" (car x) (cdr x)))
             (format t "~%"))))

(DEFUN STOREBLANKS (LINE N)
   (DO ((I 0 (ADD1 I))) ((= I N) LINE) (SETF (CHAR LINE I) #\ )))

(DEFUN INITIAL-SUBSTRING (PATTERN LINE)
   (let ((ind (mismatch PATTERN LINE)))
     (OR (NULL IND) (EQL IND (SIZE PATTERN)))))

(DEFUN SKIP-IFBLOCK (X)
   (PROG (LINE IND)
     (DCQPAIR (IND . LINE) (preparseReadLine1 X))
      (IF (NOT (STRINGP LINE))  (RETURN (CONS IND LINE)))
      (IF (ZEROP (SIZE LINE)) (RETURN (SKIP-IFBLOCK X)))
      (COND ((CHAR= (ELT LINE 0) #\) )
          (COND
            ((INITIAL-SUBSTRING ")if" LINE)
                (COND ((EVAL (|string2BootTree| (STOREBLANKS LINE 3)))
                       (RETURN (preparseReadLine X)))
                      ('T (RETURN (SKIP-IFBLOCK X)))))
            ((INITIAL-SUBSTRING ")elseif" LINE)
                (COND ((EVAL (|string2BootTree| (STOREBLANKS LINE 7)))
                       (RETURN (preparseReadLine X)))
                      ('T (RETURN (SKIP-IFBLOCK X)))))
            ((INITIAL-SUBSTRING ")else" LINE)
             (RETURN (preparseReadLine X)))
            ((INITIAL-SUBSTRING ")endif" LINE)
             (RETURN (preparseReadLine X)))
            ((INITIAL-SUBSTRING ")fin" LINE)
             (RETURN (CONS IND NIL))))))
      (RETURN (SKIP-IFBLOCK X)) ) )

(DEFUN SKIP-TO-ENDIF (X)
   (PROG (LINE IND)
     (DCQPAIR (IND . LINE) (preparseReadLine1 X))
      (COND ((NOT (STRINGP LINE)) (RETURN (CONS IND LINE)))
            ((INITIAL-SUBSTRING LINE ")endif")
             (RETURN (preparseReadLine X)))
            ((INITIAL-SUBSTRING LINE ")fin") (RETURN (CONS IND NIL)))
            ('T (RETURN (SKIP-TO-ENDIF X))))))

(DEFUN preparseReadLine (X)
    (PROG (LINE IND)
      (DCQPAIR (IND . LINE) (preparseReadLine1 X))
      (COND ((NOT (STRINGP LINE)) (RETURN (CONS IND LINE))))
      (COND ((ZEROP (SIZE LINE))
             (RETURN (CONS IND LINE))))
      (COND ((CHAR= (ELT LINE 0) #\) )
          (COND
            ((INITIAL-SUBSTRING ")if" LINE)
                (COND ((EVAL (|string2BootTree| (STOREBLANKS LINE 3)))
                       (RETURN (preparseReadLine X)))
                      ('T (RETURN (SKIP-IFBLOCK X)))))
            ((INITIAL-SUBSTRING ")elseif" LINE)
             (RETURN (SKIP-TO-ENDIF X)))
            ((INITIAL-SUBSTRING ")else" LINE)
             (RETURN (SKIP-TO-ENDIF X)))
            ((INITIAL-SUBSTRING ")endif" LINE)
             (RETURN (preparseReadLine X)))
            ((and $BOOT
                  (INITIAL-SUBSTRING #|(|# ")package" LINE)
                  (equal
                          (string-trim '(#\Space) (SUBSEQ LINE 9))
                          "\"BOOT\""))
                  (RETURN (preparseReadLine X)))
            ((INITIAL-SUBSTRING ")fin" LINE)
             (SETQ *EOF* T)
             (RETURN (CONS IND NIL)) ) )))
      (RETURN (CONS IND LINE)) ))

(DEFUN preparseReadLine1 (X)
    (PROG (LINE IND)
      (SETQ LINE (if $LINELIST
                     (pop $LINELIST)
              (expand-tabs (get-a-line in-stream))))
      (setq $preparse-last-line LINE)
      (and (stringp line) (incf $INDEX))
      (COND
        ( (NOT (STRINGP LINE))
          (RETURN (CONS $INDEX LINE)) ) )
      (SETQ LINE (DROPTRAILINGBLANKS LINE))
      (PUSH (COPY-SEQ LINE) $EchoLineStack)
    ;; next line must evaluate $INDEX before recursive call
      (RETURN
        (CONS
          $INDEX
          (COND
            ( (AND (> (SETQ IND (MAXINDEX LINE)) -1) (char= (ELT LINE IND) #\_))
              (setq $preparse-last-line
                    (STRCONC (SUBSTRING LINE 0 IND) (CDR (preparseReadLine1 X))) ))
            ( 'T
              LINE ) ))) ) )

;;(defun preparseReadLine (X)
;;  (declare (special $LINELIST $echoLineStack))
;;  (PROG (LINE IND)
;;        (setq LINE
;;              (if $LINELIST
;;                  (pop $LINELIST)
;;                  (get-a-line in-stream)))
;;        (setq $preparse-last-line LINE)
;;        (and (stringp line) (incf $INDEX))
;;        (if (NOT (STRINGP LINE)) (RETURN (CONS $INDEX LINE)))
;;        (setq LINE (DROPTRAILINGBLANKS LINE))
;;        (if Echo-Meta (PUSH (COPY-SEQ LINE) $EchoLineStack))
;;        ; next line must evaluate $INDEX before recursive call
;;        (RETURN
;;          (CONS $INDEX
;;                (if (and (> (setq IND (MAXINDEX LINE)) -1)
;;                       (EQ (ELT LINE IND) #\_))
;;                    (setq $preparse-last-line
;;                        (STRCONC (SUBSEQ LINE 0 IND)
;;                                 (CDR (preparseReadLine X))))
;;                    LINE)))))

(defun PREPARSE-ECHO (linelist)
  (if Echo-Meta (REPEAT (IN X (REVERSE $EchoLineStack))
                        (format out-stream "~&;~A~%" X)))
  (setq $EchoLineStack ()))

(defun ESCAPED (STR N) (and (> N 0) (EQ (CHAR STR (1- N)) XCAPE)))

(defun atEndOfUnit (X) (NULL (STRINGP X)) )

(defun PARSEPILES (LOCS LINES)
  "Add parens and semis to lines to aid parsing."
  (mapl #'add-parens-and-semis-to-line (NCONC LINES '(" ")) (nconc locs '(nil)))
  LINES)

(defun add-parens-and-semis-to-line (slines slocs)

  "The line to be worked on is (CAR SLINES).  It's indentation is (CAR SLOCS).  There
is a notion of current indentation. Then:

A. Add open paren to beginning of following line if following line's indentation
   is greater than current, and add close paren to end of last succeeding line
   with following line's indentation.
B. Add semicolon to end of line if following line's indentation is the same.
C. If the entire line consists of the single keyword then or else, leave it alone."

  (let ((start-column (car slocs)))
    (if (and start-column (> start-column 0))
        (let ((count 0) (i 0))
          (seq
           (mapl #'(lambda (next-lines nlocs)
                     (let ((next-line (car next-lines)) (next-column (car nlocs)))
                       (incf i)
                       (if next-column
                           (progn (setq next-column (abs next-column))
                                  (if (< next-column start-column) (exit nil))
                                  (cond ((and (eq next-column start-column)
                                              (rplaca nlocs (- (car nlocs)))
                                              (not (infixtok next-line)))
                                         (setq next-lines (DROP (1- i) slines))
                                         (rplaca next-lines (addclose (car next-lines) #\;))
                                         (setq count (1+ count))))))))
                 (cdr slines) (cdr slocs)))
          (if (> count 0)
              (progn (setf (char (car slines) (1- (nonblankloc (car slines))))
                           #\( )
                     (setq slines (DROP (1- i) slines))
                     (rplaca slines (addclose (car slines) #\) ))))))))

(defun INFIXTOK (S) (MEMBER (STRING2ID-N S 1) '(|then| |else|) :test #'eq))


(defun ADDCLOSE (LINE CHAR)
  (cond ((char= (FETCHCHAR LINE (MAXINDEX LINE)) #\; )
         (SETELT LINE (MAXINDEX LINE) CHAR)
         (if (char= CHAR #\;) LINE (suffix #\; LINE)))
        ((suffix char LINE))))
