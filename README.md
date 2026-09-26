# toon_bend - TOON in Bend 2

<div align="center">

[![Bend 2](https://img.shields.io/badge/bend-2.0.16-7c3aed.svg)](https://github.com/bendlang/bend)
[![Original](https://img.shields.io/badge/port%20of-toon__rust%200.2.4-orange.svg)](https://github.com/Dicklesworthstone/toon_rust)
[![TOON Spec](https://img.shields.io/badge/spec-v3.0-fef3c0)](https://github.com/toon-format/spec)
[![License: MIT](https://img.shields.io/badge/License-MIT%2BOpenAI%2FAnthropic%20Rider-blue.svg)](./LICENSE)

</div>

<div align="center">

**[The original: toon_rust](https://github.com/Dicklesworthstone/toon_rust)** | **[The TOON project](https://github.com/toon-format/toon)** | **[TOON Specification](https://github.com/toon-format/spec)**

</div>

A byte-for-byte port of the `toon` command line tool (`toon_rust` 0.2.4) to [Bend 2](https://github.com/bendlang/bend): the same stdout, the same stderr and the same exit code as the pinned original on every captured case, on every Bend executor lane, with the properties that hold for every input stated as laws and checked by Bend's proof checker.

> **Credit:** `toon_rust` is a Rust port of the original [TOON TypeScript implementation](https://github.com/toon-format/toon) by the [toon-format](https://github.com/toon-format) team; the format specification is maintained at [toon-format/spec](https://github.com/toon-format/spec). This repository ports the Rust tool's observable behavior, oddities included, and changes nothing about the format.

<div align="center">
<h3>Quick Build</h3>

```bash
git clone https://github.com/Dicklesworthstone/toon_bend && cd toon_bend
git clone https://github.com/bendlang/bend /tmp/bend && git -C /tmp/bend checkout --detach 15ae0c8
export BEND_NO_TELEMETRY=1
bun /tmp/bend/bend2/main.ts port/main.bend -o toon      # bun >= 1.4, clang >= 14
echo '{"users":[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]}' | ./toon -- --encode
# or, with the original's exact command line (the launcher passes `--` for you and repairs closed standard descriptors):
bun /tmp/bend/bend2/main.ts port/main.bend -o port/toon && bin/toon --encode < cases/inputs/hand/happy_readme_users.json
```

<p><em>Run and gated on Linux x86_64 only; macOS is untested (the launcher's repair of wrong-mode descriptors reads /proc). No package, no installer: one Bend build, about 25 seconds.</em></p>
</div>

---

## TL;DR

### The Problem
A port is only as good as the evidence that it behaves like the original. "The tests pass" says little when the tests were typed by the porter, and "it is the same algorithm" says nothing about the forty places where the original does something its own README does not mention.

### The Solution
`toon_bend` is built with the *porting-to-bend2* method: the original is pinned and RUN as an oracle (never read while implementing), its behavior is written down as a numbered specification (716 clauses), the Bend code is written from that specification, and it is judged against 1124 captured cases on four executor lanes. Two equivalences are kept apart:

1. **original == spec** is *golden-tested*: `goldens/` holds what the pinned binary printed; a case passes when stdout, stderr and the exit code match byte for byte on the interpreter, the native binary at 1 and 8 threads, and the JavaScript build.
2. **spec == fast** rests on laws in `port/LAWS.bend`, checked by `port/PROOF.bend` (`All terms check.`), and this README says exactly how far they reach: the fast twins (EXP-001, 002, 003, 006, 008 and 012, plus EXP-007's pre-pass) are bound to their specification twins by quantified gate laws (under `TOON_SPEC=1` every twin selector is off, for every input; each gate's condition and arms are pinned), by closed instance laws on boundary values, and by running both twins against the original on generated numbers. No universally quantified `fast == spec` law exists for any of them; their entries in `perf/NEGATIVE-EVIDENCE.md` stay PROVISIONAL for that reason.

### Why Use `toon_bend`?

| Feature | Why it matters |
| --- | --- |
| Byte-for-byte parity, golden-tested | stdout, stderr and the exit code match the pinned original byte for byte on 1124 captured cases; see **Status** below for the lanes and the commit each line was produced on |
| Bugs are fixed, never reproduced | every bug the port's inventory found in the original (decoded integers printed as `1.0`, JSON numbers not correctly rounded, two escape styles, silently dropped input, lost write errors, …) was fixed in `toon_rust` first and then ported; the port is pinned to the fixed commit `694d73b` (`docs/DISCREPANCIES.md`, "Former bug-compatibility candidates") |
| Exact numbers without an `f64` | Bend has no binary64: the port carries a software binary64 over big naturals and reproduces the original's number algorithms (correctly rounded reading of JSON and TOON number text, shortest digits for TOON with ties to even, JavaScript's number text for JSON), bit for bit on every number of the corpus and of the differential runs |
| Proved properties | 678 laws checked by Bend (`All terms check.`, unsafe 0 = 0 `@unsafe` + 0 template instances, bend 2.0.16): 41 hold for every input (the first failure ends a pass, in strict mode a line after the complete root and a repeated key that cannot merge are reported, lenient mode never reports a body check, `--encode` beats every extension, no expansion step runs at depth 256, equal estimates print `No token difference`, the kill-switch closes every fast path, with key folding off a fold attempt never folds, under the kill-switch no fold context is lean, and the parallel number pre-pass changes when a number is printed, never what is printed, and is closed by the kill-switch, the pass renders a number with the printer of the side it runs on, and --decode is the side that asks for the JSON printer, and the shortest-digit loop over words runs exactly when the kill-switch is open and the state fits, and the argv scanner's gate for a word that begins with '-' takes the plain arm or the short-option arm as its verdict says, and the JSON reader's string arm with its fast path closed is the reader's step); 637 are closed instances computed by the checker itself, 295 of them captured goldens restated as laws. 124 hand-written mutants of the code the laws speak about are all killed (`scripts/hand-mutants.py`): M01 to M54 (53 mutants) in ONE run on 2026-09-24, `{"laws_in_proof": 367, "laws_sha256_12": "e77be1b1ae88", "reduced": true, "mutants": 53, "killed": 53, "survived": [], "not_evidence": [], "verdict": "STRONG"}`, and the five round 22 added (M55 to M59) the same day, `{"laws_in_proof": 371, "laws_sha256_12": "f923e244b5a6", "reduced": true, "mutants": 5, "killed": 5, "survived": [], "not_evidence": [], "verdict": "STRONG"}`; in that run M58 mutated the wrong arm of `row.lock` (a row LONGER than the header), so the corrected M58 (a row shorter than the header) was run alone (`hand-mutants.py M58`), `{"laws_in_proof": 371, "laws_sha256_12": "f923e244b5a6", "reduced": true, "mutants": 1, "killed": 1, "survived": [], "not_evidence": [], "verdict": "STRONG"}`. The fourteen round 23 added (M60 to M73, the reviewer's own mutant texts) in one run on 2026-09-25, `{"laws_in_proof": 384, "laws_sha256_12": "ae9a286a6d1c", "reduced": true, "mutants": 14, "killed": 14, "survived": [], "not_evidence": [], "verdict": "STRONG"}`, each by the law written for it (checked one by one in a reduced proof before the run). The eleven round 24 added (M74 to M84) in one run on 2026-09-25, `{"laws_in_proof": 392, "laws_sha256_12": "5efd36a77949", "reduced": true, "mutants": 11, "killed": 11, "survived": [], "not_evidence": [], "verdict": "STRONG"}`, each by a law that pins it (M83, depth-2 folding switched off, falls to the fold-budget law, which also depends on it). The eleven round 25 added (M85 to M95) in one run on 2026-09-25, `{"laws_in_proof": 403, "laws_sha256_12": "7c4fb3e1b09b", "reduced": true, "mutants": 11, "killed": 11, "survived": [], "not_evidence": [], "verdict": "STRONG"}`, each by the law written for it. The eight round 26 added (M96 to M103) in one run on 2026-09-25, `{"laws_in_proof": 412, "laws_sha256_12": "3644d616d6f2", "reduced": true, "mutants": 8, "killed": 8, "survived": [], "not_evidence": [], "verdict": "STRONG"}`, each by the law written for it. The five round 27 added (M104 to M108) in one run on 2026-09-25, `{"laws_in_proof": 417, "laws_sha256_12": "d7212620225f", "reduced": true, "mutants": 5, "killed": 5, "survived": [], "not_evidence": [], "verdict": "STRONG"}`, each by the law written for it. The eleven round 28 added (M109 to M119) in one run on 2026-09-26, `{"laws_in_proof": 427, "laws_sha256_12": "ecf9592ec30b", "reduced": true, "mutants": 11, "killed": 11, "survived": [], "not_evidence": [], "verdict": "STRONG"}`, each by the law written for it. The six round 29 added (M120 to M125) in one run on 2026-09-26, `{"laws_in_proof": 433, "laws_sha256_12": "96129311bcf7", "reduced": true, "mutants": 6, "killed": 6, "survived": [], "not_evidence": [], "verdict": "STRONG"}`, each by the law written for it. That the earlier mutants still die against the laws added after their runs rests on the inference that adding laws can only add ways for a mutant to fail. The `laws_sha256_12` digest is over the sorted names of the laws actually compiled into the proof, so the verdict carries its own provenance |
| One pure core, a thin shell | `run_pure(argv, bytes) -> (exit code, stdout, stderr)` is a value; `main.bend` is the only file with `IO` in its types |
| No unsafe code, no dependencies | `import Base` only; 0 `@unsafe`, 0 template instances (bend 2.0.16); ONE custom effect, `Stdin.open`, with a C and a JavaScript twin, because Base cannot read descriptor 0 (DISC-012) |

---

## Status

Every line names its command, its lanes and its commit. Dates: the gate run of 2026-09-22, unless a line gives its own. Bend: 2.0.16 at `15ae0c8`. Original: `toon_rust` `694d73b` (`toon 0.2.4`), re-pinned on 2026-09-22 after every bug the port's inventory had found in it was fixed there first (the owner's order; spec Amendment A1, PLAN §2); earlier that day the pin was `7c1d6e4` (the C-10 fix) and before that `f955c67`; lines below that name an earlier pin were produced against it.

- **Golden-tested, every lane:** `scripts/lanes.sh goldens/cases.tsv goldens port/main.bend --threads 8` → PASS **1124/1124** on the interpreter, the native binary at 1 and at 8 threads, and the JavaScript build, on the tree of `e33925e` (2026-09-26, local 03:13 to 04:46; the commits after it change documents only; the line is pasted in `docs/PORT_STATE.md`). `scripts/conform.sh` also passes 1124/1124 on c-1t with `TOON_SPEC=1` (2026-09-25). MANIFEST: 3372 hashes, captured from `./oracle/toon` (sha256 `821287ea…`); floor STABLE (the original against itself). Since EXP-007 (`0131342`) the encoder's number pre-pass is a parallel let: above `--threads 1` the runtime runs it on a worker pool, so `c-8t` is a genuinely parallel lane on every `--encode` case; decoding and every other path stay sequential, and no bang is placed.
- **Outside the corpus:** seeded differential fuzzing against the original (`scripts/diff-fuzz.py`: mutated corpus documents, generated documents through every option, command lines, numbers under both settings of the kill-switch, expansion, keys chosen to collide in the port's hash, inputs large in one dimension with a time verdict) and the descriptor states the harness cannot express (`scripts/stdio-probe.py`: inherited offsets, sockets, closed, read-only and full standard streams, descriptor paths, message-oriented sockets). NON-AUTHOR review rounds (round 6 onward; every report is in `docs/reviews/`, every round has a row and a paragraph in `docs/PORT_STATE.md`) compared well over a million executions with the original. Round 7 found the two behavioral HIGH findings of this port (stdin used to be re-opened by path: wrong bytes for a file at an offset, a failure for a socket; repaired by the stdin effect), round 10 one about the repository (cited commits that did not build, because `.gitignore` hid two source files); since round 9 no round has found a difference in conversion content, and their findings are about descriptor states, the launcher and these documents. Every finding is repaired or registered. No non-author round has reviewed the bug-fix re-pin of 2026-09-22 yet; the author's own checks of it: the stdio probe (27 rows: 13 SAME, 13 KNOWN, 1 FIXED, 0 NEW), and every S10 row judged against the TOON specification and the reference implementation (spec Amendment A3).
- **Proved:** `bun /tmp/bend/bend2/main.ts port/PROOF.bend` → `All terms check.`, 678 laws, unsafe 0 = 0 `@unsafe` + 0 template instances, bend 2.0.16.
- **Parity board:** `scripts/parity-board.sh docs/FEATURE_PARITY.md` → 27 in-scope rows `present`, 6 classed exclusions, verdict DEBT (an exclusion is debt, by rule).
- **Verdict:** HOLD, not SHIP (`docs/PORT_REPORT.md`). What holds it: the convergence rule needs two clean non-author review rounds in a row on a frozen tree (since 2026-09-23 counted by the porting method's recommended rule: only a new behavior finding of MEDIUM or above makes a round dirty, and a hand mutant that survives the corpus as well as the proof is such a finding, a corpus gap; `docs/PORT_STATE.md` "Owner decisions"), and no round has been clean yet (`scripts/converge.sh docs/PORT_STATE.md`). Every divergence is ACCEPTED with a scoped contract or RESOLVED (`docs/DISCREPANCIES.md`); no known bug of the original is reproduced.

---

## What is TOON?

TOON (Token-Oriented Object Notation) is a human-readable serialization of JSON data that spends fewer LLM tokens: indentation instead of braces, array lengths in headers, and a CSV-like form for arrays of uniform objects.

### TOON Format at a Glance

```yaml
# Primitives - just the value
42
hello

# Objects - indented key-value pairs
user:
  id: 1
  name: Alice

# Arrays - count in brackets; primitives inline
tags[3]: a,b,c

# Tabular arrays - header declares fields, rows are CSV-like
users[2]{id,name}:
  1,Alice
  2,Bob

# Lists - items with a dash
items[2]:
  - 1
  - k: v

# Key folding - nested single-key objects collapse (--key-folding safe)
config.database.host: localhost
```

---

## Quick Example

```bash
# Encode JSON to TOON
echo '{"users":[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]}' | ./toon -- --encode
# users[2]{id,name}:
#   1,Alice
#   2,Bob

# Decode TOON back to JSON (every decoded number is a binary64 and prints as one: 1.0)
printf 'users[2]{id,name}:\n  1,Alice\n  2,Bob\n' | ./toon -- --decode
# {
#   "users": [
#     {
#       "id": 1.0,
#       "name": "Alice"
#     },
#     {
#       "id": 2.0,
#       "name": "Bob"
#     }
#   ]
# }
# (--indent is ALSO the indent unit expected in the TOON input: `--decode --indent 0` prints compact JSON,
#  and accepts only unindented TOON; `--indent 4` expects TOON indented by fours)

# File-based with auto-detection by extension
./toon -- input.json -o output.toon
./toon -- data.toon

# Token estimates
./toon -- input.json --stats
```

The `--` right after the program name is part of the contract: a compiled Bend binary consumes `--help`, `--threads N` and `--gpu X` itself when they come before `--` (DISC-001). Everything after `--` is the original's command line, unchanged.

---

## Performance

**The answer first.** The port does several times the original's work, costs several times its memory, and none of that
is reported as a MEASURED time on the current tree:

- **Work, COUNTED on the current tree** (instructions, `valgrind --tool=cachegrind --cache-sim=no`, `--threads 1`; the
  twelve cells of the e2e corpus comparison in `perf/e2e/README.md`, each cell's stdout compared with the original's
  first): the port executes **6.15×** the pinned original's instructions (geometric mean; encode 7.63×, decode 4.96×;
  10.95× against the original built at `opt-level=3`), from 6.83× on the tree of `2c33e64`. Best cell `apache_builds`
  decode 3.26×, worst `canada` encode 13.35× (111080 doubles through a software binary64: Bend has no `f64`). Tree of
  `f6cd68e`, 2026-09-24, `perf/evidence/COUNTED.e2e-corpus.f6cd68e.json`. Instruction counts see no cache miss and no
  memory latency: this is work, not seconds.
- **Time, MEASURED**: the reference wall-clock run is the quiet-host run of the tree of `2c33e64` (2026-09-24, 204
  cells, every one byte-identical across the port and both builds of the original; the cells whose every arm passed the
  cv gate are the MEASURED ones), with its ratios against both builds and the levers' corpus-wide effect in wall time
  against the previous reference run, in `perf/e2e/README.md`, "Results — THE REFERENCE RUN". That tree carries the
  allocation levers up to EXP-027; EXP-029, 031 and 032 came after it and are COUNTED only. The counted figure above
  and this measured one are independent: different cells (12 against 204) and different currencies (instructions
  against seconds), so their closeness corroborates nothing. The per-lever ratios in the table below are for one
  document and one mode each; the corpus-wide effect is smaller because many documents give the levers less to remove.
- **Memory**: linear in the input and several times the original's per input byte, higher for number-heavy input;
  the copy-removing levers also cut peak memory (they stopped holding the document in several list forms at once).
  The figures and the ceiling they imply (a MEMORY ceiling, not a time one) are in `perf/e2e/README.md`, "Memory".

Every RATIO here is a capture by `scripts/incumbent-bench.sh`: AB/BA pairs, medians, a cv gate of 5 percent per arm (a capture above it is REFUSED and gives no ratio), identical stdout and stderr in every sample. Two columns are NOT such captures and say so: the earlier build's single timed runs in the second table, and the round 7 timings quoted below it. No row is admitted to `perf/PERF-LEDGER.md` yet; everything measured so far is provisional or a loss, and each has its entry (`perf/NEGATIVE-EVIDENCE.md` NE-001 to NE-007; NE-007 is EXP-005, a lever whose capture the cv gate refused and whose source was reverted, so it adds no row to any table here). Host: AMD EPYC-Milan, 8 cores, Linux, shared with other agents' work; 1 thread; bend 2.0.16, clang 21.1.8; 2026-09-20. The JSON lines are in `perf/evidence/`, the cards in `perf/EXPERIMENTS.md`.

**Counted, not measured: the allocation levers of 2026-09-23** (EXP-013, 018, 019, 021, 022, 024, 025, 026, 027, 029, 031; `perf/NEGATIVE-EVIDENCE.md` NE-018, NE-022 to NE-025, NE-028 to NE-032 and NE-035; the other commits between the two trees change laws and ledgers only). These are INSTRUCTION COUNTS (`valgrind --tool=cachegrind --cache-sim=no`, `--threads 1`), not times: deterministic on this shared host (two runs of one binary differ by 80 instructions in 7.3 billion, where wall-clock cv was 10-50%), blind to cache misses and allocation latency, and therefore never called MEASURED and never used to meet a gate written in time. The session-start binary (`722991e`) against the tree of `f6cd68e` (EXP-031; EXP-032 was reverted), stdout identical in every cell, inputs from the e2e corpus (`perf/e2e/`); one file per cell in `perf/evidence/` (`COUNTED.<input>.<mode>.f6cd68e.json`, both counts and both stdout hashes; the files named `.6d48fcf.` hold the reverted EXP-032 tree's counts (NE-036), `.ac6ff70.` the comparison before EXP-031, `.cbdfba6.` the one before EXP-029, those without a commit in their name the one before EXP-025 to 027):

| input | mode | instructions before | after | ratio |
| --- | --- | --- | --- | --- |
| `gsoc_2018` (3.2 MB, long texts) | `--encode` | 7,325,873,588 | 2,936,739,179 | 2.495× fewer |
| `gsoc_2018` | `--decode` | 7,356,818,902 | 3,247,400,373 | 2.265× fewer |
| `flights_200k` (9.4 MB, numbers in rows) | `--encode` | 39,442,102,850 | 28,748,656,810 | 1.372× fewer |
| `flights_200k` | `--decode` | 32,743,595,074 | 27,152,822,084 | 1.206× fewer |
| `canada` (2.1 MB, coordinates) | `--encode` | 12,726,037,094 | 11,031,495,105 | 1.154× fewer |
| `canada` | `--decode` | 16,671,049,526 | 12,762,613,655 | 1.306× fewer |

What they remove: in the emitted C every list cell built on top of another passes through `rfc_wrap` (a refcount cell) and is later dropped, and the port built about 10.7 cells per input byte; the levers stop reversing a whole value to read its last character (EXP-013), stop building text that is never read (EXP-018), stop copying the input (EXP-019), build the output once instead of three times (EXP-021), stop reversing trimmed values twice (EXP-022) walk a quoted literal once instead of twice (EXP-024), scan the decoded text in the order the UTF-8 decoder already holds it (EXP-025), stop keeping every string value for a numeric-like test that now only reads it (EXP-026), take a plain byte inside a JSON string without the reader's whole per-byte dispatch (EXP-027), detect a repeated key in a small JSON object by walking its chain instead of the key table (EXP-029), and stop keeping the input bytes alive through a decoding (EXP-031). EXP-031 failed one of its own guard cells, gsoc encode by 0.80%, on code it did not change: clang inlines the UTF-8 loop differently in the two builds (`perf/NEGATIVE-EVIDENCE.md`, the header's COUNTED-resolution paragraph). EXP-032, which read the input once when encoding, was reverted: its reader ran on invalid UTF-8 and the JavaScript and interpreter lanes refused a Char it built (NE-036). A CPU capture on a quiet host is what would make any of them a MEASURED ratio.

**The port against earlier builds of itself** (the three number levers, commit `4bfecef` → `3751630`):

| lever | input | before | after | ratio |
| --- | --- | --- | --- | --- |
| EXP-001: integers print their own digits | `--encode` of `large_tabular_1500.json` (167255 bytes, 1500 rows) | 89.8 ms | 53.9 ms | 1.67× (cv 0.9% / 0.6%, A/A 1.001) |
| EXP-002: short integer texts are built from a `Nat` | `--decode` of the same table as TOON (76989 bytes) | 58.2 ms | 37.4 ms | 1.56× (cv 0.8% / 1.5%, A/A 0.995) |
| EXP-003: division by a power of ten is single-limb short division | `--encode` of 9000 one-decimal numbers | 288.2 ms | 135.6 ms | 2.12× (cv 0.8% / 0.7%, A/A 1.004) |

These three captures compare one binary that carries ALL THREE levers with the build before them, so each ratio belongs to the three together on that input. Alone (a variant with the other two twins switched off, against the all-twins-off arm of the current binary): EXP-003 is MEASURED at 2.05× (cv 2.7% / 3.9%, A/A 1.019); the captures of EXP-001 and EXP-002 alone were REFUSED by the cv gate twice, and their refused medians (about 16% and 3% below) say that neither is shown to meet its card's gate by itself. All three stay PROVISIONAL in `perf/NEGATIVE-EVIDENCE.md` (NE-001 to NE-003), also because the fast twins are bound to their specification twins by closed laws and differential runs, not by a quantified law. They sit behind the kill-switch `TOON_SPEC=1`.

**Inputs that are large in ONE dimension** (EXP-004, commit `3751630` → `1230a0d`; the earlier build walked a key chain per key):

| input | build of `3751630` (one run) | build of `1230a0d` | the original (`toon 0.2.4` @ `f955c67`, the PINNED `opt-level="z"` release) | `1230a0d` against the pinned original (against the strongest build: below) |
| --- | --- | --- | --- | --- |
| `-e`, one object of 16000 keys | 20.5 s | 66 ms | 17 ms | 0.25× the original's speed, MEASURED (cv 3.4% / 2.6%) |
| `-e`, 20 rows of 1200 fields | 6.5 s | 75 ms | 95 ms | 1.27× the original's speed, MEASURED (cv 4.7% / 1.1%) |
| `-d --expand-paths safe`, 40000 dotted lines | > 60 s (cut at its budget) | 772 ms | 2362 ms | 3.06× the original's speed, MEASURED (cv 0.8% / 3.1%) |
| `-e --key-folding safe`, 30000 foldable keys | > 60 s (cut at its budget) | 452 ms | 668 ms | ratio REFUSED_CV three times (the last: port arm cv 5.6%, 15 pairs): NO_EVIDENCE, `perf/NEGATIVE-EVIDENCE.md` NE-004 |

The non-author round 7 then showed that keys CHOSEN to collide in the carriers' 16 hash bits, and keys repeated in one object, were still quadratic (16000 colliding keys: 21 s; 16000 repeats: 50 s). Every bucket is a balanced tree now and a repeated key is resolved once per object; `python3 scripts/diff-fuzz.py scale --runs 16000 -- <port> --` runs those hostile inputs with a time verdict (too slow = more than 1 s AND more than 40 times the original): 5 inputs too slow on the binary of `1230a0d`, 0 on the current one, bytes identical.

**The port against the original on ordinary inputs** (`toon 0.2.4` @ `f955c67`, the pinned release build; the port binary sha256 `27787b9b…`, `--threads 1`; 15 AB/BA pairs; `perf/evidence/INCUMBENT.*.json`). That binary is what `bend port/main.bend -o <dir>/toon` emits from any commit since `a725d10`: the build is byte-reproducible, and the output BASENAME is its only path input (build it as `toon_head` and the bytes differ; build it as `toon` anywhere and they do not). MEASURED:

| input | the original | the port | ratio (original time / port time) |
| --- | --- | --- | --- |
| `--encode` of the 1500-row table (167 KB) | 6.3 ms | 54.9 ms | 0.114× (the port needs 8.7 times the original's time; cv 4.5% / 3.8%; 30 samples per arm) |
| `--decode` of the same table as TOON (77 KB) | 15.5 ms | 38.4 ms | 0.404× (the port needs 2.5 times the original's time; cv 4.7% / 2.7%; 30 samples per arm) |
| `--encode` of 20000 doubles of 15 to 17 digits (378 KB) | 7.7 ms | 1164.6 ms | 0.0066× (the port needs 151 times the original's time; cv 3.2% / 2.8%; 30 samples per arm) |

REFUSED by the cv gate in the same run, as in two earlier attempts, so NO ratio is claimed for them; their medians are orientation, not evidence: `--encode` of 24000 six-digit integers (50.7 ms against 5.9 ms, cv 3.2% / 16.3%); `--encode` of 9000 one-decimal numbers (146.9 ms against 3.4 ms, cv 7.3% / 21.8%); `--encode` of 7000 short strings (37.2 ms against 4.3 ms, cv 19.3% / 21.9%); `--encode` of 5000 scientific-notation numbers (1260.5 ms against 5.0 ms, cv 4.3% / 20.0%); `--version` (0.9 ms against 1.0 ms, cv 19.8% / 31.1%). The original finishes each of those in under 6 ms, which this shared host does not time to 5 percent; the retry predicate is a quiet host and inputs ten times larger. What is structural and will not change: Bend has no `f64`, so every non-integer number goes through big naturals (DISC-013); every input byte is a heap cell of a checked state machine; and the native runtime reserves 8 TiB of address space and uses 47 to 70 bytes of memory per input byte (DISC-011).

**Against the strongest build of the original.** Every ratio above is against the original's *pinned* release profile, which is `opt-level="z"` — tuned for size. The plan promised an `opt-level=3` incumbent so the comparison is against the strongest build; it was built on 2026-09-20 (`cargo build --release --locked --bin toon --config 'profile.release.opt-level=3'`, 862536 bytes against the pinned build's 670376) and it passes all 1065 captured goldens. What that profile is worth is **strongly input-dependent, and no single factor describes it**: 1.729× on the wide-rows input (97.0 → 56.1 ms, cv 2.0% / 4.2%, 42 samples, `perf/evidence/INCUMBENT-O3.vs-z-wide-rows.json`) and 1.389× on the expand input (2405 → 1732 ms, cv 1.3% / 2.4%, 18 samples, `.vs-z-expand.json`), both MEASURED; on the tabular encode the same capture was REFUSED by the cv gate at medians 5.84 → 4.98 ms (`.vs-z-tabular-enc.json`), so nothing is claimed there. Against that build, re-measured (15 and 9 AB/BA pairs):

| input | the strongest original | the port | ratio against the strongest build | the same ratio against the pinned build |
| --- | --- | --- | --- | --- |
| `-d --expand-paths safe`, 40000 dotted lines | 1716 ms | 863 ms | 1.989× (cv 3.1% / 3.1%) | 3.06× |
| `-e`, 20 rows of 1200 fields | 56 ms | 72 ms | 0.773× — the port is SLOWER (cv 4.4% / 2.3%) | 1.27× |

So one of the two inputs on which the port beat the original does not survive a fair build: the 1.27× was an artifact of the incumbent's size-tuned profile. On the wide-rows input that is arithmetic anyone can check — 0.773 × 1.729 = 1.34, within about 5 percent of the published 1.27×, so the flip is the build profile and not a change in the port.

**What the last column is NOT.** The two columns are separate captures, hours apart on a shared host, and the pinned-build column was measured with an EARLIER port binary (`71e268dc…`, the build of `1230a0d`) while the strongest-build column uses the current one (`27787b9b…`). They are not an interleaved pair, and the expand row's move (3.058 / 1.989 = 1.54) is larger than the 1.389× build factor alone accounts for; the residual is host state and the binary difference. Round 13 interleaved those two port binaries directly on that input and puts them within about 6 percent of each other (`docs/reviews/round-13.md`; that capture is the reviewer's, not a file of `perf/evidence/`). Two attempts to re-capture the pinned-build ratio with the current binary, so that the columns would be like-for-like, were REFUSED by the cv gate on a loaded host (cv 10.5% / 13.2% on wide rows, 5.3% / 3.9% on expand; `perf/evidence/INCUMBENT-Z.wide-rows-recapture.json`, `.expand-recapture.json`). That capture is bead `toon_bend-0i8`. The strongest build's median on the expand input also reads 1732 ms in one capture and 1716 ms in the other: two captures of one binary, not one number written twice. The `--encode` of the 1500-row table refused the cv gate against this build (the original's arm is 5.2 ms on a shared host) and claims nothing. Entry: `perf/NEGATIVE-EVIDENCE.md` NE-006.

---

## Design Philosophy

1. **The original is an oracle, not a template.** It is pinned (`docs/PIN.toml`), built, and run; implementation reads `docs/EXISTING_Toon_STRUCTURE.md`. A gap in the specification is an open question answered by *running* the original on a new case.
2. **Goldens are captured, never typed.** `goldens/<case>.out|.err|.exit` are what the pinned binary printed. Nobody edits them.
3. **Bugs are fixed, in the original first.** A bug found in either program is fixed in `toon_rust`, the port is re-pinned and re-captured, and the port is changed to match. A deliberate divergence from the pinned original exists only as a `DISC-` entry with a class, a measured impact and the owner's approval.
4. **Two equivalences, never conflated.** A claim says whether it is *proved* (a law), *golden-tested* (the harness on named lanes) or *measured* (an interleaved, cv-gated capture). Nothing else is a claim.
5. **Shapes the checker accepts are design rules.** One self-recursive `Json` type, pushdown machines with a stated measure, every input-length traversal a loop, dispatch on small class codes.

---

## Comparison

| Tool | Runtime | Evidence of parity | Proofs | Notes |
| --- | --- | --- | --- | --- |
| `toon_bend` (this repo) | Bend 2: native C, JavaScript, interpreter | 1124 captured cases x 4 lanes, differential fuzzing against the oracle | laws checked by Bend | port of `toon_rust` 0.2.4 at `694d73b` |
| `toon` (`toon_rust`) | Native (Rust) | spec fixtures | none | the oracle of this port |
| `toon` (reference, TS) | Node | canonical | none | defines the format |

---

## Installation

There is no installer. The build needs `bun` >= 1.4 and `clang` >= 14, and the pinned Bend checkout:

```bash
git clone https://github.com/bendlang/bend /tmp/bend
git -C /tmp/bend checkout --detach 15ae0c8           # bend 2.0.16, the pin in docs/PIN.toml
export BEND_NO_TELEMETRY=1 BEND_CLI='bun /tmp/bend/bend2/main.ts'
$BEND_CLI port/main.bend -o toon                      # native binary
$BEND_CLI port/main.bend -- --version                 # or run on the interpreter
```

Rebuilding the oracle (only needed to re-capture goldens) uses the original's pinned toolchain; see `docs/PLAN_TO_PORT_Toon_TO_BEND2.md` §2.

---

## Quick Start

```bash
./toon -- --encode < data.json            # JSON -> TOON
./toon -- --decode < data.toon            # TOON -> JSON
./toon -- data.json --delimiter pipe --key-folding safe
./toon -- data.toon --expand-paths safe      # dotted keys become nested objects (add --indent 4 only for TOON indented by fours)
./toon -- --help
```

---

## Command Reference

```bash
toon -- [OPTIONS] [INPUT]
```

Auto-detection:
- `.json` -> encode
- `.toon` -> decode
- stdin (no INPUT, or `-`) defaults to encode unless `--decode` is given

Flags (identical to the original's, every error text included):
- `-o, --output <FILE>`
- `-e, --encode`
- `-d, --decode`
- `--delimiter <,|\t|\||comma|tab|pipe>`
- `--indent <0..16>` (also the indent unit expected in TOON input)
- `--no-strict`
- `--key-folding <off|safe>`
- `--flatten-depth <N>`
- `--expand-paths <off|safe>`
- `--stats` (encode only)
- `-h, --help`, `-V, --version`

Exit codes: 0 success, 1 conversion or I/O error, 2 usage error.

---

## Configuration

There is no config file and no environment variable that changes a conversion. `TOON_SPEC=1` is the port's kill-switch: it selects the literal specification twin wherever a faster twin exists. That it does so for every input is a quantified law (`twin_gate_switch`); that the two twins agree is proved on closed instances and golden-tested on the whole corpus under both settings, not proved for every input.

---

## How It Works

```
JSON bytes -> strict UTF-8 -> JSON reader (pushdown machine, serde_json-compatible errors) -> Json value
           -> annotate (array strategy, key folding) -> emit -> TOON lines
TOON bytes -> strict UTF-8 -> scanner (all lines first) -> decoder (pushdown machine over lines) -> Json value
           -> JSON writer                                       (plain --decode)
           -> path expansion -> the same JSON writer            (--expand-paths safe)

Numbers: text <-> exact software binary64 (sign, exponent, 53-bit significand over big naturals).
Shell:   args, stdin/files as bytes, stdout/stderr, exit codes. It calls one pure function per step and prints.
```

### What Bend forces, and what it buys

- **No mutual recursion, no mutually recursive types.** A JSON value is ONE self-recursive type whose item and entry chains are its own constructors; the encoder's `emit`, the writer and the path expansion are each a single structurally recursive def driven by a parent-computed context.
- **Parsers are pushdown machines.** The JSON reader steps byte by byte over an explicit stack; the TOON decoder steps line by line, and each step either consumes a line or closes the innermost open construct - the measure the termination checker accepts.
- **A `match` scrutinizes a parameter, never a computed value.** Every decision is a verdict computed by the caller and passed down; the recursion stays in one def.
- **What it buys:** the checker proves, for every input, that the first failure ends a pass, that lenient mode never reports a body check, that `--encode` wins over every extension, that no expansion step runs at depth 256.

---

## Architecture

```
port/
  main.bend     IO shell: argv, bytes in, text out, exit codes
  stdin_open.c / .js   the one custom effect's twins: descriptor 0 as a Base File (native / JavaScript and interpreter)
  cli.bend      clap-compatible argv model, help/version, similarity tips, mode detection, --stats, convert
  text.bend     strict UTF-8, Unicode White_Space, trim, loop-based string and list tools, the hashed key set with balanced buckets
  bignat.bend   big naturals over 16-bit limbs
  f64.bend      software binary64: serde_json's float path, correctly rounded tokens, shortest digits, both printers
  json.bend     the Json type, the JSON reader, the JSON writer (one escape table)
  encode.bend   TOON encoder: quoting, headers, array strategy, list items, key folding
  decode.bend   TOON decoder: scanner, tokens, header parser, line machine, safe path expansion
  LAWS.bend     the laws (human-owned)
  PROOF.bend    their proofs; `bend PROOF.bend` is the gate
docs/           the plan, the pins, the specification, the architecture, the parity board, discrepancies, open questions
cases/          generators of the conformance corpus
goldens/        the captured outputs of the pinned original (never edited by hand)
scripts/        the porting harness: capture, floor, conform, lanes, doctor, lints, bench; plus diff-fuzz.py (seeded differential
                fuzzing), stdio-probe.py (descriptor states no case can express), hand-mutants.py (do the laws bite?)
bin/toon        the launcher: passes `--` first (DISC-001), repairs closed and wrong-mode standard descriptors (DISC-003/006/007)
perf/           the performance ledger, negative evidence, experiment cards
```

---

## Troubleshooting

1. **`--help` prints Bend's runtime help** - put `--` first: `./toon -- --help` (DISC-001).
2. **`Failed to parse JSON: ...`** - the input is not valid JSON; the message and its byte column are serde_json's.
3. **`Validation error at line N: Tabs are not allowed in indentation in strict mode`** - replace leading tabs or pass `--no-strict`.
4. **`Expected N list array items, but got M`** - the declared length must match in strict mode; also the symptom of items at the wrong depth.
5. **`Failed to decode TOON: Duplicate sibling key "k"`** - strict mode refuses a key repeated in one object unless both values are objects (they merge, like path expansion); `--no-strict` keeps the last value at the first position.
6. **`/tmp/bend` is gone** - it is ephemeral; re-clone and check out the pin (see Installation). Never `bend update` inside a session.

---

## Limitations

- Not ported (classed exclusions, `docs/PLAN_TO_PORT_Toon_TO_BEND2.md` §3): the `async-stream` feature, the `wasm` bindings, the `EncodeReplacer` library callback, library-only behavior no CLI path reaches, shell completions and tracing, native Windows.
- Divergences, every one a property of the Bend runtime or of number speed, each ACCEPTED with a scoped contract (`docs/DISCREPANCIES.md`): runtime flags before `--` (DISC-001, the launcher `bin/toon` passes `--` for you), unwritable standard streams (DISC-003, DISC-006; the launcher repairs the closed and read-only cases), non-UTF-8 argv words (DISC-004), no ANSI styling on a terminal (DISC-005), closed standard descriptors on the bare native binary (DISC-007, launcher), `-o` files created with mode 0644 (DISC-008), the native runtime's resource floor: 8 TiB of address space, 47 to 70 bytes of memory per input byte (DISC-011), non-integer numbers 45 to 306 times slower, linearly (DISC-013), a `/dev/fd/N` path the caller did not open (DISC-014), the sizes of the reads on stdin, visible to packet pipes and O_DIRECT files (DISC-015). RESOLVED by repairs: DISC-009, DISC-012 (stdin is read through the port's one custom effect); RESOLVED upstream, where the original was fixed: DISC-002 (usage lines name `toon`), DISC-010 (both programs stop at 127 levels of nesting).
- No GPU lane: the work is text with data-dependent structure; no bang is placed, so `gpu` is MISSING with that reason.

---

## FAQ

**Q: Is this a new format?**
A: No. It is the `toon` CLI of `toon_rust` 0.2.4, ported to Bend 2.

**Q: Does it match the original?**
A: On every captured case, byte for byte: see **Status**. Beyond the corpus, differential fuzzing against the original found three behaviors the specification had missed (all fixed, each now a clause and a case) and then ran clean: 13000 mutated documents, 16000 command lines, 4000 generated documents each encoded and then decoded, 127838 generated numbers (`docs/PORT_STATE.md`, rounds 1 to 5). The non-author review rounds (`docs/reviews/`) then found what the corpus cannot express (stdin re-opened by path, keys chosen to collide in the port's hash, descriptor states, cited commits that did not build); each finding is repaired or registered. Every divergence, all of them properties of the Bend runtime or of number speed, is ACCEPTED with a scoped contract or RESOLVED by a repair (`docs/DISCREPANCIES.md`).

**Q: Does the port reproduce the original's bugs?**
A: No. A bug found in either program is fixed properly: in `toon_rust` first, judged against the TOON specification and the reference implementation, then re-pinned, re-captured and ported. The eleven candidates the first inventory listed and every bug found since are fixed (`docs/DISCREPANCIES.md`); S10 of the specification keeps the history.

**Q: What is proved and what is tested?**
A: Proved, for every input and under the checker's assumptions: the 41 quantified laws in `port/LAWS.bend` (the gate of the shortest-digit word loop, the first failure ends a pass, strict mode reports a trailing line and an unmergeable repeated key, lenient mode never reports a body check, the mode flags win, the expansion cap, equal estimates print `No token difference`, the kill-switch gate, the two key-folding gate laws, the three laws of the parallel number pre-pass, the two laws of the argv scanner's gate for a word that begins with '-', and the JSON reader's string arm with its fast path closed). Proved for ONE value each: the closed laws, most of them a captured golden restated as `run_pure(argv, bytes) == (exit code, stdout, stderr)` and computed by the checker itself. A law speaks about Bend's logical semantics, not about the compiled C or the JavaScript build. Golden-tested: everything else, on the captured cases and the named lanes. Measured: performance numbers, each with its capture.

**Q: Why is there a software float?**
A: Bend 2 has `F32` only. The original holds every number in an `f64`, reads JSON numbers and TOON tokens correctly rounded, and prints shortest digits, as a plain decimal in TOON and as JavaScript's number text in JSON. All of that is reproduced exactly over big naturals.

---

## About Contributions

This repository follows the original's policy: outside contributions are not accepted. Issues and ideas are welcome.

---

## License

MIT License (with OpenAI/Anthropic Rider), the same text as the original `toon_rust`. See [LICENSE](LICENSE).

Third-party material: `cases/fixtures/spec/` holds the TOON specification's conformance fixtures from [toon-format/spec](https://github.com/toon-format/spec) (the copy `toon_rust` ships at the pinned commit); only their inputs and options are used, and they stay under their own license.
