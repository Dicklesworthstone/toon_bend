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
| status | BUILT 2026-09-23, PROVISIONAL (`perf/NEGATIVE-EVIDENCE.md` NE-016). The card's "pair of packed Nat words" became three U32 words: the Nat version was right but its closed laws did not finish in the checker. Orientation (CPU estimator, load 17-20) 1.84× on `canada --decode`, above the gate; wall cv far above the capture's bound |
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
  `bend PROOF.bend` unchanged at 478 laws.
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

### Precommitted gate

- **Primary (counted):** ≥ 10% fewer instructions on
  `--decode --expand-paths safe <corpus>/citm_catalog.fold.toon`, AND ≥ 4% on the dot-free
  `gsoc_2018.toon`, both at `--threads 1`.
- Always: output byte-identical to the oracle on every `*.fold.toon` in the corpus and on a dot-free
  document; `expansion_cap_on_values` and `expansion_cap_on_merges` unchanged and still proved; conform
  1076/1076 on c-1t, c-8t and js.
