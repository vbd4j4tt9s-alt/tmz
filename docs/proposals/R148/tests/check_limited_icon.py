"""R148: checks the Limited tab icon with the REAL zstd library and writes the sidecar the Luau test reads.

  python3 check_limited_icon.py OUT/limited_raw.luau

For every logo of BiomeIconData.lua (Forest ... Mech and Limited) the RGBA field is decoded the way the game decodes it
(EncodingService:Base64Decode -> DecompressBuffer(Zstd)): base64 -> a zstd frame (magic 28 B5 2F FD, content size 36864) -> 96x96x4 bytes.
For Limited the decoded pixels are also compared with docs/proposals/R148/limited_icon.png (what limited_icon.py draws and
gen_limited_icon.py encoded) and with a re-encode check of the prepared fallback (ArtworkFallbackData89.lua). The sidecar holds the raw
pixels (hex), the compressed length and its Adler-32, so test_index_limited.luau can drive the real ArtworkRuntime87 with them.
Needs python's `zstandard` (pip install zstandard; installed under OUT/pylib automatically if it is missing).
"""
import base64, os, re, subprocess, sys, zlib

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
RS = os.path.join(REPO, 'src', 'ReplicatedStorage')
out = sys.argv[1] if len(sys.argv) > 1 else 'limited_raw.luau'


def zstd():
    try:
        import zstandard
        return zstandard
    except ImportError:
        target = os.path.join(os.path.dirname(os.path.abspath(out)), 'pylib')
        print('python module zstandard missing: pip install --target', target)
        subprocess.run([sys.executable, '-m', 'pip', 'install', '--quiet', '--target', target, 'zstandard'], check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        sys.path.insert(0, target)
        try:
            import zstandard
            return zstandard
        except ImportError:
            sys.exit('FAIL: no zstandard module (pip install zstandard)')


z = zstd()
fails = 0


def check(ok, msg):
    global fails
    print(('ok   ' if ok else 'FAIL ') + msg)
    if not ok:
        fails += 1


src = open(os.path.join(RS, 'BiomeIconData.lua'), encoding='utf-8').read()
entries = dict(re.findall(r'^(\w+)=\{Size=96,TinyWidth=24,TinyHeight=24,RGBA="([^"]+)"', src, re.M))
check(set(entries) == {'Forest', 'Jungle', 'Desert', 'Snow', 'Crystal', 'Lava', 'Storm', 'Mech', 'Limited'}, 'BiomeIconData kinds: ' + ', '.join(entries))
raws = {}
for kind, field in entries.items():
    comp = base64.b64decode(field, validate=True)
    params = z.get_frame_parameters(comp)
    raw = z.ZstdDecompressor().decompress(comp)
    raws[kind] = (comp, raw)
    check(comp[:4] == bytes.fromhex('28b52ffd') and params.content_size == 96 * 96 * 4 and len(raw) == 96 * 96 * 4 and params.has_checksum is False,
          f'{kind}: base64 -> zstd frame (content size {params.content_size}, no checksum) -> {len(raw)} bytes of RGBA')
comp, raw = raws['Limited']
mech = raws['Mech'][0]
check(comp[4:7] == mech[4:7], 'Limited has the same zstd frame header bytes as Mech (FHD %02x, content size field %s)' % (comp[4], comp[5:7].hex()))
try:
    from PIL import Image
    png = Image.open(os.path.join(REPO, 'docs', 'proposals', 'R148', 'limited_icon.png')).convert('RGBA')
    check(png.size == (96, 96) and png.tobytes() == raw, 'the decoded pixels are exactly docs/proposals/R148/limited_icon.png')
    alpha = png.getchannel('A')
    check(alpha.getpixel((0, 0)) == 0 and alpha.getpixel((95, 95)) == 0 and alpha.getpixel((48, 40)) == 255 and 0.25 < sum(1 for v in alpha.tobytes() if v > 0) / 9216 < 0.9,
          'transparent corners, an opaque centre, a reasonable amount of picture (%.0f%% visible)' % (100 * sum(1 for v in alpha.tobytes() if v > 0) / 9216))
except ImportError:
    print('skip PIL not available: the PNG comparison')
fb = open(os.path.join(RS, 'ArtworkFallbackData89.lua'), encoding='utf-8').read()
m = re.search(r'\["Limited"\]="([0-9a-f]+)"', fb)
check(m is not None, 'ArtworkFallbackData89 has a Limited entry')
if m:
    b = bytes.fromhex(m.group(1))
    w, h, n = b[0], b[1], b[2]
    pos = 3 + 3 * n
    count = b[pos] + b[pos + 1] * 256
    pos += 2
    ok = (w, h) == (64, 64) and n <= 255
    for _ in range(count):
        x, y, ww, k = b[pos:pos + 4]
        pos += 4 + 3 * k
        ok = ok and 2 <= k <= 6 and x + ww <= 64 and y < 64
    check(ok and pos == len(b), f'the prepared fallback parses exactly ({count} strips, {n} colours, {len(b)} bytes)')
lua = 'return {Length=%d,Adler=%d,Hex="%s"}\n' % (len(comp), zlib.adler32(comp), raw.hex())
open(out, 'w').write(lua)
print('sidecar written:', out, '(%d bytes)' % len(lua))
if fails:
    sys.exit('%d check(s) failed' % fails)
