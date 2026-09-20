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

### DISC-001 — runtime flags before `--` belong to the Bend runtime   [2026-09-20 | Platform | OPEN]
- Spec clause: S8 (argv), S9 (usage)
- Original behavior (cite the golden): `goldens/usage_help.out` line 1: `TOON reference implementation in Rust (JSON <-> TOON)` for a bare `toon --help`
- Port behavior: `./toon --help` (no `--`) prints the Bend runtime's own option table; `./toon --threads 2 x.json` sets the thread count instead of failing as an unexpected argument. After `--` the port's argv handling is the original's: `./toon -- --help` prints the original's help text byte for byte.
- Why: the compiled Bend binary parses `--threads N`, `--gpu on|off|<size>`, `--gpu-build` and `--help` ahead of `IO.args()` on the C lane, and the JS lane answers a bare `--help` with a one-line usage (RUNTIME-FACTS-FOR-PORTERS, "argv on the three engines"). A program cannot opt out.
- Kill-switch: not applicable to a runtime property; the mitigation is the launcher `bin/toon`, which execs the binary with `--` before the user's argv, so users of the launcher see the original's behavior for every spelling.
- Affected cases: none (the harness passes `--` on every lane, so all 1053 goldens are compared unchanged; no wrapper, no re-capture)
- Impact measured: 0 of 1053 cases; 4 argv spellings differ only when the binary is run without the launcher. Round 6 (non-author) adds: the runtime takes `--threads N` / `--gpu X` ANYWHERE before `--`, also after an INPUT word (`./toon a.json --threads 2`)
- Approver: pending (the repository owner who commissioned this port)
- Resolution: n/a while OPEN

### DISC-002 — the program name in clap's `Usage:` lines is the literal `toon`   [2026-09-20 | Platform | OPEN]
- Spec clause: S1.2, S10.19
- Original behavior (cite the golden): `goldens/usage_extra_positional.err` line 3: `Usage: toon [OPTIONS] [INPUT]`, where `toon` is the final path component of argv[0] (a copy of the binary named `tn` prints `Usage: tn …`; `--version` always prints `toon`)
- Port behavior: `Usage: toon …` whatever the executable is called
- Why: `IO.args()` excludes argv[0] on every lane (`effs/args.c:7`) and Base has no other access to it
- Kill-switch: not applicable to a runtime property; a renamed launcher is the only way to meet it, and it prints `toon`
- Affected cases: none (every golden was captured from `./oracle/toon`, so the name is `toon` in all of them)
- Impact measured: 0 of 1053 cases (0 of 1005 when written; re-counted after the Phase 4 re-capture)
- Approver: pending (the repository owner who commissioned this port)
- Resolution: n/a while OPEN

### DISC-003 — an unwritable stderr: the exit code and the abort differ   [2026-09-20 | Platform | OPEN]
- Spec clause: S9.20, S10.18 (both corrected in round 6: only a FAILING stderr write aborts the original; a CLOSED stderr is ignored by it)
- Original behavior (runs of 2026-09-20, no golden: the harness cannot redirect stderr): stderr = `/dev/full` when a runtime line is printed → SIGABRT (134 in a shell, −6 for a parent); stderr CLOSED (`2>&-`) → the write error is ignored and the exit code is the normal one (0 for a successful `-e … -o /dev/null`, 1 for a missing file, 2 for an argv error); argv errors with stderr = `/dev/full` → exit 2
- Port behavior: in every one of these situations the Bend runtime fail-stops with exit 1 (it has nowhere to print `bend: a short write on a standard stream`). So the exit code differs from the original's whenever the original's is not 1: a successful conversion with a success line and a closed stderr (0 vs 1), an argv error with an unwritable stderr (2 vs 1), and the abort (134 vs 1)
- Why: the runtime owns the standard streams; a program cannot intercept the failure
- Kill-switch: not applicable
- Affected cases: none expressible
- Impact measured: 0 of 1053 cases; found and tabulated by the non-author round 6
- Approver: pending
- Resolution: n/a while OPEN

### DISC-004 — argv words that are not valid UTF-8   [2026-09-20 | Platform | OPEN]
- Spec clause: S1.22, S1.87, S5.107, S9.18
- Original behavior: clap accepts a non-UTF-8 INPUT or `--output` path as an OS string and prints it lossily in messages; a non-UTF-8 value for a typed option is an `invalid UTF-8` error (observed by the CLI extractor; no golden, cases.tsv argv is text)
- Port behavior: the runtime decodes argv with replacement before `IO.args()` returns, so such a path names a different file and messages show U+FFFD where the original does too, but the file that is opened differs
- Why: Base's argv is `String`; there is no byte-level argv effect
- Kill-switch: not applicable
- Affected cases: none expressible
- Impact measured: 0 of 1053 cases (0 of 1005 when written; re-counted after the Phase 4 re-capture)
- Approver: pending
- Resolution: n/a while OPEN

### DISC-005 — clap's ANSI styling on a terminal or under `CLICOLOR_FORCE`   [2026-09-20 | Platform | OPEN]
- Spec clause: S1.21, S8.3, S8.4
- Original behavior: help and error texts carry ANSI styling when the stream is a terminal or `CLICOLOR_FORCE` is set; into a pipe or file they are plain (every golden is plain)
- Port behavior: always plain
- Why: Base has no terminal query; reading `CLICOLOR_FORCE`/`NO_COLOR` alone would reproduce only part of the rule
- Kill-switch: not applicable
- Affected cases: none (the harness captures through pipes)
- Impact measured: 0 of 1053 cases (0 of 1005 when written; re-counted after the Phase 4 re-capture)
- Approver: pending
- Resolution: n/a while OPEN

### DISC-006 — a failed write to stdout prints the runtime's line, not the original's   [2026-09-20 | Platform | OPEN]
- Spec clause: S9.16, S8.9, S8.10
- Original behavior: `Failed to write to stdout: <os text> (os error <n>)` + LF on stderr, exit 1 (run 2026-09-20: stdout = `/dev/full` → `No space left on device (os error 28)`; stdout = a pipe whose reader is closed → `Broken pipe (os error 32)`)
- Port behavior: for a CONVERSION the same exit code 1, stderr `bend: a short write on a standard stream` + LF (C lane, both situations). Round 6 found the cases where the exit code differs too: `--help` / `--version` with stdout = `/dev/full` or closed → the original ignores the failure (S1.63: exit 0, silent), the port exits 1 with the runtime line on both the C and JS lanes; a conversion with stdout CLOSED (`-e one.json >&-`) → the original exits 0 (Rust ignores EBADF on stdout), the C lane exits 1 with the runtime line, and the JS lane exits 0: a difference BETWEEN the port's lanes that no golden can see
- Why: `IO.write` owns fd 1 and fail-stops inside the runtime; a program cannot intercept the failure. Writing through `File.open("/dev/stdout", …)` instead would return the errno, but re-opening fd 1 by path fails where the original succeeds (a socket, a descriptor inherited across a privilege change), which is a worse divergence than a differing text on a failing write. Writes to the `-o` file DO go through the File API and reproduce S9.15 byte for byte (golden-tested: `io_output_dev_full_*`).
- Kill-switch: not applicable
- Affected cases: none expressible (the harness captures stdout)
- Impact measured: 0 of 1053 cases
- Approver: pending
- Resolution: n/a while OPEN

### DISC-007 — the native binary hangs when stdin is CLOSED   [2026-09-20 | Platform | OPEN]
- Spec clause: S8.5, S9.2, S9.12 ("a process started without fd 0 sees an empty stdin")
- Original behavior (run 2026-09-20): `toon -e <&-` → `JSON error: Failed to parse JSON: EOF while parsing a value at line 1 column 0`, exit 1; `toon -d <&-` → `{}`, exit 0
- Port behavior: the JS lane matches the original. The NATIVE binary never returns (`timeout 10 ./toon -- -e <&-` → 124): with fd 0 free at startup, the Bend runtime's own wake-up pipe is given descriptor 0 (`/proc/<pid>/fd` shows 0, 3 and 4 on one pipe), so reading `/dev/stdin` reads a pipe that nobody writes
- Why: descriptor allocation happens inside the runtime before `main`; Bend has no effect that can tell whether fd 0 was open
- Kill-switch: not applicable; mitigation: the launcher `bin/toon` re-opens a closed fd 0 from `/dev/null` before exec, which gives exactly the original's behavior (an empty input)
- Affected cases: none expressible (the harness requires stdin to be a regular file)
- Impact measured: 0 of 1053 cases; found by the non-author round 6
- Approver: pending
- Resolution: n/a while OPEN

### DISC-008 — a new `-o` file is created with mode 0644, not 0666, before the umask   [2026-09-20 | Platform | OPEN]
- Spec clause: S5.103, S8.11 ("creation mode is the platform default, 0666 masked by umask")
- Original behavior (run 2026-09-20): `umask 002; toon -e -o x` → mode 664; umask 000 → 666
- Port behavior: 644 in both (C and JS lanes); equal to the original for every umask that clears the group and other write bits (022 and above). Bytes, truncation, in-place conversion and "untouched on error" are the original's
- Why: the runtime's `File.open` passes the literal `0644` to `open(2)` (`bend2/effs/file_open.c:18` at the pin); Bend has no chmod effect
- Kill-switch: not applicable
- Affected cases: none (none of the 33 corpus cases that name an output path writes a regular file; S5.103's mode sentence is not golden-tested)
- Impact measured: 0 of 1053 cases; found by the non-author round 6
- Approver: pending
- Resolution: n/a while OPEN

### DISC-009 — a non-blocking stdin is read instead of failing with EAGAIN   [2026-09-20 | Platform | OPEN]
- Spec clause: S9.12 (template `Failed to read stdin: <os text> (os error <n>)`)
- Original behavior (run by round 6): stdin is a pipe with `O_NONBLOCK` set and no data yet → `Failed to read stdin: Resource temporarily unavailable (os error 11)`, exit 1
- Port behavior: the runtime waits for the data and converts it (`[2]: 1,2`, exit 0)
- Why: the runtime's reader polls; the program never sees EAGAIN. This is the port behaving better than the original, which by this project's rule is still a divergence and not a silent fix
- Kill-switch: not applicable
- Affected cases: none expressible
- Impact measured: 0 of 1053 cases
- Approver: pending
- Resolution: n/a while OPEN

### DISC-010 — a TOON document nested about 20000 levels deep decodes instead of aborting   [2026-09-20 | Performance | OPEN]
- Spec clause: S2.150 (no nesting limit without expansion); candidate C-6 promoted to the register by round 6, because it IS a divergence
- Original behavior: a Rust stack overflow, SIGABRT, with a thread id in stderr that varies per run (the JSON extractor's handover notes; 2000 levels decode)
- Port behavior: the decoder is an explicit-stack machine and decodes the document
- Why: a limit the original has and the port does not; a signal exit with a varying message cannot be a golden
- Kill-switch: not applicable
- Affected cases: none (a signal exit is never a golden; the input is far above 1 MB)
- Impact measured: 0 of 1053 cases; not re-run in this session
- Approver: pending
- Resolution: n/a while OPEN

### Bug-compatibility candidates C-1 to C-11 (not divergences: the port is bug-compatible with each; listed so the owner can decide)

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
