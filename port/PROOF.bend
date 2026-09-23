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
