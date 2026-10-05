"""R151 treadmill polish: composes the renders of render_treadmills.mjs (Pillow).
Usage: python3 make_treadmill_sheet.py <renders dir> <scenes dir> <out dir>
Writes <out>/treadmills.png (low / mid / top, today (19d05d4) vs as built (this checkout) from the same cameras, plus close-ups), <out>/treadmills_all.png (all
seven levels, today vs as built) and <out>/treadmills_belt.gif (the belt animation of four levels)."""
import os, re, sys
from PIL import Image, ImageDraw, ImageFont

R, scenes, out = sys.argv[1], sys.argv[2], sys.argv[3]
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
BG, INK, MUTED = (27, 29, 35), (238, 240, 245), (165, 170, 182)
TODAY, NEW = (150, 54, 54), (40, 128, 84)
BIOME = ['Forest', 'Jungle', 'Desert', 'Snow', 'Lava', 'Crystal', 'Storm']
GRADE = ['low', 'low', 'mid', 'mid', 'mid', 'top', 'top']


def f(size, bold=False):
    return ImageFont.truetype(BOLD if bold else FONT, size)


budgets = {}
for which in ('before', 'after'):
    for line in open(os.path.join(scenes, which + '.txt'), encoding='utf-8'):
        if line.startswith('BUDGET '):
            m = re.match(r'BUDGET (\w+) L(\d) (.*)', line.strip())
            kv = dict(x.split('=', 1) for x in re.findall(r'(\w+=\S+)', m.group(3)))
            budgets[(which, int(m.group(2)))] = kv


def panel(name, w, h, tag=None, color=None, note=None):
    im = Image.open(os.path.join(R, name)).convert('RGB').resize((w, h), Image.LANCZOS)
    d = ImageDraw.Draw(im)
    if tag:
        ft = f(max(13, h // 20), True)
        tw = d.textlength(tag, font=ft)
        d.rectangle([8, 8, 8 + tw + 16, 8 + ft.size + 10], fill=color)
        d.text((16, 12), tag, font=ft, fill=(255, 255, 255))
    if note:
        ft = f(max(12, h // 24))
        tw = d.textlength(note, font=ft)
        d.rectangle([8, h - ft.size - 18, 8 + tw + 14, h - 8], fill=(20, 22, 28))
        d.text((15, h - ft.size - 15), note, font=ft, fill=INK)
    return im


def header(width, title, lines):
    ft, fs = f(34, True), f(19)
    h = 26 + 46 + len(lines) * 27 + 14
    im = Image.new('RGB', (width, h), BG)
    d = ImageDraw.Draw(im)
    d.text((22, 20), title, font=ft, fill=INK)
    for i, line in enumerate(lines):
        d.text((22, 72 + i * 27), line, font=fs, fill=MUTED)
    return im


def band(width, text, sub=None):
    im = Image.new('RGB', (width, 50 if not sub else 74), BG)
    d = ImageDraw.Draw(im)
    d.text((22, 12), text, font=f(24, True), fill=INK)
    if sub:
        d.text((22, 44), sub, font=f(17), fill=MUTED)
    return im


def stack(parts, width):
    h = sum(p.height for p in parts)
    im = Image.new('RGB', (width, h), BG)
    y = 0
    for p in parts:
        im.paste(p, (0, y))
        y += p.height
    return im


def row(panels, width, gap=6):
    h = max(p.height for p in panels)
    im = Image.new('RGB', (width, h + gap), BG)
    x = 0
    for p in panels:
        im.paste(p, (x, 0))
        x += p.width + gap
    return im


def cost(L):
    b, a = budgets[('before', L)], budgets[('after', L)]
    return ('parts %s -> %s (+%s new, -%s retired belt pieces), real lights %s -> %s, beams %s -> %s, belt textures %s'
            % (b['parts'], a['parts'], a['new'], a['retired'], b['lights'], a['lights'], b['beams'], a['beams'], a['textures']))


W = 1920
pw, ph = 474, 267
# ---------------------------------------------------------------------------------------------------------------- main sheet
parts = [header(W, 'Treadmills R151 as built: the same machines, with the reference details added', [
    'Before R151 (left of each pair) and as built from the real game code (right), from the SAME camera, on Base 1 of your place. Numbers: round per-step gains.',
    'Kept: every frame, rail, front, console, chevron, the belt collider, the prompt and the badge (same parts, same places). Added: a moving textured belt, neon trims,',
    'studs, small corner lamps, a "+N/step" label and an upgrade sign. Approximate render (three.js): no Roblox lighting, bloom or Fredoka font; particles are dots.'])]
for L, text in ((1, 'LOW'), (5, 'MID'), (7, 'TOP')):
    parts.append(band(W, 'Level %d  %s  (%s grade)  %s' % (L, BIOME[L - 1], GRADE[L - 1], budgets[('after', L)]['label']), cost(L)))
    parts.append(row([panel('before_L%d_hero.png' % L, pw, ph, 'BEFORE', TODAY), panel('after_L%d_hero.png' % L, pw, ph, 'R151', NEW),
                      panel('before_L%d_side.png' % L, pw, ph, 'BEFORE  side', TODAY), panel('after_L%d_side.png' % L, pw, ph, 'R151  side', NEW)], W))
cw, ch = 634, 357
parts.append(band(W, 'Close-ups (as built)', 'The belt moves with the chevrons (see treadmills_belt.gif); trims, studs and lamps are static parts; lights and particles only near the camera.'))
parts.append(row([panel('after_L5_belt.png', cw, ch, 'BELT  Lava L5', NEW, 'cooling-lava plates + molten veins over the glowing belt; fire flow on the edges'),
                  panel('after_L4_belt.png', cw, ch, 'BELT  Snow L4', NEW, 'ice slats + cyan circuit lines; frost flow on the edges'),
                  panel('after_L7_belt.png', cw, ch, 'BELT  Storm L7', NEW, 'blue slats + yellow circuit + falling digits (3 layers at the top grade)')], W))
parts.append(row([panel('after_L1_corner.png', cw, ch, 'ACCENTS  Forest L1', NEW, 'trail lantern on a studded plinth, rim glow line, bumper studs'),
                  panel('after_L3_corner.png', cw, ch, 'ACCENTS  Desert L3', NEW, 'sun brazier, studded plinth, rim + bumper glow lines'),
                  panel('after_L5_corner.png', cw, ch, 'ACCENTS  Lava L5', NEW, 'its pylons keep their place, on new studded plinths')], W))
parts.append(row([panel('after_L6_label.png', cw, ch, 'LABEL  Crystal L6', NEW, '"+N/step" just above the existing front (no new structure)'),
                  panel('after_L3_sign.png', cw, ch, 'UPGRADE SIGN  L3', NEW, 'beside the unchanged floor button, in the next level\'s colours'),
                  panel('after_L7_runner.png', cw, ch, 'WHILE YOU RUN  Storm L7', NEW, 'your own label hides while you train (popups take over)')], W))
parts.append(row([panel('before_L1_corner_dusk.png', cw, ch, 'BEFORE  Forest L1, in the dark', TODAY),
                  panel('after_L1_corner_dusk.png', cw, ch, 'R151  Forest L1, in the dark', NEW, 'one new real light (entry glow); mid / top add a deck underglow'),
                  panel('after_L5_hero_dusk.png', cw, ch, 'R151  Lava L5, dark', NEW)], W))
sheet = stack(parts, W)
sheet.save(os.path.join(out, 'treadmills.png'), optimize=True)
print('wrote treadmills.png', sheet.size)
# ---------------------------------------------------------------------------------------------------------------- all seven levels
parts = [header(W, 'All seven treadmill levels: before vs R151 as built (same cameras)', [
    'Each level is its own biome (Level 1 Forest ... Level 7 Storm). Low = levels 1-2, mid = 3-5, top = 6-7: higher levels get more belt layers, edge light flows,',
    'bumper glow lines, a deck underglow and (top) pulsing trims. Approximate render; see treadmills.md for the parts and lights of each level.'])]
for L in range(1, 8):
    parts.append(band(W, 'Level %d  %s  (%s)  %s' % (L, BIOME[L - 1], GRADE[L - 1], budgets[('after', L)]['label']), cost(L)))
    parts.append(row([panel('before_L%d_hero.png' % L, pw, ph, 'BEFORE', TODAY), panel('after_L%d_hero.png' % L, pw, ph, 'R151', NEW),
                      panel('before_L%d_front.png' % L, pw, ph, 'BEFORE  front', TODAY), panel('after_L%d_front.png' % L, pw, ph, 'R151  front', NEW)], W))
sheet = stack(parts, W)
sheet.save(os.path.join(out, 'treadmills_all.png'), optimize=True)
print('wrote treadmills_all.png', sheet.size)
# ---------------------------------------------------------------------------------------------------------------- belt GIF
levels = [L for L in (1, 4, 5, 7) if os.path.exists(os.path.join(R, 'gif_L%d_00.png' % L))]
if levels:
    frames = []
    gw, gh = 480, 270
    for i in range(20):
        im = Image.new('RGB', (gw * 2 + 4, gh * 2 + 4), BG)
        for k, L in enumerate(levels[:4]):
            p = panel('gif_L%d_%02d.png' % (L, i), gw, gh, 'L%d %s' % (L, BIOME[L - 1]), NEW)
            im.paste(p, ((k % 2) * (gw + 4), (k // 2) * (gh + 4)))
        frames.append(im.convert('P', palette=Image.ADAPTIVE, colors=192))
    frames[0].save(os.path.join(out, 'treadmills_belt.gif'), save_all=True, append_images=frames[1:], duration=83, loop=0, optimize=True)
    print('wrote treadmills_belt.gif', len(frames), 'frames')
