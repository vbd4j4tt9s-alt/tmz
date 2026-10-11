"""R156 preview: decode the game's own clover picture (src/ReplicatedStorage/CloverPassImage153.lua: palette + indices + alpha, raw deflate, base64; the same
stream EmbeddedImage153 decodes in game) to a PNG, and print its main greens so the bar colours can be picked to pair with it.
Usage: python3 -I decode_clover156.py <CloverPassImage153.lua> <out.png>     (needs Pillow + numpy)"""
import base64
import re
import sys
import zlib

import numpy as np
from PIL import Image

text = open(sys.argv[1], encoding='utf-8').read()
w, h, colors, nbytes, adler = (int(re.search(k + r'=(\d+)', text).group(1)) for k in ('Width', 'Height', 'Colors', 'Bytes', 'Check'))
raw = zlib.decompress(base64.b64decode(''.join(re.findall(r"^'([A-Za-z0-9+/=]+)',$", text, re.M))), -15)
assert len(raw) == nbytes == colors * 3 + 2 * w * h and zlib.adler32(raw) == adler, 'the stream does not match its header'
pal = np.frombuffer(raw[:colors * 3], dtype=np.uint8).reshape(-1, 3)
idx = np.frombuffer(raw[colors * 3:colors * 3 + w * h], dtype=np.uint8).reshape(h, w)
alpha = np.frombuffer(raw[colors * 3 + w * h:], dtype=np.uint8).reshape(h, w)
rgba = np.concatenate([pal[idx], alpha[..., None]], axis=2)
Image.fromarray(rgba, 'RGBA').save(sys.argv[2])
solid = alpha > 200
px = pal[idx][solid].astype(float)
print('clover %dx%d, %d solid pixels' % (w, h, int(solid.sum())))
lum = px @ np.array([.2126, .7152, .0722])
for q in (5, 25, 50, 75, 95):
    t = np.percentile(lum, q)
    c = px[np.argmin(abs(lum - t))]
    print('  luminance p%02d: rgb(%d, %d, %d)' % (q, *c))
print('  mean rgb(%d, %d, %d)' % tuple(px.mean(axis=0)))
