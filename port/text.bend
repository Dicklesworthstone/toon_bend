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

# S4.8 the loop of ends_ws: c is the character before `rest`, so the last one is tested alone
def ends_ws.go(rest: String, c: Char) -> Bool:
  match rest:
    case SNil{}:
      is_ws_char(c)
    case SCon{d, t}:
      ends_ws.go(t, d)

# S4.8 whether the last character is White_Space: a walk to the last character that allocates nothing
# (EXP-013: this used to reverse the whole text to read its head)
def ends_ws(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{c, rest}:
      ends_ws.go(rest, c)

# S4.8 whether the first or the last character is White_Space (the text differs from its own trim)
def has_edge_ws(+s: String) -> Bool:
  Bool.or(head_is_ws(s), ends_ws(s))

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

# S6.10 the loop of str_eq: stops at the first difference
def str_eq.go(a: String, b: String, same: Bool) -> Bool:
  match a b same:
    case _ _ False{}:
      False{}
    case SNil{} SNil{} True{}:
      True{}
    case SCon{Chr{x}, ta} SCon{Chr{y}, tb} True{}:
      str_eq.go(ta, tb, U32.is_eq(x, y))
    case _ _ True{}:
      False{}

# S6.10 exact string equality, scalar by scalar: a loop that allocates nothing (Base's String.eq
# recurses to the depth of the common prefix and rebuilds both texts)
def str_eq(a: String, b: String) -> Bool:
  str_eq.go(a, b, True{})

# S4.21 a later character of a bare key: ASCII letter, digit, '_' or (when dots are allowed) '.'
def key_char(+c: U32, dot: Bool) -> Bool:
  Bool.or(Bool.and(U32.is_ge(c, 97), U32.is_le(c, 122)), Bool.or(Bool.and(U32.is_ge(c, 65), U32.is_le(c, 90)), Bool.or(Bool.and(U32.is_ge(c, 48), U32.is_le(c, 57)), Bool.or(U32.is_eq(c, 95), Bool.and(dot, U32.is_eq(c, 46))))))

# S4.21 the first character of a bare key: ASCII letter or '_'
def key_first(+c: U32) -> Bool:
  Bool.or(Bool.and(U32.is_ge(c, 97), U32.is_le(c, 122)), Bool.or(Bool.and(U32.is_ge(c, 65), U32.is_le(c, 90)), U32.is_eq(c, 95)))

# S4.21 the loop over the later characters: stops at the first that does not belong
def key_rest.go(s: String, +dot: Bool, ok: Bool) -> Bool:
  match s ok:
    case _ False{}:
      False{}
    case SNil{} True{}:
      True{}
    case SCon{Chr{c}, rest} True{}:
      key_rest.go(rest, dot, key_char(c, dot))

# S4.21 (dot True) the key rule; S4.67, S4.241 (dot False) the identifier-segment rule
def is_ident(s: String, dot: Bool) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{c}, rest}:
      key_rest.go(rest, dot, key_first(c))

# S8.5 the bytes of an ASCII text (every scalar below U+0080 is its own byte): closed laws build their
# inputs with it
def ascii_bytes(s: String, acc: List<&2, U32>) -> List<&2, U32>:
  match s:
    case SNil{}:
      List.reverse(&2, U32, acc)
    case SCon{Chr{c}, rest}:
      ascii_bytes(rest, c <> acc)

# S6.36 the number of scalar values of a text (a loop: Base's String.length recurses to the length)
def str_len(s: String, acc: Nat) -> Nat:
  match s:
    case SNil{}:
      acc
    case SCon{c, rest}:
      str_len(rest, 1n+acc)

# S6.36 the length of a list (a loop: Base's List.length recurses to the length)
def llen(a, -A: Kind(a), xs: List<a, A>, acc: Nat) -> Nat:
  match xs:
    case Nil{}:
      acc
    case h <> t:
      llen(a, A, t, 1n+acc)

# S6.36 the loop of cat: every part pushed, reversed, onto one accumulator
def cat.go(parts: List<&2, String>, acc: String) -> String:
  match parts:
    case Nil{}:
      String.reverse(acc)
    case Con{p, rest}:
      cat.go(rest, rev_onto(p, acc))

# S6.36 the concatenation of texts, in order (two loops: `++` recurses to the length of its left
# operand, a stack wall on the JS and interpreter lanes for an input-controlled text)
def cat(parts: List<&2, String>) -> String:
  cat.go(parts, SNil{})

# S7.34 the value of a SHORT digit string (the caller bounds its length: a Nat ends at 2^48)
def nat_of(s: String, acc: Nat) -> Nat:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{c}, rest}:
      nat_of(rest, Nat.add(Nat.mul(acc, 10n), U32.to_nat((c - 48 : U32))))

# ---------------------------------------------------------------- S6.10 a set of key strings
#
# The original keeps object keys in hash maps; a linear search per key is quadratic in the number of
# keys of one object (round 6: 8000 keys took 5 s). KT is a binary trie over the low 16 bits of an
# FNV-1a hash of the key, with the keys themselves in the leaf buckets (balanced trees, KS): membership
# and insertion are 16 steps plus a logarithm of the bucket. Order never comes from here: it stays in the entry chain beside the set.

# S6.10 FNV-1a over the scalar values of a key (U32 arithmetic wraps, which is the algorithm)
def key_hash.go(s: String, +h: U32) -> U32:
  match s:
    case SNil{}:
      h
    case SCon{Chr{c}, rest}:
      key_hash.go(rest, ((h .^. c) * 16777619 : U32))

# S6.10 the hash of a key
def key_hash(s: String) -> U32:
  key_hash.go(s, 2166136261)

# S6.10 the order of two keys by their scalar values (any total order serves: it only balances buckets)
type Ord is Data:
  OLt{}
  OEq{}
  OGt{}

# S6.10 the order of two scalar values from the two verdicts
def ord.pick(lt: Bool, eq: Bool) -> Ord:
  match lt eq:
    case True{} _:
      OLt{}
    case False{} True{}:
      OEq{}
    case False{} False{}:
      OGt{}

# S6.10 the order of two scalar values
def ord.u32(+x: U32, +y: U32) -> Ord:
  ord.pick(U32.is_lt(x, y), U32.is_eq(x, y))

# S6.10 the loop of str_cmp: c is the verdict so far, and the first difference ends it
def str_cmp.go(a: String, b: String, c: Ord) -> Ord:
  match a b c:
    case _ _ OLt{}:
      OLt{}
    case _ _ OGt{}:
      OGt{}
    case SNil{} SNil{} OEq{}:
      OEq{}
    case SNil{} SCon{y, t} OEq{}:
      OLt{}
    case SCon{x, s} SNil{} OEq{}:
      OGt{}
    case SCon{Chr{x}, s} SCon{Chr{y}, t} OEq{}:
      str_cmp.go(s, t, ord.u32(x, y))

# S6.10 the order of two keys (a loop: Base's String.cmp recurses to the length of the common prefix)
def str_cmp(a: String, b: String) -> Ord:
  str_cmp.go(a, b, OEq{})

# S6.10 a bucket: the keys that share their 16 hash bits, as an AA tree (a balanced search tree: a level
# per node, no left child on its parent's level, no two right descendants in a row on it). Keys that
# collide in the hash, by accident or by design, cost a logarithm of their number and never their number
# (round 7: 16000 keys chosen to collide took 21 s in a list bucket).
type KS is Data:
  KSNil{}
  KSNode{lv: Nat, l: KS, key: String, r: KS}

# S6.10 skew, decided: a left child on its parent's level becomes the parent
def ks.skew.pick(same: Bool, lv: Nat, llv: Nat, a: KS, lk: String, b: KS, x: String, r: KS) -> KS:
  match same:
    case True{}:
      KSNode{llv, a, lk, KSNode{lv, b, x, r}}
    case False{}:
      KSNode{lv, KSNode{llv, a, lk, b}, x, r}

# S6.10 skew: remove a left horizontal link by a right rotation
def ks.skew(t: KS) -> KS:
  match t:
    case KSNode{+lv, KSNode{+llv, a, lk, b}, x, r}:
      ks.skew.pick(Nat.is_eq(llv, lv), lv, llv, a, lk, b, x, r)
    case other:
      other

# S6.10 split, decided: the middle of three nodes on one level is lifted a level
def ks.split.pick(same: Bool, lv: Nat, a: KS, x: String, rlv: Nat, b: KS, rk: String, rr: KS) -> KS:
  match same:
    case True{}:
      KSNode{1n+rlv, KSNode{lv, a, x, b}, rk, rr}
    case False{}:
      KSNode{lv, a, x, KSNode{rlv, b, rk, rr}}

# S6.10 the level of a tree's root (0 for the empty tree)
def ks.level(t: KS) -> Nat:
  match t:
    case KSNil{}:
      0n
    case KSNode{lv, l, x, r}:
      lv

# S6.10 split: remove two right horizontal links in a row by a left rotation
def ks.split(t: KS) -> KS:
  match t:
    case KSNode{+lv, a, x, KSNode{rlv, b, rk, +rr}}:
      ks.split.pick(Nat.is_eq(ks.level(rr), lv), lv, a, x, rlv, b, rk, rr)
    case other:
      other

# S6.10 a key against the key at the root (the verdict is not read on the empty tree)
def ks.root(t: KS, k: String) -> Ord:
  match t:
    case KSNil{}:
      OEq{}
    case KSNode{lv, l, x, r}:
      str_cmp(k, x)

# S6.10 membership in a bucket: c is the key against this root; the caller of each step looks at the
# child's root, so the descent is one structural recursion
def ks.has.go(t: KS, +k: String, c: Ord) -> Bool:
  match t c:
    case KSNil{} _:
      False{}
    case KSNode{lv, +l, x, r} OLt{}:
      ks.has.go(l, k, ks.root(l, k))
    case KSNode{lv, l, x, +r} OGt{}:
      ks.has.go(r, k, ks.root(r, k))
    case KSNode{lv, l, x, r} OEq{}:
      True{}

# S6.10 whether a key is in a bucket
def ks.has(+t: KS, +k: String) -> Bool:
  ks.has.go(t, k, ks.root(t, k))

# S6.10 insertion into a bucket: rebalanced on the way back up (skew, then split); a key already there
# changes nothing
def ks.put.go(t: KS, +k: String, c: Ord) -> KS:
  match t c:
    case KSNil{} _:
      KSNode{1n, KSNil{}, k, KSNil{}}
    case KSNode{lv, +l, x, r} OLt{}:
      ks.split(ks.skew(KSNode{lv, ks.put.go(l, k, ks.root(l, k)), x, r}))
    case KSNode{lv, l, x, +r} OGt{}:
      ks.split(ks.skew(KSNode{lv, l, x, ks.put.go(r, k, ks.root(r, k))}))
    case KSNode{lv, l, x, r} OEq{}:
      KSNode{lv, l, x, r}

# S6.10 add a key to a bucket
def ks.put(+t: KS, +k: String) -> KS:
  ks.put.go(t, k, ks.root(t, k))

# S6.10 the set: an empty region or a bucket of keys, or a fork on the next hash bit
type KT is Data:
  KLeaf{keys: KS}
  KNode{zero: KT, one: KT}

# S6.10 the empty set
def kt.empty() -> KT:
  KLeaf{KSNil{}}

# S6.10 whether the lowest bit of a hash is set
def kt.odd(h: U32) -> Bool:
  U32.is_eq((h .&. 1 : U32), 1)

# S6.10 membership: d counts the hash bits still to follow, odd is the current bit
def kt.has.go(d: Nat, odd: Bool, t: KT, +h: U32, k: String) -> Bool:
  match d odd t:
    case 0n _ KLeaf{ks}:
      ks.has(ks, k)
    case 0n _ KNode{z, o}:
      False{}
    case 1n+p _ KLeaf{ks}:
      False{}
    case 1n+p False{} KNode{z, o}:
      kt.has.go(p, kt.odd((h >> 1n : U32)), z, (h >> 1n : U32), k)
    case 1n+p True{} KNode{z, o}:
      kt.has.go(p, kt.odd((h >> 1n : U32)), o, (h >> 1n : U32), k)

# S6.10 membership from the key's hash
def kt.has.at(t: KT, +h: U32, k: String) -> Bool:
  kt.has.go(16n, kt.odd(h), t, h, k)

# S6.10 whether a key is in the set
def kt.has(t: KT, +k: String) -> Bool:
  kt.has.at(t, key_hash(k), k)

# S6.10 insertion: a leaf above depth 0 is an empty region and is split on the way down
def kt.put.go(d: Nat, odd: Bool, t: KT, +h: U32, k: String) -> KT:
  match d odd t:
    case 0n _ KLeaf{ks}:
      KLeaf{ks.put(ks, k)}
    case 0n _ KNode{z, o}:
      KNode{z, o}
    case 1n+p False{} KLeaf{ks}:
      KNode{kt.put.go(p, kt.odd((h >> 1n : U32)), KLeaf{KSNil{}}, (h >> 1n : U32), k), KLeaf{ks}}
    case 1n+p True{} KLeaf{ks}:
      KNode{KLeaf{ks}, kt.put.go(p, kt.odd((h >> 1n : U32)), KLeaf{KSNil{}}, (h >> 1n : U32), k)}
    case 1n+p False{} KNode{z, o}:
      KNode{kt.put.go(p, kt.odd((h >> 1n : U32)), z, (h >> 1n : U32), k), o}
    case 1n+p True{} KNode{z, o}:
      KNode{z, kt.put.go(p, kt.odd((h >> 1n : U32)), o, (h >> 1n : U32), k)}

# S6.10 insertion from the key's hash
def kt.put.at(t: KT, +h: U32, k: String) -> KT:
  kt.put.go(16n, kt.odd(h), t, h, k)

# S6.10 add a key to the set (the caller asks kt.has first when duplicates matter)
def kt.put(t: KT, +k: String) -> KT:
  kt.put.at(t, key_hash(k), k)
