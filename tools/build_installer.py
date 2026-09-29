"""Build a paste-into-Command-Bar installer from the difference between git BASE and the working tree.

usage: python3 tools/build_installer.py RELEASE BACKUP_NAME OUT.lua [--base REV]

- Every changed script under src/ becomes byte patches {offset(1-based), bytesRemoved, base64Inserted}
  against the live source. The live source must match the BASE version's byte length and SHA-256, so the
  installer refuses to touch a place whose scripts differ from what the patches were built for.
- The paste script creates ServerStorage/<BACKUP_NAME> holding Before/After/Target for every script and an
  `Installer` ModuleScript, then runs Installer("install"). Undo later with
  require(game.ServerStorage.<BACKUP_NAME>.Installer)("undo")  -- or ("install") to redo.
Sources are written with ScriptEditorService:UpdateSourceAsync, verified, and rolled back on any failure.
"""
import base64, difflib, hashlib, subprocess, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
args = [a for a in sys.argv[1:] if not a.startswith('--')]
base = 'HEAD'
if '--base' in sys.argv: base = sys.argv[sys.argv.index('--base') + 1]; args.remove(base)
release, backup_name, out_path = args[:3]

def git(*a): return subprocess.run(['git', '-C', ROOT, *a], check=True, capture_output=True).stdout
manifest = {}
for line in git('show', f'{base}:src/MANIFEST.tsv').decode('utf-8').splitlines()[1:]:
    cls, path, f = line.split('\t'); manifest[f] = (cls, path)
changed = [p[len('src/'):] for p in git('diff', '--name-only', base, '--', 'src').decode().split() if p.endswith('.lua')]
untracked = [p[len('src/'):] for p in git('ls-files', '--others', '--exclude-standard', 'src').decode().split() if p.endswith('.lua')]
assert not untracked, f'New scripts are not supported by this installer: {untracked}'

def sha(b): return hashlib.sha256(b).hexdigest()
def patches(before, after):
    ops = difflib.SequenceMatcher(None, before, after, autojunk=False).get_opcodes()
    spans = []  # (i1, i2, j1, j2) in before/after coordinates; merge edits separated by < 24 equal bytes
    for tag, i1, i2, j1, j2 in ops:
        if tag == 'equal': continue
        if spans and i1 - spans[-1][1] < 24: spans[-1] = (spans[-1][0], i2, spans[-1][2], j2)
        else: spans.append((i1, i2, j1, j2))
    out = [(i1 + 1, i2 - i1, base64.b64encode(after[j1:j2]).decode()) for i1, i2, j1, j2 in spans]
    # A rewritten file is smaller as one whole replacement than as hundreds of fragments.
    whole = [(1, len(before), base64.b64encode(after).decode())]
    if sum(len(d) + 40 for _, _, d in out) > len(whole[0][2]) + 40: out = whole
    # verify by applying in descending order
    b = before
    for off, n, data in sorted(out, key=lambda x: -x[0]):
        b = b[:off - 1] + base64.b64decode(data) + b[off - 1 + n:]
    assert b == after
    return out

def lua_str(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
specs = []
for f in sorted(changed):
    assert f in manifest, f'{f} is not a known script in the place'
    cls, path = manifest[f]
    before = git('show', f'{base}:src/{f}'); after = open(os.path.join(ROOT, 'src', f), 'rb').read()
    ps = patches(before, after)
    specs.append((path, cls, before, after, ps))
    print(f'{path}: {len(before)} -> {len(after)} bytes, {len(ps)} patches')

engine = open(os.path.join(ROOT, 'tools', 'installer_engine.lua'), 'rb').read().decode('utf-8')
tag = f'[{release}]'
engine = engine.replace('__TAG__', tag).replace('__RELEASE__', release)
spec_rows = []
for path, cls, before, after, _ in specs:
    spec_rows.append('{Path=%s,Class=%s,BeforeBytes=%d,AfterBytes=%d,BeforeSHA256=%s,AfterSHA256=%s}' % (
        lua_str(path), lua_str(cls), len(before), len(after), lua_str(sha(before)), lua_str(sha(after))))
engine = engine.replace('__SPECS__', '{' + ','.join(spec_rows) + '}')
engine_bytes = engine.encode('utf-8')

def chunked(b64, width=4000):
    parts = [b64[i:i + width] for i in range(0, len(b64), width)] or ['']
    return 'table.concat({' + ','.join(lua_str(p) for p in parts) + '})'

patch_rows = []
for path, cls, before, after, ps in specs:
    rows = ','.join('{%d,%d,%s}' % (o, n, chunked(d)) for o, n, d in ps)
    patch_rows.append('{Path=%s,Patches={%s}}' % (lua_str(path), rows))

paste = open(os.path.join(ROOT, 'tools', 'installer_paste.lua'), 'rb').read().decode('utf-8')
paste = (paste.replace('__TAG__', tag).replace('__BACKUP__', backup_name).replace('__SPECS__', '{' + ','.join(spec_rows) + '}')
         .replace('__ENGINE_B64__', chunked(base64.b64encode(engine_bytes).decode()))
         .replace('__ENGINE_SHA__', sha(engine_bytes))
         .replace('__PATCHES__', '{' + ','.join(patch_rows) + '}'))
engine_prefix = engine.split('\n-- @@SPLIT@@', 1)[0]
paste = paste.replace('-- @@ENGINE_HELPERS@@', engine_prefix)
open(out_path, 'w', encoding='ascii').write(paste)
print(f'wrote {out_path}: {len(paste)} bytes, {len(specs)} scripts')
