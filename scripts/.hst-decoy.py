#!/usr/bin/env python3
"""Plant a decoy findings table in a review report, for harness-selftest's M23 and control C1.

    .hst-decoy.py <report.md> hide|quote|block

`hide`  moves the real findings table INTO an HTML comment and re-heads the visible copy so the
        line-by-line reader of R24-1 cannot see it. The decoy keeps EVERY row, so the counted total
        still equals the rounds-table row and every id named still has a row — the counts agreeing is
        what disarmed every check downstream, and a decoy that changed them would be caught by the
        count rule rather than by the reader. This is a LIE: a reader sees a table the gates do not.
`quote` leaves the visible table CORRECT and adds a hidden excerpt with a DIFFERENT count. Nothing a
        reader sees is wrong, so this is NOT a lie and the gates must stay silent (control C1). Before
        round 24's repair they refused it, reporting "2 findings tables" — a false positive.
`block` puts the real table in a BLOCKQUOTE, where a reader still sees every row, and leaves a decoy
        at top level that keeps every id and row COUNT and downgrades only sev and class (to LOW and
        DOCUMENT, both in the vocabulary — a decoy outside it is caught by the grammar check instead,
        which tests nothing about blockquotes). The fourth member of R24-1's family (comment, fence,
        indented block, quote), and the one a real Markdown parser treats differently from a
        line-based reader: markdown-it parses a table inside a blockquote AS a table, so which of the
        two tables wins becomes a live question that the line reader never had. This is a LIE.

Named with a leading dot so it is not mistaken for a gate. harness-selftest.sh is its only caller.
"""
import re
import sys


def main(argv):
    if len(argv) != 3 or argv[2] not in ('hide', 'quote', 'block'):
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
    elif mode == 'block':
        def soften(row):
            c = [x.strip() for x in row.split('|')]
            if len(c) > 3:
                c[2] = re.sub(r'(?i)\b(medium|high|critical)\b', 'LOW', c[2])
                c[3] = re.sub(r'(?i)\bbehaviou?r\b', 'DOCUMENT', c[3])
            return '|'.join(c)
        decoy = table[:2] + [soften(r) for r in table[2:]]
        lines[start:end] = ['> ' + r for r in table] + [''] + decoy
    else:
        decoy = table[:3]          # header, delimiter, ONE row: deliberately a different count
        lines[start:start] = (['<!-- a quoted excerpt, deliberately with a different count:']
                              + decoy + ['-->', ''])
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(lines))


if __name__ == '__main__':
    main(sys.argv)
