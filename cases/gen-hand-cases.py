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
# S2.51 (R16-1): integer digits alone exceed 1.8e308, so a NEGATIVE exponent does not make the token
# safe. EXP-007's first num.safe deferred on `eneg` alone and printed 0 with exit 0 here.
enc("encnum_overflow_wide_ints_neg_exponent", '{"a":1' + "0" * 400 + 'e-1}\n', cls="enc-number", note="R16-1: out of range despite e-1")
# S2.51 (R16-1): the same shape where a later syntax error must NOT win — the original reports the
# out-of-range at the number's column, not the comma's.
enc("encnum_overflow_wide_ints_then_syntax", '{"a":2' + "0" * 309 + 'e-1 x}\n', cls="enc-number", note="R16-1: out-of-range precedes the syntax error")
# S2.51 (R16-3): pins num.safe's exponent bound at 250. A mutant moving it to 300 defers this token
# and prints a number where the original exits 1.
enc("encnum_overflow_exponent_just_past_bound", '{"a":1000000000000e299}\n', cls="enc-number", note="R16-3: 1e311 is out of range")

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
# S4.12-S4.16 one forcing character ALONE. In encstr_quoting above, "[x]" and "{x}" each hold two forcing
# characters, so '[' masks ']' and '{' masks '}': a port that stopped quoting on ']', '{' or '}' passed every
# case (round 15, R15-2). Each value below has exactly one forcing character.
enc("encstr_only_close_bracket_forces_quotes", json.dumps({"a": "x]y"}) + "\n")
enc("encstr_only_open_brace_forces_quotes", json.dumps({"a": "x{y"}) + "\n")
enc("encstr_only_close_brace_forces_quotes", json.dumps({"a": "x}y"}) + "\n")
# S4.8 U+1234 is NOT White_Space, so a value that starts with it is written bare. The whole-table law pins the
# 25 members and samples 27 non-members; a port that added a point it does not sample passed every gate (R15-2).
enc("encstr_non_whitespace_u1234_bare", json.dumps({"a": "ሴx"}, ensure_ascii=False) + "\n")
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
# round 20 (R20-1): EXP-029 builds the key set when the 9th member joins; a repeat of THAT member, and of the next one,
# must still take the last value at the first position (the corpus had no repeat after the switch)
enc("encstr_duplicate_keys_after_the_set_is_built",
    '{"k0":0,"k1":1,"k2":2,"k3":3,"k4":4,"k5":5,"k6":6,"k7":7,"k8":8,"k9":9,"k8":99,"k9":98,'
    '"n":{"k0":0,"k1":1,"k2":2,"k3":3,"k4":4,"k5":5,"k6":6,"k7":7,"k8":8,"k8":"x"}}\n',
    note="EXP-029: the member that builds the key set, repeated")
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
# S9.151 (round 16, R16-2): TWO repeated-key failures in one document. The FIRST is reported, so a decoder
# that keeps the last pending failure (port: D.dup.keep) prints `"a"` where the original prints `"b"`.
dec("toonerr_dup_first_of_two_wins", "x:\n  b: 1\n  b: 2\na: 1\na: 2\n", cls="toon-error", note="R16-2: the nested duplicate comes first and wins")
dec("toonerr_dup_first_of_two_wins_expand", "x:\n  b: 1\n  b: 2\na: 1\na: 2\n", ["--expand-paths", "safe"], cls="toon-error", note="R16-2 with expansion: the same first failure")

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
# S2.2 overlong forms ABOVE the lead-byte floor. The case above is a 2-byte overlong (lead C0), which the lead
# byte alone rejects; a 3-byte (E0 90 80) or 4-byte (F0 88 80 80) overlong needs the per-length MINIMUM, and a
# port that lowered it accepted both while every gate stayed green (round 15, R15-2: mutants N16, N18).
case("jsonerr_overlong_utf8_3byte", ["--encode"], b'["\xe0\x90\x80"]\n', "json-error", ext="json")
case("jsonerr_overlong_utf8_4byte", ["--encode"], b'["\xf0\x88\x80\x80"]\n', "json-error", ext="json")
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


# ---------------------------------------------------------------- proposed by the Phase 1 extractors
# One function per part so their helper names cannot collide. Names are stable: never rename a case.
def _proposed_a():
    """Cases proposed by extractor A_cli_effects (docs/spec-parts/A_cli_effects.md, 'Cases to add'); each was run on the oracle there."""
    NEST = '{"a":{"b":1}}\n'
    # ---- precedence and scan order (S1.13-S1.19, S1.130-S1.135)
    case("usage_help_first_wins", ["--help", "--indent", "99"], None, "usage", "help text, exit 0")
    case("usage_version_first_wins", ["--version", "--help"], None, "usage", "toon 0.2.4")
    case("usage_help_before_version", ["--help", "--version"], None, "usage", "help text")
    case("usage_cluster_hV", ["-hV"], None, "usage", "help text")
    case("usage_cluster_Vh", ["-Vh"], None, "usage", "version")
    case("usage_bad_value_beats_conflict", ["-e", "-d", "--indent", "99"], SMALL_JSON, "usage", "invalid value 99")
    case("usage_unknown_long_beats_conflict", ["-e", "-d", "--bogus"], SMALL_JSON, "usage", "Usage: toon --encode --decode [INPUT]")
    case("usage_unknown_long_first", ["--bogus", "-e", "-d"], SMALL_JSON, "usage", "fixed usage line")
    case("usage_conflict_beaten_by_help", ["-e", "-d", "--help"], None, "usage", "help text, exit 0")
    case("usage_unknown_long_swallows_bad_value", ["--indent", "99", "--bogus"], None, "usage", "unknown --bogus; Usage: toon --indent <INDENT> [INPUT]")
    case("usage_unknown_short_swallows_bad_value", ["--indent", "99", "-x"], None, "usage", "unknown -x")
    case("usage_extra_positional_swallows_bad_value", ["a.json", "--indent", "99", "b.json"], None, "usage", "unexpected b.json")
    case("usage_bad_value_before_extra_positional", ["--indent", "99", "a.json", "b.json"], None, "usage", "invalid value 99")
    case("usage_missing_value_swallowed", ["--indent", "--bogus"], None, "usage", "unknown --bogus, fixed usage line")
    case("usage_missing_value_before_flag", ["--indent", "--encode"], None, "usage", "a value is required for --indent")
    case("usage_missing_value_before_double_dash", ["--indent", "--", "5"], None, "usage", "a value is required for --indent")
    case("usage_missing_value_after_flag", ["-e", "-o"], None, "usage", "a value is required for --output")
    case("usage_twice_beats_bad_value", ["--indent", "2", "--indent", "99"], None, "usage", "multiple times")
    case("usage_missing_beats_twice", ["--indent", "2", "--indent"], None, "usage", "a value is required")
    case("usage_attached_bad_value_first", ["--indent=99", "--indent=2"], None, "usage", "invalid value 99")
    case("usage_attached_twice", ["--indent=2", "--indent=99"], None, "usage", "multiple times")
    case("usage_twice_swallowed_removes", ["--indent", "2", "-e", "--stats", "--indent", "4", "--bogus"], None, "usage", "Usage: toon --encode --stats [INPUT]")
    case("usage_empty_input_beats_help", ["", "--help"], None, "usage", "a value is required for [INPUT]")
    case("usage_input_then_help", ["a.json", "--help"], None, "usage", "help text")
    case("usage_unknown_long_after_input", ["a.json", "--bogus"], None, "usage", "Usage: toon <INPUT>")
    # ---- conflict usage lines (S1.79)
    case("usage_conflict_with_input", ["-e", "-d", "a.json"], None, "usage", "Usage: toon --encode <INPUT>")
    case("usage_conflict_usage_many", ["-d", "--stats", "-e", "--indent", "4", "-o", "x.out", "a.json"], None, "usage", "Usage: toon --decode --stats --indent <INDENT> --output <FILE> <INPUT>")
    case("usage_conflict_stats_first", ["--stats", "-d", "-e", "a.json"], None, "usage", "Usage: toon --stats --decode <INPUT>")
    # ---- flag given a value (S1.86)
    case("usage_flag_with_value", ["--encode=1"], None, "usage", "Usage: toon --encode [INPUT]")
    case("usage_help_with_value", ["--help=x"], None, "usage", "Usage: toon --help [INPUT]")
    case("usage_flag_with_value_after_commit", ["-e", "--stats=yes"], None, "usage", "group usage line G")
    case("usage_flag_with_value_after_attached", ["--indent=4", "--stats=yes"], None, "usage", "group usage line G")
    case("usage_flag_with_value_after_pending", ["--indent", "4", "--stats=yes"], None, "usage", "Usage: toon --stats [INPUT]")
    # ---- clusters, escapes, word classes (S1.5-S1.10)
    case("usage_cluster_conflict", ["-ed"], None, "usage", "conflict")
    case("usage_cluster_unknown_after_flag", ["-ex"], None, "usage", "unknown -x")
    case("usage_cluster_digit", ["-e5"], None, "usage", "unknown -5")
    case("usage_cluster_equals", ["-e=x"], None, "usage", "unknown -=")
    case("usage_negative_number_word", ["--indent", "-1"], None, "usage", "unknown -1")
    case("usage_negative_cluster_first_char", ["--indent", "-129"], None, "usage", "unknown -1")
    case("usage_output_value_flaglike", ["-o", "-x"], None, "usage", "unknown -x")
    case("usage_output_value_longlike", ["--output", "--weird"], None, "usage", "unknown --weird, fixed usage line")
    case("usage_unknown_long_with_value", ["--bogus=1"], None, "usage", "reports --bogus")
    case("usage_unknown_long_empty_name", ["--=x"], None, "usage", "reports --")
    case("usage_unknown_triple_dash", ["---x"], None, "usage", "reports ---x")
    case("usage_unknown_long_uppercase", ["--HELP"], None, "usage", "no similar name")
    case("usage_unknown_short_uppercase", ["-E"], None, "usage", "unknown -E")
    case("usage_double_dash_help_is_path", ["--", "--help"], None, "usage", "Failed to read file '--help', exit 1")
    case("usage_double_dash_extra", ["--", "a", "b"], None, "usage", "unexpected b, no tip")
    case("usage_double_dash_extra_flaglike", ["--", "a", "--bogus"], None, "usage", "unexpected --bogus, no tip")
    case("usage_extra_positional_dash", ["a", "-"], None, "usage", "unexpected -")
    case("usage_three_positionals", ["a", "b", "c"], None, "usage", "unexpected b")
    case("usage_value_then_positional", ["--indent", "4", "5"], None, "usage", "Failed to read file '5', exit 1")
    case("usage_word_help_is_a_path", ["help"], None, "usage", "Failed to read file 'help', exit 1")
    case("usage_encode_short_and_long", ["-e", "--encode"], None, "usage", "multiple times")
    case("usage_output_twice", ["-o", "a", "-o", "b"], None, "usage", "multiple times --output <FILE>")
    case("usage_stats_twice", ["--stats", "--stats"], None, "usage", "multiple times --stats")
    # ---- values (S1.30-S1.35, S1.82-S1.84)
    case("usage_empty_output", ["-o", ""], None, "usage", "a value is required for --output <FILE>")
    case("usage_empty_output_equals", ["--output="], None, "usage", "same")
    case("usage_empty_output_short_equals", ["-o="], None, "usage", "same")
    case("usage_empty_key_folding", ["--key-folding", ""], None, "usage", "value required + possible values line")
    case("usage_empty_flatten_depth", ["--flatten-depth", ""], None, "usage", "cannot parse integer from empty string")
    case("usage_indent_i64_max", ["--indent", "9223372036854775807"], None, "usage", "9223372036854775807 is not in 0..=16")
    case("usage_indent_i64_overflow", ["--indent", "9223372036854775808"], None, "usage", "number too large to fit in target type")
    case("usage_indent_i64_underflow", ["--indent=-9223372036854775809"], None, "usage", "number too small to fit in target type")
    case("usage_indent_canonical_echo", ["--indent", "+017"], None, "usage", "17 is not in 0..=16, value echoed as +017")
    case("usage_indent_minus_zero", ["--encode", "--indent=-0"], NEST, "usage", "accepted as 0: a:\\nb: 1")
    case("usage_indent_space", ["--indent", " 4"], None, "usage", "invalid digit found in string")
    case("usage_indent_arabic_digit", ["--indent", "\u0661"], None, "usage", "invalid digit found in string")
    case("usage_flatten_depth_plus", ["--encode", "--key-folding", "safe", "--flatten-depth", "+2"], NEST, "usage", "accepted: a.b: 1")
    case("usage_delimiter_upper", ["--delimiter", "TAB"], None, "usage", "invalid delimiter")
    case("usage_delimiter_backslash_pipe", ["--delimiter", "\\|"], None, "usage", "invalid delimiter")
    case("usage_delimiter_newline", ["--delimiter", "a\nb"], None, "usage", "word echoed raw with its LF")
    case("usage_ignored_flag_validated_decode", ["-d", "--delimiter", "x"], SMALL_TOON, "usage", "exit 2")
    case("usage_ignored_flag_validated_encode", ["-e", "--expand-paths", "maybe"], SMALL_JSON, "usage", "exit 2")
    # ---- similarity tips (S1.73-S1.76, S1.84; OQ-A1, OQ-A2)
    case("usage_enum_similar_case", ["--key-folding", "Safe"], None, "usage", "tip safe")
    case("usage_enum_similar_prefix", ["--key-folding", "saf"], None, "usage", "tip safe")
    case("usage_enum_similar_off", ["--key-folding", "of"], None, "usage", "tip off")
    case("usage_enum_not_similar", ["--key-folding", "on"], None, "usage", "no tip")
    case("usage_enum_similar_picks_best", ["--key-folding", "sofa"], None, "usage", "tip off")
    case("usage_enum_similar_tie", ["--key-folding", "ofae"], None, "usage", "tip safe (later candidate wins)")
    case("usage_enum_similar_boundary_30", ["--expand-paths", "off" + "x" * 27], None, "usage", "tip off (exactly 7/10)")
    case("usage_enum_similar_boundary_31", ["--expand-paths", "off" + "x" * 28], None, "usage", "no tip")
    case("usage_similar_arg", ["--encod"], None, "usage", "tip --encode; Usage: toon --encode [INPUT]")
    case("usage_similar_arg_help", ["--e"], None, "usage", "tip --help; Usage: toon --help [INPUT]")
    case("usage_similar_arg_nope", ["--nope"], None, "usage", "tip --encode")
    case("usage_similar_arg_tie", ["--d"], None, "usage", "tip --indent (later candidate wins over decode)")
    case("usage_similar_arg_after_commit", ["--stats", "-e", "plain", "--nope"], None, "usage", "Usage: toon --stats --encode <INPUT>")
    # ---- flag forms (S1.8, S1.10, S1.151-S1.153, S5.102)
    case("flag_cluster_eo", ["-eo", "/dev/stdout"], SMALL_JSON, "flagform")
    case("flag_cluster_eo_attached", ["-eo/dev/stdout"], SMALL_JSON, "flagform")
    case("flag_output_short_equals", ["-o=/dev/stdout"], SMALL_JSON, "flagform", "one leading = is dropped")
    case("flag_cluster_do", ["-do", "/dev/stdout"], SMALL_TOON, "flagform", "Decoded line")
    case("flag_double_dash_only", ["--"], SMALL_JSON, "flagform", "stdin, encode")
    case("flag_double_dash_stdin", ["--", "-"], SMALL_JSON, "flagform", "stdin, encode")
    case("flag_output_with_dash_input", ["-o", "/dev/stdout", "-"], SMALL_JSON, "flagform", "label stdin")
    case("flag_output_dev_null", ["-e", "-o", "/dev/null"], SMALL_JSON, "flagform", "stdout empty, success line")
    case("flag_output_dev_stderr", ["-e", "-o", "/dev/stderr"], SMALL_JSON, "flagform", "TOON then success line on stderr")
    case("flag_indent_plus_nested", ["--encode", "--indent", "+4"], NEST, "flagform", "4 spaces visible")
    case("flag_decode_indent_0", ["-d", "--indent", "0"], "a: 1\nb[2]: 1,2\n", "flagform", "compact JSON")
    case("flag_decode_indent_4", ["-d", "--indent", "4"], "a:\n    b: 1\n", "flagform")
    case("flag_all_encode_only_on_decode", ["-d", "--key-folding", "safe", "--flatten-depth", "1", "--delimiter", "pipe", "--stats"], "a.b: 1\nt[2]: x,y\n", "flagform", "all ignored")
    case("flag_all_decode_only_on_encode", ["-e", "--no-strict", "--expand-paths", "safe"], '{"a.b":1,"t":["x","y"]}\n', "flagform", "all ignored")
    # ---- mode detection (S4.300-S4.304)
    case("auto_mixed_case_json", [afile("mixed.jSoN", SMALL_JSON)], None, "autodetect")
    case("auto_toon_json", [afile("x.toon.json", SMALL_JSON)], None, "autodetect", "last dot wins: encode")
    case("auto_trailing_dot", [afile("trailing.", SMALL_JSON)], None, "autodetect", "empty extension: encode")
    case("auto_dotfile_toon", [afile(".toon", SMALL_TOON)], None, "autodetect", "no extension: encode, JSON error")
    case("auto_hidden_toon", [afile(".hidden.toon", SMALL_TOON)], None, "autodetect", "decode")
    case("auto_double_dot_toon", [afile("..toon", SMALL_TOON)], None, "autodetect", "decode")
    case("auto_ext_trailing_space", [afile("space.toon ", SMALL_TOON)], None, "autodetect", "encode, JSON error")
    case("auto_dir_with_toon_ext", [afile("dir.toon/inner", SMALL_TOON)], None, "autodetect", "encode, JSON error")
    case("auto_fullwidth_ext", [afile("fw.\uff54\uff4f\uff4f\uff4e", SMALL_TOON)], None, "autodetect", "encode, JSON error")
    case("auto_empty_json_file", [afile("empty.json", "")], None, "autodetect", "EOF while parsing a value at line 1 column 0")
    case("auto_empty_toon_file", [afile("empty.toon", "")], None, "autodetect", "{}")
    case("auto_dev_stdin_path", ["/dev/stdin"], SMALL_JSON, "autodetect", "a path, no extension: encode")
    # ---- stats (S4.310-S4.319)
    case("stats_tie_to_even_down", ["--encode", "--stats"], '{"p":"' + "x" * 58 + '"}', "stats", "16 -> 15: 6.25 prints -6.2%")
    case("stats_tie_to_even_up", ["--encode", "--stats"], '{"r":[{"a":1,"b":2}],"p":"' + "x" * 37 + '"}', "stats", "16 -> 13: 18.75 prints -18.8%")
    case("stats_f64_below_tie", ["--encode", "--stats"], '{"r":[' + ",".join(['{"a":1,"b":2}'] * 8) + '],"p":"' + "x" * 194 + '"}', "stats", "80 -> 57: prints -28.7%")
    case("stats_f64_above_tie", ["--encode", "--stats"], '{"r":[' + ",".join(['{"a":1,"b":2}'] * 18) + '],"p":"' + "x" * 57 + '"}', "stats", "80 -> 31: prints -61.3%")
    case("stats_percent_100", ["--encode", "--stats"], "{" + ",".join(['"a":1'] * 2667) + "}", "stats", "4000 -> 2: prints -100.0%")
    case("stats_root_string", ["--encode", "--stats"], '"xxxxxx"', "stats", "2 -> 1: -50.0%")
    case("stats_root_null", ["--encode", "--stats"], "null", "stats", "1 -> 1")
    case("stats_root_empty_array", ["--encode", "--stats"], "[]", "stats", "1 -> 1")
    case("stats_toon_larger", ["--encode", "--stats"], "[1,2,3,4,5,6,7,8,9,10]", "stats", "5 -> 6, no Saved line")
    case("stats_pretty_json_words", ["--encode", "--stats"], '{ "a" : [ 1 , 2 , 3 ] , "b" : "x y z" }', "stats", "17 -> 6: -64.7%")
    case("stats_leading_trailing_ws_json", ["--encode", "--stats"], '   {"a" : 1}   \n\n', "stats", "3 -> 2: -33.3%")
    case("stats_supplementary_chars", ["--encode", "--stats"], '{"a":"' + "x\U000e0020" * 11 + 'x"}', "stats", "7 -> 6: scalar values, not bytes")
    case("stats_ws_each", ["--encode", "--stats"], '{"a":"x x\x85x\xa0x\u1680x\u2000x\u2001x\u2002x\u2003x\u2004x\u2005x\u2006x\u2007x\u2008x\u2009x\u200ax\u2028x\u2029x\u202fx\u205fx\u3000x\\tx\\nx\\u000bx\\u000cx\\rx"}\n', "stats", "21 -> 24: every White_Space code point once")
    case("stats_ws_lookalikes_a", ["--encode", "--stats"], '{"k":"x\x7f\xad\u180e\u200b\u200c\u200d\u2060\ufeff\u2800\u3164\\u001c\\u001dx"}\n', "stats", "8 -> 4; c is a multiple of 4 in both texts")
    case("stats_ws_lookalikes_b", ["--encode", "--stats"], '{"k":"x\x7f\xad\u180e\u200b\u200c\u200d\u2060\ufeff\u2800\u3164\\u001e\\u001fx"}\n', "stats", "8 -> 4")
    case("stats_json_error", ["--encode", "--stats"], "{bad", "stats", "only the JSON error")
    case("stats_output_bad_dir", ["--encode", "--stats", "-o", "cases/inputs/hand/no-such-dir/out.toon"], SMALL_JSON, "stats", "only the create error")
    case("stats_output_dev_null", ["--encode", "--stats", "-o", "/dev/null"], '{"a":1}', "stats", "1 -> 2, then success line")
    # ---- I/O (S9)
    case("io_output_is_dir", ["--encode", "-o", "cases/inputs/hand/files"], SMALL_JSON, "usage", "Is a directory (os error 21)")
    case("io_input_trailing_slash", ["cases/inputs/hand/files/plain.json/"], None, "usage", "Not a directory (os error 20)")
    case("io_utf8_error_beats_json_error", ["--encode"], b"{bad \xff", "json-error", "UTF-8 message, not the JSON one")
    case("io_json_error_beats_bad_output", ["--encode", "-o", "cases/inputs/hand/no-such-dir/out.toon"], "{bad", "json-error", "JSON message, not the create one")
    case("io_bom_json_file", [afile("bom.json", b"\xef\xbb\xbf" + SMALL_JSON.encode())], None, "json-error", "expected value at line 1 column 1")
    case("io_output_dev_full_8192", ["-e", "-o", "/dev/full"], '{"k":"' + "x" * 8188 + '"}', "usage", "LINUX: exit 0 and success line (S10.3)")  # LINUX
    case("io_output_dev_full_8193", ["-e", "-o", "/dev/full"], '{"k":"' + "x" * 8189 + '"}', "usage", "LINUX: Failed to write to file '/dev/full': No space left on device (os error 28)")  # LINUX
    case("io_output_dev_full_stats", ["-e", "--stats", "-o", "/dev/full"], '{"a":1}', "usage", "LINUX: write error even for 5 bytes")  # LINUX


_proposed_a()

def _proposed_b():
    """Cases proposed by extractor B_json_io (docs/spec-parts/B_json_io.md, 'Cases to add'); each was run on the oracle there."""
    case("jsonerr_eof_after_comma_arr", ["--encode"], '[1,', "json-error", "EOF after a comma is 'a value', not 'a list'", "json")
    case("jsonerr_eof_after_comma_obj", ["--encode"], '{"a":1,\n  ', "json-error", "EOF after a comma in an object; column counts bytes after the last LF", "json")
    case("jsonerr_eof_in_array_newline", ["--encode"], '[1,2\n', "json-error", "EOF position after a trailing LF is column 0 of the next line", "json")
    case("jsonerr_exp_sign_end", ["--encode"], '1e+', "json-error", "EOF after an exponent sign", "json")
    case("jsonerr_eof_after_backslash", ["--encode"], '"abc\\', "json-error", "EOF right after a backslash", "json")
    case("jsonerr_eof_after_high_surrogate", ["--encode"], '"\\ud800', "json-error", "EOF where the low-surrogate escape must start", "json")
    case("jsonerr_eof_after_high_surrogate_backslash", ["--encode"], '"\\ud800\\', "json-error", "EOF after the backslash of the second escape", "json")
    case("jsonerr_ident_newline", ["--encode"], 'tru\n', "json-error", "the mismatching byte is LF: line 2 column 0 (contrast jsonerr_bad_true)", "json")
    case("jsonerr_ident_multibyte", ["--encode"], b'tr\xc3\xa9', "json-error", "column lands inside a multi-byte character", "json")
    case("jsonerr_ident_then_more", ["--encode"], 'nulll', "json-error", "a complete literal followed by a letter is 'trailing characters'", "json")
    case("jsonerr_short_hex_newline", ["--encode"], '"\\u12"\n', "json-error", "four bytes exist after \\u (they span the quote and the LF): invalid escape at line 2 column 0 (contrast jsonerr_short_hex)", "json")
    case("jsonerr_escape_newline", ["--encode"], '"\\\n"', "json-error", "the escape character is LF", "json")
    case("jsonerr_escape_multibyte", ["--encode"], b'"\\\xc3\xa9"', "json-error", "the escape character is the first byte of a multi-byte character", "json")
    case("jsonerr_escape_upper_u", ["--encode"], '"\\U0041"', "json-error", "escape letters are case-sensitive", "json")
    case("jsonerr_hex_multibyte", ["--encode"], b'"\\u12\xc3\xa9x"', "json-error", "the four bytes after \\u are taken blindly", "json")
    case("jsonerr_dot_nondigit", ["--encode"], '[1.]', "json-error", "a fraction needs a digit: invalid number at the offending byte", "json")
    case("jsonerr_dot_newline", ["--encode"], '1.\n', "json-error", "the offending byte is LF (contrast jsonerr_dot_end)", "json")
    case("jsonerr_exp_nondigit", ["--encode"], '[1e]', "json-error", "an exponent needs a digit", "json")
    case("jsonerr_exp_double_sign", ["--encode"], '1e+-1', "json-error", "only one sign", "json")
    case("jsonerr_minus_newline", ["--encode"], '-\n1', "json-error", "minus followed by LF", "json")
    case("jsonerr_neg_leading_zero", ["--encode"], '-01', "json-error", "leading zero after a minus", "json")
    case("jsonerr_minus_infinity", ["--encode"], '-Infinity', "json-error", "a minus commits to a number", "json")
    case("jsonerr_number_then_letter", ["--encode"], '[1x]', "json-error", "a number ends at the first byte that cannot continue it", "json")
    case("jsonerr_hex_number", ["--encode"], '0x10', "json-error", "trailing characters after 0", "json")
    case("jsonerr_out_of_range_long_int", ["--encode"], "9" * 309, "json-error", "309 integer digits overflow; column is the end of the digits", "json")
    case("jsonerr_out_of_range_then_more", ["--encode"], '[1e400,2]', "json-error", "position is the end of the number token", "json")
    case("jsonerr_raw_nul_in_string", ["--encode"], b'"a\x00b"', "json-error", "U+0000 raw", "json")
    case("jsonerr_raw_us_in_string", ["--encode"], b'"a\x1fb"', "json-error", "U+001F raw is the last rejected byte", "json")
    case("jsonerr_raw_cr_in_string", ["--encode"], '"a\rb"', "json-error", "CR raw: rejected, and CR does not start a new line for positions", "json")
    case("jsonerr_key_not_string_after_comma", ["--encode"], '{"a":1,b:2}', "json-error", "second key position", "json")
    case("jsonerr_obj_comma_then_bracket", ["--encode"], '{"a":1,]', "json-error", "after a comma only a quote, a closing brace or EOF have their own outcome", "json")
    case("jsonerr_obj_leading_comma", ["--encode"], '{,}', "json-error", "first key position", "json")
    case("jsonerr_arr_leading_comma", ["--encode"], '[,]', "json-error", "first element position", "json")
    case("jsonerr_arr_double_comma", ["--encode"], '[1,,2]', "json-error", "", "json")
    case("jsonerr_arr_comma_then_brace", ["--encode"], '[1,}', "json-error", "", "json")
    case("jsonerr_high_then_escape", ["--encode"], '"\\ud800\\n"', "json-error", "backslash then a byte other than u", "json")
    case("jsonerr_high_then_newline", ["--encode"], '"\\ud800\n"', "json-error", "the byte after the high surrogate is LF", "json")
    case("jsonerr_high_then_bad_hex", ["--encode"], '"\\ud800\\uzzzz"', "json-error", "second escape has bad hex digits", "json")
    case("jsonerr_high_then_high", ["--encode"], '"\\ud800\\ud800"', "json-error", "", "json")
    case("jsonerr_trailing_comma_newline", ["--encode"], '[1,\n]', "json-error", "position of the closing bracket on the next line", "json")
    case("jsonerr_trailing_second_line", ["--encode"], b'{}\n\n\xc3\xa9', "json-error", "", "json")
    case("jsonerr_trailing_close", ["--encode"], '[]]', "json-error", "", "json")
    case("jsonerr_trailing_nul", ["--encode"], b'1\x00', "json-error", "a real NUL byte is not end of input", "json")
    case("jsonerr_vt_ws", ["--encode"], b'\x0b1', "json-error", "VT is not whitespace", "json")
    case("jsonerr_ls_ws", ["--encode"], b'\xe2\x80\xa81', "json-error", "U+2028 is not whitespace", "json")
    case("jsonerr_cr_not_newline", ["--encode"], '[1,\r\r oops]', "json-error", "CR counts as a column byte", "json")
    case("jsonerr_colon_multibyte", ["--encode"], b'{"\xc3\xa9"\xc3\xa9}', "json-error", "", "json")
    case("jsonerr_deep_mixed_128", ["--encode"], "".join("[" if i % 2 == 0 else '{"k":' for i in range(128)), "json-error", "arrays and objects share one depth counter", "json")
    case("jsonerr_deep_128_second_line", ["--encode"], "[" * 127 + "\n   {", "json-error", "position of the 128th opening bracket", "json")
    case("jsonerr_deep_sibling_127", ["--encode"], "[" + "[" * 126 + "]" * 126 + "," + "[" * 127 + "]" * 127 + "]", "json-error", "depth is given back when a container closes", "json")
    case("jsonerr_error_before_limit", ["--encode"], "[" * 127 + ",", "json-error", "an error at depth 127 is reported normally", "json")
    case("jsonerr_utf8_after_syntax_error", ["--encode"], b'{bad json \xff', "json-error", "the UTF-8 check covers the whole input before any JSON parsing", "json")
    case("jsonerr_utf8_surrogate", ["--encode"], b'"\xed\xa0\x80"', "json-error", "a UTF-8-encoded surrogate is invalid UTF-8", "json")
    case("jsonerr_utf8_above_max", ["--encode"], b'"\xf4\x90\x80\x80"', "json-error", "above U+10FFFF", "json")
    case("enc_deep_arrays_127", ["--encode"], "[" * 127 + "]" * 127, "enc-string", "deepest accepted nesting", "json")
    case("enc_deep_objects_127", ["--encode"], '{"a":' * 126 + "{}" + "}" * 126, "enc-string", "deepest accepted nesting, objects", "json")
    case("enc_deep_siblings_126", ["--encode"], "[" + "[" * 126 + "]" * 126 + "," + "[" * 126 + "]" * 126 + "]", "enc-string", "two siblings each reaching depth 127", "json")
    case("encstr_escapes_in_all", ["--encode"], '{"q":"a\\"b","bs":"a\\\\b","n":"a\\nb","r":"a\\rb","t":"a\\tb","up":"\\u00E9\\uD83D\\uDE00","mix":"\\uD83d\\uDe00","max":"\\udbff\\udfff","min":"\\ud800\\udc00","edge":"\\ud7ff\\ue000\\uffff"}\n', "enc-string", "every escape, both hex cases, surrogate-pair extremes", "json")
    case("encstr_raw_del_in", ["--encode"], b'{"del":"a\x7fb","c1":"a\xc2\x85b","ls":"a\xe2\x80\xa8b"}\n', "enc-string", "raw DEL, C1 and U+2028 are accepted inside strings", "json")
    case("encstr_duplicate_keys_escaped", ["--encode"], '{"\\u0061":1,"b":2,"a":3}\n', "enc-string", "keys are compared after unescaping", "json")
    case("encstr_duplicate_keys_replace_container", ["--encode"], '{"a":{"x":1},"b":2,"a":[3],"b":{"y":1}}\n', "enc-string", "a duplicate replaces the whole value, no merging", "json")
    case("encstr_key_order", ["--encode"], '{"b":1,"a":2,"10":3,"9":4,"B":5,"":6}\n', "enc-string", "input order, no sorting", "json")
    case("encstr_magic_keys", ["--encode"], '{"$serde_json::private::RawValue":"[1,2]","$serde_json::private::Number":"12"}\n', "enc-string", "no special keys in the pinned feature set", "json")
    case("encstr_ws_everywhere", ["--encode"], ' \t\r\n[ \t\r\n1 \t\r\n, \t\r\n{ \t\r\n"a" \t\r\n: \t\r\nnull \t\r\n} \t\r\n] \t\r\n', "enc-string", "all four whitespace bytes in every gap", "json")
    case("jsonout_compact_shapes", ["--decode", "--indent", "0"], 'a: 1\nb[2]: x,y\nc: "q\\"z"\nd:\ne[0]:\nf: null\ng: true\nh: false\n', "json-out", "compact form, streaming writer", "toon")
    case("jsonout_compact_shapes_expand", ["--decode", "--indent", "0", "--expand-paths", "safe"], 'a: 1\nb[2]: x,y\nc: "q\\"z"\nd:\ne[0]:\nf: null\ng: true\nh: false\n', "json-out", "compact form, second writer", "toon")
    case("jsonout_compact_nested_expand", ["--decode", "--indent", "0", "--expand-paths", "safe"], 'a.b: 1\na.c[2]: 1,2\na.d.e: x\n', "json-out", "nested containers in compact form", "toon")
    case("jsonout_root_array_compact_ok", ["--decode", "--indent", "0"], '[3]: 1,two,true', "json-out", "root array, compact, streaming writer", "toon")
    case("jsonout_root_array_compact_expand", ["--decode", "--indent", "0", "--expand-paths", "safe"], '[3]: 1,two,true', "json-out", "root array, compact, second writer", "toon")
    case("jsonout_root_string_expand", ["--decode", "--expand-paths", "safe"], 'hello world', "json-out", "root primitive through the second writer", "toon")
    case("jsonout_root_number_expand", ["--decode", "--expand-paths", "safe"], '42', "json-out", "root number through the second writer", "toon")
    case("jsonout_root_empty_doc_expand", ["--decode", "--expand-paths", "safe"], '', "json-out", "empty document through the second writer", "toon")
    case("jsonout_root_empty_array_expand", ["--decode", "--expand-paths", "safe"], '[0]:', "json-out", "root empty array through the second writer", "toon")
    case("jsonout_indent_1_ok", ["--decode", "--indent", "1"], 'o:\n e:\n a[0]:\n l[2]: 1,2\n t[2]{x,y}:\n  1,a\n  2,b\n m[3]:\n  - 1\n  - k: v\n   z[0]:\n  - [2]: a,b\ns: "q\\"uote"\n', "json-out", "the JOUT document re-indented with a 1-space unit", "toon")
    case("jsonout_expand_indent_1_ok", ["--decode", "--indent", "1", "--expand-paths", "safe"], 'o:\n e:\n a[0]:\n l[2]: 1,2\n t[2]{x,y}:\n  1,a\n  2,b\n m[3]:\n  - 1\n  - k: v\n   z[0]:\n  - [2]: a,b\ns: "q\\"uote"\n', "json-out", "same, second writer", "toon")
    case("jsonout_indent_4_ok", ["--decode", "--indent", "4"], 'o:\n    e:\n    a[0]:\n    l[2]: 1,2\n    t[2]{x,y}:\n        1,a\n        2,b\n    m[3]:\n        - 1\n        - k: v\n            z[0]:\n        - [2]: a,b\ns: "q\\"uote"\n', "json-out", "the JOUT document re-indented with a 4-space unit", "toon")
    case("jsonout_expand_indent_4_ok", ["--decode", "--indent", "4", "--expand-paths", "safe"], 'o:\n    e:\n    a[0]:\n    l[2]: 1,2\n    t[2]{x,y}:\n        1,a\n        2,b\n    m[3]:\n        - 1\n        - k: v\n            z[0]:\n        - [2]: a,b\ns: "q\\"uote"\n', "json-out", "same, second writer", "toon")
    case("jsonout_empty_in_array", ["--decode"], '[4]:\n  -\n  - [0]:\n  - [1]:\n    - [0]:\n  - k:\n    l[0]:\n', "json-out", "empty object and empty array as array elements", "toon")
    case("jsonout_empty_in_array_expand", ["--decode", "--expand-paths", "safe"], '[4]:\n  -\n  - [0]:\n  - [1]:\n    - [0]:\n  - k:\n    l[0]:\n', "json-out", "same, second writer", "toon")
    case("jsonout_escape_matrix", ["--decode"], b'q: "a\\"b"\nbs: "a\\\\b"\nn: "a\\nb"\nr: "a\\rb"\nt: "a\\tb"\nnul: "a\x00b"\nus: "a\x1fb"\nbel: "a\x07b"\nbsp: "a\x08b"\nvt: "a\x0bb"\nff: "a\x0cb"\ndel: "a\x7fb"\npad: "a\xc2\x80b"\nnel: "a\xc2\x85b"\napc: "a\xc2\x9fb"\nnbsp: "a\xc2\xa0b"\nshy: "a\xc2\xadb"\nls: "a\xe2\x80\xa8b"\nps: "a\xe2\x80\xa9b"\nbom: "a\xef\xbb\xbfb"\nslash: a/b\nemoji: "a\xf0\x9f\x98\x80b"\nmax: "a\xf4\x8f\xbf\xbfb"\n', "json-out", "streaming writer: every escape class in values", "toon")
    case("jsonout_escape_matrix_expand", ["--decode", "--expand-paths", "safe"], b'q: "a\\"b"\nbs: "a\\\\b"\nn: "a\\nb"\nr: "a\\rb"\nt: "a\\tb"\nnul: "a\x00b"\nus: "a\x1fb"\nbel: "a\x07b"\nbsp: "a\x08b"\nvt: "a\x0bb"\nff: "a\x0cb"\ndel: "a\x7fb"\npad: "a\xc2\x80b"\nnel: "a\xc2\x85b"\napc: "a\xc2\x9fb"\nnbsp: "a\xc2\xa0b"\nshy: "a\xc2\xadb"\nls: "a\xe2\x80\xa8b"\nps: "a\xe2\x80\xa9b"\nbom: "a\xef\xbb\xbfb"\nslash: a/b\nemoji: "a\xf0\x9f\x98\x80b"\nmax: "a\xf4\x8f\xbf\xbfb"\n', "json-out", "second writer: every escape class in values", "toon")
    case("jsonout_escape_keys", ["--decode"], b'"k\\"1": 1\n"k\\\\2": 2\n"k\\n3": 3\n"k\\t4": 4\n"k\x085": 5\n"k\x0c6": 6\n"k\x7f7": 7\n"k\xc2\x858": 8\n"k\x019": 9\n', "json-out", "streaming writer: keys are escaped like values", "toon")
    case("jsonout_escape_keys_expand", ["--decode", "--expand-paths", "safe"], b'"k\\"1": 1\n"k\\\\2": 2\n"k\\n3": 3\n"k\\t4": 4\n"k\x085": 5\n"k\x0c6": 6\n"k\x7f7": 7\n"k\xc2\x858": 8\n"k\x019": 9\n', "json-out", "second writer: keys are escaped like values", "toon")
    case("jsonout_deep_200", ["--decode"], "".join("  " * i + "k:\n" for i in range(200)) + "  " * 200 + "v: 1\n", "json-out", "writer A has no depth limit: 201 nested objects are printed (and cannot be read back by --encode)", "toon")


_proposed_b()

def _proposed_c():
    """Cases proposed by extractor C_numbers (docs/spec-parts/C_numbers.md, 'Cases to add'); each was run on the oracle there."""
    # S4.121 / S10.42: the 16 literals that encnum_mixed_digits never reaches (it dies at n17)
    enc("encnum_mixed_digits_ok", numobj(["7e22", "7e23", "3e25", "9e28", "5e-23", "7e-25", "0.1e-22", "33e22", "0.7e24", "123456789012345e8", "123456789012345e9", "1234567890123456e7", "12345678901234567e6", "2.5e-5", "4.9406564584124654e-324", "2.2250738585072009e-308"]), cls="enc-number", note="OQ-002: the literals masked by the error in encnum_mixed_digits")
    # S4.113 / S10.41: largest finite value, accepted and rejected spellings
    enc("encnum_max_finite_edge_ok", numobj(["1.7976931348623157e308", "17976931348623157e292", "0.17976931348623157e309", "0.00017976931348623157e312"]), cls="enc-number", note="accepted spellings of the largest finite value")
    enc("encnum_max_finite_edge_err", '{"a":1797693134862315700e290}\n', cls="enc-number", note="same value, rejected: F0 x P(290) overflows")
    # S4.132 / S4.172 / S10.44: the coordinator's four tie runs
    enc("encnum_tie_up_1", '{"v":2101031963024178.25}', cls="enc-number", note="Display tie -> up")
    enc("encnum_tie_up_2", '{"v":640138878210428.25}', cls="enc-number", note="Display tie -> up")
    dec("decfmt_tie_even_1", 'v: 2101031963024178.25\n', ["--indent", "0"], cls="dec-number", note="zmij tie -> even")
    dec("decfmt_tie_even_2", 'v: 640138878210428.25\n', ["--indent", "0"], cls="dec-number", note="zmij tie -> even")
    # more ties, negatives, a power-of-two tie, two near-ties (nearer wins), one exact 17-digit value
    enc("encnum_display_ties", numobj(["1125899906842624.25", "1125899906842624.75", "-1125899906842624.25", "-2101031963024178.25", "640138878210428.75", "2.98023223876953125e-8", "70740342978178.65625", "72024262991656.71875", "2251799813685248.5"]), cls="enc-number", note="tie -> up; near-ties -> nearer")
    dec("decfmt_shortest_ties", toonnums(["1125899906842624.25", "1125899906842624.75", "-1125899906842624.25", "-2101031963024178.25", "640138878210428.75", "2.98023223876953125e-8", "70740342978178.65625", "72024262991656.71875", "2251799813685248.5"]), cls="dec-number", note="tie -> even; near-ties -> nearer")
    # S4.105
    enc("encnum_longint_then_fraction", numobj(["184467440737095516160.0e-26", "18446744073709551619703.191e21", "18446744073709551617186.486e-19", "18446744073709551618.396e-25"]), cls="enc-number", note="fraction digit accepted after dropped integer digits")
    # S4.102: the 20th digit is kept when it fits
    enc("encnum_twentieth_digit", numobj(["11785025517160790966", "1.5678513690420032304", "1.3213224190271156768", "18086891712187664377e-5", "12852728877913788482e3"]), cls="enc-number", note="20-digit significands below 2^64")
    # S4.112 to S4.114: inexact table entries, one multiply or divide
    enc("encnum_pow10_inexact", numobj(["5e24", "3e34", "56e-23", "7740e24", "5e29", "5542e30", "651e-23"]), cls="enc-number", note="rounded P(k), two roundings")
    # S4.115: repeated division by P(308)
    enc("encnum_two_step_division", numobj(["4743e-309", "690344e-314", "234768e-309", "10138e-313", "1e-309", "1e-617", "1e-640", "123e-700"]), cls="enc-number", note="T < -308")
    # S4.175 / S10.45
    enc("encnum_text_changes", numobj(["90775.01101792969", "93571168.51572259", "16606968549.412615", "9.560342718892495e+18", "2.682407416493281e-8"]), cls="enc-number", note="zmij-printed text that the JSON reader does not reproduce")
    # S4.111
    enc("encnum_u64_round_ties", numobj(["9007199254740995", "9007199254740997", "-9007199254740995", "18014398509481986", "18014398509481990", "36028797018963972"]), cls="enc-number", note="u64 -> f64 ties to even")
    # S4.107 to S4.109
    enc("encnum_exponent_forms", numobj(["1e00000000000000000000005", "123e00000000000000000000001", "0e2147483648", "1e-2147483648", "-1e-2147483648", "0.000e99999999999999999999", "1E+2", "1e-0", "0.1e309", "10e-309"]), cls="enc-number", note="exponent accumulator edges that are not errors")
    enc("encnum_exp_i32_edge", '{"a":1e2147483647}\n', cls="enc-number", note="no digit overflow; rejected by T > 308 at the last byte (column 17)")
    # S9.203
    enc("encnum_exp_overflow_multiline", '{"a":[1,\n2,\n  1e99999999999999999999]}', cls="enc-number", note="line 3 column 14")
    enc("encnum_error_column_bytes", '{"é":1e309}', cls="enc-number", note="column counts bytes: 11")
    # S4.116
    enc("encnum_long_integer_out_of_range", '{"a":1' + '0' * 309 + '}\n', cls="enc-number", note="310-digit integer: S = 10^19, T = 290, infinite product (S4.113)")
    enc("encnum_long_integer_308", '{"a":1' + '0' * 308 + '}\n', cls="enc-number", note="309-digit integer 1e308 is accepted")
    # S4.142, S4.143
    dec("decnum_finite_edge", toonnums(["1.797693134862315807e308", "1.797693134862315808e308", "1.7976931348623158e308", "-1.797693134862315808e308", "2.4703282292062327e-324", "2.4703282292062328e-324", "1e99999999999999999999", "1e-99999999999999999999", "0e99999999999999999999", "-0e99999999999999999999"]), cls="dec-number", note="exact overflow and underflow thresholds of the correctly rounded reader")
    dec("decnum_exact_halfway", toonnums(["1.00000000000000011102230246251565404236316680908203125", "1.000000000000000111022302462515654042363166809082031250000000000000000000000000000000000000000000000000000000000001", "9007199254740993", "9007199254740993.00000000000000000000000000000000000001"]), cls="dec-number", note="exact midpoints go to even; one more digit tips them")
    # S4.145
    dec("decnum_trim_unicode", 'a:  42 \nb:  42\nc: ​42\nd:    7   \n', cls="dec-number", note="Unicode White_Space is trimmed, U+200B is not")
    # S4.161, S10.49
    enc("encstr_numeric_like_forms", json.dumps({"a": "007abc", "b": "00x", "c": "-00abc", "d": "0e", "e": "07٠", "f": "1e309", "g": "0.5.5", "h": "1.e5", "i": "-0", "j": "1E5", "k": "1e+5", "l": "0", "m": "-", "n": "12abc", "o": "00.", "p": "1.5E+", "q": "123456789012345678901234567890"}, ensure_ascii=False) + "\n", note="is_numeric_like grammar, early acceptance on leading zeros")
    # S4.190, S4.191, S10.50
    dec("toonedge_length_forms", 'a[+2]: 1,2\nb[007]: 1,2,3,4,5,6,7\nc[18446744073709551616]: 1\nd[ 2]: 1,2\ne[-0]: 1\nf[+0]:\n', cls="toon-edge", note="usize parse of [N]")
    dec("toonerr_length_u64_max", 'a[18446744073709551615]: 1\n', cls="toon-error", note="largest parsable length hits the cap")
    dec("toonerr_length_leading_zero_over_cap", 'a[0100000001]: 1\n', cls="toon-error", note="message prints the parsed value, not the text")


_proposed_c()

def _proposed_d():
    """Cases proposed by extractor D_encode (docs/spec-parts/D_encode.md, 'Cases to add'); each was run on the oracle there."""
    F = ["--key-folding", "safe"]
    # --- key folding: list items, collisions, root literals, budget (S4.63-S4.80, S10.61-S10.63, S10.66, S10.76)
    enc("enc_fold_list_item_first_field", json.dumps([{"a": {"b": 1}, "c": {"d": {"e": 2}}}]) + "\n", F, note="first field of a list item is never folded; the rest is")
    enc("enc_fold_list_item_dup_key", json.dumps([{"c.d": 7, "c": {"d": 1}}]) + "\n", F, note="S10.61: sibling check ignores the first field -> duplicate key c.d")
    enc("enc_fold_list_item_rest_collision", json.dumps([{"x": 1, "c": {"d": 1}, "c.d": 7}]) + "\n", F, note="sibling check among remaining fields works")
    enc("enc_fold_root_literal_nested", json.dumps({"x": {"a": {"b": 1}, "c": 2}, "x.a.b": 3}) + "\n", F, note="root-literal check through a path prefix")
    enc("enc_fold_nested_literal_not_root", json.dumps({"r": {"s": {"p": {"q": 1}}, "s.p.q": 9, "z": 1}}) + "\n", F, note="S10.62: nested dotted literals are not in the root set")
    enc("enc_fold_partial_prefix_literal", json.dumps({"a": {"b": {"c": {"d": 1}, "k": 2}}, "a.b.c.d": 5}) + "\n", F, note="prefix after a partial fold is the folded key")
    enc("enc_fold_root_literal_ignored_in_list", json.dumps({"arr": [{"x": 1, "c": {"d": 1}}], "c.d": 7}) + "\n", F, note="no root-literal set inside list items")
    enc("enc_fold_dotted_parent_path", json.dumps({"u": {"v.w": {"a": {"b": 1}}}, "u.v.w.a.b": 1}) + "\n", F, note="S10.76: raw dot-join of the path")
    enc("enc_fold_literal_words", json.dumps({"true": {"null": 1}, "_": {"_1": {"A": "x"}}, "": {"a": 1}, "é": {"a": 1}, "1a": {"b": 1}}) + "\n", F, note="identifier segments: true/null/_ fold; empty, non-ASCII, digit-first do not")
    enc("enc_fold_budget_threading_5", json.dumps({"a": {"b": {"x": {"y": {"z": {"w": 1}}}, "k": 1}}}) + "\n", F + ["--flatten-depth", "5"], note="budget 5-2=3 passed into the remainder")
    enc("enc_fold_budget_threading_4", json.dumps({"a": {"b": {"x": {"y": {"z": {"w": 1}}}, "k": 1}}}) + "\n", F + ["--flatten-depth", "4"], note="budget 4-2=2, then 0")
    enc("enc_fold_budget_not_consumed", json.dumps({"m": {"p": 1, "n": {"a": {"b": {"c": 1}}}}}) + "\n", F + ["--flatten-depth", "2"], note="a non-folded parent passes the budget unchanged")
    enc("enc_fold_budget_reset_in_list", json.dumps({"a": {"b": [{"x": 1, "c": {"d": {"e": 1}}}]}}) + "\n", F + ["--flatten-depth", "2"], note="S10.63: budget restarts inside list items")
    enc("enc_fold_budget_sibling", json.dumps({"a": {"b": {"c": 1}}, "a.b": 2}) + "\n", F + ["--flatten-depth", "2"], note="the budget creates a sibling collision")
    enc("enc_fold_unlimited_refuses", json.dumps({"a": {"b": {"c-d": 1}}}) + "\n", F, note="S10.66 pair: unlimited budget refuses the whole chain")
    enc("enc_fold_depth2_enables_fold", json.dumps({"a": {"b": {"c-d": 1}}}) + "\n", F + ["--flatten-depth", "2"], note="S10.66 pair: budget 2 folds a.b")
    # --- list items, tabular detection, arrays of arrays (S4.35-S4.54, S10.64)
    SHAPES = [{"p": 1, "z": 0}, {"ea": [], "z": 0}, {"pa": [1, "a"], "z": 0}, {"ta": [{"i": 1, "j": "x|y"}, {"j": "k", "i": 2}], "z": 0}, {"la": [{"i": 1}, {"j": 2}], "z": 0}, {"aa": [[1], []], "z": 0}, {"ma": [1, {"q": 1}, [2, [3]]], "z": 0}, {"o": {"k": 1, "l": {"m": 2}}, "z": 0}, {"eo": {}, "z": 0}, {"a b": [1, 2], "z": {"y": [{"id": 1}, {"id": 2}]}}, {}, {"only": {}}]
    enc("enc_list_first_field_shapes", json.dumps(SHAPES) + "\n", note="every first-field shape, depth i+1 vs i+2")
    enc("enc_list_first_field_shapes_pipe_indent3", json.dumps(SHAPES) + "\n", ["--delimiter", "|", "--indent", "3"], note="same under pipe and indent 3 (S10.68)")
    enc("enc_tabular_corners", json.dumps({"a": [{}, {}], "b": [{"a": 1, "b": 2}, {"a": 1, "c": 2}], "c": [{"a": 1}], "d": [{"a": 1, "b": None, "c": True, "d": "", "e": -0.0, "f": 1.5}], "e": [{"a": 1}, {"a": [1]}], "f": [{"a": [1]}, {"a": 1}], "g": [{"a": 1}, {"a": 1, "b": 2}], "h": [{"a": 1, "b": 2}, {"a": 1}], "i": [{"a": 1}, {}], "j": [{}, {"a": 1}], "k": [{"a": {}}], "l": [{"a": 1}, {"a": {}}]}) + "\n", note="tabular detection corner by corner")
    enc("enc_aoa_corners", json.dumps({"a": [[]], "b": [[], [1]], "c": [[[]]], "d": [[1], [[2]]], "e": [[], {}], "f": [[], 1], "g": [[1, 2], [3, {"x": 1}]], "h": [[{"id": 1}, {"id": 2}]], "i": [[[1, 2], [3]], [[4]]]}) + "\n", note="arrays of arrays with empties; S10.64 (h is not tabular)")
    ROWS = {"r": [{"s": "a,b", "t": "c|d", "u": "e\tf", "v": "", "w": " x", "y": "-z", "n": "12", "b": "true", "q": "a\"b", "c": "k:v"}, {"s": "p", "t": "q", "u": "r", "v": "s", "w": "t", "y": "u", "n": "v", "b": "w", "q": "x", "c": "y"}]}
    enc("enc_tabular_quoting_comma", json.dumps(ROWS) + "\n", note="cells that need quotes, comma")
    enc("enc_tabular_quoting_pipe", json.dumps(ROWS) + "\n", ["--delimiter", "pipe"], note="same, pipe")
    enc("enc_tabular_quoting_tab", json.dumps(ROWS) + "\n", ["--delimiter", "\\t"], note="same, tab")
    NAMES = [{"a,b": 1, "c|d": 2, "e\tf": 3, "ok": 4, "": 5, "true": 6, "1": 7}] * 2
    enc("enc_tabular_field_names_comma", json.dumps(NAMES) + "\n", note="field names under the key rule")
    enc("enc_tabular_field_names_pipe", json.dumps(NAMES) + "\n", ["--delimiter", "|"], note="same, pipe")
    enc("enc_tabular_field_names_tab", json.dumps(NAMES) + "\n", ["--delimiter", "tab"], note="same, tab")
    EMPTIES = {"a": [], "b": [[]], "c": [{"d": []}], "e": {"f": []}}
    enc("enc_empty_headers_tab", json.dumps(EMPTIES) + "\n", ["--delimiter", "tab"], note="[0<TAB>]: in every header position")
    enc("enc_empty_headers_pipe_folded", json.dumps(EMPTIES) + "\n", ["--delimiter", "|", "--key-folding", "safe"], note="[0|]: and a folded empty array e.f[0|]:")
    # --- strings and keys (S4.8-S4.11, S4.16, S4.22, S10.65)
    WS25 = [0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0x85, 0xA0, 0x1680, *range(0x2000, 0x200B), 0x2028, 0x2029, 0x202F, 0x205F, 0x3000]
    NEAR = [0x1C, 0x1F, 0x180E, 0x200B, 0x200D, 0x2060, 0xFEFF]
    enc("encstr_ws_edge_sweep", json.dumps({**{"L%04X" % c: chr(c) + "x" for c in WS25 + NEAR}, **{"T%04X" % c: "x" + chr(c) for c in WS25 + NEAR}}) + "\n", note="all 25 White_Space code points at both edges (quoted) and 7 near-misses (bare)")
    enc("encstr_ws_only", json.dumps({"sp": " ", "sp3": "   ", "tab": "\t", "tabs": "\t\t", "sptab": " \t ", "vt": "\u000b", "ff": "x\u000c", "nel": "\u0085", "ls": "     ", "ps": "x     ", "zwsp": "​x", "bom": "﻿", "mvs": "᠎x", "us": "\u001fx", "fs": "x\u001c", "nbsp_mid": "a b", "vt_mid": "a\u000bb", "ideo": "　", "nul": "\u0000", "del": "\u007f", "c1": "\u009fx"}) + "\n", note="whitespace-only and control-only strings")
    NUMLIKE = ["0", "00", "-0", "-00", "007", "007abc", "0123abc", "-01x", "00:", "0.5", "0x10", "1.", "1e", "1e+", "1e+5", "1E5", "-1E-5", "1.e5", "1.5e3", "01.5", "0e0", "00e", "0.", "-", ".5", "+5", "-.5", "1_000", "１２", "١٢", "1.2.3", "1 2", "Infinity", "NaN", "-Infinity", "0b1", "1e5x", "1.5x", "-a", "--1", "- 1", "-1", "a-", "1-", "12a", "1e5.5", "1.0e", "9" * 30, "0.0", "-0.0", "0e", "05", "5", "1e05", "1e-05", "00.5", "0-"]
    enc("encstr_numeric_like", json.dumps({"k%d" % i: v for i, v in enumerate(NUMLIKE)}) + "\n", note="numeric-like pattern and the leading-zero shortcut (S10.65)")
    enc("encstr_keys_literals", json.dumps({"null": 1, "false": 2, "_": 3, "a.": 4, "a.b.": 5, "Z9": 6, "a|b": 7, "a\tb": 8, "a\\b": 9, "x\u0001y": 10, "éa": 11, "aé": 12, "-1": 13, "1": 14, "1.5": 15, "e": 16, "k\rq": 17}) + "\n", note="keys that look like literals, numbers, or hold control characters")
    enc("encstr_root_delim_pipe", json.dumps("a|b") + "\n", ["--delimiter", "pipe"], note="the active delimiter also governs a root string")


_proposed_d()

def _proposed_e():
    """Cases proposed by extractor E_decode (docs/spec-parts/E_decode.md, 'Cases to add'); each was run on the oracle there."""
    # ---- scanner (S2.105, S2.106, S2.111, S2.113, S2.114, S10.92-S10.94)
    dec("toonerr_scan_error_beats_parse_error", "bare\nalso bare\n   x: 1\n", cls="toon-error", note="S2.111: line-3 indentation error wins over Missing colon on line 2")
    dec("toonedge_blank_line_with_tab_ok", "a: 1\n\t\n \t \nb: 2\n", cls="toon-edge", note="S2.105: blank lines are exempt from the strict tab check")
    dec("toonedge_unicode_ws_blank", "\u00a0\n\u0085\n\u3000\na: 1\n", cls="toon-edge", note="S2.106: White_Space-only lines are blank")
    dec("toonedge_crlf_bare_dash", "x[1]:\r\n  -\r\n", cls="toon-edge", note="S2.113: '-\\r' is not a list item -> Expected 1 list array items, but got 0")
    dec("toonedge_bom_root_array", "\ufeff[2]: a,b", cls="toon-edge", note="S2.114: BOM defeats the root-array test -> object with key U+FEFF")
    dec("toonerr_tab_delim_empty_first_cell", "t[1\t]{a\tb}:\n  \t2\n", cls="toon-error", note="S10.94: leading tab cell hits the strict tab check")
    # ---- header parser (S2.133-S2.139, S10.83, S10.84, S10.87-S10.89, S10.97, S10.99)
    dec("toonedge_header_ignored_text", "a[2][3]: x,y\n\"b\"[1]extra: z\nc[2]extra{p,q}:\n  1,2\n  3,4\n", cls="toon-edge", note="S2.133: text between ] and { or : is ignored")
    dec("toonedge_header_key_with_colon", "a: [1]: x\n", cls="toon-edge", note="S2.130: a '[' after the key colon is value text -> {\"a\":\"[1]: x\"} (until 7c1d6e4 the key was {\"a:\":[\"x\"]}, S10.89)")
    dec("toonedge_header_in_quoted_value", "a: \"x[1]: y\"\n", cls="toon-edge", note="S10.83 (fixed in 7c1d6e4): a bracket inside a quoted value is value text -> {\"a\":\"x[1]: y\"}")
    dec("toonerr_cap_in_quoted_value", "note: \"see [999999999999]: x\"\n", cls="toon-error", note="S10.84 (fixed in 7c1d6e4): the cap no longer fires inside a quoted value -> the string")
    dec("toonedge_length_plus_and_zero", "a[+2]: x,y\nb[02]: x,y\nc[ 2]: x,y\n", cls="toon-edge", note="S2.135: '+2' and '02' are lengths, ' 2' is not")
    dec("toonedge_length_u64_overflow", "items[18446744073709551616]: 1\n", cls="toon-edge", note="S2.135: 2^64 does not parse -> plain key")
    dec("toonerr_length_u64_max_list", "items[18446744073709551615]:\n", cls="toon-error", note="S2.136: 2^64-1 parses -> cap message with the full number (list-header variant of toonerr_length_u64_max)")
    dec("toonerr_escape_beats_bad_length", "\"a\\x\"[abc]: 1\n", cls="toon-error", note="S2.139: key escape error before the bracket content is judged")
    dec("toonedge_inline_beats_fields", "t[2]{a,b}: 1,2\n", cls="toon-edge", note="S4.210: inline values win over the fields segment")
    dec("toonedge_fields_space_only", "items[1]{ }:\n  - 1\n", cls="toon-edge", note="S2.137: '{ }' is one field named '' -> [{\"\":\"- 1\"}]")
    # ---- structure (S4.202-S4.207, S4.217, S10.80, S10.81, S10.90, S10.98)
    dec("toonedge_root_array_trailing_ignored", "[2]: a,b\nc: 1\n", cls="toon-edge", note="S4.202: lines after a root array are ignored")
    dec("toonedge_rest_dropped_after_overindent", "a:\n  b: 1\n    c: 2\n  d: 3\ne: 4\n", cls="toon-edge", note="S4.204/S10.80: everything after the over-indented line is dropped -> {\"a\":{\"b\":1.0}}")
    dec("toonlenient_leftover_rows_drop_rest", "t[1]{a,b}:\n  1,2\n  3,4\nk: 1\n", ["--no-strict"], cls="toon-edge", note="S4.217: leftover row ends the document, k is lost")
    dec("toonedge_root_vs_item_keyvalue", "a\"b: c\n", cls="toon-edge", note="S4.203: root rule ignores quotes -> object")
    dec("toonedge_item_quote_hides_colon", "l[1]:\n  - a\"b: c\n", cls="toon-edge", note="S4.224: list-item rule is quote-aware -> string")
    dec("toonlenient_tab_quoted_key", "\t\"a\": 1\n", ["--no-strict"], cls="toon-edge", note="S10.90: key keeps its quotes")
    dec("toonedge_list_item_two_spaces_quoted_key", "l[1]:\n  -  \"a\": b\n", cls="toon-edge", note="S10.90: strict mode, key keeps its quotes")
    dec("toonedge_nested_129_no_expand", "".join("  " * i + "k:\n" for i in range(128)) + "  " * 128 + "v: 1\n", cls="toon-edge", note="S2.150: no nesting limit without expansion")
    # ---- arrays (S4.212-S4.215, S4.224, S4.225, S10.85)
    dec("toonerr_tabular_rows_too_few", "t[2]{a,b}:\n  1,2\n", cls="toon-error", note="S9.110: Expected 2 tabular rows, but got 1")
    dec("toonerr_row_width_beats_bad_quote", "t[1]{a,b}:\n  1,2,\"x\n", cls="toon-error", note="S9.144: strict width check before token parsing")
    dec("toonlenient_row_bad_quote_in_surplus_cell", "t[1]{a,b}:\n  1,2,\"x\n", ["--no-strict"], cls="toon-edge", note="S4.212: surplus cells are still parsed -> Unterminated string")
    dec("toonedge_data_row_test", "t[1]{a,b}:\n  1,2\n  x: 4,5\n", cls="toon-edge", note="S4.214: colon before delimiter -> not a data row, accepted (and dropped)")
    dec("toonerr_data_row_delim_first", "t[1]{a,b}:\n  1,2\n  x,y: 4\n", cls="toon-error", note="S4.214: delimiter before colon -> found more")
    dec("toonerr_count_beats_blank", "l[3]:\n  - a\n\n  - b\n", cls="toon-error", note="S9.145: count message before the blank-line message")
    dec("toonerr_blank_inside_multiline_item", "l[1]:\n  - a: 1\n\n    b: 2\n", cls="toon-error", note="S4.215: range ends at the last consumed line -> Line 3")
    dec("toonerr_extra_bare_dash_undetected", "l[1]:\n  - a\n  -\n", cls="toon-error", note="S10.85: surplus bare '-' is not reported, exit 0")
    dec("toonedge_list_first_field_list_depth", "l[1]:\n  - k[2]:\n      - a\n      - b\n    m: 1\n", cls="toon-edge", note="S4.224: items of a first-field list sit at item depth + 2")
    dec("toonerr_list_first_field_list_shallow", "l[1]:\n  - k[2]:\n    - a\n    - b\n", cls="toon-error", note="S4.224/S10.86: items at + 1 -> Expected 2 list array items, but got 0")
    dec("toonerr_sibling_bare_dash", "l[1]:\n  - a: 1\n    -\n", cls="toon-error", note="S4.225: bare '-' sibling is read as a key -> Missing colon after key")
    # ---- expansion (S3.26, S4.242, S4.248, S4.249)
    dec("toonedge_expand_quoted_unquoted_same_key", "\"a.b\": 1\na.b: 2\n", ["--expand-paths", "safe"], cls="toon-edge", note="S3.26: both count as quoted -> conflict at key \"a.b\"")
    dec("toonedge_expand_quoted_unquoted_same_key_lenient", "\"a.b\": 1\na.b: 2\n", ["--expand-paths", "safe", "--no-strict"], cls="toon-edge", note="S3.26: -> {\"a.b\":2.0}")
    dec("toonerr_expand_value_error_first", "a: 1\na:\n  x.y: 1\n  x: 2\n", ["--expand-paths", "safe"], cls="toon-error", note="S4.242: inner conflict (key x) before the conflict at a")
    dec("toonerr_decode_beats_expand", "a.b: 1\na: 2\nl[2]: x\n", ["--expand-paths", "safe"], cls="toon-error", note="S4.249: decode error on line 3 before the expansion conflict")
    dec("toonedge_expand_segments_253", ".".join(["k"] * 253) + ": 1\n", ["--expand-paths", "safe"], cls="toon-edge", note="S4.248: accepted")
    dec("toonerr_expand_segments_254", ".".join(["k"] * 254) + ": 1\n", ["--expand-paths", "safe"], cls="toon-error", note="S4.248: rejected")
    dec("toonedge_expand_nested_127", "".join("  " * i + "k:\n" for i in range(126)) + "  " * 126 + "v: 1\n", ["--expand-paths", "safe"], cls="toon-edge", note="S4.248: 127 objects accepted")
    dec("toonerr_expand_nested_128", "".join("  " * i + "k:\n" for i in range(127)) + "  " * 127 + "v: 1\n", ["--expand-paths", "safe"], cls="toon-error", note="S4.248: 128 objects rejected")


_proposed_e()


def _proposed_x():
    """Cases proposed by the pass-2 cross-surface reader (docs/spec-parts/pass2_X.md, 'Cases to add'); each was run on the oracle there."""
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
    enc("enc_value_looks_like_header", '{"a":"x[1]: y","b":"[1]:","c":"[abc] [1]: y","d":["x[1]: y"],"e":[{"f":"x[1]: y","g":[1]}]}\n', note="S4.12/S4.14: such values are quoted and nothing else; lines a, b and the item line f were the ones S10.83 broke on the way back before 7c1d6e4")
    dec("toonedge_header_in_value_first_bracket_only", 'a: "[abc] [1]: y"\nb: "x[1] y"\nc: "x[1\\t]: y"\nd: "x[1]{p:q}"\n', cls="toon-edge", note="S2.130-S2.135/S10.83: only the FIRST [ of the line is tried, it needs a length inside and a colon after; all four values survive")
    dec("toonerr_header_in_value_unterminated", 'a: "[1]:"\n', cls="toon-error", note="S10.83 (fixed in 7c1d6e4): was Unterminated string; now the string [1]:")
    dec("toonerr_header_in_value_count", 'a: "x[2]: y"\n', cls="toon-error", note="S10.83 (fixed in 7c1d6e4): was Expected 2 inline array items, but got 1; now the string")
    dec("toonedge_header_in_value_list_item_field", 'f[1]:\n  - e: "x[1]: y"\n    g[1]: 1\n', cls="toon-edge", note="S10.83 (fixed in 7c1d6e4): the first field of a list-item object keeps its string value")
    # ---- S2.113: CRLF through every construct the clause names (the corpus pins key-value and inline only)
    dec("toonedge_crlf_all_constructs", 'o:\r\n  n: -0\r\n  "q k": "s"\r\nt[2]{a,b}:\r\n  1,x\r\n  2.50,"y"\r\nl[4]:\r\n  - 1e3\r\n  - k: v\r\n    m:\r\n      z: true\r\n  - [2]: p,q\r\n  - u[1]{w}:\r\n      7\r\ne[0]:\r\n', cls="toon-edge", note="S2.113: nested object, quoted key, table rows, list items of every shape and an empty array decode like the LF twin")
    dec("toonerr_crlf_blank_line_in_list", 'l[2]:\r\n  - a\r\n\r\n  - b\r\n', cls="toon-error", note="S2.105/S2.113: a line holding only CR is blank -> Line 3: Blank lines inside list array are not allowed in strict mode")
    # ---- S4.122/S4.146: long number texts are position-independent (rows and inline values under tab and pipe)
    enc("encnum_long_text_in_rows_tab", '{"t":[{"a":1e300,"b":5e-324},{"a":-1.7976931348623157e308,"b":1e-7}],"i":[1e21,1e-300,-0]}\n', ["--delimiter", "\t"], cls="enc-number", note="S4.130: 301- to 326-character number texts inside tab-delimited rows, never quoted")
    dec("decnum_long_tokens_in_rows_pipe", "t[2|]{a|b}:\n  1" + "0" * 300 + "|0." + "0" * 323 + "5\n  " + "9" * 309 + "|-0." + "0" * 400 + "1\ni[2|]: 1" + "0" * 308 + " | 1" + "0" * 309 + "\n", cls="dec-number", note="S4.142/S4.143: 300+ character tokens as cells; 309 nines and 1e309 stay strings, -1e-401 is 0.0")


_proposed_x()


def _found_phase3():
    """Spec gaps met while implementing (Phase 3), each resolved by RUNNING the oracle (OQ-P3-1, OQ-P3-2)."""
    # ---- OQ-P3-1 (S4.223): a list item's header parse surfaces its failures even when the item has no ':' outside quotes
    dec("toonerr_item_header_cap_quoted_colon", 'l[1]:\n  - a[999999999999]":"\n', cls="toon-error", note="S4.223: the cap message although the only ':' after the brackets sits inside quotes")
    dec("toonerr_item_header_inline_unterminated", 'l[1]:\n  - a[2]{x}":"\n', cls="toon-error", note="S4.223/S4.210: a keyed header with a fields segment; its inline text is a lone quote -> Unterminated string")
    dec("toonerr_item_header_key_escape", 'l[1]:\n  - "a\\q"[1]{x}":"\n', cls="toon-error", note="S4.223/S2.139 (3): the quoted header key's escape error surfaces")
    dec("toonerr_item_bracket_cap_quoted_colon", 'l[1]:\n  - [999999999999]":"\n', cls="toon-error", note="S4.222/S4.223: the root-array test fails (no unquoted ':'), the header parse of S4.223 still reports the cap")
    # ---- OQ-P3-2 (S2.126): a quoted key is unescaped BEFORE the ':' after its closing quote is required (found by the mutation fuzzer)
    dec("toonerr_quoted_key_escape_before_colon", '"a\\x"\n"a\\x"\n', cls="toon-error", note="S2.126: Invalid escape sequence: \\x, not Missing colon after key")
    dec("toonerr_quoted_key_escape_before_colon_item", 'l[1]:\n  - "a\\b"x: 1\n', cls="toon-error", note="S2.126: the same order inside a list item")


_found_phase3()


def _found_phase4():
    """Spec gaps met in the Phase 4 find-fix rounds, each resolved by RUNNING the oracle."""
    # ---- OQ-P4-1 (S1.86): a value attached to --help / --version while C is not empty (found by the argv fuzzer)
    case("usage_help_with_value_after_commit", ["-e", "--help=x"], None, "usage", "S1.86: C not empty -> the group line G preceded by --help (help is not a member of G)")
    case("usage_version_with_value_after_commit", ["--indent=2", "--version="], None, "usage", "S1.86: the same for --version, with an empty attached value")
    case("usage_version_with_value", ["--version=1"], None, "usage", "S1.86: C empty -> Usage: toon --version [INPUT]")


_found_phase4()


def _found_round7():
    """Round 7 (non-author review): keys that collide in the port's 16 hash bits and keys repeated more than
    once. "exr" and "jda" share the low 16 bits of their FNV-1a hashes (…8a4e), so they meet in one bucket
    of every hashed carrier of the port; the original's maps do not care. Expectations are the oracle's."""
    case("encstr_keys_hash_collision", ["--encode", "--key-folding", "safe"],
         '{"exr":"a","jda":"b","exr":"c","t":[{"exr":"p","jda":"q"},{"jda":"r","exr":"s"}]}',
         "enc-string", "S6.10, S6.31: a repeated key and a permuted tabular row, all keys in one hash bucket")
    case("encstr_fold_hash_collision", ["--encode", "--key-folding", "safe"],
         '{"exr":{"x":1},"jda":{"x":2},"exr.x":3,"jda.y":{"z":4}}',
         "enc-string", "S4.63: folding's sibling test on colliding keys: exr.x collides with a literal sibling, jda.x does not")
    case("encstr_duplicate_keys_thrice", ["--encode"], '{"a":1,"b":{"a":1,"a":2,"a":3},"a":2,"c":0,"a":3}',
         "enc-string", "S2.29: a key repeated twice over keeps its first position and takes its LAST value, at both depths")
    case("toonedge_expand_hash_collision_conflict", ["--decode", "--expand-paths", "safe"], "exr.k: 1\njda.k: 2\nexr.m: 3\njda.k.z: 4\n",
         "toon-edge", "S4.244: expansion over colliding keys; the conflict is on jda.k, not on its bucket neighbour")
    case("toonedge_expand_hash_collision_lenient", ["--decode", "--expand-paths", "safe", "--no-strict"], "exr.k: 1\njda.k: 2\nexr.m: 3\njda.k.z: 4\n",
         "toon-edge", "S4.246: the same document in lenient mode: the later value wins under jda.k only")
    case("toonedge_repeated_keys_hash_collision", ["--decode"], "exr: 1\njda: 2\nexr: 3\n",
         "toon-edge", "S3.25: writer A keeps every repeated key, colliding or not")
    case("toonerr_expand_repeated_hash_collision", ["--decode", "--expand-paths", "safe"], "exr: 1\njda: 2\nexr: 3\nt[2]{jda,exr}:\n  1,2\n  3,4\n",
         "toon-error", "S4.245: a repeated literal key is a merge conflict under expansion")


_found_round7()


def _found_round8():
    """Round 8 (non-author review), R8-7: a pending value option followed by a short cluster. The FIRST
    character of the cluster decides (S1.81 when it is a known short option, S1.77 when it is not); the
    spec had said "a short cluster of known characters". The port already agreed with the oracle."""
    case("usage_missing_value_before_mixed_cluster", ["-o", "-ex"], None, "usage", "S1.81: -e is known, so -o has no value; the unknown x behind it is never looked at")
    case("usage_missing_value_before_cluster_digit", ["-o", "-e5"], None, "usage", "S1.81: the same with a digit behind the known character")
    case("usage_missing_value_indent_before_mixed_cluster", ["--indent", "-ox"], None, "usage", "S1.81: a long value option, a cluster starting with the known -o")
    case("usage_unknown_first_in_cluster_after_value_option", ["-o", "-xe"], None, "usage", "S1.77: the first character is unknown: unexpected argument '-x', although -e follows")
    case("usage_unknown_digit_cluster_after_value_option", ["-o", "-5e"], None, "usage", "S1.77: a digit first: unexpected argument '-5' (not a negative number for --output)")


_found_round8()


def _read_bytes(path):
    """The bytes of a file; the handle is closed before returning."""
    with open(path, "rb") as fh:
        return fh.read()


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
            if not os.path.exists(p) or _read_bytes(p) != data:
                drift.append(rel)
        else:
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "wb") as fh:
                fh.write(data)
    if check:
        if not os.path.exists(out_tsv) or _read_bytes(out_tsv).decode("utf-8") != tsv:
            drift.append("cases/hand-cases.tsv")
        print(json.dumps({"cases": len(rows), "drift": drift, "verdict": "OK" if not drift else "DRIFT"}))
        return 1 if drift else 0
    with open(out_tsv, "w", encoding="utf-8") as fh:
        fh.write(tsv)
    print(json.dumps({"cases": len(rows), "inputs": len(files), "verdict": "WRITTEN"}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
