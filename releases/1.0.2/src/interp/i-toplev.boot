-- Copyright (c) 1991-2002, The Numerical ALgorithms Group Ltd.
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are
-- met:
--
--     - Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--
--     - Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in
--       the documentation and/or other materials provided with the
--       distribution.
--
--     - Neither the name of The Numerical ALgorithms Group Ltd. nor the
--       names of its contributors may be used to endorse or promote products
--       derived from this software without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
-- IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
-- TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
-- PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
-- OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
-- EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
-- PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
-- PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
-- LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
-- NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


-- This file contains the top-most code for receiving parser output,
-- calling the analysis routines and printing the result output. It
-- also contains several flavors of routines that start the interpreter
-- from LISP.


--% Top Level Interpreter Code

-- When $QuiteCommand is true Spad will not produce any output from
--  a top level command
SETANDFILEQ($QuietCommand, NIL)
-- When $ProcessInteractiveValue is true, we don't want the value printed
-- or recorded.
SETANDFILEQ($ProcessInteractiveValue, NIL)
SETANDFILEQ($HTCompanionWindowID, NIL)

intSetQuiet() ==
  $QuietCommand := true

intUnsetQuiet() ==
  $QuietCommand := nil

--% Starting the interpreter from LISP

spadpo() ==
  -- starts the interpreter but only displays parsed input
  $PrintOnly: local:= true
  spad()

start(:l) ==
  -- The function  start  begins the interpreter process, reading in
  -- the profile and printing start-up messages.
  $PrintCompilerMessageIfTrue: local := nil
  $inLispVM : local := nil
  if $displayStartMsgs then sayKeyedMsg("S2IZ0053",['"interpreter"])
  initializeTimedNames($interpreterTimedNames,$interpreterTimedClasses)
  statisticsInitialization()
  $InteractiveFrame := makeInitialModemapFrame()
  initializeSystemCommands()
  initializeInterpreterFrameRing()
  setOutputAlgebra "%initialize%"
  loadExposureGroupData()
  if $displayStartMsgs then sayKeyedMsg("S2IZ0053",['"database"])
  mkLowerCaseConTable()
  if not $ruleSetsInitialized then initializeRuleSets()
  if $displayStartMsgs then sayKeyedMsg("S2IZ0053",['"constructors"])
  makeConstructorsAutoLoad()
  GCMSG(NIL)
  SETQ($IOindex,1)
  if $displayStartMsgs then sayKeyedMsg("S2IZ0053",['"history"])
  initHist()
  if functionp 'addtopath then addtopath CONCAT($SPADROOT,'"bin")
  if null(l) then
    if $displayStartMsgs then
      sayKeyedMsg("S2IZ0053",[namestring ['_.axiom,'input]])
    readSpadProfileIfThere()
  if $displayStartMsgs then spadStartUpMsgs()
  if $OLDLINE then
    SAY fillerSpaces($LINELENGTH,'"=")
    sayKeyedMsg("S2IZ0050",[namestring ['axiom,'input]])
    if $OLDLINE ^= 'END__UNIT
      then
        centerAndHighlight($OLDLINE,$LINELENGTH,'" ")
        sayKeyedMsg("S2IZ0051",NIL)
      else sayKeyedMsg("S2IZ0052",NIL)
    SAY fillerSpaces($LINELENGTH,'"=")
    TERPRI()
    $OLDLINE := NIL
  $superHash := MAKE_-HASHTABLE('UEQUAL)
  if null l then runspad()
  'EndOfSpad

readSpadProfileIfThere() ==
  -- reads SPADPROF INPUT if it exists
  file := ['_.axiom,'input]
  MAKE_-INPUT_-FILENAME file =>
    SETQ(_/EDITFILE,file)
    _/RQ ()
  NIL

--% Parser Output --> Interpreter

processInteractive(form, posnForm) ==
  --  Top-level dispatcher for the interpreter.  It sets local variables
  --  and then calls processInteractive1 to do most of the work.
  --  This function receives the output from the parser.

  initializeTimedNames($interpreterTimedNames,$interpreterTimedClasses)

  $op: local:= (form is [op,:.] => op; form) --name of operator
  $Coerce: local := NIL
  $compErrorMessageStack:local := nil
  $freeVars : local := NIL
  $mapList:local := NIL            --list of maps being type analyzed
  $compilingMap:local:= NIL        --true when compiling a map
  $compilingLoop:local:= NIL       --true when compiling a loop body
  $interpOnly: local := NIL        --true when in interpret only mode
  $whereCacheList: local := NIL    --maps compiled because of where
  $timeGlobalName: local := '$compTimeSum  --see incrementTimeSum
  $StreamFrame: local := nil       --used in printing streams
  $declaredMode: local := NIL      --Weak type propagation for symbols
  $localVars:local := NIL          --list of local variables in function
  $analyzingMapList:local := NIL   --names of maps currently being
                                   --analyzed
  $lastLineInSEQ: local := true    --see evalIF and friends
  $instantCoerceCount: local := 0
  $instantCanCoerceCount: local := 0
  $instantMmCondCount: local := 0
  $defaultFortVar:= 'X             --default FORTRAN variable name
  $fortVar : local :=              --variable name for FORTRAN output
     $defaultFortVar
  $minivector: local := NIL
  $minivectorCode: local := NIL
  $minivectorNames: local := NIL
  $domPvar: local := NIL
  $inRetract: local := NIL
  object := processInteractive1(form, posnForm)
  --object := ERRORSET(LIST('processInteractive1,LIST('QUOTE,form),LIST('QUOTE,posnForm)),'t,'t)
  if not($ProcessInteractiveValue) then
    if $reportInstantiations = true then
      reportInstantiations()
      CLRHASH $instantRecord
    writeHistModesAndValues()
    updateHist()
  object

processInteractive1(form, posnForm) ==
  -- calls the analysis and output printing routines
  $e : local := $InteractiveFrame
  recordFrame 'system

  startTimingProcess 'analysis
  object   := interpretTopLevel(form, posnForm)
  stopTimingProcess 'analysis

  startTimingProcess 'print
  if not($ProcessInteractiveValue) then
    recordAndPrint(objValUnwrap object,objMode object)
  recordFrame 'normal
  stopTimingProcess 'print

--spadtestValueHook(objValUnwrap object, objMode object)

  object

ncParseAndInterpretString s ==
   processInteractive(packageTran(parseFromString(s)), nil)

--% Result Output Printing

recordAndPrint(x,md) ==
  --  Prints out the value x which is of type m, and records the changes
  --  in environment $e into $InteractiveFrame
  --  $printAnyIfTrue  is documented in setvart.boot. controlled with )se me any
  if md = '(Any) and $printAnyIfTrue  then
    md' := first  x
    x' := rest x
  else
    x' := x
    md' := md
  $outputMode: local := md   --used by DEMO BOOT
  mode:= (md=$EmptyMode => quadSch(); md)
  if (md ^= $Void) or $printVoidIfTrue then
    if null $collectOutput then TERPRI $algebraOutputStream
    if $QuietCommand = false then
      output(x',md')
  putHist('%,'value,objNewWrap(x,md),$e)
  if $printTimeIfTrue or $printTypeIfTrue then printTypeAndTime(x',md')
  if $printStorageIfTrue then printStorage()
  if $printStatisticsSummaryIfTrue then printStatisticsSummary()
  if FIXP $HTCompanionWindowID then mkCompanionPage md
  $mkTestFlag = true => recordAndPrintTest md
  $runTestFlag =>
    $mkTestOutputType := md
    'done
  'done

printTypeAndTime(x,m) ==  --m is the mode/type of the result
  ioHook("startTypeAndTime")
  $saturn => printTypeAndTimeSaturn(x, m)
  printTypeAndTimeNormal(x, m)
  ioHook("endOfTypeAndTime")

printTypeAndTimeNormal(x,m) ==
  -- called only if either type or time is to be displayed
  if m is ['Union, :argl] then
    x' := retract(objNewWrap(x,m))
    m' := objMode x'
    m := ['Union, :[arg for arg in argl | sameUnionBranch(arg, m')], '"..."]
  if $printTimeIfTrue then
    timeString := makeLongTimeString($interpreterTimedNames,
      $interpreterTimedClasses)
  $printTimeIfTrue and $printTypeIfTrue =>
    $collectOutput =>
      $outputLines := [msgText("S2GL0012", [m]), :$outputLines]
    sayKeyedMsg("S2GL0014",[m,timeString])
  $printTimeIfTrue =>
    $collectOutput => nil
    sayKeyedMsg("S2GL0013",[timeString])
  $printTypeIfTrue =>
    $collectOutput =>
      $outputLines := [justifyMyType msgText("S2GL0012", [m]), :$outputLines]
    sayKeyedMsg("S2GL0012",[m])

printTypeAndTimeSaturn(x, m) ==
  -- header
  if $printTimeIfTrue then
    timeString := makeLongTimeString($interpreterTimedNames,
      $interpreterTimedClasses)
  else
    timeString := '""
  if $printTypeIfTrue then
    typeString := form2StringAsTeX devaluate m
  else
    typeString := '""
  if $printTypeIfTrue then
    printAsTeX('"\axPrintType{")
    if CONSP typeString then
      MAPC(FUNCTION printAsTeX, typeString)
    else
      printAsTeX(typeString)
    printAsTeX('"}")
  if $printTimeIfTrue then
    printAsTeX('"\axPrintTime{")
    printAsTeX(timeString)
    printAsTeX('"}")

printAsTeX(x) == PRINC(x, $texOutputStream)

sameUnionBranch(uArg, m) ==
  uArg is [":", ., t] => t = m
  uArg = m

msgText(key, args) ==
  msg := segmentKeyedMsg getKeyedMsg key
  msg := substituteSegmentedMsg(msg,args)
  msg := flowSegmentedMsg(msg,$LINELENGTH,$MARGIN)
  APPLY(function CONCAT, [STRINGIMAGE x for x in CDAR msg])

justifyMyType(t) ==
  len := #t
  len > $LINELENGTH => t
  CONCAT(fillerSpaces($LINELENGTH-len), t)

typeTimePrin x ==
  $highlightDelta: local:= 0
  maprinSpecial(x,0,79)

printStorage() ==
  $collectOutput => nil
  storeString :=
    makeLongSpaceString($interpreterTimedNames, $interpreterTimedClasses)
  sayKeyedMsg("S2GL0016",[storeString])

printStatisticsSummary() ==
  $collectOutput => nil
  summary := statisticsSummary()
  sayKeyedMsg("S2GL0017",[summary])

--%  Interpreter Middle-Level Driver + Utilities

interpretTopLevel(x, posnForm) ==
  --  Top level entry point from processInteractive1.  Sets up catch
  --  for a thrown result
  savedTimerStack := COPY $timedNameStack
  c := CATCH('interpreter,interpret(x, posnForm))
  while savedTimerStack ^= $timedNameStack repeat
    stopTimingProcess peekTimedName()
  c = 'tryAgain => interpretTopLevel(x, posnForm)
  c

interpret(x, :restargs) ==
  posnForm := if PAIRP restargs then CAR restargs else restargs
  --type analyzes and evaluates expression x, returns object
  $env:local := [[NIL]]
  $eval:local := true           --generate code-- don't just type analyze
  $genValue:local := true       --evaluate all generated code
  interpret1(x,nil,posnForm)

interpret1(x,rootMode,posnForm) ==
  -- dispatcher for the type analysis routines.  type analyzes and
  -- evaluates the expression x in the rootMode (if non-nil)
  -- which may be $EmptyMode.  returns an object if evaluating, and a
  -- modeset otherwise

  -- create the attributed tree

  node := mkAtreeWithSrcPos(x, posnForm)
  if rootMode then putTarget(node,rootMode)

  -- do type analysis and evaluation of expression.  The real guts

  modeSet:= bottomUp node
  not $eval => modeSet
  newRootMode := (null rootMode => first modeSet ; rootMode)
  argVal := getArgValue(node, newRootMode)
  argVal and not $genValue => objNew(argVal, newRootMode)
  argVal and (val:=getValue node) => interpret2(val,newRootMode,posnForm)
  keyedSystemError("S2IS0053",[x])

interpret2(object,m1,posnForm) ==
  -- this is the late interpretCoerce. I removed the call to
  -- coerceInteractive, so it only does the JENKS cases    ALBI
  m1=$ThrowAwayMode => object
  x := objVal object
  m := objMode object
  m=$EmptyMode =>
    x is [op,:.]  and op in '(MAP STREAM) => objNew(x,m1)
    m1 = $EmptyMode => objNew(x,m)
    systemErrorHere '"interpret2"
  m1 =>
    if (ans := coerceInteractive(object,m1)) then ans
    else throwKeyedMsgCannotCoerceWithValue(x,m,m1)
  object
