# decode.bend — TOON text to a Json value: the line scanner, the token rules, the array-header parser,
# the structural decoder (a pushdown machine over the scanned lines) and safe path expansion.
#
# Spec: docs/EXISTING_Toon_STRUCTURE.md S2.100–S2.150, S3.20–S3.29, S4.200–S4.249, S9.100–S9.147.
#
# The decoder attaches each finished value to its parent in exactly the order of the event sequence of
# S3.20–S3.22 (start, keys and values in document order, end); the value it builds keeps repeated keys
# (S3.25) and whether each key was quoted (S3.27), which is all either JSON writer and the expansion ask.
# Dispatch is on Nat codes, never on U32 literals (bend #867).

import Base
import ./text.bend as T
import ./f64.bend as F
import ./json.bend as J

# ---------------------------------------------------------------- S2.102–S2.112 the scanner

# S3.29 a non-blank line as the structural decoder sees it: 1-based number, depth, content
type Line is Data:
  Line{num: Nat, depth: Nat, content: String}

# S2.111 the scan of the WHOLE text: the non-blank lines and the blank-line numbers, both in document
# order, or the first strict-mode failure
type Scan is Data:
  ScanOk{lines: List<&2, Line>, blanks: List<&2, Nat>}
  ScanErr{msg: String}

# S2.104, S2.108 scanner state inside one line: its number; whether the leading U+0020 run is still
# going (lead) and its length (indent); whether the leading space/TAB run is still going (run) and has
# met a TAB (tab); the content so far, reversed; the lines and blank-line numbers so far, newest first;
# the first failure
type SS is Data:
  SS{num: Nat, lead: Bool, indent: Nat, run: Bool, tab: Bool, rev: String, lines: List<&2, Line>, blanks: List<&2, Nat>, err: Maybe<&2, String>}

# S2.107 depth = floor(indent / I), and 0 when I = 0
def scan.depth(indent: Nat, unit: Nat) -> Nat:
  match unit:
    case 0n:
      0n
    case 1n+p:
      Nat.div(indent, 1n+p)

# S9.101, S9.102 the two indentation messages (the word is always `spaces`)
def scan.indent_msg(zero: Bool, bad: Bool, num: Nat, unit: Nat, indent: Nat) -> Maybe<&2, String>:
  match zero bad:
    case True{} True{}:
      Some{"Validation error at line " ++ Nat.show(num) ++ ": Indentation not allowed when indent size is 0, but found " ++ Nat.show(indent) ++ " spaces"}
    case False{} True{}:
      Some{"Validation error at line " ++ Nat.show(num) ++ ": Indentation must be exact multiple of " ++ Nat.show(unit) ++ ", but found " ++ Nat.show(indent) ++ " spaces"}
    case _ False{}:
      None{}

# S2.108–S2.111 the strict checks of one non-blank line: an earlier failure stays; the tab check comes
# before the indentation check. With I = 0 any indent fails (S2.109); with I >= 1 a non-multiple fails
def scan.check(err: Maybe<&2, String>, strict: Bool, tab: Bool, num: Nat, +unit: Nat, +indent: Nat) -> Maybe<&2, String>:
  match err strict tab:
    case Some{e} _ _:
      Some{e}
    case None{} False{} _:
      None{}
    case None{} True{} True{}:
      Some{"Validation error at line " ++ Nat.show(num) ++ ": Tabs are not allowed in indentation in strict mode"}
    case None{} True{} False{}:
      scan.indent_msg(Nat.is_eq(unit, 0n), Bool.and(Nat.is_gt(indent, 0n), Bool.or(Nat.is_eq(unit, 0n), Bool.not(Nat.is_eq(Nat.mod(indent, Nat.max(unit, 1n)), 0n)))), num, unit, indent)

# S2.105 a finished line: a blank line only leaves its number; any other line is checked and kept
def scan.line(blank: Bool, +num: Nat, +indent: Nat, tab: Bool, content: String, lines: List<&2, Line>, blanks: List<&2, Nat>, err: Maybe<&2, String>, strict: Bool, +unit: Nat) -> SS:
  match blank:
    case True{}:
      SS{1n+num, True{}, 0n, True{}, False{}, SNil{}, lines, num <> blanks, err}
    case False{}:
      SS{1n+num, True{}, 0n, True{}, False{}, SNil{}, Line{num, scan.depth(indent, unit), content} <> lines, blanks, scan.check(err, strict, tab, num, unit, indent)}

# S2.105 blank means: empty after WS-trim
def scan.end.with(+content: String, num: Nat, indent: Nat, tab: Bool, lines: List<&2, Line>, blanks: List<&2, Nat>, err: Maybe<&2, String>, strict: Bool, unit: Nat) -> SS:
  scan.line(T.is_blank(content), num, indent, tab, content, lines, blanks, err, strict, unit)

# S2.102 the end of a line (an LF, or the end of the text)
def scan.end(st: SS, strict: Bool, unit: Nat) -> SS:
  match st:
    case SS{num, lead, indent, run, tab, rev, lines, blanks, err}:
      scan.end.with(String.reverse(rev), num, indent, tab, lines, blanks, err, strict, unit)

# S2.104 one character inside a line. k: 2 U+0020, 3 TAB, 0 anything else. A space extends the indent
# while only spaces came before; a TAB anywhere in the leading space/TAB run is remembered (S2.108)
def scan.tr(k: Nat, lead: Bool, run: Bool, c: U32, num: Nat, indent: Nat, tab: Bool, rev: String, lines: List<&2, Line>, blanks: List<&2, Nat>, err: Maybe<&2, String>) -> SS:
  match k lead run:
    case 2n True{} r:
      SS{num, True{}, 1n+indent, r, tab, rev, lines, blanks, err}
    case 2n False{} r:
      SS{num, False{}, indent, r, tab, SCon{Chr{32}, rev}, lines, blanks, err}
    case 3n l True{}:
      SS{num, False{}, indent, True{}, True{}, SCon{Chr{9}, rev}, lines, blanks, err}
    case _ l r:
      SS{num, False{}, indent, False{}, tab, SCon{Chr{c}, rev}, lines, blanks, err}

# S2.102, S2.104 one character: LF ends the line (CR does not, S2.113); anything else joins the line
def scan.ch(lf: Bool, st: SS, +c: U32, strict: Bool, unit: Nat) -> SS:
  match lf st:
    case True{} s:
      scan.end(s, strict, unit)
    case False{} SS{num, lead, indent, run, tab, rev, lines, blanks, err}:
      scan.tr(Bool.pick(Nat, U32.is_eq(c, 32), 2n, Bool.pick(Nat, U32.is_eq(c, 9), 3n, 0n)), lead, run, c, num, indent, tab, rev, lines, blanks, err)

# S2.111 the whole text, character by character (a loop over the text)
def scan.go(s: String, st: SS, +strict: Bool, +unit: Nat) -> SS:
  match s:
    case SNil{}:
      scan.end(st, strict, unit)
    case SCon{Chr{+c}, rest}:
      scan.go(rest, scan.ch(U32.is_eq(c, 10), st, c, strict, unit), strict, unit)

# S2.111 the first failure wins over every line; otherwise the lines and blank numbers in document order
def scan.done(st: SS) -> Scan:
  match st:
    case SS{num, lead, indent, run, tab, rev, lines, blanks, Some{e}}:
      ScanErr{e}
    case SS{num, lead, indent, run, tab, rev, lines, blanks, None{}}:
      ScanOk{List.reverse(&2, Line, lines), List.reverse(&2, Nat, blanks)}

# S2.102–S2.112 scan a text with indent size `unit`
def scan(text: String, strict: Bool, unit: Nat) -> Scan:
  scan.done(scan.go(text, SS{1n, True{}, 0n, True{}, False{}, SNil{}, Nil{}, Nil{}, None{}}, strict, unit))

# ---------------------------------------------------------------- S2.120–S2.126 tokens

# S2.122 a text, or the message of the first failure
type RS is Data:
  RSOk{s: String}
  RSErr{msg: String}

# S2.124 a value, or the message of the first failure
type RV is Data:
  RVOk{v: J.Json}
  RVErr{msg: String}

# S2.120 the closing-quote search from just after an opening quote: whether a closing quote exists, the
# raw text before it (escapes intact) and the text after it
type QS is Data:
  QS{found: Bool, inner: String, after: String}

# S2.120 the class of the head of a text: 1 a double quote, 2 a backslash, 0 anything else or the end
def quote.cls(s: String) -> Nat:
  match s:
    case SNil{}:
      0n
    case SCon{Chr{+c}, rest}:
      Bool.pick(Nat, U32.is_eq(c, 34), 1n, Bool.pick(Nat, U32.is_eq(c, 92), 2n, 0n))

# S2.120 the loop: k is the class of the head of `s` (computed by the caller, so the walk stops at the
# closing quote); a backslash takes the next character with it; a backslash at the very end pairs with
# nothing and the search fails
def quote.go(s: String, k: Nat, esc: Bool, rev: String) -> QS:
  match s k esc:
    case SNil{} _ _:
      QS{False{}, String.reverse(rev), SNil{}}
    case SCon{c, +rest} _ True{}:
      quote.go(rest, quote.cls(rest), False{}, SCon{c, rev})
    case SCon{c, rest} 1n False{}:
      QS{True{}, String.reverse(rev), rest}
    case SCon{c, +rest} 2n False{}:
      quote.go(rest, quote.cls(rest), True{}, SCon{c, rev})
    case SCon{c, +rest} _ False{}:
      quote.go(rest, quote.cls(rest), False{}, SCon{c, rev})

# S2.120 search the closing quote in the text that follows an opening quote
def quote.close(+s: String) -> QS:
  quote.go(s, quote.cls(s), False{}, SNil{})

# S2.123 unescaper state: inside an escape; the text so far, reversed; the first bad escape character
type UE is Data:
  UE{esc: Bool, rev: String, bad: Bool, badc: U32}

# S2.123 exactly five escapes. k: 1 'n', 2 't', 3 'r', 4 backslash, 5 double quote, 0 anything else
def unesc.tr(bad: Bool, esc: Bool, k: Nat, c: U32, rev: String, badc: U32) -> UE:
  match bad esc k:
    case True{} e _:
      UE{e, rev, True{}, badc}
    case False{} True{} 1n:
      UE{False{}, SCon{Chr{10}, rev}, False{}, badc}
    case False{} True{} 2n:
      UE{False{}, SCon{Chr{9}, rev}, False{}, badc}
    case False{} True{} 3n:
      UE{False{}, SCon{Chr{13}, rev}, False{}, badc}
    case False{} True{} 4n:
      UE{False{}, SCon{Chr{92}, rev}, False{}, badc}
    case False{} True{} 5n:
      UE{False{}, SCon{Chr{34}, rev}, False{}, badc}
    case False{} True{} _:
      UE{False{}, rev, True{}, c}
    case False{} False{} 4n:
      UE{True{}, rev, False{}, badc}
    case False{} False{} _:
      UE{False{}, SCon{Chr{c}, rev}, False{}, badc}

# S2.123 the class of a character for the unescaper
def unesc.cls(+c: U32) -> Nat:
  Bool.pick(Nat, U32.is_eq(c, 110), 1n, Bool.pick(Nat, U32.is_eq(c, 116), 2n, Bool.pick(Nat, U32.is_eq(c, 114), 3n, Bool.pick(Nat, U32.is_eq(c, 92), 4n, Bool.pick(Nat, U32.is_eq(c, 34), 5n, 0n)))))

# S2.123 one character
def unesc.ch(st: UE, +c: U32) -> UE:
  match st:
    case UE{esc, rev, bad, badc}:
      unesc.tr(bad, esc, unesc.cls(c), c, rev, badc)

# S2.123 the whole text (a loop over the text)
def unesc.go(s: String, st: UE) -> UE:
  match s:
    case SNil{}:
      st
    case SCon{Chr{c}, rest}:
      unesc.go(rest, unesc.ch(st, c))

# S9.105 the first bad escape from the left names its character, written raw; S9.131 the trailing
# backslash message exists in the original but no input reaches it
def unesc.fin(st: UE) -> RS:
  match st:
    case UE{esc, rev, True{}, badc}:
      RSErr{"Invalid escape sequence: \\" ++ SCon{Chr{badc}, SNil{}}}
    case UE{True{}, rev, False{}, badc}:
      RSErr{"Invalid escape sequence: backslash at end of string"}
    case UE{False{}, rev, False{}, badc}:
      RSOk{String.reverse(rev)}

# S2.123 unescape the text between two quotes
def unesc(s: String) -> RS:
  unesc.fin(unesc.go(s, UE{False{}, SNil{}, False{}, 0}))

# S2.122 a string literal after its opening quote: S9.103 without a closing quote, S9.104 when the
# closing quote is not the last character of the (trimmed) token
def lit.q(q: QS) -> RS:
  match q:
    case QS{False{}, inner, after}:
      RSErr{"Unterminated string: missing closing quote"}
    case QS{True{}, inner, SNil{}}:
      unesc(inner)
    case QS{True{}, inner, SCon{c, more}}:
      RSErr{"Unexpected characters after closing quote"}

# S2.122 the text a string literal denotes, given the token after its opening quote
def lit(s: String) -> RS:
  lit.q(quote.close(s))

# S2.124 a string literal as a value
def prim.lit(r: RS) -> RV:
  match r:
    case RSOk{s}:
      RVOk{J.JStr{s}}
    case RSErr{msg}:
      RVErr{msg}

# S2.124 (4), (5) a finite numeric literal is a number; anything else is the trimmed token, verbatim
def prim.num(m: Maybe<&2, F.F64>, t: String) -> RV:
  match m:
    case Some{f}:
      RVOk{J.JNum{f}}
    case None{}:
      RVOk{J.JStr{t}}

# S2.124 (3) exactly true, false or null, case-sensitive
def prim.word(tr: Bool, fa: Bool, nu: Bool, +t: String) -> RV:
  match tr fa nu:
    case True{} _ _:
      RVOk{J.JBool{True{}}}
    case False{} True{} _:
      RVOk{J.JBool{False{}}}
    case False{} False{} True{}:
      RVOk{J.JNull{}}
    case False{} False{} False{}:
      prim.num(F.literal(t), t)

# S2.124 a bare token: a word, a number, or itself
def prim.bare(+t: String) -> RV:
  prim.word(T.str_eq(t, "true"), T.str_eq(t, "false"), T.str_eq(t, "null"), t)

# S2.124 (2) a token that starts with a double quote is a string literal, errors included
def prim.first(q: Bool, c: U32, rest: String) -> RV:
  match q:
    case True{}:
      prim.lit(lit(rest))
    case False{}:
      prim.bare(SCon{Chr{c}, rest})

# S2.124 the primitive a TRIMMED token denotes; (1) the empty token is the empty string
def prim.t(t: String) -> RV:
  match t:
    case SNil{}:
      RVOk{J.JStr{SNil{}}}
    case SCon{Chr{+c}, rest}:
      prim.first(U32.is_eq(c, 34), c, rest)

# S2.124 the primitive a token denotes
def prim(token: String) -> RV:
  prim.t(T.trim(token))

# S2.125 splitter state: inside quotes; the previous character was a backslash inside quotes; the
# current value, reversed; the finished values, newest first
type DS is Data:
  DS{inq: Bool, esc: Bool, cur: String, vals: List<&2, String>}

# S2.125 one character. k: 1 double quote, 2 backslash, 3 the active delimiter, 0 anything else.
# Quotes and backslashes stay in the value text; every finished value is WS-trimmed
def split.tr(inq: Bool, esc: Bool, k: Nat, c: U32, cur: String, vals: List<&2, String>) -> DS:
  match inq esc k:
    case True{} True{} _:
      DS{True{}, False{}, SCon{Chr{c}, cur}, vals}
    case True{} False{} 2n:
      DS{True{}, True{}, SCon{Chr{c}, cur}, vals}
    case True{} False{} 1n:
      DS{False{}, False{}, SCon{Chr{c}, cur}, vals}
    case True{} False{} _:
      DS{True{}, False{}, SCon{Chr{c}, cur}, vals}
    case False{} e 1n:
      DS{True{}, False{}, SCon{Chr{c}, cur}, vals}
    case False{} e 3n:
      DS{False{}, False{}, SNil{}, T.trim(String.reverse(cur)) <> vals}
    case False{} e _:
      DS{False{}, False{}, SCon{Chr{c}, cur}, vals}

# S2.125 the class of a character for the splitter
def split.cls(+c: U32, delim: U32) -> Nat:
  Bool.pick(Nat, U32.is_eq(c, delim), 3n, Bool.pick(Nat, U32.is_eq(c, 34), 1n, Bool.pick(Nat, U32.is_eq(c, 92), 2n, 0n)))

# S2.125 one character
def split.ch(st: DS, +c: U32, delim: U32) -> DS:
  match st:
    case DS{inq, esc, cur, vals}:
      split.tr(inq, esc, split.cls(c, delim), c, cur, vals)

# S2.125 the whole text (a loop over the text)
def split.go(s: String, st: DS, +delim: U32) -> DS:
  match s:
    case SNil{}:
      st
    case SCon{Chr{c}, rest}:
      split.go(rest, split.ch(st, c, delim), delim)

# S2.125 the last value ends at the end of the text (an unclosed quote has swallowed the rest)
def split.fin(st: DS) -> List<&2, String>:
  match st:
    case DS{inq, esc, cur, vals}:
      List.reverse(&2, String, T.trim(String.reverse(cur)) <> vals)

# S2.125 the values of a delimited text: none for the empty text, otherwise one more than the number
# of unquoted delimiters
def split(text: String, delim: U32) -> List<&2, String>:
  match text:
    case SNil{}:
      Nil{}
    case SCon{c, rest}:
      split.fin(split.go(SCon{c, rest}, DS{False{}, False{}, SNil{}, Nil{}}, delim))

# S2.121 the unquoted-character search: whether (and where) the first ':' and the first active
# delimiter stand outside quotes
type UQ is Data:
  UQ{colon: Bool, cpos: Nat, dl: Bool, dpos: Nat}

# S2.121 search state: inside quotes, after a backslash inside quotes, the index of the character
type US is Data:
  US{inq: Bool, esc: Bool, idx: Nat, colon: Bool, cpos: Nat, dl: Bool, dpos: Nat}

# S2.121 the first hit keeps its position
def uq.pos(found: Bool, pos: Nat, idx: Nat) -> Nat:
  match found:
    case True{}:
      pos
    case False{}:
      idx

# S2.121 one character. k: 1 double quote, 2 backslash, 3 ':', 4 the active delimiter, 0 anything else.
# Every quote flips the state; inside quotes a backslash skips the next character; outside quotes a
# backslash is ordinary
def uq.tr(inq: Bool, esc: Bool, k: Nat, +idx: Nat, +colon: Bool, cpos: Nat, +dl: Bool, dpos: Nat) -> US:
  match inq esc k:
    case True{} True{} _:
      US{True{}, False{}, 1n+idx, colon, cpos, dl, dpos}
    case True{} False{} 2n:
      US{True{}, True{}, 1n+idx, colon, cpos, dl, dpos}
    case True{} False{} 1n:
      US{False{}, False{}, 1n+idx, colon, cpos, dl, dpos}
    case True{} False{} _:
      US{True{}, False{}, 1n+idx, colon, cpos, dl, dpos}
    case False{} e 1n:
      US{True{}, False{}, 1n+idx, colon, cpos, dl, dpos}
    case False{} e 3n:
      US{False{}, False{}, 1n+idx, True{}, uq.pos(colon, cpos, idx), dl, dpos}
    case False{} e 4n:
      US{False{}, False{}, 1n+idx, colon, cpos, True{}, uq.pos(dl, dpos, idx)}
    case False{} e _:
      US{False{}, False{}, 1n+idx, colon, cpos, dl, dpos}

# S2.121 the class of a character for the search (the delimiter is tested first: it may be any of , TAB |)
def uq.cls(+c: U32, delim: U32) -> Nat:
  Bool.pick(Nat, U32.is_eq(c, delim), 4n, Bool.pick(Nat, U32.is_eq(c, 58), 3n, Bool.pick(Nat, U32.is_eq(c, 34), 1n, Bool.pick(Nat, U32.is_eq(c, 92), 2n, 0n))))

# S2.121 one character
def uq.ch(st: US, +c: U32, delim: U32) -> US:
  match st:
    case US{inq, esc, idx, colon, cpos, dl, dpos}:
      uq.tr(inq, esc, uq.cls(c, delim), idx, colon, cpos, dl, dpos)

# S2.121 the whole text (a loop over the text)
def uq.go(s: String, st: US, +delim: U32) -> US:
  match s:
    case SNil{}:
      st
    case SCon{Chr{c}, rest}:
      uq.go(rest, uq.ch(st, c, delim), delim)

# S2.121 the verdict of a finished search
def uq.fin(st: US) -> UQ:
  match st:
    case US{inq, esc, idx, colon, cpos, dl, dpos}:
      UQ{colon, cpos, dl, dpos}

# S2.121 search a text for ':' and for `delim` outside quotes
def uq(s: String, delim: U32) -> UQ:
  uq.fin(uq.go(s, US{False{}, False{}, 0n, False{}, 0n, False{}, 0n}, delim))

# S4.202, S4.224 whether a text has a ':' outside quotes (4294967295 is no character, so no delimiter)
def has_colon.of(u: UQ) -> Bool:
  match u:
    case UQ{colon, cpos, dl, dpos}:
      colon

# S4.202, S4.224 whether a text has a ':' outside quotes
def has_colon(s: String) -> Bool:
  has_colon.of(uq(s, 4294967295))

# S4.214 a data row: no unquoted colon, or an unquoted delimiter before the first unquoted colon
def is_row.of(u: UQ) -> Bool:
  match u:
    case UQ{False{}, cpos, dl, dpos}:
      True{}
    case UQ{True{}, cpos, False{}, dpos}:
      False{}
    case UQ{True{}, cpos, True{}, dpos}:
      Nat.is_lt(dpos, cpos)

# S4.214 the data-row test with the table's own delimiter
def is_row(s: String, delim: U32) -> Bool:
  is_row.of(uq(s, delim))

# S2.126 a key-value content: the key, whether it was quoted, the value text (WS-trimmed); or a message
type KV is Data:
  KVOk{key: String, quoted: Bool, val: String}
  KVErr{msg: String}

# S2.126 a quoted key: its escapes are interpreted FIRST (S9.105 surfaces even when no ':' follows);
# then the character right after the closing quote must be ':' (S9.106)
def kv.quoted.key(r: RS, colon: Bool, after: String) -> KV:
  match r colon after:
    case RSErr{msg} _ _:
      KVErr{msg}
    case RSOk{k} True{} SCon{c, val}:
      KVOk{k, True{}, T.trim(val)}
    case RSOk{k} _ _:
      KVErr{"Missing colon after key"}

# S2.126 a content whose FIRST character is a double quote; S9.130 the message without a closing quote
# exists in the original but the header parse reports S9.103 first
def kv.quoted(q: QS) -> KV:
  match q:
    case QS{False{}, inner, after}:
      KVErr{"Unterminated quoted key"}
    case QS{True{}, inner, +after}:
      kv.quoted.key(unesc(inner), T.head_is(after, 58), after)

# S2.126 an unquoted key is everything before the FIRST ':' (no quote awareness), WS-trimmed
def kv.plain(c: T.Cut) -> KV:
  match c:
    case T.Cut{False{}, before, after}:
      KVErr{"Missing colon after key"}
    case T.Cut{True{}, before, after}:
      KVOk{T.trim(before), False{}, T.trim(after)}

# S2.126 the first character decides
def kv.first(q: Bool, c: U32, rest: String) -> KV:
  match q:
    case True{}:
      kv.quoted(quote.close(rest))
    case False{}:
      kv.plain(T.cut(SCon{Chr{c}, rest}, 58))

# S2.126 the key token and the value text of a key-value content
def kv(content: String) -> KV:
  match content:
    case SNil{}:
      KVErr{"Missing colon after key"}
    case SCon{Chr{+c}, rest}:
      kv.first(U32.is_eq(c, 34), c, rest)

# S2.140 a list item: exactly `-`, or starting with `- `
def is_item(s: String) -> Bool:
  match s:
    case SCon{Chr{a}, SNil{}}:
      U32.is_eq(a, 45)
    case SCon{Chr{a}, SCon{Chr{b}, rest}}:
      Bool.and(U32.is_eq(a, 45), U32.is_eq(b, 32))
    case other:
      False{}

# S4.213, S4.215, S4.225 whether a content starts with `- `
def is_dash_sp(s: String) -> Bool:
  match s:
    case SCon{Chr{a}, SCon{Chr{b}, rest}}:
      Bool.and(U32.is_eq(a, 45), U32.is_eq(b, 32))
    case other:
      False{}

# ---------------------------------------------------------------- S2.130–S2.139 the array header

# S2.137 a tabular field name and whether it was written in quotes
type Field is Data:
  Field{name: String, quoted: Bool}

# S2.130–S2.138 the outcome of offering a content to the header parser: not a header (silently), a
# failure that surfaces, or a header: its key (when it has one) and whether the key was quoted, the
# declared length, the delimiter, whether a fields segment exists (even an empty one, S4.223), the
# field names, and the inline text (WS-trimmed; empty when there is none)
type Hdr is Data:
  HNot{}
  HErr{msg: String}
  HOk{has_key: Bool, key: String, quoted: Bool, n: Nat, delim: U32, has_seg: Bool, fields: List<&2, Field>, inline: String}

# S2.137 the field names read so far (newest first), or the first failure from the left
type FRes is Data:
  FROk{rev: List<&2, Field>}
  FRErr{msg: String}

# S2.137 a quoted field name after its literal was read
def field.put(r: RS, rev: List<&2, Field>) -> FRes:
  match r:
    case RSOk{s}:
      FROk{Field{s, True{}} <> rev}
    case RSErr{msg}:
      FRErr{msg}

# S2.137 a piece starting with a double quote is a string literal; any other piece is the name verbatim
def field.first(q: Bool, c: U32, rest: String, rev: List<&2, Field>) -> FRes:
  match q:
    case True{}:
      field.put(lit(rest), rev)
    case False{}:
      FROk{Field{SCon{Chr{c}, rest}, False{}} <> rev}

# S2.137 one piece (already WS-trimmed by the splitter); the empty piece is the empty name
def field.one(name: String, rev: List<&2, Field>) -> FRes:
  match name:
    case SNil{}:
      FROk{Field{SNil{}, False{}} <> rev}
    case SCon{Chr{+c}, rest}:
      field.first(U32.is_eq(c, 34), c, rest, rev)

# S2.137 every piece in order; the first failure ends the walk
def fields.go(names: List<&2, String>, st: FRes) -> FRes:
  match names st:
    case Nil{} s:
      s
    case Con{nm, rest} FRErr{msg}:
      FRErr{msg}
    case Con{nm, rest} FROk{rev}:
      fields.go(rest, field.one(nm, rev))

# S2.139 (6) the header is complete unless a field name fails
def hdr.g(fr: FRes, has_key: Bool, key: String, quoted: Bool, n: Nat, delim: U32, has_seg: Bool, inline: String) -> Hdr:
  match fr:
    case FRErr{msg}:
      HErr{msg}
    case FROk{rev}:
      HOk{has_key, key, quoted, n, delim, has_seg, List.reverse(&2, Field, rev), inline}

# S7.34 the value of a short digit string
def nat.of(s: String, acc: Nat) -> Nat:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{c}, rest}:
      nat.of(rest, Nat.add(Nat.mul(acc, 10n), U32.to_nat((c - 48 : U32))))

# S2.136 the cap: a canonical length above 100000000 fails in both modes (S9.107 prints it as parsed,
# without `+` and without leading zeros); S2.137 then the field names, split with the header's delimiter
def hdr.f(over: Bool, +digits: String, has_key: Bool, key: String, quoted: Bool, +delim: U32, has_seg: Bool, seg: String, inline: String) -> Hdr:
  match over:
    case True{}:
      HErr{"Declared array length " ++ digits ++ " exceeds maximum allowed (100000000)"}
    case False{}:
      hdr.g(fields.go(split(seg, delim), FROk{Nil{}}), has_key, key, quoted, nat.of(digits, 0n), delim, has_seg, inline)

# S2.135 what stands between the brackets: usable or not, the delimiter, the canonical digits
type HL is Data:
  HL{ok: Bool, delim: U32, digits: String}

# S2.135 the loop of all_digits: stops at the first character that is not an ASCII digit
def all_digits.go(s: String, ok: Bool) -> Bool:
  match s ok:
    case _ False{}:
      False{}
    case SNil{} True{}:
      True{}
    case SCon{Chr{+c}, rest} True{}:
      all_digits.go(rest, Bool.and(U32.is_ge(c, 48), U32.is_le(c, 57)))

# S2.135 one or more ASCII digits
def all_digits(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{c, rest}:
      all_digits.go(SCon{c, rest}, True{})

# S2.135 leading zeros are fine: `03` is 3, `000` is 0
def len.canon(z: String) -> String:
  match z:
    case SNil{}:
      "0"
    case SCon{c, rest}:
      SCon{c, rest}

# S2.135, S7.34 a canonical digit string fits the original's 64-bit word up to 18446744073709551615
def len.fits(+d: String) -> Bool:
  Bool.or(Nat.is_lt(T.str_len(d, 0n), 20n), Bool.and(Nat.is_eq(T.str_len(d, 0n), 20n), String.is_le(d, "18446744073709551615")))

# S2.135 the digits after the optional single '+'
def len.body(ok: Bool, +digits: String, delim: U32) -> HL:
  match ok:
    case False{}:
      HL{False{}, delim, SNil{}}
    case True{}:
      HL{len.fits(len.canon(F.strip_zeros(digits))), delim, len.canon(F.strip_zeros(digits))}

# S2.135 an optional single '+'
def len.plus(plus: Bool, +c: U32, +rest: String, delim: U32) -> HL:
  match plus:
    case True{}:
      len.body(all_digits(rest), rest, delim)
    case False{}:
      len.body(all_digits(SCon{Chr{c}, rest}), SCon{Chr{c}, rest}, delim)

# S2.135 the length text once the delimiter mark is gone; empty is not a length
def len.text(s: String, delim: U32) -> HL:
  match s:
    case SNil{}:
      HL{False{}, delim, SNil{}}
    case SCon{Chr{+c}, rest}:
      len.plus(U32.is_eq(c, 43), c, rest, delim)

# S2.135 the LAST character between the brackets selects TAB or '|' (exactly one such character is
# removed); anything else means comma and stays part of the length text
def len.mark(tab: Bool, pipe: Bool, c: U32, more: String) -> HL:
  match tab pipe:
    case True{} _:
      len.text(String.reverse(more), 9)
    case False{} True{}:
      len.text(String.reverse(more), 124)
    case False{} False{}:
      len.text(String.reverse(SCon{Chr{c}, more}), 44)

# S2.135 the bracket content, read from its last character
def len.rev(r: String) -> HL:
  match r:
    case SNil{}:
      HL{False{}, 44, SNil{}}
    case SCon{Chr{+c}, more}:
      len.mark(U32.is_eq(c, 9), U32.is_eq(c, 124), c, more)

# S2.136 more than nine canonical digits is above the cap without looking at the value (the value of a
# longer string may not fit a Nat, and arguments are evaluated eagerly)
def len.over(long: Bool, digits: String) -> Bool:
  match long:
    case True{}:
      True{}
    case False{}:
      Nat.is_gt(nat.of(digits, 0n), 100000000n)

# S2.139 (4) bad bracket content is "not a header", silently; (5) then the cap
def hdr.e(l: HL, has_key: Bool, key: String, quoted: Bool, has_seg: Bool, seg: String, inline: String) -> Hdr:
  match l:
    case HL{False{}, delim, digits}:
      HNot{}
    case HL{True{}, delim, +digits}:
      hdr.f(len.over(Nat.is_gt(T.str_len(digits, 0n), 9n), digits), digits, has_key, key, quoted, delim, has_seg, seg, inline)

# S2.139 (3) the escapes of a quoted key are interpreted before the bracket content is looked at
def hdr.d.quoted(r: RS, inside: String, has_seg: Bool, seg: String, inline: String) -> Hdr:
  match r:
    case RSErr{msg}:
      HErr{msg}
    case RSOk{key}:
      hdr.e(len.rev(String.reverse(inside)), True{}, key, True{}, has_seg, seg, inline)

# S2.134 an unquoted key is the text before the bracket, WS-trimmed, verbatim; empty means no key
def hdr.d.plain(+key: String, inside: String, has_seg: Bool, seg: String, inline: String) -> Hdr:
  hdr.e(len.rev(String.reverse(inside)), Bool.not(String.is_empty(key)), key, False{}, has_seg, seg, inline)

# S2.134 the key
def hdr.d(quoted: Bool, keyraw: String, inside: String, has_seg: Bool, seg: String, inline: String) -> Hdr:
  match quoted:
    case True{}:
      hdr.d.quoted(unesc(keyraw), inside, has_seg, seg, inline)
    case False{}:
      hdr.d.plain(T.trim(keyraw), inside, has_seg, seg, inline)

# S2.132 with a fields segment, the header colon is the first ':' after its '}'
def hdr.c.colon(hc: T.Cut, quoted: Bool, keyraw: String, inside: String, seg: String) -> Hdr:
  match hc:
    case T.Cut{False{}, before, after}:
      HNot{}
    case T.Cut{True{}, before, after}:
      hdr.d(quoted, keyraw, inside, True{}, seg, T.trim(after))

# S2.132 a '{' before the first ':' opens a fields segment only when a '}' follows it; otherwise the
# first ':' after the ']' is the header colon and there is no segment
def hdr.c.close(r: T.Cut, plain_inline: String, quoted: Bool, keyraw: String, inside: String) -> Hdr:
  match r:
    case T.Cut{False{}, before, after}:
      hdr.d(quoted, keyraw, inside, False{}, SNil{}, T.trim(plain_inline))
    case T.Cut{True{}, seg, after}:
      hdr.c.colon(T.cut(after, 58), quoted, keyraw, inside, seg)

# S2.132 the text after the first '{'
def hdr.c.open(b: T.Cut, plain_inline: String, quoted: Bool, keyraw: String, inside: String) -> Hdr:
  match b:
    case T.Cut{found, before, after}:
      hdr.c.close(T.cut(after, 125), plain_inline, quoted, keyraw, inside)

# S2.132 whether a '{' stands before the first ':' after the ']'
def hdr.c.brace(brace: Bool, +tail: String, plain_inline: String, quoted: Bool, keyraw: String, inside: String) -> Hdr:
  match brace:
    case False{}:
      hdr.d(quoted, keyraw, inside, False{}, SNil{}, T.trim(plain_inline))
    case True{}:
      hdr.c.open(T.cut(tail, 123), plain_inline, quoted, keyraw, inside)

# S2.132 no ':' after the ']' means not a header (plain searches, not quote-aware)
def hdr.c(c: T.Cut, tail: String, quoted: Bool, keyraw: String, inside: String) -> Hdr:
  match c:
    case T.Cut{False{}, before, after}:
      HNot{}
    case T.Cut{True{}, before, after}:
      hdr.c.brace(T.has_char(before, 123), tail, after, quoted, keyraw, inside)

# S2.131 the first ']' after the bracket closes it; none means not a header
def hdr.b(r: T.Cut, quoted: Bool, keyraw: String) -> Hdr:
  match r:
    case T.Cut{False{}, before, after}:
      HNot{}
    case T.Cut{True{}, inside, +tail}:
      hdr.c(T.cut(tail, 58), tail, quoted, keyraw, inside)

# S2.130 a quoted key: the character right after its closing quote must be '['
def hdr.a.after(bracket: Bool, inner: String, after: String) -> Hdr:
  match bracket after:
    case True{} SCon{c, rest}:
      hdr.b(T.cut(rest, 93), True{}, inner)
    case _ _:
      HNot{}

# S2.139 (1) a leading double quote without a closing quote is S9.103
def hdr.a.quoted(q: QS) -> Hdr:
  match q:
    case QS{False{}, inner, after}:
      HErr{"Unterminated string: missing closing quote"}
    case QS{True{}, inner, +after}:
      hdr.a.after(T.head_is(after, 91), inner, after)

# S2.130 without a leading quote the bracket is the first '[' anywhere in the content
def hdr.a.plain(c: T.Cut) -> Hdr:
  match c:
    case T.Cut{False{}, before, after}:
      HNot{}
    case T.Cut{True{}, before, after}:
      hdr.b(T.cut(after, 93), False{}, before)

# S2.130 quoted or not
def hdr.a.first(q: Bool, rest: String, content: String) -> Hdr:
  match q:
    case True{}:
      hdr.a.quoted(quote.close(rest))
    case False{}:
      hdr.a.plain(T.cut(content, 91))

# S2.130 the first character after leading White_Space decides how the bracket is found
def hdr.a(t: String, content: String) -> Hdr:
  match t:
    case SNil{}:
      HNot{}
    case SCon{Chr{+c}, rest}:
      hdr.a.first(U32.is_eq(c, 34), rest, content)

# S2.130–S2.139 offer a content to the header parser
def header(+content: String) -> Hdr:
  hdr.a(T.trim_start(content), content)

# ---------------------------------------------------------------- S4.200–S4.227 the structural decoder
#
# A pushdown machine over the scanned lines. Each step either CONSUMES the next line (offered to the
# innermost open construct, which it fits) or leaves the lines alone and CLOSES the innermost construct
# (its checks run, its value goes to the enclosing construct). Measure: (lines, bound), where bound is an
# upper bound of the number of open constructs: a consumed line opens at most three.

# S4.204–S4.225 an open construct.
# FObj: an object: entries so far (newest first), the depth D of its fields, whether it is a list-item
#   object (then a line starting with `- ` is not a field, S4.225), and the key (with its quoted flag)
#   under which the construct opened above it will be stored.
# FTab: a tabular body: rows so far, declared length N, rows read, row depth r, the fields and their
#   count, the delimiter, the line number of the first row (0: none yet).
# FList: a list body: items so far, N, items read, item depth t, the line number of the first item.
type Frame is Data:
  FObj{rev: J.Json, d: Nat, item: Bool, key: String, q: Bool}
  FTab{rev: J.Json, n: Nat, cnt: Nat, r: Nat, fields: List<&2, Field>, nf: Nat, delim: U32, first: Nat}
  FList{rev: J.Json, n: Nat, cnt: Nat, t: Nat, first: Nat}

# S3.29 what does not change shape during the pass: strict mode, the blank-line numbers (ascending),
# and the number of the line consumed last
type G is Data:
  G{strict: Bool, blanks: List<&2, Nat>, last: Nat}

# S3.29 one line of look-ahead: the next unread line's depth and content, or the end
type Peek is Data:
  PNone{}
  PLine{depth: Nat, content: String}

# S4.207 what the machine does next: offer the next line to the innermost construct, close the
# innermost construct, stop with a message, or stop with the root value (S4.202, S4.204: whatever
# lines remain are ignored)
type Step is Data:
  SEat{frames: List<&2, Frame>, g: G}
  SPop{frames: List<&2, Frame>, g: G}
  SErr{msg: String}
  SDone{v: J.Json}

# S3.29 look at the next unread line
def peek(ls: List<&2, Line>) -> Peek:
  match ls:
    case Nil{}:
      PNone{}
    case Con{Line{num, depth, content}, rest}:
      PLine{depth, content}

# S4.204, S4.206, S4.225 a line is a field of an object when it sits at the object's field depth and,
# in a list-item object, does not start with `- `; S4.212 a row while fewer than N rows were read and
# the depth is the row depth, whatever the content; S4.215 an item while fewer than N were read, the
# depth is the item depth and the content is a list item (S2.140)
def fits(f: Frame, depth: Nat, content: String) -> Bool:
  match f:
    case FObj{rev, d, item, key, q}:
      Bool.and(Nat.is_eq(depth, d), Bool.not(Bool.and(item, is_dash_sp(content))))
    case FTab{rev, n, cnt, r, fields, nf, delim, first}:
      Bool.and(Nat.is_lt(cnt, n), Nat.is_eq(depth, r))
    case FList{rev, n, cnt, t, first}:
      Bool.and(Nat.is_lt(cnt, n), Bool.and(Nat.is_eq(depth, t), is_item(content)))

# S4.207 consume or close
def decide.if(ok: Bool, frames: List<&2, Frame>, g: G) -> Step:
  match ok:
    case True{}:
      SEat{frames, g}
    case False{}:
      SPop{frames, g}

# S4.207 a line that does not fit the innermost construct closes it and is offered to the next one; at
# the end of the lines every construct closes in turn
def decide(frames: List<&2, Frame>, pk: Peek, g: G) -> Step:
  match frames pk:
    case Nil{} _:
      SErr{"internal: no open construct"}
    case Con{f, more} PNone{}:
      SPop{f <> more, g}
    case Con{+f, more} PLine{depth, content}:
      decide.if(fits(f, depth, content), f <> more, g)

# S3.22 a finished value goes to the construct that awaits it: under the pending key of an object, as
# the next item of a list, or, with nothing open, it is the root value and the pass ends
def attach(v: J.Json, frames: List<&2, Frame>, pk: Peek, g: G) -> Step:
  match frames:
    case Nil{}:
      SDone{v}
    case Con{FObj{rev, d, item, key, q}, more}:
      decide(FObj{J.JECons{key, q, v, rev}, d, item, SNil{}, False{}} <> more, pk, g)
    case Con{FList{rev, n, cnt, t, first}, more}:
      decide(FList{J.JCons{v, rev}, n, 1n+cnt, t, first} <> more, pk, g)
    case Con{FTab{rev, n, cnt, r, fields, nf, delim, first}, more}:
      SErr{"internal: a value inside a tabular body"}

# S4.213 (2), S4.215 (2) the class of the head of the blank-line list against an open range (lo, hi):
# 0 not above lo, 1 strictly inside, 2 at or above hi (or no head)
def blank.cls(bs: List<&2, Nat>, lo: Nat, hi: Nat) -> Nat:
  match bs:
    case Nil{}:
      2n
    case Con{+b, rest}:
      Bool.pick(Nat, Nat.is_le(b, lo), 0n, Bool.pick(Nat, Nat.is_lt(b, hi), 1n, 2n))

# S6.44 the loop: the list is ascending, so the first member inside the range is the one reported
def blank.go(bs: List<&2, Nat>, k: Nat, +lo: Nat, +hi: Nat) -> Nat:
  match bs k:
    case Nil{} _:
      0n
    case Con{b, rest} 1n:
      b
    case Con{b, rest} 2n:
      0n
    case Con{b, +rest} _:
      blank.go(rest, blank.cls(rest, lo, hi), lo, hi)

# S6.44 the first blank line strictly inside (lo, hi), or 0
def blank.range(+blanks: List<&2, Nat>, +lo: Nat, +hi: Nat) -> Nat:
  blank.go(blanks, blank.cls(blanks, lo, hi), lo, hi)

# S4.213 (2), S4.215 (2) the first blank line strictly between the first line of a body and the last
# line it consumed, or 0; a body that read nothing (first = 0) has no range
def blank.in(blanks: List<&2, Nat>, +first: Nat, last: Nat) -> Nat:
  blank.range(blanks, first, Bool.pick(Nat, Nat.is_eq(first, 0n), 0n, last))

# S9.110, S9.112 the counted thing of a body
def close.unit(tab: Bool) -> String:
  match tab:
    case True{}:
      "tabular rows"
    case False{}:
      "list array items"

# S9.114, S9.115 the body named by the blank-line message
def close.body(tab: Bool) -> String:
  match tab:
    case True{}:
      "tabular array"
    case False{}:
      "list array"

# S4.213, S4.215 the checks after a body, strict only and in this order: (1) the count, (2) the first
# blank line inside the body (0: none), (3) a surplus row or item right after it
def close.msg(strict: Bool, short: Bool, blank: Nat, surplus: Bool, +tab: Bool, +n: Nat, cnt: Nat) -> Maybe<&2, String>:
  match strict short blank surplus:
    case False{} _ _ _:
      None{}
    case True{} True{} _ _:
      Some{"Expected " ++ Nat.show(n) ++ " " ++ close.unit(tab) ++ ", but got " ++ Nat.show(cnt)}
    case True{} False{} 1n+b _:
      Some{"Line " ++ Nat.show(1n+b) ++ ": Blank lines inside " ++ close.body(tab) ++ " are not allowed in strict mode"}
    case True{} False{} 0n True{}:
      Some{"Expected " ++ Nat.show(n) ++ " " ++ close.unit(tab) ++ ", but found more"}
    case True{} False{} 0n False{}:
      None{}

# S4.213 (3) the next unread line sits at the row depth, does not start with `- ` and is a data row
def surplus.tab(pk: Peek, r: Nat, delim: U32) -> Bool:
  match pk:
    case PNone{}:
      False{}
    case PLine{depth, +content}:
      Bool.and(Nat.is_eq(depth, r), Bool.and(Bool.not(is_dash_sp(content)), is_row(content, delim)))

# S4.215 (3) the next unread line sits at the item depth and starts with `- ` (a bare `-` is not
# noticed, S10.85)
def surplus.list(pk: Peek, t: Nat) -> Bool:
  match pk:
    case PNone{}:
      False{}
    case PLine{depth, content}:
      Bool.and(Nat.is_eq(depth, t), is_dash_sp(content))

# S4.213, S4.215 a body that fails its checks ends the pass; otherwise its array goes to its parent
def close.fin(msg: Maybe<&2, String>, v: J.Json, frames: List<&2, Frame>, pk: Peek, g: G) -> Step:
  match msg:
    case Some{m}:
      SErr{m}
    case None{}:
      attach(v, frames, pk, g)

# S4.207 close the innermost construct: an object simply ends (keeping every occurrence of a repeated
# key, S3.25); a body runs its checks first
def pop(frames: List<&2, Frame>, +pk: Peek, g: G) -> Step:
  match frames g:
    case Nil{} g0:
      SErr{"internal: nothing to close"}
    case Con{FObj{rev, d, item, key, q}, more} g0:
      attach(J.JObj{J.rev_entries(rev, J.JNil{})}, more, pk, g0)
    case Con{FTab{rev, +n, +cnt, r, fields, nf, delim, first}, more} G{+strict, +blanks, +last}:
      close.fin(close.msg(strict, Nat.is_ne(cnt, n), blank.in(blanks, first, last), surplus.tab(pk, r, delim), True{}, n, cnt), J.JArr{cnt, J.rev_items(rev, J.JNil{})}, more, pk, G{strict, blanks, last})
    case Con{FList{rev, +n, +cnt, t, first}, more} G{+strict, +blanks, +last}:
      close.fin(close.msg(strict, Nat.is_ne(cnt, n), blank.in(blanks, first, last), surplus.list(pk, t), False{}, n, cnt), J.JArr{cnt, J.rev_items(rev, J.JNil{})}, more, pk, G{strict, blanks, last})

# S4.211 the primitives of a value list so far (newest first) and their count, or the first failure
type PR is Data:
  PROk{rev: J.Json, cnt: Nat}
  PRErr{msg: String}

# S4.211 one more value
def prims.add(r: RV, rev: J.Json, cnt: Nat) -> PR:
  match r:
    case RVOk{v}:
      PROk{J.JCons{v, rev}, 1n+cnt}
    case RVErr{msg}:
      PRErr{msg}

# S4.211, S9.143 EVERY value becomes a primitive, leftmost failure first, before anything is counted
def prims.go(vals: List<&2, String>, st: PR) -> PR:
  match vals st:
    case Nil{} s:
      s
    case Con{v, rest} PRErr{msg}:
      PRErr{msg}
    case Con{v, rest} PROk{rev, cnt}:
      prims.go(rest, prims.add(prim(v), rev, cnt))

# S4.211 strict: the number of values must equal N (S9.108); lenient: all values are kept
def inline.fin(bad: Bool, +n: Nat, +cnt: Nat, rev: J.Json, frames: List<&2, Frame>, pk: Peek, g: G) -> Step:
  match bad:
    case True{}:
      SErr{"Expected " ++ Nat.show(n) ++ " inline array items, but got " ++ Nat.show(cnt)}
    case False{}:
      attach(J.JArr{cnt, J.rev_items(rev, J.JNil{})}, frames, pk, g)

# S4.211 the inline body
def inline(pr: PR, +n: Nat, frames: List<&2, Frame>, pk: Peek, g: G) -> Step:
  match pr g:
    case PRErr{msg} g0:
      SErr{msg}
    case PROk{rev, +cnt} G{+strict, blanks, last}:
      inline.fin(Bool.and(strict, Nat.is_ne(cnt, n)), n, cnt, rev, frames, pk, G{strict, blanks, last})

# S4.210 the body of a parsed header at base depth d: inline values win even over a fields segment
# (S10.87); else a tabular body when there is at least one field name; else a list body (also for
# `k[0]:` and `k[N]{}:`, S4.216). Rows and items are expected at depth d + 1.
def array(has_inline: Bool, has_fields: Bool, n: Nat, +delim: U32, +fields: List<&2, Field>, inline_text: String, d: Nat, frames: List<&2, Frame>, pk: Peek, g: G) -> Step:
  match has_inline has_fields:
    case True{} _:
      inline(prims.go(split(inline_text, delim), PROk{J.JNil{}, 0n}), n, frames, pk, g)
    case False{} True{}:
      decide(FTab{J.JNil{}, n, 0n, 1n+d, fields, T.llen(&2, Field, fields, 0n), delim, 0n} <> frames, pk, g)
    case False{} False{}:
      decide(FList{J.JNil{}, n, 0n, 1n+d, 0n} <> frames, pk, g)

# S4.205 (b) a value token
def eat.prim(r: RV, frames: List<&2, Frame>, pk: Peek, g: G) -> Step:
  match r:
    case RVErr{msg}:
      SErr{msg}
    case RVOk{v}:
      attach(v, frames, pk, g)

# S4.205 (b), S4.206 the depth of the next unread line when it is deeper than d (it then fixes the
# sibling depth D of the nested fields, however deep, S10.82), else 0
def deeper(pk: Peek, d: Nat) -> Nat:
  match pk:
    case PNone{}:
      0n
    case PLine{+depth, content}:
      Bool.pick(Nat, Nat.is_gt(depth, d), depth, 0n)

# S4.205 (b) a non-empty value text is a primitive (never split on delimiters); an empty one is a
# nested object when the next line is deeper, else the empty object
def eat.kv.val(empty: Bool, dd: Nat, val: String, frames: List<&2, Frame>, pk: Peek, g: G) -> Step:
  match empty dd:
    case False{} _:
      eat.prim(prim(val), frames, pk, g)
    case True{} 0n:
      attach(J.JObj{J.JNil{}}, frames, pk, g)
    case True{} 1n+p:
      decide(FObj{J.JNil{}, 1n+p, False{}, SNil{}, False{}} <> frames, pk, g)

# S4.205 (b) the key token; the object that receives the field remembers the key while the value is read
def eat.kv.plain(k: KV, +pk: Peek, rev: J.Json, +d: Nat, item: Bool, more: List<&2, Frame>, g: G) -> Step:
  match k:
    case KVErr{msg}:
      SErr{msg}
    case KVOk{key, quoted, +val}:
      eat.kv.val(String.is_empty(val), deeper(pk, d), val, FObj{rev, d, item, key, quoted} <> more, pk, g)

# S4.205 a key-value content at base depth d, given the header parse of the content: header failures
# surface first; (a) a header WITH a key is a keyed array; (b) anything else is read as key and value
def eat.kv(h: Hdr, content: String, pk: Peek, rev: J.Json, +d: Nat, item: Bool, more: List<&2, Frame>, g: G) -> Step:
  match h:
    case HErr{msg}:
      SErr{msg}
    case HOk{True{}, key, quoted, n, delim, has_seg, +fields, +inline_text}:
      array(Bool.not(String.is_empty(inline_text)), Bool.not(List.is_empty(&2, Field, fields)), n, delim, fields, inline_text, d, FObj{rev, d, item, key, quoted} <> more, pk, g)
    case other:
      eat.kv.plain(kv(content), pk, rev, d, item, more, g)

# S4.212, S6.41 a row object: the fields in header order, each with its value; a field without a value
# is null (lenient only); surplus values are dropped. Entries are built newest first.
def row.zip(fields: List<&2, Field>, vals: J.Json, acc: J.Json) -> J.Json:
  match fields vals:
    case Nil{} _:
      acc
    case Con{Field{name, quoted}, fs} J.JCons{v, t}:
      row.zip(fs, t, J.JECons{name, quoted, v, acc})
    case Con{Field{name, quoted}, fs} other:
      row.zip(fs, J.JNil{}, J.JECons{name, quoted, J.JNull{}, acc})

# S4.212 the row's values as primitives (surplus ones too: their failures surface), then the object
def row.fin(pr: PR, +num: Nat, rev: J.Json, n: Nat, cnt: Nat, r: Nat, +fields: List<&2, Field>, nf: Nat, delim: U32, +first: Nat, more: List<&2, Frame>, pk: Peek, g: G) -> Step:
  match pr:
    case PRErr{msg}:
      SErr{msg}
    case PROk{prev, pc}:
      decide(FTab{J.JCons{J.JObj{J.rev_entries(row.zip(fields, J.rev_items(prev, J.JNil{}), J.JNil{}), J.JNil{})}, rev}, n, 1n+cnt, r, fields, nf, delim, Bool.pick(Nat, Nat.is_eq(first, 0n), num, first)} <> more, pk, g)

# S4.212, S9.144 strict: the width is checked BEFORE the values are turned into primitives (S9.109)
def row.width(bad: Bool, +vals: List<&2, String>, num: Nat, rev: J.Json, n: Nat, cnt: Nat, r: Nat, fields: List<&2, Field>, +nf: Nat, delim: U32, first: Nat, more: List<&2, Frame>, pk: Peek, g: G) -> Step:
  match bad:
    case True{}:
      SErr{"Expected " ++ Nat.show(nf) ++ " tabular row values, but got " ++ Nat.show(T.llen(&2, String, vals, 0n))}
    case False{}:
      row.fin(prims.go(vals, PROk{J.JNil{}, 0n}), num, rev, n, cnt, r, fields, nf, delim, first, more, pk, g)

# S4.212 one row: the line split with the header's delimiter
def eat.row(+vals: List<&2, String>, num: Nat, rev: J.Json, n: Nat, cnt: Nat, r: Nat, fields: List<&2, Field>, +nf: Nat, delim: U32, first: Nat, more: List<&2, Frame>, pk: Peek, g: G) -> Step:
  match g:
    case G{+strict, blanks, last}:
      row.width(Bool.and(strict, Nat.is_ne(T.llen(&2, String, vals, 0n), nf)), vals, num, rev, n, cnt, r, fields, nf, delim, first, more, pk, G{strict, blanks, last})

# S4.221 the text after the two-character marker `- ` (nothing for the bare marker `-`), not trimmed
def item.rest(content: String) -> String:
  match content:
    case SCon{a, SCon{b, rest}}:
      rest
    case other:
      SNil{}

# S4.220–S4.226 one list item with rest R, given R's header parse (failures surface, whatever R looks
# like), whether R starts with '[' after leading White_Space, and whether R has a ':' outside quotes.
# In order: an empty or White_Space-only rest is the empty object; a keyless header behind a '[' with
# an unquoted ':' is a nested array at base depth t; a header with a key AND a fields segment opens an
# item object whose first field is that array at base depth t + 1; a ':' outside quotes makes R the
# first key-value line of an item object at base depth t + 1; anything else is a primitive.
def item.route(blank: Bool, h: Hdr, br: Bool, colon: Bool, r: String, lst: Frame, more: List<&2, Frame>, +t: Nat, pk: Peek, g: G) -> Step:
  match blank h br colon:
    case True{} _ _ _:
      attach(J.JObj{J.JNil{}}, lst <> more, pk, g)
    case False{} HErr{msg} _ _:
      SErr{msg}
    case False{} HOk{hk, key, quoted, n, delim, has_seg, +fields, +inline_text} True{} True{}:
      array(Bool.not(String.is_empty(inline_text)), Bool.not(List.is_empty(&2, Field, fields)), n, delim, fields, inline_text, t, lst <> more, pk, g)
    case False{} HOk{True{}, key, quoted, n, delim, True{}, +fields, +inline_text} _ _:
      array(Bool.not(String.is_empty(inline_text)), Bool.not(List.is_empty(&2, Field, fields)), n, delim, fields, inline_text, 1n+t, FObj{J.JNil{}, 1n+t, True{}, key, quoted} <> lst <> more, pk, g)
    case False{} h0 _ True{}:
      eat.kv(h0, r, pk, J.JNil{}, 1n+t, True{}, lst <> more, g)
    case False{} h0 _ False{}:
      eat.prim(prim(r), lst <> more, pk, g)

# S4.220–S4.226 one list item
def eat.item(+r: String, lst: Frame, more: List<&2, Frame>, t: Nat, pk: Peek, g: G) -> Step:
  item.route(T.is_blank(r), header(r), T.head_is(T.trim_start(r), 91), has_colon(r), r, lst, more, t, pk, g)

# S4.207 offer a line to the innermost construct (the line is known to fit it); S4.204 the base depth
# of a field is the object's field depth, WHATEVER the line's own depth
def eat(l: Line, pk: Peek, frames: List<&2, Frame>, g: G) -> Step:
  match l frames g:
    case Line{num, depth, content} Nil{} g0:
      SErr{"internal: a line with nothing open"}
    case Line{num, depth, +content} Con{FObj{rev, d, item, key, q}, more} G{strict, blanks, last}:
      eat.kv(header(content), content, pk, rev, d, item, more, G{strict, blanks, num})
    case Line{num, depth, content} Con{FTab{rev, n, cnt, r, fields, nf, +delim, first}, more} G{strict, blanks, last}:
      eat.row(split(content, delim), num, rev, n, cnt, r, fields, nf, delim, first, more, pk, G{strict, blanks, num})
    case Line{+num, depth, content} Con{FList{rev, n, cnt, +t, +first}, more} G{strict, blanks, last}:
      eat.item(item.rest(content), FList{rev, n, cnt, t, Bool.pick(Nat, Nat.is_eq(first, 0n), num, first)}, more, t, pk, G{strict, blanks, num})

# S4.200 (4) the outcome of decoding
type DR is Data:
  DOk{v: J.Json}
  DErr{msg: String}

# S4.200 (4) the pass. A step that consumes a line may open at most three constructs, so the bound
# grows by three; a step that closes a construct spends one. The first failure, or the root value, ends
# the pass: lines that remain are never parsed (S10.80, S10.81).
def run(lines: List<&2, Line>, bound: Nat, st: Step) -> DR:
  match lines bound st:
    case ls b SErr{msg}:
      DErr{msg}
    case ls b SDone{v}:
      DOk{v}
    case Con{l, +rest} b SEat{frames, g}:
      run(rest, Nat.add(b, 3n), eat(l, peek(rest), frames, g))
    case Nil{} b SEat{frames, g}:
      DErr{"internal: a line was expected"}
    case +ls 1n+b SPop{frames, g}:
      run(ls, b, pop(frames, peek(ls), g))
    case ls 0n SPop{frames, g}:
      DErr{"internal: construct bound"}

# S4.203 the ROOT key-value rule for a content starting with a double quote: key-value only when a
# closing quote exists and the text after it contains a ':'
def root.kv.q(q: QS) -> Bool:
  match q:
    case QS{False{}, inner, after}:
      False{}
    case QS{True{}, inner, after}:
      T.has_char(after, 58)

# S4.203 any other content is key-value exactly when it contains a ':' anywhere, quotes or not (S10.98)
def root.kv.first(q: Bool, c: U32, rest: String) -> Bool:
  match q:
    case True{}:
      root.kv.q(quote.close(rest))
    case False{}:
      T.has_char(SCon{Chr{c}, rest}, 58)

# S4.203 whether the only line of a document is a key-value line by the root rule
def root.is_kv(content: String) -> Bool:
  match content:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, rest}:
      root.kv.first(U32.is_eq(c, 34), c, rest)

# S4.203 the root primitive
def root.prim(r: RV) -> DR:
  match r:
    case RVOk{v}:
      DOk{v}
    case RVErr{msg}:
      DErr{msg}

# S4.203 exactly ONE non-blank line that is not key-value by the root rule is the root primitive;
# S4.204 every other document is a root object: its first line is a field at base depth 0 whatever
# its own depth
def root.object(single: Bool, is_kv: Bool, line: Line, rest: List<&2, Line>, g: G) -> DR:
  match single is_kv line:
    case True{} False{} Line{num, depth, content}:
      root.prim(prim(content))
    case _ _ l:
      run(l <> rest, 8n, SEat{FObj{J.JNil{}, 0n, False{}, SNil{}, False{}} <> Nil{}, g})

# S4.202 the root-array test, third part: the first line parses as a header (failures surface): the
# array is decoded at base depth 0 whatever the line's own depth. A content that is not a header falls
# through to S4.203 / S4.204.
def root.array(h: Hdr, +num: Nat, depth: Nat, +content: String, +rest: List<&2, Line>, strict: Bool, blanks: List<&2, Nat>) -> DR:
  match h:
    case HErr{msg}:
      DErr{msg}
    case HOk{hk, key, quoted, n, delim, has_seg, +fields, +inline_text}:
      run(rest, 8n, array(Bool.not(String.is_empty(inline_text)), Bool.not(List.is_empty(&2, Field, fields)), n, delim, fields, inline_text, 0n, Nil{}, peek(rest), G{strict, blanks, num}))
    case HNot{}:
      root.object(List.is_empty(&2, Line, rest), root.is_kv(content), Line{num, depth, content}, rest, G{strict, blanks, 0n})

# S4.202 the root-array test, first two parts: after leading White_Space the content starts with '['
# and it has a ':' outside quotes
def root.first(arr: Bool, +num: Nat, depth: Nat, +content: String, +rest: List<&2, Line>, strict: Bool, blanks: List<&2, Nat>) -> DR:
  match arr:
    case True{}:
      root.array(header(content), num, depth, content, rest, strict, blanks)
    case False{}:
      root.object(List.is_empty(&2, Line, rest), root.is_kv(content), Line{num, depth, content}, rest, G{strict, blanks, 0n})

# S4.201 no non-blank line is the empty object; otherwise the FIRST non-blank line selects the root form
def root(lines: List<&2, Line>, strict: Bool, blanks: List<&2, Nat>) -> DR:
  match lines:
    case Nil{}:
      DOk{J.JObj{J.JNil{}}}
    case Con{Line{num, depth, +content}, rest}:
      root.first(Bool.and(T.head_is(T.trim_start(content), 91), has_colon(content)), num, depth, content, rest, strict, blanks)

# S4.200 (3), (4) scan everything first (S2.111), then one structural pass
def decode.scanned(s: Scan, +strict: Bool) -> DR:
  match s:
    case ScanErr{msg}:
      DErr{msg}
    case ScanOk{lines, blanks}:
      root(lines, strict, blanks)

# S4.200 the value of a TOON text with indent size `unit` (no path expansion)
def decode(text: String, +strict: Bool, unit: Nat) -> DR:
  decode.scanned(scan(text, strict, unit), strict)

# ---------------------------------------------------------------- S4.240–S4.249 safe path expansion
#
# Objects under construction are entry chains kept newest first; J.obj.put replaces a value at its
# position or appends (S6.42). The depth counter c of S4.248 is carried as `left` = 256 - c: a step may
# run only while left >= 1.

# S4.240 a value (or, inside the walks, a chain), or the message of the first failure
type ER is Data:
  EOk{v: J.Json}
  EErr{msg: String}

# S9.118 the cap message
def cap_msg() -> String:
  "Path expansion exceeded maximum depth of 256"

# S4.246 the type names of the conflict messages
def ty(v: J.Json) -> String:
  match v:
    case J.JObj{entries}:
      "object"
    case J.JArr{n, items}:
      "array"
    case other:
      "primitive"

# S4.243, S4.244 what an object under construction holds under a key: nothing, an object (its entries
# in order), or something else (its type name)
type LK is Data:
  LNone{}
  LObj{entries: J.Json}
  LOther{ty: String}

# S4.244 classify a held value
def lk.of(v: J.Json) -> LK:
  match v:
    case J.JObj{entries}:
      LObj{entries}
    case J.JArr{n, items}:
      LOther{"array"}
    case other:
      LOther{"primitive"}

# S4.244 keys are unique in an object under construction, so at most one entry answers
def lk.pick(same: Bool, v: J.Json, acc: LK) -> LK:
  match same:
    case True{}:
      lk.of(v)
    case False{}:
      acc

# S4.244 the loop of lk
def lk.go(c: J.Json, +k: String, acc: LK) -> LK:
  match c:
    case J.JECons{key, q, v, t}:
      lk.go(t, k, lk.pick(T.str_eq(key, k), v, acc))
    case other:
      acc

# S4.244 look a key up in an object under construction
def lk(c: J.Json, k: String) -> LK:
  lk.go(c, k, LNone{})

# S4.244 what to do with the first entry of a source chain against a target under construction
type Act is Data:
  ANone{}
  ACap{}
  APut{}
  AConf{msg: String}
  AMerge{ex: J.Json}

# S9.116 strict: a conflict names the key, the type of the EXISTING value, then the type of the new
# one; lenient: the new value overwrites in place
def plan.conf(strict: Bool, k: String, x: String, y: String) -> Act:
  match strict:
    case True{}:
      AConf{T.cat(["Path expansion conflict at key \"", k, "\": cannot merge ", x, " with ", y])}
    case False{}:
      APut{}

# S4.244 no entry: append; two objects: deep merge; anything else: conflict or overwrite
def plan.head(l: LK, v: J.Json, strict: Bool, k: String) -> Act:
  match l v:
    case LNone{} _:
      APut{}
    case LObj{ex} J.JObj{ve}:
      AMerge{ex}
    case LObj{ex} other:
      plan.conf(strict, k, "object", ty(other))
    case LOther{t} nv:
      plan.conf(strict, k, t, ty(nv))

# S4.248 a merge or a literal insertion may not run with c >= 256; a target that already failed, or a
# source with nothing left, plans nothing
def plan(left: Nat, tgt: ER, src: J.Json, strict: Bool) -> Act:
  match left tgt src:
    case 0n _ _:
      ACap{}
    case 1n+p EErr{m} _:
      ANone{}
    case 1n+p EOk{rev} J.JECons{+k, q, v, t}:
      plan.head(lk(rev, k), v, strict, k)
    case 1n+p EOk{rev} other:
      ANone{}

# S4.244 place a value
def merge.put(rev: J.Json, k: String, v: J.Json) -> ER:
  EOk{J.obj.put(rev, k, v)}

# S4.245 place the result of a nested merge (a chain, newest first) as an object
def merge.sub(rev: J.Json, k: String, sub: ER) -> ER:
  match sub:
    case EErr{m}:
      EErr{m}
    case EOk{srev}:
      EOk{J.obj.put(rev, k, J.JObj{J.rev_entries(srev, J.JNil{})})}

# S4.244, S4.245 insert the entries of a source chain, in order, into a target under construction, at
# counter 256 - left; `act` is the plan for the FIRST entry of `src` (computed by the caller). A nested
# merge runs one counter higher. ONE def: the recursion is on the source, whose nested objects are its
# own subterms.
def merge(src: J.Json, act: Act, tgt: ER, +strict: Bool, +left: Nat) -> ER:
  match src act tgt:
    case s ACap{} t:
      EErr{cap_msg()}
    case s AConf{msg} t:
      EErr{msg}
    case s ANone{} t:
      t
    case J.JECons{k, q, v, +rest} APut{} EOk{rev}:
      +t2 = merge.put(rev, k, v)
      merge(rest, plan(left, t2, rest, strict), t2, strict, left)
    case J.JECons{k, q, J.JObj{+ve}, +rest} AMerge{ex} EOk{rev}:
      +rx = J.rev_entries(ex, J.JNil{})
      +t2 = merge.sub(rev, k, merge(ve, plan(Nat.sub(left, 1n), EOk{rx}, ve, strict), EOk{rx}, strict, Nat.sub(left, 1n)))
      merge(rest, plan(left, t2, rest, strict), t2, strict, left)
    case s a t:
      t

# S4.245 merge a whole source chain into a target under construction at counter 256 - left
def merge.all(+src: J.Json, +rev: J.Json, +strict: Bool, +left: Nat) -> ER:
  merge(src, plan(left, EOk{rev}, src, strict), EOk{rev}, strict, left)

# S4.244 the literal insertion of (k, v) at counter 256 - left: a merge of the one-entry source
def lit.ins(rev: J.Json, k: String, v: J.Json, strict: Bool, left: Nat) -> ER:
  merge.all(J.JECons{k, False{}, v, J.JNil{}}, rev, strict, left)

# S4.243 what the object under construction holds under the FIRST of the remaining segments
def lk.head(segs: List<&2, String>, rev: J.Json) -> LK:
  match segs:
    case Nil{}:
      LNone{}
    case Con{s, more}:
      lk(rev, s)

# S4.243 the object reached through a segment goes back under that segment, at its position
def path.put(rev: J.Json, s: String, sub: ER) -> ER:
  match sub:
    case EErr{m}:
      EErr{m}
    case EOk{srev}:
      EOk{J.obj.put(rev, s, J.JObj{J.rev_entries(srev, J.JNil{})})}

# S4.243 insert a path into an object under construction. Each call is one step of the walk, at
# counter 256 - left; `look` is what the object holds under the first remaining segment. An object is
# entered; nothing there, or (lenient) something that is not an object, becomes an empty object; strict:
# S9.117. The last segment is a literal insertion one counter higher.
def path.ins(segs: List<&2, String>, look: LK, left: Nat, strict: Bool, +rev: J.Json, v: J.Json) -> ER:
  match segs look left strict:
    case _ _ 0n _:
      EErr{cap_msg()}
    case Nil{} _ 1n+p _:
      EOk{rev}
    case Con{s, Nil{}} _ 1n+p +st:
      lit.ins(rev, s, v, st, p)
    case Con{s, +more} LObj{ex} 1n+p +st:
      +rx = J.rev_entries(ex, J.JNil{})
      path.put(rev, s, path.ins(more, lk.head(more, rx), p, st, rx, v))
    case Con{s, more} LOther{t} 1n+p True{}:
      EErr{T.cat(["Path expansion conflict at segment \"", s, "\": expected object but found ", t])}
    case Con{s, more} l0 1n+p +st:
      path.put(rev, s, path.ins(more, LNone{}, p, st, J.JNil{}, v))

# S4.241 splitter state: the current piece (reversed) and the finished pieces (newest first)
type DT is Data:
  DT{cur: String, acc: List<&2, String>}

# S4.241 one character: a dot ends the piece
def dots.ch(dot: Bool, c: U32, st: DT) -> DT:
  match dot st:
    case True{} DT{cur, acc}:
      DT{SNil{}, String.reverse(cur) <> acc}
    case False{} DT{cur, acc}:
      DT{SCon{Chr{c}, cur}, acc}

# S4.241 the loop over the key
def dots.go(s: String, st: DT) -> DT:
  match s:
    case SNil{}:
      st
    case SCon{Chr{+c}, rest}:
      dots.go(rest, dots.ch(U32.is_eq(c, 46), c, st))

# S4.241 the pieces in order
def dots.fin(st: DT) -> List<&2, String>:
  match st:
    case DT{cur, acc}:
      List.reverse(&2, String, String.reverse(cur) <> acc)

# S4.241 the pieces of a key between its dots
def dots(k: String) -> List<&2, String>:
  dots.fin(dots.go(k, DT{SNil{}, Nil{}}))

# S4.241 the loop: every piece must be an identifier segment; stops at the first that is not
def idents.go(segs: List<&2, String>, ok: Bool) -> Bool:
  match segs ok:
    case _ False{}:
      False{}
    case Nil{} True{}:
      True{}
    case Con{s, rest} True{}:
      idents.go(rest, T.is_ident(s, False{}))

# S3.26 the loop of in_set: stops at the first hit
def in_set.go(qs: List<&2, String>, +k: String, hit: Bool) -> Bool:
  match qs hit:
    case _ True{}:
      True{}
    case Nil{} False{}:
      False{}
    case Con{x, rest} False{}:
      in_set.go(rest, k, T.str_eq(x, k))

# S3.26 whether a key string is in the object's quoted-key set
def in_set(qs: List<&2, String>, k: String) -> Bool:
  in_set.go(qs, k, False{})

# S3.25 one entry's contribution to the quoted-key set
def qset.add(q: Bool, k: String, acc: List<&2, String>) -> List<&2, String>:
  match q:
    case True{}:
      k <> acc
    case False{}:
      acc

# S3.25, S3.26 the quoted-key set of an object: the key STRINGS that occur quoted at least once in it
def qset(c: J.Json, acc: List<&2, String>) -> List<&2, String>:
  match c:
    case J.JECons{k, q, v, t}:
      qset(t, qset.add(q, k, acc))
    case other:
      acc

# S4.243 the walk starts at the object itself
def field.path(+segs: List<&2, String>, +rev: J.Json, v: J.Json, strict: Bool, left: Nat) -> ER:
  path.ins(segs, lk.head(segs, rev), left, strict, rev, v)

# S4.242 a key that is a path (S4.241: it has a dot, its string is not in the quoted-key set, every
# piece is an identifier segment) is inserted by S4.243; any other key literally, by S4.244. Both run
# at the counter of the object's entry values (S4.248: c + 2).
def field.key(path: Bool, rev: J.Json, +k: String, v: J.Json, strict: Bool, left: Nat) -> ER:
  match path:
    case False{}:
      lit.ins(rev, k, v, strict, left)
    case True{}:
      field.path(dots(k), rev, v, strict, left)

# S4.242 FIRST the entry's value is expanded, THEN its key is inserted: a failure among the earlier
# entries wins, then a failure inside the value, then the insertion's own
def field.ins(acc: ER, +k: String, +qs: List<&2, String>, v: ER, strict: Bool, left: Nat) -> ER:
  match acc v:
    case EErr{m} _:
      EErr{m}
    case EOk{rev} EErr{m}:
      EErr{m}
    case EOk{rev} EOk{nv}:
      field.key(Bool.and(T.has_char(k, 46), Bool.and(Bool.not(in_set(qs, k)), idents.go(dots(k), True{}))), rev, k, nv, strict, left)

# S4.240 one more expanded item of an array (newest first)
def item.push(acc: ER, v: ER) -> ER:
  match acc v:
    case EErr{m} _:
      EErr{m}
    case EOk{rev} EErr{m}:
      EErr{m}
    case EOk{rev} EOk{nv}:
      EOk{J.JCons{nv, rev}}

# S4.240 an expanded array
def arr.fin(n: Nat, r: ER) -> ER:
  match r:
    case EErr{m}:
      EErr{m}
    case EOk{rev}:
      EOk{J.JArr{n, J.rev_items(rev, J.JNil{})}}

# S3.28 an expanded object: unique keys, in the order of S6.42
def obj.fin(r: ER) -> ER:
  match r:
    case EErr{m}:
      EErr{m}
    case EOk{rev}:
      EOk{J.JObj{J.rev_entries(rev, J.JNil{})}}

# S4.240 how `expand` treats the node it is given. `left` = 256 - c for the value, the items or the
# entry values; qs is the object's quoted-key set; acc is the container under construction
type XC is Data:
  XVal{left: Nat}
  XItems{left: Nat, acc: ER}
  XFields{left: Nat, qs: List<&2, String>, acc: ER}

# S4.240, S4.248 expansion, depth-first in document order. ONE def over Json (values and their chains):
# a value may run while c < 256; an array's items have c + 1; an object is rebuilt at c + 1 and its
# entry values have c + 2. Siblings are a tail call; only nesting recurses.
def expand(j: J.Json, cx: XC, +strict: Bool) -> ER:
  match j cx:
    case v XVal{0n}:
      EErr{cap_msg()}
    case J.JArr{n, items} XVal{1n+p}:
      arr.fin(n, expand(items, XItems{p, EOk{J.JNil{}}}, strict))
    case J.JObj{entries} XVal{1n+0n}:
      EErr{cap_msg()}
    case J.JObj{+entries} XVal{2n+q}:
      obj.fin(expand(entries, XFields{q, qset(entries, Nil{}), EOk{J.JNil{}}}, strict))
    case J.JCons{h, t} XItems{+p, acc}:
      expand(t, XItems{p, item.push(acc, expand(h, XVal{p}, strict))}, strict)
    case J.JECons{k, q, v, t} XFields{+p, +qs, acc}:
      expand(t, XFields{p, qs, field.ins(acc, k, qs, expand(v, XVal{p}, strict), strict, p)}, strict)
    case other XItems{p, acc}:
      acc
    case other XFields{p, qs, acc}:
      acc
    case v XVal{1n+p}:
      EOk{v}

# S4.249 expansion starts only after a complete, failure-free decode
def decode.x.fin(r: ER) -> DR:
  match r:
    case EOk{v}:
      DOk{v}
    case EErr{m}:
      DErr{m}

# S4.240 expand a decoded value (the root has c = 0)
def decode.x(r: DR, strict: Bool) -> DR:
  match r:
    case DErr{m}:
      DErr{m}
    case DOk{v}:
      decode.x.fin(expand(v, XVal{256n}, strict))

# S4.200 (5) the value of a TOON text under `--expand-paths safe`
def decode_expanded(text: String, +strict: Bool, unit: Nat) -> DR:
  decode.x(decode(text, strict, unit), strict)
