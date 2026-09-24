#!/usr/bin/env python3
"""compare: two runs of bench.py, read the way that does not invent a speedup.

    python3 perf/e2e/compare.py <old-results-dir> <new-results-dir> [--ref-arm rust_z]

A ratio moves when EITHER program moves, so a fall in `port / original` is NOT evidence that the port
improved. On 2026-09-23 a run of this suite reported the port at 5.81x against 7.98x in the reference run
of the same morning — an apparent 1.37x win that arrived right after six levers landed and agreed with
their instruction counts. Every arm had got SLOWER (port +6.8%, oracle +44.7%, -O3 +47.4%): contention
adds a near-constant cost per process and the shorter arm pays proportionally more of it, so the ratio
fell while nothing improved. The gate had already said so (0 MEASURED, 28 of 612 arms inside cv 5%) and
the reading that caught it was the port's own ABSOLUTE time.

So this script refuses to print a ratio comparison until it has printed, for every arm, whether that
arm's own absolute time moved — and it says INVALID when the arms moved together, which is the signature
of a host difference rather than a code difference.

Exit: 0 the comparison is readable, 1 the runs are not comparable (arms moved together, or too few
MEASURED cells), 2 usage.
"""
import json
import math
import os
import statistics as st
import sys


def load(d):
    p = os.path.join(d, "cells.jsonl")
    if not os.path.exists(p):
        sys.exit(f"compare: {p} does not exist")
    with open(p, encoding="utf-8") as fh:
        return {(c["file"], c["scenario"]): c for c in (json.loads(l) for l in fh)}


def gm(xs):
    xs = [x for x in xs if x and x > 0]
    return math.exp(sum(math.log(x) for x in xs) / len(xs)) if xs else 0.0


def main(argv):
    if len(argv) < 3:
        sys.exit(__doc__)
    old, new = load(argv[1]), load(argv[2])
    ref = "rust_z"
    if "--ref-arm" in argv:
        ref = argv[argv.index("--ref-arm") + 1]
    common = sorted(set(old) & set(new))
    if not common:
        sys.exit("compare: the two runs share no cell")
    arms = sorted(set(new[common[0]]["arms"]) & set(old[common[0]]["arms"]))

    print(f"cells in both runs: {len(common)}\n")
    print("EVERY ARM'S OWN ABSOLUTE TIME FIRST — a ratio is meaningless until these are read:")
    moved = {}
    for a in arms:
        to = sum(old[k]["arms"][a]["median_ms"] for k in common)
        tn = sum(new[k]["arms"][a]["median_ms"] for k in common)
        if to <= 0:                      # an arm that reported no time at all is not comparable
            sys.exit(f"compare: arm {a} has no positive median in the old run")
        moved[a] = tn / to
        print(f"  {a:10s} summed median  {to:10.0f} ms -> {tn:10.0f} ms   {(tn/to - 1)*100:+6.1f}%")

    # The signature of a host difference is NOT "every arm moved a lot". It is "every arm moved the same
    # WAY, and by different amounts" — contention costs each process about the same absolute time, so the
    # shorter arm's percentage is much larger. Tested against the known-bad pair (bend +6.8%, oracle
    # +44.7%, -O3 +47.4%): an earlier version of this check required every arm to move more than 10% and
    # let that case through, because the port's own 6.8% was under the bar.
    vs = list(moved.values())
    same_way = (all(v > 1.0 for v in vs) or all(v < 1.0 for v in vs)) and \
               max(abs(v - 1) for v in vs) > 0.10
    quality = []
    for d, label in ((old, "old"), (new, "new")):
        cv = [v["cv_pct"] for k in common for v in d[k]["arms"].values()]
        ok = sum(1 for x in cv if x <= 5)
        meas = sum(1 for k in common if d[k]["status"] == "MEASURED")
        quality.append((label, ok, len(cv), meas))
        print(f"\n  {label} run: {meas} of {len(common)} cells MEASURED, {ok} of {len(cv)} arms within cv 5%")

    if same_way:
        print("\nINVALID: every arm moved in the same DIRECTION, by differing amounts.")
        print("  That is a host difference, not a code difference. The shorter arm pays proportionally")
        print("  more of a fixed contention cost, so the RATIO will have moved even though nothing")
        print("  improved. Do not read the ratios below as a result; re-run on a quiet host.")
        return 1

    both_measured = [k for k in common if old[k]["status"] == "MEASURED" and new[k]["status"] == "MEASURED"]
    print(f"\ncells MEASURED in BOTH runs: {len(both_measured)} of {len(common)}")
    if len(both_measured) < 10:
        print("  fewer than 10 — not enough to compare. The ratios below are orientation only.")

    for key, label in (("median_ms", "median"), ("min_ms", "min"), ("cpu_ms_median", "CPU")):
        for scope, cells in (("all cells", common), ("MEASURED in both", both_measured)):
            if not cells:
                continue
            o = gm([old[k]["arms"]["bend"][key] / old[k]["arms"][ref][key] for k in cells
                    if old[k]["arms"][ref].get(key)])
            n = gm([new[k]["arms"]["bend"][key] / new[k]["arms"][ref][key] for k in cells
                    if new[k]["arms"][ref].get(key)])
            if o and n:
                print(f"  {label:7s} {scope:18s} bend/{ref}: {o:5.2f}x -> {n:5.2f}x   "
                      f"change {o/n:.3f}x")
    return 0 if len(both_measured) >= 10 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
