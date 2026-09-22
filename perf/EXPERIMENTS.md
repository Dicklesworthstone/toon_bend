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
| status | DONE 2026-09-20: the capture of the binary with ALL THREE levers met this gate (1.67×, 40% below the baseline; A/A 1.001); this lever ALONE is not shown to meet it (one-lever captures REFUSED_CV twice, refused medians about 16% below); PROVISIONAL_LOCAL_WIN, `perf/NEGATIVE-EVIDENCE.md` NE-001 |
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
| status | DONE 2026-09-20: the capture of the binary with ALL THREE levers met this gate (1.56×, 36% below; A/A 0.995); this lever ALONE is not shown to meet it (one-lever captures REFUSED_CV twice, refused medians about 3% below: on this input the gain is mostly EXP-001's printer); PROVISIONAL_LOCAL_WIN, NE-002. The digit bound is 14, not the 15 of this card: a 15-digit text overflows `Nat` (2^48 − 1); `TOON_SPEC=1` on `encnum_ints` caught it before the merge |
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
| status | DONE 2026-09-20: gate met by the three levers together (2.12×, 53% below; A/A 1.004) AND by this lever alone (2.05×, cv 2.7% / 3.9%, A/A 1.019); PROVISIONAL_LOCAL_WIN, NE-003 |
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
| status | DONE 2026-09-20: three of four inputs meet the card's gate; PROVISIONAL, NOT a ledgered WIN (`perf/NEGATIVE-EVIDENCE.md` NE-005: the earlier build was timed once per input, without cv or an A/A arm); the folding input's capture was REFUSED_CV three times: NO_EVIDENCE for a ratio, NE-004. Re-measured on 2026-09-20 against the `opt-level=3` incumbent that PLAN §2 promised (round 12's R12-13), which is 1.389× the pinned `z` build: the expand row is 1.989× (not 3.06×) and the wide-rows row is **0.773×** — against the strongest build the port is SLOWER on that input, not 1.27× faster (`perf/evidence/INCUMBENT-O3.expand.json`, `.wide-rows.json`; NE-006). The card's gate is about the port against its own earlier build and is unaffected; the ratios against the ORIGINAL are the ones that move |
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

## Third profile (2026-09-20, after round 8's R8-3 / DISC-013; the build of `4c3cccc`, 1 thread)

Instrumented build of the emitted C (`clang -std=c11 -O2 -pg -fno-inline-functions`), calls per Bend def (`gprof -b -p`, specializations
summed). Uninstrumented wall time on the same inputs: port 1.19 s and 1.31 s, the original under 0.01 s each (one run, a shared host:
orientation, not evidence). The profile ran on two scratch inputs made with Python's `random` (seed 88); the captures will run on their
deterministic equivalents `perf/inputs/doubles_20000.json` and `perf/inputs/sci_5000.json` (`perf/gen-bench-inputs.py`, no `random` module).

- `--encode` of 20000 random doubles (421 KB, 15 to 17 significant digits each): 89.9 M def calls; `BN.cmp` 29.3%, `F.dg.digit` 11.1%,
  `BN.sub` 10.1%, `BN.is_ge` + `BN.is_lt` 15.4%, `BN.mul_small` 7.0%, `F.dg.step` 3.8%, `F.dg.sub_if` 3.6%; the JSON reader's own steps are
  under 2%. The shortest-digit generator finds each digit by compare-and-subtract: about 500 `F.dg.digit` calls per number.
- `--encode` of 5000 numbers `d.dddddde±XXX` with exponents up to 250 (67 KB): 72.3 M def calls; `BN.mul_small` 39.0%, `BN.cmp` 27.3%,
  `BN.sub` 9.6%, `BN.pow10` 3.5% (2.5 M calls: about 500 per number). Every number rebuilds 10^k by k multiplications by ten, one limb pass each.

## EXP-005 — powers of ten in steps of 10^4

| field | value |
|---|---|
| experiment_id | EXP-005 |
| program / def | `port/bignat.bend` / `pow10` (a fast twin `pow10.by4`; callers in `port/f64.bend`) |
| created (UTC) | 2026-09-20 |
| agent | Claude (Claude Code session, author) |
| graveyard sweep | `rg -i 'pow10\|power of ten\|mul_small' perf/NEGATIVE-EVIDENCE.md` → only NE-003 (the DIVISION by a power of ten; its do-not-retry does not cover building the power) |
| status | CLOSED, NOT ADMITTED (2026-09-21) — built, measured, REFUSED_CV, reverted; ledgered as NE-007 |
| precommitted | true |

### Hypothesis
10^k built with ⌊k/4⌋ single-limb multiplications by 10000 and one by 10^(k mod 4) equals k multiplications by 10 (a 16-bit limb times
10000 plus a carry stays below 2^32), and lowers the median wall time of `--encode` on the 5000-number scientific-notation input at 1 thread
by at least 25%.

### Motivation
The third profile: `BN.mul_small` is 39% of all def calls on that input, nearly all of them under `BN.pow10`. DISC-013 (306 times the
original on scientific notation) names this path.

### Lever (one)
`pow10.by4(k)` beside `pow10(k)`, selected through the existing gate `F.twin.on(spec, ok)` (the kill-switch `TOON_SPEC=1` keeps `pow10`).
Laws: closed instances `pow10.by4(k) == pow10(k)` for k = 0..9, 22, 23, 308, 309, 1100; hand mutants (the step constant, the remainder arm)
added to `scripts/hand-mutants.py`. Beside the laws: `scripts/diff-fuzz.py numbers --switch TOON_SPEC=1` and `lanes.sh`.

### Precommitted gate
≥ 25% below the baseline artifact (the build of `4c3cccc`) on `perf/inputs/sci_5000.json` at `--threads 1`; cv ≤ 5% both arms; A/A null ratio
in [1/1.05, 1.05]; identical stdout; `bend PROOF.bend` → `All terms check.`; lanes PASS with `TOON_SPEC` unset and set; no input of
EXP-001..004 slower by more than 5%.

### One-line invocation
```bash
scripts/incumbent-bench.sh --runs 9 --max-cv 5 --tag EXP-005 --original <baseline binary> --threads 1 -- -e perf/inputs/sci_5000.json --port <lever binary> --threads 1 -- -e perf/inputs/sci_5000.json
```

### Result (2026-09-21): NOT ADMITTED

The lever was built (`pow10.by4` in `port/bignat.bend`, `shortest.by4` / `shortest.sel` / the `shortest.pick` arm in `port/f64.bend`,
commit `91927dd`) and captured once: `perf/evidence/EXP-005.ab.json`, 18 samples per arm, medians 1312.19 ms → 1208.72 ms,
cv 3.56% / 5.45%, verdict **REFUSED_CV** — the lever's arm is above the card's 5% gate, so the capture claims nothing and no ratio is
claimed. The precommitted gate is missed on four counts: the cv gate refused it; the refused medians are about 8% apart where the card
demanded at least 25%; the precommitted A/A null arm was never captured; and the twin carried no `{fast == spec}` law, which
`scripts/port-lint.py` reported as a PL-11 ERROR on the tree of `91927dd`.

The lever is reverted (`port/` is byte-identical to `3b67865`) and ledgered as **NE-007** in `perf/NEGATIVE-EVIDENCE.md` with its
retry predicate. The reusable finding is on that entry: the "Third profile" above counts `BN.mul_small` at 39.0% of this input's 72.3 M
def calls, while `BN.pow10` itself is only 3.5% — and removing about three quarters of those multiplications moved the median by about 8%.
A CALL census is not a WALL census: it weights a one-limb `mul_small` like a sixty-limb one, and the 27.3% `BN.cmp` + 9.6% `BN.sub` of the
digit generator's compare-and-subtract, which this lever never touches, is where EXP-006 aims. Choosing a lever by call share alone is what
set a 25% gate this code could not meet.

## EXP-006 — a quotient estimate per digit in the shortest-digit generator

| field | value |
|---|---|
| experiment_id | EXP-006 |
| program / def | `port/f64.bend` / `dg.digit`, `dg.sub_if` (a fast twin of the digit step) |
| created (UTC) | 2026-09-20 |
| agent | Claude (Claude Code session, author) |
| graveyard sweep | `rg -i 'digit\|shortest\|dragon\|quotient' perf/NEGATIVE-EVIDENCE.md` → NE-001 (integers print their own digits: a different path, kept) |
| status | PROPOSED (not started, for the reason on EXP-005's card) |
| precommitted | true |

### Hypothesis
The next digit of R/S (0 ≤ R < 10·S) is ⌊R/S⌋; an estimate from the two most significant limbs of R and S is off by at most one, so one
single-limb multiplication, one subtraction and one comparison replace up to nine compare-and-subtract rounds, and the median wall time of
`--encode` on 20000 random doubles at 1 thread falls by at least 30%.

### Motivation
The third profile: `BN.cmp`, `BN.sub`, `BN.is_ge`, `BN.is_lt` and `F.dg.*` are 75% of all def calls on that input. DISC-013 (113 times
the original on random doubles).

### Lever (one)
A fast twin of the digit step behind `F.twin.on`. Laws: the shortest-digit generator does not normalize in the checker (ARCH §11 A7), so
the twin is bound by closed laws on the DIGIT STEP alone (R, S pairs at the estimate's two failure boundaries) and by
`scripts/diff-fuzz.py numbers --switch TOON_SPEC=1` at ≥ 10^6 numbers; that weaker binding is stated on the ledger row, as for NE-001..003.

### Precommitted gate
≥ 30% below the baseline artifact on `perf/inputs/doubles_20000.json` at `--threads 1`; the other conditions of EXP-005.

### One-line invocation
```bash
scripts/incumbent-bench.sh --runs 9 --max-cv 5 --tag EXP-006 --original <baseline binary> --threads 1 -- -e perf/inputs/doubles_20000.json --port <lever binary> --threads 1 -- -e perf/inputs/doubles_20000.json
```
