# toon_bend — the JSON value, the JSON reader and the two JSON writers.
#
# ONE self-recursive Data type (PROPOSED_ARCHITECTURE, fact 1): Bend refuses mutually recursive types
# and defs, so the item and entry chains of arrays and objects are constructors of Json itself and
# every traversal is a single structurally recursive def.
#
# The reader is a byte-at-a-time state machine (S2.1: "the parser works on bytes"): every step
# consumes exactly one byte, token states live in the machine's state, and a container is closed
# inside the step that meets its bracket. A sub-lexer that handed "the rest of the input" back to a
# recursive caller would not be a structural recursion. Line and column are byte counts (S2.40).
import Base
import ./f64.bend as F
import ./text.bend as T

# S3.1 a JSON value. S3.2 an object is an ordered chain of (key, value) entries in first-appearance
# order with unique keys; S3.3 an array is an ordered chain of items and carries its item count (S7.35).
# JNil ends both kinds of chain; JCons and JECons never stand for a value on their own. An entry also
# records whether its key was written in quotes in TOON input (S3.26: path expansion asks); the JSON
# reader always records False.
type Json is Data:
  JNull{}
  JBool{b: Bool}
  JNum{f: F.F64}
  JStr{s: String}
  JArr{n: Nat, items: Json}
  JObj{entries: Json}
  JNil{}
  JCons{head: Json, tail: Json}
  JECons{key: String, quoted: Bool, val: Json, tail: Json}

# S6.12 reverse an item chain onto acc (the reader collects items newest first)
def rev_items(c: Json, acc: Json) -> Json:
  match c:
    case JCons{h, t}:
      rev_items(t, JCons{h, acc})
    case other:
      acc

# S6.10 reverse an entry chain onto acc
def rev_entries(c: Json, acc: Json) -> Json:
  match c:
    case JECons{k, q, v, t}:
      rev_entries(t, JECons{k, q, v, acc})
    case other:
      acc

# S2.30 the loop of obj.has: keys are compared after unescaping, as exact scalar sequences
def obj.has.go(c: Json, +k: String, found: Bool) -> Bool:
  match c found:
    case _ True{}:
      True{}
    case JECons{key, q, v, t} False{}:
      obj.has.go(t, k, T.str_eq(key, k))
    case _ False{}:
      False{}

# S2.29 whether an entry chain already holds key k
def obj.has(c: Json, k: String) -> Bool:
  obj.has.go(c, k, False{})

# S2.29 the entry whose key matches takes the new value; every other entry keeps its own
def obj.pick(same: Bool, old: Json, v: Maybe<&2, Json>) -> Json:
  match same v:
    case True{} Some{nv}:
      nv
    case _ _:
      old

# S2.29 once placed, the new value is no longer pending
def obj.rest(same: Bool, v: Maybe<&2, Json>) -> Maybe<&2, Json>:
  match same:
    case True{}:
      None{}
    case False{}:
      v

# S2.29 walk a reversed entry chain, replacing key k's value in place; the result is in FORWARD order
def obj.replace(c: Json, +k: String, +v: Maybe<&2, Json>, acc: Json) -> Json:
  match c:
    case JECons{+key, q, old, t}:
      +same = T.str_eq(key, k)
      obj.replace(t, k, obj.rest(same, v), JECons{key, q, obj.pick(same, old, v), acc})
    case other:
      acc

# S2.29 a repeated key keeps the POSITION of its first appearance and takes the VALUE of its last
def obj.put.if(dup: Bool, rev: Json, k: String, v: Json) -> Json:
  match dup:
    case False{}:
      JECons{k, False{}, v, rev}
    case True{}:
      rev_entries(obj.replace(rev, k, Some{v}, JNil{}), JNil{})

# S2.28 add a member to a reversed entry chain
def obj.put(+rev: Json, +k: String, v: Json) -> Json:
  obj.put.if(obj.has(rev, k), rev, k, v)

# ---------------------------------------------------------------- S2.4–S2.47 the JSON reader

# S2.25, S2.27 an open container: the items or entries read so far (newest first), the item count, and
# for an object the key whose value is awaited
type Frame is Data:
  FArr{rev: Json, n: Nat}
  FObj{rev: Json, key: String}

# S2.8 a number token being read: phase (0 after '-', 1 integer part is 0, 2 integer digits, 3 after '.',
# 4 fraction digits, 5 after e/E, 6 after the exponent sign, 7 exponent digits, 8 skipping the digits of
# an exponent that overflowed harmlessly), sign, integer and fraction digits (reversed), exponent sign
# and magnitude X (S4.107), and whether any mantissa digit is nonzero (S2.14: "S = 0").
# Phases, contexts and byte values that a `match` dispatches on are Nat: a match on U32 literals
# compiles to a 32-level bit tree per arm set (bend #867), a match on Nat literals to a table.
type Num is Data:
  Num{ph: Nat, neg: Bool, ints: String, fracs: String, eneg: Bool, x: Nat, nz: Bool}

# S2.6 what the reader awaits. MVal.ctx: 0 at the root and after ':', 1 right after '[', 2 after ','
# in an array. MStr/MEsc/MHex/MHiBs/MHiU: inside a string (key says whether it is an object key);
# need/part assemble a multi-byte character; MHex counts the four blindly taken bytes of S2.19 and
# `hi` holds a pending high surrogate (0 when none).
type Mode is Data:
  MVal{ctx: Nat}
  MKey{first: Bool}
  MColon{}
  MAfter{}
  MLit{rest: String, val: Json}
  MStr{rev: String, key: Bool, need: Nat, part: U32}
  MEsc{rev: String, key: Bool}
  MHex{rev: String, key: Bool, n: Nat, v: U32, bad: Bool, hi: U32}
  MHiBs{rev: String, key: Bool, hi: U32}
  MHiU{rev: String, key: Bool, hi: U32}
  MNum{num: Num}
  MErr{msg: String, line: Nat, col: Nat}

# S2.40 the whole reader state: mode, open containers, nesting depth (S2.32), and the position
# "L = 1 + LF bytes consumed, C = bytes consumed since the last LF" after the bytes consumed so far
type St is Data:
  St{mode: Mode, stack: List<&2, Frame>, depth: Nat, line: Nat, col: Nat, root: Maybe<&2, Json>}

# S2.45 the first error ends the reading: the error state is sticky
def fail(msg: String, +l: Nat, +c: Nat) -> St:
  St{MErr{msg, l, c}, Nil{}, 0n, l, c, None{}}

# S2.25, S2.27 a finished value goes to the root, to the open array, or under the pending key
def push(v: Json, stack: List<&2, Frame>, depth: Nat, l: Nat, c: Nat, root: Maybe<&2, Json>) -> St:
  match stack:
    case Nil{}:
      St{MAfter{}, Nil{}, depth, l, c, Some{v}}
    case Con{FArr{rev, n}, rest}:
      St{MAfter{}, FArr{JCons{v, rev}, 1n+n} <> rest, depth, l, c, root}
    case Con{FObj{rev, key}, rest}:
      St{MAfter{}, FObj{obj.put(rev, key, v), SNil{}} <> rest, depth, l, c, root}

# S2.25 ']' closes the innermost array (the caller has seen that it is an array)
def close_arr(stack: List<&2, Frame>, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>) -> St:
  match stack:
    case Con{FArr{rev, n}, rest}:
      push(JArr{n, rev_items(rev, JNil{})}, rest, Nat.sub(depth, 1n), l, c, root)
    case other:
      fail("expected value", l, c)

# S2.27 '}' closes the innermost object
def close_obj(stack: List<&2, Frame>, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>) -> St:
  match stack:
    case Con{FObj{rev, key}, rest}:
      push(JObj{rev_entries(rev, JNil{})}, rest, Nat.sub(depth, 1n), l, c, root)
    case other:
      fail("key must be a string", l, c)

# S2.6 the class of an input byte, a SMALL code (a Nat literal pattern costs the checker one successor
# per unit, so bytes are never matched as Nat values): 1 whitespace (space, TAB, LF, CR), 2 ',', 3 ']',
# 4 '}', 5 ':', 6 '"', 7 '[', 8 '{', 9 '-', 10 '0', 11 '1'-'9', 12 'n', 13 't', 14 'f', 15 '\',
# 0 anything else
def byte.cls(+b: U32) -> Nat:
  Bool.pick(Nat, Bool.or(U32.is_eq(b, 32), Bool.or(U32.is_eq(b, 10), Bool.or(U32.is_eq(b, 13), U32.is_eq(b, 9)))), 1n, Bool.pick(Nat, U32.is_eq(b, 44), 2n, Bool.pick(Nat, U32.is_eq(b, 93), 3n, Bool.pick(Nat, U32.is_eq(b, 125), 4n, Bool.pick(Nat, U32.is_eq(b, 58), 5n, Bool.pick(Nat, U32.is_eq(b, 34), 6n, Bool.pick(Nat, U32.is_eq(b, 91), 7n, Bool.pick(Nat, U32.is_eq(b, 123), 8n, Bool.pick(Nat, U32.is_eq(b, 45), 9n, Bool.pick(Nat, U32.is_eq(b, 48), 10n, Bool.pick(Nat, Bool.and(U32.is_ge(b, 49), U32.is_le(b, 57)), 11n, Bool.pick(Nat, U32.is_eq(b, 110), 12n, Bool.pick(Nat, U32.is_eq(b, 116), 13n, Bool.pick(Nat, U32.is_eq(b, 102), 14n, Bool.pick(Nat, U32.is_eq(b, 92), 15n, 0n)))))))))))))))

# S2.18 the escape class of the byte after a backslash: 1 '"', 2 '\', 3 '/', 4 'b', 5 'f', 6 'n',
# 7 'r', 8 't', 9 'u', 0 anything else
def esc.cls(+b: U32) -> Nat:
  Bool.pick(Nat, U32.is_eq(b, 34), 1n, Bool.pick(Nat, U32.is_eq(b, 92), 2n, Bool.pick(Nat, U32.is_eq(b, 47), 3n, Bool.pick(Nat, U32.is_eq(b, 98), 4n, Bool.pick(Nat, U32.is_eq(b, 102), 5n, Bool.pick(Nat, U32.is_eq(b, 110), 6n, Bool.pick(Nat, U32.is_eq(b, 114), 7n, Bool.pick(Nat, U32.is_eq(b, 116), 8n, Bool.pick(Nat, U32.is_eq(b, 117), 9n, 0n)))))))))

# S2.25 after an array element: whitespace, ',' or ']'; anything else is S9.55 (k is the byte class)
def after.arr(k: Nat, rev: Json, n: Nat, rest: List<&2, Frame>, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>) -> St:
  match k:
    case 1n:
      St{MAfter{}, FArr{rev, n} <> rest, depth, l, c, root}
    case 2n:
      St{MVal{2n}, FArr{rev, n} <> rest, depth, l, c, root}
    case 3n:
      push(JArr{n, rev_items(rev, JNil{})}, rest, Nat.sub(depth, 1n), l, c, root)
    case _:
      fail("expected `,` or `]`", l, c)

# S2.27 after an object member: whitespace, ',' or '}'; anything else is S9.56 (k is the byte class)
def after.obj(k: Nat, rev: Json, key: String, rest: List<&2, Frame>, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>) -> St:
  match k:
    case 1n:
      St{MAfter{}, FObj{rev, key} <> rest, depth, l, c, root}
    case 2n:
      St{MKey{False{}}, FObj{rev, key} <> rest, depth, l, c, root}
    case 4n:
      push(JObj{rev_entries(rev, JNil{})}, rest, Nat.sub(depth, 1n), l, c, root)
    case _:
      fail("expected `,` or `}`", l, c)

# S2.4 after the root value only whitespace may follow; anything else is S9.67 (k is the byte class)
def after.root(k: Nat, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>) -> St:
  match k:
    case 1n:
      St{MAfter{}, Nil{}, depth, l, c, root}
    case _:
      fail("trailing characters", l, c)

# S2.13 the byte after a value is judged by the enclosing context (k is the byte class)
def after(stack: List<&2, Frame>, depth: Nat, l: Nat, c: Nat, root: Maybe<&2, Json>, k: Nat) -> St:
  match stack:
    case Nil{}:
      after.root(k, depth, l, c, root)
    case Con{FArr{rev, n}, rest}:
      after.arr(k, rev, n, rest, depth, l, c, root)
    case Con{FObj{rev, key}, rest}:
      after.obj(k, rev, key, rest, depth, l, c, root)

# S2.32 a container at depth 128 is refused when its bracket is met, before anything inside it
def open.if(deep: Bool, arr: Bool, stack: List<&2, Frame>, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>) -> St:
  match deep arr:
    case True{} _:
      fail("recursion limit exceeded", l, c)
    case False{} True{}:
      St{MVal{1n}, FArr{JNil{}, 0n} <> stack, 1n+depth, l, c, root}
    case False{} False{}:
      St{MKey{True{}}, FObj{JNil{}, SNil{}} <> stack, 1n+depth, l, c, root}

# S2.32 open an array or an object
def open(arr: Bool, stack: List<&2, Frame>, +depth: Nat, l: Nat, c: Nat, root: Maybe<&2, Json>) -> St:
  open.if(Nat.is_ge(depth, 127n), arr, stack, depth, l, c, root)

# S2.25 ']' where a value is awaited: the empty array right after '[', `trailing comma` after ','
def value.close(ctx: Nat, stack: List<&2, Frame>, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>) -> St:
  match ctx:
    case 1n:
      close_arr(stack, depth, l, c, root)
    case 2n:
      fail("trailing comma", l, c)
    case _:
      fail("expected value", l, c)

# S2.6 value dispatch on the first byte (k is the class of byte b); a digit 1-9 starts a number and
# every byte without a rule here is S9.58
def value(ctx: Nat, stack: List<&2, Frame>, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>, k: Nat, b: U32) -> St:
  match k:
    case 1n:
      St{MVal{ctx}, stack, depth, l, c, root}
    case 12n:
      St{MLit{"ull", JNull{}}, stack, depth, l, c, root}
    case 13n:
      St{MLit{"rue", JBool{True{}}}, stack, depth, l, c, root}
    case 14n:
      St{MLit{"alse", JBool{False{}}}, stack, depth, l, c, root}
    case 6n:
      St{MStr{SNil{}, False{}, 0n, 0}, stack, depth, l, c, root}
    case 9n:
      St{MNum{Num{0n, True{}, SNil{}, SNil{}, False{}, 0n, False{}}}, stack, depth, l, c, root}
    case 10n:
      St{MNum{Num{1n, False{}, "0", SNil{}, False{}, 0n, False{}}}, stack, depth, l, c, root}
    case 11n:
      St{MNum{Num{2n, False{}, SCon{Chr{b}, SNil{}}, SNil{}, False{}, 0n, True{}}}, stack, depth, l, c, root}
    case 7n:
      open(True{}, stack, depth, l, c, root)
    case 8n:
      open(False{}, stack, depth, l, c, root)
    case 3n:
      value.close(ctx, stack, depth, l, c, root)
    case _:
      fail("expected value", l, c)

# S2.27 '}' where a key is awaited: the empty object right after '{', `trailing comma` after ','
def keymode.close(first: Bool, stack: List<&2, Frame>, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>) -> St:
  match first:
    case True{}:
      close_obj(stack, depth, l, c, root)
    case False{}:
      fail("trailing comma", l, c)

# S2.27 where a key is awaited: whitespace, '"', or '}'; anything else is S9.63 (k is the byte class)
def keymode(first: Bool, stack: List<&2, Frame>, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>, k: Nat) -> St:
  match k:
    case 1n:
      St{MKey{first}, stack, depth, l, c, root}
    case 6n:
      St{MStr{SNil{}, True{}, 0n, 0}, stack, depth, l, c, root}
    case 4n:
      keymode.close(first, stack, depth, l, c, root)
    case _:
      fail("key must be a string", l, c)

# S2.27 where ':' is awaited: whitespace or ':'; anything else is S9.54 (k is the byte class)
def colon(stack: List<&2, Frame>, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>, k: Nat) -> St:
  match k:
    case 1n:
      St{MColon{}, stack, depth, l, c, root}
    case 5n:
      St{MVal{0n}, stack, depth, l, c, root}
    case _:
      fail("expected `:`", l, c)

# S2.7 one byte of a literal: the first differing byte is `expected ident`; nothing is required after it
def lit.cmp(same: Bool, more: String, val: Json, stack: List<&2, Frame>, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>) -> St:
  match same more:
    case False{} _:
      fail("expected ident", l, c)
    case True{} SNil{}:
      push(val, stack, depth, l, c, root)
    case True{} SCon{h, t}:
      St{MLit{SCon{h, t}, val}, stack, depth, l, c, root}

# S2.7 the bytes after the selecting byte must be exactly ull / rue / alse
def lit(rest: String, val: Json, stack: List<&2, Frame>, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>, b: U32) -> St:
  match rest:
    case SNil{}:
      fail("expected ident", l, c)
    case SCon{Chr{e}, more}:
      lit.cmp(U32.is_eq(e, b), more, val, stack, depth, l, c, root)

# S2.15 the closing quote: a key goes to the open object and ':' is awaited; a value is pushed
def str.end(key: Bool, rev: String, stack: List<&2, Frame>, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>) -> St:
  match key stack:
    case False{} _:
      push(JStr{String.reverse(rev)}, stack, depth, l, c, root)
    case True{} Con{FObj{r, old}, rest}:
      St{MColon{}, FObj{r, String.reverse(rev)} <> rest, depth, l, c, root}
    case True{} _:
      fail("key must be a string", l, c)

# S2.15 the first byte of a multi-byte character (the input has passed the UTF-8 gate, S2.2)
def str.lead(+b: U32, rev: String, key: Bool) -> Mode:
  MStr{rev, key, Bool.pick(Nat, U32.is_lt(b, 224), 1n, Bool.pick(Nat, U32.is_lt(b, 240), 2n, 3n)), Bool.pick(U32, U32.is_lt(b, 224), (b .&. 31 : U32), Bool.pick(U32, U32.is_lt(b, 240), (b .&. 15 : U32), (b .&. 7 : U32)))}

# S2.15 a continuation byte; the last one completes the scalar value
def str.cont(need: Nat, +part: U32, rev: String, key: Bool) -> Mode:
  match need:
    case 0n:
      MStr{SCon{Chr{part}, rev}, key, 0n, 0}
    case 1n+m:
      MStr{rev, key, 1n+m, part}

# S2.15, S2.17 one content byte: 00-1F is S9.62; 20-7F is itself; 80-FF assembles a character
def str.byte(ctl: Bool, ascii: Bool, need: Nat, +b: U32, part: U32, rev: String, key: Bool, stack: List<&2, Frame>, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>) -> St:
  match ctl ascii need:
    case True{} _ _:
      fail("control character (\\u0000-\\u001F) found while parsing a string", l, c)
    case False{} True{} _:
      St{MStr{SCon{Chr{b}, rev}, key, 0n, 0}, stack, depth, l, c, root}
    case False{} False{} 0n:
      St{str.lead(b, rev, key), stack, depth, l, c, root}
    case False{} False{} 1n+m:
      St{str.cont(m, ((part << 6n) .|. (b .&. 63) : U32), rev, key), stack, depth, l, c, root}

# S2.15 inside a string (k is the class of byte b)
def str(rev: String, key: Bool, need: Nat, part: U32, stack: List<&2, Frame>, depth: Nat, l: Nat, c: Nat, root: Maybe<&2, Json>, k: Nat, +b: U32) -> St:
  match k:
    case 6n:
      str.end(key, rev, stack, depth, l, c, root)
    case 15n:
      St{MEsc{rev, key}, stack, depth, l, c, root}
    case _:
      str.byte(U32.is_lt(b, 32), U32.is_lt(b, 128), need, b, part, rev, key, stack, depth, l, c, root)

# S2.18 simple escapes (case-sensitive); any other byte is S9.59, reported just after it. e is the
# escape class of the byte: 1 '"', 2 '\', 3 '/', 4 'b', 5 'f', 6 'n', 7 'r', 8 't', 9 'u'
def esc(rev: String, key: Bool, stack: List<&2, Frame>, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>, e: Nat) -> St:
  match e:
    case 1n:
      St{MStr{SCon{Chr{34}, rev}, key, 0n, 0}, stack, depth, l, c, root}
    case 2n:
      St{MStr{SCon{Chr{92}, rev}, key, 0n, 0}, stack, depth, l, c, root}
    case 3n:
      St{MStr{SCon{Chr{47}, rev}, key, 0n, 0}, stack, depth, l, c, root}
    case 4n:
      St{MStr{SCon{Chr{8}, rev}, key, 0n, 0}, stack, depth, l, c, root}
    case 5n:
      St{MStr{SCon{Chr{12}, rev}, key, 0n, 0}, stack, depth, l, c, root}
    case 6n:
      St{MStr{SCon{Chr{10}, rev}, key, 0n, 0}, stack, depth, l, c, root}
    case 7n:
      St{MStr{SCon{Chr{13}, rev}, key, 0n, 0}, stack, depth, l, c, root}
    case 8n:
      St{MStr{SCon{Chr{9}, rev}, key, 0n, 0}, stack, depth, l, c, root}
    case 9n:
      St{MHex{rev, key, 0n, 0, False{}, 0}, stack, depth, l, c, root}
    case _:
      fail("invalid escape", l, c)

# S2.19 the value of a hex digit, or 255 when the byte is not one
def hex.val(+b: U32) -> U32:
  Bool.pick(U32, Bool.and(U32.is_ge(b, 48), U32.is_le(b, 57)), (b - 48 : U32), Bool.pick(U32, Bool.and(U32.is_ge(b, 65), U32.is_le(b, 70)), (b - 55 : U32), Bool.pick(U32, Bool.and(U32.is_ge(b, 97), U32.is_le(b, 102)), (b - 87 : U32), 255)))

# S2.20–S2.24 the four bytes are in: a bad digit is `invalid escape`; a first escape is a scalar, a
# high surrogate awaiting its partner, or a lone low surrogate; a second escape must be a low surrogate
def hex.fin(bad: Bool, first: Bool, low: Bool, high: Bool, +v: U32, hi: U32, rev: String, key: Bool, stack: List<&2, Frame>, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>) -> St:
  match bad first low high:
    case True{} _ _ _:
      fail("invalid escape", l, c)
    case False{} True{} True{} _:
      fail("lone leading surrogate in hex escape", l, c)
    case False{} True{} False{} True{}:
      St{MHiBs{rev, key, v}, stack, depth, l, c, root}
    case False{} True{} False{} False{}:
      St{MStr{SCon{Chr{v}, rev}, key, 0n, 0}, stack, depth, l, c, root}
    case False{} False{} True{} _:
      St{MStr{SCon{Chr{(65536 + ((hi - 55296) << 10n) + (v - 56320) : U32)}, rev}, key, 0n, 0}, stack, depth, l, c, root}
    case False{} False{} False{} _:
      fail("lone leading surrogate in hex escape", l, c)

# S2.19 the four bytes after \u are taken BLINDLY; the verdict comes after the fourth
def hex.go(done: Bool, rev: String, key: Bool, n: Nat, +v: U32, bad: Bool, +hi: U32, stack: List<&2, Frame>, depth: Nat, l: Nat, c: Nat, root: Maybe<&2, Json>) -> St:
  match done:
    case False{}:
      St{MHex{rev, key, n, v, bad, hi}, stack, depth, l, c, root}
    case True{}:
      hex.fin(bad, U32.is_eq(hi, 0), Bool.and(U32.is_ge(v, 56320), U32.is_le(v, 57343)), Bool.and(U32.is_ge(v, 55296), U32.is_le(v, 56319)), v, hi, rev, key, stack, depth, l, c, root)

# S2.19 one of the four bytes
def hex(rev: String, key: Bool, +n: Nat, v: U32, bad: Bool, hi: U32, stack: List<&2, Frame>, depth: Nat, l: Nat, c: Nat, root: Maybe<&2, Json>, b: U32) -> St:
  +d = hex.val(b)
  hex.go(Nat.is_ge(n, 3n), rev, key, 1n+n, ((v << 4n) .|. (d .&. 15) : U32), Bool.or(bad, U32.is_eq(d, 255)), hi, stack, depth, l, c, root)

# S2.23 after a high surrogate the next byte must be a backslash (k is the byte class)
def hibs(rev: String, key: Bool, hi: U32, stack: List<&2, Frame>, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>, k: Nat) -> St:
  match k:
    case 15n:
      St{MHiU{rev, key, hi}, stack, depth, l, c, root}
    case _:
      fail("unexpected end of hex escape", l, c)

# S2.23 and the byte after it must be 'u'
def hiu(rev: String, key: Bool, hi: U32, stack: List<&2, Frame>, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>, u: Bool) -> St:
  match u:
    case True{}:
      St{MHex{rev, key, 0n, 0, False{}, hi}, stack, depth, l, c, root}
    case False{}:
      fail("unexpected end of hex escape", l, c)

# S2.8 byte classes of the number grammar: 0 '0', 1 '1'-'9', 2 '.', 3 'e' or 'E', 4 '+', 5 '-', 6 other
def num.cls(+b: U32) -> Nat:
  Bool.pick(Nat, U32.is_eq(b, 48), 0n, Bool.pick(Nat, Bool.and(U32.is_ge(b, 49), U32.is_le(b, 57)), 1n, Bool.pick(Nat, U32.is_eq(b, 46), 2n, Bool.pick(Nat, Bool.or(U32.is_eq(b, 101), U32.is_eq(b, 69)), 3n, Bool.pick(Nat, U32.is_eq(b, 43), 4n, Bool.pick(Nat, U32.is_eq(b, 45), 5n, 6n))))))

# S2.13 the outcome of one byte inside a number: go on, a lexical error (S9.60), the end of the token
# (the byte belongs to the enclosing context), or the exponent-digit overflow of S2.14 (a)
type NR is Data:
  NGo{num: Num}
  NBad{}
  NEnd{num: Num}
  NRange{}

# S4.107, S2.14 (a) an exponent digit that would take X past 2147483647: harmless when the exponent is
# negative or the mantissa is all zeros (the value is then zero), otherwise `number out of range`
def num.exp(over: Bool, harmless: Bool, neg: Bool, ints: String, fracs: String, eneg: Bool, x: Nat, nz: Bool, d: Nat) -> NR:
  match over harmless:
    case False{} _:
      NGo{Num{7n, neg, ints, fracs, eneg, Nat.add(Nat.mul(x, 10n), d), nz}}
    case True{} True{}:
      NGo{Num{8n, neg, ints, fracs, eneg, x, nz}}
    case True{} False{}:
      NRange{}

# S2.8–S2.12 the transition table: phase x byte class
def num.tr(ph: Nat, k: Nat, +b: U32, neg: Bool, ints: String, fracs: String, +eneg: Bool, +x: Nat, +nz: Bool) -> NR:
  match ph k:
    case 0n 0n:
      NGo{Num{1n, neg, SCon{Chr{48}, ints}, fracs, eneg, x, nz}}
    case 0n 1n:
      NGo{Num{2n, neg, SCon{Chr{b}, ints}, fracs, eneg, x, True{}}}
    case 0n _:
      NBad{}
    case 1n 0n:
      NBad{}
    case 1n 1n:
      NBad{}
    case 1n 2n:
      NGo{Num{3n, neg, ints, fracs, eneg, x, nz}}
    case 1n 3n:
      NGo{Num{5n, neg, ints, fracs, eneg, x, nz}}
    case 1n _:
      NEnd{Num{1n, neg, ints, fracs, eneg, x, nz}}
    case 2n 0n:
      NGo{Num{2n, neg, SCon{Chr{48}, ints}, fracs, eneg, x, nz}}
    case 2n 1n:
      NGo{Num{2n, neg, SCon{Chr{b}, ints}, fracs, eneg, x, True{}}}
    case 2n 2n:
      NGo{Num{3n, neg, ints, fracs, eneg, x, nz}}
    case 2n 3n:
      NGo{Num{5n, neg, ints, fracs, eneg, x, nz}}
    case 2n _:
      NEnd{Num{2n, neg, ints, fracs, eneg, x, nz}}
    case 3n 0n:
      NGo{Num{4n, neg, ints, SCon{Chr{48}, fracs}, eneg, x, nz}}
    case 3n 1n:
      NGo{Num{4n, neg, ints, SCon{Chr{b}, fracs}, eneg, x, True{}}}
    case 3n _:
      NBad{}
    case 4n 0n:
      NGo{Num{4n, neg, ints, SCon{Chr{48}, fracs}, eneg, x, nz}}
    case 4n 1n:
      NGo{Num{4n, neg, ints, SCon{Chr{b}, fracs}, eneg, x, True{}}}
    case 4n 3n:
      NGo{Num{5n, neg, ints, fracs, eneg, x, nz}}
    case 4n _:
      NEnd{Num{4n, neg, ints, fracs, eneg, x, nz}}
    case 5n 4n:
      NGo{Num{6n, neg, ints, fracs, False{}, x, nz}}
    case 5n 5n:
      NGo{Num{6n, neg, ints, fracs, True{}, x, nz}}
    case 5n 0n:
      NGo{Num{7n, neg, ints, fracs, eneg, 0n, nz}}
    case 5n 1n:
      NGo{Num{7n, neg, ints, fracs, eneg, U32.to_nat((b - 48 : U32)), nz}}
    case 5n _:
      NBad{}
    case 6n 0n:
      NGo{Num{7n, neg, ints, fracs, eneg, 0n, nz}}
    case 6n 1n:
      NGo{Num{7n, neg, ints, fracs, eneg, U32.to_nat((b - 48 : U32)), nz}}
    case 6n _:
      NBad{}
    case 7n 0n:
      num.exp(Nat.is_gt(x, 214748364n), Bool.or(eneg, Bool.not(nz)), neg, ints, fracs, eneg, x, nz, 0n)
    case 7n 1n:
      num.exp(Bool.or(Nat.is_gt(x, 214748364n), Bool.and(Nat.is_eq(x, 214748364n), U32.is_gt(b, 55))), Bool.or(eneg, Bool.not(nz)), neg, ints, fracs, eneg, x, nz, U32.to_nat((b - 48 : U32)))
    case 7n _:
      NEnd{Num{7n, neg, ints, fracs, eneg, x, nz}}
    case 8n 0n:
      NGo{Num{8n, neg, ints, fracs, eneg, x, nz}}
    case 8n 1n:
      NGo{Num{8n, neg, ints, fracs, eneg, x, nz}}
    case 8n _:
      NEnd{Num{8n, neg, ints, fracs, eneg, x, nz}}
    case _ _:
      NBad{}

# S2.8 one byte of a number
def num.next(num: Num, +b: U32) -> NR:
  match num:
    case Num{ph, neg, ints, fracs, eneg, x, nz}:
      num.tr(ph, num.cls(b), b, neg, ints, fracs, eneg, x, nz)

# S4.109 the written exponent as a signed integer
def num.exp_int(eneg: Bool, x: Nat) -> F.Int:
  match eneg:
    case True{}:
      F.Int.diff(0n, x)
    case False{}:
      F.Pos{x}

# S2.51 every JSON number becomes a binary64; None is `number out of range` by value (S2.14 (b))
def num.wrap(m: Maybe<&2, F.F64>) -> Maybe<&2, Json>:
  match m:
    case None{}:
      None{}
    case Some{f}:
      Some{JNum{f}}

# S4.101 the value of a finished token; phase 8 is the harmless exponent overflow, whose value is zero
def num.value(num: Num, spec: Bool) -> Maybe<&2, Json>:
  match num:
    case Num{8n, neg, ints, fracs, eneg, x, nz}:
      Some{JNum{F.zero()}}
    case Num{ph, neg, ints, fracs, eneg, x, nz}:
      num.wrap(F.serde_value(neg, String.reverse(ints), String.reverse(fracs), num.exp_int(eneg, x), spec))

# S2.13 after the token's value is pushed, the byte that ended it is judged by the enclosing context
def step.after(st: St, k: Nat) -> St:
  match st:
    case St{MAfter{}, stack, depth, l, c, root}:
      after(stack, depth, l, c, root, k)
    case other:
      other

# S2.14 (b) an out-of-range value is reported at the END of the token: the position before byte k
def num.end(v: Maybe<&2, Json>, stack: List<&2, Frame>, depth: Nat, l0: Nat, c0: Nat, l1: Nat, c1: Nat, root: Maybe<&2, Json>, k: Nat) -> St:
  match v:
    case None{}:
      fail("number out of range", l0, c0)
    case Some{j}:
      step.after(push(j, stack, depth, l1, c1, root), k)

# S2.8 route the outcome of one byte
def num.route(r: NR, stack: List<&2, Frame>, depth: Nat, l0: Nat, c0: Nat, +l1: Nat, +c1: Nat, root: Maybe<&2, Json>, k: Nat, spec: Bool) -> St:
  match r:
    case NGo{num}:
      St{MNum{num}, stack, depth, l1, c1, root}
    case NBad{}:
      fail("invalid number", l1, c1)
    case NRange{}:
      fail("number out of range", l1, c1)
    case NEnd{num}:
      num.end(num.value(num, spec), stack, depth, l0, c0, l1, c1, root, k)

# S2.6 one byte in the current mode. (l0, c0) is the position before the byte, (l1, c1) after it:
# every offending-byte error is reported at (l1, c1) (S2.41). k is the class of byte b (byte.cls), for
# the defs that dispatch on it.
def step.mode(mode: Mode, stack: List<&2, Frame>, depth: Nat, l0: Nat, c0: Nat, l1: Nat, c1: Nat, root: Maybe<&2, Json>, k: Nat, +b: U32, spec: Bool) -> St:
  match mode:
    case MVal{ctx}:
      value(ctx, stack, depth, l1, c1, root, k, b)
    case MKey{first}:
      keymode(first, stack, depth, l1, c1, root, k)
    case MColon{}:
      colon(stack, depth, l1, c1, root, k)
    case MAfter{}:
      after(stack, depth, l1, c1, root, k)
    case MLit{rest, val}:
      lit(rest, val, stack, depth, l1, c1, root, b)
    case MStr{rev, key, need, part}:
      str(rev, key, need, part, stack, depth, l1, c1, root, k, b)
    case MEsc{rev, key}:
      esc(rev, key, stack, depth, l1, c1, root, esc.cls(b))
    case MHex{rev, key, n, v, bad, hi}:
      hex(rev, key, n, v, bad, hi, stack, depth, l1, c1, root, b)
    case MHiBs{rev, key, hi}:
      hibs(rev, key, hi, stack, depth, l1, c1, root, k)
    case MHiU{rev, key, hi}:
      hiu(rev, key, hi, stack, depth, l1, c1, root, U32.is_eq(b, 117))
    case MNum{num}:
      num.route(num.next(num, b), stack, depth, l0, c0, l1, c1, root, k, spec)
    case MErr{msg, l, c}:
      St{MErr{msg, l, c}, stack, depth, l0, c0, root}

# S2.40 only LF ends a line; every other byte (CR included) adds one to the column
def pos.line(lf: Bool, l: Nat) -> Nat:
  match lf:
    case True{}:
      1n+l
    case False{}:
      l

# S2.40 the column counts BYTES since the last LF
def pos.col(lf: Bool, c: Nat) -> Nat:
  match lf:
    case True{}:
      0n
    case False{}:
      1n+c

# S2.45 one byte; an error state is sticky
def step(st: St, +b: U32, spec: Bool) -> St:
  match st:
    case St{MErr{msg, el, ec}, stack, depth, l, c, root}:
      St{MErr{msg, el, ec}, stack, depth, l, c, root}
    case St{mode, stack, depth, +l, +c, root}:
      +lf = U32.is_eq(b, 10)
      step.mode(mode, stack, depth, l, c, pos.line(lf, l), pos.col(lf, c), root, byte.cls(b), b, spec)

# S2.45 one pass over the bytes, first error wins. Measure: the byte list.
def run(bytes: List<&2, U32>, st: St, +spec: Bool) -> St:
  match bytes:
    case Nil{}:
      st
    case Con{b, rest}:
      run(rest, step(st, b, spec), spec)

# S2.4 the result of reading: a value, or the serde_json message with its line and column
type Parsed is Data:
  POk{v: Json}
  PErr{msg: String, line: Nat, col: Nat}

# S2.42 end of input where a container still awaits something: S9.52 for an array, S9.53 for an object
def eof.open(stack: List<&2, Frame>, root: Maybe<&2, Json>, l: Nat, c: Nat) -> Parsed:
  match stack root:
    case Nil{} Some{v}:
      POk{v}
    case Nil{} None{}:
      PErr{"EOF while parsing a value", l, c}
    case Con{FArr{rev, n}, rest} _:
      PErr{"EOF while parsing a list", l, c}
    case Con{FObj{rev, key}, rest} _:
      PErr{"EOF while parsing an object", l, c}

# S2.42 after that push the enclosing container may still be open
def eof.pushed(st: St) -> Parsed:
  match st:
    case St{mode, stack, depth, l, c, root}:
      eof.open(stack, root, l, c)

# S2.42 a number that ends at the end of input: its value may still be out of range (reported at len)
def eof.num(v: Maybe<&2, Json>, stack: List<&2, Frame>, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>) -> Parsed:
  match v:
    case None{}:
      PErr{"number out of range", l, c}
    case Some{j}:
      eof.pushed(push(j, stack, depth, l, c, root))

# S2.42 which phases of a number may end at the end of input: 1, 2, 4, 7 and 8 complete the token;
# 0 (after '-'), 3 (after '.'), 5 and 6 (after e/E or its sign) are `EOF while parsing a value`
def eof.num.ph(num: Num, stack: List<&2, Frame>, depth: Nat, +l: Nat, +c: Nat, root: Maybe<&2, Json>, spec: Bool) -> Parsed:
  match num:
    case Num{0n, neg, ints, fracs, eneg, x, nz}:
      PErr{"EOF while parsing a value", l, c}
    case Num{3n, neg, ints, fracs, eneg, x, nz}:
      PErr{"EOF while parsing a value", l, c}
    case Num{5n, neg, ints, fracs, eneg, x, nz}:
      PErr{"EOF while parsing a value", l, c}
    case Num{6n, neg, ints, fracs, eneg, x, nz}:
      PErr{"EOF while parsing a value", l, c}
    case Num{ph, neg, ints, fracs, eneg, x, nz}:
      eof.num(num.value(Num{ph, neg, ints, fracs, eneg, x, nz}, spec), stack, depth, l, c, root)

# S2.42 where a key is awaited: right after '{' it is the object's EOF, right after ',' a value's
def eof.key(first: Bool, l: Nat, c: Nat) -> Parsed:
  match first:
    case True{}:
      PErr{"EOF while parsing an object", l, c}
    case False{}:
      PErr{"EOF while parsing a value", l, c}

# S2.42 where a value is awaited: right after '[' it is the list's EOF (S9.52), otherwise a value's
def eof.val(ctx: Nat, l: Nat, c: Nat) -> Parsed:
  match ctx:
    case 1n:
      PErr{"EOF while parsing a list", l, c}
    case _:
      PErr{"EOF while parsing a value", l, c}

# S2.42 every end-of-input error is reported at i = len: the position after the last byte
def finish(st: St, spec: Bool) -> Parsed:
  match st:
    case St{MErr{msg, el, ec}, stack, depth, l, c, root}:
      PErr{msg, el, ec}
    case St{MVal{ctx}, stack, depth, l, c, root}:
      eof.val(ctx, l, c)
    case St{MKey{first}, stack, depth, l, c, root}:
      eof.key(first, l, c)
    case St{MColon{}, stack, depth, l, c, root}:
      PErr{"EOF while parsing an object", l, c}
    case St{MAfter{}, stack, depth, l, c, root}:
      eof.open(stack, root, l, c)
    case St{MLit{rest, val}, stack, depth, l, c, root}:
      PErr{"EOF while parsing a value", l, c}
    case St{MNum{num}, stack, depth, l, c, root}:
      eof.num.ph(num, stack, depth, l, c, root, spec)
    case St{other, stack, depth, l, c, root}:
      PErr{"EOF while parsing a string", l, c}

# S2.4 read ONE JSON text from bytes that have already passed the UTF-8 gate (S2.2)
def read(bytes: List<&2, U32>, +spec: Bool) -> Parsed:
  finish(run(bytes, St{MVal{0n}, Nil{}, 0n, 1n, 0n, None{}}, spec), spec)

# ---------------------------------------------------------------- S5.50–S5.78 the JSON writers
# S5.73: for equal values the two writers print identical bytes except for their escape tables, so
# ONE writer serves both: `tab_b` selects writer B's table (S5.64) over writer A's (S5.63). Writer A's
# other difference, repeated keys (S5.72), lives in its input: the value built from the decoder's
# events keeps every occurrence. The text is accumulated reversed and reversed once.

# S5.66 a lower-case hex digit
def hexc(+d: U32) -> Char:
  Chr{Bool.pick(U32, U32.is_lt(d, 10), (d + 48 : U32), (d + 87 : U32))}

# S5.63, S5.64 \u00XX for a scalar below U+0100, four lower-case hex digits, pushed in reverse
def w.u00(+c: U32, acc: String) -> String:
  SCon{hexc((c .&. 15 : U32)), SCon{hexc(((c >> 4n) .&. 15 : U32)), SCon{Chr{48}, SCon{Chr{48}, SCon{Chr{117}, SCon{Chr{92}, acc}}}}}}

# S5.63, S5.64 a scalar that needs \u00XX, or itself
def w.ch.plain(esc: Bool, c: U32, acc: String) -> String:
  match esc:
    case True{}:
      w.u00(c, acc)
    case False{}:
      SCon{Chr{c}, acc}

# S5.63, S5.64 the class of a scalar for the writers: 1 '"', 2 '\', 3 U+0008, 4 TAB, 5 LF, 6 U+000C,
# 7 CR, 0 anything else
def w.cls(+c: U32) -> Nat:
  Bool.pick(Nat, U32.is_eq(c, 34), 1n, Bool.pick(Nat, U32.is_eq(c, 92), 2n, Bool.pick(Nat, U32.is_eq(c, 8), 3n, Bool.pick(Nat, U32.is_eq(c, 9), 4n, Bool.pick(Nat, U32.is_eq(c, 10), 5n, Bool.pick(Nat, U32.is_eq(c, 12), 6n, Bool.pick(Nat, U32.is_eq(c, 13), 7n, 0n)))))))

# S5.63 writer A: \b and \f have short forms; DEL and U+0080-U+009F are written raw (k is w.cls of c)
def w.ch_a(k: Nat, +c: U32, acc: String) -> String:
  match k:
    case 1n:
      SCon{Chr{34}, SCon{Chr{92}, acc}}
    case 2n:
      SCon{Chr{92}, SCon{Chr{92}, acc}}
    case 3n:
      SCon{Chr{98}, SCon{Chr{92}, acc}}
    case 4n:
      SCon{Chr{116}, SCon{Chr{92}, acc}}
    case 5n:
      SCon{Chr{110}, SCon{Chr{92}, acc}}
    case 6n:
      SCon{Chr{102}, SCon{Chr{92}, acc}}
    case 7n:
      SCon{Chr{114}, SCon{Chr{92}, acc}}
    case _:
      w.ch.plain(U32.is_lt(c, 32), c, acc)


# S5.64 writer B: only \" \\ \n \r \t have short forms; every other Cc scalar (U+0000-U+001F, U+007F,
# U+0080-U+009F) is \u00XX; there is no \b and no \f (k is w.cls of c)
def w.ch_b(k: Nat, +c: U32, acc: String) -> String:
  match k:
    case 1n:
      SCon{Chr{34}, SCon{Chr{92}, acc}}
    case 2n:
      SCon{Chr{92}, SCon{Chr{92}, acc}}
    case 4n:
      SCon{Chr{116}, SCon{Chr{92}, acc}}
    case 5n:
      SCon{Chr{110}, SCon{Chr{92}, acc}}
    case 7n:
      SCon{Chr{114}, SCon{Chr{92}, acc}}
    case _:
      w.ch.plain(Bool.or(U32.is_le(c, 31), Bool.and(U32.is_ge(c, 127), U32.is_le(c, 159))), c, acc)

# S5.63, S5.64 one scalar under the selected table
def w.ch(tab_b: Bool, +c: U32, acc: String) -> String:
  match tab_b:
    case False{}:
      w.ch_a(w.cls(c), c, acc)
    case True{}:
      w.ch_b(w.cls(c), c, acc)

# S5.67 the scalars of a string or key, escaped, onto acc (a loop over the text)
def w.chars(s: String, +tab_b: Bool, acc: String) -> String:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{c}, rest}:
      w.chars(rest, tab_b, w.ch(tab_b, c, acc))

# S5.63 a quoted, escaped string or key
def w.str(s: String, tab_b: Bool, acc: String) -> String:
  SCon{Chr{34}, w.chars(s, tab_b, SCon{Chr{34}, acc})}

# S5.61 indentation is space bytes only
def w.pad(k: Nat, acc: String) -> String:
  match k:
    case 0n:
      acc
    case 1n+p:
      w.pad(p, SCon{Chr{32}, acc})

# S5.58 LF and depth*N spaces before an element, a member or a closing bracket; nothing when N = 0
def w.nl(+n: Nat, depth: Nat, acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      w.pad(Nat.mul(1n+p, depth), SCon{Chr{10}, acc})

# S5.58 a comma after every element or member except the last: written before each one but the first
def w.comma(first: Bool, acc: String) -> String:
  match first:
    case True{}:
      acc
    case False{}:
      SCon{Chr{44}, acc}

# S5.59 the separator after a key: ':' when N = 0, ': ' otherwise
def w.colon(n: Nat, acc: String) -> String:
  match n:
    case 0n:
      SCon{Chr{58}, acc}
    case 1n+p:
      SCon{Chr{32}, SCon{Chr{58}, acc}}

# S5.56 an empty container is two bytes at every position and every N; a non-empty one closes on its
# own line at its own depth (S5.60)
def w.close(empty: Bool, open: U32, shut: U32, n: Nat, depth: Nat, body: String) -> String:
  match empty:
    case True{}:
      SCon{Chr{shut}, body}
    case False{}:
      SCon{Chr{shut}, w.nl(n, depth, body)}

# S5.56 whether a chain is empty
def is_nil(j: Json) -> Bool:
  match j:
    case JNil{}:
      True{}
    case other:
      False{}

# S5.54–S5.60 the text of a value, onto acc. ONE def over Json (values and their chains): for a
# value `depth` is its own depth; for a chain it is the depth of the elements. Siblings are a tail
# call; only nesting recurses.
def w(j: Json, first: Bool, +n: Nat, +tab_b: Bool, +depth: Nat, +spec: Bool, acc: String) -> String:
  match j:
    case JNull{}:
      SCon{Chr{108}, SCon{Chr{108}, SCon{Chr{117}, SCon{Chr{110}, acc}}}}
    case JBool{True{}}:
      SCon{Chr{101}, SCon{Chr{117}, SCon{Chr{114}, SCon{Chr{116}, acc}}}}
    case JBool{False{}}:
      SCon{Chr{101}, SCon{Chr{115}, SCon{Chr{108}, SCon{Chr{97}, SCon{Chr{102}, acc}}}}}
    case JNum{f}:
      T.rev_onto(F.show_json_fast(f, spec), acc)
    case JStr{s}:
      w.str(s, tab_b, acc)
    case JArr{cnt, +items}:
      w.close(is_nil(items), 91, 93, n, depth, w(items, True{}, n, tab_b, 1n+depth, spec, SCon{Chr{91}, acc}))
    case JObj{+entries}:
      w.close(is_nil(entries), 123, 125, n, depth, w(entries, True{}, n, tab_b, 1n+depth, spec, SCon{Chr{123}, acc}))
    case JNil{}:
      acc
    case JCons{h, t}:
      w(t, False{}, n, tab_b, depth, spec, w(h, True{}, n, tab_b, depth, spec, w.nl(n, depth, w.comma(first, acc))))
    case JECons{k, q, v, t}:
      w(t, False{}, n, tab_b, depth, spec, w(v, True{}, n, tab_b, depth, spec, w.colon(n, w.str(k, tab_b, w.nl(n, depth, w.comma(first, acc))))))

# S5.51 the JSON text of a value at indent N under writer A's table (tab_b False) or writer B's
def write(j: Json, n: Nat, tab_b: Bool, spec: Bool) -> String:
  String.reverse(w(j, True{}, n, tab_b, 0n, spec, SNil{}))

# S5.101 the JSON text followed by exactly one LF (pushed before the single reversal: `++` would
# recurse to the depth of the whole text)
def write_ln(j: Json, n: Nat, tab_b: Bool, spec: Bool) -> String:
  String.reverse(SCon{Chr{10}, w(j, True{}, n, tab_b, 0n, spec, SNil{})})
