# Round 17: non-author hostile review of toon_bend

| field | value |
|---|---|
| reviewed commit | `722991e72d2a3fd4aa198a4aaf041bc43592c163` (clone `/data/tmp/review_R17/clone`, detached; `git rev-parse HEAD` printed that hash) |
| original | `oracle/toon` → `/data/projects/toon_bend/oracle/toon`, sha256 `821287eaf1a6d320ee1ef7604e74e3cefaa42b69445c96abb9dd310782d04030`, the same as `docs/PIN.toml` |
| Bend | `bun /tmp/bend/bend2/main.ts`, `/tmp/bend` at `15ae0c86f3193b8f645b4bedbc438655b648d0da`, `BEND_NO_TELEMETRY=1` |
| tools | bun 1.4.2, Ubuntu clang 21.1.8, Python 3.14.4 |
| port binaries | `bin/toon` (native build, 30.9 s, peak RSS 2.75 GB, exit 0), `bin/toon.js` (JS build, exit 0), mutants `r17/mut/M*/toon_mut` |
| host | shared, 8 cores, 30 GB. Load average was 6.2 at the start (12:03), 12 to 20 during the run, and 15.3 at the end (12:40). Available memory fell to 5 GB once. No timing in this report is evidence of speed |

Harness: `r17/cmp.py` runs `./oracle/toon ARGV` and `<port> --threads T -- ARGV` on the same stdin and compares stdout, stderr and the exit code byte for byte. `TOON_SPEC` is removed from the environment unless a run sets it. Executions count every run: the original's runs plus the port's runs.

## Behavior findings

| id | sev | class | what | spec |
|---|---|---|---|---|
| R17-1 | MEDIUM | BEHAVIOR (mutant) | Mutant M3 of `hot.merge` (`port/decode.bend`, the `HGObj` arm) survives the corpus (c-1t 1076/1076) and the whole 450-law proof (`All terms check.`). It lets a failure found inside a NESTED merge win over an EARLIER failure of the same merge, and it changes bytes. This is R16-2's disease one level down: `dup_keep_is_first` pins `dup.keep`, but no law or case pins how `hot.merge` threads `err` into and out of the recursive call | S3.26, S9.151 |

No unmutated difference between the port and the original was found in any lens (tables below).

### R17-1 reproduction

The mutation (`r17/mut/M3/diff.txt`):
```
1352c1352
<       +r = hot.merge(se, hot.look(se, s0), s0, o0, strict, err)
---
>       +r = hot.merge(se, hot.look(se, s0), s0, o0, strict, None{})
1354c1354
<       hot.merge(t, hot.look(t, m2), m2, ord, strict, hr.err(r))
---
>       hot.merge(t, hot.look(t, m2), m2, ord, strict, dup.keep(hr.err(r), err))
```
The input, with the output verbatim:
```
$ cd /data/tmp/review_R17/clone && I='x:\n  b: 1\n  c:\n    d: 1\nx:\n  b: 2\n  c:\n    d: 2\n'
$ printf "$I" | ./oracle/toon --decode; echo "oracle exit $?"
Failed to decode TOON: Duplicate sibling key "b"
oracle exit 1
$ printf "$I" | r17/mut/M3/toon_mut --threads 1 -- --decode       (and --threads 8: the same)
Failed to decode TOON: Duplicate sibling key "d"
M3 t1 exit 1
$ printf "$I" | bin/toon --threads 1 -- --decode
Failed to decode TOON: Duplicate sibling key "b"
port exit 1
```
Corpus: `r17/mut_build.sh M3` gave `{'lane': 'c-1t', 'passed': 1076, 'failed': 0, 'inconclusive': 0, 'stderr_compared': True, 'verdict': 'PASS', 'oracle_identity_checked': True}`.
Proof: `r17/proof_capped.sh r17/mut/M3/src …` gave `PROOF rc=0 killed=0 peak_kb=4706492 secs=490 last: All terms check.`
Observability: `gen_merge.py 1740 3000` found 498 differing executions (249 inputs × 2 thread counts) with M3 as the port, and 0 with the real port. The existing lenses (`gen_dup2.py 1711`, the R16 dup lenses) do not generate this pattern: an earlier conflict in the later object, then a conflict inside one of its nested objects.
Expected (the original, and the port as committed): the first failure in document order, `"b"`. The fix is a case or a law that pins `hot.merge`'s error threading, for example this input as a golden, or a closed law on `D.hot.dups` whose source holds an earlier primitive conflict followed by a nested one.

### Mutants: all results

| mutant | def | change | corpus c-1t | `PROOF.bend` | verdict |
|---|---|---|---|---|---|
| M1 | `div_p10.fin` (live through `from_dec_p10.go`) | drop the sticky remainder | **KILLED**, 1073/1076 (`encnum_long_mantissa`, `decnum_long_mantissa`, `decnum_exact_halfway`) | not run | killed |
| M2 | `from_dec_p10.go` | guard 57 → 54 quotient bits | PASS 1076/1076 | not run | EQUIVALENT by evidence: 54 bits still leave one round bit beside the sticky flag. 0 differences in `diff-fuzz numbers --seed 17021` (100 inputs) and `gen_words.py 1730` (40000 numbers). Not a finding |
| M3 | `hot.merge` HGObj arm | the nested failure wins over an earlier one | PASS 1076/1076 | `All terms check.` | **R17-1** |
| M4 | `dups.go` object arm | the same change as M3 | PASS 1076/1076 | not run | EQUIVALENT: `dups` is called only from `row.obj` (tabular rows), whose values are primitives, so the object arm cannot be reached. The R17-1 input gives `"b"` on M4. Not a finding |
| M5 | `encode.bend:589` lean-fold gate (EXP-008) | lean even when folding is on | **KILLED**, 1073/1076 (`enc_fold_root_literal_nested`, `enc_fold_dotted_parent_path`, `fx_enc_key_folding_05`) | not run | killed |
| M6 | `dgw.mo2` (EXP-012) | top word masked to 19 bits, which is wrong only when a·k ≥ 2^67 | PASS 1076/1076 | not run | EQUIVALENT by evidence: over 200000 random doubles in the word domain (`r17/m6scan.py`, seeds 3 and 9), the largest value the loop forms is 2^66.966 (0.1029999658637419). So the word loop's real headroom is below 2^67. The code comment's bound, 10s < 2^68, is true. Not a finding |
| M7 | `from_dec_p10.go` | guard 57 → 52 | **KILLED**, 1064/1076 (`encnum_decimals`, `encnum_exponents`, `decnum_*`, `large_tabular_1500`, …) | not run | killed |

About the dispatch sweep's pinned gates (368ed75): an arm swap in `from_dec_p10.pick`, `dg.step.with`, `dg.digit_fast.fin`, `token.short` or `num.defer` is killed by construction, because each law restates that arm. I therefore attacked what those laws do NOT pin: the bodies behind the arms (M1, M2, M7, the unpinned fast arm of `from_dec_p10.pick`, all killed or equivalent), the EXP-012 word arithmetic (M6, equivalent), and the error threading next to the R16-2 law (M3, survives). EXP-012 itself is pinned closely: `dgw_fits_*` pins all four 2^64 bounds and `dgw_run_tie` pins the tie parity. I built no mutant for those.

## Document findings

| id | sev | class | claim | refuted by |
|---|---|---|---|---|
| R17-2 | LOW | DOCUMENT | `port/LAWS.bend:200-202`: "every fast twin is a two-arm match on this gate (F.shortest_fast through F.int.fit, F.int_text.ok, F.div_p10, F.from_dec_p10)". The dispatch-sweep block (`LAWS.bend` ~1805-1824) and commit `368ed75` list `div_p10.pick` among "the fast/spec gates … the corpus cannot see" and pin it | `rg -n 'div_p10\(' port/ --glob '!LAWS.bend' --glob '!PROOF.bend'` matches only the def itself (`port/f64.bend:248`). `div_p10` has no caller in the program, so it is dead code. The laws `div_p10_37_1`, `div_p10_k5`, `div_p10_k7` and `div_p10_pick_takes_the_fast_quotient` pin a def that no run executes. Since the re-pin, JSON numbers are read by `F.token_value` (`port/json.bend:786,810`) |
| R17-3 | LOW | DOCUMENT | `README.md:49`: "the three fast twins that exist are bound to their specification twins by ONE quantified law" | `rg -n 'twin\.on\(\|pre\.if\(spec\|dgw\.fits\(st\)' port/*.bend` shows live selectors for EXP-001 (`f64.bend:967` int.fit), EXP-002 (`:274`), EXP-003 (`:374`), EXP-006 and EXP-012 (`:967` dfast → `:832`), EXP-008 (`encode.bend:589`) and EXP-007 (`encode.bend:881`). That is at least seven levers behind the gate, not three. The rest of the sentence (no quantified `fast == spec` law) stands |

Checked and consistent: `./scripts/law-coverage.sh` → `{"laws": 450, "proofs": 450, … "verdict": "OK"}`. My own count of `port/LAWS.bend` gives 38 quantified, 117 closed unit and 295 golden laws, which matches PORT_STATE and FEATURE_PARITY. `python3 scripts/claims-audit.py` → `{… "findings": 0, … "laws": 450, "cases": 1076, … "verdict": "OK"}`. `./scripts/converge.sh docs/PORT_STATE.md` → `NOT_CONVERGED` (as documented). The unmutated proof at 722991e: `PROOF rc=0 killed=0 peak_kb=4563936 secs=507 last: All terms check.`

## Clean areas: compared executions (all on 722991e)

| lens (script, seed) | target | inputs | executions | diffs |
|---|---|---|---|---|
| `gen_words.py` 1701 (t1); 1702, 1703, 1704, 1705 (t1,8 × ±`TOON_SPEC=1`) | EXP-012: doubles whose fixed state (r, s, mp, mm, modelled in `state.py`) has its largest operand at bit length 58 to 70, with each operand near 2^64 (about 2600 per seed at exactly 64 bits and 14500 at 65). Also edges (man = 2^52, 2^53−1), short decimals, ±3 ulps around powers of 2 and 10, exact halfway texts, negatives; both directions; `repr` and `%.17g` texts | 8 + 4×500 documents (≈ 802400 numbers) | 10016 | 0 |
| `gen_ties.py` 1720 (t1,8 × ±spec) | 20000 doubles whose last digit is decided by an EXACT tie (2·rem = s, both ends reached), all in the word domain; both directions | 80 documents | 400 | 0 |
| `gen_pow.py` (t1,8 × ±spec) | every power of two 2^-1074..2^1023 and of ten 1e-323..1e308, ±2 ulps (subnormals, the lower neighbour of every power of two), plus negatives; both directions | 15576 numbers / 78 documents | 390 | 0 |
| `raw_boundary17.py` (R16's sweep, widened: 48 to 52 integer digits, a 50-digit 9…9 lead, exponents 249 to 252, 258 and 259) | `num.safe` bounds: alone, in a 141-item array, in an object, with `--stats`; t1,8, then `TOON_SPEC=1` t1 | 24888 | 74664 + 49776 | 0 |
| `probe.py` (t1,8) | JSON exponent overflow and positions (`1e2147483648x`, `0e…`, `{"a":1e999999999999`), the max-finite and halfway-to-overflow edges, the subnormal halfway edge; TOON number tokens (±spec) | 25 + 8 + 3 | 88 | 0 |
| `gen_dup2.py` 1711 (3000), 1712, 1713, 1714 (4000 each) (t1,8) | repeated keys at every depth, dotted/quoted keys, tabular rows, list items, later indentation errors; strict, lenient, expand (about 28% end in `Duplicate sibling key`) | 15000 | 45000 | 0 |
| `gen_merge.py` 1740 (3000), 1741 (6000) (t1,8) | one key repeated 2 to 3 times with object values that conflict at several depths (the order of failures inside ONE merge) | 9000 | 27000 | 0 |
| `diff-fuzz.py` 17017 `numbers`/`expand`/`mutate`/`docs` (`--switch TOON_SPEC=1`, t1) | repository lenses | 14 / 3000 / 3000 / 3000 | about 27000 | 0 |
| `diff-fuzz.py` 17018 `collide`, `argv` (t8); 17019 `scale` (20, t1) | repository lenses | 3000 / 3000 / 20 | about 12040 | 0 |
| conform c-1t (native) and js | the corpus | 1076 + 1076 | — | PASS 1076/1076 on both |
| JS lane (`jsport.sh`): `gen_words.py` 1750 (±spec), `gen_ties.py` 1751, `gen_merge.py` 1752 | the same lenses on `bin/toon.js` (the thread flag does not apply there, so "t1,8" is two identical runs) | 80 docs / 20 docs / 600 | 240 / 100 / 1800 | 0 |

Total compared executions of the unmutated port against the original: about 248000 (not counting the corpus runs). Mutant-vs-original runs (M2, M3, M4 observability: 40200 + 9000 + 9000) are used only to classify the mutants.

## What this round did NOT cover

- the interpreter lane (forbidden) and `scripts/lanes.sh` / `port-doctor.sh`. Native and JS only
- proofs for M1, M2, M4, M5, M6 and M7 (the killed or equivalent mutants): only M3 and the base were checked, one at a time, each capped at 5 GB
- descriptors, files, `-o`, `stdio-probe.py`, `hand-mutants.py`, performance
- the EXP-007 decode half beyond the number probes and the JS runs
- documents: only the laws' comments around the dispatch sweep and README's twin sentence (under 15% of the effort)

## Artifacts

Everything is under `/data/tmp/review_R17/`: `bin/` (the builds), and in `r17/`: `cmp.py`, `state.py`, `gen_words.py`, `gen_ties.py`, `gen_pow.py`, `probe.py`, `raw_boundary17.py`, `gen_dup2.py`, `gen_merge.py`, `m6scan.py`, `mutants.py`, `mut_build.sh`, `proof_capped.sh`, `jsport.sh`, the logs (`words_bg.log`, `rawb.log`, `df_17017.log`, `mut_corpus*.log`, `base_proof.log*`), and `mut/M1..M7/` (each a copy of the clone with one edit, `diff.txt`, `build.log`, `conform.json`, and for M3 `proof.log`).
