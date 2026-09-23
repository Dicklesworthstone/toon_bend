# Round 16 — non-author hostile review of toon_bend

| field | value |
|---|---|
| reviewed commit | `b8ce8ab33ef7633109e418b0d4322adfdaaf1603` (clone `/data/tmp/review_R16/clone`, detached) |
| scope addition | `4902734f8dc0881bb1b2283119250e14fffe4fea` (EXP-007 decode half, `27163b7`), clone `/data/tmp/review_R16/clone2`; findings on it are labelled `4902734` |
| original | `oracle/toon` → `/data/projects/toon_bend/oracle/toon`, sha256 `821287eaf1a6d320ee1ef7604e74e3cefaa42b69445c96abb9dd310782d04030` = `docs/PIN.toml`; `toon 0.2.4` |
| Bend | `bun /tmp/bend/bend2/main.ts`, `/tmp/bend` at `15ae0c86f3193b8f645b4bedbc438655b648d0da`, `BEND_NO_TELEMETRY=1` |
| tools | bun 1.4.2, Ubuntu clang 21.1.8, Python 3.14.4 |
| port binaries | `r16b/bin/toon` (b8ce8ab), `r16b/bin2/toon` (4902734), `r16b/pre007/toon_051ec2e` (the commit before EXP-007), mutants `r16b/mut/M*/toon_mut` |
| host | shared, 8 cores, 30 GB; load average 4.6 at the start (20:21), 12–25 during the run (another agent's 14–22 GB `PROOF.bend` and an e2e benchmark); available memory fell to 2 GB for ~25 minutes, during which nothing of mine was built. No timing in this report is evidence of speed |
| note | `/data/tmp/review_R16/` already held artifacts from an earlier session (`bin/`, `mut/`, `scripts/`, `*.log`, 13:20–13:52). They were not used and not touched; all of this round's work is under `/data/tmp/review_R16/r16b/` and `round-16.md` |

## Behavior findings

| id | sev | class | what | commit(s) | spec |
|---|---|---|---|---|---|
| R16-1 | HIGH | BEHAVIOR | a JSON number whose value overflows binary64 but whose exponent is negative (`2` + 309 zeros + `e-1`, or any `…e-0`) is encoded as `0`, exit 0; the original says `number out of range`, exit 1. Also with `TOON_SPEC=1`, at every thread count, and it also changes which error wins | b8ce8ab, 4902734; NOT 051ec2e | S4.101, S9.200–S9.201 (A1: only a value beyond 1.7976931348623158e308 is `number out of range`), S2.51 |
| R16-2 | MEDIUM | BEHAVIOR (mutant) | mutant M1 of `dup.keep` (keep the LAST repeated-key failure instead of the first) survives the corpus (1071/1071 c-1t) AND the 416-law proof (`All terms check.`), and it changes bytes | b8ce8ab | S3.26, S9.151 |
| R16-3 | MEDIUM | BEHAVIOR (mutant) | mutant M5 of `num.safe` (exponent bound 250 → 300) survives the corpus (1071/1071) AND the proof, and it changes bytes (`[1000000000000e299]` → `[1]: 0`). No case and no law pins the raw/defer bound; this is why R16-1 got through | b8ce8ab | S2.51, S4.101 |

### R16-1 reproduction (exact commands, output verbatim)

```
$ cd /data/tmp/review_R16/clone && B=/data/tmp/review_R16/r16b/bin/toon; N=$(python3 -c "print('1'+'0'*400+'e-1')")
$ echo "[$N]" | ./oracle/toon --encode; echo "oracle exit $?"
Failed to parse JSON: number out of range at line 1 column 405
oracle exit 1
$ echo "[$N]" | $B --threads 1 -- --encode; echo "port t1 exit $?"
[1]: 0
port t1 exit 0
$ echo "[$N]" | TOON_SPEC=1 $B --threads 1 -- --encode; echo "port spec t1 exit $?"
[1]: 0
port spec t1 exit 0
(the same two port lines at --threads 8)
```

Variants (`Z` = 309 zeros), original vs port b8ce8ab `--threads 1 -- --encode`:

| input | original | port |
|---|---|---|
| `{"a":2Ze-1}` | `Failed to parse JSON: number out of range at line 1 column 318`, exit 1 | `a: 0`, exit 0 |
| `[2Z.5e-1,"x"]` | `… number out of range at line 1 column 316`, exit 1 | `[2]: 0,x`, exit 0 |
| `[-2Ze-1]` | `… column 315`, exit 1 | `[1]: 0`, exit 0 |
| `[2Ze-1 x]` | `Failed to parse JSON: number out of range at line 1 column 314`, exit 1 | `Failed to parse JSON: expected `,` or `]` at line 1 column 316`, exit 1 (the wrong error wins) |
| `[1` + 312 zeros + `e-0]` | `… column 314`, exit 1 | `[1]: 0`, exit 0 |

The 4902734 build (`r16b/bin2/toon`) gives `[1]: 0` exit 0 on `[2Ze-1]` at `--threads 1` and `64`, with and without `TOON_SPEC=1`. The build of `051ec2e` (the commit before EXP-007's `0131342`) is correct: `Failed to parse JSON: number out of range at line 1 column 314`, `051ec2e exit 1`. So EXP-007 introduced it.

Cause: `port/json.bend` `num.safe` (`Bool.or(eneg, …)`) treats every negative exponent as "cannot overflow", but the integer digits alone can exceed 1.8e308. The deferred token then reaches `raw.unwrap`, whose `None` arm ("unreachable") returns `F.zero()`. The deferral happens in the reader, before the kill-switch is consulted, so `TOON_SPEC=1` does not turn it off.

Boundary sweep (`r16b/raw_boundary.py`: 4 leading digits × 11 integer lengths (1–400) × 3 fractions × 13 exponents × 2 signs, each alone, inside a 141-item array (the parallel split), in an object, and with `--stats`): 13416 inputs, threads 1/2/8/64: `{"executions": 67080, "diffs": 2880}`; with `TOON_SPEC=1`, threads 1/8: `{"executions": 40248, "diffs": 1440}`. There were 241 distinct differing inputs. Every one is the same pattern: original exit 1, port exit 0, and every token has a negative exponent (`e-…`, `E-1`, `e-0`) and a value ≥ 2^1024. There were no differences at the positive-exponent 250/251 and 50/51-digit edges.

### R16-2 / R16-3 reproductions (mutants; the diffs are in `r16b/mut/M1`, `r16b/mut/M5`)

M1 `port/decode.bend` `dup.keep`: `match new: case Some{m}: Some{m}  case None{}: old` (was: keep `old` when it is `Some`).
```
$ printf 'x:\n  b: 1\n  b: 2\na: 1\na: 2\n' | ./oracle/toon -d
Failed to decode TOON: Duplicate sibling key "b"
$ printf 'x:\n  b: 1\n  b: 2\na: 1\na: 2\n' | r16b/mut/M1/toon_mut --threads 1 -- -d
Failed to decode TOON: Duplicate sibling key "a"
corpus: {'lane': 'c-1t', 'passed': 1071, 'failed': 0, ..., 'verdict': 'PASS'}
proof:  M1 proof exit 0 secs 649 last: All terms check.
```
M5 `port/json.bend` `num.safe`: `Nat.is_le(x, 300n)` (was `250n`).
```
$ echo '[1000000000000e299]' | ./oracle/toon --encode      -> Failed to parse JSON: number out of range at line 1 column 18 / exit 1
$ echo '[1000000000000e299]' | r16b/mut/M5/toon_mut --threads 1 -- --encode   -> [1]: 0 / exit 0
corpus: 1071/1071 PASS;  proof: M5 proof exit 0 secs 570 last: All terms check.
```

### Mutants: all results

| mutant | def | change | corpus c-1t | `PROOF.bend` | observable? |
|---|---|---|---|---|---|
| M1 | `dup.keep` | keeps the last failure | PASS 1071/1071 (survives) | `All terms check.` (survives) | yes: 8/900 hand1 and 149/4000 dup-lens executions differ from the original |
| M2 | `hot.merge` lenient arm | stores `False{}` instead of the later entry's quoted flag | PASS 1071/1071 (survives) | **KILLED** by `hot_dups_lenient_overwrite` (expected `JECons{"a", False{}, …}`, observed `JECons{"a", True{}, …}`) | yes (`"a.b": 1⏎"a.b": 2` lenient + expand → `{"a":{"b":2}}` vs `{"a.b": 2}`) |
| M3 | `hdr.a.first` | precheck looks for `]` (93) instead of `[` (91) | PASS (survives) | `All terms check.` (survives) | no difference in 1892 header probes + 2000 dup docs + 300 hand cases. It is probably EQUIVALENT (a line with `[` but no `]` fails the later `]` cut anyway), so it is NOT a finding |
| M5 | `num.safe` | exponent bound 250 → 300 | PASS (survives) | `All terms check.` (survives) | yes (above) |
| M6 | `pre` | `par.cat(b, a)` in the parallel arm | **KILLED**: FAIL 1068/1071 (`stats_ratio_5`, `large_tabular_1500`, `large_tabular_1500_pipe_folded`) | not run | yes |

## Document findings

| id | sev | class | claim | refuted by |
|---|---|---|---|---|
| R16-4 | MEDIUM | DOCUMENT | `perf/EXPERIMENTS.md` EXP-007: "The reader keeps a token RAW when it cannot overflow (`num.safe`: a negative exponent, …); every other token is converted where it always was, so every `number out of range` keeps its position and its order", and the comment above `num.safe` in `port/json.bend` ("a negative exponent (underflow is not an error)"; "num.safe excluded overflow, so … the zero of the None arm is unreachable") | R16-1: a negative-exponent token overflows, the "unreachable" arm is reached, and the error is lost or reordered |
| R16-5 | LOW | DOCUMENT | `port/encode.bend` `pre.if` comment and law `pre_gate_switch`'s comment: "with TOON_SPEC=1 … every number takes its spec twin inside put.prim, exactly as before this pass existed"; EXPERIMENTS "behind `TOON_SPEC=1`"; PORT_STATE's kill-switch row as evidence that the switch closes the lever | with `TOON_SPEC=1` the b8ce8ab and 4902734 builds print `[1]: 0` where the pre-pass build `051ec2e` prints `number out of range`. The reader's deferral is outside the switch. The law is true only of `pre.if`, not of the program |

## Clean areas: what ran and found nothing (b8ce8ab unless marked)

Harness `r16b/cmp.py`: `./oracle/toon ARGV` vs `<port> --threads T -- ARGV`, the same stdin, comparing stdout, stderr and exit byte for byte; timeouts 60 s (none happened). Executions = original runs + port runs.

| lens (script, seed) | target | inputs | executions | diffs |
|---|---|---|---|---|
| `gen_dup.py` 1601; 1602, 1603, 1604 (threads 1,8) | repeated keys at every depth, quoted/unquoted, list items, tabular repeated fields, dotted keys, strict/lenient/expand | 1500 + 3×5000 | 48000 | 0 |
| `hand1.py` (threads 1,8) | dup vs later errors, escaped/Unicode/empty keys, `{a,a}` rows, merge chains, key order, 6 flag sets | 300 | 900 | 0 |
| `scale_dup.py` n=20000 | growing merges (depth 1 and 3), list items, alternating kinds, 97 keys, dotted+literal | 21 | 42 | 0 (no quadratic behaviour; timings noisy) |
| `hand2.py` 1620 | header precheck: `[` in keys/values/quotes, after the colon, unclosed, tabs, 13 Unicode White_Space in random positions, 5 contexts | 4392 | 8784 | 0 |
| `gen_empty.py` 1630 (threads 1,8) | JSON writer: empties at every depth, `--indent` 0/1/2/4/8/16, expand/lenient, plus encode | 10500 | 31500 | 0 |
| `gen_num.py` 1640 (t1), 1641 (t1,8,64), 1642 (t1,8, `TOON_SPEC=1`) | subnormals, powers of 2 and 10, 17 digits, exact halfway ± 10^-900, the 1e-7/1e21 edges, 2^53+k; both directions, arrays/tabular/objects | 60+150+150 batches (~300 numbers each) | 5850 | 0 |
| `digits.py` 1660 (t1,8; ±`TOON_SPEC=1`) | shortest digits, 100000 random bit patterns | 200 | 1200 | 0 |
| `raw_boundary.py` | the raw/defer boundary | 13416 | 107328 | **4320 = R16-1** |
| `gen_fold.py` 1650 (t1,8; `TOON_SPEC=1` t1) | `--key-folding safe`, `--flatten-depth` 0/1/2/3/5/100, delimiters, indents | 7179 | 35895 | 0 |
| `depth.py` (t1,8) | nesting limit 122–130 (objects, tables, lists, list-item objects, expansion segments, JSON input), S9.150/152/154 | 371 | 1113 | 0 |
| `diff-fuzz.py expand` 16016 / `collide` 16016 (t1) | repository lenses | 4000 / 4000 | 16000 | 0 |
| `diff-fuzz.py mutate`/`docs`/`argv` 16017 (t1) | repository lenses | 6000 each | 36000 | 0 |
| `diff-fuzz.py numbers` 16017 `--switch TOON_SPEC=1` (t1) | 15 batches × 400 numbers each direction | 30 | 90 | 0 |
| `diff-fuzz.py mutate` 16018 (t8), `docs` 16018 (t64) | repository lenses | 3000 / 3000 | 12000 | 0 |
| `diff-fuzz.py scale` 16019 (t1) | one large dimension | 20 | 40 | 0 |
| **4902734** `digits.py` 1670 (t1,8; ±spec) | decode half of EXP-007 | 120 | 720 | 0 |
| **4902734** `gen_num.py` 1671 (t1,2,8,64), 1672 (t1,64 spec) | numbers both directions | 800 | 3200 | 0 |
| **4902734** `dec_num.py` 1681 (t1,2,8,64; ±spec) | number-heavy TOON decode: 63/64/65/128/1000-item arrays, tables of 64/65/130 rows, nesting, `--indent` 0/4, expand, lenient, `--stats` | 732 | 7320 | 0 |
| **4902734** R16-1 check | the overflow token | 1 | 5 | R16-1 present |

Total compared executions against the original: about 316000 (plus 34736 mutant-vs-original executions used only to show that the mutants are observable). A first `dec_num.py` run (seed 1680, uncapped sizes, up to 10^6 numbers per document) was stopped by me after 83 minutes without a result: INCONCLUSIVE, and not counted.

## What this round did NOT cover

- the interpreter lane (forbidden here) and the JavaScript lane (no JS build this round). All comparisons are on the native C binary at the thread counts named above
- a full `scripts/lanes.sh` / `port-doctor.sh` run, `hand-mutants.py`, `stdio-probe.py`, `claims-audit.py`; the unmutated `PROOF.bend` was not re-run by itself (the three surviving mutant proofs printed `All terms check.`, which implies the base does too, but the base itself was not run)
- no proof run of the 4902734 tree and no mutants of its decode half (`num.text`, `dec.done`)
- R16-1's reach into `--decode` is nil: TOON tokens that overflow are strings in both programs (checked on 3 inputs)
- descriptors, files, `-o`, argv beyond `diff-fuzz argv`, `--stats` beyond the boundary sweep
- documents: only the claims around R16-1 were checked (less than 15% of the effort)
- performance: nothing measured; the host was loaded (load 12–25)

## Artifacts

All under `/data/tmp/review_R16/r16b/`: `cmp.py`, `gen_dup.py`, `hand1.py`, `hand2.py`, `gen_empty.py`, `gen_num.py`, `digits.py`, `raw_boundary.py`, `gen_fold.py`, `depth.py`, `scale_dup.py`, `dec_num.py`, `bg_fuzz.sh` + `df_*.log`, `mut_corpus.sh`/`mut_corpus.log`, `mut_proof.sh`/`mut_proof.log`, `mut/M{1,2,3,5,6}/` (each a full copy of the clone with one edit; `proof.log`, `conform.log`), `pre007/` (`git archive 051ec2e` + its build).
