"""R152 preview: lays out docs/proposals/R152/sale_money.png (a time strip per layout: desktop, phone landscape, phone portrait) and the two GIFs from the renders of
render_sale_money.mjs.   Usage: python3 make_sale_money.py <render dir> <out dir>"""
import glob
import os
import sys
from PIL import Image, ImageDraw

src, out = sys.argv[1], sys.argv[2]
BG = (16, 21, 28)


def strips():
    rows = []
    for name, title in (('desktop', 'Desktop 1280 x 720'), ('phone_landscape', 'Phone landscape 844 x 390 (balances in the thumbstick corner)'), ('phone_portrait', 'Phone portrait 390 x 844')):
        im = Image.open(os.path.join(src, name + '_strip.png')).convert('RGB')
        rows.append((title, im))
    width = max(im.width for _, im in rows)
    pad, head = 10, 22
    height = sum(im.height + head + pad for _, im in rows) + pad
    sheet = Image.new('RGB', (width + 2 * pad, height), BG)
    d = ImageDraw.Draw(sheet)
    y = pad
    for title, im in rows:
        d.text((pad, y + 3), title, fill=(233, 238, 245))
        y += head
        sheet.paste(im, (pad, y))
        y += im.height + pad
    # keep it modest: the sheet is wide, so cap the width
    if sheet.width > 2400:
        sheet = sheet.resize((2400, round(sheet.height * 2400 / sheet.width)), Image.LANCZOS)
    sheet.save(os.path.join(out, 'sale_money.png'), optimize=True)
    print('sale_money.png', sheet.size)


def gif(name, dest, step=1):
    files = sorted(glob.glob(os.path.join(src, name + '_[0-9][0-9][0-9].png')))[::step]
    frames = [Image.open(f).convert('P', palette=Image.ADAPTIVE, colors=96) for f in files]
    frames[0].save(os.path.join(out, dest), save_all=True, append_images=frames[1:], duration=int(1000 / 30 * step), loop=0, optimize=True, disposal=1)
    print(dest, len(frames), 'frames', os.path.getsize(os.path.join(out, dest)) // 1024, 'KB')


strips()
gif('desktop', 'sale_money_desktop.gif')
gif('phone_landscape', 'sale_money_phone.gif')
