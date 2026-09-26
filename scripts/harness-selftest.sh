#!/usr/bin/env bash
# harness-selftest: mutation-test the port's own gates. Copies the port
# (docs, goldens, port, perf, scripts; legacy/ is linked, never copied) into
# a scratch directory, applies ONE deliberate lie per copy, and requires the
# gate that must catch it to go red. A gate that stays green under a lie is
# the finding (LEAK). Before mutating, every gate is run once on a clean
# copy: a gate that is already red cannot be tested (UNTESTABLE), so a broken
# baseline never inflates the result. Nothing in the real port is touched;
# the scratch copies stay under $TMPDIR (the JSON names the directory) so a
# LEAK can be inspected. Mutations and the gate that must catch each:
#   M1  one byte of a golden .out flipped                -> conform.sh FAIL (exit 1)
#   M2  a case's .err golden moved aside                 -> conform.sh FAIL (a missing golden is FAIL, not skip)
#   M3  cases.tsv reduced to a comment                   -> conform.sh FAIL (zero-test green refused)
#   M4  a case renamed in cases.tsv                      -> conform.sh FAIL (no golden under the new name)
#   M5  the ORIGINAL run as the port (oracle-on-oracle)  -> conform.sh refused (exit 2); needs -- <original cmd>
#   M6  a law's proof removed from PROOF.bend            -> law-coverage.sh RED (exit 1)
#   M7  a law removed from LAWS.bend, its proof kept     -> law-coverage.sh RED (proof of no law)
#   M8  "we should revisit later" appended to the NE ledger -> claims-lint.sh hit (exit 1)
#   M9  an intention sentence appended to PORT_STATE     -> state-check.sh finding (exit 1)
#   M10 a `present` board row with no golden and no law  -> parity-board.sh MALFORMED (exit 1)
#   M11 a re-capture without --repin/--disc              -> golden-capture.sh refused (exit 3); needs -- <original cmd>
#   M12 a case added, the documents' counts left behind  -> claims-audit.py FINDINGS (exit 1)
#   M13 one more REFUSED_CV capture, the count left behind -> claims-audit.py FINDINGS (exit 1)
#   M14 a post-20 round with counted findings marked clean -> converge.sh names the contradiction (R21-2)
#   M15 a round whose `fixed` is under its finding count   -> converge.sh names the unfixed finding (R21-2)
#   M16 a COUNTED file citing an unreachable commit under "tree" -> claims-audit.py FINDINGS (R21-3)
#   M17 a COUNTED file that is not parseable JSON          -> claims-audit.py FINDINGS (R21-3)
#   M18 a non-author round with no review report          -> converge.sh names it (R22-1)
#   M19 a round's counted rows re-spelled `Medium | Behaviour` -> converge.sh names the count (R22-2)
#   M20 the same re-spelled report                         -> claims-audit.py FINDINGS (R22-2, R23-2)
#   M21 a round's report present but empty                 -> converge.sh names it (R23-1)
#   M22 an unreachable commit in any file under perf/evidence -> claims-audit.py names the file (R23-3)
#   M23 the findings table hidden in an HTML comment, the visible copy re-headed -> converge.sh (R24-1)
#   M24 an unreachable commit under a SYMLINKED subdirectory of perf/evidence -> claims-audit.py (R24-2)
#   M25 the findings table in a BLOCKQUOTE, a decoy at top level with sev/class downgraded -> converge.sh
#   M26 a finding named in the rounds row's PROSE with no row in that round's table -> converge.sh
#   M27 a report on disk whose round has no row in the rounds table         -> converge.sh
#   M28 a rounds-table row whose round cell is not a number (`24b`)         -> claims-audit.py
#   M29 an unreachable commit hidden from a raw scan by `\u` escapes        -> claims-audit.py (R25-2)
#   M30 an ACCEPTED DISC that lost its `Approver:` line                     -> converge.sh
#   M31 a findings table behind a FULLWIDTH fence, with a fullwidth decoy    -> converge.sh (R26-1)
#   M32 an unreachable commit hidden behind a DUPLICATE `commit` key         -> claims-audit.py (R26-2)
#   M33 a wrong closed-law count in README's own phrasing                    -> claims-audit.py (R26-5)
#   M34 inline HTML strikethrough in a sev cell                             -> converge.sh (R27-1)
#   M35 an escaped commit in a JSONL file with one unparseable line         -> claims-audit.py (R27-2)
#   M36 a mutant count OVERSTATED beside three-digit ids                    -> claims-audit.py
#   M37 inline HTML in a findings-table HEADER cell                         -> converge.sh (R28-1)
#   M38 a findings table with two `sev` columns, no HTML                    -> converge.sh (R28-1)
#   M39 a mutant PROSE total beside two ids, below the inventory            -> claims-audit.py (R28-2)
#   M40 a `Severity:` findings header                                       -> converge.sh (R29-1)
#   M41 an invisible Cf character in a findings BODY cell                   -> converge.sh (R29-1)
#   M42 a pasted mutant count disagreeing with its command's ids            -> claims-audit.py (R29-2)
#   M43 a pasted mutant count disagreeing with its stated range             -> claims-audit.py (R29-2)
# and one CONTROL, counted on its own axis, never as a mutation:
#   C1  a hidden excerpt with a DIFFERENT count while the visible table stays correct -> every gate SILENT
# M14, M15, M18, M19, M21, M23 and M25 assert on converge.sh's MESSAGE, not its exit code: the gate is
# legitimately NOT_CONVERGED on the clean tree, so an exit-code mutation test
# would report UNTESTABLE and prove nothing. Each requires its phrase to be
# ABSENT on the clean copy and PRESENT after the mutation, so a phrase that was
# already there cannot pass the test for it.
# The port under test is the native binary built once from port/main.bend
# (--lane c-1t, the default) or the interpreter through scripts/interp-lane.sh
# (--lane interpreter). PARITY-GATE "Anti-gaming" lists what these lies are.
#
# usage: harness-selftest.sh [--root DIR] [--lane c-1t|interpreter] [-- <original cmd...>]
#        harness-selftest.sh --regressions  # portable harness regressions; no Bend build
# exit: 0 every mutation caught, 1 any LEAK or UNTESTABLE gate, 2 usage or build failure.
# Last stdout line: {"schema":"p2b.harness-selftest.v1","sha","bend","host","lane",
#   "mutations":N,"caught":K,"leaked":[..],"untestable":[..],"scratch":"<dir>","verdict":"OK|LEAK|UNTESTABLE"}
set -uo pipefail
usage() { sed -n '2,/^set -/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { usage; exit 0; }
if [[ "${1:-}" == --regressions ]]; then
  [[ $# -eq 1 ]] || { echo 'error: --regressions takes no additional arguments' >&2; exit 2; }
  exec python3 -B - "$(dirname "$0")" <<'PY'
import json, os, subprocess, sys, tempfile, time
from pathlib import Path
scripts = Path(sys.argv[1]).resolve()
sys.path.insert(0, str(scripts))
from case_manifest import run
root = Path(tempfile.mkdtemp(prefix='harness-regressions.'))
checks = []
def invoke(script, arguments, expected, label, timeout=15, env=None, cwd=None):
    result = subprocess.run([str(scripts / script)] + list(map(str, arguments)), cwd=root if cwd is None else cwd,
                            capture_output=True, timeout=timeout, env=env)
    assert result.returncode == expected, (label, result.returncode, result.stdout, result.stderr)
    checks.append(label)
    lines = result.stdout.decode().splitlines()
    return json.loads(lines[-1]) if lines and lines[-1].startswith('{') else result
def fixture(name, rows, outputs):
    directory = root / name
    directory.mkdir()
    manifest = directory / 'cases.tsv'
    manifest.write_text(rows)
    for case, (out, err, rc) in outputs.items():
        (directory / f'{case}.out').write_bytes(out)
        (directory / f'{case}.err').write_bytes(err)
        (directory / f'{case}.exit').write_text(str(rc) + '\n')
    return manifest, directory
python = sys.executable
invoke('case-gen.py', ['--class', 'ints', '--seed', 12, '--size', 0], 0,
       'zero-size integer generator cannot select from an empty row list')
echo = [python, '-c', 'print("ok")']
m, g = fixture('no-final-newline', 'first\t\nlast\t', {'first': (b'ok\n', b'', 0), 'last': (b'wrong\n', b'', 0)})
r = invoke('conform.sh', [m, g, '--', *echo], 1, 'last TSV row is compared')
assert len(r['cases']) == 2
m, g = fixture('missing-input', 'first\t\nmissing\t\tabsent-input\n', {'first': (b'ok\n', b'', 0), 'missing': (b'ok\n', b'', 1)})
r = invoke('conform.sh', [m, g, '--', *echo], 1, 'missing stdin cannot reuse previous output')
assert r['inconclusive'] == 1
av = ['', 'x y', '*', '--', 'tab\there']
cmd = [python, '-c', 'import json,sys; print(json.dumps(sys.argv[1:]))']
m, g = fixture('argv', 'argv\t' + json.dumps(av) + '\t-\n', {'argv': ((json.dumps(av) + '\n').encode(), b'', 0)})
invoke('conform.sh', [m, g, '--lane', 'quote"\nline', '--', *cmd], 0, 'JSON argv and JSON lane escaping')
m, g = fixture('reserved', 'reserved\t\n', {'reserved': (b'', b'', 124)})
r = invoke('conform.sh', [m, g, '--', python, '-c', 'raise SystemExit(124)'], 1, 'equal timeout exits remain inconclusive')
assert r['verdict'] == 'INCONCLUSIVE'
for code in (125, 129, 139, 143, 255):
    m, g = fixture('reserved-' + str(code), 'only\n', {'only': (b'', b'', code)})
    r = invoke('conform.sh', [m, g, '--', 'bash', '-c', f'exit {code}'], 1,
               f'wrapper/infrastructure exit {code} cannot pass')
    assert r['inconclusive'] == 1
    invoke('first-divergence.sh', ['only', m, g, '--', 'true'], 1,
           f'reserved golden {code} is inconclusive in first divergence')
    assert run(['bash', '-c', f'exit {code}'])['problem']
fifo = root / 'stdin.fifo'; os.mkfifo(fifo)
m, g = fixture('fifo-input', 'only\t[]\t' + str(fifo) + '\n', {'only': (b'', b'', 0)})
r = invoke('conform.sh', [m, g, '--timeout', '.03', '--', 'cat'], 1,
           'FIFO stdin is rejected before opening can hang', timeout=2)
assert r['inconclusive'] == 1
invoke('golden-capture.sh', [m, root / 'fifo-capture', '--timeout', '.03', '--', 'cat'], 1,
       'capture provenance cannot block on FIFO stdin', timeout=2)
invoke('cases-lint.sh', [fifo], 1, 'FIFO case manifest is rejected before reading', timeout=2)
invoke('conform.sh', [fifo, g, '--', 'true'], 2,
       'conformance rejects FIFO manifest without entering a case', timeout=2)
fifo_gold = root / 'fifo-golden'; fifo_gold.mkdir(); os.mkfifo(fifo_gold / 'only.out')
m_plain = root / 'fifo-golden.tsv'; m_plain.write_text('only\n')
r = invoke('conform.sh', [m_plain, fifo_gold, '--', 'true'], 1,
           'FIFO golden stream is an invalid golden, never a hang', timeout=2)
assert r['failed'] == 1
os.mkfifo(fifo_gold / 'MANIFEST.txt')
invoke('conform.sh', [m_plain, fifo_gold, '--', 'true'], 2,
       'FIFO oracle metadata is rejected before parsing', timeout=2)
(root / 'cwd.in').write_bytes(b'from child cwd\n')
r = run(['cat'], stdin='cwd.in', cwd=root)
assert r['out'] == b'from child cwd\n' and not r['problem']
checks.append('callable runner resolves stdin relative to child cwd')
for command, timeout_value in (([], 1), (echo, 0), (echo, float('nan')), ('echo', 1)):
    try:
        run(command, timeout=timeout_value)
    except ValueError:
        pass
    else:
        raise AssertionError((command, timeout_value))
checks.append('callable runner rejects invalid command vectors and deadlines')
escaped = [python, '-c', 'import os,time; p=os.fork(); '
           'os.setsid() if p == 0 else None; time.sleep(.8) if p == 0 else time.sleep(5)']
started = time.monotonic()
r = run(escaped, timeout=.03)
assert r['problem'] == 'timeout' and time.monotonic() - started < .7
checks.append('escaped descendant pipe cannot defeat timeout cleanup')
mixed_streams = [python, '-c', 'import sys; print("All terms check.",file=sys.stderr,flush=True); '
                 'print("ERROR after checker verdict",flush=True)']
r = run(mixed_streams, merge_stderr=True)
assert r['out'].splitlines() == [b'All terms check.', b'ERROR after checker verdict'] and r['err'] == b''
checks.append('merged runner preserves verdict chronology across stdout and stderr')
r = run(escaped, timeout=.03, merge_stderr=True)
assert r['problem'] == 'timeout' and r['err'] == b''
checks.append('merged runner timeout handles escaped descendant pipe cleanup')
r = run(['not-an-installed-program-harness-test'], merge_stderr=True)
assert r['problem'] and r['out'] and r['err'] == b''
checks.append('merged launch failure keeps the merged-stream result contract')
invoke('conform.sh', [m, g, '--', 'not-an-installed-program-harness-test'], 1, 'missing executable inconclusive')
invoke('conform.sh', [m, g, '--timeout', '.03', '--', python, '-c', 'import time; time.sleep(10)'], 1, 'per-case timeout bounds execution')
invoke('conform.sh', [m, g, '--lane'], 2, 'missing option value returns instead of looping')
invoke('conform.sh', [m, g, '--oracle-command', json.dumps(echo), '--', *echo], 2, 'original command is refused as port')
m, g = fixture('missing-stderr', 'only\n', {'only': (b'ok\n', b'', 0)})
(g / 'only.err').rename(g / 'only.err.saved')
invoke('first-divergence.sh', ['only', m, g, '--', *echo], 1, 'missing stderr golden cannot pass')
m, g = fixture('capture-input', 'only\t\tabsent-input\n', {})
invoke('golden-capture.sh', [m, g, '--', *echo], 1, 'capture refuses missing input')
assert not (g / 'MANIFEST.txt').exists()
m, g = fixture('capture-good', 'only', {})
invoke('golden-capture.sh', [m, g, '--', *echo], 0, 'name-only capture and EOF row')
invoke('conform.sh', [m, g, '--', *echo], 2, 'captured original identity is enforced')
invoke('floor.sh', [m, g, '--repeat', 2, '--', *echo], 0, 'floor permits intentional oracle comparison')
invoke('floor.sh', [m, g, '--repeat', 1, '--', python, '-c', 'print("ok", flush=True)'], 2,
       'floor refuses a different command even when its outputs match')
invoke('golden-capture.sh', [m, g, '--', *echo], 3, 'silent recapture refused')
relative = root / 'capture-cwd'; relative.mkdir()
(relative / 'original.py').write_text('print("ok")\n')
(relative / 'cases.tsv').write_text('only\n')
invoke('golden-capture.sh', ['cases.tsv', 'gold', '--', python, 'original.py'], 0,
       'capture stores command identity relative to capture cwd', cwd=relative)
invoke('conform.sh', [relative / 'cases.tsv', relative / 'gold', '--', python, relative / 'original.py'], 2,
       'oracle identity stays enforced from a different cwd')
relocated = root / 'relocated-capture'
import shutil
shutil.copytree(relative, relocated)
invoke('conform.sh', ['cases.tsv', 'gold', '--', python, 'original.py'], 2,
       'relocated captured original remains forbidden as a port', cwd=relocated)
invoke('floor.sh', ['cases.tsv', 'gold', '--repeat', 1, '--', python, 'original.py'], 0,
       'relocated original argv remains valid for the floor', cwd=relocated)
orphan = root / 'orphan-gold'; orphan.mkdir(); (orphan / 'only.err').write_bytes(b'precious')
invoke('golden-capture.sh', [m, orphan, '--', *echo], 3,
       'orphan stderr/exit artifacts still require an explicit recapture')
linked = root / 'linked-gold'; linked.mkdir(); (linked / 'only.out').symlink_to(root / 'cwd.in')
invoke('golden-capture.sh', [m, linked, '--repin', 'test', '--', *echo], 2,
       'capture refuses symlink destinations before writing')
assert (root / 'cwd.in').read_bytes() == b'from child cwd\n'
hardlinked = root / 'hardlinked-gold'; hardlinked.mkdir()
os.link(root / 'cwd.in', hardlinked / 'only.out')
invoke('golden-capture.sh', [m, hardlinked, '--repin', 'test', '--', *echo], 2,
       'capture refuses hardlinked destinations without damaging the other name')
assert (root / 'cwd.in').read_bytes() == b'from child cwd\n'
linked_dir = root / 'linked-directory'; linked_dir.symlink_to(linked, target_is_directory=True)
invoke('golden-capture.sh', [m, linked_dir, '--repin', 'test', '--', *echo], 2,
       'capture refuses a symlink directory as its destination')
late_link = root / 'late-linked-gold'; late_link.mkdir()
late_command = [python, '-c', 'from pathlib import Path; '
                f'Path({str(late_link / "only.out")!r}).symlink_to({str(root / "cwd.in")!r}); print("ok")']
invoke('golden-capture.sh', [m, late_link, '--', *late_command], 2,
       'capture rechecks destinations after running the original')
assert (root / 'cwd.in').read_bytes() == b'from child cwd\n'
changed = root / 'changed-input'; changed.write_bytes(b'before')
changed_manifest = root / 'changed.tsv'; changed_manifest.write_text('only\t' + json.dumps([str(changed)]) + '\n')
invoke('golden-capture.sh', [changed_manifest, root / 'changed-gold', '--', python, '-c',
       'import pathlib,sys; pathlib.Path(sys.argv[1]).write_bytes(b"after"); print("ok")'], 1,
       'capture rejects changed fixture provenance')
assert not (root / 'changed-gold' / 'MANIFEST.txt').exists()
changed.write_bytes(b'before')
changed_manifest.write_text('only\t' + json.dumps(['--input=' + str(changed)]) + '\n')
invoke('golden-capture.sh', [changed_manifest, root / 'changed-equals-gold', '--', python, '-c',
       'import pathlib,sys; pathlib.Path(sys.argv[1].split("=",1)[1]).write_bytes(b"after"); print("ok")'], 1,
       'capture fingerprints file paths in equals-style options')
assert not (root / 'changed-equals-gold' / 'MANIFEST.txt').exists()
floor_data = root / 'floor-data'; floor_data.write_text('before')
m, g = fixture('mutating-floor', 'only\t' + json.dumps([str(floor_data)]) + '\n', {'only': (b'ok\n', b'', 0)})
r = invoke('floor.sh', [m, g, '--repeat', 1, '--', python, '-c',
       'import pathlib,sys; pathlib.Path(sys.argv[1]).write_text("after"); print("ok")'], 1,
       'equal floor outputs cannot hide changed input bytes')
assert r['verdict'] == 'INCONCLUSIVE'
empty = root / 'empty.tsv'; empty.write_text('# empty\n')
invoke('conform.sh', [empty, g, '--', *echo], 1, 'empty manifest cannot pass')
left, right = root / 'left', root / 'right'
invoke('budget-compare.py', [fifo, fifo], 2,
       'budget comparator rejects FIFO artifacts before reading', timeout=2)
left.write_text('1000.0 0.0\n'); right.write_text('1001.0 0.01\n')
invoke('budget-compare.py', [left, right, '--abs', '.1', '--rel', '.01'], 0, 'each float independently gets abs OR relative budget')
left.write_text('1e999\n'); right.write_text('1e998\n')
invoke('budget-compare.py', [left, right], 1, 'overflowing float tokens refused')
invoke('budget-compare.py', [left, right, '--abs', 'nan'], 2, 'nonfinite budget refused')
left.write_text('1e-999\n'); right.write_text('1e-998\n')
invoke('budget-compare.py', [left, right], 1, 'underflow cannot erase numeric differences')
left.write_text('-1e308\n'); right.write_text('1e308\n')
invoke('budget-compare.py', [left, right, '--rel', '2'], 0, 'finite relative budget survives overflowing absolute difference')
left.write_text('0.0\n'); right.write_text('0.01\n')
r = invoke('budget-compare.py', [left, right, '--abs', '.1'], 0, 'zero-denominator report is strict JSON')
assert r['max_rel'] is None and r['unbounded_rel']
for a, b, budget_args, expected, label in (
    ('9007199254740992.0\n', '9007199254740993.0\n', [], 1, 'binary64 rounding cannot erase decimal differences'),
    ('1.0\n', '1.00000000000000000001\n', ['--abs', '1e-21'], 1, 'exact decimal comparison exceeds tiny budget'),
    ('0.1\n', '0.3\n', ['--abs', '.2'], 0, 'exact decimal boundary passes'),
    ('1.0\n', '1.00000000000000000001\n', ['--measure'], 0, 'measurement retains tiny decimal deviations'),
    ('name  1.0\n', 'name 1.0\n', ['--abs', '1'], 1, 'budget never normalizes discrete whitespace'),
    ('id=001 1.0\n', 'id=1 1.0\n', ['--abs', '1'], 1, 'nonnumeric bytes remain exact'),
    ('1.0\n', '1.0\r\n', [], 1, 'budget keeps newline bytes exact'),
    ('1e999999999999999999999999\n', '1.0\n', [], 1, 'unsupported exponent is a mismatch, not a traceback')):
    left.write_text(a); right.write_text(b)
    r = invoke('budget-compare.py', [left, right, *budget_args], expected, label)
    if '--measure' in budget_args: assert r['max_abs'] > 0
left.write_text('4.9406564584124654e-324\n'); right.write_text('4.9406564584124655e-324\n')
r = invoke('budget-compare.py', [left, right, '--measure'], 0,
           'subnormal decimal difference is preserved in exact measurement fields')
assert r['max_abs'] is None and r['underflow_abs'] and not r['unbounded_abs']
assert r['max_abs_exact'] != '0/1'
failed = [python, '-c', 'raise SystemExit(7)']
r = invoke('incumbent-bench.sh', ['--runs', 1, '--warmup', 0, '--max-cv', 10000, '--original', *failed, '--port', *failed], 1, 'two failed benchmark arms refused')
assert r['verdict'] == 'RUN_FAILED' and r['ratio'] is None
different_err = [python, '-c', 'import sys; print("ok"); print("different", file=sys.stderr)']
invoke('incumbent-bench.sh', ['--runs', 1, '--warmup', 0, '--max-cv', 10000, '--original', *echo, '--port', *different_err], 1, 'benchmark compares stderr')
warm_code = ('from pathlib import Path; p=Path("bench-warm-marker"); '
             'print("ok" if p.exists() else "warmup-difference"); p.touch()')
r = invoke('incumbent-bench.sh', ['--runs', 1, '--warmup', 1, '--max-cv', 10000,
           '--original', python, '-c', warm_code, '--port', *echo], 1,
           'benchmark includes warmup outputs in stability checks')
assert r['verdict'] == 'NONDETERMINISTIC_ORIGINAL' and r['ratio'] is None
bench_input = root / 'bench-input'; bench_input.write_text('before')
r = invoke('incumbent-bench.sh', ['--runs', 1, '--warmup', 0, '--max-cv', 10000,
           '--original', python, '-c', 'from pathlib import Path; import sys; '
           'Path(sys.argv[1]).write_text("after"); print("ok")', bench_input, '--port', *echo], 1,
           'benchmark refuses changed explicit source/input files')
assert r['verdict'] == 'INPUT_CHANGED' and r['ratio'] is None
proposed = root / 'argv-proposed.tsv'
invoke('argv-explore.sh', ['--out', proposed, '--file', 'file with spaces', '--', python, '-c',
                         'import sys; print(repr(sys.argv[1:]),file=sys.stderr)'], 0, 'argv exploration emits lossless proposals')
vectors = [json.loads(line.split('\t', 1)[1]) for line in proposed.read_text().splitlines() if not line.startswith('#')]
assert [''] in vectors and ['file with spaces'] in vectors
explore = root / 'explore'
invoke('diff-explore.sh', ['--class', 'argv', '--seeds', 1, '--gen',
    "printf '%s' '[\"\",\"x y\",\"*\"]'", '--out-dir', explore,
    '--original', *cmd, '--port', python, '-c',
    'import json,sys; print(json.dumps(sys.argv[1:]) + "DIFF")'], 1, 'differential exploration preserves argv boundaries')
row = next(explore.glob('*/proposed.tsv')).read_text().split('\t', 1)[1]
assert json.loads(row) == ['', 'x y', '*']
invoke('diff-explore.sh', ['--class', 'argv', '--seeds', 1, '--timeout', '.03', '--gen', 'sleep 10',
    '--out-dir', root / 'timeout', '--original', 'true', '--port', 'true'], 1, 'differential generator timeout is bounded')
r = invoke('diff-explore.sh', ['--class', 'argv', '--seeds', 1, '--gen', "printf '[invalid'",
    '--out-dir', root / 'invalid-generator', '--original', 'true', '--port', 'true'], 1,
    'invalid generated argv is inconclusive execution evidence')
assert r['inconclusive'] == 1
r = invoke('diff-explore.sh', ['--args', '["{input}"]', '--seeds', 1, '--gen', "printf 'before\\n'",
    '--out-dir', root / 'mutating-input', '--original', python, '-c',
    'import pathlib,sys; pathlib.Path(sys.argv[1]).write_text("after"); print("same")',
    '--port', python, '-c', 'print("same")'], 1, 'mutated generated input cannot count as agreement')
assert r['inconclusive'] == 1
r = invoke('diff-explore.sh', ['--class', 'argv', '--seeds', 1, '--gen', "printf 'not-json'",
    '--out-dir', root / 'non-json-generator', '--original', 'true', '--port', 'true'], 1,
    'argv generator cannot silently fall back to word splitting')
assert r['inconclusive'] == 1
lint_manifest = root / 'lint.tsv'
spaced_input = root / 'input with spaces.txt'
spaced_input.write_text('data\n')
lint_manifest.write_text('usage_none\nempty\t[]\t-\tclass-empty\nerror_missing\t[]\t-\tclass-error\n'
                         'edge_1000\t' + json.dumps(['a+b', '', str(spaced_input)]) + '\t' + str(spaced_input) + '\tclass-happy')
r = invoke('cases-lint.sh', [lint_manifest, '--commands', json.dumps(['a+b'])], 0,
           'cases lint shares JSON argv, name-only, dash-stdin, fourth-column and final-row semantics')
assert r['cases'] == 4 and r['classes_missing'] == '' and r['notes'] == 0
lint_manifest.write_text('only\t[]\tabsent-stdin\tclass-annotation')
r = invoke('cases-lint.sh', [lint_manifest], 1, 'cases lint rejects a missing stdin on the final row')
assert r['cases'] == 1 and r['errors'] == 1
lint_manifest.write_text('only\t["a+b"]')
r = invoke('cases-lint.sh', [lint_manifest, '--commands', '["a+b","aaab"]'], 0,
           'cases lint command coverage uses exact argv, not regular expressions')
assert 'happy:a+b' not in r['classes_missing'] and 'happy:aaab' in r['classes_missing']
lint_manifest.write_text('first\nfirst')
invoke('cases-lint.sh', [lint_manifest], 1, 'cases lint rejects duplicate name-only rows')
# Exercise tripwire orchestration with a tiny compiler fixture; no Bend/toolchain
# behavior is mocked by these checks, only the shell harness's pin policy.
trip = root / 'tripwire'; (trip / 'port').mkdir(parents=True)
(trip / 'port' / 'main.bend').write_text('# compiler fixture input\n')
compiler = trip / 'compiler.py'
compiler.write_text('import os,sys\nfrom pathlib import Path\n'
    'if "--version" in sys.argv: print("compiler-fixture"); raise SystemExit(0)\n'
    'p=Path(sys.argv[sys.argv.index("-o")+1])\n'
    'p.write_text("#!"+sys.executable+"\\n"+os.environ.get("HARNESS_RUNTIME", "print(\\\"ok\\\")\\n"))\n'
    'p.chmod(0o755)\n')
trip_env = dict(os.environ, BEND_CLI=f'{python} {compiler}')
inputs = trip / 'inputs.tsv'; inputs.write_text('# empty\n')
invoke('perf-tripwire.sh', ['--pin', '--pin-file', 'pin.txt', inputs], 2,
       'empty tripwire corpus cannot write a green pin', env=trip_env, cwd=trip)
assert not (trip / 'pin.txt').exists()
inputs.write_text('one\nsecond\n')
pin_target = trip / 'precious.txt'; pin_target.write_text('preserve')
(trip / 'linked-pin').symlink_to(pin_target)
invoke('perf-tripwire.sh', ['--pin', '--runs', 1, '--threads', 1, '--pin-file', 'linked-pin', inputs], 2,
       'tripwire refuses symlink pin output before building', env=trip_env, cwd=trip)
assert pin_target.read_text() == 'preserve'
os.link(pin_target, trip / 'hardlinked-pin')
invoke('perf-tripwire.sh', ['--pin', '--runs', 1, '--threads', 1, '--pin-file', 'hardlinked-pin', inputs], 2,
       'tripwire refuses hardlinked pin output before building', env=trip_env, cwd=trip)
assert pin_target.read_text() == 'preserve'
os.mkfifo(trip / 'fifo-pin')
invoke('perf-tripwire.sh', ['--pin', '--runs', 1, '--threads', 1, '--pin-file', 'fifo-pin', inputs], 2,
       'tripwire refuses FIFO pin output without blocking', env=trip_env, cwd=trip, timeout=2)
invoke('perf-tripwire.sh', ['--pin', '--runs', 1, '--threads', 1, '--pin-file', 'pin.txt', inputs], 0,
       'tripwire records all requested cells', env=trip_env, cwd=trip)
invoke('perf-tripwire.sh', ['--runs', 1, '--threads', 2, '--pin-file', 'pin.txt', inputs], 2,
       'tripwire refuses a changed thread budget', env=trip_env, cwd=trip)
inputs.write_text('one\t["cheaper-workload"]\nsecond\n')
r = invoke('perf-tripwire.sh', ['--runs', 1, '--threads', 1, '--slack', 100, '--pin-file', 'pin.txt', inputs], 3,
           'changed argv cannot clear an unchanged-output timing pin', env=trip_env, cwd=trip)
assert 'one/SEQ-CPU' in r['refused']
inputs.write_text('one\n')
r = invoke('perf-tripwire.sh', ['--runs', 1, '--threads', 1, '--slack', 100, '--pin-file', 'pin.txt', inputs], 1,
           'removing a pinned tripwire case trips the gate', env=trip_env, cwd=trip)
assert 'second/SEQ-CPU' in r['trips'] and 'second/PAR-CPU' in r['trips']
data = trip / 'data.txt'; data.write_text('workload one\n')
inputs.write_text('file\t["data.txt"]\n')
invoke('perf-tripwire.sh', ['--pin', '--runs', 1, '--threads', 1, '--pin-file', 'data-pin.txt', inputs], 0,
       'tripwire fingerprints file-valued arguments', env=trip_env, cwd=trip)
data.write_text('cheaper workload\n')
r = invoke('perf-tripwire.sh', ['--runs', 1, '--threads', 1, '--slack', 100, '--pin-file', 'data-pin.txt', inputs], 3,
           'changed input bytes cannot clear an unchanged-output timing pin', env=trip_env, cwd=trip)
assert 'file/PAR-CPU' in r['refused']
inputs.write_text('file\t["--input=data.txt"]\n')
invoke('perf-tripwire.sh', ['--pin', '--runs', 1, '--threads', 1, '--pin-file', 'equals-pin.txt', inputs], 0,
       'tripwire pins equals-style file operands', env=trip_env, cwd=trip)
data.write_text('another cheaper workload\n')
r = invoke('perf-tripwire.sh', ['--runs', 1, '--threads', 1, '--slack', 100, '--pin-file', 'equals-pin.txt', inputs], 3,
           'changed equals-option input bytes refuse comparison', env=trip_env, cwd=trip)
assert 'file/PAR-CPU' in r['refused']
trip_env['HARNESS_RUNTIME'] = ('from pathlib import Path\nimport sys\n'
    'p=Path("trip-warm-"+sys.argv[2]); print("ok" if p.exists() else "warmup-difference"); p.touch()\n')
r = invoke('perf-tripwire.sh', ['--pin', '--runs', 1, '--threads', 2, '--pin-file', 'refused.txt', inputs], 3,
           'tripwire warmup differences refuse pinning', env=trip_env, cwd=trip)
assert r['refused'] and not (trip / 'refused.txt').exists()
for name in checks: print('PASS ' + name)
print(json.dumps({'checks': len(checks), 'scratch': str(root), 'verdict': 'PASS'}))
PY
fi
ROOT="$PWD"; LANE="c-1t"; ORIG=()
while [[ $# -gt 0 ]]; do
  if [[ "$1" == --root || "$1" == --lane ]]; then
    [[ $# -ge 2 && "$2" != --* ]] || { echo "error: $1 needs a value" >&2; exit 2; }
  fi
  case "$1" in
    --root) ROOT="${2:-}"; shift 2;;
    --lane) LANE="${2:-}"; shift 2;;
    --) shift; ORIG=("$@"); break;;
    *) echo "error: unknown option $1" >&2; usage >&2; exit 2;;
  esac
done
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 2
cd "$ROOT" || { echo "error: no such root $ROOT" >&2; exit 2; }
[[ -d goldens && -d port && -d scripts && -d docs && -d perf ]] || { echo "error: run from a port root (docs/ goldens/ port/ perf/ scripts/)" >&2; exit 2; }
[[ "$LANE" == c-1t || "$LANE" == interpreter ]] || { echo "error: --lane is c-1t or interpreter" >&2; exit 2; }
if [[ -n "${BEND_CLI:-}" ]]; then read -ra BEND <<<"$BEND_CLI"
elif command -v bend >/dev/null 2>&1; then BEND=(bend)
else echo "error: no bend on PATH and no BEND_CLI" >&2; exit 2; fi
export BEND_NO_TELEMETRY=1

# The three paths a copy LINKS instead of copying. Each is read by the gates and written by NO mutation,
# which `guard_symlinked` below re-checks against this script's own text on every run. perf/e2e alone is
# 198 MB of perf's 208 MB, so copying it 22 times is about 4.4 GB of scratch per run; that is what filled
# this host's disk on 2026-09-24 (seven retained trees, ~14 GB) and killed a peer's mutant run at M64.
# A mutation that ever writes under one of these would reach the REAL tree through the link, which is
# worse than a full disk -- hence the guard, and hence goldens/ and cases.tsv are still REAL copies
# (M1..M4 and M12 rewrite a golden byte, move a .err aside, reduce cases.tsv and rename a case).
LINKED=(perf/e2e perf/inputs cases)

guard_symlinked() {  # a mutation must never write under a linked path; check this script, not a promise
  local bad="" p
  for p in "${LINKED[@]}"; do
    grep -qE '\$D/'"$p" "$0" && bad+=" $p"
  done
  [[ -z "$bad" ]] || { echo "error: this script writes under a LINKED path ($bad): a mutation would reach the real tree" >&2; exit 2; }
}

guard_symlinked   # fail in a second, before any build or copy

ROOT="$PWD"
T="$(mktemp -d "${TMPDIR:-/tmp}/hst.XXXXXX")"
sha="$(git rev-parse --short HEAD 2>/dev/null || echo none)"
run_compiler() {
  local seconds="$1"; shift
  python3 -B - "$HERE" "$seconds" "${BEND[@]}" "$@" <<'PY'
import sys
sys.path.insert(0,sys.argv[1])
from case_manifest import run
r=run(sys.argv[3:],timeout=float(sys.argv[2]))
sys.stdout.buffer.write(r['out']); sys.stderr.buffer.write(r['err'])
sys.exit(r['rc'] if r['rc'] is not None else 125)
PY
}
bendv="$(run_compiler 30 --version 2>/dev/null | tail -1)" || { echo 'error: compiler version probe failed' >&2; exit 2; }
[[ -n "$bendv" ]] || { echo 'error: compiler returned no version' >&2; exit 2; }
host="$(uname -s -m 2>/dev/null | tr ' ' '-')"

# the port command: one native build for every copy, or the interpreter lane
if [[ "$LANE" == c-1t ]]; then
  if ! run_compiler 600 port/main.bend -o "$T/x" >"$T/build.log" 2>&1; then
    echo "error: native build of port/main.bend failed: $(head -c 200 "$T/build.log")" >&2; exit 2
  fi
  PORT=("$T/x" --threads 1 --gpu off --)
else
  PORT=(scripts/interp-lane.sh "${BEND[@]}" port/main.bend --)
fi

# the first case whose stdout golden is non-empty (M1 flips a byte of it), and the first law
C=""; C_ANY=""
while IFS= read -r raw || [[ -n "$raw" ]]; do
  l="${raw//$'\t'/$'\x1f'}"; IFS=$'\x1f' read -r nm _rest <<<"$l"
  [[ -z "$nm" || "$nm" == \#* ]] && continue
  [[ -z "$C_ANY" ]] && C_ANY="$nm"
  if [[ -z "$C" && -s "goldens/$nm.out" ]]; then C="$nm"; fi
done <goldens/cases.tsv
[[ -n "$C_ANY" ]] || { echo "error: goldens/cases.tsv has no cases" >&2; exit 2; }
[[ -n "$C" ]] || C="$C_ANY"
L="$(grep -oE '^law [A-Za-z0-9_.]+' port/LAWS.bend 2>/dev/null | head -1 | awk '{print $2}')"

copy() {  # $1 name -> a fresh copy of the port under $T/$1 (legacy, oracle and the LINKED paths linked)
  local d="$T/$1"; mkdir -p "$d"
  # A FAILED COPY MUST BE LOUD. This was `2>/dev/null`, which can only ever hide an incomplete copy, and
  # a verdict built on one is void. The change is DEFENSIVE: no failure was ever observed. I first
  # justified it with one, having found two retained trees missing perf/e2e/corpus (179 MB) and inferred
  # a cp cut short by the full disk; a peer session refuted that, and the real reason is that the corpus
  # is untracked and ignored, so a CLONE never has it. I then overstated the leftover as "the verdict
  # depends on which checkout it runs from"; a grep disproved that too. NO gate run here reads that
  # directory, so the trees differ by a footprint and not by coverage, and both verdicts are equally
  # valid. The residue worth keeping is only this: 2>/dev/null on a copy can hide an incomplete tree,
  # and a verdict built on one would be void, so the status is checked.
  if ! cp -RL docs goldens port scripts "$d/" 2>"$T/copy.err"; then
    sed 's/^/  cp: /' "$T/copy.err" >&2
    echo "error: incomplete copy of $1 (see above); every verdict from it would be void" >&2
    exit 2
  fi
  # perf is copied WITHOUT its two large read-only subdirectories, which are linked below
  mkdir -p "$d/perf"
  cp -RL perf/*.md perf/*.py "$d/perf/" 2>/dev/null
  [[ -d perf/evidence ]] && cp -RL perf/evidence "$d/perf/" 2>/dev/null
  local p
  for p in "${LINKED[@]}"; do
    [[ -e "$p" ]] && { mkdir -p "$d/$(dirname "$p")"; ln -s "$ROOT/$p" "$d/$p"; }
  done
  [[ -d .beads ]] && cp -RL .beads "$d/" 2>/dev/null
  [[ -d bin ]] && cp -RL bin "$d/" 2>/dev/null
  for f in README.md CONTRIBUTING.md AGENTS.md; do [[ -f $f ]] && cp "$f" "$d/"; done
  [[ -e oracle ]] && ln -s "$ROOT/oracle" "$d/oracle"
  [[ -e legacy ]] && ln -s "$ROOT/legacy" "$d/legacy"
  [[ -f .gitignore ]] && cp .gitignore "$d/"
  printf '%s' "$d"
}
n=0; caught=0; leaked=(); untestable=()
controls=0; controls_passed=0; false_positives=()   # the second axis: see expect_quiet
# baseline: each gate on a clean copy; a red gate here makes its mutations UNTESTABLE
B="$(copy base)"
( cd "$B" && scripts/conform.sh goldens/cases.tsv goldens --lane "$LANE" -- "${PORT[@]}" ) >"$T/base.conform.log" 2>&1; b_conform=$?
( cd "$B" && scripts/law-coverage.sh port/LAWS.bend port/PROOF.bend docs/FEATURE_PARITY.md port/main.bend ) >"$T/base.lawcov.log" 2>&1; b_lawcov=$?
( cd "$B" && scripts/claims-lint.sh perf/NEGATIVE-EVIDENCE.md ) >"$T/base.claims.log" 2>&1; b_claims=$?
( cd "$B" && scripts/state-check.sh docs/PORT_STATE.md ) >"$T/base.state.log" 2>&1; b_state=$?
( cd "$B" && scripts/parity-board.sh docs/FEATURE_PARITY.md ) >"$T/base.board.log" 2>&1; b_board=$?
b_audit=1; [[ -f scripts/claims-audit.py ]] && { ( cd "$B" && python3 scripts/claims-audit.py ) >"$T/base.audit.log" 2>&1; b_audit=$?; }
b_manifest=1; [[ -f goldens/MANIFEST.txt ]] && b_manifest=0
printf 'baseline   conform=%s law-coverage=%s claims-lint=%s state-check=%s parity-board=%s manifest=%s (0 = green)\n' \
  "$b_conform" "$b_lawcov" "$b_claims" "$b_state" "$b_board" "$b_manifest"

expect() {  # name baseline_rc wanted_rc dir command...
  local name="$1" base="$2" want="$3" d="$4"; shift 4; n=$((n+1))
  if [[ "$base" -ne 0 ]]; then
    printf 'UNTESTABLE %-24s the gate is already red on the clean copy (exit %s)\n' "$name" "$base"; untestable+=("$name"); return
  fi
  ( cd "$d" && "$@" ) >"$T/$name.log" 2>&1; local rc=$?
  if [[ $rc -eq $want ]]; then
    printf 'CAUGHT     %-24s exit %s\n' "$name" "$rc"; caught=$((caught+1))
  else
    printf 'LEAK       %-24s exit %s, wanted %s: %s\n' "$name" "$rc" "$want" "$(grep -v '^$' "$T/$name.log" | tail -1 | head -c 110)"; leaked+=("$name")
  fi
}

# M1 one byte of the golden flipped
D="$(copy m1)"; python3 - "$D/goldens/$C.out" <<'PY'
import sys
p = sys.argv[1]; b = bytearray(open(p, 'rb').read())
if b: b[0] ^= 0x01
else: b.append(1)
open(p, 'wb').write(bytes(b))
PY
expect M1_golden_edited "$b_conform" 1 "$D" scripts/conform.sh goldens/cases.tsv goldens --lane "$LANE" -- "${PORT[@]}"
# M2 a missing .err golden
D="$(copy m2)"; mv "$D/goldens/$C_ANY.err" "$D/goldens/$C_ANY.err.aside"
expect M2_missing_err "$b_conform" 1 "$D" scripts/conform.sh goldens/cases.tsv goldens --lane "$LANE" -- "${PORT[@]}"
# M3 an empty manifest
D="$(copy m3)"; printf '# empty\n' >"$D/goldens/cases.tsv"
expect M3_empty_manifest "$b_conform" 1 "$D" scripts/conform.sh goldens/cases.tsv goldens --lane "$LANE" -- "${PORT[@]}"
# M4 a renamed case
D="$(copy m4)"; awk -F'\t' -v c="$C_ANY" 'BEGIN{OFS="\t"} $1==c {$1=c"_renamed"} {print}' goldens/cases.tsv >"$D/goldens/cases.tsv"
expect M4_renamed_case "$b_conform" 1 "$D" scripts/conform.sh goldens/cases.tsv goldens --lane "$LANE" -- "${PORT[@]}"
# M5 oracle-on-oracle (the original as the port) must be refused, not passed
if [[ ${#ORIG[@]} -gt 0 ]]; then
  D="$(copy m5)"
  oracle_json="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' "${ORIG[@]}")"
  expect M5_oracle_on_oracle "$b_conform" 2 "$D" scripts/conform.sh goldens/cases.tsv goldens --lane "$LANE" --oracle-command "$oracle_json" -- "${ORIG[@]}"
else
  echo "UNTESTABLE M5_oracle_on_oracle      no original command given after --"
  n=$((n+1)); untestable+=(M5_oracle_on_oracle)
fi
# M6 a law whose proof is gone
if [[ -n "$L" ]]; then
  D="$(copy m6)"; awk -v L="def Laws.$L(" '{ if (skip) { if ($0 ~ /^def / || $0 ~ /^law /) skip=0; else next } if (index($0, L) == 1) { skip=1; next } print }' port/PROOF.bend >"$D/port/PROOF.bend"
  expect M6_unproved_law "$b_lawcov" 1 "$D" scripts/law-coverage.sh port/LAWS.bend port/PROOF.bend docs/FEATURE_PARITY.md port/main.bend
  # M7 a proof whose law is gone
  D="$(copy m7)"; awk -v L="law $L:" '{ if (skip) { if ($0 ~ /^law / || $0 ~ /^#/ || $0 ~ /^def /) skip=0; else next } if ($0 == L) { skip=1; next } print }' port/LAWS.bend >"$D/port/LAWS.bend"
  expect M7_ghost_proof "$b_lawcov" 1 "$D" scripts/law-coverage.sh port/LAWS.bend port/PROOF.bend docs/FEATURE_PARITY.md port/main.bend
else
  echo "UNTESTABLE M6_unproved_law M7_ghost_proof   port/LAWS.bend has no law"
  n=$((n+2)); untestable+=(M6_unproved_law M7_ghost_proof)
fi
# M8 a deferral in a ledger
D="$(copy m8)"; printf '\n- Retry predicate: we should revisit later\n' >>"$D/perf/NEGATIVE-EVIDENCE.md"
expect M8_ledger_later "$b_claims" 1 "$D" scripts/claims-lint.sh perf/NEGATIVE-EVIDENCE.md
# M9 an intention instead of a command in PORT_STATE
D="$(copy m9)"; printf '\n## Plan\n\nWe should probably fix the rest later.\n' >>"$D/docs/PORT_STATE.md"
expect M9_state_intention "$b_state" 1 "$D" scripts/state-check.sh docs/PORT_STATE.md
# M10 a present row with no evidence, inserted right under the board's header
D="$(copy m10)"; awk 'BEGIN{hdr=0; ins=0} {print} !ins && tolower($0) ~ /^\| *feature *\|/ {hdr=1; next} hdr && /^\|[[:space:]]*:?-+/ {print "| ghost feature | S1.1 | ghost | - | - | present | harness-selftest M10 |"; hdr=0; ins=1}' docs/FEATURE_PARITY.md >"$D/docs/FEATURE_PARITY.md"
expect M10_present_no_evidence "$b_board" 1 "$D" scripts/parity-board.sh docs/FEATURE_PARITY.md
# M11 a silent re-capture
if [[ ${#ORIG[@]} -gt 0 ]]; then
  D="$(copy m11)"
  expect M11_silent_recapture "$b_manifest" 3 "$D" scripts/golden-capture.sh goldens/cases.tsv goldens -- "${ORIG[@]}"
else
  echo "UNTESTABLE M11_silent_recapture     no original command given after --"
  n=$((n+1)); untestable+=(M11_silent_recapture)
fi

# M12 a count that moved on: one case is added to the corpus and the documents keep the old number
if [[ -f scripts/claims-audit.py ]]; then
  D="$(copy m12)"
  printf 'selftest_extra_case\t["--encode"]\t-\tselftest\tadded by harness-selftest M12\n' >>"$D/goldens/cases.tsv"
  expect M12_stale_count "$b_audit" 1 "$D" python3 scripts/claims-audit.py
else
  echo "UNTESTABLE M12_stale_count          scripts/claims-audit.py is not in this port"
  n=$((n+1)); untestable+=(M12_stale_count)
fi

# M13 a refusal that moved on: one more REFUSED_CV capture lands in perf/evidence/ and the documents keep
# the old number. M12 proves the stale-CASE-count check bites; this proves the stale-REFUSAL-count one does,
# which is the check that caught 16 -> 17 when QGU.wide2000.json was added (bead toon_bend-txm)
if [[ -f scripts/claims-audit.py && -d perf/evidence ]]; then
  D="$(copy m13)"
  # a REALISTIC capture: claims-audit counts the two-arm captures (a file with both `original` and `port`),
  # so a stub without them is correctly ignored and would leak instead of catching
  printf '{"tag":"selftest-m13","ratio":null,"verdict":"REFUSED_CV","original":{"median_ms":1.0,"cv_pct":9.9,"sha":"x","exit":0},"port":{"median_ms":1.0,"cv_pct":9.9,"sha":"x","exit":0}}\n' >"$D/perf/evidence/SELFTEST-M13.json"
  expect M13_stale_refused_count "$b_audit" 1 "$D" python3 scripts/claims-audit.py
else
  echo "UNTESTABLE M13_stale_refused_count  scripts/claims-audit.py or perf/evidence/ is not in this port"
  n=$((n+1)); untestable+=(M13_stale_refused_count)
fi

# A gate that is legitimately red on the clean tree cannot be tested by its exit code. This asserts on
# the MESSAGE instead, and proves the mutation caused it: the phrase must be absent on the clean copy.
expect_says() {  # name pattern dir command...
  local name="$1" pat="$2" d="$3"; shift 3; n=$((n+1))
  ( cd "$B" && "$@" ) >"$T/$name.clean.log" 2>&1
  if grep -qE -- "$pat" "$T/$name.clean.log"; then
    printf 'UNTESTABLE %-24s the phrase is already present on the clean copy\n' "$name"; untestable+=("$name"); return
  fi
  ( cd "$d" && "$@" ) >"$T/$name.log" 2>&1
  if grep -qE -- "$pat" "$T/$name.log"; then
    printf 'CAUGHT     %-24s %s\n' "$name" "$(grep -oE -- "$pat" "$T/$name.log" | head -1)"; caught=$((caught+1))
  else
    printf 'LEAK       %-24s no match for /%s/: %s\n' "$name" "$pat" "$(grep -v '^$' "$T/$name.log" | tail -1 | head -c 110)"; leaked+=("$name")
  fi
}

# A CONTROL is the INVERSE of a mutation: a change that is NOT a lie, which the gate must therefore pass
# in silence. It is counted on its own axis, never as a mutation, so "N mutations caught" keeps meaning
# exactly what it meant before controls existed. A failed control is a FALSE POSITIVE, not a leak: the
# gate objected to something honest, which rejects real work rather than letting bad work through.
# Why one exists at all (round 24): the report reader once refused a report whose only irregularity was
# quoting its OWN findings table inside an HTML comment, reporting "2 findings tables". Nothing a reader
# sees was wrong. A mutation cannot express that, because there is no lie to plant.
expect_quiet() {  # name pattern dir command...  -- the gate must NOT name it
  local name="$1" pat="$2" d="$3"; shift 3; controls=$((controls+1))
  ( cd "$d" && "$@" ) >"$T/$name.log" 2>&1
  if grep -qE -- "$pat" "$T/$name.log"; then
    printf 'FALSE_POS  %-24s the gate objected to honest content: %s\n' "$name" \
      "$(grep -oE -- "$pat" "$T/$name.log" | head -1)"; false_positives+=("$name")
  else
    printf 'QUIET      %-24s as it must be\n' "$name"; controls_passed=$((controls_passed+1))
  fi
}

# M14 a post-20 round that carries counted findings but is marked clean (R21-2). Every finding a round
# from 20 counts is a MEDIUM-or-HIGH BEHAVIOR finding, so "clean" and a non-zero count contradict.
if [[ -f scripts/converge.sh ]]; then
  D="$(copy m14)"
  awk '{print} /^\| 20 \| non-author/ {print "| 21 | non-author hostile review (subagent): harness-selftest M14 (non-author) | 2 | 2 | yes | 2026-09-24 |"}' \
    docs/PORT_STATE.md >"$D/docs/PORT_STATE.md"
  expect_says M14_clean_with_findings 'round 21 is marked clean but records 2' "$D" \
    scripts/converge.sh docs/PORT_STATE.md
  # M15 a finding neither repaired nor registered: `fixed` under the finding count.
  D="$(copy m15)"
  sed 's/^| 18 \(.*\)| 5 | 5 | no |/| 18 \1| 5 | 1 | no |/' docs/PORT_STATE.md >"$D/docs/PORT_STATE.md"
  expect_says M15_unfixed_finding 'round 18: 4 of 5 finding' "$D" \
    scripts/converge.sh docs/PORT_STATE.md
  # M18 a round labelled non-author with no report behind it (R22-1): two such rows printed CONVERGED.
  # The planted round is the last row's number plus ONE HUNDRED, and the plant ASSERTS that no report
  # exists for it. At last+1 this mutation LEAKED once in a peer's chain (2026-09-26): during a repair the
  # next round's real report is already in the working tree before its row is written, so the planted round
  # HAS a report and "has no report" never appears. A mutation whose validity depends on what a concurrent
  # review happens to have filed is not a mutation, and the leak looks like a broken gate.
  D="$(copy m18)"
  python3 - "$D/docs/PORT_STATE.md" "$D/docs/reviews" <<'PLANT'
import os, re, sys
from pathlib import Path
state, reviews = Path(sys.argv[1]), sys.argv[2]
lines = state.read_text(encoding='utf-8').split('\n')
rows = [(i, int(m.group(1))) for i, l in enumerate(lines) for m in [re.match(r'^\|\s*(\d+)\s*\|', l)] if m]
assert rows, 'no numeric round row in the rounds table'
last_i, last_n = rows[-1]
planted = last_n + 100
assert not os.path.exists(os.path.join(reviews, 'round-%02d.md' % planted)), \
    'a report exists for the planted round %d; pick another number' % planted
cells = lines[last_i].split('|')
cells[1] = ' %d ' % planted
cells[2] = ' non-author hostile review (subagent): harness-selftest M18 (non-author) '
cells[3], cells[4], cells[5] = ' 0 ', ' 0 ', ' yes '
lines.insert(last_i + 1, '|'.join(cells))
state.write_text('\n'.join(lines), encoding='utf-8')
PLANT
  expect_says M18_round_without_report 'has no report' "$D" \
    scripts/converge.sh docs/PORT_STATE.md
  # M19 a round from 20 recorded 0 | 0 | yes while its report's counted rows are re-spelled `Medium | Behaviour`
  # (R22-2: the first check was case-sensitive and read the words anywhere in the row).
  if [[ -f docs/reviews/round-21.md ]]; then
    D="$(copy m19)"
    sed 's/^\(| 21 | .*\)| 2 | 2 | no |/\1| 0 | 0 | yes |/' docs/PORT_STATE.md >"$D/docs/PORT_STATE.md"
    sed 's/^| R21-\([0-9]*\) | MEDIUM | BEHAVIOR/| R21-\1 | Medium | Behaviour/' docs/reviews/round-21.md >"$D/docs/reviews/round-21.md"
    # Round 29's source-text contract changed which rule fires: a re-spelled `Medium | Behaviour` report
    # no longer PARSES to a count, so the old phrase 'the table says 0 counted finding' can never appear
    # and this plant reported LEAK while the gate was refusing it correctly. Asserted on the rule that
    # now fires, read from converge's whole output in a retained tree.
    expect_says M19_counted_rows_respelled 'the sev cell `Medium` is not exactly' "$D" \
      scripts/converge.sh docs/PORT_STATE.md
    # M21 a round's report present but EMPTY (R23-1): an empty file used to satisfy "the report exists".
    D="$(copy m21)"
    : >"$D/docs/reviews/round-21.md"
    expect_says M21_empty_report 'round-21.md: the report is empty' "$D" \
      scripts/converge.sh docs/PORT_STATE.md
  else
    echo "UNTESTABLE M19_counted_rows_respelled docs/reviews/round-21.md is not in this port"
    n=$((n+1)); untestable+=(M19_counted_rows_respelled)
    echo "UNTESTABLE M21_empty_report         docs/reviews/round-21.md is not in this port"
    n=$((n+1)); untestable+=(M21_empty_report)
  fi
else
  echo "UNTESTABLE M14_clean_with_findings   scripts/converge.sh is not in this port"
  n=$((n+1)); untestable+=(M14_clean_with_findings)
  echo "UNTESTABLE M15_unfixed_finding      scripts/converge.sh is not in this port"
  n=$((n+1)); untestable+=(M15_unfixed_finding)
  echo "UNTESTABLE M18_round_without_report scripts/converge.sh is not in this port"
  n=$((n+1)); untestable+=(M18_round_without_report)
  echo "UNTESTABLE M19_counted_rows_respelled scripts/converge.sh is not in this port"
  n=$((n+1)); untestable+=(M19_counted_rows_respelled)
  echo "UNTESTABLE M21_empty_report         scripts/converge.sh is not in this port"
  n=$((n+1)); untestable+=(M21_empty_report)
fi

# M16/M17 round 21's R21-3: a COUNTED evidence file citing a commit no history contains must be found
# whatever shape it takes. M16 hides the commit under "tree" (the rule read only "commit"); M17 makes the
# file unparseable (it was `continue`d in silence, so nothing in it was ever read).
DEADREV=deadbee1234567890abcdef1234567890abcdef1
if [[ -f scripts/claims-audit.py && -d perf/evidence ]]; then
  # M16 needs git: `reachable()` answers True when git cannot run (by design — the check may add
  # findings, never stop the audit), and `copy` does not copy `.git`, so without it EVERY commit looks
  # reachable and this mutation cannot be caught. The copy therefore links the real `.git` (the audit's
  # only git use is `merge-base --is-ancestor` and `check-ignore`, both read-only).
  # Its control is the SAME tree before the file is planted, not the shared baseline: with `.git` present
  # the audit may report other things the baseline never sees, and then a leak would read as a catch.
  D="$(copy m16)"; n=$((n+1)); ln -s "$PWD/.git" "$D/.git" 2>/dev/null
  ( cd "$D" && python3 scripts/claims-audit.py --verbose ) >"$T/M16.control.log" 2>&1
  printf '{"kind":"counted","after":{"tree":"%s","instructions":10}}\n' "$DEADREV" >"$D/perf/evidence/COUNTED.selftest-m16.json"
  ( cd "$D" && python3 scripts/claims-audit.py --verbose ) >"$T/M16.log" 2>&1
  if grep -q 'COUNTED.selftest-m16.json' "$T/M16.control.log"; then
    printf 'UNTESTABLE %-24s the control run already names the planted file\n' M16_counted_tree_unreachable
    untestable+=(M16_counted_tree_unreachable)
  elif grep -q 'COUNTED.selftest-m16.json' "$T/M16.log"; then
    printf 'CAUGHT     %-24s %s\n' M16_counted_tree_unreachable "an unreachable commit under \"tree\""; caught=$((caught+1))
  else
    printf 'LEAK       %-24s the unreachable commit under "tree" was not reported\n' M16_counted_tree_unreachable
    leaked+=(M16_counted_tree_unreachable)
  fi
  D="$(copy m17)"
  printf '{"kind":"counted", this is not json\n' >"$D/perf/evidence/COUNTED.selftest-m17.json"
  expect M17_counted_unparseable "$b_audit" 1 "$D" python3 scripts/claims-audit.py
  # M20 the claims-audit half of M19 (R22-2, R23-2; a4 checked it by hand and asked for it here): a gate
  # repaired and tested alone is how R22-2 happened, so the audit must refuse the same re-spelled report.
  if [[ -f docs/reviews/round-21.md ]]; then
    D="$(copy m20)"
    sed 's/^\(| 21 | .*\)| 2 | 2 | no |/\1| 0 | 0 | yes |/' docs/PORT_STATE.md >"$D/docs/PORT_STATE.md"
    sed 's/^| R21-\([0-9]*\) | MEDIUM | BEHAVIOR/| R21-\1 | Medium | Behaviour/' docs/reviews/round-21.md >"$D/docs/reviews/round-21.md"
    expect M20_audit_counted_respelled "$b_audit" 1 "$D" python3 scripts/claims-audit.py
  else
    echo "UNTESTABLE M20_audit_counted_respelled docs/reviews/round-21.md is not in this port"
    n=$((n+1)); untestable+=(M20_audit_counted_respelled)
  fi
  # M22 R23-3: an unreachable commit in ANY file under perf/evidence, here a plain note in a subdirectory,
  # after a letter (`frozen...`): the rule fails closed over every hex run. It needs git, as M16 does.
  D="$(copy m22)"; n=$((n+1)); ln -s "$PWD/.git" "$D/.git" 2>/dev/null
  ( cd "$D" && python3 scripts/claims-audit.py ) >"$T/M22.control.log" 2>&1
  mkdir -p "$D/perf/evidence/old" && printf 'binary: /scratch/frozen%s/toon\n' "${DEADREV:0:7}" >"$D/perf/evidence/old/selftest-m22.txt"
  ( cd "$D" && python3 scripts/claims-audit.py ) >"$T/M22.log" 2>&1
  if grep -q 'selftest-m22.txt' "$T/M22.control.log"; then
    printf 'UNTESTABLE %-24s the control run already names the planted file\n' M22_evidence_any_file; untestable+=(M22_evidence_any_file)
  elif grep -q 'selftest-m22.txt' "$T/M22.log"; then
    printf 'CAUGHT     %-24s %s\n' M22_evidence_any_file "an unreachable commit in a note under perf/evidence/old/"; caught=$((caught+1))
  else
    printf 'LEAK       %-24s the unreachable commit in perf/evidence/old/ was not reported\n' M22_evidence_any_file; leaked+=(M22_evidence_any_file)
  fi
else
  echo "UNTESTABLE M16_counted_tree_unreachable  scripts/claims-audit.py or perf/evidence/ is not in this port"
  n=$((n+1)); untestable+=(M16_counted_tree_unreachable)
  echo "UNTESTABLE M17_counted_unparseable       scripts/claims-audit.py or perf/evidence/ is not in this port"
  n=$((n+1)); untestable+=(M17_counted_unparseable)
  echo "UNTESTABLE M20_audit_counted_respelled  scripts/claims-audit.py or perf/evidence/ is not in this port"
  n=$((n+1)); untestable+=(M20_audit_counted_respelled)
  echo "UNTESTABLE M22_evidence_any_file         scripts/claims-audit.py or perf/evidence/ is not in this port"
  n=$((n+1)); untestable+=(M22_evidence_any_file)
fi

# M23/M24 and control C1 (round 24's R24-1 and R24-2). M23's decoy KEEPS EVERY ROW, so the counted total
# still equals the rounds-table row and every id named still has a row: the counts agreeing is what
# disarmed every downstream check, and a decoy that changed them would be caught by the count rule alone
# rather than by the reader. The visible table is re-headed so the line reader cannot see it at all.
if [[ -f scripts/review_report.py && -f docs/reviews/round-23.md ]]; then
  D="$(copy m23)"
  python3 "$HERE/.hst-decoy.py" "$D/docs/reviews/round-23.md" hide
  expect_says M23_report_decoy_in_comment 'round 23' "$D" scripts/converge.sh docs/PORT_STATE.md
  # M24 needs git for the same reason M16 does, and it LEAKED once for exactly that reason before this
  # comment existed: reachable() answers True when git cannot run (by design -- the check may add
  # findings, never stop the audit), and copy() does not copy .git, so without it every commit looks
  # reachable and an unreachable one cannot be caught. Its control is the SAME tree before the file is
  # planted, not the shared baseline: with .git present the audit reports things the baseline never sees.
  D="$(copy m24)"; n=$((n+1)); ln -s "$PWD/.git" "$D/.git" 2>/dev/null
  ( cd "$D" && python3 scripts/claims-audit.py --verbose ) >"$T/M24.control.log" 2>&1
  mkdir -p "$D/linked-evidence"
  printf '{"kind":"counted","after":{"commit":"%s","instructions":10}}\n' "$DEADREV" >"$D/linked-evidence/COUNTED.selftest-m24.json"
  ln -s "$D/linked-evidence" "$D/perf/evidence/linked"
  ( cd "$D" && python3 scripts/claims-audit.py --verbose ) >"$T/M24.log" 2>&1
  if grep -q 'COUNTED.selftest-m24.json' "$T/M24.control.log"; then
    printf 'UNTESTABLE %-24s the control run already names the planted file\n' M24_evidence_symlinked_dir
    untestable+=(M24_evidence_symlinked_dir)
  elif grep -q 'COUNTED.selftest-m24.json' "$T/M24.log"; then
    printf 'CAUGHT     %-24s %s\n' M24_evidence_symlinked_dir "a file under a symlinked subdirectory of perf/evidence"; caught=$((caught+1))
  else
    printf 'LEAK       %-24s the file under the symlinked subdirectory was not read\n' M24_evidence_symlinked_dir
    leaked+=(M24_evidence_symlinked_dir)
  fi
  # M25 the fourth member of R24-1's family: the real table in a BLOCKQUOTE, a decoy at top level with
  # every id and row count kept and only sev and class downgraded. Unlike M23 this one was ALREADY
  # caught before the round-25 repair, and by a check that is not the reader: the rounds table of
  # PORT_STATE records the counted total independently, so a decoy of all-LOW/DOCUMENT rows contradicts
  # it ("the table says 2 counted finding(s)"). It is kept because R25-1 replaces the line-based reader
  # with a real Markdown parser, which DOES parse a table inside a blockquote as a table -- so "which of
  # the two tables is authoritative" becomes a live question that the line reader never had, and this is
  # the test that the rewrite kept the property. Standalone, on the tree of 491c8ea, three constructions
  # were tried and the first two were caught for reasons that had nothing to do with blockquotes: rows
  # dropped (the cross-reference rule: an id named in prose with no row) and a class cell outside the
  # vocabulary (the grammar check). The quoted table with NO decoy at all fails CLOSED, reporting
  # "0 findings tables", which is why a blockquote alone cannot produce a false CONVERGED.
  D="$(copy m25)"
  python3 "$HERE/.hst-decoy.py" "$D/docs/reviews/round-23.md" block
  expect_says M25_report_table_in_quote 'round 23' "$D" scripts/converge.sh docs/PORT_STATE.md
  # M26/M27/M28 the three shapes the author's sweep after round 25 found, repaired in da95d0e by the
  # reviewer who owned those files at the time, and planted here so a later rewrite of any of them
  # reopens a hole loudly. Each LEAKED on 5ea1ff6 and is asserted on the MESSAGE of the gate that
  # now catches it, which differs per shape -- the point of the sweep was that the three gates do not
  # cover the same ground. Each plant ASSERTS it changed the file: a plant that silently no-ops (a
  # phrase another agent has since reworded) would report a LEAK and be read as a broken gate.
  D="$(copy m26)"
  python3 - "$D/docs/PORT_STATE.md" <<'PLANT'
import re, sys
from pathlib import Path
p = Path(sys.argv[1]); t = p.read_text(encoding='utf-8')
row = next(l for l in t.split('\n') if re.match(r'^\|\s*24\s*\|', l))
c = row.split('|')                       # append to the lens cell: no phrase to match, so it cannot no-op
c[2] = c[2].rstrip() + ' R24-9 (a MEDIUM behaviour finding recorded in this row only) '
assert '|'.join(c) != row
p.write_text(t.replace(row, '|'.join(c), 1), encoding='utf-8')
PLANT
  expect_says M26_rounds_row_prose_only 'names R24-9' "$D" scripts/converge.sh docs/PORT_STATE.md
  D="$(copy m27)"
  python3 - "$D/docs/reviews" <<'PLANT'
import os, subprocess, sys
rev = subprocess.run(['git', 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip()[:12]
assert len(rev) == 12, 'no HEAD to name as the reviewed commit'
with open(os.path.join(sys.argv[1], 'round-99.md'), 'w', encoding='utf-8') as fh:
    fh.write('# Round 99\n\n| reviewed commit | %s |\n|---|---|\n| lens | non-author hostile review |\n\n'
             '| id | sev | class | what |\n|---|---|---|---|\n'
             '| R99-1 | MEDIUM | BEHAVIOR | a gate that lies |\n' % rev)
PLANT
  expect_says M27_report_without_row 'no row 99' "$D" scripts/converge.sh docs/PORT_STATE.md
  # M28 is claims-audit's half: converge.sh ALREADY refused a non-numeric round cell ("round number must
  # be a positive integer"), and the author first reported it as unread by both gates after grepping for
  # words that message does not contain. Only the audit was blind, so only the audit is asserted here.
  D="$(copy m28)"; n=$((n+1))
  python3 - "$D/docs/PORT_STATE.md" <<'PLANT'
import re, sys
from pathlib import Path
p = Path(sys.argv[1]); t = p.read_text(encoding='utf-8')
row = next(l for l in t.split('\n') if re.match(r'^\|\s*24\s*\|', l))
c = row.split('|'); c[1] = ' 24b '; c[3], c[4], c[5] = ' 2 ', ' 0 ', ' no '
assert '|'.join(c) != row
p.write_text(t.replace(row, row + '\n' + '|'.join(c), 1), encoding='utf-8')
PLANT
  ( cd "$D" && python3 scripts/claims-audit.py ) >"$T/M28.log" 2>&1
  if grep -q 'is not a number is read by no rule' "$T/M28.log"; then
    printf 'CAUGHT     %-24s %s\n' M28_round_cell_not_a_number "a rounds-table row whose round cell is not a number"; caught=$((caught+1))
  else
    printf 'LEAK       %-24s the 24b row was read by no rule and reported by none\n' M28_round_cell_not_a_number
    leaked+=(M28_round_cell_not_a_number)
  fi
  # M29 an unreachable commit hidden from a RAW-TEXT scan by JSON string escapes, in a COUNTED file.
  # The construction is the whole test and took three tries to get right, so it is spelled out: the
  # finding branch flags any unreachable hex run of 7+ characters, while the 20-character floor governs
  # only the EXEMPTION. A `\u` escape inside a hex string always contributes `00` plus two hex digits,
  # so ONE escape leaves a 43-character run and two leave 13/17/16 -- each independently a finding, and
  # the gate then goes red WITHOUT EVER NAMING the hidden commit, which reads exactly like a catch while
  # testing nothing. Escaping every THIRD character puts every raw fragment at 6, under the floor of the
  # finding branch itself, and only then does the commit vanish from a raw scan. It LEAKED on 491c8ea and
  # is caught since R25-2, which decodes the escapes -- so the assertion is on the DECODED commit, not on
  # any fragment: a repair that merely flagged the fragments again would not satisfy it.
  D="$(copy m29)"; n=$((n+1)); ln -s "$PWD/.git" "$D/.git" 2>/dev/null
  ( cd "$D" && python3 scripts/claims-audit.py --verbose ) >"$T/M29.control.log" 2>&1
  python3 - "$D/perf/evidence/COUNTED.selftest-m29.json" "$DEADREV" <<'PLANT'
import json, sys
from pathlib import Path
out, rev = sys.argv[1], sys.argv[2]
esc = ''.join('\\u%04x' % ord(c) if k % 3 == 2 else c for k, c in enumerate(rev))
Path(out).write_text('{"kind":"counted","after":{"commit":"%s","instructions":10}}\n' % esc, encoding='utf-8')
raw = Path(out).read_text(encoding='utf-8')
import re
assert not re.findall(r'(?<![0-9A-Fa-f])[0-9A-Fa-f]{7,}(?![0-9A-Fa-f])', raw), \
    'a raw fragment reached the finding floor: this would be caught for the wrong reason'
assert json.loads(raw)['after']['commit'] == rev, 'the escape does not decode to the planted commit'
PLANT
  ( cd "$D" && python3 scripts/claims-audit.py --verbose ) >"$T/M29.log" 2>&1
  if grep -q "$DEADREV" "$T/M29.control.log"; then
    printf 'UNTESTABLE %-24s the control run already names the planted commit\n' M29_escaped_commit
    untestable+=(M29_escaped_commit)
  elif grep -q "$DEADREV" "$T/M29.log"; then
    printf 'CAUGHT     %-24s %s\n' M29_escaped_commit "the decoded commit, hidden from a raw scan by \\u escapes"; caught=$((caught+1))
  else
    printf 'LEAK       %-24s the escaped commit was not named (fragments alone do not count)\n' M29_escaped_commit
    leaked+=(M29_escaped_commit)
  fi
  # M30 an ACCEPTED DISC that has lost its `Approver:` line -- a deliberate divergence licensed with no
  # recorded owner approval. AGENTS.md says a divergence "exists only as a DISC- entry ... with a class, a
  # kill-switch, the affected cases, a measured impact and the owner's approval"; the heading's class and
  # status were checked and claims-audit checks the impact DENOMINATOR, but the PRESENCE of those four
  # lines was checked nowhere until the author's sweep of this family. Deleting the `Kill-switch:` or the
  # `Affected cases:` line leaks identically and is caught by the same rule; the approver is planted
  # because it is the line whose absence licenses the most. Unlike R21-2's shape this needs only ONE gate:
  # converge.sh computes the register's completeness, and no second gate asserts that property by another
  # route (claims-audit asserts the DISC COUNTS and the impact denominator, which are different claims).
  D="$(copy m30)"
  python3 - "$D/docs/DISCREPANCIES.md" <<'PLANT'
import re, sys
from pathlib import Path
p = Path(sys.argv[1]); t = p.read_text(encoding='utf-8')
m = re.search(r'^###\s+(DISC-\d+)[^\n]*\|\s*ACCEPTED\s*\]\s*$(.*?)(?=^#{1,3}\s|\Z)', t, re.M | re.S)
assert m, 'no ACCEPTED DISC entry to strip'
line = next(l for l in m.group(2).split('\n') if l.startswith('- Approver:'))
p.write_text(t[:m.start(2)] + m.group(2).replace(line + '\n', '', 1) + t[m.end(2):], encoding='utf-8')
assert '- Approver:' not in Path(sys.argv[1]).read_text(encoding='utf-8')[m.start(2):m.end(2)]
PLANT
  expect_says M30_accepted_disc_no_approver 'without a .Approver' "$D" scripts/converge.sh docs/PORT_STATE.md
  # M31 a findings table hidden behind a FULLWIDTH fence, with a fullwidth decoy (R26-1, a defect INSIDE
  # R25-1's repair). NFKC folds U+FF40 to a backtick and U+FF5C/U+FF0D to a pipe and a hyphen, so a reader
  # of the RENDERED report sees literal fullwidth text where a reader that folds BEFORE parsing sees a fence
  # and a table: folding is right for comparing cell TEXT and wrong before structural parsing. Both halves
  # are planted because neither leaks alone -- the fence by itself makes the reader find 0 tables and fail
  # CLOSED, and a decoy whose counted total differs from the rounds row is caught by the count rule, which
  # has nothing to do with folding. Leak confirmed on b5ac14b: the reader read one LOW/DOCUMENT row and
  # counted 0 where markdown-it renders HIGH/BEHAVIOR from the raw text.
  D="$(copy m31)"
  python3 - "$D/docs/reviews/round-23.md" "$D/docs/PORT_STATE.md" <<'PLANT'
import re, sys
from pathlib import Path
rep, state = Path(sys.argv[1]), Path(sys.argv[2])
P, H, T = '｜', '－', '｀'          # fullwidth pipe, hyphen-minus, grave accent
t = rep.read_text(encoding='utf-8')
lines = t.split('\n')
i = next(k for k, l in enumerate(lines) if re.match(r'^\|\s*id\s*\|\s*sev\s*\|\s*class\s*\|', l))
j = i
while j < len(lines) and lines[j].startswith('|'):
    j += 1
real = lines[i:j]
ids = [r.split('|')[1].strip() for r in real[2:]]
assert ids, 'no findings rows to hide'
decoy = ([P + ' id ' + P + ' sev ' + P + ' class ' + P, P + (H * 3 + P) * 3]
         + [P + ' ' + ident.replace('-', H) + ' ' + P + ' LOW ' + P + ' DOCUMENT ' + P for ident in ids])
# The blank lines are load-bearing and cost this mutation one LEAK to learn: with the fullwidth fence
# flush against the table, raw parsing absorbs that line as a table ROW whose id folds to backticks, and
# the report is refused for an unparseable id -- a catch, but of "a stray row breaks parsing" rather than
# of the property under test. Separated, the real table parses cleanly, the fullwidth decoy is not a table
# at all, and what is tested is that the reader reads the REAL table: its count then contradicts the row's.
lines[i:j] = decoy + [''] + [T * 3] + [''] + real + [''] + [T * 3]
rep.write_text('\n'.join(lines), encoding='utf-8')
s = state.read_text(encoding='utf-8')
row = next(l for l in s.split('\n') if re.match(r'^\|\s*23\s*\|', l))
c = row.split('|'); c[3], c[4], c[5] = ' 0 ', ' 0 ', ' yes '
assert '|'.join(c) != row
state.write_text(s.replace(row, '|'.join(c), 1), encoding='utf-8')
PLANT
  expect_says M31_fullwidth_fence_decoy 'says 0 counted finding' "$D" scripts/converge.sh docs/PORT_STATE.md
  # M32 an unreachable commit hidden behind DUPLICATE keys (R26-2, a defect INSIDE R25-2's repair): a second
  # `commit` key hides the first, because `json.loads` keeps only the LAST. It must be COMPOSED with M29's
  # escape construction, or the raw scan still sees a plain 40-character hash and the gate goes red WITHOUT
  # naming the hidden commit -- which would test the raw scan instead of the duplicate key. The plant asserts
  # both halves of that composition, and the assertion is on the hidden commit being NAMED.
  D="$(copy m32)"; n=$((n+1)); ln -s "$PWD/.git" "$D/.git" 2>/dev/null
  ( cd "$D" && python3 scripts/claims-audit.py --verbose ) >"$T/M32.control.log" 2>&1
  python3 - "$D/perf/evidence/COUNTED.selftest-m32.json" "$DEADREV" "$(git rev-parse HEAD)" <<'PLANT'
import json, re, sys
from pathlib import Path
out, dead, live = sys.argv[1], sys.argv[2], sys.argv[3]
esc = ''.join('\\u%04x' % ord(c) if k % 3 == 2 else c for k, c in enumerate(dead))
Path(out).write_text('{"kind":"counted","after":{"commit":"%s","commit":"%s","instructions":10}}\n'
                     % (esc, live), encoding='utf-8')
raw = Path(out).read_text(encoding='utf-8')
assert dead not in raw, 'the hidden commit is literal in the raw text'
assert not [r for r in re.findall(r'(?<![0-9A-Fa-f])[0-9A-Fa-f]{7,}(?![0-9A-Fa-f])', raw) if r != live], \
    'a fragment of the hidden commit reached the raw floor: this would be caught for the wrong reason'
assert json.loads(raw)['after']['commit'] == live, 'the last key is not the reachable one'
PLANT
  ( cd "$D" && python3 scripts/claims-audit.py --verbose ) >"$T/M32.log" 2>&1
  if grep -q "$DEADREV" "$T/M32.control.log"; then
    printf 'UNTESTABLE %-24s the control run already names the planted commit\n' M32_duplicate_commit_key
    untestable+=(M32_duplicate_commit_key)
  elif grep -q "$DEADREV" "$T/M32.log"; then
    printf 'CAUGHT     %-24s %s\n' M32_duplicate_commit_key "the commit hidden behind a duplicate key"; caught=$((caught+1))
  else
    printf 'LEAK       %-24s the commit behind the duplicate key was not named\n' M32_duplicate_commit_key
    leaked+=(M32_duplicate_commit_key)
  fi
  # M33 a wrong closed-law count in README, in the phrasing R26-5's repair widened the pattern to cover.
  # The count patterns required the digits IMMEDIATELY before the noun and knew only "closed laws", so
  # "N are closed instances" -- the sentence README actually uses -- was checked by nothing and a split that
  # did not sum to the total printed OK. Three variants isolated it on b5ac14b: "999 closed laws" was
  # already caught, while "999 are closed laws" and "999 closed instances" were both QUIET, so the plant
  # must use the real sentence's shape or it tests the spelling that already worked.
  D="$(copy m33)"
  python3 - "$D/README.md" <<'PLANT'
import re, sys
from pathlib import Path
p = Path(sys.argv[1]); t = p.read_text(encoding='utf-8')
m = re.search(r'\b(\d+) are closed instances\b', t)
assert m, 'README no longer says "<n> are closed instances"; re-derive this plant against its new wording'
p.write_text(t[:m.start(1)] + str(int(m.group(1)) + 7) + t[m.end(1):], encoding='utf-8')
PLANT
  expect M33_readme_closed_count "$b_audit" 1 "$D" python3 scripts/claims-audit.py
  # M34 inline HTML strikethrough in a sev cell (R27-1, a defect INSIDE R25-1/R26-1's repair). `_text`
  # collected text and code and skipped the `~~` strikethrough tokens, but inline HTML tags were dropped
  # while the text INSIDE them was kept, so a browser showed `LOW` struck out and the gate read it. The
  # struck text must come FIRST, because the reader takes the cell's first word: probed on b5ac14b,
  # `<del>LOW</del> MEDIUM`, `<s>LOW</s> MEDIUM` and `<span hidden>LOW</span> MEDIUM` each read sev LOW
  # with counted 0, while `~~LOW~~ MEDIUM` correctly read MEDIUM with counted 1 -- the asymmetry that WAS
  # the finding. That asymmetry is GONE as of round 29's source-text contract (c0fd6df): a sev cell must be
  # exactly HIGH, MEDIUM or LOW as written, so `~~LOW~~ MEDIUM` is now an error too and is no longer a
  # control. The plant still fires the inline-HTML rule, which is refused whatever the header, so the
  # assertion below is unchanged and still passes for its own rule.
  D="$(copy m34)"
  python3 - "$D/docs/reviews/round-23.md" <<'PLANT'
import re, sys
from pathlib import Path
p = Path(sys.argv[1]); t = p.read_text(encoding='utf-8')
lines = t.split('\n')
i = next(k for k, l in enumerate(lines) if re.match(r'^\|\s*id\s*\|\s*sev\s*\|\s*class\s*\|', l))
row = next(k for k in range(i + 2, len(lines))
           if lines[k].startswith('|') and re.search(r'\|\s*\**MEDIUM\**\s*\|', lines[k]))
c = lines[row].split('|')
sev = next(j for j, x in enumerate(c) if re.fullmatch(r'\s*\**MEDIUM\**\s*', x))
c[sev] = ' <del>LOW</del> MEDIUM '          # a browser strikes the LOW; the old reader took it as the sev
lines[row] = '|'.join(c)
assert '<del>' in lines[row]
p.write_text('\n'.join(lines), encoding='utf-8')
PLANT
  expect_says M34_html_strike_in_sev 'inline HTML' "$D" scripts/converge.sh docs/PORT_STATE.md
  # M35 an escaped commit in a JSONL evidence file with ONE unparseable line (R27-2, a defect INSIDE
  # R25-2/R26-2's repair): the bad line made the WHOLE file fall back to the raw scan, where \u escapes stay
  # encoded. Probed on 3424efa with its own control -- the same file WITHOUT the bad line was CAUGHT, so the
  # bad line is the cause and not the escape. This is the ONLY exercise of that branch: perf/evidence holds
  # one .jsonl file, it has no unparseable line, and no evidence file carries a literal \uXXXX escape today.
  D="$(copy m35)"; n=$((n+1)); ln -s "$PWD/.git" "$D/.git" 2>/dev/null
  ( cd "$D" && python3 scripts/claims-audit.py --verbose ) >"$T/M35.control.log" 2>&1
  python3 - "$D/perf/evidence/COUNTED.selftest-m35.jsonl" "$DEADREV" "$(git rev-parse HEAD)" <<'PLANT'
import json, re, sys
from pathlib import Path
out, dead, live = sys.argv[1], sys.argv[2], sys.argv[3]
esc = ''.join('\\u%04x' % ord(c) if k % 3 == 2 else c for k, c in enumerate(dead))
Path(out).write_text('{"kind":"counted","after":{"commit":"%s","instructions":10}}\n'
                     '{this line is not JSON\n'
                     '{"kind":"counted","after":{"commit":"%s","instructions":11}}\n' % (esc, live),
                     encoding='utf-8')
raw = Path(out).read_text(encoding='utf-8')
assert dead not in raw, 'the hidden commit is literal in the raw text'
assert not [r for r in re.findall(r'(?<![0-9A-Fa-f])[0-9A-Fa-f]{7,}(?![0-9A-Fa-f])', raw) if r != live], \
    'a fragment of the hidden commit reached the raw floor: this would be caught for the wrong reason'
assert sum(1 for l in raw.split('\n') if l.strip() and not l.startswith('{"kind"')) == 1, 'need one bad line'
PLANT
  ( cd "$D" && python3 scripts/claims-audit.py --verbose ) >"$T/M35.log" 2>&1
  if grep -q "$DEADREV" "$T/M35.control.log"; then
    printf 'UNTESTABLE %-24s the control run already names the planted commit\n' M35_jsonl_bad_line_escape
    untestable+=(M35_jsonl_bad_line_escape)
  elif grep -q "$DEADREV" "$T/M35.log"; then
    printf 'CAUGHT     %-24s %s\n' M35_jsonl_bad_line_escape "the escaped commit beside an unparseable JSONL line"; caught=$((caught+1))
  else
    printf 'LEAK       %-24s the escaped commit beside a bad JSONL line was not named\n' M35_jsonl_bad_line_escape
    leaked+=(M35_jsonl_bad_line_escape)
  fi
  # M36 a mutant count OVERSTATED beside three-digit ids, the reviewer's own suggestion after they widened
  # `\bM\d\d\b` to `\bM\d{2,}\b` so that a scoped run of M104..M108 stops reading as a claim about the whole
  # inventory. That exemption is deliberately one-sided -- it applies only when the stated count is SMALLER
  # than the inventory -- and this plant is what holds it one-sided, because the same widening would
  # otherwise be a licence to overstate beside any two three-digit ids.
  D="$(copy m36)"
  python3 - "$D/docs/PORT_STATE.md" <<'PLANT'
import sys
from pathlib import Path
p = Path(sys.argv[1])
p.write_text(p.read_text(encoding='utf-8') +
             '\n- law admission, planted: `python3 scripts/hand-mutants.py M104 M105 M106 M107 M108` -> '
             '`{"mutants": 999, "killed": 999, "survived": [], "verdict": "STRONG"}`\n', encoding='utf-8')
PLANT
  expect M36_mutant_count_overstated "$b_audit" 1 "$D" python3 scripts/claims-audit.py
  # M37/M38 round 28's shapes, and they must be planted SEPARATELY. R28-1 moved one row up from R27-1: the
  # body-HTML refusal did not cover the HEADER, so `<del>sev</del> | sev` there chose which column was read.
  # The obvious single plant is wrong: with `<del>sev</del> | sev` BOTH rules fire, because markdown-it keeps
  # the struck text node, so the mutation would pass on whichever error came first and prove nothing about
  # either rule. So M37 carries the header tag and no duplicate-looking column pair beyond it, and M38 is a
  # plain `sev | sev` header with no HTML anywhere. Both LEAKED on fb20875: sev read LOW, counted 0, NO
  # errors, while a reader of the rendered report sees the MEDIUM in the second column.
  D="$(copy m37)"
  python3 - "$D/docs/reviews/round-23.md" html <<'PLANT'
import re, sys
from pathlib import Path
p, mode = Path(sys.argv[1]), sys.argv[2]
lines = p.read_text(encoding='utf-8').split('\n')
i = next(k for k, l in enumerate(lines) if re.match(r'^\|\s*id\s*\|\s*sev\s*\|\s*class\s*\|', l))
c = lines[i].split('|')
sev = next(j for j, x in enumerate(c) if x.strip().lower() == 'sev')
c[sev] = ' <del>sev</del> ' if mode == 'html' else ' sev '
lines[i] = '|'.join(c)
assert ('<del>' in lines[i]) == (mode == 'html')
p.write_text('\n'.join(lines), encoding='utf-8')
PLANT
  expect_says M37_header_html 'a cell contains inline HTML' "$D" scripts/converge.sh docs/PORT_STATE.md
  D="$(copy m38)"
  python3 - "$D/docs/reviews/round-23.md" <<'PLANT'
import re, sys
from pathlib import Path
p = Path(sys.argv[1]); lines = p.read_text(encoding='utf-8').split('\n')
i = next(k for k, l in enumerate(lines) if re.match(r'^\|\s*id\s*\|\s*sev\s*\|\s*class\s*\|', l))
c = lines[i].split('|')
sev = next(j for j, x in enumerate(c) if x.strip().lower() == 'sev')
c.insert(sev + 1, ' sev ')                      # a SECOND sev column, no HTML anywhere
lines[i] = '|'.join(c)
d = lines[i + 1].split('|'); d.insert(sev + 1, '---'); lines[i + 1] = '|'.join(d)
for k in range(i + 2, len(lines)):
    if not lines[k].startswith('|'):
        break
    r = lines[k].split('|'); r.insert(sev + 1, ' LOW '); lines[k] = '|'.join(r)
assert lines[i].lower().count('| sev |') >= 1
p.write_text('\n'.join(lines), encoding='utf-8')
PLANT
  # The duplicate-column rule NO LONGER EXISTS: round 29's exact-header contract subsumed it, and the phrase
  # is absent from review_report.py, so this plant reported LEAK while the report was refused. A duplicated
  # `sev` header is still a distinct lie shape (a reader sees two columns, the gate picks one) and the
  # contract is the only rule it can reach, so it is re-pointed rather than dropped.
  expect_says M38_duplicate_sev_column 'it must be exactly `| id | sev | class | what | spec |`' "$D" \
    scripts/converge.sh docs/PORT_STATE.md
  # M39 the edge M36 missed, and round 28 found: the mutant-selection exemption also excused PROSE totals,
  # not only a pasted `"mutants": N`. Isolated with a one-variable control on fb20875 -- the same prose total
  # with the two ids REMOVED was CAUGHT ("mutants in all: says 50, the repository has 107"), so the exemption
  # is the cause rather than the phrasing. An exemption has more than one dimension, the direction of the
  # error and the set of counts it covers, and M36 held only the first.
  D="$(copy m39)"
  python3 - "$D/docs/PORT_STATE.md" <<'PLANT'
import sys
from pathlib import Path
p = Path(sys.argv[1])
p.write_text(p.read_text(encoding='utf-8') +
             '\n- planted: `scripts/hand-mutants.py M104 M105` covers 50 mutants in all\n', encoding='utf-8')
PLANT
  expect M39_mutant_prose_total "$b_audit" 1 "$D" python3 scripts/claims-audit.py
  # M40 a `Severity:` header — the second shape pinned to round 29's exact-header contract (e33925e). One
  # rule, two shapes: M38's duplicated column and this respelling both reach only the contract, and the
  # reviewer's per-shape firing table says each fires the contract error ALONE, so neither can pass for
  # another rule's reason.
  D="$(copy m40)"
  python3 - "$D/docs/reviews/round-23.md" <<'PLANT'
import re, sys
from pathlib import Path
p = Path(sys.argv[1]); lines = p.read_text(encoding='utf-8').split('\n')
i = next(k for k, l in enumerate(lines) if re.match(r'^\|\s*id\s*\|\s*sev\s*\|\s*class\s*\|', l))
c = lines[i].split('|')
j = next(k for k, x in enumerate(c) if x.strip().lower() == 'sev')
c[j] = ' Severity: '
lines[i] = '|'.join(c)
assert 'Severity:' in lines[i]
p.write_text('\n'.join(lines), encoding='utf-8')
PLANT
  expect_says M40_severity_header 'it must be exactly `| id | sev | class | what | spec |`' "$D" \
    scripts/converge.sh docs/PORT_STATE.md
  # M41 an invisible format character (U+200B) in a findings BODY cell, with an EXACT header. The placement
  # is the reviewer's shape test rather than a guess: a Cf character in the HEADER fires the Cf error AND the
  # contract error, so the plant would pass on either; in a body sev cell it fires the Cf error beside the
  # sev-vocabulary error and NO contract error, so the asserted phrase pins the Cf rule.
  D="$(copy m41)"
  python3 - "$D/docs/reviews/round-23.md" <<'PLANT'
import re, sys
from pathlib import Path
p = Path(sys.argv[1]); lines = p.read_text(encoding='utf-8').split('\n')
i = next(k for k, l in enumerate(lines) if re.match(r'^\|\s*id\s*\|\s*sev\s*\|\s*class\s*\|', l))
row = next(k for k in range(i + 2, len(lines)) if lines[k].startswith('|'))
c = lines[row].split('|')
j = next(k for k, x in enumerate(c) if x.strip() in ('HIGH', 'MEDIUM', 'LOW'))
c[j] = c[j].replace(c[j].strip(), c[j].strip() + '​')      # a zero-width space a reader cannot see
lines[row] = '|'.join(c)
assert '​' in lines[row] and lines[i].strip().startswith('| id | sev | class')
p.write_text('\n'.join(lines), encoding='utf-8')
PLANT
  expect_says M41_cf_in_findings_cell 'invisible format character' "$D" scripts/converge.sh docs/PORT_STATE.md
  # M42/M43 the two halves of round 29's paste-scope rule (R29-2): a pasted `"mutants": N` is judged against
  # the ids ITS OWN command lists, else a range named since the previous paste, else the whole inventory. The
  # two shapes test opposite sides of one rule, which is why both are planted: a count that disagrees with its
  # command's ids, and a count that disagrees with its stated range.
  D="$(copy m42)"
  python3 - "$D/docs/PORT_STATE.md" <<'PLANT'
import sys
from pathlib import Path
p = Path(sys.argv[1])
p.write_text(p.read_text(encoding='utf-8') +
             '\n- planted: `python3 scripts/hand-mutants.py M120 M121` -> `{"mutants": 5, "killed": 5, '
             '"survived": [], "verdict": "STRONG"}`\n', encoding='utf-8')
PLANT
  expect_says M42_paste_vs_command_ids 'ids its hand-mutants.py command lists' "$D" python3 scripts/claims-audit.py
  D="$(copy m43)"
  python3 - "$D/docs/PORT_STATE.md" <<'PLANT'
import sys
from pathlib import Path
p = Path(sys.argv[1])
p.write_text(p.read_text(encoding='utf-8') +
             '\n- planted: the run covered M01 to M10 -> `{"mutants": 99, "killed": 99, "survived": [], '
             '"verdict": "STRONG"}`\n', encoding='utf-8')
PLANT
  expect_says M43_paste_vs_stated_range 'inventory ids in M1 to M10' "$D" python3 scripts/claims-audit.py
  # C1: the same decoy, but the visible table is left CORRECT and the hidden copy carries a DIFFERENT
  # count. Nothing a reader sees is wrong, so the gate must stay silent; if it speaks, it is reading what
  # no reader sees. This is the shape that was wrongly refused before round 24's repair.
  D="$(copy c1)"
  python3 "$HERE/.hst-decoy.py" "$D/docs/reviews/round-23.md" quote
  expect_quiet C1_hidden_table_ignored 'round 23: docs/reviews/round-23.md' "$D" \
    scripts/converge.sh docs/PORT_STATE.md
else
  echo "UNTESTABLE M23_report_decoy_in_comment  scripts/review_report.py or docs/reviews/round-23.md is not in this port"
  n=$((n+1)); untestable+=(M23_report_decoy_in_comment)
  echo "UNTESTABLE M24_evidence_symlinked_dir   scripts/review_report.py or docs/reviews/round-23.md is not in this port"
  n=$((n+1)); untestable+=(M24_evidence_symlinked_dir)
  echo "UNTESTABLE M25_report_table_in_quote    scripts/review_report.py or docs/reviews/round-23.md is not in this port"
  n=$((n+1)); untestable+=(M25_report_table_in_quote)
  for m in M26_rounds_row_prose_only M27_report_without_row M28_round_cell_not_a_number M29_escaped_commit M30_accepted_disc_no_approver \
              M31_fullwidth_fence_decoy M32_duplicate_commit_key M33_readme_closed_count \
              M34_html_strike_in_sev M35_jsonl_bad_line_escape M36_mutant_count_overstated \
              M37_header_html M38_duplicate_sev_column M39_mutant_prose_total \
              M40_severity_header M41_cf_in_findings_cell M42_paste_vs_command_ids \
              M43_paste_vs_stated_range; do
    echo "UNTESTABLE $m  scripts/review_report.py or docs/reviews/round-23.md is not in this port"
    n=$((n+1)); untestable+=("$m")
  done
fi

verdict=OK
[[ ${#untestable[@]} -gt 0 ]] && verdict=UNTESTABLE
[[ ${#false_positives[@]} -gt 0 ]] && verdict=FALSE_POSITIVE
[[ ${#leaked[@]} -gt 0 ]] && verdict=LEAK
jarr() { local s=""; local x; for x in "$@"; do s+="\"$x\","; done; printf '%s' "${s%,}"; }
j() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1])[1:-1])' "$1"; }
echo "--"
echo "harness-selftest: $caught/$n mutations caught, ${#leaked[@]} leaked, ${#untestable[@]} untestable, $controls_passed/$controls controls quiet → $verdict (scratch: $T)"
printf '{"schema":"p2b.harness-selftest.v1","sha":"%s","bend":"%s","host":"%s","lane":"%s","mutations":%d,"caught":%d,"leaked":[%s],"untestable":[%s],"controls":%d,"controls_passed":%d,"false_positives":[%s],"scratch":"%s","verdict":"%s"}\n' \
  "$sha" "$(j "$bendv")" "$host" "$LANE" "$n" "$caught" "$(jarr ${leaked[@]+"${leaked[@]}"})" "$(jarr ${untestable[@]+"${untestable[@]}"})" "$controls" "$controls_passed" "$(jarr ${false_positives[@]+"${false_positives[@]}"})" "$(j "$T")" "$verdict"
[[ "$verdict" == OK ]]
