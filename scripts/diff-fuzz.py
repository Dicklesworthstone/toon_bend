#!/usr/bin/env python3
"""diff-fuzz: differential fuzzing of the port against the pinned original, outside the corpus.

Every lens compares stdout, stderr and the exit code, byte for byte, of
    <original> ARGV            and            <port...> ARGV
on generated inputs. Deterministic for a given --seed. The last stdout line is a JSON scorecard.

usage: diff-fuzz.py <lens> [--seed N] [--runs N] [--jobs N] [--original PATH] -- <port command...>
lenses:
  mutate    corpus documents (stdin files of goldens/cases.tsv) with random edits, their own mode, random options
  docs      structure-aware generated JSON through --encode with random options, then the original's
            TOON through --decode (expansion, lenient, indents)
  argv      random command lines (flags, clusters, values, typos, paths, the escape) on small inputs
  numbers   generated number texts in both directions; with --switch VAR=1 also the port under that
            environment variable (fast twins vs spec twins vs the original)
  expand    TOON documents over a small key alphabet: dotted keys, quoted keys, duplicates, merges,
            conflicts, strict and lenient, always with --expand-paths safe
  scale     one large dimension per input (keys, rows, fields, items, digits, blank lines); reports the
            port's and the original's wall time beside the byte comparison (the quadratic-time lens)
Never writes a file: an argv that names an output path other than a device is not generated.
exit: 0 no difference, 1 differences (the first few are printed), 2 usage.
"""
import json
import os
import random
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def parse(argv):
    if len(argv) < 2 or argv[0] in ("-h", "--help") or "--" not in argv:
        print(__doc__.strip())
        sys.exit(0 if argv and argv[0] in ("-h", "--help") else 2)
    cut = argv.index("--")
    head, port = argv[:cut], argv[cut + 1:]
    opts = {"lens": head[0], "seed": 1, "runs": 2000, "jobs": 4, "original": os.path.join(ROOT, "oracle", "toon"), "switch": None}
    i = 1
    while i < len(head):
        key = head[i].lstrip("-")
        if key not in ("seed", "runs", "jobs", "original", "switch") or i + 1 >= len(head):
            print(__doc__.strip())
            sys.exit(2)
        opts[key] = head[i + 1] if key in ("original", "switch") else int(head[i + 1])
        i += 2
    if not port:
        sys.exit(2)
    return opts, port


def run(cmd, data, env=None, limit=120):
    e = dict(os.environ)
    e.pop("TOON_SPEC", None)
    if env:
        e.update(env)
    t0 = time.perf_counter()
    try:
        r = subprocess.run(cmd, input=data, capture_output=True, cwd=ROOT, env=e, timeout=limit)
        return (r.returncode, r.stdout, r.stderr), time.perf_counter() - t0
    except subprocess.TimeoutExpired:
        return ("TIMEOUT", b"", b""), float(limit)


def corpus_docs(max_bytes=4000):
    out = []
    path = os.path.join(ROOT, "goldens", "cases.tsv")
    with open(path, encoding="utf-8") as fh:
        rows = [l.rstrip("\n").split("\t") for l in fh if l.strip() and not l.startswith("#")]
    for r in rows:
        try:
            argv = json.loads(r[1])
        except json.JSONDecodeError as exc:
            raise SystemExit("goldens/cases.tsv: argv of %s is not a JSON array: %s" % (r[0], exc))
        mode = "--decode" if ("--decode" in argv or "-d" in argv) else "--encode"
        if r[2] == "-":
            continue
        p = os.path.join(ROOT, r[2])
        if os.path.getsize(p) > max_bytes:
            continue
        with open(p, "rb") as fh:
            raw = fh.read()
        try:
            out.append((mode, raw.decode("utf-8")))
        except UnicodeDecodeError:
            continue
    return sorted(set(out))


ALPHA = list(' \t\n:,|-[]{}"\\.#0123456789abkxy_+eE') + ["  ", "- ", "\n  ", "\n    ", '": ', "[2]", "{a,b}", "true", "null", "1e5", "-0", "\r\n", " ", "﻿", "é", '"a.b"', "a.b", "\\n", "\\u", '{"a":', "[1,2]", "{}", "[]", "0.1", "1E400"]


def lens_mutate(rnd, n):
    seeds = corpus_docs()
    for _ in range(n):
        mode, s = rnd.choice(seeds)
        for _ in range(rnd.randint(1, 4)):
            if not s:
                s = "a: 1\n"
            i = rnd.randrange(len(s) + 1)
            k = rnd.random()
            if k < 0.4:
                s = s[:i] + rnd.choice(ALPHA) + s[i:]
            elif k < 0.6:
                s = s[:i] + s[i + 1:]
            else:
                ls = s.split("\n")
                j = rnd.randrange(len(ls))
                if k < 0.75:
                    ls.insert(j, ls[rnd.randrange(len(ls))])
                elif k < 0.85:
                    ls[j] = " " * rnd.randint(0, 5) + ls[j].lstrip(" ")
                elif k < 0.93:
                    del ls[j]
                else:
                    ls.insert(j, "")
                s = "\n".join(ls)
        args = [mode]
        if mode == "--decode":
            args += ["--indent", rnd.choice(["2", "2", "2", "0", "1", "3", "4"])]
            if rnd.random() < 0.35:
                args.append("--no-strict")
            if rnd.random() < 0.35:
                args += ["--expand-paths", "safe"]
        else:
            args += ["--indent", rnd.choice(["2", "2", "0", "1", "4"]), "--delimiter", rnd.choice([",", "|", "\t"])]
            if rnd.random() < 0.5:
                args += ["--key-folding", "safe"]
            if rnd.random() < 0.3:
                args += ["--flatten-depth", str(rnd.choice([0, 1, 2, 3]))]
            if rnd.random() < 0.2:
                args.append("--stats")
        yield args, s.encode("utf-8"), None


STR = ["", "a", "true", "false", "null", "1", "-1", "1e5", "0x1", "05", "-", "- x", " pad", "pad ", "a b", "a,b", "a|b", "a\tb", "a:b", "[1]", "x[1]: y", "{a}", '"q"', "back\\slash", "line\nbreak", "\r", " nb", " em", "﻿", "é", "日本", "😀", "\u0007", "\u007f", "\u0085", "a.b", "a.b.c", "_x", "x-y", "k.", ".k", "#c", "long " + "z" * 40]
KEYS = ["a", "b", "c", "id", "name", "a.b", "a.b.c", "x.y", "k-1", "1k", "", "true", "with space", 'q"uote', "é", "c:d", "[k]", "{k}", "a}b", "_", "A_1", "data", "meta", "items"]


def gen_num(rnd):
    k = rnd.random()
    if k < 0.4:
        return str(rnd.randrange(-1000, 100000))
    if k < 0.6:
        return "%d.%d" % (rnd.randrange(0, 1000), rnd.randrange(0, 10 ** rnd.randrange(1, 12)))
    if k < 0.8:
        return rnd.choice(["1e21", "1e-7", "1.5e300", "5e-324", "-0", "-0.0", "0.1", "1e16", "123456789012345678", "0.30000000000000004", "2.5e-5", "9007199254740993", "1E+2", "4.35", "0.000001", "1e15", "281474976710655", "281474976710656"])
    return str(rnd.random() * 10 ** rnd.randrange(-20, 25))


def gen_val(rnd, d):
    k = rnd.random()
    if d > 3 or k < 0.35:
        j = rnd.random()
        if j < 0.45:
            return json.dumps(rnd.choice(STR), ensure_ascii=rnd.random() < 0.3)
        if j < 0.8:
            return gen_num(rnd)
        return rnd.choice(["true", "false", "null"])
    if k < 0.6:
        n = rnd.randrange(0, 5)
        if rnd.random() < 0.4:
            ks = rnd.sample(KEYS, rnd.randrange(1, 4))
            rows = []
            for _ in range(n):
                order = ks if rnd.random() < 0.7 else list(reversed(ks))
                rows.append("{" + ",".join(json.dumps(x) + ":" + gen_val(rnd, 9) for x in order) + "}")
            return "[" + ",".join(rows) + "]"
        return "[" + ",".join(gen_val(rnd, d + 1) for _ in range(n)) + "]"
    return "{" + ",".join(json.dumps(rnd.choice(KEYS)) + ":" + gen_val(rnd, d + 1) for _ in range(rnd.randrange(0, 5))) + "}"


def lens_docs(rnd, n):
    for _ in range(n):
        args = ["--encode"]
        if rnd.random() < 0.4:
            args += ["--delimiter", rnd.choice([",", "|", "\t"])]
        ind = "2"
        if rnd.random() < 0.4:
            ind = str(rnd.choice([0, 1, 2, 3, 4, 8]))
            args += ["--indent", ind]
        if rnd.random() < 0.5:
            args += ["--key-folding", "safe"]
        if rnd.random() < 0.3:
            args += ["--flatten-depth", str(rnd.choice([0, 1, 2, 3, 10]))]
        if rnd.random() < 0.3:
            args.append("--stats")
        back = ["--decode", "--indent", ind]
        if rnd.random() < 0.5:
            back += ["--expand-paths", "safe"]
        if rnd.random() < 0.3:
            back.append("--no-strict")
        yield args, gen_val(rnd, 0).encode("utf-8"), back


LONG = ["output", "encode", "decode", "delimiter", "indent", "no-strict", "key-folding", "flatten-depth", "expand-paths", "stats", "help", "version"]
VALS = ["0", "2", "4", "16", "17", "-1", "+3", "03", "abc", "", "x", ",", "|", "pipe", "tab", "\\t", "comma", "off", "safe", "Safe", "saf", "of", "on", "SAFE", "ofae", "1.5", "99999999999999999999", "18446744073709551615", "18446744073709551616", "-", "--", "-x", "/dev/null"]
FILES = ["cases/inputs/hand/files/auto.json", "cases/inputs/hand/files/auto.toon", "nope.json", "cases/inputs/hand/files", "-", "help", "x.TOON", ".json"]
DEVICES = ("/dev/null", "/dev/stdout")


def argv_safe(a):
    for i, w in enumerate(a):
        nxt = a[i + 1] if i + 1 < len(a) else None
        if w.startswith("--output"):
            val = w.split("=", 1)[1] if "=" in w else nxt
            if val not in DEVICES:
                return False
        elif w.startswith("-") and not w.startswith("--") and "o" in w[1:]:
            rest = w[w.index("o", 1) + 1:]
            rest = rest[1:] if rest.startswith("=") else rest
            if (rest or nxt) not in DEVICES:
                return False
        elif w == "/dev/stdout" and not (i > 0 and a[i - 1] in ("-o", "--output")):
            return False
    return True


def lens_argv(rnd, n):
    def typo(s):
        k = rnd.random()
        if k < 0.3 and len(s) > 2:
            i = rnd.randrange(len(s))
            return s[:i] + s[i + 1:]
        if k < 0.6:
            i = rnd.randrange(len(s) + 1)
            return s[:i] + rnd.choice("abcdefghijklmnopqrstuvwxyz-") + s[i:]
        if k < 0.8:
            return s.upper() if rnd.random() < 0.5 else s.capitalize()
        return s[:max(1, len(s) // 2)]

    def word():
        k = rnd.random()
        if k < 0.35:
            w = "--" + rnd.choice(LONG)
            return [w + "=" + rnd.choice(VALS)] if rnd.random() < 0.35 else [w]
        if k < 0.45:
            return ["--" + typo(rnd.choice(LONG))]
        if k < 0.6:
            return ["-" + "".join(rnd.choice("edhVoxE=5") for _ in range(rnd.randint(1, 3)))]
        if k < 0.8:
            return [rnd.choice(VALS)]
        if k < 0.9:
            return [rnd.choice(FILES)]
        if k < 0.95:
            return ["--"]
        return ["--" + rnd.choice(LONG), rnd.choice(VALS)]

    inputs = [b'{"a":"b","l":["x","y"]}\n', b"a: b\nl[2]: x,y\n", b"", b"{bad"]
    made = 0
    while made < n:
        a = []
        for _ in range(rnd.randint(0, 5)):
            a += word()
        if argv_safe(a):
            made += 1
            yield a, rnd.choice(inputs), None


EDGE = [0, 1, 9, 10, 99, 100, 2 ** 31 - 1, 2 ** 32, 2 ** 48 - 1, 2 ** 48, 2 ** 48 + 1, 10 ** 14 - 1, 10 ** 14, 10 ** 14 + 1, 10 ** 15, 2 ** 53 - 1, 2 ** 53, 2 ** 53 + 1, 2 ** 63, 2 ** 64 - 1, 2 ** 64, 10 ** 22, 10 ** 23]


def num_text(rnd):
    k = rnd.random()
    sign = "-" if rnd.random() < 0.25 else ""
    if k < 0.2:
        return sign + str(max(0, rnd.choice(EDGE) + rnd.choice([0, 0, 1, -1, 7])))
    if k < 0.45:
        return sign + str(rnd.randrange(0, 10 ** rnd.randrange(1, 16)))
    if k < 0.7:
        return sign + "%d.%s" % (rnd.randrange(0, 10 ** rnd.randrange(1, 10)), "".join(rnd.choice("0123456789") for _ in range(rnd.randrange(1, 8))))
    if k < 0.85:
        return sign + "%d.%s" % (rnd.randrange(0, 100), "".join(rnd.choice("0123456789") for _ in range(rnd.randrange(8, 30))))
    m = str(rnd.randrange(1, 10 ** rnd.randrange(1, 18)))
    if rnd.random() < 0.5:
        m += "." + str(rnd.randrange(0, 10 ** rnd.randrange(1, 10)))
    return sign + m + rnd.choice(["e", "E"]) + rnd.choice(["", "+", "-"]) + str(rnd.choice([0, 1, 5, 15, 16, 21, 22, 23, 24, 30, 100, 200, 300, 307, 308]))


def lens_numbers(rnd, n, original):
    per = 400
    for _ in range(max(1, n // per)):
        lits = [num_text(rnd) for _ in range(per)]
        ok = [l for l in lits if run([original, "--encode"], ("[" + l + "]").encode())[0][0] == 0] if run([original, "--encode"], ("[" + ",".join(lits) + "]").encode())[0][0] != 0 else lits
        yield ["--encode"], ("[" + ",".join(ok) + "]").encode("utf-8"), None
        yield ["--decode"], ("l[%d]:\n" % len(ok) + "".join("  - %s\n" % l for l in ok)).encode("utf-8"), None


SEG = ["a", "b", "c", "x", "y", "k1", "_z"]


def lens_expand(rnd, n):
    def key():
        k = ".".join(rnd.choice(SEG) for _ in range(rnd.randint(1, 4)))
        r = rnd.random()
        return '"' + k + '"' if r < 0.12 else (k + "-q" if r < 0.18 else k)

    def body(d, ind):
        out = []
        for _ in range(rnd.randint(1, 5)):
            k = key()
            r = rnd.random()
            if r < 0.45 or d > 2:
                out.append(ind + k + ": " + rnd.choice(["1", "x", "true", '"s"', "null"]))
            elif r < 0.6:
                out.append(ind + k + "[2]: p,q")
            elif r < 0.7:
                out.append(ind + k + ":")
            elif r < 0.8:
                out += [ind + k + "[2]{" + key() + "," + key() + "}:", ind + "  1,2", ind + "  3,4"]
            elif r < 0.88:
                out += [ind + k + "[1]:", ind + "  - " + key() + ": 1", ind + "    " + key() + ": 2"]
            else:
                out.append(ind + k + ":")
                out += body(d + 1, ind + "  ")
        return out

    for _ in range(n):
        args = ["--decode", "--expand-paths", "safe"]
        if rnd.random() < 0.5:
            args.append("--no-strict")
        yield args, ("\n".join(body(0, "")) + "\n").encode("utf-8"), None


def lens_scale(rnd, n):
    size = max(1000, n)
    yield ["-e"], json.dumps({("k%d" % i): i for i in range(size)}).encode(), None
    yield ["-e", "--key-folding", "safe"], json.dumps({("k%d" % i): {"a": {"b": "v"}} for i in range(size)}).encode(), None
    yield ["-d", "--expand-paths", "safe"], "".join("a.k%d.c: v\n" % i for i in range(size)).encode(), None
    yield ["-d", "--expand-paths", "safe"], "".join("x.k%d.c%d: v\n" % (i % 50, i) for i in range(size)).encode(), None
    yield ["-e"], json.dumps([{("f%d" % j): "v" for j in range(size // 20)} for _ in range(20)]).encode(), None
    yield ["-e"], json.dumps([({("f%d" % j): "v" for j in range(size // 20)} if i == 0 else {("f%d" % j): "v" for j in reversed(range(size // 20))}) for i in range(8)]).encode(), None
    yield ["-d"], ("\n" * size + "".join("a%d[1]: x\n" % i for i in range(size))).encode(), None
    yield ["-d"], ("t[%d]{id,n}:\n" % size + "".join("  %d,u%d\n" % (i, i) for i in range(size))).encode(), None
    yield ["-d"], ("l[%d]:\n" % size + "".join("  - k: %d\n" % i for i in range(size))).encode(), None
    yield ["-e"], json.dumps(["s%d" % i for i in range(size)]).encode(), None
    yield ["-d"], ("a: " + "9" * size + "\n").encode(), None


def main():
    opts, port = parse(sys.argv[1:])
    rnd = random.Random(opts["seed"])
    original = opts["original"]
    lens = opts["lens"]
    gens = {"mutate": lens_mutate, "docs": lens_docs, "argv": lens_argv, "expand": lens_expand, "scale": lens_scale}
    if lens == "numbers":
        jobs = list(lens_numbers(rnd, opts["runs"], original))
    elif lens in gens:
        jobs = list(gens[lens](rnd, opts["runs"]))
    else:
        print(__doc__.strip())
        return 2
    switch = None
    if opts["switch"]:
        name, _, value = opts["switch"].partition("=")
        switch = {name: value}

    def work(job):
        args, data, back = job
        o, to = run([original] + args, data)
        p, tp = run(port + args, data)
        diffs = []
        if o != p:
            diffs.append((args, data, o, p))
        if switch is not None:
            s, _ = run(port + args, data, env=switch)
            if s != o:
                diffs.append((["%s=%s" % next(iter(switch.items()))] + args, data, o, s))
        if back is not None and o[0] == 0:
            o2, _ = run([original] + back, o[1])
            p2, _ = run(port + back, o[1])
            if o2 != p2:
                diffs.append((back, o[1], o2, p2))
        return diffs, to, tp, args, len(data)

    total = 0
    found = []
    slow = []
    with ThreadPoolExecutor(1 if lens == "scale" else opts["jobs"]) as ex:
        for diffs, to, tp, args, size in ex.map(work, jobs):
            total += 1
            found += diffs
            if lens == "scale":
                slow.append({"argv": args, "bytes": size, "original_s": round(to, 2), "port_s": round(tp, 2)})
    for args, data, o, p in found[:8]:
        print("DIFF", args, repr(data[:200]))
        print("   original", o[0], o[1][:100], o[2][:160])
        print("   port    ", p[0], p[1][:100], p[2][:160])
    for row in slow:
        print("scale", json.dumps(row))
    print(json.dumps({"lens": lens, "seed": opts["seed"], "inputs": total, "differences": len(found), "switch": opts["switch"], "verdict": "PASS" if not found else "FAIL"}))
    return 0 if not found else 1


if __name__ == "__main__":
    sys.exit(main())
