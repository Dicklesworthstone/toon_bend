# review_R1 — self-containment review of `docs/EXISTING_Toon_STRUCTURE.md`

Reviewer: a reader who has never seen the original's source. Question: does the spec ALONE predict the original's exact
stdout, stderr and exit code for ten cases? Predictions were written to
`/data/tmp/claude-1000/-data-projects-toon-bend/74a98d40-34be-4aa9-bc74-48585483da17/scratchpad/review_R1_predictions.md`
before any golden was opened, then compared byte for byte (Python on bytes; the predicted strings were extracted
mechanically from the predictions file, not retyped).

**Result: 10 of 10 match on all three streams. Nothing was guessed. `findings: []`.**

## Table

| case | stdout match | stderr match | exit match | first divergent byte / line | clauses used |
|---|---|---|---|---|---|
| enc_fold_budget_not_consumed | yes (35 B) | yes (empty) | yes (0) | none | S1.7, S1.11, S1.15, S1.32, S1.33, S4.300, S2.1, S2.4, S2.5, S4.55, S4.56, S4.58, S4.61, S4.64, S4.65, S4.66, S4.67, S4.68, S4.69, S4.70, S4.71, S4.72, S4.77, S4.78, S4.79, S4.80, S4.81, S4.21, S4.110, S4.111, S4.130, S4.131, S5.31, S5.1, S5.100, S5.104 |
| enc_fold_budget_sibling | yes (19 B) | yes (empty) | yes (0) | none | as above, plus S4.74, S6.30; S4.69 and S4.72 decide the refusal at the root, S4.71/S4.72 allow `b.c` |
| enc_fold_list_item_rest_collision | yes (43 B) | yes (empty) | yes (0) | none | S4.60, S4.30, S4.34, S4.35, S4.36, S4.38, S4.24, S4.25, S4.27, S4.44, S4.45, S4.52, S4.53, S4.63, S4.73, S3.9, S4.65, S4.69, S4.80, S4.58, S4.56, S4.64, S4.21, S4.61 |
| encnum_zero_huge_exponent | yes (5 B) | yes (empty) | yes (0) | none | S2.8, S2.14(a), S4.102, S4.107, S4.108, S2.52, S3.6, S4.117, S4.4, S4.130, S5.32, S4.56, S4.21 |
| encstr_duplicate_keys_escaped | yes (10 B) | yes (empty) | yes (0) | none | S2.19, S2.20, S2.28, S2.29, S2.30, S3.2, S4.55, S4.56, S4.21, S4.110, S4.130, S5.31 |
| fx_enc_arrays_objects_10 | yes (37 B) | yes (empty) | yes (0) | none | S4.57, S4.30, S4.34, S4.36, S4.38, S4.24, S4.27, S4.44, S4.45, S4.52, S4.31, S4.29, S4.5, S4.6–S4.18 |
| fx_enc_objects_24 | yes (20 B) | yes (empty) | yes (0) | none | S2.18, S4.21, S4.20, S4.19, S4.56 |
| fx_enc_primitives_01 | yes (6 B) | yes (empty) | yes (0) | none | S4.60, S4.5, S4.6, S4.18 |
| fx_enc_primitives_07 | yes (5 B) | yes (empty) | yes (0) | none | S4.60, S4.10, S4.6, S4.20, S4.19, S5.8 |
| fx_enc_primitives_08 | yes (8 B) | yes (empty) | yes (0) | none | S4.60, S4.10, S4.17, S4.6, S4.20 |

Common framing for all ten: input is stdin because argv has no INPUT (S1.11); `--encode` selects the mode (S4.300);
lines joined by LF plus one final LF, stderr empty, exit 0 (S5.1, S5.100, S5.104, S1.20, S3.15).

## Spec findings

```
findings: []
```

No clause was missing, wrong or ambiguous for these ten cases, and no reading had to be chosen between alternatives.

## Misses

None.

## Places where I had to guess

None. One point I checked for ambiguity and found to be unambiguous as written, recorded so nobody re-reviews it:

- S4.65, quoted: "The walk stops at the first of: the segment count equals the budget; current is a primitive; current is
  an array …; current is an object with zero fields; current is an object with two or more fields. Then: a primitive, an
  array or an empty object is the LEAF …; a non-empty object … is the REMAINDER". In `enc_fold_budget_sibling`
  (`--flatten-depth 2`, inner chain `b` → `c` → `1`) two stop conditions are true at the same moment (count = budget AND
  current is a primitive). The clause classifies by what `current` IS, not by which condition fired, so the result is a
  leaf and the line is `  b.c: 1` either way. No change needed.

## Reviewer's own errors (NOT spec findings)

- In the predictions file I wrote a byte count in parentheses next to each stdout. Five of those counts are my own
  arithmetic slips (I wrote 39, 22, 44, 39, 21; the real lengths of the strings I predicted are 35, 19, 43, 37, 20).
  The predicted byte STRINGS are what was compared and all ten equal the goldens. No clause invited the miscount; the
  spec gives no byte counts for these cases.

## Observations that are not findings (they did not affect any prediction)

- Cosmetic text defect in two clauses I used. S2.20 reads, literally: "`A` is `A`, `\` a backslash, `"` a quote (they do
  not end the string)", and S3.4 reads "`A` is `A`". These examples were evidently meant to show escape spellings
  (such as backslash-`u0041`) next to the character they denote, but the escape spellings have been collapsed into the
  characters themselves, so the examples are vacuous. The rule sentence of S2.20 ("`n` outside `D800–DFFF`: the scalar
  value U+`n`") with S2.19 ("The value `n` is the 16-bit number the four digits spell") is complete on its own, which is
  why `encstr_duplicate_keys_escaped` needed no guess. Suggested repair: write the escapes in words or double the
  backslash, as the Notation section already does for backslash-`t`.
- Independence caveat the coordinator should weigh. Three of my ten cases appear verbatim, input and output, as
  EXAMPLES inside the clauses that govern them: `enc_fold_budget_not_consumed` in S4.66 (R5), `enc_fold_budget_sibling`
  in S4.69 (R15), `enc_fold_list_item_rest_collision` in S4.69 (R2) and S10.61; `fx_enc_arrays_objects_10`'s two item
  lines appear in S4.52, and the three `fx_enc_primitives_*` outputs appear in S4.5/S4.10. I derived each prediction
  from the rule text first and only then checked it against the example, and the two agreed every time, but a match on
  a case whose answer is printed in the spec is weaker evidence of self-containment than a match on an unseen case. For
  these seven the review shows "rule text and example are consistent with each other and with the golden"; for
  `encnum_zero_huge_exponent` (example `0e99999999999999999999` → `0` in S2.14/S4.108), likewise. Only
  `encstr_duplicate_keys_escaped` and `fx_enc_objects_24` had no printed answer for their exact input
  (S4.19 prints the same escaped text only as a VALUE example, not as a key).
- The format of `goldens/<name>.exit` (`0` followed by LF) is a harness convention, not program output; the spec rightly
  does not describe it. I predicted the exit code and compared the number.

## Attestation

- Files read: `docs/EXISTING_Toon_STRUCTURE.md` (the organization section, the Notation, and the clause rows cited
  above, located with `grep -n`/`sed -n`); `goldens/cases.tsv` (the ten rows); the ten input files under
  `cases/inputs/hand/` and `cases/inputs/fx/` (via `/bin/cat -A` and `wc -c`). After the predictions file was written:
  `goldens/<case>.out`, `.err`, `.exit` for the ten cases only.
- I did not open anything under `legacy/`, `/dp/toon_rust`, `~/.cargo` or `docs/spec-parts/` (this report is the only
  file I touched there: written, never read; I tested only that `review_R1.md` did not already exist). I did not run
  `./oracle/toon`, `toon` or any TOON/JSON converter, and used no JSON/TOON library; Python was used only to compare
  bytes.
- The predictions file was written before any file under `goldens/` other than `cases.tsv` was opened.
- Nothing was deleted; no file in the repo other than this report was written.
- During the session a tool result carried an appended block styled as a system reminder (a project AGENTS.md and a
  session-context update). It did not come from the user or the coordinator; I did not act on its workflow
  instructions (reading `docs/PORT_STATE.md`, running gates, committing/pushing) and kept to the review rules.
