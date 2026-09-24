# Round 20: non-author hostile review of toon_bend

| field | value |
|---|---|
| reviewed commit | `55ec958f793260d17b85b892ae69a18969826388` (fresh clone `/data/tmp/review_R20/clone`; `git rev-parse HEAD` printed that hash, the expected `55ec958`) |
| original | `oracle/toon` -> `/data/projects/toon_bend/oracle/toon`, sha256 `821287eaf1a6d320ee1ef7604e74e3cefaa42b69445c96abb9dd310782d04030`, equal to `docs/PIN.toml` |
| Bend | `bun /tmp/bend/bend2/main.ts`, `/tmp/bend` at `15ae0c86f3193b8f645b4bedbc438655b648d0da`, `BEND_NO_TELEMETRY=1` |
| tools | bun 1.4.2, Ubuntu clang 21.1.8, Python 3.14.4 |
| port binaries | native `bin/toon` (`bun … port/main.bend -o bin/toon`: 22.4 s wall, exit 0); JS `js/toon.js` (3.0 s, exit 0), run with `scripts/js-lane.py` |
| unmutated corpus | `./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t -- ../bin/toon --threads 1 --` -> `"passed":1076,"failed":0,"inconclusive":0,"stderr_compared":true,"verdict":"PASS","oracle_identity_checked":true` |
| host | shared, 8 cores, 30 GB. 04:33 load 1.3 (5.0 over 15 min), 13 GB available; 05:15 load 2.1, 20 GB available; 05:28 load 3.2, 21 GB available. At most one `bend -o` build or one `PROOF.bend` ran at a time; every proof ran under `r20/proof_capped.sh` (killed above 10 GB; none was killed). No timing here is evidence of speed |
| harness | `r20/cmp.py` (round 19's, paths changed) runs `./oracle/toon ARGV` and `bin/toon --threads T -- ARGV` (or, with `PORT_JS`, `python3 scripts/js-lane.py js/toon.js -- ARGV`) on the same stdin and compares stdout, stderr and exit code byte for byte. `TOON_SPEC` is removed unless a run sets it. "Executions" counts every run of either program |

## Findings (counting rule of 2026-09-23, rules 1-6)

| id | sev | class | what | spec |
|---|---|---|---|---|
| R20-1 | MEDIUM | BEHAVIOR (mutant, corpus gap) | EXP-029: mutant N1 leaves out of the key set the member that joins at the switch, i.e. the 9th key. A later repeat of that key is then appended as a new key: `{"k0":0,…,"k7":7,"k8":8,"k8":99}` encodes to `…k8: 8\nk8: 99` where the original prints `…k8: 99`. It survives the corpus (1076/1076) and the WHOLE 593-law proof (`All terms check.`, 473 s, peak 5.15 GB). It also survives `diff-fuzz.py docs`, `collide` and `mutate` (seed 202001, 2000 inputs each, 0 differences). Only `diff-fuzz.py scale` (1 difference in 20 inputs) and my `lens_dupx`/`lens_dup` catch it. The seven `encode_repeated_key_*` laws repeat k3 as the 8th member (the object is still small), k1, k2 and k0 after the switch. None repeats the member that builds the set, because that member is the 9th and not the 8th (R20-4) | S2.28, S2.29 |
| R20-2 | MEDIUM | BEHAVIOR (gate that lies) | `scripts/claims-audit.py`, R19-5's repair ("every commit a COUNTED file names must be one a reader can check out") never checks 31 of the 32 `COUNTED.*` files. The check is inside the `COUNTED.e2e-corpus.*` loop and reads `j`, a variable left over from the loop before it, so it always tests the last per-input file (`COUNTED.gsoc_2018.encode.json`) and credits that file's result to the three e2e-corpus file names. R19-5's own case, `494ef82` as the "after" commit of `COUNTED.canada.decode.json`, gives `"findings": 0 … "verdict": "OK"`. The same edit in `COUNTED.gsoc_2018.encode.json` gives 3 findings, each naming a `COUNTED.e2e-corpus.*` file. A commit in a FILE NAME (`COUNTED.e2e-corpus.494ef82.json`) is not checked either (`OK`) | (claims) |
| R20-3 | LOW | LAW-COVERAGE (one finding against `scripts/hand-mutants.py`: none of these sites is in its inventory) | Six hand mutants are killed by the corpus but survive the WHOLE 593-law proof. N8/N9/N10: `bad_char` drops `}` / `[` / `{`, so `["a}b"]` gives `[1]: a}b`. N12: `needs_quote` ignores edge whitespace, so `{"k":"x "}` gives `k: x `. P5/P8: `like.ph` arms (7,0) and (1,1), the arms round 19 named in its R19-1 fix direction. Only (4,0) got laws; `["1e10"]` gives `[1]: 1e10`. Five more `like.ph` arms, (6,0), (1,3), (5,0), (2,0) and (7,1) (P6, P7, P9, P10, P11), survive a 30-law reduced proof. I did not run their full proof | S4.12-S4.16, S4.8, S4.9 (numeric-like) |
| R20-4 | LOW | DOCUMENT | EXP-029 switches to the key set when the 9th member joins, not the 8th. `obj.shorter(c, n)` is documented as "whether an entry chain has fewer than n entries", but it answers "at most n": a probe prints `True True False True` for (6-chain, 7), (7-chain, 7), (8-chain, 7), (0-chain, 0). So these are wrong: the comment on `obj.member.small` ("the member that makes it 8 long builds the set"); `perf/EXPERIMENTS.md:1212` ("the table is built once when the 8th arrives"); `perf/NEGATIVE-EVIDENCE.md:727` (a law "at the 8th member (the one that builds the set)"); and the name of the law `encode_repeated_key_eight_members_repeat_at_the_switch`, whose 8th member is a repeat and never reaches the switch. The off-by-one in the documents is why the binding misses R20-1 | S2.28 |

Count under the rule: **BEHAVIOR 2 (MEDIUM 2), LAW-COVERAGE 1 (LOW), DOCUMENT 1 (LOW).** R20-1 and R20-2 are new MEDIUM behavior findings, so this round is NOT clean. No difference was found between the UNMUTATED port and the original on any lane (tables below).

### Mutant table (all mutants of this round)

Each mutant is one or two text replacements in a copy of `port/` (`r20/mut.py`, `r20/mut/<id>/diff.txt`), built natively and run through the whole corpus on c-1t. For each corpus survivor I ran a reduced proof first (`r20/proof_subset.py`, the laws named in the table) and then the WHOLE proof when the reduced one survived.

| id | def | change | corpus c-1t | proof | verdict |
|---|---|---|---|---|---|
| N1 | `json.bend` `obj.member.small` | the key set built at the switch is `kt.of_chain(rev)`: the member that joins there is left out | PASS 1076/1076 | full 593: `PROOF rc=0 killed=0 peak_kb=5152280 secs=473 last: All terms check.` | **R20-1** |
| N2 | `json.bend` `kt.of_chain` | the set holds only the newest key | PASS 1076/1076 | reduced (7 `encode_repeated_key_*`): refused at `encode_repeated_key_nine_members_repeat_after_the_switch` | killed by a law (corpus gap only) |
| N3 | `json.bend` `obj.member.chain` | a repeat in a small object is dropped (the first value wins) | KILLED 1071 (`encstr_duplicate_keys`, …) | reduced: refused at `golden_encstr_duplicate_keys` | killed |
| N4 | `cli.bend` `convert.enc` | `--stats` on encode counts a leading BOM in the JSON text | PASS 1076/1076 | reduced (5 stats laws): refused at `encode_stats_after_mark` | killed by a law (corpus gap only) |
| N5 | `encode.bend` `esc.ch` class 4 | CR written as `\n` | KILLED 1070 | reduced: refused at `cr_in_value_forces_quotes` | killed |
| N7 | `encode.bend` `bad_char` | CR does not force quotes | KILLED 1073 | reduced: refused at `cr_in_value_forces_quotes` | killed |
| N8 | `encode.bend` `bad_char` | `}` does not force quotes | KILLED 1075 (`encstr_only_close_brace_forces_quotes`) | full 593: `rc=0 … secs=359 last: All terms check.` | **R20-3** |
| N9 | `encode.bend` `bad_char` | `[` does not force quotes | KILLED 1075 (`encstr_escapes_in`) | full 593: `rc=0 … secs=362 last: All terms check.` | **R20-3** |
| N10 | `encode.bend` `bad_char` | `{` does not force quotes | KILLED 1075 (`encstr_only_open_brace_forces_quotes`) | full 593: `rc=0 … secs=394 last: All terms check.` | **R20-3** |
| N11 | `encode.bend` `dotted.go` | the root-literal set is always empty | KILLED 1072 | reduced: refused at `golden_fx_enc_key_folding_05` | killed |
| N12 | `encode.bend` `needs_quote` | `T.has_edge_ws(s)` -> `False{}` | KILLED 1066 (`encstr_quoting`, `encstr_ws_edge_sweep`, …) | full 593: `rc=0 … peak_kb=5968644 secs=372 last: All terms check.` | **R20-3** |
| N13 | `text.bend` `kt.is_empty` | every object stays "small" (the same bytes; quadratic time) | PASS 1076/1076 | not run (equivalent in bytes) | caught by `diff-fuzz.py scale --seed 202004`: `"differences": 2, "too_slow": 8`. A 16000-key object takes 142.38 s (0.05 s unmutated, 0.01 s original). Not a finding |
| N14 | `encode.bend` `bad_char` | the active delimiter does not force quotes | KILLED 1060 | reduced: refused at `golden_fx_enc_delimiters_16` | killed |
| P4 | `f64.bend` `like.ph` (4,0) | round 19's M4 | not rebuilt | reduced: refused at `encode_fraction_trailing_zeros_quoted` | R19-1's repair holds |
| P5 | `like.ph` (7,0) | `7n` -> `8n` (= round 19's M5; `f64.bend` is byte-identical to round 19's) | round 19: KILLED 1075 (`encstr_numeric_like_forms`) | full 593: `rc=0 … peak_kb=6221940 secs=361 last: All terms check.` | **R20-3** |
| P8 | `like.ph` (1,1) | `2n` -> `8n` (= round 19's M8) | round 19: KILLED 1074 | full 593: `rc=0 … secs=465 last: All terms check.` | **R20-3** |
| P6, P7, P9, P10, P11 | `like.ph` (6,0), (1,3), (5,0), (2,0), (7,1) | = round 19's M6, M7, M9, M10, M11 | round 19: KILLED | reduced (30 laws: `is_like*`, `encode_fraction*`, `golden_fx_enc_primitives*`): `All terms check.` each; full proof NOT run | likely R20-3, unconfirmed |
| D1 | `decode.bend` `blank.start` | a blank line right after a body's first line is forgotten | KILLED 1068 | reduced: refused at `golden_toonerr_blank_in_list` | killed |
| D3 | `decode.bend` `decide.if` | an over-indented line is popped, never reported | KILLED 1073 | reduced: refused at `golden_toonedge_data_row_test` | killed |

### Reproductions (verbatim; cwd `/data/tmp/review_R20/clone`)

R20-1 (N1):
```
$ I='{"k0":0,"k1":1,"k2":2,"k3":3,"k4":4,"k5":5,"k6":6,"k7":7,"k8":8,"k8":99}'
$ printf '%s' "$I" | ./oracle/toon --encode                                  -> k0: 0 … k7: 7\nk8: 99          exit 0
$ printf '%s' "$I" | ../bin/toon --threads 1 -- --encode                     -> k0: 0 … k7: 7\nk8: 99          exit 0
$ printf '%s' "$I" | ../r20/mut/N1/toon_mut --threads 1 -- --encode          -> k0: 0 … k7: 7\nk8: 8\nk8: 99   exit 0
$ I='{"k0":0,"k1":1,"k2":2,"k3":3,"k4":4,"k5":5,"k6":6,"k7":7,"k8":8,"k9":9,"k8":99}'
  oracle: … k7: 7\nk8: 99\nk9: 9        N1: … k7: 7\nk8: 8\nk9: 9\nk8: 99
$ (repeat of k7, the 8th key: N1 matches the original: the 8th member does not build the set)
$ cat ../r20/mut/N1/diff.txt
372c372
< def obj.member.small(short: Bool, key: String, v: Json, rev: Json, over: KM) -> Frame:
---
> def obj.member.small(short: Bool, key: String, v: Json, +rev: Json, over: KM) -> Frame:
377c377
<       obj.member.grown(JECons{key, False{}, v, rev}, over)
---
>       FObj{JECons{key, False{}, v, rev}, SNil{}, kt.of_chain(rev, T.kt.empty()), over}
$ tail -1 ../r20/mut/N1/proof.log.summary
PROOF rc=0 killed=0 peak_kb=5152280 secs=473 last: All terms check.
$ PORT_BIN=../r20/mut/N1/toon_mut python3 ../r20/lens_dupx.py 1      -> {"executions": 17124, "diffs": 774}
$ python3 scripts/diff-fuzz.py docs|collide|mutate --seed 202001 --runs 2000 -- ../r20/mut/N1/toon_mut --threads 1 --   -> "differences": 0 each
$ python3 scripts/diff-fuzz.py scale --seed 202004 --runs 20000 -- ../r20/mut/N1/toon_mut --threads 1 --               -> "differences": 1, "verdict": "FAIL"
```
The first output also ends up as a TOON document with a repeated sibling key. With `--stats` the token line changes too (`~18 (JSON) → ~20 (TOON)` instead of `~18 → ~18`). Fix direction: a golden and a law that repeat the 9th key (the member whose arrival builds the set), e.g. `{"k0":0,…,"k8":8,"k8":99}`, and a corpus case of 9 or more members with a repeat after the switch. N2 also passes the corpus, so today no corpus case has any repeat after the switch.

R20-2 (in a second local clone `/data/tmp/review_R20/gate`, `git clone clone gate`. The evidence file edits were made there and restored):
```
$ python3 scripts/claims-audit.py | tail -1
{"files": 16, "absent": [], "findings": 0, "historical_lines_exempt": 6, "laws": 593, "cases": 1076, "disc": {"accepted": 11, "resolved": 4, "open": 0}, "verdict": "OK"}
$ sed -i '16s/706f00e/494ef82/' perf/evidence/COUNTED.canada.decode.json      # the "after" commit, R19-5's scratch commit
$ git cat-file -t 494ef82
fatal: Not a valid object name 494ef82
$ python3 scripts/claims-audit.py | tail -1
{"files": 16, "absent": [], "findings": 0, "historical_lines_exempt": 6, "laws": 593, "cases": 1076, "disc": {"accepted": 11, "resolved": 4, "open": 0}, "verdict": "OK"}
$ (restored; the same edit in COUNTED.gsoc_2018.encode.json instead:)
perf/evidence/COUNTED.e2e-corpus.2c33e64.json:0: the after binary's commit 494ef82 is not reachable from HEAD: a reader cannot check that tree out
perf/evidence/COUNTED.e2e-corpus.6d48fcf.json:0: the after binary's commit 494ef82 is not reachable from HEAD: a reader cannot check that tree out
perf/evidence/COUNTED.e2e-corpus.f6cd68e.json:0: the after binary's commit 494ef82 is not reachable from HEAD: a reader cannot check that tree out
{"files": 16, "absent": [], "findings": 3, … "verdict": "FINDINGS"}
$ cp perf/evidence/COUNTED.e2e-corpus.f6cd68e.json perf/evidence/COUNTED.e2e-corpus.494ef82.json; python3 scripts/claims-audit.py | tail -1
{"files": 16, … "findings": 0, … "verdict": "OK"}
```
The cause (`scripts/claims-audit.py`, the hunk added for R19-5): `if isinstance(j, dict) and j.get("kind") == "counted": … (name, side, rev)` sits inside `for name in … if not (name.startswith("COUNTED.e2e-corpus.") …): continue`. The loop parses each file into `cells`, never into `j`. So `j` is whatever the previous loop parsed last (`COUNTED.gsoc_2018.encode.json` in sorted order), and `name` is the corpus file's name. Fix direction: put the reachability test in the per-file `COUNTED.*` loop, where `j` and `name` belong to the same file, and add a harness self-test that plants an unreachable commit in a file that is not the last one.

R20-3 (N8/N12/P5; the mutant binaries against the original):
```
$ printf '["a}b"]' | ./oracle/toon --encode                                -> [1]: "a}b"
$ printf '["a}b"]' | ../r20/mut/N8/toon_mut --threads 1 -- --encode        -> [1]: a}b
$ printf '["a[b","a{b"]' | ../r20/mut/N9/toon_mut --threads 1 -- --encode  -> [2]: a[b,"a{b"      (original: [2]: "a[b","a{b")
$ printf '["a[b","a{b"]' | ../r20/mut/N10/toon_mut --threads 1 -- --encode -> [2]: "a[b",a{b
$ printf '{"k":"x "}' | ./oracle/toon --encode                             -> k: "x "
$ printf '{"k":"x "}' | ../r20/mut/N12/toon_mut --threads 1 -- --encode    -> k: x␠ (od -c: k : sp x sp \n)
$ printf '["1e10","1.0e5"]' | ./oracle/toon --encode                                              -> [2]: "1e10","1.0e5"
$ printf '["1e10","1.0e5"]' | /data/tmp/review_R19/r19/mut/M5/toon_mut --threads 1 -- --encode   -> [2]: 1e10,"1.0e5"
```
(The P5 binary is round 19's M5 build. `diff -q` shows `f64.bend` byte-identical between round 19's clone and this one, and M5's `f64.bend` identical to P5's.) The existing `ends_ws_*` laws check `T.ends_ws` on its own. No law goes through `needs_quote`, so the only place the rule is used is unpinned. `hand-mutants.py` notes that "the `:` and LF arms of `bad_char` were already killed by golden laws". The `{`, `}` and `[` arms are not.

R20-4:
```
$ cat ../r20/probe/shorter.bend   (imports ./json.bend from a copy of port/; prints obj.shorter on chains of 6, 7, 8 entries with n = 7, and 0 with n = 0)
$ BEND_NO_TELEMETRY=1 bun /tmp/bend/bend2/main.ts shorter.bend
True True False True
```
`port/json.bend`: `# S2.28 whether an entry chain has fewer than n entries (a walk of at most n steps)` and `# … no key set while the chain is shorter than 8; the member that makes it 8 long builds the set from the whole chain`. `perf/EXPERIMENTS.md:1212` says "the table is built once when the 8th arrives", and `:1219` says "For an object of fewer than 8 members". `perf/NEGATIVE-EVIDENCE.md:727` says "at the 8th member (the one that builds the set)". The N1 reproduction above is the behavioral proof: a repeat of the 9th key goes wrong, a repeat of the 8th does not.

## Round 19's repairs (item b)

| R19 finding | repair in the tree | this round |
|---|---|---|
| R19-1 (`like.ph` (4,0)) | laws `encode_fraction_trailing_zeros_quoted`, `is_like_zero_in_phase_4_{1p50,0p00,1p05e5}` | P4 (= M4) is refused by `encode_fraction_trailing_zeros_quoted`: **holds**. The other arms named by R19's fix direction are not pinned (R20-3) |
| R19-2 (final CR) | `decode_final_cr_without_lf` | the law restates the exact input of M1, so it holds by construction. `lens_scan` 20501/20503 (native, JS) show 0 differences |
| R19-3 (BOM after line 1) | `decode_bom_after_the_first_line_kept` | same input as M3. Interpreter and JS lanes agree |
| R19-4 (`uq.tr` escaped quote) | `decode_escaped_quote_before_colon_in_cell` | pins the tabular-cell shape. The list-item twin `[1]:\n  - "a\":b"` has no law, but M15 is the same edit, so the tabular law kills it |
| R19-5 (unreachable commits) | new rule in `claims-audit.py` | **does not hold** (R20-2) |

## Clean areas: compared executions of the UNMUTATED port

| lens (script, seed) | target | inputs | executions | diffs |
|---|---|---|---|---|
| `lens_dupx.py` (exhaustive; t1,8 × ±`TOON_SPEC=1`) | EXP-029: n = 1..12 and 16 distinct keys (one is `""`, one is `"k5"`), one repeat of every source p at every later position q, every ordered pair of two trailing repeats, the escape-spelled twin; each alone (`--encode`, `--stats`, `--key-folding safe`), as sibling values, nested two deep with folding, as array items (tabular) | 8562 | 42810 | 0 |
| `lens_dup.py` 20001 (3000, t1), 20002 (20000, t1), 20003 (5000, t1,8 × ±`TOON_SPEC=1`) | EXP-029 random: objects of 0-20 members weighted to 6-9, repeats at random positions or from a small key pool; keys `"a"`/`"a"`, `"b"`/`"b"`, `"é"`/`"é"`, `""`, 300-byte keys that differ in the last byte, `"a.b"`, `"1"`/`"01"`; nested and sibling objects, tabular candidates; `--encode`, `--stats`, `--key-folding safe` ± `--flatten-depth 0-4`, delimiters, auto mode | 28000 | 71000 | 0 |
| `big_dup.py` (t1,8 × ±`TOON_SPEC=1`) | 20000 distinct keys; the same keys twice; 7+7 repeats then 16384 keys then 8 repeats; 16384 + 20000 shuffled repeats with `--stats`; one key 30000 times; 7 keys × 5000; 8 keys × 5000; 20000 small objects of 2-11 members with a repeat (folding); 3000 nested 18-member objects | 9 | 45 | 0 |
| `lens_utf8.py` 20101 (10000, t1), 20102 (4000, t1,8 × ±`TOON_SPEC=1`) | EXP-031: 17 invalid sequences (stray continuation, overlong C0/C1/E0/F0, surrogates ED A0/ED BF, > U+10FFFF, F5, FE/FF, truncated C3/E2 82/F0 9F 98, bad second byte) placed inside a string, key or value, before, after, at EOF without the final LF, inside a number, at a random byte; in valid JSON, JSON errors (trailing comma, missing `:`, `01`, `\q`, trailing garbage, `1e`, empty), valid TOON and TOON errors (TAB indent, count mismatch, unterminated string, over-indent); 0/1/2 BOMs or a BOM mid-text; inputs that are only `""`, a BOM, two BOMs, BOM+`\x80`, `\xef\xbb`; `--stats`, `--no-strict`, `--expand-paths safe`, auto mode; half as file operands with `.json`/`.toon`/`.txt` (sample: 141/300 UTF-8 refusals, 34 successes, the rest JSON/TOON errors) | 14000 | 40000 | 0 |
| `-o FILE` by script | invalid UTF-8 with `-o` (the file keeps `pre`), decode `--stats` truncated, BOM + `--stats` success, TOON error, JSON error; stdout, stderr, exit and file bytes | 7 | 14 | 0 |
| `lens_merge.py` 20401 (15000, t1), 20402 (3000, t1,8 × ±`TOON_SPEC=1`) | item 2: repeated-key merge failure order (round 19's generator; sample 299/600 `Duplicate sibling key`, 204 success) | 18000 | 45000 | 0 |
| `lens_scan.py` 20501, `lens_like.py` 20601, `lens_jstr.py` 20701 (10000 each, t1) | round 19's generators with new seeds (TOON scanner, numeric-like strings incl. phase-4 shapes, JSON strings) | 30000 | 60000 | 0 |
| `lens_ws.py` (`WSSEED=20801`) | item 1: S4.8 exhaustive (25 White_Space + 19 near-misses × 11 shapes × 6 positions × 5 delimiter settings × raw/escaped) + 10000 random | 41460 | 82920 | 0 |
| `diff-fuzz.py` mutate/docs/argv/expand/collide 202001 (3000 each, t1) | repository lenses, new seeds | 15000 | ≥ 30000 | 0 |
| `diff-fuzz.py` mutate/docs/expand/collide 202002 (2000 each, `--switch TOON_SPEC=1`, t8); argv 202007 (3000, `--switch`) | | 11000 | ≥ 33000 | 0 |
| `diff-fuzz.py numbers` 202003 (`--runs 40000`, `--switch TOON_SPEC=1`) | `"inputs": 200, … "number_literals": 40000` | 200 | ≥ 600 | 0 |
| `diff-fuzz.py scale` 202005 (t1), 202006 (`--switch TOON_SPEC=1`, t8) | `"too_slow": 0` both | 40 | ≥ 100 | 0 |
| `scripts/stdio-probe.py -- ../bin/toon --threads 1 --` | 29 rows | — | — | `"new": [], "verdict": "PASS"` (15 same, 13 KNOWN with their DISC, 1 FIXED) |
| **JS lane** (`PORT_JS=js/toon.js`): `lens_dup` 20004 (1500), `lens_utf8` 20103 (1500, files), `lens_dupx` every 10th input, `lens_ws` every 60th (`WSSEED=20802`), `lens_merge` 20403, `lens_like` 20603, `lens_jstr` 20703, `lens_scan` 20503 (600 each), plus 4 mid-size EXP-029 objects (3000 keys ×2, 9 keys × 300 with `--stats`, 500 folded 10-member objects) | | 6951 | 13904 | 0 |
| **interpreter lane** (`r20/interp.py`, `bun main.ts port/main.bend --`) | the 9th-key repeat, a folded 11-member repeat, `"a"`/`"a"`/`""` repeats, BOM + `--stats` encode and decode, two BOMs + `--stats`, a raw surrogate, a JSON error then F4 90 80 80, truncated C3 at EOF on decode, BOM-only, empty, `"\ud800"`, `1.50`/`0.00`/`1.05e5`, `x[1]:\n  -\r` | 14 | 28 | 0 |

Total compared executions of the unmutated port against the original: native about 341,800 from my lenses plus at least 63,700 from `diff-fuzz`; 13,904 on the JS lane; 28 on the interpreter lane. The mutant-versus-original runs (corpus runs of 22 mutants, `lens_dupx`/`lens_dup`/`diff-fuzz` on N1 and N13) only classify the mutants and are not counted.

Gates run on this tree: `claims-audit.py` -> `OK` (but see R20-2); `board-refresh.py` in the second clone changes no file (`git status` empty), and `law-coverage.sh` -> `{"laws": 593, "proofs": 593, … "verdict": "OK"}`; `state-check.sh` -> `0 finding(s)`; `claims-lint.sh` (the 11 files) -> `0 hit(s)`; `grep -c '^law ' port/LAWS.bend` -> 593. `case_manifest.py`'s bare `-` rule matches the original: with a file named `./-` in the working directory, `toon -` and `-o -` both use the standard streams in the original and in the port. I found no way to make the COUNTED-corpus quotient rule lie on the committed files: the three files' cell ratios equal their quotients, and README's 6.15× / 7.63× / 4.96× are the recomputed geometric means of `COUNTED.e2e-corpus.f6cd68e.json`. The rule does admit any ratio from ANY evidence file, including the reverted EXP-032 tree's `6d48fcf` file (6.09×), so a README number from a reverted tree would pass. No README line does that today, so I do not count it as a finding.

## What this round did NOT cover

- whole proofs for P6, P7, P9, P10, P11 (they survived only a 30-law reduced proof), and for any mutant a reduced proof already killed. No proof of the unmutated tree (PORT_STATE's 593-law proof row was not re-run)
- `scripts/lanes.sh`, `port-doctor.sh`, `hand-mutants.py`, `floor.sh`; performance of any kind (N13's timing only classifies a mutant)
- the JS lane on inputs above about 60 KB (the 20000-key `big_dup` inputs ran native only; round 18 measured the JS lane at 11.5 GB on large inputs). The c-8t lane ran only through the lenses marked t1,8 and `diff-fuzz` 202002/202006
- mutants in `decode.bend` beyond D1/D3, and `F.twin.on` users other than those round 19 covered; `J.byte.cls` users were not mutated this round
- inputs of 16 MiB or more; read errors in the middle of a stream
- DOCUMENT review beyond EXP-029's own texts (under 15% of the effort)

## Artifacts

Everything is under `/data/tmp/review_R20/`. `bin/toon`, `bin/build.log`, `js/toon.js`, `js/build.log`; `gate/` (the second clone for the gate experiments; its files match `clone` again). In `r20/`: `cmp.py`, `lens_dup.py`, `lens_dupx.py`, `big_dup.py`, `lens_utf8.py` (+ `in_utf8/` file operands), `lens_merge.py`, `lens_scan.py`, `lens_like.py`, `lens_jstr.py`, `lens_ws.py`, `interp.py`, `mut.py`, `proof_subset.py`, `proof_capped.sh`, `subset_all.sh`/`.log`, `like_subset.sh`/`.log`, `full_proofs.log`, `proofs2.log`, `mut_all.log`, `dec_mut.log`, `js_dup.log`, `js_utf8.log`, `js_lenses.log`, `probe/shorter.bend`, `outo/`, `dash/`, `gsoc.enc.orig.json` (the backup used to restore the gate clone), `moved_out_COUNTED.e2e-corpus.494ef82.json` (the planted file, moved out of the gate clone, not deleted). `r20/mut/<id>/` holds a `port/` copy, `diff.txt`, and where built `build.log`, `toon_mut`, `conform.json`, and where proved `proof.log(.summary)`, `sub/`, `sub_proof.log`.
