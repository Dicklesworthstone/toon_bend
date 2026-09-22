#!/usr/bin/env python3
"""End-to-end benchmark suite: the port against the original on REAL JSON documents.

usage:
  python3 perf/e2e/bench.py fetch   [--corpus DIR]
  python3 perf/e2e/bench.py prepare [--corpus DIR] --reference <toon binary>
  python3 perf/e2e/bench.py run     [--corpus DIR] [--out DIR] --arm NAME=KIND:PATH ... [options]
  python3 perf/e2e/bench.py report  <run dir>

fetch     downloads every document of perf/e2e/corpus.json (pinned upstream commit) into the corpus
          directory (default perf/e2e/corpus/, gitignored) and verifies each sha256; a mismatch is fatal. Then it
          derives the manifest's `derive` entries (prefix slices of a fetched array) and pins them the same way.
prepare   makes the TOON inputs of the decode scenarios with the REFERENCE binary (the pinned original):
          <name>.toon from `--encode`, <name>.fold.toon from `--encode --key-folding safe`.
run       times every (document, scenario) cell on every arm. An arm is NAME=KIND:PATH, where KIND is
            rust  a toon_rust binary, called as PATH ARGS
            bend  a native binary emitted by `bend port/main.bend -o toon`, called as PATH --threads 1 -- ARGS
            js    an emitted toon.js, called through scripts/js-lane.py (adds Python and Bun start-up)
          The FIRST arm is the reference: every other arm's stdout, stderr and exit code are compared with
          it byte for byte on the first (untimed) run of each cell, and every ratio is <arm> / <reference>.
          Then the arms are interleaved in rounds whose order is shuffled by a seeded generator, so drift
          on a shared host lands on every arm alike. The number of rounds is budget / (one round's time),
          clamped to [--min-runs, --max-runs]. Timed runs write stdout to /dev/null.
report    rewrites report.md of a run directory from its cells.jsonl and fingerprint.json.

options of run:
  --scenarios a,b     default: every scenario (encode, encode_stdin, encode_fold, encode_tab, encode_stats,
                      decode, decode_expand)
  --files a,b         default: every document of the manifest; --tiers S,M,L,XL filters by size tier
  --budget S          seconds of timed work per cell (default 30)
  --min-runs N        default 5;  --max-runs N  default 30
  --timeout S         per invocation (default 900); a timeout makes the cell TIMEOUT, not a number
  --max-cv PCT        a cell whose arms exceed it is marked NOISY (default 5; the repository's cv gate)
  --seed N            default 1

Metrics per arm and cell: wall time (median, mean, p95, min, max, cv), user+sys CPU, peak RSS
(of the verification run, read by /usr/bin/time: a child spawned from Python inherits the
Python process's high-water mark across exec, so its own ru_maxrss is useless below ~30 MB), input
throughput in MB/s. Per non-reference arm: the ratio of medians and a
95% bootstrap interval of it (2000 resamples, seeded). Every sample is kept in samples.jsonl.

What this suite measures is the COMMAND, end to end: process start, reading the file, conversion,
writing the output. It is not a library micro-benchmark; start-up is part of every number (and
is measured on its own by the `version` scenario).
"""
import argparse
import hashlib
import json
import math
import os
import platform
import random
import signal
import statistics
import subprocess
import sys
import threading
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
MANIFEST = HERE / 'corpus.json'
DEFAULT_CORPUS = HERE / 'corpus'
JS_LANE = ROOT / 'scripts' / 'js-lane.py'

# Each scenario: the argv after the program (with {json}, {toon}, {fold} standing for the inputs), and
# whether the input is given on stdin instead of as a path.
SCENARIOS = {
    'encode':        {'argv': ['--encode', '{json}'], 'input': 'json'},
    'encode_stdin':  {'argv': ['--encode'], 'input': 'json', 'stdin': True},
    'encode_fold':   {'argv': ['--encode', '--key-folding', 'safe', '{json}'], 'input': 'json'},
    'encode_tab':    {'argv': ['--encode', '--delimiter', '\t', '{json}'], 'input': 'json'},
    'encode_stats':  {'argv': ['--encode', '--stats', '{json}'], 'input': 'json'},
    'decode':        {'argv': ['--decode', '{toon}'], 'input': 'toon'},
    'decode_expand': {'argv': ['--decode', '--expand-paths', 'safe', '{fold}'], 'input': 'fold'},
    'version':       {'argv': ['--version'], 'input': None},
}
DEFAULT_SCENARIOS = [s for s in SCENARIOS if s != 'version']


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def load_manifest():
    with open(MANIFEST, encoding='utf-8') as fh:
        return json.load(fh)


def cmd_fetch(args):
    manifest = load_manifest()
    corpus = Path(args.corpus)
    corpus.mkdir(parents=True, exist_ok=True)
    bad = 0
    for entry in manifest['files']:
        if 'derive' in entry:
            continue
        dest = corpus / (entry['name'] + '.json')
        if dest.is_file() and sha256_file(dest) == entry['sha256']:
            print(f"ok      {entry['name']:18} {entry['bytes']:>9} bytes (cached)")
            continue
        url = manifest['sources'][entry['source']]['raw'] + entry['file']
        tmp = dest.with_suffix('.part')
        with urllib.request.urlopen(url, timeout=120) as resp, open(tmp, 'wb') as out:
            while True:
                chunk = resp.read(1 << 20)
                if not chunk:
                    break
                out.write(chunk)
        got = sha256_file(tmp)
        if got != entry['sha256']:
            print(f"BAD     {entry['name']}: sha256 {got} != pinned {entry['sha256']} ({url})", file=sys.stderr)
            bad += 1
            continue
        os.replace(tmp, dest)
        print(f"fetched {entry['name']:18} {entry['bytes']:>9} bytes")
    for entry in manifest['files']:
        if 'derive' in entry:
            bad += derive(entry, corpus)
    if bad:
        sys.exit(1)


def has_float(v):
    if isinstance(v, float):
        return True
    if isinstance(v, dict):
        return any(has_float(x) for x in v.values())
    if isinstance(v, list):
        return any(has_float(x) for x in v)
    return False


def derive(entry, corpus):
    """The first N records of a fetched document's top-level array, re-serialized compactly (UTF-8 kept). Refused when the
    source holds a non-integer number: Python would re-print its text (1E5 -> 100000.0), and the slice would stop being the
    document's own bytes. Returns 1 on a sha256 mismatch, 0 otherwise."""
    dest = corpus / (entry['name'] + '.json')
    if dest.is_file() and sha256_file(dest) == entry['sha256']:
        print(f"ok      {entry['name']:18} {entry['bytes']:>9} bytes (cached)")
        return 0
    src_path = corpus / (entry['derive']['from'] + '.json')
    with open(src_path, encoding='utf-8') as fh:
        src = json.load(fh)
    if not isinstance(src, list) or has_float(src):
        sys.exit(f"fetch: {src_path} is not a float-free top-level array; {entry['name']} cannot be derived from it")
    data = json.dumps(src[:entry['derive']['records']], ensure_ascii=False, separators=(',', ':')).encode('utf-8')
    if hashlib.sha256(data).hexdigest() != entry['sha256']:
        print(f"BAD     {entry['name']}: derived bytes differ from the pinned sha256", file=sys.stderr)
        return 1
    dest.write_bytes(data)
    print(f"derived {entry['name']:18} {len(data):>9} bytes (first {entry['derive']['records']} records of "
          f"{entry['derive']['from']})")
    return 0


def cmd_prepare(args):
    manifest = load_manifest()
    corpus = Path(args.corpus)
    ref = str(Path(args.reference).resolve())
    for entry in manifest['files']:
        src = corpus / (entry['name'] + '.json')
        if not src.is_file() or sha256_file(src) != entry['sha256']:
            sys.exit(f"prepare: {src} is missing or not the pinned bytes; run `bench.py fetch` first")
        for suffix, extra in (('.toon', []), ('.fold.toon', ['--key-folding', 'safe'])):
            dest = corpus / (entry['name'] + suffix)
            proc = subprocess.run([ref, '--encode', *extra, str(src), '-o', str(dest)],
                                  capture_output=True, timeout=600, check=False)
            if proc.returncode != 0:
                sys.exit(f"prepare: the reference failed on {src} {extra}: {proc.stderr.decode(errors='replace')}")
        print(f"prepared {entry['name']:18} toon {os.path.getsize(corpus / (entry['name'] + '.toon')):>9} bytes"
              f"  fold {os.path.getsize(corpus / (entry['name'] + '.fold.toon')):>9} bytes")


def parse_arm(text):
    name, _, spec = text.partition('=')
    kind, _, path = spec.partition(':')
    if not name or kind not in ('rust', 'bend', 'js') or not path:
        raise argparse.ArgumentTypeError(f'an arm is NAME=rust|bend|js:PATH, not {text!r}')
    path = str(Path(path).resolve())
    if not os.path.isfile(path):
        raise argparse.ArgumentTypeError(f'{path} is not a file')
    return {'name': name, 'kind': kind, 'path': path}


def arm_argv(arm, argv):
    if arm['kind'] == 'rust':
        return [arm['path'], *argv]
    if arm['kind'] == 'bend':
        return [arm['path'], '--threads', '1', '--', *argv]
    return [sys.executable, str(JS_LANE), arm['path'], '--', *argv]


def run_once(cmd, stdin_path, capture, timeout, rss_file):
    """The untimed verification run: keeps stdout and stderr, and reads the peak RSS through GNU time
    (which forks from its own small image, so ru_maxrss is the program's)."""
    timed = ['/usr/bin/time', '-f', '%M', '-o', rss_file, *cmd] if os.access('/usr/bin/time', os.X_OK) else cmd
    with open(stdin_path or os.devnull, 'rb') as stdin:
        t0 = time.perf_counter_ns()
        try:
            proc = subprocess.run(timed, stdin=stdin, stdout=subprocess.PIPE if capture else subprocess.DEVNULL,
                                  stderr=subprocess.PIPE, timeout=timeout, check=False)
        except subprocess.TimeoutExpired:
            return {'timeout': True}
        t1 = time.perf_counter_ns()
    rss = None
    if timed is not cmd:
        try:
            rss = int(Path(rss_file).read_text().split()[-1])
        except (OSError, ValueError, IndexError):
            rss = None
    return {'timeout': False, 'wall_ns': t1 - t0, 'exit': proc.returncode, 'maxrss_kib': rss,
            'stdout': proc.stdout if capture else None, 'stderr': proc.stderr}


def spawn_measured(cmd, stdin_path, timeout):
    """posix_spawn + a blocking wait4: wall time from spawn to reap, and the child's OWN rusage (CPU and
    peak RSS; RUSAGE_CHILDREN would give a running maximum over every child). stdout and stderr go to
    /dev/null. A timer kills the child at the timeout."""
    devnull = os.open(os.devnull, os.O_RDWR)
    stdin_fd = os.open(stdin_path, os.O_RDONLY) if stdin_path else devnull
    killed = []
    try:
        t0 = time.perf_counter_ns()
        pid = os.posix_spawn(cmd[0], cmd, os.environ,
                             file_actions=[(os.POSIX_SPAWN_DUP2, stdin_fd, 0),
                                           (os.POSIX_SPAWN_DUP2, devnull, 1),
                                           (os.POSIX_SPAWN_DUP2, devnull, 2)])
        timer = threading.Timer(timeout, lambda: (killed.append(1), os.kill(pid, signal.SIGKILL)))
        timer.start()
        _, status, ru = os.wait4(pid, 0)
        t1 = time.perf_counter_ns()
        timer.cancel()
    finally:
        os.close(devnull)
        if stdin_path:
            os.close(stdin_fd)
    if killed:
        return {'timeout': True}
    return {'timeout': False, 'wall_ns': t1 - t0, 'exit': os.waitstatus_to_exitcode(status),
            'cpu_ns': int((ru.ru_utime + ru.ru_stime) * 1e9)}


def pctl(sorted_vals, q):
    """Nearest-rank percentile."""
    if not sorted_vals:
        return None
    k = max(0, min(len(sorted_vals) - 1, math.ceil(q * len(sorted_vals)) - 1))
    return sorted_vals[k]


def summarize(samples):
    walls = sorted(s['wall_ns'] / 1e6 for s in samples)
    mean = statistics.fmean(walls)
    sd = statistics.stdev(walls) if len(walls) > 1 else 0.0
    return {
        'n': len(walls), 'median_ms': statistics.median(walls), 'mean_ms': mean,
        'p95_ms': pctl(walls, 0.95), 'min_ms': walls[0], 'max_ms': walls[-1],
        'cv_pct': 100.0 * sd / mean if mean else 0.0,
        'cpu_ms_median': statistics.median(s['cpu_ns'] / 1e6 for s in samples),
    }


def bootstrap_ratio(a, b, rng, reps=2000):
    """95% interval of median(a) / median(b) by resampling each arm independently."""
    ratios = []
    for _ in range(reps):
        ma = statistics.median(rng.choices(a, k=len(a)))
        mb = statistics.median(rng.choices(b, k=len(b)))
        ratios.append(ma / mb)
    ratios.sort()
    return [ratios[int(0.025 * reps)], ratios[int(0.975 * reps) - 1]]


def fingerprint(arms):
    def read(path):
        try:
            return Path(path).read_text().strip()
        except OSError:
            return None
    cpu = None
    for line in (read('/proc/cpuinfo') or '').splitlines():
        if line.lower().startswith('model name'):
            cpu = line.split(':', 1)[1].strip()
            break
    def git(*a):
        try:
            return subprocess.run(['git', '-C', str(ROOT), *a], capture_output=True, text=True, check=False).stdout.strip()
        except OSError:
            return None
    return {
        'utc': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'host': platform.node(), 'kernel': platform.release(), 'cpu': cpu, 'cores': os.cpu_count(),
        'governor': read('/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor'),
        'mem_total_kib': next((int(l.split()[1]) for l in (read('/proc/meminfo') or '').splitlines()
                               if l.startswith('MemTotal')), None),
        'loadavg_start': os.getloadavg(),
        'python': platform.python_version(),
        'git_head': git('rev-parse', 'HEAD'), 'git_dirty_port': bool(git('status', '--porcelain', '--', 'port/')),
        'arms': [{**a, 'sha256': sha256_file(a['path']), 'bytes': os.path.getsize(a['path'])} for a in arms],
    }


def cell_inputs(entry, corpus):
    base = corpus / entry['name']
    return {'json': str(base) + '.json', 'toon': str(base) + '.toon', 'fold': str(base) + '.fold.toon'}


def cmd_run(args):
    manifest = load_manifest()
    corpus = Path(args.corpus)
    arms = args.arm
    if len(arms) < 2:
        sys.exit('run: give at least two arms; the first is the reference')
    scenarios = args.scenarios.split(',') if args.scenarios else DEFAULT_SCENARIOS
    for s in scenarios:
        if s not in SCENARIOS:
            sys.exit(f'run: unknown scenario {s}; known: {", ".join(SCENARIOS)}')
    entries = manifest['files']
    if args.files:
        wanted = args.files.split(',')
        entries = [e for e in entries if e['name'] in wanted]
        missing = set(wanted) - {e['name'] for e in entries}
        if missing:
            sys.exit(f'run: not in the manifest: {", ".join(sorted(missing))}')
    if args.tiers:
        entries = [e for e in entries if e['tier'] in args.tiers.split(',')]
    for e in entries:
        p = corpus / (e['name'] + '.json')
        if not p.is_file() or sha256_file(p) != e['sha256']:
            sys.exit(f'run: {p} is missing or not the pinned bytes; run `bench.py fetch` and `prepare` first')

    out = Path(args.out or HERE / 'results' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
    out.mkdir(parents=True, exist_ok=True)
    fp = fingerprint(arms)
    fp.update({'scenarios': scenarios, 'files': [e['name'] for e in entries], 'budget_s': args.budget,
               'min_runs': args.min_runs, 'max_runs': args.max_runs, 'max_cv_pct': args.max_cv, 'seed': args.seed})
    (out / 'fingerprint.json').write_text(json.dumps(fp, indent=2) + '\n')
    rng = random.Random(args.seed)
    cells_path, samples_path = out / 'cells.jsonl', out / 'samples.jsonl'
    cells_path.write_text('')
    samples_path.write_text('')

    work = [(e, s) for e in entries for s in scenarios if s == 'version' or s in e.get('scenarios', SCENARIOS)]
    if 'version' in scenarios:  # start-up needs no document; one cell is enough
        work = [(e, s) for (e, s) in work if s != 'version'] + [(entries[0], 'version')]
    for entry, scen in work:
        spec = SCENARIOS[scen]
        inputs = cell_inputs(entry, corpus)
        argv = [a.format(**inputs) for a in spec['argv']]
        stdin_path = inputs[spec['input']] if spec.get('stdin') else None
        in_bytes = os.path.getsize(inputs[spec['input']]) if spec['input'] else 0
        label = f"{entry['name'] if spec['input'] else '-'}/{scen}"
        cell = {'file': entry['name'] if spec['input'] else None, 'tier': entry['tier'] if spec['input'] else None,
                'scenario': scen, 'input_bytes': in_bytes, 'argv': argv, 'arms': {},
                'json_bytes': os.path.getsize(inputs['json']) if spec['input'] else 0,
                'series': entry.get('series') if spec['input'] else None,
                'load_start': os.getloadavg()}

        # 1. The verification run of every arm: the bytes must agree with the reference. It is also the warm-up.
        ref_out = None
        verdict, first_ms = 'SAME', {}
        for i, arm in enumerate(arms):
            r = run_once(arm_argv(arm, argv), stdin_path, True, args.timeout, str(out / '.rss'))
            if r['timeout']:
                cell['arms'][arm['name']] = {'status': 'TIMEOUT', 'timeout_s': args.timeout}
                verdict = 'TIMEOUT'
                continue
            first_ms[arm['name']] = r['wall_ns'] / 1e6
            outcome = (r['exit'], hashlib.sha256(r['stdout']).hexdigest(), hashlib.sha256(r['stderr']).hexdigest())
            cell['arms'][arm['name']] = {'exit': r['exit'], 'stdout_sha256': outcome[1], 'stdout_bytes': len(r['stdout']),
                                         'stderr_sha256': outcome[2],
                                         'peak_rss_mb': r['maxrss_kib'] / 1024 if r['maxrss_kib'] else None}
            if i == 0:
                ref_out = outcome
            elif outcome != ref_out and verdict == 'SAME':
                verdict = 'DIFF'
        cell['output'] = verdict
        if verdict == 'TIMEOUT':
            cell['status'] = 'TIMEOUT'
            print(f"{label:34} TIMEOUT (> {args.timeout}s on {[a for a, v in cell['arms'].items() if v.get('status') == 'TIMEOUT']})",
                  flush=True)
            with open(cells_path, 'a', encoding='utf-8') as fh:
                fh.write(json.dumps(cell) + '\n')
            continue

        # 2. Interleaved, shuffled rounds.
        round_s = sum(first_ms.values()) / 1000
        runs = max(args.min_runs, min(args.max_runs, int(args.budget / round_s) if round_s > 0 else args.max_runs))
        samples = {a['name']: [] for a in arms}
        with open(samples_path, 'a', encoding='utf-8') as sfh:
            for rnd in range(runs):
                order = arms[:]
                rng.shuffle(order)
                for arm in order:
                    r = spawn_measured(arm_argv(arm, argv), stdin_path, args.timeout)
                    if r['timeout'] or r['exit'] != cell['arms'][arm['name']]['exit']:
                        sys.exit(f'run: {label} {arm["name"]} changed behavior between runs: {r}')
                    samples[arm['name']].append(r)
                    sfh.write(json.dumps({'file': cell['file'], 'scenario': scen, 'arm': arm['name'], 'round': rnd,
                                          'wall_ns': r['wall_ns'], 'cpu_ns': r['cpu_ns']}) + '\n')
        ref = arms[0]['name']
        ref_walls = [s['wall_ns'] for s in samples[ref]]
        noisy = False
        for arm in arms:
            st = summarize(samples[arm['name']])
            if in_bytes:
                st['mb_per_s'] = in_bytes / 1e6 / (st['median_ms'] / 1000)
            if arm['name'] != ref:
                walls = [s['wall_ns'] for s in samples[arm['name']]]
                st['ratio_vs_ref'] = statistics.median(walls) / statistics.median(ref_walls)
                st['ratio_ci95'] = bootstrap_ratio(walls, ref_walls, rng)
            noisy = noisy or st['cv_pct'] > args.max_cv
            cell['arms'][arm['name']].update(st)
        cell['status'] = 'NOISY' if noisy else 'MEASURED'
        cell['load_end'] = os.getloadavg()
        with open(cells_path, 'a', encoding='utf-8') as fh:
            fh.write(json.dumps(cell) + '\n')
        parts = []
        for arm in arms:
            a = cell['arms'][arm['name']]
            ratio = f" x{a['ratio_vs_ref']:.2f}" if 'ratio_vs_ref' in a else ''
            parts.append(f"{arm['name']} {a['median_ms']:.1f}ms cv{a['cv_pct']:.1f}%{ratio}")
        print(f"{label:34} {verdict:4} {cell['status']:8} n={runs:<3} " + ' | '.join(parts), flush=True)

    fp['loadavg_end'] = os.getloadavg()
    fp['finished_utc'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    (out / 'fingerprint.json').write_text(json.dumps(fp, indent=2) + '\n')
    write_report(out)
    print(f'report: {out / "report.md"}')


def fmt_ms(v):
    if v is None:
        return '-'
    if v >= 10000:
        return f'{v / 1000:.1f} s'
    if v >= 1000:
        return f'{v / 1000:.2f} s'
    return f'{v:.1f} ms' if v >= 10 else f'{v:.2f} ms'


def geomean(xs):
    xs = [x for x in xs if x and x > 0]
    return math.exp(statistics.fmean(math.log(x) for x in xs)) if xs else None


def write_report(out):
    out = Path(out)
    fp = json.loads((out / 'fingerprint.json').read_text())
    cells = [json.loads(l) for l in (out / 'cells.jsonl').read_text().splitlines() if l.strip()]
    arms = [a['name'] for a in fp['arms']]
    ref, others = arms[0], arms[1:]
    L = []
    L.append(f"# toon end-to-end benchmark: {', '.join(arms)}\n")
    L.append(f"Run `{out.name}`, started {fp['utc']}, finished {fp.get('finished_utc', '(unfinished)')}. "
             f"Reference arm: **{ref}**; every ratio is `<arm> median / {ref} median` (above 1 = slower than {ref}).\n")
    L.append('## Environment\n')
    L.append(f"- host `{fp['host']}`, {fp['cpu']}, {fp['cores']} cores, governor `{fp['governor']}`, "
             f"kernel {fp['kernel']}, {round((fp['mem_total_kib'] or 0) / 1048576)} GiB RAM")
    L.append(f"- load average at start {tuple(round(x, 2) for x in fp['loadavg_start'])}, "
             f"at end {tuple(round(x, 2) for x in fp.get('loadavg_end', (0, 0, 0)))} (a shared host)")
    L.append(f"- toon_bend HEAD `{fp['git_head']}`" + (' (port/ has uncommitted changes)' if fp['git_dirty_port'] else ''))
    for a in fp['arms']:
        L.append(f"- arm **{a['name']}** ({a['kind']}): `{a['path']}`, {a['bytes']} bytes, sha256 `{a['sha256'][:16]}…`")
    L.append(f"- budget {fp['budget_s']} s per cell, runs clamped to [{fp['min_runs']}, {fp['max_runs']}], "
             f"arms interleaved in seeded shuffled rounds (seed {fp['seed']}); cv gate {fp['max_cv_pct']}% "
             f"(a cell above it on any arm is NOISY: its ratio is orientation, not evidence)")
    L.append('- timed runs write stdout to /dev/null; the untimed first run of each cell compared stdout, '
             'stderr and exit code of every arm with the reference byte for byte\n')

    def errpath(c):
        return c['arms'].get(ref, {}).get('exit', 0) != 0

    L.append('## Summary\n')
    L.append('A cell whose reference exits non-zero times an ERROR PATH (the same failure on every arm, byte for byte); '
             'it is listed in its table but left out of these geometric means.\n')
    L.append('| scenario | cells | outputs identical | ' + ' | '.join(f'geomean {o}/{ref}' for o in others)
             + ' | ' + ' | '.join(f'range {o}/{ref}' for o in others) + ' |')
    L.append('|---|---|---|' + '---|' * (2 * len(others)))
    for scen in dict.fromkeys(c['scenario'] for c in cells):
        cs = [c for c in cells if c['scenario'] == scen and c['status'] != 'TIMEOUT' and not errpath(c)]
        same = sum(1 for c in cs if c['output'] == 'SAME')
        g, r = [], []
        for o in others:
            rs = [c['arms'][o]['ratio_vs_ref'] for c in cs if 'ratio_vs_ref' in c['arms'].get(o, {})]
            gm = geomean(rs)
            g.append(f'{gm:.1f}×' if gm else '-')
            r.append(f'{min(rs):.1f}× – {max(rs):.1f}×' if rs else '-')
        to = sum(1 for c in cells if c['scenario'] == scen and c['status'] == 'TIMEOUT')
        L.append(f"| {scen} | {len(cs)}{f' (+{to} timeout)' if to else ''} | {same}/{len(cs)} | "
                 + ' | '.join(g) + ' | ' + ' | '.join(r) + ' |')
    L.append('')

    def ratio_of(c, o, key):
        a, b = c['arms'][o].get(key), c['arms'][ref].get(key)
        return a / b if a and b else None

    L.append('### The same ratios by three estimators\n')
    L.append('On a loaded host the median carries the noise of every sample. Two estimators are less sensitive to it: the '
             'MINIMUM over the interleaved samples (contention only ever adds time) and the median CPU time (user + sys of '
             'the child itself, which excludes waiting for a core but not cache or SMT interference). Where the three agree, '
             'the ratio does not depend on the noise. None of them replaces the cv gate: a NOISY cell stays orientation.\n')
    L.append('| scenario | ' + ' | '.join(f'{o}/{ref} median | min | CPU' for o in others) + ' |')
    L.append('|---|' + '---|' * (3 * len(others)))
    for scen in dict.fromkeys(c['scenario'] for c in cells):
        cs = [c for c in cells if c['scenario'] == scen and c['status'] != 'TIMEOUT' and not errpath(c)]
        row = []
        for o in others:
            for key in ('median_ms', 'min_ms', 'cpu_ms_median'):
                gm = geomean([ratio_of(c, o, key) for c in cs])
                row.append(f'{gm:.1f}×' if gm else '-')
        L.append(f'| {scen} | ' + ' | '.join(row) + ' |')
    L.append('')

    ok_cells = [c for c in cells if c['status'] != 'TIMEOUT' and not errpath(c) and c['file']]
    L.append('## By document\n')
    L.append(f'Geometric mean over the scenarios of each document of `<arm> / {ref}`; the MEASURED column counts cells within the '
             'cv gate.\n')
    L.append('| document | tier | JSON size | scenarios | MEASURED | '
             + ' | '.join(f'{o}/{ref} median | min | CPU' for o in others) + ' |')
    L.append('|---|---|---|---|---|' + '---|' * (3 * len(others)))
    for doc in dict.fromkeys(c['file'] for c in ok_cells):
        cs = [c for c in ok_cells if c['file'] == doc]
        gm = [geomean([ratio_of(c, o, key) for c in cs]) for o in others for key in ('median_ms', 'min_ms', 'cpu_ms_median')]
        L.append(f"| {doc} | {cs[0]['tier']} | {cs[0].get('json_bytes', 0) / 1e6:.2f} MB | {len(cs)} | "
                 f"{sum(c['status'] == 'MEASURED' for c in cs)} | " + ' | '.join(f'{g:.1f}×' if g else '-' for g in gm) + ' |')
    L.append('')

    series = {}
    for c in ok_cells:
        if c.get('series'):
            series.setdefault((c['series']['group'], c['scenario']), []).append(c)
    if series:
        L.append('## Scaling\n')
        L.append('Each series is ONE schema at several sizes (records `n`). `b` is the least-squares slope of log(median time) '
                 'against log(n): 1.0 is linear, above 1 grows faster than the input. Start-up is inside every point, which '
                 'pulls `b` below 1 when the smallest points are short. `ms / 1k rec` is the marginal cost between the two '
                 'largest points.\n')
        for (group, scen), cs in series.items():
            cs = sorted(cs, key=lambda c: c['series']['n'])
            if len(cs) < 2:
                continue
            ns = [c['series']['n'] for c in cs]
            L.append(f'### {group} / {scen}\n')
            L.append('| arm | ' + ' | '.join(f'n={n}' for n in ns) + ' | b | ms / 1k rec |' +
                     ''.join(f' {a}/{ref} at n={ns[-1]} |' for a in arms if a != ref))
            L.append('|---|' + '---|' * (len(ns) + 2 + len(others)))
            for a in arms:
                ys = [c['arms'][a]['median_ms'] for c in cs]
                lx, ly = [math.log(n) for n in ns], [math.log(y) for y in ys]
                mx, my = statistics.fmean(lx), statistics.fmean(ly)
                b = sum((x - mx) * (y - my) for x, y in zip(lx, ly)) / sum((x - mx) ** 2 for x in lx)
                marg = (ys[-1] - ys[-2]) / ((ns[-1] - ns[-2]) / 1000)
                tail = ''.join(f" {cs[-1]['arms'][o]['ratio_vs_ref']:.2f}× |" for o in others) if a == ref else \
                    ' |' * len(others)
                L.append(f'| {a} | ' + ' | '.join(fmt_ms(y) for y in ys) + f' | {b:.2f} | {marg:.2f} |' + tail)
            L.append('')

    L.append('## Memory\n')
    L.append('Peak RSS of the verification run of each cell (GNU time), as a geometric mean over the cells of a scenario, and '
             'as bytes of peak RSS per byte of the scenario\'s input.\n')
    L.append('| scenario | ' + ' | '.join(f'{a} peak RSS | {a} B/B' for a in arms) + ' | '
             + ' | '.join(f'{o}/{ref} RSS' for o in others) + ' |')
    L.append('|---|' + '---|' * (2 * len(arms) + len(others)))
    for scen in dict.fromkeys(c['scenario'] for c in ok_cells):
        cs = [c for c in ok_cells if c['scenario'] == scen and all(c['arms'][a].get('peak_rss_mb') for a in arms)]
        if not cs:
            continue
        row = []
        for a in arms:
            row.append(f"{geomean([c['arms'][a]['peak_rss_mb'] for c in cs]):.0f} MB")
            row.append(f"{geomean([c['arms'][a]['peak_rss_mb'] * 1048576 / c['input_bytes'] for c in cs]):.0f}")
        row += [f"{geomean([c['arms'][o]['peak_rss_mb'] / c['arms'][ref]['peak_rss_mb'] for c in cs]):.1f}×" for o in others]
        L.append(f'| {scen} | ' + ' | '.join(row) + ' |')
    L.append('')

    for scen in dict.fromkeys(c['scenario'] for c in cells):
        L.append(f'## {scen}\n')
        hdr = ['document', 'input'] + [f'{a} median (p95)' for a in arms] + [f'{o}/{ref} [95% CI]' for o in others] \
            + [f'{a} MB/s' for a in arms] + [f'{a} peak RSS' for a in arms] + ['cv % (' + '/'.join(arms) + ')', 'n', 'status']
        L.append('| ' + ' | '.join(hdr) + ' |')
        L.append('|' + '---|' * len(hdr))
        for c in (c for c in cells if c['scenario'] == scen):
            row = [c['file'] or '-', f"{c['input_bytes'] / 1e6:.2f} MB" if c['input_bytes'] else '-']
            if c['status'] == 'TIMEOUT':
                row += ['TIMEOUT' if c['arms'].get(a, {}).get('status') == 'TIMEOUT' else '-' for a in arms]
                row += ['-'] * (len(others) + 2 * len(arms) + 2) + ['TIMEOUT']
                L.append('| ' + ' | '.join(row) + ' |')
                continue
            row += [f"{fmt_ms(c['arms'][a]['median_ms'])} ({fmt_ms(c['arms'][a]['p95_ms'])})" for a in arms]
            row += [f"{c['arms'][o]['ratio_vs_ref']:.2f}× [{c['arms'][o]['ratio_ci95'][0]:.2f}, "
                    f"{c['arms'][o]['ratio_ci95'][1]:.2f}]" for o in others]
            row += [f"{c['arms'][a]['mb_per_s']:.2f}" if 'mb_per_s' in c['arms'][a] else '-' for a in arms]
            row += [f"{c['arms'][a]['peak_rss_mb']:.0f} MB" if c['arms'][a].get('peak_rss_mb') else '-' for a in arms]
            row += ['/'.join(f"{c['arms'][a]['cv_pct']:.1f}" for a in arms), str(c['arms'][ref]['n']),
                    c['status'] + ('' if c['output'] == 'SAME' else f" ({c['output']})")
                    + (f" ERROR PATH (exit {c['arms'][ref]['exit']})" if errpath(c) else '')]
            L.append('| ' + ' | '.join(row) + ' |')
        L.append('')
    (out / 'report.md').write_text('\n'.join(L) + '\n')


def main():
    p = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    sub = p.add_subparsers(dest='cmd', required=True)
    f = sub.add_parser('fetch')
    f.add_argument('--corpus', default=str(DEFAULT_CORPUS))
    pr = sub.add_parser('prepare')
    pr.add_argument('--corpus', default=str(DEFAULT_CORPUS))
    pr.add_argument('--reference', required=True)
    r = sub.add_parser('run')
    r.add_argument('--corpus', default=str(DEFAULT_CORPUS))
    r.add_argument('--out')
    r.add_argument('--arm', type=parse_arm, action='append', required=True)
    r.add_argument('--scenarios')
    r.add_argument('--files')
    r.add_argument('--tiers')
    r.add_argument('--budget', type=float, default=30.0)
    r.add_argument('--min-runs', type=int, default=5)
    r.add_argument('--max-runs', type=int, default=30)
    r.add_argument('--timeout', type=float, default=900.0)
    r.add_argument('--max-cv', type=float, default=5.0)
    r.add_argument('--seed', type=int, default=1)
    rep = sub.add_parser('report')
    rep.add_argument('dir')
    args = p.parse_args()
    {'fetch': cmd_fetch, 'prepare': cmd_prepare, 'run': cmd_run,
     'report': lambda a: write_report(a.dir)}[args.cmd](args)


if __name__ == '__main__':
    main()
