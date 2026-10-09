"""R155 preview: composes the rendered layers of every frame (R154's compose154.py: the world / stage render with its colour grade and blur, the GUI
under and over, plus R152's flying-seed viewport) and makes the R155 files.
Usage:
  compose155.py video <render dir> <out.mp4> <frames dir> [width]   -> the clip as the game plays it (the scene, the wait on the hero shot, the
                                                                       click, the world, the flight), a caption strip (the shot, the move, the
                                                                       clock) and a beat ruler; width = the picture's width (960)
  compose155.py board <render dir> <out.png>                        -> the contact sheet
  compose155.py check <render dir> <out.png> [columns]              -> (checking) every frame of a render dir in a grid
The beat ruler: the clip's clock (0 .. its end) with a tick for every sound cue that is a hit (impacts, clicks, bells, twinkles, slams; a
whoosh at its swell), the hit in the tier colour, the cuts of the cinematic camera (white notches above the ruler), the camera's shots as
alternating bands, the wait on the hero shot (striped) up to the click, and the playhead. Picture and ruler come from the same clock, so a
cut or a snap that sits on a tick is in sync with that sound."""
import json
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

MODE = sys.argv[1]
TIER = {6: ('SECRET', (176, 112, 255)), 7: ('COSMIC', (120, 160, 255)), 8: ('KING', (255, 205, 84))}
HITS = {'Impact', 'GroundImpact', 'PackBurst', 'TitleSlam', 'PackShake', 'SecretGlitch', 'SecretVault', 'CosmicBoom', 'CosmicStar', 'KingBell',
        'KingFanfare', 'Sparkle', 'SuckIn', 'Flight'}
BG, INK, SUB = (14, 12, 20), (238, 234, 250), (150, 146, 172)


def font(px, bold=True):
    try:
        return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf' if bold else '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', px)
    except Exception:
        return ImageFont.load_default()


def grade(img, g, blur, scale):
    """Roblox ColorCorrectionEffect, approximately (compose152.py): brightness adds, contrast / saturation scale, tint multiplies."""
    img = img.convert('RGB')
    if g:
        if g['s']:
            img = ImageEnhance.Color(img).enhance(max(0.0, 1 + g['s']))
        if g['c']:
            img = ImageEnhance.Contrast(img).enhance(max(0.0, 1 + g['c']))
        if g['b']:
            add = int(g['b'] * 255)
            img = img.point(lambda v: max(0, min(255, v + add)))
        t = g['tint']
        if t != [255, 255, 255]:
            r, gg, b = img.split()
            img = Image.merge('RGB', (r.point(lambda v: v * t[0] // 255), gg.point(lambda v: v * t[1] // 255), b.point(lambda v: v * t[2] // 255)))
    if blur and blur > .3:
        img = img.filter(ImageFilter.GaussianBlur(blur * .45 * scale))
    return img


def overlay(img, path):
    if os.path.exists(path):
        ov = Image.open(path).convert('RGBA')
        if ov.size != img.size:
            ov = ov.resize(img.size, Image.LANCZOS)
        img.alpha_composite(ov)


def frame(d, m):
    img = grade(Image.open(os.path.join(d, m['name'] + '_world.png')), m['grade'], m['blur'], m['h'] / 720).convert('RGBA')
    for i in range(m.get('under', 0)):
        overlay(img, os.path.join(d, '%s_under%d.png' % (m['name'], i)))
    vp = m.get('vp')
    if vp and os.path.exists(os.path.join(d, m['name'] + '_vp.png')):  # the collected seed flying home (R152's viewport layer)
        x, y, w, h = vp['rect']
        s = max(1, int(w * vp['scale']))
        card = Image.open(os.path.join(d, m['name'] + '_vp.png')).convert('RGBA').resize((s, s), Image.LANCZOS)
        if vp['alpha'] < 1:
            card.putalpha(card.split()[3].point(lambda v: int(v * vp['alpha'])))
        img.alpha_composite(card, (int(x + w / 2 - s / 2), int(y + h / 2 - s / 2)))
    for i in range(m['guis']):
        overlay(img, os.path.join(d, '%s_gui%d.png' % (m['name'], i)))
    return img.convert('RGB')


def load(d):
    meta = json.load(open(os.path.join(d, 'meta.json')))
    beats = json.load(open(os.path.join(d, 'beats.json')))
    return meta, (beats[0] if beats else None)


def shots(meta):
    """the camera's shots as [start, end, name] from the per-frame shot names"""
    out = []
    for m in meta:
        if not out or out[-1][2] != m['shot']:
            out.append([m['t'], m['t'], m['shot']])
        out[-1][1] = m['t']
    for i in range(len(out) - 1):
        out[i][1] = out[i + 1][0]
    return out


def strip(w, h, m, beat, segs, length):
    """the caption and the beat ruler under the picture"""
    rank = beat and beat.get('rank')
    _, color = TIER.get(rank, ('', (255, 255, 255)))
    tl = beat['tl'] if beat else {}
    im = Image.new('RGB', (w, h), BG)
    d = ImageDraw.Draw(im)
    f1, f2 = font(13), font(12, False)
    d.text((8, 5), m['shot'], font=f1, fill=color)
    sw = d.textlength(m['shot'], font=f1)
    clock = '%.2f s' % m['t']
    room = w - 8 - d.textlength(clock, font=f1) - 12 - (8 + sw + 8)
    move = m['move']
    while move and d.textlength(move, font=f2) > room:
        move = move[:-2].rstrip() + '…' if len(move) > 2 else ''
        move = move.replace('……', '…')
    d.text((8 + sw + 8, 6), move, font=f2, fill=INK)
    d.text((w - 8, 5), clock, font=f1, fill=SUB, anchor='ra')
    x0, x1, y = 8, w - 8, h - 13
    X = lambda t: x0 + (x1 - x0) * max(0.0, min(1.0, t / length))
    for i, (a, b, _) in enumerate(segs):
        d.rectangle([X(a), y - 4, X(b), y + 4], fill=(40, 36, 56) if i % 2 == 0 else (58, 52, 80))
    if 'Press' in tl and 'Settle' in tl:  # the wait on the hero shot, up to the click
        a, b = X(tl['Settle']), X(tl['Press'])
        for k in range(int(a), int(b), 4):
            d.line([k, y + 4, min(b, k + 4), y - 4], fill=(96, 90, 120))
        d.text(((a + b) / 2, y - 18), 'waits', font=font(10, False), fill=SUB, anchor='ma')
        p = X(tl['Press'])
        d.line([p, y - 7, p, y + 7], fill=(120, 230, 160), width=2)
        d.text((p + 3, y - 18), 'click', font=font(10, False), fill=(120, 230, 160))
    for t, slot in (beat['cues'] if beat else []):
        if slot in HITS:
            d.line([X(t), y - 6, X(t), y + 6], fill=(205, 200, 225), width=1)
    for c in (beat.get('cuts', []) if beat else []):
        cx = X(c)
        d.polygon([(cx - 3, y - 12), (cx + 3, y - 12), (cx, y - 7)], fill=(255, 255, 255))
    if 'Climax' in tl:
        c = X(tl['Climax'])
        d.polygon([(c - 4, y - 10), (c + 4, y - 10), (c, y - 4)], fill=color)
        d.line([c, y - 6, c, y + 6], fill=color, width=2)
    p = X(m['t'])
    d.line([p, y - 8, p, y + 8], fill=(255, 255, 255), width=2)
    return im


def encode_mp4(frames_dir, out, fps):
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(fps), '-i', os.path.join(frames_dir, 'f%04d.png'), '-c:v', 'libx264',
                    '-pix_fmt', 'yuv420p', '-preset', 'slow', '-crf', '20', '-movflags', '+faststart', out], check=True)


def fresh(d):
    if os.path.isdir(d):
        shutil.rmtree(d)
    os.makedirs(d)


if MODE == 'check':
    D, OUT = sys.argv[2], sys.argv[3]
    cols = int(sys.argv[4]) if len(sys.argv) > 4 else 3
    meta = json.load(open(os.path.join(D, 'meta.json')))
    W0 = 480
    ims = [frame(D, m) for m in meta]
    ims = [im.resize((W0, int(im.height * W0 / im.width)), Image.LANCZOS) for im in ims]
    H0 = max(im.height for im in ims)
    sheet = Image.new('RGB', (cols * (W0 + 6), ((len(ims) + cols - 1) // cols) * (H0 + 20)), BG)
    d = ImageDraw.Draw(sheet)
    for k, (m, im) in enumerate(zip(meta, ims)):
        x, y = (k % cols) * (W0 + 6), (k // cols) * (H0 + 20)
        d.text((x + 2, y + 3), '%.2f %s  %s' % (m['t'], m['shot'], m['label']), font=font(12), fill=INK)
        sheet.paste(im, (x, y + 18))
    sheet.save(OUT)
    sys.exit(0)

if MODE == 'video':
    D, OUT, FR = sys.argv[2], sys.argv[3], sys.argv[4]
    PW = int(sys.argv[5]) if len(sys.argv) > 5 else 960
    meta, beat = load(D)
    segs = shots(meta)
    length = max(m['t'] for m in meta) + 1 / 25
    fresh(FR)
    for i, m in enumerate(meta):
        pic = frame(D, m)
        pic = pic.resize((PW, int(pic.height * PW / pic.width)), Image.LANCZOS)
        out = Image.new('RGB', (pic.width, pic.height + 44), BG)
        out.paste(pic, (0, 0))
        out.paste(strip(pic.width, 44, m, beat, segs, length), (0, pic.height))
        out.save(os.path.join(FR, 'f%04d.png' % i))
    encode_mp4(FR, OUT, 25)
    print(OUT, '%.2f MB' % (os.path.getsize(OUT) / 1e6), '%d frames' % len(meta))
    sys.exit(0)

if MODE == 'board':
    D, OUT = sys.argv[2], sys.argv[3]
    meta = json.load(open(os.path.join(D, 'meta.json')))
    rows = []
    for m in meta:
        if not rows or rows[-1][0] != m['tag']:
            rows.append((m['tag'], []))
        rows[-1][1].append(m)
    FH, PAD, LABEL, SUBL = 150, 12, 18, 30
    NOTES = {
        'Secret': 'three cuts, each on its sound (the two glitches, the 1st lock click); creeping low moves, a rack focus, a ratchet on the clicks, dead stop, thrown back by the hit',
        'Cosmic': 'one continuous take: a zoom-out to deep space, a vortex push-in, a crash into the core, dead stop, the supernova blows it back; the seed at its size with the star',
        'King': 'three cuts on the carry whoosh, the crown\'s shimmer and the 2nd shake; a crane down the hall, a tracking shot past the pillars, the crown meets the pack, the crowned seed',
        'The SKIP button': 'R155: a click or tap anywhere no longer skips; the SKIP button at the bottom right (from SkipFrom to the hit), gamepad B / R2 or Enter do',
        'Phones and low quality': 'the same shots on the light stage; the depth of field (background blur) is on everywhere: the owner\'s choice',
        'Reduced Motion': 'still shots cut on the Calm beats: no moves, roll, lens changes or shake; a still depth of field; the seed\'s still hero shot',
        'Onlookers': 'other players keep their own camera: nothing of theirs is moved; they see the sky beam land on the puller (R152), as before',
    }
    imgs = {}
    for _, items in rows:
        for m in items:
            im = frame(D, m)
            imgs[m['name']] = im.resize((int(im.width * FH / im.height), FH), Image.LANCZOS)
    tiers = [r for r in rows if r[0] in ('Secret', 'Cosmic', 'King')]
    extra = [r for r in rows if r[0] not in ('Secret', 'Cosmic', 'King')]
    PER = 5
    width = PAD + PER * (int(FH * 16 / 9) + PAD)
    lines = []
    for tag, items in tiers:
        lines.append(('head', tag))
        for k in range(0, len(items), PER):
            lines.append(('row', items[k:k + PER]))
    lines.append(('head', 'Variants'))
    ex = []
    for tag, items in extra:
        ex += items
    row, w = [], PAD
    for m in ex:
        iw = imgs[m['name']].width + PAD
        if w + iw > width and row:
            lines.append(('row', row))
            row, w = [], PAD
        row.append(m)
        w += iw
    if row:
        lines.append(('row', row))
    height = 96 + sum((SUBL + 10) if k == 'head' else (FH + LABEL + PAD) for k, _ in lines) + 40
    sheet = Image.new('RGB', (width, height), BG)
    d = ImageDraw.Draw(sheet)
    d.text((PAD, 12), 'R155: the cinematic camera for the Secret, Cosmic and King reveals, as built (keyframes)', font=font(22), fill=INK)
    d.text((PAD, 42), 'The real scripts on the Roblox mock, the camera and its depth of field as the game sets them; drawn with three.js (approximate: plain',
           font=font(13, False), fill=SUB)
    d.text((PAD, 60), 'materials, stand-in pack art, avatar and garden, no Future lighting; the depth of field drawn with a bokeh pass). The world before and after the stage is today\'s.',
           font=font(13, False), fill=SUB)
    y = 92
    colors = {'Secret': TIER[6][1], 'Cosmic': TIER[7][1], 'King': TIER[8][1]}
    for kind, v in lines:
        if kind == 'head':
            d.text((PAD, y), v.upper(), font=font(18), fill=colors.get(v, (230, 226, 246)))
            note = NOTES.get(v)
            if v == 'Variants':
                note = 'the SKIP button (desktop; a phone, clear of the thumb controls; a gamepad: its B) · phones and low quality (the depth of field on every device) · Reduced Motion · onlookers'
            if note:
                d.text((PAD + d.textlength(v.upper(), font=font(18)) + 14, y + 4), note, font=font(12, False), fill=SUB)
            y += SUBL + 10
            continue
        x = PAD
        for m in v:
            im = imgs[m['name']]
            label = m['label']
            room = im.width
            if m['tag'] in ('Secret', 'Cosmic', 'King'):
                clock = '%.2f s' % m['t']
                d.text((x + im.width, y + 1), clock, font=font(11, False), fill=SUB, anchor='ra')
                room -= d.textlength(clock, font=font(11, False)) + 6
            while label and d.textlength(label, font=font(12)) > room:
                label = label[:-1]
            d.text((x, y), label, font=font(12), fill=(214, 210, 236))
            sheet.paste(im, (x, y + LABEL))
            x += im.width + PAD
        y += FH + LABEL + PAD
    sheet.crop((0, 0, width, y + 8)).save(OUT, optimize=True)
    print('board ->', OUT, '%.2f MB' % (os.path.getsize(OUT) / 1e6))
    sys.exit(0)
print(__doc__)
sys.exit(2)
