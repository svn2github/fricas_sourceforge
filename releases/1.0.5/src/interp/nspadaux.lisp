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

(defvar |$DEFdepth| 0)
(defvar |$localMacroStack| nil)
(defvar |$globalMacroStack| nil)
(defvar |$abbreviationStack| nil)
(defvar |$knownAttributes| nil "cumulative list of known attributes of a file") 

(setq |$underscoreChar| (|char| '_))
(defvar |$back| nil) 

(setq |$markChoices| '(ATOM COLON LAMBDA AUTOSUBSET AUTOHARD AUTOREP REPPER FREESI RETRACT))
(setq |$convert2NewCompiler| 'T)
(setq |$AnalyzeOnly| NIL)
(setq |$categoryPart| 'T)
(setq |$insideCAPSULE| nil)
(setq |$insideEXPORTS| nil)
(setq |$originalSignature| nil)
(setq |$insideDEF| nil)
(setq |$insideTypeExpression| nil)
(setq |$spadTightList| '(\.\. \# \'  \:\  \: \:\:))

(setq |$PerCentVariableList| '(%1 %2 %3 %4 %5 %6 %7 %8 %9 %10))

(mapcar #'(lambda (X) (MAKEPROP (CAR X) 'SPECIAL (CADR X)))
        '((PART |compPART|)
          (WI |compWI|)
          (MI |compWI|)))
        
(mapcar #'(lambda (X) (MAKEPROP (CAR X) 'PSPAD (CADR X)))
        '((|default| |formatDefault|)
          (|local| |formatLocal|)
          (COMMENT   |formatCOMMENT|)
          (CAPSULE |formatCAPSULE|)
          (LISTOF |formatPAREN|)
          (DEF    |formatDEF|)
          (SEQ    |formatSEQ|)
          (LET    |formatLET|)
          (\:    |formatColon|)
          (ELT    |formatELT|)
          (QUOTE |formatQUOTE|)
          (SEGMENT |formatSEGMENT|)
          (DOLLAR |formatDOLLAR|)
          (BRACE  |formatBrace|)
          (|dot|  |formatDot|)
          (MDEF |formatMDEF|)
          (|free| |formatFree|)
          (|elt|  |formatElt|)
          (PAREN |formatPAREN|)
          (PROGN |formatPROGN|)
          (|exit| |formatExit|)
          (|leave| |formatLeave|)
          (|void|  |formatvoid|)
          (MI   |formatMI|)
          (IF   |formatIF|)
          (\=\> |formatFATARROW|)
          (\+\-\> |formatMap|)
          (|Enumeration| |formatEnumeration|)
          (|import| |formatImport|)
          (UNCOERCE |formatUNCOERCE|)
          (CATEGORY |formatCATEGORY|)
          (SIGNATURE |formatSIGNATURE|)
          (|where| |formatWHERE|)
          (COLLECT   |formatCOLLECT|)
          (|MyENUM|    |formatENUM|)
          (REDUCE    |formatREDUCE|)
          (REPEAT    |formatREPEAT|)
          (ATTRIBUTE |formatATTRIBUTE|)
          (CONS      |formatCONS|)
          (|construct| |formatConstruct|)
          (|Union| |formatUnion|)
          (|Record| |formatRecord|)
          (|Mapping| |formatMapping|)
          (|Tuple|   |formatTuple|)
          (|with|  |formatWith|)
          (|withDefault| |formatWithDefault|)
          (|defaultDefs| |formatDefaultDefs|)
          (|add|   |formatAdd|)))

(remprop 'cons   '|Led|)
(remprop 'append 'format)
(remprop 'cons   'format)


