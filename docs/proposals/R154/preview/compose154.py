"""R154 preview: composes the rendered layers of every frame (R152's compose152.py: the world / stage render with its colour grade and blur,
the GUI under and over) and makes the R154 files.
Usage:
  compose154.py video   <render dir> <out base> <frames dir>               -> <out base>.mp4 and .gif: the scene through the proposed camera,
                                                                              a caption strip (the shot, the move, the clock) and a beat ruler
  compose154.py compare <today render dir> <out base> <frames dir> <proposed render dir>  -> <out base>.mp4: today | proposed, same clock
  compose154.py board   <render dir> <out.png>                              -> the storyboard sheet
The beat ruler: the scene's timeline (0 .. Length) with a tick for every sound cue that is a hit (impacts, clicks, bells, twinkles, slams;
not the beds, risers and whooshes), the hit itself in the tier colour, the camera's shots as alternating bands and the playhead. Picture
and ruler come from the same clock, so a cut / snap that lands on a tick is in sync with that sound."""
import json
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

MODE = sys.argv[1]
TIER = {6: ('SECRET', (176, 112, 255)), 7: ('COSMIC', (120, 160, 255)), 8: ('KING', (255, 205, 84))}
HITS = {'Impact', 'GroundImpact', 'PackBurst', 'TitleSlam', 'PackShake', 'SecretGlitch', 'SecretVault', 'CosmicBoom', 'CosmicStar', 'KingBell',
        'KingFanfare', 'Sparkle', 'SuckIn'}
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


def strip(w, h, m, beat, segs, show_caption=True):
    """the caption and the beat ruler under the picture"""
    rank = beat and beat.get('rank')
    name, color = TIER.get(rank, ('', (255, 255, 255)))
    tl = beat['tl'] if beat else {'Length': 1}
    length = tl.get('Length', 1)
    im = Image.new('RGB', (w, h), BG)
    d = ImageDraw.Draw(im)
    if show_caption:
        d.text((8, 4), m['shot'], font=font(12), fill=color)
        sw = d.textlength(m['shot'], font=font(12))
        clock = '%.2f s' % m['t']
        room = w - 8 - d.textlength(clock, font=font(12)) - 12 - (8 + sw + 8)
        move = m['move']
        while move and d.textlength(move, font=font(11, False)) > room:
            move = move[:-2].rstrip() + '…' if len(move) > 2 else ''
            move = move.replace('……', '…')
        d.text((8 + sw + 8, 5), move, font=font(11, False), fill=INK)
        d.text((w - 8, 4), clock, font=font(12), fill=SUB, anchor='ra')
    x0, x1, y = 8, w - 8, h - 12
    X = lambda t: x0 + (x1 - x0) * max(0.0, min(1.0, t / length))
    for i, (a, b, _) in enumerate(segs):
        d.rectangle([X(a), y - 4, X(b), y + 4], fill=(40, 36, 56) if i % 2 == 0 else (58, 52, 80))
    for t, slot in (beat['cues'] if beat else []):
        if slot in HITS:
            d.line([X(t), y - 6, X(t), y + 6], fill=(205, 200, 225), width=1)
    if 'Climax' in tl:
        c = X(tl['Climax'])
        d.polygon([(c - 4, y - 9), (c + 4, y - 9), (c, y - 3)], fill=color)
        d.line([c, y - 6, c, y + 6], fill=color, width=2)
    p = X(m['t'])
    d.line([p, y - 8, p, y + 8], fill=(255, 255, 255), width=2)
    return im


def encode_mp4(frames_dir, out, fps):
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(fps), '-i', os.path.join(frames_dir, 'f%04d.png'), '-c:v', 'libx264',
                    '-pix_fmt', 'yuv420p', '-preset', 'slow', '-crf', '18', '-movflags', '+faststart', out], check=True)


def encode_gif(frames_dir, out, fps, width):
    pal = os.path.join(frames_dir, 'palette.png')
    vf = 'fps=%d,scale=%d:-1:flags=lanczos' % (fps, width)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', '25', '-i', os.path.join(frames_dir, 'f%04d.png'), '-vf', vf + ',palettegen=max_colors=128:stats_mode=full', pal], check=True)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', '25', '-i', os.path.join(frames_dir, 'f%04d.png'), '-i', pal, '-lavfi',
                    vf + '[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle', '-loop', '0', out], check=True)


def fresh(d):
    if os.path.isdir(d):
        shutil.rmtree(d)
    os.makedirs(d)


if MODE == 'check':  # (checking) every frame of a render dir in a grid: compose154.py check <render dir> <out.png> [columns]
    D, OUT = sys.argv[2], sys.argv[3]
    cols = int(sys.argv[4]) if len(sys.argv) > 4 else 3
    meta = json.load(open(os.path.join(D, 'meta.json')))
    ims = [frame(D, m) for m in meta]
    W0, H0 = ims[0].width, ims[0].height
    sheet = Image.new('RGB', (cols * (W0 + 6), ((len(ims) + cols - 1) // cols) * (H0 + 20)), BG)
    d = ImageDraw.Draw(sheet)
    for k, (m, im) in enumerate(zip(meta, ims)):
        x, y = (k % cols) * (W0 + 6), (k // cols) * (H0 + 20)
        d.text((x + 2, y + 3), '%.2f %s  %s' % (m['t'], m['shot'], m['label']), font=font(12), fill=INK)
        sheet.paste(im.resize((W0, H0)), (x, y + 18))
    sheet.save(OUT)
    sys.exit(0)

if MODE == 'video':
    D, OUT, FR = sys.argv[2], sys.argv[3], sys.argv[4]
    meta, beat = load(D)
    segs = shots(meta)
    fresh(FR)
    for i, m in enumerate(meta):
        pic = frame(D, m)
        out = Image.new('RGB', (pic.width, pic.height + 40), BG)
        out.paste(pic, (0, 0))
        out.paste(strip(pic.width, 40, m, beat, segs), (0, pic.height))
        out.save(os.path.join(FR, 'f%04d.png' % i))
    encode_mp4(FR, OUT + '.mp4', 25)
    encode_gif(FR, OUT + '.gif', 20, 640)
    for ext in ('.mp4', '.gif'):
        print(OUT + ext, '%.2f MB' % (os.path.getsize(OUT + ext) / 1e6))
    sys.exit(0)

if MODE == 'compare':
    D, OUT, FR, P = sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
    meta, beat = load(D)
    pmeta, _ = load(P)
    segs = shots(pmeta)
    fresh(FR)
    for i, (m, pm) in enumerate(zip(meta, pmeta)):
        a, b = frame(D, m), frame(P, pm)
        out = Image.new('RGB', (a.width * 2 + 8, a.height + 64), BG)
        dr = ImageDraw.Draw(out)
        dr.text((8, 6), 'TODAY (R151 / R152 camera)', font=font(14), fill=SUB)
        dr.text((a.width + 16, 6), 'PROPOSED (R154 cinematic camera)', font=font(14), fill=TIER[8][1])
        out.paste(a, (0, 24))
        out.paste(b, (a.width + 8, 24))
        out.paste(strip(a.width * 2 + 8, 40, pm, beat, segs), (0, a.height + 24))
        out.save(os.path.join(FR, 'f%04d.png' % i))
    encode_mp4(FR, OUT + '.mp4', 25)
    print(OUT + '.mp4', '%.2f MB' % (os.path.getsize(OUT + '.mp4') / 1e6))
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
        'Secret': 'mysterious and dark: creeping low moves, a rack focus out of the dark, glitch jump-cuts with a dutch tilt, a ratchet push on every lock click, dead stop on the silence, snap back on the hit',
        'Cosmic': 'vast: a cosmic zoom-out from the pack to deep space, settling on the line of planets, a vortex push-in, a crash into the core, the supernova blows the camera back',
        'King': 'regal and epic: a grand crane down the hall, a low tracking shot past the pillars, an orbit and crane that meets the descending crown, a low push-in, a crane up with the crowned seed',
        'Phones and tablets': 'the field of view is vertical: the seed and the crown take the same share of the height on 16:9, a 19.5:9 phone and a 4:3 tablet; subjects stay inside the 4:3 centre',
        'Reduced Motion (King)': 'still shots, cut on the Calm beats: no moves, tilts, zooms, focus pulls or shake; the world camera untouched',
        'Onlookers': 'other players keep their own camera: nothing of theirs is moved; they see the sky beam land on the puller (R152)',
    }
    imgs = {}
    for _, items in rows:
        for m in items:
            im = frame(D, m)
            imgs[m['name']] = im.resize((int(im.width * FH / im.height), FH), Image.LANCZOS)
    # the three tiers in full rows (5 per line), the variants together at the bottom
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
    d.text((PAD, 12), 'R154 proposal: cinematic camera for the Secret, Cosmic and King reveals (keyframes)', font=font(22), fill=INK)
    d.text((PAD, 42), "Today's scenes, beats, sounds and clock; only the camera is new. Drawn from the real client scripts on the Roblox mock with three.js;",
           font=font(13, False), fill=SUB)
    d.text((PAD, 60), 'approximate: plain materials, stand-in pack art, avatar and garden, no Future lighting. Depth of field drawn with a bokeh pass.',
           font=font(13, False), fill=SUB)
    y = 92
    colors = {'Secret': TIER[6][1], 'Cosmic': TIER[7][1], 'King': TIER[8][1]}
    for kind, v in lines:
        if kind == 'head':
            d.text((PAD, y), v.upper(), font=font(18), fill=colors.get(v, (230, 226, 246)))
            note = NOTES.get(v)
            if v == 'Variants':
                note = 'phones and tablets (King) · Reduced Motion = CALM (King) · onlookers, seen from their own camera'
            if note:
                d.text((PAD + d.textlength(v.upper(), font=font(18)) + 14, y + 4), note, font=font(12, False), fill=SUB)
            y += SUBL + 10
            continue
        x = PAD
        for m in v:
            im = imgs[m['name']]
            short = {'Reduced Motion (King)': 'CALM', 'Onlookers': 'ONLOOKER', 'Phones and tablets': ''}
            label = m['label'] if m['tag'] in ('Secret', 'Cosmic', 'King') or not short.get(m['tag']) else '%s: %s' % (short[m['tag']], m['label'])
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
