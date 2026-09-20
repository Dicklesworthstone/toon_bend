# Port report: Toon → Bend 2   HOLD   commit c7239e2 (gates) and later (documents)   2026-09-20   bend 2.0.16

<!-- Phase 6 document (SHIP-AND-CERTIFY). Every constant is computed from an
     artifact and pasted; every claim is proved / golden-tested / measured
     with the artifact named; anything else is deleted. Run
     scripts/claims-lint.sh on this file before committing it. -->

## Verdict

HOLD. The port is complete and every lane is green; ONE constant fails, and one number is missing:

1. **Convergence met for the tier: fails.** `converge.sh`: `NOT_CONVERGED` (T2 needs the last two rounds clean; the five non-author rounds, 6 to 10, found 6, 11, 8, 3 and 10 findings: 2 HIGH in round 7 on stdin, 1 HIGH in round 10 on cited commits that did not build from the public history, 0 behavioral differences in rounds 9 and 10; their reports are in `docs/reviews/`). Owner: the author, with a fresh non-author subagent per round. Flips after two consecutive rounds with fewer than 3 new genuine findings.
2. **Every performance claim has a pin, cv ≤ 5%, identical sha: holds for what is claimed.** Three captures against the original on ordinary inputs are MEASURED and five are REFUSED_CV (nothing is claimed for those). Owner: the author, on a quiet host. These are missing numbers, not failing ones; they block only a speed sentence for those inputs.

The DISC register is complete since 2026-09-20: the repository owner delegated the rulings to the author ("You decide on everything. I approve whatever you want to do."), twelve entries are ACCEPTED with a scoped contract each (DISC-014 was found and ruled on after the delegation, by the same delegation), two are RESOLVED by repairs, and the port's one custom effect `Stdin.open` stays.

## Constants (computed, never asserted)

| constant | value | evidence |
|---|---|---|
| 100% of cases pass on every lane | `{"lanes":[{"lane":"interpreter","verdict":"PASS","passed":1065,"failed":0},{"lane":"c-1t","verdict":"PASS","passed":1065,"failed":0},{"lane":"c-8t","verdict":"PASS","passed":1065,"failed":0},{"lane":"js","verdict":"PASS","passed":1065,"failed":0}],"stderr_compared":true,"timeouts_seconds":{"interpreter":60.0,"compiled":5.0,"build":600},"verdict":"PASS"}` on the tree of `c7239e2` (1065 cases), inside one `port-doctor.sh` run whose last line is `{"proof":"All terms check.","unsafe":"0","unsafe_annotations":"0","instances":"0","unsafe_count_mode":"explicit-and-instances","bend":"bend 2.0.16","lanes":"PASS","board":"DEBT","floor":"STABLE","switch":"PASS","verdict":"GREEN"}` | `scripts/port-doctor.sh` |
| all laws check | `All terms check.` (unsafe 0 = 0 `@unsafe` + 0 template instances, bend 2.0.16 @ `15ae0c8`), 368 laws; the doctor's proof row says the same | `(cd port && bun /tmp/bend/bend2/main.ts PROOF.bend)` |
| law coverage | `{"laws": 368, "proofs": 368, "unproved": "", "ghost_proofs": "", "ghost_cited": "", "uncited": "", "duplicate_laws": [], "duplicate_proofs": [], "unsafe": 0, "unsafe_annotations": 0, "verdict": "OK"}` | `scripts/law-coverage.sh` |
| the gates bite | `harness-selftest.sh -- ./oracle/toon`: `"mutations":11,"caught":11,"leaked":[],"untestable":[],"verdict":"OK"` | `scripts/harness-selftest.sh` |
| the laws bite | `{"laws_in_proof": 123, "reduced": true, "mutants": 22, "killed": 22, "survived": [], "not_evidence": [], "verdict": "STRONG"}`; `scripts/law-mutation.sh` itself: INCONCLUSIVE on the three modules (no valid textual site) | `scripts/hand-mutants.py` |
| board FULL or DEBT, every exclusion classed | `{"rows": 33, "present": 27, "partial": 0, "missing": 0, "excluded": 6, "na": 0, "no_evidence": 0, "verdict": "DEBT"}` | `scripts/parity-board.sh` |
| DISC register complete | 12 ACCEPTED (each with a scoped contract), 2 RESOLVED, 0 OPEN | `docs/DISCREPANCIES.md`; `scripts/converge.sh`: `"open_disc": []` |
| floor unchanged since capture | `{"repeat":3,"stable":1065,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` | `scripts/floor.sh` |
| MANIFEST unchanged since the clean tail | there is no clean tail yet; last change `4c3cccc Round 8 (non-author, dirty: 0 HIGH, 4 MEDIUM, 4 LOW): EBADF on stdin ends the input, launcher repairs, 5 cases, 368 laws` (15 hashes added, 0 changed; every re-capture of this port only ever ADDED hashes) | git |
| evidence ≤ 24 h old on this commit | every line of this report is dated 2026-09-20 | `docs/PORT_STATE.md` |
| zero open high-severity findings | round 7's two HIGH findings (stdin re-opened by path) are repaired and have regression rows (`scripts/stdio-probe.py`); round 10's one HIGH finding (cited commits that did not build) is repaired and has a gate (`scripts/clean-build-check.sh`); rounds 8 and 9 had none | PORT_STATE rounds table, `docs/reviews/` |
| convergence met for the tier | `{"tier": "T2", "rounds": 10, "clean": 5, "clean_tail": 0, "last_two_clean": false, "non_author_round": true, "open_oq": [], "open_disc": [], "verdict": "NOT_CONVERGED", "missing": ["clean rounds since last reset 0 < 2"]}`: FAILS | `scripts/converge.sh` |
| every perf claim has a pin, cv ≤ 5%, identical sha | the MEASURED captures named below; one NO_EVIDENCE; six REFUSED_CV that are claimed nowhere; NO row is admitted to the WIN ledger (NE-001..005 are provisional) | `perf/evidence/`, `perf/PERF-LEDGER.md`, `perf/NEGATIVE-EVIDENCE.md` |
| claims lint | `claims-lint: 0 hit(s) in 11 file(s)`: this file, `README.md`, `CONTRIBUTING.md`, `docs/PORT_STATE.md`, `docs/PARITY_RUNBOOK.md`, `docs/DISCREPANCIES.md`, `docs/OPEN_QUESTIONS.md`, `perf/*.md` | `scripts/claims-lint.sh` |

## Claims

### Proved
- 14 quantified laws, for every input and under the checker's assumptions: the first failure ends a pass (`argv_stop_is_sticky`, `decode_error_ends_pass`, `decode_root_ends_pass`, `json_error_is_sticky`), lenient mode never reports a scan or body check (`lenient_scan_never_fails`, `lenient_body_never_fails`), the mode flags win (`encode_flag_wins`, `decode_flag_wins`, `stdin_defaults_to_encode`), no `Saved` line without savings, the expansion cap on values and merges, and the kill-switch gate (`twin_gate_switch`, `twin_gate_open`); `All terms check.` (unsafe 0 = 0 `@unsafe` + 0 template instances, bend 2.0.16)
- 354 closed laws, each about ONE value: 59 unit laws (the big-natural carry, the divisions and readers of the fast twins against their specification twins, the twins' bounds, the key hash, the balanced buckets, the percent roundings) and 295 captured goldens restated as `run_pure(argv, bytes) == (exit code, stdout, stderr)`; same verdict line
- NOT proved: `fast == spec` for every input, for any of the three twins; anything about the compiled C or the JavaScript build; anything about a non-integer number through the pipeline (the checker does not normalize the shortest-digit generator)

### Golden-tested
- The two native lanes are ONE sequential execution under two labels: the port places no bang and no parallel let, so the runtime never starts a worker pool and `--threads N` changes nothing (2 OS threads at `--threads` 1, 8 and 64, measured by round 10 and re-measured); `c-8t` adds no evidence beyond `c-1t` today and is kept because it would catch a parallel twin the day one is added.
- 1065 cases on interpreter, c-1t, c-8t, js at `c7239e2` (earlier all-lane passes: 1065 at `4c3cccc`, 1060 at `d80251a`, 1053 at `1230a0d`; of those only `1230a0d` builds from the public history, see Reproduce); gpu MISSING: no bang is placed (text with data-dependent structure); the three compiled lanes also under `TOON_SPEC=1`; MANIFEST 3195 hashes captured from `./oracle/toon` (`toon 0.2.4` @ `f955c67`); 2026-09-20
- outside the corpus, against the original, 0 differences on conversion content: the author's seeded lenses (`scripts/diff-fuzz.py`: mutate, docs, argv, expand, collide, numbers under `TOON_SPEC=1`, scale) and the non-author rounds (about 122000, 90000 and 948000 compared executions in rounds 7, 8 and 9; round 10 added terminals, environments, thread counts and a fresh clone)

### Measured
- 1.67× / 1.56× / 2.12× against the port's own build of `4bfecef` (EXP-001 tabular encode, EXP-002 tabular decode, EXP-003 9000 decimals; 18 samples per arm in AB/BA pairs; cv ≤ 1.5%; A/A 1.001 / 0.995 / 1.004; stdout sha equal; AMD EPYC-Milan 8 cores, Linux, 1 thread; 2026-09-20); PROVISIONAL, not WIN (NE-001..003)
- against the original (`toon 0.2.4` @ `f955c67`, release build, 1 thread each): 0.25× on one object of 16000 keys, 1.27× on 20 rows of 1200 fields, 3.06× on 40000 expanded lines (cv ≤ 4.7%; stdout sha equal; `perf/evidence/EXP-004.*-vs-original.json`), measured on the build of `1230a0d`

- against the original (`toon 0.2.4` @ `f955c67`, release; the port's build of `4c3cccc`, 1 thread, 15 AB/BA pairs): 0.114× on the 1500-row table encode, 0.404× on its decode, 0.0066× on 20000 doubles (cv ≤ 4.7%; `perf/evidence/INCUMBENT.tabular-enc.json`, `.tabular-dec.json`, `.doubles.json`); five more captures of that run were REFUSED_CV and claim nothing
- EXP-003 alone (one lever per artifact): 2.05× against the all-twins-off arm of the current code (cv 2.7% / 3.9%; A/A 1.019; `perf/evidence/EXP-003.one-lever.ab.json`); the 1.67× and 1.56× above belong to the three levers TOGETHER: EXP-001 and EXP-002 alone were REFUSED_CV twice and are not shown to meet their gates

### Not claimed
- a ratio against the original for integers, one-decimal numbers, strings, scientific notation and startup: REFUSED_CV three times (`perf/evidence/INCUMBENT.*.json`); predicate: a quiet host and inputs ten times larger
- the folding input's ratio: NE-004 (REFUSED_CV twice)
- a WIN for EXP-001..003: NE-001..003 (closed laws only; one artifact carries three levers)
- exclusions, each classed in PLAN §3: async streaming, WebAssembly bindings, the `EncodeReplacer` callback, library-only behavior no CLI path reaches, shell completions / tracing / build metadata, native Windows

## Discrepancies

ACCEPTED on 2026-09-20 by the owner's delegation, one line each (id, class, kill-switch or mitigation, cases affected): DISC-001 Platform, runtime flags before `--`, launcher, 0 · DISC-002 Platform, the literal program name, none, 0 · DISC-003 Platform, an unwritable stderr, launcher repairs closed and read-only, 0 · DISC-004 Platform, non-UTF-8 argv, none, 0 · DISC-005 Platform, ANSI styling, none, 0 · DISC-006 Platform, a failed stdout write, launcher repairs closed and read-only, 0 · DISC-007 Platform, closed descriptors on the bare native binary, launcher, 0 · DISC-008 Platform, `-o` mode 0644, none, 0 · DISC-010 Performance, deep nesting, none, 0 · DISC-011 Performance, the runtime's resource floor, the JavaScript build, 0 · DISC-013 Performance, non-integer numbers 45 to 300 times slower (linear), none, 0 · DISC-014 Platform, a `/dev/fd/N` path the caller did not open reaches a descriptor of the runtime, none, 0. RESOLVED by repairs: DISC-009, DISC-012 (the stdin effect; regression rows in `scripts/stdio-probe.py`). Approver of every entry: the repository owner through the delegation quoted above.

## Reproduce (an auditor gets the same lines)

Use `c7239e2` or any commit after it. NOT `d80251a`, `861abf2` or `4c3cccc`, which this report's earlier versions named: they do not build from the public history (`port/stdin_open.c` and `.js` were hidden by `.gitignore` until `a725d10`; `./scripts/clean-build-check.sh 4c3cccc` → FAIL at the native build, `… c7239e2` → PASS). The oracle binary is not in the repository: `docs/PIN.toml` has its commit and sha256, PLAN §2 the build command; without it the first, second and the last-but-one command below cannot run, the others can.

```bash
git checkout c7239e2                                                    # or any commit after it
export BEND_NO_TELEMETRY=1 BEND_CLI='bun /tmp/bend/bend2/main.ts'      # bendlang/bend at 15ae0c8
./scripts/floor.sh goldens/cases.tsv goldens --repeat 3 -- ./oracle/toon
./scripts/port-doctor.sh --threads 8 --original ./oracle/toon -- --switch TOON_SPEC=1 --probe '["--encode","cases/inputs/hand/large_tabular_1500.json"]'
./scripts/clean-build-check.sh && ./scripts/converge.sh docs/PORT_STATE.md
python3 scripts/hand-mutants.py
$BEND_CLI port/main.bend -o ./x && python3 scripts/stdio-probe.py -- ./x -- && python3 scripts/diff-fuzz.py scale --runs 16000 -- ./x --
./scripts/incumbent-bench.sh --runs 9 --pin "bend 2.0.16 @15ae0c8; toon 0.2.4 @f955c67" --original ./oracle/toon -e perf/inputs/wide_rows_1200.json --port ./x --threads 1 -- -e perf/inputs/wide_rows_1200.json
./scripts/claims-lint.sh README.md CONTRIBUTING.md docs/PORT_REPORT.md docs/PORT_STATE.md docs/PARITY_RUNBOOK.md docs/DISCREPANCIES.md docs/OPEN_QUESTIONS.md perf/*.md
```
