#!/usr/bin/env python3
"""The ONE reader of a review report (docs/reviews/round-NN.md) for the rounds under the adopted counting rule.

scripts/converge.sh and scripts/claims-audit.py both import it. Each used to carry its own reader, and a repair
applied to one and tested on one left the other lying (round 22's R22-2). Round 23 (R23-1, R23-2) then showed
that every reader keyed on ONE layout reads any other layout as "zero counted findings", which agrees with a
rounds-table row of 0: an empty report file, a lens spelled with U+2011, backticked ids, reordered columns, a
leading space, bullets. This reader fails CLOSED: a report it cannot read completely is an error, never a zero.

The contract a report from round 20 on must meet (the review brief states the same one):
  - it is not empty, and a header row `| reviewed commit | <hex> ... |` names the commit it reviewed;
  - it is read as a renderer reads it (rounds 24-25): parsed with a CommonMark parser with GitHub tables
    (markdown-it-py; without it every report is an error), so HTML, code and struck-through text are not read
    and a table counts wherever it renders (top level, blockquote, list item);
  - it has exactly ONE findings table, found by its header cells `id`, `sev` and `class` (any order, any other
    columns), possibly with no rows, and no other rendered table lists this round's ids in its first column;
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


def is_non_author(lens):
    """The lens says non-author, in any spelling of the dash or the case."""
    return re.search(r"non\s*-\s*author", fold(lens), re.I) is not None


def _md():
    """A CommonMark parser with GitHub's tables and strikethrough: the structure a renderer shows. Round 25
    (R25-1) found the fifth way a hand-written line reader and a renderer disagree (a table in a blockquote or under
    a list item; a delimiter row with too few cells, a setext heading, a <pre> block read as a table). Every round
    since 20 found another one, so the reader no longer imitates a renderer: it IS one (markdown-it-py)."""
    try:
        from markdown_it import MarkdownIt
    except ImportError:
        return None
    return MarkdownIt("commonmark").enable(["table", "strikethrough"])


def _text(inline):
    """What a reader sees of one inline token: text and code, not HTML, not struck-through text."""
    out, struck = [], 0
    for c in inline.children or []:
        if c.type == "s_open":
            struck += 1
        elif c.type == "s_close":
            struck -= 1
        elif struck == 0 and c.type in ("text", "code_inline"):
            out.append(c.content)
        elif struck == 0 and c.type in ("softbreak", "hardbreak"):
            out.append(" ")
    return fold("".join(out)).strip()


def _tables(tokens):
    """Every rendered table, anywhere (top level, blockquote, list item), as a list of rows of cell texts."""
    tables, rows, row = [], None, None
    for t in tokens:
        if t.type == "table_open":
            rows = []
        elif t.type == "tr_open":
            row = []
        elif t.type == "inline" and row is not None:
            row.append(_text(t))
        elif t.type == "tr_close":
            rows.append(row)
            row = None
        elif t.type == "table_close":
            tables.append(rows)
            rows = None
    return tables


def parse(text, rnd):
    """{"commit", "rows", "counted", "errors"} of one report of round `rnd`, read from its RENDERED structure."""
    out = {"commit": None, "rows": [], "counted": 0, "errors": []}
    err = out["errors"].append
    md = _md()
    if md is None:
        err("the Markdown parser markdown-it-py is not installed (python3 -m pip install markdown-it-py): "
            "a report is read as a renderer reads it, or not at all")
        return out
    t = fold(text)
    if not t.strip():
        err("the report is empty")
        return out
    tokens = md.parse(t)
    tables = _tables(tokens)
    for rows in tables:
        for r in rows:
            if len(r) >= 2 and r[0].lower() == "reviewed commit" and not out["commit"]:
                m = re.match(r"([0-9a-fA-F]{7,40})\b", r[1])
                if m:
                    out["commit"] = m.group(1).lower()
    if not out["commit"]:
        err("no `| reviewed commit | <hex> |` header row names the commit this round reviewed")
    found = []
    for n, rows in enumerate(tables):
        head = [c.lower() for c in rows[0]] if rows else []
        cols = {name: head.index(name) for name in ("id", "sev", "class") if name in head}
        if "sev" not in cols and "severity" in head:
            cols["sev"] = head.index("severity")
        if len(cols) == 3:
            found.append((n, cols))
    if len(found) != 1:
        err("%d findings tables (header cells `id`, `sev`, `class`); a report has exactly one" % len(found))
        return out
    tn, cols = found[0]
    seen = set()
    for r in tables[tn][1:]:
        ident, sev, cls = (r[cols[k]] if cols[k] < len(r) else "" for k in ("id", "sev", "class"))
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
    # Only the findings table may list this round's findings: another rendered table whose FIRST cell is one of this
    # round's ids (a re-headed copy, R24-1; a copy in a blockquote or a list item, R25-1) is refused.
    for n, rows in enumerate(tables):
        if n != tn:
            for r in rows:
                if r and re.fullmatch(r"R%d[-.]0*\d+" % rnd, r[0], re.I):
                    err("a table other than the findings table lists %s" % r[0])
    shown = " ".join(_text(x) for x in tokens if x.type == "inline")
    named = {"R%d-%d" % (rnd, int(k)) for k in
             re.findall(r"(?<![A-Za-z0-9])R%d[-.]0*(\d+)(?![0-9])" % rnd, shown, re.I)}
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


def check(root, path, rnd, recorded, lens=None):
    """Every problem with round `rnd`'s report at `path` against the rounds table's count `recorded` and, when
    given, the row's own `lens` prose: a finding id of this round that the ROW names must be a row of the report's
    findings table (a4's sweep after round 25: a legal report with an empty table, a `0 | 0 | yes` row whose prose
    still names a MEDIUM behavior finding, was counted clean). The report applies the same rule to its own prose."""
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
    if lens is not None and not rep["errors"]:
        listed = {r["id"] for r in rep["rows"]}
        named = {"R%d-%d" % (rnd, int(k)) for k in
                 re.findall(r"(?<![A-Za-z0-9])R%d[-.]0*(\d+)(?![0-9])" % rnd, fold(lens), re.I)}
        for ident in sorted(named - listed, key=lambda s: int(s.split("-")[1])):
            problems.append("round %d: the rounds row names %s, which %s's findings table does not list" % (rnd, ident, path))
    return problems


if __name__ == "__main__":
    if len(sys.argv) != 3 or not sys.argv[2].isdigit():
        sys.exit("usage: review_report.py <report.md> <round>")
    with open(sys.argv[1], encoding="utf-8") as fh:
        res = parse(fh.read(), int(sys.argv[2]))
    print(json.dumps(res))
    sys.exit(1 if res["errors"] else 0)
