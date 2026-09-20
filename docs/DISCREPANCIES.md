# Discrepancies — the Bend 2 port of Toon

<!-- Every observed or deliberate divergence from the original's observable behavior.
     Bug-compatibility is the default: a divergence exists only as an entry
     here, with a kill-switch, the affected cases and a measured impact.
     Goldens are re-captured for an accepted DISC only through the
     canonicalizing wrapper the entry names, never edited by hand. -->

Classes: `NumericWidth` (F32 for f64, budgeted) · `OrderLeak` (the
original's order is hash-random and cannot be reproduced) · `ErrorText`
(platform/library message differs) · `Platform` (path separators, locale,
line endings) · `Nondeterminism` (the original varies; canonicalized) ·
`BugFix` (an intentional fix, approved) · `Excluded` (feature not ported,
also in PLAN §3) · `Performance` (a limit the original has and the port does
not, or vice versa).

## Register

`ACCEPTED` records an approved deliberate divergence. `REVERTED` records its
reversal. `RESOLVED` records a repair that restores the original behavior;
it needs a Resolution field naming the regression artifacts, not approval
to change the contract. Keep the historical entry and its original evidence.

### DISC-001 — runtime flags before `--` belong to the Bend runtime   [2026-09-20 | Platform | ACCEPTED]
- Spec clause: S8 (argv), S9 (usage)
- Original behavior (cite the golden): `goldens/usage_help.out` line 1: `TOON reference implementation in Rust (JSON <-> TOON)` for a bare `toon --help`
- Port behavior: `./toon --help` (no `--`) prints the Bend runtime's own option table; `./toon --threads 2 x.json` sets the thread count instead of failing as an unexpected argument. After `--` the port's argv handling is the original's: `./toon -- --help` prints the original's help text byte for byte.
- Why: the compiled Bend binary parses `--threads N`, `--gpu on|off|<size>`, `--gpu-build` and `--help` ahead of `IO.args()` on the C lane, and the JS lane answers a bare `--help` with a one-line usage (RUNTIME-FACTS-FOR-PORTERS, "argv on the three engines"). A program cannot opt out.
- Kill-switch: not applicable to a runtime property; the mitigation is the launcher `bin/toon`, which execs the binary with `--` before the user's argv, so users of the launcher see the original's behavior for every spelling. Round 8 (R8-4, R8-5) found two defects of the launcher itself, both repaired: reached through a symbolic link outside the checkout it looked for the binary beside the LINK (exit 127), and a `TOON_BEND_THREADS` the runtime refuses (`0`, `abc`, `2x`) made EVERY command exit 1, `--version` included; the launcher resolves links now and ignores a value that is not a positive decimal count
- Affected cases: none (the harness passes `--` on every lane, so all 1053 goldens are compared unchanged; no wrapper, no re-capture)
- Impact measured: 0 of 1053 cases; 4 argv spellings differ only when the binary is run without the launcher. Round 6 (non-author) adds: the runtime takes `--threads N` / `--gpu X` ANYWHERE before `--`, also after an INPUT word (`./toon a.json --threads 2`)
- Approver: the repository owner, 2026-09-20, who delegated the ruling to the author in these words: "You decide on everything. I approve whatever you want to do." The author's ruling follows under Resolution
- Resolution: ACCEPTED. Scoped contract: the bare compiled binary keeps the Bend runtime's flags before `--`; the supported command line is the launcher `bin/toon`, which passes `--` first, so every word the user types reaches the port's argv. Nothing else may differ.

### DISC-002 — the program name in clap's `Usage:` lines is the literal `toon`   [2026-09-20 | Platform | ACCEPTED]
- Spec clause: S1.2, S10.19
- Original behavior (cite the golden): `goldens/usage_extra_positional.err` line 3: `Usage: toon [OPTIONS] [INPUT]`, where `toon` is the final path component of argv[0] (a copy of the binary named `tn` prints `Usage: tn …`; `--version` always prints `toon`)
- Port behavior: `Usage: toon …` whatever the executable is called
- Why: `IO.args()` excludes argv[0] on every lane (`effs/args.c:7`) and Base has no other access to it
- Kill-switch: not applicable to a runtime property; a renamed launcher is the only way to meet it, and it prints `toon`
- Affected cases: none (every golden was captured from `./oracle/toon`, so the name is `toon` in all of them)
- Impact measured: 0 of 1053 cases (0 of 1005 when written; re-counted after the Phase 4 re-capture)
- Approver: the repository owner, 2026-09-20, who delegated the ruling to the author in these words: "You decide on everything. I approve whatever you want to do." The author's ruling follows under Resolution
- Resolution: ACCEPTED. Scoped contract: `Usage:` lines name the program `toon` whatever the file is called; only the program-name token of clap's usage lines may differ from an original that was renamed.

### DISC-003 — an unwritable stderr: the exit code and the abort differ   [2026-09-20 | Platform | ACCEPTED]
- Spec clause: S9.20, S10.18 (both corrected in round 6: only a FAILING stderr write aborts the original; a CLOSED stderr is ignored by it)
- Original behavior (runs of 2026-09-20, no golden: the harness cannot redirect stderr): stderr = `/dev/full` when a runtime line is printed → SIGABRT (134 in a shell, −6 for a parent); stderr CLOSED (`2>&-`) → the write error is ignored and the exit code is the normal one (0 for a successful `-e … -o /dev/null`, 1 for a missing file, 2 for an argv error); argv errors with stderr = `/dev/full` → exit 2
- Port behavior: on the NATIVE binary, in every one of these situations the Bend runtime fail-stops with exit 1 (it has nowhere to print `bend: a short write on a standard stream`). So the exit code differs from the original's whenever the original's is not 1: a successful conversion with a success line and a closed stderr (0 vs 1), an argv error with an unwritable stderr (2 vs 1), and the abort (134 vs 1). Corrections by round 8 (R8-6, R8-2): this entry used to say "every lane": the JAVASCRIPT build with stderr CLOSED exits 2 for a usage error and 0 after a success line, like the original, and only `/dev/full` gives its exit 1; the native binary with descriptors 1 AND 2 both closed exits 2 on `--bogus`. A stderr that is OPEN in the wrong access mode (`2</dev/null`: the first write gives EBADF) behaves like a closed one: the original ignores it, the native binary and the JavaScript build exit 1
- Why: the runtime owns the standard streams; a program cannot intercept the failure
- Kill-switch: not applicable; mitigation for a CLOSED or READ-ONLY stderr: the launcher `bin/toon` re-opens it from `/dev/null`, which is what the original's "ignore EBADF" amounts to (`scripts/stdio-probe.py -- ./bin/toon`: the closed-stderr and read-only-stderr rows are SAME; the access mode is read from `/proc/self/fdinfo`, so that half of the mitigation is Linux-only). A stderr that is open for writing and FAILS (`/dev/full`) stays as described
- Affected cases: none expressible
- Impact measured: 0 of 1053 cases; found and tabulated by the non-author round 6
- Approver: the repository owner, 2026-09-20, who delegated the ruling to the author in these words: "You decide on everything. I approve whatever you want to do." The author's ruling follows under Resolution
- Resolution: ACCEPTED. Scoped contract: only when stderr cannot be WRITTEN. Through `bin/toon` a closed or read-only stderr behaves like the original's; a stderr that is open for writing and fails (`/dev/full`) gives exit 1 instead of the original's abort or its normal exit code. stdout bytes never differ.

### DISC-004 — argv words that are not valid UTF-8   [2026-09-20 | Platform | ACCEPTED]
- Spec clause: S1.22, S1.87, S5.107, S9.18
- Original behavior: clap accepts a non-UTF-8 INPUT or `--output` path as an OS string and prints it lossily in messages; a non-UTF-8 value for a typed option is an `invalid UTF-8` error (observed by the CLI extractor; no golden, cases.tsv argv is text)
- Port behavior: the runtime decodes argv with replacement before `IO.args()` returns, so such a path names a different file and messages show U+FFFD where the original does too, but the file that is opened differs. For a TYPED option the text differs as well (round 7, R7-10): `--indent $'\xff'` (also `--delimiter`) → the original prints `error: invalid UTF-8 was detected in one or more arguments`, a blank line, `Usage: toon [OPTIONS] [INPUT]`, a blank line and the help hint, exit 2; the port prints `error: invalid value '\ufffd' for '--indent <INDENT>': invalid digit found in string` and the help hint, exit 2. `--key-folding $'\xff'`, unknown options and paths behave as described above
- Why: Base's argv is `String`; there is no byte-level argv effect
- Kill-switch: not applicable
- Affected cases: none expressible
- Impact measured: 0 of 1053 cases (0 of 1005 when written; re-counted after the Phase 4 re-capture)
- Approver: the repository owner, 2026-09-20, who delegated the ruling to the author in these words: "You decide on everything. I approve whatever you want to do." The author's ruling follows under Resolution
- Resolution: ACCEPTED. Scoped contract: only argv words that are not valid UTF-8 (paths and typed option values); the exit code is the original's (2 for the typed options), the text and the opened path may differ.

### DISC-005 — clap's ANSI styling on a terminal or under `CLICOLOR_FORCE`   [2026-09-20 | Platform | ACCEPTED]
- Spec clause: S1.21, S8.3, S8.4
- Original behavior: help and error texts carry ANSI styling when the stream is a terminal or `CLICOLOR_FORCE` is set; into a pipe or file they are plain (every golden is plain)
- Port behavior: always plain
- Why: Base has no terminal query; reading `CLICOLOR_FORCE`/`NO_COLOR` alone would reproduce only part of the rule
- Kill-switch: not applicable
- Affected cases: none (the harness captures through pipes)
- Impact measured: 0 of 1053 cases (0 of 1005 when written; re-counted after the Phase 4 re-capture)
- Approver: the repository owner, 2026-09-20, who delegated the ruling to the author in these words: "You decide on everything. I approve whatever you want to do." The author's ruling follows under Resolution
- Resolution: ACCEPTED. Scoped contract: the port never styles its messages: on a terminal or under `CLICOLOR_FORCE` the original's ANSI sequences are absent; the text between them is identical.

### DISC-006 — a failed write to stdout prints the runtime's line, not the original's   [2026-09-20 | Platform | ACCEPTED]
- Spec clause: S9.16, S8.9, S8.10
- Original behavior: `Failed to write to stdout: <os text> (os error <n>)` + LF on stderr, exit 1 (run 2026-09-20: stdout = `/dev/full` → `No space left on device (os error 28)`; stdout = a pipe whose reader is closed → `Broken pipe (os error 32)`)
- Port behavior: for a CONVERSION the same exit code 1, stderr `bend: a short write on a standard stream` + LF (C lane, both situations). Round 6 found the cases where the exit code differs too: `--help` / `--version` with stdout = `/dev/full` or closed → the original ignores the failure (S1.63: exit 0, silent), the port exits 1 with the runtime line on both the C and JS lanes; a conversion with stdout CLOSED (`-e one.json >&-`) → the original exits 0 (Rust ignores EBADF on stdout), the C lane exits 1 with the runtime line, and the JS lane exits 0: a difference BETWEEN the port's lanes that no golden can see. Round 7 (R7-11) adds a NON-BLOCKING stdout pipe with 349 KB of output and a reader that starts late: the original writes 65536 bytes, prints `Failed to write to stdout: Resource temporarily unavailable (os error 11)` and exits 1; the native binary writes the same 65536 bytes and exits 1 with the runtime line; the JS lane writes all 348899 bytes and exits 0. Round 8 (R8-6, R8-2) corrects and adds: `--help` / `--version` with stdout CLOSED exit 0 on the JavaScript build (this entry said 1 on both lanes; only `/dev/full` gives the JavaScript build its exit 1), and a stdout that is OPEN read-only (`1</dev/null`) is ignored by the original (exit 0, silent) while the native binary and the JavaScript build exit 1, the native one with the runtime line. Through the launcher `bin/toon` a CLOSED stdout is re-opened from `/dev/null`, which is the original's behavior exactly (exit 0, silent): `scripts/stdio-probe.py -- ./bin/toon` reports that row SAME, and the read-only-stdout row too (Linux: the launcher reads the access mode from `/proc/self/fdinfo`); the `/dev/full` and non-blocking rows stay
- Why: `IO.write` owns fd 1 and fail-stops inside the runtime; a program cannot intercept the failure. Writing through `File.open("/dev/stdout", …)` instead would return the errno, but re-opening fd 1 by path fails where the original succeeds (a socket, a descriptor inherited across a privilege change), which is a worse divergence than a differing text on a failing write. Writes to the `-o` file DO go through the File API and reproduce S9.15 byte for byte (golden-tested: `io_output_dev_full_*`).
- Kill-switch: not applicable
- Affected cases: none expressible (the harness captures stdout)
- Impact measured: 0 of 1053 cases
- Approver: the repository owner, 2026-09-20, who delegated the ruling to the author in these words: "You decide on everything. I approve whatever you want to do." The author's ruling follows under Resolution
- Resolution: ACCEPTED. Scoped contract: only when stdout cannot be WRITTEN. Through `bin/toon` a closed or read-only stdout behaves like the original's; a failing write (`/dev/full`, a closed pipe reader, a non-blocking pipe that fills) ends with exit 1 like the original and prints the runtime's line instead of `Failed to write to stdout: …`; on the JavaScript build a non-blocking pipe is written completely. Writes to an `-o` file are the original's byte for byte.

### DISC-007 — the native binary hangs when stdin is CLOSED   [2026-09-20 | Platform | ACCEPTED]
- Spec clause: S8.5, S9.2, S9.12 ("a process started without fd 0 sees an empty stdin")
- Original behavior (run 2026-09-20): `toon -e <&-` → `JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 0`, exit 1; `toon -d <&-` → `{}`, exit 0
- Port behavior: the JS lane matches the original. The NATIVE binary, as first registered (commit `1230a0d` and before), never returned (`timeout 10 ./toon -- -e <&-` → 124): with fd 0 free at startup, the Bend runtime's own wake-up pipe is given descriptor 0 (`/proc/<pid>/fd` shows 0, 3 and 4 on one pipe), so reading `/dev/stdin` read a pipe that nobody writes. SINCE the stdin effect (DISC-012) the read fails at once instead: `-e <&-` and `-d <&-` both print `Failed to read stdin: Resource temporarily unavailable (os error 11)` and exit 1, so `-e` has the original's exit code with another text and `-d` exits 1 where the original exits 0. Round 7 (R7-7) found a SECOND hang that is still there on the bare native binary: fd 0 AND fd 1 closed, an INPUT file, more than 64 KiB of output: descriptors 0 and 1 are both the runtime's pipe, the conversion's own stdout is written INTO it and blocks when it is full (`wchan` = `anon_pipe_write`); the original exits 0
- Why: descriptor allocation happens inside the runtime before `main`; Bend has no effect that can tell whether fd 0 was open
- Kill-switch: not applicable; mitigation: the launcher `bin/toon` re-opens closed descriptors 0, 1 and 2 from `/dev/null` before exec, which gives exactly the original's behavior (an empty input; EBADF on stdout and stderr ignored). `python3 scripts/stdio-probe.py -- ./bin/toon` reports every closed-descriptor row SAME; against the bare binary the two rows of this entry are KNOWN
- Affected cases: none expressible (the harness requires stdin to be a regular file)
- Impact measured: 0 of 1053 cases; found by the non-author round 6
- Approver: the repository owner, 2026-09-20, who delegated the ruling to the author in these words: "You decide on everything. I approve whatever you want to do." The author's ruling follows under Resolution
- Resolution: ACCEPTED. Scoped contract: only the BARE native binary started with a standard descriptor closed; the supported command line is the launcher, where every closed-descriptor row of `scripts/stdio-probe.py` is SAME.

### DISC-008 — a new `-o` file is created with mode 0644, not 0666, before the umask   [2026-09-20 | Platform | ACCEPTED]
- Spec clause: S5.103, S8.11 ("creation mode is the platform default, 0666 masked by umask")
- Original behavior (run 2026-09-20): `umask 002; toon -e -o x` → mode 664; umask 000 → 666
- Port behavior: 644 in both (C and JS lanes); equal to the original for every umask that clears the group and other write bits (022 and above). Bytes, truncation, in-place conversion and "untouched on error" are the original's
- Why: the runtime's `File.open` passes the literal `0644` to `open(2)` (`bend2/effs/file_open.c:18` at the pin); Bend has no chmod effect
- Kill-switch: not applicable
- Affected cases: none (none of the 33 corpus cases that name an output path writes a regular file; S5.103's mode sentence is not golden-tested)
- Impact measured: 0 of 1053 cases; found by the non-author round 6
- Approver: the repository owner, 2026-09-20, who delegated the ruling to the author in these words: "You decide on everything. I approve whatever you want to do." The author's ruling follows under Resolution
- Resolution: ACCEPTED. Scoped contract: a NEW `-o` file gets mode 0644 before the umask instead of 0666; identical to the original under every umask that clears the group and other write bits (022 and above, the common default).

### DISC-009 — a non-blocking stdin is read instead of failing with EAGAIN   [2026-09-20 | Platform | RESOLVED]
- Spec clause: S9.12 (template `Failed to read stdin: <os text> (os error <n>)`)
- Original behavior (run by round 6): stdin is a pipe with `O_NONBLOCK` set and no data yet → `Failed to read stdin: Resource temporarily unavailable (os error 11)`, exit 1
- Port behavior: the runtime waits for the data and converts it (`[2]: 1,2`, exit 0)
- Why: as first written: "the runtime's reader polls; the program never sees EAGAIN". That cause was WRONG (round 7, R7-8, `strace`): the port opened the PATH `/dev/stdin`, a new open file description that does not carry the caller's `O_NONBLOCK`, and did one blocking `read` on it. The same root cause as DISC-012
- Kill-switch: not applicable
- Affected cases: none expressible
- Impact measured: 0 of 1053 cases
- Approver: not needed (a repair restores the original's behavior)
- Resolution: RESOLVED 2026-09-20 by the stdin effect `Stdin.open` (`port/main.bend`, `port/stdin_open.c`, `port/stdin_open.js`): descriptor 0 itself is read, so the read fails with EAGAIN and the port prints the original's line, exit 1. Regression artifact: `python3 scripts/stdio-probe.py -- <port>` row "stdin is an empty pipe with O_NONBLOCK" → SAME on the native binary, through the launcher and on the JavaScript build

### DISC-010 — a TOON document nested about 20000 levels deep decodes instead of aborting   [2026-09-20 | Performance | ACCEPTED]
- Spec clause: S2.150 (no nesting limit without expansion); candidate C-6 promoted to the register by round 6, because it IS a divergence
- Original behavior: a Rust stack overflow, SIGABRT, with a thread id in stderr that varies per run (the JSON extractor's handover notes; 2000 levels decode). Measured by round 7 (R7-9; `--indent 1`, the default 8 MiB stack): 12000 levels (72 MB) decode, exit 0; 16000 levels (128 MB) abort, exit 134. The "about 20000" of this entry's title was a guess; the threshold is between 12000 and 16000
- Port behavior: the decoder is an explicit-stack machine, so nothing in it depends on the nesting depth. That the port DECODES a 16000-level document has NOT been run (no case, no capture): at the measured 47 to 70 bytes of resident memory per input byte (DISC-011) such a document needs about 6 GB, which was not spent on a shared host
- Why: a limit the original has and the port does not; a signal exit with a varying message cannot be a golden
- Kill-switch: not applicable
- Affected cases: none (a signal exit is never a golden; the input is far above 1 MB)
- Impact measured: 0 of 1060 cases; the original's half re-run by round 7, the port's half unverified (see above)
- Approver: the repository owner, 2026-09-20, who delegated the ruling to the author in these words: "You decide on everything. I approve whatever you want to do." The author's ruling follows under Resolution
- Resolution: ACCEPTED. Scoped contract: TOON documents nested deeper than the original's stack allows (between 12000 and 16000 levels at the default 8 MiB stack); the original aborts there, the port has no depth limit of its own and is bounded by memory (DISC-011).

### DISC-011 — the native runtime's resource floor: 8 TiB of address space, a thread, an event loop   [2026-09-20 | Performance | ACCEPTED]
- Spec clause: S11.1 (large inputs), S8.1 (process start)
- Original behavior (run by round 7, R7-6): works under `RLIMIT_AS` = 100 MB, `RLIMIT_DATA` = 64 MB, `RLIMIT_NPROC` = 1, `RLIMIT_NOFILE` = 4; peak resident memory about 4 bytes per input byte (a 16 MB JSON string: 63 MB)
- Port behavior: the native binary reserves 8 TiB of address space before `main` (`VmSize` 8592046796 kB for `{"a":1}`), starts a thread and opens an event loop. With `RLIMIT_AS` below about 10 GiB or `RLIMIT_DATA` below about 34 GiB it prints `bend: reservation failed` and exits 1 for EVERY argv (`--version` exits 1 instead of 0, `--bogus` 1 instead of 2); with `RLIMIT_NPROC` exhausted `bend: pthread_create`, exit 1, also with `--threads 1`; with `RLIMIT_NOFILE` = 4 `bend: the event loop failed to open`, = 5 `Failed to read stdin: Too many open files (os error 24)`. The JavaScript build works at 4 GiB. Peak resident memory is 47 to 70 bytes per input byte (the same 16 MB string: 1117 MB; an 8 MB table 397 MB against 126 MB)
- Why: the Bend runtime's heap reservation and scheduler are not the program's to configure; every value is a heap term (a byte of input is a list cell of a `U32`)
- Kill-switch: not applicable; the JavaScript build is the lane for an address-space-limited environment
- Affected cases: none expressible (the harness sets no limits)
- Impact measured: 0 of 1060 cases; found by the non-author round 7
- Approver: the repository owner, 2026-09-20, who delegated the ruling to the author in these words: "You decide on everything. I approve whatever you want to do." The author's ruling follows under Resolution
- Resolution: ACCEPTED. Scoped contract: the native binary needs an address-space limit above about 10 GiB, a data limit above about 34 GiB, one spare thread and six descriptors, and about 50 to 70 bytes of memory per input byte; under tighter limits use the JavaScript build. Bytes never differ.

### DISC-012 — stdin was re-opened by PATH: a file offset ignored, a socket refused   [2026-09-20 | Platform | RESOLVED]
- Spec clause: S8.5 (the input is descriptor 0 when no INPUT is named), S9.12
- Original behavior (run by round 7, R7-1..R7-3): reads descriptor 0 as inherited: `{ read -r _; toon -d; } < f.toon` decodes from the second line on and leaves the shared offset at the end; a socket as stdin (every Node.js `child_process` with piped input) converts; a descriptor of a file that is no longer readable by path converts
- Port behavior up to commit `e3f5540`: `File.open("/dev/stdin", "r")`, the method's recipe for a runtime without a stdin effect, makes a NEW open file description: the regular file was read again from byte 0 (WRONG BYTES with exit 0; with a non-TOON first line an error where the original succeeds) and the shared offset was not consumed; a socket failed with `Failed to read stdin: No such device or address (os error 6)`, exit 1; the unreadable file failed with `Permission denied (os error 13)`. Native binary, launcher and JavaScript build alike. The conformance harness could not see any of it: it feeds regular files at offset 0
- Why: Base has no stdin effect (`bend2/effs/` at the pin has none)
- Kill-switch: not applicable (a repair)
- Affected cases: none expressible in `goldens/cases.tsv`; the regression artifact is a script
- Impact measured: 0 of 1060 cases; 5 of 16 rows of `scripts/stdio-probe.py` on the binary of `1230a0d`
- Approver: the repair needs none; the MEANS does: it is the port's one custom effect, which `AGENTS.md` had ruled out ("no custom effects") on the wrong premise that an effect exists on one lane only. Owner's decision, 2026-09-20, delegated to the author ("You decide on everything. I approve whatever you want to do."): the effect STAYS: without it a regular-file stdin at an offset gives wrong bytes with exit 0 and a socket stdin fails, and it costs no lane
- Resolution: RESOLVED 2026-09-20: `Stdin.open` (`port/main.bend`) with a twin per lane, `port/stdin_open.c` (`dup(0)` as a Base `File`) and `port/stdin_open.js` (descriptor 0 as the `File`), so the interpreter, both native lanes and the JavaScript build read descriptor 0 itself. Regression artifacts: `python3 scripts/stdio-probe.py -- <port>` rows "stdin is a regular file at offset 11", "… at its end", "stdin offset is left alone when INPUT is a file", "stdin is a socket", "stdin is a descriptor of a file unreadable by path" → SAME on the native binary, through the launcher and on the JavaScript build; `scripts/lanes.sh` PASS on every lane after the change. Round 8 (R8-1) found the repair INCOMPLETE for one state: a descriptor 0 that is open WITHOUT read access (`0>/dev/null`, the write end of a pipe, an O_PATH descriptor; also INPUT spelled `-`): the original takes EBADF on stdin for the end of the input (`-d` prints `{}`, exit 0), the port printed `Failed to read stdin: Bad file descriptor (os error 9)`, exit 1. Repaired the same day: on standard input a read that fails with errno 9 ends the input (`read.failed` in `port/main.bend`); rows "stdin is open WRITE-only, decode" and "… encode" of the probe → SAME on the native binary and the JavaScript build

### DISC-013 — a number that is not a small integer costs 45 to 300 times the original's time   [2026-09-20 | Performance | ACCEPTED]
- Spec clause: S11.1 (large inputs); S4.100–S4.175 (the three number algorithms)
- Original behavior (run by round 8, R8-3): hardware binary64: 80000 random doubles (1.69 MB of JSON) encode in 0.043 s and decode in 0.10 s; 1.06 MB of scientific-notation values 0.049 s; 3.85 MB of timestamped records 0.139 s
- Port behavior: the same bytes, in 4.80 s (113 times), 4.67 s (45 times), 14.96 s (306 times) and 7.29 s (53 times); the JavaScript build needs 7.1 s for a 0.42 MB document. Growth is LINEAR in the input (it is a constant factor, not a complexity difference), and integers below 2^48 and texts of at most 14 digits take the fast twins and are not affected
- Why: Bend has no binary64. Every other number is a software float over big naturals: one correctly rounded division by a power of ten per JSON number, a shortest-digit generation per printed number, powers of ten of up to 1100 bits for large exponents
- Kill-switch: not applicable (`TOON_SPEC=1` only selects the slower twins)
- Affected cases: none fails (the harness has no time verdict below its 5 s per-case budget; `encnum_*` / `decnum_*` are small). `scripts/diff-fuzz.py scale` flags an input as too slow above 1 s AND 40 times the original; its inputs hold no non-integer numbers, by design of this entry
- Impact measured: 0 of 1060 cases; found by the non-author round 8 (round 7 had measured the same factor without counting it)
- Approver: the repository owner, 2026-09-20, who delegated the ruling to the author in these words: "You decide on everything. I approve whatever you want to do." The author's ruling follows under Resolution
- Resolution: ACCEPTED as the state of this release, with the work it names left open as beads (`toon_bend-ngs`, `toon_bend-p47`, `toon_bend-okl`). Scoped contract: bytes are identical; a number that is not an integer below 2^48 costs 45 to 300 times the original's time, linearly in the input.

### Bug-compatibility candidates C-1 to C-11 (not divergences: the port is bug-compatible with each; listed so the owner can decide)

**Ruling, 2026-09-20.** The repository owner delegated it to the author ("You decide on everything. I approve whatever you want to do."). The author's ruling: EVERY candidate stays bug-compatible. A port that fixes one of them is a different program for anyone who pipes both, none of them loses data silently without the original doing the same, and each has its clause in S10 and its cases, so a later owner can turn any of them into a `BugFix` DISC with a kill-switch without reading code. C-6 had already left this list (it is DISC-010).

These are behaviors of the pinned original that look unintended. The port reproduces all of them and the goldens pin them. Turning any into a fix is a `BugFix` DISC with the owner's approval, a kill-switch and a re-capture; none has been taken.

| # | observed (golden) | note |
|---|---|---|
| C-1 | decoded integers print as floats: `goldens/happy_readme_users_decode.out` has `"id": 1.0` | the README shows `{"id":1,…}`; OQ-007 |
| C-2 | JSON number input is not correctly rounded: `goldens/encnum_long_mantissa.out` n09 `0.33333333333333337` | serde_json without `float_roundtrip`; OQ-002 |
| C-3 | the two JSON writers escape control characters differently (`decstr_control_out` vs `decstr_control_out_expand`) | streaming writer: serde_json escaping; `--expand-paths safe` writer: `\\u00XX` for every `is_control()` char |
| C-4 | decode errors carry no `Failed to decode TOON:` prefix | README and the original's spec document say they do; OQ-006 |
| C-5 | control characters other than `\\n \\r \\t` are written raw and unquoted into TOON (`encstr_escapes_in`) | `is_safe_unquoted` does not test them |
| C-6 | (moved: the port does NOT reproduce this one, so it is DISC-010, not a candidate) | see DISC-010 |
| C-7 | without `--stats`, a failing write to the `-o` file is silently lost when the output is at most 8192 bytes: success line, exit 0 (`io_output_dev_full_8192` vs `io_output_dev_full_8193`) | the original's buffered writer drops the flush error; reproduced (OQ-A6) |
| C-8 | "safe" key folding can emit two equal keys in one list-item object: `[{"c.d":7,"c":{"d":1}}]` encodes as `- c.d: 7` then `c.d: 1` (`enc_fold_list_item_dup_key`) | S10.61: the sibling check for the remaining fields does not see the first field |
| C-9 | a line indented deeper than any open block silently ends the root object and everything after it is dropped, exit 0: `a:`, `  b: 1`, `    c: 2`, `  d: 3`, `e: 4` decodes to `{"a":{"b":1.0}}` | S10 rows of part E; strict mode does not catch it |
| C-10 | the header parser finds `[` inside a quoted value, so the original's own output `a: "x[1]: y"` decodes to `{"a: \"x":["y\""]}` | S10.84; breaks the round trip for such strings |
| C-11 | `1.7976931348623158e308` is rejected as `number out of range` although it rounds to the largest finite value; the encoder's own TOON text for that value is rejected when fed back as JSON | S10.41 |

<!-- template for the next entry -->
### Entry template — `DISC-<nnn>` — `<short title>`   [<date> | <class> | OPEN · ACCEPTED · REVERTED · RESOLVED]
- Spec clause: S`<n.m>`
- Original behavior (cite the golden): `goldens/<case>.out` line `<n>`: `<verbatim>`
- Port behavior: `<verbatim>`
- Why: `<one paragraph; "the original is wrong" needs the approver below>`
- Kill-switch: `~` switch `<name>` / env `Toon_<FLAG>=1` restores the original's behavior
- Affected cases: `<list>` (re-captured through wrapper `scripts/canon-<name>.sh`, MANIFEST diff `<sha>`)
- Impact measured: `<n>` of `<m>` cases; largest numeric delta `<value>` (class NumericWidth only)
- Approver: `<name>`, `<date>`
- Resolution: `<for RESOLVED only: restored behavior and regression cases / lane or proof artifacts>`
