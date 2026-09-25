# Where these scripts come from

The harness was copied from the porting-to-bend2 skill on 2026-09-20 in commit `c4a5235`. The intent was
"update by re-copying, never by editing here"; that was NOT kept. The table below is computed, not remembered:
`for f in scripts/*; do cmp -s "$f" ~/.claude/skills/porting-to-bend2/scripts/$(basename $f); done` names TEN
copied scripts that differ from the skill's copies, and `git log --follow -- scripts/<f>` names every commit
that edited each one (the newest first, `c4a5235` being the copy itself and so omitted). A re-copy from the
skill must carry all of these over, or the skill must take them.

Round 13 (R13-2) found the previous version of this table wrong in three ways at once: it named seven scripts
where ten differ, it said "each edited once" where two had been edited twice, and it omitted three scripts that
the very commit it sat in had edited — a re-copy guided by it would have silently dropped this session's
missing-oracle guards.

| script | commits (newest first) | why |
|---|---|---|
| `case_manifest.py` | `1f184e8` | the floor refuses a missing original and exits 2 instead of running 1065 cases to report INCONCLUSIVE (round 12, R12-6) |
| `converge.sh` | `b2dcb18` | accepts this port's OQ ids (`OQ-A1`, `OQ-P3-1`, `OQ-C2 / OQ-E1`) |
| `harness-selftest.sh` | `6d41d1c`, `1a5da71` | the twelfth mutation (a stale count against `claims-audit.py`); copies `cases/`, `.beads/`, `bin/` and the root documents and links `oracle/` (this port keeps stdin files outside `goldens/`) |
| `incumbent-bench.sh` | `1f184e8`, `77a63d9` | neither arm is timed when its executable is missing (round 12, R12-6); the CPU model comes from `/proc/cpuinfo` (`platform.processor()` is empty on Linux) |
| `interp-lane.sh` | `1230a0d` | captures stderr through a PIPE, not a file (`-o /dev/stderr` overwrote it) |
| `js-lane.py` | `4c3cccc` | documents that a directory as stdin stops Python before bun starts |
| `pin-check.sh` | `77a63d9` | an absent oracle is a RED row, not a traceback |
| `port-doctor.sh` | `1f184e8` | an `--original` that is not an executable file exits 2 before the lane runs (round 12, R12-6) |
| `port-lint.py` | `3751630` | laws name defs through any capitalized module alias |
| `port.sh` | `1f184e8` | the `claims` command and the `report` row lint the ONE list of claim-bearing documents, not `docs/*.md perf/*.md README.md` (round 12, R12-9) |

Written for this port, not copied: `diff-fuzz.py`, `stdio-probe.py`, `hand-mutants.py`, `board-refresh.py`, `clean-build-check.sh`, `claims-audit.py`, `review_report.py` (round 23's one reader of a review report, imported by both `converge.sh` and `claims-audit.py`), `.hst-decoy.py` (round 24's M23 and control C1: plants a decoy findings table in a copied report; named with a leading dot because it is not a gate, and `harness-selftest.sh` is its only caller). The two newest were missing from this line, which is the drift round 13's R13-2 found in it before: a list of what a re-copy must carry over is worth only as much as its last update.
