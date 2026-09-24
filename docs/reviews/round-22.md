# Round 22: non-author hostile review of toon_bend

| field | value |
|---|---|
| reviewed commit | `2bde9683e727223eb3313f9be6999807551141ef` (fresh clone `/data/tmp/review_R22/clone`; `git rev-parse HEAD` printed that hash, the expected `2bde968`) |
| original | `oracle/toon` -> `/data/projects/toon_bend/oracle/toon`, sha256 `821287eaf1a6d320ee1ef7604e74e3cefaa42b69445c96abb9dd310782d04030`, equal to `docs/PIN.toml` |
| Bend | `bun /tmp/bend/bend2/main.ts`, `/tmp/bend` at `15ae0c8`, `BEND_NO_TELEMETRY=1` |
| tools | bun 1.4.2, Ubuntu clang 21.1.8, Python 3.14.4 |
| port binaries | native `bin/toon` (29.5 s wall, exit 0); JS `js/toon.js` (exit 0), run through `scripts/js-lane.py` |
| unmutated corpus | `./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t -- ../bin/toon --threads 1 --` -> `'passed': 1078, 'failed': 0, 'inconclusive': 0, 'stderr_compared': True, 'verdict': 'PASS', 'oracle_identity_checked': True` |
| repo gates on this tree | `claims-audit.py` -> `"findings": 0 … "laws": 612, "cases": 1078 … "verdict": "OK"`; `converge.sh` -> `"rounds": 21, "clean": 5, "clean_tail": 0 … "NOT_CONVERGED"`; `law-coverage.sh` -> `"laws": 612, "proofs": 612 … "verdict": "OK"` |
| host | shared, 8 cores, 30 GB. 13:46 load 4.8, 24 GB available; 13:53 load 18, 19 GB available; 14:10 load 8.6, 14 GB available (another session's `hand-mutants` proof running beside mine). Proofs ran one at a time from my queue, each under `proof_capped.sh` (started only with ≥ 12 GB available, killed above 10 GB). At the coordinator's request (14:30) I stopped my queue for a 15-minute window: the whole proof of group GA had started 2 s before and was KILLED by me (INCONCLUSIVE, not counted, re-run later). Nothing else was killed. No timing here is evidence of speed |
| harness | `r22/cmp.py` (round 21's, paths changed) runs `./oracle/toon ARGV` and `bin/toon --threads T -- ARGV` (or, with `PORT_JS`, `python3 scripts/js-lane.py js/toon.js -- ARGV`) on the same stdin and compares stdout, stderr and exit byte for byte; `TOON_SPEC` is removed unless a run sets it. `r22/q.py` does the same for a list of hand inputs. "Executions" counts every run of either program |

## Findings (counting rule of 2026-09-23, rules 1-6)

| id | sev | class | what | spec |
|---|---|---|---|---|
| R22-1 | MEDIUM | BEHAVIOR (gate that lies; NEW) | `converge.sh` and `claims-audit.py` accept rounds that have NO review report. With two rows added to the rounds table (`\| 22 \| non-author … (non-author) \| 0 \| 0 \| yes \|` and the same for 23), `docs/reviews/` still ending at `round-21.md`, and the prose summaries refreshed to match (the ONLY complaints the audit raises), `converge.sh` prints `"verdict": "CONVERGED"` for T2, `claims-audit.py` prints `"findings": 0 … "verdict": "OK"`, and `state-check.sh` prints `0 finding(s)`. The audit only checks table rows against the reports that EXIST (`for r, path in f["reviews"].items()`); nothing requires a row labelled non-author to have `docs/reviews/round-<n>.md`, and `converge.sh` never looks at `docs/reviews/`. So the gate that decides SHIP can be satisfied by two table rows without any evidence behind them, which is exactly what R21-2's repair was meant to prevent | PARITY-GATE rules 1, 6; PORT_STATE "Owner decisions" 2026-09-23 |
| R22-2 | MEDIUM | BEHAVIOR (gate that lies; R21-2's audit half, REOPENED: the repair in `887a9a7` changed only `converge.sh`) | R21-2's fix direction asked the audit to "compare counts even when the report yields 0, and read severity and class from their own columns". Neither was done: `claims-audit.py` still has `re.search(r"\bBEHAVIOR\b", row) and re.search(r"\b(?:MEDIUM\|HIGH)\b", row)` (case-sensitive, anywhere in the row) and `if rows and rows != …`. Control: set round 21's row to `0 \| 0 \| yes` alone and the audit catches it (`round 21: the table says 0 findings, docs/reviews/round-21.md lists 2`). Then ALSO re-spell the two counted rows of `round-21.md` as `Medium \| Behavior (…)` (title case; the words and the report's substance unchanged): the count check disappears, the only remaining audit lines are the prose ones R22-1 shows how to refresh, and `converge.sh` counts round 21 as clean (`"clean": 6, "clean_tail": 1`). The same happens with the class spelled `BEHAVIOUR` and the severity left `MEDIUM` (clone `gate9`: `claims-audit.py … \| grep -c "round 21: the table"` -> `0`). I count it as a reopened finding, not a new one; `converge.sh`'s own rule treats a reopened finding as resetting the clean streak | as R21-2 |
| R22-3 | LOW | BEHAVIOR (gate that lies; partly R21-3 REOPENED, partly new shapes) | `claims-audit.py`'s reachability rule for COUNTED evidence still misses shapes. One that R21-3 named is NOT repaired although `887a9a7` says all four shapes are closed: a hash followed by a suffix in the file name (`COUNTED.canada.decode.494ef82-pre.json` -> `0 OK`). New shapes, each `0 OK` with the unreachable `494ef82` planted: `"after": {"commit": "494ef82 (scratch)"}`, `"after": {"binary": {"commit": …}}`, `"after": {"sha": …}`, a file whose JSON is a list, `"runs": [{"commit": …}]`, a `.jsonl` file, and every `COUNTED-PROFILE.*` file (the prefix test is `name.startswith("COUNTED.")`, so the committed `COUNTED-PROFILE.825e44de.counts.jsonl`, which the profile's claims rest on, is never read). Control: `"after": {"commit": "494ef82"}` -> `1 FINDINGS`. No committed file has these shapes today, so no document states a false number now | (claims) |
| R22-4 | LOW | LAW-COVERAGE (ONE finding against `scripts/hand-mutants.py`: none of these sites is in its inventory) | Five NEW hand mutants are killed by the corpus on c-1t but survive the WHOLE 612-law proof (run together as group GC: `All terms check.`, 437 s, peak 6.4 GB; singles below). V7: the JSON reader's `\b` escape decodes to FF (1 case catches it: `encstr_escapes_in`). V8: `esc.cls` refuses `\f` (3 cases). V10: `key_first` refuses `_`, so `_a` is quoted as a key (3 cases). V14: `row.lock`'s arm for a row SHORTER than the header returns the lockstep verdict, so `[{"a":1,"b":2},{"a":3}]` is written as a table whose second row has ONE cell (`[2]{a,b}:\n  1,2\n  3`), losing the shape (2 cases: `enc_tabular_corners`, `fx_enc_arrays_objects_07`). V25: `vk.arr` lets an array that is itself a list item be tabular (S4.42; 1 case: `enc_aoa_corners`). Round 21's R21-4 repair (the laws on `]` `"` `\`, signed exponents, `\/`, the words) HOLDS: every neighbouring mutant I wrote in those defs (`bad_char` `:` LF delimiter, `is_word` false, `needs_quote` dash and empty, the JSON reader's `\t`, 16 `like.ph` arms) is refused by a law (table below) | S2.18, S4.21, S4.36, S4.42 |
| R22-5 | LOW | DOCUMENT | `docs/PORT_STATE.md:126` still says "a clean round has < 3 new genuine findings". Since `887a9a7`, `converge.sh` requires ZERO for rounds from 20 and says so: with round 21 set to `2 \| 2 \| yes`, `./scripts/converge.sh docs/PORT_STATE.md` prints `missing: round 21 is marked clean but records 2 new genuine finding(s) (from round 20 every counted finding is a MEDIUM-or-HIGH behaviour finding, so a clean round has none)`. `PORT_REPORT.md:12` states the new rule correctly, so the two claim-bearing documents disagree | (claims) |

Count under the rule: **BEHAVIOR 3 (MEDIUM 2, LOW 1), LAW-COVERAGE 1 (LOW), DOCUMENT 1 (LOW).** NEW behavior findings of MEDIUM or above: **1** (R22-1); R22-2 is R21-2's unrepaired half (reopened). Either way this round is NOT clean. I found **no difference between the UNMUTATED port and the original** on any lane, in about 345,000 native executions of my lenses and hand inputs, at least 50,000 from `diff-fuzz` with new seeds, about 17,000 on the JS lane and 28 on the interpreter (tables below). No mutant I wrote survived the corpus.

### R22-1 reproduction

`/data/tmp/review_R22/r22/repro_R22_1.sh DIR` clones the reviewed tree into DIR, applies `r22/R22-1.diff` (8 insertions, 6 deletions in PORT_STATE.md and PORT_REPORT.md: the two rows, and the ranges "6 to 21" -> "6 to 23", the findings lists extended by ", 0 and 0", the pasted converge line replaced by the new one), then runs the gates:
```
$ /data/tmp/review_R22/r22/repro_R22_1.sh /data/tmp/review_R22/gate5
 docs/PORT_REPORT.md |  4 ++--
 docs/PORT_STATE.md  | 10 ++++++----
 2 files changed, 8 insertions(+), 6 deletions(-)
round-21.md                                   # (the last file in docs/reviews/)
{"files": 16, "absent": [], "findings": 0, "historical_lines_exempt": 6, "laws": 612, "cases": 1078, "disc": {"accepted": 11, "resolved": 4, "open": 0}, "verdict": "OK"}
{"tier": "T2", "rounds": 23, "clean": 7, "clean_tail": 2, "last_two_clean": true, "non_author_round": true, "open_oq": [], "open_disc": [], "unfixed": [], "verdict": "CONVERGED", "missing": []}
state-check: 0 finding(s)
```
Before the prose refresh (rows only), the audit's 12 findings were all of the kinds "'rounds 6 to 21' summarises the review series but stops at 21" and "a pasted converge.sh line says …", none about a missing report. Fix direction: for every round from the first non-author one, require `docs/reviews/round-<n>.md` (in the audit, and in `converge.sh` before it counts a round clean), and apply the report comparison when the report yields 0 rows too.

### R22-2 reproduction

```
$ /data/tmp/review_R22/r22/repro_R22_2.sh /data/tmp/review_R22/gate6 control     # table row 21 -> "0 | 0 | yes" only
docs/PORT_STATE.md:0: round 21: the table says 0 findings, docs/reviews/round-21.md lists 2
{"files": 16, … "findings": 5, … "verdict": "FINDINGS"}
$ /data/tmp/review_R22/r22/repro_R22_2.sh /data/tmp/review_R22/gate7             # the same, plus "Medium | Behavior" in round-21.md
 docs/PORT_STATE.md       | 2 +-
 docs/reviews/round-21.md | 4 ++--
{"tier": "T2", "rounds": 21, "clean": 6, "clean_tail": 1, … "verdict": "NOT_CONVERGED", "missing": ["clean rounds since last reset 1 < 2"]}
$ cd /data/tmp/review_R22/gate7 && python3 scripts/claims-audit.py | grep -v '^    |'
docs/PORT_STATE.md:70: rounds 6 to 21 lists [… 2, 2]; the table gives [… 2, 0]
docs/PORT_REPORT.md:12: rounds 6 to 21 lists [… 2, 2]; the table gives [… 2, 0]
docs/PORT_REPORT.md:32: a pasted converge.sh line says clean=5; converge.sh says 6 today
docs/PORT_REPORT.md:32: a pasted converge.sh line says clean_tail=0; converge.sh says 1 today
{"files": 16, … "findings": 4, … "verdict": "FINDINGS"}          # no "round 21: the table says …" line any more
```
The four remaining lines are prose that an author refreshes as in R22-1.

### R22-3 reproduction

```
$ /data/tmp/review_R22/r22/repro_R22_3.sh /data/tmp/review_R22/gate8
== A control: after.commit = 494ef82                  1 FINDINGS
== B after.commit = '494ef82 (scratch)'               0 OK
== C after.binary.commit (nested one level deeper)    0 OK
== D after.sha                                        0 OK
== E the whole file a one-element list                0 OK
== I runs: [{commit: 494ef82}]                        0 OK
== file name COUNTED.canada.decode.494ef82-pre.json   0 OK
== file name COUNTED-PROFILE.494ef82.counts.json      0 OK
== file name COUNTED.canada.decode.494ef82.jsonl      0 OK
```
(`git status --short` in `gate8` is empty afterwards: every edit was restored, planted names moved to `r22_R22_3_moved/`.)

### R22-4 reproductions (mutant against the original; `r22/tri.py`; every row: the unmutated port is identical to the original)

```
V7  ["a\bb"]                      orig: [1]: a\x08b                 mut: [1]: a\x0cb
V8  ["a\fb"]                      orig: [1]: a\x0cb  (exit 0)       mut: Failed to parse JSON: invalid escape at line 1 column 5 (exit 1)
V10 {"_a":1,"a_":2}               orig: _a: 1\na_: 2                mut: "_a": 1\na_: 2
V14 [{"a":1,"b":2},{"a":3}]       orig: [2]:\n  - a: 1\n    b: 2\n  - a: 3      mut: [2]{a,b}:\n  1,2\n  3
V25 [[{"a":1},{"a":2}]]           orig: [1]:\n  - [2]:\n    - a: 1\n    - a: 2  mut: [1]:\n  - [2]{a}:\n    1\n    2
```
Proofs: `r22/proofs22.log` (`{"id": "GC", "mode": "full", "proof": "PROOF rc=0 killed=0 peak_kb=6428192 secs=437 last: All terms check."}`), singles V14 alone `PROOF rc=0 … secs=440 last: All terms check.`, V25 alone `PROOF rc=0 … secs=434 last: All terms check.`, V10 alone `PROOF rc=0 … secs=481 last: All terms check.`; V7 and V8 ran only inside group GC (see "What this round did NOT cover").
Fix direction: a law each for `\b`/`\f` (e.g. `["a\bb","a\fb"]`), a bare `_`-initial key, a short row after a full one IN header order (R21's `encode_row_missing_a_header_key_is_list_form` has a REORDERED short row, which takes the general test, not `row.lock`), and a list item that is an array of objects; add the five sites to `hand-mutants.py`.

## Mutant table (all mutants of this round)

Each mutant is one exact-text replacement in a copy of `port/` (`r22/mut22.py`; `r22/mut22/<id>/diff.txt`), built natively and run through the whole corpus on c-1t. NO mutant survived the corpus (smallest kill: 1 case). For corpus-killed mutants I then looked for a law: first a subset proof of the golden laws of the failing cases (when those cases have one), otherwise all 317 non-golden laws (`^(?!golden_)`), and for the survivors of that, the WHOLE proof (group GB, then GC without V3, then singles). "refused by" names the law in the checker's `Location:` line (`r22/proofs22.log`).

| id | def | change | corpus c-1t (failing cases) | law | verdict |
|---|---|---|---|---|---|
| V7 | `json.bend` `esc` | `\b` decodes to FF | 1 (`encstr_escapes_in`) | non-golden: All terms check; whole (GC): All terms check | **R22-4** |
| V8 | `json.bend` `esc.cls` | `\f` is invalid | 3 | non-golden: All terms check; whole (GC): All terms check | **R22-4** |
| V10 | `text.bend` `key_first` | `_` cannot start a bare key | 3 | whole (GC) and ALONE (481 s): All terms check | **R22-4** |
| V14 | `encode.bend` `row.lock` | a row shorter than the header passes lockstep | 2 | whole (GC) and ALONE (440 s, peak 5.3 GB): All terms check | **R22-4** |
| V25 | `encode.bend` `vk.arr` | an array that is a list item may be tabular | 1 (`enc_aoa_corners`) | whole (GC) and ALONE (434 s): All terms check | **R22-4** |
| V1 | `bad_char` | `:` does not force quotes | 9 | reduced: `golden_fx_enc_arrays_tabular_03` | killed by a law |
| V2 | `bad_char` | LF does not force quotes | 4 | reduced: All terms check; `golden_fx_enc_primitives_11` refuses | killed by a law |
| V3 | `bad_char` | tests `,` instead of the ACTIVE delimiter | 14 | reduced: All terms check; whole (GB): `golden_fx_enc_delimiters_20`, confirmed alone | killed by a law |
| V4 | `is_word` | `false` not a word | 3 | `encode_null_true_false_strings_quoted` | killed (R21-4's law holds) |
| V5, V6 | `esc.ch` | LF written `\r`; CR written `\n` | 8; 6 | `golden_fx_enc_primitives_11`; `cr_in_value_forces_quotes` | killed |
| V9 | JSON `esc` | `\t` decodes to VT | 18 | `tab_in_value_forces_quotes` | killed |
| V11 | `key_char` | `.` allowed in identifier segments | 2 | `golden_enc_folding_collision` | killed |
| V12 | `key_char` | `9` not a key character | 18 | `encode_repeated_key_twelve_members_repeat_of_an_early_key` | killed |
| V13 | `is_prim` | null not primitive | 6 | `golden_fx_enc_arrays_tabular_02` | killed |
| V15 | `is_row.of` | colon before delimiter is a row | 2 | `golden_toonedge_data_row_test` | killed |
| V16 | `len.mark` | a pipe header selects comma | 13 | `golden_toonerr_mixed_delims` | killed |
| V17 | `needs_quote` | a leading dash does not force quotes | 12 | `golden_fx_enc_primitives_16` | killed |
| V18 | `needs_quote` | the empty string is bare | 14 | `golden_encstr_root_empty_string` | killed |
| V19 | `put.header` | pipe marker omitted, comma written | 143 | `golden_flag_delimiter_equals_pipe` | killed |
| V20 | `cli.bend` `utf8.start.keep` | `--stats` encode keeps no text | 22 | `encode_stats_reads_the_text` | killed |
| V21 | `cli.bend` delimiter word | the two-character `\t` refused | 2 | `golden_flag_delimiter_backslash_t` | killed |
| V23, V24 | `row.lock` | in-order row with a nested value passes; values never tested | 25 each | `golden_enc_fold_list_item_dup_key` | killed |
| P00, P01, P10, P12, P20, P21, P22, P23, P30, P31, P43, P50, P51, P54, P55, P61 | `f64.bend` `like.ph` arms (0,0) (0,1) (1,0) (1,2) (2,0) (2,1) (2,2) (2,3) (3,0) (3,1) (4,3) (5,0) (5,1) (5,4) (5,5) (6,1) -> sink | | 1 to 12 each | `is_like_zero`, `is_like_fraction`, `is_like_leading_zeros`, `is_like_zero_fraction`, `is_like_signed_exponent`, `is_like_upper_exponent`, `encode_exponents_and_signed_integers_quoted`, `encode_numeric_like_items`, `golden_fx_enc_primitives_09` | all killed by laws |
| V22 | `F.twin.on` | every fast twin closed | not built | not run | behaviour-equivalent by design (fast == spec); not evidence |

Item 3 of the brief (dispatches no law pins): V16 (`len.mark` delimiter code), V19 (`put.marker`), V20 (`utf8.start.keep`), V21 (delimiter word), V3 (active delimiter in `bad_char`), V15 (`is_row.of`) and the `like.ph` arms are all pinned by a law; `row.lock`'s short-row arm (V14), `vk.arr`'s `tab_ok` (V25), the JSON escape arms `\b`/`\f` (V7, V8) and `key_first`'s `_` (V10) are pinned by the corpus only.

## Round 21's repairs (item 0)

| R21 finding | this round |
|---|---|
| R21-1 (tabular decision) | **holds.** New generator `lens_tab2.py` (1-60 rows; the perturbed row first, last, middle or random; reordering, a nested object/array/`{}`/`[]`/`[[]]`/`[{}]` under a header key, dropped, added and repeated keys, key spellings equal after `\u` unescaping, 7-12-key headers, folding, delimiters, indent 1, `--stats`): 60,000 native executions (seed 22902 t1; 22903 t1,8 × ±`TOON_SPEC=1`) and 3,000 on JS (22904), 0 differences; the generator's own sample is 158 tabular / 322 list outputs of 400. Round 21's `lens_tab.py` with new seeds 22801/22802 (45,000) and JS 22803 (1,200): 0. 28 hand inputs (repeats that serde resolves to primitives, nested values in first/middle/last row, `b` spellings, `[{},{}]`, `[{},{"a":1}]`, 10-key reversed rows) × native, `TOON_SPEC=1`, JS, pipe: 224 executions, 0. The mutants V14, V23, V24, V25 in the neighbouring arms: V23/V24 law-killed, V14/V25 corpus-only (R22-4) |
| R21-2 (counting rule gate) | `converge.sh` half **holds** (a `yes` with counted findings from round 20 is named: control in `gate4`). The audit half is **not repaired** (R22-2), and a new hole exists (R22-1) |
| R21-3 (reachability) | the four repaired shapes hold (the controls above print `1 FINDINGS`); the `-pre` suffix R21 named does **not**, and other shapes pass (R22-3) |
| R21-4 (laws for `]` `"` `\`, signed exponents, 0 mantissa, `\/`, the words) | **holds**: V4 is refused by `encode_null_true_false_strings_quoted`, all 16 new `like.ph` arm mutants are refused by laws; `hand-mutants.py` M45-M54 were not re-run by me |
| R21-5 (docstring count) | the docstring no longer states a count ("Count the set with `len(MUTANTS)`") |

## Clean areas: compared executions of the UNMUTATED port

| lens (script, seed) | target | executions | diffs |
|---|---|---|---|
| `lens_tab2.py` 22902 (20000, t1), 22903 (4000, t1,8 × ±spec) | item 0(a), new generator | 60,000 | 0 |
| `lens_tab.py` 22801 (15000, t1), 22802 (3000, t1,8 × ±spec) | item 0(a) | 45,000 | 0 |
| `lens_ws.py` `WSSEED=22101` | item 1: 25 White_Space + 19 near-misses (U+200B, U+FEFF, U+180E among them) × values, keys, items, tabular cells, one-char and whitespace-only strings × 5 delimiter settings × raw/escaped, + 10000 random | 82,920 | 0 |
| `lens_order.py` 22701 (15000, t1), 22702 (3000, t1,8 × ±spec); `lens_merge.py` 22201 (10000) | item 2 (sample: 225/300 and 185/300 outputs are `Duplicate sibling key`) | 65,000 | 0 |
| 20 hand TOON documents × `--decode` / `--no-strict` / `--expand-paths safe` / both / `--stats`, native and JS | item 2: outer before nested, nested before outer, merges whose later body conflicts, conflicts after a merge, dotted keys vs nested keys, tabular headers repeated | 400 | 0 |
| `lens_sw.py` 22001, `lens_utf8.py` 22301, `lens_like.py` 22501, `lens_jstr.py` 22601, `lens_scan.py` 22401 | item 0(d) and round 19-21 generators, new seeds | 90,000 | 0 |
| `diff-fuzz.py` mutate/docs/argv/expand/collide 223001 (3000 each, t1) and 223002 (2000 each, `--switch TOON_SPEC=1`, t8) | repository lenses | ≥ 50,000 (25,000 inputs) | 0 (`"verdict": "PASS"` each) |
| `diff-fuzz.py numbers` 223003 (`--runs 40000 --switch TOON_SPEC=1`), `scale` 223004 (t1), 223005 (`--switch`, t8) | `"number_literals": 40000`; `"too_slow": 0` | ≥ 640 | 0 |
| ad hoc native (`r22/q.py`, `t1.jl`-`t5.jl`) | tabular corners; key quoting (`_a`, `9a`, `a.b`, `é`, `""`, `true`); dash and numeric-like strings; 22 code points from U+0001 to U+10FFFF (noncharacters, U+FFFE/FFFF, U+FEFF, U+2028) raw and `\u`-escaped as values, keys, items, cells, `--stats`, and decoded back | 2,130 | 0 |
| `-o` and file operands (`r22/files22.py`) | 22 argv shapes: success lines, `--stats -o`, `-o -`, missing dir, `.JSON` with a space, invalid UTF-8 file, empty TOON, `-oFILE`, `--output=` | 44 (+ output file bytes compared) | 0 |
| **JS lane** (`PORT_JS=js/toon.js`): `lens_tab2` 22904 (1500), `lens_tab` 22803, `lens_order` 22703 (800), `lens_sw` 22002 (800), `lens_utf8` 22302, `lens_like` 22502, `lens_jstr` 22602, `lens_scan` 22402, `lens_merge` 22202 (600 each), `lens_ws` every 50th (`WSSEED=22102`), plus the hand inputs | | about 17,000 | 0 |
| **interpreter lane** (`r22/interp22.py`, `bun main.ts port/main.bend --`) | reordered rows with nested values, short rows, `\u` key spellings, edge whitespace and near-misses, tab cells with U+1680/VT, merge-order and lenient triples, expansion conflicts, quoting | 28 | 0 |

Total compared executions of the unmutated port against the original: about 345,000 native from my lenses and hand inputs, at least 50,600 from `diff-fuzz`, about 17,000 on JS, 28 on the interpreter. The mutant runs (40 corpus runs, `tri.py`) only classify mutants and are not counted here.


## What this round did NOT cover

- a proof of the UNMUTATED tree (each mutant proof that ended in `All terms check.` implies the unmutated laws check too, but I did not re-run PORT_STATE's proof row); `lanes.sh`, `port-doctor.sh`, `hand-mutants.py` M01-M54, `floor.sh`, `stdio-probe.py`; any performance
- the interpreter lane beyond the 14 inputs in `r22/interp22.py`; the JS lane on inputs above about 60 KB; c-8t only through the lenses marked t1,8 and `diff-fuzz` seed 223002/223005
- `-o` beyond the 22 argv shapes of `r22/files22.py`; read errors in mid-stream; inputs of 16 MiB or more
- single whole proofs of V7 and V8 (each survived the whole proof only as a member of group GC; at 16:14-16:40 the host had 3-9 GB available, my queue waited for 12 GB and I stopped it (never started, not killed mid-run); a masking interaction between them is unlikely, as they touch different defs and inputs, but not excluded)
- the law coverage of mutants I did not write; V22 (`F.twin.on` always closed) was built as a site but is behaviour-equivalent by design and was not run
- DOCUMENT review beyond R22-5 (under 15% of the effort)

## Artifacts

Everything is under `/data/tmp/review_R22/`: `bin/toon`, `js/toon.js`; `gate/` (R22-1's planted rows, diff in `r22/R22-1.diff`), `gate2/` (R22-2's edits, `r22/R22-2.diff`), `gate3/` (R22-3; every planted evidence file was restored from `r22/canada.6d48fcf.orig.json` and planted names moved to `r22/moved/`; `git status --short` is empty), `gate4/` (the control for R21-2's converge half). In `r22/`: `cmp.py`, `q.py`, `tri.py`, the lenses (`lens_tab2.py` is new; the others are round 21's with new seeds), `interp22.py`, `files22.py`, `mut22.py`, `mut22/<id>/` (port copy, `diff.txt`, `build.log`, `toon_mut`, `conform.json`, proof copies and logs), `mut22_all.log`, `proofs22.log`, `redq.py`, `subq.sh`, `subq2.sh`, the lens logs (`tab_*`, `tab2_*`, `order_*`, `merge_*`, `sw_*`, `utf8_*`, `like_*`, `jstr_*`, `scan_*`, `ws_*`, `js_*`, `df_*`).
