# Contributing to toon_bend (the Bend 2 port of toon)

Outside contributions are not accepted, as for the original `toon_rust`; issues and ideas are welcome. This file says
how anyone can CHECK the repository's claims from a clone, and which rules the maintainers (people and coding agents)
work under. `AGENTS.md` is the agent-facing version of the same rules; `docs/PARITY_RUNBOOK.md` is the maintainer's.

There is NO continuous integration here: no workflow file exists. Every gate is run by hand and its last line is pasted
into `docs/PORT_STATE.md`.

## 1. The two equivalences

The port is correct in two separable senses, and every claim says which one it rests on. **original == spec** is
golden-tested: `goldens/` holds the pinned original's captured stdout, stderr and exit code per case, and
`./scripts/lanes.sh` compares the port with them byte for byte on every lane (interpreter, the native binary at 1 and
N threads, the JavaScript build; no device lane, because no bang is placed). **spec == fast** is law-BOUND, and how far
that reaches is stated wherever it is claimed: the three fast twins are bound to their specification twins by one
quantified gate law (`twin_gate_switch`), by closed instance laws and by differential runs under `TOON_SPEC=1`; no
universally quantified `fast == spec` law exists for any of them (`perf/NEGATIVE-EVIDENCE.md` NE-001..003). The original
(`legacy/`, not in this repository) is an oracle to run, never a template to read: a spec gap is an `OQ-` row resolved
by running it on a new case.

## 2. Checking the claims from a clone (no oracle needed)

```bash
git clone https://github.com/bendlang/bend /tmp/bend && git -C /tmp/bend checkout --detach 15ae0c8
export BEND_NO_TELEMETRY=1 BEND_CLI='bun /tmp/bend/bend2/main.ts'
$BEND_CLI port/main.bend -o /tmp/toon_check                                                  # about 25 s
./scripts/conform.sh goldens/cases.tsv goldens --lane c-1t -- /tmp/toon_check --threads 1 --     # PASS, every case
(cd port && $BEND_CLI PROOF.bend)                                                            # "All terms check.", about 4 min
python3 cases/build-cases.py --check && ./scripts/cases-lint.sh goldens/cases.tsv
python3 scripts/spec-lint.py docs/EXISTING_Toon_STRUCTURE.md goldens/cases.tsv
./scripts/law-coverage.sh && ./scripts/parity-board.sh docs/FEATURE_PARITY.md
python3 scripts/claims-audit.py                                                              # do the documents' numbers still match the repository?
./scripts/clean-build-check.sh                                                               # does the COMMIT build, not only the working tree?
```

What needs the pinned original's binary at `oracle/toon` (it is not in the repository; `docs/PIN.toml` has its commit
and sha256): `golden-capture.sh`, `floor.sh`, `pin-check.sh`, `scripts/diff-fuzz.py`, `scripts/stdio-probe.py`,
`scripts/incumbent-bench.sh`.

## 3. Adding a case (maintainers)

`goldens/cases.tsv` is GENERATED: never edit it. Add the case to a generator (`cases/gen-hand-cases.py`), then
`python3 cases/build-cases.py`, `./scripts/cases-lint.sh goldens/cases.tsv`, and a re-capture with
`./scripts/golden-capture.sh goldens/cases.tsv goldens --repin "<reason>" -- ./oracle/toon`. The MANIFEST diff must
add hashes and change none. Name the case in the spec clause it exercises (`python3 scripts/spec-lint.py …` refuses an
uncited case). Goldens are never typed or edited by hand.

## 4. Laws

`port/LAWS.bend` only grows: a law is never weakened or deleted; a law the checker refuses is a finding about the code
or the spec. A new law gets its proof in `port/PROOF.bend`, a citation on its board row
(`python3 scripts/board-refresh.py`), and, when it speaks about code that can be broken in one line, a mutant in
`scripts/hand-mutants.py`.

## 5. Divergences (DISC)

Bug-compatibility is the default. A divergence exists only as an entry of `docs/DISCREPANCIES.md` with its class, spec
clause, the original's behavior, the port's, a kill-switch or mitigation, the affected cases and the measured impact.
The approver is the repository owner (who, on 2026-09-20, delegated the rulings on every entry of the register to the author; the
words are quoted in each entry).

## 6. Performance levers

Not before the parity gate. Then: sweep `perf/NEGATIVE-EVIDENCE.md`, write the card in `perf/EXPERIMENTS.md` BEFORE the
code, put the fast twin behind the gate `F.twin.on` (kill-switch `TOON_SPEC=1`), state its laws, capture with
`scripts/incumbent-bench.sh` (cv gate 5%, an A/A arm), and ledger the outcome whatever it is. A refused capture is
NO_EVIDENCE, not a number.

## 7. What a change shows

Pasted, never paraphrased: the `lanes.sh` JSON line, the last line of `bend port/PROOF.bend` with the unsafe split and
the Bend version, the `parity-board.sh` verdict line, and for a lever the bench JSON line and the ledger entry.
`./scripts/claims-lint.sh` is clean on every claim-bearing document, this one included.
