"""Read Workspace's streaming settings out of a binary .rbxl (read-only) and print them as the Luau global line run_track_music157.sh puts in front of the scene.
Usage: python3 place_streaming157.py <place.rbxl> <fixed|old>      -> T157={Expect='fixed',Enabled=true,Target=1024,Min=64,Behavior=2,Integrity=3}
(StreamOutBehavior: 0 Default, 1 LowMemory, 2 Opportunistic; StreamingIntegrityMode: 3 PauseOutsideLoadedArea.) tools/rbxl.py does the chunk decompression."""
import os, struct, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', '..', '..', 'tools'))
import rbxl  # noqa: E402

path, expect = sys.argv[1], sys.argv[2]
d = open(path, 'rb').read()
assert d[:8] == b'<roblox!'
pos = 32
classes, got = {}, {}
while pos < len(d):
    name = d[pos:pos + 4]
    clen, ulen, _ = struct.unpack_from('<III', d, pos + 4)
    pos += 16
    if clen == 0:
        body = d[pos:pos + ulen]; pos += ulen
    else:
        body = rbxl.decomp(d[pos:pos + clen], ulen); pos += clen
    if name == b'INST':
        cid, = struct.unpack_from('<I', body, 0)
        cname, o = rbxl.rstr(body, 4); o += 1
        n, = struct.unpack_from('<I', body, o); o += 4
        rs, o = rbxl.refs(body, o, n)
        classes[cid] = (cname.decode(), rs)
    elif name == b'PROP':
        cid, = struct.unpack_from('<I', body, 0)
        pname, o = rbxl.rstr(body, 4); pname = pname.decode()
        t = body[o]; o += 1
        cname, rs = classes[cid]
        if cname != 'Workspace' or pname not in ('StreamingEnabled', 'StreamingTargetRadius', 'StreamingMinRadius', 'StreamOutBehavior', 'StreamingIntegrityMode'):
            continue
        n = len(rs)
        if t == 0x02:
            got[pname] = bool(body[o])
        elif t == 0x03:
            got[pname] = rbxl.deinterleave_i32(body, o, n)[0][0]
        elif t == 0x12:
            raw = body[o:o + 4 * n]
            got[pname] = (raw[0] << 24) | (raw[n] << 16) | (raw[2 * n] << 8) | raw[3 * n]
    elif name == b'END\x00':
        break
print("T157={Expect='%s',Enabled=%s,Target=%s,Min=%s,Behavior=%s,Integrity=%s}" % (
    expect, 'true' if got.get('StreamingEnabled') else 'false', got.get('StreamingTargetRadius', 1024), got.get('StreamingMinRadius', 64),
    got.get('StreamOutBehavior', 0), got.get('StreamingIntegrityMode', 0)))
