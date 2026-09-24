# STOPPED at 112 of 204 cells — contaminated, nothing here is usable

Stopped deliberately, not killed by the host. At 112 cells it had **0 MEASURED and 8 of 336 arms
inside cv 5%**: the first half was captured while another session's four-lane run was still up.

Finishing it would have blended contaminated cells with clean ones into one geometric mean, which is
how the six-lever run (`2026-09-23-six-levers-78a2588`) produced an apparent 1.37× improvement that was
entirely contention — see that directory's `INVALID.md`.

Replaced by `2026-09-23-wall2-2c33e64`, started after the other session cleared the host.

Kept rather than deleted because the cv distribution is itself evidence of what a busy host does to this
suite: 8 of 336 arms in the gate here, against 218 of 357 in the replacement at load 2.4–3.0, and 393 of
612 in the one good run of the morning.
