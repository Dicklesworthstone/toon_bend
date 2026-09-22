# perf/e2e — the port against the original on real JSON

An end-to-end benchmark suite: the `toon` COMMAND (process start, reading the file, conversion, writing the output) of the
Bend port against `toon_rust`, on 20 real public JSON documents from 64 KB to 9.9 MB, in 7 scenarios, with every output
compared byte for byte before anything is timed.

```bash
python3 perf/e2e/bench.py fetch                                  # 20 documents, pinned by upstream commit + sha256
python3 perf/e2e/bench.py prepare --reference ./oracle/toon      # the TOON inputs of the decode scenarios
python3 perf/e2e/bench.py run --arm rust_z=rust:./oracle/toon \
    --arm rust_o3=rust:<opt-level=3 build> --arm bend=bend:<dir>/toon          # ~40 min for the full matrix
python3 perf/e2e/bench.py report perf/e2e/results/<run>          # re-render report.md
```

`--files`, `--tiers S,M,L,XL`, `--scenarios`, `--budget`, `--min-runs`/`--max-runs`, `--max-cv` narrow or tune a run
(`bench.py --help`). A `js` arm (the emitted `toon.js` through `scripts/js-lane.py`) is supported but was not part of the runs below.

## The corpus (`corpus.json`)

| tier | documents | what they stress |
|---|---|---|
| S (< 0.25 MB) | github_events, apache_builds, numbers, instruments | API payloads, a flat array of 10001 doubles, deep small objects |
| M (0.5–1.4 MB) | random, update_center, twitterescaped, twitter, mesh, jobs, football, earthquakes, movies | UTF-8 (CJK) and `\u` escapes, wide objects, GeoJSON, uniform tables with nulls and small decimals |
| L (1.7–3.3 MB) | citm_catalog, flights_20k, canada, marine_ik, gsoc_2018 | integer-keyed maps, one big table, 111080 high-precision doubles, 245k mixed numbers, long prose |
| XL (8.6–9.9 MB) | semanticscholar, flights_200k | abstracts and author lists, a 200000-row numeric table |

Sources: `simdjson/simdjson-data` @ `4197c42` (the standard JSON-parser benchmark files) and `vega/vega-datasets` @ `a96a3d7`
(real tabular datasets). None is generated. The documents and their TOON twins live in `perf/e2e/corpus/` (gitignored).

Scenarios: `encode`, `encode_stdin`, `encode_fold` (`--key-folding safe`), `encode_tab` (`--delimiter` TAB), `encode_stats`,
`decode`, `decode_expand` (`--decode --expand-paths safe` of the folded TOON), plus `version` (start-up only).

## Method

- **Correctness before time.** The first run of every cell (untimed) compares stdout, stderr and exit code of every arm with the
  reference arm; a cell reports `SAME`, `DIFF` or `TIMEOUT`. A reference exit other than 0 marks the cell `ERROR PATH`, and it is left
  out of the summary means.
- **Interleaved, shuffled rounds.** Each round runs every arm once, in an order shuffled by a seeded generator, so host drift lands on all
  arms alike. Rounds per cell = 30 s budget / one round's time, clamped to [5, 30]. Timed runs write stdout to `/dev/null`.
- **Numbers per arm:** median, mean, p95 (nearest rank), min, max, cv; CPU (user + sys, from the child's own `wait4` rusage); peak RSS
  (through `/usr/bin/time`: a child spawned from Python inherits Python's high-water mark across `exec`, so its own `ru_maxrss` is
  useless below about 30 MB); input MB/s. **Ratio** = arm median / reference median, with a 95% bootstrap interval (2000 resamples).
- **cv gate 5%**, this repository's gate: a cell with any arm above it is `NOISY`, and its ratio is orientation, not evidence.

## Results (2026-09-22, AMD EPYC-Milan, 8 cores, shared host, 1 thread)

Two full runs of 140 cells each, in `results/`:

| run | arms | outputs identical | MEASURED cells | host load |
|---|---|---|---|---|
| `2026-09-22-full` | `toon_rust` `f955c67` at `opt-level=z` (the then-pinned oracle) and at `opt-level=3`; the port at `866aa8a` | 140/140 | **39** | 1–4 |
| `2026-09-22-repinned` | `toon_rust` `7c1d6e4` (the C-10 fix) at `z` and `3`; the port at `a8efed0` | 140/140, all exit 0 | 1 | 6–7 (other agents' gates) |

The C-10 fix touches neither path's speed: across the 138 cells that both runs converted, the port's ratio moved by a median factor
of 1.003 (90% of cells within ±10%). So the MEASURED cells of the first run are the evidence below, and the second run confirms their
shape on the fixed binaries, and adds the two semanticscholar decodes, which the old binaries could not run.

### Summary (second run, geometric mean of the port's ratio against `toon_rust` at `opt-level=z`; orientation)

| scenario | port / rust `z` | range | rust `opt-level=3` / rust `z` |
|---|---|---|---|
| encode | 13.5× | 5.0× – 97.7× | 0.8× |
| encode_fold / encode_tab / encode_stdin | 14.0× / 13.6× / 13.3× | 4.9× – 99.3× | 0.8× |
| encode_stats | 10.1× | 4.0× – 58.1× | 0.6× (the original's token estimate is where `opt-level=3` pays most) |
| decode | 6.6× | 2.1× – 33.3× | 0.8× |
| decode_expand | 11.9× | 4.9× – 52.2× | 0.6× |

Against the strongest build (`opt-level=3`) every port ratio is about 1.1–2.2× larger again: `z` is the original's size-tuned release
profile, and `opt-level=3` finishes the same work in 0.45–0.92 of its time.

### MEASURED cells (first run; port time / rust `z` time, 95% CI; last two columns: port / rust `opt-level=3`, rust `3` / rust `z`)

| document | scenario | rust `z` | rust `3` | port | port / rust `z` | port / rust `3` | rust `3` / `z` |
|---|---|---|---|---|---|---|---|
| flights_20k | decode | 144.3 ms | 117.7 ms | 298 ms | 2.06× [2.03, 2.11] | 2.5× | 0.82× |
| football | decode | 54.6 ms | 46.0 ms | 131 ms | 2.40× [2.35, 2.43] | 2.8× | 0.84× |
| earthquakes | decode | 83.7 ms | 69.0 ms | 569 ms | 6.80× [6.74, 6.88] | 8.2× | 0.83× |
| flights_20k | encode_fold | 73.5 ms | 56.0 ms | 506 ms | 6.89× [6.79, 6.96] | 9.0× | 0.76× |
| apache_builds | encode_tab | 3.7 ms | 3.0 ms | 28 ms | 7.49× [7.34, 7.68] | 9.1× | 0.82× |
| jobs | decode | 54.3 ms | 45.3 ms | 420 ms | 7.74× [7.68, 7.80] | 9.3× | 0.83× |
| semanticscholar | encode | 267.0 ms | 214.9 ms | 2169 ms | 8.12× [7.95, 8.31] | 10.1× | 0.81× |
| earthquakes | encode | 63.3 ms | 51.1 ms | 565 ms | 8.92× [8.69, 9.09] | 11.1× | 0.81× |
| flights_200k | decode | 951.2 ms | 789.3 ms | 8653 ms | 9.10× [8.87, 9.23] | 11.0× | 0.83× |
| marine_ik | decode | 268.3 ms | 226.9 ms | 2732 ms | 10.18× [10.01, 10.36] | 12.0× | 0.85× |
| twitter | decode_expand | 16.5 ms | 10.6 ms | 181 ms | 10.96× [10.76, 11.13] | 17.0× | 0.64× |
| football | encode_stdin | 22.2 ms | 18.0 ms | 293 ms | 13.16× [12.85, 13.33] | 16.3× | 0.81× |
| mesh | decode | 68.8 ms | 56.3 ms | 1130 ms | 16.43× [16.15, 16.70] | 20.1× | 0.82× |
| jobs | encode | 24.1 ms | 19.7 ms | 558 ms | 23.20× [22.73, 23.71] | 28.3× | 0.82× |
| canada | decode | 202.5 ms | 151.6 ms | 5314 ms | 26.25× [25.84, 27.33] | 35.1× | 0.75× |
| flights_200k | encode | 331.0 ms | 275.3 ms | 9189 ms | 27.76× [26.83, 28.29] | 33.4× | 0.83× |
| canada | encode | 87.6 ms | 69.9 ms | 4837 ms | 55.22× [50.59, 55.92] | 69.2× | 0.80× |
| mesh | encode_fold | 18.0 ms | 14.7 ms | 1010 ms | 55.98× [55.38, 56.63] | 69.0× | 0.81× |

(The full list of 39, with every other scenario, is in `results/2026-09-22-full/report.md`; its two semanticscholar decode rows
are ERROR PATH cells of the old binaries and are not listed here.)

### What the numbers say

1. **Text and structure: 2–14× the original.** Documents made of strings, keys and small integers (twitter, semanticscholar,
   earthquakes, football, flights_20k, gsoc) encode at 2.2–4.5 MB/s in the port against 19–64 MB/s in the original. Decoding a
   uniform table is the port's best case (flights_20k 2.1×, football 2.4×).
2. **Non-integer numbers: 20–100× the original.** canada (111080 doubles) 55×, mesh 56×, numbers 93–98× (its cells are NOISY: the original's arm is under 4 ms), flights_200k 28×, marine_ik 20×.
   This is DISC-013: Bend has no `f64`, so every non-integer goes through the software binary64 over big naturals.
3. **Memory: 50–125 bytes per input byte** at peak (semanticscholar: 420 MB for 8.6 MB) against 5–95 for the original (59 MB),
   consistent with DISC-011.
4. **Start-up is not the cost:** `--version` runs in 0.9 ms on every arm.
5. **The original's build profile matters:** `opt-level=3` takes 0.45–0.92 of the pinned `z` build's time, so any ratio against `z`
   flatters the port by 1.1–2.2× (the same fact as `perf/NEGATIVE-EVIDENCE.md` NE-006, now on 140 cells).

### A bug found on the way (C-10), fixed in both repositories

`toon --encode semanticscholar.json` succeeded and `toon --decode` of its own output failed: `Expected 6 inline array items, but got 25`.
A quoted abstract holding a citation marker, `"… [6] J. D. Achenbach …: …"`, was read as an array header, because the decoder took the
first `[` of a line even inside the value after the key's colon. `a: "x[1]: y"` even decoded SILENTLY to `{"a: \"x":["y\""]}`, exit 0.
The port reproduced it (candidate C-10, S10.83). On the owner's order ("fix ANY bug found in either toon_rust or toon_bend
immediately") it is fixed upstream (`toon_rust` `7c1d6e4`, with regression tests) and the port is re-pinned to that commit, with 7
goldens re-captured and `port/decode.bend` fixed (S2.130). All four lanes pass 1071/1071 after the fix; `docs/PORT_STATE.md` has the lines.

## Where the port's time goes (`perf`, 2026-09-22)

`results/2026-09-22-full/profiles/`: flat profiles of 14 cells (`<cell>.txt`) and caller attributions of three (`<cell>.callers.txt`,
from the emitted C rebuilt with frame pointers); `perf/evidence/EXP-006.wall-profile.txt` is the one for `perf/inputs/doubles_20000.json`.
BendRT's own symbols dominate: `term_drop` frees a dead term tree node by node; `span_fade` takes apart a SHARED (`+`) value by bumping
each child's reference count with an atomic add and then dropping it; `rfc_wrap` allocates a reference cell when a value is copied;
`spin_N` are native loops (`spin_7`/`spin_8` = `String.reverse`, `spin_9` = reverse-append); `io_cstr` converts output text.

| rank | where (port def → runtime) | share of wall | input | evidence |
|---|---|---|---|---|
| 1 | `BN.cmp` → `span_fade` + `term_drop` (the digit generator's compare consumes shared copies of both operands) | 51.6% inclusive; 45% on canada | doubles_20000, canada encode | `EXP-006.wall-profile.txt`, `canada_encode.callers.txt` |
| 2 | `term_drop` + `span_fade` overall (freeing, shared matches) | 40–75% self | every cell | `profiles/*.txt` |
| 3 | `decode.header` → `term_drop`/`span_fade` (every line is offered to the header parser, which copies and drops the whole line even when it holds no `[`) | ~18% | gsoc decode | `gsoc_decode.callers.txt` |
| 4 | `run` teardown (`CLI_CONVERT` dropping the input and the value at exit) | 10–15% | twitter encode, gsoc decode | `twitter_encode.callers.txt` |
| 5 | `String.reverse` / reverse-append (`spin_7`–`spin_9`: the accumulate-reversed pattern) and `rfc_wrap` | 8–15% and 4–15% | string-heavy cells | `profiles/*.txt` |
| 6 | `BN.sub` | 10% | doubles_20000 | `EXP-006.wall-profile.txt` |
| 7 | `io_cstr` (output) | 3–8% | string-heavy cells | `profiles/*.txt` |

### Opportunity matrix (hand-off to extreme-software-optimization; score = impact × confidence / effort, act on ≥ 2.0)

| lever | impact | confidence | effort | score | status |
|---|---|---|---|---|---|
| `BN.cmp` without taking shared operands apart (compare in place, or compare limb counts first) | 5 | 4 | 2 | 10.0 | bead `toon_bend-2t0`; needs its card, law and one-lever capture |
| EXP-006, a quotient estimate per digit (fewer `cmp`/`sub` rounds) | 4 | 3 | 3 | 4.0 | card PROPOSED; its wall-profile precondition is now MET |
| `decode.header`: look for a `[` before offering a line to the header parser | 3 | 4 | 1 | 12.0 | bead `toon_bend-z3z` (the behaviour must stay S2.130's) |
| skip the teardown of the input and the value at exit | 2 | 2 | 3 | 1.3 | below the bar: needs a runtime-level exit that Base may not offer |
| fewer `String.reverse` passes (build text forward where the measure allows) | 2 | 2 | 4 | 1.0 | below the bar |

Every lever above still goes through this repository's discipline before it is built: the graveyard sweep of
`perf/NEGATIVE-EVIDENCE.md`, a card in `perf/EXPERIMENTS.md`, a fast twin behind `F.twin.on` with its `fast == spec` law, and an
interleaved cv-gated capture. None of them has been built.
