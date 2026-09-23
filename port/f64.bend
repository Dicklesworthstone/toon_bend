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
import ./text.bend as T

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

# ---------------------------------------------------------------- S8.2, S4.114 the twin gate and ONE division by 10^k

# S8.2 THE gate of every numeric fast twin: a fast twin is selected only when the kill-switch is off
# AND its own applicability verdict holds. Law twin_gate_switch: twin.on(True, ok) == False for every ok.
def twin.on(spec: Bool, ok: Bool) -> Bool:
  match spec:
    case True{}:
      False{}
    case False{}:
      ok

# S4.114 the fast twin's quotient: the dividend shifted so that at least 56 quotient bits remain
# (10^k has fewer than 4k + 1 bits), divided by 10^k exactly, remainder folded into the sticky flag
def div_p10.fin(st: BN.P5, neg: Bool, e2b: Nat) -> F64:
  match st:
    case BN.P5{q, sticky}:
      round(neg, q, e2b, sticky)

# S4.114 the fast twin of div(f, pow10(k)) for k <= 22, where the table entry IS 10^k: exact quotient
# of the significand by 10^k, one RNE. EXP-003.
def div_p10.go(neg: Bool, +ma: List<&2, U32>, +ta: Nat, +k: Nat) -> F64:
  +s = Nat.sub(Nat.add(57n, Nat.mul(4n, k)), BN.bitlen(ma, 0n))
  div_p10.fin(BN.div_pow10(BN.shl(ma, s), k), neg, Nat.sub(ta, s))

# S4.114 the gate selects the fast quotient
def div_p10.pick(fast: Bool, neg: Bool, ma: List<&2, U32>, ta: Nat, +k: Nat) -> F64:
  match fast:
    case True{}:
      div_p10.go(neg, ma, ta, k)
    case False{}:
      div(FNum{neg, ta, ma}, pow10(k))

# S4.114 ONE IEEE division by the table entry P(k): the spec twin is div(f, pow10(k)); the fast twin
# applies to a nonzero finite f and k <= 22 (where the table entry IS 10^k), through the gate
def div_p10(f: F64, +k: Nat, spec: Bool) -> F64:
  match f:
    case FNum{neg, ta, Con{h, t}}:
      div_p10.pick(twin.on(spec, Nat.is_le(k, 22n)), neg, h <> t, ta, k)
    case other:
      div(other, pow10(k))

# ---------------------------------------------------------------- S4.141–S4.144 the value of a TOON number token

# ---------------------------------------------------------------- S4.101, S4.143 fast twin: short integer texts
# EXP-002. A number text with no fraction digit, a written exponent of 0 and at most 14 integer digits
# denotes an integer below 10^14 < 2^48 exactly (a Nat ends at 2^48 - 1 = 281474976710655, so 15 digits
# do not fit: the corpus case encnum_ints holds 281474976710656): both readers (S4.101: F0 = RNE(S), no scaling;
# S4.143: the exact decimal rounded once) return that integer, so it is built from a Nat. Zero keeps
# the spec twins (the sign rules of S4.118 and S4.144 live there).

# S4.101 whether the written exponent is 0
def exp.is_zero(e: Int) -> Bool:
  match e:
    case Pos{0n}:
      True{}
    case other:
      False{}

# S4.101 whether the short-integer twin applies, before the value is looked at (through the gate)
def int_text.ok(spec: Bool, +ints: String, fracs: String, e: Int) -> Bool:
  twin.on(spec, Bool.and(String.is_empty(fracs), Bool.and(exp.is_zero(e), Nat.is_le(T.str_len(ints, 0n), 14n))))

# S4.101 a non-zero integer below 10^14 with its sign
def int_text.value(v: Nat, neg: Bool) -> Maybe<&2, F64>:
  Some{with_sign(neg, from_nat(v))}

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

# S4.143 the first n characters of a text and the rest (a loop; n descends)
type Take is Data:
  Take{head: String, tail: String}

# S4.143 the loop of take
def take.go(n: Nat, s: String, rev: String) -> Take:
  match n s:
    case 0n rest:
      Take{String.reverse(rev), rest}
    case 1n+p SNil{}:
      Take{String.reverse(rev), SNil{}}
    case 1n+p SCon{c, rest}:
      take.go(p, rest, SCon{c, rev})

# S4.143 the loop of any_nonzero: stops at the first digit that is not '0'
def any_nonzero.go(s: String, hit: Bool) -> Bool:
  match s hit:
    case _ True{}:
      True{}
    case SNil{} False{}:
      False{}
    case SCon{Chr{c}, rest} False{}:
      any_nonzero.go(rest, Bool.not(U32.is_eq(c, 48)))

# S4.143 the significant digits that decide a correctly rounded binary64, and how many digits were
# dropped from the exponent's point of view
type Clamp is Data:
  Clamp{digits: String, dropped: Nat}

# S4.143 no rounding boundary of binary64 (a midpoint of two neighbours, the overflow threshold, half
# of the smallest subnormal) has more than 767 significant decimal digits, so none lies strictly
# between two consecutive 800-digit decimals: when the digits after the first 800 are not all zero, a
# single '1' in place of them rounds exactly like the full text; when they are all zero they only
# scale. This keeps every big natural below 3000 bits whatever the token's length.
def clamp.tail(nonzero: Bool, head: String, +tail: String) -> Clamp:
  match nonzero:
    case True{}:
      Clamp{T.cat([head, "1"]), Nat.sub(T.str_len(tail, 0n), 1n)}
    case False{}:
      Clamp{head, T.str_len(tail, 0n)}

# S4.143 clamp a digit string (no leading zeros) to 800 significant digits
def clamp.of(t: Take) -> Clamp:
  match t:
    case Take{head, SNil{}}:
      Clamp{head, 0n}
    case Take{head, SCon{+c, +rest}}:
      clamp.tail(any_nonzero.go(SCon{c, rest}, False{}), head, SCon{c, rest})

# S4.143 the fast twin of from_dec for a negative decimal exponent: d / 10^eabs as an exact quotient by
# short division (EXP-003); the dividend is shifted so that at least 56 quotient bits remain
def from_dec_p10.go(neg: Bool, +d: List<&2, U32>, +eabs: Nat) -> F64:
  +s = Nat.sub(Nat.add(57n, Nat.mul(4n, eabs)), BN.bitlen(d, 0n))
  div_p10.fin(BN.div_pow10(BN.shl(d, s), eabs), neg, Nat.sub(100000n, s))

# S4.143 the gate selects the short division
def from_dec_p10.pick(fast: Bool, eneg: Bool, neg: Bool, d: List<&2, U32>, eabs: Nat) -> F64:
  match fast:
    case True{}:
      from_dec_p10.go(neg, d, eabs)
    case False{}:
      from_dec(eneg, neg, d, eabs)

# S4.143 the correctly rounded binary64 of d * 10^(+-eabs): the spec twin is from_dec; the fast twin
# applies to a negative decimal exponent, through the gate
def from_dec_p10(+eneg: Bool, neg: Bool, d: List<&2, U32>, eabs: Nat, spec: Bool) -> F64:
  from_dec_p10.pick(twin.on(spec, eneg), eneg, neg, d, eabs)

# S4.143 the exact decimal D * 10^E rounded once
def token.round.e(neg: Bool, digits: String, e: Int, spec: Bool) -> Maybe<&2, F64>:
  match e:
    case Pos{k}:
      token.done(from_dec_p10(False{}, neg, BN.from_dec(digits, Nil{}), k, spec))
    case Neg{k}:
      token.done(from_dec_p10(True{}, neg, BN.from_dec(digits, Nil{}), k, spec))

# S4.143 the clamped digits with the exponent moved by the dropped count
def token.round.c(neg: Bool, c: Clamp, e: Int, spec: Bool) -> Maybe<&2, F64>:
  match c:
    case Clamp{digits, dropped}:
      token.round.e(neg, digits, Int.add(e, Pos{dropped}), spec)

# S4.143 the exact decimal D * 10^E rounded once
def token.round(neg: Bool, digits: String, e: Int, spec: Bool) -> Maybe<&2, F64>:
  token.round.c(neg, clamp.of(take.go(800n, digits, SNil{})), e, spec)

# S4.142, S4.143 with `lead` = the decimal exponent of the first significant digit + 346 (a Nat):
# above 10^309 the value is infinite and below 10^-345 it is zero, decided without big arithmetic
def token.range(huge: Bool, tiny: Bool, neg: Bool, digits: String, e: Int, spec: Bool) -> Maybe<&2, F64>:
  match huge tiny:
    case True{} _:
      None{}
    case False{} True{}:
      Some{FNum{False{}, 98926n, Nil{}}}
    case False{} False{}:
      token.round(neg, digits, e, spec)

# S4.143 lead = nd + E; infinite when lead - 1 > 309, zero when lead - 1 < -345
def token.lead.of(l: Int, neg: Bool, digits: String, e: Int, spec: Bool) -> Maybe<&2, F64>:
  match l:
    case Pos{n}:
      token.range(Nat.is_gt(n, 310n), False{}, neg, digits, e, spec)
    case Neg{n}:
      token.range(False{}, Nat.is_gt(n, 344n), neg, digits, e, spec)

# S4.143 position of the first significant digit: nd + E - 1, as an Int
def token.lead(neg: Bool, +digits: String, +e: Int, spec: Bool) -> Maybe<&2, F64>:
  token.lead.of(Int.add(Pos{T.str_len(digits, 0n)}, e), neg, digits, e, spec)

# S4.143 no significant digit: the value is zero
def token.nz(digits: String, neg: Bool, e: Int, spec: Bool) -> Maybe<&2, F64>:
  match digits:
    case SNil{}:
      Some{FNum{False{}, 98926n, Nil{}}}
    case SCon{c, rest}:
      token.lead(neg, SCon{c, rest}, e, spec)

# S4.143 the literal path of the token reader: the exact decimal, rounded once
def token.literal(neg: Bool, ints: String, +fracs: String, exp: Int, spec: Bool) -> Maybe<&2, F64>:
  token.nz(strip_zeros(T.cat([ints, fracs])), neg, Int.add(exp, Int.diff(0n, T.str_len(fracs, 0n))), spec)

# S4.143 zero keeps the literal path (S4.144); any other short integer text is built from its Nat value
def token.short.value(v: Nat, neg: Bool, ints: String, fracs: String, e: Int) -> Maybe<&2, F64>:
  match v:
    case 0n:
      token.literal(neg, ints, fracs, e, False{})
    case 1n++p:
      int_text.value(1n+p, neg)

# S4.143 the Nat value is only computed for a text the fast twin accepts (at most 14 digits)
def token.short(ok: Bool, neg: Bool, +ints: String, fracs: String, e: Int, spec: Bool) -> Maybe<&2, F64>:
  match ok:
    case False{}:
      token.literal(neg, ints, fracs, e, spec)
    case True{}:
      token.short.value(T.nat_of(ints, 0n), neg, ints, fracs, e)

# S4.143 the correctly rounded value of a numeric token given as its sign, integer digits, fraction
# digits and written exponent; None when the value is not finite (S4.142). spec is the kill-switch.
def token_value(neg: Bool, +ints: String, +fracs: String, +exp: Int, +spec: Bool) -> Maybe<&2, F64>:
  token.short(int_text.ok(spec, ints, fracs, exp), neg, ints, fracs, exp, spec)

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

# S4.131 (fast twin of dg.digit, EXP-006) the corrected estimate: at most one more subtraction
def dg.digit_fast.fix(+r: List<&2, U32>, +s: List<&2, U32>, +d: U32) -> List<&2, U32> & U32:
  +ge = BN.is_ge(r, s)
  (dg.sub_if(ge, r, s), (d + Bool.pick(U32, ge, 1, 0) : U32))

# S4.131 (fast twin of dg.digit, EXP-006) an estimate of 10 or more means the caller's r >= 10 s: the spec
# loop decides that case, so the twin equals the spec twin on every input, not only on the generator's
def dg.digit_fast.fin(ok: Bool, +r: List<&2, U32>, +s: List<&2, U32>, +est: Nat) -> List<&2, U32> & U32:
  match ok:
    case False{}:
      dg.digit(10n, r, s, 0)
    case True{}:
      dg.digit_fast.fix(BN.sub(r, BN.mul_small(s, U32.from_nat(est), 0), 0), s, U32.from_nat(est))

# S4.131 (fast twin of dg.digit, EXP-006) the next digit floor(r/s) from a quotient estimate. With k = n - 2
# limbs dropped (n the limb count of s), S2 = floor(s / B^k) >= 2^16 and R2 = floor(r / B^k): the estimate
# floor(R2 / (S2 + 1)) is never above the digit and at most one below it (error < 11 / S2 < 1); with n <= 2
# nothing is dropped and floor(R2 / S2) is the digit itself. One multiplication, one subtraction and one
# comparison replace up to nine compare-and-subtract rounds.
def dg.digit_fast(+r: List<&2, U32>, +s: List<&2, U32>) -> List<&2, U32> & U32:
  +k = Nat.sub(BN.len(s), 2n)
  +est = Nat.div(BN.to_nat(BN.above(k, r)), Nat.add(BN.to_nat(BN.above(k, s)), Bool.pick(Nat, Nat.is_gt(k, 0n), 1n, 0n)))
  dg.digit_fast.fin(Nat.is_le(est, 9n), r, s, est)

# S4.132, S4.172 both ends reached: the nearer candidate wins (S4.133); on an EXACT tie the even last
# digit wins, in both printers (JavaScript's Number::toString rule)
def dg.tie(c: Cmp, d_odd: Bool) -> Bool:
  match c:
    case GT{}:
      True{}
    case LT{}:
      False{}
    case EQ{}:
      d_odd

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
def dg.step2(p: List<&2, U32> & U32, +s: List<&2, U32>, +mp: List<&2, U32>, +mm: List<&2, U32>, ds: List<&2, U32>, low_ok: Bool, high_ok: Bool) -> Dg:
  match p:
    case (+rem, +d):
      dg.emit(dg.low(low_ok, BN.cmp(rem, mm)), dg.high(high_ok, BN.cmp(BN.add(rem, mp, 0), s)), dg.tie(BN.cmp(BN.shl_bits(rem, 1n, 0), s), U32.is_eq((d .&. 1 : U32), 1)), rem, s, mp, mm, d, ds)

# S4.131 one digit; a finished state stays as it is
def dg.step(st: Dg, low_ok: Bool, high_ok: Bool) -> Dg:
  match st:
    case Dg{r, s, mp, mm, ds, True{}}:
      Dg{r, s, mp, mm, ds, True{}}
    case Dg{r, +s, mp, mm, ds, False{}}:
      dg.step2(dg.digit(10n, BN.mul_small(r, 10, 0), s, 0), s, BN.mul_small(mp, 10, 0), BN.mul_small(mm, 10, 0), ds, low_ok, high_ok)

# S7.30 at most 17 digits are ever produced; fuel 25
def dg.gen(fuel: Nat, st: Dg, +low_ok: Bool, +high_ok: Bool) -> Dg:
  match fuel:
    case 0n:
      st
    case 1n+f:
      dg.gen(f, dg.step(st, low_ok, high_ok), low_ok, high_ok)

# S4.131 (fast twin of dg.step, EXP-006) one digit through the quotient estimate
def dg.step.fast(st: Dg, low_ok: Bool, high_ok: Bool) -> Dg:
  match st:
    case Dg{r, s, mp, mm, ds, True{}}:
      Dg{r, s, mp, mm, ds, True{}}
    case Dg{r, +s, mp, mm, ds, False{}}:
      dg.step2(dg.digit_fast(BN.mul_small(r, 10, 0), s), s, BN.mul_small(mp, 10, 0), BN.mul_small(mm, 10, 0), ds, low_ok, high_ok)

# S4.131 the digit step the gate selects (fast only when F.twin.on said so)
def dg.step.with(fast: Bool, st: Dg, low_ok: Bool, high_ok: Bool) -> Dg:
  match fast:
    case False{}:
      dg.step(st, low_ok, high_ok)
    case True{}:
      dg.step.fast(st, low_ok, high_ok)

# S7.30 dg.gen with the digit step chosen by the gate
def dg.gen.with(fuel: Nat, st: Dg, +low_ok: Bool, +high_ok: Bool, +fast: Bool) -> Dg:
  match fuel:
    case 0n:
      st
    case 1n+f:
      dg.gen.with(f, dg.step.with(fast, st, low_ok, high_ok), low_ok, high_ok, fast)

# S4.131 the digits d1..dn (each 0..9, no trailing zero) and k as an Int: the value is 0.d1d2...dn * 10^k
type Short is Data:
  Short{digits: List<&2, U32>, k: Int}

# S4.131 collect the result
def dg.finish(st: Dg, +kb: Nat) -> Short:
  match st:
    case Dg{r, s, mp, mm, ds, done}:
      Short{List.reverse(&2, U32, ds), Int.diff(kb, 78913n)}

# ---------------------------------------------------------------- S4.131 fast twin: the digit loop in words
# EXP-012. When r, s, mp and mm are all below 2^64 after the fix-up, every value the loop forms stays
# below 10s < 2^68: rem < s after each digit, and mp, mm <= s before each step (otherwise the previous
# step's tests would have ended generation). Each value is then three 24-bit words x2 * 2^48 + x1 * 2^24 + x0
# in U32 (x2 < 2^20), so every product by a digit fits 32 bits, and the loop keeps all of them in scalar
# arguments: one digit allocates nothing but itself. U32, not Nat: the checker evaluates U32 words natively
# and Nat values of 2^24 scale in unary (a closed law over Nat words did not finish in 22 GB).

# S4.131 (EXP-012) the word mask 2^24 - 1
def dgw.m() -> U32:
  16777215

# S4.131 (EXP-012) the first limb of a big natural, or 0
def dgw.head(a: List<&2, U32>) -> U32:
  match a:
    case Nil{}:
      0
    case Con{x, t}:
      x

# S4.131 (EXP-012) the low word of a big natural below 2^64: limb 0 and the low byte of limb 1
def dgw.w0(+a: List<&2, U32>) -> U32:
  (dgw.head(a) .|. ((dgw.head(BN.above(1n, a)) .&. 255) << 16n) : U32)

# S4.131 (EXP-012) the middle word: the high byte of limb 1 and limb 2
def dgw.w1(+a: List<&2, U32>) -> U32:
  ((dgw.head(BN.above(1n, a)) >> 8n) .|. (dgw.head(BN.above(2n, a)) << 8n) : U32)

# S4.131 (EXP-012) the high word: limb 3
def dgw.w2(+a: List<&2, U32>) -> U32:
  dgw.head(BN.above(3n, a))

# S4.131 (EXP-012) compare two word triples: the higher words decide unless equal
def dgw.cmp(+a2: U32, +a1: U32, +a0: U32, +b2: U32, +b1: U32, +b0: U32) -> Cmp:
  BN.cmp.pick(BN.cmp.limb(U32.is_lt(a2, b2), U32.is_gt(a2, b2)), BN.cmp.pick(BN.cmp.limb(U32.is_lt(a1, b1), U32.is_gt(a1, b1)), BN.cmp.limb(U32.is_lt(a0, b0), U32.is_gt(a0, b0))))

# S4.131 (EXP-012) the carry out of the low word of a * k (k <= 10)
def dgw.mc0(+a0: U32, +k: U32) -> U32:
  ((a0 * k) >> 24n : U32)

# S4.131 (EXP-012) the carry out of the middle word of a * k
def dgw.mc1(+a1: U32, +a0: U32, +k: U32) -> U32:
  (((a1 * k) + dgw.mc0(a0, k)) >> 24n : U32)

# S4.131 (EXP-012) the words of a * k
def dgw.mo0(+a0: U32, +k: U32) -> U32:
  ((a0 * k) .&. dgw.m() : U32)

# S4.131 (EXP-012)
def dgw.mo1(+a1: U32, +a0: U32, +k: U32) -> U32:
  (((a1 * k) + dgw.mc0(a0, k)) .&. dgw.m() : U32)

# S4.131 (EXP-012)
def dgw.mo2(+a2: U32, +a1: U32, +a0: U32, +k: U32) -> U32:
  ((a2 * k) + dgw.mc1(a1, a0, k) : U32)

# S4.131 (EXP-012) the carries and words of a + b
def dgw.ac0(+a0: U32, +b0: U32) -> U32:
  ((a0 + b0) >> 24n : U32)

# S4.131 (EXP-012)
def dgw.ac1(+a1: U32, +a0: U32, +b1: U32, +b0: U32) -> U32:
  (((a1 + b1) + dgw.ac0(a0, b0)) >> 24n : U32)

# S4.131 (EXP-012)
def dgw.ao0(+a0: U32, +b0: U32) -> U32:
  ((a0 + b0) .&. dgw.m() : U32)

# S4.131 (EXP-012)
def dgw.ao1(+a1: U32, +a0: U32, +b1: U32, +b0: U32) -> U32:
  (((a1 + b1) + dgw.ac0(a0, b0)) .&. dgw.m() : U32)

# S4.131 (EXP-012)
def dgw.ao2(+a2: U32, +a1: U32, +a0: U32, +b2: U32, +b1: U32, +b0: U32) -> U32:
  ((a2 + b2) + dgw.ac1(a1, a0, b1, b0) : U32)

# S4.131 (EXP-012) the borrows and words of a - b, for a >= b: a word adds 2^24 before it subtracts, and
# bit 24 of the result is 1 exactly when no borrow was taken
def dgw.sb0(+a0: U32, +b0: U32) -> U32:
  (1 - (((a0 + 16777216) - b0) >> 24n) : U32)

# S4.131 (EXP-012)
def dgw.sb1(+a1: U32, +a0: U32, +b1: U32, +b0: U32) -> U32:
  (1 - ((((a1 + 16777216) - b1) - dgw.sb0(a0, b0)) >> 24n) : U32)

# S4.131 (EXP-012)
def dgw.so0(+a0: U32, +b0: U32) -> U32:
  (((a0 + 16777216) - b0) .&. dgw.m() : U32)

# S4.131 (EXP-012)
def dgw.so1(+a1: U32, +a0: U32, +b1: U32, +b0: U32) -> U32:
  ((((a1 + 16777216) - b1) - dgw.sb0(a0, b0)) .&. dgw.m() : U32)

# S4.131 (EXP-012)
def dgw.so2(+a2: U32, +a1: U32, +a0: U32, +b2: U32, +b1: U32, +b0: U32) -> U32:
  ((a2 - b2) - dgw.sb1(a1, a0, b1, b0) : U32)

# S4.131 (EXP-012) whether a >= b
def dgw.ge(+a2: U32, +a1: U32, +a0: U32, +b2: U32, +b1: U32, +b0: U32) -> Bool:
  Bool.not(BN.is_lt.of(dgw.cmp(a2, a1, a0, b2, b1, b0)))

# S4.131 (EXP-012) floor(r / s) for r < 10 s by repeated subtraction; ge is r >= s for the r given
# (ten rounds of fuel, of which at most nine subtract, as in dg.digit)
def dgw.q(fuel: Nat, ge: Bool, +r2: U32, +r1: U32, +r0: U32, +s2: U32, +s1: U32, +s0: U32, +d: U32) -> U32:
  match fuel ge:
    case _ False{}:
      d
    case 0n True{}:
      d
    case 1n+f True{}:
      +n2 = dgw.so2(r2, r1, r0, s2, s1, s0)
      +n1 = dgw.so1(r1, r0, s1, s0)
      +n0 = dgw.so0(r0, s0)
      dgw.q(f, dgw.ge(n2, n1, n0, s2, s1, s0), n2, n1, n0, s2, s1, s0, (d + 1 : U32))

# S4.131 (EXP-012) emit the digit, or the digit plus one (dg.emit's four cases, digits only)
def dgw.emit(tc1: Bool, tc2: Bool, up: Bool, +d: U32, ds: List<&2, U32>) -> List<&2, U32>:
  match tc1 tc2:
    case False{} False{}:
      d <> ds
    case True{} False{}:
      d <> ds
    case False{} True{}:
      (d + 1 : U32) <> ds
    case True{} True{}:
      (d + Bool.pick(U32, up, 1, 0) : U32) <> ds

# S4.131 (EXP-012) the digit loop of dg.gen over word pairs: done is whether the previous digit ended
# generation (dg.gen's "a finished state stays as it is"); the remainder, mp and mm are multiplied by ten,
# the digit is floor(10r / s), and the same three tests as dg.step2 decide the emitted digit and the end
def dgw.loop(fuel: Nat, done: Bool, +r2: U32, +r1: U32, +r0: U32, +s2: U32, +s1: U32, +s0: U32, +p2: U32, +p1: U32, +p0: U32, +m2: U32, +m1: U32, +m0: U32, ds: List<&2, U32>, +low_ok: Bool, +high_ok: Bool) -> List<&2, U32>:
  match fuel done:
    case _ True{}:
      ds
    case 0n False{}:
      ds
    case 1n+f False{}:
      +x2 = dgw.mo2(r2, r1, r0, 10)
      +x1 = dgw.mo1(r1, r0, 10)
      +x0 = dgw.mo0(r0, 10)
      +q2 = dgw.mo2(p2, p1, p0, 10)
      +q1 = dgw.mo1(p1, p0, 10)
      +q0 = dgw.mo0(p0, 10)
      +n2 = dgw.mo2(m2, m1, m0, 10)
      +n1 = dgw.mo1(m1, m0, 10)
      +n0 = dgw.mo0(m0, 10)
      +d = dgw.q(10n, dgw.ge(x2, x1, x0, s2, s1, s0), x2, x1, x0, s2, s1, s0, 0)
      +t2 = dgw.mo2(s2, s1, s0, d)
      +t1 = dgw.mo1(s1, s0, d)
      +t0 = dgw.mo0(s0, d)
      +e2 = dgw.so2(x2, x1, x0, t2, t1, t0)
      +e1 = dgw.so1(x1, x0, t1, t0)
      +e0 = dgw.so0(x0, t0)
      +tc1 = dg.low(low_ok, dgw.cmp(e2, e1, e0, n2, n1, n0))
      +tc2 = dg.high(high_ok, dgw.cmp(dgw.ao2(e2, e1, e0, q2, q1, q0), dgw.ao1(e1, e0, q1, q0), dgw.ao0(e0, q0), s2, s1, s0))
      +up = dg.tie(dgw.cmp(dgw.mo2(e2, e1, e0, 2), dgw.mo1(e1, e0, 2), dgw.mo0(e0, 2), s2, s1, s0), U32.is_eq((d .&. 1 : U32), 1))
      dgw.loop(f, Bool.or(tc1, tc2), e2, e1, e0, s2, s1, s0, q2, q1, q0, n2, n1, n0, dgw.emit(tc1, tc2, up, d, ds), low_ok, high_ok)

# S4.131 (EXP-012) the fixed state fits the words: r, s, mp and mm all below 2^64
def dgw.fits(st: Dg) -> Bool:
  match st:
    case Dg{r, s, mp, mm, ds, done}:
      Bool.and(Bool.and(Nat.is_le(BN.bitlen(r, 0n), 64n), Nat.is_le(BN.bitlen(s, 0n), 64n)), Bool.and(Nat.is_le(BN.bitlen(mp, 0n), 64n), Nat.is_le(BN.bitlen(mm, 0n), 64n)))

# S4.131 (EXP-012) the digit loop over words, from the fixed state (25 digits of fuel, as dg.gen)
def dgw.run(st: Dg, +even: Bool) -> List<&2, U32>:
  match st:
    case Dg{+r, +s, +mp, +mm, ds, done}:
      dgw.loop(25n, done, dgw.w2(r), dgw.w1(r), dgw.w0(r), dgw.w2(s), dgw.w1(s), dgw.w0(s), dgw.w2(mp), dgw.w1(mp), dgw.w0(mp), dgw.w2(mm), dgw.w1(mm), dgw.w0(mm), ds, even, even)

# S4.131 generate after the fix-up
def dg.run(fixed: DgK, +even: Bool) -> Short:
  match fixed:
    case DgK{st, kb}:
      dg.finish(dg.gen(25n, st, even, even), kb)

# S4.131 (EXP-012) the digit loop over words when the gate is open and the state fits, else dg.gen.with
def dg.run.words(words: Bool, st: Dg, +kb: Nat, +even: Bool, +fast: Bool) -> Short:
  match words:
    case True{}:
      Short{List.reverse(&2, U32, dgw.run(st, even)), Int.diff(kb, 78913n)}
    case False{}:
      dg.finish(dg.gen.with(25n, st, even, even, fast), kb)

# S4.131 dg.run with the digit step chosen by the gate
def dg.run.with(fixed: DgK, +even: Bool, +fast: Bool) -> Short:
  match fixed:
    case DgK{+st, +kb}:
      dg.run.words(Bool.and(fast, dgw.fits(st)), st, kb, even, fast)

# S4.131 shortest round-trip digits of  man * 2^(tb - 100000) > 0.  The estimate
# floor((bitlen + t - 1) * 78913 / 2^18) never exceeds k (78913/2^18 is just below log10 2); it is
# formed with the bias 262144, whose product with the ratio is the integer 78913.
def shortest(+man: List<&2, U32>, +tb: Nat) -> Short:
  +even = Bool.not(BN.is_odd(man))
  +kb = Nat.div(Nat.mul(Nat.add(Nat.sub(Nat.add(BN.bitlen(man, 0n), tb), 1n), 162144n), 78913n), 262144n)
  +up = Nat.is_ge(kb, 78913n)
  +p = BN.pow10(Bool.pick(Nat, up, Nat.sub(kb, 78913n), Nat.sub(78913n, kb)), [1])
  dg.run(dg.fix(5n, dg.scale(up, dg.init(Nat.is_ge(tb, 100000n), Bool.and(BN.is_eq(man, two52()), Nat.is_gt(tb, 98926n)), man, tb), p), even, kb), even)

# S4.131 shortest with the digit step chosen by the gate (fast = False is shortest itself, line for line)
def shortest.with(+man: List<&2, U32>, +tb: Nat, +fast: Bool) -> Short:
  +even = Bool.not(BN.is_odd(man))
  +kb = Nat.div(Nat.mul(Nat.add(Nat.sub(Nat.add(BN.bitlen(man, 0n), tb), 1n), 162144n), 78913n), 262144n)
  +up = Nat.is_ge(kb, 78913n)
  +p = BN.pow10(Bool.pick(Nat, up, Nat.sub(kb, 78913n), Nat.sub(78913n, kb)), [1])
  dg.run.with(dg.fix(5n, dg.scale(up, dg.init(Nat.is_ge(tb, 100000n), Bool.and(BN.is_eq(man, two52()), Nat.is_gt(tb, 98926n)), man, tb), p), even, kb), even, fast)

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

# S5.31 (a) the digits then k - n zeros (an integer value has no fraction, in both layouts, S5.37);
# (b) the first k digits, a point, the rest
def plain.big(whole: Bool, +text: String, +k: Nat, n: Nat) -> String:
  match whole:
    case True{}:
      text ++ String.repeat("0", Nat.sub(k, n))
    case False{}:
      String.take(text, k) ++ "." ++ String.drop(text, k)

# S5.31 plain decimal notation of digits and k
def plain(ds: List<&2, U32>, k: Int, +n: Nat) -> String:
  match k:
    case Neg{z}:
      plain.small(z, digits.text(ds))
    case Pos{0n}:
      plain.small(0n, digits.text(ds))
    case Pos{1n++p}:
      plain.big(Nat.is_ge(1n+p, n), digits.text(ds), 1n+p, n)

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
      signed(neg, plain(ds, k, List.length(&2, U32, ds)))

# ---------------------------------------------------------------- S4.131 fast twin: integers below 2^48
# EXP-001. The spec twin is shortest. TOON_SPEC=1 selects it everywhere. Laws: shortest_fast_*.

# S4.131 the decimal digits of a Nat, most significant first (at most fuel of them)
def nat.digits(fuel: Nat, n: Nat, acc: List<&2, U32>) -> List<&2, U32>:
  match fuel n:
    case 0n _:
      acc
    case 1n+p 0n:
      acc
    case 1n+p +m:
      nat.digits(p, Nat.div(m, 10n), U32.from_nat(Nat.mod(m, 10n)) <> acc)

# S4.131 whether a digit list starts with 0
def zero_head(ds: List<&2, U32>) -> Bool:
  match ds:
    case Nil{}:
      False{}
    case Con{d, rest}:
      U32.is_eq(d, 0)

# S4.131 the loop of drop_zeros: stops at the first digit that is not 0
def drop_zeros.go(ds: List<&2, U32>, zero: Bool) -> List<&2, U32>:
  match ds zero:
    case Con{d, +rest} True{}:
      drop_zeros.go(rest, zero_head(rest))
    case other _:
      other

# S4.131 drop the leading zeros of a digit list
def drop_zeros(+ds: List<&2, U32>) -> List<&2, U32>:
  drop_zeros.go(ds, zero_head(ds))

# S4.131 the shortest digits of an integer are its own digits without the trailing zeros, and the
# decimal point sits after ALL of its digits
def short.of_digits(+ds: List<&2, U32>) -> Short:
  Short{List.reverse(&2, U32, drop_zeros(List.reverse(&2, U32, ds))), Pos{T.llen(&2, U32, ds, 0n)}}

# S4.131 whether a finite value is an integer below 2^48: a binary exponent in -52..0 whose shifted-out
# bits are all zero, and at most 48 bits left
type IntFit is Data:
  IntFit{ok: Bool, q: List<&2, U32>}

# S4.131 the shifted significand and its verdict
def int.fit.q(p: List<&2, U32> & Bool) -> IntFit:
  (+q, sticky) = p
  IntFit{Bool.and(Bool.not(sticky), Nat.is_le(BN.bitlen(q, 0n), 48n)), q}

# S4.131 only exponents -52..0 can denote such an integer with a 53-bit significand
def int.fit(in_range: Bool, man: List<&2, U32>, tb: Nat) -> IntFit:
  match in_range:
    case False{}:
      IntFit{False{}, Nil{}}
    case True{}:
      int.fit.q(BN.shr(man, Nat.sub(100000n, tb)))

# S4.131 an integer below 2^48 prints its own digits; every other value takes the digit generator, whose
# digit step is the quotient-estimate twin when the gate says so (EXP-006)
def shortest.pick(fit: IntFit, man: List<&2, U32>, tb: Nat, +dfast: Bool) -> Short:
  match fit:
    case IntFit{True{}, q}:
      short.of_digits(nat.digits(16n, BN.to_nat(q), Nil{}))
    case IntFit{False{}, q}:
      shortest.with(man, tb, dfast)

# S4.131 the fast twin of shortest: an integer below 2^48 (a binary exponent in -52..0) through the gate,
# and every other value through the quotient-estimate digit step (EXP-006) through the same gate
def shortest_fast(+man: List<&2, U32>, +tb: Nat, +spec: Bool) -> Short:
  shortest.pick(int.fit(twin.on(spec, Bool.and(Nat.is_le(tb, 100000n), Nat.is_ge(tb, 99948n))), man, tb), man, tb, twin.on(spec, True{}))

# S4.130 the TOON text of a number: 0 for zero, null for a non-finite value, else the shortest digits
# with exact ties going to the even digit (S4.132), laid out per S5.31
def show_toon(f: F64) -> String:
  match f:
    case FInf{n}:
      "null"
    case FNum{n, tb, Nil{}}:
      "0"
    case FNum{n, tb, Con{h, t}}:
      toon.short(shortest(h <> t, tb), n)

# S4.130 the fast twin of show_toon: the same layout over shortest_fast
def show_toon_fast(f: F64, spec: Bool) -> String:
  match f:
    case FInf{n}:
      "null"
    case FNum{n, tb, Nil{}}:
      "0"
    case FNum{n, tb, Con{h, t}}:
      toon.short(shortest_fast(h <> t, tb, spec), n)

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

# S4.173 plain decimal when -5 <= k <= 21 (JavaScript's Number::toString: 1e-6 <= |x| < 1e21)
def json.is_plain(k: Int) -> Bool:
  match k:
    case Pos{p}:
      Nat.is_le(p, 21n)
    case Neg{z}:
      Nat.is_le(z, 5n)

# S4.173 layout choice
def json.pick(plain_ok: Bool, ds: List<&2, U32>, k: Int, n: Nat) -> String:
  match plain_ok:
    case True{}:
      plain(ds, k, n)
    case False{}:
      expo(ds, k)

# S5.36 JSON layout of the shortest digits
def json.short(sh: Short, neg: Bool) -> String:
  match sh:
    case Short{+ds, +k}:
      signed(neg, json.pick(json.is_plain(k), ds, k, List.length(&2, U32, ds)))

# S4.170 the JSON text of a number, as JavaScript's JSON.stringify writes it: 0 for zero, null for a
# non-finite value, else the shortest digits with exact ties going to the even digit (S4.172), laid
# out per S5.37–S5.40
def show_json(f: F64) -> String:
  match f:
    case FInf{n}:
      "null"
    case FNum{n, tb, Nil{}}:
      "0"
    case FNum{n, tb, Con{h, t}}:
      json.short(shortest(h <> t, tb), n)

# S4.170 the fast twin of show_json: the same layout over shortest_fast
def show_json_fast(f: F64, spec: Bool) -> String:
  match f:
    case FInf{n}:
      "null"
    case FNum{n, tb, Nil{}}:
      "0"
    case FNum{n, tb, Con{h, t}}:
      json.short(shortest_fast(h <> t, tb, spec), n)

# ---------------------------------------------------------------- S4.141, S4.161 the two numeric grammars

# S4.141 lexer state. Phases: 0 a digit is required, 1 the integer part is the single digit 0, 2 integer
# digits, 3 after '.', 4 fraction digits, 5 after e/E, 6 after the exponent sign, 7 exponent digits,
# 8 rejected. In the numeric-like grammar (S4.161) a 0 followed by a digit is phase 2 like any other
# digit; the token grammar (S4.141) rejects it. Digits are kept reversed; X saturates
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
def lex.zero_digit(like: Bool, c: U32, ints: String, fracs: String, eneg: Bool, x: Nat) -> Lex:
  match like:
    case True{}:
      Lex{2n, SCon{Chr{c}, ints}, fracs, eneg, x}
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
      lex.zero_digit(like, c, ints, fracs, eneg, x)
    case 1n 1n:
      lex.zero_digit(like, c, ints, fracs, eneg, x)
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

# S4.141 the text matched completely when the lexer ends in phase 1, 2, 4 or 7
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
    case _:
      False{}

# S4.161 numeric-like: optional '-', digits (leading zeros allowed), optional fraction and exponent
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
def literal.value(ok: Bool, neg: Bool, ints: String, fracs: String, eneg: Bool, x: Nat, spec: Bool) -> Maybe<&2, F64>:
  match ok:
    case False{}:
      None{}
    case True{}:
      token_value(neg, String.reverse(ints), String.reverse(fracs), lex.exp(eneg, x), spec)

# S4.141 the grammar's verdict and the pieces it collected
def literal.body(st: Lex, neg: Bool, spec: Bool) -> Maybe<&2, F64>:
  match st:
    case Lex{ph, ints, fracs, eneg, x}:
      literal.value(lex.ok(ph), neg, ints, fracs, eneg, x, spec)

# S4.141–S4.144 the number a (trimmed) TOON token denotes, or None when the token is not a finite
# numeric literal and therefore a string. spec is the numeric kill-switch (TOON_SPEC=1).
def literal(s: String, spec: Bool) -> Maybe<&2, F64>:
  match s:
    case SNil{}:
      None{}
    case SCon{Chr{+c}, rest}:
      literal.body(lex.run(U32.is_eq(c, 45), c, rest, False{}), U32.is_eq(c, 45), spec)

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

# ---------------------------------------------------------------- S7.20 a text form of the exact value, for laws

# S7.20 the limbs of a significand as text, least significant first
def bits.limbs(m: List<&2, U32>, acc: String) -> String:
  match m:
    case Nil{}:
      acc
    case Con{x, t}:
      bits.limbs(t, T.cat([acc, " ", U32.show(x)]))

# S7.20 sign, biased binary exponent and limbs of a value as one text. Two values are the same binary64
# exactly when their texts are equal. Laws compare these texts: the checker cannot compare two biased
# exponents directly (a Nat near 100000 is expanded in unary when two terms are compared).
def bits(f: F64) -> String:
  match f:
    case FInf{neg}:
      Bool.pick(String, neg, "-inf", "inf")
    case FNum{neg, tb, man}:
      T.cat([Bool.pick(String, neg, "-", "+"), Nat.show(tb), ":", bits.limbs(man, SNil{})])

# S7.20 the same for a value that may be absent
def bits.opt(m: Maybe<&2, F64>) -> String:
  match m:
    case None{}:
      "none"
    case Some{f}:
      bits(f)
