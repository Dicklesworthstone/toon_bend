# Port state — Toon → Bend 2

<!-- Read FIRST on every resume; rewritten at the END of every session.
     Facts only, each with the command that produced it. -->

## Where we are

| field | value |
|---|---|
| phase | 1 spec (in progress): five owned-section extractors running (`docs/spec-parts/`), merge into `docs/EXISTING_Toon_STRUCTURE.md` follows. Phases −1 (fit) and 0 (truth pack) are done and committed (`c4a5235`). |
| tier | T2 |
| bend | `bend 2.0.16` (checkout `15ae0c8`, run as `bun /tmp/bend/bend2/main.ts`); drift vs the previous pin: first pin, nothing to compare (VERSION-DRIFT) |
| last updated | 2026-09-20 by Claude (Claude Code session, author of phases −1/0) |

## Last gate outputs (paste, do not paraphrase)

| gate | command | result | date |
|---|---|---|---|
| lanes | `BEND_CLI='bun /tmp/bend/bend2/main.ts' ./scripts/lanes.sh goldens/cases.tsv goldens port/main.bend --threads 8` | `{"lanes":[{"lane":"interpreter","verdict":"FAIL","passed":3,"failed":675},{"lane":"c-1t","verdict":"FAIL","passed":3,"failed":675},{"lane":"c-8t","verdict":"FAIL","passed":3,"failed":675},{"lane":"js","verdict":"FAIL","passed":3,"failed":675}],"stderr_compared":true,"timeouts_seconds":{"interpreter":60.0,"compiled":5.0,"build":600},"verdict":"FAIL"}` | 2026-09-20 |
| proofs | `(cd port && bun /tmp/bend/bend2/main.ts PROOF.bend)` | `All terms check.` | 2026-09-20 |
| parity | `./scripts/parity-board.sh docs/FEATURE_PARITY.md` | `{"rows": 3, "present": 0, "partial": 0, "missing": 3, "excluded": 0, "na": 0, "no_evidence": 0, "verdict": "MALFORMED"}` | 2026-09-20 |
| floor | `./scripts/floor.sh goldens/cases.tsv goldens --repeat 3 -- ./oracle/toon` | `{"repeat":3,"stable":678,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` | 2026-09-20 |

Notes on these lines:

- lanes: FAIL is the scaffold stub's result, the expected state before Phase 3; it was run on the full 678-case corpus and the four lanes agree with each other (3/678 each).
- proofs: 0 `@unsafe` + 0 template instances, bend 2.0.16 @ `15ae0c8`; the only law so far is the scaffolded `fast_is_spec`.
- parity: MALFORMED because the board is still the template; Phase 2 fills it from the spec.
- incumbent: not run; no port binary exists before Phase 3, and no speed number is stated anywhere.

Other checks (not gate rows):

- `./scripts/pin-check.sh docs/PIN.toml` → `pin-check: YELLOW` with one YELLOW row, `manifest_version`: `golden-capture.sh` writes no `version:` line into MANIFEST, so that row cannot turn green without a hand edit of `goldens/`, which is forbidden. Identity is carried by `original_version` GREEN (`toon 0.2.4`) and the executable sha256 `980f2b26…879a6d` in MANIFEST's provenance. Every other row is GREEN.
- `python3 cases/build-cases.py --check` → `{"cases": 678, "verdict": "OK"}`; `./scripts/cases-lint.sh goldens/cases.tsv` → `{"cases": 678, "errors": 0, "notes": 7, "classes_missing": "", "verdict": "OK"}`.

## Open items

| id | what | blocks | owner |
|---|---|---|---|
| OQ-003 | `--stats` percent rounding at an exact half | phase 1 (extractor X-A probes it) | X-A |
| OQ-008 | OS error text per Bend lane (`No such file or directory (os error 2)`) | phase 3 (shell) | author |
| DISC-001 | Platform: the Bend runtime consumes `--help`/`--threads`/`--gpu` before `--` | approval by the owner; mitigation is the `bin/toon` launcher | owner |
| finding | the two number printers break exact last-digit ties differently (zmij: even digit; Rust `Display`: up); sent to extractor X-C for clauses and cases | phase 1 | X-C |
| feasibility probes (scratchpad, not in the repo) | byte-read → strict UTF-8 → write is byte-identical on C and interpreter lanes (163 KB in 6 ms / 0.27 s); a single self-recursive `Json` type passes structural recursion where a phase-sum wrapper is refused; the lexicographic (input, stack) measure is accepted; a BigNat + software-binary64 prototype matches Python's `float`/`repr` on 6618 of 6618 values | informs phase 2 | author |

## Find-fix rounds (Phase 4/5)

| round | lens | new genuine findings | fixed | clean? | date |
|---|---|---|---|---|---|

Convergence (computed by `scripts/converge.sh docs/PORT_STATE.md`): T1 ≥ 3
rounds and ≥ 1 clean at the end; T2 ≥ 5 and ≥ 2 consecutive clean at the end and ≥ 1 non-author round; T3
≥ 10 with the last two rounds clean; a clean round has < 3 new genuine
findings and no unresolved finding from that round; a dirty or reopened
round resets the clean streak. Every OQ is resolved or excluded; no OPEN DISC. Current: not computed yet (no rounds before Phase 4).

## Next action (one line, executable)

`for f in docs/spec-parts/[A-E]_*.md; do grep -c '^| S[0-9]' "$f"; done` then merge the five part files into `docs/EXISTING_Toon_STRUCTURE.md` and run `python3 scripts/spec-lint.py docs/EXISTING_Toon_STRUCTURE.md goldens/cases.tsv`
