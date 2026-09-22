# toon_bend — big naturals. NUMERIC_PLAN §1: every quantity of the original that can pass
# Bend's Nat wall (2^48 - 1) is carried here: the u64 decimal significand of a JSON literal
# (S7.21), 53-bit significands and their 106-bit products (S7.20), powers of ten up to
# 10^308 and beyond for long tokens (S7.26, S7.29), declared array lengths and option values
# up to 2^64 - 1 (S7.34, S7.2).
#
# A BigNat is a little-endian list of 16-bit limbs held in U32, with no high zero limb
# (zero is Nil). A product of two limbs plus two carries is at most
# 65535*65535 + 2*65535 = 2^32 - 1, so no U32 operation below ever wraps.
# Recursion depth is the limb count of a number (bounded by the number, never by the
# document), except from_dec, which walks a digit string tail-recursively.
import Base

# S7.21 the last limb is dropped when it is zero, so a number never grows a high zero limb
def cons.last(zero: Bool, x: U32) -> List<&2, U32>:
  match zero:
    case True{}:
      Nil{}
    case False{}:
      x <> Nil{}

# S7.21 put limb x below the (already normalized) higher limbs t
def cons(+x: U32, t: List<&2, U32>) -> List<&2, U32>:
  match t:
    case Nil{}:
      cons.last(U32.is_eq(x, 0), x)
    case Con{h, r}:
      x <> h <> r

# S7.21 normalize a limb list that may carry high zero limbs
def strip(a: List<&2, U32>) -> List<&2, U32>:
  match a:
    case Nil{}:
      Nil{}
    case Con{x, xs}:
      cons(x, strip(xs))

# S7.21 zero test
def is_zero(a: List<&2, U32>) -> Bool:
  match a:
    case Nil{}:
      True{}
    case Con{h, r}:
      False{}

# S7.21 parity (the rounding rule's "ties to even" reads it)
def is_odd(a: List<&2, U32>) -> Bool:
  match a:
    case Nil{}:
      False{}
    case Con{h, r}:
      U32.is_eq((h .&. 1 : U32), 1)

# S7.21 a + b + c, with c a carry of at most 2
def add(a: List<&2, U32>, b: List<&2, U32>, +c: U32) -> List<&2, U32>:
  match a b:
    case Nil{} Nil{}:
      cons(c, Nil{})
    case Con{x, xs} Nil{}:
      +s = (x + c : U32)
      cons((s .&. 65535 : U32), add(xs, Nil{}, (s >> 16n : U32)))
    case Nil{} Con{y, ys}:
      +s = (y + c : U32)
      cons((s .&. 65535 : U32), add(Nil{}, ys, (s >> 16n : U32)))
    case Con{x, xs} Con{y, ys}:
      +s = (x + y + c : U32)
      cons((s .&. 65535 : U32), add(xs, ys, (s >> 16n : U32)))

# S7.21 a - b - w for a >= b + w (w is a borrow of 0 or 1); callers compare first
def sub(a: List<&2, U32>, b: List<&2, U32>, +w: U32) -> List<&2, U32>:
  match a b:
    case Nil{} _:
      Nil{}
    case Con{x, xs} Nil{}:
      +t = (x + 65536 - w : U32)
      cons((t .&. 65535 : U32), sub(xs, Nil{}, (1 - (t >> 16n) : U32)))
    case Con{x, xs} Con{y, ys}:
      +t = (x + 65536 - y - w : U32)
      cons((t .&. 65535 : U32), sub(xs, ys, (1 - (t >> 16n) : U32)))

# S7.21 order of two limbs
def cmp.limb(lt: Bool, gt: Bool) -> Cmp:
  match lt gt:
    case True{} _:
      LT{}
    case False{} True{}:
      GT{}
    case False{} False{}:
      EQ{}

# S7.21 the higher limbs decide; the lower limbs break their tie
def cmp.pick(hi: Cmp, lo: Cmp) -> Cmp:
  match hi:
    case EQ{}:
      lo
    case LT{}:
      LT{}
    case GT{}:
      GT{}

# S7.21 order of two normalized numbers (a longer limb list is larger)
def cmp(a: List<&2, U32>, b: List<&2, U32>) -> Cmp:
  match a b:
    case Nil{} Nil{}:
      EQ{}
    case Nil{} Con{y, ys}:
      LT{}
    case Con{x, xs} Nil{}:
      GT{}
    case Con{+x, xs} Con{+y, ys}:
      cmp.pick(cmp(xs, ys), cmp.limb(U32.is_lt(x, y), U32.is_gt(x, y)))

# S7.21 verdicts over an order
def is_lt.of(c: Cmp) -> Bool:
  match c:
    case LT{}:
      True{}
    case _:
      False{}

# S7.21 verdicts over an order
def is_gt.of(c: Cmp) -> Bool:
  match c:
    case GT{}:
      True{}
    case _:
      False{}

# S7.21 verdicts over an order
def is_eq.of(c: Cmp) -> Bool:
  match c:
    case EQ{}:
      True{}
    case _:
      False{}

# S7.21 a < b
def is_lt(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  is_lt.of(cmp(a, b))

# S7.21 a > b
def is_gt(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  is_gt.of(cmp(a, b))

# S7.21 a == b
def is_eq(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  is_eq.of(cmp(a, b))

# S7.21 a >= b
def is_ge(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  Bool.not(is_lt(a, b))

# S7.21 a <= b
def is_le(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  Bool.not(is_gt(a, b))

# S7.21 a * k + c for a limb-sized k and a carry c below 65536
def mul_small(a: List<&2, U32>, +k: U32, +c: U32) -> List<&2, U32>:
  match a:
    case Nil{}:
      cons(c, Nil{})
    case Con{x, xs}:
      +p = (x * k + c : U32)
      cons((p .&. 65535 : U32), mul_small(xs, k, (p >> 16n : U32)))

# S7.21 t * 65536 (zero stays Nil)
def limb_up(t: List<&2, U32>) -> List<&2, U32>:
  match t:
    case Nil{}:
      Nil{}
    case Con{h, r}:
      0 <> h <> r

# S7.21 schoolbook product
def mul(a: List<&2, U32>, +b: List<&2, U32>) -> List<&2, U32>:
  match a:
    case Nil{}:
      Nil{}
    case Con{x, xs}:
      add(mul_small(b, x, 0), limb_up(mul(xs, b)), 0)

# S7.21 t * 65536^n
def limbs_up(n: Nat, t: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n:
      t
    case 1n+p:
      limbs_up(p, limb_up(t))

# S7.21 a * 2^r + c for r below 16 and c below 2^r
def shl_bits(a: List<&2, U32>, +r: Nat, +c: U32) -> List<&2, U32>:
  match a:
    case Nil{}:
      cons(c, Nil{})
    case Con{x, xs}:
      +p = ((x << r) .|. c : U32)
      cons((p .&. 65535 : U32), shl_bits(xs, r, (p >> 16n : U32)))

# S7.21 a * 2^n
def shl(a: List<&2, U32>, +n: Nat) -> List<&2, U32>:
  limbs_up(Nat.div(n, 16n), shl_bits(a, Nat.mod(n, 16n), 0))

# S7.21 drop n whole limbs; sticky reports whether a dropped limb was nonzero
def limbs_down(n: Nat, a: List<&2, U32>, sticky: Bool) -> List<&2, U32> & Bool:
  match n:
    case 0n:
      (a, sticky)
    case 1n+p:
      match a:
        case Nil{}:
          (Nil{}, sticky)
        case Con{x, xs}:
          limbs_down(p, xs, Bool.or(sticky, Bool.not(U32.is_eq(x, 0))))

# S7.21 floor(a / 2^r) for r below 16
def shr_bits(a: List<&2, U32>, +r: Nat) -> List<&2, U32>:
  match a:
    case Nil{}:
      Nil{}
    case Con{x, Nil{}}:
      cons((x >> r : U32), Nil{})
    case Con{x, Con{+y, ys}}:
      cons((((x >> r) .|. (y << Nat.sub(16n, r))) .&. 65535 : U32), shr_bits(y <> ys, r))

# S7.21 whether the low r bits (r below 16) of a are nonzero
def low_nonzero(a: List<&2, U32>, r: Nat) -> Bool:
  match a:
    case Nil{}:
      False{}
    case Con{x, xs}:
      Bool.not(U32.is_eq((x .&. ((1 << r) - 1) : U32), 0))

# S7.21 finish a right shift: the bit part, and its share of the sticky flag
def shr.fin(p: List<&2, U32> & Bool, +r: Nat) -> List<&2, U32> & Bool:
  match p:
    case (+a, sticky):
      (shr_bits(a, r), Bool.or(sticky, low_nonzero(a, r)))

# S7.21 floor(a / 2^n) beside the sticky flag "a dropped bit was nonzero"
def shr(a: List<&2, U32>, +n: Nat) -> List<&2, U32> & Bool:
  shr.fin(limbs_down(Nat.div(n, 16n), a, False{}), Nat.mod(n, 16n))

# S7.21 significant bits of one limb: sixteen steps, one bit counted while x is nonzero
def bits_of_limb(fuel: Nat, +x: U32, acc: Nat) -> Nat:
  match fuel:
    case 0n:
      acc
    case 1n+f:
      bits_of_limb(f, (x >> 1n : U32), Nat.add(acc, Bool.pick(Nat, U32.is_eq(x, 0), 0n, 1n)))

# S7.21 bit length (0 for zero); call with acc = 0n
def bitlen(a: List<&2, U32>, acc: Nat) -> Nat:
  match a:
    case Nil{}:
      0n
    case Con{x, Nil{}}:
      Nat.add(acc, bits_of_limb(16n, x, 0n))
    case Con{x, Con{y, ys}}:
      bitlen(y <> ys, Nat.add(acc, 16n))

# S7.26 acc * 10^k
def pow10(k: Nat, acc: List<&2, U32>) -> List<&2, U32>:
  match k:
    case 0n:
      acc
    case 1n+p:
      pow10(p, mul_small(acc, 10, 0))

# S7.21 the value of a string of ASCII digits appended to acc (acc * 10^len + digits)
def from_dec(s: String, acc: List<&2, U32>) -> List<&2, U32>:
  match s:
    case SNil{}:
      acc
    case SCon{c, rest}:
      from_dec(rest, mul_small(acc, 10, (Char.to_u32(c) - 48 : U32)))

# S7.21 long division state: remainder so far, the shifted divisor, the quotient bits so far
type DivSt is Data:
  DivSt{r: List<&2, U32>, b: List<&2, U32>, q: List<&2, U32>}

# S7.21 one quotient bit: subtract when the shifted divisor fits
def div.pick(ge: Bool, r: List<&2, U32>, +b: List<&2, U32>, q: List<&2, U32>) -> DivSt:
  match ge:
    case True{}:
      DivSt{sub(r, b, 0), shr_bits(b, 1n), shl_bits(q, 1n, 1)}
    case False{}:
      DivSt{r, shr_bits(b, 1n), shl_bits(q, 1n, 0)}

# S7.21 one step of the division
def div.step(st: DivSt) -> DivSt:
  match st:
    case DivSt{+r, +b, q}:
      div.pick(is_ge(r, b), r, b, q)

# S7.21 measure: the number of quotient bits, known before the loop (PROPOSED_ARCHITECTURE §4)
def div.go(fuel: Nat, st: DivSt) -> DivSt:
  match fuel:
    case 0n:
      st
    case 1n+f:
      div.go(f, div.step(st))

# S7.21 floor(a / b) and a mod b for b > 0, one quotient bit per step: DivSt{a mod b, _, a / b}
def divmod(+a: List<&2, U32>, +b: List<&2, U32>) -> DivSt:
  +nbits = Nat.add(Nat.sub(bitlen(a, 0n), bitlen(b, 0n)), 1n)
  div.go(nbits, DivSt{a, shl(b, Nat.sub(nbits, 1n)), Nil{}})

# S7.21 2^64 - 1, the largest value the original's 64-bit accumulators hold
def u64_max() -> List<&2, U32>:
  [65535, 65535, 65535, 65535]

# S7.7 Horner over the limbs from the most significant one: no intermediate exceeds the value itself
# (arguments are evaluated eagerly, so a running power of 65536 would pass Nat's 2^48 wall by itself)
def to_nat.go(hi_first: List<&2, U32>, acc: Nat) -> Nat:
  match hi_first:
    case Nil{}:
      acc
    case Con{x, t}:
      to_nat.go(t, Nat.add(Nat.mul(acc, 65536n), U32.to_nat(x)))

# S7.7 the value of a SMALL big natural as a Nat (the caller bounds it below 2^48)
def to_nat(a: List<&2, U32>) -> Nat:
  to_nat.go(List.reverse(&2, U32, a), 0n)

# ---------------------------------------------------------------- S7.21 fast twin: division by a power of ten
# EXP-003. The spec twin is divmod. floor(floor(a/x)/y) = floor(a/(x*y)), and a mod (x*y) is nonzero
# exactly when a mod x is nonzero or floor(a/x) mod y is: so 10^k is taken as k bits and ceil(k/6)
# single-limb divisors 5^6.

# S7.21 one single-limb division, from the most significant limb down: r < d <= 65535 keeps
# r * 65536 + limb below 2^32
def div_small.go(hi_first: List<&2, U32>, +d: U32, r: U32, acc: List<&2, U32>) -> List<&2, U32> & U32:
  match hi_first:
    case Nil{}:
      (acc, r)
    case Con{x, t}:
      +cur = ((r << 16n) .|. x : U32)
      div_small.go(t, d, U32.mod(cur, d), U32.div(cur, d) <> acc)

# S7.21 a quotient so far and whether any remainder was nonzero
type P5 is Data:
  P5{a: List<&2, U32>, sticky: Bool}

# S7.21 fold one single-limb division into the state
def p5.fold(p: List<&2, U32> & U32, sticky: Bool) -> P5:
  (q, r) = p
  P5{strip(q), Bool.or(sticky, Bool.not(U32.is_eq(r, 0)))}

# S7.21 divide the state by a single limb d > 1
def p5.step(st: P5, d: U32) -> P5:
  match st:
    case P5{a, sticky}:
      p5.fold(div_small.go(List.reverse(&2, U32, a), d, 0, Nil{}), sticky)

# S7.21 divide by 5^k: six factors at a time, then the rest
def div_pow5(k: Nat, st: P5) -> P5:
  match k:
    case 0n:
      st
    case 1n:
      p5.step(st, 5)
    case 2n:
      p5.step(st, 25)
    case 3n:
      p5.step(st, 125)
    case 4n:
      p5.step(st, 625)
    case 5n:
      p5.step(st, 3125)
    case 6n+p:
      div_pow5(p, p5.step(st, 15625))

# S7.21 the shifted-out bits are the first remainder
def p5.of_shift(p: List<&2, U32> & Bool) -> P5:
  (q, sticky) = p
  P5{q, sticky}

# S7.21 floor(a / 10^k) and whether a is not a multiple of 10^k
def div_pow10(a: List<&2, U32>, +k: Nat) -> P5:
  div_pow5(k, p5.of_shift(shr(a, k)))

# S7.21 the spec twin of div_pow10: the restoring division by the big natural 10^k
def div_pow10.spec.of(st: DivSt) -> P5:
  match st:
    case DivSt{r, b, q}:
      P5{q, Bool.not(is_zero(r))}

# S7.21 floor(a / 10^k) and whether a is not a multiple of 10^k, through divmod
def div_pow10.spec(a: List<&2, U32>, k: Nat) -> P5:
  div_pow10.spec.of(divmod(a, pow10(k, [1])))
