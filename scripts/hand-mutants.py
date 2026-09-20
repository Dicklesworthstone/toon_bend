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
"""
import json, os, re, shutil, subprocess, sys, tempfile, time
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BEND = os.environ.get("BEND_CLI", "bun /tmp/bend/bend2/main.ts").split()
ENV = dict(os.environ, BEND_NO_TELEMETRY="1")
KEEP = re.compile(r"golden_(encnum|decnum|fx_dec_numbers|happy|fx_enc_arrays_(tabular|objects)|fx_dec_arrays_tabular|fx_dec_path_expansion|toonedge_expand|jsonout_duplicate|fx_enc_key_folding|enc_fold|toonerr_expand|encstr_duplicate|collision)")
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
 ("M11", "text.bend", "kt.bucket_has.go(rest, k, str_eq(x, k))", "kt.bucket_has.go(rest, k, False{})", "membership never hits"),
 ("M12", "text.bend", "    case Nil{} False{}:\n      False{}\n    case Con{x, rest} False{}:\n      kt.bucket_has.go", "    case Nil{} False{}:\n      True{}\n    case Con{x, rest} False{}:\n      kt.bucket_has.go", "membership always hits"),
 ("M14", "json.bend", "FObj{rev_entries(obj.replace(rev, key, Some{v}, JNil{}), JNil{}), SNil{}, idx}", "FObj{JECons{key, False{}, v, rev}, SNil{}, idx}", "a repeated JSON key is appended, not replaced"),
 ("M15", "decode.bend", "    case XObj{keys, map} True{}:\n      XObj{k <> keys, xm.set(map, k, v)}", "    case XObj{keys, map} True{}:\n      XObj{keys, xm.set(map, k, v)}", "a fresh expanded key is never listed"),
 ("M16", "decode.bend", "    case XObj{keys, map} False{}:\n      XObj{keys, xm.set(map, k, v)}", "    case XObj{keys, map} False{}:\n      XObj{k <> keys, xm.set(map, k, v)}", "a merged key is listed twice"),
 ("M17", "encode.bend", "row.lock(rest, t, T.str_eq(k, key), Bool.and(prim, is_prim(v)))", "row.lock(rest, t, True{}, Bool.and(prim, is_prim(v)))", "rows in another key order count as lockstep"),
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
