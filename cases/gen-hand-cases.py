#!/usr/bin/env python3
"""gen-hand-cases.py: the hand-designed conformance cases (everything the spec fixtures do not reach).

Writes  cases/inputs/hand/<case>.<ext>   stdin bytes per case
        cases/inputs/hand/files/*        files passed as the INPUT argument (mode auto-detection)
        cases/hand-cases.tsv             rows for goldens/cases.tsv

Classes: usage, flagform, autodetect, stats, enc-number, dec-number, enc-string, dec-string,
json-error, toon-error, toon-edge, json-out, encoding, large, determinism.
Deterministic (no clock, no randomness): same script in, same bytes out.
usage: python3 cases/gen-hand-cases.py [--check]
"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HAND = "cases/inputs/hand"
FILES = HAND + "/files"
rows, files = [], {}


def b(x):
    return x if isinstance(x, bytes) else x.encode("utf-8")


def case(name, args, stdin=None, cls="", note="", ext="txt"):
    rel = "-"
    if stdin is not None:
        rel = f"{HAND}/{name}.{ext}"
        files[rel] = b(stdin)
    rows.append((name, json.dumps(args, ensure_ascii=False), rel, cls, note))


def enc(name, text, extra=(), cls="enc-string", note=""):
    case(name, ["--encode", *extra], text, cls, note, "json")


def dec(name, text, extra=(), cls="dec-string", note=""):
    case(name, ["--decode", *extra], text, cls, note, "toon")


def afile(relname, data):
    files[f"{FILES}/{relname}"] = b(data)
    return f"{FILES}/{relname}"


SMALL_JSON = '{"name":"Alice","age":30,"tags":["a","b"]}\n'
SMALL_TOON = "name: Alice\nage: 30\ntags[2]: a,b\n"

# ---------------------------------------------------------------- usage
case("usage_none", [], None, "usage", "no args, empty stdin")
case("usage_help", ["--help"], None, "usage")
case("usage_help_short", ["-h"], None, "usage")
case("usage_version", ["--version"], None, "usage")
case("usage_version_short", ["-V"], None, "usage")
case("usage_help_wins_over_bad_flag_value", ["--indent", "99", "--help"], None, "usage")
case("usage_unknown_flag", ["--no-such-flag"], None, "usage")
case("usage_unknown_short", ["-x"], None, "usage")
case("usage_extra_positional", ["a.json", "b.json"], None, "usage")
case("usage_conflict_encode_decode", ["-e", "-d"], SMALL_JSON, "usage")
case("usage_conflict_decode_encode", ["--decode", "--encode"], SMALL_JSON, "usage")
case("usage_encode_twice", ["-e", "-e"], SMALL_JSON, "usage")
case("usage_indent_twice", ["--indent", "2", "--indent", "4"], SMALL_JSON, "usage")
case("usage_missing_value_delimiter", ["--delimiter"], None, "usage")
case("usage_missing_value_indent", ["--indent"], None, "usage")
case("usage_missing_value_output", ["-o"], None, "usage")
case("usage_missing_value_key_folding", ["--key-folding"], None, "usage")
case("usage_bad_delimiter", ["--encode", "--delimiter", "x"], SMALL_JSON, "usage")
case("usage_bad_delimiter_word", ["--encode", "--delimiter", "invalid"], SMALL_JSON, "usage")
case("usage_bad_delimiter_empty", ["--encode", "--delimiter", ""], SMALL_JSON, "usage")
case("usage_bad_delimiter_two_chars", ["--encode", "--delimiter", ",,"], SMALL_JSON, "usage")
case("usage_bad_indent_17", ["--encode", "--indent", "17"], SMALL_JSON, "usage")
case("usage_bad_indent_99", ["--encode", "--indent", "99"], SMALL_JSON, "usage")
case("usage_bad_indent_256", ["--encode", "--indent", "256"], SMALL_JSON, "usage")
case("usage_bad_indent_huge", ["--encode", "--indent", "99999999999999999999"], SMALL_JSON, "usage")
case("usage_bad_indent_abc", ["--encode", "--indent", "abc"], SMALL_JSON, "usage")
case("usage_bad_indent_empty", ["--encode", "--indent", ""], SMALL_JSON, "usage")
case("usage_bad_indent_float", ["--encode", "--indent", "2.5"], SMALL_JSON, "usage")
case("usage_bad_indent_negative", ["--encode", "--indent=-1"], SMALL_JSON, "usage")
case("usage_indent_plus", ["--encode", "--indent", "+4"], SMALL_JSON, "usage", "Rust u8 parse accepts a leading +")
case("usage_indent_leading_zero", ["--encode", "--indent", "04"], SMALL_JSON, "usage")
case("usage_bad_key_folding", ["--encode", "--key-folding", "maybe"], SMALL_JSON, "usage")
case("usage_bad_key_folding_case", ["--encode", "--key-folding", "SAFE"], SMALL_JSON, "usage")
case("usage_bad_expand_paths", ["--decode", "--expand-paths", "maybe"], SMALL_TOON, "usage")
case("usage_bad_flatten_depth_abc", ["--encode", "--flatten-depth", "abc"], SMALL_JSON, "usage")
case("usage_bad_flatten_depth_neg", ["--encode", "--flatten-depth=-1"], SMALL_JSON, "usage")
case("usage_bad_flatten_depth_float", ["--encode", "--flatten-depth", "1.5"], SMALL_JSON, "usage")
case("usage_empty_arg", [""], None, "usage")
case("usage_missing_file", ["cases/inputs/hand/files/does-not-exist.json"], None, "usage")
case("usage_missing_file_toon", ["cases/inputs/hand/files/does-not-exist.toon"], None, "usage")
case("usage_dir_as_input", ["cases/inputs/hand/files"], None, "usage")
case("usage_output_bad_dir", ["--encode", "-o", "cases/inputs/hand/no-such-dir/out.toon"], SMALL_JSON, "usage")

# ---------------------------------------------------------------- flag forms
case("flag_indent_equals", ["--encode", "--indent=4"], '{"a":{"b":1}}\n', "flagform")
case("flag_delimiter_equals_pipe", ["--encode", "--delimiter=|"], '{"t":["a","b"]}\n', "flagform")
case("flag_delimiter_word_comma", ["--encode", "--delimiter", "comma"], '{"t":["a","b"]}\n', "flagform")
case("flag_delimiter_word_pipe", ["--encode", "--delimiter", "pipe"], '{"t":["a","b"]}\n', "flagform")
case("flag_delimiter_word_tab", ["--encode", "--delimiter", "tab"], '{"t":["a","b"]}\n', "flagform")
case("flag_delimiter_backslash_t", ["--encode", "--delimiter", "\\t"], '{"t":["a","b"]}\n', "flagform")
case("flag_delimiter_real_tab", ["--encode", "--delimiter", "\t"], '{"t":["a","b"]}\n', "flagform")
case("flag_short_combined_e", ["-e"], SMALL_JSON, "flagform")
case("flag_short_d", ["-d"], SMALL_TOON, "flagform")
case("flag_stdin_dash", ["-e", "-"], SMALL_JSON, "flagform")
case("flag_stdin_dash_decode", ["-d", "-"], SMALL_TOON, "flagform")
case("flag_double_dash_file", ["--", afile("plain.json", SMALL_JSON)], None, "flagform")
case("flag_output_dev_stdout_encode", ["-e", "-o", "/dev/stdout"], SMALL_JSON, "flagform", "file output path + success line on stderr")
case("flag_output_dev_stdout_decode", ["-d", "--output", "/dev/stdout"], SMALL_TOON, "flagform")
case("flag_output_attached", ["-e", "-o/dev/stdout"], SMALL_JSON, "flagform")
case("flag_output_equals", ["-e", "--output=/dev/stdout"], SMALL_JSON, "flagform")
case("flag_output_file_label", ["-o", "/dev/stdout", afile("label.json", SMALL_JSON)], None, "flagform", "success line names the input path")
case("flag_indent_0_encode", ["--encode", "--indent", "0"], '{"a":{"b":1},"l":[{"x":1},{"y":2}]}\n', "flagform")
case("flag_indent_16_encode", ["--encode", "--indent", "16"], '{"a":{"b":1}}\n', "flagform")
case("flag_indent_1_encode", ["--encode", "--indent", "1"], '{"a":{"b":{"c":1}},"l":[{"x":1,"y":[1,{"z":2}]}]}\n', "flagform")
case("flag_no_strict_on_encode_ignored", ["--encode", "--no-strict"], SMALL_JSON, "flagform")
case("flag_expand_paths_on_encode_ignored", ["--encode", "--expand-paths", "safe"], '{"a.b":1}\n', "flagform")
case("flag_key_folding_on_decode_ignored", ["--decode", "--key-folding", "safe"], "a.b: 1\n", "flagform")
case("flag_flatten_depth_without_folding", ["--encode", "--flatten-depth", "2"], '{"a":{"b":{"c":1}}}\n', "flagform")
case("flag_flatten_depth_big", ["--encode", "--key-folding", "safe", "--flatten-depth", "18446744073709551615"], '{"a":{"b":{"c":1}}}\n', "flagform")
case("flag_flatten_depth_too_big", ["--encode", "--key-folding", "safe", "--flatten-depth", "18446744073709551616"], '{"a":{"b":{"c":1}}}\n', "flagform")
case("flag_flatten_depth_3", ["--encode", "--key-folding", "safe", "--flatten-depth", "3"], '{"a":{"b":{"c":{"d":{"e":1}}}}}\n', "flagform")

# ---------------------------------------------------------------- auto-detection by extension
case("auto_json_ext", [afile("auto.json", SMALL_JSON)], None, "autodetect")
case("auto_toon_ext", [afile("auto.toon", SMALL_TOON)], None, "autodetect")
case("auto_upper_json_ext", [afile("upper.JSON", SMALL_JSON)], None, "autodetect")
case("auto_upper_toon_ext", [afile("upper.TOON", SMALL_TOON)], None, "autodetect")
case("auto_txt_ext_defaults_encode", [afile("plain.txt", SMALL_JSON)], None, "autodetect")
case("auto_no_ext_defaults_encode", [afile("noext", SMALL_JSON)], None, "autodetect")
case("auto_toon_ext_forced_encode", ["--encode", afile("forced.toon", SMALL_JSON)], None, "autodetect")
case("auto_json_ext_forced_decode", ["--decode", afile("forced.json", SMALL_TOON)], None, "autodetect")
case("auto_double_ext", [afile("data.json.toon", SMALL_TOON)], None, "autodetect")
case("auto_dotfile_json", [afile(".json", SMALL_JSON)], None, "autodetect", "a bare .json has no extension in Rust's Path")
case("auto_stdin_defaults_encode", [], SMALL_JSON, "autodetect")
case("auto_toon_content_json_ext_fails", [afile("wrong.json", SMALL_TOON)], None, "autodetect")

# ---------------------------------------------------------------- stats
case("stats_small", ["--encode", "--stats"], SMALL_JSON, "stats")
case("stats_users", ["--encode", "--stats"], '{"users":[{"id":1,"name":"Alice","active":true},{"id":2,"name":"Bob","active":false},{"id":3,"name":"Carol","active":true}]}\n', "stats")
case("stats_no_savings", ["--encode", "--stats"], '1\n', "stats", "diff 0: no Saved line")
case("stats_empty_object", ["--encode", "--stats"], '{}\n', "stats")
case("stats_with_output", ["--encode", "--stats", "-o", "/dev/stdout"], SMALL_JSON, "stats")
case("stats_on_decode_ignored", ["--decode", "--stats"], SMALL_TOON, "stats")
case("stats_unicode_whitespace", ["--encode", "--stats"], '{"a":"x\u00a0y\u2003z","b":"one two  three"}\n', "stats", "is_whitespace is Unicode-aware")
for i, n in enumerate([3, 7, 16, 40, 80], 1):
    case(f"stats_ratio_{i}", ["--encode", "--stats"], json.dumps({"rows": [{"id": k, "v": "x" * (k % 5)} for k in range(n)]}) + "\n", "stats", "percent rounding probes")

# ---------------------------------------------------------------- numbers, JSON -> TOON
def numobj(lits):
    return "{" + ",".join(f'"n{i:02d}":{lit}' for i, lit in enumerate(lits, 1)) + "}\n"

enc("encnum_ints", numobj(["0", "-0", "1", "-1", "42", "-42", "100", "1000000", "2147483647", "4294967295", "4294967296", "281474976710655", "281474976710656"]), cls="enc-number")
enc("encnum_big_ints", numobj(["9007199254740991", "9007199254740992", "9007199254740993", "-9007199254740993", "9223372036854775807", "9223372036854775808", "-9223372036854775808", "-9223372036854775809", "18446744073709551615", "18446744073709551616", "123456789012345678901234567890"]), cls="enc-number")
enc("encnum_decimals", numobj(["0.1", "0.10", "1.0", "1.50", "-1.5", "3.14", "0.5", "0.25", "0.125", "100.001", "0.000001", "0.0000001", "123456.789", "0.1e1", "-0.0", "0.0"]), cls="enc-number")
enc("encnum_exponents", numobj(["1e0", "1e1", "1E2", "1e+2", "1e-2", "1.5e3", "1.5E-3", "12e-1", "1e15", "1e16", "1e17", "1e21", "1e22", "1e23", "-1e-7", "5e-1", "0e0", "0e10", "-0e-5"]), cls="enc-number")
enc("encnum_extremes", numobj(["1.7976931348623157e308", "-1.7976931348623157e308", "1e308", "2.2250738585072014e-308", "2.2250738585072011e-308", "5e-324", "4.9e-324", "2.4703282292062328e-324", "1e-400", "-1e-400"]), cls="enc-number")
enc("encnum_long_mantissa", numobj(["0.30000000000000004", "0.1000000000000000055511151231257827", "3.141592653589793238462643383279", "2.718281828459045", "1.2345678901234567", "1.23456789012345678", "123456789.123456789", "9007199254740993.5", "0.3333333333333333333333", "1.0000000000000002", "1.00000000000000011102230246251565", "1.00000000000000011102230246251566"]), cls="enc-number")
enc("encnum_in_arrays", '{"inline":[1,2.5,-3,1e3,0.0,-0],"table":[{"a":1.0,"b":2e2},{"a":-0.5,"b":1e-3}],"nested":[[1,2.0],[3e0]]}\n', cls="enc-number")
enc("encnum_root", '1e6\n', cls="enc-number")
enc("encnum_root_negative_zero", '-0.0\n', cls="enc-number")
enc("encnum_overflow_positive", '{"a":1e309}\n', cls="enc-number", note="serde_json: number out of range")
enc("encnum_overflow_negative", '{"a":-1e309}\n', cls="enc-number")
enc("encnum_overflow_huge_exponent", '{"a":1e99999999999999999999}\n', cls="enc-number")
enc("encnum_zero_huge_exponent", '{"a":0e99999999999999999999}\n', cls="enc-number")
enc("encnum_tiny_huge_exponent", '{"a":1e-99999999999999999999}\n', cls="enc-number")

# ---------------------------------------------------------------- numbers, TOON -> JSON
def toonnums(toks):
    return "".join(f"n{i:02d}: {t}\n" for i, t in enumerate(toks, 1))

dec("decnum_ints", toonnums(["0", "-0", "1", "-1", "42", "100", "1000000", "4294967296", "9007199254740991", "9007199254740992", "9007199254740993", "18446744073709551615", "18446744073709551616", "123456789012345678901234567890"]), cls="dec-number")
dec("decnum_decimals", toonnums(["0.1", "0.10", "1.0", "1.50", "-1.5", "3.14", "0.5", "0.000001", "0.0000001", "0.00001", "0.0001", "123456.789", "-0.0", "0.0", "100.0"]), cls="dec-number")
dec("decnum_exponents", toonnums(["1e0", "1e1", "1E2", "1e+2", "1e-2", "1.5e3", "1.5E-3", "1e15", "1e16", "1e17", "1e21", "1e22", "-1e-7", "0e0", "1e-5", "1e-6", "1e-7", "123456789012345680000", "12345678901234567"]), cls="dec-number")
dec("decnum_extremes", toonnums(["1.7976931348623157e308", "1e308", "1e309", "-1e309", "2.2250738585072014e-308", "5e-324", "4.9e-324", "2.4703282292062328e-324", "1e-400", "-1e-400"]), cls="dec-number", note="1e309 parses to inf: not finite, so the token is a string")
dec("decnum_long_mantissa", toonnums(["0.30000000000000004", "3.141592653589793238462643383279", "1.2345678901234567", "1.23456789012345678", "9007199254740993.5", "1.0000000000000002", "1.00000000000000011102230246251565", "1.00000000000000011102230246251566", "0.1000000000000000055511151231257827"]), cls="dec-number")
dec("decnum_not_numbers", toonnums(["007", "00", "01.5", "-01", "+5", "1.", ".5", "1e", "1e+", "0x10", "1_000", "-", "--1", "1.2.3", "1e5e5", "Infinity", "-Infinity", "NaN", "inf", "1 2", "١٢٣", "１２"]), cls="dec-number", note="tokens that stay strings")
dec("decnum_inline_and_tabular", "inline[6]: 1,2.5,-3,1e3,0.0,-0\ntable[2]{a,b}:\n  1.0,2e2\n  -0.5,1e-3\nlist[2]:\n  - 1e21\n  - 0.5\n", cls="dec-number")
dec("decnum_root", "1e6", cls="dec-number")
dec("decnum_root_negative_zero", "-0", cls="dec-number")
dec("decnum_compact", toonnums(["1", "1.5", "1e21", "1e-7", "100"]), ["--indent", "0"], cls="dec-number")
dec("decnum_expand_path", "a.b: 1\na.c: 2.50\nd: 1e21\n", ["--expand-paths", "safe"], cls="dec-number", note="the non-streaming stringify path")

# ---------------------------------------------------------------- OQ-001: JSON float text format thresholds (TOON -> JSON)
dec("decfmt_exp_upper_boundary", toonnums(["999999999999999.9", "1000000000000000", "1234567890123456", "9999999999999998", "9007199254740993", "10000000000000000", "12345678901234567", "1e15", "9.999999999999999e15", "1e16", "1.5e16", "-1e16", "-1234567890123456"]), cls="dec-number", note="OQ-001")
dec("decfmt_exp_lower_boundary", toonnums(["0.001", "0.0001", "0.00001", "0.000011", "0.0000099", "0.000001", "0.0000015", "1.5e-5", "9.9e-6", "1.5e-6", "1.2345e-10", "-0.00001", "-0.000001", "0.000123456789"]), cls="dec-number", note="OQ-001")
dec("decfmt_exp_shapes", toonnums(["1.5e300", "1.2345e+300", "1e100", "1.7976931348623157e308", "2.5e-300", "1e-100", "123e20", "0.5e-10", "5e-324", "1.5e22", "12345.678e5", "1234.5", "0.5", "100", "1e2", "1.25e2", "1.255e2"]), cls="dec-number", note="OQ-001")
dec("decfmt_exp_compact_and_expand", "a: 1e16\nb: 1e-6\nc: 1.5\nd: 100\n", ["--indent", "0", "--expand-paths", "safe"], cls="dec-number", note="OQ-001: both writers")

# ---------------------------------------------------------------- OQ-002: serde_json's default float path (JSON -> TOON)
enc("encnum_u64_boundary", numobj(["18446744073709551614", "18446744073709551615", "18446744073709551616", "18446744073709551625", "184467440737095516150", "1844674407370955161500", "18446744073709551615.5", "1844674407370955161.55", "184467440737095516.155", "99999999999999999999", "99999999999999999999.9", "-18446744073709551616", "-99999999999999999999"]), cls="enc-number", note="OQ-002: digits past a u64 significand are dropped")
enc("encnum_frac_long", numobj(["0.12345678901234567890123", "0.00000000000000000000123456789012345678901", "0.99999999999999999999", "0.999999999999999999999999", "1.99999999999999999999", "0.18446744073709551615", "0.18446744073709551616", "0.184467440737095516159", "123.00000000000000000000001", "0.5000000000000000000000000001"]), cls="enc-number", note="OQ-002")
enc("encnum_pow10_slow_path", numobj(["1.5e23", "123e30", "1e-23", "12345678901234567e-30", "1e-308", "1e-320", "123456789e-320", "1e-323", "1e-324", "3e-324", "9007199254740993e0", "9007199254740993e1", "9007199254740993e-1", "1e23", "8.5e22", "9.5e22", "1.2e25", "4.35e30", "6.02214076e23", "1.602176634e-19", "6.62607015e-34"]), cls="enc-number", note="OQ-002: exponents past the exact powers of ten")
enc("encnum_pow10_each", numobj([f"1e{k}" for k in range(-30, 31)]), cls="enc-number", note="OQ-002")
enc("encnum_mixed_digits", numobj(["7e22", "7e23", "3e25", "9e28", "5e-23", "7e-25", "0.1e-22", "33e22", "0.7e24", "123456789012345e8", "123456789012345e9", "1234567890123456e7", "12345678901234567e6", "2.5e-5", "4.9406564584124654e-324", "2.2250738585072009e-308", "1.7976931348623158e308", "1.7976931348623159e308"]), cls="enc-number", note="OQ-002")

# ---------------------------------------------------------------- strings, JSON -> TOON
enc("encstr_quoting", json.dumps({"empty": "", "lead": " a", "trail": "a ", "both": " a ", "t": "true", "f": "false", "n": "null", "num": "123", "exp": "1e5", "neg": "-5", "dash": "-", "dashword": "-a", "lz": "007", "colon": "a:b", "comma": "a,b", "pipe": "a|b", "tab": "a\tb", "quote": 'say "hi"', "bs": "a\\b", "nl": "a\nb", "cr": "a\rb", "brk": "[x]", "brc": "{x}", "hash": "#x", "plain": "hello world", "T": "True", "N": "NULL", "dotnum": ".5", "plusnum": "+5", "hex": "0x10"}) + "\n")
enc("encstr_quoting_pipe", json.dumps({"comma": "a,b", "pipe": "a|b", "tab": "a\tb", "arr": ["a,b", "c|d", "e"]}) + "\n", ["--delimiter", "|"])
enc("encstr_quoting_tab", json.dumps({"comma": "a,b", "pipe": "a|b", "tab": "a\tb", "arr": ["a,b", "c|d", "e"]}) + "\n", ["--delimiter", "\t"])
enc("encstr_unicode", json.dumps({"cafe": "café", "emoji": "😀", "jp": "日本語", "rtl": "مرحبا", "zwj": "a\u200db", "comb": "e\u0301", "nbsp_lead": "\u00a0x", "emsp_trail": "x\u2003", "ls": "a\u2028b", "bom": "\ufeffx", "nel": "\u0085x"}, ensure_ascii=False) + "\n", note="trim() is Unicode-aware")
enc("encstr_escapes_in", '{"u":"\\u0041\\u00e9\\u20ac","pair":"\\ud83d\\ude00","slash":"a\\/b","b":"x\\by","f":"x\\fy","nul":"x\\u0000y","del":"x\\u007fy","c1":"x\\u0001y","esc":"\\u001b[0m"}\n', note="control characters other than \\n \\r \\t are emitted raw")
enc("encstr_keys", json.dumps({"ok_key": 1, "_u": 2, "a.b": 3, "a-b": 4, "1a": 5, "": 6, "a b": 7, "é": 8, "k\"q": 9, "k:c": 10, "k[0]": 11, "k{x}": 12, "true": 13, "123": 14, "-": 15, "a\nb": 16, " lead": 17, "A9_": 18, "a..b": 19, ".a": 20}, ensure_ascii=False) + "\n")
enc("encstr_root_string", '"hello world"\n')
enc("encstr_root_string_quoted", '"true"\n')
enc("encstr_root_empty_string", '""\n')
enc("encstr_root_null", 'null\n')
enc("encstr_root_bool", 'false\n')
enc("encstr_long", json.dumps({"long": "x" * 5000, "k" * 300: "v"}) + "\n")
enc("encstr_duplicate_keys", '{"a":1,"b":2,"a":3,"c":{"x":1,"x":2}}\n', note="IndexMap: last value, first position")
enc("encstr_whitespace_json", ' \n\t{ "a" : [ 1 , 2 ] ,\r\n "b" : { } }  \n\n')
enc("encstr_no_trailing_newline", '{"a":1}')
enc("enc_shapes_mixed", json.dumps({"empty_obj": {}, "empty_arr": [], "nested_empty": {"a": {}, "b": []}, "arr_of_empty": [{}, [], {}], "mixed": [1, "a", None, True, {"k": "v"}, [1, 2], []], "aoa": [[1, 2], [], ["a"]], "aoa_mixed": [[1, [2]], [3]], "objs_diff": [{"a": 1}, {"b": 2}], "objs_order": [{"a": 1, "b": 2}, {"b": 3, "a": 4}], "objs_nested": [{"a": {"x": 1}}, {"a": {"x": 2}}], "objs_first_arr": [{"items": [{"id": 1}, {"id": 2}], "n": 1}, {"items": [1, 2], "n": 2}, {"items": [], "n": 3}, {"items": [[1]], "n": 4}], "objs_first_obj": [{"o": {"p": 1}, "q": 2}, {"o": {}, "q": 3}]}) + "\n", cls="enc-string")
enc("enc_folding_mix", json.dumps({"a": {"b": {"c": 1}}, "a.b": 2, "x": {"y": {"z": [1, 2]}}, "p": {"q": {}}, "m": {"n": {"o": 1, "o2": 2}}, "u": {"v-w": {"k": 1}}, "arr": [{"d": {"e": {"f": 1}}}], "deep": {"l1": {"l2": {"l3": {"l4": 1}}}}}) + "\n", ["--key-folding", "safe"], cls="enc-string")
enc("enc_folding_collision", json.dumps({"a": {"b": 1}, "a.b": 2, "c": {"d": {"e": 1}}, "c.d": {"e": 2}}) + "\n", ["--key-folding", "safe"], cls="enc-string")
enc("enc_deep_100", "".join('{"k":' for _ in range(100)) + "1" + "}" * 100 + "\n", cls="enc-string")
enc("enc_deep_arrays_100", "[" * 100 + "]" * 100 + "\n", cls="enc-string")

# ---------------------------------------------------------------- strings, TOON -> JSON
dec("decstr_quoted", 'a: "hello"\nb: "a\\nb\\tc\\rd\\\\e\\"f"\nc: ""\nd: "true"\ne: "123"\nf: " padded "\n"q k": 1\n"a.b": 2\n"": 3\n')
dec("decstr_unquoted", "a: hello world\nb:   spaced   \nc: true\nd: TRUE\ne: null\nf: Null\ng: café 😀\nh: a:b\ni: x # not a comment\n")
dec("decstr_unicode_ws", "a: \u00a0x\u00a0\nb: x\u2003\n", note="trim() strips Unicode whitespace")
dec("decstr_control_out", 'a: "x\\\\y"\nb: x\u0001y\nc: x\u007fy\nd: x\u0085y\ne: x\u2028y\nf: x\by\ng: x\fy\n', note="streaming JSON writer: serde_json escaping")
dec("decstr_control_out_expand", 'a: "x\\\\y"\nb: x\u0001y\nc: x\u007fy\nd: x\u0085y\ne: x\u2028y\nf: x\by\ng: x\fy\n', ["--expand-paths", "safe"], note="non-streaming JSON writer: is_control escaping")
dec("decstr_keys", 'simple: 1\nwith space: 2\nk-dash: 3\n"quoted:colon": 4\né: 5\n1abc: 6\n')
dec("decstr_empty_doc", "", note="empty input is {}")
dec("decstr_blank_doc", "\n\n  \n", note="only blank lines")
dec("decstr_root_string", "hello world")
dec("decstr_root_quoted", '"a: b"')
dec("decstr_root_true", "true")
dec("decstr_root_null", "null")
dec("decstr_two_primitives", "hello\nworld\n")

# ---------------------------------------------------------------- JSON output shapes
JOUT = 'o:\n  e:\n  a[0]:\n  l[2]: 1,2\n  t[2]{x,y}:\n    1,a\n    2,b\n  m[3]:\n    - 1\n    - k: v\n      z[0]:\n    - [2]: a,b\ns: "q\\"uote"\n'
for ind in ("0", "1", "2", "4"):
    dec(f"jsonout_indent_{ind}", JOUT, ["--indent", ind] if ind != "2" else [], cls="json-out")
    dec(f"jsonout_expand_indent_{ind}", JOUT, (["--indent", ind] if ind != "2" else []) + ["--expand-paths", "safe"], cls="json-out")
dec("jsonout_root_array", "[3]: 1,two,true", cls="json-out")
dec("jsonout_root_empty_array", "[0]:", cls="json-out")
dec("jsonout_root_array_compact", "[2]:\n- a: 1\n- b: 2", ["--indent", "0"], cls="json-out")
dec("jsonout_expand_merge", "a.b: 1\na.c: 2\na:\n  d: 3\nx.y.z: deep\n\"q.r\": kept\nbad-seg.k: 4\n", ["--expand-paths", "safe"], cls="json-out")
dec("jsonout_expand_conflict_strict", "a.b: 1\na: 2\n", ["--expand-paths", "safe"], cls="json-out")
dec("jsonout_expand_conflict_lenient", "a.b: 1\na: 2\n", ["--expand-paths", "safe", "--no-strict"], cls="json-out")
dec("jsonout_expand_conflict_obj_prim", "a: 1\na.b: 2\n", ["--expand-paths", "safe"], cls="json-out")
dec("jsonout_expand_conflict_obj_prim_lenient", "a: 1\na.b: 2\n", ["--expand-paths", "safe", "--no-strict"], cls="json-out")
dec("jsonout_expand_in_arrays", "rows[2]{a.b,c}:\n  1,2\n  3,4\nl[1]:\n  - p.q: 1\n", ["--expand-paths", "safe"], cls="json-out")
dec("jsonout_expand_deep_limit", ".".join(["k"] * 300) + ": 1\n", ["--expand-paths", "safe"], cls="json-out", note="MAX_EXPAND_DEPTH 256")
dec("jsonout_duplicate_keys", "a: 1\na: 2\nb: 3\n", cls="json-out", note="streaming writer repeats the key")
dec("jsonout_duplicate_keys_expand", "a: 1\na: 2\nb: 3\n", ["--expand-paths", "safe"], cls="json-out")
dec("jsonout_duplicate_keys_expand_lenient", "a: 1\na: 2\nb: 3\n", ["--expand-paths", "safe", "--no-strict"], cls="json-out")

# ---------------------------------------------------------------- JSON parse errors
JERR = {
    "empty": "", "whitespace": "  \n\t\n", "open_brace": "{", "open_bracket": "[", "trailing_comma_arr": "[1,]",
    "trailing_comma_obj": '{"a":1,}', "missing_value": '{"invalid": }', "missing_colon": '{"a" 1}', "unquoted_key": "{a:1}",
    "single_quotes": "'a'", "bad_true": "tru", "bad_null": "nul", "bad_ident": "nope", "leading_zero": "01", "dot_end": "1.",
    "dot_start": ".5", "lone_minus": "-", "exp_end": "1e", "plus": "+1", "unterminated_string": '"abc', "bad_escape": '"\\x"',
    "short_hex": '"\\u12"', "bad_hex": '"\\u12zz"', "lone_high_surrogate": '"\\ud800"', "high_then_bmp": '"\\ud800\\u0041"',
    "lone_low_surrogate": '"\\udc00"', "raw_newline_in_string": '"a\nb"', "raw_tab_in_string": '"a\tb"', "trailing_chars": "1 2",
    "trailing_after_obj": "{} x", "second_line_error": '{\n  "a": 1,\n  "b": oops\n}', "comment": "// c\n1", "nan": "NaN",
    "infinity": "Infinity", "missing_comma": "[1 2]", "missing_comma_obj": '{"a":1 "b":2}', "key_not_string": "{1:2}",
    "eof_in_object": '{"a":1', "eof_after_key": '{"a"', "eof_after_colon": '{"a":', "eof_in_array": "[1,2",
    "deep_128": "[" * 128 + "]" * 128, "deep_129": "[" * 129 + "]" * 129, "deep_objects_200": '{"a":' * 200 + "1" + "}" * 200,
    "bom_prefixed": "\ufeff{}", "unicode_in_error_col": '{"é😀": oops}', "minus_word": "-x", "upper_true": "TRUE",
    "form_feed_ws": "\f1", "nbsp_ws": "\u00a01",
}
for k, v in JERR.items():
    case(f"jsonerr_{k}", ["--encode"], v, "json-error", ext="json")
case("jsonerr_invalid_utf8_stdin", ["--encode"], b'{"a":"\xff\xfe"}\n', "json-error", "read_to_string rejects invalid UTF-8", "json")
case("jsonerr_invalid_utf8_file", [afile("bad-utf8.json", b'{"a":"\xc3\x28"}\n')], None, "json-error")
case("toonerr_invalid_utf8_stdin", ["--decode"], b"a: \xff\n", "toon-error", ext="toon")
case("jsonerr_overlong_utf8", ["--encode"], b'"\xc0\xaf"\n', "json-error", ext="json")
case("jsonerr_truncated_utf8", ["--encode"], b'{"a":"\xe2\x82"}', "json-error", ext="json")

# ---------------------------------------------------------------- TOON decode errors and edges
TERR = {
    "blank_in_list": "items[2]:\n  - a\n\n  - b", "blank_in_tabular": "rows[2]{id}:\n  1\n\n  2",
    "extra_list_items": "items[1]:\n  - a\n  - b", "extra_tabular_rows": "rows[1]{id}:\n  1\n  2",
    "too_few_list_items": "items[3]:\n  - a", "too_few_inline": "items[3]: a,b", "too_many_inline": "items[1]: a,b",
    "row_width_short": "rows[1]{a,b,c}:\n  1,2", "row_width_long": "rows[1]{a,b}:\n  1,2,3",
    "huge_length": "items[9999999999]:", "length_at_cap": "items[100000000]:", "length_over_cap": "items[100000001]:",
    "unterminated_value": 'name: "unterminated', "unterminated_key": '"unterminated key: value',
    "bad_escape": 'name: "bad \\x escape"', "unicode_escape": 'name: "\\u0041"', "trailing_backslash": 'name: "abc\\',
    "after_closing_quote": 'name: "abc" def', "tab_indent": "\tname: value", "tab_indent_list": "items[1]:\n\t- a",
    "indent_not_multiple": "outer:\n a: 1", "indent_three": "outer:\n   a: 1", "missing_close_bracket": "items[3: a,b,c",
    "missing_colon_second_line": "a: 1\nbare\n", "missing_colon_nested": "o:\n  bare\n", "bad_length": "items[abc]: 1",
    "negative_length": "items[-1]: 1", "empty_length": "items[]: 1", "float_length": "items[1.5]: 1",
    "inline_bad_quote": 'items[2]: "a,b', "field_bad_quote": 'rows[1]{"a}:\n  1', "list_item_no_space": "items[1]:\n  -a",
    "depth_jump": "a:\n    b: 1\n", "first_line_indented": "  a: 1\n", "empty_key": ": 1\n", "colon_only": ":\n",
    "quoted_key_no_colon": '"k" 1\n', "zero_length_with_items": "items[0]:\n  - a\n", "zero_inline_with_values": "items[0]: a\n",
    "tabular_row_colon": "rows[2]{a,b}:\n  1,2\n  x: y\n", "crlf": "a: 1\r\nb: two\r\nl[2]: x,y\r\n", "bom": "\ufeffa: 1\n",
    "trailing_spaces": "a: 1   \nb:   \n  c: 2  \n", "header_spaces": "items [2] : a,b\n", "header_key_quoted": '"my items"[2]: a,b\n',
    "header_brace_after_colon": "k[1]: {a}\n", "nested_headers": "a[1]:\n  - [1]:\n    - [1]: x\n", "pipe_header": "t[2|]{a|b}:\n  1|2\n  3|4\n",
    "tab_header": "t[2\t]{a\tb}:\n  1\t2\n  3\t4\n", "mixed_delims": "t[2|]: a,b|c\n", "list_obj_first_tabular": "l[1]:\n  - rows[2]{a}:\n      1\n      2\n    n: 1\n",
    "list_obj_fields": "l[2]:\n  - a: 1\n    b: 2\n  - c:\n      d: 3\n", "list_dash_only": "l[2]:\n  -\n  - \n", "object_empty_nested": "a:\nb:\n  c:\n",
    "value_is_header_like": "a: [2]: x\n", "key_with_brackets_value": "a[b]: 1\n", "hyphen_value": "a: - b\n", "list_at_root_no_header": "- a\n- b\n",
}
for k, v in TERR.items():
    dec(f"toonerr_{k}", v, cls="toon-error")
for k in ("blank_in_list", "blank_in_tabular", "extra_list_items", "extra_tabular_rows", "too_few_list_items", "too_few_inline",
          "too_many_inline", "row_width_short", "row_width_long", "tab_indent", "tab_indent_list", "indent_not_multiple",
          "indent_three", "depth_jump", "first_line_indented", "zero_length_with_items", "zero_inline_with_values",
          "tabular_row_colon", "bad_escape", "unterminated_value", "huge_length"):
    dec(f"toonlenient_{k}", TERR[k], ["--no-strict"], cls="toon-edge")
dec("toonedge_indent4", "a:\n    b:\n        c: 1\n", ["--indent", "4"], cls="toon-edge")
dec("toonedge_indent4_wrong", "a:\n  b: 1\n", ["--indent", "4"], cls="toon-edge")
dec("toonedge_indent0_flat", "a: 1\nb: 2\n", ["--indent", "0"], cls="toon-edge")
dec("toonedge_indent0_indented", "a:\n  b: 1\n", ["--indent", "0"], cls="toon-edge")
dec("toonedge_indent0_indented_lenient", "a:\n  b: 1\n", ["--indent", "0", "--no-strict"], cls="toon-edge")
dec("toonedge_indent1", "a:\n b:\n  c: 1\n", ["--indent", "1"], cls="toon-edge")

# ---------------------------------------------------------------- round-trip shaped happy paths
enc("happy_readme_users", '{"users":[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]}\n', cls="happy")
dec("happy_readme_users_decode", "users[2]{id,name}:\n  1,Alice\n  2,Bob\n", cls="happy")
enc("happy_config_folded", '{"config":{"database":{"host":"localhost","port":5432}}}\n', ["--key-folding", "safe"], cls="happy")
dec("happy_config_expanded", "config.database.host: localhost\nconfig.database.port: 5432\n", ["--expand-paths", "safe"], cls="happy")

# ---------------------------------------------------------------- large + determinism
def big_rows(n):
    return json.dumps({"rows": [{"id": k, "name": f"user{k}", "email": f"user{k}@example.com", "score": (k * 37 % 1000) / 10, "active": k % 3 == 0, "note": None if k % 7 else "has, comma"} for k in range(n)]}, ensure_ascii=False) + "\n"

enc("large_tabular_1500", big_rows(1500), cls="large")
enc("large_tabular_1500_pipe_folded", big_rows(1500), ["--delimiter", "|", "--key-folding", "safe"], cls="large")
enc("determinism_a", big_rows(40), cls="determinism")
enc("determinism_a_again", big_rows(40), cls="determinism")


def main():
    check = "--check" in sys.argv[1:]
    names = [r[0] for r in rows]
    dup = sorted({n for n in names if names.count(n) > 1})
    if dup:
        raise SystemExit(f"duplicate case names: {dup}")
    tsv = "# generated by cases/gen-hand-cases.py; do not edit\n" + "".join("\t".join(r) + "\n" for r in rows)
    out_tsv = os.path.join(ROOT, "cases", "hand-cases.tsv")
    drift = []
    for rel, data in files.items():
        p = os.path.join(ROOT, rel)
        if check:
            if not os.path.exists(p) or open(p, "rb").read() != data:
                drift.append(rel)
        else:
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "wb") as fh:
                fh.write(data)
    if check:
        if not os.path.exists(out_tsv) or open(out_tsv, encoding="utf-8").read() != tsv:
            drift.append("cases/hand-cases.tsv")
        print(json.dumps({"cases": len(rows), "drift": drift, "verdict": "OK" if not drift else "DRIFT"}))
        return 1 if drift else 0
    with open(out_tsv, "w", encoding="utf-8") as fh:
        fh.write(tsv)
    print(json.dumps({"cases": len(rows), "inputs": len(files), "verdict": "WRITTEN"}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
