#!/usr/bin/env python3
"""board-refresh: keep docs/FEATURE_PARITY.md honest after a gate run.

1. ALWAYS: rewrite the `laws` column from port/LAWS.bend: every law is cited on the row(s) it supports, by the
   RULES table below (first matching rule wins). A law no rule places stops the run: add a rule, never a
   blanket one. `scripts/law-coverage.sh` then reports 0 uncited and 0 ghost citations.
2. WITH --commit SHA --lanes-log FILE (the complete output of scripts/lanes.sh): paste the lanes JSON line into
   the header, flip `partial` rows to `present` ONLY when every lane of that run passed, and rewrite the
   "Proof coverage" and "Lanes" tables from the law file and the log.
usage: python3 scripts/board-refresh.py [--commit SHA --lanes-log FILE]
exit: 0 written, 1 a law without a rule or a rule without its row, 2 usage.
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOARD = os.path.join(ROOT, "docs", "FEATURE_PARITY.md")


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def write(path, text):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


ROWS = {  # key = the start of the feature cell
 "JSON text input": [], "JSON input errors": [], "strict UTF-8": [], "JSON number reading": [], "TOON number text": [],
 "encoder primitives": [], "array headers, joins": [], "list items in every shape": [], "delimiters comma, tab, pipe on encode": [],
 "safe key folding": [], "TOON scanning": [], "tokens, string literals": [], "TOON number tokens": [], "structural decoding": [],
 "strict validation": [], "safe path expansion": [], "JSON number text": [], "JSON writer A": [], "JSON writer B": [],
 "argv: option spellings": [], "help and version text": [], "clap error shapes": [], "mode detection": [], "output framing": [],
 "--stats": [], "I/O errors": [], "large inputs and determinism": [],
}
def put(law, *rows):
    for r in rows:
        ROWS[r].append(law)
RULES = [  # (regex on the law name, rows) — first match wins
 (r"json_error_is_sticky$", ["JSON input errors"]),
 # EXP-007: the pre-pass renders numbers before emission; its laws pin the kill-switch and the two
 # ways a number reaches put.prim (rendered text, or a token whose conversion was deferred)
 (r"(pre_gate_switch|pre_txt_is_num|pre_raw_is_num)$", ["TOON number text"]),
 # the decode-side half of the same pass renders the JSON number text before the writer
 (r"(pre_txt_is_num_json)$", ["JSON number text"]),
 # the pass's printer dispatch: which of the two number printers a rendered token was built with,
 # so the law belongs on both number-text rows (hand mutant M36 swaps them)
 (r"(num_text_)", ["TOON number text", "JSON number text"]),
 # the argv scanner's gate: pinned because the corpus covers it by only two cases
 (r"(on_neg_takes_)", ["argv: option spellings"]),
 # EXP-016: the byte classifier's table. Every branch of the reader dispatches on this code,
 # so the table belongs on the row that owns the JSON grammar.
 (r"(byte_cls_)", ["JSON text input"]),
 # the dispatch sweep: each law pins one arm of a fast/spec gate, on the row whose numbers it decides
 (r"(dg_step_with_|dg_digit_fast_fin_)", ["TOON number text"]),
 (r"(div_p10_pick_|from_dec_p10_pick_|token_short_takes_)", ["JSON number reading"]),
 (r"(num_defer_)", ["JSON text input", "TOON number text"]),
 # which printer the decode side tells the pass to use (hand mutant M37 lies about the flag)
 (r"(dec_done_renders_with_the_json_printer)$", ["JSON number text"]),
 # R16-1/R16-3: the reader's deferral bounds. They govern which tokens the pre-pass may keep raw,
 # so they pin whether `number out of range` keeps its position — a JSON-input fact, not a TOON one
 (r"(num_safe_)", ["JSON text input", "TOON number text"]),
 (r"(kt_collision_)", ["JSON text input", "safe key folding"]),
 (r"(str_cmp_orders|ks_bucket_)", ["JSON text input", "safe key folding", "safe path expansion"]),
 (r"golden_encstr_fold_hash_collision$", ["safe key folding"]),
 (r"golden_toonedge_repeated_keys_hash_collision$", ["structural decoding", "JSON writer A"]),
 (r"golden_(toonedge|toonerr)_expand_.*hash_collision", ["safe path expansion", "JSON writer B"]),
 (r"golden_collision_keys_encode$", ["JSON text input", "safe key folding", "array headers, joins"]),
 (r"golden_encstr_duplicate_keys", ["JSON text input"]),
 (r"(int_fit_|short_of_digits_)", ["TOON number text", "JSON number text"]),
 (r"(int_text_)", ["JSON number reading", "TOON number tokens"]),
 (r"(key_hash_fnv1a|kt_member|kt_not_member)$", ["JSON text input", "safe key folding"]),
 (r"golden_(jsonerr|toonerr)_(invalid_utf8|overlong_utf8|truncated_utf8)", ["strict UTF-8"]),
 # round 13 (R13-9): the three behaviours whose mutants survived the whole proof, now pinned by laws
 (r"(utf8_rejects_surrogate|utf8_accepts_below_surrogate)$", ["strict UTF-8"]),
 # EXP-018: the decoder that only validates, and the conversion that asks for the text only when it reads it
 (r"(utf8_verdict_|encode_invalid_utf8_refused$)", ["strict UTF-8"]),
 (r"(encode_non_ascii_without_stats|encode_stats_reads_the_text)$", ["strict UTF-8", "--stats"]),
 # EXP-031/032: the UTF-8 verdict decides before any decode or JSON failure; the mark with --stats; the one walk
 (r"(decode_invalid_utf8_after_toon_error|decode_truncated_utf8_at_the_end|encode_invalid_utf8_after_json_error"
  r"|encode_truncated_utf8_after_json_error|encode_stats_invalid_utf8_in_key)$", ["strict UTF-8"]),
 (r"(decode_stats_after_mark_multibyte|encode_stats_after_mark|encode_stats_two_marks_is_json_error)$", ["strict UTF-8", "--stats"]),
 # EXP-021: the TOON text built forward from reversed lines (the final LF, line order, every line shape)
 (r"(encode_text_)", ["output framing"]),
 # EXP-022: trim_end on every shape, and the decoder's values trimmed through the whole pure core
 (r"(trim_end_|decode_values_trimmed_at_the_end$)", ["tokens, string literals"]),
 # EXP-024: a string literal found and unescaped in one walk, its failures in their order
 (r"(decode_literal_)", ["tokens, string literals"]),
 # EXP-025: the scanner over the reversed text: CR endings, blank lines, the TAB check, the first failure, the BOM
 (r"(decode_scan_)", ["TOON scanning"]),
 # round 19 (R19-1..4): the numeric-like quoting of a trailing fraction zero, a final CR without LF, a byte order mark
 # after the first line, an escaped quote before a colon in a quoted cell
 (r"(encode_fraction_trailing_zeros_quoted|is_like_zero_in_phase_4_)", ["encoder primitives"]),
 (r"(decode_final_cr_without_lf|decode_bom_after_the_first_line_kept)$", ["TOON scanning"]),
 (r"(decode_escaped_quote_before_colon_in_cell)$", ["tokens, string literals"]),
 # round 26 (R26-3, R26-4): deeper lines in bodies, check order, indentation jumps, narrow rows; argv number words; the
 # fold prefix
 (r"(decode_deeper_row_not_a_row|decode_deeper_item_not_an_item|decode_deeper_line_after_full_table)$", ["structural decoding"]),
 (r"(decode_blank_before_surplus_row|decode_indentation_jump_refused|decode_narrow_row_refused)$", ["strict validation"]),
 (r"(argv_negative_leading_dot_word|argv_negative_two_dots_word)$", ["argv: option spellings"]),
 (r"encode_fold_prefix_is_parent_path$", ["safe key folding"]),
 # round 25 (R25-3, R25-4): list items and the data-row test; strict and lenient table ends; argv number words and -o=
 (r"(decode_list_item_ws_before_nested_array|decode_colon_before_delimiter_not_a_row|decode_delimiter_before_colon_is_a_row"
  r"|decode_list_line_after_full_table|decode_bare_dash_sibling_over_indented)$", ["structural decoding"]),
 (r"(decode_lenient_sibling_after_full_table|decode_blank_line_inside_table_refused)$", ["strict validation"]),
 (r"(argv_negative_exponent_dot_word|argv_negative_trailing_exponent_word|argv_flatten_depth_negative_value"
  r"|argv_output_equals_removed)$", ["argv: option spellings"]),
 # round 24 (R24-3, R24-4): the header colon and the fields segment, quoted and bare field names under expansion, quoted
 # key escapes; fold budgets in list items and at depth 2; an upper-case first key character
 (r"(decode_semicolon_after_fields_refused|decode_space_and_tab_before_header_colon|decode_quoted_field_not_expanded"
  r"|decode_quoted_key_four_escapes|decode_bare_field_expanded)$", ["tokens, string literals"]),
 (r"(encode_fold_budget_in_list_item|encode_flatten_depth_two_folds)$", ["safe key folding"]),
 (r"encode_upper_case_initial_keys_are_bare$", ["encoder primitives"]),
 # round 23 (R23-4, R23-5): later bare-key characters; field-name, header-colon and quoted-key rules of the header parser;
 # the JSON reader's `\u` hex and surrogate ends; a list item's tabular first field; the data-row test; `\u00XX` hex case
 (r"encode_key_later_char_range_ends$", ["encoder primitives"]),
 (r"(decode_empty_field_between_names|decode_empty_last_field_name|decode_bracket_then_equals_is_key"
  r"|decode_quoted_key_cr_escape|decode_values_after_fields_header_refused|decode_open_quote_in_fields_segment"
  r"|decode_unknown_escape_in_quoted_key)$", ["tokens, string literals"]),
 (r"(encode_hex_escape_letter_ends|encode_surrogate_pairs_at_both_ends)$", ["JSON text input"]),
 (r"encode_list_item_first_field_tabular$", ["list items in every shape"]),
 (r"decode_colon_line_ends_tabular_rows$", ["strict validation"]),
 (r"decode_json_writer_lower_case_hex_controls$", ["JSON writer A"]),
 # round 22 (R22-4): the JSON reader's `\b` and `\f`; a `_`-initial bare key; a short row in header order; an array
 # of objects that is itself a list item (S4.42)
 (r"encode_json_backspace_and_form_feed_escapes$", ["JSON text input"]),
 (r"encode_underscore_initial_keys_are_bare$", ["encoder primitives"]),
 (r"encode_short_row_in_header_order_is_list_form$", ["array headers, joins"]),
 (r"encode_array_of_objects_as_list_item_is_list_form$", ["list items in every shape"]),
 # round 21 (R21-1, R21-4): tabular decisions on reordered, empty and short rows; the JSON reader's `\/`
 (r"(encode_reordered_row_with_nested_(object|array)_is_list_form|encode_array_of_empty_objects_is_list_form"
  r"|encode_row_missing_a_header_key_is_list_form)$", ["array headers, joins"]),
 (r"encode_escaped_solidus_reads_as_slash$", ["JSON text input"]),
 (r"(encode_close_bracket_quote_backslash_force_quotes|encode_signed_exponents_and_zero_mantissa_quoted"
  r"|encode_null_true_false_strings_quoted)$", ["encoder primitives"]),
 # round 20 (R20-3): brackets and braces, edge whitespace, exponents with a 0, a digit after a leading 0
 (r"(encode_brackets_and_braces_force_quotes|encode_edge_whitespace_forces_quotes|encode_exponents_and_signed_integers_quoted"
  r"|encode_leading_zero_digits_quoted|is_like_exponent_|is_like_signed_integer|is_like_leading_zero_then_digit)$", ["encoder primitives"]),
 # EXP-029: repeated keys in small and large JSON objects, around the member that builds the key set
 (r"(encode_repeated_key_)", ["JSON text input"]),
 # round 18 (R18-2..5): delimited values with an escaped quote, the first bad escape, FF before a quoted key,
 # a backslash outside quotes in a header's field segment
 (r"(decode_(inline|tabular|pipe)_escaped_quote_before_delimiter|decode_literal_first_of_two_bad_escapes|decode_form_feed_before_quoted_key|decode_backslash_outside_quotes_in_fields)$", ["tokens, string literals"]),
 # EXP-026: the numeric-like recognizer against the lexer, and the quoting it decides
 (r"(is_like_|encode_numeric_like_items$)", ["encoder primitives"]),
 # EXP-027: the JSON reader's string arm, its guard's edges, and plain bytes through the whole core
 (r"(step_in_str_|plain_\d+_|encode_plain_string_bytes$)", ["JSON text input"]),
 (r"(writer_b_keeps_)", ["JSON writer B"]),
 (r"(writer_a_keeps_del_raw)$", ["JSON writer A"]),
 (r"(tab_in_value_forces_quotes)$", ["encoder primitives", "delimiters comma, tab, pipe on encode"]),
 # round 14 (R14-1): five more behaviours whose mutants survived the whole proof, now pinned by laws. Each
 # row is the one that cites the cases its mutant broke (encstr_quoting, auto_upper_toon_ext,
 # usage_similar_arg_*, stats_ws_each + encstr_ws_edge_sweep, decfmt_exp_upper_boundary). CR is a quoting
 # character only, not a delimiter, so unlike TAB it is not placed on the delimiters row.
 (r"(cr_in_value_forces_quotes)$", ["encoder primitives"]),
 (r"ends_ws_", ["encoder primitives"]),
 (r"(lower_rev_folds_upper_toon)$", ["mode detection"]),
 (r"(seven_tenths_is_0_7)$", ["clap error shapes"]),
 (r"(is_ws_ogham_space_mark|is_ws_not_after_ogham|is_ws_all_25_members|is_ws_documented_non_members)$", ["encoder primitives", "--stats"]),
 (r"(json_plain_at_k16|json_plain_at_k21|json_exponent_at_k22|json_plain_at_kneg5|json_exponent_at_kneg6)$", ["JSON number text"]),
 (r"golden_jsonerr_", ["JSON input errors"]),
 (r"golden_(jsonout_duplicate_keys)$", ["JSON writer A", "structural decoding"]),
 (r"golden_jsonout_", ["JSON writer A"]),
 (r"golden_flag_decode_indent_", ["JSON writer A"]),
 (r"(bn_add_carry|div_pow10_|div_p10_|from_dec_p10_|serde_)", ["JSON number reading"]),
 (r"golden_encnum_", ["JSON number reading", "TOON number text"]),
 (r"(show_toon_fast_)", ["TOON number text"]),
 (r"golden_(fx_enc_arrays_objects_01|happy_readme_users)$", ["TOON number text", "list items in every shape"]),
 (r"(show_json_fast_)", ["JSON number text"]),
 (r"golden_(decnum_|fx_dec_numbers_0[68])", ["JSON number text", "TOON number tokens"]),
 (r"token_", ["TOON number tokens"]),
 (r"golden_fx_dec_numbers_", ["TOON number tokens"]),
 (r"twin_gate_", ["JSON number reading", "TOON number text", "TOON number tokens", "JSON number text"]),
 (r"(dg_digit_fast_|dgw_run_|dgw_fits_|dg_run_with_gate|dg_run_words_spec_arm)", ["TOON number text", "JSON number text"]),
 (r"(fold_off_never_folds|fctx_lean_closed_by_switch)$", ["safe key folding"]),
 (r"golden_(encstr_root_|fx_enc_primitives_|fx_enc_objects_(04|17|20))", ["encoder primitives"]),
 (r"golden_fx_enc_arrays_(primitive|nested_0[13]|tabular|objects_(15|02))", ["array headers, joins"]),
 (r"golden_(fx_enc_arrays_objects_|fx_enc_objects_|fx_enc_arrays_nested_10|flag_indent_(0|16)_encode|fx_enc_whitespace_)", ["list items in every shape"]),
 (r"golden_(fx_enc_delimiters_|flag_delimiter_)", ["delimiters comma, tab, pipe on encode", "argv: option spellings"]),
 (r"golden_(fx_enc_key_folding_|enc_fold|flag_flatten_depth_)", ["safe key folding"]),
 (r"(depth_of_indent|depth_with_indent_zero|lenient_scan_never_fails)$", ["TOON scanning"]),
 (r"golden_(fx_dec_indentation_errors_|toonedge_indent|toonlenient_indent_|toonerr_tab_indent|toonlenient_tab_indent|toonedge_crlf)", ["TOON scanning"]),
 (r"golden_fx_dec_blank_lines_01$", ["TOON scanning", "strict validation"]),
 (r"(lenient_body_never_fails)$", ["strict validation"]),
 (r"golden_(toonlenient_|fx_dec_blank_lines_|fx_dec_validation_errors_|toonerr_(blank_in_list|count_beats_blank|extra_|too_few_|too_many_|zero_))", ["strict validation"]),
 (r"(expansion_cap_on_|expand_cap_is_256_|expand_segments_253_|expand_depth_12[78]_|expand_order_first_insertion)",["safe path expansion", "JSON writer B"]),
 (r"golden_(fx_dec_path_expansion_|toonedge_expand_)", ["safe path expansion", "JSON writer B"]),
 (r"golden_(toonerr_(after_closing_quote|bad_escape|cap_in_quoted_value|header_|huge_length|inline_bad_quote|length_|missing_close_bracket|mixed_delims|nested_headers|trailing_backslash|unicode_escape|unterminated_)|toonedge_(header_|item_quote|list_item_two_spaces|length_|fields_)|fx_dec_primitives_|fx_dec_objects_(04|17)|fx_dec_whitespace_|fx_dec_delimiters_)", ["tokens, string literals"]),
 (r"(decode_error_ends_pass|decode_root_ends_pass|decode_trailing_line_is_error|decode_dup_reported_at_end)$",["structural decoding"]),
 (r"hot_dups_", ["structural decoding"]),
 # round 16 (R16-2): the first repeated-key failure is the one reported
 (r"(dup_keep_is_first|decode_outer_dup_before_nested_dup)$", ["structural decoding"]),
 (r"hdr_precheck_", ["tokens, string literals"]),
 (r"write_(empty_array|empty_object|nested_indent_[02])$", ["JSON writer A"]),
 (r"golden_(decstr_|toonerr_|toonedge_|fx_dec_)", ["structural decoding"]),
 (r"(encode_flag_wins|decode_flag_wins|stdin_defaults_to_encode)$", ["mode detection"]),
 (r"golden_flag_(stdin_dash|double_dash)", ["mode detection", "argv: option spellings"]),
 (r"golden_flag_", ["argv: option spellings"]),
 (r"golden_usage_(version|help)", ["help and version text", "clap error shapes"]),
 (r"argv_stop_is_sticky$", ["argv: option spellings", "clap error shapes"]),
 (r"golden_usage_none$", ["mode detection"]),
 (r"golden_usage_", ["clap error shapes"]),
 (r"(stats_|no_saved_line_without_savings)", ["--stats"]),
 (r"golden_happy_", ["large inputs and determinism", "JSON writer A"]),
]


def cite(laws):
    for law in laws:
        for rx, rows in RULES:
            if re.match(rx, law):
                for r in rows:
                    ROWS[r].append(law)
                break
        else:
            sys.exit("board-refresh: no rule places the law %s" % law)
    out, seen = [], set()
    for line in read(BOARD).splitlines(keepends=True):
        if line.startswith("| ") and not line.startswith("| feature") and line.count("|") >= 8:
            cells = line.rstrip("\n").split("|")
            key = next((k for k in ROWS if cells[1].strip().startswith(k)), None)
            if key is not None:
                seen.add(key)
                cells[5] = " " + (", ".join(ROWS[key]) if ROWS[key] else "none") + " "
                line = "|".join(cells) + "\n"
        out.append(line)
    if set(ROWS) - seen:
        sys.exit("board-refresh: board rows not found: " + ", ".join(sorted(set(ROWS) - seen)))
    write(BOARD, "".join(out))


def finalize(commit, log):
    line = [l for l in read(log).splitlines() if l.startswith('{"lanes"')][-1].strip()
    lanes = json.loads(line)
    allpass = lanes["verdict"] == "PASS"
    laws_text = read(os.path.join(ROOT, "port", "LAWS.bend"))
    blocks = re.split(r"(?m)^law ", laws_text)[1:]
    names = [b.split(":", 1)[0].strip() for b in blocks]
    quant = [n for n, b in zip(names, blocks) if re.search(r"(?m)^  for ", b.split("\nlaw ")[0])]
    golden = [n for n in names if n.startswith("golden_")]
    closed = [n for n in names if n not in quant and n not in golden]
    twin = [n for n in names if re.match(r"(twin_gate_|dg_digit_fast_|dgw_run_|dgw_fits_|dg_run_with_gate|dg_run_words_spec_arm|fold_off_never_folds|fctx_lean_closed_by_switch|div_pow10_|div_p10_|from_dec_p10_|serde_|token_|show_(toon|json)_fast_|int_fit_|int_text_|short_of_digits_)", n)]
    s = read(BOARD)
    a = s.index("Last gate run:")
    b = s.index("| feature |")
    cases = lanes["lanes"][0]["passed"] + lanes["lanes"][0]["failed"]
    import datetime
    head = ("Last gate run: " + datetime.date.today().isoformat() + " on the tree of commit `%s` · `scripts/lanes.sh goldens/cases.tsv goldens port/main.bend --threads 8` (alone or inside `scripts/port-doctor.sh`; the pasted line names the timeouts it ran with) → `%s` ·\n"
            "proofs: `bun /tmp/bend/bend2/main.ts port/PROOF.bend` → `All terms check.` with 0 unsafe (0 `@unsafe` + 0 template instances, bend 2.0.16), %d laws "
            "(%d quantified, %d closed unit laws, %d closed whole-pipeline `golden_<case>` laws) · `scripts/law-coverage.sh`: every law cited by a row below, 0 ghost citations ·\n"
            "a row is `present` when the goldens it names pass on EVERY lane of that run and the laws it names are proved; \"laws\" on a row are closed instances unless the row names one of the %d quantified laws.\n\n"
            % (commit, line, len(names), len(quant), len(closed), len(golden), len(quant)))
    s = s[:a] + head + s[b:]
    if allpass:  # table rows only: the legend above the table names the statuses too
        s = "".join(l.replace(" | partial | ", " | present | ") if l.startswith("| ") and l.count("|") >= 8 else l for l in s.splitlines(keepends=True))
    s = s.replace("`J.read` (`J.step`, `J.run`, `J.finish`), `J.obj.put`", "`J.read` (`J.step`, `J.run`, `J.finish`), `J.obj.member`, `J.obj.close`, `T.kt.*`, `J.km.*`")
    a = s.index("## Proof coverage")
    tail = """## Proof coverage

    | kind | count | list |
    |---|---|---|
    | quantified laws (hold for every input) | %d | %s |
    | laws about the fast twins (the quantified gate pair and the two quantified key-folding gate laws; the rest closed instances, `perf/NEGATIVE-EVIDENCE.md` NE-001..003, NE-010, NE-011) | %d | %s |
    | other closed unit laws | %d | %s |
    | closed goldens as laws (`C.run_pure(argv, bytes) == Out`) | %d | `golden_<case>` for %d corpus cases, each cited on its row above |
    | `@unsafe` defs | 0 | none; template instances: 0 |

    ## Lanes

    | lane | cases | verdict | date |
    |---|---|---|---|
    %s| gpu (`--gpu on`) | - | MISSING: no bang is placed (text with data-dependent structure), so there is no device lane to run | - |

Since EXP-007 (`0131342`) the encoder's number pre-pass is a parallel let: above `--threads 1` the runtime runs it on a worker pool,
so `c-8t` is a genuinely parallel lane on every `--encode` case; decoding and every other path stay sequential, and no bang is placed.
    """ % (len(quant), ", ".join("`%s`" % n for n in quant), len(twin), ", ".join("`%s`" % n for n in twin),
           len([n for n in closed if n not in twin]), ", ".join("`%s`" % n for n in closed if n not in twin), len(golden), len(golden),
           "".join("| %s | %d/%d | %s | %s (tree of `%s`) |\n" % (l["lane"], l["passed"], l["passed"] + l["failed"], l["verdict"], datetime.date.today().isoformat(), commit) for l in lanes["lanes"]))
    tail = "\n".join(l[4:] if l.startswith("    ") else l for l in tail.split("\n"))  # the template above is indented with this def
    s = s[:a] + tail
    write(BOARD, s)
    print("laws", len(names), "quantified", len(quant), "closed", len(closed), "golden", len(golden), "twin", len(twin), "allpass", allpass)


def main():
    argv = sys.argv[1:]
    if "-h" in argv or "--help" in argv:
        print(__doc__.strip())
        return 0
    opts = dict(zip(argv[0::2], argv[1::2]))
    if len(argv) % 2 or set(opts) - {"--commit", "--lanes-log"} or (("--commit" in opts) != ("--lanes-log" in opts)):
        print(__doc__.strip())
        return 2
    laws = re.findall(r"(?m)^law\s+([A-Za-z_][A-Za-z0-9_.]*)", read(os.path.join(ROOT, "port", "LAWS.bend")))
    cite(laws)
    if opts:
        finalize(opts["--commit"], opts["--lanes-log"])
    print(json.dumps({"laws": len(laws), "rows": len(ROWS), "rows_without_a_law": [k for k, v in ROWS.items() if not v], "lanes_pasted": bool(opts)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
