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
OUT = os.path.join(HERE, "inputs")
DOCS = {
    "ints_24000.json": json.dumps(list(range(100000, 100000 + 24000))),
    "decimals1_9000.json": json.dumps([round(i * 3.7, 1) for i in range(9000)]),
    "strings_7000.json": json.dumps(["user%d@example.com" % i for i in range(7000)]),
    # EXP-004: one large dimension each (keys of one object, folded keys, expanded paths, fields of a row)
    "wide_object_16000.json": json.dumps({"k%d" % i: i for i in range(16000)}),
    "fold_keys_30000.json": json.dumps({"k%d" % i: {"a": {"b": "v"}} for i in range(30000)}),
    "expand_lines_40000.toon": "".join("a.k%d.c: v\n" % i for i in range(40000)),
    "wide_rows_1200.json": json.dumps([{"f%d" % j: "v" for j in range(1200)} for _ in range(20)]),
    # EXP-005 / EXP-006 (DISC-013): numbers that are not small integers. A fixed linear congruence, no random module:
    # the same bytes on every Python.
    "doubles_20000.json": "[" + ",".join(_double(i) for i in range(20000)) + "]",
    "sci_5000.json": "[" + ",".join(_sci(i) for i in range(5000)) + "]",
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
