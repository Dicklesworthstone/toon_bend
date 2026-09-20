# toon_bend — software binary64. Bend has no f64, and the original holds every number in one
# (S7.20, S7.29). NUMERIC_PLAN: no F32 anywhere; every IEEE operation the original performs is
# "exact rational result, then ONE round-to-nearest-even" (the spec's Notation, part C), over
# big naturals.
#
# A finite value is  man * 2^(tb - 100000)  with man a BigNat of at most 53 bits; tb is a
# biased Nat exponent so that no signed arithmetic is needed; zero is man = Nil; the smallest
# exponent is 2^-1074 (tb = 98926). NaN cannot arise (S4.117).
import Base
import ./bignat.bend as BN

# S7.25 a signed integer as sign and magnitude, for the decimal exponents E10, X, T, k, q
type Int is Data:
  Pos{n: Nat}
  Neg{n: Nat}

# S7.25 x - y as an Int, from the verdict x >= y
def Int.diff.if(ge: Bool, x: Nat, y: Nat) -> Int:
  match ge:
    case True{}:
      Pos{Nat.sub(x, y)}
    case False{}:
      Neg{Nat.sub(y, x)}

# S7.25 x - y as an Int (never Neg{0n})
def Int.diff(+x: Nat, +y: Nat) -> Int:
  Int.diff.if(Nat.is_ge(x, y), x, y)

# S7.25 exact sum (the original's 32-bit saturation is unobservable, S4.109)
def Int.add(a: Int, b: Int) -> Int:
  match a b:
    case Pos{x} Pos{y}:
      Pos{Nat.add(x, y)}
    case Neg{x} Neg{y}:
      Int.diff(0n, Nat.add(x, y))
    case Pos{x} Neg{y}:
      Int.diff(x, y)
    case Neg{x} Pos{y}:
      Int.diff(y, x)

# S7.20 the carrier: a finite value, or an infinity produced by an overflowing operation
type F64 is Data:
  FNum{neg: Bool, tb: Nat, man: List<&2, U32>}
  FInf{neg: Bool}

# S7.20 +0
def zero() -> F64:
  FNum{False{}, 98926n, Nil{}}

# S7.20 2^53
def two53() -> List<&2, U32>:
  [0, 0, 0, 32]

# S7.20 2^52
def two52() -> List<&2, U32>:
  [0, 0, 0, 16]

# S4.113 infinity when the top bit's exponent passes 1023 (tb + bitlen(man) - 1 > 101023)
def overflow.if(inf: Bool, neg: Bool, tb: Nat, man: List<&2, U32>) -> F64:
  match inf:
    case True{}:
      FInf{neg}
    case False{}:
      FNum{neg, tb, man}

# S4.113 the overflow test of every rounding
def overflow(neg: Bool, +tb: Nat, +man: List<&2, U32>) -> F64:
  overflow.if(Nat.is_gt(Nat.add(tb, BN.bitlen(man, 0n)), 101024n), neg, tb, man)

# S4.111 a rounding increment that carried to 2^53 becomes 2^52 one exponent higher
def renorm(carry: Bool, neg: Bool, tb: Nat, man: List<&2, U32>) -> F64:
  match carry:
    case True{}:
      overflow(neg, 1n+tb, two52())
    case False{}:
      overflow(neg, tb, man)

# S4.111 after the increment
def round.up2(neg: Bool, tb: Nat, +man: List<&2, U32>) -> F64:
  renorm(BN.is_eq(man, two53()), neg, tb, man)

# S4.111 apply the rounding decision
def round.up(up: Bool, neg: Bool, tb: Nat, man0: List<&2, U32>) -> F64:
  match up:
    case False{}:
      overflow(neg, tb, man0)
    case True{}:
      round.up2(neg, tb, BN.add(man0, [1], 0))

# S4.111 ties to even: up when the half bit is set and (something lies below it, or the kept part is odd)
def round.b(q: List<&2, U32> & Bool, half: Bool, st: Bool, neg: Bool, tb: Nat) -> F64:
  match q:
    case (+man0, low):
      round.up(Bool.and(half, Bool.or(st, BN.is_odd(man0))), neg, tb, man0)

# S4.111 n1 is the number shifted so that its lowest bit is the half bit
def round.a(p: List<&2, U32> & Bool, sticky: Bool, neg: Bool, tb: Nat) -> F64:
  match p:
    case (+n1, st1):
      round.b(BN.shr(n1, 1n), BN.is_odd(n1), Bool.or(st1, sticky), neg, tb)

# S4.111 exact when the target grid is at or below the number's own unit, else a rounding shift
def round.dir(left: Bool, neg: Bool, n: List<&2, U32>, +e2b: Nat, +tb: Nat, sticky: Bool) -> F64:
  match left:
    case True{}:
      overflow(neg, tb, BN.shl(n, Nat.sub(e2b, tb)))
    case False{}:
      round.a(BN.shr(n, Nat.sub(Nat.sub(tb, e2b), 1n)), sticky, neg, tb)

# S4.111 the target unit: 52 bits below the top bit, but never below 2^-1074 (gradual underflow)
def round.go(zero: Bool, neg: Bool, n: List<&2, U32>, +e2b: Nat, sticky: Bool, len: Nat) -> F64:
  match zero:
    case True{}:
      FNum{neg, 98926n, Nil{}}
    case False{}:
      +tb = Nat.max(Nat.sub(Nat.sub(Nat.add(e2b, len), 1n), 52n), 98926n)
      round.dir(Nat.is_le(tb, e2b), neg, n, e2b, tb, sticky)

# S4.111 RNE of  n * 2^(e2b - 100000)  (plus a nonzero tail below it when sticky): the ONE rounding
# every operation ends with. Callers that pass sticky give n at least 55 bits.
def round(neg: Bool, +n: List<&2, U32>, e2b: Nat, sticky: Bool) -> F64:
  round.go(BN.is_zero(n), neg, n, e2b, sticky, BN.bitlen(n, 0n))

# S4.111 F0 = RNE(S) for a non-negative integer
def from_big(neg: Bool, n: List<&2, U32>) -> F64:
  round(neg, n, 100000n, False{})

# S7.6 a Nat below 2^48 as a BigNat (three limbs)
def big_of_nat(+n: Nat) -> List<&2, U32>:
  +hi = Nat.div(n, 65536n)
  BN.strip([U32.from_nat(Nat.mod(n, 65536n)), U32.from_nat(Nat.mod(hi, 65536n)), U32.from_nat(Nat.div(hi, 65536n))])

# S7.6 an integer count as binary64 (exact below 2^53)
def from_nat(n: Nat) -> F64:
  from_big(False{}, big_of_nat(n))

# S4.113 sign of a product or quotient
def sign.xor(a: Bool, b: Bool) -> Bool:
  match a b:
    case True{} False{}:
      True{}
    case False{} True{}:
      True{}
    case _ _:
      False{}

# S4.113 ONE IEEE multiplication: exact product, one RNE
def mul(a: F64, b: F64) -> F64:
  match a b:
    case FNum{na, ta, ma} FNum{nb, tb, mb}:
      round(sign.xor(na, nb), BN.mul(ma, mb), Nat.sub(Nat.add(ta, tb), 100000n), False{})
    case FInf{na} FNum{nb, tb, mb}:
      FInf{sign.xor(na, nb)}
    case FNum{na, ta, ma} FInf{nb}:
      FInf{sign.xor(na, nb)}
    case FInf{na} FInf{nb}:
      FInf{sign.xor(na, nb)}

# S4.114 the quotient of the shifted dividend, with the remainder as the sticky flag
def div.fin(st: BN.DivSt, neg: Bool, e2b: Nat) -> F64:
  match st:
    case BN.DivSt{r, b, q}:
      round(neg, q, e2b, Bool.not(BN.is_zero(r)))

# S4.114 shift the dividend so that the quotient has at least 56 bits
def div.go(neg: Bool, +ma: List<&2, U32>, ta: Nat, +mb: List<&2, U32>, tb: Nat) -> F64:
  +s = Nat.sub(Nat.add(56n, BN.bitlen(mb, 0n)), BN.bitlen(ma, 0n))
  div.fin(BN.divmod(BN.shl(ma, s), mb), neg, Nat.sub(Nat.add(ta, 100000n), Nat.add(tb, s)))

# S4.114 zero divided by anything is zero
def div.nz(zero: Bool, neg: Bool, ma: List<&2, U32>, ta: Nat, mb: List<&2, U32>, tb: Nat) -> F64:
  match zero:
    case True{}:
      FNum{neg, 98926n, Nil{}}
    case False{}:
      div.go(neg, ma, ta, mb, tb)

# S4.114 ONE IEEE division by a nonzero finite divisor: exact quotient, one RNE, gradual underflow
def div(a: F64, b: F64) -> F64:
  match a b:
    case FNum{na, ta, +ma} FNum{nb, tb, mb}:
      div.nz(BN.is_zero(ma), sign.xor(na, nb), ma, ta, mb, tb)
    case FInf{na} _:
      FInf{na}
    case FNum{na, ta, ma} FInf{nb}:
      FNum{sign.xor(na, nb), 98926n, Nil{}}

# S4.143 d / 10^eabs, correctly rounded: a quotient of at least 56 bits and a sticky remainder
def from_dec.neg(neg: Bool, +d: List<&2, U32>, +m: List<&2, U32>) -> F64:
  +s = Nat.sub(Nat.add(56n, BN.bitlen(m, 0n)), BN.bitlen(d, 0n))
  div.fin(BN.divmod(BN.shl(d, s), m), neg, Nat.sub(100000n, s))

# S4.143 the correctly rounded binary64 of the exact decimal  d * 10^(+-eabs)  (d > 0 is the caller's duty)
def from_dec(eneg: Bool, neg: Bool, d: List<&2, U32>, eabs: Nat) -> F64:
  match eneg:
    case False{}:
      round(neg, BN.mul(d, BN.pow10(eabs, [1])), 100000n, False{})
    case True{}:
      from_dec.neg(neg, d, BN.pow10(eabs, [1]))

# S4.112 the power-of-ten table entry P(k) = RNE(10^k), 0 <= k <= 308
def pow10(k: Nat) -> F64:
  round(False{}, BN.pow10(k, [1]), 100000n, False{})

# S4.117 the sign is applied exactly, after all rounding
def with_sign(neg: Bool, f: F64) -> F64:
  match f:
    case FNum{n, tb, man}:
      FNum{neg, tb, man}
    case FInf{n}:
      FInf{neg}

# S4.117 zero test (either sign)
def is_zero(f: F64) -> Bool:
  match f:
    case FNum{n, tb, man}:
      BN.is_zero(man)
    case FInf{n}:
      False{}

# ---------------------------------------------------------------- S4.101–S4.117 the JSON reader's value rule

# S4.102 1844674407370955161 = (2^64 - 1 - 5) / 10: the fit test's pivot
def serde.lim() -> List<&2, U32>:
  [39321, 39321, 39321, 6553]

# S4.102 a digit d fits unless S > pivot, or S = pivot and d > 5 (that is, S*10 + d > 2^64 - 1)
def serde.fits(c: Cmp, d_gt5: Bool) -> Bool:
  match c:
    case LT{}:
      True{}
    case EQ{}:
      Bool.not(d_gt5)
    case GT{}:
      False{}

# S4.102 the significand so far, a digit count (dropped integer digits, or accepted fraction digits), and
# whether a digit has already failed the fit test
type SAcc is Data:
  SAcc{s: List<&2, U32>, n: Nat, stop: Bool}

# S4.103 integer digits: the first digit that does not fit and EVERY later one are dropped and counted
def serde.int.pick(fits: Bool, s: List<&2, U32>, n: Nat, d: U32) -> SAcc:
  match fits:
    case True{}:
      SAcc{BN.mul_small(s, 10, d), n, False{}}
    case False{}:
      SAcc{s, 1n+n, True{}}

# S4.103 one integer digit
def serde.int.step(st: SAcc, +d: U32) -> SAcc:
  match st:
    case SAcc{s, n, True{}}:
      SAcc{s, 1n+n, True{}}
    case SAcc{+s, n, False{}}:
      serde.int.pick(serde.fits(BN.cmp(s, serde.lim()), U32.is_gt(d, 5)), s, n, d)

# S4.102 the integer digits, left to right
def serde.int(digits: String, st: SAcc) -> SAcc:
  match digits:
    case SNil{}:
      st
    case SCon{c, rest}:
      serde.int(rest, serde.int.step(st, (Char.to_u32(c) - 48 : U32)))

# S4.104 fraction digits: a fitting digit is appended and counted; the first that does not fit ends it
def serde.frac.pick(fits: Bool, s: List<&2, U32>, n: Nat, d: U32) -> SAcc:
  match fits:
    case True{}:
      SAcc{BN.mul_small(s, 10, d), 1n+n, False{}}
    case False{}:
      SAcc{s, n, True{}}

# S4.104 one fraction digit
def serde.frac.step(st: SAcc, +d: U32) -> SAcc:
  match st:
    case SAcc{s, n, True{}}:
      SAcc{s, n, True{}}
    case SAcc{+s, n, False{}}:
      serde.frac.pick(serde.fits(BN.cmp(s, serde.lim()), U32.is_gt(d, 5)), s, n, d)

# S4.104 the fraction digits, left to right (S4.105: they are offered to the fit test even after
# integer digits were dropped, starting from the unchanged S)
def serde.frac(digits: String, st: SAcc) -> SAcc:
  match digits:
    case SNil{}:
      st
    case SCon{c, rest}:
      serde.frac(rest, serde.frac.step(st, (Char.to_u32(c) - 48 : U32)))

# S4.117 a finite result carries the literal's sign, a zero of either sign is +0, an infinite result is
# the "number out of range" verdict (None)
def serde.done(f: F64, neg: Bool) -> Maybe<&2, F64>:
  match f:
    case FInf{n}:
      None{}
    case FNum{n, tb, Nil{}}:
      Some{FNum{False{}, 98926n, Nil{}}}
    case FNum{n, tb, Con{h, t}}:
      Some{FNum{neg, tb, h <> t}}

# S4.115 the state of the T < -308 loop: still dividing, or finished with a result
type Down is Data:
  DGo{f: F64, k: Nat}
  DEnd{r: Maybe<&2, F64>}

# S4.115 one step from the two verdicts "more than 308 remain" and "F is zero"
def serde.down.pick(more: Bool, fzero: Bool, f: F64, +k: Nat, neg: Bool) -> Down:
  match more fzero:
    case False{} _:
      DEnd{serde.done(div(f, pow10(k)), neg)}
    case True{} True{}:
      DEnd{Some{FNum{False{}, 98926n, Nil{}}}}
    case True{} False{}:
      DGo{div(f, pow10(308n)), Nat.sub(k, 308n)}

# S4.115 one step of the loop; a finished state stays finished
def serde.down.step(st: Down, neg: Bool) -> Down:
  match st:
    case DEnd{r}:
      DEnd{r}
    case DGo{+f, +k}:
      serde.down.pick(Nat.is_gt(k, 308n), is_zero(f), f, k, neg)

# S4.115 F0 < 2^64, so two divisions by P(308) always give zero: four steps of fuel cannot run out
# in the dividing state, and if they did the value would be that zero (the spec's own bound)
def serde.down.end(st: Down) -> Maybe<&2, F64>:
  match st:
    case DEnd{r}:
      r
    case DGo{f, k}:
      Some{FNum{False{}, 98926n, Nil{}}}

# S4.115 T < -308: while more than 308 remain, stop with zero when F = 0, else divide by P(308)
def serde.down(fuel: Nat, st: Down, +neg: Bool) -> Maybe<&2, F64>:
  match fuel:
    case 0n:
      serde.down.end(st)
    case 1n+g:
      serde.down(g, serde.down.step(st, neg), neg)

# S4.116 T > 308: zero when F0 = 0, otherwise "number out of range"
def serde.over(fzero: Bool) -> Maybe<&2, F64>:
  match fzero:
    case True{}:
      Some{FNum{False{}, 98926n, Nil{}}}
    case False{}:
      None{}

# S4.113 0 <= T <= 308: one multiplication by P(T); T > 308: S4.116
def serde.up(big: Bool, +f0: F64, k: Nat, neg: Bool) -> Maybe<&2, F64>:
  match big:
    case True{}:
      serde.over(is_zero(f0))
    case False{}:
      serde.done(mul(f0, pow10(k)), neg)

# S4.113–S4.116 the value G(S, T) from F0 = RNE(S) and the total decimal exponent T
def serde.g(neg: Bool, f0: F64, t: Int) -> Maybe<&2, F64>:
  match t:
    case Pos{+k}:
      serde.up(Nat.is_gt(k, 308n), f0, k, neg)
    case Neg{k}:
      serde.down(4n, DGo{f0, k}, neg)

# S4.109 T = E10 + the written exponent, with E10 = dropped integer digits - accepted fraction digits
def serde.finish(a: SAcc, dropped: Nat, neg: Bool, exp: Int) -> Maybe<&2, F64>:
  match a:
    case SAcc{s, accepted, stop}:
      serde.g(neg, from_big(False{}, s), Int.add(Int.diff(dropped, accepted), exp))

# S4.105 the fraction starts from the S the integer part left, whether or not digits were dropped
def serde.frac.start(a: SAcc, fracs: String, neg: Bool, exp: Int) -> Maybe<&2, F64>:
  match a:
    case SAcc{s, dropped, stop}:
      serde.finish(serde.frac(fracs, SAcc{s, 0n, False{}}), dropped, neg, exp)

# S4.101 the binary64 value of a JSON number literal given as its sign, integer digits, fraction digits
# and written exponent (a magnitude the reader has already kept within 2147483647, S4.107);
# None is "number out of range" (S9.200, S9.201)
def serde_value(neg: Bool, ints: String, fracs: String, exp: Int) -> Maybe<&2, F64>:
  serde.frac.start(serde.int(ints, SAcc{Nil{}, 0n, False{}}), fracs, neg, exp)

# ---------------------------------------------------------------- S4.141–S4.144 the value of a TOON number token

# S4.143 the loop of strip_zeros: h is the character before `rest`, zero says whether it is '0'
def strip_zeros.go(rest: String, zero: Bool, h: U32) -> String:
  match rest zero:
    case r False{}:
      SCon{Chr{h}, r}
    case SNil{} True{}:
      SNil{}
    case SCon{Chr{+c}, more} True{}:
      strip_zeros.go(more, U32.is_eq(c, 48), c)

# S4.143 leading zeros carry no value
def strip_zeros(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+c}, rest}:
      strip_zeros.go(rest, U32.is_eq(c, 48), c)

# S4.142 an infinite result makes the token a string (None); S4.144 a zero of either sign is +0
def token.done(f: F64) -> Maybe<&2, F64>:
  match f:
    case FInf{n}:
      None{}
    case FNum{n, tb, Nil{}}:
      Some{FNum{False{}, 98926n, Nil{}}}
    case FNum{n, tb, Con{h, t}}:
      Some{FNum{n, tb, h <> t}}

# S4.143 the exact decimal D * 10^E rounded once
def token.round(neg: Bool, digits: String, e: Int) -> Maybe<&2, F64>:
  match e:
    case Pos{k}:
      token.done(from_dec(False{}, neg, BN.from_dec(digits, Nil{}), k))
    case Neg{k}:
      token.done(from_dec(True{}, neg, BN.from_dec(digits, Nil{}), k))

# S4.142, S4.143 with `lead` = the decimal exponent of the first significant digit + 346 (a Nat):
# above 10^309 the value is infinite and below 10^-345 it is zero, decided without big arithmetic
def token.range(huge: Bool, tiny: Bool, neg: Bool, digits: String, e: Int) -> Maybe<&2, F64>:
  match huge tiny:
    case True{} _:
      None{}
    case False{} True{}:
      Some{FNum{False{}, 98926n, Nil{}}}
    case False{} False{}:
      token.round(neg, digits, e)

# S4.143 lead = nd + E; infinite when lead - 1 > 309, zero when lead - 1 < -345
def token.lead.of(l: Int, neg: Bool, digits: String, e: Int) -> Maybe<&2, F64>:
  match l:
    case Pos{n}:
      token.range(Nat.is_gt(n, 310n), False{}, neg, digits, e)
    case Neg{n}:
      token.range(False{}, Nat.is_gt(n, 344n), neg, digits, e)

# S4.143 position of the first significant digit: nd + E - 1, as an Int
def token.lead(neg: Bool, +digits: String, +e: Int) -> Maybe<&2, F64>:
  token.lead.of(Int.add(Pos{String.length(digits)}, e), neg, digits, e)

# S4.143 no significant digit: the value is zero
def token.nz(digits: String, neg: Bool, e: Int) -> Maybe<&2, F64>:
  match digits:
    case SNil{}:
      Some{FNum{False{}, 98926n, Nil{}}}
    case SCon{c, rest}:
      token.lead(neg, SCon{c, rest}, e)

# S4.143 the correctly rounded value of a numeric token given as its sign, integer digits, fraction
# digits and written exponent; None when the value is not finite (S4.142)
def token_value(neg: Bool, ints: String, +fracs: String, exp: Int) -> Maybe<&2, F64>:
  token.nz(strip_zeros(ints ++ fracs), neg, Int.add(exp, Int.diff(0n, String.length(fracs))))

# ---------------------------------------------------------------- S4.131 shortest round-trip digits
# Free-format generation after Burger and Dybvig over big naturals. The value is r/s, the distances to
# the upper and lower ends of the rounding interval are mp/s and mm/s; digits are taken while the
# remainder is still outside both ends.

# S4.131 generator state: r, s, mp, mm, the digits so far (reversed), and whether generation has ended
type Dg is Data:
  Dg{r: List<&2, U32>, s: List<&2, U32>, mp: List<&2, U32>, mm: List<&2, U32>, ds: List<&2, U32>, done: Bool}

# S4.131 the interval of  man * 2^t : half a unit above; half a unit below, or a quarter when man = 2^52
# and t > -1074 (the lower neighbour of a power of two is half as far away)
def dg.init(pos: Bool, edge: Bool, man: List<&2, U32>, +tb: Nat) -> Dg:
  match pos edge:
    case True{} False{}:
      Dg{BN.shl(man, Nat.sub(tb, 99999n)), [2], BN.shl([1], Nat.sub(tb, 100000n)), BN.shl([1], Nat.sub(tb, 100000n)), Nil{}, False{}}
    case True{} True{}:
      Dg{BN.shl(man, Nat.sub(tb, 99998n)), [4], BN.shl([1], Nat.sub(tb, 99999n)), BN.shl([1], Nat.sub(tb, 100000n)), Nil{}, False{}}
    case False{} False{}:
      Dg{BN.shl(man, 1n), BN.shl([1], Nat.sub(100001n, tb)), [1], [1], Nil{}, False{}}
    case False{} True{}:
      Dg{BN.shl(man, 2n), BN.shl([1], Nat.sub(100002n, tb)), [2], [1], Nil{}, False{}}

# S4.131 scale by 10^|k| so that the first digit is the tenths digit of r/s
def dg.scale(up: Bool, st: Dg, +p: List<&2, U32>) -> Dg:
  match up st:
    case True{} Dg{r, s, mp, mm, ds, done}:
      Dg{r, BN.mul(s, p), mp, mm, ds, done}
    case False{} Dg{r, s, mp, mm, ds, done}:
      Dg{BN.mul(r, p), s, BN.mul(mp, p), BN.mul(mm, p), ds, done}

# S4.131 "reaches the upper end": the end point belongs to the interval exactly when man is even
def dg.high(high_ok: Bool, c: Cmp) -> Bool:
  match high_ok c:
    case _ GT{}:
      True{}
    case True{} EQ{}:
      True{}
    case _ _:
      False{}

# S4.131 "reaches the lower end"
def dg.low(low_ok: Bool, c: Cmp) -> Bool:
  match low_ok c:
    case _ LT{}:
      True{}
    case True{} EQ{}:
      True{}
    case _ _:
      False{}

# S4.131 raise k by one: s * 10
def dg.fix.next(big: Bool, r: List<&2, U32>, s: List<&2, U32>, mp: List<&2, U32>, mm: List<&2, U32>) -> Dg:
  match big:
    case True{}:
      Dg{r, BN.mul_small(s, 10, 0), mp, mm, Nil{}, False{}}
    case False{}:
      Dg{r, s, mp, mm, Nil{}, False{}}

# S7.31 the state beside the biased exponent kb = k + 78913, where the value is 0.d1d2... * 10^k
type DgK is Data:
  DgK{st: Dg, kb: Nat}

# S4.131 the estimate of k is never too high and at most two too low: raise k while the upper end still
# reaches 10^k. Five steps of fuel; a step that does not raise k changes nothing.
def dg.fix(fuel: Nat, st: Dg, +high_ok: Bool, +kb: Nat) -> DgK:
  match fuel:
    case 0n:
      DgK{st, kb}
    case 1n+f:
      match st:
        case Dg{+r, +s, +mp, mm, ds, done}:
          +big = dg.high(high_ok, BN.cmp(BN.add(r, mp, 0), s))
          dg.fix(f, dg.fix.next(big, r, s, mp, mm), high_ok, Nat.add(kb, Bool.pick(Nat, big, 1n, 0n)))

# S4.131 conditional subtraction
def dg.sub_if(ge: Bool, r: List<&2, U32>, s: List<&2, U32>) -> List<&2, U32>:
  match ge:
    case True{}:
      BN.sub(r, s, 0)
    case False{}:
      r

# S4.131 the next digit floor(r/s) by repeated subtraction: ten steps, of which at most nine subtract
def dg.digit(fuel: Nat, +r: List<&2, U32>, +s: List<&2, U32>, d: U32) -> List<&2, U32> & U32:
  match fuel:
    case 0n:
      (r, d)
    case 1n+f:
      +ge = BN.is_ge(r, s)
      dg.digit(f, dg.sub_if(ge, r, s), s, (d + Bool.pick(U32, ge, 1, 0) : U32))

# S4.132, S4.172 both ends reached: the nearer candidate wins (S4.133); on an EXACT tie the TOON printer
# takes the larger magnitude (tie_up) and the JSON printer the even last digit
def dg.tie(c: Cmp, tie_up: Bool, d_odd: Bool) -> Bool:
  match c:
    case GT{}:
      True{}
    case LT{}:
      False{}
    case EQ{}:
      Bool.or(tie_up, d_odd)

# S4.131 emit the digit, or the digit plus one, and say whether generation ends
def dg.emit(tc1: Bool, tc2: Bool, up: Bool, rem: List<&2, U32>, s: List<&2, U32>, mp: List<&2, U32>, mm: List<&2, U32>, +d: U32, ds: List<&2, U32>) -> Dg:
  match tc1 tc2:
    case False{} False{}:
      Dg{rem, s, mp, mm, d <> ds, False{}}
    case True{} False{}:
      Dg{rem, s, mp, mm, d <> ds, True{}}
    case False{} True{}:
      Dg{rem, s, mp, mm, (d + 1 : U32) <> ds, True{}}
    case True{} True{}:
      Dg{rem, s, mp, mm, (d + Bool.pick(U32, up, 1, 0) : U32) <> ds, True{}}

# S4.131 the two termination tests on the new remainder
def dg.step2(p: List<&2, U32> & U32, +s: List<&2, U32>, +mp: List<&2, U32>, +mm: List<&2, U32>, ds: List<&2, U32>, low_ok: Bool, high_ok: Bool, tie_up: Bool) -> Dg:
  match p:
    case (+rem, +d):
      dg.emit(dg.low(low_ok, BN.cmp(rem, mm)), dg.high(high_ok, BN.cmp(BN.add(rem, mp, 0), s)), dg.tie(BN.cmp(BN.shl_bits(rem, 1n, 0), s), tie_up, U32.is_eq((d .&. 1 : U32), 1)), rem, s, mp, mm, d, ds)

# S4.131 one digit; a finished state stays as it is
def dg.step(st: Dg, low_ok: Bool, high_ok: Bool, tie_up: Bool) -> Dg:
  match st:
    case Dg{r, s, mp, mm, ds, True{}}:
      Dg{r, s, mp, mm, ds, True{}}
    case Dg{r, +s, mp, mm, ds, False{}}:
      dg.step2(dg.digit(10n, BN.mul_small(r, 10, 0), s, 0), s, BN.mul_small(mp, 10, 0), BN.mul_small(mm, 10, 0), ds, low_ok, high_ok, tie_up)

# S7.30 at most 17 digits are ever produced; fuel 25
def dg.gen(fuel: Nat, st: Dg, +low_ok: Bool, +high_ok: Bool, +tie_up: Bool) -> Dg:
  match fuel:
    case 0n:
      st
    case 1n+f:
      dg.gen(f, dg.step(st, low_ok, high_ok, tie_up), low_ok, high_ok, tie_up)

# S4.131 the digits d1..dn (each 0..9, no trailing zero) and k as an Int: the value is 0.d1d2...dn * 10^k
type Short is Data:
  Short{digits: List<&2, U32>, k: Int}

# S4.131 collect the result
def dg.finish(st: Dg, +kb: Nat) -> Short:
  match st:
    case Dg{r, s, mp, mm, ds, done}:
      Short{List.reverse(&2, U32, ds), Int.diff(kb, 78913n)}

# S4.131 generate after the fix-up
def dg.run(fixed: DgK, +even: Bool, tie_up: Bool) -> Short:
  match fixed:
    case DgK{st, kb}:
      dg.finish(dg.gen(25n, st, even, even, tie_up), kb)

# S4.131 shortest round-trip digits of  man * 2^(tb - 100000) > 0.  The estimate
# floor((bitlen + t - 1) * 78913 / 2^18) never exceeds k (78913/2^18 is just below log10 2); it is
# formed with the bias 262144, whose product with the ratio is the integer 78913.
def shortest(+man: List<&2, U32>, +tb: Nat, tie_up: Bool) -> Short:
  +even = Bool.not(BN.is_odd(man))
  +kb = Nat.div(Nat.mul(Nat.add(Nat.sub(Nat.add(BN.bitlen(man, 0n), tb), 1n), 162144n), 78913n), 262144n)
  +up = Nat.is_ge(kb, 78913n)
  +p = BN.pow10(Bool.pick(Nat, up, Nat.sub(kb, 78913n), Nat.sub(78913n, kb)), [1])
  dg.run(dg.fix(5n, dg.scale(up, dg.init(Nat.is_ge(tb, 100000n), Bool.and(BN.is_eq(man, two52()), Nat.is_gt(tb, 98926n)), man, tb), p), even, kb), even, tie_up)

# ---------------------------------------------------------------- S5.30–S5.42 the two layouts

# S5.31 digits as text (at most 17 of them)
def digits.text(ds: List<&2, U32>) -> String:
  match ds:
    case Nil{}:
      SNil{}
    case Con{d, rest}:
      SCon{Chr{(d + 48 : U32)}, digits.text(rest)}

# S5.31 (c) and S5.39: 0. then -k zeros then the digits
def plain.small(zeros: Nat, text: String) -> String:
  "0." ++ String.repeat("0", zeros) ++ text

# S5.31 (a) the digits then k - n zeros; (b) the first k digits, a point, the rest. `tail` is "" for
# the TOON layout and ".0" for the JSON layout of an integer value (S5.37)
def plain.big(whole: Bool, +text: String, +k: Nat, n: Nat, tail: String) -> String:
  match whole:
    case True{}:
      text ++ String.repeat("0", Nat.sub(k, n)) ++ tail
    case False{}:
      String.take(text, k) ++ "." ++ String.drop(text, k)

# S5.31 plain decimal notation of digits and k
def plain(ds: List<&2, U32>, k: Int, +n: Nat, tail: String) -> String:
  match k:
    case Neg{z}:
      plain.small(z, digits.text(ds))
    case Pos{0n}:
      plain.small(0n, digits.text(ds))
    case Pos{1n++p}:
      plain.big(Nat.is_ge(1n+p, n), digits.text(ds), 1n+p, n, tail)

# S5.41 a leading minus for a negative value
def signed(neg: Bool, text: String) -> String:
  match neg:
    case True{}:
      "-" ++ text
    case False{}:
      text

# S5.31 TOON layout: never an exponent
def toon.short(sh: Short, neg: Bool) -> String:
  match sh:
    case Short{+ds, k}:
      signed(neg, plain(ds, k, List.length(&2, U32, ds), ""))

# S4.130 the TOON text of a number: 0 for zero, null for a non-finite value, else the shortest digits
# with exact ties going up (S4.132), laid out per S5.31
def show_toon(f: F64) -> String:
  match f:
    case FInf{n}:
      "null"
    case FNum{n, tb, Nil{}}:
      "0"
    case FNum{n, tb, Con{h, t}}:
      toon.short(shortest(h <> t, tb, True{}), n)

# S5.40 d1, then a point and the other digits when there are any
def expo.mant(ds: List<&2, U32>) -> String:
  match ds:
    case Nil{}:
      SNil{}
    case Con{d, Nil{}}:
      SCon{Chr{(d + 48 : U32)}, SNil{}}
    case Con{d, Con{e, rest}}:
      SCon{Chr{(d + 48 : U32)}, SCon{Chr{46}, digits.text(e <> rest)}}

# S5.40 exponent layout: q = k - 1, always signed, never padded
def expo(ds: List<&2, U32>, k: Int) -> String:
  match k:
    case Pos{p}:
      expo.mant(ds) ++ "e+" ++ Nat.show(Nat.sub(p, 1n))
    case Neg{z}:
      expo.mant(ds) ++ "e-" ++ Nat.show(1n+z)

# S4.173 plain decimal when -5 <= q <= 15, that is -4 <= k <= 16
def json.is_plain(k: Int) -> Bool:
  match k:
    case Pos{p}:
      Nat.is_le(p, 16n)
    case Neg{z}:
      Nat.is_le(z, 4n)

# S4.173 layout choice
def json.pick(plain_ok: Bool, ds: List<&2, U32>, k: Int, n: Nat) -> String:
  match plain_ok:
    case True{}:
      plain(ds, k, n, ".0")
    case False{}:
      expo(ds, k)

# S5.36 JSON layout of the shortest digits
def json.short(sh: Short, neg: Bool) -> String:
  match sh:
    case Short{+ds, +k}:
      signed(neg, json.pick(json.is_plain(k), ds, k, List.length(&2, U32, ds)))

# S4.170 the JSON text of a number: 0.0 for zero, null for a non-finite value, else the shortest digits
# with exact ties going to the even digit (S4.172), laid out per S5.37–S5.40
def show_json(f: F64) -> String:
  match f:
    case FInf{n}:
      "null"
    case FNum{n, tb, Nil{}}:
      "0.0"
    case FNum{n, tb, Con{h, t}}:
      json.short(shortest(h <> t, tb, False{}), n)

# ---------------------------------------------------------------- S4.141, S4.161 the two numeric grammars

# S4.141 lexer state. Phases: 0 a digit is required, 1 the integer part is the single digit 0, 2 integer
# digits, 3 after '.', 4 fraction digits, 5 after e/E, 6 after the exponent sign, 7 exponent digits,
# 8 rejected, 9 accepted early (S4.161's leading-zero shortcut). Digits are kept reversed; X saturates
# at 10^9, far past every range decision of S4.142, so a long exponent cannot reach Nat's wall.
# Phases and classes are Nat: a match on U32 literals compiles to a bit tree per arm set (bend #867).
type Lex is Data:
  Lex{ph: Nat, ints: String, fracs: String, eneg: Bool, x: Nat}

# S4.141 character classes: 0 '0', 1 '1'-'9', 2 '.', 3 'e' or 'E', 4 '+', 5 '-', 6 other
def lex.cls(+c: U32) -> Nat:
  Bool.pick(Nat, U32.is_eq(c, 48), 0n, Bool.pick(Nat, Bool.and(U32.is_ge(c, 49), U32.is_le(c, 57)), 1n, Bool.pick(Nat, U32.is_eq(c, 46), 2n, Bool.pick(Nat, Bool.or(U32.is_eq(c, 101), U32.is_eq(c, 69)), 3n, Bool.pick(Nat, U32.is_eq(c, 43), 4n, Bool.pick(Nat, U32.is_eq(c, 45), 5n, 6n))))))

# S4.141 an exponent digit, saturating
def lex.x(x: Nat, d: Nat) -> Nat:
  Nat.min(Nat.add(Nat.mul(x, 10n), d), 1000000000n)

# S4.141 a digit right after a leading zero: the decoder's grammar rejects it; S4.161 accepts at once
def lex.zero_digit(like: Bool, ints: String, fracs: String, eneg: Bool, x: Nat) -> Lex:
  match like:
    case True{}:
      Lex{9n, ints, fracs, eneg, x}
    case False{}:
      Lex{8n, ints, fracs, eneg, x}

# S4.141 the transition table: phase x class
def lex.tr(ph: Nat, k: Nat, +c: U32, like: Bool, ints: String, fracs: String, eneg: Bool, x: Nat) -> Lex:
  match ph k:
    case 0n 0n:
      Lex{1n, SCon{Chr{48}, ints}, fracs, eneg, x}
    case 0n 1n:
      Lex{2n, SCon{Chr{c}, ints}, fracs, eneg, x}
    case 1n 0n:
      lex.zero_digit(like, ints, fracs, eneg, x)
    case 1n 1n:
      lex.zero_digit(like, ints, fracs, eneg, x)
    case 1n 2n:
      Lex{3n, ints, fracs, eneg, x}
    case 1n 3n:
      Lex{5n, ints, fracs, eneg, x}
    case 2n 0n:
      Lex{2n, SCon{Chr{48}, ints}, fracs, eneg, x}
    case 2n 1n:
      Lex{2n, SCon{Chr{c}, ints}, fracs, eneg, x}
    case 2n 2n:
      Lex{3n, ints, fracs, eneg, x}
    case 2n 3n:
      Lex{5n, ints, fracs, eneg, x}
    case 3n 0n:
      Lex{4n, ints, SCon{Chr{48}, fracs}, eneg, x}
    case 3n 1n:
      Lex{4n, ints, SCon{Chr{c}, fracs}, eneg, x}
    case 4n 0n:
      Lex{4n, ints, SCon{Chr{48}, fracs}, eneg, x}
    case 4n 1n:
      Lex{4n, ints, SCon{Chr{c}, fracs}, eneg, x}
    case 4n 3n:
      Lex{5n, ints, fracs, eneg, x}
    case 5n 4n:
      Lex{6n, ints, fracs, False{}, x}
    case 5n 5n:
      Lex{6n, ints, fracs, True{}, x}
    case 5n 0n:
      Lex{7n, ints, fracs, eneg, 0n}
    case 5n 1n:
      Lex{7n, ints, fracs, eneg, U32.to_nat((c - 48 : U32))}
    case 6n 0n:
      Lex{7n, ints, fracs, eneg, 0n}
    case 6n 1n:
      Lex{7n, ints, fracs, eneg, U32.to_nat((c - 48 : U32))}
    case 7n 0n:
      Lex{7n, ints, fracs, eneg, lex.x(x, 0n)}
    case 7n 1n:
      Lex{7n, ints, fracs, eneg, lex.x(x, U32.to_nat((c - 48 : U32)))}
    case 9n _:
      Lex{9n, ints, fracs, eneg, x}
    case _ _:
      Lex{8n, ints, fracs, eneg, x}

# S4.141 one character
def lex.step(st: Lex, +c: U32, like: Bool) -> Lex:
  match st:
    case Lex{ph, ints, fracs, eneg, x}:
      lex.tr(ph, lex.cls(c), c, like, ints, fracs, eneg, x)

# S4.141 the whole text through the lexer (a loop over the text)
def lex.go(s: String, st: Lex, +like: Bool) -> Lex:
  match s:
    case SNil{}:
      st
    case SCon{Chr{c}, rest}:
      lex.go(rest, lex.step(st, c, like), like)

# S4.141 the text matched completely when the lexer ends in phase 1, 2, 4, 7 (or 9)
def lex.ok(ph: Nat) -> Bool:
  match ph:
    case 1n:
      True{}
    case 2n:
      True{}
    case 4n:
      True{}
    case 7n:
      True{}
    case 9n:
      True{}
    case _:
      False{}

# S4.161 numeric-like: optional '-', digits with the leading-zero shortcut, optional fraction and exponent
def is_like.body(st: Lex) -> Bool:
  match st:
    case Lex{ph, ints, fracs, eneg, x}:
      lex.ok(ph)

# S4.141 a leading '-' is outside the lexer: run it over the rest, or over the whole text
def lex.run(dash: Bool, c: U32, rest: String, like: Bool) -> Lex:
  match dash:
    case True{}:
      lex.go(rest, Lex{0n, SNil{}, SNil{}, False{}, 0n}, like)
    case False{}:
      lex.go(SCon{Chr{c}, rest}, Lex{0n, SNil{}, SNil{}, False{}, 0n}, like)

# S4.161 whether a string is numeric-like (the encoder then quotes it, S4.160)
def is_like(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, rest}:
      is_like.body(lex.run(U32.is_eq(c, 45), c, rest, True{}))

# S4.109 the written exponent as an Int
def lex.exp(eneg: Bool, x: Nat) -> Int:
  match eneg:
    case True{}:
      Int.diff(0n, x)
    case False{}:
      Pos{x}

# S4.142 a token that matches the grammar is a number only when its value is finite
def literal.value(ok: Bool, neg: Bool, ints: String, fracs: String, eneg: Bool, x: Nat) -> Maybe<&2, F64>:
  match ok:
    case False{}:
      None{}
    case True{}:
      token_value(neg, String.reverse(ints), String.reverse(fracs), lex.exp(eneg, x))

# S4.141 the grammar's verdict and the pieces it collected
def literal.body(st: Lex, neg: Bool) -> Maybe<&2, F64>:
  match st:
    case Lex{ph, ints, fracs, eneg, x}:
      literal.value(lex.ok(ph), neg, ints, fracs, eneg, x)

# S4.141–S4.144 the number a (trimmed) TOON token denotes, or None when the token is not a finite
# numeric literal and therefore a string
def literal(s: String) -> Maybe<&2, F64>:
  match s:
    case SNil{}:
      None{}
    case SCon{Chr{+c}, rest}:
      literal.body(lex.run(U32.is_eq(c, 45), c, rest, False{}), U32.is_eq(c, 45))

# ---------------------------------------------------------------- S1.74, S4.315, S4.316 the CLI's binary64 arithmetic

# S1.74 both significands brought to the smaller exponent (exact)
def align.a(ma: List<&2, U32>, +ta: Nat, tb: Nat) -> List<&2, U32>:
  BN.shl(ma, Nat.sub(ta, Nat.min(ta, tb)))

# S1.74 ONE IEEE addition of two non-negative finite values: exact sum, one RNE
def add(a: F64, b: F64) -> F64:
  match a b:
    case FNum{na, +ta, ma} FNum{nb, +tb, mb}:
      round(False{}, BN.add(align.a(ma, ta, tb), align.a(mb, tb, ta), 0), Nat.min(ta, tb), False{})
    case _ _:
      FInf{False{}}

# S1.75 exact order of two non-negative finite values
def cmp(a: F64, b: F64) -> Cmp:
  match a b:
    case FNum{na, +ta, ma} FNum{nb, +tb, mb}:
      BN.cmp(align.a(ma, ta, tb), align.a(mb, tb, ta))
    case FInf{na} FNum{nb, tb, mb}:
      GT{}
    case FNum{na, ta, ma} FInf{nb}:
      LT{}
    case FInf{na} FInf{nb}:
      EQ{}

# S4.316 the shifted value without its sticky flag
def fixed1.fst(p: List<&2, U32> & Bool) -> List<&2, U32>:
  (q, s) = p
  q

# S4.316 drop the half bit
def fixed1.half(r1: List<&2, U32>) -> List<&2, U32>:
  fixed1.fst(BN.shr(r1, 1n))

# S4.316 round up by one
def fixed1.up(up: Bool, q: List<&2, U32>) -> List<&2, U32>:
  match up:
    case True{}:
      BN.add(q, [1], 0)
    case False{}:
      q

# S4.316 ten times the significand, scaled to an integer with round-half-to-even on the EXACT value:
# with a negative binary exponent -k, the bits below the half bit are the sticky flag
def fixed1.round(p: List<&2, U32> & Bool) -> List<&2, U32>:
  (+r1, s1) = p
  fixed1.up(Bool.and(BN.is_odd(r1), Bool.or(s1, BN.is_odd(fixed1.half(r1)))), fixed1.half(r1))

# S4.316 the text of a small non-negative count of tenths: integer part, '.', one digit
def fixed1.text(+n: Nat) -> String:
  Nat.show(Nat.div(n, 10n)) ++ "." ++ Nat.show(Nat.mod(n, 10n))

# S4.316 the count of tenths of man10 * 2^(tb - 100000)
def fixed1.tenths(int: Bool, man10: List<&2, U32>, +tb: Nat) -> List<&2, U32>:
  match int:
    case True{}:
      BN.shl(man10, Nat.sub(tb, 100000n))
    case False{}:
      fixed1.round(BN.shr(man10, Nat.sub(Nat.sub(100000n, tb), 1n)))

# S4.316 `{:.1}` of a non-negative finite value below 2^44: at least one integer digit, exactly one
# fractional digit, no exponent
def fixed1(f: F64) -> String:
  match f:
    case FNum{neg, +tb, man}:
      fixed1.text(BN.to_nat(fixed1.tenths(Nat.is_ge(tb, 100000n), BN.mul_small(man, 10, 0), tb)))
    case FInf{neg}:
      "inf"
