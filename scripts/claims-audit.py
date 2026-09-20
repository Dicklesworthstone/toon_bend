#!/usr/bin/env python3
"""claims-audit: the numbers and the cross-references of the claim-bearing documents, checked against the
repository itself. `claims-lint.sh` judges the WORDS (deferrals, unsafe counts without a version); this one
judges the FACTS (including every ratio, median and cv of README's performance section against
`perf/evidence/*.json`), because that is what the non-author review rounds kept finding (rounds 9 to 11: a corpus
size that moved, a round range that stopped at 9, a bead id that had been closed, a pasted probe line with
the row count of an older run).

It computes from the repository: the laws by kind, the cases, the MANIFEST hashes, the spec clauses, the
DISC entries by status, the NE / EXP / OQ ids, the beads and their status, the mutants, the probe rows, and
the ratios of `perf/evidence/*.json`. Then, in every claim-bearing document, it checks

  COUNTS         a sentence that states one of those numbers must state the current one
  REFERENCES     every DISC-, NE-, EXP-, OQ-, bead, law, case, clause, review report and repository path
                 that a document names must exist, the parity board's goldens and laws columns included
  PASTED LINES   a pasted JSON line of a gate (stdio-probe, converge, lanes, law-coverage, parity-board)
                 must agree with what that gate says today

A line that records HISTORY (a commit `abc1234` in backticks, or the words "historical", "used to", "when
written", "earlier", "before") is exempt from the count checks and says so in the summary: history is not a
stale claim. Referring to something that does not exist is never exempt.

usage: python3 scripts/claims-audit.py [--files F...] [--verbose]
exit: 0 no finding, 1 findings, 2 usage. Last stdout line: JSON.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# CURRENT: documents that describe the port as it is now — counts and references are both checked.
CURRENT = ["README.md", "CONTRIBUTING.md", "AGENTS.md", "docs/PORT_STATE.md", "docs/PORT_REPORT.md",
           "docs/PARITY_RUNBOOK.md", "docs/FEATURE_PARITY.md", "docs/DISCREPANCIES.md", "docs/OPEN_QUESTIONS.md",
           "perf/PERF-LEDGER.md", "perf/NEGATIVE-EVIDENCE.md", "perf/EXPERIMENTS.md", "scripts/ORIGIN.md"]
# ARCHIVE: the plan, the architecture and the numeric plan are PINNED records of what was decided, with
# amendment sections; their numbers are the numbers of the day they were written (and ARCH §11 A7 lists law
# names on purpose BECAUSE they do not exist). Only their references to ids and paths are checked.
ARCHIVE = ["docs/PLAN_TO_PORT_Toon_TO_BEND2.md", "docs/PROPOSED_ARCHITECTURE.md", "docs/NUMERIC_PLAN.md"]
DOCS = CURRENT + ARCHIVE
HISTORY = re.compile(r"`[0-9a-f]{7,40}`|\bhistorical\b|\bused to\b|\bwhen (?:written|this was written)\b"
                     r"|\bearlier\b|\b(?:at|after) Phase \d\b|\bthe corpus at\b|\bre-counted\b", re.I)
# paths a document may name although they are not in the repository (build outputs, the gitignored oracle,
# the skills' own scripts, and the placeholders of a command line)
ABSENT_OK = re.compile(r"^(oracle/|legacy/|port/toon|port/[a-z_]+\.(?:c|gpu)$|/tmp/|~/|<|\./x|scripts/<|"
                       r"cases/<|docs/<|perf/<|\.github/workflows/|assets/probes/|scripts/(?:bench-speedup|ledger-row|keep-audit)\.sh)")


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as fh:
        return fh.read()


def read_opt(path):
    """An input a copy of the port may lack (the issue database, the review reports): absent is empty, not a crash."""
    try:
        return read(path)
    except OSError:
        return ""


def facts():
    """Everything the documents may state about themselves, computed from the repository."""
    f = {}
    laws = re.split(r"(?m)^(?=law )", read("port/LAWS.bend"))[1:]
    names = [b.split(":", 1)[0][4:].strip() for b in laws]
    f["law_names"] = set(names)
    f["laws"] = len(names)
    f["laws_quantified"] = sum(1 for b in laws if re.search(r"(?m)^  for ", b.split("\nlaw ")[0]))
    f["laws_golden"] = sum(1 for n in names if n.startswith("golden_"))
    f["laws_closed"] = f["laws"] - f["laws_quantified"] - f["laws_golden"]
    f["proofs"] = len(re.findall(r"(?m)^def Laws\.", read("port/PROOF.bend")))
    rows = [l for l in read("goldens/cases.tsv").splitlines() if l.strip() and not l.startswith("#")]
    f["cases"] = len(rows)
    f["case_names"] = {l.split("\t")[0] for l in rows}
    f["hashes"] = len(re.findall(r"(?m)^  [0-9a-f]{64}  ", read("goldens/MANIFEST.txt")))
    spec = read("docs/EXISTING_Toon_STRUCTURE.md")
    f["clause_ids"] = set(re.findall(r"(?m)^\| (S\d+\.\d+) \|", spec))
    f["clauses"] = len(f["clause_ids"])
    disc = read("docs/DISCREPANCIES.md")
    f["disc_ids"] = set(re.findall(r"(?m)^### (DISC-\d+) ", disc))
    f["disc_accepted"] = len(re.findall(r"(?m)^### DISC-\d+ .*\| ACCEPTED\]$", disc))
    f["disc_resolved"] = len(re.findall(r"(?m)^### DISC-\d+ .*\| RESOLVED\]$", disc))
    f["disc_open"] = len(f["disc_ids"]) - f["disc_accepted"] - f["disc_resolved"]
    f["ne_ids"] = set(re.findall(r"(?m)^### (NE-[A-Z0-9-]+) ", read("perf/NEGATIVE-EVIDENCE.md")))
    f["ne_ids"] |= set(re.findall(r"(?m)^\| (NE-INH-\d+) \|", read("perf/NEGATIVE-EVIDENCE.md")))
    f["exp_ids"] = set(re.findall(r"(?m)^## (EXP-\d+)", read("perf/EXPERIMENTS.md")))
    f["exp_ids"] |= set(re.findall(r"(?m)^\| experiment_id \| (EXP-\d+) \|", read("perf/EXPERIMENTS.md")))
    f["oq_ids"] = set()
    for cell in re.findall(r"(?m)^\| ([^|]+) \|", read("docs/OPEN_QUESTIONS.md")):
        f["oq_ids"].update(re.findall(r"OQ-[A-Z0-9-]+", cell))  # one row may answer two (`OQ-C2 / OQ-E1`)
    f["mutants"] = len(re.findall(r"(?m)^ \(\"M\d+\"", read("scripts/hand-mutants.py")))
    f["probe_rows"] = len(re.findall(r"(?m)^    row\(", read("scripts/stdio-probe.py")))
    beads = {}
    for line in read_opt(".beads/issues.jsonl").splitlines():
        if line.strip():
            try:
                j = json.loads(line)
            except ValueError:
                continue
            if "id" in j:
                beads[j["id"]] = j.get("status", "?")
    f["beads"] = beads
    reviews_dir = os.path.join(ROOT, "docs", "reviews")
    ev = {}
    evdir = os.path.join(ROOT, "perf", "evidence")
    for name in sorted(os.listdir(evdir) if os.path.isdir(evdir) else []):
        if not name.endswith(".json"):
            continue
        try:
            j = json.loads(read(os.path.join("perf", "evidence", name)))
        except ValueError:
            continue
        if isinstance(j, dict) and "port" in j and "original" in j:
            ev[name] = j
    f["evidence"] = ev
    f["ratios"] = {round(j["ratio"], d) for j in ev.values() if j.get("ratio") for d in (2, 3, 4)}
    f["medians"] = {round(j[side]["median_ms"], d) for j in ev.values() for side in ("original", "port") for d in (0, 1)}
    f["cvs"] = {round(j[side]["cv_pct"], d) for j in ev.values() for side in ("original", "port") for d in (0, 1)}
    f["reviews"] = {int(m.group(1)): p for p in sorted(os.listdir(reviews_dir) if os.path.isdir(reviews_dir) else [])
                    for m in [re.match(r"round-(\d+)\.md$", p)] if m}
    state = read("docs/PORT_STATE.md")
    f["round_rows"] = [int(m) for m in re.findall(r"(?m)^\| (\d+) \| ", state)]
    f["round_findings"] = {int(a): int(b) for a, b in re.findall(r"(?m)^\| (\d+) \| .*? \| (\d+) \| \d+ \| (?:yes|no) \|", state)}
    return f


def gate_lines():
    """What the gates that documents paste say TODAY (the ones that run in a second and need no oracle)."""
    out = {}
    for key, cmd in (("law_coverage", ["./scripts/law-coverage.sh"]),
                     ("parity_board", ["./scripts/parity-board.sh", "docs/FEATURE_PARITY.md"]),
                     ("converge", ["./scripts/converge.sh", "docs/PORT_STATE.md"])):
        try:
            r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=120)
            last = (r.stdout.strip().splitlines() or [""])[-1]
            out[key] = json.loads(last) if last.startswith("{") else {}
        except (OSError, ValueError, subprocess.SubprocessError):
            out[key] = {}
    return out


def audit(files, f, gates, verbose):
    findings, absent = [], []
    exempt = 0

    def hit(path, n, what, line):
        findings.append({"file": path, "line": n, "finding": what, "text": line.strip()[:200]})

    # (name, pattern with ONE numeric group, expected)
    counts = [
        ("laws", r"(?<!of )\b(\d+) laws\b", f["laws"]),   # "a reduced proof OF 123 laws" is scoped, not a count of the file
        ("quantified laws", r"\b(\d+) quantified\b", f["laws_quantified"]),
        ("closed unit laws", r"\b(\d+) closed unit laws\b", f["laws_closed"]),
        ("whole-pipeline laws", r"\b(\d+) closed whole-pipeline\b", f["laws_golden"]),
        ("proofs", r'"proofs": (\d+)', f["proofs"]),
        ("laws in a pasted line", r'"laws": (\d+)', f["laws"]),
        ("cases", r"\b(\d+) captured cases\b", f["cases"]),
        ("cases in a pasted line", r'"cases": (\d+)', f["cases"]),
        ("cases in a pasted conform line", r'"passed": ?(\d+), ?"failed": ?0', f["cases"]),
        ("cases in a lane row", r"PASS \((?:passed=)?(\d+) ", f["cases"]),
        ("impact denominator", r"Impact measured: 0 of (\d+) cases", f["cases"]),
        ("MANIFEST hashes", r"MANIFEST[^\n]{0,14}?(\d+) hashes\b|\b(\d+) hashes (?:and capture inputs )?verified", f["hashes"]),
        ("spec clauses", r"\b(\d+) clauses\b", f["clauses"]),
        ("mutants", r"\b(\d+) hand-written (?:semantic )?mutants\b", f["mutants"]),
        ("mutants in a pasted line", r'"mutants": (\d+)', f["mutants"]),
        ("probe rows", r"\b(\d+) descriptor-state rows\b", f["probe_rows"]),
        ("probe rows in a pasted line", r'"rows":\s*(\d+),\s*"same"', f["probe_rows"]),
        ("rounds in a pasted converge line", r'"rounds":\s*(\d+)', gates.get("converge", {}).get("rounds")),
        ("board rows in a pasted line", r'"rows": (\d+), "present"', gates.get("parity_board", {}).get("rows")),
        ("present rows in a pasted line", r'"present": (\d+)', gates.get("parity_board", {}).get("present")),
    ]
    for path in files:
        try:
            text = read(path)
        except OSError:
            absent.append(path)  # a partial copy of the port (the harness self-test makes those): not a finding
            continue
        for n, line in enumerate(text.splitlines(), 1):
            historical = bool(HISTORY.search(line))
            for name, pat, want in counts:
                if want is None or path in ARCHIVE:
                    continue
                for m in re.finditer(pat, line):
                    said = next(g for g in m.groups() if g)
                    if int(said) != want:
                        if historical:
                            exempt += 1
                        else:
                            hit(path, n, "%s: says %s, the repository has %d" % (name, said, want), line)
            # references that must exist
            for ident in re.findall(r"\bDISC-\d+\b", line):
                if ident not in f["disc_ids"]:
                    hit(path, n, "names %s, which is not in the register" % ident, line)
            for ident in re.findall(r"\bNE-[A-Z0-9-]+\b", line):
                if ident not in f["ne_ids"] and not re.fullmatch(r"NE-\d+\.\.\d+", ident):
                    hit(path, n, "names %s, which is not in perf/NEGATIVE-EVIDENCE.md" % ident, line)
            for ident in re.findall(r"\bEXP-\d+\b", line):
                if ident not in f["exp_ids"]:
                    hit(path, n, "names %s, which has no card in perf/EXPERIMENTS.md" % ident, line)
            for ident in re.findall(r"\bOQ-[A-Z]\d*(?:-\d+)?\b", line):
                if ident not in f["oq_ids"]:
                    hit(path, n, "names %s, which is not in docs/OPEN_QUESTIONS.md" % ident, line)
            for ident in re.findall(r"\btoon_bend-[a-z0-9]{3}\b", line):
                if not f["beads"]:
                    continue  # no issue database in this copy of the port
                if ident not in f["beads"]:
                    hit(path, n, "names the bead %s, which does not exist" % ident, line)
                elif f["beads"][ident] == "closed" and re.search(r"bead[s]? [`(]?%s|\(bead" % ident, line):
                    hit(path, n, "names the bead %s as work to do; it is closed" % ident, line)
            for ident in re.findall(r"`(round-\d+\.md)`|docs/reviews/(round-\d+\.md)", line):
                name = ident[0] or ident[1]
                if name not in f["reviews"].values():
                    hit(path, n, "names the review report %s, which does not exist" % name, line)
            for ident in re.findall(r"`(S\d+\.\d+)`", line):
                if ident not in f["clause_ids"]:
                    hit(path, n, "names the clause %s, which is not in the spec" % ident, line)
            for ident in re.findall(r"`(golden_[a-z0-9_]+|[a-z][a-z0-9_]*_is_[a-z0-9_]+|twin_gate_[a-z]+)`", line):
                if path in ARCHIVE:
                    continue
                if ident not in f["law_names"] and ident not in f["case_names"]:
                    hit(path, n, "names the law %s, which is not in port/LAWS.bend" % ident, line)
            for ident in re.findall(r"`((?:scripts|cases|docs|perf|port|bin|goldens)/[A-Za-z0-9_./*-]+)`", line):
                if ABSENT_OK.match(ident) or "*" in ident or ident.endswith("/"):
                    continue
                if not os.path.exists(os.path.join(ROOT, ident)):
                    hit(path, n, "names the path %s, which does not exist" % ident, line)
    # the parity board's own columns: every case it names must be in the corpus, every law in LAWS.bend
    if "docs/FEATURE_PARITY.md" in files:
        board = read("docs/FEATURE_PARITY.md")
        header = None
        for n, line in enumerate(board.splitlines(), 1):
            cells = [c.strip() for c in line.strip().strip("|").split(" | ")] if line.startswith("| ") else None
            if not cells or len(cells) < 7:
                continue
            if cells[0].lower() == "feature":
                header = cells
                continue
            if header is None or set(cells[0]) <= set("-: "):
                continue
            for name in re.split(r"[,\s]+", cells[3]):
                name = name.strip("`")
                if name and name != "-" and name not in f["case_names"]:
                    findings.append({"file": "docs/FEATURE_PARITY.md", "line": n, "text": line.strip()[:160],
                                     "finding": "the goldens column names %s, which is not a case of goldens/cases.tsv" % name})
            for name in re.split(r"[,\s]+", cells[4]):
                name = name.strip("`")
                if name and name not in ("-", "none") and name not in f["law_names"]:
                    findings.append({"file": "docs/FEATURE_PARITY.md", "line": n, "text": line.strip()[:160],
                                     "finding": "the laws column names %s, which is not a law of port/LAWS.bend" % name})

    # every number of README's performance section must come from perf/evidence/
    readme = read("README.md")
    a = readme.find("## Performance")
    b = readme.find("## Design Philosophy", a + 1)
    if a > 0 and b > a and "README.md" in files:
        base = readme[:a].count("\n") + 1
        for i, line in enumerate(readme[a:b].splitlines()):
            if line.lstrip().startswith(("#", ">")) or "perf/evidence" in line:
                continue
            for value, kind, pool in ([(v, "ratio", f["ratios"]) for v in re.findall(r"(\d+\.\d+)×", line)]
                                      + [(v, "median", f["medians"]) for v in re.findall(r"(\d+\.\d+) ms", line)]
                                      + [(v, "cv", f["cvs"]) for v in re.findall(r"cv (\d+\.\d+)%|/ (\d+\.\d+)%", line) for v in [v[0] or v[1]]]):
                if float(value) not in pool:
                    findings.append({"file": "README.md", "line": base + i, "text": line.strip()[:200],
                                     "finding": "the performance section states the %s %s, which is in no file of perf/evidence/" % (kind, value)})

    # the rounds table against the review reports
    for r, path in f["reviews"].items():
        if r not in f["round_findings"]:
            findings.append({"file": "docs/PORT_STATE.md", "line": 0, "text": "",
                             "finding": "docs/reviews/%s exists and the rounds table has no row %d" % (path, r)})
        else:
            rows = len(re.findall(r"(?m)^\| R\d+-", read("docs/reviews/" + path)))
            if rows and rows != f["round_findings"][r]:
                findings.append({"file": "docs/PORT_STATE.md", "line": 0, "text": "",
                                 "finding": "round %d: the table says %d findings, docs/reviews/%s lists %d"
                                            % (r, f["round_findings"][r], path, rows)})
    if verbose:
        for k in sorted(f):
            if k not in ("law_names", "case_names", "clause_ids", "beads", "disc_ids", "ne_ids", "exp_ids", "oq_ids"):
                print("fact  %-22s %s" % (k, f[k]))
    return findings, exempt, absent


def main():
    argv = sys.argv[1:]
    if "-h" in argv or "--help" in argv:
        print(__doc__.strip())
        return 0
    verbose = "--verbose" in argv
    files = DOCS
    if "--files" in argv:
        files = [a for a in argv[argv.index("--files") + 1:] if not a.startswith("--")]
        if not files:
            print(__doc__.strip())
            return 2
    f = facts()
    gates = gate_lines()
    findings, exempt, absent = audit(files, f, gates, verbose)
    for x in findings:
        print("%s:%d: %s" % (x["file"], x["line"], x["finding"]))
        if x["text"]:
            print("    %s" % x["text"])
    print(json.dumps({"files": len(files) - len(absent), "absent": absent, "findings": len(findings), "historical_lines_exempt": exempt,
                      "laws": f["laws"], "cases": f["cases"], "disc": {"accepted": f["disc_accepted"], "resolved": f["disc_resolved"], "open": f["disc_open"]},
                      "verdict": "OK" if not findings else "FINDINGS"}))
    return 0 if not findings else 1


if __name__ == "__main__":
    sys.exit(main())
