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
  - it has exactly ONE table whose header mentions sev or class in any spelling (round 29), and that table's header
    is exactly `| id | sev | class | what | spec |`; it may have no rows, and no other rendered table lists this
    round's ids in its first column;
  - no table cell contains inline HTML (rounds 27-28) or an invisible format character, Unicode Cf (round 29);
  - every row of that table has an id `R<n>-<k>` of THIS round, a sev HIGH, MEDIUM or LOW, and a class that
    starts BEHAVIOR (or BEHAVIOUR), LAW-COVERAGE or DOCUMENT before round 32, and PORT, HARNESS, CORPUS,
    LAW-COVERAGE or DOCUMENT from round 32 (the owner's decision of 2026-09-26, PORT_RULE_ROUND below);
  - every `R<n>-<k>` of this round named anywhere in the report has a row in that table (a finding written as
    a bullet or in prose only is an error, not an absence).
The counted findings are the rows whose sev is HIGH or MEDIUM and whose class is BEHAVIOR (before round 32) or
PORT (from round 32).

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
LEGACY_CLASSES = CLASSES
# The owner's decision of 2026-09-26 (toon_bend-txp, option 4: "I approve it all"): from this round on, only a
# difference between the port and the pinned original decides convergence. PORT: a stdout, stderr or exit-code
# difference on some lane, or a wrong proof verdict. HARNESS: a gate that misreads. CORPUS: a hand mutant that
# survives the corpus and the proof. HARNESS, CORPUS, LAW-COVERAGE and DOCUMENT findings are recorded and must be
# repaired (the rounds table's `fixed` column), but do not make a round dirty. BEHAVIOR is refused from this round:
# it named both kinds at once. Applied from the first round briefed under the decision, not to earlier rounds.
PORT_RULE_ROUND = 32
PORT_CLASSES = ("PORT", "HARNESS", "CORPUS", "LAW-COVERAGE", "DOCUMENT")
HEADER = ("id", "sev", "class", "what", "spec")   # the findings table's header, as every review brief states it


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


def _tables(tokens, html=None, raw=None):
    """Every rendered table, anywhere (top level, blockquote, list item), as a list of rows of cell texts. `html`, when
    given, collects (table, row) for every row with inline HTML in a cell; `raw`, when given, receives the same tables
    as the cells' SOURCE text (markup not interpreted)."""
    tables, rows, row, rrows, rrow = [], None, None, None, None
    for t in tokens:
        if t.type == "table_open":
            rows, rrows = [], []
        elif t.type == "tr_open":
            row, rrow = [], []
        elif t.type == "inline" and row is not None:
            if html is not None and any(c.type == "html_inline" for c in t.children or []):
                html.add((len(tables), len(rows)))
            row.append(_text(t))
            rrow.append(t.content.strip())
        elif t.type == "tr_close":
            rows.append(row)
            rrows.append(rrow)
            row = rrow = None
        elif t.type == "table_close":
            tables.append(rows)
            if raw is not None:
                raw.append(rrows)
            rows = rrows = None
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
    # Round 26 (R26-1): the RAW text is parsed. Folding (NFKC) before parsing turned fullwidth backticks and pipes
    # into a fence or a table the renderer never shows; folding belongs to the extracted cell text only (`_text`).
    if not text.strip():
        err("the report is empty")
        return out
    tokens = md.parse(text)
    html, raw = set(), []
    tables = _tables(tokens, html, raw)
    # Round 27 (R27-1): `<del>LOW</del> MEDIUM` renders MEDIUM and was read LOW. Round 28 (R28-1): refusing it only in
    # the findings BODY left the header, where `<del>sev</del> | sev` chooses which column is read, and every other
    # table (the reviewed commit's). How a browser renders inline HTML is not decided here: ANY table cell with inline
    # HTML is refused (a placeholder belongs in backticks, which is code, not HTML).
    for n, i in sorted(html):
        err("table %d, row %d: a cell contains inline HTML; write it as text (a placeholder in backticks)" % (n + 1, i + 1))
    for rows in tables:
        for r in rows:
            if len(r) >= 2 and r[0].lower() == "reviewed commit" and not out["commit"]:
                m = re.match(r"([0-9a-fA-F]{7,40})\b", r[1])
                if m:
                    out["commit"] = m.group(1).lower()
    if not out["commit"]:
        err("no `| reviewed commit | <hex> |` header row names the commit this round reviewed")
    # Round 29 (R29-1): the sixth round in a row found a header the reader matched differently from how a page shows
    # it (`Severity:` or `sev` + U+200B beside `sev`). The reader no longer MATCHES headers: the findings header is the
    # brief's fixed contract, exactly `| id | sev | class | what | spec |`. Any table whose header mentions sev or
    # class in ANY spelling is a candidate, there must be exactly one, and it must be exactly that header; and an
    # invisible format character (Unicode Cf: zero-width spaces, joiners, bidi controls) in any table cell is refused.
    for n, rows in enumerate(tables):
        for i, row in enumerate(rows):
            if any(unicodedata.category(ch) == "Cf" for cell in row for ch in cell):
                err("table %d, row %d: a cell contains an invisible format character (Unicode Cf)" % (n + 1, i + 1))
    # Round 30 (R30-2): letters run together (`base vs mutant` -> `basevsmutant`) made honest headers candidates. A
    # header now names sev or class when one of its WORDS starts with `sev` or `class` (`Severity:`, `sev`, `classes`).
    found = [n for n, rows in enumerate(tables) if rows
             and any(re.match(r"sev|class", w) for c in rows[0] for w in re.findall(r"[^\W\d_]+", c.lower()))]
    if len(found) != 1:
        err("%d findings tables (a header naming sev or class); a report has exactly one" % len(found))
        return out
    tn = found[0]
    # The header is compared as SOURCE text: `~~sev~~` or `*sev*` is not the contract, whatever it renders as.
    if [c.lower() for c in raw[tn][0]] != list(HEADER):
        err("the findings header is `| %s |`; it must be exactly `| %s |`"
            % (" | ".join(raw[tn][0])[:120], " | ".join(HEADER)))
        return out
    cols = {name: HEADER.index(name) for name in ("id", "sev", "class")}
    seen = set()
    # The three cells the count rests on are read as SOURCE text too (round 29): an id is bare `R<n>-<k>`, a sev is
    # exactly one bare word, a class starts with a bare class word. No markup there is interpreted, so no new markup
    # shape (strikethrough, emphasis, links, entities, images) can make the gate read one word while a page shows
    # another. Every filed report from round 20 on meets this; its prose columns (`what`, `spec`) stay free.
    for r in raw[tn][1:]:
        ident, sev, cls = (r[cols[k]] if cols[k] < len(r) else "" for k in ("id", "sev", "class"))
        m = re.fullmatch(r"R(\d+)-(\d+)", ident)
        if not m or int(m.group(1)) != rnd:
            err("a findings row whose id `%s` is not a bare R%d-<k>" % (ident[:40], rnd))
            continue
        ident = "R%d-%d" % (rnd, int(m.group(2)))
        if ident in seen:
            err("%s has two rows in the findings table" % ident)
        seen.add(ident)
        sev_word = sev if sev in SEVERITIES else ""
        classes = PORT_CLASSES if rnd >= PORT_RULE_ROUND else LEGACY_CLASSES
        cls_word = (re.match(r"(%s)(?=$| )" % "|".join(classes), cls) or [""])[0]
        if not sev_word:
            err("%s: the sev cell `%s` is not exactly HIGH, MEDIUM or LOW" % (ident, sev[:30]))
        if not cls_word:
            err("%s: the class cell `%s` does not start with a bare %s" % (ident, cls[:30], ", ".join(classes)))
        out["rows"].append({"id": ident, "sev": sev_word, "class": cls_word})
        # Before PORT_RULE_ROUND a HIGH or MEDIUM BEHAVIOR finding counts (the rule of 2026-09-23, under which those
        # rounds were briefed); from it, only a HIGH or MEDIUM PORT finding does (the owner's decision, toon_bend-txp).
        if sev_word in ("HIGH", "MEDIUM") and cls_word in (("PORT",) if rnd >= PORT_RULE_ROUND else ("BEHAVIOR", "BEHAVIOUR")):
            out["counted"] += 1
    # Only the findings table may list this round's findings: another rendered table whose FIRST cell is one of this
    # round's ids (a re-headed copy, R24-1; a copy in a blockquote or a list item, R25-1) is refused.
    for n, rows in enumerate(tables):
        if n != tn:
            for r in rows:
                if r and re.fullmatch(r"R%d[-.]0*\d+" % rnd, r[0], re.I):
                    err("a table other than the findings table lists %s" % r[0])
    # Round 30 (R30-1): ids were looked for in the RENDERED inline text only, so an id in an HTML block, one broken
    # by a zero-width space or a soft hyphen, or one spelled with a Cyrillic `Р` was never "named" while the page
    # showed it. The completeness check now reads the SOURCE (prose, code, HTML blocks and comments alike) with every
    # invisible format character (Unicode Cf) removed, so a hidden id is found rather than missed; and an id-shaped
    # `<letter><round>-<k>` whose letter is not an ASCII R is an error, not an absence. Over-reading source can only
    # demand MORE rows (fail closed): an honest report names its ids in plain text, and its rows hold them.
    # Fenced and indented code blocks are QUOTATION (commands, outputs, the decoys a reviewer planted, which the brief
    # asks them to show): they are left out, as they always were. Everything else in the source is read.
    lines = text.split("\n")
    for t in tokens:
        if t.type in ("fence", "code_block") and t.map:
            for i in range(t.map[0], t.map[1]):
                lines[i] = ""
    scan = fold("".join(ch for ch in "\n".join(lines) if unicodedata.category(ch) != "Cf"))
    named = set()
    for m in re.finditer(r"(?<!\w)([^\W\d_])%d[-.]0*(\d+)(?![0-9])" % rnd, scan):
        if m.group(1) in "Rr":
            named.add("R%d-%d" % (rnd, int(m.group(2))))
        elif not m.group(1).isascii():
            err("`%s` names a round-%d id with the letter U+%04X instead of R" % (m.group(0), rnd, ord(m.group(1))))
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
