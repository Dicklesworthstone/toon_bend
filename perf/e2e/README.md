# perf/e2e — the port against the original on real JSON

An end-to-end benchmark suite: the `toon` COMMAND (process start, reading the file, conversion, writing the output) of the
Bend port against `toon_rust`, on 28 real public JSON documents from 64 KB to 13 MB (plus 4 prefix slices of one of them, for a
scaling series), in 7 scenarios, with every output compared byte for byte before anything is timed.

```bash
python3 perf/e2e/bench.py fetch                                  # 28 documents + 4 derived slices, pinned by commit + sha256
python3 perf/e2e/bench.py prepare --reference ./oracle/toon      # the TOON inputs of the decode scenarios
python3 perf/e2e/bench.py run --arm rust_z=rust:./oracle/toon \
    --arm rust_o3=rust:<opt-level=3 build> --arm bend=bend:<dir>/toon          # ~75 min for the full matrix (205 cells)
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
| XL (8.6–13 MB) | semanticscholar, flights_200k, openapi_github | abstracts and author lists, a 200000-row numeric table, GitHub's REST OpenAPI description (deep schemas, long prose: the classic LLM tool-context document) |
| added 2026-09-22 (corpus v2) | unemployment (S), flights_2k/5k/10k (S/M), npm_cli_lock (M), us_10m (M), vscode_lock (M), openapi_github (XL) | BLS rows with ISO timestamps; the flights table at four sizes; two real `package-lock.json` (wide maps keyed by paths, integrity hashes); TopoJSON (arrays of integer pairs) |
| series | flights 2k/5k/10k/20k (vega's own files); semsch_625/1250/2500/5000 (prefix slices of semanticscholar, re-serialized, pinned) | growth with size on one schema: the report's Scaling section |

Sources: `simdjson/simdjson-data` @ `4197c42` (the standard JSON-parser benchmark files), `vega/vega-datasets` @ `a96a3d7`
(real tabular datasets), `github/rest-api-description` @ `642960c`, `microsoft/vscode` @ `fcbe40c` and `npm/cli` @ `7b50811`
(their lockfiles). None is generated; a derived slice is refused when its source holds a non-integer number. The documents and their TOON twins live in `perf/e2e/corpus/` (gitignored).

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

## Results — THE REFERENCE RUN (2026-09-24, `2c33e64`, AMD EPYC-Milan, 8 cores, 1 thread)

`results/2026-09-23-wall2-2c33e64/`. **Port binary `sha256 caac3708…`**, built from `port/main.bend` at
`2c33e64` (571 laws, `All terms check.`, four lanes PASS 1076/1076); original `toon_rust` `694d73b` at
`opt-level=z` and `opt-level=3`. 204 cells.

The BINARY's hash is the identity that matters here, not the commit. A wall-clock number measures the
executable, so it stays valid across every commit that does not change it — and commits that change
`port/` without changing the executable are common: `9c9039e`, `55ec958` and `c5f3b46` differ in
`port/json.bend` (comment corrections), `LAWS.bend` and `PROOF.bend`, and all three build the identical
binary `sha256 825e44de…` (same output basename, which the build is sensitive to). "The `port/` code is
unchanged" would be refuted by a diff; "the binary is unchanged" is checkable in one command. The
previous reference run's arm was `sha256 ec6a58ab…`. Load 2.4–3.6 throughout, because two other sessions on this machine stopped
their own work for it — a four-lane conformance run and a 24 GB C emission.

### Correctness

**204 of 204 cells byte-identical across all three arms** — stdout sha256, stderr sha256 and exit code,
over encode, encode via stdin, `--key-folding`, `--delimiter tab`, `--stats`, decode and
`--expand-paths`. This column does not depend on load.

### Speed — 66 MEASURED cells (cv ≤ 5% on every arm)

| estimator | vs the pinned original (`-Oz`) | vs `-O3` |
|---|---|---|
| median of N | **6.05×** | 9.82× |
| min of N | 6.09× | 9.96× |
| median CPU | 6.09× | 9.93× |

Three estimators within 0.7% of each other. 349 of 612 arms inside the cv gate.

### What nine optimisation levers bought, and how we know it is real

Against the previous reference run (`9ae2f2e`, before EXP-013/018/019/021/022/024 and the rest), read
with `python3 perf/e2e/compare.py`, which prints every arm's own absolute time before any ratio:

| arm | summed median, `9ae2f2e` | `2c33e64` | change |
|---|---|---|---|
| **port** | 134,000 ms | **103,653 ms** | **−22.6%** |
| original `-Oz` | 15,523 ms | 15,779 ms | +1.7% |
| original `-O3` | 9,559 ms | 9,808 ms | +2.6% |

**The port's own absolute time fell 22.6% while both oracle arms stayed inside 2.6%.** That is a code
difference. The ratio improvement is therefore real, and it is **8.06× → 6.33×, a factor of 1.27**, on
the 37 cells MEASURED in BOTH runs — the figure to quote, rather than the 1.36× over all cells, because
only those 37 passed the gate twice.

This matters because the same comparison done badly produced the opposite conclusion. The
`2026-09-23-six-levers-78a2588` run reported 5.81× against 7.98×, an apparent 1.37× win arriving right
after six levers landed and agreeing with their instruction counts — and it was entirely contention:
every arm had slowed, the oracles hardest, because a fixed scheduling cost is a larger fraction of a
40 ms process than of a 700 ms one. See that directory's `INVALID.md`. `compare.py` now refuses that
pattern automatically and exits 1.

### Cost per byte, which is what to optimise against

| scenario | port ms/MB | ratio (MEASURED) |
|---|---|---|
| `decode_expand` | **414.9** | 6.25× |
| `decode` | 292.4 | 5.11× |
| `encode_stats` | 287.0 | 5.55× |
| `encode_fold` | 264.3 | 7.49× |
| `encode_tab` | 223.4 | 5.02× |
| `encode_stdin` | 222.8 | 7.23× |
| `encode` | **201.8** | **8.20×** |

The two columns disagree, and they are answering different questions. `decode_expand` costs the most per
byte of input while carrying one of the better ratios; plain `encode` is the cheapest per byte and has
the worst ratio. **Use ms/MB to choose a target and the ratio to report parity** — a ratio moves when
either program moves.

## The previous reference run (2026-09-23, `9ae2f2e`, before the nine levers)

`results/2026-09-23-final-9ae2f2e/`. Kept because the run above is measured against it.

`results/2026-09-23-final-9ae2f2e/`. Arms: `toon_rust` `694d73b` at `opt-level=z` (the pinned oracle) and at
`opt-level=3`; the port built from a clean `git archive` export of `9ae2f2e` (EXP-007 + EXP-012 + the R16-1
fix; 1076 cases PASS on all four lanes, 450 laws `All terms check.`). 204 cells, host load 3.3 and 24 GB free.

**This is the first run on an unloaded host, and it is the one to quote.** Every earlier run in this
directory was taken while other agents' gates were running; their wall-clock cv ran 19–95% and almost no
cell passed the 5% gate. Here 72 of 204 cells are MEASURED with cv 0.4–3%.

### Correctness

**204 of 204 cells byte-identical across all three arms** — stdout sha256, stderr sha256 and exit code.
Every scenario of every document: encode, encode via stdin, `--key-folding`, `--delimiter tab`, `--stats`,
decode and `--expand-paths`. This column does not depend on load and is the strongest result here.

### Speed (geometric mean of the port's ratio; lower is better)

| estimator | vs `-Oz` (the pinned oracle) | vs `-O3` |
|---|---|---|
| all 204 cells, median of N | 7.98× | 12.34× |
| all 204 cells, min of N | 8.16× | 12.74× |
| all 204 cells, median CPU | 8.06× | 12.53× |
| **72 MEASURED cells only** (cv ≤ 5% on every arm) | **7.70×** | **12.53×** |

The three estimators agree to within 2%, and the MEASURED subset agrees with the whole corpus, so the
figure is not an artifact of which cells passed the gate. **The port is about 8× the pinned original's
wall time, and about 12.5× the original built at `opt-level=3`.**

By scenario (median geomean vs `-Oz`): `encode_fold` 9.71×, `encode` 9.61×, `encode_tab` 9.49×,
`encode_stdin` 9.36×, `decode_expand` 6.96×, `encode_stats` 6.36×, `decode` 5.73×.

**Do not read that ordering as "where the port is slow".** A ratio moves when EITHER program moves, and
ranking cells by it conflates "the port is slow here" with "the original is fast here". The worst single
cell of the whole run, `gsoc_2018/encode_tab` at 17.11×, is not the port being slow: the port is FASTER
there (711 ms) than on plain encode (792 ms), and the ratio is worst because the ORACLE drops from 59.9 ms
to 41.6 ms. The same reversal runs through the aggregate. Ranked by the port's own cost per megabyte of
input:

| scenario | port ms/MB | ratio geomean |
|---|---|---|
| `decode_expand` | **479.6** | 6.96× |
| `encode_fold` | 356.3 | 9.71× |
| `decode` | **340.4** | 5.73× |
| `encode_stats` | 336.3 | 6.36× |
| `encode_tab` | 314.1 | 9.49× |
| `encode_stdin` | 314.0 | 9.36× |
| `encode` | **300.2** | 9.61× |

By the port's own time, `decode` (340 ms/MB) costs MORE per byte than plain `encode` (300 ms/MB), and
`decode_expand` is the most expensive path in the suite — the opposite of what the ratio column suggests.
The ratio ordering says the original's decoder is comparatively slow, which is a fact about the original.
**For choosing an optimisation target, use the ms/MB column; for reporting parity, use the ratio.** By size: S 6.73×, M 7.77×, L 9.46×, XL 9.13×; the gap widens with
the document, so this is not a fixed startup cost. Best cell `flights_2k/decode` 2.69×; worst
`gsoc_2018/encode_tab` 17.11×.

### Memory and throughput

| | `-Oz` | `-O3` | port |
|---|---|---|---|
| peak RSS, median cell | 11.5 MB | 11.7 MB | **47.0 MB** |
| peak RSS, worst cell | 164.2 MB | 164.3 MB | **615.8 MB** |
| encode of `openapi_github` (13.0 MB) | 295.6 ms, 44.0 MB/s | 223.4 ms, 58.2 MB/s | 2950.4 ms, **4.4 MB/s** |

The port holds the whole document as a `Json` value of boxed constructors and carries every number as a
software binary64 over big naturals, so a larger resident set is expected; the measured factors are 4.09× at
the median cell and 3.75× at the worst, and the worst-case figure is the number to watch if the port is ever run on a document near memory.

### Memory: linear, ~26 bytes per input byte, and halved by the copy-removing levers

The suite records peak RSS per cell (`/usr/bin/time -f %M` on the untimed verification run, so the
figure is the child's own high-water mark and not Python's).

**The shape is linear.** Fitted over the corpus's two size series — `flights` from 72 KB to 9.9 MB and
the `semanticscholar` prefixes from 1.0 MB to 8.9 MB, five and four points each — the slope of log RSS
against log bytes is **b = 0.92 to 0.97** across all nine (family, scenario) pairs. No superlinear
blow-up: the pushdown machines and the tail-recursive traversals hold at scale, and the linearity rules
out a leak.

**The constant halved when the copy-removing levers landed, which no wall-clock or instruction
measurement had shown.** Peak RSS of `--encode`, same inputs, same flags, two builds:

| document | `9ae2f2e` (before) | `2c33e64` (after) | |
|---|---|---|---|
| `gsoc_2018` | 163,512 KiB | 84,716 KiB | **1.93× less** |
| `citm_catalog` | 86,496 KiB | 45,904 KiB | **1.88× less** |

That is the same cause as their instruction win: the port had been holding the document in several list
representations at once, and removing the redundant copies removed the memory they occupied as well as
the work of building them. It is worth stating separately because a lever justified and gated on
instruction counts turned out to pay a second dividend nobody measured.

**Where it stands on the current tree** (`2c33e64`, documents over 1 MB so the ~7 MB fixed term is small):

| document | numbers | port | original (`-Oz`) | ratio |
|---|---|---|---|---|
| `openapi_github` (13.0 MB) | 1% | **25.5 B/byte** | 7.2 | 3.5× |
| `gsoc_2018` (3.3 MB) | 1% | 26.0 | 5.4 | 4.9× |
| `citm_catalog` (1.7 MB) | 8% | 27.2 | 7.2 | 3.8× |
| `canada` (2.3 MB) | 90% | **60.2** | 13.9 | 4.3× |

A floor of about **26 bytes of resident memory per input byte** for text, rising to **60** for a
number-heavy document — numbers cost 2.3× what text does (60.2 against 26.0), the same asymmetry the counted
comparison found for instructions (3.25× for integers against 11.80× for decimals).

**The practical ceiling is a MEMORY ceiling, not a time one.** Because the fit is linear over two orders
of magnitude it extrapolates: about **2.6 GB for a 100 MB document** and **26 GB for 1 GB** at the text
floor, and about 2.3× that for number-heavy input. On a 30 GB host that puts the limit near 1 GB of
text input — and no wall-clock number would ever have revealed it.

The remaining constant is structural and named in the architecture: a `Json` value is a tree of boxed
constructors and every number is a software binary64 over big naturals held as `List<&2, U32>`. The
levers took out the redundant copies; the one remaining copy is the representation itself.

### What this run does NOT establish

- It is **not** comparable cell-by-cell with the earlier runs in this directory: those were NOISY on a
  loaded host, and comparing a clean run against a noisy baseline would manufacture a speedup or a
  regression out of scheduling. No EXP-012 delta is claimed here for that reason; EXP-012's own evidence is
  its card and NE-016.
- The 132 NOISY cells are orientation only. They agree with the MEASURED ones, which is why the whole-corpus
  geomean is quoted beside the gated one rather than instead of it.
- One thread only. The port places one parallel let (EXP-007's number pre-pass), so `--threads 8` changes
  encode and nothing else; that is a separate measurement.

## Counted comparison (2026-09-23, deterministic, load-independent)

`results/` holds wall-clock runs; this section holds **instruction counts**, which this shared host
can actually produce. Every cv-gated wall capture here has been refused for two days (the last full
run had **28 of 612 arms within cv 5%**), while `valgrind --tool=cachegrind --cache-sim=no` is
deterministic to about 1e-8 run to run and does not care about load at all.

**This is a `counted` claim, not a `measured` one.** Cachegrind counts instructions, not stalls: it
sees no cache miss and no memory latency. It answers "how much more WORK does the port do than the
original", which is a real question with a defensible answer, and it does not answer "how much slower
is it in seconds".

Port built from `2c33e64` (571 laws, `All terms check.`); original `toon_rust` `694d73b` at
`opt-level=z` and `opt-level=3`. **Each cell's stdout sha256 and exit code were compared with the
oracle's and matched before it was counted** — a differing arm is skipped, never counted.

| document | mode | input | port I-refs | original (`-Oz`) | port / `-Oz` | port / `-O3` |
|---|---|---|---|---|---|---|
| `github_events` | encode | 65 KB | 69,335,386 | 11,212,882 | **6.18×** | 9.94× |
| `github_events` | decode | 65 KB | 91,108,288 | 15,325,631 | **5.94×** | 10.60× |
| `apache_builds` | encode | 127 KB | 142,099,515 | 21,164,012 | **6.71×** | 10.09× |
| `apache_builds` | decode | 127 KB | 127,031,577 | 32,985,081 | **3.85×** | 7.29× |
| `twitter` | encode | 632 KB | 669,343,457 | 100,702,697 | **6.65×** | 10.09× |
| `twitter` | decode | 632 KB | 855,650,214 | 152,175,306 | **5.62×** | 9.82× |
| `citm_catalog` | encode | 1,727 KB | 1,837,261,188 | 216,214,935 | **8.50×** | 13.64× |
| `citm_catalog` | decode | 1,727 KB | 1,649,954,763 | 379,392,083 | **4.35×** | 8.63× |
| `gsoc_2018` | encode | 3,328 KB | 3,010,313,869 | 359,329,330 | **8.38×** | 15.70× |
| `gsoc_2018` | decode | 3,328 KB | 4,125,614,132 | 424,313,564 | **9.72×** | 18.02× |
| `canada` | encode | 2,251 KB | 11,014,963,483 | 826,582,787 | **13.33×** | 24.96× |
| `canada` | decode | 2,251 KB | 13,543,103,834 | 1,874,185,975 | **7.23×** | 16.27× |

**Geometric mean: 6.83× the pinned original's instructions, 12.15× against `-O3`.**
Encode 8.00×, decode 5.83×. Range 3.85× to 13.33×.

### What the spread says

**`canada` is the worst cell in the suite by a wide margin** — 13.33× on encode, 4,893 instructions
per input byte against the original's 367. It is the number-heavy document, and the port carries a
software binary64 over big naturals because Bend has no `f64`. Every other document sits between 3.85×
and 9.72×. The cost of not having hardware floats is concentrated almost entirely here, and it is
larger than the cost of everything else the port does differently.

**Read the instructions-per-byte column, not the ratio**, when choosing what to work on next: a ratio
moves when either program moves (see the correction above, where `encode_tab` looked like the worst
cell in the wall-clock run at 17.11x while the port took 711 ms there against 792 ms on plain encode,
the ratio being worst because the ORACLE dropped from 59.9 ms to 41.6 ms).

## Earlier runs (2026-09-22, AMD EPYC-Milan, 8 cores, shared host, 1 thread)

Two full runs of 140 cells each, in `results/`:

| run | arms | outputs identical | MEASURED cells | host load |
|---|---|---|---|---|
| `2026-09-22-full` | `toon_rust` `f955c67` at `opt-level=z` (the then-pinned oracle) and at `opt-level=3`; the port at `866aa8a` | 140/140 | **39** | 1–4 |
| `2026-09-22-repinned` | `toon_rust` `7c1d6e4` (the C-10 fix) at `z` and `3`; the port at `a8efed0` | 140/140, all exit 0 | 1 | 6–7 (other agents' gates) |
| `2026-09-22-694d73b` | `toon_rust` `694d73b` (the fix-every-bug re-pin) at `z` (682872 bytes) and `3` (884048 bytes, 1071/1071 goldens); the port at `fb974a4` (1071/1071 on c-1t); corpus v2, 205 cells | 205/205, all exit 0 | **0** | 8.5 → 20 (other agents' gates and this session's own research agents) |

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

### Third run: the current pins (`2026-09-22-694d73b`; orientation only, every cell NOISY)

The load rose from 8.5 to 20 on 8 cores during the run, and no cell met the 5% cv gate, on wall time or on the child's CPU time
(cv 7–20%). So nothing below is a MEASURED ratio. It is orientation for the shape, reported with the estimator least favourable to the
port: contention adds a near-constant time and so inflates the shorter arm proportionally more, and the ratio of medians is pulled
toward 1. Here the median ratio divided by the minimum ratio had p10 0.80, p50 0.876 and p90 1.01 per cell; the median flatters the port
by about 12%.

| scenario (cells) | port / rust `z`, by minimum | port / rust `3`, by minimum | port / rust `z`, by median |
|---|---|---|---|
| encode (32) | 12.1× | 17.1× | 10.7× |
| encode_stdin / fold / tab (28 each) | 12.1× / 12.2× / 12.4× | 17.8× / 17.1× / 17.6× | 11.0× / 10.7× / 10.8× |
| encode_stats (28) | 8.5× | 15.8× | 7.5× |
| decode (32) | 8.2× | 13.7× | 7.0× |
| decode_expand (28) | 9.2× | 15.6× | 8.2× |
| all 204 document cells (geomean) | 10.5× | 16.3× | 9.2× |

Per document (port / rust `3` by minimum, geomean over its scenarios): TopoJSON 5.8×, github_events 7.7×, the flights table 8.0–9.3×
(32.7× at 200k rows, a third of them doubles), lockfiles 13.6–16.3×, OpenAPI 13.7×, semanticscholar 14.1×, twitter 17.0×, gsoc 21.3×,
jobs 27.8×, marine_ik 30.4×, mesh 58.8×, canada 86.0×, numbers 88.0×. `opt-level=3` of the original took 0.64 of the pinned `z`
build's time (geomean, all three estimators agree on this one), so a ratio against `z` flatters the port by about 1.6×.

**Scaling is linear on both sides.** The flights series (2k → 20k rows) fits time ∝ n^b with b = 1.03–1.07 for the port and
0.96–1.10 for the original in every scenario; the semanticscholar slices (625 → 5000 records) give b = 0.92–0.96 against 0.83–0.97.
The ratio does not grow with the input on these schemas (orientation: the points are NOISY).

**Memory:** peak RSS per input byte, geomean per scenario: the port 59–60 B/B on encode, 100 on decode, 112 on decode_expand; the
original 14–25. The small decode inputs reach 169–209 B/B, where the runtime's base heap dominates.

**Profiles** (gprof on the emitted C, `results/2026-09-22-694d73b/profiles/`, inclusive time; ranking only, the `-pg` run is
instrumented): `BN.cmp` 42–45% on canada encode and on the flights_200k decode (about 205 compares per number); on the OpenAPI encode
`fctx.child` building the dotted fold path with `T.cat` for every field although folding is off (18.5%, `WL_FID_ENCODE_CTX_FIELD` +
`spin_263`/`spin_84`/`spin_86`); on prose-heavy decodes `T.cut` copying every line that holds no `[` (28% of gsoc, 19% of the OpenAPI
decode_expand; `spin_148` = `head_is` + `cut.go`). `spin_N` numbers are per build: map them through the emitted C.

**What the corpus found beyond speed.** (1) `--key-folding safe` then `--expand-paths safe` changes 3 of the 28 documents with exit 0:
a literal key holding a dot (`"lazy.js"` in a package-lock, a gist file name `"hello.rb"` in the OpenAPI description) is written
unquoted and then split. The reference TS implementation does exactly the same, so this is the format's property at spec v3.0 (spec
v4 dropped both options), not a bug of either program. (2) Outside the corpus, round 16's repro of a quadratic repeated-key merge was
re-checked here: 8000 repeated keys take 17.2 s in the port against 0.24 s in the original (bead `toon_bend-qgu`).

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
