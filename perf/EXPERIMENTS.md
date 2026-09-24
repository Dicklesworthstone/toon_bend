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
`expand_order_first_insertion`, `expand_cap_is_256_reject`, `expand_segments_253_not_ok` (renamed on 2026-09-22 when 253 segments started to exceed the nesting limit of 127; its input is unchanged); `scripts/diff-fuzz.py` lenses `docs`, `expand`
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
| status | BUILT 2026-09-22, PROVISIONAL (`perf/NEGATIVE-EVIDENCE.md` NE-010): 1071/1071 on c-1t both switch settings and js, 10^6-double differential SAME, six closed laws; the card's capture REFUSED_CV at load 9 (medians 1278 → 675 ms) |
| precommitted | true |

### Hypothesis
The next digit of R/S (0 ≤ R < 10·S) is ⌊R/S⌋; an estimate from the two most significant limbs of R and S is off by at most one, so one
single-limb multiplication, one subtraction and one comparison replace up to nine compare-and-subtract rounds, and the median wall time of
`--encode` on 20000 random doubles at 1 thread falls by at least 30%.

### Motivation
The third profile: `BN.cmp`, `BN.sub`, `BN.is_ge`, `BN.is_lt` and `F.dg.*` are 75% of all def calls on that input. DISC-013 (113 times
the original on random doubles).

### Precondition added 2026-09-21 by NE-007 (do not start without it)
EXP-005 chose its lever and set a 25% gate from this same CALL census, and the lever moved the median by about 8% — the census counted
`BN.mul_small` at 39.0% while `BN.pow10` itself was 3.5%, and it weighted a one-limb multiply like a sixty-limb one. **A call share is not
a wall share, so the 75% above does not license the 30% gate below.** Before writing a line of the twin: take a WALL-time profile of
`--encode` on `perf/inputs/doubles_20000.json` at 1 thread (`clang -O2 -pg` on the emitted C, `gprof -b -p` read for SELF SECONDS, not for
call counts, and the artifact committed to `perf/evidence/` — the third profile has no artifact file, which is its own weakness), and set
the gate from the self time the digit step actually owns. If that profile gives the digit step less than 30% of the wall, the gate below is
unreachable by construction and the card is re-carded or abandoned BEFORE any code is written, not after a refused capture.

Two things about EXP-006 are nonetheless stronger than EXP-005 was, and the profile should confirm or refute both: the lever is a
STRUCTURAL reduction (one estimate replaces up to nine compare-and-subtract rounds per digit, so the work removed is not merely the same
work in fewer calls), and the defs it touches run per DIGIT of every number rather than once per power of ten.

**Precondition MET, 2026-09-22** (`perf/evidence/EXP-006.wall-profile.txt`: `perf record -g`, 2552 samples, the emitted C rebuilt with frame
pointers). Inclusive wall shares on this input: `BN.cmp` **51.6%**, `BN.sub` 10.0%, `F.dg.digit` 3.8% + 2.5% self, `BN.add` 3.8%. The digit
step owns about 68% of the wall, so the 30% gate is reachable by construction and the card may proceed. The profile adds one fact the call
census could not show: almost all of `BN.cmp`'s time is BendRT memory management UNDER it (`span_fade` 34.6% self, which takes a SHARED `+`
value apart with atomic refcount bumps, and `term_drop` 37.0% self), not comparison work. A comparison that consumes shared copies of both
operands is therefore a competing lever (a cmp that does not take its arguments apart through the refcount path); per the one-lever rule it
gets its own card, and whichever runs first must re-profile for the other.

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

## EXP-007 — every number rendered by a parallel pre-pass (and the GPU question)

| field | value |
|---|---|
| experiment_id | EXP-007 |
| program / def | `port/encode.bend` / `pre`, `par.take`, `par.cat` (a pass over the value before emission) and `port/json.bend` / `num.defer`, `raw.f64` |
| created (UTC) | 2026-09-22 |
| agent | Claude (Claude Code session, author) |
| graveyard sweep | `rg -i 'parallel\|thread\|gpu\|bang' perf/NEGATIVE-EVIDENCE.md` → the inherited priors (GPU wins on uniform numeric work, loses on divergent work) and now NE-008, NE-009, this card's own outcomes |
| status | **WIRED IN 2026-09-22, commit `0131342`**, behind `TOON_SPEC=1`, with three proved laws and four gates (proof, c-1t, c-8t, js, kill-switch parity, two fuzz lenses); the interpreter lane was still to run. The RATIOS remain NO_EVIDENCE: every cv-gated capture on this shared host was REFUSED (NE-008). The GPU half stays NEGATIVE (NE-009). The original spike patch is `perf/evidence/EXP-007.parallel-prerender.patch` |
| precommitted | false (a spike to size the lever, run because the owner asked what Bend's parallelism is worth here) |

### Hypothesis
Every number's text depends on that number alone, so the conversions are independent: rendering them in a pass that forks long item chains with parallel lets should use the worker pool (and, under a bang, a device), and cut the wall time of the number-heavy documents of `perf/e2e/` by more than half.

### What the spike does
The reader keeps a token RAW when it cannot overflow (`num.safe`: at most 50 integer digits, AND either a negative exponent or an exponent ≤ 250 — so below 10^50 or 10^300 against a limit of 1.8e308); every other token is converted where it always was, so every `number out of range` keeps its position and its order. **The integer-digit bound applies on both arms.** The card's first wording made a negative exponent sufficient on its own; round 16 (R16-1) showed that 401 integer digits overflow whatever the exponent, so `1<400 zeros>e-1` was deferred and printed `0` with exit 0 where the original exits 1, and a later syntax error could win a race the original gives to the number. This half of the pass is NOT behind the kill-switch — the reader defers before any option is read — so the bound has to be right rather than recoverable; the five closed `num_safe_*` laws pin both constants, which is what R16-3 found missing when a mutant moved 250 to 300 and survived both the corpus and the proof. The pass then turns each raw token into its rendered text (`JTxt`), splitting an item chain of more than 64 items into halves with a parallel let. A value the pass does not reach keeps its `JNum`, which the emitter prints itself: **running out of fuel changes the speed and never the text.**

### Outcome
- Correct: 1071/1071 goldens on the c-1t lane at 8 threads, and 60 encodes of the 20 real documents byte-identical to the original; GPU runs byte-identical too
- CPU pool: 3.6× on `numbers`, 2.6× on `mesh`, 1.8× on `flights_200k`, 1.3× on `canada`, nothing on the text-heavy documents — orientation, the one paired capture was REFUSED_CV (NE-008)
- The ceiling: 8 separate processes reached 3.6× of throughput on `canada` where one process at 8 threads reached 1.4×. The limit is the single shared heap that `span_fade`/`term_drop` work on, not the cores (NE-008)
- GPU (2 × RTX 4090, `pre!`): 7.3× slower on `numbers`, 2.9× on `mesh`, **71× on `canada`** (357.84 s against 5.05 s), outputs identical, device confirmed busy (NE-009)

### What it would take to admit the CPU half
1. A quantified law `{encode(pre(f, j, …), opt) == encode(j, opt) : List<&2, String>}` — the pass is a reordering of the same function, and `port-lint.py` PL-11 demands a law for anything that behaves like a twin
2. A quiet host, ≥ 15 pairs, an A/A arm, and a document whose ORIGINAL arm reaches 100 ms (NE-006's predicate)
3. The allocation cost first (`toon_bend-2t0`, closed since): on the 17-digit-double documents the scaling stops at two threads, and no thread count moves it

## EXP-008 — a lean fold context: no path prefix grown while key folding is off

| field | value |
|---|---|
| experiment_id | EXP-008 |
| program / def | `port/encode.bend` / `fctx.child` (a `lean` field on `FCtx`, set through `F.twin.on`) |
| created (UTC) | 2026-09-22 |
| agent | Claude (session ef481f9c) |
| graveyard sweep | `rg -i 'fold\|fctx\|prefix\|path' perf/NEGATIVE-EVIDENCE.md` → NE-004 (the folding capture, `--key-folding safe`: a different mode; this lever acts only with folding OFF) |
| status | BUILT 2026-09-22, PROVISIONAL (`perf/NEGATIVE-EVIDENCE.md` NE-011). Carded AFTER the lever was built, from bead `toon_bend-gzg` and the profile below; the precommitted gate is stated now and not moved |
| precommitted | false (see status) |

### Hypothesis
`fctx.child` extends the dotted path prefix with `T.cat` for every non-folded object field, and only `fold.go` reads the prefix,
which runs only when folding is on. With folding off (the default) a context that is passed on unchanged removes that work, and the
median wall of `--encode` on a deep, key-heavy document falls by at least 10%.

### Evidence before the lever
`perf/e2e/results/2026-09-22-694d73b/profiles/openapi_encode.inclusive.txt`: `WL_FID_ENCODE_CTX_FIELD_K1169` 18.5% inclusive (207030
calls) through `spin_263`/`spin_84`/`spin_86` (the join); 14.3% on `vscode_lock`.

### Lever (one)
`FCtx` gains `lean: Bool = F.twin.on(spec, not fo)`; `fctx.child` returns a lean context unchanged. Laws: `fold_off_never_folds`
(quantified: with folding off a fold attempt never folds, whatever the prefix) and `fctx_lean_closed_by_switch` (quantified).

### Precommitted gate
≥ 10% below the NE-010 lever binary on the e2e corpus's `openapi_github.json` (sha256 `ab1d3dfd…` in `perf/e2e/corpus.json`; gitignored, fetched by `python3 perf/e2e/bench.py fetch`) (`--encode`, `--threads 1`), cv ≤ 5% on both arms.

### Result
Orientation (interleaved ABBA, 8 rounds, load 10): 4785.5 → 3858.4 ms, 1.240× by median (19% below), cv 1.6% / 4.4%; 1.329× by
minimum, 1.269× by CPU. The gate's figure is met inside the cv bound by this harness; the repository's cv-gated tool with an A/A arm
has not run (NE-011).

## EXP-009 — the header parser looks for '[' before it cuts the line

| field | value |
|---|---|
| experiment_id | EXP-009 |
| program / def | `port/decode.bend` / `hdr.a.first` (the unquoted branch of `header`, S2.130) |
| created (UTC) | 2026-09-22 |
| agent | Claude (session ef481f9c) |
| graveyard sweep | `rg -i 'precheck\|header\|has_char\|cut' perf/NEGATIVE-EVIDENCE.md` → no entry (the hits are NE-004's unrelated text and NE-010's "call census" note) |
| status | BUILT 2026-09-22, PROVISIONAL (`perf/NEGATIVE-EVIDENCE.md` NE-013): orientation 1.157× by the least favourable estimator, above the 5% gate, but the lever arm's cv (8.8%) is above the capture's bound. Carded before the lever (bead `toon_bend-z3z`) |
| precommitted | true |

### Hypothesis
Every decoded line is offered to `header`, whose unquoted branch runs `T.cut(content, 91)`: a loop that copies the text before the
first `[` in reverse and reverses it again. On a line with no `[` (almost every line of an ordinary document) the copy is built, found
to have no bracket, and dropped, one allocation and one drop per character. A `T.has_char(content, 91)` test first (a loop that
allocates nothing) answers `HNot` for those lines without the copy, and the median wall of `--decode` on `gsoc_2018.toon` at
1 thread falls by at least 5%.

### Evidence before the lever
gprof of the zgb tree (built from `455ece6` plus the zgb change, `clang -O3 -g -pg`), `--decode` of the e2e corpus's
`gsoc_2018.toon`: `WL_FID_DECODE_HEADER` 16.1% inclusive over 18960 calls; the flat profile is `term_drop` 34.6%, `rfc_wrap` 15.5%,
`span_fade` 14.6% (orientation: a call-graph profile, not a capture).

### Lever (one)
`hdr.a.first`'s unquoted branch becomes `hdr.a.plain.pre(T.has_char(content, 91), content)`: `False` answers `HNot{}`, `True` runs
the old `hdr.a.plain(T.cut(content, 91))`. Not a twin behind the switch: the two branches compute the same verdict (with no `[`,
`T.cut` misses and `hdr.a.plain` answers `HNot`), bound by closed laws on the miss, the hit and the quoted-key paths, and by the
corpus on every lane.

### Precommitted gate
≥ 5% below the zgb binary on `gsoc_2018.toon` (sha256 in `perf/e2e/corpus.json`; gitignored, fetched by
`python3 perf/e2e/bench.py fetch`) (`--decode`, `--threads 1`), cv ≤ 5% on both arms; 1071/1071 on c-1t; the proof green.

## EXP-010 — trim_end returns a text that ends in a non-White_Space character as it is

| field | value |
|---|---|
| experiment_id | EXP-010 |
| program / def | `port/text.bend` / `trim_end` (under `T.trim`, called by the decoder's key-value split, primitive tokens and header inline text, S2.106) |
| created (UTC) | 2026-09-22 |
| agent | Claude (session ef481f9c) |
| graveyard sweep | `rg -i 'trim\|reverse' perf/NEGATIVE-EVIDENCE.md` → no entry |
| status | REVERTED 2026-09-22, NEUTRAL at this load (`perf/NEGATIVE-EVIDENCE.md` NE-014): the reversals fell from 154994 to 61458 calls, but the wall did not move beyond the noise (1.007× / 1.006×, cv 8-21%) |
| precommitted | true |

### Hypothesis
`trim_end(s)` is `String.reverse(trim_start(String.reverse(s)))`: two full copies of the text, each taken apart afterwards, even when
nothing trails. A value whose last character is not White_Space (almost every key and value) is its own trim; finding the last
character is a walk that allocates nothing. Returning `s` in that case lowers the median wall of `--decode` on `gsoc_2018.toon` at
1 thread by at least 5% against the EXP-009 binary.

### Evidence before the lever
gprof of the EXP-009 tree, `--decode` of `gsoc_2018.toon`: `spin_7` (`String.reverse`) 21.0% inclusive over 154994 calls, of
which `WL_FID_DECODE_KV` 50560 and `WL_FID_DECODE_PRIM` 30336 (two per `T.trim`); `term_drop` 42.3% flat (orientation).

### Lever (one)
`trim_end.pick(ends_ws(s), s)`: `False` returns `s`; `True` runs the old reversal. Not a twin behind the switch: both branches
compute the same text (a reversed text whose head is not White_Space is left alone by `trim_start`, and reversing twice is the
identity), bound by closed laws on no trailing space, trailing ASCII spaces, a trailing U+3000, an all-space text and the empty text,
and by the corpus on every lane.

### Precommitted gate
≥ 5% below the EXP-009 binary on `gsoc_2018.toon` (`--decode`, `--threads 1`), cv ≤ 5% on both arms; 1071/1071 on c-1t; the proof
green.

## EXP-011 — the JSON writer decides an empty container by pattern, not by a shared look at its chain

| field | value |
|---|---|
| experiment_id | EXP-011 |
| program / def | `port/json.bend` / `w` (the JSON writer, S5.54–S5.60), its `JArr` and `JObj` arms |
| created (UTC) | 2026-09-22 |
| agent | Claude (session ef481f9c) |
| graveyard sweep | `rg -i 'writer\|is_nil\|share\|span_fade' perf/NEGATIVE-EVIDENCE.md` → NE-012 (borrowing is not inferred for `List<&2, U32>`: a different def and type; it is why this lever removes the share instead of hoping for a borrow) |
| status | BUILT 2026-09-22, PROVISIONAL (`perf/NEGATIVE-EVIDENCE.md` NE-015): orientation 1.204× by the least favourable estimator, above the gate; both arms' cv above the capture's bound |
| precommitted | true |

### Hypothesis
`w` binds `JArr{cnt, +items}` and `JObj{+entries}` so that `is_nil` can look at the chain before `w` writes it: every array and
object chain of the document becomes shared, and the writer then takes each node apart as a shared value (`span_fade`) while the
other reference is dropped. Matching `JArr{cnt, JNil{}}` and `JObj{JNil{}}` first (the empty container, written as two bytes) and
the non-empty arm without `+` removes the share, and the median wall of `--decode` on `gsoc_2018.toon` at 1 thread falls by at
least 5% against the EXP-009 binary.

### Evidence before the lever
gprof of the EXP-010 tree, `--decode` of `gsoc_2018.toon`: `WL_FID_JSON_W` 20.9% inclusive, all of it under `spin_365` (the
writer's loop), which calls `span_fade` 2943616 times (orientation).

### Lever (one)
The two arms split by pattern. Laws: closed instances of `J.write` on an empty array, an empty object, a nested empty object inside
a non-empty object, and a non-empty array at indent 0 and 2 (the text each must be); the corpus on every lane (the `jsonout_*`
and every `--decode` case go through this def).

### Precommitted gate
≥ 5% below the EXP-009 binary on `gsoc_2018.toon` (`--decode`, `--threads 1`), cv ≤ 5% on both arms; 1071/1071 on c-1t; the proof
green.

## EXP-012 — the shortest-digit loop in scalar words when every operand is below 2^64

| field | value |
|---|---|
| experiment_id | EXP-012 |
| program / def | `port/f64.bend` / `dg.gen.with` under `shortest.with` (S4.131), the digit loop after `dg.fix` |
| created (UTC) | 2026-09-23 |
| agent | Claude (session ef481f9c) |
| graveyard sweep | `rg -i 'scalar\|limb\|u32 pair\|two words\|bitlen' perf/NEGATIVE-EVIDENCE.md` → NE-012 (BN.cmp cannot borrow; its retry predicate is "the number path stops carrying big naturals as lists"), NE-008 (its retry predicate is "the number path stops allocating per digit"), NE-INH-9 (generic `Bool.pick` in hot code: typed match helpers instead). This lever is the one both predicates name |
| status | BUILT 2026-09-23, PROVISIONAL (`perf/NEGATIVE-EVIDENCE.md` NE-016). The card's "pair of packed Nat words" became three U32 words: the Nat version was right but its closed laws did not finish in the checker. Orientation (CPU estimator, load 17-20) 1.84× on `canada --decode`, above the gate; wall cv far above the capture's bound. COUNTED 2026-09-23 (cachegrind, deterministic): 2.39× fewer instructions on `canada --encode`, 2.06× on `canada --decode`; the gate is in CPU time, so it stays PROVISIONAL until a quiet-host capture |
| precommitted | true |

### Hypothesis
After the scale and the fix-up, the digit loop of the shortest-digit generator works on four big naturals `r`, `s`, `mp`, `mm`
held as little-endian lists of 16-bit limbs: every digit multiplies three of them by ten, compares four times and subtracts,
and each operation allocates and takes apart shared lists (gprof of `canada.toon --decode` at 1 thread: `BN.cmp` 18.8% inclusive
over 7523500 calls, 68 per number; `span_fade` 41%). When all four are below 2^64 (a double of ordinary magnitude), `10s < 2^68`
bounds every intermediate (`rem < s`; `mp, mm <= s` before each step, else the previous step ended generation), so each value is
a pair of packed `Nat` words `h * 2^24 + l` with `h < 2^44`, and one tail-recursive loop whose operands are scalar arguments
allocates nothing per digit but the digit. The median wall of `--decode` on `canada.toon` at 1 thread falls by at least 20%
against the binary of `31e46fd`.

### Lever (one)
`dg.run.with` tests the bound on the fixed state; within it, `dgw.loop` (scalar pairs) replaces `dg.gen.with`; outside it, the
current path runs unchanged. Behind `F.twin.on` (`TOON_SPEC=1` runs the spec loop). Laws: closed instances of `dgw.run == dg.run`
on states at each branch of the loop (low end, high end, both with the tie, the 64-bit edge, a many-digit value); beside them the
1000000-number differential against the original and the spec twin, and conform on c-1t with the switch off and on.

### Precommitted gate
≥ 20% below the `31e46fd` binary on `canada.toon` (`--decode`, `--threads 1`), cv ≤ 5% on both arms; the 10^6-number differential
0 differences; 1071/1071 on c-1t with `TOON_SPEC` unset and set; the proof green.

## EXP-016 — the JSON reader's byte classifier as a lazy chain

| field | value |
|---|---|
| experiment_id | EXP-016 |
| program / def | `port/json.bend` / `byte.cls` (and `esc.cls` if it carries) |
| created (UTC) | 2026-09-23 |
| agent | Claude (Claude Code session, author) |
| graveyard sweep | `rg -i 'byte.cls\|classif\|Bool.pick\|lazy\|short.circuit' perf/` → **NE-INH-9** "generic `Bool.pick` in hot code — reported generic representation/sharing cost; scalar words need no heap box", whose retry guidance is "inspect and compare typed helpers". No do-not-retry applies. No other entry touches the classifier |
| status | **CLOSED, NOT ADMITTED (2026-09-23)** — built, measured, reverted (stashed, recoverable); ledgered as `perf/NEGATIVE-EVIDENCE.md` NE-019. The load-independent half of the gate was MET (`spin_6` −63%); the wall/CPU half was MISSED by a wide margin (0.5–2.5% against a 10% gate). The `byte_cls_*` laws the card added (one per class member and non-member) are KEPT: they pin a table that had no law, and they are independent of the lever |
| precommitted | true |

### Hypothesis

`byte.cls` is a 15-deep `Bool.pick(Nat, …)` chain. `Bool.pick` is STRICT: the emitted `spin_6` takes two
already-built `Term`s and `term_sink`s the one it does not return, so every input byte pays all 15
comparisons AND the construction of all 15 untaken arms. Rewriting it as a lazy nested `match` over `Bool`
— one helper per level, the scrutinee a parameter, per the project's match rule — evaluates only the arm
taken and builds only the one class code the byte has. This lowers `spin_6` calls per input byte by at
least 50% and `heap_alloc` per input byte measurably, with byte-identical output.

### Motivation (profile of 2026-09-23, `--encode` of the corpus document `gsoc_2018.json` in `perf/e2e/corpus/` (gitignored), 3.2 MB, 1 thread)

`clang -std=c11 -O2 -pg -fno-inline-functions` over the emitted C. `spin_6` is the hottest single symbol
(8.14% of samples, **79,183,977 calls**). Its callers: `spin_443` **49,917,465 (63%)**, `spin_125`
16,864,440, `spin_276` 12,266,955. `spin_443` is `byte.cls` — it is called **3,327,831** times, exactly the
count of `WL_FID_JSON_STEP`, i.e. once per input byte, and it makes **15 `spin_6` calls each**. Per input
byte the run also does `term_triv` 40×, `term_tag` 77×, `heap_alloc` 16×, `rfc_wrap` 11.5×. The e2e
reference run puts `--encode` at 9.61× the original against `--decode` at 5.73×, so the read path is where
the port is furthest behind, and no lever so far has targeted it (EXP-001/002/003/006/012 are all number
and digit work).

### Lever (one)

`byte.cls` rewritten as a chain of small typed helpers, each `match`ing a `Bool` parameter and calling the
next level only in the `False` arm. Same order, same 16 classes, no change to any caller.

### Correctness binding

This is a REWRITE, not a fast twin, so there is no kill switch and no `fast == spec` law: a universal law
is impossible here anyway, because the checker cannot decide `U32.is_eq` on an abstract scalar (the same
wall the escape-table laws hit). Instead the classifier's whole TABLE is pinned by **one closed law per entry** —
one per class member, plus non-members at 0, 31, 33, 47, 59, 97, 126 and 255 — added BEFORE the rewrite and
required to pass unchanged after it. `byte.cls` had no law of any kind before this card; the laws are
worth keeping whatever happens to the lever.

### Precommitted gate

- **Primary, load-independent:** `spin_6` calls per input byte fall by ≥ 50% on the same input and the same
  build flags, and `heap_alloc` per input byte falls. Call counts are exact regardless of host load, which
  is why they are the primary gate: every wall-clock capture on this host has been REFUSED_CV.
- **Secondary, needs a quiet host (load < 1):** ≥ 10% below the current binary on `--encode` of a
  string-heavy document at `--threads 1`; cv ≤ 5% both arms; A/A null ratio in [1/1.05, 1.05].
- Always: the 28 `byte_cls_*` laws unchanged, `bend PROOF.bend` → `All terms check.`, conform 1076/1076 on
  c-1t, c-8t and js, and byte-identical output on the e2e corpus.

### One-line invocation

```bash
scripts/incumbent-bench.sh --runs 9 --max-cv 5 --tag EXP-016 --original <current binary> -- --encode <corpus>/gsoc_2018.json --port <lever binary> -- --encode <corpus>/gsoc_2018.json
```

## EXP-017 — the number pre-pass splits far more often than any worker pool needs

| field | value |
|---|---|
| experiment_id | EXP-017 |
| program / def | `port/encode.bend` / `par.cut`'s threshold (the literal `64n`) |
| created (UTC) | 2026-09-23 |
| agent | Claude (Claude Code session, author of EXP-007) |
| graveyard sweep | `rg -i 'threshold\|fork\|split\|leaf\|granularity' perf/` → NE-008 (EXP-007's own entry: ratios NO_EVIDENCE, the pass ADMITTED on correctness), NE-INH-11 ("split heavy tiles; 32-px cells" — neutral, retry on "a tail-bound profile"). No do-not-retry applies to the threshold itself |
| status | **CLOSED, NOT ADMITTED (2026-09-23)** — built at 2048 and at 256, measured, reverted to 64; ledgered as `perf/NEGATIVE-EVIDENCE.md` NE-020. Between 64 and 2048 the CPU time moves by at most 1.1%, so the split granularity is not a lever at all |
| precommitted | true |
| credit | the hotspot was found by the peer session (toon-bend-92) profiling `flights_200k.json`; the code is mine |

### Hypothesis

`par.cut` splits a chain while it is longer than **64** items. Each split costs three traversals of the
left half: `par.take` walks `k` items into a reversed accumulator and then `J.rev_items` it back, and
`par.cat(a, b)` is `rev_items(rev_items(a, JNil{}), b)` — two more. Total copying is therefore
O(levels x n), and with 200k items a threshold of 64 gives about 11.6 levels and ~3000 leaves. Eight
workers need dozens of leaves, not thousands, and at `--threads 1` every one of those splits is pure
overhead on top of the rendering. Raising the threshold to 2048 cuts the levels to about 6.6 — about
40% less copying — and changes NOTHING about what the pass returns, only where it forks.

### Motivation

Peer profile of `--encode` on `flights_200k.json` at `--threads 1`: `spin_164` at **6.6% self time over
only 28,670 calls**, all under `WL_FID_ENCODE_PRE` / `ENCODE_PRE_J1353`, with `spin_418`/`spin_420` (~2%)
beside it — the split machinery, not the rendering. The e2e reference run has `--encode` at 9.61x the
original against `--decode` at 5.73x.

### Lever (one)

The literal `64n` in `par.cut` becomes `2048n`. No other change.

### Correctness binding

The threshold decides only WHERE the chain forks, never what the pass returns, so no new law is needed
and none of the existing `pre_*` laws changes. The claim rests on the goldens: the fork shape is exactly
what `c-8t` exists to exercise (since EXP-007 the pass is a genuine parallel lane on every `--encode`
case), so a fork-shape bug is a c-8t-only failure.

### Precommitted gate

- **Primary:** ≥ 8% below the current binary on `--encode` of `flights_200k.json` at `--threads 1`,
  by interleaved ABBA child-CPU time, min and median agreeing in sign.
- **No regression at scale:** `--threads 8` on the same input not worse than the current binary by more
  than 2%.
- Always: conform 1076/1076 on c-1t, **c-8t** and js; byte-identical output on the e2e corpus;
  `bend PROOF.bend` unchanged at the law count of that commit (480 laws when written).
- NE-019's lesson applies: a profile share is not a budget. If the gate is missed, the lever is reverted
  and ledgered, whatever the call counts say.

## EXP-020 — path expansion rebuilds nodes it does not change

| field | value |
|---|---|
| experiment_id | EXP-020 |
| program / def | `port/decode.bend` / `x.norm` (S3.28, the expansion tree's normalisation) |
| created (UTC) | 2026-09-23 |
| agent | Claude (Claude Code session) |
| graveyard sweep | `rg -i 'expand\|x.norm\|rebuild\|wildcard' perf/` → nothing on expansion. NE-019 and NE-020 apply as METHOD (a profile share is not a budget; gate on a measured A/B), and NE-012 is adjacent (borrowing is not inferred for `List<&2, U32>`) |
| status | **CLOSED, NOT ADMITTED (2026-09-23)** — built in a scratch tree, counted, not merged; ledgered as `perf/NEGATIVE-EVIDENCE.md` NE-027. The pass-through rebuild costs **0.11%**, against a 5% gate. `port/` was never modified |
| precommitted | true |

### Hypothesis

`x.norm` walks the expansion tree and reconstructs EVERY node, including the two that it does not
change: `case XLeaf{v}: XLeaf{v}` and `case XBNil{}: XBNil{}` each allocate a fresh node identical to
the one they destructured, so every scalar in the document costs one `rfc_wrap` and a matching
`term_drop` for nothing. Letting those two fall through a single `case other: other` arm returns the
term unchanged and allocates nothing. `XV` has exactly six constructors (`XLeaf`, `XObj`, `XTLeaf`,
`XTNode`, `XBNil`, `XBNode`), the other four keep their explicit arms, so the wildcard covers exactly
the two pass-through cases and nothing else.

### Motivation (deterministic, cachegrind, 2026-09-23)

`--expand-paths safe` is the most expensive path in the port per byte of input: **479.6 ms/MB** against
plain `--decode` at 340.4 ms/MB across the 204-cell e2e reference run. Isolated on
the corpus document `citm_catalog.fold.toon` (in the gitignored `perf/e2e/corpus/`, 650 KB): plain decode **2,077,027,910** I-refs, with expansion
**2,682,287,179** — expansion adds **605,259,269 instructions, +29.1%**. Of the expansion run,
`term_drop` is 29.4%, `rfc_wrap` 18.1% and `span_fade` 6.1% — **53.6% is allocate-and-drop traffic**,
while the expansion's own logic (`WL_FID_DECODE_X_NORM` plus `_K950`) is 2.7%. The cost is not the
normalisation; it is the rebuilding it does on the way through.

### Lever (one)

The `XLeaf` and `XBNil` arms of `x.norm` replaced by a single trailing `case other: other`.

### Correctness binding

A quantified law per pass-through case, pinning that the def returns its argument unchanged for exactly
those constructors — the same "pin the dispatch" form that killed M36/M37, and it is refutable: a mutant
that made the wildcard swallow `XTLeaf` or `XBNode` would fail the explicit-arm laws.

### Precommitted gate

- **Primary (counted, deterministic):** ≥ 5% fewer instructions on
  `--decode --expand-paths safe <corpus>/citm_catalog.fold.toon` at `--threads 1`.
- Always: output byte-identical to the current binary AND to the oracle; `bend PROOF.bend` green with the
  new laws; conform 1076/1076 on c-1t, c-8t and js.
- Per NE-019/NE-020: if the gate is missed the lever is reverted and ledgered, whatever the profile said.

## EXP-023 — expansion builds a keyed map for objects that have nothing to expand

| field | value |
|---|---|
| experiment_id | EXP-023 |
| program / def | `port/decode.bend` / `expand`'s `XFields` path and the `XObj` arm of `x.norm` (S4.240, S3.28) |
| created (UTC) | 2026-09-23 |
| agent | Claude (Claude Code session) |
| graveyard sweep | `rg -i 'expand\|x.norm\|map\|precheck' perf/` → **NE-027** (this card's direct predecessor: trimming `x.norm`'s pass-through rebuild is 0.11%, and its retry predicate names exactly this lever as the larger one worth doing), **NE-013/EXP-009** (the same precheck SHAPE won 17.2% counted on the header parser), NE-019/NE-020 as method |
| status | CARDED 2026-09-23 with its evidence, LEVER NOT BUILT |
| precommitted | true |

### The measurements that motivate it (all counted, cachegrind, deterministic)

Expansion's cost is not proportional to input size — it is proportional to KEY COUNT, because the `XV`
map is built per object per key and then normalised back to `Json`:

| document | size | unquoted dotted keys | plain decode | with expansion | expansion adds |
|---|---|---|---|---|---|
| `gsoc_2018.toon` | 3.0 MB | **0 of ~? ** | 7,356,972,432 | 7,821,379,865 | **464,407,433 (+6.3%)** |
| `citm_catalog.fold.toon` | 650 KB | **1 of 23,143** | 2,077,027,910 | 2,682,287,179 | **605,259,269 (+29.1%)** |

The smaller document pays MORE in absolute instructions. On `gsoc_2018.toon` the entire 464M is spent
expanding a document with **nothing to expand**.

Key statistics of the expand corpus, which is what the lever turns on:

| document | keys | unquoted with a dot | share |
|---|---|---|---|
| `citm_catalog.fold.toon` | 23,143 | 1 | 0.0% |
| `github_events.fold.toon` | 1,117 | 11 | 1.0% |
| `openapi_github.fold.toon` | 193,136 | 15,407 | 8.0% |

Where the expansion run's instructions go (`citm_catalog.fold.toon`): `term_drop` 29.4%, `rfc_wrap`
18.1%, `span_fade` 6.1% — **53.6% allocate-and-drop** — against the expansion's own defs
(`WL_FID_DECODE_X_NORM` and its continuations, plus `WL_FID_DECODE_EXPAND`) at about 97M, **16% of the
extra cost**. The traffic is caused by the map building and the rebuild, not by the logic.

### Hypothesis

An object whose keys contain no dot **outside a quoted key** needs no expansion: its entries can be kept
as they are instead of being inserted into an `XBNode` map and reassembled by `x.norm`'s `XObj` arm. A
per-object precheck of the entry chain (no allocation, one scan, the `quoted` flag already carried by
`J.JECons`) should remove most of the 464M on a dot-free document.

### Why this is NOT NE-027 again

NE-027 made an operation cheaper (a node reconstruction) and returned 0.11%. This removes a DATA
STRUCTURE and the traversal that consumes it, for the common case, which is the shape that has actually
paid in this repository (the header precheck, 17.2%; the peer's traversal-removing levers, 18.3% and
11.6%). Per NE-027's own rule: eliminate a pass over the data, not an operation within one.

### The trap this lever must not fall into

**The depth cap must still be enforced.** `expansion_cap_on_values` and `expansion_cap_on_merges` say no
expansion step runs at depth 256, and the budget decrements per level of the JSON structure, not per
dot. A dotless object's VALUES may still nest arbitrarily deep, so the walk cannot be skipped — only the
map building and the reassembly may be. A lever that skips the descent would accept a document the
original rejects, and those two laws are what would catch it.

### The bisect, done before building (2026-09-23, NE-033's rule)

NE-033 cost a lever because I attributed a measured cost to the wrong half. So the 605M was split
between expansion's two halves before any code was written, from the same cachegrind run:

| half | named instructions |
|---|---|
| `x.norm` and its continuations (reassembly) | **89.4M** |
| `field.ins` (insertion into the map) | 15.1M |
| `expand` itself | 7.3M |

Reassembly is about **six times** the insertion cost, and NE-027 already proved it is not the
pass-through rebuild (0.11%). What remains is the `XObj` arm —
`XLeaf{J.JObj{x.entries(keys, x.norm(map), J.JNil{})}}` — which walks the insertion-order key list and
performs **one balanced-tree lookup per key**: 23,143 lookups on `citm_catalog.fold.toon`. That is the
target, and it is named precisely now.

**The bisect also raised the lever's cost.** `lit.ins` is
`merge.all(J.JECons{k, False{}, v, J.JNil{}}, obj, strict, left)`, so a plain non-dotted key goes
through the SAME merge machinery as a dotted one — the machinery that implements duplicate merging,
conflicts, strict-mode errors and the S6.42 first-insertion order. Bypassing it for a dotless object
needs duplicate detection of its own (the `qs` set is quoted keys only, not all keys), and any error
there changes observable behaviour on the ~100 expansion goldens and must still satisfy
`expansion_cap_on_values` and `expansion_cap_on_merges`.

So this is not the small reshape the card first implied. It is a change to the merge path, and it
**overlaps a lever the peer session is building** — a cheap duplicate check for small objects, which is the
same machinery approached from the other side; its card lands with their push. Held for that reason, not for lack of evidence.

### Precommitted gate

- **Primary (counted):** ≥ 10% fewer instructions on
  `--decode --expand-paths safe <corpus>/citm_catalog.fold.toon`, AND ≥ 4% on the dot-free
  `gsoc_2018.toon`, both at `--threads 1`.
- Always: output byte-identical to the oracle on every `*.fold.toon` in the corpus and on a dot-free
  document; `expansion_cap_on_values` and `expansion_cap_on_merges` unchanged and still proved; conform
  1076/1076 on c-1t, c-8t and js.
## EXP-013 — the encoder's edge-White_Space test looks at the last character without reversing the string

| field | value |
|---|---|
| experiment_id | EXP-013 |
| program / def | `port/text.bend` / `has_edge_ws` (S4.8), called by the encoder's value rule `needs_quote` for every string value |
| created (UTC) | 2026-09-23 |
| agent | Claude (session ef481f9c) |
| graveyard sweep | `rg -i 'edge_ws\|has_edge\|ends_ws' perf/` → NE-014 (EXP-010: the same walk for `trim_end`, NEUTRAL on decode because the reversals there were short). Its retry predicate names "an input whose values are long texts" as the target; `gsoc_2018 --encode` (long project descriptions, 16.5-17.2x the original in the quiet-host reference run of `722991e`) is that input |
| status | BUILT 2026-09-23, PROVISIONAL (`perf/NEGATIVE-EVIDENCE.md` NE-018): orientation 1.14-1.17× on `gsoc_2018 --encode` by every estimator at load 8-9, above the gate; cv above the capture's bound. COUNTED 2026-09-23 (cachegrind, deterministic): 13.1% fewer instructions (1.150×); the gate is in CPU time, so it stays PROVISIONAL until a quiet-host capture |
| precommitted | true |

### Hypothesis
`has_edge_ws(s)` is `head_is_ws(s) or head_is_ws(String.reverse(s))`: a full reversed copy of every string value the encoder
writes, taken apart again at once, only to read its last character. An allocation-free walk to the last character answers the
same question. The median CPU time of `--encode` on `gsoc_2018.json` at 1 thread falls by at least 5% against the binary of `722991e`.

### Evidence before the lever
gprof of `722991e` at 1 thread, `gsoc_2018.json --encode`: `spin_8` (`String.reverse`) 33.9% inclusive over 68262 calls, 15168 of
them from `WL_FID_ENCODE_PUT_PRIM` (the value rule), 34128 from the JSON reader and 15168 from line assembly.

### Lever (one)
`ends_ws` (a walk that keeps the previous character, allocating nothing) replaces the reversal inside `has_edge_ws`. Same verdict
by construction (the head of the reverse is the last character). Laws: closed instances of `has_edge_ws` on the empty text, one
character, a leading space, a trailing space, a trailing U+3000 and no edge space, each against `head_is_ws(String.reverse(s))`
written out; beside them conform on c-1t and the docs/mutate lenses.

### Precommitted gate
≥ 5% below the `722991e` binary on `gsoc_2018.json` (`--encode`, `--threads 1`), CPU median, cv ≤ 5% on both arms; conform c-1t
1076/1076; the proof green.

## EXP-014 — a tabular array whose rows all matched the header in order skips the second lockstep walk

| field | value |
|---|---|
| experiment_id | EXP-014 |
| program / def | `port/encode.bend` / `rows_ok.go` → a three-state verdict, `VTab`/`CTab` carry it, `rows` and `row.line` (S4.34–S4.37) |
| created (UTC) | 2026-09-23 |
| agent | Claude (session ef481f9c) |
| graveyard sweep | `rg -i 'row.lock\|rows_ok\|lockstep\|tabular check' perf/NEGATIVE-EVIDENCE.md` → NE-005 (EXP-004 introduced the lockstep walk as a win; no predicate against reusing its verdict) |
| status | BUILT and PARKED 2026-09-23, NEUTRAL at load 14-16 (`perf/NEGATIVE-EVIDENCE.md` NE-017): the gate is not shown; the code is kept as a git stash in the author's scratch clone, not in the port. COUNTED 2026-09-23 (cachegrind): 2.98% fewer instructions on `flights_200k --encode`, below the 3% gate |
| precommitted | true |

### Hypothesis
The tabular test walks every row in lockstep with the header (`row.lock`: one `str_eq` per field), and the row writer walks every row
in lockstep AGAIN to choose between the row's own order and its key map. When the test found every row in header order (the common
case), the writer's second walk is redundant. Carrying "every row locked" from the test to the writer removes one `str_eq` per field
per row; the median CPU time of `--encode` on `flights_200k.json` at 1 thread falls by at least 3% against the EXP-013 binary.

### Evidence before the lever
gprof of the EXP-013 tree, `flights_200k.json --encode` at 1 thread: `spin_269` (`row.lock`) 8.8% inclusive over 400000 calls,
half from `row_ok` and half from `row.line`; `str_eq` (`spin_48`) 1200000 calls under it, each taking both keys apart.

### Lever (one)
`rows_ok.go` returns 0 (not tabular), 1 (tabular, every row locked) or 2 (tabular, some row needs its key map); `VTab`/`CTab` carry
`lk`; `row.line` with `lk` writes the row's own cells in order without the second walk. Same text by construction (the second walk
would return 1 and choose the same cells). Laws: closed instances of the whole encoder on arrays whose rows are all locked, one
row in another key order, and a non-uniform array, against the captured behaviour (goldens) and via `run_pure`; corpus and fuzz.

### Precommitted gate
≥ 3% below the EXP-013 binary on `flights_200k.json` (`--encode`, `--threads 1`), CPU median; conform c-1t 1076/1076; proof green.

## EXP-015 — one walk answers both "a character forces quotes" and "the last character is White_Space"

| field | value |
|---|---|
| experiment_id | EXP-015 |
| program / def | `port/encode.bend` / `needs_quote` (S4.6–S4.17): `T.has_edge_ws` and `has_bad` each walk the whole string value |
| created (UTC) | 2026-09-23 |
| agent | Claude (session ef481f9c) |
| graveyard sweep | `rg -i 'has_bad\|needs_quote\|fuse' perf/NEGATIVE-EVIDENCE.md` → no entry |
| status | BUILT and PARKED 2026-09-23: conform c-1t 1076/1076; 24-round ABBA at load 14-16 on `gsoc_2018 --encode` 1.029× by CPU median (below the 4% gate), 1.083× by minimum, cv 50-99%: the gate is not shown, so the code is kept as a git stash in the author's scratch clone, not in the port. COUNTED 2026-09-23 (cachegrind): 0.94% fewer instructions, a quarter of the gate: NEUTRAL, `perf/NEGATIVE-EVIDENCE.md` NE-021 |
| precommitted | true |

### Hypothesis
After EXP-013 the value rule still walks every string value twice before writing it: `ends_ws` to its last character and
`has_bad` over every character, both over a shared string (each node taken apart). The two answers only ever meet in an OR, so
one walk that tracks the previous character and stops at the first quote-forcing character answers both. The median CPU time of
`--encode` on `gsoc_2018.json` at 1 thread falls by at least 4% against the EXP-013 binary.

### Lever (one)
`quote.scan(s, delim)` = `ends_ws(s) or has_bad(s, delim)` in one loop; `needs_quote` uses it with `T.head_is_ws` for the other edge.
Laws: closed instances of `quote.scan` against `ends_ws(s) or has_bad(s, delim)` written out (empty, a bad character only, a trailing
space only, both, neither, the active delimiter tab), and a mutant that drops either half.

### Precommitted gate
≥ 4% below the EXP-013 binary on `gsoc_2018.json` (`--encode`, `--threads 1`), CPU median; conform c-1t 1076/1076; proof green.

## Allocation profile (2026-09-23, before EXP-018 and EXP-019; the tree of `d851844` plus the four rebased commits of session ef481f9c)

cachegrind (instruction counts, deterministic: two runs of one binary differ by 80 in 7.3×10⁹) of `gsoc_2018 --encode` at
`--threads 1`: `rfc_wrap` 21.8% of all instructions, `term_drop` 14.9%, `spin_8` (`String.reverse`) 8.8%, `span_fade` 5.7%;
on `flights_200k --encode`: `term_drop` 24.5%, `rfc_wrap` 15.6%, `span_fade` 9.1%. A scratch build of the emitted C with
`rfc_wrap` counting its callers three frames deep (return addresses by frame pointer, resolved with `addr2line -i`): **35,607,642
wraps on 3,327,831 input bytes, 10.7 per byte**. In the emitted C every constructor stored into a new node's field passes through
`rfc_seal`, so each list cell built on top of another cell costs one `rfc_wrap` (and later its drop): the count is a count of list
cells built. Per input byte: 1 in the runtime's `file_read_bytes_pack`, 2 in `chunks.join` (the chunk reversed, then pushed back),
1 in the UTF-8 decoder's reversed text (`convert`'s loop), 1 in `String.reverse` of that text, about 2 in the JSON reader's string
accumulation and its reversal, and the rest in line assembly.

## EXP-018 — encoding without --stats validates UTF-8 without building the decoded text

| field | value |
|---|---|
| experiment_id | EXP-018 |
| program / def | `port/text.bend` / the UTF-8 decoder (`utf8.start`, `utf8.scalar`, `utf8.cont`, the `Decoding` state) and `port/cli.bend` / `convert` (S2.2, S8.7) |
| created (UTC) | 2026-09-23 |
| agent | Claude (session ef481f9c) |
| graveyard sweep | `rg -i 'utf8\|utf-8\|decoded text\|chunk' perf/NEGATIVE-EVIDENCE.md` → no entry |
| status | COUNTED_WIN 2026-09-23 (`perf/NEGATIVE-EVIDENCE.md` NE-022): 18.3% fewer instructions on `gsoc_2018 --encode` (gate 8%); CPU confirmation on a quiet host pending |
| precommitted | true |

### Hypothesis
In encode mode the JSON reader reads the BYTES; the decoded text `convert` builds (a reversed character list, then its reverse) is
used only by `--stats`. Without `--stats` both lists are built and dropped: two list cells per character. A decoder that keeps the
same verdict but does not accumulate the text when it is not needed removes them, and the instruction count of `--encode` on
`gsoc_2018.json` at 1 thread falls by at least 8% against the binary of the same tree without the lever.

### Evidence before the lever
The allocation profile above: 3,327,830 wraps inside `CLI_CONVERT` (the decoder's `SCon{Chr{c}, rev}`) and 3,327,830 in
`String.reverse` called from it, 18.7% of all wraps, one each per input byte.

### Lever (one)
The `Decoding` state carries a `keep` flag; `utf8.init()` keeps the text (every existing use and law unchanged), `utf8.init.verdict()`
does not, and a scalar is pushed onto the text only when `keep` holds. `convert` asks for the text only in decode mode or with
`--stats`. The verdict does not read the text, so it is the same by construction. Laws: closed instances of the verdict decoder
against the keeping one on the empty input, ASCII, a two-, three- and four-byte scalar, a surrogate, an overlong form, a cut-short
sequence and a stray continuation byte; and `run_pure` on `--encode` with and without `--stats`, and on invalid UTF-8 in encode mode.

### Precommitted gate
The gate is in INSTRUCTIONS (a counted claim, never called measured): ≥ 8% fewer instructions than the same tree without the lever on
`gsoc_2018.json` (`--encode`, `--threads 1`), cachegrind `--cache-sim=no`, stdout identical; conform c-1t on every case with and
without `TOON_SPEC=1`; the proof green. A CPU-time capture on a quiet host is the confirmation, recorded when it exists.

### One-line invocation
```bash
valgrind --tool=cachegrind --cache-sim=no --cachegrind-out-file=/dev/null <binary> --threads 1 -- --encode perf/e2e/corpus/gsoc_2018.json
```

## EXP-019 — the input bytes are not copied: one 16 MiB first read, and the newest chunk kept as the tail

| field | value |
|---|---|
| experiment_id | EXP-019 |
| program / def | `port/main.bend` / `read.opened`, `chunks.all`, `read.loop`, `read.failed` (S8.5, S8.6) |
| created (UTC) | 2026-09-23 |
| agent | Claude (session ef481f9c) |
| graveyard sweep | `rg -i 'utf8\|utf-8\|decoded text\|chunk' perf/NEGATIVE-EVIDENCE.md` → no entry |
| status | COUNTED_WIN 2026-09-23 (`perf/NEGATIVE-EVIDENCE.md` NE-023): 11.6% fewer instructions on `gsoc_2018 --encode` against EXP-018 (gate 5%). The card was written after EXP-018 was counted and while this lever was being written, not before it: stated here rather than back-dated |
| precommitted | true |

### Hypothesis
`chunks.join(chunks, Nil)` rebuilds even a single chunk (`List.reverse`, then pushed back onto `Nil`): two list cells per input
byte, which is exactly `chunk.onto(List.reverse(c), Nil) == c`. Keeping the newest chunk as the tail removes the copy of that chunk,
and a first read of 16 MiB makes every regular file up to that size one chunk, so the input is never copied. The instruction count of
`--encode` on `gsoc_2018.json` (3.2 MB: four 1 MiB chunks today) at 1 thread falls by at least 5% against the EXP-018 binary.

### Evidence before the lever
The allocation profile above EXP-018: 3,327,830 and 3,327,827 wraps in the read loop's two helpers, one each per input byte.

### Lever (one mechanism, two code points)
`chunks.all` starts the join from the newest chunk instead of from `Nil`; the first `File.read_bytes` asks for 16777216 bytes, the
later ones for 1048576 as before (a pipe returns at most its buffer per read, so a larger size on every read would allocate 16 MiB per
64 KiB on the JavaScript lane). Neither changes a byte of the input: the same list by construction. `main.bend` is the shell, which the
proof book does not import, so there is no law; the evidence is the corpus on every lane, `scripts/stdio-probe.py` (inherited offsets,
pipes, sockets, closed streams) with the same rows as before, and a 19 MB input (two chunks of the new shape) as a path and through a
pipe against the original.

### Precommitted gate
In INSTRUCTIONS (counted, never called measured): ≥ 5% fewer than the EXP-018 binary on `gsoc_2018.json` (`--encode`, `--threads 1`),
stdout identical; conform c-1t with and without `TOON_SPEC=1`; stdio-probe rows unchanged. CPU on a quiet host is the confirmation.

## EXP-021 — the TOON text is built forward from reversed lines: one copy per output character instead of three

| field | value |
|---|---|
| experiment_id | EXP-021 |
| program / def | `port/encode.bend` / `line.prim`, `line.hdr`, `line.inline`, `line.key`, `lines.obj0`, `row.line`, `encode.go`; `port/cli.bend` / `lines.join`, `toon.text` (S4.30–S4.62, S5.100) |
| created (UTC) | 2026-09-23 |
| agent | Claude (session ef481f9c) |
| graveyard sweep | `rg -i 'lines.join\|toon.text\|output text\|line assembly' perf/NEGATIVE-EVIDENCE.md` → no entry |
| status | COUNTED_WIN 2026-09-23 (`perf/NEGATIVE-EVIDENCE.md` NE-024): 11.3% fewer instructions on `gsoc_2018 --encode` against EXP-019 (gate 8%); CPU confirmation on a quiet host pending |
| precommitted | true |

### Hypothesis
Every output character is copied three times after it is first written: each line is built reversed and reversed back
(`String.reverse` in six line builders), `lines.join` pushes it reversed onto a reversed whole text, and `toon.text` reverses that.
Lines handed over still reversed and last first let `lines.join` build the text forward, `rev_onto(line, SCon{LF, acc})`, one copy per
character. The instruction count of `--encode` on `gsoc_2018.json` at 1 thread falls by at least 8% against the EXP-019 binary.

### Evidence before the lever
Re-profile of the EXP-019 tree (the allocation profile's method): 22,296,321 wraps on `gsoc_2018 --encode`; `String.reverse` under
`CLI_CONVERT` 3,089,196, `rev_onto` under it 3,070,236, `String.reverse` in `line.prim` 3,023,315: 41% of the wraps, one each per
output character.

### Lever (one)
The six line builders drop their `String.reverse`; `encode.go` drops its `List.reverse`: `E.encode` returns the lines LAST first, each
REVERSED (no law names `E.encode` or a line builder; the only caller is `enc.read`). `lines.join` then pushes each onto the text
forward. Same bytes by construction: `rev_onto(rev(L), LF ++ acc) = L ++ LF ++ acc`, taken from the last line to the first. Laws:
closed `run_pure` goldens (bytes from the pinned original) on zero lines (an empty root object), one line, several lines at several
depths, a tabular array and a list item, all through the whole pure core; corpus and fuzz.

### Precommitted gate
In INSTRUCTIONS (counted): ≥ 8% fewer than the EXP-019 binary on `gsoc_2018.json` (`--encode`, `--threads 1`), stdout identical;
conform c-1t with and without `TOON_SPEC=1`; the proof green.

## EXP-022 — trim_end returns a text whose last character is not White_Space as it is (EXP-010 retried, counted)

| field | value |
|---|---|
| experiment_id | EXP-022 |
| program / def | `port/text.bend` / `trim_end` (under `T.trim`: the decoder's key-value split, primitive tokens, header inline text; S2.106) |
| created (UTC) | 2026-09-23 |
| agent | Claude (session ef481f9c) |
| graveyard sweep | `rg -i 'trim\|reverse' perf/NEGATIVE-EVIDENCE.md` → NE-014 (EXP-010, this lever, NEUTRAL by wall at load 10-13, CPU 1.057×). Its retry predicate: a quiet host for a cv ≤ 5% capture, OR an input of long text values. Neither holds literally: gsoc was already its input and the host is not quiet. What is new is the instrument: the allocation profile counts this lever's site EXACTLY (below), and cachegrind's count does not depend on the load. The retry is therefore a NEW card with a COUNTED gate; it does not re-open EXP-010's wall-clock gate, and NE-014 stays as written |
| status | COUNTED_WIN 2026-09-23 (`perf/NEGATIVE-EVIDENCE.md` NE-025): 12.5% fewer instructions on `gsoc_2018.toon --decode` against EXP-021 (gate 10%); CPU confirmation on a quiet host pending |
| precommitted | true |

### Hypothesis
`trim_end(s)` is `String.reverse(trim_start(String.reverse(s)))`, two copies of every trimmed text. A text whose last character is
not White_Space is its own trim, and `ends_ws` (EXP-013) finds that by a borrowed walk that allocates nothing. The instruction count
of `--decode` on `gsoc_2018.toon` at 1 thread falls by at least 10% against the EXP-021 binary.

### Evidence before the lever
Allocation profile of the EXP-021 tree on `gsoc_2018.toon --decode` (3,091,396 bytes): 44,389,777 wraps, 14.4 per byte;
`String.reverse` under the trim (`spin_18<spin_10`, reached from `DECODE_PRIM` and from the key-value split) 2,819,811 × 2 and
2,755,347 × 2: 11,150,316 wraps, 25.1% of all.

### Lever (one)
`trim_end.pick(T.ends_ws(s), s)`: `False` returns `s`; `True` runs the old reversal. Both branches compute the same text (a
reversed text whose head is not White_Space is left alone by `trim_start`, and two reversals are the identity). Laws: closed
instances of `trim_end` on no trailing space, a trailing ASCII space, trailing spaces after an inner one, a trailing U+3000, an
all-space text and the empty text, each against the old expression written out; corpus and fuzz.

### Precommitted gate
In INSTRUCTIONS (counted): ≥ 10% fewer than the EXP-021 binary on `gsoc_2018.toon` (`--decode`, `--threads 1`), stdout identical;
conform c-1t with and without `TOON_SPEC=1`; the proof green.

## EXP-024 — a string literal is found and unescaped in one walk: two copies per character instead of four

| field | value |
|---|---|
| experiment_id | EXP-024 |
| program / def | `port/decode.bend` / `lit` (S2.120, S2.122, S2.123): quoted values and quoted tabular cells; keys and headers keep `quote.close` + `unesc` |
| created (UTC) | 2026-09-23 |
| agent | Claude (session ef481f9c) |
| graveyard sweep | `rg -i 'unesc\|quote\|string literal' perf/NEGATIVE-EVIDENCE.md` → no entry |
| status | COUNTED_WIN 2026-09-23 (`perf/NEGATIVE-EVIDENCE.md` NE-028): 8.2% fewer instructions on `gsoc_2018.toon --decode` against EXP-022 (gate 8%, met by 0.2 points); CPU confirmation on a quiet host pending |
| precommitted | true |

### Hypothesis
`lit` walks a quoted literal twice: `quote.go` copies the raw inner text reversed and reverses it, then `unesc` copies it reversed
again and reverses it: four list cells per character. One walk that pairs each backslash with the next character (as `quote.go`
does), unescapes as it goes, remembers the first bad escape and reverses once at the closing quote builds two. The failures keep their
order: no closing quote first, then characters after it, then the first bad escape. The instruction count of `--decode` on
`gsoc_2018.toon` at 1 thread falls by at least 8% against the EXP-022 binary.

### Evidence before the lever
Re-profile of the EXP-022 tree on `gsoc_2018.toon --decode`: 32,936,101 wraps; `quote.go` and its reversal under `DECODE_LIT`
2,428,836 × 2, `unesc`'s accumulation and its reversal 2,441,813 × 2: 9,741,298, 29.6% of all.

### Lever (one)
`lit` becomes one loop over (text, class of its head, unescaper state); the old `lit.q` goes (its only callers were `lit`). Laws:
closed `run_pure` goldens through the whole pure core with bytes from the pinned original: an unterminated literal holding a bad
escape (the quote failure wins), a bad escape followed by characters after the quote (those win), a bad escape alone, all five
escapes, a backslash before the last quote (unterminated), the empty literal, quoted tabular cells with escapes; corpus and fuzz.

### Precommitted gate
In INSTRUCTIONS (counted): ≥ 8% fewer than the EXP-022 binary on `gsoc_2018.toon` (`--decode`, `--threads 1`), stdout identical;
conform c-1t with and without `TOON_SPEC=1`; the proof green.

## EXP-025 — the TOON scanner walks the decoded text still reversed: each line built forward in one copy instead of three

| field | value |
|---|---|
| experiment_id | EXP-025 |
| program / def | `port/decode.bend` / `scan` (S2.102–S2.113): a segmenter over the reversed text (`seg.go`) and a per-line pass in document order (`scan.segs`, `scan.lead`); `port/cli.bend` / the decode arm of `convert.text` without `--stats` |
| created (UTC) | 2026-09-23 |
| agent | Claude (session ef481f9c) |
| graveyard sweep | `rg -i 'scan\|segment' perf/NEGATIVE-EVIDENCE.md` → no entry about the line scanner |
| status | COUNTED_WIN 2026-09-23 (`perf/NEGATIVE-EVIDENCE.md` NE-029): 24.3% fewer instructions on `gsoc_2018.toon --decode` against EXP-024 (gate 8%); CPU confirmation on a quiet host pending |
| precommitted | true |

### Hypothesis
Decode copies every character three times before the structural decoder sees it: `convert` reverses the decoded text, `scan.go`
pushes each line's characters onto a reversed accumulator, and `scan.end` reverses each line back. The UTF-8 decoder already holds the
text reversed; walking THAT pushes each line's characters into forward order, and pushing each finished line onto a list collects the
lines first-first: one copy per character. The instruction count of `--decode` on `gsoc_2018.toon` at 1 thread falls by at least 8%
against the EXP-024 binary.

### Evidence before the lever
Allocation profile of the EXP-022 tree on `gsoc_2018.toon --decode`: `String.reverse` under `CLI_CONVERT` 3,089,196 wraps, the
scanner's accumulation 2,995,661 and its per-line reversal 2,995,661: 9,080,518 of 32,936,101.

### Lever (one)
`seg.go(rev, class of its head, at a line's end, current line, lines)`: an LF closes a line; the FIRST character met for a line is its
LAST, so a CR there is the one `cr.drop` removes; any other character is pushed. The per-line pass consumes the leading U+0020 run as
the indent (no copy), and the TAB flag is "the rest starts with a TAB" (the leading run is spaces then a TAB or not at all: S2.104,
S2.108); then `scan.line` and `scan.check` as before, in document order, so the first failure is still the earliest line. The byte order
mark is the head of the first line. `scan(text)` stays for every other caller and every law (it reverses its argument once); decode with
`--stats` keeps the forward path, whose estimate reads the forward text. Laws: closed `run_pure` goldens from the pinned original on
CRLF endings, a lone CR, CR CR, blank and whitespace-only lines, a TAB in the indent (strict failure) and after it, two strict failures
(the first wins), a byte order mark, an empty input, a text without a final LF; corpus and fuzz.

### Precommitted gate
In INSTRUCTIONS (counted): ≥ 8% fewer than the EXP-024 binary on `gsoc_2018.toon` (`--decode`, `--threads 1`), stdout identical;
conform c-1t with and without `TOON_SPEC=1`; the proof green.

## EXP-026 — the encoder's numeric-like test borrows the string and stops at the lexer's sink

| field | value |
|---|---|
| experiment_id | EXP-026 |
| program / def | `port/f64.bend` / `is_like` (S4.161), called by `E.needs_quote` for every string value the encoder writes |
| created (UTC) | 2026-09-23 |
| agent | Claude (session ef481f9c) |
| graveyard sweep | `rg -i 'is_like\|numeric-like\|lexer' perf/NEGATIVE-EVIDENCE.md` → no entry |
| status | COUNTED_WIN 2026-09-23 (`perf/NEGATIVE-EVIDENCE.md` NE-030): 13.5% fewer instructions on `gsoc_2018 --encode` against EXP-025 (gate 5%); CPU confirmation on a quiet host pending |
| precommitted | true |

### Hypothesis
`is_like(s)` runs the number lexer (`lex.run` → `lex.go`) over the WHOLE string, building a `Lex` record per character even after
phase 8 (the sink) is reached, and it rebuilds the head cell, so it owns `s`. It is the only one of `needs_quote`'s six checks that owns
its argument (a probe's keep audit: the other five borrow), so every string value is kept, and the writer then takes a shared text
apart: one `span_fade` per character. A recognizer over the same phase table that only matches characters (so the compiler borrows the
string) and returns at the sink gives the same verdict, keeps no string, and allocates nothing. The instruction count of `--encode` on
`gsoc_2018.json` at 1 thread falls by at least 5% against the EXP-025 binary.

### Evidence before the lever
`span_fade` tallied by caller on the EXP-025 binary, `gsoc_2018 --encode`: 6,271,545 calls, 2,795,574 of them under `PUT_PRIM`'s
string writer (one per character of the string values); the rest is the byte list (NE-012: a `List` is never borrowed).

### Lever (one)
`like.ph(ph, k)`: the lexer's phase table with `like = True`, phases only; `like.go(s, ph)`: walks `s` by matching, returns
`False` at phase 8 and `lex.ok(ph)` at the end; `is_like` drops a leading '-' and starts it. The lexer stays for the readers
(`F.literal`, `like = False`) and as `is_like.lex`, the specification the laws compare against. Laws: closed instances
`is_like(x) == is_like.lex(x)` covering every accepting phase (1, 2, 4, 7), every refusal path, a leading '-', '-' alone, the empty
text, a long non-numeric text; beside them the pinned original on EVERY string up to length 6 over the alphabet `0 5 . e E + - a`
(one representative per lexer class), each as the value of a one-key object through `--encode`, and the corpus.

### Precommitted gate
In INSTRUCTIONS (counted): ≥ 5% fewer than the EXP-025 binary on `gsoc_2018.json` (`--encode`, `--threads 1`), stdout identical;
conform c-1t with and without `TOON_SPEC=1`; the exhaustive comparison 0 differences; the proof green.

## EXP-027 — the JSON reader takes a plain ASCII byte inside a string without the per-byte dispatch

| field | value |
|---|---|
| experiment_id | EXP-027 |
| program / def | `port/json.bend` / `run` (S2.15, S2.40): a fast arm `step.fast` beside `step`, behind `F.twin.on` |
| created (UTC) | 2026-09-23 |
| agent | Claude (session ef481f9c) |
| graveyard sweep | `rg -i 'json reader\|J.step\|byte.cls\|string byte' perf/NEGATIVE-EVIDENCE.md` → NE-019 (EXP-016: `byte.cls` alone made cheaper bought 1.4% of the instructions, because its selects are cheap). This lever is a different one: it skips the WHOLE dispatch of a string byte (`byte.cls`, both position helpers, `step.mode`, `str`, `str.byte`), and its gate is an instruction count, which is what showed NE-019's selects to be cheap |
| status | COUNTED_WIN 2026-09-23 (`perf/NEGATIVE-EVIDENCE.md` NE-031): 14.5% fewer instructions on `gsoc_2018 --encode` against EXP-026 (gate 5%). The SHAPE changed after this card: the carded `step.fast` wrapper met the gate on gsoc (-11.9%) but ADDED 1.2% on `canada --encode` (a byte test paid by every byte outside strings); a mode-first variant still added 0.9% (a keep of the state per byte); the arm inside `run`'s own match (`step.in_str`) is what is kept: gsoc -14.5%, flights -1.9%, canada -0.16%. The laws are those of the kept shape |
| precommitted | true |

### Hypothesis
`JSON_STEP` and `JSON_RUN` are 26% of the instructions of `gsoc_2018 --encode` on the EXP-026 binary (920 million for 3.3 million
bytes, about 280 per byte), and most bytes of that input are string content. A byte 20-7F other than `"` and `\` inside a string
does one thing: the character joins the text and the column moves by one (`str.byte`'s ASCII arm; the line cannot move, the byte is
not LF). An arm that checks that condition and does exactly that skips the rest, and the instruction count of `--encode` on
`gsoc_2018.json` at 1 thread falls by at least 5% against the EXP-026 binary.

### Lever (one)
`step.fast(st, b, spec)` = `step.fast.str(F.twin.on(spec, plain(b)), st, b, spec)`: the fast arm matches an `MStr` state and builds
`St{MStr{SCon{Chr{b}, rev}, key, 0n, 0}, stack, depth, l, 1n+c, root}`, as `str.byte` does; every other state, and every state under
`TOON_SPEC=1`, goes to `step`, unchanged (so `json_error_is_sticky` still speaks about the step `run` falls back to). Laws: the
quantified step_fast_is_step_under_switch (the carded law of the carded shape, superseded when the shape changed: the kept law is `step_in_str_slow_is_step`, see the status line; for every state and byte, `step.fast(st, b, True) == step(st, b, True)`), closed instances
`step.fast(st, b, False) == step(st, b, False)` on plain bytes at both ends of the range, a key, a pending multi-byte `need`, and on
`"`, `\`, a control byte, a non-ASCII byte and a non-string state; corpus with and without the switch, fuzz.

### Precommitted gate
In INSTRUCTIONS (counted): ≥ 5% fewer than the EXP-026 binary on `gsoc_2018.json` (`--encode`, `--threads 1`), stdout identical;
conform c-1t with and without `TOON_SPEC=1`; the proof green.

## EXP-028 — the port has integer fast paths on both sides and nothing for ordinary decimals

| field | value |
|---|---|
| experiment_id | EXP-028 |
| program / def | `port/f64.bend` / `token.short` (the reader's gate, S4.143) and the printer's integer twin (S4.131, EXP-001) |
| created (UTC) | 2026-09-23 |
| agent | Claude (Claude Code session) |
| graveyard sweep | `rg -i 'decimal\|fraction\|integer fast\|short' perf/` → NE-001 (EXP-001, the printer's INTEGER fast path), NE-002 (EXP-002, the reader's INTEGER fast path, bound 14 digits), NE-003 (EXP-003, division by a power of ten), NE-016 (EXP-012, the shortest-digit loop in words). Every one of them is about integers or about the digit LOOP; **none is about a non-integer value taking a fast path**, and no do-not-retry applies |
| status | **CLOSED, NOT ADMITTED (2026-09-23)** — the reader half was built in a scratch tree, passed 1076/1076, counted −0.7% on canada and +0.9% on the short-decimal twin against a ≥25% gate, and was not merged; `port/` was never modified. Ledgered as `perf/NEGATIVE-EVIDENCE.md` NE-033, which also CORRECTS this card's attribution: the decimal penalty is in the PRINTER, not the reader |
| precommitted | true |

### The measurement that localises it (counted, cachegrind, deterministic)

`canada` is the worst cell of the counted corpus comparison: **13.33×** the original's instructions on
encode, **4,893 instructions per input byte** against the original's 367, where every other document in
the suite sits between 3.85× and 9.72×. It has 111,126 numbers with a median of 18 characters each.

Three twins of that document, same shape, same number COUNT, different number TEXT:

| twin | median chars/number | port I-refs | oracle I-refs | port / oracle | instr / number |
|---|---|---|---|---|---|
| short integers | 2 | 1,890,963,549 | 582,449,097 | **3.25×** | 17,015 |
| short decimals | 7 | 6,922,497,773 | 586,761,517 | **11.80×** | 62,294 |
| `canada` as published | 18 | 11,014,963,500 | 826,582,787 | **13.33×** | 99,121 |

**The oracle is nearly flat across all three** (582M, 587M, 827M). The port is not. And the jump is not
the digit count: a 7-character decimal carries about 5 significant digits, comfortably inside
`token.short`'s 14-digit bound, and it already costs **11.80×**. What changes between row 1 and row 2 is
the presence of a FRACTION.

### Hypothesis

`token.short` refuses any token with a fraction — the law `int_text_fraction_refused` pins exactly that —
and the printer's fast twin is likewise an integer path. So a value like `65.613471` takes the full
correctly-rounded big-natural route in BOTH directions, while `65613471` takes a fast path in both. A
decimal whose significand fits a machine word is arithmetically no harder than the integer: `65.613471`
is `65613471 × 10^-6`, and EXP-003 already provides an exact division by a power of ten. Giving the
reader and the printer a fast path for a non-integer whose significand fits should move the decimal rows
toward the integer row.

### Why this is the right SHAPE (NE-027's rule)

It does not make an operation cheaper; it stops a whole big-natural computation from happening for the
common case. NE-019, NE-020 and NE-027 each made an operation cheaper and returned 2%, 1% and 0.11%.
The levers that paid removed work wholesale.

### Precommitted gate

- **Primary (counted):** ≥ 25% fewer instructions on `--encode` of `canada.json` at `--threads 1`,
  and the short-decimal twin's ratio against the oracle below 8× (from 11.80×).
- Always: output byte-identical to the oracle on `canada.json`, both twins, and every `encnum_*` and
  `decnum_*` case; the existing number laws unchanged and still proved; conform 1076/1076 on c-1t,
  c-8t and js.
- The twins are regenerable from `perf/e2e/counted.py`'s corpus by the substitutions recorded here; they
  are not committed (the corpus directory is gitignored).

### The trap

Correct rounding is the whole contract of this path. A significand that fits a word does NOT mean the
decimal→binary64 conversion is exact: `0.1` is not representable, and the fast path must round exactly as
the slow one does or the goldens will diverge on the first tie. The existing closed laws on the reader's
boundary values are the floor, not the ceiling, and a new fast path needs its own boundary laws plus the
million-number differential before it is believed.
## Orientation of the allocation family in CPU time (2026-09-23 18:33, NOT a capture)

Whether the counted levers (EXP-013 to 027) show up as time: `ab.py` (the author's interleaved ABBA, 8 rounds, `--threads 1`) of
the `722991e` binary against the `cbdfba6` binary on a host at load 13-15. Every capture rule is not met (one arm's cv is above 5%
on every input, and there is no A/A arm), so these are orientation, never a ratio a document may quote as MEASURED. CPU medians,
stdout identical in every pair:

| input | mode | before (CPU ms) | after (CPU ms) | CPU ratio | cv before / after | counted ratio (instructions) |
|---|---|---|---|---|---|---|
| `gsoc_2018` | `--encode` | 850.8 | 368.3 | 2.31 | 4.7% / 5.9% | 2.434 |
| `gsoc_2018` | `--decode` | 799.4 | 556.2 | 1.44 | 4.0% / 4.6% | 1.783 |
| `flights_200k` | `--encode` | 5811.6 | 4954.7 | 1.17 | 8.7% / 9.7% | 1.204 |

Reading: on encode the time follows the count closely; on decode it follows it less (1.44 against 1.78), so part of what the decode
levers removed was cheap instructions and part of what remains is memory traffic the count does not see.

## EXP-029 — a small JSON object detects repeated keys by walking its own chain, not the key table

| field | value |
|---|---|
| experiment_id | EXP-029 |
| program / def | `port/json.bend` / `push`'s object arm, `obj.member` (S2.28, S2.29); `port/text.bend` / `kt.is_empty` |
| created (UTC) | 2026-09-23 |
| agent | Claude (session ef481f9c) |
| graveyard sweep | `rg -i 'kt\|key table\|repeated\|16000' perf/NEGATIVE-EVIDENCE.md` → NE-004 (EXP-004: the key table replaced a walk of the chain per key, which made one object of 16000 keys take 20.5 s). This lever keeps that protection: the walk is used only while the object has fewer than 8 members, and the table is built once when the 8th arrives |
| status | COUNTED_WIN 2026-09-23 (`perf/NEGATIVE-EVIDENCE.md` NE-032): 12.5% fewer instructions on `flights_200k --encode` against `3a6f7f6` (gate 5%); `gsoc_2018` 3.2% fewer, `canada` +0.007% (allowance 0.5%); CPU confirmation on a quiet host pending |
| precommitted | true |

### Hypothesis
Every member of every JSON object is looked up in and inserted into `T.KT`, a binary trie over 16 hash bits: the key is hashed twice
and each insertion copies a path of up to 16 nodes. `flights_200k` has 200000 objects of 3 keys; the allocation profile puts about 17M
list-cell wraps under `KT_PUT_GO` there. For an object of fewer than 8 members the chain itself answers "is this key already here"
(it holds each key once, the same set the table holds) by a walk of at most 7 comparisons that allocates nothing. The instruction
count of `--encode` on `flights_200k.json` at 1 thread falls by at least 5% against the binary of `3a6f7f6`.

### Lever (one)
While the object's table is empty (`kt.is_empty`), a member is checked with `obj.has` against the chain and not inserted anywhere;
the member that makes the chain 8 long builds the table from the whole chain (`kt.of_chain`), and from then on the table is used as
before. The repeated-key rules (first position, last value, the map of last values) are unchanged. Laws: closed `run_pure` goldens
from the pinned original: a repeated key in objects of 2, 7, 8 and 9 members (before, at and after the switch), the repeat at the
first and at the last position, a repeat after the switch of a key seen before it, nested objects each small; corpus, fuzz
(collide), and the scale lens (large objects keep the table).

### Precommitted gate
In INSTRUCTIONS (counted): ≥ 5% fewer than the binary of `3a6f7f6` on `flights_200k.json` (`--encode`, `--threads 1`), stdout
identical; `gsoc_2018` and `canada` not worse by more than 0.5%; conform c-1t with and without `TOON_SPEC=1`; the proof green.

## EXP-030 — encoding reads the input bytes once: the UTF-8 gate and the JSON reader step together

| field | value |
|---|---|
| experiment_id | EXP-030 |
| program / def | `port/json.bend` / `run` and `read` (S2.4, S2.45); `port/text.bend` / `utf8.bytes`, `utf8.step` (S2.2); `port/cli.bend` / `convert`, `convert.text` (S8.7, S8.8) |
| created (UTC) | 2026-09-23 |
| agent | Claude (session ef481f9c) |
| graveyard sweep | `rg -i 'utf8\|utf-8 gate\|fus(e\|ed\|ion)\|one walk\|single pass' perf/NEGATIVE-EVIDENCE.md perf/PERF-LEDGER.md` → no entry; EXP-018 (NE-022) is the neighbour: it stopped building the decoded text when nothing reads it, and kept the second walk |
| status | NEUTRAL 2026-09-23 (`perf/NEGATIVE-EVIDENCE.md` NE-034): 1.18% fewer instructions on `flights_200k --encode` (gate 2%, not met); not merged, parked; the decode half is carded separately as EXP-031 |
| precommitted | true |

### Hypothesis
`convert` walks the input byte list twice in encode mode: `T.utf8.bytes` for the UTF-8 verdict (S2.2), then `J.read` for the value.
The list has a later use when the first walk runs, so the emitted C keeps it (`term_keep`) and the decoder, which owns its argument,
takes every shared cell apart: the frame-pointer tally of `span_fade` on `flights_200k --encode` (the binary of the EXP-029 code,
`faaccac`) puts 9,863,892 of 64,361,865 calls in `CLI_CONVERT`, one per input byte (the file is 9.4 MB). Decode mode pays the same,
because `convert` passes the bytes on to `convert.text`, which reads them only in encode mode. One walk that steps the decoder and
the reader together owns an unshared list: no keep, no span_fade per byte, and one traversal instead of two. The instruction count
of `--encode` on `flights_200k.json` at 1 thread falls by at least 2% against the binary of `faaccac`.

### Lever (one)
`J.read.u(bytes, u, spec)`: one tail-recursive walk whose arms are `run`'s arms with `T.utf8.step(u, b)` beside each step; it returns
the decoder's final state and the reader's result. `convert` decides the mode first: decode walks the bytes once with the decoder
alone (the bytes have no later use); encode runs `J.read.u` over the BOM-stripped bytes (EF BB BF is one complete valid scalar, so
the verdict with and without it is the same, and `bom.text` drops the U+FEFF the other path would have decoded). The UTF-8 verdict
still decides first: an invalid input prints S2.2's message whatever the reader found. Laws: the quantified
`run.u(bytes, u, st, spec) == RU{utf8.bytes(bytes, u), run(bytes, st, spec)}` by induction on the bytes; closed `run_pure` goldens
from the pinned original for invalid UTF-8 before, inside and after a JSON error, a BOM with and without `--stats`, an invalid byte
inside a string and a key; corpus, fuzz (mutate, docs), stdio probes.

### Precommitted gate
In INSTRUCTIONS (counted): ≥ 2% fewer than the binary of `faaccac` on `flights_200k.json` (`--encode`, `--threads 1`), stdout
identical; `gsoc_2018` (encode and decode) and `canada` (encode) not worse by more than 0.5%; conform c-1t with and without
`TOON_SPEC=1`; the proof green.

## EXP-031 — decode mode stops handing the input bytes on to the encode arm

| field | value |
|---|---|
| experiment_id | EXP-031 |
| program / def | `port/cli.bend` / `convert`, `convert.text` (S8.7, S8.8) |
| created (UTC) | 2026-09-23 |
| agent | Claude (session ef481f9c) |
| graveyard sweep | `rg -i 'utf8\|convert\|bytes' perf/NEGATIVE-EVIDENCE.md` → NE-034 (EXP-030, NEUTRAL: the fused encode walk; its uncarded decode cells are what this card tests, OUT OF SAMPLE) and NE-022 (EXP-018) |
| status | COUNTED_WIN on the primary gate, ENCODE GUARD FAILED 2026-09-23 (`perf/NEGATIVE-EVIDENCE.md` NE-035): `semanticscholar --decode` 18.18% fewer instructions (gate 5%), out of sample; `gsoc_2018 --encode` 0.80% MORE (allowance 0.5%). Kept by the author as a trade-off, stated in NE-035; the owner may revert it |
| precommitted | true |

### Hypothesis
`convert` passes the input bytes to `convert.text` in every mode, and only the encode arm reads them there; so in decode mode the
list is kept alive through the whole decoding and the UTF-8 decoder takes shared cells apart. NE-034 counted the decode cells of a
lever that also removed this (gsoc 19.56%, flights 3.90%, canada 5.27% fewer), but its card did not gate them. This card tests the
decode half ALONE, on inputs that count never ran: the instruction count of `--decode` on the e2e corpus's `semanticscholar.toon`
at 1 thread falls by at least 5% against the binary of `faaccac`.

### Lever (one)
`convert` decides the mode first. Decode: `convert.text` receives the decoder's verdict and the options, not the bytes. Encode: the
code of `faaccac` unchanged (the UTF-8 walk, then `J.read` over the mark-dropped bytes). Laws: the existing goldens through
`run_pure` for decode (invalid UTF-8, a mark, `--stats`), plus closed goldens from the pinned original for an invalid byte after a
decode error and a truncated sequence at the end of a TOON text.

### Precommitted gate
In INSTRUCTIONS (counted), stdout identical: ≥ 5% fewer than the binary of `faaccac` on `semanticscholar.toon --decode`;
`twitter.toon`, `citm_catalog.toon` and `openapi_github.toon` `--decode` not worse by more than 0.5% (a prediction of their
direction, not a gate: fewer); the encode cells `gsoc_2018`, `flights_200k`, `canada` not worse by more than 0.5%; conform c-1t
with and without `TOON_SPEC=1`; the proof green.

## EXP-032 — on top of EXP-031, encoding reads the input bytes once (NE-034's fused walk, retried)

| field | value |
|---|---|
| experiment_id | EXP-032 |
| program / def | `port/json.bend` / `run.u`, `read.u` (S2.4, S2.45); `port/cli.bend` / `convert.mode`'s encode arm, `convert.enc` (S8.7) |
| created (UTC) | 2026-09-23 |
| agent | Claude (session ef481f9c) |
| graveyard sweep | NE-034 (EXP-030, NEUTRAL: 1.18% on `flights_200k --encode` against a 2% gate); its retry predicate "EXP-031 is kept and a new count of the fused encode walk ON TOP of it clears a new card's gate" now holds (NE-035) |
| status | COUNTED_WIN on the primary gate, DECODE GUARD FAILED 2026-09-23 (`perf/NEGATIVE-EVIDENCE.md` NE-036): `semanticscholar --encode` 3.35% fewer instructions than EXP-031 (gate 1.5%); four decode cells 1.0-1.8% more on unchanged decode code; the EXP-031+032 stack is fewer than `faaccac` on all eleven cells counted. Kept, stated in NE-036 |
| precommitted | true |

### Hypothesis
After EXP-031 the encode arm alone still walks the bytes twice with the list shared, and its UTF-8 walk costs about 7 more
instructions per byte than before (bead `toon_bend-1yf`). NE-034's fused walk removes that walk. The instruction count of `--encode`
on the e2e corpus's `semanticscholar.json` (never counted by EXP-030 or EXP-031) at 1 thread falls by at least 1.5% against the
binary of the EXP-031 code.

### Lever (one)
NE-034's code, unchanged in substance, on top of EXP-031: `J.run.u` / `J.read.u` and the quantified law `run_u_is_both`, the five
closed goldens of NE-034; the encode arm of `convert.mode` runs `J.read.u` over the mark-dropped bytes and `convert.enc` decides the
UTF-8 verdict first.

### Precommitted gate
In INSTRUCTIONS (counted), stdout identical: ≥ 1.5% fewer than the EXP-031 binary on `semanticscholar.json --encode`;
`gsoc_2018`, `flights_200k`, `canada` `--encode` not worse by more than 0.5% (predicted fewer); `semanticscholar.toon` and
`gsoc_2018.toon` `--decode` not worse by more than 0.5%; conform c-1t with and without `TOON_SPEC=1`; the proof green.
