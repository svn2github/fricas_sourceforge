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


;;; This is the package that originally contained the VMLisp macros
;;; but in fact contains macros to support several other lisps. It
;;; is essentially the place where most of the macros to support
;;; idioms from prior ports (like rdefiostream and fileactq)
(make-package "VMLISP" :use '("AXIOM-LISP"))

;;; This is the boot to lisp compiler package which contains the
;;; src/boot files. Tt is the boot translator package.
(make-package "BOOTTRAN" :use '("AXIOM-LISP"))

;;; Everything in axiom that the user references eventually shows
;;; up here. The interpreter and the algebra are run after switching
;;; to the boot package (in-package "BOOT") so any symbol that the
;;; interpreter or algebra uses has to (cough, cough) appear here.
(make-package "BOOT" :use '("VMLISP" "AXIOM-LISP"))

;;; FOAM is the intermediate language for the aldor compiler. FOAM
;;; means "first order abstract machine" and functions similar to
;;; RTL for the GCC compiler. It is a "machine" that is used as the
;;; target for meta-assembler level statments. These are eventually
;;; expanded for the real target machine (or interpreted directly)
(make-package "FOAM" :use '("AXIOM-LISP"))

;;; FOAM-USER is the package containing foam statements and macros
;;; that get inserted into user code versus the foam package which
;;; provides support for compiler code.
(make-package "FOAM-USER" :use '("AXIOM-LISP" "FOAM"))

(in-package "BOOT")

(import
    '(VMLISP::NE VMLISP::FLUID
         AXIOM-LISP:SEQUENCE VMLISP::OBEY VMLISP::|union|
         VMLISP::OPTIONLIST VMLISP::EXIT VMLISP::throw-protect
         VMLISP::*INDEX-FILENAME*))
(export
    '(BOOT::|$FormalMapVariableList| BOOT::|$userModemaps|
         boot::restart boot::$IEEE
         BOOT::|directoryp| BOOT::|makedir| boot::help boot::|version| boot::|pp|
         BOOT::POP-STACK-4 BOOT::|$BasicDomains| BOOT::|$DomainFrame|
         BOOT::|$SideEffectFreeFunctionList|
         BOOT::ATOM2STRING BOOT::|$DoubleQuote| BOOT::|$genSDVar|
         BOOT::GETCHARN BOOT::DROP
         BOOT::MATCH-STRING BOOT::|$fromSpadTrace|
         BOOT::|$UserSynonyms| BOOT::%L BOOT::FLUIDVARS
         BOOT::/EMBEDREPLY BOOT::|$LocalFrame| BOOT::|$streamIndexing|
         BOOT::APPLYR BOOT::NEXTINPUTLINE BOOT::$NORMALSTRING
         BOOT::|$InteractiveTimingStatsIfTrue| BOOT::|$leaveLevelStack|
         BOOT::|$xyMin| BOOT::|lcm| BOOT::STRINGSUFFIX
         BOOT::|Category| BOOT::ESCAPE-CHARACTER
         BOOT::|break| BOOT::$DIRECTORY
         BOOT::CONVERSATION BOOT::|fillerSpaces|
         BOOT::$REVERSEVIDEOSTRING BOOT::|$DomainsInScope|
         BOOT::|$gauss01| BOOT::|$mostRecentOpAlist| BOOT::SUBLISLIS
         BOOT::QUITFILE BOOT::|PrintBox| BOOT::POP-REDUCTION
         BOOT::META-SYNTAX-ERROR BOOT::|$constructorInfoTable|
         BOOT::|$currentLine| BOOT::|$Float| BOOT::|$slamFlag|
         BOOT::|$SmallIntegerOpt| BOOT::$SPAD BOOT::|$timerOn|
         BOOT::$TRACELETFLAG VMLISP::NE BOOT::ADJCURMAXINDEX
         BOOT::STREAM-BUFFER BOOT::SPADSLAM BOOT::$EM
         BOOT::|$PositiveIntegerOpt| BOOT::THETA BOOT::READ-QUIETLY
         BOOT::RS BOOT::|$compUniquelyIfTrue|
         BOOT::|$insideExpressionIfTrue| BOOT::LE BOOT::KAR BOOT::ELEM
         BOOT::LASTATOM BOOT::IN-STREAM BOOT::$DELAY
         BOOT::QSEXPT BOOT::|$quadSymbol| BOOT::|$streamAlist|
         BOOT::|$SymbolOpt| BOOT::TAKE BOOT::CONSOLEINPUTP
         BOOT::|$hasYield| BOOT::DEBUGMODE BOOT::|$DummyFunctorNames|
         BOOT::|$PositiveInteger| BOOT::%D VMLISP::FLUID BOOT::TLINE
         BOOT::|$abbreviationTable| BOOT::|$FontTable|
         BOOT::|$PatternVariableList| BOOT::|$returnMode| BOOT::NEQUAL
         BOOT::GE BOOT::|MakeSymbol| BOOT::|$insideWhereIfTrue|
         BOOT::|$mapSubNameAlist| BOOT::GETCHAR BOOT::|Gaussian|
         BOOT::IDENTIFIER BOOT::|$LastCxArg| BOOT::|$systemCommands|
         BOOT::|$true| BOOT::SETANDFILE BOOT::PUSH-REDUCTION
         BOOT::|$BigFloat| BOOT::|$brightenCommentsFlag|
         BOOT::|$cacheCount| BOOT::|$exitModeStack| BOOT::|$noEnv|
         BOOT::|$NonPositiveIntegerOpt| BOOT::PUTGCEXIT
         BOOT::|$readingFile|
         BOOT::IS BOOT::KDR BOOT::|$quadSym| BOOT::|$BreakMode|
         BOOT::$TOKSTACK BOOT::DEFSTREAM BOOT::LOCVARS BOOT::NTH-STACK
         BOOT::$UNDERLINESTRING BOOT::|$compCount|
         BOOT::|$lisplibModemapAlist| BOOT::COMP BOOT::LINE
         BOOT::GETGENSYM BOOT::$FUNNAME BOOT::|$SystemSynonyms|
         BOOT::|$spadOpList| BOOT::GENERAL BOOT::|$fortranOutputStream|
         BOOT::META_PREFIX BOOT::|$InteractiveMode| BOOT::|strconc|
         BOOT::TAILFN BOOT::RPLACW BOOT::|PositiveInteger|
         BOOT::|$inactiveLisplibs| BOOT::|$NonPositiveInteger|
         BOOT::|$reportCoerceIfTrue|
         BOOT::|sayBrightlyNT| BOOT::NEXT-CHAR boot::|sayString|
         BOOT::META_ERRORS_OCCURRED BOOT::|$resolveFlag|
         BOOT::|$StringOpt| BOOT::|UnivariatePoly| BOOT::MATCH-TOKEN
         BOOT::|$createUpdateFiles| BOOT::|$noParseCommands|
         BOOT::FLAGP BOOT::ECHO-META BOOT::|initializeSetVariables|
         BOOT::|$CategoryNames| BOOT::?ORDER
         BOOT::$FILELINENUMBER BOOT::|$timerTicksPerSecond|
         BOOT::|bootUnionPrint| BOOT::|$consistencyCheck|
         BOOT::|$oldTime| BOOT::$NEWSPAD BOOT::NUMOFNODES
         BOOT::|$ResMode| BOOT::S* BOOT::TRANSPGVAR BOOT::$BOXSTRING
         BOOT::|$BasicPredicates| BOOT::|$eltIfNil| BOOT::$FUNNAME_TAIL
         BOOT::|$QuickCode| BOOT::GENVAR BOOT::|$TypeEqui|
         BOOT::TOKEN-TYPE BOOT::|updateSourceFiles| BOOT::|$BFtag|
         BOOT::|$reportBottomUpFlag| BOOT::|$SmallInteger|
         BOOT::|$TypeEQ| BOOT::|Boolean| BOOT::|RationalNumber|
         BOOT::MAKENEWOP BOOT::|$EmptyList| BOOT::|$leaveMode|
         BOOT::MKQ BOOT::ON BOOT::CONTAINED BOOT::|conOutStream|
         BOOT::POINTW BOOT::REDUCTION-POP-ELT BOOT::TOKEN-SYMBOL
         BOOT::ERRCOL BOOT::|$domainTraceNameAssoc| BOOT::SUBSTEQ
         BOOT::DELASSOS BOOT::|Size| BOOT::|$form|
         BOOT::|$insideCategoryIfTrue| BOOT::SUCHTHAT BOOT::|One|
         BOOT::ACTION BOOT::MDEFTRACE BOOT::|$BooleanOpt|
         BOOT::|$xyStack| BOOT::ASSOCLEFT BOOT::|sayALGEBRA|
         BOOT::|Coord| BOOT::IDENTIFIER-TOKEN BOOT::ADVANCE-CHAR
         BOOT::|$InitialDomainsInScope| BOOT::|$StringCategory|
         BOOT::S- BOOT::NEWLINE BOOT::|$optimizableDomainNames|
         BOOT::IN BOOT::COLLECTV BOOT::|$Lisp|
         BOOT::|$lisplibOperationAlist| BOOT::|$reportExitModeStack|
         BOOT::|$updateCatTableIfTrue| BOOT::NREVERSE0 BOOT::%M
         BOOT::|sayFORTRAN| BOOT::NEWLINECHR BOOT::|$EmptyMode|
         BOOT::|$Zero| BOOT::CARCDREXPAND BOOT::|IS_#GENVAR|
         BOOT::LISTOFATOMS BOOT::|$algebraOutputStream|
         BOOT::|$highlightAllowed| BOOT::|NonNegativeInteger|
         BOOT::/EMBED-1
         BOOT::|$constructorsNotInDatabase| BOOT::|$ConstructorNames|
         BOOT::|$Integer| BOOT::|$systemModemapsInCore| BOOT::KADDR
         BOOT::STAR BOOT::|$reportCompilation|
         BOOT::|$traceNoisely| BOOT::SPADDIFFERENCE BOOT::%B
         BOOT::COMMENT-CHARACTER BOOT::|$PrettyPrint| BOOT::SPADLET
         BOOT::|$ModemapFrame| BOOT::|$QuickLet| BOOT::SPADDO
         BOOT::PREDECESSOR BOOT::*EOF* BOOT::POP-STACK-1 BOOT::BANG
         BOOT::|$ConstructorCache| BOOT::|$printConStats|
         BOOT::|$RationalNumberOpt| BOOT::RESET
         BOOT::NLIST BOOT::NSTRCONC BOOT::TAIL BOOT::GETRULEFUNLISTS
         BOOT::|$IntegerOpt| BOOT::$NEWLINSTACK BOOT::|$QuietIfNil|
         BOOT::$SPAD_ERRORS BOOT::|$useDCQnotLET| BOOT::|$xCount|
         BOOT::$BOOT BOOT::POINT BOOT::OPTIONAL BOOT::PARSE-IDENTIFIER
         BOOT::BSTRING-TOKEN BOOT::LASTELEM BOOT::STREAM-EOF
         BOOT::|sayBrightly| BOOT::|$formulaOutputStream|
         BOOT::|BigFloat| BOOT::SLAM BOOT::$DISPLAY
         BOOT::|$NonMentionableDomainNames| BOOT::$OLDLINE BOOT::$TYPE
         BOOT::STATUS BOOT::KEYFN BOOT::|$NonNegativeIntegerOpt|
         BOOT::|$userConstructors| BOOT::BOOT-NEQUAL BOOT::RPLAC
         BOOT::GETTAIL BOOT::|QuotientField| BOOT::CURRENT-TOKEN
         BOOT::|$suffix| BOOT::|$VariableCount| BOOT::COMPARE
         AXIOM-LISP:SEQUENCE BOOT::|$Exit| BOOT::BOOT-EQUAL BOOT::LT
         VMLISP::OBEY BOOT::TYPE-CONTENTS-OF-FILE BOOT::|UnSizedBox| BOOT::|Integer| BOOT::|Nud|
         BOOT::IOCLEAR BOOT::|$BigFloatOpt| BOOT::|$EmptyEnvironment|
         BOOT::|$forceDatabaseUpdate| BOOT::$LINESTACK BOOT::ULCASEFG
         BOOT::|$Boolean| BOOT::|$clamList| BOOT::COLLECT
         BOOT::IOSTREAMS-SET BOOT::MUST BOOT::|$FloatOpt|
         BOOT::|$NonNegativeInteger|
         BOOT::FLAG BOOT::TL BOOT::BLANKS BOOT::|$report3|
         BOOT::|$reportFlag| BOOT::|$xeditIsConsole| BOOT::PAIR
         BOOT::|$evalDomain| BOOT::|$traceletFunctions| BOOT::|$Void|
         BOOT::GT BOOT::MATCH-ADVANCE-STRING
         BOOT::|$scanModeFlag| BOOT::SUBLISNQ BOOT::LASSQ BOOT::NOTE
         BOOT::ILAM BOOT::CURRENT-SYMBOL
         BOOT::|$SetFunctions| BOOT::|$sourceFileTypes| BOOT::|String|
         BOOT::NUMBER-TOKEN BOOT::$LINENUMBER BOOT::$NUM_OF_META_ERRORS
         BOOT::|$Polvar| BOOT::|$domainsWithUnderDomains|
         BOOT::SPADCALL BOOT::DELASC BOOT::FAIL BOOT::$COMPILE
         BOOT::|$lastUntraced| BOOT::|$lisplibKind|
         BOOT::|$tracedModemap| BOOT::|$inputPromptType| BOOT::LASSOC
         AXIOM-LISP:NUMBER BOOT::|$prefix| BOOT::|$TranslateOnly| BOOT::SAY
         BOOT::|$CategoryFrame| BOOT::|$croakIfTrue| BOOT::|$exitMode|
         BOOT::|$lisplibDependentCategories| BOOT::|$NoValue|
         BOOT::MOAN BOOT::POP-STACK-2 BOOT::BAC
         BOOT::|$InitialModemapFrame| BOOT::$MAXLINENUMBER
         BOOT::$ESCAPESTRING BOOT::|$bootStrapMode|
         BOOT::|$compileMapFlag| BOOT::|$currentFunction|
         BOOT::|$DomainNames| BOOT::|$PolyMode| BOOT::|$tripleCache|
         BOOT::SUCHTHATCLAUSE BOOT::WHILE BOOT::S+ BOOT::|Expression|
         BOOT::PARSE-NUMBER BOOT::|$Index| BOOT::$NBOOT
         BOOT::|$PrintCompilerMessagesIfTrue| BOOT::$PROMPT
         BOOT::MAKE-PARSE-FUNCTION BOOT::/METAOPTION BOOT::|$topOp|
         BOOT::|$xyInitial| BOOT::MKPF BOOT::STRM
         BOOT::MATCH-NEXT-TOKEN BOOT::|pathname| BOOT::|$cacheAlist|
         BOOT::$FUNCTION BOOT::|$reportSpadTrace|
         BOOT::|$tempCategoryTable| BOOT::|$underDomainAlist|
         BOOT::|$whereList| BOOT::|append| BOOT::|function|
         BOOT::CURINPUTLINE BOOT::|sayFORMULA|
         BOOT::/GENVARLST BOOT::|$Category| BOOT::|$SpecialDomainNames|
         VMLISP::|union| BOOT::ASSOCRIGHT BOOT::CURSTRMLINE
         BOOT::REDUCTION BOOT::|$lisplibDomainDependents|
         BOOT::|OptionList| BOOT::|$postStack| BOOT::|$traceDomains|
         BOOT::BRIGHTPRINT BOOT::|$instantRecord|
         BOOT::|$NETail| BOOT::UNTIL BOOT::GET-TOKEN
         BOOT::|$Expression| BOOT::$LASTPREFIX BOOT::|$mathTraceList|
         BOOT::|$PrintOnly| BOOT::ELEMN BOOT::NILADIC
         BOOT::PARSE-BSTRING BOOT::/DEPTH BOOT::|$spadLibFT|
         BOOT::|$xyMax| BOOT::|$IOindex| BOOT::SPADCONST
         BOOT::|sayBrightlyI| BOOT::|SquareMatrix|
         BOOT::LASTTAIL
         BOOT::|UnboundBox| BOOT::NEXT-TOKEN
         BOOT::|$OutsideStringIfTrue| BOOT::|$String| BOOT::TRIMLZ
         BOOT::KADR BOOT::STRMBLANKLINE BOOT::STRMSKIPTOBLANK
         BOOT::IOSTAT BOOT::|$insideCoerceInteractiveHardIfTrue|
         BOOT::|$lisplibSignatureAlist| BOOT::REMFLAG BOOT::SPADREDUCE
         BOOT::QLASSQ BOOT::NEXTSTRMLINE BOOT::|FontTable| BOOT::|Led|
         BOOT::UNGET-TOKENS BOOT::|$operationNameList|
         BOOT::|$tokenCommands| BOOT::IS_GENVAR BOOT::INIT-RULES
         BOOT::|PrintItem| BOOT::$LISPLIB BOOT::|$optionAlist|
         BOOT::|$previousTime| BOOT::|$StreamIndex|
         BOOT::|$systemLisplibsWithModemapsInCore|
         BOOT::|$tracedSpadModemap| BOOT::ISTEP BOOT::|$warningStack|
         BOOT::|and| BOOT::OUT-STREAM BOOT::TOKEN
         BOOT::|$ConstructorDependencyAlist|
         BOOT::|$lisplibVariableAlist| BOOT::INTERNL BOOT::IEQUAL
         BOOT::|$algebraList| BOOT::|$brightenCommentsIfTrue|
         BOOT::|$failure| BOOT::|$Mode| BOOT::|$opFilter|
         BOOT::|$TraceFlag| BOOT::|Float| BOOT::POP-STACK-3
         BOOT::|$EmptyString| BOOT::$TOP_STACK BOOT::|$mpolyTTrules|
         BOOT::|$mpolyTMrules| BOOT::|$InteractiveFrame|
         BOOT::|$InteractiveModemapFrame| BOOT::|$letAssoc|
         BOOT::|$lisp2lispRenameAssoc| BOOT::|$RationalNumber|
         BOOT::|$ThrowAwayMode| BOOT::*PROMPT* BOOT::NUMOFARGS
         BOOT::|$semanticErrorStack| BOOT::|$spadSystemDisks|
         BOOT::$TOP_LEVEL BOOT::BUMPCOMPERRORCOUNT
         BOOT::|delete| BOOT::STREQ BOOT::STRING-TOKEN BOOT::XNAME
         BOOT::|$ExpressionOpt| BOOT::|$systemCreation| BOOT::$GENNO
         BOOT::CROAK BOOT::PARSE-STRING BOOT::|$genFVar|
         BOOT::|$lisplibModemap| BOOT::|$NoValueMode| BOOT::|$PrintBox|
         BOOT::ADVANCE-TOKEN BOOT::|$NegativeIntegerOpt|
         BOOT::|$polyDefaultAssoc| BOOT::|$PrimitiveDomainNames|
         AXIOM-LISP:STEP BOOT::|rassoc| BOOT::|$Res|
         BOOT::MATCH-CURRENT-TOKEN BOOT::/GENSYMLIST BOOT::|$false|
         BOOT::|$ignoreCommentsIfTrue| BOOT::|$ModeVariableList|
         BOOT::|$useBFasDefault| BOOT::|$CommonDomains|
         BOOT::|$printLoadMsgs| BOOT::|dataCoerce| BOOT::|$inLispVM|
         BOOT::|$streamCount|
         BOOT::|$Symbol| BOOT::|$updateIfTrue| BOOT::REMDUP
         BOOT::ADDASSOC BOOT::|PrintList|
         BOOT::SPECIAL-CHAR BOOT::XCAPE BOOT::|$EmptyVector|
         BOOT::REPEAT BOOT::|$NegativeInteger|
         BOOT::LENGTHENVEC BOOT::CURMAXINDEX BOOT::|$hasCategoryTable|
         BOOT::|$leftPren| BOOT::|$lisplibForm| BOOT::|$OneCoef|
         BOOT::|$reportCoerce| VMLISP::OPTIONLIST BOOT::META
         BOOT::|$insideCapsuleFunctionIfTrue|
         BOOT::|$insideConstructIfTrue| BOOT::$BOLDSTRING
         BOOT::|breaklet| BOOT::|$insideCompTypeOf|
         BOOT::|$rightPren|
         BOOT::|$systemLastChanged| BOOT::|$xyCurrent| BOOT::|Zero|
         BOOT::YIELD BOOT::|Polynomial| BOOT::|$Domain| BOOT::STRINGPAD
         BOOT::TRUNCLIST BOOT::|SmallInteger| BOOT::|$libFile|
         BOOT::|$mathTrace| BOOT::|$PolyDomains| BOOT::|or|
         BOOT::|$DomainVariableList| BOOT::|$insideFunctorIfTrue|
         BOOT::|$One| VMLISP::EXIT BOOT::CURRENT-CHAR BOOT::NBLNK
         BOOT::$DALYMODE))

;;; Definitions for package VMLISP of type EXPORT
(in-package "VMLISP")
(import '(
          BOOT:|directoryp| BOOT:|makedir|))

(export
    '(VMLISP::SINTP VMLISP::$FCOPY 
         VMLISP::PUT
         VMLISP::QVELT-1 VMLISP::QSETVELT-1 vmlisp::throw-protect
         VMLISP::|directoryp| VMLISP::|makedir| VMLISP::EQCAR
         VMLISP::DEFIOSTREAM VMLISP::RDEFIOSTREAM VMLISP::MLAMBDA
         VMLISP::QSLESSP VMLISP::QSDIFFERENCE VMLISP::QSQUOTIENT
         VMLISP::CREATE-SBC VMLISP::LASTPAIR
         VMLISP::EQSUBSTLIST VMLISP::QCAAAR VMLISP::$TOTAL-ELAPSED-TIME
         VMLISP::QUOTIENT VMLISP::SORTGREATERP
         VMLISP::QSETREFV VMLISP::QSTRINGLENGTH VMLISP::EVALFUN
         VMLISP::QCDAR VMLISP::TEMPUS-FUGIT VMLISP::QSPLUS VMLISP::QSABSVAL
         VMLISP::QSZEROP VMLISP::QSMIN VMLISP::QSLEFTSHIFT
         VMLISP::SETDIFFERENCE VMLISP::RPLQ VMLISP::CATCHALL
         VMLISP::RECOMPILE-DIRECTORY VMLISP::MDEF VMLISP::LINTP
         VMLISP::NILFN VMLISP::TAB VMLISP::QCDDR VMLISP::IOSTATE
         VMLISP::SFP VMLISP::NE VMLISP::STRGREATERP
         VMLISP::USE-VMLISP-SYNTAX VMLISP::RCLASS VMLISP::RSETCLASS
         VMLISP::SEQ VMLISP::FIXP VMLISP::MAKE-CVEC
         VMLISP::|F,PRINT-ONE| VMLISP::HASHUEQUAL VMLISP::$OUTFILEP
         VMLISP::TIMES VMLISP::DIFFERENCE VMLISP::MSUBST VMLISP::DIVIDE
         VMLISP::|remove| VMLISP::GETL VMLISP::QCADAR VMLISP::QCAAAAR
         VMLISP::RECLAIM VMLISP::ORADDTEMPDEFS VMLISP::NAMEDERRSET
         VMLISP::TRIMSTRING VMLISP::CURRINDEX VMLISP::EVALANDFILEACTQ
         VMLISP::LISPLIB VMLISP::FLUID VMLISP::MDEFX VMLISP::COMP370
         VMLISP::NEQ VMLISP::GETREFV VMLISP::|log| VMLISP::QVSIZE
         VMLISP::MBPIP VMLISP::RPLNODE VMLISP::QSORT
         VMLISP::PLACEP VMLISP::RREAD VMLISP::BINTP VMLISP::QSODDP
         VMLISP::O VMLISP::RVECP VMLISP::CHAR2NUM VMLISP::POPP
         VMLISP::QCDAADR VMLISP::HKEYS VMLISP::HASHCVEC VMLISP::HASHID
         VMLISP::REMOVEQ VMLISP::LISTOFFUNCTIONS
         VMLISP::QCADAAR VMLISP::ABSVAL VMLISP::VMPRINT
         VMLISP::MAKE-APPENDSTREAM
         VMLISP::MAKE-INSTREAM VMLISP::HASHTABLEP VMLISP::UPCASE
         VMLISP::LOADCOND VMLISP::STRPOSL VMLISP::STATEP VMLISP::QCDADR
         VMLISP::HREMPROP VMLISP::LAM VMLISP::FBPIP VMLISP::NCONC2
         VMLISP::GETFULLSTR VMLISP::I VMLISP::HREM
         VMLISP::*LISP-BIN-FILETYPE* VMLISP::INT2RNUM VMLISP::EBCDIC
         VMLISP::$INFILEP VMLISP::BFP VMLISP::NUMP VMLISP::UNEMBED
         VMLISP::PAIRP VMLISP::BOOLEANP VMLISP::FIX VMLISP::REMAINDER
         VMLISP::RE-ENABLE-INT VMLISP::QCAADDR VMLISP::QCDDADR
         VMLISP::$LISTFILE VMLISP::IVECP VMLISP::LIST2VEC
         VMLISP::|LAM,FILEACTQ| VMLISP::LISTOFQUOTES
         VMLISP::$ERASE VMLISP::QSDEC1
         VMLISP::QSSUB1 VMLISP::QCAR VMLISP::EVA1FUN VMLISP::IS-CONSOLE
         VMLISP::MAKESTRING VMLISP::CUROUTSTREAM VMLISP::QCDDDR
         VMLISP::QCDADAR VMLISP::MAKE-ABSOLUTE-FILENAME VMLISP::SUFFIX
         VMLISP::FUNARGP VMLISP::VM/ VMLISP::QRPLACA VMLISP::GGREATERP
         VMLISP::CGREATERP VMLISP::RNUMP VMLISP::RESETQ VMLISP::QRPLACD
         VMLISP::SORTBY VMLISP::CVECP VMLISP::SETELT VMLISP::HGET
         VMLISP::$DIRECTORY-LIST VMLISP::LN
         VMLISP::|member| VMLISP::AXIOM-MEMBER
         VMLISP::$LIBRARY-DIRECTORY-LIST
         VMLISP::QCSIZE VMLISP::QCADDDR VMLISP::RWRITE VMLISP::SUBLOAD
         VMLISP::STRINGIMAGE VMLISP::$CLEAR VMLISP::|read-line|
         VMLISP::PROPLIST VMLISP::INTP VMLISP::OUTPUT VMLISP::CONSOLE
         VMLISP::QCDDDAR VMLISP::ADDOPTIONS VMLISP::$FILETYPE-TABLE
         VMLISP::QSMINUSP VMLISP::|assoc| VMLISP::SETSIZE VMLISP::QCDR
         VMLISP::EFFACE VMLISP::COPY VMLISP::DOWNCASE VMLISP::LC2UC
         VMLISP::EMBED VMLISP::SETANDFILEQ VMLISP::QSMAX
         VMLISP::LIST2REFVEC VMLISP::MACRO-INVALIDARGS VMLISP::EMBEDDED
         VMLISP::REFVECP VMLISP::CLOSEDFN VMLISP::MAKE-HASHTABLE
         VMLISP::MAKE-FILENAME VMLISP::|$defaultMsgDatabaseName|
         VMLISP::LEXGREATERP
         VMLISP::IDENTP VMLISP::QSINC1 VMLISP::QESET VMLISP::MRP
         VMLISP::LESSP VMLISP::RPLPAIR VMLISP::QVELT VMLISP::QRPLQ
         VMLISP::MACERR VMLISP::*FILEACTQ-APPLY* VMLISP::HPUT*
         VMLISP::$FILEP VMLISP::MAKE-FULL-CVEC VMLISP::HCLEAR
         VMLISP::HPUTPROP 
         VMLISP::STRING2ID-N VMLISP::CALLBELOW VMLISP::BPINAME
         VMLISP::CHANGELENGTH VMLISP::ECQ VMLISP::OBEY VMLISP::QASSQ
         VMLISP::DCQ VMLISP::SHUT VMLISP::FILE VMLISP::HPUT
         VMLISP::MAKEPROP VMLISP::GREATERP
         VMLISP::REROOT VMLISP::DIG2FIX VMLISP::L-CASE
         VMLISP::TEREAD VMLISP::QSREMAINDER VMLISP::$FINDFILE
         VMLISP::EQQ VMLISP::PRETTYPRINT VMLISP::HASHEQ VMLISP::LOG2
         VMLISP::U-CASE VMLISP::NREMOVE VMLISP::QREFELT VMLISP::SIZE
         VMLISP::EOFP VMLISP::QCDAAR VMLISP::RSHUT VMLISP::ADD1
         VMLISP::QMEMQ VMLISP::SUBSTRING VMLISP::LOADVOL
         VMLISP::QSTIMES VMLISP::STRINGLENGTH VMLISP::NEXT
         VMLISP::DEVICE VMLISP::MAPELT VMLISP::LENGTHOFBPI
         VMLISP::DIGITP VMLISP::QLENGTH VMLISP::QCAAADR VMLISP::CVEC
         VMLISP::VEC2LIST VMLISP::MODE VMLISP::MAKE-VEC VMLISP::GCMSG
         VMLISP::CONCAT VMLISP::$SHOWLINE VMLISP::QCAADR VMLISP::QCDDAR
         VMLISP::QCDAAAR VMLISP::RDROPITEMS VMLISP::VECP
         VMLISP::|union| VMLISP::ONE-OF VMLISP::NULLOUTSTREAM
         VMLISP::QSGREATERP VMLISP::MINUS VMLISP::MAXINDEX
         VMLISP::GETSTR VMLISP::QCADADR VMLISP::PRIN2CVEC
         VMLISP::CURRENTTIME VMLISP::$REPLACE VMLISP::UNIONQ
         VMLISP::NREMOVEQ VMLISP::CURINSTREAM VMLISP::MAKE-OUTSTREAM
         VMLISP::APPLX VMLISP::LASTNODE VMLISP::SUBSTQ VMLISP::TRUEFN
         VMLISP::|last| VMLISP::RPLACSTR VMLISP::SETQP VMLISP::QCADDR
         VMLISP::QCAADAR VMLISP::QCDDAAR VMLISP::|intersection|
         VMLISP::HASHTABLE-CLASS
         VMLISP::*COMP370-APPLY* VMLISP::QSETVELT VMLISP::MOVEVEC
         VMLISP::ID VMLISP::DEFINE-FUNCTION VMLISP::MSUBSTQ VMLISP::|nsubst|
         VMLISP::LISTOFFLUIDS VMLISP::SUB1 VMLISP::NUMBEROFARGS
         VMLISP::VMREAD VMLISP::SMINTP VMLISP::$SCREENSIZE
         VMLISP::LISTOFFREES VMLISP::QCDADDR VMLISP::COMPRREAD
         VMLISP::GENSYMP VMLISP::IFCAR VMLISP::QSETQ
         VMLISP::QCADDAR VMLISP::*LISP-SOURCE-FILETYPE* VMLISP::KOMPILE
         VMLISP::INPUT VMLISP::PAPPP VMLISP::UEQUAL VMLISP::COMPRWRITE
         VMLISP::SUBRP VMLISP::ASSEMBLE VMLISP::|LAM,EVALANDFILEACTQ|
         VMLISP::|$msgDatabaseName| VMLISP::IFCDR VMLISP::QVMAXINDEX
         VMLISP::$SPADROOT VMLISP::PRIN0 VMLISP::PRETTYPRIN0
         VMLISP::STACKLIFO VMLISP::ASSQ VMLISP::PRINTEXP
         VMLISP::QCDDDDR VMLISP::QSADD1
         VMLISP::SETDIFFERENCEQ VMLISP::STRPOS VMLISP::CONSTANT
         VMLISP::QCAAR VMLISP::HCOUNT VMLISP::RCOPYITEMS
         VMLISP::QSMINUS VMLISP::EVA1 VMLISP::OPTIONLIST
         VMLISP::NUM2CHAR VMLISP::QENUM VMLISP::QEQQ
         VMLISP::$TOTAL-GC-TIME VMLISP::CHARP VMLISP::QCADR
         VMLISP::INTERSECTIONQ VMLISP::DSETQ VMLISP::FETCHCHAR
         VMLISP::STRCONC VMLISP::MACRO-MISSINGARGS VMLISP::RPACKFILE
         VMLISP::EXIT VMLISP::PLUS VMLISP::RKEYIDS
         VMLISP::COMPILE-LIB-FILE VMLISP::RECOMPILE-LIB-FILE-IF-NECESSARY
         VMLISP::GET-CURRENT-DIRECTORY VMLISP::TRIM-DIRECTORY-NAME))

;;; Definitions for package BOOT of type SHADOW
(in-package "BOOT")
(shadow '(BOOT::MAP))
(import
    '(VMLISP::NE VMLISP::FLUID
         VMLISP::OBEY BOOT::TYPE-CONTENTS-OF-FILE VMLISP::|union|
         VMLISP::OPTIONLIST VMLISP::EXIT VMLISP::LEXGREATERP))
(import '(vmlisp::make-input-filename))
(import '(vmlisp::libstream-dirname))
(import '(vmlisp::eqcar))
(export '(boot::eqcar))

;;; Definitions for package VMLISP of type SHADOW

(in-package "BOOT") ;; Used to be "UNCOMMON"

(export '(
        ;; !! ;;; Passed on from the Lisp package
        ;; !! + * -

        ;;;; Operating system interface
        |OsRunProgram| |OsRunProgramToStream| |OsProcessNumber|
        |OsEnvGet|     |OsEnvVarCharacter|    |OsExpandString|

        ;;;; Time
        |TimeStampString|

        ;;;; Lisp Interface
        |LispKeyword|
        |LispReadFromString| |LispEval|
        |LispCompile| |LispCompileFile| |LispCompileFileQuietlyToObject|
        |LispLoadFile| |LispLoadFileQuietly|

        ;;; Control
        |funcall| |Catch| |Throw| |UnwindProtect| |CatchAsCan|

        ;;; General
        |Eq| |Nil| |DeepCopy| |Sort| |SortInPlace|

        |genRemoveDuplicates| |genMember|
        |gobSharedExcluding| |gobSharedParts| |gobAlwaysShared?|
        |gobPretty| |gobSexpr|

        ;;; Streams
        |Prompt| |PlainError| |PrettyPrint| |PlainPrint| |PlainPrintOn|
        |WithOpenStream|
        |WriteLispExpr| |WriteByte| |WriteChar| |WriteLine| |WriteString|
        |ReadLispExpr| |ReadByte| |ReadChar| |ReadLine|
        |ByteFileWriteLine| |ByteFileReadLine|
        |ReadLineIntoString| |ByteFileReadLineIntoString| |ReadBytesIntoVector|
        |StreamCopyChars| |StreamCopyBytes|
        |InputStream?| |OutputStream?|
        |StreamSize| |StreamGetPosition| |StreamSetPosition|
        |StreamEnd?| |StreamFlush| |StreamClose|

        |FileLine| |StreamLine|

        ;;; Pathnames
        |TempFileDirectory| |LispFileType| |FaslFileType|
        |ToPathname| |Pathname| |NewPathname| |SessionPathname|
        |PathnameDirectory| |PathnameName| |PathnameType|
        |PathnameString| |PathnameAbsolute?|
        |PathnameWithType| |PathnameWithDirectory|
        |PathnameWithoutType| |PathnameWithoutDirectory|

        |PathnameToUsualCase| |PathnameWithinDirectory|
        |PathnameDirectoryOfDirectoryPathname| |PathnameWithinOsEnvVar|

        ;;; Symbols
        |MakeSymbol| |Symbol?| |SymbolString|

        ;;; Bits
        |Bit| |Bit?| |TrueBit| |FalseBit| |BitOn?| |BitOr|

        ;;; General Sequences
        ;; !! ;;; Passed on from the Lisp package
        ;; !! ELT SETELT
        ;; SIZE

        ;;; Vectors
        |FullVector| |Vector?|

        ;;; Bit Vectors
        |FullBvec|

        ;;; Characters
        |char| |Char| |Char?|
        |CharCode| |CharGreater?| |CharDigit?|
        |SpaceChar| |NewlineChar|

        ;;; Character Sets
        |Cset| |CsetMember?|
        |CsetUnion| |CsetComplement| |CsetString|
        |NumericCset| |LowerCaseCset| |UpperCaseCset| |WhiteSpaceCset|
        |AlphaCset| |AlphaNumericCset|

        ;;; Character Strings
        |FullString| |ToString| |StringImage| |String?|
        |StringGetCode| |StringConcat|
        |StringLength| |StringFromTo| |StringFromToEnd| |StringFromLong|
        |StringGreater?| |StringPrefix?| |StringUpperCase| |StringLowerCase|
        |StringToInteger|  |StringToFloat|
        |StringWords|      |StringTrim|
        |StringPositionOf| |StringPositionOfNot|
        |UnescapeString|   |ExpandVariablesInString|

        ;;; Numbers
        |Number?| |Integer?| |SmallInteger?| |Float?| |DoublePrecision|
        |Odd?| |Remainder|
        |Abs| |Min| |Max|
        |Exp| |Ln| |Log10|
        |Sin| |Cos| |Tan| |Cotan| |Arctan|

        ;;; Pairs
        |Pair?|

        |car|       |cdr|
        |caar|      |cadr|      |cdar|      |cddr|
        |caaar|     |caadr|     |cadar|     |caddr|
        |cdaar|     |cdadr|     |cddar|     |cdddr|
        |FastCar|   |FastCdr|
        |FastCaar|  |FastCadr|  |FastCdar|  |FastCddr|
        |FastCaaar| |FastCaadr| |FastCadar| |FastCaddr|
        |FastCdaar| |FastCdadr| |FastCddar| |FastCdddr|
        |IfCar|     |IfCdr|
        |EqCar|     |EqCdr|

        ;;; Lists
        |length1?| |second|

        |ListIsLength?| |ListMemberQ?| |ListMember?|
        |ListRemoveQ| |ListNRemoveQ| |ListRemoveDuplicatesQ| |ListNReverse|
        |ListUnion| |ListUnionQ| |ListIntersection| |ListIntersectionQ|
        |ListAdjoin| |ListAdjoinQ|

        ;;; Association lists
        |AlistAssoc| |AlistRemove|
        |AlistAssocQ| |AlistRemoveQ| |AlistAdjoinQ| |AlistUnionQ|

        ;;; Tables
        |Table?|
        |TableCount| |TableGet| |TableSet| |TableUnset| |TableKeys|
))

(in-package "BOOT")
(export '(boot::ncloop boot::ncrecover))
(import '(
   vmlisp::make-input-filename
   vmlisp::is-console
   ;; boot::|openServer|
   ;; boot::|sockGetInt|
   ;; boot::|sockSendInt|
   ;; boot::|sockGetInts|
   ;; boot::|sockSendInts|
   ;; boot::|sockGetString|
   ;; boot::|sockSendString|
   ;; boot::|sockGetFloat|
   ;; boot::|sockSendFloat|
   ;; boot::|sockGetFloats|
   ;; boot::|sockSendFloats|
   ;; boot::|sockSendWakeup|
   ;; boot::|sockSendSignal|
   vmlisp::qsdifference
   vmlisp::qsminusp
   vmlisp::qsplus
   vmlisp::absval
   vmlisp::cgreaterp
   vmlisp::char2num
   vmlisp::charp
   vmlisp::concat
   vmlisp::copy
   vmlisp::difference
   vmlisp::digitp
   vmlisp::divide
   vmlisp::eqcar
   vmlisp::fixp
   vmlisp::greaterp
   vmlisp::hasheq
   vmlisp::hput
   vmlisp::hrem
   vmlisp::identp
   vmlisp::lessp
   vmlisp::ln
   vmlisp::make-cvec
   vmlisp::make-full-cvec
   vmlisp::make-vec
   vmlisp::memq
   vmlisp::movevec
   vmlisp::pname
   vmlisp::prettyprin0
   vmlisp::prettyprint
   vmlisp::printexp
   vmlisp::qassq
   vmlisp::qcar
   vmlisp::qcdr
   vmlisp::qcaar
   vmlisp::qcadr
   vmlisp::qcdar
   vmlisp::qcddr
   vmlisp::qcaaar
   vmlisp::qcaadr
   vmlisp::qcadar
   vmlisp::qcaddr
   vmlisp::qcdaar
   vmlisp::qcdadr
   vmlisp::qcddar
   vmlisp::qcdddr
   vmlisp::qcaaaar
   vmlisp::qcaaadr
   vmlisp::qcaadar
   vmlisp::qcaaddr
   vmlisp::qcadaar
   vmlisp::qcadadr
   vmlisp::qcaddar
   vmlisp::qcadddr
   vmlisp::qcdaaar
   vmlisp::qcdaadr
   vmlisp::qcdadar
   vmlisp::qcdaddr
   vmlisp::qcddaar
   vmlisp::qcddadr
   vmlisp::qcdddar
   vmlisp::qcddddr
   vmlisp::qcsize
   vmlisp::qenum
   vmlisp::qeset
   vmlisp::qlength
   vmlisp::qmemq
   vmlisp::qsadd1
   vmlisp::qslessp
   vmlisp::qsdec1
   vmlisp::qsetvelt
   vmlisp::qsgreaterp
   vmlisp::qsinc1
   vmlisp::qsmax
   vmlisp::qsmin
   vmlisp::qsoddp
   vmlisp::qsquotient
   vmlisp::qsremainder
   vmlisp::qssub1
   vmlisp::qstimes
   vmlisp::qszerop
   vmlisp::qszerop
   vmlisp::qvelt
   vmlisp::qvsize
   vmlisp::setandfileq
   vmlisp::sintp
   vmlisp::size
   vmlisp::stringimage
   vmlisp::strpos
   vmlisp::strposl
   vmlisp::substring
   ;; boot::|error|
   vmlisp::ivecp
   vmlisp::rvecp
   vmlisp::dig2fix
   vmlisp::rnump
   vmlisp::fix
   vmlisp::sortgreaterp
   vmlisp::qsort
   vmlisp::sortby
   vmlisp::make-instream
   vmlisp::list2vec
   vmlisp::vec2list
   vmlisp::sub1
   vmlisp::add1
   vmlisp::neq
   vmlisp::hashtable-class
   vmlisp::maxindex
   ;; boot::remdup
   vmlisp::upcase
   vmlisp::downcase
   vmlisp::vecp
   vmlisp::strconc
   vmlisp::defiostream
   vmlisp::shut
   vmlisp::prin2cvec
   ;; boot::lasttail
   ;; boot::lastpair
   ;; boot::lastatom
   ;; boot::|last|
   vmlisp::ncons
   vmlisp::rplpair
   vmlisp::nump
   vmlisp::intp
   vmlisp::makeprop
   vmlisp::ifcar
   vmlisp::ifcdr
   vmlisp::quotient
   vmlisp::remainder
   vmlisp::make-hashtable
   vmlisp::hget
   vmlisp::hkeys
   vmlisp::$infilep
   vmlisp::$findfile
   vmlisp::pairp
   vmlisp::cvec
   vmlisp::uequal
   vmlisp::id
   vmlisp::vec-setelt
   vmlisp::make-bvec
   ;; boot::bvec-make-full
   ;; boot::bvec-setelt
   vmlisp::|shoeread-line|
   vmlisp::|shoeInputFile|
   vmlisp::|shoeConsole|
   vmlisp::|startsId?|
   vmlisp::|idChar?|
   vmlisp::|npPC|
   vmlisp::|npPP|
   ;; boot::mkprompt
   ;; boot::|fillerSpaces|
   ;; boot::|sayString|
   ;; boot::help
   ;; boot::|version|
   ;; boot::|pp|
   ;; boot::$dalymode
   ;; boot::$IEEE
))

(in-package "FOAM")

(export '(
FOAM::|printDFloat|
FOAM::|printSFloat|
FOAM::|printBInt|
FOAM::|printSInt|
FOAM::|printString|
FOAM::|printChar|
FOAM::|printNewLine|
FOAM::|MakeLit|
FOAM::|EnvNext|
FOAM::|EnvLevel|
FOAM::|MakeEnv|
FOAM::|RElt|
FOAM::|RNew|
FOAM::|DDecl|
FOAM::|ClosFun|
FOAM::|ClosEnv|
FOAM::|CCall|
FOAM::|ArrToBInt|
FOAM::|ArrToSInt|
FOAM::|ArrToDFlo|
FOAM::|ArrToSFlo|
FOAM::|BIntToDFlo|
FOAM::|BIntToSFlo|
FOAM::|SIntToDFlo|
FOAM::|SIntToSFlo|
FOAM::|BIntToSInt|
FOAM::|SIntToBInt|
FOAM::|BitToSInt|
FOAM::|ScanBInt|
FOAM::|ScanSInt|
FOAM::|ScanDFlo|
FOAM::|ScanSFlo|
FOAM::|FormatBInt|
FOAM::|FormatSInt|
FOAM::|FormatDFlo|
FOAM::|FormatSFlo|
FOAM::|PtrEQ|
FOAM::|PtrIsNil|
FOAM::|PtrNil|
FOAM::|BIntBit|
FOAM::|BIntShift|
FOAM::|BIntLength|
FOAM::|BIntPower|
FOAM::|BIntGcd|
FOAM::|BIntDivide|
FOAM::|BIntRem|
FOAM::|BIntQuo|
FOAM::|BIntMod|
FOAM::|BIntTimes|
FOAM::|BIntMinus|
FOAM::|BIntPlus|
FOAM::|BIntInc|
FOAM::|BIntDec|
FOAM::|BIntAbs|
FOAM::|BIntNegate|
FOAM::|BIntNE|
FOAM::|BIntGT|
FOAM::|BIntEQ|
FOAM::|BIntLE|
FOAM::|BIntIsSmall|
FOAM::|BIntIsOdd|
FOAM::|BIntIsEven|
FOAM::|BIntIsPos|
FOAM::|BIntIsNeg|
FOAM::|BIntIsZero|
FOAM::|BInt1|
FOAM::|BInt0|
FOAM::|SIntOr|
FOAM::|SIntAnd|
FOAM::|SIntNot|
FOAM::|SIntBit|
FOAM::|SIntShift|
FOAM::|SIntLength|
FOAM::|SIntTimesMod|
FOAM::|SIntMinusMod|
FOAM::|SIntPlusMod|
FOAM::|SIntPower|
FOAM::|SIntGcd|
FOAM::|SIntDivide|
FOAM::|SIntRem|
FOAM::|SIntQuo|
FOAM::|SIntMod|
FOAM::|SIntTimes|
FOAM::|SIntMinus|
FOAM::|SIntPlus|
FOAM::|SIntInc|
FOAM::|SIntDec|
FOAM::|SIntNegate|
FOAM::|SIntNE|
FOAM::|SIntGT|
FOAM::|SIntEQ|
FOAM::|SIntLE|
FOAM::|SIntIsOdd|
FOAM::|SIntIsEven|
FOAM::|SIntIsPos|
FOAM::|SIntIsNeg|
FOAM::|SIntIsZero|
FOAM::|SIntMax|
FOAM::|SIntMin|
FOAM::|SInt1|
FOAM::|SInt0|
FOAM::|HIntMax|
FOAM::|HIntMin|
FOAM::|HInt1|
FOAM::|HInt0|
FOAM::|ByteMax|
FOAM::|ByteMin|
FOAM::|Byte1|
FOAM::|Byte0|
FOAM::|DFloCeiling|
FOAM::|DFloFloor|
FOAM::|DFloTruncate|
FOAM::|DFloRound|
FOAM::|DFloIPower|
FOAM::|DFloPower|
FOAM::|DFloDivide|
FOAM::|DFloTimes|
FOAM::|DFloMinus|
FOAM::|DFloPlus|
FOAM::|DFloNegate|
FOAM::OTHER-FORM
FOAM::|DFloNE|
FOAM::|DFloGT|
FOAM::|DFloEQ|
FOAM::|DFloLE|
FOAM::|DFloIsPos|
FOAM::|DFloIsNeg|
FOAM::|DFloIsZero|
FOAM::|DFloEpsilon|
FOAM::|DFloMax|
FOAM::|DFloMin|
FOAM::|DFlo1|
FOAM::|DFlo0|
FOAM::|SFloCeiling|
FOAM::|SFloFloor|
FOAM::|SFloTruncate|
FOAM::|SFloRound|
FOAM::|SFloIPower|
FOAM::|SFloPower|
FOAM::|SFloDivide|
FOAM::|SFloTimes|
FOAM::|SFloMinus|
FOAM::|SFloPlus|
FOAM::|SFloNegate|
FOAM::|SFloNE|
FOAM::|SFloGT|
FOAM::|SFloEQ|
FOAM::|SFloLE|
FOAM::|SFloIsPos|
FOAM::|SFloIsNeg|
FOAM::|SFloIsZero|
FOAM::|SFloEpsilon|
FOAM::|SFloMax|
FOAM::|SFloMin|
FOAM::|SFlo1|
FOAM::|SFlo0|
FOAM::|CharNum|
FOAM::|CharOrd|
FOAM::|CharUpper|
FOAM::|CharLower|
FOAM::|CharNE|
FOAM::|CharGT|
FOAM::|CharEQ|
FOAM::|CharLE|
FOAM::|CharIsLetter|
FOAM::|CharIsDigit|
FOAM::|CharMax|
FOAM::|CharMin|
FOAM::|CharNewline|
FOAM::|CharSpace|
FOAM::|BitNE|
FOAM::|BitEQ|
FOAM::|BitOr|
FOAM::|BitAnd|
FOAM::|BitNot|
FOAM::|BitTrue|
FOAM::|BitFalse|
FOAM::|Clos|
FOAM::COMPILE-AS-FILE
FOAM::|FormatNumber|
FOAM::AXIOMXL-GLOBAL-NAME
FOAM::AXIOMXL-FILE-INIT-NAME
FOAM::|BIntPrev|
FOAM::|BIntLT|
FOAM::|BIntIsSingle|
FOAM::|SIntShiftDn|
FOAM::|SIntShiftUp|
FOAM::|SIntTimesPlus|
FOAM::|SIntNext|
FOAM::|SIntPrev|
FOAM::|SIntLT|
FOAM::|DFloAssemble|
FOAM::|DFloDissemble|
FOAM::|DFloRDivide|
FOAM::|DFloRTimesPlus|
FOAM::|DFloRTimes|
FOAM::|DFloRMinus|
FOAM::|DFloRPlus|
FOAM::|DFloTimesPlus|
FOAM::|DFloNext|
FOAM::|DFloPrev|
FOAM::|DFloLT|
FOAM::|SFloAssemble|
FOAM::|fiStrHash|
FOAM::|SFloDissemble|
FOAM::|SFloRDivide|
FOAM::|SFloRTimesPlus|
FOAM::|SFloRTimes|
FOAM::|fiGetDebugger|
FOAM::|SFloRMinus|
FOAM::|fiSetDebugger|
FOAM::|SFloRPlus|
FOAM::|SFloTimesPlus|
FOAM::|fiGetDebugVar|
FOAM::|SFloNext|
FOAM::|fiSetDebugVar|
FOAM::|SFloPrev|
FOAM::|atan2|
FOAM::|SFloLT|
FOAM::|atan|
FOAM::|acos|
FOAM::|CharLT|
FOAM::|asin|
FOAM::|BoolNE|
FOAM::|tanh|
FOAM::|BoolEQ|
FOAM::|cosh|
FOAM::|BoolOr|
FOAM::|sinh|
FOAM::|BoolAnd|
FOAM::|tan|
FOAM::|BoolNot|
FOAM::|cos|
FOAM::|sin|
FOAM::|BoolTrue|
FOAM::|exp|
FOAM::|BoolFalse|
FOAM::|log|
FOAM::|pow|
FOAM::|sqrt|
FOAM::|fputs|
FOAM::|fputc|
FOAM::|stderrFile|
FOAM::|stdoutFile|
FOAM::|stdinFile|
FOAM::|SetProgHashCode|
FOAM::|ProgHashCode|
FOAM::|formatDFloat|
FOAM::|formatSFloat|
FOAM::|formatBInt|
FOAM::|formatSInt|
FOAM::|strLength|
FOAM::|MakeLevel|
FOAM::|FoamEnvEnsure|
FOAM::|SetEnvInfo|
FOAM::|EnvInfo|
FOAM::|SInt|
FOAM::TYPED-LET
FOAM::FILE-IMPORTS
FOAM::FILE-EXPORTS
FOAM::DEFSPECIALS
FOAM::BLOCK-RETURN
FOAM::CASES
FOAM::IGNORE-VAR
FOAM::DEFPROG
FOAM::DECLARE-TYPE
FOAM::DECLARE-PROG
FOAM::|FoamFree|
FOAM::|SetEElt|
FOAM::|SetAElt|
FOAM::|SetRElt|
FOAM::|SetLex|
FOAM::|Lex|
FOAM::|AElt|
FOAM::|EElt|
FOAM::|ANew|
FOAM::|SetClosFun|
FOAM::|SetClosEnv|
FOAM::|Halt|
FOAM::|BoolToSInt|
FOAM::|SIntToHInt|
FOAM::|SIntToByte|
FOAM::|ByteToSInt|
FOAM::|fputss|
FOAM::|fgetss|
FOAM::|PtrNE|
FOAM::|PtrMagicEQ|
FOAM::|BIntShiftDn|
FOAM::|BIntShiftUp|
FOAM::|BIntBIPower|
FOAM::|BIntSIPower|
FOAM::|BIntTimesPlus|
FOAM::|BIntNext|
))
