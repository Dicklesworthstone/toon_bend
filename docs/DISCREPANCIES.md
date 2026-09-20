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

### DISC-CANDIDATES (not divergences: the port is bug-compatible with each; listed so the owner can decide)

These are behaviors of the pinned original that look unintended. The port reproduces all of them and the goldens pin them. Turning any into a fix is a `BugFix` DISC with the owner's approval, a kill-switch and a re-capture; none has been taken.

| # | observed (golden) | note |
|---|---|---|
| C-1 | decoded integers print as floats: `goldens/happy_readme_users_decode.out` has `"id": 1.0` | the README shows `{"id":1,…}`; OQ-007 |
| C-2 | JSON number input is not correctly rounded: `goldens/encnum_long_mantissa.out` n09 `0.33333333333333337` | serde_json without `float_roundtrip`; OQ-002 |
| C-3 | the two JSON writers escape control characters differently (`decstr_control_out` vs `decstr_control_out_expand`) | streaming writer: serde_json escaping; `--expand-paths safe` writer: `\\u00XX` for every `is_control()` char |
| C-4 | decode errors carry no `Failed to decode TOON:` prefix | README and the original's spec document say they do; OQ-006 |
| C-5 | control characters other than `\\n \\r \\t` are written raw and unquoted into TOON (`encstr_escapes_in`) | `is_safe_unquoted` does not test them |

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
