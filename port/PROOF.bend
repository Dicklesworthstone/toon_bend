# toon — the proofs. The agent's file: imports the code and the laws and fills every law with
# `def Laws.<name>(params)`. Lemmas go above their first use. Gate:  bend PROOF.bend  →
# "All terms check." (state the unsafe count from the same output beside every parity claim).
import Base
import ./bignat.bend as BN
import ./text.bend as T
import ./json.bend as J
import ./decode.bend as D
import ./cli.bend as C
import ./LAWS.bend as Laws

# S1.4 the first arm of on.tok matches a stopped scan whatever the token is
def Laws.argv_stop_is_sticky(code, out, err, t):
  {==}

# S9.141 run scrutinizes the lines, then the bound, then the step: by cases on the first two, every
# arm that meets a failure returns it
def Laws.decode_error_ends_pass(ls, b, msg):
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

# S4.202 the same cases; every arm that meets the root value returns it
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

# S2.45 the first arm of step
def Laws.json_error_is_sticky(msg, el, ec, stack, depth, l, c, root, b):
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

# ---------------------------------------------------------------- closed goldens of the whole pure core:
# every one is proved by computation

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
