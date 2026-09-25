#!/usr/bin/env python3
"""Plant a decoy findings table in a review report, for harness-selftest's M23 and control C1.

    .hst-decoy.py <report.md> hide|quote

`hide`  moves the real findings table INTO an HTML comment and re-heads the visible copy so the
        line-by-line reader of R24-1 cannot see it. The decoy keeps EVERY row, so the counted total
        still equals the rounds-table row and every id named still has a row — the counts agreeing is
        what disarmed every check downstream, and a decoy that changed them would be caught by the
        count rule rather than by the reader. This is a LIE: a reader sees a table the gates do not.
`quote` leaves the visible table CORRECT and adds a hidden excerpt with a DIFFERENT count. Nothing a
        reader sees is wrong, so this is NOT a lie and the gates must stay silent (control C1). Before
        round 24's repair they refused it, reporting "2 findings tables" — a false positive.

Named with a leading dot so it is not mistaken for a gate. harness-selftest.sh is its only caller.
"""
import re
import sys


def main(argv):
    if len(argv) != 3 or argv[2] not in ('hide', 'quote'):
        sys.exit(__doc__)
    path, mode = argv[1], argv[2]
    with open(path, encoding='utf-8') as fh:
        lines = fh.read().split('\n')
    header = re.compile(r'^\|\s*id\s*\|\s*sev\s*\|\s*class\s*\|')
    start = next((i for i, l in enumerate(lines) if header.match(l)), None)
    if start is None:
        sys.exit('no findings table (header cells id, sev, class) in ' + path)
    end = start
    while end < len(lines) and lines[end].startswith('|'):
        end += 1
    table = lines[start:end]
    if mode == 'hide':
        visible = [table[0].replace('| id ', '| finding ').replace('| sev ', '| severity ')
                   .replace('| class ', '| type ')] + table[1:]
        lines[start:end] = (['<!-- kept for the record, not the findings table:'] + table
                            + ['-->', ''] + visible)
    else:
        decoy = table[:3]          # header, delimiter, ONE row: deliberately a different count
        lines[start:start] = (['<!-- a quoted excerpt, deliberately with a different count:']
                              + decoy + ['-->', ''])
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(lines))


if __name__ == '__main__':
    main(sys.argv)
