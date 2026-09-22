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

# S4.316 a tie goes to the even digit: 6.25 prints as 6.2 (OQ-003)
law stats_pct_6_25:
  {C.percent(1n, 16n) == "6.2" : String}

# S4.316 and 18.75 prints as 18.8
law stats_pct_18_75:
  {C.percent(3n, 16n) == "18.8" : String}

# S4.315 two binary64 operations, not the exact ratio: 23/80 prints 28.7 (exact 28.75 would print 28.8)
law stats_pct_double_rounding:
  {C.percent(23n, 80n) == "28.7" : String}

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
  {F.show_json_fast(F.from_nat(1500n), False{}) == "1500.0" : String}

# S4.131 (EXP-001) one digit
law show_toon_fast_one:
  {F.show_toon_fast(F.from_nat(1n), False{}) == "1" : String}

# S4.101 (EXP-002) the short-integer twin of the JSON number reader equals the literal path, bit for bit
law serde_short_42:
  {F.bits.opt(F.serde_value(False{}, "42", "", F.Pos{0n}, False{})) == F.bits.opt(F.serde_value(False{}, "42", "", F.Pos{0n}, True{})) : String}

# S4.118 (EXP-002) a negative zero keeps the literal path in both settings
law serde_short_zero:
  {F.bits.opt(F.serde_value(True{}, "0", "", F.Pos{0n}, False{})) == F.bits.opt(F.serde_value(True{}, "0", "", F.Pos{0n}, True{})) : String}

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

# S4.101, S4.114 (EXP-003) the whole JSON number path on 3.7: fast twins and spec twins give the same bits
law serde_decimal_3_7:
  {F.bits.opt(F.serde_value(False{}, "3", "7", F.Pos{0n}, False{})) == F.bits.opt(F.serde_value(False{}, "3", "7", F.Pos{0n}, True{})) : String}

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

# S4.248 (toonedge_expand_segments_253) and 253 segments are accepted
law expand_cap_is_256_accept:
  {D.dr.ok(D.decode_expanded("k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k.k: x\n", True{}, 2n, False{})) == True{} : Bool}

# S2.2 a UTF-8-encoded surrogate (ED A0 80, the CESU-8 form of U+D800) is NOT valid UTF-8 and the input
# gate rejects it. Round 13 (R13-9) mutated the surrogate test out of `utf8.cont` and the whole proof still
# checked: no law pinned it, only the corpus (`jsonerr_utf8_surrogate`).
law utf8_rejects_surrogate:
  {T.utf8.finish(T.utf8.bytes([237, 160, 128], T.utf8.init())) == None{} : Maybe<&2, String>}

# S2.2 and the same three-byte shape one scalar below the surrogate block (ED 9F BF = U+D7FF) IS valid:
# the law above must not be satisfiable by refusing every three-byte sequence.
law utf8_accepts_below_surrogate:
  {T.utf8.finish(T.utf8.bytes([237, 159, 191], T.utf8.init())) == Some{SCon{Chr{55295}, SNil{}}} : Maybe<&2, String>}

# S5.64 writer B (the one behind --expand-paths) escapes DEL as \u007f. The accumulator is built in
# reverse, so the expected string reads backwards. Round 13 (R13-9) mutated this table and the whole proof
# still checked.
law writer_b_escapes_del:
  {J.w.ch(True{}, 127, SNil{}) == "f700u\\" : String}

# S5.64 and writer B escapes the C1 block too (U+0085 as \u0085)
law writer_b_escapes_c1:
  {J.w.ch(True{}, 133, SNil{}) == "5800u\\" : String}

# S5.63 writer A (plain --decode) writes the SAME scalar raw: the two tables differ, and a repair that
# unified them would break the goldens of one of the two writers
law writer_a_keeps_del_raw:
  {J.w.ch(False{}, 127, SNil{}) == SCon{Chr{127}, SNil{}} : String}

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

# S4.173 the JSON writers stay PLAIN up to decimal exponent k = 16 ...
law json_plain_at_k16:
  {F.json.is_plain(F.Pos{16n}) == True{} : Bool}

# S4.173 ... and switch to an exponent at k = 17
law json_exponent_at_k17:
  {F.json.is_plain(F.Pos{17n}) == False{} : Bool}

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
  {C.run_pure([], T.ascii_bytes("", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 0"} : C.Out}

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
  {C.run_pure(["--decode"], T.ascii_bytes("hello\nworld\n", Nil{})) == C.Out{1n, "", "Missing colon after key"} : C.Out}

# S5.112 goldens/jsonout_root_empty_array
law golden_jsonout_root_empty_array:
  {C.run_pure(["--decode"], T.ascii_bytes("[0]:", Nil{})) == C.Out{0n, "[]\n", ""} : C.Out}

# S5.112 goldens/jsonerr_empty
law golden_jsonerr_empty:
  {C.run_pure(["--encode"], T.ascii_bytes("", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 0"} : C.Out}

# S5.112 goldens/jsonerr_whitespace
law golden_jsonerr_whitespace:
  {C.run_pure(["--encode"], T.ascii_bytes("  \n\t\n", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 3 column 0"} : C.Out}

# S5.112 goldens/jsonerr_open_brace
law golden_jsonerr_open_brace:
  {C.run_pure(["--encode"], T.ascii_bytes("{", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing an object at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_open_bracket
law golden_jsonerr_open_bracket:
  {C.run_pure(["--encode"], T.ascii_bytes("[", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a list at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_trailing_comma_arr
law golden_jsonerr_trailing_comma_arr:
  {C.run_pure(["--encode"], T.ascii_bytes("[1,]", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: trailing comma at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_missing_value
law golden_jsonerr_missing_value:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"invalid\": }", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected value at line 1 column 13"} : C.Out}

# S5.112 goldens/jsonerr_single_quotes
law golden_jsonerr_single_quotes:
  {C.run_pure(["--encode"], T.ascii_bytes("'a'", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected value at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_bad_true
law golden_jsonerr_bad_true:
  {C.run_pure(["--encode"], T.ascii_bytes("tru", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_bad_null
law golden_jsonerr_bad_null:
  {C.run_pure(["--encode"], T.ascii_bytes("nul", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_bad_ident
law golden_jsonerr_bad_ident:
  {C.run_pure(["--encode"], T.ascii_bytes("nope", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected ident at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_dot_end
law golden_jsonerr_dot_end:
  {C.run_pure(["--encode"], T.ascii_bytes("1.", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_dot_start
law golden_jsonerr_dot_start:
  {C.run_pure(["--encode"], T.ascii_bytes(".5", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected value at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_lone_minus
law golden_jsonerr_lone_minus:
  {C.run_pure(["--encode"], T.ascii_bytes("-", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_exp_end
law golden_jsonerr_exp_end:
  {C.run_pure(["--encode"], T.ascii_bytes("1e", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_plus
law golden_jsonerr_plus:
  {C.run_pure(["--encode"], T.ascii_bytes("+1", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected value at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_unterminated_string
law golden_jsonerr_unterminated_string:
  {C.run_pure(["--encode"], T.ascii_bytes("\"abc", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a string at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_bad_escape
law golden_jsonerr_bad_escape:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\x\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid escape at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_short_hex
law golden_jsonerr_short_hex:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\u12\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a string at line 1 column 6"} : C.Out}

# S5.112 goldens/jsonerr_bad_hex
law golden_jsonerr_bad_hex:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\u12zz\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid escape at line 1 column 7"} : C.Out}

# S5.112 goldens/jsonerr_lone_high_surrogate
law golden_jsonerr_lone_high_surrogate:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: unexpected end of hex escape at line 1 column 8"} : C.Out}

# S5.112 goldens/jsonerr_high_then_bmp
law golden_jsonerr_high_then_bmp:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\\u0041\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: lone leading surrogate in hex escape at line 1 column 13"} : C.Out}

# S5.112 goldens/jsonerr_lone_low_surrogate
law golden_jsonerr_lone_low_surrogate:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\udc00\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: lone leading surrogate in hex escape at line 1 column 7"} : C.Out}

# S5.112 goldens/jsonerr_raw_newline_in_string
law golden_jsonerr_raw_newline_in_string:
  {C.run_pure(["--encode"], T.ascii_bytes("\"a\nb\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: control character (\\u0000-\\u001F) found while parsing a string at line 2 column 0"} : C.Out}

# S5.112 goldens/jsonerr_raw_tab_in_string
law golden_jsonerr_raw_tab_in_string:
  {C.run_pure(["--encode"], T.ascii_bytes("\"a\tb\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: control character (\\u0000-\\u001F) found while parsing a string at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_trailing_after_obj
law golden_jsonerr_trailing_after_obj:
  {C.run_pure(["--encode"], T.ascii_bytes("{} x", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: trailing characters at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_nan
law golden_jsonerr_nan:
  {C.run_pure(["--encode"], T.ascii_bytes("NaN", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected value at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_infinity
law golden_jsonerr_infinity:
  {C.run_pure(["--encode"], T.ascii_bytes("Infinity", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected value at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_eof_after_key
law golden_jsonerr_eof_after_key:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"a\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing an object at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_eof_after_colon
law golden_jsonerr_eof_after_colon:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"a\":", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 5"} : C.Out}

# S5.112 goldens/jsonerr_minus_word
law golden_jsonerr_minus_word:
  {C.run_pure(["--encode"], T.ascii_bytes("-x", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid number at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_upper_true
law golden_jsonerr_upper_true:
  {C.run_pure(["--encode"], T.ascii_bytes("TRUE", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected value at line 1 column 1"} : C.Out}

# S5.112 goldens/toonerr_blank_in_list
law golden_toonerr_blank_in_list:
  {C.run_pure(["--decode"], T.ascii_bytes("items[2]:\n  - a\n\n  - b", Nil{})) == C.Out{1n, "", "Line 3: Blank lines inside list array are not allowed in strict mode"} : C.Out}

# S5.112 goldens/toonerr_extra_list_items
law golden_toonerr_extra_list_items:
  {C.run_pure(["--decode"], T.ascii_bytes("items[1]:\n  - a\n  - b", Nil{})) == C.Out{1n, "", "Expected 1 list array items, but found more"} : C.Out}

# S5.112 goldens/toonerr_too_few_list_items
law golden_toonerr_too_few_list_items:
  {C.run_pure(["--decode"], T.ascii_bytes("items[3]:\n  - a", Nil{})) == C.Out{1n, "", "Expected 3 list array items, but got 1"} : C.Out}

# S5.112 goldens/toonerr_too_few_inline
law golden_toonerr_too_few_inline:
  {C.run_pure(["--decode"], T.ascii_bytes("items[3]: a,b", Nil{})) == C.Out{1n, "", "Expected 3 inline array items, but got 2"} : C.Out}

# S5.112 goldens/toonerr_too_many_inline
law golden_toonerr_too_many_inline:
  {C.run_pure(["--decode"], T.ascii_bytes("items[1]: a,b", Nil{})) == C.Out{1n, "", "Expected 1 inline array items, but got 2"} : C.Out}

# S5.112 goldens/toonerr_huge_length
law golden_toonerr_huge_length:
  {C.run_pure(["--decode"], T.ascii_bytes("items[9999999999]:", Nil{})) == C.Out{1n, "", "Declared array length 9999999999 exceeds maximum allowed (100000000)"} : C.Out}

# S5.112 goldens/toonerr_unterminated_value
law golden_toonerr_unterminated_value:
  {C.run_pure(["--decode"], T.ascii_bytes("name: \"unterminated", Nil{})) == C.Out{1n, "", "Unterminated string: missing closing quote"} : C.Out}

# S5.112 goldens/toonerr_unterminated_key
law golden_toonerr_unterminated_key:
  {C.run_pure(["--decode"], T.ascii_bytes("\"unterminated key: value", Nil{})) == C.Out{1n, "", "Unterminated string: missing closing quote"} : C.Out}

# S5.112 goldens/toonerr_bad_escape
law golden_toonerr_bad_escape:
  {C.run_pure(["--decode"], T.ascii_bytes("name: \"bad \\x escape\"", Nil{})) == C.Out{1n, "", "Invalid escape sequence: \\x"} : C.Out}

# S5.112 goldens/toonerr_unicode_escape
law golden_toonerr_unicode_escape:
  {C.run_pure(["--decode"], T.ascii_bytes("name: \"\\u0041\"", Nil{})) == C.Out{1n, "", "Invalid escape sequence: \\u"} : C.Out}

# S5.112 goldens/toonerr_trailing_backslash
law golden_toonerr_trailing_backslash:
  {C.run_pure(["--decode"], T.ascii_bytes("name: \"abc\\", Nil{})) == C.Out{1n, "", "Unterminated string: missing closing quote"} : C.Out}

# S5.112 goldens/toonerr_after_closing_quote
law golden_toonerr_after_closing_quote:
  {C.run_pure(["--decode"], T.ascii_bytes("name: \"abc\" def", Nil{})) == C.Out{1n, "", "Unexpected characters after closing quote"} : C.Out}

# S5.112 goldens/toonerr_tab_indent
law golden_toonerr_tab_indent:
  {C.run_pure(["--decode"], T.ascii_bytes("\tname: value", Nil{})) == C.Out{1n, "", "Validation error at line 1: Tabs are not allowed in indentation in strict mode"} : C.Out}

# S5.112 goldens/toonerr_tab_indent_list
law golden_toonerr_tab_indent_list:
  {C.run_pure(["--decode"], T.ascii_bytes("items[1]:\n\t- a", Nil{})) == C.Out{1n, "", "Validation error at line 2: Tabs are not allowed in indentation in strict mode"} : C.Out}

# S5.112 goldens/toonerr_missing_close_bracket
law golden_toonerr_missing_close_bracket:
  {C.run_pure(["--decode"], T.ascii_bytes("items[3: a,b,c", Nil{})) == C.Out{0n, "{\n  \"items[3\": \"a,b,c\"\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_missing_colon_nested
law golden_toonerr_missing_colon_nested:
  {C.run_pure(["--decode"], T.ascii_bytes("o:\n  bare\n", Nil{})) == C.Out{1n, "", "Missing colon after key"} : C.Out}

# S5.112 goldens/toonerr_inline_bad_quote
law golden_toonerr_inline_bad_quote:
  {C.run_pure(["--decode"], T.ascii_bytes("items[2]: \"a,b", Nil{})) == C.Out{1n, "", "Unterminated string: missing closing quote"} : C.Out}

# S5.112 goldens/toonerr_list_item_no_space
law golden_toonerr_list_item_no_space:
  {C.run_pure(["--decode"], T.ascii_bytes("items[1]:\n  -a", Nil{})) == C.Out{1n, "", "Expected 1 list array items, but got 0"} : C.Out}

# S5.112 goldens/toonerr_colon_only
law golden_toonerr_colon_only:
  {C.run_pure(["--decode"], T.ascii_bytes(":\n", Nil{})) == C.Out{0n, "{\n  \"\": {}\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_zero_length_with_items
law golden_toonerr_zero_length_with_items:
  {C.run_pure(["--decode"], T.ascii_bytes("items[0]:\n  - a\n", Nil{})) == C.Out{1n, "", "Expected 0 list array items, but found more"} : C.Out}

# S5.112 goldens/toonerr_zero_inline_with_values
law golden_toonerr_zero_inline_with_values:
  {C.run_pure(["--decode"], T.ascii_bytes("items[0]: a\n", Nil{})) == C.Out{1n, "", "Expected 0 inline array items, but got 1"} : C.Out}

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
  {C.run_pure(["--decode"], T.ascii_bytes("a: [2]: x\n", Nil{})) == C.Out{1n, "", "Expected 2 inline array items, but got 1"} : C.Out}

# S5.112 goldens/toonerr_hyphen_value
law golden_toonerr_hyphen_value:
  {C.run_pure(["--decode"], T.ascii_bytes("a: - b\n", Nil{})) == C.Out{0n, "{\n  \"a\": \"- b\"\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_list_at_root_no_header
law golden_toonerr_list_at_root_no_header:
  {C.run_pure(["--decode"], T.ascii_bytes("- a\n- b\n", Nil{})) == C.Out{1n, "", "Missing colon after key"} : C.Out}

# S5.112 goldens/toonlenient_blank_in_list
law golden_toonlenient_blank_in_list:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[2]:\n  - a\n\n  - b", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\",\n    \"b\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_extra_list_items
law golden_toonlenient_extra_list_items:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[1]:\n  - a\n  - b", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\"\n  ]\n}\n", ""} : C.Out}

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
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[1]:\n\t- a", Nil{})) == C.Out{1n, "", "Missing colon after key"} : C.Out}

# S5.112 goldens/toonlenient_zero_length_with_items
law golden_toonlenient_zero_length_with_items:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[0]:\n  - a\n", Nil{})) == C.Out{0n, "{\n  \"items\": []\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_zero_inline_with_values
law golden_toonlenient_zero_inline_with_values:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[0]: a\n", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_bad_escape
law golden_toonlenient_bad_escape:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("name: \"bad \\x escape\"", Nil{})) == C.Out{1n, "", "Invalid escape sequence: \\x"} : C.Out}

# S5.112 goldens/toonlenient_unterminated_value
law golden_toonlenient_unterminated_value:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("name: \"unterminated", Nil{})) == C.Out{1n, "", "Unterminated string: missing closing quote"} : C.Out}

# S5.112 goldens/toonlenient_huge_length
law golden_toonlenient_huge_length:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[9999999999]:", Nil{})) == C.Out{1n, "", "Declared array length 9999999999 exceeds maximum allowed (100000000)"} : C.Out}

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
  {C.run_pure(["--indent", "-1"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected argument '-1' found\n\n  tip: to pass '-1' as a value, use '-- -1'\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_negative_cluster_first_char
law golden_usage_negative_cluster_first_char:
  {C.run_pure(["--indent", "-129"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected argument '-1' found\n\n  tip: to pass '-1' as a value, use '-- -1'\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

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
  {C.run_pure(["--encode"], T.ascii_bytes("[1,", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_exp_sign_end
law golden_jsonerr_exp_sign_end:
  {C.run_pure(["--encode"], T.ascii_bytes("1e+", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_eof_after_backslash
law golden_jsonerr_eof_after_backslash:
  {C.run_pure(["--encode"], T.ascii_bytes("\"abc\\", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a string at line 1 column 5"} : C.Out}

# S5.112 goldens/jsonerr_eof_after_high_surrogate
law golden_jsonerr_eof_after_high_surrogate:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a string at line 1 column 7"} : C.Out}

# S5.112 goldens/jsonerr_eof_after_high_surrogate_backslash
law golden_jsonerr_eof_after_high_surrogate_backslash:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\\", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a string at line 1 column 8"} : C.Out}

# S5.112 goldens/jsonerr_ident_newline
law golden_jsonerr_ident_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("tru\n", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected ident at line 2 column 0"} : C.Out}

# S5.112 goldens/jsonerr_ident_then_more
law golden_jsonerr_ident_then_more:
  {C.run_pure(["--encode"], T.ascii_bytes("nulll", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: trailing characters at line 1 column 5"} : C.Out}

# S5.112 goldens/jsonerr_short_hex_newline
law golden_jsonerr_short_hex_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\u12\"\n", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid escape at line 2 column 0"} : C.Out}

# S5.112 goldens/jsonerr_escape_newline
law golden_jsonerr_escape_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\\n\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid escape at line 2 column 0"} : C.Out}

# S5.112 goldens/jsonerr_escape_upper_u
law golden_jsonerr_escape_upper_u:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\U0041\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid escape at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_dot_nondigit
law golden_jsonerr_dot_nondigit:
  {C.run_pure(["--encode"], T.ascii_bytes("[1.]", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid number at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_dot_newline
law golden_jsonerr_dot_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("1.\n", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid number at line 2 column 0"} : C.Out}

# S5.112 goldens/jsonerr_exp_nondigit
law golden_jsonerr_exp_nondigit:
  {C.run_pure(["--encode"], T.ascii_bytes("[1e]", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid number at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_exp_double_sign
law golden_jsonerr_exp_double_sign:
  {C.run_pure(["--encode"], T.ascii_bytes("1e+-1", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid number at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_minus_infinity
law golden_jsonerr_minus_infinity:
  {C.run_pure(["--encode"], T.ascii_bytes("-Infinity", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid number at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_number_then_letter
law golden_jsonerr_number_then_letter:
  {C.run_pure(["--encode"], T.ascii_bytes("[1x]", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected `,` or `]` at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_hex_number
law golden_jsonerr_hex_number:
  {C.run_pure(["--encode"], T.ascii_bytes("0x10", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: trailing characters at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_raw_cr_in_string
law golden_jsonerr_raw_cr_in_string:
  {C.run_pure(["--encode"], T.ascii_bytes("\"a\rb\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: control character (\\u0000-\\u001F) found while parsing a string at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_obj_leading_comma
law golden_jsonerr_obj_leading_comma:
  {C.run_pure(["--encode"], T.ascii_bytes("{,}", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: key must be a string at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_arr_leading_comma
law golden_jsonerr_arr_leading_comma:
  {C.run_pure(["--encode"], T.ascii_bytes("[,]", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected value at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_arr_comma_then_brace
law golden_jsonerr_arr_comma_then_brace:
  {C.run_pure(["--encode"], T.ascii_bytes("[1,}", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected value at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_high_then_escape
law golden_jsonerr_high_then_escape:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\\n\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: unexpected end of hex escape at line 1 column 9"} : C.Out}

# S5.112 goldens/jsonerr_high_then_newline
law golden_jsonerr_high_then_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\n\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: unexpected end of hex escape at line 2 column 0"} : C.Out}

# S5.112 goldens/jsonerr_high_then_bad_hex
law golden_jsonerr_high_then_bad_hex:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\\uzzzz\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid escape at line 1 column 13"} : C.Out}

# S5.112 goldens/jsonerr_high_then_high
law golden_jsonerr_high_then_high:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\\ud800\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: lone leading surrogate in hex escape at line 1 column 13"} : C.Out}

# S5.112 goldens/jsonerr_trailing_comma_newline
law golden_jsonerr_trailing_comma_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("[1,\n]", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: trailing comma at line 2 column 1"} : C.Out}

# S5.112 goldens/jsonerr_trailing_close
law golden_jsonerr_trailing_close:
  {C.run_pure(["--encode"], T.ascii_bytes("[]]", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: trailing characters at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_cr_not_newline
law golden_jsonerr_cr_not_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("[1,\r\r oops]", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected value at line 1 column 7"} : C.Out}

# S5.112 goldens/jsonout_empty_in_array
law golden_jsonout_empty_in_array:
  {C.run_pure(["--decode"], T.ascii_bytes("[4]:\n  -\n  - [0]:\n  - [1]:\n    - [0]:\n  - k:\n    l[0]:\n", Nil{})) == C.Out{0n, "[\n  {},\n  [],\n  [\n    []\n  ],\n  {\n    \"k\": {},\n    \"l\": []\n  }\n]\n", ""} : C.Out}

# S5.112 goldens/toonedge_crlf_bare_dash
law golden_toonedge_crlf_bare_dash:
  {C.run_pure(["--decode"], T.ascii_bytes("x[1]:\r\n  -\r\n", Nil{})) == C.Out{1n, "", "Expected 1 list array items, but got 0"} : C.Out}

# S5.112 goldens/toonedge_header_key_with_colon
law golden_toonedge_header_key_with_colon:
  {C.run_pure(["--decode"], T.ascii_bytes("a: [1]: x\n", Nil{})) == C.Out{0n, "{\n  \"a:\": [\n    \"x\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonedge_header_in_quoted_value
law golden_toonedge_header_in_quoted_value:
  {C.run_pure(["--decode"], T.ascii_bytes("a: \"x[1]: y\"\n", Nil{})) == C.Out{0n, "{\n  \"a: \\\"x\": [\n    \"y\\\"\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_cap_in_quoted_value
law golden_toonerr_cap_in_quoted_value:
  {C.run_pure(["--decode"], T.ascii_bytes("note: \"see [999999999999]: x\"\n", Nil{})) == C.Out{1n, "", "Declared array length 999999999999 exceeds maximum allowed (100000000)"} : C.Out}

# S5.112 goldens/toonerr_length_u64_max_list
law golden_toonerr_length_u64_max_list:
  {C.run_pure(["--decode"], T.ascii_bytes("items[18446744073709551615]:\n", Nil{})) == C.Out{1n, "", "Declared array length 18446744073709551615 exceeds maximum allowed (100000000)"} : C.Out}

# S5.112 goldens/toonedge_root_vs_item_keyvalue
law golden_toonedge_root_vs_item_keyvalue:
  {C.run_pure(["--decode"], T.ascii_bytes("a\"b: c\n", Nil{})) == C.Out{0n, "{\n  \"a\\\"b\": \"c\"\n}\n", ""} : C.Out}

# S5.112 goldens/toonedge_item_quote_hides_colon
law golden_toonedge_item_quote_hides_colon:
  {C.run_pure(["--decode"], T.ascii_bytes("l[1]:\n  - a\"b: c\n", Nil{})) == C.Out{0n, "{\n  \"l\": [\n    \"a\\\"b: c\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonedge_list_item_two_spaces_quoted_key
law golden_toonedge_list_item_two_spaces_quoted_key:
  {C.run_pure(["--decode"], T.ascii_bytes("l[1]:\n  -  \"a\": b\n", Nil{})) == C.Out{0n, "{\n  \"l\": [\n    {\n      \"\\\"a\\\"\": \"b\"\n    }\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_count_beats_blank
law golden_toonerr_count_beats_blank:
  {C.run_pure(["--decode"], T.ascii_bytes("l[3]:\n  - a\n\n  - b\n", Nil{})) == C.Out{1n, "", "Expected 3 list array items, but got 2"} : C.Out}

# S5.112 goldens/toonerr_extra_bare_dash_undetected
law golden_toonerr_extra_bare_dash_undetected:
  {C.run_pure(["--decode"], T.ascii_bytes("l[1]:\n  - a\n  -\n", Nil{})) == C.Out{0n, "{\n  \"l\": [\n    \"a\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_list_first_field_list_shallow
law golden_toonerr_list_first_field_list_shallow:
  {C.run_pure(["--decode"], T.ascii_bytes("l[1]:\n  - k[2]:\n    - a\n    - b\n", Nil{})) == C.Out{1n, "", "Expected 2 list array items, but got 0"} : C.Out}

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
  {C.run_pure(["--encode", "--indent", "0"], T.ascii_bytes("{\"a\":{\"b\":1},\"l\":[{\"x\":1},{\"y\":2}]}\n", Nil{})) == C.Out{0n, "a:\nb: 1\nl[2]:\n- x: 1\n- y: 2\n", ""} : C.Out}

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
  {C.run_pure(["--encode", "--key-folding", "safe"], T.ascii_bytes("[{\"c.d\": 7, \"c\": {\"d\": 1}}]\n", Nil{})) == C.Out{0n, "[1]:\n  - c.d: 7\n    c.d: 1\n", ""} : C.Out}

# S5.112 goldens/flag_flatten_depth_3
law golden_flag_flatten_depth_3:
  {C.run_pure(["--encode", "--key-folding", "safe", "--flatten-depth", "3"], T.ascii_bytes("{\"a\":{\"b\":{\"c\":{\"d\":{\"e\":1}}}}}\n", Nil{})) == C.Out{0n, "a.b.c:\n  d:\n    e: 1\n", ""} : C.Out}

# S5.112 goldens/fx_dec_indentation_errors_01
law golden_fx_dec_indentation_errors_01:
  {C.run_pure(["--decode", "--indent", "2"], T.ascii_bytes("a:\n   b: 1", Nil{})) == C.Out{1n, "", "Validation error at line 2: Indentation must be exact multiple of 2, but found 3 spaces"} : C.Out}

# S5.112 goldens/fx_dec_indentation_errors_04
law golden_fx_dec_indentation_errors_04:
  {C.run_pure(["--decode", "--indent", "4"], T.ascii_bytes("a:\n    b: 1", Nil{})) == C.Out{0n, "{\n    \"a\": {\n        \"b\": 1.0\n    }\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_indentation_errors_08
law golden_fx_dec_indentation_errors_08:
  {C.run_pure(["--decode"], T.ascii_bytes("text: \"hello\tworld\"", Nil{})) == C.Out{0n, "{\n  \"text\": \"hello\\tworld\"\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_indentation_errors_13
law golden_fx_dec_indentation_errors_13:
  {C.run_pure(["--decode"], T.ascii_bytes("a: 1\n\nb: 2", Nil{})) == C.Out{0n, "{\n  \"a\": 1.0,\n  \"b\": 2.0\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_blank_lines_01
law golden_fx_dec_blank_lines_01:
  {C.run_pure(["--decode"], T.ascii_bytes("items[3]:\n  - a\n\n  - b\n  - c", Nil{})) == C.Out{1n, "", "Line 3: Blank lines inside list array are not allowed in strict mode"} : C.Out}

# S5.112 goldens/toonedge_indent4
law golden_toonedge_indent4:
  {C.run_pure(["--decode", "--indent", "4"], T.ascii_bytes("a:\n    b:\n        c: 1\n", Nil{})) == C.Out{0n, "{\n    \"a\": {\n        \"b\": {\n            \"c\": 1.0\n        }\n    }\n}\n", ""} : C.Out}

# S5.112 goldens/toonedge_indent0_flat
law golden_toonedge_indent0_flat:
  {C.run_pure(["--decode", "--indent", "0"], T.ascii_bytes("a: 1\nb: 2\n", Nil{})) == C.Out{0n, "{\"a\":1.0,\"b\":2.0}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_indent_not_multiple
law golden_toonlenient_indent_not_multiple:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("outer:\n a: 1", Nil{})) == C.Out{0n, "{\n  \"outer\": {},\n  \"a\": 1.0\n}\n", ""} : C.Out}

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
  {C.run_pure(["--decode"], T.ascii_bytes("a[+2]: x,y\nb[02]: x,y\nc[ 2]: x,y\n", Nil{})) == C.Out{0n, "{\n  \"a\": [\n    \"x\",\n    \"y\"\n  ],\n  \"b\": [\n    \"x\",\n    \"y\"\n  ],\n  \"c[ 2]\": \"x,y\"\n}\n", ""} : C.Out}

# S5.112 goldens/toonedge_fields_space_only
law golden_toonedge_fields_space_only:
  {C.run_pure(["--decode"], T.ascii_bytes("items[1]{ }:\n  - 1\n", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    {\n      \"\": \"- 1\"\n    }\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_numbers_02
law golden_fx_dec_numbers_02:
  {C.run_pure(["--decode"], T.ascii_bytes("value: -1E+03", Nil{})) == C.Out{0n, "{\n  \"value\": -1000.0\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_numbers_03
law golden_fx_dec_numbers_03:
  {C.run_pure(["--decode"], T.ascii_bytes("value: 2.5e2", Nil{})) == C.Out{0n, "{\n  \"value\": 250.0\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_numbers_05
law golden_fx_dec_numbers_05:
  {C.run_pure(["--decode"], T.ascii_bytes("value: -0", Nil{})) == C.Out{0n, "{\n  \"value\": 0.0\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_numbers_10
law golden_fx_dec_numbers_10:
  {C.run_pure(["--decode"], T.ascii_bytes("value: 5E+00", Nil{})) == C.Out{0n, "{\n  \"value\": 5.0\n}\n", ""} : C.Out}

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
  {C.run_pure(["--decode"], T.ascii_bytes("items[2]{id,value}:\n  1,null\n  2,\"test\"", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    {\n      \"id\": 1.0,\n      \"value\": null\n    },\n    {\n      \"id\": 2.0,\n      \"value\": \"test\"\n    }\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_arrays_tabular_03
law golden_fx_dec_arrays_tabular_03:
  {C.run_pure(["--decode"], T.ascii_bytes("items[2]{id,note}:\n  1,\"a:b\"\n  2,\"c:d\"", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    {\n      \"id\": 1.0,\n      \"note\": \"a:b\"\n    },\n    {\n      \"id\": 2.0,\n      \"note\": \"c:d\"\n    }\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonedge_data_row_test
law golden_toonedge_data_row_test:
  {C.run_pure(["--decode"], T.ascii_bytes("t[1]{a,b}:\n  1,2\n  x: 4,5\n", Nil{})) == C.Out{0n, "{\n  \"t\": [\n    {\n      \"a\": 1.0,\n      \"b\": 2.0\n    }\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_blank_lines_05
law golden_fx_dec_blank_lines_05:
  {C.run_pure(["--decode"], T.ascii_bytes("outer[2]:\n  - inner[2]:\n    - a\n\n    - b\n  - x", Nil{})) == C.Out{1n, "", "Expected 2 list array items, but got 0"} : C.Out}

# S5.112 goldens/fx_dec_blank_lines_11
law golden_fx_dec_blank_lines_11:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[3]:\n  - a\n\n  - b\n  - c", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\",\n    \"b\",\n    \"c\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_validation_errors_01
law golden_fx_dec_validation_errors_01:
  {C.run_pure(["--decode"], T.ascii_bytes("tags[2]: a,b,c", Nil{})) == C.Out{1n, "", "Expected 2 inline array items, but got 3"} : C.Out}

# S5.112 goldens/toonlenient_row_width_short
law golden_toonlenient_row_width_short:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("rows[1]{a,b,c}:\n  1,2", Nil{})) == C.Out{0n, "{\n  \"rows\": [\n    {\n      \"a\": 1.0,\n      \"b\": 2.0,\n      \"c\": null\n    }\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_extra_tabular_rows
law golden_toonlenient_extra_tabular_rows:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("rows[1]{id}:\n  1\n  2", Nil{})) == C.Out{0n, "{\n  \"rows\": [\n    {\n      \"id\": 1.0\n    }\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_blank_in_tabular
law golden_toonlenient_blank_in_tabular:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("rows[2]{id}:\n  1\n\n  2", Nil{})) == C.Out{0n, "{\n  \"rows\": [\n    {\n      \"id\": 1.0\n    },\n    {\n      \"id\": 2.0\n    }\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_path_expansion_01
law golden_fx_dec_path_expansion_01:
  {C.run_pure(["--decode", "--expand-paths", "safe"], T.ascii_bytes("a.b.c: 1", Nil{})) == C.Out{0n, "{\n  \"a\": {\n    \"b\": {\n      \"c\": 1.0\n    }\n  }\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_path_expansion_03
law golden_fx_dec_path_expansion_03:
  {C.run_pure(["--decode", "--expand-paths", "safe"], T.ascii_bytes("a.b.items[2]{id,name}:\n  1,A\n  2,B", Nil{})) == C.Out{0n, "{\n  \"a\": {\n    \"b\": {\n      \"items\": [\n        {\n          \"id\": 1.0,\n          \"name\": \"A\"\n        },\n        {\n          \"id\": 2.0,\n          \"name\": \"B\"\n        }\n      ]\n    }\n  }\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_path_expansion_05
law golden_fx_dec_path_expansion_05:
  {C.run_pure(["--decode", "--expand-paths", "safe"], T.ascii_bytes("a.b.c: 1\na.b.d: 2\na.e: 3", Nil{})) == C.Out{0n, "{\n  \"a\": {\n    \"b\": {\n      \"c\": 1.0,\n      \"d\": 2.0\n    },\n    \"e\": 3.0\n  }\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_path_expansion_08
law golden_fx_dec_path_expansion_08:
  {C.run_pure(["--decode", "--expand-paths", "safe", "--no-strict"], T.ascii_bytes("a.b: 1\na: 2", Nil{})) == C.Out{0n, "{\n  \"a\": 2.0\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_path_expansion_10
law golden_fx_dec_path_expansion_10:
  {C.run_pure(["--decode", "--expand-paths", "safe"], T.ascii_bytes("a.b: 1\n\"c.d\": 2", Nil{})) == C.Out{0n, "{\n  \"a\": {\n    \"b\": 1.0\n  },\n  \"c.d\": 2.0\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_path_expansion_11
law golden_fx_dec_path_expansion_11:
  {C.run_pure(["--decode", "--expand-paths", "safe"], T.ascii_bytes("full-name.x: 1", Nil{})) == C.Out{0n, "{\n  \"full-name.x\": 1.0\n}\n", ""} : C.Out}

# S5.112 goldens/toonedge_expand_quoted_unquoted_same_key
law golden_toonedge_expand_quoted_unquoted_same_key:
  {C.run_pure(["--decode", "--expand-paths", "safe"], T.ascii_bytes("\"a.b\": 1\na.b: 2\n", Nil{})) == C.Out{1n, "", "Path expansion conflict at key \"a.b\": cannot merge primitive with primitive"} : C.Out}

# S5.112 goldens/decnum_root_negative_zero
law golden_decnum_root_negative_zero:
  {C.run_pure(["--decode"], T.ascii_bytes("-0", Nil{})) == C.Out{0n, "0.0\n", ""} : C.Out}

# S5.112 goldens/fx_dec_numbers_06
law golden_fx_dec_numbers_06:
  {C.run_pure(["--decode"], T.ascii_bytes("value: -0.0", Nil{})) == C.Out{0n, "{\n  \"value\": 0.0\n}\n", ""} : C.Out}

# S5.112 goldens/fx_dec_numbers_08
law golden_fx_dec_numbers_08:
  {C.run_pure(["--decode"], T.ascii_bytes("value: 05", Nil{})) == C.Out{0n, "{\n  \"value\": \"05\"\n}\n", ""} : C.Out}

# S5.112 goldens/jsonout_root_array
law golden_jsonout_root_array:
  {C.run_pure(["--decode"], T.ascii_bytes("[3]: 1,two,true", Nil{})) == C.Out{0n, "[\n  1.0,\n  \"two\",\n  true\n]\n", ""} : C.Out}

# S5.112 goldens/jsonout_duplicate_keys
law golden_jsonout_duplicate_keys:
  {C.run_pure(["--decode"], T.ascii_bytes("a: 1\na: 2\nb: 3\n", Nil{})) == C.Out{0n, "{\n  \"a\": 1.0,\n  \"a\": 2.0,\n  \"b\": 3.0\n}\n", ""} : C.Out}

# S5.112 goldens/flag_decode_indent_0
law golden_flag_decode_indent_0:
  {C.run_pure(["-d", "--indent", "0"], T.ascii_bytes("a: 1\nb[2]: 1,2\n", Nil{})) == C.Out{0n, "{\"a\":1.0,\"b\":[1.0,2.0]}\n", ""} : C.Out}

# S5.112 goldens/flag_decode_indent_4
law golden_flag_decode_indent_4:
  {C.run_pure(["-d", "--indent", "4"], T.ascii_bytes("a:\n    b: 1\n", Nil{})) == C.Out{0n, "{\n    \"a\": {\n        \"b\": 1.0\n    }\n}\n", ""} : C.Out}

# S5.112 goldens/encnum_root_negative_zero
law golden_encnum_root_negative_zero:
  {C.run_pure(["--encode"], T.ascii_bytes("-0.0\n", Nil{})) == C.Out{0n, "0\n", ""} : C.Out}

# S5.112 goldens/encnum_overflow_positive
law golden_encnum_overflow_positive:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"a\":1e309}\n", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: number out of range at line 1 column 10"} : C.Out}

# S5.112 goldens/encnum_overflow_negative
law golden_encnum_overflow_negative:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"a\":-1e309}\n", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: number out of range at line 1 column 11"} : C.Out}

# S5.112 goldens/fx_enc_arrays_objects_01
law golden_fx_enc_arrays_objects_01:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"items\":[{\"id\":1,\"name\":\"First\"},{\"id\":2,\"name\":\"Second\",\"extra\":true}]}\n", Nil{})) == C.Out{0n, "items[2]:\n  - id: 1\n    name: First\n  - id: 2\n    name: Second\n    extra: true\n", ""} : C.Out}

# S5.112 goldens/happy_readme_users
law golden_happy_readme_users:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"users\":[{\"id\":1,\"name\":\"Alice\"},{\"id\":2,\"name\":\"Bob\"}]}\n", Nil{})) == C.Out{0n, "users[2]{id,name}:\n  1,Alice\n  2,Bob\n", ""} : C.Out}

# S5.112 goldens/happy_readme_users_decode
law golden_happy_readme_users_decode:
  {C.run_pure(["--decode"], T.ascii_bytes("users[2]{id,name}:\n  1,Alice\n  2,Bob\n", Nil{})) == C.Out{0n, "{\n  \"users\": [\n    {\n      \"id\": 1.0,\n      \"name\": \"Alice\"\n    },\n    {\n      \"id\": 2.0,\n      \"name\": \"Bob\"\n    }\n  ]\n}\n", ""} : C.Out}

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
  {C.run_pure(["-d", "-"], T.ascii_bytes("name: Alice\nage: 30\ntags[2]: a,b\n", Nil{})) == C.Out{0n, "{\n  \"name\": \"Alice\",\n  \"age\": 30.0,\n  \"tags\": [\n    \"a\",\n    \"b\"\n  ]\n}\n", ""} : C.Out}

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
  {C.run_pure(["--decode", "--expand-paths", "safe"], T.ascii_bytes("exr.k: 1\njda.k: 2\nexr.m: 3\njda.k.z: 4\n", Nil{})) == C.Out{1n, "", "Path expansion conflict at segment \"k\": expected object but found primitive"} : C.Out}

# S4.246 goldens/toonedge_expand_hash_collision_lenient (round 7: every key of this document lands in ONE bucket of the hashed carriers)
law golden_toonedge_expand_hash_collision_lenient:
  {C.run_pure(["--decode", "--expand-paths", "safe", "--no-strict"], T.ascii_bytes("exr.k: 1\njda.k: 2\nexr.m: 3\njda.k.z: 4\n", Nil{})) == C.Out{0n, "{\n  \"exr\": {\n    \"k\": 1.0,\n    \"m\": 3.0\n  },\n  \"jda\": {\n    \"k\": {\n      \"z\": 4.0\n    }\n  }\n}\n", ""} : C.Out}

# S3.25 goldens/toonedge_repeated_keys_hash_collision (round 7: every key of this document lands in ONE bucket of the hashed carriers)
law golden_toonedge_repeated_keys_hash_collision:
  {C.run_pure(["--decode"], T.ascii_bytes("exr: 1\njda: 2\nexr: 3\n", Nil{})) == C.Out{0n, "{\n  \"exr\": 1.0,\n  \"jda\": 2.0,\n  \"exr\": 3.0\n}\n", ""} : C.Out}

# S4.245 goldens/toonerr_expand_repeated_hash_collision (round 7: every key of this document lands in ONE bucket of the hashed carriers)
law golden_toonerr_expand_repeated_hash_collision:
  {C.run_pure(["--decode", "--expand-paths", "safe"], T.ascii_bytes("exr: 1\njda: 2\nexr: 3\nt[2]{jda,exr}:\n  1,2\n  3,4\n", Nil{})) == C.Out{1n, "", "Path expansion conflict at key \"exr\": cannot merge primitive with primitive"} : C.Out}

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
