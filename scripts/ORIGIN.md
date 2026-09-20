# Where these scripts come from

The harness (everything here except the five files named below) was copied from the porting-to-bend2 skill on 2026-09-20.
The intent was "update by re-copying, never by editing here"; that was NOT kept for seven of them, each edited once in
this repository for a defect met here, so a re-copy must carry these changes over (or the skill must take them):

| script | commit | why |
|---|---|---|
| `converge.sh` | `b2dcb18` | accepts this port's OQ ids (`OQ-A1`, `OQ-P3-1`, `OQ-C2 / OQ-E1`) |
| `port-lint.py` | `3751630` | laws name defs through any capitalized module alias |
| `interp-lane.sh` | `1230a0d` | captures stderr through a PIPE, not a file (`-o /dev/stderr` overwrote it) |
| `js-lane.py` | `4c3cccc` | documents that a directory as stdin stops Python before bun starts |
| `pin-check.sh` | `77a63d9` | an absent oracle is a RED row, not a traceback |
| `incumbent-bench.sh` | `77a63d9` | the CPU model comes from `/proc/cpuinfo` (`platform.processor()` is empty on Linux) |
| `harness-selftest.sh` | `1a5da71` | copies `cases/` and links `oracle/` (this port keeps stdin files outside `goldens/`) |

Written for this port, not copied: `diff-fuzz.py`, `stdio-probe.py`, `hand-mutants.py`, `board-refresh.py`, `clean-build-check.sh`.
