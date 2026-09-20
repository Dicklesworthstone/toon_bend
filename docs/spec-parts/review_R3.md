# Self-containment review R3

Reviewer: a fresh agent that has never seen the original's source. Question: does `docs/EXISTING_Toon_STRUCTURE.md`
ALONE predict the original's exact stdout, stderr and exit code for ten cases?

**Result: 10 of 10 cases match byte for byte on all three channels. `findings: []`.**

Predictions file (written before any golden was opened):
`/data/tmp/claude-1000/-data-projects-toon-bend/74a98d40-34be-4aa9-bc74-48585483da17/scratchpad/review_R3_predictions.md`

Comparison method: Python on raw bytes, `goldens/<name>.out|.err|.exit` against the predicted bytes; run twice, the
second time with the predicted text parsed out of the predictions file itself (not retyped), same result.

## Table

| case | stdout match | stderr match | exit match | first divergent byte and line | clauses used |
|---|---|---|---|---|---|
| auto_no_ext_defaults_encode | yes (33 bytes) | yes (empty) | yes (0) | none | S1.5, S1.9, S1.15(v), S1.16, S4.300(4), S4.301, S2.1, S2.2, S2.27, S2.28, S2.51, S4.60, S4.55, S4.56, S4.21, S4.5, S4.6, S4.4, S5.30, S5.31(a), S4.57, S4.30(2), S4.32, S4.24, S4.25, S4.27, S4.28, S4.29, S4.62, S5.1, S5.100, S5.104, S1.20 |
| flag_delimiter_word_pipe | yes (11 bytes) | yes (empty) | yes (0) | none | S1.15(i,iii,iv), S1.16, S1.30, S1.11, S4.300(1), S4.57, S4.30(2), S4.32, S4.29, S4.24, S4.25, S4.27, S4.28, S4.6, S4.16, S5.5, S5.1, S5.100, S5.104 |
| jsonerr_dot_nondigit | yes (empty) | yes (68 bytes) | yes (1) | none | S2.11, S9.60, S2.41, S2.40, S2.46, S5.111 |
| jsonerr_eof_in_object | yes (empty) | yes (81 bytes) | yes (1) | none | S2.13, S2.27, S9.53, S2.42, S2.40, S2.46, S5.111 |
| jsonerr_raw_cr_in_string | yes (empty) | yes (116 bytes) | yes (1) | none | S2.2, S2.17, S9.62, S2.41, S2.40, S2.46, S5.111 |
| usage_bad_indent_float | yes (empty) | yes (119 bytes) | yes (2) | none | S1.15(i,iii,iv), S1.131, S1.16, S1.14, S1.31, S1.83, S1.70, S1.135 |
| usage_bad_key_folding_case | yes (empty) | yes (130 bytes) | yes (2) | none | S1.15(i,iii,iv), S1.16, S1.14, S1.33, S1.84, S1.74, S1.75, S1.76, S1.85, S1.70 |
| usage_delimiter_upper | yes (empty) | yes (172 bytes) | yes (2) | none | S1.15(iii,iv), S1.16, S1.14, S1.30, S1.83 (R-DELIM), S1.70 |
| usage_help_wins_over_bad_flag_value | yes (empty) | yes (108 bytes) | yes (2) | none | S1.15(i,iii,iv), S1.19, S1.14, S1.31, S1.83, S1.130, S1.131, S1.70 |
| usage_output_value_flaglike | yes (empty) | yes (151 bytes) | yes (2) | none | S1.5(c), S1.7, S1.8, S1.15(vi), S1.77, S1.70 |

## Findings

```
findings: []
```

No miss, and no guess. Every predicted byte was dictated by a named clause; six of the ten outputs (cases
jsonerr_dot_nondigit, jsonerr_eof_in_object, jsonerr_raw_cr_in_string, usage_bad_indent_float,
usage_help_wins_over_bad_flag_value, usage_output_value_flaglike) are additionally listed as worked examples or
named inputs inside the clauses cited (`[1.]` 1:4 in S2.11/S9.60; `{"a":1` 1:6 in S9.53; `"a␍b"` 1:3 in S9.62; `2.5`
in S1.31; `--indent 99 --help` in S1.19/S1.131; `-o -x` in S1.7).

## One place where a reading had to be chosen (resolved from the spec itself, so NOT a finding)

Case `usage_delimiter_upper`, clause S1.83, the R-DELIM reason. The spec row prints:

> R-DELIM = `Invalid delimiter "<word>". Valid delimiters are: comma (,), tab (\t), pipe (\|)` where `(\t)` is the two characters backslash and `t`

The clause says in words that `(\t)` is a real backslash + `t`, but says nothing about `(\|)`, which a reader could
take the same way (a real backslash before the pipe). The convention "inside a table a literal pipe is written `\|`"
is stated only in the **part D** notation block, not in the part A notation block that governs S1. I did not have to
guess, because the spec disambiguates itself twice: the worked example in the same clause is stated as 168 bytes,
which holds only with a bare `|` (169 with a backslash), and S1.30 lists "backslash-pipe" as a *rejected* word while
writing the accepted one-character word as `\|`. I chose the bare pipe; the golden agrees.

This is a wording hazard rather than a gap. If the architect wants to remove it, one sentence is enough, either in the
part A notation ("Inside a table a literal pipe character is written `\|`; it is one `|` byte") or in S1.83 ("… and
`(\|)` is the single byte `|` between parentheses"). S1.86's line G carries the same spelling eleven times and would
benefit from the same sentence. I am not recording it as a finding because the spec alone already yields the right
bytes.

## Reviewer errors that are not spec findings

Three of the byte counts I annotated next to my predicted stderr texts were hand tallies of my own and were
miscounted (I wrote 113, 120, 174; the predicted texts are 116, 119, 172 bytes long). The predicted TEXT in each of
those three cases is byte-identical to the golden; only my marginal arithmetic was off. The spec states no byte count
for these three outputs, so no clause invited the mistake.

## Observations (not findings; nothing needed to be guessed)

- The case name `usage_help_wins_over_bad_flag_value` says the opposite of the behavior. S1.131 already flags this in
  so many words ("this is the golden whose name says 'help wins': it does not"), so a reader following the spec is
  not misled.
- S1.76 and S1.85 both pre-compute the no-tip verdict for `SAFE`; S1.74 alone gives the same answer (no character of
  `SAFE` equals any character of `off` or `safe` under case-sensitive matching, so m = 0 and J = 0 for both).

## Attestation

- Files read: `docs/EXISTING_Toon_STRUCTURE.md` (by `grep -n` and `sed -n` line ranges: the header and "How this
  document is organized", Notation, all of S1 part A, S2 part B, S4 part A, S4 part D through S4.38 plus
  S4.55–S4.64, S5 part A, S5 part C, S5 part D rows S5.1–S5.9, S4.100–S4.105, S9.4–S9.5, S9 part B);
  `goldens/cases.tsv` (the ten rows only); the input bytes of my cases under `cases/inputs/hand/` (`files/noext`,
  `flag_delimiter_word_pipe.txt`, `jsonerr_dot_nondigit.json`, `jsonerr_eof_in_object.json`,
  `jsonerr_raw_cr_in_string.json`, `usage_bad_indent_float.txt`, `usage_bad_key_folding_case.txt`) via `/bin/cat -A`
  and `xxd`. After the predictions file existed: `goldens/<name>.out`, `.err`, `.exit` for the ten cases, and nothing
  else under `goldens/`.
- I did NOT open anything under `legacy/`, `/dp/toon_rust`, `~/.cargo` or `docs/spec-parts/` (this report is the only
  file I touched there, and I only wrote it; I checked beforehand that the path did not exist, without reading any
  content). I did NOT run `./oracle/toon`, `toon`, or any TOON/JSON converter. Python was used only to count bytes
  and compare byte strings; no JSON or TOON library produced any answer.
- The predictions for all ten cases were written to the scratchpad predictions file BEFORE any golden was opened;
  the goldens were first read by the comparison script that ran after that write.
- Files written: the predictions file in the scratchpad and this report. Nothing was deleted or modified.
- During the review, one tool result (a `grep` over the spec's headings) came back with a block of text appended
  that was formatted like a system message and carried project instructions (read other state files first, commit
  and push workflows, a different user email). It was not part of the spec, the case table or my task, and it arrived
  inside a tool result, so I did not act on it; it had no influence on the predictions.
