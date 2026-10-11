"""R151 speed popups preview: joins outdir/gif/g000.png.. (render_preview.mjs) into one small looping GIF with one shared palette.
Usage: python3 make_gif.py OUTDIR OUT.gif [colours]"""
import glob
import os
import sys

from PIL import Image

out_dir, target = sys.argv[1], sys.argv[2]
colours = int(sys.argv[3]) if len(sys.argv) > 3 else 96
files = sorted(glob.glob(os.path.join(out_dir, 'gif', 'g*.png')))
frames = [Image.open(f).convert('RGB') for f in files]
# one palette for every frame (no colour flicker): built from a mosaic of frames spread over the run
picks = frames[:: max(1, len(frames) // 6)]
w, h = frames[0].size
mosaic = Image.new('RGB', (w, h * len(picks)))
for i, im in enumerate(picks):
    mosaic.paste(im, (0, i * h))
palette = mosaic.quantize(colors=colours, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
frames_p = [im.quantize(palette=palette, dither=Image.Dither.NONE) for im in frames]
durations = [33] * len(frames_p)
durations[-1] = 700                                   # rest on the last frame before it loops
frames_p[0].save(target, save_all=True, append_images=frames_p[1:], duration=durations, loop=0, optimize=True, disposal=1)
print('%s: %d frames, %dx%d, %d KB' % (target, len(frames_p), w, h, os.path.getsize(target) // 1024))
