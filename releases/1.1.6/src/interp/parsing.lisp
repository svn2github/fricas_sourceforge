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


; NAME:    META/LISP Parser Generator and Lexical Analysis Utilities (Parsing)
;
; PURPOSE: This package provides routines to support the Metalanguage
;          translator writing system.   Metalanguage is described
;          in META/LISP, R.D. Jenks, Tech Report, IBM T.J. Watson Research Center,
;          1969.  Familiarity with this document is assumed.
;
;          The parser generator itself is described in either the file
;          MetaBoot.lisp (hand-coded version) or the file MetaMeta.lisp (machine
;          generated from self-descriptive Meta code), both of which load themselves
;          into package Parsing.

; CONTENTS:
;
;       0. Current I/O Stream definition
;
;       1. Data structure declarations (defstructs) for parsing objects
;
;               A. Line Buffer
;               B. Stack
;               C. Token
;               D. Reduction
;
;       2. Recursive descent parsing support routines
;               A. Stacking and retrieving reductions of rules.
;               B. Applying metagrammatical elements of a production (e.g., Star).
;
;       3. Routines for handling lexical scanning
;
;               A. Manipulating the token stack and reading tokens
;               B. Error handling
;               C. Constructing parsing procedures
;               D. Managing rule sets
;
;       4. Tracing routines
;
;       5. Routines for inspecting and resetting total I/O system state
;
;       METALEX.LISP:  Meta file handling, auxiliary parsing actions and tokenizing
;       METAMETA.LISP: Meta parsing
;
;       BOOTLEX.LISP:  Boot file handling, auxiliary parsing actions and tokenizing
;       NEWMETA.LISP:  Boot parsing

(in-package "BOOT")

; 0. Current I/O Stream definition

(defparameter in-stream  t "Current input stream.")
(defparameter out-stream t "Current output stream.")
(defparameter File-Closed nil   "Way to stop EOF tests for console input.")

; 1. Data structure declarations (defstructs) for parsing objects
;
;               A. Line Buffer
;               B. Stack
;               C. Token
;               D. Reduction

; 1A. A Line Buffer
;
; The philosophy of lines is that
;
;       a) NEXT LINE will always get you a non-blank line or fail.
;       b) Every line is terminated by a blank character.
;
; Hence there is always a current character, because there is never a non-blank line,
; and there is always a separator character between tokens on separate lines.
; Also, when a line is read, the character pointer is always positioned ON the first
; character.

; FUNCTIONS DEFINED IN THIS SECTION:
;
;       Line-Buffer, Line-Current-Char, Line-Current-Index, Line-Last-Index, Line-Number
;       Line-New-Line, Line-Advance-Char, Line-Past-End-P, Line-At-End-P
;       Make-Line

(defstruct Line "Line of input file to parse."
           (Buffer (make-string 0) :type string)
           (Current-Char #\Return :type character)
           (Current-Index 1 :type fixnum)
           (Last-Index 0 :type fixnum)
           (Number 0 :type fixnum))

(defun Line-Print (line)
  (format out-stream "~&~5D> ~A~%" (Line-Number line) (Line-Buffer Line))
  (format out-stream "~v@T^~%" (+ 7 (Line-Current-Index line))))

(defun Line-Clear (line)
  (let ((l line))
     (setf (Line-Buffer l) (make-string 0)
           (Line-Current-Char l) #\Return
           (Line-Current-Index l) 1
           (Line-Last-Index l) 0
           (Line-Number l) 0)))

(defun Line-New-Line (string line &optional (linenum nil))
  "Sets string to be the next line stored in line."
  (setf (Line-Last-Index line) (1- (length string))
        (Line-Current-Index line) 0
        (Line-Current-Char line) (or (and (> (length string) 0) (elt string 0)) #\Return)
        (Line-Buffer line) string
        (Line-Number line) (or linenum (1+ (Line-Number line)))))

(defun Line-Advance-Char (line)
  (setf (Line-Current-Char line)
        (elt (Line-Buffer line) (incf (Line-Current-Index line)))))

(defun Line-Next-Char (line)
  (elt (Line-Buffer line) (1+ (Line-Current-Index line))))

(defun Line-Past-End-P (line)
  "Tests if line is empty or positioned past the last character."
  (> (line-current-index line) (line-last-index line)))

(defun Line-At-End-P (line)
  "Tests if line is empty or positioned past the last character."
  (>= (line-current-index line) (line-last-index line)))

; 1C. Token

; FUNCTIONS DEFINED IN THIS SECTION:
;
;       Make-Token, Token-Symbol, Token-Type, Token-Install, Token-Print

(defstruct Token
  "A token is a Symbol with a Type.
The type is either NUMBER, IDENTIFIER or SPECIAL-CHAR.
NonBlank is true if the token is not preceded by a blank."
  (Symbol nil)
  (Type nil)
  (NonBlank t)
)

(defparameter Prior-Token (make-token) "What did I see last")
(defparameter nonblank t "Is there no blank in front of the current token.")
(defparameter Current-Token (make-token) "Token at head of input stream.")
(defparameter Next-Token (make-token)    "Next token in input stream.")
(defparameter Valid-Tokens 0               "Number of tokens in buffer (0, 1 or 2)")

(defun Token-Install (symbol type token &optional (nonblank t))
  (setf (token-symbol token) symbol (token-type token) type
        (token-nonblank token) nonblank
  )
  token)

(defun Token-Print (token)
  (format out-stream "(token (symbol ~S) (type ~S))~%"
          (Token-Symbol token) (Token-Type token)))

; 1D. A Reduction
;

; 2. Recursive descent parsing support routines (semantically related to MetaLanguage)
;
; This section of the code contains:
;
;               A. Routines for stacking and retrieving reductions of rules.
;               B. Routines for applying certain metagrammatical elements
;                  of a production (e.g., Star).
;               C. Token-level parsing utilities (keywords, strings, identifiers).

; 2A. Routines for stacking and retrieving reductions of rules.

; FUNCTIONS DEFINED IN THIS SECTION:
;
;       Push-Reduction Pop-Reduction

(defun |next_symbol|() (NEXT-SYMBOL))

; 2B. Routines for applying certain metagrammatical elements
;     of a production (e.g., Star).

; Must means that if it is not present in the token stream, it is a syntax error.

; FUNCTIONS DEFINED IN THIS SECTION:
;
;       MUST, OPTIONAL, ACTION

(defun MUST(dothis) (or dothis (meta-syntax-error nil nil)))

; Optional means that if it is present in the token stream, that is a good thing,
; otherwise don't worry (like [ foo ] in BNF notation).

(defun OPTIONAL (dothis) (or dothis t))

; Action is something we do as a consequence of successful parsing; it is
; inserted at the end of the conjunction of requirements for a successful
; parse, and so should return T.

(defun ACTION (dothis) (or dothis t))

; 3. Routines for handling lexical scanning
;
; Lexical scanning of tokens is performed off of the current line.  No
; token can span more than 1 line.  All real I/O is handled in a line-oriented
; fashion (in a slight paradox) below the character level.  All character
; routines implicitly assume the parameter Current-Line.  We do not make
; Current-Line an explicit optional parameter for reasons of efficiency.

(defparameter prev-line nil)
(defparameter prev-line-number 0)

(defun prev-line-show ()
    (if prev-line
        (format t "~&The prior line was:~%~%~5D> ~A~%~%"
               prev-line-number prev-line)
        (format t "~&The prior line is empty.~%")))

(defun prev-line-set (l)
    (if (> (Line-Last-Index l) 0)
        (progn
            (setf prev-line (Line-Buffer l))
            (setf prev-line-number (Line-Number l)))))

(defun prev-line-clear ()
    (setf prev-line nil))

(defparameter Current-Line (make-line)  "Current input line.")

(defmacro current-line-print () '(Line-Print Current-Line))

(defmacro current-line-show ()
  `(if (line-past-end-p current-line)
       (format t "~&The current line is empty.~%")
       (progn (format t "~&The current line is:~%~%")
              (current-line-print))))

(defmacro current-line-clear () `(Line-Clear Current-Line))

; 3A.  Manipulating the token stack and reading tokens

; This section is broken up into 3 levels:
;
;       (1) Token handling:     Current Token, Next Token, Advance Token
;       (2) Character handling: Current Char, Next Char, Advance Char
;       (3) Line handling:      Next Line, Print Next Line
;       (X) Random Stuff


; 3A (1) Token Handling.

; Tokens are acquired from a stream of characters.  Lexical analysis is performed
; by the functiond Get Token.  One-token lookahead is maintained in variables
; Current-Token and Next-Token by procedures Current Token, Next Token, and
; Advance Token.  The functions Match Current Token and Match Next Token recognize
; classes of tokens, by type, or by type and symbol.  The current and next tokens
; can be shoved back on the input stream (to the current line) with Unget-Tokens.

(defun token-stack-show ()
  (if (= Valid-Tokens 0) (format t "~%There are no valid tokens.~%")
      (format t "~%The number of valid tokens is ~S.~%" Valid-Tokens))
 (if (token-type prior-token)
      (progn (format t "The prior token was ~S~%" prior-token)
             ))
  (if (> Valid-Tokens 0)
      (progn (format t "The current token is ~S~%" current-token)
             ))
  (if (> Valid-Tokens 1)
      (progn (format t "The next token is ~S~%" next-token)
             ))
)

(defmacro token-stack-clear ()
  `(progn (setq Valid-Tokens 0)
          (token-install nil nil current-token nil)
          (token-install nil nil next-token nil)
          (token-install nil nil prior-token nil)))

; *** Match Token

(defun match-token (token type &optional (symbol nil))
  (if (and token (eq (token-type token) type))
      (if symbol (if (eq symbol (token-symbol token)) token) token)))

(defun |match_current_token|(type symbol)
  "Returns the current token if it has EQ type and (optionally) equal symbol."
  (match-token (current-token) type symbol))

(defun |match_next_token|(type symbol)
  "Returns the next token if it has equal type and (optionally) equal symbol."
  (match-token (next-token) type symbol))

; *** Current Token, Next Token, Advance Token

(defun try-get-token (token)
  (let ((tok (get-token token)))
    (if tok (progn (incf Valid-Tokens) token))))

(defun |current_symbol|() (make-symbol-of (current-token)))

(defun next-symbol () (make-symbol-of (next-token)))

(defun make-symbol-of (token)
  (let ((u (and token (token-symbol token))))
    (cond ((not u) nil)
          (u))))

(defun current-token ()
  "Returns the current token getting a new one if necessary."
  (if (> Valid-Tokens 0)
      Current-Token
      (try-get-token Current-Token)))

(defun next-token ()
  "Returns the token after the current token, or NIL if there is none after."
  (current-token)
  (if (> Valid-Tokens 1)
      Next-Token
      (progn
          (try-get-token Next-Token))))

(defun |advance_token|()
  (current-token)                       ;don't know why this is needed
  "Makes the next token be the current token."
  (case Valid-Tokens
    (0 (try-get-token (Current-Token)))
    (1 (decf Valid-Tokens)
       (setq Prior-Token (copy-token Current-Token))
       (try-get-token Current-Token))
    (2 (setq Prior-Token (copy-token Current-Token))
       (setq Current-Token (copy-token Next-Token))
       (decf Valid-Tokens))))

(defparameter XTokenReader 'get-boot-token "Tokenizing function")

; *** Get Token

(defun get-token (token) (funcall XTokenReader token))

; 3A (2) Character handling.

; FUNCTIONS DEFINED IN THIS SECTION:
;
;       Current-Char, Next-Char, Advance-Char

; *** Current Char, Next Char, Advance Char

(defun Current-Char-Index ()
  (line-current-index Current-Line))

(defun Line-subseq-from (x)
    (subseq (Line-Buffer Current-Line)
            x (line-current-index Current-Line)))

(defun Current-Char ()
  "Returns the current character of the line, initially blank for an unread line."
  (if (Line-Past-End-P Current-Line) #\Return (Line-Current-Char Current-Line)))

(defun Next-Char ()
   "Returns the character after the current character, blank if at end of line.
The blank-at-end-of-line assumption is allowable because we assume that end-of-line
is a token separator, which blank is equivalent to."

  (if (Line-At-End-P Current-Line) #\Return (Line-Next-Char Current-Line)))

(defun Advance-Char ()
  "Advances IN-STREAM, invoking Next Line if necessary."
  (loop (cond ((not (Line-At-End-P Current-Line))
               (return (Line-Advance-Char Current-Line)))
              ((next-line in-stream)
               (return (current-char)))
              ((return nil)))))

; 3A 3. Line Handling.

; PARAMETERS DEFINED IN THIS SECTION:
;

; *** Next Line

(defparameter Line-Handler 'next-BOOT-line "Who grabs lines for us.")

(defun next-line (&optional (in-stream t)) (funcall Line-Handler in-stream))

(defun make-string-adjustable (s)
  (cond ((adjustable-array-p s) s)
        (t (make-array (array-dimensions s) :element-type 'character
                       :adjustable t :initial-contents s))))

(defun get-a-line (stream)
  (let ((ll (read-a-line stream)))
    (if (stringp ll) (make-string-adjustable ll) ll)))

(defun read-a-line (&optional (stream t))
   (let ((line (read-line stream nil nil)))
      (if (null line)
           (progn (setq File-Closed t *EOF* t)
                  (Line-New-Line (make-string 0) Current-Line)
                   nil)
          line)))

; 3B. Error handling

(defparameter line nil)

(defparameter Meta_Error_Handler nil)

(defun meta-syntax-error (&optional (wanted nil) (parsing nil))
  (funcall Meta_Error_Handler wanted parsing))

;       5. Routines for inspecting and resetting total I/O system state
;
; The package largely assumes that:
;
;       A. One I/O stream pair is in effect at any moment.
;       B. There is a Current Line
;       C. There is a Current Token and a Next Token
;       D. There is a Reduction Stack
;
; This state may be examined and reset with the procedures IOSTAT and IOCLEAR.

(defun IOStat ()
  "Tell me what the current state of the parsing world is."
  (prev-line-show)
  (current-line-show)
  (if (or $BOOT $SPAD) (next-lines-show))
  (token-stack-show)
  ;(reduce-stack-show)
  nil)

(defun IOClear ()
  (current-line-clear)
  (token-stack-clear)
  (if (or $BOOT $SPAD) (next-lines-clear))
  nil)

