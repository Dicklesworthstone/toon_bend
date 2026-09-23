# cli.bend — the pure model of the command line: argv to either a text-and-exit-code (help, version,
# every argv error) or the resolved options; the conversion of an input to the output text; the
# statistics and success lines. No IO here: the shell (main.bend) reads, writes and exits.
#
# Spec: docs/EXISTING_Toon_STRUCTURE.md S1.1–S1.155, S4.300–S4.319, S5.100–S5.113, S9.1–S9.11.
# Dispatch is on Nat codes, never on U32 literals (bend #867).

import Base
import ./text.bend as T
import ./bignat.bend as BN
import ./f64.bend as F
import ./json.bend as J
import ./encode.bend as E
import ./decode.bend as D

# ---------------------------------------------------------------- S1.3 the arguments
#
# An argument is a Nat id, in declaration order (S6.3): 0 INPUT, 1 output, 2 encode, 3 decode,
# 4 delimiter, 5 indent, 6 no-strict, 7 key-folding, 8 flatten-depth, 9 expand-paths, 10 stats,
# 11 help, 12 version.

# S1.75 the twelve long names in candidate order; the id of a name is its 1-based position
def names() -> List<&2, String>:
  ["output", "encode", "decode", "delimiter", "indent", "no-strict", "key-folding", "flatten-depth", "expand-paths", "stats", "help", "version"]

# S1.6 the loop of long_id: stops at the first exact, case-sensitive match
def long_id.go(ns: List<&2, String>, +name: String, i: Nat, hit: Bool) -> Nat:
  match ns hit:
    case _ True{}:
      i
    case Nil{} False{}:
      0n
    case Con{n, rest} False{}:
      long_id.go(rest, name, 1n+i, T.str_eq(n, name))

# S1.6 the id of a long name, or 0 when it is unknown
def long_id(name: String) -> Nat:
  long_id.go(names(), name, 0n, False{})

# S1.3 (table T2) the display form of an argument in messages and in context-built Usage lines
def disp(id: Nat) -> String:
  match id:
    case 0n:
      "[INPUT]"
    case 1n:
      "--output <FILE>"
    case 2n:
      "--encode"
    case 3n:
      "--decode"
    case 4n:
      "--delimiter <DELIMITER>"
    case 5n:
      "--indent <INDENT>"
    case 6n:
      "--no-strict"
    case 7n:
      "--key-folding <KEY_FOLDING>"
    case 8n:
      "--flatten-depth <N>"
    case 9n:
      "--expand-paths <EXPAND_PATHS>"
    case 10n:
      "--stats"
    case 11n:
      "--help"
    case _:
      "--version"

# S1.3 (table T1) whether an argument takes a value
def takes_value(id: Nat) -> Bool:
  match id:
    case 1n:
      True{}
    case 4n:
      True{}
    case 5n:
      True{}
    case 7n:
      True{}
    case 8n:
      True{}
    case 9n:
      True{}
    case _:
      False{}

# ---------------------------------------------------------------- S1.5–S1.10 argv words to tokens

# S1.5 what a word (or one piece of a short cluster) is: the escape; a long-option word split at its
# first '=' (S1.6); one character of a short cluster other than 'o' (S1.8); the 'o' of a cluster with
# what follows it (S1.8); a plain word, with whether the escape came before it (S1.10)
type Tok is Data:
  TEsc{}
  TLong{name: String, has_val: Bool, val: String}
  TShort{c: U32}
  TOut{has_val: Bool, val: String}
  TPlain{word: String, esc: Bool}
  TNeg{word: String, first: U32}

# S1.8 remove one leading '='
def tok.out.eq(eq: Bool, c: U32, more: String) -> String:
  match eq:
    case True{}:
      more
    case False{}:
      SCon{Chr{c}, more}

# S1.8 `o` ends the cluster: the rest, after ONE leading '=' when present, is its attached value when
# the rest is non-empty (`-o=` is an attached empty value); nothing after `o` means the option waits
def tok.out(rest: String) -> Tok:
  match rest:
    case SNil{}:
      TOut{False{}, SNil{}}
    case SCon{Chr{+c}, more}:
      TOut{True{}, tok.out.eq(U32.is_eq(c, 61), c, more)}

# S1.8 the characters of a cluster, left to right; `o` says whether the head of `s` is 'o'
def tok.cluster(s: String, o: Bool, acc: List<&2, Tok>) -> List<&2, Tok>:
  match s o:
    case SNil{} _:
      acc
    case SCon{c, rest} True{}:
      tok.out(rest) <> acc
    case SCon{Chr{c}, +rest} False{}:
      tok.cluster(rest, T.head_is(rest, 111), TShort{c} <> acc)

# S1.6 a long-option word is split at its FIRST '='
def tok.long(c: T.Cut) -> Tok:
  match c:
    case T.Cut{found, name, val}:
      TLong{name, found, val}

# S1.156 the class of the first character of a text: 0 an ASCII digit, 1 '.', 2 'e' or 'E', 3 any
# other character, 4 none
def num.cls(s: String) -> Nat:
  match s:
    case SNil{}:
      4n
    case SCon{Chr{+c}, rest}:
      Bool.pick(Nat, Bool.and(U32.is_ge(c, 48), U32.is_le(c, 57)), 0n, Bool.pick(Nat, U32.is_eq(c, 46), 1n, Bool.pick(Nat, Bool.or(U32.is_eq(c, 101), U32.is_eq(c, 69)), 2n, 3n)))

# S1.156 whether the text after a leading '-' is a number: ASCII digits, at most one '.' that is not
# the first character and comes before any exponent letter, at most one 'e' or 'E' that is not the
# first character and not the last. k is the class of the head of s; `at` whether a character was
# read; `dot`, `exp` whether a '.' or an exponent letter was read; `last_e` whether the character
# read last was the exponent letter.
def num.go(s: String, k: Nat, at: Bool, dot: Bool, +exp: Bool, last_e: Bool) -> Bool:
  match s k:
    case SNil{} _:
      Bool.not(last_e)
    case SCon{h, +rest} 0n:
      num.go(rest, num.cls(rest), True{}, dot, exp, False{})
    case SCon{h, +rest} 1n:
      Bool.and(Bool.and(at, Bool.not(Bool.or(dot, exp))), num.go(rest, num.cls(rest), True{}, True{}, exp, False{}))
    case SCon{h, +rest} 2n:
      Bool.and(Bool.and(at, Bool.not(exp)), num.go(rest, num.cls(rest), True{}, dot, True{}, True{}))
    case SCon{h, rest} _:
      False{}

# S1.156 a word '-' + number is kept whole (an option that allows negative numbers takes it as its
# value, S1.157); any other '-' word is a short cluster (S1.8)
def tok.neg(num: Bool, +c: U32, +m: String, acc: List<&2, Tok>) -> List<&2, Tok>:
  match num:
    case True{}:
      TNeg{SCon{Chr{45}, SCon{Chr{c}, m}}, c} <> acc
    case False{}:
      tok.cluster(SCon{Chr{c}, m}, U32.is_eq(c, 111), acc)

# S1.5 (a), (b) after `--`: nothing more is the escape; otherwise a long-option word. (c) a short cluster
def tok.dash2(dash: Bool, +c: U32, +more: String, acc: List<&2, Tok>) -> List<&2, Tok>:
  match dash more:
    case True{} SNil{}:
      TEsc{} <> acc
    case True{} SCon{h, t}:
      tok.long(T.cut(SCon{h, t}, 61)) <> acc
    case False{} m:
      tok.neg(num.go(SCon{Chr{c}, m}, num.cls(SCon{Chr{c}, m}), False{}, False{}, False{}, False{}), c, m, acc)

# S1.5 the class of a word that begins with '-': (a) exactly `--`; (b) `--` and more; (c) '-' and a
# second character that is not '-'; (d) the one-character word `-` is plain
def tok.dash(rest: String, acc: List<&2, Tok>) -> List<&2, Tok>:
  match rest:
    case SNil{}:
      TPlain{"-", False{}} <> acc
    case SCon{Chr{+c}, more}:
      tok.dash2(U32.is_eq(c, 45), c, more, acc)

# S1.5 (d) a word that does not begin with '-' is plain
def tok.word.first(dash: Bool, c: U32, rest: String, acc: List<&2, Tok>) -> List<&2, Tok>:
  match dash:
    case True{}:
      tok.dash(rest, acc)
    case False{}:
      TPlain{SCon{Chr{c}, rest}, False{}} <> acc

# S1.5 a word before any escape
def tok.word(w: String, acc: List<&2, Tok>) -> List<&2, Tok>:
  match w:
    case SNil{}:
      TPlain{SNil{}, False{}} <> acc
    case SCon{Chr{+c}, rest}:
      tok.word.first(U32.is_eq(c, 45), c, rest, acc)

# S1.10 tokenizer state: whether the escape was seen; the tokens so far, newest first
type TS is Data:
  TS{esc: Bool, acc: List<&2, Tok>}

# S1.10 the escape itself is consumed silently
def toks.step.esc(esc: Bool, w: String, acc: List<&2, Tok>) -> TS:
  match esc:
    case True{}:
      TS{True{}, TEsc{} <> acc}
    case False{}:
      TS{False{}, tok.word(w, acc)}

# S1.10 after the escape every word is a plain word
def toks.step(st: TS, +w: String) -> TS:
  match st:
    case TS{True{}, acc}:
      TS{True{}, TPlain{w, True{}} <> acc}
    case TS{False{}, acc}:
      toks.step.esc(T.str_eq("--", w), w, acc)

# S1.4 the words left to right (a loop over argv)
def toks.go(ws: List<&2, String>, st: TS) -> TS:
  match ws:
    case Nil{}:
      st
    case Con{w, rest}:
      toks.go(rest, toks.step(st, w))

# S1.5 the tokens of argv, in order
def toks.fin(st: TS) -> List<&2, Tok>:
  match st:
    case TS{esc, acc}:
      List.reverse(&2, Tok, acc)

# S1.5 argv (without argv[0]) as tokens
def toks(ws: List<&2, String>) -> List<&2, Tok>:
  toks.fin(toks.go(ws, TS{False{}, Nil{}}))

# ---------------------------------------------------------------- S1.74–S1.76 similarity (clap's Jaro)

# S1.74 a character of b and whether it has been matched
type BM is Data:
  BM{c: U32, m: Bool}

# S1.74 the characters of a text as an unmatched list
def jaro.bms(s: String, acc: List<&2, BM>) -> List<&2, BM>:
  match s:
    case SNil{}:
      List.reverse(&2, BM, acc)
    case SCon{Chr{c}, rest}:
      jaro.bms(rest, BM{c, False{}} <> acc)

# S1.74 search state for one character of a: whether it found its match; the position in b; b so far
# (newest first)
type JF is Data:
  JF{found: Bool, j: Nat, rev: List<&2, BM>}

# S1.74 a[i] takes the LEFTMOST not yet matched position j of b with |i - j| <= w and b[j] = a[i]
def jaro.try(take: Bool, found: Bool, +j: Nat, c: U32, m: Bool, rev: List<&2, BM>) -> JF:
  match take:
    case True{}:
      JF{True{}, 1n+j, BM{c, True{}} <> rev}
    case False{}:
      JF{found, 1n+j, BM{c, m} <> rev}

# S1.74 one position of b
def jaro.pos(st: JF, bm: BM, +ac: U32, +lo: Nat, +hi: Nat) -> JF:
  match st bm:
    case JF{+found, +j, rev} BM{+c, +m}:
      jaro.try(Bool.and(Bool.not(found), Bool.and(Bool.not(m), Bool.and(U32.is_eq(c, ac), Bool.and(Nat.is_ge(j, lo), Nat.is_le(j, hi))))), found, j, c, m, rev)

# S1.74 all positions of b for one character of a (a loop over b)
def jaro.scan(bs: List<&2, BM>, st: JF, +ac: U32, +lo: Nat, +hi: Nat) -> JF:
  match bs:
    case Nil{}:
      st
    case Con{bm, rest}:
      jaro.scan(rest, jaro.pos(st, bm, ac, lo, hi), ac, lo, hi)

# S1.74 state over a: the index i, b with its marks, the matched characters of a (newest first)
type JA is Data:
  JA{i: Nat, bs: List<&2, BM>, am: List<&2, U32>}

# S1.74 after one character of a was tried
def jaro.took(f: JF, +i: Nat, +ac: U32, am: List<&2, U32>) -> JA:
  match f:
    case JF{True{}, j, rev}:
      JA{1n+i, List.reverse(&2, BM, rev), ac <> am}
    case JF{False{}, j, rev}:
      JA{1n+i, List.reverse(&2, BM, rev), am}

# S1.74 one character of a: the window is i - w .. i + w
def jaro.step(st: JA, +ac: U32, +w: Nat) -> JA:
  match st:
    case JA{+i, bs, am}:
      jaro.took(jaro.scan(bs, JF{False{}, 0n, Nil{}}, ac, Nat.sub(i, w), Nat.add(i, w)), i, ac, am)

# S1.74 all characters of a (a loop over a)
def jaro.match(a: String, st: JA, +w: Nat) -> JA:
  match a:
    case SNil{}:
      st
    case SCon{Chr{c}, rest}:
      jaro.match(rest, jaro.step(st, c, w), w)

# S1.74 the matched characters of b, in b's order
def jaro.bmatched(bs: List<&2, BM>, acc: List<&2, U32>) -> List<&2, U32>:
  match bs:
    case Nil{}:
      List.reverse(&2, U32, acc)
    case Con{BM{c, True{}}, rest}:
      jaro.bmatched(rest, c <> acc)
    case Con{BM{c, False{}}, rest}:
      jaro.bmatched(rest, acc)

# S1.74 h: the ranks at which the k-th matched character of a differs from the k-th of b
def jaro.h(xs: List<&2, U32>, ys: List<&2, U32>, acc: Nat) -> Nat:
  match xs ys:
    case Con{x, xt} Con{y, yt}:
      jaro.h(xt, yt, Nat.add(acc, Bool.pick(Nat, U32.is_eq(x, y), 0n, 1n)))
    case _ _:
      acc

# S1.74 J = ((m/|a| + m/|b|) + (m - t)/m) / 3 in binary64, in that order; 0 when m = 0
def jaro.value(+m: Nat, la: Nat, lb: Nat, t: Nat) -> F.F64:
  match m:
    case 0n:
      F.zero()
    case 1n+p:
      F.div(F.add(F.add(F.div(F.from_nat(m), F.from_nat(la)), F.div(F.from_nat(m), F.from_nat(lb))), F.div(F.from_nat(Nat.sub(m, t)), F.from_nat(m))), F.from_nat(3n))

# S1.74 from the finished matching
def jaro.fin(st: JA, la: Nat, lb: Nat) -> F.F64:
  match st:
    case JA{i, bs, +am}:
      jaro.value(T.llen(&2, U32, am, 0n), la, lb, Nat.div(jaro.h(List.reverse(&2, U32, am), jaro.bmatched(bs, Nil{}), 0n), 2n))

# S1.74 w = max(floor(max(|a|, |b|) / 2) - 1, 0)
def jaro.window(la: Nat, lb: Nat) -> Nat:
  Nat.sub(Nat.div(Nat.max(la, lb), 2n), 1n)

# S1.74 the similarity of two texts taken as sequences of scalar values (0 when either is empty: m = 0)
def jaro(+a: String, +b: String) -> F.F64:
  jaro.fin(jaro.match(a, JA{0n, jaro.bms(b, Nil{}), Nil{}}, jaro.window(T.str_len(a, 0n), T.str_len(b, 0n))), T.str_len(a, 0n), T.str_len(b, 0n))

# S1.74 the binary64 literal 0.7
def seven_tenths() -> F.F64:
  F.from_dec(True{}, False{}, [7], 1n)

# S1.75 the best candidate so far: whether there is one, its text and its J
type Best is Data:
  Best{has: Bool, name: String, j: F.F64}

# S1.75 a candidate replaces the best when its J is above 0.7 and not below the best's: among equal
# J the LATER candidate wins
def best.pick(above: Bool, c: Cmp, +cand: String, +j: F.F64, old: Best) -> Best:
  match above c:
    case False{} _:
      old
    case True{} LT{}:
      old
    case True{} _:
      Best{True{}, cand, j}

# S1.75 one candidate against the best so far
def best.one(old: Best, +cand: String, +j: F.F64) -> Best:
  match old:
    case Best{False{}, name, bj}:
      best.pick(BN.is_gt.of(F.cmp(j, seven_tenths())), GT{}, cand, j, Best{False{}, name, bj})
    case Best{True{}, name, +bj}:
      best.pick(BN.is_gt.of(F.cmp(j, seven_tenths())), F.cmp(j, bj), cand, j, Best{True{}, name, bj})

# S1.75 every candidate in list order (a loop over the list)
def best.go(cands: List<&2, String>, +word: String, old: Best) -> Best:
  match cands:
    case Nil{}:
      old
    case Con{+c, rest}:
      best.go(rest, word, best.one(old, c, jaro(word, c)))

# S1.75 the most similar candidate above 0.7, if any
def best(cands: List<&2, String>, word: String) -> Best:
  best.go(cands, word, Best{False{}, SNil{}, F.zero()})

# ---------------------------------------------------------------- S1.70–S1.86 the argv error texts

# S1.70 the last lines of every argv error that carries a Usage line. Every argv error text here is
# WITHOUT its final LF: the shell's stderr write appends it.
def fin(usage: String) -> String:
  usage ++ "\n\nFor more information, try '--help'."

# S1.72 the fixed usage line
def usage_fixed() -> String:
  "Usage: toon [OPTIONS] [INPUT]"

# S1.72 whether an argument is committed (a loop over C; stops at the first hit)
def has.go(c: List<&2, Nat>, +id: Nat, hit: Bool) -> Bool:
  match c hit:
    case _ True{}:
      True{}
    case Nil{} False{}:
      False{}
    case Con{x, rest} False{}:
      has.go(rest, id, Nat.is_eq(x, id))

# S1.13 whether an argument is in the committed list
def has(c: List<&2, Nat>, id: Nat) -> Bool:
  has.go(c, id, False{})

# S1.72 the options and flags of C in C's order, each followed by one space (INPUT is always last);
# the line is accumulated reversed
def usage.args(c: List<&2, Nat>, acc: String) -> String:
  match c:
    case Nil{}:
      acc
    case Con{0n, rest}:
      usage.args(rest, acc)
    case Con{id, rest}:
      usage.args(rest, SCon{Chr{32}, T.rev_onto(disp(id), acc)})

# S1.72 `<INPUT>` when INPUT is committed, else `[INPUT]`
def usage.input(committed: Bool) -> String:
  match committed:
    case True{}:
      "<INPUT>"
    case False{}:
      "[INPUT]"

# S1.72 the smart usage line built from C
def usage(+c: List<&2, Nat>) -> String:
  match c:
    case Nil{}:
      usage_fixed()
    case Con{x, rest}:
      String.reverse(T.rev_onto(usage.input(has(c, 0n)), usage.args(x <> rest, T.rev_onto("Usage: toon ", SNil{}))))

# S1.71 unknown long option without a similar name
def e71(+name: String, usage_line: String) -> String:
  T.cat(["error: unexpected argument '--", name, "' found\n\n  tip: to pass '--", name, "' as a value, use '-- --", name, "'\n\n", fin(usage_line)])

# S1.73 unknown long option with a similar name
def e73(name: String, cand: String, usage_line: String) -> String:
  T.cat(["error: unexpected argument '--", name, "' found\n\n  tip: a similar argument exists: '--", cand, "'\n\n", fin(usage_line)])

# S1.77 unknown short character: always the fixed usage line, never a similarity tip
def e77(+c: U32) -> String:
  "error: unexpected argument '-" ++ SCon{Chr{c}, SNil{}} ++ "' found\n\n  tip: to pass '-" ++ SCon{Chr{c}, SNil{}} ++ "' as a value, use '-- -" ++ SCon{Chr{c}, SNil{}} ++ "'\n\n" ++ fin(usage_fixed())

# S1.78 extra positional word: no tip line, fixed usage line
def e78(word: String) -> String:
  T.cat(["error: unexpected argument '", word, "' found\n\n", fin(usage_fixed())])

# S1.79 encode/decode conflict
def e79(first: Nat, second: Nat, usage_line: String) -> String:
  "error: the argument '" ++ disp(first) ++ "' cannot be used with '" ++ disp(second) ++ "'\n\n" ++ fin(usage_line)

# S1.80 used more than once
def e80(id: Nat) -> String:
  "error: the argument '" ++ disp(id) ++ "' cannot be used multiple times\n\n" ++ fin(usage_fixed())

# S1.81 the possible-values line of the two enum options
def pv(id: Nat) -> String:
  match id:
    case 7n:
      "  [possible values: off, safe]\n"
    case 9n:
      "  [possible values: off, safe]\n"
    case _:
      SNil{}

# S1.81, S1.82 missing or empty value: no Usage line
def e81(+id: Nat) -> String:
  "error: a value is required for '" ++ disp(id) ++ "' but none was supplied\n" ++ pv(id) ++ "\nFor more information, try '--help'."

# S1.83 invalid value with a reason: the word as typed, no Usage line
def e83(word: String, id: Nat, reason: String) -> String:
  T.cat(["error: invalid value '", word, "' for '", disp(id), "': ", reason, "\n\nFor more information, try '--help'."])

# S1.84 the optional similar-value tip
def e84.tip(b: Best) -> String:
  match b:
    case Best{True{}, name, j}:
      "\n  tip: a similar value exists: '" ++ name ++ "'\n"
    case Best{False{}, name, j}:
      SNil{}

# S1.84 invalid enum value
def e84(+word: String, id: Nat) -> String:
  T.cat(["error: invalid value '", word, "' for '", disp(id), "'\n  [possible values: off, safe]\n", e84.tip(best(["off", "safe"], word)), "\nFor more information, try '--help'."])

# S1.86 the group G of every argument a value-less flag competes with (help and version are not in it)
def usage_g() -> String:
  "<INPUT|--output <FILE>|--encode|--decode|--delimiter <DELIMITER>|--indent <INDENT>|--no-strict|--key-folding <KEY_FOLDING>|--flatten-depth <N>|--expand-paths <EXPAND_PATHS>|--stats>"

# S1.86 the usage line depends on whether C is empty at that moment: empty, the flag and `[INPUT]`;
# otherwise the group G, preceded by the flag itself when the flag is not a member of G (--help and
# --version; amended in Phase 4, OQ-P4-1)
def e86.usage(c: List<&2, Nat>, +id: Nat) -> String:
  match c id:
    case Nil{} _:
      T.cat(["Usage: toon ", disp(id), " [INPUT]"])
    case Con{x, rest} 11n:
      T.cat(["Usage: toon --help ", usage_g()])
    case Con{x, rest} 12n:
      T.cat(["Usage: toon --version ", usage_g()])
    case Con{x, rest} _:
      T.cat(["Usage: toon ", usage_g()])

# S1.86 a value attached to a flag
def e86(val: String, +id: Nat, c: List<&2, Nat>) -> String:
  T.cat(["error: unexpected value '", val, "' for '", disp(id), "' found; no more were expected\n\n", fin(e86.usage(c, id))])

# S1.60 the help text, block V1
def help_text() -> String:
  "TOON reference implementation in Rust (JSON <-> TOON)\n\nUsage: toon [OPTIONS] [INPUT]\n\nArguments:\n  [INPUT]  Input file path (omit or use \"-\" to read from stdin)\n\nOptions:\n  -o, --output <FILE>                Output file path (omit or use \"-\" to write to stdout)\n  -e, --encode                       Encode JSON to TOON (auto-detected by default)\n  -d, --decode                       Decode TOON to JSON (auto-detected by default)\n      --delimiter <DELIMITER>        Delimiter for arrays: comma (`,` or `comma`), tab (`\\t` or `tab`), or pipe (`|` or `pipe`) [default: ,]\n      --indent <INDENT>              Indentation size in spaces, 0 to 16 (encode: TOON output, at least 1; decode: TOON input and JSON output, where 0 prints compact JSON) [default: 2]\n      --no-strict                    Disable strict mode for decoding (allows lenient parsing)\n      --key-folding <KEY_FOLDING>    Key folding mode: off or safe [default: off] [possible values: off, safe]\n      --flatten-depth <N>            Maximum folded segment count when key folding is enabled\n      --expand-paths <EXPAND_PATHS>  Path expansion mode: off or safe (decode only) [default: off] [possible values: off, safe]\n      --stats                        Show token estimates for the JSON and TOON forms (stderr)\n  -h, --help                         Print help\n  -V, --version                      Print version\n\nEXAMPLES:\n    toon input.json                  # Encode JSON to TOON (stdout)\n    toon input.toon                  # Decode TOON to JSON (stdout)\n    toon input.json -o output.toon   # Encode to file\n    cat data.json | toon --encode    # Encode from stdin\n    cat data.toon | toon --decode    # Decode from stdin\n    toon input.json --stats          # Show token statistics\n"

# S1.62 the version line
def version_text() -> String:
  "toon 0.2.4\n"

# ---------------------------------------------------------------- S1.30–S1.34 option values

# S1.3 (table T1) the option values (flags and the presence of INPUT are read from the committed list): INPUT word,
# output word, delimiter, indent, key folding, flatten depth (any value above the deepest possible key
# chain acts as unlimited, S7.2: capped at 1000), path expansion
type Vals is Data:
  Vals{input: String, output: String, delim: U32, indent: Nat, fold: Bool, budget: Nat, expand: Bool}

# S1.3 (table T1) the defaults
def vals0() -> Vals:
  Vals{SNil{}, SNil{}, 44, 2n, False{}, 1000n, False{}}

# S1.14 (4) a validated value, or the text of its error
type VR is Data:
  VOk{vals: Vals}
  VBad{text: String}

# S1.30 the seven delimiter words, case-sensitive, untrimmed; 0 for every other word
def delim.of(+w: String) -> U32:
  Bool.pick(U32, Bool.or(T.str_eq(w, ","), T.str_eq(w, "comma")), 44, Bool.pick(U32, Bool.or(T.str_eq(w, "|"), T.str_eq(w, "pipe")), 124, Bool.pick(U32, Bool.or(T.str_eq(w, "tab"), Bool.or(T.str_eq(w, "\\t"), T.str_eq(w, "\t"))), 9, 0)))

# S1.83 R-DELIM: the word is copied raw between the double quotes; `(\t)` is a backslash and a `t`
def e83.delim(+w: String) -> String:
  e83(w, 4n, T.cat(["Invalid delimiter \"", w, "\". Valid delimiters are: comma (,), tab (\\t), pipe (|)"]))

# S1.30 an accepted delimiter is stored; any other word is S1.83 with reason R-DELIM
def delim.set.if(bad: Bool, d: U32, w: String, input: String, output: String, indent: Nat, fold: Bool, budget: Nat, expand: Bool) -> VR:
  match bad:
    case True{}:
      VBad{e83.delim(w)}
    case False{}:
      VOk{Vals{input, output, d, indent, fold, budget, expand}}

# S1.30 the delimiter option
def delim.set(+d: U32, w: String, v: Vals) -> VR:
  match v:
    case Vals{input, output, delim, indent, fold, budget, expand}:
      delim.set.if(U32.is_eq(d, 0), d, w, input, output, indent, fold, budget, expand)

# S1.31, S1.32 an integer word: kind 0 well-formed, 1 empty, 2 invalid digit; its sign; its digits
type IW is Data:
  IW{kind: Nat, neg: Bool, digits: String}

# S1.31 the verdict of the digit test
def int.digits.if(ok: Bool, neg: Bool, s: String) -> IW:
  match ok:
    case True{}:
      IW{0n, neg, s}
    case False{}:
      IW{2n, False{}, SNil{}}

# S1.31 one or more ASCII digits, nothing else (a lone sign is an invalid digit)
def int.digits(neg: Bool, +s: String) -> IW:
  int.digits.if(D.all_digits(s), neg, s)

# S1.31 an optional single '+' or '-' (S1.32: `minus` False makes a leading '-' an invalid digit)
def int.sign(plus: Bool, dash: Bool, minus: Bool, c: U32, rest: String) -> IW:
  match plus dash minus:
    case True{} _ _:
      int.digits(False{}, rest)
    case False{} True{} True{}:
      int.digits(True{}, rest)
    case False{} True{} False{}:
      IW{2n, False{}, SNil{}}
    case False{} False{} _:
      int.digits(False{}, SCon{Chr{c}, rest})

# S1.31, S1.32 read an integer word
def int.word(w: String, minus: Bool) -> IW:
  match w:
    case SNil{}:
      IW{1n, False{}, SNil{}}
    case SCon{Chr{+c}, rest}:
      int.sign(U32.is_eq(c, 43), U32.is_eq(c, 45), minus, c, rest)

# S1.31 the canonical digits of a well-formed word (leading zeros are allowed)
def int.canon(digits: String) -> String:
  D.len.canon(F.strip_zeros(digits))

# S1.31 whether canonical digits exceed a 19-digit limit of the signed 64-bit range
def int.beyond(+c: String, lim: String) -> Bool:
  Bool.or(Nat.is_gt(T.str_len(c, 0n), 19n), Bool.and(Nat.is_eq(T.str_len(c, 0n), 19n), String.is_gt(c, lim)))

# S1.31 the parsed integer in canonical decimal, for the range message (`-007` is `-7`, `-0` is `0`)
def int.show(neg: Bool, +c: String) -> String:
  match neg:
    case True{}:
      Bool.pick(String, T.str_eq(c, "0"), "0", "-" ++ c)
    case False{}:
      c

# S1.31 0..=16: not negative (but `-0` is 0), at most two digits, and then at most 16 (the value of
# a longer digit string is never computed: arguments are evaluated eagerly and Nat ends at 2^48)
def indent.small(short: Bool, c: String) -> Nat:
  match short:
    case True{}:
      T.nat_of(c, 0n)
    case False{}:
      17n

# S1.31 the reasons, first that applies
def indent.reason(kind: Nat, large: Bool, small: Bool, ok: Bool, shown: String) -> String:
  match kind large small ok:
    case 1n _ _ _:
      "cannot parse integer from empty string"
    case 2n _ _ _:
      "invalid digit found in string"
    case _ True{} _ _:
      "number too large to fit in target type"
    case _ False{} True{} _:
      "number too small to fit in target type"
    case _ False{} False{} True{}:
      SNil{}
    case _ False{} False{} False{}:
      shown ++ " is not in 0..=16"

# S1.31 store the indent, or S1.83 with its reason
def indent.set(reason: String, +w: String, n: Nat, v: Vals) -> VR:
  match reason v:
    case SNil{} Vals{input, output, delim, indent, fold, budget, expand}:
      VOk{Vals{input, output, delim, n, fold, budget, expand}}
    case SCon{c, r} v0:
      VBad{e83(w, 5n, SCon{c, r})}

# S1.31 the range verdicts over the canonical digits
def indent.check.c(+kind: Nat, +neg: Bool, +c: String, w: String, v: Vals) -> VR:
  indent.set(indent.reason(kind, Bool.and(Bool.not(neg), int.beyond(c, "9223372036854775807")), Bool.and(neg, int.beyond(c, "9223372036854775808")), Bool.and(Bool.or(Bool.not(neg), T.str_eq(c, "0")), Nat.is_le(indent.small(Nat.is_le(T.str_len(c, 0n), 2n), c), 16n)), int.show(neg, c)), w, indent.small(Nat.is_le(T.str_len(c, 0n), 2n), c), v)

# S1.31 the verdicts of a well-formed (or not) indent word
def indent.check(iw: IW, w: String, v: Vals) -> VR:
  match iw:
    case IW{kind, neg, digits}:
      indent.check.c(kind, neg, int.canon(digits), w, v)

# S1.32 store the flatten depth, or S1.83 with its reason
def budget.set(reason: String, w: String, n: Nat, v: Vals) -> VR:
  match reason v:
    case SNil{} Vals{input, output, delim, indent, fold, budget, expand}:
      VOk{Vals{input, output, delim, indent, fold, n, expand}}
    case SCon{c, r} v0:
      VBad{e83(w, 8n, SCon{c, r})}

# S1.32 the reasons, first that applies
def budget.reason(kind: Nat, large: Bool) -> String:
  match kind large:
    case 1n _:
      "cannot parse integer from empty string"
    case 2n _:
      "invalid digit found in string"
    case _ True{}:
      "number too large to fit in target type"
    case _ False{}:
      SNil{}

# S7.2 a depth of four or more digits acts as unlimited (no key chain is that deep); its value is
# never computed
def budget.value(short: Bool, c: String) -> Nat:
  match short:
    case True{}:
      T.nat_of(c, 0n)
    case False{}:
      1000n

# S1.32 canonical digits fit the 64-bit unsigned word up to 18446744073709551615
def u64.fits(+d: String) -> Bool:
  Bool.or(Nat.is_lt(T.str_len(d, 0n), 20n), Bool.and(Nat.is_eq(T.str_len(d, 0n), 20n), String.is_le(d, "18446744073709551615")))

# S1.32 the range verdict over the canonical digits
def budget.check.c(kind: Nat, +c: String, w: String, v: Vals) -> VR:
  budget.set(budget.reason(kind, Bool.not(u64.fits(c))), w, Nat.min(budget.value(Nat.is_le(T.str_len(c, 0n), 3n), c), 1000n), v)

# S1.32 the verdicts of a flatten-depth word: every value up to 18446744073709551615 is accepted
def budget.check(iw: IW, w: String, v: Vals) -> VR:
  match iw:
    case IW{kind, neg, digits}:
      budget.check.c(kind, int.canon(digits), w, v)

# S1.33 store an enum value (7 key folding, 9 path expansion)
def enum.put(id: Nat, on: Bool, v: Vals) -> VR:
  match id v:
    case 7n Vals{input, output, delim, indent, fold, budget, expand}:
      VOk{Vals{input, output, delim, indent, on, budget, expand}}
    case _ Vals{input, output, delim, indent, fold, budget, expand}:
      VOk{Vals{input, output, delim, indent, fold, budget, on}}

# S1.33 exactly `off` or `safe`; the empty word is S1.82; anything else S1.84
def enum.set(off: Bool, safe: Bool, empty: Bool, +id: Nat, w: String, v: Vals) -> VR:
  match off safe empty:
    case True{} _ _:
      enum.put(id, False{}, v)
    case False{} True{} _:
      enum.put(id, True{}, v)
    case False{} False{} True{}:
      VBad{e81(id)}
    case False{} False{} False{}:
      VBad{e84(w, id)}

# S1.34 `-o` and INPUT accept any non-empty word verbatim; the empty word is S1.82
def word.set(empty: Bool, +id: Nat, w: String, v: Vals) -> VR:
  match empty id v:
    case True{} _ v0:
      VBad{e81(id)}
    case False{} 0n Vals{input, output, delim, indent, fold, budget, expand}:
      VOk{Vals{w, output, delim, indent, fold, budget, expand}}
    case False{} _ Vals{input, output, delim, indent, fold, budget, expand}:
      VOk{Vals{input, w, delim, indent, fold, budget, expand}}

# S1.14 (4) validate the value of an argument
def validate(id: Nat, +w: String, v: Vals) -> VR:
  match id:
    case 0n:
      word.set(String.is_empty(w), 0n, w, v)
    case 1n:
      word.set(String.is_empty(w), 1n, w, v)
    case 4n:
      delim.set(delim.of(w), w, v)
    case 5n:
      indent.check(int.word(w, True{}), w, v)
    case 7n:
      enum.set(T.str_eq(w, "off"), T.str_eq(w, "safe"), String.is_empty(w), 7n, w, v)
    case 8n:
      budget.check(int.word(w, False{}), w, v)
    case 9n:
      enum.set(T.str_eq(w, "off"), T.str_eq(w, "safe"), String.is_empty(w), 9n, w, v)
    case _:
      VOk{v}

# ---------------------------------------------------------------- S1.13–S1.19 the argv state machine

# S1.13 the pending item: none; a value-taking option met without an attached value, with the value
# word it has collected (if any); or the INPUT word
type Pend is Data:
  PNo{}
  POpt{id: Nat, has: Bool, word: String}
  PIn{word: String}

# S1.13 the scan: still going (the committed list C in order, the pending item, the values so far), or
# stopped with an exit code and the texts for stdout and stderr
type PS is Data:
  PGo{c: List<&2, Nat>, p: Pend, vals: Vals}
  PStop{code: Nat, out: String, err: String}

# S1.14 the effect of resolving the pending item: the new C, the new values, and the text of its
# error (empty: none). After an error the values are never read again.
type RR is Data:
  RR{c: List<&2, Nat>, vals: Vals, err: String}

# S1.14 (2) keep an argument unless it is the removed one
def c.keep(same: Bool, x: Nat, acc: List<&2, Nat>) -> List<&2, Nat>:
  match same:
    case True{}:
      acc
    case False{}:
      x <> acc

# S1.14 (2) remove an argument from C, the others keep their order
def c.remove(c: List<&2, Nat>, +id: Nat, acc: List<&2, Nat>) -> List<&2, Nat>:
  match c:
    case Nil{}:
      List.reverse(&2, Nat, acc)
    case Con{+x, rest}:
      c.remove(rest, id, c.keep(Nat.is_eq(x, id), x, acc))

# S1.14 (3) append an argument to C
def c.add(c: List<&2, Nat>, id: Nat) -> List<&2, Nat>:
  List.append(&2, Nat, c, id <> Nil{})

# S1.14 (4) the verdict of the validation
def commit.val(r: VR, c: List<&2, Nat>) -> RR:
  match r:
    case VOk{v}:
      RR{c, v, SNil{}}
    case VBad{text}:
      RR{c, vals0(), text}

# S1.14 steps 2, 3, 4 for an argument and its value word (flags have none: `valued` False)
def commit(dup: Bool, valued: Bool, +c: List<&2, Nat>, +id: Nat, w: String, v: Vals) -> RR:
  match dup valued:
    case True{} _:
      RR{c.remove(c, id, Nil{}), v, e80(id)}
    case False{} True{}:
      commit.val(validate(id, w, v), c.add(c, id))
    case False{} False{}:
      RR{c.add(c, id), v, SNil{}}

# S1.14 resolve the pending item: (1) an option without a value is the missing-value error and
# nothing is committed; otherwise steps 2, 3, 4. INPUT uses steps 3 and 4 only.
def resolve(+c: List<&2, Nat>, p: Pend, v: Vals) -> RR:
  match p:
    case PNo{}:
      RR{c, v, SNil{}}
    case POpt{id, False{}, w}:
      RR{c, v, e81(id)}
    case POpt{+id, True{}, w}:
      commit(has(c, id), True{}, c, id, w, v)
    case PIn{w}:
      commit(False{}, True{}, c, 0n, w, v)

# S1.15 after a commit: its error stops the scan; otherwise nothing is pending
def flag.commit(r: RR) -> PS:
  match r:
    case RR{c, v, SCon{h, t}}:
      PStop{2n, SNil{}, SCon{h, t}}
    case RR{c, v, SNil{}}:
      PGo{c, PNo{}, v}

# S1.15 (i) after P was resolved with reporting: help and version act at once (S1.19); any other flag
# takes steps 2 and 3
def flag.after(r: RR, +id: Nat) -> PS:
  match r id:
    case RR{c, v, SCon{h, t}} _:
      PStop{2n, SNil{}, SCon{h, t}}
    case RR{c, v, SNil{}} 11n:
      PStop{0n, help_text(), SNil{}}
    case RR{c, v, SNil{}} 12n:
      PStop{0n, version_text(), SNil{}}
    case RR{+c, v, SNil{}} _:
      flag.commit(commit(has(c, id), False{}, c, id, SNil{}, v))

# S1.15 (ii) after P was resolved with reporting: steps 2, 3, 4 for the option at once
def opt.after(r: RR, +id: Nat, w: String) -> PS:
  match r:
    case RR{c, v, SCon{h, t}}:
      PStop{2n, SNil{}, SCon{h, t}}
    case RR{+c, v, SNil{}}:
      flag.commit(commit(has(c, id), True{}, c, id, w, v))

# S1.15 (iii) after P was resolved with reporting: the option becomes the pending item
def wait.after(r: RR, id: Nat) -> PS:
  match r:
    case RR{c, v, SCon{h, t}}:
      PStop{2n, SNil{}, SCon{h, t}}
    case RR{c, v, SNil{}}:
      PGo{c, POpt{id, False{}, SNil{}}, v}

# S1.15 (v) after P was resolved with reporting: the word becomes the pending INPUT
def input.after(r: RR, w: String) -> PS:
  match r:
    case RR{c, v, SCon{h, t}}:
      PStop{2n, SNil{}, SCon{h, t}}
    case RR{c, v, SNil{}}:
      PGo{c, PIn{w}, v}

# S1.73 the usage line shows C with the candidate appended when it is not already committed
def similar.usage(dup: Bool, +c: List<&2, Nat>, id: Nat) -> String:
  match dup:
    case True{}:
      usage(c)
    case False{}:
      usage(c.add(c, id))

# S1.71, S1.73 an unknown long name: P's own error is discarded, its effect on C is kept
def unknown.long(b: Best, r: RR, name: String) -> PS:
  match b r:
    case Best{False{}, cand, j} RR{c, v, e}:
      PStop{2n, SNil{}, e71(name, usage(c))}
    case Best{True{}, +cand, j} RR{+c, v, e}:
      PStop{2n, SNil{}, e73(name, cand, similar.usage(has(c, long_id(cand)), c, long_id(cand)))}

# S1.15 a long-option word. id 0: unknown (vi). A flag with `=value` is S1.86 at once, P untouched
# (vii). Otherwise P is resolved with reporting and the flag (i), the option with its attached value
# (ii) or the waiting option (iii) follows.
def on.long(id: Nat, valued: Bool, has_val: Bool, +name: String, val: String, +c: List<&2, Nat>, p: Pend, v: Vals) -> PS:
  match id valued has_val:
    case 0n _ _:
      unknown.long(best(names(), name), resolve(c, p, v), name)
    case +i False{} True{}:
      PStop{2n, SNil{}, e86(val, i, c)}
    case +i False{} False{}:
      flag.after(resolve(c, p, v), i)
    case +i True{} True{}:
      opt.after(resolve(c, p, v), i, val)
    case +i True{} False{}:
      wait.after(resolve(c, p, v), i)

# S1.3 the only short flag letters are e, d, h, V (case-sensitive); `o` never reaches this def (S1.8)
def short.id(+ch: U32) -> Nat:
  Bool.pick(Nat, U32.is_eq(ch, 101), 2n, Bool.pick(Nat, U32.is_eq(ch, 100), 3n, Bool.pick(Nat, U32.is_eq(ch, 104), 11n, Bool.pick(Nat, U32.is_eq(ch, 86), 12n, 0n))))

# S1.8 a character of a short cluster: e, d, h, V act as their long flags (id is that flag, or 0); any
# other character is S1.77
def on.short(id: Nat, c32: U32, c: List<&2, Nat>, p: Pend, v: Vals) -> PS:
  match id:
    case 0n:
      PStop{2n, SNil{}, e77(c32)}
    case +i:
      flag.after(resolve(c, p, v), i)

# S1.9, S1.15 (iv)–(vi) a plain word: the value of a waiting option (only before the escape); else
# INPUT when none was seen (committed or pending); else an extra positional, S1.78
def on.plain(p: Pend, esc: Bool, seen: Bool, w: String, c: List<&2, Nat>, v: Vals) -> PS:
  match p esc seen:
    case POpt{id, False{}, old} False{} _:
      PGo{c, POpt{id, True{}, w}, v}
    case PIn{old} _ _:
      PStop{2n, SNil{}, e78(w)}
    case p0 _ True{}:
      PStop{2n, SNil{}, e78(w)}
    case p0 _ False{}:
      input.after(resolve(c, p0, v), w)

# S1.157 --indent (5) and --flatten-depth (8) allow negative numbers: while one of them waits for
# its value, a '-' + number word is that value
def neg.ok(p: Pend) -> Bool:
  match p:
    case POpt{5n, False{}, w}:
      True{}
    case POpt{8n, False{}, w}:
      True{}
    case _:
      False{}

# S1.157 the value of the waiting option (a plain word, S1.9); otherwise the cluster, whose first
# character is a digit and therefore the unknown-character error S1.77
def on.neg(ok: Bool, +ch: U32, w: String, +c: List<&2, Nat>, p: Pend, v: Vals) -> PS:
  match ok:
    case True{}:
      on.plain(p, False{}, has(c, 0n), w, c, v)
    case False{}:
      on.short(short.id(ch), ch, c, p, v)

# S1.15 one token
def on.tok(st: PS, t: Tok) -> PS:
  match st t:
    case PStop{code, out, err} _:
      PStop{code, out, err}
    case PGo{c, p, v} TEsc{}:
      PGo{c, p, v}
    case PGo{c, p, v} TLong{+name, has_val, val}:
      on.long(long_id(name), takes_value(long_id(name)), has_val, name, val, c, p, v)
    case PGo{c, p, v} TShort{+ch}:
      on.short(short.id(ch), ch, c, p, v)
    case PGo{c, p, v} TOut{True{}, val}:
      opt.after(resolve(c, p, v), 1n, val)
    case PGo{c, p, v} TOut{False{}, val}:
      wait.after(resolve(c, p, v), 1n)
    case PGo{+c, p, v} TPlain{w, esc}:
      on.plain(p, esc, has(c, 0n), w, c, v)
    case PGo{+c, +p, v} TNeg{w, +ch}:
      on.neg(neg.ok(p), ch, w, c, p, v)

# S1.4 the tokens left to right; the first report ends the scan (a loop over the tokens)
def scan(ts: List<&2, Tok>, st: PS) -> PS:
  match ts:
    case Nil{}:
      st
    case Con{t, rest}:
      scan(rest, on.tok(st, t))

# ---------------------------------------------------------------- S1.16, S4.300–S4.303 the accepted argv

# S1.3 (table T1), S4.300 the resolved options: whether INPUT is a path (else stdin) and the word; whether there is
# an output path and the word; decode mode; delimiter; indent; strict; key folding; flatten depth;
# path expansion; statistics
type Opts is Data:
  Opts{has_in: Bool, input: String, has_out: Bool, output: String, decode: Bool, delim: U32, indent: Nat, strict: Bool, fold: Bool, budget: Nat, expand: Bool, stats: Bool}

# S1.20 the outcome of argv: a text and an exit code, or the options to run with
type Parsed is Data:
  PExit{code: Nat, out: String, err: String}
  PRun{o: Opts}

# S4.302 ASCII lower case of a text, reversed onto acc (no other character lowercases to j s o n t)
def lower.rev(s: String, acc: String) -> String:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{+c}, rest}:
      lower.rev(rest, SCon{Chr{Bool.pick(U32, Bool.and(U32.is_ge(c, 65), U32.is_le(c, 90)), (c + 32 : U32), c)}, acc})

# S4.301 the extension, from the REVERSED final path component cut at its first '.' (the last dot of
# the component): the text after that dot, even when nothing precedes it (a file named `.toon` has
# the extension `toon`); no dot means no extension. The argument `ext_rev` is the text after the last
# dot, reversed; lowering it reversed onto the empty text restores its order.
def ext.of(c: T.Cut) -> String:
  match c:
    case T.Cut{False{}, ext_rev, stem_rev}:
      SNil{}
    case T.Cut{True{}, ext_rev, stem_rev}:
      lower.rev(ext_rev, SNil{})

# S4.301 the final path component, reversed (the text after the last '/')
def ext.comp(c: T.Cut) -> String:
  match c:
    case T.Cut{found, before, after}:
      before

# S4.301, S4.302 the lower-cased extension of a path (empty when there is none)
def ext(path: String) -> String:
  ext.of(T.cut(ext.comp(T.cut(String.reverse(path), 47)), 46))

# S4.300 mode selection, first rule that applies: (1) --encode; (2) --decode; (3) the extension of an
# INPUT path; (4) encode. S4.303: stdin has no extension.
def mode.decode(enc: Bool, dec: Bool, has_in: Bool, +e: String) -> Bool:
  match enc dec has_in:
    case True{} _ _:
      False{}
    case False{} True{} _:
      True{}
    case False{} False{} True{}:
      T.str_eq(e, "toon")
    case False{} False{} False{}:
      False{}

# S1.11 INPUT absent, or exactly `-`, means stdin; S1.12 the output word `-` means stdout, like no -o
def opts(+c: List<&2, Nat>, v: Vals) -> Opts:
  match v:
    case Vals{+input, +output, delim, indent, fold, budget, expand}:
      Opts{Bool.and(has(c, 0n), Bool.not(T.str_eq(input, "-"))), input, Bool.and(has(c, 1n), Bool.not(T.str_eq(output, "-"))), output, mode.decode(has(c, 2n), has(c, 3n), Bool.and(has(c, 0n), Bool.not(T.str_eq(input, "-"))), ext(input)), delim, indent, Bool.not(has(c, 6n)), fold, budget, expand, has(c, 10n)}

# S1.18 which of encode (2) and decode (3) is earlier in C
def conflict.first(c: List<&2, Nat>) -> Nat:
  match c:
    case Nil{}:
      2n
    case Con{2n, rest}:
      2n
    case Con{3n, rest}:
      3n
    case Con{x, rest}:
      conflict.first(rest)

# S1.79 the message names the earlier flag first; the usage line is built from C without the other
def conflict(+first: Nat, +c: List<&2, Nat>) -> Parsed:
  PExit{2n, SNil{}, e79(first, Nat.sub(5n, first), usage(c.remove(c, Nat.sub(5n, first), Nil{})))}

# S1.18 the conflict is considered only when the scan ended without any report
def finish.ok(both: Bool, +c: List<&2, Nat>, v: Vals) -> Parsed:
  match both:
    case True{}:
      conflict(conflict.first(c), c)
    case False{}:
      PRun{opts(c, v)}

# S1.16 at the end of argv: P is resolved with reporting; then the conflict rule; then the run
def finish.rr(r: RR) -> Parsed:
  match r:
    case RR{c, v, SCon{h, t}}:
      PExit{2n, SNil{}, SCon{h, t}}
    case RR{+c, v, SNil{}}:
      finish.ok(Bool.and(has(c, 2n), has(c, 3n)), c, v)

# S1.16 the end of the scan
def finish(st: PS) -> Parsed:
  match st:
    case PStop{code, out, err}:
      PExit{code, out, err}
    case PGo{c, p, v}:
      finish.rr(resolve(c, p, v))

# S1.4 the whole argv (without argv[0])
def parse(argv: List<&2, String>) -> Parsed:
  finish(scan(toks(argv), PGo{Nil{}, PNo{}, vals0()}))

# ---------------------------------------------------------------- S4.310–S4.319 statistics

# S4.310 estimator state: scalar values that are not whitespace, words, whether a word is open
type ES is Data:
  ES{c: Nat, w: Nat, inw: Bool}

# S4.312 a word is a maximal run of non-whitespace scalar values
def est.ch(st: ES, ws: Bool) -> ES:
  match st ws:
    case ES{c, w, inw} True{}:
      ES{c, w, False{}}
    case ES{c, w, True{}} False{}:
      ES{1n+c, w, True{}}
    case ES{c, w, False{}} False{}:
      ES{1n+c, 1n+w, True{}}

# S4.311 whitespace is the Unicode White_Space property (a loop over the text)
def est.go(s: String, st: ES) -> ES:
  match s:
    case SNil{}:
      st
    case SCon{Chr{c}, rest}:
      est.go(rest, est.ch(st, T.is_ws(c)))

# S4.310 E = max(floor(c / 4), w, 1)
def est.fin(st: ES) -> Nat:
  match st:
    case ES{c, w, inw}:
      Nat.max(Nat.max(Nat.div(c, 4n), w), 1n)

# S4.310 the token estimate of a text
def est(s: String) -> Nat:
  est.fin(est.go(s, ES{0n, 0n, False{}}))

# S4.316 a count of tenths as `<units>.<tenth>`
def percent.show(+tenths: Nat) -> String:
  Nat.show(Nat.div(tenths, 10n)) ++ "." ++ Nat.show(Nat.mod(tenths, 10n))

# S4.315 p = D / J * 100 with one fractional digit, rounded half up on the EXACT quotient: in tenths,
# floor((2000 D + J) / 2J). J >= 1 (every estimate is at least 1, S4.310).
def percent(d: Nat, +j: Nat) -> String:
  percent.show(Nat.div(Nat.add(Nat.mul(d, 2000n), j), Nat.mul(j, 2n)))

# S5.108 the noun after a count: singular for exactly one
def noun(+n: Nat) -> String:
  Bool.pick(String, Nat.is_eq(n, 1n), "token", "tokens")

# S5.108 the third line: TOON smaller (Saved, D = J - T), TOON larger (D = T - J), or equal
def stats.third(less: Bool, more: Bool, +j: Nat, +t: Nat) -> String:
  match less more:
    case True{} _:
      T.cat(["\nSaved ~", Nat.show(Nat.sub(j, t)), " ", noun(Nat.sub(j, t)), " (-", percent(Nat.sub(j, t), j), "%)"])
    case False{} True{}:
      T.cat(["\nTOON is larger by ~", Nat.show(Nat.sub(t, j)), " ", noun(Nat.sub(t, j)), " (+", percent(Nat.sub(t, j), j), "%)"])
    case False{} False{}:
      "\nNo token difference (0.0%)"

# S5.108 the statistics lines WITHOUT their final LF (the shell's stderr write appends it): an empty
# line, the estimates line, and the line S5.108 chooses by comparing T with J
def stats.text(+j: Nat, +t: Nat) -> String:
  "\nToken estimates: ~" ++ Nat.show(j) ++ " (JSON) → ~" ++ Nat.show(t) ++ " (TOON)" ++ stats.third(Nat.is_lt(t, j), Nat.is_gt(t, j), j, t)

# ---------------------------------------------------------------- S8.7, S8.8 the conversion

# S8.8 the outcome of a conversion: the complete output text (final LF included) and the statistics
# lines (empty unless encode mode with --stats), or the one runtime error line
type CR is Data:
  COk{out: String, stats: String}
  CErr{msg: String}

# S5.100 each TOON line followed by one LF, accumulated reversed; zero lines give the single LF
def lines.join(ls: List<&2, String>, acc: String) -> String:
  match ls:
    case Nil{}:
      acc
    case Con{l, rest}:
      lines.join(rest, SCon{Chr{10}, T.rev_onto(l, acc)})

# S5.100 the TOON output text
def toon.text(ls: List<&2, String>) -> String:
  match ls:
    case Nil{}:
      "\n"
    case Con{l, rest}:
      String.reverse(lines.join(l <> rest, SNil{}))

# S4.318 statistics only with --stats; S4.313 J measures the input text exactly as read, T the TOON
# output (its final LF is whitespace and cannot change T)
def enc.ok(stats: Bool, +out: String, text: String) -> CR:
  match stats:
    case False{}:
      COk{out, SNil{}}
    case True{}:
      COk{out, stats.text(est(text), est(out))}

# S9.1 a JSON failure; otherwise the encoder's lines
def enc.read(p: J.Parsed, o: E.Opts, stats: Bool, text: String) -> CR:
  match p:
    case J.PErr{msg, line, col}:
      CErr{"Failed to parse JSON: " ++ msg ++ " at line " ++ Nat.show(line) ++ " column " ++ Nat.show(col)}
    case J.POk{v}:
      enc.ok(stats, toon.text(E.encode(v, o)), text)

# S4.318 decode with --stats: J measures the JSON output, T the TOON input as read (S4.313)
def dec.ok(stats: Bool, +out: String, text: String) -> CR:
  match stats:
    case False{}:
      COk{out, SNil{}}
    case True{}:
      COk{out, stats.text(est(out), est(text))}

# S9.3 every TOON failure is the decoder's message after the prefix `Failed to decode TOON: `;
# S5.101 otherwise the JSON text and one LF, from the one JSON writer (S3.24)
def dec.done(r: D.DR, indent: Nat, +spec: Bool, stats: Bool, text: String) -> CR:
  match r:
    case D.DErr{msg}:
      CErr{"Failed to decode TOON: " ++ msg}
    case D.DOk{v}:
      dec.ok(stats, J.write_ln(E.pre.if(spec, True{}, v), indent, spec), text)

# S8.7 a leading U+FEFF (the UTF-8 byte order mark EF BB BF) is dropped from the input: it is an
# encoding signature, never data
def bom.bytes.drop(mark: Bool, a: U32, b: U32, c: U32, rest: List<&2, U32>) -> List<&2, U32>:
  match mark:
    case True{}:
      rest
    case False{}:
      Con{a, Con{b, Con{c, rest}}}

# S8.7 the first three bytes, dropped when they are the mark
def bom.bytes(bytes: List<&2, U32>) -> List<&2, U32>:
  match bytes:
    case Con{+a, Con{+b, Con{+c, rest}}}:
      bom.bytes.drop(Bool.and(U32.is_eq(a, 239), Bool.and(U32.is_eq(b, 187), U32.is_eq(c, 191))), a, b, c, rest)
    case other:
      other

# S8.7 the first character of the decoded text, kept unless it is the mark
def bom.text.drop(mark: Bool, c: U32, rest: String) -> String:
  match mark:
    case True{}:
      rest
    case False{}:
      SCon{Chr{c}, rest}

# S8.7 the same for the decoded text
def bom.text(s: String) -> String:
  match s:
    case SCon{Chr{+c}, rest}:
      bom.text.drop(U32.is_eq(c, 65279), c, rest)
    case other:
      other

# S4.200 (5) path expansion only with --expand-paths safe
def dec.run(expand: Bool, text: String, strict: Bool, indent: Nat, spec: Bool) -> D.DR:
  match expand:
    case True{}:
      D.decode_expanded(text, strict, indent, spec)
    case False{}:
      D.decode(text, strict, indent, spec)

# S8.8 decode the text (after the byte order mark was dropped)
def dec.text(+text: String, expand: Bool, strict: Bool, +indent: Nat, +spec: Bool, stats: Bool) -> CR:
  dec.done(dec.run(expand, text, strict, indent, spec), indent, spec, stats, text)

# S9.7, S9.8 the UTF-8 failure names stdin or the path as typed
def utf8.msg(has_in: Bool, input: String) -> String:
  match has_in:
    case False{}:
      "Failed to read stdin: stream did not contain valid UTF-8"
    case True{}:
      T.cat(["Failed to read file '", input, "': stream did not contain valid UTF-8"])

# S8.7 the complete input is validated as UTF-8 before any parsing (S9.10); S8.8 then the conversion,
# a pure function of the text and the options
def convert.text(m: Maybe<&2, String>, o: Opts, bytes: List<&2, U32>, +spec: Bool) -> CR:
  match m o:
    case None{} Opts{has_in, input, has_out, output, decode, delim, indent, strict, fold, budget, expand, stats}:
      CErr{utf8.msg(has_in, input)}
    case Some{rev} Opts{has_in, input, has_out, output, False{}, delim, indent, strict, fold, budget, expand, stats}:
      enc.read(J.read(bom.bytes(bytes), spec), E.Opts{indent, delim, fold, budget, spec}, stats, bom.text(String.reverse(rev)))
    case Some{rev} Opts{has_in, input, has_out, output, True{}, delim, +indent, strict, fold, budget, expand, stats}:
      dec.text(bom.text(String.reverse(rev)), expand, strict, indent, spec, stats)

# S8.7 the decoder's start: the text is read by decode mode and by --stats (S4.313); an encode without
# --stats reads the bytes, so the decoder only validates there (EXP-018: the same verdict, no text built)
def utf8.start.keep(keep: Bool) -> T.UTF8:
  match keep:
    case True{}:
      T.utf8.init()
    case False{}:
      T.utf8.init.verdict()

# S8.7 whether the conversion reads the decoded text
def o.reads_text(o: Opts) -> Bool:
  match o:
    case Opts{has_in, input, has_out, output, decode, delim, indent, strict, fold, budget, expand, stats}:
      Bool.or(decode, stats)

# S8.7, S8.8 input bytes to output text. spec is the numeric kill-switch (TOON_SPEC=1, read once by the
# shell): with it every number takes its spec twin; the bytes are the same either way.
def convert(+o: Opts, +bytes: List<&2, U32>, spec: Bool) -> CR:
  convert.text(T.utf8.finish(T.utf8.bytes(bytes, utf8.start.keep(o.reads_text(o)))), o, bytes, spec)

# S5.107 the input label: the literal `stdin`, or the INPUT word exactly as typed
def label.in(has_in: Bool, input: String) -> String:
  match has_in:
    case False{}:
      "stdin"
    case True{}:
      input

# S5.105, S5.106 the success line WITHOUT its final LF
def success(o: Opts) -> String:
  match o:
    case Opts{has_in, input, has_out, output, decode, delim, indent, strict, fold, budget, expand, stats}:
      T.cat([Bool.pick(String, decode, "Decoded", "Encoded"), " `", label.in(has_in, input), "` → `", output, "`"])

# S5.102 whether there is an output path
def o.has_out(o: Opts) -> Bool:
  match o:
    case Opts{has_in, input, has_out, output, decode, delim, indent, strict, fold, budget, expand, stats}:
      has_out

# S5.102 the output word exactly as typed
def o.output(o: Opts) -> String:
  match o:
    case Opts{has_in, input, has_out, output, decode, delim, indent, strict, fold, budget, expand, stats}:
      output

# S4.319 encoding needs at least one space per level: with 0 every depth shares one column and the
# output no longer denotes the input. Checked before the input is read.
def o.indent_error(o: Opts) -> Bool:
  match o:
    case Opts{has_in, input, has_out, output, decode, delim, indent, strict, fold, budget, expand, stats}:
      Bool.and(Bool.not(decode), Nat.is_eq(indent, 0n))

# S1.11 whether INPUT is a path (else stdin)
def o.has_in(o: Opts) -> Bool:
  match o:
    case Opts{has_in, input, has_out, output, decode, delim, indent, strict, fold, budget, expand, stats}:
      has_in

# S5.107 the INPUT word exactly as typed
def o.input(o: Opts) -> String:
  match o:
    case Opts{has_in, input, has_out, output, decode, delim, indent, strict, fold, budget, expand, stats}:
      input

# ---------------------------------------------------------------- S5.112 the whole pure core

# S5.112 everything the program prints for an argv and an input, as a value: the exit code, the bytes
# for stdout (or for the -o file) and the text for stderr WITHOUT its final LF. The shell performs it;
# the closed laws state it.
type Out is Data:
  Out{code: Nat, out: String, err: String}

# S5.111 a runtime failure is exit code 1 with nothing written; a success carries the statistics lines
def run.cr(r: CR) -> Out:
  match r:
    case CErr{msg}:
      Out{1n, SNil{}, msg}
    case COk{out, stats}:
      Out{0n, out, stats}

# S1.158 the refusal of indent 0 when encoding
def indent.msg() -> String:
  "Indentation size must be at least 1 when encoding TOON"

# S4.319 the indent is checked before the input is looked at
def run.opts(bad: Bool, o: Opts, bytes: List<&2, U32>) -> Out:
  match bad:
    case True{}:
      Out{1n, SNil{}, indent.msg()}
    case False{}:
      run.cr(convert(o, bytes, False{}))

# S1.135 an argv error, help or version never looks at the input
def run.parsed(p: Parsed, bytes: List<&2, U32>) -> Out:
  match p:
    case PExit{code, out, err}:
      Out{code, out, err}
    case PRun{+o}:
      run.opts(o.indent_error(o), o, bytes)

# S5.112 argv and input bytes to the program's observable result (without the success line of -o)
def run_pure(argv: List<&2, String>, bytes: List<&2, U32>) -> Out:
  run.parsed(parse(argv), bytes)
