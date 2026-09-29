import ctypes, struct, sys
zstd = ctypes.CDLL("libzstd.so.1")
zstd.ZSTD_decompress.restype = ctypes.c_size_t
zstd.ZSTD_decompress.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t]
zstd.ZSTD_isError.argtypes=[ctypes.c_size_t]
lz4 = ctypes.CDLL("liblz4.so.1")
lz4.LZ4_decompress_safe.argtypes=[ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int, ctypes.c_int]

def decomp(data, ulen):
    out = ctypes.create_string_buffer(ulen)
    if data[:4] == b'\x28\xb5\x2f\xfd':
        n = zstd.ZSTD_decompress(out, ulen, data, len(data))
        assert not zstd.ZSTD_isError(n)
    else:
        n = lz4.LZ4_decompress_safe(data, out, len(data), ulen)
    assert n == ulen, (n, ulen)
    return out.raw

def deinterleave_i32(b, off, n):
    raw = b[off:off+4*n]
    vals = []
    for i in range(n):
        v = (raw[i]<<24)|(raw[n+i]<<16)|(raw[2*n+i]<<8)|raw[3*n+i]
        vals.append((v>>1) ^ -(v&1))
    return vals, off+4*n

def refs(b, off, n):
    vals, off = deinterleave_i32(b, off, n)
    acc=0; out=[]
    for v in vals: acc+=v; out.append(acc)
    return out, off

def rstr(b, off):
    (l,) = struct.unpack_from('<I', b, off); off+=4
    return b[off:off+l], off+l

def load(path):
    d = open(path,'rb').read()
    assert d[:8]==b'<roblox!'
    pos = 32
    classes = {}  # id -> (name, [refs])
    inst = {}     # ref -> {'class':, props}
    parent = {}
    while pos < len(d):
        name = d[pos:pos+4]; clen, ulen, _ = struct.unpack_from('<III', d, pos+4); pos+=16
        if clen == 0: body = d[pos:pos+ulen]; pos+=ulen
        else: body = decomp(d[pos:pos+clen], ulen); pos+=clen
        if name == b'INST':
            cid, = struct.unpack_from('<I', body, 0)
            cname, o = rstr(body, 4); o += 1
            n, = struct.unpack_from('<I', body, o); o+=4
            rs, o = refs(body, o, n)
            classes[cid] = (cname.decode(), rs)
            for r in rs: inst[r] = {'ClassName': cname.decode()}
        elif name == b'PROP':
            cid, = struct.unpack_from('<I', body, 0)
            pname, o = rstr(body, 4); pname = pname.decode()
            t = body[o]; o+=1
            cname, rs = classes[cid]
            if t == 0x01 and pname in ('Name','Source','Value'):
                for r in rs:
                    s, o = rstr(body, o)
                    inst[r][pname] = s
            elif t == 0x02 and pname in ('Disabled','Enabled'):
                for i,r in enumerate(rs): inst[r][pname] = bool(body[o+i])
            elif t == 0x13 and pname == 'Value':
                vals, _ = refs(body, o, len(rs))
                for r,v in zip(rs,vals): inst[r]['ValueRef'] = v
            elif t == 0x12 and pname == 'RunContext':
                n=len(rs); raw=body[o:o+4*n]
                for i,r in enumerate(rs):
                    inst[r][pname]=(raw[i]<<24)|(raw[n+i]<<16)|(raw[2*n+i]<<8)|raw[3*n+i]
        elif name == b'PRNT':
            n, = struct.unpack_from('<I', body, 1)
            ch, o = refs(body, 5, n)
            pa, o = refs(body, o, n)
            parent.update(zip(ch, pa))
        elif name == b'END\x00':
            break
    return inst, parent

def path_of(r, inst, parent):
    parts=[]
    while r in inst:
        parts.append(inst[r].get('Name', b'?').decode('utf-8','replace'))
        r = parent.get(r, -1)
    return list(reversed(parts))
