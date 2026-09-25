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
  PASTED LINES   a pasted gate line must be internally consistent (lanes, floor, mutants, self-test,
                 clean-build, law-coverage, port-doctor, port-lint, diff-fuzz, stdio-probe), and where the
                 gate runs in a second (converge, law-coverage, parity-board) it must agree with what that
                 gate says TODAY, field by field; verdicts written in prose are held to the same
  SUMMARIES      every prose summary of the rounds table, and every range inside the non-author series,
                 must reach the latest round

HISTORY is judged on the CLAUSE around a number, never on its whole line: a count is exempt only when a
phrase that says it is historical ("at that commit", "earlier", "superseded", "until 2026-…", …) stands in
the same clause. It used to be line-wide, and a line quoting any commit hash was exempt entirely; appending
one word to a false line then silenced every count on it (rounds 14 and 15). Referring to something that
does not exist is never exempt, and neither is the oracle's sha256.

WHAT THIS CANNOT CHECK: a pasted result of a gate too expensive to re-run here (the lanes, the proof,
clean-build-check) is checked for internal consistency only. A line that is consistent but was never
produced -- `clean-build-check` reported as PASS at a commit it never ran on -- passes; only re-running
that gate at that commit refutes it (round 15's L15). Nor is a pass count spelled "N/N" ("PASS 1065/1065")
compared with the corpus: a check for it was built and MEASURED before adoption, and 4 of its 7 flags were
correct historical records at a past corpus size (NE-001..003's "PASS 1053/1053", an OQ run "at `1230a0d`")
that no clause-level marker distinguishes from a stale current claim. Such counts are kept current by hand.

usage: python3 scripts/claims-audit.py [--files F...] [--verbose]
exit: 0 no finding, 1 findings, 2 usage. Last stdout line: JSON.
"""
import json
import math
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import review_report  # noqa: E402  (the one reader of review reports, shared with converge.sh)

_IGNORED = {}
_REACH = {}


def reachable(rev):
    """True when `rev` names a commit that HEAD contains (so a clone of the published branch has it). A git
    failure (no git, not a work tree) answers True: this check may add findings, never remove the ability
    to run the audit."""
    if rev in _REACH:
        return _REACH[rev]
    try:
        r = subprocess.run(["git", "-C", ROOT, "merge-base", "--is-ancestor", rev, "HEAD"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10, check=False)
        ok = r.returncode == 0
        if r.returncode not in (0, 1):
            probe = subprocess.run(["git", "-C", ROOT, "rev-parse", "--is-inside-work-tree"],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10, check=False)
            ok = probe.returncode != 0
        _REACH[rev] = ok
    except Exception:
        _REACH[rev] = True
    return _REACH[rev]


def gitignored(rel):
    """True when a cited path is excluded by .gitignore. Cached; one subprocess per distinct path.
    A git failure (no git, not a work tree) answers False: this check may add findings, never remove
    the ability to run the audit."""
    if rel in _IGNORED:
        return _IGNORED[rel]
    try:
        r = subprocess.run(["git", "-C", ROOT, "check-ignore", "-q", "--", rel],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10, check=False)
        _IGNORED[rel] = (r.returncode == 0)
    except Exception:
        _IGNORED[rel] = False
    return _IGNORED[rel]


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
# A line is exempt only when it SAYS it describes a past state. It used to begin with a bare
# `[0-9a-f]{7,40}` alternative, so ANY line quoting a commit was exempt from every count check --
# and this project's convention puts the compiler checkout `15ae0c8` on every proof line, which
# left docs/PORT_STATE.md's whole law breakdown permanently unchecked. Round 14 (R14-2) rewrote it
# to "7 laws = 1 quantified + ..." and the gate still printed verdict OK. A commit reference is
# NOT a historical marker; a commit reference NEXT TO one of these words is.
HISTORY = re.compile(r"\bhistorical\b|\bused to\b|\bwhen (?:written|this was written)\b"
                     r"|\bearlier\b|\b(?:at|after) Phase \d\b|\bthe corpus at\b|\bre-counted\b"
                     r"|\bsuperseded\b|\buntil 20\d\d-\d\d-\d\d\b|\bthis (?:row|line|file) said\b"
                     r"|\bpreviously\b|\bthe previous table\b|\bwas \d+ until\b"
                     r"|\bat that commit\b|\bas of \d+\b", re.I)
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
    f["quantified_names"] = {n for n, b in zip(names, laws) if re.search(r"(?m)^  for ", b.split("\nlaw ")[0])}
    f["closed_unit_names"] = {n for n in names if n not in f["quantified_names"] and not n.startswith("golden_")}
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
    # harness-selftest.sh names each of its mutations `M<n>_<slug>`. Round 13's R13-3 was one gate pasted
    # into two documents with two numbers (11 and 12); it was repaired by hand and never gated, so it
    # would recur silently the day a thirteenth mutation is added. (`"mutants"` above is hand-mutants.py,
    # a different script: this is `"mutations"`.)
    f["selftest_mutations"] = len(set(re.findall(r"\bM\d+_[a-z_]+", read_opt("scripts/harness-selftest.sh")))) or None
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
    # How many captures the cv gate REFUSED. A document that states this number was wrong for two review
    # rounds ("ten files" while fifteen carried the verdict) because nothing computed it: the five refusals
    # rounds 12 and 13 added were never counted. The count is over the same two-arm captures as `ratios`.
    f["refused"] = sum(1 for j in ev.values() if j.get("verdict") == "REFUSED_CV")
    # The oracle's sha256 as docs/PIN.toml pins it, so a document's copy can be compared with it.
    pin = read_opt("docs/PIN.toml") or ""
    m = re.search(r"oracle/toon sha256 ([0-9a-f]{64})", pin) or re.search(
        r"(?m)^\s*sha256\s*=\s*\"([0-9a-f]{64})\"", pin)
    f["oracle_sha"] = m.group(1) if m else None
    # the pinned Bend version (`version = "2.0.16"` in PIN.toml's bend table)
    m = re.search(r'(?m)^version\s*=\s*"(\d+\.\d+\.\d+)"', pin)
    f["bend_version"] = m.group(1) if m else None
    f["ratios"] = {round(j["ratio"], d) for j in ev.values() if j.get("ratio") for d in (2, 3, 4)}
    # COUNTED evidence (2026-09-23): instruction counts of two binaries on one input (cachegrind), a claim class of
    # its own that no timed capture's fields describe. Its ratio is admitted only when the file carries both counts
    # and the ratio IS their quotient, so a README ratio still has to be computed from counts on disk.
    # Round 23 (R23-3): the reachability rule used to look for commits by SHAPE (a key named like a commit, a string
    # starting with 7-12 hex digits, a file name split on `.`, `-`, `_`), and every round found shapes it did not
    # know (`{"commit": {"id": ...}}`, `built_from`, `v494ef82`, a 13-digit abbreviation, `/scratch/frozen494ef82/`,
    # `.JSON`, `.ndjson`, a subdirectory, the profile's `.annot.txt`). It now fails CLOSED over EVERY file under
    # perf/evidence/, whatever its name: every run of 7 to 40 hex digits (bounded by non-hex, not all digits, not
    # all letters, not after `0x`) must be (a) a commit HEAD contains, or (b) a prefix of a pin recorded in
    # docs/PIN.toml or PLAN §2 (the original's and Bend's commits, which are not in this history), or (c) a digest:
    # the string value of a JSON key named like `sha`, `digest`, `hash`, `md5` or `checksum`, or part of a UUID
    # (the session directories in recorded command lines). Anything else is a finding: a reader cannot check it.
    # Round 19's R19-5 rule and its R20-R22 extensions are subsumed by this one.
    pin_text = read("docs/PIN.toml") + re.split(r"(?m)^## 3\.", re.split(r"(?m)^## 2\.", read("docs/PLAN_TO_PORT_Toon_TO_BEND2.md") + "\n## 2.", maxsplit=1)[1], maxsplit=1)[0]
    pins = {h.lower() for h in re.findall(r"(?<![0-9a-fA-F])[0-9a-fA-F]{7,40}(?![0-9a-fA-F])", pin_text)}
    # A digest is exempt only as a WHOLE value of exactly 12, 16 or 64 hex digits (the widths this harness
    # writes) under a digest-named key with no commit-named key above it: `{"commit": {"hash": "494ef82"}}`
    # stays a commit (R23-3's shape C). What stays out of reach, and is said here rather than hidden: a commit
    # abbreviated to exactly 12 or 16 digits and stored as a digest-named value is indistinguishable from a digest.
    digest_key = re.compile(r"sha|digest|hash|md5|checksum", re.I)
    commit_key = re.compile(r"commit|tree|rev|head|built|from|ref", re.I)
    def drop_digests(node, under_commit=False):
        if isinstance(node, dict):
            out = {}
            for k, v in node.items():
                below = under_commit or bool(commit_key.search(str(k)))
                digest = (not below and digest_key.search(str(k)) and isinstance(v, str)
                          and re.fullmatch(r"[0-9a-fA-F]{12}|[0-9a-fA-F]{16}|[0-9a-fA-F]{64}", v))
                out[k] = None if digest else drop_digests(v, below)
            return out
        if isinstance(node, list):
            return [drop_digests(v, under_commit) for v in node]
        return node
    # A FILE NAME's hex run is read too (R23-3's shape M). Besides a commit or a pin it may be the prefix of a
    # digest a claim-bearing ledger records in full (`COUNTED-PROFILE.825e44de.*` names the profiled binary,
    # whose sha256 perf/COUNTED-PROFILE.md states): a run of 24 or more digits, never 40 (a full commit).
    recorded = {h.lower() for name in sorted(os.listdir(os.path.join(ROOT, "perf"))) if name.endswith(".md")
                for h in re.findall(r"(?<![0-9a-fA-F])[0-9a-fA-F]{24,}(?![0-9a-fA-F])", read(os.path.join("perf", name)))
                if len(h) != 40}
    hex_run = re.compile(r"(?<![0-9A-Fa-f])(?<!0x)(?<!0X)[0-9A-Fa-f]{7,40}(?![0-9A-Fa-f])")
    uuid = re.compile(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
    for dirpath, _dirs, names in sorted(os.walk(evdir)) if os.path.isdir(evdir) else []:
        for name in sorted(names):
            rel = os.path.relpath(os.path.join(dirpath, name), evdir)
            raw = read(os.path.join("perf", "evidence", rel))
            try:
                docs_ = [json.loads(raw)]
            except ValueError:
                try:
                    docs_ = [json.loads(l) for l in raw.splitlines() if l.strip()]
                except ValueError:
                    docs_ = None
            text = json.dumps([drop_digests(d) for d in docs_], ensure_ascii=False) if docs_ else raw
            for where, body in (("file name's hex run", rel), ("hex run", uuid.sub(" ", text))):
                for run in sorted({m.group(0) for m in hex_run.finditer(body)}):
                    low = run.lower()
                    if low.isdigit() or low.isalpha() or any(p.startswith(low) or low.startswith(p) for p in pins):
                        continue
                    if where.startswith("file") and any(d.startswith(low) for d in recorded):
                        continue
                    if not reachable(low):
                        f.setdefault("counted_unreachable", []).append((rel, where, run))
    for name in sorted(os.listdir(evdir) if os.path.isdir(evdir) else []):
        if not (name.lower().startswith("counted") and name.lower().endswith((".json", ".jsonl", ".ndjson"))):
            continue
        raw = read(os.path.join("perf", "evidence", name))
        try:
            docs_ = [json.loads(l) for l in raw.splitlines() if l.strip()] if name.lower().endswith(("l", ".ndjson")) else [json.loads(raw)]
        except ValueError as exc:
            f.setdefault("counted_unparseable", []).append((name, str(exc)))
            continue
        j = docs_[0] if len(docs_) == 1 else None
        try:
            before, after, ratio = j["before"]["instructions"], j["after"]["instructions"], j["ratio"]
        except (KeyError, TypeError):
            continue
        if j.get("kind") == "counted" and after and abs(before / after - ratio) < 1e-9:
            f["ratios"] |= {round(ratio, d) for d in (2, 3, 4)}
    # COUNTED corpus comparisons (2026-09-23): `COUNTED.e2e-corpus.<commit>.json` is a list of cells, each with the port's
    # count and the original's at opt-level z and 3. A cell's ratio is admitted only when it IS the quotient of its counts
    # (to the 2 decimals written), and the geometric means (all cells, encode cells, decode cells, both builds) are
    # admitted only as recomputed from those counts, so a README summary is computed from counts on disk, never typed.
    f["corpus_bad"] = []
    for name in sorted(os.listdir(evdir) if os.path.isdir(evdir) else []):
        if not (name.startswith("COUNTED.e2e-corpus.") and name.endswith(".json")):
            continue
        try:
            cells = json.loads(read(os.path.join("perf", "evidence", name)))
            groups = {}
            for c in cells:
                for key, base in (("ratio_z", "oracle_z"), ("ratio_o3", "oracle_o3")):
                    exact = c["port"] / c[base]
                    if abs(round(exact, 2) - c[key]) > 1e-9:
                        f["corpus_bad"].append("%s: %s %s says %s, the counts give %.4f" % (name, c["doc"], c["mode"], c[key], exact))
                        continue
                    f["ratios"] |= {round(exact, d) for d in (2, 3, 4)}
                    for group in ("all", c["mode"]):
                        groups.setdefault((key, group), []).append(math.log(exact))
            for logs in groups.values():
                f["ratios"] |= {round(math.exp(sum(logs) / len(logs)), d) for d in (2, 3, 4)}
        except (ValueError, KeyError, TypeError, ZeroDivisionError):
            f["corpus_bad"].append("%s: not a list of cells with port, oracle_z, oracle_o3, ratio_z, ratio_o3" % name)
    f["medians"] = {round(j[side]["median_ms"], d) for j in ev.values() for side in ("original", "port") for d in (0, 1, 2)}
    f["cvs"] = {round(j[side]["cv_pct"], d) for j in ev.values() for side in ("original", "port") for d in (0, 1)}
    f["reviews"] = {int(m.group(1)): p for p in sorted(os.listdir(reviews_dir) if os.path.isdir(reviews_dir) else [])
                    for m in [re.match(r"round-(\d+)\.md$", p)] if m}
    state = read("docs/PORT_STATE.md")
    f["round_rows"] = [int(m) for m in re.findall(r"(?m)^\| (\d+) \| ", state)]
    f["round_findings"] = {int(a): int(b) for a, b in re.findall(r"(?m)^\| (\d+) \| .*? \| (\d+) \| \d+ \| (?:yes|no) \|", state)}
    # The first round the table labels "(non-author)". A range that starts at or after it summarises the
    # review series SO FAR and must reach the latest round; one that starts before it (the author rounds,
    # "rounds 1 to 5") is a closed, complete set and is left alone.
    na = [int(a) for a, lens in re.findall(r"(?m)^\| (\d+) \| (.*?) \| \d+ \| \d+ \| (?:yes|no) \|", state)
          if lens.rstrip().endswith("(non-author)")]
    f["first_non_author"] = min(na) if na else None
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


JSON_OBJ = re.compile(r'\{"[^\n]*?\}(?=[^"]*$|`| |,|\.|$)')

# A clause ends at `;`, at `|` (a table cell), at a colon or full stop followed by a space, and at an
# opening or closing parenthesis. The history exemption is judged on the CLAUSE around a number, never on
# its whole line.
CLAUSE_END = re.compile(r";|\||[.:](?=\s|$)|[()]")


def clause_of(line, start, end):
    """The clause of `line` that contains the span [start, end)."""
    lo = 0
    for m in CLAUSE_END.finditer(line, 0, start):
        lo = m.end()
    m = CLAUSE_END.search(line, end)
    return line[lo:(m.start() if m else len(line))]


def pasted_objects(line):
    """Every one-line JSON object pasted in a document line, longest match first."""
    out = []
    for m in re.finditer(r'\{"', line):
        for end in range(len(line), m.start(), -1):
            if line[end - 1] != "}":
                continue
            try:
                obj = json.loads(line[m.start():end])
            except ValueError:
                continue
            if isinstance(obj, dict):
                out.append(obj)
            break
    return out


def inconsistent(o):
    """Is a pasted gate line self-contradictory? Returns a reason or None.

    Round 14 (R14-2) flipped eleven pasted gate lines -- the js lane to "FAIL" with failed 0, the
    floor to "UNSTABLE" with unstable [], the self-test to "caught": 2 against "mutations": 12, the
    mutant tally to "killed": 3 of 25 -- and every one passed, because nothing compared a verdict
    with the numbers beside it. A gate's own output is internally consistent by construction, so a
    pasted line that is NOT is either falsified or mis-transcribed. This needs no gate re-run.
    """
    v = o.get("verdict")
    if "lanes" in o and isinstance(o["lanes"], list) and o["lanes"]:
        for lane in o["lanes"]:
            if not isinstance(lane, dict) or "failed" not in lane:
                continue
            ok = lane.get("failed") == 0 and lane.get("passed", 0) > 0
            if ok != (lane.get("verdict") == "PASS"):
                return 'lane %s says verdict %r with passed %r failed %r' % (
                    lane.get("lane"), lane.get("verdict"), lane.get("passed"), lane.get("failed"))
        allpass = all(l.get("verdict") == "PASS" for l in o["lanes"] if isinstance(l, dict))
        if v is not None and allpass != (v == "PASS"):
            return 'verdict %r with %d lanes that are %s' % (
                v, len(o["lanes"]), "all PASS" if allpass else "not all PASS")
    if "stable" in o and "unstable" in o:
        clean = not o.get("unstable") and not o.get("inconclusive")
        if v is not None and clean != (v == "STABLE"):
            return 'verdict %r with unstable %r and inconclusive %r' % (
                v, o.get("unstable"), o.get("inconclusive"))
    if "mutants" in o and "killed" in o:
        clean = o["killed"] == o["mutants"] and not o.get("survived") and not o.get("not_evidence")
        if v is not None and clean != (v == "STRONG"):
            return 'verdict %r with killed %r of %r, survived %r' % (
                v, o["killed"], o["mutants"], o.get("survived"))
    if "mutations" in o and "caught" in o:
        clean = o["caught"] == o["mutations"] and not o.get("leaked") and not o.get("untestable")
        if v is not None and clean != (v == "OK"):
            return 'verdict %r with caught %r of %r, leaked %r, untestable %r' % (
                v, o["caught"], o["mutations"], o.get("leaked"), o.get("untestable"))
    if "native" in o and "js" in o and isinstance(o.get("conform_c1t"), dict):
        clean = (o["native"] == "built" and o["js"] == "built"
                 and o["conform_c1t"].get("failed") == 0 and o["conform_c1t"].get("passed", 0) > 0)
        if v is not None and clean != (v == "PASS"):
            return 'verdict %r with native %r js %r conform %r' % (
                v, o["native"], o["js"], o["conform_c1t"])
    if "proofs" in o and "laws" in o and "unproved" in o:
        clean = (o["laws"] == o["proofs"] and not o.get("unproved") and not o.get("ghost_proofs")
                 and not o.get("ghost_cited") and not o.get("uncited")
                 and not o.get("duplicate_laws") and not o.get("duplicate_proofs"))
        if v is not None and clean != (v == "OK"):
            return 'verdict %r with laws %r proofs %r unproved %r' % (
                v, o["laws"], o["proofs"], o.get("unproved"))
    if "proof" in o and "lanes" in o and "floor" in o and "switch" in o:
        clean = (o["proof"] == "All terms check." and o["lanes"] == "PASS"
                 and o["floor"] == "STABLE" and o["switch"] == "PASS")
        if v is not None and clean != (v == "GREEN"):
            return 'doctor verdict %r with proof %r lanes %r floor %r switch %r' % (
                v, o["proof"], o["lanes"], o["floor"], o["switch"])
    # port-lint's contract is "0 clean (or only infos)": its verdict is OK when no ERROR and no
    # WARNING is reported, however many infos there are (41 of them here, all PL-02). Keyed on
    # "errors" so it is not confused with claims-audit's own shape below, whose verdict turns on
    # `findings` alone -- the first draft of this rule read port-lint's 41 infos as a contradiction.
    if "errors" in o and "warnings" in o and "infos" in o:
        clean = o["errors"] == 0 and o["warnings"] == 0
        if v is not None and clean != (v == "OK"):
            return 'port-lint verdict %r with errors %r warnings %r' % (v, o["errors"], o["warnings"])
    elif "findings" in o and "verdict" in o and ("absent" in o or "disc" in o):
        if (o["findings"] == 0) != (v == "OK"):
            return 'verdict %r with findings %r' % (v, o["findings"])
    return None


# Prose summaries of the rounds table. Three copies drifted independently in one session (PORT_STATE's
# phase line and open-items row, PORT_REPORT's verdict), each omitting the newest round, and nothing
# computed them. Two phrasings occur, so two patterns:
ROUNDS_SPAN = re.compile(r"rounds?,? (\d+) to (\d+),? (?:[a-z ]{0,30})?found ([\d,\s]+(?:and \d+)?)", re.I)
ROUNDS_BARE = re.compile(r"(\d+(?:, \d+){3,}(?: and \d+)?) findings", re.I)


ROUNDS_ANY = re.compile(r"\brounds?,? (\d+) to (\d+)\b", re.I)


def rounds_series_stale(text, facts, first_na):
    """(line, reason) for any 'rounds A to B' that summarises the non-author series but stops short.

    ROUNDS_SPAN below only sees a range followed by "found <list>", so "rounds 6 to 13 are non-author
    subagents" went stale unseen (round 15, R15-9). This checks EVERY range that starts inside the
    non-author series. A range starting before it ("rounds 1 to 5", the author rounds) is a closed set,
    and a clause that says it is historical is exempt. Measured on the documents before adoption: of the
    ranges that stop short, the author series is the only one this rule must leave alone.
    """
    if not facts or first_na is None:
        return []
    last, out = max(facts), []
    for m in ROUNDS_ANY.finditer(text):
        lo, hi = int(m.group(1)), int(m.group(2))
        if lo < first_na or hi >= last:
            continue
        line_no = text[:m.start()].count("\n") + 1
        line = text.splitlines()[line_no - 1]
        col = m.start() - (text.rfind("\n", 0, m.start()) + 1)
        if HISTORY.search(clause_of(line, col, col + (m.end() - m.start()))):
            continue
        out.append((line_no, "'rounds %d to %d' summarises the review series but stops at %d; the table now "
                             "has %d rounds" % (lo, hi, hi, last)))
    return out


def rounds_prose(text, facts):
    """(line, reason) for every summary of the rounds table that disagrees with the table.

    The subtle case is the reason this exists: a list can be internally CONSISTENT and still stale.
    "rounds 6 to 12 found 6, 11, 8, 3, 10, 12 and 13" was exactly right about rounds 6-12 and simply
    predated round 13, so a list-only comparison passes every one of the three drifted copies. The
    RANGE is what went stale, so the range is checked against the latest round.
    """
    if not facts:
        return []
    out, order, rounds, last = [], [facts[r] for r in sorted(facts)], sorted(facts), max(facts)
    for m in ROUNDS_SPAN.finditer(text):
        lo, hi = int(m.group(1)), int(m.group(2))
        got = [int(x) for x in re.findall(r"\d+", m.group(3))]
        if len(got) < 2:
            continue  # "rounds 9 to 13 found 0 differences" is prose, not a per-round list
        want = [facts[r] for r in range(lo, hi + 1) if r in facts]
        line = text[:m.start()].count("\n") + 1
        if got != want:
            out.append((line, "rounds %d to %d lists %s; the table gives %s" % (lo, hi, got, want)))
        elif hi < last:
            out.append((line, "rounds %d to %d summarises the rounds table but stops at %d; the table "
                              "now has %d rounds (round %d found %d)" % (lo, hi, hi, last, last, facts[last])))
    for m in ROUNDS_BARE.finditer(text):
        got = [int(x) for x in re.findall(r"\d+", m.group(1))]
        line = text[:m.start()].count("\n") + 1
        if got == order[-len(got):]:
            continue
        for end in range(len(order) - 1, len(got) - 1, -1):
            if got == order[end - len(got):end]:
                out.append((line, "a list of %d findings %s matches rounds %d to %d, which are not the "
                                  "latest; the table now ends at round %d (found %d)"
                                  % (len(got), got, rounds[end - len(got)], rounds[end - 1], last, facts[last])))
                break
    seen, uniq = set(), []
    for x in out:  # one stale sentence can trip both patterns: report each line once
        if x[0] not in seen:
            seen.add(x[0])
            uniq.append(x)
    return uniq


CONVERGE_KEYS = {"clean_tail", "last_two_clean", "non_author_round", "open_oq", "open_disc", "tier"}


def live_mismatches(o, f, gates):
    """Reasons a pasted gate object disagrees with that gate's LIVE output or with the repository.

    Round 15 (R15-3) passed a law-coverage line with "unsafe": 9 (only the prose spelling of the unsafe
    count was compared), a converge line that merely omitted `tier` and `clean_tail` (the field-by-field
    comparison required both), a doctor line with "board": "FULL", a floor line with "stable": 999, a
    diff-fuzz line with 3 differences and PASS, and a probe line whose counts did not add up. Each gate
    shape is now recognised by the keys only it prints, and compared with what that gate says today.
    """
    out = []

    def cmp(label, live):
        for k, want in (live or {}).items():
            if k in o and not isinstance(want, (list, dict)) and o[k] != want:
                out.append("a pasted %s line says %s=%r; %s says %r today" % (label, k, o[k], label, want))

    if "verdict" in o and CONVERGE_KEYS & set(o):
        cmp("converge.sh", gates.get("converge"))
    if "proofs" in o and "unproved" in o:
        cmp("law-coverage.sh", gates.get("law_coverage"))
    if "present" in o and "excluded" in o and "rows" in o:
        cmp("parity-board.sh", gates.get("parity_board"))
    if "board" in o and "proof" in o and (gates.get("parity_board") or {}).get("verdict"):
        if o["board"] != gates["parity_board"]["verdict"]:
            out.append("a pasted port-doctor line says board=%r; parity-board.sh says %r today"
                       % (o["board"], gates["parity_board"]["verdict"]))
    # floor: every case is stable, unstable or inconclusive, and there are exactly f["cases"] of them
    if "stable" in o and "unstable" in o and isinstance(o.get("unstable"), list):
        total = o["stable"] + len(o["unstable"]) + len(o.get("inconclusive") or [])
        if total != f["cases"]:
            out.append("a pasted floor line accounts for %d cases; the corpus has %d" % (total, f["cases"]))
    # diff-fuzz: PASS means no difference and nothing too slow
    if "differences" in o and "lens" in o and "verdict" in o:
        clean = o["differences"] == 0 and not o.get("too_slow")
        if clean != (o["verdict"] == "PASS"):
            out.append("a pasted diff-fuzz line says verdict %r with %r differences and %r too slow"
                       % (o["verdict"], o["differences"], o.get("too_slow")))
    # stdio-probe: every row is same, known, fixed or new; PASS means nothing new
    if "rows" in o and "same" in o and isinstance(o.get("known"), list):
        total = o["same"] + len(o["known"]) + len(o.get("fixed") or []) + len(o.get("new") or [])
        if total != o["rows"]:
            out.append("a pasted stdio-probe line has %d rows but same+known+fixed+new = %d" % (o["rows"], total))
        if "verdict" in o and (not o.get("new")) != (o["verdict"] == "PASS"):
            out.append("a pasted stdio-probe line says verdict %r with new %r" % (o["verdict"], o.get("new")))
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
        # Other spellings of the same two numbers. docs/PORT_REPORT.md said "360 closed laws ... 65 unit laws"
        # for two rounds (R14-4, then R15-5) because only the spelling above was ever checked.
        ("closed laws", r"\b(\d+) closed laws\b", f["laws"] - f["laws_quantified"]),
        ("unit laws", r"\b(\d+) unit laws\b", f["laws_closed"]),
        ("mutants in all", r"\b(\d+) mutants in all\b", f["mutants"]),
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
        # `\*{0,2}` because these documents bold a number as **16**, which would otherwise put `**`
        # between the digits and the noun and silently stop the row from ever matching.
        ("REFUSED_CV captures", r"\b(\d+)\*{0,2} files? in `perf/evidence/` carry\b", f["refused"]),
        ("self-test mutations in a pasted line", r'"mutations":\s*(\d+)', f["selftest_mutations"]),
        # a bare "N unsafe" (round 15's L17 appended "of 7 unsafe" and nothing objected); measured before
        # adoption: its only occurrence in the documents was a true "0 unsafe"
        ("unsafe count", r"\b(\d+) unsafe\b", (gates.get("law_coverage") or {}).get("unsafe")),
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
        if path not in ARCHIVE:
            lines = text.splitlines()
            rf = f.get("round_findings") or {}
            seen_lines = set()
            for n, why in rounds_prose(text, rf) + rounds_series_stale(text, rf, f.get("first_non_author")):
                if n in seen_lines:
                    continue  # one stale sentence, one finding
                seen_lines.add(n)
                hit(path, n, why, lines[n - 1] if 0 < n <= len(lines) else "")
        for n, line in enumerate(text.splitlines(), 1):
            historical = bool(HISTORY.search(line))
            # A pasted gate line is internally consistent by construction, so one that contradicts
            # itself is falsified or mis-transcribed. Checked even on a historical line: a gate's
            # output was self-consistent on the day it ran too.
            if path not in ARCHIVE:
                for obj in pasted_objects(line):
                    why = inconsistent(obj)
                    if why:
                        hit(path, n, "a pasted gate line contradicts itself: %s" % why, line)
                    # Compared with each gate's LIVE output, not only with itself. A pasted converge
                    # line reading "CONVERGED" is the one string between HOLD and SHIP, so this is the
                    # check that matters most (R14-2's worst hole; R15-3 found it could be dodged by
                    # leaving out two keys, which no longer helps).
                    for why in live_mismatches(obj, f, gates):
                        hit(path, n, why, line)
                # "unsafe 0 = 0 @unsafe + 0 template instances" must add up AND match the live
                # law-coverage number. Round 14 rewrote a proof row to "unsafe 7 = 7 @unsafe" and
                # nothing objected; the unsafe count is stated beside every parity claim, so it is
                # exactly the number a reader trusts without re-running the proof.
                live_unsafe = (gates.get("law_coverage") or {}).get("unsafe")
                for m in re.finditer(r"unsafe (\d+) = (\d+) `?@unsafe`? \+ (\d+) template instances", line):
                    tot, expl, inst = (int(x) for x in m.groups())
                    if tot != expl + inst:
                        hit(path, n, "unsafe %d does not equal %d @unsafe + %d template instances"
                            % (tot, expl, inst), line)
                    elif (live_unsafe is not None and tot != live_unsafe
                          and not HISTORY.search(clause_of(line, m.start(), m.end()))):
                        hit(path, n, "says unsafe %d; law-coverage.sh says %d today"
                            % (tot, live_unsafe), line)
                # Verdicts written in PROSE (R15-3 (e)): the converge verdict, and the report's own title.
                # A pasted JSON verdict was checked; the same verdict written as words was not, so
                # "`converge.sh`: `CONVERGED`" and a title of SHIP both passed.
                live_cv = (gates.get("converge") or {}).get("verdict")
                if live_cv:
                    for m in re.finditer(r"`converge\.sh`[^`\n]{0,40}`(NOT_CONVERGED|CONVERGED)`", line):
                        if m.group(1) != live_cv and not HISTORY.search(clause_of(line, m.start(), m.end())):
                            hit(path, n, "says converge.sh gives %s; it gives %s today" % (m.group(1), live_cv), line)
                    if path == "docs/PORT_REPORT.md" and n == 1 and live_cv != "CONVERGED" and re.search(r"\bSHIP\b", line):
                        hit(path, n, "the report's title says SHIP while converge.sh says %s" % live_cv, line)
                # parity-board's own key=value spelling (R15-3 (f)): only its JSON spelling was compared
                live_pb = gates.get("parity_board") or {}
                for m in re.finditer(r"rows=(\d+) present=(\d+) partial=(\d+) missing=(\d+) excluded=(\d+)"
                                     r" n/a=(\d+) no-evidence=(\d+) verdict=([A-Z]+)", line):
                    said = dict(zip(("rows", "present", "partial", "missing", "excluded", "na", "no_evidence"),
                                    (int(x) for x in m.groups()[:7])), verdict=m.group(8))
                    for k, v in said.items():
                        if k in live_pb and live_pb[k] != v:
                            hit(path, n, "a pasted parity-board line says %s=%r; parity-board.sh says %r today"
                                % (k, v, live_pb[k]), line)
                # the Bend version beside a verdict must be the pinned one
                if f.get("bend_version"):
                    for m in re.finditer(r"\bbend (\d+\.\d+\.\d+)\b", line):
                        if (m.group(1) != f["bend_version"]
                                and not HISTORY.search(clause_of(line, m.start(), m.end()))):
                            hit(path, n, "names bend %s; docs/PIN.toml pins %s" % (m.group(1), f["bend_version"]), line)
            # The oracle's sha256 is the one number docs/PIN.toml exists to pin. Checked in EVERY document,
            # ARCHIVE included (R15-3 (g): PLAN §2's copy was skipped as archival, although a pinned hash
            # does not age), on either side of the word "oracle", and never exempted as history: a single
            # aside on a line otherwise full of current facts once exempted the sha along with it.
            # A hash is taken to BE the oracle's only when the sentence binds the two within one clause:
            # "oracle/toon … sha256 `X`", or `X` followed closely by "the oracle". Mere proximity is not
            # enough: PLAN §2 names the opt-level=3 build's sha right after the aside "(like `oracle/toon`)",
            # and a ±90-character window read that as a false oracle hash.
            if f.get("oracle_sha"):
                for m in re.finditer(r"\b([0-9a-f]{64})\b", line):
                    before = line[max(0, m.start() - 90):m.start()]
                    after = line[m.end():m.end() + 50]
                    bound = (re.search(r"oracle(?:/toon)?`?[^;.|]{0,60}sha256(?:\s+is)?\W{0,3}$", before, re.I)
                             or re.search(r"^\W{0,3}[^;.|]{0,30}\boracle\b", after, re.I))
                    if bound and m.group(1) != f["oracle_sha"]:
                        hit(path, n, "names an oracle sha256 %s…; docs/PIN.toml pins %s…"
                            % (m.group(1)[:12], f["oracle_sha"][:12]), line)
            # `hand-mutants.py M24 M25 M26` runs a SELECTION and reports that many mutants: a line that names
            # the ids it ran is not a stale full-set line. It must still name ids that exist (REFERENCES).
            selective = bool(re.search(r"\bM\d\d\b[^\n]*\bM\d\d\b", line))
            for name, pat, want in counts:
                if want is None or path in ARCHIVE:
                    continue
                for m in re.finditer(pat, line):
                    said = int(next(g for g in m.groups() if g))
                    if said == want:
                        continue
                    # A line that names mutant ids reports a SELECTION, which may be smaller than the set but
                    # never larger. This used to skip every mutant count on such a line, so round 15 wrote
                    # `"mutants": 99` beside two ids and nothing objected.
                    if selective and name.startswith("mutants") and said < want:
                        continue
                    # Judged on the CLAUSE around this number. The exemption used to cover the whole line, so
                    # appending "earlier" to a line made every count on it unchecked -- and README's headline
                    # row carried "earlier kills stand", which silently exempted its law and mutant counts.
                    if HISTORY.search(clause_of(line, m.start(), m.end())):
                        exempt += 1
                    else:
                        hit(path, n, "%s: says %d, the repository has %d" % (name, said, want), line)
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
                elif gitignored(ident):
                    # The existence check above reads the WORKING TREE, so a citation of a gitignored
                    # file passes for whoever fetched it and fails only on a clean clone. Observed
                    # 2026-09-23: five citations of documents under the gitignored perf/e2e/corpus/
                    # sat in the ledger through a whole session of `0 findings`, and were caught by a
                    # reviewer whose tree lacked them, not by this gate. ABSENT_OK still exempts the
                    # paths a copy of the port is MEANT to lack (oracle/, legacy/, build outputs).
                    hit(path, n, "names the path %s, which is gitignored: it exists here but not in a "
                                 "clean clone, so this citation cannot be checked by a reviewer" % ident, line)
            # A gate line's tree must be one a reader can check out: reachable from HEAD. Round 18 (R18-D1)
            # found the lanes and proof rows citing `494ef82` and `9eb07dc`, commits of the author's scratch
            # clone that a rebase replaced before the push; they resolved in that clone (its object store
            # kept them), so an existence test would have passed. Only "tree of" citations are held to this:
            # other hashes in the documents name the original's history (toon_rust) or binaries.
            for ident in re.findall(r"tree of (?:commit )?`([0-9a-f]{7,40})`", line):
                if not reachable(ident):
                    hit(path, n, "cites the tree of %s, which is not reachable from HEAD: a reader of this "
                                 "repository cannot check that tree out" % ident, line)
    # The board's proof-coverage table splits the closed unit laws over two rows. Round 14 (R14-4) found the
    # split six short, it was repaired by hand -- and the very next law added drifted it again, nine short,
    # because the gate's `(\d+) closed unit laws` never matches `| other closed unit laws | N |`. Both rows
    # are now checked: each stated count equals the names it lists, and every closed unit law is on one.
    if "docs/FEATURE_PARITY.md" in files and f.get("closed_unit_names"):
        board_lines = read("docs/FEATURE_PARITY.md").splitlines()
        cited = set()
        for n, l in enumerate(board_lines, 1):
            m = re.match(r"^\| (laws about the fast twins|other closed unit laws)\b[^|]*\| (\d+) \|([^|]*)\|", l)
            if not m:
                continue
            names_here = re.findall(r"`([a-z0-9_]+)`", m.group(3))
            if int(m.group(2)) != len(names_here):
                hit("docs/FEATURE_PARITY.md", n, "the row '%s' says %s laws and lists %d"
                    % (m.group(1), m.group(2), len(names_here)), l)
            cited.update(names_here)
        if cited:
            missing = sorted(f["closed_unit_names"] - cited)
            if missing:
                findings.append({"file": "docs/FEATURE_PARITY.md", "line": 0, "text": "",
                                 "finding": "%d closed unit law(s) of port/LAWS.bend on neither proof-coverage row: %s"
                                            % (len(missing), ", ".join(missing[:6]) + (" …" if len(missing) > 6 else ""))})
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

    for name, side, rev in f.get("counted_unreachable", []):
        findings.append({"file": "perf/evidence/" + name, "line": 0, "text": "",
                         "finding": "the %s %s is not a commit HEAD contains, a pin of docs/PIN.toml or PLAN §2, or a digest: a reader cannot check it"
                                    % (side, rev)})
    # R21-3(c): an unreadable evidence file is a finding, not a skip. Silently passing over it hid every
    # commit inside it, and a file that cannot be parsed cannot support the claim that cites it.
    for name, why in f.get("counted_unparseable", []):
        findings.append({"file": "perf/evidence/" + name, "line": 0, "text": "",
                         "finding": "COUNTED evidence that is not parseable JSON (%s): nothing in it can support a claim, "
                                    "and any commit it names goes unchecked" % why})
    for bad in f.get("corpus_bad", []):
        findings.append({"file": "perf/evidence/" + bad.split(":")[0], "line": 0, "text": "",
                         "finding": "a corpus cell's ratio is not the quotient of its counts: " + bad})
    # every number of README's performance section must come from perf/evidence/
    readme = read("README.md")
    a = readme.find("## Performance")
    b = readme.find("## Design Philosophy", a + 1)
    if a > 0 and b > a and "README.md" in files:
        base = readme[:a].count("\n") + 1
        for i, line in enumerate(readme[a:b].splitlines()):
            if line.lstrip().startswith(("#", ">")):
                continue
            # Integers count too: round 13 (R13-6) falsified a whole row to `9999 ms | 111 ms` and this gate
            # stayed green, because every pattern here demanded a decimal point. Naming a file under
            # perf/evidence/ is likewise no longer an exemption from having the numbers on the line checked.
            for value, kind, pool in ([(v, "ratio", f["ratios"]) for v in re.findall(r"(\d+(?:\.\d+)?)×", line)]
                                      + [(v, "median", f["medians"]) for v in re.findall(r"(\d+(?:\.\d+)?) ms", line)]
                                      + [(v, "cv", f["cvs"]) for v in re.findall(r"cv (\d+(?:\.\d+)?)%|/ (\d+(?:\.\d+)?)%", line) for v in [v[0] or v[1]]]):
                if float(value) not in pool:
                    findings.append({"file": "README.md", "line": base + i, "text": line.strip()[:200],
                                     "finding": "the performance section states the %s %s, which is in no file of perf/evidence/" % (kind, value)})

    # the rounds table against the review reports
    # R22-1: the other direction. A row the table labels non-author is evidence only through its report; a row with no
    # docs/reviews/round-NN.md (two fabricated `0 | 0 | yes` rows made converge.sh print CONVERGED) is a finding.
    # R23-1, R23-2: from the counting-rule round EVERY row is checked by scripts/review_report.py, the reader
    # converge.sh uses too (one reader, so a repair cannot reach one gate and miss the other): the report must
    # exist, parse completely (any layout it cannot read is an error, never zero findings), name a reviewed
    # commit HEAD contains, and count what the table says. Before round 20 the lens decides, folded (NFKC and
    # every dash to `-`) so a U+2011 spelling of "non-author" is still read as one.
    for m in re.finditer(r"(?m)^\| (\d+) \| (.*?) \| (\d+) \| \d+ \| (?:yes|no) \|", read("docs/PORT_STATE.md")):
        rid = int(m.group(1))
        if rid >= 20:
            for problem in review_report.check(ROOT, os.path.join(ROOT, "docs", "reviews", "round-%02d.md" % rid),
                                               rid, int(m.group(3))):
                findings.append({"file": "docs/PORT_STATE.md", "line": 0, "text": "",
                                 "finding": problem.replace(ROOT + os.sep, "")})
        elif review_report.is_non_author(m.group(2)) and rid not in f["reviews"]:
            findings.append({"file": "docs/PORT_STATE.md", "line": 0, "text": "",
                             "finding": "round %d is labelled non-author in the rounds table but docs/reviews/round-%02d.md does not exist"
                                        % (rid, rid)})
    for r, path in f["reviews"].items():
        if r not in f["round_findings"]:
            findings.append({"file": "docs/PORT_STATE.md", "line": 0, "text": "",
                             "finding": "docs/reviews/%s exists and the rounds table has no row %d" % (path, r)})
        else:
            # A report bolds its HIGH and MEDIUM rows (`| **R12-1** |`): count those too, or a round
            # with two MEDIUM findings reads as two findings short (round 12, found by this gate).
            # A row a report explicitly marks as NOT a finding is not counted. Round 14 recorded
            # R14-16 as "(not a finding: confirmation)" -- a DISC it re-verified as accurately
            # registered, filed under an id so the next round does not re-raise it. Counting it
            # would force the rounds table to overstate the round by one.
            # Only THIS round's own ids (`R15-n` in round-15.md). A report's "claims that held" table cites
            # earlier rounds' ids too -- round 15 has a row "| R14-3, R14-9, R14-13 repairs |" -- and the
            # counter used to match any `R<n>-`, so it read that row as a fifteenth-round finding.
            report_rows = [m.group(0) for m in re.finditer(r"(?m)^\| \*{0,2}R%d-\d+\b[^\n]*" % r, read("docs/reviews/" + path))
                           if not re.search(r"not a finding|confirmation only", m.group(0), re.I)]
            rows = len(report_rows)
            # From round 20 the count is review_report.check's (above); this reader serves the earlier rounds only.
            if r < 20 and rows and rows != f["round_findings"][r]:
                findings.append({"file": "docs/PORT_STATE.md", "line": 0, "text": "",
                                 "finding": "round %d: the table says %d findings, docs/reviews/%s lists %d"
                                            % (r, f["round_findings"][r], path, rows)})
            # A round whose own report calls itself non-author must be LABELLED non-author in the table:
            # converge.sh needs a non-author round for T2, so relabelling one either way changes what the
            # tier computes (round 15's L16 relabelled round 14 as an author round and nothing objected).
            head = read("docs/reviews/" + path).split("\n", 3)[:3]
            says_na = any(review_report.is_non_author(h) for h in head)
            m = re.search(r"(?m)^\| %d \| (.*?) \| \d+ \| \d+ \| (?:yes|no) \|" % r, read("docs/PORT_STATE.md"))
            # BOTH ends of the lens must say so. The first version checked only the terminal marker, and
            # round 15's L16 rewrote the lens to begin "author:" while leaving "(non-author)" at its end --
            # a row that contradicts itself, which that version passed. In this table rounds 1-5 begin
            # "author:" with no marker and every non-author round begins "non-author" and ends with one.
            lens = m.group(1) if m else ""
            lens = review_report.fold(lens)
            if says_na and m and not (lens.lstrip().lower().startswith("non-author")
                                      and lens.rstrip().endswith("(non-author)")):
                findings.append({"file": "docs/PORT_STATE.md", "line": 0, "text": "",
                                 "finding": "round %d: docs/reviews/%s calls itself non-author, but its table row "
                                            "does not both begin 'non-author' and end '(non-author)'" % (r, path)})
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
