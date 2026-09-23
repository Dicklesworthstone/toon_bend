# Round 19: non-author hostile review of toon_bend

| field | value |
|---|---|
| reviewed commit | `7d6f79ea7b91c2db50ddf51c28f95e9beb6f4d49` (fresh clone `/data/tmp/review_R19/clone`; `git rev-parse HEAD` printed that hash, NOT the expected `2c33e64`: one commit landed on top, `7d6f79e perf(e2e): a COUNTED corpus comparison`. `git diff --stat cbdfba6 HEAD -- port/ ':!port/LAWS.bend' ':!port/PROOF.bend'` is empty, so the port code reviewed is the code of `cbdfba6`/`2c33e64`) |
| original | `oracle/toon` -> `/data/projects/toon_bend/oracle/toon`, sha256 `821287eaf1a6d320ee1ef7604e74e3cefaa42b69445c96abb9dd310782d04030`, equal to `docs/PIN.toml`; `toon 0.2.4` |
| Bend | `bun /tmp/bend/bend2/main.ts`, `/tmp/bend` at `15ae0c86f3193b8f645b4bedbc438655b648d0da`, `BEND_NO_TELEMETRY=1` |
| tools | bun 1.4.2, Ubuntu clang 21.1.8, Python 3.14.4 |
| port binary | `bin/toon` (native; `bun … port/main.bend -o bin/toon`: 24.2 s wall, exit 0) |
| unmutated corpus | `./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t -- ../bin/toon --threads 1 --` -> `"passed":1076,"failed":0,"inconclusive":0,"stderr_compared":true,"verdict":"PASS"` |
| host | shared, 8 cores, 30 GB. 18:25 load 3.8, 24 GB available; 18:47 load 7.1; 19:15 load 8.6; 19:30 load 14.7, 8 GB available (other sessions). Only one `bend -o` build or one `PROOF.bend` ran at a time. No timing here is evidence of speed |

Harness: `r19/cmp.py` (round 18's `cmp.py`, paths changed) runs `./oracle/toon ARGV` and `bin/toon --threads T -- ARGV` on the same stdin (a pipe) and compares stdout, stderr and exit code byte for byte. `TOON_SPEC` is removed unless a run sets it. "Executions" counts every run of either program.

## Findings

| id | sev | class | what | spec |
|---|---|---|---|---|
| R19-1 | MEDIUM | BEHAVIOR (mutant) | EXP-026 `like.ph` arm (4,0), a '0' after the first fraction digit: mutant M4 (`4n` -> `8n`) makes the encoder leave `"1.50"`, `"1.500"`, `"2.10"` and similar strings UNQUOTED. Once the original decodes that TOON, the value comes back as the NUMBER `1.5`. It survives the corpus (1076/1076), the whole 571-law proof (`All terms check.`), and `diff-fuzz.py docs` and `mutate` (seed 191101, 2000 inputs each, 0 differences). NE-030 says its seventeen `is_like_*` laws cover "every accepting phase, every refusal path". The comment above `is_like_zero_fraction` says the two zero-fraction laws reach "the table's class-0 arms of phases 3 and 4". They do not: "0.0" and "1.05" take (3,0) and then (4,1), and no law puts a '0' in phase 4. The only evidence that reaches the arm is NE-030's one-off length-6 sweep, and no gate re-runs it | S4.160, S4.161 |
| R19-2 | LOW | BEHAVIOR (mutant) | EXP-025 `scan.rev` starts the reversed walk with `end = True`: a CR at the very end of the text with no LF is dropped. Mutant M1 (`True{}` -> `False{}`) keeps it, and then `x[1]:\n  -\r` (a bare list marker, then CR at EOF) fails with `Expected 1 list array items, but got 0` where the original prints `{"x": [{}]}`. It survives the corpus, the 571-law proof and diff-fuzz docs/mutate. It also survives my own lenses (`lens_scan` 19001, `lens_scanx` A L=4). The laws `decode_scan_bare_dash_cr_cr` and `decode_scan_bare_dash_crlf` pin S2.113's one observable exception only when an LF follows. `decode_scan_no_final_lf` has no CR | S2.102, S2.113 |
| R19-3 | LOW | BEHAVIOR (mutant) | EXP-025 byte order mark: mutant M3 applies `seg.bom` to every line (not only the first). Decoding without `--stats` then drops a U+FEFF that heads ANY line: `a: 1\n\xEF\xBB\xBFb: 2\n` gives key `"b"` where the original gives key `"﻿b"`. It survives the corpus, the 571-law proof and diff-fuzz docs/mutate. My `lens_scan` 19001 catches it (2 of 6000 executions). No law or corpus case has a U+FEFF after the first character | S8.7 |
| R19-4 | LOW | BEHAVIOR (mutant) | `uq.tr` (the colon/delimiter search, S2.121): mutant M15 (a backslash inside quotes no longer sets `esc`). A quoted tabular cell or list item holding `\"` then `:` becomes a key-value line. `t[1]{a,b}:\n  "x\":y",1\n` gives `Expected 1 tabular rows, but got 0` (exit 1). `[1]:\n  - "a\":b"\n` gives `Missing colon after key`. It survives the corpus and the 571-law proof. The repository's `diff-fuzz.py docs --seed 191101` DOES catch it (39 differences in 2000 inputs; `mutate`: 1). This is the `uq` twin of R18-2 (`split.tr`), whose repair pinned only `split` | S2.121, S4.214 |
| R19-5 | LOW | DOCUMENT | round 18's R18-D1 repair can be bypassed by wording. `README.md:153` says the COUNTED evidence files "without a commit in their name hold the same comparison against `494ef82`", and `perf/evidence/COUNTED.{canada,gsoc_2018,flights_200k}.{encode,decode}.json` all record `"after": {"commit": "494ef82", …}`. That commit does not exist: it is the same scratch commit R18-D1 reported. `python3 scripts/claims-audit.py` still says `"findings": 0, … "verdict": "OK"`, because the new rule only matches the words "tree of `hash`" | (claims) |

No difference between the UNMUTATED port and the original was found in any lens (tables below). All four behavior findings are hand mutants that change bytes and that neither the corpus nor the proof catches.

### Mutant table (all mutants of this round)

Each mutant is one text replacement in a copy of `port/` (`r19/mut.py`, `r19/mut/<id>/diff.txt`), built natively and run through the whole corpus (`conform.sh … --lane c-1t`). Each corpus survivor was then checked with the WHOLE 571-law `PROOF.bend` in its own copy (`r19/proof_capped.sh`: one proof at a time, killed above 10 GB; none was killed).

| id | def | change | corpus c-1t | `PROOF.bend` (571 laws) | verdict |
|---|---|---|---|---|---|
| M1 | `decode.bend` `scan.rev` | initial `end` `True{}` -> `False{}` (CR at EOF kept) | PASS 1076/1076 | `PROOF rc=0 killed=0 peak_kb=4530444 secs=384 last: All terms check.` | **R19-2** |
| M2 | `decode.bend` `seg.bom.drop` | drop every leading U+FEFF | INVALID: did not compile (`expected : a defined name / observed : seg.bom`, a forward reference) | — | not a mutant |
| M3 | `decode.bend` `seg.go` LF arm | `cur` -> `seg.bom(bom, cur)` (BOM dropped at every line head) | PASS 1076/1076 | `PROOF rc=0 killed=0 peak_kb=5119052 secs=533 last: All terms check.` | **R19-3** |
| M4 | `f64.bend` `like.ph` (4,0) | `4n` -> `8n` | PASS 1076/1076 | `PROOF rc=0 killed=0 peak_kb=4794828 secs=503 last: All terms check.` | **R19-1** |
| M5 | `like.ph` (7,0) | `7n` -> `8n` | KILLED 1075 (`encstr_numeric_like_forms`) | not run | killed |
| M6 | `like.ph` (6,0) | `7n` -> `8n` | KILLED 1075 (`encstr_numeric_like`) | not run | killed |
| M7 | `like.ph` (1,3) | `5n` -> `8n` | KILLED 1075 (`encstr_numeric_like`) | not run | killed |
| M8 | `like.ph` (1,1) | `2n` -> `8n` | KILLED 1074 (`encstr_numeric_like`, `fx_enc_primitives_10`) | not run | killed |
| M9 | `like.ph` (5,0) | `7n` -> `8n` | KILLED 1075 (`encstr_numeric_like`) | not run | killed |
| M10 | `like.ph` (2,0) | `2n` -> `8n` | KILLED 1075 (`encstr_numeric_like_forms`) | not run | killed |
| M11 | `like.ph` (7,1) | `7n` -> `8n` | KILLED 1074 | not run | killed |
| M12 | `encode.bend` `put.row` | lock 0 writes cells in ROW order | KILLED 1071 (`enc_shapes_mixed`, …) | not run | killed |
| M13 | `encode.bend` `row.lock` | a row with more keys than the header passes lockstep | KILLED 1073 (`enc_tabular_corners`, …) | not run | killed |
| M14 | `decode.bend` `len.mark` | a TAB mark selects `\|` | KILLED 1062 (`toonerr_tab_header`, 13 more) | not run | killed |
| M15 | `decode.bend` `uq.tr` | inside quotes a backslash does not set `esc` | PASS 1076/1076 | `PROOF rc=0 killed=0 peak_kb=5148148 secs=462 last: All terms check.` | **R19-4** (diff-fuzz docs catches it) |
| M16 | `encode.bend` `fctx.lean` | `F.twin.on(spec, Bool.not(fo))` -> `F.twin.on(spec, True{})` | KILLED 1073 (`enc_fold_root_literal_nested`, …) | not run | killed |

Which other tools catch the survivors (mutant binary vs the original):

| mutant | `diff-fuzz.py docs --seed 191101 --runs 2000` | `diff-fuzz.py mutate --seed 191101 --runs 2000` | my lens |
|---|---|---|---|
| M4 | 0 differences, PASS | 0, PASS | `lens_like.py 19101 2000`: 187 diffs in 4000 executions |
| M1 | 0, PASS | 0, PASS | `lens_scan.py 19001 3000`: 0; `lens_scanx.py 4 A`: 0 (46,810 executions) |
| M3 | 0, PASS | 0, PASS | `lens_scan.py 19001 3000`: 2 diffs |
| M15 | 39 differences, FAIL | 1, FAIL | — |

### Reproductions (verbatim; cwd `/data/tmp/review_R19/clone`)

R19-1 (M4):
```
$ printf '["1.50","1.500"]' | ./oracle/toon --encode                                  -> [2]: "1.50","1.500"      exit 0
$ printf '["1.50","1.500"]' | ../bin/toon --threads 1 -- --encode                     -> [2]: "1.50","1.500"      exit 0
$ printf '["1.50","1.500"]' | ../r19/mut/M4/toon_mut --threads 1 -- --encode          -> [2]: 1.50,1.500          exit 0
$ echo '{"price":"1.50"}' | ./oracle/toon --encode | ./oracle/toon --decode
{
  "price": "1.50"
}
$ echo '{"price":"1.50"}' | ../r19/mut/M4/toon_mut --threads 1 -- --encode | ./oracle/toon --decode
{
  "price": 1.5
}
$ cat ../r19/mut/M4/diff.txt
1213c1213
<       4n
---
>       8n
```
Fix direction: a closed law `F.is_like("1.50") == F.is_like.lex("1.50")`, or better a law for EVERY non-sink arm of `like.ph` against `lex.tr` (the table has 23 non-sink arms; by my reading of the 17 `is_like_*` laws and `encode_numeric_like_items`, they reach 15, and miss (1,1), (1,3), (2,0), (4,0), (5,0), (6,0), (7,0), (7,1). Of those eight, only (4,0) is also missed by the corpus: M5-M11 are killed by `encstr_numeric_like*`), and make NE-030's length-6 sweep a gate instead of a one-off.

R19-2 (M1):
```
$ printf 'x[1]:\n  -\r' | ./oracle/toon --decode                             -> {"x": [{}]} (pretty-printed)  exit 0
$ printf 'x[1]:\n  -\r' | ../bin/toon --threads 1 -- --decode                -> {"x": [{}]} (pretty-printed)  exit 0
$ printf 'x[1]:\n  -\r' | ../r19/mut/M1/toon_mut --threads 1 -- --decode    -> Failed to decode TOON: Expected 1 list array items, but got 0   exit 1
```
Fix direction: the golden `x[1]:\n  -\r` (no LF) beside `decode_scan_bare_dash_crlf`.

R19-3 (M3):
```
$ printf 'a: 1\n\xef\xbb\xbfb: 2\n' | ./oracle/toon --decode                          -> {"a": 1, "﻿b": 2}   exit 0
$ printf 'a: 1\n\xef\xbb\xbfb: 2\n' | ../bin/toon --threads 1 -- --decode             -> {"a": 1, "﻿b": 2}   exit 0
$ printf 'a: 1\n\xef\xbb\xbfb: 2\n' | ../r19/mut/M3/toon_mut --threads 1 -- --decode  -> {"a": 1, "b": 2}         exit 0
```
(The original's and port's key is the raw U+FEFF followed by `b`. The same holds for two leading BOMs: `\xef\xbb\xbf\xef\xbb\xbfa: 1` gives key `"﻿a"` in the original and in the port. No law pins either.)

R19-4 (M15):
```
$ printf 't[1]{a,b}:\n  "x\\":y",1\n' | ./oracle/toon --decode                         -> {"t": [{"a": "x\":y", "b": 1}]}   exit 0
$ printf 't[1]{a,b}:\n  "x\\":y",1\n' | ../bin/toon --threads 1 -- --decode            -> same                              exit 0
$ printf 't[1]{a,b}:\n  "x\\":y",1\n' | ../r19/mut/M15/toon_mut --threads 1 -- --decode -> Failed to decode TOON: Expected 1 tabular rows, but got 0   exit 1
$ printf '[1]:\n  - "a\\":b"\n' | ../r19/mut/M15/toon_mut --threads 1 -- --decode       -> Failed to decode TOON: Missing colon after key   exit 1   (original: ["a\":b"], exit 0)
```

R19-5:
```
$ git cat-file -t 494ef82
fatal: Not a valid object name 494ef82
$ git -C /data/projects/toon_bend cat-file -t 494ef82
fatal: Not a valid object name 494ef82
$ grep -rn '494ef82' perf/evidence/ | head -3
perf/evidence/COUNTED.canada.decode.json:16:  "commit": "494ef82",
perf/evidence/COUNTED.canada.encode.json:16:  "commit": "494ef82",
perf/evidence/COUNTED.gsoc_2018.encode.json:16:  "commit": "494ef82",
$ python3 scripts/claims-audit.py
{"files": 16, "absent": [], "findings": 0, "historical_lines_exempt": 5, "laws": 571, "cases": 1076, "disc": {"accepted": 11, "resolved": 4, "open": 0}, "verdict": "OK"}
```
`README.md:153`: "… (`COUNTED.<input>.<mode>.cbdfba6.json`, both counts and both stdout hashes; the files without a commit in their name hold the same comparison against `494ef82`, before EXP-025 to 027)". The rule added in `9459014` only matches `tree of (?:commit )?\`hash\``. `PORT_STATE.md:110` names `494ef82`/`9eb07dc`/`208c0c2` as the historical record of R18-D1, which is fine. The README and evidence citations are live claims.

## Clean areas: compared executions, unmutated port (all on 7d6f79e)

| lens (script, seed) | target | inputs | executions | diffs |
|---|---|---|---|---|
| `lens_scan.py` 19001 (3000, t1), 19002 (20000, t1), 19003 (5000, t1,8 × ±`TOON_SPEC=1`) | EXP-025: random TOON over keys/dotted/quoted keys, bare `-`, `- ` items, headers, tabular rows, blank and WS-only lines (incl. U+3000), TAB/space-TAB/TAB-space indents; line endings LF, CRLF, CR, CR CR LF, blank CRLF pairs, trailing SP/TAB; final endings none/LF/CRLF/CR/CR CR; 0/1/2 BOMs, a BOM at the end, BOM+LF, BOM+CRLF; ±`--no-strict`, ±`--expand-paths safe`, ±`--stats`, `--indent` 0-4 (70% of inputs fail: sanity sample 211 of 300, most `Validation error at line N`) | 28000 | 71000 | 0 |
| `lens_scanx.py` A (L≤4), B (L≤5) | EXP-025 exhaustive: every sequence of ≤4 tokens over `k: 1`, `-`, SP, TAB, CR, LF, U+FEFF, `a:` and of ≤5 tokens over `- x`, 2SP, TAB, CR, LF, `k:`, `[1]:`, CRLF, each × 5 argv (plain, `--no-strict`, `--stats`, `--expand-paths safe`, `--indent 1`) | 210650 | 421300 | 0 |
| `big_scan.py` | 200,000-line CRLF list with BOM; 150,000 lines with blank CRLF runs; strict failure at line 100,002 then a TAB; a 300 KB line ending CR CR LF, then CR at EOF; 500,000 LF + 300,000 CRLF; a TAB-indent at line 80,002. × 4 argv × t1,8, piped | 24 | 72 | 0 |
| `lens_like.py` 19101 (20000, t1), 19102 (5000, t1,8 × ±`TOON_SPEC=1`) | EXP-026: numeric-like strings up to 400+ digits, runs of leading zeros up to 30, signs, `+`/`--`, fractions up to 25 digits, exponents with 0-2 signs and up to 12 digits, one inserted/prefixed/suffixed near-miss (`.`, `e`, `x`, `_`, SP, U+0660, U+FF11, U+2003, U+00A0) as values, keys, inline items, tabular cells, list items, nested keys; delimiters `,`/`\|`/TAB/`tab`, `--key-folding safe` | 25000 | 65000 | 0 |
| `lens_jstr.py` 19201 (20000, t1), 19202 (5000, t1,8 × ±`TOON_SPEC=1`) | EXP-027: JSON strings as keys and values mixing plain bytes, DEL, `~`, SP, escapes (`\"`, `\\`, `\n`, `\/`, `\t`, `A`, surrogate pairs), 2/3/4-byte UTF-8, structural characters. 35% with one bad piece (control bytes 00/01/1F, raw LF/TAB/CR, `\q`, short/invalid `\u`, a lone surrogate, a trailing `\`, invalid UTF-8) right after plain bytes; unterminated strings, trailing garbage, BOM; `--stats`, `--delimiter \|` | 25000 | 65000 | 0 |
| `lens_jstrx.py` | EXP-027 exhaustive: every 2-byte string (256×256) as an array item and as an object key, `--encode` (error columns of every control and invalid byte right after every other byte) | 131072 | 262144 | 0 |
| `big_json.py` | a 136 KB string key/value with `é` and U+1F600 placed at 64 KiB ± 0..3 bytes, through a pipe; 200 KB of plain bytes then 0x01 / `\q` / EOF; 80,000 numeric-like items; ±`--stats` × t1,8 | 36 | 72 | 0 |
| `lens_ws.py` | S4.8 (`ends_ws`/`has_edge_ws`): 25 White_Space scalars + 19 near-misses (U+200B/C/D, U+FEFF, U+180E, U+2060, U+10FFFF, …) in 11 string shapes × 6 positions (value, key, item, tabular cell, list item, folded nested key) × 5 delimiter settings × raw UTF-8 and `\u`-escaped JSON; 10,000 random 1-6 character WS/near-miss/`, \| " \ :` strings | 41460 | 82920 | 0 |
| `lens_merge.py` 19401 (20000, t1), 19402 (5000, t1,8 × ±`TOON_SPEC=1`) | R17-1's repair: blocks that repeat an earlier key (merge, or changed to primitive/array), at depths 0-3, list-item objects, tabular leaves, dotted and quoted keys; late structural errors (bad indent, count mismatch, unterminated string, TAB, stray item), blank lines, CRLF; ±expansion, ±lenient (sample: 274/600 `Duplicate sibling key`, 216 success, 72 validation errors, path-expansion conflicts 1-2) | 25000 | 65000 | 0 |
| `lens_hdr.py` | S2.135/S2.136 header length: 0, 00, 01, 99999999, 100000000, 100000001, zero-padded 10- and 18-digit caps, 4294967296, 2^64, `1\|`, `1\t`, `\|`, TAB, `1,`, spaces, signs, `1\|\|`, `1\|\t`, Arabic-Indic and full-width digits × 9 header forms × 3 argv | 837 | 1674 | 0 |
| `interp.py` | interpreter lane (`bun main.ts port/main.bend --`) on 16 targeted inputs for EXP-025/026/027 and S4.8 | 16 | 32 | 0 |
| `-o FILE` by hand | decode with BOM+CRLF, a TAB failure, empty input; the written file compared by sha256 | 3 | 6 | 0 |
| `diff-fuzz.py` mutate/docs/argv/expand/collide 191001 (4000 each, t1) and 191002 (2000 each, `--switch TOON_SPEC=1`, t8) | repository lenses, new seeds | 30000 | ≥ 60000 | 0 |
| `diff-fuzz.py numbers` 191003 (`--runs 40000`, `--switch TOON_SPEC=1`) | `"inputs": 200, … "number_literals": 40000` | 200 docs | ≥ 400 | 0 |
| `diff-fuzz.py scale` 191004 (`--runs 30000`, t1), 191005 (`--runs 30000`, `--switch TOON_SPEC=1`, t8) | large inputs through pipes | 40 | ≥ 80 | 0 |
| `scripts/stdio-probe.py -- ../bin/toon --threads 1 --` | round 18's two new piped-chunk rows included | 29 rows | — | `"new": [], "verdict": "PASS"` (15 same, 13 KNOWN with their DISC, 1 FIXED) |

Total compared executions of the unmutated port against the original: about 1,094,000 native (1,034,214 from my lenses plus ≥ 60,480 from diff-fuzz), plus 32 on the interpreter lane. The mutant-versus-original runs (corpus, diff-fuzz 191101, lenses) only classify the mutants and are not counted.

Round 18's repairs hold where they were tested. `stdio-probe` passes. The escaped-quote/delimiter shapes (R18-2) appear in `lens_jstr`/`lens_scan`/`lens_merge` inputs with no difference. The `uq` search next to `split` was unpinned (R19-4).

Repository gates run and consistent: `grep -c '^law ' port/LAWS.bend` -> 571; `./scripts/law-coverage.sh` -> `{"laws": 571, "proofs": 571, … "verdict": "OK"}`; `./scripts/state-check.sh docs/PORT_STATE.md` -> `state-check: 0 finding(s)`; `./scripts/claims-lint.sh …` -> `claims-lint: 0 hit(s) in 11 file(s)`; `git diff --stat cbdfba6 HEAD -- port/ ':!port/LAWS.bend' ':!port/PROOF.bend'` is empty, as PORT_STATE says. `./scripts/pin-check.sh` is RED here only because this clone has no `legacy/Toon` link (my setup), so that is not a finding.

## What this round did NOT cover

- the JS lane: I did not build `toon.js`. At the end, available memory was 8 GB with other sessions' jobs running, and round 18 measured the JS lane at 11.5 GB on large inputs. The interpreter lane got only 16 inputs (32 executions)
- `scripts/lanes.sh`, `port-doctor.sh`, `hand-mutants.py`, `floor.sh`; performance of any kind; the new COUNTED e2e comparison (`7d6f79e`) was not re-counted
- proofs for the killed mutants (M5-M14, M16); a proof of the unmutated tree (PORT_STATE's `9459014` proof row was not re-run)
- the `--stats` decode path (`dec.text` forward) got about 20% of `lens_scan` inputs and 1/5 of `lens_scanx`, not a dedicated lens
- mutants of `seg.go`'s CR arm, `scan.lead` and `step.in_str`'s non-fast arm: the new laws name these (NE-029/NE-031 list mutants killed there), so I did not repeat them
- inputs ≥ 16 MiB (round 18 covered EXP-019's boundaries); read errors in the middle of a stream

## Artifacts

Everything is under `/data/tmp/review_R19/`. `bin/toon` and `build.log`. In `r19/`: `cmp.py`, `lens_scan.py`, `lens_scanx.py`, `big_scan.py`, `lens_like.py`, `lens_jstr.py`, `lens_jstrx.py`, `big_json.py`, `lens_ws.py`, `lens_merge.py`, `lens_hdr.py`, `interp.py`, `mut.py`, `proof_capped.sh`, `difffuzz.log`, `mut_all.log`, `proofs_chain.log`. `r19/mut/M1..M16/` each hold a `port/` copy with one edit, `diff.txt`, `build.log`, `toon_mut`, `conform.json`, and for M1/M3/M4/M15 also `proof.log` and `proof.log.summary`.
