"""Build a paste-into-Command-Bar installer from the difference between git BASE and the working tree.

usage: python3 tools/build_installer.py RELEASE BACKUP_NAME OUT.lua [--base REV] [--retire retire.json] [--manifest FILE]

--manifest FILE: read the script list (class, path in the place, file) from FILE instead of BASE's src/MANIFEST.tsv. Use it when
  BASE's manifest is stale, e.g. docs/releases/R147_base_manifest.tsv = tools/export.py of the live place (its scripts match BASE).

- Every changed script under src/ becomes byte patches {offset(1-based), bytesRemoved, base64Inserted}
  against the live source. The live source must match the BASE version's byte length and SHA-256, so the
  installer refuses to touch a place whose scripts differ from what the patches were built for.
- The paste script creates ServerStorage/<BACKUP_NAME> holding Before/After/Target for every script and an
  `Installer` ModuleScript, then runs Installer("install"). Undo later with
  require(game.ServerStorage.<BACKUP_NAME>.Installer)("undo")  -- or ("install") to redo.
Sources are written with ScriptEditorService:UpdateSourceAsync, verified, and rolled back on any failure.

RETIRING instances (--retire retire.json)
- Scripts deleted from src/ are NOT removed from the place by themselves (nothing requires them, the owner may have removed
  them already), and non-script instances (folders, parts, RemoteEvents...) are never touched by the script patches. To take
  objects out of the place, list them in a JSON file and pass it with --retire; one explicit list covers scripts and non-scripts.
- Format: a JSON list of paths, each path a list of instance names from the service down. Names are exact and may contain
  '/' or '.', which is why paths are name arrays and not strings. Example (docs/releases/R147_retire.json):
      [["Workspace", "Keycap/Keyboard"], ["Workspace", "Verity"], ["ReplicatedStorage", "KeyboardCore142"]]
  A path needs at least a service plus one name. No duplicates, and no path inside another (retiring a folder retires
  everything in it, scripts included). A retired path may not be a script this release patches or adds (build error); a script
  that is still in src/ but retired only produces a WARNING (delete it from src/ so the next release does not patch it).
  Deleted src/ scripts are reported as retired when a path covers them and as "left in the place" when none does.
- At install time each path is looked up first, before anything changes: a missing object is skipped and printed
  ("Skipped Workspace.Verity (not found ...)"), a path where two siblings share a name refuses the whole install, nothing changed.
- The installer then MOVES (never destroys) each found object into ServerStorage/<BACKUP>/Retired/NN/Parked, as part of the same
  all-or-nothing transaction as the script writes: on any failure everything is moved/written back and nothing stays half-done.
  Every Script/LocalScript inside a retired object (or the object itself) has its Disabled state recorded in the backup, is
  set Disabled while parked, and gets its recorded Disabled state back on undo. What was retired is printed ("Retired ...").
- Undo moves each object back to its exact original parent under its exact original name, then restores Disabled. It refuses
  (changing nothing) if the original parent is gone or ambiguous, a same-named object already sits there, or a parked object
  was moved by hand. Redo ("install") parks them again.
"""
import base64, difflib, hashlib, json, re, subprocess, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
args = [a for a in sys.argv[1:] if not a.startswith('--')]
base = '46043d4'  # r107-live: what is live in the place; installers patch from here
if '--base' in sys.argv: base = sys.argv[sys.argv.index('--base') + 1]; args.remove(base)
retire_file = None
manifest_file = None
if '--manifest' in sys.argv: manifest_file = sys.argv[sys.argv.index('--manifest') + 1]; args.remove(manifest_file)
if '--retire' in sys.argv: retire_file = sys.argv[sys.argv.index('--retire') + 1]; args.remove(retire_file)
release, backup_name, out_path = args[:3]

def git(*a): return subprocess.run(['git', '-C', ROOT, *a], check=True, capture_output=True).stdout
manifest = {}
manifest_text = open(os.path.join(ROOT, manifest_file), encoding='utf-8').read() if manifest_file else git('show', f'{base}:src/MANIFEST.tsv').decode('utf-8')
for line in manifest_text.splitlines()[1:]:
    cls, path, f = line.split('\t'); manifest[f] = (cls, path)
# A manifest file must describe BASE exactly: every script it lists is BASE's file (the patches are built from BASE).
if manifest_file:
    in_base = {p[len('src/'):] for p in git('ls-tree', '-r', '--name-only', base, 'src').decode().split() if p.endswith('.lua')}
    assert set(manifest) == in_base, f'{manifest_file} does not list exactly the scripts in {base}: {sorted(set(manifest) ^ in_base)[:8]}'
status = [l.split('\t') for l in git('diff', '--name-status', base, '--', 'src').decode().splitlines()]
changed = [p[len('src/'):] for s, p in status if p.endswith('.lua') and s == 'M']
added = [p[len('src/'):] for s, p in status if p.endswith('.lua') and s == 'A']
added += [p[len('src/'):] for p in git('ls-files', '--others', '--exclude-standard', 'src').decode().split() if p.endswith('.lua')]
# Scripts deleted from src/ are left alone in the place unless the --retire list covers them.
deleted = [p[len('src/'):] for s, p in status if p.endswith('.lua') and s == 'D']
assert all(s in ('M', 'A', 'D') for s, p in status if p.endswith('.lua')), f'Renamed scripts are not supported: {status}'

def load_retire(path):
    """A JSON list of paths; a path is a list of instance names, service first (names may contain '/')."""
    with open(path, encoding='utf-8') as fh: data = json.load(fh)
    assert isinstance(data, list), f'{path}: expected a JSON list of paths'
    seen = []
    for names in data:
        assert isinstance(names, list) and len(names) >= 2 and all(isinstance(n, str) and n for n in names), \
            f'{path}: each path must be a list of at least two non-empty names (service first), got {names!r}'
        assert names not in seen, f'{path}: duplicate path {names!r}'
        seen.append(names)
    for a in seen:
        for b in seen:
            assert a is b or a != b[:len(a)], f'{path}: {b!r} is inside {a!r}; list only the outer object'
    return seen
def display_path(names):
    # same notation the installer prints: Workspace.Verity, Workspace["Keycap/Keyboard"]
    return ''.join((n if i == 0 else '.' + n) if re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', n) else '["%s"]' % n for i, n in enumerate(names))
def retired_by(src_file, retire):
    """The retire path covering a src/ file (src/ names '/' as '_' and same-named siblings 'Name~2'), or None."""
    parts = src_file.split('/')
    for suffix in ('.server.lua', '.client.lua', '.lua'):
        if parts[-1].endswith(suffix): parts[-1] = parts[-1][:-len(suffix)]; break
    parts = [re.sub(r'~\d+$', '', x) for x in parts]
    for names in retire:
        n = [x.replace('/', '_') for x in names]
        if parts[:len(n)] == n: return names
    return None
retire = load_retire(retire_file) if retire_file else []
for f in deleted:
    r = retired_by(f, retire)
    print(f'{f}: deleted in src/, ' + (f'retired by --retire ({display_path(r)})' if r else 'not touched by the installer (left in the place)'))
def added_script(f):
    # Class from the Rojo suffix; folder-style init scripts are not supported for added scripts.
    assert not os.path.basename(f).startswith('init.'), f'{f}: add scripts as plain files, not init scripts'
    for suffix, cls in (('.server.lua', 'Script'), ('.client.lua', 'LocalScript'), ('.lua', 'ModuleScript')):
        if f.endswith(suffix): return cls, f[:-len(suffix)]

def sha(b): return hashlib.sha256(b).hexdigest()
def byte_ops(b, a):
    # Byte-level opcodes. A char-level SequenceMatcher on a big region is quadratic (R151: 100+ heavily edited scripts took
    # minutes each), so diff by lines first and refine only small changed line blocks byte by byte; a big changed block is
    # replaced whole. Same result shape as SequenceMatcher.get_opcodes() (byte offsets into b / a).
    if len(b) + len(a) <= 4000:
        return difflib.SequenceMatcher(None, b, a, autojunk=False).get_opcodes()
    bl, al = b.splitlines(keepends=True), a.splitlines(keepends=True)
    bo, ao = [0], [0]
    for line in bl: bo.append(bo[-1] + len(line))
    for line in al: ao.append(ao[-1] + len(line))
    out = []
    for t, i1, i2, j1, j2 in difflib.SequenceMatcher(None, bl, al, autojunk=False).get_opcodes():
        x1, x2, y1, y2 = bo[i1], bo[i2], ao[j1], ao[j2]
        if t == 'equal':
            out.append(('equal', x1, x2, y1, y2))
        elif t == 'replace' and (x2 - x1) + (y2 - y1) <= 4000:
            for tt, k1, k2, l1, l2 in difflib.SequenceMatcher(None, b[x1:x2], a[y1:y2], autojunk=False).get_opcodes():
                out.append((tt, x1 + k1, x1 + k2, y1 + l1, y1 + l2))
        else:
            out.append(('replace' if t == 'replace' else t, x1, x2, y1, y2))
    return out
def patches(before, after):
    # Only diff the region between the common prefix and suffix; big files usually change in a few spots.
    head = 0
    while head < min(len(before), len(after)) and before[head] == after[head]: head += 1
    tail = 0
    while tail < min(len(before), len(after)) - head and before[-1 - tail] == after[-1 - tail]: tail += 1
    mid_b, mid_a = before[head:len(before) - tail], after[head:len(after) - tail]
    ops = [(t, i1 + head, i2 + head, j1 + head, j2 + head) for t, i1, i2, j1, j2 in byte_ops(mid_b, mid_a)]
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
new_paths = set()
for f in sorted(added):
    cls, path = added_script(f)
    after = open(os.path.join(ROOT, 'src', f), 'rb').read()
    specs.append((path, cls, None, after, [(1, 0, base64.b64encode(after).decode())]))
    new_paths.add(path)
    print(f'{path}: NEW {cls}, {len(after)} bytes')

# A retired object must not also be written to: refuse paths that equal or contain a script this release patches or adds.
for path, *_ in specs:
    for names in retire:
        assert path.split('/')[:len(names)] != names, f'retire path {display_path(names)} contains {path}, which this release patches or adds'
# Scripts still in src/ that sit on a retire path: the place loses them, so src/ should too (else the next release patches them).
for f in sorted(p[len('src/'):] for p in git('ls-files', 'src').decode().split('\n') if p.endswith('.lua')):
    r = retired_by(f, retire)
    if r and os.path.exists(os.path.join(ROOT, 'src', f)): print(f'WARNING: src/{f} is still in src/ but retired by {display_path(r)}; delete it from src/')
for names in retire: print(f'retire: {display_path(names)}')

engine = open(os.path.join(ROOT, 'tools', 'installer_engine.lua'), 'rb').read().decode('utf-8')
tag = f'[{release}]'
engine = engine.replace('__TAG__', tag).replace('__RELEASE__', release)
spec_rows = []
for path, cls, before, after, _ in specs:
    if before is None:
        spec_rows.append('{Path=%s,Class=%s,New=true,AfterBytes=%d,AfterSHA256=%s}' % (lua_str(path), lua_str(cls), len(after), lua_str(sha(after))))
        continue
    spec_rows.append('{Path=%s,Class=%s,BeforeBytes=%d,AfterBytes=%d,BeforeSHA256=%s,AfterSHA256=%s}' % (
        lua_str(path), lua_str(cls), len(before), len(after), lua_str(sha(before)), lua_str(sha(after))))
def lua_name(name):
    # printable ASCII as is, every other byte as a 3-digit decimal escape: the paste script stays ASCII-only
    return '"' + ''.join(chr(b) if 32 <= b < 127 and chr(b) not in '\\"' else '\\%03d' % b for b in name.encode('utf-8')) + '"'
retire_lua = '{' + ','.join('{' + ','.join(lua_name(n) for n in names) + '}' for names in retire) + '}'
engine = engine.replace('__SPECS__', '{' + ','.join(spec_rows) + '}').replace('__RETIRE__', retire_lua)
engine_bytes = engine.encode('utf-8')

def chunked(b64, width=4000):
    parts = [b64[i:i + width] for i in range(0, len(b64), width)] or ['']
    return 'table.concat({' + ','.join(lua_str(p) for p in parts) + '})'

patch_rows = []
for path, cls, before, after, ps in specs:
    rows = ','.join('{%d,%d,%s}' % (o, n, chunked(d)) for o, n, d in ps)
    patch_rows.append('{Path=%s,Patches={%s}}' % (lua_str(path), rows))

paste = open(os.path.join(ROOT, 'tools', 'installer_paste.lua'), 'rb').read().decode('utf-8')
paste = (paste.replace('__TAG__', tag).replace('__BACKUP__', backup_name).replace('__SPECS__', '{' + ','.join(spec_rows) + '}').replace('__RETIRE__', retire_lua)
         .replace('__ENGINE_B64__', chunked(base64.b64encode(engine_bytes).decode()))
         .replace('__ENGINE_SHA__', sha(engine_bytes))
         .replace('__PATCHES__', '{' + ','.join(patch_rows) + '}'))
engine_prefix = engine.split('\n-- @@SPLIT@@', 1)[0]
paste = paste.replace('-- @@ENGINE_HELPERS@@', engine_prefix)
open(out_path, 'w', encoding='ascii').write(paste)
print(f'wrote {out_path}: {len(paste)} bytes, {len(specs)} scripts')
