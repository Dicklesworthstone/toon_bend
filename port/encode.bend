# toon_bend — the encoder: a Json value to TOON lines (S4.1–S4.84, S5.1–S5.12).
#
# Shape (PROPOSED_ARCHITECTURE): ONE structurally recursive def, `emit`, walks the value. Bend has no
# mutual recursion and cannot match a computed value in place, so every verdict about a child
# (its array strategy, its tabular header, whether its key folds and how far) is computed by the PARENT
# with non-recursive verdict defs and handed down in the context parameter; `emit` only ever matches
# its own parameters. Key folding descends through the single-field chain structurally (CDesc).
# Lines are accumulated newest first; every walk whose length the input controls is a loop.
import Base
import ./text.bend as T
import ./f64.bend as F
import ./json.bend as J

# S3.9 encoder options: indent 0-16, the active delimiter (44 comma, 9 tab, 124 pipe), key folding on or
# off, the flatten-depth budget (NUMERIC_PLAN S7.2: saturated, "unlimited" is any value past the input), and
# the numeric kill-switch (TOON_SPEC=1: every number takes its spec twin)
type Opts is Data:
  Opts{indent: Nat, delim: U32, fold: Bool, budget: Nat, spec: Bool}

# S4.12–S4.16 a character that forces quotes wherever it stands: ':' '"' '\' '[' ']' '{' '}' LF CR TAB,
# or the ACTIVE delimiter
def bad_char(+c: U32, delim: U32) -> Bool:
  Bool.or(U32.is_eq(c, delim), Bool.or(U32.is_eq(c, 58), Bool.or(U32.is_eq(c, 34), Bool.or(U32.is_eq(c, 92), Bool.or(U32.is_eq(c, 91), Bool.or(U32.is_eq(c, 93), Bool.or(U32.is_eq(c, 123), Bool.or(U32.is_eq(c, 125), Bool.or(U32.is_eq(c, 10), Bool.or(U32.is_eq(c, 13), U32.is_eq(c, 9)))))))))))

# S4.12–S4.16 the loop of has_bad: stops at the first such character
def has_bad.go(s: String, +delim: U32, found: Bool) -> Bool:
  match s found:
    case _ True{}:
      True{}
    case SNil{} False{}:
      False{}
    case SCon{Chr{c}, rest} False{}:
      has_bad.go(rest, delim, bad_char(c, delim))

# S4.12–S4.16 whether a string contains a character that forces quotes
def has_bad(s: String, delim: U32) -> Bool:
  has_bad.go(s, delim, False{})

# S4.17 condition 10: the string starts with '-'
def starts_dash(s: String) -> Bool:
  match s:
    case SCon{Chr{c}, rest}:
      U32.is_eq(c, 45)
    case SNil{}:
      False{}

# S4.9 condition 3: exactly true, false or null
def is_word(+s: String) -> Bool:
  Bool.or(T.str_eq(s, "true"), Bool.or(T.str_eq(s, "false"), T.str_eq(s, "null")))

# S4.6 the value rule: bare only when none of the ten conditions S4.7–S4.17 holds
def needs_quote(+s: String, delim: U32) -> Bool:
  Bool.or(String.is_empty(s), Bool.or(T.has_edge_ws(s), Bool.or(is_word(s), Bool.or(F.is_like(s), Bool.or(has_bad(s, delim), starts_dash(s))))))

# S4.19 the escape class of a scalar: 1 '\', 2 '"', 3 LF, 4 CR, 5 TAB, 0 anything else
def esc.cls(+c: U32) -> Nat:
  Bool.pick(Nat, U32.is_eq(c, 92), 1n, Bool.pick(Nat, U32.is_eq(c, 34), 2n, Bool.pick(Nat, U32.is_eq(c, 10), 3n, Bool.pick(Nat, U32.is_eq(c, 13), 4n, Bool.pick(Nat, U32.is_eq(c, 9), 5n, 0n)))))

# S4.19 exactly five escapes, per scalar, onto a reversed accumulator; everything else is copied.
# k is the escape class of c (esc.cls): a small code, never the scalar's own value
def esc.ch(k: Nat, c: U32, acc: String) -> String:
  match k:
    case 1n:
      SCon{Chr{92}, SCon{Chr{92}, acc}}
    case 2n:
      SCon{Chr{34}, SCon{Chr{92}, acc}}
    case 3n:
      SCon{Chr{110}, SCon{Chr{92}, acc}}
    case 4n:
      SCon{Chr{114}, SCon{Chr{92}, acc}}
    case 5n:
      SCon{Chr{116}, SCon{Chr{92}, acc}}
    case _:
      SCon{Chr{c}, acc}

# S4.19 the escaped text, reversed, onto acc (a loop over the text)
def esc.go(s: String, acc: String) -> String:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{+c}, rest}:
      esc.go(rest, esc.ch(esc.cls(c), c, acc))

# S4.20 the quoted form onto a reversed accumulator
def put.quoted(s: String, acc: String) -> String:
  SCon{Chr{34}, esc.go(s, SCon{Chr{34}, acc})}

# S4.5 a string value: bare or quoted, from the verdict
def put.value.if(q: Bool, s: String, acc: String) -> String:
  match q:
    case True{}:
      put.quoted(s, acc)
    case False{}:
      T.rev_onto(s, acc)

# S4.5 a string value under the value rule with the active delimiter
def put.value(+s: String, delim: U32, acc: String) -> String:
  put.value.if(needs_quote(s, delim), s, acc)

# S4.21 a key: bare when the key rule allows, else quoted
def put.key(+k: String, acc: String) -> String:
  put.value.if(Bool.not(T.is_ident(k, True{})), k, acc)

# S4.3–S4.5 a primitive's text: null, true, false, the number's TOON text (S4.130), or a string
def put.prim(j: J.Json, delim: U32, +spec: Bool, acc: String) -> String:
  match j:
    case J.JBool{True{}}:
      T.rev_onto("true", acc)
    case J.JBool{False{}}:
      T.rev_onto("false", acc)
    case J.JNum{f}:
      T.rev_onto(F.show_toon_fast(f, spec), acc)
    case J.JStr{s}:
      put.value(s, delim, acc)
    case J.JTxt{s}:
      T.rev_onto(s, acc)
    case J.JRaw{neg, ints, fracs, eneg, x}:
      T.rev_onto(F.show_toon_fast(J.raw.f64(neg, ints, fracs, eneg, x, spec), spec), acc)
    case other:
      T.rev_onto("null", acc)

# ---------------------------------------------------------------- S4.24–S4.39 arrays

# S3.7 a primitive is a string, a number, a boolean or null
def is_prim(j: J.Json) -> Bool:
  match j:
    case J.JNull{}:
      True{}
    case J.JBool{b}:
      True{}
    case J.JNum{f}:
      True{}
    case J.JStr{s}:
      True{}
    case J.JTxt{s}:
      True{}
    case J.JRaw{neg, ints, fracs, eneg, x}:
      True{}
    case other:
      False{}

# S3.7 an object (empty or not)
def is_obj(j: J.Json) -> Bool:
  match j:
    case J.JObj{e}:
      True{}
    case other:
      False{}

# S3.7 the loop of all_prim: stops at the first item that is not a primitive
def all_prim.go(c: J.Json, ok: Bool) -> Bool:
  match c ok:
    case _ False{}:
      False{}
    case J.JCons{h, t} True{}:
      all_prim.go(t, is_prim(h))
    case _ True{}:
      True{}

# S3.7 every item is a primitive (true for the empty chain)
def all_prim(c: J.Json) -> Bool:
  all_prim.go(c, True{})

# S3.7 the loop of all_obj
def all_obj.go(c: J.Json, ok: Bool) -> Bool:
  match c ok:
    case _ False{}:
      False{}
    case J.JCons{h, t} True{}:
      all_obj.go(t, is_obj(h))
    case _ True{}:
      True{}

# S3.7 every item is an object (true for the empty chain)
def all_obj(c: J.Json) -> Bool:
  all_obj.go(c, True{})

# S6.35 the keys of an entry chain, newest first
def keys.go(c: J.Json, acc: List<&2, String>) -> List<&2, String>:
  match c:
    case J.JECons{k, q, v, t}:
      keys.go(t, k <> acc)
    case other:
      acc

# S6.35 the keys of an entry chain as a SET (S4.69 only asks membership; order never comes from it)
def keys.kt.go(c: J.Json, acc: T.KT) -> T.KT:
  match c:
    case J.JECons{k, q, v, t}:
      keys.kt.go(t, T.kt.put(acc, k))
    case other:
      acc

# S4.69 the sibling set of an object body; nobody asks it when folding is off, so it is not built then
def keys.kt(on: Bool, c: J.Json) -> T.KT:
  match on:
    case False{}:
      T.kt.empty()
    case True{}:
      keys.kt.go(c, T.kt.empty())

# S6.31 the keys of an entry chain in field order (the tabular header comes from the FIRST row's order)
def keys(c: J.Json) -> List<&2, String>:
  List.reverse(&2, String, keys.go(c, Nil{}))

# S4.36 the loop of lookup: the value under a key, null when the key is absent
def lookup.go(c: J.Json, +k: String, hit: Bool, val: J.Json) -> J.Json:
  match c hit:
    case _ True{}:
      val
    case J.JECons{key, q, v, t} False{}:
      lookup.go(t, k, T.str_eq(key, k), v)
    case _ False{}:
      J.JNull{}

# S4.37 the value a row holds under a header key
def lookup(c: J.Json, k: String) -> J.Json:
  lookup.go(c, k, False{}, J.JNull{})

# S4.36 the loop of has_prim: whether a row holds a PRIMITIVE under a key
def has_prim.go(c: J.Json, +k: String, hit: Bool, prim: Bool) -> Bool:
  match c hit:
    case _ True{}:
      prim
    case J.JECons{key, q, v, t} False{}:
      has_prim.go(t, k, T.str_eq(key, k), is_prim(v))
    case _ False{}:
      False{}

# S4.36 (c)+(d) a row contains a header key and holds a primitive under it
def has_prim(c: J.Json, k: String) -> Bool:
  has_prim.go(c, k, False{}, False{})

# S4.36 the loop over the header keys for one row, against the row's key map
def row_keys.go(hdr: List<&2, String>, +km: J.KM, ok: Bool) -> Bool:
  match hdr ok:
    case _ False{}:
      False{}
    case Nil{} True{}:
      True{}
    case Con{+k, rest} True{}:
      row_keys.go(rest, km, has_prim(J.km.bucket(km, k), k))

# S4.36 the number of fields of a row
def count.go(c: J.Json, n: Nat) -> Nat:
  match c:
    case J.JECons{k, q, v, t}:
      count.go(t, 1n+n)
    case other:
      n

# S4.36 a row whose keys come in HEADER order is judged in one lockstep walk: 0 the orders differ (or
# the counts do), so the per-key search decides; 1 same keys, same order, every value primitive;
# 2 same keys and order but a value that is not primitive. `same` is the verdict on the previous pair.
def row.lock(hdr: List<&2, String>, c: J.Json, same: Bool, prim: Bool) -> Nat:
  match hdr c same:
    case _ _ False{}:
      0n
    case Nil{} J.JECons{key, q, v, t} True{}:
      0n
    case Nil{} other True{}:
      Bool.pick(Nat, prim, 1n, 2n)
    case Con{k, rest} J.JECons{key, q, v, t} True{}:
      row.lock(rest, t, T.str_eq(k, key), Bool.and(prim, is_prim(v)))
    case Con{k, rest} other True{}:
      0n

# S4.36 the lockstep verdict, or the general test: (b) exactly as many fields as the header, (c)+(d)
# every header key present with a primitive value. Key ORDER in the row is free, so the general test
# asks a key map of the row (S6.31), not the entries one by one.
def row_ok.of(lock: Nat, +entries: J.Json, +hdr: List<&2, String>, hn: Nat) -> Bool:
  match lock:
    case 1n:
      True{}
    case 2n:
      False{}
    case _:
      Bool.and(Nat.is_eq(count.go(entries, 0n), hn), row_keys.go(hdr, J.km.of(entries, J.km.empty()), True{}))

# S4.36 one row: (a) an object, then S4.36 (b)-(d)
def row_ok(row: J.Json, +hdr: List<&2, String>, hn: Nat) -> Bool:
  match row:
    case J.JObj{+entries}:
      row_ok.of(row.lock(hdr, entries, True{}, True{}), entries, hdr, hn)
    case other:
      False{}

# S4.36 the loop over the rows: one failing row sends the whole array to list form
def rows_ok.go(c: J.Json, +hdr: List<&2, String>, +hn: Nat, ok: Bool) -> Bool:
  match c ok:
    case _ False{}:
      False{}
    case J.JCons{h, t} True{}:
      rows_ok.go(t, hdr, hn, row_ok(h, hdr, hn))
    case _ True{}:
      True{}

# S4.35 the header: the first row must be a NON-empty object; its keys in its own order
def tab_hdr(items: J.Json) -> List<&2, String>:
  match items:
    case J.JCons{J.JObj{entries}, t}:
      keys(entries)
    case other:
      Nil{}

# S4.30 what a value is and how it will be written; VTab carries the tabular header
type VK is Data:
  VPrim{}
  VArr0{}
  VInline{}
  VTab{hdr: List<&2, String>}
  VList{}
  VObj0{}
  VObj{}

# S4.34 tabular or list form
def vk.tab.if(ok: Bool, hdr: List<&2, String>) -> VK:
  match ok:
    case True{}:
      VTab{hdr}
    case False{}:
      VList{}

# S4.34 tabular when a header can be extracted and every row is uniform; an empty header (first row {})
# is never tabular (S4.35)
def vk.tab(+hdr: List<&2, String>, items: J.Json) -> VK:
  +hn = T.llen(&2, String, hdr, 0n)
  vk.tab.if(Bool.and(Bool.not(Nat.is_eq(hn, 0n)), rows_ok.go(items, hdr, hn, True{})), hdr)


# S4.30 the five steps in order for an array chain: empty, all primitive (inline), everything that is
# not "all objects" goes to list form (step 3 is byte-identical to list form, S4.39), all objects are
# tabular when the tests pass. `tab_ok` is False for an array that is itself a list item (S4.42).
def vk.arr(empty: Bool, prims: Bool, objs: Bool, tab_ok: Bool, +items: J.Json) -> VK:
  match empty prims objs tab_ok:
    case True{} _ _ _:
      VArr0{}
    case False{} True{} _ _:
      VInline{}
    case False{} False{} True{} True{}:
      vk.tab(tab_hdr(items), items)
    case _ _ _ _:
      VList{}

# S4.30 the kind of a value
def vkind(v: J.Json, tab_ok: Bool) -> VK:
  match v:
    case J.JArr{n, +items}:
      vk.arr(J.is_nil(items), all_prim(items), all_obj(items), tab_ok, items)
    case J.JObj{J.JNil{}}:
      VObj0{}
    case J.JObj{other}:
      VObj{}
    case other:
      VPrim{}

# S4.61 the start of a line: indent x depth spaces, then "- " on a hyphen line
def ln(d: Nat, hy: Bool, opt: Opts) -> String:
  match hy opt:
    case False{} Opts{indent, delim, fo, budget, spec}:
      T.pad_onto(Nat.mul(indent, d), Chr{32}, SNil{})
    case True{} Opts{indent, delim, fo, budget, spec}:
      SCon{Chr{32}, SCon{Chr{45}, T.pad_onto(Nat.mul(indent, d), Chr{32}, SNil{})}}

# S4.25 the delimiter marker inside the brackets: nothing for comma, the character itself otherwise
def put.marker(comma: Bool, delim: U32, acc: String) -> String:
  match comma:
    case True{}:
      acc
    case False{}:
      SCon{Chr{delim}, acc}

# S4.26 the field names, each under the key rule, separated by ONE active delimiter
def put.fields(hdr: List<&2, String>, +delim: U32, first: Bool, acc: String) -> String:
  match hdr first:
    case Nil{} _:
      acc
    case Con{k, rest} True{}:
      put.fields(rest, delim, False{}, put.key(k, acc))
    case Con{k, rest} False{}:
      put.fields(rest, delim, False{}, put.key(k, SCon{Chr{delim}, acc}))

# S4.26 the field list of a tabular header: { names }; nothing for the other forms
def put.fieldlist(hdr: List<&2, String>, delim: U32, acc: String) -> String:
  match hdr:
    case Nil{}:
      acc
    case Con{k, rest}:
      SCon{Chr{125}, put.fields(k <> rest, delim, True{}, SCon{Chr{123}, acc})}

# S4.24 the key in front of a header, when the array has one
def put.optkey(hk: Bool, key: String, acc: String) -> String:
  match hk:
    case True{}:
      put.key(key, acc)
    case False{}:
      acc

# S4.24 key (when there is one), '[', length, marker, ']', field list (tabular), ':'
def put.header(hk: Bool, key: String, n: Nat, hdr: List<&2, String>, +delim: U32, acc: String) -> String:
  SCon{Chr{58}, put.fieldlist(hdr, delim, SCon{Chr{93}, put.marker(U32.is_eq(delim, 44), delim, T.rev_onto(Nat.show(n), SCon{Chr{91}, put.optkey(hk, key, acc)}))})}

# S4.28 the join of a chain of primitives: ONE delimiter between items, nothing after the last
def put.join(c: J.Json, +delim: U32, +spec: Bool, first: Bool, acc: String) -> String:
  match c first:
    case J.JCons{h, t} True{}:
      put.join(t, delim, spec, False{}, put.prim(h, delim, spec, acc))
    case J.JCons{h, t} False{}:
      put.join(t, delim, spec, False{}, put.prim(h, delim, spec, SCon{Chr{delim}, acc}))
    case _ _:
      acc

# S4.37 the cells of one row, taken in HEADER order (not in the row's own key order) from its key map
def put.cells(hdr: List<&2, String>, +km: J.KM, +delim: U32, +spec: Bool, first: Bool, acc: String) -> String:
  match hdr first:
    case Nil{} _:
      acc
    case Con{+k, rest} True{}:
      put.cells(rest, km, delim, spec, False{}, put.prim(lookup(J.km.bucket(km, k), k), delim, spec, acc))
    case Con{+k, rest} False{}:
      put.cells(rest, km, delim, spec, False{}, put.prim(lookup(J.km.bucket(km, k), k), delim, spec, SCon{Chr{delim}, acc}))

# S4.37 the cells of a row whose keys come in header order: its own values, in its own order
def put.cells.seq(c: J.Json, +delim: U32, +spec: Bool, first: Bool, acc: String) -> String:
  match c first:
    case J.JECons{k, q, v, t} True{}:
      put.cells.seq(t, delim, spec, False{}, put.prim(v, delim, spec, acc))
    case J.JECons{k, q, v, t} False{}:
      put.cells.seq(t, delim, spec, False{}, put.prim(v, delim, spec, SCon{Chr{delim}, acc}))
    case _ _:
      acc

# S4.37 header order by lockstep when the row has it, by its key map otherwise: the same cells either way
def put.row(lock: Nat, hdr: List<&2, String>, entries: J.Json, delim: U32, spec: Bool, acc: String) -> String:
  match lock:
    case 0n:
      put.cells(hdr, J.km.of(entries, J.km.empty()), delim, spec, True{}, acc)
    case _:
      put.cells.seq(entries, delim, spec, True{}, acc)

# S4.37 one row line at depth d: no marker, no keys. Every line builder returns its line REVERSED: the
# text is built forward from reversed lines, one copy per character (S5.100, EXP-021)
def row.line(row: J.Json, +hdr: List<&2, String>, d: Nat, +opt: Opts) -> String:
  match row opt:
    case J.JObj{+entries} Opts{indent, delim, fo, budget, spec}:
      put.row(row.lock(hdr, entries, True{}, True{}), hdr, entries, delim, spec, ln(d, False{}, opt))
    case _ _:
      SNil{}

# S4.37 the row lines of a tabular array, in item order (a loop over the rows; the Phase 5 seam, S11.2)
def rows(c: J.Json, +hdr: List<&2, String>, +d: Nat, +opt: Opts, acc: List<&2, String>) -> List<&2, String>:
  match c:
    case J.JCons{h, t}:
      rows(t, hdr, d, opt, row.line(h, hdr, d, opt) <> acc)
    case other:
      acc


# ---------------------------------------------------------------- S4.63–S4.84 key folding

# S4.70–S4.78 what a body knows about folding: whether folding is on, the budget, the root-literal
# set (present only below the root object, absent inside list items, S4.73), and the path prefix.
# lean (a fast twin through F.twin.on, EXP-008): folding is off, so nobody reads the prefix (only fold.go
# does, and only when fc.can); a lean context is passed to children unchanged instead of growing a prefix
type FCtx is Data:
  FCtx{on: Bool, budget: Nat, has_set: Bool, set: T.KT, has_pre: Bool, pre: String, lean: Bool}

# S4.65 the chain walk: while there is room and the value is an object with EXACTLY one field, take that
# field's key and enter its value. Segments are collected newest first. Arrays are never entered.
def walk(v: J.Json, room: Nat, acc: List<&2, String>) -> List<&2, String>:
  match v room:
    case J.JObj{J.JECons{k, q, v2, J.JNil{}}} 1n+r:
      walk(v2, r, k <> acc)
    case _ _:
      acc

# S4.65 the value the walk stops at, n levels below v
def leaf_of(v: J.Json, n: Nat) -> J.Json:
  match v n:
    case J.JObj{J.JECons{k, q, v2, t}} 1n+p:
      leaf_of(v2, p)
    case other _:
      other

# S4.67 every collected segment must be an identifier segment (no dot)
def segs_ok.go(segs: List<&2, String>, ok: Bool) -> Bool:
  match segs ok:
    case _ False{}:
      False{}
    case Nil{} True{}:
      True{}
    case Con{s, rest} True{}:
      segs_ok.go(rest, T.is_ident(s, False{}))

# S4.68 one segment in front of what is already joined
def join_segs.one(s: String, acc: String) -> String:
  match acc:
    case SNil{}:
      s
    case SCon{c, t}:
      T.cat([s, ".", SCon{c, t}])

# S4.68 the segments (newest first) joined with single dots, in walk order
def join_segs(segs: List<&2, String>, acc: String) -> String:
  match segs:
    case Nil{}:
      acc
    case Con{s, rest}:
      join_segs(rest, join_segs.one(s, acc))


# S4.71 a path: the prefix, a dot, the key; the key alone when there is no prefix
def path(has_pre: Bool, pre: String, k: String) -> String:
  match has_pre:
    case True{}:
      T.cat([pre, ".", k])
    case False{}:
      k

# S3.16 the verdict of a fold attempt: the segment count (0 = no fold) and the folded key
type Fold is Data:
  Fold{segs: Nat, fkey: String}

# S4.84 the refusal tests have one common outcome, so their order is not observable: at least two
# segments (S4.66), all identifier segments (S4.67), no sibling collision (S4.69), not a root literal (S4.72)
def fold.check(two: Bool, idents: Bool, sib: Bool, lit: Bool, n: Nat, fkey: String) -> Fold:
  match two idents sib lit:
    case True{} True{} False{} False{}:
      Fold{n, fkey}
    case _ _ _ _:
      Fold{0n, SNil{}}

# S4.68–S4.72 judge the collected segments
def fold.go(fc: FCtx, +segs: List<&2, String>, sibs: T.KT) -> Fold:
  match fc:
    case FCtx{on, budget, has_set, set, has_pre, pre, lean}:
      +n = T.llen(&2, String, segs, 0n)
      +fkey = join_segs(segs, SNil{})
      fold.check(Nat.is_ge(n, 2n), segs_ok.go(segs, True{}), T.kt.has(sibs, fkey), Bool.and(has_set, T.kt.has(set, path(has_pre, pre, fkey))), n, fkey)

# S4.64 whether folding is on
def fc.on(fc: FCtx) -> Bool:
  match fc:
    case FCtx{on, budget, has_set, set, has_pre, pre, lean}:
      on

# S4.64 the preconditions that do not depend on the value: folding is on and the budget is at least 2
def fc.can(fc: FCtx) -> Bool:
  match fc:
    case FCtx{on, budget, has_set, set, has_pre, pre, lean}:
      Bool.and(on, Nat.is_ge(budget, 2n))

# S4.65 how many more segments the walk may take after the starting key: budget - 1, none when folding is off
def fc.room(fc: FCtx) -> Nat:
  match fc:
    case FCtx{True{}, budget, has_set, set, has_pre, pre, lean}:
      Nat.sub(budget, 1n)
    case FCtx{False{}, budget, has_set, set, has_pre, pre, lean}:
      0n

# S4.64 attempt or not
def fold.if(can: Bool, segs: List<&2, String>, fc: FCtx, sibs: T.KT) -> Fold:
  match can:
    case False{}:
      Fold{0n, SNil{}}
    case True{}:
      fold.go(fc, segs, sibs)

# S4.63 the fold attempt of one field of an object body
def fold(k: String, +v: J.Json, +fc: FCtx, sibs: T.KT) -> Fold:
  fold.if(Bool.and(fc.can(fc), is_obj(v)), walk(v, fc.room(fc), k <> Nil{}), fc, sibs)

# S4.78 the body under a NON-folded object field: the same budget, the prefix extended by the raw key; a lean
# context (folding off, EXP-008) is passed on unchanged, since nothing reads its prefix
def fctx.child(fc: FCtx, k: String) -> FCtx:
  match fc:
    case FCtx{on, budget, has_set, set, has_pre, pre, True{}}:
      FCtx{on, budget, has_set, set, has_pre, pre, True{}}
    case FCtx{on, budget, has_set, set, has_pre, pre, False{}}:
      FCtx{on, budget, has_set, set, True{}, path(has_pre, pre, k), False{}}

# S4.77 the body under a partial fold: budget minus the segment count (never below 0), prefix + folded key
def fctx.rem(fc: FCtx, segs: Nat, fkey: String) -> FCtx:
  match fc:
    case FCtx{on, budget, has_set, set, has_pre, pre, lean}:
      FCtx{on, Nat.sub(budget, segs), has_set, set, True{}, path(has_pre, pre, fkey), lean}

# S4.64 (EXP-008) a context is lean when folding is off and the gate is open (TOON_SPEC=1 closes it)
def fctx.lean(+fo: Bool, spec: Bool) -> Bool:
  F.twin.on(spec, Bool.not(fo))

# S4.73 bodies started from a list item: no root-literal set, no prefix, the budget reset to the option
def fctx.item(opt: Opts) -> FCtx:
  match opt:
    case Opts{indent, delim, +fo, budget, spec}:
      FCtx{fo, budget, False{}, T.kt.empty(), False{}, SNil{}, fctx.lean(fo, spec)}

# S4.70 add a root key to the set when it contains a dot
def dotted.add(has: Bool, k: String, acc: T.KT) -> T.KT:
  match has:
    case True{}:
      T.kt.put(acc, k)
    case False{}:
      acc

# S4.70 the root keys that contain a dot anywhere
def dotted.go(c: J.Json, acc: T.KT) -> T.KT:
  match c:
    case J.JECons{+k, q, v, t}:
      dotted.go(t, dotted.add(T.has_char(k, 46), k, acc))
    case other:
      acc

# S4.70 the root-literal set; nobody asks it when folding is off, so it is not built then
def dotted.set(on: Bool, c: J.Json) -> T.KT:
  match on:
    case False{}:
      T.kt.empty()
    case True{}:
      dotted.go(c, T.kt.empty())

# S4.70 the fold context of the root object's body: the root-literal set, no prefix, the full budget
def fctx.root(opt: Opts, j: J.Json) -> FCtx:
  match opt j:
    case Opts{indent, delim, +fo, budget, +spec} J.JObj{entries}:
      FCtx{fo, budget, True{}, dotted.set(fo, entries), False{}, SNil{}, fctx.lean(fo, spec)}
    case Opts{indent, delim, +fo, budget, spec} other:
      FCtx{fo, budget, False{}, T.kt.empty(), False{}, SNil{}, fctx.lean(fo, spec)}

# ---------------------------------------------------------------- S4.40–S4.62 the emitter

# S4.30–S4.59 how `emit` treats the node it is given; every field is a verdict the PARENT computed.
# hk/key: whether the line carries a key, and the raw key (the key rule is applied when it is written);
# d: depth of the line; hy: whether the line starts with "- "; dc: depth of what the node nests.
type Ctx is Data:
  CPrim{hk: Bool, key: String, d: Nat, hy: Bool}
  CArr0{hk: Bool, key: String, d: Nat, hy: Bool}
  CInline{hk: Bool, key: String, d: Nat, hy: Bool}
  CTab{hk: Bool, key: String, d: Nat, hy: Bool, dc: Nat, hdr: List<&2, String>}
  CList{hk: Bool, key: String, d: Nat, hy: Bool, dc: Nat}
  CObj0{hk: Bool, key: String, d: Nat, hy: Bool}
  CObjK{key: String, d: Nat, hy: Bool, dc: Nat, fc: FCtx}
  CObjRoot{fc: FCtx}
  CObjItem{d: Nat}
  CDesc{n: Nat, leaf: Ctx}
  CFields{d: Nat, fc: FCtx, sibs: T.KT}
  CItems{d: Nat}

# S4.44 a non-empty object without a key: the root object's body, or a list item whose first field
# goes on the hyphen line
def ctx.obj(hk: Bool, hy: Bool, key: String, d: Nat, dc: Nat, fc: FCtx) -> Ctx:
  match hk hy:
    case True{} _:
      CObjK{key, d, hy, dc, fc}
    case False{} True{}:
      CObjItem{d}
    case False{} False{}:
      CObjRoot{fc}

# S4.30 the context for a value from its kind verdict
def ctx.vk(vk: VK, hk: Bool, key: String, d: Nat, hy: Bool, dc: Nat, fc: FCtx) -> Ctx:
  match vk:
    case VPrim{}:
      CPrim{hk, key, d, hy}
    case VArr0{}:
      CArr0{hk, key, d, hy}
    case VInline{}:
      CInline{hk, key, d, hy}
    case VTab{hdr}:
      CTab{hk, key, d, hy, dc, hdr}
    case VList{}:
      CList{hk, key, d, hy, dc}
    case VObj0{}:
      CObj0{hk, key, d, hy}
    case VObj{}:
      ctx.obj(hk, hy, key, d, dc, fc)

# S4.74–S4.77 a field that folds: descend segs - 1 single-field objects to the leaf or remainder, which
# is then written under the folded key at the field's own depth; S4.80 a field that does not fold is
# written normally and its body keeps the budget
def ctx.field.of(f: Fold, +k: String, +v: J.Json, +d: Nat, +fc: FCtx) -> Ctx:
  match f:
    case Fold{0n, fkey}:
      ctx.vk(vkind(v, True{}), True{}, k, d, False{}, 1n+d, fctx.child(fc, k))
    case Fold{1n++m, +fkey}:
      CDesc{Nat.sub(m, 1n), ctx.vk(vkind(leaf_of(v, m), True{}), True{}, fkey, d, False{}, 1n+d, fctx.rem(fc, 1n+m, fkey))}

# S4.63 the context of one field of an object body at depth d
def ctx.field(+k: String, +v: J.Json, d: Nat, +fc: FCtx, sibs: T.KT) -> Ctx:
  ctx.field.of(fold(k, v, fc, sibs), k, v, d, fc)

# S4.44–S4.51 the first field of a list-item object at depth d: on the hyphen line, never folded, what
# it nests two levels deeper; an array of uniform objects may be tabular here (S4.48)
def ctx.first(k: String, +v: J.Json, +d: Nat, opt: Opts) -> Ctx:
  ctx.vk(vkind(v, True{}), True{}, k, d, True{}, 2n+d, fctx.item(opt))

# S4.40–S4.43 an item of a list array at depth d; an array that is itself a list item is never tabular
def ctx.item(+h: J.Json, +d: Nat, opt: Opts) -> Ctx:
  ctx.vk(vkind(h, False{}), False{}, SNil{}, d, True{}, 1n+d, fctx.item(opt))

# S4.60 the root value: no key, no hyphen, depth 0
def ctx.root(+j: J.Json, +opt: Opts) -> Ctx:
  ctx.vk(vkind(j, True{}), False{}, SNil{}, 0n, False{}, 1n, fctx.root(opt, j))

# S3.10 the active delimiter
def opt.delim(opt: Opts) -> U32:
  match opt:
    case Opts{indent, delim, fo, budget, spec}:
      delim

# S3.9 whether key folding is on
def opt.fold(opt: Opts) -> Bool:
  match opt:
    case Opts{indent, delim, fo, budget, spec}:
      fo

# S4.130 the numeric kill-switch (TOON_SPEC=1)
def opt.spec(opt: Opts) -> Bool:
  match opt:
    case Opts{indent, delim, fo, budget, spec}:
      spec

# S4.56 `key: ` in front of a value, when the line carries a key
def put.keycolon(hk: Bool, key: String, acc: String) -> String:
  match hk:
    case True{}:
      SCon{Chr{32}, SCon{Chr{58}, put.key(key, acc)}}
    case False{}:
      acc

# S4.40, S4.45, S4.56, S4.60 a primitive's line, reversed
def line.prim(hk: Bool, key: String, d: Nat, hy: Bool, v: J.Json, +opt: Opts) -> String:
  put.prim(v, opt.delim(opt), opt.spec(opt), put.keycolon(hk, key, ln(d, hy, opt)))

# S4.24 a header line (empty array, tabular header, list header), reversed
def line.hdr(hk: Bool, key: String, n: Nat, hdr: List<&2, String>, d: Nat, hy: Bool, +opt: Opts) -> String:
  put.header(hk, key, n, hdr, opt.delim(opt), ln(d, hy, opt))

# S4.29 an inline array line: the header, ONE space, the join; reversed
def line.inline(hk: Bool, key: String, n: Nat, items: J.Json, d: Nat, hy: Bool, +opt: Opts) -> String:
  put.join(items, opt.delim(opt), opt.spec(opt), True{}, SCon{Chr{32}, put.header(hk, key, n, Nil{}, opt.delim(opt), ln(d, hy, opt))})

# S4.58, S4.59, S4.50, S4.51 `key:` alone, reversed
def line.key(key: String, d: Nat, hy: Bool, opt: Opts) -> String:
  SCon{Chr{58}, put.key(key, ln(d, hy, opt))}

# S4.59 an empty object: `key:` when keyed; S4.43 `-` alone as a list item; S4.60 no line at the root
def lines.obj0(hk: Bool, hy: Bool, key: String, d: Nat, opt: Opts, acc: List<&2, String>) -> List<&2, String>:
  match hk hy:
    case True{} _:
      line.key(key, d, hy, opt) <> acc
    case False{} True{}:
      SCon{Chr{45}, ln(d, False{}, opt)} <> acc
    case False{} False{}:
      acc

# S4.30–S4.62 the lines of a node, newest first. ONE def over Json; `ctx` says what the node is.
# Every recursive call is on a matched part of `j`; sibling chains are tail calls.
def emit(j: J.Json, cx: Ctx, +opt: Opts, acc: List<&2, String>) -> List<&2, String>:
  match j cx:
    case v CPrim{hk, key, d, hy}:
      line.prim(hk, key, d, hy, v, opt) <> acc
    case v CArr0{hk, key, d, hy}:
      line.hdr(hk, key, 0n, Nil{}, d, hy, opt) <> acc
    case J.JArr{n, items} CInline{hk, key, d, hy}:
      line.inline(hk, key, n, items, d, hy, opt) <> acc
    case J.JArr{n, items} CTab{hk, key, d, hy, dc, +hdr}:
      rows(items, hdr, dc, opt, line.hdr(hk, key, n, hdr, d, hy, opt) <> acc)
    case J.JArr{n, items} CList{hk, key, d, hy, dc}:
      emit(items, CItems{dc}, opt, line.hdr(hk, key, n, Nil{}, d, hy, opt) <> acc)
    case v CObj0{hk, key, d, hy}:
      lines.obj0(hk, hy, key, d, opt, acc)
    case J.JObj{+entries} CObjK{key, d, hy, dc, +fc}:
      emit(entries, CFields{dc, fc, keys.kt(fc.on(fc), entries)}, opt, line.key(key, d, hy, opt) <> acc)
    case J.JObj{+entries} CObjRoot{+fc}:
      emit(entries, CFields{0n, fc, keys.kt(fc.on(fc), entries)}, opt, acc)
    case J.JObj{J.JECons{+k, q, +v, +rest}} CObjItem{+d}:
      emit(rest, CFields{1n+d, fctx.item(opt), T.kt.put(keys.kt(opt.fold(opt), rest), k)}, opt, emit(v, ctx.first(k, v, d, opt), opt, acc))
    case J.JObj{J.JECons{k, q, v, t}} CDesc{0n, leaf}:
      emit(v, leaf, opt, acc)
    case J.JObj{J.JECons{k, q, v, t}} CDesc{1n+p, leaf}:
      emit(v, CDesc{p, leaf}, opt, acc)
    case J.JECons{k, q, +v, t} CFields{+d, +fc, +sibs}:
      emit(t, CFields{d, fc, sibs}, opt, emit(v, ctx.field(k, v, d, fc, sibs), opt, acc))
    case J.JCons{+h, t} CItems{+d}:
      emit(t, CItems{d}, opt, emit(h, ctx.item(h, d, opt), opt, acc))
    case _ _:
      acc

# ---------------------------------------------------------------- EXP-007 numbers rendered in parallel
#
# Every number's text depends on that number alone, so a pass BEFORE emission renders them all and the
# emitter copies the text (JTxt). The pass forks an item chain of more than 64 items into halves with a
# parallel let, so the renderings run on the worker pool. A value the pass does not reach keeps its own
# node, which put.prim renders exactly as before: running out of fuel changes the speed, never the text.

# S4.130, S5.30, EXP-007 the text a number takes in the output being built: the TOON text when the pass
# runs before the encoder's emitter, the JSON text when it runs before the writer on the decode side
def num.text(js: Bool, f: F.F64, spec: Bool) -> String:
  match js:
    case True{}:
      F.show_json_fast(f, spec)
    case False{}:
      F.show_toon_fast(f, spec)

# S4.60, EXP-007 the pass's mode: a value; the rest of a chain, walked and collected onto acc; an item chain of
# n items; a chain cut in two, split when it is long
type PM is Data:
  PVal{}
  PSeq{}
  PPar{n: Nat}
  PCut{long: Bool, n: Nat, left: J.Json, right: J.Json}

# S4.60, EXP-007 the first k items of a chain, in order, and the rest
type PS is Data:
  PS{left: J.Json, right: J.Json}

# S4.60, EXP-007 take k items off a chain
def par.take(k: Nat, c: J.Json, acc: J.Json) -> PS:
  match k c:
    case 0n r:
      PS{J.rev_items(acc, J.JNil{}), r}
    case 1n+p J.JCons{h, t}:
      par.take(p, t, J.JCons{h, acc})
    case 1n+p r:
      PS{J.rev_items(acc, J.JNil{}), r}

# S4.60, EXP-007 a chain appended to another
def par.cat(a: J.Json, b: J.Json) -> J.Json:
  J.rev_items(J.rev_items(a, J.JNil{}), b)

# S4.60, EXP-007 a chain walked sequentially was collected newest first: items or entries
def par.back(acc: J.Json) -> J.Json:
  match acc:
    case J.JECons{k, q, v, t}:
      J.rev_entries(J.JECons{k, q, v, t}, J.JNil{})
    case other:
      J.rev_items(other, J.JNil{})

# S4.60, EXP-007 the cut of a chain of n items at n/2, split while it is longer than 64 items
def par.cut(+n: Nat, s: PS) -> PM:
  match s:
    case PS{l, r}:
      PCut{Nat.is_gt(n, 64n), n, l, r}

# S4.60, S4.130, EXP-007 one def over (fuel, value): a cut and a split each spend one unit of fuel, every other step
# descends into j
def pre(+fuel: Nat, j: J.Json, m: PM, acc: J.Json, +js: Bool, +spec: Bool) -> J.Json:
  match fuel j m:
    case f J.JNum{x} PVal{}:
      J.JTxt{num.text(js, x, spec)}
    case f J.JRaw{neg, ints, fracs, eneg, x} PVal{}:
      J.JTxt{num.text(js, J.raw.f64(neg, ints, fracs, eneg, x, spec), spec)}
    case f J.JArr{+n, items} PVal{}:
      J.JArr{n, pre(f, items, PPar{n}, J.JNil{}, js, spec)}
    case f J.JObj{e} PVal{}:
      J.JObj{pre(f, e, PSeq{}, J.JNil{}, js, spec)}
    case f J.JCons{h, t} PSeq{}:
      pre(f, t, PSeq{}, J.JCons{pre(f, h, PVal{}, J.JNil{}, js, spec), acc}, js, spec)
    case f J.JECons{k, q, v, t} PSeq{}:
      pre(f, t, PSeq{}, J.JECons{k, q, pre(f, v, PVal{}, J.JNil{}, js, spec), acc}, js, spec)
    case f J.JNil{} PSeq{}:
      par.back(acc)
    case 1n++p c PPar{+n}:
      pre(p, J.JNil{}, par.cut(n, par.take(Nat.div(n, 2n), c, J.JNil{})), acc, js, spec)
    case 1n++p z PCut{True{}, +n, l, r}:
      a b = pre(p, l, PPar{Nat.div(n, 2n)}, J.JNil{}, js, spec) pre(p, r, PPar{Nat.sub(n, Nat.div(n, 2n))}, J.JNil{}, js, spec)
      par.cat(a, b)
    case 1n++p z PCut{False{}, n, l, r}:
      pre(p, par.cat(l, r), PSeq{}, J.JNil{}, js, spec)
    case 0n z PCut{long, n, l, r}:
      par.cat(l, r)
    case f v m:
      v

# S8.2, EXP-007 the kill-switch: with TOON_SPEC=1 the value goes to the emitter untouched and every
# number takes its spec twin inside put.prim. This closes the EMITTER half of the pass only. The
# reader's half is not switchable: num.safe defers a token before any option is read, so the switch
# cannot restore an eager conversion, and the deferral must therefore be correct on its own rather
# than merely recoverable (R16-1, R16-5). num.safe's bounds carry that weight and are pinned by the
# five closed num_safe_* laws.
def pre.if(spec: Bool, js: Bool, j: J.Json) -> J.Json:
  match spec:
    case True{}:
      j
    case False{}:
      pre(64n, j, PVal{}, J.JNil{}, js, False{})

# S4.60 the TOON lines of a value, LAST first and each reversed, as emit collects them (an empty root
# object gives no line); S5.100's join builds the text forward from them (EXP-021)
def encode.go(+j: J.Json, +opt: Opts) -> List<&2, String>:
  emit(j, ctx.root(j, opt), opt, Nil{})

# S4.60, EXP-007 the numbers are rendered first (in parallel), then the lines are emitted: last first,
# each reversed (EXP-021)
def encode(j: J.Json, +opt: Opts) -> List<&2, String>:
  encode.go(pre.if(opt.spec(opt), False{}, j), opt)
