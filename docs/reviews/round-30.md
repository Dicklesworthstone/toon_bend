# Round 30: non-author hostile review of toon_bend

| field | value |
|---|---|
| reviewed commit | 2fabd59ddd038d5f62a5857ecfa275f3861c8c75 |
| clone | fresh `git clone https://github.com/Dicklesworthstone/toon_bend /data/tmp/review_R30/clone`; `git rev-parse HEAD` printed that hash (the expected `2fabd59`) |
| original | `oracle/toon` -> `/data/projects/toon_bend/oracle/toon`, sha256 `821287eaf1a6d320ee1ef7604e74e3cefaa42b69445c96abb9dd310782d04030`, equal to `docs/PIN.toml` |
| Bend | `bun /tmp/bend/bend2/main.ts`, `/tmp/bend` at `15ae0c86f3193b8f645b4bedbc438655b648d0da`, `BEND_NO_TELEMETRY=1` (never updated) |
| tools | bun 1.4.2, Ubuntu clang 21.1.8, Python 3.14.4, markdown-it-py 3.0.0 |
| port binaries | native `/data/tmp/review_R30/bin/toon` (21 s wall); JS `/data/tmp/review_R30/bin/toon.js`, run through `scripts/js-lane.py` |
| unmutated corpus | `./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t -- ../bin/toon --threads 1 --` gives `"passed":1124,"failed":0,"inconclusive":0,"stderr_compared":true,"verdict":"PASS","oracle_identity_checked":true` |
| repo gates on this tree | `claims-audit.py`: `"findings": 0 … "laws": 678, "cases": 1124 … "verdict": "OK"`; `law-coverage.sh`: `"laws": 678, "proofs": 678 … "unsafe": 0 … "verdict": "OK"`; `claims-lint.sh`: 0 hits in 12 files; `state-check.sh`: 0 findings; `build-cases.py --check`: OK; `converge.sh`: NOT_CONVERGED (clean tail 0) |
| host | shared, 8 cores, 30 GB. At 05:49 the load was 1.06, 23 GB available, 18 GB disk free; at 08:53 the load was 3.35, 23 GB available, 16 GB free. Every build and proof started with at least 12 GiB `MemAvailable` and ran ONE at a time: builds under `systemd-run --user --scope -p MemoryMax=8G -p MemorySwapMax=0`, proofs and `law-mutation.sh` under `MemoryMax=10G`. None was killed by the cap. Whole-proof peak 3.4 GB, 441-554 s. This round used 144 MB of disk |
| harness | `r30/h30.py` runs `./oracle/toon ARGV` and `bin/toon --threads T -- ARGV` (or `js-lane.py toon.js -- ARGV`) on the same stdin and compares stdout, stderr and the exit code byte for byte, with `TOON_SPEC` removed unless the lane sets it (`t8s` = 8 threads with `TOON_SPEC=1`) |

## Findings (counting rule of 2026-09-23, rules 1-6)

| id | sev | class | what | spec |
|---|---|---|---|---|
| R30-1 | MEDIUM | BEHAVIOR (a gate that lies; NEW, beside R29-1's repair) | `review_report.py` reads a report's PROSE ids only from inline tokens, by regex over NFKC-folded text. A finding placed in an HTML block (`<p>…</p>` or a `<table>`, which GitHub and every CommonMark renderer with HTML show), or a prose id containing an invisible Cf character (U+200B, U+00AD) or a Cyrillic `Р` for `R`, is shown to a reader and never seen by the gate. With two planted non-author rounds `0 \| 0 \| yes` whose reports carry a HIGH BEHAVIOR finding only in such a form, `converge.sh` prints CONVERGED. The plain-prose control is refused (NOT_CONVERGED) | PARITY-GATE rules 1, 6; `review_report.py` docstring ("every `R<n>-<k>` … named anywhere in the report has a row") |
| R30-2 | LOW | BEHAVIOR (a gate that lies, fail-closed; in R29-1's repair) | The candidate test for "a findings table" strips every non-letter from a header cell and then searches `sev` or `class`, so an HONEST second table whose header reads `base vs mutant`, `these values`, `false verdicts` or `release version` becomes a second findings table and the whole report is refused (`2 findings tables`). None of these headers mentions sev in any spelling a reader sees | `review_report.py` contract ("a header naming sev or class") |
| R30-3 | LOW | BEHAVIOR (a gate that lies; in R29-2's repair) | `claims-audit.py` takes a paste's scope from `hand-mutants.py((?: M\d+)+)`, which needs the ids to follow `.py` directly on the SAME line. Accepted with `"findings": 0 … "OK"`: `hand-mutants.py --all-laws M120 M121` reporting `"mutants": 124, "killed": 124`; the command on one line and its JSON on the next (a fenced paste) reporting 124 for two ids; and a whole-inventory command with no ids reporting a stale 110 because the prose before it says `M01 to M111`. The honest two-id pastes of the first two shapes are refused (`says 2, the repository has 124`) | (claims) |
| R30-4 | MEDIUM | BEHAVIOR (corpus gap; ONE finding against `scripts/hand-mutants.py`, whose inventory has none of these sites) | Three NEW hand mutants survive the whole corpus on c-1t (1124 of 1124 each) AND the whole 678-law `PROOF.bend` as a group (P1: `All terms check.`, 552 s). On every distinguishing input the unmutated port equals the original on native t1, t8 with `TOON_SPEC=1`, JS and the interpreter. X1 (`ucut.go`): a backslash inside quotes in a fields segment stops escaping, so `a[1]{"x\"}y"}:` + row `1` fails `Missing colon after key` instead of decoding key `x"}y`. X11 (`fields.dup.go`): a repeated field name is never detected, so `a[1]{x,x}:` + `1,2` prints `{"x": 1, "x": 2}` instead of `Duplicate sibling key "x"` (strict) or `{"x": 2}` (lenient). X12 (`hdr.c.colon.if`): the text after a fields header colon is not trimmed, so `a[1]{x}:` followed by two spaces fails `Unexpected content after fields-bearing header colon` | S2.132, S3.26, S2.139 (7) / S9.149 |
| R30-5 | LOW | LAW-COVERAGE (ONE finding against `scripts/hand-mutants.py`) | Two NEW mutants that the corpus kills on c-1t but NO law does. X2 `len.rev`: empty bracket content is a usable length 0 (1 case, `toonerr_empty_length`; P4 `All terms check.`, 554 s). X10 `nest.over`: the decoder's nesting limit moves from 127 to 128 (12 cases; P7 `All terms check.`, 549 s) | S2.135, S4.230 / S9.153 |
| R30-6 | LOW | DOCUMENT | `docs/PORT_STATE.md` (law-mutation sweep row) says "A SURVIVED in that set is a genuine law-weakness finding". Running `scripts/law-mutation.sh` on the json and encode modules gives three SURVIVED, and all three are equivalent mutants, not weak laws: `write` and `write_ln` true2false (the root call's `first` flag, which only a chain constructor reads, and the root is never a chain) and `fold` conjdrop (a non-object value walks to one segment, which `fold.check` refuses anyway). The two built ones (W1, W2) pass 1124 of 1124 cases | (claims) |

Count under the rule: **BEHAVIOR 4 (MEDIUM 2, LOW 2), LAW-COVERAGE 1 (LOW), DOCUMENT 1 (LOW).** NEW behavior findings of MEDIUM or above: **2** (R30-1, R30-4). This round is NOT clean. I found **no difference between the UNMUTATED port and the original** on any lane: about 37,400 native t1 executions (15,000 `diff-fuzz` inputs, about 400 more `diff-fuzz` numbers and scale inputs, and about 22,000 from my own generators), about 17,330 at 8 threads with `TOON_SPEC=1` (plus 84,800 number literals across both settings), about 3,070 on the JS lane and 12 on the interpreter.

Round 29's repairs, item 0: (a) the HEADER contract holds against everything I planted (the fixed header, Cf in cells, source-text sev/class cells), but the prose half of the same reader does not (R30-1), and the letters-only candidate test refuses honest reports (R30-2). (b) R29-2's repair holds for `hand-mutants.py M<a> M<b>` on one line, not for a flag, a line break or a range in the prose (R30-3). (c) The six new laws are in the tree (678/678) and the inventory holds M120-M125; new neighbouring-arm mutants give R30-4 and R30-5. (d) `law-mutation.sh` was run on text, json, decode and encode (below).

### R30-1 reproduction

Decoys (these are planted files, NOT findings of this report; their hidden ids are given only inside fenced blocks). Each report has the header table and an EMPTY findings table, then one of:

```
A  <p><b>R30-99</b> | HIGH | BEHAVIOR | the port prints the wrong bytes</p>          (HTML block)
B  <table><tr><td>R30-99</td><td>HIGH</td><td>BEHAVIOR</td>…</tr></table>          (HTML block)
C  Finding R30<U+200B>-99 (HIGH, BEHAVIOR): the port prints the wrong bytes.       (Cf in prose)
D  Finding <U+0420>30-99 (HIGH, BEHAVIOR): …                                      (Cyrillic Er)
E  Finding R30<U+00AD>-99 (HIGH, BEHAVIOR): …                                      (soft hyphen)
K  Finding R30-99 (HIGH, BEHAVIOR): …                                              (control)
```

The reader alone (`python3 scripts/review_report.py <file> 30`): A, B, C, D and E each give `"rows": [], "counted": 0, "errors": []` with rc=0; K is refused with rc=1 and the error printed in the block below.

```
$ python3 scripts/review_report.py K_control_prose_plain_99.md 30   (rc=1)
{"commit": "2fabd59ddd038d5f62a5857ecfa275f3861c8c75", "rows": [], "counted": 0, "errors": ["R30-99 is named in the report but has no row in its findings table"]}
```

The full gate (`/data/tmp/review_R30/decoys/plant_conv.py`): it appends rows 30 and 31 (`| 30 | non-author hostile review (subagent): decoy row | 0 | 0 | yes | 2026-09-26 |`) to the rounds table of the clone's `docs/PORT_STATE.md`, writes the two reports, runs the gates, moves the reports to `/data/tmp/review_R30/moved/` and restores `PORT_STATE.md` from a copy:

```
== htmlblock   (round 30 = A, round 31 = B)
$ ./scripts/converge.sh docs/PORT_STATE.md (rc=0)
{"tier": "T2", "rounds": 31, "clean": 7, "clean_tail": 2, "last_two_clean": true, "non_author_round": true, "open_oq": [], "open_disc": [], "unfixed": [], "verdict": "CONVERGED", "missing": []}
$ python3 scripts/claims-audit.py (rc=1) lines naming a review report: none
after restore: ?? oracle
== zwsp_cyr2   (round 30 = C, round 31 = D)
$ ./scripts/converge.sh docs/PORT_STATE.md (rc=0)
{… "verdict": "CONVERGED", "missing": []}
$ python3 scripts/claims-audit.py (rc=1) lines naming a review report: none
== control_plain   (both K)
$ ./scripts/converge.sh docs/PORT_STATE.md (rc=1)
{… "verdict": "NOT_CONVERGED", "missing": ["round 30: docs/reviews/round-30.md: R30-99 is named in the report but has no row in its findings table", "round 31: …", "clean rounds since last reset 0 < 2"]}
$ python3 scripts/claims-audit.py (rc=1) lines naming a review report: ['docs/PORT_STATE.md:0: round 30: … R30-99 is named in the report but has no row …', …]
```

`claims-audit.py` exits 1 in all three plants only because the prose summaries ("rounds 20 to 29", "rounds 6 to 29") are stale against a 31-row table, which a real round's author refreshes; it names no review report in the decoy plants and names both in the control. Cause: `parse()` builds `shown` from `inline` tokens only (so `html_block` content, which renders, is never read) and matches ids with `R%d[-.]0*(\d+)` over `fold()`, which keeps Cf characters and does not fold homoglyphs; the Cf refusal added for R29-1 covers table cells only. Fix direction: refuse any `html_block` token in a report, and refuse Cf and non-ASCII letters adjacent to an `R<n>` token anywhere in the text (or match ids on the raw bytes after deleting Cf).

### R30-2 reproduction

Each report is an empty or one-row findings table plus ONE more table (`/data/tmp/review_R30/decoys/{F,G,H,I}_*.md`):

```
F  | mutant | base vs mutant | law |          -> {"errors": ["2 findings tables (a header naming sev or class); a report has exactly one"]} rc=1
G  | lens | these values | diffs |            -> same, rc=1
H  | gate | false verdicts |                  -> same, rc=1
I  | tool | release version |                 -> same, rc=1
J  (no second table, control)                 -> {"errors": []} rc=0
```

Cause: `re.search(r"sev|class", re.sub(r"[^a-z]", "", c.lower()))` joins words (`base vs` -> `basevs`, `these values` -> `thesevalues`). Fix direction: test each word, or the whole cell, against the names, instead of a substring of the letters.

### R30-3 reproduction

Each line was inserted after `- law admission, round 29:` in the clone's `docs/PORT_STATE.md`, then `python3 scripts/claims-audit.py` ran and the file was restored (`git status --short` afterwards: `?? oracle`):

```
== P1 rc=0   - law admission, round 30: `python3 scripts/hand-mutants.py --all-laws M120 M121` → `{"laws_in_proof": 433, "reduced": true, "mutants": 124, "killed": 124, …}`
             {"files": 16, "absent": [], "findings": 0, … "verdict": "OK"}
== P2 rc=1   (same command, "mutants": 2, "killed": 2)
             HIT docs/PORT_STATE.md:52: mutants in a pasted line: says 2, the repository has 124
== P3 rc=0   - law admission, whole inventory (it covers M01 to M111 and every id added since), 2026-09-26: `python3 scripts/hand-mutants.py` → `{… "mutants": 110, "killed": 110 …}`
             {… "findings": 0, … "verdict": "OK"}
== P4 rc=1   (control) `hand-mutants.py M120 M121` → "mutants": 124   -> says 124 for the 2 ids its hand-mutants.py command lists
== P5 rc=1   (control) `hand-mutants.py` → "mutants": 110              -> says 110, the repository has 124
== P6 rc=0   a fenced paste: line 1 `$ python3 scripts/hand-mutants.py M120 M121`, line 2 `{… "mutants": 124, "killed": 124 …}`
             {… "findings": 0, … "verdict": "OK"}
== P7 rc=1   (the same fenced paste with "mutants": 2)  -> says 2, the repository has 124
```

`--all-laws` is a real flag of `hand-mutants.py` (its usage line: `[--all-laws] [M01 M05 ...]`). Fix direction: parse the command's arguments (any order, flags skipped), look back past a line break inside the same paste, and let a command with no ids mean the whole inventory whatever the prose says.

### R30-4 reproductions (original, unmutated port on three lanes, mutant binary `mut/<id>/toon`; `r30/dist30.py`)

```
== X1 ['-d'] b'a[1]{"x\\"}y"}:\n  1'
   orig   (b'{\n  "a": [\n    {\n      "x\\"}y": 1\n    }\n  ]\n}\n', b'', 0)
   port t1 SAME | t8 SAME | js SAME
   mutant (b'', b'Failed to decode TOON: Missing colon after key\n', 1)   <- DIFFERS
== X1 ['-d', '--no-strict'] b'rows[2]{"id","n\\"}"}:\n  1,2\n  3,4'
   orig   (b'{\n  "rows": [\n    {\n      "id": 1,\n      "n\\"}": 2\n    },\n    {\n      "id": 3,\n      "n\\"}": 4\n    }\n  ]\n}\n', b'', 0)
   port t1 SAME | t8 SAME | js SAME
   mutant (b'', b'Failed to decode TOON: Missing colon after key\n', 1)   <- DIFFERS
== X11 ['-d'] b'a[1]{x,x}:\n  1,2'
   orig   (b'', b'Failed to decode TOON: Duplicate sibling key "x"\n', 1)
   port t1 SAME | t8 SAME | js SAME
   mutant (b'{\n  "a": [\n    {\n      "x": 1,\n      "x": 2\n    }\n  ]\n}\n', b'', 0)   <- DIFFERS
== X11 ['-d', '--no-strict'] b'a[1]{x,y,x}:\n  1,2,3'
   orig   (b'{\n  "a": [\n    {\n      "x": 3,\n      "y": 2\n    }\n  ]\n}\n', b'', 0)
   port t1 SAME | t8 SAME | js SAME
   mutant (b'{\n  "a": [\n    {\n      "x": 1,\n      "y": 2,\n      "x": 3\n    }\n  ]\n}\n', b'', 0)   <- DIFFERS
== X12 ['-d'] b'a[1]{x}:  \n  1'
   orig   (b'{\n  "a": [\n    {\n      "x": 1\n    }\n  ]\n}\n', b'', 0)
   port t1 SAME | t8 SAME | js SAME
   mutant (b'', b'Failed to decode TOON: Unexpected content after fields-bearing header colon\n', 1)   <- DIFFERS
== X12 ['-d'] b'k:\n  a[2]{x,y}: \n    1,2\n    3,4'
   orig   (b'{\n  "k": {\n    "a": [\n ... "y": 4\n      }\n    ]\n  }\n}\n', b'', 0)
   port t1 SAME | t8 SAME | js SAME
   mutant (b'', b'Failed to decode TOON: Unexpected content after fields-bearing header colon\n', 1)   <- DIFFERS
```

(`dist30.py` prints 11 inputs; all 11 separate their mutant, and on all 11 the unmutated port equals the original on t1, t8 and JS.) The interpreter lane (`r30/interp30.py`, `scripts/interp-lane.sh bun /tmp/bend/bend2/main.ts port/main.bend --`) also equals the original on the first X1, X11 and X12 inputs.

Mutant texts (`r30/m30defs.py`; each an exact replacement of text that occurs once):

- X1 `ucut.go` (decode): the `1n` arm's `ucut.cls(rest, inq, True{}, k)` -> `ucut.cls(rest, inq, False{}, k)`
- X11 `fields.dup.go` (decode): `fields.dup.go(rest, T.kt.put(seen, name), T.kt.has(seen, name))` -> `… , False{})`
- X12 `hdr.c.colon.if` (decode): `hdr.d(quoted, keyraw, inside, True{}, seg, T.trim(rest))` -> `… seg, rest)`

Proof: `P1 ['X1', 'X11', 'X12'] PROOF rc=0 secs=552 ['Maximum resident set size (kbytes): 3366744'] stdout-first= ['All terms check.'] loc= [] restored=IDENTICAL`.

Why the corpus misses them: no input under `cases/inputs/` has a backslash anywhere in a fields segment (`rg -n '\]\{[^\n]*\\"' cases/inputs/` and the same with `\\\\` are empty; the only fields-backslash law, `decode_backslash_outside_quotes_in_fields`, pins the OUTSIDE-quotes arm), no case repeats a field name in a tabular header, and no case puts whitespace after a fields header's colon. Fix direction: capture the three inputs as cases, write closed laws on them (each is a few bytes through `C.run_pure`), and add the sites to the inventory.

### R30-5 reproductions

Corpus failures on c-1t (`/data/tmp/review_R30/mut/results30.jsonl`): X2 1 case (`toonerr_empty_length`); X10 12 cases (`jsonout_deep_200`, `toonerr_nesting_limit_at_tabular_body`, `toonerr_nesting_limit_at_empty_item`, `toonerr_nesting_limit_at_item_first_field`, `toonedge_nested_129_no_expand`, `toonerr_expand_nested_128`, `toonedge_expand_arrays_255`, `toonerr_expand_arrays_256`, `toonedge_expand_empty_leaf_128`, `toonerr_expand_empty_leaf_129`, `toonedge_expand_mixed_100_objects_55_arrays`, `toonerr_expand_mixed_100_objects_56_arrays`). Proofs, each mutant alone:

```
P4 ['X2'] PROOF rc=0 secs=554 ['Maximum resident set size (kbytes): 3351884'] stdout-first= ['All terms check.'] loc= [] restored=IDENTICAL
P7 ['X10'] PROOF rc=0 secs=549 ['Maximum resident set size (kbytes): 3457740'] stdout-first= ['All terms check.'] loc= [] restored=IDENTICAL
```

Mutant texts: X2 `len.rev`: `case SNil{}:\n      HL{False{}, 44, SNil{}}` -> `HL{True{}, 44, SNil{}}`. X10 `nest.over`: `…, extra), 127n)` -> `…, extra), 128n)`. (X10's law would need a 128-deep closed input; `expand_depth_127_accept` pins the expansion limit, not the decoder's.)

### R30-6 reproduction

`/data/tmp/review_R30/lm/json.out` and `encode.out` (commands below): `write` true2false SURVIVED 548.84 s, `write_ln` true2false SURVIVED 545.56 s, `fold` conjdrop SURVIVED 551.43 s. W1 (the `write_ln` mutant) and W2 (the `fold` mutant) built natively: `"passed": 1124, "failed": 0` each. Reasoning for equivalence: `w`'s `first` argument is read only in the `JCons` and `JECons` arms, and `write`/`write_ln` call `w` on the value itself, never on a chain; `walk` on a non-object returns the one-element list `[k]`, and `fold.check` refuses fewer than two segments.

## Mutant table (all 11 mutants of this round)

Each mutant is an exact-text replacement (`r30/m30defs.py`), applied to the one working copy `/data/tmp/review_R30/mport/port`, built natively (memory-gated) and restored; every record says `restored: IDENTICAL` and `diff -r clone/port mport/port` is empty at the end. Each binary ran the whole corpus on c-1t.

| mutant | def | change | corpus c-1t failing | law | verdict |
|---|---|---|---|---|---|
| X1 | `ucut.go` | backslash in quotes stops escaping | 0 | none (P1) | R30-4 |
| X11 | `fields.dup.go` | repeated field never detected | 0 | none (P1) | R30-4 |
| X12 | `hdr.c.colon.if` | text after fields colon untrimmed | 0 | none (P1) | R30-4 |
| X2 | `len.rev` | empty bracket is length 0 | 1 | none (P4) | R30-5 |
| X10 | `nest.over` | nesting limit 128 | 12 | none (P7) | R30-5 |
| X3 | `surplus.tab` | a `- ` line at row depth is a surplus row | 1 | `decode_list_line_after_full_table` (P3) | killed |
| X4 | `is_row.of` | colon without delimiter is a row | 2 | `decode_colon_line_ends_tabular_rows` (P2) | killed |
| B1 | `shr_bits` | top limb kept when it shifts to zero | 15 | `div_p10_37_1` (P6) | killed |
| B5 | `mul_small` | final carry dropped | 84 | `token_short_42` (P8) | killed |
| W1 | `write_ln` | root `first` flag False | 0 | none | equivalent (R30-6) |
| W2 | `fold` | `is_obj` conjunct dropped | 0 | none | equivalent (R30-6) |

Peeling: P2 (X2, X3, X4) stopped at `decode_colon_line_ends_tabular_rows` in 441 s; P3 (X2, X3) at `decode_list_line_after_full_table` in 465 s; P5 (X10, B1, B5) at `token_short_42` in 10 s; P6 (X10, B1) at `div_p10_37_1` in 22 s; P8 (B5 alone) at `token_short_42` in 10 s. X3 and X4 were not proved singly after their group failed, so "killed" means the group failed at that law.

## Item 0(d): `scripts/law-mutation.sh` on four modules

One invocation per module, one at a time, each under `systemd-run --user --scope -p MemoryMax=10G`, with `--ops true2false,false2true,and2or,or2and,conjdrop` (the verdict-flip and guard operators) and the defs a law names that carry such a site (`r30/sites.py` regenerates the set: text 7, json 6, decode 2, encode 2, cli 9, f64 12, bignat 2; the first six match the PORT_STATE counts):

```
./scripts/law-mutation.sh port utf8.init utf8.init.verdict is_ws head_is_ws ends_ws has_edge_ws has_char --file text.bend --ops …
  baseline: All terms check.
  mutants: valid=9 killed=9 survived=0 invalid=0 timeouts=0 errors=0 uncovered=0 nosite=26   verdict: STRONG
./scripts/law-mutation.sh port byte.cls num.safe plain w write write_ln --file json.bend --ops …
  mutants: valid=12 killed=10 survived=2 invalid=0 timeouts=0 errors=0 uncovered=0 nosite=18   verdict: WEAK   (write, write_ln true2false: equivalent, R30-6)
./scripts/law-mutation.sh port scan.check dr.ok --file decode.bend --ops …
  mutants: valid=5 killed=5 survived=0 invalid=0 timeouts=0 errors=0 uncovered=0 nosite=5   verdict: STRONG
./scripts/law-mutation.sh port fold pre.if --file encode.bend --ops …
  {"valid":2,"killed":1,"survived":1,"invalid":0,"timeouts":1,"errors":0,"uncovered":1,"nosite":7, … "verdict":"WEAK"}   (fold conjdrop: equivalent, R30-6; pre.if false2true TIMEOUT at 901.03 s)
```

29 mutants over 17 defs: 25 killed, 3 equivalent survivors, 1 TIMEOUT. The TIMEOUT (`pre.if`: the pre-pass given `spec = True` in its gate-open arm) is INCONCLUSIVE, not a result; a re-run at `--timeout 3000` was started and stopped by me before its baseline finished, to free the heavy slot, so it produced nothing. Under the port's own premise (fast twin text equals spec twin text) that mutant is also behavior-equivalent. The cli, f64 and bignat batches were not run.

## Clean areas: compared executions of the UNMUTATED port

| lens (script, seed) | target | executions (compared pairs) | diffs |
|---|---|---|---|
| `diff-fuzz.py` mutate/docs/argv/expand/collide 300001 (3000 each, t1) | repository lenses, new seed | 15,000 (`"differences": 0 … "PASS"` each) | 0 |
| `diff-fuzz.py` same five 300002 (2000 each, `--switch TOON_SPEC=1`, t8) | repository lenses | 10,000 | 0 |
| `diff-fuzz.py numbers` 300003 (switch, t1), 300007 and 300009 (switch, t8) and 300006, 300008, 300010 (no switch) | `"number_literals"`: 2000, 400, 40000 and 2000, 400, 40000 | 424 inputs, 84,800 literals | 0 |
| `diff-fuzz.py scale` 300004 (t1), 300005 (switch, t8) | `"too_slow": 0` | 40 | 0 |
| `diff-fuzz.py` mutate/docs/argv/expand/collide 300101 (300 each, JS lane, `--slow-floor 5`) | JS lane | 1,500 | 0 |
| `gen30.py hdr` 30001 (60), 30101 (3000), 30201 (1000, t8s), 30301 (200, JS), 30002 (5, t1 + JS) | item 1: 25 key forms, 28 bracket contents (signs, `#`, marks in every position, 2^32, 2^64), 20 fields segments, 9 colon forms, 15 inline forms, 5 contexts, `--no-strict`, `--expand-paths safe`, `--stats`, indents 4 and 0 | 4,270 | 0 |
| `gen30.py expand` 30001 / 30101 / 30201 / 30301 | item 1: dotted paths over numeric-looking, quoted and empty segments, collisions with earlier siblings, arrays and tabular leaves, lenient, `--stats` | 4,260 | 0 |
| `gen30.py statserr` 30101 / 30201 / 30301 | item 1: `--stats` on 40 malformed JSON and 23 malformed TOON inputs, missing files, directories, `-o` to a missing directory, bad option values | 4,200 | 0 |
| `gen30.py writer` 30001 / 30101 / 30201 / 30301 | item 2: C0 controls, DEL, U+0080-U+009F, U+2028/9, BOM, U+10FFFF and escapes through encode and decode, both writers; `\u` in TOON (the original also refuses it: `Invalid escape sequence: \u`) | 4,260 | 0 |
| `gen30.py numbers` 30001 (100) / 30101 / 30201 / 30301 | item 2: 46 printer boundaries (1e21, 1e-7, -0, 5e-324, 2.4703282292062327e-324, 1.7976931348623157e308 and its neighbours, 2^53 ± 1, 2^64, i64 limits) in both directions | 4,300 | 0 |
| `gen30.py deep` and `deep2.py` | item 2: nesting 118-135 in JSON and TOON, objects, list-of-lists, tabular and inline at the bottom, empty items, expansion (deep2: t1 + t8s 220, JS 110) | 4,590 | 0 |
| `gen30.py jsonerr` 30001 (200) / 30101 / 30201 / 30301 | item 4: generated JSON with one inserted, deleted or replaced byte (error messages and byte columns), multibyte text before the error | 4,400 | 0 |
| `otest.py` 30001 (t1), 30002 (JS) | `-o` to new, existing, missing-directory and input paths, `-o -`, with `--stats` | 190 | 0 |
| interpreter lane (`r30/interp30.py`) | 12 inputs: the X1, X11, X12, X2, X3 distinguishing inputs, `--stats` on a count error, a quoted dotted key under expansion, number boundaries both ways, `\u` in TOON | 12 | 0 |

## What this round did NOT cover

- `law-mutation.sh` on the cli, f64 and bignat modules, and a conclusive run of `pre.if` false2true (TIMEOUT above)
- Single proofs of X3 and X4 (each was killed only as a member of a group), and a whole proof of the UNMUTATED tree (P1, P4 and P7 ending in `All terms check.` imply the unmutated laws check)
- `lanes.sh`, `port-doctor.sh`, `floor.sh`, `stdio-probe.py`, `harness-selftest.sh`, `hand-mutants.py` for any id, and any performance measurement
- Encoder dispatches (quoting classes, key folding arms) with new hand mutants: all 11 of this round's mutants are in decode, bignat, json and encode's `fold`
- DOCUMENT review beyond the repository gates' own counts and R30-6

## Process notes (RULE 1)

- I deleted NO file. Planted reports were moved with `os.rename` into `/data/tmp/review_R30/moved/`. So was an empty scratch file of mine (`gen30.py.new`, created by a mistaken `cat >>`), which is there as `gen30.py.new.empty`. `PORT_STATE.md` in the clone was restored from a copy after every plant (`git status --short` shows only `?? oracle`). The mutant working copy was restored after every build and proof.
- I stopped one background job of mine (the `pre.if` re-run of `law-mutation.sh`) before its baseline proof finished; no proof process of mine was left running, and its temp copy is under `/data/tmp/review_R30/tmp/`.
- Nothing under `/data/projects/toon_bend` or `/dp/toon_rust` was modified. `/tmp/bend` was not updated.

## Artifacts

Everything is under `/data/tmp/review_R30/`: `bin/`, `clone/`, `mport/`, `mut/<id>/toon`, `mut/results30.jsonl`, `decoys/` (decoy reports, `plant_conv.py`, `mut_plant.py`), `moved/`, `lm/` (law-mutation logs), `df/` (diff-fuzz logs), `r30/` (`h30.py`, `gen30.py`, `deep2.py`, `otest.py`, `dist30.py`, `m30defs.py`, `mut30.py`, `proof30.py`, `interp30.py`, `sites.py`, `proof_*.out`, `gen.log`).
