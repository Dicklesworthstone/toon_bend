# Partial capture — STOPPED, not a complete run

**Do not quote these numbers as a suite result.** This directory holds 85 of the
suite's 224 cells. The run was killed at 2026-09-22 ~20:55 by the host's
memory reaper, not by any failure of the benchmark or of either program.

- **Arms:** `rust_z` and `rust_o3` = the pinned original (`toon 0.2.4`, oracle
  `694d73b`) at opt-level `z` and `3`; `bend` = the port built from a clean
  `git archive` export of commit `4902734` (Bend 2.0.16, checkout `15ae0c8`).
- **Covered:** 13 of 32 documents — github_events, apache_builds, numbers,
  flights_2k, unemployment, instruments, npm_cli_lock, flights_5k, random,
  update_center, twitterescaped, twitter, us_10m. The larger tiers were not
  reached, so the geomeans below are **biased toward small documents**.
- **Correctness:** 85 / 85 cells byte-identical across all three arms
  (stdout sha256, stderr sha256 and exit code). This column does not depend on
  load and is the one result here that stands on its own.
- **Timing status:** every cell is NOISY under the repository's 5% cv gate.
  Host load was 15 and wall-clock cv per cell ran 19–95%. Under the project's
  own definitions these are **not MEASURED claims**; they are orientation.

Why the numbers are still worth keeping: the three estimators agree.

| estimator | bend / rust_z | bend / rust_o3 |
|---|---|---|
| median of 30 | 7.29× | 10.50× |
| min of 30 | 7.77× | 11.08× |
| median CPU time | 7.33× | 10.85× |

Wall-clock cv was 19–95% but *process CPU* cv on the same samples was 5–9%,
and min-of-30 wall agrees with median CPU to within ~6%. Contention inflates
wall time and leaves CPU time alone, so the convergence of the three is
evidence the ratio is roughly right even though no single cell passes the gate.

**Cause of the kill:** an unrelated `bun /tmp/bend/bend2/main.ts PROOF.bend`
belonging to another agent reached 22.4 GB RSS of the host's 30 GB while this
run was in progress. Nothing was wrong with the suite.

**To finish it:** re-run the same command when the host has memory, and replace
this directory's numbers with the complete ones.

```
python3 perf/e2e/bench.py run \
  --out perf/e2e/results/<date>-final \
  --arm rust_z=rust:<oracle z> --arm rust_o3=rust:<oracle o3> \
  --arm bend=bend:<port built from the commit under test> --max-cv 5
```
