"""Bundle a built paste script plus BASE/after sources of the changed scripts for the mock installer test."""
import subprocess, sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
paste, out, backup = sys.argv[1], sys.argv[2], sys.argv[3]
base = sys.argv[4] if len(sys.argv) > 4 else '46043d4'
def git(*a): return subprocess.run(['git', '-C', ROOT, *a], check=True, capture_output=True).stdout
manifest = {}
for line in git('show', f'{base}:src/MANIFEST.tsv').decode().splitlines()[1:]:
    cls, path, f = line.split('\t'); manifest[f] = (cls, path)
status = [l.split('\t') for l in git('diff', '--name-status', base, '--', 'src').decode().splitlines()]
changed = [p[4:] for st, p in status if p.endswith('.lua') and st == 'M']
added = [p[4:] for st, p in status if p.endswith('.lua') and st == 'A']
added += [p[4:] for p in git('ls-files', '--others', '--exclude-standard', 'src').decode().split() if p.endswith('.lua')]
def long(s):
    level = 1
    while (']' + '=' * level + ']') in s: level += 1
    return '[' + '=' * level + '[\n' + s + ']' + '=' * level + ']'
rows = ['PASTE=' + long(open(paste, encoding='ascii').read()), 'BACKUP=%s' % repr(backup).replace("'", '"')]
items = []
for f in changed:
    cls, path = manifest[f]
    before = git('show', f'{base}:src/{f}').decode('utf-8'); after = open(os.path.join(ROOT, 'src', f), encoding='utf-8').read()
    items.append('{Path=%s,Class=%s,Before=%s,After=%s}' % (repr(path).replace("'", '"'), repr(cls).replace("'", '"'), long(before), long(after)))
for f in added:
    for suffix, cls in (('.server.lua', 'Script'), ('.client.lua', 'LocalScript'), ('.lua', 'ModuleScript')):
        if f.endswith(suffix): path = f[:-len(suffix)]; break
    after = open(os.path.join(ROOT, 'src', f), encoding='utf-8').read()
    items.append('{Path=%s,Class=%s,New=true,After=%s}' % (repr(path).replace("'", '"'), repr(cls).replace("'", '"'), long(after)))
rows.append('Scripts={' + ','.join(items) + '}')
open(out, 'w', encoding='utf-8').write('return {' + ',\n'.join(rows) + '}')
print('scripts', len(items))
