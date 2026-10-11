"""Synthetic release whose scripts are 100 KB and more, with multibyte text, for the installer's chunked backups.

usage: python3 tools/tests/chunk_fixture.py OUTDIR [LUAU]
Builds a throw-away git repo (base commit = the old scripts, working tree = the new ones) next to copies of the installer tools,
builds the installer from it, and writes OUTDIR/inst_bundle.luau plus copies of roblox.luau and test_installer.luau. Then it runs
`LUAU test_installer.luau` there (default /opt/luau/luau) and exits 1 unless it ends with "0 failures".

Scripts: BigData (changed, 241,023 -> 322,000 bytes), BigNew (added, 305,000 bytes), Edge (changed, 99,999 -> 100,000 bytes: one StringValue
becomes two chunks) and Small. In the big ones a 4-byte emoji / 3-byte infinity sign starts at byte offsets 99998, 199995 and
299992, so a cut at 100,000 / 200,000 / 300,000 bytes (or one byte earlier) would split a character; filler lines carry both too."""
import os, shutil, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__)); TOOLS = os.path.dirname(HERE)
out_dir = os.path.abspath(sys.argv[1]); luau = sys.argv[2] if len(sys.argv) > 2 else '/opt/luau/luau'
EMOJI, INF = '\U0001F600', '∞'
MARKS = {99998: EMOJI, 199995: INF, 299992: EMOJI}

def pad(buf, k):
    # exactly k bytes of nothing: blank lines, or a comment line
    if k > 0: buf += b'\n' * k if k < 3 else b'--' + b'-' * (k - 3) + b'\n'
def fill(buf, target, marks, start=0):
    """Append filler lines until buf is `target` bytes long. A mark (offset, char) in marks becomes a '-- char' comment line whose
    character starts exactly at that byte offset of buf. Lines depend on a counter only, never on the offset."""
    pending = sorted((o, c) for o, c in marks.items() if len(buf) <= o - 3 and o + len(c.encode()) + 1 <= target)
    n = start
    while len(buf) < target:
        line = ('local v%d = {"%s", "%s", %d}\n' % (n, INF, EMOJI, n)).encode(); n += 1
        if pending and len(buf) + len(line) > pending[0][0] - 3:
            o, c = pending.pop(0); pad(buf, o - 3 - len(buf)); buf += b'-- ' + c.encode() + b'\n'
        elif len(buf) + len(line) > target: pad(buf, target - len(buf))
        else: buf += line
    assert len(buf) == target
    return buf
def check_marks(text, marks):
    for o, c in marks.items():
        if o + len(c.encode()) <= len(text):
            assert text[o:o + len(c.encode())] == c.encode(), (o, c)
            assert all(0x80 <= b < 0xC0 for b in text[o + 1:o + len(c.encode())])  # a cut inside them splits the character
    text.decode('utf-8')

TAIL = b'return {}\n'
def big_data():
    head = fill(bytearray(), 240000, MARKS)
    mid = fill(bytearray(), 1000, {}, start=900000)
    before = bytes(head + b'-- version 1\n' + mid + TAIL)
    grown = bytearray(head + ('-- version 2 %s %s (longer)\n' % (INF, EMOJI)).encode() + mid)
    after = bytes(fill(grown, 322000 - len(TAIL), MARKS, start=700000) + TAIL)
    return before, after
def big_new(): return bytes(fill(bytearray(), 305000 - len(TAIL), MARKS) + TAIL)
def edge(): return b'--' + b'e' * 99996 + b'\n', b'--' + b'e' * 99997 + b'\n'
before_data, after_data = big_data(); new_data = big_new(); edge_before, edge_after = edge()
for t in (before_data, after_data, new_data): check_marks(t, MARKS)
assert len(before_data) > 200000 and len(after_data) > 300000 and len(new_data) > 300000 and (len(edge_before), len(edge_after)) == (99999, 100000)

def run(*cmd, cwd): subprocess.run(cmd, cwd=cwd, check=True)
def write(root, rel, data):
    path = os.path.join(root, rel); os.makedirs(os.path.dirname(path), exist_ok=True); open(path, 'wb').write(data)
repo = tempfile.mkdtemp(prefix='chunk_fixture_')
try:
    for f in ('build_installer.py', 'installer_engine.lua', 'installer_paste.lua', 'installer_testdata.py'):
        write(repo, 'tools/' + f, open(os.path.join(TOOLS, f), 'rb').read())
    write(repo, 'src/MANIFEST.tsv', b'class\tpath_in_place\tfile\n' + b''.join(
        b'ModuleScript\tReplicatedStorage/%s\tReplicatedStorage/%s.lua\n' % (n, n) for n in (b'BigData', b'Edge', b'Small')))
    write(repo, 'src/ReplicatedStorage/BigData.lua', before_data)
    write(repo, 'src/ReplicatedStorage/Edge.lua', edge_before)
    write(repo, 'src/ReplicatedStorage/Small.lua', b'return 1\n')
    run('git', 'init', '-q', cwd=repo)
    run('git', '-c', 'user.name=t', '-c', 'user.email=t@t', 'add', '-A', cwd=repo)
    run('git', '-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-q', '-m', 'base', cwd=repo)
    base = subprocess.run(['git', 'rev-parse', '--short', 'HEAD'], cwd=repo, check=True, capture_output=True, text=True).stdout.strip()
    write(repo, 'src/ReplicatedStorage/BigData.lua', after_data)
    write(repo, 'src/ReplicatedStorage/Edge.lua', edge_after)
    write(repo, 'src/ReplicatedStorage/Small.lua', b'return 2 -- ' + INF.encode() + b'\n')
    write(repo, 'src/ReplicatedStorage/BigNew.lua', new_data)
    run(sys.executable, 'tools/build_installer.py', 'R999', 'ChestChase_R999_Backup', 'inst.lua', '--base', base, cwd=repo)
    os.makedirs(out_dir, exist_ok=True)
    run(sys.executable, 'tools/installer_testdata.py', 'inst.lua', os.path.join(out_dir, 'inst_bundle.luau'), 'ChestChase_R999_Backup', base, cwd=repo)
finally: shutil.rmtree(repo, ignore_errors=True)
for f in ('roblox.luau', 'test_installer.luau'): shutil.copy(os.path.join(HERE, f), out_dir)
result = subprocess.run([luau, 'test_installer.luau'], cwd=out_dir, capture_output=True, text=True)
print(result.stdout + result.stderr, end='')
sys.exit(0 if result.returncode == 0 and result.stdout.strip().endswith(' 0 failures') else 1)
