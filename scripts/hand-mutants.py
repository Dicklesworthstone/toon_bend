#!/usr/bin/env python3
"""hand-mutants: the law admission test with HAND-WRITTEN semantic mutants (the textual operators of
scripts/law-mutation.sh find no valid site in this code style: its three runs here were INCONCLUSIVE).

Each mutant is one exact-text replacement in one module. It is applied in a fresh temp copy of port/
(the port itself is never edited), the proof runs there, and the mutant is
  KILLED    the checker refuses a law (the law's name is reported)
  SURVIVED  `All terms check.`: no law pins what the mutant breaks -> state a law, or say why none can
  INVALID   the mutant does not check on its own (not evidence)      NOSITE  the text is gone: update the mutant
By default the proof is REDUCED to every non-golden law plus the golden laws that reach numbers, tabular
rows, folding, expansion and repeated keys (about a third of the laws, about 3 minutes per mutant);
--all-laws runs the whole proof per mutant.
usage: python3 scripts/hand-mutants.py [--all-laws] [M01 M05 ...]
exit: 0 every mutant KILLED, 1 otherwise. Last stdout line: JSON summary. Temp copies are kept (path printed).

The ids run from M01 with one gap: `M13` is a numbering slip that was never
defined (`git log -S M13 -- scripts/hand-mutants.py` is empty), NOT a mutant that was removed for being
INVALID. Count the set with `len(MUTANTS)`, never by reading the highest id.
"""
import hashlib, json, os, re, shutil, subprocess, sys, tempfile, time
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BEND = os.environ.get("BEND_CLI", "bun /tmp/bend/bend2/main.ts").split()
ENV = dict(os.environ, BEND_NO_TELEMETRY="1")
KEEP = re.compile(r"golden_(encnum|decnum|fx_dec_numbers|happy|fx_enc_arrays_(tabular|objects)|fx_dec_arrays_tabular|fx_dec_path_expansion|toonedge_expand|jsonout_duplicate|fx_enc_key_folding|enc_fold|toonerr_expand|encstr_duplicate|collision|repeated_keys)")
MUTANTS = [
 ("M01", "bignat.bend", "div_pow5(p, p5.step(st, 15625))", "div_pow5(p, p5.step(st, 3125))", "5^6 divisor replaced by 5^5"),
 ("M02", "bignat.bend", "P5{strip(q), Bool.or(sticky, Bool.not(U32.is_eq(r, 0)))}", "P5{strip(q), sticky}", "single-limb remainders never reach the sticky flag"),
 ("M03", "bignat.bend", "  (q, sticky) = p\n  P5{q, sticky}", "  (q, sticky) = p\n  P5{q, False{}}", "shifted-out bits never reach the sticky flag"),
 ("M04", "bignat.bend", "+cur = ((r << 16n) .|. x : U32)", "+cur = ((r << 15n) .|. x : U32)", "limb radix 2^15 in the short division"),
 ("M05", "f64.bend", "    case True{}:\n      False{}\n    case False{}:\n      ok", "    case True{}:\n      ok\n    case False{}:\n      ok", "the kill-switch no longer closes the twins"),
 ("M06", "f64.bend", "Nat.is_le(T.str_len(ints, 0n), 14n)", "Nat.is_le(T.str_len(ints, 0n), 15n)", "15-digit texts take the Nat path"),
 ("M07", "f64.bend", "Nat.is_le(BN.bitlen(q, 0n), 48n)", "Nat.is_le(BN.bitlen(q, 0n), 53n)", "integers up to 2^53 take the Nat printing path"),
 ("M08", "f64.bend", "IntFit{Bool.and(Bool.not(sticky), Nat.is_le(BN.bitlen(q, 0n), 48n)), q}", "IntFit{Nat.is_le(BN.bitlen(q, 0n), 48n), q}", "non-integers are printed as their floor"),
 ("M09", "f64.bend", "    case Con{d, rest}:\n      U32.is_eq(d, 0)", "    case Con{d, rest}:\n      False{}", "zero_head never sees a leading zero"),
 ("M10", "text.bend", "((h .^. c) * 16777619 : U32)", "((h .^. c) * 16777617 : U32)", "a different FNV prime"),
 ("M11", "text.bend", "    case KSNode{lv, l, x, r} OEq{}:\n      True{}", "    case KSNode{lv, l, x, r} OEq{}:\n      False{}", "bucket membership never hits"),
 ("M12", "text.bend", "    case KSNil{} _:\n      False{}", "    case KSNil{} _:\n      True{}", "bucket membership always hits"),
 ("M14", "json.bend", "      FObj{rev, SNil{}, idx, km.put(over, key, v)}", "      FObj{JECons{key, False{}, v, rev}, SNil{}, idx, over}", "a repeated JSON key is appended, not replaced"),
 ("M18", "json.bend", "    case KBNode{lv, l, x, xv, r} T.OEq{}:\n      KBNode{lv, l, x, v, r}", "    case KBNode{lv, l, x, xv, r} T.OEq{}:\n      KBNode{lv, l, x, xv, r}", "the map of last values keeps the FIRST repeat"),
 ("M19", "json.bend", "JECons{k, q, obj.over(km.get(over, k), v), acc}", "JECons{k, q, v, acc}", "the last values are never applied when an object closes"),
 ("M20", "decode.bend", "    case XBNode{lv, l, x, xv, r} T.OEq{}:\n      XBNode{lv, l, x, v, r}", "    case XBNode{lv, l, x, xv, r} T.OEq{}:\n      XBNode{lv, l, x, xv, r}", "setting an existing expanded key keeps the old value"),
 ("M21", "text.bend", "    case True{}:\n      KSNode{1n+rlv, KSNode{lv, a, x, b}, rk, rr}", "    case True{}:\n      KSNode{lv, a, x, KSNode{rlv, b, rk, rr}}", "split never lifts: a bucket degenerates into a chain"),
 ("M22", "text.bend", "    case True{}:\n      KSNode{llv, a, lk, KSNode{lv, b, x, r}}", "    case True{}:\n      KSNode{lv, KSNode{llv, a, lk, b}, x, r}", "skew never rotates"),
 ("M23", "text.bend", "    case SNil{} SCon{y, t} OEq{}:\n      OLt{}", "    case SNil{} SCon{y, t} OEq{}:\n      OEq{}", "a proper prefix compares equal"),
 ("M15", "decode.bend", "    case XObj{keys, map} True{}:\n      XObj{k <> keys, xm.set(map, k, v)}", "    case XObj{keys, map} True{}:\n      XObj{keys, xm.set(map, k, v)}", "a fresh expanded key is never listed"),
 ("M16", "decode.bend", "    case XObj{keys, map} False{}:\n      XObj{keys, xm.set(map, k, v)}", "    case XObj{keys, map} False{}:\n      XObj{k <> keys, xm.set(map, k, v)}", "a merged key is listed twice"),
 ("M17", "encode.bend", "row.lock(rest, t, T.str_eq(k, key), Bool.and(prim, is_prim(v)))", "row.lock(rest, t, True{}, Bool.and(prim, is_prim(v)))", "rows in another key order count as lockstep"),
 # Round 13 (R13-9) wrote these three itself and all three SURVIVED the whole 368-law proof: no law pinned
 # writer B's escape table, the surrogate test or the TAB quoting rule. The laws exist now
 # (writer_b_keeps_del_raw, writer_b_keeps_c1_raw, utf8_rejects_surrogate, tab_in_value_forces_quotes), and the
 # mutants live here so that stays true.
 # M24 was "writer B stops escaping DEL and the C1 block"; since the re-pin to toon_rust 694d73b there is one
 # table, which keeps both raw, so the mutant now brings the old table B's DEL escape back.
 ("M24", "json.bend", "      w.ch.plain(U32.is_lt(c, 32), c, acc)", "      w.ch.plain(Bool.or(U32.is_lt(c, 32), U32.is_eq(c, 127)), c, acc)", "the JSON writer escapes DEL again (the old table B, C-3)"),
 ("M25", "text.bend", "Bool.or(U32.is_lt(value, 55296), U32.is_gt(value, 57343))", "True{}", "a UTF-8-encoded surrogate is accepted"),
 ("M26", "encode.bend", "Bool.or(U32.is_eq(c, 13), U32.is_eq(c, 9))", "U32.is_eq(c, 13)", "a TAB in a value no longer forces quotes"),
 # Round 14's five (R14-1): each SURVIVED the whole 374-law proof while breaking captured cases, until
 # the laws of 2026-09-22 pinned them. M31 mutates the same expression as M26 but the OTHER arm (CR, not TAB).
 ("M27", "cli.bend", "Bool.and(U32.is_ge(c, 65), U32.is_le(c, 90))", "Bool.and(U32.is_ge(c, 65), U32.is_le(c, 83))", "the extension lowercaser stops folding T..Z, so `.TOON` is not decoded"),
 ("M28", "cli.bend", "def seven_tenths() -> F.F64:\n  F.from_dec(True{}, False{}, [7], 1n)", "def seven_tenths() -> F.F64:\n  F.from_dec(True{}, False{}, [8], 1n)", "clap's similarity threshold moves from 0.7 to 0.8"),
 ("M29", "text.bend", "U32.is_eq(c, 5760)", "U32.is_eq(c, 5761)", "U+1680 stops being White_Space and U+1681 starts"),
 # M30 moved the old zmij boundary (1e16 to 1e15); M34 now covers the upper JavaScript boundary, so M30
 # moves the LOWER one (0.000001 would print as 1e-6).
 ("M30", "f64.bend", "    case Neg{z}:\n      Nat.is_le(z, 5n)", "    case Neg{z}:\n      Nat.is_le(z, 4n)", "the JSON writer's plain range stops at 1e-5 instead of 1e-6"),
 ("M31", "encode.bend", "Bool.or(U32.is_eq(c, 13), U32.is_eq(c, 9))", "Bool.or(U32.is_eq(c, 9), U32.is_eq(c, 9))", "a CR in a value no longer forces quotes"),
 # An author-side hunt before round 15 (2026-09-22): round 14's survivors were each one entry of a small
 # table, so other entries of the same tables were tried. Two White_Space entries SURVIVED the full
 # 381-law proof; the `:` and LF arms of `bad_char` were already killed by golden laws.
 ("M32", "text.bend", "U32.is_eq(c, 12288)", "U32.is_eq(c, 12289)", "U+3000 IDEOGRAPHIC SPACE stops being White_Space"),
 ("M33", "text.bend", "U32.is_eq(c, 160)", "U32.is_eq(c, 161)", "U+00A0 NO-BREAK SPACE stops being White_Space"),
 # Round 15 (R15-10): two laws this file's own notes called "proved but not SHOWN to bite" each turned out
 # to be the ONLY law that kills one of the reviewer's mutants. These make that bite permanent.
 ("M34", "f64.bend", "    case Pos{p}:\n      Nat.is_le(p, 21n)", "    case Pos{p}:\n      Nat.is_le(p, 22n)", "the JSON writer stays plain at k = 22 (json_exponent_at_k22 catches it)"),
 ("M35", "text.bend", "Bool.or(Bool.and(U32.is_ge(c, 9), U32.is_le(c, 13)), Bool.or(U32.is_eq(c, 32)", "Bool.or(Bool.and(U32.is_ge(c, 9), U32.is_le(c, 14)), Bool.or(U32.is_eq(c, 32)", "White_Space gains U+000E (only is_ws_documented_non_members catches it)"),
 # S4.130/S5.30 (round 16 named the EXP-007 decode half as unmutated): the pass's printer dispatch,
 # swapped. JSON output would carry Rust `Display` number text and TOON output JavaScript's. No law
 # mentioned num.text until num_text_json_is_show_json / num_text_toon_is_show_toon were written;
 # law-mutation.sh cannot express this one (its only operator here, swapargs, is type-invalid).
 ("M36", "encode.bend",
  "    case True{}:\n      F.show_json_fast(f, spec)\n    case False{}:\n      F.show_toon_fast(f, spec)",
  "    case True{}:\n      F.show_toon_fast(f, spec)\n    case False{}:\n      F.show_json_fast(f, spec)",
  "the number pre-pass renders TOON text into JSON output and JSON text into TOON output"),
 # S5.101 the other half of the same question: dec.done is what TELLS the pass it is on the JSON side.
 # num_text_*_is_show_* pin the dispatch GIVEN the flag; this mutant lies about the flag instead.
 ("M37", "cli.bend",
  "dec.ok(stats, J.write_ln(E.pre.if(spec, True{}, v), indent, spec), text)",
  "dec.ok(stats, J.write_ln(E.pre.if(spec, False{}, v), indent, spec), text)",
  "--decode renders its numbers with the TOON printer instead of the JSON one"),
 # round 20 (R20-1, R20-3): sites no mutant of this inventory reached; each is killed by the law written for it
 ("M38", "json.bend",
  "def obj.member.small(short: Bool, key: String, v: Json, rev: Json, over: KM) -> Frame:\n  match short:\n    case True{}:\n      FObj{JECons{key, False{}, v, rev}, SNil{}, T.kt.empty(), over}\n    case False{}:\n      obj.member.grown(JECons{key, False{}, v, rev}, over)",
  "def obj.member.small(short: Bool, key: String, v: Json, +rev: Json, over: KM) -> Frame:\n  match short:\n    case True{}:\n      FObj{JECons{key, False{}, v, rev}, SNil{}, T.kt.empty(), over}\n    case False{}:\n      FObj{JECons{key, False{}, v, rev}, SNil{}, kt.of_chain(rev, T.kt.empty()), over}",
  "the key set built when the 9th member joins leaves that member out, so a later repeat of it is a second key (R20-1)"),
 ("M39", "encode.bend", "Bool.or(U32.is_eq(c, 125),", "Bool.or(False{},", "`}` no longer forces quotes (R20-3, N8)"),
 ("M40", "encode.bend", "Bool.or(U32.is_eq(c, 91),", "Bool.or(False{},", "`[` no longer forces quotes (R20-3, N9)"),
 ("M41", "encode.bend", "Bool.or(U32.is_eq(c, 123),", "Bool.or(False{},", "`{` no longer forces quotes (R20-3, N10)"),
 ("M42", "encode.bend", "Bool.or(T.has_edge_ws(s),", "Bool.or(False{},", "whitespace at an edge no longer forces quotes (R20-3, N12)"),
 ("M43", "f64.bend", "    case 7n 0n:\n      7n\n", "    case 7n 0n:\n      8n\n", "an exponent digit 0 leaves the numeric-like lexer (R20-3, P5)"),
 ("M44", "f64.bend", "    case 1n 1n:\n      2n\n", "    case 1n 1n:\n      8n\n", "a digit after a leading 0 leaves the numeric-like lexer (R20-3, P8)"),
 # round 21 (R21-1, R21-4): sites no mutant of this inventory reached; each is killed by the law written for it
 ("M45", "encode.bend", "      prim\n", "      True{}\n",
  "has_prim.go says a key holds a primitive when it holds an object or array, so a reordered row with one goes tabular (R21-1)"),
 ("M46", "encode.bend", "Bool.or(U32.is_eq(c, 34),", "Bool.or(False{},", "`\"` no longer forces quotes (R21-4, Q1)"),
 ("M47", "encode.bend", "Bool.or(U32.is_eq(c, 92),", "Bool.or(False{},", "`\\` no longer forces quotes (R21-4, Q2)"),
 ("M48", "encode.bend", "Bool.or(U32.is_eq(c, 93),", "Bool.or(False{},", "`]` no longer forces quotes (R21-4, Q3)"),
 ("M49", "f64.bend", "    case 6n 0n:\n      7n\n", "    case 6n 0n:\n      8n\n", "an exponent after its sign leaves the numeric-like lexer (R21-4, L60)"),
 ("M50", "f64.bend", "    case 1n 3n:\n      5n\n", "    case 1n 3n:\n      8n\n", "an exponent after a leading 0 leaves the numeric-like lexer (R21-4, L13)"),
 ("M51", "encode.bend", "vk.tab.if(Bool.and(Bool.not(Nat.is_eq(hn, 0n)),", "vk.tab.if(Bool.and(True{},",
  "an array of empty objects is written as a table with an empty header (R21-4, R6)"),
 ("M52", "encode.bend", "      has_prim.go(t, k, T.str_eq(key, k), is_prim(v))\n    case _ False{}:\n      False{}\n",
  "      has_prim.go(t, k, T.str_eq(key, k), is_prim(v))\n    case _ False{}:\n      True{}\n",
  "has_prim.go treats a header key missing from a row as present (R21-4, R16)"),
 ("M53", "json.bend", "Bool.pick(Nat, U32.is_eq(b, 47), 3n,", "Bool.pick(Nat, U32.is_eq(b, 47), 0n,", "the JSON reader rejects the escape `\\/` (R21-4, R12)"),
 ("M54", "encode.bend", 'T.str_eq(s, "null"))', "False{})", "the string null is no longer a word that needs quotes (R21-4, Q7)"),
 ("M55", "json.bend", "      St{MStr{SCon{Chr{8}, rev}, key, 0n, 0}", "      St{MStr{SCon{Chr{12}, rev}, key, 0n, 0}",
  "the JSON escape `\\b` reads as FF (R22-4, V7)"),
 ("M56", "json.bend", "U32.is_eq(b, 102), 5n,", "U32.is_eq(b, 102), 0n,", "the JSON reader rejects the escape `\\f` (R22-4, V8)"),
 ("M57", "text.bend", "U32.is_le(c, 90)), U32.is_eq(c, 95)))", "U32.is_le(c, 90)), False{}))", "`_` can no longer start a bare key (R22-4, V10)"),
 ("M58", "encode.bend", "    case Con{k, rest} other True{}:\n      0n\n", "    case Con{k, rest} other True{}:\n      Bool.pick(Nat, prim, 1n, 2n)\n",
  "a row shorter than the header, in header order, passes the lockstep test (R22-4, V14)"),
 ("M59", "encode.bend", "    case False{} False{} True{} True{}:\n", "    case False{} False{} True{} _:\n",
  "an array of objects that is a list item may be tabular (R22-4, V25)"),
 # round 23: the reviewer's own mutant texts (r23/mut23.py), taken verbatim. H1 and H2 (the length cap 100000000) are
 # NOT here: no closed law can pin that boundary without the checker building 10^8 in unary, so they would read as
 # SURVIVED against the laws; `toonerr_length_at_cap` pins them on every lane (PORT_STATE, round 23).
 ('M60', 'text.bend', 'def key_char(+c: U32, dot: Bool) -> Bool:\n  Bool.or(Bool.and(U32.is_ge(c, 97), U32.is_le(c, 122)), Bool.or(Bool.and(U32.is_ge(c, 65), U32.is_le(c, 90))', 'def key_char(+c: U32, dot: Bool) -> Bool:\n  Bool.or(Bool.and(U32.is_ge(c, 97), U32.is_le(c, 122)), Bool.or(Bool.and(U32.is_ge(c, 65), U32.is_le(c, 89))',
  "key_char: 'Z' is not a later key character (R23-4, K3)"),
 ('M61', 'decode.bend', '    case SNil{}:\n      FRErr{"Empty field name in field list"}', '    case SNil{}:\n      FROk{Field{SNil{}, False{}} <> rev}',
  'field.one: an empty field name is a name (R23-4, H5)'),
 ('M62', 'decode.bend', 'hdr.c.pick(Bool.pick(Nat, U32.is_eq(c, 123), 1n, Bool.pick(Nat, U32.is_eq(c, 58), 2n, 0n))', 'hdr.c.pick(Bool.pick(Nat, U32.is_eq(c, 123), 1n, Bool.pick(Nat, Bool.or(U32.is_eq(c, 58), U32.is_eq(c, 61)), 2n, 0n))',
  "hdr.c.seg: '=' after ']' acts as the header colon (R23-4, H9)"),
 ('M63', 'decode.bend', '    case False{} True{} 3n:\n      UE{False{}, SCon{Chr{13}, rev}', '    case False{} True{} 3n:\n      UE{False{}, SCon{Chr{10}, rev}',
  'unesc.tr: \\r reads as LF in keys (R23-4, U3)'),
 ('M64', 'json.bend', 'U32.is_le(b, 70)), (b - 55 : U32)', 'U32.is_le(b, 70)), (b - 54 : U32)',
  'hex.val: upper-case A-F off by one (R23-5, A4)'),
 ('M65', 'json.bend', 'U32.is_le(b, 102)), (b - 87 : U32)', 'U32.is_le(b, 101)), (b - 87 : U32)',
  "hex.val: lower-case 'f' is not a hex digit (R23-5, A5)"),
 ('M66', 'json.bend', '(v - 56320) : U32)', '(v - 56319) : U32)',
  'hex.fin: surrogate pair decoded one too high (R23-5, A6)'),
 ('M67', 'json.bend', 'U32.is_le(v, 56319)), v, hi', 'U32.is_le(v, 56318)), v, hi',
  'hex.go: U+DBFF is not a high surrogate (R23-5, A7)'),
 ('M68', 'encode.bend', '  ctx.vk(vkind(v, True{}), True{}, k, d, True{}, 2n+d, fctx.item(opt))', '  ctx.vk(vkind(v, False{}), True{}, k, d, True{}, 2n+d, fctx.item(opt))',
  "a list item object's first field is never tabular (R23-5, T4)"),
 ('M69', 'decode.bend', '    case UQ{True{}, cpos, False{}, dpos}:\n      False{}', '    case UQ{True{}, cpos, False{}, dpos}:\n      True{}',
  'is_row.of: a colon and no delimiter is a row (R23-5, I1)'),
 ('M70', 'decode.bend', 'hdr.h(Bool.and(has_seg, Bool.not(String.is_empty(inline)))', 'hdr.h(False{}',
  'hdr.g: values after a fields header colon are accepted (R23-5, H4)'),
 ('M71', 'decode.bend', '    case UC{False{}, rev, after, True{}}:\n      HErr{"Unterminated string: missing closing quote"}', '    case UC{False{}, rev, after, True{}}:\n      HNot{}',
  'hdr.c.fields: an open quote in the fields segment is not an error (R23-5, H6)'),
 ('M72', 'decode.bend', '    case False{} True{} _:\n      UE{False{}, rev, True{}, c}', '    case False{} True{} _:\n      UE{False{}, SCon{Chr{c}, rev}, False{}, badc}',
  'unesc.tr: an unknown escape in a key is kept, not refused (R23-5, U4)'),
 ('M73', 'json.bend', '(d + 48 : U32), (d + 87 : U32))}', '(d + 48 : U32), (d + 55 : U32))}',
  'hexc: upper-case hex digits in \\u00XX (R23-5, J2)'),
 # round 24: the reviewer's own mutant texts (r24/mut24.py), taken verbatim
 ('M74', 'decode.bend', 'hdr.c.colon.if(U32.is_eq(c, 58),', 'hdr.c.colon.if(Bool.or(U32.is_eq(c, 58), U32.is_eq(c, 59)),',
  "hdr.c.colon: ';' after the fields segment is the header colon (R24-3, H10)"),
 ('M75', 'decode.bend', 'hdr.c.colon(ascii_ws.go(after, ascii_ws.cls(after)), quoted', 'hdr.c.colon(after, quoted',
  "hdr.c.fields: no whitespace allowed between '}' and ':' (R24-3, H11)"),
 ('M76', 'decode.bend', 'FROk{Field{s, True{}} <> rev}', 'FROk{Field{s, False{}} <> rev}',
  'field.put: a quoted field name loses its quoted flag (R24-3, H13)'),
 ('M77', 'decode.bend', '    case False{} True{} 2n:\n      UE{False{}, SCon{Chr{9}, rev}', '    case False{} True{} 2n:\n      UE{False{}, SCon{Chr{32}, rev}',
  'unesc.tr: \\t in a quoted key reads as a space (R24-4, U5)'),
 ('M78', 'decode.bend', '    case False{} True{} 5n:\n      UE{False{}, SCon{Chr{34}, rev}', '    case False{} True{} 5n:\n      UE{False{}, SCon{Chr{39}, rev}',
  'unesc.tr: \\" in a quoted key reads as \' (R24-4, U6)'),
 ('M79', 'decode.bend', '    case False{} True{} 4n:\n      UE{False{}, SCon{Chr{92}, rev}', '    case False{} True{} 4n:\n      UE{False{}, SCon{Chr{47}, rev}',
  'unesc.tr: \\\\ in a quoted key reads as / (R24-4, U7)'),
 ('M80', 'decode.bend', '    case False{} True{} 1n:\n      UE{False{}, SCon{Chr{10}, rev}', '    case False{} True{} 1n:\n      UE{False{}, SCon{Chr{13}, rev}',
  'unesc.tr: \\n in a quoted key reads as CR (R24-4, U8)'),
 ('M81', 'decode.bend', 'FROk{Field{SCon{Chr{c}, rest}, False{}} <> rev}', 'FROk{Field{SCon{Chr{c}, rest}, True{}} <> rev}',
  'field.first: a bare field name is flagged quoted (R24-4, H14)'),
 ('M82', 'encode.bend', '    case Opts{indent, delim, +fo, budget, spec}:\n      FCtx{fo, budget, False{}, T.kt.empty(), False{}, SNil{}, fctx.lean(fo, spec)}\n\n# S4.70', '    case Opts{indent, delim, +fo, budget, spec}:\n      FCtx{fo, Nat.sub(budget, 1n), False{}, T.kt.empty(), False{}, SNil{}, fctx.lean(fo, spec)}\n\n# S4.70',
  "fctx.item: a list item's body gets budget - 1 (R24-4, F4)"),
 ('M83', 'encode.bend', 'Bool.and(on, Nat.is_ge(budget, 2n))', 'Bool.and(on, Nat.is_ge(budget, 3n))',
  'fc.can: flatten-depth 2 never folds (R24-4, F5)'),
 ('M84', 'text.bend', 'def key_first(+c: U32) -> Bool:\n  Bool.or(Bool.and(U32.is_ge(c, 97), U32.is_le(c, 122)), Bool.or(Bool.and(U32.is_ge(c, 65),', 'def key_first(+c: U32) -> Bool:\n  Bool.or(Bool.and(U32.is_ge(c, 97), U32.is_le(c, 122)), Bool.or(Bool.and(U32.is_ge(c, 66),',
  "key_first: 'A' cannot start a bare key (R24-4, KF1)"),
 # round 25: the reviewer's own mutant texts (r25/m25defs.py), taken verbatim
 ('M85', 'decode.bend', 'T.head_is(T.trim_start(r), 91)', 'T.head_is(r, 91)',
  'eat.item: White_Space before `[` in an item hides the nested array (R25-3, D7)'),
 ('M86', 'decode.bend', 'True{}, uq.pos(colon, cpos, idx), dl, dpos}', 'True{}, idx, dl, dpos}',
  "uq.tr: the LAST colon's position is kept (R25-3, D25)"),
 ('M87', 'decode.bend', 'colon, cpos, True{}, uq.pos(dl, dpos, idx)}', 'colon, cpos, True{}, idx}',
  "uq.tr: the LAST delimiter's position is kept (R25-3, D26)"),
 ('M88', 'decode.bend', 'Bool.and(Nat.is_eq(depth, r), Bool.and(Bool.not(is_dash_sp(content)), is_row(content, delim)))', 'Bool.and(Nat.is_eq(depth, r), is_row(content, delim))',
  'surplus.tab: a `- ` line after a full table counts as a surplus row (R25-3, D5)'),
 ('M89', 'cli.bend', 'Bool.and(Bool.and(at, Bool.not(Bool.or(dot, exp))), num.go(rest, num.cls(rest), True{}, True{}, exp, False{}))', 'Bool.and(Bool.and(at, Bool.not(dot)), num.go(rest, num.cls(rest), True{}, True{}, exp, False{}))',
  "num.go: a '.' after the exponent letter is still a number (R25-3, C3)"),
 ('M90', 'cli.bend', '    case SNil{} _:\n      Bool.not(last_e)', '    case SNil{} _:\n      True{}',
  'num.go: a trailing exponent letter is still a number (R25-3, C5)'),
 ('M91', 'cli.bend', '    case POpt{8n, False{}, w}:\n      True{}', '    case POpt{8n, False{}, w}:\n      False{}',
  'neg.ok: --flatten-depth does not take a negative-number word (R25-3, C6)'),
 ('M92', 'decode.bend', '    case False{} False{} False{} False{}:\n      1n', '    case False{} False{} False{} False{}:\n      0n',
  'fits.obj: lenient mode closes the object at a deeper line (R25-4, D11)'),
 ('M93', 'decode.bend', '    case False{} True{} _ _:\n      0n', '    case False{} True{} _ _:\n      1n',
  'fits.obj: a list-item line inside a list-item object is a field (R25-4, D12)'),
 ('M94', 'decode.bend', 'blank.in(first, last), surplus.tab(pk, r, delim)', '0n, surplus.tab(pk, r, delim)',
  'pop FTab: blank lines inside a table are allowed (R25-4, D14)'),
 ('M95', 'cli.bend', 'TOut{True{}, tok.out.eq(U32.is_eq(c, 61), c, more)}', 'TOut{True{}, tok.out.eq(False{}, c, more)}',
  "tok.out: `-o=x` keeps the '=' (R25-4, C7)"),
 # round 26: the reviewer's own mutant texts (r26/m26defs.py). Not here: N4 (two edits; this inventory takes one),
 # N10 and N11 (the nesting limit: 16 KB inputs, cases only), J1-J4 (exponents: their laws would drive the checker
 # into unary arithmetic or the software float; cases only). Each is pinned by a captured case on every lane.
 ('M96', 'decode.bend', 'Bool.and(Nat.is_eq(depth, r), is_row(content, delim))), 1n, 0n)', 'Bool.and(Nat.is_ge(depth, r), is_row(content, delim))), 1n, 0n)',
  'fits FTab: a deeper data row is consumed as a row (R26-3, N6)'),
 ('M97', 'decode.bend', 'Bool.and(Nat.is_eq(depth, t), is_item(content))), 1n, 0n)', 'Bool.and(Nat.is_ge(depth, t), is_item(content))), 1n, 0n)',
  'fits FList: a deeper list item is consumed as an item (R26-3, N7)'),
 ('M98', 'decode.bend', 'Bool.and(Nat.is_eq(depth, r), Bool.and(Bool.not(is_dash_sp(content)), is_row(content, delim)))', 'Bool.and(Nat.is_ge(depth, r), Bool.and(Bool.not(is_dash_sp(content)), is_row(content, delim)))',
  'surplus.tab: a DEEPER data row after a full table counts as surplus (R26-3, N1)'),
 ('M99', 'cli.bend', 'Bool.and(Bool.and(at, Bool.not(Bool.or(dot, exp))), num.go(', 'Bool.and(Bool.not(Bool.or(dot, exp)), num.go(',
  "num.go: a '.' may be the first character (R26-3, C1)"),
 ('M100', 'cli.bend', 'Bool.and(Bool.and(at, Bool.not(Bool.or(dot, exp))), num.go(', 'Bool.and(Bool.and(at, Bool.not(exp)), num.go(',
  "num.go: a second '.' allowed (R26-3, C2)"),
 ('M101', 'decode.bend', 'Bool.and(g.strict(g), Nat.is_gt(1n+p, 1n+base))', 'Bool.and(g.strict(g), Nat.is_gt(1n+p, 2n+base))',
  'eat.kv.nest: strict indentation jump of one extra level allowed (R26-4, N8)'),
 ('M102', 'decode.bend', 'row.width(Bool.and(strict, Nat.is_ne(T.llen(&2, String, vals, 0n), nf))', 'row.width(Bool.and(strict, Nat.is_gt(T.llen(&2, String, vals, 0n), nf))',
  'eat.row: a narrower row passes strict (R26-4, N14)'),
 ('M103', 'encode.bend', '      FCtx{on, budget, has_set, set, True{}, path(has_pre, pre, k), False{}}', '      FCtx{on, budget, has_set, set, True{}, k, False{}}',
  'fctx.child: the prefix is reset to the raw key (R26-4, E3)'),
 # round 27: the reviewer's own mutant texts (r27/m27defs.py). Not here, each pinned by captured cases: N17, N18,
 # N19 (16 KB nesting inputs), J5, J10, J11 (exponents), D4 (no reviewer input).
 ('M104', 'cli.bend', 'Nat.is_le(T.str_len(c, 0n), 3n)', 'Nat.is_le(T.str_len(c, 0n), 2n)',
  '--flatten-depth of three digits acts as unlimited (R27-3, E11)'),
 ('M105', 'cli.bend', 'Bool.and(U32.is_eq(a, 239), Bool.and(U32.is_eq(b, 187), U32.is_eq(c, 191)))', 'Bool.and(U32.is_eq(a, 239), U32.is_eq(b, 187))',
  'byte-level BOM test ignores the third byte (EF BB xx dropped) (R27-3, C6)'),
 ('M106', 'encode.bend', 'FCtx{on, Nat.sub(budget, segs), has_set, set, True{}, path(has_pre, pre, fkey), lean}', 'FCtx{on, Nat.sub(budget, segs), has_set, set, True{}, fkey, lean}',
  'fctx.rem: the prefix under a partial fold is the folded key alone (the enclosing prefix is lost) (R27-3, E13)'),
 ('M107', 'cli.bend', '    case SCon{h, +rest} 0n:\n      num.go(rest, num.cls(rest), True{}, dot, exp, False{})', '    case SCon{h, +rest} 0n:\n      num.go(rest, num.cls(rest), True{}, dot, exp, last_e)',
  'num.go: a digit after the exponent letter does not clear `last_e` (`-1e5` is not a number) (R27-3, C11)'),
 ('M108', 'encode.bend', 'emit(entries, CFields{dc, fc, keys.kt(fc.on(fc), entries)}', 'emit(entries, CFields{dc, fc, T.kt.empty()}',
  'a NESTED object body has no sibling set: sibling collisions below the root are not seen (R27-4, E6)'),
]

def reduced(laws_text, proof_text):
    head, *blocks = re.split(r"(?m)^(?=# S[^\n]*\nlaw |law )", laws_text)
    kept, names = [], []
    for b in blocks:
        m = re.search(r"(?m)^law\s+(\w+):", b)
        if not m:
            head += b
            continue
        n = m.group(1)
        if not n.startswith("golden_") or KEEP.match(n):
            kept.append(b); names.append(n)
    phead, *pblocks = re.split(r"(?m)^(?=# S[^\n]*\ndef Laws\.|def Laws\.)", proof_text)
    pk = [b for b in pblocks if (re.search(r"(?m)^def Laws\.(\w+)\(", b) or [None, None])[1] in names]
    return head + "".join(kept), phead + "".join(pk), names

def run_proof(d):
    t = time.time()
    try:
        # `check=` is deliberately absent and must stay absent: a NON-ZERO return is the signal this whole
        # script exists to read (the checker refusing a law is a KILLED mutant), so check=True would raise on
        # every kill and turn the evidence into a crash. The returncode is inspected by the caller.
        # `BEND` is the harness-wide BEND_CLI contract (AGENTS.md). It is passed as a LIST, never through a
        # shell, so there is no injection path: it names the compiler the operator chose to run.
        # UBS reports both as findings (python.taint.command critical, py.subprocess-no-check info) on this
        # file and on scripts/diff-fuzz.py; both are false positives for this design and predate this comment.
        # ubs:ignore[python.taint.command] the operator's BEND_CLI as an argv list, no shell (bead toon_bend-vnb).
        r = subprocess.run(BEND + ["PROOF.bend"], cwd=d, capture_output=True, text=True, env=ENV, timeout=1200)
        return r.returncode, (r.stdout + r.stderr), time.time() - t
    except subprocess.TimeoutExpired:
        return "TIMEOUT", "", time.time() - t

def main():
    args = [a for a in sys.argv[1:]]
    if "-h" in args or "--help" in args:
        print(__doc__.strip()); return 0
    all_laws = "--all-laws" in args
    only = set(a for a in args if not a.startswith("-"))
    out_dir = tempfile.mkdtemp(prefix="hand-mutants.")
    print("copies under:", out_dir, flush=True)
    with open(ROOT + "/port/LAWS.bend", encoding="utf-8") as fh:
        laws = fh.read()
    with open(ROOT + "/port/PROOF.bend", encoding="utf-8") as fh:
        proof = fh.read()
    rl, rp, names = (laws, proof, re.findall(r"(?m)^law\s+(\w+):", laws)) if all_laws else reduced(laws, proof)
    results = []
    for mid, fname, old, new, what in [("BASE", None, None, None, "the unmutated proof")] + MUTANTS:
        if only and mid not in only and mid != "BASE":
            continue
        d = os.path.join(out_dir, mid)
        os.makedirs(d, exist_ok=True)
        for f in os.listdir(ROOT + "/port"):
            if f.endswith(".bend"):
                shutil.copyfile(os.path.join(ROOT, "port", f), os.path.join(d, f))
        with open(os.path.join(d, "LAWS.bend"), "w", encoding="utf-8") as fh:
            fh.write(rl)
        with open(os.path.join(d, "PROOF.bend"), "w", encoding="utf-8") as fh:
            fh.write(rp)
        if fname:
            with open(os.path.join(d, fname), encoding="utf-8") as fh:
                src = fh.read()
            if src.count(old) != 1:
                results.append({"id": mid, "status": "NOSITE", "count": src.count(old)}); print(json.dumps(results[-1]), flush=True); continue
            with open(os.path.join(d, fname), "w", encoding="utf-8") as fh:
                fh.write(src.replace(old, new))
        rc, out, dt = run_proof(d)
        if rc == 0 and "All terms check." in out:
            status, by = ("SURVIVED" if fname else "GREEN"), ""
        elif rc == "TIMEOUT":
            status, by = "TIMEOUT", ""
        else:
            locs = re.findall(r"Location: (\S+)", out)
            by = ", ".join(sorted(set(l.split(".", 1)[1] if l.startswith("LAWS.") else l for l in locs)))[:300]
            status = "KILLED" if any(l.startswith("LAWS.") for l in locs) else "INVALID"
            if status == "INVALID":
                by = out.strip().replace("\n", " | ")[:300]
        results.append({"id": mid, "file": fname, "what": what, "status": status, "by": by, "seconds": round(dt, 1)})
        print(json.dumps(results[-1]), flush=True)
        if mid == "BASE" and status != "GREEN":
            print(json.dumps({"verdict": "BASELINE_RED"})); return 2
    muts = [r for r in results if r["id"] != "BASE"]
    # A SURVIVED verdict is only as good as the proof that the law was PRESENT when the mutant ran.
    # On 2026-09-23 the external reset --hard loop on the working checkout wiped two uncommitted laws
    # between writing and mutating them; M36 then reported SURVIVED with a GREEN baseline and a
    # plausible law count, and the run was indistinguishable from a genuinely weak law set. The
    # digest below is over the sorted law names actually compiled into the proof, so a verdict
    # carries its own provenance: two runs that disagree can be told apart by comparing it, and the
    # full list is written beside the copies for inspection. Commit laws before mutating them.
    digest = hashlib.sha256("\n".join(sorted(names)).encode()).hexdigest()[:12]
    with open(os.path.join(out_dir, "laws-in-proof.txt"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(sorted(names)) + "\n")
    summary = {"laws_in_proof": len(names), "laws_sha256_12": digest, "laws_listed_in": out_dir + "/laws-in-proof.txt",
               "reduced": not all_laws, "mutants": len(muts), "killed": sum(r["status"] == "KILLED" for r in muts),
               "survived": [r["id"] for r in muts if r["status"] == "SURVIVED"], "not_evidence": [r["id"] for r in muts if r["status"] not in ("KILLED", "SURVIVED")]}
    summary["verdict"] = "STRONG" if muts and summary["killed"] == len(muts) else "WEAK"
    print(json.dumps(summary), flush=True)
    return 0 if summary["verdict"] == "STRONG" else 1


if __name__ == "__main__":
    sys.exit(main())
