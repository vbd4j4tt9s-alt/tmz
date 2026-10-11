"""R158: where SpeedGainPopup.client.lua asks the style for the screen's popup size.
Usage: python3 check_layout_site158.py <SpeedGainPopup.client.lua>   (exit 0 = fine; run_popups158.sh and mutate_popups158.py call it)

The size of a popup on this screen (SpeedPopupStyle.Layout: the unit with the size share, and the fan) is worked out ONCE per popup, when it is born (spawnPopup), never in the code that
runs for every popup every frame (apply, updateEntry, step, refreshZoom): that is what keeps "no per-frame work added" true. The client has exactly one call of Layout, inside spawnPopup,
and never calls SizeScale / FanScale / Unit itself any more (Layout is the one door)."""
import re
import sys

lines = open(sys.argv[1], encoding='utf-8').read().split('\n')
problems = []
calls = []
current = None
for i, line in enumerate(lines, 1):
    m = re.match(r'^local function (\w+)\(', line)
    if m:
        current = m.group(1)
    code = line.split('--')[0] if '"' not in line.split('--')[0] else line   # (a comment after the code; a line with a string keeps its text)
    for name in ('Layout', 'SizeScale', 'FanScale', 'Style.Unit'):
        if name + '(' in code:
            calls.append((name, current, i))
layout = [c for c in calls if c[0] == 'Layout']
if len(layout) != 1:
    problems.append('Style.Layout is called %d times (want exactly 1): %s' % (len(layout), layout))
elif layout[0][1] != 'spawnPopup':
    problems.append('Style.Layout is called in %s (line %d), not in spawnPopup' % (layout[0][1], layout[0][2]))
for name, fn, i in calls:
    if name != 'Layout':
        problems.append('%s( is called in %s (line %d): the client takes the screen\'s size and fan from Style.Layout only' % (name, fn, i))
if problems:
    print('\n'.join(problems))
    sys.exit(1)
print('ok: the client asks Style.Layout once, in spawnPopup (line %d), and nowhere else' % layout[0][2])
