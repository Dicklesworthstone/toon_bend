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

The set holds 34 mutants and the ids run M01..M12 and M14..M35: `M13` is a numbering slip that was never
defined (`git log -S M13 -- scripts/hand-mutants.py` is empty), NOT a mutant that was removed for being
INVALID. Count the set with `len(MUTANTS)`, never by reading the highest id.
"""
import json, os, re, shutil, subprocess, sys, tempfile, time
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
 # (writer_b_escapes_del, writer_b_escapes_c1, utf8_rejects_surrogate, tab_in_value_forces_quotes), and the
 # mutants live here so that stays true.
 ("M24", "json.bend", "w.ch.plain(Bool.or(U32.is_le(c, 31), Bool.and(U32.is_ge(c, 127), U32.is_le(c, 159))), c, acc)", "w.ch.plain(U32.is_le(c, 31), c, acc)", "writer B stops escaping DEL and the C1 block"),
 ("M25", "text.bend", "Bool.or(U32.is_lt(value, 55296), U32.is_gt(value, 57343))", "True{}", "a UTF-8-encoded surrogate is accepted"),
 ("M26", "encode.bend", "Bool.or(U32.is_eq(c, 13), U32.is_eq(c, 9))", "U32.is_eq(c, 13)", "a TAB in a value no longer forces quotes"),
 # Round 14's five (R14-1): each SURVIVED the whole 374-law proof while breaking captured cases, until
 # the laws of 2026-09-22 pinned them. M31 mutates the same expression as M26 but the OTHER arm (CR, not TAB).
 ("M27", "cli.bend", "Bool.and(U32.is_ge(c, 65), U32.is_le(c, 90))", "Bool.and(U32.is_ge(c, 65), U32.is_le(c, 83))", "the extension lowercaser stops folding T..Z, so `.TOON` is not decoded"),
 ("M28", "cli.bend", "def seven_tenths() -> F.F64:\n  F.from_dec(True{}, False{}, [7], 1n)", "def seven_tenths() -> F.F64:\n  F.from_dec(True{}, False{}, [8], 1n)", "clap's similarity threshold moves from 0.7 to 0.8"),
 ("M29", "text.bend", "U32.is_eq(c, 5760)", "U32.is_eq(c, 5761)", "U+1680 stops being White_Space and U+1681 starts"),
 ("M30", "f64.bend", "    case Pos{p}:\n      Nat.is_le(p, 16n)\n    case Neg{z}:\n      Nat.is_le(z, 4n)", "    case Pos{p}:\n      Nat.is_le(p, 15n)\n    case Neg{z}:\n      Nat.is_le(z, 4n)", "the JSON writers' plain/exponent boundary moves from 1e16 to 1e15"),
 ("M31", "encode.bend", "Bool.or(U32.is_eq(c, 13), U32.is_eq(c, 9))", "Bool.or(U32.is_eq(c, 9), U32.is_eq(c, 9))", "a CR in a value no longer forces quotes"),
 # An author-side hunt before round 15 (2026-09-22): round 14's survivors were each one entry of a small
 # table, so other entries of the same tables were tried. Two White_Space entries SURVIVED the full
 # 381-law proof; the `:` and LF arms of `bad_char` were already killed by golden laws.
 ("M32", "text.bend", "U32.is_eq(c, 12288)", "U32.is_eq(c, 12289)", "U+3000 IDEOGRAPHIC SPACE stops being White_Space"),
 ("M33", "text.bend", "U32.is_eq(c, 160)", "U32.is_eq(c, 161)", "U+00A0 NO-BREAK SPACE stops being White_Space"),
 # Round 15 (R15-10): two laws this file's own notes called "proved but not SHOWN to bite" each turned out
 # to be the ONLY law that kills one of the reviewer's mutants. These make that bite permanent.
 ("M34", "f64.bend", "    case Pos{p}:\n      Nat.is_le(p, 16n)", "    case Pos{p}:\n      Nat.is_le(p, 17n)", "the JSON writers stay plain at k = 17 (only json_exponent_at_k17 catches it)"),
 ("M35", "text.bend", "Bool.or(Bool.and(U32.is_ge(c, 9), U32.is_le(c, 13)), Bool.or(U32.is_eq(c, 32)", "Bool.or(Bool.and(U32.is_ge(c, 9), U32.is_le(c, 14)), Bool.or(U32.is_eq(c, 32)", "White_Space gains U+000E (only is_ws_documented_non_members catches it)"),
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
    summary = {"laws_in_proof": len(names), "reduced": not all_laws, "mutants": len(muts), "killed": sum(r["status"] == "KILLED" for r in muts),
               "survived": [r["id"] for r in muts if r["status"] == "SURVIVED"], "not_evidence": [r["id"] for r in muts if r["status"] not in ("KILLED", "SURVIVED")]}
    summary["verdict"] = "STRONG" if muts and summary["killed"] == len(muts) else "WEAK"
    print(json.dumps(summary), flush=True)
    return 0 if summary["verdict"] == "STRONG" else 1


if __name__ == "__main__":
    sys.exit(main())
