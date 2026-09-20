# Feature parity — the Bend 2 port of Toon

<!-- Generated from the spec's in-scope rows and kept current by hand after
     every gate run. `scripts/parity-board.sh docs/FEATURE_PARITY.md`
     computes the verdict: FULL, PARTIAL, DEBT (exclusions exist) or
     MALFORMED (a "present" row with neither a golden nor a law). Rules:
     partial never rounds up; excluded is debt; a present feature names
     its evidence. Statuses: present | partial | missing | excluded | n/a. -->

Last gate run: 2026-09-20 · lanes: `scripts/lanes.sh` → FAIL (interpreter, c-1t, c-8t, js: the scaffold stub, before Phase 3) ·
proofs: `bun /tmp/bend/bend2/main.ts port/PROOF.bend` → `All terms check.` with 0 unsafe (0 `@unsafe` + 0 template instances, bend 2.0.16) · board: PARTIAL.

| feature | original ref | port def | goldens | laws | status | notes |
|---|---|---|---|---|---|---|
| JSON text input: grammar, whitespace, escapes, surrogate pairs, duplicate keys | S2.1–S2.35, S2.50–S2.55 `serde_json-1.0.151/src/de.rs:1393` | `json.read` | encstr_whitespace_json, encstr_escapes_in, encstr_duplicate_keys, encstr_ws_everywhere | none | missing | golden-tested only |
| JSON input errors: every message with its byte line and column; recursion limit 128 | S2.40–S2.47, S9.50–S9.83 `serde_json-1.0.151/src/read.rs:421` | `json.read` | jsonerr_empty, jsonerr_trailing_comma_arr, jsonerr_deep_129, jsonerr_unicode_in_error_col, jsonerr_lone_high_surrogate | none | missing | one case per message and per position rule |
| strict UTF-8 on input, stdin and file | S2.100, S9 part A `src/cli/mod.rs:128` | `text.utf8_decode`, `sh.read_all` | jsonerr_invalid_utf8_stdin, jsonerr_invalid_utf8_file, jsonerr_overlong_utf8, jsonerr_truncated_utf8, toonerr_invalid_utf8_stdin | none | missing |  |
| JSON number reading (the default, non-round-trip float path) | S4.100–S4.122 `serde_json-1.0.151/src/de.rs:639` | `f64.serde_read` | encnum_long_mantissa, encnum_u64_boundary, encnum_frac_long, encnum_pow10_slow_path, encnum_pow10_each, encnum_extremes | none | missing | closed laws planned: pow10_22, pow10_23, serde_fit_boundary |
| TOON number text (Rust Display: shortest digits, ties up, no exponent) | S4.130–S4.134, S5.30–S5.35 `src/encode/primitives.rs:85` | `f64.shortest`, `f64.show_toon` | encnum_ints, encnum_big_ints, encnum_decimals, encnum_exponents, encnum_tie_up_1, encnum_display_ties | none | missing |  |
| encoder primitives and the quoting decision for values and keys | S4.3–S4.23 `src/shared/validation.rs:47` | `enc.value_text`, `enc.key_text` | encstr_quoting, encstr_quoting_pipe, encstr_quoting_tab, encstr_unicode, encstr_ws_edge_sweep, encstr_keys, fx_enc_primitives_01 | none | missing | law planned: unescape_escape |
| array headers, joins and the five-step array strategy (inline, list of arrays, tabular, list) | S4.24–S4.39 `src/encode/encoders.rs:182` | `enc.header`, `enc.classify` | fx_enc_arrays_primitive_01, fx_enc_arrays_tabular_01, fx_enc_arrays_nested_01, fx_enc_arrays_objects_01, enc_shapes_mixed | none | missing |  |
| list items in every shape; objects, root forms, indentation 0–16 | S4.40–S4.62, S5.1–S5.12 `src/encode/encoders.rs:356` | `enc.emit` | enc_list_first_field_shapes, flag_indent_0_encode, flag_indent_16_encode, enc_deep_100, fx_enc_objects_01 | none | missing |  |
| delimiters comma, tab, pipe on encode | S3.10, S4.25–S4.28 `src/encode/primitives.rs:49` | `enc.header`, `enc.join` | fx_enc_delimiters_01, flag_delimiter_word_tab, encstr_root_delim_pipe, enc_tabular_quoting_pipe | none | missing |  |
| safe key folding with flatten depth, sibling and root-literal collisions | S4.63–S4.84 `src/encode/folding.rs:19` | `enc.fold` | fx_enc_key_folding_01, enc_folding_mix, enc_folding_collision, enc_fold_list_item_dup_key, enc_fold_budget_threading_4 | none | missing | bug-compatible with S10.61–S10.66 |
| TOON scanning: lines, indent, depth, blank lines, strict checks | S2.100–S2.114 `src/decode/scanner.rs:42` | `dec.scan` | toonerr_tab_indent, toonerr_indent_three, toonlenient_indent_three, toonedge_indent0_indented, toonerr_crlf, toonerr_bom | none | missing |  |
| tokens, string literals, delimited values, keys, array headers | S2.120–S2.140 `src/decode/parser.rs:34` | `dec.header`, `dec.split`, `dec.key`, `dec.string` | toonerr_bad_escape, toonerr_after_closing_quote, toonerr_header_spaces, toonerr_missing_close_bracket, toonedge_length_forms | none | missing |  |
| TOON number tokens (correctly rounded) and token classification | S4.140–S4.147 `src/decode/parser.rs:243` | `num.token`, `f64.from_dec` | decnum_ints, decnum_long_mantissa, decnum_not_numbers, decnum_extremes, decnum_exact_halfway, decnum_finite_edge | none | missing |  |
| structural decoding: root forms, key-value lines, nested objects, inline, tabular and list arrays, list items | S4.200–S4.227 `src/decode/decoders.rs:30` | `dec.run` | fx_dec_objects_01, fx_dec_arrays_tabular_01, fx_dec_arrays_nested_01, fx_dec_root_form_01, toonerr_list_obj_fields, toonerr_nested_headers | none | missing |  |
| strict validation and --no-strict: counts, blank lines, extra rows and items, the length cap | S4.211–S4.217, S9.100–S9.119, S9.140–S9.147 `src/decode/validation.rs:12` | `dec.run` | toonerr_blank_in_list, toonerr_extra_tabular_rows, toonerr_too_few_inline, toonlenient_extra_list_items, toonerr_length_over_cap, toonerr_scan_error_beats_parse_error | none | missing |  |
| safe path expansion: quoted-key suppression, deep merge, conflicts, depth cap 256 | S4.240–S4.249 `src/decode/expand.rs:26` | `dec.build`, `dec.expand` | jsonout_expand_merge, jsonout_expand_conflict_strict, jsonout_expand_conflict_lenient, jsonout_expand_deep_limit, toonedge_expand_segments_253, fx_dec_path_expansion_01 | none | missing |  |
| JSON number text (zmij: shortest digits, ties to even, e±X outside 1e-5…1e16) | S4.170–S4.175, S5.36–S5.45 `zmij-1.0.23/src/lib.rs:1369` | `f64.show_json` | decfmt_exp_upper_boundary, decfmt_exp_lower_boundary, decfmt_exp_shapes, decfmt_tie_even_1, decnum_ints | none | missing |  |
| JSON writer A (streaming, plain --decode): layouts at every indent, escaping, duplicate keys kept | S5.50–S5.78 `src/cli/json_stream.rs:22` | `json.write_a` | jsonout_indent_2, jsonout_compact_shapes, jsonout_indent_1_ok, jsonout_indent_4_ok, decstr_control_out, jsonout_duplicate_keys | none | missing |  |
| JSON writer B (with --expand-paths safe): layouts, its own escape table | S5.50–S5.78 `src/cli/json_stringify.rs:8` | `json.write_b` | jsonout_expand_indent_2, jsonout_compact_shapes_expand, jsonout_expand_indent_4_ok, decstr_control_out_expand | none | missing | bug-compatible: differs from writer A on 35 characters (C-3) |
| argv: option spellings, value domains, ignored options | S1.1–S1.35, S1.150–S1.155 `src/cli/args.rs:16` | `cli.parse` | flag_indent_equals, flag_delimiter_backslash_t, flag_output_attached, flag_double_dash_file, flag_no_strict_on_encode_ignored | none | missing |  |
| help and version text | S1.60–S1.63 `src/cli/args.rs:4` | `cli.help`, `cli.version` | usage_help, usage_help_short, usage_version, usage_version_short | none | missing | behind `--` on the compiled binary: DISC-001 |
| clap error shapes, context-built usage lines, similarity tips, which error wins | S1.70–S1.87, S1.130–S1.135 `clap_builder-4.6.6/src/error/format.rs:1` | `cli.parse`, `cli.similar`, `cli.usage_line` | usage_bad_delimiter, usage_bad_indent_17, usage_conflict_encode_decode, usage_unknown_flag, usage_similar_arg, usage_enum_similar_tie, usage_help_first_wins, usage_conflict_usage_many | none | missing | program name is the literal `toon`: DISC-002 |
| mode detection by flags and extension; stdin, `-`, files | S4.300–S4.304 `src/cli/args.rs:88` | `cli.mode` | auto_json_ext, auto_toon_ext, auto_upper_json_ext, auto_dotfile_json, auto_stdin_defaults_encode, flag_stdin_dash | none | missing |  |
| output framing: stdout vs -o FILE, final newline, success lines, the 8192-byte silent write failure | S5.100–S5.113, S9.1–S9.22 `src/cli/mod.rs:140` | `Cli.run`, `sh.exec_plan` | flag_output_dev_stdout_encode, flag_output_file_label, flag_output_dev_stderr, io_output_dev_full_8192, io_output_dev_full_8193 | none | missing | bug-compatible with S10.3 (OQ-A6) |
| --stats: token estimates, percent through two binary64 operations, line order | S4.310–S4.319 `src/cli/mod.rs:54` | `cli.stats` | stats_small, stats_users, stats_no_savings, stats_with_output, stats_tie_to_even_down, stats_f64_below_tie, stats_percent_100 | none | missing | closed laws planned: stats_pct_6_25, stats_pct_18_75 |
| I/O errors: missing file, directory, uncreatable output, OS error text | S8.1–S8.17, S9.1–S9.22 `src/error.rs:24` | `sh.fail_read`, `sh.fail_create`, `sh.fail_write` | usage_missing_file, usage_dir_as_input, usage_output_bad_dir, io_output_is_dir, io_json_error_beats_bad_output | none | missing | OQ-A4 open for errno 20, 28, 32 |
| large inputs and determinism | S11.1–S11.3 `src/encode/encoders.rs:282` | `Cli.run` | large_tabular_1500, large_tabular_1500_pipe_folded, determinism_a, determinism_a_again | none | missing | every input-length traversal tail-recursive |
| async streaming encode/decode (`async-stream`) | PLAN §3 `src/encode/async_encode.rs:1` | - | - | - | excluded | PLAN §3: out-of-scope (off in the pinned build) |
| WebAssembly bindings (`wasm`) | PLAN §3 `src/wasm.rs:1` | - | - | - | excluded | PLAN §3: out-of-scope |
| `EncodeReplacer` callback | PLAN §3 `src/encode/replacer.rs:5` | - | - | - | excluded | PLAN §3: out-of-scope, debt (no CLI spelling; needs a Rust driver for stage goldens) |
| library-only behavior no CLI path reaches (OQ-B3) | S2.55, S5.75, S9.77–S9.83 `src/cli/json_stream.rs:57` | - | - | - | excluded | PLAN §3: out-of-scope, debt |
| shell completions, tracing, build metadata | PLAN §3 `Cargo.toml:30` | - | - | - | excluded | PLAN §3: out-of-scope (unreached by the pinned CLI) |
| native Windows behavior | PLAN §3 | - | - | - | excluded | PLAN §3: platform |

(Every in-scope row starts `missing` and flips to `present` only when the goldens it names pass on every lane and the laws it names are proved; `partial` never rounds up; `excluded` is debt.)

## Proof coverage

| kind | count | list |
|---|---|---|
| fast == spec laws | `<n>` | |
| round-trip / conservation laws | `<n>` | |
| closed goldens as laws | `<n>` | |
| `@unsafe` defs | `<n>` | each with its comment and bead |

## Lanes

| lane | cases | verdict | date |
|---|---|---|---|
| interpreter | `<n>/<n>` | PASS | |
| c-1t | | | |
| c-<N>t | | | |
| js | | | |
| gpu (`--gpu on`) | | PASS · MISSING (no device: stated) | |
