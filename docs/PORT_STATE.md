# Port state — Toon → Bend 2

<!-- Read FIRST on every resume; rewritten at the END of every session.
     Facts only, each with the command that produced it. -->

## Where we are

| field | value |
|---|---|
| phase | 4 parity gate and 5 performance, both in progress: the reference port is complete (Phase 3 exit at `d068470`), five author find-fix rounds are done, three numeric levers are in behind `TOON_SPEC=1` (`3751630`); open: the complete interpreter-lane run at `3751630`, the non-author round, the cv-gated captures, the owner's decisions on DISC-001..006 |
| tier | T2 |
| bend | `bend 2.0.16` (checkout `15ae0c8`, run as `bun /tmp/bend/bend2/main.ts`); drift vs the previous pin: none, same pin since Phase 0 (VERSION-DRIFT) |
| last updated | 2026-09-20 by Claude (Claude Code session, author of phases −1 to 5) |

## Last gate outputs (paste, do not paraphrase)

| gate | command | result | date |
|---|---|---|---|
| lanes | `BEND_CLI='bun /tmp/bend/bend2/main.ts' ./scripts/lanes.sh goldens/cases.tsv goldens port/main.bend --threads 8` at `d068470` (1005 cases) | `{"lanes":[{"lane":"interpreter","verdict":"FAIL","passed":1004,"failed":1},{"lane":"c-1t","verdict":"PASS","passed":1005,"failed":0},{"lane":"c-8t","verdict":"PASS","passed":1005,"failed":0},{"lane":"js","verdict":"PASS","passed":1005,"failed":0}],"stderr_compared":true,"timeouts_seconds":{"interpreter":60.0,"compiled":5.0,"build":600},"verdict":"FAIL"}` | 2026-09-20 |
| proofs | `(cd port && bun /tmp/bend/bend2/main.ts PROOF.bend)` at `3751630` | `All terms check.` | 2026-09-20 |
| parity | `./scripts/parity-board.sh docs/FEATURE_PARITY.md` | `{"rows": 33, "present": 0, "partial": 27, "missing": 0, "excluded": 6, "na": 0, "no_evidence": 0, "verdict": "PARTIAL"}` | 2026-09-20 |
| floor | `./scripts/floor.sh goldens/cases.tsv goldens --repeat 3 -- ./oracle/toon` | `{"repeat":3,"stable":1053,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` | 2026-09-20 |

Notes on these lines:

- lanes: the FAIL above is ONE interpreter case out of 1005; the run's log was cut to its last four lines, so the case name was lost. It did not reproduce: the 26 heaviest cases re-run alone on the interpreter lane all pass, and the machine was saturated at the time by this session's own stress runs (a 6 GB JavaScript process among them), so a 60-second interpreter timeout is the unconfirmed explanation. A complete run at `3751630` with a full log (`scratchpad/lanes_final.log`, `--interpreter-timeout 120`) is in progress; no claim rests on the interpreter lane until it passes.
- at `3751630` (1053 cases): `./scripts/conform.sh goldens/cases.tsv goldens --lane <lane> -- <port>` → `{"lane":"c-1t","passed":1053,"failed":0,"inconclusive":0,"verdict":"PASS"}`, the same for `c-8t` and `js`, and the same three again with `TOON_SPEC=1` in the environment.
- proofs: 206 laws, unsafe 0 = 0 `@unsafe` + 0 template instances, bend 2.0.16 @ `15ae0c8`, 67 s. `./scripts/law-coverage.sh` → `"laws": 206, "proofs": 206, "unproved": "", "ghost_proofs": "", "ghost_cited": "", "unsafe": 0, "verdict": "OK"`.
- `python3 scripts/port-lint.py port/*.bend --laws port/LAWS.bend` → `{"files": 10, "findings": 19, "errors": 0, "warnings": 0, "infos": 19, "by_rule": {"PL-02": 19}, "verdict": "OK"}` (the 19 infos are recursions whose depth is a nesting depth, a limb count bounded by the 800-digit clamp, or at most 17 digits).
- `python3 scripts/spec-lint.py docs/EXISTING_Toon_STRUCTURE.md goldens/cases.tsv` → `spec-lint: 703 clauses, 1053 cases, 1053 cases cited, 0 finding(s)`.
- `python3 cases/build-cases.py --check` → `{"cases": 1053, "verdict": "OK"}`; `./scripts/cases-lint.sh goldens/cases.tsv` → `{"cases": 1053, "errors": 0, "notes": 20, "classes_missing": "", "verdict": "OK"}`.
- `./scripts/pin-check.sh docs/PIN.toml` → `pin-check: YELLOW`, one YELLOW row, `manifest_version`: `golden-capture.sh` writes no `version:` line into MANIFEST, so that row cannot turn green without a hand edit of `goldens/`, which is forbidden; identity is carried by `original_version` GREEN (`toon 0.2.4`) and the executable sha256 in MANIFEST's provenance. Every other row is GREEN (3159 hashes verified, 1053 cases = 1053 goldens).
- incumbent: no cv-gated capture exists yet. Maintenance numbers only (shared host, load 5, medians of 9): `--encode` of `cases/inputs/hand/large_tabular_1500.json` original 5.8 ms, port 105 ms before the levers and 64 ms after; `--decode` of its 76989-byte TOON original 16.4 ms, port 62 ms before and 48 ms after. No speed claim is made anywhere.

## Open items

| id | what | blocks | owner |
|---|---|---|---|
| lanes-interp | one unnamed interpreter-lane failure at `d068470`, not reproduced | the parity board (every row is `partial` until a complete interpreter run passes) | author: read `scratchpad/lanes_final.log` |
| DISC-001..006 | six Platform divergences, all OPEN: runtime flags before `--`; the literal program name `toon`; an unwritable stderr; non-UTF-8 argv; ANSI styling; the text of a failed stdout write | `converge.sh` (no OPEN DISC may remain); SHIP | the repository owner: accept or reject each |
| C-1..C-11 | bug-compatibility candidates listed for the owner (decoded integers print as `1.0`, the two escape tables, the 8192-byte silent write, the two encode → decode breaks S10.83 and S10.200, …) | nothing: the port reproduces each | the repository owner |
| OQ-A4 | which OS error texts each lane produces for errno 20, 28, 32 | closes with the complete lanes run: errno 2, 13, 20, 21, 28 are golden-tested (`io_*`, `usage_*` cases); errno 32 on stdout is DISC-006 | author |
| round 6 | the non-author hostile review (T2 needs one) | `converge.sh` | a fresh subagent |
| EXP-001..003 | cv-gated captures and ledger rows for the three levers | every performance sentence | author, on a quiet host |
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

What each round found (every finding was resolved by RUNNING the original, then a clause, a case and a repair):

- round 1: OQ-P3-2, a quoted key is unescaped before the colon after its closing quote is required (7 of 3000 mutated documents differed); S2.126 amended, `toonerr_quoted_key_escape_before_colon*`.
- round 2: OQ-P4-1, `--help=x` / `--version=x` with a non-empty committed list print the flag before the group line (11 of 4000 command lines differed); S1.86 amended, `usage_help_with_value_after_commit`, `usage_version_with_value*`.
- round 4: on the JS lane Base's `List.length` overflowed the machine stack on a 200000-field tabular header (`bend: memory fault`), while the C lane and the original answered; every `List.length`, `String.length` and `++` over input-controlled text is now a loop (`T.llen`, `T.str_len`, `T.cat`), and TOON number tokens are clamped to 800 significant digits plus a sticky digit.
- round 5: the short-integer fast twin accepted 15-digit texts, and 281474976710656 (in `encnum_ints`) is past Nat's 2^48 − 1; the run with `TOON_SPEC=1` passed and the run without it failed, which is what the switch is for; the bound is 14 digits now.

Convergence (computed by `scripts/converge.sh docs/PORT_STATE.md`): T1 ≥ 3
rounds and ≥ 1 clean at the end; T2 ≥ 5 and ≥ 2 consecutive clean at the end and ≥ 1 non-author round; T3
≥ 10 with the last two rounds clean; a clean round has < 3 new genuine
findings and no unresolved finding from that round; a dirty or reopened
round resets the clean streak. Every OQ is resolved or excluded; no OPEN DISC. Current: NOT_CONVERGED (no non-author round yet; OQ-A4 open; six OPEN DISC await the owner).

## Next action (one line, executable)

`tail -3 /data/tmp/claude-1000/-data-projects-toon-bend/74a98d40-34be-4aa9-bc74-48585483da17/scratchpad/lanes_final.log` then, when every lane says PASS, `python3 scratchpad/update_board.py present` and paste the lanes line above; when a lane fails, `./scripts/first-divergence.sh <case> goldens/cases.tsv goldens -- ./scripts/interp-lane.sh bun /tmp/bend/bend2/main.ts port/main.bend --`
