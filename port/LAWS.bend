# toon — the laws. HUMAN-OWNED: an agent may add a law, never weaken or delete one. Every law names
# the spec clause it encodes. Kinds:
#   fast == spec   binds every fast twin to its spec twin (none exists before Phase 5)
#   first wins     the first failure, or the finished root value, ends a pass, whatever follows
#   mode           a flag decides regardless of every other input
#   closed golden  a small input whose expected output is pasted from goldens/ or from a spec clause
#                  — the checker computes both sides
# What does NOT belong here: anything the checker must normalize through a large Peano Nat (byte
# values as Nat, long digit strings, whole documents through the JSON reader): those stay in goldens/
# and conform.sh. The scaffold's placeholder law over its stub core was replaced together with the stub.
import Base
import ./bignat.bend as BN
import ./text.bend as T
import ./json.bend as J
import ./decode.bend as D
import ./cli.bend as C

# ---------------------------------------------------------------- first failure wins

# S1.4 the first report ends the argv scan: a stopped scan ignores every later token
law argv_stop_is_sticky:
  for code: Nat
  for out: String
  for err: String
  for t: C.Tok
  {C.on.tok(C.PStop{code, out, err}, t) == C.PStop{code, out, err} : C.PS}

# S9.141, S10.80 the first decode failure ends the pass: the lines that remain are never parsed
law decode_error_ends_pass:
  for ls: List<&2, D.Line>
  for b: Nat
  for msg: String
  {D.run(ls, b, D.SErr{msg}) == D.DErr{msg} : D.DR}

# S4.202, S4.204, S10.81 once the root value is complete every remaining line is ignored
law decode_root_ends_pass:
  for ls: List<&2, D.Line>
  for b: Nat
  for v: J.Json
  {D.run(ls, b, D.SDone{v}) == D.DOk{v} : D.DR}

# S2.45 the JSON reader's first error is sticky: later bytes cannot change it
law json_error_is_sticky:
  for msg: String
  for el: Nat
  for ec: Nat
  for stack: List<&2, J.Frame>
  for depth: Nat
  for l: Nat
  for c: Nat
  for root: Maybe<&2, J.Json>
  for b: U32
  {J.step(J.St{J.MErr{msg, el, ec}, stack, depth, l, c, root}, b) == J.St{J.MErr{msg, el, ec}, stack, depth, l, c, root} : J.St}

# ---------------------------------------------------------------- modes

# S4.213, S4.215, S4.217 lenient mode never reports a body check (count, blank line, surplus)
law lenient_body_never_fails:
  for short: Bool
  for blank: Nat
  for surplus: Bool
  for tab: Bool
  for n: Nat
  for cnt: Nat
  {D.close.msg(False{}, short, blank, surplus, tab, n, cnt) == None{} : Maybe<&2, String>}

# S2.112 lenient scanning never fails
law lenient_scan_never_fails:
  for tab: Bool
  for num: Nat
  for unit: Nat
  for indent: Nat
  {D.scan.check(None{}, False{}, tab, num, unit, indent) == None{} : Maybe<&2, String>}

# S4.300 (1), S1.155 --encode always selects encode, whatever the extension says
law encode_flag_wins:
  for dec: Bool
  for has_in: Bool
  for e: String
  {C.mode.decode(True{}, dec, has_in, e) == False{} : Bool}

# S4.300 (2) without --encode, --decode always selects decode
law decode_flag_wins:
  for has_in: Bool
  for e: String
  {C.mode.decode(False{}, True{}, has_in, e) == True{} : Bool}

# S4.303 stdin has no extension: without a flag and without an INPUT path the mode is encode
law stdin_defaults_to_encode:
  for e: String
  {C.mode.decode(False{}, False{}, False{}, e) == False{} : Bool}

# S4.314, S5.108 no Saved line when the TOON estimate is not smaller
law no_saved_line_without_savings:
  for j: Nat
  for t: Nat
  {C.stats.saved(False{}, j, t) == SNil{} : String}

# S4.248 no expansion step runs with the depth counter at 256
law expansion_cap_on_values:
  for v: J.Json
  for strict: Bool
  {D.expand(v, D.XVal{0n}, strict) == D.EErr{"Path expansion exceeded maximum depth of 256"} : D.ER}

# S4.248 nor a merge or a literal insertion
law expansion_cap_on_merges:
  for tgt: D.ER
  for src: J.Json
  for strict: Bool
  {D.plan(0n, tgt, src, strict) == D.ACap{} : D.Act}

# ---------------------------------------------------------------- closed goldens

# S7.21 a carry runs through every limb
law bn_add_carry:
  {BN.add([65535, 65535], [1], 0) == [0, 0, 1] : List<&2, U32>}

# S2.107 depth = floor(indent / I), and 0 when I = 0
law depth_of_indent:
  {D.scan.depth(7n, 2n) == 3n : Nat}

# S2.107
law depth_with_indent_zero:
  {D.scan.depth(5n, 0n) == 0n : Nat}

# S4.317 stats_small: the TOON text of the README example estimates to 6 tokens
law stats_estimate_small:
  {C.est("name: Alice\nage: 30\ntags[2]: a,b") == 6n : Nat}

# S4.310 the estimate is never 0
law stats_estimate_empty:
  {C.est("") == 1n : Nat}

# S4.316 a tie goes to the even digit: 6.25 prints as 6.2 (OQ-003)
law stats_pct_6_25:
  {C.percent(1n, 16n) == "6.2" : String}

# S4.316 and 18.75 prints as 18.8
law stats_pct_18_75:
  {C.percent(3n, 16n) == "18.8" : String}

# S4.315 two binary64 operations, not the exact ratio: 23/80 prints 28.7 (exact 28.75 would print 28.8)
law stats_pct_double_rounding:
  {C.percent(23n, 80n) == "28.7" : String}

# ---------------------------------------------------------------- closed goldens of the WHOLE pure core
#
# Each law below is one case of goldens/cases.tsv, pasted from its captured files: argv, the input
# bytes, and the original's exit code, stdout and stderr (without the final LF that the shell's stderr
# write appends). Both sides are computed by the checker's normalizer, a fifth executor beside the four
# lanes, through C.run_pure: argv parser, UTF-8 gate, JSON reader or TOON scanner and decoder, encoder
# or JSON writer, error texts. Selection: ASCII input of at most 110 bytes, no input file, no -o, no
# --stats, and no number on the path (the software binary64 carries 100000-biased exponents, which the
# normalizer holds in unary: those cases stay with conform.sh). Law names are golden_<case name>.

# S5.112 goldens/usage_none
law golden_usage_none:
  {C.run_pure([], T.ascii_bytes("", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 0"} : C.Out}

# S5.112 goldens/usage_version
law golden_usage_version:
  {C.run_pure(["--version"], T.ascii_bytes("", Nil{})) == C.Out{0n, "toon 0.2.4\n", ""} : C.Out}

# S5.112 goldens/usage_version_short
law golden_usage_version_short:
  {C.run_pure(["-V"], T.ascii_bytes("", Nil{})) == C.Out{0n, "toon 0.2.4\n", ""} : C.Out}

# S5.112 goldens/usage_unknown_short
law golden_usage_unknown_short:
  {C.run_pure(["-x"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected argument '-x' found\n\n  tip: to pass '-x' as a value, use '-- -x'\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_conflict_encode_decode
law golden_usage_conflict_encode_decode:
  {C.run_pure(["-e", "-d"], T.ascii_bytes("{\"name\":\"Alice\",\"age\":30,\"tags\":[\"a\",\"b\"]}\n", Nil{})) == C.Out{2n, "", "error: the argument '--encode' cannot be used with '--decode'\n\nUsage: toon --encode [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_conflict_decode_encode
law golden_usage_conflict_decode_encode:
  {C.run_pure(["--decode", "--encode"], T.ascii_bytes("{\"name\":\"Alice\",\"age\":30,\"tags\":[\"a\",\"b\"]}\n", Nil{})) == C.Out{2n, "", "error: the argument '--decode' cannot be used with '--encode'\n\nUsage: toon --decode [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_encode_twice
law golden_usage_encode_twice:
  {C.run_pure(["-e", "-e"], T.ascii_bytes("{\"name\":\"Alice\",\"age\":30,\"tags\":[\"a\",\"b\"]}\n", Nil{})) == C.Out{2n, "", "error: the argument '--encode' cannot be used multiple times\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_missing_value_delimiter
law golden_usage_missing_value_delimiter:
  {C.run_pure(["--delimiter"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: a value is required for '--delimiter <DELIMITER>' but none was supplied\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_missing_value_indent
law golden_usage_missing_value_indent:
  {C.run_pure(["--indent"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: a value is required for '--indent <INDENT>' but none was supplied\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_bad_indent_negative
law golden_usage_bad_indent_negative:
  {C.run_pure(["--encode", "--indent=-1"], T.ascii_bytes("{\"name\":\"Alice\",\"age\":30,\"tags\":[\"a\",\"b\"]}\n", Nil{})) == C.Out{2n, "", "error: invalid value '-1' for '--indent <INDENT>': -1 is not in 0..=16\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_bad_flatten_depth_neg
law golden_usage_bad_flatten_depth_neg:
  {C.run_pure(["--encode", "--flatten-depth=-1"], T.ascii_bytes("{\"name\":\"Alice\",\"age\":30,\"tags\":[\"a\",\"b\"]}\n", Nil{})) == C.Out{2n, "", "error: invalid value '-1' for '--flatten-depth <N>': invalid digit found in string\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/flag_delimiter_equals_pipe
law golden_flag_delimiter_equals_pipe:
  {C.run_pure(["--encode", "--delimiter=|"], T.ascii_bytes("{\"t\":[\"a\",\"b\"]}\n", Nil{})) == C.Out{0n, "t[2|]: a|b\n", ""} : C.Out}

# S5.112 goldens/encstr_root_string
law golden_encstr_root_string:
  {C.run_pure(["--encode"], T.ascii_bytes("\"hello world\"\n", Nil{})) == C.Out{0n, "hello world\n", ""} : C.Out}

# S5.112 goldens/encstr_root_string_quoted
law golden_encstr_root_string_quoted:
  {C.run_pure(["--encode"], T.ascii_bytes("\"true\"\n", Nil{})) == C.Out{0n, "\"true\"\n", ""} : C.Out}

# S5.112 goldens/encstr_root_empty_string
law golden_encstr_root_empty_string:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\"\n", Nil{})) == C.Out{0n, "\"\"\n", ""} : C.Out}

# S5.112 goldens/encstr_root_null
law golden_encstr_root_null:
  {C.run_pure(["--encode"], T.ascii_bytes("null\n", Nil{})) == C.Out{0n, "null\n", ""} : C.Out}

# S5.112 goldens/encstr_root_bool
law golden_encstr_root_bool:
  {C.run_pure(["--encode"], T.ascii_bytes("false\n", Nil{})) == C.Out{0n, "false\n", ""} : C.Out}

# S5.112 goldens/decstr_empty_doc
law golden_decstr_empty_doc:
  {C.run_pure(["--decode"], T.ascii_bytes("", Nil{})) == C.Out{0n, "{}\n", ""} : C.Out}

# S5.112 goldens/decstr_blank_doc
law golden_decstr_blank_doc:
  {C.run_pure(["--decode"], T.ascii_bytes("\n\n  \n", Nil{})) == C.Out{0n, "{}\n", ""} : C.Out}

# S5.112 goldens/decstr_root_string
law golden_decstr_root_string:
  {C.run_pure(["--decode"], T.ascii_bytes("hello world", Nil{})) == C.Out{0n, "\"hello world\"\n", ""} : C.Out}

# S5.112 goldens/decstr_root_quoted
law golden_decstr_root_quoted:
  {C.run_pure(["--decode"], T.ascii_bytes("\"a: b\"", Nil{})) == C.Out{0n, "\"a: b\"\n", ""} : C.Out}

# S5.112 goldens/decstr_root_true
law golden_decstr_root_true:
  {C.run_pure(["--decode"], T.ascii_bytes("true", Nil{})) == C.Out{0n, "true\n", ""} : C.Out}

# S5.112 goldens/decstr_root_null
law golden_decstr_root_null:
  {C.run_pure(["--decode"], T.ascii_bytes("null", Nil{})) == C.Out{0n, "null\n", ""} : C.Out}

# S5.112 goldens/decstr_two_primitives
law golden_decstr_two_primitives:
  {C.run_pure(["--decode"], T.ascii_bytes("hello\nworld\n", Nil{})) == C.Out{1n, "", "Missing colon after key"} : C.Out}

# S5.112 goldens/jsonout_root_empty_array
law golden_jsonout_root_empty_array:
  {C.run_pure(["--decode"], T.ascii_bytes("[0]:", Nil{})) == C.Out{0n, "[]\n", ""} : C.Out}

# S5.112 goldens/jsonerr_empty
law golden_jsonerr_empty:
  {C.run_pure(["--encode"], T.ascii_bytes("", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 0"} : C.Out}

# S5.112 goldens/jsonerr_whitespace
law golden_jsonerr_whitespace:
  {C.run_pure(["--encode"], T.ascii_bytes("  \n\t\n", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 3 column 0"} : C.Out}

# S5.112 goldens/jsonerr_open_brace
law golden_jsonerr_open_brace:
  {C.run_pure(["--encode"], T.ascii_bytes("{", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing an object at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_open_bracket
law golden_jsonerr_open_bracket:
  {C.run_pure(["--encode"], T.ascii_bytes("[", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a list at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_trailing_comma_arr
law golden_jsonerr_trailing_comma_arr:
  {C.run_pure(["--encode"], T.ascii_bytes("[1,]", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: trailing comma at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_missing_value
law golden_jsonerr_missing_value:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"invalid\": }", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected value at line 1 column 13"} : C.Out}

# S5.112 goldens/jsonerr_single_quotes
law golden_jsonerr_single_quotes:
  {C.run_pure(["--encode"], T.ascii_bytes("'a'", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected value at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_bad_true
law golden_jsonerr_bad_true:
  {C.run_pure(["--encode"], T.ascii_bytes("tru", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_bad_null
law golden_jsonerr_bad_null:
  {C.run_pure(["--encode"], T.ascii_bytes("nul", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_bad_ident
law golden_jsonerr_bad_ident:
  {C.run_pure(["--encode"], T.ascii_bytes("nope", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected ident at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_dot_end
law golden_jsonerr_dot_end:
  {C.run_pure(["--encode"], T.ascii_bytes("1.", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_dot_start
law golden_jsonerr_dot_start:
  {C.run_pure(["--encode"], T.ascii_bytes(".5", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected value at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_lone_minus
law golden_jsonerr_lone_minus:
  {C.run_pure(["--encode"], T.ascii_bytes("-", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_exp_end
law golden_jsonerr_exp_end:
  {C.run_pure(["--encode"], T.ascii_bytes("1e", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_plus
law golden_jsonerr_plus:
  {C.run_pure(["--encode"], T.ascii_bytes("+1", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected value at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_unterminated_string
law golden_jsonerr_unterminated_string:
  {C.run_pure(["--encode"], T.ascii_bytes("\"abc", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a string at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_bad_escape
law golden_jsonerr_bad_escape:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\x\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid escape at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_short_hex
law golden_jsonerr_short_hex:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\u12\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a string at line 1 column 6"} : C.Out}

# S5.112 goldens/jsonerr_bad_hex
law golden_jsonerr_bad_hex:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\u12zz\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid escape at line 1 column 7"} : C.Out}

# S5.112 goldens/jsonerr_lone_high_surrogate
law golden_jsonerr_lone_high_surrogate:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: unexpected end of hex escape at line 1 column 8"} : C.Out}

# S5.112 goldens/jsonerr_high_then_bmp
law golden_jsonerr_high_then_bmp:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\\u0041\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: lone leading surrogate in hex escape at line 1 column 13"} : C.Out}

# S5.112 goldens/jsonerr_lone_low_surrogate
law golden_jsonerr_lone_low_surrogate:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\udc00\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: lone leading surrogate in hex escape at line 1 column 7"} : C.Out}

# S5.112 goldens/jsonerr_raw_newline_in_string
law golden_jsonerr_raw_newline_in_string:
  {C.run_pure(["--encode"], T.ascii_bytes("\"a\nb\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: control character (\\u0000-\\u001F) found while parsing a string at line 2 column 0"} : C.Out}

# S5.112 goldens/jsonerr_raw_tab_in_string
law golden_jsonerr_raw_tab_in_string:
  {C.run_pure(["--encode"], T.ascii_bytes("\"a\tb\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: control character (\\u0000-\\u001F) found while parsing a string at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_trailing_after_obj
law golden_jsonerr_trailing_after_obj:
  {C.run_pure(["--encode"], T.ascii_bytes("{} x", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: trailing characters at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_nan
law golden_jsonerr_nan:
  {C.run_pure(["--encode"], T.ascii_bytes("NaN", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected value at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_infinity
law golden_jsonerr_infinity:
  {C.run_pure(["--encode"], T.ascii_bytes("Infinity", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected value at line 1 column 1"} : C.Out}

# S5.112 goldens/jsonerr_eof_after_key
law golden_jsonerr_eof_after_key:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"a\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing an object at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_eof_after_colon
law golden_jsonerr_eof_after_colon:
  {C.run_pure(["--encode"], T.ascii_bytes("{\"a\":", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 5"} : C.Out}

# S5.112 goldens/jsonerr_minus_word
law golden_jsonerr_minus_word:
  {C.run_pure(["--encode"], T.ascii_bytes("-x", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid number at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_upper_true
law golden_jsonerr_upper_true:
  {C.run_pure(["--encode"], T.ascii_bytes("TRUE", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected value at line 1 column 1"} : C.Out}

# S5.112 goldens/toonerr_blank_in_list
law golden_toonerr_blank_in_list:
  {C.run_pure(["--decode"], T.ascii_bytes("items[2]:\n  - a\n\n  - b", Nil{})) == C.Out{1n, "", "Line 3: Blank lines inside list array are not allowed in strict mode"} : C.Out}

# S5.112 goldens/toonerr_extra_list_items
law golden_toonerr_extra_list_items:
  {C.run_pure(["--decode"], T.ascii_bytes("items[1]:\n  - a\n  - b", Nil{})) == C.Out{1n, "", "Expected 1 list array items, but found more"} : C.Out}

# S5.112 goldens/toonerr_too_few_list_items
law golden_toonerr_too_few_list_items:
  {C.run_pure(["--decode"], T.ascii_bytes("items[3]:\n  - a", Nil{})) == C.Out{1n, "", "Expected 3 list array items, but got 1"} : C.Out}

# S5.112 goldens/toonerr_too_few_inline
law golden_toonerr_too_few_inline:
  {C.run_pure(["--decode"], T.ascii_bytes("items[3]: a,b", Nil{})) == C.Out{1n, "", "Expected 3 inline array items, but got 2"} : C.Out}

# S5.112 goldens/toonerr_too_many_inline
law golden_toonerr_too_many_inline:
  {C.run_pure(["--decode"], T.ascii_bytes("items[1]: a,b", Nil{})) == C.Out{1n, "", "Expected 1 inline array items, but got 2"} : C.Out}

# S5.112 goldens/toonerr_huge_length
law golden_toonerr_huge_length:
  {C.run_pure(["--decode"], T.ascii_bytes("items[9999999999]:", Nil{})) == C.Out{1n, "", "Declared array length 9999999999 exceeds maximum allowed (100000000)"} : C.Out}

# S5.112 goldens/toonerr_unterminated_value
law golden_toonerr_unterminated_value:
  {C.run_pure(["--decode"], T.ascii_bytes("name: \"unterminated", Nil{})) == C.Out{1n, "", "Unterminated string: missing closing quote"} : C.Out}

# S5.112 goldens/toonerr_unterminated_key
law golden_toonerr_unterminated_key:
  {C.run_pure(["--decode"], T.ascii_bytes("\"unterminated key: value", Nil{})) == C.Out{1n, "", "Unterminated string: missing closing quote"} : C.Out}

# S5.112 goldens/toonerr_bad_escape
law golden_toonerr_bad_escape:
  {C.run_pure(["--decode"], T.ascii_bytes("name: \"bad \\x escape\"", Nil{})) == C.Out{1n, "", "Invalid escape sequence: \\x"} : C.Out}

# S5.112 goldens/toonerr_unicode_escape
law golden_toonerr_unicode_escape:
  {C.run_pure(["--decode"], T.ascii_bytes("name: \"\\u0041\"", Nil{})) == C.Out{1n, "", "Invalid escape sequence: \\u"} : C.Out}

# S5.112 goldens/toonerr_trailing_backslash
law golden_toonerr_trailing_backslash:
  {C.run_pure(["--decode"], T.ascii_bytes("name: \"abc\\", Nil{})) == C.Out{1n, "", "Unterminated string: missing closing quote"} : C.Out}

# S5.112 goldens/toonerr_after_closing_quote
law golden_toonerr_after_closing_quote:
  {C.run_pure(["--decode"], T.ascii_bytes("name: \"abc\" def", Nil{})) == C.Out{1n, "", "Unexpected characters after closing quote"} : C.Out}

# S5.112 goldens/toonerr_tab_indent
law golden_toonerr_tab_indent:
  {C.run_pure(["--decode"], T.ascii_bytes("\tname: value", Nil{})) == C.Out{1n, "", "Validation error at line 1: Tabs are not allowed in indentation in strict mode"} : C.Out}

# S5.112 goldens/toonerr_tab_indent_list
law golden_toonerr_tab_indent_list:
  {C.run_pure(["--decode"], T.ascii_bytes("items[1]:\n\t- a", Nil{})) == C.Out{1n, "", "Validation error at line 2: Tabs are not allowed in indentation in strict mode"} : C.Out}

# S5.112 goldens/toonerr_missing_close_bracket
law golden_toonerr_missing_close_bracket:
  {C.run_pure(["--decode"], T.ascii_bytes("items[3: a,b,c", Nil{})) == C.Out{0n, "{\n  \"items[3\": \"a,b,c\"\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_missing_colon_nested
law golden_toonerr_missing_colon_nested:
  {C.run_pure(["--decode"], T.ascii_bytes("o:\n  bare\n", Nil{})) == C.Out{1n, "", "Missing colon after key"} : C.Out}

# S5.112 goldens/toonerr_inline_bad_quote
law golden_toonerr_inline_bad_quote:
  {C.run_pure(["--decode"], T.ascii_bytes("items[2]: \"a,b", Nil{})) == C.Out{1n, "", "Unterminated string: missing closing quote"} : C.Out}

# S5.112 goldens/toonerr_list_item_no_space
law golden_toonerr_list_item_no_space:
  {C.run_pure(["--decode"], T.ascii_bytes("items[1]:\n  -a", Nil{})) == C.Out{1n, "", "Expected 1 list array items, but got 0"} : C.Out}

# S5.112 goldens/toonerr_colon_only
law golden_toonerr_colon_only:
  {C.run_pure(["--decode"], T.ascii_bytes(":\n", Nil{})) == C.Out{0n, "{\n  \"\": {}\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_zero_length_with_items
law golden_toonerr_zero_length_with_items:
  {C.run_pure(["--decode"], T.ascii_bytes("items[0]:\n  - a\n", Nil{})) == C.Out{1n, "", "Expected 0 list array items, but found more"} : C.Out}

# S5.112 goldens/toonerr_zero_inline_with_values
law golden_toonerr_zero_inline_with_values:
  {C.run_pure(["--decode"], T.ascii_bytes("items[0]: a\n", Nil{})) == C.Out{1n, "", "Expected 0 inline array items, but got 1"} : C.Out}

# S5.112 goldens/toonerr_header_spaces
law golden_toonerr_header_spaces:
  {C.run_pure(["--decode"], T.ascii_bytes("items [2] : a,b\n", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\",\n    \"b\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_header_key_quoted
law golden_toonerr_header_key_quoted:
  {C.run_pure(["--decode"], T.ascii_bytes("\"my items\"[2]: a,b\n", Nil{})) == C.Out{0n, "{\n  \"my items\": [\n    \"a\",\n    \"b\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_header_brace_after_colon
law golden_toonerr_header_brace_after_colon:
  {C.run_pure(["--decode"], T.ascii_bytes("k[1]: {a}\n", Nil{})) == C.Out{0n, "{\n  \"k\": [\n    \"{a}\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_nested_headers
law golden_toonerr_nested_headers:
  {C.run_pure(["--decode"], T.ascii_bytes("a[1]:\n  - [1]:\n    - [1]: x\n", Nil{})) == C.Out{0n, "{\n  \"a\": [\n    [\n      [\n        \"x\"\n      ]\n    ]\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_mixed_delims
law golden_toonerr_mixed_delims:
  {C.run_pure(["--decode"], T.ascii_bytes("t[2|]: a,b|c\n", Nil{})) == C.Out{0n, "{\n  \"t\": [\n    \"a,b\",\n    \"c\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_list_dash_only
law golden_toonerr_list_dash_only:
  {C.run_pure(["--decode"], T.ascii_bytes("l[2]:\n  -\n  - \n", Nil{})) == C.Out{0n, "{\n  \"l\": [\n    {},\n    {}\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_object_empty_nested
law golden_toonerr_object_empty_nested:
  {C.run_pure(["--decode"], T.ascii_bytes("a:\nb:\n  c:\n", Nil{})) == C.Out{0n, "{\n  \"a\": {},\n  \"b\": {\n    \"c\": {}\n  }\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_value_is_header_like
law golden_toonerr_value_is_header_like:
  {C.run_pure(["--decode"], T.ascii_bytes("a: [2]: x\n", Nil{})) == C.Out{1n, "", "Expected 2 inline array items, but got 1"} : C.Out}

# S5.112 goldens/toonerr_hyphen_value
law golden_toonerr_hyphen_value:
  {C.run_pure(["--decode"], T.ascii_bytes("a: - b\n", Nil{})) == C.Out{0n, "{\n  \"a\": \"- b\"\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_list_at_root_no_header
law golden_toonerr_list_at_root_no_header:
  {C.run_pure(["--decode"], T.ascii_bytes("- a\n- b\n", Nil{})) == C.Out{1n, "", "Missing colon after key"} : C.Out}

# S5.112 goldens/toonlenient_blank_in_list
law golden_toonlenient_blank_in_list:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[2]:\n  - a\n\n  - b", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\",\n    \"b\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_extra_list_items
law golden_toonlenient_extra_list_items:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[1]:\n  - a\n  - b", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_too_few_list_items
law golden_toonlenient_too_few_list_items:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[3]:\n  - a", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_too_few_inline
law golden_toonlenient_too_few_inline:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[3]: a,b", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\",\n    \"b\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_too_many_inline
law golden_toonlenient_too_many_inline:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[1]: a,b", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\",\n    \"b\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_tab_indent
law golden_toonlenient_tab_indent:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("\tname: value", Nil{})) == C.Out{0n, "{\n  \"name\": \"value\"\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_tab_indent_list
law golden_toonlenient_tab_indent_list:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[1]:\n\t- a", Nil{})) == C.Out{1n, "", "Missing colon after key"} : C.Out}

# S5.112 goldens/toonlenient_zero_length_with_items
law golden_toonlenient_zero_length_with_items:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[0]:\n  - a\n", Nil{})) == C.Out{0n, "{\n  \"items\": []\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_zero_inline_with_values
law golden_toonlenient_zero_inline_with_values:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[0]: a\n", Nil{})) == C.Out{0n, "{\n  \"items\": [\n    \"a\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonlenient_bad_escape
law golden_toonlenient_bad_escape:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("name: \"bad \\x escape\"", Nil{})) == C.Out{1n, "", "Invalid escape sequence: \\x"} : C.Out}

# S5.112 goldens/toonlenient_unterminated_value
law golden_toonlenient_unterminated_value:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("name: \"unterminated", Nil{})) == C.Out{1n, "", "Unterminated string: missing closing quote"} : C.Out}

# S5.112 goldens/toonlenient_huge_length
law golden_toonlenient_huge_length:
  {C.run_pure(["--decode", "--no-strict"], T.ascii_bytes("items[9999999999]:", Nil{})) == C.Out{1n, "", "Declared array length 9999999999 exceeds maximum allowed (100000000)"} : C.Out}

# S5.112 goldens/usage_version_first_wins
law golden_usage_version_first_wins:
  {C.run_pure(["--version", "--help"], T.ascii_bytes("", Nil{})) == C.Out{0n, "toon 0.2.4\n", ""} : C.Out}

# S5.112 goldens/usage_cluster_Vh
law golden_usage_cluster_Vh:
  {C.run_pure(["-Vh"], T.ascii_bytes("", Nil{})) == C.Out{0n, "toon 0.2.4\n", ""} : C.Out}

# S5.112 goldens/usage_missing_value_before_flag
law golden_usage_missing_value_before_flag:
  {C.run_pure(["--indent", "--encode"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: a value is required for '--indent <INDENT>' but none was supplied\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_attached_bad_value_first
law golden_usage_attached_bad_value_first:
  {C.run_pure(["--indent=99", "--indent=2"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: invalid value '99' for '--indent <INDENT>': 99 is not in 0..=16\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_attached_twice
law golden_usage_attached_twice:
  {C.run_pure(["--indent=2", "--indent=99"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: the argument '--indent <INDENT>' cannot be used multiple times\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_flag_with_value
law golden_usage_flag_with_value:
  {C.run_pure(["--encode=1"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected value '1' for '--encode' found; no more were expected\n\nUsage: toon --encode [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_help_with_value
law golden_usage_help_with_value:
  {C.run_pure(["--help=x"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected value 'x' for '--help' found; no more were expected\n\nUsage: toon --help [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_flag_with_value_after_commit
law golden_usage_flag_with_value_after_commit:
  {C.run_pure(["-e", "--stats=yes"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected value 'yes' for '--stats' found; no more were expected\n\nUsage: toon <INPUT|--output <FILE>|--encode|--decode|--delimiter <DELIMITER>|--indent <INDENT>|--no-strict|--key-folding <KEY_FOLDING>|--flatten-depth <N>|--expand-paths <EXPAND_PATHS>|--stats>\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_flag_with_value_after_attached
law golden_usage_flag_with_value_after_attached:
  {C.run_pure(["--indent=4", "--stats=yes"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected value 'yes' for '--stats' found; no more were expected\n\nUsage: toon <INPUT|--output <FILE>|--encode|--decode|--delimiter <DELIMITER>|--indent <INDENT>|--no-strict|--key-folding <KEY_FOLDING>|--flatten-depth <N>|--expand-paths <EXPAND_PATHS>|--stats>\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_cluster_conflict
law golden_usage_cluster_conflict:
  {C.run_pure(["-ed"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: the argument '--encode' cannot be used with '--decode'\n\nUsage: toon --encode [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_cluster_unknown_after_flag
law golden_usage_cluster_unknown_after_flag:
  {C.run_pure(["-ex"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected argument '-x' found\n\n  tip: to pass '-x' as a value, use '-- -x'\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_cluster_digit
law golden_usage_cluster_digit:
  {C.run_pure(["-e5"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected argument '-5' found\n\n  tip: to pass '-5' as a value, use '-- -5'\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_cluster_equals
law golden_usage_cluster_equals:
  {C.run_pure(["-e=x"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected argument '-=' found\n\n  tip: to pass '-=' as a value, use '-- -='\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_negative_number_word
law golden_usage_negative_number_word:
  {C.run_pure(["--indent", "-1"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected argument '-1' found\n\n  tip: to pass '-1' as a value, use '-- -1'\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_negative_cluster_first_char
law golden_usage_negative_cluster_first_char:
  {C.run_pure(["--indent", "-129"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected argument '-1' found\n\n  tip: to pass '-1' as a value, use '-- -1'\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_unknown_short_uppercase
law golden_usage_unknown_short_uppercase:
  {C.run_pure(["-E"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: unexpected argument '-E' found\n\n  tip: to pass '-E' as a value, use '-- -E'\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_encode_short_and_long
law golden_usage_encode_short_and_long:
  {C.run_pure(["-e", "--encode"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: the argument '--encode' cannot be used multiple times\n\nUsage: toon [OPTIONS] [INPUT]\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/usage_indent_i64_underflow
law golden_usage_indent_i64_underflow:
  {C.run_pure(["--indent=-9223372036854775809"], T.ascii_bytes("", Nil{})) == C.Out{2n, "", "error: invalid value '-9223372036854775809' for '--indent <INDENT>': number too small to fit in target type\n\nFor more information, try '--help'."} : C.Out}

# S5.112 goldens/jsonerr_eof_after_comma_arr
law golden_jsonerr_eof_after_comma_arr:
  {C.run_pure(["--encode"], T.ascii_bytes("[1,", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_exp_sign_end
law golden_jsonerr_exp_sign_end:
  {C.run_pure(["--encode"], T.ascii_bytes("1e+", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_eof_after_backslash
law golden_jsonerr_eof_after_backslash:
  {C.run_pure(["--encode"], T.ascii_bytes("\"abc\\", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a string at line 1 column 5"} : C.Out}

# S5.112 goldens/jsonerr_eof_after_high_surrogate
law golden_jsonerr_eof_after_high_surrogate:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a string at line 1 column 7"} : C.Out}

# S5.112 goldens/jsonerr_eof_after_high_surrogate_backslash
law golden_jsonerr_eof_after_high_surrogate_backslash:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\\", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: EOF while parsing a string at line 1 column 8"} : C.Out}

# S5.112 goldens/jsonerr_ident_newline
law golden_jsonerr_ident_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("tru\n", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected ident at line 2 column 0"} : C.Out}

# S5.112 goldens/jsonerr_ident_then_more
law golden_jsonerr_ident_then_more:
  {C.run_pure(["--encode"], T.ascii_bytes("nulll", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: trailing characters at line 1 column 5"} : C.Out}

# S5.112 goldens/jsonerr_short_hex_newline
law golden_jsonerr_short_hex_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\u12\"\n", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid escape at line 2 column 0"} : C.Out}

# S5.112 goldens/jsonerr_escape_newline
law golden_jsonerr_escape_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\\n\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid escape at line 2 column 0"} : C.Out}

# S5.112 goldens/jsonerr_escape_upper_u
law golden_jsonerr_escape_upper_u:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\U0041\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid escape at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_dot_nondigit
law golden_jsonerr_dot_nondigit:
  {C.run_pure(["--encode"], T.ascii_bytes("[1.]", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid number at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_dot_newline
law golden_jsonerr_dot_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("1.\n", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid number at line 2 column 0"} : C.Out}

# S5.112 goldens/jsonerr_exp_nondigit
law golden_jsonerr_exp_nondigit:
  {C.run_pure(["--encode"], T.ascii_bytes("[1e]", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid number at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_exp_double_sign
law golden_jsonerr_exp_double_sign:
  {C.run_pure(["--encode"], T.ascii_bytes("1e+-1", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid number at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_minus_infinity
law golden_jsonerr_minus_infinity:
  {C.run_pure(["--encode"], T.ascii_bytes("-Infinity", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid number at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_number_then_letter
law golden_jsonerr_number_then_letter:
  {C.run_pure(["--encode"], T.ascii_bytes("[1x]", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected `,` or `]` at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_hex_number
law golden_jsonerr_hex_number:
  {C.run_pure(["--encode"], T.ascii_bytes("0x10", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: trailing characters at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_raw_cr_in_string
law golden_jsonerr_raw_cr_in_string:
  {C.run_pure(["--encode"], T.ascii_bytes("\"a\rb\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: control character (\\u0000-\\u001F) found while parsing a string at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_obj_leading_comma
law golden_jsonerr_obj_leading_comma:
  {C.run_pure(["--encode"], T.ascii_bytes("{,}", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: key must be a string at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_arr_leading_comma
law golden_jsonerr_arr_leading_comma:
  {C.run_pure(["--encode"], T.ascii_bytes("[,]", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected value at line 1 column 2"} : C.Out}

# S5.112 goldens/jsonerr_arr_comma_then_brace
law golden_jsonerr_arr_comma_then_brace:
  {C.run_pure(["--encode"], T.ascii_bytes("[1,}", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected value at line 1 column 4"} : C.Out}

# S5.112 goldens/jsonerr_high_then_escape
law golden_jsonerr_high_then_escape:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\\n\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: unexpected end of hex escape at line 1 column 9"} : C.Out}

# S5.112 goldens/jsonerr_high_then_newline
law golden_jsonerr_high_then_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\n\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: unexpected end of hex escape at line 2 column 0"} : C.Out}

# S5.112 goldens/jsonerr_high_then_bad_hex
law golden_jsonerr_high_then_bad_hex:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\\uzzzz\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: invalid escape at line 1 column 13"} : C.Out}

# S5.112 goldens/jsonerr_high_then_high
law golden_jsonerr_high_then_high:
  {C.run_pure(["--encode"], T.ascii_bytes("\"\\ud800\\ud800\"", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: lone leading surrogate in hex escape at line 1 column 13"} : C.Out}

# S5.112 goldens/jsonerr_trailing_comma_newline
law golden_jsonerr_trailing_comma_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("[1,\n]", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: trailing comma at line 2 column 1"} : C.Out}

# S5.112 goldens/jsonerr_trailing_close
law golden_jsonerr_trailing_close:
  {C.run_pure(["--encode"], T.ascii_bytes("[]]", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: trailing characters at line 1 column 3"} : C.Out}

# S5.112 goldens/jsonerr_cr_not_newline
law golden_jsonerr_cr_not_newline:
  {C.run_pure(["--encode"], T.ascii_bytes("[1,\r\r oops]", Nil{})) == C.Out{1n, "", "JSON error: Failed to parse JSON: expected value at line 1 column 7"} : C.Out}

# S5.112 goldens/jsonout_empty_in_array
law golden_jsonout_empty_in_array:
  {C.run_pure(["--decode"], T.ascii_bytes("[4]:\n  -\n  - [0]:\n  - [1]:\n    - [0]:\n  - k:\n    l[0]:\n", Nil{})) == C.Out{0n, "[\n  {},\n  [],\n  [\n    []\n  ],\n  {\n    \"k\": {},\n    \"l\": []\n  }\n]\n", ""} : C.Out}

# S5.112 goldens/toonedge_crlf_bare_dash
law golden_toonedge_crlf_bare_dash:
  {C.run_pure(["--decode"], T.ascii_bytes("x[1]:\r\n  -\r\n", Nil{})) == C.Out{1n, "", "Expected 1 list array items, but got 0"} : C.Out}

# S5.112 goldens/toonedge_header_key_with_colon
law golden_toonedge_header_key_with_colon:
  {C.run_pure(["--decode"], T.ascii_bytes("a: [1]: x\n", Nil{})) == C.Out{0n, "{\n  \"a:\": [\n    \"x\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonedge_header_in_quoted_value
law golden_toonedge_header_in_quoted_value:
  {C.run_pure(["--decode"], T.ascii_bytes("a: \"x[1]: y\"\n", Nil{})) == C.Out{0n, "{\n  \"a: \\\"x\": [\n    \"y\\\"\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_cap_in_quoted_value
law golden_toonerr_cap_in_quoted_value:
  {C.run_pure(["--decode"], T.ascii_bytes("note: \"see [999999999999]: x\"\n", Nil{})) == C.Out{1n, "", "Declared array length 999999999999 exceeds maximum allowed (100000000)"} : C.Out}

# S5.112 goldens/toonerr_length_u64_max_list
law golden_toonerr_length_u64_max_list:
  {C.run_pure(["--decode"], T.ascii_bytes("items[18446744073709551615]:\n", Nil{})) == C.Out{1n, "", "Declared array length 18446744073709551615 exceeds maximum allowed (100000000)"} : C.Out}

# S5.112 goldens/toonedge_root_vs_item_keyvalue
law golden_toonedge_root_vs_item_keyvalue:
  {C.run_pure(["--decode"], T.ascii_bytes("a\"b: c\n", Nil{})) == C.Out{0n, "{\n  \"a\\\"b\": \"c\"\n}\n", ""} : C.Out}

# S5.112 goldens/toonedge_item_quote_hides_colon
law golden_toonedge_item_quote_hides_colon:
  {C.run_pure(["--decode"], T.ascii_bytes("l[1]:\n  - a\"b: c\n", Nil{})) == C.Out{0n, "{\n  \"l\": [\n    \"a\\\"b: c\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonedge_list_item_two_spaces_quoted_key
law golden_toonedge_list_item_two_spaces_quoted_key:
  {C.run_pure(["--decode"], T.ascii_bytes("l[1]:\n  -  \"a\": b\n", Nil{})) == C.Out{0n, "{\n  \"l\": [\n    {\n      \"\\\"a\\\"\": \"b\"\n    }\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_count_beats_blank
law golden_toonerr_count_beats_blank:
  {C.run_pure(["--decode"], T.ascii_bytes("l[3]:\n  - a\n\n  - b\n", Nil{})) == C.Out{1n, "", "Expected 3 list array items, but got 2"} : C.Out}

# S5.112 goldens/toonerr_extra_bare_dash_undetected
law golden_toonerr_extra_bare_dash_undetected:
  {C.run_pure(["--decode"], T.ascii_bytes("l[1]:\n  - a\n  -\n", Nil{})) == C.Out{0n, "{\n  \"l\": [\n    \"a\"\n  ]\n}\n", ""} : C.Out}

# S5.112 goldens/toonerr_list_first_field_list_shallow
law golden_toonerr_list_first_field_list_shallow:
  {C.run_pure(["--decode"], T.ascii_bytes("l[1]:\n  - k[2]:\n    - a\n    - b\n", Nil{})) == C.Out{1n, "", "Expected 2 list array items, but got 0"} : C.Out}
