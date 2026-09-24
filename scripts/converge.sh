#!/usr/bin/env bash
# converge: compute the parity gate's convergence rule from docs/PORT_STATE.md
# instead of feeling it. Reads the "Find-fix rounds" table (columns found by
# header name: "new genuine findings", "clean"), the tier ("| tier | T1 |" in
# PORT_STATE or --tier), open OQ rows in docs/OPEN_QUESTIONS.md (resolution
# explicitly RESOLVED, EXCLUDED or WITHDRAWN) and unresolved DISC entries.
# Rule (PARITY-GATE): T1 >= 3 rounds and >= 1 clean round; T2 >= 5 and >= 2
# clean since the last reset; T3 >= 10 and the LAST TWO rounds clean; a clean
# round has no reopened finding/counterexample and a finding count under the
# threshold its COUNTING RULE was calibrated for (below). Every round's
# findings must also be fixed.
#
# R21-2 (round 21, MEDIUM). The threshold and the counting rule were changed
# independently, and the pair became unsound.
#   - The method's threshold is "< 3 new genuine findings" (the porting skill,
#     PORT-LOOP "Converge by the tier's rule"). It was calibrated when the
#     count was findings OF ANY KIND, so "< 3" meant a round that turned up
#     almost nothing.
#   - At round 20 the owner adopted a stricter counting rule (PORT_STATE
#     "Owner decisions", 2026-09-23): only NEW BEHAVIOR findings of MEDIUM or
#     HIGH are counted; law-coverage and document findings are listed and
#     repaired but not counted. `scripts/claims-audit.py` already switches on
#     `r >= 20` for exactly this.
# Under the new counting rule the SAME "< 3" admits a round carrying two
# MEDIUM-or-HIGH behaviour defects, and two such rounds in a row satisfy T2 and
# T3. The number got smaller while the threshold consuming it did not, so the
# gate grew more permissive in substance while looking unchanged.
#
# So the threshold is version-matched to the counting rule that produced the
# number: rounds before 20 keep "< 3" (their counts are comparable to what it
# was calibrated for), rounds from 20 on must be ZERO, because every finding
# they still count is a MEDIUM-or-HIGH behaviour defect. This deliberately
# diverges from the skill's single "< 3"; the skill's own text assumes the
# old counting rule, and the two cannot both be applied as written.
#
# A `yes` beside a count over the round's own threshold is a row that
# contradicts itself: it is reported by name, not silently downgraded, so the
# author learns which row disagrees with itself. Independently, an unfixed
# finding (fixed < findings: neither repaired nor registered as a DISC) blocks
# convergence wherever it sits, not only in the last two rounds.
# Every OQ is resolved or excluded; every DISC is accepted, reverted or resolved
# by a fidelity repair with a recorded Resolution and regression evidence. A round
# whose lens is "author" does not count as the required non-author round
# (T2/T3 need at least one non-author round; T1 is warned).
#
# usage: converge.sh [docs/PORT_STATE.md] [--tier T1|T2|T3] [--oq <OPEN_QUESTIONS.md>] [--disc <DISCREPANCIES.md>]   (defaults: beside PORT_STATE)
# exit: 0 CONVERGED, 1 NOT_CONVERGED or malformed, 2 usage. Last stdout line: JSON.
set -uo pipefail
usage() { sed -n '2,/^set -/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { usage; exit 0; }
STATE="docs/PORT_STATE.md"; TIER=""; OQ=""; DISC=""
while [[ $# -gt 0 ]]; do
  case "$1" in --tier|--oq|--disc) [[ $# -ge 2 && -n "$2" ]] || { echo "error: $1 needs a value" >&2; exit 2; };; esac
  case "$1" in
    --tier) TIER="${2:-}"; shift 2;;
    --oq) OQ="${2:-}"; shift 2;;
    --disc) DISC="${2:-}"; shift 2;;
    -*) echo "error: unknown option $1" >&2; exit 2;;
    *) STATE="$1"; shift;;
  esac
done
[[ -f "$STATE" ]] || { echo "error: $STATE not found" >&2; usage >&2; exit 2; }
# the registers live beside PORT_STATE unless named; a missing one is reported, never read as "none open"
: "${OQ:=$(dirname "$STATE")/OPEN_QUESTIONS.md}"; : "${DISC:=$(dirname "$STATE")/DISCREPANCIES.md}"
python3 -B - "$STATE" "$TIER" "$OQ" "$DISC" "$(dirname "$0")" <<'PY'
import json, os, re, sys
sys.path.insert(0, sys.argv[5])
from markdown_evidence import visible_lines, split_row
from case_manifest import regular_text
def cells_of(line): return split_row(line, unescape=True)
state, tier, oq, disc = sys.argv[1:5]
txt = '\n'.join(visible_lines(regular_text(state)))
if not tier:
    m = re.search(r"^\|\s*tier\s*\|\s*(T[123])\s*\|", txt, re.M | re.I)
    tier = m.group(1).upper() if m else ""
tier = tier.upper()
if tier not in ("T1", "T2", "T3"):
    print("error: record a concrete tier T1, T2 or T3, or pass --tier", file=sys.stderr)
    sys.exit(2)
# rounds table
rows, header, malformed = [], None, []
sections = re.findall(r"^## Find-fix rounds\b.*?(?=^## |\Z)", txt, re.M | re.S | re.I)
if len(sections) != 1: malformed.append('missing or ambiguous Find-fix rounds section')
lines = sections[0].split("\n") if len(sections) == 1 else []
for ln in lines:
    if not ln.startswith("|"): continue
    if not ln.rstrip().endswith('|'):
        malformed.append('unterminated round row'); continue
    cells = cells_of(ln)
    if header is None:
        header = [c.lower() for c in cells]; continue
    if set("".join(cells)) <= set("-: "): continue
    if len(cells) != len(header):
        malformed.append('round row has the wrong number of columns'); continue
    rows.append(dict(zip(header, cells)))
def col(row, *names):
    for n in names:
        for k in row:
            if k.rstrip('?').strip() == n: return row[k]
    return ""
# The round from which the owner's stricter counting rule applies (only NEW BEHAVIOR findings of
# MEDIUM or HIGH are counted). scripts/claims-audit.py switches on the same number; keep them equal.
COUNTING_RULE_ROUND = 20
rounds, clean_flags, lenses, round_ids, unfixed = 0, [], [], set(), []
normalized = [k.rstrip('?').strip() for k in header or []]
if not header or len(set(normalized)) != len(header) or not all(n in normalized for n in ('round', 'lens', 'clean')) or sum(k in ('new genuine findings', 'findings') for k in normalized) != 1:
    malformed.append('missing or ambiguous round table header')
reset_findings = {match.group(1) for match in re.finditer(r'^-\s+(F-\d+-\d+)\b[^\n]*(?:RE_OPENED|adversarial counterexample)', txt, re.M | re.I)}
for r in rows:
    if not re.fullmatch(r"[1-9]\d*", col(r, "round")):
        malformed.append('round number must be a positive integer'); continue
    rid = int(col(r, "round"))
    if rid in round_ids:
        malformed.append(f"duplicate round {rid}"); continue
    if round_ids and rid <= max(round_ids): malformed.append(f"round {rid} is out of order")
    round_ids.add(rid)
    rounds += 1
    f = col(r, "new genuine findings", "findings"); m = re.match(r"^(\d+)(?:\s*:|\s*$)", f); n = int(m.group(1)) if m else None
    c = col(r, "clean").lower()
    clean_value = re.fullmatch(r'(yes|no)(?:\s*\([^\n]*\))?', c)
    said_clean = bool(clean_value and clean_value.group(1) == 'yes')
    # R21-2: the threshold is version-matched to the counting rule that produced the number.
    # Rounds from 20 count only MEDIUM/HIGH behaviour findings, so any of them makes the round dirty.
    limit = 1 if rid >= COUNTING_RULE_ROUND else 3
    clean = n is not None and n < limit and said_clean
    if n is None: malformed.append(f"round {rid} has no numeric finding count")
    if not clean_value: malformed.append(f'round {rid} needs an explicit yes/no clean value')
    # A `yes` over the round's own threshold is a row that contradicts itself: say so, do not just downgrade it.
    if said_clean and n is not None and n >= limit:
        malformed.append(f'round {rid} is marked clean but records {n} new genuine finding(s)'
                         + (' (from round %d every counted finding is a MEDIUM-or-HIGH behaviour finding, so a clean round has none)' % COUNTING_RULE_ROUND
                            if rid >= COUNTING_RULE_ROUND else ' (the threshold is under 3)'))
    # `fixed` counts findings repaired OR registered as a DISC; fewer than found means one is still open.
    fx = col(r, "fixed"); fm = re.match(r"^(\d+)(?:\s*:|\s*$)", fx)
    if n is not None and fm and int(fm.group(1)) < n:
        unfixed.append(f'round {rid}: {n - int(fm.group(1))} of {n} finding(s) neither repaired nor registered')
    elif n and not fm: malformed.append(f'round {rid} has no numeric fixed count')
    # R22-1: a non-author round is evidence only through its report. A row with no docs/reviews/round-NN.md beside
    # PORT_STATE is a claim nobody can check: it is malformed and never clean (two fabricated `0 | 0 | yes` rows
    # printed CONVERGED before this). From the counting-rule round, the row's number must also equal the report's
    # own count of MEDIUM/HIGH BEHAVIOR rows, read case-insensitively (R22-2: `Medium | Behavior` escaped the audit).
    if re.search(r"non-author", col(r, "lens"), re.I):
        report = os.path.join(os.path.dirname(os.path.abspath(sys.argv[1])), "reviews", "round-%02d.md" % rid)
        if not os.path.isfile(report):
            malformed.append(f"round {rid} is labelled non-author but has no report {os.path.relpath(report)}")
            clean = False
        elif rid >= COUNTING_RULE_ROUND:
            rep_rows = [m.group(0) for m in re.finditer(r"(?m)^\|\s*\*{0,2}R%d-\d+\b[^\n]*" % rid, regular_text(report))
                        if not re.search(r"not a finding|confirmation only", m.group(0), re.I)]
            # The severity and the class are read from THEIR OWN cells (`| id | sev | class | what | spec |`): a
            # document finding whose prose says "a MEDIUM-or-HIGH behaviour finding" is not a counted finding.
            cells = lambda row: (row.split("|") + ["", "", ""])[2:4]
            counted = sum(1 for sev, cls in map(cells, rep_rows)
                          if re.match(r"\s*\*{0,2}(?:medium|high)\b", sev, re.I) and re.match(r"\s*\*{0,2}behaviou?r\b", cls, re.I))
            if n is not None and counted != n:
                malformed.append(f"round {rid}: the table says {n} counted finding(s), {os.path.relpath(report)} lists {counted}")
                clean = False
    # Reopened findings and adversarial counterexamples reset even a <3 round.
    if re.search(r"\bRE_OPENED\b|\badversarial counterexample\b", " ".join(r.values()), re.I): clean = False
    if reset_findings.intersection(re.findall(r'\bF-\d+-\d+\b', ' '.join(r.values()))): clean = False
    clean_flags.append(bool(clean)); lenses.append(col(r, "lens").lower())
clean_total = sum(clean_flags)
clean_tail = 0
for clean in reversed(clean_flags):
    if not clean: break
    clean_tail += 1
last_two_clean = len(clean_flags) >= 2 and all(clean_flags[-2:])
non_author = any(re.search(r'\(non-author\)\s*$', l) and not re.search(r'\(author\)', l) for l in lenses)
# OQ / DISC
registers_missing = []
open_oq, oq_ids = [], set()
try:
    oq_text = '\n'.join(visible_lines(regular_text(oq)))
    oq_headers, oq_separator = 0, False
    previous_header = False
    for ln in oq_text.splitlines():
        cells = cells_of(ln)
        if cells and [c.lower() for c in cells[:3]] == ['id', 'question', 'spec clause']:
            oq_headers += 1
            previous_header = len(cells) == 6 and cells[4].lower() == 'resolution' and cells[5].lower() == 'date'
            if not previous_header: malformed.append('malformed OQ table header')
            continue
        if previous_header:
            oq_separator = bool(cells and len(cells) == 6 and all(re.fullmatch(r':?-{3,}:?', c) for c in cells))
            if not oq_separator: malformed.append('OQ table needs a delimiter row')
            previous_header = False
        if re.match(r'^\|\s*OQ-', ln):
            # this port's register names questions after the extractor or phase that raised them (OQ-A1, OQ-P3-1),
            # and one row answers two of them (OQ-C2 / OQ-E1)
            if not re.fullmatch(r'OQ-[A-Za-z0-9]+(-[A-Za-z0-9]+)*( / OQ-[A-Za-z0-9]+(-[A-Za-z0-9]+)*)*', cells[0]): malformed.append('malformed OQ identifier')
            if cells[0] in oq_ids: malformed.append(f'duplicate OQ {cells[0]}')
            oq_ids.add(cells[0])
            res = cells[4] if len(cells) > 4 else ""
            closed = re.match(r'^(RESOLVED|EXCLUDED|WITHDRAWN)\b(.*)', res, re.I)
            classified = not closed or closed.group(1).upper() != 'EXCLUDED' or re.search(r'\b(infeasible-numeric|mutation-dependent|exception-dependent|external-dependency|platform|effect|nondeterministic|out-of-scope)\b', closed.group(2), re.I)
            if len(cells) != 6 or not ln.rstrip().endswith('|') or not closed or not closed.group(2).strip(' :()—-\t') or not classified:
                open_oq.append(cells[0])
    if oq_headers != 1 or not oq_separator: malformed.append('missing or ambiguous OQ register table')
except (OSError, UnicodeError, ValueError): registers_missing.append(oq)
open_disc, disc_ids, resolved_ids = [], set(), []
try:
    disc_text = '\n'.join(visible_lines(regular_text(disc)))
    if len(re.findall(r'^## Register\s*$', disc_text, re.M | re.I)) != 1:
        malformed.append('missing or ambiguous DISC Register section')
    for ln in disc_text.splitlines():
        if re.match(r'^#{1,6}\s+DISC-', ln) and not re.match(r'^###\s+DISC-\d+\b', ln):
            malformed.append('malformed DISC heading')
        entry = re.match(r'^#{1,6}\s+(DISC-\d+)\b', ln)
        if entry:
            if entry.group(1) in disc_ids: malformed.append(f'duplicate DISC {entry.group(1)}')
            disc_ids.add(entry.group(1))
        m = re.search(r'\|\s*(ACCEPTED|REVERTED|RESOLVED)\s*\]\s*$', ln, re.I)
        if entry and (not ln.startswith('### ') or not m): open_disc.append(entry.group(1))
        if entry and m and m.group(1).upper() == 'RESOLVED': resolved_ids.append(entry.group(1))
    for identifier in resolved_ids:
        block = re.search(r'^###\s+' + re.escape(identifier) + r'\b[^\n]*(?:\n|\Z)(.*?)(?=^#{1,3}\s|\Z)', disc_text, re.M | re.S)
        resolution = re.search(r'^-[ \t]+Resolution:[ \t]*([^\n]*)', block.group(1), re.M | re.I) if block else None
        value = resolution.group(1).strip(' `\t') if resolution else ''
        if not value or value.startswith('<') or re.fullmatch(r'pending|none|n/a|-', value, re.I):
            open_disc.append(identifier)
except (OSError, UnicodeError, ValueError): registers_missing.append(disc)
need = {"T1": (3, 1), "T2": (5, 2), "T3": (10, 2)}[tier]
missing = list(malformed)
if rounds < need[0]: missing.append(f"rounds {rounds} < {need[0]}")
if tier == "T3":
    if not last_two_clean: missing.append("last two rounds not both clean")
elif clean_tail < need[1]: missing.append(f"clean rounds since last reset {clean_tail} < {need[1]}")
if tier == "T3" and re.search(r"\bNEEDS_REFINEMENT\b", txt): missing.append("hypothesis NEEDS_REFINEMENT remains")
for u in unfixed: missing.append("unfixed finding: " + u)
if open_oq: missing.append("open OQ: " + ", ".join(open_oq))
if open_disc: missing.append("open DISC: " + ", ".join(sorted(set(open_disc))))
for r in registers_missing: missing.append(f"register not found: {r}")
if tier != "T1" and not non_author: missing.append("no non-author round (lens column)")
verdict = "CONVERGED" if not missing else "NOT_CONVERGED"
print(f"tier {tier}: rounds {rounds}, clean {clean_total}, clean tail {clean_tail}, last two clean {last_two_clean}, non-author round {non_author}, open OQ {len(open_oq)}, open DISC {len(open_disc)}")
if tier == "T1" and rounds and not non_author: print("warn: no non-author round recorded (T1 allows it; the example shows why it should not)")
for m in missing: print(f"  missing: {m}")
print(f"convergence: {verdict}")
print(json.dumps({"tier": tier, "rounds": rounds, "clean": clean_total, "clean_tail": clean_tail, "last_two_clean": last_two_clean,
                  "non_author_round": non_author, "open_oq": open_oq, "open_disc": open_disc,
                  "unfixed": unfixed, "verdict": verdict, "missing": missing}))
sys.exit(0 if verdict == "CONVERGED" else 1)
PY
