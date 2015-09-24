\documentclass{article}
\usepackage{axiom}
\begin{document}
\title{\$SPAD/src/algebra interval.as}
\author{Mike Dewar}
\maketitle
\begin{abstract}
\end{abstract}
\eject
\tableofcontents
\eject
\section{IntervalCategory}
<<IntervalCategory>>=
#include "axiom.as"

+++ Author: Mike Dewar
+++ Date Created: November 1996
+++ Date Last Updated:
+++ Basic Functions:
+++ Related Constructors:
+++ Also See:
+++ AMS Classifications:
+++ Keywords:
+++ References:
+++ Description:
+++ This category is an implementation of interval arithmetic and transcendental
+++ functions over intervals.

FUNCAT ==> Join(FloatingPointSystem,TranscendentalFunctionCategory);

define IntervalCategory(R:FUNCAT): Category ==
 Join(GcdDomain, OrderedSet, TranscendentalFunctionCategory, RadicalCategory,
      RetractableTo(Integer))
 with {
  approximate;
  interval : (R,R) -> %;
    ++ interval(inf,sup) creates a new interval, either \spad{[inf,sup]} if
    ++ \spad{inf <= sup} or \spad{[sup,in]} otherwise.
  qinterval : (R,R) -> %;
    ++ qinterval(inf,sup) creates a new interval \spad{[inf,sup]}, without
    ++ checking the ordering on the elements.
  interval : R -> %;
    ++ interval(f) creates a new interval around f.
  interval : Fraction Integer -> %;
    ++ interval(f) creates a new interval around f.
  inf : % -> R;
    ++ inf(u) returns the infinum of \spad{u}.
  sup : % -> R;
    ++ sup(u) returns the supremum of \spad{u}.
  width : % -> R;
    ++ width(u) returns \spad{sup(u) - inf(u)}.
  positive? : % -> Boolean;
    ++ positive?(u) returns \spad{true} if every element of u is positive,
    ++ \spad{false} otherwise.
  negative? : % -> Boolean;
    ++ negative?(u) returns \spad{true} if every element of u is negative,
    ++ \spad{false} otherwise.
  contains? : (%,R) -> Boolean;
    ++ contains?(i,f) returns true if \spad{f} is contained within the interval
    ++ \spad{i}, false otherwise.
}

@
\section{Interval}
<<Interval>>=
+++ Author: Mike Dewar
+++ Date Created: November 1996
+++ Date Last Updated:
+++ Basic Functions:
+++ Related Constructors:
+++ Also See:
+++ AMS Classifications:
+++ Keywords:
+++ References:
+++ Description:
+++ This domain is an implementation of interval arithmetic and transcendental
+++ functions over intervals.

Interval(R:FUNCAT): IntervalCategory(R) == add {

  import from Integer;
  import from R;

  Rep ==> Record(Inf:R, Sup:R);

  import from Rep;

  local roundDown(u:R):R ==
    if zero?(u) then float(-1,-(bits() pretend Integer));
                else float(mantissa(u) - 1,exponent(u));

  local roundUp(u:R):R   ==
    if zero?(u) then float(1, -(bits()) pretend Integer);
                else float(mantissa(u) + 1,exponent(u));

  -- Sometimes the float representation does not use all the bits (e.g. when
  -- representing an integer in software using arbitrary-length Integers as
  -- your mantissa it is convenient to keep them exact).  This function
  -- normalises things so that rounding etc. works as expected.  It is only
  -- called when creating new intervals.
  local normaliseFloat(u:R):R ==
    if zero? u then u else {
    m : Integer := mantissa u;
    b : Integer := bits() pretend Integer;
    l : Integer := length(m);
    if (l < b) then {
      BASE : Integer := base()$R pretend Integer;
      float(m*BASE^((b-l) pretend PositiveInteger),exponent(u)-b+l);
    }
    else
      u;
  }

  interval(i:R,s:R):% == {
    i > s =>  per [roundDown normaliseFloat s,roundUp normaliseFloat i];
    per [roundDown normaliseFloat i,roundUp normaliseFloat s];
  }

  interval(f:R):% == {
    zero?(f) => 0;
    one?(f)  => 1;
    -- This next part is necessary to allow e.g. mapping between Expressions:
    -- AXIOM assumes that Integers stay as Integers!
    import from Union(value1:Integer,failed:'failed');
    fnew : R := normaliseFloat f;
    retractIfCan(f)@Union(value1:Integer,failed:'failed') case value1 =>
      per [fnew,fnew];
    per [roundDown fnew, roundUp fnew];
  }

  qinterval(i:R,s:R):% ==
    per [roundDown normaliseFloat i,roundUp normaliseFloat s];

  local exactInterval(i:R,s:R):% == per [i,s];
  local exactSupInterval(i:R,s:R):% == per [roundDown i,s];
  local exactInfInterval(i:R,s:R):% == per [i,roundUp s];

  inf(u:%):R == (rep u).Inf;
  sup(u:%):R == (rep u).Sup;
  width(u:%):R == (rep u).Sup - (rep u).Inf;

  contains?(u:%,f:R):Boolean == (f > inf(u)) and (f < sup(u));

  positive?(u:%):Boolean == inf(u) > 0;
  negative?(u:%):Boolean == sup(u) < 0;

  (<)(a:%,b:%):Boolean ==
    if inf(a) < inf(b) then
      true
    else if inf(a) > inf(b) then
      false
    else
      sup(a) < sup(b);

  (+)(a:%,b:%):% == {
    -- A couple of blatent hacks to preserve the Ring Axioms!
    if zero?(a) then return(b) else if zero?(b) then return(a);
    if a=b then return qinterval(2*inf(a),2*sup(a));
    qinterval(inf(a) + inf(b), sup(a) + sup(b));
  }

  (-)(a:%,b:%):% ==  {
    if zero?(a) then return(-b) else if zero?(b) then return(a);
    if a=b then 0 else qinterval(inf(a) - sup(b), sup(a) - inf(b));
  }

  (*)(a:%,b:%):% == {
    -- A couple of blatent hacks to preserve the Ring Axioms!
    if one?(a) then return(b) else if one?(b) then return(a);
    if zero?(a) then return(0) else if zero?(b) then return(0);
    prods : List R :=  sort [inf(a)*inf(b),sup(a)*sup(b),
                             inf(a)*sup(b),sup(a)*inf(b)];
    qinterval(first prods, last prods);
  }

  (*)(a:Integer,b:%):% == {
    if (a > 0) then
      qinterval(a*inf(b),a*sup(b));
    else if (a < 0) then
      qinterval(a*sup(b),a*inf(b));
    else
      0;
  }

  (*)(a:PositiveInteger,b:%):% == qinterval(a*inf(b),a*sup(b));

  (^)(a:%,n:PositiveInteger):% == {
    contains?(a,0) and zero?((n pretend Integer) rem 2) =>
      interval(0,max(inf(a)^n,sup(a)^n));
    interval(inf(a)^n,sup(a)^n);
  }

  (^) (a:%,n:PositiveInteger):% ==  {
    contains?(a,0) and zero?((n pretend Integer) rem 2) =>
      interval(0,max(inf(a)^n,sup(a)^n));
    interval(inf(a)^n,sup(a)^n);
  }

  (-)(a:%):% == exactInterval(-sup(a),-inf(a));

  (=)(a:%,b:%):Boolean == (inf(a)=inf(b)) and (sup(a)=sup(b));
  (~=)(a:%,b:%):Boolean == (inf(a)~=inf(b)) or (sup(a)~=sup(b));

  1:% == {one : R := normaliseFloat 1; per([one,one])};
  0:% == per([0,0]);

  recip(u:%):Union(value1:%,failed:'failed') == {
   contains?(u,0) => [failed];
   vals:List R := sort[1/inf(u),1/sup(u)];
   [qinterval(first vals, last vals)];
  }

  unit?(u:%):Boolean == contains?(u,0);

  exquo(u:%,v:%):Union(value1:%,failed:'failed') == {
   contains?(v,0) => [failed];
   one?(v) => [u];
   u=v => [1];
   u=-v => [-1];
   vals:List R := sort[inf(u)/inf(v),inf(u)/sup(v),sup(u)/inf(v),sup(u)/sup(v)];
   [qinterval(first vals, last vals)];
  }

  gcd(u:%,v:%):% == 1;

  coerce(u:Integer):% == {
    ur := normaliseFloat(u::R);
    exactInterval(ur,ur);
  }

  interval(u:Fraction Integer):% == {
    import { log2 : % -> %;
             coerce : Integer -> %;
             retractIfCan : % -> Union(value1:Integer,failed:'failed');}
    from Float;
    flt := u::R;

    -- Test if the representation in R is exact
    --den := denom(u)::Float;
    local bin : Union(value1:Integer,failed:'failed');
    bin := retractIfCan(log2(denom(u)::Float));
    bin case value1 and length(numer u)$Integer < (bits() pretend Integer) => {
      flt := normaliseFloat flt;
      exactInterval(flt,flt);
    }

    qinterval(flt,flt);
  }

  retractIfCan(u:%):Union(value1:Integer,failed:'failed') == {
    not zero? width(u) => [failed];
    retractIfCan inf u;
  }

  retract(u:%):Integer == {
    not zero? width(u) =>
      error "attempt to retract a non-Integer interval to an Integer";
    retract inf u;
  }

  coerce(u:%):OutputForm ==
    bracket([coerce inf(u), coerce sup(u)]$List(OutputForm));

  characteristic():NonNegativeInteger == 0;


  -- Explicit export from TranscendentalFunctionCategory
  pi():% == qinterval(pi(),pi());

  -- From ElementaryFunctionCategory
  log(u:%):% == {
    positive?(u) => qinterval(log inf u, log sup u);
    error "negative logs in interval";
  }

  exp(u:%):% == qinterval(exp inf u, exp sup u);

  (^)(u:%,v:%):% == {
    zero?(v) => if zero?(u) then error "0^0 is undefined" else 1;
    one?(u)  => 1;
    expts : List R :=  sort [inf(u)^inf(v),sup(u)^sup(v),
                             inf(u)^sup(v),sup(u)^inf(v)];
    qinterval(first expts, last expts);
  }

  -- From TrigonometricFunctionCategory

  -- This function checks whether an interval contains a value of the form
  -- `offset + 2 n pi'.
  local hasTwoPiMultiple(offset:R,Pi:R,i:%):Boolean == {
    import from Integer;
    next : Integer := retract ceiling( (inf(i) - offset)/(2*Pi) );
    contains?(i,offset+2*next*Pi);
  }

  -- This function checks whether an interval contains a value of the form
  -- `offset + n pi'.
  local hasPiMultiple(offset:R,Pi:R,i:%):Boolean == {
    import from Integer;
    next : Integer := retract ceiling( (inf(i) - offset)/Pi );
    contains?(i,offset+next*Pi);
  }

  sin(u:%):% == {
    import from Integer;
    Pi : R := pi();
    hasOne? : Boolean := hasTwoPiMultiple(Pi/(2::R),Pi,u);
    hasMinusOne? : Boolean := hasTwoPiMultiple(3*Pi/(2::R),Pi,u);

    if hasOne? and hasMinusOne? then
      exactInterval(-1,1);
    else {
      vals : List R := sort [sin inf u, sin sup u];
      if hasOne? then
        exactSupInterval(first vals, 1);
      else if hasMinusOne? then
        exactInfInterval(-1,last vals);
      else
        qinterval(first vals, last vals);
    }
  }

  cos(u:%):% == {
    Pi : R := pi();
    hasOne? : Boolean := hasTwoPiMultiple(0,Pi,u);
    hasMinusOne? : Boolean := hasTwoPiMultiple(Pi,Pi,u);

    if hasOne? and hasMinusOne? then
      exactInterval(-1,1);
    else {
      vals : List R := sort [cos inf u, cos sup u];
      if hasOne? then
        exactSupInterval(first vals, 1);
      else if hasMinusOne? then
        exactInfInterval(-1,last vals);
      else
        qinterval(first vals, last vals);
    }
  }

  tan(u:%):% == {
    Pi : R := pi();
    if width(u) > Pi then
      error "Interval contains a singularity"
    else {
      -- Since we know the interval is less than pi wide, monotonicity implies
      -- that there is no singularity.  If there is a singularity on a endpoint
      -- of the interval the user will see the error generated by R.
      lo : R := tan inf u;
      hi : R := tan sup u;

      lo > hi => error "Interval contains a singularity";
      qinterval(lo,hi);
    }
  }

  csc(u:%):% == {
    Pi : R := pi();
    if width(u) > Pi then
      error "Interval contains a singularity"
    else {
      import from Integer;
      -- singularities are at multiples of Pi
      if hasPiMultiple(0,Pi,u) then error "Interval contains a singularity";
      vals : List R := sort [csc inf u, csc sup u];
      if hasTwoPiMultiple(Pi/(2::R),Pi,u) then
        exactInfInterval(1,last vals);
      else if hasTwoPiMultiple(3*Pi/(2::R),Pi,u) then
        exactSupInterval(first vals,-1);
      else
        qinterval(first vals, last vals);
    }
  }

  sec(u:%):% == {
    Pi : R := pi();
    if width(u) > Pi then
      error "Interval contains a singularity"
    else {
      import from Integer;
      -- singularities are at Pi/2 + n Pi
      if hasPiMultiple(Pi/(2::R),Pi,u) then
        error "Interval contains a singularity";
      vals : List R := sort [sec inf u, sec sup u];
      if hasTwoPiMultiple(0,Pi,u) then
        exactInfInterval(1,last vals);
      else if hasTwoPiMultiple(Pi,Pi,u) then
        exactSupInterval(first vals,-1);
      else
        qinterval(first vals, last vals);
    }
  }


  cot(u:%):% == {
    Pi : R := pi();
    if width(u) > Pi then
      error "Interval contains a singularity"
    else {
      -- Since we know the interval is less than pi wide, monotonicity implies
      -- that there is no singularity.  If there is a singularity on a endpoint
      -- of the interval the user will see the error generated by R.
      hi : R := cot inf u;
      lo : R := cot sup u;

      lo > hi => error "Interval contains a singularity";
      qinterval(lo,hi);
    }
  }

  -- From ArcTrigonometricFunctionCategory

  asin(u:%):% == {
    lo : R := inf(u);
    hi : R := sup(u);
    if (lo < -1) or (hi > 1) then error "asin only defined on the region -1..1";
    qinterval(asin lo,asin hi);
  }

  acos(u:%):% == {
    lo : R := inf(u);
    hi : R := sup(u);
    if (lo < -1) or (hi > 1) then error "acos only defined on the region -1..1";
    qinterval(acos hi,acos lo);
  }

  atan(u:%):% == qinterval(atan inf u, atan sup u);

  acot(u:%):% == qinterval(acot sup u, acot inf u);

  acsc(u:%):% == {
    lo : R := inf(u);
    hi : R := sup(u);
    if ((lo <= -1) and (hi >= -1)) or ((lo <= 1) and (hi >= 1)) then
      error "acsc not defined on the region -1..1";
    qinterval(acsc hi, acsc lo);
  }

  asec(u:%):% == {
    lo : R := inf(u);
    hi : R := sup(u);
    if ((lo < -1) and (hi > -1)) or ((lo < 1) and (hi > 1)) then
      error "asec not defined on the region -1..1";
    qinterval(asec lo, asec hi);
  }

  -- From HyperbolicFunctionCategory

  tanh(u:%):% == qinterval(tanh inf u, tanh sup u);

  sinh(u:%):% == qinterval(sinh inf u, sinh sup u);

  sech(u:%):% == {
    negative? u => qinterval(sech inf u, sech sup u);
    positive? u => qinterval(sech sup u, sech inf u);
    vals : List R := sort [sech inf u, sech sup u];
    exactSupInterval(first vals,1);
  }

  cosh(u:%):% == {
    negative? u => qinterval(cosh sup u, cosh inf u);
    positive? u => qinterval(cosh inf u, cosh sup u);
    vals : List R := sort [cosh inf u, cosh sup u];
    exactInfInterval(1,last vals);
  }

  csch(u:%):% == {
    contains?(u,0) => error "csch: singularity at zero";
    qinterval(csch sup u, csch inf u);
  }

  coth(u:%):% == {
    contains?(u,0) => error "coth: singularity at zero";
    qinterval(coth sup u, coth inf u);
  }

  -- From ArcHyperbolicFunctionCategory

  acosh(u:%):% == {
    inf(u)<1 => error "invalid argument: acosh only defined on the region 1..";
    qinterval(acosh inf u, acosh sup u);
  }

  acoth(u:%):% == {
    lo : R := inf(u);
    hi : R := sup(u);
    if ((lo <= -1) and (hi >= -1)) or ((lo <= 1) and (hi >= 1)) then
      error "acoth not defined on the region -1..1";
    qinterval(acoth hi, acoth lo);
  }

  acsch(u:%):% == {
    contains?(u,0) => error "acsch: singularity at zero";
    qinterval(acsch sup u, acsch inf u);
  }

  asech(u:%):% == {
    lo : R := inf(u);
    hi : R := sup(u);
    if  (lo <= 0) or (hi > 1) then
      error "asech only defined on the region 0 < x <= 1";
    qinterval(asech hi, asech lo);
  }

  asinh(u:%):% == qinterval(asinh inf u, asinh sup u);

  atanh(u:%):% == {
    lo : R := inf(u);
    hi : R := sup(u);
    if  (lo <= -1) or (hi >= 1) then
      error "atanh only defined on the region -1 < x < 1";
    qinterval(atanh lo, atanh hi);
  }

  -- From RadicalCategory
  (^)(u:%,n:Fraction Integer):% == interval(inf(u)^n,sup(u)^n);

}

@
\section{License}
<<license>>=
--Copyright (c) 1991-2002, The Numerical ALgorithms Group Ltd.
--All rights reserved.
--
--Redistribution and use in source and binary forms, with or without
--modification, are permitted provided that the following conditions are
--met:
--
--    - Redistributions of source code must retain the above copyright
--      notice, this list of conditions and the following disclaimer.
--
--    - Redistributions in binary form must reproduce the above copyright
--      notice, this list of conditions and the following disclaimer in
--      the documentation and/or other materials provided with the
--      distribution.
--
--    - Neither the name of The Numerical ALgorithms Group Ltd. nor the
--      names of its contributors may be used to endorse or promote products
--      derived from this software without specific prior written permission.
--
--THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
--IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
--TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
--PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
--OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
--EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
--PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
--PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
--LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
--NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
--SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
@
<<*>>=
<<license>>

<<IntervalCategory>>
<<Interval>>
@
\eject
\begin{thebibliography}{99}
\bibitem{1} nothing
\end{thebibliography}
\end{document}
