# INVALID timing run — correctness only

**Do not quote any speed number from this directory.** The timings are void. The
correctness column is sound and is the only thing here worth citing.

## What is sound

**204 of 204 cells byte-identical across all three arms** — stdout sha256, stderr
sha256 and exit code — for the port built from `78a2588` (EXP-013/018/019/021/022/024,
518 laws, four lanes PASS 1076/1076) against `toon_rust` `694d73b` at `opt-level=z`
and `opt-level=3`. That column does not depend on host load.

## Why the timings are void

The run reported the port at **5.81×** the pinned original by median geomean against
**7.98×** in the reference run of the same day — an apparent 1.37× improvement, which
would have agreed neatly with the counted instruction reductions of the six levers
(18.3%, 11.6%, 12.5%, and more). It is an artifact.

Summed median wall time over the 204 cells present in both runs:

| arm | reference run | this run | change |
|---|---|---|---|
| `bend` | 134,000 ms | 143,170 ms | **+6.8%** |
| `rust_z` | 15,523 ms | 22,462 ms | **+44.7%** |
| `rust_o3` | 9,559 ms | 14,095 ms | **+47.4%** |

**Every arm got slower.** The port most of all in absolute terms is not the story —
the oracle arms degraded six times harder, because contention adds a near-constant
cost per process and the shorter arm pays proportionally more of it. The ratio
therefore fell while nothing improved.

The cv distribution says the same thing outright: **28 of 612 arms within cv 5%,
against 393 of 612 in the reference run**; median arm cv 18.8%, p75 63.9%, max 170.9%.
`bench.py` marked **all 204 cells NOISY and 0 MEASURED**, which is the gate working.

## The lesson, since this one was seductive

A noisy run that agrees with a prior expectation is the most dangerous kind of wrong.
Six levers had just landed with counted reductions, so a large ratio improvement was
exactly what a reader (and the author) expected to see. The check that caught it was
not statistical: it was asking **"did the port's own absolute time go down?"** It did
not; it went up 6.8%. Ratios must never be read without their absolute arms.

## What to do instead

Re-run when the host is quiet. The counted evidence for the six levers stands on its
own (`perf/evidence/COUNTED.*.json`) and does not depend on this run.
