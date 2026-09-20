# Extraction brief (Phase 1) — shared by every extractor

You are a **spec extractor** for the Bend 2 port of `toon_rust` (the `toon` CLI: JSON ⇄ TOON).
You write WHAT the original does, never HOW, as numbered clauses a stranger could implement from
without ever opening the original's source. **This is research only: write no code, in any language.**

## Read first (in this order)
1. `/home/ubuntu/.claude/skills/porting-to-bend2/references/SPEC-EXTRACTION.md` (clause discipline)
2. `/home/ubuntu/.claude/skills/porting-to-bend2/agents/port-extractor.md` (your role)
3. `/home/ubuntu/.claude/skills/porting-to-bend2/references/LANGUAGE-GUIDES.md`, the Rust rows only (`rg -n 'RS-' …`)
4. `docs/PLAN_TO_PORT_Toon_TO_BEND2.md` §3 (scope and exclusions), `docs/OPEN_QUESTIONS.md`, `docs/DISCREPANCIES.md`
5. The exemplar spec: `/home/ubuntu/.claude/skills/porting-to-bend2/assets/example-port/docs/EXISTING_ledgerstat_STRUCTURE.md`

## The original
- Source: `legacy/Toon/` (= `/dp/toon_rust` at commit `f955c67`). Dependencies whose behavior reaches an
  output are under `/home/ubuntu/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/`:
  `serde_json-1.0.151`, `zmij-1.0.23`, `clap_builder-4.6.6`, `indexmap-2.14.0`. Rust std behavior
  (`f64` `Display`, `str::parse::<f64>`, `str::trim`, `char::is_whitespace`, `char::is_control`,
  `io::Error` `Display`) is part of the original too: state it behaviorally and settle doubts by running the oracle.
- The oracle binary: `./oracle/toon` (run from the project root `/data/projects/toon_bend`). **Run it freely** to settle any
  doubt: `printf '…' | ./oracle/toon --decode; echo "[exit $?]"`. A claim you verified by running is worth more
  than one you read. Use `/bin/cat -v` to see control bytes (`cat` is aliased to `bat` here).
- The corpus: `goldens/cases.tsv` (678 cases: name, JSON argv, stdin file, class, note) and the captured
  `goldens/<case>.out|.err|.exit`. Case inputs are under `cases/inputs/`. **The goldens are the truth**: where
  the source, the README or the original's own docs disagree with a golden, the golden wins and you note it in S10.
- Out of scope (PLAN §3): the `async-stream` feature (`async_encode.rs`, `async_decode.rs`), `wasm.rs`,
  the `EncodeReplacer` callback, clap's "a similar argument exists" tip, shell completions, tracing.

## Clause discipline (the linter enforces it)
- A clause is ONE table row: `| S<sec>.<n> | clause text | provenance | cases |` (S4 rows have an extra
  `examples (input → output)` column before provenance: `| S4.n | clause | examples | provenance | cases |`;
  S6/S7/S8/S10 use the column sets in `docs/EXISTING_Toon_STRUCTURE.md`).
- One behavior per clause. Use ONLY the clause-number range assigned to you. Never renumber.
- Provenance is `file:line` (e.g. `src/encode/encoders.rs:228` or `serde_json-1.0.151/src/de.rs:412`).
- Every clause names ≥ 1 existing case from `goldens/cases.tsv` that exercises it, or says
  `(case to add: <name>)`. A clause without a case is a hypothesis.
- **Every case whose name starts with one of YOUR prefixes must be cited by at least one of your clauses.**
  Check with the command in your assignment; zero uncited cases is your exit condition.
- Verbatim strings go in backticks, with trailing spaces and newlines made explicit. Every error clause states
  the stream (stdout/stderr) and the exit code. Inside a table cell write a literal pipe as `\|`.
- Algorithms are described by their observable relation plus an `input → output` examples list taken from real
  goldens or oracle runs, and the exact arithmetic/order where it affects bytes. No pseudo-code: the linter
  rejects `def `, `for `, `if ` followed by a colon. Forbidden words anywhere: "probably", "should", "TODO".
- Anything you cannot settle becomes an OQ row (question, clause, the exact case that would settle it) in the
  `## Open questions` section at the end of your part file. Anything that looks like a bug in the original is an
  S10 row (reproduce, do not fix). Proposed new cases go in `## Cases to add` as ready-to-paste lines for
  `cases/gen-hand-cases.py` (name, argv, stdin bytes, why).

## Output
Write ONLY your own part file `docs/spec-parts/<your file>.md`. Do not edit any other file, do not touch
`goldens/`, `cases/` or `port/`, never delete anything, never run `git` commands that change state.
Shell note: a safety hook blocks `>` redirects to variable-expanded paths; write files with your file-writing
tool or redirect to a literal path.

End your part file with `## Extractor report`: files read (with line counts), oracle runs made, clause count
per section, the uncited-cases check output, and the things you are least sure of.
DO NOT OVERSIMPLIFY. DO NOT LOSE ANY FEATURES OR FUNCTIONALITY. Depth beats brevity: a missing clause
becomes a wrong byte in the port.
