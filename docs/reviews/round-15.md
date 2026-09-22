# Round 15: non-author hostile review of the Bend 2 port of Toon

| field | value |
|---|---|
| clone | `/data/tmp/review_R15/clone` (`git clone https://github.com/Dicklesworthstone/toon_bend`) |
| `git rev-parse HEAD` | `37633aae66cbfc5a2f6ae2bead5c7ebdf27a80ac` (subject: `PORT_STATE: next action is round 15; round 14 fully repaired`), the commit the brief required |
| working tree | `git status --short` in the clone shows only `?? oracle` (my symlink to the read-only oracle directory: `.gitignore`'s `oracle/` pattern matches only a directory, so it does not cover a symlink). No tracked file was changed. The claims-audit falsifications ran in a SECOND scratch clone, `/data/tmp/review_R15/audit_copy`, which I cloned from the clone. Each lie was restored from memory right after its run, and `git status --short` there was empty after every one of the 25 runs |
| bend | `bend 2.0.16`, checkout `/tmp/bend` at `15ae0c86f3193b8f645b4bedbc438655b648d0da`, run as `bun /tmp/bend/bend2/main.ts` |
| toolchain | bun 1.4.2 · Ubuntu clang 21.1.8 · Python 3.14.4 · Linux 7.0.0-30-generic x86_64, 8 cores, SHARED host (load 3 to 9, 13 to 23 GB available) |
| port binary (native) | `bun /tmp/bend/bend2/main.ts port/main.bend -o /data/tmp/review_R15/bin/toon` produced sha256 `27787b9babd0a8388b92070437548a1a847a9f62c30119442355b7723cd76465` in 18.1 s. This is the same sha that NE-006/NE-007 and round 14 name, so the byte-reproducible build reproduces again |
| port build (JS) | `/data/tmp/review_R15/bin/toon.js` sha256 `1a273ccba7eb435918086c37672f8f3845d304c4d25c7e500aadc27e793625a0`. It is also identical to round 14's |
| 36 mutant binaries | `/data/tmp/review_R15/mut/<id>/toon.bin`. Their sha256 prefixes are listed in `/data/tmp/review_R15/mutant_shas.txt` |
| oracle | `/data/projects/toon_bend/oracle/toon`, used read-only through the clone's `oracle` symlink, sha256 `980f2b26484f424b74cb0a0b61062183d0038d45101590a38953a82611879a6d`. This is exactly `docs/PIN.toml`'s value |
| date | 2026-09-22 (host local time) |

**Nothing in `/data/projects/toon_bend` was modified.** Its `git status --short` (` M .gitignore`, `?? perf/e2e/`) is exactly the snapshot taken at the start of this session, and both entries are other agents' work. I only read from it: the oracle binary. **`/dp/toon_rust` was not touched at all.** **Nothing was deleted anywhere, at any point**, including the files I created. **No file under `goldens/` was edited** in any tree.

---

## 1. Findings

**HIGH 0 · MEDIUM 5 · LOW 4** (9 total, all new or re-opened genuine findings). This round is **not clean**.

By `references/PARITY-GATE.md`'s strict rule ("a genuine finding changes bytes, an exit code, a proof, or the corpus"), the findings fall into these groups:

- **R15-1 and R15-2 change a proof and the corpus.** 24 new semantic mutants each survive the whole 383-law proof. Six of them break no captured case either, and neither of the repository's two document-level fuzz lenses catches them.
- **R15-3 changes what a gate's exit code means.**
- **R15-4 and R15-5** are certification claims that the repository refutes when you run their own command.
- **R15-7 and R15-8** are defects in the repairs of R14-14 and R14-15, the two spec findings.
- **The rest** are stale facts that no gate checks.

**The port's conversion behaviour survived every lens again: 0 differences in 34 233 compared executions** (§2). The findings are all about the proof's coverage, the corpus's coverage, and the gates that check the documents.

| id | sev | lens | reproduction (`file:line`) | expected | observed | class |
|---|---|---|---|---|---|---|
| **R15-1** | MEDIUM | do the laws bite? (NEW hand-written semantic mutants against the FULL 383-law proof) | `python3 /data/tmp/review_R15/mut15.py && python3 /data/tmp/review_R15/proofmut.py <ids>`. Mutants are defined in `/data/tmp/review_R15/mutants.py`. Sites: `port/f64.bend:962` (`json.is_plain`, the **Neg** arm), `port/encode.bend:23` (`bad_char`: `[` `]` `{` `}` `"` `\`), `port/encode.bend:49` (`is_word`: `null`), `port/text.bend:216,220` (`key_char` digit 9, `key_first` `_`), `port/text.bend:22,24,44` (UTF-8 3- and 4-byte overlong minima, the U+10FFFF maximum), `port/json.bend:438` (recursion limit), `:382` (`\/`, `\b`), `:648` (`E` exponent), `:975` (`\b`/`\f` classes), `:995` (writer A U+001F), `:1013` (writer B U+009F), `port/decode.bend:198` (TOON `\r`) | a mutant that breaks captured cases is KILLED by some law, or the gap is recorded | **24 of 24 SURVIVED `All terms check.`** on the whole 383-law proof (259–338 s each). **18 of them break captured cases on c-1t**, and none of the broken cases has a `golden_<case>` law. For example, N19 (JSON recursion limit 128→129) breaks 6 `jsonerr_deep_*` cases, N11 breaks 18 cases, N07 breaks 6 (`encstr_quoting`, …) and N01/N02 break `decfmt_exp_lower_boundary` (full table in §2). **The calibration holds:** three control mutants were KILLED by exactly the law expected: K17 by `json_exponent_at_k17`, W1 by `is_ws_documented_non_members`, N10 by `golden_fx_enc_key_folding_01`. **The pattern is the one round 14 named, and the author-side hunt did not follow it past `is_ws`.** In `json.is_plain` (`port/f64.bend:957-962`), the def the session wrote TWO laws for, only the `Pos` arm is pinned. The two-line `Neg` arm (1e-5, `Nat.is_le(z, 4n)`) is not, so N01 and N02 survive. `writer_b_escapes_c1` (`port/LAWS.bend:330`) pins U+0085 and not the table's upper edge U+009F (N27). The UTF-8 laws pin the surrogate lower edge (`:315-321`) but no overlong minimum and not the maximum (N15/N16/N18). `bad_char` has 11 arms and 3 pinned by laws (TAB, CR, `:`/LF through goldens); 6 more survive here. Round 14's R14-1 was 5 survivors in 5 defs; this is 24 in 10 defs | NEW (same class as R13-9 / R14-1, disjoint sites) |
| **R15-2** | MEDIUM | corpus and fuzzer coverage (mutants that NO gate of the repository sees) | the mutants N04, N05, N06 (`port/encode.bend:23`), N16 (`port/text.bend:22`), N18 (`port/text.bend:24`) and W2 (`port/text.bend:93`), each run with `scripts/conform.sh … --lane c-1t` and with `scripts/diff-fuzz.py docs` and `mutate` at `--seed 1515 --runs 1500` | a behaviour a clause specifies and the oracle exhibits is caught by the goldens, a law or the fuzzers | **Each mutant passes all 1065 goldens (0 broken), survives the full proof (R15-1), and passes diff-fuzz `docs` and `mutate`, 0 differences in 1500 each.** All six still differ from the pinned oracle on a one-line input. `{"a":"x]y"}` gives oracle `a: "x]y"` and mutant `a: x]y` (N04); the same holds for `{` (N05) and `}` (N06). `["\xe0\x90\x80"]` gives oracle `Failed to read stdin: stream did not contain valid UTF-8`, exit 1, and the mutant `[1]: Ѐ`, exit 0 (N16). `["\xf0\x88\x80\x80"]` gives the same split (N18). `{"a":"ሴx"}` gives oracle `a: ሴx` and mutant `a: "ሴx"` (W2). **The corpus has no string whose ONLY forcing character is `]`, `{` or `}`** (S4.12–S4.16), and no 3- or 4-byte overlong sequence above the lead-byte floor (S2.2). The `docs` lens cannot find them because its `STR` pool (`scripts/diff-fuzz.py:143`) holds `"[1]"`, `"{a}"` and `"x[1]: y"`, and in each of those another forcing character masks the one mutated. My own lens (`lens15.py utf8`) finds N16 in 10 of 430 executions and N18 in 5, so the gap is closable. W2 also shows that `port/LAWS.bend:383`'s comment ("… and NOTHING else") and `docs/PORT_STATE.md:37`'s "two whole-table laws now pin it" overclaim. The members law is complete, but the non-members law samples 27 points, and adding any other code point survives (the port itself is correct). This is the only finding in six rounds where the port could be wrong on a spec clause with every gate green | NEW |
| **R15-3** | MEDIUM | the claim-checking gates themselves (repair of R14-2) | in `/data/tmp/review_R15/audit_copy`: `python3 /data/tmp/review_R15/falsify.py`. Each lie is applied alone, then `claims-audit.py`, `claims-lint.sh` (the 11 files), `state-check.sh` and `converge.sh` run, then the text is restored | a falsified pasted gate line or count is caught | **20 of 23 applied lies pass all three gates with exit 0** (two more had no site). Only 3 are caught: C1, C2 (R14-2's #13 and #9 reproduced exactly) and L20 (a rounds list). Among those that pass: **(a) R14-2's lie #10 EXACTLY** (`docs/PORT_REPORT.md:23`'s law-coverage line with `"unsafe": 9, "unsafe_annotations": 9`, control C3), even though PORT_STATE:111 lists "add up the unsafe count" among its repairs. The new check reads only the prose shape `unsafe N = A @unsafe + B template instances` (`scripts/claims-audit.py:381`) and never the JSON field it compares against. **(b) R14-2's lie #13 EXACTLY** (`7 laws = 1 quantified + 2 closed unit laws + 4 closed whole-pipeline`) passes once the word `earlier` is appended to the line (L19). The `HISTORY` exemption (`:48`) is still LINE-WIDE, only re-triggered by words instead of hex. `README.md:58`, the public "Proved properties" row with `383 laws` and `32 hand-written mutants`, contains "earlier kills stand", so **README's headline counts are unchecked today** (C5: `99 hand-written mutants` passes), along with 4 other count-bearing lines (`docs/PORT_STATE.md:37,39`, `docs/PORT_REPORT.md:25,29`). **(c)** The new `selective` exemption (`:401`) exempts EVERY mutant count on any line that names two `Mnn` ids, so `"mutants": 99, "killed": 99` on `docs/PORT_STATE.md:37` passes (L06). **(d)** The converge field-by-field check needs `tier` AND `clean_tail` in the pasted object (`:365`), so a pasted line without them reading `"verdict": "CONVERGED", "missing": []` passes (L11). **(e) Verdicts in prose are unchecked:** PORT_REPORT's title `HOLD`→`SHIP` (L09) and `converge.sh`: `NOT_CONVERGED`→`CONVERGED` in the verdict list (L08) both pass. **(f) Shapes no rule recognises:** the parity row `rows=33 … excluded=0 … verdict=FULL` (key=value, L01); the doctor JSON `"board":"FULL"` (L05); a floor line with `"stable":999` (L03); a diff-fuzz line with `"differences": 3` and `"verdict": "PASS"` (L14, internally inconsistent and not caught); a clean-build `"ref"` moved to HEAD (L15); the proof row's `bend 2.0.99` and date `2025-01-01` (L02). **(g)** The oracle sha check skips ARCHIVE documents, so PLAN §2's pinned sha `980f2b26…` rewritten to `dead2b26…` passes (L10, `docs/PLAN_TO_PORT_Toon_TO_BEND2.md:42`). The check also looks only BEFORE the hash (`:395`), so a sha written ahead of the word "oracle" is never compared | RE_OPENED (R14-2; (a) and (b) are its own lies #10 and #13) |
| **R15-4** | MEDIUM | the certification report vs its own commands | `docs/PORT_REPORT.md:21`: "every input it gated is byte-identical at the newest commit, `git diff --stat 2dee063 HEAD -- port/ goldens/ docs/FEATURE_PARITY.md` empty"; the header at `:1` repeats the claim; `docs/PORT_REPORT.md:69` says "since then `port/` changed in comments of `port/LAWS.bend` only: `git diff c7239e2 HEAD -- port/`" | the named command prints what the report says | Running the first command prints **3 files, 88 insertions**: `docs/FEATURE_PARITY.md`, `port/LAWS.bend` (+45), `port/PROOF.bend` (+36). Running the second prints `port/LAWS.bend` +96/−8 and `port/PROOF.bend` +60, which is **15 new laws with their proofs, not comments**. `docs/PORT_STATE.md:29` already says "This paragraph used to assert a single empty diff over `port/ goldens/ docs/FEATURE_PARITY.md`; two of this session's own repairs made that untrue". The author found the defect, repaired PORT_STATE, and left the identical false sentence in the Phase-6 report, the document whose rule is "every constant is computed from an artifact". PORT_STATE's per-row argument itself HOLDS (§1 "held" below). Only the report's shortcut is false | NEW |
| **R15-5** | MEDIUM | claims audit (law counts) | `docs/PORT_REPORT.md:41`: "- 360 closed laws, each about ONE value: 65 unit laws … and 295 captured goldens" | the breakdown matches `port/LAWS.bend` (383 = 14 + 74 + 295) | **369 closed laws, 74 unit laws.** This is the same line R14-4 found six short, repaired to 360/65, and nine short again after the session's own nine laws. README (`:58`: 369), PORT_STATE (`:36`: 74) and the board (`:57-58`: 39 + 37) were all updated, and this line was not. `claims-audit.py` still cannot see it: its pattern is `(\d+) closed unit laws` and this line says `65 unit laws` | RE_OPENED (R14-4) |
| **R15-6** | LOW | provenance of the gate lines | `docs/FEATURE_PARITY.md:10` ("Last gate run: 2026-09-20 on the tree of commit `c7239e2`"); `docs/PORT_STATE.md:35` ("`c7239e2` (1065, the doctor's row above)"); `docs/PORT_REPORT.md:46` ("1065 cases on interpreter, c-1t, c-8t, js at `c7239e2` … 2026-09-20"); `docs/PORT_REPORT.md:28` vs `:30`; `README.md:68` | one all-lane run, named consistently | The doctor's row above PORT_STATE:35 is the run on **`2dee063`**. `:27` says so, and `:31` says the `c7239e2` table "is superseded". Three documents still name `c7239e2` as the latest run. PORT_REPORT:30 says "the gate lines are from the `port-doctor.sh` run of local 2026-09-21", but the floor line it pastes at `:28` is `{"repeat":3,…}`, added by commit `a725d10` on 2026-09-20. That doctor run used `--repeat 2` (PORT_STATE:22). README:68 likewise puts "floor STABLE (the original against itself, 3 repeats)" inside "one GREEN `port-doctor.sh` run on the tree of commit `2dee063`". No verdict changes: the floor is STABLE both times | NEW |
| **R15-7** | LOW | spec notation (repair of R14-14) | `docs/EXISTING_Toon_STRUCTURE.md:72` ("Part B's examples use only `⏎`, `⇥` and `→`") and the part E block at `:74-86` | the notation declares every symbol its part's examples use | **Part B also uses `␍`** (7 rows: S2.5, S2.40, S2.42, S9.50, …) **and `␀`** (6 rows: S9.55, S9.57, S9.58, S9.62, …). Neither symbol is declared ANYWHERE in the spec: `grep -n '␍\|␀'` finds only example cells. Part E uses `␍` (5 rows: S2.113, S2.140, S4.201, S9.112, S10.92) and `⇥` (5 rows), while its block declares only `␠`, `⏎`, `→` and `ERR:`. The block written to answer R14-14 ("so that every part … has one") is itself refuted by the rows it governs. Part E's central rule, "apply writer A to the value shown", DID predict stdout on the 20 clause examples I ran against the oracle. The 11 non-matches were flag-dependent examples (`--expand-paths`, lenient) or examples written as event sequences such as `K(id) P(123.0)`, and the notation says every right side is compact JSON. That rule holds | NEW (in R14-14's repair) |
| **R15-8** | LOW | spec clause prediction (repair of R14-15) | `docs/EXISTING_Toon_STRUCTURE.md:156` (S1.32): "… a leading `-` (also `-0`, but **a leading `-` is reachable only as `--flatten-depth=-0`**, S1.7: the SEPARATE word `-0` is a short cluster …)" | the amended sentence predicts the oracle | Run against the oracle, **`--flatten-depth -`** (a separate word) gives `error: invalid value '-' for '--flatten-depth <N>': invalid digit found in string`, exit 2. `--flatten-depth=-5` and `--flatten-depth=--1` give the same message. A leading `-` is reachable in more than the one spelling the amendment names: the lone `-` is a value, not a cluster, and so is any `=-N`. The port matches the oracle on all 7 spellings I ran. Only the amendment's sentence is wrong | NEW (in R14-15's repair) |
| **R15-9** | LOW | stale facts no gate checks | `docs/PORT_STATE.md:13` ("rounds 6 to 13 are non-author subagents"); `scripts/hand-mutants.py:16` ("The set holds 25 mutants and the ids run M01..M12 and M14..M26") | the latest round and the current set | Round 14 is a non-author round too (the rounds table at `:84` says so). `hand-mutants.py` holds **32** mutants up to **M33** (`len(MUTANTS)` = 32; `claims-audit.py` itself computes 32). PORT_STATE:37 cites that docstring as the authority on the M13 gap ("the script's docstring says so"). `claims-audit.py`'s `ROUNDS_SPAN` needs "… found <list>" after the range, so a range that ends one round short in any other sentence is not checked | NEW |
| R15-10 | — (not a finding: confirmation) | the two laws "proved but not SHOWN to bite" | mutants K17 (`port/f64.bend:960`, `Nat.is_le(p, 16n)` → `17n`) and W1 (`port/text.bend:93`, range 9..13 → 9..14) | the session's disclosure (PORT_STATE:37, PORT_REPORT:25) is honest | Both laws DO bite, and each is the ONLY law that does. K17 is KILLED by `json_exponent_at_k17` alone (it breaks `decnum_exponents`, `decfmt_exp_upper_boundary`, `decfmt_exp_compact_and_expand`, none with a golden law). W1 is KILLED by `is_ws_documented_non_members` alone (U+000E, which breaks no case and differs from the oracle: `{"a":"\u000ex"}` gives oracle `a: x` and W1 `a: "x"`). The disclosure was accurate ("not SHOWN", never "does not bite"). **Recorded so the two can become M34/M35 and the next round does not re-raise them** | — |

### Findings I looked for and did NOT find (the claims that held)

| claim | how I checked | verdict |
|---|---|---|
| `main.bend`'s import closure never reaches LAWS/PROOF | `grep '^import'` over `port/*.bend`: main → cli, text; cli → text, bignat, f64, json, encode, decode; nothing imports `LAWS.bend` except `PROOF.bend` | **HOLDS** |
| PORT_STATE:29's per-row argument (lanes/floor/kill-switch inputs unchanged; proof re-run; parity re-run) | `git diff --stat 2dee063 HEAD -- port/ goldens/ ':!port/LAWS.bend' ':!port/PROOF.bend'` is **empty**. `git diff --stat 2dee063 HEAD` lists no `cases/` path and none of the scripts the doctor runs (only `board-refresh.py`, `claims-audit.py`, `hand-mutants.py`). I re-ran the proof: `All terms check.`, 4 min 15 s, 3.99 GB RSS. I re-ran the parity board: the identical line. c-1t, js and `TOON_SPEC=1` c-1t: 1065/1065 each. The interpreter lane on a 43-row sample (every 25th case): 42 passed, 0 failed | **HOLDS** (the report's shortcut is R15-4) |
| 383 laws = 14 quantified + 74 closed unit + 295 golden | `grep -c '^law '` = 383, `^law golden_` = 295, laws whose next line is `for` = 14, so 383 − 14 − 295 = 74. `law-coverage.sh`: `{"laws": 383, "proofs": 383, …, "unsafe": 0, …, "verdict": "OK"}` | **HOLDS** (except PORT_REPORT:41, R15-5) |
| the proof-coverage rows 39 and 37 | each row lists exactly that many distinct names (39/39, 37/37); 39 − 2 quantified + 37 = 74 | **HOLDS** |
| 32 mutants; 16 REFUSED_CV files; 3195 hashes; 703 clauses; 27 probe rows | `len(MUTANTS)` 32; `grep -l REFUSED_CV perf/evidence/*.json \| wc -l` 16; MANIFEST 3195; spec-lint 703; `stdio-probe.py` 27 rows | **HOLDS** |
| pin-check: FOUR non-green rows in a fresh clone, `manifest_hashes` RED structurally | in my clone: `original_present` RED, `original_commit` RED, `manifest_hashes` RED (`changed input /data/tmp/review_R15/clone/-`), `manifest_version` YELLOW, every other row GREEN, `pin-check: RED` | **HOLDS exactly as PORT_STATE:43 now says** (R14-5 repaired) |
| R14-3, R14-9, R14-13 repairs | NE-007 now says `--runs 9`; bead `0m1`'s close reason no longer names the dangling commit as published; `.gitignore` has `/toon` and `/toon.js` | **HOLD** |
| the claims-audit checks that DO work | C1 (R14's #13 without a history word) and C2 (R14's #9, a pasted converge line with all its keys) are caught; L20 (a rounds list whose last entry changed) is caught | **HOLD** |
| the gates bite at HEAD | `harness-selftest.sh -- ./oracle/toon` gives `{"sha":"37633aa",…,"mutations":12,"caught":12,"leaked":[],"untestable":[],…,"verdict":"OK"}`; `clean-build-check.sh HEAD` gives `{"ref":"37633aa",…,"native":"built","js":"built","conform_c1t":{"passed":1065,"failed":0},"verdict":"PASS"}` | **HOLD** |
| part E's "apply writer A to the value shown" | 31 part-E clause examples run through the oracle's `--decode` (`/data/tmp/review_R15/partE.py`): 18 match exactly (8 whole document, 10 the single root key's value), 2 `ERR:` examples match, and the rest need a flag or are event sequences | **HOLDS** for its stated scope (the notation's symbol list is R15-7) |

---

## 2. What I ran

Every line below is this round's own output on this clone.

### The documented gates, re-run

| gate | last line | exit |
|---|---|---|
| `(cd port && bun /tmp/bend/bend2/main.ts PROOF.bend)` | `All terms check.` (4:15 wall, 3 985 756 KB max RSS) | 0 |
| `./scripts/law-coverage.sh` | `{"laws": 383, "proofs": 383, "unproved": "", "ghost_proofs": "", "ghost_cited": "", "uncited": "", "duplicate_laws": [], "duplicate_proofs": [], "unsafe": 0, "unsafe_annotations": 0, "verdict": "OK"}` | 0 |
| `./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t -- bin/toon --` | `"passed":1065,"failed":0,"inconclusive":0,"stderr_compared":true,"verdict":"PASS","oracle_identity_checked":true}` | 0 |
| `./scripts/conform.sh … --lane js -- python3 scripts/js-lane.py bin/toon.js --` | `"passed":1065,"failed":0,"inconclusive":0,"stderr_compared":true,"verdict":"PASS","oracle_identity_checked":true}` | 0 |
| `TOON_SPEC=1 ./scripts/conform.sh … --lane c-1t` | `"passed":1065,"failed":0,…,"verdict":"PASS",…}` | 0 |
| interpreter lane, 43-row sample (`interp-lane.sh`, 90 s budget) | `"passed":42,"failed":0,"inconclusive":0,…,"verdict":"PASS",…}` | 0 |
| `./scripts/parity-board.sh docs/FEATURE_PARITY.md` | `{"rows": 33, "present": 27, "partial": 0, "missing": 0, "excluded": 6, "na": 0, "no_evidence": 0, "verdict": "DEBT"}` | 0 |
| `./scripts/converge.sh docs/PORT_STATE.md` | `{"tier": "T2", "rounds": 14, "clean": 5, "clean_tail": 0, "last_two_clean": false, "non_author_round": true, "open_oq": [], "open_disc": [], "verdict": "NOT_CONVERGED", "missing": ["clean rounds since last reset 0 < 2"]}` | 1 |
| `./scripts/state-check.sh docs/PORT_STATE.md` | `state-check: 0 finding(s)` | 0 |
| `python3 scripts/claims-audit.py` | `{"files": 16, "absent": [], "findings": 0, "historical_lines_exempt": 1, "laws": 383, "cases": 1065, "disc": {"accepted": 13, "resolved": 2, "open": 0}, "verdict": "OK"}` | 0 |
| `./scripts/pin-check.sh docs/PIN.toml` | `pin-check: RED` (4 non-green rows, as PORT_STATE:43 says) | 0 (the script printed RED and exited 0 under my pipe) |
| `./scripts/harness-selftest.sh -- ./oracle/toon` | `{"schema":"p2b.harness-selftest.v1","sha":"37633aa","bend":"bend 2.0.16","host":"Linux-x86_64","lane":"c-1t","mutations":12,"caught":12,"leaked":[],"untestable":[],"scratch":"/data/tmp/review_R15/tmp/hst.qB9fIO","verdict":"OK"}` | 0 |
| `./scripts/clean-build-check.sh HEAD` | `{"ref":"37633aa","export":"/data/tmp/review_R15/tmp/clean-build.8Lhaag","native":"built","js":"built","conform_c1t":{"passed":1065,"failed":0},"verdict":"PASS"}` | 0 |
| `python3 scripts/stdio-probe.py -- bin/toon --` | `{"rows": 27, "same": 13, "known": [14 rows], "fixed": [], "new": [], …, "verdict": "PASS"}` | 0 |
| `python3 scripts/port-lint.py port/*.bend --laws port/LAWS.bend` | `{"files": 10, "findings": 41, "errors": 0, "warnings": 0, "infos": 41, "by_rule": {"PL-02": 41}, "laws": "port/LAWS.bend", "verdict": "OK"}` | 0 |
| `python3 scripts/spec-lint.py docs/EXISTING_Toon_STRUCTURE.md goldens/cases.tsv` | `spec-lint: 703 clauses, 1065 cases, 1065 cases cited, 0 finding(s)` | 0 |
| `python3 cases/build-cases.py --check` / `./scripts/cases-lint.sh goldens/cases.tsv` | `{"cases": 1065, "verdict": "OK"}` / `{"cases": 1065, "errors": 0, "notes": 20, "classes_missing": "", "verdict": "OK"}` | 0 |

I did **not** run the full `port-doctor.sh` (about 1 h 40 m on a shared host) or `floor.sh`. I ran each of the doctor's constituent gates separately above, and spent the budget on 28 full proofs instead.

### Differential lenses (port vs the pinned oracle, byte for byte on stdout, stderr and exit)

| lens | executions compared | differences |
|---|---|---|
| `scripts/diff-fuzz.py` `mutate`, `docs`, `argv`, `expand`, `collide` at `--seed 1515 --runs 1500`; `numbers` (6 documents of 400 texts each) | 7 506 | 0 |
| **my own** `lens15.py`: every scalar 0x00–0x7F plus 14 non-ASCII points in values, keys, list items and tabular cells under 3 delimiters and folding (`chars`); 90 UTF-8 boundary sequences in JSON and TOON (`utf8`); every JSON `\X` and `\u` form and every TOON escape, both writers (`esc`); 221 number texts around both writers' boundaries (`nums`) | 12 652 | 0 |
| **my own** `meta15.py`: 373 corpus JSON inputs through 4 encode option sets, then the oracle's TOON through 3 decode option sets, plus the port's own encode→decode chain against the oracle's chain; nesting depth 1–140, 300, 1000, 3000 for arrays, objects and list items; 588 argv permutations of 2–4 flags | 9 732 | 0 |
| corpus conformance: c-1t, js and `TOON_SPEC=1` c-1t (3 × 1065), the interpreter sample (42), and `clean-build-check`'s c-1t on the exported tree (1065) | 4 302 | 0 |
| `stdio-probe.py` descriptor states | 27 | 0 NEW |
| spec-clause checks run on both programs (S1.32 spellings and hand checks) | 14 | 0 |
| **total** | **34 233 compared executions** | **0 unregistered differences** |

The oracle was also run alone for 31 part-E predictions (`partE.py`).

### The new law mutants (R15-1, R15-2)

Each mutant is ONE exact-text replacement in a fresh copy of `port/` (`/data/tmp/review_R15/mut/<id>/`, with the WHOLE 383-law `LAWS.bend`/`PROOF.bend`, not `hand-mutants.py`'s reduced set). Each was built and run over all 1065 cases on c-1t. The whole proof then ran in the copy. There are 27 full proofs plus 1 baseline, about 2 h 15 min of checker time.

| id | site | mutation | whole proof | cases broken on c-1t |
|---|---|---|---|---|
| N01 | `port/f64.bend:962` | JSON writers plain lower boundary 1e-5 → 1e-4 (`Neg` arm `≤ 4` → `≤ 3`) | **SURVIVED** (296 s) | 3: `decnum_decimals`, `decnum_exponents`, `decfmt_exp_lower_boundary` |
| N02 | `port/f64.bend:962` | … extended to 1e-6 (`≤ 5`) | **SURVIVED** (263 s) | 4: + `decfmt_exp_compact_and_expand` |
| N03 | `port/encode.bend:23` | `bad_char`: `[` no longer forces quotes | **SURVIVED** (282 s) | 1: `encstr_escapes_in` |
| N04 | `port/encode.bend:23` | `bad_char`: `]` | **SURVIVED** (321 s) | **0** (the oracle differs: R15-2) |
| N05 | `port/encode.bend:23` | `bad_char`: `{` | **SURVIVED** (265 s) | **0** (the oracle differs) |
| N06 | `port/encode.bend:23` | `bad_char`: `}` | **SURVIVED** (267 s) | **0** (the oracle differs) |
| N07 | `port/encode.bend:23` | `bad_char`: `"` | **SURVIVED** (296 s) | 6: `encstr_quoting`, `encstr_escapes_in_all`, `enc_tabular_quoting_{comma,pipe,tab}`, `fx_enc_objects_07` |
| N08 | `port/encode.bend:23` | `bad_char`: `\` | **SURVIVED** (282 s) | 2: `encstr_quoting`, `encstr_escapes_in_all` |
| N09 | `port/encode.bend:49` | `is_word`: the string `null` written bare | **SURVIVED** (328 s) | 2: `encstr_quoting`, `fx_enc_primitives_06` |
| N11 | `port/text.bend:216` | `key_char`: digit `9` not a key char | **SURVIVED** (338 s) | 18: `encnum_ints`, `encnum_big_ints`, `encnum_decimals`, `encstr_keys`, … |
| N12 | `port/text.bend:220` | `key_first`: `_` cannot start a bare key | **SURVIVED** (267 s) | 3: `encstr_keys`, `enc_fold_literal_words`, `encstr_keys_literals` |
| N15 | `port/text.bend:44` | UTF-8: scalars up to U+12FFFF accepted | **SURVIVED** (269 s) | 1: `jsonerr_utf8_above_max` |
| N16 | `port/text.bend:22` | UTF-8: 3-byte minimum 2048 → 1024 | **SURVIVED** (337 s) | **0** (the oracle differs) |
| N18 | `port/text.bend:24` | UTF-8: 4-byte minimum 65536 → 32768 | **SURVIVED** (279 s) | **0** (the oracle differs) |
| N19 | `port/json.bend:438` | JSON recursion limit 128 → 129 | **SURVIVED** (319 s) | 6: `jsonerr_deep_128`, `jsonerr_deep_129`, `jsonerr_deep_objects_200`, `jsonerr_deep_mixed_128`, `jsonerr_deep_128_second_line`, `jsonerr_deep_sibling_127` |
| N22 | `port/json.bend:382` | JSON reader: `\/` invalid | **SURVIVED** (301 s) | 1: `encstr_escapes_in` |
| N23 | `port/json.bend:382` | JSON reader: `\b` invalid | **SURVIVED** (295 s) | 1: `encstr_escapes_in` |
| N24 | `port/json.bend:975` | writers: the `\f` class moved to VT | **SURVIVED** (322 s) | 3: `decstr_control_out`, `jsonout_escape_matrix`, `jsonout_escape_keys` |
| N25 | `port/json.bend:975` | writers: the `\b` class moved to BEL | **SURVIVED** (259 s) | 3: same |
| N26 | `port/json.bend:995` | writer A: U+001F written raw | **SURVIVED** (278 s) | 1: `jsonout_escape_matrix` |
| N27 | `port/json.bend:1013` | writer B: U+009F written raw | **SURVIVED** (320 s) | 1: `jsonout_escape_matrix_expand` |
| N28 | `port/decode.bend:198` | TOON decoder: `\r` escape invalid | **SURVIVED** (320 s) | 4: `decstr_quoted`, `jsonout_escape_matrix`, `jsonout_escape_matrix_expand`, `fx_dec_primitives_06` |
| N35 | `port/json.bend:648` | JSON reader: upper-case `E` exponent invalid | **SURVIVED** (267 s) | 2: `encnum_exponents`, `encnum_exponent_forms` |
| W2 | `port/text.bend:93` | White_Space gains U+1234 | **SURVIVED** (300 s) | **0** (the oracle differs) |
| K17 (control) | `port/f64.bend:960` | plain at k = 17 | KILLED by `json_exponent_at_k17` (100 s) | 3 |
| W1 (control) | `port/text.bend:93` | White_Space gains U+000E | KILLED by `is_ws_documented_non_members` (96 s) | 0 (the oracle differs) |
| N10 (control) | `port/text.bend:216` | `.` not a key char with dots allowed | KILLED by `golden_fx_enc_key_folding_01` (158 s) | 36 |

Built but not proved: 8 more mutants that my own analysis predicts dead or equivalent. N13, N21, N31, N36, N37 and N38 each break a case that has a `golden_*` law, so they are predicted KILLED. N17 and N33 are equivalent (0 cases broken, and no input distinguishes them from the oracle). N20 breaks no case and I found no input that separates it from the oracle.

All 24 survivors and 6 of the 8 unproved mutants were built from the clone's own text. Every "the oracle differs" claim was run: `/data/tmp/review_R15/mut/<id>/toon.bin` against `oracle/toon` on the one-line inputs quoted in R15-2. Mutants N04–N06, N16, N18 and W2 were also run through `diff-fuzz.py docs` and `mutate` (6 × 2 × 1500 = 18 000 executions, 0 differences: the fuzzers are blind to them). `lens15.py utf8` catches N16 (10/430) and N18 (5/430).

### Attacking `scripts/claims-audit.py` (R15-3), one lie at a time

| # | file:line | the lie | caught? |
|---|---|---|---|
| L01 | `docs/PORT_STATE.md:21` | parity row `excluded=0 … verdict=FULL` | no |
| L02 | `docs/PORT_STATE.md:19` | proof row `bend 2.0.99`, date `2025-01-01` | no |
| L03 | `docs/PORT_STATE.md:22` | floor `"stable":999` | no |
| L04 | `docs/PORT_STATE.md:36` | law-coverage JSON `"unsafe": 9, "unsafe_annotations": 9` | no |
| L05 | `docs/PORT_REPORT.md:21` | doctor JSON `"board":"FULL"` | no |
| L06 | `docs/PORT_STATE.md:37` | `"mutants": 99, "killed": 99` (line names M-ids) | no |
| L07 | `docs/PORT_REPORT.md:41` | `999 closed laws … 999 unit laws` | no |
| L08 | `docs/PORT_REPORT.md:12` | `converge.sh`: `CONVERGED`, "holds" | no |
| L09 | `docs/PORT_REPORT.md:1` | `HOLD` → `SHIP` | no |
| L10 | `docs/PLAN_TO_PORT_Toon_TO_BEND2.md:42` | oracle sha `dead2b26…` | no |
| L11 | `docs/PORT_REPORT.md:32` | converge JSON without `tier`/`clean_tail`, `"verdict": "CONVERGED"` | no |
| L14 | `docs/PORT_STATE.md:44` | diff-fuzz `"differences": 3` with `"verdict": "PASS"` | no |
| L15 | `docs/PORT_STATE.md:39` | clean-build `"ref":"37633aa"` | no |
| L16 | `docs/PORT_STATE.md:84` | round 14 relabelled `author:` | no |
| L17 | `docs/PORT_REPORT.md:22` | noise appended | no |
| L18 | `docs/PORT_STATE.md:36` | `; earlier` appended (the numbers unchanged) | no (the harmless case, recorded for L19) |
| L19 | `docs/PORT_STATE.md:36` | `7 laws = 1 quantified + 2 closed unit laws + 4 closed whole-pipeline; earlier` | **no** |
| L20 | `docs/PORT_STATE.md:61` | rounds list ends in `1` instead of `15` | **yes** |
| C1 | `docs/PORT_STATE.md:36` | R14's #13 exactly, no history word | **yes** |
| C2 | `docs/PORT_REPORT.md:32` | R14's #9 exactly | **yes** |
| C3 | `docs/PORT_REPORT.md:23` | R14's #10 exactly (`"unsafe": 9`) | **no** |
| C4 | `docs/PORT_STATE.md:37` | `99 mutants in all.` | no |
| C5 | `README.md:58` | `99 hand-written mutants` | **no**: README:58 carries "earlier" |

(L12 and L13 had no unique site.) After every run: `git -C /data/tmp/review_R15/audit_copy status --short` was empty.

### Execution counts per lens

- **Port vs oracle or golden: 34 233 compared executions, 0 differences.** Breakdown: diff-fuzz 7 506 · lens15 12 652 · meta15 9 732 · corpus 4 302 · descriptor states 27 · clause checks 14.
- **Mutant evidence (not counted above):** corpus runs 36 × 1065 = 38 340 comparisons, diff-fuzz on 6 mutants 18 000, and lens15 on 2 mutants 860.
- **Full proofs:** 28, about 2 h 15 min of checker time.
- **Claim-gate falsifications:** 23 applied, 3 caught.

---

## 3. What would make round 16 clean

1. **Laws for R15-1's defs.** Tables should be pinned whole, as `is_ws_all_25_members` did: `bad_char`'s 11 arms, `is_word`'s 3 words, `key_char`/`key_first`, `json.is_plain`'s `Neg` arm at z = 4/5, `w.cls` and both writers' ranges at both edges, the reader's `esc.cls` and exponent class, the TOON decoder's 5 escapes, and the UTF-8 minima and maximum. Then add the 24 mutants to `scripts/hand-mutants.py`, with K17 and W1 as M34/M35.
2. **Cases for R15-2:** a value whose only forcing character is `]`, `{` or `}`, and 3- and 4-byte overlong sequences above the lead floor. Remove the masking companions from `diff-fuzz.py`'s `STR` pool, or add single-character strings.
3. **Fixes to `claims-audit.py`.**
   - Exempt a SPAN rather than a line: a history word should cover only its own clause.
   - Remove the `selective` line exemption.
   - Compare EVERY pasted gate JSON with the gate's live output where the gate is live (law-coverage's `unsafe`), and check diff-fuzz/floor/probe shapes for internal consistency.
   - Check the key=value parity row, the report's title verdict, and PLAN's sha.
4. **Prose repairs:** the three `docs/PORT_REPORT.md` sentences (R15-4, R15-5), the provenance lines of R15-6, part B/E's symbol lists (R15-7), S1.32's sentence (R15-8), and `PORT_STATE.md:13` plus `hand-mutants.py:16` (R15-9).

---

files_written: [`/data/tmp/review_R15/round-15.md`, `/data/tmp/review_R15/mut15.py`, `/data/tmp/review_R15/mutants.py`, `/data/tmp/review_R15/proofmut.py`, `/data/tmp/review_R15/falsify.py`, `/data/tmp/review_R15/lens15.py`, `/data/tmp/review_R15/meta15.py`, `/data/tmp/review_R15/partE.py`, `/data/tmp/review_R15/{mut_pass1.jsonl,proofmut1.jsonl,proofmut2.jsonl,proofmut3.jsonl,mutant_shas.txt,proof.out,c1t.out,fuzz.out,lens15.out,meta15.out,partE.out,interp.out,interp_subset.tsv,lanes_js_spec_probe.out,selftest.out,cleanbuild.out}`, `/data/tmp/review_R15/bin/{toon,toon.js}`, `/data/tmp/review_R15/mut/<36 ids>/` (mutant copies, binaries, proof logs), `/data/tmp/review_R15/clone/` (the fresh clone, plus an untracked `oracle` symlink), `/data/tmp/review_R15/audit_copy/` (scratch clone for falsifications, clean), `/data/tmp/review_R15/tmp/**` (gate scratch). All were kept and nothing was deleted]

goldens_touched: false

ran_original: true
