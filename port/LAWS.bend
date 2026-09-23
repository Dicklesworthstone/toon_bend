# toon — the laws. HUMAN-OWNED: an agent may add a law, never weaken or delete one. Every law names
# the spec clause it encodes. Kinds:
#   first wins     the first failure, or the finished root value, ends a pass, whatever follows (quantified)
#   mode           a flag decides regardless of every other input (quantified)
#   twin gate      under TOON_SPEC=1 every fast-twin selector is off, for every input (quantified); what
#                  binds a fast twin to its spec twin BEYOND the gate is closed instances only: see the
#                  section "fast == spec (Phase 5)" below, which says why no quantified law exists
#   closed unit    one def on one value: a bound, a rounding, a bucket's balance (the checker computes both sides)
#   closed golden  golden_<case>: a captured golden restated as C.run_pure(argv, bytes) == Out, whole
#                  documents through the JSON reader or the TOON decoder included (they normalize in 1 to 5 s
#                  each since bytes are dispatched on small class codes)
# What does NOT belong here, because the checker does not finish on it: a number that is not a small
# integer through the pipeline (the shortest-digit generator), and digit strings long enough to need a
# large Peano Nat. Those stay in goldens/ and conform.sh.
import Base
import ./bignat.bend as BN
import ./f64.bend as F
import ./text.bend as T
import ./json.bend as J
import ./decode.bend as D
import ./encode.bend as E
import ./cli.bend as C

# ---------------------------------------------------------------- first failure wins

# S1.4 the first report ends the argv scan: a stopped scan ignores every later token
law argv_stop_is_sticky:
  for code: Nat
  for out: String
  for err: String
  for t: C.Tok
  {C.on.tok(C.PStop{code, out, err}, t) == C.PStop{code, out, err} : C.PS}

# S9.141 the first decode failure ends the pass: the lines that remain are never parsed
law decode_error_ends_pass:
  for ls: List<&2, D.Line>
  for b: Nat
  for msg: String
  for strict: Bool
  {D.run(ls, b, D.SErr{msg}, strict) == D.DErr{msg} : D.DR}

# S4.202 in LENIENT mode, once the root value is complete every remaining line is ignored (before the
# owner's order to fix every bug this law held in strict mode too: S10.81, lines after a root array
# vanished silently; strict mode now reports them, decode_trailing_line_is_error)
law decode_root_ends_pass:
  for ls: List<&2, D.Line>
  for b: Nat
  for v: J.Json
  {D.run(ls, b, D.SDone{v, None{}}, False{}) == D.DOk{v} : D.DR}

# S4.202, S9.152 in strict mode a line after the complete root value fails, naming that line
law decode_trailing_line_is_error:
  for num: Nat
  for depth: Nat
  for content: String
  for rest: List<&2, D.Line>
  for b: Nat
  for v: J.Json
  for dup: Maybe<&2, String>
  {D.run(Con{D.Line{num, depth, content}, rest}, b, D.SDone{v, dup}, True{}) == D.DErr{"Validation error at line " ++ Nat.show(num) ++ ": Unexpected content after the document root"} : D.DR}

# S3.26 with every line read, a repeated-key failure noted during the pass is the outcome
law decode_dup_reported_at_end:
  for b: Nat
  for v: J.Json
  for m: String
  for strict: Bool
  {D.run(Nil{}, b, D.SDone{v, Some{m}}, strict) == D.DErr{m} : D.DR}

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
  for spec: Bool
  {J.step(J.St{J.MErr{msg, el, ec}, stack, depth, l, c, root}, b, spec) == J.St{J.MErr{msg, el, ec}, stack, depth, l, c, root} : J.St}

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

# S5.108 equal estimates say so (before the owner's order to fix every bug this law stated that no
# line followed at all, S10.16: a larger TOON form and equal forms were reported by silence)
law no_saved_line_without_savings:
  for j: Nat
  for t: Nat
  {C.stats.third(False{}, False{}, j, t) == "\nNo token difference (0.0%)" : String}

# S4.315 the percentage is rounded on the exact quotient: 23/80 is exactly 28.75, printed 28.8 (the
# binary64 computation printed 28.7, S10.17)
law stats_exact_tie_rounds_up:
  {C.stats.text(80n, 57n) == "\nToken estimates: ~80 (JSON) → ~57 (TOON)\nSaved ~23 tokens (-28.8%)" : String}

# S5.108 a larger TOON form is reported, with the singular noun for one token
law stats_larger_toon_reported:
  {C.stats.text(4n, 5n) == "\nToken estimates: ~4 (JSON) → ~5 (TOON)\nTOON is larger by ~1 token (+25.0%)" : String}

# S4.248 no expansion step runs with the depth counter at 256
law expansion_cap_on_values:
  for v: J.Json
  for strict: Bool
  {D.expand(v, D.XVal{0n}, strict) == D.EErr{"Path expansion exceeded maximum depth of 256"} : D.ER}

# S4.248 nor a merge or a literal insertion
law expansion_cap_on_merges:
  for tgt: D.XR
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

# S4.316 an exact tie rounds half up: 6.25 prints as 6.3 (before the owner's order to fix every bug,
# the binary64 formatting printed 6.2, OQ-003)
law stats_pct_6_25:
  {C.percent(1n, 16n) == "6.3" : String}

# S4.316 and 18.75 prints as 18.8
law stats_pct_18_75:
  {C.percent(3n, 16n) == "18.8" : String}

# S4.315 the exact ratio: 23/80 is 28.75 and prints 28.8 (two binary64 operations printed 28.7, S10.17)
law stats_pct_double_rounding:
  {C.percent(23n, 80n) == "28.8" : String}

# ---------------------------------------------------------------- fast == spec (Phase 5)
#
# TOON_SPEC=1 is read once by the shell and reaches every numeric fast twin as `spec`. The gate laws hold
# for EVERY input. (A law "fast(x, True) == spec(x)" per twin cannot be checked: comparing the two sides
# unfolds bodies that hold 100000-scale Nat literals over abstract arguments, and the checker's stack
# overflows expanding them; the gate keeps the provable part apart.) With the switch off the
# twins are bound by closed instances (both readers and both divisions against their spec twins, compared
# through F.bits; the integer printer against pasted texts, because the spec generator does not normalize
# within any budget: one value ran 25 minutes) and compared natively on generated values and on
# the whole corpus on the compiled lanes with the switch off and on (perf/NEGATIVE-EVIDENCE.md NE-001..003,
# where the three levers stay PROVISIONAL for exactly this reason; scripts/diff-fuzz.py numbers); a universal law for
# them needs the correctness theorems of shortest-digit generation and of limb-wise division, which are
# not attempted.

# S8.2 (EXP-001, EXP-002, EXP-003) with the switch on, NO fast twin is selected, whatever its own
# applicability verdict says: every fast twin is a two-arm match on this gate (F.shortest_fast through
# F.int.fit, F.int_text.ok, F.div_p10, F.from_dec_p10), and the other arm is its spec twin
law twin_gate_switch:
  for ok: Bool
  {F.twin.on(True{}, ok) == False{} : Bool}

# S8.2 with the switch off the gate is the twin's own verdict
law twin_gate_open:
  for ok: Bool
  {F.twin.on(False{}, ok) == ok : Bool}

# S4.131 (EXP-001) the integer twin prints an integer's own digits: 1500 is 1500 (trailing zeros return as layout)
law show_toon_fast_1500:
  {F.show_toon_fast(F.from_nat(1500n), False{}) == "1500" : String}

# S4.170 (EXP-001) and the JSON layout adds .0
law show_json_fast_1500:
  {F.show_json_fast(F.from_nat(1500n), False{}) == "1500" : String}

# S4.131 (EXP-001) one digit
law show_toon_fast_one:
  {F.show_toon_fast(F.from_nat(1n), False{}) == "1" : String}

# S4.101 (EXP-002) the short-integer twin of the JSON number reader equals the literal path. Restated on
# J.num.value when the reader moved to the correctly rounded token path (owner's fix order, 2026-09-22):
# the non-round-trip serde path the law used to name no longer exists
law serde_short_42:
  {J.num.bits(J.num.value(J.Num{1n, False{}, "24", "", False{}, 0n, False{}}, False{})) == J.num.bits(J.num.value(J.Num{1n, False{}, "24", "", False{}, 0n, False{}}, True{})) : String}

# S4.118 (EXP-002) a negative zero keeps the literal path in both settings (restated as above)
law serde_short_zero:
  {J.num.bits(J.num.value(J.Num{1n, True{}, "0", "", False{}, 0n, False{}}, False{})) == J.num.bits(J.num.value(J.Num{1n, True{}, "0", "", False{}, 0n, False{}}, True{})) : String}

# S4.143 (EXP-002) the short-integer twin of the token reader equals the literal path
law token_short_42:
  {F.bits.opt(F.token_value(False{}, "42", "", F.Pos{0n}, False{})) == F.bits.opt(F.token_value(False{}, "42", "", F.Pos{0n}, True{})) : String}

# S4.143 (EXP-002) with a sign
law token_short_neg7:
  {F.bits.opt(F.token_value(True{}, "7", "", F.Pos{0n}, False{})) == F.bits.opt(F.token_value(True{}, "7", "", F.Pos{0n}, True{})) : String}

# S4.114 (EXP-003) 37 / 10 by short division equals the one IEEE division by the table entry
law div_p10_37_1:
  {F.bits(F.div_p10(F.from_nat(37n), 1n, False{})) == F.bits(F.div_p10(F.from_nat(37n), 1n, True{})) : String}

# S4.114 (EXP-003) five factors of ten
law div_p10_k5:
  {F.bits(F.div_p10(F.from_nat(123457n), 5n, False{})) == F.bits(F.div_p10(F.from_nat(123457n), 5n, True{})) : String}

# S4.114 (EXP-003) more than one single-limb division
law div_p10_k7:
  {F.bits(F.div_p10(F.from_nat(3n), 7n, False{})) == F.bits(F.div_p10(F.from_nat(3n), 7n, True{})) : String}

# S4.143 (EXP-003) 37e-1 through the short division equals from_dec
law from_dec_p10_37:
  {F.bits(F.from_dec_p10(True{}, False{}, [37], 1n, False{})) == F.bits(F.from_dec(True{}, False{}, [37], 1n)) : String}

# S4.143 (EXP-003) a 20-digit significand times 10^-30, negative
law from_dec_p10_k30:
  {F.bits(F.from_dec_p10(True{}, True{}, [2770, 60191, 43404, 43860], 30n, False{})) == F.bits(F.from_dec(True{}, True{}, [2770, 60191, 43404, 43860], 30n)) : String}

# S4.101, S4.114 (EXP-003) the whole JSON number path on 3.7: fast twins and spec twins give the same value
# (restated on J.num.value, as serde_short_42)
law serde_decimal_3_7:
  {J.num.bits(J.num.value(J.Num{1n, False{}, "3", "7", False{}, 0n, False{}}, False{})) == J.num.bits(J.num.value(J.Num{1n, False{}, "3", "7", False{}, 0n, False{}}, True{})) : String}

# S4.143 (EXP-003) the whole token path on 3.7
law token_decimal_3_7:
  {F.bits.opt(F.token_value(False{}, "3", "7", F.Pos{0n}, False{})) == F.bits.opt(F.token_value(False{}, "3", "7", F.Pos{0n}, True{})) : String}

# S7.21 (EXP-003) the short division equals the restoring division
law div_pow10_a20_k0:
  {BN.div_pow10([2770, 60191, 43404, 43860], 0n) == BN.div_pow10.spec([2770, 60191, 43404, 43860], 0n) : BN.P5}

# S7.21 (EXP-003) the short division equals the restoring division
law div_pow10_a20_k1:
  {BN.div_pow10([2770, 60191, 43404, 43860], 1n) == BN.div_pow10.spec([2770, 60191, 43404, 43860], 1n) : BN.P5}

# S7.21 (EXP-003) the short division equals the restoring division
law div_pow10_a20_k5:
  {BN.div_pow10([2770, 60191, 43404, 43860], 5n) == BN.div_pow10.spec([2770, 60191, 43404, 43860], 5n) : BN.P5}

# S7.21 (EXP-003) the short division equals the restoring division
law div_pow10_a20_k6:
  {BN.div_pow10([2770, 60191, 43404, 43860], 6n) == BN.div_pow10.spec([2770, 60191, 43404, 43860], 6n) : BN.P5}

# S7.21 (EXP-003) the short division equals the restoring division
law div_pow10_a20_k7:
  {BN.div_pow10([2770, 60191, 43404, 43860], 7n) == BN.div_pow10.spec([2770, 60191, 43404, 43860], 7n) : BN.P5}

# S7.21 (EXP-003) the short division equals the restoring division
law div_pow10_a20_k12:
  {BN.div_pow10([2770, 60191, 43404, 43860], 12n) == BN.div_pow10.spec([2770, 60191, 43404, 43860], 12n) : BN.P5}

# S7.21 (EXP-003) the short division equals the restoring division
law div_pow10_a20_k19:
  {BN.div_pow10([2770, 60191, 43404, 43860], 19n) == BN.div_pow10.spec([2770, 60191, 43404, 43860], 19n) : BN.P5}

# S7.21 (EXP-003) the short division equals the restoring division
law div_pow10_a20_k22:
  {BN.div_pow10([2770, 60191, 43404, 43860], 22n) == BN.div_pow10.spec([2770, 60191, 43404, 43860], 22n) : BN.P5}

# S7.21 (EXP-003) the short division equals the restoring division
law div_pow10_a20_k23:
  {BN.div_pow10([2770, 60191, 43404, 43860], 23n) == BN.div_pow10.spec([2770, 60191, 43404, 43860], 23n) : BN.P5}

# S7.21 (EXP-003) the short division equals the restoring division
law div_pow10_multiple_k7:
  {BN.div_pow10([50048, 457], 7n) == BN.div_pow10.spec([50048, 457], 7n) : BN.P5}

# S7.21 (EXP-003) the short division equals the restoring division
law div_pow10_below_multiple_k7:
  {BN.div_pow10([50047, 457], 7n) == BN.div_pow10.spec([50047, 457], 7n) : BN.P5}

# S7.21 (EXP-003) the short division equals the restoring division
law div_pow10_one_k1:
  {BN.div_pow10([1], 1n) == BN.div_pow10.spec([1], 1n) : BN.P5}

# S7.21 (EXP-003) the short division equals the restoring division
law div_pow10_zero_k3:
  {BN.div_pow10(Nil{}, 3n) == BN.div_pow10.spec(Nil{}, 3n) : BN.P5}

# ---------------------------------------------------------------- carriers and the cap (closed)

# S6.10 the key hash is FNV-1a over the scalar values: the published 32-bit test value of "hello"
law key_hash_fnv1a:
  {T.key_hash("hello") == 1335831723 : U32}

# S6.10 a key put into the set is in it
law kt_member:
  {T.kt.has(T.kt.put(T.kt.put(T.kt.empty(), "a"), "b.c"), "b.c") == True{} : Bool}

# S6.10 and a key never put is not
law kt_not_member:
  {T.kt.has(T.kt.put(T.kt.put(T.kt.empty(), "a"), "b.c"), "b") == False{} : Bool}

# S6.42 (captured from the original) expanded keys keep the position of their FIRST insertion: `a` stays before `m` although `a.c` comes after it
law expand_order_first_insertion:
  {C.run_pure(["--decode", "--expand-paths", "safe", "--indent", "0"], T.ascii_bytes("z: x\na.b: p\nm: q\na.c: r\n", Nil{})) == C.Out{0n, "{\"z\":\"x\",\"a\":{\"b\":\"p\",\"c\":\"r\"},\"m\":\"q\"}\n", ""} : C.Out}

# S4.248 (toonerr_expand_segments_254) the cap is 256, not just "some fuel": a root key of 254 segments is rejected
law expand_cap_is_256_reject:
  {D.decode_expanded("k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k: x\n", True{}, 2n, False{}) == D.DErr{"Path expansion exceeded maximum depth of 256"} : D.DR}

# S4.231, S9.155 (toonedge_expand_segments_253) 253 segments pass the 256 cap but nest past the decoder's
# limit of 127. Replaces expand_cap_is_256_accept, which said they were accepted (the owner's fix order,
# 2026-09-22: expansion is held to the same nesting limit as the decoder)
law expand_segments_253_hits_nesting_cap:
  {D.decode_expanded("k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k: x\n", True{}, 2n, False{}) == D.DErr{"Nesting depth exceeds 127 levels after path expansion"} : D.DR}

# S4.231, S9.155 127 segments nest exactly to the limit and are accepted ...
law expand_depth_127_accept:
  {D.dr.ok(D.decode_expanded("k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k: x\n", True{}, 2n, False{})) == True{} : Bool}

# S4.231, S9.155 ... and 128 are one level too deep
law expand_depth_128_reject:
  {D.decode_expanded("k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k: x\n", True{}, 2n, False{}) == D.DErr{"Nesting depth exceeds 127 levels after path expansion"} : D.DR}

# S4.231, S9.155 the former expand_cap_is_256_accept, its input verbatim and its verdict reversed
law expand_segments_253_not_ok:
  {D.dr.ok(D.decode_expanded("k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k: x\n", True{}, 2n, False{})) == False{} : Bool}

# S2.2 a UTF-8-encoded surrogate (ED A0 80, the CESU-8 form of U+D800) is NOT valid UTF-8 and the input
# gate rejects it. Round 13 (R13-9) mutated the surrogate test out of `utf8.cont` and the whole proof still
# checked: no law pinned it, only the corpus (`jsonerr_utf8_surrogate`).
law utf8_rejects_surrogate:
  {T.utf8.finish(T.utf8.bytes([237, 160, 128], T.utf8.init())) == None{} : Maybe<&2, String>}

# S2.2 and the same three-byte shape one scalar below the surrogate block (ED 9F BF = U+D7FF) IS valid:
# the law above must not be satisfiable by refusing every three-byte sequence.
law utf8_accepts_below_surrogate:
  {T.utf8.finish(T.utf8.bytes([237, 159, 191], T.utf8.init())) == Some{SCon{Chr{55295}, SNil{}}} : Maybe<&2, String>}

# S5.63 the one JSON writer (plain --decode and --expand-paths alike; before the owner's order to fix
# every bug, --expand-paths used a second table that escaped DEL, C-3) writes DEL raw. Round 13 (R13-9)
# mutated the escape table and the whole proof still checked.
# Renamed from writer_b_escapes_del when its verdict was reversed.
law writer_b_keeps_del_raw:
  {J.w.chars(SCon{Chr{127}, SNil{}}, SNil{}) == SCon{Chr{127}, SNil{}} : String}

# S5.63 and the C1 block raw too (U+0085). Renamed from writer_b_escapes_c1 when its verdict was reversed.
law writer_b_keeps_c1_raw:
  {J.w.chars(SCon{Chr{133}, SNil{}}, SNil{}) == SCon{Chr{133}, SNil{}} : String}

# S5.63 U+0008 and U+000C have the short escapes \b and \f, U+0001 is \u0001 (the accumulator is
# built in reverse, so the expected strings read backwards)
law writer_a_keeps_del_raw:
  {J.w.chars(SCon{Chr{8}, SCon{Chr{12}, SCon{Chr{1}, SNil{}}}}, SNil{}) == "1000u\\f\\b\\" : String}

# S4.12-S4.16 a TAB inside a value forces quotes (and is written as the escape \t). Round 13 (R13-9)
# mutated TAB out of `bad_char` and the whole proof still checked: only the corpus caught it.
law tab_in_value_forces_quotes:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"a\":\"x\\ty\"}", Nil{})) == C.Out{0n, "a: \"x\\ty\"\n", ""} : C.Out}

# Round 14 (R14-1) wrote five mutants in five defs no existing mutant touched; each SURVIVED the whole
# 374-law proof while breaking captured cases, so each behaviour below was golden-tested only. One law
# per mutation; where a mutation moves a boundary, both of its sides are pinned.

# S4.12-S4.16 a CR inside a value forces quotes (the CR arm of `bad_char`; the TAB arm is M26's law above).
# Expected output captured from the pinned original: `a: "x\ry"`.
law cr_in_value_forces_quotes:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"a\":\"x\\ry\"}", Nil{})) == C.Out{0n, "a: \"x\\ry\"\n", ""} : C.Out}

# S4.302 the extension lowercaser folds the WHOLE range A..Z, so an upper-case `.TOON` path is the TOON
# extension (the result is reversed onto the accumulator, hence "noot")
law lower_rev_folds_upper_toon:
  {C.lower.rev("TOON", SNil{}) == "noot" : String}

# S1.74 clap's similarity threshold is the binary64 literal 0.7, bit for bit
law seven_tenths_is_0_7:
  {F.bits(C.seven_tenths()) == F.bits(F.from_dec(True{}, False{}, [7], 1n)) : String}

# S4.8 U+1680 OGHAM SPACE MARK is White_Space ...
law is_ws_ogham_space_mark:
  {T.is_ws(5760) == True{} : Bool}

# S4.8 ... and the code point after it, U+1681, is not
law is_ws_not_after_ogham:
  {T.is_ws(5761) == False{} : Bool}

# S4.173 the JSON writer is PLAIN at decimal exponent k = 16 (the old zmij boundary, still plain) ...
law json_plain_at_k16:
  {F.json.is_plain(F.Pos{16n}) == True{} : Bool}

# S4.173 ... and up to k = 21, JavaScript's Number::toString boundary. Replaces json_exponent_at_k17
# (the owner's fix order, 2026-09-22: the JSON writer moved from zmij's 1e16 switch to JavaScript's)
law json_plain_at_k21:
  {F.json.is_plain(F.Pos{21n}) == True{} : Bool}

# S4.173 ... and switches to an exponent at k = 22
law json_exponent_at_k22:
  {F.json.is_plain(F.Pos{22n}) == False{} : Bool}

# S4.173 below one, plain down to k = -5 (0.000001) ...
law json_plain_at_kneg5:
  {F.json.is_plain(F.Neg{5n}) == True{} : Bool}

# S4.173 ... and an exponent from k = -6 (1e-7)
law json_exponent_at_kneg6:
  {F.json.is_plain(F.Neg{6n}) == False{} : Bool}

# S4.8 the WHOLE White_Space table, all 25 members. Round 14 pinned one entry (U+1680); an author-side
# hunt before round 15 then showed U+3000 and U+00A0 each SURVIVED the full 381-law proof, so the table
# is pinned whole rather than one entry at a time.
law is_ws_all_25_members:
  {Bool.and(T.is_ws(9), Bool.and(T.is_ws(10), Bool.and(T.is_ws(11), Bool.and(T.is_ws(12), Bool.and(T.is_ws(13), Bool.and(T.is_ws(32), Bool.and(T.is_ws(133), Bool.and(T.is_ws(160), Bool.and(T.is_ws(5760), Bool.and(T.is_ws(8192), Bool.and(T.is_ws(8193), Bool.and(T.is_ws(8194), Bool.and(T.is_ws(8195), Bool.and(T.is_ws(8196), Bool.and(T.is_ws(8197), Bool.and(T.is_ws(8198), Bool.and(T.is_ws(8199), Bool.and(T.is_ws(8200), Bool.and(T.is_ws(8201), Bool.and(T.is_ws(8202), Bool.and(T.is_ws(8232), Bool.and(T.is_ws(8233), Bool.and(T.is_ws(8239), Bool.and(T.is_ws(8287), T.is_ws(12288))))))))))))))))))))))))) == True{} : Bool}

# S4.8 ... and none of 27 SAMPLED non-members: the spec's explicit exclusions (U+001C-U+001F, U+180E,
# U+200B-U+200D, U+2060, U+FEFF) plus both neighbours of every range and singleton, so each boundary of the
# table is pinned. This is a SAMPLE, not "nothing else": a closed law cannot range over all 1114112 code
# points, so a port that added some other point (round 15's W2 added U+1234) passes it. That point is held
# by the corpus instead (encstr_non_whitespace_u1234_bare). This comment said "NOTHING else" until round 15.
law is_ws_documented_non_members:
  {Bool.and(Bool.not(T.is_ws(8)), Bool.and(Bool.not(T.is_ws(14)), Bool.and(Bool.not(T.is_ws(28)), Bool.and(Bool.not(T.is_ws(29)), Bool.and(Bool.not(T.is_ws(30)), Bool.and(Bool.not(T.is_ws(31)), Bool.and(Bool.not(T.is_ws(33)), Bool.and(Bool.not(T.is_ws(132)), Bool.and(Bool.not(T.is_ws(134)), Bool.and(Bool.not(T.is_ws(159)), Bool.and(Bool.not(T.is_ws(161)), Bool.and(Bool.not(T.is_ws(5759)), Bool.and(Bool.not(T.is_ws(5761)), Bool.and(Bool.not(T.is_ws(6158)), Bool.and(Bool.not(T.is_ws(8191)), Bool.and(Bool.not(T.is_ws(8203)), Bool.and(Bool.not(T.is_ws(8204)), Bool.and(Bool.not(T.is_ws(8205)), Bool.and(Bool.not(T.is_ws(8231)), Bool.and(Bool.not(T.is_ws(8234)), Bool.and(Bool.not(T.is_ws(8238)), Bool.and(Bool.not(T.is_ws(8240)), Bool.and(Bool.not(T.is_ws(8286)), Bool.and(Bool.not(T.is_ws(8288)), Bool.and(Bool.not(T.is_ws(12287)), Bool.and(Bool.not(T.is_ws(12289)), Bool.not(T.is_ws(65279)))))))))))))))))))))))))))) == True{} : Bool}

# ---------------------------------------------------------------- closed goldens of the WHOLE pure core
#
# Each law below is one case of goldens/cases.tsv, pasted from its captured files: argv, the input
# bytes, and the original's exit code, stdout and stderr (without the final LF that the shell's stderr
# write appends). Both sides are computed by the checker's normalizer, a fifth executor beside the four
# lanes, through C.run_pure: argv parser, UTF-8 gate, JSON reader or TOON scanner and decoder, encoder
# or JSON writer, error texts. Selection: ASCII input of at most 110 bytes, no input file, no -o, no
# --stats, and no number on the path (the software binary64 carries 100000-biased exponents, which the
# normalizer holds in unary: those cases stay with conform.sh). Law names are golden_<case name>.

# S5.112 goldens/usage_none
law golden_usage_none:
  {C.run_pure([], T.ascii_bytes("", Nil{})) == C.Out{1n, "", "Failed to parse JSON: EOF while parsing a value at line 1 column 0"} : C.Out}

# S5.112 goldens/usage_version
law golden_usage_version:
  {C.run_pure(["--version"], T.ascii_bytes("", Nil{})) == C.Out{0n, "toon 0.2.4\n", ""} : C.Out}

# S5.112 goldens/usage_version_short
law golden_usage_version_short:
  {C.run_pure(["-V"], T.ascii_bytes("", Nil{})) == C.Out{0n, "toon 0.2.4\n", ""} : C.Out}

# S5.112 goldens/usage_unknown_short
law golden_usage_unknown_short:
  {C.run_pure(["-x"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected argument '-x' found\n\n  tip: to pass '-x' as a value, use '-- -x'\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_conflict_encode_decode
law golden_usage_conflict_encode_decode:
  {C.run_pure(["-e", "-d"], T.ascii_bytes("{\"name\":\"Alice\",\"age\":30,\"tags\":[\"a\",\"b\"]}\n", Nil{})) == C.Out{2n, "", "error: the argument '--encode' cannot be used with '--decode'\n\nUsage: toon --encode [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_conflict_decode_encode
law golden_usage_conflict_decode_encode:
  {C.run_pure(["--decode", "--encode"], T.ascii_bytes("{\"name\":\"Alice\",\"age\":30,\"tags\":[\"a\",\"b\"]}\n", Nil{})) == C.Out{2n, "", "error: the argument '--decode' cannot be used with '--encode'\n\nUsage: toon --decode [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_encode_twice
law golden_usage_encode_twice:
  {C.run_pure(["-e", "-e"], T.ascii_bytes("{\"name\":\"Alice\",\"age\":30,\"tags\":[\"a\",\"b\"]}\n", Nil{})) == C.Out{2n, "", "error: the argument '--encode' cannot be used multiple times\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_missing_value_delimiter
law golden_usage_missing_value_delimiter:
  {C.run_pure(["--delimiter"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: a value is required for '--delimiter <DELIMITER>' but none was supplied\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_missing_value_indent
law golden_usage_missing_value_indent:
  {C.run_pure(["--indent"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: a value is required for '--indent <INDENT>' but none was supplied\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_bad_indent_negative
law golden_usage_bad_indent_negative:
  {C.run_pure(["--encode", "--indent=-1"], T.ascii_bytes("{\"name\":\"Alice\",\"age\":30,\"tags\":[\"a\",\"b\"]}\n", Nil{})) == C.Out{2n, "", "error: invalid value '-1' for '--indent <INDENT>': -1 is not in 0..=16\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_bad_flatten_depth_neg
law golden_usage_bad_flatten_depth_neg:
  {C.run_pure(["--encode", "--flatten-depth=-1"], T.ascii_bytes("{\"name\":\"Alice\",\"age\":30,\"tags\":[\"a\",\"b\"]}\n", Nil{})) == C.Out{2n, "", "error: invalid value '-1' for '--flatten-depth <N>': invalid digit found in string\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/flag_delimiter_equals_pipe
law golden_flag_delimiter_equals_pipe:
  {C.run_pure(["--encode", "--delimiter=|"], T.ascii_bytes("{\"t\":[\"a\",\"b\"]}\n", Nil{})) == C.Out{0n, "t[2|]: a|b\n", ""} : C.Out}

# S5.112 goldens/encstr_root_string
law golden_encstr_root_string:
  {C.run_pure(["--encode"], T.ascii_bytes("\"hello world\"\n", Nil{})) == C.Out{0n, "hello world\n", ""} : C.Out}

# S5.112 goldens/encstr_root_string_quoted
law golden_encstr_root_string_quoted:
  {C.run_pure(["--encode"], T.ascii_bytes("\"true\"\n", Nil{})) == C.Out{0n, "\"true\"\n", ""} : C.Out}

# S5.112 goldens/encstr_root_empty_string
law golden_encstr_root_empty_string:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\"\n", Nil{})) == C.Out{0n, "\"\"\n", ""} : C.Out}

# S5.112 goldens/encstr_root_null
law golden_encstr_root_null:
  {C.run_pure(["--encode"], T.ascii_bytes("null\n", Nil{})) == C.Out{0n, "null\n", ""} : C.Out}

# S5.112 goldens/encstr_root_bool
law golden_encstr_root_bool:
  {C.run_pure(["--encode"], T.ascii_bytes("false\n", Nil{})) == C.Out{0n, "false\n", ""} : C.Out}

# S5.112 goldens/decstr_empty_doc
law golden_decstr_empty_doc:
  {C.run_pure(["--decode"], T.ascii_bytes("", Nil{})) == C.Out{0n, "{}\n", ""} : C.Out}

# S5.112 goldens/decstr_blank_doc
law golden_decstr_blank_doc:
  {C.run_pure(["--decode"], T.ascii_bytes("\n\n  \n", Nil{})) == C.Out{0n, "{}\n", ""} : C.Out}

# S5.112 goldens/decstr_root_string
law golden_decstr_root_string:
  {C.run_pure(["--decode"], T.ascii_bytes("hello world", Nil{})) == C.Out{0n, "\"hello world\"\n", ""} : C.Out}

# S5.112 goldens/decstr_root_quoted
law golden_decstr_root_quoted:
  {C.run_pure(["--decode"], T.ascii_bytes("\"a: b\"", Nil{})) == C.Out{0n, "\"a: b\"\n", ""} : C.Out}

# S5.112 goldens/decstr_root_true
law golden_decstr_root_true:
  {C.run_pure(["--decode"], T.ascii_bytes("true", Nil{})) == C.Out{0n, "true\n", ""} : C.Out}

# S5.112 goldens/decstr_root_null
law golden_decstr_root_null:
  {C.run_pure(["--decode"], T.ascii_bytes("null", Nil{})) == C.Out{0n, "null\n", ""} : C.Out}

# S5.112 goldens/decstr_two_primitives
law golden_decstr_two_primitives:
  {C.run_pure(["--decode"], T.ascii_bytes("hello\nworld\n", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Missing colon after key"} : C.Out}

# S5.112 goldens/jsonout_root_empty_array
law golden_jsonout_root_empty_array:
  {C.run_pure(["--decode"], T.ascii_bytes("[0]:", Nil{})) == C.Out{0n, "[]\n", ""} : C.Out}

# S5.112 goldens/jsonerr_empty
law golden_jsonerr_empty:
  {C.run_pure(["--encode"], T.ascii_bytes("", Nil{})) == C.Out{1n, "", "Failed to parse JSON: EOF while parsing a value at line 1 column 0"} : C.Out}

# S5.112 goldens/jsonerr_whitespace
law golden_jsonerr_whitespace:
  {C.run_pure(["--encode"], T.ascii_bytes("  \n\t\n", Nil{})) == C.Out{1n, "", "Failed to parse JSON: EOF while parsing a value at line 3 column 0"} : C.Out}

# S5.112 goldens/jsonerr_open_brace
law golden_jsonerr_open_brace:
  {C.run_pure(["--encode"], T.ascii_bytes("{", Nil{})) == C.Out{1n, "", "Failed to parse JSON: EOF while parsing an object at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_open_bracket
law golden_jsonerr_open_bracket:
  {C.run_pure(["--encode"], T.ascii_bytes("[", Nil{})) == C.Out{1n, "", "Failed to parse JSON: EOF while parsing a list at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_trailing_comma_arr
law golden_jsonerr_trailing_comma_arr:
  {C.run_pure(["--encode"], T.ascii_bytes("[1,]", Nil{})) == C.Out{1n, "", "Failed to parse JSON: trailing comma at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_missing_value
law golden_jsonerr_missing_value:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"invalid\": }", Nil{})) == C.Out{1n, "", "Failed to parse JSON: expected value at line 1 column 13"} : C.Out}

# S5.112 goldens/jsonerr_single_quotes
law golden_jsonerr_single_quotes:
  {C.run_pure(["--encode"], T.ascii_bytes("'a'", Nil{})) == C.Out{1n, "", "Failed to parse JSON: expected value at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_bad_true
law golden_jsonerr_bad_true:
  {C.run_pure(["--encode"], T.ascii_bytes("tru", Nil{})) == C.Out{1n, "", "Failed to parse JSON: EOF while parsing a value at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_bad_null
law golden_jsonerr_bad_null:
  {C.run_pure(["--encode"], T.ascii_bytes("nul", Nil{})) == C.Out{1n, "", "Failed to parse JSON: EOF while parsing a value at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_bad_ident
law golden_jsonerr_bad_ident:
  {C.run_pure(["--encode"], T.ascii_bytes("nope", Nil{})) == C.Out{1n, "", "Failed to parse JSON: expected ident at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_dot_end
law golden_jsonerr_dot_end:
  {C.run_pure(["--encode"], T.ascii_bytes("1.", Nil{})) == C.Out{1n, "", "Failed to parse JSON: EOF while parsing a value at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_dot_start
law golden_jsonerr_dot_start:
  {C.run_pure(["--encode"], T.ascii_bytes(".5", Nil{})) == C.Out{1n, "", "Failed to parse JSON: expected value at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_lone_minus
law golden_jsonerr_lone_minus:
  {C.run_pure(["--encode"], T.ascii_bytes("-", Nil{})) == C.Out{1n, "", "Failed to parse JSON: EOF while parsing a value at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_exp_end
law golden_jsonerr_exp_end:
  {C.run_pure(["--encode"], T.ascii_bytes("1e", Nil{})) == C.Out{1n, "", "Failed to parse JSON: EOF while parsing a value at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_plus
law golden_jsonerr_plus:
  {C.run_pure(["--encode"], T.ascii_bytes("+1", Nil{})) == C.Out{1n, "", "Failed to parse JSON: expected value at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_unterminated_string
law golden_jsonerr_unterminated_string:
  {C.run_pure(["--encode"], T.ascii_bytes("\"abc", Nil{})) == C.Out{1n, "", "Failed to parse JSON: EOF while parsing a string at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_bad_escape
law golden_jsonerr_bad_escape:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\x\"", Nil{})) == C.Out{1n, "", "Failed to parse JSON: invalid escape at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_short_hex
law golden_jsonerr_short_hex:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\u12\"", Nil{})) == C.Out{1n, "", "Failed to parse JSON: EOF while parsing a string at line 1 column 6"} : C.Out}

# S5.112 goldens/jsonerr_bad_hex
law golden_jsonerr_bad_hex:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\u12zz\"", Nil{})) == C.Out{1n, "", "Failed to parse JSON: invalid escape at line 1 column 7"} : C.Out}

# S5.112 goldens/jsonerr_lone_high_surrogate
law golden_jsonerr_lone_high_surrogate:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\"", Nil{})) == C.Out{1n, "", "Failed to parse JSON: unexpected end of hex escape at line 1 column 8"} : C.Out}

# S5.112 goldens/jsonerr_high_then_bmp
law golden_jsonerr_high_then_bmp:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\\u0041\"", Nil{})) == C.Out{1n, "", "Failed to parse JSON: lone leading surrogate in hex escape at line 1 column 13"} : C.Out}

# S5.112 goldens/jsonerr_lone_low_surrogate
law golden_jsonerr_lone_low_surrogate:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\udc00\"", Nil{})) == C.Out{1n, "", "Failed to parse JSON: lone leading surrogate in hex escape at line 1 column 7"} : C.Out}

# S5.112 goldens/jsonerr_raw_newline_in_string
law golden_jsonerr_raw_newline_in_string:
  {C.run_pure(["--encode"], T.ascii_bytes("\"a\nb\"", Nil{})) == C.Out{1n, "", "Failed to parse JSON: control character (\\u0000-\\u001F) found while parsing a string at line 2 column 0"} : C.Out}

# S5.112 goldens/jsonerr_raw_tab_in_string
law golden_jsonerr_raw_tab_in_string:
  {C.run_pure(["--encode"], T.ascii_bytes("\"a\tb\"", Nil{})) == C.Out{1n, "", "Failed to parse JSON: control character (\\u0000-\\u001F) found while parsing a string at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_trailing_after_obj
law golden_jsonerr_trailing_after_obj:
  {C.run_pure(["--encode"], T.ascii_bytes("{} x", Nil{})) == C.Out{1n, "", "Failed to parse JSON: trailing characters at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_nan
law golden_jsonerr_nan:
  {C.run_pure(["--encode"], T.ascii_bytes("NaN", Nil{})) == C.Out{1n, "", "Failed to parse JSON: expected value at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_infinity
law golden_jsonerr_infinity:
  {C.run_pure(["--encode"], T.ascii_bytes("Infinity", Nil{})) == C.Out{1n, "", "Failed to parse JSON: expected value at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_eof_after_key
law golden_jsonerr_eof_after_key:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"a\"", Nil{})) == C.Out{1n, "", "Failed to parse JSON: EOF while parsing an object at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_eof_after_colon
law golden_jsonerr_eof_after_colon:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"a\":", Nil{})) == C.Out{1n, "", "Failed to parse JSON: EOF while parsing a value at line 1 column 5"} : C.Out}

# S5.112 goldens/jsonerr_minus_word
law golden_jsonerr_minus_word:
  {C.run_pure(["--encode"], T.ascii_bytes("-x", Nil{})) == C.Out{1n, "", "Failed to parse JSON: invalid number at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_upper_true
law golden_jsonerr_upper_true:
  {C.run_pure(["--encode"], T.ascii_bytes("TRUE", Nil{})) == C.Out{1n, "", "Failed to parse JSON: expected value at line 1 column 1"} : C.Out}

# S5.112 goldens/toonerr_blank_in_list
law golden_toonerr_blank_in_list:
  {C.run_pure(["--decode"], T.ascii_bytes("items[2]:\n  - a\n\n  - b", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Line 3: Blank lines inside list array are not allowed in strict mode"} : C.Out}

# S5.112 goldens/toonerr_extra_list_items
law golden_toonerr_extra_list_items:
  {C.run_pure(["--decode"], T.ascii_bytes("items[1]:\n  - a\n  - b", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Expected 1 list array items, but found more"} : C.Out}

# S5.112 goldens/toonerr_too_few_list_items
law golden_toonerr_too_few_list_items:
  {C.run_pure(["--decode"], T.ascii_bytes("items[3]:\n  - a", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Expected 3 list array items, but got 1"} : C.Out}

# S5.112 goldens/toonerr_too_few_inline
law golden_toonerr_too_few_inline:
  {C.run_pure(["--decode"], T.ascii_bytes("items[3]: a,b", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Expected 3 inline array items, but got 2"} : C.Out}

# S5.112 goldens/toonerr_too_many_inline
law golden_toonerr_too_many_inline:
  {C.run_pure(["--decode"], T.ascii_bytes("items[1]: a,b", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Expected 1 inline array items, but got 2"} : C.Out}

# S5.112 goldens/toonerr_huge_length
law golden_toonerr_huge_length:
  {C.run_pure(["--decode"], T.ascii_bytes("items[9999999999]:", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Declared array length 9999999999 exceeds maximum allowed (100000000)"} : C.Out}

# S5.112 goldens/toonerr_unterminated_value
law golden_toonerr_unterminated_value:
  {C.run_pure(["--decode"], T.ascii_bytes("name: \"unterminated", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Unterminated string: missing closing quote"} : C.Out}

# S5.112 goldens/toonerr_unterminated_key
law golden_toonerr_unterminated_key:
  {C.run_pure(["--decode"], T.ascii_bytes("\"unterminated key: value", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Unterminated string: missing closing quote"} : C.Out}

# S5.112 goldens/toonerr_bad_escape
law golden_toonerr_bad_escape:
  {C.run_pure(["--decode"], T.ascii_bytes("name: \"bad \\x escape\"", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Invalid escape sequence: \\x"} : C.Out}

# S5.112 goldens/toonerr_unicode_escape
law golden_toonerr_unicode_escape:
  {C.run_pure(["--decode"], T.ascii_bytes("name: \"\\u0041\"", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Invalid escape sequence: \\u"} : C.Out}

# S5.112 goldens/toonerr_trailing_backslash
law golden_toonerr_trailing_backslash:
  {C.run_pure(["--decode"], T.ascii_bytes("name: \"abc\\", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Unterminated string: missing closing quote"} : C.Out}

# S5.112 goldens/toonerr_after_closing_quote
law golden_toonerr_after_closing_quote:
  {C.run_pure(["--decode"], T.ascii_bytes("name: \"abc\" def", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Unexpected characters after closing quote"} : C.Out}

# S5.112 goldens/toonerr_tab_indent
law golden_toonerr_tab_indent:
  {C.run_pure(["--decode"], T.ascii_bytes("\tname: value", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Validation error at line 1: Tabs are not allowed in indentation in strict mode"} : C.Out}

# S5.112 goldens/toonerr_tab_indent_list
law golden_toonerr_tab_indent_list:
  {C.run_pure(["--decode"], T.ascii_bytes("items[1]:\n\t- a", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Validation error at line 2: Tabs are not allowed in indentation in strict mode"} : C.Out}

# S5.112 goldens/toonerr_missing_close_bracket
law golden_toonerr_missing_close_bracket:
  {C.run_pure(["--decode"], T.ascii_bytes("items[3: a,b,c", Nil{})) == C.Out{0n, "{\n  \"items[3\": \"a,b,c\"\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_missing_colon_nested
law golden_toonerr_missing_colon_nested:
  {C.run_pure(["--decode"], T.ascii_bytes("o:\n  bare\n", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Missing colon after key"} : C.Out}

# S5.112 goldens/toonerr_inline_bad_quote
law golden_toonerr_inline_bad_quote:
  {C.run_pure(["--decode"], T.ascii_bytes("items[2]: \"a,b", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Unterminated string: missing closing quote"} : C.Out}

# S5.112 goldens/toonerr_list_item_no_space
law golden_toonerr_list_item_no_space:
  {C.run_pure(["--decode"], T.ascii_bytes("items[1]:\n  -a", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Expected 1 list array items, but got 0"} : C.Out}

# S5.112 goldens/toonerr_colon_only
law golden_toonerr_colon_only:
  {C.run_pure(["--decode"], T.ascii_bytes(":\n", Nil{})) == C.Out{0n, "{\n  \"\": {}\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_zero_length_with_items
law golden_toonerr_zero_length_with_items:
  {C.run_pure(["--decode"], T.ascii_bytes("items[0]:\n  - a\n", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Expected 0 list array items, but found more"} : C.Out}

# S5.112 goldens/toonerr_zero_inline_with_values
law golden_toonerr_zero_inline_with_values:
  {C.run_pure(["--decode"], T.ascii_bytes("items[0]: a\n", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Expected 0 inline array items, but got 1"} : C.Out}

# S5.112 goldens/toonerr_header_spaces
law golden_toonerr_header_spaces:
  {C.run_pure(["--decode"], T.ascii_bytes("items [2] : a,b\n", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\",\n    \"b\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_header_key_quoted
law golden_toonerr_header_key_quoted:
  {C.run_pure(["--decode"], T.ascii_bytes("\"my items\"[2]: a,b\n", Nil{})) == C.Out{0n, "{\n  \"my items\": [\n    \"a\",\n    \"b\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_header_brace_after_colon
law golden_toonerr_header_brace_after_colon:
  {C.run_pure(["--decode"], T.ascii_bytes("k[1]: {a}\n", Nil{})) == C.Out{0n, "{\n  \"k\": [\n    \"{a}\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_nested_headers
law golden_toonerr_nested_headers:
  {C.run_pure(["--decode"], T.ascii_bytes("a[1]:\n  - [1]:\n    - [1]: x\n", Nil{})) == C.Out{0n, "{\n  \"a\": [\n    [\n      [\n        \"x\"\n      ]\n    ]\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_mixed_delims
law golden_toonerr_mixed_delims:
  {C.run_pure(["--decode"], T.ascii_bytes("t[2|]: a,b|c\n", Nil{})) == C.Out{0n, "{\n  \"t\": [\n    \"a,b\",\n    \"c\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_list_dash_only
law golden_toonerr_list_dash_only:
  {C.run_pure(["--decode"], T.ascii_bytes("l[2]:\n  -\n  - \n", Nil{})) == C.Out{0n, "{\n  \"l\": [\n    {},\n    {}\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_object_empty_nested
law golden_toonerr_object_empty_nested:
  {C.run_pure(["--decode"], T.ascii_bytes("a:\nb:\n  c:\n", Nil{})) == C.Out{0n, "{\n  \"a\": {},\n  \"b\": {\n    \"c\": {}\n  }\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_value_is_header_like
law golden_toonerr_value_is_header_like:
  {C.run_pure(["--decode"], T.ascii_bytes("a: [2]: x\n", Nil{})) == C.Out{0n, "{\n  \"a\": \"[2]: x\"\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_hyphen_value
law golden_toonerr_hyphen_value:
  {C.run_pure(["--decode"], T.ascii_bytes("a: - b\n", Nil{})) == C.Out{0n, "{\n  \"a\": \"- b\"\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_list_at_root_no_header
law golden_toonerr_list_at_root_no_header:
  {C.run_pure(["--decode"], T.ascii_bytes("- a\n- b\n", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Missing colon after key"} : C.Out}

# S5.112 goldens/toonlenient_blank_in_list
law golden_toonlenient_blank_in_list:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[2]:\n  - a\n\n  - b", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\",\n    \"b\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_extra_list_items
law golden_toonlenient_extra_list_items:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[1]:\n  - a\n  - b", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\",\n    \"b\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_too_few_list_items
law golden_toonlenient_too_few_list_items:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[3]:\n  - a", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_too_few_inline
law golden_toonlenient_too_few_inline:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[3]: a,b", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\",\n    \"b\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_too_many_inline
law golden_toonlenient_too_many_inline:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[1]: a,b", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\",\n    \"b\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_tab_indent
law golden_toonlenient_tab_indent:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("\tname: value", Nil{})) == C.Out{0n, "{\n  \"name\": \"value\"\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_tab_indent_list
law golden_toonlenient_tab_indent_list:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[1]:\n\t- a", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Missing colon after key"} : C.Out}

# S5.112 goldens/toonlenient_zero_length_with_items
law golden_toonlenient_zero_length_with_items:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[0]:\n  - a\n", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_zero_inline_with_values
law golden_toonlenient_zero_inline_with_values:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[0]: a\n", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_bad_escape
law golden_toonlenient_bad_escape:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("name: \"bad \\x escape\"", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Invalid escape sequence: \\x"} : C.Out}

# S5.112 goldens/toonlenient_unterminated_value
law golden_toonlenient_unterminated_value:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("name: \"unterminated", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Unterminated string: missing closing quote"} : C.Out}

# S5.112 goldens/toonlenient_huge_length
law golden_toonlenient_huge_length:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[9999999999]:", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Declared array length 9999999999 exceeds maximum allowed (100000000)"} : C.Out}

# S5.112 goldens/usage_version_first_wins
law golden_usage_version_first_wins:
  {C.run_pure(["--version", "--help"], T.ascii_bytes("", Nil{})) == C.Out{0n, "toon 0.2.4\n", ""} : C.Out}

# S5.112 goldens/usage_cluster_Vh
law golden_usage_cluster_Vh:
  {C.run_pure(["-Vh"], T.ascii_bytes("", Nil{})) == C.Out{0n, "toon 0.2.4\n", ""} : C.Out}

# S5.112 goldens/usage_missing_value_before_flag
law golden_usage_missing_value_before_flag:
  {C.run_pure(["--indent", "--encode"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: a value is required for '--indent <INDENT>' but none was supplied\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_attached_bad_value_first
law golden_usage_attached_bad_value_first:
  {C.run_pure(["--indent=99", "--indent=2"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: invalid value '99' for '--indent <INDENT>': 99 is not in 0..=16\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_attached_twice
law golden_usage_attached_twice:
  {C.run_pure(["--indent=2", "--indent=99"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: the argument '--indent <INDENT>' cannot be used multiple times\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_flag_with_value
law golden_usage_flag_with_value:
  {C.run_pure(["--encode=1"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected value '1' for '--encode' found; no more were expected\n\nUsage: toon --encode [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_help_with_value
law golden_usage_help_with_value:
  {C.run_pure(["--help=x"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected value 'x' for '--help' found; no more were expected\n\nUsage: toon --help [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_flag_with_value_after_commit
law golden_usage_flag_with_value_after_commit:
  {C.run_pure(["-e", "--stats=yes"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected value 'yes' for '--stats' found; no more were expected\n\nUsage: toon <INPUT|--output <FILE>|--encode|--decode|--delimiter <DELIMITER>|--indent <INDENT>|--no-strict|--key-folding <KEY_FOLDING>|--flatten-depth <N>|--expand-paths <EXPAND_PATHS>|--stats>\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_flag_with_value_after_attached
law golden_usage_flag_with_value_after_attached:
  {C.run_pure(["--indent=4", "--stats=yes"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected value 'yes' for '--stats' found; no more were expected\n\nUsage: toon <INPUT|--output <FILE>|--encode|--decode|--delimiter <DELIMITER>|--indent <INDENT>|--no-strict|--key-folding <KEY_FOLDING>|--flatten-depth <N>|--expand-paths <EXPAND_PATHS>|--stats>\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_cluster_conflict
law golden_usage_cluster_conflict:
  {C.run_pure(["-ed"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: the argument '--encode' cannot be used with '--decode'\n\nUsage: toon --encode [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_cluster_unknown_after_flag
law golden_usage_cluster_unknown_after_flag:
  {C.run_pure(["-ex"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected argument '-x' found\n\n  tip: to pass '-x' as a value, use '-- -x'\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_cluster_digit
law golden_usage_cluster_digit:
  {C.run_pure(["-e5"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected argument '-5' found\n\n  tip: to pass '-5' as a value, use '-- -5'\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_cluster_equals
law golden_usage_cluster_equals:
  {C.run_pure(["-e=x"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected argument '-=' found\n\n  tip: to pass '-=' as a value, use '-- -='\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_negative_number_word
law golden_usage_negative_number_word:
  {C.run_pure(["--indent", "-1"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: invalid value '-1' for '--indent <INDENT>': -1 is not in 0..=16\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_negative_cluster_first_char
law golden_usage_negative_cluster_first_char:
  {C.run_pure(["--indent", "-129"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: invalid value '-129' for '--indent <INDENT>': -129 is not in 0..=16\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_unknown_short_uppercase
law golden_usage_unknown_short_uppercase:
  {C.run_pure(["-E"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected argument '-E' found\n\n  tip: to pass '-E' as a value, use '-- -E'\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_encode_short_and_long
law golden_usage_encode_short_and_long:
  {C.run_pure(["-e", "--encode"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: the argument '--encode' cannot be used multiple times\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_indent_i64_underflow
law golden_usage_indent_i64_underflow:
  {C.run_pure(["--indent=-9223372036854775809"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: invalid value '-9223372036854775809' for '--indent <INDENT>': number too small to fit in target type\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/jsonerr_eof_after_comma_arr
law golden_jsonerr_eof_after_comma_arr:
  {C.run_pure(["--encode"], T.ascii_bytes("[1,", Nil{})) == C.Out{1n, "", "Failed to parse JSON: EOF while parsing a value at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_exp_sign_end
law golden_jsonerr_exp_sign_end:
  {C.run_pure(["--encode"], T.ascii_bytes("1e+", Nil{})) == C.Out{1n, "", "Failed to parse JSON: EOF while parsing a value at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_eof_after_backslash
law golden_jsonerr_eof_after_backslash:
  {C.run_pure(["--encode"], T.ascii_bytes("\"abc\\", Nil{})) == C.Out{1n, "", "Failed to parse JSON: EOF while parsing a string at line 1 column 5"} : C.Out}

# S5.112 goldens/jsonerr_eof_after_high_surrogate
law golden_jsonerr_eof_after_high_surrogate:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800", Nil{})) == C.Out{1n, "", "Failed to parse JSON: EOF while parsing a string at line 1 column 7"} : C.Out}

# S5.112 goldens/jsonerr_eof_after_high_surrogate_backslash
law golden_jsonerr_eof_after_high_surrogate_backslash:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\\", Nil{})) == C.Out{1n, "", "Failed to parse JSON: EOF while parsing a string at line 1 column 8"} : C.Out}

# S5.112 goldens/jsonerr_ident_newline
law golden_jsonerr_ident_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("tru\n", Nil{})) == C.Out{1n, "", "Failed to parse JSON: expected ident at line 2 column 0"} : C.Out}

# S5.112 goldens/jsonerr_ident_then_more
law golden_jsonerr_ident_then_more:
  {C.run_pure(["--encode"], T.ascii_bytes("nulll", Nil{})) == C.Out{1n, "", "Failed to parse JSON: trailing characters at line 1 column 5"} : C.Out}

# S5.112 goldens/jsonerr_short_hex_newline
law golden_jsonerr_short_hex_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\u12\"\n", Nil{})) == C.Out{1n, "", "Failed to parse JSON: invalid escape at line 2 column 0"} : C.Out}

# S5.112 goldens/jsonerr_escape_newline
law golden_jsonerr_escape_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\\n\"", Nil{})) == C.Out{1n, "", "Failed to parse JSON: invalid escape at line 2 column 0"} : C.Out}

# S5.112 goldens/jsonerr_escape_upper_u
law golden_jsonerr_escape_upper_u:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\U0041\"", Nil{})) == C.Out{1n, "", "Failed to parse JSON: invalid escape at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_dot_nondigit
law golden_jsonerr_dot_nondigit:
  {C.run_pure(["--encode"], T.ascii_bytes("[1.]", Nil{})) == C.Out{1n, "", "Failed to parse JSON: invalid number at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_dot_newline
law golden_jsonerr_dot_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("1.\n", Nil{})) == C.Out{1n, "", "Failed to parse JSON: invalid number at line 2 column 0"} : C.Out}

# S5.112 goldens/jsonerr_exp_nondigit
law golden_jsonerr_exp_nondigit:
  {C.run_pure(["--encode"], T.ascii_bytes("[1e]", Nil{})) == C.Out{1n, "", "Failed to parse JSON: invalid number at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_exp_double_sign
law golden_jsonerr_exp_double_sign:
  {C.run_pure(["--encode"], T.ascii_bytes("1e+-1", Nil{})) == C.Out{1n, "", "Failed to parse JSON: invalid number at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_minus_infinity
law golden_jsonerr_minus_infinity:
  {C.run_pure(["--encode"], T.ascii_bytes("-Infinity", Nil{})) == C.Out{1n, "", "Failed to parse JSON: invalid number at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_number_then_letter
law golden_jsonerr_number_then_letter:
  {C.run_pure(["--encode"], T.ascii_bytes("[1x]", Nil{})) == C.Out{1n, "", "Failed to parse JSON: expected `,` or `]` at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_hex_number
law golden_jsonerr_hex_number:
  {C.run_pure(["--encode"], T.ascii_bytes("0x10", Nil{})) == C.Out{1n, "", "Failed to parse JSON: trailing characters at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_raw_cr_in_string
law golden_jsonerr_raw_cr_in_string:
  {C.run_pure(["--encode"], T.ascii_bytes("\"a\rb\"", Nil{})) == C.Out{1n, "", "Failed to parse JSON: control character (\\u0000-\\u001F) found while parsing a string at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_obj_leading_comma
law golden_jsonerr_obj_leading_comma:
  {C.run_pure(["--encode"], T.ascii_bytes("{,}", Nil{})) == C.Out{1n, "", "Failed to parse JSON: key must be a string at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_arr_leading_comma
law golden_jsonerr_arr_leading_comma:
  {C.run_pure(["--encode"], T.ascii_bytes("[,]", Nil{})) == C.Out{1n, "", "Failed to parse JSON: expected value at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_arr_comma_then_brace
law golden_jsonerr_arr_comma_then_brace:
  {C.run_pure(["--encode"], T.ascii_bytes("[1,}", Nil{})) == C.Out{1n, "", "Failed to parse JSON: expected value at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_high_then_escape
law golden_jsonerr_high_then_escape:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\\n\"", Nil{})) == C.Out{1n, "", "Failed to parse JSON: unexpected end of hex escape at line 1 column 9"} : C.Out}

# S5.112 goldens/jsonerr_high_then_newline
law golden_jsonerr_high_then_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\n\"", Nil{})) == C.Out{1n, "", "Failed to parse JSON: unexpected end of hex escape at line 2 column 0"} : C.Out}

# S5.112 goldens/jsonerr_high_then_bad_hex
law golden_jsonerr_high_then_bad_hex:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\\uzzzz\"", Nil{})) == C.Out{1n, "", "Failed to parse JSON: invalid escape at line 1 column 13"} : C.Out}

# S5.112 goldens/jsonerr_high_then_high
law golden_jsonerr_high_then_high:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\\ud800\"", Nil{})) == C.Out{1n, "", "Failed to parse JSON: lone leading surrogate in hex escape at line 1 column 13"} : C.Out}

# S5.112 goldens/jsonerr_trailing_comma_newline
law golden_jsonerr_trailing_comma_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("[1,\n]", Nil{})) == C.Out{1n, "", "Failed to parse JSON: trailing comma at line 2 column 1"} : C.Out}

# S5.112 goldens/jsonerr_trailing_close
law golden_jsonerr_trailing_close:
  {C.run_pure(["--encode"], T.ascii_bytes("[]]", Nil{})) == C.Out{1n, "", "Failed to parse JSON: trailing characters at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_cr_not_newline
law golden_jsonerr_cr_not_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("[1,\r\r oops]", Nil{})) == C.Out{1n, "", "Failed to parse JSON: expected value at line 1 column 7"} : C.Out}

# S5.112 goldens/jsonout_empty_in_array
law golden_jsonout_empty_in_array:
  {C.run_pure(["--decode"], T.ascii_bytes("[4]:\n  -\n  - [0]:\n  - [1]:\n    - [0]:\n  - k:\n    l[0]:\n", Nil{})) == C.Out{0n, "[\n  {},\n  [],\n  [\n    []\n  ],\n  {\n    \"k\": {},\n    \"l\": []\n  }\n]\n", ""} : C.Out}

# S5.112 goldens/toonedge_crlf_bare_dash
law golden_toonedge_crlf_bare_dash:
  {C.run_pure(["--decode"], T.ascii_bytes("x[1]:\r\n  -\r\n", Nil{})) == C.Out{0n, "{\n  \"x\": [\n    {}\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonedge_header_key_with_colon
law golden_toonedge_header_key_with_colon:
  {C.run_pure(["--decode"], T.ascii_bytes("a: [1]: x\n", Nil{})) == C.Out{0n, "{\n  \"a\": \"[1]: x\"\n}\n", ""} : C.Out}

# S5.112 goldens/toonedge_header_in_quoted_value
law golden_toonedge_header_in_quoted_value:
  {C.run_pure(["--decode"], T.ascii_bytes("a: \"x[1]: y\"\n", Nil{})) == C.Out{0n, "{\n  \"a\": \"x[1]: y\"\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_cap_in_quoted_value
law golden_toonerr_cap_in_quoted_value:
  {C.run_pure(["--decode"], T.ascii_bytes("note: \"see [999999999999]: x\"\n", Nil{})) == C.Out{0n, "{\n  \"note\": \"see [999999999999]: x\"\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_length_u64_max_list
law golden_toonerr_length_u64_max_list:
  {C.run_pure(["--decode"], T.ascii_bytes("items[18446744073709551615]:\n", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Declared array length 18446744073709551615 exceeds maximum allowed (100000000)"} : C.Out}

# S5.112 goldens/toonedge_root_vs_item_keyvalue
law golden_toonedge_root_vs_item_keyvalue:
  {C.run_pure(["--decode"], T.ascii_bytes("a\"b: c\n", Nil{})) == C.Out{0n, "\"a\\\"b: c\"\n", ""} : C.Out}

# S5.112 goldens/toonedge_item_quote_hides_colon
law golden_toonedge_item_quote_hides_colon:
  {C.run_pure(["--decode"], T.ascii_bytes("l[1]:\n  - a\"b: c\n", Nil{})) == C.Out{0n, "{\n  \"l\": [\n    \"a\\\"b: c\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonedge_list_item_two_spaces_quoted_key
law golden_toonedge_list_item_two_spaces_quoted_key:
  {C.run_pure(["--decode"], T.ascii_bytes("l[1]:\n  -  \"a\": b\n", Nil{})) == C.Out{0n, "{\n  \"l\": [\n    {\n      \"a\": \"b\"\n    }\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_count_beats_blank
law golden_toonerr_count_beats_blank:
  {C.run_pure(["--decode"], T.ascii_bytes("l[3]:\n  - a\n\n  - b\n", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Expected 3 list array items, but got 2"} : C.Out}

# S5.112 goldens/toonerr_extra_bare_dash_undetected
law golden_toonerr_extra_bare_dash_undetected:
  {C.run_pure(["--decode"], T.ascii_bytes("l[1]:\n  - a\n  -\n", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Expected 1 list array items, but found more"} : C.Out}

# S5.112 goldens/toonerr_list_first_field_list_shallow
law golden_toonerr_list_first_field_list_shallow:
  {C.run_pure(["--decode"], T.ascii_bytes("l[1]:\n  - k[2]:\n    - a\n    - b\n", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Expected 2 list array items, but got 0"} : C.Out}

# ---------------------------------------------------------------- closed goldens of the WHOLE pure core, second batch (encoder, folding,
# delimiters, tabular rows, expansion, small numbers through the fast twins): at least one per board row that can carry one

# S5.112 goldens/fx_enc_primitives_01
law golden_fx_enc_primitives_01:
  {C.run_pure(["--encode"], T.ascii_bytes("\"hello\"\n", Nil{})) == C.Out{0n, "hello\n", ""} : C.Out}

# S5.112 goldens/fx_enc_primitives_03
law golden_fx_enc_primitives_03:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\"\n", Nil{})) == C.Out{0n, "\"\"\n", ""} : C.Out}

# S5.112 goldens/fx_enc_primitives_04
law golden_fx_enc_primitives_04:
  {C.run_pure(["--encode"], T.ascii_bytes("\"true\"\n", Nil{})) == C.Out{0n, "\"true\"\n", ""} : C.Out}

# S5.112 goldens/fx_enc_primitives_07
law golden_fx_enc_primitives_07:
  {C.run_pure(["--encode"], T.ascii_bytes("\"42\"\n", Nil{})) == C.Out{0n, "\"42\"\n", ""} : C.Out}

# S5.112 goldens/fx_enc_primitives_09
law golden_fx_enc_primitives_09:
  {C.run_pure(["--encode"], T.ascii_bytes("\"1e-6\"\n", Nil{})) == C.Out{0n, "\"1e-6\"\n", ""} : C.Out}

# S5.112 goldens/fx_enc_primitives_11
law golden_fx_enc_primitives_11:
  {C.run_pure(["--encode"], T.ascii_bytes("\"line1\\nline2\"\n", Nil{})) == C.Out{0n, "\"line1\\nline2\"\n", ""} : C.Out}

# S5.112 goldens/fx_enc_primitives_14
law golden_fx_enc_primitives_14:
  {C.run_pure(["--encode"], T.ascii_bytes("\"C:\\\\Users\\\\path\"\n", Nil{})) == C.Out{0n, "\"C:\\\\Users\\\\path\"\n", ""} : C.Out}

# S5.112 goldens/fx_enc_primitives_16
law golden_fx_enc_primitives_16:
  {C.run_pure(["--encode"], T.ascii_bytes("\"- item\"\n", Nil{})) == C.Out{0n, "\"- item\"\n", ""} : C.Out}

# S5.112 goldens/fx_enc_objects_04
law golden_fx_enc_objects_04:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"note\":\"a:b\"}\n", Nil{})) == C.Out{0n, "note: \"a:b\"\n", ""} : C.Out}

# S5.112 goldens/fx_enc_objects_17
law golden_fx_enc_objects_17:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"full name\":\"Ada\"}\n", Nil{})) == C.Out{0n, "\"full name\": Ada\n", ""} : C.Out}

# S5.112 goldens/fx_enc_objects_20
law golden_fx_enc_objects_20:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"123\":\"x\"}\n", Nil{})) == C.Out{0n, "\"123\": x\n", ""} : C.Out}

# S5.112 goldens/fx_enc_arrays_primitive_01
law golden_fx_enc_arrays_primitive_01:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"tags\":[\"reading\",\"gaming\"]}\n", Nil{})) == C.Out{0n, "tags[2]: reading,gaming\n", ""} : C.Out}

# S5.112 goldens/fx_enc_arrays_primitive_04
law golden_fx_enc_arrays_primitive_04:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"items\":[]}\n", Nil{})) == C.Out{0n, "items[0]:\n", ""} : C.Out}

# S5.112 goldens/fx_enc_arrays_primitive_08
law golden_fx_enc_arrays_primitive_08:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"items\":[\"a\",\"b,c\",\"d:e\"]}\n", Nil{})) == C.Out{0n, "items[3]: a,\"b,c\",\"d:e\"\n", ""} : C.Out}

# S5.112 goldens/fx_enc_arrays_nested_01
law golden_fx_enc_arrays_nested_01:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"pairs\":[[\"a\",\"b\"],[\"c\",\"d\"]]}\n", Nil{})) == C.Out{0n, "pairs[2]:\n  - [2]: a,b\n  - [2]: c,d\n", ""} : C.Out}

# S5.112 goldens/fx_enc_arrays_nested_03
law golden_fx_enc_arrays_nested_03:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"pairs\":[[],[]]}\n", Nil{})) == C.Out{0n, "pairs[2]:\n  - [0]:\n  - [0]:\n", ""} : C.Out}

# S5.112 goldens/fx_enc_arrays_tabular_02
law golden_fx_enc_arrays_tabular_02:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"items\":[{\"id\":1,\"value\":null},{\"id\":2,\"value\":\"test\"}]}\n", Nil{})) == C.Out{0n, "items[2]{id,value}:\n  1,null\n  2,test\n", ""} : C.Out}

# S5.112 goldens/fx_enc_arrays_tabular_03
law golden_fx_enc_arrays_tabular_03:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"items\":[{\"sku\":\"A,1\",\"desc\":\"cool\",\"qty\":2},{\"sku\":\"B2\",\"desc\":\"wip: test\",\"qty\":1}]}\n", Nil{})) == C.Out{0n, "items[2]{sku,desc,qty}:\n  \"A,1\",cool,2\n  B2,\"wip: test\",1\n", ""} : C.Out}

# S5.112 goldens/fx_enc_arrays_objects_15
law golden_fx_enc_arrays_objects_15:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"items\":[{\"a\":1,\"b\":2,\"c\":3},{\"c\":30,\"b\":20,\"a\":10}]}\n", Nil{})) == C.Out{0n, "items[2]{a,b,c}:\n  1,2,3\n  10,20,30\n", ""} : C.Out}

# S5.112 goldens/fx_enc_arrays_objects_02
law golden_fx_enc_arrays_objects_02:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"items\":[{\"id\":1,\"nested\":{\"x\":1}}]}\n", Nil{})) == C.Out{0n, "items[1]:\n  - id: 1\n    nested:\n      x: 1\n", ""} : C.Out}

# S5.112 goldens/fx_enc_arrays_objects_10
law golden_fx_enc_arrays_objects_10:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"items\":[{\"name\":\"Ada\",\"data\":[]}]}\n", Nil{})) == C.Out{0n, "items[1]:\n  - name: Ada\n    data[0]:\n", ""} : C.Out}

# S5.112 goldens/fx_enc_arrays_objects_13
law golden_fx_enc_arrays_objects_13:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"items\":[{\"data\":[],\"name\":\"x\"}]}\n", Nil{})) == C.Out{0n, "items[1]:\n  - data[0]:\n    name: x\n", ""} : C.Out}

# S5.112 goldens/fx_enc_arrays_objects_14
law golden_fx_enc_arrays_objects_14:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"items\":[\"first\",\"second\",{}]}\n", Nil{})) == C.Out{0n, "items[3]:\n  - first\n  - second\n  -\n", ""} : C.Out}

# S5.112 goldens/fx_enc_objects_03
law golden_fx_enc_objects_03:
  {C.run_pure(["--encode"], T.ascii_bytes("{}\n", Nil{})) == C.Out{0n, "\n", ""} : C.Out}

# S5.112 goldens/fx_enc_objects_25
law golden_fx_enc_objects_25:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"a\":{\"b\":{\"c\":\"deep\"}}}\n", Nil{})) == C.Out{0n, "a:\n  b:\n    c: deep\n", ""} : C.Out}

# S5.112 goldens/fx_enc_arrays_nested_10
law golden_fx_enc_arrays_nested_10:
  {C.run_pure(["--encode"], T.ascii_bytes("[]\n", Nil{})) == C.Out{0n, "[0]:\n", ""} : C.Out}

# S5.112 goldens/flag_indent_0_encode
law golden_flag_indent_0_encode:
  {C.run_pure(["--encode", "--indent", "0"], T.ascii_bytes("{\"a\":{\"b\":1},\"l\":[{\"x\":1},{\"y\":2}]}\n", Nil{})) == C.Out{1n, "", "Indentation size must be at least 1 when encoding TOON"} : C.Out}

# S5.112 goldens/flag_indent_16_encode
law golden_flag_indent_16_encode:
  {C.run_pure(["--encode", "--indent", "16"], T.ascii_bytes("{\"a\":{\"b\":1}}\n", Nil{})) == C.Out{0n, "a:\n                b: 1\n", ""} : C.Out}

# S5.112 goldens/fx_enc_whitespace_01
law golden_fx_enc_whitespace_01:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"id\":123}\n", Nil{})) == C.Out{0n, "id: 123\n", ""} : C.Out}

# S5.112 goldens/fx_enc_delimiters_01
law golden_fx_enc_delimiters_01:
  {C.run_pure(["--encode", "--delimiter", "\t"], T.ascii_bytes("{\"tags\":[\"reading\",\"gaming\",\"coding\"]}\n", Nil{})) == C.Out{0n, "tags[3\t]: reading\tgaming\tcoding\n", ""} : C.Out}

# S5.112 goldens/fx_enc_delimiters_02
law golden_fx_enc_delimiters_02:
  {C.run_pure(["--encode", "--delimiter", "|"], T.ascii_bytes("{\"tags\":[\"reading\",\"gaming\",\"coding\"]}\n", Nil{})) == C.Out{0n, "tags[3|]: reading|gaming|coding\n", ""} : C.Out}

# S5.112 goldens/fx_enc_delimiters_06
law golden_fx_enc_delimiters_06:
  {C.run_pure(["--encode", "--delimiter", "\t"], T.ascii_bytes("{\"pairs\":[[\"a\",\"b\"],[\"c\",\"d\"]]}\n", Nil{})) == C.Out{0n, "pairs[2\t]:\n  - [2\t]: a\tb\n  - [2\t]: c\td\n", ""} : C.Out}

# S5.112 goldens/fx_enc_delimiters_10
law golden_fx_enc_delimiters_10:
  {C.run_pure(["--encode", "--delimiter", "\t"], T.ascii_bytes("[{\"id\":1},{\"id\":2}]\n", Nil{})) == C.Out{0n, "[2\t]{id}:\n  1\n  2\n", ""} : C.Out}

# S5.112 goldens/fx_enc_delimiters_16
law golden_fx_enc_delimiters_16:
  {C.run_pure(["--encode", "--delimiter", ","], T.ascii_bytes("{\"items\":[{\"id\":1,\"note\":\"a,b\"},{\"id\":2,\"note\":\"c,d\"}]}\n", Nil{})) == C.Out{0n, "items[2]{id,note}:\n  1,\"a,b\"\n  2,\"c,d\"\n", ""} : C.Out}

# S5.112 goldens/fx_enc_delimiters_20
law golden_fx_enc_delimiters_20:
  {C.run_pure(["--encode", "--delimiter", "|"], T.ascii_bytes("{\"pairs\":[[\"a\",\"b|c\"]]}\n", Nil{})) == C.Out{0n, "pairs[1|]:\n  - [2|]: a|\"b|c\"\n", ""} : C.Out}

# S5.112 goldens/fx_enc_key_folding_01
law golden_fx_enc_key_folding_01:
  {C.run_pure(["--encode", "--key-folding", "safe"], T.ascii_bytes("{\"a\":{\"b\":{\"c\":1}}}\n", Nil{})) == C.Out{0n, "a.b.c: 1\n", ""} : C.Out}

# S5.112 goldens/fx_enc_key_folding_03
law golden_fx_enc_key_folding_03:
  {C.run_pure(["--encode", "--key-folding", "safe"], T.ascii_bytes("{\"a\":{\"b\":{\"items\":[{\"id\":1,\"name\":\"A\"},{\"id\":2,\"name\":\"B\"}]}}}\n", Nil{})) == C.Out{0n, "a.b.items[2]{id,name}:\n  1,A\n  2,B\n", ""} : C.Out}

# S5.112 goldens/fx_enc_key_folding_05
law golden_fx_enc_key_folding_05:
  {C.run_pure(["--encode", "--key-folding", "safe"], T.ascii_bytes("{\"data\":{\"meta\":{\"items\":[1,2]}},\"data.meta.items\":\"literal\"}\n", Nil{})) == C.Out{0n, "data:\n  meta:\n    items[2]: 1,2\ndata.meta.items: literal\n", ""} : C.Out}

# S5.112 goldens/fx_enc_key_folding_08
law golden_fx_enc_key_folding_08:
  {C.run_pure(["--encode", "--key-folding", "safe", "--flatten-depth", "0"], T.ascii_bytes("{\"a\":{\"b\":{\"c\":1}}}\n", Nil{})) == C.Out{0n, "a:\n  b:\n    c: 1\n", ""} : C.Out}

# S5.112 goldens/fx_enc_key_folding_12
law golden_fx_enc_key_folding_12:
  {C.run_pure(["--encode", "--key-folding", "safe"], T.ascii_bytes("{\"a\":{\"b\":[1,2]}}\n", Nil{})) == C.Out{0n, "a.b[2]: 1,2\n", ""} : C.Out}

# S5.112 goldens/fx_enc_key_folding_13
law golden_fx_enc_key_folding_13:
  {C.run_pure(["--encode", "--key-folding", "safe"], T.ascii_bytes("{\"first\":{\"second\":{\"third\":1}},\"simple\":2,\"short\":{\"path\":3}}\n", Nil{})) == C.Out{0n, "first.second.third: 1\nsimple: 2\nshort.path: 3\n", ""} : C.Out}

# S5.112 goldens/enc_folding_collision
law golden_enc_folding_collision:
  {C.run_pure(["--encode", "--key-folding", "safe"], T.ascii_bytes("{\"a\": {\"b\": 1}, \"a.b\": 2, \"c\": {\"d\": {\"e\": 1}}, \"c.d\": {\"e\": 2}}\n", Nil{})) == C.Out{0n, "a:\n  b: 1\na.b: 2\nc.d.e: 1\nc.d:\n  e: 2\n", ""} : C.Out}

# S5.112 goldens/enc_fold_root_literal_nested
law golden_enc_fold_root_literal_nested:
  {C.run_pure(["--encode", "--key-folding", "safe"], T.ascii_bytes("{\"x\": {\"a\": {\"b\": 1}, \"c\": 2}, \"x.a.b\": 3}\n", Nil{})) == C.Out{0n, "x:\n  a:\n    b: 1\n  c: 2\nx.a.b: 3\n", ""} : C.Out}

# S5.112 goldens/enc_fold_budget_threading_5
law golden_enc_fold_budget_threading_5:
  {C.run_pure(["--encode", "--key-folding", "safe", "--flatten-depth", "5"], T.ascii_bytes("{\"a\": {\"b\": {\"x\": {\"y\": {\"z\": {\"w\": 1}}}, \"k\": 1}}}\n", Nil{})) == C.Out{0n, "a.b:\n  x.y.z:\n    w: 1\n  k: 1\n", ""} : C.Out}

# S5.112 goldens/enc_fold_list_item_dup_key
law golden_enc_fold_list_item_dup_key:
  {C.run_pure(["--encode", "--key-folding", "safe"], T.ascii_bytes("[{\"c.d\": 7, \"c\": {\"d\": 1}}]\n", Nil{})) == C.Out{0n, "[1]:\n  - c.d: 7\n    c:\n      d: 1\n", ""} : C.Out}

# S5.112 goldens/flag_flatten_depth_3
law golden_flag_flatten_depth_3:
  {C.run_pure(["--encode", "--key-folding", "safe", "--flatten-depth", "3"], T.ascii_bytes("{\"a\":{\"b\":{\"c\":{\"d\":{\"e\":1}}}}}\n", Nil{})) == C.Out{0n, "a.b.c:\n  d:\n    e: 1\n", ""} : C.Out}

# S5.112 goldens/fx_dec_indentation_errors_01
law golden_fx_dec_indentation_errors_01:
  {C.run_pure(["--decode", "--indent", "2"], T.ascii_bytes("a:\n   b: 1", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Validation error at line 2: Indentation must be exact multiple of 2, but found 3 spaces"} : C.Out}

# S5.112 goldens/fx_dec_indentation_errors_04
law golden_fx_dec_indentation_errors_04:
  {C.run_pure(["--decode", "--indent", "4"], T.ascii_bytes("a:\n    b: 1", Nil{})) == C.Out{0n, "{\n    \"a\": {\n        \"b\": 1\n    }\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_indentation_errors_08
law golden_fx_dec_indentation_errors_08:
  {C.run_pure(["--decode"], T.ascii_bytes("text: \"hello\tworld\"", Nil{})) == C.Out{0n, "{\n  \"text\": \"hello\\tworld\"\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_indentation_errors_13
law golden_fx_dec_indentation_errors_13:
  {C.run_pure(["--decode"], T.ascii_bytes("a: 1\n\nb: 2", Nil{})) == C.Out{0n, "{\n  \"a\": 1,\n  \"b\": 2\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_blank_lines_01
law golden_fx_dec_blank_lines_01:
  {C.run_pure(["--decode"], T.ascii_bytes("items[3]:\n  - a\n\n  - b\n  - c", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Line 3: Blank lines inside list array are not allowed in strict mode"} : C.Out}

# S5.112 goldens/toonedge_indent4
law golden_toonedge_indent4:
  {C.run_pure(["--decode", "--indent", "4"], T.ascii_bytes("a:\n    b:\n        c: 1\n", Nil{})) == C.Out{0n, "{\n    \"a\": {\n        \"b\": {\n            \"c\": 1\n        }\n    }\n}\n", ""} : C.Out}

# S5.112 goldens/toonedge_indent0_flat
law golden_toonedge_indent0_flat:
  {C.run_pure(["--decode", "--indent", "0"], T.ascii_bytes("a: 1\nb: 2\n", Nil{})) == C.Out{0n, "{\"a\":1,\"b\":2}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_indent_not_multiple
law golden_toonlenient_indent_not_multiple:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("outer:\n a: 1", Nil{})) == C.Out{0n, "{\n  \"outer\": {},\n  \"a\": 1\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_primitives_01
law golden_fx_dec_primitives_01:
  {C.run_pure(["--decode"], T.ascii_bytes("hello", Nil{})) == C.Out{0n, "\"hello\"\n", ""} : C.Out}

# S5.112 goldens/fx_dec_primitives_04
law golden_fx_dec_primitives_04:
  {C.run_pure(["--decode"], T.ascii_bytes("\"line1\\nline2\"", Nil{})) == C.Out{0n, "\"line1\\nline2\"\n", ""} : C.Out}

# S5.112 goldens/fx_dec_primitives_08
law golden_fx_dec_primitives_08:
  {C.run_pure(["--decode"], T.ascii_bytes("\"say \\\"hello\\\"\"", Nil{})) == C.Out{0n, "\"say \\\"hello\\\"\"\n", ""} : C.Out}

# S5.112 goldens/fx_dec_primitives_19
law golden_fx_dec_primitives_19:
  {C.run_pure(["--decode"], T.ascii_bytes("\"true\"", Nil{})) == C.Out{0n, "\"true\"\n", ""} : C.Out}

# S5.112 goldens/fx_dec_primitives_22
law golden_fx_dec_primitives_22:
  {C.run_pure(["--decode"], T.ascii_bytes("\"42\"", Nil{})) == C.Out{0n, "\"42\"\n", ""} : C.Out}

# S5.112 goldens/fx_dec_objects_04
law golden_fx_dec_objects_04:
  {C.run_pure(["--decode"], T.ascii_bytes("note: \"a:b\"", Nil{})) == C.Out{0n, "{\n  \"note\": \"a:b\"\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_objects_17
law golden_fx_dec_objects_17:
  {C.run_pure(["--decode"], T.ascii_bytes("\"full name\": Ada", Nil{})) == C.Out{0n, "{\n  \"full name\": \"Ada\"\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_whitespace_01
law golden_fx_dec_whitespace_01:
  {C.run_pure(["--decode"], T.ascii_bytes("tags[3]: a , b , c", Nil{})) == C.Out{0n, "{\n  \"tags\": [\n    \"a\",\n    \"b\",\n    \"c\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_whitespace_06
law golden_fx_dec_whitespace_06:
  {C.run_pure(["--decode"], T.ascii_bytes("items[3]: a,,c", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\",\n    \"\",\n    \"c\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonedge_header_in_value_first_bracket_only
law golden_toonedge_header_in_value_first_bracket_only:
  {C.run_pure(["--decode"], T.ascii_bytes("a: \"[abc] [1]: y\"\nb: \"x[1] y\"\nc: \"x[1\\t]: y\"\nd: \"x[1]{p:q}\"\n", Nil{})) == C.Out{0n, "{\n  \"a\": \"[abc] [1]: y\",\n  \"b\": \"x[1] y\",\n  \"c\": \"x[1\\t]: y\",\n  \"d\": \"x[1]{p:q}\"\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_delimiters_01
law golden_fx_dec_delimiters_01:
  {C.run_pure(["--decode"], T.ascii_bytes("tags[3\t]: reading\tgaming\tcoding", Nil{})) == C.Out{0n, "{\n  \"tags\": [\n    \"reading\",\n    \"gaming\",\n    \"coding\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_delimiters_02
law golden_fx_dec_delimiters_02:
  {C.run_pure(["--decode"], T.ascii_bytes("tags[3|]: reading|gaming|coding", Nil{})) == C.Out{0n, "{\n  \"tags\": [\n    \"reading\",\n    \"gaming\",\n    \"coding\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_delimiters_16
law golden_fx_dec_delimiters_16:
  {C.run_pure(["--decode"], T.ascii_bytes("items[2\t]: a,b\tc,d", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a,b\",\n    \"c,d\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_delimiters_21
law golden_fx_dec_delimiters_21:
  {C.run_pure(["--decode"], T.ascii_bytes("items[2\t]:\n  - status: a,b\n  - status: c,d", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    {\n      \"status\": \"a,b\"\n    },\n    {\n      \"status\": \"c,d\"\n    }\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonedge_length_plus_and_zero
law golden_toonedge_length_plus_and_zero:
  {C.run_pure(["--decode"], T.ascii_bytes("a[+2]: x,y\nb[02]: x,y\nc[ 2]: x,y\n", Nil{})) == C.Out{0n, "{\n  \"a[+2]\": \"x,y\",\n  \"b\": [\n    \"x\",\n    \"y\"\n  ],\n  \"c[ 2]\": \"x,y\"\n}\n", ""} : C.Out}

# S5.112 goldens/toonedge_fields_space_only
law golden_toonedge_fields_space_only:
  {C.run_pure(["--decode"], T.ascii_bytes("items[1]{ }:\n  - 1\n", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Empty field list in array header"} : C.Out}

# S5.112 goldens/fx_dec_numbers_02
law golden_fx_dec_numbers_02:
  {C.run_pure(["--decode"], T.ascii_bytes("value: -1E+03", Nil{})) == C.Out{0n, "{\n  \"value\": -1000\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_numbers_03
law golden_fx_dec_numbers_03:
  {C.run_pure(["--decode"], T.ascii_bytes("value: 2.5e2", Nil{})) == C.Out{0n, "{\n  \"value\": 250\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_numbers_05
law golden_fx_dec_numbers_05:
  {C.run_pure(["--decode"], T.ascii_bytes("value: -0", Nil{})) == C.Out{0n, "{\n  \"value\": 0\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_numbers_10
law golden_fx_dec_numbers_10:
  {C.run_pure(["--decode"], T.ascii_bytes("value: 5E+00", Nil{})) == C.Out{0n, "{\n  \"value\": 5\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_numbers_16
law golden_fx_dec_numbers_16:
  {C.run_pure(["--decode"], T.ascii_bytes("05", Nil{})) == C.Out{0n, "\"05\"\n", ""} : C.Out}

# S5.112 goldens/fx_dec_numbers_20
law golden_fx_dec_numbers_20:
  {C.run_pure(["--decode"], T.ascii_bytes("nums[3]: 05,007,0123", Nil{})) == C.Out{0n, "{\n  \"nums\": [\n    \"05\",\n    \"007\",\n    \"0123\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_arrays_nested_02
law golden_fx_dec_arrays_nested_02:
  {C.run_pure(["--decode"], T.ascii_bytes("items[3]:\n  - first\n  - second\n  -", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"first\",\n    \"second\",\n    {}\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_arrays_nested_07
law golden_fx_dec_arrays_nested_07:
  {C.run_pure(["--decode"], T.ascii_bytes("items[1]:\n  - name: Ada\n    data[0]:", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    {\n      \"name\": \"Ada\",\n      \"data\": []\n    }\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_arrays_nested_09
law golden_fx_dec_arrays_nested_09:
  {C.run_pure(["--decode"], T.ascii_bytes("pairs[2]:\n  - [2]: a,b\n  - [2]: c,d", Nil{})) == C.Out{0n, "{\n  \"pairs\": [\n    [\n      \"a\",\n      \"b\"\n    ],\n    [\n      \"c\",\n      \"d\"\n    ]\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_objects_03
law golden_fx_dec_objects_03:
  {C.run_pure(["--decode"], T.ascii_bytes("user:", Nil{})) == C.Out{0n, "{\n  \"user\": {}\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_objects_22
law golden_fx_dec_objects_22:
  {C.run_pure(["--decode"], T.ascii_bytes("user.name: Ada", Nil{})) == C.Out{0n, "{\n  \"user.name\": \"Ada\"\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_objects_28
law golden_fx_dec_objects_28:
  {C.run_pure(["--decode"], T.ascii_bytes("a:\n  b:\n    c: deep", Nil{})) == C.Out{0n, "{\n  \"a\": {\n    \"b\": {\n      \"c\": \"deep\"\n    }\n  }\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_root_form_01
law golden_fx_dec_root_form_01:
  {C.run_pure(["--decode"], T.ascii_bytes("", Nil{})) == C.Out{0n, "{}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_arrays_tabular_02
law golden_fx_dec_arrays_tabular_02:
  {C.run_pure(["--decode"], T.ascii_bytes("items[2]{id,value}:\n  1,null\n  2,\"test\"", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    {\n      \"id\": 1,\n      \"value\": null\n    },\n    {\n      \"id\": 2,\n      \"value\": \"test\"\n    }\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_arrays_tabular_03
law golden_fx_dec_arrays_tabular_03:
  {C.run_pure(["--decode"], T.ascii_bytes("items[2]{id,note}:\n  1,\"a:b\"\n  2,\"c:d\"", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    {\n      \"id\": 1,\n      \"note\": \"a:b\"\n    },\n    {\n      \"id\": 2,\n      \"note\": \"c:d\"\n    }\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonedge_data_row_test
law golden_toonedge_data_row_test:
  {C.run_pure(["--decode"], T.ascii_bytes("t[1]{a,b}:\n  1,2\n  x: 4,5\n", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Validation error at line 3: Over-indented line: expected depth 0, but found 1"} : C.Out}

# S5.112 goldens/fx_dec_blank_lines_05
law golden_fx_dec_blank_lines_05:
  {C.run_pure(["--decode"], T.ascii_bytes("outer[2]:\n  - inner[2]:\n    - a\n\n    - b\n  - x", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Expected 2 list array items, but got 0"} : C.Out}

# S5.112 goldens/fx_dec_blank_lines_11
law golden_fx_dec_blank_lines_11:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[3]:\n  - a\n\n  - b\n  - c", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\",\n    \"b\",\n    \"c\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_validation_errors_01
law golden_fx_dec_validation_errors_01:
  {C.run_pure(["--decode"], T.ascii_bytes("tags[2]: a,b,c", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Expected 2 inline array items, but got 3"} : C.Out}

# S5.112 goldens/toonlenient_row_width_short
law golden_toonlenient_row_width_short:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("rows[1]{a,b,c}:\n  1,2", Nil{})) == C.Out{0n, "{\n  \"rows\": [\n    {\n      \"a\": 1,\n      \"b\": 2,\n      \"c\": null\n    }\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_extra_tabular_rows
law golden_toonlenient_extra_tabular_rows:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("rows[1]{id}:\n  1\n  2", Nil{})) == C.Out{0n, "{\n  \"rows\": [\n    {\n      \"id\": 1\n    },\n    {\n      \"id\": 2\n    }\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_blank_in_tabular
law golden_toonlenient_blank_in_tabular:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("rows[2]{id}:\n  1\n\n  2", Nil{})) == C.Out{0n, "{\n  \"rows\": [\n    {\n      \"id\": 1\n    },\n    {\n      \"id\": 2\n    }\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_path_expansion_01
law golden_fx_dec_path_expansion_01:
  {C.run_pure(["--decode", "--expand-paths", "safe"], T.ascii_bytes("a.b.c: 1", Nil{})) == C.Out{0n, "{\n  \"a\": {\n    \"b\": {\n      \"c\": 1\n    }\n  }\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_path_expansion_03
law golden_fx_dec_path_expansion_03:
  {C.run_pure(["--decode", "--expand-paths", "safe"], T.ascii_bytes("a.b.items[2]{id,name}:\n  1,A\n  2,B", Nil{})) == C.Out{0n, "{\n  \"a\": {\n    \"b\": {\n      \"items\": [\n        {\n          \"id\": 1,\n          \"name\": \"A\"\n        },\n        {\n          \"id\": 2,\n          \"name\": \"B\"\n        }\n      ]\n    }\n  }\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_path_expansion_05
law golden_fx_dec_path_expansion_05:
  {C.run_pure(["--decode", "--expand-paths", "safe"], T.ascii_bytes("a.b.c: 1\na.b.d: 2\na.e: 3", Nil{})) == C.Out{0n, "{\n  \"a\": {\n    \"b\": {\n      \"c\": 1,\n      \"d\": 2\n    },\n    \"e\": 3\n  }\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_path_expansion_08
law golden_fx_dec_path_expansion_08:
  {C.run_pure(["--decode", "--expand-paths", "safe", "--no-strict"], T.ascii_bytes("a.b: 1\na: 2", Nil{})) == C.Out{0n, "{\n  \"a\": 2\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_path_expansion_10
law golden_fx_dec_path_expansion_10:
  {C.run_pure(["--decode", "--expand-paths", "safe"], T.ascii_bytes("a.b: 1\n\"c.d\": 2", Nil{})) == C.Out{0n, "{\n  \"a\": {\n    \"b\": 1\n  },\n  \"c.d\": 2\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_path_expansion_11
law golden_fx_dec_path_expansion_11:
  {C.run_pure(["--decode", "--expand-paths", "safe"], T.ascii_bytes("full-name.x: 1", Nil{})) == C.Out{0n, "{\n  \"full-name.x\": 1\n}\n", ""} : C.Out}

# S5.112 goldens/toonedge_expand_quoted_unquoted_same_key
law golden_toonedge_expand_quoted_unquoted_same_key:
  {C.run_pure(["--decode", "--expand-paths", "safe"], T.ascii_bytes("\"a.b\": 1\na.b: 2\n", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Duplicate sibling key \"a.b\""} : C.Out}

# S5.112 goldens/decnum_root_negative_zero
law golden_decnum_root_negative_zero:
  {C.run_pure(["--decode"], T.ascii_bytes("-0", Nil{})) == C.Out{0n, "0\n", ""} : C.Out}

# S5.112 goldens/fx_dec_numbers_06
law golden_fx_dec_numbers_06:
  {C.run_pure(["--decode"], T.ascii_bytes("value: -0.0", Nil{})) == C.Out{0n, "{\n  \"value\": 0\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_numbers_08
law golden_fx_dec_numbers_08:
  {C.run_pure(["--decode"], T.ascii_bytes("value: 05", Nil{})) == C.Out{0n, "{\n  \"value\": \"05\"\n}\n", ""} : C.Out}

# S5.112 goldens/jsonout_root_array
law golden_jsonout_root_array:
  {C.run_pure(["--decode"], T.ascii_bytes("[3]: 1,two,true", Nil{})) == C.Out{0n, "[\n  1,\n  \"two\",\n  true\n]\n", ""} : C.Out}

# S5.112 goldens/jsonout_duplicate_keys
law golden_jsonout_duplicate_keys:
  {C.run_pure(["--decode"], T.ascii_bytes("a: 1\na: 2\nb: 3\n", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Duplicate sibling key \"a\""} : C.Out}

# S5.112 goldens/flag_decode_indent_0
law golden_flag_decode_indent_0:
  {C.run_pure(["-d", "--indent", "0"], T.ascii_bytes("a: 1\nb[2]: 1,2\n", Nil{})) == C.Out{0n, "{\"a\":1,\"b\":[1,2]}\n", ""} : C.Out}

# S5.112 goldens/flag_decode_indent_4
law golden_flag_decode_indent_4:
  {C.run_pure(["-d", "--indent", "4"], T.ascii_bytes("a:\n    b: 1\n", Nil{})) == C.Out{0n, "{\n    \"a\": {\n        \"b\": 1\n    }\n}\n", ""} : C.Out}

# S5.112 goldens/encnum_root_negative_zero
law golden_encnum_root_negative_zero:
  {C.run_pure(["--encode"], T.ascii_bytes("-0.0\n", Nil{})) == C.Out{0n, "0\n", ""} : C.Out}

# S5.112 goldens/encnum_overflow_positive
law golden_encnum_overflow_positive:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"a\":1e309}\n", Nil{})) == C.Out{1n, "", "Failed to parse JSON: number out of range at line 1 column 10"} : C.Out}

# S5.112 goldens/encnum_overflow_negative
law golden_encnum_overflow_negative:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"a\":-1e309}\n", Nil{})) == C.Out{1n, "", "Failed to parse JSON: number out of range at line 1 column 11"} : C.Out}

# S5.112 goldens/fx_enc_arrays_objects_01
law golden_fx_enc_arrays_objects_01:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"items\":[{\"id\":1,\"name\":\"First\"},{\"id\":2,\"name\":\"Second\",\"extra\":true}]}\n", Nil{})) == C.Out{0n, "items[2]:\n  - id: 1\n    name: First\n  - id: 2\n    name: Second\n    extra: true\n", ""} : C.Out}

# S5.112 goldens/happy_readme_users
law golden_happy_readme_users:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"users\":[{\"id\":1,\"name\":\"Alice\"},{\"id\":2,\"name\":\"Bob\"}]}\n", Nil{})) == C.Out{0n, "users[2]{id,name}:\n  1,Alice\n  2,Bob\n", ""} : C.Out}

# S5.112 goldens/happy_readme_users_decode
law golden_happy_readme_users_decode:
  {C.run_pure(["--decode"], T.ascii_bytes("users[2]{id,name}:\n  1,Alice\n  2,Bob\n", Nil{})) == C.Out{0n, "{\n  \"users\": [\n    {\n      \"id\": 1,\n      \"name\": \"Alice\"\n    },\n    {\n      \"id\": 2,\n      \"name\": \"Bob\"\n    }\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/flag_delimiter_word_pipe
law golden_flag_delimiter_word_pipe:
  {C.run_pure(["--encode", "--delimiter", "pipe"], T.ascii_bytes("{\"t\":[\"a\",\"b\"]}\n", Nil{})) == C.Out{0n, "t[2|]: a|b\n", ""} : C.Out}

# S5.112 goldens/flag_delimiter_backslash_t
law golden_flag_delimiter_backslash_t:
  {C.run_pure(["--encode", "--delimiter", "\\t"], T.ascii_bytes("{\"t\":[\"a\",\"b\"]}\n", Nil{})) == C.Out{0n, "t[2\t]: a\tb\n", ""} : C.Out}

# S5.112 goldens/flag_short_combined_e
law golden_flag_short_combined_e:
  {C.run_pure(["-e"], T.ascii_bytes("{\"name\":\"Alice\",\"age\":30,\"tags\":[\"a\",\"b\"]}\n", Nil{})) == C.Out{0n, "name: Alice\nage: 30\ntags[2]: a,b\n", ""} : C.Out}

# S5.112 goldens/flag_indent_equals
law golden_flag_indent_equals:
  {C.run_pure(["--encode", "--indent=4"], T.ascii_bytes("{\"a\":{\"b\":1}}\n", Nil{})) == C.Out{0n, "a:\n    b: 1\n", ""} : C.Out}

# S5.112 goldens/flag_double_dash_only
law golden_flag_double_dash_only:
  {C.run_pure(["--"], T.ascii_bytes("{\"name\":\"Alice\",\"age\":30,\"tags\":[\"a\",\"b\"]}\n", Nil{})) == C.Out{0n, "name: Alice\nage: 30\ntags[2]: a,b\n", ""} : C.Out}

# S5.112 goldens/flag_no_strict_on_encode_ignored
law golden_flag_no_strict_on_encode_ignored:
  {C.run_pure(["--encode", "--no-strict"], T.ascii_bytes("{\"name\":\"Alice\",\"age\":30,\"tags\":[\"a\",\"b\"]}\n", Nil{})) == C.Out{0n, "name: Alice\nage: 30\ntags[2]: a,b\n", ""} : C.Out}

# S5.112 goldens/flag_stdin_dash
law golden_flag_stdin_dash:
  {C.run_pure(["-e", "-"], T.ascii_bytes("{\"name\":\"Alice\",\"age\":30,\"tags\":[\"a\",\"b\"]}\n", Nil{})) == C.Out{0n, "name: Alice\nage: 30\ntags[2]: a,b\n", ""} : C.Out}

# S5.112 goldens/flag_stdin_dash_decode
law golden_flag_stdin_dash_decode:
  {C.run_pure(["-d", "-"], T.ascii_bytes("name: Alice\nage: 30\ntags[2]: a,b\n", Nil{})) == C.Out{0n, "{\n  \"name\": \"Alice\",\n  \"age\": 30,\n  \"tags\": [\n    \"a\",\n    \"b\"\n  ]\n}\n", ""} : C.Out}

# ---------------------------------------------------------------- strict UTF-8 on raw byte lists (closed)

# S2.100 goldens/jsonerr_invalid_utf8_stdin: the bytes 7b 22 61 22 3a 22 ff fe 22 7d 0a
law golden_jsonerr_invalid_utf8_stdin:
  {C.run_pure(["--encode"], [123, 34, 97, 34, 58, 34, 255, 254, 34, 125, 10]) == C.Out{1n, "", "Failed to read stdin: stream did not contain valid UTF-8"} : C.Out}

# S2.100 goldens/toonerr_invalid_utf8_stdin: the bytes 61 3a 20 ff 0a
law golden_toonerr_invalid_utf8_stdin:
  {C.run_pure(["--decode"], [97, 58, 32, 255, 10]) == C.Out{1n, "", "Failed to read stdin: stream did not contain valid UTF-8"} : C.Out}

# S2.100 goldens/jsonerr_overlong_utf8: the bytes 22 c0 af 22 0a (an overlong form is invalid)
law golden_jsonerr_overlong_utf8:
  {C.run_pure(["--encode"], [34, 192, 175, 34, 10]) == C.Out{1n, "", "Failed to read stdin: stream did not contain valid UTF-8"} : C.Out}

# S2.100 goldens/jsonerr_truncated_utf8: the bytes 7b 22 61 22 3a 22 e2 82 22 7d (a sequence cut short)
law golden_jsonerr_truncated_utf8:
  {C.run_pure(["--encode"], [123, 34, 97, 34, 58, 34, 226, 130, 34, 125]) == C.Out{1n, "", "Failed to read stdin: stream did not contain valid UTF-8"} : C.Out}

# ---------------------------------------------------------------- bounds the mutation test found unpinned (closed): each of these
# kills a hand-written mutant that every earlier law let live (scratch driver hand_mutants.py, 2026-09-20)

# S7.21 (EXP-003) a multiple of 2^k that is not a multiple of 5^k: only the single-limb remainder can set the sticky flag
law div_pow10_even_not_multiple_k1:
  {BN.div_pow10([4], 1n) == BN.div_pow10.spec([4], 1n) : BN.P5}

# S7.21 (EXP-003) 30000128 = 2^7 * 234376 leaves no shifted-out bit and a remainder of 1 under 5^7
law div_pow10_pow2_multiple_k7:
  {BN.div_pow10([50176, 457], 7n) == BN.div_pow10.spec([50176, 457], 7n) : BN.P5}

# S7.21 (EXP-003) and the flag itself, not only the agreement of the twins
law div_pow10_sticky_from_remainder:
  {BN.div_pow10([4], 1n) == BN.P5{Nil{}, True{}} : BN.P5}

# S4.131 (EXP-001) a lost bit means the value is not an integer: 3 shifted right by one bit
law int_fit_refuses_lost_bit:
  {F.int.fit.q(BN.shr([3], 1n)) == F.IntFit{False{}, [1]} : F.IntFit}

# S4.131 (EXP-001) the integer path ends below 2^48 (Nat's largest immediate on the compiled lanes): 2^48 - 1 fits
law int_fit_accepts_2p48_minus_1:
  {F.int.fit.q(([65535, 65535, 65535], False{})) == F.IntFit{True{}, [65535, 65535, 65535]} : F.IntFit}

# S4.131 (EXP-001) and 2^48 does not
law int_fit_refuses_2p48:
  {F.int.fit.q(([0, 0, 0, 1], False{})) == F.IntFit{False{}, [0, 0, 0, 1]} : F.IntFit}

# S4.101 (EXP-002) a 14-digit integer text takes the Nat path
law int_text_14_digits_ok:
  {F.int_text.ok(False{}, "99999999999999", "", F.Pos{0n}) == True{} : Bool}

# S4.101 (EXP-002) a 15-digit text does not (281474976710656 = 2^48 is past Nat's largest immediate)
law int_text_15_digits_refused:
  {F.int_text.ok(False{}, "281474976710656", "", F.Pos{0n}) == False{} : Bool}

# S4.101 (EXP-002) a fraction or an exponent keeps the literal path
law int_text_fraction_refused:
  {F.int_text.ok(False{}, "42", "5", F.Pos{0n}) == False{} : Bool}

# S4.131 (EXP-001) the digits of an integer lose their trailing zeros and keep the point after all of them
law short_of_digits_drops_trailing_zeros:
  {F.short.of_digits([1, 5, 0, 0]) == F.Short{[1, 5], F.Pos{4n}} : F.Short}

# S6.10 "exr" and "jda" share the 16 hash bits the tree uses (FNV-1a 1957071438 and 3907357262, both ...8a4e):
# a key that lands in a NON-EMPTY bucket without being in it is not a member
law kt_collision_not_member:
  {T.kt.has(T.kt.put(T.kt.empty(), "exr"), "jda") == False{} : Bool}

# S6.10 and both colliding keys are members once both are put
law kt_collision_both_members:
  {Bool.and(T.kt.has(T.kt.put(T.kt.put(T.kt.empty(), "exr"), "jda"), "jda"), T.kt.has(T.kt.put(T.kt.put(T.kt.empty(), "exr"), "jda"), "exr")) == True{} : Bool}

# S6.10 the two hashes behind the collision laws
law kt_collision_hashes:
  {(T.key_hash("exr"), T.key_hash("jda")) == (1957071438, 3907357262) : U32 & U32}

# S6.10, S4.37 goldens/encstr_keys_hash_collision: the encoder on colliding keys: a tabular header and rows, a folded
# sibling test, a repeated key
law golden_collision_keys_encode:
  {C.run_pure(["--encode", "--key-folding", "safe"], T.ascii_bytes("{\"exr\":\"a\",\"jda\":\"b\",\"exr\":\"c\",\"t\":[{\"exr\":\"p\",\"jda\":\"q\"},{\"jda\":\"r\",\"exr\":\"s\"}]}", Nil{})) == C.Out{0n, "exr: c\njda: b\nt[2]{exr,jda}:\n  p,q\n  s,r\n", ""} : C.Out}

# S6.10 goldens/encstr_duplicate_keys: a repeated JSON key keeps its FIRST position and takes its LAST value, at every depth
law golden_encstr_duplicate_keys:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"a\":1,\"b\":2,\"a\":3,\"c\":{\"x\":1,\"x\":2}}\n", Nil{})) == C.Out{0n, "a: 3\nb: 2\nc:\n  x: 2\n", ""} : C.Out}

# S6.10 goldens/encstr_duplicate_keys_escaped: keys are compared after unescaping
law golden_encstr_duplicate_keys_escaped:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"\\u0061\":1,\"b\":2,\"a\":3}\n", Nil{})) == C.Out{0n, "a: 3\nb: 2\n", ""} : C.Out}

# S6.10 goldens/encstr_duplicate_keys_replace_container: a repeated key replaces the whole value, nothing is merged
law golden_encstr_duplicate_keys_replace_container:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"a\":{\"x\":1},\"b\":2,\"a\":[3],\"b\":{\"y\":1}}\n", Nil{})) == C.Out{0n, "a[1]: 3\nb:\n  y: 1\n", ""} : C.Out}

# ---------------------------------------------------------------- round 7: balanced buckets and colliding keys (closed)

# S6.10 the order that balances buckets: a proper prefix is less, the first differing scalar value decides
law str_cmp_orders:
  {(T.str_cmp("ab", "abc"), T.str_cmp("abd", "abc"), T.str_cmp("abc", "abc"), T.str_cmp("", "")) == (T.OLt{}, T.OGt{}, T.OEq{}, T.OEq{}) : T.Ord & T.Ord & T.Ord & T.Ord}

# S6.10 a bucket stays balanced: seven keys put in ascending order (the worst case of a plain search tree)
# make an AA tree of three levels, not a chain of seven
law ks_bucket_is_balanced:
  {T.ks.level(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.KSNil{}, "a"), "b"), "c"), "d"), "e"), "f"), "g")) == 3n : Nat}

# S6.10 and every one of them is found again, while a key between two of them is not
law ks_bucket_members:
  {(T.ks.has(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.KSNil{}, "a"), "b"), "c"), "d"), "e"), "a"), T.ks.has(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.KSNil{}, "a"), "b"), "c"), "d"), "e"), "e"), T.ks.has(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.KSNil{}, "a"), "b"), "c"), "d"), "e"), "bb")) == (True{}, True{}, False{}) : Bool & Bool & Bool}

# S4.63 goldens/encstr_fold_hash_collision (round 7: every key of this document lands in ONE bucket of the hashed carriers)
law golden_encstr_fold_hash_collision:
  {C.run_pure(["--encode", "--key-folding", "safe"], T.ascii_bytes("{\"exr\":{\"x\":1},\"jda\":{\"x\":2},\"exr.x\":3,\"jda.y\":{\"z\":4}}", Nil{})) == C.Out{0n, "exr:\n  x: 1\njda.x: 2\nexr.x: 3\njda.y:\n  z: 4\n", ""} : C.Out}

# S2.29 goldens/encstr_duplicate_keys_thrice (round 7: every key of this document lands in ONE bucket of the hashed carriers)
law golden_encstr_duplicate_keys_thrice:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"a\":1,\"b\":{\"a\":1,\"a\":2,\"a\":3},\"a\":2,\"c\":0,\"a\":3}", Nil{})) == C.Out{0n, "a: 3\nb:\n  a: 3\nc: 0\n", ""} : C.Out}

# S4.243 goldens/toonedge_expand_hash_collision_conflict (round 7: every key of this document lands in ONE bucket of the hashed carriers)
law golden_toonedge_expand_hash_collision_conflict:
  {C.run_pure(["--decode", "--expand-paths", "safe"], T.ascii_bytes("exr.k: 1\njda.k: 2\nexr.m: 3\njda.k.z: 4\n", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Path expansion conflict at segment \"k\": expected object but found primitive"} : C.Out}

# S4.246 goldens/toonedge_expand_hash_collision_lenient (round 7: every key of this document lands in ONE bucket of the hashed carriers)
law golden_toonedge_expand_hash_collision_lenient:
  {C.run_pure(["--decode", "--expand-paths", "safe", "--no-strict"], T.ascii_bytes("exr.k: 1\njda.k: 2\nexr.m: 3\njda.k.z: 4\n", Nil{})) == C.Out{0n, "{\n  \"exr\": {\n    \"k\": 1,\n    \"m\": 3\n  },\n  \"jda\": {\n    \"k\": {\n      \"z\": 4\n    }\n  }\n}\n", ""} : C.Out}

# S3.25 goldens/toonedge_repeated_keys_hash_collision (round 7: every key of this document lands in ONE bucket of the hashed carriers)
law golden_toonedge_repeated_keys_hash_collision:
  {C.run_pure(["--decode"], T.ascii_bytes("exr: 1\njda: 2\nexr: 3\n", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Duplicate sibling key \"exr\""} : C.Out}

# S4.245 goldens/toonerr_expand_repeated_hash_collision (round 7: every key of this document lands in ONE bucket of the hashed carriers)
law golden_toonerr_expand_repeated_hash_collision:
  {C.run_pure(["--decode", "--expand-paths", "safe"], T.ascii_bytes("exr: 1\njda: 2\nexr: 3\nt[2]{jda,exr}:\n  1,2\n  3,4\n", Nil{})) == C.Out{1n, "", "Failed to decode TOON: Duplicate sibling key \"exr\""} : C.Out}

# S6.10 the other worst case: seven keys put in DESCENDING order (every insertion makes a left link, which
# only skew removes) also make three levels
law ks_bucket_is_balanced_descending:
  {T.ks.level(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.KSNil{}, "g"), "f"), "e"), "d"), "c"), "b"), "a")) == 3n : Nat}

# S6.10 and the first and the last of them are found again
law ks_bucket_members_descending:
  {(T.ks.has(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.KSNil{}, "g"), "f"), "e"), "d"), "c"), "b"), "a"), "a"), T.ks.has(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.ks.put(T.KSNil{}, "g"), "f"), "e"), "d"), "c"), "b"), "a"), "g")) == (True{}, True{}) : Bool & Bool}

# ---------------------------------------------------------------- round 8: a cluster after a pending value option (closed)

# S1.81 goldens/usage_missing_value_before_mixed_cluster (round 8: the FIRST character of a cluster after a pending value option decides)
law golden_usage_missing_value_before_mixed_cluster:
  {C.run_pure(["-o", "-ex"], Nil{}) == C.Out{2n, "", "error: a value is required for '--output <FILE>' but none was supplied\n\nFor more information, try '--help'."} : C.Out}

# S1.81 goldens/usage_missing_value_indent_before_mixed_cluster (round 8: the FIRST character of a cluster after a pending value option decides)
law golden_usage_missing_value_indent_before_mixed_cluster:
  {C.run_pure(["--indent", "-ox"], Nil{}) == C.Out{2n, "", "error: a value is required for '--indent <INDENT>' but none was supplied\n\nFor more information, try '--help'."} : C.Out}

# S1.77 goldens/usage_unknown_first_in_cluster_after_value_option (round 8: the FIRST character of a cluster after a pending value option decides)
law golden_usage_unknown_first_in_cluster_after_value_option:
  {C.run_pure(["-o", "-xe"], Nil{}) == C.Out{2n, "", "error: unexpected argument '-x' found\n\n  tip: to pass '-x' as a value, use '-- -x'\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S1.77 goldens/usage_unknown_digit_cluster_after_value_option (round 8: the FIRST character of a cluster after a pending value option decides)
law golden_usage_unknown_digit_cluster_after_value_option:
  {C.run_pure(["-o", "-5e"], Nil{}) == C.Out{2n, "", "error: unexpected argument '-5' found\n\n  tip: to pass '-5' as a value, use '-- -5'\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# ---------------------------------------------------------------- EXP-007: numbers rendered before emission

# S8.2 the kill-switch closes the EMITTER half of the pass: with TOON_SPEC=1 the value reaches the
# emitter untouched, so every number takes its spec twin inside put.prim. It does not close the
# reader's half, which defers before any option is read (R16-1, R16-5); the num_safe_* laws below
# are what make that half correct without a switch.
law pre_gate_switch:
  for js: Bool
  for j: J.Json
  {E.pre.if(True{}, js, j) == j : J.Json}

# S4.130, EXP-007 a rendered number prints the text the emitter would have produced for it: the pass
# moves WHEN show_toon_fast runs, never WHAT it returns
law pre_txt_is_num:
  for f: F.F64
  for spec: Bool
  for delim: U32
  for acc: String
  {E.put.prim(J.JTxt{F.show_toon_fast(f, spec)}, delim, spec, acc) == E.put.prim(J.JNum{f}, delim, spec, acc) : String}

# S2.51, EXP-007 a deferred token prints what its own conversion prints: put.prim converts a JRaw with
# the reader's own token_value, so a token the pass never reaches is emitted identically
law pre_raw_is_num:
  for neg: Bool
  for ints: String
  for fracs: String
  for eneg: Bool
  for x: Nat
  for spec: Bool
  for delim: U32
  for acc: String
  {E.put.prim(J.JRaw{neg, ints, fracs, eneg, x}, delim, spec, acc) == E.put.prim(J.JNum{J.raw.f64(neg, ints, fracs, eneg, x, spec)}, delim, spec, acc) : String}

# S4.130, S5.30, EXP-007 the pass's printer dispatch. `num.text` chooses the JSON text or the TOON
# text from the side it runs on, and until these two laws existed NO law mentioned it: `pre_txt_is_num`
# and `pre_txt_is_num_json` pin what a JTxt MEANS on each side, not that the pass built it with the
# right printer. Swapping the two arms puts Rust `Display` number text into JSON output and
# JavaScript number text into TOON output; hand mutant M36 does exactly that, and before these laws
# the checker had nothing to say about it. Round 16 named the EXP-007 decode half as unmutated.
law num_text_json_is_show_json:
  for f: F.F64
  for spec: Bool
  {E.num.text(True{}, f, spec) == F.show_json_fast(f, spec) : String}

law num_text_toon_is_show_toon:
  for f: F.F64
  for spec: Bool
  {E.num.text(False{}, f, spec) == F.show_toon_fast(f, spec) : String}

# S5.101 the other half of the same question: the two laws above pin the dispatch GIVEN the side flag,
# and `dec.done` is what TELLS the pass which side it is on. Hand mutant M37 lies about the flag, and
# it survived the 179-law reduced proof in the same run that killed M36: `--decode` then prints
# 1000000000000000000000 for 1e+21 and 0.0000001 for 1e-7, exit 0, with no law objecting. This law
# restates the body so that the `True{}` is refutable, which is exactly what it is for. It is stated
# by quantification and NOT as a closed law over a concrete number: computing one would route the
# checker through the decimal->binary64 conversion and the shortest-digit generator, which do not
# normalize (ARCH §11 A7) and which cost 19.9 GB when tried.
law dec_done_renders_with_the_json_printer:
  for v: J.Json
  for indent: Nat
  for spec: Bool
  for stats: Bool
  for text: String
  {C.dec.done(D.DOk{v}, indent, spec, stats, text) == C.dec.ok(stats, J.write_ln(E.pre.if(spec, True{}, v), indent, spec), text) : C.CR}

# ---------------------------------------------------------------- the dispatch sweep (round 16 follow-up)
#
# R16-2, R16-3, M36 and M37 were one disease: a def that CHOOSES between two behaviours with no law
# saying which choice belongs in which arm. A mutant that swaps the arms of a fast/spec gate can then
# survive both the corpus and the proof, because the corpus only samples inputs and the fast twin
# agrees with the spec twin on most of them — the difference hides outside the captured cases.
#
# This block pins every fast/spec gate in the port that no law named, both arms where the checker can
# take it. Each law is a QUANTIFIED restatement of one arm, which is the cheap form: it names no
# number, so it never routes the checker through the decimal->binary64 conversion or the
# shortest-digit generator, and it adds nothing measurable to the proof's footprint.
#
# TWO ARMS ARE NOT HERE and cannot be, for the reason NE-001..003 already give: the checker cannot
# unfold those bodies over abstract arguments (it reports "the machine stack overflowed").
#   div_p10.pick        the SPEC arm, div(FNum{neg, ta, ma}, pow10(k))
#   from_dec_p10.pick   the FAST arm, from_dec_p10.go(neg, d, eabs)
# Their opposite arms ARE pinned below, so a mutant cannot put the wrong body in the pinned arm; what
# stays unpinned is the unpinned arm's own body, which remains golden-tested only. Stated, not hidden.

# S4.114 the gate takes the fast quotient when it says fast
law div_p10_pick_takes_the_fast_quotient:
  for neg: Bool
  for ma: List<&2, U32>
  for ta: Nat
  for k: Nat
  {F.div_p10.pick(True{}, neg, ma, ta, k) == F.div_p10.go(neg, ma, ta, k) : F.F64}

# S4.143 and the correctly rounded reader when it says spec
law from_dec_p10_pick_takes_the_spec_reader:
  for eneg: Bool
  for neg: Bool
  for d: List<&2, U32>
  for eabs: Nat
  {F.from_dec_p10.pick(False{}, eneg, neg, d, eabs) == F.from_dec(eneg, neg, d, eabs) : F.F64}

# S4.131 the shortest-digit step, both arms
law dg_step_with_takes_the_fast_step:
  for st: F.Dg
  for low_ok: Bool
  for high_ok: Bool
  {F.dg.step.with(True{}, st, low_ok, high_ok) == F.dg.step.fast(st, low_ok, high_ok) : F.Dg}

law dg_step_with_takes_the_spec_step:
  for st: F.Dg
  for low_ok: Bool
  for high_ok: Bool
  {F.dg.step.with(False{}, st, low_ok, high_ok) == F.dg.step(st, low_ok, high_ok) : F.Dg}

# S4.131 (EXP-006) the digit itself, both arms
law dg_digit_fast_fin_takes_the_fast_digit:
  for r: List<&2, U32>
  for s: List<&2, U32>
  for est: Nat
  {F.dg.digit_fast.fin(True{}, r, s, est) == F.dg.digit_fast.fix(BN.sub(r, BN.mul_small(s, U32.from_nat(est), 0), 0), s, U32.from_nat(est)) : List<&2, U32> & U32}

law dg_digit_fast_fin_takes_the_spec_digit:
  for r: List<&2, U32>
  for s: List<&2, U32>
  for est: Nat
  {F.dg.digit_fast.fin(False{}, r, s, est) == F.dg.digit(10n, r, s, 0) : List<&2, U32> & U32}

# S4.143 the short-integer twin, both arms. Round 5 found this gate accepting 15-digit texts, which
# is what a swapped arm here would look like again.
law token_short_takes_the_short_value:
  for neg: Bool
  for ints: String
  for fracs: String
  for e: F.Int
  {F.token.short(True{}, neg, ints, fracs, e, False{}) == F.token.short.value(T.nat_of(ints, 0n), neg, ints, fracs, e) : Maybe<&2, F.F64>}

law token_short_takes_the_literal:
  for neg: Bool
  for ints: String
  for fracs: String
  for e: F.Int
  for spec: Bool
  {F.token.short(False{}, neg, ints, fracs, e, spec) == F.token.literal(neg, ints, fracs, e, spec) : Maybe<&2, F.F64>}

# S2.51 (EXP-007) the consumer of num.safe. R16-1 was a wrong BOUND; a swap here is the same bug
# reached from the other side, deferring a token the bound refused.
law num_defer_keeps_the_token_raw:
  for neg: Bool
  for ints: String
  for fracs: String
  for eneg: Bool
  for x: Nat
  for spec: Bool
  {J.num.defer(True{}, neg, ints, fracs, eneg, x, spec) == Some{J.JRaw{neg, ints, fracs, eneg, x}} : Maybe<&2, J.Json>}

law num_defer_converts_now:
  for neg: Bool
  for ints: String
  for fracs: String
  for eneg: Bool
  for x: Nat
  for spec: Bool
  {J.num.defer(False{}, neg, ints, fracs, eneg, x, spec) == J.num.wrap(F.token_value(neg, String.reverse(ints), String.reverse(fracs), J.num.exp_int(eneg, x), spec)) : Maybe<&2, J.Json>}

# S2.51, EXP-007 (R16-1, R16-3) the two bounds num.safe rests on, pinned as closed facts so that
# moving either constant is a red proof and not a surviving mutant. A deferred token's `number out of
# range` would be lost: the reader defers before the kill-switch is read, so TOON_SPEC=1 does not
# restore it, and raw.unwrap's None arm would answer zero for a value the original rejects.

# 51 integer digits are refused even with a negative exponent. This is the fact R16-1 found missing:
# the old disjunction returned True for every negative exponent, so `1<400 zeros>e-1` was deferred
# and printed 0 with exit 0 where the original exits 1.
law num_safe_wide_ints_refused_when_eneg:
  {J.num.safe(True{}, 1n, "100000000000000000000000000000000000000000000000000") == False{} : Bool}

# 51 integer digits are refused with a positive exponent too.
law num_safe_wide_ints_refused_when_epos:
  {J.num.safe(False{}, 0n, "100000000000000000000000000000000000000000000000000") == False{} : Bool}

# An exponent of 251 is refused. This is the fact R16-3 found missing: a mutant moving the bound to
# 300 survived the corpus and the proof, though `1000000000000e299` is out of range in the original.
law num_safe_big_exponent_refused:
  {J.num.safe(False{}, 251n, "1") == False{} : Bool}

# The pass is not silently disabled: the two shapes it exists for are still deferred. Without these,
# a mutant answering False everywhere would satisfy the three refusals above and cost the speedup.
law num_safe_small_exponent_deferred:
  {J.num.safe(False{}, 250n, "1") == True{} : Bool}

law num_safe_deep_underflow_deferred:
  {J.num.safe(True{}, 400n, "1") == True{} : Bool}

# S4.131 (EXP-006) one limb: nothing is dropped, the estimate is the digit (45 = 6 * 7 + 3)
law dg_digit_fast_1limb:
  {F.dg.digit_fast([45], [7]) == F.dg.digit(10n, [45], [7], 0) : List<&2, U32> & U32}

# S4.131 (EXP-006) two limbs: nothing is dropped, the estimate is the digit
law dg_digit_fast_2limb:
  {F.dg.digit_fast([1234, 5], [4000, 1]) == F.dg.digit(10n, [1234, 5], [4000, 1], 0) : List<&2, U32> & U32}

# S4.131 (EXP-006) three limbs, r = 9 s with s = 2^32: the estimate floor(589824 / 65537) = 8 is one low and the
# correction adds the ninth (the checker's Nat arithmetic stays below 2^20 here; values near 2^48 exhaust it)
law dg_digit_fast_low:
  {F.dg.digit_fast([0, 0, 9], [0, 0, 1]) == F.dg.digit(10n, [0, 0, 9], [0, 0, 1], 0) : List<&2, U32> & U32}

# S4.131 (EXP-006) three limbs where the estimate is already the digit (7)
law dg_digit_fast_exact:
  {F.dg.digit_fast([100, 200, 15], [7, 3, 2]) == F.dg.digit(10n, [100, 200, 15], [7, 3, 2], 0) : List<&2, U32> & U32}

# S4.131 (EXP-006) r >= 10 s: the estimate is 10 or more and the spec loop decides, so both return (r - 10 s, 10)
law dg_digit_fast_fallback:
  {F.dg.digit_fast([0, 0, 30], [0, 0, 2]) == F.dg.digit(10n, [0, 0, 30], [0, 0, 2], 0) : List<&2, U32> & U32}

# S4.131 (EXP-006) r < s: the estimate is 0 and nothing is subtracted
law dg_digit_fast_zero:
  {F.dg.digit_fast([5, 0, 1], [6, 0, 1]) == F.dg.digit(10n, [5, 0, 1], [6, 0, 1], 0) : List<&2, U32> & U32}

# S4.64, S4.78 (EXP-008) with folding off a fold attempt never folds, whatever the prefix, the budget, the
# root-literal set and the lean flag hold: the prefix is observable only through a fold, so a lean context
# that stops growing it changes no output
law fold_off_never_folds:
  for k: String
  for v: J.Json
  for budget: Nat
  for hs: Bool
  for set: T.KT
  for hp: Bool
  for pre: String
  for lean: Bool
  for sibs: T.KT
  {E.fold(k, v, E.FCtx{False{}, budget, hs, set, hp, pre, lean}, sibs) == E.Fold{0n, SNil{}} : E.Fold}

# S4.64 (EXP-008) under TOON_SPEC=1 no context is lean: the spec twin always grows the prefix
law fctx_lean_closed_by_switch:
  for fo: Bool
  {E.fctx.lean(fo, True{}) == False{} : Bool}

# S3.26 (toon_bend-zgb) the hot map merges like dups, the spec's merge over entry chains: a nested object
# merges, a new key is appended, the later quoted flag is kept (entries and failure both)
law hot_dups_nested:
  {(D.hr.entries(D.hot.dups(J.JECons{"a", True{}, J.JObj{J.JECons{"k2", False{}, J.JBool{True{}}, J.JNil{}}}, J.JECons{"c", False{}, J.JNull{}, J.JNil{}}}, J.JECons{"a", False{}, J.JObj{J.JECons{"k1", False{}, J.JNull{}, J.JNil{}}}, J.JECons{"b", False{}, J.JStr{"x"}, J.JNil{}}}, True{})), D.hr.err(D.hot.dups(J.JECons{"a", True{}, J.JObj{J.JECons{"k2", False{}, J.JBool{True{}}, J.JNil{}}}, J.JECons{"c", False{}, J.JNull{}, J.JNil{}}}, J.JECons{"a", False{}, J.JObj{J.JECons{"k1", False{}, J.JNull{}, J.JNil{}}}, J.JECons{"b", False{}, J.JStr{"x"}, J.JNil{}}}, True{}))) == (D.mr.entries(D.dups(J.JECons{"a", True{}, J.JObj{J.JECons{"k2", False{}, J.JBool{True{}}, J.JNil{}}}, J.JECons{"c", False{}, J.JNull{}, J.JNil{}}}, J.JECons{"a", False{}, J.JObj{J.JECons{"k1", False{}, J.JNull{}, J.JNil{}}}, J.JECons{"b", False{}, J.JStr{"x"}, J.JNil{}}}, True{})), D.mr.err(D.dups(J.JECons{"a", True{}, J.JObj{J.JECons{"k2", False{}, J.JBool{True{}}, J.JNil{}}}, J.JECons{"c", False{}, J.JNull{}, J.JNil{}}}, J.JECons{"a", False{}, J.JObj{J.JECons{"k1", False{}, J.JNull{}, J.JNil{}}}, J.JECons{"b", False{}, J.JStr{"x"}, J.JNil{}}}, True{}))) : J.Json & Maybe<&2, String>}

# S3.26 (toon_bend-zgb) two levels down: the inner object is made hot and merged in place
law hot_dups_deep:
  {(D.hr.entries(D.hot.dups(J.JECons{"a", False{}, J.JObj{J.JECons{"b", False{}, J.JObj{J.JECons{"k2", False{}, J.JNull{}, J.JNil{}}}, J.JNil{}}}, J.JNil{}}, J.JECons{"a", False{}, J.JObj{J.JECons{"b", False{}, J.JObj{J.JECons{"k1", False{}, J.JNull{}, J.JNil{}}}, J.JECons{"z", False{}, J.JNull{}, J.JNil{}}}}, J.JNil{}}, True{})), D.hr.err(D.hot.dups(J.JECons{"a", False{}, J.JObj{J.JECons{"b", False{}, J.JObj{J.JECons{"k2", False{}, J.JNull{}, J.JNil{}}}, J.JNil{}}}, J.JNil{}}, J.JECons{"a", False{}, J.JObj{J.JECons{"b", False{}, J.JObj{J.JECons{"k1", False{}, J.JNull{}, J.JNil{}}}, J.JECons{"z", False{}, J.JNull{}, J.JNil{}}}}, J.JNil{}}, True{}))) == (D.mr.entries(D.dups(J.JECons{"a", False{}, J.JObj{J.JECons{"b", False{}, J.JObj{J.JECons{"k2", False{}, J.JNull{}, J.JNil{}}}, J.JNil{}}}, J.JNil{}}, J.JECons{"a", False{}, J.JObj{J.JECons{"b", False{}, J.JObj{J.JECons{"k1", False{}, J.JNull{}, J.JNil{}}}, J.JECons{"z", False{}, J.JNull{}, J.JNil{}}}}, J.JNil{}}, True{})), D.mr.err(D.dups(J.JECons{"a", False{}, J.JObj{J.JECons{"b", False{}, J.JObj{J.JECons{"k2", False{}, J.JNull{}, J.JNil{}}}, J.JNil{}}}, J.JNil{}}, J.JECons{"a", False{}, J.JObj{J.JECons{"b", False{}, J.JObj{J.JECons{"k1", False{}, J.JNull{}, J.JNil{}}}, J.JECons{"z", False{}, J.JNull{}, J.JNil{}}}}, J.JNil{}}, True{}))) : J.Json & Maybe<&2, String>}

# S3.26, S9.151 (toon_bend-zgb) strict mode: an object meets a string, the EARLIER value stays and the
# first failure is the first conflicting key's, a later conflict does not replace it
law hot_dups_strict_conflict:
  {(D.hr.entries(D.hot.dups(J.JECons{"a", False{}, J.JStr{"s"}, J.JECons{"b", False{}, J.JNull{}, J.JNil{}}}, J.JECons{"a", False{}, J.JObj{J.JNil{}}, J.JECons{"b", False{}, J.JStr{"x"}, J.JNil{}}}, True{})), D.hr.err(D.hot.dups(J.JECons{"a", False{}, J.JStr{"s"}, J.JECons{"b", False{}, J.JNull{}, J.JNil{}}}, J.JECons{"a", False{}, J.JObj{J.JNil{}}, J.JECons{"b", False{}, J.JStr{"x"}, J.JNil{}}}, True{}))) == (D.mr.entries(D.dups(J.JECons{"a", False{}, J.JStr{"s"}, J.JECons{"b", False{}, J.JNull{}, J.JNil{}}}, J.JECons{"a", False{}, J.JObj{J.JNil{}}, J.JECons{"b", False{}, J.JStr{"x"}, J.JNil{}}}, True{})), D.mr.err(D.dups(J.JECons{"a", False{}, J.JStr{"s"}, J.JECons{"b", False{}, J.JNull{}, J.JNil{}}}, J.JECons{"a", False{}, J.JObj{J.JNil{}}, J.JECons{"b", False{}, J.JStr{"x"}, J.JNil{}}}, True{}))) : J.Json & Maybe<&2, String>}

# S5.56 (EXP-011) an empty array is two bytes at any indent
law write_empty_array:
  {J.write(J.JArr{0n, J.JNil{}}, 2n, False{}) == "[]" : String}

# S5.56 (EXP-011) an empty object is two bytes at any indent
law write_empty_object:
  {J.write(J.JObj{J.JNil{}}, 2n, False{}) == "{}" : String}

# S5.56, S5.58, S5.60 (EXP-011) an empty object inside a non-empty one stays two bytes; a non-empty
# array opens a line per element and closes at its own depth
law write_nested_indent_2:
  {J.write(J.JObj{J.JECons{"a", False{}, J.JObj{J.JNil{}}, J.JECons{"b", False{}, J.JArr{1n, J.JCons{J.JNull{}, J.JNil{}}}, J.JNil{}}}}, 2n, False{}) == "{\n  \"a\": {},\n  \"b\": [\n    null\n  ]\n}" : String}

# S5.58, S5.59 (EXP-011) at indent 0 no line breaks and ':' alone
law write_nested_indent_0:
  {J.write(J.JObj{J.JECons{"a", False{}, J.JObj{J.JNil{}}, J.JECons{"b", False{}, J.JArr{1n, J.JCons{J.JNull{}, J.JNil{}}}, J.JNil{}}}}, 0n, False{}) == "{\"a\":{},\"b\":[null]}" : String}

# S2.130 (EXP-009) no '[': the precheck answers what the cut would (not a header)
law hdr_precheck_miss:
  {D.hdr.a.plain.pre(T.has_char("key: value", 91), "key: value") == D.hdr.a.plain(T.cut("key: value", 91)) : D.Hdr}

# S2.130 (EXP-009) a header: the precheck lets the cut run
law hdr_precheck_hit:
  {D.hdr.a.plain.pre(T.has_char("items[2]: a,b", 91), "items[2]: a,b") == D.hdr.a.plain(T.cut("items[2]: a,b", 91)) : D.Hdr}

# S2.130 (EXP-009) a '[' after the colon belongs to the value: both answer not a header
law hdr_precheck_colon_first:
  {D.hdr.a.plain.pre(T.has_char("a: b[1]", 91), "a: b[1]") == D.hdr.a.plain(T.cut("a: b[1]", 91)) : D.Hdr}

# S2.131 (EXP-009) a '[' never closed: both answer not a header
law hdr_precheck_unclosed:
  {D.hdr.a.plain.pre(T.has_char("k[3", 91), "k[3") == D.hdr.a.plain(T.cut("k[3", 91)) : D.Hdr}

# S3.26 (toon_bend-zgb) lenient mode: the later value takes the earlier one's position, no failure
law hot_dups_lenient_overwrite:
  {(D.hr.entries(D.hot.dups(J.JECons{"a", True{}, J.JStr{"s"}, J.JECons{"b", False{}, J.JObj{J.JNil{}}, J.JNil{}}}, J.JECons{"a", False{}, J.JObj{J.JNil{}}, J.JECons{"b", False{}, J.JStr{"x"}, J.JNil{}}}, False{})), D.hr.err(D.hot.dups(J.JECons{"a", True{}, J.JStr{"s"}, J.JECons{"b", False{}, J.JObj{J.JNil{}}, J.JNil{}}}, J.JECons{"a", False{}, J.JObj{J.JNil{}}, J.JECons{"b", False{}, J.JStr{"x"}, J.JNil{}}}, False{}))) == (D.mr.entries(D.dups(J.JECons{"a", True{}, J.JStr{"s"}, J.JECons{"b", False{}, J.JObj{J.JNil{}}, J.JNil{}}}, J.JECons{"a", False{}, J.JObj{J.JNil{}}, J.JECons{"b", False{}, J.JStr{"x"}, J.JNil{}}}, False{})), D.mr.err(D.dups(J.JECons{"a", True{}, J.JStr{"s"}, J.JECons{"b", False{}, J.JObj{J.JNil{}}, J.JNil{}}}, J.JECons{"a", False{}, J.JObj{J.JNil{}}, J.JECons{"b", False{}, J.JStr{"x"}, J.JNil{}}}, False{}))) : J.Json & Maybe<&2, String>}

# S5.30, EXP-007 a rendered number prints the JSON text the writer would have produced for it: the pass on
# the decode side moves WHEN show_json_fast runs, never WHAT it returns
law pre_txt_is_num_json:
  for f: F.F64
  for first: Bool
  for n: Nat
  for depth: Nat
  for spec: Bool
  for acc: String
  {J.w(J.JTxt{F.show_json_fast(f, spec)}, first, n, depth, spec, acc) == J.w(J.JNum{f}, first, n, depth, spec, acc) : String}

# S3.26 (round 16, R16-2) the FIRST repeated-key failure is the one reported: once a failure is pending, no
# later one replaces it. A decoder that kept the last one printed `"a"` where the original prints `"b"`
# (case toonerr_dup_first_of_two_wins); that mutant passed every case and the whole proof before this law
law dup_keep_is_first:
  for m: String
  for new: Maybe<&2, String>
  {D.dup.keep(Some{m}, new) == Some{m} : Maybe<&2, String>}
