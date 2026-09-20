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
- Affected cases: none (the harness passes `--` on every lane, so all 678 goldens are compared unchanged; no wrapper, no re-capture)
- Impact measured: 0 of 678 cases; 4 argv spellings differ only when the binary is run without the launcher
- Approver: pending (the repository owner who commissioned this port)
- Resolution: n/a while OPEN

### DISC-002 — the program name in clap's `Usage:` lines is the literal `toon`   [2026-09-20 | Platform | OPEN]
- Spec clause: S1.2, S10.19
- Original behavior (cite the golden): `goldens/usage_extra_positional.err` line 3: `Usage: toon [OPTIONS] [INPUT]`, where `toon` is the final path component of argv[0] (a copy of the binary named `tn` prints `Usage: tn …`; `--version` always prints `toon`)
- Port behavior: `Usage: toon …` whatever the executable is called
- Why: `IO.args()` excludes argv[0] on every lane (`effs/args.c:7`) and Base has no other access to it
- Kill-switch: not applicable to a runtime property; a renamed launcher is the only way to meet it, and it prints `toon`
- Affected cases: none (every golden was captured from `./oracle/toon`, so the name is `toon` in all of them)
- Impact measured: 0 of 1005 cases
- Approver: pending (the repository owner who commissioned this port)
- Resolution: n/a while OPEN

### DISC-003 — an unwritable stderr fail-stops instead of aborting   [2026-09-20 | Platform | OPEN]
- Spec clause: S9.20, S10.18
- Original behavior: a failed write to stderr panics inside `eprintln!` and the process aborts with status 134 (observed by the CLI extractor with stderr redirected to `/dev/full`; no golden, the harness cannot express it)
- Port behavior: the Bend runtime prints nothing further and exits 1 (`bend: a short write on a standard stream`)
- Why: the runtime owns the standard streams; a program cannot intercept the failure
- Kill-switch: not applicable
- Affected cases: none expressible
- Impact measured: 0 of 1005 cases
- Approver: pending
- Resolution: n/a while OPEN

### DISC-004 — argv words that are not valid UTF-8   [2026-09-20 | Platform | OPEN]
- Spec clause: S1.22, S1.87, S5.107, S9.18
- Original behavior: clap accepts a non-UTF-8 INPUT or `--output` path as an OS string and prints it lossily in messages; a non-UTF-8 value for a typed option is an `invalid UTF-8` error (observed by the CLI extractor; no golden, cases.tsv argv is text)
- Port behavior: the runtime decodes argv with replacement before `IO.args()` returns, so such a path names a different file and messages show U+FFFD where the original does too, but the file that is opened differs
- Why: Base's argv is `String`; there is no byte-level argv effect
- Kill-switch: not applicable
- Affected cases: none expressible
- Impact measured: 0 of 1005 cases
- Approver: pending
- Resolution: n/a while OPEN

### DISC-005 — clap's ANSI styling on a terminal or under `CLICOLOR_FORCE`   [2026-09-20 | Platform | OPEN]
- Spec clause: S1.21, S8.3, S8.4
- Original behavior: help and error texts carry ANSI styling when the stream is a terminal or `CLICOLOR_FORCE` is set; into a pipe or file they are plain (every golden is plain)
- Port behavior: always plain
- Why: Base has no terminal query; reading `CLICOLOR_FORCE`/`NO_COLOR` alone would reproduce only part of the rule
- Kill-switch: not applicable
- Affected cases: none (the harness captures through pipes)
- Impact measured: 0 of 1005 cases
- Approver: pending
- Resolution: n/a while OPEN

### DISC-006 — a failed write to stdout prints the runtime's line, not the original's   [2026-09-20 | Platform | OPEN]
- Spec clause: S9.16, S8.9, S8.10
- Original behavior: `Failed to write to stdout: <os text> (os error <n>)` + LF on stderr, exit 1 (run 2026-09-20: stdout = `/dev/full` → `No space left on device (os error 28)`; stdout = a pipe whose reader is closed → `Broken pipe (os error 32)`)
- Port behavior: the same exit code 1; stderr is `bend: a short write on a standard stream` + LF (run 2026-09-20 on the C lane, both situations)
- Why: `IO.write` owns fd 1 and fail-stops inside the runtime; a program cannot intercept the failure. Writing through `File.open("/dev/stdout", …)` instead would return the errno, but re-opening fd 1 by path fails where the original succeeds (a socket, a descriptor inherited across a privilege change), which is a worse divergence than a differing text on a failing write. Writes to the `-o` file DO go through the File API and reproduce S9.15 byte for byte (golden-tested: `io_output_dev_full_*`).
- Kill-switch: not applicable
- Affected cases: none expressible (the harness captures stdout)
- Impact measured: 0 of 1005 cases
- Approver: pending
- Resolution: n/a while OPEN

### DISC-CANDIDATES (not divergences: the port is bug-compatible with each; listed so the owner can decide)

These are behaviors of the pinned original that look unintended. The port reproduces all of them and the goldens pin them. Turning any into a fix is a `BugFix` DISC with the owner's approval, a kill-switch and a re-capture; none has been taken.

| # | observed (golden) | note |
|---|---|---|
| C-1 | decoded integers print as floats: `goldens/happy_readme_users_decode.out` has `"id": 1.0` | the README shows `{"id":1,…}`; OQ-007 |
| C-2 | JSON number input is not correctly rounded: `goldens/encnum_long_mantissa.out` n09 `0.33333333333333337` | serde_json without `float_roundtrip`; OQ-002 |
| C-3 | the two JSON writers escape control characters differently (`decstr_control_out` vs `decstr_control_out_expand`) | streaming writer: serde_json escaping; `--expand-paths safe` writer: `\\u00XX` for every `is_control()` char |
| C-4 | decode errors carry no `Failed to decode TOON:` prefix | README and the original's spec document say they do; OQ-006 |
| C-5 | control characters other than `\\n \\r \\t` are written raw and unquoted into TOON (`encstr_escapes_in`) | `is_safe_unquoted` does not test them |
| C-6 | a TOON document nested about 20000 levels deep aborts the original with a Rust stack overflow (SIGABRT; the thread id in stderr varies per run); 2000 levels decode | reported by the JSON extractor's handover notes; outside the corpus (a signal exit is never a golden). The port's decoder is an explicit-stack machine and does not overflow; if this is ever pinned it is a `Performance`-class DISC |
| C-7 | without `--stats`, a failing write to the `-o` file is silently lost when the output is at most 8192 bytes: success line, exit 0 (`io_output_dev_full_8192` vs `io_output_dev_full_8193`) | the original's buffered writer drops the flush error; reproduced (OQ-A6) |
| C-8 | "safe" key folding can emit two equal keys in one list-item object: `[{"c.d":7,"c":{"d":1}}]` encodes as `- c.d: 7` then `c.d: 1` (`enc_fold_list_item_dup_key`) | S10.61: the sibling check for the remaining fields does not see the first field |
| C-9 | a line indented deeper than any open block silently ends the root object and everything after it is dropped, exit 0: `a:`, `  b: 1`, `    c: 2`, `  d: 3`, `e: 4` decodes to `{"a":{"b":1.0}}` | S10 rows of part E; strict mode does not catch it |
| C-10 | the header parser finds `[` inside a quoted value, so the original's own output `a: "x[1]: y"` decodes to `{"a: \"x":["y\""]}` | S10.84; breaks the round trip for such strings |
| C-11 | `1.7976931348623158e308` is rejected as `number out of range` although it rounds to the largest finite value; the encoder's own TOON text for that value is rejected when fed back as JSON | S10.41 |

<!-- template for the next entry -->
### DISC-nnn — `<short title>`   [<date> | <class> | OPEN · ACCEPTED · REVERTED · RESOLVED]
- Spec clause: S`<n.m>`
- Original behavior (cite the golden): `goldens/<case>.out` line `<n>`: `<verbatim>`
- Port behavior: `<verbatim>`
- Why: `<one paragraph; "the original is wrong" needs the approver below>`
- Kill-switch: `~` switch `<name>` / env `Toon_<FLAG>=1` restores the original's behavior
- Affected cases: `<list>` (re-captured through wrapper `scripts/canon-<name>.sh`, MANIFEST diff `<sha>`)
- Impact measured: `<n>` of `<m>` cases; largest numeric delta `<value>` (class NumericWidth only)
- Approver: `<name>`, `<date>`
- Resolution: `<for RESOLVED only: restored behavior and regression cases / lane or proof artifacts>`
