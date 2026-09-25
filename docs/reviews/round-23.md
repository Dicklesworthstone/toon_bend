# Round 23: non-author hostile review of toon_bend

| field | value |
|---|---|
| reviewed commit | `57c7b36a9d14fedf7b714463d55b485f70291231` (fresh clone `/data/tmp/review_R23/clone`; `git rev-parse HEAD` printed that hash, the expected `57c7b36`) |
| original | `oracle/toon` -> `/data/projects/toon_bend/oracle/toon`, sha256 `821287eaf1a6d320ee1ef7604e74e3cefaa42b69445c96abb9dd310782d04030`, equal to `docs/PIN.toml` |
| Bend | `bun /tmp/bend/bend2/main.ts`, `/tmp/bend` at `15ae0c86f3193b8f645b4bedbc438655b648d0da`, `BEND_NO_TELEMETRY=1` |
| tools | bun 1.4.2, Ubuntu clang 21.1.8, Python 3.14.4 |
| port binaries | native `bin/toon` (26 s, peak RSS 1.9 GB, exit 0); JS `js/toon.js` (2.9 s, exit 0), run through `scripts/js-lane.py` |
| unmutated corpus | `./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t -- ../bin/toon --threads 1 --` -> `"passed":1078,"failed":0,"inconclusive":0,"stderr_compared":true,"verdict":"PASS","oracle_identity_checked":true` |
| repo gates on this tree | `converge.sh` -> `"rounds": 22, "clean": 5, "clean_tail": 0 … "verdict": "NOT_CONVERGED"`; `claims-audit.py` -> `"findings": 0 … "laws": 616, "cases": 1078 … "verdict": "OK"` |
| host | shared, 8 cores, 30 GB. 18:31 load 2.5, 8 GB available (another session's `bend` job at 13 GB RSS); 18:35 11 GB; 18:37 19 GB; 19:54 load 2.1. Every Bend build and proof ran through `r23/build.sh` / `r23/proof.sh`: started only at >= 12 GiB `MemAvailable`, one at a time, inside `systemd-run --user --scope -p MemoryMax=10G -p MemorySwapMax=0` (a run killed there would be INCONCLUSIVE; none was). Proof peaks measured by `/usr/bin/time -v`: 2.5-3.4 GB |
| harness | `r23/cmp.py` (round 22's, paths changed) runs `./oracle/toon ARGV` and `bin/toon --threads T -- ARGV` (or, with `PORT_JS`, `python3 scripts/js-lane.py js/toon.js -- ARGV`) on the same stdin and compares stdout, stderr and exit byte for byte; `TOON_SPEC` is removed unless a run sets it. `r23/tri.py` adds a mutant binary. "Executions" counts every run of either program |

## Findings (counting rule of 2026-09-23, rules 1-6)

| id | sev | class | what | spec |
|---|---|---|---|---|
| R23-1 | MEDIUM | BEHAVIOR (gate that lies; NEW, in R22-1's repair) | R22-1's repair keys the "a non-author round needs its report" rule on two things the table author controls, and both let two fabricated `0 \| 0 \| yes` rows print CONVERGED again. (a) The report only has to EXIST: two EMPTY files `docs/reviews/round-23.md` and `round-24.md` (0 bytes) satisfy `converge.sh` (`os.path.isfile`) and `claims-audit.py` (`rid in f["reviews"]`); an empty report yields 0 counted rows, which equals the table's 0. (b) The rule fires only on the ASCII word `non-author` in the lens: with the lens written `independent hostile review (subagent, non‑author)` (U+2011 NON-BREAKING HYPHEN, indistinguishable on screen) and NO report file at all, neither gate asks for a report. With the prose summaries refreshed as R22-1 did (`r23/refresh.py`), both variants print `"verdict": "CONVERGED"`, the audit `"findings": 0 … "verdict": "OK"`, and `state-check: 0 finding(s)`. Control: the same rows with an ASCII hyphen and no report are named by both gates. The owner decision (PORT_STATE "Owner decisions": "two consecutive non-author rounds on the frozen tree are clean") is exactly what these rows fake | PARITY-GATE rules 1, 6; PORT_STATE "Owner decisions" |
| R23-2 | MEDIUM | BEHAVIOR (gate that lies; NEW, in R22-2's repair) | The counted-row reader of both gates recognises ONE layout only (`^\|\s*\*{0,2}R<n>-\d+`, then cells 2 and 3 as sev and class) and reads anything else as ZERO counted findings, which then "agrees" with a table row of 0. A report that lists a real `MEDIUM`/`BEHAVIOR` finding passes as clean when the finding row has: the columns reordered (`\| id \| class \| sev \|`), an extra column before sev (`\| id \| lane \| sev \| class \|`), the id in backticks, as a link, lower-case (`r23-1`) or dotted (`R23.1`), the sev in backticks, `_…_` or `<b>…</b>`, the class `BEHAVIORAL`, the table indented one space or written without leading pipes (both render as tables), the finding as a bullet, an escaped pipe in the id cell, or the three words not / a / finding in sequence anywhere in the row's prose (the exclusion is a row-wide regex: the first draft of THIS row quoted that phrase, and both gates then counted this report as 2 MEDIUM behavior findings instead of 3). 16 of 18 variants print `converge.sh` CONVERGED and audit `OK`; the control (the exact layout) and two variants (`R23-01`, a NBSP before `MEDIUM`) are caught. Neither gate refuses a report it cannot parse (no findings table, or a row it cannot read) | PARITY-GATE rules 1, 6 |
| R23-3 | LOW | BEHAVIOR (gate that lies; R22-3's repair, new shapes) | `claims-audit.py`'s reachability rule still misses unreachable commits in COUNTED evidence. With `494ef82` planted (control `after.commit = "494ef82"` -> `1 FINDINGS`), each of these prints `0 OK`: `"commit": {"id": "494ef82"}` and `{"hash": …}` (a key under a commit key is not "named"), keys `built_from` / `head`, values `"at 494ef82"`, `"toon_bend@494ef82"`, `"v494ef82"`, a 13-hex abbreviation `494ef82abcdef` (COMMIT_ID is 7-12 or 40 digits; git accepts any length >= 4), a path value `/scratch/frozen494ef82/toon` (the committed profile names its binary's tree this way: `frozenc5f3b46`), files named `COUNTED.….JSON`, `COUNTED-canada.….json`, `counted.….json`, `….ndjson`, a file under `perf/evidence/old/`, and the `.annot.txt` / `keep-audit.txt` files the counted profile rests on. No committed file has an unreachable commit in these shapes today (every 7-12-hex token in `perf/evidence/COUNTED*` that is a commit resolves: `f6cd68e cbdfba6 c5f3b46 ac6ff70 722991e 706f00e 6d48fcf`) | (claims) |
| R23-4 | MEDIUM | BEHAVIOR (corpus gap; ONE finding against `scripts/hand-mutants.py`: no site is in its inventory) | Four NEW hand mutants survive the whole corpus on c-1t (1078 of 1078 pass) AND the whole 616-law proof, each ALONE (`All terms check.`, 418-421 s) and together in group GALL3. K3: `key_char` refuses `Z` after the first character, so `{"aZ":1}` is written `"aZ": 1` (original `aZ: 1`). H5: `field.one` accepts an empty field name, so `[1]{a,,b}:` decodes (exit 0) where the original fails `Empty field name in field list` (exit 1). H9: `hdr.c.seg` takes `=` after `]` as the header colon, so `a[1]=: 1` decodes to `{"a": [": 1"]}` where the original gives `{"a[1]=": 1}`. U3: `unesc.tr` reads `\r` in a quoted KEY as LF, so `"a\rb": 1` decodes to key `"a\nb"` (the value-side twin `lit.esc` is pinned by `decode_literal_five_escapes`; the key side is not). The unmutated port equals the original on every one of these inputs, native and JS | S4.21, S2.137/S9.148, S2.133, S2.123 |
| R23-5 | LOW | LAW-COVERAGE (ONE finding against `scripts/hand-mutants.py`) | Twelve NEW mutants are killed by the corpus on c-1t but by NO law (all twelve together, group GALL3 with R23-4's four: `All terms check.`, 419 s): A4 `hex.val` upper-case A-F off by one; A5 `hex.val` refuses `f`; A6 a surrogate pair decoded one scalar too high; A7 U+DBFF not a high surrogate; T4 a list-item object's first field never tabular (S4.48); I1 a colon with no delimiter is a row; H1 `len.over` refuses exactly 100000000; H2 nine canonical digits over the cap unseen; H4 values after a fields-header colon accepted; H6 an open quote in a fields segment is "not a header"; U4 an unknown escape in a quoted key kept; J2 upper-case hex in `\u00XX`. Each is caught by 1 to 6 cases (A4 and A7 by `encstr_escapes_in_all` alone; H1/H2 by `toonerr_length_at_cap` ALONE; H4 by `toonedge_inline_beats_fields` alone; H6 by `toonerr_field_bad_quote` alone) | S2.19-S2.23, S4.48, S4.214, S2.136, S2.139, S2.132, S2.123, S5.66 |

Count under the rule: **BEHAVIOR 4 (MEDIUM 3, LOW 1), LAW-COVERAGE 1 (LOW), DOCUMENT 0.** NEW behavior findings of MEDIUM or above: **3** (R23-1, R23-2, R23-4). This round is NOT clean. I found **no difference between the UNMUTATED port and the original** on any lane: about 191,000 native executions of my own generators and hand inputs, at least 50,000 from `diff-fuzz` with new seeds, 12,896 on the JS lane and 36 on the interpreter (tables below).

### R23-1 reproduction

`/data/tmp/review_R23/r23/repro_R23_1.sh DIR VARIANT` clones the reviewed tree into DIR, appends rows 23 and 24 (`0 | 0 | yes`), refreshes the prose as R22-1 did (`r23/refresh.py`: "6 to 22" -> "6 to 24", the findings list extended by ", 0 and 0", the pasted converge line replaced, "NOT_CONVERGED" -> "CONVERGED" in PORT_REPORT's item 1), then runs the gates:
```
$ r23/repro_R23_1.sh gates/r1_empty empty          # lens "... (non-author)", two EMPTY report files
-rw-rw-r-- 1 ubuntu ubuntu 24029 Sep 24 18:53 round-22.md
-rw-rw-r-- 1 ubuntu ubuntu     0 Sep 24 18:53 round-23.md
-rw-rw-r-- 1 ubuntu ubuntu     0 Sep 24 18:53 round-24.md
{"tier": "T2", "rounds": 24, "clean": 7, "clean_tail": 2, "last_two_clean": true, "non_author_round": true, "open_oq": [], "open_disc": [], "unfixed": [], "verdict": "CONVERGED", "missing": []}
{"files": 16, "absent": [], "findings": 0, "historical_lines_exempt": 6, "laws": 616, "cases": 1078, "disc": {"accepted": 11, "resolved": 4, "open": 0}, "verdict": "OK"}
state-check: 0 finding(s)
$ r23/repro_R23_1.sh gates/r1_nbhyph nbhyph        # lens "independent hostile review (subagent, non‑author)", NO report files
-rw-rw-r-- 1 ubuntu ubuntu 24029 Sep 24 18:53 round-22.md          # (the last file in docs/reviews/)
{"tier": "T2", "rounds": 24, "clean": 7, "clean_tail": 2, "last_two_clean": true, … "verdict": "CONVERGED", "missing": []}
{"files": 16, "absent": [], "findings": 0, … "verdict": "OK"}
state-check: 0 finding(s)
```
Control (`gates/r1_control`: the same lens with an ASCII hyphen, no report):
```
  missing: round 23 is labelled non-author but has no report docs/reviews/round-23.md
  missing: round 24 is labelled non-author but has no report docs/reviews/round-24.md
docs/PORT_STATE.md:0: round 23 is labelled non-author in the rounds table but docs/reviews/round-23.md does not exist
{"files": 16, … "findings": 5, … "verdict": "FINDINGS"}
```
`harness-selftest.sh` M18 plants only the "no file" shape, so it cannot see either variant. Fix direction: a report must parse (a findings table in the required header `| id | sev | class | what | spec |`, or an explicit "no findings" line) and its header must name the reviewed commit; and require a report for EVERY row after the last author round (or normalise the lens text: NFKC plus hyphen folding) instead of keying on the ASCII word.

### R23-2 reproduction

`python3 /data/tmp/review_R23/r23/gatevar.py DIR VARIANT` clones the tree, appends rows 23 and 24 (`0 | 0 | yes`, non-author), writes `docs/reviews/round-23.md` with ONE finding row in the variant's layout (`R23-1 … MEDIUM … BEHAVIOR … the port prints X where the original prints Y`) and `round-24.md` with an empty findings table, refreshes the prose and runs both gates (`r23/gatevar.log`):
```
== control              converge NOT_CONVERGED ("round 23: the table says 0 counted finding(s), docs/reviews/round-23.md lists 1"), audit FINDINGS
== backtick_id          converge CONVERGED, audit OK      | `R23-1` | MEDIUM | BEHAVIOR | … |
== link_id              converge CONVERGED, audit OK      | [R23-1](#r23-1) | MEDIUM | BEHAVIOR | … |
== lower_id             converge CONVERGED, audit OK      | r23-1 | MEDIUM | BEHAVIOR | … |
== indented             converge CONVERGED, audit OK      " | R23-1 | MEDIUM | BEHAVIOR | … |"  (one leading space)
== no_lead_pipe         converge CONVERGED, audit OK      R23-1 | MEDIUM | BEHAVIOR | … | S4.1
== reordered            converge CONVERGED, audit OK      | id | class | sev | what | spec |
== extra_col            converge CONVERGED, audit OK      | id | lane | sev | class | what | spec |
== sev_code             converge CONVERGED, audit OK      | R23-1 | `MEDIUM` | BEHAVIOR | … |
== sev_under            converge CONVERGED, audit OK      | R23-1 | _MEDIUM_ | _BEHAVIOR_ | … |
== sev_html             converge CONVERGED, audit OK      | R23-1 | <b>MEDIUM</b> | BEHAVIOR | … |
== sev_abbrev           converge CONVERGED, audit OK      | R23-1 | MED | BEHAVIOR | … |
== class_al             converge CONVERGED, audit OK      | R23-1 | MEDIUM | BEHAVIORAL | … |
== not_a_finding_prose  converge CONVERGED, audit OK      | R23-1 | MEDIUM | BEHAVIOR | …; R22 had called this shape not a finding | S4.1 |
== escaped_pipe_id      converge CONVERGED, audit OK      | R23-1 (a\|b) | MEDIUM | BEHAVIOR | … |
== padded_id            converge NOT_CONVERGED, audit FINDINGS   (caught)
== id_R23_dot           converge CONVERGED, audit OK      | R23.1 | MEDIUM | BEHAVIOR | … |
== nbsp_sev             converge NOT_CONVERGED, audit FINDINGS   (caught)
== bullets              converge CONVERGED, audit OK      - **R23-1** (MEDIUM, BEHAVIOR): …
```
The rule text the brief binds reviewers to fixes the column order, so some variants are a non-conforming report; the defect is that the gate reads a non-conforming report as a CLEAN one instead of refusing it. The `not a finding` variant is a conforming report. Fix direction: parse the findings table by its header (locate `sev` and `class` by name), refuse a report whose table is missing or whose R-ids cannot be read, and apply the "not a finding" exclusion only to an explicit marker in the class cell.

### R23-3 reproduction

`python3 /data/tmp/review_R23/r23/reach.py gates/reach` (edits one evidence file at a time and restores it with `git checkout`; planted new files are renamed aside into `gates/reach_moved/`, none deleted; `git status --short` afterwards shows only `?? oracle`):
```
== A control: after.commit = 494ef82                              1 FINDINGS | perf/evidence/COUNTED.canada.decode.json:0: the after.commit commit 494ef82 is not reachable from HEAD: a read
== B after.commit = {id: 494ef82}                                 0 OK
== C after.commit = {hash: 494ef82, date: ...}                    0 OK
== D after.built_from = 494ef82                                   0 OK
== E after.head = 494ef82                                         0 OK
== F after.commit = 'at 494ef82'                                  0 OK
== G after.commit = 'toon_bend@494ef82'                           0 OK
== H after.commit = 13-hex abbreviation 494ef82abcdef             0 OK
== I after.commit = 494ef82 (control for H: 7 hex)                1 FINDINGS | …
== J after.binary = '/scratch/frozen494ef82/toon'                 0 OK
== K after.commit = 'v494ef82'                                    0 OK
== L file name COUNTED.canada.decode.494ef82.JSON (upper-case ext) 0 OK
== M file name COUNTED-canada.decode.494ef82.json (dash)          0 OK
== N file name counted.canada.decode.494ef82.json (lower)         0 OK
== O subdirectory perf/evidence/old/COUNTED...494ef82.json        0 OK
== P COUNTED.canada.decode.494ef82.ndjson                         0 OK
== Q annot.txt Command: .../frozen494ef82/toon                    0 OK
== R counts.jsonl command: .../frozen494ef82/toon                 0 OK
```
Fix direction: under a commit-named key, treat EVERY string at any depth below it as named; accept any hex run of 7-40 digits that is a prefix of an object git knows or does not know (resolve with `git rev-parse --verify <x>^{commit}` rather than by length); extract `[0-9a-f]{7,40}` tokens bounded by non-hex from path-like values; walk `perf/evidence/` recursively with a case-insensitive name test and read the `.txt` Command lines.

### R23-4 reproductions (the original, the unmutated port and the mutant on the same input; `r23/tri.py`)

```
K3 port same mut DIFF | ['--encode'] b'{"aZ":1,"Za":2}'
   orig: (b'aZ: 1\nZa: 2\n', b'', 0)
   mut:  (b'"aZ": 1\nZa: 2\n', b'', 0)
H5 port same mut DIFF | ['--decode'] b'[1]{a,,b}:\n  1,2,3\n'
   orig: (b'', b'Failed to decode TOON: Empty field name in field list\n', 1)
   mut:  (b'[\n  {\n    "a": 1,\n    "": 2,\n    "b": 3\n  }\n]\n', b'', 0)
H5 port same mut DIFF | ['--decode'] b'[1]{a,}:\n  1,2\n'
   orig: (b'', b'Failed to decode TOON: Empty field name in field list\n', 1)
   mut:  (b'[\n  {\n    "a": 1,\n    "": 2\n  }\n]\n', b'', 0)
H9 port same mut DIFF | ['--decode'] b'a[1]=: 1\n'
   orig: (b'{\n  "a[1]=": 1\n}\n', b'', 0)
   mut:  (b'{\n  "a": [\n    ": 1"\n  ]\n}\n', b'', 0)
H9 port same mut DIFF | ['--decode', '--no-strict'] b'k: 1\na[1]= "x:"\n'
   orig: (b'', b'Failed to decode TOON: Unterminated string: missing closing quote\n', 1)
   mut:  (b'{\n  "k": 1,\n  "a": [\n    "x:"\n  ]\n}\n', b'', 0)
U3 port same mut DIFF | ['--decode'] b'"a\\rb": 1\n'
   orig: (b'{\n  "a\\rb": 1\n}\n', b'', 0)
   mut:  (b'{\n  "a\\nb": 1\n}\n', b'', 0)
```
Mutant texts (`r23/mut23.py`, applied to a copy in `r23/mut/<id>/port`, `diff.txt` beside it):
- K3 `text.bend` `key_char`: `U32.is_le(c, 90)` -> `U32.is_le(c, 89)` (the upper-case range of the LATER characters)
- H5 `decode.bend` `field.one`: `case SNil{}: FRErr{"Empty field name in field list"}` -> `FROk{Field{SNil{}, False{}} <> rev}`
- H9 `decode.bend` `hdr.c.seg`: `U32.is_eq(c, 58), 2n` -> `Bool.or(U32.is_eq(c, 58), U32.is_eq(c, 61)), 2n`
- U3 `decode.bend` `unesc.tr`: `case False{} True{} 3n: … SCon{Chr{13}, rev}` -> `SCon{Chr{10}, rev}`

Corpus (`r23/mut_all.log`): K3, H5, H9, U3 each `"passed": 1078, "failed": 0, … "verdict": "PASS"`. Proofs (`r23/proofs23.log`, whole 616-law `PROOF.bend` of each single mutant):
```
K3 PROOF rc=0 secs=418 	Maximum resident set size (kbytes): 3245296 last: All terms check.
H5 PROOF rc=0 secs=421 	Maximum resident set size (kbytes): 3101896 last: All terms check.
H9 PROOF rc=0 secs=419 	Maximum resident set size (kbytes): 2847836 last: All terms check.
U3 PROOF rc=0 secs=420 	Maximum resident set size (kbytes): 3356152 last: All terms check.
```
Fix direction: goldens and laws for a later `Z` in a bare key (and the other range ends of `key_char`: `z`, `A`, `9`), an empty field name between two names and at the end of a field list, a `]` followed by a character other than `{`, `:` or whitespace in a key, and `\r` in a quoted key (and field name); add the four sites to `hand-mutants.py`.

### R23-5 reproductions (the unmutated port equals the original on every row)

```
A4 ['--encode'] b'["\\u00C9"]'           orig: [1]: É (C3 89)                     mut: [1]: Ù (C3 99)
A5 ['--encode'] b'["\\u00ef"]'           orig: [1]: ï  exit 0                     mut: Failed to parse JSON: invalid escape at line 1 column 8  exit 1
A6 ['--encode'] b'["\\ud83d\\ude00"]'    orig: [1]: U+1F600                       mut: [1]: U+1F601
A7 ['--encode'] b'["\\udbff\\udfff"]'    orig: [1]: U+10FFFF  exit 0              mut: Failed to parse JSON: lone leading surrogate in hex escape at line 1 column 14  exit 1
T4 ['--encode'] b'[{"a":[{"x":1},{"x":2}],"b":1}]'  orig: [1]:\n  - a[2]{x}:\n      1\n      2\n    b: 1   mut: [1]:\n  - a[2]:\n      - x: 1\n      - x: 2\n    b: 1
I1 ['--decode'] b'[2]{a,b}:\n  1,2\n  x: 3\n'  orig: Expected 2 tabular rows, but got 1   mut: Expected 2 tabular row values, but got 1
H1, H2 ['--decode'] b'[100000000]:\n'    orig: Expected 100000000 list array items, but got 0   mut: Declared array length 100000000 exceeds maximum allowed (100000000)
H4 ['--decode'] b'[1]{a}: 1\n'            orig: Unexpected content after fields-bearing header colon  exit 1   mut: [\n  1\n]  exit 0
H6 ['--decode'] b'rows[1]{"a}:\n  1'      orig: Unterminated string: missing closing quote   mut: Missing colon after key
U4 ['--decode'] b'"a\\qb": 1\n'           orig: Invalid escape sequence: \q  exit 1   mut: {"aqb": 1}  exit 0
J2 ['--decode'] b'k: a\x1fb\n'           orig: "a\u001fb"                          mut: "a\u001Fb"
```
Proof: group GALL3 = K3 H5 H9 U3 + the twelve, `PROOF rc=0 secs=419 … last: All terms check.` (`r23/mut/GALL3/proof.log.summary`). The law pre-screen (`r23/lawscreen.py`: every closed `C.run_pure` law, 374 of 375 parsed, run on the mutant binary) names no law for any of the twelve.

## Mutant table (all mutants of this round)

Each mutant is one exact-text replacement in a copy of `port/` (`r23/mut23.py`; `r23/mut/<id>/diff.txt`), built natively (memory-gated) and run through the whole corpus on c-1t. For corpus-killed mutants, `r23/lawscreen.py` runs each closed `C.run_pure` law's argv and bytes on the mutant binary; a law it names refuses the mutant when the checker evaluates it. Mutants the screen named no law for went into whole proofs: GALL (refused by `writer_b_keeps_del_raw`: J1), GALL2 (refused by `writer_a_keeps_del_raw`: J3), GALL3 (16 members, `All terms check.`); J4 alone (refused by `writer_b_keeps_c1_raw`); K3, H5, H9, U3 alone (`All terms check.`).

| id | def | change | corpus c-1t failing | law | verdict |
|---|---|---|---|---|---|
| K3 | `text.bend` `key_char` | later `Z` not a key char | 0 | none (whole, alone) | **R23-4** |
| H5 | `decode.bend` `field.one` | empty field name accepted | 0 | none (whole, alone) | **R23-4** |
| H9 | `decode.bend` `hdr.c.seg` | `=` after `]` is the header colon | 0 | none (whole, alone) | **R23-4** |
| U3 | `decode.bend` `unesc.tr` | `\r` in a quoted key reads LF | 0 | none (whole, alone) | **R23-4** |
| H7 | `decode.bend` `ucut.cls` | a backslash outside quotes escapes | 0 | screen: `decode_backslash_outside_quotes_in_fields` | killed by a law (corpus gap only) |
| A4 | `json.bend` `hex.val` | A-F off by one | 1 | none (GALL3) | **R23-5** |
| A5 | `hex.val` | `f` not a hex digit | 6 | none (GALL3) | **R23-5** |
| A6 | `hex.fin` | pair one scalar high | 2 | none (GALL3) | **R23-5** |
| A7 | `hex.go` | U+DBFF not high | 1 | none (GALL3) | **R23-5** |
| T4 | `encode.bend` `ctx.first` | first field of a list-item object never tabular | 6 | none (GALL3) | **R23-5** |
| I1 | `decode.bend` `is_row.of` | colon, no delimiter: a row | 2 | none (GALL3) | **R23-5** |
| H1 | `len.over` | 100000000 over the cap | 1 | none (GALL3) | **R23-5** |
| H2 | `hdr.e.canon` | nine digits over unseen | 1 | none (GALL3) | **R23-5** |
| H4 | `hdr.g` | values after a fields colon accepted | 1 | none (GALL3) | **R23-5** |
| H6 | `hdr.c.fields` | open quote in fields not an error | 1 | none (GALL3) | **R23-5** |
| U4 | `unesc.tr` | unknown key escape kept | 3 | none (GALL3) | **R23-5** |
| J2 | `json.bend` `hexc` | upper-case hex digits | 2 | none (GALL3) | **R23-5** |
| A1 | JSON `esc` | `\/` reads `\` | 1 | screen: `encode_escaped_solidus_reads_as_slash` | killed |
| A2 | JSON `esc` | `\"` reads `'` | 8 | screen: `encode_close_bracket_quote_backslash_force_quotes` | killed |
| A3 | JSON `esc` | `\r` reads LF | 6 | screen: `cr_in_value_forces_quotes` | killed |
| A8 | `hex.go` | U+DC00 not low | 2 | screen: `golden_jsonerr_lone_low_surrogate` | killed |
| A9 | `hibs` | any byte stands for the backslash | 2 | screen: `golden_jsonerr_lone_high_surrogate`, `golden_jsonerr_high_then_newline` | killed |
| A10 | `hex.fin` | lone low surrogate is a scalar | 1 | screen: `golden_jsonerr_lone_low_surrogate` | killed |
| K1 | `key_first` | `z` cannot start | 13 | screen: 5 laws incl. `golden_enc_fold_budget_threading_5` | killed |
| K2 | `key_char` | `0` not a key char | 23 | screen: 9 laws incl. `encode_repeated_key_two_members_repeat_last` | killed |
| K4 | `key_first` | a digit may start | 8 | screen: `golden_fx_enc_objects_20` | killed |
| R1 | `row.lock` | LONGER in-order row passes lockstep | 3 | screen: `golden_fx_enc_arrays_objects_01` | killed |
| R2 | `row.lock` | keys never compared | 6 | screen: `golden_fx_enc_arrays_objects_15`, `golden_collision_keys_encode`, `encode_row_missing_a_header_key_is_list_form` | killed |
| T1 | `vk.arr` | primitives as a list item: list form | 15 | screen: `golden_fx_enc_arrays_nested_01` +2 | killed |
| T2 | `vkind` | `{}` takes the non-empty kind | 6 | screen: `golden_fx_enc_arrays_objects_14`, `encode_array_of_empty_objects_is_list_form` | killed |
| T3 | folded leaf | never tabular | 1 | screen: `golden_fx_enc_key_folding_03` | killed |
| H3 | `hdr.names` | blank field list split | 1 | screen: `golden_toonedge_fields_space_only` | killed |
| H8 | `len.mark` | TAB header selects comma | 14 | screen: `golden_fx_dec_delimiters_01`, `_16` | killed |
| U1 | `lit.esc` | bad escape always `\x` | 1 | screen: `golden_toonerr_unicode_escape` +2 | killed |
| U2 | `lit.esc` | `\r` reads LF in values | 4 | screen: `decode_literal_five_escapes` | killed |
| J1 | writer A | DEL escaped | 6 | proof GALL: `writer_b_keeps_del_raw` | killed |
| J3 | writer A | U+0008 as `\u0008` | 6 | proof GALL2: `writer_a_keeps_del_raw` | killed |
| J4 | writer A | C1 escaped | 6 | proof alone: `writer_b_keeps_c1_raw` | killed |

Screen-killed rows rest on the pre-screen (the law's own argv and bytes reproduce a different result on the mutant binary), not on a separate proof per mutant.

Item 3 of the brief (dispatches no law pins): pinned by a law — `len.mark`'s TAB arm (H8), `hdr.names` (H3), `lit.esc` (U1, U2), `ucut.cls` (H7), the writer's DEL/C1/`\b` arms (J1, J3, J4), `vk.arr`/`vkind` (T1, T2), `row.lock` (R1, R2); pinned by the corpus only — `hex.val`/`hex.fin`/`hex.go` (A4-A7), `ctx.first`'s tab_ok (T4), `is_row.of`'s colon-only arm (I1), the length cap boundary (H1, H2), `hdr.g`'s inline test (H4), `hdr.c.fields`' open quote (H6), `unesc.tr`'s bad-escape arm (U4), `hexc` (J2); pinned by NEITHER — `key_char`'s range ends (K3), `field.one`'s empty arm (H5), `hdr.c.seg`'s "other" arm (H9), `unesc.tr`'s `\r` arm (U3).

## Round 22's repairs (item 0)

| R22 finding | this round |
|---|---|
| R22-1 (no report) | the planted "no file" shape is caught (control above); the repair is evaded by an empty file or a look-alike hyphen (**R23-1**) |
| R22-2 (counted cells) | title case, `BEHAVIOUR` and a zero-yield report are caught (control, and my gatevar `control`); 16 other layouts are read as zero (**R23-2**) |
| R22-3 (reachability) | **holds** for every shape R22 named: re-planted one by one in `gates/reach22` (`r23` inline script, files moved aside to `gates/reach22_moved/`), each prints `1 FINDINGS`: `"494ef82 (scratch)"`, `after.binary.commit`, `after.sha`, the whole file a list, `runs[].commit`, the name `COUNTED.canada.decode.494ef82-pre.json`, a `COUNTED.x.jsonl` and a `COUNTED-PROFILE.x.counts.jsonl` naming it. 16 further shapes are not read (**R23-3**) |
| R22-4 (five law gaps) | holds for the five sites: the neighbouring mutants A1-A3, A8-A10, K1, K2, K4, R1, R2, T1-T3 are refused by laws (screen). New gaps in the same defs and neighbours: K3 (R23-4), A4-A7 (R23-5). `hand-mutants.py M55-M59`: 5 of 5 KILLED by the four new laws (below) |
| R22-5 (document) | `PORT_STATE.md` no longer states "< 3 new genuine findings" (line 130: "a clean round has no unresolved finding from that round and, from round 20 on …") |

`python3 scripts/hand-mutants.py M55 M56 M57 M58 M59` on this tree (`TMPDIR=/data/tmp/review_R23/hm`, memory-gated, `r23/hm_55_59.log`): BASE (the unmutated REDUCED proof) `GREEN` 360.9 s; M55 and M56 `KILLED` by `encode_json_backspace_and_form_feed_escapes`, M57 by `encode_underscore_initial_keys_are_bare`, M58 by `encode_short_row_in_header_order_is_list_form`, M59 by `encode_array_of_objects_as_list_item_is_list_form`; last line `{"laws_in_proof": 371, "laws_sha256_12": "f923e244b5a6", … "reduced": true, "mutants": 5, "killed": 5, "survived": [], "not_evidence": [], "verdict": "STRONG"}`, identical to the line PORT_STATE and README paste. R22-4's repair holds.

## Clean areas: compared executions of the UNMUTATED port

| lens (script, seed) | target | executions | diffs |
|---|---|---|---|
| `lens23.py hdr` 23101 (1500), 23102 (800), 23201 (8000, t1), 23202 (2000, t1,8 × ±`TOON_SPEC=1`) | item 1: `KEY[LEN]{FIELDS}AFTER` with 26 keys (quoted, escaped, `\u`, bad escapes, brackets, colons), 35 length texts (leading zeros, signs, spaces, trailing and doubled delimiter marks, 100000000/100000001, 23 digits, `1e1`, Arabic-Indic and full-width digits), 29 field lists (quoted, escaped, `}` inside quotes, empty, blank, duplicate, mixed delimiters, unterminated), 12 tails, as root/nested/list item, with row bodies of the right, short and long shape and wrong delimiters | 3,000 + 1,600 + 16,000 + 10,000 | 0 |
| `lens23.py litem` same seeds | list items opening objects with a tabular (or list/inline/empty/object) first field; row depths 2-4, sibling fields at depths 1-3, `--indent` 1/2/4 | 30,600 | 0 |
| `lens23.py indent` same seeds | the original's own encoding at `--indent` 1..16, 0-2 lines re-indented or stripped, decoded at the same or another indent, 70% `--no-strict`, 30% expansion | 29,000 | 0 |
| `lens23.py expand` same seeds | 18 keys (`a.b`, `"a.b"`, `a."b"`, `"a".b`, `a.`, `.a`, `a..b`, `"a..b"`, …) nested 0-2 deep with inline arrays and tables, `--expand-paths safe` ± `--no-strict` | 29,000 | 0 |
| `lens23.py jw` same seeds | item 2: 49 code points (C0, DEL, C1 ends, U+2028/9, U+FEFF, noncharacters, U+10FFFF, `"` `\` `/`) in 7 positions; 51 number texts (1e21 / 1e20, 1e-7 / 1e-6, -0, 5e-324, the 2^-1075 ties, max double and its overflow neighbours, 2^53+1, 2^64, 1e400, leading zeros, `1.`, `.5`, …) both directions | 29,000 | 0 |
| `lens23.py deep` same seeds | nesting 120-134: JSON arrays, objects, mixes (± folding) and TOON objects, lists, mixes | 29,000 | 0 |
| `hand23.py` (native t1,8 × ±`TOON_SPEC=1`) | item 2 exhaustive: 71 code points × 8 positions × 3 decode modes; 51 numbers × 5 TOON positions × 2 modes and × 4 JSON shapes × 3 encode modes | 14,240 | 0 |
| `diff-fuzz.py` mutate/docs/argv/expand/collide 230001 (3000 each, t1), 230002 (2000 each, `--switch TOON_SPEC=1`, t8) | repository lenses, new seeds | ≥ 50,000 (25,000 inputs, each `"differences": 0 … "verdict": "PASS"`) | 0 |
| `diff-fuzz.py numbers` 230003 (`--runs 40000 --switch TOON_SPEC=1`), `scale` 230004 (t1), 230005 (`--switch`, t8) | `"number_literals": 40000`; `"too_slow": 0` | ≥ 640 | 0 |
| **JS lane**: `lens23.py` all six modes seed 23301 (600 each), `hand23.py --js` | the sharpest shapes above on `js/toon.js` | 7,200 + 5,696 | 0 |
| **interpreter lane** (`r23/interp23.py`, `bun main.ts port/main.bend --`) | 18 inputs: `[02]` with a quoted comma field, `[+2]`, `[100000000]`, a 19-digit length, a quoted key with `\"` and a pipe header with `}` in a quoted field, a short row lenient, a list item with a tabular first field, `--indent 3` lenient, dotted/quoted key collisions, C0/DEL/C1 in values and keys under expansion, the five printer boundaries both ways, depth 127/128, `\u` in TOON, a TAB header | 36 | 0 |

Total compared executions of the unmutated port against the original: about 191,000 native from my generators and hand inputs (18,000 + 3,200 + 96,000 + 60,000 + 14,240), at least 50,640 from `diff-fuzz`, 12,896 on JS, 36 on the interpreter. Confirmed along the way (both programs agree): the original refuses `\u` in TOON strings (`Invalid escape sequence: \u`), writes DEL and U+0080-U+009F raw and C0 as `\u00xx` (lower-case) with `\b`/`\f` short forms, prints `-0` as `0` on `--decode`, and fails `recursion limit exceeded` at JSON depth 128 but not 127. The mutant runs (38 corpus runs, `tri.py`, `lawscreen.py`) classify mutants only and are not counted here.

## What this round did NOT cover

- a WHOLE proof of the UNMUTATED tree (only `hand-mutants.py`'s reduced BASE, GREEN; each whole mutant proof that ended in `All terms check.` implies the unmutated laws check too); `lanes.sh`, `port-doctor.sh`, `floor.sh`, `stdio-probe.py`, `harness-selftest.sh` (it builds the port; not run), any performance
- a separate proof for each screen-killed mutant: those verdicts rest on the law's own inputs reproducing a different result on the mutant binary, and on the golden-law equivalence; the 12 LAW-COVERAGE mutants were proved only as members of GALL3 (not singly)
- c-8t beyond the lenses marked t1,8 and `diff-fuzz` seeds 230002/230005; the JS lane beyond 12,896 executions; inputs above about 100 KB on any lane; `-o` and file operands
- the rounds-table gates beyond the 23 layouts above (e.g. a report in a code fence counts its rows, an over-count that fails closed, not tested for harm); `state-check.sh` and `claims-lint.sh` were run only as part of the R23-1 reproductions
- DOCUMENT review beyond reading README's and PORT_STATE's mutant and law statements against the inventory (58 sites, `len(MUTANTS)`) and the 616-law count: no document finding (under 15% of the effort)

## Artifacts

Everything is under `/data/tmp/review_R23/`: `bin/toon`, `js/toon.js`; `gates/` (one clone per gate scenario: `r1_empty`, `r1_nbhyph`, `r1_control` for R23-1; the 19 `gatevar.py` layouts and `author` for R23-2; `reach` and `reach_moved` for R23-3; `reach22` and `reach22_moved` for R22-3's shapes; `selfcheck`, where this report is read by the repository's own gates: `round 23: the table says 0 counted finding(s), docs/reviews/round-23.md lists 3`). `hm/` holds `hand-mutants.py`'s copies. In `r23/`: `cmp.py`, `q.py`, `tri.py`, `lens23.py`, `lens23_data.py`, `hand23.py`, `interp23.py`, `refresh.py`, `repro_R23_1.sh`, `gatevar.py` (+ `gatevar.log`), `reach.py` (+ `reach.log`), `mut23.py`, `group.py`, `lawscreen.py`, `screenall.sh`, `build.sh`, `proof.sh`, `proofq.sh`, `waitmem.sh`, `mut/<id>/` (port copy, `diff.txt`, `toon_mut`, `toon_mut.log`, `conform.json`, proof logs), `mut_all.log`, `proofs23.log`, `hm_55_59.log`, the lens logs (`lens_*`, `js_*`, `df_*`).
