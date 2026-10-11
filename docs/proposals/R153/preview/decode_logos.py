"""R153 biome notifier preview: decode the REAL biome logos.
BiomeIconData.lua keeps each logo as 96x96 RGBA, zstd-compressed and base64 encoded (the game's ArtworkRuntime87 decodes it the same way).
Usage: python3 -I decode_logos.py <BiomeIconData.lua> <out dir>   ->  <out dir>/logo_<Kind>.png (Forest, Desert, Snow, Lava, Crystal, Jungle, Storm, ...)
Needs the `zstandard` and `Pillow` Python packages."""
import base64
import re
import sys

import zstandard
from PIL import Image

src = open(sys.argv[1]).read()
out = sys.argv[2]
count = 0
for m in re.finditer(r'(\w+)=\{([^{}]*?)RGBA="([A-Za-z0-9+/=]+)"', src):
    kind, header, blob = m.groups()
    raw = zstandard.ZstdDecompressor().decompress(base64.b64decode(blob), max_output_size=1 << 24)
    side = re.search(r'Size=(\d+)', header)
    w = h = int(side.group(1)) if side else 0
    if w and len(raw) == w * h * 4:
        Image.frombytes('RGBA', (w, h), raw).save(f'{out}/logo_{kind}.png')
        count += 1
print('decoded', count, 'logos')
