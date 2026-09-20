# Round 13 — hostile non-author review of toon_bend @ `1f184e8`

Reviewer: non-author, round 13, 2026-09-20. Clone: `review_R13/clone` (`git rev-parse HEAD` = `1f184e831cfe2043ae89f2d29d20ebd284d771f2`; `git status --short` empty before and after every gate). Binaries I built from that clone: `review_R13/build/toon` (native, sha256 `27787b9babd0a8388b92070437548a1a847a9f62c30119442355b7723cd76465`) and `review_R13/build/toon.js`; also `review_R13/old1230a0d/bin/toon` (the port at `1230a0d`, sha256 `71e268dc…`) and three extra builds for the reproducibility claim. Oracle: `/data/projects/toon_bend/oracle/toon` (`toon 0.2.4`, sha256 `980f2b26…` = `docs/PIN.toml`). The `opt-level=3` incumbent: `…/scratchpad/cargo-o3b/release/toon` (sha256 `0325f112…` = PLAN §2, 862536 bytes). Everything I wrote is under `review_R13/`. Nothing inside `/data/projects/toon_bend` was modified; no file was deleted anywhere.

---

## 1. Findings

**0 HIGH, 1 MEDIUM, 8 LOW.** Every gate a reader is told to run reproduces the line the documents paste (the two exceptions are findings R13-3 and R13-4), the proof gate prints exactly `All terms check.`, all four lanes pass 1065/1065, and **0 differences in conversion content** were found between port and original in my own generators and probes. The three claims this session introduced were re-checked directly: the byte-reproducible build is **true and reproduced** (the section "The byte-reproducible build" in §2), the three new missing-oracle guards **fire correctly** on every input I could construct, and the `opt-level=3` incumbent **exists, is the same program** (it passes all 1065 captured goldens) and its two published ratios reproduce. The MEDIUM is about how the single number `1.389×` is used.

| id | severity | lens | reproduction / file:line | expected | observed | class |
|---|---|---|---|---|---|---|
| **R13-1** | **MEDIUM** | 1a (the new `opt-level=3` numbers) | `docs/PORT_REPORT.md:52` "…(it is 1.389× the pinned build, cv 1.3% / 2.4%, `perf/evidence/INCUMBENT-O3.vs-z-expand.json`): 1.989× on 40000 expanded lines and **0.773× on 20 rows of 1200 fields** … A ratio taken against the pinned build **flatters the port by about 1.4× on this workload**"; same single factor in `docs/PLAN_TO_PORT_Toon_TO_BEND2.md:42` ("so every ratio taken against the pinned z build flatters the port") and `perf/NEGATIVE-EVIDENCE.md:131`. Repro (my captures, same script, `scripts/incumbent-bench.sh --runs 25`, interleaved AB/BA, 50 samples per arm): pinned `z` vs `opt-level=3` on `perf/inputs/wide_rows_1200.json` → 99.89 ms vs 56.98 ms (cv 4.08% / 5.87%), and on `cases/inputs/hand/large_tabular_1500.json` → 5.85 ms vs 4.94 ms (cv 3.14% / 5.21%) | one factor "about 1.4×" describing what the build profile is worth, applied to the two published rows | the profile's advantage is strongly input-dependent: **1.75×** on the wide-rows input (the repository's own two captures give 94.86/55.852 = **1.70×**), **1.18×** on the tabular encode (its own files give 6.3/5.195 = **1.21×**), 1.39–1.44× on the expand input. And neither published move equals 1.4 either: 3.058/1.989 = **1.54**, 1.272/0.773 = **1.65**. README:184 and NE-006:131 do scope the number ("on the one input whose arms are large enough…", "on the expand input"); `docs/PORT_REPORT.md:52` and PLAN §2's inference drop that scope. Separately, the two ratios README:188-189 puts side by side under "the same ratio against the pinned build" are **not a like-for-like pair**: 3.06× was measured with port binary `71e268dc` at 12:00 UTC, 1.989× with `27787b9b` at 21:49 UTC, on a shared host, never interleaved; my interleaved control of those two binaries on that input (24 samples each) is 988.6 ms vs 930.1 ms, so the binaries are within ~6% and the residual is host state, not the build | NEW |
| R13-2 | LOW | 1d (`scripts/ORIGIN.md` vs `git log`) | `scripts/ORIGIN.md:3-16`: "The harness (everything here except the five files named below) was copied from the porting-to-bend2 skill … that was NOT kept for **seven** of them, **each edited once**". Repro: `for f in scripts/*; do cmp -s "$f" ~/.claude/skills/porting-to-bend2/scripts/$f; done` and `git log --follow -- scripts/<f>` | the table names every copied script this repository edited, with the commit that edited it | **eleven** copied scripts differ from the skill's copies, not seven: the table omits `case_manifest.py`, `port-doctor.sh` and `port.sh` — all three edited by `1f184e8`, the commit this table sits in. "Each edited once" is false for two of the seven it does list: `incumbent-bench.sh` (`77a63d9` **and** `1f184e8`) and `harness-selftest.sh` (`1a5da71` **and** `6d41d1c`), and for both the commit the table names is no longer the newest. A re-copy from the skill guided by this table would silently drop the three missing-oracle guards this session added | NEW (same class as round 11's ORIGIN.md finding, re-created by the repairing commit) |
| R13-3 | LOW | 6 | `docs/PORT_REPORT.md:24` pastes `harness-selftest.sh -- ./oracle/toon`: `"mutations":11,"caught":11,…` | the line the gate prints | `scripts/harness-selftest.sh` defines **twelve** mutations, M01…M12 (`scripts/harness-selftest.sh:20-22`, `:507-526`), and `docs/PORT_STATE.md:33` pastes `"mutations":12,"caught":12` from the same gate. Two claim-bearing documents paste two different lines for one gate; PORT_REPORT's is one mutation stale (M12, the stale-count mutation, arrived in `6d41d1c`). `scripts/claims-audit.py` checks no `"mutations":N` in a pasted gate line (see R13-6), which is why it survived | NEW |
| R13-4 | LOW | 6 | `docs/PORT_STATE.md:88` "…`port.sh claims` is `0 hit(s) in 10 file(s)`" | the line `./scripts/port.sh claims` prints | `claims-lint: 0 hit(s) in **11** file(s)` (run in the clone; `./scripts/claims-lint.sh <the ONE list>` prints the same, and `docs/PORT_REPORT.md:35` and the commit message of `1f184e8` both say 11). The sentence that records the repair of R12-9 states the wrong number for the repair it records | NEW |
| R13-5 | LOW | 6 | `README.md:339` "non-integer numbers **45 to 300** times slower, linearly (DISC-013)" and `docs/PORT_REPORT.md:65` "DISC-013 Performance, non-integer numbers **45 to 300** times slower (linear)" | the register's range, which `1f184e8` corrected to "45 to **306**" because 306 is the entry's own largest measurement | R12-10 was repaired in `docs/DISCREPANCIES.md:156`/`:165` only. The same false range survives verbatim in the two documents that summarise the register for a reader. A partial repair | NEW (RE_OPENED content of R12-10 in two other files) |
| R13-6 | LOW | 6 (the gate itself) | `scripts/claims-audit.py:253-268`: README's performance section is checked with `re.findall(r"(\d+\.\d+) ms", line)` and `(\d+\.\d+)×`, i.e. **only values with a decimal point**. Repro, in my clone: replace `\| 1716 ms \| 863 ms \|` with `\| 9999 ms \| 111 ms \|` in `README.md` **and** `"mutations":11,"caught":11` with `"mutations":99,"caught":99` in `docs/PORT_REPORT.md`, then `python3 scripts/claims-audit.py` | the gate that exists to catch exactly this ("every number of README's performance section must come from `perf/evidence/`") fires | `{"files": 16, "absent": [], "findings": 0, …, "verdict": "OK"}`, exit 0. Every median in the new `opt-level=3` table (1716, 863, 56, 72, 2405, 1732 ms) is an integer and therefore outside the gate; so is every number in `docs/PORT_REPORT.md` and `perf/*.md` that is not a README performance-section value, and every pasted gate line except `law-coverage`, `parity-board`, `converge`, `stdio-probe` row counts and `conform` pass counts. Files restored; `git status --short` empty | NEW |
| R13-7 | LOW | 1b (the new guards) | `scripts/case_manifest.py:450-456` (the floor guard) accepts an oracle whose **content** matches but whose **basename** differs, and `floor.sh` then reports a red verdict that names no cause. Repro, from the clone: `ln -s /data/projects/toon_bend/oracle/toon /tmp/x/symlink_oracle; ./scripts/floor.sh goldens/cases.tsv goldens --repeat 1 -- /tmp/x/symlink_oracle` | STABLE, or a refusal that says why | `{"repeat":1,"stable":1003,"unstable":[62 × `usage_*`],…,"oracle_identity_checked":true,"verdict":"UNSTABLE"}`, exit 1. The 62 cases differ only because clap prints argv[0]'s basename in `Usage:` (S1.2, DISC-002); `identity()` compares the file's sha256, so the identity check passes and the floor then reports 62 false UNSTABLE cases. The floor gate is supposed to measure the ORIGINAL's nondeterminism; a renamed oracle is not nondeterminism | NEW |
| R13-8 | LOW | 6 | `perf/NEGATIVE-EVIDENCE.md:137` `- Tally: W0/L5/N2` against the same entry's own list (`:130-132`) of **five** MEASURED ratios — 0.114×, 0.404×, 0.0066×, 1.989×, 0.773× — and its own sentence at `:135` "a **LOSS on every input but the expand one**" | a tally consistent with the entry | the expand row (1.989×) is a measured gain the entry itself excludes from the losses, so the losses are four, not five; W0/L5/N2 counts it as a loss (or counts a sixth result that the entry does not list). The ledger's own taxonomy (`:8-25`) defines no W/L/N counting rule, so the number cannot be reconciled from the file | NEW |
| R13-9 | LOW | 2 (do the laws bite?) | `lensL/mut.py` and `lensL/fullproof.py`: eight new semantic mutants of my own, in defs `scripts/hand-mutants.py` does not touch, each one exact-text replacement in a copy of `port/` under my directory. Three survive **the full 368-law proof** with `All terms check.`: **N04** `port/json.bend:1011` (writer B stops escaping DEL and U+0080–U+009F, S5.64), **N06** `port/text.bend:44` (UTF-8 surrogates D800–DFFF accepted, S2.2), **N07** `port/encode.bend:23` (a TAB in a value no longer forces quotes, S4.12–S4.16) | a mutant that changes the program's bytes is killed by a law, or the behaviour is declared golden-tested only | `bend PROOF.bend` prints `All terms check.` for all three (249 s, 315 s, 309 s). The corpus does catch every one (3, 1 and 6 failing cases on c-1t), and **none of those ten cases has a `golden_<case>` law** — so no law in `port/LAWS.bend`, quantified or closed, pins the writer-B escape table, UTF-8 surrogate rejection or the TAB quoting rule. This is a law-coverage gap, **not a port defect**, and no document claims otherwise (README's Proved/Golden-tested split is exactly right); it is filed because it is the answer to "do the laws bite?" outside the 22 mutants that define the existing `STRONG` verdict | NEW |

Nothing else was found. In particular: **0 differences between port and original in conversion content, on every lane I ran** — see §2 for the counts.

### Checked against the register and the earlier reports before reporting

* The two behavioural differences my environment lens produced are both registered and **accurately described**: a `-o` file at `umask 000` (original 0666, port 0644 — `DISC-008`, whose text gives exactly this and scopes it to "every umask that clears the group and other write bits"), and `RLIMIT_NOFILE=4` (`bend: the event loop failed to open`, exit 1 — `DISC-011`, verbatim). A closed pipe reader, a closed stdout and `/dev/full` are `DISC-006`, whose Resolution names "a closed pipe reader" explicitly and gives the two texts I saw.
* The port printing the literal `toon` in `Usage:` lines when the binary is renamed is `DISC-002` + `OQ-A3` + `S1.2` + `S10.19`: registered, with the original's behaviour measured.
* R13-5 is the content of round 12's R12-10 surviving in two other files; R13-2 is the class of round 11's ORIGIN.md finding re-created. Both are recorded as such.

---

## 2. What I ran

All runs are from the clone at `1f184e8`; `TMPDIR` pointed inside `review_R13` for every one; my own parallelism never exceeded two heavy jobs. The host was shared and busy throughout (load 3–8, 30 GB RAM with 22 GB in use by other agents and swap in use); that matters only for the cv gate of the performance lens, and is stated wherever it does.

### Lens 1 — every gate the documents tell a reader to run, verbatim last line

| command (the document that prescribes it) | last line | rc |
|---|---|---|
| `$BEND_CLI port/main.bend -o <dir>/toon` (README:30, CONTRIBUTING §2:27) | *(no output)*; 33 s; sha256 `27787b9babd0a8388b92070437548a1a847a9f62c30119442355b7723cd76465` | 0 |
| `(cd port && $BEND_CLI PROOF.bend)` (CONTRIBUTING §2:29, AGENTS.md) | `All terms check.` — exactly, no "with N unsafe annotations" line; 4 min 30.66 s wall, 3 908 152 kB peak RSS (`/usr/bin/time -v`) | 0 |
| `./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t -- <toon> --threads 1 --` (CONTRIBUTING §2:28) | `{"lane":"c-1t","cases":[…],"passed":1065,"failed":0,"inconclusive":0,"stderr_compared":true,"verdict":"PASS","oracle_identity_checked":true}` | 0 |
| the same on `--lane c-8t` (`--threads 8`) | `…"passed":1065,"failed":0,…,"verdict":"PASS","oracle_identity_checked":true}` | 0 |
| the same on `--lane js --timeout 20 -- python3 scripts/js-lane.py <toon.js> --` | `…"passed":1065,"failed":0,…,"verdict":"PASS","oracle_identity_checked":true}` | 0 |
| the same on `--lane c-1t` with `TOON_SPEC=1` (README:68, PORT_STATE:29) | `…"passed":1065,"failed":0,…,"verdict":"PASS","oracle_identity_checked":true}` | 0 |
| **interpreter lane, 118-case stratified sample** (`./scripts/conform.sh <sample> goldens --lane interpreter --timeout 90 -- ./scripts/interp-lane.sh bun /tmp/bend/bend2/main.ts port/main.bend --`) | `{"lane":"interpreter",…,"passed":118,"failed":0,"inconclusive":0,"stderr_compared":true,"verdict":"PASS","oracle_identity_checked":true}` | 0 |
| `python3 cases/build-cases.py --check` (CONTRIBUTING §2:30) | `{"cases": 1065, "verdict": "OK"}` | 0 |
| `./scripts/cases-lint.sh goldens/cases.tsv` | `{"cases": 1065, "errors": 0, "notes": 20, "classes_missing": "", "verdict": "OK"}` | 0 |
| `python3 scripts/spec-lint.py docs/EXISTING_Toon_STRUCTURE.md goldens/cases.tsv` (CONTRIBUTING §2:31) | `spec-lint: 703 clauses, 1065 cases, 1065 cases cited, 0 finding(s)` | 0 |
| `./scripts/law-coverage.sh` (CONTRIBUTING §2:32) | `{"laws": 368, "proofs": 368, "unproved": "", "ghost_proofs": "", "ghost_cited": "", "uncited": "", "duplicate_laws": [], "duplicate_proofs": [], "unsafe": 0, "unsafe_annotations": 0, "verdict": "OK"}` | 0 |
| `./scripts/parity-board.sh docs/FEATURE_PARITY.md` | `{"rows": 33, "present": 27, "partial": 0, "missing": 0, "excluded": 6, "na": 0, "no_evidence": 0, "verdict": "DEBT"}` | 0 |
| `python3 scripts/port-lint.py port/*.bend --laws port/LAWS.bend` | `{"files": 10, "findings": 41, "errors": 0, "warnings": 0, "infos": 41, "by_rule": {"PL-02": 41}, "laws": "port/LAWS.bend", "verdict": "OK"}` | 0 |
| `python3 perf/gen-bench-inputs.py --check` | `{"inputs": 9, "drift": [], "verdict": "OK"}` | 0 |
| `./scripts/clean-build-check.sh` (CONTRIBUTING §2:33, PORT_REPORT:74) | `{"ref":"1f184e8","export":"…","native":"built","js":"built","conform_c1t":{"passed":1065,"failed":0},"verdict":"PASS"}` | 0 |
| `./scripts/floor.sh goldens/cases.tsv goldens --repeat 2 -- <oracle>` (PORT_REPORT:69) | `{"repeat":2,"stable":1065,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` | 0 |
| `./scripts/converge.sh docs/PORT_STATE.md` (RUNBOOK §2, PORT_REPORT:71) | `{"tier": "T2", "rounds": 12, "clean": 5, "clean_tail": 0, "last_two_clean": false, "non_author_round": true, "open_oq": [], "open_disc": [], "verdict": "NOT_CONVERGED", "missing": ["clean rounds since last reset 0 < 2"]}` — identical to `docs/PORT_REPORT.md:32` | 1 (as documented) |
| `./scripts/claims-lint.sh <the ONE list>` (AGENTS.md:291, PORT_REPORT:79) | `claims-lint: 0 hit(s) in 11 file(s)` | 0 |
| `./scripts/port.sh claims` | `claims-lint: 0 hit(s) in 11 file(s)` (PORT_STATE:88 says 10: **R13-4**) | 0 |
| `python3 scripts/claims-audit.py` | `{"files": 16, "absent": [], "findings": 0, "historical_lines_exempt": 0, "laws": 368, "cases": 1065, "disc": {"accepted": 13, "resolved": 2, "open": 0}, "verdict": "OK"}` | 0 |
| `./scripts/state-check.sh docs/PORT_STATE.md` | `state-check: 0 finding(s)` | 0 |
| `python3 scripts/state-json.py docs/PORT_STATE.md --check` | the JSON twin, no PLACEHOLDERS, no drift | 0 |
| `./scripts/pin-check.sh docs/PIN.toml` | `pin-check: RED` — four RED rows (`original_present`, `original_commit`, `original_version`, …): the oracle and `legacy/Toon` are not in a clone. `CONTRIBUTING.md:36-38` says this script needs the oracle, so I do not count it as a finding (round 12 reached the same conclusion) | 2 |
| `python3 scripts/board-refresh.py` then `git status --short` | `{"laws": 368, "rows": 27, "rows_without_a_law": ["output framing", "I/O errors"], "lanes_pasted": false}`; **`git status --short` empty** | 0 |
| `python3 scripts/stdio-probe.py --original <oracle> -- <native> --` | `{"rows": 27, "same": 13, "known": [14 rows], "fixed": [], "new": [], "verdict": "PASS"}` — the same 14 KNOWN rows, in the same order, as `docs/PORT_STATE.md:37` | 0 |
| the same through `bin/toon` (`TOON_BEND_BIN` set) | `{"rows": 27, "same": 13, "known": [7], "fixed": [7], "new": [], "verdict": "PASS"}` — identical to PORT_STATE's launcher line | 0 |
| the same on the JavaScript build (`--timeout 20`) | `{"rows": 27, "same": 13, "known": [9], "fixed": [5], "new": [], "verdict": "PASS"}` — identical to PORT_STATE's JavaScript line | 0 |
| the kill-switch probe by hand (`TOON_SPEC=1 <binary> --gpu off -- --encode cases/inputs/hand/large_tabular_1500.json` vs `env -u TOON_SPEC …` vs the original) | all three stdout sha256 `7f28c487…`: PASS | 0 |

`./scripts/port-doctor.sh --threads 8 --original ./oracle/toon -- …` was **not** run end to end (its interpreter lane is about 90 minutes on this host); every gate in its table was run separately above, with the interpreter lane sampled. `python3 scripts/hand-mutants.py` (about an hour) was replaced by my own mutant set, §"Lens 2" below, run through the same reduced proof.

### The three new missing-oracle guards (lens 1b)

| input | expected | observed | rc |
|---|---|---|---|
| `floor.sh … -- ./oracle/toon` in a clone with no `oracle/` | refuse, exit 2 | `floor: the pinned original is not at ./oracle/toon (it is not part of the repository: docs/PIN.toml names its commit and sha256; PLAN §2 has the build command)` | 2 |
| `floor.sh … -- <a copy of the oracle with the execute bit removed>` | refuse | same message with that path | 2 |
| `floor.sh … -- <a symlink to the oracle>` | run | it runs — and reports 62 false UNSTABLE cases: **R13-7** | 1 |
| `port-doctor.sh --threads 1 --original ./oracle/toon --` in that clone | refuse, exit 2 | `port-doctor: the pinned original is not at ./oracle/toon (…)` | 2 |
| `port-doctor.sh --original no_such_binary_xyz --` (a bare name, not on PATH) | the guard deliberately does not fire for a PATH name | it does not fire; the run fails later for an unrelated reason (`error: no bend on PATH and no --checkout`) | 2 |
| `incumbent-bench.sh … --original ./oracle/toon --port <binary>` in that clone | refuse, exit 2 | `incumbent-bench: the original is not an executable file at ./oracle/toon (the pinned original is not part of the repository: …)` | 2 |
| `incumbent-bench.sh … --original <a directory>` | refuse | same message with that path | 2 |
| `incumbent-bench.sh … --original no_such_binary_xyz` (a bare name) | the guard deliberately does not fire | it does not: `pair 1/1`, `ratio original/port = None   verdict RUN_FAILED`, exit 1, the JSON carries `"provenance": null` — the pre-guard behaviour R12-6 complained about, retained for PATH names by design | 1 |

The guards fire on every path-shaped input I could construct (missing, non-executable, a directory) and refuse nothing that should run (a symlink to the real binary, a PATH name, a multi-word command whose head is on PATH). The documented sentence `docs/PORT_REPORT.md:67` "They do NOT [run without the oracle]: `floor.sh`, `port-doctor.sh`, `stdio-probe.py`, `diff-fuzz.py`, `incumbent-bench.sh` (each says so and exits 2)" is now true of all five.

### The byte-reproducible build (lens 1c) — the claim is TRUE

`README.md:174`, `docs/PORT_REPORT.md:54` and `perf/NEGATIVE-EVIDENCE.md:127`: "that binary is what `bend port/main.bend -o <dir>/toon` emits from any commit since `a725d10`: the build is byte-reproducible, and the output BASENAME is its only path input". My four builds:

| source tree | `-o` argument | sha256 |
|---|---|---|
| clone at `1f184e8` | `review_R13/build/toon` | `27787b9babd0a8388b92070437548a1a847a9f62c30119442355b7723cd76465` |
| clone at `1f184e8` | `review_R13/rep/d1/toon` (another directory) | `27787b9b…` — identical |
| clone at `1f184e8` | `review_R13/rep/d2/toon_zz` | `b397e65f10cfdecd7604ff1a64996da43e13696fe2986bd7fdb56d1794a7b7c0` — different, as the claim says |
| `git archive a725d10` | `./toon` | `27787b9b…` — identical |
| `git archive 1230a0d` | `./toon` | `71e268dc1c0c99fc3b6dd83a3a8fd4df7ca0882e6d179fabe59a80e2a701f496` — the exact sha256 in `perf/evidence/EXP-004.*.json`, which independently confirms those captures' provenance |

Only two commits since `a725d10` touch `port/` (`a725d10` itself and `77a63d9`), and both endpoints give `27787b9b…`. The claim holds and is reproducible by a third party.

### The `opt-level=3` incumbent (lens 1a) — it exists, it is the same program, its ratios reproduce

* `sha256 0325f112333e0bae142b9be2dfb5d92ebd6e902f3c519597ec6d222445e8ffb3`, 862536 bytes, `--version` = `toon 0.2.4` — exactly what `docs/PLAN_TO_PORT_Toon_TO_BEND2.md:42` records.
* **It is the same program**: I ran it against the 1065 captured goldens of the pinned build — `{"lane":"o3-original","passed":1065,"failed":0,"inconclusive":0,"stderr_compared":true,"verdict":"PASS"}`. Nothing in the repository proved this before; it is the check that makes "the strongest build of the same source" more than an assertion.
* My re-captures (`scripts/incumbent-bench.sh`, interleaved AB/BA, the same inputs and sha256s as the evidence files):

| capture | published | mine | verdict of mine |
|---|---|---|---|
| `opt-level=3` vs the port, `-d --expand-paths safe`, 40000 lines | 1716 ms vs 863 ms, **1.989×**, cv 3.1% / 3.1%, 18 samples | 1715.08 ms vs 899.63 ms, **1.906×**, cv 4.58% / 2.86%, 18 samples | MEASURED |
| `opt-level=3` vs the port, `-e`, 20 rows of 1200 fields | 56 ms vs 72 ms, **0.773×**, cv 4.4% / 2.3%, 30 samples | 57.27 ms vs 76.70 ms (**0.747×**), cv 14.35% / 20.69% | REFUSED_CV (busy host) — medians reproduce, ratio not claimed |
| pinned `z` vs `opt-level=3`, the expand input | 2405 ms vs 1732 ms, **1.389×**, cv 1.3% / 2.4%, 18 samples | 2440.98 ms vs 1693.47 ms (**1.441×**), cv 4.95% / 5.95% | REFUSED_CV — medians reproduce |
| pinned `z` vs `opt-level=3`, **wide rows** (my own, not in the repository) | — | 99.89 ms vs 56.98 ms (**1.753×**), cv 4.08% / 5.87%, 50 samples | REFUSED_CV — the basis of **R13-1** |
| pinned `z` vs `opt-level=3`, **tabular encode** (my own) | — | 5.85 ms vs 4.94 ms (**1.184×**), cv 3.14% / 5.21%, 50 samples | REFUSED_CV — the basis of **R13-1** |
| the port at `1230a0d` vs the port at HEAD, the expand input (my own) | — | 988.64 ms vs 930.13 ms (**1.063×**, HEAD faster), cv 8.12% / 7.53%, 24 samples | REFUSED_CV — the basis of R13-1's second half |

Every number the documents publish reproduces in medians; the two the documents call MEASURED reproduce as ratios where my host let the cv gate pass. What does **not** reproduce is the single factor: see R13-1.

### Lens 5 — the environment surface

35 port-vs-original comparisons, each a distinct process state (`lensE/env.py`, `lensE/env3.sh` and an inline batch). SAME on: `LC_ALL` = `C`, `de_DE.UTF-8`, `tr_TR.UTF-8`, `C.UTF-8`, `POSIX` (encode, `--stats`, `--help`); `LC_NUMERIC=de_DE.UTF-8`; `TZ=Pacific/Kiritimati`; `PATH` empty; `PATH` unset; `HOME` unset; a completely empty environment; `umask 077` and `umask 777` on a new `-o` file; `RLIMIT_NOFILE=8`; `RLIMIT_FSIZE=1000` with `-o` and with stdout a pipe; a 1 MB argument as INPUT; 10000 arguments; 10000 `-e` flags before the input; SIGPIPE with a small output; a closed stdout reader with a large output (both exit 1); a **read-only** `TMPDIR`; a **nonexistent** `TMPDIR`. **DIFF on five, every one registered and verbatim in its entry**: `umask 000` on a new `-o` file (original 0666, port 0644 — `DISC-008`); `RLIMIT_NOFILE=4` → `bend: the event loop failed to open`, exit 1; `RLIMIT_NPROC=1` → `bend: pthread_create`, exit 1; `RLIMIT_AS=100 MB` and `RLIMIT_DATA=64 MB` → `bend: reservation failed`, exit 1 (the last four are `DISC-011`, which gives those exact three texts and those exact limits). The one state I did **not** probe is a deleted cwd: the machine's destructive-command guard refused the probe and I did not work around it. The stderr TEXT on a failed stdout write (`Failed to write to stdout: Broken pipe (os error 32)` vs `bend: a short write on a standard stream`) and a closed stdout (original exit 0, port exit 1) are `DISC-006`, whose Resolution names "a closed pipe reader" and gives both behaviours.

### Lens 3 — depth and resource limits

`lensD/depth.py`: nested TOON objects at `--indent 1`, decoded by the original, the native build and the JavaScript build, byte-compared.

| depth | input bytes | original | native | JavaScript |
|---|---|---|---|---|
| 50 | 1 520 | exit 0 | SAME | SAME |
| 200 | 21 195 | exit 0 | SAME | SAME |
| 1 000 | 506 395 | exit 0 | SAME | SAME |
| 2 000 | 2 013 895 | exit 0 | SAME | SAME |
| 3 000 | 4 521 395 | exit 0 | SAME | SAME |

No lane breaks below 3000 levels, and the three agree byte for byte with the original everywhere. **I could not close DISC-010's open half** (does the port decode a 12000/16000-level document at the default 8 MiB stack?): at `--indent 1` the input is quadratic in the depth (16000 levels ≈ 128 MB) and `DISC-011`'s measured 47–70 bytes of resident memory per input byte puts that run at roughly 6 GB, on a host that had 0–8 GB free and 18 GB of swap already in use during my session. I stopped at 3000 levels deliberately; the register's statement that this half is unverified is still accurate, and bead `toon_bend-1kv` stays open. The `js` lane showed no earlier cliff than the native one up to 3000, which is consistent with the decoder being an explicit-stack machine.

### Lens 4 — metamorphic / multi-generation round trips

`lensD/meta.py`: generated JSON (10 value shapes, 16 hostile keys, tabular candidates, `1e308`, `-0.0`, `2**53`, embedded LF/TAB/`,`/`|`/`[1]`/`x: y`, `é😀`) encoded under `--indent 0/1/4`, `--delimiter tab|pipe`, `--key-folding safe [--flatten-depth 2]` and `--stats`; each encoding decoded under `--expand-paths safe`, `--no-strict`, both, and two indents; each decoding re-encoded and re-decoded (a third generation); each encoding also decoded by **both** JSON writers and after a random byte mutation, strict and lenient. Port and original compared on stdout, stderr and exit code at every step.

| seed | compared executions | differences |
|---|---|---|
| 13 | 7 844 | 0 |
| 77 | 20 870 | 0 |
| 404 | 20 682 | 0 |
| 909 | 25 788 | 0 |
| 1313 | 26 094 | 0 |
| 5150 | 31 294 | 0 |
| 6161 | 31 274 | 0 |
| 7171 | 36 546 | 0 |
| 8181 | 36 238 | 0 |
| 9191 | 41 778 | 0 |

**278 408 compared executions in this lens, 0 differences** (`lensD/meta_diffs.json` is empty after every run).

### The repository's own fuzz lenses, fresh seeds

| command | last line |
|---|---|
| `diff-fuzz.py mutate --seed 1301 --runs 1500 --jobs 2` | `{"lens": "mutate", "seed": 1301, "inputs": 1500, "differences": 0, "too_slow": 0, "switch": null, "verdict": "PASS"}` |
| `diff-fuzz.py docs --seed 1302 --runs 1500 --jobs 2` | `{"lens": "docs", "seed": 1302, "inputs": 1500, "differences": 0, "too_slow": 0, "switch": null, "verdict": "PASS"}` |
| `diff-fuzz.py argv --seed 1303 --runs 1500 --jobs 2` | `{"lens": "argv", "seed": 1303, "inputs": 1500, "differences": 0, "too_slow": 0, "switch": null, "verdict": "PASS"}` |
| `diff-fuzz.py expand --seed 1304 --runs 1500 --jobs 2` | `{"lens": "expand", "seed": 1304, "inputs": 1500, "differences": 0, "too_slow": 0, "switch": null, "verdict": "PASS"}` |
| `diff-fuzz.py collide --seed 1305 --runs 1500 --jobs 2` | `{"lens": "collide", "seed": 1305, "inputs": 1500, "differences": 0, "too_slow": 0, "switch": null, "verdict": "PASS"}` |
| `diff-fuzz.py numbers --seed 1306 --runs 4000 --jobs 2 --switch TOON_SPEC=1` | `{"lens": "numbers", "seed": 1306, "inputs": 20, "differences": 0, "too_slow": 0, "switch": "TOON_SPEC=1", "verdict": "PASS"}` |
| `diff-fuzz.py numbers --seed 1307 --runs 8000 --jobs 1 --switch TOON_SPEC=1` | `{"lens": "numbers", "seed": 1307, "inputs": 40, "differences": 0, "too_slow": 0, "switch": "TOON_SPEC=1", "verdict": "PASS"}` |
| `diff-fuzz.py docs --seed 2001 --runs 4000 --jobs 1` | `{"lens": "docs", "seed": 2001, "inputs": 4000, "differences": 0, "too_slow": 0, "switch": null, "verdict": "PASS"}` |
| `expand` 2002/4000, `mutate` 2003/4000, `argv` 2004/6000, `collide` 2005/4000 | each `"differences": 0, "too_slow": 0, "verdict": "PASS"` |
| `docs` 3001/3000, `expand` 3002/6000, `mutate` 3003/6000, `collide` 3004/6000, `argv` 3005/8000, `numbers` 3006/8000 (`--switch TOON_SPEC=1`) | each `"differences": 0, "too_slow": 0, "verdict": "PASS"` |
| `docs` 4001/8000, `expand` 4002/8000, `mutate` 4003/8000, `argv` 4004/10000, `collide` 4005/10000, `numbers` 4006/12000 (`--switch TOON_SPEC=1`) | each `"differences": 0, "too_slow": 0, "verdict": "PASS"` |
| `docs` 5001/8000 | `{"lens": "docs", "seed": 5001, "inputs": 8000, "differences": 0, "too_slow": 0, "switch": null, "verdict": "PASS"}` |
| `diff-fuzz.py scale --runs 16000 --jobs 2` | `{"lens": "scale", "seed": 1, "inputs": 18, "differences": 0, "too_slow": 0, "switch": null, "verdict": "PASS"}` — **byte-identical to the line `docs/PORT_STATE.md:37` pastes** |
| `./scripts/harness-selftest.sh --lane c-1t -- ./oracle/toon` (with the oracle symlinked into the clone after the `pin-check` run above) | `{"schema":"p2b.harness-selftest.v1","sha":"1f184e8","bend":"bend 2.0.16","host":"Linux-x86_64","lane":"c-1t","mutations":12,"caught":12,"leaked":[],"untestable":[],"scratch":"…","verdict":"OK"}` — **twelve**, not the eleven `docs/PORT_REPORT.md:24` pastes (**R13-3**) |

### Other checks I ran

* **Thread count.** `README.md` and `docs/PORT_REPORT.md` claim "2 OS threads at `--threads` 1, 8 and 64". Measured from `/proc/<pid>/status` on a 2.4 s run: `Threads: 2` at 1, 8 and 64. Reproduces.
* **The program name under a different basename.** A copy of the port named `zzz` prints `Usage: toon …`; a copy of the original named `zzz` prints `Usage: zzz …`. That is `DISC-002` / `OQ-A3` / `S1.2` / `S10.19`, registered with the original's behaviour measured — not a finding, and the reason R13-7 exists.

---

## 3. Registers and documents re-checked

### `docs/DISCREPANCIES.md` — 15 entries, 13 ACCEPTED + 2 RESOLVED, 0 OPEN

| entry | verdict this round |
|---|---|
| DISC-001, 004, 005, 007, 009, 012, 014, 015 | not re-probed beyond `stdio-probe.py`, which reports every one of their rows exactly as `docs/PORT_STATE.md:37` pastes them, on all three builds, with 0 NEW rows |
| DISC-002 (the literal program name) | verified directly: a copy of the original named `zzz` prints `Usage: zzz …`, a copy of the port prints `Usage: toon …`. The entry, `S1.2`, `S10.19` and `OQ-A3` all say this; accurate |
| DISC-003, DISC-006 | verified directly: a closed pipe reader → original `Failed to write to stdout: Broken pipe (os error 32)` exit 1, port `bend: a short write on a standard stream` exit 1; stdout closed with `>&-` → original exit 0, port exit 1; `/dev/full` → original `No space left on device (os error 28)` exit 1, port the runtime line exit 1. All three are in DISC-006's Resolution verbatim. Accurate |
| DISC-008 (`-o` mode) | verified at three umasks: 000 → 0666 / 0644 (differs, as the entry says), 077 → 0600 / 0600, 777 → 0000 / 0000. The entry's scope sentence ("identical under every umask that clears the group and other write bits") is exactly right |
| DISC-010 (deep nesting) | the port's half is STILL unverified at the depths the entry names; I reached 3000 levels on three lanes with byte-identical output and stopped for memory (see Lens 3). The entry says this half is unverified, so it is accurate — and `toon_bend-1kv` stays open |
| DISC-011 (the resource floor) | verified for two of its cells: `RLIMIT_NOFILE=4` → `bend: the event loop failed to open`, exit 1 (verbatim); `RLIMIT_NOFILE=8` → SAME as the original. Accurate |
| DISC-013 | the register's range is now "45 to 306"; two other documents still say "45 to 300": **R13-5** |
| C-1 … C-11 (bug-compat candidates) | not re-run beyond what the metamorphic and fuzz lenses touch; 0 differences there |

### `docs/OPEN_QUESTIONS.md`

26 entries, all with a terminal resolution word (`RESOLVED …` / `RESOLVED as a divergence …` / `RESOLVED for scope …`); `converge.sh` reports `"open_oq": []`, and the register agrees.

### Documents, one line each

* **README.md** — the Status section's gate lines, the lane counts, the board verdict, the "2 OS threads" claim and the whole build recipe reproduce; every performance median in the `opt-level=3` table matches its evidence file. Wrong: `:339`'s "45 to 300 times" (**R13-5**); and `:188-189` presents two ratios taken with different port binaries in different sessions as one comparison (**R13-1**).
* **CONTRIBUTING.md** — section 2 runs as written and every command passes. Its "what needs the oracle" list (`golden-capture.sh`, `floor.sh`, `pin-check.sh`, `diff-fuzz.py`, `stdio-probe.py`, `incumbent-bench.sh`) and `docs/PORT_REPORT.md:67`'s (`floor.sh`, `port-doctor.sh`, `stdio-probe.py`, `diff-fuzz.py`, `incumbent-bench.sh`) are two different lists, neither containing the other; both are individually true, so I do not count it.
* **docs/PORT_REPORT.md** — the gate table's lines reproduce except the harness-selftest row (**R13-3**); the "Reproduce" recipe runs from HEAD and all five named scripts now refuse a missing oracle and exit 2 (R12-6 fully repaired). Wrong: `:24` (**R13-3**), `:52` (**R13-1**), `:65` (**R13-5**).
* **docs/PORT_STATE.md** — every pasted gate line I ran reproduces verbatim, including the three `stdio-probe` lines, the `law-coverage`, `port-lint`, `spec-lint`, `cases-lint`, `parity-board` and `floor` lines and the `converge` line. Wrong: `:88`'s "`0 hit(s) in 10 file(s)`" (**R13-4**), and `:33`'s "twelve deliberate lies" followed by a list of eleven (the M12 stale-count mutation is missing from the prose list).
* **docs/PLAN_TO_PORT_Toon_TO_BEND2.md** — §2's pins (commit, version, sha256, build command, the `opt-level=3` build's size and sha256) all verified against the binaries on disk; §3's exclusions are all classed and all appear on the board. Its inference "so every ratio taken against the pinned `z` build flatters the port" is directionally right but the single factor is not (**R13-1**).
* **docs/PARITY_RUNBOOK.md** — §1 and §2 accurate; every `./scripts/…` it names exists, and `lanes.sh --interpreter-timeout` (§3.5) is a real flag.
* **docs/FEATURE_PARITY.md** — 33 rows, 27 present, 6 classed exclusions, DEBT; `board-refresh.py` leaves the file byte-identical (`git status --short` empty afterwards, twice).
* **AGENTS.md** — accurate on everything I exercised; the ONE claim-bearing file list matches what `claims-lint.sh` and `port.sh claims` now use (11 files).
* **perf/EXPERIMENTS.md / NEGATIVE-EVIDENCE.md / PERF-LEDGER.md** — the evidence files carry exactly the medians, cvs, sample counts and verdicts the entries quote; `PERF-LEDGER.md` still holds no WIN row, as every document says. Wrong: NE-006's tally (**R13-8**) and its shared single-factor framing (**R13-1**).
* **scripts/ORIGIN.md** — **R13-2**.
* **`scripts/claims-audit.py`** — what it does NOT check: any number in a document that is not a count it computes, a reference id, or a README-performance-section value **with a decimal point**; that excludes every integer median (the whole `opt-level=3` table), every value in `docs/PORT_REPORT.md` and `perf/*.md`, the pasted lines of `harness-selftest.sh`, `clean-build-check.sh`, `floor.sh` (the verdict, not the row count), `conform` per lane, `claims-lint`'s file count, `pin-check`, `state-check`, `port-lint` and `spec-lint`; the arithmetic consistency between two ratios in one table; whether a pasted command's flags exist; and `scripts/ORIGIN.md`'s table against `git log`. Findings R13-3, R13-4, R13-5 and R13-6 all sit in that blind spot, and so did R12-3, R12-4, R12-7 and R12-10. **R13-6** demonstrates it with two deliberate falsifications the gate does not see.

---

## 4. Lens 2 — do the laws actually bite? My own eight mutants

`scripts/hand-mutants.py` has 22 hand-written semantic mutants and kills 22/22 against a **reduced** proof of 123 laws (every non-golden law plus the golden laws matching its `KEEP` regex). `docs/PORT_REPORT.md:28` and `docs/PORT_STATE.md:32` cite that JSON as the "the laws bite" constant. I wrote **eight new mutants of my own**, all in defs the existing 22 do not touch, and ran them through **the same reduced proof, the same way** (`lensL/mut.py`; one exact-text replacement per mutant, applied to a copy of `port/` under my directory; the port itself was never edited).

| id | module | the change | reduced proof (123 laws) | the corpus (1065 cases, c-1t) | full proof (368 laws) |
|---|---|---|---|---|---|
| N01 | `cli.bend` | `--stats` token estimate `max(floor(c/3), w, 1)` instead of `c/4` (S4.310) | **KILLED** in 2 s — `stats_estimate_small` | — | — |
| N02 | `cli.bend` | the `Saved` percentage ten times too large (S4.315) | **KILLED** in 13 s — `stats_pct_6_25` | — | — |
| N05 | `decode.bend` | the scanner's depth `floor(indent / (I+1))` instead of `floor(indent / I)` (S2.107) | **KILLED** in 2 s — `depth_of_indent` | — | — |
| N03 | `encode.bend` | a value starting with `-` is no longer quoted (S4.17) | **SURVIVED** (201 s, `All terms check.`) | **caught**: 12 cases fail (`encstr_quoting`, `encstr_numeric_like`, `enc_tabular_quoting_{comma,pipe,tab}`, …) | **KILLED** in 91 s — `golden_fx_enc_primitives_16` is one of its 12 failing cases |
| N04 | `json.bend` | JSON writer B no longer escapes DEL and U+0080–U+009F (S5.64) | **SURVIVED** (218 s) | **caught**: 3 cases (`decstr_control_out_expand`, `jsonout_escape_matrix_expand`, `jsonout_escape_keys_expand`) | **SURVIVED** (249 s, `All terms check.`) — none of its 3 failing cases has a golden law |
| N06 | `text.bend` | UTF-8 surrogates D800–DFFF accepted (S2.2) | **SURVIVED** (222 s) | **caught**: 1 case (`jsonerr_utf8_surrogate`) | **SURVIVED** (315 s) — `jsonerr_utf8_surrogate` has no golden law |
| N07 | `encode.bend` | a TAB inside a value no longer forces quotes (S4.12–S4.16) | **SURVIVED** (201 s) | **caught**: 6 cases (`encstr_quoting`, `encstr_escapes_in_all`, `fx_enc_primitives_12`, …) | **SURVIVED** (309 s) — none of its 6 failing cases has a golden law |
| N08 | `encode.bend` | the bare words `true` / `false` / `null` are no longer quoted as strings (S4.9) | **SURVIVED** (206 s) | **caught**: 14 cases (`encstr_quoting`, `encstr_root_string_quoted`, `fx_enc_arrays_nested_02`, …) | **KILLED** in 75 s — `golden_encstr_root_string_quoted`, `golden_fx_enc_primitives_04` |

`lensL/fullproof.py` last line: `{"lens": "R13-mutants-full-proof", "rows": [{"id": "N03", "full_proof": "KILLED", …}, {"id": "N04", "full_proof": "SURVIVED", …}, {"id": "N06", "full_proof": "SURVIVED", …}, {"id": "N07", "full_proof": "SURVIVED", …}, {"id": "N08", "full_proof": "KILLED", …}]}`.

**Result: 3 of 8 killed by the reduced proof, 5 by the corpus, and 3 survive even the FULL 368-law proof** — N04, N06 and N07. Only 295 of the 1065 cases are restated as `golden_<case>` laws, and none of the ten cases that catch those three mutants is among them.

**Reading.** This is not a finding against the port: every one of the five is caught by the corpus on the compiled lane, which is exactly what the documents promise for this territory ("Golden-tested: everything else", README FAQ). It is filed as **R13-9** because the brief asks for it and because the three full-proof survivors name three behaviours that no law in the file pins at all. What it does show is the *shape* of the evidence: the `22/22 STRONG` line is about a mutant set chosen for the code the non-golden laws speak about (numbers, carriers, the repeated-key map). Encoder quoting, the two JSON escape tables and UTF-8 validation are pinned by goldens, not by any of the 14 quantified or 59 closed unit laws — a reader who takes `"verdict": "STRONG"` as a statement about the port's behaviour in general would be over-reading it. It is filed as a LOW because it is a real gap in the laws; it is not raised higher because no document claims otherwise.

---

## 5. Counts

| what | number | differences |
|---|---|---|
| my metamorphic generator (10 seeds), port vs original, byte-compared on stdout + stderr + exit code | **278 408** | 0 |
| my environment / descriptor / SIGPIPE probes | **35** | 2, both registered (DISC-008, DISC-011) + 3 more rows of DISC-011 and DISC-006 |
| my nesting-depth probes (3 lanes × 5 depths) | **10** comparisons | 0 |
| the repository's fuzz lenses, 26 fresh seeds (`mutate`, `docs`, `argv`, `expand`, `collide`) | **110 500** generated inputs | 0 |
| the repository's `numbers` lens under `TOON_SPEC=1` (4 seeds) | **32 000** generated number texts, each against the original and the port with and without the switch | 0 |
| the repository's `scale` lens (`--runs 16000`) | 18 sized inputs, with a time verdict | 0, 0 too-slow |
| `stdio-probe.py` rows (native, launcher, JavaScript) | **81** rows | 0 NEW |
| port executions compared against captured goldens | 1065 × 4 (c-1t, c-8t, js, c-1t under `TOON_SPEC=1`) + 118 (interpreter sample) = **4 378** | 0 failures |
| the `opt-level=3` incumbent against the captured goldens | **1 065** | 0 failures |
| the original against its own goldens (`floor.sh --repeat 2`) | **2 130** | 0 unstable |
| mutant binaries against the corpus (lens 2) | 5 × 1065 = **5 325** | 36 failures, all intended |
| interleaved benchmark captures | 6 captures, 9–25 AB/BA pairs each | stdout sha equal in every sample of every one |

**Total port-vs-original compared executions in this round: 278 453 of my own generators + 142 518 of the repository's lenses + 81 probe rows = about 421 000**, plus 4 378 port-vs-golden, 1 065 incumbent-vs-golden and 2 130 floor executions. **0 differences in conversion content anywhere.**

---

## 6. Hygiene

Everything I created is under `/data/tmp/claude-1000/-data-projects-toon-bend/c69eae29-9bfb-4fc0-8aca-9b94f927689d/scratchpad/review_R13/`: the clone, five Bend builds, the mutant copies (`tmp/R13-mutants.*`, `tmp/surv`, `tmp/full`), the lens scripts (`lensD/`, `lensE/`, `lensL/`), the logs and this report. `TMPDIR` pointed inside that directory for every command. Inside `/data/projects/toon_bend` I only **read** files and **ran** `oracle/toon` and the two `cargo-o3*` binaries; nothing there was modified, and `git status` in it was not disturbed by me.

Two writes need declaring, both inside my own clone: (1) for finding **R13-6** I edited `README.md` and `docs/PORT_REPORT.md` in the clone, ran `claims-audit.py`, and restored both from copies I had taken first (`git status --short` empty afterwards — verified); (2) after the `pin-check.sh` run recorded above I created the symlink `clone/oracle/toon → /data/projects/toon_bend/oracle/toon` so that `harness-selftest.sh` could run (`oracle/` is gitignored; `git status --short` stayed empty).

**No file or directory was deleted anywhere**, in the project, in my clone or elsewhere. I ran no `git stash`, `git reset`, `git clean`, `rm -rf` or any other destructive command; the one probe that would have deleted a directory (a deleted cwd, lens 5) was refused by the machine's guard and I did not work around it — that state is therefore **not probed** this round. I signalled no process I did not start; one probe of my own deadlocked on a bug in my own script and was ended by its own `timeout 900`, and I re-ran that lens as a shell script instead. My parallelism stayed at two heavy jobs; I deliberately stopped the nesting-depth lens at 3000 levels rather than spend the ~6 GB that DISC-010's open half would need on a host with 0–8 GB free and 18 GB of swap already in use.


---

## 7. Verdict of this round

Nine genuine findings: **0 HIGH, 1 MEDIUM (R13-1), 8 LOW**. None of them is a wrong byte, a wrong exit code or a false claim of correctness. Under the project's own rule (`docs/PORT_STATE.md`, "a clean round has < 3 new genuine findings"), **round 13 is not clean**, and `converge.sh` stays `NOT_CONVERGED`.

The substance, stated plainly: the port itself came through this round untouched. Four hundred thousand compared executions across five lenses — metamorphic multi-generation round trips, the environment and resource surface, nesting depth on three lanes, the repository's own fuzzers on 26 fresh seeds, and 5 325 mutant-binary executions — produced **zero differences in conversion content**. Every gate reproduces, the build is byte-reproducible exactly as claimed, the three new guards behave, and the `opt-level=3` incumbent is real and is the same program. Eight of the nine findings are documents and harness; the one MEDIUM is a performance sentence that generalises a one-input measurement, on a workload where the repository's own data give 1.70–1.75× instead of 1.389×.

The pattern across rounds 11, 12 and 13 is now unmistakable and worth saying as a recommendation rather than a finding: every round since 9 has found its defects **in the prose about the evidence, not in the evidence**, and `scripts/claims-audit.py` — the gate built to stop exactly that — has a blind spot (R13-6) that let four of this round's eight LOWs through. Extending that script to check integer medians, every pasted gate line, and `scripts/ORIGIN.md` against `git log` would do more for the next round's cleanliness than another lens.
