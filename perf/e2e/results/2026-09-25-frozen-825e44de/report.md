# toon end-to-end benchmark: rust_z, rust_o3, bend

Run `2026-09-25-frozen-825e44de`, started 2026-09-25T00:47:39Z, finished 2026-09-25T01:24:30Z. Reference arm: **rust_z**; every ratio is `<arm> median / rust_z median` (above 1 = slower than rust_z).

## Environment

- host `hetzner1`, AMD EPYC-Milan Processor, 8 cores, governor `None`, kernel 7.0.0-30-generic, 31 GiB RAM
- load average at start (1.32, 1.25, 1.5), at end (1.49, 1.58, 1.53) (a shared host)
- toon_bend HEAD `4dbf2907c76bdefe49676fa638b180227544546c`
- arm **rust_z** (rust): `/data/tmp/claude-1000/-data-projects-toon-bend/9e91730b-d91a-4f9e-8b28-923307a5f8cb/scratchpad/arms2/z/toon`, 682872 bytes, sha256 `821287eaf1a6d320…`
- arm **rust_o3** (rust): `/data/tmp/claude-1000/-data-projects-toon-bend/9e91730b-d91a-4f9e-8b28-923307a5f8cb/scratchpad/arms2/o3/toon`, 883984 bytes, sha256 `b3683f3917d51fe9…`
- arm **bend** (bend): `/data/tmp/claude-1000/-data-projects-toon-bend/9e91730b-d91a-4f9e-8b28-923307a5f8cb/scratchpad/frozenc5f3b46/toon`, 1030208 bytes, sha256 `825e44de69c3a4e6…`
- budget 30.0 s per cell, runs clamped to [5, 30], arms interleaved in seeded shuffled rounds (seed 1); cv gate 5.0% (a cell above it on any arm is NOISY: its ratio is orientation, not evidence)
- timed runs write stdout to /dev/null; the untimed first run of each cell compared stdout, stderr and exit code of every arm with the reference byte for byte

## Summary

A cell whose reference exits non-zero times an ERROR PATH (the same failure on every arm, byte for byte); it is listed in its table but left out of these geometric means.

| scenario | cells | outputs identical | geomean rust_o3/rust_z | geomean bend/rust_z | range rust_o3/rust_z | range bend/rust_z |
|---|---|---|---|---|---|---|
| encode | 32 | 32/32 | 0.7× | 5.6× | 0.5× – 0.8× | 2.6× – 12.2× |
| encode_stdin | 28 | 28/28 | 0.7× | 5.6× | 0.5× – 0.8× | 2.6× – 12.3× |
| encode_fold | 28 | 28/28 | 0.7× | 6.3× | 0.5× – 0.8× | 2.5× – 12.1× |
| encode_tab | 28 | 28/28 | 0.7× | 5.7× | 0.5× – 0.8× | 2.7× – 12.3× |
| encode_stats | 28 | 28/28 | 0.5× | 5.0× | 0.4× – 0.6× | 2.6× – 9.8× |
| decode | 32 | 32/32 | 0.6× | 3.9× | 0.4× – 0.8× | 1.9× – 7.5× |
| decode_expand | 28 | 28/28 | 0.6× | 5.4× | 0.4× – 0.8× | 3.3× – 7.5× |

### The same ratios by three estimators

On a loaded host the median carries the noise of every sample. Two estimators are less sensitive to it: the MINIMUM over the interleaved samples (contention only ever adds time) and the median CPU time (user + sys of the child itself, which excludes waiting for a core but not cache or SMT interference). Contention adds roughly constant time, so it inflates the shorter arm proportionally more and pulls the ratio of medians toward 1: the median flatters the slower program (by ~12% on the 2026-09-22 run at load 8-14). A claim uses the estimator least favourable to the port and names it; the spread between the three is the noise band. None of them replaces the cv gate: a NOISY cell stays orientation.

| scenario | rust_o3/rust_z median | min | CPU | bend/rust_z median | min | CPU |
|---|---|---|---|---|---|---|
| encode | 0.7× | 0.7× | 0.7× | 5.6× | 5.8× | 5.7× |
| encode_stdin | 0.7× | 0.7× | 0.7× | 5.6× | 5.8× | 5.7× |
| encode_fold | 0.7× | 0.7× | 0.7× | 6.3× | 6.4× | 6.3× |
| encode_tab | 0.7× | 0.7× | 0.7× | 5.7× | 5.8× | 5.7× |
| encode_stats | 0.5× | 0.5× | 0.5× | 5.0× | 5.0× | 5.0× |
| decode | 0.6× | 0.6× | 0.6× | 3.9× | 3.9× | 3.9× |
| decode_expand | 0.6× | 0.6× | 0.6× | 5.4× | 5.4× | 5.4× |

## By document

Geometric mean over the scenarios of each document of `<arm> / rust_z`; the MEASURED column counts cells within the cv gate.

| document | tier | JSON size | scenarios | MEASURED | rust_o3/rust_z median | min | CPU | bend/rust_z median | min | CPU |
|---|---|---|---|---|---|---|---|---|---|---|
| github_events | S | 0.07 MB | 7 | 2 | 0.8× | 0.8× | 0.8× | 3.3× | 3.3× | 3.4× |
| apache_builds | S | 0.13 MB | 7 | 1 | 0.7× | 0.7× | 0.7× | 3.9× | 4.0× | 4.0× |
| numbers | S | 0.15 MB | 7 | 2 | 0.5× | 0.5× | 0.5× | 9.8× | 10.2× | 10.0× |
| flights_2k | S | 0.18 MB | 7 | 0 | 0.7× | 0.7× | 0.7× | 3.6× | 3.7× | 3.7× |
| unemployment | S | 0.19 MB | 7 | 0 | 0.7× | 0.7× | 0.7× | 4.4× | 4.5× | 4.5× |
| instruments | S | 0.22 MB | 7 | 0 | 0.7× | 0.7× | 0.7× | 4.6× | 4.7× | 4.7× |
| npm_cli_lock | M | 0.44 MB | 7 | 1 | 0.7× | 0.7× | 0.7× | 4.3× | 4.2× | 4.3× |
| flights_5k | M | 0.45 MB | 7 | 0 | 0.7× | 0.7× | 0.7× | 3.9× | 4.0× | 3.9× |
| random | M | 0.51 MB | 7 | 0 | 0.7× | 0.7× | 0.7× | 4.9× | 4.8× | 4.9× |
| update_center | M | 0.53 MB | 7 | 2 | 0.7× | 0.7× | 0.7× | 4.5× | 4.4× | 4.6× |
| twitterescaped | M | 0.56 MB | 7 | 0 | 0.7× | 0.7× | 0.7× | 5.3× | 5.1× | 5.3× |
| twitter | M | 0.63 MB | 7 | 1 | 0.7× | 0.7× | 0.7× | 5.4× | 5.2× | 5.4× |
| us_10m | M | 0.64 MB | 7 | 2 | 0.6× | 0.6× | 0.6× | 2.7× | 2.8× | 2.7× |
| mesh | M | 0.72 MB | 7 | 6 | 0.5× | 0.5× | 0.5× | 7.8× | 8.0× | 7.8× |
| vscode_lock | M | 0.78 MB | 7 | 2 | 0.7× | 0.7× | 0.7× | 5.0× | 5.0× | 5.1× |
| flights_10k | M | 0.89 MB | 7 | 1 | 0.7× | 0.7× | 0.7× | 4.0× | 4.2× | 4.1× |
| jobs | M | 0.94 MB | 7 | 2 | 0.6× | 0.6× | 0.6× | 8.9× | 9.2× | 9.0× |
| football | M | 1.21 MB | 7 | 6 | 0.7× | 0.7× | 0.7× | 6.0× | 6.0× | 6.0× |
| earthquakes | M | 1.22 MB | 7 | 5 | 0.6× | 0.6× | 0.6× | 6.5× | 6.5× | 6.5× |
| movies | M | 1.40 MB | 7 | 1 | 0.7× | 0.6× | 0.7× | 6.1× | 6.4× | 6.1× |
| citm_catalog | L | 1.73 MB | 7 | 0 | 0.6× | 0.6× | 0.6× | 6.7× | 7.0× | 6.8× |
| flights_20k | L | 1.78 MB | 7 | 2 | 0.7× | 0.7× | 0.7× | 4.0× | 4.2× | 4.0× |
| canada | L | 2.25 MB | 7 | 7 | 0.5× | 0.5× | 0.5× | 9.1× | 9.3× | 9.1× |
| marine_ik | L | 2.98 MB | 7 | 6 | 0.5× | 0.5× | 0.5× | 6.9× | 7.1× | 6.9× |
| gsoc_2018 | L | 3.33 MB | 7 | 5 | 0.6× | 0.6× | 0.6× | 6.0× | 6.1× | 6.0× |
| semanticscholar | XL | 8.59 MB | 7 | 7 | 0.7× | 0.7× | 0.7× | 5.4× | 5.5× | 5.4× |
| flights_200k | XL | 9.86 MB | 7 | 7 | 0.6× | 0.6× | 0.6× | 6.9× | 7.0× | 6.9× |
| openapi_github | XL | 13.01 MB | 7 | 6 | 0.7× | 0.7× | 0.7× | 4.9× | 5.0× | 4.9× |
| semsch_625 | M | 0.98 MB | 2 | 0 | 0.7× | 0.7× | 0.7× | 4.8× | 4.8× | 4.9× |
| semsch_1250 | L | 2.10 MB | 2 | 0 | 0.6× | 0.7× | 0.6× | 5.4× | 5.5× | 5.4× |
| semsch_2500 | L | 4.27 MB | 2 | 1 | 0.7× | 0.6× | 0.7× | 5.3× | 5.6× | 5.3× |
| semsch_5000 | XL | 8.59 MB | 2 | 2 | 0.7× | 0.7× | 0.7× | 5.3× | 5.3× | 5.3× |

## Scaling

Each series is ONE schema at several sizes (records `n`). `b` is the least-squares slope of log(median time) against log(n): 1.0 is linear, above 1 grows faster than the input. Start-up is inside every point, which pulls `b` below 1 when the smallest points are short. `ms / 1k rec` is the marginal cost between the two largest points.

### flights / encode

| arm | n=2000 | n=5000 | n=10000 | n=20000 | b | ms / 1k rec | rust_o3/rust_z at n=20000 | bend/rust_z at n=20000 |
|---|---|---|---|---|---|---|---|---|
| rust_z | 6.92 ms | 15.7 ms | 32.5 ms | 68.2 ms | 1.00 | 3.58 | 0.71× | 4.42× |
| rust_o3 | 5.22 ms | 11.4 ms | 22.9 ms | 48.2 ms | 0.96 | 2.52 | | |
| bend | 28.5 ms | 70.7 ms | 147.8 ms | 301.3 ms | 1.03 | 15.35 | | |

### flights / encode_stdin

| arm | n=2000 | n=5000 | n=10000 | n=20000 | b | ms / 1k rec | rust_o3/rust_z at n=20000 | bend/rust_z at n=20000 |
|---|---|---|---|---|---|---|---|---|
| rust_z | 6.89 ms | 16.2 ms | 33.8 ms | 69.2 ms | 1.01 | 3.54 | 0.67× | 4.32× |
| rust_o3 | 5.18 ms | 11.4 ms | 23.9 ms | 46.2 ms | 0.96 | 2.23 | | |
| bend | 28.5 ms | 70.7 ms | 150.2 ms | 299.1 ms | 1.03 | 14.89 | | |

### flights / encode_fold

| arm | n=2000 | n=5000 | n=10000 | n=20000 | b | ms / 1k rec | rust_o3/rust_z at n=20000 | bend/rust_z at n=20000 |
|---|---|---|---|---|---|---|---|---|
| rust_z | 6.87 ms | 15.8 ms | 32.1 ms | 68.4 ms | 1.00 | 3.63 | 0.71× | 4.37× |
| rust_o3 | 5.20 ms | 11.5 ms | 22.9 ms | 48.2 ms | 0.97 | 2.53 | | |
| bend | 28.4 ms | 70.7 ms | 148.5 ms | 298.7 ms | 1.03 | 15.02 | | |

### flights / encode_tab

| arm | n=2000 | n=5000 | n=10000 | n=20000 | b | ms / 1k rec | rust_o3/rust_z at n=20000 | bend/rust_z at n=20000 |
|---|---|---|---|---|---|---|---|---|
| rust_z | 6.99 ms | 16.0 ms | 32.8 ms | 68.8 ms | 0.99 | 3.60 | 0.70× | 4.34× |
| rust_o3 | 5.23 ms | 11.4 ms | 22.9 ms | 48.0 ms | 0.96 | 2.51 | | |
| bend | 28.4 ms | 71.4 ms | 146.9 ms | 298.8 ms | 1.02 | 15.19 | | |

### flights / encode_stats

| arm | n=2000 | n=5000 | n=10000 | n=20000 | b | ms / 1k rec | rust_o3/rust_z at n=20000 | bend/rust_z at n=20000 |
|---|---|---|---|---|---|---|---|---|
| rust_z | 9.04 ms | 21.5 ms | 42.9 ms | 88.2 ms | 0.99 | 4.53 | 0.59× | 4.43× |
| rust_o3 | 5.71 ms | 12.4 ms | 24.9 ms | 51.7 ms | 0.96 | 2.67 | | |
| bend | 37.1 ms | 93.8 ms | 195.6 ms | 390.6 ms | 1.03 | 19.51 | | |

### flights / decode

| arm | n=2000 | n=5000 | n=10000 | n=20000 | b | ms / 1k rec | rust_o3/rust_z at n=20000 | bend/rust_z at n=20000 |
|---|---|---|---|---|---|---|---|---|
| rust_z | 9.83 ms | 23.4 ms | 45.2 ms | 89.6 ms | 0.96 | 4.45 | 0.61× | 2.28× |
| rust_o3 | 6.34 ms | 14.3 ms | 27.1 ms | 54.3 ms | 0.93 | 2.72 | | |
| bend | 18.6 ms | 46.7 ms | 95.9 ms | 204.3 ms | 1.04 | 10.84 | | |

### flights / decode_expand

| arm | n=2000 | n=5000 | n=10000 | n=20000 | b | ms / 1k rec | rust_o3/rust_z at n=20000 | bend/rust_z at n=20000 |
|---|---|---|---|---|---|---|---|---|
| rust_z | 10.6 ms | 24.6 ms | 48.8 ms | 97.4 ms | 0.96 | 4.86 | 0.61× | 4.49× |
| rust_o3 | 6.97 ms | 15.3 ms | 29.4 ms | 59.8 ms | 0.93 | 3.04 | | |
| bend | 41.0 ms | 101.1 ms | 211.5 ms | 437.5 ms | 1.03 | 22.60 | | |

### semsch / encode

| arm | n=625 | n=1250 | n=2500 | n=5000 | b | ms / 1k rec | rust_o3/rust_z at n=5000 | bend/rust_z at n=5000 |
|---|---|---|---|---|---|---|---|---|
| rust_z | 20.4 ms | 42.4 ms | 96.2 ms | 200.9 ms | 1.11 | 41.87 | 0.74× | 5.58× |
| rust_o3 | 15.0 ms | 30.5 ms | 69.9 ms | 149.0 ms | 1.11 | 31.64 | | |
| bend | 110.7 ms | 256.9 ms | 550.7 ms | 1.12 s | 1.11 | 227.99 | | |

### semsch / decode

| arm | n=625 | n=1250 | n=2500 | n=5000 | b | ms / 1k rec | rust_o3/rust_z at n=5000 | bend/rust_z at n=5000 |
|---|---|---|---|---|---|---|---|---|
| rust_z | 29.5 ms | 62.4 ms | 132.3 ms | 270.2 ms | 1.07 | 55.16 | 0.62× | 4.98× |
| rust_o3 | 18.4 ms | 36.3 ms | 79.5 ms | 166.8 ms | 1.07 | 34.95 | | |
| bend | 127.3 ms | 296.7 ms | 651.2 ms | 1.34 s | 1.13 | 277.49 | | |

## Memory

Peak RSS of the verification run of each cell (GNU time), as a geometric mean over the cells of a scenario, and as bytes of peak RSS per byte of the scenario's input.

| scenario | rust_z peak RSS | rust_z B/B | rust_o3 peak RSS | rust_o3 B/B | bend peak RSS | bend B/B | rust_o3/rust_z RSS | bend/rust_z RSS |
|---|---|---|---|---|---|---|---|---|
| encode | 13 MB | 14 | 14 MB | 15 | 33 MB | 36 | 1.0× | 2.5× |
| encode_stdin | 12 MB | 15 | 13 MB | 16 | 29 MB | 37 | 1.0× | 2.4× |
| encode_fold | 13 MB | 16 | 13 MB | 16 | 29 MB | 37 | 1.0× | 2.3× |
| encode_tab | 12 MB | 15 | 13 MB | 16 | 29 MB | 37 | 1.0× | 2.4× |
| encode_stats | 12 MB | 15 | 13 MB | 16 | 49 MB | 61 | 1.0× | 4.0× |
| decode | 15 MB | 22 | 15 MB | 23 | 37 MB | 55 | 1.0× | 2.5× |
| decode_expand | 14 MB | 25 | 14 MB | 26 | 39 MB | 71 | 1.0× | 2.8× |

## encode

| document | input | rust_z median (p95) | rust_o3 median (p95) | bend median (p95) | rust_o3/rust_z [95% CI] | bend/rust_z [95% CI] | rust_z MB/s | rust_o3 MB/s | bend MB/s | rust_z peak RSS | rust_o3 peak RSS | bend peak RSS | cv % (rust_z/rust_o3/bend) | n | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| github_events | 0.07 MB | 2.25 ms (3.35 ms) | 1.87 ms (2.06 ms) | 7.12 ms (9.29 ms) | 0.83× [0.81, 0.84] | 3.17× [3.11, 3.21] | 28.98 | 34.80 | 9.15 | 3 MB | 3 MB | 5 MB | 84.4/8.2/9.6 | 30 | NOISY |
| apache_builds | 0.13 MB | 2.96 ms (3.14 ms) | 2.40 ms (2.66 ms) | 13.3 ms (13.7 ms) | 0.81× [0.79, 0.83] | 4.50× [4.42, 4.57] | 42.99 | 53.06 | 9.56 | 3 MB | 4 MB | 7 MB | 3.0/7.6/1.9 | 30 | NOISY |
| numbers | 0.15 MB | 5.89 ms (6.26 ms) | 3.39 ms (3.66 ms) | 71.8 ms (74.4 ms) | 0.58× [0.56, 0.59] | 12.20× [12.00, 12.38] | 25.51 | 44.33 | 2.09 | 4 MB | 4 MB | 8 MB | 10.3/4.2/2.0 | 30 | NOISY |
| flights_2k | 0.18 MB | 6.92 ms (7.71 ms) | 5.22 ms (5.95 ms) | 28.5 ms (29.7 ms) | 0.75× [0.73, 0.78] | 4.11× [4.04, 4.23] | 25.81 | 34.20 | 6.27 | 5 MB | 5 MB | 8 MB | 5.4/5.5/2.2 | 30 | NOISY |
| unemployment | 0.19 MB | 7.15 ms (7.71 ms) | 5.10 ms (6.33 ms) | 35.6 ms (36.7 ms) | 0.71× [0.70, 0.73] | 4.98× [4.90, 5.06] | 25.97 | 36.42 | 5.22 | 5 MB | 5 MB | 9 MB | 3.9/7.1/1.6 | 30 | NOISY |
| instruments | 0.22 MB | 5.11 ms (6.07 ms) | 3.92 ms (5.13 ms) | 25.0 ms (28.4 ms) | 0.77× [0.75, 0.79] | 4.90× [4.79, 5.02] | 43.13 | 56.26 | 8.80 | 4 MB | 4 MB | 9 MB | 7.0/8.7/5.4 | 30 | NOISY |
| npm_cli_lock | 0.44 MB | 12.0 ms (14.3 ms) | 9.39 ms (12.2 ms) | 43.7 ms (45.4 ms) | 0.78× [0.77, 0.80] | 3.63× [3.55, 3.67] | 36.35 | 46.58 | 10.02 | 6 MB | 6 MB | 14 MB | 7.2/8.2/3.0 | 30 | NOISY |
| flights_5k | 0.45 MB | 15.7 ms (18.3 ms) | 11.4 ms (13.4 ms) | 70.7 ms (74.4 ms) | 0.73× [0.69, 0.76] | 4.49× [4.28, 4.56] | 28.38 | 39.00 | 6.31 | 9 MB | 9 MB | 15 MB | 7.7/6.7/3.0 | 30 | NOISY |
| random | 0.51 MB | 14.8 ms (16.3 ms) | 10.9 ms (13.9 ms) | 74.4 ms (83.4 ms) | 0.74× [0.71, 0.76] | 5.03× [4.87, 5.20] | 34.52 | 46.89 | 6.86 | 8 MB | 8 MB | 16 MB | 5.3/9.2/5.1 | 30 | NOISY |
| update_center | 0.53 MB | 15.7 ms (17.3 ms) | 12.1 ms (14.1 ms) | 71.8 ms (78.9 ms) | 0.77× [0.75, 0.80] | 4.56× [4.45, 4.73] | 33.87 | 44.17 | 7.43 | 8 MB | 8 MB | 18 MB | 5.1/7.7/5.5 | 30 | NOISY |
| twitterescaped | 0.56 MB | 13.1 ms (14.2 ms) | 9.26 ms (11.3 ms) | 63.9 ms (68.0 ms) | 0.70× [0.69, 0.72] | 4.86× [4.74, 4.95] | 42.79 | 60.73 | 8.80 | 7 MB | 7 MB | 17 MB | 3.6/9.2/3.4 | 30 | NOISY |
| twitter | 0.63 MB | 12.6 ms (14.2 ms) | 9.28 ms (10.6 ms) | 68.3 ms (81.0 ms) | 0.73× [0.71, 0.75] | 5.41× [5.17, 5.66] | 50.01 | 68.06 | 9.24 | 7 MB | 7 MB | 19 MB | 6.0/5.2/7.1 | 30 | NOISY |
| us_10m | 0.64 MB | 65.1 ms (74.3 ms) | 41.1 ms (46.8 ms) | 166.5 ms (173.0 ms) | 0.63× [0.61, 0.67] | 2.56× [2.50, 2.67] | 9.87 | 15.62 | 3.86 | 25 MB | 25 MB | 36 MB | 7.5/6.8/2.2 | 30 | NOISY |
| mesh | 0.72 MB | 29.7 ms (32.3 ms) | 15.9 ms (17.5 ms) | 281.7 ms (285.7 ms) | 0.53× [0.53, 0.55] | 9.50× [9.39, 9.63] | 24.39 | 45.61 | 2.57 | 11 MB | 11 MB | 25 MB | 4.0/4.1/1.0 | 30 | MEASURED |
| vscode_lock | 0.78 MB | 17.9 ms (20.5 ms) | 13.3 ms (15.9 ms) | 77.1 ms (79.7 ms) | 0.74× [0.73, 0.77] | 4.30× [4.22, 4.42] | 43.63 | 58.76 | 10.14 | 8 MB | 8 MB | 22 MB | 6.7/6.0/2.3 | 30 | NOISY |
| flights_10k | 0.89 MB | 32.5 ms (35.5 ms) | 22.9 ms (25.5 ms) | 147.8 ms (155.4 ms) | 0.71× [0.67, 0.73] | 4.55× [4.35, 4.66] | 27.48 | 38.91 | 6.04 | 15 MB | 15 MB | 27 MB | 5.2/5.4/2.0 | 30 | NOISY |
| jobs | 0.94 MB | 26.0 ms (29.0 ms) | 18.1 ms (20.5 ms) | 270.1 ms (278.8 ms) | 0.70× [0.67, 0.72] | 10.38× [10.18, 10.67] | 35.99 | 51.70 | 3.47 | 12 MB | 12 MB | 28 MB | 5.6/5.4/1.4 | 30 | NOISY |
| football | 1.21 MB | 21.6 ms (23.0 ms) | 16.1 ms (17.9 ms) | 163.9 ms (172.2 ms) | 0.75× [0.73, 0.76] | 7.58× [7.39, 7.71] | 55.80 | 74.76 | 7.36 | 11 MB | 12 MB | 33 MB | 2.8/4.0/2.7 | 30 | MEASURED |
| earthquakes | 1.22 MB | 45.8 ms (50.6 ms) | 30.6 ms (32.5 ms) | 281.7 ms (295.8 ms) | 0.67× [0.65, 0.69] | 6.14× [6.04, 6.29] | 26.61 | 39.84 | 4.33 | 17 MB | 17 MB | 42 MB | 4.5/4.1/2.9 | 30 | MEASURED |
| movies | 1.40 MB | 35.9 ms (38.7 ms) | 25.5 ms (27.1 ms) | 273.5 ms (281.2 ms) | 0.71× [0.69, 0.73] | 7.62× [7.45, 7.73] | 39.01 | 54.93 | 5.12 | 17 MB | 17 MB | 38 MB | 6.0/5.2/1.5 | 30 | NOISY |
| citm_catalog | 1.73 MB | 25.9 ms (29.4 ms) | 18.1 ms (20.7 ms) | 193.9 ms (208.6 ms) | 0.70× [0.68, 0.73] | 7.49× [7.32, 7.78] | 66.69 | 95.16 | 8.91 | 12 MB | 12 MB | 45 MB | 6.1/9.1/3.1 | 30 | NOISY |
| flights_20k | 1.78 MB | 68.2 ms (72.6 ms) | 48.2 ms (54.7 ms) | 301.3 ms (308.0 ms) | 0.71× [0.68, 0.74] | 4.42× [4.30, 4.55] | 26.15 | 37.06 | 5.92 | 27 MB | 27 MB | 50 MB | 4.5/5.4/1.6 | 30 | NOISY |
| canada | 2.25 MB | 93.0 ms (96.7 ms) | 49.3 ms (51.2 ms) | 989.6 ms (1.01 s) | 0.53× [0.52, 0.54] | 10.64× [10.50, 10.73] | 24.21 | 45.69 | 2.27 | 30 MB | 30 MB | 129 MB | 2.0/3.7/1.1 | 26 | MEASURED |
| marine_ik | 2.98 MB | 129.5 ms (134.3 ms) | 75.8 ms (81.0 ms) | 992.1 ms (1.01 s) | 0.59× [0.58, 0.60] | 7.66× [7.56, 7.76] | 23.04 | 39.34 | 3.01 | 37 MB | 37 MB | 124 MB | 2.7/3.1/0.8 | 24 | MEASURED |
| gsoc_2018 | 3.33 MB | 43.5 ms (46.4 ms) | 28.9 ms (31.1 ms) | 271.0 ms (277.2 ms) | 0.66× [0.64, 0.68] | 6.23× [6.16, 6.35] | 76.55 | 115.22 | 12.28 | 17 MB | 17 MB | 83 MB | 3.6/4.8/1.2 | 30 | MEASURED |
| semanticscholar | 8.59 MB | 200.7 ms (206.5 ms) | 148.9 ms (154.8 ms) | 1.12 s (1.13 s) | 0.74× [0.73, 0.75] | 5.56× [5.48, 5.61] | 42.81 | 57.72 | 7.70 | 67 MB | 67 MB | 224 MB | 1.7/3.0/1.5 | 20 | MEASURED |
| flights_200k | 9.86 MB | 367.0 ms (375.1 ms) | 241.5 ms (249.6 ms) | 2.96 s (3.00 s) | 0.66× [0.65, 0.67] | 8.07× [7.97, 8.20] | 26.88 | 40.84 | 3.33 | 122 MB | 122 MB | 288 MB | 1.6/1.7/0.7 | 8 | MEASURED |
| openapi_github | 13.01 MB | 299.7 ms (312.9 ms) | 226.7 ms (242.4 ms) | 1.43 s (1.46 s) | 0.76× [0.74, 0.79] | 4.76× [4.65, 4.83] | 43.42 | 57.41 | 9.11 | 89 MB | 89 MB | 317 MB | 2.5/3.0/1.4 | 14 | MEASURED |
| semsch_625 | 0.98 MB | 20.4 ms (24.0 ms) | 15.0 ms (17.2 ms) | 110.7 ms (120.7 ms) | 0.74× [0.71, 0.76] | 5.42× [5.29, 5.63] | 48.04 | 65.33 | 8.86 | 10 MB | 10 MB | 29 MB | 10.5/6.6/4.7 | 30 | NOISY |
| semsch_1250 | 2.10 MB | 42.4 ms (45.2 ms) | 30.5 ms (34.7 ms) | 256.9 ms (264.7 ms) | 0.72× [0.69, 0.74] | 6.06× [5.91, 6.16] | 49.42 | 68.75 | 8.16 | 18 MB | 19 MB | 57 MB | 4.0/6.6/1.9 | 30 | NOISY |
| semsch_2500 | 4.27 MB | 96.2 ms (100.5 ms) | 69.9 ms (76.9 ms) | 550.7 ms (561.1 ms) | 0.73× [0.71, 0.75] | 5.72× [5.69, 5.77] | 44.33 | 61.08 | 7.75 | 34 MB | 35 MB | 113 MB | 2.6/5.4/1.4 | 30 | NOISY |
| semsch_5000 | 8.59 MB | 200.9 ms (207.2 ms) | 149.0 ms (153.9 ms) | 1.12 s (1.13 s) | 0.74× [0.72, 0.76] | 5.58× [5.49, 5.66] | 42.75 | 57.66 | 7.66 | 67 MB | 67 MB | 224 MB | 2.2/2.5/1.3 | 20 | MEASURED |

## encode_stdin

| document | input | rust_z median (p95) | rust_o3 median (p95) | bend median (p95) | rust_o3/rust_z [95% CI] | bend/rust_z [95% CI] | rust_z MB/s | rust_o3 MB/s | bend MB/s | rust_z peak RSS | rust_o3 peak RSS | bend peak RSS | cv % (rust_z/rust_o3/bend) | n | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| github_events | 0.07 MB | 2.25 ms (2.42 ms) | 1.87 ms (1.95 ms) | 7.08 ms (7.39 ms) | 0.83× [0.82, 0.84] | 3.15× [3.12, 3.20] | 28.99 | 34.82 | 9.20 | 3 MB | 3 MB | 5 MB | 3.4/2.6/2.0 | 30 | MEASURED |
| apache_builds | 0.13 MB | 3.06 ms (3.54 ms) | 2.50 ms (3.02 ms) | 13.5 ms (14.5 ms) | 0.82× [0.80, 0.85] | 4.40× [4.34, 4.50] | 41.63 | 50.91 | 9.46 | 3 MB | 4 MB | 7 MB | 8.1/7.7/3.0 | 30 | NOISY |
| numbers | 0.15 MB | 5.84 ms (8.41 ms) | 3.52 ms (4.02 ms) | 71.6 ms (73.8 ms) | 0.60× [0.58, 0.62] | 12.25× [11.94, 12.55] | 25.69 | 42.68 | 2.10 | 4 MB | 4 MB | 7 MB | 13.0/7.7/3.8 | 30 | NOISY |
| flights_2k | 0.18 MB | 6.89 ms (7.57 ms) | 5.18 ms (6.51 ms) | 28.5 ms (31.0 ms) | 0.75× [0.72, 0.77] | 4.13× [4.03, 4.24] | 25.89 | 34.44 | 6.27 | 5 MB | 5 MB | 8 MB | 8.5/11.2/3.6 | 30 | NOISY |
| unemployment | 0.19 MB | 7.27 ms (8.39 ms) | 5.18 ms (6.57 ms) | 36.3 ms (39.1 ms) | 0.71× [0.68, 0.73] | 4.99× [4.81, 5.12] | 25.55 | 35.85 | 5.12 | 5 MB | 5 MB | 9 MB | 8.6/7.8/6.8 | 30 | NOISY |
| instruments | 0.22 MB | 5.16 ms (6.10 ms) | 4.01 ms (4.89 ms) | 25.2 ms (26.7 ms) | 0.78× [0.74, 0.80] | 4.90× [4.66, 5.03] | 42.73 | 54.92 | 8.73 | 4 MB | 4 MB | 9 MB | 7.4/7.4/3.0 | 30 | NOISY |
| npm_cli_lock | 0.44 MB | 11.9 ms (13.6 ms) | 9.37 ms (11.4 ms) | 43.3 ms (49.1 ms) | 0.78× [0.77, 0.80] | 3.62× [3.52, 3.74] | 36.61 | 46.68 | 10.11 | 6 MB | 6 MB | 14 MB | 6.2/6.5/6.0 | 30 | NOISY |
| flights_5k | 0.45 MB | 16.2 ms (17.6 ms) | 11.4 ms (12.4 ms) | 70.7 ms (77.0 ms) | 0.70× [0.69, 0.72] | 4.36× [4.29, 4.50] | 27.52 | 39.25 | 6.31 | 9 MB | 9 MB | 15 MB | 5.1/4.4/3.2 | 30 | NOISY |
| random | 0.51 MB | 14.4 ms (16.4 ms) | 10.7 ms (12.0 ms) | 73.4 ms (86.3 ms) | 0.74× [0.73, 0.76] | 5.09× [4.89, 5.32] | 35.34 | 47.76 | 6.95 | 8 MB | 8 MB | 16 MB | 5.2/4.9/7.4 | 30 | NOISY |
| update_center | 0.53 MB | 15.7 ms (16.9 ms) | 11.9 ms (13.4 ms) | 68.5 ms (72.2 ms) | 0.76× [0.74, 0.78] | 4.37× [4.24, 4.44] | 34.00 | 44.75 | 7.79 | 8 MB | 8 MB | 18 MB | 4.7/4.6/3.4 | 30 | MEASURED |
| twitterescaped | 0.56 MB | 12.9 ms (14.1 ms) | 9.30 ms (10.3 ms) | 64.3 ms (72.8 ms) | 0.72× [0.70, 0.73] | 4.96× [4.83, 5.10] | 43.45 | 60.47 | 8.75 | 7 MB | 7 MB | 17 MB | 4.2/7.1/5.6 | 30 | NOISY |
| twitter | 0.63 MB | 13.0 ms (13.8 ms) | 9.50 ms (10.9 ms) | 69.5 ms (74.0 ms) | 0.73× [0.71, 0.75] | 5.35× [5.24, 5.42] | 48.60 | 66.47 | 9.09 | 7 MB | 7 MB | 19 MB | 3.0/5.9/3.9 | 30 | NOISY |
| us_10m | 0.64 MB | 65.1 ms (70.3 ms) | 42.1 ms (46.5 ms) | 166.7 ms (176.4 ms) | 0.65× [0.61, 0.67] | 2.56× [2.45, 2.63] | 9.87 | 15.28 | 3.85 | 25 MB | 25 MB | 36 MB | 4.7/5.5/3.2 | 30 | NOISY |
| mesh | 0.72 MB | 29.8 ms (31.7 ms) | 15.9 ms (17.5 ms) | 283.8 ms (295.9 ms) | 0.53× [0.53, 0.54] | 9.52× [9.40, 9.65] | 24.28 | 45.42 | 2.55 | 11 MB | 11 MB | 25 MB | 4.7/4.0/2.1 | 30 | MEASURED |
| vscode_lock | 0.78 MB | 17.4 ms (19.3 ms) | 13.3 ms (14.5 ms) | 76.2 ms (80.0 ms) | 0.76× [0.75, 0.78] | 4.38× [4.30, 4.45] | 44.94 | 58.84 | 10.26 | 8 MB | 8 MB | 22 MB | 6.4/4.1/3.1 | 30 | NOISY |
| flights_10k | 0.89 MB | 33.8 ms (39.2 ms) | 23.9 ms (29.1 ms) | 150.2 ms (164.6 ms) | 0.71× [0.67, 0.73] | 4.44× [4.22, 4.56] | 26.37 | 37.32 | 5.94 | 15 MB | 15 MB | 27 MB | 7.1/10.7/4.4 | 30 | NOISY |
| jobs | 0.94 MB | 26.2 ms (28.3 ms) | 17.8 ms (19.6 ms) | 271.2 ms (281.5 ms) | 0.68× [0.66, 0.70] | 10.35× [10.07, 10.53] | 35.73 | 52.57 | 3.45 | 12 MB | 12 MB | 27 MB | 4.2/5.7/1.7 | 30 | NOISY |
| football | 1.21 MB | 21.5 ms (23.5 ms) | 16.2 ms (17.9 ms) | 163.0 ms (169.7 ms) | 0.75× [0.74, 0.77] | 7.58× [7.48, 7.68] | 56.17 | 74.46 | 7.41 | 11 MB | 12 MB | 33 MB | 3.3/4.1/2.5 | 30 | MEASURED |
| earthquakes | 1.22 MB | 45.3 ms (50.2 ms) | 30.8 ms (34.2 ms) | 280.6 ms (296.1 ms) | 0.68× [0.66, 0.70] | 6.19× [6.08, 6.36] | 26.92 | 39.66 | 4.35 | 17 MB | 17 MB | 42 MB | 4.4/4.9/2.9 | 30 | MEASURED |
| movies | 1.40 MB | 35.0 ms (38.3 ms) | 25.3 ms (28.1 ms) | 274.0 ms (280.9 ms) | 0.72× [0.69, 0.74] | 7.83× [7.65, 7.94] | 40.00 | 55.25 | 5.11 | 17 MB | 17 MB | 38 MB | 4.9/8.0/1.6 | 30 | NOISY |
| citm_catalog | 1.73 MB | 25.6 ms (29.4 ms) | 17.8 ms (20.0 ms) | 193.6 ms (199.4 ms) | 0.70× [0.67, 0.74] | 7.56× [7.29, 8.01] | 67.49 | 97.11 | 8.92 | 12 MB | 12 MB | 45 MB | 8.0/6.4/1.7 | 30 | NOISY |
| flights_20k | 1.78 MB | 69.2 ms (74.1 ms) | 46.2 ms (52.4 ms) | 299.1 ms (308.2 ms) | 0.67× [0.65, 0.69] | 4.32× [4.25, 4.39] | 25.79 | 38.63 | 5.97 | 27 MB | 27 MB | 50 MB | 4.2/5.3/1.5 | 30 | NOISY |
| canada | 2.25 MB | 93.6 ms (98.1 ms) | 49.7 ms (52.7 ms) | 993.0 ms (999.2 ms) | 0.53× [0.52, 0.54] | 10.61× [10.42, 10.69] | 24.05 | 45.25 | 2.27 | 30 MB | 30 MB | 129 MB | 2.6/2.9/0.8 | 25 | MEASURED |
| marine_ik | 2.98 MB | 128.0 ms (134.3 ms) | 76.5 ms (82.8 ms) | 989.4 ms (1.00 s) | 0.60× [0.59, 0.61] | 7.73× [7.63, 7.81] | 23.31 | 38.98 | 3.02 | 37 MB | 37 MB | 124 MB | 2.4/6.4/0.7 | 24 | NOISY |
| gsoc_2018 | 3.33 MB | 43.1 ms (45.1 ms) | 28.4 ms (31.4 ms) | 270.1 ms (279.2 ms) | 0.66× [0.65, 0.68] | 6.27× [6.17, 6.40] | 77.25 | 117.18 | 12.32 | 17 MB | 17 MB | 83 MB | 3.3/4.4/2.0 | 30 | MEASURED |
| semanticscholar | 8.59 MB | 202.2 ms (207.2 ms) | 153.1 ms (156.2 ms) | 1.12 s (1.13 s) | 0.76× [0.74, 0.77] | 5.54× [5.48, 5.60] | 42.49 | 56.15 | 7.67 | 67 MB | 67 MB | 224 MB | 1.8/3.3/0.8 | 20 | MEASURED |
| flights_200k | 9.86 MB | 365.5 ms (377.6 ms) | 227.3 ms (242.0 ms) | 2.96 s (3.01 s) | 0.62× [0.61, 0.63] | 8.10× [8.02, 8.24] | 26.99 | 43.39 | 3.33 | 122 MB | 122 MB | 288 MB | 1.4/2.6/1.0 | 8 | MEASURED |
| openapi_github | 13.01 MB | 299.9 ms (331.4 ms) | 232.5 ms (247.2 ms) | 1.43 s (1.46 s) | 0.78× [0.75, 0.80] | 4.75× [4.62, 4.83] | 43.39 | 55.96 | 9.13 | 89 MB | 89 MB | 317 MB | 3.5/3.9/1.0 | 15 | MEASURED |

## encode_fold

| document | input | rust_z median (p95) | rust_o3 median (p95) | bend median (p95) | rust_o3/rust_z [95% CI] | bend/rust_z [95% CI] | rust_z MB/s | rust_o3 MB/s | bend MB/s | rust_z peak RSS | rust_o3 peak RSS | bend peak RSS | cv % (rust_z/rust_o3/bend) | n | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| github_events | 0.07 MB | 2.48 ms (2.90 ms) | 2.07 ms (2.27 ms) | 9.09 ms (9.43 ms) | 0.84× [0.80, 0.86] | 3.67× [3.57, 3.74] | 26.30 | 31.50 | 7.17 | 3 MB | 3 MB | 5 MB | 5.8/11.8/1.9 | 30 | NOISY |
| apache_builds | 0.13 MB | 2.99 ms (3.35 ms) | 2.45 ms (2.66 ms) | 13.4 ms (13.9 ms) | 0.82× [0.80, 0.83] | 4.47× [4.41, 4.53] | 42.51 | 51.90 | 9.50 | 3 MB | 4 MB | 7 MB | 6.3/5.0/1.4 | 30 | NOISY |
| numbers | 0.15 MB | 5.88 ms (6.89 ms) | 3.37 ms (3.97 ms) | 71.0 ms (73.8 ms) | 0.57× [0.55, 0.59] | 12.08× [11.67, 12.41] | 25.55 | 44.56 | 2.12 | 4 MB | 4 MB | 7 MB | 7.6/6.2/1.8 | 30 | NOISY |
| flights_2k | 0.18 MB | 6.87 ms (7.93 ms) | 5.20 ms (5.50 ms) | 28.4 ms (30.6 ms) | 0.76× [0.72, 0.77] | 4.13× [4.00, 4.19] | 25.99 | 34.31 | 6.29 | 5 MB | 5 MB | 8 MB | 6.6/3.9/2.8 | 30 | NOISY |
| unemployment | 0.19 MB | 7.02 ms (9.29 ms) | 5.07 ms (7.28 ms) | 35.9 ms (40.5 ms) | 0.72× [0.71, 0.74] | 5.11× [5.01, 5.23] | 26.44 | 36.65 | 5.17 | 5 MB | 5 MB | 9 MB | 8.8/12.0/5.4 | 30 | NOISY |
| instruments | 0.22 MB | 5.33 ms (6.13 ms) | 4.08 ms (4.42 ms) | 32.7 ms (40.6 ms) | 0.77× [0.74, 0.80] | 6.14× [5.99, 6.32] | 41.38 | 54.01 | 6.74 | 4 MB | 4 MB | 9 MB | 5.7/5.9/7.5 | 30 | NOISY |
| npm_cli_lock | 0.44 MB | 16.0 ms (18.8 ms) | 13.0 ms (15.0 ms) | 109.1 ms (117.1 ms) | 0.81× [0.78, 0.83] | 6.80× [6.51, 7.05] | 27.26 | 33.74 | 4.01 | 7 MB | 7 MB | 14 MB | 7.4/6.7/5.3 | 30 | NOISY |
| flights_5k | 0.45 MB | 15.8 ms (17.3 ms) | 11.5 ms (13.1 ms) | 70.7 ms (75.3 ms) | 0.73× [0.71, 0.76] | 4.48× [4.37, 4.64] | 28.32 | 38.89 | 6.31 | 9 MB | 9 MB | 15 MB | 4.7/5.9/3.1 | 30 | NOISY |
| random | 0.51 MB | 14.9 ms (17.2 ms) | 11.1 ms (12.2 ms) | 90.1 ms (108.7 ms) | 0.74× [0.69, 0.77] | 6.03× [5.71, 6.33] | 34.17 | 45.98 | 5.67 | 8 MB | 8 MB | 16 MB | 8.2/5.3/9.1 | 30 | NOISY |
| update_center | 0.53 MB | 20.0 ms (22.9 ms) | 16.0 ms (18.9 ms) | 105.0 ms (117.4 ms) | 0.80× [0.78, 0.81] | 5.24× [5.12, 5.37] | 26.59 | 33.32 | 5.08 | 10 MB | 10 MB | 18 MB | 7.7/5.8/5.7 | 30 | NOISY |
| twitterescaped | 0.56 MB | 14.6 ms (16.3 ms) | 10.8 ms (11.4 ms) | 106.5 ms (121.4 ms) | 0.74× [0.72, 0.76] | 7.28× [7.04, 7.57] | 38.46 | 52.00 | 5.28 | 7 MB | 7 MB | 17 MB | 10.2/3.5/7.2 | 30 | NOISY |
| twitter | 0.63 MB | 14.7 ms (16.7 ms) | 10.8 ms (11.9 ms) | 109.6 ms (118.9 ms) | 0.73× [0.72, 0.76] | 7.46× [7.23, 7.62] | 42.99 | 58.58 | 5.76 | 7 MB | 7 MB | 19 MB | 5.9/6.0/4.7 | 30 | NOISY |
| us_10m | 0.64 MB | 73.0 ms (79.4 ms) | 48.3 ms (52.9 ms) | 179.5 ms (192.2 ms) | 0.66× [0.64, 0.68] | 2.46× [2.42, 2.51] | 8.80 | 13.31 | 3.58 | 27 MB | 27 MB | 36 MB | 4.9/5.3/2.7 | 30 | NOISY |
| mesh | 0.72 MB | 29.9 ms (32.0 ms) | 15.9 ms (17.6 ms) | 284.6 ms (294.2 ms) | 0.53× [0.52, 0.54] | 9.50× [9.36, 9.65] | 24.17 | 45.41 | 2.54 | 11 MB | 11 MB | 25 MB | 3.0/3.3/1.7 | 30 | MEASURED |
| vscode_lock | 0.78 MB | 22.8 ms (24.1 ms) | 17.9 ms (18.8 ms) | 163.8 ms (173.8 ms) | 0.79× [0.78, 0.81] | 7.19× [7.04, 7.31] | 34.32 | 43.56 | 4.77 | 10 MB | 10 MB | 22 MB | 2.7/4.6/3.4 | 30 | MEASURED |
| flights_10k | 0.89 MB | 32.1 ms (36.3 ms) | 22.9 ms (26.1 ms) | 148.5 ms (155.0 ms) | 0.71× [0.68, 0.73] | 4.63× [4.37, 4.72] | 27.81 | 38.95 | 6.01 | 15 MB | 15 MB | 26 MB | 6.7/5.7/2.4 | 30 | NOISY |
| jobs | 0.94 MB | 26.5 ms (30.5 ms) | 18.1 ms (20.7 ms) | 273.9 ms (283.3 ms) | 0.68× [0.66, 0.71] | 10.32× [10.02, 10.58] | 35.29 | 51.71 | 3.42 | 12 MB | 12 MB | 28 MB | 6.1/7.6/2.0 | 30 | NOISY |
| football | 1.21 MB | 21.3 ms (22.7 ms) | 16.1 ms (17.0 ms) | 164.5 ms (170.2 ms) | 0.76× [0.74, 0.77] | 7.74× [7.56, 7.88] | 56.78 | 74.89 | 7.34 | 11 MB | 12 MB | 33 MB | 3.4/4.5/2.5 | 30 | MEASURED |
| earthquakes | 1.22 MB | 50.3 ms (53.6 ms) | 35.2 ms (39.8 ms) | 391.2 ms (400.0 ms) | 0.70× [0.68, 0.72] | 7.77× [7.59, 7.88] | 24.24 | 34.65 | 3.12 | 17 MB | 17 MB | 43 MB | 3.6/7.3/1.5 | 30 | NOISY |
| movies | 1.40 MB | 35.4 ms (40.1 ms) | 25.4 ms (28.2 ms) | 274.7 ms (282.4 ms) | 0.72× [0.70, 0.74] | 7.77× [7.60, 7.97] | 39.60 | 55.14 | 5.10 | 17 MB | 17 MB | 38 MB | 5.1/5.8/1.8 | 30 | NOISY |
| citm_catalog | 1.73 MB | 26.9 ms (29.2 ms) | 18.1 ms (20.5 ms) | 221.2 ms (227.7 ms) | 0.67× [0.65, 0.73] | 8.21× [7.95, 8.76] | 64.11 | 95.27 | 7.81 | 12 MB | 12 MB | 45 MB | 6.8/6.1/1.6 | 30 | NOISY |
| flights_20k | 1.78 MB | 68.4 ms (74.0 ms) | 48.2 ms (51.9 ms) | 298.7 ms (309.1 ms) | 0.71× [0.67, 0.74] | 4.37× [4.17, 4.49] | 26.10 | 37.00 | 5.98 | 27 MB | 27 MB | 50 MB | 5.9/4.7/1.7 | 30 | NOISY |
| canada | 2.25 MB | 103.7 ms (107.5 ms) | 58.4 ms (63.4 ms) | 990.7 ms (1.00 s) | 0.56× [0.55, 0.58] | 9.55× [9.43, 9.69] | 21.70 | 38.55 | 2.27 | 37 MB | 37 MB | 129 MB | 2.2/4.6/0.7 | 25 | MEASURED |
| marine_ik | 2.98 MB | 150.8 ms (156.1 ms) | 96.1 ms (100.5 ms) | 1.02 s (1.03 s) | 0.64× [0.62, 0.65] | 6.76× [6.66, 6.80] | 19.78 | 31.04 | 2.93 | 50 MB | 50 MB | 125 MB | 2.1/4.0/0.9 | 23 | MEASURED |
| gsoc_2018 | 3.33 MB | 45.7 ms (48.3 ms) | 31.0 ms (33.0 ms) | 326.3 ms (331.9 ms) | 0.68× [0.67, 0.69] | 7.15× [7.07, 7.24] | 72.89 | 107.51 | 10.20 | 17 MB | 17 MB | 83 MB | 2.8/6.1/1.1 | 30 | NOISY |
| semanticscholar | 8.59 MB | 201.2 ms (210.5 ms) | 148.1 ms (152.7 ms) | 1.29 s (1.32 s) | 0.74× [0.72, 0.75] | 6.43× [6.31, 6.51] | 42.70 | 58.03 | 6.64 | 67 MB | 67 MB | 224 MB | 2.2/2.0/0.7 | 18 | MEASURED |
| flights_200k | 9.86 MB | 374.1 ms (386.2 ms) | 235.8 ms (249.6 ms) | 2.99 s (3.06 s) | 0.63× [0.62, 0.66] | 8.00× [7.90, 8.14] | 26.36 | 41.83 | 3.30 | 122 MB | 122 MB | 288 MB | 1.7/2.7/1.1 | 8 | MEASURED |
| openapi_github | 13.01 MB | 590.3 ms (600.6 ms) | 486.9 ms (498.8 ms) | 2.91 s (2.93 s) | 0.82× [0.81, 0.84] | 4.92× [4.84, 5.02] | 22.05 | 26.72 | 4.48 | 95 MB | 95 MB | 317 MB | 1.5/1.3/0.5 | 7 | MEASURED |

## encode_tab

| document | input | rust_z median (p95) | rust_o3 median (p95) | bend median (p95) | rust_o3/rust_z [95% CI] | bend/rust_z [95% CI] | rust_z MB/s | rust_o3 MB/s | bend MB/s | rust_z peak RSS | rust_o3 peak RSS | bend peak RSS | cv % (rust_z/rust_o3/bend) | n | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| github_events | 0.07 MB | 2.25 ms (2.44 ms) | 1.87 ms (2.23 ms) | 7.09 ms (8.09 ms) | 0.83× [0.81, 0.85] | 3.15× [3.11, 3.19] | 28.98 | 34.84 | 9.19 | 3 MB | 3 MB | 5 MB | 3.2/8.5/4.6 | 30 | NOISY |
| apache_builds | 0.13 MB | 2.97 ms (3.21 ms) | 2.40 ms (2.56 ms) | 13.3 ms (14.7 ms) | 0.81× [0.80, 0.82] | 4.47× [4.41, 4.51] | 42.89 | 52.99 | 9.59 | 3 MB | 4 MB | 7 MB | 5.3/3.4/4.9 | 30 | NOISY |
| numbers | 0.15 MB | 5.84 ms (6.80 ms) | 3.45 ms (3.78 ms) | 71.9 ms (75.4 ms) | 0.59× [0.57, 0.61] | 12.32× [11.98, 12.61] | 25.72 | 43.58 | 2.09 | 4 MB | 4 MB | 7 MB | 8.6/5.2/2.1 | 30 | NOISY |
| flights_2k | 0.18 MB | 6.99 ms (7.79 ms) | 5.23 ms (5.76 ms) | 28.4 ms (29.7 ms) | 0.75× [0.72, 0.77] | 4.06× [4.00, 4.11] | 25.53 | 34.11 | 6.29 | 5 MB | 5 MB | 8 MB | 4.8/6.9/2.8 | 30 | NOISY |
| unemployment | 0.19 MB | 7.22 ms (8.03 ms) | 5.14 ms (6.10 ms) | 35.9 ms (38.3 ms) | 0.71× [0.69, 0.73] | 4.98× [4.83, 5.14] | 25.73 | 36.12 | 5.17 | 5 MB | 5 MB | 9 MB | 6.7/6.6/3.3 | 30 | NOISY |
| instruments | 0.22 MB | 5.20 ms (5.87 ms) | 4.04 ms (4.31 ms) | 25.0 ms (31.2 ms) | 0.78× [0.75, 0.80] | 4.81× [4.71, 4.93] | 42.41 | 54.51 | 8.81 | 4 MB | 4 MB | 9 MB | 4.9/4.6/7.9 | 30 | NOISY |
| npm_cli_lock | 0.44 MB | 12.2 ms (16.7 ms) | 9.50 ms (10.5 ms) | 44.4 ms (48.3 ms) | 0.78× [0.75, 0.80] | 3.62× [3.53, 3.71] | 35.73 | 46.04 | 9.86 | 6 MB | 6 MB | 14 MB | 11.1/6.5/5.4 | 30 | NOISY |
| flights_5k | 0.45 MB | 16.0 ms (17.1 ms) | 11.4 ms (13.3 ms) | 71.4 ms (76.2 ms) | 0.71× [0.70, 0.74] | 4.47× [4.38, 4.57] | 27.93 | 39.21 | 6.25 | 9 MB | 9 MB | 15 MB | 4.6/8.8/4.0 | 30 | NOISY |
| random | 0.51 MB | 14.8 ms (16.8 ms) | 10.8 ms (11.6 ms) | 73.3 ms (82.9 ms) | 0.73× [0.71, 0.76] | 4.96× [4.79, 5.11] | 34.52 | 47.08 | 6.96 | 8 MB | 8 MB | 16 MB | 5.6/4.0/5.0 | 30 | NOISY |
| update_center | 0.53 MB | 15.5 ms (17.0 ms) | 11.6 ms (12.7 ms) | 67.7 ms (75.1 ms) | 0.75× [0.74, 0.76] | 4.38× [4.29, 4.48] | 34.46 | 45.81 | 7.87 | 8 MB | 8 MB | 18 MB | 4.6/3.8/4.6 | 30 | MEASURED |
| twitterescaped | 0.56 MB | 13.2 ms (14.1 ms) | 9.25 ms (11.1 ms) | 67.0 ms (73.0 ms) | 0.70× [0.68, 0.74] | 5.09× [4.97, 5.21] | 42.71 | 60.81 | 8.39 | 7 MB | 7 MB | 17 MB | 6.1/7.7/4.5 | 30 | NOISY |
| twitter | 0.63 MB | 12.7 ms (15.0 ms) | 9.26 ms (10.3 ms) | 66.6 ms (75.4 ms) | 0.73× [0.71, 0.74] | 5.24× [5.09, 5.34] | 49.74 | 68.19 | 9.49 | 7 MB | 7 MB | 19 MB | 8.7/5.5/4.7 | 30 | NOISY |
| us_10m | 0.64 MB | 66.0 ms (73.0 ms) | 43.1 ms (48.6 ms) | 175.1 ms (182.5 ms) | 0.65× [0.63, 0.67] | 2.65× [2.60, 2.68] | 9.74 | 14.91 | 3.67 | 25 MB | 25 MB | 37 MB | 5.0/6.6/3.2 | 30 | NOISY |
| mesh | 0.72 MB | 29.3 ms (30.2 ms) | 15.8 ms (17.5 ms) | 281.0 ms (293.7 ms) | 0.54× [0.53, 0.55] | 9.58× [9.49, 9.66] | 24.67 | 45.94 | 2.58 | 11 MB | 11 MB | 25 MB | 2.0/4.9/1.6 | 30 | MEASURED |
| vscode_lock | 0.78 MB | 17.0 ms (18.6 ms) | 12.9 ms (14.4 ms) | 74.5 ms (80.3 ms) | 0.76× [0.73, 0.77] | 4.39× [4.24, 4.47] | 46.04 | 60.80 | 10.49 | 8 MB | 8 MB | 22 MB | 8.1/6.8/4.2 | 30 | NOISY |
| flights_10k | 0.89 MB | 32.8 ms (45.7 ms) | 22.9 ms (25.2 ms) | 146.9 ms (156.0 ms) | 0.70× [0.67, 0.74] | 4.48× [4.34, 4.74] | 27.19 | 39.05 | 6.07 | 15 MB | 15 MB | 26 MB | 13.6/5.5/2.8 | 30 | NOISY |
| jobs | 0.94 MB | 26.4 ms (27.6 ms) | 17.8 ms (19.5 ms) | 273.5 ms (285.0 ms) | 0.67× [0.66, 0.70] | 10.37× [10.15, 10.56] | 35.50 | 52.71 | 3.42 | 12 MB | 12 MB | 27 MB | 3.6/4.3/2.1 | 30 | MEASURED |
| football | 1.21 MB | 21.3 ms (23.2 ms) | 15.9 ms (16.8 ms) | 163.8 ms (170.3 ms) | 0.75× [0.73, 0.76] | 7.70× [7.56, 7.79] | 56.72 | 75.69 | 7.37 | 11 MB | 12 MB | 33 MB | 3.4/2.4/1.9 | 30 | MEASURED |
| earthquakes | 1.22 MB | 43.5 ms (45.7 ms) | 29.2 ms (32.0 ms) | 288.8 ms (295.4 ms) | 0.67× [0.66, 0.70] | 6.64× [6.52, 6.86] | 28.04 | 41.84 | 4.22 | 17 MB | 17 MB | 42 MB | 3.9/5.8/2.0 | 30 | NOISY |
| movies | 1.40 MB | 36.6 ms (38.8 ms) | 25.7 ms (29.2 ms) | 275.0 ms (280.0 ms) | 0.70× [0.67, 0.73] | 7.51× [7.32, 7.76] | 38.21 | 54.48 | 5.09 | 17 MB | 17 MB | 38 MB | 4.7/6.8/1.3 | 30 | NOISY |
| citm_catalog | 1.73 MB | 25.9 ms (27.9 ms) | 17.8 ms (20.6 ms) | 192.7 ms (199.4 ms) | 0.69× [0.66, 0.72] | 7.43× [7.22, 7.69] | 66.57 | 97.08 | 8.96 | 12 MB | 12 MB | 45 MB | 5.9/7.4/2.3 | 30 | NOISY |
| flights_20k | 1.78 MB | 68.8 ms (79.2 ms) | 48.0 ms (53.2 ms) | 298.8 ms (307.1 ms) | 0.70× [0.67, 0.72] | 4.34× [4.22, 4.42] | 25.93 | 37.21 | 5.97 | 27 MB | 27 MB | 50 MB | 5.9/4.9/1.4 | 30 | NOISY |
| canada | 2.25 MB | 96.0 ms (99.5 ms) | 49.7 ms (52.3 ms) | 989.7 ms (1.01 s) | 0.52× [0.50, 0.53] | 10.31× [10.14, 10.44] | 23.44 | 45.28 | 2.27 | 30 MB | 30 MB | 131 MB | 2.7/3.0/1.1 | 26 | MEASURED |
| marine_ik | 2.98 MB | 130.4 ms (133.4 ms) | 76.6 ms (81.3 ms) | 994.9 ms (1.01 s) | 0.59× [0.58, 0.60] | 7.63× [7.53, 7.74] | 22.87 | 38.97 | 3.00 | 37 MB | 37 MB | 125 MB | 2.2/4.0/0.9 | 24 | MEASURED |
| gsoc_2018 | 3.33 MB | 39.5 ms (41.2 ms) | 26.6 ms (28.6 ms) | 269.4 ms (279.8 ms) | 0.67× [0.66, 0.69] | 6.81× [6.70, 6.94] | 84.16 | 124.88 | 12.35 | 17 MB | 17 MB | 83 MB | 3.2/4.0/1.5 | 30 | MEASURED |
| semanticscholar | 8.59 MB | 187.9 ms (195.6 ms) | 140.2 ms (145.2 ms) | 1.12 s (1.13 s) | 0.75× [0.74, 0.76] | 5.94× [5.89, 6.00] | 45.74 | 61.31 | 7.70 | 67 MB | 67 MB | 225 MB | 2.1/2.5/0.6 | 20 | MEASURED |
| flights_200k | 9.86 MB | 376.1 ms (392.9 ms) | 236.9 ms (242.5 ms) | 2.99 s (3.01 s) | 0.63× [0.61, 0.64] | 7.96× [7.86, 8.04] | 26.22 | 41.63 | 3.29 | 122 MB | 122 MB | 288 MB | 1.9/1.6/0.4 | 8 | MEASURED |
| openapi_github | 13.01 MB | 297.2 ms (314.5 ms) | 230.0 ms (240.3 ms) | 1.43 s (1.46 s) | 0.77× [0.75, 0.79] | 4.82× [4.71, 4.92] | 43.79 | 56.58 | 9.09 | 89 MB | 89 MB | 317 MB | 2.6/3.1/1.1 | 15 | MEASURED |

## encode_stats

| document | input | rust_z median (p95) | rust_o3 median (p95) | bend median (p95) | rust_o3/rust_z [95% CI] | bend/rust_z [95% CI] | rust_z MB/s | rust_o3 MB/s | bend MB/s | rust_z peak RSS | rust_o3 peak RSS | bend peak RSS | cv % (rust_z/rust_o3/bend) | n | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| github_events | 0.07 MB | 3.45 ms (3.76 ms) | 2.17 ms (2.28 ms) | 10.3 ms (11.1 ms) | 0.63× [0.62, 0.64] | 2.99× [2.94, 3.03] | 18.86 | 29.96 | 6.30 | 3 MB | 3 MB | 6 MB | 5.6/2.4/3.9 | 30 | NOISY |
| apache_builds | 0.13 MB | 4.70 ms (4.96 ms) | 2.87 ms (3.00 ms) | 19.6 ms (21.2 ms) | 0.61× [0.60, 0.62] | 4.18× [4.09, 4.22] | 27.09 | 44.29 | 6.48 | 3 MB | 4 MB | 10 MB | 2.9/3.8/2.9 | 30 | MEASURED |
| numbers | 0.15 MB | 8.24 ms (8.79 ms) | 3.92 ms (4.15 ms) | 80.3 ms (84.1 ms) | 0.48× [0.46, 0.48] | 9.75× [9.55, 9.88] | 18.22 | 38.33 | 1.87 | 4 MB | 4 MB | 11 MB | 4.2/3.3/2.1 | 30 | MEASURED |
| flights_2k | 0.18 MB | 9.04 ms (10.6 ms) | 5.71 ms (6.48 ms) | 37.1 ms (38.5 ms) | 0.63× [0.61, 0.65] | 4.10× [4.02, 4.13] | 19.74 | 31.28 | 4.82 | 5 MB | 5 MB | 12 MB | 5.8/7.1/1.7 | 30 | NOISY |
| unemployment | 0.19 MB | 9.35 ms (9.96 ms) | 5.56 ms (6.89 ms) | 45.2 ms (47.3 ms) | 0.59× [0.58, 0.61] | 4.84× [4.74, 4.90] | 19.85 | 33.38 | 4.10 | 5 MB | 5 MB | 13 MB | 6.8/7.7/3.1 | 30 | NOISY |
| instruments | 0.22 MB | 8.35 ms (9.85 ms) | 4.68 ms (5.52 ms) | 36.3 ms (39.5 ms) | 0.56× [0.54, 0.57] | 4.35× [4.21, 4.44] | 26.38 | 47.10 | 6.06 | 4 MB | 4 MB | 14 MB | 6.5/10.1/4.3 | 30 | NOISY |
| npm_cli_lock | 0.44 MB | 19.4 ms (20.9 ms) | 11.3 ms (12.9 ms) | 69.7 ms (74.1 ms) | 0.58× [0.57, 0.60] | 3.60× [3.52, 3.70] | 22.58 | 38.69 | 6.27 | 6 MB | 6 MB | 24 MB | 6.5/6.0/3.0 | 30 | NOISY |
| flights_5k | 0.45 MB | 21.5 ms (23.9 ms) | 12.4 ms (13.8 ms) | 93.8 ms (99.6 ms) | 0.58× [0.57, 0.60] | 4.36× [4.29, 4.46] | 20.77 | 35.90 | 4.76 | 9 MB | 9 MB | 25 MB | 4.3/5.0/3.4 | 30 | NOISY |
| random | 0.51 MB | 23.8 ms (28.4 ms) | 12.7 ms (14.9 ms) | 104.9 ms (121.1 ms) | 0.53× [0.51, 0.55] | 4.41× [4.23, 4.63] | 21.48 | 40.29 | 4.87 | 8 MB | 8 MB | 26 MB | 6.7/8.2/8.0 | 30 | NOISY |
| update_center | 0.53 MB | 25.9 ms (28.2 ms) | 14.1 ms (15.2 ms) | 104.1 ms (116.7 ms) | 0.55× [0.54, 0.56] | 4.02× [3.92, 4.09] | 20.56 | 37.72 | 5.12 | 8 MB | 8 MB | 30 MB | 3.7/8.3/7.3 | 30 | NOISY |
| twitterescaped | 0.56 MB | 22.9 ms (25.1 ms) | 11.4 ms (12.6 ms) | 102.8 ms (108.8 ms) | 0.50× [0.49, 0.51] | 4.50× [4.37, 4.63] | 24.61 | 49.15 | 5.47 | 7 MB | 7 MB | 30 MB | 4.0/5.1/3.7 | 30 | NOISY |
| twitter | 0.63 MB | 23.5 ms (24.9 ms) | 11.4 ms (13.1 ms) | 103.8 ms (112.7 ms) | 0.49× [0.48, 0.50] | 4.42× [4.35, 4.50] | 26.91 | 55.43 | 6.08 | 7 MB | 7 MB | 32 MB | 2.4/5.5/3.9 | 30 | NOISY |
| us_10m | 0.64 MB | 81.3 ms (88.9 ms) | 45.2 ms (49.1 ms) | 209.4 ms (217.8 ms) | 0.56× [0.54, 0.57] | 2.58× [2.51, 2.63] | 7.90 | 14.20 | 3.07 | 25 MB | 25 MB | 51 MB | 5.1/4.4/2.6 | 30 | NOISY |
| mesh | 0.72 MB | 41.1 ms (43.9 ms) | 17.9 ms (19.2 ms) | 323.2 ms (335.2 ms) | 0.44× [0.43, 0.44] | 7.86× [7.79, 7.95] | 17.61 | 40.41 | 2.24 | 11 MB | 11 MB | 42 MB | 5.2/2.9/1.7 | 30 | NOISY |
| vscode_lock | 0.78 MB | 30.3 ms (32.1 ms) | 16.0 ms (18.2 ms) | 122.0 ms (127.4 ms) | 0.53× [0.52, 0.54] | 4.03× [3.98, 4.11] | 25.81 | 48.95 | 6.41 | 8 MB | 8 MB | 40 MB | 2.9/5.9/2.4 | 30 | NOISY |
| flights_10k | 0.89 MB | 42.9 ms (45.7 ms) | 24.9 ms (28.2 ms) | 195.6 ms (204.3 ms) | 0.58× [0.56, 0.61] | 4.56× [4.46, 4.72] | 20.80 | 35.82 | 4.56 | 15 MB | 15 MB | 47 MB | 5.0/5.7/2.1 | 30 | NOISY |
| jobs | 0.94 MB | 37.8 ms (40.3 ms) | 20.7 ms (24.2 ms) | 330.7 ms (336.3 ms) | 0.55× [0.54, 0.56] | 8.76× [8.64, 8.86] | 24.80 | 45.26 | 2.83 | 12 MB | 12 MB | 49 MB | 3.3/7.0/1.2 | 30 | NOISY |
| football | 1.21 MB | 36.6 ms (38.7 ms) | 18.9 ms (20.3 ms) | 236.2 ms (249.6 ms) | 0.52× [0.51, 0.53] | 6.46× [6.35, 6.52] | 33.00 | 63.84 | 5.11 | 11 MB | 12 MB | 61 MB | 2.8/5.3/2.5 | 30 | NOISY |
| earthquakes | 1.22 MB | 69.8 ms (73.1 ms) | 35.8 ms (39.9 ms) | 378.8 ms (388.5 ms) | 0.51× [0.50, 0.52] | 5.42× [5.34, 5.46] | 17.47 | 34.06 | 3.22 | 17 MB | 17 MB | 70 MB | 2.6/4.6/1.7 | 30 | MEASURED |
| movies | 1.40 MB | 55.6 ms (59.7 ms) | 29.1 ms (32.8 ms) | 353.5 ms (363.5 ms) | 0.52× [0.51, 0.54] | 6.35× [6.19, 6.42] | 25.16 | 48.09 | 3.96 | 17 MB | 17 MB | 70 MB | 3.5/5.6/1.3 | 30 | NOISY |
| citm_catalog | 1.73 MB | 48.9 ms (54.6 ms) | 22.1 ms (27.1 ms) | 294.5 ms (310.4 ms) | 0.45× [0.43, 0.46] | 6.02× [5.78, 6.16] | 35.29 | 78.05 | 5.86 | 12 MB | 12 MB | 85 MB | 5.6/9.9/2.4 | 30 | NOISY |
| flights_20k | 1.78 MB | 88.2 ms (92.6 ms) | 51.7 ms (57.9 ms) | 390.6 ms (400.6 ms) | 0.59× [0.57, 0.60] | 4.43× [4.36, 4.51] | 20.24 | 34.55 | 4.57 | 27 MB | 27 MB | 91 MB | 3.1/5.1/1.1 | 30 | NOISY |
| canada | 2.25 MB | 134.0 ms (140.8 ms) | 57.8 ms (58.7 ms) | 1.12 s (1.14 s) | 0.43× [0.42, 0.44] | 8.36× [8.18, 8.47] | 16.80 | 38.96 | 2.01 | 30 MB | 30 MB | 181 MB | 2.4/2.2/1.2 | 22 | MEASURED |
| marine_ik | 2.98 MB | 174.6 ms (183.4 ms) | 85.3 ms (90.5 ms) | 1.14 s (1.15 s) | 0.49× [0.47, 0.50] | 6.54× [6.35, 6.58] | 17.08 | 34.96 | 2.61 | 37 MB | 37 MB | 193 MB | 2.5/3.2/0.7 | 21 | MEASURED |
| gsoc_2018 | 3.33 MB | 112.1 ms (116.6 ms) | 49.1 ms (52.1 ms) | 447.4 ms (453.1 ms) | 0.44× [0.43, 0.44] | 3.99× [3.94, 4.02] | 29.69 | 67.77 | 7.44 | 17 MB | 17 MB | 159 MB | 2.4/2.7/0.9 | 30 | MEASURED |
| semanticscholar | 8.59 MB | 380.2 ms (385.5 ms) | 194.2 ms (202.7 ms) | 1.62 s (1.64 s) | 0.51× [0.50, 0.52] | 4.27× [4.24, 4.31] | 22.60 | 44.26 | 5.29 | 67 MB | 67 MB | 419 MB | 1.7/2.7/0.7 | 13 | MEASURED |
| flights_200k | 9.86 MB | 483.5 ms (500.2 ms) | 260.1 ms (278.2 ms) | 3.52 s (3.54 s) | 0.54× [0.53, 0.55] | 7.28× [7.14, 7.37] | 20.40 | 37.92 | 2.80 | 122 MB | 122 MB | 514 MB | 1.8/2.9/0.8 | 7 | MEASURED |
| openapi_github | 13.01 MB | 517.7 ms (526.5 ms) | 279.1 ms (286.4 ms) | 2.19 s (2.22 s) | 0.54× [0.52, 0.55] | 4.22× [4.17, 4.28] | 25.14 | 46.63 | 5.95 | 89 MB | 89 MB | 614 MB | 0.9/2.4/1.1 | 9 | MEASURED |

## decode

| document | input | rust_z median (p95) | rust_o3 median (p95) | bend median (p95) | rust_o3/rust_z [95% CI] | bend/rust_z [95% CI] | rust_z MB/s | rust_o3 MB/s | bend MB/s | rust_z peak RSS | rust_o3 peak RSS | bend peak RSS | cv % (rust_z/rust_o3/bend) | n | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| github_events | 0.06 MB | 2.53 ms (2.79 ms) | 1.96 ms (2.14 ms) | 7.41 ms (7.61 ms) | 0.77× [0.76, 0.79] | 2.92× [2.90, 2.95] | 23.36 | 30.20 | 7.99 | 3 MB | 3 MB | 5 MB | 5.1/3.4/1.5 | 30 | NOISY |
| apache_builds | 0.07 MB | 4.20 ms (4.50 ms) | 2.80 ms (3.24 ms) | 9.54 ms (11.4 ms) | 0.67× [0.65, 0.69] | 2.27× [2.20, 2.32] | 17.31 | 26.00 | 7.62 | 3 MB | 4 MB | 6 MB | 4.7/6.2/6.8 | 30 | NOISY |
| numbers | 0.15 MB | 11.9 ms (12.6 ms) | 5.97 ms (6.65 ms) | 77.3 ms (83.5 ms) | 0.50× [0.49, 0.51] | 6.48× [6.36, 6.56] | 12.58 | 25.13 | 1.94 | 5 MB | 5 MB | 8 MB | 2.8/5.4/4.3 | 30 | NOISY |
| flights_2k | 0.07 MB | 9.83 ms (10.5 ms) | 6.34 ms (7.32 ms) | 18.6 ms (19.6 ms) | 0.64× [0.64, 0.66] | 1.89× [1.88, 1.92] | 7.38 | 11.45 | 3.90 | 5 MB | 6 MB | 10 MB | 2.7/5.7/2.1 | 30 | NOISY |
| unemployment | 0.10 MB | 10.9 ms (12.4 ms) | 6.54 ms (7.15 ms) | 27.3 ms (30.4 ms) | 0.60× [0.58, 0.62] | 2.50× [2.45, 2.57] | 9.51 | 15.86 | 3.80 | 5 MB | 5 MB | 10 MB | 7.8/9.9/5.6 | 30 | NOISY |
| instruments | 0.11 MB | 7.49 ms (8.60 ms) | 5.13 ms (6.26 ms) | 22.8 ms (25.0 ms) | 0.69× [0.66, 0.70] | 3.04× [2.97, 3.12] | 14.33 | 20.92 | 4.72 | 4 MB | 5 MB | 8 MB | 8.4/10.8/4.0 | 30 | NOISY |
| npm_cli_lock | 0.34 MB | 14.7 ms (17.2 ms) | 10.3 ms (11.2 ms) | 56.5 ms (59.4 ms) | 0.70× [0.69, 0.71] | 3.84× [3.73, 3.93] | 23.24 | 33.12 | 6.05 | 7 MB | 7 MB | 14 MB | 6.0/4.0/3.6 | 30 | NOISY |
| flights_5k | 0.18 MB | 23.4 ms (27.5 ms) | 14.3 ms (15.4 ms) | 46.7 ms (49.6 ms) | 0.61× [0.59, 0.62] | 1.99× [1.94, 2.05] | 7.74 | 12.71 | 3.88 | 10 MB | 10 MB | 19 MB | 6.9/3.5/3.0 | 30 | NOISY |
| random | 0.44 MB | 21.7 ms (22.8 ms) | 13.7 ms (14.5 ms) | 77.6 ms (84.8 ms) | 0.63× [0.63, 0.64] | 3.58× [3.47, 3.66] | 20.11 | 31.76 | 5.62 | 8 MB | 9 MB | 22 MB | 3.5/4.3/5.3 | 30 | NOISY |
| update_center | 0.55 MB | 20.2 ms (21.8 ms) | 13.3 ms (14.4 ms) | 77.6 ms (90.1 ms) | 0.66× [0.64, 0.67] | 3.85× [3.70, 3.96] | 27.16 | 41.10 | 7.05 | 8 MB | 8 MB | 22 MB | 8.6/4.2/7.2 | 30 | NOISY |
| twitterescaped | 0.54 MB | 17.8 ms (19.0 ms) | 12.0 ms (12.7 ms) | 77.2 ms (89.0 ms) | 0.68× [0.66, 0.69] | 4.35× [4.22, 4.44] | 30.16 | 44.62 | 6.94 | 8 MB | 8 MB | 17 MB | 3.8/3.1/5.5 | 30 | NOISY |
| twitter | 0.54 MB | 17.6 ms (18.9 ms) | 11.9 ms (13.6 ms) | 73.6 ms (84.2 ms) | 0.67× [0.66, 0.69] | 4.17× [4.07, 4.31] | 30.35 | 45.15 | 7.28 | 8 MB | 8 MB | 17 MB | 4.0/5.3/5.7 | 30 | NOISY |
| us_10m | 1.13 MB | 112.5 ms (120.3 ms) | 57.3 ms (61.8 ms) | 335.0 ms (349.1 ms) | 0.51× [0.50, 0.52] | 2.98× [2.92, 3.05] | 10.07 | 19.76 | 3.38 | 29 MB | 30 MB | 65 MB | 3.4/3.7/2.3 | 30 | MEASURED |
| mesh | 0.67 MB | 59.3 ms (62.1 ms) | 26.5 ms (28.3 ms) | 311.5 ms (322.5 ms) | 0.45× [0.44, 0.46] | 5.25× [5.19, 5.34] | 11.26 | 25.23 | 2.14 | 13 MB | 13 MB | 31 MB | 2.8/3.2/1.6 | 30 | MEASURED |
| vscode_lock | 0.65 MB | 20.7 ms (22.3 ms) | 14.3 ms (15.1 ms) | 100.0 ms (112.6 ms) | 0.69× [0.68, 0.70] | 4.82× [4.63, 4.93] | 31.39 | 45.48 | 6.51 | 9 MB | 9 MB | 22 MB | 3.8/2.4/7.3 | 30 | NOISY |
| flights_10k | 0.36 MB | 45.2 ms (47.7 ms) | 27.1 ms (29.9 ms) | 95.9 ms (102.4 ms) | 0.60× [0.59, 0.61] | 2.12× [2.08, 2.17] | 8.02 | 13.38 | 3.78 | 17 MB | 17 MB | 35 MB | 2.8/4.6/4.1 | 30 | MEASURED |
| jobs | 0.37 MB | 41.0 ms (47.9 ms) | 22.5 ms (24.6 ms) | 242.7 ms (253.0 ms) | 0.55× [0.54, 0.56] | 5.91× [5.82, 6.05] | 9.03 | 16.46 | 1.53 | 14 MB | 14 MB | 27 MB | 5.0/3.7/2.4 | 30 | MEASURED |
| football | 0.37 MB | 32.7 ms (34.6 ms) | 20.0 ms (20.4 ms) | 82.0 ms (88.8 ms) | 0.61× [0.60, 0.62] | 2.51× [2.47, 2.60] | 11.46 | 18.75 | 4.56 | 13 MB | 13 MB | 32 MB | 2.5/2.1/3.6 | 30 | MEASURED |
| earthquakes | 1.44 MB | 66.5 ms (70.3 ms) | 38.5 ms (41.5 ms) | 396.1 ms (410.7 ms) | 0.58× [0.57, 0.59] | 5.96× [5.88, 6.05] | 21.72 | 37.51 | 3.65 | 18 MB | 18 MB | 50 MB | 2.7/3.6/2.0 | 30 | MEASURED |
| movies | 0.48 MB | 56.4 ms (60.8 ms) | 33.4 ms (37.8 ms) | 145.4 ms (152.3 ms) | 0.59× [0.58, 0.61] | 2.58× [2.54, 2.63] | 8.55 | 14.45 | 3.32 | 16 MB | 16 MB | 44 MB | 4.4/6.2/2.5 | 30 | NOISY |
| citm_catalog | 0.67 MB | 38.3 ms (46.8 ms) | 21.4 ms (27.0 ms) | 181.6 ms (207.4 ms) | 0.56× [0.54, 0.57] | 4.75× [4.60, 4.96] | 17.41 | 31.07 | 3.67 | 12 MB | 12 MB | 33 MB | 12.4/11.3/6.7 | 30 | NOISY |
| flights_20k | 0.72 MB | 89.6 ms (92.3 ms) | 54.3 ms (58.0 ms) | 204.3 ms (222.5 ms) | 0.61× [0.60, 0.61] | 2.28× [2.24, 2.32] | 8.09 | 13.34 | 3.55 | 32 MB | 32 MB | 67 MB | 1.7/3.7/3.6 | 30 | MEASURED |
| canada | 2.93 MB | 177.6 ms (193.1 ms) | 72.8 ms (76.7 ms) | 1.34 s (1.38 s) | 0.41× [0.40, 0.42] | 7.54× [7.38, 7.63] | 16.50 | 40.26 | 2.19 | 33 MB | 33 MB | 131 MB | 2.6/2.2/1.5 | 18 | MEASURED |
| marine_ik | 2.48 MB | 219.4 ms (228.6 ms) | 96.3 ms (99.7 ms) | 1.32 s (1.35 s) | 0.44× [0.43, 0.45] | 6.03× [5.96, 6.11] | 11.31 | 25.77 | 1.88 | 45 MB | 45 MB | 187 MB | 1.9/1.8/0.9 | 18 | MEASURED |
| gsoc_2018 | 3.09 MB | 52.5 ms (58.0 ms) | 32.0 ms (36.9 ms) | 299.6 ms (324.9 ms) | 0.61× [0.59, 0.62] | 5.70× [5.62, 5.81] | 58.86 | 96.71 | 10.32 | 22 MB | 22 MB | 80 MB | 6.1/6.1/5.2 | 30 | NOISY |
| semanticscholar | 8.92 MB | 268.1 ms (275.3 ms) | 165.1 ms (178.1 ms) | 1.33 s (1.35 s) | 0.62× [0.61, 0.63] | 4.97× [4.92, 5.00] | 33.27 | 54.02 | 6.69 | 69 MB | 69 MB | 252 MB | 1.4/2.7/0.9 | 16 | MEASURED |
| flights_200k | 4.65 MB | 668.2 ms (678.7 ms) | 343.2 ms (364.0 ms) | 2.84 s (2.87 s) | 0.51× [0.50, 0.52] | 4.25× [4.18, 4.29] | 6.96 | 13.55 | 1.64 | 164 MB | 164 MB | 389 MB | 0.9/2.7/1.1 | 7 | MEASURED |
| openapi_github | 9.33 MB | 342.9 ms (368.5 ms) | 234.9 ms (268.2 ms) | 1.76 s (1.81 s) | 0.69× [0.66, 0.71] | 5.12× [4.94, 5.27] | 27.21 | 39.72 | 5.31 | 94 MB | 95 MB | 322 MB | 3.5/5.2/2.2 | 12 | NOISY |
| semsch_625 | 1.02 MB | 29.5 ms (31.7 ms) | 18.4 ms (20.8 ms) | 127.3 ms (133.4 ms) | 0.62× [0.61, 0.64] | 4.32× [4.21, 4.40] | 34.67 | 55.65 | 8.03 | 11 MB | 12 MB | 32 MB | 5.7/6.7/3.7 | 30 | NOISY |
| semsch_1250 | 2.18 MB | 62.4 ms (67.6 ms) | 36.3 ms (40.6 ms) | 296.7 ms (314.0 ms) | 0.58× [0.57, 0.61] | 4.75× [4.68, 4.95] | 34.86 | 60.02 | 7.34 | 19 MB | 19 MB | 64 MB | 4.4/6.2/2.9 | 30 | NOISY |
| semsch_2500 | 4.43 MB | 132.3 ms (138.6 ms) | 79.5 ms (85.6 ms) | 651.2 ms (678.1 ms) | 0.60× [0.59, 0.62] | 4.92× [4.87, 5.03] | 33.48 | 55.73 | 6.80 | 36 MB | 36 MB | 127 MB | 3.0/4.7/1.7 | 30 | MEASURED |
| semsch_5000 | 8.92 MB | 270.2 ms (280.8 ms) | 166.8 ms (172.6 ms) | 1.34 s (1.36 s) | 0.62× [0.60, 0.63] | 4.98× [4.87, 5.02] | 33.02 | 53.46 | 6.63 | 69 MB | 69 MB | 252 MB | 2.0/2.0/0.8 | 16 | MEASURED |

## decode_expand

| document | input | rust_z median (p95) | rust_o3 median (p95) | bend median (p95) | rust_o3/rust_z [95% CI] | bend/rust_z [95% CI] | rust_z MB/s | rust_o3 MB/s | bend MB/s | rust_z peak RSS | rust_o3 peak RSS | bend peak RSS | cv % (rust_z/rust_o3/bend) | n | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| github_events | 0.06 MB | 2.63 ms (2.80 ms) | 2.06 ms (2.15 ms) | 10.2 ms (11.2 ms) | 0.78× [0.77, 0.79] | 3.86× [3.83, 3.91] | 22.29 | 28.53 | 5.78 | 3 MB | 3 MB | 5 MB | 4.2/2.8/3.3 | 30 | MEASURED |
| apache_builds | 0.07 MB | 4.37 ms (5.68 ms) | 2.87 ms (3.12 ms) | 14.7 ms (15.5 ms) | 0.66× [0.64, 0.67] | 3.37× [3.34, 3.43] | 16.66 | 25.33 | 4.94 | 3 MB | 4 MB | 7 MB | 7.9/5.7/2.2 | 30 | NOISY |
| numbers | 0.15 MB | 12.5 ms (13.6 ms) | 6.43 ms (6.93 ms) | 77.9 ms (79.8 ms) | 0.52× [0.51, 0.52] | 6.25× [6.20, 6.32] | 12.04 | 23.35 | 1.93 | 5 MB | 5 MB | 8 MB | 3.8/3.2/1.7 | 30 | MEASURED |
| flights_2k | 0.07 MB | 10.6 ms (11.3 ms) | 6.97 ms (8.25 ms) | 41.0 ms (43.9 ms) | 0.65× [0.63, 0.68] | 3.85× [3.78, 3.94] | 6.81 | 10.40 | 1.77 | 5 MB | 6 MB | 11 MB | 3.6/7.6/3.3 | 30 | NOISY |
| unemployment | 0.10 MB | 11.4 ms (13.5 ms) | 6.85 ms (8.02 ms) | 49.4 ms (53.8 ms) | 0.60× [0.58, 0.61] | 4.33× [4.20, 4.37] | 9.08 | 15.13 | 2.10 | 5 MB | 5 MB | 11 MB | 6.7/6.5/3.6 | 30 | NOISY |
| instruments | 0.11 MB | 7.97 ms (8.90 ms) | 5.55 ms (5.81 ms) | 39.9 ms (41.7 ms) | 0.70× [0.68, 0.72] | 5.01× [4.91, 5.13] | 13.47 | 19.36 | 2.69 | 4 MB | 5 MB | 11 MB | 5.0/6.0/2.8 | 30 | NOISY |
| npm_cli_lock | 0.33 MB | 16.5 ms (17.6 ms) | 11.2 ms (11.6 ms) | 98.6 ms (106.2 ms) | 0.68× [0.67, 0.69] | 5.98× [5.87, 6.21] | 20.27 | 29.94 | 3.39 | 6 MB | 6 MB | 20 MB | 3.7/2.6/5.0 | 30 | MEASURED |
| flights_5k | 0.18 MB | 24.6 ms (27.3 ms) | 15.3 ms (17.5 ms) | 101.1 ms (104.0 ms) | 0.62× [0.61, 0.64] | 4.10× [4.06, 4.19] | 7.35 | 11.84 | 1.79 | 10 MB | 10 MB | 23 MB | 4.2/6.4/1.7 | 30 | NOISY |
| random | 0.44 MB | 22.8 ms (24.4 ms) | 14.5 ms (16.4 ms) | 125.0 ms (142.4 ms) | 0.64× [0.62, 0.65] | 5.49× [5.35, 5.71] | 19.18 | 30.07 | 3.49 | 8 MB | 9 MB | 25 MB | 3.5/5.7/5.6 | 30 | NOISY |
| update_center | 0.55 MB | 21.5 ms (24.7 ms) | 14.2 ms (15.3 ms) | 120.3 ms (130.9 ms) | 0.66× [0.65, 0.67] | 5.59× [5.44, 5.75] | 25.42 | 38.65 | 4.55 | 8 MB | 8 MB | 27 MB | 4.5/3.0/5.1 | 30 | NOISY |
| twitterescaped | 0.53 MB | 18.6 ms (20.2 ms) | 12.3 ms (13.6 ms) | 118.3 ms (128.0 ms) | 0.66× [0.66, 0.67] | 6.36× [6.24, 6.45] | 28.58 | 43.05 | 4.49 | 8 MB | 8 MB | 25 MB | 3.2/3.8/5.1 | 30 | NOISY |
| twitter | 0.53 MB | 18.4 ms (19.8 ms) | 12.3 ms (13.1 ms) | 113.6 ms (122.3 ms) | 0.67× [0.66, 0.68] | 6.19× [6.00, 6.33] | 28.93 | 43.09 | 4.68 | 8 MB | 8 MB | 25 MB | 3.4/2.8/4.2 | 30 | MEASURED |
| us_10m | 1.13 MB | 116.0 ms (131.1 ms) | 62.8 ms (66.5 ms) | 382.9 ms (406.3 ms) | 0.54× [0.52, 0.55] | 3.30× [3.23, 3.37] | 9.77 | 18.04 | 2.96 | 29 MB | 30 MB | 67 MB | 4.5/3.4/2.9 | 30 | MEASURED |
| mesh | 0.67 MB | 62.3 ms (71.4 ms) | 29.2 ms (30.8 ms) | 322.7 ms (334.5 ms) | 0.47× [0.46, 0.48] | 5.18× [5.12, 5.22] | 10.73 | 22.90 | 2.07 | 13 MB | 13 MB | 31 MB | 4.5/3.1/2.4 | 30 | MEASURED |
| vscode_lock | 0.64 MB | 23.5 ms (25.8 ms) | 15.8 ms (17.1 ms) | 166.7 ms (175.7 ms) | 0.67× [0.66, 0.68] | 7.09× [6.88, 7.18] | 27.25 | 40.45 | 3.84 | 8 MB | 8 MB | 31 MB | 3.9/3.8/3.4 | 30 | MEASURED |
| flights_10k | 0.36 MB | 48.8 ms (53.2 ms) | 29.4 ms (30.4 ms) | 211.5 ms (219.4 ms) | 0.60× [0.59, 0.61] | 4.34× [4.27, 4.42] | 7.43 | 12.33 | 1.71 | 17 MB | 17 MB | 43 MB | 5.6/2.0/2.2 | 30 | NOISY |
| jobs | 0.37 MB | 43.3 ms (45.6 ms) | 24.5 ms (26.6 ms) | 323.3 ms (335.2 ms) | 0.57× [0.56, 0.58] | 7.47× [7.35, 7.61] | 8.57 | 15.12 | 1.15 | 13 MB | 14 MB | 31 MB | 2.8/5.4/1.9 | 30 | NOISY |
| football | 0.37 MB | 34.9 ms (37.2 ms) | 21.7 ms (23.4 ms) | 174.2 ms (181.6 ms) | 0.62× [0.61, 0.63] | 4.99× [4.92, 5.05] | 10.72 | 17.26 | 2.15 | 13 MB | 13 MB | 39 MB | 3.0/3.3/2.2 | 30 | MEASURED |
| earthquakes | 1.44 MB | 68.7 ms (75.3 ms) | 40.1 ms (42.6 ms) | 517.4 ms (537.4 ms) | 0.58× [0.57, 0.60] | 7.53× [7.39, 7.59] | 21.03 | 35.99 | 2.79 | 18 MB | 18 MB | 62 MB | 4.0/3.0/1.9 | 30 | MEASURED |
| movies | 0.48 MB | 59.4 ms (66.4 ms) | 37.0 ms (39.0 ms) | 328.7 ms (335.3 ms) | 0.62× [0.60, 0.64] | 5.53× [5.38, 5.64] | 8.12 | 13.03 | 1.47 | 16 MB | 16 MB | 57 MB | 4.7/4.5/1.3 | 30 | MEASURED |
| citm_catalog | 0.67 MB | 38.5 ms (43.5 ms) | 22.6 ms (24.9 ms) | 248.1 ms (273.4 ms) | 0.59× [0.57, 0.60] | 6.44× [6.27, 6.58] | 17.28 | 29.52 | 2.68 | 12 MB | 13 MB | 41 MB | 5.3/4.0/4.7 | 30 | NOISY |
| flights_20k | 0.72 MB | 97.4 ms (102.0 ms) | 59.8 ms (65.8 ms) | 437.5 ms (454.2 ms) | 0.61× [0.60, 0.62] | 4.49× [4.43, 4.55] | 7.45 | 12.13 | 1.66 | 32 MB | 32 MB | 83 MB | 2.5/3.8/2.0 | 30 | MEASURED |
| canada | 2.93 MB | 180.9 ms (200.3 ms) | 77.7 ms (81.5 ms) | 1.36 s (1.40 s) | 0.43× [0.42, 0.44] | 7.54× [7.46, 7.61] | 16.20 | 37.70 | 2.15 | 33 MB | 33 MB | 131 MB | 2.9/2.2/0.9 | 18 | MEASURED |
| marine_ik | 2.48 MB | 240.0 ms (271.4 ms) | 114.1 ms (121.9 ms) | 1.47 s (1.50 s) | 0.48× [0.47, 0.48] | 6.14× [6.06, 6.22] | 10.34 | 21.75 | 1.68 | 45 MB | 46 MB | 193 MB | 3.7/3.1/0.9 | 16 | MEASURED |
| gsoc_2018 | 3.09 MB | 58.1 ms (63.0 ms) | 35.2 ms (37.4 ms) | 356.1 ms (374.7 ms) | 0.61× [0.59, 0.62] | 6.13× [6.03, 6.30] | 53.21 | 87.79 | 8.68 | 22 MB | 22 MB | 87 MB | 3.4/3.7/2.4 | 30 | MEASURED |
| semanticscholar | 8.92 MB | 299.2 ms (307.2 ms) | 191.2 ms (200.5 ms) | 1.65 s (1.69 s) | 0.64× [0.63, 0.65] | 5.53× [5.46, 5.63] | 29.81 | 46.66 | 5.39 | 76 MB | 77 MB | 294 MB | 2.0/2.1/1.2 | 14 | MEASURED |
| flights_200k | 4.65 MB | 706.6 ms (720.2 ms) | 372.0 ms (376.9 ms) | 4.14 s (4.17 s) | 0.53× [0.52, 0.54] | 5.86× [5.75, 6.01] | 6.58 | 12.50 | 1.12 | 164 MB | 164 MB | 467 MB | 1.6/0.9/0.7 | 5 | MEASURED |
| openapi_github | 9.01 MB | 389.1 ms (397.1 ms) | 258.1 ms (272.0 ms) | 2.37 s (2.40 s) | 0.66× [0.66, 0.69] | 6.09× [6.03, 6.18] | 23.15 | 34.91 | 3.80 | 95 MB | 95 MB | 398 MB | 1.5/2.6/0.9 | 9 | MEASURED |

