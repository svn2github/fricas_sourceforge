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

)package "BOOT"

-- note domainObjects are now (dispatchVector hashCode . domainVector)
-- lazy oldAxiomDomainObjects are (dispatchVector hashCode  (Call form) . backptr),
-- pre oldAxiomCategory is (dispatchVector . (cat form))
-- oldAxiomCategory objects are (dispatchVector . ( (cat form)  hash defaultpack parentlist))

hashCode? x == INTEGERP x

$domainTypeTokens := ['lazyOldAxiomDomain, 'oldAxiomDomain, 'oldAxiomPreCategory,
           'oldAxiomCategory, 0]

-- The name game.
-- The compiler produces names that are of the form:
-- a) cons(0, <string>)
-- b) cons(1, type-name, arg-names...)
-- c) cons(2, arg-names...)
-- d) cons(3, value)
-- NB: (c) is for tuple-ish constructors,
--     and (d) is for dependent types.

DNameStringID := 0
DNameApplyID  := 1
DNameTupleID  := 2
DNameOtherID  := 3

DNameToSExpr1 dname ==
  NULL dname => error "unexpected domain name"
  CAR dname = DNameStringID =>
    INTERN(CompStrToString CDR dname)
  name0 := DNameToSExpr1 CAR CDR dname
  args  := CDR CDR dname
  name0 = '_-_> =>
    froms := CAR args
    froms := MAPCAR(function DNameToSExpr, CDR froms)
    ret   := CAR CDR args -- a tuple
    ret   := DNameToSExpr CAR CDR ret -- contents
    CONS('Mapping, CONS(ret, froms))
  name0 = 'Union or name0 = 'Record =>
    sxs := MAPCAR(function DNameToSExpr, CDR CAR args)
    CONS(name0, sxs)
  name0 = 'Enumeration =>
    CONS(name0, MAPCAR(function DNameFixEnum, CDR CAR args))
  CONS(name0, MAPCAR(function DNameToSExpr, args))

DNameToSExpr dname ==
  CAR dname = DNameOtherID  =>
        CDR dname
  sx := DNameToSExpr1 dname
  CONSP sx => sx
  LIST sx

DNameFixEnum arg == CompStrToString CDR arg

SExprToDName(sexpr, cosigVal) ==
  -- is it a non-type valued object?
  NOT cosigVal => [DNameOtherID, :sexpr]
  if CAR sexpr = '_: then sexpr := CAR CDR CDR sexpr
  CAR sexpr = 'Mapping =>
    args := [ SExprToDName(sx, 'T) for sx in CDR sexpr]
    [DNameApplyID,
         [DNameStringID,: StringToCompStr '"->"],
              [DNameTupleID, : CDR args],
                 [DNameTupleID, CAR args]]
  name0 :=   [DNameStringID, : StringToCompStr SYMBOL_-NAME CAR sexpr]
  CAR sexpr = 'Union or CAR sexpr = 'Record =>
    [DNameApplyID, name0,
        [DNameTupleID,: [ SExprToDName(sx, 'T) for sx in CDR sexpr]]]
  newCosig := CDR GETDATABASE(CAR sexpr, QUOTE COSIG)
  [DNameApplyID, name0,
   : MAPCAR(function SExprToDName, CDR sexpr, newCosig)]

-- local garbage because Compiler strings are null terminated
StringToCompStr(str) ==
   CONCATENATE(QUOTE STRING, str, STRING (CODE_-CHAR 0))

CompStrToString(str) ==
   SUBSTRING(str, 0, (LENGTH str - 1))
-- local garbage ends

runOldAxiomFunctor(:allArgs) ==
  [:args,env] := allArgs
  GETDATABASE(env, 'CONSTRUCTORKIND) = 'category =>
      [$oldAxiomPreCategoryDispatch,: [env, :args]]
  dom:=APPLY(env, args)
  makeOldAxiomDispatchDomain dom

makeLazyOldAxiomDispatchDomain domform ==
  GETDATABASE(opOf domform, 'CONSTRUCTORKIND) = 'category =>
      [$oldAxiomPreCategoryDispatch,: domform]
  dd := [$lazyOldAxiomDomainDispatch, hashTypeForm(domform,0), domform]
  NCONC(dd,dd) -- installs back pointer to head of domain.
  dd

makeOldAxiomDispatchDomain dom ==
  PAIRP dom => dom
  [$oldAxiomDomainDispatch,hashTypeForm(dom.0,0),:dom]

closeOldAxiomFunctor(name) ==
   [function runOldAxiomFunctor,:SYMBOL_-FUNCTION name]

lazyOldAxiomDomainLookupExport(domenv, self, op, sig, box, skipdefaults, env) ==
  dom := instantiate domenv
  SPADCALL(CDR dom, self, op, sig, box, skipdefaults, CAR(dom).3)

lazyOldAxiomDomainHashCode(domenv, env) == CAR domenv

lazyOldAxiomDomainDevaluate(domenv, env) ==
  dom := instantiate domenv
  SPADCALL(CDR dom, CAR(dom).1)

lazyOldAxiomAddChild(domenv, kid, env) ==
  CONS($lazyOldAxiomDomainDispatch,domenv)

$lazyOldAxiomDomainDispatch :=
   VECTOR('lazyOldAxiomDomain,
          [function lazyOldAxiomDomainDevaluate],
          [nil],
          [function lazyOldAxiomDomainLookupExport],
          [function lazyOldAxiomDomainHashCode],
          [function lazyOldAxiomAddChild])

-- old Axiom pre category objects are just (dispatch . catform)
-- where catform is ('categoryname,: evaluated args)
-- old Axiom category objects are  (dispatch . [catform, hashcode, defaulting package, parent vector, dom])
oldAxiomPreCategoryBuild(catform, dom, env) ==
   pack := oldAxiomCategoryDefaultPackage(catform, dom)
   CONS($oldAxiomCategoryDispatch,
       [catform, hashTypeForm(catform,0), pack, oldAxiomPreCategoryParents(catform,dom), dom])
oldAxiomPreCategoryHashCode(catform, env) == hashTypeForm(catform,0)
oldAxiomCategoryDefaultPackage(catform, dom) ==
    hasDefaultPackage opOf catform

oldAxiomPreCategoryDevaluate([op,:args], env) ==
   SExprToDName([op,:devaluateList args], T)

$oldAxiomPreCategoryDispatch :=
   VECTOR('oldAxiomPreCategory,
          [function oldAxiomPreCategoryDevaluate],
          [nil],
          [nil],
          [function oldAxiomPreCategoryHashCode],
          [function oldAxiomPreCategoryBuild],
          [nil])

oldAxiomCategoryDevaluate([[op,:args],:.], env) ==
   SExprToDName([op,:devaluateList args], T)

oldAxiomPreCategoryParents(catform,dom) ==
  vars := ["$",:rest GETDATABASE(opOf catform, 'CONSTRUCTORFORM)]
  vals := [dom,:rest catform]
  -- parents :=  GETDATABASE(opOf catform, 'PARENTS)
  parents := parentsOf opOf catform
  PROGV(vars, vals,
    LIST2VEC
      [EVAL quoteCatOp cat for [cat,:pred] in parents | EVAL pred])

quoteCatOp cat ==
   atom cat => MKQ cat
   ['LIST, MKQ CAR cat,: CDR cat]


oldAxiomCategoryLookupExport(catenv, self, op, sig, box, env) ==
   [catform,hash, pack,:.] := catenv
   opIsHasCat op => if EQL(sig, hash) then [self] else nil
   NULL(pack) => nil
   if not VECP pack then
       pack:=apply(pack, CONS(self, rest catform))
       RPLACA(CDDR catenv, pack)
   fun := basicLookup(op, sig, pack, self) => [fun]
   nil

oldAxiomCategoryParentCount([.,.,.,parents,.], env) == LENGTH parents
oldAxiomCategoryNthParent([.,.,.,parvec,dom], n, env) ==
  catform := ELT(parvec, n-1)
  VECTORP KAR catform => catform
  newcat := oldAxiomPreCategoryBuild(catform,dom,nil)
  SETELT(parvec, n-1, newcat)
  newcat

oldAxiomCategoryBuild([catform,:.], dom, env) ==
  oldAxiomPreCategoryBuild(catform,dom, env)
oldAxiomCategoryHashCode([.,hash,:.], env) == hash

$oldAxiomCategoryDispatch :=
   VECTOR('oldAxiomCategory,
          [function oldAxiomCategoryDevaluate],
          [nil],
          [function oldAxiomCategoryLookupExport],
          [function oldAxiomCategoryHashCode],
          [function oldAxiomCategoryBuild], -- builder ??
          [function oldAxiomCategoryParentCount],
          [function oldAxiomCategoryNthParent]) -- 1 indexed

instantiate domenv ==
   -- following is a patch for a bug in runtime.as
   -- has a lazy dispatch vector with an instantiated domenv
  VECTORP CDR domenv => [$oldAxiomDomainDispatch ,: domenv]
  callForm := CADR domenv
  oldDom := CDDR domenv
  [functor,:args] := callForm
--  if null(fn := GETL(functor,'instantiate)) then
--     ofn := SYMBOL_-FUNCTION functor
--     loadFunctor functor
--     fn := SYMBOL_-FUNCTION functor
--     SETF(SYMBOL_-FUNCTION functor, ofn)
--     PUT(functor, 'instantiate, fn)
--  domvec := APPLY(fn, args)
  domvec := APPLY(functor, args)
  RPLACA(oldDom, $oldAxiomDomainDispatch)
  RPLACD(oldDom, [CADR oldDom,: domvec])
  oldDom

hashTypeForm([fn,: args], percentHash) ==
   hashType([fn,:devaluateList args], percentHash)

--------------------> NEW DEFINITION (override in i-util.boot.pamphlet)
devaluate(d) ==
  isDomain d =>
      -- ?need a shortcut for old domains
      -- ELT(CAR d, 0) = 'oldAxiomDomain => ...
      -- FIXP(ELT(CAR d,0)) => d
      DNameToSExpr(SPADCALL(CDR d,CAR(d).1))
  not REFVECP d => d
  QSGREATERP(QVSIZE d,5) and QREFELT(d,3) is ['Category] => QREFELT(d,0)
  QSGREATERP(QVSIZE d,0) =>
    d':=QREFELT(d,0)
    isFunctor d' => d'
    d
  d

$hashOp1 := hashString '"1"
$hashOp0 := hashString '"0"
$hashOpApply := hashString '"apply"
$hashOpSet := hashString '"set!"
$hashSeg := hashString '".."
$hashPercent := hashString '"%"

oldAxiomDomainLookupExport _
  (domenv, self, op, sig, box, skipdefaults, env) ==
     domainVec := CDR domenv
     if hashCode? op then
         EQL(op, $hashOp1) => op := 'One
         EQL(op, $hashOp0) => op := 'Zero
         EQL(op, $hashOpApply) => op := 'elt
         EQL(op, $hashOpSet) => op := 'setelt
         EQL(op, $hashSeg) => op := 'SEGMENT
     constant := nil
     if hashCode? sig and self and EQL(sig, getDomainHash self) then
       sig := '($)
       constant := true
     val :=
       skipdefaults =>
          oldCompLookupNoDefaults(op, sig, domainVec, self)
       oldCompLookup(op, sig, domainVec, self)
     null val => val
     if constant then val := SPADCALL val
     RPLACA(box, val)
     box

oldAxiomDomainHashCode(domenv, env) == CAR domenv

oldAxiomDomainDevaluate(domenv, env) ==
   SExprToDName(CDR(domenv).0, 'T)

oldAxiomAddChild(domenv, child, env) == CONS($oldAxiomDomainDispatch, domenv)

$oldAxiomDomainDispatch :=
   VECTOR('oldAxiomDomain,
          [function oldAxiomDomainDevaluate],
          [nil],
          [function oldAxiomDomainLookupExport],
          [function oldAxiomDomainHashCode],
          [function oldAxiomAddChild])

--------------------> NEW DEFINITION (see g-util.boot.pamphlet)
isDomain a ==
  PAIRP a and VECP(CAR a) and
    member(CAR(a).0, $domainTypeTokens)

-- following is interpreter interface to function lookup
-- perhaps it should always work with hashcodes for signature?
--------------------> NEW DEFINITION (override in nrungo.boot.pamphlet)
NRTcompiledLookup(op,sig,dom) ==
  if CONTAINED('_#,sig) then
      sig := [NRTtypeHack t for t in sig]
  hashCode? sig =>   compiledLookupCheck(op,sig,dom)
  (fn := compiledLookup(op,sig,dom)) => fn
  percentHash :=
      VECP dom => hashType(dom.0, 0)
      getDomainHash dom
  compiledLookupCheck(op, hashType(['Mapping,:sig], percentHash), dom)

--------------------> NEW DEFINITION (override in nrungo.boot.pamphlet)
compiledLookup(op, sig, dollar) ==
  if not isDomain dollar then dollar := NRTevalDomain dollar
  basicLookup(op, sig, dollar, dollar)

--------------------> NEW DEFINITION (override in nrungo.boot.pamphlet)
basicLookup(op,sig,domain,dollar) ==
   -- following case is for old domains like Record and Union
   -- or for getting operations out of yourself
  VECP domain =>
     isNewWorldDomain domain => -- getting ops from yourself (or for defaults)
        oldCompLookup(op, sig, domain, dollar)
     -- getting ops from Record or Union
     lookupInDomainVector(op,sig,domain,dollar)
  hashPercent :=
     VECP dollar => hashType(dollar.0,0)
     hashType(dollar,0)
  box := [nil]
  not VECP(dispatch := CAR domain) => error "bad domain format"
  lookupFun := dispatch.3
  dispatch.0 = 0 =>  -- new compiler domain object
       hashSig :=
           hashCode? sig => sig
           opIsHasCat op => hashType(sig, hashPercent)
           hashType(['Mapping,:sig], hashPercent)

       if SYMBOLP op then
          op = 'Zero => op := $hashOp0
          op = 'One => op := $hashOp1
          op = 'elt => op := $hashOpApply
          op = 'setelt => op := $hashOpSet
          op := hashString SYMBOL_-NAME op
       val:=CAR SPADCALL(CDR domain, dollar, op, hashSig, box, false,
                               lookupFun) => val
       hashCode? sig => nil
       #sig>1 or opIsHasCat op => nil
       boxval := SPADCALL(CDR dollar, dollar, op, hashType(first sig, hashPercent),
                     box, false, lookupFun) =>
          [FUNCTION IDENTITY,: CAR boxval]
       nil
  opIsHasCat op =>
      HasCategory(domain, sig)
  if hashCode? op then
     EQL(op, $hashOp1) => op := 'One
     EQL(op, $hashOp0) => op := 'Zero
     EQL(op, $hashOpApply) => op := 'elt
     EQL(op, $hashOpSet) => op := 'setelt
     EQL(op, $hashSeg) => op := 'SEGMENT
  hashCode? sig and EQL(sig, hashPercent) =>
      SPADCALL CAR SPADCALL(CDR dollar, dollar, op, '($), box, false, lookupFun)
  CAR SPADCALL(CDR dollar, dollar, op, sig, box, false, lookupFun)

basicLookupCheckDefaults(op,sig,domain,dollar) ==
  box := [nil]
  not VECP(dispatch := CAR dollar) => error "bad domain format"
  lookupFun := dispatch.3
  dispatch.0 = 0  =>  -- new compiler domain object
       hashPercent :=
          VECP dollar => hashType(dollar.0,0)
          hashType(dollar,0)

       hashSig :=
         hashCode? sig => sig
         hashType( ['Mapping,:sig], hashPercent)

       if SYMBOLP op then op := hashString SYMBOL_-NAME op
       CAR SPADCALL(CDR dollar, dollar, op, hashSig, box, not $lookupDefaults, lookupFun)
  CAR SPADCALL(CDR dollar, dollar, op, sig, box, not $lookupDefaults, lookupFun)

$hasCatOpHash := hashString '"%%"
opIsHasCat op ==
  hashCode? op => EQL(op, $hasCatOpHash)
  EQ(op, "%%")

-- has cat questions lookup up twice if false
-- replace with following ?
--  not(opIsHasCat op) and
--     (u := lookupInDomainVector(op,sig,domvec,domvec)) => u

oldCompLookup(op, sig, domvec, dollar) ==
  $lookupDefaults:local := nil
  u := lookupInDomainVector(op,sig,domvec,dollar) => u
  $lookupDefaults := true
  lookupInDomainVector(op,sig,domvec,dollar)

oldCompLookupNoDefaults(op, sig, domvec, dollar) ==
  $lookupDefaults:local := nil
  lookupInDomainVector(op,sig,domvec,dollar)

--------------------> NEW DEFINITION (override in nrungo.boot.pamphlet)
lookupInDomainVector(op,sig,domain,dollar) ==
  PAIRP domain => basicLookupCheckDefaults(op,sig,domain,domain)
  slot1 := domain.1
  SPADCALL(op,sig,dollar,slot1)

--------------------> NEW DEFINITION (override in nrunfast.boot.pamphlet)
lookupComplete(op,sig,dollar,env) ==
   hashCode? sig => hashNewLookupInTable(op,sig,dollar,env,nil)
   newLookupInTable(op,sig,dollar,env,nil)

--------------------> NEW DEFINITION (override in nrunfast.boot.pamphlet)
lookupIncomplete(op,sig,dollar,env) ==
   hashCode? sig => hashNewLookupInTable(op,sig,dollar,env,true)
   newLookupInTable(op,sig,dollar,env,true)


--------------------> NEW DEFINITION (override in nrunfast.boot.pamphlet)
lazyMatchArg2(s,a,dollar,domain,typeFlag) ==
  if s = '$ then
--  a = 0 => return true  --needed only if extra call in newGoGet to basicLookup
    s := devaluate dollar -- calls from HasCategory can have $s
  INTEGERP a =>
    not typeFlag => s = domain.a
    a = 6 and $isDefaultingPackage => s = devaluate dollar
    VECP (d := domainVal(dollar,domain,a)) =>
      s = d.0 => true
      domainArg := ($isDefaultingPackage => domain.6.0; domain.0)
      KAR s = QCAR d.0 and lazyMatchArgDollarCheck(s,d.0,dollar.0,domainArg)
    isDomain d =>
        dhash:=getDomainHash d
        dhash =
           (if hashCode? s then s else hashType(s, dhash))
    lazyMatch(s,d,dollar,domain)                         --new style
  a = '$ => s = devaluate dollar
  a = "$$" => s = devaluate domain
  STRINGP a =>
    STRINGP s => a = s
    s is ['QUOTE,y] and PNAME y = a
    IDENTP s and PNAME s = a
  atom a =>  a = s
  op := opOf a
  op  = 'NRTEVAL => s = nrtEval(CADR a,domain)
  op = 'QUOTE => s = CADR a
  lazyMatch(s,a,dollar,domain)
  --above line is temporarily necessary until system is compiled 8/15/90
--s = a

--------------------> NEW DEFINITION (override in nrunfast.boot.pamphlet)
getOpCode(op,vec,max) ==
--search Op vector for "op" returning code if found, nil otherwise
  res := nil
  hashCode? op =>
    for i in 0..max by 2 repeat
      EQL(hashString PNAME QVELT(vec,i),op) => return (res := QSADD1 i)
    res
  for i in 0..max by 2 repeat
    EQ(QVELT(vec,i),op) => return (res := QSADD1 i)
  res

hashNewLookupInTable(op,sig,dollar,[domain,opvec],flag) ==
  opIsHasCat op =>
      HasCategory(domain, sig)
  if hashCode? op and EQL(op, $hashOp1) then op := 'One
  if hashCode? op and EQL(op, $hashOp0) then op := 'Zero
  hashPercent :=
    VECP dollar => hashType(dollar.0,0)
    hashType(dollar,0)
  if hashCode? sig and EQL(sig, hashPercent) then
         sig := hashType('(Mapping $), hashPercent)
  dollar = nil => systemError()
  $lookupDefaults = true =>
    hashNewLookupInCategories(op,sig,domain,dollar)      --lookup first in my cats
      or newLookupInAddChain(op,sig,domain,dollar)
  --fast path when called from newGoGet
  success := false
  if $monitorNewWorld then
    sayLooking(concat('"---->",form2String devaluate domain,
      '"----> searching op table for:","%l","  "),op,sig,dollar)
  someMatch := false
  numvec := getDomainByteVector domain
  predvec := domain.3
  max := MAXINDEX opvec
  k := getOpCode(op,opvec,max) or return
    flag => newLookupInAddChain(op,sig,domain,dollar)
    nil
  maxIndex := MAXINDEX numvec
  start := ELT(opvec,k)
  finish :=
    QSGREATERP(max,k) => opvec.(QSPLUS(k,2))
    maxIndex
  if QSGREATERP(finish,maxIndex) then systemError '"limit too large"
  numArgs := if hashCode? sig then -1 else (#sig)-1
  success := nil
  $isDefaultingPackage: local :=
    -- use special defaulting handler when dollar non-trivial
    dollar ~= domain and isDefaultPackageForm? devaluate domain
  while finish > start repeat
    PROGN
      i := start
      numTableArgs :=numvec.i
      predIndex := numvec.(i := QSADD1 i)
      NE(predIndex,0) and null testBitVector(predvec,predIndex) => nil
      exportSig :=
          [newExpandTypeSlot(numvec.(i + j + 1),
            dollar,domain) for j in 0..numTableArgs]
      sig ~= hashType(['Mapping,: exportSig],hashPercent) => nil --signifies no match
      loc := numvec.(i + numTableArgs + 2)
      loc = 1 => (someMatch := true)
      loc = 0 =>
        start := QSPLUS(start,QSPLUS(numTableArgs,4))
        i := start + 2
        someMatch := true --mark so that if subsumption fails, look for original
        subsumptionSig :=
          [newExpandTypeSlot(numvec.(QSPLUS(i,j)),
            dollar,domain) for j in 0..numTableArgs]
        if $monitorNewWorld then
          sayBrightly [formatOpSignature(op,sig),'"--?-->",
            formatOpSignature(op,subsumptionSig)]
        nil
      slot := domain.loc
      null atom slot =>
        EQ(QCAR slot,FUNCTION newGoGet) => someMatch:=true
                   --treat as if operation were not there
        --if EQ(QCAR slot, function newGoGet) then
        --  UNWIND_-PROTECT --break infinite recursion
        --    ((SETELT(domain,loc,'skip); slot := replaceGoGetSlot QCDR slot),
        --      if domain.loc = 'skip then domain.loc := slot)
        return (success := slot)
      slot = 'skip =>       --recursive call from above 'replaceGoGetSlot
        return (success := newLookupInAddChain(op,sig,domain,dollar))
      systemError '"unexpected format"
    start := QSPLUS(start,QSPLUS(numTableArgs,4))
  NE(success,'failed) and success =>
    if $monitorNewWorld then
      sayLooking1('"<----",uu) where uu ==
        PAIRP success => [first success,:devaluate rest success]
        success
    success
  subsumptionSig and (u:= basicLookup(op,subsumptionSig,domain,dollar)) => u
  flag or someMatch => newLookupInAddChain(op,sig,domain,dollar)
  nil

--------------------> NEW DEFINITION (override in nrunfast.boot.pamphlet)
newExpandLocalType(lazyt,dollar,domain) ==
  VECP lazyt => lazyt.0
  isDomain lazyt => devaluate lazyt
  ATOM lazyt => lazyt
  lazyt is [vec,.,:lazyForm] and VECP vec =>              --old style
    BREAK()
    newExpandLocalTypeForm(lazyForm,dollar,domain)
  newExpandLocalTypeForm(lazyt,dollar,domain)             --new style

hashNewLookupInCategories(op,sig,dom,dollar) ==
  slot4 := dom.4
  catVec := CADR slot4
  SIZE catVec = 0 => nil                      --early exit if no categories
  INTEGERP KDR catVec.0 =>
    newLookupInCategories1(op,sig,dom,dollar) --old style
  $lookupDefaults : local := nil
  if $monitorNewWorld = true then sayBrightly concat('"----->",
    form2String devaluate dom,'"-----> searching default packages for ",op)
  predvec := dom.3
  packageVec := QCAR slot4
--the next three lines can go away with new category world
  varList := ['$,:$FormalMapVariableList]
  valueList := [dom,:[dom.(5+i) for i in 1..(# rest dom.0)]]
  valueList := [MKQ val for val in valueList]
  nsig := MSUBST(dom.0,dollar.0,sig)
  for i in 0..MAXINDEX packageVec |
       (entry := packageVec.i) and entry ~= 'T repeat
    package :=
      VECP entry =>
         if $monitorNewWorld then
           sayLooking1('"already instantiated cat package",entry)
         entry
      IDENTP entry =>
        cat := catVec.i
        packageForm := nil
        if not GETL(entry,'LOADED) then loadLib entry
        infovec := GETL(entry,'infovec)
        success :=
          --VECP infovec =>  ----new world
          true =>  ----new world
            opvec := infovec.1
            max := MAXINDEX opvec
            code := getOpCode(op,opvec,max)
            null code => nil
            byteVector := CDDDR infovec.3
            endPos :=
              code+2 > max => SIZE byteVector
              opvec.(code+2)
            --not nrunNumArgCheck(#(QCDR sig),byteVector,opvec.code,endPos) => nil
            --numOfArgs := byteVector.(opvec.code)
            --numOfArgs ~= #(QCDR sig) => nil
            packageForm := [entry,'$,:CDR cat]
            package := evalSlotDomain(packageForm,dom)
            packageVec.i := package
            package

        null success =>
          if $monitorNewWorld = true then
            sayBrightlyNT '"  not in: "
            pp (packageForm and devaluate package or entry)
          nil
        if $monitorNewWorld then
          sayLooking1('"candidate default package instantiated: ",success)
        success
      entry
    null package => nil
    if $monitorNewWorld then
      sayLooking1('"Looking at instantiated package ",package)
    res := basicLookup(op,sig,package,dollar) =>
      if $monitorNewWorld = true then
        sayBrightly '"candidate default package succeeds"
      return res
    if $monitorNewWorld = true then
      sayBrightly '"candidate fails -- continuing to search categories"
    nil

--------------------> NEW DEFINITION (override in nrunfast.boot.pamphlet)
replaceGoGetSlot env ==
  [thisDomain,index,:op] := env
  thisDomainForm := devaluate thisDomain
  bytevec := getDomainByteVector thisDomain
  numOfArgs := bytevec.index
  goGetDomainSlotIndex := bytevec.(index := QSADD1 index)
  goGetDomain :=
     goGetDomainSlotIndex = 0 => thisDomain
     thisDomain.goGetDomainSlotIndex
  if PAIRP goGetDomain and SYMBOLP CAR goGetDomain then
     goGetDomain := lazyDomainSet(goGetDomain,thisDomain,goGetDomainSlotIndex)
  sig :=
    [newExpandTypeSlot(bytevec.(index := QSADD1 index),thisDomain,thisDomain)
      for i in 0..numOfArgs]
  thisSlot := bytevec.(QSADD1 index)
  if $monitorNewWorld then
    sayLooking(concat('"%l","..",form2String thisDomainForm,
      '" wants",'"%l",'"  "),op,sig,goGetDomain)
  slot :=  basicLookup(op,sig,goGetDomain,goGetDomain)
  slot = nil =>
    $returnNowhereFromGoGet = true =>
      ['nowhere,:goGetDomain]  --see newGetDomainOpTable
    sayBrightly concat('"Function: ",formatOpSignature(op,sig),
      '" is missing from domain: ",form2String goGetDomain.0)
    keyedSystemError("S2NR0001",[op,sig,goGetDomain.0])
  if $monitorNewWorld then
    sayLooking1(['"goget stuffing slot",:bright thisSlot,'"of "],thisDomain)
  SETELT(thisDomain,thisSlot,slot)
  if $monitorNewWorld then
    sayLooking1('"<------",[CAR slot,:devaluate CDR slot])
  slot

newHasCategory(domain,catform) ==
  catform = '(Type) => true
  slot4 := domain.4
  auxvec := CAR slot4
  catvec := CADR slot4
  $isDefaultingPackage: local := isDefaultPackageForm? devaluate domain
  #catvec > 0 and INTEGERP KDR catvec.0 =>              --old style
    BREAK()
  lazyMatchAssocV(catform,auxvec,catvec,domain)         --new style

--------------------> NEW DEFINITION (override in nrunfast.boot.pamphlet)
lazyMatchAssocV(x,auxvec,catvec,domain) ==      --new style slot4
  -- Does not work (triggers type error due to initialization by NIL)
  -- n : FIXNUM := MAXINDEX catvec
  n := MAXINDEX catvec
  -- following call to hashType was missing 2nd arg. 0 added on 3/31/94 by RSS
  hashCode? x =>
    percentHash :=
      VECP domain => hashType(domain.0, 0)
      getDomainHash domain
    or/[ELT(auxvec,i) for i in 0..n |
        x = hashType(newExpandLocalType(QVELT(catvec,i),domain,domain), percentHash)]
  xop := CAR x
  or/[ELT(auxvec,i) for i in 0..n |
    --xop = CAR (lazyt := QVELT(catvec,i)) and lazyMatch(x,lazyt,domain,domain)]
    xop = CAR (lazyt := getCatForm(catvec,i,domain)) and lazyMatch(x,lazyt,domain,domain)]

getCatForm(catvec, index, domain) ==
   NUMBERP(form := QVELT(catvec,index)) => domain.form
   form

has(domain,catform') == HasCategory(domain,catform')

HasCategory(domain,catform') ==
  catform' is ['SIGNATURE,:f] => HasSignature(domain,f)
  catform' is ['ATTRIBUTE,f] =>
      BREAK()
  isDomain domain =>
     FIXP((first domain).0) =>
        catform' := devaluate catform'
        basicLookup("%%",catform',domain,domain)
     HasCategory(CDDR domain, catform')
  catform:= devaluate catform'
  isNewWorldDomain domain => newHasCategory(domain,catform)
  domain0:=domain.0 -- handles old style domains, Record, Union etc.
  slot4 := domain.4
  catlist := slot4.1
  member(catform,catlist) or
   opOf(catform) = "Type" or  --temporary hack
    or/[compareSigEqual(catform,cat,domain0,domain) for cat in catlist]

--------------------> NEW DEFINITION (override in nrunfast.boot.pamphlet)
lazyDomainSet(lazyForm,thisDomain,slot) ==
  form :=
    lazyForm                                        --new style
  slotDomain := evalSlotDomain(form,thisDomain)
  if $monitorNewWorld then
    sayLooking1(concat(form2String devaluate thisDomain,
      '" activating lazy slot ",slot,'": "),slotDomain)
-- name := CAR form
--getInfovec name
  SETELT(thisDomain,slot,slotDomain)


--------------------> NEW DEFINITION (override in template.boot.pamphlet)
evalSlotDomain(u,dollar) ==
  $returnNowhereFromGoGet: local := false
  $ : fluid := dollar
  $lookupDefaults : local := nil -- new world
  isDomain u => u
  u = '$ => dollar
  u = "$$" => dollar
  FIXP u =>
    VECP (y := dollar.u) => y
    isDomain y => y
    y is ['SETELT,:.] => eval y--lazy domains need to marked; this is dangerous?
    y is [v,:.] =>
      VECP v =>
          BREAK()
          lazyDomainSet(y,dollar,u)               --old style has [$,code,:lazyt]
      constructor? v or MEMQ(v,'(Record Union Mapping)) =>
        lazyDomainSet(y,dollar,u)                       --new style has lazyt
      y
    y
  u is ['NRTEVAL,y] =>
    y is ['ELT,:.] => evalSlotDomain(y,dollar)
    eval  y
  u is ['QUOTE,y] => y
  u is ['Record,:argl] =>
     FUNCALL('Record0,[[tag,:evalSlotDomain(dom,dollar)]
                                 for [.,tag,dom] in argl])
  u is ['Union,:argl] and first argl is ['_:,.,.] =>
     APPLY('Union,[['_:,tag,evalSlotDomain(dom,dollar)]
                                 for [.,tag,dom] in argl])
  u is ['spadConstant,d,n] =>
    dom := evalSlotDomain(d,dollar)
    SPADCALL(dom . n)
  u is ['ELT,d,n] =>
    dom := evalSlotDomain(d,dollar)
    slot := dom . n
    slot is [=FUNCTION newGoGet,:env] =>
        replaceGoGetSlot env
    slot
  u is [op,:argl] => APPLY(op,[evalSlotDomain(x,dollar) for x in argl])
  systemErrorHere '"evalSlotDomain"

--------------------> NEW DEFINITION (override in i-util.boot.pamphlet)
domainEqual(a,b) ==
  devaluate(a) = devaluate(b)


--------------------> NEW DEFINITION (see i-funsel.boot.pamphlet)
getFunctionFromDomain(op,dc,args) ==
  -- finds the function op with argument types args in dc
  -- complains, if no function or ambiguous
  $reportBottomUpFlag:local:= NIL
  member(CAR dc,$nonLisplibDomains) =>
    throwKeyedMsg("S2IF0002",[CAR dc])
  not constructor? CAR dc =>
    throwKeyedMsg("S2IF0003",[CAR dc])
  p:= findFunctionInDomain(op,dc,NIL,args,args,NIL,NIL) =>
--+
    --sig := [NIL,:args]
    domain := evalDomain dc
    for mm in nreverse p until b repeat
      [[.,:osig],nsig,:.] := mm
      b := compiledLookup(op,nsig,domain)
    b or  throwKeyedMsg("S2IS0023",[op,dc])
  throwKeyedMsg("S2IF0004",[op,dc])

devaluateDeeply x ==
    VECP x => devaluate x
    atom x => x
    [devaluateDeeply y for y in x]

lookupDisplay(op,sig,vectorOrForm,suffix) ==
    null $NRTmonitorIfTrue => nil
    prefix := (suffix = '"" => ">"; "<")
    sayBrightly
        concat(prefix,formatOpSignature(op,sig),
            '" from ", prefix2String devaluateDeeply vectorOrForm,suffix)

isCategoryPackageName nam ==
    p := PNAME opOf nam
    p.(MAXINDEX p) = char '_&
