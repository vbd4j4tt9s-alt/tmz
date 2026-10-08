"""R153: the same text for the same seed, on every surface a player reads a seed's chance.
Usage: check_surfaces.py DUMP.txt (the CANON lines of dump_odds.luau) NAME=LOG ...   where each LOG holds `SURFACE <name> <seedId> <text>` lines.
Surfaces: index (the real ChestIndex), card (the real reveal card), chat (the real PullAnnouncerClient), chat-rules (PullAnnounceRules on the server), plaque (HubDisplayRules).
Every seed in the dump must appear on every surface with exactly its canonical text; prints a table (seed, rarity-free) and exits 1 on any difference."""
import re
import sys

dump = sys.argv[1]
canon = {}
for line in open(dump, encoding='utf-8'):
    if line.startswith('CANON '):
        _, sid, text, pct = line.split()
        canon[sid] = text
if len(canon) != 54:
    print('FAIL: the dump has %d canonical seeds, want 54' % len(canon))
    sys.exit(1)
surfaces = {}
for arg in sys.argv[2:]:
    name, path = arg.split('=', 1)
    surfaces[name] = {}
    for line in open(path, encoding='utf-8', errors='replace'):
        m = re.match(r'^SURFACE (\S+) (\S+) (\S+)\s*$', line.rstrip('\n'))
        if m and m.group(1) == name:
            surfaces[name].setdefault(m.group(2), []).append(m.group(3))
bad = 0
for name, rows in surfaces.items():
    missing = sorted(set(canon) - set(rows))
    extra = sorted(set(rows) - set(canon))
    wrong = sorted(sid for sid, texts in rows.items() if sid in canon and any(t != canon[sid] for t in texts))
    ok = not missing and not extra and not wrong
    print('%-11s %d seeds %s' % (name, len(rows), 'all equal to the canonical text' if ok else 'DIFFER'))
    for sid in missing:
        print('  missing: %s' % sid)
    for sid in extra:
        print('  not a seed: %s' % sid)
    for sid in wrong:
        print('  %s: %s (canonical %s)' % (sid, rows[sid], canon[sid]))
    bad += (not ok)
# one line per seed: every surface the same
different = [sid for sid in canon if len({canon[sid]} | {t for rows in surfaces.values() for t in rows.get(sid, [])}) != 1]
print('R153 surfaces: %d seeds x %d surfaces (%s): %s' % (len(canon), len(surfaces), ', '.join(sorted(surfaces)), 'identical text on every surface' if not different and not bad else 'MISMATCH %s' % different))
sys.exit(1 if (bad or different) else 0)
