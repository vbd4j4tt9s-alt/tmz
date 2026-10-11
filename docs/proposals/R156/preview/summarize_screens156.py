"""R156 preview: SCREEN lines of screens156.luau (R155 = 'current' and the proposal = 'fresh', 36 screens) -> a table for the write-up.
Usage: python3 -I summarize_screens156.py SCRATCH/screens.log"""
import sys

rows = {}
for line in open(sys.argv[1], encoding='utf-8'):
    if not line.startswith('SCREEN '):
        continue
    mode, name, size, bars, clear, gap, details, hit, text = line[len('SCREEN '):].strip().split('|')
    rows.setdefault(name + ' ' + size, {})[mode] = dict(bars=bars[5:], clear=clear == 'clear=true', gap=int(gap[4:]), details=details[5:] == 'shown', hit=hit[4:], text=text[5:])
print('SCREENS %-34s %-26s %-26s %s' % ('screen', 'R155 (bars, gap)', 'proposal (bars, gap)', 'name rows: the whole label box / the middle 240 px of text run into'))
tight = new_hit = hidden = unclear = 0
for key, d in rows.items():
    c, n = d['current'], d['fresh']
    print('SCREENS %-34s %-26s %-26s %s%s' % (key, '%s, %d px' % (c['bars'], c['gap']), '%s, %d px' % (n['bars'], n['gap']), 'shown' if n['details'] else 'hidden on this screen (as in R155)' if not c['details'] else 'hidden',
                                              ' | box: ' + n['hit'] + ' (R155: ' + c['hit'] + '), text: ' + n['text'] + ' (R155: ' + c['text'] + ')' if n['hit'] != '-' or n['text'] != '-' else ''))
    tight += n['gap'] <= 8
    new_hit += n['text'] != '-' and c['text'] == '-'
    hidden += not n['details']
    unclear += not n['clear']
print('SCREENS %d screens: gap <= 8 px on %d; no clear spot on %d; name rows hidden by HudLayout on %d (R155: %d); name text (middle 240 px) newly running into another box (R155: not) on %d' % (
    len(rows), tight, unclear, hidden, sum(not d['current']['details'] for d in rows.values()), new_hit))
