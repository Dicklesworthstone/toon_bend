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

# S2.113 the last character of the line (the head of the reversed content), kept unless it is CR
def cr.drop.if(cr: Bool, c: U32, rest: String) -> String:
  match cr:
    case True{}:
      rest
    case False{}:
      SCon{Chr{c}, rest}

# S2.113 one CR at the end of a line belongs to a CRLF line ending, not to the content
def cr.drop(rev: String) -> String:
  match rev:
    case SCon{Chr{+c}, rest}:
      cr.drop.if(U32.is_eq(c, 13), c, rest)
    case other:
      other

# S2.102 the end of a line (an LF, or the end of the text)
def scan.end(st: SS, strict: Bool, unit: Nat) -> SS:
  match st:
    case SS{num, lead, indent, run, tab, rev, lines, blanks, err}:
      scan.end.with(String.reverse(cr.drop(rev)), num, indent, tab, lines, blanks, err, strict, unit)

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

# S2.123 the character after a backslash inside a literal: one of the five escapes joins the text; any
# other is the first bad escape. After a bad escape the text is no longer kept (it can only fail)
def lit.esc(bad: Bool, k: Nat, c: U32, rev: String, badc: U32) -> UE:
  match bad k:
    case True{} _:
      UE{False{}, rev, True{}, badc}
    case False{} 1n:
      UE{False{}, SCon{Chr{10}, rev}, False{}, badc}
    case False{} 2n:
      UE{False{}, SCon{Chr{9}, rev}, False{}, badc}
    case False{} 3n:
      UE{False{}, SCon{Chr{13}, rev}, False{}, badc}
    case False{} 4n:
      UE{False{}, SCon{Chr{92}, rev}, False{}, badc}
    case False{} 5n:
      UE{False{}, SCon{Chr{34}, rev}, False{}, badc}
    case False{} _:
      UE{False{}, rev, True{}, c}

# S2.123 the escaped character, by its class
def lit.esc.ch(bad: Bool, ch: Char, rev: String, badc: U32) -> UE:
  match ch:
    case Chr{+c}:
      lit.esc(bad, unesc.cls(c), c, rev, badc)

# S2.123 a character that is neither a backslash nor the closing quote joins the text
def lit.plain(bad: Bool, ch: Char, rev: String, badc: U32) -> UE:
  match bad:
    case True{}:
      UE{False{}, rev, True{}, badc}
    case False{}:
      UE{False{}, SCon{ch, rev}, False{}, badc}

# S2.122 at the closing quote: S9.104 when it is not the last character of the (trimmed) token, then the
# first bad escape (S9.105), else the text
def lit.close(rest: String, st: UE) -> RS:
  match rest st:
    case SCon{c, more} _:
      RSErr{"Unexpected characters after closing quote"}
    case SNil{} UE{esc, rev, True{}, badc}:
      RSErr{"Invalid escape sequence: \\" ++ SCon{Chr{badc}, SNil{}}}
    case SNil{} UE{esc, rev, False{}, badc}:
      RSOk{String.reverse(rev)}

# S2.120, S2.122, S2.123 the literal in ONE walk (EXP-024): k is the class of the head of `s` (1 a double
# quote, 2 a backslash); a backslash takes the next character with it, as in quote.go, and the text is
# unescaped as it is read. S9.103 without a closing quote comes before every other failure
def lit.go(s: String, k: Nat, st: UE) -> RS:
  match s k st:
    case SNil{} _ _:
      RSErr{"Unterminated string: missing closing quote"}
    case SCon{ch, +rest} _ UE{True{}, rev, bad, badc}:
      lit.go(rest, quote.cls(rest), lit.esc.ch(bad, ch, rev, badc))
    case SCon{ch, rest} 1n UE{False{}, rev, bad, badc}:
      lit.close(rest, UE{False{}, rev, bad, badc})
    case SCon{ch, +rest} 2n UE{False{}, rev, bad, badc}:
      lit.go(rest, quote.cls(rest), UE{True{}, rev, bad, badc})
    case SCon{ch, +rest} _ UE{False{}, rev, bad, badc}:
      lit.go(rest, quote.cls(rest), lit.plain(bad, ch, rev, badc))

# S2.122 the text a string literal denotes, given the token after its opening quote
def lit(+s: String) -> RS:
  lit.go(s, quote.cls(s), UE{False{}, SNil{}, False{}, 0})

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
def prim.word(tr: Bool, fa: Bool, nu: Bool, +t: String, spec: Bool) -> RV:
  match tr fa nu:
    case True{} _ _:
      RVOk{J.JBool{True{}}}
    case False{} True{} _:
      RVOk{J.JBool{False{}}}
    case False{} False{} True{}:
      RVOk{J.JNull{}}
    case False{} False{} False{}:
      prim.num(F.literal(t, spec), t)

# S2.124 a bare token: a word, a number, or itself
def prim.bare(+t: String, spec: Bool) -> RV:
  prim.word(T.str_eq(t, "true"), T.str_eq(t, "false"), T.str_eq(t, "null"), t, spec)

# S2.124 (2) a token that starts with a double quote is a string literal, errors included
def prim.first(q: Bool, c: U32, rest: String, spec: Bool) -> RV:
  match q:
    case True{}:
      prim.lit(lit(rest))
    case False{}:
      prim.bare(SCon{Chr{c}, rest}, spec)

# S2.124 the primitive a TRIMMED token denotes; (1) the empty token is the empty string
def prim.t(t: String, spec: Bool) -> RV:
  match t:
    case SNil{}:
      RVOk{J.JStr{SNil{}}}
    case SCon{Chr{+c}, rest}:
      prim.first(U32.is_eq(c, 34), c, rest, spec)

# S2.124 the primitive a token denotes
def prim(token: String, spec: Bool) -> RV:
  prim.t(T.trim(token), spec)

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

# S2.126 the class of the first character of a text: 1 ASCII whitespace (U+0020, TAB, LF, FF, CR), 0
# anything else or none
def ascii_ws.cls(s: String) -> Nat:
  match s:
    case SNil{}:
      0n
    case SCon{Chr{+c}, rest}:
      Bool.pick(Nat, Bool.or(U32.is_eq(c, 32), Bool.or(U32.is_eq(c, 9), Bool.or(U32.is_eq(c, 10), Bool.or(U32.is_eq(c, 12), U32.is_eq(c, 13))))), 1n, 0n)

# S2.126 the text after its leading ASCII whitespace; k is the class of the head of s
def ascii_ws.go(s: String, k: Nat) -> String:
  match s k:
    case SCon{h, +rest} 1n:
      ascii_ws.go(rest, ascii_ws.cls(rest))
    case other _:
      other

# S2.126 the key token starts after leading ASCII whitespace: a quoted key preceded by whitespace is
# still a quoted key (its quotes are not part of the key)
def kv.start(content: String) -> KV:
  match content:
    case SNil{}:
      KVErr{"Missing colon after key"}
    case SCon{Chr{+c}, rest}:
      kv.first(U32.is_eq(c, 34), c, rest)

# S2.126 the key token and the value text of a key-value content
def kv(+content: String) -> KV:
  kv.start(ascii_ws.go(content, ascii_ws.cls(content)))

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

# S2.137 one piece (already WS-trimmed by the splitter); an empty piece is not a name (S9.148)
def field.one(name: String, rev: List<&2, Field>) -> FRes:
  match name:
    case SNil{}:
      FRErr{"Empty field name in field list"}
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

# S2.139 (7) a fields segment announces rows on the following lines: values after its colon fail
# (S9.149); otherwise the header is complete
def hdr.h(inline_after_seg: Bool, has_key: Bool, key: String, quoted: Bool, n: Nat, delim: U32, has_seg: Bool, fields: List<&2, Field>, inline: String) -> Hdr:
  match inline_after_seg:
    case True{}:
      HErr{"Unexpected content after fields-bearing header colon"}
    case False{}:
      HOk{has_key, key, quoted, n, delim, has_seg, fields, inline}

# S2.139 (6) the field names, unless one fails
def hdr.g(fr: FRes, has_key: Bool, key: String, quoted: Bool, n: Nat, delim: U32, +has_seg: Bool, +inline: String) -> Hdr:
  match fr:
    case FRErr{msg}:
      HErr{msg}
    case FROk{rev}:
      hdr.h(Bool.and(has_seg, Bool.not(String.is_empty(inline))), has_key, key, quoted, n, delim, has_seg, List.reverse(&2, Field, rev), inline)

# S2.137 a fields segment whose text is empty or White_Space only is not a field list (S9.148); no
# segment has no names
def hdr.names(has_seg: Bool, +seg: String, delim: U32) -> FRes:
  match has_seg:
    case False{}:
      FROk{Nil{}}
    case True{}:
      Bool.pick(FRes, T.is_blank(seg), FRErr{"Empty field list in array header"}, fields.go(split(seg, delim), FROk{Nil{}}))

# S2.136 the cap: a length above 100000000 fails in both modes (S9.107 prints the digits as written,
# leading zeros included; `canon` is their value's digits); S2.137 then the field names, split with the
# header's delimiter
def hdr.f(over: Bool, digits: String, +canon: String, has_key: Bool, key: String, quoted: Bool, +delim: U32, +has_seg: Bool, seg: String, inline: String) -> Hdr:
  match over:
    case True{}:
      HErr{"Declared array length " ++ digits ++ " exceeds maximum allowed (100000000)"}
    case False{}:
      hdr.g(hdr.names(has_seg, seg, delim), has_key, key, quoted, T.nat_of(canon, 0n), delim, has_seg, inline)

# S2.135 what stands between the brackets: usable or not, the delimiter, the digits as written
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

# S2.135 the length text once the delimiter mark is gone: one or more ASCII digits and nothing else
# (no sign, no space); anything else is not a length
def len.text(+s: String, delim: U32) -> HL:
  HL{all_digits(s), delim, s}

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
      Nat.is_gt(T.nat_of(digits, 0n), 100000000n)

# S2.136 the cap test over the digits of the value (leading zeros removed)
def hdr.e.canon(+canon: String, digits: String, has_key: Bool, key: String, quoted: Bool, delim: U32, has_seg: Bool, seg: String, inline: String) -> Hdr:
  hdr.f(len.over(Nat.is_gt(T.str_len(canon, 0n), 9n), canon), digits, canon, has_key, key, quoted, delim, has_seg, seg, inline)

# S2.139 (4) bad bracket content is "not a header", silently; (5) then the cap; a length of any size
# is a length (a value too large for the platform word is over the cap, not a key, S2.136)
def hdr.e(l: HL, has_key: Bool, key: String, quoted: Bool, has_seg: Bool, seg: String, inline: String) -> Hdr:
  match l:
    case HL{False{}, delim, digits}:
      HNot{}
    case HL{True{}, delim, +digits}:
      hdr.e.canon(len.canon(F.strip_zeros(digits)), digits, has_key, key, quoted, delim, has_seg, seg, inline)

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

# S2.132 a quote-aware search for the first occurrence of a character outside double quotes (inside
# quotes a backslash escapes the next character): the text before it (reversed) and after it, and,
# when there is none, whether the text ended inside quotes
type UC is Data:
  UC{found: Bool, rev: String, after: String, inq: Bool}

# S2.132 the class of the head of a text in the scan state: 0 an escaped character, 1 a backslash
# inside quotes, 2 a double quote, 3 the target outside quotes, 4 anything else, or no character
def ucut.cls(s: String, +inq: Bool, esc: Bool, k: U32) -> Nat:
  match s:
    case SNil{}:
      4n
    case SCon{Chr{+c}, rest}:
      Bool.pick(Nat, esc, 0n, Bool.pick(Nat, Bool.and(inq, U32.is_eq(c, 92)), 1n, Bool.pick(Nat, U32.is_eq(c, 34), 2n, Bool.pick(Nat, Bool.and(Bool.not(inq), U32.is_eq(c, k)), 3n, 4n))))

# S2.132 the scan (a loop over the text; code is ucut.cls of its head)
def ucut.go(s: String, code: Nat, +inq: Bool, rev: String, +k: U32) -> UC:
  match s code:
    case SNil{} _:
      UC{False{}, rev, SNil{}, inq}
    case SCon{h, rest} 3n:
      UC{True{}, rev, rest, inq}
    case SCon{h, +rest} 0n:
      ucut.go(rest, ucut.cls(rest, inq, False{}, k), inq, SCon{h, rev}, k)
    case SCon{h, +rest} 1n:
      ucut.go(rest, ucut.cls(rest, inq, True{}, k), inq, SCon{h, rev}, k)
    case SCon{h, +rest} 2n:
      ucut.go(rest, ucut.cls(rest, Bool.not(inq), False{}, k), Bool.not(inq), SCon{h, rev}, k)
    case SCon{h, +rest} _:
      ucut.go(rest, ucut.cls(rest, inq, False{}, k), inq, SCon{h, rev}, k)

# S2.132 the first k outside quotes in s
def ucut(+s: String, +k: U32) -> UC:
  ucut.go(s, ucut.cls(s, False{}, False{}, k), False{}, SNil{}, k)

# S2.132 the header colon, when it is the first character left
def hdr.c.colon.if(colon: Bool, rest: String, quoted: Bool, keyraw: String, inside: String, seg: String) -> Hdr:
  match colon:
    case True{}:
      hdr.d(quoted, keyraw, inside, True{}, seg, T.trim(rest))
    case False{}:
      HNot{}

# S2.133 after the fields segment only ASCII whitespace may come before the header colon; any other
# text means not a header
def hdr.c.colon(t: String, quoted: Bool, keyraw: String, inside: String, seg: String) -> Hdr:
  match t:
    case SNil{}:
      HNot{}
    case SCon{Chr{+c}, rest}:
      hdr.c.colon.if(U32.is_eq(c, 58), rest, quoted, keyraw, inside, seg)

# S2.132 the fields segment ends at the first '}' outside quotes (a quoted field name may hold '}',
# which the encoder writes raw inside its quotes). No such '}': a quote left open is S9.103; anything
# else is not a header.
def hdr.c.fields(u: UC, quoted: Bool, keyraw: String, inside: String) -> Hdr:
  match u:
    case UC{True{}, rev, +after, inq}:
      hdr.c.colon(ascii_ws.go(after, ascii_ws.cls(after)), quoted, keyraw, inside, String.reverse(rev))
    case UC{False{}, rev, after, True{}}:
      HErr{"Unterminated string: missing closing quote"}
    case UC{False{}, rev, after, False{}}:
      HNot{}

# S2.132, S2.133 1 a fields segment opens, 2 the header colon, 0 any other text
def hdr.c.pick(k: Nat, +rest: String, quoted: Bool, keyraw: String, inside: String) -> Hdr:
  match k:
    case 1n:
      hdr.c.fields(ucut(rest, 125), quoted, keyraw, inside)
    case 2n:
      hdr.d(quoted, keyraw, inside, False{}, SNil{}, T.trim(rest))
    case _:
      HNot{}

# S2.133 after the ']' only ASCII whitespace may come before '{' or ':'; any other text means the line
# is not a header (it is then a key-value line whose key is everything before the colon)
def hdr.c.seg(t: String, quoted: Bool, keyraw: String, inside: String) -> Hdr:
  match t:
    case SNil{}:
      HNot{}
    case SCon{Chr{+c}, rest}:
      hdr.c.pick(Bool.pick(Nat, U32.is_eq(c, 123), 1n, Bool.pick(Nat, U32.is_eq(c, 58), 2n, 0n)), rest, quoted, keyraw, inside)

# S2.131–S2.133 the text after the ']'
def hdr.c(+tail: String, quoted: Bool, keyraw: String, inside: String) -> Hdr:
  hdr.c.seg(ascii_ws.go(tail, ascii_ws.cls(tail)), quoted, keyraw, inside)

# S2.131 the first ']' after the bracket closes it; none means not a header
def hdr.b(r: T.Cut, quoted: Bool, keyraw: String) -> Hdr:
  match r:
    case T.Cut{False{}, before, after}:
      HNot{}
    case T.Cut{True{}, inside, tail}:
      hdr.c(tail, quoted, keyraw, inside)

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

# S2.130 an unquoted key has no ':', so a first '[' with a ':' before it belongs to the value
def hdr.a.key(colon: Bool, before: String, after: String) -> Hdr:
  match colon:
    case True{}:
      HNot{}
    case False{}:
      hdr.b(T.cut(after, 93), False{}, before)

# S2.130 without a leading quote the bracket is the first '[' of the content, when no ':' precedes it
def hdr.a.plain(c: T.Cut) -> Hdr:
  match c:
    case T.Cut{False{}, before, after}:
      HNot{}
    case T.Cut{True{}, +before, after}:
      hdr.a.key(T.has_char(before, 58), before, after)

# S2.130 an unquoted content without '[' is not a header; the cut (a copy of the text before the
# bracket) is made only when there is one (EXP-009: most lines have none, and the copy of the whole
# line was built and dropped for each of them)
def hdr.a.plain.pre(bracket: Bool, content: String) -> Hdr:
  match bracket:
    case True{}:
      hdr.a.plain(T.cut(content, 91))
    case False{}:
      HNot{}

# S2.130 quoted or not
def hdr.a.first(q: Bool, rest: String, +content: String) -> Hdr:
  match q:
    case True{}:
      hdr.a.quoted(quote.close(rest))
    case False{}:
      hdr.a.plain.pre(T.has_char(content, 91), content)

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

# S3.26 the value map of an object that met a repeated key (bead toon_bend-zgb: merging a later
# occurrence into the STORED entry chain cost that chain's length, so one key repeated n times whose
# object grows was quadratic). An AA tree over the keys, ordered by T.str_cmp (keys that collide in
# T.key_hash cost nothing extra). A node holds the key's quoted flag and either a plain value, or,
# when `hot`, an object still taking merges: its own map `sub` and its keys newest first in `ord`
# (JECons with JNull values: the chain gives the positions, the map the values and flags). Order
# never comes from the tree.
type HM is Data:
  HNil{}
  HNode{lv: Nat, l: HM, key: String, q: Bool, val: J.Json, hot: Bool, sub: HM, ord: J.Json, r: HM}

# S3.26 skew, decided: a left child on its parent's level becomes the parent
def hm.skew.pick(same: Bool, lv: Nat, llv: Nat, a: HM, lk: String, lq: Bool, lval: J.Json, lhot: Bool, lsub: HM, lord: J.Json, b: HM, x: String, xq: Bool, xv: J.Json, xhot: Bool, xsub: HM, xord: J.Json, r: HM) -> HM:
  match same:
    case True{}:
      HNode{llv, a, lk, lq, lval, lhot, lsub, lord, HNode{lv, b, x, xq, xv, xhot, xsub, xord, r}}
    case False{}:
      HNode{lv, HNode{llv, a, lk, lq, lval, lhot, lsub, lord, b}, x, xq, xv, xhot, xsub, xord, r}

# S3.26 skew: remove a left horizontal link by a right rotation
def hm.skew(t: HM) -> HM:
  match t:
    case HNode{+lv, HNode{+llv, a, lk, lq, lval, lhot, lsub, lord, b}, x, xq, xv, xhot, xsub, xord, r}:
      hm.skew.pick(Nat.is_eq(llv, lv), lv, llv, a, lk, lq, lval, lhot, lsub, lord, b, x, xq, xv, xhot, xsub, xord, r)
    case other:
      other

# S3.26 the level of a tree's root (0 for the empty tree)
def hm.level(t: HM) -> Nat:
  match t:
    case HNil{}:
      0n
    case HNode{lv, l, x, xq, xv, xhot, xsub, xord, r}:
      lv

# S3.26 split, decided: the middle of three nodes on one level is lifted a level
def hm.split.pick(same: Bool, lv: Nat, a: HM, x: String, xq: Bool, xv: J.Json, xhot: Bool, xsub: HM, xord: J.Json, rlv: Nat, b: HM, rk: String, rq: Bool, rval: J.Json, rhot: Bool, rsub: HM, rord: J.Json, rr: HM) -> HM:
  match same:
    case True{}:
      HNode{1n+rlv, HNode{lv, a, x, xq, xv, xhot, xsub, xord, b}, rk, rq, rval, rhot, rsub, rord, rr}
    case False{}:
      HNode{lv, a, x, xq, xv, xhot, xsub, xord, HNode{rlv, b, rk, rq, rval, rhot, rsub, rord, rr}}

# S3.26 split: remove two right horizontal links in a row by a left rotation
def hm.split(t: HM) -> HM:
  match t:
    case HNode{+lv, a, x, xq, xv, xhot, xsub, xord, HNode{rlv, b, rk, rq, rval, rhot, rsub, rord, +rr}}:
      hm.split.pick(Nat.is_eq(hm.level(rr), lv), lv, a, x, xq, xv, xhot, xsub, xord, rlv, b, rk, rq, rval, rhot, rsub, rord, rr)
    case other:
      other

# S3.26 a key against the key at the root (the verdict is not read on the empty tree)
def hm.root(t: HM, k: String) -> T.Ord:
  match t:
    case HNil{}:
      T.OEq{}
    case HNode{lv, l, x, xq, xv, xhot, xsub, xord, r}:
      T.str_cmp(k, x)

# S3.26 set a key: c is the key against this root (the caller of each step looks at the child's
# root, so the descent is one structural recursion); a key already there takes the new flag and value
def hm.put.go(t: HM, +k: String, q: Bool, v: J.Json, hot: Bool, sub: HM, ord: J.Json, c: T.Ord) -> HM:
  match t c:
    case HNil{} _:
      HNode{1n, HNil{}, k, q, v, hot, sub, ord, HNil{}}
    case HNode{lv, +l, x, xq, xv, xhot, xsub, xord, r} T.OLt{}:
      hm.split(hm.skew(HNode{lv, hm.put.go(l, k, q, v, hot, sub, ord, hm.root(l, k)), x, xq, xv, xhot, xsub, xord, r}))
    case HNode{lv, l, x, xq, xv, xhot, xsub, xord, +r} T.OGt{}:
      hm.split(hm.skew(HNode{lv, l, x, xq, xv, xhot, xsub, xord, hm.put.go(r, k, q, v, hot, sub, ord, hm.root(r, k))}))
    case HNode{lv, l, x, xq, xv, xhot, xsub, xord, r} T.OEq{}:
      HNode{lv, l, x, q, v, hot, sub, ord, r}

# S3.26 set a key to a flag and a plain value, or to a hot object (its map and its key order)
def hm.put(+t: HM, +k: String, q: Bool, v: J.Json, hot: Bool, sub: HM, ord: J.Json) -> HM:
  hm.put.go(t, k, q, v, hot, sub, ord, hm.root(t, k))

# S3.26 what a tree holds under a key
type HGR is Data:
  HGRNone{}
  HGRSome{q: Bool, val: J.Json, hot: Bool, sub: HM, ord: J.Json}

# S3.26 what a tree holds under a key: c is the key against this root
def hm.get.go(t: HM, +k: String, c: T.Ord) -> HGR:
  match t c:
    case HNil{} _:
      HGRNone{}
    case HNode{lv, +l, x, xq, xv, xhot, xsub, xord, r} T.OLt{}:
      hm.get.go(l, k, hm.root(l, k))
    case HNode{lv, l, x, xq, xv, xhot, xsub, xord, +r} T.OGt{}:
      hm.get.go(r, k, hm.root(r, k))
    case HNode{lv, l, x, xq, xv, xhot, xsub, xord, r} T.OEq{}:
      HGRSome{xq, xv, xhot, xsub, xord}

# S3.26 what a tree holds under a key
def hm.get(+t: HM, +k: String) -> HGR:
  hm.get.go(t, k, hm.root(t, k))

# S3.26 the plain entries of a chain put into a tree (its keys are unique)
def hm.of(c: J.Json, acc: HM) -> HM:
  match c:
    case J.JECons{+k, q, v, t}:
      hm.of(t, hm.put(acc, k, q, v, False{}, HNil{}, J.JNil{}))
    case other:
      acc

# S3.26 the keys of an entry chain (in order) newest first, with JNull values: a hot object's order
def hm.ord(c: J.Json, acc: J.Json) -> J.Json:
  match c:
    case J.JECons{k, q, v, t}:
      hm.ord(t, J.JECons{k, q, J.JNull{}, acc})
    case other:
      acc

# S3.26 one entry of a closing object: the chain gives the key its FIRST position, the map gives the
# value and the quoted flag the key ends with (a repeated key updated the map, never the chain)
def obj.pair(m: Maybe<&2, J.Json>, k: String, q: Bool, v: J.Json, acc: J.Json) -> J.Json:
  match m:
    case Some{J.JECons{k2, q2, v2, t2}}:
      J.JECons{k, q2, v2, acc}
    case other:
      J.JECons{k, q, v, acc}

# S3.26 the entries of a closing object, in first-occurrence order (the chain is newest first, so
# walking it and prepending gives document order)
def obj.entries(c: J.Json, +km: J.KM, acc: J.Json) -> J.Json:
  match c:
    case J.JECons{+k, q, v, t}:
      obj.entries(t, km, obj.pair(J.km.get(km, k), k, q, v, acc))
    case other:
      acc

# S3.26 the final value of a node: a plain value, or a hot object built from its order and the final
# values of its map
def hm.fin(hot: Bool, val: J.Json, ord: J.Json, +m: J.KM) -> J.Json:
  match hot:
    case True{}:
      J.JObj{obj.entries(ord, m, J.JNil{})}
    case False{}:
      val

# S3.26 the final entries of a tree, each hot object built bottom-up, as a key map (one structural
# recursion over the left subtree, the node's own map and the right subtree)
def hm.mat(h: HM, acc: J.KM) -> J.KM:
  match h:
    case HNil{}:
      acc
    case HNode{lv, l, +k, q, val, hot, sub, ord, r}:
      hm.mat(r, hm.mat(l, J.km.put(acc, k, J.JECons{k, q, hm.fin(hot, val, ord, hm.mat(sub, J.km.empty())), J.JNil{}})))

# S4.204–S4.225 an open construct.
# FObj: an object: entries so far (newest first), the set of their keys, and HNil until a key repeats,
#   then the map of their values (from then on the chain holds JNull values and gives positions only); the base depth b (a line
#   less deep belongs to an enclosing construct) and the depth d of its fields (fixed by the first
#   field; d = b in strict mode, S4.206); whether it is a list-item object (then a list-item line is
#   not a field, S4.225); and the key (with its quoted flag) under which the construct opened above it
#   will be stored.
# FTab: a tabular body: rows so far, declared length N, rows read, row depth r, the fields and their
#   count, the delimiter, the blank-line candidate of the body (blank.start), and whether two fields
#   share a name (then each row resolves its repeated keys, S3.26).
# FList: a list body: items so far, N, items read, item depth t, the blank-line candidate.
type Frame is Data:
  FObj{rev: J.Json, kt: T.KT, hm: HM, b: Nat, d: Nat, item: Bool, key: String, q: Bool}
  FTab{rev: J.Json, n: Nat, cnt: Nat, r: Nat, fields: List<&2, Field>, nf: Nat, delim: U32, cand: Nat, dupf: Bool}
  FList{rev: J.Json, n: Nat, cnt: Nat, t: Nat, cand: Nat}

# S3.29 what does not change shape during the pass: strict mode, the blank-line numbers (ascending),
# the number of the line consumed last, the numeric kill-switch (TOON_SPEC=1), and the first repeated
# key that could not be merged (strict mode, S3.26): it is reported only when the pass itself succeeds
type G is Data:
  G{strict: Bool, blanks: List<&2, Nat>, last: Nat, spec: Bool, dup: Maybe<&2, String>}

# S3.29 the numeric kill-switch (TOON_SPEC=1)
def g.spec(g: G) -> Bool:
  match g:
    case G{strict, blanks, last, spec, dup}:
      spec

# S3.29 strict mode
def g.strict(g: G) -> Bool:
  match g:
    case G{strict, blanks, last, spec, dup}:
      strict

# S3.29 the number of the line consumed last
def g.last(g: G) -> Nat:
  match g:
    case G{strict, blanks, last, spec, dup}:
      last

# S3.26 keep the FIRST repeated-key failure
def dup.keep(old: Maybe<&2, String>, new: Maybe<&2, String>) -> Maybe<&2, String>:
  match old:
    case Some{m}:
      Some{m}
    case None{}:
      new

# S3.26 note a repeated-key failure in G
def g.dup(g: G, new: Maybe<&2, String>) -> G:
  match g:
    case G{strict, blanks, last, spec, dup}:
      G{strict, blanks, last, spec, dup.keep(dup, new)}

# S3.29 one line of look-ahead: the next unread line's number, depth and content, or the end
type Peek is Data:
  PNone{}
  PLine{num: Nat, depth: Nat, content: String}

# S4.207 what the machine does next: offer the next line to the innermost construct, close the
# innermost construct, stop with a message, or stop with the root value and the pending repeated-key
# failure (S4.202: lines after a complete root array are S9.152 in strict mode)
type Step is Data:
  SEat{frames: List<&2, Frame>, g: G}
  SPop{frames: List<&2, Frame>, g: G}
  SErr{msg: String}
  SDone{v: J.Json, dup: Maybe<&2, String>}

# S3.29 look at the next unread line
def peek(ls: List<&2, Line>) -> Peek:
  match ls:
    case Nil{}:
      PNone{}
    case Con{Line{num, depth, content}, rest}:
      PLine{num, depth, content}

# S4.206, S4.225 an object and the next line: 0 the line belongs to an enclosing construct (less deep
# than the base, or a list-item line in a list-item object), 1 a field (at the field depth; in lenient
# mode also any deeper line, which keeps its own depth as its base, S4.206), 2 an over-indented line
# (strict: S9.150)
def fits.obj(below: Bool, marker: Bool, same: Bool, strict: Bool) -> Nat:
  match below marker same strict:
    case True{} _ _ _:
      0n
    case False{} True{} _ _:
      0n
    case False{} False{} True{} _:
      1n
    case False{} False{} False{} True{}:
      2n
    case False{} False{} False{} False{}:
      1n

# S4.212 a row while the table is not full (strict: fewer than N rows were read; lenient: any number,
# S4.212 (4)), at the row depth, and a data row (S4.214: a key-value line ends the rows); S4.215 an
# item likewise, at the item depth, and a list item (S2.140). 0 close, 1 consume, 2 over-indented.
def fits(f: Frame, +depth: Nat, +content: String, +strict: Bool) -> Nat:
  match f:
    case FObj{rev, kt, km, b, d, item, key, q}:
      fits.obj(Nat.is_lt(depth, b), Bool.and(item, is_item(content)), Nat.is_eq(depth, d), strict)
    case FTab{rev, n, cnt, r, fields, nf, delim, first, dupf}:
      Bool.pick(Nat, Bool.and(Bool.or(Bool.not(strict), Nat.is_lt(cnt, n)), Bool.and(Nat.is_eq(depth, r), is_row(content, delim))), 1n, 0n)
    case FList{rev, n, cnt, t, first}:
      Bool.pick(Nat, Bool.and(Bool.or(Bool.not(strict), Nat.is_lt(cnt, n)), Bool.and(Nat.is_eq(depth, t), is_item(content))), 1n, 0n)

# S4.206 the field depth of the innermost object (for S9.150)
def fields.depth(f: Frame) -> Nat:
  match f:
    case FObj{rev, kt, km, b, d, item, key, q}:
      d
    case other:
      0n

# S4.207 consume, close, or report an over-indented line (S9.150)
def decide.if(k: Nat, +num: Nat, +depth: Nat, frames: List<&2, Frame>, g: G) -> Step:
  match k frames:
    case 1n fs:
      SEat{fs, g}
    case 2n Con{+f, more}:
      SErr{"Validation error at line " ++ Nat.show(num) ++ ": Over-indented line: expected depth " ++ Nat.show(fields.depth(f)) ++ ", but found " ++ Nat.show(depth)}
    case _ fs:
      SPop{fs, g}

# S4.207 a line that does not fit the innermost construct closes it and is offered to the next one; at
# the end of the lines every construct closes in turn
def decide(frames: List<&2, Frame>, pk: Peek, +g: G) -> Step:
  match frames pk:
    case Nil{} _:
      SErr{"internal: no open construct"}
    case Con{f, more} PNone{}:
      SPop{f <> more, g}
    case Con{+f, more} PLine{+num, +depth, content}:
      decide.if(fits(f, depth, content, g.strict(g)), num, depth, f <> more, g)

# S3.26 the outcome of storing entries whose keys may already be present: the entries (in order) and
# the first failure, if any
type MR is Data:
  MR{entries: J.Json, err: Maybe<&2, String>}

# S3.26 the entries of an outcome
def mr.entries(m: MR) -> J.Json:
  match m:
    case MR{entries, err}:
      entries

# S3.26 the failure of an outcome
def mr.err(m: MR) -> Maybe<&2, String>:
  match m:
    case MR{entries, err}:
      err

# S3.26 the value under a key in an entry chain, if any (a loop over the chain; keys are unique)
def entry.get(c: J.Json, +k: String) -> Maybe<&2, J.Json>:
  match c:
    case J.JECons{+ek, q, v, t}:
      Bool.pick(Maybe<&2, J.Json>, T.str_eq(ek, k), Some{v}, entry.get(t, k))
    case other:
      None{}

# S3.26 the entry chain with the entry under k replaced in place, reversed onto acc
def entry.set.go(c: J.Json, +k: String, +q: Bool, +v: J.Json, acc: J.Json) -> J.Json:
  match c:
    case J.JECons{+ek, eq, ev, t}:
      entry.set.go(t, k, q, v, J.JECons{ek, Bool.pick(Bool, T.str_eq(ek, k), q, eq), Bool.pick(J.Json, T.str_eq(ek, k), v, ev), acc})
    case other:
      acc

# S3.26 replace the entry under k, keeping its position
def entry.set(c: J.Json, k: String, q: Bool, v: J.Json) -> J.Json:
  J.rev_entries(entry.set.go(c, k, q, v, J.JNil{}), J.JNil{})

# S3.26 an entry appended after the others
def entry.add(c: J.Json, k: String, q: Bool, v: J.Json) -> J.Json:
  J.rev_entries(J.JECons{k, q, v, J.rev_entries(c, J.JNil{})}, J.JNil{})

# S9.151 the failure of a repeated key whose values do not merge
def dup.msg(k: String) -> String:
  "Duplicate sibling key \"" ++ k ++ "\""

# S3.26 the value already stored under the key of the head entry of `src`, if any
def dups.look(src: J.Json, tgt: J.Json) -> Maybe<&2, J.Json>:
  match src:
    case J.JECons{+k, q, v, t}:
      entry.get(tgt, k)
    case other:
      None{}

# S3.26 store the entries of `src` (in order) into `tgt` (in order); `look` is merge.look of the head
# of src. A new key is appended. A key already present: two objects merge recursively (ONE def: the
# nested merge is on a part of src); any other pair is a failure in strict mode (the earlier value
# stays) and the later value in the earlier one's position in lenient mode. The later entry's quoted
# flag is kept.
def dups.go(src: J.Json, look: Maybe<&2, J.Json>, +tgt: J.Json, +strict: Bool, err: Maybe<&2, String>) -> MR:
  match src look strict:
    case J.JECons{+k, +q, +v, +t} None{} _:
      +tgt2 = entry.add(tgt, k, q, v)
      dups.go(t, dups.look(t, tgt2), tgt2, strict, err)
    case J.JECons{+k, +q, J.JObj{+se}, +t} Some{J.JObj{+te}} _:
      +m = dups.go(se, dups.look(se, te), te, strict, err)
      +tgt2 = entry.set(tgt, k, q, J.JObj{mr.entries(m)})
      dups.go(t, dups.look(t, tgt2), tgt2, strict, mr.err(m))
    case J.JECons{+k, q, v, +t} Some{ev} True{}:
      dups.go(t, dups.look(t, tgt), tgt, strict, dup.keep(err, Some{dup.msg(k)}))
    case J.JECons{+k, +q, +v, +t} Some{ev} False{}:
      +tgt2 = entry.set(tgt, k, q, v)
      dups.go(t, dups.look(t, tgt2), tgt2, strict, err)
    case other _ _:
      MR{tgt, err}

# S3.26 store entries (in order) into entries (in order)
def dups(+src: J.Json, +tgt: J.Json, strict: Bool) -> MR:
  dups.go(src, dups.look(src, tgt), tgt, strict, None{})

# S3.26 what a later occurrence meets under its key in a tree: nothing (a new key), an object to merge
# into (both values are objects; a plain stored object is made hot here, once), or a value that does not
# merge (then nothing stored is needed: strict mode keeps it, lenient mode overwrites it)
type HG is Data:
  HGNone{}
  HGObj{sub: HM, ord: J.Json}
  HGVal{}

# S3.26 whether a value is an object
def hot.is_obj(v: J.Json) -> Bool:
  match v:
    case J.JObj{e}:
      True{}
    case other:
      False{}

# S3.26 the verdict for a later value that is an object against what is stored
def hot.verdict.obj(r: HGR) -> HG:
  match r:
    case HGRNone{}:
      HGNone{}
    case HGRSome{q, val, True{}, sub, ord}:
      HGObj{sub, ord}
    case HGRSome{q, J.JObj{+te}, False{}, sub, ord}:
      HGObj{hm.of(te, HNil{}), hm.ord(te, J.JNil{})}
    case other:
      HGVal{}

# S3.26 the verdict for a later value that is not an object against what is stored
def hot.verdict.val(r: HGR) -> HG:
  match r:
    case HGRNone{}:
      HGNone{}
    case other:
      HGVal{}

# S3.26 the verdict for a later value (src_obj: whether it is an object) against what is stored
def hot.verdict(src_obj: Bool, r: HGR) -> HG:
  match src_obj:
    case True{}:
      hot.verdict.obj(r)
    case False{}:
      hot.verdict.val(r)

# S3.26 the verdict for the head entry of a source chain
def hot.look(src: J.Json, +m: HM) -> HG:
  match src:
    case J.JECons{+k, q, v, t}:
      hot.verdict(hot.is_obj(v), hm.get(m, k))
    case other:
      HGNone{}

# S3.26 a merge's outcome: the target's map, its key order, and the first failure
type HR is Data:
  HR{map: HM, ord: J.Json, err: Maybe<&2, String>}

# S3.26 the map of an outcome
def hr.map(r: HR) -> HM:
  match r:
    case HR{m, o, e}:
      m

# S3.26 the key order of an outcome
def hr.ord(r: HR) -> J.Json:
  match r:
    case HR{m, o, e}:
      o

# S3.26 the failure of an outcome
def hr.err(r: HR) -> Maybe<&2, String>:
  match r:
    case HR{m, o, e}:
      e

# S3.26 the entries of an outcome in first-occurrence order (what the laws compare with dups)
def hr.entries(r: HR) -> J.Json:
  match r:
    case HR{m, o, e}:
      obj.entries(o, hm.mat(m, J.km.empty()), J.JNil{})

# S3.26 store the entries of `src` (in order) into a hot object (its map m and key order ord); `look`
# is hot.look of the head of src. A new key is appended. A key already present: two objects merge
# recursively (ONE def: the nested merge is on a part of src, and costs the size of that part, never
# the size of the target); any other pair is a failure in strict mode (the earlier value stays) and the
# later value in the earlier one's position in lenient mode. The later entry's quoted flag is kept.
def hot.merge(src: J.Json, look: HG, +m: HM, +ord: J.Json, +strict: Bool, err: Maybe<&2, String>) -> HR:
  match src look strict:
    case J.JECons{+k, +q, +v, +t} HGNone{} _:
      +m2 = hm.put(m, k, q, v, False{}, HNil{}, J.JNil{})
      hot.merge(t, hot.look(t, m2), m2, J.JECons{k, q, J.JNull{}, ord}, strict, err)
    case J.JECons{+k, +q, J.JObj{+se}, +t} HGObj{+s0, +o0} _:
      +r = hot.merge(se, hot.look(se, s0), s0, o0, strict, err)
      +m2 = hm.put(m, k, q, J.JNull{}, True{}, hr.map(r), hr.ord(r))
      hot.merge(t, hot.look(t, m2), m2, ord, strict, hr.err(r))
    case J.JECons{+k, q, v, +t} HGVal{} True{}:
      hot.merge(t, hot.look(t, m), m, ord, strict, dup.keep(err, Some{dup.msg(k)}))
    case J.JECons{+k, +q, +v, +t} HGVal{} False{}:
      +m2 = hm.put(m, k, q, v, False{}, HNil{}, J.JNil{})
      hot.merge(t, hot.look(t, m2), m2, ord, strict, err)
    case other _ _:
      HR{m, ord, err}

# S3.26 merge an entry chain into an object's entries through the hot map (the frame's path, as one
# def the laws can state against dups, the spec's merge over entry chains)
def hot.dups(+src: J.Json, +te: J.Json, strict: Bool) -> HR:
  hot.merge(src, hot.look(src, hm.of(te, HNil{})), hm.of(te, HNil{}), hm.ord(te, J.JNil{}), strict, None{})

# S3.26 the frame's map at its first repeated key: the chain's entries, all plain (before that, the
# chain alone holds the values and no map is kept)
def hm.frame(h: HM, rev: J.Json) -> HM:
  match h:
    case HNil{}:
      hm.of(rev, HNil{})
    case other:
      other

# S3.26 the frame after a repeated key: the CHAIN keeps the key's first position and is not touched,
# the MAP takes the merged value (rounds 16-17, beads toon_bend-qgu and toon_bend-zgb: walking a chain
# per repeated key made the merge quadratic at the outer and at the nested level)
def attach.dup(r: HR, rev: J.Json, kt: T.KT, b: Nat, d: Nat, item: Bool, more: List<&2, Frame>, pk: Peek, +g: G) -> Step:
  match r:
    case HR{m, o, err}:
      decide(FObj{rev, kt, m, b, d, item, SNil{}, False{}} <> more, pk, g.dup(g, err))

# S3.26 merge the later occurrence (the one-entry chain src) into the frame's map h1
def attach.src(+src: J.Json, +h1: HM, rev: J.Json, kt: T.KT, b: Nat, d: Nat, item: Bool, more: List<&2, Frame>, pk: Peek, +g: G) -> Step:
  attach.dup(hot.merge(src, hot.look(src, h1), h1, J.JNil{}, g.strict(g), None{}), rev, kt, b, d, item, more, pk, g)

# S3.22 a new key: stored in the chain and the key set, and in the map once there is one (the chain
# then holds a JNull: the value lives in the map alone)
def attach.new(h: HM, +v: J.Json, rev: J.Json, kt: T.KT, b: Nat, d: Nat, item: Bool, +key: String, +q: Bool, more: List<&2, Frame>, pk: Peek, g: G) -> Step:
  match h:
    case HNil{}:
      decide(FObj{J.JECons{key, q, v, rev}, T.kt.put(kt, key), HNil{}, b, d, item, SNil{}, False{}} <> more, pk, g)
    case other:
      decide(FObj{J.JECons{key, q, J.JNull{}, rev}, T.kt.put(kt, key), hm.put(other, key, q, v, False{}, HNil{}, J.JNil{}), b, d, item, SNil{}, False{}} <> more, pk, g)

# S3.22, S3.26 a finished value under the pending key of an object: a new key is stored (attach.new);
# a key stored before is merged (S3.26) in the MAP alone, as the one-entry chain of the later
# occurrence, and G remembers the first failure
def attach.obj(seen: Bool, +v: J.Json, +rev: J.Json, +kt: T.KT, +h0: HM, b: Nat, d: Nat, item: Bool, +key: String, +q: Bool, more: List<&2, Frame>, pk: Peek, +g: G) -> Step:
  match seen:
    case False{}:
      attach.new(h0, v, rev, kt, b, d, item, key, q, more, pk, g)
    case True{}:
      attach.src(J.JECons{key, q, v, J.JNil{}}, hm.frame(h0, rev), rev, kt, b, d, item, more, pk, g)

# S3.22 a finished value goes to the construct that awaits it: under the pending key of an object, as
# the next item of a list, or, with nothing open, it is the root value and the pass ends
def attach(v: J.Json, frames: List<&2, Frame>, pk: Peek, g: G) -> Step:
  match frames g:
    case Nil{} G{strict, blanks, last, spec, dup}:
      SDone{v, dup}
    case Con{FObj{rev, +kt, +km, b, d, item, +key, q}, more} g0:
      attach.obj(T.kt.has(kt, key), v, rev, kt, km, b, d, item, key, q, more, pk, g0)
    case Con{FList{rev, n, cnt, t, first}, more} g0:
      decide(FList{J.JCons{v, rev}, n, 1n+cnt, t, first} <> more, pk, g0)
    case Con{FTab{rev, n, cnt, r, fields, nf, delim, first, dupf}, more} g0:
      SErr{"internal: a value inside a tabular body"}

# S6.44 whether the first blank-line number is below a line number
def blank.lt(bs: List<&2, Nat>, num: Nat) -> Bool:
  match bs:
    case Nil{}:
      False{}
    case Con{b, rest}:
      Nat.is_lt(b, num)

# S6.44 the blank-line numbers are ascending and lines are consumed in order, so the numbers below the
# line being consumed are dropped for good: every open body has already noted its candidate (each
# number is dropped once; re-scanning them at every body made the pass quadratic in round 6's probes)
def blank.drop(bs: List<&2, Nat>, lt: Bool, +num: Nat) -> List<&2, Nat>:
  match bs lt:
    case Con{b, +rest} True{}:
      blank.drop(rest, blank.lt(rest, num), num)
    case other _:
      other

# S4.213 (2), S4.215 (2) a body's candidate: 0 before its first line; then the number of the first
# blank line AFTER that first line, or 1 when there is none (a line number after a first line is >= 2).
# `bs` is the list already dropped up to the line being consumed.
def blank.start(cand: Nat, bs: List<&2, Nat>) -> Nat:
  match cand bs:
    case 0n Nil{}:
      1n
    case 0n Con{b, rest}:
      b
    case 1n+c _:
      1n+c

# S4.213 (2), S4.215 (2) the first blank line strictly between a body's first line and the last line it
# consumed, or 0
def blank.in(+cand: Nat, last: Nat) -> Nat:
  Bool.pick(Nat, Bool.and(Nat.is_ge(cand, 2n), Nat.is_lt(cand, last)), cand, 0n)

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
    case PLine{num, depth, +content}:
      Bool.and(Nat.is_eq(depth, r), Bool.and(Bool.not(is_dash_sp(content)), is_row(content, delim)))

# S4.215 (3) the next unread line sits at the item depth and is a list item (`- ` or a bare `-`)
def surplus.list(pk: Peek, t: Nat) -> Bool:
  match pk:
    case PNone{}:
      False{}
    case PLine{num, depth, content}:
      Bool.and(Nat.is_eq(depth, t), is_item(content))

# S4.213, S4.215 a body that fails its checks ends the pass; otherwise its array goes to its parent
def close.fin(msg: Maybe<&2, String>, v: J.Json, frames: List<&2, Frame>, pk: Peek, g: G) -> Step:
  match msg:
    case Some{m}:
      SErr{m}
    case None{}:
      attach(v, frames, pk, g)

# S3.26 the entries of a closing object in first-occurrence order: with no repeated key the chain
# (newest first) reversed; otherwise the chain gives the positions and the map's final values fill them
def obj.close(h: HM, rev: J.Json) -> J.Json:
  match h:
    case HNil{}:
      J.rev_entries(rev, J.JNil{})
    case other:
      obj.entries(rev, hm.mat(other, J.km.empty()), J.JNil{})

# S4.207 close the innermost construct: an object simply ends (its keys are unique, S3.26); a body
# runs its checks first
def pop(frames: List<&2, Frame>, +pk: Peek, g: G) -> Step:
  match frames g:
    case Nil{} g0:
      SErr{"internal: nothing to close"}
    case Con{FObj{rev, kt, h, b, d, item, key, q}, more} g0:
      attach(J.JObj{obj.close(h, rev)}, more, pk, g0)
    case Con{FTab{rev, +n, +cnt, r, fields, nf, delim, first, dupf}, more} G{+strict, +blanks, +last, spec, dup}:
      close.fin(close.msg(strict, Nat.is_ne(cnt, n), blank.in(first, last), surplus.tab(pk, r, delim), True{}, n, cnt), J.JArr{cnt, J.rev_items(rev, J.JNil{})}, more, pk, G{strict, blanks, last, spec, dup})
    case Con{FList{rev, +n, +cnt, t, first}, more} G{+strict, +blanks, +last, spec, dup}:
      close.fin(close.msg(strict, Nat.is_ne(cnt, n), blank.in(first, last), surplus.list(pk, t), False{}, n, cnt), J.JArr{cnt, J.rev_items(rev, J.JNil{})}, more, pk, G{strict, blanks, last, spec, dup})

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
def prims.go(vals: List<&2, String>, st: PR, +spec: Bool) -> PR:
  match vals st:
    case Nil{} s:
      s
    case Con{v, rest} PRErr{msg}:
      PRErr{msg}
    case Con{v, rest} PROk{rev, cnt}:
      prims.go(rest, prims.add(prim(v, spec), rev, cnt), spec)

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
    case PROk{rev, +cnt} G{+strict, blanks, last, spec, dup}:
      inline.fin(Bool.and(strict, Nat.is_ne(cnt, n)), n, cnt, rev, frames, pk, G{strict, blanks, last, spec, dup})

# S4.230 whether opening `extra` more nested objects or arrays inside the open constructs (one per
# frame) would pass the limit of 127 (the JSON reader's, S2.20)
def nest.over(frames: List<&2, Frame>, extra: Nat) -> Bool:
  Nat.is_gt(Nat.add(T.llen(&2, Frame, frames, 0n), extra), 127n)

# S9.153 the nesting failure names the line that opens the container
def nest.msg(num: Nat) -> String:
  "Validation error at line " ++ Nat.show(num) ++ ": Nesting depth exceeds 127 levels"

# S3.26 the loop of fields.dup: whether a name was seen before
def fields.dup.go(fs: List<&2, Field>, +seen: T.KT, hit: Bool) -> Bool:
  match fs hit:
    case _ True{}:
      True{}
    case Nil{} False{}:
      False{}
    case Con{Field{+name, q}, rest} False{}:
      fields.dup.go(rest, T.kt.put(seen, name), T.kt.has(seen, name))

# S3.26 whether two field names are equal (then every row merges its repeated keys)
def fields.dup(fs: List<&2, Field>) -> Bool:
  fields.dup.go(fs, T.kt.empty(), False{})

# S4.210 the body of a parsed header at base depth d: inline values; else a tabular body when there is
# at least one field name; else a list body (also for `k[0]:`, S4.216). Rows and items are expected at
# depth d + 1. The array is one more container; a tabular body's rows are two (S4.230).
def array.open(has_inline: Bool, has_fields: Bool, n: Nat, +delim: U32, +fields: List<&2, Field>, inline_text: String, d: Nat, frames: List<&2, Frame>, pk: Peek, +g: G) -> Step:
  match has_inline has_fields:
    case True{} _:
      inline(prims.go(split(inline_text, delim), PROk{J.JNil{}, 0n}, g.spec(g)), n, frames, pk, g)
    case False{} True{}:
      decide(FTab{J.JNil{}, n, 0n, 1n+d, fields, T.llen(&2, Field, fields, 0n), delim, 0n, fields.dup(fields)} <> frames, pk, g)
    case False{} False{}:
      decide(FList{J.JNil{}, n, 0n, 1n+d, 0n} <> frames, pk, g)

# S4.230 the nesting limit first
def array.nest(over: Bool, has_inline: Bool, has_fields: Bool, n: Nat, delim: U32, fields: List<&2, Field>, inline_text: String, d: Nat, frames: List<&2, Frame>, pk: Peek, +g: G) -> Step:
  match over:
    case True{}:
      SErr{nest.msg(g.last(g))}
    case False{}:
      array.open(has_inline, has_fields, n, delim, fields, inline_text, d, frames, pk, g)

# S4.210 the body of a parsed header
def array(+has_inline: Bool, +has_fields: Bool, n: Nat, delim: U32, fields: List<&2, Field>, inline_text: String, d: Nat, +frames: List<&2, Frame>, pk: Peek, g: G) -> Step:
  array.nest(nest.over(frames, Bool.pick(Nat, Bool.and(has_fields, Bool.not(has_inline)), 2n, 1n)), has_inline, has_fields, n, delim, fields, inline_text, d, frames, pk, g)

# S4.205 (b) a value token
def eat.prim(r: RV, frames: List<&2, Frame>, pk: Peek, g: G) -> Step:
  match r:
    case RVErr{msg}:
      SErr{msg}
    case RVOk{v}:
      attach(v, frames, pk, g)

# S4.205 (b), S4.206 the depth of the next unread line when it is deeper than the base (it then fixes
# the depth of the nested fields), else 0
def deeper(pk: Peek, base: Nat) -> Nat:
  match pk:
    case PNone{}:
      0n
    case PLine{num, +depth, content}:
      Bool.pick(Nat, Nat.is_gt(depth, base), depth, 0n)

# S9.154 the number of the next unread line (0 at the end)
def next.num(pk: Peek) -> Nat:
  match pk:
    case PNone{}:
      0n
    case PLine{num, depth, content}:
      num

# S4.206 strict: the first field of a nested object sits exactly one level below the base (S9.154);
# lenient: its depth fixes the depth of the fields, however deep
def eat.kv.jump(jump: Bool, +dd: Nat, +base: Nat, num: Nat, frames: List<&2, Frame>, pk: Peek, g: G) -> Step:
  match jump:
    case True{}:
      SErr{"Validation error at line " ++ Nat.show(num) ++ ": Indentation depth jump: expected depth " ++ Nat.show(1n+base) ++ ", but found " ++ Nat.show(dd)}
    case False{}:
      decide(FObj{J.JNil{}, T.kt.empty(), HNil{}, 1n+base, dd, False{}, SNil{}, False{}} <> frames, pk, g)

# S4.205 (b) an empty value is a nested object when the next line is deeper than the base, else the
# empty object
def eat.kv.nest(dd: Nat, +base: Nat, num: Nat, frames: List<&2, Frame>, pk: Peek, +g: G) -> Step:
  match dd:
    case 0n:
      attach(J.JObj{J.JNil{}}, frames, pk, g)
    case 1n++p:
      eat.kv.jump(Bool.and(g.strict(g), Nat.is_gt(1n+p, 1n+base)), 1n+p, base, num, frames, pk, g)

# S4.230 the object is one more container
def eat.kv.obj(over: Bool, +base: Nat, +pk: Peek, frames: List<&2, Frame>, +g: G) -> Step:
  match over:
    case True{}:
      SErr{nest.msg(g.last(g))}
    case False{}:
      eat.kv.nest(deeper(pk, base), base, next.num(pk), frames, pk, g)

# S4.205 (b) a non-empty value text is a primitive (never split on delimiters); an empty one is an
# object
def eat.kv.val(empty: Bool, base: Nat, pk: Peek, val: String, +frames: List<&2, Frame>, +g: G) -> Step:
  match empty:
    case False{}:
      eat.prim(prim(val, g.spec(g)), frames, pk, g)
    case True{}:
      eat.kv.obj(nest.over(frames, 1n), base, pk, frames, g)

# S4.205 (b) the key token; the object that receives the field remembers the key while the value is read
def eat.kv.plain(k: KV, pk: Peek, rev: J.Json, kt: T.KT, km: HM, b: Nat, d: Nat, base: Nat, item: Bool, more: List<&2, Frame>, g: G) -> Step:
  match k:
    case KVErr{msg}:
      SErr{msg}
    case KVOk{key, quoted, +val}:
      eat.kv.val(String.is_empty(val), base, pk, val, FObj{rev, kt, km, b, d, item, key, quoted} <> more, g)

# S4.205 a key-value content at base depth `base` (its own depth, S4.206), given the header parse of
# the content: header failures surface first; (a) a header WITH a key is a keyed array; (b) anything
# else is read as key and value. rev, kt, b, d, item describe the object that receives the field.
def eat.kv(h: Hdr, content: String, pk: Peek, rev: J.Json, kt: T.KT, km: HM, b: Nat, d: Nat, base: Nat, item: Bool, more: List<&2, Frame>, g: G) -> Step:
  match h:
    case HErr{msg}:
      SErr{msg}
    case HOk{True{}, key, quoted, n, delim, has_seg, +fields, +inline_text}:
      array(Bool.not(String.is_empty(inline_text)), Bool.not(List.is_empty(&2, Field, fields)), n, delim, fields, inline_text, base, FObj{rev, kt, km, b, d, item, key, quoted} <> more, pk, g)
    case other:
      eat.kv.plain(kv(content), pk, rev, kt, km, b, d, base, item, more, g)

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

# S3.26 a row whose field names repeat, after its repeated keys were merged
def row.merged(m: MR, rev: J.Json, n: Nat, cnt: Nat, r: Nat, fields: List<&2, Field>, nf: Nat, delim: U32, first: Nat, more: List<&2, Frame>, pk: Peek, g: G) -> Step:
  match m:
    case MR{entries, err}:
      decide(FTab{J.JCons{J.JObj{entries}, rev}, n, 1n+cnt, r, fields, nf, delim, first, True{}} <> more, pk, g.dup(g, err))

# S4.212, S3.26 the row object (entries in header order); with repeated field names its repeated keys
# are merged like any object's
def row.obj(dupf: Bool, +entries: J.Json, rev: J.Json, n: Nat, cnt: Nat, r: Nat, fields: List<&2, Field>, nf: Nat, delim: U32, first: Nat, more: List<&2, Frame>, pk: Peek, +g: G) -> Step:
  match dupf:
    case False{}:
      decide(FTab{J.JCons{J.JObj{entries}, rev}, n, 1n+cnt, r, fields, nf, delim, first, False{}} <> more, pk, g)
    case True{}:
      row.merged(dups(entries, J.JNil{}, g.strict(g)), rev, n, cnt, r, fields, nf, delim, first, more, pk, g)

# S4.212 the row's values as primitives (surplus ones too: their failures surface), then the object
def row.fin(pr: PR, num: Nat, rev: J.Json, n: Nat, cnt: Nat, r: Nat, +fields: List<&2, Field>, nf: Nat, delim: U32, first: Nat, dupf: Bool, more: List<&2, Frame>, pk: Peek, g: G) -> Step:
  match pr:
    case PRErr{msg}:
      SErr{msg}
    case PROk{prev, pc}:
      row.obj(dupf, J.rev_entries(row.zip(fields, J.rev_items(prev, J.JNil{}), J.JNil{}), J.JNil{}), rev, n, cnt, r, fields, nf, delim, first, more, pk, g)

# S4.212, S9.144 strict: the width is checked BEFORE the values are turned into primitives (S9.109)
def row.width(bad: Bool, +vals: List<&2, String>, num: Nat, rev: J.Json, n: Nat, cnt: Nat, r: Nat, fields: List<&2, Field>, +nf: Nat, delim: U32, first: Nat, dupf: Bool, more: List<&2, Frame>, pk: Peek, +g: G) -> Step:
  match bad:
    case True{}:
      SErr{"Expected " ++ Nat.show(nf) ++ " tabular row values, but got " ++ Nat.show(T.llen(&2, String, vals, 0n))}
    case False{}:
      row.fin(prims.go(vals, PROk{J.JNil{}, 0n}, g.spec(g)), num, rev, n, cnt, r, fields, nf, delim, first, dupf, more, pk, g)

# S4.212 one row: the line split with the header's delimiter
def eat.row(+vals: List<&2, String>, num: Nat, rev: J.Json, n: Nat, cnt: Nat, r: Nat, fields: List<&2, Field>, +nf: Nat, delim: U32, first: Nat, dupf: Bool, more: List<&2, Frame>, pk: Peek, g: G) -> Step:
  match g:
    case G{+strict, blanks, last, spec, dup}:
      row.width(Bool.and(strict, Nat.is_ne(T.llen(&2, String, vals, 0n), nf)), vals, num, rev, n, cnt, r, fields, nf, delim, first, dupf, more, pk, G{strict, blanks, last, spec, dup})

# S4.221 the text after the two-character marker `- ` (nothing for the bare marker `-`), not trimmed
def item.rest(content: String) -> String:
  match content:
    case SCon{a, SCon{b, rest}}:
      rest
    case other:
      SNil{}

# S4.221, S4.230 an empty item object is one more container
def item.empty(over: Bool, lst: Frame, more: List<&2, Frame>, pk: Peek, +g: G) -> Step:
  match over:
    case True{}:
      SErr{nest.msg(g.last(g))}
    case False{}:
      attach(J.JObj{J.JNil{}}, lst <> more, pk, g)

# S4.224, S4.230 an item object whose first field is on the hyphen line is one more container
def item.kv(over: Bool, h: Hdr, r: String, +t: Nat, lst: Frame, more: List<&2, Frame>, pk: Peek, +g: G) -> Step:
  match over:
    case True{}:
      SErr{nest.msg(g.last(g))}
    case False{}:
      eat.kv(h, r, pk, J.JNil{}, T.kt.empty(), HNil{}, 1n+t, 1n+t, 1n+t, True{}, lst <> more, g)

# S4.220–S4.226 one list item with rest R, given R's header parse (failures surface, whatever R looks
# like), whether R starts with '[' after leading White_Space, and whether R has a ':' outside quotes.
# In order: an empty or White_Space-only rest is the empty object; a keyless header behind a '[' with
# an unquoted ':' is a nested array at base depth t; a header with a key AND a fields segment opens an
# item object whose first field is that array at base depth t + 1; a ':' outside quotes makes R the
# first key-value line of an item object at base depth t + 1; anything else is a primitive.
def item.route(blank: Bool, h: Hdr, br: Bool, colon: Bool, r: String, +lst: Frame, +more: List<&2, Frame>, +t: Nat, pk: Peek, +g: G) -> Step:
  match blank h br colon:
    case True{} _ _ _:
      item.empty(nest.over(lst <> more, 1n), lst, more, pk, g)
    case False{} HErr{msg} _ _:
      SErr{msg}
    case False{} HOk{hk, key, quoted, n, delim, has_seg, +fields, +inline_text} True{} True{}:
      array(Bool.not(String.is_empty(inline_text)), Bool.not(List.is_empty(&2, Field, fields)), n, delim, fields, inline_text, t, lst <> more, pk, g)
    case False{} HOk{True{}, key, quoted, n, delim, True{}, +fields, +inline_text} _ _:
      array(Bool.not(String.is_empty(inline_text)), Bool.not(List.is_empty(&2, Field, fields)), n, delim, fields, inline_text, 1n+t, FObj{J.JNil{}, T.kt.empty(), HNil{}, 1n+t, 1n+t, True{}, key, quoted} <> lst <> more, pk, g)
    case False{} h0 _ True{}:
      item.kv(nest.over(lst <> more, 1n), h0, r, t, lst, more, pk, g)
    case False{} h0 _ False{}:
      eat.prim(prim(r, g.spec(g)), lst <> more, pk, g)

# S4.220–S4.226 one list item
def eat.item(+r: String, lst: Frame, more: List<&2, Frame>, t: Nat, pk: Peek, g: G) -> Step:
  item.route(T.is_blank(r), header(r), T.head_is(T.trim_start(r), 91), has_colon(r), r, lst, more, t, pk, g)

# S4.207 offer a line to the innermost construct (the line is known to fit it); S4.206 a field's own
# depth is its base depth (the field depth, or in lenient mode a deeper line's own depth)
def eat(l: Line, pk: Peek, frames: List<&2, Frame>, g: G) -> Step:
  match l frames g:
    case Line{num, depth, content} Nil{} g0:
      SErr{"internal: a line with nothing open"}
    case Line{+num, depth, +content} Con{FObj{rev, kt, km, b, d, item, key, q}, more} G{strict, +blanks, last, spec, dup}:
      eat.kv(header(content), content, pk, rev, kt, km, b, d, depth, item, more, G{strict, blank.drop(blanks, blank.lt(blanks, num), num), num, spec, dup})
    case Line{+num, depth, content} Con{FTab{rev, n, cnt, r, fields, nf, +delim, first, dupf}, more} G{strict, +blanks, last, spec, dup}:
      +pb = blank.drop(blanks, blank.lt(blanks, num), num)
      eat.row(split(content, delim), num, rev, n, cnt, r, fields, nf, delim, blank.start(first, pb), dupf, more, pk, G{strict, pb, num, spec, dup})
    case Line{+num, depth, content} Con{FList{rev, n, cnt, +t, first}, more} G{strict, +blanks, last, spec, dup}:
      +pb = blank.drop(blanks, blank.lt(blanks, num), num)
      eat.item(item.rest(content), FList{rev, n, cnt, t, blank.start(first, pb)}, more, t, pk, G{strict, pb, num, spec, dup})

# S4.200 (4) the outcome of decoding
type DR is Data:
  DOk{v: J.Json}
  DErr{msg: String}

# S4.202 the root value: a line after a complete root array is S9.152 in strict mode (lenient mode
# ignores it); then a repeated-key failure noted during the pass (S3.26)
def run.done(strict: Bool, left: List<&2, Line>, v: J.Json, dup: Maybe<&2, String>) -> DR:
  match strict left dup:
    case True{} Con{Line{num, depth, content}, rest} _:
      DErr{"Validation error at line " ++ Nat.show(num) ++ ": Unexpected content after the document root"}
    case _ _ Some{m}:
      DErr{m}
    case _ _ None{}:
      DOk{v}

# S4.200 (4) the pass. A step that consumes a line may open at most three constructs, so the bound
# grows by three; a step that closes a construct spends one. The first failure, or the root value, ends
# the pass.
def run(lines: List<&2, Line>, bound: Nat, st: Step, +strict: Bool) -> DR:
  match lines bound st:
    case ls b SErr{msg}:
      DErr{msg}
    case ls b SDone{v, dup}:
      run.done(strict, ls, v, dup)
    case Con{l, +rest} b SEat{frames, g}:
      run(rest, Nat.add(b, 3n), eat(l, peek(rest), frames, g), strict)
    case Nil{} b SEat{frames, g}:
      DErr{"internal: a line was expected"}
    case +ls 1n+b SPop{frames, g}:
      run(ls, b, pop(frames, peek(ls), g), strict)
    case ls 0n SPop{frames, g}:
      DErr{"internal: construct bound"}

# S4.203 whether the only line of a document is a key-value line: it has a ':' outside quotes, the
# same rule as for a list item (S4.224)
def root.is_kv(content: String) -> Bool:
  has_colon(content)

# S4.203 the root primitive
def root.prim(r: RV) -> DR:
  match r:
    case RVOk{v}:
      DOk{v}
    case RVErr{msg}:
      DErr{msg}

# S4.203 exactly ONE non-blank line that is not key-value by the root rule is the root primitive;
# S4.204 every other document is a root object: its first line is a field at base depth 0 whatever
# its own depth; every later line belongs to it (depth 0, or deeper lines per S4.206)
def root.object(single: Bool, is_kv: Bool, line: Line, +rest: List<&2, Line>, +strict: Bool, +blanks: List<&2, Nat>, spec: Bool) -> DR:
  match single is_kv line:
    case True{} False{} Line{num, depth, content}:
      root.prim(prim(content, spec))
    case _ _ Line{+num, depth, +content}:
      run(rest, 8n, eat.kv(header(content), content, peek(rest), J.JNil{}, T.kt.empty(), HNil{}, 0n, 0n, 0n, False{}, Nil{}, G{strict, blank.drop(blanks, blank.lt(blanks, num), num), num, spec, None{}}), strict)

# S4.202 the root-array test, third part: the first line parses as a header (failures surface): the
# array is decoded at base depth 0 whatever the line's own depth. A content that is not a header falls
# through to S4.203 / S4.204.
def root.array(h: Hdr, +num: Nat, depth: Nat, +content: String, +rest: List<&2, Line>, +strict: Bool, blanks: List<&2, Nat>, spec: Bool) -> DR:
  match h:
    case HErr{msg}:
      DErr{msg}
    case HOk{hk, key, quoted, n, delim, has_seg, +fields, +inline_text}:
      run(rest, 8n, array(Bool.not(String.is_empty(inline_text)), Bool.not(List.is_empty(&2, Field, fields)), n, delim, fields, inline_text, 0n, Nil{}, peek(rest), G{strict, blanks, num, spec, None{}}), strict)
    case HNot{}:
      root.object(List.is_empty(&2, Line, rest), root.is_kv(content), Line{num, depth, content}, rest, strict, blanks, spec)

# S4.202 the root-array test, first two parts: after leading White_Space the content starts with '['
# and it has a ':' outside quotes
def root.first(arr: Bool, +num: Nat, depth: Nat, +content: String, +rest: List<&2, Line>, strict: Bool, blanks: List<&2, Nat>, spec: Bool) -> DR:
  match arr:
    case True{}:
      root.array(header(content), num, depth, content, rest, strict, blanks, spec)
    case False{}:
      root.object(List.is_empty(&2, Line, rest), root.is_kv(content), Line{num, depth, content}, rest, strict, blanks, spec)

# S4.201 no non-blank line is the empty object; otherwise the FIRST non-blank line selects the root form
def root(lines: List<&2, Line>, strict: Bool, blanks: List<&2, Nat>, spec: Bool) -> DR:
  match lines:
    case Nil{}:
      DOk{J.JObj{J.JNil{}}}
    case Con{Line{num, depth, +content}, rest}:
      root.first(Bool.and(T.head_is(T.trim_start(content), 91), has_colon(content)), num, depth, content, rest, strict, blanks, spec)

# S4.200 (3), (4) scan everything first (S2.111), then one structural pass
def decode.scanned(s: Scan, +strict: Bool, spec: Bool) -> DR:
  match s:
    case ScanErr{msg}:
      DErr{msg}
    case ScanOk{lines, blanks}:
      root(lines, strict, blanks, spec)

# S4.200 the value of a TOON text with indent size `unit` (no path expansion)
def decode(text: String, +strict: Bool, unit: Nat, spec: Bool) -> DR:
  decode.scanned(scan(text, strict, unit), strict, spec)

# ---------------------------------------------------------------- S4.240–S4.249 safe path expansion
#
# An object under construction is an XObj: its keys in insertion order beside a map from key to value
# (S6.42, S6.43). The depth counter c of S4.248 is carried as `left` = 256 - c: a step may run only
# while left >= 1.

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

# S6.42 an object under construction, and the map it keeps. ONE self-recursive type (Bend has no
# mutually recursive types): XLeaf a finished value; XObj an object being built: its keys newest first
# (the ORDER carrier, S6.42) beside a map from key to value (the LOOKUP carrier: the original uses a
# hash map; a search along the entries made expansion quadratic in round 6's probes); XTLeaf / XTNode
# the map, a binary trie over the low 16 bits of T.key_hash; XBNil / XBNode a trie leaf's bucket, an AA
# tree by key (T.KS with a value per key): keys that collide in the hash cost a logarithm of their number.
type XV is Data:
  XLeaf{v: J.Json}
  XObj{keys: List<&2, String>, map: XV}
  XTLeaf{bucket: XV}
  XTNode{zero: XV, one: XV}
  XBNil{}
  XBNode{lv: Nat, l: XV, key: String, val: XV, r: XV}

# S4.242 the new object starts empty
def xv.empty() -> XV:
  XObj{Nil{}, XTLeaf{XBNil{}}}

# S6.42 an object under construction, or the message of the first failure
type XR is Data:
  XOk{x: XV}
  XErr{msg: String}

# S6.43 skew, decided: a left child on its parent's level becomes the parent
def xb.skew.pick(same: Bool, lv: Nat, llv: Nat, a: XV, lk: String, lval: XV, b: XV, x: String, xv: XV, r: XV) -> XV:
  match same:
    case True{}:
      XBNode{llv, a, lk, lval, XBNode{lv, b, x, xv, r}}
    case False{}:
      XBNode{lv, XBNode{llv, a, lk, lval, b}, x, xv, r}

# S6.43 skew: remove a left horizontal link by a right rotation
def xb.skew(t: XV) -> XV:
  match t:
    case XBNode{+lv, XBNode{+llv, a, lk, lval, b}, x, xv, r}:
      xb.skew.pick(Nat.is_eq(llv, lv), lv, llv, a, lk, lval, b, x, xv, r)
    case other:
      other

# S6.43 the level of a bucket's root (0 for the empty bucket)
def xb.level(t: XV) -> Nat:
  match t:
    case XBNode{lv, l, x, xv, r}:
      lv
    case other:
      0n

# S6.43 split, decided: the middle of three nodes on one level is lifted a level
def xb.split.pick(same: Bool, lv: Nat, a: XV, x: String, xv: XV, rlv: Nat, b: XV, rk: String, rval: XV, rr: XV) -> XV:
  match same:
    case True{}:
      XBNode{1n+rlv, XBNode{lv, a, x, xv, b}, rk, rval, rr}
    case False{}:
      XBNode{lv, a, x, xv, XBNode{rlv, b, rk, rval, rr}}

# S6.43 split: remove two right horizontal links in a row by a left rotation
def xb.split(t: XV) -> XV:
  match t:
    case XBNode{+lv, a, x, xv, XBNode{rlv, b, rk, rval, +rr}}:
      xb.split.pick(Nat.is_eq(xb.level(rr), lv), lv, a, x, xv, rlv, b, rk, rval, rr)
    case other:
      other

# S6.43 a key against the key at the root (the verdict is not read on the empty bucket)
def xb.root(t: XV, k: String) -> T.Ord:
  match t:
    case XBNode{lv, l, x, xv, r}:
      T.str_cmp(k, x)
    case other:
      T.OEq{}

# S6.43 the value a bucket holds under a key: c is the key against this root (the caller of each step
# looks at the child's root, so the descent is one structural recursion)
def xb.get.go(t: XV, +k: String, c: T.Ord) -> Maybe<&2, XV>:
  match t c:
    case XBNode{lv, +l, x, xv, r} T.OLt{}:
      xb.get.go(l, k, xb.root(l, k))
    case XBNode{lv, l, x, xv, +r} T.OGt{}:
      xb.get.go(r, k, xb.root(r, k))
    case XBNode{lv, l, x, xv, r} T.OEq{}:
      Some{xv}
    case other _:
      None{}

# S6.43 the value a bucket holds under a key
def xb.get(+t: XV, +k: String) -> Maybe<&2, XV>:
  xb.get.go(t, k, xb.root(t, k))

# S6.43 set a key in a bucket: rebalanced on the way back up (skew, then split); a key already there
# takes the new value
def xb.set.go(t: XV, +k: String, v: XV, c: T.Ord) -> XV:
  match t c:
    case XBNode{lv, +l, x, xv, r} T.OLt{}:
      xb.split(xb.skew(XBNode{lv, xb.set.go(l, k, v, xb.root(l, k)), x, xv, r}))
    case XBNode{lv, l, x, xv, +r} T.OGt{}:
      xb.split(xb.skew(XBNode{lv, l, x, xv, xb.set.go(r, k, v, xb.root(r, k))}))
    case XBNode{lv, l, x, xv, r} T.OEq{}:
      XBNode{lv, l, x, v, r}
    case other _:
      XBNode{1n, XBNil{}, k, v, XBNil{}}

# S6.43 set a key in a bucket
def xb.set(+t: XV, +k: String, v: XV) -> XV:
  xb.set.go(t, k, v, xb.root(t, k))

# S6.43 the value the map holds under a key: d counts the hash bits still to follow
def xm.get.go(d: Nat, odd: Bool, t: XV, +h: U32, +k: String) -> Maybe<&2, XV>:
  match d odd t:
    case 0n _ XTLeaf{b}:
      xb.get(b, k)
    case 1n+p False{} XTNode{z, o}:
      xm.get.go(p, T.kt.odd((h >> 1n : U32)), z, (h >> 1n : U32), k)
    case 1n+p True{} XTNode{z, o}:
      xm.get.go(p, T.kt.odd((h >> 1n : U32)), o, (h >> 1n : U32), k)
    case _ _ other:
      None{}

# S6.43 look a key up in a map
def xm.get.at(t: XV, +h: U32, +k: String) -> Maybe<&2, XV>:
  xm.get.go(16n, T.kt.odd(h), t, h, k)

# S6.43 look a key up in a map
def xm.get(t: XV, +k: String) -> Maybe<&2, XV>:
  xm.get.at(t, T.key_hash(k), k)

# S6.43 set a key in a map: a leaf above depth 0 is an empty region and is split on the way down
def xm.set.go(d: Nat, odd: Bool, t: XV, +h: U32, +k: String, v: XV) -> XV:
  match d odd t:
    case 0n _ XTLeaf{b}:
      XTLeaf{xb.set(b, k, v)}
    case 1n+p False{} XTLeaf{b}:
      XTNode{xm.set.go(p, T.kt.odd((h >> 1n : U32)), XTLeaf{XBNil{}}, (h >> 1n : U32), k, v), XTLeaf{b}}
    case 1n+p True{} XTLeaf{b}:
      XTNode{XTLeaf{b}, xm.set.go(p, T.kt.odd((h >> 1n : U32)), XTLeaf{XBNil{}}, (h >> 1n : U32), k, v)}
    case 1n+p False{} XTNode{z, o}:
      XTNode{xm.set.go(p, T.kt.odd((h >> 1n : U32)), z, (h >> 1n : U32), k, v), o}
    case 1n+p True{} XTNode{z, o}:
      XTNode{z, xm.set.go(p, T.kt.odd((h >> 1n : U32)), o, (h >> 1n : U32), k, v)}
    case _ _ other:
      other

# S6.43 set a key in a map
def xm.set.at(t: XV, +h: U32, +k: String, v: XV) -> XV:
  xm.set.go(16n, T.kt.odd(h), t, h, k, v)

# S6.43 set a key in a map
def xm.set(t: XV, +k: String, v: XV) -> XV:
  xm.set.at(t, T.key_hash(k), k, v)

# S6.42 set a key of an object under construction: a fresh key is appended to the order, an existing
# one keeps the position of its first insertion
def xo.set(obj: XV, +k: String, fresh: Bool, v: XV) -> XV:
  match obj fresh:
    case XObj{keys, map} True{}:
      XObj{k <> keys, xm.set(map, k, v)}
    case XObj{keys, map} False{}:
      XObj{keys, xm.set(map, k, v)}
    case other _:
      other

# S4.245 a finished object (its keys are unique, S3.28) opened for merging
def xv.open(c: J.Json, keys: List<&2, String>, map: XV) -> XV:
  match c:
    case J.JECons{+k, q, v, t}:
      xv.open(t, k <> keys, xm.set(map, k, XLeaf{v}))
    case other:
      XObj{keys, map}

# S4.243, S4.244 what an object under construction holds under a key: nothing, an object (opened), or
# something else (its type name)
type LK is Data:
  LNone{}
  LObj{x: XV}
  LOther{ty: String}

# S4.244 classify a held value
def lk.of(x: XV) -> LK:
  match x:
    case XObj{keys, map}:
      LObj{XObj{keys, map}}
    case XLeaf{J.JObj{entries}}:
      LObj{xv.open(entries, Nil{}, XTLeaf{XBNil{}})}
    case XLeaf{J.JArr{n, items}}:
      LOther{"array"}
    case XLeaf{other}:
      LOther{"primitive"}
    case other:
      LNone{}

# S4.244 from the map's answer
def lk.found(m: Maybe<&2, XV>) -> LK:
  match m:
    case None{}:
      LNone{}
    case Some{x}:
      lk.of(x)

# S4.244 look a key up in an object under construction
def lk(obj: XV, k: String) -> LK:
  match obj:
    case XObj{keys, map}:
      lk.found(xm.get(map, k))
    case other:
      LNone{}

# S4.244 what to do with the first entry of a source chain against a target under construction: nothing
# (no entry left, or the target already failed), the cap, place the value (fresh: the key is new),
# a conflict, or a deep merge into the existing object
type Act is Data:
  ANone{}
  ACap{}
  APut{fresh: Bool}
  AConf{msg: String}
  AMerge{ex: XV}

# S9.116 strict: a conflict names the key, the type of the EXISTING value, then the type of the new
# one; lenient: the new value overwrites in place
def plan.conf(strict: Bool, k: String, x: String, y: String) -> Act:
  match strict:
    case True{}:
      AConf{T.cat(["Path expansion conflict at key \"", k, "\": cannot merge ", x, " with ", y])}
    case False{}:
      APut{False{}}

# S4.244 no entry: append; two objects: deep merge; anything else: conflict or overwrite
def plan.head(l: LK, v: J.Json, strict: Bool, k: String) -> Act:
  match l v:
    case LNone{} _:
      APut{True{}}
    case LObj{ex} J.JObj{ve}:
      AMerge{ex}
    case LObj{ex} other:
      plan.conf(strict, k, "object", ty(other))
    case LOther{t} nv:
      plan.conf(strict, k, t, ty(nv))

# S4.248 a merge or a literal insertion may not run with c >= 256; a target that already failed, or a
# source with nothing left, plans nothing
def plan(left: Nat, tgt: XR, src: J.Json, strict: Bool) -> Act:
  match left tgt src:
    case 0n _ _:
      ACap{}
    case 1n+p XErr{m} _:
      ANone{}
    case 1n+p XOk{obj} J.JECons{+k, q, v, t}:
      plan.head(lk(obj, k), v, strict, k)
    case 1n+p XOk{obj} other:
      ANone{}

# S4.244 place a value
def merge.put(obj: XV, k: String, fresh: Bool, v: J.Json) -> XR:
  XOk{xo.set(obj, k, fresh, XLeaf{v})}

# S4.245 place the result of a nested merge; the key keeps its position
def merge.sub(obj: XV, k: String, sub: XR) -> XR:
  match sub:
    case XErr{m}:
      XErr{m}
    case XOk{sx}:
      XOk{xo.set(obj, k, False{}, sx)}

# S4.244, S4.245 insert the entries of a source chain, in order, into a target under construction, at
# counter 256 - left; `act` is the plan for the FIRST entry of `src` (computed by the caller). A nested
# merge runs one counter higher. ONE def: the recursion is on the source, whose nested objects are its
# own subterms.
def merge(src: J.Json, act: Act, tgt: XR, +strict: Bool, +left: Nat) -> XR:
  match src act tgt:
    case s ACap{} t:
      XErr{cap_msg()}
    case s AConf{msg} t:
      XErr{msg}
    case s ANone{} t:
      t
    case J.JECons{k, q, v, +rest} APut{fresh} XOk{obj}:
      +t2 = merge.put(obj, k, fresh, v)
      merge(rest, plan(left, t2, rest, strict), t2, strict, left)
    case J.JECons{k, q, J.JObj{+ve}, +rest} AMerge{+ex} XOk{obj}:
      +t2 = merge.sub(obj, k, merge(ve, plan(Nat.sub(left, 1n), XOk{ex}, ve, strict), XOk{ex}, strict, Nat.sub(left, 1n)))
      merge(rest, plan(left, t2, rest, strict), t2, strict, left)
    case s a t:
      t

# S4.245 merge a whole source chain into a target under construction at counter 256 - left
def merge.all(+src: J.Json, +obj: XV, +strict: Bool, +left: Nat) -> XR:
  merge(src, plan(left, XOk{obj}, src, strict), XOk{obj}, strict, left)

# S4.244 the literal insertion of (k, v) at counter 256 - left: a merge of the one-entry source
def lit.ins(obj: XV, k: String, v: J.Json, strict: Bool, left: Nat) -> XR:
  merge.all(J.JECons{k, False{}, v, J.JNil{}}, obj, strict, left)

# S4.243 what the object under construction holds under the FIRST of the remaining segments
def lk.head(segs: List<&2, String>, obj: XV) -> LK:
  match segs:
    case Nil{}:
      LNone{}
    case Con{s, more}:
      lk(obj, s)

# S4.243 the object reached through a segment goes back under that segment
def path.put(obj: XV, s: String, fresh: Bool, sub: XR) -> XR:
  match sub:
    case XErr{m}:
      XErr{m}
    case XOk{sx}:
      XOk{xo.set(obj, s, fresh, sx)}

# S4.243 insert a path into an object under construction. Each call is one step of the walk, at
# counter 256 - left; `look` is what the object holds under the first remaining segment. An object is
# entered; nothing there becomes a new empty object at the END of the order; (lenient) something that is
# not an object becomes an empty object AT ITS POSITION; strict: S9.117. The last segment is a literal
# insertion one counter higher.
def path.ins(segs: List<&2, String>, look: LK, left: Nat, strict: Bool, obj: XV, v: J.Json) -> XR:
  match segs look left strict:
    case _ _ 0n _:
      XErr{cap_msg()}
    case Nil{} _ 1n+p _:
      XOk{obj}
    case Con{s, Nil{}} _ 1n+p +st:
      lit.ins(obj, s, v, st, p)
    case Con{s, +more} LObj{+ex} 1n+p +st:
      path.put(obj, s, False{}, path.ins(more, lk.head(more, ex), p, st, ex, v))
    case Con{s, more} LOther{t} 1n+p True{}:
      XErr{T.cat(["Path expansion conflict at segment \"", s, "\": expected object but found ", t])}
    case Con{s, +more} LOther{t} 1n+p False{}:
      path.put(obj, s, False{}, path.ins(more, LNone{}, p, False{}, xv.empty(), v))
    case Con{s, +more} LNone{} 1n+p +st:
      path.put(obj, s, True{}, path.ins(more, LNone{}, p, st, xv.empty(), v))

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

# S3.25 one entry's contribution to the quoted-key set
def qset.add(q: Bool, k: String, acc: T.KT) -> T.KT:
  match q:
    case True{}:
      T.kt.put(acc, k)
    case False{}:
      acc

# S3.25, S3.26 the quoted-key set of an object: the key STRINGS that occur quoted at least once in it
# (S6.43: only membership is ever asked)
def qset(c: J.Json, acc: T.KT) -> T.KT:
  match c:
    case J.JECons{k, q, v, t}:
      qset(t, qset.add(q, k, acc))
    case other:
      acc

# S4.243 the walk starts at the object itself
def field.path(+segs: List<&2, String>, +obj: XV, v: J.Json, strict: Bool, left: Nat) -> XR:
  path.ins(segs, lk.head(segs, obj), left, strict, obj, v)

# S4.242 a key that is a path (S4.241: it has a dot, its string is not in the quoted-key set, every
# piece is an identifier segment) is inserted by S4.243; any other key literally, by S4.244. Both run
# at the counter of the object's entry values (S4.248: c + 2).
def field.key(path: Bool, obj: XV, +k: String, v: J.Json, strict: Bool, left: Nat) -> XR:
  match path:
    case False{}:
      lit.ins(obj, k, v, strict, left)
    case True{}:
      field.path(dots(k), obj, v, strict, left)

# S4.242 FIRST the entry's value is expanded, THEN its key is inserted: a failure among the earlier
# entries wins, then a failure inside the value, then the insertion's own
def field.ins(acc: XR, +k: String, qs: T.KT, v: ER, strict: Bool, left: Nat) -> XR:
  match acc v:
    case XErr{m} _:
      XErr{m}
    case XOk{obj} EErr{m}:
      XErr{m}
    case XOk{obj} EOk{nv}:
      field.key(Bool.and(T.has_char(k, 46), Bool.and(Bool.not(T.kt.has(qs, k)), idents.go(dots(k), True{}))), obj, k, nv, strict, left)

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

# S3.28 the value a finished map holds under a key of its own order list
def x.value(m: Maybe<&2, XV>) -> J.Json:
  match m:
    case Some{XLeaf{v}}:
      v
    case other:
      J.JNull{}

# S6.42 the entries of a finished object: the keys come newest first, so consing them gives the order
# of first insertion
def x.entries(keys: List<&2, String>, +map: XV, acc: J.Json) -> J.Json:
  match keys:
    case Nil{}:
      acc
    case Con{+k, rest}:
      x.entries(rest, map, J.JECons{k, False{}, x.value(xm.get(map, k)), acc})

# S3.28 finish an object under construction: every object inside it first (structural recursion over
# the ONE type: the map's nodes, its buckets, the values), then its own entries in order
def x.norm(x: XV) -> XV:
  match x:
    case XLeaf{v}:
      XLeaf{v}
    case XObj{keys, map}:
      XLeaf{J.JObj{x.entries(keys, x.norm(map), J.JNil{})}}
    case XTLeaf{b}:
      XTLeaf{x.norm(b)}
    case XTNode{z, o}:
      XTNode{x.norm(z), x.norm(o)}
    case XBNil{}:
      XBNil{}
    case XBNode{lv, l, k, val, r}:
      XBNode{lv, x.norm(l), k, x.norm(val), x.norm(r)}

# S3.28 the finished value
def x.json(x: XV) -> J.Json:
  match x:
    case XLeaf{v}:
      v
    case other:
      J.JNull{}

# S3.28 an expanded object: unique keys, in the order of S6.42
def obj.fin(r: XR) -> ER:
  match r:
    case XErr{m}:
      EErr{m}
    case XOk{x}:
      EOk{x.json(x.norm(x))}

# S4.240 how `expand` treats the node it is given. `left` = 256 - c for the value, the items or the
# entry values; qs is the object's quoted-key set; acc is the container under construction
type XC is Data:
  XVal{left: Nat}
  XItems{left: Nat, acc: ER}
  XFields{left: Nat, qs: T.KT, acc: XR}

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
      expand(entries, XFields{q, qset(entries, T.kt.empty()), XOk{xv.empty()}}, strict)
    case J.JCons{h, t} XItems{+p, acc}:
      expand(t, XItems{p, item.push(acc, expand(h, XVal{p}, strict))}, strict)
    case J.JECons{k, q, v, t} XFields{+p, +qs, acc}:
      expand(t, XFields{p, qs, field.ins(acc, k, qs, expand(v, XVal{p}, strict), strict, p)}, strict)
    case other XItems{p, acc}:
      acc
    case other XFields{p, qs, acc}:
      obj.fin(acc)
    case v XVal{1n+p}:
      EOk{v}

# S4.231 the larger of `best` and the nesting depth of a value (its objects and arrays, the outermost
# included; 0 for a primitive); over a chain, of its values. Siblings are a tail call; only nesting
# recurses.
def depth.of(j: J.Json, +best: Nat) -> Nat:
  match j:
    case J.JArr{n, items}:
      Nat.max(best, 1n + depth.of(items, 0n))
    case J.JObj{entries}:
      Nat.max(best, 1n + depth.of(entries, 0n))
    case J.JCons{h, t}:
      depth.of(t, depth.of(h, best))
    case J.JECons{k, q, v, t}:
      depth.of(t, depth.of(v, best))
    case other:
      best

# S4.231 expansion nests one object per dotted segment, so its result may be deeper than the document;
# it is held to the decoder's limit of 127 (S9.155)
def decode.x.depth(over: Bool, v: J.Json) -> DR:
  match over:
    case True{}:
      DErr{"Nesting depth exceeds 127 levels after path expansion"}
    case False{}:
      DOk{v}

# S4.249 expansion starts only after a complete, failure-free decode
def decode.x.fin(r: ER) -> DR:
  match r:
    case EOk{+v}:
      decode.x.depth(Nat.is_gt(depth.of(v, 0n), 127n), v)
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
def decode_expanded(text: String, +strict: Bool, unit: Nat, spec: Bool) -> DR:
  decode.x(decode(text, strict, unit, spec), strict)

# S4.249 whether a decode outcome is a value (laws ask this of large results)
def dr.ok(r: DR) -> Bool:
  match r:
    case DOk{v}:
      True{}
    case DErr{m}:
      False{}
