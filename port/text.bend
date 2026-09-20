# toon_bend — text primitives shared by every module. NUMERIC_PLAN §6 (the encoding contract):
# input is read as bytes and decoded as STRICT UTF-8 (the original rejects anything else, S2.2);
# White_Space and the control class are hand-written tables because Base's Char tests are ASCII-only
# and the original's are Unicode-aware (S4.8, S2.106, S5.70). Every walk over a text is tail-recursive
# (accumulate reversed, reverse once): the JS and interpreter lanes die near 3*10^4 nested frames.
import Base

# S2.2 strict UTF-8 decoder state: continuation bytes still needed, the value so far, the smallest value
# a sequence of this length may encode (overlong forms fall below it), and the text so far, reversed
type UTF8 is Data:
  Decoding{need: Nat, value: U32, minimum: U32, rev: String}
  Invalid{}

# S2.2 a lead byte: 00-7F alone; C2-DF one continuation; E0-EF two; F0-F4 three; anything else is invalid
def utf8.start(ascii: Bool, two: Bool, three: Bool, four: Bool, +c: U32, rev: String) -> UTF8:
  match ascii two three four:
    case True{} _ _ _:
      Decoding{0n, 0, 0, SCon{Chr{c}, rev}}
    case False{} True{} _ _:
      Decoding{1n, (c .&. 31 : U32), 128, rev}
    case False{} False{} True{} _:
      Decoding{2n, (c .&. 15 : U32), 2048, rev}
    case False{} False{} False{} True{}:
      Decoding{3n, (c .&. 7 : U32), 65536, rev}
    case False{} False{} False{} False{}:
      Invalid{}

# S2.2 a completed sequence must not be overlong, a surrogate (D800-DFFF) or above U+10FFFF
def utf8.scalar(ok: Bool, c: U32, rev: String) -> UTF8:
  match ok:
    case True{}:
      Decoding{0n, 0, 0, SCon{Chr{c}, rev}}
    case False{}:
      Invalid{}

# S2.2 a continuation byte must be 80-BF
def utf8.cont(ok: Bool, need: Nat, +value: U32, minimum: U32, rev: String) -> UTF8:
  match ok:
    case False{}:
      Invalid{}
    case True{}:
      match need:
        case 0n:
          utf8.scalar(Bool.and(U32.is_ge(value, minimum), Bool.and(U32.is_le(value, 1114111), Bool.or(U32.is_lt(value, 55296), U32.is_gt(value, 57343)))), value, rev)
        case 1n+n:
          Decoding{1n+n, value, minimum, rev}

# S2.2 one byte
def utf8.step(st: UTF8, +c: U32) -> UTF8:
  match st:
    case Invalid{}:
      Invalid{}
    case Decoding{0n, v, m, rev}:
      utf8.start(U32.is_lt(c, 128), Bool.and(U32.is_ge(c, 194), U32.is_le(c, 223)), Bool.and(U32.is_ge(c, 224), U32.is_le(c, 239)), Bool.and(U32.is_ge(c, 240), U32.is_le(c, 244)), c, rev)
    case Decoding{1n+n, v, m, rev}:
      utf8.cont(Bool.and(U32.is_ge(c, 128), U32.is_le(c, 191)), n, ((v << 6n) .|. (c .&. 63) : U32), m, rev)

# S2.2 a chunk of bytes through the decoder (the state crosses chunk boundaries)
def utf8.bytes(xs: List<&2, U32>, st: UTF8) -> UTF8:
  match xs:
    case Nil{}:
      st
    case Con{c, rest}:
      utf8.bytes(rest, utf8.step(st, c))

# S2.2 the decoder's start state
def utf8.init() -> UTF8:
  Decoding{0n, 0, 0, SNil{}}

# S2.2 a sequence cut short by the end of input is invalid; the text is still reversed
def utf8.finish(st: UTF8) -> Maybe<&2, String>:
  match st:
    case Decoding{0n, v, m, rev}:
      Some{rev}
    case _:
      None{}

# S7.11 UTF-8 length of one scalar value
def utf8.width(+c: U32) -> Nat:
  Bool.pick(Nat, U32.is_lt(c, 128), 1n, Bool.pick(Nat, U32.is_lt(c, 2048), 2n, Bool.pick(Nat, U32.is_lt(c, 65536), 3n, 4n)))

# S7.11 UTF-8 byte length of a text
def utf8.len(s: String, acc: Nat) -> Nat:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{c}, rest}:
      utf8.len(rest, Nat.add(acc, utf8.width(c)))

# S4.8 the 25 White_Space code points: U+0009-U+000D, U+0020, U+0085, U+00A0, U+1680, U+2000-U+200A,
# U+2028, U+2029, U+202F, U+205F, U+3000 (not U+001C-U+001F, U+180E, U+200B-U+200D, U+2060, U+FEFF)
def is_ws(+c: U32) -> Bool:
  Bool.or(Bool.and(U32.is_ge(c, 9), U32.is_le(c, 13)), Bool.or(U32.is_eq(c, 32), Bool.or(U32.is_eq(c, 133), Bool.or(U32.is_eq(c, 160), Bool.or(U32.is_eq(c, 5760), Bool.or(Bool.and(U32.is_ge(c, 8192), U32.is_le(c, 8202)), Bool.or(U32.is_eq(c, 8232), Bool.or(U32.is_eq(c, 8233), Bool.or(U32.is_eq(c, 8239), Bool.or(U32.is_eq(c, 8287), U32.is_eq(c, 12288)))))))))))

# S5.70 the Unicode control class Cc: U+0000-U+001F and U+007F-U+009F
def is_cc(+c: U32) -> Bool:
  Bool.or(U32.is_le(c, 31), Bool.and(U32.is_ge(c, 127), U32.is_le(c, 159)))

# S4.8 White_Space test on a Char
def is_ws_char(c: Char) -> Bool:
  is_ws(Char.to_u32(c))

# S2.106 whether a text starts with a White_Space character
def head_is_ws(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{c, rest}:
      is_ws_char(c)

# S2.106 the loop of trim_start: `ws` is the verdict for the head of `s`, computed by the caller, so the
# walk stops at the first character that is not White_Space
def trim_start.go(s: String, ws: Bool) -> String:
  match s ws:
    case SCon{c, +rest} True{}:
      trim_start.go(rest, head_is_ws(rest))
    case other _:
      other

# S2.106 drop leading White_Space (Rust's trim_start)
def trim_start(+s: String) -> String:
  trim_start.go(s, head_is_ws(s))

# S2.106 drop trailing White_Space: reverse, drop leading, reverse back (both reversals are loops)
def trim_end(s: String) -> String:
  String.reverse(trim_start(String.reverse(s)))

# S2.106 drop White_Space at both ends (Rust's trim)
def trim(s: String) -> String:
  trim_end(trim_start(s))

# S2.105 a text made only of White_Space (or empty) is blank
def is_blank(s: String) -> Bool:
  String.is_empty(trim_start(s))

# S4.8 whether the first or the last character is White_Space (the text differs from its own trim)
def has_edge_ws(+s: String) -> Bool:
  Bool.or(head_is_ws(s), head_is_ws(String.reverse(s)))

# S6.36 prepend the characters of `s` to `acc` in reverse order: the accumulate step of every builder
def rev_onto(s: String, acc: String) -> String:
  match s:
    case SNil{}:
      acc
    case SCon{c, rest}:
      rev_onto(rest, SCon{c, acc})

# S5.1 n copies of a character prepended to an accumulator (indentation, zero padding)
def pad_onto(n: Nat, +c: Char, acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      pad_onto(p, c, SCon{c, acc})

# S2.121 the loop of has_char: stops at the first hit
def has_char.go(s: String, +k: U32, found: Bool) -> Bool:
  match s found:
    case _ True{}:
      True{}
    case SNil{} False{}:
      False{}
    case SCon{Chr{c}, rest} False{}:
      has_char.go(rest, k, U32.is_eq(c, k))

# S2.121 whether a text contains a given character
def has_char(s: String, k: U32) -> Bool:
  has_char.go(s, k, False{})

# S2.126 whether a text starts with a given character
def head_is(s: String, k: U32) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{c}, rest}:
      U32.is_eq(c, k)

# S2.126 a text cut at the FIRST occurrence of a character: whether it occurs, the text before it (the
# whole text when it does not occur) and the text after it
type Cut is Data:
  Cut{found: Bool, before: String, after: String}

# S2.126 the loop of cut: `hit` is the verdict for the head of `s`, so the walk stops at the first hit
def cut.go(s: String, hit: Bool, +k: U32, rev: String) -> Cut:
  match s hit:
    case SNil{} _:
      Cut{False{}, String.reverse(rev), SNil{}}
    case SCon{c, rest} True{}:
      Cut{True{}, String.reverse(rev), rest}
    case SCon{c, +rest} False{}:
      cut.go(rest, head_is(rest, k), k, SCon{c, rev})

# S2.126 cut a text at the first occurrence of character k (a plain search, no quote awareness)
def cut(+s: String, +k: U32) -> Cut:
  cut.go(s, head_is(s, k), k, SNil{})
