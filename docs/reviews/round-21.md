# Round 21: non-author hostile review of toon_bend

| field | value |
|---|---|
| reviewed commit | `c5f3b46f786191be9c37cde778e1d72e9adb8e21` (fresh clone `/data/tmp/review_R21/clone`; `git rev-parse HEAD` printed that hash, the expected `c5f3b46`) |
| original | `oracle/toon` -> `/data/projects/toon_bend/oracle/toon`, sha256 `821287eaf1a6d320ee1ef7604e74e3cefaa42b69445c96abb9dd310782d04030`, the same as `docs/PIN.toml` |
| Bend | `bun /tmp/bend/bend2/main.ts`, `/tmp/bend` at `15ae0c86f3193b8f645b4bedbc438655b648d0da`, `BEND_NO_TELEMETRY=1` |
| tools | bun 1.4.2, Ubuntu clang 21.1.8, Python 3.14.4 |
| port binaries | native `bin/toon` (22.8 s wall, exit 0); JS `js/toon.js` (2.9 s, exit 0), run through `scripts/js-lane.py` |
| unmutated corpus | `./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t -- ../bin/toon --threads 1 --` -> `'passed': 1077, 'failed': 0, 'inconclusive': 0, 'stderr_compared': True, 'verdict': 'PASS', 'oracle_identity_checked': True` |
| repo gates on this tree | `claims-audit.py` -> `"findings": 0 … "laws": 604, "cases": 1077 … "verdict": "OK"`; `state-check.sh` -> `0 finding(s)`; `law-coverage.sh` -> `"laws": 604, "proofs": 604 … "verdict": "OK"`; `claims-lint.sh` (11 files) -> `0 hit(s)`; `build-cases.py --check` -> `{"cases": 1077, "verdict": "OK"}` |
| host | shared, 8 cores, 30 GB. 07:40 load 0.8, 24 GB available; 07:48 load 10.0; 08:23 load 3.0, 18 GB available; 10:45 load 2.5. Only one `bend -o` build or one `PROOF.bend` ran at a time (a single serial queue, `r21/queue.sh`); every proof ran under `proof_capped.sh` (killed above 10 GB, started only with at least 12 GB available). No proof was killed. No timing here is evidence of speed |
| harness | `r21/cmp.py` (round 20's, with the paths changed) runs `./oracle/toon ARGV` and `bin/toon --threads T -- ARGV` (or, with `PORT_JS`, `python3 scripts/js-lane.py js/toon.js -- ARGV`) on the same stdin and compares stdout, stderr and the exit code byte for byte. `TOON_SPEC` is removed unless a run sets it. "Executions" counts every run of either program. `r21/tri.py` runs the original, the unmutated port and one mutant on the same input |

## Findings (counting rule of 2026-09-23, rules 1-6)

| id | sev | class | what | spec |
|---|---|---|---|---|
| R21-1 | MEDIUM | BEHAVIOR (mutant, corpus gap) | `encode.bend` `has_prim.go`: when a header key is found, the mutant returns `True{}` in place of `prim`, so a nested value under a header key passes the tabular test. It survives the corpus (1077/1077) and the WHOLE 604-law proof (`All terms check.`, 414 s, peak 5.8 GB). It also survives `diff-fuzz.py docs`, `mutate` and `collide` (seed 212101, 2000 inputs each, 0 differences). It is reached by any array of objects whose later row has the header's keys in another order and holds an object or array under one of them. The mutant then writes a tabular array and prints the nested value as `null`, which loses data. `M17` (row order) is the only inventory mutant in this area, and no law or case has an out-of-order row with a non-primitive value | S4.36 (c)+(d), S4.37 |
| R21-2 | MEDIUM | BEHAVIOR (gate that lies) | Round 20's counting rule is not enforced by any gate. The rounds table can record a round with counted findings as clean, and both gates accept it. With row 20 edited to `2 \| 2 \| yes` (2 counted MEDIUM behavior findings, clean "yes") and `PORT_REPORT.md`'s pasted converge line refreshed to match, `claims-audit.py` prints `"findings": 0 … "verdict": "OK"` and `converge.sh` counts round 20 as clean (`"clean": 6, "clean_tail": 1`). `converge.sh` still marks a round clean at `n < 3` if the table says yes. The audit compares the table's count with the report but never checks the `clean?` cell. It also stops comparing when the report yields 0 countable rows, and its row filter is case-sensitive: with a report's class and severity written `behavior`/`medium`, the count check is skipped. Two such rounds in a row would make `converge.sh` print CONVERGED while the adopted rule says both are dirty | PARITY-GATE rules 1 and 6; PORT_STATE "Owner decisions" 2026-09-23 |
| R21-3 | LOW | BEHAVIOR (gate that lies) | `claims-audit.py`'s R20-2 repair (the reachability rule for commits in COUNTED evidence) misses several file shapes. With the scratch commit `494ef82` planted in `COUNTED.canada.decode.json`, the audit prints `OK` in each of these cases: the commit sits under `"tree"` instead of `"commit"`, or in a top-level `"commits"` list; `"kind"` is missing or spelled `"Counted"`; or the file's JSON does not parse (the loop does `continue` silently, while the e2e-corpus loop reports an unparsable file). Commits in file NAMES are also missed when the hash is upper case (`COUNTED.canada.decode.494EF82.json`; git accepts upper-case hex), not in the last dot field (`COUNTED.494ef82.canada.decode.json`), or followed by a suffix (`…494ef82-pre.json`, `…494ef82.v2.json`). Caught as they should be: an upper-case or lower-case unreachable hash under `"after".commit`, and `COUNTED.canada.decode.494ef82.json`. No committed file has any of the missed shapes, so no document states a false number today | (claims) |
| R21-4 | LOW | LAW-COVERAGE (one finding against `scripts/hand-mutants.py`: none of these sites is in its inventory) | Nine new hand mutants are killed by the corpus but survive the WHOLE 604-law proof (each ran alone, `All terms check.`). Q1: `bad_char` drops `"`. Q2: it drops `\`. Q3: it drops `]` (R20-3's law `encode_brackets_and_braces_force_quotes` pins `}`, `[` and `{` but not `]`). L60 and L13: `like.ph` arms (6,0) and (1,3), which are round 20's P6 and P7, "likely, unconfirmed" there and now confirmed; the round-20 repair pinned only (7,0), (1,1), (5,0) and (2,0). R6: `vk.tab` drops the empty-header test. R16: `has_prim.go` treats a missing key as present. R12: the JSON reader's `esc.cls` refuses `\/`. Q7: `is_word` drops `null` | S4.14, S4.9, S4.161, S4.34-S4.36, S2.18 |
| R21-5 | LOW | DOCUMENT | The docstring of `scripts/hand-mutants.py` still says "The set holds 34 mutants and the ids run M01..M12 and M14..M35", but the list holds 43 (M01..M44 without M13): `grep -c '^ ("M[0-9]*",' scripts/hand-mutants.py` -> `43` | (harness) |

Count under the rule: **BEHAVIOR 3 (MEDIUM 2, LOW 1), LAW-COVERAGE 1 (LOW), DOCUMENT 1 (LOW).** R21-1 and R21-2 are new MEDIUM behavior findings, so this round is NOT clean. I found no difference between the UNMUTATED port and the original on any lane (tables below).

### R21-1 reproduction (cwd `/data/tmp/review_R21/clone`)

```
$ cat ../r21/mut21/R5/diff.txt          # port/encode.bend
224c224
<       prim
---
>       True{}
$ I='[{"a":1,"b":2},{"b":{"x":1},"a":3}]'
$ printf '%s' "$I" | ./oracle/toon --encode                                  -> [2]:\n  - a: 1\n    b: 2\n  - b:\n      x: 1\n    a: 3     exit 0
$ printf '%s' "$I" | ../bin/toon --threads 1 -- --encode                     -> (identical to the original)                              exit 0
$ printf '%s' "$I" | ../r21/mut21/R5/toon_mut --threads 1 -- --encode        -> [2]{a,b}:\n  1,2\n  3,null                            exit 0
$ I='{"t":[{"a":1,"b":2},{"b":[1,2],"a":3}]}'
  original/port: t[2]:\n  - a: 1\n    b: 2\n  - b[2]: 1,2\n    a: 3        mutant: t[2]{a,b}:\n  1,2\n  3,null
$ cat ../r21/mut21/R5/conform.json
{"id": "R5", … "passed": 1077, "failed": 0, "inconclusive": 0, "failed_cases": [], "verdict": "PASS"}
$ grep R5 ../r21/proofs.log
{"id": "R5", "proof": "PROOF rc=0 killed=0 peak_kb=5833892 secs=414 last: All terms check."}
$ python3 scripts/diff-fuzz.py docs|mutate|collide --seed 212101 --runs 2000 -- ../r21/mut21/R5/toon_mut --threads 1 --   -> "differences": 0 each
$ PORT_BIN=../r21/mut21/R5/toon_mut python3 ../r21/lens_tab.py 21801 2000 1   -> {"executions": 4000, "diffs": 82}
```
Fix direction: add a captured case and a law for an out-of-order row that holds a nested value under a header key (for example the first input above, plus a `b:[1,2]` twin). Extend `hand-mutants.py` with this site (and R16, the missing-key arm of the same def).

### R21-2 reproduction (in a second local clone `/data/tmp/review_R21/gate`, `git clone clone gate`; every edit was restored from a copy, and `git status --short` shows only the `oracle` link afterwards)

```
$ python3 scripts/claims-audit.py | tail -1 ; ./scripts/converge.sh docs/PORT_STATE.md | tail -1
{"files": 16, … "findings": 0, … "verdict": "OK"}
{"tier": "T2", "rounds": 20, "clean": 5, "clean_tail": 0, "last_two_clean": false, … "verdict": "NOT_CONVERGED", …}
$ sed -i -E 's/^(\| 20 \| .*\| )2 \| 2 \| no \|/\12 | 2 | yes |/' docs/PORT_STATE.md            # 2 counted findings, clean "yes"
$ sed -i 's/"clean": 5, "clean_tail": 0,/"clean": 6, "clean_tail": 1,/' docs/PORT_REPORT.md       # refresh the pasted converge line
$ python3 scripts/claims-audit.py | tail -1
{"files": 16, "absent": [], "findings": 0, "historical_lines_exempt": 6, "laws": 604, "cases": 1077, "disc": {"accepted": 11, "resolved": 4, "open": 0}, "verdict": "OK"}
$ ./scripts/converge.sh docs/PORT_STATE.md | tail -1
{"tier": "T2", "rounds": 20, "clean": 6, "clean_tail": 1, "last_two_clean": false, … "missing": ["clean rounds since last reset 1 < 2"]}
```
Without the second edit, the audit's only complaint is the stale pasted converge line in `PORT_REPORT.md:32`, which is a document check and does not check the rule. The code: `scripts/converge.sh` has `clean = n is not None and n < 3 and … == 'yes'`. `scripts/claims-audit.py` has `if r >= 20: report_rows = [row … if re.search(r"\bBEHAVIOR\b", row) and re.search(r"\b(?:MEDIUM|HIGH)\b", row)]`, then `if rows and rows != f["round_findings"][r]`. So the check is skipped when no row matches, the match is case-sensitive, and a LOW row whose prose mentions "MEDIUM" is counted. Fix direction: for rounds ≥ 20, require `clean? = no` whenever the count is ≥ 1 (in `converge.sh`, or in the audit against the table), compare counts even when the report yields 0, and read severity and class from their own columns.

### R21-3 reproduction (gate clone; each edit restored from `r21/canada.decode.orig.json`; the planted files were moved to `r21/moved_out_*`, not deleted)

```
== A: after.commit upper-case 494EF82  -> perf/evidence/COUNTED.canada.decode.json:0: the after binary's commit 494EF82 is not reachable … "findings": 1 … "FINDINGS"
== A2: after.commit 494ef82            -> … "findings": 1 … "FINDINGS"
== B: "tree": "494ef82" instead of "commit"          -> "findings": 0 … "verdict": "OK"
== C: "kind" removed + unreachable commit            -> "findings": 0 … "verdict": "OK"
== C2: "kind": "Counted" + unreachable commit        -> "findings": 0 … "verdict": "OK"
== D: file made unparsable + unreachable commit      -> "findings": 0 … "verdict": "OK"
== B2: top-level "commits": ["494ef82"]              -> "findings": 0 … "verdict": "OK"
== COUNTED.canada.decode.494ef82.json   -> the file name's binary's commit 494ef82 is not reachable … "findings": 1
== COUNTED.canada.decode.494EF82.json   -> "findings": 0 … OK
== COUNTED.494ef82.canada.decode.json   -> "findings": 0 … OK
== COUNTED.canada.decode.494ef82-pre.json -> "findings": 0 … OK
== COUNTED.canada.decode.494ef82.v2.json  -> "findings": 0 … OK
$ git cat-file -t 9C9039E     -> commit      (git accepts upper-case hex)
```

### R21-4 reproductions (mutant against the original; `r21/tri.py`)

```
Q3  ["a]b","]"]   orig: [2]: "a]b","]"       mut: [2]: a]b,]
Q1  ["a\"b"]      orig: [1]: "a\"b"          mut: [1]: a"b
Q2  ["a\\b"]      orig: [1]: "a\\b"          mut: [1]: a\b
L60 ["1e+0","1e-05"]  orig: [2]: "1e+0","1e-05"   mut: [2]: 1e+0,1e-05
L13 ["0e5"]       orig: [1]: "0e5"           mut: [1]: 0e5
R6  [{},{}]       orig: [2]:\n  -\n  -       mut: [2]:\n  \n  \n
R16 [{"a":1,"b":2},{"c":3,"a":4}]  orig: list form   mut: [2]{a,b}:\n  1,2\n  4,null
R12 ["a\/b"]      orig: [1]: a/b             mut: Failed to parse JSON: invalid escape at line 1 column 5 (exit 1)
Q7  ["null"]      orig: [1]: "null"          mut: [1]: null
```
Whole proofs (`r21/proofs.log`): `Q3 … secs=449 last: All terms check.`, `Q1 … secs=572 …`, `Q2 … secs=563 …`, `L60 … secs=467 …`, `L13 … secs=558 …`, `R12 … secs=506 …`, `R6 … secs=517 …`, `R16 … secs=459 …`, `Q7 … secs=412 …`, each `rc=0 killed=0 … All terms check.`

## Mutant table (all mutants of this round)

Each mutant is one or more exact-text replacements in a copy of `port/` (`r21/mut21.py`; `r21/mut21/<id>/diff.txt`), built natively and run through the whole corpus on c-1t. For each corpus survivor I first checked on inputs whether it is equivalent. A non-equivalent survivor got a whole proof (or the one law that pins its input). Corpus-killed mutants in the areas no law obviously covers got whole proofs one at a time. Grouped proofs (G1-G7) only showed that the group was refused (the checker stops at the first refused law), so each member then ran on its own.

| id | def | change | corpus c-1t | proof | verdict |
|---|---|---|---|---|---|
| R5 | `encode.bend` `has_prim.go` | hit arm returns True | PASS 1077 | full: All terms check. | **R21-1** |
| S4 | `decode.bend` `ucut.cls` | a backslash outside quotes escapes too | PASS 1077 | refused by `decode_backslash_outside_quotes_in_fields` | killed by a law (corpus gap only; not a finding) |
| S3 | `decode.bend` `split.cls` | backslash not an escape in a quoted cell | PASS 1077 | full: refused by `decode_inline_escaped_quote_before_delimiter` | killed by a law |
| L41 | `f64.bend` `like.ph` (4,1) | -> 8 (`"3.14"` written bare) | PASS 1077 | reduced (24 `is_like*`): refused by `is_like_inner_zero_fraction` | killed by a law. The corpus has no string like `"3.14"` (a second nonzero fraction digit) |
| S1, S2 | `ascii_ws.cls` | FF / CR not ASCII whitespace | PASS 1077 | not run | equivalent on every input I tried (`\fa: 1`, `a[2]:\f1,2`, `a:\f1`, `\ra: 1`, header fields); not counted |
| Q24 | `like.first` | leading `-` goes to the sink | PASS 1077 | not run | equivalent: `starts_dash` quotes every such string (`is_like` has no other caller) |
| R14 | `shortest_fast` | int fast path bound 99948 -> 99947 | PASS 1077 | not run | equivalent: tb = 99947 means a value in [0.5, 1), which is never an integer, so `int.fit` refuses it anyway |
| Q1, Q2, Q3 | `bad_char` | `"`, `\`, `]` do not force quotes | KILLED (1071, 1075, 1076) | full: All terms check. each | **R21-4** |
| L60, L13 | `like.ph` (6,0), (1,3) | -> 8 | KILLED (1076 each) | full: All terms check. each | **R21-4** |
| R6, R16 | `vk.tab`, `has_prim.go` | empty header tabular; missing key present | KILLED (1076, 1073) | full: All terms check. each | **R21-4** |
| R12 | JSON `esc.cls` | `\/` invalid | KILLED 1076 | full: All terms check. | **R21-4** |
| Q7 | `is_word` | `null` not a word | KILLED 1075 | full: All terms check. | **R21-4** |
| Q4, Q11 | `bad_char` TAB; encoder `esc.cls` TAB | | KILLED | refused by `tab_in_value_forces_quotes` | killed |
| Q13, Q14 | encoder `esc.cls` `\`, `"` | | KILLED | `golden_fx_enc_primitives_14`, `encode_plain_string_bytes` | killed |
| Q19, Q20, Q21, Q22, Q23 | `is_ws` U+3000, U+0085, +U+200B, U+1680, U+202F | | KILLED | `is_ws_all_25_members`, `is_ws_documented_non_members`, `is_ws_ogham_space_mark` | killed |
| Q16 | `has_edge_ws` | trailing whitespace ignored | KILLED 1073 | full: refused (after 505 s) | killed |
| Q10 | `is_word` | `true` not a word | KILLED | `golden_encstr_root_string_quoted` | killed |
| L71 | `like.ph` (7,1) | -> 8 | KILLED | `encode_exponents_and_signed_integers_quoted` (group G3) | killed |
| R3, R4 | `row.lock` extra field; `row_ok.of` count | | KILLED 1074 each | `golden_fx_enc_arrays_objects_01` | killed |
| R8 | JSON `plain` | 0x1F joins a string | KILLED 1076 | `plain_31_refused` | killed |
| R11 | JSON `byte.cls` | TAB not whitespace | KILLED 1074 | `golden_jsonerr_whitespace` (group G5) | killed |
| Q5, Q6, Q8, Q9, Q12, Q15, Q17, Q18, Q25, R1, R7, R9, R10, R13, R15, S5, S6, L00, L01, L10, L12, L21, L22, L23, L30, L31, L43, L54, L55, L51, L61, L50, L20 | quoting, escapes, `is_ws`/edge, `lex.ok`, row order, header marker, JSON reader classes, folding lean gate, CR segments, TOON unescape, the remaining `like.ph` arms | | KILLED on c-1t (1 to 142 failing cases; `r21/mut_table.txt`) | not run | law coverage unknown; not claimed |
| Q26, Q27, Q28 | `like.go` | | INVALID (my mutants used a `Nat.eq` that does not exist) | — | not evidence |

## Round 20's repairs (item 0)

| R20 finding | this round |
|---|---|
| R20-1 (the 9th member builds the set) | **holds.** `lens_sw` (new generator: 8-24 members, repeats of the 9th-20th and later members, key spellings equal after unescaping including `\u` spellings of `k`, `.`, `/`, `é`, non-BMP pairs, several switching objects per document, list items, tabular rows, nested, folding, delimiters, auto mode): 0 differences in 63,600 native executions (t1, t8, ± `TOON_SPEC=1`) and 3,000 on JS. `lens_dupx` (round 20's exhaustive set) on t1,8 × ±`TOON_SPEC=1`: 42,810, 0 differences. Ad-hoc: every member k8..k19 of a 20-member object repeated at the end, a non-BMP key repeated with three spellings at the switch, tabular rows with a repeat at the switch, native and JS: 72 executions, 0 differences. Interpreter lane: 15-member object with repeats at and after the switch, tabular rows with the switch: 0 differences |
| R20-2 (reachability rule) | **holds for the shape it tests** (the before/after `commit` fields, both cases, and a hash in the last dot field of a file name), **does not hold** for the other shapes (R21-3) |
| R20-3 (laws for `}` `[` `{`, edge whitespace, `like.ph` (7,0), (1,1)) | the named laws kill their mutants (Q16 refused, L71 refused). The repair is **incomplete**: `]`, `"` and `\` in `bad_char` and the arms (6,0) and (1,3) that round 20 listed are still pinned only by the corpus (R21-4) |
| R20-4 (the 9th, not the 8th) | `obj.shorter`'s comment and `obj.member.small`'s comment now say "at most" and "9th". Not re-probed |
| round 20's new counting in the audit | makes it possible to lie (R21-2) |

## Clean areas: compared executions of the UNMUTATED port

| lens (script, seed) | target | inputs | executions | diffs |
|---|---|---|---|---|
| `lens_sw.py` 21001 (300, t1), 21002 (20000, t1), 21003 (4000, t1,8 × ±`TOON_SPEC=1`) | item 0(a), above | 24300 | 60600 | 0 |
| `lens_dupx.py` (t1,8 × ±`TOON_SPEC=1`) | round 20's exhaustive EXP-029 set | 8562 | 42810 | 0 |
| `lens_ws.py` (`WSSEED=21101`) | item 1: 25 White_Space + 19 near-misses (incl. U+200B, U+FEFF, U+180E) × 11 shapes (values, keys, array items, tabular cells, one-character and whitespace-only strings) × 6 positions × 5 delimiter settings × raw/escaped, + 10000 random | 41460 | 82920 | 0 |
| `lens_merge.py` 21201 (15000, t1), 21202 (3000, t1,8 × ±spec) | item 2 (round 19's generator; sample 289/600 `Duplicate sibling key`) | 18000 | 45000 | 0 |
| `lens_order.py` 21701 (20000, t1), 21703 (4000, t1,8 × ±spec) | item 2, new: 2-4 planted conflicts per document at depths 0-3 in chosen orders (outer before nested, nested before outer, siblings), merges whose second body holds its own conflict, list-item objects, dotted keys, `--expand-paths safe`, `--no-strict`, `--stats` (sample 204/300 `Duplicate sibling key`) | 24000 | 60000 | 0 |
| `lens_tab.py` 21801 (20000, t1), 21802 (4000, t1,8 × ±spec) | new: S4.34-S4.37 rows permuted / extended / shortened / with repeats / with nested values, 8-11-member rows, delimiters, folding, indent 3, `--stats` | 24000 | 60000 | 0 |
| `lens_utf8.py` 21301 (8000, t1), 21302 (3000, t1,8 × ±spec, file operands) | item 0(e): EXP-031's gate, invalid UTF-8 around JSON and TOON errors, BOMs, `--stats` | 11000 | 31000 | 0 |
| `lens_scan.py` 21401, `lens_like.py` 21501, `lens_jstr.py` 21601 (10000 each, t1) | round 19's generators, new seeds | 30000 | 60000 | 0 |
| `diff-fuzz.py` mutate/docs/argv/expand/collide 212001 (3000 each, t1) | repository lenses | 15000 | ≥ 30000 | 0 (`"verdict": "PASS"` each) |
| `diff-fuzz.py` mutate/docs/argv/expand/collide 212002 (2000 each, `--switch TOON_SPEC=1`, t8) | | 10000 | ≥ 20000 | 0 |
| `diff-fuzz.py numbers` 212003 (`--runs 40000`, `--switch TOON_SPEC=1`) | `"inputs": 200, … "number_literals": 40000` | 200 | ≥ 600 | 0 |
| `diff-fuzz.py scale` 212004 (t1), 212005 (`--switch`, t8) | `"too_slow": 0` both | 40 | ≥ 100 | 0 |
| ad hoc (native + JS) | nesting 126-129, 200, 3000 (JSON arrays, objects, folded, TOON objects, dotted expansion, nested list arrays); 22 JSON `\u` escape forms (lone and paired surrogates, `\uD800\uDBFF`, `\u0000`, `\u2028`, `\ufeff`, truncated) as values, keys and with `--stats`; the switch set above | 90 | 276 | 0 |
| **JS lane** (`PORT_JS=js/toon.js`): `lens_sw` 21004 (1500), `lens_order` 21702 (800), `lens_ws` every 50th (`WSSEED=21102`), `lens_utf8` 21303 (800, files), `lens_merge` 21203, `lens_like` 21502, `lens_jstr` 21602, `lens_scan` 21402 (600 each), `lens_tab` 21803 (800) | | 7630 | 15260 | 0 |
| **interpreter lane** (`r21/interp21.py`, `bun main.ts port/main.bend --`) | round 20's 14 plus 8: repeats at and after the switch, tabular rows at the switch, Unicode edge whitespace and near-misses, tab-delimited cells with U+00A0/U+2009, merge-order and lenient triples, expansion collision, numeric-like forms | 22 | 44 | 0 |

Total compared executions of the unmutated port against the original: about 452,000 native from my lenses plus at least 50,700 from `diff-fuzz`, 15,260 on the JS lane, and 44 on the interpreter lane. The mutant-against-original runs (69 corpus runs, `diff-fuzz`/`lens_tab` on R5) only classify mutants and are not counted here.

## What this round did NOT cover

- the law coverage of the 33 corpus-killed mutants listed in the "not run" row. Without a proof for each, I do not claim them either way
- the three INVALID mutants (Q26-Q28): my own spelling error, not evidence
- a proof of the unmutated tree (every surviving mutant's `All terms check.` implies the base proof checks, but I did not re-run PORT_STATE's proof row); `lanes.sh`, `port-doctor.sh`, `hand-mutants.py`, `floor.sh`; performance of any kind
- the JS lane on inputs above about 60 KB; the c-8t lane only through the lenses marked t1,8 and `diff-fuzz` 212002/212005
- `-o FILE` paths, read errors in the middle of a stream, inputs of 16 MiB or more
- DOCUMENT review beyond R21-5 and the gates in the header (under 15% of the effort)

## Artifacts

Everything is under `/data/tmp/review_R21/`: `bin/toon`, `js/toon.js`, `build-native.log`, `build-js.log`; `gate/` (the second clone for R21-2/R21-3; its tracked files match `clone` again). In `r21/`: `cmp.py`, `tri.py`, `lens_sw.py`, `lens_order.py`, `lens_tab.py`, round 20's lenses (paths changed), `interp21.py`, `mut21.py`, `mut21/<id>/` (port copy, `diff.txt`, `build.log`, `toon_mut`, `conform.json`, and for proved ones `proof.log(.summary)`), `mut21_all.log`, `mut_table.txt`, `proofs.log`, `queue.sh`/`queue.txt`/`queue.done`/`queue.out`, `fullproof.sh`, `redproof.sh`, `proof_capped.sh`, `proof_subset.py`, the lens logs (`sw_*`, `ws_*`, `merge_*`, `utf8_*`, `scan_*`, `like_*`, `jstr_*`, `js_*`, `df_*`), `df_chain.py`, `js_chain.sh`, and the backups used to restore the gate clone (`canada.decode.orig.json`, `PORT_STATE.orig.md`, `PORT_REPORT.orig.md`, `round-20.orig.md`, `moved_out_*`).
