"""Bundle a built paste script plus BASE/after sources of the changed scripts for the mock installer test."""
import subprocess, sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
paste, out = sys.argv[1], sys.argv[2]
base = sys.argv[3] if len(sys.argv) > 3 else 'HEAD'
def git(*a): return subprocess.run(['git', '-C', ROOT, *a], check=True, capture_output=True).stdout
manifest = {}
for line in git('show', f'{base}:src/MANIFEST.tsv').decode().splitlines()[1:]:
    cls, path, f = line.split('\t'); manifest[f] = (cls, path)
changed = [p[4:] for p in git('diff', '--name-only', base, '--', 'src').decode().split() if p.endswith('.lua')]
def long(s):
    level = 1
    while (']' + '=' * level + ']') in s: level += 1
    return '[' + '=' * level + '[\n' + s + ']' + '=' * level + ']'
rows = ['PASTE=' + long(open(paste, encoding='ascii').read())]
items = []
for f in changed:
    cls, path = manifest[f]
    before = git('show', f'{base}:src/{f}').decode('utf-8'); after = open(os.path.join(ROOT, 'src', f), encoding='utf-8').read()
    items.append('{Path=%s,Class=%s,Before=%s,After=%s}' % (repr(path).replace("'", '"'), repr(cls).replace("'", '"'), long(before), long(after)))
rows.append('Scripts={' + ','.join(items) + '}')
open(out, 'w', encoding='utf-8').write('return {' + ',\n'.join(rows) + '}')
print('scripts', len(items))
