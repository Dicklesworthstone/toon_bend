# Pass 2, part X — the seams BETWEEN the surfaces (cross-surface second reading)

Reader X owns no surface. Target: behavior that falls between parts A–E and boundaries the corpus never reaches.
Method: (1) three throw-away models written from the SPEC CLAUSES (not from the source): the whole decode pipeline
(scanner → structural decoder → value tree → path expansion → both JSON writers → number text), the encoder
(quoting, array strategy, list items, key folding with budget, root-literal set and sibling check) and the expansion
counter; (2) differential runs of those models against `./oracle/toon` on random, mutated and boundary documents;
(3) round-trip fuzzing encode → decode with matching options; (4) hand probes of option, framing, size and
error-precedence crossings. Every statement below marked [run] was observed on the oracle in this pass.

**Headline: the run-1 spec predicted every one of about 150,000 oracle runs.** No clause was found WRONG. Two clauses are
LOOSE in a way that lets a careful implementer produce a different byte (both at a crossing of two surfaces), one
round-trip break class is unrecorded, and four multi-path clauses are pinned by the corpus on one path only.

## Corrections

| clause | what is wrong or loose | evidence (oracle run: input → observed) | proposed wording |
|---|---|---|---|
| S9.15 (and the same sentence in S10.3) | Loose across directions. "With `--stats` every failed write is reported" carries no mode. In DECODE mode `--stats` is ignored (S1.153, S4.318), the output still goes through the 8192-byte buffered path, and a small failed write is LOST. S8.12 says it correctly ("with `--stats` (encode)"); S9.15 and S10.3 read alone predict exit 1 here. | [run] `printf 'a: 1\n' \| toon -d --stats -o /dev/full` → stdout empty, stderr ``Decoded `stdin` → `/dev/full`\n``, exit 0. [run] the encode twin `printf '{"a":1}' \| toon -e --stats -o /dev/full` → `Failed to write to file '/dev/full': No space left on device (os error 28)\n`, exit 1. | S9.15: "… In ENCODE mode with `--stats` every failed write is reported. In every other situation (encode without `--stats`, and decode with or without `--stats`, which decode ignores by S1.153) the failure is reported only when the output exceeds 8192 bytes (S10.3)." S10.3: replace "With `--stats` the error is always reported" by "In encode mode with `--stats` the error is always reported; decode mode never takes that path". Add the case `io_output_dev_full_decode_stats`. |
| S10.3, S7.11 (coverage, not wording) | The threshold is stated for "the whole output" but was run in run 1 with ONE long TOON line on the encode path only (part A's report, item c, marks the rest as inference). Confirmed here on every path, so the inference can be dropped. | [run] encode, 910 short lines: total 8192 B → exit 0 + success line; 8193 B → the write error. [run] decode writer A, root string, 8192 B → exit 0 + ``Decoded `stdin` → `/dev/full` ``; 8193 B → the write error; the same two totals through writer B (`--expand-paths safe`), through `--indent 0`, and with an output of several hundred short JSON lines: identical outcomes. | No change of wording. Add provenance note "[run: many short lines; decode path, both writers]" and the six `io_output_dev_full_decode_*` / `io_output_dev_full_lines_*` cases. |
| S10.83 | Loose on REACH: "Only values containing `[`, optional `+`, digits, optional TAB or `\|`, `]` and a later `:` are hit" reads as "anywhere in the value". The normative rule (S2.130–S2.135) tries only the FIRST `[` of the line, and the colon test is the fields-aware one of S2.132. Loose on OUTCOME: the row says "key and value both wrong, exit 0"; three other outcomes exist. Loose on POSITION: the list of unaffected positions can be read as "list items are safe", but the first field of a list-item OBJECT is a key-value line and is hit. None of this contradicts S2.130–S2.138 (the model built from them predicts all of it); the S10 row is what a law-writer will read when stating the round-trip exclusion set, so it needs the exact predicate. | [run] survive: `a: "[abc] [1]: y"` → `{"a":"[abc] [1]: y"}` (first bracket is `[abc]`); `b: "x[1] y"`; `c: "x[1\t]: y"` (backslash-`t` inside the brackets, as the encoder writes a TAB) ; `d: "x[1]{p:q}"` (brace before the colon, no colon after the `}`) → all unchanged. [run] hit with an ERROR instead of silent corruption: `a: "[1]:"` → `Unterminated string: missing closing quote`, exit 1 (the inline text is the closing quote alone); `a: "x[2]: y"` → `Expected 2 inline array items, but got 1`, exit 1; the cap S10.84. [run] hit inside a list item: `f[1]:⏎␠␠- e: "x[1]: y"⏎␠␠␠␠g[1]: 1` → `{"f":[{"e: \"x":["y\""],"g":[1.0]}]}`. [run] the encoder writes exactly these lines: `{"a":"x[1]: y","b":"[1]:","e":[{"f":"x[1]: y","g":[1]}]}` → `a: "x[1]: y"⏎b: "[1]:"⏎e[1]:⏎␠␠- f: "x[1]: y"⏎␠␠␠␠g[1]: 1`. | "… A key-value content whose key is NOT quoted (object field, folded key, first or later field of a list-item object) is re-read as an array header exactly when, taking the FIRST `[` of the content (it lies in the value, a bare key has none): a `]` follows; the text between is an optional `+`, ASCII digits, an optional final `\|` (a TAB cannot occur there in encoder output: it is written backslash-`t`), value ≤ 18446744073709551615; and a header colon exists after the `]` by S2.132. Outcomes: N > 100000000 → S10.84; otherwise the text after the header colon, which always ends with the value's closing quote, is split as inline values: a last piece that is just that closing quote (the value ended right after the colon or after a delimiter, [run] `a: "x[2]: y,"`) → S9.103; strict count ≠ N → S9.108; else exit 0 with the key `<key>: "<text before the bracket>` and a wrong array. Values of QUOTED keys, inline values, tabular cells, list-item primitives and a root string are never hit." |

Corrections to other clauses: none. In particular S4.248 (the clause run 1 was least sure of) is exact: see Report, class 8.

## New clauses

S10 rows use the pass-2 range given to this reader (S10.200–S10.229). No other section needs a new clause.

| S10.n | behavior | why it is a bug | reproduce with case | decision |
|---|---|---|---|---|
| S10.200 | Second encode → decode break (the first is S10.83). A tabular field name that contains `}` is written by the encoder in quotes with the brace raw inside them (S4.21, S4.26): `[{"a}b":1,"c":2},{"a}b":3,"c":4}]` → `[2]{"a}b",c}:⏎  1,2⏎  3,4` [run]. The decoder finds the end of the fields segment with a plain byte search (S2.132), cuts it at that brace, and the cut piece `"a` fails as a string literal: `Unterminated string: missing closing quote`, stderr, exit 1, stdout empty [run]. The outcome is ALWAYS that error, never a silent wrong value: a name that needs the brace is written entirely inside quotes, so the cut segment always ends inside an open quote and its last piece starts with `"` without a closing quote (also when the name holds escaped quotes, e.g. the name `"}` is written `"\"}"` and cut to `"\"`) [run: 40 generated names]. An opening brace in a field name is harmless (`[1]{"a{b",c}:` decodes) [run]; so are `[`, `]`, `:`, `{`, `}` in the quoted KEY in front of a header (the bracket search starts after the key's closing quote, S2.130) and braces or colons inside inline VALUES (there the first `{` lies after the header colon, S2.132) [run]. (`src/decode/parser.rs:75`, `src/encode/primitives.rs:70-79`) | the encoder emits a document that its own decoder rejects; together with S10.83, S10.74 (literal dotted keys under `--expand-paths safe`) and S10.68 (`--indent 0`) this completes the list of classes found by about 35,000 round-trip documents over adversarial strings, keys and shapes under every delimiter | (case to add: enc_tabular_field_name_close_brace), (case to add: toonerr_field_name_close_brace), (case to add: toonedge_field_name_open_brace_ok) | bug-compatible (default); candidate for the owner's DISC list next to S10.83 |

## Cases to add

Ready to paste into `cases/gen-hand-cases.py` (helpers `case`, `enc`, `dec` as defined there). Every line was run on the
oracle in this pass; the observed outcome follows each group. 39 new names, none present in `goldens/cases.tsv`.

```python
# ---- S4.248: the expansion counter on the paths no golden pins (arrays, table rows, header keys, merges of 1-3 levels, empty leaf, mixed chain, lenient)
dec("toonedge_expand_arrays_255", "[1]:\n" + "".join("  " * i + "- [1]:\n" for i in range(1, 254)) + "  " * 254 + "- [1]: x\n", ["--expand-paths", "safe"], cls="toon-edge", note="S4.248: 255 nested list arrays around a primitive are accepted")
dec("toonerr_expand_arrays_256", "[1]:\n" + "".join("  " * i + "- [1]:\n" for i in range(1, 255)) + "  " * 255 + "- [1]: x\n", ["--expand-paths", "safe"], cls="toon-error", note="S4.248: 256 nested list arrays -> depth cap")
dec("toonedge_expand_empty_leaf_128", "".join("  " * i + "o:\n" for i in range(127)), ["--expand-paths", "safe"], cls="toon-edge", note="S4.248: 128 objects (root included) are accepted when the deepest one is {}")
dec("toonerr_expand_empty_leaf_129", "".join("  " * i + "o:\n" for i in range(128)), ["--expand-paths", "safe"], cls="toon-error", note="S4.248: 129 objects with an empty deepest member -> depth cap")
dec("toonedge_expand_mixed_100_objects_55_arrays", "".join("  " * i + "o:\n" for i in range(99)) + "  " * 99 + "a[1]:\n" + "".join("  " * (99 + j) + "- [1]:\n" for j in range(1, 54)) + "  " * 153 + "- [1]: x\n", ["--expand-paths", "safe"], cls="toon-edge", note="S4.248: objects cost 2, arrays 1: 100 objects then 55 list arrays around a primitive pass")
dec("toonerr_expand_mixed_100_objects_56_arrays", "".join("  " * i + "o:\n" for i in range(99)) + "  " * 99 + "a[1]:\n" + "".join("  " * (99 + j) + "- [1]:\n" for j in range(1, 55)) + "  " * 154 + "- [1]: x\n", ["--expand-paths", "safe"], cls="toon-error", note="S4.248: one more array -> depth cap")
dec("toonedge_expand_nested_key_251", "o:\n  " + ".".join(["k"] * 251) + ": 1\n", ["--expand-paths", "safe"], cls="toon-edge", note="S4.248: k=1, 253-2k = 251 segments accepted")
dec("toonerr_expand_nested_key_252", "o:\n  " + ".".join(["k"] * 252) + ": 1\n", ["--expand-paths", "safe"], cls="toon-error", note="S4.248: k=1, 252 segments -> depth cap")
dec("toonedge_expand_header_key_253", ".".join(["k"] * 253) + "[2]: a,b\n", ["--expand-paths", "safe"], cls="toon-edge", note="S4.248: an array-header key walks like any key; its array value was expanded at c=2 before the walk")
dec("toonerr_expand_header_key_254", ".".join(["k"] * 254) + "[2]: a,b\n", ["--expand-paths", "safe"], cls="toon-error", note="S4.248: 254-segment header key -> depth cap")
dec("toonedge_expand_root_tabular_field_252", "[1]{" + ".".join(["k"] * 252) + "}:\n  1\n", ["--expand-paths", "safe"], cls="toon-edge", note="S4.248: a row object of a root table has c=1, so 252 segments pass")
dec("toonerr_expand_root_tabular_field_253", "[1]{" + ".".join(["k"] * 253) + "}:\n  1\n", ["--expand-paths", "safe"], cls="toon-error", note="S4.248: 253 segments in a root-table field -> depth cap")
dec("toonedge_expand_keyed_tabular_field_250", "t[1]{" + ".".join(["k"] * 250) + "}:\n  1\n", ["--expand-paths", "safe"], cls="toon-edge", note="S4.248: a row object under a key has c=3, so 250 segments pass")
dec("toonerr_expand_keyed_tabular_field_251", "t[1]{" + ".".join(["k"] * 251) + "}:\n  1\n", ["--expand-paths", "safe"], cls="toon-error", note="S4.248: 251 segments in a keyed-table field -> depth cap")
dec("toonedge_expand_merge_flat_252", (".".join(["k"] * 252) + ":\n  p: 1\n") + (".".join(["k"] * 252) + ":\n  q: 2\n"), ["--expand-paths", "safe"], cls="toon-edge", note="S4.248: the merge of two flat objects at the end of a 252-segment path runs at c=255")
dec("toonerr_expand_merge_flat_253", (".".join(["k"] * 253) + ":\n  p: 1\n") + (".".join(["k"] * 253) + ":\n  q: 2\n"), ["--expand-paths", "safe"], cls="toon-error", note="S4.248: the same merge at 253 segments would run at c=256 -> depth cap")
dec("toonedge_expand_merge_nested_251", (".".join(["k"] * 251) + ":\n  x:\n    p: 1\n") + (".".join(["k"] * 251) + ":\n  x:\n    q: 2\n"), ["--expand-paths", "safe"], cls="toon-edge", note="S4.248: a nested merge runs one higher (c=255)")
dec("toonerr_expand_merge_nested_252", (".".join(["k"] * 252) + ":\n  x:\n    p: 1\n") + (".".join(["k"] * 252) + ":\n  x:\n    q: 2\n"), ["--expand-paths", "safe"], cls="toon-error", note="S4.248: nested merge at c=256 -> depth cap")
dec("toonedge_expand_merge3_250", (".".join(["k"] * 250) + ":\n  x:\n    y:\n      p: 1\n") + (".".join(["k"] * 250) + ":\n  x:\n    y:\n      q: 2\n"), ["--expand-paths", "safe"], cls="toon-edge", note="S4.248: three merge levels (c=253, 254, 255) pass")
dec("toonerr_expand_merge3_251", (".".join(["k"] * 251) + ":\n  x:\n    y:\n      p: 1\n") + (".".join(["k"] * 251) + ":\n  x:\n    y:\n      q: 2\n"), ["--expand-paths", "safe", "--no-strict"], cls="toon-error", note="S4.248: third merge level at c=256 -> depth cap, in lenient mode too")
# ---- S10.3 / S9.15 / S1.153: the 8192-byte rule on the decode path (both writers), with --stats in decode mode, and for an output made of many short lines
dec("io_output_dev_full_decode_8192", "x" * 8189 + "\n", ["-o", "/dev/full"], cls="usage", note="LINUX: S10.3 on the decode path, writer A: 8192 output bytes -> exit 0 and the success line")
dec("io_output_dev_full_decode_8193", "x" * 8190 + "\n", ["-o", "/dev/full"], cls="usage", note="LINUX: 8193 output bytes -> Failed to write to file '/dev/full': No space left on device (os error 28)")
dec("io_output_dev_full_decode_expand_8192", "x" * 8189 + "\n", ["-o", "/dev/full", "--expand-paths", "safe"], cls="usage", note="LINUX: the same through writer B (one 8191-byte piece, then LF)")
dec("io_output_dev_full_decode_expand_8193", "x" * 8190 + "\n", ["-o", "/dev/full", "--expand-paths", "safe"], cls="usage", note="LINUX: the same through writer B")
dec("io_output_dev_full_decode_stats", "a: 1\n", ["--stats", "-o", "/dev/full"], cls="usage", note="LINUX: S1.153: --stats is ignored in decode mode, so the small failed write is LOST (exit 0, success line), unlike io_output_dev_full_stats")
case("io_output_dev_full_lines_8192", ["-e", "-o", "/dev/full"], "{" + ",".join('"k%04d":"v"' % i for i in range(909)) + ',"z":"' + "y" * 7 + '"}', "usage", "LINUX: 910 short lines, 8192 bytes in total -> exit 0 and the success line (the total decides, not the line sizes)")
case("io_output_dev_full_lines_8193", ["-e", "-o", "/dev/full"], "{" + ",".join('"k%04d":"v"' % i for i in range(909)) + ',"z":"' + "y" * 8 + '"}', "usage", "LINUX: 910 short lines, 8193 bytes in total -> write error")
# ---- S10.200 (new): second encode->decode break, a closing brace inside a quoted tabular field name
enc("enc_tabular_field_name_close_brace", '[{"a}b":1,"c":2},{"a}b":3,"c":4}]\n', note="S4.26: the field name is quoted, the brace stays raw inside the quotes")
dec("toonerr_field_name_close_brace", '[2]{"a}b",c}:\n  1,2\n  3,4\n', cls="toon-error", note="S2.132/S10.200: the encoder's own output; the fields segment is cut at the brace inside the quotes -> Unterminated string")
dec("toonedge_field_name_open_brace_ok", '[1]{"a{b",c}:\n  1,2\n', cls="toon-edge", note="S2.132: an opening brace inside a quoted field name is harmless")
# ---- S10.83: exact reach of the header-in-value class, and its other outcomes
enc("enc_value_looks_like_header", '{"a":"x[1]: y","b":"[1]:","c":"[abc] [1]: y","d":["x[1]: y"],"e":[{"f":"x[1]: y","g":[1]}]}\n', note="S4.12/S4.14: such values are quoted and nothing else; lines a, b and the item line f are the ones S10.83 breaks on the way back")
dec("toonedge_header_in_value_first_bracket_only", 'a: "[abc] [1]: y"\nb: "x[1] y"\nc: "x[1\\t]: y"\nd: "x[1]{p:q}"\n', cls="toon-edge", note="S2.130-S2.135/S10.83: only the FIRST [ of the line is tried, it needs a length inside and a colon after; all four values survive")
dec("toonerr_header_in_value_unterminated", 'a: "[1]:"\n', cls="toon-error", note="S10.83: the inline text is the value's closing quote -> Unterminated string")
dec("toonerr_header_in_value_count", 'a: "x[2]: y"\n', cls="toon-error", note="S10.83: -> Expected 2 inline array items, but got 1")
dec("toonedge_header_in_value_list_item_field", 'f[1]:\n  - e: "x[1]: y"\n    g[1]: 1\n', cls="toon-edge", note="S10.83: the first field of a list-item object is a key-value line too")
# ---- S2.113: CRLF through every construct the clause names (the corpus pins key-value and inline only)
dec("toonedge_crlf_all_constructs", 'o:\r\n  n: -0\r\n  "q k": "s"\r\nt[2]{a,b}:\r\n  1,x\r\n  2.50,"y"\r\nl[4]:\r\n  - 1e3\r\n  - k: v\r\n    m:\r\n      z: true\r\n  - [2]: p,q\r\n  - u[1]{w}:\r\n      7\r\ne[0]:\r\n', cls="toon-edge", note="S2.113: nested object, quoted key, table rows, list items of every shape and an empty array decode like the LF twin")
dec("toonerr_crlf_blank_line_in_list", 'l[2]:\r\n  - a\r\n\r\n  - b\r\n', cls="toon-error", note="S2.105/S2.113: a line holding only CR is blank -> Line 3: Blank lines inside list array are not allowed in strict mode")
# ---- S4.122/S4.146: long number texts are position-independent (rows and inline values under tab and pipe)
enc("encnum_long_text_in_rows_tab", '{"t":[{"a":1e300,"b":5e-324},{"a":-1.7976931348623157e308,"b":1e-7}],"i":[1e21,1e-300,-0]}\n', ["--delimiter", "\t"], cls="enc-number", note="S4.130: 301- to 326-character number texts inside tab-delimited rows, never quoted")
dec("decnum_long_tokens_in_rows_pipe", "t[2|]{a|b}:\n  1" + "0" * 300 + "|0." + "0" * 323 + "5\n  " + "9" * 309 + "|-0." + "0" * 400 + "1\ni[2|]: 1" + "0" * 308 + " | 1" + "0" * 309 + "\n", cls="dec-number", note="S4.142/S4.143: 300+ character tokens as cells; 309 nines and 1e309 stay strings, -1e-401 is 0.0")
```

Observed on the oracle [run], by group:
- **Expansion counter (20).** Every `toonedge_expand_*` → exit 0, stderr empty, pretty JSON on stdout (sizes 33 404 B to 131 830 B); every
  `toonerr_expand_*` → stdout empty, stderr `Path expansion exceeded maximum depth of 256\n`, exit 1 (the lenient one too).
  All twenty are what S4.248's counter gives: arrays 255/256; empty deepest object 128/129; key under one object 251/252; header key
  253/254; root-table field 252/253 (row object c = 1); keyed-table field 250/251 (row object c = 3); flat merge 252/253; nested merge
  251/252; three-level merge 250/251; 100 objects + 55/56 arrays.
- **Write-loss rule (7).** `…_8192`, `…_lines_8192`, `…_decode_stats` → stdout empty, stderr the success line
  (``Decoded `stdin` → `/dev/full`\n`` or ``Encoded `stdin` → `/dev/full`\n``), exit 0; `…_8193` → stderr
  `Failed to write to file '/dev/full': No space left on device (os error 28)\n`, exit 1.
- **S10.200 (3).** encode → `[2]{"a}b",c}:⏎  1,2⏎  3,4`; decode of that text → `Unterminated string: missing closing quote`, exit 1;
  `[1]{"a{b",c}:⏎  1,2` → `[{"a{b":1.0,"c":2.0}]` (pretty form).
- **S10.83 (5).** encode → `a: "x[1]: y"⏎b: "[1]:"⏎c: "[abc] [1]: y"⏎d[1]: "x[1]: y"⏎e[1]:⏎  - f: "x[1]: y"⏎    g[1]: 1`;
  first-bracket case → the four strings unchanged; `a: "[1]:"` → `Unterminated string: missing closing quote`, exit 1;
  `a: "x[2]: y"` → `Expected 2 inline array items, but got 1`, exit 1; list-item case → `{"f":[{"e: \"x":["y\""],"g":[1.0]}]}` (pretty form).
- **CRLF (2).** The all-constructs document gives byte-identical stdout to its LF twin (358 B:
  `{"o":{"n":0.0,"q k":"s"},"t":[{"a":1.0,"b":"x"},{"a":2.5,"b":"y"}],"l":[1000.0,{"k":"v","m":{"z":true}},["p","q"],{"u":[{"w":7.0}]}],"e":[]}` in pretty form);
  the CR-only line → `Line 3: Blank lines inside list array are not allowed in strict mode`, exit 1.
- **Long number text (2).** encode → rows `1` + 300 zeros ⇥ `0.` + 323 zeros + `5`, and `-17976931348623157` + 292 zeros ⇥ `0.0000001`, inline
  `1000000000000000000000⇥0.` + 299 zeros + `1⇥0` (cell lengths 301, 326, 310, 9; 22, 302, 1); decode → `1e+300`, `5e-324`, the string of
  309 nines, `0.0`, `1e+308`, and the string `1` + 309 zeros.

## Report

**Files re-read (source, for the code paths that CONNECT modules):** `src/cli/mod.rs` (239), `src/cli/conversion.rs` (79),
`src/cli/args.rs` (174), `src/cli/json_stringify.rs` (170 of 334), `src/cli/json_stream.rs` (head), `src/decode/decoders.rs` (30–512),
`src/decode/parser.rs` (20–364), `src/decode/scanner.rs` (40–150), `src/decode/expand.rs` (221), `src/shared/string_utils.rs`,
`src/shared/literal_utils.rs`, `src/encode/encoders.rs` (14–300), `src/encode/primitives.rs` (1–100), `src/encode/normalize.rs`,
`src/lib.rs` (40–190). **Spec re-read:** the five "How this document is organized" ranges for S2 part E, S3 D/E, S4 A/C(index)/D/E,
S5 A/B, S6 B, S8, S9 A/C/E, S10 A/D/E, plus the five run-1 "least sure of" notes, OPEN_QUESTIONS and DISCREPANCIES.

**Oracle runs:** about 150,000 (scripts and transcripts under the pass-2 scratch directory, `pass2/X/`).

**Probe classes (19) and what they showed.** "Model" always means a model written from the clause texts.
1. Round trip `decode(encode(v))`, atom-level values and keys (77 adversarial atoms as values AND keys: header look-alikes, `- `
   prefixes, quotes, backslashes, every delimiter, Unicode White_Space and non-members, NUL, numeric-like), 3 delimiters × indents
   1–4. 400 unfiltered documents: 7 breaks, all S10.83 (predicate above) or the new S10.200. 18,000 more generated with those two
   classes filtered out (about 15,500 run): 0 breaks.
2. The same with `--key-folding safe` then `--expand-paths safe`. 3,000 unfiltered: 164 breaks, every one in a document with a
   LITERAL dotted key (S10.74). 12,000 generated with literal dotted keys filtered out (about 9,300 run): 0 breaks. Folded keys
   always re-expand to the input.
3. Char-level strings (38-symbol alphabet incl. U+0085, U+2028, U+3000, U+FEFF, U+001F, U+0000, astral) in nine shapes (root, object
   value, inline item, tabular cell and field name, list item, first-field key of each kind, nested arrays), 6,800 documents: 0 breaks.
4. Decode pipeline model vs oracle, random line soup (22 key forms, 34 value forms, 17 header forms, indents, tabs, blank lines, CR,
   `--indent` 0–4, strict/lenient, expansion on/off), stdout + stderr + exit compared: 17,500 documents, 0 differences. The same
   model replays all 416 stdin decode goldens (416/416).
5. The same with Unicode White_Space / control characters inside and around contents and 15 more number-token shapes: 24,000, 0 differences.
6. Mutation fuzz: valid encoder output with 1–3 line mutations (indent ±, deleted/duplicated/swapped lines, `[N]` ± 1, delimiter
   swap, dropped quote or colon, damaged `- `, trailing junk, blank lines; 10 % with a mismatched `--indent`): 16,000, 0 differences.
7. Encoder model vs oracle (quoting, five-step array strategy, seven first-field shapes, folding with budget threading,
   sibling and root-literal checks, reset inside list items; delimiters, indents 0–16, flatten-depth absent/0–4/2^64−1): 17,500
   documents incl. 8,000 chain-heavy ones with dotted sibling keys, 0 differences.
8. **S4.248** (run 1's least-sure clause): a counter model taken word by word from the clause vs the oracle on 1,400 random
   documents next to the cap (long dotted keys shared or not, object values 1–4 deep with dotted inner keys, nesting k ∈ {1…127},
   strict and lenient): 0 differences (of the 800 documents whose outcome was tallied: 528 accepted, 218 depth errors, 54 conflicts); plus the explicit paths now proposed as
   cases (arrays, table rows at two positions, header keys, list-item keys inside nested arrays, merges of one, two and THREE
   levels). The clause is exact, including "each nested merge one higher".
9. Number tokens in every decode position (value, root, inline, cell, list item, key, field name) with trailing spaces, CR, NBSP,
   U+3000, VT (trimmed) and U+001F (not trimmed → string), `-0` everywhere, 300–400-character tokens, tokens of 1 MB: all as
   S2.124 / S4.140–S4.147 say. Numeric-looking KEYS are plain strings and never expand (`1.5: x`, `a.1e5: y` stay literal).
10. Number VALUE preservation JSON → TOON → JSON for 1,800 numbers (random bit-pattern doubles and the extremes), in object, inline, tabular, list and
    nested positions under all three delimiters: 0 losses (S4.134).
11. Options crossing directions: `--delimiter \|` on decode does not change the default delimiter of a marker-less header
    (`a[2]: x\|y,z` → `["x\|y","z"]`); decode-only flags on encode and encode-only flags on decode are inert; every combinable
    option at once in each mode (nine options plus INPUT `-`); `--flatten-depth` 0/1 with folding. All as S1.150–S1.154 say, with the one exception recorded under Corrections
    (`--stats` on decode meets the write-loss rule).
12. Input framing: empty / whitespace-only / BOM-only / CR-only input in both directions; JSON followed by BOM, NUL, NBSP, FF;
    1 MB single lines in both directions, 1 MB of leading spaces, 1 MB digit token: all as S2.1–S2.5, S2.102–S2.106, S9.2, S9.21 say.
13. Output size 8192/8193 with `-o /dev/full` on every write path, and stdout = `/dev/full` for outputs of 2 B to 9 KB in both
    modes (always `Failed to write to stdout: …`, exit 1, no statistics): S9.16 holds; S10.3 holds on the paths run 1 had inferred.
14. Error precedence across surfaces: argv error beats invalid UTF-8; invalid UTF-8 beats a JSON error and an uncreatable `-o`;
    a late scanner error beats an early cap error (strict) while lenient mode reports the cap; decode errors beat expansion
    errors; an expansion error beats an uncreatable `-o`: all as S9.10, S9.14, S2.111, S4.249 say.
15. The length cap in nested and ignored positions (list item, first-field table, sibling field, nested object, inside a cell,
    on a dropped line, after a root array, in a quoted value; 6 length spellings × 11 positions × 3 modes = 198 runs): model =
    oracle. Noteworthy and predicted: `- - [100000001]: x` is a cap error because S4.223 parses the rest as a header before
    S4.226 makes it a string; a cell `[100000001]: x` and a dropped line are never parsed.
16. Duplicate JSON keys meeting the encoder: `\u0061` equals `a`; duplicates collapse before tabular detection and before folding
    (`[{"a":1,"b":2,"a":3},{"b":5,"a":4}]` → `[2]{a,b}:⏎  3,2⏎  4,5`): as S2.29, S2.30, S6.10 say.
17. `--stats` × decode × `-o`: the first correction.
18. Environment → output (`CLICOLOR_FORCE`): already S1.21 / S8.3.
19. Spec-internal consistency of facts stated by two parts (White_Space set in S2.106 / S4.8 / S4.311 / S4.145; numeric literal
    in S2.124 / S4.141; numeric-like in S4.10–S4.11 / S4.161; length syntax and cap in S2.135–S2.136 / S4.190–S4.191 / S9.107 /
    S9.210; `--indent` in S1.151 / S2.101 / S5.53): no contradiction except the S9.15 / S10.3 / S1.153 one above.

**Round-trip exclusion set, for whoever writes the law** (evidence: classes 1–3, about 35,000 documents; a closure claim, not provable
by running): with matching `--indent` ≥ 1 and any delimiter, `decode(encode(v))` differs from `v` (beyond the `1` → `1.0` number
text) exactly when (a) a string VALUE on a bare-key key-value line satisfies the S10.83 predicate as reworded above, or (b) a
tabular field name contains `}` (S10.200); with `--expand-paths safe` also (c) a key that is written bare and contains a dot
(S10.74); with `--indent 0` any nested value (S10.68).

**Still unsure / hypotheses not confirmed by a run.**
- HYPOTHESIS: a JSON array of more than 100,000,000 items encodes to a header above the decoder's cap (S4.27 + S2.136), a third
  encode → decode break. Not run: the input exceeds this pass's 20 MB limit.
- The round-trip exclusion set is an observation over a finite alphabet; combinations of three or more interacting atoms inside
  one string were sampled, not enumerated.
- The three models were written from the clauses by a reader who had also read the source; where a clause was ambiguous the
  reader may have resolved it the source's way without noticing. The two looseness findings above are the places where that was
  caught; a reviewer who never opened the source is the better test of wording.
- Parts A (clap argv grammar), B (serde_json messages and columns) and C (the three number algorithms beyond the shapes above)
  were probed only where they touch another surface; their single-surface rules were left to their own pass-2 readers.
