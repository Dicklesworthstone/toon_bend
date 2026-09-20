# Keeping Toon-bend at parity (for maintainers)

<!-- Phase 6 output, written beside docs/PORT_REPORT.md. Every `./scripts/…` command below exists in this repository.
     Two things it names live OUTSIDE the repository, in the skills that drove the port: `keep-audit.sh` (bend2-mega-skill) and
     `assets/probes/base/run-base-probes.sh` (porting-to-bend2); the ledgers' template text also names the mega-skill's
     `bench-speedup.sh` and `ledger-row.sh`, which this port replaced by `scripts/incumbent-bench.sh`. -->

## 1. What "parity" means here

Every case in `goldens/cases.tsv` (1065 cases on 2026-09-20; `docs/PORT_STATE.md` has the current count and the
pasted line) prints identical stdout, stderr and exit code on the interpreter, the C binary at 1 and 8
threads, and the JS build (`gpu`: MISSING: no bang is placed, so there is no device lane). The two native lanes are
ONE sequential execution under two labels: the port has no parallel let, so the runtime never starts a worker pool and `--threads N`
changes nothing (2 OS threads at `--threads` 1, 8 and 64); the c-8t lane is kept because it would catch a parallel twin the day one is added.
`bend port/PROOF.bend` prints `All terms check.` (0 `@unsafe` + 0 template instances under bend 2.0.16). The
board (`docs/FEATURE_PARITY.md`) is DEBT: 27 rows present and six exclusions, each classed in PLAN §3 (async
streaming, WebAssembly bindings, the `EncodeReplacer` callback, library-only behavior, completions / tracing / build
metadata, native Windows). A claim is one of
three kinds: proved (a law), golden-tested (the harness on named lanes),
measured (an interleaved, cv-gated capture). Nothing else is a claim.

## 2. The gates, in one command each

```bash
./scripts/pin-check.sh docs/PIN.toml                       # GREEN before anything else; YELLOW = caveat; RED = stop
./scripts/port-doctor.sh --threads 8 --original ./oracle/toon -- --switch TOON_SPEC=1 --probe '["--encode","cases/inputs/hand/large_tabular_1500.json"]'   # proof, lanes, board, floor, kill-switch (about 90 minutes: the interpreter lane)
./scripts/converge.sh docs/PORT_STATE.md                   # the tier's convergence rule, computed
./scripts/claims-lint.sh README.md CONTRIBUTING.md docs/PORT_REPORT.md docs/PORT_STATE.md docs/PARITY_RUNBOOK.md docs/DISCREPANCIES.md docs/OPEN_QUESTIONS.md perf/*.md   # the forbidden phrases, on the claim-bearing documents (not docs/*.md: the spec's clauses are not claims)
./scripts/harness-selftest.sh -- ./oracle/toon             # the gates are attacked and hold (verdict OK)
./scripts/clean-build-check.sh                             # the COMMIT builds and converts, not only the working tree (an ignored source file hides here)
python3 scripts/stdio-probe.py -- <port command>           # descriptor states no case can express: SAME, KNOWN (its DISC) or NEW
python3 scripts/diff-fuzz.py <lens> --seed N -- <port command>   # seeded differential fuzzing; the scale lens has a time verdict
python3 scripts/hand-mutants.py                            # do the laws bite? (about an hour)
```

There is NO CI: no workflow file exists in `.github/`. The gates are run by hand (or by a coding agent) and their
last lines are pasted into `docs/PORT_STATE.md`; the oracle binary they need is not in the repository
(`docs/PIN.toml` names its commit and sha256; PLAN §2 has the build command).

## 3. When the original ships a new version

1. Re-pin: PLAN §2 and `docs/PIN.toml` (`commit`, `version_expect`).
2. `./scripts/floor.sh goldens/cases.tsv goldens --repeat 3 -- ./oracle/toon` → STABLE.
3. `./scripts/golden-capture.sh goldens/cases.tsv goldens --repin "toon <new version>" -- ./oracle/toon`.
4. Read the printed MANIFEST diff: every changed hash is a clause change
   (amend `docs/EXISTING_Toon_STRUCTURE.md`), a DISC, or a bug in the
   original (an S10 row). No hash changes silently.
5. `./scripts/lanes.sh goldens/cases.tsv goldens port/main.bend --threads 8 --interpreter-timeout 120`; fix the port to the new clauses.
6. `docs/PORT_STATE.md` rewritten; `./scripts/state-check.sh docs/PORT_STATE.md`.

Never edit a golden. Never re-capture to make a red case green.

## 4. When bend ships a new version

1. `./scripts/pin-check.sh` turns YELLOW on `bend_version`.
2. `./scripts/version-drift.sh --old "<pinned cli>" --new "<new cli>" --threads 8` → SAME or the DRIFT list. Rebuild the stdin effect's twins' assumptions too: `port/stdin_open.c` uses the runtime's `io_done` / `io_hand` / `io_fail`, and the effect seam has no ABI promise across versions.
3. Re-run PROOF: the unsafe count can change with no source change (2.0.16
   counts template instances); re-state it as `unsafe k = a @unsafe + b instances, bend <v>`.
4. `assets/probes/base/run-base-probes.sh` (from the skill) for drift in the
   Base facts the port relies on; every DRIFT row is a reference to re-verify.
5. Update `docs/PIN.toml [bend]`, PLAN §2b, and the version in every claim.

## 5. How to add a behavior

A case in a GENERATOR (`cases/gen-hand-cases.py`; `goldens/cases.tsv` is generated and never edited; a name is an
identifier, never renamed) → `python3 cases/build-cases.py` → `golden-capture.sh --repin "<reason>"` → a clause `S<n>.<m>` in the
spec naming the case → the def with `# S<n>.<m>` above it → a board row
(`present` only with the golden or a law named) → `lanes.sh` PASS. A case
with no clause is unexplained; a clause with no case is a hypothesis.

## 6. How to propose a divergence

`docs/DISCREPANCIES.md` entry `DISC-<n>` OPEN with class, spec clause,
original behavior (cite the golden), port behavior, kill-switch, affected
cases, measured impact → approver: the repository owner (never the implementer, unless the owner delegates the ruling in writing, as on 2026-09-20) →
re-capture through the canonicalizing wrapper with `--disc DISC-<n>` → the
switch stays forever. A self-signed DISC is refused.

## 7. How to propose a law

Append the law to `port/LAWS.bend` with its clause tag and its proof to `port/PROOF.bend`; the law owner is the
repository owner. Then `python3 scripts/board-refresh.py` (every law is cited on its board row). Laws are never weakened or deleted: a law the checker
refuses is a finding about the code or the spec.

## 8. How to propose a lever

`./scripts/graveyard-sweep.sh "<lever words>"` → the card in
`perf/EXPERIMENTS.md` with the precommitted gate → the fast twin behind
`TOON_SPEC=1` (the gate `F.twin.on`) → its laws in `port/LAWS.bend`, proved, and SAID to be closed instances when they are → `keep-audit`
→ capture with `incumbent-bench.sh` (two retained binaries, AB/BA pairs, cv gate 5%, an A/A arm; `--pin` for a claim against the original) → the ledger (WIN → PERF-LEDGER
with `./scripts/evidence-bundle.sh EXP-<id>`; else NEGATIVE-EVIDENCE with a
retry predicate) → `lanes.sh` again. A refused capture is NO_EVIDENCE, never
a rounded number.

## 9. Words that fail the claims lint

Forbidden: `later` (as a deferral), `should be`, `probably`, `roughly`, `flaky`.
Forbidden: `usually passes`, `within noise` without a cv figure, `100% parity` beside an exclusion table.
Forbidden: `faster` without a number, `verified` without a law or a golden, an unsafe count without `bend --version`. `./scripts/claims-lint.sh`
is the executable list.

## 10. The one-line re-certification

```bash
./scripts/port-doctor.sh --threads 8 --original ./oracle/toon -- --switch TOON_SPEC=1 --probe '["--encode","cases/inputs/hand/large_tabular_1500.json"]' && ./scripts/converge.sh docs/PORT_STATE.md && ./scripts/claims-lint.sh README.md CONTRIBUTING.md docs/PORT_REPORT.md docs/PORT_STATE.md docs/PARITY_RUNBOOK.md docs/DISCREPANCIES.md docs/OPEN_QUESTIONS.md perf/*.md
```

Its three last lines, pasted, are the certification (`docs/PORT_REPORT.md`
"Reproduce").
