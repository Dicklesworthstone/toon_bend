# ABORTED — not evidence, not citable

This directory holds a **stopped** run. `cells.jsonl` and `samples.jsonl` are real
timings of real work, and they are **not a measurement of anything**. No number in
here may be cited, in this repository or outside it, for any purpose.

## What it was going to be

B1 of the quiet-window batch: the e2e wall suite on the frozen port binary
`sha256 825e44de69c3a4e6c0d442ea`, so a wall figure could be attached to the
`port/` tree that rounds 20–21 are reviewing.

    python3 perf/e2e/bench.py run --out perf/e2e/results/2026-09-24-frozen-c5f3b46 \
      --arm rust_z=rust:.../arms2/z/toon --arm rust_o3=rust:.../arms2/o3/toon \
      --arm bend=bend:.../frozenc5f3b46/toon --max-cv 5

## Why it was stopped, with the numbers that decided it

Stopped at 87 cells, 2026-09-24. The cv gate is `--max-cv 5`:

| | this run (87 cells) | the published run (2026-09-23-wall2) |
|---|---|---|
| cells `MEASURED` | **0** | 66 |
| cells `NOISY` | **87 (all of them)** | 24 |
| arms inside cv 5% | **14 of 261** | 57 of 90 |
| arm cv, median | **10.6%** | 4.6% |
| arm cv, p90 / max | **19.0% / 65.5%** | — |

Not one cell passed. At that rate the suite's remaining ~35 minutes would have
produced an artifact whose every row was `NOISY`.

## The decision, and the thing I got wrong

I started the run on a stated 90-minute quiet window. The premise was wrong, and
a peer corrected it while the run was in flight: the steady load I had budgeted
for (a mutant sweep) had **already finished**, and the load actually present was
a round-21 reviewer doing **native clang builds and multi-job differential
fuzzing** — spiky, not steady. Load read 3.12 and falling when I launched;
5.10 by the time I looked at the cells.

**Spiky co-tenancy is the exact condition that manufactured the phantom 1.37×
improvement** this campaign already retracted (see `INVALID.md` beside the
2026-09-23 run and `perf/e2e/compare.py`, which now refuses a comparison whose
arms all moved the same way by differing amounts). A shorter arm is inflated
proportionally more by contention, so contention does not merely widen the error
bars on a ratio — it *biases* it, and in the flattering direction.

Reading the early cv and stopping is cheaper than reading a finished table and
having to decide whether to trust it. The run was stopped rather than completed
**because a completed contaminated run is a liability, not a datum**: it exists,
it is tabular, and it invites citation.

## What replaces it while the host is busy

Nothing, on the wall-clock axis — and that is the honest answer. The wall
figures in `perf/e2e/README.md` remain the ones from 2026-09-23-wall2, attached
to the binary hash they were taken on, and the frozen tree has **no wall figure
of its own**. It does not need one: `port/` produced a byte-identical binary
across `9c9039e`, `55ec958` and `c5f3b46`, so the published wall numbers already
describe this tree's binary.

Load-immune work (instruction counts under cachegrind, which are deterministic
to ~1e-8 and indifferent to host load) proceeds instead, and is labelled
`counted`, never `measured`.

## Retry predicate

Re-run B1 only when **all** hold:

1. the peer running rounds 20–21 has signalled that round 21 has reported
   (they committed to saying so the moment it does);
2. one-minute load is below 1.5 and the five-minute figure agrees — a falling
   one-minute average over a spiky producer is not a quiet host, which is the
   specific inference that failed here;
3. the first 20 cells show ≥ 60% of arms inside cv 5%. If they do not, stop
   again at 20 cells rather than at 87.

Keep this directory: RULE 1, and it is the record of the judgement.
