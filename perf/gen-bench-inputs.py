#!/usr/bin/env python3
"""Regenerate the performance inputs of perf/EXPERIMENTS.md (deterministic, no randomness).

usage: python3 perf/gen-bench-inputs.py [--check]
Writes perf/inputs/*.json (and the one hand-shaped .toon of EXP-004); the TOON twins used by the decode captures are made by the pinned
original: ./oracle/toon --encode perf/inputs/<name>.json -o perf/inputs/<name>.toon
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def _lcg(i):
    """A fixed 48-bit linear congruence (the constants of POSIX drand48), seeded by the index."""
    x = (i * 2862933555777941757 + 3037000493) & ((1 << 64) - 1)
    for _ in range(3):
        x = (x * 0x5DEECE66D + 0xB) & ((1 << 48) - 1)
    return x


def _double(i):
    """17 significant digits and a decimal exponent in -10..9, written the way json.dumps writes a float."""
    x = _lcg(i)
    return repr(((x >> 4) % 10 ** 17) / 10 ** 17 * 10 ** (x % 20 - 10))


def _sci(i):
    x = _lcg(i + 1000003)
    return "%d.%06de%+d" % (x % 9 + 1, (x >> 8) % 10 ** 6, (x >> 30) % 501 - 250)


def _big_rows(n):
    """A tabular document of n rows, the SAME shape as `big_rows` in cases/gen-hand-cases.py (which
    builds the `large_tabular_1500` case), so a capture on this one differs from the earlier attempts
    only in length. Keep the two formulas identical; a divergence would make the lengths incomparable."""
    rows = [{"id": k, "name": "user%d" % k, "email": "user%d@example.com" % k,
             "score": (k * 37 % 1000) / 10, "active": k % 3 == 0,
             "note": None if k % 7 else "has, comma"} for k in range(n)]
    return json.dumps({"rows": rows}, ensure_ascii=False) + "\n"
OUT = os.path.join(HERE, "inputs")
DOCS = {
    "ints_24000.json": json.dumps(list(range(100000, 100000 + 24000))),
    "decimals1_9000.json": json.dumps([round(i * 3.7, 1) for i in range(9000)]),
    "strings_7000.json": json.dumps(["user%d@example.com" % i for i in range(7000)]),
    # EXP-004: one large dimension each (keys of one object, folded keys, expanded paths, fields of a row)
    "wide_object_16000.json": json.dumps({"k%d" % i: i for i in range(16000)}),
    "fold_keys_30000.json": json.dumps({"k%d" % i: {"a": {"b": "v"}} for i in range(30000)}),
    # NE-004's escalation: five captures on fold_keys_30000 were REFUSED_CV, the fifth on a quiet host
    # (load 0.91, --runs 15) with the PORT's arm at cv 8.37% and a 233.6 ms median. That entry's
    # do-not-retry says, in those exact circumstances, "capture at 60000 keys" - a longer arm for the
    # same allocation pattern. Same shape as the 30000 one, twice the keys.
    "fold_keys_60000.json": json.dumps({"k%d" % i: {"a": {"b": "v"}} for i in range(60000)}),
    "expand_lines_40000.toon": "".join("a.k%d.c: v\n" % i for i in range(40000)),
    "wide_rows_1200.json": json.dumps([{"f%d" % j: "v" for j in range(1200)} for _ in range(20)]),
    # EXP-005 / EXP-006 (DISC-013): numbers that are not small integers. A fixed linear congruence, no random module:
    # the same bytes on every Python.
    "doubles_20000.json": "[" + ",".join(_double(i) for i in range(20000)) + "]",
    "sci_5000.json": "[" + ",".join(_sci(i) for i in range(5000)) + "]",
    # The tabular encode capture's input, scaled so the ORIGINAL's arm is long enough to gate.
    # `cases/inputs/hand/large_tabular_1500.json` gives the original a 5.2 ms median, and a capture at
    # that length was REFUSED_CV twice (beads toon_bend-udw and toon_bend-0i8, whose predicate is "an
    # arm of at least 100 ms"). The row shape is EXACTLY `big_rows` of cases/gen-hand-cases.py, so the
    # two inputs differ only in length and a capture on this one is comparable with the earlier attempts.
    # It is a perf input, not a case: as a case its 3 MB would be re-read by every lane of every
    # conformance run and would force a golden re-capture, for no extra coverage over the 1500-row case.
    "tabular_30000.json": _big_rows(30000),
    # The four inputs the still-refused INCUMBENT captures need, each the SAME SHAPE as the small one
    # it replaces and longer only in length, so a capture on it is comparable with the earlier attempts.
    # PORT_REPORT recorded all five remaining refusals as the host's fault ("on a quiet host"). Reading
    # the arms says otherwise, and in the same way the tabular one was misread: the ORIGINAL's arm is
    # 3.45 ms (decimals1_9000, cv 21.8%), 5.92 ms (ints_24000, 16.3%), 5.04 ms (sci_5000, 20.0%) and
    # 4.29 ms (strings_7000, 21.9%), while the PORT's arm is 3.2-7.3% on three of the four. No quiet
    # host times a 3 ms process to 5%: the binding constraint is the arm, and the predicate of beads
    # toon_bend-udw and toon_bend-0i8 is "an arm of at least 100 ms". Sized by measuring `oracle/toon`
    # (694d73b, the CURRENT pin) on candidates: 122.0, 126.4, 112.1 and 102.7 ms respectively.
    # The fifth refusal, INCUMBENT.startup, is `--version` and has NO input to scale; see PORT_STATE.
    "decimals1_300000.json": json.dumps([round(i * 3.7, 1) for i in range(300000)]),
    "ints_300000.json": json.dumps(list(range(100000, 100000 + 300000))),
    "sci_80000.json": "[" + ",".join(_sci(i) for i in range(80000)) + "]",
    "strings_300000.json": json.dumps(["user%d@example.com" % i for i in range(300000)]),
}


def _read_text(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def main():
    check = "--check" in sys.argv[1:]
    drift = []
    os.makedirs(OUT, exist_ok=True)
    for name, text in DOCS.items():
        path = os.path.join(OUT, name)
        if check:
            if not os.path.exists(path) or _read_text(path) != text:
                drift.append(name)
        else:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(text)
    print(json.dumps({"inputs": len(DOCS), "drift": drift, "verdict": "OK" if not drift else ("DRIFT" if check else "WRITTEN")}))
    return 1 if drift and check else 0


if __name__ == "__main__":
    sys.exit(main())
