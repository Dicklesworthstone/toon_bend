# Round 24: non-author hostile review of toon_bend

| field | value |
|---|---|
| reviewed commit | `4dd7812fe4c835f4e69906fe47cc6aa915a415fe` (fresh clone `/data/tmp/review_R24/clone`; `git rev-parse HEAD` printed that hash, the expected `4dd7812`) |
| original | `oracle/toon` -> `/data/projects/toon_bend/oracle/toon`, sha256 `821287eaf1a6d320ee1ef7604e74e3cefaa42b69445c96abb9dd310782d04030`, equal to `docs/PIN.toml` |
| Bend | `bun /tmp/bend/bend2/main.ts`, `/tmp/bend` at `15ae0c86f3193b8f645b4bedbc438655b648d0da`, `BEND_NO_TELEMETRY=1` |
| tools | bun 1.4.2, Ubuntu clang 21.1.8, Python 3.14.4, markdown-it-py 3.0.0 (only to show what a report renders as) |
| port binaries | native `/data/tmp/review_R24/bin/toon` (21.7 s wall, exit 0); JS `/data/tmp/review_R24/js/toon.js` (exit 0), run through `scripts/js-lane.py` |
| unmutated corpus | `./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t -- ../bin/toon --threads 1 --` -> `'passed': 1083, 'failed': 0, 'inconclusive': 0, 'stderr_compared': True, 'verdict': 'PASS', 'oracle_identity_checked': True` |
| repo gates on this tree | `converge.sh` -> `"rounds": 23, "clean": 5, "clean_tail": 0 … "verdict": "NOT_CONVERGED"`; `claims-audit.py` -> `"findings": 0 … "laws": 629, "cases": 1083 … "verdict": "OK"` |
| host | shared, 8 cores, 30 GB. 01:15 load 0.9, 24 GB available, 15 GB disk free; load peaked near 10 during my mutant builds + fuzzing (01:27), 1.9 at 02:15. Every Bend build and proof started only at >= 12 GiB `MemAvailable`, one at a time, inside `systemd-run --user --scope -p MemoryMax=10G -p MemorySwapMax=0`; none was killed. Proof peaks (`/usr/bin/time -v`): 2.9-3.4 GB. Disk used by this round: 135 MB |
| harness | `r24/cmp.py` (round 23's, paths changed) runs `./oracle/toon ARGV` and `bin/toon --threads T -- ARGV` (or the JS lane) on the same stdin, compares stdout, stderr, exit byte for byte, with `TOON_SPEC` removed unless set. `r24/tri.py` adds a mutant binary. "Executions" counts every run of either program |

## Findings (counting rule of 2026-09-23, rules 1-6)

| id | sev | class | what | spec |
|---|---|---|---|---|
| R24-1 | MEDIUM | BEHAVIOR (gate that lies; NEW, in R23-1/R23-2's repair) | `scripts/review_report.py` reads Markdown as plain lines. It reads a findings table that no reader sees (inside an HTML comment, a code fence or an indented code block) and it ignores the findings table a reader does see when that table's header says `finding` / `severity` instead of `id` / `sev`. It then counts zero. With two planted rows `24` and `25` (`0 \| 0 \| yes`, non-author), each report's only visible table lists `R2x-1 \| HIGH \| BEHAVIOR`, and an HTML comment holds a decoy `R2x-1 \| LOW \| DOCUMENT` table. `converge.sh` prints `"verdict": "CONVERGED"`, `claims-audit.py` prints `"findings": 0 … "verdict": "OK"` and `state-check` prints `0 finding(s)`. The control (the same finding under an `id` header, no decoy) is caught by both gates. The docstring promises "fails CLOSED: a report it cannot read completely is an error, never a zero" and accepts tables that are "indented or not". A table indented four spaces is a code block, not a table | PARITY-GATE rules 1, 6; PORT_STATE "Owner decisions" |
| R24-2 | LOW | BEHAVIOR (gate that lies; R23-3's repair, new shapes) | The claim is that `claims-audit.py`'s reachability "fails CLOSED over EVERY file under perf/evidence/". With the unreachable `494ef82` planted, all of these print `0 … OK`: a symlinked subdirectory `perf/evidence/archive -> …` holding `COUNTED.canada.decode.494ef82.json` with `after.commit = 494ef82` (`os.walk` does not follow directory links; control: a real subdirectory -> `2 FINDINGS`); a file NAMED `COUNTED.canada.decode.494ef82.json` whose own content has a `binary_sha256` of 64 hex digits that starts with `494ef82` (a file name only needs a 7-digit prefix of any recorded digest; control without the digest -> `1 FINDINGS`); `"commit": 8913e45` unquoted (valid JSON, read as the number 8.913e48; quoted control -> `1 FINDINGS`); `"0x494ef82"`; `494ef82` followed by 34 more hex digits (runs over 40 digits are never read). None of these shapes is in a committed file today. None is the declared residual (a 12- or 16-digit commit stored as a digest-named value) | (claims) |
| R24-3 | MEDIUM | BEHAVIOR (corpus gap; ONE finding against `scripts/hand-mutants.py`: no site is in its inventory) | Three NEW hand mutants each survive the whole corpus on c-1t (1083 of 1083 pass) AND the whole 629-law `PROOF.bend`, alone (`All terms check.`, 430-432 s each) and together (group P1, 443 s). H10: `hdr.c.colon` also takes `;` as the header colon, so `a[1]{x};` + a row decodes (exit 0). The original fails with `Missing colon after key` (exit 1). H11: `hdr.c.fields` no longer skips whitespace between `}` and `:`, so `a[1]{x} :` fails where the original decodes `{"a":[{"x":1}]}`. H13: `field.put` drops the quoted flag of a quoted field name, so `[1]{"a.b",c}:` under `--expand-paths safe` expands `a.b` into `{"a":{"b":1}}`. The original keeps `"a.b": 1`. The unmutated port equals the original on all of these inputs, native and JS | S2.133 (amended: only White_Space between `}` and `:`), S2.132, S2.137, S3.27 |
| R24-4 | LOW | LAW-COVERAGE (ONE finding against `scripts/hand-mutants.py`) | Eight NEW mutants are killed by the corpus on c-1t but by NO law (all eight together, group P2: `All terms check.`, 431 s; the law pre-screen names no law for any of them). U5-U8: `unesc.tr` reads `\t`, `\"`, `\\`, `\n` in a quoted KEY as space, `'`, `/`, CR (round 23 pinned only `\r`, the value side is pinned by `decode_literal_five_escapes`). H14: `field.first` flags a bare field name as quoted, so dotted field names stop expanding. F4: `fctx.item` gives a list item's body budget - 1. F5: `fc.can` needs budget 3, so `--flatten-depth 2` never folds. KF1: `key_first` refuses `A` as the first character. Each is caught by 1 to 7 cases (F4 by `enc_fold_budget_reset_in_list` ALONE, U7 only by the two `jsonout_escape_keys*` cases) | S2.123, S2.137/S3.27, S4.73, S4.64, S4.21 |

Count under the rule: **BEHAVIOR 3 (MEDIUM 2, LOW 1), LAW-COVERAGE 1 (LOW), DOCUMENT 0.** NEW behavior findings of MEDIUM or above: **2** (R24-1, R24-3). This round is NOT clean. On every lane I tried, I found **no difference between the UNMUTATED port and the original**: about 219,600 native executions from my own generators and hand inputs, 30,000 `diff-fuzz` inputs with new seeds (plus 40,000 number literals and 40 scale inputs), about 28,300 on the JS lane and 22 on the interpreter (tables below).

### R24-1 reproduction

`python3 /data/tmp/review_R24/r24/decoy.py VARIANT` works in a second clone `/data/tmp/review_R24/gates`. It appends row 24 (`0 | 0 | yes`, non-author) and writes `docs/reviews/round-24.md`, whose visible findings table lists `R24-1 | HIGH | BEHAVIOR`. It then runs `review_report.py`, `converge.sh` and `claims-audit.py`, and renders the report with markdown-it (GFM tables, HTML on) to show what a reader sees. Afterwards it restores PORT_STATE with `git checkout` and moves the report aside into `gates_moved/`; nothing is deleted. From `r24/decoy.log`:
```
=== variant control        (header `| id | severity | class | what | spec |`, no decoy)
review_report.py rc=0: {... "rows": [{"id": "R24-1", "sev": "HIGH", "class": "BEHAVIOR"}], "counted": 1, "errors": []}
converge.sh round-24 lines: ['  missing: round 24: the table says 0 counted finding(s), docs/reviews/round-24.md lists 1', ...]
=== variant comment        (decoy `| id | sev | class |` table inside <!-- -->, visible table headed `| finding | severity | class |`)
review_report.py rc=0: {... "rows": [{"id": "R24-1", "sev": "LOW", "class": "DOCUMENT"}], "counted": 0, "errors": []}
converge.sh round-24 lines: NONE
RENDERED table rows (markdown-it, GFM tables): [['field', 'value'], ['reviewed commit', ...], ['finding', 'severity', 'class', 'what', 'spec'], ['R24-1', 'HIGH', 'BEHAVIOR', 'the port prints X where the original prints Y', 'S4.1']]
RENDERED non-table blocks: [('html_block', '<!--\n| id | sev | class | what | spec |\n|---|---|---|---|---')]
=== variant fence          (decoy inside ``` ... ```)          -> "counted": 0, "errors": [], converge round-24 lines: NONE; rendered: ('fence', ...)
=== variant indented       (decoy indented four spaces)       -> "counted": 0, "errors": [], converge round-24 lines: NONE; rendered: ('code_block', ...)
```
In the fourth variant, `details` (the decoy inside `<details>`), both tables render, so it is not counted here.

Full gate run: `python3 /data/tmp/review_R24/r24/decoy2.py`. It adds rows 24 and 25 with comment-decoy reports and refreshes the prose summaries the way R22/R23 did ("6 to 23" -> "6 to 25", "9 to 23" -> "9 to 25", the count list extended by ", 0 and 0", the pasted converge line replaced). From `r24/decoy2.log`:
```
$ python3 scripts/review_report.py docs/reviews/round-24.md 24   (rc=0)
{"commit": "4dd7812fe4c835f4e69906fe47cc6aa915a415fe", "rows": [{"id": "R24-1", "sev": "LOW", "class": "DOCUMENT"}], "counted": 0, "errors": []}
$ python3 scripts/review_report.py docs/reviews/round-25.md 25   (rc=0)
{"commit": "4dd7812fe4c835f4e69906fe47cc6aa915a415fe", "rows": [{"id": "R25-1", "sev": "LOW", "class": "DOCUMENT"}], "counted": 0, "errors": []}
$ ./scripts/converge.sh docs/PORT_STATE.md   (rc=0)
tier T2: rounds 25, clean 7, clean tail 2, last two clean True, non-author round True, open OQ 0, open DISC 0
convergence: CONVERGED
{"tier": "T2", "rounds": 25, "clean": 7, "clean_tail": 2, "last_two_clean": true, "non_author_round": true, "open_oq": [], "open_disc": [], "unfixed": [], "verdict": "CONVERGED", "missing": []}
$ python3 scripts/claims-audit.py   (rc=0)
{"files": 16, "absent": [], "findings": 0, "historical_lines_exempt": 6, "laws": 629, "cases": 1083, "disc": {"accepted": 11, "resolved": 4, "open": 0}, "verdict": "OK"}
$ ./scripts/state-check.sh docs/PORT_STATE.md   (rc=0)
state-check: 0 finding(s)
after restore: ?? oracle
```
This needs a report author who hides a table, which is the same fabrication vector as R23-1(b), the look-alike hyphen. It is not the declared limit. That limit covers a *complete, well-formed* report. These reports are malformed: the visible findings table has no `id`/`sev` header, and the table that does is invisible. Fix direction: strip HTML comments, fenced code and indented code blocks before looking for tables. Require the delimiter row's cell count to equal the header's, as GFM does. Refuse a report with any rendered table whose rows carry `R<n>-<k>` ids but which is not the findings table.

### R24-2 reproduction

`python3 /data/tmp/review_R24/r24/reach24.py` plants one shape at a time in the gates clone and runs `claims-audit.py`. It restores edits with `git checkout` and moves planted files and links aside into `gates_moved/`, never deleting. `git status --short` afterwards shows only `?? oracle`. From `r24/reach24.log`:
```
== A control after.commit = C                                 "findings": 1 "verdict": "FINDINGS"} | ['perf/evidence/COUNTED.canada.decode.json:0: the hex run 494ef82 is not a commit HEAD contains, ...']
== C name .C.json, own content sha256 = C+57 hex              "findings": 0 "verdict": "OK"} | []
== D control for C: same file without the digest              "findings": 1 "verdict": "FINDINGS"} | ["perf/evidence/COUNTED.canada.decode.494ef82.json:0: the file name's hex run 494ef82 is not ..."]
== E symlinked subdirectory holding after.commit = C          "findings": 0 "verdict": "OK"} | []
== F control for E: a real subdirectory, same file            "findings": 2 "verdict": "FINDINGS"} | [...]
== G after.commit = 8913e45 unquoted (a JSON number)          "findings": 0 "verdict": "OK"} | []
== H control for G: quoted '8913e45'                          "findings": 1 "verdict": "FINDINGS"} | []
== I commit after 0x: '0x494ef82'                             "findings": 0 "verdict": "OK"} | []
== J commit inside a >40-hex run (C + 34 hex)                 "findings": 0 "verdict": "OK"} | []
```
Both `494ef82` and `8913e45` are unknown to toon_bend, toon_rust and bend (`git cat-file -t` prints `fatal: Not a valid object name`). Fix direction: `os.walk(..., followlinks=True)`, or refuse links. Exempt a file-name prefix only through a digest recorded in ANOTHER file, or not at all. Read the raw text as well as the re-dumped JSON. Read hex runs of any length.

### R24-3 reproductions (the original, the unmutated port and the mutant on the same input; `r24/tri.py`)

```
H10 port same mut DIFF | ['--decode'] b'a[1]{x};\n  1\n'
   orig: (b'', b'Failed to decode TOON: Missing colon after key\n', 1)
   mut:  (b'{\n  "a": [\n    {\n      "x": 1\n    }\n  ]\n}\n', b'', 0)
H11 port same mut DIFF | ['--decode'] b'a[1]{x} :\n  1\n'
   orig: (b'{\n  "a": [\n    {\n      "x": 1\n    }\n  ]\n}\n', b'', 0)
   mut:  (b'', b'Failed to decode TOON: Missing colon after key\n', 1)
H11 port same mut DIFF | ['--decode'] b'a[1]{x}\t:\n  1\n'
   (same two results)
H13 port same mut DIFF | ['--decode', '--expand-paths', 'safe'] b'[1]{"a.b",c}:\n  1,2\n'
   orig: (b'[\n  {\n    "a.b": 1,\n    "c": 2\n  }\n]\n', b'', 0)
   mut:  (b'[\n  {\n    "a": {\n      "b": 1\n    },\n    "c": 2\n  }\n]\n', b'', 0)
```
Mutant texts (`r24/mut24.py`; each applied to the one working copy `r24/mport/` and restored after its build: `mport restored: IDENTICAL`):
- H10 `decode.bend` `hdr.c.colon`: `hdr.c.colon.if(U32.is_eq(c, 58),` -> `hdr.c.colon.if(Bool.or(U32.is_eq(c, 58), U32.is_eq(c, 59)),`
- H11 `decode.bend` `hdr.c.fields`: `hdr.c.colon(ascii_ws.go(after, ascii_ws.cls(after)), quoted` -> `hdr.c.colon(after, quoted`
- H13 `decode.bend` `field.put`: `FROk{Field{s, True{}} <> rev}` -> `FROk{Field{s, False{}} <> rev}`

Corpus (`r24/mut/results.jsonl`): H10, H11 and H13 each `"passed": 1083, "failed": 0`. Law pre-screen (`r24/lawscreen.py`, round 23's, which runs each of the 388 parsable closed `C.run_pure` laws on the mutant binary): no law besides `encode_plain_string_bytes`, which the screen also names for the UNMUTATED binary (a parse artefact). Whole proofs (`r24/proofs24.log`):
```
P1 H10,H11,H13 PROOF rc=0 secs=443 Maximum resident set size (kbytes): 3391552 last: ['All terms check.']
S_H10 H10 PROOF rc=0 secs=432 Maximum resident set size (kbytes): 2924292 last: ['All terms check.']
S_H11 H11 PROOF rc=0 secs=430 Maximum resident set size (kbytes): 3297964 last: ['All terms check.']
S_H13 H13 PROOF rc=0 secs=432 Maximum resident set size (kbytes): 3255872 last: ['All terms check.']
```
Fix direction: goldens and laws for a non-colon, non-whitespace character after `}` (`;`, `=`, a letter), for spaces and a TAB between `}` and `:` (S2.133's amendment says only White_Space may stand there; `toonerr_header_spaces` covers only `]`), and for a quoted dotted field name under `--expand-paths safe` (S3.27 names `fx_dec_path_expansion_10` and `jsonout_expand_in_arrays`, and neither has a quoted field that contains a dot). Add the three sites to `hand-mutants.py`.

### R24-4 reproductions (the unmutated port equals the original on every row; `r24/tri_lc.log`)

```
U5 ['--decode'] b'"a\\tb": 1\n'    orig: {"a\tb": 1}      mut: {"a b": 1}
U6 ['--decode'] b'"a\\"b": 1\n'    orig: {"a\"b": 1}      mut: {"a'b": 1}
U7 ['--decode'] b'"a\\\\b": 1\n'   orig: {"a\\b": 1}      mut: {"a/b": 1}
U8 ['--decode'] b'"a\\nb": 1\n'    orig: {"a\nb": 1}      mut: {"a\rb": 1}
H14 ['--decode','--expand-paths','safe'] b'[1]{a.b}:\n  1\n'   orig: [{"a":{"b":1}}]   mut: [{"a.b":1}]
F4 ['--encode','--key-folding','safe','--flatten-depth','2'] {"a": {"b": [{"x": 1, "c": {"d": {"e": 1}}}]}}
   orig: a.b[1]:\n  - x: 1\n    c.d:\n      e: 1\n     mut: a.b[1]:\n  - x: 1\n    c:\n      d:\n        e: 1\n
F5 ['--encode','--key-folding','safe','--flatten-depth','2'] b'{"a":{"b":1}}'   orig: a.b: 1   mut: a:\n  b: 1
KF1 ['--encode'] b'{"Ab":1}'   orig: Ab: 1   mut: "Ab": 1
```
Proof: group P2 = U5 U6 U7 U8 H14 F4 F5 KF1, `P2 … PROOF rc=0 secs=431 Maximum resident set size (kbytes): 3016204 last: ['All terms check.']`. Failing cases per mutant on c-1t: U5 3, U6 3, U7 2, U8 3, H14 5, F4 1, F5 7, KF1 2 (names in `r24/mut/results.jsonl`).

## Mutant table (all 29 mutants of this round)

Each mutant is one exact-text replacement (`r24/mut24.py`, `r24/mut/<id>/diff.txt`). Each was built natively (memory-gated) and run through the whole corpus on c-1t. Corpus-killed mutants were screened by `r24/lawscreen.py`. Mutants the screen named no law for went into whole proofs.

| id | def | change | corpus c-1t failing | law | verdict |
|---|---|---|---|---|---|
| H10 | `hdr.c.colon` | `;` is the header colon | 0 | none (whole, alone and P1) | **R24-3** |
| H11 | `hdr.c.fields` | no whitespace between `}` and `:` | 0 | none (whole, alone and P1) | **R24-3** |
| H13 | `field.put` | quoted field name loses its flag | 0 | none (whole, alone and P1) | **R24-3** |
| U5 | `unesc.tr` | key `\t` -> space | 3 | none (P2) | **R24-4** |
| U6 | `unesc.tr` | key `\"` -> `'` | 3 | none (P2) | **R24-4** |
| U7 | `unesc.tr` | key `\\` -> `/` | 2 | none (P2) | **R24-4** |
| U8 | `unesc.tr` | key `\n` -> CR | 3 | none (P2) | **R24-4** |
| H14 | `field.first` | bare field flagged quoted | 5 | none (P2) | **R24-4** |
| F4 | `fctx.item` | list-item budget - 1 | 1 | none (P2) | **R24-4** |
| F5 | `fc.can` | depth 2 never folds | 7 | none (P2) | **R24-4** |
| KF1 | `key_first` | `A` cannot start a key | 2 | none (P2) | **R24-4** |
| H12 | `hdr.c` | no whitespace after `]` | 1 | screen: `golden_toonerr_header_spaces` | killed |
| H15 | `all_digits.go` | `9` not a digit | 18 | screen: 6 laws incl. `golden_toonerr_huge_length` | killed |
| H16 | `len.mark` | pipe header selects comma | 13 | screen: `golden_toonerr_mixed_delims` +2 | killed |
| H17 | `len.canon` | all-zero length is 1 | 37 | screen: 9 laws incl. `golden_jsonout_root_empty_array` | killed |
| I2 | `is_row.of` | colon-first is the row | 2 | screen: `golden_toonedge_data_row_test` | killed |
| E1 | `bad_char` | TAB does not force quotes | 7 | screen: `tab_in_value_forces_quotes` | killed (= inventory M26) |
| E2 | `bad_char` | `}` does not force quotes | 1 | screen: `encode_brackets_and_braces_force_quotes` | killed |
| E3 | `bad_char` | `{` does not force quotes | 2 | screen: same | killed |
| E4 | `bad_char` | CR does not force quotes | 3 | screen: `cr_in_value_forces_quotes` | killed |
| E5 | `bad_char` | `[` does not force quotes | 1 | screen: `encode_brackets_and_braces_force_quotes` | killed |
| F1 | `fold.check` | root-literal collision ignored | 4 | screen: `golden_fx_enc_key_folding_05`, `golden_enc_fold_root_literal_nested` | killed |
| F2 | `fold.check` | sibling collision ignored | 3 | screen: `golden_enc_fold_list_item_dup_key` | killed |
| F3 | `segs_ok.go` | dotted segment may fold | 2 | screen: `golden_enc_folding_collision`, `golden_encstr_fold_hash_collision` | killed |
| C1 | `--delimiter` word | literal TAB word invalid | 13 | screen: `golden_fx_enc_delimiters_01` +2 | killed |
| C2 | `--delimiter` word | `pipe` invalid | 4 | screen: `golden_flag_delimiter_word_pipe` | killed |
| W1 | writer `w.ch_a` | TAB as `\u0009` | 13 | screen: `decode_literal_five_escapes` +3 | killed |
| W2 | writer `w.ch_a` | CR as `\n` | 5 | screen: `decode_quoted_key_cr_escape` +2 | killed |
| W3 | `w.colon` | `--indent 0` writes `: ` | 10 | screen: `golden_flag_decode_indent_0` +2 | killed |

Screen-killed rows rest on the pre-screen: the law's own argv and bytes give a different result on the mutant binary. There is no separate proof for each.

Item 3 of the brief (dispatches no law pins): pinned by NEITHER a law nor a case are `hdr.c.colon`'s colon test, `hdr.c.fields`' whitespace skip and `field.put`'s quoted flag (R24-3). Pinned by the corpus only are `unesc.tr`'s other four key escapes, `field.first`'s unquoted flag, `fctx.item`'s budget reset, `fc.can`'s threshold and `key_first`'s `A` (R24-4). The rest in the table are pinned by a law.

## Round 23's repairs (item 0)

| R23 finding | this round |
|---|---|
| R23-1 (empty report, look-alike hyphen) | holds for those shapes. From round 20 every row needs a report that parses, and an empty file is `the report is empty`. The report can still be read wrongly: a hidden decoy table (**R24-1**) |
| R23-2 (layouts read as zero) | holds for the 16 layouts R23 named. Header-located columns, markup stripping and every named id having a row all bite (my `control` variant is counted 1). The reader does not know what Markdown hides or renders (**R24-1**) |
| R23-3 (reachability shapes) | holds for R23's shapes A-R (the brief's list); my control A is caught. Five further shapes are not read (**R24-2**) |
| R23-4 / R23-5 (corpus gaps, law coverage) | holds for the sixteen sites. The five cases and thirteen laws are in the tree (629 laws, 1083 cases, both gates agree). Neighbouring arms: `unesc.tr`'s other key escapes, `field.first`, `hdr.c.colon`, `hdr.c.fields`, `field.put` (**R24-3**, **R24-4**). I did not re-run `hand-mutants.py M60-M73` (each run is a reduced proof per mutant) or `harness-selftest.sh` M20-M22 |

## Clean areas: compared executions of the UNMUTATED port

| lens (script, seed) | target | executions | diffs |
|---|---|---|---|
| `lens24.py fold` 24001 (300), 24101 (3000, t1), 24102 (1500, t8 + `TOON_SPEC=1`), 24201 (10000) | item 1: single-key chains of 1-5 keys drawn from 45 keys (quoting-needing: spaces, dots, colons, quotes, `\`, delimiters, TAB, LF, U+2028, digits-first, empty, `true`, `12`), half with a dotted sibling that collides after folding; random nested docs; `--key-folding safe/off`, `--flatten-depth` 0-5, 100, 2^64, -1, `01`; delimiters; indents | 600 + 6000 + 3000 + 20000 | 0 |
| `lens24.py foldrt` same seeds | the original's folded TOON (depths 0-4) decoded with `--expand-paths safe` ± `--no-strict` | 600 + 6000 + 3000 + 20000 | 0 |
| `lens24.py num` same seeds | item 1/2: decimals near every Display boundary (m·10^e for e in -9..23, random bit patterns, 29 fixed boundary texts incl. 1e21, 9.999999999999999e20, 5e-324, 2^-1075 neighbours, max double, 2^53+1, 2^64, random 1-20 digit mantissas with exponents), both directions, 5 shapes | 600 + 6000 + 3000 + 20000 | 0 |
| `lens24.py stats` same seeds + `stats24.py` (7,800 inputs of swept sizes) | `--stats` percent rounding; `r24/stats_ties.py` confirmed 10 exact .x5 ties in three of the families (e.g. `(16, 15, 6.25, 'Saved ~1 token (-6.3%)')`, `(80, 41, 48.75, … (-48.8%))`) | 600 + 6000 + 3000 + 20000 + 15600 | 0 |
| `lens24.py indent` same seeds | the original's encoding at `--indent` 1..16 with 0-3 lines retabbed (all tabs, one tab, tab mid-indent, mixed), decoded at the same or another indent 0-16, 75% `--no-strict`, 20% expansion | 600 + 6000 + 3000 + 20000 | 0 |
| `out24.py` | `-o` into a directory (`adir`, `adir/`, `.`), missing parent, read-only dir and file, `-`, empty, `--`, the input itself, `/dev/full`, `/dev/null`, `/proc/self/status`, a dangling symlink, a symlink to a dir, a 300-char name, a name with a backtick and LF, non-ASCII; failures before writing; `--stats`; the file's state afterwards compared too | 84 | 0 |
| `jw24.py` | item 2 exhaustive: code points U+0000-U+02FF + 13 others × 8 positions (raw value, quoted value, quoted/bare/dotted keys, inline, field name) × 4 decode modes (plain, expand, `--indent 0`, lenient+expand+compact); 18 escapes incl. `\u` forms (the original refuses: `Invalid escape sequence: \u`); 8 invalid UTF-8 sequences incl. surrogate encodings; 33 number texts at printer boundaries; nesting 118-135 | 51768 | 0 |
| `hand24.py` | 17 flatten depths × 20 fold documents; 32 header/field edge inputs × 4 modes; 12 quote-forcing characters × 6 delimiter spellings; key-first letters | 1792 | 0 |
| `depthgrid.py` + two deep probes | expansion depth: indentation depth 0-127 × dotted segments around 127-d, 256, 257 (two different messages: `Nesting depth exceeds 127 levels after path expansion` and `Path expansion exceeded maximum depth of 256`); TOON nesting to 3000 (the original caps at 127); dotted keys of 126-40000 segments | 2304 + 80 | 0 |
| whitespace between `]`/`}` and `{`/`:` | U+00A0, U+3000, U+2028, VT, FF, U+0085, U+1680, mixed | 64 | 0 |
| `diff-fuzz.py` mutate/docs/argv/expand/collide 240001 (4000 each, t1), 240002 (2000 each, `--switch TOON_SPEC=1`, t8) | repository lenses, new seeds | 30,000 inputs (each log `"differences": 0 … "verdict": "PASS"`) | 0 |
| `diff-fuzz.py numbers` 240003 (`--runs 40000 --switch TOON_SPEC=1`), `scale` 240004 (t1), 240005 (`--switch`, t8) | `"number_literals": 40000`; scale `"too_slow": 0` | 200 + 20 + 20 inputs | 0 |
| **JS lane** | `lens24.py` five modes 24103 (300 each) and 24202 (1000 each), `jw24.py --js` (11,064), `hand24.py --js`, `out24.py --js`, `depthgrid.py --js`, the whitespace set, the deep probes | 3000 + 10000 + 11064 + 1792 + 84 + 2304 + 64 + 40 | 0 |
| **interpreter lane** (`r24/interp24.py`, `bun main.ts port/main.bend --`) | 11 inputs: the R24-3 inputs, a quoted-key `\t`, fold at depth 2 in a list, a stats tie size, lenient retab, 257 segments, `{`/`}` quoting, `\r` compact, the five printer boundaries | 22 | 0 |

Total compared executions of the unmutated port against the original: about 219,600 native from my generators and hand inputs, 30,240 `diff-fuzz` inputs (at least 60,480 executions) with 40,000 number literals, about 28,300 on JS and 22 on the interpreter. The mutant runs (29 corpus runs, `tri.py`, `lawscreen.py`, 5 proofs) only classify mutants and are not counted.

## What this round did NOT cover

- a WHOLE proof of the UNMUTATED tree. Each whole mutant proof that ended in `All terms check.` implies the unmutated laws check too. Also not run: `lanes.sh`, `port-doctor.sh`, `floor.sh`, `stdio-probe.py`, `harness-selftest.sh` (so M20-M22 were not re-run), `hand-mutants.py M60-M73`, and any performance
- single proofs of the eight R24-4 mutants (only group P2); screen-killed verdicts rest on the pre-screen
- c-8t beyond seeds 24102/240002/240005; the JS lane beyond about 28,300 executions; inputs above about 100 KB (except the deep probes, the largest about 4.5 MB); file operands other than the `-o` set
- the review-report reader beyond the five layouts of R24-1 (e.g. setext headings, HTML `<table>`, reference-style links in id cells); the reachability rule beyond the ten shapes of R24-2
- DOCUMENT review: none beyond reading `review_report.py`'s docstring (its "indented or not" is part of R24-1) and the counts both gates print (629 laws, 1083 cases); no DOCUMENT finding

## Artifacts

Everything is under `/data/tmp/review_R24/`: `bin/toon`, `js/toon.js`, `clone/` (the reviewed tree plus the `oracle` link), `gates/` (the second clone the gate scenarios ran in, restored), `gates_moved/` (planted reports and evidence files moved aside, never deleted). In `r24/`: `cmp.py`, `tri.py`, `lens24.py`, `stats24.py`, `stats_ties.py`, `out24.py` (+ `outw/`), `jw24.py`, `hand24.py`, `depthgrid.py`, `interp24.py`, `decoy.py` (+ `decoy.log`), `decoy2.py` (+ `decoy2.log`), `reach24.py` (+ `reach24.log`, `evlink/`), `mut24.py` (+ `mut24.log`, `mut/<id>/{toon,diff.txt}`, `mut/results.jsonl`), `mport/` (the working copy, restored identical), `lawscreen.py` (+ `screen.log`), `proofgrp.py` (+ `proofs24.log`, `pgroup/<name>/{port,proof.log}`), `tri_lc.log`, and the lens and diff-fuzz logs (`lens_*`, `js_*`, `df_*`).
