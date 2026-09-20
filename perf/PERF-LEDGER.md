# Performance Ledger — toon_bend

<!-- Copy to perf/PERF-LEDGER.md when the project reaches rigor tier T2
     (references/NEGATIVE-EVIDENCE-AND-LEDGERS.md). Only WIN rows live here.
     A qualified local result awaiting target validation is provisional;
     a refused capture is NO_EVIDENCE. Neither is admitted here. -->

Row admission (all mandatory):

1. Name the comparison: for scaling, runtime arms of the same binary;
   for a source optimization, two identified artifacts at the same runtime
   settings. `bench-speedup` measures the former; the latter needs a
   harness interleaving both retained artifacts. A C twin, if cited, is
   labelled as the sequential reference.
2. Interleaved in both orders with an A/A pair; medians; **cv ≤ 5% or the
   row is refused** (`scripts/bench-speedup.sh --aa --max-cv 5 --strict`).
3. Identical stdout bytes across every sample/arm (`same_output: true`),
   with controlled inputs and a separately stated numerical contract.
4. `bend PROOF.bend` → "All terms check." with relevant law coverage,
   unsafe declarations and trusted dependencies reviewed; the keep-audit
   delta attached. An unchanged unsafe count alone is insufficient.
5. Route attested: a device row used `--gpu on` or a positive span, names the device and
   includes dispatch evidence; a CPU row ran with `--gpu off`.
6. Fingerprint: `bend --version`, commit, clang, `uname -sm`, CPU model,
   core count, GPU, thread count, span, lanes per bang.
7. Evidence dir with the JSON line, the emitted C, keep-audit before and
   after, and the fingerprint.
8. A meaningful improvement that meets the stated success criterion;
   low dispersion and matching output alone do not make a gain. Review
   paired samples, drift and uncertainty before assigning WIN.

CV/A/A thresholds screen captures; they do not prove statistical
significance. Review the retained paired samples and proof assumptions
(including 2.0.16 template warnings). `ledger-row.sh` formats a provisional
row and cannot verify these admission requirements or promote it to WIN.

---

## Rows

| date | program | lever | baseline arm | baseline ms | ours ms | ratio | cv% | cksum | laws | keep Δ | fingerprint | evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2026-09-20 | `port/main.bend` `-e perf/inputs/wide_object_16000.json` | EXP-004 hashed key set in the JSON reader's object frame (16000 keys in one object) | commit `3751630` binary, t=1, ONE run under a 60 s budget | 20.5 s | 66.2 ms | 310× | port arm 2.6 (n=10); baseline single run, no cv | stdout sha `a304069f0b104f84` equal to the original's in every sample | `All terms check.` 336 laws (unsafe 0 = 0 `@unsafe` + 0 template instances); no twin: the carrier is part of the spec twins, so the evidence is the goldens + `kt_member`, `kt_not_member`, `key_hash_fnv1a`, `expand_order_first_insertion` + `scripts/diff-fuzz.py` lenses docs/expand/scale, 0 differences | whole program call sites, `3751630`→`1230a0d`: keep 255→268, take 248→298, seal 1687→1770, free 54→56 | AMD EPYC-Milan, 8 cores, Linux 7.0.0-30 x86_64 (shared host) · bend 2.0.16 @15ae0c8 · clang 21.1.8 · `--threads 1` · no bang | `perf/evidence/EXP-004.wide-object-vs-original.json`, `perf/evidence/EXP-004.baseline-wide-object.json` |
| 2026-09-20 | `port/main.bend` `-e perf/inputs/wide_rows_1200.json` | EXP-004 lockstep row test + key map for tabular rows (20 rows x 1200 fields) | commit `3751630` binary, t=1, ONE run under a 60 s budget | 6.5 s | 74.6 ms | 87× | port arm 1.1 (n=10); baseline single run, no cv | stdout sha `ebb3350da2edfdd1` equal to the original's in every sample | `All terms check.` 336 laws (unsafe 0 = 0 `@unsafe` + 0 template instances); no twin: the carrier is part of the spec twins, so the evidence is the goldens + `kt_member`, `kt_not_member`, `key_hash_fnv1a`, `expand_order_first_insertion` + `scripts/diff-fuzz.py` lenses docs/expand/scale, 0 differences | whole program call sites, `3751630`→`1230a0d`: keep 255→268, take 248→298, seal 1687→1770, free 54→56 | AMD EPYC-Milan, 8 cores, Linux 7.0.0-30 x86_64 (shared host) · bend 2.0.16 @15ae0c8 · clang 21.1.8 · `--threads 1` · no bang | `perf/evidence/EXP-004.wide-rows-vs-original.json`, `perf/evidence/EXP-004.baseline-wide-rows.json` |
| 2026-09-20 | `port/main.bend` `-d --expand-paths safe perf/inputs/expand_lines_40000.toon` | EXP-004 expansion on the ordered-list + hashed-map carrier (40000 dotted lines) | commit `3751630` binary, t=1, ONE run under a 60 s budget | > 60 s (budget; TIMEOUT) | 772.3 ms | > 78× (baseline cut at its budget) | port arm 3.1 (n=10); baseline single run, no cv | stdout sha `2d3cd6711abc94fa` equal to the original's in every sample | `All terms check.` 336 laws (unsafe 0 = 0 `@unsafe` + 0 template instances); no twin: the carrier is part of the spec twins, so the evidence is the goldens + `kt_member`, `kt_not_member`, `key_hash_fnv1a`, `expand_order_first_insertion` + `scripts/diff-fuzz.py` lenses docs/expand/scale, 0 differences | whole program call sites, `3751630`→`1230a0d`: keep 255→268, take 248→298, seal 1687→1770, free 54→56 | AMD EPYC-Milan, 8 cores, Linux 7.0.0-30 x86_64 (shared host) · bend 2.0.16 @15ae0c8 · clang 21.1.8 · `--threads 1` · no bang | `perf/evidence/EXP-004.expand-vs-original.json`, `perf/evidence/EXP-004.baseline-expand.json` |

Reading these rows: the three EXP-004 rows compare the merged binary with the PREVIOUS PORT binary on inputs where that binary is quadratic; the ratio is an algorithmic one (a single baseline run, stated as such), not a tuned-constant one. Conformance at the ledgered tree `1230a0d`: `scripts/conform.sh` PASS 1053/1053 on c-1t, c-8t and js with `TOON_SPEC` unset and with `TOON_SPEC=1`; regression captures against `3751630` on the four earlier inputs: ratios 0.997 / 0.992 / 0.994 / 1.022 (tabular encode, tabular decode, decimals, strings; all MEASURED, cv ≤ 5%, `perf/evidence/EXP-004.regress-*.json`), so no earlier input moved by more than 2.3%. The fourth EXP-004 input (30000 folded keys) and the three number levers EXP-001..003 are NOT in this table: see `perf/NEGATIVE-EVIDENCE.md` NE-001..NE-004 for why (a refused cv, and twins bound by closed laws only).

## Frozen pins

Hold one row per hardware as the pin (the repo's own gate accepts 1.15× of
its pin on identical hardware). Move a pin only by an explicit, reviewed
ratchet; never because a run beat it once.

| hardware | program | arm | ms | cksum | date | bend |
|---|---|---|---|---|---|---|
