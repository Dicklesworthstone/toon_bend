# Round 26: non-author hostile review of toon_bend

| field | value |
|---|---|
| reviewed commit | daa102b80e5bb384d419d617215542da2e135785 |
| clone | fresh `git clone https://github.com/Dicklesworthstone/toon_bend /data/tmp/review_R26/clone`; `git rev-parse HEAD` printed that hash (the expected `daa102b`) |
| original | `oracle/toon` -> `/data/projects/toon_bend/oracle/toon`, sha256 `821287eaf1a6d320ee1ef7604e74e3cefaa42b69445c96abb9dd310782d04030`, equal to `docs/PIN.toml` |
| Bend | `bun /tmp/bend/bend2/main.ts`, `/tmp/bend` at `15ae0c86f3193b8f645b4bedbc438655b648d0da`, `BEND_NO_TELEMETRY=1` (never updated) |
| tools | bun 1.4.2, Ubuntu clang 21.1.8, Python 3.14.4, markdown-it-py 3.0.0 |
| port binaries | native `/data/tmp/review_R26/bin/toon` (25.5 s wall, exit 0, sha256 `825e44de69c3a4e6c0d442ea99c86be8c3b194f8e58a090137fc0c4d2743ac9e`, the binary PORT_STATE names); JS `/data/tmp/review_R26/js/toon.js` (2.4 s), run through `scripts/js-lane.py` |
| unmutated corpus | `./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t -- ../bin/toon --threads 1 --` -> `{"lane":"c-1t","passed":1093,"failed":0,"inconclusive":0,"stderr_compared":true,"verdict":"PASS","oracle_identity_checked":true}` |
| repo gates on this tree | `claims-audit.py` -> `"findings": 0 … "laws": 648, "cases": 1093 … "verdict": "OK"`; `law-coverage.sh` -> `"laws": 648, "proofs": 648 … "verdict": "OK"`; `spec-lint.py` -> `716 clauses, 1093 cases, 1093 cases cited, 0 finding(s)`; `build-cases.py --check` OK; `cases-lint.sh` OK; `port-lint.py` OK (53 PL-02 infos) |
| host | shared, 8 cores, 30 GB. 13:20 load 1.9, 23 GB available, 21 GB disk free (18 GB at the end; other sessions write too). This round used 165 MB. Every Bend build and proof started at >= 12 GiB `MemAvailable`, one at a time, inside `systemd-run --user --scope -p MemoryMax=10G -p MemorySwapMax=0`. None was killed. Proof peaks (`/usr/bin/time -v`): 3.1-3.4 GB, 502-507 s |
| harness | `r26/cmp.py` (round 25's, paths changed) runs `./oracle/toon ARGV` and `bin/toon --threads T -- ARGV` (or the JS lane) on the same stdin and compares stdout, stderr and exit byte for byte, with `TOON_SPEC` removed unless set. `r26/tri3.sh` adds a mutant binary. "Executions" counts every run of either program |

## Findings (counting rule of 2026-09-23, rules 1-6)

| id | sev | class | what | spec |
|---|---|---|---|---|
| R26-1 | MEDIUM | BEHAVIOR (gate that lies; NEW, in R25-1's repair) | `scripts/review_report.py` applies `fold()` (NFKC plus the dash map) to the WHOLE report BEFORE markdown-it parses it, so it parses a different document from the one that renders. NFKC maps fullwidth characters to Markdown syntax: `｀｀｀` (U+FF40 x3) becomes a code fence and `｜ … ｜ / ｜－－－｜` becomes a table. A report whose ONE rendered findings table (markdown-it on the raw text) lists `R26-1 \| HIGH \| BEHAVIOR`, preceded by a paragraph written with fullwidth pipes (renders as text) and a line of fullwidth grave accents (renders as text), is read by the gate as `R26-1 LOW DOCUMENT`, counted 0, no error: the text becomes the findings table and the fence swallows the real one. With two planted rounds 26 and 27 (`0 \| 0 \| yes`, non-author) `converge.sh` prints `CONVERGED`, `claims-audit.py` `"findings": 0 … "OK"`, `state-check.sh` `0 finding(s)`. The same fold refuses an honest report: one that quotes a line of fullwidth grave accents (a Unicode test input) before its only findings table gets `0 findings tables` | PARITY-GATE rules 1, 6; `review_report.py` docstring ("read as a renderer reads it") |
| R26-2 | LOW | BEHAVIOR (gate that lies; NEW, in R25-2's repair) | Reachability now reads a JSON evidence file as `json.loads` decodes it, and `json.loads` keeps only the LAST of duplicate keys. With `"commit": "494ef82", "commit": "706f00e"` in `after`, or with a whole extra `"after": {"commit": "494ef82"}` before the real `after`, the raw file plainly names the unreachable `494ef82`, and `claims-audit.py` prints `"findings": 0 … "OK"`. The control (the same two keys in the other order) gives `"findings": 1`. The raw-text reading before R25-2's repair would have seen it | (claims) |
| R26-3 | MEDIUM | BEHAVIOR (corpus gap; ONE finding against `scripts/hand-mutants.py`: no site is in its inventory) | Ten NEW hand mutants survive the whole corpus on c-1t (1093 of 1093 each) AND the whole 648-law `PROOF.bend` as one group (P2: `All terms check.`, 507 s). The unmutated port equals the original on every distinguishing input (native, JS, interpreter). Decoder: N6 `fits` FTab and N7 `fits` FList consume a DEEPER row or item. `[2]{a,b}:⏎␠␠1,2⏎␠␠␠␠3,4` and `[2]:⏎␠␠- 1⏎␠␠␠␠- 2` then decode with exit 0 to two elements; the original says `Expected 2 … but got 1` (and keeps one element under `--no-strict`). N1 `surplus.tab` counts a deeper row as surplus. N4 `close.msg` runs the surplus check before the blank-line check. N10 `array` counts a tabular body as one container. N11 `item.route` does not count an empty item object toward the limit of 127. CLI: C1 and C2 `num.go` accept `-.5` and `-1.2.3` as negative numbers. JSON reader: J1 and J2 move the exponent-overflow position (`[1e21474836480]`, `[1e21474836400]`) | S4.207, S4.212, S4.213 (3), S4.215, S4.230, S1.156, S2.14 (a) |
| R26-4 | LOW | LAW-COVERAGE (ONE finding against `scripts/hand-mutants.py`) | Five NEW mutants that the corpus kills on c-1t but NO law does. All five together in group P3: `All terms check.`, 502 s; the law pre-screen names none. N8 `eat.kv.nest`: strict depth jump by one extra level (`jsonout_indent_1`, `jsonout_expand_indent_1`, `toonerr_depth_jump`). N14 `eat.row`: a narrower row passes strict (`toonerr_row_width_short`, `fx_dec_validation_errors_03`, `_09`). J3: exponent overflow on a zero mantissa is out of range (`encnum_zero_huge_exponent`, `encnum_exponent_forms`). J4: `e+` read as a negative exponent (`encnum_exponents`, `encnum_text_changes`, `encnum_exponent_forms`). E3 `fctx.child`: the fold prefix reset to the raw key (`enc_fold_dotted_parent_path` only) | S4.206, S4.212, S2.14 (a), S2.8-S2.12, S4.78 |
| R26-5 | LOW | DOCUMENT | `README.md` line 58 says the 648 laws are "41 [that] hold for every input … 571 are closed instances … 295 of them captured goldens", and 41 + 571 = 612. Counting the laws in `port/LAWS.bend` (a law is quantified when it has a `for` line) gives 648 = 41 quantified + 607 closed, 295 of them `golden_*`. The 571 is left over from round 21's count (commit `1df86ac`: "612 laws = 41 + 276 + 295"). `claims-audit.py`, which checks "laws by kind", prints `"findings": 0` on this tree | (claims) |

Count under the rule: **BEHAVIOR 3 (MEDIUM 2, LOW 1), LAW-COVERAGE 1 (LOW), DOCUMENT 1 (LOW).** NEW behavior findings of MEDIUM or above: **2** (R26-1, R26-3). This round is NOT clean. I found **no difference between the UNMUTATED port and the original** on any lane I tried: about 78,500 native executions from my own generators, 30,240 `diff-fuzz` inputs with new seeds plus 40,000 number literals, about 17,500 JS-lane executions from my generators plus 1,200 `diff-fuzz` inputs on JS, and 30 interpreter executions (table below).

### R26-1 reproduction

The reader alone. `python3 /data/tmp/review_R26/r26/render26.py 26 reports/*.md` prints the reader's verdict next to the tables that markdown-it renders from the RAW text (commonmark + table + strikethrough, the reader's own configuration):

```
== control.md review_report rc=0 {... "rows": [{"id": "R26-1", "sev": "HIGH", "class": "BEHAVIOR"}], "counted": 1, "errors": []}
== f1_fold_fence.md review_report rc=0 {... "rows": [{"id": "R26-1", "sev": "LOW", "class": "DOCUMENT"}], "counted": 0, "errors": []}
   RENDERED (raw text) tables: [[['id', 'sev', 'class', 'what', 'spec'], ['R26-1', 'HIGH', 'BEHAVIOR', 'the port prints X where the original prints Y', 'S4.1']]]
== f2_honest_fw.md review_report rc=1 {... "rows": [], "counted": 0, "errors": ["0 findings tables (header cells `id`, `sev`, `class`); a report has exactly one"]}
   RENDERED (raw text) tables: [[['id', 'sev', 'class', 'what', 'spec'], ['R26-1', 'HIGH', 'BEHAVIOR', 'the port prints X where the original prints Y', 'S4.1']]]
```

The body of `f1_fold_fence.md` below the header table, written here with escapes (Python string literal): `"## Findings\n\n" + DECOY + "\n\uff40\uff40\uff40\n\n" + REAL + "\n\uff40\uff40\uff40\n"`. REAL is an ordinary findings table with the row `| R26-1 | HIGH | BEHAVIOR | … |`. DECOY is the same table with the row `| R26-1 | LOW | DOCUMENT | wording | - |`, every `|` replaced by U+FF5C and every `-` by U+FF0D.

This report itself first quoted that body literally inside a code block. The repository's reader REFUSED it: `python3 scripts/review_report.py ../round-26.md 26` -> `"errors": ["2 findings tables (header cells `+"`id`, `sev`, `class`"+`); a report has exactly one"]`. The quoted U+FF40 line, folded into a fence, closed my code block early, and the table quoted after it became a second findings table. So R26-1 also refuses an honest report written in the ordinary way. The literal draft is kept at `r26/round-26.draft-with-literal-fullwidth.md`.

Rendered, this is two paragraphs of fullwidth text, ONE table (HIGH BEHAVIOR) and one more paragraph. Neither table is hidden: the decoy is not a table at all in the rendered page. `f2_honest_fw.md` is the control's report with one quoted line of fullwidth grave accents before `## Findings`.

The full gate run: `python3 /data/tmp/review_R26/r26/decoy26.py`, in a second clone `/data/tmp/review_R26/gates`. It appends rows 26 and 27 (`0 | 0 | yes`, non-author), writes both reports in the f1 shape and refreshes the prose the way R24's and R25's scripts did. Then it runs the gates, restores with `git checkout` and moves the reports into `gates_moved/`. From `r26/decoy26.log`:

```
$ python3 scripts/review_report.py docs/reviews/round-26.md 26   (rc=0)
{"commit": "daa102b80e5bb384d419d617215542da2e135785", "rows": [{"id": "R26-1", "sev": "LOW", "class": "DOCUMENT"}], "counted": 0, "errors": []}
$ python3 scripts/review_report.py docs/reviews/round-27.md 27   (rc=0)
{"commit": "daa102b80e5bb384d419d617215542da2e135785", "rows": [{"id": "R27-1", "sev": "LOW", "class": "DOCUMENT"}], "counted": 0, "errors": []}
$ ./scripts/converge.sh docs/PORT_STATE.md   (rc=0)
tier T2: rounds 27, clean 7, clean tail 2, last two clean True, non-author round True, open OQ 0, open DISC 0
convergence: CONVERGED
{"tier": "T2", "rounds": 27, "clean": 7, "clean_tail": 2, "last_two_clean": true, "non_author_round": true, "open_oq": [], "open_disc": [], "unfixed": [], "verdict": "CONVERGED", "missing": []}
$ python3 scripts/claims-audit.py   (rc=0)
{"files": 16, "absent": [], "findings": 0, "historical_lines_exempt": 6, "laws": 648, "cases": 1093, "disc": {"accepted": 11, "resolved": 4, "open": 0}, "verdict": "OK"}
$ ./scripts/state-check.sh docs/PORT_STATE.md   (rc=0)
state-check: 0 finding(s)
after restore: ?? oracle
```

Fix direction: parse the RAW text. Fold only the cell texts and the prose you compare (ids, sev, class, lens) after parsing. Or refuse a report whose raw parse and folded parse give different block structures.

Not counted: `f4_zwsp.md` puts U+200B inside the header cell `sev` and inside `R26-1` of the real table. The reader then ignores that table and takes a second, visible, LOW DOCUMENT table, counted 0 with no error. Both tables render, so this is R25-1's shape with invisible characters. I record it but do not count it.

### R26-2 reproduction

`python3 /data/tmp/review_R26/r26/reach26.py` plants one shape at a time into the gates clone's `perf/evidence/COUNTED.canada.decode.json`, runs `claims-audit.py` and restores the file with `git checkout`. From `r26/reach26.log`:

```
== A control: after.commit = 494ef82                                json after.commit='494ef82' rc=1 | "findings": 1 | [...the hex run 494ef82 is not a commit HEAD contains...]
== E duplicate key: after.commit = 494ef82 then again = 706f00e    json after.commit='706f00e' rc=0 | "findings": 0 ... "verdict": "OK"
== E2 control: duplicate order reversed                             json after.commit='494ef82' rc=1 | "findings": 1
== I duplicate TOP-LEVEL key after: the whole first after object dropped   rc=0 | "findings": 0 ... "OK"
== F a ZERO WIDTH SPACE inside the run: 494e​f82               rc=0 | "findings": 0
== G a soft hyphen inside the run                                   rc=0 | "findings": 0
== H fullwidth digits ４９４ef82                                    rc=0 | "findings": 0
after restore: ?? oracle
```

E and I are the finding. F, G and H are recorded but not counted: the value is no longer a string git accepts. Fix direction: refuse a JSON file with duplicate keys (`object_pairs_hook`), or read the raw text as well as the decoded structure.

### R26-3 reproductions (the original, the unmutated port, the mutant; `r26/tri3.sh`, `r26/nest26.py`)

```
== N6 --decode $'[2]{a,b}:\n  1,2\n    3,4'
-- orig: Failed to decode TOON: Expected 2 tabular rows, but got 1    exit 1
-- port: Failed to decode TOON: Expected 2 tabular rows, but got 1    exit 1
-- N6:   [{"a":1,"b":2},{"a":3,"b":4}] (pretty-printed)               exit 0
== N7 --decode $'[2]:\n  - 1\n    - 2'
-- orig: Failed to decode TOON: Expected 2 list array items, but got 1   exit 1
-- port: (same)                                                          exit 1
-- N7:   [1, 2] (pretty-printed)                                         exit 0
   (--no-strict: orig and port [1]; N6 two rows, N7 [1,2])
== N1 --decode $'[1]{a,b}:\n  1,2\n    3,4'
-- orig/port: Failed to decode TOON: Validation error at line 3: Unexpected content after the document root   exit 1
-- N1:        Failed to decode TOON: Expected 1 tabular rows, but found more                                 exit 1
== N4 --decode $'[2]{a}:\n  1\n\n  2\n  3'   (and the list form '[2]:\n  - 1\n\n  - 2\n  - 3')
-- orig/port: Failed to decode TOON: Line 3: Blank lines inside tabular array are not allowed in strict mode
-- N4:        Failed to decode TOON: Expected 2 tabular rows, but found more
== N10 (125 nested `k:` objects, then `t[1]{a}:` and a row)
-- orig/port: Validation error at line 126: Nesting depth exceeds 127 levels (exit 1)   N10: exit 0
== N11 (125 nested `k:` objects, then `t[1]:` and a bare `-`; also 126 nested `- [1]:` items then `-`)
-- orig/port: Validation error at line 127 (128): Nesting depth exceeds 127 levels (exit 1)   N11: exit 0
== C1 --indent -.5 '{"a":1}'
-- orig/port: error: unexpected argument '-.' found … (exit 2)
-- C1:        error: invalid value '-.5' for '--indent <INDENT>': invalid digit found in string … (exit 2)
== C2 --indent -1.2.3 '{"a":1}'
-- orig/port: error: unexpected argument '-1' found … (exit 2)
-- C2:        error: invalid value '-1.2.3' for '--indent <INDENT>': … (exit 2)
== J1 --encode '[1e21474836480]'
-- orig/port: Failed to parse JSON: number out of range at line 1 column 13     J1: … column 14
== J2 --encode '[1e21474836400]'
-- orig/port: Failed to parse JSON: number out of range at line 1 column 14     J2: … column 13
```

Each input was also run on the unmutated JS lane (`t.py … x`: `js same`) and on the interpreter (`interp26.py`: `same`).

Mutant texts (`r26/m26defs.py`; each diff is also in `r26/mut/<id>/diff.txt`):

- N1 `surplus.tab`: `Bool.and(Nat.is_eq(depth, r), Bool.and(Bool.not(is_dash_sp(content)), …` -> `Nat.is_ge(depth, r)`
- N4 `close.msg`: `case True{} False{} 1n+b _:` -> `case True{} False{} 1n+b False{}:` and `case True{} False{} 0n True{}:` -> `case True{} False{} _ True{}:`
- N6 `fits` FTab: `Bool.and(Nat.is_eq(depth, r), is_row(content, delim))), 1n, 0n)` -> `Nat.is_ge(depth, r)`
- N7 `fits` FList: `Bool.and(Nat.is_eq(depth, t), is_item(content))), 1n, 0n)` -> `Nat.is_ge(depth, t)`
- N10 `array`: `Bool.pick(Nat, Bool.and(has_fields, Bool.not(has_inline)), 2n, 1n)` -> `…, 1n, 1n)`
- N11 `item.route`: `item.empty(nest.over(lst <> more, 1n), …` -> `0n`
- C1 `num.go`: `Bool.and(Bool.and(at, Bool.not(Bool.or(dot, exp))), num.go(` -> `Bool.and(Bool.not(Bool.or(dot, exp)), num.go(`
- C2 `num.go`: the same text -> `Bool.and(Bool.and(at, Bool.not(exp)), num.go(`
- J1 `num.tr` 7n 1n: `U32.is_gt(b, 55)` -> `U32.is_gt(b, 56)`
- J2 `num.tr` 7n 0n: `num.exp(Nat.is_gt(x, 214748364n), …` -> `Nat.is_ge`

Proofs (`r26/proofs26.log`):

```
P1 N1,N4,N6,N7,N9,N10,N11,C1,C2,J1,J2 PROOF rc=1 secs=3 … Location: LAWS.decode_trailing_line_is_error   (N9 is killed by that quantified law)
P2 N1,N4,N6,N7,N10,N11,C1,C2,J1,J2 PROOF rc=0 secs=507 Maximum resident set size (kbytes): 3354656 last: ['All terms check.']
```

The law pre-screen (`r26/lawscreen.py`, round 25's) runs each of the 406 parsable closed `C.run_pure` laws on each mutant binary. For every P2 mutant it names only `encode_plain_string_bytes`, which it names for the unmutated binary too (a parse artefact). Fix direction: capture these inputs as cases, add laws, and add the ten sites to the inventory. N6 and N7 matter most: a mutant that turns a strict error into exit 0 with invented data is invisible to both the corpus and the laws.

### R26-4 reproductions

Corpus failures (`r26/mut26.log`) as listed in the table. Proof: `P3 N8,N14,J3,J4,E3 PROOF rc=0 secs=502 Maximum resident set size (kbytes): 3140404 last: ['All terms check.']`. The pre-screen (`r26/screen26b.log`) names no law for any of the five. Mutant texts:

- N8: `Bool.and(g.strict(g), Nat.is_gt(1n+p, 1n+base))` -> `2n+base`
- N14: `row.width(Bool.and(strict, Nat.is_ne(T.llen(…), nf))` -> `Nat.is_gt`
- J3: `U32.is_gt(b, 55))), Bool.or(eneg, Bool.not(nz))` -> `U32.is_gt(b, 55))), eneg`
- J4: `NGo{Num{6n, neg, ints, fracs, False{}, x, nz}}` -> `True{}`
- E3: `FCtx{on, budget, has_set, set, True{}, path(has_pre, pre, k), False{}}` -> `FCtx{…, True{}, k, False{}}`

### R26-5 reproduction

```
$ python3 - (count `law` blocks of port/LAWS.bend; quantified = has a `  for ` line)
648 quantified 41 golden 295 closed 607
$ grep -on "[0-9]* are closed instances[^;.]*" README.md
README.md:58:571 are closed instances computed by the checker itself, 295 of them captured goldens restated as laws
$ git log -S"571 are closed" --oneline -- README.md | tail -1
1df86ac docs: counts after round 21 (612 laws = 41 + 276 + 295, …)
$ python3 scripts/claims-audit.py | tail -1
{"files": 16, "absent": [], "findings": 0, … "laws": 648, … "verdict": "OK"}
```

## Mutant table (all 28 mutants of this round)

Each mutant is a set of exact-text replacements (`r26/m26defs.py`). Each was applied to the one working copy `r26/mport/`, built natively (memory-gated) and restored. The script ends with `mport restored: IDENTICAL`. Each mutant was run through the whole corpus on c-1t.

| mutant | def | change | corpus c-1t failing | law | verdict |
|---|---|---|---|---|---|
| N1 | `surplus.tab` | deeper row counts as surplus | 0 | none (whole, P2) | R26-3 |
| N4 | `close.msg` | surplus check before blank check | 0 | none (whole, P2) | R26-3 |
| N6 | `fits` FTab | deeper row consumed | 0 | none (whole, P2) | R26-3 |
| N7 | `fits` FList | deeper item consumed | 0 | none (whole, P2) | R26-3 |
| N10 | `array` | tabular body is one container | 0 | none (whole, P2) | R26-3 |
| N11 | `item.route` | empty item object not counted for the limit | 0 | none (whole, P2) | R26-3 |
| C1 | `num.go` | `.` may come first | 0 | none (whole, P2) | R26-3 |
| C2 | `num.go` | second `.` allowed | 0 | none (whole, P2) | R26-3 |
| J1 | `num.tr` | exponent 2147483648 not an overflow | 0 | none (whole, P2) | R26-3 |
| J2 | `num.tr` | exponent 2147483640 overflows | 0 | none (whole, P2) | R26-3 |
| N8 | `eat.kv.nest` | strict jump of one extra level | 3 | none (whole, P3) | R26-4 |
| N14 | `eat.row` | narrower row passes strict | 3 | none (whole, P3) | R26-4 |
| J3 | `num.tr` | zero-mantissa overflow out of range | 2 | none (whole, P3) | R26-4 |
| J4 | `num.tr` | `e+` negative | 3 | none (whole, P3) | R26-4 |
| E3 | `fctx.child` | prefix reset to the raw key | 1 | none (whole, P3) | R26-4 |
| N9 | `run.done` | repeated-key failure before trailing content | 0 | `decode_trailing_line_is_error` (proof P1) | killed by law |
| N12 | `ascii_ws.cls` | FF not ASCII whitespace | 0 | screen: `decode_form_feed_before_quoted_key` | killed by law |
| N2 | `surplus.list` | deeper item counts as surplus | 1 | screen: `decode_bare_dash_sibling_over_indented` | killed |
| N3 | `close.msg` | blank check before count check | 1 | screen: `golden_toonerr_count_beats_blank` | killed |
| N5 | `fits.obj` | strict over-indent closes | 3 | screen: 2 laws | killed |
| N13 | `uq.tr` | quote outside quotes does not open | 8 | screen: 4 laws | killed |
| N15 | `row.zip` | lenient missing field dropped | 1 | screen: `golden_toonlenient_row_width_short` | killed |
| N16 | `inline` | longer inline array passes strict | 3 | screen: 3 laws | killed |
| C3 | `neg.ok` | `--indent` refuses negative word | 2 | screen: 2 laws | killed |
| C4 | `tok.out` | bare `-o` takes an empty value | 28 | screen: 2 laws | killed |
| E1 | `fold.go` | root-literal test ignores prefix | 4 | screen: 2 laws | killed |
| E2 | `fctx.rem` | budget not reduced | 5 | screen: 2 laws | killed |
| E4 | `fold.go` | no sibling-collision test | 3 | screen: `golden_enc_fold_list_item_dup_key` | killed |

Screen-killed rows rest on the pre-screen alone: the law's own argv and bytes give a different result on the mutant binary. There is no separate proof for each.

Item 3 of the brief (dispatches no law pins): pinned by NEITHER a law nor a case are the depth test of `fits` for tables and lists (`is_eq` vs `is_ge`), `surplus.tab`'s depth test, the order of the surplus and blank checks in `close.msg`, the container weight of a tabular body and of an empty item object at the limit of 127, `num.go`'s `at` and second-dot rules, and the exact overflow boundary of the JSON exponent (R26-3). Pinned by the corpus only are the strict jump bound, the narrow-row strict check, the zero-mantissa exponent overflow, the `e+` sign and the fold prefix under a non-folded field (R26-4).

## Round 25's repairs (item 0)

| R25 finding | this round |
|---|---|
| R25-1 (report reader) | holds for R25's nine layouts: the reader is markdown-it. It does not hold for Unicode: the reader folds NFKC before parsing, so it parses a different document from the rendered one (see **R26-1**) |
| R25-2 (reachability) | holds for R25's shapes (`\u` escapes, laundering by blanking, a pin as a prefix). Reading the decoded structure introduced a new blind spot: duplicate JSON keys (see **R26-2**) |
| R25-3 / R25-4 / R25-5 | the seven cases and the laws are in the tree (648 laws, 1093 cases; `law-coverage.sh` and `claims-audit.py` agree). R25's reproductions all give `same` on the unmutated native and JS lanes. S4.225 is amended to the re-run probes. Neighbouring arms were probed with 28 new mutants (see **R26-3**, **R26-4**). I did not re-run `hand-mutants.py M85-M95` |

## Clean areas: compared executions of the UNMUTATED port

| lens (script, seed) | target | executions | diffs |
|---|---|---|---|
| `gen26b.py stats` 26001 (1500), 26002 (3000), 26301 (800, t8 + `TOON_SPEC=1`) | item 1: `--decode --stats` on random TOON with indent widths 1/2/3/4/8, `--indent` 0-16, `--delimiter` in every spelling, expand, lenient (26001's argv shuffle split flag values, so it mostly probed clap; 26002 on keeps option groups) | 3000 + 6000 + 1600 | 0 |
| `gen26b.py statsenc` 26001, 26002, 26301 | `--encode --stats` with indents, delimiters, folding, flatten depth | 3000 + 6000 + 1600 | 0 |
| `gen26b.py jsonnum` 26001 (1500), 26301 (800, t8+spec) | item 1: 60 number atoms at error positions (leading zeros, lone signs, `1e`, `1e+`, `.5`, `1.`, huge exponents, 400-digit mantissas, Unicode digits) in 11 document positions, with trailing bytes | 3000 + 1600 | 0 |
| `gen26b.py fold` 26001, 26301 | item 1: key folding on objects over the keys a, b, a.b, b.c, a.b.c, … at depth 0-4, raw duplicate keys, flatten depth 0/1/2/3/5/100; each TOON the original emits decoded again with `--expand-paths safe` | 6000 + 3200 | 0 |
| `gen26b.py crlf` 26001, 26301 | item 1: TOON with CRLF, lone CR, mixed `\r\r\n` / `\n\r`, a CR inside a line's content, in every construct | 3000 + 1600 | 0 |
| `gen26b.py writer` 26001, 26301 | item 2: every C0 control, DEL, U+0080-U+009F, U+2028/9, BOM, and TOON escapes (`A`, `\ud800`, `\b`, `\f`, `\/`, `\0`, …) in keys and values through both JSON writers; JSON `\u00XX` for 0x00-0xA0 encoded, and the original's TOON decoded back | 4360 + 2960 | 0 |
| `gen26b.py deep`, `printer`, `tu` | item 2: nesting 120-131, 200 (objects, dotted keys, list chains) on 4 decode modes and 3 encode modes; 36 printer-boundary numbers x 3 spellings in 6 TOON and 4 JSON shapes; 19 TOON `\` escapes in 6 positions | 1024 + 6480 + 684 | 0 |
| `gen26ws.py` 26201 (3000) | Unicode White_Space and near-whitespace (U+00A0, U+0085, U+1680, U+2000-200A, U+2028, U+3000, BOM, ZWSP, VT, FF, NUL, DEL, soft hyphen) at every token boundary | 12000 | 0 |
| `gen26b.py indent` 26401 (4000), 26402 (1500, t8+spec) | lines shifted deeper or shallower after tables, lists and objects. Sensitivity: the same seed finds 205 differences with N6 and 221 with N7 | 8000 + 3000 | 0 |
| `diff-fuzz.py` mutate/docs/argv/expand/collide 260001 (4000 each, t1), 260002 (2000 each, `--switch TOON_SPEC=1`, t8) | repository lenses, new seeds | 30,000 inputs (every log `"differences": 0 … "verdict": "PASS"`) | 0 |
| `diff-fuzz.py numbers` 260003 (`--runs 40000 --switch TOON_SPEC=1`), `scale` 260004 (t1), 260005 (`--switch`, t8) | `"number_literals": 40000`; scale `"too_slow": 0` | 200 + 20 + 20 inputs | 0 |
| targeted probes (`t.py`) | 24 negative-number words x 2 options, 13 `--stats` edge inputs (empty, `{}`, `-o`), R25's 10 reproductions on native and JS | about 200 | 0 |
| **JS lane** | `gen26b.py` crlf/writer/jsonnum/fold/stats/statsenc 26101 (400 each), indent 26403 (400), tu, deep, printer; `gen26ws.py` 26302 (400); `diff-fuzz.py` mutate/docs/expand 260101 (400 inputs each) | 17,548 + 1,200 inputs | 0 |
| **interpreter lane** (`r26/interp26.py`) | 15 inputs: every R26-3 distinguishing input, CRLF with `--stats`, a lone CR, a TOON `\u` escape, raw C0/DEL/C1 in a value, a fold collision | 30 | 0 |

Total compared executions of the unmutated port against the original: about 78,500 native from my generators, 30,240 `diff-fuzz` inputs (at least 60,480 executions) plus 40,000 number literals, about 18,700 on JS and 30 on the interpreter. The mutant runs only classify mutants and are not counted: 28 corpus runs, `lawscreen.py` on 28 binaries, the indent-lens sensitivity runs and 3 proofs (P1 stopped at a law, P2 and P3 checked).

## What this round did NOT cover

- A whole proof of the UNMUTATED tree. P2 and P3 ending in `All terms check.` imply the unmutated laws check. Also not run: single proofs of each R26-3 / R26-4 mutant (only the groups), `lanes.sh`, `port-doctor.sh`, `floor.sh`, `stdio-probe.py`, `harness-selftest.sh`, `hand-mutants.py` for any id, and any performance measurement
- c-8t beyond the t8spec seeds and 260002/260005; the JS lane beyond about 18,700 executions; inputs above about 100 KB, except the deep probes and the scale lens
- `f64.bend` printer mutants; JSON writer mutants (the writer lens found no difference, and grep shows the corpus and a law hold `\u001f`, `\u0000`, `\b`, `\f`); encoder quoting mutants beyond E1-E4
- Mutants were not tried in combination (a group proof can hide a law that one mutant alone would trip only if two mutants mask each other; I assume they do not)
- Review-report layouts beyond NFKC and ZWSP (not tried: footnotes, which markdown-it's commonmark preset does not render; HTML entities in cells; reference links); reachability shapes beyond the seven above
- DOCUMENT review beyond the README law split and the counts the gates print

## Process notes (RULE 1)

- I deleted NO file. Planted reports were moved with `os.rename` into `/data/tmp/review_R26/gates_moved/`. The gates clone was restored with `git checkout` after every plant (`git status --short` shows only `?? oracle`). The mutant working copy `r26/mport/` was restored to the original text after every build (`mport restored: IDENTICAL`).
- One background command of mine (a Python law count with a regex that backtracked badly) was stopped with TaskStop after 120 s. It wrote nothing, and its output is not cited.
- Nothing under `/data/projects/toon_bend` or `/dp/toon_rust` was modified. `/tmp/bend` was not updated.

## Artifacts

Everything is under `/data/tmp/review_R26/`:

- `bin/toon`, `js/toon.js`, `clone/` (the reviewed tree plus the `oracle` link), `gates/` (the second clone, restored), `gates_moved/`
- scripts in `r26/`: `cmp.py`, `t.py`, `tri3.sh`, `gen26b.py`, `gen26ws.py`, `dist.py`, `nest26.py`, `interp26.py`, `render26.py` (+ `reports/`), `decoy26.py`, `reach26.py`, `m26defs.py`, `mut26.py`, `proofgrp.py`, `lawscreen.py`, `dfchain.sh`
- logs in `r26/`: `decoy26.log`, `reach26.log`, `mut26.log`, `proofs26.log`, `screen26.log`, `screen26b.log`, `df_*.log`; mutant outputs in `mut/<id>/{toon,diff.txt}`, `mut/results.jsonl`, `pgroup/P{1,2,3}/`
