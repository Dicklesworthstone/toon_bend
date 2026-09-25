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
    old_dir, new_dir = argv[1], argv[2]
    old, new = load(old_dir), load(new_dir)
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
    # 2026-09-25: the rule above treats every arm alike, and they are not alike. An arm whose BINARY is
    # byte-identical in both runs is a CONTROL: it cannot have changed, so its movement measures the host
    # difference directly. An arm whose binary differs is the thing under test. Judging a changed arm
    # against its controls separates the two, where the symmetric rule cannot.
    #   C = the largest absolute movement among controls; T = a changed arm's movement.
    #   no controls          -> the symmetric rule above stands (nothing bounds the host)
    #   C > 10%              -> INVALID: the hosts differ too much for any attribution
    #   same direction, T < 3C -> INVALID for that arm: not separable from host drift
    #   otherwise            -> readable, with C printed as the noise floor on every ratio
    # The rule and its verdicts for three historical comparisons were fixed in writing BEFORE this code
    # existed (perf/e2e/results/2026-09-25-frozen-825e44de/COMPARE-PRECOMMIT.md), because refining a gate
    # that has just blocked a result is the gate-self-weakening shape. The phantom 1.37x of 2026-09-23
    # (bend +6.8%, rust_z +44.7%, rust_o3 +47.4%, controls byte-identical) must stay INVALID: it fails
    # rule 2 on C = 47.4% and rule 3 on 6.8% < 142%.
    shas = {}
    for d, label in ((old_dir, "old"), (new_dir, "new")):
        f = os.path.join(d, "fingerprint.json")
        if os.path.exists(f):
            with open(f, encoding="utf-8") as fh:
                try:
                    shas[label] = {a["name"]: a.get("sha256") for a in (json.load(fh).get("arms") or [])}
                except (ValueError, KeyError, TypeError):
                    shas[label] = {}
        else:
            shas[label] = {}
    controls = [a for a in arms if shas["old"].get(a) and shas["old"].get(a) == shas["new"].get(a)]
    changed = [a for a in arms if shas["old"].get(a) and shas["new"].get(a) and shas["old"][a] != shas["new"][a]]
    floor = max((abs(moved[a] - 1) for a in controls), default=None)
    if controls:
        print("\n  CONTROLS (binary byte-identical in both runs, so their movement IS the host difference):")
        for a in controls:
            print(f"    {a:10s} {(moved[a]-1)*100:+6.1f}%   sha {shas['old'][a][:12]}")
        for a in changed:
            print(f"  CHANGED  {a:10s} {(moved[a]-1)*100:+6.1f}%   {shas['old'][a][:12]} -> {shas['new'][a][:12]}")
        print(f"  host noise floor C = {floor*100:.1f}%  (every ratio below carries at least this)")
        if floor > 0.10:
            print("\nINVALID: the CONTROLS moved more than 10%. The two runs were taken on materially")
            print("  different hosts, so no arm's movement can be attributed to code. Re-run.")
            return 1
        verdicts = []
        for a in changed:
            same_dir = (moved[a] - 1) * (max((moved[c] - 1 for c in controls), key=abs)) > 0
            if same_dir and abs(moved[a] - 1) < 3 * floor:
                verdicts.append(a)
        if verdicts:
            print("\nINVALID: " + ", ".join(verdicts) + " moved the same way as the controls and by less")
            print("  than three times their drift, so that movement is not separable from the host.")
            return 1
        same_way = False   # the controls bound the host; the changed arm is judged against them
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
