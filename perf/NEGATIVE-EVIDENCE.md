# Negative Evidence Ledger — toon_bend

<!-- Copy to perf/NEGATIVE-EVIDENCE.md on the day the project reaches rigor
     tier T2, BEFORE the first lever. Sweep it before starting any perf
     lever: a lever is re-attemptable only if its do-not-retry predicate
     holds. An unresolved gain needs more evidence. Record honest losing baselines. -->

Outcome taxonomy (closed set):

- **WIN** — a meaningful improvement meeting the stated success criterion,
  admitted after paired-sample/A/A review, output checks, relevant law
  review and a complete target-hardware fingerprint.
- **PROVISIONAL_LOCAL_WIN** — a qualified local capture suggests a gain,
  but target/coverage/significance review is incomplete. Too few runs or a
  failed capture gate gives NO_EVIDENCE instead.
- **NEGATIVE(reverted)** — slower or neutral; source reverted.
- **NEGATIVE(retained-for-proof)** — a spec twin retained for a law;
  erased proof-only use does not require a runtime switch.
- **NO_EVIDENCE** — the capture was refused (cv above the gate, a mode
  exited non-zero, outputs differ). Control inputs/effects first, then
  minimize and report any unexplained divergence.
- **VOID** — the measurement could not have exercised the claimed lever,
  such as timing the evaluator/JS for a native-pool claim or no actual
  device dispatch for a GPU claim. Compiled value-main does use the native
  runtime; quotas/cache events require diagnosis, not automatic VOID.

---

## Entry template

### NE-<ID> — <lever>   [<DATE> | <OUTCOME>]
- Program / def: `<x.bend>` / `<def>`
- Provenance: bend `<version>` commit `<hash>`, clang `<n>`, `<uname -sm>`,
  `<CPU, cores>`, GPU `<name or none>`, span `<2GB>`, lanes per bang `<16384>`
- Exact command: `scripts/bench-speedup.sh <x.bend> --threads 1,8 --gpu off,on --runs 5 --aa --max-cv 5`
- Kill-switch: <spec twin `<name>` | `--gpu off` | env `<VAR>` | `~` switch>
- Measured: <before> → <after> (<ratio>), cv <v>%, A/A null ratio <r>
- Correctness: <law-proved `<law>` | lane-identical cksum `<n>` | DIFFERS → bug filed `<link>`>
- Keep-audit delta: `<def>: keep a→b, take c→d`
- Disposition: <reverted | kept behind `<switch>` | promoted to PERF-LEDGER>
- Killing metric: <wall on `<hw>` | keep count (proxy) | `.gpu` bytes (proxy) | rounds (proxy)>
- **Do-not-retry unless:** <new bend version | new clang major | new silicon / lane count | a law proves the reorder | the wall moved | the shader guide's cost model changed>
- Tally: W<i>/L<j>/N<k>
- Agent: <name>


## Entries (this project)

### NE-001 — integer fast path in the two number printers   [2026-09-20 | PROVISIONAL_LOCAL_WIN]
- Program / def: `port/f64.bend`, `port/bignat.bend` / `show_toon_fast`, `show_json_fast`, `shortest_fast`, `int.fit`
- Provenance: bend 2.0.16 commit `15ae0c8`, clang 21.1.8, Linux x86_64, AMD EPYC-Milan 8 cores (shared host), GPU none, no bang
- Exact command: `scripts/incumbent-bench.sh --runs 9 --max-cv 5 --timeout 60 --tag EXP-001 --original <binary of 4bfecef> --threads 1 -- --encode cases/inputs/hand/large_tabular_1500.json --port <binary of 3751630> --threads 1 -- --encode cases/inputs/hand/large_tabular_1500.json` (and the same with the `3751630` binary on both sides for the A/A arm)
- Kill-switch: env `TOON_SPEC=1` (read once in the shell; `F.twin.on` turns every twin selector off; law `twin_gate_switch`)
- Measured: 89.8 ms → 53.9 ms (1.67×, 40% below the baseline; precommitted gate ≥ 25%), cv 0.9% / 0.6%, 18 samples per arm in AB/BA pairs, A/A null ratio 1.001; verdict MEASURED (`perf/evidence/EXP-001.ab.json`, `perf/evidence/EXP-001.aa.json`)
- Correctness: stdout sha `7f28c487efdfb54d` identical on both arms; `All terms check.` (unsafe 0 = 0 `@unsafe` + 0 template instances, bend 2.0.16); lanes c-1t, c-8t, js PASS 1053/1053 with the switch off and on; `scripts/diff-fuzz.py numbers --switch TOON_SPEC=1`: fast twin, spec twin and the original agree on every generated number text (0 differences)
- Keep-audit delta: whole program call sites, `4bfecef`→`3751630`: keep 246→255, take 244→248, seal 1679→1687, free 51→54 (the new twin defs; no new keep inside an existing hot def)
- Disposition: kept behind `TOON_SPEC`; NOT promoted to PERF-LEDGER
- Why provisional and not WIN: (1) the binding `fast == spec` is ONE quantified gate law plus CLOSED instance laws plus differential runs; no universally quantified equivalence law exists for this twin (the checker's normalizer overflows on bodies with 10^5-scale `Nat` literals); (2) the `3751630` binary carries EXP-001, EXP-002 and EXP-003 together, so this capture does not isolate one lever: the input was chosen to exercise this lever, and the other two also run on it
- Killing metric: wall on this host at 1 thread
- One lever per artifact (2026-09-20): a scratch variant of the current code with the other two twins switched off at their gates, against the all-twins-off arm (`TOON_SPEC=1`) of the current binary, captured twice (9 and 15 pairs): REFUSED_CV both times (second attempt: cv 3.1% / 5.3%, A/A arm 20.6% / 14.9%), so NO ratio is claimed. The refused medians, 103.3 ms → 86.3 ms (about 16% below), are far from this card's gate (≥ 25%): the ratio measured above belongs to the THREE levers together on this input, and this lever ALONE is not shown to meet its gate (`perf/evidence/EXP-001.one-lever.ab.json`, `.aa.json`)
- **Promote to WIN when:** a quantified `fast == spec` law for the twin checks, OR the owner accepts closed laws + differential runs as the binding in writing; AND the capture is repeated with one lever per artifact
- Tally: W0/L0/N0 (provisional)
- Agent: Claude (author session)

### NE-002 — exact small-integer path in the two number readers   [2026-09-20 | PROVISIONAL_LOCAL_WIN]
- Program / def: `port/f64.bend`, `port/bignat.bend` / `serde.short`, `token.short`, `int_text.ok` (at most 14 digits: 15 digits overflow `Nat`'s 2^48 − 1, found by `TOON_SPEC=1` on `encnum_ints`; the card's "15 digits" was wrong)
- Provenance: bend 2.0.16 commit `15ae0c8`, clang 21.1.8, Linux x86_64, AMD EPYC-Milan 8 cores (shared host), GPU none, no bang
- Exact command: `scripts/incumbent-bench.sh --runs 9 --max-cv 5 --timeout 60 --tag EXP-002 --original <binary of 4bfecef> --threads 1 -- --decode perf/inputs/large_tabular_1500.toon --port <binary of 3751630> --threads 1 -- --decode perf/inputs/large_tabular_1500.toon` (and the same with the `3751630` binary on both sides for the A/A arm)
- Kill-switch: env `TOON_SPEC=1` (read once in the shell; `F.twin.on` turns every twin selector off; law `twin_gate_switch`)
- Measured: 58.2 ms → 37.4 ms (1.56×, 36% below the baseline; precommitted gate ≥ 15%), cv 0.8% / 1.5%, 18 samples per arm in AB/BA pairs, A/A null ratio 0.995; verdict MEASURED (`perf/evidence/EXP-002.ab.json`, `perf/evidence/EXP-002.aa.json`)
- Correctness: stdout sha `b55987a665c7b80f` identical on both arms; `All terms check.` (unsafe 0 = 0 `@unsafe` + 0 template instances, bend 2.0.16); lanes c-1t, c-8t, js PASS 1053/1053 with the switch off and on; `scripts/diff-fuzz.py numbers --switch TOON_SPEC=1`: fast twin, spec twin and the original agree on every generated number text (0 differences)
- Keep-audit delta: whole program call sites, `4bfecef`→`3751630`: keep 246→255, take 244→248, seal 1679→1687, free 51→54 (the new twin defs; no new keep inside an existing hot def)
- Disposition: kept behind `TOON_SPEC`; NOT promoted to PERF-LEDGER
- Why provisional and not WIN: (1) the binding `fast == spec` is ONE quantified gate law plus CLOSED instance laws plus differential runs; no universally quantified equivalence law exists for this twin (the checker's normalizer overflows on bodies with 10^5-scale `Nat` literals); (2) the `3751630` binary carries EXP-001, EXP-002 and EXP-003 together, so this capture does not isolate one lever: the input was chosen to exercise this lever, and the other two also run on it
- Killing metric: wall on this host at 1 thread
- One lever per artifact (2026-09-20): a scratch variant of the current code with the other two twins switched off at their gates, against the all-twins-off arm (`TOON_SPEC=1`) of the current binary, captured twice (9 and 15 pairs): REFUSED_CV both times (second attempt: cv 5.2% / 5.0%, A/A arm 5.9% / 3.1%), so NO ratio is claimed. The refused medians, 65.5 ms → 63.4 ms (about 3% below), are far from this card's gate (≥ 15%): the ratio measured above belongs to the THREE levers together on this input, and this lever ALONE is not shown to meet its gate (`perf/evidence/EXP-002.one-lever.ab.json`, `.aa.json`)
- **Promote to WIN when:** a quantified `fast == spec` law for the twin checks, OR the owner accepts closed laws + differential runs as the binding in writing; AND the capture is repeated with one lever per artifact
- Tally: W0/L0/N0 (provisional)
- Agent: Claude (author session)

### NE-003 — division by a power of ten through single-limb short division   [2026-09-20 | PROVISIONAL_LOCAL_WIN]
- Program / def: `port/f64.bend`, `port/bignat.bend` / `BN.div_pow10`, `F.div_p10`, `F.from_dec_p10`
- Provenance: bend 2.0.16 commit `15ae0c8`, clang 21.1.8, Linux x86_64, AMD EPYC-Milan 8 cores (shared host), GPU none, no bang
- Exact command: `scripts/incumbent-bench.sh --runs 9 --max-cv 5 --timeout 60 --tag EXP-003 --original <binary of 4bfecef> --threads 1 -- --encode perf/inputs/decimals1_9000.json --port <binary of 3751630> --threads 1 -- --encode perf/inputs/decimals1_9000.json` (and the same with the `3751630` binary on both sides for the A/A arm)
- Kill-switch: env `TOON_SPEC=1` (read once in the shell; `F.twin.on` turns every twin selector off; law `twin_gate_switch`)
- Measured: 288.2 ms → 135.6 ms (2.12×, 53% below the baseline; precommitted gate ≥ 30%), cv 0.8% / 0.7%, 18 samples per arm in AB/BA pairs, A/A null ratio 1.004; verdict MEASURED (`perf/evidence/EXP-003.ab.json`, `perf/evidence/EXP-003.aa.json`)
- Correctness: stdout sha `26ff3ffebdf2bac5` identical on both arms; `All terms check.` (unsafe 0 = 0 `@unsafe` + 0 template instances, bend 2.0.16); lanes c-1t, c-8t, js PASS 1053/1053 with the switch off and on; `scripts/diff-fuzz.py numbers --switch TOON_SPEC=1`: fast twin, spec twin and the original agree on every generated number text (0 differences)
- Keep-audit delta: whole program call sites, `4bfecef`→`3751630`: keep 246→255, take 244→248, seal 1679→1687, free 51→54 (the new twin defs; no new keep inside an existing hot def)
- Disposition: kept behind `TOON_SPEC`; NOT promoted to PERF-LEDGER
- Why provisional and not WIN: (1) the binding `fast == spec` is ONE quantified gate law plus CLOSED instance laws plus differential runs; no universally quantified equivalence law exists for this twin (the checker's normalizer overflows on bodies with 10^5-scale `Nat` literals); (2) the `3751630` binary carries EXP-001, EXP-002 and EXP-003 together, so this capture does not isolate one lever: the input was chosen to exercise this lever, and the other two also run on it
- Killing metric: wall on this host at 1 thread
- One lever per artifact (2026-09-20, the second reason above, for THIS lever): a scratch variant of the current code with the other two twins switched off at their gates (`twin.on(True{}, …)`), against the all-twins-off arm of the current binary (`TOON_SPEC=1`): 312.3 ms → 152.5 ms, 2.05×, cv 2.7% / 3.9%, A/A 1.019, MEASURED (`perf/evidence/EXP-003.one-lever.ab.json`, `.aa.json`). The same captures for EXP-001 and EXP-002 were REFUSED_CV while a reviewer's builds ran — the arms' cv, original / port: EXP-001 3.1% / 5.3% (`.ab`) and 20.6% / 14.9% (`.aa`), EXP-002 5.2% / 5.0% (`.ab`) and 5.9% / 3.1% (`.aa`), 30 samples each; their files are in `perf/evidence/` and claim nothing
- **Promote to WIN when:** a quantified `fast == spec` law for the twin checks, OR the owner accepts closed laws + differential runs as the binding in writing; AND the capture is repeated with one lever per artifact
- Tally: W0/L0/N0 (provisional)
- Agent: Claude (author session)

### NE-004 — EXP-004 on the folding input: the ratio against the original   [2026-09-20 | NO_EVIDENCE]
- Program / def: `port/encode.bend` / `keys.kt`, `dotted.set`, folding's sibling test on `T.KT`
- Provenance: as NE-001
- Exact command: `scripts/incumbent-bench.sh --runs 7 --max-cv 5 --timeout 60 --tag EXP-004 --original ./oracle/toon -e --key-folding safe perf/inputs/fold_keys_30000.json --port <binary of 1230a0d> --threads 1 -- -e --key-folding safe perf/inputs/fold_keys_30000.json`
- Kill-switch: none (a carrier of the spec twins)
- Measured: REFUSED_CV four times. A fourth capture on 2026-09-20 against the `opt-level=3` incumbent (15 pairs, 30 samples) was refused on the PORT's arm again: cv 2.2% / 8.5% (original / port), medians 336 ms and 339 ms (`perf/evidence/INCUMBENT-O3.fold.json`). Four refusals, three of them on the port's arm, are themselves the finding: this input's port-side timing is not stable on this host at this size, which is what the retry predicate below already demanded be answered at 60000 keys. First two (port arm cv 5.2% with 5 pairs, then 6.8% with 7 pairs; the original's arm 2.1%); the third (15 pairs, load about 3) was refused too: cv 7.5% / 5.6% (original / port), medians 668.4 ms and 452.5 ms, 30 samples per arm. Only the third is in `perf/evidence/EXP-004.fold-vs-original.json`: each capture overwrote the file before it, so the medians of the first two (307 ms and 303 ms) survive only in this entry and in `git show 53df4c1:perf/evidence/EXP-004.fold-vs-original.json`. No ratio is claimed. What the refused captures still show without a ratio: the previous port binary (`3751630`) did not finish this input in its 60 s budget (`perf/evidence/EXP-004.baseline-fold.json`), and stdout was byte-identical to the original's in every sample of all three.
- Correctness: as NE-005's
- Disposition: the carrier is kept (it is the spec twin); the RATIO is not ledgered
- Killing metric: wall on this host at 1 thread
- **Do-not-retry unless:** the host is quiet (no other agent's build; load below 1) and `--runs 15`; a second refusal under those conditions means the input's allocation pattern is noisy at this size: then capture at 60000 keys
- Tally: W0/L0/N3
- Agent: Claude (author session)

### NE-005 — EXP-004, hashed key carriers, on three scale inputs   [2026-09-20 | PROVISIONAL_LOCAL_WIN]
- Program / def: `port/text.bend` `kt.*`, `port/json.bend` `km.*` / `obj.member`, `port/encode.bend` `row.lock` / `put.cells`, `port/decode.bend` `XV` / `xm.*`
- Provenance: bend 2.0.16 commit `15ae0c8`, clang 21.1.8, Linux x86_64, AMD EPYC-Milan 8 cores (shared host; the model name is NOT in the capture JSONs, whose `cpu` field is empty), GPU none, no bang
- Exact command: `scripts/incumbent-bench.sh --runs 5 --max-cv 5 --timeout 60 --tag EXP-004 --original ./oracle/toon <args> --port <binary of 1230a0d> --threads 1 -- <args>` for the port against the ORIGINAL; the port's own earlier build (`3751630`) was timed ONCE per input under a 60 s budget (`perf/evidence/EXP-004.baseline-*.json`)
- Kill-switch: none (the carrier is part of the spec twins)
- Measured: earlier build → build of `1230a0d`: 20.5 s → 66.2 ms (16000 keys in one object), 6.5 s → 74.6 ms (20 rows of 1200 fields), more than 60 s (cut at its budget) → 772.3 ms (40000 expanded lines; at least 77 times, 60.0 s / 772.3 ms = 77.7). Against the original, MEASURED with cv ≤ 4.7% on both arms: 0.25×, 1.27×, 3.06× (`perf/evidence/EXP-004.*-vs-original.json`); regression captures against `3751630` on the four earlier inputs: 0.997, 0.992, 0.994, 1.022
- Correctness: stdout sha identical to the original's in every sample; `All terms check.` (unsafe 0 = 0 `@unsafe` + 0 template instances, bend 2.0.16); lanes PASS; `scripts/diff-fuzz.py` lenses docs, expand, collide, scale: 0 differences
- Keep-audit delta: whole program call sites, `3751630`→`1230a0d`: keep 255→268, take 248→298, seal 1687→1770, free 54→56 (`perf/evidence/keep-audit.3751630.txt`, `keep-audit.1230a0d.txt`)
- Disposition: kept (it repairs a quadratic, round 6's finding); NOT in PERF-LEDGER
- Why provisional and not WIN: the comparison with the earlier build has ONE baseline run per input, no cv and no A/A arm, so the ledger's rule 2 refuses it however large the difference is; the evidence directory holds the JSON lines and the keep-audit outputs, not the emitted C (rule 7); the fingerprints lack the CPU model (rule 6). The ratios against the original ARE cv-gated, and they are the only ones a document may quote as MEASURED
- Killing metric: wall on this host at 1 thread
- **Promote to WIN when:** AB/BA captures with an A/A arm exist for the earlier build against this one at sizes the earlier build finishes well inside the timeout (4000 keys, 300-field rows, 8000 expanded lines), with the emitted C of both builds in the evidence directory and the CPU model in the fingerprint
- Tally: W0/L0/N0 (provisional)
- Agent: Claude (author session); the refusal is round 10's (non-author)

### NE-006 — the port against the original on ordinary inputs, and against the strongest build of it   [2026-09-20 | MEASURED_LOSS]
- Program / def: the whole pipeline (`run_pure`); no lever, no kill-switch. This entry exists because every measured outcome, including a loss, needs a register row: round 12's R12-11 found these ratios published in README, PORT_REPORT and PORT_STATE with no entry anywhere
- Provenance: bend 2.0.16 commit `15ae0c8`, clang 21.1.8, Linux x86_64, AMD EPYC-Milan 8 cores (shared host), 1 thread, no bang; port binary sha256 `27787b9b…` (reproduced by `bend port/main.bend -o <dir>/toon` from any commit since `a725d10`; the emitted binary is byte-identical whatever the directory, the output BASENAME being the only path input)
- Exact command: `scripts/incumbent-bench.sh --runs 15 --max-cv 5 --tag INCUMBENT --original ./oracle/toon <args> --port <binary> --threads 1 -- <args>`
- Kill-switch: none
- Measured, against the PINNED original (`opt-level="z"`, 30 samples per arm): 0.114× on the 1500-row table encode (6.3 ms vs 54.9 ms, cv 4.5% / 3.8%), 0.404× on its decode (15.5 ms vs 38.4 ms, cv 4.7% / 2.7%), 0.0066× on 20000 doubles (7.7 ms vs 1164.6 ms, cv 3.2% / 2.8%) — `perf/evidence/INCUMBENT.tabular-enc.json`, `.tabular-dec.json`, `.doubles.json`. The port needs 8.7, 2.5 and 151 times the original's time on those inputs
- Measured, against the STRONGEST build (`opt-level=3`, which is 1.389× the pinned build on the expand input, cv 1.3% / 2.4%, `perf/evidence/INCUMBENT-O3.vs-z-expand.json`): 1.989× on 40000 expanded lines (1716 ms vs 863 ms, cv 3.1% / 3.1%) where the pinned build gave 3.06×, and 0.773× on 20 rows of 1200 fields (56 ms vs 72 ms, cv 4.4% / 2.3%) where the pinned build gave 1.27× — `perf/evidence/INCUMBENT-O3.expand.json`, `.wide-rows.json`. **On the wide-rows input the port is slower than the original, not faster**: the earlier "1.27×" was an artifact of comparing against the weaker build
- Refused and claiming nothing: the tabular-encode capture against the `opt-level=3` build (original arm cv 12.6% at a 5.2 ms median, `perf/evidence/INCUMBENT-O3.tabular-enc.json`); the folding input a fourth time (NE-004)
- Correctness: stdout and stderr sha identical between the arms in every sample of every capture above; exit 0 on both arms
- Disposition: a LOSS on every input but the expand one; nothing is promoted; DISC-013 is the accepted contract for the number-heavy case and beads `toon_bend-p47`, `toon_bend-okl`, `toon_bend-0m1`, `toon_bend-oiu` carry the work
- Killing metric: wall on this host at 1 thread
- **Do-not-retry unless:** the host is quiet (load below 1) AND the input makes the ORIGINAL's arm at least 100 ms, which the 5 to 16 ms arms of the three INCUMBENT rows never do (bead `toon_bend-udw`); a retry that keeps a sub-20 ms arm will refuse again however many pairs it runs
- Tally: W0/L5/N2
- Agent: Claude (author session); the missing-entry finding is round 12's (non-author), the `opt-level=3` build its R12-13

---

## Inherited priors (re-confirm on THIS program's shape; not local evidence)

From `bend guide shaders` (10-core M4 mini, 2.0.13), the runtime's comments,
the M4 pins and the skill's own machine. Full table with mechanisms:
`references/NEGATIVE-EVIDENCE-AND-LEDGERS.md` "The inherited graveyard".

| id | lever | reported measurement | original advice (historical) |
|---|---|---|---|
| NE-INH-1 | scene read through counts | 8.0 → 16.5 ms | never; borrow by matching |
| NE-INH-2 | fold per level / two bangs a frame | 600 ms vs 8 | never |
| NE-INH-3 | non-tail recursion in the bang | 5.5 → 12.6 ms | never |
| NE-INH-4 | mesh / project / light / cull on the GPU | 14–33 vs 0.6–1.6 ms | the stage becomes uniform per lane |
| NE-INH-5 | fork per pixel / per `Qua` | 2.6 vs 1.6 ms | never |
| NE-INH-6 | slivers and sub-pixel triangles | 42 ms frames | never |
| NE-INH-7 | wide records through frames and joins | 2× per entry | never |
| NE-INH-8 | `match` on `U32` literals | +21% C, +6.4% `.gpu` | the emitter gains word tables |
| NE-INH-9 | generic `Bool.pick` in hot code | reported generic representation/sharing cost; scalar words need no heap box | inspect and compare typed helpers |
| NE-INH-10 | free the scene in a bang / image freed on one host lane | 12.9 / 19.8 ms | never |
| NE-INH-11 | split heavy tiles; 32-px cells; per-lane early-out | +0.03 (neutral); +0.85; 0 | a tail-bound profile |
| NE-INH-12 | two consumers of one list | 45 ms frames; 448 s Metal compile | never |
| NE-INH-13 | a second parallel let per host def | 2.32 → 1.93 ms removed | never |
| NE-INH-14 | 32 Metal groups (M4) | bitonic 1.85 → 1.29 s; light benches 1.25× slower | runtime-level; per-hardware pin |
| NE-INH-15 | no threadgroup hold | 1.13–1.35× slower | runtime-level |
| NE-INH-16 | eight CUDA connections | startup 2× | runtime-level |
| NE-INH-17 | skewed fork | original same-depth fixture had unequal work | retest the corrected equal-leaf-count fixture |
| NE-INH-18 | affine loop as benchmark body | historical 5 ms; closed-form optimization suspected, no retained assembly | inspect generated work before assigning a cause or outcome |
| NE-INH-19 | GPU for divergent work | queens 0.76 s vs 2.68; lexer 0.43 vs 3.89; hashmap 0.52 vs 1.55 | per-lane work made uniform |
| NE-INH-20 | bang inside a `do` continuation | 2× reads | never |
| NE-INH-21 | host-built scene read by the device (CUDA) | 17–19 FPS vs 8 ms frame | frame on one side of the bus |

These are historical source claims, not local measurements. The shader
tutorial was labeled AI-written pending human revision in 2.0.14. "Never"
in this inherited table refers to advice for that workload, not a ban on
new experiments. Reconfirm the mechanism, work size and target before
using any row. Reported flat sweeps of leaf count, heavy tiles and early-out
likewise do not establish universal performance rules.
