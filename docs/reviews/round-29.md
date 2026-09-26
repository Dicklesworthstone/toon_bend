# Round 29: non-author hostile review of toon_bend

| field | value |
|---|---|
| reviewed commit | e6640bb0dbe083a4550a43a147e92b2c3ef2124e |
| clone | fresh `git clone https://github.com/Dicklesworthstone/toon_bend /data/tmp/review_R29/clone`; `git rev-parse HEAD` printed that hash (the expected `e6640bb`) |
| original | `oracle/toon` -> `/data/projects/toon_bend/oracle/toon`, sha256 `821287eaf1a6d320ee1ef7604e74e3cefaa42b69445c96abb9dd310782d04030`, equal to `docs/PIN.toml` |
| Bend | `bun /tmp/bend/bend2/main.ts`, `/tmp/bend` at `15ae0c86f3193b8f645b4bedbc438655b648d0da`, `BEND_NO_TELEMETRY=1` (never updated) |
| tools | bun 1.4.2, Ubuntu clang 21.1.8, Python 3.14.4, markdown-it-py 3.0.0 |
| port binaries | native `/data/tmp/review_R29/bin/toon` (21 s wall); JS `/data/tmp/review_R29/bin/toon.js`, run through `scripts/js-lane.py` |
| unmutated corpus | `./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t -- ../bin/toon --threads 1 --` gives `"passed":1117,"failed":0,"inconclusive":0,"stderr_compared":true,"verdict":"PASS","oracle_identity_checked":true` |
| repo gates on this tree | `claims-audit.py` gives `"findings": 0 … "laws": 672, "cases": 1117 … "verdict": "OK"`; `law-coverage.sh` gives `"laws": 672, "proofs": 672 … "verdict": "OK"`; `arch-lint.py` PASS; `pin-check.sh` RED only because this clone has no `legacy/Toon` (environment), plus `manifest_version` YELLOW, which commit `0e4c08d` explains (the version line is written from the next re-capture on) |
| host | shared, 8 cores, 30 GB. At 01:32 the load was 0.82, with 24 GB available and 21 GB of disk free. At 02:54 the load was 1.42, with 24 GB available and 20 GB free. Every build and proof started with at least 12 GiB `MemAvailable` and ran one at a time: builds under `systemd-run --user --scope -p MemoryMax=8G`, proofs under `MemoryMax=10G`, both with `MemorySwapMax=0`. None was killed. Whole-proof peaks were 2.9-3.5 GB and 430-571 s. This round used 100 MB of disk |
| harness | `r29/h29.py` runs `./oracle/toon ARGV` and `bin/toon --threads T -- ARGV` (or `js-lane.py toon.js -- ARGV`) on the same stdin. It compares stdout, stderr and the exit code byte for byte, and removes `TOON_SPEC` unless the run sets it |

## Findings (counting rule of 2026-09-23, rules 1-6)

| id | sev | class | what | spec |
|---|---|---|---|---|
| R29-1 | MEDIUM | BEHAVIOR (a gate that lies; NEW, in R28-1's repair) | R28-1's repair refuses two findings columns "a reader could take for one field", but it only compares exact folded header text: `head.count("sev") + head.count("severity")`. So the header `Severity:` beside `sev` gets through, and so does `sev` followed by an invisible U+200B beside `sev`, which renders as two identical `sev` headers. The report renders HIGH under the first column. The gate reads LOW from the second. With planted rounds 29 and 30 (`0 \| 0 \| yes`, non-author) whose reports use either header, `converge.sh` prints `CONVERGED`, `claims-audit.py` prints `"findings": 0 … "OK"` and `state-check.sh` prints `0 finding(s)`. The control `sev \| sev` is refused, with NOT_CONVERGED | PARITY-GATE rules 1, 6; `review_report.py` docstring |
| R29-2 | LOW | BEHAVIOR (a gate that lies; in R28-2's repair) | `claims-audit.py` treats a pasted `"mutants": N` below the inventory as a selection whenever the LINE contains two `M<nn>` tokens anywhere. It does not check the pasted command's own arguments, and it does not compare N with the ids named. Two lines pass (`"findings": 0 … "OK"`): a pasted whole-inventory run, `hand-mutants.py` with no ids, reporting a stale `"mutants": 110` (the inventory has 118), with M118 and M119 mentioned in the prose after it; and `hand-mutants.py M118 M119` reporting `"mutants": 117, "killed": 117`. The second is the shape R28-2 reported (seven mutants from two ids), and it is still accepted | (claims) |
| R29-3 | MEDIUM | BEHAVIOR (corpus gap; ONE finding against `scripts/hand-mutants.py`, whose inventory has none of these sites) | Three NEW hand mutants survive the whole corpus on c-1t (1117 of 1117 each) AND the whole 672-law `PROOF.bend` as a group (P5: `All terms check.`, 524 s). On every distinguishing input, the unmutated port equals the original on native t1, on c-8t with `TOON_SPEC=1` and on JS. H5 (`all_digits`): empty bracket content after a delimiter mark counts as length 0, so `a[\|]:` gives `{"a": []}` instead of `{"a[\|]": {}}`. H6 (`hdr.a.quoted`): any character, not only `[`, after a quoted key's closing quote opens the bracket, so `"k"x1]: 5` gives `{"k": [5]}` instead of the error `Missing colon after key`. U10 (`utf8.cont`): U+DFFF (`ED BF BF`) is accepted as text, where the original refuses the stream as invalid UTF-8 | S2.135, S2.130, S2.2 |
| R29-4 | LOW | LAW-COVERAGE (ONE finding against `scripts/hand-mutants.py`) | Five NEW mutants that the corpus kills on c-1t but NO law does. P10 (E3, F6, F7, C2 together) and S_N1 (N1 alone) both give `All terms check.`. N1 `limbs_down`: whole dropped limbs never set the sticky flag (10 cases). E3 `plan.head`: the object-vs-other conflict names the two types in the wrong order (3). F6 `dg.high`: an even significand's upper end is outside the interval (3). F7 `dg.low`: the same at the lower end (3). C2 `indent.check.c`: `-0` is out of range (1) | S7.21, S4.111, S9.116, S4.131, S1.31 |

Count under the rule: **BEHAVIOR 3 (MEDIUM 2, LOW 1), LAW-COVERAGE 1 (LOW), DOCUMENT 0.** NEW behavior findings of MEDIUM or above: **2** (R29-1, R29-3). This round is NOT clean. I found **no difference between the UNMUTATED port and the original** on any lane I tried. That covers about 31,500 native t1 executions from my own generators, 11,000 at 8 threads with `TOON_SPEC=1`, 30,040 `diff-fuzz` inputs with new seeds plus 80,000 number literals, 2,417 JS-lane executions from my generators plus 2,000 `diff-fuzz` inputs on JS, and 14 interpreter executions.

### R29-1 reproduction

First, the reader on its own (`r29/reports/`, each report written by a Python snippet with the header table and one findings table; row `R29-1 | HIGH | LOW | BEHAVIOR`):

```
== control_dup.md 1 {… "rows": [{"id": "R29-1", "sev": "HIGH", "class": "BEHAVIOR"}], "counted": 1, "errors": ["the findings table has more than one `sev` column"]}
== zwsp_sev.md 0 {… "rows": [{"id": "R29-1", "sev": "LOW", "class": "BEHAVIOR"}], "counted": 0, "errors": []}
== wj_sev.md 0 {… "sev": "LOW" …, "counted": 0, "errors": []}          (U+2060 WORD JOINER)
== cyr_sev.md 0 {… "sev": "LOW" …, "counted": 0, "errors": []}         (Cyrillic U+0455 U+0435 + v, renders "sev")
== zwsp_class.md 0 {… "sev": "HIGH", "class": "DOCUMENT"}, "counted": 0, "errors": []}
== sev_dot.md 0 {… "sev": "LOW" …, "counted": 0, "errors": []}         (header `Sev.` beside `sev`)
== severity_colon.md 0 {… "sev": "LOW" …, "counted": 0, "errors": []}  (header `Severity:` beside `sev`)
```

Then the full gate run: `python3 /data/tmp/review_R29/r29/decoy29.py MODE "6 to 28=>6 to 30" "9 to 28=>9 to 30" "20 to 28=>20 to 30" "TWENTY-THREE rounds=>TWENTY-FIVE rounds" "twenty-three non-author=>twenty-five non-author" "2, 2 and 2=>2, 2, 2, 0 and 0"`, run in the one clone. The script appends rows 29 and 30 (`0 | 0 | yes`, non-author) to the rounds table and writes both reports. Each report's header is `| id | FIRST | sev | class | what | spec |` with the row `| R2n-1 | HIGH | LOW | BEHAVIOR | … |`. The script refreshes the prose spans the audit checks, runs the gates, restores the clone with `git checkout` and moves the reports into `/data/tmp/review_R29/moved/`. Results from `r29/logs/decoy29_zwsp.log` (FIRST = `sev` + U+200B):

```
$ python3 scripts/review_report.py docs/reviews/round-29.md 29   (rc=0)
{"commit": "e6640bb0dbe083a4550a43a147e92b2c3ef2124e", "rows": [{"id": "R29-1", "sev": "LOW", "class": "BEHAVIOR"}], "counted": 0, "errors": []}
$ ./scripts/converge.sh docs/PORT_STATE.md   (rc=0)
tier T2: rounds 30, clean 7, clean tail 2, last two clean True, non-author round True, open OQ 0, open DISC 0
convergence: CONVERGED
$ python3 scripts/claims-audit.py   (rc=0)
{"files": 16, "absent": [], "findings": 0, "historical_lines_exempt": 8, "laws": 672, "cases": 1117, "disc": {"accepted": 11, "resolved": 4, "open": 0}, "verdict": "OK"}
$ ./scripts/state-check.sh docs/PORT_STATE.md   (rc=0)
state-check: 0 finding(s)
after restore: ?? oracle
```

`r29/logs/decoy29_severity.log` (FIRST = `Severity:`, no invisible character at all) gives the same output: `CONVERGED`, `"findings": 0 … "OK"`, `0 finding(s)`. The control `r29/logs/decoy29_dup.log` (FIRST = `sev`) is refused: `converge.sh` rc=1, `missing: round 29: … the findings table has more than one `sev` column`. The planted reports are decoys. Their ids (`R29-1` in the planted round-29 file, `R30-1` in the planted round-30 file) are NOT findings of this report, and those files are kept only in `moved/`. This is not a hidden table and not a complete forgery: the one table renders, and a reader sees HIGH under the first severity column. Cause: `review_report.py` counts duplicates as `head.count(name)`, over exact NFKC-folded text. NFKC does not remove format characters (Cf) or fold homoglyphs, and `Severity:` is not exactly `severity`. Fix direction: normalize header cells before comparing them (drop Cf characters, strip punctuation, map `severity` to `sev`), or refuse every header cell that is not exactly one of a small allowed set of column names.

### R29-2 reproduction

In the clone, each line below was appended after the `- law admission, round 28:` line of `docs/PORT_STATE.md`. Then `python3 scripts/claims-audit.py` was run, and the file was restored (`git status --short` afterwards: `?? oracle`):

```
== A_two_ids_count7 rc=0
   - law admission, round 29: `python3 scripts/hand-mutants.py M118 M119` → `{"mutants": 7, "killed": 7, "survived": [], "not_evidence": [], "verdict": "STRONG"}`
   {"files": 16, … "findings": 0, … "verdict": "OK"}
== B_two_ids_count117_killed117 rc=0
   - law admission, round 29: `python3 scripts/hand-mutants.py M118 M119` → `{"mutants": 117, "killed": 117, "survived": [], "not_evidence": [], "verdict": "STRONG"}`
   {… "findings": 0, … "verdict": "OK"}
== C_prose_total_ids rc=1          (R28-2's prose case: repaired)
   docs/PORT_STATE.md:51: mutants in all: says 100, the repository has 118
== D_pasted_full_run_stale rc=0
   - whole inventory, 2026-09-26: `python3 scripts/hand-mutants.py` → `{"mutants": 110, "killed": 110, "survived": [], "not_evidence": [], "verdict": "STRONG"}` (its two newest, M118 and M119, included)
   {… "findings": 0, … "verdict": "OK"}
```

Cause: `selective = bool(re.search(r"\bM\d{2,}\b[^\n]*\bM\d{2,}\b", line))` looks at the whole line, not at the arguments of the command pasted on it, and the exemption only requires `said < want`. Fix direction: take the selection from the pasted command's own `M<nn>` arguments, and require the pasted count to equal the number of distinct ids.

### R29-3 reproductions (the original, the unmutated port and the mutant binary `mut/<id>/toon`, through `r29/dist29.py`)

```
== H5 argv=['-d'] stdin=b'a[|]: 1'
   orig    (b'{\n  "a[|]": 1\n}\n', b'', 0)
   port    SAME as orig
   mutant  (b'', b'Failed to decode TOON: Expected 0 inline array items, but got 1\n', 1)   <- DIFFERS
== H5 argv=['-d'] stdin=b'a[|]:'
   orig    (b'{\n  "a[|]": {}\n}\n', b'', 0)
   port    SAME as orig
   mutant  (b'{\n  "a": []\n}\n', b'', 0)   <- DIFFERS
== H5 argv=['-d'] stdin=b'a[\t]{x}:'
   orig    (b'{\n  "a[\\t]{x}": {}\n}\n', b'', 0)
   port    SAME as orig
   mutant  (b'{\n  "a": []\n}\n', b'', 0)   <- DIFFERS
== H6 argv=['-d'] stdin=b'"k"x1]: 5'
   orig    (b'', b'Failed to decode TOON: Missing colon after key\n', 1)
   port    SAME as orig
   mutant  (b'{\n  "k": [\n    5\n  ]\n}\n', b'', 0)   <- DIFFERS
== H6 argv=['-d'] stdin=b'"k"(1]: 5'
   orig    (b'', b'Failed to decode TOON: Missing colon after key\n', 1)
   port    SAME as orig
   mutant  (b'{\n  "k": [\n    5\n  ]\n}\n', b'', 0)   <- DIFFERS
== U10 argv=['-e'] stdin=b'"\xed\xbf\xbf"'
   orig    (b'', b'Failed to read stdin: stream did not contain valid UTF-8\n', 1)
   port    SAME as orig
   mutant  (b'\xed\xbf\xbf\n', b'', 0)   <- DIFFERS
== U10 argv=['-d'] stdin=b'a: \xed\xbf\xbf'
   orig    (b'', b'Failed to read stdin: stream did not contain valid UTF-8\n', 1)
   port    SAME as orig
   mutant  (b'{\n  "a": "\xed\xbf\xbf"\n}\n', b'', 0)   <- DIFFERS
```

Mutant texts (`r29/m29defs.py`; each is an exact replacement of text that occurs once):

- H5 `all_digits` (decode): `case SNil{}:\n      False{}` -> `True{}` (the empty-string arm)
- H6 `hdr.a.quoted` (decode): `hdr.a.after(T.head_is(after, 91), inner, after)` -> `hdr.a.after(Bool.not(String.is_empty(after)), inner, after)`
- U10 `utf8.cont` (text): `U32.is_gt(value, 57343)` -> `U32.is_ge(value, 57343)`

Proofs (`r29/logs/proofs29.log`, whole `PROOF.bend`, 672 laws). These lines also peel off the corpus survivors that a law does kill:

```
P1 H4,H5,H6,N4,K1,U10,U11 PROOF rc=1 secs=3 … loc=['Location: LAWS.bn_add_carry'] restored=IDENTICAL                              (N4 killed by law)
P2 H4,H5,H6,K1,U10,U11 PROOF rc=1 secs=62 … loc=['Location: LAWS.utf8_accepts_below_surrogate'] restored=IDENTICAL                (U11 killed by law)
P3 H4,H5,H6,K1,U10 PROOF rc=1 secs=235 … loc=['Location: LAWS.ks_bucket_members'] restored=IDENTICAL                              (K1 killed by law)
P4 H4,H5,H6,U10 PROOF rc=1 secs=295 … loc=['Location: LAWS.decode_backslash_outside_quotes_in_fields'] restored=IDENTICAL          (H4 killed by law)
P5 H5,H6,U10 PROOF rc=0 secs=524 ['Maximum resident set size (kbytes): 3349112'] stdout-first=['All terms check.'] loc=[] restored=IDENTICAL
```

The corpus misses these three for the following reasons. The only pinned surrogate inputs are the low end (`ED A0 80`), in the laws `utf8_rejects_surrogate`, `utf8_accepts_below_surrogate` and `utf8_verdict_rejects_surrogate`, and the corpus has no `ED BF BF`. No case offers bracket content that is ONLY a delimiter mark (`[|]`, `[TAB]`). No case puts a character other than `[` or `:` right after a quoted key's closing quote. Fix direction: capture these inputs as cases, write the cheap closed laws (`T.utf8.finish(T.utf8.bytes([237, 191, 191], …)) == None{}`, plus the two `header` verdicts), and add the sites to the inventory.

Corpus survivors that the laws DO kill: N4 (`add` drops the final carry; the port prints `1.0633823966279326:e+42` for `a: 1063382396627932698323045648224275660865535.00057`), K1 (`ks.has.go`: a key below the bucket root counts as present; `jda: 1\nexr: 2` loses `exr`), U11 (U+D7FF refused) and H4 (a backslash outside quotes escapes `}`). They are not findings under the rule, but no captured case pins any of the four.

### R29-4 reproductions

Corpus failures on c-1t (`/data/tmp/review_R29/mut/results29.jsonl`):

- N1: 10 cases (`encnum_long_mantissa`, `decnum_long_mantissa`, `decfmt_exp_shapes`, `encnum_pow10_each`, `large_tabular_1500`, `large_tabular_1500_pipe_folded`, `determinism_a`, `determinism_a_again`, `encnum_text_changes`, `decnum_exact_halfway`)
- E3: 3 cases (`jsonout_expand_conflict_strict`, `fx_dec_path_expansion_06`, `fx_dec_path_expansion_07`)
- F6: 3 cases (`encnum_exponents`, `encnum_pow10_slow_path`, `encnum_pow10_each`)
- F7: 3 cases (`decfmt_exp_shapes`, `encnum_mixed_digits_ok`, `encnum_u64_round_ties`)
- C2: 1 case (`usage_indent_minus_zero`)

Proofs:

```
S_N1 N1 PROOF rc=0 secs=535 ['Maximum resident set size (kbytes): 3328332'] stdout-first=['All terms check.'] loc=[] restored=IDENTICAL
P10 E3,F6,F7,C2 PROOF rc=0 secs=531 ['Maximum resident set size (kbytes): 2920288'] stdout-first=['All terms check.'] loc=[] restored=IDENTICAL
```

Mutant texts:

- N1: `limbs_down(p, xs, Bool.or(sticky, Bool.not(U32.is_eq(x, 0))))` -> `limbs_down(p, xs, sticky)`
- E3: `plan.conf(strict, k, "object", ty(other))` -> `plan.conf(strict, k, ty(other), "object")`
- F6: dg.high's `case True{} EQ{}:\n      True{}` -> `False{}`
- F7: the same change in dg.low
- C2: `Bool.and(Bool.or(Bool.not(neg), T.str_eq(c, "0")), Nat.is_le(` -> `Bool.and(Bool.not(neg), Nat.is_le(`

The unmutated port equals the original on two inputs that separate F6 and F7: `[49999999999999995805696]` (5e22 minus 2^22; an even significand whose upper end is exactly 5e22) and `[70000000000000004194304]` (an even significand whose lower end is exactly 7e22). Both print `50000000000000000000000` and `70000000000000000000000`, on native t1, on c-8t with `TOON_SPEC=1` and on JS.

## Mutant table (all 25 mutants of this round)

Each mutant is an exact-text replacement (`r29/m29defs.py`). Each was applied to the one working copy `/data/tmp/review_R29/mport/port`, built natively (memory-gated) and restored. Every record says `restored: IDENTICAL`, and `diff -r clone/port mport/port` is empty at the end. Each mutant binary was then run through the whole corpus on c-1t.

| mutant | def | change | corpus c-1t failing | law | verdict |
|---|---|---|---|---|---|
| H5 | `all_digits` | empty bracket text is a length | 0 | none (P5) | R29-3 |
| H6 | `hdr.a.quoted` | any char after a quoted key opens the bracket | 0 | none (P5) | R29-3 |
| U10 | `utf8.cont` | U+DFFF accepted | 0 | none (P5) | R29-3 |
| N1 | `limbs_down` | whole dropped limbs never sticky | 10 | none (S_N1) | R29-4 |
| E3 | `plan.head` | conflict types swapped | 3 | none (P10) | R29-4 |
| F6 | `dg.high` | even upper end outside | 3 | none (P10) | R29-4 |
| F7 | `dg.low` | even lower end outside | 3 | none (P10) | R29-4 |
| C2 | `indent.check.c` | `-0` out of range | 1 | none (P10) | R29-4 |
| H4 | `ucut.cls` | backslash outside quotes escapes | 0 | `decode_backslash_outside_quotes_in_fields` (P4) | killed by law only |
| N4 | `add` | final carry dropped | 0 | `bn_add_carry` (P1) | killed by law only |
| K1 | `ks.has.go` | key below bucket root found | 0 | `ks_bucket_members` (P3) | killed by law only |
| U11 | `utf8.cont` | U+D7FF refused | 0 | `utf8_accepts_below_surrogate` (P2) | killed by law only |
| H7 | `hdr.g` | values after fields colon accepted | 1 | `decode_values_after_fields_header_refused` (P7) | killed |
| H3 | `hdr.c.fields` | open quote in fields is not a header | 1 | `decode_open_quote_in_fields_segment` (P8) | killed |
| C4 | `jaro.pos` | window high end excluded | 6 | `argv_key_folding_similar_tie` (P9) | killed |
| N2 | `low_nonzero` | bit 0 ignored | 15 | `div_pow10_a20_k0` (S_N2) | killed |
| N3 | `p5.fold` | earlier sticky forgotten | 3 | `div_pow10_a20_k22` (S_N3) | killed |
| N5 | `bitlen` | top limb bit 15 not counted | 4 | `div_pow10_a20_k0` (S_N5) | killed |
| H2 | `hdr.c.fields` | no whitespace before the colon | 1 | screen: `decode_space_and_tab_before_header_colon` exists | killed (not proved singly) |
| C3 | `budget.check.c` | three-digit flatten depth unlimited | 1 | screen: `encode_flatten_depth_100_folds_100` exists | killed (not proved singly) |
| H1 | `hdr.names` | blank fields segment split | 1 | screen: `golden_toonedge_fields_space_only` exists | killed (not proved) |
| H8 | `hdr.a.plain` | `:` before `[` ignored | 7 | screen: four golden laws of its failing cases exist | killed (not proved) |
| E1 | `path.ins` | lenient replacement moves to end | 3 | screen: `golden_toonedge_expand_hash_collision_lenient` exists | killed (not proved) |
| E2 | `plan.conf` | lenient overwrite moves to end | 2 | screen: `golden_fx_dec_path_expansion_08` exists | killed (not proved) |
| X1 | `xb.get.go` | key above bucket root not found | 2 | screen: two golden collision laws exist | killed (not proved) |

P6 (H2, H3, H7, N1, N2, N3, N5, E3, F6, F7, C2, C3, C4) stopped at `div_pow10_a20_k0` in 39 s. P7 (H2, H3, H7, E3, F6, F7, C2, C3, C4) stopped at H7's law. P8 (H2, H3, E3, F6, F7, C2, C3, C4) stopped at H3's law. P9 (E3, F6, F7, C2, C4) stopped at C4's law. P10 is above. None of these peelings was repeated with the named law removed, so "killed" means that the group failed at that law.

## Round 28's repairs (item 0)

| R28 finding | this round |
|---|---|
| R28-1 (inline HTML in any cell; duplicate findings columns) | Inline HTML: holds. `<del>` in a header is refused (`decoy29_dup` control and the reader). Duplicate columns: holds only for byte-identical folded names. `Severity:`, `Sev.`, `sev`+U+200B, `sev`+U+2060 and Cyrillic `ѕеv` beside `sev` are all read through the second column (**R29-1**) |
| R28-2 (only pasted runs are selections) | The prose-total case is repaired (`C_prose_total_ids` gives rc=1). A pasted count is still exempted whenever ANY two ids stand on the line, and it is not compared with the ids named (**R29-2**) |
| R28-3 / R28-4 (cases, laws, M109-M119) | In the tree: `law-coverage.sh` gives 672/672, the corpus has 1117 cases, and the inventory lists M109-M119. NEW neighbouring-arm mutants: U10 (neighbour of the U+D800 law) survives everything (**R29-3**), and U11 is killed by `utf8_accepts_below_surrogate`. F6 and F7 (the even-significand arms of F2 and F3's defs) are caught only by the corpus (**R29-4**). C2 (neighbour of Ce) is caught only by the corpus (**R29-4**). C4 (neighbour of K3) is killed by a law |
| (d) `law-mutation.sh` on modules | NOT run (see below) |

## Clean areas: compared executions of the UNMUTATED port

| lens (script, seed) | target | executions (compared pairs) | diffs |
|---|---|---|---|
| `gen29.py hdr` 29001 (300), 29101 (4000), 29201 (1500, t8 + `TOON_SPEC=1`), 29301 (300, JS) | item 1: header lines built from 35 keys (quoted, escaped, unterminated, NBSP, U+3000), 44 bracket contents (leading zeros, signs, spaces, `\|`/TAB marks in every position, the cap and over it, 2^64, Arabic and fullwidth digits), whitespace and junk between `]`, `{…}` and `:`, 27 fields segments (quoted `}`, empty pieces, blank, unterminated), 13 colon forms, inline values and body rows, in 5 contexts, with `--no-strict`, `--expand-paths safe` and `--stats` | 6100 | 0 |
| `gen29.py bignat` same seeds | item 1: integers at 2^k and 10^k ± 1, 2, 65535, 65536, 2^32-1 for k at the limb boundaries (15-17, 31-33, 47-49, 63-65, … 1074, 1075), with decimal points, long zero runs, exponents to ±400, both directions, `--stats` | 6100 | 0 |
| `gen29.py expand` same seeds | item 1: dotted keys with numeric-looking (`0`, `01`, `-1`, `1e2`), quoted (`"a.b"`), empty, `__proto__`, Unicode segments; nested values, arrays, tabular arrays and list items under them; strict, `--no-strict`, `--stats` | 6100 | 0 |
| `gen29.py statserr` same seeds | item 1: `--stats` on 21 malformed JSON inputs, 24 malformed TOON inputs, missing files, directories, `-o` to a missing directory, repeated `--stats`, bad option values | 6100 | 0 |
| `gen29.py writer` same seeds | item 2: every C0 control, DEL, U+0080-U+009F, U+2028/9, BOM, U+10FFFF, U+FFFD, U+D7FF, U+E000 and 9 escapes, in values, keys, inline and tabular cells, list items and dotted keys, plain `--decode` and `--expand-paths safe` | 6100 | 0 |
| `gen29.py sticky` 29401 (3000), 29402 (1000, t8 + `TOON_SPEC=1`), 29403 (300, JS) | item 1/2: exact halfway points between neighbouring doubles (integers up to 2^143 and decimals down to 2^-1100), with one extra low digit (just above) or one fewer (just below), in both directions | 4300 | 0 |
| `gen29.py collide` same seeds | items 1/3: keys whose FNV-1a hashes collide in the low 16 bits (`exr`/`jda`, …), in JSON objects of 2-20 members with repeats and key folding, and in TOON objects, nested objects and dotted paths under expansion | 4300 | 0 |
| `gen29.py merge` 29501 (4000), 29502 (1500, t8 + `TOON_SPEC=1`), 29503 (300, JS) | item 1: expansion merges against earlier siblings: primitives, empty objects, arrays and tabular arrays under the same paths, quoted `"a.b"` beside `a.b`, list items with dotted keys, strict / lenient / `--stats` | 5800 | 0 |
| `diff-fuzz.py` mutate/docs/argv/expand/collide 290001 (4000 each, t1), 290002 (2000 each, `--switch TOON_SPEC=1`, t8) | repository lenses, new seeds | 30,000 inputs (every log gives `"differences": 0 … "verdict": "PASS"`) | 0 |
| `diff-fuzz.py numbers` 290003 (`--switch TOON_SPEC=1`) and 290006 (no switch), `scale` 290004 (t1) and 290005 (`--switch`, t8) | `"number_literals": 40000` in each numbers run; scale `"too_slow": 0` | 400 + 40 inputs | 0 |
| **JS lane** | `gen29.py`: the eight lenses above at 300 each (2,400); 17 distinguishing inputs of this round's mutants; `diff-fuzz.py` mutate/docs/argv/expand/collide 290101 (400 each, `js-lane.py toon.js --`) | 2,417 + 2,000 inputs | 0 |
| **interpreter lane** (`r29/interp29.py`, `scripts/interp-lane.sh`, `BEND_NO_TELEMETRY=1`) | 14 inputs: `"k"x1]: 5`, space and TAB before a fields colon, `{ }`, `a[]`, an open quote in fields, `k: v[1]: 2`, 2^70+2^17+1, 2^66+2^13+1, a 10-member object with colliding keys, colliding expansion paths, a lenient overwrite, `--stats` on a count error, `[0100000000]`, pipe tabular | 14 | 0 |

The same 17 distinguishing inputs were also run on native t1 and on c-8t with `TOON_SPEC=1`: 0 diffs. Mutant hunts (not counted above): `r29/mhunt29.py` ran 4,500 generated inputs against the N4 and K1 binaries, to find their distinguishing inputs.

## What this round did NOT cover

- `scripts/law-mutation.sh` on any module (item 0(d)). Each module batch pays an ~8-minute baseline, and every survivor then runs a whole proof. The proof budget went to this round's own 25 mutants: 14 whole or partial proof runs. I did not check the "111 named, 38 with a site" target set against the tree
- A whole proof of the UNMUTATED tree. P5, P10 and S_N1 ending in `All terms check.` imply that the unmutated laws check
- Single proofs of the survivors in R29-3 and R29-4 (only groups, except N1). H2 and C3 were screened, not proved. H1, H8, E1, E2 and X1 were screened by golden laws of their failing cases and not proved
- `lanes.sh`, `port-doctor.sh`, `floor.sh`, `stdio-probe.py`, `harness-selftest.sh`, `hand-mutants.py` for any id, any performance measurement, and `-o` sandboxes
- Nesting depth near 127 beyond the repository's `diff-fuzz` lenses (round 28 swept 120-131). Encoder quoting and folding arms. The JSON reader's error columns
- Review-report layouts beyond header names (for example, a second table whose ids are not in its first column), and DOCUMENT review beyond the repository gates' own counts

## Process notes (RULE 1)

- I deleted NO file. Planted reports were moved with `os.rename` into `/data/tmp/review_R29/moved/`. So was an empty scratch file of mine (`gen29.py.extra`, created by a mistaken heredoc), which is there as `gen29.py.extra.empty`. The clone was restored with `git checkout` after every plant, and a copy of `PORT_STATE.md` was compared after the R29-2 edits (`git status --short` shows only `?? oracle`). The mutant working copy `mport/` was restored after every build and proof: every record says `restored: IDENTICAL`, and `diff -r clone/port mport/port` is empty.
- One run wrapped `proof29.py` in `timeout 900`. None of those four runs reached the limit (the longest took 535 s), and the copy was verified clean afterwards.
- Nothing under `/data/projects/toon_bend` or `/dp/toon_rust` was modified. `/tmp/bend` was not updated.

## Artifacts

Everything is under `/data/tmp/review_R29/`:

- `bin/toon`, `bin/toon.js`, `clone/` (the reviewed tree plus the `oracle` link), `mport/` (restored working copy), `mut/<id>/toon`, `mut/results29.jsonl`, `moved/`
- scripts in `r29/`: `h29.py`, `gen29.py`, `dist29.py`, `mhunt29.py`, `m29defs.py`, `mut29.py`, `proof29.py`, `decoy29.py`, `interp29.py`, `run_all.sh`, `df_all.sh`, `reports/`
- logs in `r29/logs/`: `run_all.log`, `df_all.log`, `df_*.log`, `dfjs_*.log`, `diff_*.jsonl`, `mut29_a.log`, `mut29_b.log`, `proofs29.log`, `proof_*.out`, `decoy29_*.log`, `interp29.log`, `conform_base.log`
