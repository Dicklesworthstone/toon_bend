# Port state — Toon → Bend 2

<!-- Read FIRST on every resume; rewritten at the END of every session.
     Facts only, each with the command that produced it. -->

## Where we are

| field | value |
|---|---|
| phase | 4 parity gate (NOT converged: three non-author rounds in a row were dirty, with falling severity; round 9 is running) and 5 performance (three number levers PROVISIONAL, the key carriers ledgered); the reference port is complete and green on every lane |
| tier | T2 |
| bend | `bend 2.0.16` (checkout `15ae0c8`, run as `bun /tmp/bend/bend2/main.ts`); drift vs the previous pin: none, same pin since Phase 0 (VERSION-DRIFT) |
| last updated | 2026-09-20 by Claude (Claude Code session, author of phases −1 to 5; rounds 6 to 9 are non-author subagents) |

## Last gate outputs (paste, do not paraphrase)

| gate | command | result | date |
|---|---|---|---|
| lanes | `BEND_CLI='bun /tmp/bend/bend2/main.ts' ./scripts/lanes.sh goldens/cases.tsv goldens port/main.bend --threads 8 --interpreter-timeout 120` at `d80251a` (1060 cases) | `{"lanes":[{"lane":"interpreter","verdict":"PASS","passed":1060,"failed":0},{"lane":"c-1t","verdict":"PASS","passed":1060,"failed":0},{"lane":"c-8t","verdict":"PASS","passed":1060,"failed":0},{"lane":"js","verdict":"PASS","passed":1060,"failed":0}],"stderr_compared":true,"timeouts_seconds":{"interpreter":120.0,"compiled":5.0,"build":600},"verdict":"PASS"}` | 2026-09-20 |
| proofs | `(cd port && bun /tmp/bend/bend2/main.ts PROOF.bend)` at `4c3cccc` | `All terms check.` | 2026-09-20 |
| parity | `./scripts/parity-board.sh docs/FEATURE_PARITY.md` | `{"rows": 33, "present": 27, "partial": 0, "missing": 0, "excluded": 6, "na": 0, "no_evidence": 0, "verdict": "DEBT"}` | 2026-09-20 |
| floor | `./scripts/floor.sh goldens/cases.tsv goldens --repeat 3 -- ./oracle/toon` | `{"repeat":3,"stable":1065,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` | 2026-09-20 |

Notes on these lines:

- lanes: the FIRST complete all-lane PASS was at `1230a0d` (1053 cases, the same JSON shape, every lane 1053/1053). The single interpreter failure of the earlier runs was the HARNESS: `scripts/interp-lane.sh` captured stderr in a plain file, where `-o /dev/stderr` overwrites (case `flag_output_dev_stderr`; the pinned original does the same under `2>file`); the wrapper uses a pipe now. HEAD is `4c3cccc` = `d80251a` + round 8's change to the shell's stdin read (`read.failed` in `port/main.bend`) + 5 usage cases; at `4c3cccc` `./scripts/conform.sh goldens/cases.tsv goldens --lane <lane> -- <port>` → PASS 1065/1065 on c-1t, c-8t and js, with `TOON_SPEC` unset and with `TOON_SPEC=1`; the four-lane run at `4c3cccc` was started and its log is `scratchpad/lanes_4c3cccc.log` (see Next action).
- proofs: 368 laws = 14 quantified + 59 closed unit laws + 295 closed whole-pipeline `golden_<case>` laws; unsafe 0 = 0 `@unsafe` + 0 template instances, bend 2.0.16 @ `15ae0c8`; 4 min 04 s. `./scripts/law-coverage.sh` → `{"laws": 368, "proofs": 368, "unproved": "", "ghost_proofs": "", "ghost_cited": "", "uncited": "", "duplicate_laws": [], "duplicate_proofs": [], "unsafe": 0, "unsafe_annotations": 0, "verdict": "OK"}`.
- law admission: `./scripts/law-mutation.sh port <defs> --file <module>` → INCONCLUSIVE on `bignat.bend`, `f64.bend` and `text.bend` (its textual operators find no valid site in this code style). `python3 scripts/hand-mutants.py` (22 hand-written semantic mutants of the fast twins, the key carriers and the repeated-key map, reduced proof of 123 laws) → `{"laws_in_proof": 123, "reduced": true, "mutants": 22, "killed": 22, "survived": [], "not_evidence": [], "verdict": "STRONG"}`. Its FIRST pass had 7 survivors of 16, and the pass over the 12 mutants of round 7's new code had 1: each is pinned by a closed law now (`div_pow10_*`, `int_fit_*`, `int_text_*`, `short_of_digits_*`, `kt_collision_*`, `ks_bucket_*`, `golden_encstr_duplicate_keys*`). What NO law can pin: `Nat` is unbounded in the checker, so the 2^48 − 1 bound of the compiled lanes is pinned only on the guard defs (`int_fit_refuses_2p48`, `int_text_15_digits_refused`) and by the goldens.
- `python3 scripts/port-lint.py port/*.bend --laws port/LAWS.bend` → `{"files": 10, "findings": 41, "errors": 0, "warnings": 0, "infos": 41, "by_rule": {"PL-02": 41}, "laws": "port/LAWS.bend", "verdict": "OK"}` (the 41 infos are recursions whose depth is a nesting depth, a limb count bounded by the 800-digit clamp, at most 17 digits, 16 hash bits, or the height of a balanced bucket).
- `python3 scripts/spec-lint.py docs/EXISTING_Toon_STRUCTURE.md goldens/cases.tsv` → `spec-lint: 703 clauses, 1065 cases, 1065 cases cited, 0 finding(s)`.
- `python3 cases/build-cases.py --check` → `{"cases": 1065, "verdict": "OK"}`; `./scripts/cases-lint.sh goldens/cases.tsv` → `{"cases": 1065, "errors": 0, "notes": 20, "classes_missing": "", "verdict": "OK"}`. Corpus: 1005 → 1053 (Phase 4) → 1060 (round 7) → 1065 (round 8); every re-capture added hashes and changed none (MANIFEST 3195 hashes).
- `./scripts/pin-check.sh docs/PIN.toml` → `pin-check: YELLOW`, one YELLOW row, `manifest_version`: `golden-capture.sh` writes no `version:` line into MANIFEST, so that row cannot turn green without a hand edit of `goldens/`, which is forbidden; identity is carried by `original_version` GREEN (`toon 0.2.4`) and the executable sha256 in MANIFEST's provenance.
- what no case can express: `python3 scripts/stdio-probe.py -- <port>` (20 descriptor-state rows against the original) → native binary `{"rows":20,"same":10,"known":10,"new":[],"verdict":"PASS"}`; through `bin/toon` 10 SAME, 7 rows that are KNOWN on the bare binary are repaired by the launcher, 3 KNOWN (`/dev/full`: DISC-003, DISC-006), 0 NEW; JavaScript build 0 NEW. `python3 scripts/diff-fuzz.py scale --runs 16000 -- <port> --` → `{"lens": "scale", "seed": 1, "inputs": 18, "differences": 0, "too_slow": 0, "switch": null, "verdict": "PASS"}` (the same lens on the binary of `1230a0d`: `"too_slow": 5`).
- incumbent: `scripts/incumbent-bench.sh` captures are in `perf/evidence/`. MEASURED: EXP-001 1.67×, EXP-002 1.56×, EXP-003 2.12× against the build of `4bfecef` (A/A 1.00; PROVISIONAL, `perf/NEGATIVE-EVIDENCE.md` NE-001..003); EXP-004 against the original: 0.25× (16000 keys), 1.27× (1200-field rows), 3.06× (40000 expanded lines), one NO_EVIDENCE (NE-004). All six captures of ordinary inputs against the original were REFUSED_CV on the loaded host: no speed sentence is made from them anywhere.

## Open items

| id | what | blocks | owner |
|---|---|---|---|
| DISC-001..008, 010, 011, 013 | eleven OPEN divergences: ten Platform/Performance facts of the Bend runtime (runtime flags before `--`, the literal program name, unwritable standard streams, non-UTF-8 argv, ANSI styling, closed descriptors, `-o` mode 0644, deep nesting, the 8 TiB reservation and memory per byte) and the cost of non-integer numbers (45 to 300 times, linear) | `converge.sh` (no OPEN DISC may remain); SHIP | the repository owner: accept or reject each (bead `toon_bend-svd`) |
| custom effect | `Stdin.open` (`port/stdin_open.c`, `.js`) is the port's one custom effect; `AGENTS.md` had forbidden custom effects on a wrong premise and was amended by the author | nothing technical; it is a rule change the owner did not make | the repository owner (bead `toon_bend-gvt`): keep it (recommended: without it a regular-file stdin at an offset gives wrong bytes and a socket stdin fails) or revert and re-open DISC-012 |
| C-1..C-11 | bug-compatibility candidates listed for the owner (decoded integers print as `1.0`, the two escape tables, the 8192-byte silent write, the two encode → decode breaks S10.83 and S10.200, …) | nothing: the port reproduces each | the repository owner |
| rounds | T2 needs the last two rounds clean; rounds 6, 7 and 8 found 6, 11 and 8 (2 HIGH in round 7, 0 HIGH in round 8) | `converge.sh` | a fresh non-author subagent per round, after the previous round's repairs |
| NE-001..004 | three PROVISIONAL levers and one refused capture | any WIN claim for them | author, on a quiet host; the owner for the binding question (bead `toon_bend-clf`) |
| incumbent | cv-gated captures of ordinary inputs against the original | every speed sentence against the original | author, on a quiet host (bead `toon_bend-925`) |
| license, remote | this repository has no LICENSE and no git remote | publishing; `git push` | the repository owner |
| `./-` and `docs/AGENTS.scaffold.md` | two stray files created in Phase 0/1 (a probe's `-o -` output; a needless copy) | nothing; deletion needs the owner's exact command (RULE 1) | the repository owner |

## Find-fix rounds (Phase 4/5)

| round | lens | new genuine findings | fixed | clean? | date |
|---|---|---|---|---|---|
| 1 | author: mutation fuzz of corpus documents against the original (9000 TOON, 4000 JSON) | 1 | 1 | yes | 2026-09-20 |
| 2 | author: argv fuzz against the original (clap emulation; 4000 then 12000 command lines) | 1 | 1 | yes | 2026-09-20 |
| 3 | author: structure-aware generated documents, every option, encode then decode (4000), and the 45 cases proposed by the pass-2 reader and by Phase 3 | 0 | 0 | yes | 2026-09-20 |
| 4 | author: lane hazards, inputs of 10^5 and 10^6 elements on C and JS against the original (25 shapes) | 1 | 1 | yes | 2026-09-20 |
| 5 | author: kill-switch parity and twin-vs-twin numbers (1005 cases under both settings; 127838 generated numbers, both directions, against the original) | 1 | 1 | yes | 2026-09-20 |
| 6 | non-author hostile review (subagent): descriptor and platform states, inputs large in one dimension, a review of every claim in the documents (non-author) | 6 | 6 | no | 2026-09-20 |
| 7 | non-author hostile review (subagent): the new key carriers, scale, numbers in both directions and under `TOON_SPEC=1`, argv and files, lane agreement (about 122000 compared executions) (non-author) | 11 | 11 | no | 2026-09-20 |
| 8 | non-author hostile review (subagent): balanced buckets and the repeated-key map, stdin and descriptors beyond the probe, signals and resources, 40 random spec clauses, a fresh-seed floor (about 90000 compared executions) (non-author) | 8 | 8 | no | 2026-09-20 |

What each round found (every finding was resolved by RUNNING the original, then a clause, a case and a repair; "fixed" counts findings repaired OR registered as a DISC):

- round 1: OQ-P3-2, a quoted key is unescaped before the colon after its closing quote is required (7 of 3000 mutated documents differed); S2.126 amended, `toonerr_quoted_key_escape_before_colon*`.
- round 2: OQ-P4-1, `--help=x` / `--version=x` with a non-empty committed list print the flag before the group line (11 of 4000 command lines differed); S1.86 amended, `usage_help_with_value_after_commit`, `usage_version_with_value*`.
- round 4: on the JS lane Base's `List.length` overflowed the machine stack on a 200000-field tabular header (`bend: memory fault`), while the C lane and the original answered; every `List.length`, `String.length` and `++` over input-controlled text is now a loop (`T.llen`, `T.str_len`, `T.cat`), and TOON number tokens are clamped to 800 significant digits plus a sticky digit.
- round 5: the short-integer fast twin accepted 15-digit texts, and 281474976710656 (in `encnum_ints`) is past Nat's 2^48 − 1; the run with `TOON_SPEC=1` passed and the run without it failed, which is what the switch is for; the bound is 14 digits now.
- round 6 (report `scratchpad/review_R6/REPORT.md`): the native binary hung on a closed stdin (DISC-007, launcher); `-o` files get mode 0644 (DISC-008); quadratic time in the keys of one object (repaired: hashed key carriers, EXP-004); exit codes on unwritable standard streams (DISC-003, DISC-006); a non-blocking stdin (DISC-009); a spec error in S9.20. Its claims review is answered item by item in the commits `1230a0d` and `e3f5540` (law counts and wording, board citations, fuzzers in `scripts/`, ledgers, plan amendments).
- round 7 (report `scratchpad/review_R7/REPORT.md`, 2 HIGH): stdin was re-opened by PATH: an inherited offset ignored (wrong bytes, exit 0) and a socket refused (DISC-012, repaired by the stdin effect; DISC-009 RESOLVED by the same repair); list buckets quadratic on keys that collide in the 16 hash bits, and a chain walk per repeated key (repaired: AA-tree buckets, a map of last values; 7 cases); the runtime's resource floor (DISC-011); a second closed-descriptor hang (DISC-007 amended, launcher); three DISC texts corrected.
- round 8 (report `scratchpad/review_R8/REPORT.md`, 0 HIGH): EBADF on stdin must end the input (repaired); read-only stdout/stderr (DISC-003, DISC-006, launcher); the cost of non-integer numbers (DISC-013); two launcher defects (repaired); DISC wording for the JavaScript build; S1.81's cluster rule (amended, 5 cases); a limit of `js-lane.py` (documented).

Convergence (computed by `scripts/converge.sh docs/PORT_STATE.md`): T1 ≥ 3
rounds and ≥ 1 clean at the end; T2 ≥ 5 and ≥ 2 consecutive clean at the end and ≥ 1 non-author round; T3
≥ 10 with the last two rounds clean; a clean round has < 3 new genuine
findings and no unresolved finding from that round; a dirty or reopened
round resets the clean streak. Every OQ is resolved or excluded; no OPEN DISC. Current: NOT_CONVERGED (the last three rounds are dirty; eleven OPEN DISC await the owner; no OQ is open).

## Next action (one line, executable)

`grep -v '^pass ' /data/tmp/claude-1000/-data-projects-toon-bend/74a98d40-34be-4aa9-bc74-48585483da17/scratchpad/lanes_4c3cccc.log | tail -3` then, when every lane says PASS, `python3 scratchpad/finalize_board.py 4c3cccc scratchpad/lanes_4c3cccc.log` and paste the lanes line above; when the log is gone (a new session), `BEND_CLI='bun /tmp/bend/bend2/main.ts' ./scripts/lanes.sh goldens/cases.tsv goldens port/main.bend --threads 8 --interpreter-timeout 120`
