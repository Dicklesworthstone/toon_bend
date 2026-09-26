# Round 28: non-author hostile review of toon_bend

| field | value |
|---|---|
| reviewed commit | 6dd844d5d5f43bd1b5b1b89d5d62391725e46e31 |
| clone | fresh `git clone https://github.com/Dicklesworthstone/toon_bend /data/tmp/review_R28/clone`; `git rev-parse HEAD` printed that hash (the expected `6dd844d`) |
| original | `oracle/toon` -> `/data/projects/toon_bend/oracle/toon`, sha256 `821287eaf1a6d320ee1ef7604e74e3cefaa42b69445c96abb9dd310782d04030`, equal to `docs/PIN.toml` |
| Bend | `bun /tmp/bend/bend2/main.ts`, `/tmp/bend` at `15ae0c86f3193b8f645b4bedbc438655b648d0da`, `BEND_NO_TELEMETRY=1` (never updated) |
| tools | bun 1.4.2, Ubuntu clang 21.1.8, Python 3.14.4, markdown-it-py 3.0.0 |
| port binaries | native `/data/tmp/review_R28/bin/toon` (22 s wall); JS `/data/tmp/review_R28/bin/toon.js`, run through `scripts/js-lane.py … --` |
| unmutated corpus | `./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t -- ../bin/toon --threads 1 --` -> `"passed":1110,"failed":0,"inconclusive":0,"stderr_compared":true,"verdict":"PASS","oracle_identity_checked":true` |
| repo gates on this tree | `claims-audit.py` -> `"findings": 0 … "laws": 662, "cases": 1110 … "verdict": "OK"`; `law-coverage.sh` -> `"laws": 662, "proofs": 662 … "verdict": "OK"`; `build-cases.py --check` OK; `cases-lint.sh` OK; `converge.sh` NOT_CONVERGED (clean tail 0); `pin-check.sh` RED only because this clone has no `legacy/Toon` (environment, not a finding) |
| host | shared, 8 cores, 30 GB. 20:20 load 0.85, 24 GB available, 12 GB disk free; 21:24 load 1.5, 24 GB available, 11 GB free. Another session ran a `PROOF.bend` (about 4 GB) during this round. This round used 129 MB of disk. Every build and proof started at >= 12 GiB `MemAvailable`, one at a time, under `systemd-run --user --scope -p MemoryMax=8G` (builds) or `10G` (proofs), `MemorySwapMax=0`; none was killed. Whole-proof peaks 2.8-3.5 GB, 291-477 s |
| harness | `r28/h28.py` runs `./oracle/toon ARGV` and `bin/toon --threads T -- ARGV` (or `js-lane.py toon.js -- ARGV`) on the same stdin and compares stdout, stderr and exit byte for byte, with `TOON_SPEC` removed unless set |

## Findings (counting rule of 2026-09-23, rules 1-6)

| id | sev | class | what | spec |
|---|---|---|---|---|
| R28-1 | MEDIUM | BEHAVIOR (gate that lies; NEW, in R27-1's repair) | R27-1's repair refuses inline HTML only in the BODY rows of the findings table. The HEADER row is still read with the HTML tags dropped and the text between them kept. A findings table with two `sev` columns, the first one struck in HTML (`<del>sev</del>`), is read through the struck column. Header `id`, `<del>sev</del>`, `sev`, `class`, row `R2n-1`, `LOW`, `HIGH`, `BEHAVIOR` renders a struck header over LOW and a plain `sev` header over HIGH, yet the gate counts it as LOW. The same works with `<s>class</s>` for the class column (DOCUMENT is read, BEHAVIOR is rendered). With planted rounds 28 and 29 (`0 \| 0 \| yes`, non-author) whose reports use this header, `converge.sh` prints `CONVERGED`, `claims-audit.py` prints `"findings": 0 … "OK"` and `state-check.sh` prints `0 finding(s)`. The Markdown control `~~sev~~` gives NOT_CONVERGED | PARITY-GATE rules 1, 6; `review_report.py` docstring |
| R28-2 | LOW | BEHAVIOR (gate that lies; in round 27's selection rule (d)) | `claims-audit.py` exempts EVERY mutant count below the inventory's on any line that names two ids `M<nn>`, without comparing the count with the ids named. So `the inventory has 100 mutants in all; M104 and M105 are its newest.` passes (`"findings": 0 … "OK"`). The same total without the ids gives `mutants in all: says 100, the repository has 107`. A pasted `hand-mutants.py M104 M105` line reporting `"mutants": 7, "killed": 7` (seven mutants from two ids) also passes | (claims) |
| R28-3 | MEDIUM | BEHAVIOR (corpus gap; ONE finding against `scripts/hand-mutants.py`: no site is in its inventory) | Six NEW hand mutants survive the whole corpus on c-1t (1110 of 1110 each) AND the whole 662-law `PROOF.bend` as a group (P2: `All terms check.`, 477 s; P9: `All terms check.`, 469 s). The unmutated port equals the original on every distinguishing input, on native t1, on c-8t with `TOON_SPEC=1` and on JS. U3 and U4 (`utf8.start`): the overlong forms at the boundary, `E0 9F BF` (U+07FF) and `F0 8F BF BF` (U+FFFF), are accepted as text. U6 (`utf8.step`): byte `C0` is accepted as a continuation byte. F2 (`dg.high`) and F3 (`dg.low`): an odd significand's interval end counts as inside, so 17-digit integers print wrongly: `[38933209638946775]` gives `38933209638946780` instead of `…776`, and `[36899328138587787]` gives `…780` instead of `…784`. This holds in both printers (encode and `--decode`), and 74 or 90 of 40,000 random numbers differ. Ce (`indent.check.c`): `--indent=-9223372036854775808` says `number too small to fit in target type` instead of `… is not in 0..=16` | S2.2, S4.131, S1.31 |
| R28-4 | LOW | LAW-COVERAGE (ONE finding against `scripts/hand-mutants.py`) | Nine NEW mutants that the corpus kills on c-1t but NO law does. All nine are in group P9, which gives `All terms check.`. U2 `utf8.cont` (U+110000 accepted; 1 case), F1 `dg.tie` (an exact tie rounds down; 2 cases), K2 `jaro.window` (one wider; 3), K3 `jaro.pos` (low end of the window excluded; 5), K4 `best.pick` (among equal J the earlier candidate wins; 2), I1 `item.route` (fields after a tabular first field expected one level deeper; 2), B12 `expo` (negative exponent one too small; 10), Cc `int.beyond` (i64::MAX out of range; 1), Cd `u64.fits` (u64::MAX out of range; 1) | S2.2, S4.132, S1.74, S1.75, S4.224, S5.40, S1.31, S1.32 |

Count under the rule: **BEHAVIOR 3 (MEDIUM 2, LOW 1), LAW-COVERAGE 1 (LOW), DOCUMENT 0.** NEW behavior findings of MEDIUM or above: **2** (R28-1, R28-3). This round is NOT clean. I found **no difference between the UNMUTATED port and the original** on any lane I tried: about 30,700 native executions from my own generators, 798 `-o` sandbox executions, 30,040 `diff-fuzz` inputs with new seeds plus 40,000 number literals, 6,507 JS-lane executions from my generators plus 1,600 `diff-fuzz` inputs on JS, and 24 interpreter executions.

### R28-1 reproduction

The reader alone (`/data/tmp/review_R28/r28/reports/`). Each report holds the header table and one findings table. RENDERED is markdown-it's HTML (commonmark + table + strikethrough, the reader's own configuration):

```
== control          {"rows": [{"id": "R28-1", "sev": "HIGH", "class": "BEHAVIOR"}], "counted": 1, "errors": []}
== hdr_strike_md    {"rows": [{"id": "R28-1", "sev": "HIGH", "class": "BEHAVIOR"}], "counted": 1, "errors": []}
   RENDERED: <tr><th>id</th><th><s>sev</s></th><th>sev</th><th>class</th><th>what</th></tr> <tr><td>R28-1</td><td>LOW</td><td>HIGH</td><td>BEHAVIOR</td><td>x</td></tr>
== hdr_del          {"rows": [{"id": "R28-1", "sev": "LOW", "class": "BEHAVIOR"}], "counted": 0, "errors": []}
   RENDERED: <tr><th>id</th><th><del>sev</del></th><th>sev</th><th>class</th><th>what</th></tr> <tr><td>R28-1</td><td>LOW</td><td>HIGH</td><td>BEHAVIOR</td><td>x</td></tr>
== hdr_cls          {"rows": [{"id": "R28-1", "sev": "HIGH", "class": "DOCUMENT"}], "counted": 0, "errors": []}
   RENDERED: <tr><th>id</th><th>sev</th><th><s>class</s></th><th>class</th><th>what</th></tr> <tr><td>R28-1</td><td>HIGH</td><td>DOCUMENT</td><td>BEHAVIOR</td><td>x</td></tr>
```

(`~~sev~~` renders `<s>sev</s>`, and the gate drops that header and reads the plain `sev` column. The raw `<del>sev</del>` renders the same kind of struck header, yet the gate reads THROUGH it.) Cause: `_tables` records inline HTML for every row, but `parse` refuses it only for rows `tables[tn][1:]`, never for the header row that picks the columns (`head = [c.lower() for c in rows[0]]`).

Full gate run: `python3 /data/tmp/review_R28/r28/decoy28.py html`, in the one clone. It appends rows 28 and 29 (`0 | 0 | yes`, non-author) and writes both reports with the header `| id | <del>sev</del> | sev | class | what | spec |` and a row whose struck column says LOW and whose plain `sev` column says HIGH. It refreshes the prose spans, runs the gates, restores with `git checkout` and moves the reports into `/data/tmp/review_R28/moved/`. From `r28/decoy28_html.log`:

```
$ python3 scripts/review_report.py docs/reviews/round-28.md 28   (rc=0)
{"commit": "6dd844d5d5f43bd1b5b1b89d5d62391725e46e31", "rows": [{"id": "R28-1", "sev": "LOW", "class": "BEHAVIOR"}], "counted": 0, "errors": []}
$ ./scripts/converge.sh docs/PORT_STATE.md   (rc=0)
tier T2: rounds 29, clean 7, clean tail 2, last two clean True, non-author round True, open OQ 0, open DISC 0
convergence: CONVERGED
$ python3 scripts/claims-audit.py   (rc=0)
{"files": 16, "absent": [], "findings": 0, "historical_lines_exempt": 6, "laws": 662, "cases": 1110, "disc": {"accepted": 11, "resolved": 4, "open": 0}, "verdict": "OK"}
$ ./scripts/state-check.sh docs/PORT_STATE.md   (rc=0)
state-check: 0 finding(s)
after restore: ?? oracle
```

Control, `python3 decoy28.py md` (`~~sev~~`, `r28/decoy28_md.log`): both reports counted 1, and `converge.sh` rc=1 `NOT_CONVERGED` (`round 28: the table says 0 counted finding(s), docs/reviews/round-28.md lists 1`). `claims-audit.py` gives `"findings": 3`. The planted reports are decoys: their row ids (`R28-1` in the planted round-28 file, `R29-1` in the planted round-29 file) are NOT findings of this report, and those files live only in `moved/`. This is not a hidden table and not a complete forgery. The one table renders, and a reader sees HIGH under the plain `sev` header. Fix direction: refuse inline HTML in the header row too (or refuse a duplicated header name).

### R28-2 reproduction

`r28/sel28.log`: each line was appended after the `- law admission, round 27:` line of `docs/PORT_STATE.md` in the clone, `claims-audit.py` was run, and the file was restored with `git checkout`:

```
== A: two ids, count 7 (selection larger than the ids named)
   - law admission, round 28: `python3 scripts/hand-mutants.py M104 M105` → `{"mutants": 7, "killed": 7, "survived": [], "not_evidence": [], "verdict": "STRONG"}`
  rc=0 {… "findings": 0, … "verdict": "OK"}
== B: stale total on a line naming two ids
   - the inventory has 100 mutants in all; M104 and M105 are its newest.
  rc=0 {… "findings": 0, … "verdict": "OK"}
== C: control, the same total without ids
  rc=1 docs/PORT_STATE.md:50: mutants in all: says 100, the repository has 107
```

Cause (`claims-audit.py`, the `selective` test): `selective and name.startswith("mutants") and said < want` skips every mutant count on the line, including the full-set pattern `mutants in all`. Fix direction: a selection's count must equal the number of distinct ids the line names, and `mutants in all` is never a selection.

### R28-3 reproductions (the original and the mutant; the unmutated port equals the original on native t1, c-8t `TOON_SPEC=1` and JS)

```
== U3 argv=['-e'] stdin=b'"\xe0\x9f\xbf"'
   orig   (b'', b'Failed to read stdin: stream did not contain valid UTF-8\n', 1)
   mutant (b'\xdf\xbf\n', b'', 0)
== U4 argv=['-d'] stdin=b'a: \xf0\x8f\xbf\xbf'
   orig   (b'', b'Failed to read stdin: stream did not contain valid UTF-8\n', 1)
   mutant (b'{\n  "a": "\xef\xbf\xbf"\n}\n', b'', 0)
== U6 argv=['-d'] stdin=b'a: \xc3\xc0'
   orig   (b'', b'Failed to read stdin: stream did not contain valid UTF-8\n', 1)
   mutant (b'{\n  "a": "\xc3\x80"\n}\n', b'', 0)
== F2 argv=['-e'] stdin=b'[38933209638946775]'
   orig   (b'[1]: 38933209638946776\n', b'', 0)
   mutant (b'[1]: 38933209638946780\n', b'', 0)
== F2 argv=['-d'] stdin=b'a: 38933209638946775'
   orig   (b'{\n  "a": 38933209638946776\n}\n', b'', 0)
   mutant (b'{\n  "a": 38933209638946780\n}\n', b'', 0)
== F3 argv=['-e'] stdin=b'[36899328138587787]'
   orig   (b'[1]: 36899328138587784\n', b'', 0)
   mutant (b'[1]: 36899328138587780\n', b'', 0)
== Ce argv=['-e', '--indent=-9223372036854775808'] stdin=b'{}'
   orig   (…"-9223372036854775808 is not in 0..=16\n\nFor more information, try '--help'.\n", 2)
   mutant (…"number too small to fit in target type\n\nFor more information, try '--help'.\n", 2)
```

Mutant texts (`r28/m28defs.py`):

- U3 `utf8.start` (text): `Decoding{2n, (c .&. 15 : U32), 2048, keep, rev}` -> `2047`
- U4 `utf8.start` (text): `Decoding{3n, (c .&. 7 : U32), 65536, keep, rev}` -> `65535`
- U6 `utf8.step` (text): `utf8.cont(Bool.and(U32.is_ge(c, 128), U32.is_le(c, 191))` -> `U32.is_le(c, 192)`
- F2 `dg.high` (f64): `case True{} EQ{}:` -> `case _ EQ{}:` (the dg.high arm)
- F3 `dg.low` (f64): `case True{} EQ{}:` -> `case _ EQ{}:` (the dg.low arm)
- Ce `indent.check.c` (cli): `int.beyond(c, "9223372036854775808")` -> `int.beyond(c, "9223372036854775807")`

Proofs (`r28/logs/proofs28.log`, whole `PROOF.bend`, 662 laws):

```
P1 U3,U4,U6,S2,F2,F3 PROOF rc=1 secs=291 ['Maximum resident set size (kbytes): 3326260'] stdout-first=[] loc=['Location: LAWS.decode_scan_lone_cr_inside_kept'] restored=IDENTICAL   (S2 killed by law)
P2 U3,U4,U6,F2,F3 PROOF rc=0 secs=477 ['Maximum resident set size (kbytes): 3494296'] stdout-first=['All terms check.'] loc=[] restored=IDENTICAL
P9 Ce,U2,F1,K2,K3,K4,I1,B12,Cc,Cd PROOF rc=0 secs=469 ['Maximum resident set size (kbytes): 2828272'] stdout-first=['All terms check.'] loc=[] restored=IDENTICAL
```

Why the corpus misses them: the three overlong cases (`jsonerr_overlong_utf8*`) use values far below the minimum (`c0 af`, `e0 90 80`, `f0 88 80 80`), never the last overlong value, and the laws `utf8_verdict_rejects_overlong` / `golden_jsonerr_overlong_utf8` have the same shape. No case holds a continuation byte of `C0` or above. F2 and F3 need a value whose interval end is exactly reached with an odd significand (17-digit integers near 2^55). The `encnum_display_ties` / `decfmt_shortest_ties` cases pin only `dg.tie` (F1 is killed by them). Fix direction: capture these inputs as cases, write closed laws where the checker can evaluate them (the UTF-8 ones are cheap: `T.utf8.finish(T.utf8.bytes([224, 159, 191], …)) == None{}`), and add the sites to the inventory.

### R28-4 reproductions

Corpus failures on c-1t (`/data/tmp/review_R28/mut/results28.jsonl`): U2 1 (`jsonerr_utf8_above_max`), F1 2 (`encnum_display_ties`, `decfmt_shortest_ties`), K2 3 (`usage_enum_similar_picks_best`, `usage_similar_arg_nope`, `usage_similar_arg_after_commit`), K3 5 (`usage_enum_similar_off`, `usage_enum_similar_picks_best`, `usage_enum_similar_tie`, `usage_enum_similar_boundary_30`, …), K4 2 (`usage_enum_similar_tie`, `usage_similar_arg_tie`), I1 2 (`toonerr_list_obj_first_tabular`, `fx_dec_arrays_nested_05`), B12 10 (`decnum_decimals`, `decnum_exponents`, `decnum_extremes`, `decnum_compact`, …), Cc 1 (`usage_indent_i64_max`), Cd 1 (`flag_flatten_depth_big`). Proof: P9 above (`All terms check.`). Mutant texts: U2 `U32.is_le(value, 1114111)` -> `1179647`; F1 dg.tie `case EQ{}: d_odd` -> `False{}`; K2 `Nat.sub(Nat.div(Nat.max(la, lb), 2n), 1n)` -> `Nat.div(Nat.max(la, lb), 2n)`; K3 `Nat.is_ge(j, lo)` -> `Nat.is_gt(j, lo)`; K4 best.pick gains `case True{} EQ{}: old` before the catch-all; I1 item.route's `FObj{…, 1n+t, 1n+t, True{}, key, quoted}` -> `…, 1n+t, 2n+t, …`; B12 `Nat.show(1n+z)` -> `Nat.show(z)` in `expo`; Cc `String.is_gt(c, lim)` -> `String.is_ge(c, lim)`; Cd `String.is_le(d, "18446744073709551615")` -> `String.is_lt(…)`.

## Mutant table (all 27 mutants of this round)

Each mutant is an exact-text replacement (`r28/m28defs.py`). Each was applied to the one working copy `/data/tmp/review_R28/mport/port`, built natively (memory-gated), restored (every record says `restored: IDENTICAL`, and `diff -r clone/port mport/port` is empty at the end) and run through the whole corpus on c-1t.

| mutant | def | change | corpus c-1t failing | law | verdict |
|---|---|---|---|---|---|
| U3 | `utf8.start` | 3-byte minimum 0x7FF | 0 | none (P2) | R28-3 |
| U4 | `utf8.start` | 4-byte minimum 0xFFFF | 0 | none (P2) | R28-3 |
| U6 | `utf8.step` | C0 is a continuation byte | 0 | none (P2) | R28-3 |
| F2 | `dg.high` | upper end always inside | 0 | none (P2) | R28-3 |
| F3 | `dg.low` | lower end always inside | 0 | none (P2) | R28-3 |
| Ce | `indent.check.c` | i64::MIN too small | 0 | none (P9) | R28-3 |
| U2 | `utf8.cont` | U+110000..U+11FFFF accepted | 1 | none (P9) | R28-4 |
| F1 | `dg.tie` | exact tie rounds down | 2 | none (P9) | R28-4 |
| K2 | `jaro.window` | window one wider | 3 | none (P9) | R28-4 |
| K3 | `jaro.pos` | window low end excluded | 5 | none (P9) | R28-4 |
| K4 | `best.pick` | earlier of equal J wins | 2 | none (P9) | R28-4 |
| I1 | `item.route` | sibling fields one level deeper | 2 | none (P9) | R28-4 |
| B12 | `expo` | negative exponent one too small | 10 | none (P9) | R28-4 |
| Cc | `int.beyond` | i64::MAX out of range | 1 | none (P9) | R28-4 |
| Cd | `u64.fits` | u64::MAX out of range | 1 | none (P9) | R28-4 |
| S2 | `seg.go` | any CR in a line dropped | 0 | `decode_scan_lone_cr_inside_kept` (P1) | killed by law |
| K5 | `est.ch` | whitespace counted as a character | 15 | `stats_estimate_small` (P3) | killed |
| K1 | `lower.rev` | T-Z not lower-cased | 1 | `lower_rev_folds_upper_toon` (P4) | killed |
| J2 | `hex.fin` | wrong message after a high surrogate | 2 | `golden_jsonerr_high_then_bmp` (P5) | killed |
| F4 | `int.fit` | integers below 2^60 print own digits | 8 | `int_fit_refuses_2p48` (P6) | killed |
| B9 | `seg.bom` | text BOM not dropped | 2 | `decode_scan_byte_order_mark` (P7) | killed |
| B8 | `surplus.tab` | a `- ` line at row depth is a surplus row | 1 | `decode_list_line_after_full_table` (P8) | killed |
| J1 | `hex.fin` | lone low surrogate accepted | 1 | screen: `golden_jsonerr_lone_low_surrogate` exists | killed (not proved singly) |
| B7 | `surplus.list` | bare `-` not surplus | 1 | screen: `golden_toonerr_extra_bare_dash_undetected` exists | killed (not proved singly) |
| Cb | `indent.small` | indents 10-16 rejected | 1 | screen: `golden_flag_indent_16_encode` exists | killed (not proved singly) |
| S1 | `seg.go` | every trailing CR dropped | 0 | - | no distinguishing input found (the original also yields `b` for `a: b\r\r\n`); treated as equivalent, not a finding |
| F5 | `dg.init` | 2^-1022 as a power-of-two edge | 0 | - | no distinguishing input in 40,000 numbers plus the min-normal inputs; treated as equivalent, not a finding |

The "screen" rows were left out of the peeling groups, because a golden law of the very case that kills them exists in `port/LAWS.bend`. No proof was run for them alone. None of the three is counted as a finding.

## Round 27's repairs (item 0)

| R27 finding | this round |
|---|---|
| R27-1 (inline HTML in findings rows) | Holds for body rows: `<del>`, `<s>` and `<span hidden>` in a findings cell are refused. It does NOT hold for the header row that chooses the columns (see **R28-1**) |
| R27-2 (JSONL per line) | Holds. `r28/reach28.log`: an escaped commit is caught in a 2-line valid JSONL file, beside a raw U+2028 or U+0085 inside a string (which `splitlines` splits), in a pretty-printed `.json` with a trailing comma, and under a `sha` key with a bad sibling line (every case gives `"findings": 1`). A latin-1 evidence file stops the audit with `UnicodeDecodeError` (rc=1, fails closed) |
| (d) selection of M100+ ids | Implemented as stated, but the exemption is not tied to the ids named (see **R28-2**) |
| R27-3 / R27-4 (cases, laws, M104-M108) | In the tree (`law-coverage.sh` 662/662; the corpus has 1110 cases). NEW neighbouring-arm mutants: U3/U4 (neighbours of the surrogate and overlong laws), F2/F3 (neighbours of F1's tie arm), and Ce (neighbour of Cc, which `usage_indent_i64_max` pins, and of R27's `indent`/`budget` sites) survive everything (**R28-3**). I did not re-run `hand-mutants.py M104-M108` |

## Clean areas: compared executions of the UNMUTATED port

| lens (script, seed) | target | executions (compared pairs) | diffs |
|---|---|---|---|
| `gen28.py stats` 28001 (200), 28101 (3000), 28201 (1000, t8 + `TOON_SPEC=1`) | item 1: `--stats` both directions on documents with 2-, 3- and 4-byte UTF-8, combining marks, emoji, ZWSP, NBSP, U+3000, U+2028, NEL, DEL; empty, whitespace-only and BOM-only documents in both directions | 4200 | 0 |
| `gen28.py listitems` same seeds | item 1: list items whose first field is a tabular array, an inline array, a nested list or an empty array, followed by sibling fields at depths t-1..t+1, at indents 1-8 and 0, three delimiters, wrong counts, strict / `--no-strict` / `--expand-paths safe` | 4200 | 0 |
| `gen28.py nostrict` same seeds | item 1: 22 strict-only errors (counts, widths, blank lines in bodies, indentation non-multiples, tabs, over-indent, surplus rows and items) with context before and after, 4 indents, with and without `--no-strict` | 4200 | 0 |
| `gen28.py escapes` same seeds | item 2: every C0, DEL, U+0080-U+009F, U+2028/9, BOM, and 22 TOON escapes incl. `\ud800`, `\udc00`, a pair, `\u0000`, `\x41`, `\0` in values, keys, inline arrays, tabular fields, list items and dotted keys through plain `--decode` and `--expand-paths safe` | 4200 | 0 |
| `gen28.py printer` same seeds | item 2: 46 boundary numbers (1e21, 1e-7, -0, 5e-324, 2.4e-324, 1.7976931348623157e308 and its neighbours, 2^53+1, min normal and its predecessor, …) plus random mantissa/exponent texts in 5 JSON and 7 TOON shapes | 4200 | 0 |
| `gen28.py deep` same seeds | item 2: nesting 120-131 in objects, dotted keys under expansion, list-in-list chains, JSON arrays/objects/mixed, key folding with flatten depths 1-130 | 4200 | 0 |
| `auto28.py` | item 1: 31 file names (`x.TOON`, `x.Toon`, `x.json.toon`, `.toon`, `x.`, `x.toon ` with a trailing space or TAB, fullwidth `ｔｏｏｎ`, `x..toon`, `-x.toon`, `dir.toon/x`, …) × 15 contents × 7 option sets; stdin whose first or last bytes are space, TAB, LF, CRLF, CR, VT, FF, NBSP, U+3000, BOM × 11 bodies × 6 option sets | 4707 | 0 |
| `outpath28.py` | item 1: `-o` / `--output=` / `--output` to an existing file, a read-only file, a directory, `dir/`, a read-only directory, a missing directory, a dangling link, a link to a file, the input file itself, `-`, the empty word, a space, `.`, `/dev/null`, `/dev/full`, a Unicode name, a name with LF; 7 input sets. Each run is in a fresh sandbox and the resulting file trees are compared too | 399 invocations × 2 programs | 0 |
| `diff-fuzz.py` mutate/docs/argv/expand/collide 280001 (4000 each, t1), 280002 (2000 each, `--switch TOON_SPEC=1`, t8) | repository lenses, new seeds | 30,000 inputs (every log `"differences": 0 … "verdict": "PASS"`) | 0 |
| `diff-fuzz.py numbers` 280003 (`--runs 40000 --switch TOON_SPEC=1`), `scale` 280004 (t1), 280005 (`--switch`, t8) | `"number_literals": 40000`; scale `"too_slow": 0` | 200 + 20 + 20 inputs | 0 |
| **JS lane** | `gen28.py` six lenses 28301 (300 each), `auto28.py` (4707); `diff-fuzz.py` mutate/docs/argv/expand 280101 (400 each, `js-lane.py toon.js --`); every R28-3 distinguishing input | 6,507 + 1,600 inputs + 7 | 0 |
| **interpreter lane** (`r28/interp28.py`, `interp-lane.sh`) | 12 inputs (list item with a tabular first field, CR CR LF, `--stats` with multibyte and on empty input both ways, lenient blank line, TOON `\u`, the five printer boundaries, C1 controls under expansion, overlong E0 9F BF, U+FFFF), run twice | 24 | 0 |

One harness error of mine, stated so that nobody reads it as a finding: my first interpreter run did not export `BEND_NO_TELEMETRY`. All 12 inputs then differed only by the Bend CLI's own line `bend 2.0.27 is available: run bend update` on stderr. With `BEND_NO_TELEMETRY=1` exported, as the brief requires, 12 of 12 are `same`, and the same holds on the repeat run.

## What this round did NOT cover

- A whole proof of the UNMUTATED tree. P2 and P9 ending in `All terms check.` imply that the unmutated laws check. Also not run: single proofs of each R28-3 / R28-4 mutant (only the groups), `lanes.sh`, `port-doctor.sh`, `floor.sh`, `stdio-probe.py`, `harness-selftest.sh`, `hand-mutants.py` for any id, and any performance measurement
- J1, B7 and Cb were not proved killed by a law alone (screen only). K5, K1, J2, F4, B9 and B8 each stopped a group proof at the named law. I did not check separately that the named law is the only one that bites
- `bignat.bend` mutants; the TOON header parser (`hdr.*`) and the path expansion (`xm.*`, `plan`, `merge`) beyond the diff-fuzz `expand`/`collide` lenses; the encoder's folding and quoting arms (R27 attacked those)
- Review-report layouts beyond the header row and inline HTML; reachability shapes beyond the seven in `reach28.log`
- DOCUMENT review beyond the repository gates' own counts (0 findings) and the selection rule of R28-2

## Process notes (RULE 1)

- I deleted NO file. Planted reports and evidence files were moved with `os.rename` into `/data/tmp/review_R28/moved/` (13 files). The clone was restored with `git checkout` after every plant (`git status --short` shows only `?? oracle`). The mutant working copy `mport/` was restored after every build and proof (`restored: IDENTICAL` on every record; `diff -r clone/port mport/port` is empty).
- Three duplicate monitor watches of mine (all waiting on the same log) were stopped with TaskStop. They only waited, wrote nothing, and nothing from them is cited.
- Nothing under `/data/projects/toon_bend` or `/dp/toon_rust` was modified. `/tmp/bend` was not updated.

## Artifacts

Everything is under `/data/tmp/review_R28/`:

- `bin/toon`, `bin/toon.js`, `clone/` (the reviewed tree plus the `oracle` link), `mport/` (restored working copy), `mut/<id>/toon`, `mut/results28.jsonl`, `moved/`, `r28/work/`, `r28/opath/`
- scripts in `r28/`: `h28.py`, `gen28.py`, `auto28.py`, `outpath28.py`, `interp28.py`, `m28defs.py`, `mut28.py`, `dist28.py`, `proof28.py`, `decoy28.py`, `reach28.py`, `run_all.sh`, `df_all.sh`, `js_all.sh`, `reports/`
- logs in `r28/` and `r28/logs/`: `decoy28_html.log`, `decoy28_md.log`, `reach28.log`, `sel28.log`, `run_all.log`, `df_all.log`, `df_*.log`, `dfjs_*.log`, `js_all.log`, `mut28_a.log`, `mut28_b.log`, `proofs28.log`, `proof_P*.log`, `proof_P*.out`, `diff_*.jsonl`
