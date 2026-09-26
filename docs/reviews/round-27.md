# Round 27: non-author hostile review of toon_bend

| field | value |
|---|---|
| reviewed commit | 67506ebe2f1cc5821492f9feab1dc91495ea9808 |
| clone | fresh `git clone https://github.com/Dicklesworthstone/toon_bend /data/tmp/review_R27/clone`; `git rev-parse HEAD` printed that hash (the expected `67506eb`) |
| original | `oracle/toon` -> `/data/projects/toon_bend/oracle/toon`, sha256 `821287eaf1a6d320ee1ef7604e74e3cefaa42b69445c96abb9dd310782d04030`, equal to `docs/PIN.toml` |
| Bend | `bun /tmp/bend/bend2/main.ts`, `/tmp/bend` at `15ae0c86f3193b8f645b4bedbc438655b648d0da`, `BEND_NO_TELEMETRY=1` (never updated) |
| tools | bun 1.4.2, Ubuntu clang 21.1.8, Python 3.14.4, markdown-it-py 3.0.0 |
| port binaries | native `/data/tmp/review_R27/bin/toon` (23 s wall, sha256 `825e44de69c3a4e6c0d442ea99c86be8c3b194f8e58a090137fc0c4d2743ac9e`, the binary PORT_STATE names); JS `/data/tmp/review_R27/bin/toon.js` (2.7 s), run through `scripts/js-lane.py` |
| unmutated corpus | `./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t -- ../bin/toon --threads 1 --` -> `"passed":1103,"failed":0,"inconclusive":0,"stderr_compared":true,"verdict":"PASS","oracle_identity_checked":true` |
| repo gates on this tree | `claims-audit.py` -> `"findings": 0 … "laws": 657, "cases": 1103 … "verdict": "OK"`; `law-coverage.sh` -> `"laws": 657, "proofs": 657 … "verdict": "OK"`; `build-cases.py --check` OK; `cases-lint.sh` OK; `port-lint.py` OK (53 PL-02 infos); `converge.sh` NOT_CONVERGED (clean tail 0) |
| host | shared, 8 cores, 30 GB. 16:27 load 1.2, 23 GB available, 17 GB disk free (15 GB at the end). This round used 101 MB. Every build and proof started at >= 12 GiB `MemAvailable`, one at a time, under `systemd-run --user --scope -p MemoryMax=8G` (builds, interpreter) or `10G` (proofs), `MemorySwapMax=0`. None was killed. Whole-proof peaks 2.9-3.4 GB, 437-470 s |
| harness | `r27/cmp.py` runs `./oracle/toon ARGV` and `bin/toon --threads T -- ARGV` (or `js-lane.py toon.js -- ARGV`) on the same stdin and compares stdout, stderr and exit byte for byte, with `TOON_SPEC` removed unless set. "Executions" counts every run of either program |

## Findings (counting rule of 2026-09-23, rules 1-6)

| id | sev | class | what | spec |
|---|---|---|---|---|
| R27-1 | MEDIUM | BEHAVIOR (gate that lies; NEW, in R25-1/R26-1's repair) | `scripts/review_report.py` drops Markdown strikethrough (`~~LOW~~ HIGH` is read as HIGH) but reads inline-HTML strikethrough as plain text. `<del>LOW</del> HIGH` (also `<s>`, `<strike>`, `<span hidden>`) is read as sev `LOW`. markdown-it renders `~~LOW~~` as `<s>LOW</s>`, the same HTML the raw `<s>LOW</s>` produces, and the gate reads the two differently. With planted rounds 27 and 28 (`0 \| 0 \| yes`, non-author) whose only rows are `\| R2n-1 \| <del>LOW</del> HIGH \| BEHAVIOR \| … \|`, `converge.sh` prints `CONVERGED`, `claims-audit.py` prints `"findings": 0 … "OK"` and `state-check.sh` prints `0 finding(s)`. The control `~~LOW~~ HIGH` gives NOT_CONVERGED. It also misreads an honest report: a finding re-graded to `<del>HIGH</del> LOW \| <del>BEHAVIOR</del> DOCUMENT` is counted as HIGH BEHAVIOR | PARITY-GATE rules 1, 6; `review_report.py` docstring ("struck-through text [is] not read") |
| R27-2 | LOW | BEHAVIOR (gate that lies; NEW, in R25-2/R26-2's repair) | Reachability decodes a JSON or JSONL evidence file only when EVERY line parses. Otherwise it reads the whole raw file, where `\u`-escapes stay encoded. Take a JSONL file whose valid first line is `{"run": 1, "commit": "494ef82"}` (decodes to the unreachable `494ef82`) and add one truncated last line (an interrupted writer), or one line with a trailing comma. `claims-audit.py` then prints `"findings": 0 … "OK"`. Without the bad line it prints `"findings": 1`, and with the commit written plainly next to the same bad line it also prints 1. A lone `{"commit": "4…",}` object gives 0 in the same way. Not among the three declared limits | (claims) |
| R27-3 | MEDIUM | BEHAVIOR (corpus gap; ONE finding against `scripts/hand-mutants.py`: no site is in its inventory) | Seven NEW hand mutants survive the whole corpus on c-1t (1103 of 1103 each) AND the whole 657-law `PROOF.bend` as one group (P3: `All terms check.`, 470 s). On each distinguishing input the unmutated port equals the original on native t1, c-8t with `TOON_SPEC=1`, JS and the interpreter. E11 `budget.check.c`: a three-digit `--flatten-depth` acts as unlimited (a 120-deep chain with `--flatten-depth 100` folds all 120 segments). C6 `bom.bytes`: `EF BB xx` is dropped as a BOM. N18 `array`: an inline array weighs two containers toward 127. N19 `item.route`: a hyphen-line item object is not counted toward 127. E13 `fctx.rem`: under a partial fold the enclosing prefix is lost, so a nested fold collides with a root literal. C11 `num.go`: `-1e5` is no longer a negative number. J5 `num.tr` 7n 0n: `[0e21474836470]` is out of range | S1.32/S7.2, S8.7, S4.230 (2), S4.71/S4.72/S4.77, S1.156, S2.14 (a) |
| R27-4 | LOW | LAW-COVERAGE (ONE finding against `scripts/hand-mutants.py`) | Five NEW mutants that the corpus kills on c-1t but NO law does. All five together in group P4 give `All terms check.` (466 s), and the law pre-screen names none of them. E6 `emit` CObjK: a nested object body has no sibling set (`enc_fold_nested_literal_not_root` only). N17 `array`: a list body weighs two containers (5 cases). D4 `expand`: an array does not raise the expansion counter (`toonerr_expand_root_tabular_field_253`, `toonerr_expand_keyed_tabular_field_251`). J10 and J11 `num.tr` 3n 0n / 4n 0n: a fraction digit 0 marks the mantissa non-zero (`encnum_exponent_forms` only) | S4.69, S4.230, S4.248, S2.14 (a) |

Count under the rule: **BEHAVIOR 3 (MEDIUM 2, LOW 1), LAW-COVERAGE 1 (LOW), DOCUMENT 0.** NEW behavior findings of MEDIUM or above: **2** (R27-1, R27-3). This round is NOT clean. I found **no difference between the UNMUTATED port and the original** on any lane I tried: about 53,300 native executions from my own generators, 30,240 `diff-fuzz` inputs with new seeds plus 40,000 number literals, about 5,470 JS-lane executions from my generators plus 2,000 `diff-fuzz` inputs on JS, and 26 interpreter executions.

### R27-1 reproduction

The reader alone (`/data/tmp/review_R27/r27/reports/`). Each report holds the header table and one findings table with one row. RENDERED is markdown-it's HTML of that row (commonmark + table + strikethrough, the reader's own configuration):

```
== control.md       {"rows": [{"id": "R27-1", "sev": "HIGH", "class": "BEHAVIOR"}], "counted": 1, "errors": []}
   RENDERED row: <tr><td>R27-1</td><td>HIGH</td><td>BEHAVIOR</td>…
== strike_md.md     {"rows": [{"id": "R27-1", "sev": "HIGH", "class": "BEHAVIOR"}], "counted": 1, "errors": []}
   RENDERED row: <tr><td>R27-1</td><td><s>LOW</s> HIGH</td><td>BEHAVIOR</td>…
== del_sev.md       {"rows": [{"id": "R27-1", "sev": "LOW", "class": "BEHAVIOR"}], "counted": 0, "errors": []}
   RENDERED row: <tr><td>R27-1</td><td><del>LOW</del> HIGH</td><td>BEHAVIOR</td>…
== s_class.md       {"rows": [{"id": "R27-1", "sev": "HIGH", "class": "DOCUMENT"}], "counted": 0, "errors": []}
   RENDERED row: <tr><td>R27-1</td><td>HIGH</td><td><s>DOCUMENT</s> BEHAVIOR</td>…
== strike_tag.md    {"rows": [{"id": "R27-1", "sev": "LOW", "class": "BEHAVIOR"}], "counted": 0, "errors": []}
   RENDERED row: <tr><td>R27-1</td><td><strike>LOW</strike> HIGH</td><td>BEHAVIOR</td>…
== hidden_span.md   {"rows": [{"id": "R27-1", "sev": "LOW", "class": "BEHAVIOR"}], "counted": 0, "errors": []}
   RENDERED row: <tr><td>R27-1</td><td><span hidden>LOW</span> HIGH</td><td>BEHAVIOR</td>…
== honest_revert.md {"rows": [{"id": "R27-1", "sev": "HIGH", "class": "BEHAVIOR"}], "counted": 1, "errors": []}
   RENDERED row: <tr><td>R27-1</td><td><del>HIGH</del> LOW</td><td><del>BEHAVIOR</del> DOCUMENT</td>…
```

(`strike_md.md` renders `<s>LOW</s> HIGH`, and `s_class.md`'s raw `<s>DOCUMENT</s>` renders the same element, yet the gate reads the first as struck and the second as text.) An HTML comment `<!-- LOW --> HIGH` is read correctly (HIGH), because a comment is one `html_inline` token. Element tags are also `html_inline` tokens, but the text BETWEEN them is an ordinary `text` token that `_text` keeps.

The full gate run is `python3 /data/tmp/review_R27/r27/decoy27.py`, run in the one clone. It appends rows 27 and 28 (`0 | 0 | yes`, non-author) and writes both reports with the row `| R2n-1 | <del>LOW</del> HIGH | BEHAVIOR | … |`. It refreshes the prose (rounds span, the per-round list `…, 2, 0 and 0`, the pasted converge line), runs the gates, then restores with `git checkout` and moves the reports into `/data/tmp/review_R27/moved/`. From `r27/decoy27.log`:

```
$ python3 scripts/review_report.py docs/reviews/round-27.md 27   (rc=0)
{"commit": "67506ebe2f1cc5821492f9feab1dc91495ea9808", "rows": [{"id": "R27-1", "sev": "LOW", "class": "BEHAVIOR"}], "counted": 0, "errors": []}
$ python3 scripts/review_report.py docs/reviews/round-28.md 28   (rc=0)
{"commit": "67506ebe2f1cc5821492f9feab1dc91495ea9808", "rows": [{"id": "R28-1", "sev": "LOW", "class": "BEHAVIOR"}], "counted": 0, "errors": []}
$ ./scripts/converge.sh docs/PORT_STATE.md   (rc=0)
tier T2: rounds 28, clean 7, clean tail 2, last two clean True, non-author round True, open OQ 0, open DISC 0
convergence: CONVERGED
{"tier": "T2", "rounds": 28, "clean": 7, "clean_tail": 2, "last_two_clean": true, "non_author_round": true, "open_oq": [], "open_disc": [], "unfixed": [], "verdict": "CONVERGED", "missing": []}
$ python3 scripts/claims-audit.py   (rc=0)
{"files": 16, "absent": [], "findings": 0, "historical_lines_exempt": 6, "laws": 657, "cases": 1103, "disc": {"accepted": 11, "resolved": 4, "open": 0}, "verdict": "OK"}
$ ./scripts/state-check.sh docs/PORT_STATE.md   (rc=0)
state-check: 0 finding(s)
after restore: ?? oracle
```

Control, `python3 decoy27.py "~~LOW~~ HIGH"` (`r27/decoy27_control.log`): both reports counted 1, `converge.sh` rc=1 `NOT_CONVERGED` (`round 27: the table says 0 counted finding(s), docs/reviews/round-27.md lists 1`), `claims-audit.py` `"findings": 3`.

This is not a hidden table and not a complete forgery. The one table renders, and a reader of the rendered page sees HIGH (with a struck-out LOW). A reviewer who re-grades a row in the ordinary way is misread in both directions. Fix direction: in `_text`, also drop the text between `html_inline` open and close tags of `del`, `s`, `strike`, and of any element carrying `hidden` (or refuse any cell that contains an `html_inline` token).

### R27-2 reproduction

`python3 /data/tmp/review_R27/r27/reach27.py` plants one file at a time under `perf/evidence/`, runs `claims-audit.py` and moves the plant into `/data/tmp/review_R27/moved/`. From `r27/reach27.log`:

```
== A control: one JSONL line, commit escaped
   file perf/evidence/probe27.jsonl = '{"run": 1, "commit": "\\u0034\\u0039\\u0034\\u0065\\u0066\\u0038\\u0032"}\n'
   rc=1 ['perf/evidence/probe27.jsonl:0: the hex run 494ef82 is not a commit HEAD contains, a pin of docs/PIN.toml or PLAN §2, or a digest: a reader cannot check it']
== B the same line + a truncated last line (an interrupted writer)
   file perf/evidence/probe27.jsonl = '{"run": 1, "commit": "\\u0034…\\u0032"}\n{"run": 2, "comm\n'
   rc=0 []   {"files": 16, … "findings": 0, … "verdict": "OK"}
== C the same line + a line with a trailing comma
   rc=0 []   {… "findings": 0, … "verdict": "OK"}
== D one JSON object with a trailing comma (not JSON; JSON5 reads it)
   file perf/evidence/probe27.json = '{"commit": "\\u0034…\\u0032",}\n'
   rc=0 []   {… "findings": 0, … "verdict": "OK"}
== E control: B with the commit written plainly
   rc=1 ['perf/evidence/probe27.jsonl:0: the hex run 494ef82 is not a commit HEAD contains, …']
json.loads of the escaped value: 494ef82
after restore: ?? oracle
```

Cause (`claims-audit.py` lines 324-331): `docs_ = [json.loads(l, **keep) for l in raw.splitlines() if l.strip()]` fails as a whole when one line fails, `docs_ = None`, and the raw text is scanned. There, every hex run of the escaped commit is 4 digits long. Fix direction: decode per line and keep the lines that parse, scanning only the failing lines raw. Also decode `\uXXXX` in the raw fallback, or refuse an unparseable `.json`/`.jsonl` evidence file.

### R27-3 reproductions (the original, the unmutated port, the mutant; `r27/mut27.py`, `mut/results.jsonl`)

```
== E11 --encode --key-folding safe --flatten-depth 100  <  {"k":{"k":…(120 levels)…1…}}
-- orig/port: first line has 100 segments `k.k.….k:` then 20 nested `k:` lines        exit 0
-- E11:       one line `k.k.…(120 segments)…k: 1`                                      exit 0
== C6 --encode  <  bytes EF BB 80
-- orig/port: Failed to parse JSON: expected value at line 1 column 1          exit 1
-- C6:        Failed to parse JSON: EOF while parsing a value at line 1 column 0   exit 1
== N18 --decode  <  125 nested `k:` objects, then `t[1]: 1`          (r27/in_inline125.toon)
-- orig/port: the JSON object, exit 0
-- N18:       Failed to decode TOON: Validation error at line 126: Nesting depth exceeds 127 levels   exit 1
== N19 --decode  <  125 nested `k:` objects, then `t[1]:` and `- a: 1`   (r27/in_listobj125.toon)
-- orig/port: Failed to decode TOON: Validation error at line 127: Nesting depth exceeds 127 levels   exit 1
-- N19:       the JSON object, exit 0
== E13 --encode --key-folding safe  <  {"x.a.b.c.d":1,"x":{"z":0,"a":{"b":{"c":{"d":2},"e":3}}}}
-- orig/port: x.a.b.c.d: 1⏎x:⏎  z: 0⏎  a.b:⏎    c:⏎      d: 2⏎    e: 3
-- E13:       x.a.b.c.d: 1⏎x:⏎  z: 0⏎  a.b:⏎    c.d: 2⏎    e: 3        (decodes back with a colliding key)
== C11 --indent -1e5 -e  <  {"a":1}
-- orig/port: error: invalid value '-1e5' for '--indent <INDENT>': invalid digit found in string … exit 2
-- C11:       error: unexpected argument '-1' found⏎⏎  tip: to pass '-1' as a value, use '-- -1' … exit 2
== J5 --encode  <  [0e21474836470]
-- orig/port: [1]: 0                                                    exit 0
-- J5:        Failed to parse JSON: number out of range at line 1 column 14   exit 1
```

Every input above also gives `same` on the unmutated JS lane and on c-8t with `TOON_SPEC=1` (`js same | c-8t spec same`), and on the interpreter (`r27/interp27.py`: `interp same`).

Mutant texts (`r27/m27defs.py`):

- E11 `budget.check.c` (cli): `Nat.is_le(T.str_len(c, 0n), 3n)` -> `2n`
- C6 `bom.bytes` (cli): `Bool.and(U32.is_eq(a, 239), Bool.and(U32.is_eq(b, 187), U32.is_eq(c, 191)))` -> `Bool.and(U32.is_eq(a, 239), U32.is_eq(b, 187))`
- N18 `array` (decode): `Bool.pick(Nat, Bool.and(has_fields, Bool.not(has_inline)), 2n, 1n)` -> `Bool.pick(Nat, Bool.or(has_inline, has_fields), 2n, 1n)`
- N19 `item.route` (decode): `item.kv(nest.over(lst <> more, 1n), h0, r,` -> `0n`
- E13 `fctx.rem` (encode): `FCtx{on, Nat.sub(budget, segs), has_set, set, True{}, path(has_pre, pre, fkey), lean}` -> `…, True{}, fkey, lean}`
- C11 `num.go` 0n arm (cli): `num.go(rest, num.cls(rest), True{}, dot, exp, False{})` -> `…, exp, last_e)`
- J5 `num.tr` 7n 0n (json): `num.exp(Nat.is_gt(x, 214748364n), Bool.or(eneg, Bool.not(nz)), …, 0n)` -> `num.exp(Nat.is_gt(x, 214748364n), eneg, …, 0n)`

Proofs (`r27/proofs27.log`, whole `PROOF.bend`, 657 laws):

```
P1 E11,W3,C6,D2,N18,N19,E13,C11,J5 PROOF rc=1 secs=299 … loc=['Location: LAWS.decode_literal_first_of_two_bad_escapes']   (D2 killed by law)
P2 E11,W3,C6,N18,N19,E13,C11,J5 PROOF rc=1 secs=437 … loc=['Location: LAWS.decode_json_writer_lower_case_hex_controls']  (W3 killed by law)
P3 E11,C6,N18,N19,E13,C11,J5 PROOF rc=0 secs=470 ['Maximum resident set size (kbytes): 2853140'] stdout-first=['All terms check.'] restored=IDENTICAL
```

N19 is the hyphen-line neighbour of R26's N11 (the empty item). N18 is the inline neighbour of N10 (the tabular body). J5 is the `0`-digit arm of R26's J3. C11 is the digit arm of the `num.go` that C1/C2/M89/M90 mutate. E13 is the `fctx.rem` twin of R26's E3. The repairs pinned the arm each mutant touched, not the arms next to it. Fix direction: capture these seven inputs as cases, write laws where the checker can evaluate them, and add the sites to the inventory.

### R27-4 reproductions

Corpus failures (`mut/results.jsonl`): E6 1 (`enc_fold_nested_literal_not_root`). N17 5 (`toonerr_nesting_limit_at_empty_item`, `toonedge_expand_arrays_255`, `toonerr_expand_arrays_256`, `toonedge_expand_mixed_100_objects_55_arrays`, `toonerr_expand_mixed_100_objects_56_arrays`). D4 2 (`toonerr_expand_root_tabular_field_253`, `toonerr_expand_keyed_tabular_field_251`). J10 1 and J11 1 (`encnum_exponent_forms`). Proof: `P4 E6,N17,D4,J10,J11 PROOF rc=0 secs=466 ['Maximum resident set size (kbytes): 3311328'] stdout-first=['All terms check.']`. The pre-screen (`r27/screen27.log`) names no law for any of the five. Mutant texts:

- E6: `emit(entries, CFields{dc, fc, keys.kt(fc.on(fc), entries)}` -> `emit(entries, CFields{dc, fc, T.kt.empty()}`
- N17: `Bool.pick(Nat, Bool.and(has_fields, Bool.not(has_inline)), 2n, 1n)` -> `Bool.pick(Nat, Bool.not(has_inline), 2n, 1n)`
- D4: `arr.fin(n, expand(items, XItems{p, EOk{J.JNil{}}}, strict))` -> `XItems{1n+p, …}`
- J10: `case 3n 0n: NGo{Num{4n, …, eneg, x, nz}}` -> `…, x, True{}}}`
- J11: `case 4n 0n: NGo{Num{4n, …, eneg, x, nz}}` -> `…, x, True{}}}`

## Mutant table (all 27 mutants of this round)

Each mutant is a set of exact-text replacements (`r27/m27defs.py`). Each was applied to the one working copy `/data/tmp/review_R27/mport/`, built natively (memory-gated), restored (both runs end `mport restored: IDENTICAL`) and run through the whole corpus on c-1t.

| mutant | def | change | corpus c-1t failing | law | verdict |
|---|---|---|---|---|---|
| E11 | `budget.check.c` | 3-digit flatten depth unlimited | 0 | none (whole, P3) | R27-3 |
| C6 | `bom.bytes` | third BOM byte ignored | 0 | none (whole, P3) | R27-3 |
| N18 | `array` | inline array weighs 2 | 0 | none (whole, P3) | R27-3 |
| N19 | `item.route` | hyphen-line item object not counted | 0 | none (whole, P3) | R27-3 |
| E13 | `fctx.rem` | partial-fold prefix loses the parent path | 0 | none (whole, P3) | R27-3 |
| C11 | `num.go` | digit after `e` keeps `last_e` | 0 | none (whole, P3) | R27-3 |
| J5 | `num.tr` 7n 0n | zero-mantissa overflow by a `0` digit out of range | 0 | none (whole, P3) | R27-3 |
| E6 | `emit` CObjK | nested body has no sibling set | 1 | none (whole, P4) | R27-4 |
| N17 | `array` | list body weighs 2 | 5 | none (whole, P4) | R27-4 |
| D4 | `expand` | arrays do not raise the counter | 2 | none (whole, P4) | R27-4 |
| J10 | `num.tr` 3n 0n | first fraction 0 is non-zero | 1 | none (whole, P4) | R27-4 |
| J11 | `num.tr` 4n 0n | later fraction 0 is non-zero | 1 | none (whole, P4) | R27-4 |
| D2 | `lit.esc` | last bad escape named | 0 | `decode_literal_first_of_two_bad_escapes` (P1) | killed by law |
| W3 | `hexc` | hex digit 10 as `:` | 0 | `decode_json_writer_lower_case_hex_controls` (P2) | killed by law |
| W1 | `w.ch_a` 3n | U+0008 as `\f` | 6 | `writer_a_keeps_del_raw` (P9) | killed |
| W2 | `w.cls` | VT gets `\f`, FF `\u000c` | 6 | `writer_a_keeps_del_raw` (P10) | killed |
| C7 | `percent` | ties round down | 5 | `stats_exact_tie_rounds_up` (P7) | killed |
| C8 | `est.fin` | estimate may be 0 | 1 | `stats_estimate_empty` (P8) | killed |
| E5 | `emit` CObjItem | hyphen key not a sibling | 1 | screen: `golden_enc_fold_list_item_dup_key` | killed |
| E7 | `row.lock` | longer row passes lockstep | 3 | screen: `golden_fx_enc_arrays_objects_01` | killed |
| E8 | `walk` | enters multi-field objects | 7 | screen: `golden_enc_fold_budget_threading_5` | killed |
| E9 | `dotted.go` | root-literal set empty | 4 | screen: 3 laws | killed |
| D1 | `lit.close` | bad escape before trailing text | 1 | screen: `decode_literal_trailing_before_bad_escape` | killed |
| D3 | `path.ins` lenient | replaced key re-listed fresh | 3 | screen: `golden_toonedge_expand_hash_collision_lenient` | killed |
| NA | `fits` FTab | lenient stops at n rows | 2 | screen: `golden_toonlenient_extra_tabular_rows` | killed |
| NB | `fits` FList | lenient stops at n items | 2 | screen: 2 laws | killed |
| C10 | `num.go` 2n | `e` may come first | 1 | screen: `golden_usage_cluster_digit` | killed |

"Screen" rows rest on the pre-screen alone (`r27/lawscreen.py`, round 26's with paths changed: 415 parsable closed `C.run_pure` laws run on the mutant binary; the unmutated binary fails only `encode_plain_string_bytes`, a parse artefact). There is no separate proof for them.

Item 3 of the brief (dispatches no law pins): pinned by NEITHER a law nor a case are the three-digit threshold of the flatten-depth budget, the third byte of the BOM test, the container weight of an inline array and of a hyphen-line item object at the limit of 127, the enclosing prefix under a partial fold, the `last_e` reset in `num.go`, and the zero-mantissa exponent overflow reached by a `0` digit (R27-3). Pinned by the corpus only are the nested sibling set, the weight of a list body, the array step of the expansion counter, and the fraction-zero `nz` flag (R27-4).

## Round 26's repairs (item 0)

| R26 finding | this round |
|---|---|
| R26-1 (report reader) | holds for NFKC: the raw text is parsed, and fullwidth fences and pipes no longer change the structure. It does not hold for inline HTML: text between `<del>`/`<s>`/`<strike>`/`<span hidden>` tags is read as visible text, while `~~…~~` is dropped (see **R27-1**) |
| R26-2 (reachability) | holds for duplicate keys. The decode is all-or-nothing per file, so one unparseable line puts the whole file back on the raw path, where `\u` escapes hide a commit again (see **R27-2**) |
| R26-3 / R26-4 / R26-5 | the ten cases, 657 laws, M96-M103 and the README split are in the tree (`law-coverage.sh`, `claims-audit.py` agree; README 41 + 616 = 657 matches my count of `port/LAWS.bend`: `657 quantified 41 golden 295 closed 616`). NEW neighbouring-arm mutants: 7 survive everything (**R27-3**) and 5 are corpus-only (**R27-4**). I did not re-run `hand-mutants.py M96-M103` |

## Clean areas: compared executions of the UNMUTATED port

| lens (script, seed) | target | executions | diffs |
|---|---|---|---|
| `gen27.py fold` 27001 (3000), 27201 (1500, t8 + `TOON_SPEC=1`) | item 1: key folding over keys a, b, a.b, b.c, a.b.c, `é`, `1`, `a b`, `k.`, `.k`, `a..b` …, raw duplicate keys, depth 2-7, `--flatten-depth` in 31 spellings (0 … 18446744073709551616, `+3`, `-1`, `03`, `0x10`, spaces), indents, delimiters | 6000 + 3000 | 0 |
| targeted fold sweep | chains of 2-128 levels × flatten depth L-1, L, L+1, 99-101, 127-129, 1000, with and without a root literal | 428 | 0 |
| flatten-depth words | 30 words × with/without folding × `--flatten-depth W` / `--flatten-depth=W` | 240 | 0 |
| `gen27.py empty` (all) | item 1: 39 empty, whitespace-only, BOM, NEL, U+3000, VT/FF, `-`, `:`, `[0]:` … documents × 15 modes (decode, lenient, expand, indent 0/1/4, stats, auto, `-`, `-o -`, encode, fold) | 1170 | 0 |
| `gen27.py delim` 27001, 27201 | item 1: `--delimiter` in every spelling on encode with keys and values made of `, \| TAB : space - " [ ] { } #` in tables, lists, inline arrays, folding | 6000 + 3000 | 0 |
| `gen27.py uws` 27001, 27201 | item 1: 22 Unicode White_Space and near-whitespace characters in 23 key/value/header/row/item positions of TOON, 4 decode modes | 6000 + 3000 | 0 |
| `gen27.py keyesc` 27001, 27201 | items 1-2: every C0, DEL, U+0080-U+009F, U+2028/9, BOM, NBSP, `"`, `\`, `/` and 17 TOON escapes (`A`, `\ud800`, `\udc00`, a pair, `\b`, `\f`, `\/`, `\0`, `\x41`, …) in keys (plain, tabular field, list-item, dotted) and values through both JSON writers; JSON `\u` escapes of the same set in keys through encode | 6000 + 3000 | 0 |
| `gen27.py printer` 27001, 27201 | item 2: 47 boundary numbers (1e21, 1e-7, -0, 5e-324, 2.4e-324, 1.7976931348623157e308 and its neighbours, 2^53+1, 1e309, 1e-400, …) in 5 JSON and 6 TOON shapes | 6000 + 3000 | 0 |
| `gen27.py deep` 27001 (400), 27201 (1500) | item 2: nesting 120-131 and 200 in objects, dotted keys, list chains, keyed arrays, tabular bodies, JSON objects/arrays/mixed | 800 + 3000 | 0 |
| nesting-limit boundary | the original's limit for list, inline, tabular, empty list, list-item object and nested list-item array (L = 123-128) | 36 (original only; used to build N17-N19 inputs) | - |
| `jsonerr27.py` 27301 | JSON with multibyte text, surrogate escapes, whitespace, numbers: every truncation, 150 random insertions, deletions and replacements per base, 3 encode modes | 2350 | 0 |
| input files | 21 paths (extensions `.toon`, `.TOON`, `.json.toon`, none, `.toon` alone, directory, unreadable, dangling link, invalid UTF-8, empty, Unicode names) × 8 option sets incl. `-o` to a directory / missing dir | 336 | 0 |
| `diff-fuzz.py` mutate/docs/argv/expand/collide 270001 (4000 each, t1), 270002 (2000 each, `--switch TOON_SPEC=1`, t8) | repository lenses, new seeds | 30,000 inputs (every log `"differences": 0 … "verdict": "PASS"`) | 0 |
| `diff-fuzz.py numbers` 270003 (`--runs 40000 --switch TOON_SPEC=1`), `scale` 270004 (t1), 270005 (`--switch`, t8) | `"number_literals": 40000`; scale `"too_slow": 0` | 200 + 20 + 20 inputs | 0 |
| **JS lane** | `gen27.py` fold/uws/delim/keyesc/printer 27101 (400 each), deep 27101 (150), empty (585); `diff-fuzz.py` mutate/docs/expand 270101 (400 each), argv 270101 and 270102 (400 each); every R27-3/R27-4 distinguishing input | 5,470 + 2,000 inputs + 13 | 0 |
| **interpreter lane** (`r27/interp27.py`) | 13 inputs: the 10 distinguishing inputs of R27-3/R27-4 with an input, a whitespace-only document, a quoted key with escapes under expansion, folding with pipe-delimited keys | 26 | 0 |

The first JS `argv` run (seed 270101) printed 13 differences, all on argv that BEGIN with `--`. I ran the port command as `js-lane.py toon.js` without the launcher's own `--`, so `js-lane.py` consumed the program's `--` as documented ("The optional first -- belongs to this launcher"). Re-run with `js-lane.py toon.js --`, the same seed gives `"differences": 0`, and so does seed 270102. This is my harness error, not a finding.

Total compared executions of the unmutated port against the original: about 53,300 native from my generators, 30,240 `diff-fuzz` inputs (at least 60,480 executions) plus 40,000 number literals, about 5,470 JS executions from my generators plus 2,000 `diff-fuzz` inputs on JS, and 26 on the interpreter. The mutant runs only classify mutants and are not counted: 27 corpus runs, `lawscreen.py` on 19 binaries, and 10 proofs (P1, P2 and P5-P10 each stopped at a law; P3 and P4 checked).

## What this round did NOT cover

- A whole proof of the UNMUTATED tree. P3 and P4 ending in `All terms check.` imply that the unmutated laws check. Also not run: single proofs of each R27-3 / R27-4 mutant (only the groups), `lanes.sh`, `port-doctor.sh`, `floor.sh`, `stdio-probe.py`, `harness-selftest.sh`, `hand-mutants.py` for any id, and any performance measurement
- Screen-killed mutants (E5, E7, E8, E9, D1, D3, NA, NB, C10) were not confirmed by a proof
- c-8t beyond the t8 + spec seeds; the JS lane beyond the runs above; inputs above about 100 KB (the scale lens at 20)
- `f64.bend` printer mutants and `bignat.bend` mutants; clap similarity (`jaro`) mutants; decoder header-parser (`hdr.*`) mutants beyond the inventory
- Review-report layouts beyond inline HTML (not tried: `<details>`, which is declared out of reach, and reference-style links). Reachability shapes beyond the four above
- DOCUMENT review beyond the README law split and the repository gates' own counts (0 findings)

## Process notes (RULE 1)

- I deleted NO file. Planted reports and evidence files were moved with `os.rename` into `/data/tmp/review_R27/moved/`. The clone was restored with `git checkout` after every plant (`git status --short` shows only `?? oracle`). The mutant working copy `mport/` was restored to the original text after every build and proof (`mport restored: IDENTICAL`, `restored=IDENTICAL` on every proof line).
- One background command of mine (a Python law count with a regex that backtracked) was stopped with TaskStop. It wrote nothing, and its output is not cited. It was replaced by a line-based count.
- Nothing under `/data/projects/toon_bend` or `/dp/toon_rust` was modified. `/tmp/bend` was not updated.

## Artifacts

Everything is under `/data/tmp/review_R27/`:

- `bin/toon`, `bin/toon.js`, `clone/` (the reviewed tree plus the `oracle` link), `mport/` (restored working copy), `mut/<id>/toon`, `mut/results.jsonl`, `moved/`
- scripts in `r27/`: `cmp.py`, `gen27.py`, `dist.py`, `jsonerr27.py`, `m27defs.py`, `mut27.py`, `proofgrp27.py`, `peel27.sh`, `lawscreen.py`, `interp27.py`, `decoy27.py`, `reach27.py`, `dfchain.sh`, `dfjs.sh`, `reports/`
- logs in `r27/`: `decoy27.log`, `decoy27_control.log`, `reach27.log`, `mut27_a.log`, `mut27_b.log`, `proofs27.log`, `proof_P*.out`, `screen27.log`, `js_t8.log`, `df_*.log`
