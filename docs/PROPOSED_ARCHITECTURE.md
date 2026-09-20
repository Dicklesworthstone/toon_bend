# Proposed architecture — the Bend 2 port of Toon

<!-- Phase 2 document. Derived from the spec and from reference Bend
     programs (bend2-mega-skill skeletons, the example port), not invented.
     Its whole job is the CORE/SHELL split: what is pure (and therefore
     provable) versus what is an effect (and therefore only golden-tested).
     Every spec clause gets a home and an evidence kind here. -->

Three facts about Bend's checker shape everything below; each was established by a probe before this document was written
(PORT_STATE "feasibility probes"), so none is a guess:

1. **No mutual recursion and no mutually recursive types.** A rose tree written as "value ⇄ list of values" is refused, and so is
   a phase-sum wrapper around it. ONE self-recursive `Data` type whose child chains are its own constructors passes structural
   recursion. `Json` is that type; every traversal of it is a single def; helpers take verdicts and already-recursed results.
2. **The lexicographic measure (input, stack) is accepted**: a def may either consume a matched piece of its first parameter, or pass
   it unchanged and consume a matched piece of its second. The JSON reader and the TOON decoder are pushdown machines of that shape:
   no fuel, no `@unsafe`.
3. **The JS and interpreter lanes die near 3×10⁴ nested frames.** Every traversal whose length the input controls (bytes, characters,
   lines, rows, items, fields) is tail-recursive: accumulate reversed, reverse once. Only nesting depth recurses naturally.

## 1. Core / shell split

| clause group | lives in | kind | evidence |
|---|---|---|---|
| S1.1–S1.22, S1.30–S1.35, S1.60–S1.63, S1.70–S1.87, S1.130–S1.135, S1.150–S1.155 argv model: spellings, value domains, help and version text, error shapes, which error wins, ignored options | core (`cli.bend`): a pure def from the argv list to `Parsed` = options, or a usage verdict carrying the exact text and exit code | spec twin | golden (usage_*, flag_*, auto_*) + closed law on the similarity formula |
| S4.300–S4.304 mode detection; S4.310–S4.319 `--stats` | core (`cli.bend`) | spec twin | golden (auto_*, stats_*) + closed laws on the estimate and the percent |
| S2.1–S2.35, S2.40–S2.47 JSON text grammar and error positions; S2.50–S2.55 conversion; S9.50–S9.83 JSON error rows | core (`json.bend`): a pushdown machine over the input BYTES with line and column counters | spec twin | golden (jsonerr_*, encstr_*) + closed laws on small documents |
| S3.1–S3.17, S3.20–S3.29 data model | core (`json.bend`, `decode.bend`): `Json`, `Event`, `Line`, `Node` | data | golden; law `events_build_value` (round trip value → events → value) |
| S4.1–S4.84 encoder; S5.1–S5.12 TOON format | core (`encode.bend`): structural recursion over `Json`, lines accumulated in reverse | spec twin (+ fast twin for tabular rows in Phase 5) | golden (fx_enc_*, enc_*, encstr_*) + law `unescape_escape` + closed goldens |
| S4.100–S4.122 JSON number reading; S4.130–S4.134 TOON number text; S4.140–S4.147 token classification; S4.160–S4.162 numeric-like; S4.170–S4.175 JSON number text; S4.190–S4.193 lengths; S5.30–S5.45 number layouts; S9.200–S9.212 number errors | core (`bignat.bend`, `f64.bend`) | spec twin | golden (encnum_*, decnum_*, decfmt_*) + closed laws (table entries, ties, boundaries) |
| S2.100–S2.114 scanning; S2.120–S2.126 tokens; S2.130–S2.140, S2.150 headers and markers; S4.200–S4.207, S4.210–S4.217, S4.220–S4.227 structural decoding; S9.100–S9.119, S9.130–S9.132, S9.140–S9.147 decode errors | core (`decode.bend`): scanner, then a pushdown machine over the line list emitting events in reverse | spec twin | golden (fx_dec_*, decstr_*, toonerr_*, toonlenient_*, toonedge_*) + closed laws on the scanner and the header parser |
| S4.240–S4.249 path expansion | core (`decode.bend`): structural recursion over the built value | spec twin | golden (jsonout_expand_*, fx_dec_path_expansion_*) + closed laws |
| S5.50–S5.78 the two JSON writers | core (`json.bend`): writer A folds the event list with an explicit context stack; writer B recurses over `Json` | spec twin | golden (jsonout_*, decstr_control_out*) + closed laws on the two escape tables |
| S5.100–S5.113 output framing, streams, success and statistics lines | core builds the texts (`cli.bend`); shell writes them in the stated order | spec twin / shell | golden (flag_output_*, stats_*) |
| S8.1–S8.17 effects; S9.1–S9.22 I/O and usage error rows | shell (`main.bend`): one def per effect and one per verdict mapping; no branch on data | shell | golden (usage_*, io_*, flag_*) |

Rule: the shell decides *whether* and *when*; the core decides *what*. `main.bend` is the only file whose types mention `IO`.
A whole run is one pure def, `Cli.run(argv, input bytes or read failure) -> Plan`, where `Plan` lists what to write where and
the exit code; the shell executes the plan.

## 2. Module map

| def / type | implements | twin kind | input owner | notes |
|---|---|---|---|---|
| `type BigNat` (= `List<&2, U32>`), `bn.add/sub/cmp/mul/mul_small/shl/shr/bitlen/divmod/pow10/from_dec/show` | S7.21, S7.34, S4.102, S4.190 | spec | consumes its operands; `+` where a value is compared and then used | little-endian 16-bit limbs; no high zero limb; `bn.cmp`, `bn.add` recurse over limbs (bounded by the number size, not the input) |
| `type F64`, `f64.round`, `f64.from_nat`, `f64.mul`, `f64.div`, `f64.from_dec` | S4.111–S4.116, S4.143, S7.6 | spec | consumes | one rounding def serves every operation (NUMERIC_PLAN §1) |
| `f64.serde_read` (S, E10, X, T, the fit tests, the three division steps) | S4.100–S4.110, S4.117–S4.122, S9.200–S9.209 | spec | consumes the literal's digit lists | returns `Result`: a value, or the `number out of range` verdict with the byte offset |
| `f64.shortest` (tie mode argument), `f64.show_toon`, `f64.show_json` | S4.130–S4.134, S4.170–S4.175, S5.30–S5.45 | spec | consumes the `F64` | Burger–Dybvig free-format generation over `BigNat`; fuel 25 (S7.30) |
| `num.is_literal`, `num.is_like`, `num.token` | S4.140–S4.147, S4.160–S4.162 | spec | borrows the text (`+`) | two grammars, deliberately separate defs (S4.162) |
| `text.utf8_decode`, `text.is_ws`, `text.is_cc`, `text.trim`, `text.rev_*` | S2.100, S2.106, S4.8, NUMERIC_PLAN §6 | spec | consumes the byte list | strict decoder; hand-written White_Space and Cc tables |
| `type Json` (JNull, JBool, JNum, JStr, JArr, JObj, plus the chains JNil, JCons, JENil, JECons) | S3.1–S3.17, S6.10–S6.12 | data | | one self-recursive type; objects keep insertion order; `JNum` holds an `F64` |
| `json.read` (pushdown machine over bytes) | S2.1–S2.35, S2.40–S2.47, S2.50–S2.55, S9.50–S9.83 | spec | consumes the byte list; the stack holds reversed partial containers | depth counter for the 128 limit (S7.41); duplicate keys: last value, first position (S6.10) |
| `json.write_a` (events → text), `json.write_b` (`Json` → text), `json.str_a`, `json.str_b` | S5.50–S5.78 | spec | consume | two escape tables (C-3) |
| `enc.value_text`, `enc.key_text`, `enc.needs_quote`, `enc.escape` | S4.3–S4.23, S5.1–S5.12 | spec | borrow (`+`) | the ten quoting conditions as ten verdict defs |
| `enc.header`, `enc.join`, `enc.classify` (the five-step array strategy), `enc.tabular_header` | S4.24–S4.39 | spec | borrow the array chain | verdict defs only; they never recurse into `enc.emit` |
| `enc.fold` (chain walk, identifier rule, sibling and root-literal checks, budget) | S4.63–S4.84, S3.16 | spec | borrows the field | returns a `Fold` verdict: none, leaf, or remainder |
| `enc.emit` (ONE def over `Json` with a context parameter: root, fields at depth d, list items at depth d, first field of a list item) | S4.1–S4.2, S4.40–S4.62 | spec | consumes the value; lines accumulated in reverse | depth recursion is natural; siblings are a tail call; Phase 5 adds a second def `enc.rows_par` for tabular rows, bound to `enc.rows_seq` by a law (§7) |
| `type Line`, `dec.scan` | S2.100–S2.114, S9.100–S9.102 | spec | consumes the character list | all lines are scanned before any structure is decoded (S2.111) |
| `dec.header`, `dec.split`, `dec.key`, `dec.string`, `dec.prim` | S2.120–S2.140, S2.150, S9.103–S9.109 | spec | borrow the content | byte-position searches of the original become character-list walks with the same quote state |
| `type Event`, `type Frame`, `dec.run` (pushdown machine over the line list) | S3.20–S3.29, S4.200–S4.227, S9.110–S9.119, S9.130–S9.132, S9.140–S9.147 | spec | consumes the line list; the frame stack is the second measure | events accumulated in reverse; a verdict ends the run |
| `dec.build` (events → `Node` with quoted-key sets), `dec.expand` | S4.240–S4.249, S6.42, S6.43 | spec | consumes | `dec.build` is a stack machine over the event list |
| `type Opts`, `type Parsed`, `cli.parse` (committed list and pending item, S1.13–S1.15), `cli.similar`, `cli.usage_line`, `cli.help`, `cli.version` | S1.1–S1.22, S1.30–S1.35, S1.60–S1.63, S1.70–S1.87, S1.130–S1.135, S1.150–S1.155 | spec | consumes the argv list | the program name is the literal `toon` (DISC-002) |
| `cli.mode`, `cli.stats`, `cli.success_line`, `type Plan`, `Cli.run` | S4.300–S4.304, S4.310–S4.319, S5.100–S5.113 | spec | consumes | `Cli.run` is the single core entry the shell calls |
| `main`, `sh.read_all`, `sh.open_in`, `sh.write_out`, `sh.exec_plan`, `sh.fail_read`, `sh.fail_create`, `sh.fail_write` | S8.1–S8.17, S9.1–S9.22 | shell | threads the `File` handle | `IO.die` for every non-zero exit; the 8192-byte rule of S7.11 lives in the plan, not in the shell |

## 3. State threading and failure

- Every mutation of the original becomes a value threaded through a loop: the reader's (stack, line, column), the decoder's
  (frames, events reversed, blank-line list), the encoder's reversed line list.
- Every failure is a `Result`-like verdict built in the core with its exact message: the shell has ONE `match` per verdict type and
  maps it to `IO.die(Unit, code, text)`. Early exit from a loop is a sticky verdict that later steps pass through unchanged.
- "First error wins" orders (S1.130–S1.135, S2.111, S9.140–S9.147, S6.45) are reproduced by doing the passes in the same order:
  scan all lines, then one structural pass, then expansion.
- Nothing is written to stdout before the whole conversion has succeeded (S4.1, S4.200), so the plan is complete before any effect.

## 4. Loop measures

Every loop in the original and its measure in Bend. No `@unsafe` and no fuel except the four bounded numeric loops below.

| original loop | measure | Bend shape |
|---|---|---|
| read stdin or a file to EOF | fuel `Nat` of read calls (65536 reads of up to 65536 bytes); exhaustion is an explicit error verdict, never a default | `case 1n+g:` over the fuel, the effect result as a parameter |
| UTF-8 decode, line split, scan, per-character tests | the byte or character list | structural, tail-recursive with a reversed accumulator |
| JSON reader (recursive descent in the original) | (byte list, stack): consume a byte, or keep the bytes and pop a frame | one def, pushdown machine |
| TOON decoder (mutually recursive descent in the original) | (line list, frame stack): consume a line, or keep the lines and pop a frame | one def, pushdown machine |
| encoder over the value tree | the `Json` value (children and sibling chains are subterms) | one structurally recursive def with a context parameter |
| value builder and writer A over the event list | the event list, with an explicit stack | structural, tail-recursive |
| path expansion, writer B | the `Json` / `Node` value | structural |
| argv scan | the argv list | structural |
| key-fold chain walk | the value (each step enters the single child) with the budget as a second, decreasing `Nat` | structural |
| long division for a quotient of known bit length | fuel = the number of quotient bits (at most 57 + the token's excess bits), computed before the loop | `case 1n+f:` |
| digit generation | fuel 25 (at most 17 digits are ever produced, S7.30); a `done` flag makes later steps identity | `case 1n+f:` |
| next digit by repeated subtraction | fuel 10 (nine subtractions at most) | `case 1n+f:` |
| k fix-up in digit generation | fuel 5 (at most three raises) | `case 1n+f:` |
| 10^k and limb shifts | the `Nat` k, structurally | `case 1n+p:` |

## 5. Numeric plan

See `docs/NUMERIC_PLAN.md` (one row per S7 quantity; no `F32`, no budgeted output).

## 6. Order plan

| S6 clause | Bend carrier | proof / golden |
|---|---|---|
| S6.1 committed argument list | a list in order of first acceptance, INPUT moved last when the usage line is built | golden `usage_conflict_usage_many` |
| S6.2 argv scan order | structural recursion over the argv list, one pending item | golden `usage_help_wins_over_bad_flag_value`, `usage_help_first_wins` |
| S6.3 option declaration order | a literal list of option descriptors in source order | golden `usage_help`, `usage_flag_with_value` |
| S6.4 enum value order | the literal list `off`, `safe` | golden `usage_bad_key_folding`, `usage_enum_similar_tie` |
| S6.5 stderr line sequence | the `Plan`'s ordered list of stderr lines | golden `stats_with_output` |
| S6.6 no unstable structure | nothing to carry; no `Map` iteration reaches an output anywhere in the port | golden `determinism_a`, `determinism_a_again` |
| S6.10 parsed object order, duplicates | the entry chain `JECons` in insertion order; a repeated key replaces the value in place (first position, last value) by a linear walk | golden `encstr_duplicate_keys`, `encstr_duplicate_keys_escaped`; closed law `dup_key_first_pos_last_value` |
| S6.11 the tool's ordered pair list | the same chain: there is one representation, so no conversion can reorder | golden `enc_shapes_mixed` |
| S6.12 array order | the item chain `JCons` in text order | golden `encnum_in_arrays` |
| S6.13 event order for writer A, duplicates kept | the event list in line order (built reversed, reversed once) | golden `jsonout_duplicate_keys` |
| S6.14 tree order for writer B | entry chains with first-insertion positions kept by in-place replacement | golden `jsonout_expand_merge`, `jsonout_duplicate_keys_expand` |
| S6.15 quoted-key set | a list of key strings per object with a linear membership test (never iterated into output) | golden `jsonout_expand_merge` |
| S6.16 hash index of the ordered map | not reproduced: lookup is a linear walk of the entry chain | golden `determinism_a` |
| S6.17 no sort on the JSON path | no sort def exists in the port | golden `encstr_key_order` |
| S6.30 object field order | the entry chain | golden `fx_enc_objects_01` |
| S6.31 tabular header order from the first row | the header is the key list of the first row; each later row is read by key lookup in header order | golden `fx_enc_arrays_objects_15`; closed law `tabular_row_in_header_order` |
| S6.32 array item order | the item chain | golden `large_tabular_1500` |
| S6.33 list-item first field is positional | the head of the entry chain | golden `enc_list_first_field_shapes` |
| S6.34 root-literal set | a list of root keys containing a dot, membership by exact string equality | golden `enc_fold_root_literal_nested` |
| S6.35 sibling key list | the body's key list, "any equals" test | golden `enc_folding_collision` |
| S6.36 depth-first pre-order emission | the reversed line accumulator threaded through `enc.emit` | golden `enc_shapes_mixed` |
| S6.37 fold segment order | a reversed segment list, reversed once before joining | golden `fx_enc_key_folding_01` |
| S6.38 no sort in the encoder | no sort def exists | golden `fx_enc_objects_01` |
| S6.40 decoded entry order | event order | golden `fx_dec_objects_01` |
| S6.41 tabular row key order | the header's field list zipped with the row's cells | golden `fx_dec_arrays_tabular_01`, `toonlenient_row_width_short` |
| S6.42 expanded object order | first-insertion position kept; merged keys appended in source order | golden `jsonout_expand_merge`; closed law `expand_merge_order` |
| S6.43 quoted-key set | as S6.15 | golden `fx_dec_path_expansion_10` |
| S6.44 blank-line numbers ascending | a list built in line order; the checks take the first member inside the range | golden `toonerr_blank_in_list` |
| S6.45 which error is reported | the three passes run in the original's order and each stops at its first verdict | golden `toonerr_scan_error_beats_parse_error` |

There is no sort and no `Map` anywhere in the port: every lookup is a linear walk of an insertion-ordered chain, which is what
makes the original's orders reproducible by construction. (Quadratic lookups are confined to one object's width, as in the original, S11.1.)

## 7. Parallel shape plan (Phase 5, planned now)

The hot loops are per row (S11.2). Rows of one tabular array are independent in both directions, so the natural fast twin is a **map
over rows**: `enc.rows_par` splits the row chain into a balanced binary tree of chunks (the count is carried beside the chain,
S7.35), encodes the two halves with a parallel let, and concatenates the two line lists; its spec twin is the sequential
`enc.rows_seq`. The law is `{enc.rows_par(d, rows) == enc.rows_seq(rows)}` under the premise that the tree covers the chain; it
needs only associativity of list append. The same shape serves decode (split each row's cells, classify tokens) once the row
lines of a table have been collected. Leaves hold a few hundred rows so that a fork's cost is small against its work.

**The seam**: the shell's last effect before the conversion is the read of the input (and one environment read for the
kill-switch); `Cli.run` and everything under it is a closed pure computation, so a parallel let anywhere inside it has no effect
beneath it. No bang (`f!(x)`) is placed: the work is text with data-dependent structure, not uniform numeric work, so the gpu
lane is MISSING with that reason (GPU-PORTS "Is the original a GPU port at all?": no).

## 8. Law plan (drafts LAWS.bend)

| law | kind | clause | when provable |
|---|---|---|---|
| `unescape_escape`: unescaping the escaped form of any string gives the string back | round trip | S4.19–S4.20, S2.123 | Phase 3 (induction on the string) |
| `events_build_value`: building a value from a value's own event stream gives the value back | round trip | S3.20–S3.29 | Phase 3 (induction on `Json`), if the stack machine's invariant states cleanly; otherwise closed instances |
| `bn_add_small`, `bn_mul_small`, `bn_cmp_refl` and other closed `BigNat` instances | closed golden | S7.21 | Phase 3 |
| `f64_from_2p53_plus_1`, `pow10_22`, `pow10_23`, `pow10_292`, `serde_fit_boundary`, `length_cap_boundary` | closed golden | S4.111–S4.113, S4.102, S4.191 | Phase 3 (small `U32` limb computations only) |
| `toon_tie_up`, `json_tie_even` on the value 2101031963024178.25 | closed golden | S4.132, S4.172 | Phase 3, if the normalizer affords the digit generator; else a harness golden with the reason recorded |
| `stats_estimate_small`, `stats_pct_6_25`, `stats_pct_18_75` | closed golden | S4.310–S4.317 | Phase 3 |
| `depth_of_indent`, `dup_key_first_pos_last_value`, `tabular_row_in_header_order`, `expand_merge_order` | closed golden | S2.107, S6.10, S6.31, S6.42 | Phase 3 |
| `rows_par_is_seq` | equivalence (fast == spec) | S4.37, S11.2 | Phase 5, with the fast twin |

Every property law is admitted only if `scripts/law-mutation.sh` kills a mutant of the def it names (LAWS-FROM-SPEC "Admission test").

## 9. Lanes and kill-switches

Lanes that must agree: interpreter, C at 1 thread, C at 8 threads, JS. No bang exists, so gpu is MISSING with that reason.
Kill-switch: one environment read in `main` (`TOON_SPEC=1`) passed down as a `Bool`; it selects the spec twin for every fast twin.
Before Phase 5 no fast twin exists and the switch changes nothing. No DISC needs a switch: the five OPEN entries are runtime
properties of the platform (DISCREPANCIES.md).

## 10. What is proved vs golden-tested (summary the README will repeat)

- Proved: the laws of §8 that reach `All terms check.` (restated with the verdict line and the unsafe split at each gate).
- Golden-tested: everything else, byte for byte on four lanes against the pinned original: 1005 cases at the end of Phase 1.
- Measured: nothing yet (Phase 5).

## 11. Amendments made while implementing (Phase 3, 2026-09-20)

Each amendment names what §1–§10 said, what the code does, and why. Nothing here changes a clause of the spec.

| # | planned | implemented | reason |
|---|---|---|---|
| A1 | `dec.run` emits an `Event` list; `dec.build` assembles a `Node`; writer A folds the event list, writer B recurses over `Json` | `decode.bend` builds the `Json` value directly: `attach` places each finished value in exactly the order of the event sequence of S3.20–S3.22; entries record `quoted` (S3.27) and repeated keys are kept (S3.25). ONE tree writer `J.write(j, n, tab_b)` serves both writers: the flag selects writer B's escape table (S5.64) over writer A's (S5.63) | the event list is not observable from the CLI (S3.22, S5.75: a library surface); S5.73 states the two writers print identical bytes except for their escape tables and repeated keys, and repeated keys live in the value. One pass instead of three, and no fast twin of the decoder is needed later |
| A2 | measure of the decoder: (line list, frame stack) | (line list, bound), where `bound` is an upper bound of the number of open constructs: a consumed line opens at most three, a close spends one. The frames themselves change freely | closing a construct REPLACES its parent frame (the finished value is attached), so the popped stack is not a subterm of the matched stack; the checker accepts the Nat bound. No `@unsafe`, no fuel: the bound is never reached (a law candidate) |
| A3 | `Cli.run(argv, input) -> Plan` | `Cli.parse(argv) -> Parsed` (help, version, every argv error, or the options), then the shell reads the input, then `Cli.convert(opts, bytes) -> CR`; `Cli.run_pure(argv, bytes) -> Out` is the two composed, for laws | the input may only be read after the whole argv was accepted (S1.135), so the pure core is two functions with one effect between them |
| A4 | dispatch on byte values | every `match` dispatches on a SMALL `Nat` class code computed once per byte (`J.byte.cls`, `J.esc.cls`, `J.w.cls`, `E.esc.cls`, `C.short.id`), never on a `U32` literal and never on a byte value as a `Nat` literal | a `match` on `U32` literals compiles to a 32-level bit tree per arm set (bend #867: the JSON reader alone took > 120 s and 15 GB to emit C); a `Nat` literal pattern costs the checker one successor per unit (json.bend check 1.65 s → 0.57 s, an interpreter-lane run 4.8 s → 2.5 s) |
| A5 | Base's `String.eq` for keys | `T.str_eq`, a loop | Base's `String.eq` recurses to the depth of the common prefix and rebuilds both texts: a stack wall on the JS lane for long equal keys, and an allocation per comparison |
| A6 | law plan §8 | 20 laws proved in Phase 3: first-failure-wins (argv scan, decode pass, root value, JSON reader), mode laws (lenient never reports; `--encode`/`--decode` win; the 256 cap on values and merges; no Saved line without savings) and closed goldens (bignat carry, depth of indent, estimates, the three percent roundings). Whole-document closed goldens through the JSON reader or the decoder did NOT finish in the checker's normalizer within 110 s and stay golden-tested; `unescape_escape`, `events_build_value` and `rows_par_is_seq` are not stated yet | the normalizer's cost, measured; a law that cannot be checked in a gate's budget is a harness golden with the reason recorded (§8's own rule) |
| A7 | §8 named laws before any code existed: `unescape_escape`, `events_build_value`, `bn_add_small`, `bn_mul_small`, `bn_cmp_refl`, `f64_from_2p53_plus_1`, `pow10_22`, `pow10_23`, `pow10_292`, `serde_fit_boundary`, `length_cap_boundary`, `toon_tie_up`, `json_tie_even`, `dup_key_first_pos_last_value`, `tabular_row_in_header_order`, `expand_merge_order`, `rows_par_is_seq`; NUMERIC_PLAN cites six of them | NONE of those seventeen names exists in `port/LAWS.bend`. What is stated instead (the file is the authority; `scripts/law-coverage.sh` lists it): 14 quantified laws (`argv_stop_is_sticky`, `decode_error_ends_pass`, `decode_root_ends_pass`, `json_error_is_sticky`, `lenient_scan_never_fails`, `lenient_body_never_fails`, `encode_flag_wins`, `decode_flag_wins`, `stdin_defaults_to_encode`, `no_saved_line_without_savings`, `expansion_cap_on_values`, `expansion_cap_on_merges`, `twin_gate_switch`, `twin_gate_open`), 41 closed unit laws (`bn_add_carry`, `depth_of_indent`, `depth_with_indent_zero`, the `stats_*`, the `div_pow10_*`, `div_p10_*`, `from_dec_p10_*`, `serde_*`, `token_*`, `show_*_fast_*`, `key_hash_fnv1a`, `kt_member`, `kt_not_member`, `expand_order_first_insertion`, `expand_cap_is_256_reject`, `expand_cap_is_256_accept`) and 157 closed whole-pipeline laws `golden_<case>` (a captured golden restated as `C.run_pure(argv, bytes) == Out`). The planned subjects map as: duplicate keys and the tabular header order are golden-tested ONLY (`encstr_duplicate_keys`, `fx_enc_arrays_objects_15`); the merge order has the closed law `expand_order_first_insertion`; the length cap has `golden_toonerr_huge_length`, `golden_toonlenient_huge_length` and `golden_toonerr_length_u64_max_list`; the power-of-ten and tie values (`pow10_*`, `toon_tie_up`, `json_tie_even`, `f64_from_2p53_plus_1`, `serde_fit_boundary`) are golden-tested ONLY (`encnum_pow10_each`, `encnum_tie_up_1`, `encnum_display_ties`, `encnum_big_ints`, `encnum_u64_boundary`): a closed law through the shortest-digit generator ran 25 minutes in the normalizer without finishing; `unescape_escape` and `events_build_value` are not stated (A1 removed the event list, so the second has no subject); `rows_par_is_seq` is not stated because no parallel twin was built (§7 stayed a plan: no bang, no parallel let) | the plan was written before the checker's costs were measured; the README and the board cite only laws that exist |
| A8 | §6 order carriers: the entry chain alone, with linear walks for a repeated key (S6.10), for folding's sibling test (S4.63), for the tabular row lookup (S6.31) and for path expansion (S6.42) | a hashed key set `T.KT` (a 16-level bit tree over FNV-1a of the key, buckets compared with `T.str_eq`) beside the entry chain in the JSON reader's object frame and in the encoder's folding sets; a key map `J.KM` for rows whose keys are not in header order, behind a lockstep test for rows that are; an expansion carrier `D.XV` (insertion-ordered key list + hashed map) in `decode.bend`; blank lines inside an array body are dropped as the body advances instead of re-scanned per line. Order is still carried by the chain / the key list; the tree only answers membership and lookup | the round 6 non-author review measured quadratic time in the number of keys of one object (8000 keys 5.2 s, 30000 folded keys and 40000 expanded lines > 120 s, the original < 3 s). This is a change of the SPEC twins' carrier, not a fast twin: there is no slow twin kept beside it, so it rests on the goldens, on `kt_member`, `kt_not_member`, `key_hash_fnv1a`, `expand_order_first_insertion`, and on `scripts/diff-fuzz.py` (lenses `docs`, `expand`, `scale`) |
