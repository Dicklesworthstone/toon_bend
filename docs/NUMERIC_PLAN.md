# Numeric plan — the Bend 2 port of Toon

<!-- Phase 2 document, written BEFORE any Bend arithmetic. Bend has U32
     (wrapping 32-bit words), F32, and Nat (exact, ≤ 2^48−1, and a source
     literal ≤ 4294967295n). Anything else in the original (Python int,
     i64/u64, f64, decimal) must be mapped here with its proof or golden. -->

**The shape of the problem.** The original holds every JSON number in an `f64` and the goldens show four distinct
text/value algorithms (S4.100–S4.175): a truncating, twice-rounding JSON reader on the encode side; a correctly rounded
token reader on the decode side; and two shortest-digit printers that differ in layout and in how they break an exact tie.
Bend has no f64. **No `F32` is used anywhere in this port and there is no budgeted output class**: every number is carried
as an exact software binary64 and every IEEE operation the original performs is reproduced as "exact rational result, one
round-to-nearest-even", over big naturals.

## 1. Representations

| choice | when | proof | golden |
|---|---|---|---|
| `U32` limbs, 16 bits each (`BigNat` = little-endian `List<&2, U32>`, no high zero limb) | every quantity that can pass 2^48 − 1: the u64 significand S, 53-bit significands and their 106-bit products, 10^k up to k = 308 and beyond for long tokens, declared array lengths up to 2^64 − 1, option values up to 2^64 − 1 | a product of two limbs plus two carries is at most 65535² + 2·65535 = 2^32 − 1, so no `U32` operation wraps; closed laws on small values (`bn_*` laws); the carrier was checked against Python on sums, differences, products, shifts, bit lengths and comparisons before the port (scratch probe, PORT_STATE) | `encnum_u64_boundary`, `encnum_big_ints`, `toonerr_length_u64_max`, `flag_flatten_depth_big` |
| software binary64 `F64` = sign, biased exponent `tb` (a `Nat`, value = man × 2^(tb − 100000)), significand `man` (a `BigNat` of at most 53 bits); zero is `man = Nil`; infinity is its own constructor; NaN cannot arise (S4.117) | every JSON and TOON number value; the `--stats` percentage | closed laws on exactly representable values (`f64_*` laws); one rounding def (`f64.round`) serves every operation, so one set of laws covers from-integer, multiply, divide and from-decimal | `encnum_*`, `decnum_*`, `decfmt_*`, `stats_*` (53 cases), and the 3000 numeric cells of `large_tabular_1500` |
| `Nat` | counts, sizes, depths, line and column numbers, indices, the indent width, digit counts, decimal exponents: all bounded by the input length or a small constant | the bound is stated per row below; the shell refuses nothing for size because a `Nat` count of input bytes fits 2^48 − 1 for any input this host can hold (256 TiB) | every case |
| sign and magnitude `Int` = `Pos{Nat}` / `Neg{Nat}` | the signed decimal exponents E10, T, q and the shortest-digit exponent k | total defs with no saturating subtraction across zero: `Int.add`, `Int.cmp`; closed laws | `encnum_exponents`, `encnum_exp_i32_edge`, `decfmt_exp_shapes` |
| two-word / fixed point | not needed: the u64 quantities go through `BigNat`, and no decimal has a fixed scale | n/a | n/a |
| `F32` | **never** | n/a | n/a |

## 2. Inventory (one row per S7 clause)

| S7.n | quantity | original type | evidence of range | Bend rep | exact or budget | proof | golden |
|---|---|---|---|---|---|---|---|
| S7.1 | `--indent` value | i64 parse, range 0..=16, then u8 | `usage_bad_indent_huge`, `flag_indent_16_encode` | validated on the digit text (sign, digits as `BigNat` U32 limbs compared with 2^63 for the "too large" message), then `Nat` ≤ 16 | exact | golden only (argv text is shell input) | `usage_bad_indent_17`, `usage_bad_indent_256`, `usage_bad_indent_huge`, `usage_bad_indent_negative`, `flag_indent_0_encode` |
| S7.2 | `--flatten-depth` value | usize (u64), absent = 2^64 − 1 | `flag_flatten_depth_big`, `flag_flatten_depth_too_big` | digits as `BigNat` (U32 limbs) compared with 2^64 − 1 for validity; then a `Nat` budget saturated at 2^40 (a fold chain is shorter than the input, so every value ≥ 2^40 behaves as unlimited, S7.2's own note) | exact | golden | `flag_flatten_depth_3`, `flag_flatten_depth_big`, `flag_flatten_depth_too_big`, `enc_fold_budget_threading_4` |
| S7.3 | c (non-whitespace scalar count), w (word count) | usize | `stats_ratio_5` (c = 1520, w = 321) | `Nat`; bound: ≤ input length in code points < 2^48 | exact | golden | `stats_ratio_5`, `stats_unicode_whitespace` |
| S7.4 | E = max(⌊c/4⌋, w, 1) | usize | `stats_ratio_5` | `Nat` (`Nat.div` by 4 truncates, as the original does) | exact | closed law `stats_estimate_small` | `stats_no_savings`, `stats_empty_object` |
| S7.5 | D = J − T saturating at 0 | usize saturating | `stats_unicode_whitespace` (0) | `Nat.sub` (saturating, the same semantics) | exact | closed law | `stats_unicode_whitespace`, `stats_ratio_5` |
| S7.6 | q = D ⊘ J, p = q ⊗ 100 | binary64, two operations | `stats_f64_below_tie`, `stats_f64_above_tie` | software `F64` over U32 limbs: `f64.from_nat`, `f64.div`, `f64.mul` (each one RNE) | exact | closed laws on 1/16 and 3/16 | `stats_users`, `stats_ratio_2`, `stats_f64_below_tie`, `stats_f64_above_tie` |
| S7.7 | printed percentage, one decimal, ties to even on the exact binary value | f64 `{:.1}` | `stats_tie_to_even_down`, `stats_percent_100` | exact decimal expansion of man × 2^e through `BigNat` (U32 limbs): scale by 10, split integer part, compare the remainder with one half | exact | closed laws `stats_pct_6_25`, `stats_pct_18_75` | `stats_tie_to_even_down`, `stats_tie_to_even_up`, `stats_percent_100` |
| S7.8 | Jaro similarity compared with 0.7 | f64 | `usage_enum_similar_boundary_30`, `usage_enum_similar_boundary_31` | `Nat` cross-multiplication of the exact rational (m/\|a\| + m/\|b\| + (m − t)/m)/3 against 7/10; all factors are string lengths below 100, so products stay below 2^48; the rule is "≥ 7/10" because the original's f64 evaluation of an exact 7/10 is 0.70000000000000007 (S7.8) | exact | golden (the equivalence with the f64 test is the extractor's argument plus 566 oracle runs) | `usage_similar_arg`, `usage_similar_arg_tie`, `usage_enum_similar_boundary_30`, `usage_enum_similar_boundary_31` |
| S7.9 | process exit status | i32 | 0, 1, 2 | `U32` literal passed to `IO.die` | exact | golden | `usage_help`, `usage_none`, `usage_unknown_flag` |
| S7.10 | OS error number in messages | errno | 2, 21 in the corpus | the `U32` the effect's `Fail` carries, printed with `U32.show` (OQ-008: identical on the three lanes) | exact | golden | `usage_missing_file`, `usage_dir_as_input`, `usage_output_bad_dir` |
| S7.11 | 8192-byte threshold of the silent write failure | usize | `io_output_dev_full_8192` / `_8193` | `Nat` count of the output's UTF-8 bytes (1–4 per code point, counted while the output is built) | exact | golden | `io_output_dev_full_8192`, `io_output_dev_full_8193` |
| S7.12 | fixed text sizes | bytes | help 1570, version 11 | not computed: the texts are literals; `Nat` only where S7.11 counts them | exact | golden | `usage_help`, `usage_version` |
| S7.20 | every number value, encode side | f64 | `encnum_extremes` | software `F64` (U32 limbs) | exact | `f64_*` closed laws | `encnum_extremes`, `encnum_pow10_slow_path` |
| S7.21 | S, the decimal significand | u64 | `encnum_u64_boundary` | `BigNat` (U32 limbs); the fit test is the exact comparison S > 1844674407370955161, or equal with d > 5 (S4.102), so S never exceeds 2^64 − 1 | exact | closed law `serde_fit_boundary` | `encnum_u64_boundary`, `encnum_big_ints`, `encnum_frac_long` |
| S7.22 | count of discarded integer digits | i32 | `encnum_big_ints` (+10) | `Nat`; bound: ≤ literal length | exact | golden | `encnum_big_ints`, `encnum_u64_boundary` |
| S7.23 | count of accepted fraction digits | i32 | `encnum_frac_long` (−40) | `Nat`; bound: ≤ literal length | exact | golden | `encnum_frac_long` |
| S7.24 | X, the written exponent | i32 with the overflow test of S4.107 | `encnum_exp_i32_edge` | `Nat` with the same test (X > 214748364, or equal with d > 7), so X ≤ 2147483647 < 2^48 | exact | golden | `encnum_exp_i32_edge`, `encnum_overflow_huge_exponent` |
| S7.25 | T, the total decimal exponent | i32 saturating | `encnum_extremes` | `Int` (sign and `Nat` magnitude), exact sum; the original's saturation is unobservable (S4.109); \|T\| < 2^32 + literal length | exact | golden | `encnum_extremes`, `encnum_overflow_positive` |
| S7.26 | index into the power-of-ten table | usize 0..308 | `encnum_pow10_each` | `Nat`; P(k) is computed as `f64.from_dec(1, k)`, the RNE of 10^k, which is what the table holds (S4.112); the seven pinned bit patterns are closed laws | exact | closed laws `pow10_22`, `pow10_23`, `pow10_292` | `encnum_pow10_each`, `encnum_extremes` |
| S7.27 | negative integer literal | i64 | `encnum_big_ints` | no separate carrier: one rule, sign × G(S, T) (S4.110) over `F64` (U32 limbs) | exact | golden | `encnum_big_ints`, `encnum_ints` |
| S7.28 | non-negative integer literal | u64 | `encnum_big_ints` | the same rule over `F64` (U32 limbs) | exact | closed law `f64_from_2p53_plus_1` | `encnum_big_ints`, `encnum_ints` |
| S7.29 | every number value, decode side | f64, correctly rounded | `decnum_extremes` | software `F64` (U32 limbs) from the exact decimal: D × 10^E as a `BigNat`, or a bit-by-bit quotient with a sticky remainder when E < 0, then one RNE (`f64.round`); tokens whose leading digit's exponent is above 310 or below −345 are decided without big arithmetic | exact | closed laws; scratch probe agreed with Python `float` on 6618 of 6618 tokens | `decnum_extremes`, `decnum_long_mantissa`, `decnum_exact_halfway`, `decnum_finite_edge` |
| S7.30 | count of shortest digits n ≤ 17 | small integer | `decfmt_exp_upper_boundary` | `Nat` (a list length); the generator stops by its own termination tests within 17 digits and carries fuel 25 | exact | closed laws | `decnum_long_mantissa`, `encnum_long_mantissa` |
| S7.31 | q, the decimal exponent of the first digit | i32 | `decfmt_exp_shapes` (−324 … +308) | `Int` derived from a biased `Nat` k (k + 78913 ≥ 0 by construction) | exact | closed laws | `decfmt_exp_shapes`, `decnum_extremes`, `decfmt_exp_lower_boundary`, `decfmt_exp_upper_boundary` |
| S7.32 | length of a TOON number text | bytes | `encnum_extremes` (326) | not computed; the text is built digit by digit with `Nat` counters for the zero padding (≤ 324) | exact | golden | `encnum_extremes` |
| S7.33 | length of a JSON number text | bytes ≤ 24 | `decnum_extremes` | `Nat` counters for the zero padding only (the length itself is never computed; the text is built from the digits and q) | exact | golden | `decnum_extremes`, `decnum_ints` |
| S7.34 | declared array length N | usize (u64) | `toonerr_length_u64_max` | digits as `BigNat` (U32 limbs): compared with 2^64 − 1 (above: not a header) and with 100000000 (above: the cap error, printing the `BigNat` in decimal); at or below the cap it becomes a `Nat` | exact | closed law `length_cap_boundary` | `toonerr_length_at_cap`, `toonerr_length_over_cap`, `toonerr_length_u64_max`, `toonedge_length_forms` |
| S7.35 | element count written into a header | usize | `large_tabular_1500` | `Nat`, carried beside the collection while it is built (never recounted in a loop) | exact | golden | `large_tabular_1500`, `encnum_in_arrays` |
| S7.36 | expected and actual counts in validation messages | usize | `toonerr_length_at_cap` | `Nat` ≤ 100000000 (expected) and ≤ line count (actual) | exact | golden | `toonerr_too_few_list_items`, `toonerr_row_width_short` |
| S7.37 | line number in decode messages | usize, 1-based | `toonerr_indent_three` | `Nat` ≤ line count | exact | golden | `toonerr_indent_three`, `toonedge_indent0_indented` |
| S7.38 | indent width option | u8 0..16 | `flag_indent_16_encode` | `Nat` ≤ 16 | exact | golden | `flag_indent_0_encode`, `decnum_compact` |
| S7.39 | leading-space count and depth | usize, truncating division, 0 when the width is 0 | `toonlenient_indent_three` | `Nat`; `Nat.div` truncates and `a/0n = 0` in Bend, which is the original's width-0 rule, and it is still written as an explicit case so no reader has to know that | exact | closed law `depth_of_indent` | `toonerr_indent_three`, `toonlenient_indent_three`, `toonedge_indent0_indented_lenient` |
| S7.40 | flatten depth option | usize | as S7.2 | as S7.2: `Nat` budget saturated at 2^40 | exact | golden | `flag_flatten_depth_3`, `flag_flatten_depth_big` |
| S7.41 | nesting limits 256 and 128 | usize constants | `jsonerr_deep_129`, `jsonout_expand_deep_limit` | `Nat` counters compared with the constants | exact | closed laws on the counter at 127/128 | `jsonerr_deep_128`, `jsonerr_deep_129`, `toonedge_expand_segments_253` |
| S7.42 | line and column in JSON error messages | usize; column in BYTES | `jsonerr_unicode_in_error_col` | `Nat` counters advanced per input byte: the JSON reader runs over the byte list, never over code points | exact | golden | `jsonerr_unicode_in_error_col`, `jsonerr_second_line_error`, `encnum_mixed_digits` |
| S7.43 | `--stats` counts and percentage | usize, f64 | as S7.3–S7.7 | `Nat` counts, software `F64` (U32 limbs) | exact | as S7.6, S7.7 | `stats_small`, `stats_ratio_1` |

## 3. Output classes (the harness enforces both, separately)

| class | outputs | comparison |
|---|---|---|
| exact | every byte of stdout and stderr and every exit code, numbers included | byte-identical on every lane |
| budgeted | none | n/a |

No budgeted outputs. A number that cannot be matched exactly would be a bug, not a tolerance.

## 4. Printing contract

- TOON number text (S4.130–S4.133, S5.30–S5.35): `0` for zero; otherwise the shortest round-trip digits with an exact tie
  going to the larger magnitude, laid out without any exponent (integers without `.0`, zeros padded on either side).
- JSON number text (S4.170–S4.174, S5.36–S5.42): `0.0` for zero; otherwise the shortest round-trip digits with an exact tie
  going to the even last digit, plain decimal with a forced `.0` when −5 ≤ q ≤ 15, otherwise `d[.ddd]e±X`.
- Both come from one digit generator (`f64.shortest`) with a tie-mode argument and two layout defs. `Nat.show` and `U32.show`
  print counts, lengths, line numbers and errno values. `F32.show` is never called.

## 5. Bridges the proofs cannot cross (stated, not hidden)

- The laws about the number core are **closed**: each pins one value (a table entry's bit pattern, a tie, a boundary). No
  quantified law says "this is IEEE-754"; that equivalence is golden-tested (53 number cases, the 3000 cells of
  `large_tabular_1500`) and was model-checked by the numbers extractor on 22265 + 8162 encode literals and 35434 decode
  outputs against the oracle. Closed laws are kept small: the checker's normalizer runs the limb arithmetic natively in `U32`,
  and no law routes through `U32.to_nat` of a large word or `Nat.read` of a long digit string.
- Rust's `Display` digit rule is an observed law (std source is not on this host): it held on about 34000 oracle values
  including 356 exact ties.
- `null` from a number (OQ-C1) is implemented but unreachable; nothing proves unreachability.

## 6. Encoding contract

| boundary | rule | evidence |
|---|---|---|
| input bytes (stdin or file) | read as bytes to EOF (`File.read_bytes` in a loop; short reads are not EOF), then decoded as **strict** UTF-8: overlong forms, surrogates, values above U+10FFFF and truncated sequences are rejected with the original's `stream did not contain valid UTF-8` message (S9, part A); `File.read` is never used because it decodes with replacement | `jsonerr_invalid_utf8_stdin`, `jsonerr_invalid_utf8_file`, `jsonerr_overlong_utf8`, `jsonerr_truncated_utf8`, `toonerr_invalid_utf8_stdin` |
| BOM, CR | kept as data: U+FEFF is an ordinary character (it becomes part of the first key, or a JSON `expected value` error); `\r` stays in the line (S2.113) | `jsonerr_bom_prefixed`, `toonerr_bom`, `toonerr_crlf`, `toonedge_crlf_bare_dash` |
| JSON reader positions | the reader consumes the byte list so that line and column are byte counts (S7.42); string contents are decoded from those bytes (already validated) | `jsonerr_unicode_in_error_col` |
| characters | a `Char` is a Unicode scalar value; `\uXXXX` escapes and surrogate pairs are range-checked before `Chr{…}` is built (an unchecked surrogate is a lane difference in Bend) | `encstr_escapes_in`, `jsonerr_lone_high_surrogate`, `jsonerr_lone_low_surrogate` |
| White_Space and control classes | hand-written tables: the 25 White_Space code points (S4.8) for trims, blank lines, quoting and `--stats`; the Cc class U+0000–U+001F, U+007F–U+009F for the second JSON writer. Base's `Char.is_space` is ASCII-only and is not used | `encstr_ws_edge_sweep`, `decnum_trim_unicode`, `stats_unicode_whitespace`, `decstr_control_out_expand` |
| output | UTF-8 through `IO.write` / `File.write`, which re-encode code points; NUL is written as one 0 byte | `encstr_escapes_in` |
| argv | `IO.args()` strings (decoded with replacement by the runtime): DISC-004 for words that are not UTF-8 | `usage_indent_arabic_digit`, `auto_fullwidth_ext` |
