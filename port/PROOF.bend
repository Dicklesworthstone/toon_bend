# toon — the proofs. The agent's file: imports the code and the laws and fills every law with
# `def Laws.<name>(params)`. Lemmas go above their first use. Gate:  bend PROOF.bend  →
# "All terms check." (state the unsafe count from the same output beside every parity claim).
import Base
import ./bignat.bend as BN
import ./f64.bend as F
import ./text.bend as T
import ./json.bend as J
import ./decode.bend as D
import ./encode.bend as E
import ./cli.bend as C
import ./LAWS.bend as Laws

# S1.4 the first arm of on.tok matches a stopped scan whatever the token is
def Laws.argv_stop_is_sticky(code, out, err, t):
  {==}

# S9.141 run scrutinizes the lines, then the bound, then the step: by cases on the first two, every
# arm that meets a failure returns it
def Laws.decode_error_ends_pass(ls, b, msg, strict):
  match ls:
    case Nil{}:
      match b:
        case 0n:
          {==}
        case 1n+p:
          {==}
    case Con{l, rest}:
      match b:
        case 0n:
          {==}
        case 1n+p:
          {==}

# S4.202 the same cases; with strict False and no pending failure, run.done returns the root value
def Laws.decode_root_ends_pass(ls, b, v):
  match ls:
    case Nil{}:
      match b:
        case 0n:
          {==}
        case 1n+p:
          {==}
    case Con{l, rest}:
      match b:
        case 0n:
          {==}
        case 1n+p:
          {==}

# S9.152 the same split on the bound, and on the pending failure; run.done's first arm names the line
def Laws.decode_trailing_line_is_error(num, depth, content, rest, b, v, dup):
  match b dup:
    case 0n None{}:
      {==}
    case 0n Some{m}:
      {==}
    case 1n+p None{}:
      {==}
    case 1n+p Some{m}:
      {==}

# S3.26 the same split on the bound; run.done's second arm returns the pending failure
def Laws.decode_dup_reported_at_end(b, v, m, strict):
  match b strict:
    case 0n True{}:
      {==}
    case 0n False{}:
      {==}
    case 1n+p True{}:
      {==}
    case 1n+p False{}:
      {==}

# S2.45 the first arm of step
def Laws.json_error_is_sticky(msg, el, ec, stack, depth, l, c, root, b, spec):
  {==}

# S4.217 the first arm of close.msg
def Laws.lenient_body_never_fails(short, blank, surplus, tab, n, cnt):
  {==}

# S2.112 the second arm of scan.check
def Laws.lenient_scan_never_fails(tab, num, unit, indent):
  {==}

# S4.300 (1)
def Laws.encode_flag_wins(dec, has_in, e):
  {==}

# S4.300 (2)
def Laws.decode_flag_wins(has_in, e):
  {==}

# S4.303
def Laws.stdin_defaults_to_encode(e):
  {==}

# S4.314
def Laws.no_saved_line_without_savings(j, t):
  {==}

# S4.315 by evaluation
def Laws.stats_exact_tie_rounds_up():
  {==}

# S5.108 by evaluation
def Laws.stats_larger_toon_reported():
  {==}

# S4.248 expand scrutinizes the value first: by cases on its constructor, every arm meets XVal{0n}
def Laws.expansion_cap_on_values(v, strict):
  match v:
    case J.JNull{}:
      {==}
    case J.JBool{b}:
      {==}
    case J.JNum{f}:
      {==}
    case J.JStr{s}:
      {==}
    case J.JTxt{s}:
      {==}
    case J.JRaw{neg, ints, fracs, eneg, x}:
      {==}
    case J.JArr{n, items}:
      {==}
    case J.JObj{entries}:
      {==}
    case J.JNil{}:
      {==}
    case J.JCons{head, tail}:
      {==}
    case J.JECons{key, quoted, val, tail}:
      {==}

# S4.248
def Laws.expansion_cap_on_merges(tgt, src, strict):
  {==}

# S7.21
def Laws.bn_add_carry():
  {==}

# S2.107
def Laws.depth_of_indent():
  {==}

# S2.107
def Laws.depth_with_indent_zero():
  {==}

# S4.317
def Laws.stats_estimate_small():
  {==}

# S4.310
def Laws.stats_estimate_empty():
  {==}

# S4.316
def Laws.stats_pct_6_25():
  {==}

# S4.316
def Laws.stats_pct_18_75():
  {==}

# S4.315
def Laws.stats_pct_double_rounding():
  {==}

# ---------------------------------------------------------------- fast == spec (Phase 5)

# S8.2 the first arm of the gate
def Laws.twin_gate_switch(ok):
  {==}

# S8.2 the second arm of the gate
def Laws.twin_gate_open(ok):
  {==}

# S4.131 computed
def Laws.show_toon_fast_1500():
  {==}

# S4.170 computed
def Laws.show_json_fast_1500():
  {==}

# S4.131 computed
def Laws.show_toon_fast_one():
  {==}

# S4.101 computed
def Laws.serde_short_42():
  {==}

# S4.118 computed
def Laws.serde_short_zero():
  {==}

# S4.143 computed
def Laws.token_short_42():
  {==}

# S4.143 computed
def Laws.token_short_neg7():
  {==}

# S4.114 computed
def Laws.div_p10_37_1():
  {==}

# S4.114 computed
def Laws.div_p10_k5():
  {==}

# S4.114 computed
def Laws.div_p10_k7():
  {==}

# S4.143 computed
def Laws.from_dec_p10_37():
  {==}

# S4.143 computed
def Laws.from_dec_p10_k30():
  {==}

# S4.101, computed
def Laws.serde_decimal_3_7():
  {==}

# S4.143 computed
def Laws.token_decimal_3_7():
  {==}

# S7.21 both sides computed
def Laws.div_pow10_a20_k0():
  {==}

# S7.21 both sides computed
def Laws.div_pow10_a20_k1():
  {==}

# S7.21 both sides computed
def Laws.div_pow10_a20_k5():
  {==}

# S7.21 both sides computed
def Laws.div_pow10_a20_k6():
  {==}

# S7.21 both sides computed
def Laws.div_pow10_a20_k7():
  {==}

# S7.21 both sides computed
def Laws.div_pow10_a20_k12():
  {==}

# S7.21 both sides computed
def Laws.div_pow10_a20_k19():
  {==}

# S7.21 both sides computed
def Laws.div_pow10_a20_k22():
  {==}

# S7.21 both sides computed
def Laws.div_pow10_a20_k23():
  {==}

# S7.21 both sides computed
def Laws.div_pow10_multiple_k7():
  {==}

# S7.21 both sides computed
def Laws.div_pow10_below_multiple_k7():
  {==}

# S7.21 both sides computed
def Laws.div_pow10_one_k1():
  {==}

# S7.21 both sides computed
def Laws.div_pow10_zero_k3():
  {==}

# ---------------------------------------------------------------- carriers and the cap (closed)

# S6.10 computed
def Laws.key_hash_fnv1a():
  {==}

# S6.10 computed
def Laws.kt_member():
  {==}

# S6.10 computed
def Laws.kt_not_member():
  {==}

# S6.42 computed
def Laws.expand_order_first_insertion():
  {==}

# S4.248 computed
def Laws.expand_cap_is_256_reject():
  {==}

# S4.231, S9.155 computed
def Laws.expand_segments_253_hits_nesting_cap():
  {==}

# S4.231, S9.155 computed
def Laws.expand_depth_127_accept():
  {==}

# S4.231, S9.155 computed
def Laws.expand_depth_128_reject():
  {==}

# S4.231, S9.155 computed
def Laws.expand_segments_253_not_ok():
  {==}

# ---------------------------------------------------------------- closed goldens of the whole pure core:
# every one is proved by computation

# S2.2 the surrogate gate (round 13, R13-9)
def Laws.utf8_rejects_surrogate():
  {==}

# S2.2 the scalar below the surrogate block
def Laws.utf8_accepts_below_surrogate():
  {==}

# S5.63 the one escape table keeps DEL raw
def Laws.writer_b_keeps_del_raw():
  {==}

# S5.63 the one escape table keeps the C1 block raw
def Laws.writer_b_keeps_c1_raw():
  {==}

# S5.63 writer A on the same scalar
def Laws.writer_a_keeps_del_raw():
  {==}

# S4.12-S4.16 a TAB forces quotes
def Laws.tab_in_value_forces_quotes():
  {==}

# S4.12-S4.16 the CR arm of bad_char (round 14, R14-1)
def Laws.cr_in_value_forces_quotes():
  {==}

# S4.302 the extension lowercaser over A..Z (round 14, R14-1)
def Laws.lower_rev_folds_upper_toon():
  {==}

# S1.74 the similarity threshold 0.7 (round 14, R14-1)
def Laws.seven_tenths_is_0_7():
  {==}

# S4.8 U+1680 is White_Space (round 14, R14-1)
def Laws.is_ws_ogham_space_mark():
  {==}

# S4.8 U+1681 is not White_Space (round 14, R14-1)
def Laws.is_ws_not_after_ogham():
  {==}

# S4.173 plain at k = 16 (round 14, R14-1)
def Laws.json_plain_at_k16():
  {==}

# S4.173 plain at k = 21, JavaScript's boundary (the owner's fix order)
def Laws.json_plain_at_k21():
  {==}

# S4.173 exponent at k = 22 (replaces json_exponent_at_k17)
def Laws.json_exponent_at_k22():
  {==}

# S4.173 plain at k = -5
def Laws.json_plain_at_kneg5():
  {==}

# S4.173 exponent at k = -6
def Laws.json_exponent_at_kneg6():
  {==}

# S4.8 the whole White_Space table, all 25 members (author-side hunt before round 15)
def Laws.is_ws_all_25_members():
  {==}

# S4.8 the table's documented non-members and every boundary neighbour (author-side hunt before round 15)
def Laws.is_ws_documented_non_members():
  {==}

# S5.112 goldens/usage_none
def Laws.golden_usage_none():
  {==}

# S5.112 goldens/usage_version
def Laws.golden_usage_version():
  {==}

# S5.112 goldens/usage_version_short
def Laws.golden_usage_version_short():
  {==}

# S5.112 goldens/usage_unknown_short
def Laws.golden_usage_unknown_short():
  {==}

# S5.112 goldens/usage_conflict_encode_decode
def Laws.golden_usage_conflict_encode_decode():
  {==}

# S5.112 goldens/usage_conflict_decode_encode
def Laws.golden_usage_conflict_decode_encode():
  {==}

# S5.112 goldens/usage_encode_twice
def Laws.golden_usage_encode_twice():
  {==}

# S5.112 goldens/usage_missing_value_delimiter
def Laws.golden_usage_missing_value_delimiter():
  {==}

# S5.112 goldens/usage_missing_value_indent
def Laws.golden_usage_missing_value_indent():
  {==}

# S5.112 goldens/usage_bad_indent_negative
def Laws.golden_usage_bad_indent_negative():
  {==}

# S5.112 goldens/usage_bad_flatten_depth_neg
def Laws.golden_usage_bad_flatten_depth_neg():
  {==}

# S5.112 goldens/flag_delimiter_equals_pipe
def Laws.golden_flag_delimiter_equals_pipe():
  {==}

# S5.112 goldens/encstr_root_string
def Laws.golden_encstr_root_string():
  {==}

# S5.112 goldens/encstr_root_string_quoted
def Laws.golden_encstr_root_string_quoted():
  {==}

# S5.112 goldens/encstr_root_empty_string
def Laws.golden_encstr_root_empty_string():
  {==}

# S5.112 goldens/encstr_root_null
def Laws.golden_encstr_root_null():
  {==}

# S5.112 goldens/encstr_root_bool
def Laws.golden_encstr_root_bool():
  {==}

# S5.112 goldens/decstr_empty_doc
def Laws.golden_decstr_empty_doc():
  {==}

# S5.112 goldens/decstr_blank_doc
def Laws.golden_decstr_blank_doc():
  {==}

# S5.112 goldens/decstr_root_string
def Laws.golden_decstr_root_string():
  {==}

# S5.112 goldens/decstr_root_quoted
def Laws.golden_decstr_root_quoted():
  {==}

# S5.112 goldens/decstr_root_true
def Laws.golden_decstr_root_true():
  {==}

# S5.112 goldens/decstr_root_null
def Laws.golden_decstr_root_null():
  {==}

# S5.112 goldens/decstr_two_primitives
def Laws.golden_decstr_two_primitives():
  {==}

# S5.112 goldens/jsonout_root_empty_array
def Laws.golden_jsonout_root_empty_array():
  {==}

# S5.112 goldens/jsonerr_empty
def Laws.golden_jsonerr_empty():
  {==}

# S5.112 goldens/jsonerr_whitespace
def Laws.golden_jsonerr_whitespace():
  {==}

# S5.112 goldens/jsonerr_open_brace
def Laws.golden_jsonerr_open_brace():
  {==}

# S5.112 goldens/jsonerr_open_bracket
def Laws.golden_jsonerr_open_bracket():
  {==}

# S5.112 goldens/jsonerr_trailing_comma_arr
def Laws.golden_jsonerr_trailing_comma_arr():
  {==}

# S5.112 goldens/jsonerr_missing_value
def Laws.golden_jsonerr_missing_value():
  {==}

# S5.112 goldens/jsonerr_single_quotes
def Laws.golden_jsonerr_single_quotes():
  {==}

# S5.112 goldens/jsonerr_bad_true
def Laws.golden_jsonerr_bad_true():
  {==}

# S5.112 goldens/jsonerr_bad_null
def Laws.golden_jsonerr_bad_null():
  {==}

# S5.112 goldens/jsonerr_bad_ident
def Laws.golden_jsonerr_bad_ident():
  {==}

# S5.112 goldens/jsonerr_dot_end
def Laws.golden_jsonerr_dot_end():
  {==}

# S5.112 goldens/jsonerr_dot_start
def Laws.golden_jsonerr_dot_start():
  {==}

# S5.112 goldens/jsonerr_lone_minus
def Laws.golden_jsonerr_lone_minus():
  {==}

# S5.112 goldens/jsonerr_exp_end
def Laws.golden_jsonerr_exp_end():
  {==}

# S5.112 goldens/jsonerr_plus
def Laws.golden_jsonerr_plus():
  {==}

# S5.112 goldens/jsonerr_unterminated_string
def Laws.golden_jsonerr_unterminated_string():
  {==}

# S5.112 goldens/jsonerr_bad_escape
def Laws.golden_jsonerr_bad_escape():
  {==}

# S5.112 goldens/jsonerr_short_hex
def Laws.golden_jsonerr_short_hex():
  {==}

# S5.112 goldens/jsonerr_bad_hex
def Laws.golden_jsonerr_bad_hex():
  {==}

# S5.112 goldens/jsonerr_lone_high_surrogate
def Laws.golden_jsonerr_lone_high_surrogate():
  {==}

# S5.112 goldens/jsonerr_high_then_bmp
def Laws.golden_jsonerr_high_then_bmp():
  {==}

# S5.112 goldens/jsonerr_lone_low_surrogate
def Laws.golden_jsonerr_lone_low_surrogate():
  {==}

# S5.112 goldens/jsonerr_raw_newline_in_string
def Laws.golden_jsonerr_raw_newline_in_string():
  {==}

# S5.112 goldens/jsonerr_raw_tab_in_string
def Laws.golden_jsonerr_raw_tab_in_string():
  {==}

# S5.112 goldens/jsonerr_trailing_after_obj
def Laws.golden_jsonerr_trailing_after_obj():
  {==}

# S5.112 goldens/jsonerr_nan
def Laws.golden_jsonerr_nan():
  {==}

# S5.112 goldens/jsonerr_infinity
def Laws.golden_jsonerr_infinity():
  {==}

# S5.112 goldens/jsonerr_eof_after_key
def Laws.golden_jsonerr_eof_after_key():
  {==}

# S5.112 goldens/jsonerr_eof_after_colon
def Laws.golden_jsonerr_eof_after_colon():
  {==}

# S5.112 goldens/jsonerr_minus_word
def Laws.golden_jsonerr_minus_word():
  {==}

# S5.112 goldens/jsonerr_upper_true
def Laws.golden_jsonerr_upper_true():
  {==}

# S5.112 goldens/toonerr_blank_in_list
def Laws.golden_toonerr_blank_in_list():
  {==}

# S5.112 goldens/toonerr_extra_list_items
def Laws.golden_toonerr_extra_list_items():
  {==}

# S5.112 goldens/toonerr_too_few_list_items
def Laws.golden_toonerr_too_few_list_items():
  {==}

# S5.112 goldens/toonerr_too_few_inline
def Laws.golden_toonerr_too_few_inline():
  {==}

# S5.112 goldens/toonerr_too_many_inline
def Laws.golden_toonerr_too_many_inline():
  {==}

# S5.112 goldens/toonerr_huge_length
def Laws.golden_toonerr_huge_length():
  {==}

# S5.112 goldens/toonerr_unterminated_value
def Laws.golden_toonerr_unterminated_value():
  {==}

# S5.112 goldens/toonerr_unterminated_key
def Laws.golden_toonerr_unterminated_key():
  {==}

# S5.112 goldens/toonerr_bad_escape
def Laws.golden_toonerr_bad_escape():
  {==}

# S5.112 goldens/toonerr_unicode_escape
def Laws.golden_toonerr_unicode_escape():
  {==}

# S5.112 goldens/toonerr_trailing_backslash
def Laws.golden_toonerr_trailing_backslash():
  {==}

# S5.112 goldens/toonerr_after_closing_quote
def Laws.golden_toonerr_after_closing_quote():
  {==}

# S5.112 goldens/toonerr_tab_indent
def Laws.golden_toonerr_tab_indent():
  {==}

# S5.112 goldens/toonerr_tab_indent_list
def Laws.golden_toonerr_tab_indent_list():
  {==}

# S5.112 goldens/toonerr_missing_close_bracket
def Laws.golden_toonerr_missing_close_bracket():
  {==}

# S5.112 goldens/toonerr_missing_colon_nested
def Laws.golden_toonerr_missing_colon_nested():
  {==}

# S5.112 goldens/toonerr_inline_bad_quote
def Laws.golden_toonerr_inline_bad_quote():
  {==}

# S5.112 goldens/toonerr_list_item_no_space
def Laws.golden_toonerr_list_item_no_space():
  {==}

# S5.112 goldens/toonerr_colon_only
def Laws.golden_toonerr_colon_only():
  {==}

# S5.112 goldens/toonerr_zero_length_with_items
def Laws.golden_toonerr_zero_length_with_items():
  {==}

# S5.112 goldens/toonerr_zero_inline_with_values
def Laws.golden_toonerr_zero_inline_with_values():
  {==}

# S5.112 goldens/toonerr_header_spaces
def Laws.golden_toonerr_header_spaces():
  {==}

# S5.112 goldens/toonerr_header_key_quoted
def Laws.golden_toonerr_header_key_quoted():
  {==}

# S5.112 goldens/toonerr_header_brace_after_colon
def Laws.golden_toonerr_header_brace_after_colon():
  {==}

# S5.112 goldens/toonerr_nested_headers
def Laws.golden_toonerr_nested_headers():
  {==}

# S5.112 goldens/toonerr_mixed_delims
def Laws.golden_toonerr_mixed_delims():
  {==}

# S5.112 goldens/toonerr_list_dash_only
def Laws.golden_toonerr_list_dash_only():
  {==}

# S5.112 goldens/toonerr_object_empty_nested
def Laws.golden_toonerr_object_empty_nested():
  {==}

# S5.112 goldens/toonerr_value_is_header_like
def Laws.golden_toonerr_value_is_header_like():
  {==}

# S5.112 goldens/toonerr_hyphen_value
def Laws.golden_toonerr_hyphen_value():
  {==}

# S5.112 goldens/toonerr_list_at_root_no_header
def Laws.golden_toonerr_list_at_root_no_header():
  {==}

# S5.112 goldens/toonlenient_blank_in_list
def Laws.golden_toonlenient_blank_in_list():
  {==}

# S5.112 goldens/toonlenient_extra_list_items
def Laws.golden_toonlenient_extra_list_items():
  {==}

# S5.112 goldens/toonlenient_too_few_list_items
def Laws.golden_toonlenient_too_few_list_items():
  {==}

# S5.112 goldens/toonlenient_too_few_inline
def Laws.golden_toonlenient_too_few_inline():
  {==}

# S5.112 goldens/toonlenient_too_many_inline
def Laws.golden_toonlenient_too_many_inline():
  {==}

# S5.112 goldens/toonlenient_tab_indent
def Laws.golden_toonlenient_tab_indent():
  {==}

# S5.112 goldens/toonlenient_tab_indent_list
def Laws.golden_toonlenient_tab_indent_list():
  {==}

# S5.112 goldens/toonlenient_zero_length_with_items
def Laws.golden_toonlenient_zero_length_with_items():
  {==}

# S5.112 goldens/toonlenient_zero_inline_with_values
def Laws.golden_toonlenient_zero_inline_with_values():
  {==}

# S5.112 goldens/toonlenient_bad_escape
def Laws.golden_toonlenient_bad_escape():
  {==}

# S5.112 goldens/toonlenient_unterminated_value
def Laws.golden_toonlenient_unterminated_value():
  {==}

# S5.112 goldens/toonlenient_huge_length
def Laws.golden_toonlenient_huge_length():
  {==}

# S5.112 goldens/usage_version_first_wins
def Laws.golden_usage_version_first_wins():
  {==}

# S5.112 goldens/usage_cluster_Vh
def Laws.golden_usage_cluster_Vh():
  {==}

# S5.112 goldens/usage_missing_value_before_flag
def Laws.golden_usage_missing_value_before_flag():
  {==}

# S5.112 goldens/usage_attached_bad_value_first
def Laws.golden_usage_attached_bad_value_first():
  {==}

# S5.112 goldens/usage_attached_twice
def Laws.golden_usage_attached_twice():
  {==}

# S5.112 goldens/usage_flag_with_value
def Laws.golden_usage_flag_with_value():
  {==}

# S5.112 goldens/usage_help_with_value
def Laws.golden_usage_help_with_value():
  {==}

# S5.112 goldens/usage_flag_with_value_after_commit
def Laws.golden_usage_flag_with_value_after_commit():
  {==}

# S5.112 goldens/usage_flag_with_value_after_attached
def Laws.golden_usage_flag_with_value_after_attached():
  {==}

# S5.112 goldens/usage_cluster_conflict
def Laws.golden_usage_cluster_conflict():
  {==}

# S5.112 goldens/usage_cluster_unknown_after_flag
def Laws.golden_usage_cluster_unknown_after_flag():
  {==}

# S5.112 goldens/usage_cluster_digit
def Laws.golden_usage_cluster_digit():
  {==}

# S5.112 goldens/usage_cluster_equals
def Laws.golden_usage_cluster_equals():
  {==}

# S5.112 goldens/usage_negative_number_word
def Laws.golden_usage_negative_number_word():
  {==}

# S5.112 goldens/usage_negative_cluster_first_char
def Laws.golden_usage_negative_cluster_first_char():
  {==}

# S5.112 goldens/usage_unknown_short_uppercase
def Laws.golden_usage_unknown_short_uppercase():
  {==}

# S5.112 goldens/usage_encode_short_and_long
def Laws.golden_usage_encode_short_and_long():
  {==}

# S5.112 goldens/usage_indent_i64_underflow
def Laws.golden_usage_indent_i64_underflow():
  {==}

# S5.112 goldens/jsonerr_eof_after_comma_arr
def Laws.golden_jsonerr_eof_after_comma_arr():
  {==}

# S5.112 goldens/jsonerr_exp_sign_end
def Laws.golden_jsonerr_exp_sign_end():
  {==}

# S5.112 goldens/jsonerr_eof_after_backslash
def Laws.golden_jsonerr_eof_after_backslash():
  {==}

# S5.112 goldens/jsonerr_eof_after_high_surrogate
def Laws.golden_jsonerr_eof_after_high_surrogate():
  {==}

# S5.112 goldens/jsonerr_eof_after_high_surrogate_backslash
def Laws.golden_jsonerr_eof_after_high_surrogate_backslash():
  {==}

# S5.112 goldens/jsonerr_ident_newline
def Laws.golden_jsonerr_ident_newline():
  {==}

# S5.112 goldens/jsonerr_ident_then_more
def Laws.golden_jsonerr_ident_then_more():
  {==}

# S5.112 goldens/jsonerr_short_hex_newline
def Laws.golden_jsonerr_short_hex_newline():
  {==}

# S5.112 goldens/jsonerr_escape_newline
def Laws.golden_jsonerr_escape_newline():
  {==}

# S5.112 goldens/jsonerr_escape_upper_u
def Laws.golden_jsonerr_escape_upper_u():
  {==}

# S5.112 goldens/jsonerr_dot_nondigit
def Laws.golden_jsonerr_dot_nondigit():
  {==}

# S5.112 goldens/jsonerr_dot_newline
def Laws.golden_jsonerr_dot_newline():
  {==}

# S5.112 goldens/jsonerr_exp_nondigit
def Laws.golden_jsonerr_exp_nondigit():
  {==}

# S5.112 goldens/jsonerr_exp_double_sign
def Laws.golden_jsonerr_exp_double_sign():
  {==}

# S5.112 goldens/jsonerr_minus_infinity
def Laws.golden_jsonerr_minus_infinity():
  {==}

# S5.112 goldens/jsonerr_number_then_letter
def Laws.golden_jsonerr_number_then_letter():
  {==}

# S5.112 goldens/jsonerr_hex_number
def Laws.golden_jsonerr_hex_number():
  {==}

# S5.112 goldens/jsonerr_raw_cr_in_string
def Laws.golden_jsonerr_raw_cr_in_string():
  {==}

# S5.112 goldens/jsonerr_obj_leading_comma
def Laws.golden_jsonerr_obj_leading_comma():
  {==}

# S5.112 goldens/jsonerr_arr_leading_comma
def Laws.golden_jsonerr_arr_leading_comma():
  {==}

# S5.112 goldens/jsonerr_arr_comma_then_brace
def Laws.golden_jsonerr_arr_comma_then_brace():
  {==}

# S5.112 goldens/jsonerr_high_then_escape
def Laws.golden_jsonerr_high_then_escape():
  {==}

# S5.112 goldens/jsonerr_high_then_newline
def Laws.golden_jsonerr_high_then_newline():
  {==}

# S5.112 goldens/jsonerr_high_then_bad_hex
def Laws.golden_jsonerr_high_then_bad_hex():
  {==}

# S5.112 goldens/jsonerr_high_then_high
def Laws.golden_jsonerr_high_then_high():
  {==}

# S5.112 goldens/jsonerr_trailing_comma_newline
def Laws.golden_jsonerr_trailing_comma_newline():
  {==}

# S5.112 goldens/jsonerr_trailing_close
def Laws.golden_jsonerr_trailing_close():
  {==}

# S5.112 goldens/jsonerr_cr_not_newline
def Laws.golden_jsonerr_cr_not_newline():
  {==}

# S5.112 goldens/jsonout_empty_in_array
def Laws.golden_jsonout_empty_in_array():
  {==}

# S5.112 goldens/toonedge_crlf_bare_dash
def Laws.golden_toonedge_crlf_bare_dash():
  {==}

# S5.112 goldens/toonedge_header_key_with_colon
def Laws.golden_toonedge_header_key_with_colon():
  {==}

# S5.112 goldens/toonedge_header_in_quoted_value
def Laws.golden_toonedge_header_in_quoted_value():
  {==}

# S5.112 goldens/toonerr_cap_in_quoted_value
def Laws.golden_toonerr_cap_in_quoted_value():
  {==}

# S5.112 goldens/toonerr_length_u64_max_list
def Laws.golden_toonerr_length_u64_max_list():
  {==}

# S5.112 goldens/toonedge_root_vs_item_keyvalue
def Laws.golden_toonedge_root_vs_item_keyvalue():
  {==}

# S5.112 goldens/toonedge_item_quote_hides_colon
def Laws.golden_toonedge_item_quote_hides_colon():
  {==}

# S5.112 goldens/toonedge_list_item_two_spaces_quoted_key
def Laws.golden_toonedge_list_item_two_spaces_quoted_key():
  {==}

# S5.112 goldens/toonerr_count_beats_blank
def Laws.golden_toonerr_count_beats_blank():
  {==}

# S5.112 goldens/toonerr_extra_bare_dash_undetected
def Laws.golden_toonerr_extra_bare_dash_undetected():
  {==}

# S5.112 goldens/toonerr_list_first_field_list_shallow
def Laws.golden_toonerr_list_first_field_list_shallow():
  {==}

# S5.112 goldens/fx_enc_primitives_01
def Laws.golden_fx_enc_primitives_01():
  {==}

# S5.112 goldens/fx_enc_primitives_03
def Laws.golden_fx_enc_primitives_03():
  {==}

# S5.112 goldens/fx_enc_primitives_04
def Laws.golden_fx_enc_primitives_04():
  {==}

# S5.112 goldens/fx_enc_primitives_07
def Laws.golden_fx_enc_primitives_07():
  {==}

# S5.112 goldens/fx_enc_primitives_09
def Laws.golden_fx_enc_primitives_09():
  {==}

# S5.112 goldens/fx_enc_primitives_11
def Laws.golden_fx_enc_primitives_11():
  {==}

# S5.112 goldens/fx_enc_primitives_14
def Laws.golden_fx_enc_primitives_14():
  {==}

# S5.112 goldens/fx_enc_primitives_16
def Laws.golden_fx_enc_primitives_16():
  {==}

# S5.112 goldens/fx_enc_objects_04
def Laws.golden_fx_enc_objects_04():
  {==}

# S5.112 goldens/fx_enc_objects_17
def Laws.golden_fx_enc_objects_17():
  {==}

# S5.112 goldens/fx_enc_objects_20
def Laws.golden_fx_enc_objects_20():
  {==}

# S5.112 goldens/fx_enc_arrays_primitive_01
def Laws.golden_fx_enc_arrays_primitive_01():
  {==}

# S5.112 goldens/fx_enc_arrays_primitive_04
def Laws.golden_fx_enc_arrays_primitive_04():
  {==}

# S5.112 goldens/fx_enc_arrays_primitive_08
def Laws.golden_fx_enc_arrays_primitive_08():
  {==}

# S5.112 goldens/fx_enc_arrays_nested_01
def Laws.golden_fx_enc_arrays_nested_01():
  {==}

# S5.112 goldens/fx_enc_arrays_nested_03
def Laws.golden_fx_enc_arrays_nested_03():
  {==}

# S5.112 goldens/fx_enc_arrays_tabular_02
def Laws.golden_fx_enc_arrays_tabular_02():
  {==}

# S5.112 goldens/fx_enc_arrays_tabular_03
def Laws.golden_fx_enc_arrays_tabular_03():
  {==}

# S5.112 goldens/fx_enc_arrays_objects_15
def Laws.golden_fx_enc_arrays_objects_15():
  {==}

# S5.112 goldens/fx_enc_arrays_objects_02
def Laws.golden_fx_enc_arrays_objects_02():
  {==}

# S5.112 goldens/fx_enc_arrays_objects_10
def Laws.golden_fx_enc_arrays_objects_10():
  {==}

# S5.112 goldens/fx_enc_arrays_objects_13
def Laws.golden_fx_enc_arrays_objects_13():
  {==}

# S5.112 goldens/fx_enc_arrays_objects_14
def Laws.golden_fx_enc_arrays_objects_14():
  {==}

# S5.112 goldens/fx_enc_objects_03
def Laws.golden_fx_enc_objects_03():
  {==}

# S5.112 goldens/fx_enc_objects_25
def Laws.golden_fx_enc_objects_25():
  {==}

# S5.112 goldens/fx_enc_arrays_nested_10
def Laws.golden_fx_enc_arrays_nested_10():
  {==}

# S5.112 goldens/flag_indent_0_encode
def Laws.golden_flag_indent_0_encode():
  {==}

# S5.112 goldens/flag_indent_16_encode
def Laws.golden_flag_indent_16_encode():
  {==}

# S5.112 goldens/fx_enc_whitespace_01
def Laws.golden_fx_enc_whitespace_01():
  {==}

# S5.112 goldens/fx_enc_delimiters_01
def Laws.golden_fx_enc_delimiters_01():
  {==}

# S5.112 goldens/fx_enc_delimiters_02
def Laws.golden_fx_enc_delimiters_02():
  {==}

# S5.112 goldens/fx_enc_delimiters_06
def Laws.golden_fx_enc_delimiters_06():
  {==}

# S5.112 goldens/fx_enc_delimiters_10
def Laws.golden_fx_enc_delimiters_10():
  {==}

# S5.112 goldens/fx_enc_delimiters_16
def Laws.golden_fx_enc_delimiters_16():
  {==}

# S5.112 goldens/fx_enc_delimiters_20
def Laws.golden_fx_enc_delimiters_20():
  {==}

# S5.112 goldens/fx_enc_key_folding_01
def Laws.golden_fx_enc_key_folding_01():
  {==}

# S5.112 goldens/fx_enc_key_folding_03
def Laws.golden_fx_enc_key_folding_03():
  {==}

# S5.112 goldens/fx_enc_key_folding_05
def Laws.golden_fx_enc_key_folding_05():
  {==}

# S5.112 goldens/fx_enc_key_folding_08
def Laws.golden_fx_enc_key_folding_08():
  {==}

# S5.112 goldens/fx_enc_key_folding_12
def Laws.golden_fx_enc_key_folding_12():
  {==}

# S5.112 goldens/fx_enc_key_folding_13
def Laws.golden_fx_enc_key_folding_13():
  {==}

# S5.112 goldens/enc_folding_collision
def Laws.golden_enc_folding_collision():
  {==}

# S5.112 goldens/enc_fold_root_literal_nested
def Laws.golden_enc_fold_root_literal_nested():
  {==}

# S5.112 goldens/enc_fold_budget_threading_5
def Laws.golden_enc_fold_budget_threading_5():
  {==}

# S5.112 goldens/enc_fold_list_item_dup_key
def Laws.golden_enc_fold_list_item_dup_key():
  {==}

# S5.112 goldens/flag_flatten_depth_3
def Laws.golden_flag_flatten_depth_3():
  {==}

# S5.112 goldens/fx_dec_indentation_errors_01
def Laws.golden_fx_dec_indentation_errors_01():
  {==}

# S5.112 goldens/fx_dec_indentation_errors_04
def Laws.golden_fx_dec_indentation_errors_04():
  {==}

# S5.112 goldens/fx_dec_indentation_errors_08
def Laws.golden_fx_dec_indentation_errors_08():
  {==}

# S5.112 goldens/fx_dec_indentation_errors_13
def Laws.golden_fx_dec_indentation_errors_13():
  {==}

# S5.112 goldens/fx_dec_blank_lines_01
def Laws.golden_fx_dec_blank_lines_01():
  {==}

# S5.112 goldens/toonedge_indent4
def Laws.golden_toonedge_indent4():
  {==}

# S5.112 goldens/toonedge_indent0_flat
def Laws.golden_toonedge_indent0_flat():
  {==}

# S5.112 goldens/toonlenient_indent_not_multiple
def Laws.golden_toonlenient_indent_not_multiple():
  {==}

# S5.112 goldens/fx_dec_primitives_01
def Laws.golden_fx_dec_primitives_01():
  {==}

# S5.112 goldens/fx_dec_primitives_04
def Laws.golden_fx_dec_primitives_04():
  {==}

# S5.112 goldens/fx_dec_primitives_08
def Laws.golden_fx_dec_primitives_08():
  {==}

# S5.112 goldens/fx_dec_primitives_19
def Laws.golden_fx_dec_primitives_19():
  {==}

# S5.112 goldens/fx_dec_primitives_22
def Laws.golden_fx_dec_primitives_22():
  {==}

# S5.112 goldens/fx_dec_objects_04
def Laws.golden_fx_dec_objects_04():
  {==}

# S5.112 goldens/fx_dec_objects_17
def Laws.golden_fx_dec_objects_17():
  {==}

# S5.112 goldens/fx_dec_whitespace_01
def Laws.golden_fx_dec_whitespace_01():
  {==}

# S5.112 goldens/fx_dec_whitespace_06
def Laws.golden_fx_dec_whitespace_06():
  {==}

# S5.112 goldens/toonedge_header_in_value_first_bracket_only
def Laws.golden_toonedge_header_in_value_first_bracket_only():
  {==}

# S5.112 goldens/fx_dec_delimiters_01
def Laws.golden_fx_dec_delimiters_01():
  {==}

# S5.112 goldens/fx_dec_delimiters_02
def Laws.golden_fx_dec_delimiters_02():
  {==}

# S5.112 goldens/fx_dec_delimiters_16
def Laws.golden_fx_dec_delimiters_16():
  {==}

# S5.112 goldens/fx_dec_delimiters_21
def Laws.golden_fx_dec_delimiters_21():
  {==}

# S5.112 goldens/toonedge_length_plus_and_zero
def Laws.golden_toonedge_length_plus_and_zero():
  {==}

# S5.112 goldens/toonedge_fields_space_only
def Laws.golden_toonedge_fields_space_only():
  {==}

# S5.112 goldens/fx_dec_numbers_02
def Laws.golden_fx_dec_numbers_02():
  {==}

# S5.112 goldens/fx_dec_numbers_03
def Laws.golden_fx_dec_numbers_03():
  {==}

# S5.112 goldens/fx_dec_numbers_05
def Laws.golden_fx_dec_numbers_05():
  {==}

# S5.112 goldens/fx_dec_numbers_10
def Laws.golden_fx_dec_numbers_10():
  {==}

# S5.112 goldens/fx_dec_numbers_16
def Laws.golden_fx_dec_numbers_16():
  {==}

# S5.112 goldens/fx_dec_numbers_20
def Laws.golden_fx_dec_numbers_20():
  {==}

# S5.112 goldens/fx_dec_arrays_nested_02
def Laws.golden_fx_dec_arrays_nested_02():
  {==}

# S5.112 goldens/fx_dec_arrays_nested_07
def Laws.golden_fx_dec_arrays_nested_07():
  {==}

# S5.112 goldens/fx_dec_arrays_nested_09
def Laws.golden_fx_dec_arrays_nested_09():
  {==}

# S5.112 goldens/fx_dec_objects_03
def Laws.golden_fx_dec_objects_03():
  {==}

# S5.112 goldens/fx_dec_objects_22
def Laws.golden_fx_dec_objects_22():
  {==}

# S5.112 goldens/fx_dec_objects_28
def Laws.golden_fx_dec_objects_28():
  {==}

# S5.112 goldens/fx_dec_root_form_01
def Laws.golden_fx_dec_root_form_01():
  {==}

# S5.112 goldens/fx_dec_arrays_tabular_02
def Laws.golden_fx_dec_arrays_tabular_02():
  {==}

# S5.112 goldens/fx_dec_arrays_tabular_03
def Laws.golden_fx_dec_arrays_tabular_03():
  {==}

# S5.112 goldens/toonedge_data_row_test
def Laws.golden_toonedge_data_row_test():
  {==}

# S5.112 goldens/fx_dec_blank_lines_05
def Laws.golden_fx_dec_blank_lines_05():
  {==}

# S5.112 goldens/fx_dec_blank_lines_11
def Laws.golden_fx_dec_blank_lines_11():
  {==}

# S5.112 goldens/fx_dec_validation_errors_01
def Laws.golden_fx_dec_validation_errors_01():
  {==}

# S5.112 goldens/toonlenient_row_width_short
def Laws.golden_toonlenient_row_width_short():
  {==}

# S5.112 goldens/toonlenient_extra_tabular_rows
def Laws.golden_toonlenient_extra_tabular_rows():
  {==}

# S5.112 goldens/toonlenient_blank_in_tabular
def Laws.golden_toonlenient_blank_in_tabular():
  {==}

# S5.112 goldens/fx_dec_path_expansion_01
def Laws.golden_fx_dec_path_expansion_01():
  {==}

# S5.112 goldens/fx_dec_path_expansion_03
def Laws.golden_fx_dec_path_expansion_03():
  {==}

# S5.112 goldens/fx_dec_path_expansion_05
def Laws.golden_fx_dec_path_expansion_05():
  {==}

# S5.112 goldens/fx_dec_path_expansion_08
def Laws.golden_fx_dec_path_expansion_08():
  {==}

# S5.112 goldens/fx_dec_path_expansion_10
def Laws.golden_fx_dec_path_expansion_10():
  {==}

# S5.112 goldens/fx_dec_path_expansion_11
def Laws.golden_fx_dec_path_expansion_11():
  {==}

# S5.112 goldens/toonedge_expand_quoted_unquoted_same_key
def Laws.golden_toonedge_expand_quoted_unquoted_same_key():
  {==}

# S5.112 goldens/decnum_root_negative_zero
def Laws.golden_decnum_root_negative_zero():
  {==}

# S5.112 goldens/fx_dec_numbers_06
def Laws.golden_fx_dec_numbers_06():
  {==}

# S5.112 goldens/fx_dec_numbers_08
def Laws.golden_fx_dec_numbers_08():
  {==}

# S5.112 goldens/jsonout_root_array
def Laws.golden_jsonout_root_array():
  {==}

# S5.112 goldens/jsonout_duplicate_keys
def Laws.golden_jsonout_duplicate_keys():
  {==}

# S5.112 goldens/flag_decode_indent_0
def Laws.golden_flag_decode_indent_0():
  {==}

# S5.112 goldens/flag_decode_indent_4
def Laws.golden_flag_decode_indent_4():
  {==}

# S5.112 goldens/encnum_root_negative_zero
def Laws.golden_encnum_root_negative_zero():
  {==}

# S5.112 goldens/encnum_overflow_positive
def Laws.golden_encnum_overflow_positive():
  {==}

# S5.112 goldens/encnum_overflow_negative
def Laws.golden_encnum_overflow_negative():
  {==}

# S5.112 goldens/fx_enc_arrays_objects_01
def Laws.golden_fx_enc_arrays_objects_01():
  {==}

# S5.112 goldens/happy_readme_users
def Laws.golden_happy_readme_users():
  {==}

# S5.112 goldens/happy_readme_users_decode
def Laws.golden_happy_readme_users_decode():
  {==}

# S5.112 goldens/flag_delimiter_word_pipe
def Laws.golden_flag_delimiter_word_pipe():
  {==}

# S5.112 goldens/flag_delimiter_backslash_t
def Laws.golden_flag_delimiter_backslash_t():
  {==}

# S5.112 goldens/flag_short_combined_e
def Laws.golden_flag_short_combined_e():
  {==}

# S5.112 goldens/flag_indent_equals
def Laws.golden_flag_indent_equals():
  {==}

# S5.112 goldens/flag_double_dash_only
def Laws.golden_flag_double_dash_only():
  {==}

# S5.112 goldens/flag_no_strict_on_encode_ignored
def Laws.golden_flag_no_strict_on_encode_ignored():
  {==}

# S5.112 goldens/flag_stdin_dash
def Laws.golden_flag_stdin_dash():
  {==}

# S5.112 goldens/flag_stdin_dash_decode
def Laws.golden_flag_stdin_dash_decode():
  {==}

# S2.100 goldens/jsonerr_invalid_utf8_stdin
def Laws.golden_jsonerr_invalid_utf8_stdin():
  {==}

# S2.100 goldens/toonerr_invalid_utf8_stdin
def Laws.golden_toonerr_invalid_utf8_stdin():
  {==}

# S2.100 goldens/jsonerr_overlong_utf8
def Laws.golden_jsonerr_overlong_utf8():
  {==}

# S2.100 goldens/jsonerr_truncated_utf8
def Laws.golden_jsonerr_truncated_utf8():
  {==}

# S7.21 the mutation-test bound
def Laws.div_pow10_even_not_multiple_k1():
  {==}

# S7.21 the mutation-test bound
def Laws.div_pow10_pow2_multiple_k7():
  {==}

# S7.21 the mutation-test bound
def Laws.div_pow10_sticky_from_remainder():
  {==}

# S4.131 the mutation-test bound
def Laws.int_fit_refuses_lost_bit():
  {==}

# S4.131 the mutation-test bound
def Laws.int_fit_accepts_2p48_minus_1():
  {==}

# S4.131 the mutation-test bound
def Laws.int_fit_refuses_2p48():
  {==}

# S4.101 the mutation-test bound
def Laws.int_text_14_digits_ok():
  {==}

# S4.101 the mutation-test bound
def Laws.int_text_15_digits_refused():
  {==}

# S4.101 the mutation-test bound
def Laws.int_text_fraction_refused():
  {==}

# S4.131 the mutation-test bound
def Laws.short_of_digits_drops_trailing_zeros():
  {==}

# S6.10 the mutation-test bound
def Laws.kt_collision_not_member():
  {==}

# S6.10 the mutation-test bound
def Laws.kt_collision_both_members():
  {==}

# S6.10 the mutation-test bound
def Laws.kt_collision_hashes():
  {==}

# S6.10 goldens/encstr_keys_hash_collision
def Laws.golden_collision_keys_encode():
  {==}

# S6.10 goldens/encstr_duplicate_keys
def Laws.golden_encstr_duplicate_keys():
  {==}

# S6.10 goldens/encstr_duplicate_keys_escaped
def Laws.golden_encstr_duplicate_keys_escaped():
  {==}

# S6.10 goldens/encstr_duplicate_keys_replace_container
def Laws.golden_encstr_duplicate_keys_replace_container():
  {==}

# S6.10 the order of keys
def Laws.str_cmp_orders():
  {==}

# S6.10 the bucket's balance
def Laws.ks_bucket_is_balanced():
  {==}

# S6.10 the bucket's members
def Laws.ks_bucket_members():
  {==}

# S4.63 goldens/encstr_fold_hash_collision
def Laws.golden_encstr_fold_hash_collision():
  {==}

# S2.29 goldens/encstr_duplicate_keys_thrice
def Laws.golden_encstr_duplicate_keys_thrice():
  {==}

# S4.243 goldens/toonedge_expand_hash_collision_conflict
def Laws.golden_toonedge_expand_hash_collision_conflict():
  {==}

# S4.246 goldens/toonedge_expand_hash_collision_lenient
def Laws.golden_toonedge_expand_hash_collision_lenient():
  {==}

# S3.25 goldens/toonedge_repeated_keys_hash_collision
def Laws.golden_toonedge_repeated_keys_hash_collision():
  {==}

# S4.245 goldens/toonerr_expand_repeated_hash_collision
def Laws.golden_toonerr_expand_repeated_hash_collision():
  {==}

# S6.10 the bucket's balance, descending
def Laws.ks_bucket_is_balanced_descending():
  {==}

# S6.10 the bucket's members, descending
def Laws.ks_bucket_members_descending():
  {==}

# S1.81 goldens/usage_missing_value_before_mixed_cluster
def Laws.golden_usage_missing_value_before_mixed_cluster():
  {==}

# S1.81 goldens/usage_missing_value_indent_before_mixed_cluster
def Laws.golden_usage_missing_value_indent_before_mixed_cluster():
  {==}

# S1.77 goldens/usage_unknown_first_in_cluster_after_value_option
def Laws.golden_usage_unknown_first_in_cluster_after_value_option():
  {==}

# S1.77 goldens/usage_unknown_digit_cluster_after_value_option
def Laws.golden_usage_unknown_digit_cluster_after_value_option():
  {==}

# S8.2 the kill-switch closes the pass
def Laws.pre_gate_switch(js, j):
  {==}

# S4.130 a rendered number prints the emitter's own text
def Laws.pre_txt_is_num(f, spec, delim, acc):
  {==}

# S2.51 a deferred token prints its own conversion
def Laws.pre_raw_is_num(neg, ints, fracs, eneg, x, spec, delim, acc):
  {==}

# S1.15 the argv scanner's gate: the equality is the arm's body
def Laws.on_neg_takes_the_plain_arm(ch, w, c, p, v):
  {==}

# S1.15 closed
def Laws.on_neg_takes_the_short_arm(ch, w, c, p, v):
  {==}

# S4.130 the pass's printer dispatch on the JSON side: the match reduces on the literal
def Laws.num_text_json_is_show_json(f, spec):
  {==}

# S5.30 the same on the TOON side
def Laws.num_text_toon_is_show_toon(f, spec):
  {==}

# S5.101 dec.done's DOk arm is this call: the equality is the body
def Laws.dec_done_renders_with_the_json_printer(v, indent, spec, stats, text):
  {==}

# ---- the dispatch sweep: each law is one arm of a gate, so the equality is that arm's body ----

# S4.114
def Laws.div_p10_pick_takes_the_fast_quotient(neg, ma, ta, k):
  {==}

# S4.143
def Laws.from_dec_p10_pick_takes_the_spec_reader(eneg, neg, d, eabs):
  {==}

# S4.131
def Laws.dg_step_with_takes_the_fast_step(st, low_ok, high_ok):
  {==}

# S4.131
def Laws.dg_step_with_takes_the_spec_step(st, low_ok, high_ok):
  {==}

# S4.131
def Laws.dg_digit_fast_fin_takes_the_fast_digit(r, s, est):
  {==}

# S4.131
def Laws.dg_digit_fast_fin_takes_the_spec_digit(r, s, est):
  {==}

# S4.143
def Laws.token_short_takes_the_short_value(neg, ints, fracs, e):
  {==}

# S4.143
def Laws.token_short_takes_the_literal(neg, ints, fracs, e, spec):
  {==}

# S2.51
def Laws.num_defer_keeps_the_token_raw(neg, ints, fracs, eneg, x, spec):
  {==}

# S2.51
def Laws.num_defer_converts_now(neg, ints, fracs, eneg, x, spec):
  {==}

# S2.51 (R16-1) computed: 51 integer digits outrun any negative exponent
def Laws.num_safe_wide_ints_refused_when_eneg():
  {==}

# S2.51 (R16-1) computed
def Laws.num_safe_wide_ints_refused_when_epos():
  {==}

# S2.51 (R16-3) computed: the exponent bound is 250, not 300
def Laws.num_safe_big_exponent_refused():
  {==}

# S2.51 computed: the pass still fires on the shapes it exists for
def Laws.num_safe_small_exponent_deferred():
  {==}

# S2.51 computed
def Laws.num_safe_deep_underflow_deferred():
  {==}

# S4.131 computed
def Laws.dg_digit_fast_1limb():
  {==}

# S4.131 computed
def Laws.dg_digit_fast_2limb():
  {==}

# S4.131 computed
def Laws.dg_digit_fast_low():
  {==}

# S4.131 computed
def Laws.dg_digit_fast_exact():
  {==}

# S4.131 computed
def Laws.dg_digit_fast_fallback():
  {==}

# S4.131 computed
def Laws.dg_digit_fast_zero():
  {==}

# S4.64 fc.can reduces to False through Bool.and's first argument, and fold.if(False, ...) is the no-fold verdict
def Laws.fold_off_never_folds(k, v, budget, hs, set, hp, pre, lean, sibs):
  {==}

# S4.64 twin.on(True, _) is False
def Laws.fctx_lean_closed_by_switch(fo):
  {==}

# S3.26 closed: both merges compute to the same entries and failure
def Laws.hot_dups_nested():
  {==}

# S3.26 closed
def Laws.hot_dups_deep():
  {==}

# S3.26 closed
def Laws.hot_dups_strict_conflict():
  {==}

# S5.56 closed
def Laws.write_empty_array():
  {==}

# S5.56 closed
def Laws.write_empty_object():
  {==}

# S5.56, S5.58, S5.60 closed
def Laws.write_nested_indent_2():
  {==}

# S5.58, S5.59 closed
def Laws.write_nested_indent_0():
  {==}

# S2.130 closed
def Laws.hdr_precheck_miss():
  {==}

# S2.130 closed
def Laws.hdr_precheck_hit():
  {==}

# S2.130 closed
def Laws.hdr_precheck_colon_first():
  {==}

# S2.131 closed
def Laws.hdr_precheck_unclosed():
  {==}

# S3.26 closed
def Laws.hot_dups_lenient_overwrite():
  {==}

# S5.30 a rendered number prints the writer's own JSON text
def Laws.pre_txt_is_num_json(f, first, n, depth, spec, acc):
  {==}

# S3.26 the first pending failure stands (R16-2)
def Laws.dup_keep_is_first(m, new):
  {==}

# S4.131 closed: both loops computed
def Laws.dgw_run_third():
  {==}

# S4.131 closed
def Laws.dgw_run_asym():
  {==}

# S4.131 closed
def Laws.dgw_run_half():
  {==}

# S4.131, S4.133 closed
def Laws.dgw_run_tie():
  {==}

# S4.131 closed
def Laws.dgw_run_carry():
  {==}

# S4.131 closed
def Laws.dgw_run_borrow():
  {==}

# S4.131 closed
def Laws.dgw_run_edge64():
  {==}

# S4.131 dg.run.with matches DgK first: one step reaches the body
def Laws.dg_run_with_gate(st, kb, even, fast):
  {==}

# S4.131 the False arm of dg.run.words
def Laws.dg_run_words_spec_arm(st, kb, even, fast):
  {==}

# S4.131 closed
def Laws.dgw_fits_all_at_2p64_minus_1():
  {==}

# S4.131 closed
def Laws.dgw_fits_r_at_2p64():
  {==}

# S4.131 closed
def Laws.dgw_fits_s_at_2p64():
  {==}

# S4.131 closed
def Laws.dgw_fits_mp_at_2p64():
  {==}

# S4.131 closed
def Laws.dgw_fits_mm_at_2p64():
  {==}

# ---- EXP-016: the byte classifier's table (S2.6 value dispatch), each entry computed ----

# S2.6 computed
def Laws.byte_cls_32_is_1():
  {==}

# S2.6 computed
def Laws.byte_cls_10_is_1():
  {==}

# S2.6 computed
def Laws.byte_cls_13_is_1():
  {==}

# S2.6 computed
def Laws.byte_cls_9_is_1():
  {==}

# S2.6 computed
def Laws.byte_cls_44_is_2():
  {==}

# S2.6 computed
def Laws.byte_cls_93_is_3():
  {==}

# S2.6 computed
def Laws.byte_cls_125_is_4():
  {==}

# S2.6 computed
def Laws.byte_cls_58_is_5():
  {==}

# S2.6 computed
def Laws.byte_cls_34_is_6():
  {==}

# S2.6 computed
def Laws.byte_cls_91_is_7():
  {==}

# S2.6 computed
def Laws.byte_cls_123_is_8():
  {==}

# S2.6 computed
def Laws.byte_cls_45_is_9():
  {==}

# S2.6 computed
def Laws.byte_cls_48_is_10():
  {==}

# S2.6 computed
def Laws.byte_cls_49_is_11():
  {==}

# S2.6 computed
def Laws.byte_cls_53_is_11():
  {==}

# S2.6 computed
def Laws.byte_cls_57_is_11():
  {==}

# S2.6 computed
def Laws.byte_cls_110_is_12():
  {==}

# S2.6 computed
def Laws.byte_cls_116_is_13():
  {==}

# S2.6 computed
def Laws.byte_cls_102_is_14():
  {==}

# S2.6 computed
def Laws.byte_cls_92_is_15():
  {==}

# S2.6 computed
def Laws.byte_cls_0_is_0():
  {==}

# S2.6 computed
def Laws.byte_cls_31_is_0():
  {==}

# S2.6 computed
def Laws.byte_cls_33_is_0():
  {==}

# S2.6 computed
def Laws.byte_cls_47_is_0():
  {==}

# S2.6 computed
def Laws.byte_cls_59_is_0():
  {==}

# S2.6 computed
def Laws.byte_cls_97_is_0():
  {==}

# S2.6 computed
def Laws.byte_cls_126_is_0():
  {==}

# S2.6 computed
def Laws.byte_cls_255_is_0():
  {==}

# S4.8 closed
def Laws.ends_ws_empty():
  {==}

# S4.8 closed
def Laws.ends_ws_one_space():
  {==}

# S4.8 closed
def Laws.ends_ws_leading_only():
  {==}

# S4.8 closed
def Laws.ends_ws_trailing_space():
  {==}

# S4.8 closed
def Laws.ends_ws_trailing_ideographic():
  {==}

# S4.8 closed
def Laws.ends_ws_inner_space():
  {==}

# S3.26 closed: both merges computed (R17-1)
def Laws.hot_dups_outer_failure_before_nested():
  {==}

# S3.26, S9.151 closed: the whole pure core computed (R17-1)
def Laws.decode_outer_dup_before_nested_dup():
  {==}

# S2.2, S8.7 closed: computed (EXP-018)
def Laws.utf8_verdict_empty():
  {==}

# S2.2, S8.7 closed: computed (EXP-018)
def Laws.utf8_verdict_ascii_keeps_no_text():
  {==}

# S2.2, S8.7 closed: computed (EXP-018)
def Laws.utf8_verdict_two_byte():
  {==}

# S2.2, S8.7 closed: computed (EXP-018)
def Laws.utf8_verdict_four_byte():
  {==}

# S2.2, S8.7 closed: computed (EXP-018)
def Laws.utf8_verdict_rejects_surrogate():
  {==}

# S2.2, S8.7 closed: computed (EXP-018)
def Laws.utf8_verdict_rejects_overlong():
  {==}

# S2.2, S8.7 closed: computed (EXP-018)
def Laws.utf8_verdict_rejects_cut_short():
  {==}

# S2.2, S8.7 closed: computed (EXP-018)
def Laws.utf8_verdict_rejects_stray_continuation():
  {==}

# S2.2, S8.7 closed: computed (EXP-018)
def Laws.encode_non_ascii_without_stats():
  {==}

# S2.2, S8.7 closed: computed (EXP-018)
def Laws.encode_stats_reads_the_text():
  {==}

# S2.2, S8.7 closed: computed (EXP-018)
def Laws.encode_invalid_utf8_refused():
  {==}

# S5.100 closed: the whole pure core computed (EXP-021)
def Laws.encode_text_zero_lines():
  {==}

# S5.100 closed: the whole pure core computed (EXP-021)
def Laws.encode_text_one_line():
  {==}

# S5.100 closed: the whole pure core computed (EXP-021)
def Laws.encode_text_three_depths():
  {==}

# S5.100 closed: the whole pure core computed (EXP-021)
def Laws.encode_text_tabular_rows():
  {==}

# S5.100 closed: the whole pure core computed (EXP-021)
def Laws.encode_text_list_items():
  {==}

# S2.106 closed: computed (EXP-022)
def Laws.trim_end_nothing_trailing():
  {==}

# S2.106 closed: computed (EXP-022)
def Laws.trim_end_one_space():
  {==}

# S2.106 closed: computed (EXP-022)
def Laws.trim_end_inner_kept():
  {==}

# S2.106 closed: computed (EXP-022)
def Laws.trim_end_ideographic():
  {==}

# S2.106 closed: computed (EXP-022)
def Laws.trim_end_all_space():
  {==}

# S2.106 closed: computed (EXP-022)
def Laws.trim_end_empty():
  {==}

# S2.106 closed: computed (EXP-022)
def Laws.decode_values_trimmed_at_the_end():
  {==}

# S2.122 closed: the whole pure core computed (EXP-024)
def Laws.decode_literal_unterminated_before_bad_escape():
  {==}

# S2.122 closed: the whole pure core computed (EXP-024)
def Laws.decode_literal_trailing_before_bad_escape():
  {==}

# S2.122 closed: the whole pure core computed (EXP-024)
def Laws.decode_literal_bad_escape():
  {==}

# S2.122 closed: the whole pure core computed (EXP-024)
def Laws.decode_literal_five_escapes():
  {==}

# S2.122 closed: the whole pure core computed (EXP-024)
def Laws.decode_literal_escaped_last_quote():
  {==}

# S2.122 closed: the whole pure core computed (EXP-024)
def Laws.decode_literal_empty():
  {==}

# S2.122 closed: the whole pure core computed (EXP-024)
def Laws.decode_literal_tabular_cells():
  {==}

# S2.111 closed: the whole pure core computed (EXP-025)
def Laws.decode_scan_crlf_endings():
  {==}

# S2.111 closed: the whole pure core computed (EXP-025)
def Laws.decode_scan_cr_cr_keeps_one():
  {==}

# S2.111 closed: the whole pure core computed (EXP-025)
def Laws.decode_scan_lone_cr_inside_kept():
  {==}

# S2.111 closed: the whole pure core computed (EXP-025)
def Laws.decode_scan_blank_and_space_lines():
  {==}

# S2.111 closed: the whole pure core computed (EXP-025)
def Laws.decode_scan_tab_in_indent_strict():
  {==}

# S2.111 closed: the whole pure core computed (EXP-025)
def Laws.decode_scan_tab_after_spaces_strict():
  {==}

# S2.111 closed: the whole pure core computed (EXP-025)
def Laws.decode_scan_two_failures_first_wins():
  {==}

# S2.111 closed: the whole pure core computed (EXP-025)
def Laws.decode_scan_tab_lenient():
  {==}

# S2.111 closed: the whole pure core computed (EXP-025)
def Laws.decode_scan_byte_order_mark():
  {==}

# S2.111 closed: the whole pure core computed (EXP-025)
def Laws.decode_scan_byte_order_mark_stats():
  {==}

# S2.111 closed: the whole pure core computed (EXP-025)
def Laws.decode_scan_empty_input():
  {==}

# S2.111 closed: the whole pure core computed (EXP-025)
def Laws.decode_scan_no_final_lf():
  {==}

# S2.113 closed: the whole pure core computed (EXP-025)
def Laws.decode_scan_bare_dash_cr_cr():
  {==}

# S2.113 closed: the whole pure core computed (EXP-025)
def Laws.decode_scan_bare_dash_crlf():
  {==}

# S4.161 closed: both sides computed (EXP-026)
def Laws.is_like_zero():
  {==}

# S4.161 closed: both sides computed (EXP-026)
def Laws.is_like_leading_zeros():
  {==}

# S4.161 closed: both sides computed (EXP-026)
def Laws.is_like_fraction():
  {==}

# S4.161 closed: both sides computed (EXP-026)
def Laws.is_like_signed_exponent():
  {==}

# S4.161 closed: both sides computed (EXP-026)
def Laws.is_like_upper_exponent():
  {==}

# S4.161 closed: both sides computed (EXP-026)
def Laws.is_like_empty():
  {==}

# S4.161 closed: both sides computed (EXP-026)
def Laws.is_like_dash_alone():
  {==}

# S4.161 closed: both sides computed (EXP-026)
def Laws.is_like_dot_end():
  {==}

# S4.161 closed: both sides computed (EXP-026)
def Laws.is_like_e_end():
  {==}

# S4.161 closed: both sides computed (EXP-026)
def Laws.is_like_e_sign_end():
  {==}

# S4.161 closed: both sides computed (EXP-026)
def Laws.is_like_plus_first():
  {==}

# S4.161 closed: both sides computed (EXP-026)
def Laws.is_like_dot_first():
  {==}

# S4.161 closed: both sides computed (EXP-026)
def Laws.is_like_trailing_letter():
  {==}

# S4.161 closed: both sides computed (EXP-026)
def Laws.is_like_fraction_in_exponent():
  {==}

# S4.161 closed: both sides computed (EXP-026)
def Laws.is_like_long_text():
  {==}

# S4.161 closed: both sides computed (EXP-026)
def Laws.encode_numeric_like_items():
  {==}

# S4.161 closed: both sides computed (EXP-026)
def Laws.is_like_zero_fraction():
  {==}

# S4.161 closed: both sides computed (EXP-026)
def Laws.is_like_inner_zero_fraction():
  {==}

# S2.15 the slow arm and step's path for a string state compute the same term (step's first arm cannot match a
# string state)
def Laws.step_in_str_slow_is_step(rev, key, need, part, stack, depth, l, c, root, b):
  {==}

# S2.15 closed: both sides computed (EXP-027)
def Laws.plain_31_refused():
  {==}

# S2.15 closed: both sides computed (EXP-027)
def Laws.plain_32_accepted():
  {==}

# S2.15 closed: both sides computed (EXP-027)
def Laws.plain_33_accepted():
  {==}

# S2.15 closed: both sides computed (EXP-027)
def Laws.plain_34_refused():
  {==}

# S2.15 closed: both sides computed (EXP-027)
def Laws.plain_35_accepted():
  {==}

# S2.15 closed: both sides computed (EXP-027)
def Laws.plain_91_accepted():
  {==}

# S2.15 closed: both sides computed (EXP-027)
def Laws.plain_92_refused():
  {==}

# S2.15 closed: both sides computed (EXP-027)
def Laws.plain_93_accepted():
  {==}

# S2.15 closed: both sides computed (EXP-027)
def Laws.plain_127_accepted():
  {==}

# S2.15 closed: both sides computed (EXP-027)
def Laws.plain_128_refused():
  {==}

# S2.15 closed: both sides computed (EXP-027)
def Laws.step_in_str_fast_value():
  {==}

# S2.15 closed: both sides computed (EXP-027)
def Laws.step_in_str_fast_space():
  {==}

# S2.15 closed: both sides computed (EXP-027)
def Laws.step_in_str_fast_key_pending():
  {==}

# S2.15 closed: both sides computed (EXP-027)
def Laws.encode_plain_string_bytes():
  {==}

# closed: the whole pure core computed (round 18)
# S2.125 closed
def Laws.decode_inline_escaped_quote_before_delimiter():
  {==}

# closed: the whole pure core computed (round 18)
# S2.125 closed
def Laws.decode_tabular_escaped_quote_before_delimiter():
  {==}

# closed: the whole pure core computed (round 18)
# S2.125 closed
def Laws.decode_pipe_escaped_quote_before_delimiter():
  {==}

# closed: the whole pure core computed (round 18)
# S9.105 closed
def Laws.decode_literal_first_of_two_bad_escapes():
  {==}

# closed: the whole pure core computed (round 18)
# S2.126 closed
def Laws.decode_form_feed_before_quoted_key():
  {==}

# closed: the whole pure core computed (round 18)
# S2.132 closed
def Laws.decode_backslash_outside_quotes_in_fields():
  {==}

# S2.28 closed: the whole pure core computed (EXP-029)
def Laws.encode_repeated_key_two_members_repeat_last():
  {==}

# S2.28 closed: the whole pure core computed (EXP-029)
def Laws.encode_repeated_key_seven_members_repeat_first():
  {==}

# S2.28 closed: the whole pure core computed (EXP-029)
def Laws.encode_repeated_key_eight_members_repeat_at_the_switch():
  {==}

# S2.28 closed: the whole pure core computed (EXP-029)
def Laws.encode_repeated_key_nine_members_repeat_after_the_switch():
  {==}

# S2.28 closed: the whole pure core computed (EXP-029)
def Laws.encode_repeated_key_twelve_members_repeat_of_an_early_key():
  {==}

# S2.28 closed: the whole pure core computed (EXP-029)
def Laws.encode_repeated_key_nested_small_objects_repeat():
  {==}

# S2.28 closed: the whole pure core computed (EXP-029)
def Laws.encode_repeated_key_ten_members_repeat_of_the_oldest():
  {==}

# S4.161 closed: the whole pure core computed (round 19)
def Laws.encode_fraction_trailing_zeros_quoted():
  {==}

# S2.113 closed: the whole pure core computed (round 19)
def Laws.decode_final_cr_without_lf():
  {==}

# S8.7 closed: the whole pure core computed (round 19)
def Laws.decode_bom_after_the_first_line_kept():
  {==}

# S2.121 closed: the whole pure core computed (round 19)
def Laws.decode_escaped_quote_before_colon_in_cell():
  {==}

# S4.161 closed: computed (round 19)
def Laws.is_like_zero_in_phase_4_1p50():
  {==}

# S4.161 closed: computed (round 19)
def Laws.is_like_zero_in_phase_4_0p00():
  {==}

# S4.161 closed: computed (round 19)
def Laws.is_like_zero_in_phase_4_1p05e5():
  {==}

# S9.10 closed: the whole pure core computed (EXP-031)
def Laws.decode_invalid_utf8_after_toon_error():
  {==}

# S9.10 closed: the whole pure core computed (EXP-031)
def Laws.decode_truncated_utf8_at_the_end():
  {==}

# S8.7 closed: the whole pure core computed (EXP-031)
def Laws.decode_stats_after_mark_multibyte():
  {==}

# S9.10 closed: the whole pure core computed (EXP-031/032)
def Laws.encode_invalid_utf8_after_json_error():
  {==}

# S9.10 closed: the whole pure core computed (EXP-031/032)
def Laws.encode_truncated_utf8_after_json_error():
  {==}

# S9.10 closed: the whole pure core computed (EXP-031/032)
def Laws.encode_stats_invalid_utf8_in_key():
  {==}

# S8.7 closed: the whole pure core computed (EXP-031/032)
def Laws.encode_stats_after_mark():
  {==}

# S8.7 closed: the whole pure core computed (EXP-031/032)
def Laws.encode_stats_two_marks_is_json_error():
  {==}

# S2.28 closed: the whole pure core computed (round 20)
def Laws.encode_repeated_key_the_member_that_builds_the_set():
  {==}

# S2.28 closed: the whole pure core computed (round 20)
def Laws.encode_repeated_key_the_builder_and_the_next():
  {==}

# S2.28 closed: the whole pure core computed (round 20)
def Laws.encode_repeated_key_the_builder_nested():
  {==}

# S4.14 closed: the whole pure core computed (round 20)
def Laws.encode_brackets_and_braces_force_quotes():
  {==}

# S4.8 closed: the whole pure core computed (round 20)
def Laws.encode_edge_whitespace_forces_quotes():
  {==}

# S4.161 closed: the whole pure core computed (round 20)
def Laws.encode_exponents_and_signed_integers_quoted():
  {==}

# S4.161 closed: computed (round 20)
def Laws.is_like_exponent_zero_digit():
  {==}

# S4.161 closed: computed (round 20)
def Laws.is_like_exponent_ten():
  {==}

# S4.161 closed: computed (round 20)
def Laws.is_like_signed_integer():
  {==}

# S4.161 closed: the whole pure core computed (round 20)
def Laws.encode_leading_zero_digits_quoted():
  {==}

# S4.161 closed: computed (round 20)
def Laws.is_like_leading_zero_then_digit():
  {==}

# S4.36 closed: the whole pure core computed (round 21)
def Laws.encode_reordered_row_with_nested_object_is_list_form():
  {==}

# S4.36 closed: the whole pure core computed (round 21)
def Laws.encode_reordered_row_with_nested_array_is_list_form():
  {==}

# S4.14 closed: the whole pure core computed (round 21)
def Laws.encode_close_bracket_quote_backslash_force_quotes():
  {==}

# S4.161 closed: the whole pure core computed (round 21)
def Laws.encode_signed_exponents_and_zero_mantissa_quoted():
  {==}

# S4.35 closed: the whole pure core computed (round 21)
def Laws.encode_array_of_empty_objects_is_list_form():
  {==}

# S4.36 closed: the whole pure core computed (round 21)
def Laws.encode_row_missing_a_header_key_is_list_form():
  {==}

# S2.18 closed: the whole pure core computed (round 21)
def Laws.encode_escaped_solidus_reads_as_slash():
  {==}

# S4.9 closed: the whole pure core computed (round 21)
def Laws.encode_null_true_false_strings_quoted():
  {==}

# S2.18 closed: the whole pure core computed (round 22)
def Laws.encode_json_backspace_and_form_feed_escapes():
  {==}

# S4.21 closed: the whole pure core computed (round 22)
def Laws.encode_underscore_initial_keys_are_bare():
  {==}

# S4.36 closed: the whole pure core computed (round 22)
def Laws.encode_short_row_in_header_order_is_list_form():
  {==}

# S4.42 closed: the whole pure core computed (round 22)
def Laws.encode_array_of_objects_as_list_item_is_list_form():
  {==}

# S4.21 closed: the whole pure core computed (round 23)
def Laws.encode_key_later_char_range_ends():
  {==}

# S2.137 closed: the whole pure core computed (round 23)
def Laws.decode_empty_field_between_names():
  {==}

# S2.137 closed: the whole pure core computed (round 23)
def Laws.decode_empty_last_field_name():
  {==}

# S2.133 closed: the whole pure core computed (round 23)
def Laws.decode_bracket_then_equals_is_key():
  {==}

# S2.123 closed: the whole pure core computed (round 23)
def Laws.decode_quoted_key_cr_escape():
  {==}

# S2.19 closed: the whole pure core computed (round 23)
def Laws.encode_hex_escape_letter_ends():
  {==}

# S2.21 closed: the whole pure core computed (round 23)
def Laws.encode_surrogate_pairs_at_both_ends():
  {==}

# S4.48 closed: the whole pure core computed (round 23)
def Laws.encode_list_item_first_field_tabular():
  {==}

# S4.214 closed: the whole pure core computed (round 23)
def Laws.decode_colon_line_ends_tabular_rows():
  {==}

# S2.139 closed: the whole pure core computed (round 23)
def Laws.decode_values_after_fields_header_refused():
  {==}

# S2.132 closed: the whole pure core computed (round 23)
def Laws.decode_open_quote_in_fields_segment():
  {==}

# S2.123 closed: the whole pure core computed (round 23)
def Laws.decode_unknown_escape_in_quoted_key():
  {==}

# S5.66 closed: the whole pure core computed (round 23)
def Laws.decode_json_writer_lower_case_hex_controls():
  {==}

# S2.133 closed: the whole pure core computed (round 24)
def Laws.decode_semicolon_after_fields_refused():
  {==}

# S2.133 closed: the whole pure core computed (round 24)
def Laws.decode_space_and_tab_before_header_colon():
  {==}

# S2.137 closed: the whole pure core computed (round 24)
def Laws.decode_quoted_field_not_expanded():
  {==}

# S2.123 closed: the whole pure core computed (round 24)
def Laws.decode_quoted_key_four_escapes():
  {==}

# S2.137 closed: the whole pure core computed (round 24)
def Laws.decode_bare_field_expanded():
  {==}

# S4.78 closed: the whole pure core computed (round 24)
def Laws.encode_fold_budget_in_list_item():
  {==}

# S4.79 closed: the whole pure core computed (round 24)
def Laws.encode_flatten_depth_two_folds():
  {==}

# S4.21 closed: the whole pure core computed (round 24)
def Laws.encode_upper_case_initial_keys_are_bare():
  {==}

# S4.222 closed: the whole pure core computed (round 25)
def Laws.decode_list_item_ws_before_nested_array():
  {==}

# S4.214 closed: the whole pure core computed (round 25)
def Laws.decode_colon_before_delimiter_not_a_row():
  {==}

# S4.214 closed: the whole pure core computed (round 25)
def Laws.decode_delimiter_before_colon_is_a_row():
  {==}

# S9.152 closed: the whole pure core computed (round 25)
def Laws.decode_list_line_after_full_table():
  {==}

# S1.156 closed: the whole pure core computed (round 25)
def Laws.argv_negative_exponent_dot_word():
  {==}

# S1.156 closed: the whole pure core computed (round 25)
def Laws.argv_negative_trailing_exponent_word():
  {==}

# S1.156 closed: the whole pure core computed (round 25)
def Laws.argv_flatten_depth_negative_value():
  {==}

# S4.217 closed: the whole pure core computed (round 25)
def Laws.decode_lenient_sibling_after_full_table():
  {==}

# S4.225 closed: the whole pure core computed (round 25)
def Laws.decode_bare_dash_sibling_over_indented():
  {==}

# S4.213 closed: the whole pure core computed (round 25)
def Laws.decode_blank_line_inside_table_refused():
  {==}

# S1.8 closed: the argv tokenizer computed (round 25)
def Laws.argv_output_equals_removed():
  {==}

# S4.212 closed: the whole pure core computed (round 26)
def Laws.decode_deeper_row_not_a_row():
  {==}

# S4.215 closed: the whole pure core computed (round 26)
def Laws.decode_deeper_item_not_an_item():
  {==}

# S9.152 closed: the whole pure core computed (round 26)
def Laws.decode_deeper_line_after_full_table():
  {==}

# S4.213 closed: the whole pure core computed (round 26)
def Laws.decode_blank_before_surplus_row():
  {==}

# S1.156 closed: the whole pure core computed (round 26)
def Laws.argv_negative_leading_dot_word():
  {==}

# S1.156 closed: the whole pure core computed (round 26)
def Laws.argv_negative_two_dots_word():
  {==}

# S9.154 closed: the whole pure core computed (round 26)
def Laws.decode_indentation_jump_refused():
  {==}

# S9.109 closed: the whole pure core computed (round 26)
def Laws.decode_narrow_row_refused():
  {==}


# S4.71 closed: the whole pure core computed (round 26)
def Laws.encode_fold_prefix_is_parent_path():
  {==}

# S4.79 closed: the whole pure core computed (round 27)
def Laws.encode_flatten_depth_100_folds_100():
  {==}

# S2.3 closed: the whole pure core computed (round 27)
def Laws.encode_ef_bb_not_a_bom():
  {==}

# S4.71 closed: the whole pure core computed (round 27)
def Laws.encode_partial_fold_keeps_enclosing_prefix():
  {==}

# S1.156 closed: the whole pure core computed (round 27)
def Laws.argv_indent_negative_exponent_word():
  {==}

# S4.70 closed: the whole pure core computed (round 27)
def Laws.encode_nested_body_sibling_set():
  {==}

# S2.2 closed: the whole pure core computed (round 28)
def Laws.utf8_verdict_rejects_last_overlong_3byte():
  {==}

# S2.2 closed: the whole pure core computed (round 28)
def Laws.utf8_verdict_rejects_last_overlong_4byte():
  {==}

# S2.2 closed: the whole pure core computed (round 28)
def Laws.utf8_verdict_rejects_c0_continuation():
  {==}

# S2.2 closed: the whole pure core computed (round 28)
def Laws.utf8_verdict_rejects_above_max():
  {==}

# S1.31 closed: the whole pure core computed (round 28)
def Laws.argv_indent_i64_min():
  {==}

# S1.31 closed: the whole pure core computed (round 28)
def Laws.argv_indent_i64_max():
  {==}

# S1.31 closed: the whole pure core computed (round 28)
def Laws.argv_flatten_depth_u64_max():
  {==}

# S1.40 closed: the whole pure core computed (round 28)
def Laws.argv_key_folding_similar_picks_best():
  {==}

# S1.40 closed: the whole pure core computed (round 28)
def Laws.argv_key_folding_similar_tie():
  {==}

# S3.20 closed: the whole pure core computed (round 28)
def Laws.decode_list_item_first_tabular_then_field():
  {==}

# S2.135 closed: the whole pure core computed (round 29)
def Laws.decode_bracket_only_delimiter_is_key():
  {==}

# S2.130 closed: the whole pure core computed (round 29)
def Laws.decode_char_after_quoted_key_refused():
  {==}

# S2.2 closed: the whole pure core computed (round 29)
def Laws.utf8_verdict_rejects_last_surrogate():
  {==}

# S7.21 closed: the whole pure core computed (round 29)
def Laws.bn_limbs_down_sticky():
  {==}

# S4.244 closed: the whole pure core computed (round 29)
def Laws.decode_expand_conflict_names_object_first():
  {==}

# S1.31 closed: the whole pure core computed (round 29)
def Laws.argv_indent_minus_zero():
  {==}

# S2.132 closed: the whole pure core computed (round 30)
def Laws.decode_escaped_quote_in_quoted_field_name():
  {==}

# S3.26 closed: the whole pure core computed (round 30)
def Laws.decode_duplicate_field_name_refused():
  {==}

# S2.132 closed: the whole pure core computed (round 30)
def Laws.decode_spaces_after_fields_colon():
  {==}

# S2.135 closed: the whole pure core computed (round 30)
def Laws.decode_empty_brackets_are_a_key():
  {==}

# S4.19 the escape classifier on its five bytes: each side computes (toon_bend-tqz)
def Laws.escape_class_of_backslash():
  {==}

# S4.19 as above, the quote
def Laws.escape_class_of_quote():
  {==}

# S4.19 as above, the line feed
def Laws.escape_class_of_lf():
  {==}

# S4.19 as above, the carriage return
def Laws.escape_class_of_cr():
  {==}

# S4.19 as above, the tab
def Laws.escape_class_of_tab():
  {==}

# S4.19/S2.123 the round trip, one escape at a time. Each side reduces to the same term: the escaper's
# output for a known class is two closed bytes, `String.reverse` on a closed pair computes, appending onto
# the quantified continuation exposes both bytes as constructors, and the unescaper's two steps (the
# backslash arming the escape, the letter discharging it) leave the quantified state with exactly the
# original byte prepended. No induction is needed for the step; the composition along a string is
# `unesc.go`'s own recursion, and is golden-tested rather than proved (see the section's note in LAWS.bend).
def Laws.escape_step_backslash(rest, rev, badc):
  {==}

# S4.19/S2.123 as above, the quote: `\"` back to one quote
def Laws.escape_step_quote(rest, rev, badc):
  {==}

# S4.19/S2.123 as above, the line feed: `\n` back to byte 10
def Laws.escape_step_lf(rest, rev, badc):
  {==}

# S4.19/S2.123 as above, the carriage return: `\r` back to byte 13
def Laws.escape_step_cr(rest, rev, badc):
  {==}

# S4.19/S2.123 as above, the tab: `\t` back to byte 9
def Laws.escape_step_tab(rest, rev, badc):
  {==}

# S4.19/S2.123 the plain class on a representative byte: copied through, no escape armed
def Laws.escape_step_plain(rest, rev, badc):
  {==}

# S5.63/S2.18 the JSON escape round trip, one arm at a time (toon_bend-tqz). Each side reduces to the same
# term: the writer's output for a known class is closed bytes, `String.reverse` and `T.ascii_bytes` on a
# closed string compute, and the reader's steps (the backslash arming the escape through `MEsc`, the letter
# discharging it through `J.esc`) carry the stack, the depth, the line, the root and the key flag untouched
# while prepending the original byte and advancing the column once per byte read. The case split on `spec` is
# what the kill-switch costs: `J.run`'s string arm consults `F.twin.on(spec, plain(b))` (EXP-027), and a
# backslash is not plain, so both settings take the same path — the checker needs the two cases to see it.
def Laws.json_escape_round_trip_quote(rev, key, stack, depth, l, c, root, spec):
  match spec:
    case True{}:
      {==}
    case False{}:
      {==}

# S5.63/S2.18 as above, the backslash
def Laws.json_escape_round_trip_backslash(rev, key, stack, depth, l, c, root, spec):
  match spec:
    case True{}:
      {==}
    case False{}:
      {==}

# S5.63/S2.18 as above, the backspace
def Laws.json_escape_round_trip_backspace(rev, key, stack, depth, l, c, root, spec):
  match spec:
    case True{}:
      {==}
    case False{}:
      {==}

# S5.63/S2.18 as above, the tab
def Laws.json_escape_round_trip_tab(rev, key, stack, depth, l, c, root, spec):
  match spec:
    case True{}:
      {==}
    case False{}:
      {==}

# S5.63/S2.18 as above, the line feed
def Laws.json_escape_round_trip_lf(rev, key, stack, depth, l, c, root, spec):
  match spec:
    case True{}:
      {==}
    case False{}:
      {==}

# S5.63/S2.18 as above, the form feed
def Laws.json_escape_round_trip_formfeed(rev, key, stack, depth, l, c, root, spec):
  match spec:
    case True{}:
      {==}
    case False{}:
      {==}

# S5.63/S2.18 as above, the carriage return
def Laws.json_escape_round_trip_cr(rev, key, stack, depth, l, c, root, spec):
  match spec:
    case True{}:
      {==}
    case False{}:
      {==}

# S5.63/S2.18 the hex arm: six bytes out, four digits walked back through MHex
def Laws.json_escape_round_trip_hex_01(rev, key, stack, depth, l, c, root, spec):
  match spec:
    case True{}:
      {==}
    case False{}:
      {==}

# S5.63/S2.18 the hex arm on a byte whose digits reach `hexc`'s letter branch
def Laws.json_escape_round_trip_hex_1f(rev, key, stack, depth, l, c, root, spec):
  match spec:
    case True{}:
      {==}
    case False{}:
      {==}

# S5.63/S2.18 the raw arm, the one byte EXP-027's fast path decides
def Laws.json_escape_round_trip_plain_A(rev, key, stack, depth, l, c, root, spec):
  match spec:
    case True{}:
      {==}
    case False{}:
      {==}
