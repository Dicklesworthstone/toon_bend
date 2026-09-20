# Plan to port Toon to Bend 2

<!-- Phase 0 document. Filled before the spec; amended (never silently
     rewritten) as the port learns. Every number here is a gate somewhere. -->

## 1. Purpose

`toon` (the `tru` crate, repository `toon_rust`) is a command-line converter
between JSON and TOON (Token-Oriented Object Notation, spec v3.0): an
indentation-based, length-prefixed text encoding of the JSON data model built
to spend fewer LLM tokens. It encodes JSON to TOON (inline primitive arrays,
tabular arrays of uniform objects, list arrays, optional safe key folding,
three delimiters), decodes TOON to JSON (strict validation by default, optional
safe path expansion), and estimates token savings. It is run by people and
agents that move structured data in and out of prompts. The Bend 2 port buys
two of Bend's properties: **byte-identical lanes** (one source whose
interpreter, C at 1 and N threads, and JS executions agree with the Rust
binary byte for byte on 678 captured cases) and **proved fast twins** (the
row-wise encode and decode kernels are data-parallel by shape, so a balanced
fork is bound to the literal sequential twin by a law instead of by testing).
It also yields the first machine-checked statements of TOON's algebraic
properties (escape/unescape round trip, quoting safety, fold/expand inverse).
No GPU lane is planned: the workload is text with data-dependent structure,
so no bang is placed (GPU-PORTS "Is the original a GPU port at all?": no).

## 2. The original, pinned (the truth pack)

| field | value |
|---|---|
| repository / path | `legacy/Toon` (gitignored; an oracle, never a template) |
| commit / version | `f955c67015d45330935b3ae4d62178d2bb44a481` (2026-09-12, clean tree) / `toon 0.2.4`; upstream `https://github.com/Dicklesworthstone/toon_rust`; behavior-bearing locked dependencies: `serde_json 1.0.151` (parse, error text, string escaping), `zmij 1.0.23` (JSON float text), `indexmap 2.14.0` (key order, duplicates), `clap 4.6.6` / `clap_builder 4.6.6` (argv, usage text, exit 2) |
| toolchain to build it | `rustc 1.100.0-nightly (908501772 2026-08-30)`, `cargo 1.100.0-nightly (e8cb624d5 2026-08-22)`, pinned by the original's `rust-toolchain.toml` (`nightly-2026-08-31`) |
| build command | `cd legacy/Toon && cargo build --release` (the original's release profile: `opt-level="z"`, `lto=true`, `codegen-units=1`, `panic="abort"`, `strip=true`); the artifact is snapshotted to `oracle/toon` (gitignored), sha256 `980f2b26484f424b74cb0a0b61062183d0038d45101590a38953a82611879a6d`. The copy in `~/.local/bin/toon` is a different build (681 KB vs 655 KB) and is not the oracle. Phase 5 also builds an `opt-level=3` incumbent so the speed comparison is against the strongest build, recorded there. |
| run command | `./oracle/toon` from the project root (case argv appended; stdin from the case's file or `/dev/null`) |
| threads / parallelism it uses | single-threaded (the `async-stream` feature is off in the pinned build and excluded, §3) |
| nondeterminism floor | `scripts/floor.sh` over 3 runs: 678 stable / 0 unstable: `{"repeat":3,"stable":678,"unstable":[],"inconclusive":[],"oracle_identity_checked":true,"verdict":"STABLE"}` (2026-09-20) |
| goldens | `goldens/cases.tsv` (678 cases: 329 hand-designed from `cases/gen-hand-cases.py`, 349 from the vendored TOON spec fixtures via `cases/gen-fixture-cases.py`; 507 exit 0, 139 exit 1, 32 exit 2 in the current capture), `goldens/MANIFEST.txt` recorded at each capture. Re-captures: 2026-09-20 `--repin` OQ-001/OQ-002 (+9 cases, 0 prior hashes changed). The fixtures' own `expected` fields are the upstream TypeScript reference's and are not goldens. |
| rigor tier | **T2** (a tool with a data format: ~350 spec behaviors, 12 flags, ~60 error paths). Convergence: ≥ 5 rounds, last 2 clean, ≥ 1 non-author round. |

### 2b. Bend, pinned (VERSION-DRIFT)

| field | value |
|---|---|
| `bend --version` | `bend 2.0.16` |
| how obtained | a checkout of `bendlang/bend` at `15ae0c8` (`v2.0.16-5-g15ae0c8`, clean) run as `BEND_CLI='bun /tmp/bend/bend2/main.ts'`; no `bend` is on PATH on this host. `/tmp/bend` is ephemeral: re-clone and `git checkout --detach 15ae0c8` to restore the pin. |
| bun / clang | `1.4.2` / `Ubuntu clang version 21.1.8 (6ubuntu1)` |
| verdict under this pin | scaffold: `All terms check.` = 0 @unsafe + 0 template instances (2026-09-20); restated at every gate in `docs/PORT_STATE.md` |
| drift check | first pin; no previous CLI to compare. On any change of `/tmp/bend`'s HEAD: `./scripts/version-drift.sh --old "bun <old checkout>/bend2/main.ts" --new "bun /tmp/bend/bend2/main.ts"` before any other gate. |

## 3. Scope

### In scope (each row becomes rows in FEATURE_PARITY.md)

| surface | original entry point | notes |
|---|---|---|
| encode JSON → TOON (`--encode`, `-e`, default mode) | `src/cli/mod.rs:run_encode`, `src/encode/*` | normalization, primitive/key quoting, array strategy (inline / tabular / list), list-item objects, indentation 0–16 |
| delimiters comma / tab / pipe (`--delimiter`, word and escape spellings) | `src/cli/args.rs:parse_delimiter`, `src/encode/primitives.rs:format_header` | delimiter-aware quoting and header suffix |
| safe key folding (`--key-folding safe`, `--flatten-depth N`) | `src/encode/folding.rs:try_fold_key_chain` | sibling and root-literal collision rules, depth budget |
| decode TOON → JSON (`--decode`, `-d`) | `src/cli/mod.rs:run_decode`, `src/decode/*` | scanner, header parser, inline/tabular/list arrays, list-item objects, root form detection, event stream |
| strict validation and `--no-strict` | `src/decode/scanner.rs`, `src/decode/validation.rs` | tabs, indent multiples, counts, blank lines, extra rows/items, length cap 100 000 000 |
| safe path expansion (`--expand-paths safe`) | `src/decode/expand.rs` | quoted-key suppression, deep merge, strict conflicts vs last-write-wins, depth cap 256 |
| JSON text input | `serde_json 1.0.151` (`de.rs`, `read.rs`) | full grammar, byte-column error positions, recursion limit 128, duplicate keys (last value, first position), the default (not round-trip) float path |
| JSON text output, two writers | `src/cli/json_stream.rs` (streaming) and `src/cli/json_stringify.rs` (with `--expand-paths safe`) | indent 0 compact / N pretty; the two writers escape control characters differently (bug-compatible) |
| number text | Rust `f64` `Display` (TOON side), `zmij 1.0.23` (JSON side), Rust `str::parse::<f64>` (TOON tokens) | carried as exact binary64 in software: NUMERIC_PLAN |
| mode auto-detection, stdin / `-`, `-o FILE`, success lines | `src/cli/args.rs:detect_mode`, `src/cli/mod.rs` | `.json`/`.toon` case-insensitive; `Encoded \`in\` → \`out\`` on stderr |
| `--stats` | `src/cli/mod.rs:estimate_tokens` | Unicode-whitespace word and character counts; percent through two f64 operations and `{:.1}` |
| usage surface | `clap 4.6.6` derive in `src/cli/args.rs` | `--help`/`-h`, `--version`/`-V`, value validation, conflicts, repeats, missing values, unexpected arguments with the `--` tip; exit 2 |
| input errors | `src/error.rs`, Rust `std::io` | missing file, directory, invalid UTF-8 (`stream did not contain valid UTF-8`), uncreatable output; exit 1 |
| library surface as Bend modules | `src/lib.rs` | `encode`, `encode_lines`, `decode`, `decode_stream` (events), `expand`, exported from `port/` for Bend callers; exercised through the CLI goldens |

### Excluded (each row is debt or infeasibility, never "later")

| feature | reason | class | debt? |
|---|---|---|---|
| async streaming encode/decode (`async-stream` feature, `asupersync`) | off in the pinned build; not reachable from the CLI; Bend has no async runtime to mirror, and the synchronous event stream carries the same semantics | out-of-scope | no |
| WebAssembly bindings (`wasm` feature, `src/wasm.rs`) | a packaging of the same library for JS hosts; Bend's own JS lane (`bend x.bend -o x.js`) is the counterpart and is one of the conformance lanes | out-of-scope | no |
| `EncodeReplacer` callback | a library-only closure hook with no CLI spelling, so no golden can be captured for it through the oracle binary; ported as a Bend higher-order def only if a Rust driver is added to capture stage goldens | out-of-scope | yes |
| clap's "a similar argument exists" suggestion and its context-built `Usage:` line for a suggested flag | a string-similarity engine inside clap; the plain unexpected-argument error, the `--` tip and the fixed `Usage:` lines are in scope | external-dependency | yes |
| shell completions, `tracing` logs, `chrono`, `vergen` build metadata | dependencies of the crate that no CLI path of the pinned build reaches | out-of-scope | no |
| native Windows paths and line endings | Bend 2 has no native Windows target | platform | no |
| a bare `--help`, `--threads N`, `--gpu X` given to the compiled Bend binary **before** `--` | the Bend runtime consumes its own flags ahead of the program; the harness and the shipped launcher pass `--` first, so every golden holds; recorded as DISC-001 (Platform) | platform | no |

## 4. Reference Bend programs (imitate, do not invent)

- `bend2-mega-skill/assets/skeletons/cli_tool.bend` (args, exit codes, files)
- `bend2-mega-skill/assets/skeletons/laws_proof/` (LAWS/PROOF split)
- `bend2-mega-skill/assets/skeletons/parallel_kernel.bend` (balanced fork, one bang)
- `porting-to-bend2/assets/example-port/` (a complete port with goldens, laws and a fast twin)
- the Bend repository's text-processing demos and `tests/` string and parser programs, chosen in Phase 2 from REPO-CORPUS-FOR-PORTERS (recorded in PROPOSED_ARCHITECTURE)

## 5. Success criteria (numbers, each a gate)

| criterion | target | gate |
|---|---|---|
| conformance | 100% of 678 cases (more as OQs add them) on interpreter, C 1T, C 8T, JS; no bang, so gpu is MISSING with that reason | `scripts/lanes.sh` PASS |
| proofs | `All terms check.` with 0 `@unsafe`; template instances stated beside the verdict | `bend port/PROOF.bend` |
| parity board | FULL (or DEBT with every exclusion listed above) | `scripts/parity-board.sh` |
| discrepancies | every divergence a DISC entry with a kill-switch | `docs/DISCREPANCIES.md` |
| performance (after parity) | no target is promised: the incumbent is a native Rust binary. The number, whatever it is, is reported as measured at 1 thread vs 1 thread on `large_tabular_*` inputs with cv ≤ 5%, plus the port's own 1T→8T scaling | `scripts/incumbent-bench.sh --pin` |
| ledgers | every lever an experiment card and an outcome | `perf/` |

## 6. Phases and their artifacts

| phase | artifact | gate to leave |
|---|---|---|
| −1 fit screen | this file §3 and §7 | no infeasible feature in scope without an exclusion row |
| 0 truth pack | §2, goldens, MANIFEST, floor | floor STABLE (or DISC per unstable case) |
| 1 spec | `docs/EXISTING_Toon_STRUCTURE.md` | spec self-containment review passed |
| 2 architecture | `docs/PROPOSED_ARCHITECTURE.md`, `docs/NUMERIC_PLAN.md`, `port/LAWS.bend` draft | every spec clause has a home (def) and an evidence kind (law/golden) |
| 3 reference port | `port/main.bend` spec twins, `port/PROOF.bend` | lanes PASS, All terms check. |
| 4 parity gate | `docs/FEATURE_PARITY.md`, DISC register, find-fix rounds | parity FULL/DEBT, convergence rule met |
| 5 performance | fast twins, `perf/` ledgers, incumbent numbers | every kept lever law-bound, cv-gated, ledgered |
| 6 certify | `docs/PORT_REPORT.md`, evidence bundle | claims taxonomy complete; SHIP/HOLD/BLOCK |

## 7. Risks and unknowns

| risk | where it bites | mitigation |
|---|---|---|
| **every JSON number is an `f64` in the original and Bend has none** | NUMERIC_PLAN; every number that reaches an output | no F32 budget class: numbers are carried as exact binary64 values in software (sign, exponent, 53-bit significand over big-natural limbs). Three algorithms are reproduced exactly because the goldens show all three: serde_json's default float path on the encode side (u64 significand, later digits dropped, one f64 multiply or divide by a power of ten: `0.3333333333333333333333` encodes as `0.33333333333333337`), Rust's correctly rounded `str::parse::<f64>` on the decode side, and shortest round-trip digit generation for both printers (Rust `Display` without exponents; zmij with `e±X` outside 1e-5…1e16). `--stats` percent uses the same software f64 division and multiplication |
| serde_json's error surface (25 messages, byte columns, recursion limit 128) | JSON reader | the reader runs over bytes, not code points, so line/column arithmetic matches; one clause and one case per message |
| strict UTF-8 on input; Bend's `File.read` decodes with replacement | shell | `File.read_bytes` + a strict decoder in the core; invalid input is the original's `stream did not contain valid UTF-8` error |
| Unicode-aware `trim()` / `is_whitespace()` / `is_control()` in the original; Base's are ASCII-only | quoting safety, token trimming, stats, the second JSON writer | hand-written White_Space and Cc tables with a case per boundary code point |
| OS error text (`No such file or directory (os error 2)`) | shell | built from the effect's errno; checked per lane, an `ErrorText` DISC only if a lane cannot produce it |
| the compiled binary consumes `--help`/`--threads`/`--gpu` before `--` | usage surface | harness and launcher pass `--`; DISC-001 Platform |
| String is a cons list of code points: long inputs and the interpreter lane's speed | large cases; per-case timeouts | accumulate reversed and reverse once (no quadratic `++`); `--timeout` raised for `large_*` on the interpreter lane only if measured necessary, recorded in PORT_STATE |
| iteration-order leaks (dict/map/set) | spec §6 | explicit order carried beside the Map; stable sort with the original's tie-break |
| exceptions as control flow | core/shell split | Result/Maybe in the core; the shell maps to exit codes |
| loops without an evident measure | translation | fuel or structural descent; `@unsafe` counted, never hidden |
| original is nondeterministic | truth pack | floor.sh; canonicalizing wrapper as a DISC |
