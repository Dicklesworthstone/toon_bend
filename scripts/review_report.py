#!/usr/bin/env python3
"""The ONE reader of a review report (docs/reviews/round-NN.md) for the rounds under the adopted counting rule.

scripts/converge.sh and scripts/claims-audit.py both import it. Each used to carry its own reader, and a repair
applied to one and tested on one left the other lying (round 22's R22-2). Round 23 (R23-1, R23-2) then showed
that every reader keyed on ONE layout reads any other layout as "zero counted findings", which agrees with a
rounds-table row of 0: an empty report file, a lens spelled with U+2011, backticked ids, reordered columns, a
leading space, bullets. This reader fails CLOSED: a report it cannot read completely is an error, never a zero.

The contract a report from round 20 on must meet (the review brief states the same one):
  - it is not empty, and a header row `| reviewed commit | <hex> ... |` names the commit it reviewed;
  - it has exactly ONE findings table, found by its header cells `id`, `sev` and `class` (any order, any other
    columns, with or without outer pipes, indented or not), possibly with no rows;
  - every row of that table has an id `R<n>-<k>` of THIS round, a sev HIGH, MEDIUM or LOW, and a class that
    starts BEHAVIOR (or BEHAVIOUR), LAW-COVERAGE or DOCUMENT, after markup is removed;
  - every `R<n>-<k>` of this round named anywhere in the report has a row in that table (a finding written as
    a bullet or in prose only is an error, not an absence).
The counted findings are the rows whose sev is HIGH or MEDIUM and whose class is BEHAVIOR.

What no parser can do: tell a complete, well-formed report written by the table's own author from a real one.
The gates check that the record is complete and consistent, not who wrote it (docs/PORT_STATE.md says so).

usage: review_report.py <report.md> <round>    prints one JSON line; exit 0 when it parses, 1 when not.
"""
import json
import re
import subprocess
import sys
import unicodedata

# Every Unicode dash a lens or an id could be spelled with; NFKC folds NBSP to a space but keeps these.
DASHES = dict.fromkeys(map(ord, "‐‑‒–—―−﹘﹣－"), "-")
SEVERITIES = ("HIGH", "MEDIUM", "LOW")
CLASSES = ("BEHAVIOUR", "BEHAVIOR", "LAW-COVERAGE", "DOCUMENT")


def fold(text):
    """NFKC, every dash to `-`: what a reader sees, as one spelling."""
    return unicodedata.normalize("NFKC", text).translate(DASHES)


def clean(cell):
    """A cell without its markup: HTML tags, links, emphasis and code marks."""
    cell = re.sub(r"<[^>]*>", "", fold(cell))
    cell = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", cell)
    return re.sub(r"[*_`~]", "", cell).strip()


def cells(line):
    """A table line's cells, split on unescaped pipes, outer pipes optional."""
    s = line.strip()
    s = s[1:] if s.startswith("|") else s
    s = s[:-1] if s.endswith("|") and not s.endswith("\\|") else s
    return [c.replace("\\|", "|") for c in re.split(r"(?<!\\)\|", s)]


def is_non_author(lens):
    """The lens says non-author, in any spelling of the dash or the case."""
    return re.search(r"non\s*-\s*author", fold(lens), re.I) is not None


def parse(text, rnd):
    """{"commit", "rows", "counted", "errors"} of one report of round `rnd`."""
    out = {"commit": None, "rows": [], "counted": 0, "errors": []}
    err = out["errors"].append
    t = fold(text)
    if not t.strip():
        err("the report is empty")
        return out
    lines = t.splitlines()
    for line in lines:
        if "|" in line:
            c = [clean(x) for x in cells(line)]
            if len(c) >= 2 and c[0].lower() == "reviewed commit":
                m = re.match(r"([0-9a-fA-F]{7,40})\b", c[1])
                if m:
                    out["commit"] = m.group(1).lower()
                break
    if not out["commit"]:
        err("no `| reviewed commit | <hex> |` header row names the commit this round reviewed")
    tables = []
    for i, line in enumerate(lines[:-1]):
        if "|" not in line:
            continue
        head = [clean(x).lower() for x in cells(line)]
        sep = lines[i + 1]
        if not re.fullmatch(r"\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)*\|?\s*", sep):
            continue
        cols = {name: head.index(name) for name in ("id", "sev", "class") if name in head}
        if "sev" not in cols and "severity" in head:
            cols["sev"] = head.index("severity")
        if len(cols) == 3:
            tables.append((i, cols))
    if len(tables) != 1:
        err("%d findings tables (header cells `id`, `sev`, `class`); a report has exactly one" % len(tables))
        return out
    start, cols = tables[0]
    seen = set()
    for line in lines[start + 2:]:
        if "|" not in line:
            break
        c = cells(line)
        if len(c) <= max(cols.values()):
            err("a findings row has fewer cells than the table's header: %s" % line.strip()[:80])
            continue
        ident, sev, cls = (clean(c[cols[k]]) for k in ("id", "sev", "class"))
        m = re.fullmatch(r"R(\d+)[-.]0*(\d+)", ident, re.I)
        if not m or int(m.group(1)) != rnd:
            err("a findings row whose id `%s` is not R%d-<k>" % (ident[:40], rnd))
            continue
        ident = "R%d-%d" % (rnd, int(m.group(2)))
        if ident in seen:
            err("%s has two rows in the findings table" % ident)
        seen.add(ident)
        sev_word = (sev.upper().split() or [""])[0]
        cls_word = (re.match(r"[A-Z-]*", cls.upper()) or [""])[0]
        if sev_word not in SEVERITIES:
            err("%s: the sev cell `%s` is not HIGH, MEDIUM or LOW" % (ident, sev[:30]))
        if cls_word not in CLASSES:
            err("%s: the class cell `%s` does not start BEHAVIOR, LAW-COVERAGE or DOCUMENT" % (ident, cls[:30]))
        out["rows"].append({"id": ident, "sev": sev_word, "class": cls_word})
        if sev_word in ("HIGH", "MEDIUM") and cls_word.startswith("BEHAVIO"):
            out["counted"] += 1
    named = {"R%d-%d" % (rnd, int(k)) for k in
             re.findall(r"(?<![A-Za-z0-9])R%d[-.]0*(\d+)(?![0-9])" % rnd, t, re.I)}
    for ident in sorted(named - seen, key=lambda s: int(s.split("-")[1])):
        err("%s is named in the report but has no row in its findings table" % ident)
    return out


def reachable(root, rev):
    """True when `rev` is a commit HEAD contains; a git failure answers True (the audit's convention)."""
    try:
        r = subprocess.run(["git", "-C", root, "merge-base", "--is-ancestor", rev, "HEAD"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10, check=False)
        if r.returncode in (0, 1):
            return r.returncode == 0
        probe = subprocess.run(["git", "-C", root, "rev-parse", "--is-inside-work-tree"],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10, check=False)
        return probe.returncode != 0
    except Exception:
        return True


def check(root, path, rnd, recorded):
    """Every problem with round `rnd`'s report at `path` against the rounds table's count `recorded`."""
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
    except OSError:
        return ["round %d has no report %s" % (rnd, path)]
    rep = parse(text, rnd)
    problems = ["round %d: %s: %s" % (rnd, path, e) for e in rep["errors"]]
    if rep["commit"] and not reachable(root, rep["commit"]):
        problems.append("round %d: %s reviewed %s, which is not a commit HEAD contains" % (rnd, path, rep["commit"]))
    if not rep["errors"] and recorded is not None and rep["counted"] != recorded:
        problems.append("round %d: the table says %d counted finding(s), %s lists %d"
                        % (rnd, recorded, path, rep["counted"]))
    return problems


if __name__ == "__main__":
    if len(sys.argv) != 3 or not sys.argv[2].isdigit():
        sys.exit("usage: review_report.py <report.md> <round>")
    with open(sys.argv[1], encoding="utf-8") as fh:
        res = parse(fh.read(), int(sys.argv[2]))
    print(json.dumps(res))
    sys.exit(1 if res["errors"] else 0)
