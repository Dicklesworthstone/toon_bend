# Experiments — toon_bend

<!-- One card per lever, written BEFORE the lever. Losses get cards too. -->

## Profile that motivates EXP-001 and EXP-002 (2026-09-20, before any lever)

Instrumented build of the emitted C (`clang -std=c11 -O2 -pg -fno-inline-functions`, 1 thread), input
`cases/inputs/hand/large_tabular_1500.json` (167255 bytes, 1500 uniform rows, 3000 numbers), `--encode`. Calls per Bend def
(`gprof -b -p`, specializations summed): `BN.cmp` 1072262, `BN.shr_bits` 495846, `BN.sub` 430276, `BN.div.step` 377037,
`BN.shl_bits` 359075, `BN.is_ge` 348872, `BN.is_lt` 348872, `J.run` 334511, `F.dg.digit` 276055, `BN.add` 192271,
`BN.mul_small` 173601, `BN.div.go` 172270, `J.step` 170255, `F.dg.step` 155070, `F.dg.gen` 152847. The number substrate
(big naturals under the shortest-digit generator and under the one correctly rounded division) is called about ten times more often than
the JSON reader's per-byte step. Wall time of the uninstrumented binary on the same input, maintenance numbers on a shared host (load 5):
port 97 ms, original 5.6 ms; decode of the 76989-byte TOON: port 62 ms, original 15.5 ms.

## EXP-001 — integer fast path in the two number printers

| field | value |
|---|---|
| experiment_id | EXP-001 |
| program / def | `port/f64.bend` / `show_toon`, `show_json` (fast twins `show_toon_fast`, `show_json_fast`) |
| created (UTC) | 2026-09-20 |
| agent | Claude (Claude Code session, author) |
| graveyard sweep | `rg -i 'fast.?path\|integer\|shortest\|digit' perf/NEGATIVE-EVIDENCE.md` → no entry |
| status | PROPOSED |
| precommitted | true |

### Hypothesis
For a finite value that is an integer below 2^53 the shortest round-trip digits are the integer's own decimal digits, so printing them
directly (no big-natural digit generation) lowers the median wall time of `--encode` on `large_tabular_1500.json` at 1 thread by at least 25%.

### Motivation
The profile above: `F.dg.*` and the `BN.*` calls under it dominate the call counts; half of that input's numbers are integers (`id`).

### Lever (one)
A second def per printer that tests "exponent ≥ 0 after stripping trailing zero bits, value below 2^53" and prints the digits of the
significand shifted left; every other value goes to the spec twin. Kill-switch `TOON_SPEC=1` selects the spec twin everywhere. Law: closed
instances `show_toon_fast(f) == show_toon(f)` on boundary values (0, 1, 10, 2^53 − 1, 2^53, a non-integer); a universal law needs the
correctness theorem of shortest-digit generation and is not attempted. Beside the law: the fast and spec twins compared on ≥ 10^6 generated
values by a native driver, and `lanes.sh` with and without the switch.

### Precommitted gate
≥ 25% below the baseline artifact (the parity-gate commit's binary) at `--threads 1`; cv ≤ 5% both arms; A/A null ratio in [1/1.05, 1.05];
identical stdout; `bend PROOF.bend` → `All terms check.`; lanes PASS with `TOON_SPEC` unset and set.

### One-line invocation
```bash
scripts/incumbent-bench.sh --runs 9 --max-cv 5 --tag EXP-001 --original <baseline binary> -- --encode cases/inputs/hand/large_tabular_1500.json --port <lever binary> -- --encode cases/inputs/hand/large_tabular_1500.json
```

## EXP-002 — exact small-integer path in the two number readers

| field | value |
|---|---|
| experiment_id | EXP-002 |
| program / def | `port/f64.bend` / `serde_value`, `token_value` (fast twins) |
| created (UTC) | 2026-09-20 |
| agent | Claude (Claude Code session, author) |
| graveyard sweep | `rg -i 'fast.?path\|integer\|divis' perf/NEGATIVE-EVIDENCE.md` → no entry |
| status | PROPOSED |
| precommitted | true |

### Hypothesis
A number text with no fraction, no exponent and at most 15 digits denotes an integer below 2^53 exactly, so building the value from a `Nat`
(no big-natural rounding) lowers the median wall time of `--decode` on the 76989-byte TOON of the same table at 1 thread by at least 15%.

### Motivation
`F.round` 22191 calls, `BN.from_dec` and `BN.pow10` under `token_value`; both readers agree on exact integers (S4.101, S4.143: exact
decimal, one rounding, and an integer below 2^53 needs none).

### Lever (one)
A second def per reader for the all-digit, at-most-15-digit case; everything else goes to the spec twin. Same kill-switch. Law: closed
instances on 0, 1, 999999999999999 and the first excluded length; beside it the twin-vs-twin native comparison and lanes under both settings.

### Precommitted gate
≥ 15% below the baseline artifact on the decode input at `--threads 1`; cv ≤ 5% both arms; A/A null ratio in [1/1.05, 1.05]; identical stdout;
proofs and lanes as EXP-001.

### One-line invocation
```bash
scripts/incumbent-bench.sh --runs 9 --max-cv 5 --tag EXP-002 --original <baseline binary> -- --decode <table.toon> --port <lever binary> -- --decode <table.toon>
```

## Second profile (2026-09-20, before EXP-003; t_next scratch build, 1 thread, maintenance numbers on a shared host)

Wall time split by value type, medians of 7 runs, JSON arrays of one value type through `--encode`:

| input | bytes | reader (bytes → `Json`) | encode + print | total | original |
|---|---|---|---|---|---|
| 7000 short strings | 166890 | 15.5 ms | 18.6 ms | 34.1 ms | 4.6 ms |
| 24000 six-digit integers | 192000 | 73.8 ms | 385.8 ms | 459.6 ms | 5.8 ms |
| 9000 one-decimal numbers | 77995 | 179.7 ms | 170.4 ms | 350.1 ms | 3.0 ms |
| 5999 seventeen-digit numbers | 115482 | 134.2 ms | 339.0 ms | 473.2 ms | 5.4 ms |

The reader costs about 20 µs per decimal number against 0.6 µs per string byte run: `BN.divmod` is a restoring division, one quotient
bit per step (57 steps per number, four passes over a seven-limb list each). Printing costs 16 µs per integer and 19–56 µs per decimal:
the shortest-digit generator takes each digit by repeated subtraction over big naturals.

## EXP-003 — exact division by a power of ten through single-limb short division

| field | value |
|---|---|
| experiment_id | EXP-003 |
| program / def | `port/bignat.bend` / `divmod` under `F.div` (the JSON reader's one division, S4.114) and under `F.from_dec` (the TOON token reader, S4.143) |
| created (UTC) | 2026-09-20 |
| agent | Claude (Claude Code session, author) |
| graveyard sweep | `rg -i 'divis\|short division\|pow10' perf/NEGATIVE-EVIDENCE.md` → no entry |
| status | PROPOSED |
| precommitted | true |

### Hypothesis
Dividing by 10^k (k ≤ 22 in the JSON reader, any k in the token reader) as a shift by k bits and ⌈k/6⌉ single-limb divisions by 5^6 = 15625
(each one pass from the most significant limb, remainders OR-ed into the sticky flag) gives the same floor quotient and the same sticky flag as
the restoring division, and lowers the median wall time of `--encode` on 9000 one-decimal numbers at 1 thread by at least 30%.

### Motivation
The second profile above: 179.7 ms of reader time for 9000 decimals; `BN.div.step` 377037 calls on the 1500-row table.

### Lever (one)
`BN.div_pow10(a, k) -> (quotient, sticky)` beside `BN.divmod`; `F.div10_fast` and `F.from_dec_fast` call it, the spec twins keep `divmod`.
Exactness argument: ⌊⌊a/x⌋/y⌋ = ⌊a/(xy)⌋ for positive integers, and a mod xy ≠ 0 exactly when a mod x ≠ 0 or ⌊a/x⌋ mod y ≠ 0. Kill-switch
`TOON_SPEC=1`. Laws: closed instances `div_pow10(a, k) == (divmod(a, 10^k).q, divmod(a, 10^k).r ≠ 0)` on boundary values (k = 0, 1, 6, 7, 22, 23;
exact multiples; one below a multiple); a universal law needs divisibility lemmas over limb lists and is not attempted. Beside the laws: the two
twins compared on ≥ 10^6 generated (a, k) by a native driver, and `lanes.sh` with and without the switch.

### Precommitted gate
≥ 30% below the baseline artifact on the one-decimal input at `--threads 1`; cv ≤ 5% both arms; A/A null ratio in [1/1.05, 1.05]; identical stdout;
`bend PROOF.bend` → `All terms check.`; lanes PASS with `TOON_SPEC` unset and set.

### One-line invocation
```bash
scripts/incumbent-bench.sh --runs 9 --max-cv 5 --tag EXP-003 --original <baseline binary> -- --encode <decimals.json> --port <lever binary> -- --encode <decimals.json>
```

## EXP-004 — hashed key carriers (a change of the SPEC twins' carrier, not a fast twin)

| field | value |
|---|---|
| experiment_id | EXP-004 |
| program / def | `port/text.bend` (`key_hash`, `KT`, `kt.*`), `port/json.bend` (`FObj.idx`, `obj.member`, `KM`, `km.*`), `port/encode.bend` (`keys.kt`, `row.lock`, `put.cells`), `port/decode.bend` (`blank.*`, `XV`, `xm.*`, `path.ins`, `x.norm`) |
| created (UTC) | 2026-09-20 |
| agent | Claude (Claude Code session, author); the finding is the round 6 non-author reviewer's |
| graveyard sweep | `rg -i 'hash\|carrier\|key set\|quadratic\|linear walk' perf/NEGATIVE-EVIDENCE.md` → no entry |
| status | PROPOSED |
| precommitted | the gate below was written before the merge into `port/` and before any capture; the scratch implementation existed already (it was written to answer the review finding), so this card is NOT "before the lever" and says so |

### Hypothesis
Four places walk a key chain once per key, which is quadratic in the keys of ONE object: the JSON reader's repeated-key test (S6.10),
the encoder's folding sibling test (S4.63), the tabular row lookup by header key (S6.31), and path expansion's lookup and re-insertion
(S6.42); the decoder also re-scanned the blank lines of an array body per line. A hashed key set / map beside the ordered chain makes each
of them near-linear, so the four inputs below finish in under 2 s each at 1 thread where the baseline needs more than 5 s.

### Motivation
Round 6 review, maintenance numbers on the shared host: 8000 keys in one object 5.2 s; 30000 folded keys and 40000 expanded lines did
not finish in 120 s; 20 rows of 1200 fields 16.6 s. The original needs under 3 s for each.

### Lever (one)
`T.KT`: a 16-level bit tree over FNV-1a (32 bit) of the key, with small buckets compared by `T.str_eq`; order stays in the entry chain or
in an explicit key list, the tree only answers membership and lookup. There is NO slow twin kept beside it and no `TOON_SPEC` arm: the
carrier is part of the spec twins. Evidence: the goldens on every lane; the closed laws `key_hash_fnv1a`, `kt_member`, `kt_not_member`,
`expand_order_first_insertion`, `expand_cap_is_256_reject`, `expand_cap_is_256_accept`; `scripts/diff-fuzz.py` lenses `docs`, `expand`
and `scale` against the original.

### Precommitted gate
Each of the four inputs: port median under 2 s at `--threads 1`, stdout and stderr identical to the original's, cv ≤ 5% on both arms;
the baseline artifact (commit `3751630`) either exceeds 5 s or its 60 s budget on the same input; `bend PROOF.bend` → `All terms check.`;
lanes PASS; no input of EXP-001..003 slower than the baseline by more than 5%.

### One-line invocation
```bash
scripts/incumbent-bench.sh --runs 5 --max-cv 5 --timeout 60 --tag EXP-004 --original <baseline binary> -- -e perf/inputs/wide_object_16000.json --port <merged binary> -- -e perf/inputs/wide_object_16000.json
```
(and the same with `-e --key-folding safe perf/inputs/fold_keys_30000.json`, `-d --expand-paths safe perf/inputs/expand_lines_40000.toon`,
`-e perf/inputs/wide_rows_1200.json`)
