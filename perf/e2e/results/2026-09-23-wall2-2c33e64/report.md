# toon end-to-end benchmark: rust_z, rust_o3, bend

Run `2026-09-23-wall2-2c33e64`, started 2026-09-24T03:05:17Z, finished 2026-09-24T03:45:12Z. Reference arm: **rust_z**; every ratio is `<arm> median / rust_z median` (above 1 = slower than rust_z).

## Environment

- host `hetzner1`, AMD EPYC-Milan Processor, 8 cores, governor `None`, kernel 7.0.0-30-generic, 31 GiB RAM
- load average at start (3.56, 6.79, 6.98), at end (2.35, 3.01, 3.64) (a shared host)
- toon_bend HEAD `dd355a7a406abcbcefb87cb443490707fa1a1dd4` (port/ has uncommitted changes)
- arm **rust_z** (rust): `/data/tmp/claude-1000/-data-projects-toon-bend/9e91730b-d91a-4f9e-8b28-923307a5f8cb/scratchpad/arms2/z/toon`, 682872 bytes, sha256 `821287eaf1a6d320…`
- arm **rust_o3** (rust): `/data/tmp/claude-1000/-data-projects-toon-bend/9e91730b-d91a-4f9e-8b28-923307a5f8cb/scratchpad/arms2/o3/toon`, 883984 bytes, sha256 `b3683f3917d51fe9…`
- arm **bend** (bend): `/data/tmp/claude-1000/-data-projects-toon-bend/9e91730b-d91a-4f9e-8b28-923307a5f8cb/scratchpad/final2c33e64/toon`, 1025816 bytes, sha256 `caac37086fda0ae4…`
- budget 30.0 s per cell, runs clamped to [5, 30], arms interleaved in seeded shuffled rounds (seed 1); cv gate 5.0% (a cell above it on any arm is NOISY: its ratio is orientation, not evidence)
- timed runs write stdout to /dev/null; the untimed first run of each cell compared stdout, stderr and exit code of every arm with the reference byte for byte

## Summary

A cell whose reference exits non-zero times an ERROR PATH (the same failure on every arm, byte for byte); it is listed in its table but left out of these geometric means.

| scenario | cells | outputs identical | geomean rust_o3/rust_z | geomean bend/rust_z | range rust_o3/rust_z | range bend/rust_z |
|---|---|---|---|---|---|---|
| encode | 32 | 32/32 | 0.7× | 6.1× | 0.5× – 0.8× | 2.8× – 12.1× |
| encode_stdin | 28 | 28/28 | 0.7× | 6.2× | 0.5× – 0.8× | 2.8× – 11.9× |
| encode_fold | 28 | 28/28 | 0.7× | 6.8× | 0.5× – 0.8× | 2.7× – 12.3× |
| encode_tab | 28 | 28/28 | 0.7× | 6.2× | 0.5× – 0.8× | 2.8× – 12.0× |
| encode_stats | 28 | 28/28 | 0.5× | 5.4× | 0.4× – 0.6× | 2.7× – 10.2× |
| decode | 32 | 32/32 | 0.6× | 4.7× | 0.4× – 0.8× | 2.1× – 8.0× |
| decode_expand | 28 | 28/28 | 0.6× | 5.9× | 0.4× – 0.8× | 3.6× – 8.3× |

### The same ratios by three estimators

On a loaded host the median carries the noise of every sample. Two estimators are less sensitive to it: the MINIMUM over the interleaved samples (contention only ever adds time) and the median CPU time (user + sys of the child itself, which excludes waiting for a core but not cache or SMT interference). Contention adds roughly constant time, so it inflates the shorter arm proportionally more and pulls the ratio of medians toward 1: the median flatters the slower program (by ~12% on the 2026-09-22 run at load 8-14). A claim uses the estimator least favourable to the port and names it; the spread between the three is the noise band. None of them replaces the cv gate: a NOISY cell stays orientation.

| scenario | rust_o3/rust_z median | min | CPU | bend/rust_z median | min | CPU |
|---|---|---|---|---|---|---|
| encode | 0.7× | 0.7× | 0.7× | 6.1× | 6.3× | 6.2× |
| encode_stdin | 0.7× | 0.7× | 0.7× | 6.2× | 6.3× | 6.2× |
| encode_fold | 0.7× | 0.7× | 0.7× | 6.8× | 7.0× | 6.9× |
| encode_tab | 0.7× | 0.7× | 0.7× | 6.2× | 6.4× | 6.3× |
| encode_stats | 0.5× | 0.5× | 0.5× | 5.4× | 5.5× | 5.4× |
| decode | 0.6× | 0.6× | 0.6× | 4.7× | 4.7× | 4.7× |
| decode_expand | 0.6× | 0.6× | 0.6× | 5.9× | 6.0× | 6.0× |

## By document

Geometric mean over the scenarios of each document of `<arm> / rust_z`; the MEASURED column counts cells within the cv gate.

| document | tier | JSON size | scenarios | MEASURED | rust_o3/rust_z median | min | CPU | bend/rust_z median | min | CPU |
|---|---|---|---|---|---|---|---|---|---|---|
| github_events | S | 0.07 MB | 7 | 3 | 0.8× | 0.8× | 0.8× | 3.6× | 3.7× | 3.7× |
| apache_builds | S | 0.13 MB | 7 | 0 | 0.7× | 0.7× | 0.7× | 4.3× | 4.5× | 4.4× |
| numbers | S | 0.15 MB | 7 | 3 | 0.6× | 0.5× | 0.5× | 9.8× | 10.1× | 10.1× |
| flights_2k | S | 0.18 MB | 7 | 2 | 0.7× | 0.7× | 0.7× | 4.2× | 4.3× | 4.3× |
| unemployment | S | 0.19 MB | 7 | 0 | 0.7× | 0.7× | 0.7× | 4.9× | 5.1× | 5.0× |
| instruments | S | 0.22 MB | 7 | 0 | 0.7× | 0.7× | 0.7× | 4.8× | 4.9× | 4.9× |
| npm_cli_lock | M | 0.44 MB | 7 | 3 | 0.7× | 0.7× | 0.7× | 4.9× | 4.9× | 5.0× |
| flights_5k | M | 0.45 MB | 7 | 1 | 0.7× | 0.7× | 0.7× | 4.7× | 4.8× | 4.8× |
| random | M | 0.51 MB | 7 | 1 | 0.7× | 0.7× | 0.7× | 5.7× | 5.5× | 5.8× |
| update_center | M | 0.53 MB | 7 | 1 | 0.7× | 0.7× | 0.7× | 5.1× | 5.0× | 5.2× |
| twitterescaped | M | 0.56 MB | 7 | 1 | 0.7× | 0.7× | 0.7× | 5.7× | 5.7× | 5.8× |
| twitter | M | 0.63 MB | 7 | 2 | 0.7× | 0.7× | 0.7× | 5.9× | 5.8× | 6.0× |
| us_10m | M | 0.64 MB | 7 | 3 | 0.6× | 0.6× | 0.6× | 2.9× | 3.0× | 2.9× |
| mesh | M | 0.72 MB | 7 | 5 | 0.5× | 0.5× | 0.5× | 8.0× | 8.1× | 8.0× |
| vscode_lock | M | 0.78 MB | 7 | 5 | 0.7× | 0.7× | 0.7× | 5.9× | 5.7× | 5.9× |
| flights_10k | M | 0.89 MB | 7 | 4 | 0.7× | 0.7× | 0.7× | 4.9× | 5.1× | 4.9× |
| jobs | M | 0.94 MB | 7 | 3 | 0.6× | 0.6× | 0.6× | 10.1× | 10.3× | 10.2× |
| football | M | 1.21 MB | 7 | 1 | 0.7× | 0.7× | 0.7× | 6.9× | 6.9× | 6.9× |
| earthquakes | M | 1.22 MB | 7 | 1 | 0.6× | 0.6× | 0.6× | 6.6× | 6.9× | 6.7× |
| movies | M | 1.40 MB | 7 | 0 | 0.7× | 0.6× | 0.7× | 6.2× | 6.5× | 6.2× |
| citm_catalog | L | 1.73 MB | 7 | 0 | 0.6× | 0.6× | 0.6× | 7.6× | 8.2× | 7.6× |
| flights_20k | L | 1.78 MB | 7 | 0 | 0.7× | 0.7× | 0.7× | 4.8× | 5.0× | 4.8× |
| canada | L | 2.25 MB | 7 | 3 | 0.5× | 0.5× | 0.5× | 9.1× | 9.3× | 9.1× |
| marine_ik | L | 2.98 MB | 7 | 4 | 0.5× | 0.5× | 0.5× | 7.4× | 7.6× | 7.4× |
| gsoc_2018 | L | 3.33 MB | 7 | 0 | 0.6× | 0.6× | 0.6× | 6.7× | 7.1× | 6.7× |
| semanticscholar | XL | 8.59 MB | 7 | 5 | 0.7× | 0.7× | 0.7× | 5.8× | 5.9× | 5.8× |
| flights_200k | XL | 9.86 MB | 7 | 4 | 0.6× | 0.6× | 0.6× | 8.5× | 8.5× | 8.5× |
| openapi_github | XL | 13.01 MB | 7 | 7 | 0.7× | 0.7× | 0.7× | 5.5× | 5.6× | 5.5× |
| semsch_625 | M | 0.98 MB | 2 | 0 | 0.7× | 0.7× | 0.7× | 5.9× | 6.0× | 5.9× |
| semsch_1250 | L | 2.10 MB | 2 | 1 | 0.7× | 0.6× | 0.7× | 6.2× | 6.5× | 6.3× |
| semsch_2500 | L | 4.27 MB | 2 | 1 | 0.7× | 0.6× | 0.7× | 6.1× | 6.2× | 6.1× |
| semsch_5000 | XL | 8.59 MB | 2 | 2 | 0.7× | 0.7× | 0.7× | 6.0× | 6.0× | 6.0× |

## Scaling

Each series is ONE schema at several sizes (records `n`). `b` is the least-squares slope of log(median time) against log(n): 1.0 is linear, above 1 grows faster than the input. Start-up is inside every point, which pulls `b` below 1 when the smallest points are short. `ms / 1k rec` is the marginal cost between the two largest points.

### flights / encode

| arm | n=2000 | n=5000 | n=10000 | n=20000 | b | ms / 1k rec | rust_o3/rust_z at n=20000 | bend/rust_z at n=20000 |
|---|---|---|---|---|---|---|---|---|
| rust_z | 7.02 ms | 15.7 ms | 32.0 ms | 75.5 ms | 1.03 | 4.34 | 0.70× | 5.42× |
| rust_o3 | 5.28 ms | 11.4 ms | 22.2 ms | 52.9 ms | 0.99 | 3.07 | | |
| bend | 33.7 ms | 89.1 ms | 185.7 ms | 409.2 ms | 1.08 | 22.36 | | |

### flights / encode_stdin

| arm | n=2000 | n=5000 | n=10000 | n=20000 | b | ms / 1k rec | rust_o3/rust_z at n=20000 | bend/rust_z at n=20000 |
|---|---|---|---|---|---|---|---|---|
| rust_z | 7.10 ms | 16.2 ms | 31.2 ms | 75.0 ms | 1.01 | 4.38 | 0.70× | 5.41× |
| rust_o3 | 5.23 ms | 11.8 ms | 22.2 ms | 52.3 ms | 0.99 | 3.01 | | |
| bend | 34.0 ms | 90.0 ms | 182.0 ms | 406.1 ms | 1.07 | 22.42 | | |

### flights / encode_fold

| arm | n=2000 | n=5000 | n=10000 | n=20000 | b | ms / 1k rec | rust_o3/rust_z at n=20000 | bend/rust_z at n=20000 |
|---|---|---|---|---|---|---|---|---|
| rust_z | 6.87 ms | 15.8 ms | 32.5 ms | 83.6 ms | 1.07 | 5.11 | 0.78× | 5.10× |
| rust_o3 | 5.18 ms | 11.7 ms | 22.5 ms | 65.1 ms | 1.08 | 4.26 | | |
| bend | 33.7 ms | 89.6 ms | 185.0 ms | 426.3 ms | 1.10 | 24.13 | | |

### flights / encode_tab

| arm | n=2000 | n=5000 | n=10000 | n=20000 | b | ms / 1k rec | rust_o3/rust_z at n=20000 | bend/rust_z at n=20000 |
|---|---|---|---|---|---|---|---|---|
| rust_z | 7.12 ms | 16.5 ms | 33.3 ms | 75.5 ms | 1.02 | 4.22 | 0.68× | 5.41× |
| rust_o3 | 5.46 ms | 12.0 ms | 22.9 ms | 51.1 ms | 0.96 | 2.82 | | |
| bend | 34.1 ms | 91.4 ms | 187.8 ms | 408.8 ms | 1.07 | 22.10 | | |

### flights / encode_stats

| arm | n=2000 | n=5000 | n=10000 | n=20000 | b | ms / 1k rec | rust_o3/rust_z at n=20000 | bend/rust_z at n=20000 |
|---|---|---|---|---|---|---|---|---|
| rust_z | 9.14 ms | 21.3 ms | 43.1 ms | 97.4 ms | 1.02 | 5.42 | 0.61× | 5.30× |
| rust_o3 | 5.83 ms | 13.0 ms | 25.5 ms | 59.8 ms | 1.00 | 3.43 | | |
| bend | 43.3 ms | 114.1 ms | 239.5 ms | 516.5 ms | 1.08 | 27.70 | | |

### flights / decode

| arm | n=2000 | n=5000 | n=10000 | n=20000 | b | ms / 1k rec | rust_o3/rust_z at n=20000 | bend/rust_z at n=20000 |
|---|---|---|---|---|---|---|---|---|
| rust_z | 10.1 ms | 23.2 ms | 45.0 ms | 92.0 ms | 0.96 | 4.70 | 0.60× | 2.76× |
| rust_o3 | 6.50 ms | 14.2 ms | 27.2 ms | 55.3 ms | 0.93 | 2.81 | | |
| bend | 21.4 ms | 52.3 ms | 108.2 ms | 253.8 ms | 1.07 | 14.55 | | |

### flights / decode_expand

| arm | n=2000 | n=5000 | n=10000 | n=20000 | b | ms / 1k rec | rust_o3/rust_z at n=20000 | bend/rust_z at n=20000 |
|---|---|---|---|---|---|---|---|---|
| rust_z | 10.8 ms | 24.6 ms | 48.5 ms | 99.7 ms | 0.97 | 5.11 | 0.61× | 4.84× |
| rust_o3 | 7.12 ms | 15.5 ms | 29.4 ms | 60.6 ms | 0.93 | 3.12 | | |
| bend | 43.6 ms | 108.9 ms | 225.8 ms | 482.4 ms | 1.04 | 25.66 | | |

### semsch / encode

| arm | n=625 | n=1250 | n=2500 | n=5000 | b | ms / 1k rec | rust_o3/rust_z at n=5000 | bend/rust_z at n=5000 |
|---|---|---|---|---|---|---|---|---|
| rust_z | 20.9 ms | 45.0 ms | 96.2 ms | 201.5 ms | 1.09 | 42.09 | 0.75× | 5.64× |
| rust_o3 | 15.5 ms | 33.1 ms | 70.2 ms | 151.0 ms | 1.09 | 32.35 | | |
| bend | 121.3 ms | 271.0 ms | 560.2 ms | 1.14 s | 1.07 | 230.22 | | |

### semsch / decode

| arm | n=625 | n=1250 | n=2500 | n=5000 | b | ms / 1k rec | rust_o3/rust_z at n=5000 | bend/rust_z at n=5000 |
|---|---|---|---|---|---|---|---|---|
| rust_z | 31.2 ms | 63.9 ms | 136.2 ms | 277.3 ms | 1.05 | 56.44 | 0.61× | 6.37× |
| rust_o3 | 19.3 ms | 37.0 ms | 80.8 ms | 169.2 ms | 1.05 | 35.37 | | |
| bend | 185.2 ms | 411.5 ms | 862.5 ms | 1.77 s | 1.08 | 361.96 | | |

## Memory

Peak RSS of the verification run of each cell (GNU time), as a geometric mean over the cells of a scenario, and as bytes of peak RSS per byte of the scenario's input.

| scenario | rust_z peak RSS | rust_z B/B | rust_o3 peak RSS | rust_o3 B/B | bend peak RSS | bend B/B | rust_o3/rust_z RSS | bend/rust_z RSS |
|---|---|---|---|---|---|---|---|---|
| encode | 14 MB | 14 | 14 MB | 15 | 33 MB | 36 | 1.0× | 2.5× |
| encode_stdin | 12 MB | 15 | 13 MB | 16 | 29 MB | 37 | 1.0× | 2.4× |
| encode_fold | 13 MB | 16 | 13 MB | 16 | 30 MB | 37 | 1.0× | 2.3× |
| encode_tab | 12 MB | 15 | 13 MB | 16 | 29 MB | 37 | 1.0× | 2.4× |
| encode_stats | 12 MB | 15 | 13 MB | 16 | 49 MB | 61 | 1.0× | 4.0× |
| decode | 15 MB | 22 | 15 MB | 23 | 46 MB | 69 | 1.0× | 3.1× |
| decode_expand | 14 MB | 25 | 14 MB | 26 | 42 MB | 78 | 1.0× | 3.1× |

## encode

| document | input | rust_z median (p95) | rust_o3 median (p95) | bend median (p95) | rust_o3/rust_z [95% CI] | bend/rust_z [95% CI] | rust_z MB/s | rust_o3 MB/s | bend MB/s | rust_z peak RSS | rust_o3 peak RSS | bend peak RSS | cv % (rust_z/rust_o3/bend) | n | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| github_events | 0.07 MB | 2.31 ms (2.51 ms) | 1.96 ms (2.18 ms) | 7.62 ms (7.88 ms) | 0.85× [0.83, 0.87] | 3.30× [3.24, 3.34] | 28.18 | 33.20 | 8.55 | 3 MB | 3 MB | 5 MB | 3.7/7.0/3.0 | 30 | NOISY |
| apache_builds | 0.13 MB | 3.11 ms (3.76 ms) | 2.51 ms (2.81 ms) | 15.4 ms (16.1 ms) | 0.81× [0.79, 0.84] | 4.93× [4.81, 5.13] | 40.91 | 50.61 | 8.29 | 3 MB | 4 MB | 7 MB | 6.8/4.8/2.3 | 30 | NOISY |
| numbers | 0.15 MB | 5.94 ms (6.40 ms) | 3.49 ms (3.83 ms) | 71.1 ms (75.3 ms) | 0.59× [0.57, 0.60] | 11.98× [11.75, 12.17] | 25.29 | 43.00 | 2.11 | 4 MB | 4 MB | 8 MB | 3.8/4.8/2.7 | 30 | MEASURED |
| flights_2k | 0.18 MB | 7.02 ms (7.75 ms) | 5.28 ms (5.78 ms) | 33.7 ms (35.0 ms) | 0.75× [0.73, 0.78] | 4.80× [4.68, 4.97] | 25.41 | 33.79 | 5.29 | 5 MB | 5 MB | 8 MB | 11.8/4.0/1.9 | 30 | NOISY |
| unemployment | 0.19 MB | 7.34 ms (7.98 ms) | 5.33 ms (6.16 ms) | 42.1 ms (47.3 ms) | 0.73× [0.71, 0.74] | 5.73× [5.61, 5.89] | 25.29 | 34.85 | 4.41 | 5 MB | 5 MB | 9 MB | 5.6/6.7/4.2 | 30 | NOISY |
| instruments | 0.22 MB | 5.31 ms (5.95 ms) | 4.17 ms (4.45 ms) | 25.9 ms (29.9 ms) | 0.79× [0.76, 0.81] | 4.88× [4.77, 5.01] | 41.50 | 52.85 | 8.51 | 4 MB | 5 MB | 9 MB | 5.8/4.1/6.1 | 30 | NOISY |
| npm_cli_lock | 0.44 MB | 12.0 ms (13.4 ms) | 9.43 ms (10.6 ms) | 50.4 ms (53.1 ms) | 0.79× [0.76, 0.80] | 4.20× [4.06, 4.27] | 36.45 | 46.36 | 8.67 | 6 MB | 6 MB | 14 MB | 5.5/23.3/3.3 | 30 | NOISY |
| flights_5k | 0.45 MB | 15.7 ms (17.7 ms) | 11.4 ms (13.4 ms) | 89.1 ms (94.3 ms) | 0.72× [0.71, 0.76] | 5.66× [5.49, 5.76] | 28.34 | 39.09 | 5.01 | 9 MB | 9 MB | 15 MB | 5.6/6.9/3.5 | 30 | NOISY |
| random | 0.51 MB | 14.7 ms (15.7 ms) | 10.9 ms (11.6 ms) | 86.7 ms (99.1 ms) | 0.74× [0.72, 0.75] | 5.89× [5.65, 6.08] | 34.68 | 46.97 | 5.89 | 8 MB | 8 MB | 16 MB | 3.5/3.6/7.0 | 30 | NOISY |
| update_center | 0.53 MB | 16.2 ms (18.0 ms) | 12.4 ms (13.4 ms) | 75.5 ms (82.5 ms) | 0.77× [0.74, 0.79] | 4.66× [4.50, 4.84] | 32.89 | 42.89 | 7.06 | 8 MB | 8 MB | 18 MB | 5.1/5.2/5.3 | 30 | NOISY |
| twitterescaped | 0.56 MB | 13.2 ms (14.7 ms) | 9.41 ms (10.6 ms) | 69.5 ms (78.0 ms) | 0.71× [0.69, 0.73] | 5.26× [5.13, 5.44] | 42.54 | 59.78 | 8.09 | 7 MB | 7 MB | 17 MB | 5.3/5.6/5.6 | 30 | NOISY |
| twitter | 0.63 MB | 12.9 ms (13.9 ms) | 9.59 ms (10.8 ms) | 73.5 ms (80.7 ms) | 0.74× [0.72, 0.77] | 5.71× [5.58, 5.87] | 49.07 | 65.88 | 8.60 | 7 MB | 7 MB | 19 MB | 4.1/5.8/5.2 | 30 | NOISY |
| us_10m | 0.64 MB | 67.6 ms (73.9 ms) | 42.8 ms (48.3 ms) | 186.3 ms (191.4 ms) | 0.63× [0.62, 0.66] | 2.75× [2.68, 2.82] | 9.50 | 15.01 | 3.45 | 25 MB | 25 MB | 36 MB | 4.9/6.3/2.3 | 30 | NOISY |
| mesh | 0.72 MB | 28.9 ms (30.1 ms) | 15.6 ms (16.5 ms) | 276.9 ms (285.6 ms) | 0.54× [0.53, 0.55] | 9.57× [9.39, 9.69] | 25.01 | 46.25 | 2.61 | 11 MB | 11 MB | 25 MB | 2.2/2.5/1.5 | 30 | MEASURED |
| vscode_lock | 0.78 MB | 17.1 ms (20.6 ms) | 13.5 ms (15.4 ms) | 86.7 ms (104.0 ms) | 0.79× [0.75, 0.80] | 5.07× [4.84, 5.23] | 45.69 | 57.88 | 9.02 | 8 MB | 8 MB | 22 MB | 8.7/5.3/8.3 | 30 | NOISY |
| flights_10k | 0.89 MB | 32.0 ms (35.3 ms) | 22.2 ms (25.0 ms) | 185.7 ms (192.5 ms) | 0.69× [0.67, 0.73] | 5.80× [5.61, 6.00] | 27.87 | 40.13 | 4.81 | 15 MB | 15 MB | 26 MB | 6.1/7.5/1.9 | 30 | NOISY |
| jobs | 0.94 MB | 25.7 ms (28.6 ms) | 18.1 ms (20.3 ms) | 309.3 ms (325.6 ms) | 0.71× [0.67, 0.73] | 12.05× [11.59, 12.37] | 36.51 | 51.74 | 3.03 | 12 MB | 12 MB | 28 MB | 5.7/6.7/2.7 | 30 | NOISY |
| football | 1.21 MB | 22.4 ms (24.3 ms) | 16.6 ms (18.8 ms) | 193.3 ms (218.9 ms) | 0.74× [0.72, 0.77] | 8.62× [8.38, 8.93] | 53.83 | 72.51 | 6.24 | 11 MB | 12 MB | 33 MB | 8.3/8.9/5.0 | 30 | NOISY |
| earthquakes | 1.22 MB | 49.8 ms (52.6 ms) | 33.9 ms (36.2 ms) | 309.9 ms (326.6 ms) | 0.68× [0.66, 0.70] | 6.22× [6.14, 6.36] | 24.50 | 35.97 | 3.94 | 17 MB | 17 MB | 42 MB | 6.9/4.4/2.5 | 30 | NOISY |
| movies | 1.40 MB | 36.1 ms (42.9 ms) | 25.2 ms (29.6 ms) | 268.7 ms (278.9 ms) | 0.70× [0.67, 0.74] | 7.45× [7.25, 7.72] | 38.83 | 55.57 | 5.21 | 17 MB | 17 MB | 38 MB | 8.9/11.4/1.9 | 30 | NOISY |
| citm_catalog | 1.73 MB | 29.0 ms (67.4 ms) | 19.8 ms (40.7 ms) | 248.2 ms (368.3 ms) | 0.68× [0.62, 0.77] | 8.55× [8.10, 9.30] | 59.51 | 87.43 | 6.96 | 12 MB | 12 MB | 45 MB | 47.9/29.7/13.3 | 30 | NOISY |
| flights_20k | 1.78 MB | 75.5 ms (152.3 ms) | 52.9 ms (317.4 ms) | 409.2 ms (875.2 ms) | 0.70× [0.62, 0.78] | 5.42× [4.75, 6.85] | 23.65 | 33.73 | 4.36 | 27 MB | 27 MB | 50 MB | 49.9/90.2/38.1 | 30 | NOISY |
| canada | 2.25 MB | 97.6 ms (105.5 ms) | 51.8 ms (58.1 ms) | 984.3 ms (1.02 s) | 0.53× [0.52, 0.54] | 10.08× [9.91, 10.33] | 23.06 | 43.47 | 2.29 | 30 MB | 30 MB | 129 MB | 6.0/5.5/1.5 | 26 | NOISY |
| marine_ik | 2.98 MB | 125.4 ms (130.5 ms) | 74.4 ms (77.3 ms) | 1.05 s (1.06 s) | 0.59× [0.58, 0.60] | 8.35× [8.20, 8.42] | 23.80 | 40.11 | 2.85 | 37 MB | 37 MB | 125 MB | 2.1/2.9/1.1 | 24 | MEASURED |
| gsoc_2018 | 3.33 MB | 44.0 ms (49.1 ms) | 28.6 ms (32.9 ms) | 295.2 ms (299.2 ms) | 0.65× [0.64, 0.67] | 6.71× [6.62, 6.89] | 75.60 | 116.30 | 11.27 | 17 MB | 17 MB | 83 MB | 8.5/5.9/1.1 | 30 | NOISY |
| semanticscholar | 8.59 MB | 225.1 ms (241.8 ms) | 172.1 ms (195.0 ms) | 1.21 s (1.30 s) | 0.76× [0.70, 0.83] | 5.37× [5.08, 5.87] | 38.17 | 49.95 | 7.11 | 67 MB | 67 MB | 225 MB | 6.3/8.7/4.3 | 19 | NOISY |
| flights_200k | 9.86 MB | 380.5 ms (392.4 ms) | 249.1 ms (268.6 ms) | 3.99 s (4.10 s) | 0.65× [0.63, 0.69] | 10.48× [10.25, 10.69] | 25.92 | 39.60 | 2.47 | 122 MB | 122 MB | 288 MB | 1.8/4.6/1.2 | 6 | MEASURED |
| openapi_github | 13.01 MB | 310.1 ms (341.8 ms) | 231.0 ms (263.4 ms) | 1.67 s (1.74 s) | 0.75× [0.73, 0.77] | 5.39× [5.32, 5.48] | 41.96 | 56.32 | 7.79 | 89 MB | 89 MB | 317 MB | 3.2/4.5/1.4 | 13 | MEASURED |
| semsch_625 | 0.98 MB | 20.9 ms (23.1 ms) | 15.5 ms (18.5 ms) | 121.3 ms (132.7 ms) | 0.74× [0.71, 0.78] | 5.82× [5.72, 5.99] | 47.02 | 63.35 | 8.08 | 10 MB | 10 MB | 28 MB | 6.5/10.4/3.9 | 30 | NOISY |
| semsch_1250 | 2.10 MB | 45.0 ms (51.2 ms) | 33.1 ms (36.9 ms) | 271.0 ms (277.9 ms) | 0.73× [0.71, 0.76] | 6.02× [5.91, 6.25] | 46.55 | 63.35 | 7.73 | 18 MB | 19 MB | 57 MB | 5.8/5.7/1.4 | 30 | NOISY |
| semsch_2500 | 4.27 MB | 96.2 ms (109.3 ms) | 70.2 ms (73.5 ms) | 560.2 ms (574.1 ms) | 0.73× [0.71, 0.74] | 5.82× [5.67, 5.88] | 44.33 | 60.80 | 7.62 | 34 MB | 35 MB | 113 MB | 5.5/3.1/1.2 | 30 | NOISY |
| semsch_5000 | 8.59 MB | 201.5 ms (209.1 ms) | 151.0 ms (167.3 ms) | 1.14 s (1.15 s) | 0.75× [0.73, 0.76] | 5.64× [5.52, 5.70] | 42.63 | 56.86 | 7.56 | 67 MB | 67 MB | 224 MB | 2.0/3.4/0.7 | 19 | MEASURED |

## encode_stdin

| document | input | rust_z median (p95) | rust_o3 median (p95) | bend median (p95) | rust_o3/rust_z [95% CI] | bend/rust_z [95% CI] | rust_z MB/s | rust_o3 MB/s | bend MB/s | rust_z peak RSS | rust_o3 peak RSS | bend peak RSS | cv % (rust_z/rust_o3/bend) | n | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| github_events | 0.07 MB | 2.37 ms (2.62 ms) | 1.99 ms (2.25 ms) | 7.63 ms (7.93 ms) | 0.84× [0.82, 0.86] | 3.22× [3.16, 3.29] | 27.48 | 32.76 | 8.54 | 3 MB | 3 MB | 5 MB | 4.2/6.9/3.1 | 30 | NOISY |
| apache_builds | 0.13 MB | 3.22 ms (3.76 ms) | 2.68 ms (2.83 ms) | 15.6 ms (16.3 ms) | 0.83× [0.80, 0.87] | 4.85× [4.77, 5.01] | 39.50 | 47.43 | 8.15 | 3 MB | 4 MB | 7 MB | 7.6/4.6/3.5 | 30 | NOISY |
| numbers | 0.15 MB | 6.00 ms (6.38 ms) | 3.58 ms (3.75 ms) | 71.6 ms (76.9 ms) | 0.60× [0.59, 0.61] | 11.93× [11.74, 12.20] | 25.01 | 41.88 | 2.10 | 4 MB | 4 MB | 8 MB | 3.7/3.3/3.0 | 30 | MEASURED |
| flights_2k | 0.18 MB | 7.10 ms (8.04 ms) | 5.23 ms (5.90 ms) | 34.0 ms (35.7 ms) | 0.74× [0.72, 0.77] | 4.79× [4.70, 4.97] | 25.13 | 34.10 | 5.25 | 5 MB | 5 MB | 8 MB | 6.4/4.9/2.5 | 30 | NOISY |
| unemployment | 0.19 MB | 7.16 ms (7.87 ms) | 5.34 ms (6.08 ms) | 41.9 ms (45.0 ms) | 0.75× [0.73, 0.77] | 5.85× [5.75, 5.98] | 25.93 | 34.79 | 4.43 | 5 MB | 5 MB | 9 MB | 4.1/5.9/3.5 | 30 | NOISY |
| instruments | 0.22 MB | 5.48 ms (6.10 ms) | 4.31 ms (4.90 ms) | 26.5 ms (33.0 ms) | 0.79× [0.76, 0.82] | 4.83× [4.67, 5.08] | 40.18 | 51.08 | 8.32 | 4 MB | 4 MB | 9 MB | 6.4/10.8/11.0 | 30 | NOISY |
| npm_cli_lock | 0.44 MB | 12.0 ms (17.0 ms) | 9.45 ms (10.7 ms) | 49.7 ms (52.5 ms) | 0.79× [0.77, 0.81] | 4.16× [4.06, 4.21] | 36.58 | 46.29 | 8.80 | 6 MB | 6 MB | 14 MB | 10.6/4.6/4.2 | 30 | NOISY |
| flights_5k | 0.45 MB | 16.2 ms (18.0 ms) | 11.8 ms (13.1 ms) | 90.0 ms (95.7 ms) | 0.73× [0.70, 0.74] | 5.55× [5.33, 5.64] | 27.50 | 37.87 | 4.96 | 9 MB | 9 MB | 15 MB | 5.1/9.1/3.1 | 30 | NOISY |
| random | 0.51 MB | 14.8 ms (18.5 ms) | 11.1 ms (12.5 ms) | 85.3 ms (98.4 ms) | 0.75× [0.71, 0.77] | 5.74× [5.44, 5.97] | 34.38 | 45.86 | 5.99 | 8 MB | 8 MB | 16 MB | 9.0/5.5/6.9 | 30 | NOISY |
| update_center | 0.53 MB | 16.1 ms (17.4 ms) | 12.1 ms (13.4 ms) | 76.4 ms (85.7 ms) | 0.75× [0.73, 0.77] | 4.74× [4.62, 4.91] | 33.11 | 44.15 | 6.98 | 8 MB | 8 MB | 18 MB | 5.3/4.9/5.7 | 30 | NOISY |
| twitterescaped | 0.56 MB | 13.1 ms (14.6 ms) | 9.37 ms (10.7 ms) | 66.2 ms (73.2 ms) | 0.72× [0.70, 0.75] | 5.06× [4.93, 5.24] | 42.98 | 60.00 | 8.50 | 7 MB | 7 MB | 17 MB | 5.4/7.6/4.0 | 30 | NOISY |
| twitter | 0.63 MB | 13.0 ms (14.6 ms) | 9.39 ms (10.2 ms) | 71.3 ms (74.8 ms) | 0.72× [0.70, 0.75] | 5.49× [5.32, 5.59] | 48.64 | 67.27 | 8.86 | 7 MB | 7 MB | 19 MB | 5.0/4.7/2.9 | 30 | NOISY |
| us_10m | 0.64 MB | 68.3 ms (72.2 ms) | 44.9 ms (47.9 ms) | 187.9 ms (195.1 ms) | 0.66× [0.64, 0.68] | 2.75× [2.70, 2.83] | 9.40 | 14.30 | 3.42 | 25 MB | 25 MB | 36 MB | 5.1/4.0/3.3 | 30 | NOISY |
| mesh | 0.72 MB | 30.2 ms (32.6 ms) | 15.9 ms (17.7 ms) | 283.8 ms (300.9 ms) | 0.53× [0.52, 0.54] | 9.41× [9.20, 9.60] | 23.98 | 45.63 | 2.55 | 11 MB | 11 MB | 25 MB | 4.3/5.6/3.0 | 30 | NOISY |
| vscode_lock | 0.78 MB | 17.3 ms (18.5 ms) | 13.3 ms (13.7 ms) | 88.6 ms (96.7 ms) | 0.77× [0.74, 0.78] | 5.12× [5.02, 5.21] | 45.15 | 58.96 | 8.82 | 8 MB | 8 MB | 22 MB | 3.0/2.6/4.5 | 30 | MEASURED |
| flights_10k | 0.89 MB | 31.2 ms (35.9 ms) | 22.2 ms (23.8 ms) | 182.0 ms (193.3 ms) | 0.71× [0.69, 0.75] | 5.83× [5.68, 6.01] | 28.58 | 40.19 | 4.90 | 15 MB | 15 MB | 27 MB | 6.4/4.3/2.5 | 30 | NOISY |
| jobs | 0.94 MB | 26.7 ms (28.8 ms) | 18.6 ms (20.4 ms) | 314.8 ms (327.3 ms) | 0.70× [0.67, 0.71] | 11.80× [11.57, 12.01] | 35.12 | 50.49 | 2.98 | 12 MB | 12 MB | 28 MB | 5.2/5.3/1.9 | 30 | NOISY |
| football | 1.21 MB | 21.5 ms (23.8 ms) | 16.3 ms (19.3 ms) | 192.7 ms (205.7 ms) | 0.76× [0.74, 0.77] | 8.95× [8.76, 9.05] | 56.11 | 73.91 | 6.27 | 11 MB | 12 MB | 33 MB | 6.0/7.3/2.9 | 30 | NOISY |
| earthquakes | 1.22 MB | 51.2 ms (61.3 ms) | 33.8 ms (43.3 ms) | 310.6 ms (326.0 ms) | 0.66× [0.64, 0.69] | 6.06× [5.98, 6.24] | 23.81 | 36.06 | 3.93 | 17 MB | 17 MB | 42 MB | 9.9/9.3/3.1 | 30 | NOISY |
| movies | 1.40 MB | 36.8 ms (89.1 ms) | 27.8 ms (85.9 ms) | 273.2 ms (499.4 ms) | 0.76× [0.62, 0.84] | 7.43× [6.14, 7.83] | 38.08 | 50.31 | 5.12 | 17 MB | 17 MB | 38 MB | 38.6/51.5/25.2 | 30 | NOISY |
| citm_catalog | 1.73 MB | 27.5 ms (51.7 ms) | 18.5 ms (27.0 ms) | 239.2 ms (403.6 ms) | 0.67× [0.53, 0.75] | 8.70× [6.88, 10.72] | 62.80 | 93.12 | 7.22 | 12 MB | 12 MB | 45 MB | 40.5/19.6/22.5 | 30 | NOISY |
| flights_20k | 1.78 MB | 75.0 ms (460.5 ms) | 52.3 ms (225.7 ms) | 406.1 ms (1.12 s) | 0.70× [0.46, 0.86] | 5.41× [3.56, 5.59] | 23.79 | 34.11 | 4.39 | 27 MB | 27 MB | 50 MB | 91.1/77.5/56.9 | 30 | NOISY |
| canada | 2.25 MB | 94.2 ms (103.7 ms) | 49.2 ms (52.9 ms) | 966.8 ms (1.00 s) | 0.52× [0.51, 0.53] | 10.26× [10.17, 10.37] | 23.90 | 45.72 | 2.33 | 30 MB | 30 MB | 129 MB | 5.2/4.1/2.2 | 26 | NOISY |
| marine_ik | 2.98 MB | 126.8 ms (132.3 ms) | 74.7 ms (77.6 ms) | 1.05 s (1.08 s) | 0.59× [0.58, 0.60] | 8.25× [8.13, 8.37] | 23.53 | 39.95 | 2.85 | 37 MB | 37 MB | 125 MB | 2.8/2.9/1.6 | 23 | MEASURED |
| gsoc_2018 | 3.33 MB | 44.8 ms (57.2 ms) | 30.2 ms (51.4 ms) | 296.3 ms (327.1 ms) | 0.67× [0.65, 0.69] | 6.61× [6.53, 6.71] | 74.26 | 110.35 | 11.23 | 17 MB | 17 MB | 83 MB | 18.2/18.1/4.6 | 30 | NOISY |
| semanticscholar | 8.59 MB | 205.3 ms (220.3 ms) | 153.0 ms (193.5 ms) | 1.15 s (1.19 s) | 0.75× [0.72, 0.77] | 5.59× [5.45, 5.69] | 41.86 | 56.17 | 7.48 | 67 MB | 67 MB | 224 MB | 3.2/7.1/1.3 | 16 | NOISY |
| flights_200k | 9.86 MB | 389.7 ms (402.7 ms) | 251.9 ms (266.5 ms) | 4.09 s (4.14 s) | 0.65× [0.60, 0.68] | 10.49× [10.25, 10.78] | 25.31 | 39.16 | 2.41 | 122 MB | 122 MB | 288 MB | 2.5/5.3/0.9 | 6 | NOISY |
| openapi_github | 13.01 MB | 309.6 ms (328.4 ms) | 240.7 ms (244.6 ms) | 1.68 s (1.72 s) | 0.78× [0.76, 0.79] | 5.43× [5.40, 5.52] | 42.02 | 54.07 | 7.74 | 89 MB | 89 MB | 317 MB | 2.4/2.3/1.1 | 13 | MEASURED |

## encode_fold

| document | input | rust_z median (p95) | rust_o3 median (p95) | bend median (p95) | rust_o3/rust_z [95% CI] | bend/rust_z [95% CI] | rust_z MB/s | rust_o3 MB/s | bend MB/s | rust_z peak RSS | rust_o3 peak RSS | bend peak RSS | cv % (rust_z/rust_o3/bend) | n | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| github_events | 0.07 MB | 2.53 ms (2.82 ms) | 2.15 ms (2.32 ms) | 9.54 ms (10.3 ms) | 0.85× [0.83, 0.86] | 3.76× [3.71, 3.82] | 25.70 | 30.24 | 6.83 | 3 MB | 3 MB | 5 MB | 5.0/3.8/4.3 | 30 | NOISY |
| apache_builds | 0.13 MB | 3.24 ms (4.26 ms) | 2.63 ms (2.85 ms) | 15.6 ms (16.4 ms) | 0.81× [0.77, 0.84] | 4.81× [4.66, 4.97] | 39.34 | 48.48 | 8.17 | 3 MB | 4 MB | 7 MB | 11.6/6.0/2.1 | 30 | NOISY |
| numbers | 0.15 MB | 6.02 ms (6.40 ms) | 3.57 ms (3.87 ms) | 71.1 ms (74.6 ms) | 0.59× [0.58, 0.61] | 11.80× [11.67, 12.13] | 24.92 | 42.06 | 2.11 | 4 MB | 4 MB | 8 MB | 3.9/6.6/2.4 | 30 | NOISY |
| flights_2k | 0.18 MB | 6.87 ms (7.24 ms) | 5.18 ms (5.78 ms) | 33.7 ms (35.1 ms) | 0.75× [0.73, 0.78] | 4.91× [4.79, 4.99] | 25.99 | 34.45 | 5.29 | 5 MB | 5 MB | 8 MB | 3.1/4.8/2.4 | 30 | MEASURED |
| unemployment | 0.19 MB | 7.30 ms (9.03 ms) | 5.22 ms (6.68 ms) | 41.5 ms (44.3 ms) | 0.71× [0.70, 0.74] | 5.68× [5.54, 5.88] | 25.42 | 35.59 | 4.47 | 5 MB | 5 MB | 9 MB | 8.8/8.3/2.8 | 30 | NOISY |
| instruments | 0.22 MB | 5.51 ms (7.48 ms) | 4.34 ms (4.64 ms) | 33.5 ms (37.9 ms) | 0.79× [0.76, 0.82] | 6.08× [5.96, 6.25] | 39.98 | 50.83 | 6.58 | 4 MB | 4 MB | 9 MB | 12.3/81.0/6.2 | 30 | NOISY |
| npm_cli_lock | 0.44 MB | 15.9 ms (16.8 ms) | 12.7 ms (13.1 ms) | 114.4 ms (126.3 ms) | 0.80× [0.79, 0.81] | 7.19× [7.02, 7.47] | 27.49 | 34.35 | 3.82 | 7 MB | 7 MB | 14 MB | 3.1/2.6/5.3 | 30 | NOISY |
| flights_5k | 0.45 MB | 15.8 ms (18.4 ms) | 11.7 ms (16.3 ms) | 89.6 ms (92.1 ms) | 0.74× [0.71, 0.76] | 5.66× [5.49, 5.78] | 28.17 | 38.28 | 4.98 | 9 MB | 9 MB | 15 MB | 6.0/29.8/2.5 | 30 | NOISY |
| random | 0.51 MB | 15.1 ms (17.0 ms) | 11.0 ms (12.7 ms) | 109.4 ms (121.2 ms) | 0.73× [0.71, 0.76] | 7.25× [7.00, 7.63] | 33.84 | 46.24 | 4.66 | 8 MB | 8 MB | 16 MB | 5.4/6.7/7.4 | 30 | NOISY |
| update_center | 0.53 MB | 20.9 ms (23.2 ms) | 16.3 ms (17.6 ms) | 115.8 ms (122.2 ms) | 0.78× [0.76, 0.80] | 5.53× [5.39, 5.67] | 25.48 | 32.79 | 4.60 | 10 MB | 10 MB | 18 MB | 8.1/5.0/3.5 | 30 | NOISY |
| twitterescaped | 0.56 MB | 14.7 ms (15.8 ms) | 11.1 ms (12.2 ms) | 112.9 ms (120.7 ms) | 0.75× [0.72, 0.77] | 7.67× [7.49, 7.90] | 38.21 | 50.85 | 4.98 | 7 MB | 7 MB | 17 MB | 5.0/6.4/3.8 | 30 | NOISY |
| twitter | 0.63 MB | 14.5 ms (15.1 ms) | 10.9 ms (11.5 ms) | 117.9 ms (127.3 ms) | 0.75× [0.73, 0.77] | 8.12× [7.92, 8.32] | 43.51 | 58.09 | 5.36 | 7 MB | 7 MB | 19 MB | 2.5/3.4/4.2 | 30 | MEASURED |
| us_10m | 0.64 MB | 73.6 ms (77.4 ms) | 49.0 ms (52.1 ms) | 199.8 ms (207.5 ms) | 0.67× [0.64, 0.68] | 2.71× [2.65, 2.75] | 8.73 | 13.10 | 3.22 | 27 MB | 27 MB | 36 MB | 3.1/5.2/2.5 | 30 | NOISY |
| mesh | 0.72 MB | 29.7 ms (33.2 ms) | 15.9 ms (16.9 ms) | 281.6 ms (291.4 ms) | 0.53× [0.53, 0.54] | 9.47× [9.36, 9.60] | 24.33 | 45.50 | 2.57 | 11 MB | 11 MB | 25 MB | 4.1/2.9/2.0 | 30 | MEASURED |
| vscode_lock | 0.78 MB | 22.8 ms (25.5 ms) | 18.3 ms (20.0 ms) | 189.0 ms (202.2 ms) | 0.80× [0.78, 0.82] | 8.28× [8.04, 8.51] | 34.27 | 42.83 | 4.14 | 10 MB | 10 MB | 22 MB | 4.5/4.6/4.1 | 30 | MEASURED |
| flights_10k | 0.89 MB | 32.5 ms (36.1 ms) | 22.5 ms (26.6 ms) | 185.0 ms (197.1 ms) | 0.69× [0.67, 0.71] | 5.69× [5.58, 5.83] | 27.45 | 39.71 | 4.82 | 15 MB | 15 MB | 27 MB | 9.9/9.1/2.6 | 30 | NOISY |
| jobs | 0.94 MB | 26.1 ms (28.2 ms) | 18.6 ms (20.1 ms) | 319.8 ms (342.3 ms) | 0.71× [0.68, 0.73] | 12.26× [11.83, 12.45] | 35.90 | 50.33 | 2.93 | 12 MB | 12 MB | 28 MB | 6.6/6.1/3.0 | 30 | NOISY |
| football | 1.21 MB | 21.8 ms (24.0 ms) | 16.6 ms (17.4 ms) | 194.7 ms (203.3 ms) | 0.76× [0.74, 0.77] | 8.93× [8.76, 9.05] | 55.37 | 72.85 | 6.20 | 11 MB | 12 MB | 33 MB | 4.0/3.9/2.9 | 30 | MEASURED |
| earthquakes | 1.22 MB | 54.5 ms (56.3 ms) | 37.9 ms (41.3 ms) | 419.5 ms (435.6 ms) | 0.70× [0.68, 0.71] | 7.70× [7.61, 7.83] | 22.40 | 32.20 | 2.91 | 17 MB | 17 MB | 43 MB | 2.3/4.2/1.8 | 30 | MEASURED |
| movies | 1.40 MB | 38.4 ms (55.0 ms) | 27.1 ms (30.4 ms) | 281.1 ms (302.9 ms) | 0.70× [0.67, 0.73] | 7.31× [6.96, 7.51] | 36.43 | 51.71 | 4.98 | 17 MB | 17 MB | 38 MB | 42.7/5.5/4.2 | 30 | NOISY |
| citm_catalog | 1.73 MB | 29.1 ms (74.0 ms) | 18.8 ms (59.2 ms) | 264.2 ms (955.4 ms) | 0.64× [0.46, 0.78] | 9.08× [6.65, 10.36] | 59.33 | 92.10 | 6.54 | 12 MB | 12 MB | 45 MB | 60.4/51.9/61.2 | 30 | NOISY |
| flights_20k | 1.78 MB | 83.6 ms (200.6 ms) | 65.1 ms (270.9 ms) | 426.3 ms (1.07 s) | 0.78× [0.50, 1.05] | 5.10× [3.78, 7.36] | 21.36 | 27.44 | 4.19 | 27 MB | 27 MB | 50 MB | 66.5/74.7/37.0 | 30 | NOISY |
| canada | 2.25 MB | 105.7 ms (118.4 ms) | 60.0 ms (62.0 ms) | 981.6 ms (1.03 s) | 0.57× [0.55, 0.57] | 9.29× [9.11, 9.41] | 21.30 | 37.49 | 2.29 | 37 MB | 37 MB | 129 MB | 5.2/2.8/2.1 | 26 | NOISY |
| marine_ik | 2.98 MB | 149.9 ms (173.7 ms) | 94.8 ms (104.3 ms) | 1.08 s (1.12 s) | 0.63× [0.61, 0.65] | 7.20× [7.03, 7.32] | 19.90 | 31.46 | 2.76 | 50 MB | 50 MB | 124 MB | 9.0/5.5/2.1 | 22 | NOISY |
| gsoc_2018 | 3.33 MB | 50.2 ms (98.4 ms) | 35.0 ms (46.9 ms) | 366.8 ms (574.3 ms) | 0.70× [0.67, 0.74] | 7.31× [7.04, 7.70] | 66.33 | 94.98 | 9.07 | 17 MB | 17 MB | 83 MB | 38.8/70.6/37.0 | 30 | NOISY |
| semanticscholar | 8.59 MB | 205.5 ms (222.8 ms) | 157.4 ms (172.6 ms) | 1.33 s (1.37 s) | 0.77× [0.73, 0.78] | 6.48× [6.30, 6.57] | 41.82 | 54.59 | 6.45 | 67 MB | 67 MB | 225 MB | 2.9/4.1/1.0 | 17 | MEASURED |
| flights_200k | 9.86 MB | 386.6 ms (393.3 ms) | 251.3 ms (266.9 ms) | 4.07 s (4.17 s) | 0.65× [0.63, 0.68] | 10.52× [10.20, 10.90] | 25.51 | 39.26 | 2.42 | 122 MB | 122 MB | 288 MB | 1.6/3.1/2.4 | 6 | MEASURED |
| openapi_github | 13.01 MB | 628.8 ms (646.3 ms) | 529.8 ms (534.4 ms) | 3.19 s (3.25 s) | 0.84× [0.82, 0.85] | 5.07× [4.95, 5.16] | 20.69 | 24.56 | 4.08 | 95 MB | 95 MB | 317 MB | 1.6/1.6/0.9 | 6 | MEASURED |

## encode_tab

| document | input | rust_z median (p95) | rust_o3 median (p95) | bend median (p95) | rust_o3/rust_z [95% CI] | bend/rust_z [95% CI] | rust_z MB/s | rust_o3 MB/s | bend MB/s | rust_z peak RSS | rust_o3 peak RSS | bend peak RSS | cv % (rust_z/rust_o3/bend) | n | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| github_events | 0.07 MB | 2.34 ms (2.58 ms) | 1.99 ms (2.19 ms) | 7.70 ms (8.42 ms) | 0.85× [0.83, 0.88] | 3.28× [3.23, 3.33] | 27.79 | 32.78 | 8.46 | 3 MB | 3 MB | 5 MB | 4.1/4.5/3.2 | 30 | MEASURED |
| apache_builds | 0.13 MB | 3.21 ms (3.48 ms) | 2.53 ms (2.83 ms) | 15.5 ms (16.1 ms) | 0.79× [0.77, 0.82] | 4.83× [4.78, 5.02] | 39.61 | 50.29 | 8.19 | 3 MB | 4 MB | 7 MB | 5.9/5.1/1.9 | 30 | NOISY |
| numbers | 0.15 MB | 5.98 ms (6.78 ms) | 3.56 ms (4.48 ms) | 71.8 ms (74.9 ms) | 0.60× [0.58, 0.61] | 12.01× [11.77, 12.22] | 25.12 | 42.21 | 2.09 | 4 MB | 4 MB | 8 MB | 5.2/9.6/2.0 | 30 | NOISY |
| flights_2k | 0.18 MB | 7.12 ms (8.09 ms) | 5.46 ms (5.94 ms) | 34.1 ms (41.1 ms) | 0.77× [0.74, 0.79] | 4.79× [4.66, 4.96] | 25.06 | 32.70 | 5.24 | 5 MB | 5 MB | 8 MB | 6.6/4.9/6.5 | 30 | NOISY |
| unemployment | 0.19 MB | 7.23 ms (9.38 ms) | 5.25 ms (6.74 ms) | 41.6 ms (47.9 ms) | 0.73× [0.71, 0.75] | 5.75× [5.62, 5.89] | 25.68 | 35.37 | 4.47 | 5 MB | 5 MB | 9 MB | 57.4/40.2/5.1 | 30 | NOISY |
| instruments | 0.22 MB | 5.38 ms (5.80 ms) | 4.20 ms (4.51 ms) | 26.4 ms (28.4 ms) | 0.78× [0.76, 0.80] | 4.89× [4.79, 4.98] | 40.92 | 52.41 | 8.36 | 4 MB | 4 MB | 9 MB | 5.6/4.2/6.6 | 30 | NOISY |
| npm_cli_lock | 0.44 MB | 12.2 ms (15.3 ms) | 9.44 ms (10.6 ms) | 50.8 ms (56.8 ms) | 0.78× [0.75, 0.80] | 4.17× [4.02, 4.27] | 35.92 | 46.32 | 8.62 | 6 MB | 6 MB | 14 MB | 10.0/7.4/7.2 | 30 | NOISY |
| flights_5k | 0.45 MB | 16.5 ms (18.4 ms) | 12.0 ms (14.2 ms) | 91.4 ms (95.1 ms) | 0.73× [0.71, 0.75] | 5.54× [5.41, 5.72] | 27.03 | 37.11 | 4.88 | 9 MB | 9 MB | 15 MB | 7.0/8.3/3.1 | 30 | NOISY |
| random | 0.51 MB | 14.9 ms (17.4 ms) | 10.9 ms (12.4 ms) | 87.6 ms (96.3 ms) | 0.73× [0.71, 0.76] | 5.87× [5.62, 6.11] | 34.20 | 46.70 | 5.82 | 8 MB | 8 MB | 16 MB | 6.3/7.2/9.6 | 30 | NOISY |
| update_center | 0.53 MB | 15.8 ms (17.2 ms) | 12.0 ms (13.8 ms) | 74.5 ms (81.0 ms) | 0.76× [0.74, 0.80] | 4.70× [4.58, 4.86] | 33.65 | 44.43 | 7.15 | 8 MB | 8 MB | 18 MB | 4.1/6.6/4.6 | 30 | NOISY |
| twitterescaped | 0.56 MB | 13.2 ms (16.0 ms) | 9.61 ms (10.5 ms) | 67.4 ms (75.0 ms) | 0.73× [0.70, 0.75] | 5.10× [4.95, 5.26] | 42.57 | 58.52 | 8.34 | 7 MB | 7 MB | 17 MB | 6.8/5.2/5.8 | 30 | NOISY |
| twitter | 0.63 MB | 12.7 ms (14.7 ms) | 9.52 ms (10.2 ms) | 69.2 ms (76.0 ms) | 0.75× [0.72, 0.77] | 5.46× [5.24, 5.63] | 49.88 | 66.32 | 9.13 | 7 MB | 7 MB | 19 MB | 5.5/3.7/3.8 | 30 | NOISY |
| us_10m | 0.64 MB | 68.0 ms (73.1 ms) | 44.6 ms (49.0 ms) | 189.3 ms (197.6 ms) | 0.66× [0.64, 0.67] | 2.78× [2.73, 2.81] | 9.45 | 14.39 | 3.39 | 25 MB | 25 MB | 38 MB | 3.5/4.4/2.2 | 30 | MEASURED |
| mesh | 0.72 MB | 29.7 ms (33.1 ms) | 15.9 ms (16.8 ms) | 282.6 ms (291.3 ms) | 0.54× [0.52, 0.54] | 9.52× [9.38, 9.63] | 24.37 | 45.47 | 2.56 | 11 MB | 11 MB | 25 MB | 4.2/2.7/1.6 | 30 | MEASURED |
| vscode_lock | 0.78 MB | 17.4 ms (18.4 ms) | 13.3 ms (15.1 ms) | 87.4 ms (95.0 ms) | 0.76× [0.75, 0.78] | 5.02× [4.90, 5.16] | 44.86 | 58.74 | 8.94 | 8 MB | 8 MB | 22 MB | 3.2/6.4/4.2 | 30 | NOISY |
| flights_10k | 0.89 MB | 33.3 ms (35.5 ms) | 22.9 ms (24.9 ms) | 187.8 ms (197.3 ms) | 0.69× [0.68, 0.71] | 5.64× [5.56, 5.81] | 26.81 | 38.92 | 4.75 | 15 MB | 15 MB | 26 MB | 4.6/4.7/3.4 | 30 | MEASURED |
| jobs | 0.94 MB | 26.5 ms (28.5 ms) | 18.1 ms (20.0 ms) | 317.2 ms (329.3 ms) | 0.68× [0.66, 0.70] | 11.95× [11.63, 12.28] | 35.30 | 51.66 | 2.95 | 12 MB | 12 MB | 28 MB | 4.0/5.3/2.8 | 30 | NOISY |
| football | 1.21 MB | 21.9 ms (29.1 ms) | 16.6 ms (17.6 ms) | 195.2 ms (204.3 ms) | 0.76× [0.73, 0.77] | 8.92× [8.58, 9.11] | 55.16 | 72.93 | 6.18 | 11 MB | 12 MB | 33 MB | 10.4/3.9/3.0 | 30 | NOISY |
| earthquakes | 1.22 MB | 46.5 ms (56.3 ms) | 32.5 ms (38.5 ms) | 307.6 ms (315.1 ms) | 0.70× [0.67, 0.71] | 6.62× [6.44, 6.75] | 26.24 | 37.58 | 3.97 | 17 MB | 17 MB | 42 MB | 8.2/7.1/1.5 | 30 | NOISY |
| movies | 1.40 MB | 35.7 ms (40.4 ms) | 25.8 ms (29.5 ms) | 272.3 ms (287.0 ms) | 0.72× [0.69, 0.74] | 7.62× [7.38, 7.72] | 39.19 | 54.18 | 5.14 | 17 MB | 17 MB | 39 MB | 7.9/5.7/2.3 | 30 | NOISY |
| citm_catalog | 1.73 MB | 28.4 ms (73.7 ms) | 19.8 ms (66.4 ms) | 248.4 ms (442.1 ms) | 0.70× [0.64, 0.86] | 8.73× [8.20, 9.35] | 60.73 | 87.26 | 6.95 | 12 MB | 12 MB | 45 MB | 52.0/83.1/61.1 | 30 | NOISY |
| flights_20k | 1.78 MB | 75.5 ms (131.1 ms) | 51.1 ms (81.7 ms) | 408.8 ms (1.28 s) | 0.68× [0.62, 0.72] | 5.41× [4.98, 5.79] | 23.64 | 34.93 | 4.37 | 27 MB | 27 MB | 50 MB | 51.9/73.9/53.6 | 30 | NOISY |
| canada | 2.25 MB | 94.4 ms (99.4 ms) | 50.2 ms (56.1 ms) | 969.2 ms (1.00 s) | 0.53× [0.52, 0.54] | 10.26× [10.03, 10.41] | 23.84 | 44.89 | 2.32 | 30 MB | 30 MB | 131 MB | 3.5/5.7/1.5 | 26 | NOISY |
| marine_ik | 2.98 MB | 131.8 ms (174.2 ms) | 77.0 ms (98.6 ms) | 1.12 s (1.49 s) | 0.58× [0.54, 0.61] | 8.50× [7.83, 9.03] | 22.63 | 38.75 | 2.66 | 37 MB | 37 MB | 125 MB | 15.2/15.0/12.4 | 21 | NOISY |
| gsoc_2018 | 3.33 MB | 44.1 ms (52.0 ms) | 30.4 ms (43.3 ms) | 308.5 ms (341.2 ms) | 0.69× [0.64, 0.74] | 7.00× [6.61, 7.20] | 75.51 | 109.48 | 10.79 | 17 MB | 17 MB | 83 MB | 10.1/16.8/4.3 | 30 | NOISY |
| semanticscholar | 8.59 MB | 193.5 ms (210.4 ms) | 145.3 ms (161.4 ms) | 1.16 s (1.19 s) | 0.75× [0.72, 0.77] | 5.97× [5.77, 6.10] | 44.40 | 59.14 | 7.43 | 67 MB | 67 MB | 226 MB | 3.6/4.0/1.2 | 19 | MEASURED |
| flights_200k | 9.86 MB | 383.3 ms (458.1 ms) | 243.3 ms (439.8 ms) | 4.01 s (4.32 s) | 0.63× [0.57, 0.91] | 10.47× [9.48, 10.93] | 25.74 | 40.55 | 2.46 | 122 MB | 122 MB | 288 MB | 8.0/29.0/3.4 | 6 | NOISY |
| openapi_github | 13.01 MB | 307.6 ms (332.0 ms) | 233.7 ms (241.6 ms) | 1.67 s (1.72 s) | 0.76× [0.75, 0.78] | 5.44× [5.36, 5.55] | 42.30 | 55.67 | 7.78 | 89 MB | 89 MB | 317 MB | 2.8/1.6/1.0 | 13 | MEASURED |

## encode_stats

| document | input | rust_z median (p95) | rust_o3 median (p95) | bend median (p95) | rust_o3/rust_z [95% CI] | bend/rust_z [95% CI] | rust_z MB/s | rust_o3 MB/s | bend MB/s | rust_z peak RSS | rust_o3 peak RSS | bend peak RSS | cv % (rust_z/rust_o3/bend) | n | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| github_events | 0.07 MB | 3.69 ms (3.93 ms) | 2.37 ms (2.83 ms) | 11.0 ms (12.3 ms) | 0.64× [0.62, 0.66] | 2.98× [2.93, 3.10] | 17.67 | 27.54 | 5.93 | 3 MB | 3 MB | 6 MB | 4.9/7.6/6.4 | 30 | NOISY |
| apache_builds | 0.13 MB | 4.93 ms (5.26 ms) | 3.06 ms (3.26 ms) | 21.7 ms (22.6 ms) | 0.62× [0.60, 0.63] | 4.41× [4.35, 4.47] | 25.81 | 41.60 | 5.86 | 3 MB | 4 MB | 10 MB | 9.5/4.0/2.8 | 30 | NOISY |
| numbers | 0.15 MB | 8.29 ms (9.85 ms) | 3.99 ms (4.50 ms) | 78.5 ms (82.7 ms) | 0.48× [0.47, 0.49] | 9.48× [9.33, 9.60] | 18.11 | 37.61 | 1.91 | 4 MB | 4 MB | 11 MB | 6.7/6.2/2.3 | 30 | NOISY |
| flights_2k | 0.18 MB | 9.14 ms (10.8 ms) | 5.83 ms (7.05 ms) | 43.3 ms (54.5 ms) | 0.64× [0.62, 0.66] | 4.74× [4.62, 4.89] | 19.53 | 30.60 | 4.12 | 5 MB | 5 MB | 12 MB | 6.2/8.3/7.8 | 30 | NOISY |
| unemployment | 0.19 MB | 9.57 ms (11.7 ms) | 5.72 ms (8.34 ms) | 51.1 ms (70.0 ms) | 0.60× [0.59, 0.62] | 5.34× [5.24, 5.44] | 19.41 | 32.47 | 3.63 | 5 MB | 5 MB | 13 MB | 7.1/13.7/11.4 | 30 | NOISY |
| instruments | 0.22 MB | 8.50 ms (10.4 ms) | 4.82 ms (5.06 ms) | 37.4 ms (39.9 ms) | 0.57× [0.55, 0.58] | 4.40× [4.35, 4.49] | 25.94 | 45.73 | 5.90 | 4 MB | 5 MB | 14 MB | 7.7/5.0/8.1 | 30 | NOISY |
| npm_cli_lock | 0.44 MB | 19.2 ms (21.6 ms) | 11.1 ms (11.9 ms) | 76.5 ms (81.3 ms) | 0.58× [0.56, 0.59] | 3.99× [3.88, 4.04] | 22.79 | 39.34 | 5.72 | 6 MB | 6 MB | 24 MB | 4.7/3.9/2.5 | 30 | MEASURED |
| flights_5k | 0.45 MB | 21.3 ms (23.9 ms) | 13.0 ms (14.0 ms) | 114.1 ms (119.7 ms) | 0.61× [0.58, 0.63] | 5.35× [5.19, 5.44] | 20.91 | 34.29 | 3.91 | 9 MB | 9 MB | 25 MB | 4.7/5.2/1.8 | 30 | NOISY |
| random | 0.51 MB | 24.2 ms (26.0 ms) | 13.1 ms (14.4 ms) | 124.9 ms (146.4 ms) | 0.54× [0.52, 0.57] | 5.17× [5.02, 5.43] | 21.12 | 39.08 | 4.09 | 8 MB | 8 MB | 26 MB | 4.1/6.0/6.5 | 30 | NOISY |
| update_center | 0.53 MB | 26.9 ms (30.2 ms) | 14.7 ms (15.8 ms) | 115.7 ms (122.8 ms) | 0.55× [0.54, 0.57] | 4.31× [4.19, 4.42] | 19.85 | 36.18 | 4.61 | 8 MB | 8 MB | 30 MB | 4.7/4.6/4.2 | 30 | MEASURED |
| twitterescaped | 0.56 MB | 23.0 ms (26.6 ms) | 11.6 ms (13.6 ms) | 105.7 ms (114.0 ms) | 0.50× [0.49, 0.51] | 4.60× [4.53, 4.65] | 24.47 | 48.50 | 5.32 | 7 MB | 7 MB | 30 MB | 4.8/11.4/3.3 | 30 | NOISY |
| twitter | 0.63 MB | 23.8 ms (25.0 ms) | 11.5 ms (12.9 ms) | 106.3 ms (113.4 ms) | 0.48× [0.48, 0.50] | 4.46× [4.34, 4.57] | 26.50 | 54.76 | 5.94 | 7 MB | 7 MB | 32 MB | 2.8/7.3/4.7 | 30 | NOISY |
| us_10m | 0.64 MB | 85.8 ms (91.4 ms) | 48.6 ms (52.6 ms) | 235.9 ms (252.0 ms) | 0.57× [0.56, 0.58] | 2.75× [2.70, 2.80] | 7.49 | 13.22 | 2.72 | 25 MB | 25 MB | 51 MB | 4.4/4.5/3.2 | 30 | MEASURED |
| mesh | 0.72 MB | 40.7 ms (42.2 ms) | 17.9 ms (18.4 ms) | 319.5 ms (324.8 ms) | 0.44× [0.43, 0.44] | 7.84× [7.77, 7.89] | 17.76 | 40.51 | 2.26 | 11 MB | 11 MB | 42 MB | 1.8/1.7/1.1 | 30 | MEASURED |
| vscode_lock | 0.78 MB | 29.8 ms (32.2 ms) | 15.8 ms (17.2 ms) | 137.4 ms (144.7 ms) | 0.53× [0.52, 0.54] | 4.61× [4.51, 4.65] | 26.21 | 49.41 | 5.69 | 8 MB | 8 MB | 40 MB | 3.5/3.8/2.6 | 30 | MEASURED |
| flights_10k | 0.89 MB | 43.1 ms (46.3 ms) | 25.5 ms (28.2 ms) | 239.5 ms (250.8 ms) | 0.59× [0.58, 0.60] | 5.55× [5.44, 5.60] | 20.70 | 35.00 | 3.73 | 15 MB | 15 MB | 47 MB | 3.5/4.6/1.8 | 30 | MEASURED |
| jobs | 0.94 MB | 38.4 ms (42.5 ms) | 21.1 ms (23.0 ms) | 393.0 ms (409.2 ms) | 0.55× [0.53, 0.57] | 10.23× [9.93, 10.54] | 24.38 | 44.42 | 2.38 | 12 MB | 12 MB | 49 MB | 4.9/4.9/1.9 | 30 | MEASURED |
| football | 1.21 MB | 37.0 ms (40.6 ms) | 18.9 ms (21.4 ms) | 266.6 ms (277.3 ms) | 0.51× [0.50, 0.52] | 7.21× [7.03, 7.34] | 32.65 | 63.73 | 4.53 | 11 MB | 12 MB | 61 MB | 6.0/4.1/2.2 | 30 | NOISY |
| earthquakes | 1.22 MB | 75.7 ms (94.9 ms) | 39.6 ms (53.0 ms) | 408.2 ms (459.7 ms) | 0.52× [0.51, 0.55] | 5.39× [5.25, 5.52] | 16.12 | 30.78 | 2.99 | 17 MB | 17 MB | 70 MB | 8.6/12.8/4.5 | 30 | NOISY |
| movies | 1.40 MB | 56.7 ms (65.9 ms) | 29.7 ms (35.7 ms) | 352.5 ms (368.2 ms) | 0.52× [0.51, 0.54] | 6.22× [6.13, 6.43] | 24.71 | 47.14 | 3.97 | 17 MB | 17 MB | 70 MB | 7.0/7.6/2.0 | 30 | NOISY |
| citm_catalog | 1.73 MB | 49.6 ms (95.5 ms) | 23.6 ms (167.9 ms) | 350.4 ms (1.05 s) | 0.48× [0.43, 0.58] | 7.06× [6.73, 7.41] | 34.80 | 73.25 | 4.93 | 12 MB | 12 MB | 85 MB | 69.3/111.3/66.7 | 30 | NOISY |
| flights_20k | 1.78 MB | 97.4 ms (152.3 ms) | 59.8 ms (92.2 ms) | 516.5 ms (686.0 ms) | 0.61× [0.56, 0.65] | 5.30× [4.95, 5.55] | 18.33 | 29.83 | 3.46 | 27 MB | 27 MB | 91 MB | 39.0/48.8/33.7 | 30 | NOISY |
| canada | 2.25 MB | 134.7 ms (141.5 ms) | 55.9 ms (58.5 ms) | 1.09 s (1.10 s) | 0.41× [0.40, 0.42] | 8.11× [8.01, 8.23] | 16.71 | 40.30 | 2.06 | 30 MB | 30 MB | 181 MB | 2.5/3.3/0.7 | 23 | MEASURED |
| marine_ik | 2.98 MB | 177.5 ms (429.4 ms) | 84.6 ms (134.3 ms) | 1.23 s (2.17 s) | 0.48× [0.47, 0.49] | 6.93× [6.80, 7.31] | 16.80 | 35.25 | 2.43 | 37 MB | 37 MB | 193 MB | 32.2/14.3/17.3 | 18 | NOISY |
| gsoc_2018 | 3.33 MB | 118.3 ms (133.8 ms) | 53.8 ms (64.2 ms) | 490.2 ms (519.6 ms) | 0.45× [0.44, 0.47] | 4.14× [4.06, 4.21] | 28.13 | 61.87 | 6.79 | 17 MB | 17 MB | 159 MB | 5.6/7.5/2.6 | 30 | NOISY |
| semanticscholar | 8.59 MB | 385.5 ms (401.1 ms) | 196.4 ms (215.8 ms) | 1.69 s (1.72 s) | 0.51× [0.49, 0.53] | 4.38× [4.29, 4.41] | 22.29 | 43.75 | 5.08 | 67 MB | 67 MB | 419 MB | 1.7/4.1/1.1 | 13 | MEASURED |
| flights_200k | 9.86 MB | 501.3 ms (549.1 ms) | 266.9 ms (280.3 ms) | 4.80 s (4.94 s) | 0.53× [0.49, 0.56] | 9.58× [8.74, 9.84] | 19.68 | 36.96 | 2.05 | 121 MB | 122 MB | 514 MB | 4.5/3.3/2.2 | 5 | MEASURED |
| openapi_github | 13.01 MB | 530.4 ms (538.4 ms) | 287.7 ms (307.4 ms) | 2.49 s (2.51 s) | 0.54× [0.53, 0.56] | 4.70× [4.65, 4.78] | 24.53 | 45.24 | 5.22 | 89 MB | 89 MB | 615 MB | 1.5/3.6/0.6 | 8 | MEASURED |

## decode

| document | input | rust_z median (p95) | rust_o3 median (p95) | bend median (p95) | rust_o3/rust_z [95% CI] | bend/rust_z [95% CI] | rust_z MB/s | rust_o3 MB/s | bend MB/s | rust_z peak RSS | rust_o3 peak RSS | bend peak RSS | cv % (rust_z/rust_o3/bend) | n | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| github_events | 0.06 MB | 2.68 ms (2.88 ms) | 2.13 ms (2.30 ms) | 10.5 ms (11.8 ms) | 0.80× [0.77, 0.82] | 3.91× [3.84, 4.00] | 22.12 | 27.83 | 5.65 | 3 MB | 3 MB | 6 MB | 4.3/4.8/4.6 | 30 | MEASURED |
| apache_builds | 0.07 MB | 4.26 ms (4.92 ms) | 2.84 ms (3.23 ms) | 12.3 ms (12.8 ms) | 0.67× [0.65, 0.69] | 2.88× [2.81, 2.91] | 17.08 | 25.61 | 5.93 | 3 MB | 4 MB | 7 MB | 6.9/5.4/1.9 | 30 | NOISY |
| numbers | 0.15 MB | 12.0 ms (12.8 ms) | 5.99 ms (6.36 ms) | 83.4 ms (86.5 ms) | 0.50× [0.49, 0.51] | 6.97× [6.88, 7.05] | 12.54 | 25.08 | 1.80 | 5 MB | 5 MB | 11 MB | 2.9/3.4/2.8 | 30 | MEASURED |
| flights_2k | 0.07 MB | 10.1 ms (10.6 ms) | 6.50 ms (7.06 ms) | 21.4 ms (23.1 ms) | 0.64× [0.63, 0.65] | 2.11× [2.09, 2.14] | 7.17 | 11.16 | 3.39 | 6 MB | 6 MB | 10 MB | 2.8/4.2/3.0 | 30 | MEASURED |
| unemployment | 0.10 MB | 11.0 ms (11.3 ms) | 6.61 ms (7.82 ms) | 30.3 ms (33.1 ms) | 0.60× [0.59, 0.61] | 2.76× [2.74, 2.81] | 9.43 | 15.69 | 3.42 | 5 MB | 5 MB | 10 MB | 1.8/5.5/5.2 | 30 | NOISY |
| instruments | 0.11 MB | 7.65 ms (8.31 ms) | 5.36 ms (5.55 ms) | 27.2 ms (29.7 ms) | 0.70× [0.69, 0.71] | 3.55× [3.50, 3.61] | 14.04 | 20.02 | 3.95 | 4 MB | 5 MB | 9 MB | 3.9/6.4/3.7 | 30 | NOISY |
| npm_cli_lock | 0.34 MB | 14.5 ms (15.9 ms) | 10.4 ms (11.1 ms) | 71.0 ms (74.4 ms) | 0.72× [0.70, 0.72] | 4.90× [4.81, 4.98] | 23.61 | 33.01 | 4.82 | 7 MB | 7 MB | 20 MB | 4.9/3.2/2.3 | 30 | MEASURED |
| flights_5k | 0.18 MB | 23.2 ms (24.9 ms) | 14.2 ms (16.8 ms) | 52.3 ms (57.9 ms) | 0.61× [0.60, 0.62] | 2.25× [2.20, 2.30] | 7.80 | 12.76 | 3.46 | 10 MB | 10 MB | 19 MB | 4.8/5.3/4.2 | 30 | NOISY |
| random | 0.44 MB | 21.8 ms (24.1 ms) | 13.8 ms (14.1 ms) | 91.9 ms (100.2 ms) | 0.63× [0.62, 0.64] | 4.22× [4.10, 4.31] | 20.04 | 31.63 | 4.75 | 8 MB | 9 MB | 24 MB | 4.0/3.3/4.1 | 30 | MEASURED |
| update_center | 0.55 MB | 20.3 ms (22.2 ms) | 13.6 ms (15.9 ms) | 109.1 ms (117.2 ms) | 0.67× [0.66, 0.69] | 5.39× [5.28, 5.50] | 27.02 | 40.34 | 5.02 | 8 MB | 8 MB | 30 MB | 4.8/6.9/3.8 | 30 | NOISY |
| twitterescaped | 0.54 MB | 17.7 ms (19.0 ms) | 12.1 ms (12.8 ms) | 99.6 ms (115.8 ms) | 0.68× [0.67, 0.69] | 5.62× [5.53, 5.76] | 30.22 | 44.34 | 5.38 | 8 MB | 8 MB | 27 MB | 5.8/4.1/4.9 | 30 | NOISY |
| twitter | 0.54 MB | 17.5 ms (18.6 ms) | 11.8 ms (12.6 ms) | 96.0 ms (100.7 ms) | 0.67× [0.67, 0.68] | 5.48× [5.40, 5.56] | 30.56 | 45.41 | 5.58 | 8 MB | 8 MB | 27 MB | 3.3/2.9/2.7 | 30 | MEASURED |
| us_10m | 1.13 MB | 115.3 ms (128.5 ms) | 60.2 ms (65.1 ms) | 384.9 ms (398.2 ms) | 0.52× [0.51, 0.54] | 3.34× [3.29, 3.39] | 9.82 | 18.81 | 2.94 | 29 MB | 30 MB | 65 MB | 3.9/3.9/2.2 | 30 | MEASURED |
| mesh | 0.67 MB | 58.4 ms (61.4 ms) | 26.5 ms (28.3 ms) | 336.5 ms (346.4 ms) | 0.45× [0.45, 0.46] | 5.76× [5.70, 5.85] | 11.44 | 25.23 | 1.98 | 13 MB | 13 MB | 37 MB | 6.4/2.8/1.6 | 30 | NOISY |
| vscode_lock | 0.65 MB | 20.5 ms (21.3 ms) | 14.2 ms (14.9 ms) | 129.5 ms (141.2 ms) | 0.70× [0.68, 0.70] | 6.32× [6.14, 6.47] | 31.75 | 45.67 | 5.02 | 9 MB | 9 MB | 34 MB | 2.1/2.6/4.9 | 30 | MEASURED |
| flights_10k | 0.36 MB | 45.0 ms (46.9 ms) | 27.2 ms (28.1 ms) | 108.2 ms (115.1 ms) | 0.60× [0.60, 0.61] | 2.40× [2.36, 2.43] | 8.05 | 13.33 | 3.35 | 17 MB | 17 MB | 35 MB | 1.9/2.8/3.1 | 30 | MEASURED |
| jobs | 0.37 MB | 40.7 ms (44.7 ms) | 22.9 ms (25.8 ms) | 258.7 ms (273.2 ms) | 0.56× [0.56, 0.57] | 6.36× [6.18, 6.48] | 9.11 | 16.17 | 1.43 | 14 MB | 14 MB | 27 MB | 3.4/4.2/3.1 | 30 | MEASURED |
| football | 0.37 MB | 34.6 ms (39.1 ms) | 20.8 ms (23.5 ms) | 105.9 ms (124.3 ms) | 0.60× [0.59, 0.62] | 3.06× [2.98, 3.15] | 10.81 | 17.98 | 3.53 | 13 MB | 13 MB | 32 MB | 6.3/4.8/7.2 | 30 | NOISY |
| earthquakes | 1.44 MB | 71.4 ms (77.7 ms) | 40.3 ms (43.3 ms) | 477.4 ms (506.1 ms) | 0.56× [0.54, 0.59] | 6.68× [6.49, 6.95] | 20.22 | 35.87 | 3.03 | 18 MB | 18 MB | 74 MB | 5.9/5.3/3.1 | 30 | NOISY |
| movies | 0.48 MB | 56.6 ms (67.0 ms) | 33.5 ms (38.8 ms) | 166.8 ms (181.6 ms) | 0.59× [0.57, 0.61] | 2.95× [2.84, 3.00] | 8.52 | 14.39 | 2.89 | 16 MB | 16 MB | 44 MB | 10.2/7.7/4.5 | 30 | NOISY |
| citm_catalog | 0.67 MB | 42.2 ms (153.9 ms) | 22.8 ms (58.0 ms) | 228.0 ms (517.3 ms) | 0.54× [0.42, 0.80] | 5.41× [4.22, 7.10] | 15.80 | 29.22 | 2.92 | 12 MB | 12 MB | 36 MB | 60.4/68.5/33.2 | 30 | NOISY |
| flights_20k | 0.72 MB | 92.0 ms (102.8 ms) | 55.3 ms (64.2 ms) | 253.8 ms (280.1 ms) | 0.60× [0.59, 0.61] | 2.76× [2.73, 2.81] | 7.88 | 13.11 | 2.86 | 32 MB | 32 MB | 67 MB | 4.4/7.6/5.2 | 30 | NOISY |
| canada | 2.93 MB | 178.3 ms (183.3 ms) | 72.2 ms (77.3 ms) | 1.42 s (1.47 s) | 0.40× [0.40, 0.41] | 7.95× [7.92, 8.10] | 16.44 | 40.59 | 2.07 | 33 MB | 33 MB | 146 MB | 1.6/2.5/1.4 | 17 | MEASURED |
| marine_ik | 2.48 MB | 221.2 ms (253.4 ms) | 96.3 ms (100.9 ms) | 1.41 s (1.44 s) | 0.44× [0.42, 0.44] | 6.37× [6.12, 6.42] | 11.21 | 25.75 | 1.76 | 45 MB | 45 MB | 187 MB | 4.8/1.9/1.2 | 17 | MEASURED |
| gsoc_2018 | 3.09 MB | 60.5 ms (69.5 ms) | 36.4 ms (59.4 ms) | 476.7 ms (520.6 ms) | 0.60× [0.57, 0.64] | 7.88× [7.71, 8.12] | 51.11 | 85.04 | 6.49 | 22 MB | 22 MB | 149 MB | 6.9/20.0/2.8 | 30 | NOISY |
| semanticscholar | 8.92 MB | 276.4 ms (292.9 ms) | 167.6 ms (189.6 ms) | 1.77 s (1.81 s) | 0.61× [0.58, 0.63] | 6.41× [6.11, 6.50] | 32.27 | 53.23 | 5.03 | 69 MB | 69 MB | 423 MB | 3.1/4.3/0.9 | 13 | MEASURED |
| flights_200k | 4.65 MB | 730.5 ms (789.6 ms) | 372.0 ms (421.8 ms) | 3.35 s (3.58 s) | 0.51× [0.46, 0.57] | 4.59× [4.19, 5.10] | 6.36 | 12.50 | 1.39 | 164 MB | 164 MB | 389 MB | 5.9/6.7/5.5 | 7 | NOISY |
| openapi_github | 9.33 MB | 347.7 ms (353.2 ms) | 234.9 ms (247.1 ms) | 2.14 s (2.21 s) | 0.68× [0.67, 0.69] | 6.16× [6.12, 6.26] | 26.84 | 39.73 | 4.36 | 96 MB | 94 MB | 450 MB | 0.9/1.9/1.3 | 10 | MEASURED |
| semsch_625 | 1.02 MB | 31.2 ms (37.6 ms) | 19.3 ms (24.3 ms) | 185.2 ms (213.3 ms) | 0.62× [0.59, 0.64] | 5.93× [5.77, 6.10] | 32.75 | 53.06 | 5.52 | 12 MB | 12 MB | 51 MB | 7.3/10.1/6.0 | 30 | NOISY |
| semsch_1250 | 2.18 MB | 63.9 ms (69.0 ms) | 37.0 ms (41.7 ms) | 411.5 ms (426.6 ms) | 0.58× [0.57, 0.59] | 6.44× [6.34, 6.54] | 34.07 | 58.80 | 5.29 | 19 MB | 19 MB | 106 MB | 3.8/4.7/1.9 | 30 | MEASURED |
| semsch_2500 | 4.43 MB | 136.2 ms (147.7 ms) | 80.8 ms (85.7 ms) | 862.5 ms (873.5 ms) | 0.59× [0.58, 0.61] | 6.33× [6.18, 6.40] | 32.51 | 54.82 | 5.14 | 36 MB | 36 MB | 212 MB | 3.5/2.9/0.8 | 26 | MEASURED |
| semsch_5000 | 8.92 MB | 277.3 ms (287.7 ms) | 169.2 ms (176.7 ms) | 1.77 s (1.80 s) | 0.61× [0.60, 0.63] | 6.37× [6.24, 6.43] | 32.16 | 52.71 | 5.05 | 69 MB | 69 MB | 423 MB | 1.7/1.6/0.9 | 13 | MEASURED |

## decode_expand

| document | input | rust_z median (p95) | rust_o3 median (p95) | bend median (p95) | rust_o3/rust_z [95% CI] | bend/rust_z [95% CI] | rust_z MB/s | rust_o3 MB/s | bend MB/s | rust_z peak RSS | rust_o3 peak RSS | bend peak RSS | cv % (rust_z/rust_o3/bend) | n | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| github_events | 0.06 MB | 2.75 ms (2.95 ms) | 2.21 ms (2.45 ms) | 12.9 ms (13.6 ms) | 0.80× [0.78, 0.83] | 4.69× [4.63, 4.75] | 21.36 | 26.57 | 4.55 | 3 MB | 3 MB | 6 MB | 3.5/4.8/2.7 | 30 | MEASURED |
| apache_builds | 0.07 MB | 4.57 ms (4.83 ms) | 3.11 ms (3.62 ms) | 17.6 ms (18.4 ms) | 0.68× [0.67, 0.70] | 3.85× [3.80, 3.93] | 15.92 | 23.40 | 4.13 | 4 MB | 4 MB | 7 MB | 4.8/9.7/2.2 | 30 | NOISY |
| numbers | 0.15 MB | 12.4 ms (15.2 ms) | 6.49 ms (6.90 ms) | 82.3 ms (85.2 ms) | 0.52× [0.51, 0.53] | 6.63× [6.51, 6.70] | 12.09 | 23.15 | 1.82 | 5 MB | 5 MB | 11 MB | 6.0/4.6/1.6 | 30 | NOISY |
| flights_2k | 0.07 MB | 10.8 ms (12.0 ms) | 7.12 ms (8.16 ms) | 43.6 ms (48.1 ms) | 0.66× [0.65, 0.67] | 4.05× [3.99, 4.11] | 6.74 | 10.19 | 1.66 | 6 MB | 6 MB | 11 MB | 5.3/5.5/3.8 | 30 | NOISY |
| unemployment | 0.10 MB | 11.9 ms (13.5 ms) | 7.06 ms (7.38 ms) | 52.4 ms (55.5 ms) | 0.59× [0.58, 0.61] | 4.40× [4.29, 4.50] | 8.70 | 14.68 | 1.98 | 5 MB | 5 MB | 11 MB | 9.0/8.9/3.1 | 30 | NOISY |
| instruments | 0.11 MB | 8.03 ms (9.01 ms) | 5.65 ms (6.45 ms) | 43.5 ms (48.8 ms) | 0.70× [0.69, 0.72] | 5.42× [5.32, 5.53] | 13.38 | 19.01 | 2.47 | 4 MB | 5 MB | 11 MB | 4.7/7.2/3.9 | 30 | NOISY |
| npm_cli_lock | 0.33 MB | 16.2 ms (17.3 ms) | 11.3 ms (11.9 ms) | 110.9 ms (118.6 ms) | 0.70× [0.69, 0.71] | 6.85× [6.68, 6.98] | 20.62 | 29.61 | 3.01 | 6 MB | 6 MB | 20 MB | 3.2/3.3/4.0 | 30 | MEASURED |
| flights_5k | 0.18 MB | 24.6 ms (26.2 ms) | 15.5 ms (17.7 ms) | 108.9 ms (113.5 ms) | 0.63× [0.61, 0.64] | 4.43× [4.31, 4.48] | 7.37 | 11.71 | 1.66 | 10 MB | 10 MB | 23 MB | 3.5/4.4/1.9 | 30 | MEASURED |
| random | 0.44 MB | 22.9 ms (25.0 ms) | 14.6 ms (15.0 ms) | 141.4 ms (147.0 ms) | 0.64× [0.63, 0.65] | 6.19× [6.11, 6.27] | 19.10 | 29.80 | 3.09 | 9 MB | 9 MB | 25 MB | 7.0/2.1/2.0 | 30 | NOISY |
| update_center | 0.55 MB | 22.2 ms (27.6 ms) | 14.7 ms (16.5 ms) | 150.2 ms (157.7 ms) | 0.66× [0.64, 0.69] | 6.77× [6.56, 6.87] | 24.66 | 37.21 | 3.64 | 8 MB | 9 MB | 30 MB | 7.0/5.2/2.4 | 30 | NOISY |
| twitterescaped | 0.53 MB | 18.7 ms (20.4 ms) | 12.5 ms (13.3 ms) | 139.2 ms (144.8 ms) | 0.67× [0.66, 0.68] | 7.45× [7.38, 7.51] | 28.42 | 42.50 | 3.82 | 8 MB | 8 MB | 27 MB | 4.2/4.0/2.1 | 30 | MEASURED |
| twitter | 0.53 MB | 18.3 ms (19.1 ms) | 12.6 ms (13.8 ms) | 134.6 ms (141.6 ms) | 0.69× [0.67, 0.70] | 7.36× [7.24, 7.46] | 29.05 | 42.13 | 3.95 | 8 MB | 8 MB | 27 MB | 2.2/8.6/2.8 | 30 | NOISY |
| us_10m | 1.13 MB | 116.3 ms (125.6 ms) | 61.8 ms (71.9 ms) | 419.9 ms (446.0 ms) | 0.53× [0.52, 0.55] | 3.61× [3.53, 3.68] | 9.74 | 18.34 | 2.70 | 29 MB | 30 MB | 67 MB | 3.7/6.3/2.9 | 30 | NOISY |
| mesh | 0.67 MB | 61.2 ms (64.2 ms) | 28.8 ms (31.9 ms) | 334.9 ms (352.9 ms) | 0.47× [0.47, 0.48] | 5.47× [5.41, 5.52] | 10.92 | 23.16 | 1.99 | 13 MB | 13 MB | 37 MB | 3.5/3.4/1.9 | 30 | MEASURED |
| vscode_lock | 0.64 MB | 23.8 ms (24.9 ms) | 16.1 ms (16.9 ms) | 181.6 ms (199.0 ms) | 0.68× [0.66, 0.69] | 7.64× [7.55, 7.95] | 26.93 | 39.82 | 3.53 | 9 MB | 9 MB | 34 MB | 3.0/3.4/4.3 | 30 | MEASURED |
| flights_10k | 0.36 MB | 48.5 ms (51.2 ms) | 29.4 ms (31.0 ms) | 225.8 ms (236.2 ms) | 0.61× [0.60, 0.62] | 4.65× [4.59, 4.70] | 7.47 | 12.31 | 1.61 | 17 MB | 17 MB | 43 MB | 2.9/2.2/2.1 | 30 | MEASURED |
| jobs | 0.37 MB | 43.4 ms (45.7 ms) | 24.9 ms (26.1 ms) | 344.8 ms (364.7 ms) | 0.57× [0.57, 0.58] | 7.94× [7.79, 8.03] | 8.54 | 14.90 | 1.08 | 14 MB | 14 MB | 31 MB | 2.7/2.3/2.7 | 30 | MEASURED |
| football | 0.37 MB | 37.1 ms (41.3 ms) | 22.9 ms (24.8 ms) | 202.8 ms (241.6 ms) | 0.62× [0.60, 0.63] | 5.47× [5.35, 5.61] | 10.09 | 16.36 | 1.85 | 13 MB | 13 MB | 39 MB | 8.2/8.9/6.3 | 30 | NOISY |
| earthquakes | 1.44 MB | 70.5 ms (78.3 ms) | 41.0 ms (44.1 ms) | 571.2 ms (595.1 ms) | 0.58× [0.56, 0.60] | 8.11× [7.95, 8.31] | 20.50 | 35.27 | 2.53 | 18 MB | 18 MB | 73 MB | 6.3/4.2/2.0 | 30 | NOISY |
| movies | 0.48 MB | 59.6 ms (69.9 ms) | 37.8 ms (44.6 ms) | 350.8 ms (411.1 ms) | 0.63× [0.60, 0.66] | 5.89× [5.67, 6.10] | 8.09 | 12.77 | 1.37 | 16 MB | 16 MB | 57 MB | 9.5/9.1/6.0 | 30 | NOISY |
| citm_catalog | 0.67 MB | 46.1 ms (290.2 ms) | 24.5 ms (173.0 ms) | 309.3 ms (908.1 ms) | 0.53× [0.33, 0.79] | 6.71× [4.17, 9.24] | 14.46 | 27.22 | 2.15 | 12 MB | 13 MB | 41 MB | 89.8/103.9/47.6 | 30 | NOISY |
| flights_20k | 0.72 MB | 99.7 ms (136.2 ms) | 60.6 ms (98.9 ms) | 482.4 ms (597.5 ms) | 0.61× [0.60, 0.65] | 4.84× [4.76, 4.93] | 7.27 | 11.95 | 1.50 | 32 MB | 32 MB | 83 MB | 12.7/17.2/8.6 | 30 | NOISY |
| canada | 2.93 MB | 181.7 ms (201.5 ms) | 77.2 ms (87.3 ms) | 1.44 s (1.50 s) | 0.43× [0.42, 0.43] | 7.95× [7.87, 8.06] | 16.13 | 37.95 | 2.03 | 33 MB | 33 MB | 146 MB | 3.0/3.4/1.5 | 17 | MEASURED |
| marine_ik | 2.48 MB | 243.4 ms (248.5 ms) | 114.1 ms (116.3 ms) | 1.53 s (1.57 s) | 0.47× [0.46, 0.48] | 6.30× [6.27, 6.42] | 10.19 | 21.74 | 1.62 | 45 MB | 46 MB | 193 MB | 1.6/1.6/1.1 | 15 | MEASURED |
| gsoc_2018 | 3.09 MB | 62.8 ms (72.6 ms) | 37.4 ms (51.1 ms) | 519.5 ms (572.0 ms) | 0.60× [0.57, 0.64] | 8.27× [7.98, 8.51] | 49.21 | 82.67 | 5.95 | 22 MB | 22 MB | 148 MB | 7.6/13.2/6.5 | 30 | NOISY |
| semanticscholar | 8.92 MB | 311.6 ms (335.8 ms) | 192.4 ms (209.9 ms) | 2.05 s (2.09 s) | 0.62× [0.61, 0.66] | 6.58× [6.47, 6.71] | 28.63 | 46.37 | 4.35 | 76 MB | 77 MB | 423 MB | 2.9/4.1/1.0 | 11 | MEASURED |
| flights_200k | 4.65 MB | 718.2 ms (726.7 ms) | 380.1 ms (396.6 ms) | 4.31 s (4.38 s) | 0.53× [0.51, 0.55] | 6.00× [5.85, 6.09] | 6.47 | 12.23 | 1.08 | 164 MB | 164 MB | 467 MB | 0.8/2.9/1.5 | 5 | MEASURED |
| openapi_github | 9.01 MB | 394.2 ms (401.6 ms) | 270.7 ms (276.0 ms) | 2.72 s (2.75 s) | 0.69× [0.67, 0.70] | 6.91× [6.78, 6.99] | 22.85 | 33.28 | 3.31 | 95 MB | 95 MB | 435 MB | 1.6/1.8/0.7 | 8 | MEASURED |

