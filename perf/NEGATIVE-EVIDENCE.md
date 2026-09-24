# Negative Evidence Ledger — toon_bend

<!-- Copy to perf/NEGATIVE-EVIDENCE.md on the day the project reaches rigor
     tier T2, BEFORE the first lever. Sweep it before starting any perf
     lever: a lever is re-attemptable only if its do-not-retry predicate
     holds. An unresolved gain needs more evidence. Record honest losing baselines. -->

The COUNTED class and its resolution (added 2026-09-23, CORRECTED the same day). An instruction count
from `valgrind --tool=cachegrind --cache-sim=no` is deterministic to about 1e-8 for the SAME binary, but
two builds are not automatically comparable.

**The mechanism is clang's inlining of an emitted `INLINE` spin loop, which flips when a def's CALL-SITE
COUNT changes** — not, as I first wrote here, the constructor table. The peer session's evidence, from
`cg_annotate` per function on `twitter.toon --decode` across two trees with IDENTICAL decode Bend code:
`WL_FID_CLI_CONVERT` goes 0 → 34.27M because `utf8.bytes`' spin loop is now inlined into the worklist
function (one call site left), while spin totals go 207.4M → 185.4M — net +12.3M of that cell's +13.0M.
In the other direction a change that added only DEFS (no constructor) moved unchanged encode code by
+0.80%, because a def gained a second call site and its loop stopped being inlined.

So **a def-only change CAN move unchanged code by about 1–2%** whenever it alters how many places call a
loop def. My control here — two trees differing only by ONE UNUSED DEF, never called — counted
**+0.000%** (760 instructions in 3,010,226,497 on `gsoc_2018`, an exact tie on `canada`). That is a
correct measurement of the wrong thing: an unused def changes no call site, so it does not test the
mechanism and **does not clear a sub-2% result**.

What that means for the four sub-2% entries below, stated per entry rather than in general:

| entry | counted | did it change a loop def's call sites? | is the FIGURE attributable? | is the CONCLUSION affected? |
|---|---|---|---|---|
| NE-019 | −1.4% | yes — an inlined `Bool.pick` chain became 16 defs | **no** | no: gate was 10%, and an independent CPU capture agreed (0.975 min) |
| NE-020 | ~1% | no — one literal changed, no def added or removed | yes | no: gate was 8% |
| NE-027 | 0.11% | possibly — two match arms removed | **no** | no: gate was 5% |
| NE-033 | −0.7% | yes — `token.short`'s arm now calls `token.dec`, giving `token.literal` a second site | **no** | no: gate was 25% |

Every one of those levers missed its gate by a wide margin, so no verdict changes. But three of the four
FIGURES fall within the inlining band and are not measurements of the lever. A counted claim must say which
kind of change it was, and a sub-2% claim needs a per-function `cg_annotate` check before it is believed.

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
- Measured, against the STRONGEST build (`opt-level=3`, whose advantage over the pinned build is input-dependent: 1.729× on wide rows, cv 2.0% / 4.2%, and 1.389× on expand, cv 1.3% / 2.4%, both MEASURED; REFUSED on the tabular encode at medians 5.84 and 4.98 ms — `perf/evidence/INCUMBENT-O3.vs-z-*.json`. Round 13's R13-1 withdrew the single factor of about 1.4× that stood here): 1.989× on 40000 expanded lines (1716 ms vs 863 ms, cv 3.1% / 3.1%) where the pinned build gave 3.06×, and 0.773× on 20 rows of 1200 fields (56 ms vs 72 ms, cv 4.4% / 2.3%) where the pinned build gave 1.27× — `perf/evidence/INCUMBENT-O3.expand.json`, `.wide-rows.json`. **On the wide-rows input the port is slower than the original, not faster**: the earlier "1.27×" was an artifact of comparing against the weaker build
- Refused and claiming nothing: the tabular-encode capture against the `opt-level=3` build (original arm cv 12.6% at a 5.2 ms median, `perf/evidence/INCUMBENT-O3.tabular-enc.json`); the folding input a fourth time (NE-004)
- Correctness: stdout and stderr sha identical between the arms in every sample of every capture above; exit 0 on both arms
- Disposition: a LOSS on every input but the expand one; nothing is promoted; DISC-013 is the accepted contract for the number-heavy case and beads `toon_bend-p47`, `toon_bend-okl`, `toon_bend-0m1`, `toon_bend-oiu` carry the work
- Killing metric: wall on this host at 1 thread
- **Do-not-retry unless:** the host is quiet (load below 1) AND the input makes the ORIGINAL's arm at least 100 ms, which the 5 to 16 ms arms of the three INCUMBENT rows never do (bead `toon_bend-udw`); a retry that keeps a sub-20 ms arm will refuse again however many pairs it runs
- Tally: W1/L4/N5 — one measured win (expand against the strongest build, 1.989×), four measured losses (the three pinned-build rows and wide rows against the strongest build), and five captures that claim nothing (the tabular encode against the strongest build, the fold a fourth time, the two pinned-build re-captures of 2026-09-20 and the build-profile capture on the tabular encode)
- Agent: Claude (author session); the missing-entry finding is round 12's (non-author), the `opt-level=3` build its R12-13

### NE-007 — EXP-005, powers of ten in steps of 10^4   [2026-09-21 | NO_EVIDENCE]
- Dates in this entry are LOCAL (UTC−4), as in every other entry and commit here. The capture's own fingerprint is UTC and reads `2026-09-21T00:54:08+00:00`, which is local 2026-09-20 20:54, minutes after the lever's commit `91927dd` (`Sun Sep 20 20:51:43 2026 -0400`); this entry was written local 2026-09-21
- Program / def: `port/bignat.bend` / `pow10.by4` (a fast twin of `pow10`), with `shortest.by4`, `shortest.sel` and the `shortest.pick` arm in `port/f64.bend`; card `perf/EXPERIMENTS.md` EXP-005, precommitted
- Provenance: bend 2.0.16 commit `15ae0c8`, clang 21.1.8, Linux-7.0.0-30-generic-x86_64 (glibc 2.43), AMD EPYC-Milan 8 cores (shared host), 1 thread, no bang; baseline binary sha256 `27787b9b…` (the port build WITHOUT the lever, the same binary NE-006 measures), lever binary sha256 `c0393686…`
- Exact command: `scripts/incumbent-bench.sh --runs 9 --max-cv 5 --tag EXP-005 --original <baseline binary> --threads 1 -- -e perf/inputs/sci_5000.json --port <lever binary> --threads 1 -- -e perf/inputs/sci_5000.json` (`perf/evidence/EXP-005.ab.json`, which records `samples: 18` per arm and no run count; `scripts/incumbent-bench.sh:80-82` runs `for arm in ('original','port','port','original')` per pair, so a pair yields **TWO** samples per arm and 18 samples means `--runs 9` — the number the EXP-005 card's own invocation at `perf/EXPERIMENTS.md` already gave, and the same factor NE-001 and NE-006 use. Both arms are builds of THIS port, so the entry says nothing about the original). This row said `--runs 18` until 2026-09-21, justified in-line by a misreading of those very lines as one sample per arm per pair; round 14 (R14-3) caught it
- Kill-switch: `TOON_SPEC=1` through the existing gate `F.twin.on(spec, ok)` (never exercised: see Correctness)
- Measured: REFUSED_CV. 18 samples per arm, medians 1312.19 ms (no lever) → 1208.72 ms (lever), cv 3.56% / 5.45% — the LEVER's arm is above the 5% gate, so the capture claims nothing and **no ratio is claimed** (`ratio` is null in the JSON). What the refused capture still shows without a ratio: the two arms' medians are about 8% apart, where the card's precommitted gate demanded at least 25%; stdout sha `494b6050…` and stderr sha were identical in every sample and both arms exited 0
- Why it was not admitted (four independent reasons, any one sufficient): the cv gate refused the capture; the refused medians are nowhere near the precommitted ≥ 25%; the card's precommitted A/A null arm was never captured (`incumbent-bench.sh` does not produce one); and the twin had **no `{fast == spec}` law** — `python3 scripts/port-lint.py port/*.bend --laws port/LAWS.bend` reported it as a PL-11 ERROR (`fast twin pow10.by4 is not named by any law in LAWS.bend`) on the tree of `91927dd`, the repository's own gate refusing the lever
- Correctness: not established and not needed. No law was written, `bend PROOF.bend` was never re-run on the lever, and no lane run and no kill-switch parity run covered it. The stdout equality above is 18 samples of one input, not evidence of equality
- Disposition: **reverted**. `port/bignat.bend` and `port/f64.bend` are byte-identical to their state at `3b67865` again (`git diff 3b67865 -- port/` is empty); the lever's source survives in commit `91927dd` and the first revert attempt in the dangling commit `0d35d55`
- Killing metric: wall on this host at 1 thread; and, before any stopwatch, the missing law
- What the round taught, which is the reusable part: the profile this card rests on is `perf/EXPERIMENTS.md` "Third profile" (a gprof `-b -p` call census of an instrumented `clang -std=c11 -O2 -pg -fno-inline-functions` build of `4c3cccc`, specializations summed; that section labels its own wall times "orientation, not evidence", and no JSON artifact exists for it). On this input it counts 72.3 M def calls: `BN.mul_small` 39.0%, nearly all under `BN.pow10`, which is itself only **3.5%** (2.5 M calls, about 500 per number, because `pow10(k)` recurses k times and the exponents reach 250). Cutting those multiplications by about four moved the median by about 8%. **A CALL census is not a WALL census**, for two reasons this round makes concrete: it weights a one-limb `mul_small` exactly like a sixty-limb one, though the limb array grows as the power is built; and the 39% it attributes to `mul_small` sits beside `BN.cmp` 27.3% and `BN.sub` 9.6%, the digit generator's own compare-and-subtract, which this lever does not touch at all and which is where EXP-006 aims (on the doubles input that same profile puts `BN.cmp`, `BN.sub`, `BN.is_ge`, `BN.is_lt` and `F.dg.*` at 75% of def calls). Choosing a lever by call share alone is what produced a precommitted 25% gate that the code could not meet
- **Do-not-retry unless:** a WALL-time profile (not a call census) attributes at least 25% of `--encode` on `perf/inputs/sci_5000.json` to `BN.pow10` and its callees, on a quiet host (load below 1) with at least 15 pairs so the cv gate can be met; or the power of ten stops being built per number at all, inside a named redesign of `F.shortest` (EXP-006's territory) rather than as a standalone lever. A retry that re-runs THIS lever unchanged is refused in advance
- Tally: W0/L0/N1
- Agent: Claude (author session)

### NE-008 — numbers rendered by a PARALLEL pre-pass (EXP-007), on the CPU worker pool   [2026-09-22 | ADMITTED, ratios NO_EVIDENCE]
- Program / def: `port/encode.bend` / `pre` (a pass that renders every number's text before emission and forks long item chains with parallel lets) plus `port/json.bend` / `num.defer`, `raw.f64` (the reader keeps a token raw when it cannot overflow). NOT in the repository: the spike is `perf/evidence/EXP-007.parallel-prerender.patch` against `3851a08`; card EXP-007
- Provenance: bend 2.0.16 commit `15ae0c8`, clang 21.1.8, Linux x86_64, AMD EPYC-Milan 8 cores, SHARED HOST AT LOAD 8-9 THROUGHOUT (other agents' gates), single timed runs unless a line says otherwise
- Exact command: `<spike binary> --threads N -- --encode perf/e2e/corpus/<doc>.json`, the documents of `perf/e2e/corpus.json`
- Kill-switch: none in the spike. A `TOON_SPEC=1` arm was NOT captured
- Correctness (the part that IS established): `./scripts/conform.sh goldens/cases.tsv goldens --lane spike -- <spike> --threads 8 --` → 1071/1071 PASS against the goldens of `3851a08`; and 60 encodes of the 20 real documents of `perf/e2e/` (default, `--key-folding safe`, `--stats`) byte-identical to the original `7c1d6e4`. Parallelism did not change one output byte
- Measured (orientation only, single runs on a loaded host; the cv gate REFUSED the one paired capture): `numbers` 0.43 s → 0.12 s at 8 threads, `mesh` 1.22 → 0.47, `flights_200k` 11.3 → 6.3, `canada` 5.54 → 4.31 (its best, at TWO threads; 8 threads is slower than 2), `marine_ik` 3.14 → 3.03, `twitter` and `semanticscholar` unchanged. `scripts/incumbent-bench.sh --runs 5` on `numbers` (base at 1 thread against the spike at 8): REFUSED_CV, medians 460.6 → 190.2 ms, cv 18.1% / 10.0%, stdout sha identical in every sample
- The ceiling, which is the reusable finding: 8 SEPARATE single-thread processes converted 8 copies of `canada` in 13.6 s wall, against 6.1 s for one process alone — about 3.6× of throughput from the same 8 cores — while ONE process at 8 threads reached 1.4× on that document. The hardware had the capacity; the runtime did not use it. The port's own profile says why (`perf/evidence/EXP-006.wall-profile.txt`): its time is BendRT memory management (`span_fade` 34.6% self, `term_drop` 37.0% self), which is refcount and free traffic on ONE shared heap, so more threads add contention rather than throughput on the documents whose numbers allocate most (canada and marine_ik carry 17-digit doubles)
- Disposition: NOT admitted, NOT committed to `port/`. No law binds `pre` to the pass-free pipeline, and the capture was refused
- Killing metric: wall on this host; and, before the stopwatch, the missing law
- **Do-not-retry unless:** a quantified law `{encode(pre(f, j, …), opt) == encode(j, opt)}` is written and proved first (the pass is a reordering of the same function, so the law is the natural one, and `port-lint.py` PL-11 would demand it anyway); AND the capture runs on a quiet host (load below 1) with at least 15 pairs; AND the document's ORIGINAL arm reaches 100 ms (NE-006's predicate). A retry on the 17-digit-double documents (`canada`, `marine_ik`) also needs the allocation cost addressed first (`toon_bend-2t0`, closed since), because their scaling stops at two threads for a reason no thread count changes
- **ADMITTED 2026-09-22 (commit `0131342`), and what changed since the lines above.** The pass is in
  `port/` now, behind the existing `TOON_SPEC=1` kill-switch, with three laws the checker proves:
  `pre_gate_switch` (for EVERY value, the switch hands the value to the emitter untouched),
  `pre_txt_is_num` and `pre_raw_is_num` (a rendered or deferred number prints exactly what `put.prim`
  would have printed for its `JNum`). The 295 closed whole-pipeline golden laws now run THROUGH the
  pass inside the checker, so the proof gate re-verifies it on every one of them. Gates on the wired
  tree: `bend PROOF.bend` → `All terms check.` (396 laws at that commit); conform 1071/1071 on c-1t, on c-8t and on
  js; kill-switch parity on six real documents (`TOON_SPEC=1` and off, both equal to the original);
  `diff-fuzz docs` 2500 inputs and `numbers`, 0 differences; `port-lint` OK. The INTERPRETER lane had
  not been run when this line was written
- **The runtime tax a parallel let puts on the SEQUENTIAL phases of the same program** (2026-09-22, the
  finding that matters most here). The encode-only build made `--decode` SLOWER, although decode never
  calls the pass: interleaved, min of 5, decode of mesh at `--threads 8`, base 1285 ms → 1609 ms (1.25×)
  and flights_200k 9220 → 12170 ms (1.32×). Attribution, decode of mesh, base against that build:
  `--threads 1` 0.99× with the twins on and 1.05× with `TOON_SPEC=1`; `--threads 8` **1.36×** with the
  twins on and **1.34×** with `TOON_SPEC=1`, which disables the pass entirely. The penalty is the same
  whether the pass runs or not and does not exist at one thread, so it is not the pass executing: a
  program that CONTAINS a parallel let takes the runtime's parallel path above one thread, and every
  sequential phase pays for it in proportion to its heap traffic (mesh decode, allocation-heavy, pays 35%;
  twitter encode, string-heavy, pays nothing measurable — 179.3 ms against base's 184.6 ms with everything
  off). **Partial parallelisation is therefore a trap in this runtime**: whatever phase is left sequential
  regresses at the default thread count, which is why the decode half is a repair and not an extension
- **The decode half** (2026-09-22): the same pass before `J.write_ln`, rendering the JSON number text.
  Interleaved, min of 5, base against both passes at `--threads 8`: decode numbers 376 → 175 ms (2.15×),
  mesh 1234 → 627 ms (1.97×), flights_200k 9228 → 5053 ms (1.83×), gsoc_2018 1074 → 1100 ms (0.98×);
  encode canada 5270 → 3843 ms (1.37×), twitter 154 → 175 ms (0.88×). At `--threads 1` every case is 3 to
  7% slower than base. Gates: `All terms check.`; conform 1071/1071 on c-1t, c-8t and js; 72 decode runs
  (6 documents × 6 thread counts × the kill-switch both ways) byte-identical to the original; diff-fuzz
  docs and expand, 1500 inputs each, 0 differences
- **A thread-count default was chased and REFUSED, 2026-09-22.** A first sweep (best of 3) suggested the
  parallel gain saturates at 2 to 4 threads while the tax keeps growing, with encode of twitter at 156 ms
  on 4 threads against 275 ms on 8 — which would have made the binary's default (the CPU count) the worst
  setting, and `bin/toon` already has the knob (`TOON_BEND_THREADS`). Re-measured INTERLEAVED, min of 5,
  the claim did not survive: the best thread count is different per document and mostly noise (encode
  twitter 220 / 217 / 204 ms at 2 / 4 / 8 threads, semanticscholar 3005 / 2724 / 3013, canada 5448 / 5118
  / 6137, decode gsoc_2018 1192 / 1238 / 1216, decode flights_200k 7256 / 5423 / 5163, encode numbers 207
  / 128 / 109). **No default is changed.** Do-not-retry unless a quiet host (load below 1) gives a
  consistent optimum across at least five documents of different shapes, and a second machine with a
  different core count agrees
- **Thread-count determinism, the risk this lever actually carries** (2026-09-22, on the wired build):
  8 documents (numbers, canada, mesh, flights_20k, twitter, citm_catalog, jobs, us_10m) encoded at
  `--threads` 1, 2, 3, 8, 16, 64 and 128 — 56 runs, every one byte-identical to the original. A fork-order
  bug would show as a thread count whose output differs from the others; none does. This is evidence about
  THESE documents at THESE thread counts, not a proof: the laws cover what a rendered number prints, not
  the order in which the pool renders them
- **The ratios are still NO_EVIDENCE and the entry keeps that word.** Three interleaved cv-gated
  captures on 2026-09-22 (base at `--threads 1` against the wired build at `--threads 8`, 7 pairs each)
  were all REFUSED: 10001 doubles 418.6 → 155.6 ms (cv 10.2% / 16.3%), canada 6025.5 → 4504.7 ms (cv
  5.0% / 6.1%), twitter 199.5 → 211.1 ms (cv 9.4% / 12.5%); stdout identical in every sample of all
  three. The host carried seven other agents at load 13 throughout. What the medians orient toward: a
  2 to 3× gain where the numbers are, a gain of about 1.3× on the two 17-digit-double documents, and a
  LOSS of about 6% on the text-heavy ones at 8 threads which is neutral at 1 thread — that loss is
  measured beside other agents on the same cores and is not separated from them
- **The threshold was tuned once and the loser is recorded:** forking arrays longer than 512 items
  instead of 64 was worse everywhere (10001 doubles 152 → 240 ms, mesh 532 → 753 ms, canada 4001 →
  5665 ms) and did not remove the twitter loss, so 64 stays
- Tally: W0/L0/N1
- Agent: Claude (author session, 2026-09-22)

### NE-009 — the GPU: a bang on that same pass, on two RTX 4090s   [2026-09-22 | NEGATIVE(reverted)]
- Program / def: the EXP-007 spike with ONE character added, `pre!(…)` in `port/encode.bend` / `encode`, so the runtime may run the pass on a device. The emitted C carried the bang (`toon.gpu`, 1257816 bytes, built by `bend port/main.bend -o toon` with CUDA 12.4 present)
- Provenance: bend 2.0.16 commit `15ae0c8`, clang 21.1.8, CUDA 12.4, driver 595.91.07, 2 × NVIDIA GeForce RTX 4090 (24564 MiB each), AMD Ryzen Threadripper PRO 5995WX, 64 cores, Linux; host `threadripperje`. SHARED HOST AT LOAD 17-100 (another agent's cross-build), single timed runs
- Exact command: `./toon --gpu on --threads 8 -- --encode ../corpus/<doc>.json` against `./toon --gpu off --threads {1,8,64} -- …`
- Correctness: every GPU run's stdout was byte-identical to the original `7c1d6e4` (`numbers`, `mesh`, `canada`). The device ran the work (device 0 at 100% utilisation, 681 MiB, during the `canada` run)
- Measured (orientation; the SIGN is not in doubt at these magnitudes): `numbers` 0.20 s at 8 CPU threads → **1.46 s** on the GPU (7.3× slower); `mesh` 1.37 → **3.94 s** (2.9× slower); `canada` 5.05 s at 64 CPU threads → **357.84 s** on the GPU (71× slower)
- Why, and this is the part that generalises: the pass is not uniform numeric work. Each number walks a software binary64 over big naturals whose limb count depends on its digits, so lanes diverge; and every step allocates and frees in the one shared corpus, which on a device is exactly the traffic a GPU cannot absorb. The skill's inherited priors say the same of divergent workloads (lexer 0.43 s CPU-parallel against 3.89 s GPU); this port's own numbers now confirm it on real hardware for THIS program
- Disposition: reverted (the bang exists only in the spike copy). The parity board's `gpu` row stays MISSING, and its reason gains a measurement instead of a judgement: not merely "text with data-dependent structure", but 71× slower on the document that would have benefited most
- Killing metric: wall against the CPU pool on the same binary and input
- **Do-not-retry unless:** the number path stops allocating per digit (a limb-array representation with a bounded working set), AND a document is found whose per-item work is uniform and long enough to amortise a device round (the roofline in HARDWARE-PLAYBOOK), AND the CPU arm is itself scaling (NE-008's ceiling lifted). Re-running THIS bang on THIS pass is refused in advance
- Tally: W0/L1/N0
- Agent: Claude (author session, 2026-09-22)

---

### NE-010 — a quotient estimate per digit in the shortest-digit generator (EXP-006)   [2026-09-22 | PROVISIONAL]
- Program / def: `port/f64.bend` / `dg.digit_fast` (+ `.fin`, `.fix`), `dg.step.fast`, `dg.step.with`, `dg.gen.with`, `dg.run.with`, `shortest.with`, the gate in `shortest_fast`; `port/bignat.bend` / `len`, `above`. Kept behind `F.twin.on` (`TOON_SPEC=1` selects the ten-round spec loop)
- Provenance: bend 2.0.16 commit `15ae0c8`, clang 21.1.8, Linux x86_64, AMD EPYC-Milan 8 cores, SHARED HOST AT LOAD 9-13 (other agents' gates); base binary sha256 `3581658e…` (HEAD `3c55410` without the lever), lever binary `4903d373…`, `--threads 1`
- Binding (the weaker kind, as NE-001..003): six closed laws on the digit step at each branch of the estimate (`dg_digit_fast_1limb`, `_2limb`, `_low` (estimate one below the digit), `_exact`, `_fallback` (estimate >= 10: the spec loop decides), `_zero`), `All terms check.` over the 401 laws of `455ece6`, at that commit (unsafe 0 = 0 `@unsafe` + 0 template instances, bend 2.0.16); no quantified `fast == spec` law (the checker's Nat arithmetic exhausts memory at 2^48-scale values: a first `_low` instance at s = 2^48 - 1 aborted at the 6 GiB probe cap, the committed one uses s = 2^32). The argument that makes it exact on every input is in the def's comment: with k = n - 2 limbs dropped, S2 >= 2^16 and the estimate floor(R2 / (S2 + 1)) is within one below the digit (error < 11 / S2); an estimate >= 10 falls back to the spec loop
- Correctness evidence: `conform.sh` 1071/1071 on c-1t with and without `TOON_SPEC=1`, 1071/1071 on js; a seeded differential of 1,000,000 doubles (random bit patterns, 17-digit values, subnormals, neighbours of powers of two and ten, short decimals; 50 documents of 20000) encoded and decoded by the original `694d73b`, the fast twin and the spec twin: `{"numbers": 1000000, "diffs": 0, "verdict": "SAME"}`
- Exact command (the card's): `scripts/incumbent-bench.sh --runs 15 --max-cv 5 --tag EXP-006 --original <base> --threads 1 -- -e perf/inputs/doubles_20000.json --port <lever> --threads 1 -- -e perf/inputs/doubles_20000.json` → **REFUSED_CV** (`perf/evidence/EXP-006.capture-refused-cv.json`): medians 1278.4 → 675.5 ms, cv 5.3% / 8.8%, 30 samples per arm, stdout sha identical
- Orientation (interleaved ABBA, 8 rounds, not the cv-gated tool): `canada` 6112.6 → 3243.8 ms, 1.884× by median, 1.935× by minimum, 1.852× by CPU, cv 3.3% / 4.2%; `numbers` 1.79× / 1.97× / 1.87×; `mesh` 1.62× / 1.89× / 1.70×; `doubles_20000` 1.87× / 1.86× / 1.83×. Every estimator on every input clears the card's precommitted gate (≥ 30% below the baseline); the cv gate on the card's own input does not
- Profile after the lever (gprof, `canada --encode`): `BN.cmp` 22.8 M → 7.5 M calls, 45.5% → 25.7% inclusive
- Killing metric: none yet. Promotion to a ledger WIN needs: a cv-gated capture (a quiet host, the card's command) AND either a quantified law or the owner's acceptance of closed laws + the 10^6 differential (bead `toon_bend-clf`, the same question as NE-001..003)
- **COUNTED 2026-09-23** (valgrind 3.26 cachegrind, `--cache-sim=no`, deterministic to 6e-8 run to run;
  `--encode perf/inputs/doubles_20000.json` at `--threads 1`, the input this card names):

  | arm | I-refs |
  |---|---|
  | lever ON (current binary) | **5,298,462,439** |
  | lever OFF (`dg.digit_fast.fin` forced to its spec arm) | **9,283,456,452** |

  **The lever removes 42.9% of the instructions (1.752x fewer).** Output byte-identical between the two
  arms (sha256 `f44011cd…`).
- **Corroborating CPU time** (interleaved, both orders, 7 rounds per arm, child CPU): ON min 0.566 s
  median 0.574 s (cv **7.2%**); OFF min 1.051 s median 1.088 s (cv 3.6%). **1.855x by min, 1.896x by
  median.** The two currencies agree.
- **Why this is still PROVISIONAL_LOCAL_WIN and not WIN:** the card's success criterion is a wall-clock
  capture with **cv <= 5% on both arms**, and the ON arm's cv is 7.2% on this shared host. A 7.2% cv
  cannot manufacture an 85% effect, so the gain is not in doubt — but the stated criterion is the stated
  criterion, and "counted" is a different claim class that does not retroactively satisfy a gate
  precommitted in wall-clock terms. The entry now carries numbers where it had none; the outcome label
  waits for a host at load < 1.
- **Do-not-retry unless:** (not a loss) — re-capture when the load average is below 1
- Tally: W0/L0/N1 (provisional)
- Agent: Claude (session ef481f9c, 2026-09-22)

### NE-011 — a lean fold context: no path prefix grown while folding is off (EXP-008)   [2026-09-22 | PROVISIONAL]
- Program / def: `port/encode.bend` / `FCtx.lean`, `fctx.child`, `fctx.lean`, `fctx.item`, `fctx.root`. Kept behind `F.twin.on` (`TOON_SPEC=1` makes no context lean)
- Provenance: as NE-010; base = the NE-010 lever binary `4903d373…`, lever binary `edfd3d5c…`
- Binding (stronger than NE-010): two QUANTIFIED laws, `fold_off_never_folds` (with folding off a fold attempt yields `Fold{0n, SNil}` whatever the prefix, budget, root-literal set and lean flag hold: the prefix is observable only through a fold) and `fctx_lean_closed_by_switch` (under `TOON_SPEC=1` no context is lean); both `All terms check.` in 1.7 s each
- Correctness evidence: `conform.sh` 1071/1071 on c-1t with and without `TOON_SPEC=1`
- Orientation (interleaved ABBA, 8 rounds): `openapi_github --encode` (13 MB, deep schemas) 4785.5 → 3858.4 ms, 1.240× by median, 1.329× by minimum, 1.269× by CPU, cv 1.6% / 4.4%; `vscode_lock` 1.305× / 1.275× / 1.26× (cv 8.9% / 6.5%); `twitter` 1.09× / 1.13× / 1.12×. The profile had given `fctx.child` 18.5% inclusive on the OpenAPI encode (`perf/e2e/results/2026-09-22-694d73b/profiles/openapi_encode.inclusive.txt`)
- Killing metric: none yet; promotion needs a cv-gated capture on a quiet host
- **COUNTED 2026-09-23** (valgrind 3.26 cachegrind, `--cache-sim=no`, deterministic; `--encode` of
  the corpus document `gsoc_2018.json` (fetched into `perf/e2e/corpus/`, which is gitignored), 3.2 MB, at `--threads 1`, folding off, which is the case the lever is
  for): lever ON **7,325,873,584** I-refs, lever OFF (`fctx.lean` forced `False{}`) **7,457,489,302** —
  **the lever removes 1.8% of the instructions (1.018x)**. Output byte-identical between the arms.
  `TOON_SPEC=1` was NOT used as the off arm: it would also close the number twins and confound the count.
- **Reading:** 1.8% is a real but small effect, and far below what the earlier orientation implied. The
  lever costs nothing and is already proved by `fctx_lean_closed_by_switch`, so it stays; but it should
  not be described as a significant win, and a wall-clock capture is unlikely ever to resolve 1.8% on
  this host.
- **Do-not-retry unless:** (not a loss) — re-capture when the load average is below 1
- Tally: W0/L0/N1 (provisional)
- Agent: Claude (session ef481f9c, 2026-09-22)

### NE-012 — BN.cmp that borrows its operands instead of taking shared copies (`toon_bend-2t0`, closed since)   [2026-09-22 | NEGATIVE(not built)]
- Program / def: `port/bignat.bend` / `cmp`. Probe: a ten-def program comparing `List<&2, U32>` operands through the recursive shape, a tail-recursive verdict accumulator, and a variant whose match binds the limb plainly and hands both scalars to a helper; call sites as nested calls, sequential lets, a parallel let, and a reader that returns the operand
- Result (`scripts/keep-audit.sh` of bend2-mega-skill on the probe and on `port/main.bend`): every variant TAKES both lists (`ctr_take`, `take` 3, `peek` 0) and every call site KEEPS its operands (`keep` 2-4); the tail-recursive form compiles to a flat `spin_N` loop but still `ctr_take`s. Borrow inference never lent a `List<&2, U32>` in any shape tried, although the skill's own `keeps_shared.bend` borrows a user tree read twice. So the `span_fade` time under `cmp` (the shared copies taken apart) has no source-level lever found
- **Do-not-retry unless:** a Bend release changes borrow inference for `List` (re-run the probe first: `scratchpad` copy in the session, ten lines), OR the number path stops carrying big naturals as lists (a limb-array or scalar-pair representation for values below 2^106)
- Tally: W0/L0/N0 (negative finding, nothing built)
- Agent: Claude (session ef481f9c, 2026-09-22)

### NE-013 — the header parser looks for '[' before it cuts the line (EXP-009, bead toon_bend-z3z)   [2026-09-22 | PROVISIONAL]
- Program / def: `port/decode.bend` / `hdr.a.plain.pre`, `hdr.a.first`. Not behind the switch: both branches compute the same verdict (with no `[` the cut misses and `hdr.a.plain` answers `HNot`)
- Provenance: bend 2.0.16 commit `15ae0c8`, clang 21.1.8, Linux x86_64, AMD EPYC-Milan 8 cores, SHARED HOST AT LOAD 11 (other agents' builds, one of them 14 GB); base = the zgb binary sha256 `dbf3edf2f9a4c9c2…` (the NE-011 tree plus the toon_bend-zgb carrier), lever binary `a63151ed793e6164…`, `--threads 1`
- Binding (the weaker kind): four closed laws, one per path of the unquoted branch (`hdr_precheck_miss`, `_hit`, `_colon_first` (a `[` after the colon belongs to the value), `_unclosed`), `All terms check.` in a scratch book of the eight new laws; no quantified law (it needs a lemma that `T.has_char(s, 91)` false makes `T.cut(s, 91)` miss, by induction over both loops' accumulators; not attempted)
- Correctness evidence: `conform.sh` 1071/1071 on c-1t; `scripts/diff-fuzz.py` seed 11: mutate, docs, expand 1500 inputs each and scale 20, 0 differences
- Orientation (interleaved ABBA, 6 rounds, load 11): `gsoc_2018 --decode` 1290.4 → 1106.5 ms, 1.166× by median, 1.233× by minimum, 1.157× by CPU, cv 4.7% / 8.8%: the lever arm's cv is above the gate, so this is not a capture
- Killing metric: none yet; promotion needs a cv-gated capture on a quiet host
- **COUNTED 2026-09-23** (cachegrind, `--cache-sim=no`, deterministic; `--decode` of the 3.0 MB
  `gsoc_2018.toon` at `--threads 1`, the input this card names): lever ON **7,356,972,045** I-refs,
  lever OFF (`hdr.a.plain.pre` forced to always cut, the pre-EXP-009 behaviour) **8,881,143,736** —
  **the lever removes 17.2% of the instructions (1.207x)**. Output byte-identical between the arms.
- **Reading:** this CORROBORATES the earlier orientation of 1.157x with a deterministic number, and is
  slightly better than it. The precheck is a real win on header-poor documents, which is the common case.
- **Do-not-retry unless:** (not a loss) — re-capture when the load average is below 1
- Tally: W0/L0/N1 (provisional)
- Agent: Claude (session ef481f9c, 2026-09-22)

### NE-014 — trim_end returns a text that ends in a non-White_Space character as it is (EXP-010)   [2026-09-22 | NEUTRAL, reverted]
- Program / def: `port/text.bend` / `trim_end` (an `ends_ws` walk to the last character, then the old reversal only when it is White_Space)
- Provenance: as NE-013; base = the EXP-009 binary `a63151ed793e6164…`, `--threads 1`, load 10-13
- Mechanism confirmed: gprof of the lever tree on `gsoc_2018 --decode`: `String.reverse` 154994 → 61458 calls, 21.0% → 9.7% inclusive
- Wall (interleaved ABBA, 12 rounds): `gsoc_2018 --decode` 1105.2 → 1097.5 ms, 1.007× by median, 1.016× by minimum, 1.057× by CPU, cv 8.3% / 8.8%; `twitter --decode` 209.8 → 208.6 ms, 1.006× / 0.985× / 1.009×, cv 11.6% / 20.6%. A 6-round run had shown 1.039× / 0.991× / 1.063×. The precommitted 5% is not met by any estimator but CPU, whose margin is inside the noise
- Why it did not pay (orientation): the reversals are short (keys and short values); the drops that dominate the flat profile (`term_drop`, `span_fade`) sit under the JSON writer (`spin_365`, 20%) and are unchanged
- **Do-not-retry unless:** a quiet host (load below 1) gives a cv ≤ 5% capture tool run, OR an input whose values are long texts (the gain scales with value length) is the target
- Tally: W0/L0/N1 (neutral)
- Agent: Claude (session ef481f9c, 2026-09-22)

### NE-015 — the JSON writer decides an empty container by pattern, not by a shared look at its chain (EXP-011)   [2026-09-22 | PROVISIONAL]
- Program / def: `port/json.bend` / `w` (the `JArr` and `JObj` arms; `w.close` removed, now unused). Not behind the switch: the same text by construction (the empty chain is the pattern, the non-empty arm is the old `False` branch of `w.close`)
- Provenance: as NE-013; base = the EXP-009 binary `a63151ed793e6164…`, lever binary `7963669b9aaadef7…`, `--threads 1`, load 10-11
- Binding (the weaker kind): four closed laws on the output text (`write_empty_array`, `write_empty_object`, `write_nested_indent_2`, `write_nested_indent_0`), `All terms check.` against the lever's writer AND against the previous writer (a scratch book of the four laws over each `json.bend`), so the instances pin that the text did not change
- Correctness evidence: `conform.sh` 1071/1071 on c-1t; `scripts/diff-fuzz.py` seed 13: docs, mutate, expand 1500 inputs each, 0 differences
- Orientation (interleaved ABBA, 10 rounds): `gsoc_2018 --decode` 1102.0 → 903.4 ms, 1.220× by median, 1.284× by minimum, 1.204× by CPU, cv 11.4% / 9.5% (not a capture)
- Killing metric: none yet; promotion needs a cv-gated capture on a quiet host
- **COUNTED 2026-09-23** (cachegrind, `--cache-sim=no`, deterministic; `--decode` of the 3.0 MB
  `gsoc_2018.toon` at `--threads 1`): lever ON **7,356,971,965** I-refs, lever OFF (the `JArr{cnt, +items}`
  / `JObj{+entries}` arms and `w.close` restored VERBATIM from `8d32b6e^`, not reconstructed)
  **8,219,726,013** — **the lever removes 10.5% of the instructions (1.117x)**. Output byte-identical.
- **Reading:** positive and substantial, though more conservative than the earlier orientation of 1.204x.
  Removing the share (so the writer does not take each node apart with `span_fade` while another
  reference is dropped) is worth about a tenth of the decode path.
- **Do-not-retry unless:** (not a loss) — re-capture when the load average is below 1
- Tally: W0/L0/N1 (provisional)
- Agent: Claude (session ef481f9c, 2026-09-22)



### NE-016 — the shortest-digit loop in scalar words when every operand is below 2^64 (EXP-012)   [2026-09-23 | PROVISIONAL]
- Program / def: `port/f64.bend` / `dgw.*` (the loop `dgw.loop`, the word helpers, `dgw.fits`, `dgw.run`), `dg.run.words`, `dg.run.with`. Behind `F.twin.on` (`TOON_SPEC=1` runs `dg.gen.with`); a state with any of r, s, mp, mm at or above 2^64 takes the old path
- Provenance: bend 2.0.16 commit `15ae0c8`, clang 21.1.8, Linux x86_64, AMD EPYC-Milan 8 cores, SHARED HOST AT LOAD 17-20 (other agents' benchmark suite and builds); base = the binary of `4902734` sha256 `ef15400197d1ad85…`, lever binary `beca7cf43e91eedf…`, `--threads 1`
- Representation: three 24-bit words in U32 per value. A first version held two Nat words; the program was right (1000000-number differential SAME) but a closed law over it did not finish in 22 GB: the checker evaluates Nat values of 2^24 scale in unary. With U32 words the seven closed laws check in 17 s at 1.9 GB
- Binding (the weaker kind, as NE-010): seven closed laws `dgw_run_third`, `_asym`, `_half`, `_tie`, `_carry` (operands above 2^32), `_borrow` (a low-word borrow), `_edge64` (s just below 2^64), each `dg.run.words(True, st, …) == dg.run(DgK{st, …})` against the spec loop; three hand mutants (no low-word borrow, a wrong multiply carry, the tie's parity inverted) are each killed, by `_borrow`, `_carry` and `_tie`. The gate is pinned too, condition included: the quantified laws `dg_run_with_gate` (the word loop runs exactly when the switch is open AND `dgw.fits` holds) and `dg_run_words_spec_arm`, and five closed boundary laws `dgw_fits_*` (every operand at 2^64 - 1 fits; each of r, s, mp, mm at 2^64 does not); a mutant dropping `fits` and one moving the s bound to 65 bits are each killed. No quantified `fast == spec` law
- Correctness evidence: `conform.sh` 1071/1071 on c-1t with `TOON_SPEC` unset and set; the seeded 1000000-number differential (original, fast twin, spec twin; seeds 12 and 1212) `{"diffs": 0, "verdict": "SAME"}` twice; an exponent sweep of 24562 doubles (every biased exponent 0-2046, six mantissas, both signs, subnormals included) encoded and decoded byte-identical to the original, exit 0, empty stderr. The loop never forms a value at or above 2^68, so no word exceeds 2^24 (the high word stays below 2^20)
- Orientation (interleaved ABBA, 6 rounds, load 17-20; wall cv 23-53% so wall means nothing here, process CPU time is the steady estimator): CPU `canada --decode` 1.84×, `canada --encode` 2.24×, `citm_catalog --decode` 0.97×, `twitter --encode` 1.01× (neutral where numbers are few); stdout identical in every pair. An earlier single pair on a quieter host: `canada --decode` 5.60 → 2.80 s
- Counted (2026-09-23, cachegrind Ir, the recipe in NE-018; same two binaries, `--threads 1`): `canada --encode` 30,477,033,742 → 12,726,037,467 instructions (**2.39×, 58.2% fewer**), `canada --decode` 34,421,509,459 → 16,671,049,899 (**2.06×, 51.6% fewer**); stdout sha identical per mode. The count agrees with the CPU orientation; the gate is in CPU time, so the entry stays PROVISIONAL
- Killing metric: none yet; promotion to MEASURED needs a cv-gated capture on a quiet host
- **Do-not-retry unless:** (not a loss) — re-capture when the load average is below 1
- Tally: W0/L0/N1 (provisional)
- Agent: Claude (session ef481f9c, 2026-09-23)


### NE-017 — a tabular array whose rows all matched the header in order skips the second lockstep walk (EXP-014)   [2026-09-23 | NEUTRAL, parked]
- Program / def: `port/encode.bend` / a three-state `rows_st.go` replacing `rows_ok.go`, `VTab`/`CTab` carrying `lk`, `row.line.seq`
- Provenance: bend 2.0.16 commit `15ae0c8`, clang 21.1.8, Linux x86_64, AMD EPYC-Milan 8 cores, SHARED HOST AT LOAD 14-16 (a review round and other agents' jobs); base = the EXP-013 binary (tree of `3dac104`, the published EXP-013 commit; the binary was built from its pre-rebase twin, whose `port/` code is byte-identical), `--threads 1`
- Mechanism: the writer's second `row.lock` per row (half of `spin_269`, 8.8% inclusive on `flights_200k --encode`) is skipped when every row was found in header order; about 4% expected
- Correctness: conform c-1t 1076/1076 with `TOON_SPEC` unset and set; `scripts/diff-fuzz.py` seed 1414: docs, mutate, collide 1500 each and scale 20, 0 differences
- Wall (interleaved ABBA, 6 rounds): `flights_200k --encode` 8283.3 → 8473.7 ms, 0.978× by median, 1.011× by minimum, 0.992× by CPU, cv 44.5% / 29.6%; `citm_catalog --encode` 1.002× / 1.004× / 1.004× (cv 35-88%). The expected 4% is far inside this noise: the gate is not shown
- Counted (2026-09-23, cachegrind Ir, the recipe in NE-018): `flights_200k --encode` 39,443,902,183 → 38,269,102,200 instructions, **2.98% fewer**, stdout sha identical. The card's gate was ≥ 3% of CPU: the instruction count alone does not meet it, so the load-independent evidence confirms NEUTRAL rather than rescuing it
- Disposition: not merged; the code is parked as a git stash in the author's scratch clone
- **Do-not-retry unless:** a quiet-host cv-gated CPU capture is wanted to test whether memory effects the count cannot see add the missing margin (unlikely: the count says the whole lever is about 3%), OR it is combined with another lever on `row.lock` whose own count clears a new card's gate
- Tally: W0/L0/N1 (neutral)
- Agent: Claude (session ef481f9c, 2026-09-23)


### NE-018 — the encoder's edge-White_Space test reads the last character without reversing the string (EXP-013)   [2026-09-23 | PROVISIONAL]
- Program / def: `port/text.bend` / `ends_ws`, `ends_ws.go`, `has_edge_ws`. Not behind the switch: the same verdict by construction (the head of the reverse is the last character)
- Provenance: bend 2.0.16 commit `15ae0c8`, clang 21.1.8, Linux x86_64, AMD EPYC-Milan 8 cores, SHARED HOST AT LOAD 8-9 (a review round running); base = the binary of `722991e`, `--threads 1`
- Binding (the weaker kind): six closed laws `ends_ws_*` (the empty text, one space, a leading space only, a trailing space, a trailing U+3000, an inner space) against `head_is_ws(String.reverse(s))`; a mutant that never sees a trailing space is killed by `ends_ws_one_space`
- Correctness evidence: conform c-1t 1076/1076; `scripts/diff-fuzz.py` seed 1313: docs and mutate 1500 each, 0 differences
- Orientation (interleaved ABBA, 8 rounds): `gsoc_2018 --encode` 816.0 → 700.5 ms, 1.165× by median, 1.163× by minimum, 1.144× by CPU, cv 16.5% / 19.3%; `jobs --encode` 0.99-1.02×, `citm_catalog --encode` 1.01-1.27× (cv 21-84%): the gain appears where string values are long, as NE-014's retry predicate said
- Counted (2026-09-23, load-independent): `gsoc_2018 --encode` at `--threads 1`, 7,325,873,961 → 6,368,568,319 instructions, **13.1% fewer (1.150×)**, stdout sha `82d0b726…` identical in both arms; the orientation's 1.14-1.17× agrees. The count is deterministic: a second run of the base gave 7,325,873,881 (80 instructions apart in 7.3 billion). Recipe: `valgrind --tool=cachegrind --cache-sim=no --cachegrind-out-file=<f> <binary> --threads 1 -- <args>`, the `I refs` line on stderr (valgrind 3.26.0, installed on this host this day). A count is not a time: it sees no cache misses, stalls or allocation latency, so it is recorded as COUNTED, never as MEASURED, and a lever that trades instructions for memory traffic reads wrong on it
- Killing metric: none yet; promotion to MEASURED needs a cv-gated capture on a quiet host
- **Do-not-retry unless:** (not a loss) — re-capture when the load average is below 1
- Tally: W0/L0/N1 (provisional)
- Agent: Claude (session ef481f9c, 2026-09-23)

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

### NE-019 — the JSON reader's byte classifier as a lazy chain (EXP-016)   [2026-09-23 | MEASURED_LOSS(no gain), reverted]

- **Lever:** `J.byte.cls` rewritten from a 15-deep strict `Bool.pick` chain into 15 typed helpers, each
  matching a `Bool` parameter and recursing only on `False`, so only the arm taken is ever built.
- **Why it looked promising:** `spin_6` (the emitted strict Bool-select: it evaluates both arms and
  `term_sink`s the loser) was the **hottest single symbol** of `--encode` on a 3.2 MB string-heavy
  document — 8.14% of samples, 79,183,977 calls. 63% of them came from one caller, `spin_443`, which is
  `byte.cls`, called once per input byte (3,327,831 = exactly `WL_FID_JSON_STEP`) and making 15 selects each.
  `NE-INH-9` ("generic `Bool.pick` in hot code") pointed the same way, with retry guidance "inspect and
  compare typed helpers".
- **Measured, load-independent (call counts are exact at any load):** the lever did what it was designed
  to do. `spin_6` 79,183,977 → **29,266,512 (−63%)**, exactly `spin_443`'s contribution; `term_triv`
  133,975,580 → 84,058,115 (−37%); `term_tag` 256,313,662 → 206,396,197 (−19%).
- **Measured, wall/CPU (interleaved ABBA, 12 pairs, min and median of child CPU time, host load ~6):**
  baseline min 0.828 s median 0.853 s (cv 3.6%); lever min 0.807 s median 0.848 s (cv 3.2%).
  **Ratio 0.975 by min, 0.995 by median.** The precommitted gate was ≥ 10%. **MISSED.**
- **Outcome:** removing 49.9 million Bool-selects and 50 million `term_triv` calls — 63% of the hottest
  symbol in the profile — moved CPU time by about 2%. Those operations are far cheaper per call than
  their rank in the profile suggests, so on this runtime **a gprof symbol's share is not a budget you can
  spend**. This is the useful result: it retires "attack the top symbol" as a strategy for this port and
  redirects the effort to the memory traffic (`heap_alloc` did not move AT ALL — the untaken `Nat` arms
  were never heap-allocated, which also falsified the second half of the card's own hypothesis).
- **Correctness:** output byte-identical to the oracle on the 3.2 MB document; the `byte_cls_*` laws
  passed unchanged across the rewrite, which is what they were written for.
- **Cross-checked with instruction counts (2026-09-23, valgrind 3.26 cachegrind, `--cache-sim=no`), and
  this REFINES the conclusion above:** baseline **7,325,874,144** I-refs, lever **7,222,208,788** —
  **ratio 0.986, i.e. 1.4% fewer instructions**, against a measured CPU ratio of 0.975–0.995. The two
  agree. Run-to-run variation was 440 instructions in 7.3e9 (6e-8), so the count is deterministic.

  The reconciliation matters more than the lever. `spin_6` is a THREE-INSTRUCTION function (a compare,
  a move, a drop). 79.2M calls of it is about 240M instructions — **3.3% of the 7.3e9 total**, not the
  8.14% gprof attributed to it. Removing 63% of those calls removes about 2% of the instructions, which
  is exactly what both cachegrind and the CPU measurement report.

  So the sharper statement is: **gprof's %time column overstates tiny leaf functions** — its sampling
  resolution and its own `mcount` overhead land on the leaf — while an instruction count does not. "The
  hottest symbol was not worth attacking" is true; "profiles lie" is too coarse. A CALL count and a
  `%time` share are both poor proxies for work here; an instruction count is a good one, and it would
  have failed this lever before it was written.
- **Kept anyway:** the `byte_cls_*` closed laws pinning the classifier's table (commit `053554b`). `byte.cls` had no
  law of any kind before this experiment; a wrong entry would have been caught only by whichever captured
  case happened to contain that byte.
- **Artifact:** the lever is `git stash` entry "EXP-016 lever: byte.cls as a lazy chain" and a copy in the
  session scratch; nothing was deleted.
- **Do-not-retry unless:** the runtime's strict Bool-select becomes expensive (a Bend release that boxes
  or refcounts select arms — re-read the emitted `spin_6` first: today it is `if (c) {sink(a); return b}`,
  two moves and a drop), OR a profile shows `spin_6` above 25% of samples rather than 8%, OR the same
  rewrite is wanted for READABILITY rather than speed, in which case it must be argued on those terms and
  not on this evidence.

### NE-020 — the number pre-pass's split threshold (EXP-017)   [2026-09-23 | NEUTRAL, reverted]

- **Lever:** the literal `64n` in `E.par.cut`, which decides while a chain keeps forking, raised to `2048n`
  (and, as a second point on the curve, `256n`).
- **Why it looked promising:** the peer session's gprof of `--encode` on `flights_200k.json` at one thread
  put `spin_164` at **6.6% self time over only 28,670 calls**, all under `WL_FID_ENCODE_PRE`, with
  `spin_418`/`spin_420` (~2%) beside it — the split machinery, not the rendering. Each split costs three
  traversals of the left half (`par.take`'s accumulator and its `rev_items`, then `par.cat`'s
  `rev_items(rev_items(a, JNil{}), b)`), and 64 gives about 3000 leaves on a 200k-item chain where a pool
  of at most 128 threads can use dozens. The arithmetic for a ~40% cut in copying was sound.
- **Measured** (interleaved, both orders, 6 rounds per arm, child CPU time, `--encode flights_200k.json`
  at `--threads 1`):

  | threshold | min | median | cv | ratio (min) |
  |---|---|---|---|---|
  | 64 (current) | 5.299 s | 5.489 s | 2.3% | 1.000 |
  | 256 | 5.302 s | 5.414 s | 3.1% | 1.001 |
  | 2048 | 5.241 s | 5.394 s | 5.0% | 0.989 |

  At `--threads 8`, 2048 against 64 was 0.979 by min and 1.025 by median — inside the noise in both
  directions. The precommitted gate was ≥ 8% at one thread. **MISSED; there is no effect to gate.**
- **Outcome:** changing the split granularity by a factor of 32 moves CPU time by at most 1.1%. The
  copying the splits do is real and the count of it falls as designed, but it is not where the time goes.
- **A correction on the record:** an earlier two-arm run of this same comparison reported 2048 as **7%
  SLOWER** (ratio 1.072 by min). That run's baseline cv was 10.1% and it was wrong. It was not acted on;
  the three-arm run above, with cv 2.3–5.0%, replaced it. A two-arm capture on a loaded host can invent a
  7% effect in either direction, which is the whole reason this repository gates on cv.
- **This is the SECOND independent confirmation of NE-019's finding**, from a different def, a different
  input and a different profile: on this runtime **a symbol's share of a gprof profile is not a budget you
  can spend**. NE-019 removed 63% of the hottest symbol for ~2%; NE-020 removed most of the split work for
  ~1%. Both times the arithmetic was right and the conclusion was wrong. Profile-guided lever choice needs
  a measured A/B before the work, not after.
- **Bearing on the untried option:** the peer's alternative was to have `pre` return each half reversed so
  `par.cat` becomes one `rev_items` instead of two — i.e. remove two of the three traversals per split.
  NE-020 says the whole of that cost is worth about 1%, so that lever cannot pay for its contract change
  and the law it would need. Recommend NOT building it.
- **Do-not-retry unless:** a profile shows `WL_FID_ENCODE_PRE`'s split machinery above 20% of self time
  rather than 6.6%, OR the chain representation stops being a cons list (an array or rope would change
  what a split costs), OR a >= 64-thread run is the target, where leaf count rather than copying bounds
  the pool.

### NE-027 — path expansion's pass-through rebuild (EXP-020)   [2026-09-23 | NEUTRAL, not merged]

- **Lever:** `D.x.norm`'s two arms that reconstruct what they destructure — `case XLeaf{v}: XLeaf{v}` and
  `case XBNil{}: XBNil{}` — replaced by a single trailing `case other: other`, which returns the term
  unchanged and allocates nothing. The other four `XV` constructors kept their explicit arms.
- **Why it looked promising:** `--expand-paths safe` is the port's most expensive path per byte in the
  e2e reference run (**479.6 ms/MB** against plain `--decode` at 340.4). Isolated on
  `citm_catalog.fold.toon` (650 KB), expansion adds **605,259,269 instructions (+29.1%)** over plain
  decode, and of the expansion run `term_drop` is 29.4%, `rfc_wrap` 18.1%, `span_fade` 6.1% — **53.6% is
  allocate-and-drop traffic** while the expansion's own logic is 2.7%. Rebuilding a node per scalar
  looked like an obvious source of it.
- **Counted** (cachegrind, `--cache-sim=no`, deterministic):
  current **2,682,287,539** I-refs, lever **2,679,346,560** — **2,940,979 fewer, 0.11%**.
  Gate was >= 5%. **MISSED by a factor of 45.** Output byte-identical to the current port AND to the
  oracle (sha256 `dab1596b…`).
- **Outcome:** the pass-through rebuild is very nearly free. Either the compiler already recognises
  `case C{x}: C{x}` and elides the reconstruction, or `XLeaf`/`XBNil` are far rarer in the tree than a
  per-scalar count suggests. Either way the hypothesis that "every scalar costs an `rfc_wrap` and a
  `term_drop` for nothing" is false. `port/` was never modified: the lever was built and counted in a
  scratch tree, so there is nothing to revert.
- **THE PATTERN ACROSS NE-019, NE-020 AND NE-027.** Three levers, three defs, three inputs, three
  precommitted gates, three misses — 2%, 1%, 0.11%. All three made an *operation* cheaper: a select, a
  split, a reconstruction. Over the same hours the peer session's two levers, which remove a whole *traversal*
  of the data (one drops a decoded text that encode builds and throws away; the other stops the chunk
  join copying the newest chunk twice), counted **18.3%** and **11.6%** and together **1.386x** on the
  same input — their cards and ledger entries land with their push. The rule this yields for the next card: **eliminate a pass over the data, not an
  operation within one.** A lever whose description contains the word "cheaper" is suspect; one whose
  description contains "no longer builds" or "one copy instead of three" is worth the effort.
- **Do-not-retry unless:** a cachegrind run shows `x.norm` itself (`WL_FID_DECODE_X_NORM`, today 2.1% of
  the expand run) above 10%, OR the expansion tree stops being rebuilt wholesale — the 605M that
  expansion adds is worth attacking, but by not building the intermediate `XV` tree at all, which is a
  different and much larger lever than this one.
### NE-021 — one walk answers both "a character forces quotes" and "the last character is White_Space" (EXP-015)   [2026-09-23 | NEUTRAL, parked]
- Program / def: `port/encode.bend` / `quote.scan(s, delim)` = `ends_ws(s) or has_bad(s, delim)` in one loop, used by `needs_quote`
- Provenance: bend 2.0.16 commit `15ae0c8`, clang 21.1.8, Linux x86_64, AMD EPYC-Milan 8 cores, shared host; base = the EXP-013 binary (tree of `3dac104`, the published EXP-013 commit; the binary was built from its pre-rebase twin, whose `port/` code is byte-identical), `--threads 1`
- Correctness: conform c-1t 1076/1076
- Wall (24-round ABBA at load 14-16): `gsoc_2018 --encode` 1.029× by CPU median, 1.083× by minimum, cv 50-99%: the gate (≥ 4% of CPU) is not shown
- Counted (cachegrind Ir, the recipe in NE-018): `gsoc_2018 --encode` 6,368,568,319 → 6,308,782,023 instructions, **0.94% fewer**, stdout sha identical. After EXP-013 the second walk left is cheap: the whole lever is under 1% of the work, a quarter of its gate
- Disposition: not merged; the code stays a git stash in the author's scratch clone
- **Do-not-retry unless:** the string representation stops being a cons list of characters (a walk then costs differently), OR a profile by instruction count puts `has_bad` plus `ends_ws` above 8% of the encoder's instructions
- Tally: W0/L0/N1 (neutral)
- Agent: Claude (session ef481f9c, 2026-09-23)

### NE-022 — encoding without --stats validates UTF-8 without building the decoded text (EXP-018)   [2026-09-23 | COUNTED_WIN, kept]
- Program / def: `port/text.bend` / the `Decoding` state's `keep` flag, `utf8.push`, `utf8.init.verdict`; `port/cli.bend` / `utf8.start.keep`, `o.reads_text`, `convert`. Not behind the switch: the verdict never reads the text, the same by construction
- Provenance: bend 2.0.16 commit `15ae0c8`, clang 21.1.8, Linux x86_64, AMD EPYC-Milan 8 cores, shared host; base = the same tree without the lever (the four rebased commits of session ef481f9c on `d851844`), `--threads 1`
- Counted (cachegrind Ir, the recipe in NE-018): `gsoc_2018 --encode` 6,368,568,839 → 5,200,268,903 instructions, **18.3% fewer (1.225×)**, stdout sha `82d0b726…` identical; the gate was 8%
- Binding: eight closed laws `utf8_verdict_*` (the empty input and ASCII accepted with NO text, a two- and a four-byte scalar, a surrogate, an overlong form, a cut-short sequence, a stray continuation byte) and three through the whole pure core (`encode_non_ascii_without_stats`, `encode_stats_reads_the_text`, `encode_invalid_utf8_refused`, bytes from the pinned original). Three hand mutants are each killed in a reduced proof of these laws: the text never kept (`encode_stats_reads_the_text`), the text always pushed (`utf8_verdict_ascii_keeps_no_text`), `--stats` forgotten in `o.reads_text` (`encode_stats_reads_the_text`)
- Correctness evidence: conform c-1t 1076/1076 with `TOON_SPEC` unset and set; `scripts/diff-fuzz.py` seed 1818: mutate, docs and argv 1500 inputs each, 0 differences
- Killing metric: none; promotion to MEASURED needs a cv-gated CPU capture on a quiet host
- **Do-not-retry unless:** (a win, kept) — revert only if the CPU capture shows no gain, which would mean an instruction count is not a proxy for this runtime's allocation cost
- Tally: W1/L0/N0 (counted)
- Agent: Claude (session ef481f9c, 2026-09-23)

### NE-023 — the input bytes are not copied: one 16 MiB first read, and the newest chunk kept as the tail (EXP-019)   [2026-09-23 | COUNTED_WIN, kept]
- Program / def: `port/main.bend` / `chunks.all`, `read.opened` (the first read's size), `read.loop`, `read.failed`
- Provenance: as NE-022; base = the EXP-018 binary
- Counted (cachegrind Ir): `gsoc_2018 --encode` 5,200,268,903 → 4,594,481,010, **11.6% fewer (1.132×)**, stdout identical; the gate was 5%. With EXP-018, against the tree without either: `gsoc_2018 --encode` 6,368,568,839 → 4,594,481,010 (**1.386×**), `flights_200k --encode` 39,443,902,183 → 34,186,157,328 (1.154×); `gsoc_2018.toon --decode` (this lever only: decode needs the text) 7,323,845,399 → 6,785,805,168 (1.079×); stdout identical in every pair
- Binding: none by law (the shell is outside the proof book). Evidence: conform c-1t 1076/1076 with `TOON_SPEC` unset and set; `scripts/stdio-probe.py` 27 rows, the same 13 SAME, 13 KNOWN and 1 FIXED as the base binary, 0 NEW; `diff-fuzz.py scale` seed 1919, 20 inputs, 0 differences; a 19 MB input (over the first read, so two chunk shapes) as a path and through a pipe, stdout sha identical to the original's. Round 18 (R18-1, R18-D2): of that evidence only the one-off 19 MB pipe run reaches a second chunk: the corpus (regular-file stdin, ONE read), the probe's 27 rows and scale seed 1919 (largest input 54,890 bytes) do not, and the reviewer's mutants K1 (only the newest chunk kept) and K2 (older chunks joined in reverse) pass all three. Since round 18 two `scripts/stdio-probe.py` rows pipe a 404,126-byte document fed in 32 KiB writes (encode and decode), and both mutants fail them (NEW rows, verdict FAIL)
- Killing metric: none; promotion to MEASURED needs a cv-gated CPU capture on a quiet host
- **Do-not-retry unless:** (a win, kept) — revisit the 16 MiB first read if a lane is found where allocating it costs more than the copy it saves (the JavaScript build zero-fills it once per run)
- Tally: W1/L0/N0 (counted)
- Agent: Claude (session ef481f9c, 2026-09-23)

### NE-024 — the TOON text is built forward from reversed lines: one copy per output character instead of three (EXP-021)   [2026-09-23 | COUNTED_WIN, kept]
- Program / def: `port/encode.bend` / the six line builders (`line.prim`, `line.hdr`, `line.inline`, `line.key`, `lines.obj0`, `row.line`) return their line reversed; `encode.go` returns the lines last first; `port/cli.bend` / `lines.join`, `toon.text` build the text forward
- Provenance: as NE-022; base = the EXP-019 binary
- Counted (cachegrind Ir): `gsoc_2018 --encode` 4,594,481,010 → 4,075,715,463, **11.3% fewer (1.127×)**; `flights_200k --encode` 34,186,157,328 → 33,403,287,482 (2.3% fewer: its lines are short rows of numbers); stdout identical in both; the gate was 8% on gsoc
- Binding: five closed goldens through the whole pure core (`encode_text_zero_lines`, `_one_line`, `_three_depths`, `_tabular_rows`, `_list_items`; bytes from the pinned original), the first laws on the board's "output framing" row. Three hand mutants each killed in a reduced proof: the lines joined in the wrong order (`_three_depths`), one builder left unreversed (`_three_depths`), the LF put on the wrong side of the line (`_one_line`)
- Correctness evidence: conform c-1t 1076/1076 with `TOON_SPEC` unset and set; `scripts/diff-fuzz.py` seed 2121: docs, mutate and argv 1500 inputs each, collide 1200, 0 differences
- Killing metric: none; promotion to MEASURED needs a cv-gated CPU capture on a quiet host
- **Do-not-retry unless:** (a win, kept) — revert only if the CPU capture shows no gain
- Tally: W1/L0/N0 (counted)
- Agent: Claude (session ef481f9c, 2026-09-23)

### NE-025 — trim_end returns a text whose last character is not White_Space as it is (EXP-022, EXP-010 retried and counted)   [2026-09-23 | COUNTED_WIN, kept]
- Program / def: `port/text.bend` / `trim_end.pick`, `trim_end` (`ends_ws` moved above it); not behind the switch: both branches compute the same text
- Provenance: as NE-022; base = the EXP-021 binary. NE-014 (the same lever, NEUTRAL by wall at load 10-13) stands as written: this entry is a new card with a COUNTED gate, not a re-reading of that one
- Counted (cachegrind Ir): `gsoc_2018.toon --decode` 6,785,804,709 → 5,937,718,735, **12.5% fewer (1.143×)**, stdout identical; the gate was 10%. Why the wall missed it in NE-014: a 12% change is inside a cv of 8-21%, which is what a load-independent instrument is for
- Mechanism: the allocation profile put 11,150,316 of 44,389,777 wraps (25.1%) in the two reversals under the trim; `ends_ws` only matches its argument, so the compiler borrows the text (no keep) and a text with nothing to drop is returned untouched
- Binding: six closed laws `trim_end_*` against the old expression written out (nothing trailing, one space, an inner space kept with a trailing space and tab, a trailing U+3000, only spaces, empty) and `decode_values_trimmed_at_the_end` through the whole pure core (bytes from the pinned original). Three hand mutants each killed in a reduced proof: the untouched text dropped (`_nothing_trailing`), the trim skipped (`_one_space`), `ends_ws` testing the first character (`_one_space`)
- Correctness evidence: conform c-1t 1076/1076 with `TOON_SPEC` unset and set; `scripts/diff-fuzz.py` seed 2222: docs, mutate and expand 1500 inputs each, 0 differences
- Killing metric: none; promotion to MEASURED needs a cv-gated CPU capture on a quiet host
- **Do-not-retry unless:** (a win, kept) — revert only if the CPU capture shows no gain
- Tally: W1/L0/N0 (counted)
- Agent: Claude (session ef481f9c, 2026-09-23)

### NE-028 — a string literal is found and unescaped in one walk (EXP-024)   [2026-09-23 | COUNTED_WIN, kept]
- Program / def: `port/decode.bend` / `lit`, `lit.go`, `lit.close`, `lit.plain`, `lit.esc`, `lit.esc.ch` (the old `lit.q` removed: `lit` was its only caller); keys and headers keep `quote.close` + `unesc`
- Provenance: as NE-022; base = the EXP-022 binary
- Counted (cachegrind Ir): `gsoc_2018.toon --decode` 5,937,718,735 → 5,449,278,370, **8.2% fewer (1.090×)**, stdout identical; the gate was 8% and is met by 0.2 points, which is stated rather than rounded
- Binding: seven closed goldens `decode_literal_*` through the whole pure core (bytes from the pinned original): the failure order (unterminated before a bad escape, trailing characters before a bad escape), a bad escape alone, all five escapes, a backslash before the last quote, the empty literal, quoted tabular cells. Three hand mutants each killed in a reduced proof: the bad escape reported before trailing characters (`_trailing_before_bad_escape`), a backslash that does not take the next character (`_bad_escape`), `\t` not unescaped (`_five_escapes`)
- Correctness evidence: conform c-1t 1076/1076 with `TOON_SPEC` unset and set; `scripts/diff-fuzz.py` seed 2424: docs, mutate and expand 1500 inputs each, 0 differences
- Killing metric: none; promotion to MEASURED needs a cv-gated CPU capture on a quiet host
- **Do-not-retry unless:** (a win, kept) — revert only if the CPU capture shows no gain
- Tally: W1/L0/N0 (counted)
- Agent: Claude (session ef481f9c, 2026-09-23)

### NE-029 — the TOON scanner walks the decoded text still reversed: each line built forward in one copy (EXP-025)   [2026-09-23 | COUNTED_WIN, kept]
- Program / def: `port/decode.bend` / `seg.go`, `seg.cls`, `seg.bom`, `seg.bom.drop`, `scan.lead`, `scan.segs`, `scan.rev`, `decode.rev`, `decode_expanded.rev`; the per-character state `SS` and its loop (`scan.go`, `scan.ch`, `scan.tr`, `scan.end`, `cr.drop`) replaced by the per-line state `SL`; `scan(text)` kept for the laws that name it; `port/cli.bend` / `dec.run.rev`, `dec.text.rev` (decode with `--stats` keeps the forward path)
- Provenance: as NE-022; base = the EXP-024 binary
- Counted (cachegrind Ir): `gsoc_2018.toon --decode` 5,449,278,370 → 4,126,574,186, **24.3% fewer (1.321×)**; `flights_200k.toon --decode` 30,209,984,532 → 28,390,287,257 (6.0% fewer); `canada.toon --decode` 14,608,072,725 → 13,549,853,165 (7.2% fewer); stdout identical to the original's on all three; the gate was 8% on gsoc
- Binding: fourteen closed goldens `decode_scan_*` through the whole pure core (bytes from the pinned original): CRLF endings, CR CR, a CR inside a line, blank and whitespace-only lines, a TAB in the indent alone and after spaces, two strict failures (the first line wins), the TAB under `--no-strict`, a byte order mark with and without `--stats`, the empty input, no final LF, and a bare list marker before CR CR and before CRLF. Four hand mutants in a reduced proof: every CR dropped (killed by `_lone_cr_inside_kept`), the TAB flag lost (`_tab_in_indent_strict`), the byte order mark kept (`_byte_order_mark`), both CRs of CR CR dropped: this last one SURVIVED the first twelve laws, because the value trim removes a kept trailing CR; the two bare-marker laws were written for it (S2.113's one observable exception) and it is killed by `_bare_dash_cr_cr`
- Correctness evidence: conform c-1t 1076/1076 with `TOON_SPEC` unset and set; `scripts/diff-fuzz.py` seed 2525: docs, mutate, expand and argv 1500 inputs each, 0 differences; `scripts/stdio-probe.py` the same 13 SAME, 13 KNOWN and 1 FIXED rows, 0 NEW
- Killing metric: none; promotion to MEASURED needs a cv-gated CPU capture on a quiet host
- **Do-not-retry unless:** (a win, kept) — revert only if the CPU capture shows no gain
- Tally: W1/L0/N0 (counted)
- Agent: Claude (session ef481f9c, 2026-09-23)

### NE-030 — the encoder's numeric-like test borrows the string and stops at the lexer's sink (EXP-026)   [2026-09-23 | COUNTED_WIN, kept]
- Program / def: `port/f64.bend` / `is_like`, `like.go`, `like.ph`, `like.first`; the lexer-based test kept as `is_like.lex` (the specification the laws compare with); the readers' lexer (`F.literal`) unchanged
- Provenance: as NE-022; base = the EXP-025 binary
- Mechanism: a keep audit of a probe (one def per check of `needs_quote`) showed `is_like` the only check that takes its argument (`ctr_take`), so `needs_quote` kept every string value and the writer took a shared text apart: 2,795,574 `span_fade` calls under `PUT_PRIM` on `gsoc_2018 --encode`, one per character. The lexer also walked every string to its end, a `Lex` record per character, after its sink
- Counted (cachegrind Ir): `gsoc_2018 --encode` 4,072,387,460 → 3,520,909,254, **13.5% fewer (1.157×)**, stdout identical; the gate was 5%. `flights_200k --encode` 33,393,424,502 → 33,392,224,475 and `canada --encode` 11,032,322,041 → 11,032,093,099 (both under 0.01%: few string values)
- Binding: seventeen closed laws `is_like_*` (`is_like(x) == is_like.lex(x)` on every accepting phase, every refusal path, the sink, a long text) and `encode_numeric_like_items` through the whole pure core (bytes from the pinned original). Four hand mutants in a reduced proof: any prefix accepted (killed by `is_like_dot_end`), the '-' not skipped (`is_like_signed_exponent`), the exponent's '-' refused (`is_like_signed_exponent`), a '0' after the point refused: this one SURVIVED the first fifteen laws (none put a '0' after the point) and is killed by `is_like_zero_fraction`, written for it
- Correction (round 19, R19-1): "every refusal path" above was not true. No law put a '0' after a fraction digit (the lexer's phase 4 on class 0), and a mutant that sent that arm to the sink left `"1.50"` unquoted, which the original then reads back as the number 1.5; it passed the corpus, the proof, the docs and mutate lenses. Only the one-off length-6 sweep reached the arm, and no gate re-runs it. Three `is_like_zero_in_phase_4_*` laws and `encode_fraction_trailing_zeros_quoted` now pin it, and each kills that mutant
- Correctness evidence: the pinned original and the port on EVERY string up to length 6 over `0 5 . e E + - a` (299593 strings, one per lexer class), as array items and as object values through `--encode`: stdout sha identical (`339d0ed0…`, `23979ab5…`); conform c-1t 1076/1076 with `TOON_SPEC` unset and set; `scripts/diff-fuzz.py` seed 2626: docs, mutate and collide 1500 inputs each, numbers 6 documents (1200 number literals), 0 differences
- Killing metric: none; promotion to MEASURED needs a cv-gated CPU capture on a quiet host
- **Do-not-retry unless:** (a win, kept) — revert only if the CPU capture shows no gain
- Tally: W1/L0/N0 (counted)
- Agent: Claude (session ef481f9c, 2026-09-23)

### NE-031 — the JSON reader takes a plain ASCII byte inside a string without the per-byte dispatch (EXP-027)   [2026-09-23 | COUNTED_WIN, kept]
- Program / def: `port/json.bend` / `run` matches the byte and the state together: a string state goes to `step.in_str` (its fast arm, behind `F.twin.on`, when the byte is `plain`; else step's own path for a string state), any other state to `step`, unchanged; `plain`
- Provenance: as NE-022; base = the EXP-026 binary
- Counted (cachegrind Ir), three shapes, stdout identical in every cell: (1) the carded wrapper `step.fast` around `step`: `gsoc_2018 --encode` 3,520,909,254 → 3,101,385,374 (-11.9%) but `canada --encode` 11,032,092,303 → 11,160,383,918 (**+1.2%**, the byte test paid outside strings) and `flights_200k` -0.4%; (2) the mode tested first through a borrowed `in_str`: gsoc 3,144,543,145 (-10.7%), canada 11,128,872,394 (**+0.9%**: `+st` kept the state every byte), flights -0.5%; (3) KEPT, the arm inside `run`'s match: gsoc **3,010,314,170 (-14.5%, 1.170×)**, `flights_200k` 32,764,310,271 (-1.9%), `canada` 11,014,963,054 (-0.16%); the gate was 5% on gsoc
- Binding: the quantified law `step_in_str_slow_is_step` (for every string state and byte, the arm with the fast path closed IS `step`: the kill-switch and every refused byte take it); ten closed laws on `plain`'s edges on both sides (31/32, 33/34/35, 91/92/93, 127/128); three closed laws `step_in_str_fast_*` (the fast arm equals `step` on a plain byte in a value, a space, DEL in a key with a character pending); `encode_plain_string_bytes` through the whole pure core (bytes from the pinned original). Hand mutants in a reduced proof: the range widened to 128 (killed by `plain_128_refused`), the guard off (`plain_32_accepted`), the quote admitted (`plain_34_refused`), the column not moved (`step_in_str_fast_value`), the slow arm losing the line (`step_in_str_slow_is_step`)
- Correctness evidence: conform c-1t 1076/1076 with `TOON_SPEC` unset and set; `scripts/diff-fuzz.py` seed 2729: docs, mutate and collide 1500 inputs each, and mutate seed 2730 with `TOON_SPEC=1`, 0 differences
- Killing metric: none; promotion to MEASURED needs a cv-gated CPU capture on a quiet host
- **Do-not-retry unless:** (a win, kept) — revert only if the CPU capture shows no gain; a future fast arm in `run` is judged on a string-poor input too (canada), because a per-byte test costs every byte
- Tally: W1/L0/N0 (counted)
- Agent: Claude (session ef481f9c, 2026-09-23)

### NE-033 — a decimal fast path in the number READER (EXP-028)   [2026-09-23 | MEASURED_LOSS(no gain), not merged]

- **Lever:** `int_text.ok` refuses any token with a fraction (the law `int_text_fraction_refused` pins
  it), so `65.613471` takes the full correctly rounded big-natural route while `65613471` takes a fast
  path. The lever admitted a non-integer whose WHOLE significand fits the 14-digit bound and computed it
  as `nat_of(ints ++ fracs) / 10^len(fracs)` through `div_p10` — EXP-003's short division, not `div` —
  which is Clinger's condition: a significand below 10^14 < 2^53 divided once, correctly rounded.
- **Correctness:** **conform 1076/1076 PASS on c-1t**, every `encnum_*`, `decnum_*` and extreme case
  included. The arithmetic was right.
- **Counted:** canada `11,014,957,856 → 11,088,288,430` (**−0.7%, slightly WORSE**); the short-decimal
  twin `6,922,497,466 → 6,862,359,683` (**+0.9%**). Gate was ≥ 25%. **MISSED.** Not merged; `port/` was
  never modified.
- **Why, and this corrects EXP-028's card.** The card blamed the reader AND the printer and I built the
  reader. The reader was never the cost. Forcing EXP-012's scalar digit loop off separates them exactly:

  | twin | EXP-012 ON | EXP-012 OFF | what it means |
  |---|---|---|---|
  | short integers | 1,890,963,922 | 1,890,963,917 | **identical** — integers never reach the shortest-digit generator at all |
  | short decimals | 6,922,497,426 | 13,448,869,374 | the generator IS the decimal cost, and EXP-012 already halves it |

  An integer is printed by EXP-001's path straight from its digits. A decimal must have its shortest
  round-trip digits GENERATED, and that is the whole of the 17,015 → 62,294 instructions-per-number gap.
  The reader contributes about 1%.
- **What this bounds.** The port's worst document is worst because of shortest-digit generation for
  non-integers, a cost EXP-012 has already halved. Closing the rest is not a fast path or a guard: it
  needs a DIFFERENT ALGORITHM — a Ryu- or Grisu-class fixed-point method with precomputed powers,
  replacing Burger and Dybvig's big-natural iteration. That is a large piece of work with real rounding
  risk, and it is the only remaining lever of size on this path. Naming it is the useful outcome here.
- **Method note, my fourth miss of the same kind.** NE-019 (2%), NE-020 (1%), NE-027 (0.11%) and now
  NE-033 (−0.7%) were all chosen from a correct measurement and a wrong attribution. The measurement
  that would have refused this lever before it was written took four minutes: force the OTHER half of
  the suspected pair off and see which one moves. **Bisect the suspected cost between two halves before
  building either.**
- **Do-not-retry unless:** the printer's decimal path stops being the dominant cost of a number-heavy
  document (re-measure with the EXP-012 on/off split above first), OR the reader's big-natural route is
  shown by that same split to exceed 10% of a number-heavy run.
### NE-032 — a small JSON object detects repeated keys by walking its own chain, not the key table (EXP-029)   [2026-09-23 | COUNTED_WIN, kept]
- Program / def: `port/json.bend` / `obj.member.at`, `obj.member.chain`, `obj.member.small`, `obj.member.grown`, `obj.shorter`, `kt.of_chain`, `push`'s object arm; `port/text.bend` / `kt.is_empty`. Not behind the switch: the chain and the key set answer the same membership question (the chain holds each key once); a mutant that leaves the object small for ever, or never builds the set, is only slower, so no law can see it and none is asked to
- Provenance: as NE-022; base = the binary of `3a6f7f6` (the EXP-027 code)
- Counted (cachegrind Ir): `flights_200k --encode` 32,764,310,573 → 28,679,609,596, **12.5% fewer (1.142×)**; `gsoc_2018 --encode` 3,010,314,246 → 2,913,445,152 (3.2% fewer); `canada --encode` 11,014,963,424 → 11,015,737,694 (+0.007%, inside the card's 0.5% allowance); stdout identical in all three; the gate was 5% on flights
- NE-004's protection kept: one object of 16000 keys encodes in 0.06 s (0.07 s before), output identical to the original's
- Binding: seven closed goldens `encode_repeated_key_*` through the whole pure core (bytes from the pinned original): a repeat in objects of 2 and 7 members, at the 8th member (the one that builds the set), after it, of an early key and of the OLDEST key after it, and in nested small objects. Hand mutants in a reduced proof: a repeat in a small object taken as a new key (killed by `_two_members_repeat_last`), the set built with the newest key only (killed by `_nine_members_repeat_after_the_switch`)
- Correctness evidence: conform c-1t 1076/1076 with `TOON_SPEC` unset and set; `scripts/diff-fuzz.py` seed 2929: collide, docs and mutate 1500 inputs each, scale seed 2930 20 inputs, 0 differences
- Killing metric: none; promotion to MEASURED needs a cv-gated CPU capture on a quiet host
- **Do-not-retry unless:** (a win, kept) — revert only if the CPU capture shows no gain; the threshold 8 is not tuned (a count at 4 and 16 would say whether it matters)
- Tally: W1/L0/N0 (counted)
- Agent: Claude (session ef481f9c, 2026-09-23)

### NE-034 — encoding reads the input bytes once: the UTF-8 gate and the JSON reader step together (EXP-030)   [2026-09-23 | NEUTRAL, parked]
- Program / def: `port/json.bend` / a fused `run.u` (the arms of `run`, each with `T.utf8.step` beside it), `read.u`; `port/cli.bend` / `convert` deciding the mode first, `convert.enc` (the UTF-8 verdict first, S9.10)
- Provenance: as NE-022; base = the binary of the EXP-029 code (`d5483e5`), `--threads 1`
- Mechanism: the second walk and the `span_fade` per input byte (9,863,892 on `flights_200k --encode`, the frame-pointer tally) disappear when one walk owns the list
- Counted (cachegrind Ir), stdout identical in all six cells: `flights_200k --encode` 28,679,609,592 → 28,340,783,667, **1.18% fewer** (the gate was 2%); `gsoc_2018 --encode` 2,913,444,694 → 2,813,786,898 (3.42% fewer); `canada --encode` 11,015,737,330 → 10,930,199,395 (0.78% fewer); and the decode cells the card did not gate: `gsoc_2018 --decode` 4,125,565,216 → 3,318,525,950 (19.56% fewer), `flights_200k --decode` 28,366,283,493 → 27,259,753,148 (3.90% fewer), `canada --decode` 13,543,063,702 → 12,830,013,857 (5.27% fewer)
- Binding (in the parked code): the quantified law `run_u_is_both` (`run.u(bytes, u, st, spec) == RU{utf8.bytes(bytes, u), run(bytes, st, spec)}` for every input and both states, by induction on the bytes with a split on the reader's mode), five closed `run_pure` goldens from the pinned original (an invalid byte after a JSON error, a truncated sequence after one, an invalid byte in a key under `--stats`, `--stats` after a mark, two marks); in a reduced proof two hand mutants were killed (the decoder step dropped from one arm: `run_u_is_both`; the reader's error preferred to the UTF-8 verdict: `encode_invalid_utf8_after_json_error`)
- Correctness evidence: conform c-1t 1076/1076 with `TOON_SPEC` unset and set
- Disposition: not merged; the code is parked on a branch of the author's scratch clone. The decode gains were not what the card gated, so they are not claimed here: the decode half alone (decode mode stops handing the bytes to the encode arm) is carded as EXP-031 with a gate on inputs this count did not touch
- **Do-not-retry unless:** EXP-031 is kept and a new count of the fused encode walk ON TOP of it clears a new card's gate, or another lever on the input path (reading, BOM, `run`) is combined with it
- Tally: W0/L0/N1 (neutral)
- Agent: Claude (session ef481f9c, 2026-09-23)
