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


$stripTypes := false
$pretendFlag := false
$defaultFlag := false
$baseForms := nil
$literals  := nil

spad2AxTranslatorAutoloadOnceTrigger any == true

sourceFilesToAxFile(filename, sourceFiles) ==
  makeAxFile(filename, MAPCAN('fileConstructors, sourceFiles))


$extendedDomains := nil

setExtendedDomains(l) == 
        $extendedDomains := l

fileConstructors name ==
   [INTERN(con,"BOOT") for con in SRCABBREVS SOURCEPATH STRING name]

makeAxFile(filename, constructors) ==
  $defaultFlag : local := false
  $literals := []
  axForms :=
     [modemapToAx(modemap) for cname in constructors |
            (modemap:=GETDATABASE(cname,'CONSTRUCTORMODEMAP)) and
              (not cname in '(Tuple Exit Type)) and
                not isDefaultPackageName cname]
  if $baseForms then
     axForms := [:$baseForms, :axForms]
  if $defaultFlag then
     axForms :=
        [['Foreign, ['Declare, 'dummyDefault, 'Exit], 'Lisp], :axForms]
  axForms := APPEND(axDoLiterals(), axForms)
  axForm := ['Sequence, _
               ['Import, [], 'AxiomLib], ['Import, [], 'Boolean], :axForms]
  st := MAKE_-OUTSTREAM(filename)
  PPRINT(axForm,st)
  CLOSE st

makeAxExportForm(filename, constructors) ==
  $defaultFlag : local := false
  $literals := []
  axForms :=
     [modemapToAx(modemap) for cname in constructors |
            (modemap:=GETDATABASE(cname,'CONSTRUCTORMODEMAP)) and
              (not cname in '(Tuple Exit Type)) and
                not isDefaultPackageName cname]
  if $baseForms then
     axForms := [:$baseForms, :axForms]
  if $defaultFlag then
     axForms :=
        [['Foreign, ['Declare, 'dummyDefault, 'Exit], 'Lisp], :axForms]
  axForms := APPEND(axDoLiterals(), axForms)
  axForm := ['Sequence, _
               ['Import, [], 'AxiomLib], ['Import, [], 'Boolean], :axForms]
  axForm


stripType type ==
  $stripTypes =>
     categoryForm? type => 'Type
     type
  type

modemapToAx(modemap) ==
  modemap is [[consform, target,:argtypes],.]
  consform is [constructor,:args]
  argdecls:=['Comma, : [axFormatDecl(a,stripType t) for a in args for t in argtypes]]
  resultType :=  axFormatType stripType target
  categoryForm? constructor =>
      categoryInfo := GETDATABASE(constructor,'CONSTRUCTORCATEGORY)
      categoryInfo := SUBLISLIS($FormalMapVariableList, $TriangleVariableList,
                       categoryInfo)
      NULL args =>
          ['Define,['Declare, constructor,'Category],
               addDefaults(constructor, axFormatType categoryInfo)]
      ['Define,
          ['Declare, constructor, ['Apply, "->", optcomma argdecls, 'Category]],
           ['Lambda, argdecls, 'Category,
             ['Label, constructor,
               addDefaults(constructor, axFormatType categoryInfo)]]]
  constructor in $extendedDomains =>
     NULL args =>
        ['Extend, ['Define, ['Declare, constructor, resultType],
            ['Add, ['PretendTo, ['Add, [], []], resultType], []]]]
     conscat := INTERN(STRCONC(SYMBOL_-NAME(constructor), "ExtendCategory"),"BOOT")
     rtype := ['Apply, conscat, :args]
--     if resultType is ['With,a,b] then
--        if not(b is ['Sequence,:withseq]) then withseq := [b]
--        cosigs := rest GETDATABASE(constructor, 'COSIG)
--        exportargs := [['Export, [], arg, []] for arg in args for p in cosigs | p]
--        resultType := ['With,a,['Sequence,:APPEND(exportargs, withseq)]]
     consdef := ['Define,
        ['Declare, conscat, ['Apply, "->", optcomma argdecls, 'Category]],
          ['Lambda, argdecls, 'Category, ['Label, conscat, resultType]]]
     ['Sequence, consdef,
      ['Extend, ['Define,
        ['Declare, constructor, ['Apply, "->", optcomma argdecls, rtype]],
          ['Lambda, argdecls, rtype,
            ['Label, constructor,
                ['Add, ['PretendTo, ['Add, [], []], rtype], []]]]]]]
  NULL args =>
     ['Export, ['Declare, constructor, resultType],[],[]]
--  if resultType is ['With,a,b] then
--     if not(b is ['Sequence,:withseq]) then withseq := [b]
--     cosigs := rest GETDATABASE(constructor, 'COSIG)
--     exportargs := [['Export, [], arg, []] for arg in args for p in cosigs | p]
--     resultType := ['With,a,['Sequence,:APPEND(exportargs, withseq)]]
  ['Export, ['Declare, constructor, ['Apply, "->", optcomma argdecls, resultType]],[],[]]

optcomma [op,:args] ==
   # args = 1 => first args
   [op,:args]

axFormatDecl(sym, type) ==
   if sym = '$ then sym := '%
   opOf type in '(StreamAggregate FiniteLinearAggregate) =>
        ['Declare, sym, 'Type]
   ['Declare, sym, axFormatType type]

makeTypeSequence l ==
   ['Sequence,: delete('Type, l)]

axFormatAttrib(typeform) ==
  atom typeform => typeform
  axFormatType typeform

axFormatType(typeform) ==
  atom typeform =>
     typeform = '$ => '%
     STRINGP typeform =>
        ['Apply,'Enumeration, INTERN typeform]
     INTEGERP typeform =>
       -- need to test for PositiveInteger vs Integer
        axAddLiteral('integer, 'PositiveInteger, 'Literal)
        ['RestrictTo, ['LitInteger, STRINGIMAGE typeform ], 'PositiveInteger]
     FLOATP typeform => ['LitFloat, STRINGIMAGE typeform]
     MEMQ(typeform,$TriangleVariableList) =>
        SUBLISLIS($FormalMapVariableList, $TriangleVariableList, typeform)
     MEMQ(typeform, $FormalMapVariableList) => typeform
     axAddLiteral('string, 'Symbol, 'Literal)
     ['RestrictTo, ['LitString, PNAME typeform], 'Symbol]
  typeform is ['construct,: args] =>
      axAddLiteral('bracket, ['Apply, 'List, 'Symbol], [ 'Apply, 'Tuple, 'Symbol])
      axAddLiteral('string, 'Symbol, 'Literal)
      ['RestrictTo, ['Apply, 'bracket, 
                        :[axFormatType a for a in args]],
                          ['Apply, 'List, 'Symbol] ]
  typeform is [op] =>
    op = '$ => '%
    op = 'Void => ['Comma]
    op
  typeform is ['local, val] => axFormatType val
  typeform is ['QUOTE, val] => axFormatType val
  typeform is ['Join,:cats,lastcat] =>
      lastcat is ['CATEGORY,type,:ops] =>
         ['With, [],
            makeTypeSequence(
               APPEND([axFormatType c for c in cats],
                        [axFormatOp op for op in ops]))]
      ['With, [], makeTypeSequence([axFormatType c for c in rest typeform])]
  typeform is ['CATEGORY, type, :ops] =>
      ['With, [],  axFormatOpList ops]
  typeform is ['Mapping, target, :argtypes] =>
      ['Apply, "->",
               ['Comma, :[axFormatType t for t in argtypes]],
                axFormatType target]
  typeform is ['_:, name, type] => axFormatDecl(name,type)
  typeform is ['Union, :args] =>
      first args is ['_:,.,.] =>
         ['Apply, 'Union, :[axFormatType a for a in args]]
      taglist := []
      valueCount := 0
      for x in args repeat
          tag :=
            STRINGP x => INTERN x
            x is ['QUOTE,val] and STRINGP val => INTERN val
            valueCount := valueCount + 1
            INTERNL("value", STRINGIMAGE valueCount)
          taglist := [tag ,: taglist]
      ['Apply, 'Union, :[axFormatDecl(name,type) for name in reverse taglist
                                for type in args]]
  typeform is ['Dictionary,['Record,:args]] =>
      ['Apply, 'Dictionary,
          ['PretendTo, axFormatType CADR typeform, 'SetCategory]]
  typeform is ['FileCategory,xx,['Record,:args]] =>
      ['Apply, 'FileCategory, axFormatType xx,
          ['PretendTo, axFormatType CADDR typeform, 'SetCategory]]
  typeform is [op,:args] =>
      $pretendFlag and constructor? op and
        GETDATABASE(op,'CONSTRUCTORMODEMAP) is [[.,target,:argtypes],.] =>
          ['Apply, op,
               :[['PretendTo, axFormatType a, axFormatType t]
                     for a in args for t in argtypes]]
      MEMQ(op, '(SquareMatrix SquareMatrixCategory DirectProduct
         DirectProductCategory RadixExpansion)) and
            GETDATABASE(op,'CONSTRUCTORMODEMAP) is [[.,target,arg1type,:restargs],.] =>
               ['Apply, op,
                  ['PretendTo, axFormatType first args, axFormatType arg1type],
                     :[axFormatType a for a in rest args]]
      ['Apply, op, :[axFormatType a for a in args]]
  error "unknown entry type"

axFormatOpList ops == ['Sequence,:[axFormatOp o for o in ops]]

axOpTran(name) ==
   ATOM name =>
      name = 'elt => 'apply
      name = 'setelt => 'set!
      name = 'SEGMENT => ".."
      name = 1 => '_1
      name = 0 => '_0
      name
   opOf name = 'Zero => '_0
   opOf name = 'One => '_1
   error "bad op name"

axFormatOpSig(name, [result,:argtypes]) ==
   ['Declare, axOpTran name,
         ['Apply, "->", ['Comma, :[axFormatType t for t in argtypes]],
                        axFormatType result]]

axFormatConstantOp(name, [result]) ==
   ['Declare, axOpTran name, axFormatType result]

axFormatPred pred ==
   atom pred => pred
   [op,:args] := pred
   op = 'IF => axFormatOp pred
   op = 'has =>
      [name,type] := args
      if name = '$ then name := '%
      else name := axFormatOp name
      ftype := axFormatOp type
      if ftype is ['Declare,:.] then
           ftype := ['With, [], ftype]
      ['Test,['Has,name, ftype]]
   axArglist := [axFormatPred arg for arg in args]
   op = 'AND => ['And,:axArglist]
   op = 'OR  => ['Or,:axArglist]
   op = 'NOT => ['Not,:axArglist]
   error "unknown predicate"


axFormatCondOp op ==
  $pretendFlag:local := true
  axFormatOp op


axFormatOp op ==
   op is ['IF, pred, trueops, falseops] =>
      NULL(trueops) or trueops='noBranch =>
         ['If, ['Test,['Not, axFormatPred pred]],
              axFormatCondOp falseops,
                axFormatCondOp trueops]
      ['If, axFormatPred pred,
             axFormatCondOp trueops,
              axFormatCondOp falseops]
       -- ops are either single op or ['PROGN, ops]
   op is ['SIGNATURE, name, type] => axFormatOpSig(name,type)
   op is ['SIGNATURE, name, type, 'constant] =>
            axFormatConstantOp(name,type)
   op is ['ATTRIBUTE, attributeOrCategory] =>
       categoryForm? attributeOrCategory =>
           axFormatType attributeOrCategory
       ['RestrictTo, axFormatAttrib attributeOrCategory, 'Category]
   op is ['PROGN, :ops] => axFormatOpList ops
   op is 'noBranch => []
   axFormatType op

addDefaults(catname, withform) ==
  withform isnt ['With, joins, ['Sequence,: oplist]] =>
     error "bad category body"
  null(defaults := getDefaultingOps catname) => withform
  defaultdefs := [makeDefaultDef(decl) for decl in defaults]
  ['With, joins,
     ['Sequence, :oplist, ['Default, ['Sequence,: defaultdefs]]]]

makeDefaultDef(decl) ==
  decl isnt ['Declare, op, type] =>
       error "bad default definition"
  $defaultFlag := true
  type is ['Apply, "->", args, result] =>
       ['Define, decl, ['Lambda, makeDefaultArgs args, result,
                    ['Label, op, 'dummyDefault]]]
  ['Define, ['Declare, op, type], 'dummyDefault]

makeDefaultArgs args ==
  args isnt ['Comma,:argl] => error "bad default argument list"
  ['Comma,: [['Declare,v,t] for v in $TriangleVariableList for t in argl]]

getDefaultingOps catname ==
  not(name:=hasDefaultPackage catname) => nil
  $infovec: local := getInfovec name
  opTable := $infovec.1
  $opList:local  := nil
  for i in 0..MAXINDEX opTable repeat
    op := opTable.i
    i := i + 1
    startIndex := opTable.i
    stopIndex :=
      i + 1 > MAXINDEX opTable => MAXINDEX getCodeVector()
      opTable.(i + 2)
    curIndex := startIndex
    while curIndex < stopIndex repeat
      curIndex := get1defaultOp(op,curIndex)
  $pretendFlag : local := true
  catops := GETDATABASE(catname, 'OPERATIONALIST)
  [axFormatDefaultOpSig(op,sig,catops) for opsig in $opList | opsig is [op,sig]]

axFormatDefaultOpSig(op, sig, catops) ==
  #sig > 1 => axFormatOpSig(op,sig)
  nsig := MSUBST('$,'($), sig) -- dcSig listifies '$ ??
  (catsigs := LASSOC(op, catops)) and
    (catsig := assoc(nsig, catsigs)) and last(catsig) = 'CONST =>
       axFormatConstantOp(op, sig)
  axFormatOpSig(op,sig)

get1defaultOp(op,index) ==
  numvec := getCodeVector()
  segment := getOpSegment index
  numOfArgs := numvec.index
  index := index + 1
  predNumber := numvec.index
  index := index + 1
  signumList :=
 -- following substitution fixes the problem that default packages
 -- have $ added as a first arg, thus other arg counts are off by 1.
    SUBLISLIS($FormalMapVariableList, rest $FormalMapVariableList,
             dcSig(numvec,index,numOfArgs))
  index := index + numOfArgs + 1
  slotNumber := numvec.index
  if not([op,signumList] in $opList) then
     $opList := [[op,signumList],:$opList]
  index + 1

axAddLiteral(name, type, dom) == 
  elt := [name, type, dom]
  if not member( elt, $literals) then
     $literals := [elt, :$literals]

axDoLiterals() == 
  [ [ 'Import,
          [ 'With, [], 
            ['Declare, name, [ 'Apply, '_-_> , dom , '_% ]]],
                 type ] for [name, type, dom] in $literals]

