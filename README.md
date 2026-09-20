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
bun /tmp/bend/bend2/main.ts port/main.bend -o port/toon && bin/toon --encode < users.json
```

<p><em>Run and gated on Linux x86_64 only; macOS is untested (the launcher's repair of wrong-mode descriptors reads /proc). No package, no installer: one Bend build, about 25 seconds.</em></p>
</div>

---

## TL;DR

### The Problem
A port is only as good as the evidence that it behaves like the original. "The tests pass" says little when the tests were typed by the porter, and "it is the same algorithm" says nothing about the forty places where the original does something its own README does not mention.

### The Solution
`toon_bend` is built with the *porting-to-bend2* method: the original is pinned and RUN as an oracle (never read while implementing), its behavior is written down as a numbered specification (703 clauses), the Bend code is written from that specification, and it is judged against 1065 captured cases on four executor lanes. Two equivalences are kept apart:

1. **original == spec** is *golden-tested*: `goldens/` holds what the pinned binary printed; a case passes when stdout, stderr and the exit code match byte for byte on the interpreter, the native binary at 1 and 8 threads, and the JavaScript build.
2. **spec == fast** rests on laws in `port/LAWS.bend`, checked by `port/PROOF.bend` (`All terms check.`), and this README says exactly how far they reach: the three fast twins that exist are bound to their specification twins by ONE quantified law (under `TOON_SPEC=1` every twin selector is off, for every input), by closed instance laws on boundary values, and by running both twins against the original on generated numbers. No universally quantified `fast == spec` law exists for any of them; `perf/NEGATIVE-EVIDENCE.md` NE-001 to NE-003 keep them provisional for that reason.

### Why Use `toon_bend`?

| Feature | Why it matters |
| --- | --- |
| Byte-for-byte parity, golden-tested | stdout, stderr and the exit code match the pinned original byte for byte on 1065 captured cases; see **Status** below for the lanes and the commit each line was produced on |
| Bug-compatible by default | decoded integers print as `1.0`, JSON number input is not correctly rounded, the two JSON writers escape differently: all reproduced, all listed for the owner in `docs/DISCREPANCIES.md` |
| Exact numbers without an `f64` | Bend has no binary64: the port carries a software binary64 over big naturals and reproduces three different number algorithms of the original bit for bit |
| Proved properties | 368 laws checked by Bend (`All terms check.`, unsafe 0 = 0 `@unsafe` + 0 template instances, bend 2.0.16): 14 hold for every input (the first failure ends a pass, lenient mode never reports a body check, `--encode` beats every extension, no expansion step runs at depth 256, the kill-switch closes every fast path); 354 are closed instances computed by the checker itself, 295 of them captured goldens restated as laws. 22 hand-written mutants of the code the laws speak about are all killed (`scripts/hand-mutants.py`) |
| One pure core, a thin shell | `run_pure(argv, bytes) -> (exit code, stdout, stderr)` is a value; `main.bend` is the only file with `IO` in its types |
| No unsafe code, no dependencies | `import Base` only; 0 `@unsafe`, 0 template instances (bend 2.0.16); ONE custom effect, `Stdin.open`, with a C and a JavaScript twin, because Base cannot read descriptor 0 (DISC-012) |

---

## Status

Every line names its command, its lanes and its commit. Dates: 2026-09-20. Bend: 2.0.16 at `15ae0c8`. Original: `toon_rust` `f955c67` (`toon 0.2.4`).

- **Golden-tested, every lane:** `scripts/lanes.sh goldens/cases.tsv goldens port/main.bend --threads 8` → PASS on the interpreter, the native binary at 1 and at 8 threads, and the JavaScript build: 1065/1065 each on the tree of `4c3cccc` (and 1060/1060 at `d80251a`, 1053/1053 at `1230a0d`); `scripts/conform.sh` also passes 1065/1065 on the three compiled lanes with `TOON_SPEC=1`. MANIFEST: 3195 hashes, captured from `./oracle/toon`; floor STABLE (the original against itself, 3 repeats). The two native lanes are ONE sequential execution under two labels: the port places no bang and no parallel let, so the runtime never starts a worker pool and `--threads N` changes nothing (2 OS threads at `--threads` 1, 8 and 64, measured by round 10 and re-measured); `c-8t` adds no evidence beyond `c-1t` today and is kept because it would catch a parallel twin the day one is added.
- **Outside the corpus:** seeded differential fuzzing against the original (`scripts/diff-fuzz.py`: mutated corpus documents, generated documents through every option, command lines, numbers under both settings of the kill-switch, expansion, keys chosen to collide in the port's hash, inputs large in one dimension with a time verdict) and the descriptor states the harness cannot express (`scripts/stdio-probe.py`: inherited offsets, sockets, closed, read-only and full standard streams, descriptor paths). Five NON-AUTHOR review rounds (6 to 10; their reports are in `docs/reviews/`, what was done about each finding in `docs/PORT_STATE.md`) compared well over a million executions with the original and found 0 differences in conversion content since round 7's repairs; their 38 findings (2 HIGH in round 7: stdin used to be re-opened by path; 1 HIGH in round 10: three cited commits did not build from the public history, because `.gitignore` hid two source files) are each repaired or registered.
- **Proved:** `bun /tmp/bend/bend2/main.ts port/PROOF.bend` → `All terms check.`, 368 laws, unsafe 0 = 0 `@unsafe` + 0 template instances, bend 2.0.16.
- **Parity board:** `scripts/parity-board.sh docs/FEATURE_PARITY.md` → 27 in-scope rows `present`, 6 classed exclusions, verdict DEBT (an exclusion is debt, by rule).
- **Verdict:** HOLD, not SHIP (`docs/PORT_REPORT.md`). What holds it: the convergence rule needs two clean non-author review rounds in a row, and none of rounds 6 to 10 was clean (`scripts/converge.sh docs/PORT_STATE.md`). Every divergence is ACCEPTED with a scoped contract or RESOLVED by a repair (`docs/DISCREPANCIES.md`, DISC-001 to DISC-014).

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

Every RATIO here is a capture by `scripts/incumbent-bench.sh`: AB/BA pairs, medians, a cv gate of 5 percent per arm (a capture above it is REFUSED and gives no ratio), identical stdout and stderr in every sample. Two columns are NOT such captures and say so: the earlier build's single timed runs in the second table, and the round 7 timings quoted below it. No row is admitted to `perf/PERF-LEDGER.md` yet; everything measured so far is provisional (`perf/NEGATIVE-EVIDENCE.md` NE-001 to NE-005). Host: AMD EPYC-Milan, 8 cores, Linux, shared with other agents' work; 1 thread; bend 2.0.16, clang 21.1.8; 2026-09-20. The JSON lines are in `perf/evidence/`, the cards in `perf/EXPERIMENTS.md`.

**The port against earlier builds of itself** (the three number levers, commit `4bfecef` → `3751630`):

| lever | input | before | after | ratio |
| --- | --- | --- | --- | --- |
| EXP-001: integers print their own digits | `--encode` of `large_tabular_1500.json` (167255 bytes, 1500 rows) | 89.8 ms | 53.9 ms | 1.67× (cv 0.9% / 0.6%, A/A 1.001) |
| EXP-002: short integer texts are built from a `Nat` | `--decode` of the same table as TOON (76989 bytes) | 58.2 ms | 37.4 ms | 1.56× (cv 0.8% / 1.5%, A/A 0.995) |
| EXP-003: division by a power of ten is single-limb short division | `--encode` of 9000 one-decimal numbers | 288.2 ms | 135.6 ms | 2.12× (cv 0.8% / 0.7%, A/A 1.004) |

Each met the gate written on its card before the capture. They are still PROVISIONAL in `perf/NEGATIVE-EVIDENCE.md` (NE-001 to NE-003), for two stated reasons: the fast twins are bound to their specification twins by closed laws and differential runs, not by a quantified law, and one binary carries all three levers, so no capture isolates one. They sit behind the kill-switch `TOON_SPEC=1`.

**Inputs that are large in ONE dimension** (EXP-004, commit `3751630` → `1230a0d`; the earlier build walked a key chain per key):

| input | build of `3751630` (one run) | build of `1230a0d` | the original (`toon 0.2.4` @ `f955c67`, release) | `1230a0d` against the original |
| --- | --- | --- | --- | --- |
| `-e`, one object of 16000 keys | 20.5 s | 66 ms | 17 ms | 0.25× the original's speed, MEASURED (cv 3.4% / 2.6%) |
| `-e`, 20 rows of 1200 fields | 6.5 s | 75 ms | 95 ms | 1.27× the original's speed, MEASURED (cv 4.7% / 1.1%) |
| `-d --expand-paths safe`, 40000 dotted lines | > 60 s (cut at its budget) | 772 ms | 2362 ms | 3.06× the original's speed, MEASURED (cv 0.8% / 3.1%) |
| `-e --key-folding safe`, 30000 foldable keys | > 60 s (cut at its budget) | 307 ms | 610 ms | ratio REFUSED_CV twice (port arm cv 6.8%): NO_EVIDENCE, `perf/NEGATIVE-EVIDENCE.md` NE-004 |

The non-author round 7 then showed that keys CHOSEN to collide in the carriers' 16 hash bits, and keys repeated in one object, were still quadratic (16000 colliding keys: 21 s; 16000 repeats: 50 s). Every bucket is a balanced tree now and a repeated key is resolved once per object; `python3 scripts/diff-fuzz.py scale --runs 16000 -- <port> --` runs those hostile inputs with a time verdict (too slow = more than 1 s AND more than 40 times the original): 5 inputs too slow on the binary of `1230a0d`, 0 on the current one, bytes identical.

**The port against the original on ordinary inputs: no claim.** All six captures were REFUSED by the cv gate on the loaded host (`perf/evidence/INCUMBENT.*.json`, arms at 7 to 48 percent cv), so this README states no ratio. The refused medians, for orientation only and not as evidence: encode the 1500-row table: 63.6 ms against 6.0 ms; decode it: 48.9 ms against 23.9 ms; encode 24000 integers: 57.2 ms against 6.0 ms; encode 9000 decimals: 153.1 ms against 3.9 ms; encode 7000 strings: 39.6 ms against 4.0 ms; `--version`: 0.9 ms against 0.9 ms. What is structural and will not change: Bend has no `f64`, so every non-integer number goes through big naturals; every input byte is a heap cell of a checked state machine; and the native runtime reserves 8 TiB of address space and uses 47 to 70 bytes of memory per input byte (DISC-011).

---

## Design Philosophy

1. **The original is an oracle, not a template.** It is pinned (`docs/PIN.toml`), built, and run; implementation reads `docs/EXISTING_Toon_STRUCTURE.md`. A gap in the specification is an open question answered by *running* the original on a new case.
2. **Goldens are captured, never typed.** `goldens/<case>.out|.err|.exit` are what the pinned binary printed. Nobody edits them.
3. **Bug-compatible by default.** A deliberate divergence exists only as a `DISC-` entry with a class, a measured impact and the owner's approval.
4. **Two equivalences, never conflated.** A claim says whether it is *proved* (a law), *golden-tested* (the harness on named lanes) or *measured* (an interleaved, cv-gated capture). Nothing else is a claim.
5. **Shapes the checker accepts are design rules.** One self-recursive `Json` type, pushdown machines with a stated measure, every input-length traversal a loop, dispatch on small class codes.

---

## Comparison

| Tool | Runtime | Evidence of parity | Proofs | Notes |
| --- | --- | --- | --- | --- |
| `toon_bend` (this repo) | Bend 2: native C, JavaScript, interpreter | 1065 captured cases x 4 lanes, differential fuzzing against the oracle | laws checked by Bend | bug-compatible port of `toon_rust` 0.2.4 |
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
           -> JSON writer, escape table A                       (plain --decode)
           -> path expansion -> JSON writer, escape table B     (--expand-paths safe)

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
  json.bend     the Json type, the JSON reader, the JSON writer with two escape tables
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
2. **`JSON error: Failed to parse JSON: ...`** - the input is not valid JSON; the message and its byte column are serde_json's.
3. **`Validation error at line N: Tabs are not allowed in indentation in strict mode`** - replace leading tabs or pass `--no-strict`.
4. **`Expected N list array items, but got M`** - the declared length must match in strict mode; also the symptom of items at the wrong depth.
5. **Decoded numbers print as `1.0`** - that is the original's behavior (every decoded number is a binary64); it is reproduced, and listed as candidate C-1 for the owner.
6. **`/tmp/bend` is gone** - it is ephemeral; re-clone and check out the pin (see Installation). Never `bend update` inside a session.

---

## Limitations

- Not ported (classed exclusions, `docs/PLAN_TO_PORT_Toon_TO_BEND2.md` §3): the `async-stream` feature, the `wasm` bindings, the `EncodeReplacer` library callback, library-only behavior no CLI path reaches, shell completions and tracing, native Windows.
- Divergences, every one a property of the Bend runtime or of number speed, each ACCEPTED with a scoped contract (`docs/DISCREPANCIES.md`): runtime flags before `--` (DISC-001, the launcher `bin/toon` passes `--` for you), the literal program name `toon` in usage lines (DISC-002), unwritable standard streams (DISC-003, DISC-006; the launcher repairs the closed and read-only cases), non-UTF-8 argv words (DISC-004), no ANSI styling on a terminal (DISC-005), closed standard descriptors on the bare native binary (DISC-007, launcher), `-o` files created with mode 0644 (DISC-008), no nesting limit where the original's stack overflows (DISC-010), the native runtime's resource floor: 8 TiB of address space, 50 to 70 bytes of memory per input byte (DISC-011), non-integer numbers 45 to 300 times slower, linearly (DISC-013), a `/dev/fd/N` path the caller did not open (DISC-014). RESOLVED by repairs: DISC-009, DISC-012 (stdin is read through the port's one custom effect).
- No GPU lane: the work is text with data-dependent structure; no bang is placed, so `gpu` is MISSING with that reason.

---

## FAQ

**Q: Is this a new format?**
A: No. It is the `toon` CLI of `toon_rust` 0.2.4, ported to Bend 2.

**Q: Does it match the original?**
A: On every captured case, byte for byte: see **Status**. Beyond the corpus, differential fuzzing against the original found three behaviors the specification had missed (all fixed, each now a clause and a case) and then ran clean: 13000 mutated documents, 16000 command lines, 8000 generated documents in both directions, 127838 generated numbers. Three non-author review rounds then found what the corpus cannot express (stdin re-opened by path, keys chosen to collide in the port's hash, descriptor states); each finding is repaired or registered. Eleven divergences, all properties of the Bend runtime or of number speed, are ACCEPTED with a scoped contract each (`docs/DISCREPANCIES.md`).

**Q: Why reproduce the bugs?**
A: Because a port that silently fixes things is a different program. Each oddity is reproduced, numbered in the specification (S10), and listed for the owner, who can accept a `DISC-` with a kill-switch.

**Q: What is proved and what is tested?**
A: Proved, for every input and under the checker's assumptions: the 14 quantified laws in `port/LAWS.bend` (the first failure ends a pass, lenient mode never reports a body check, the mode flags win, the expansion cap, no `Saved` line without savings, the kill-switch gate). Proved for ONE value each: the closed laws, most of them a captured golden restated as `run_pure(argv, bytes) == (exit code, stdout, stderr)` and computed by the checker itself. A law speaks about Bend's logical semantics, not about the compiled C or the JavaScript build. Golden-tested: everything else, on the captured cases and the named lanes. Measured: performance numbers, each with its capture.

**Q: Why is there a software float?**
A: Bend 2 has `F32` only. The original holds every number in an `f64`, reads JSON numbers with serde_json's default (not correctly rounded) path, reads TOON tokens correctly rounded, and prints with two shortest-digit algorithms that differ on ties. All of that is reproduced exactly over big naturals.

---

## About Contributions

This repository follows the original's policy: outside contributions are not accepted. Issues and ideas are welcome.

---

## License

MIT License (with OpenAI/Anthropic Rider), the same text as the original `toon_rust`. See [LICENSE](LICENSE).

Third-party material: `cases/fixtures/spec/` holds the TOON specification's conformance fixtures from [toon-format/spec](https://github.com/toon-format/spec) (the copy `toon_rust` ships at the pinned commit); only their inputs and options are used, and they stay under their own license.
