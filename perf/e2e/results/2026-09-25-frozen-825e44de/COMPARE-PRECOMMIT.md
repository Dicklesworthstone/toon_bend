# Precommitment: a refined `compare.py` rule, written BEFORE the code exists

`compare.py` returned **INVALID** on this run against the reference run. That verdict is recorded
below and is not being replaced. I believe the guard has a blind spot, and I am going to refine it —
but refining a gate immediately after it blocks a result one would like to publish is the
gate-self-weakening shape, and a peer session said so before I wrote a line. So the rule and its
predicted verdicts for three historical comparisons are fixed here first, and the implementation is
judged against these predictions rather than the predictions against the implementation.

## The verdict that stands, quoted

```
EVERY ARM'S OWN ABSOLUTE TIME FIRST — a ratio is meaningless until these are read:
  bend       summed median      103653 ms ->      89314 ms    -13.8%
  rust_o3    summed median        9808 ms ->       9454 ms     -3.6%
  rust_z     summed median       15779 ms ->      15282 ms     -3.2%
  old run: 66 of 204 cells MEASURED, 349 of 612 arms within cv 5%
  new run: 77 of 204 cells MEASURED, 400 of 612 arms within cv 5%
INVALID: every arm moved in the same DIRECTION, by differing amounts.
```

## Why I think it is a blind spot, not a wrong result

The guard's own stated reason is that **a shorter arm pays proportionally more of a fixed contention
cost**. That predicts the SHORT arms move most when contention changes. Here the **longest** arm moved
most (−13.8% against −3.2% and −3.6%), which is the opposite signature.

And the guard treats all three arms symmetrically when they are not. `rust_z` (`821287ea…`) and
`rust_o3` (`b3683f39…`) are **byte-identical binaries in both runs** — they are controls, and they
measure the host difference directly. Only `bend` changed: `caac3708…` in the reference run against
`825e44de…` here, a tree that added EXP-029, round 19's repairs and EXP-031.

## The refined rule, fixed now

Let **C** = the largest absolute movement among arms whose binary sha256 is IDENTICAL in both runs
(the controls). Let **T** = an arm's absolute movement when its sha256 DIFFERS (a test arm).

1. **No controls at all** (every arm's binary changed) → keep the present symmetric rule: all arms the
   same direction with a spread over 10% is INVALID. Nothing can bound the host without a control.
2. **C > 10%** → **INVALID**: the controls themselves moved more than a tenth, so the two runs were
   taken on materially different hosts and no arm's movement can be attributed.
3. **A test arm moves in the SAME direction as the controls and T < 3 × C** → **INVALID** for that
   arm: its movement is not separable from host drift.
4. **Otherwise** → **VALID**, and the report MUST print C as the noise floor carried by every ratio,
   MUST name both binary hashes of each changed arm, and MUST keep printing the absolute arms first.

## Predicted verdicts, fixed before implementation

| comparison | controls | C | test arm T | predicted verdict |
|---|---|---|---|---|
| the phantom 1.37× (`2026-09-23-six-levers-78a2588` vs `2026-09-23-final-9ae2f2e`): bend +6.8%, rust_z +44.7%, rust_o3 +47.4% | byte-identical | **47.4%** | 6.8%, same direction | **INVALID**, twice over — by rule 2 (C > 10%) and by rule 3 (6.8% < 142%) |
| the published 1.27× improvement (`2026-09-23-wall2-2c33e64` vs `2026-09-23-final-9ae2f2e`): bend −22.6%, oracles +1.7% and +2.6% | byte-identical | 2.6% | 22.6%, **opposite** direction | **VALID**, noise floor 2.6% — rule 3 does not apply to an opposite-direction move. This reproduces the verdict under which it was published |
| **this run** vs the reference: bend −13.8%, rust_o3 −3.6%, rust_z −3.2% | byte-identical | **3.6%** | 13.8%, same direction | **VALID**, noise floor 3.6% — and only just: 13.8% against a 3 × 3.6% = 10.8% threshold, a margin of 28% |

**If the implementation disagrees with any row above, the implementation is wrong or the rule is, and
the INVALID verdict stands.** In particular, if the phantom 1.37× comparison does not come back
INVALID, the refinement is abandoned.

## What the refinement deliberately does NOT do

It does not make this run's ratios safe to quote without qualification. Rule 4 requires the noise
floor printed beside them, and this run's floor is **3.6%** — larger than several of the per-scenario
differences one might want to read. The margin over the threshold is 28%, which is not comfortable.
Any figure published from this run says so.

## Verification against the predictions above (run after the code was written)

All three held, and the arm figures reproduced the precommitted table exactly.

| comparison | predicted | actual |
|---|---|---|
| the phantom 1.37× | INVALID by rule 2, C = 47.4% | **INVALID**, "the CONTROLS moved more than 10%", C = 47.4%; arms bend +6.8%, rust_o3 +47.4%, rust_z +44.7% — identical to this directory's sibling `INVALID.md` |
| the published 1.27× | VALID, floor 2.6% | **VALID**, floor 2.6%; arms bend −22.6%, rust_o3 +2.6%, rust_z +1.7% |
| this run | VALID, floor 3.6% | **VALID**, floor 3.6%; arms bend −13.8%, rust_o3 −3.6%, rust_z −3.2% |

So the refinement keeps the case it was built for (a run whose controls moved 45% cannot be read, and
the old rule and the new one both refuse it) while separating a changed arm from controls that did not
change. Had the phantom comparison come back readable, the refinement was to be abandoned.

**One result the precommitment did not anticipate, and it strengthens the reading.** The comparison
yields six estimators — median, min and CPU time, each over all cells and over the 36 cells MEASURED
in both runs — and they agree within 1%: 1.110, 1.110, 1.115, 1.105, 1.111, 1.109. One of them is CPU
time, which contention affects far less than wall clock, so a host artifact would have to forge itself
consistently across three different measurement bases to produce this. The precommitted rule passes
this comparison on the controls argument alone; the estimator agreement is independent corroboration
that was not required in advance and is therefore worth more than if it had been.

**The qualification stands as written:** 1.110× carries a 3.6% host floor, and the margin over the
rule-3 threshold was 28%, which is not comfortable. Both are stated wherever the figure is published.
