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
    # How many captures the cv gate REFUSED. A document that states this number was wrong for two review
    # rounds ("ten files" while fifteen carried the verdict) because nothing computed it: the five refusals
    # rounds 12 and 13 added were never counted. The count is over the same two-arm captures as `ratios`.
    f["refused"] = sum(1 for j in ev.values() if j.get("verdict") == "REFUSED_CV")
    # The oracle's sha256 as docs/PIN.toml pins it, so a document's copy can be compared with it.
    pin = read_opt("docs/PIN.toml") or ""
    m = re.search(r"oracle/toon sha256 ([0-9a-f]{64})", pin) or re.search(
        r"(?m)^\s*sha256\s*=\s*\"([0-9a-f]{64})\"", pin)
    f["oracle_sha"] = m.group(1) if m else None
    f["ratios"] = {round(j["ratio"], d) for j in ev.values() if j.get("ratio") for d in (2, 3, 4)}
    f["medians"] = {round(j[side]["median_ms"], d) for j in ev.values() for side in ("original", "port") for d in (0, 1, 2)}
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


JSON_OBJ = re.compile(r'\{"[^\n]*?\}(?=[^"]*$|`| |,|\.|$)')


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
        # `\*{0,2}` because these documents bold a number as **16**, which would otherwise put `**`
        # between the digits and the noun and silently stop the row from ever matching.
        ("REFUSED_CV captures", r"\b(\d+)\*{0,2} files? in `perf/evidence/` carry\b", f["refused"]),
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
            for n, why in rounds_prose(text, f.get("round_findings") or {}):
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
                    # converge.sh is RUN by gate_lines(), so a pasted converge line is compared
                    # field by field with what it says TODAY. Only `rounds` was compared before,
                    # so round 14 (R14-2) flipped a pasted "NOT_CONVERGED" to "CONVERGED" with
                    # "missing": [] and the gate stayed green -- the single worst hole it found,
                    # because that verdict is the one thing standing between HOLD and SHIP.
                    live = gates.get("converge") or {}
                    if live and "tier" in obj and "clean_tail" in obj and "verdict" in obj:
                        for k, want in live.items():
                            if k not in obj or isinstance(want, (list, dict)):
                                continue
                            if obj[k] != want:
                                hit(path, n, "a pasted converge line says %s=%r; converge.sh says "
                                             "%r today" % (k, obj[k], want), line)
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
                    elif live_unsafe is not None and tot != live_unsafe and not historical:
                        hit(path, n, "says unsafe %d; law-coverage.sh says %d today"
                            % (tot, live_unsafe), line)
                # The oracle's sha256 is the one number docs/PIN.toml exists to pin, and nothing
                # compared a document's copy of it with PIN.toml's (R14-2). Deliberately NOT gated
                # on `historical`: the first version was, and a single aside ("this file said so")
                # on a line otherwise full of CURRENT facts exempted the sha with it. An exemption
                # covers a whole line, so a check that matters must not depend on one.
                if f.get("oracle_sha"):
                    for m in re.finditer(r"\b([0-9a-f]{64})\b", line):
                        near = line[max(0, m.start() - 90):m.start()].lower()
                        if "oracle" in near and m.group(1) != f["oracle_sha"]:
                            hit(path, n, "names an oracle sha256 %s…; docs/PIN.toml pins %s…"
                                % (m.group(1)[:12], f["oracle_sha"][:12]), line)
            # `hand-mutants.py M24 M25 M26` runs a SELECTION and reports that many mutants: a line that names
            # the ids it ran is not a stale full-set line. It must still name ids that exist (REFERENCES).
            selective = bool(re.search(r"\bM\d\d\b[^\n]*\bM\d\d\b", line))
            for name, pat, want in counts:
                if want is None or path in ARCHIVE:
                    continue
                if selective and name.startswith("mutants"):
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
            rows = len([m for m in re.finditer(r"(?m)^\| \*{0,2}R\d+-[^\n]*", read("docs/reviews/" + path))
                        if not re.search(r"not a finding|confirmation only", m.group(0), re.I)])
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
