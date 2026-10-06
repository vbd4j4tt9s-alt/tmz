"""art_to_png.py IN.txt OUTDIR [sheet.png]: the IMAGE lines of dump_art.luau / preview_frames152.luau -> one PNG per image (and a contact sheet
on a dark checker, so the transparent parts show)."""
import sys, os
from PIL import Image, ImageDraw
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
imgs = []
for line in open(src):
    if not line.startswith('IMAGE '):
        continue
    _, name, w, h, hexs = line.split(' ', 4)
    w, h = int(w), int(h)
    im = Image.frombytes('RGBA', (w, h), bytes.fromhex(hexs.strip()))
    im.save(os.path.join(out, name + '.png'))
    imgs.append((name, im))
if len(sys.argv) > 3 and imgs:
    cell = 200
    cols = 5
    rows = (len(imgs) + cols - 1) // cols
    sheet = Image.new('RGB', (cols * cell, rows * (cell + 18)), (18, 18, 24))
    d = ImageDraw.Draw(sheet)
    for i, (name, im) in enumerate(imgs):
        x, y = (i % cols) * cell, (i // cols) * (cell + 18)
        bg = Image.new('RGB', (cell - 10, cell - 10), (28, 28, 40))
        bd = ImageDraw.Draw(bg)
        for yy in range(0, cell, 16):
            for xx in range(0, cell, 16):
                if (xx // 16 + yy // 16) % 2 == 0:
                    bd.rectangle([xx, yy, xx + 15, yy + 15], fill=(40, 40, 56))
        k = min((cell - 10) / im.width, (cell - 10) / im.height)
        sm = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)
        bg.paste(sm, ((cell - 10 - sm.width) // 2, (cell - 10 - sm.height) // 2), sm)
        sheet.paste(bg, (x + 5, y + 5))
        d.text((x + 6, y + cell - 4), name, fill=(220, 220, 230))
    sheet.save(sys.argv[3])
print(len(imgs), 'images')
