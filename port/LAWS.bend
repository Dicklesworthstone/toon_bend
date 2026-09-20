# toon — the laws. HUMAN-OWNED: an agent may add a law, never weaken or delete one. Every law names
# the spec clause it encodes. Kinds:
#   fast == spec   binds every fast twin to its spec twin (none exists before Phase 5)
#   first wins     the first failure, or the finished root value, ends a pass, whatever follows
#   mode           a flag decides regardless of every other input
#   closed golden  a small input whose expected output is pasted from goldens/ or from a spec clause
#                  — the checker computes both sides
# What does NOT belong here: anything the checker must normalize through a large Peano Nat (byte
# values as Nat, long digit strings, whole documents through the JSON reader): those stay in goldens/
# and conform.sh. The scaffold's placeholder law over its stub core was replaced together with the stub.
import Base
import ./bignat.bend as BN
import ./text.bend as T
import ./json.bend as J
import ./decode.bend as D
import ./cli.bend as C

# ---------------------------------------------------------------- first failure wins

# S1.4 the first report ends the argv scan: a stopped scan ignores every later token
law argv_stop_is_sticky:
  for code: Nat
  for out: String
  for err: String
  for t: C.Tok
  {C.on.tok(C.PStop{code, out, err}, t) == C.PStop{code, out, err} : C.PS}

# S9.141, S10.80 the first decode failure ends the pass: the lines that remain are never parsed
law decode_error_ends_pass:
  for ls: List<&2, D.Line>
  for b: Nat
  for msg: String
  {D.run(ls, b, D.SErr{msg}) == D.DErr{msg} : D.DR}

# S4.202, S4.204, S10.81 once the root value is complete every remaining line is ignored
law decode_root_ends_pass:
  for ls: List<&2, D.Line>
  for b: Nat
  for v: J.Json
  {D.run(ls, b, D.SDone{v}) == D.DOk{v} : D.DR}

# S2.45 the JSON reader's first error is sticky: later bytes cannot change it
law json_error_is_sticky:
  for msg: String
  for el: Nat
  for ec: Nat
  for stack: List<&2, J.Frame>
  for depth: Nat
  for l: Nat
  for c: Nat
  for root: Maybe<&2, J.Json>
  for b: U32
  {J.step(J.St{J.MErr{msg, el, ec}, stack, depth, l, c, root}, b) == J.St{J.MErr{msg, el, ec}, stack, depth, l, c, root} : J.St}

# ---------------------------------------------------------------- modes

# S4.213, S4.215, S4.217 lenient mode never reports a body check (count, blank line, surplus)
law lenient_body_never_fails:
  for short: Bool
  for blank: Nat
  for surplus: Bool
  for tab: Bool
  for n: Nat
  for cnt: Nat
  {D.close.msg(False{}, short, blank, surplus, tab, n, cnt) == None{} : Maybe<&2, String>}

# S2.112 lenient scanning never fails
law lenient_scan_never_fails:
  for tab: Bool
  for num: Nat
  for unit: Nat
  for indent: Nat
  {D.scan.check(None{}, False{}, tab, num, unit, indent) == None{} : Maybe<&2, String>}

# S4.300 (1), S1.155 --encode always selects encode, whatever the extension says
law encode_flag_wins:
  for dec: Bool
  for has_in: Bool
  for e: String
  {C.mode.decode(True{}, dec, has_in, e) == False{} : Bool}

# S4.300 (2) without --encode, --decode always selects decode
law decode_flag_wins:
  for has_in: Bool
  for e: String
  {C.mode.decode(False{}, True{}, has_in, e) == True{} : Bool}

# S4.303 stdin has no extension: without a flag and without an INPUT path the mode is encode
law stdin_defaults_to_encode:
  for e: String
  {C.mode.decode(False{}, False{}, False{}, e) == False{} : Bool}

# S4.314, S5.108 no Saved line when the TOON estimate is not smaller
law no_saved_line_without_savings:
  for j: Nat
  for t: Nat
  {C.stats.saved(False{}, j, t) == SNil{} : String}

# S4.248 no expansion step runs with the depth counter at 256
law expansion_cap_on_values:
  for v: J.Json
  for strict: Bool
  {D.expand(v, D.XVal{0n}, strict) == D.EErr{"Path expansion exceeded maximum depth of 256"} : D.ER}

# S4.248 nor a merge or a literal insertion
law expansion_cap_on_merges:
  for tgt: D.ER
  for src: J.Json
  for strict: Bool
  {D.plan(0n, tgt, src, strict) == D.ACap{} : D.Act}

# ---------------------------------------------------------------- closed goldens

# S7.21 a carry runs through every limb
law bn_add_carry:
  {BN.add([65535, 65535], [1], 0) == [0, 0, 1] : List<&2, U32>}

# S2.107 depth = floor(indent / I), and 0 when I = 0
law depth_of_indent:
  {D.scan.depth(7n, 2n) == 3n : Nat}

# S2.107
law depth_with_indent_zero:
  {D.scan.depth(5n, 0n) == 0n : Nat}

# S4.317 stats_small: the TOON text of the README example estimates to 6 tokens
law stats_estimate_small:
  {C.est("name: Alice\nage: 30\ntags[2]: a,b") == 6n : Nat}

# S4.310 the estimate is never 0
law stats_estimate_empty:
  {C.est("") == 1n : Nat}

# S4.316 a tie goes to the even digit: 6.25 prints as 6.2 (OQ-003)
law stats_pct_6_25:
  {C.percent(1n, 16n) == "6.2" : String}

# S4.316 and 18.75 prints as 18.8
law stats_pct_18_75:
  {C.percent(3n, 16n) == "18.8" : String}

# S4.315 two binary64 operations, not the exact ratio: 23/80 prints 28.7 (exact 28.75 would print 28.8)
law stats_pct_double_rounding:
  {C.percent(23n, 80n) == "28.7" : String}
