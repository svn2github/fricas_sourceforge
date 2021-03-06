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


--% FUNCTIONS WHICH MUNCH ON == STATEMENTS
 
compDefine(form,m,e) ==
  $tripleCache: local:= nil
  $tripleHits: local:= 0
  $macroIfTrue: local := nil
  $packagesUsed: local := nil
  result:= compDefine1(form,m,e)
  result
 
compDefine1(form,m,e) ==
  $insideExpressionIfTrue: local:= false
  --1. decompose after macro-expanding form
  ['DEF,lhs,signature,specialCases,rhs]:= form:= macroExpand(form,e)
  $insideWhereIfTrue and isMacro(form,e) and (m=$EmptyMode or m=$NoValueMode)
     => [lhs,m,put(first lhs,'macro,rhs,e)]
  null signature.target and not MEMQ(KAR rhs,$ConstructorNames) and
    (sig:= getSignatureFromMode(lhs,e)) =>
  -- here signature of lhs is determined by a previous declaration
      compDefine1(['DEF,lhs,[first sig,:rest signature],specialCases,rhs],m,e)
  if signature.target=$Category then $insideCategoryIfTrue:= true
--?? following 3 lines seem bogus, BMT 6/23/93
--?  if signature.target is ['Mapping,:map] then
--?    signature:= map
--?    form:= ['DEF,lhs,signature,specialCases,rhs]
 
-- RDJ (11/83): when argument and return types are all declared,
--  or arguments have types declared in the environment,
--  and there is no existing modemap for this signature, add
--  the modemap by a declaration, then strip off declarations and recurse
  e := compDefineAddSignature(lhs,signature,e)
-- 2. if signature list for arguments is not empty, replace ('DEF,..) by
--       ('where,('DEF,..),..) with an empty signature list;
--     otherwise, fill in all NILs in the signature
  not (and/[null x for x in rest signature]) => compDefWhereClause(form,m,e)
  signature.target=$Category =>
    compDefineCategory(form,m,e,nil,$formalArgList)
  isDomainForm(rhs,e) and not $insideFunctorIfTrue =>
    if null signature.target then signature:=
      [getTargetFromRhs(lhs,rhs,giveFormalParametersValues(rest lhs,e)),:
          rest signature]
    rhs:= addEmptyCapsuleIfNecessary(signature.target,rhs)
    compDefineFunctor(['DEF,lhs,signature,specialCases,rhs],m,e,nil,
      $formalArgList)
  null $form => stackAndThrow ['"bad == form ",form]
  newPrefix:=
    $prefix => INTERN STRCONC(encodeItem $prefix,'",",encodeItem $op)
    getAbbreviation($op,#rest $form)
  compDefineCapsuleFunction(form,m,e,newPrefix,$formalArgList)
 
compDefineAddSignature([op,:argl],signature,e) ==
  (sig:= hasFullSignature(argl,signature,e)) and
   not assoc(['$,:sig],LASSOC('modemap,getProplist(op,e))) =>
     declForm:=
       [":",[op,:[[":",x,m] for x in argl for m in rest sig]],first signature]
     [.,.,e]:= comp(declForm,$EmptyMode,e)
     e
  e
 
hasFullSignature(argl,[target,:ml],e) ==
  target =>
    u:= [m or get(x,"mode",e) or return 'failed for x in argl for m in ml]
    u^='failed => [target,:u]
 
addEmptyCapsuleIfNecessary(target,rhs) ==
  MEMQ(KAR rhs,$SpecialDomainNames) => rhs
  ['add,rhs,['CAPSULE]]
 
getTargetFromRhs(lhs,rhs,e) ==
  --undeclared target mode obtained from rhs expression
  rhs is ['CAPSULE,:.] =>
    stackSemanticError(['"target category of ",lhs,
      '" cannot be determined from definition"],nil)
  rhs is ['SubDomain,D,:.] => getTargetFromRhs(lhs,D,e)
  rhs is ['add,D,['CAPSULE,:.]] => getTargetFromRhs(lhs,D,e)
  rhs is ['Record,:l] => ['RecordCategory,:l]
  rhs is ['Union,:l] => ['UnionCategory,:l]
  rhs is ['List,:l] => ['ListCategory,:l]
  rhs is ['Vector,:l] => ['VectorCategory,:l]
  [.,target,.]:= compOrCroak(rhs,$EmptyMode,e)
  target
 
giveFormalParametersValues(argl,e) ==
  for x in argl repeat
    e:= put(x,'value,[genSomeVariable(),get(x,'mode,e),nil],e)
  e
 
macroExpandInPlace(x,e) ==
  y:= macroExpand(x,e)
  atom x or atom y => y
  RPLACA(x,first y)
  RPLACD(x,rest y)
  x
 
macroExpand(x,e) ==   --not worked out yet
  atom x => (u:= get(x,'macro,e) => macroExpand(u,e); x)
  x is ['DEF,lhs,sig,spCases,rhs] =>
    ['DEF,macroExpand(lhs,e),macroExpandList(sig,e),macroExpandList(spCases,e),
      macroExpand(rhs,e)]
  macroExpandList(x,e)
 
macroExpandList(l,e) ==
  -- macros should override niladic props
  (l is [name]) and IDENTP name and GETDATABASE(name, 'NILADIC) and
        (u := get(name, 'macro, e)) => macroExpand(u,e)
  [macroExpand(x,e) for x in l]
 
compDefineCategory1(df is ['DEF,form,sig,sc,body],m,e,prefix,fal) ==
  categoryCapsule :=
--+
    body is ['add,cat,capsule] =>
      body := cat
      capsule
    nil
  [d,m,e]:= compDefineCategory2(form,sig,sc,body,m,e,prefix,fal)
--+ next two lines
  if categoryCapsule and not $bootStrapMode then [.,.,e] :=
    $insideCategoryPackageIfTrue: local := true  --see NRTmakeSlot1
-->
    $categoryPredicateList: local :=
        makeCategoryPredicates(form,$lisplibCategory)
    compDefine1(mkCategoryPackage(form,cat,categoryCapsule),$EmptyMode,e)
  [d,m,e]
 
makeCategoryPredicates(form,u) ==
      $tvl := TAKE(#rest form,$TriangleVariableList)
      $mvl := TAKE(#rest form,rest $FormalMapVariableList)
      fn(u,nil) where
        fn(u,pl) ==
          u is ['Join,:.,a] => fn(a,pl)
          u is ['has,:.] => insert(EQSUBSTLIST($mvl,$tvl,u),pl)
          u is [op,:.] and MEMQ(op,'(SIGNATURE ATTRIBUTE)) => pl
          atom u => pl
          fnl(u,pl)
        fnl(u,pl) ==
          for x in u repeat pl := fn(x,pl)
          pl
 
--+ the following function
mkCategoryPackage(form is [op,:argl],cat,def) ==
  packageName:= INTERN(STRCONC(PNAME op,'"&"))
  packageAbb := INTERN(STRCONC(GETDATABASE(op,'ABBREVIATION),'"-"))
  $options:local := []
  -- This stops the next line from becoming confused
  abbreviationsSpad2Cmd ['domain,packageAbb,packageName]
  -- This is a little odd, but the parser insists on calling
  -- domains, rather than packages
  nameForDollar := first SETDIFFERENCE('(S A B C D E F G H I),argl)
  packageArgl := [nameForDollar,:argl]
  capsuleDefAlist := fn(def,nil) where fn(x,oplist) ==
    atom x => oplist
    x is ['DEF,y,:.] => [y,:oplist]
    fn(rest x,fn(first x,oplist))
  explicitCatPart := gn cat where gn cat ==
    cat is ['CATEGORY,:.] => rest rest cat
    cat is ['Join,:u] => gn last u
    nil
  catvec := eval mkEvalableCategoryForm form
  fullCatOpList:=JoinInner([catvec],$e).1
  catOpList :=
    --note: this gets too many modemaps in general
    --   this is cut down in NRTmakeSlot1
    [['SIGNATURE,op1,sig] for [[op1,sig],:.] in fullCatOpList
         --above line calls the category constructor just compiled
        | assoc(op1,capsuleDefAlist)]
  null catOpList => nil
  packageCategory := ['CATEGORY,'domain,
                     :SUBLISLIS(argl,$FormalMapVariableList,catOpList)]
  nils:= [nil for x in argl]
  packageSig := [packageCategory,form,:nils]
  $categoryPredicateList := SUBST(nameForDollar,'$,$categoryPredicateList)
  SUBST(nameForDollar,'$,
      ['DEF,[packageName,:packageArgl],packageSig,[nil,:nils],def])
 
compDefineCategory2(form,signature,specialCases,body,m,e,
  $prefix,$formalArgList) ==
    --1. bind global variables
    $insideCategoryIfTrue: local:= true
    $TOP__LEVEL: local := nil
    $definition: local := nil
                 --used by DomainSubstitutionFunction
    $form: local := nil
    $op: local := nil
    $extraParms: local := nil
             --Set in DomainSubstitutionFunction, used further down
--  1.1  augment e to add declaration $: <form>
    [$op,:argl]:= $definition:= form
    e:= addBinding("$",[['mode,:$definition]],e)
 
--  2. obtain signature
    signature':=
      [first signature,:[getArgumentModeOrMoan(a,$definition,e) for a in argl]]
    e:= giveFormalParametersValues(argl,e)
 
--   3. replace arguments by $1,..., substitute into body,
--     and introduce declarations into environment
    sargl:= TAKE(# argl, $TriangleVariableList)
    $functorForm:= $form:= [$op,:sargl]
    $formalArgList:= [:sargl,:$formalArgList]
    aList:= [[a,:sa] for a in argl for sa in sargl]
    formalBody:= SUBLIS(aList,body)
    signature' := SUBLIS(aList,signature')
--Begin lines for category default definitions
    $functionStats: local:= [0,0]
    $functorStats: local:= [0,0]
    $frontier: local := 0
    $getDomainCode: local := nil
    $addForm: local:= nil
    for x in sargl for t in rest signature' repeat
      [.,.,e]:= compMakeDeclaration([":",x,t],m,e)
 
--   4. compile body in environment of %type declarations for arguments
    op':= $op
    -- following line causes cats with no with or Join to be fresh copies
    if opOf(formalBody)^='Join and opOf(formalBody)^='mkCategory then
           formalBody := ['Join, formalBody]
    body:= optFunctorBody (compOrCroak(formalBody,signature'.target,e)).expr
    if $extraParms then
      formals:=actuals:=nil
      for u in $extraParms repeat
        formals:=[CAR u,:formals]
        actuals:=[MKQ CDR u,:actuals]
      body := ['sublisV,['PAIR,['QUOTE,formals],['LIST,:actuals]],body]
    if argl then body:=  -- always subst for args after extraparms
        ['sublisV,['PAIR,['QUOTE,sargl],['LIST,:
          [['devaluate,u] for u in sargl]]],body]
    body:=
      ['PROG1,['LET,g:= GENSYM(),body],['SETELT,g,0,mkConstructor $form]]
    fun:= compile [op',['LAM,sargl,body]]
 
--  5. give operator a 'modemap property
    pairlis:= [[a,:v] for a in argl for v in $FormalMapVariableList]
    parSignature:= SUBLIS(pairlis,signature')
    parForm:= SUBLIS(pairlis,form)
    lisplibWrite('"compilerInfo",
      removeZeroOne ['SETQ,'$CategoryFrame,
       ['put,['QUOTE,op'],'
        (QUOTE isCategory),true,['addModemap,MKQ op',MKQ parForm,
          MKQ parSignature,true,MKQ fun,'$CategoryFrame]]],$libFile)
    --Equivalent to the following two lines, we hope
    if null sargl then
      evalAndRwriteLispForm('NILADIC,
            ['MAKEPROP,['QUOTE,op'],'(QUOTE NILADIC),true])
 
--   6. put modemaps into InteractiveModemapFrame
    $domainShell := eval [op',:MAPCAR('MKQ,sargl)]
    $lisplibCategory:= formalBody
    if $LISPLIB then
      $lisplibForm:= form
      $lisplibKind:= 'category
      modemap:= [[parForm,:parSignature],[true,op']]
      $lisplibModemap:= modemap
      $lisplibParents  :=         
        getParentsFor($op,$FormalMapVariableList,$lisplibCategory)
      $lisplibAncestors := computeAncestorsOf($form,nil)
      $lisplibAbbreviation := constructor? $op
      form':=[op',:sargl]
      augLisplibModemapsFromCategory(form',formalBody,signature')
    [fun,'(Category),e]
 
mkConstructor form ==
  atom form => ['devaluate,form]
  null rest form => ['QUOTE,[first form]]
  ['LIST,MKQ first form,:[mkConstructor x for x in rest form]]
 
compDefineCategory(df,m,e,prefix,fal) ==
  $domainShell: local -- holds the category of the object being compiled
  $lisplibCategory: local := nil
  not $insideFunctorIfTrue and $LISPLIB =>
    compDefineLisplib(df,m,e,prefix,fal,'compDefineCategory1)
  compDefineCategory1(df,m,e,prefix,fal)
 
compDefineFunctor(df,m,e,prefix,fal) ==
  $domainShell: local -- holds the category of the object being compiled
  -- Our profiling machinery is a big time sink ...
  -- $profileCompiler: local := true
  $profileAlist:    local := nil
  $LISPLIB => compDefineLisplib(df,m,e,prefix,fal,'compDefineFunctor1)
  compDefineFunctor1(df,m,e,prefix,fal)
 
compDefineFunctor1(df is ['DEF,form,signature,$functorSpecialCases,body],
  m,$e,$prefix,$formalArgList) ==
    if NRTPARSE = true then
      [lineNumber,:$functorSpecialCases] := $functorSpecialCases
--  1. bind global variables
    $addForm: local := nil
    $viewNames: local:= nil
 
            --This list is only used in genDomainViewName, for generating names
            --for alternate views, if they do not already exist.
            --format: Alist: (domain name . sublist)
            --sublist is alist: category . name of view
    $functionStats: local:= [0,0]
    $functorStats: local:= [0,0]
    $form: local := nil
    $op: local := nil
    $signature: local := nil
    $functorTarget: local := nil
    $Representation: local := nil
         --Set in doIt, accessed in the compiler - compNoStacking
    $LocalDomainAlist: local := nil --set in doIt, accessed in genDeltaEntry
    $LocalDomainAlist := nil
    $functorForm: local := nil
    $functorLocalParameters: local := nil
    $CheckVectorList: local := nil
                  --prevents CheckVector from printing out same message twice
    $getDomainCode: local := nil -- code for getting views
    $insideFunctorIfTrue: local:= true
    $functorsUsed: local := nil --not currently used, finds dependent functors
    $setelt: local :=
      $QuickCode = true => 'QSETREFV
      'SETELT
    $TOP__LEVEL: local := nil
    $genFVar: local:= 0
    $genSDVar: local:= 0
    originale:= $e
    [$op,:argl]:= form
    $formalArgList:= [:argl,:$formalArgList]
    $pairlis := [[a,:v] for a in argl for v in $FormalMapVariableList]
    $mutableDomain: local :=
      -- all defaulting packages should have caching turned off
       isCategoryPackageName $op or   
         (if BOUNDP '$mutableDomains then MEMQ($op,$mutableDomains)
            else false )   --true if domain has mutable state
    signature':=
      [first signature,:[getArgumentModeOrMoan(a,form,$e) for a in argl]]
    $functorForm:= $form:= [$op,:argl]
    if null first signature' then signature':=
      modemap2Signature getModemap($form,$e)
    target:= first signature'
    $functorTarget:= target
    $e:= giveFormalParametersValues(argl,$e)
    [ds,.,$e]:= compMakeCategoryObject(target,$e) or
--+ copy needed since slot1 is reset; compMake.. can return a cached vector
      sayBrightly '"   cannot produce category object:"
      pp target
      return nil
    $domainShell:= COPY_-SEQ ds
    $attributesName:local := INTERN STRCONC(PNAME $op,'";attributes")
    attributeList := disallowNilAttribute ds.2 --see below under "loadTimeAlist"
--+ 7 lines for $NRT follow
    $goGetList: local := nil
-->--these globals used by NRTmakeCategoryAlist, set by NRTsetVector4Part1
    $condAlist: local := nil
    $uncondAlist: local := nil
-->>-- next global initialized here, reset by NRTbuildFunctor
    $NRTslot1PredicateList: local :=
      REMDUP [CADR x for x in attributeList]
-->>-- next global initialized here, used by NRTgenAttributeAlist (NRUNOPT)
    $NRTattributeAlist: local := NRTgenInitialAttributeAlist attributeList
    $NRTslot1Info: local  --set in NRTmakeSlot1 called by NRTbuildFunctor
       --this is used below to set $lisplibSlot1 global
    $NRTbase: local := 6 -- equals length of $domainShell
    $NRTaddForm: local := nil   -- see compAdd; NRTmakeSlot1
    $NRTdeltaList: local := nil --list of misc. elts used in compiled fncts
    $NRTdeltaListComp: local := nil --list of COMP-ed forms for $NRTdeltaList
    $NRTaddList: local := nil --list of fncts not defined in capsule (added)
    $NRTdeltaLength: local := 0 -- =length of block of extra entries in vector
    $NRTloadTimeAlist: local := nil --used for things in slot4 (NRTsetVector4)
    $NRTdomainFormList: local := nil -- of form ((gensym . (Repe...)) ...
    -- the above optimizes the calls to local domains
    $template: local:= nil --stored in the lisplib (if $NRTvec = true)
    $functionLocations: local := nil --locations of defined functions in source
    -- generate slots for arguments first, then for $NRTaddForm in compAdd
    for x in argl repeat NRTgetLocalIndex x
    [.,.,$e]:= compMakeDeclaration([":",'_$,target],m,$e)
    --The following loop sees if we can economise on ADDed operations
    --by using those of Rep, if that is the same. Example: DIRPROD
    if $insideCategoryPackageIfTrue^= true  then
      if body is ['add,ab:=[fn,:.],['CAPSULE,:cb]] and MEMQ(fn,'(List Vector))
         and FindRep(cb) = ab
               where FindRep cb ==
                 u:=
                   while cb repeat
                     ATOM cb => return nil
                     cb is [['LET,'Rep,v,:.],:.] => return (u:=v)
                     cb:=CDR cb
                 u
      then $e:= augModemapsFromCategoryRep('_$,ab,cb,target,$e)
      else $e:= augModemapsFromCategory('_$,'_$,'_$,target,$e)
    $signature:= signature'
    operationAlist:= SUBLIS($pairlis,$domainShell.(1))
    parSignature:= SUBLIS($pairlis,signature')
    parForm:= SUBLIS($pairlis,form)
 
--  (3.1) now make a list of the functor's local parameters; for
--  domain D in argl,check its signature: if domain, its type is Join(A1,..,An);
--  in this case, D is replaced by D1,..,Dn (gensyms) which are set
--  to the A1,..,An view of D
    if isPackageFunction() then $functorLocalParameters:=
      [nil,:
        [nil
          for i in 6..MAXINDEX $domainShell |
            $domainShell.i is [.,.,['ELT,'_$,.]]]]
    --leave space for vector ops and package name to be stored
--+
    $functorLocalParameters:=
      argPars :=
        makeFunctorArgumentParameters(argl,rest signature',first signature')
 -- must do above to bring categories into scope --see line 5 of genDomainView
      argl
--  4. compile body in environment of %type declarations for arguments
    op':= $op
    rettype:= signature'.target
    T:= compFunctorBody(body,rettype,$e,parForm)
    -- If only compiling certain items, then ignore the body shell.
    $compileOnlyCertainItems =>
       reportOnFunctorCompilation()
       [nil, ['Mapping, :signature'], originale]
 
    body':= T.expr
    lamOrSlam:= if $mutableDomain then 'LAM else 'SPADSLAM
    fun:= compile SUBLIS($pairlis, [op',[lamOrSlam,argl,body']])
    --The above statement stops substitutions gettting in one another's way
--+
    operationAlist := SUBLIS($pairlis,$lisplibOperationAlist)
    if $LISPLIB then
      augmentLisplibModemapsFromFunctor(parForm,operationAlist,parSignature)
    reportOnFunctorCompilation()
 
--  5. give operator a 'modemap property
--   if $functorsUsed then MAKEPROP(op',"NEEDS",$functorsUsed)
    if $LISPLIB then
      modemap:= [[parForm,:parSignature],[true,op']]
      $lisplibModemap:= modemap
      $lisplibCategory := modemap.mmTarget
      $lisplibParents  :=         
        getParentsFor($op,$FormalMapVariableList,$lisplibCategory)
      $lisplibAncestors := computeAncestorsOf($form,nil)
      $lisplibAbbreviation := constructor? $op
    $insideFunctorIfTrue:= false
    if $LISPLIB then
      $lisplibKind:=
------->This next line prohibits changing the KIND once given
--------kk:=GETDATABASE($op,'CONSTRUCTORKIND) => kk
        $functorTarget is ["CATEGORY",key,:.] and key^="domain" => 'package
        'domain
      $lisplibForm:= form
      if null $bootStrapMode then
        $NRTslot1Info := NRTmakeSlot1Info()
        $isOpPackageName: local := isCategoryPackageName $op
        $lisplibFunctionLocations := SUBLIS($pairlis,$functionLocations)
        $lisplibCategoriesExtended := SUBLIS($pairlis,$lisplibCategoriesExtended)
        -- see NRTsetVector4 for initial setting of $lisplibCategoriesExtended
        libFn := GETDATABASE(op','ABBREVIATION)
        $lookupFunction: local :=
            NRTgetLookupFunction($functorForm,CADAR $lisplibModemap,$NRTaddForm)
            --either lookupComplete (for forgetful guys) or lookupIncomplete
        $byteAddress :local := 0
        $byteVec :local := nil
        $NRTslot1PredicateList :=
          [simpBool x for x in $NRTslot1PredicateList]
        rwriteLispForm('loadTimeStuff,
          ['MAKEPROP,MKQ $op,''infovec,getInfovecCode()])
      $lisplibSlot1 := $NRTslot1Info --NIL or set by $NRTmakeSlot1
      $lisplibOperationAlist:= operationAlist
      $lisplibMissingFunctions:= $CheckVectorList
    lisplibWrite('"compilerInfo",
       removeZeroOne ['SETQ,'$CategoryFrame,
        ['put,['QUOTE,op'],'
         (QUOTE isFunctor),
          ['QUOTE,operationAlist],['addModemap,['QUOTE,op'],['
           QUOTE,parForm],['QUOTE,parSignature],true,['QUOTE,op'],
            ['put,['QUOTE,op' ],'(QUOTE mode),
             ['QUOTE,['Mapping,:parSignature]],'$CategoryFrame]]]], $libFile)
    if null argl then
      evalAndRwriteLispForm('NILADIC,
            ['MAKEPROP, ['QUOTE,op'], ['QUOTE,'NILADIC], true])
    [fun,['Mapping,:signature'],originale]
 
disallowNilAttribute x == 
  res := [y for y in x | car y and car y ^= "nil"]
--HACK to get rid of nil attibutes ---NOTE: nil is RENAMED to NIL

compFunctorBody(body,m,e,parForm) ==
  $bootStrapMode = true =>
    [bootStrapError($functorForm, _/EDITFILE),m,e]
  T:= compOrCroak(body,m,e)
  body is [op,:.] and MEMQ(op,'(add CAPSULE)) => T
  $NRTaddForm :=
    body is ["SubDomain",domainForm,predicate] => domainForm
    body
  T
 
reportOnFunctorCompilation() ==
  displayMissingFunctions()
  if $semanticErrorStack then sayBrightly '" "
  displaySemanticErrors()
  if $warningStack then sayBrightly '" "
  displayWarnings()
  $functorStats:= addStats($functorStats,$functionStats)
  [byteCount,elapsedSeconds] := $functorStats
  sayBrightly ['%l,:bright '"  Cumulative Statistics for Constructor",
    $op]
  timeString := normalizeStatAndStringify elapsedSeconds
  sayBrightly ['"      Time:",:bright timeString,'"seconds"]
  sayBrightly '" "
  'done
 
displayMissingFunctions() ==
  null $CheckVectorList => nil
  loc := nil
  exp := nil
  for [[op,sig,:.],:pred] in $CheckVectorList  | null pred repeat
    null member(op,$formalArgList) and
      getmode(op,$env) is ['Mapping,:.] =>
        loc := [[op,sig],:loc]
    exp := [[op,sig],:exp]
  if loc then
    sayBrightly ['%l,:bright '"  Missing Local Functions:"]
    for [op,sig] in loc for i in 1.. repeat
      sayBrightly ['"      [",i,'"]",:bright op,
        ": ",:formatUnabbreviatedSig sig]
  if exp then
    sayBrightly ['%l,:bright '"  Missing Exported Functions:"]
    for [op,sig] in exp for i in 1.. repeat
      sayBrightly ['"      [",i,'"]",:bright op,
        ": ",:formatUnabbreviatedSig sig]
 
--% domain view code
 
makeFunctorArgumentParameters(argl,sigl,target) ==
  $forceAdd: local:= true
  $ConditionalOperators: local := nil
  ("append"/[fn(a,augmentSig(s,findExtras(a,target)))
              for a in argl for s in sigl]) where
    findExtras(a,target) ==
      --  see if conditional information implies anything else
      --  in the signature of a
      target is ['Join,:l] => "union"/[findExtras(a,x) for x in l]
      target is ['CATEGORY,.,:l] => "union"/[findExtras1(a,x) for x in l] where
        findExtras1(a,x) ==
          x is ['AND,:l] => "union"/[findExtras1(a,y) for y in l]
          x is ['OR,:l] => "union"/[findExtras1(a,y) for y in l]
          x is ['IF,c,p,q] =>
            union(findExtrasP(a,c),
                  union(findExtras1(a,p),findExtras1(a,q))) where
              findExtrasP(a,x) ==
                x is ['AND,:l] => "union"/[findExtrasP(a,y) for y in l]
                x is ['OR,:l] => "union"/[findExtrasP(a,y) for y in l]
                x is ['has,=a,y] and y is ['SIGNATURE,:.] => [y]
                nil
        nil
    augmentSig(s,ss) ==
       -- if we find something extra, add it to the signature
      null ss => s
      for u in ss repeat
        $ConditionalOperators:=[CDR u,:$ConditionalOperators]
      s is ['Join,:sl] =>
        u:=ASSQ('CATEGORY,ss) =>
          SUBST([:u,:ss],u,s)
        ['Join,:sl,['CATEGORY,'package,:ss]]
      ['Join,s,['CATEGORY,'package,:ss]]
    fn(a,s) ==
      isCategoryForm(s,$CategoryFrame) =>
        s is ["Join",:catlist] => genDomainViewList0(a,rest s)
        [genDomainView(a,a,s,"getDomainView")]
      [a]
 
genDomainViewList0(id,catlist) ==
  l:= genDomainViewList(id,catlist,true)
  l
 
genDomainViewList(id,catlist,firsttime) ==
  null catlist => nil
  catlist is [y] and not isCategoryForm(y,$EmptyEnvironment) => nil
  [genDomainView(if firsttime then id else genDomainViewName(id,first catlist),
    id,first catlist,"getDomainView"),:genDomainViewList(id,rest catlist,nil)]
 
genDomainView(viewName,originalName,c,viewSelector) ==
  c is ['CATEGORY,.,:l] => genDomainOps(viewName,originalName,c)
  code:=
    c is ['SubsetCategory,c',.] => c'
    c
  $e:= augModemapsFromCategory(originalName,viewName,nil,c,$e)
  --$alternateViewList:= ((viewName,:code),:$alternateViewList)
  cd:= ['LET,viewName,[viewSelector,originalName,mkDomainConstructor code]]
  if null member(cd,$getDomainCode) then
          $getDomainCode:= [cd,:$getDomainCode]
  viewName
 
genDomainOps(viewName,dom,cat) ==
  oplist:= getOperationAlist(dom,dom,cat)
  siglist:= [sig for [sig,:.] in oplist]
  oplist:= substNames(dom,viewName,dom,oplist)
  cd:=
    ['LET,viewName,['mkOpVec,dom,['LIST,:
      [['LIST,MKQ op,['LIST,:[mkDomainConstructor mode for mode in sig]]]
        for [op,sig] in siglist]]]]
  $getDomainCode:= [cd,:$getDomainCode]
  for [opsig,cond,:.] in oplist for i in 0.. repeat
    if opsig in $ConditionalOperators then cond:=nil
    [op,sig]:=opsig
    $e:= addModemap(op,dom,sig,cond,['ELT,viewName,i],$e)
  viewName
 
mkOpVec(dom,siglist) ==
  dom:= getPrincipalView dom
  substargs:= [['$,:dom.0],:
    [[a,:x] for a in $FormalMapVariableList for x in rest dom.0]]
  oplist:= getOperationAlistFromLisplib opOf dom.0
  --new form is (<op> <signature> <slotNumber> <condition> <kind>)
  ops:= MAKE_-VEC (#siglist)
  for (opSig:= [op,sig]) in siglist for i in 0.. repeat
    u:= ASSQ(op,oplist)
    assoc(sig,u) is [.,n,.,'ELT] => ops.i := dom.n
    noplist:= SUBLIS(substargs,u)
 -- following variation on assoc needed for GENSYMS in Mutable domains
    AssocBarGensym(SUBST(dom.0,'$,sig),noplist) is [.,n,.,'ELT] =>
                   ops.i := dom.n
    ops.i := [Undef,[dom.0,i],:opSig]
  ops
 
genDomainViewName(a,category) ==
--+
  a
 
compDefWhereClause(['DEF,form,signature,specialCases,body],m,e) ==
-- form is lhs (f a1 ... an) of definition; body is rhs;
-- signature is (t0 t1 ... tn) where t0= target type, ti=type of ai, i > 0;
-- specialCases is (NIL l1 ... ln) where li is list of special cases
-- which can be given for each ti
 
-- removes declarative and assignment information from form and
-- signature, placing it in list L, replacing form by ("where",form',:L),
-- signature by a list of NILs (signifying declarations are in e)
  $sigAlist: local := nil
  $predAlist: local := nil
 
-- 1. create sigList= list of all signatures which have embedded
--    declarations moved into global variable $sigAlist
  sigList:=
    [transformType fetchType(a,x,e,form) for a in rest form for x in rest signature]
       where
        fetchType(a,x,e,form) ==
          x => x
          getmode(a,e) or userError concat(
            '"There is no mode for argument",a,'"of function",first form)
        transformType x ==
          atom x => x
          x is [":",R,Rtype] =>
            ($sigAlist:= [[R,:transformType Rtype],:$sigAlist]; x)
          x is ['Record,:.] => x --RDJ 8/83
          [first x,:[transformType y for y in rest x]]
 
-- 2. replace each argument of the form (|| x p) by x, recording
--    the given predicate in global variable $predAlist
  argList:=
    [removeSuchthat a for a in rest form] where
      removeSuchthat x ==
        x is ["|",y,p] => ($predAlist:= [[y,:p],:$predAlist]; y)
        x
 
-- 3. obtain a list of parameter identifiers (x1 .. xn) ordered so that
--       the type of xi is independent of xj if i < j
  varList:=
    orderByDependency(ASSOCLEFT argDepAlist,ASSOCRIGHT argDepAlist) where
      argDepAlist:=
        [[x,:dependencies] for [x,:y] in argSigAlist] where
          dependencies() ==
            setUnion(listOfIdentifiersIn y,
              delete(x,listOfIdentifiersIn LASSOC(x,$predAlist)))
          argSigAlist:= [:$sigAlist,:pairList(argList,sigList)]
 
-- 4. construct a WhereList which declares and/or defines the xi's in
--    the order constructed in step 3
  (whereList:= [addSuchthat(x,[":",x,LASSOC(x,argSigAlist)]) for x in varList])
     where addSuchthat(x,y) == (p:= LASSOC(x,$predAlist) => ["|",y,p]; y)
 
-- 5. compile new ('DEF,("where",form',:WhereList),:.) where
--    all argument parameters of form' are bound/declared in WhereList
  comp(form',m,e) where
    form':=
      ["where",defform,:whereList] where
        defform:=
          ['DEF,form'',signature',specialCases,body] where
            form'':= [first form,:argList]
            signature':= [first signature,:[nil for x in rest signature]]
 
orderByDependency(vl,dl) ==
  -- vl is list of variables, dl is list of dependency-lists
  selfDependents:= [v for v in vl for d in dl | MEMQ(v,d)]
  for v in vl for d in dl | MEMQ(v,d) repeat
    (SAY(v," depends on itself"); fatalError:= true)
  fatalError => userError '"Parameter specification error"
  until (null vl) repeat
    newl:=
      [v for v in vl for d in dl | null setIntersection(d,vl)] or return nil
    orderedVarList:= [:newl,:orderedVarList]
    vl':= setDifference(vl,newl)
    dl':= [setDifference(d,newl) for x in vl for d in dl | member(x,vl')]
    vl:= vl'
    dl:= dl'
  REMDUP NREVERSE orderedVarList --ordered so ith is indep. of jth if i < j

compDefineCapsuleFunction(df is ['DEF,form,signature,specialCases,body],
  m,oldE,$prefix,$formalArgList) ==
    [lineNumber,:specialCases] := specialCases
    e := oldE
    --1. bind global variables
    $form: local := nil
    $op: local := nil
    $functionStats: local:= [0,0]
    $argumentConditionList: local := nil
    $finalEnv: local := nil
             --used by ReplaceExitEtc to get a common environment
    $initCapsuleErrorCount: local:= #$semanticErrorStack
    $insideCapsuleFunctionIfTrue: local:= true
    $CapsuleModemapFrame: local:= e
    $CapsuleDomainsInScope: local:= get("$DomainsInScope","special",e)
    $insideExpressionIfTrue: local:= true
    $returnMode:= m
    [$op,:argl]:= form
    $form:= [$op,:argl]
    argl:= stripOffArgumentConditions argl
    $formalArgList:= [:argl,:$formalArgList]

    --let target and local signatures help determine modes of arguments
    argModeList:=
      identSig:= hasSigInTargetCategory(argl,form,first signature,e) =>
        (e:= checkAndDeclare(argl,form,identSig,e); rest identSig)
      [getArgumentModeOrMoan(a,form,e) for a in argl]
    argModeList:= stripOffSubdomainConditions(argModeList,argl)
    signature':= [first signature,:argModeList]
    if null identSig then  --make $op a local function
      oldE := put($op,'mode,['Mapping,:signature'],oldE)

    --obtain target type if not given
    if null first signature' then signature':=
      identSig => identSig
      getSignature($op,rest signature',e) or return nil

    --replace ##1,.. in signature by arguments
--    pp signature'
    signature':= SUBLISLIS(argl,$FormalFunctionParameterList,signature')
--  pp '"------after----"
--  pp signature'
    e:= giveFormalParametersValues(argl,e)

    $signatureOfForm:= signature' --this global is bound in compCapsuleItems
    $functionLocations := [[[$op,$signatureOfForm],:lineNumber],
      :$functionLocations]
    e:= addDomain(first signature',e)
    e:= compArgumentConditions e

    if $profileCompiler then
      for x in argl for t in rest signature' repeat profileRecord('arguments,x,t)


    --4. introduce needed domains into extendedEnv
    for domain in signature' repeat e:= addDomain(domain,e)

    --6. compile body in environment with extended environment
    rettype:= resolve(signature'.target,$returnMode)

    localOrExported :=
      null member($op,$formalArgList) and
        getmode($op,e) is ['Mapping,:.] => 'local
      'exported

    --6a skip if compiling only certain items but not this one
    -- could be moved closer to the top
    formattedSig := formatUnabbreviated ['Mapping,:signature']
    $compileOnlyCertainItems and _
      not member($op, $compileOnlyCertainItems) =>
        sayBrightly ['"   skipping ", localOrExported,:bright $op]
        [nil,['Mapping,:signature'],oldE]
    sayBrightly ['"   compiling ",localOrExported,
      :bright $op,'": ",:formattedSig]

    T := CATCH('compCapsuleBody, compOrCroak(body,rettype,e))
           or ["",rettype,e]
--+
    NRTassignCapsuleFunctionSlot($op,signature')
    if $newCompCompare=true then
         SAY '"The old compiler generates:"
         prTriple T
--  A THROW to the above CATCH occurs if too many semantic errors occur
--  see stackSemanticError
    catchTag:= MKQ GENSYM()
    fun:=
      body':= replaceExitEtc(T.expr,catchTag,"TAGGEDreturn",$returnMode)
      body':= addArgumentConditions(body',$op)
      finalBody:= ["CATCH",catchTag,body']
      compileCases([$op,["LAM",[:argl,'_$],finalBody]],oldE)
    $functorStats:= addStats($functorStats,$functionStats)


--  7. give operator a 'value property
    val:= [fun,signature',e]
    [fun,['Mapping,:signature'],oldE] -- oldE:= put($op,'value,removeEnv val,e)

getSignatureFromMode(form,e) ==
  getmode(opOf form,e) is ['Mapping,:signature] =>
    #form^=#signature => stackAndThrow ["Wrong number of arguments: ",form]
    EQSUBSTLIST(rest form,take(#rest form,$FormalMapVariableList),signature)
 
hasSigInTargetCategory(argl,form,opsig,e) ==
  mList:= [getArgumentMode(x,e) for x in argl]
    --each element is a declared mode for the variable or nil if none exists
  potentialSigList:=
    REMDUP
      [sig
        for [[opName,sig,:.],:.] in $domainShell.(1) |
          fn(opName,sig,opsig,mList,form)] where
            fn(opName,sig,opsig,mList,form) ==
              opName=$op and #sig=#form and (null opsig or opsig=first sig) and
                (and/[compareMode2Arg(x,m) for x in mList for m in rest sig])
  c:= #potentialSigList
  1=c => first potentialSigList
    --accept only those signatures op right length which match declared modes
  0=c => (#(sig:= getSignatureFromMode(form,e))=#form => sig; nil)
  1<c =>
    sig:= first potentialSigList
    stackWarning ["signature of lhs not unique:",:bright sig,"chosen"]
    sig
  nil --this branch will force all arguments to be declared
 
compareMode2Arg(x,m) == null x or modeEqual(x,m)
 
getArgumentModeOrMoan(x,form,e) ==
  getArgumentMode(x,e) or
    stackSemanticError(["argument ",x," of ",form," is not declared"],nil)
 
getArgumentMode(x,e) ==
  STRINGP x => x
  m:= get(x,'mode,e) => m
 
checkAndDeclare(argl,form,sig,e) ==
 
-- arguments with declared types must agree with those in sig;
-- those that don't get declarations put into e
  for a in argl for m in rest sig repeat
    m1:= getArgumentMode(a,e) =>
      ^modeEqual(m1,m) =>
        stack:= ["   ",:bright a,'"must have type ",m,
          '" not ",m1,'%l,:stack]
    e:= put(a,'mode,m,e)
  if stack then
    sayBrightly ['"   Parameters of ",:bright first form,
      '" are of wrong type:",'%l,:stack]
  e
 
getSignature(op,argModeList,$e) ==
  1=#
    (sigl:=
      REMDUP
        [sig
          for [[dc,:sig],[pred,:.]] in (mmList:= get(op,'modemap,$e)) | dc='_$
            and rest sig=argModeList and knownInfo pred]) => first sigl
  null sigl =>
    (u:= getmode(op,$e)) is ['Mapping,:sig] => sig
    SAY '"************* USER ERROR **********"
    SAY("available signatures for ",op,": ")
    if null mmList
       then SAY "    NONE"
       else for [[dc,:sig],:.] in mmList repeat printSignature("     ",op,sig)
    printSignature("NEED ",op,["?",:argModeList])
    nil
  for u in sigl repeat
    for v in sigl | not (u=v) repeat
      if SourceLevelSubsume(u,v) then sigl:= delete(v,sigl)
              --before we complain about duplicate signatures, we should
              --check that we do not have for example, a partial - as
              --well as a total one.  SourceLevelSubsume (from CATEGORY BOOT)
              --should do this
  1=#sigl => first sigl
  stackSemanticError(["duplicate signatures for ",op,": ",argModeList],nil)
 
--% ARGUMENT CONDITION CODE
 
stripOffArgumentConditions argl ==
  [f for x in argl for i in 1..] where
    f() ==
      x is ["|",arg,condition] =>
        condition:= SUBST('_#1,arg,condition)
        -- in case conditions are given in terms of argument names, replace
        $argumentConditionList:= [[i,arg,condition],:$argumentConditionList]
        arg
      x
 
stripOffSubdomainConditions(margl,argl) ==
  [f for x in margl for arg in argl for i in 1..] where
    f ==
      x is ['SubDomain,marg,condition] =>
        pair:= assoc(i,$argumentConditionList) =>
          (RPLAC(CADR pair,MKPF([condition,CADR pair],'AND)); marg)
        $argumentConditionList:= [[i,arg,condition],:$argumentConditionList]
        marg
      x
 
compArgumentConditions e ==
  $argumentConditionList:=
    [f for [n,a,x] in $argumentConditionList] where
      f ==
        y:= SUBST(a,'_#1,x)
        T := [.,.,e]:= compOrCroak(y,$Boolean,e)
        [n,x,T.expr]
  e
 
addArgumentConditions($body,$functionName) ==
  $argumentConditionList =>
               --$body is only used in this function
    fn $argumentConditionList where
      fn clist ==
        clist is [[n,untypedCondition,typedCondition],:.] =>
          ['COND,[typedCondition,fn rest clist],
            [$true,["argumentDataError",n,
              MKQ untypedCondition,MKQ $functionName]]]
        null clist => $body
        systemErrorHere '"addArgumentConditions"
  $body
 
putInLocalDomainReferences (def := [opName,[lam,varl,body]]) ==
  $elt: local := ($QuickCode => 'QREFELT; 'ELT)
--+
  NRTputInTail CDDADR def
  def
 
 
compileCases(x,$e) == -- $e is referenced in compile
  $specialCaseKeyList: local := nil
  not ($insideFunctorIfTrue=true) => compile x
  specialCaseAssoc:=
    [y for y in getSpecialCaseAssoc() | not get(first y,"specialCase",$e) and
          ([R,R']:= y) and isEltArgumentIn(FindNamesFor(R,R'),x)] where
        FindNamesFor(R,R') ==
          [R,:
            [v
              for ['LET,v,u,:.] in $getDomainCode | CADR u=R and
                eval substitute(R',R,u)]]
        isEltArgumentIn(Rlist,x) ==
          atom x => nil
          x is ['ELT,R,.] => MEMQ(R,Rlist) or isEltArgumentIn(Rlist,rest x)
          x is ["QREFELT",R,.] => MEMQ(R,Rlist) or isEltArgumentIn(Rlist,rest x)
          isEltArgumentIn(Rlist,first x) or isEltArgumentIn(Rlist,rest x)
  null specialCaseAssoc => compile x
  listOfDomains:= ASSOCLEFT specialCaseAssoc
  listOfAllCases:= outerProduct ASSOCRIGHT specialCaseAssoc
  cl:=
    [u for l in listOfAllCases] where
      u() ==
        $specialCaseKeyList:= [[D,:C] for D in listOfDomains for C in l]
        [MKPF([["EQUAL",D,C] for D in listOfDomains for C in l],"AND"),
          compile COPY x]
  $specialCaseKeyList:= nil
  ["COND",:cl,[$true,compile x]]
 
getSpecialCaseAssoc() ==
  [[R,:l] for R in rest $functorForm
    for l in rest $functorSpecialCases | l]
 
compile u ==
  [op,lamExpr] := u
  if $suffix then
    $suffix:= $suffix+1
    op':=
      opexport:=nil
      opmodes:=
        [sel
          for [[DC,:sig],[.,sel]] in get(op,'modemap,$e) |
            DC='_$ and (opexport:=true) and
             (and/[modeEqual(x,y) for x in sig for y in $signatureOfForm])]
      isLocalFunction op =>
        if opexport then userError ['%b,op,'%d,'" is local and exported"]
        INTERN STRCONC(encodeItem $prefix,'";",encodeItem op) where
          isLocalFunction op ==
            null member(op,$formalArgList) and
              getmode(op,$e) is ['Mapping,:.]
      isPackageFunction() and KAR $functorForm^="CategoryDefaults" =>
        if null opmodes then userError ['"no modemap for ",op]
        opmodes is [['PAC,.,name]] => name
        encodeFunctionName(op,$functorForm,$signatureOfForm,";",$suffix)
      encodeFunctionName(op,$functorForm,$signatureOfForm,";",$suffix)
    u:= [op',lamExpr]
  -- If just updating certain functions, check for previous existence.
  -- Deduce old sequence number and use it (items have been skipped).
  if $LISPLIB and $compileOnlyCertainItems then
    parts := splitEncodedFunctionName(u.0, ";")
--  Next line JHD/SMWATT 7/17/86 to deal with inner functions
    parts='inner => $savableItems:=[u.0,:$savableItems]
    unew  := nil
    for [s,t] in $splitUpItemsAlreadyThere repeat
       if parts.0=s.0 and parts.1=s.1 and parts.2=s.2 then unew := t
    null unew =>
      sayBrightly ['"   Error: Item did not previously exist"]
      sayBrightly ['"   Item not saved: ", :bright u.0]
      sayBrightly ['"   What's there is: ", $lisplibItemsAlreadyThere]
      nil
    sayBrightly ['"   Renaming ", u.0, '" as ", unew]
    u := [unew, :rest u]
    $savableItems := [unew, :$saveableItems] -- tested by embedded RWRITE
  optimizedBody:= optimizeFunctionDef u
  stuffToCompile:=
    if null $insideCapsuleFunctionIfTrue
       then optimizedBody
       else putInLocalDomainReferences optimizedBody
  $doNotCompileJustPrint=true => (PRETTYPRINT stuffToCompile; op')
  $macroIfTrue => constructMacro stuffToCompile
  result:= spadCompileOrSetq stuffToCompile
  functionStats:=[0,elapsedTime()]
  $functionStats:= addStats($functionStats,functionStats)
  printStats functionStats
  result
 
spadCompileOrSetq (form is [nam,[lam,vl,body]]) ==
        --bizarre hack to take account of the existence of "known" functions
        --good for performance (LISPLLIB size, BPI size, NILSEC)
  CONTAINED("",body) => sayBrightly ['"  ",:bright nam,'" not compiled"]
  if vl is [:vl',E] and body is [nam',: =vl'] then
      LAM_,EVALANDFILEACTQ ['PUT,MKQ nam,MKQ 'SPADreplace,MKQ nam']
      sayBrightly ['"     ",:bright nam,'"is replaced by",:bright nam']
  else if (ATOM body or and/[ATOM x for x in body])
         and vl is [:vl',E] and not CONTAINED(E,body) then
           macform := ['XLAM,vl',body]
           LAM_,EVALANDFILEACTQ ['PUT,MKQ nam,MKQ 'SPADreplace,MKQ macform]
           sayBrightly ['"     ",:bright nam,'"is replaced by",:bright body]
  $insideCapsuleFunctionIfTrue => first COMP LIST form
  compileConstructor form
 
compileConstructor form ==
  u:= compileConstructor1 form
  clearClams()                  --clear all CLAMmed functions
  u
 
compileConstructor1 (form:=[fn,[key,vl,:bodyl]]) ==
-- fn is the name of some category/domain/package constructor;
-- we will cache all of its values on $ConstructorCache with reference
-- counts
  $clamList: local := nil
  lambdaOrSlam :=
    GETDATABASE(fn,'CONSTRUCTORKIND) = 'category => 'SPADSLAM
    $mutableDomain => 'LAMBDA
    $clamList:=
      [[fn,"$ConstructorCache",'domainEqualList,'count],:$clamList]
    'LAMBDA
  compForm:= LIST [fn,[lambdaOrSlam,vl,:bodyl]]
  if GETDATABASE(fn,'CONSTRUCTORKIND) = 'category
      then u:= compAndDefine compForm
      else u:=COMP compForm
  clearConstructorCache fn      --clear cache for constructor
  first u
 
constructMacro (form is [nam,[lam,vl,body]]) ==
  ^(and/[atom x for x in vl]) =>
    stackSemanticError(["illegal parameters for macro: ",vl],nil)
  ["XLAM",vl':= [x for x in vl | IDENTP x],body]
 
listInitialSegment(u,v) ==
  null u => true
  null v => nil
  first u=first v and listInitialSegment(rest u,rest v)
  --returns true iff u.i=v.i for i in 1..(#u)-1
 
modemap2Signature [[.,:sig],:.] == sig
 
uncons x ==
  atom x => x
  x is ["CONS",a,b] => [a,:uncons b]
 
--% CAPSULE
 
bootStrapError(functorForm,sourceFile) ==
  ['COND, _
    ['$bootStrapMode, _
        ['VECTOR,mkDomainConstructor functorForm,nil,nil,nil,nil,nil]],
    [''T, ['systemError,['LIST,''%b,MKQ CAR functorForm,''%d,'"from", _
      ''%b,MKQ namestring sourceFile,''%d,'"needs to be compiled"]]]]
 
compAdd(['add,$addForm,capsule],m,e) ==
  $bootStrapMode = true =>
    if $addForm is ['Tuple,:.] then code := nil
       else [code,m,e]:= comp($addForm,m,e)
    [['COND, _
       ['$bootStrapMode, _
           code],_
       [''T, ['systemError,['LIST,''%b,MKQ CAR $functorForm,''%d,'"from", _
         ''%b,MKQ namestring _/EDITFILE,''%d,'"needs to be compiled"]]]],m,e]
  $addFormLhs: local:= $addForm
  if $addForm is ["SubDomain",domainForm,predicate] then
    $packagesUsed := [domainForm,:$packagesUsed]
--+
    $NRTaddForm := domainForm
    NRTgetLocalIndex domainForm
    --need to generate slot for add form since all $ go-get
    --  slots will need to access it
    [$addForm,.,e]:= compSubDomain1(domainForm,predicate,m,e)
  else
    $packagesUsed :=
      $addForm is ['Tuple,:u] => [:u,:$packagesUsed]
      [$addForm,:$packagesUsed]
--+
    $NRTaddForm := $addForm
    [$addForm,.,e]:=
      $addForm is ['Tuple,:.] =>
        $NRTaddForm := ['Tuple,:[NRTgetLocalIndex x for x in rest $addForm]]
        compOrCroak(compTuple2Record $addForm,$EmptyMode,e)
      compOrCroak($addForm,$EmptyMode,e)
  compCapsule(capsule,m,e)
 
compTuple2Record u == ['Record,:[[":",i,x] for i in 1.. for x in rest u]]
 
compCapsule(['CAPSULE,:itemList],m,e) ==
  $bootStrapMode = true =>
    [bootStrapError($functorForm, _/EDITFILE),m,e]
  $insideExpressionIfTrue: local:= false
  compCapsuleInner(itemList,m,addDomain('_$,e))
 
compSubDomain(["SubDomain",domainForm,predicate],m,e) ==
  $addFormLhs: local:= domainForm
  $addForm: local := nil
  $NRTaddForm := domainForm
  [$addForm,.,e]:= compSubDomain1(domainForm,predicate,m,e)
--+
  compCapsule(['CAPSULE],m,e)
 
compSubDomain1(domainForm,predicate,m,e) ==
  [.,.,e]:=
    compMakeDeclaration([":","#1",domainForm],$EmptyMode,addDomain(domainForm,e))
  u:=
    compOrCroak(predicate,$Boolean,e) or
      stackSemanticError(["predicate: ",predicate,
        " cannot be interpreted with #1: ",domainForm],nil)
  prefixPredicate:= lispize u.expr
  $lisplibSuperDomain:=
    [domainForm,predicate]
  evalAndRwriteLispForm('evalOnLoad2,
    ['SETQ,'$CategoryFrame,['put,op':= ['QUOTE,$op],'
     (QUOTE SuperDomain),dF':= ['QUOTE,domainForm],['put,dF','(QUOTE SubDomain),[
       'CONS,['QUOTE,[$op,:prefixPredicate]],['DELASC,op',['get,dF','
         (QUOTE SubDomain),'$CategoryFrame]]],'$CategoryFrame]]])
  [domainForm,m,e]
 
compCapsuleInner(itemList,m,e) ==
  e:= addInformation(m,e)
           --puts a new 'special' property of $Information
  data:= ["PROGN",:itemList]
      --RPLACd by compCapsuleItems and Friends
  e:= compCapsuleItems(itemList,nil,e)
  localParList:= $functorLocalParameters
  if $addForm then data:= ['add,$addForm,data]
  code:=
    $insideCategoryIfTrue and not $insideCategoryPackageIfTrue => data
    processFunctorOrPackage($form,$signature,data,localParList,m,e)
  [MKPF([:$getDomainCode,code],"PROGN"),m,e]
 
--% PROCESS FUNCTOR CODE
 
processFunctor(form,signature,data,localParList,e) ==
  form is ["CategoryDefaults"] =>
    error "CategoryDefaults is a reserved name"
  buildFunctor(form,signature,data,localParList,e)
 
compCapsuleItems(itemlist,$predl,$e) ==
  $TOP__LEVEL: local
  $signatureOfForm: local := nil
  $suffix: local:= 0
  for item in itemlist repeat $e:= compSingleCapsuleItem(item,$predl,$e)
  $e
 
compSingleCapsuleItem(item,$predl,$e) ==
  doIt(macroExpandInPlace(item,$e),$predl)
  $e
 
doIt(item,$predl) ==
  $GENNO: local:= 0
  item is ['SEQ,:l,['exit,1,x]] =>
    RPLACA(item,"PROGN")
    RPLACA(LASTNODE item,x)
    for it1 in rest item repeat $e:= compSingleCapsuleItem(it1,$predl,$e)
        --This will RPLAC as appropriate
  isDomainForm(item,$e) =>
     -- convert naked top level domains to import
    u:= ['import, [first item,:rest item]]
    stackWarning ["Use: import ", [first item,:rest item]]
    RPLACA(item,first u)
    RPLACD(item,rest u)
    doIt(item,$predl)
  item is ['LET,lhs,rhs,:.] =>
    not (compOrCroak(item,$EmptyMode,$e) is [code,.,$e]) =>
      stackSemanticError(["cannot compile assigned value to",:bright lhs],nil)
    not (code is ['LET,lhs',rhs',:.] and atom lhs') =>
      code is ["PROGN",:.] =>
         stackSemanticError(["multiple assignment ",item," not allowed"],nil)
      RPLACA(item,first code)
      RPLACD(item,rest code)
    lhs:= lhs'
    if not member(KAR rhs,$NonMentionableDomainNames) and
      not MEMQ(lhs, $functorLocalParameters) then
         $functorLocalParameters:= [:$functorLocalParameters,lhs]
    if code is ['LET,.,rhs',:.] and isDomainForm(rhs',$e) then
      if isFunctor rhs' then
        $functorsUsed:= insert(opOf rhs',$functorsUsed)
        $packagesUsed:= insert([opOf rhs'],$packagesUsed)
      if lhs="Rep" then
        $Representation:= (get("Rep",'value,$e)).(0)
           --$Representation bound by compDefineFunctor, used in compNoStacking
--+
--+
      $LocalDomainAlist:= --see genDeltaEntry
        [[lhs,:SUBLIS($LocalDomainAlist,get(lhs,'value,$e).0)],:$LocalDomainAlist]
--+
    code is ['LET,:.] =>
      RPLACA(item,($QuickCode => 'QSETREFV;'SETELT))
      rhsCode:=
       rhs'
      RPLACD(item,['$,NRTgetLocalIndexClear lhs,rhsCode])
    RPLACA(item,first code)
    RPLACD(item,rest code)
  item is [":",a,t] => [.,.,$e]:= compOrCroak(item,$EmptyMode,$e)
  item is ['import,:doms] =>
     for dom in doms repeat
       sayBrightly ['"   importing ",:formatUnabbreviated dom]
     [.,.,$e] := compOrCroak(item,$EmptyMode,$e)
     RPLACA(item,'PROGN)
     RPLACD(item,NIL) -- creates a no-op
  item is ["IF",:.] => doItIf(item,$predl,$e)
  item is ["where",b,:l] => compOrCroak(item,$EmptyMode,$e)
  item is ["MDEF",:.] => [.,.,$e]:= compOrCroak(item,$EmptyMode,$e)
  item is ['DEF,[op,:.],:.] =>
    body:= isMacro(item,$e) => $e:= put(op,'macro,body,$e)
    [.,.,$e]:= t:= compOrCroak(item,$EmptyMode,$e)
    RPLACA(item,"CodeDefine")
        --Note that DescendCode, in CodeDefine, is looking for this
    RPLACD(CADR item,[$signatureOfForm])
      --This is how the signature is updated for buildFunctor to recognise
--+
    functionPart:= ['dispatchFunction,t.expr]
    RPLACA(CDDR item,functionPart)
    RPLACD(CDDR item,nil)
  u:= compOrCroak(item,$EmptyMode,$e) =>
    ([code,.,$e]:= u; RPLACA(item,first code); RPLACD(item,rest code))
  true => cannotDo()
 
isMacro(x,e) ==
  x is ['DEF,[op,:args],signature,specialCases,body] and
    null get(op,'modemap,e) and null args and null get(op,'mode,e)
      and signature is [nil] => body
 
doItIf(item is [.,p,x,y],$predl,$e) ==
  olde:= $e
  [p',.,$e]:= comp(p,$Boolean,$e) or userError ['"not a Boolean:",p]
  oldFLP:=$functorLocalParameters
  if x^="noBranch" then
    compSingleCapsuleItem(x,$predl,getSuccessEnvironment(p,$e))
    x':=localExtras(oldFLP)
          where localExtras(oldFLP) ==
            EQ(oldFLP,$functorLocalParameters) => NIL
            flp1:=$functorLocalParameters
            oldFLP':=oldFLP
            n:=0
            while oldFLP' repeat
              oldFLP':=CDR oldFLP'
              flp1:=CDR flp1
              n:=n+1
            -- Now we have to add code to compile all the elements
            -- of functorLocalParameters that were added during the
            -- conditional compilation
            nils:=ans:=[]
            for u in flp1 repeat -- is =u form always an ATOM?
              if ATOM u or (or/[v is [.,=u,:.] for v in $getDomainCode])
                then
                  nils:=[u,:nils]
                else
                  gv := GENSYM()
                  ans:=[['LET,gv,u],:ans]
                  nils:=[gv,:nils]
              n:=n+1
            $functorLocalParameters:=[:oldFLP,:NREVERSE nils]
            NREVERSE ans
  oldFLP:=$functorLocalParameters
  if y^="noBranch" then
    compSingleCapsuleItem(y,$predl,getInverseEnvironment(p,olde))
    y':=localExtras(oldFLP)
  RPLACA(item,"COND")
  RPLACD(item,[[p',x,:x'],['(QUOTE T),y,:y']])
 
--compSingleCapsuleIf(x,predl,e,$functorLocalParameters) ==
--  compSingleCapsuleItem(x,predl,e)
 
--% CATEGORY AND DOMAIN FUNCTIONS
compContained(["CONTAINED",a,b],m,e) ==
  [a,ma,e]:= comp(a,$EmptyMode,e) or return nil
  [b,mb,e]:= comp(b,$EmptyMode,e) or return nil
  isCategoryForm(ma,e) and isCategoryForm(mb,e) =>
    (T:= [["CONTAINED",a,b],$Boolean,e]; convert(T,m))
  nil
 
compJoin(["Join",:argl],m,e) ==
  catList:= [(compForMode(x,$Category,e) or return 'failed).expr for x in argl]
  catList='failed => stackSemanticError(["cannot form Join of: ",argl],nil)
  catList':=
    [extract for x in catList] where
      extract() ==
        isCategoryForm(x,e) =>
          parameters:=
            union("append"/[getParms(y,e) for y in rest x],parameters)
              where getParms(y,e) ==
                atom y =>
                  isDomainForm(y,e) => LIST y
                  nil
                y is ['LENGTH,y'] => [y,y']
                LIST y
          x
        x is ["DomainSubstitutionMacro",pl,body] =>
          (parameters:= union(pl,parameters); body)
        x is ["mkCategory",:.] => x
        atom x and getmode(x,e)=$Category => x
        stackSemanticError(["invalid argument to Join: ",x],nil)
        x
  T:= [wrapDomainSub(parameters,["Join",:catList']),$Category,e]
  convert(T,m)
 
compForMode(x,m,e) ==
  $compForModeIfTrue: local:= true
  comp(x,m,e)
 
compMakeCategoryObject(c,$e) ==
  not isCategoryForm(c,$e) => nil
  u:= mkEvalableCategoryForm c => [eval u,$Category,$e]
  nil
 
quotifyCategoryArgument x == MKQ x
 
makeCategoryForm(c,e) ==
  not isCategoryForm(c,e) => nil
  [x,m,e]:= compOrCroak(c,$EmptyMode,e)
  [x,e]
 
compCategory(x,m,e) ==
  $TOP__LEVEL: local:= true
  (m:= resolve(m,["Category"]))=["Category"] and x is ['CATEGORY,
    domainOrPackage,:l] =>
      $sigList: local := nil
      $atList: local := nil
      $sigList:= $atList:= nil
      for x in l repeat compCategoryItem(x,nil)
      rep:= mkExplicitCategoryFunction(domainOrPackage,$sigList,$atList)
    --if inside compDefineCategory, provide for category argument substitution
      [rep,m,e]
  systemErrorHere '"compCategory"
 
mkExplicitCategoryFunction(domainOrPackage,sigList,atList) ==
  body:=
    ["mkCategory",MKQ domainOrPackage,['LIST,:REVERSE sigList],['LIST,:
      REVERSE atList],MKQ domList,nil] where
        domList() ==
          ("union"/[fn sig for ["QUOTE",[[.,sig,:.],:.]] in sigList]) where
            fn sig == [D for D in sig | mustInstantiate D]
  parameters:=
    REMDUP
      ("append"/
        [[x for x in sig | IDENTP x and x^='_$]
          for ["QUOTE",[[.,sig,:.],:.]] in sigList])
  wrapDomainSub(parameters,body)
 
wrapDomainSub(parameters,x) ==
   ["DomainSubstitutionMacro",parameters,x]
 
mustInstantiate D ==
  D is [fn,:.] and ^(MEMQ(fn,$DummyFunctorNames) or GETL(fn,"makeFunctionList"))
 
DomainSubstitutionFunction(parameters,body) ==
  --see definition of DomainSubstitutionMacro in SPAD LISP
  if parameters then
    (body:= Subst(parameters,body)) where
      Subst(parameters,body) ==
        ATOM body =>
          MEMQ(body,parameters) => MKQ body
          body
        member(body,parameters) =>
          g:=GENSYM()
          $extraParms:=PUSH([g,:body],$extraParms)
           --Used in SetVector12 to generate a substitution list
           --bound in buildFunctor
           --For categories, bound and used in compDefineCategory
          MKQ g
        first body="QUOTE" => body
        PAIRP $definition and
            isFunctor first body and
              first body ^= first $definition
          =>  ['QUOTE,optimize body]
        [Subst(parameters,u) for u in body]
  not (body is ["Join",:.]) => body
  atom $definition => body
  null rest $definition => body
           --should not bother if it will only be called once
  name:= INTERN STRCONC(KAR $definition,";CAT")
  SETANDFILE(name,nil)
  body:= ["COND",[name],['(QUOTE T),['SETQ,name,body]]]
  body
 
compCategoryItem(x,predl) ==
  x is nil => nil
  --1. if x is a conditional expression, recurse; otherwise, form the predicate
  x is ["COND",[p,e]] =>
    predl':= [p,:predl]
    e is ["PROGN",:l] => for y in l repeat compCategoryItem(y,predl')
    compCategoryItem(e,predl')
  x is ["IF",a,b,c] =>
    predl':= [a,:predl]
    if b^="noBranch" then
      b is ["PROGN",:l] => for y in l repeat compCategoryItem(y,predl')
      compCategoryItem(b,predl')
    c="noBranch" => nil
    predl':= [["not",a],:predl]
    c is ["PROGN",:l] => for y in l repeat compCategoryItem(y,predl')
    compCategoryItem(c,predl')
  pred:= (predl => MKPF(predl,"AND"); true)
 
  --2. if attribute, push it and return
  x is ["ATTRIBUTE",y] => PUSH(MKQ [y,pred],$atList)
 
  --3. it may be a list, with PROGN as the CAR, and some information as the CDR
  x is ["PROGN",:l] => for u in l repeat compCategoryItem(u,predl)
 
-- 4. otherwise, x gives a signature for a
--    single operator name or a list of names; if a list of names,
--    recurse
  ["SIGNATURE",op,:sig]:= x
  null atom op =>
    for y in op repeat compCategoryItem(["SIGNATURE",y,:sig],predl)
 
  --4. branch on a single type or a signature %with source and target
  PUSH(MKQ [rest x,pred],$sigList)
 







