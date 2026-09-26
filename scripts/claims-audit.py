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


_INVENTORY = {}
_GIT = []


def git_tree():
    """Whether ROOT is inside a git work tree (cached)."""
    if not _GIT:
        try:
            _GIT.append(subprocess.run(["git", "-C", ROOT, "rev-parse", "--is-inside-work-tree"], stdout=subprocess.DEVNULL,
                                       stderr=subprocess.DEVNULL, timeout=10, check=False).returncode == 0)
        except Exception:
            _GIT.append(False)
    return _GIT[0]


def inventory_at(rev):
    """len(MUTANTS) of scripts/hand-mutants.py at commit `rev`, or None when `rev` is not a commit HEAD contains or
    has no inventory there (round 30, R30-3: a whole-inventory run is checked against the inventory it ran on)."""
    if rev not in _INVENTORY:
        _INVENTORY[rev] = None
        try:
            ok = subprocess.run(["git", "-C", ROOT, "merge-base", "--is-ancestor", rev, "HEAD"], stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL, timeout=10, check=False).returncode == 0
            r = subprocess.run(["git", "-C", ROOT, "show", rev + ":scripts/hand-mutants.py"], capture_output=True,
                               text=True, timeout=10, check=False) if ok else None
            if r is not None and r.returncode == 0:
                import ast
                _INVENTORY[rev] = next((len(ast.literal_eval(n.value)) for n in ast.parse(r.stdout).body
                                        if isinstance(n, ast.Assign)
                                        and any(getattr(t, "id", "") == "MUTANTS" for t in n.targets)), None)
        except Exception:
            _INVENTORY[rev] = None
    return _INVENTORY[rev]


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


def origin_unlisted():
    """Scripts written FOR THIS PORT that scripts/ORIGIN.md does not name.

    The audit already checks that every script ORIGIN.md names EXISTS. This is the reverse, and the defect
    has been seen twice: round 13's R13-2 found the table naming seven scripts where ten differed, and on
    2026-09-25 the "written for this port" line was missing `review_report.py`, added two rounds earlier. A
    re-copy of the harness guided by that line would silently drop what it omits.

    "Written for this port" has to be computable by a REVIEWER. The line is maintained by comparing against
    ~/.claude/skills/porting-to-bend2/scripts/, which a clean clone does not have, so that definition cannot
    be a gate. This uses the commit that first ADDED the file against the copy commit ORIGIN.md itself names:
    added by the copy commit means a copy from the skill, added by anything else means written here. The copy
    commit is read from the prose rather than hardcoded, so a re-copy moves the sentence and the gate
    together. Fails OPEN on a git failure, as reachable() does."""
    out = []
    origin = read_opt("scripts/ORIGIN.md")
    if not origin:
        return ["scripts/ORIGIN.md is missing or empty: nothing accounts for where the scripts came from"]
    m = re.search(r"commit `([0-9a-f]{7,40})`", origin)
    if not m:
        return ["scripts/ORIGIN.md names no commit the harness was copied in, so which scripts were written "
                "for this port cannot be computed"]
    copy_commit = m.group(1)
    try:
        names = sorted(n for n in os.listdir(os.path.join(ROOT, "scripts"))
                       if n.endswith((".sh", ".py")) and not n.startswith("ORIGIN"))
    except OSError:
        return []
    for name in names:
        try:
            r = subprocess.run(["git", "-C", ROOT, "log", "--diff-filter=A", "--follow", "--format=%h",
                                "--", "scripts/" + name],
                               capture_output=True, text=True, timeout=15, check=False)
            adds = [line for line in r.stdout.split("\n") if line] if r.returncode == 0 else []
        except (OSError, subprocess.SubprocessError):
            return []                      # no git: this check may add findings, never block the audit
        if not adds:
            continue                       # uncommitted: history cannot judge it yet
        first = adds[-1]
        if copy_commit.startswith(first) or first.startswith(copy_commit):
            continue                       # a copy from the skill
        if name not in origin:
            out.append("scripts/ORIGIN.md does not name %s, yet it first appears in %s and not in the copy "
                       "commit %s: a script written for this port must be listed there, or a re-copy of the "
                       "harness will silently drop it" % (name, first, copy_commit))
    return out


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
    # len(MUTANTS), as the inventory's own docstring says to count it: a regex over `("M` missed entries written
    # with single quotes (round 23's M60-M73) and would miss any other spelling of the same Python literal.
    import ast
    inventory = next((ast.literal_eval(n.value) for n in ast.parse(read("scripts/hand-mutants.py")).body
                      if isinstance(n, ast.Assign) and any(getattr(t, "id", "") == "MUTANTS" for t in n.targets)), [])
    f["mutants"] = len(inventory)
    f["mutant_ids"] = {int(e[0][1:]) for e in inventory}   # round 29 (R29-2): a selection is counted against its ids
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
    # after `0x`) must be (a) a commit HEAD contains, or (b) a prefix of a pin recorded in
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
    class Pairs(list):
        """A JSON object as ALL its (key, value) pairs, duplicates kept (R26-2: a dict kept only the last of two
        `commit` keys, so an unreachable commit under the first one was never read)."""
    def drop_digests(node, under_commit=False):
        if isinstance(node, (dict, Pairs)):
            out = []
            for k, v in (node.items() if isinstance(node, dict) else node):
                below = under_commit or bool(commit_key.search(str(k)))
                digest = (not below and digest_key.search(str(k)) and isinstance(v, str)
                          and re.fullmatch(r"[0-9a-fA-F]{12}|[0-9a-fA-F]{16}|[0-9a-fA-F]{64}", v))
                out.append([k, None if digest else drop_digests(v, below)])
                if digest:
                    exempt_values.append(v)
                if digest and len(v) == 64:
                    recorded.add(v.lower())
            return out
        if isinstance(node, list):
            return [drop_digests(v, under_commit) for v in node]
        return node
    # A hex run may also name a digest RECORDED IN FULL elsewhere: a whole 64-digit digest value of any evidence file,
    # or a run of 24 or more digits (never 40, a full commit) in a perf ledger (perf/*.md). In a FILE NAME any such
    # prefix counts (`COUNTED-PROFILE.825e44de.*` names the profiled binary; R23-3's shape M made names readable);
    # in CONTENT only a prefix of 20 or more digits does ("port binary sha256 825e44de69c3a4e6c0d442ea"), far from the
    # 7-16 digits a commit is abbreviated to. Two passes: every file's digests are recorded before any file is judged.
    recorded = {h.lower() for name in sorted(os.listdir(os.path.join(ROOT, "perf"))) if name.endswith(".md")
                for h in re.findall(r"(?<![0-9a-fA-F])[0-9a-fA-F]{24,}(?![0-9a-fA-F])", read(os.path.join("perf", name)))
                if len(h) != 40}
    # Round 24 (R24-2): the RAW text is read, so an unquoted `"commit": 8913e45` (which JSON reads as the number
    # 8.913e48) is still seen; the exempt digest values are blanked in it first. Symlinked subdirectories are
    # followed. A file name's run is certified only by a digest a LEDGER records, never by its own content (a file
    # named `...494ef82.json` carrying a digest that starts 494ef82 certified itself). After `0x` only an address
    # (12 or more digits) is exempt. A maximal run of more than 40 digits is a finding unless it is 64 or 128 long
    # (sha256, sha512): it is neither a commit nor a digest this harness writes.
    ledger = set(recorded)
    hex_run = re.compile(r"(?<![0-9A-Fa-f])[0-9A-Fa-f]{7,}(?![0-9A-Fa-f])")
    uuid = re.compile(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
    evidence_texts = []
    for dirpath, _dirs, names in sorted(os.walk(evdir, followlinks=True)) if os.path.isdir(evdir) else []:
        for name in sorted(names):
            rel = os.path.relpath(os.path.join(dirpath, name), evdir)
            raw = read(os.path.join("perf", "evidence", rel))
            # Round 25 (R25-2): a JSON file is read as its DECODED structure (so `\u` escapes are seen) with every
            # number kept as its source text (so an unquoted hex-shaped number is seen), and only the digest-keyed
            # VALUES are removed from it: blanking a digest's text everywhere in the raw file also erased the same
            # text standing as a commit under a commit key. A file that is not JSON is read raw.
            keep = {"parse_float": lambda x: "#" + x, "parse_int": lambda x: "#" + x, "parse_constant": lambda x: x,
                    "object_pairs_hook": Pairs}
            # Round 27 (R27-2): one unparseable line used to send the WHOLE file to the raw fallback, where an escaped
            # commit (`49...`) is only fragments. Each line is now decoded on its own, and whatever is not
            # JSON is read both raw and with its `\u` escapes decoded.
            docs_, rest = [], []
            try:
                docs_ = [json.loads(raw, **keep)]
            except ValueError:
                for line in raw.splitlines():
                    try:
                        if line.strip():
                            docs_.append(json.loads(line, **keep))
                    except ValueError:
                        rest.append(line)
            exempt_values = []
            text = json.dumps([drop_digests(d) for d in docs_], ensure_ascii=False) if docs_ else ""
            if rest:
                loose = "\n".join(rest)
                text += "\n" + loose + "\n" + re.sub(r"\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1), 16)), loose)
            evidence_texts.append((rel, text))
    for rel, text in evidence_texts:
        for where, body, floor, certs in (("file name's hex run", rel, 7, ledger), ("hex run", uuid.sub(" ", text), 20, recorded)):
            for m in hex_run.finditer(body):
                run = m.group(0)
                low = run.lower()
                # All-digit runs are skipped: they are the counts, sizes and times every evidence file is made of, so a
                # commit abbreviated to digits only is out of reach (said here, not hidden). All-LETTER runs are read:
                # skipping them let `deadbee` through (harness-selftest M22 leaked on its first run, 2026-09-25).
                # A pin is exempt as itself or an abbreviation of it, never as the head of a LONGER run (R25-2:
                # `15ae0c8494ef82` passed as the Bend pin 15ae0c8).
                if low.isdigit() or any(p.startswith(low) for p in pins):
                    continue
                if len(low) > 40:
                    if len(low) not in (64, 128):
                        f.setdefault("counted_unreachable", []).append((rel, "hex run of %d digits" % len(low), run[:48]))
                    continue
                if body[max(0, m.start() - 2):m.start()].lower() == "0x" and len(low) >= 12:
                    continue
                if len(low) >= floor and any(d.startswith(low) for d in certs):
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


def mutant_cmds(span):
    """The `hand-mutants.py` INVOCATIONS in `span`, as the text that follows each one.

    A MENTION IS NOT A COMMAND. The rule that scopes a pasted mutant count by "the ids its own command
    lists" matched any prose naming the script, so a sentence like "a def that `scripts/hand-mutants.py`
    covers" beside a paste made the audit treat it as a WHOLE-INVENTORY run and demand a commit sha -- a
    false finding, reported by the round-30 reviewer as a side effect of their own pointer sentence
    (2026-09-26, R30-3). The discriminator is checked against how these documents actually spell things,
    not guessed: every real invocation carries an interpreter or a path prefix (`python3
    scripts/hand-mutants.py …`, five of them), every prose mention is a bare backticked path, and a
    mention that still LISTS ids stays a command whatever its prefix, because ids are unambiguous. A bare
    mention falls through to the ordinary count check, which is the check it always deserved."""
    return [t for pre, t in re.findall(r"((?:python3\s+|\./)?)(?:scripts/)?hand-mutants\.py([^`\n|]*)", span)
            if pre or re.search(r"\bM\d+\b", t)]


def _sh_string(kind, body):
    """The bytes a single-quoted `echo` or `printf` argument sends to stdin (the two spellings README uses)."""
    if kind == "echo":
        return body + "\n"
    esc = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", "'": "'", '"': '"', "0": "\0"}
    out, i = [], 0
    while i < len(body):
        if body[i] == "\\" and i + 1 < len(body):
            out.append(esc.get(body[i + 1], "\\" + body[i + 1]))
            i += 2
        else:
            out.append(body[i])
            i += 1
    return "".join(out)


# 49v: README's example OUTPUT rested on nothing. Every ratio of the performance section is checked against
# perf/evidence/ and every count against the repository, but the bytes a reader compares with their own
# terminal were checked by no gate -- and the reality check of 2026-09-26 found the decode example printing
# `"id": 1.0` where the port and the original both print `1`: the exact bug the README's own table says was
# FIXED upstream, shown as this port's output. The corpus already covers both examples
# (`happy_readme_users`, `happy_readme_users_decode`), so this is a comparison, not a new capture.
#
# An example is `echo`/`printf` piped into the port inside a ```bash fence, followed immediately by
# `# `-prefixed lines. Those lines are read as a claim about stdout only when at least one of them already
# equals the golden at its own index: a comment block that matches nothing is prose (the Quick Build block's
# "# or, with the original's exact command line ...") and is not an output claim. THE HOLE THAT LEAVES: an
# example rewritten so that NO line survives reads as prose and is skipped. Closing it needs a spelled
# convention in README; the drift this catches is a line or two moving, which is what actually happened.
def readme_examples(text):
    """(line, finding) for every README example whose shown output is not the captured golden."""
    idx = {}
    for row in read_opt("goldens/cases.tsv").splitlines():
        col = row.split("\t")
        if row.startswith("#") or len(col) < 3 or col[2] == "-":
            continue
        try:
            key = (read(col[2]), tuple(json.loads(col[1])))
        except (OSError, ValueError):
            continue  # a partial copy of the port, or a row whose argv is not JSON (cases-lint's finding)
        idx.setdefault(key, col[0])
    out, lines, fence = [], text.splitlines(), False
    for n, line in enumerate(lines, 1):
        if line.startswith("```"):
            fence = line.strip() == "```bash"
            continue
        m = re.match(r"\s*(echo|printf) '([^']*)' \| \./toon\s+--\s+(.*?)\s*$", line) if fence else None
        if not m:
            continue
        claimed = []
        for follow in lines[n:]:
            c = re.match(r"#(?: (.*)|$)", follow)
            if not c:
                break
            body = c.group(1) or ""
            if body.strip() in ("...", "…") or body.startswith("("):
                break  # an elision, or a note about the example: the claim ends here
            claimed.append(body)
        if not claimed:
            continue  # a command shown without its output claims nothing
        case = idx.get((_sh_string(m.group(1), m.group(2)), tuple(m.group(3).split())))
        if case is None:
            out.append((n, "a README example pipes inline input into the port that matches no case of "
                           "goldens/cases.tsv, so the output it shows is checked by nothing"))
            continue
        golden = read_opt("goldens/%s.out" % case).splitlines()
        if not any(c == golden[i] for i, c in enumerate(claimed[:len(golden)])):
            continue  # prose, not an output claim (the hole named above)
        for i, c in enumerate(claimed[:len(golden)]):
            if c != golden[i]:
                out.append((n + 1 + i, "the README example of case %s shows `%s` where goldens/%s.out line %d "
                                       "is `%s`" % (case, c[:60], case, i + 1, golden[i][:60])))
                break
        else:
            if len(claimed) < len(golden):
                out.append((n + len(claimed), "the README example of case %s shows %d lines of the %d in "
                                              "goldens/%s.out and does not mark the elision"
                                              % (case, len(claimed), len(golden), case)))
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
        # R26-5: README says "N are closed instances", which the `closed laws` spelling never matched, so a stale 571
        # stood beside 648 laws with the audit OK.
        ("closed laws", r"\b(\d+) (?:are )?closed (?:laws|instances)\b", f["laws"] - f["laws_quantified"]),
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
        para_cmd = None   # the last hand-mutants.py command of the current paragraph (round 30, R30-3)
        for n, line in enumerate(text.splitlines(), 1):
            if not line.strip():
                para_cmd = None
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
            for name, pat, want in counts:
                if want is None or path in ARCHIVE:
                    continue
                for m in re.finditer(pat, line):
                    said = int(next(g for g in m.groups() if g))
                    # A pasted `"mutants": N` reports ONE run, and what that run covered is stated beside it. Round
                    # 29 (R29-2): "two ids anywhere on the line, N below the inventory" excused a stale whole-run
                    # count with ids in the prose after it, and `hand-mutants.py M118 M119` reporting 117. Each paste
                    # is now judged by the text since the previous paste: the ids its own `hand-mutants.py` command
                    # lists, else a range `M<a> to M<b>` named there (the inventory's ids inside it), else the
                    # whole inventory. The first two must match EXACTLY; the third is the ordinary check below.
                    # Round 30 (R30-3): the command's ids are ALL its `M<n>` arguments (`--all-laws M120 M121`), a
                    # command on an earlier line of the same paragraph (a fenced two-line paste) still scopes the
                    # count, and a WHOLE-inventory run (a command listing no ids) is checked against the inventory at
                    # the commit it names, read from git: a prose range beside a whole run was the writer's word.
                    if name == "mutants in a pasted line":
                        since = line[:m.start()]
                        prior = list(re.finditer(r'"mutants": \d+', since))
                        span = since[prior[-1].end():] if prior else since
                        cmd = mutant_cmds(span)   # a MENTION is not a command: see mutant_cmds (R30-3)
                        if not cmd and not prior and para_cmd is not None:
                            cmd = [para_cmd]
                        rng = re.findall(r"\bM(\d+) to M(\d+)\b", span)
                        scope = None
                        if cmd and re.search(r"\bM\d+\b", cmd[-1]):
                            scope = len(set(re.findall(r"\bM\d+\b", cmd[-1])))
                            what = "the %d ids its hand-mutants.py command lists" % scope
                        elif cmd:
                            # Without git (a copy of the tree, as harness-selftest makes) history cannot be read: like
                            # `reachable`, a git failure adds no finding. With git, an unnamed or unknown commit is one.
                            if not git_tree():
                                continue
                            shas = [s for s in re.findall(r"`([0-9a-f]{7,40})`", span) if inventory_at(s) is not None]
                            if not shas:
                                hit(path, n, "%s: a whole-inventory run (its command lists no ids) says %d and names "
                                    "no commit it ran at; name it (`<sha>`) so its inventory can be read" % (name, said), line)
                                continue
                            scope = inventory_at(shas[-1])
                            what = "the whole inventory at %s (%d mutants)" % (shas[-1], scope)
                        elif rng:
                            lo, hi = int(rng[-1][0]), int(rng[-1][1])
                            scope = sum(1 for k in f["mutant_ids"] if lo <= k <= hi)
                            what = "the %d inventory ids in M%d to M%d" % (scope, lo, hi)
                        if scope is not None:
                            if said != scope:
                                hit(path, n, "%s: says %d for %s" % (name, said, what), line)
                            continue
                    if said == want:
                        continue
                    # Judged on the CLAUSE around this number. The exemption used to cover the whole line, so
                    # appending "earlier" to a line made every count on it unchecked -- and README's headline
                    # row carried "earlier kills stand", which silently exempted its law and mutant counts.
                    if HISTORY.search(clause_of(line, m.start(), m.end())):
                        exempt += 1
                    else:
                        hit(path, n, "%s: says %d, the repository has %d" % (name, said, want), line)
            # The paragraph CARRIER takes invocations only, by the same test: it used the broad pattern, so a
            # prose mention on one table row made the NEXT row's paste inherit it as a whole-inventory command
            # and demand a commit sha. Found by writing exactly that pair into docs/PORT_REPORT.md while
            # recording this repair (2026-09-26), which is why both sites now call one function.
            cmds = mutant_cmds(line)
            if cmds:
                para_cmd = cmds[-1]
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
    # docs/PORT_REPORT.md's FIRST LINE is the report's headline and carries the corpus it was gated on. It
    # went stale by 56 cases (1071 while the pasted lanes line said 1127) and no rule saw it, because the
    # count patterns want "N captured cases" and the headline says "N cases" (2026-09-26, the same
    # phrasing-brittleness as README's "closed instances"). Widening the global pattern to a bare `(\d+)
    # cases` is NOT the fix: about twenty lines across these documents state a case count for a NAMED
    # commit's corpus, which is provenance and legitimately not today's number. So this check reads the
    # headline itself and asks only that the current count appear in it, which cannot go stale by rewording.
    if "docs/PORT_REPORT.md" in files and f.get("cases"):
        first = read("docs/PORT_REPORT.md").split("\n")[0]
        if re.search(r"\(\d[\d,]*\s+cases\)", first) and str(f["cases"]) not in first:
            hit("docs/PORT_REPORT.md", 1,
                "the headline states a corpus of %s, not the %d cases of goldens/cases.tsv"
                % ((re.search(r"\((\d[\d,]*)\s+cases\)", first) or [""])[1], f["cases"]), first)
    # every number of README's performance section must come from perf/evidence/
    readme = read("README.md")
    if "README.md" in files:
        rl = readme.splitlines()
        for n, why in readme_examples(readme):
            hit("README.md", n, why, rl[n - 1] if 0 < n <= len(rl) else "")
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

    # a4's sweep after round 25: a rounds-table row whose round cell is not a bare number (`24b`) was ignored by every
    # rule below, which match `^\| (\d+) \|`. Every row of the Find-fix rounds table must have a numeric round cell.
    state_text = read("docs/PORT_STATE.md")
    sect = re.search(r"(?ms)^## Find-fix rounds\b.*?(?=^## |\Z)", state_text)
    for row in re.findall(r"(?m)^\|[^\n]*\|\s*$", sect.group(0) if sect else ""):
        first = row.strip("|").split("|")[0].strip()
        if first.lower() != "round" and not set(first) <= set("-: ") and not re.fullmatch(r"[1-9]\d*", first):
            findings.append({"file": "docs/PORT_STATE.md", "line": 0, "text": row[:80],
                             "finding": "a rounds-table row whose round cell `%s` is not a number is read by no rule" % first[:20]})
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
                                               rid, int(m.group(3)), m.group(2)):
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
    for problem in origin_unlisted():
        findings.append({"file": "scripts/ORIGIN.md", "line": 0, "text": "", "finding": problem})
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
