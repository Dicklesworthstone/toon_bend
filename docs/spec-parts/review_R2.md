# review_R2 — self-containment review of `docs/EXISTING_Toon_STRUCTURE.md`

Reviewer: R2 (never saw the original's source; spec-only). Date: 2026-09-20.
Question: does the spec ALONE predict the original's exact stdout, stderr and exit code for ten cases?

**Result: 10 of 10 cases match byte for byte on all three channels. `findings: []`.**

Predictions file (written before any golden was opened, mtime 02:33:47 EDT):
`/data/tmp/claude-1000/-data-projects-toon-bend/74a98d40-34be-4aa9-bc74-48585483da17/scratchpad/review_R2_predictions.md`

## Table

| case | stdout | stderr | exit | first divergent byte / line | clauses used |
|---|---|---|---|---|---|
| decnum_exact_halfway | match (104 B) | match (0 B) | match (0) | none | S4.204, S4.205, S2.126, S2.124, S4.141, S4.143, S4.131, S4.172, S4.173, S5.37, S5.38, S5.59, S5.51, S5.104 |
| decnum_root | match (10 B) | match (0 B) | match (0) | none | S4.203, S4.141, S4.146, S4.173, S5.37, S5.55, S5.51 |
| fx_dec_arrays_nested_12 | match (77 B) | match (0 B) | match (0) | none | S4.204, S4.205, S2.130–S2.135, S4.210, S4.215, S2.140, S4.222, S4.211, S4.170, S5.58–S5.60 |
| fx_dec_arrays_primitive_12 | match (51 B) | match (0 B) | match (0) | none | S4.202, S4.203 (root rule), S2.120, S2.130–S2.135, S2.122, S2.138, S2.125, S4.211, S5.58, S5.59 |
| fx_dec_arrays_primitive_13 | match (21 B) | match (0 B) | match (0) | none | S4.203 (root rule), S2.130–S2.135, S4.210, S4.216, S5.56, S5.59 |
| fx_dec_blank_lines_12 | match (122 B) | match (0 B) | match (0) | none | S2.105, S4.210, S4.212, S4.213 (strict-only), S2.125, S5.58–S5.60 |
| jsonout_expand_indent_1 | match (0 B) | match (35 B) | match (1) | none | S2.101, S2.107, S2.110, S4.206, S4.205, S4.216, S4.212, S4.213(1), S9.110, S4.249, S5.52, S5.53, S9.3 |
| jsonout_root_empty_doc_expand | match (3 B) | match (0 B) | match (0) | none | S2.102, S4.201, S9.21, S4.240, S5.50, S5.56, S5.51 |
| toonedge_expand_segments_253 | match (130299 B) | match (0 B) | match (0) | none | S4.241, S4.243, S4.248, S5.50, S5.59, S5.60, S5.73, S5.77, S4.170 |
| toonerr_header_brace_after_colon | match (27 B) | match (0 B) | match (0) | none | S4.203, S4.204, S2.130–S2.132, S2.135, S2.138, S2.124(5), S4.211, S5.58, S5.59, S5.63 |

Comparison method: the predicted bytes were rebuilt in memory from the predictions file (case 9 from its stated
generator: 507 lines) and compared with `goldens/<name>.out`, `.err`, `.exit` as byte strings in Python
(no JSON or TOON library involved anywhere; number values were checked with exact rational arithmetic only).

## Findings

`findings: []`

No miss, and no place where I had to choose between two readings of a clause. Nothing to report as
"spec wrong / silent", and nothing as "clause misapplied".

## Notes (not findings; no spec change requested)

- Strength of the test per case. For three of the ten cases the spec states the outcome outright, so they test
  the spec's consistency more than its derivability: S5.53 names `jsonout_expand_indent_1` and its message;
  S4.248 says a root-level dotted key "is accepted up to 253 segments"; S2.132 quotes the input `k[1]: {a}` with
  its value. I derived each independently as well (S4.206 over-indented block -> row depth 3 vs rows at depth 4 ->
  0 rows -> S9.110; counter c+n+2 = 255 < 256; B after C -> no fields segment) and the derivations agree with the
  stated outcomes. The other seven cases were derived from general clauses only.
- The over-indent rule was load-bearing in `jsonout_expand_indent_1`: with I = 1 the children of `o:` sit at
  depth 2, and only S4.206's "the first unread line fixes the sibling depth D" lets the decode reach the `t[2]{x,y}:`
  line at all. The clause is explicit and the prediction was right; mentioned because a reader who skipped S4.206
  would expect a different failure point.
- The numeric cases needed S4.131's closed-interval detail (end points belong to the interval when m is even):
  for 2^53 both `9007199254740992` and `9007199254740993` are 16-digit decimals inside the interval, and the
  "nearest to v" sentence of S4.131 is what selects `…992`. The clause covers it.

## Attestation

- Files read: `docs/EXISTING_Toon_STRUCTURE.md` (sections: header and "How this document is organized", Notation,
  S1 part A incl. S1.150–S1.155, S2 part E, S3 part E, S4 part A, S4 part C subsections B/C/D/E/F, S4 part E,
  S5 parts A/B/C, one row each of S6.45, S10.32, S10.43, S9 part A, S9 part E, S10 part E);
  `goldens/cases.tsv` (the ten rows); the ten input files under `cases/inputs/hand/` and `cases/inputs/fx/`;
  and, only in step 2, the thirty files `goldens/<case>.out|.err|.exit` of my ten cases.
- I did not open anything under `legacy/`, `/dp/toon_rust`, `~/.cargo`, or any existing file under
  `docs/spec-parts/` (this report is the only file I touched there; I tested only whether its own path existed).
  I did not run `./oracle/toon`, `toon`, or any TOON/JSON converter, and used no JSON/TOON library.
- The predictions file was written (02:33:47 EDT) before any golden output file was opened; the first read of
  any `goldens/*.out|.err|.exit` happened after that, in the comparison step.
- Files written: the predictions file in the scratchpad and this report. Nothing was deleted or modified.
