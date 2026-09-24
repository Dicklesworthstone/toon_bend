# COUNTED-PROFILE — where the port's instructions go, on the frozen binary

**Class: `counted`.** Every number here is an instruction count, not a time. Counted evidence says
whether code does less *work*; it carries no cache miss and no memory latency, so it is not a speed
claim and it does not satisfy any gate written in wall-clock terms. Nothing here is `measured`.

## Why this file exists

To choose the next lever. Before this profile the campaign's stated next target was a
Ryu/Grisu-class rewrite of shortest-digit generation, on the strength of a per-number cost
measured before several levers landed. **That target is wrong**, and the reason is in the table
below: on the most number-dense input in the corpus the port's entire numeric substrate is 19.9% of
instructions, while reference counting and teardown are 40.5% — and on string input the numeric
substrate is 0.1%. A numeric lever has a ceiling of about a fifth of one scenario. The costs that
are uniform across every scenario are elsewhere.

Consumer: whoever picks the next experiment card. Gate: no lever is spent on the number path on the
strength of the superseded attribution. Retirement: when the binary below stops being the reference,
or when a lever changes the ranking.

## Provenance

| field | value |
|---|---|
| port binary | `sha256 825e44de69c3a4e6c0d442ea`. **The BINARY is identical across `9c9039e`, `55ec958` and `c5f3b46`; the TREE is not, and this row said otherwise until it was checked.** `git diff 9c9039e 55ec958 -- port/` is empty. `git diff 55ec958 c5f3b46 -- port/` is 3 files and 93 insertions: `LAWS.bend` and `PROOF.bend`, which `port/main.bend`'s import graph never reaches (it imports `Base`, `./cli.bend`, `./text.bend`), and three COMMENT lines in `json.bend` (round 20's R20-4 wording). None of it reaches codegen, which is why one hash covers all three — but "the tree is byte-identical" was the wrong sentence for it |
| oracle | `oracle/toon`, the pinned `toon 0.2.4` from `toon_rust` `694d73b` (`sha256 821287ea…` per `docs/PIN.toml`) |
| tool | `valgrind --tool=cachegrind --cache-sim=no --branch-sim=no`, the `I refs` line; `cg_annotate` for per-symbol attribution |
| static ownership | `keep-audit.sh` of the bend2-mega-skill over `port/main.bend` |
| threads | **`--threads 1`, passed explicitly to the port** (a runtime flag, so before `--`). See "The thread count is part of the measurement" below: this profile was first taken WITHOUT it and every number was wrong |
| host sensitivity | none for the counts themselves. This profile was taken while the host was too loaded for any wall capture |
| determinism, measured here | `--encode --threads 1`: **bit-identical** over three runs (839,968,998 ×3). `--decode --threads 1`: 1,472,343,298 / 1,472,342,938 / 1,472,342,938, a spread of ~2.4e-7. Without `--threads 1`: 867,758,374 / 867,707,500 / 867,708,462, ~6e-5 |
| inputs | `perf/e2e/corpus/` (gitignored). Obtained by `python3 perf/e2e/bench.py fetch`, which downloads 28 real documents plus 4 derived slices, each pinned by commit and sha256, and **fails fatally on a hash mismatch** — so a third party reproduces the exact bytes profiled here without the corpus being in the repository. `perf/gen-bench-inputs.py` is a different thing: it generates the deterministic inputs under `perf/inputs/` that the experiment cards name |
| raw evidence | `perf/evidence/COUNTED-PROFILE.825e44de.counts.jsonl`, `…​.<scenario>.annot.txt`, `…​.keep-audit.txt` |
| captured | 2026-09-24, Claude session 9e91730b |

**Correctness held in every cell.** The port's stdout sha256 equals the oracle's in all 7 scenarios,
14 runs. A counted comparison whose arms disagree on output is measuring two different programs.

## The thread count is part of the measurement (a correction)

**The first version of this file was taken without `--threads 1` and every number in it was wrong.**
The port takes runtime flags before `--`, and without one it uses the default thread count. Since
EXP-007 the encoder's number pre-pass is a **parallel let**, so above one thread the runtime splits
it across a worker pool. Two consequences, both measured:

- **It is not reproducible.** Three identical invocations of `numbers.json --encode` gave
  867,758,374 / 867,707,500 / 867,708,462 — a spread of ~6e-5. With `--threads 1` the same command
  gives 839,968,998 three times, bit for bit.
- **It is inflated, unevenly.** The same encode counts 3.3% more at the default; `citm --decode`
  counts **10.9% more**. `WL_FID_EXIT`, which appeared at 25.3% of the expansion delta, is the
  parallel worklist machinery and **disappears entirely** at one thread.

**The avoidable part: the project already had a correct harness and I wrote my own.**
`perf/e2e/counted.py:22` builds the port's argv as `[PORT, '--threads', '1', '--', …]`. I wrote a
separate shell script for this profile because I wanted a different set of scenarios, and dropped the
flag that script already had. The rule that follows is not "remember `--threads 1`" but **diff a new
measurement invocation against the existing one before trusting it** — the existing one encodes
decisions someone already got wrong once.

Every earlier counted entry in `perf/NEGATIVE-EVIDENCE.md` was taken at `--threads 1`, so the first
version of this file was also not comparable with them. The corrected numbers below cross-validate
against one of those entries exactly: NE-027 measured path expansion's cost as **605,259,269**
instructions, and this profile now measures **605,239,282** — a difference of 3e-5, on a different
binary six weeks apart. The first version made that delta look like 864,715,290, and led me to write
that expansion's cost had "grown 43%". It had not; the thread count had changed.

## The scenarios

All at `--threads 1`. `trio` is `term_drop` + `rfc_wrap` + `span_fade`; `numeric` is every
`WL_FID_BIGNAT_*` and `WL_FID_F64_*` def; `runtime` adds the `spin_N` loops and the allocator to the
trio. Symbols are grouped by base def (see the note under the attribution table).

| scenario | input | port Ir | oracle Ir | ratio | p/byte | trio | numeric | runtime |
|---|---|---|---|---|---|---|---|---|
| `startup_encode` | 7 B | 532,601 | 504,653 | **1.06×** | — | — | — | — |
| `encode_numbers` | `numbers.json` 150 KB | 839,987,992 | 46,751,971 | **17.97×** | 5,595 | 40.5% | **19.9%** | 69.8% |
| `encode_numeric_big` | `canada.json` 2.25 MB | 11,031,494,760 | 826,606,260 | **13.35×** | 4,901 | 38.9% | 18.8% | 69.6% |
| `encode_strings` | `twitter.json` 632 KB | 671,502,656 | 100,701,316 | **6.67×** | 1,063 | 36.8% | **0.1%** | 61.0% |
| `decode_expand` | `citm_catalog.fold.toon` 666 KB, `--expand-paths safe` | 2,077,613,203 | 404,972,974 | **5.13×** | 3,120 | 49.1% | 1.6% | 74.3% |
| `decode_fold_noexpand` | the same file, `--expand-paths off` | 1,472,373,921 | 379,401,578 | **3.88×** | 2,211 | 46.9% | 2.5% | 77.1% |
| `decode_plain` | `citm_catalog.toon` 666 KB | 1,472,365,716 | 379,389,023 | **3.88×** | 2,211 | 46.9% | 2.5% | 77.1% |

**Fixed cost is not the story.** At 1.06× on a 7-byte input the two programs start up at almost the
same price; the entire gap is work done per byte.

## Where the instructions go

Shares of each scenario's total. `term_drop`, `rfc_wrap` and `span_fade` are BendRT primitives, and
what they do is quoted below from the runtime source (`bend2/comp.ts` at the pinned `15ae0c8`),
not inferred from their names:

- `rfc_wrap` (comp.ts:3814) **allocates a heap cell to hold a reference count** and re-tags the term.
  `rfc_seal` calls it for any `TAG_CTR` term that is not already refcounted — the price of making a
  constructor shareable.
- `span_fade` (comp.ts:3972) is reached from `ctr_take` **only when destructuring an already-shared
  constructor**: it bumps each of the n fields' counts, then drops the parent.
- `term_drop` (comp.ts:3880) is the recursive teardown.
- `WL_FID_EXIT` is runtime-generated too (comp.ts:2757, 3305, 4356), the worklist's exit frame — not
  a port def.

| scenario | refcount + teardown | port's numeric code (`BIGNAT`+`F64`) | all runtime + `spin_N` |
|---|---|---|---|
| `decode_expand` | **49.1%** | 1.6% | 74.3% |
| `decode_plain` | **46.9%** | 2.5% | 77.1% |
| `decode_fold_noexpand` | **46.9%** | 2.5% | 77.1% |
| `encode_numbers` | **40.5%** | 19.9% | 69.8% |
| `encode_numeric_big` | **38.9%** | 18.8% | 69.6% |
| `encode_strings` | **36.8%** | 0.1% | 61.0% |

`WL_FID_EXIT` had a column of its own in the first version of this table, at 2.4-14.0%. It is the
parallel worklist machinery and is absent at `--threads 1`.

**This is a confirmation, not a discovery, and the prior work owns it.** NE-006 already recorded
`span_fade` 34.6% self and `term_drop` 37.0% self and drew the conclusion that the port's time is
BendRT memory management on one shared heap. NE-027 already recorded 53.6% allocate-and-drop traffic
on the expansion path. What this file adds is the same quantity across every scenario on the current
binary, beside the numeric substrate, so the two can be compared as targets.

## The static counterpart: the port seals and never borrows

`keep-audit.sh` over the whole program, per segment:

Over all **460** segments — both the `FID_*` defs and the `spin_N` native loops a tail-recursive def
compiles to. The first version of this table counted `FID_*` only and under-reported every row
(seal 1,690, peek 1, 163 sealing segments); `spin_N` segments are as much a part of the program, and
one of them holds half the program's borrows:

| quantity | total | segments with any |
|---|---|---|
| `seal` (make shareable → `rfc_wrap`) | **2,548** | 309 |
| `take` (destructure) | 345 | — |
| `keep` | 344 | — |
| `free` | 40 | — |
| `peek` (borrow) | **2** | **2** |

**308 of the 309 sealing segments have `peek` == 0.** The whole program borrows in exactly two
places: `spin_486`, which borrows once and seals four times, and `FID_DECODE_HOT_LOOK`, which borrows
once and seals nothing. Against 2,548 seals.

Read that `peek` figure precisely, because the same run prints a larger one. `keep-audit.sh` also
reports a whole-file tally — `peek=77 keep=381 take=365 seal=2560 free=63` — and says of it
"includes runtime definitions, NOT segment totals". The 77 counts textual matches across the entire
emitted C, the runtime's own definitions included; the **2** above is the port's own segments, which
is the number that describes the program. The segment seal total (2,548) sitting just under the
whole-file one (2,560) is the cross-check that the segment sum is nearly complete. Neither figure means the port has a borrow
worth having: per `bend guide` (Quantities) a quantity is `&0`/`&1`/`&2`, with `Type` short for
`Kind(&1)` and `Data` for `Kind(&2)`, so a signature like `List<&2, String>` says the ELEMENTS are
reusable — **it is not a borrow annotation, and there is no source-level borrow to write.** `peek`
versus `take` is a compiler inference, which is exactly what NE-012 found when no shape it tried
persuaded the compiler to lend a `List`. The top sealers, all with zero borrows:

| segment | seal | keep | take |
|---|---|---|---|
| `FID_DECODE_EAT_K738` | **432** | 34 | 0 |
| `FID_ENCODE_PRE` | 72 | 0 | 12 |
| `FID_DECODE_DECIDE` | 48 | 5 | 8 |
| `FID_DECODE_EAT_KV_PLAIN` | 48 | 2 | 0 |
| `FID_JSON_W` | 38 | 0 | 8 |
| `FID_ENCODE_EMIT` | 22 | 14 | 5 |

Earlier keep audits in the ledger report whole-program totals only (`seal 1679→1687` across two
commits); this is the per-segment ranking. `FID_DECODE_EAT_K738` at 432 seals is six times the next
segment.

**This does not license "add borrows" as a lever.** NE-012 built that probe and it failed: borrow
inference never lent a `List<&2, U32>` in any shape tried, and its do-not-retry predicate is a Bend
release that changes borrow inference for `List`, or a number path that stops carrying big naturals
as lists. NE-030 did get a borrow (of a string, in one specific shape) and it counted a win. So the
seal/peek asymmetry is a **diagnosis of where the cost is**, not a prescription; it says which
segments to look at, and the ledger says the shape of lever that pays there.

## The sharpest single result: path expansion costs 34× the oracle's

Isolated correctly — the same input file, the only difference being `--expand-paths off` vs `safe`,
with the oracle as the control on the identical pair:

| | port | oracle |
|---|---|---|
| `--expand-paths off` | 1,472,373,921 | 379,401,578 |
| `--expand-paths safe` | 2,077,613,203 | 404,972,974 |
| **cost of expansion alone** | **+605,239,282 (+41.1%)** | **+25,571,396 (+6.7%)** |

**The port pays 23.7× the oracle for the same expansion.** It is the largest single disparity in this
profile; the next worst ratio is `encode_numbers` at 18.0×. NE-027 measured this same quantity as
605,259,269 on an earlier binary; this profile gets 605,239,282, a difference of 3e-5.

Attribution of the port's 605,239,282-instruction delta, **grouped by base def**. The compiler hoists
a def's match arms into their own worklist entries with a `_K<n>` suffix (`WL_FID_DECODE_X_NORM_K998`
… `_K1001`), so reading the base symbol alone under-counts the def — for `x.norm` by a third. The
first published version of this table did exactly that and is corrected here:

| base def / runtime symbol | delta | share of the delta |
|---|---|---|
| `term_drop` | +196,922,426 | **32.5%** |
| **`WL_FID_DECODE_X_NORM`** (with its 4 arm entries) | **+89,295,460** | **14.8%** |
| `rfc_wrap` | +87,757,215 | 14.5% |
| `span_fade` | +44,117,536 | 7.3% |
| `spin_249` | +41,180,072 | 6.8% |
| `WL_FID_DECODE_XM_SET_GO` (with its arm entries) | +36,678,879 | 6.1% |
| `WL_FID_DECODE_FIELD_INS` | +15,140,478 | 2.5% |
| `heap_alloc_miss` | +8,973,932 | 1.5% |
| `WL_FID_DECODE_EXPAND` | +7,282,073 | 1.2% |
| `io_cstr` | ~0 | 0.0% |
| `WL_FID_DECODE_SCAN_REV` | 0 | 0.0% |

Rolled up: **runtime primitives and `spin_N` loops are 67.7%** of the delta, named port defs 25.1%,
of which `x.norm` is 14.8% and every `X_*` def together 21.7%. The refcount-and-teardown trio alone
is **54.3%** of the delta.

Two of those rows are controls that make the rest trustworthy: `io_cstr` moves by 702 instructions
and `WL_FID_DECODE_SCAN_REV` by zero, so the delta is neither output writing nor re-scanning — it is
purely the extra work after decoding.

## What this says about the next lever — and the one it refuted

Expansion is three phases after decoding: `expand` builds an `XV` (a keyed map per object, plus the
objects that dotted keys create), `x.norm` finishes every object still under construction inside it,
and `x.entries` reads the finished map back in insertion order. Together they cost 53% on top of a
plain decode, and 73% of that is runtime primitives.

**A lever aimed at this was carded as EXP-033 and WITHDRAWN before any code was written**, on two
findings from reading the source — see `perf/NEGATIVE-EVIDENCE.md` NE-037. Both are worth stating
here because the shape of the mistake is reusable:

1. The card proposed fusing `x.json` into `x.norm`, on the belief that `x.json` walks the normalised
   tree and discards it. **It does not.** `x.json` is a two-arm match on ONE constructor (`XLeaf{v}`
   → `v`, anything else → `JNull{}`); it is too small to appear anywhere in the profile. Fusing it
   removes one dispatch, not a traversal.
2. The stronger variant — drop `x.norm(map)` entirely, on the belief that every value in a finished
   object's map is already an `XLeaf` — is **unsound**. `xo.set` stores `XObj` values, and `lk.of`
   re-opens an `XLeaf{JObj{…}}` into an `XObj` for merging, so a map legitimately holds objects still
   under construction. Those are exactly what path expansion creates, and they cannot be finished
   earlier: an object under construction may still receive another dotted key. `x.norm`'s descent is
   load-bearing.

NE-027 remains the decisive precedent on this path, and it now cuts three ways. It made an
*operation* inside this pass cheaper (the pass-through rebuild `case XLeaf{v}: XLeaf{v}`),
precommitted 5% and counted **0.11%, missed by a factor of 45**. Its rule — *eliminate a pass over
the data, not an operation within one* — is why EXP-033 was aimed at a pass. The refutation adds the
converse: **check that the pass is removable before carding it.** Each of expansion's three phases is
load-bearing, so on this path there is no pass to remove, and the rule's own precedent says an
operation lever will not pay either.

What remains attributable is the runtime traffic over a `+`-shared `XV`, which is `toon_bend-0uw`'s
territory and is already governed by NE-012's do-not-retry predicate (borrow inference never lent a
`List`, and the retry condition is a Bend release that changes it). **So this profile names no next
lever for path expansion**, and that is the honest reading of it. Its durable contribution is the
ranking: the numeric substrate is not the target, and the uniform cost is sharing.

## What this profile does not establish

- **No time claim.** Instruction counts and cycles diverge exactly where this profile points: a lever
  that trades pointer chasing for arithmetic can cut instructions and not cut time. Every conclusion
  here is about work done.
- **Small deltas are not readable at this resolution.** Two builds differing only in a def's
  call-site count have counted ±1.0–1.8% apart from clang's inlining flipping. Every figure quoted
  above is far larger than that, but a future sub-2% comparison needs a per-function check.
- **One input per scenario.** The five documents are the corpus's extremes by design (pure numbers,
  pure strings, deep objects), not a distribution.
- **`decode_plain` and `decode_fold_noexpand` agreeing to 0.02%** (1,632,276,292 vs 1,632,681,447 on
  different files of nearly equal size) is a coincidence of input size, not a result.
