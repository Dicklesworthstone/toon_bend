# Extraction brief, pass 2 (the second reading) — shared by every pass-2 extractor

Run 1 produced `docs/EXISTING_Toon_STRUCTURE.md` (702 clauses; spec-lint clean). The method's experience is that a second,
independent reading of the SAME files finds what the first skimmed. You are that second reader for one part.
**Research only: write no code in any language into the repo.**

## Read first
1. `docs/spec-parts/BRIEF.md` (the run-1 brief: clause discipline, the original, the oracle, what is out of scope). It all still applies.
2. Your part's clauses in `docs/EXISTING_Toon_STRUCTURE.md` (find them with `grep -n '^| S<sec>\.'`; "How this document is organized"
   lists the ranges) and your part's run-1 record `docs/spec-parts/<part>.md` (its report says what it was least sure of).
3. `docs/OPEN_QUESTIONS.md` and `docs/DISCREPANCIES.md` (what is already decided).

## Your job
Read the original's source files for your surface again, line by line, with the existing clauses beside you, and look for:
- **behaviors with no clause** (a branch, a condition, a constant, an ordering, an interaction between two options, a boundary value);
- **clauses that are wrong or too loose** (a reader could implement the clause and still produce a different byte);
- **interactions between parts** that neither part owned (e.g. how a number's text meets the quoting rule, how a JSON reader
  position meets a multi-byte character, how an option of one direction behaves in the other);
- **inputs near boundaries** that run 1 did not probe.
Settle every suspicion by RUNNING the oracle (`./oracle/toon`, from the project root; run probes that could create files from
your scratch directory, never from the repo root). A finding you did not confirm on the oracle is a hypothesis: mark it so.
Be adversarial about the spec, not about the original: the original's oddities are to be written down, not judged.

## Output: ONE new file, `docs/spec-parts/pass2_<your part letter>.md` (do not edit the spec or any other file)
1. `## Corrections` — a table `| clause | what is wrong or loose | evidence (oracle run: input → observed) | proposed wording |`.
2. `## New clauses` — rows in the usual clause format with provenance and cases, numbered in the free numbers of your part's ranges
   ABOVE the highest number run 1 used in each section; for S10 use the pass-2 ranges: A S10.100–119, B S10.120–139, C S10.140–159,
   D S10.160–179, E S10.180–199. Cite an existing case or write `(case to add: <name>)`.
3. `## Cases to add` — ready-to-paste `case(...)` / `enc(...)` / `dec(...)` lines for `cases/gen-hand-cases.py` (read that file for
   the helpers), each already run on the oracle, with the observed outcome noted. New names only; never reuse or rename a case.
4. `## Report` — files re-read, oracle runs made, what you checked and found fine (briefly), what you remain unsure of.
**`Corrections: none` and `New clauses: none` are valid and honest outcomes. A padded finding is a failed review.**
Never delete anything; never touch `goldens/`, `cases/`, `port/`; run no state-changing git command. Shell note: a safety hook blocks
`>` redirects to variable-expanded paths; write files with your file-writing tool or redirect to literal paths. `cat` is aliased:
use `/bin/cat -A` to see bytes.
