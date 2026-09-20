# AGENTS.md — toon_bend (toon, the Bend 2 port)

> Guidelines for AI coding agents working in this Bend 2 codebase. Read this whole file, then `docs/PORT_STATE.md`, before any work.

---

## RULE 0 - THE FUNDAMENTAL OVERRIDE PREROGATIVE

If I tell you to do something, even if it goes against what follows below, YOU MUST LISTEN TO ME. I AM IN CHARGE, NOT YOU.

---

## RULE NUMBER 1: NO FILE DELETION

**YOU ARE NEVER ALLOWED TO DELETE A FILE WITHOUT EXPRESS PERMISSION.** Even a new file that you yourself created, such as a test code file. You have a horrible track record of deleting critically important files or otherwise throwing away tons of expensive work. As a result, you have permanently lost any and all rights to determine that a file or folder should be deleted.

**YOU MUST ALWAYS ASK AND RECEIVE CLEAR, WRITTEN PERMISSION BEFORE EVER DELETING A FILE OR FOLDER OF ANY KIND.**

---

## Irreversible Git & Filesystem Actions — DO NOT EVER BREAK GLASS

1. **Absolutely forbidden commands:** `git reset --hard`, `git clean -fd`, `rm -rf`, or any command that can delete or overwrite code/data must never be run unless the user explicitly provides the exact command and states, in the same message, that they understand and want the irreversible consequences.
2. **No guessing:** If there is any uncertainty about what a command might delete or overwrite, stop immediately and ask the user for specific approval. "I think it's safe" is never acceptable.
3. **Safer alternatives first:** When cleanup or rollbacks are needed, request permission to use non-destructive options (`git status`, `git diff`, `git stash`, copying to backups) before ever considering a destructive command.
4. **Mandatory explicit plan:** Even after explicit user authorization, restate the command verbatim, list exactly what will be affected, and wait for a confirmation that your understanding is correct. Only then may you execute it—if anything remains ambiguous, refuse and escalate.
5. **Document the confirmation:** When running any approved destructive command, record (in the session notes / final response) the exact user text that authorized it, the command actually run, and the execution time. If that record is absent, the operation did not happen.

---

## Git Branch: ONLY Use `main`, NEVER `master`

**The default branch is `main`. There is no `master` branch in this repository; never create one.**

- **All work happens on `main`** — commits, PRs, feature branches all merge to `main`
- **Never reference `master` in code or docs** — if you see `master` anywhere, it's a bug that needs fixing
- If a `master` branch is ever added for legacy URL compatibility, it must stay synchronized with `main`:
  ```bash
  git push origin main:master
  ```

---

## Toolchain: Bend 2

We only use **Bend 2** (`bendlang/bend`, CLI `bend`) for the port, NEVER another language for anything that reaches an output. The harness around it is Bash and Python 3; nothing else is added.

- **Language:** Bend 2, pinned in `docs/PIN.toml` and `docs/PLAN_TO_PORT_Toon_TO_BEND2.md` §2b (currently `bend 2.0.16`, checkout `15ae0c8`)
- **How it runs here:** no `bend` is on PATH on the build hosts; every command uses `BEND_CLI='bun /tmp/bend/bend2/main.ts'` with `BEND_NO_TELEMETRY=1`. `/tmp/bend` is ephemeral: re-clone `bendlang/bend` and `git checkout --detach 15ae0c8` to restore the pin. **Never `bend update` inside a session.**
- **Dependencies:** `import Base` only. No hub packages, no custom effects (a custom effect would exist on one lane only).
- **Unsafe code:** Forbidden. `@unsafe` needs the owner's approval, a comment naming the measure that was not expressible, and a bead; the count is stated beside every claim.
- **Base templates (`~`):** avoided in everything `PROOF.bend` imports. Since 2.0.16 every template instance is counted in the verdict as an unsafe annotation, so a `List.map(~…)` would turn `All terms check.` into a partial green. Write the four-line recursion instead.
- **When the version moves:** `./scripts/version-drift.sh --old "<pinned cli>" --new "<this cli>"` before any other gate (see the porting skill's VERSION-DRIFT).

### Tools the gates need

| Tool | Purpose |
|------|---------|
| `bun` ≥ 1.4 | runs the Bend CLI from the checkout, the interpreter lane and the JS lane |
| `clang` ≥ 14 | builds the native binary (`bend main.bend -o toon`); both C lanes |
| `python3` ≥ 3.11 | the harness scripts and the case generators (`tomllib`) |
| `rg`, `jq` | lookups and reading the gates' JSON lines |
| `cargo` (the original's pinned nightly) | **only** to rebuild the oracle binary from the pinned commit |

### The oracle

The original (`toon_rust` at `f955c67`, `toon 0.2.4`) is an **oracle to run, never a template to read while implementing**. It is symlinked at `legacy/Toon` (gitignored) and its release binary is snapshotted at `oracle/toon` (gitignored; sha256 in `docs/PIN.toml`). Rebuild it with the command in PLAN §2; do not substitute the `toon` on PATH, which is a different build.

### Skills

This port is driven by two skills, end to end: **porting-to-bend2** (the method: phases, gates, harness, claims) and **bend2-mega-skill** (the language, proofs, runtime, performance). Load both at session start; their RUNBOOK and "First 30 Seconds" tables say what to run for the phase `docs/PORT_STATE.md` names.

---

## Code Editing Discipline

### No Script-Based Changes

**NEVER** run a script that processes/changes code files in this repo. Brittle regex-based transformations create far more problems than they solve.

- **Always make code changes manually**, even when there are many instances
- For many simple changes: use parallel subagents
- For subtle/complex changes: do them methodically yourself

### No File Proliferation

If you want to change something or add a feature, **revise existing code files in place**.

**NEVER** create variations like:
- `mainV2.bend`
- `main_improved.bend`
- `encode_enhanced.bend`

New files are reserved for **genuinely new functionality** that makes zero sense to include in any existing file. The bar for creating new files is **incredibly high**.


### Generated files are regenerated, never edited

`goldens/cases.tsv`, `cases/hand-cases.tsv`, `cases/fixture-cases.tsv` and everything under `cases/inputs/` are outputs of `cases/build-cases.py`. Change a generator, run `python3 cases/build-cases.py`, then re-capture (`--repin "<reason>"`). `python3 cases/build-cases.py --check` must say `OK` before any commit.

---

## Backwards Compatibility

We do not care about backwards compatibility **of the port's own internals**—we're in early development with no users. We want to do things the **RIGHT** way with **NO TECH DEBT**.

- Never create "compatibility shims"
- Never create wrapper functions for deprecated APIs
- Just fix the code directly

**The one thing we are rigidly compatible with is the original's observable behavior.** Bug-compatibility is the default: stdout, stderr and the exit code match the pinned `toon` binary byte for byte, including its oddities (decoded integers print as `1.0`; JSON number input is not correctly rounded; the two JSON writers escape control characters differently). A deliberate divergence exists only as a `DISC-` entry in `docs/DISCREPANCIES.md` with a class, a kill-switch, the affected cases, a measured impact and the owner's approval. No silent fixes.

---

## Compiler Checks (CRITICAL)

**After any substantive code changes, you MUST verify no errors were introduced:**

```bash
export BEND_NO_TELEMETRY=1 BEND_CLI='bun /tmp/bend/bend2/main.ts'

# The proof gate: must print exactly "All terms check." (a "with N unsafe annotations" line is a partial green)
(cd port && $BEND_CLI PROOF.bend)

# Check every entry point without executing it
~/.claude/skills/bend2-mega-skill/scripts/bend-check.sh port

# Porting anti-patterns (quadratic ++, untagged defs, fast twins without a law, clock/random in the core, ...)
python3 scripts/port-lint.py port/*.bend --laws port/LAWS.bend

# Conformance on the fast lane while iterating, then every lane before a commit
./scripts/conform.sh goldens/cases.tsv goldens --lane interpreter -- $BEND_CLI port/main.bend --
./scripts/lanes.sh goldens/cases.tsv goldens port/main.bend --threads 8
```

If you see errors, **carefully understand and resolve each issue**. `~/.claude/skills/bend2-mega-skill/scripts/explain-error.sh` decodes a checker refusal; fix the first error only, then re-run. A refusal is usually a missing spec fact (an aliasing invariant, a loop bound, an unlisted error path): write the clause first, then reshape the code. Three identical errors on one def → write the OQ and move on.

---

## Testing

### Testing Policy

Tests here are **captured, never typed**. `goldens/<case>.out|.err|.exit` hold what the pinned original printed for each row of `goldens/cases.tsv`; the port passes a case when all three match byte for byte **on every lane** (interpreter, C at 1 thread, C at 8 threads, JS). A lane difference is a bug, never a tolerance. A missing golden, an unrunnable case or an empty manifest is a FAIL, never a skip.

Properties that hold for every input are **laws** in `port/LAWS.bend`, proved in `port/PROOF.bend`. A claim says which of the two it rests on.

### Running the gates

```bash
./scripts/port-doctor.sh --threads 8 --original ./oracle/toon --   # every gate, one table, GREEN or RED
./scripts/lanes.sh goldens/cases.tsv goldens port/main.bend --threads 8
./scripts/first-divergence.sh <case> goldens/cases.tsv goldens -- $BEND_CLI port/main.bend --   # one failing case: class + spec section
./scripts/floor.sh goldens/cases.tsv goldens --repeat 3 -- ./oracle/toon                        # the original vs itself
./scripts/law-coverage.sh                                                                       # laws <-> proofs <-> parity board
./scripts/law-mutation.sh port <defs...>                                                        # do the laws actually bite?
```

### Case Classes

| Prefix in `goldens/cases.tsv` | Focus Areas |
|-----------|-------------|
| `fx_enc_*`, `fx_dec_*` | the 349 vendored TOON spec fixtures (inputs and options only; their `expected` fields are the upstream TypeScript reference's and are **not** goldens) |
| `usage_*`, `flag_*`, `auto_*` | clap's usage surface, option spellings, mode auto-detection, `-o`, stdin |
| `stats_*` | `--stats` token estimates and the percent line |
| `encnum_*`, `decnum_*`, `decfmt_*` | number text in both directions: serde_json's float path, Rust `Display`, correctly rounded token parsing, zmij's JSON float text |
| `encstr_*`, `enc_*`, `decstr_*` | quoting, escapes, Unicode whitespace, keys, shapes, key folding |
| `jsonerr_*`, `jsonout_*` | serde_json's error messages with byte columns; the two JSON writers |
| `toonerr_*`, `toonlenient_*`, `toonedge_*` | decode errors, `--no-strict`, indent sizes |
| `large_*`, `determinism_*`, `happy_*` | performance inputs doubling as conformance, floor probes, README examples |

### Adding a case

A case is added by editing a generator (`cases/gen-hand-cases.py`), never the TSV, then `python3 cases/build-cases.py`, `./scripts/cases-lint.sh goldens/cases.tsv`, and a re-capture with `./scripts/golden-capture.sh … --repin "<reason>" -- ./oracle/toon`. Diff `goldens/MANIFEST.txt`: prior hashes must not change. **Never edit a file under `goldens/` by hand.**

---

## Third-Party Library Usage

There are no third-party Bend libraries in this port. For Bend itself, trust the live `bend guide`, `bend guide effects`, `bend base <Name>`, the repository at the pinned commit and the two papers over any dated note (including the skills' own). If you aren't 100% sure how a Base def behaves, **probe it**: write a ten-line `.bend` file in your scratch directory and run it on the interpreter and the C lane before relying on it.

---

## toon_bend — This Project

**This is the project you're working on.** toon_bend is a Bend 2 port of `toon_rust` (the `toon` CLI, itself a Rust port of the TOON reference implementation) — a human-readable, token-efficient serialization format for JSON data, optimized for LLM context windows. The port is built with the **porting-to-bend2** method: the original is pinned and run as an oracle, its behavior is written down as a numbered spec, and the Bend code is implemented from that spec and judged against captured goldens on every lane.

### What It Does

Converts between JSON and TOON formats, byte-for-byte the way the pinned `toon 0.2.4` binary does. TOON uses indentation-based structure (like YAML) with array length prefixes, tabular arrays and optional key folding to produce output that is more compact than JSON while remaining losslessly round-trippable.

### The two equivalences (never conflated)

1. **original == spec** is *golden-tested*: `goldens/` holds the original's captured stdout, stderr and exit code per case in `goldens/cases.tsv`; `scripts/lanes.sh` must pass on every lane (interpreter, C at 1 and N threads, JS). A failing case is a port bug or a spec gap, never a tolerance.
2. **spec == fast** is *law-proved*: every fast twin is bound to its spec twin in `port/LAWS.bend`, and `$BEND_CLI port/PROOF.bend` must print `All terms check.` The unsafe count from that output and `bend --version` are stated beside every parity or performance claim.

A claim says which equivalence it rests on. "Proved" means a law; "golden-tested" means the harness on named lanes; "measured" means an interleaved, cv-gated capture with a checksum. Nothing else is a claim.

### Architecture

```
JSON bytes → strict UTF-8 → JSON reader (pushdown machine, serde_json-compatible errors) → Json value
           → annotate (array strategy, key folding) → emit → TOON lines
TOON bytes → strict UTF-8 → lines → scanner → decoder (pushdown machine over lines) → events
           → streaming JSON writer            (plain --decode)
           → value builder → path expansion → second JSON writer   (--expand-paths safe)

Numbers: text ⇄ exact software binary64 (sign, exponent, 53-bit significand over big naturals).
Shell:   args, stdin/files as bytes, stdout/stderr, exit codes. It calls one core function and prints.
```

Three shapes are forced by Bend and are **design rules here, not accidents**:

- **No mutual recursion, no mutually recursive types.** A JSON value is ONE self-recursive `Data` type whose child chains are its own constructors; every traversal of it is a single structurally recursive def. Helpers take verdicts and already-recursed results; the recursion stays in the caller.
- **Pushdown machines for parsers.** The JSON reader and the TOON decoder are single defs over (input, explicit stack): each step consumes input, or leaves it unchanged and pops a frame — the lexicographic measure the checker accepts.
- **Every input-length traversal is tail-recursive** (accumulate reversed, reverse once). The JS and interpreter lanes die near 3×10⁴ nested frames; only nesting depth may recurse naturally.

### Project Structure

```
toon_bend/
├── AGENTS.md                      # this file
├── README.md
├── port.env                       # knobs for scripts/port.sh (ORIGINAL, THREADS, SWITCH, PROBE, PIN)
├── port/
│   ├── main.bend                  # IO shell: args, bytes in, lines out, exit codes (imports the core)
│   ├── cli.bend                   # pure argv model: clap-compatible parsing, help/version text, mode detection, --stats
│   ├── text.bend                  # strict UTF-8, Unicode White_Space / Cc tables, trim, tail-recursive list and string tools
│   ├── bignat.bend                # big naturals over 16-bit limbs in U32
│   ├── f64.bend                   # software binary64: u64→f64, ×/÷ by powers of ten, correctly rounded decimal→f64, shortest digits, both printers
│   ├── json.bend                  # the Json value type, the JSON reader, the two JSON writers
│   ├── encode.bend                # TOON encoder: quoting, headers, array strategy, list items, key folding
│   ├── decode.bend                # TOON decoder: scanner, header parser, event machine, value builder, path expansion
│   ├── LAWS.bend                  # the laws (human-owned: add, never weaken or delete)
│   └── PROOF.bend                 # their proofs; `bend PROOF.bend` is the gate
├── docs/
│   ├── PORT_STATE.md              # READ FIRST on resume: phase, pasted gate lines, open items, next action
│   ├── PLAN_TO_PORT_Toon_TO_BEND2.md   # pins (original §2, Bend §2b), scope and classed exclusions, risks
│   ├── EXISTING_Toon_STRUCTURE.md # THE SPEC: numbered clauses S1–S12 with provenance and cases
│   ├── PROPOSED_ARCHITECTURE.md   # core/shell split, module map, loop measures, order carriers, seam
│   ├── NUMERIC_PLAN.md            # one row per numeric quantity; the encoding contract
│   ├── FEATURE_PARITY.md          # the parity board (present / partial / missing / excluded)
│   ├── DISCREPANCIES.md           # every divergence (DISC) and the bug-compat candidates
│   ├── OPEN_QUESTIONS.md          # spec gaps, each resolved by RUNNING the original
│   ├── PIN.toml                   # the pins as data (scripts/pin-check.sh)
│   └── spec-parts/                # the extractors' part files behind the spec
├── cases/
│   ├── build-cases.py             # regenerates inputs and assembles goldens/cases.tsv
│   ├── gen-hand-cases.py          # the hand-designed cases
│   ├── gen-fixture-cases.py       # cases from the vendored spec fixtures
│   ├── fixtures/spec/             # vendored TOON spec fixtures (toon-format/spec)
│   └── inputs/                    # generated stdin bytes and input files
├── goldens/                       # cases.tsv (generated) + captured .out/.err/.exit + MANIFEST.txt — NEVER edit by hand
├── perf/                          # PERF-LEDGER.md (wins), NEGATIVE-EVIDENCE.md (graveyard), EXPERIMENTS.md (cards)
├── scripts/                       # the porting harness (capture, floor, conform, lanes, doctor, lints, bench)
├── legacy/Toon -> /dp/toon_rust   # the original (gitignored): an oracle, never a template
└── oracle/toon                    # the pinned release binary (gitignored; sha256 in docs/PIN.toml)
```

### Key Files Quick Reference

| File | Purpose |
|------|---------|
| `docs/PORT_STATE.md` | where the port is, the last gate lines verbatim, the one next action |
| `docs/EXISTING_Toon_STRUCTURE.md` | the spec every def, law, board row and DISC cites by clause number |
| `port/main.bend` | the only file with `IO` in its types; a chain of small shell defs |
| `port/json.bend` | `Json` (one self-recursive type), reader with serde_json's messages and byte columns, both writers |
| `port/f64.bend` | the number substrate; where serde_json's non-round-trip float path is reproduced step by step |
| `port/encode.bend` | value → TOON lines: annotate (strategy, folding), then emit |
| `port/decode.bend` | TOON lines → events → value; strict validation; safe path expansion |
| `port/LAWS.bend` / `port/PROOF.bend` | what is proved, and the gate |
| `goldens/cases.tsv` / `goldens/MANIFEST.txt` | the corpus and the capture's provenance and hashes |
| `cases/gen-hand-cases.py` | where a new case is written |

### Gates (paste their last lines into PORT_STATE; never paraphrase)

| gate | command |
|---|---|
| everything at once | `./scripts/port-doctor.sh --threads 8 --original ./oracle/toon -- --switch TOON_SPEC=1 --probe '["--encode","cases/inputs/hand/large_tabular_1500.json"]'` (proof, lanes, board, floor, kill-switch parity; last line JSON, verdict GREEN or RED) |
| one failing case | `./scripts/first-divergence.sh <case> goldens/cases.tsv goldens -- <port command>` (the divergence class and the spec section to read) |
| convergence | `./scripts/converge.sh docs/PORT_STATE.md` (computed from the rounds table and the OQ/DISC registers; T2: ≥ 5 rounds, last 2 clean, ≥ 1 non-author round) |
| the pins | `./scripts/pin-check.sh docs/PIN.toml` |
| the state file | `./scripts/state-check.sh docs/PORT_STATE.md` before ending a session (no placeholders, gate lines pasted, one executable next action) |
| the words | `./scripts/claims-lint.sh docs/*.md perf/*.md README.md` before committing any claim |

### Core Types Quick Reference

| Type | Purpose |
|------|---------|
| `Json` | ONE self-recursive Data type: null, bool, number, string, array, object, plus the item and entry chains as its own constructors; objects keep insertion order |
| `F64` | a software binary64: sign, exponent, significand as a `BigNat`; zero and the specials named explicitly |
| `BigNat` | little-endian 16-bit limbs in `U32`, no high zero limb |
| `Event` | the decoder's stream: start/end object, start/end array with its declared length, key (with `was_quoted`), primitive |
| `Line` | a scanned TOON line: number, indent, depth, content |
| `Opts` | the resolved options: mode, indent 0–16, delimiter, key folding, flatten depth, strict, expand paths, stats, input, output |
| `Outcome`-style verdicts | every failure is a value carried to the shell, which owns the one `IO.die` per verdict type |

### Project Semantics (hard rules)

- **The original is a behavior oracle, not a template.** Implementation reads `docs/EXISTING_Toon_STRUCTURE.md`. A spec gap is an `OQ-` entry in `docs/OPEN_QUESTIONS.md`, resolved by *running* the original on a new case and capturing it, then amending the spec. Never open `legacy/` while implementing.
- **Goldens are captured, never typed or edited.** Re-capture only when the contract changes (a new original commit, or an accepted `DISC-`), never to make a red case green. Every re-capture diffs `MANIFEST.txt`.
- **Spec twin first.** Literal and sequential. Fast twins come only in Phase 5, each with a `{fast == spec}` law, behind the `TOON_SPEC=1` kill-switch read once in the shell.
- **`port/LAWS.bend` is human-owned:** add laws, never weaken or delete one. A law the checker cannot prove is a finding about the code or the spec.
- **Every def carries its clause tag** (`# S<n>.<m>`) on the line above it.
- **Numbers are exact.** No `F32` anywhere near an output. The numeric plan is written before any arithmetic def.
- **Before any performance lever:** sweep `perf/NEGATIVE-EVIDENCE.md` (`rg -i '<lever>' perf/`) and honor the retry predicate; write the experiment card in `perf/EXPERIMENTS.md` **before** the lever; capture with the cv gate and the A/A arm; a refused capture is `NO_EVIDENCE`. Every outcome, including losses, gets a ledger entry with a retry predicate. Forbidden in ledgers: "later", "if it seems important", "we should revisit", "tracked elsewhere".
- **A speedup number against the original** needs the incumbent contract in PLAN §2 (commit, toolchain, flags, threads) and `scripts/incumbent-bench.sh` with `--pin`; otherwise it is a maintenance number.
- **`docs/PORT_STATE.md` is rewritten at the end of every session** with the phase, the last gate outputs and one executable next action.

### What We're NOT Porting

- The `async-stream` feature (asupersync streaming) and the `wasm` bindings
- The `EncodeReplacer` library callback (no CLI spelling, so no golden can be captured for it)
- clap's "a similar argument exists" suggestion engine (the fixed usage errors ARE ported)
- Shell completions, `tracing` logs, build metadata
- Native Windows behavior

(See `docs/PLAN_TO_PORT_Toon_TO_BEND2.md` §3 for the classed exclusion table. An exclusion without a class is not an exclusion; it is a missing feature.)

### Output Style

- **stdout** is data only: TOON or JSON, exactly the original's bytes, always newline-terminated.
- **stderr** carries errors, the `Encoded`/`Decoded` success lines and the `--stats` lines, exactly the original's text. `IO.print_err` always appends a newline; every message here ends with one.
- **Exit codes:** 0 success, 1 conversion or I/O error, 2 usage error (clap's).
- **Runtime flags:** the compiled Bend binary consumes `--help`, `--threads N` and `--gpu X` when they come before `--`. The harness and the launcher pass `--` first (DISC-001, Platform).

### Key Design Decisions

- **One core, a thin shell** — everything decidable without an effect lives in the pure core; `main.bend` is the only file with `IO` in its types
- **One self-recursive `Json` type** — the only rose-tree shape Bend's termination checker accepts without fuel
- **Parsers are pushdown machines** with the measure (input, stack); no `@unsafe`, no fuel
- **Bytes in, lines out** — input is read as bytes and decoded strictly (the original rejects invalid UTF-8); JSON error columns are byte columns; output is written line by line
- **Software binary64** — Bend has no f64, and the goldens show three distinct number algorithms that must be matched bit for bit
- **Bug-compatible by default** — oddities are reproduced and listed for the owner, not fixed
- **No Base templates in the proved core** — keeps the verdict exactly `All terms check.`
- **No GPU lane** — text with data-dependent structure; no bang is placed, so `gpu` is MISSING with that reason

---

## MCP Agent Mail — Multi-Agent Coordination

A mail-like layer that lets coding agents coordinate asynchronously via MCP tools and resources. Provides identities, inbox/outbox, searchable threads, and advisory file reservations with human-auditable artifacts in Git.

### Why It's Useful

- **Prevents conflicts:** Explicit file reservations (leases) for files/globs
- **Token-efficient:** Messages stored in per-project archive, not in context
- **Quick reads:** `resource://inbox/...`, `resource://thread/...`

### Same Repository Workflow

1. **Register identity:**
   ```
   ensure_project(project_key=<abs-path>)
   register_agent(project_key, program, model)
   ```

2. **Reserve files before editing:**
   ```
   file_reservation_paths(project_key, agent_name, ["src/**"], ttl_seconds=3600, exclusive=true)
   ```

3. **Communicate with threads:**
   ```
   send_message(..., thread_id="FEAT-123")
   fetch_inbox(project_key, agent_name)
   acknowledge_message(project_key, agent_name, message_id)
   ```

4. **Quick reads:**
   ```
   resource://inbox/{Agent}?project=<abs-path>&limit=20
   resource://thread/{id}?project=<abs-path>&include_bodies=true
   ```

### Macros vs Granular Tools

- **Prefer macros for speed:** `macro_start_session`, `macro_prepare_thread`, `macro_file_reservation_cycle`, `macro_contact_handshake`
- **Use granular tools for control:** `register_agent`, `file_reservation_paths`, `send_message`, `fetch_inbox`, `acknowledge_message`

### Common Pitfalls

- `"from_agent not registered"`: Always `register_agent` in the correct `project_key` first
- `"FILE_RESERVATION_CONFLICT"`: Adjust patterns, wait for expiry, or use non-exclusive reservation
- **Auth errors:** If JWT+JWKS enabled, include bearer token with matching `kid`

---

## Beads (br) — Dependency-Aware Issue Tracking

Beads provides a lightweight, dependency-aware issue database and CLI (`br` - beads_rust) for selecting "ready work," setting priorities, and tracking status. It complements MCP Agent Mail's messaging and file reservations.

**Important:** `br` is non-invasive—it NEVER runs git commands automatically. You must manually commit changes after `br sync --flush-only`.

### Conventions

- **Single source of truth:** Beads for task status/priority/dependencies; Agent Mail for conversation and audit
- **Shared identifiers:** Use Beads issue ID (e.g., `br-123`) as Mail `thread_id` and prefix subjects with `[br-123]`
- **Reservations:** When starting a task, call `file_reservation_paths()` with the issue ID in `reason`

### Typical Agent Flow

1. **Pick ready work (Beads):**
   ```bash
   br ready --json  # Choose highest priority, no blockers
   ```

2. **Reserve edit surface (Mail):**
   ```
   file_reservation_paths(project_key, agent_name, ["src/**"], ttl_seconds=3600, exclusive=true, reason="br-123")
   ```

3. **Announce start (Mail):**
   ```
   send_message(..., thread_id="br-123", subject="[br-123] Start: <title>", ack_required=true)
   ```

4. **Work and update:** Reply in-thread with progress

5. **Complete and release:**
   ```bash
   br close 123 --reason "Completed"
   br sync --flush-only  # Export to JSONL (no git operations)
   ```
   ```
   release_file_reservations(project_key, agent_name, paths=["src/**"])
   ```
   Final Mail reply: `[br-123] Completed` with summary

### Mapping Cheat Sheet

| Concept | Value |
|---------|-------|
| Mail `thread_id` | `br-###` |
| Mail subject | `[br-###] ...` |
| File reservation `reason` | `br-###` |
| Commit messages | Include `br-###` for traceability |

---

## bv — Graph-Aware Triage Engine

bv is a graph-aware triage engine for Beads projects (`.beads/beads.jsonl`). It computes PageRank, betweenness, critical path, cycles, HITS, eigenvector, and k-core metrics deterministically.

**Scope boundary:** bv handles *what to work on* (triage, priority, planning). For agent-to-agent coordination (messaging, work claiming, file reservations), use MCP Agent Mail.

**CRITICAL: Use ONLY `--robot-*` flags. Bare `bv` launches an interactive TUI that blocks your session.**

### The Workflow: Start With Triage

**`bv --robot-triage` is your single entry point.** It returns:
- `quick_ref`: at-a-glance counts + top 3 picks
- `recommendations`: ranked actionable items with scores, reasons, unblock info
- `quick_wins`: low-effort high-impact items
- `blockers_to_clear`: items that unblock the most downstream work
- `project_health`: status/type/priority distributions, graph metrics
- `commands`: copy-paste shell commands for next steps

```bash
bv --robot-triage        # THE MEGA-COMMAND: start here
bv --robot-next          # Minimal: just the single top pick + claim command
```

### Command Reference

**Planning:**
| Command | Returns |
|---------|---------|
| `--robot-plan` | Parallel execution tracks with `unblocks` lists |
| `--robot-priority` | Priority misalignment detection with confidence |

**Graph Analysis:**
| Command | Returns |
|---------|---------|
| `--robot-insights` | Full metrics: PageRank, betweenness, HITS, eigenvector, critical path, cycles, k-core, articulation points, slack |
| `--robot-label-health` | Per-label health: `health_level`, `velocity_score`, `staleness`, `blocked_count` |
| `--robot-label-flow` | Cross-label dependency: `flow_matrix`, `dependencies`, `bottleneck_labels` |
| `--robot-label-attention [--attention-limit=N]` | Attention-ranked labels |

**History & Change Tracking:**
| Command | Returns |
|---------|---------|
| `--robot-history` | Bead-to-commit correlations |
| `--robot-diff --diff-since <ref>` | Changes since ref: new/closed/modified issues, cycles |

**Other:**
| Command | Returns |
|---------|---------|
| `--robot-burndown <sprint>` | Sprint burndown, scope changes, at-risk items |
| `--robot-forecast <id\|all>` | ETA predictions with dependency-aware scheduling |
| `--robot-alerts` | Stale issues, blocking cascades, priority mismatches |
| `--robot-suggest` | Hygiene: duplicates, missing deps, label suggestions |
| `--robot-graph [--graph-format=json\|dot\|mermaid]` | Dependency graph export |
| `--export-graph <file.html>` | Interactive HTML visualization |

### Scoping & Filtering

```bash
bv --robot-plan --label backend              # Scope to label's subgraph
bv --robot-insights --as-of HEAD~30          # Historical point-in-time
bv --recipe actionable --robot-plan          # Pre-filter: ready to work
bv --recipe high-impact --robot-triage       # Pre-filter: top PageRank
bv --robot-triage --robot-triage-by-track    # Group by parallel work streams
bv --robot-triage --robot-triage-by-label    # Group by domain
```

### Understanding Robot Output

**All robot JSON includes:**
- `data_hash` — Fingerprint of source beads.jsonl
- `status` — Per-metric state: `computed|approx|timeout|skipped` + elapsed ms
- `as_of` / `as_of_commit` — Present when using `--as-of`

**Two-phase analysis:**
- **Phase 1 (instant):** degree, topo sort, density
- **Phase 2 (async, 500ms timeout):** PageRank, betweenness, HITS, eigenvector, cycles

### jq Quick Reference

```bash
bv --robot-triage | jq '.quick_ref'                        # At-a-glance summary
bv --robot-triage | jq '.recommendations[0]'               # Top recommendation
bv --robot-plan | jq '.plan.summary.highest_impact'        # Best unblock target
bv --robot-insights | jq '.status'                         # Check metric readiness
bv --robot-insights | jq '.Cycles'                         # Circular deps (must fix!)
```

---

## UBS — Ultimate Bug Scanner

**Golden Rule:** `ubs <changed-files>` before every commit. Exit 0 = safe. Exit >0 = fix & re-run.

UBS has no Bend front end: it scans the harness (`scripts/*.sh`, `scripts/*.py`, `cases/*.py`). For `.bend` files the equivalent gate is `python3 scripts/port-lint.py port/*.bend --laws port/LAWS.bend`.

### Commands

```bash
ubs cases/gen-hand-cases.py scripts/conform.sh   # Specific files (< 1s) — USE THIS
ubs $(git diff --name-only --cached)             # Staged files — before commit
ubs --only=python,bash scripts/ cases/           # Language filter (3-5x faster)
ubs --ci --fail-on-warning .                     # CI mode — before PR
```

### Output Format

```
Warning  Category (N errors)
    file.py:42:5 - Issue description
    Suggested fix
Exit code: 1
```

Parse: `file:line:col` -> location | Suggested fix -> how to fix | Exit 0/1 -> pass/fail

### Fix Workflow

1. Read finding -> category + fix suggestion
2. Navigate `file:line:col` -> view context
3. Verify real issue (not false positive)
4. Fix root cause (not symptom)
5. Re-run `ubs <file>` -> exit 0
6. Commit

---

## RCH — Remote Compilation Helper

RCH offloads `cargo build`, `cargo test` and other compilation commands to the remote worker fleet. **In this project it matters for exactly one thing: rebuilding the oracle** from the pinned commit of the original (`cd legacy/Toon && cargo build --release`). The cargo shim is installed ahead of `~/.cargo/bin`, so the build is admitted automatically; never invoke cargo by absolute path, and never set `CARGO_TARGET_DIR` to a `/tmp` path.

Bend builds (`bend main.bend -o toon`) are a bun process plus one `clang` invocation and run locally; they take about a second.

Quick commands:
```bash
rch doctor                    # Health check
rch status                    # Overview of current state
rch queue                     # See active/waiting builds
```

---

## ast-grep vs ripgrep

**Use `ripgrep` for `.bend` files.** ast-grep has no Bend grammar, so structural search does not apply to the port itself; Bend's one-statement-per-line style makes line-based search reliable.

**Use `ast-grep` when structure matters in the harness** (Python, Bash, TypeScript under `scripts/` and `cases/`).

### Rule of Thumb

- `.bend` code, clause tags, law names, case names -> `rg`
- Refactoring a harness script -> `ast-grep`

### Bend Examples

```bash
# Every def that implements a clause group
rg -n -B1 '^def ' port/encode.bend | rg '# S4\.'

# Defs with no clause tag on the line above (must be empty)
python3 scripts/port-lint.py port/*.bend | rg PL-10

# Where a constructor is matched
rg -n 'case JArr\{' port/

# Any Base template in the proved core (must be empty)
rg -n '\(~' port/*.bend

# A case and the clauses that predict it
rg -n 'toonerr_blank_in_list' goldens/cases.tsv docs/EXISTING_Toon_STRUCTURE.md
```

---

## Morph Warp Grep — AI-Powered Code Search

**Use `mcp__morph-mcp__warp_grep` for exploratory "how does X work?" questions.** An AI agent expands your query, greps the codebase, reads relevant files, and returns precise line ranges with full context.

**Use `ripgrep` for targeted searches.** When you know exactly what you're looking for.

### When to Use What

| Scenario | Tool | Why |
|----------|------|-----|
| "How does the decoder machine handle list items?" | `warp_grep` | Exploratory; don't know where to start |
| "Where is key folding decided?" | `warp_grep` | Need to understand architecture |
| "Find all clauses citing `fx_dec_objects_07`" | `ripgrep` | Targeted literal search |
| "Find every `IO.die`" | `ripgrep` | Simple pattern |

### warp_grep Usage

```
mcp__morph-mcp__warp_grep(
  repoPath: "/data/projects/toon_bend",
  query: "How does the TOON decoder track indentation depth across list items?"
)
```

Returns structured results with file paths, line ranges, and extracted code snippets.

### Anti-Patterns

- **Don't** use `warp_grep` to find a specific def name -> use `ripgrep`
- **Don't** use `ripgrep` to understand "how does X work" -> wastes time with manual reads
- **Don't** point `warp_grep` at `legacy/` during implementation: the spec is the source, the original is an oracle

---

<!-- bv-agent-instructions-v1 -->

---

## Beads Workflow Integration

This project uses [beads_rust](https://github.com/Dicklesworthstone/beads_rust) (`br`) for issue tracking. Issues are stored in `.beads/` and tracked in git.

**Important:** `br` is non-invasive—it NEVER executes git commands. After `br sync --flush-only`, you must manually run `git add .beads/ && git commit`.

### Essential Commands

```bash
# View issues (launches TUI - avoid in automated sessions)
bv

# CLI commands for agents (use these instead)
br ready              # Show issues ready to work (no blockers)
br list --status=open # All open issues
br show <id>          # Full issue details with dependencies
br create --title="..." --type=task --priority=2
br update <id> --status=in_progress
br close <id> --reason "Completed"
br close <id1> <id2>  # Close multiple issues at once
br sync --flush-only  # Export to JSONL (NO git operations)
```

### Workflow Pattern

1. **Start**: Run `br ready` to find actionable work
2. **Claim**: Use `br update <id> --status=in_progress`
3. **Work**: Implement the task
4. **Complete**: Use `br close <id>`
5. **Sync**: Run `br sync --flush-only` then manually commit

### Key Concepts

- **Dependencies**: Issues can block other issues. `br ready` shows only unblocked work.
- **Priority**: P0=critical, P1=high, P2=medium, P3=low, P4=backlog (use numbers, not words)
- **Types**: task, bug, feature, epic, question, docs
- **Blocking**: `br dep add <issue> <depends-on>` to add dependencies

### Session Protocol

**Before ending any session, run this checklist:**

```bash
git status              # Check what changed
git add <files>         # Stage code changes
br sync --flush-only    # Export beads to JSONL
git add .beads/         # Stage beads changes
git commit -m "..."     # Commit everything together
git push                # Push to remote
```

### Best Practices

- Check `br ready` at session start to find available work
- Update status as you work (in_progress -> closed)
- Create new issues with `br create` when you discover tasks
- Use descriptive titles and set appropriate priority/type
- Always `br sync --flush-only && git add .beads/` before ending session

<!-- end-bv-agent-instructions -->

---

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - `./scripts/port-doctor.sh --threads 8 --original ./oracle/toon --`; paste its table
3. **Rewrite `docs/PORT_STATE.md`** - phase, pasted gate lines, open OQ/DISC/NE items, ONE executable next action; then `./scripts/state-check.sh docs/PORT_STATE.md`
4. **Lint the words** - `./scripts/claims-lint.sh docs/*.md perf/*.md README.md`
5. **Update issue status** - Close finished work, update in-progress items
6. **Sync beads** - `br sync --flush-only` to export to JSONL
7. **Commit** (and push when a remote is configured)
8. **Hand off** - Provide context for next session

Stopping early writes `STOPPED: <reason>. Resume with: <command>` as PORT_STATE's next action.

---

## cass — Cross-Agent Session Search

`cass` indexes prior agent conversations (Claude Code, Codex, Cursor, Gemini, ChatGPT, etc.) so we can reuse solved problems.

**Rules:** Never run bare `cass` (TUI). Always use `--robot` or `--json`.

### Examples

```bash
cass health
cass search "async runtime" --robot --limit 5
cass view /path/to/session.jsonl -n 42 --json
cass expand /path/to/session.jsonl -n 42 -C 3 --json
cass capabilities --json
cass robot-docs guide
```

### Tips

- Use `--fields minimal` for lean output
- Filter by agent with `--agent`
- Use `--days N` to limit to recent history

stdout is data-only, stderr is diagnostics; exit code 0 means success.

Treat cass as a way to avoid re-solving problems other agents already handled.

---

Note for Codex/GPT-5.2:

You constantly bother me and stop working with concerned questions that look similar to this:

```
Unexpected changes (need guidance)

- Working tree still shows edits I did not make in port/main.bend, port/encode.bend, docs/PORT_STATE.md, goldens/cases.tsv. Please advise whether to keep/commit/revert these before any further work. I did not touch them.

Next steps (pick one)

1. Decide how to handle the unrelated modified files above so we can resume cleanly.
```

NEVER EVER DO THAT AGAIN. The answer is literally ALWAYS the same: those are changes created by the potentially dozen of other agents working on the project at the same time. This is not only a common occurence, it happens multiple times PER MINUTE. The way to deal with it is simple: you NEVER, under ANY CIRCUMSTANCE, stash, revert, overwrite, or otherwise disturb in ANY way the work of other agents. Just treat those changes identically to changes that you yourself made. Just fool yourself into thinking YOU made the changes and simply don't recall it for some reason.

---

## Note on Built-in TODO Functionality

Also, if I ask you to explicitly use your built-in TODO functionality, don't complain about this and say you need to use beads. You can use built-in TODOs if I tell you specifically to do so. Always comply with such orders.
