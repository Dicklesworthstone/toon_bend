# Round 18: non-author hostile review of toon_bend

| field | value |
|---|---|
| reviewed commit | `78a2588a2d467e911c0675cc61c0280edc005c7e` (fresh clone `/data/tmp/review_R18/clone`; `git rev-parse HEAD` printed that hash) |
| original | `oracle/toon` -> `/data/projects/toon_bend/oracle/toon`, sha256 `821287eaf1a6d320ee1ef7604e74e3cefaa42b69445c96abb9dd310782d04030`, equal to `docs/PIN.toml`; `toon 0.2.4` |
| Bend | `bun /tmp/bend/bend2/main.ts`, `/tmp/bend` at `15ae0c86f3193b8f645b4bedbc438655b648d0da`, `BEND_NO_TELEMETRY=1` |
| tools | bun 1.4.2, Ubuntu clang 21.1.8, Python 3.14.4 |
| port binaries | `bin/toon` (native, 42.4 s, peak RSS 2.85 GB, exit 0), `bin/toon.js` (JS build, exit 0), mutants `r18/mut/K*/toon_mut` |
| unmutated corpus | `./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t -- bin/toon --threads 1 --` -> `"passed":1076,"failed":0,"inconclusive":0,...,"verdict":"PASS"` |
| host | shared, 8 cores, 30 GB. Load 6.6 at the start (16:08), 12 to 17 during the run (another session held an 18.7 GB `bend -o` job), 6.5 at the end (17:04). Available memory dipped to 4 GB once; no proof was started below 7 GB available. No timing here is evidence of speed |

Harness: `r18/cmp.py` runs `./oracle/toon ARGV` and `<port> --threads T -- ARGV` (or `python3 scripts/js-lane.py bin/toon.js -- ARGV`) on the same stdin and compares stdout, stderr and exit code byte for byte; `TOON_SPEC` is removed unless a run sets it. "Executions" counts every run of either program.

## Behavior findings

No unmutated difference between the port and the original was found in any lens (tables below). All behavior findings are mutants that change bytes and that neither the corpus (c-1t 1076/1076) nor the proof (`All terms check.`) catches.

| id | sev | class | what | spec |
|---|---|---|---|---|
| R18-1 | MEDIUM | BEHAVIOR (mutant) | EXP-019's chunk assembly (`port/main.bend` `chunks.all`) is not guarded by any gate. Two mutants survive: K1 keeps only the newest chunk, and K2 joins the older chunks in reverse order. Both corrupt every piped input larger than one read (about 64 KiB). The corpus cannot reach the path: conform feeds stdin from a regular file, which arrives in ONE 16 MiB read. The proof book does not import `main.bend`. The run NE-023 cites as evidence (`diff-fuzz.py scale --seed 1919`, default size) never exceeds 54,890 bytes, so it cannot reach a second chunk either (see R18-D2) | S8.5, S8.6 |
| R18-2 | MEDIUM | BEHAVIOR (mutant) | K8, `split.tr` (`port/decode.bend:372-373`): a backslash inside quotes no longer protects the next character when a line is split on the delimiter. `[2]: "a\",b",c`, a quoted inline item or tabular cell that holds an escaped quote followed by the delimiter, then fails with `Unterminated string`. Neither the corpus nor any of the 518 laws has such an item | S2.125 |
| R18-3 | LOW | BEHAVIOR (mutant) | K3, EXP-024 `lit.esc` (`port/decode.bend:249-250`): after a bad escape, the LAST escaped character is reported instead of the first. The card, NE-028 and the def's own comment all say "keeps the first bad escape". None of the seven `decode_literal_*` laws, and no corpus case, has two escapes after a bad one | S9.105, S2.123 |
| R18-4 | LOW | BEHAVIOR (mutant) | K7, `ascii_ws.cls` (`port/decode.bend:557`): FF (U+000C) is no longer skipped before a key. A quoted key after a leading FF is then read as the unquoted key `"k"` (quotes kept) | S2.126 |
| R18-5 | LOW | BEHAVIOR (mutant) | K9, `ucut.cls` (`port/decode.bend:797`): a backslash OUTSIDE quotes in a header's field segment escapes the next character. `k[1]{a\},b}:` then decodes successfully (exit 0) where the original says `Missing colon after key` | S2.132 |

### Mutant table (all mutants of this round)

Each mutant is one text replacement in a copy of `port/` (`r18/mut.py`, `r18/mut/<id>/diff.txt`), built natively, then run through the whole corpus (`conform.sh ... --lane c-1t`). A mutant that survived the corpus was then checked with the WHOLE 518-law `PROOF.bend` (`r18/proof_capped.sh`: one proof at a time, killed above 10 GB; none was killed).

| id | def | change | corpus c-1t | `PROOF.bend` (518 laws) | observable (original vs mutant) | verdict |
|---|---|---|---|---|---|---|
| K1 | `main.bend` `chunks.all` | `chunks.join(rest, c)` -> `chunks.join(Nil{}, c)` | PASS 1076/1076 | cannot catch it: PROOF.bend and LAWS.bend import bignat, f64, text, json, decode, encode and cli, never `main.bend` (`grep -n '^import' port/PROOF.bend port/LAWS.bend`) | yes: 200 KB and 409 KB pipes | **R18-1** |
| K2 | `main.bend` `chunks.all` | `chunks.join(List.reverse(rest), c)` | PASS 1076/1076 | as K1 | yes: 409 KB pipe | **R18-1** |
| K3 | `decode.bend` `lit.esc` (True arm) | `badc` -> `c` | PASS 1076/1076 | `PROOF rc=0 killed=0 peak_kb=4608492 secs=438 last: All terms check.` | yes | **R18-3** |
| K4 | `decode.bend` `lit.esc` (unknown escape) | the escaped character is kept, no failure | **KILLED** 1072/1076 (`toonerr_bad_escape`, `toonerr_unicode_escape`, `toonlenient_bad_escape`, `fx_dec_validation_errors_05`) | not run | — | killed |
| K5 | `decode.bend` `lit.close` | a bad escape is reported before characters after the closing quote | **KILLED** 1075/1076 (`toonerr_item_header_key_escape`) | not run (NE-028 says `decode_literal_trailing_before_bad_escape` kills it) | — | killed |
| K6 | `cli.bend` `o.reads_text` | `Bool.or(decode, stats)` -> `decode` | **KILLED** 1054/1076 (`stats_small`, `stats_users`, ... 22 cases) | not run | — | killed |
| K7 | `decode.bend` `ascii_ws.cls` | FF (12) dropped from the class | PASS 1076/1076 | `PROOF rc=0 killed=0 peak_kb=4526452 secs=363 last: All terms check.` | yes (quoted key only) | **R18-4** |
| K8 | `decode.bend` `split.tr` | a backslash inside quotes does not set `esc` | PASS 1076/1076 | `PROOF rc=0 killed=0 peak_kb=4461976 secs=418 last: All terms check.` | yes | **R18-2** |
| K9 | `decode.bend` `ucut.cls` | `Bool.and(inq, c == 92)` -> `c == 92` | PASS 1076/1076 | `PROOF rc=0 killed=0 peak_kb=4562456 secs=361 last: All terms check.` | yes | **R18-5** |
| K10 | `decode.bend` `unesc.tr` (True arm) | after a bad escape, `Bool.pick(U32, e, c, badc)` | PASS 1076/1076 | not run | no: once `bad` is set the arm keeps `esc` False forever, so `e` is always False and the mutant cannot fire. `"\q\z": 1` and `"a\q\n"[1]: x` give the same bytes as the original | EQUIVALENT by construction (my mutant design error). Not a finding |

### Reproductions (verbatim; cwd `/data/tmp/review_R18/clone`)

R18-1 (K1, K2): 409 KB through a pipe. The unmutated port matches the original, and K2 fed the same bytes as a PATH also matches. Only the piped, multi-chunk read differs:
```
$ python3 -c "import json;print(json.dumps({'k':list(range(60000))}))" > ../r18/in/k60k.json      # 408898 bytes
$ cat ../r18/in/k60k.json | ./oracle/toon --encode | sha256sum
aaef852b7f11bbd5e82745fe9ac034c499e21796b736ec8f0680654d33e5c1f4  -
$ cat ../r18/in/k60k.json | ../bin/toon --threads 1 -- --encode | sha256sum
aaef852b7f11bbd5e82745fe9ac034c499e21796b736ec8f0680654d33e5c1f4  -
$ cat ../r18/in/k60k.json | ../r18/mut/K2/toon_mut --threads 1 -- --encode | sha256sum
Failed to parse JSON: trailing characters at line 1 column 2
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  -
$ cat ../r18/in/k60k.json | ../r18/mut/K1/toon_mut --threads 1 -- --encode | sha256sum
Failed to parse JSON: trailing characters at line 1 column 7
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  -
$ ../r18/mut/K2/toon_mut --threads 1 -- --encode ../r18/in/k60k.json | sha256sum          # as a path: one read
aaef852b7f11bbd5e82745fe9ac034c499e21796b736ec8f0680654d33e5c1f4  -
```
Only the scale lens at a non-default size sees it: `diff-fuzz.py scale --seed 180002 --runs 20000 -- ../r18/mut/K1/toon_mut --threads 1 --` -> `{"lens": "scale", "seed": 180002, "inputs": 20, "differences": 19, ...,"verdict": "FAIL"}`. At the default size, seed 1919 (the run NE-023 cites) -> `{"lens": "scale", "seed": 1919, "inputs": 20, "differences": 0, ..., "verdict": "PASS"}` on K1; its largest input is `"bytes": 54890`.
Fix direction: move `chunks.join`/`chunks.all` into a module the proof book imports and state a law (for example `chunks.all([c2, c1]) == c1 ++ c2` on closed three-chunk instances), or add a gate that pipes a document larger than 64 KiB (conform only takes regular files).

R18-2 (K8):
```
$ printf '[2]: "a\\",b",c\n' | ./oracle/toon --decode ; echo "exit $?"
[
  "a\",b",
  "c"
]
exit 0
$ printf '[2]: "a\\",b",c\n' | ../r18/mut/K8/toon_mut --threads 1 -- --decode ; echo "exit $?"
Failed to decode TOON: Unterminated string: missing closing quote
exit 1
```
The same holds for a tabular cell (`k[1]{a,b}:\n  "x\",y",2`, where the original gives `"a": "x\",y"`) and for the pipe delimiter (`[2|]: "a\"|b"|c`). The unmutated port matches the original on all three, and on the exhaustive lens below.

R18-3 (K3):
```
$ printf '%s\n' 'k: "\q\z"' | ./oracle/toon --decode              -> Failed to decode TOON: Invalid escape sequence: \q   (exit 1)
$ printf '%s\n' 'k: "\q\z"' | ../bin/toon --threads 1 -- --decode  -> Failed to decode TOON: Invalid escape sequence: \q   (exit 1)
$ printf '%s\n' 'k: "\q\z"' | ../r18/mut/K3/toon_mut --threads 1 -- --decode -> Failed to decode TOON: Invalid escape sequence: \z   (exit 1)
$ printf '%s\n' '[2]: "a\x\n",b'  -> original and port `\x`, K3 `\n`
```

R18-4 (K7): input `\f"k": 1\n` (`$'\f"k": 1\n'`), `--decode`: the original prints `{ "k": 1 }` (exit 0). K7 prints `{ "\"k\"": 1 }` (exit 0). With an unquoted key (`\fk: 1`), K7 and the original agree.

R18-5 (K9): input `$'k[1]{a\\},b}:\n  1,2\n'`, `--decode`: the original says `Failed to decode TOON: Missing colon after key` (exit 1). K9 prints `{ "k": [ { "a\}": 1, "b": 2 } ] }` (exit 0). Input `$'k[1]{a\\"},b}:\n  1,2\n'`: the original says `Unterminated string: missing closing quote`, K9 says `Missing colon after key`.

## Document findings (separate; about 10% of the effort)

| id | sev | class | claim | refuted by |
|---|---|---|---|---|
| R18-D1 | LOW | DOCUMENT | `docs/PORT_STATE.md:20-21` and `docs/FEATURE_PARITY.md:10,66-69` cite the proof run "on the tree of `9eb07dc`" and the four-lane PASS "on the tree of `494ef82`". PORT_STATE backs the carry-over with "`git diff 494ef82 HEAD -- port/ ':!port/LAWS.bend' ':!port/PROOF.bend'` is empty" | Neither commit exists in the published repository, nor in the author's working checkout: `git cat-file -t 494ef82` -> `fatal: Not a valid object name 494ef82` (the same for `9eb07dc`, in the clone and in `/data/projects/toon_bend`). The document's own check fails: `git diff --stat 494ef82 HEAD -- port/ ...` -> `fatal: bad revision '494ef82'`. So the lanes and proof rows point at trees nobody can check out. `claims-audit.py` still says `"findings": 0`, so it does not check commit references |
| R18-D2 | LOW | DOCUMENT | `perf/NEGATIVE-EVIDENCE.md` NE-023 and the EXP-019 card list, as the lever's evidence, "conform c-1t 1076/1076", stdio-probe's 27 rows and "`diff-fuzz.py scale` seed 1919, 20 inputs, 0 differences" | Mutant K1 passes the corpus (1076/1076) and scale seed 1919 (0 differences; largest input 54,890 bytes, below one pipe read). The cited evidence cannot see the multi-chunk path the lever changed. Only the one-off 19 MB pipe run, which is not in any gate, could. See R18-1 |

Checked and consistent: `./scripts/law-coverage.sh` -> `{"laws": 518, "proofs": 518, ... "verdict": "OK"}`; `grep -c '^law ' port/LAWS.bend` -> 518; `python3 scripts/claims-audit.py` -> `{"files": 16, "absent": [], "findings": 0, ..., "laws": 518, "cases": 1076, ..., "verdict": "OK"}`.

## Clean areas: compared executions, unmutated port (all on 78a2588)

| lens (script, seed) | target | inputs | executions | diffs |
|---|---|---|---|---|
| `lens_a.py` (t1) | EXP-018: 34 argv shapes (`--stats` in every position, `--sta`/`--stat`/`--stats=true`, `-e`/`-d`/`-ed`/`-de`, `--decode` twice, `--decode --encode` in both orders, `--`, `-`, `--indent 0`, `--expand-paths`) × 147 inputs (JSON and TOON bodies; 0, 1, 2 BOMs; 9 invalid UTF-8 shapes before, after, inside and after a BOM). Also files with `.json`/`.toon`/`.txt`/none/`.JSON`/`.Toon` extensions for auto mode, with and without `--stats`/`--encode`/`--decode` before and after the path | 35400 | 70800 | 0 |
| `lens_o.py` (t1) | `-o FILE` and `-o -`, 6 modes × 8 inputs (BOM, invalid UTF-8, empty); compares the written file too | 192 | 384 | 0 |
| `lens_b.py` (t1) | EXP-019: 0 and 1 byte, a lone BOM; 16 MiB −1/0/+1, 17 MiB −1/0/+1, 18 MiB+7, with a 2-, 3- or 4-byte scalar, an invalid byte or a cut-short lead ENDING AT the 16 MiB (and 17 MiB) boundary; TOON at the same sizes; a BOM plus `--stats`. Each as a path, a pipe, a regular-file stdin at offsets 0/1/5, and a FIFO. Slow writers: 1-byte bursts every 0.5 ms (196 KB), 3-byte, 4097-byte/1 ms and 65537-byte/10 ms bursts (196 KB and 2 MB) | 435 comparisons | 870 | 0 |
| `lens_c.py` 18001 (t1); 18002, 18003, 18004 (t1,8 × ±`TOON_SPEC=1`) | EXP-021 and EXP-013: random JSON of every line shape (nested objects, tabular, primitive and mixed arrays, list items holding objects, `[]`/`{}`/`[[]]`/`[{}]` at every depth; keys and values with edge White_Space and near-misses) with delimiters (6 spellings), `--indent` 0..17, `--key-folding safe`, `--flatten-depth`, `--stats`; then the original's TOON decoded back (±expansion, lenient, `--stats`) | 12000 enc + 10493 dec | 94961 | 0 |
| `lens_h.py` (t1) | S4.8 exhaustively: 25 White_Space scalars and 22 near-misses, in 10 string shapes, × root/value/key/item/cell/list item/nested, × 4 delimiter settings, plus key folding | 15040 | 30080 | 0 |
| `lens_d.py` 18101 (t1), 18103 (t1,8), 18104 (t1) | EXP-022/024: TOON with quoted literals over `" \ n t r u / b x , \| TAB é U+3000 U+00A0 : 0 U+2028`, trailing WS/near-miss on values, keys, inline items, tabular cells and list items; ±`--no-strict`, ±expansion, `--indent 0/4` | 9000 | 21000 | 0 |
| `lens_e.py` (t1) | EXP-024 exhaustive: every `"`+w for w over `" \ n q SP a` up to length 5 (9331 words); over `" \ t , u` up to length 4 with 5 trailing WS suffixes; over `" \ x \| t` up to length 4 with U+2003/U+FEFF suffixes. 7 positions (value, list item, first and second inline item, first and second tabular cell, root) + 2 lenient | 133182 | 266364 | 0 |
| `lens_g.py` (t1) | S2.106: one WS scalar or near-miss inserted at EVERY position of 15 template documents (headers, fields, delimiters, list items, dotted keys); a WS pair at every line end, strict/lenient/expand | 4725 | 9450 | 0 |
| `lens_f.py` 18201 (4000), 18202, 18203, 18204 (5000 each) (t1,8) | the repeated-key merge (R17-1's repair): keys from {a, b, c} (sometimes `a.b`, `b.c`, `a.b.c`, `"a"`, `"a.b"`) repeated at depths 0-4, objects merged 2-4 times, list-item objects, later indentation/count/quote errors, ±expansion, ±lenient, `--indent 0`. About 40% end in `Duplicate sibling key`. Plus the R17-1 input and two variants by hand | 19000 | 57000 | 0 |
| `diff-fuzz.py` mutate/docs/argv/expand/collide 180101 (3000 each, t1) and 180102 (2000 each, `--switch TOON_SPEC=1`, t8) | repository lenses, new seeds | 25000 | ≥ 50000 | 0 |
| `diff-fuzz.py numbers` 180103 (`--runs 3000`, 2800 literals), 180202 (`--runs 40000`, 40000 literals, t8) | both with `--switch TOON_SPEC=1` | 214 docs, 42800 literals | ≥ 428 | 0 |
| `diff-fuzz.py scale` 180201 (`--runs 20000`, t1), 180203 (`--runs 60000`, `--switch TOON_SPEC=1`, t8) | large inputs through pipes (multi-chunk) | 40 | ≥ 80 | 0 |
| JS lane (`bin/toon.js` via `scripts/js-lane.py`) | `lens_c` 18301 (300 docs), `lens_d` 18302 (400), `lens_f` 18303 (300); an 18,513,716-byte JSON as a path (stdout identical, exit 0; the JS process peaked at 11.5 GB RSS, which is why the pipe variant at that size was NOT run); a 2,970,383-byte JSON through a pipe with `--encode --stats` (stdout and stderr identical) and its TOON through a pipe with `--decode` (identical) | 1536 docs + 3 large | 2842 + 6 | 0 |

Total compared executions of the unmutated port against the original: about 604,000 native (550,909 from my lenses plus ≥ 50,500 from diff-fuzz) and about 2,850 on the JS lane. Mutant-versus-original runs are used only to classify the mutants: the corpus runs, the probes above, and diff-fuzz scale 180001/180002/1919 on K1.

## What this round did NOT cover

- the interpreter lane, `scripts/lanes.sh`, `port-doctor.sh`, `stdio-probe.py`, `hand-mutants.py`; performance of any kind
- the JS lane on a ≥ 16 MiB PIPE input: the path run peaked at 11.5 GB RSS, above this round's memory budget
- proofs for the killed mutants (K4, K5, K6) and for K1/K2: the proof book does not import `main.bend`, so a proof run could not change the verdict
- read errors in the middle of a stream (EIO after the first chunk); I found no way to produce one without root
- repeated keys with `--expand-paths safe` path-versus-literal conflicts beyond about 1% of `lens_f` (strict duplicate detection fires first); R17's `gen_dup2`/`gen_merge` shapes were not re-run
- the numeric fast/spec twins beyond diff-fuzz `numbers` (42,800 literals); no new mutants there (round 17 covered EXP-012)

## Artifacts

Everything is under `/data/tmp/review_R18/`: `bin/` (the builds, `build.log`); `r18/cmp.py`, `lens_a.py` ... `lens_h.py`, `lens_o.py`, `gen_big.py`, `mut.py`, `proof_capped.sh`, `difffuzz.log`, `lens_c_bg.log`, `lens_f_bg.log`, `proofs_chain.log`; `r18/mut/K1..K10/` (each a `port/` copy with one edit, `diff.txt`, `toon_mut`, `conform.json`, and for K3/K7/K8/K9 `proof.log` + `proof.log.summary`); `r18/in/` (generated inputs, FIFOs).
