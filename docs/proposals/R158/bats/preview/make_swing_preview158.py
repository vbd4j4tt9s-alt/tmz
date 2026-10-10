"""R158 bats: the swing preview sheet (swing_preview.png) and animation (swing_preview.gif).
  python3 make_swing_preview158.py jobs <jobs.json>                                   render jobs for render_swing158.mjs
  python3 make_swing_preview158.py refs <video.mp4> <ref dir>                          reference crops (swing 1 of the owner's video) via ffmpeg
  python3 make_swing_preview158.py sheet <render out> <ref dir> <out.png>
  python3 make_swing_preview158.py gif <render out> <ref dir> <frames dir> <out.gif>
APPROXIMATE renders (blocky rig, the fallback bat, no Roblox lighting); the reference is the video itself.
"""
import json, os, subprocess, sys
from PIL import Image, ImageDraw, ImageFont

FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
def font(size, bold=False):
    try: return ImageFont.truetype(BOLD if bold else FONT, size)
    except OSError: return ImageFont.load_default()

PW, PH = 260, 300            # sheet panel
GW, GH = 280, 320            # gif panel
# The video is variable frame rate (frame n is at about n/30 - .02 s): reference frames are picked by INDEX and captioned with their real time.
PTS = {11: .347, 12: .386, 14: .447, 17: .546, 20: .646, 21: .679, 22: .712, 26: .846, 34: 1.112}
SWING_START = .39            # swing 1 starts here (frame 12 at .386 is the first one that moves); the timeline and the captions count from here
GIF_FIRST = 12               # the gif's reference frames are frames 12 .. 41 (frame 21, the contact, lands on t = .30 like the renders)
REF_START = PTS[GIF_FIRST]
REF_CROP = 'crop=420:480:1090:540'
# the eight columns: (phase, reference video time, today time + its own phase name, proposed time)
COLS = [  # (phase, reference frame index, (today time, today's own phase name), proposed time)
    ('rest',            11, (0.0,   'tool hold'),          0.0),
    ('load',            14, (0.135, 'wound back'),         0.07),
    ('coil (hold)',     17, (0.165, 'hold'),               0.15),
    ('strike',          20, (0.24,  'whip over the top'),  0.26),
    ('CONTACT',         21, (0.30,  'contact'),            0.30),
    ('through',         22, (0.36,  'chop down'),          0.335),
    ('follow-through',  26, (0.432, 'follow-through'),     0.52),
    ('recovery',        34, (0.60,  'settle'),             0.72),
]
WHITE, GREY, RED, BLUE = 0xffffff, 0x8a8a8a, 0xe02020, 0x2060ff

def jobs(path):
    j = []
    for i, (_, _, (tt, _), pt) in enumerate(COLS):
        j.append(dict(out=f'today_R15_{i}.png', sys='today', rig='R15', t=tt, view='front34', w=PW, h=PH))
        p = dict(out=f'proposed_R15_{i}.png', sys='proposed', rig='R15', t=pt, view='front34', w=PW, h=PH)
        if .21 < pt <= .40: p['ribbon'] = dict(sys='proposed', rig='R15', **{'from': max(.21, pt - .12), 'to': pt}, color=WHITE, opacity=.85)
        j.append(p)
        q = dict(out=f'proposed_R6_{i}.png', sys='proposed', rig='R6', t=pt, view='front34', w=PW, h=PH)
        if .21 < pt <= .40: q['ribbon'] = dict(sys='proposed', rig='R6', **{'from': max(.21, pt - .12), 'to': pt}, color=WHITE, opacity=.85)
        j.append(q)
    # top views: the bat tip path (grey = the whole swing) and the moment / window the server hits
    j.append(dict(out='top_today.png', sys='today', rig='R15', t=.30, view='top', w=330, h=330, box=True,
                  trails=[dict(sys='today', rig='R15', **{'from': 0, 'to': .74}, color=GREY, width=.14),
                          dict(sys='today', rig='R15', **{'from': .29, 'to': .31}, color=BLUE, width=.35)]))
    j.append(dict(out='top_proposed.png', sys='proposed', rig='R15', t=.30, view='top', w=330, h=330, sector=True,
                  trails=[dict(sys='proposed', rig='R15', **{'from': 0, 'to': .85}, color=GREY, width=.14),
                          dict(sys='proposed', rig='R15', **{'from': .24, 'to': .36}, color=RED, width=.3)]))
    j.append(dict(out='fx_proposed.png', sys='proposed', rig='R15', t=.30, view='front34', w=330, h=330,
                  ribbon=dict(sys='proposed', rig='R15', **{'from': .21, 'to': .30}, color=WHITE, opacity=.9),
                  burst=dict(sys='proposed', rig='R15', t=.30, size=1.7, color=0xffe08a)))
    j.append(dict(out='side_proposed.png', sys='proposed', rig='R15', t=.30, view='side', w=330, h=330,
                  trails=[dict(sys='proposed', rig='R15', **{'from': 0, 'to': .85}, color=GREY, width=.12),
                          dict(sys='proposed', rig='R15', **{'from': .24, 'to': .36}, color=RED, width=.25)]))
    # gif frames, 30 fps over 0 .. .967 s
    for k in range(30):
        t = k / 30
        j.append(dict(out=f'g_today_{k:02d}.png', sys='today', rig='R15', t=t, view='front34', w=GW, h=GH))
        g = dict(out=f'g_proposed_{k:02d}.png', sys='proposed', rig='R15', t=t, view='front34', w=GW, h=GH)
        if .21 < t <= .40: g['ribbon'] = dict(sys='proposed', rig='R15', **{'from': max(.21, t - .12), 'to': t}, color=WHITE, opacity=.85)
        j.append(g)
    json.dump(j, open(path, 'w'))

def refs(video, out):
    os.makedirs(out, exist_ok=True)
    # sheet crops at the column times, and 30 gif frames from REF_START
    for i, (_, n, _, _) in enumerate(COLS):
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', video, '-vf', f"select='eq(n,{n})',setpts=N/30/TB,{REF_CROP},scale={PW}:{PH}", '-vsync', '0', '-frames:v', '1',
                        os.path.join(out, f'ref_{i}.png')], check=True)
    first = GIF_FIRST
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', video, '-vf', f"select='between(n,{first},{first + 29})',setpts=N/30/TB,{REF_CROP},scale={GW}:{GH}",
                    '-vsync', '0', '-start_number', '0', os.path.join(out, 'g_ref_%02d.png')], check=True)

def label(d, xy, text, size=15, fill=(20, 20, 20), bold=False, anchor='la'):
    d.text(xy, text, font=font(size, bold), fill=fill, anchor=anchor)

# phase timeline (seconds from the start of the swing). Colours: categorical slots 1-5 of the dataviz reference palette, fixed order, validated;
# every segment is labelled (the relief rule: three slots sit under 3:1 on white).
PHASES = ['load', 'coil / hold', 'strike', 'follow-through', 'recovery']
PCOL = ['#2a78d6', '#eb6834', '#1baf7a', '#eda100', '#e87ba4']
TIMELINE = [
    ('Reference video (measured, swing 1)', [(0, .06), (.06, .26), (.26, .32), (.32, .59), (.59, .89)], .29, None),
    ('Today (BatSwingPose)',                [(0, .135), (.135, .165), (.165, .30), (.30, .432), (.432, .74)], .30, None),
    ('Proposed (BatSwingPose158)',          [(0, .07), (.07, .22), (.22, .335), (.335, .60), (.60, .85)], .30, (.24, .36)),
]
def timeline(w, h):
    img = Image.new('RGB', (w, h), (252, 252, 251)); d = ImageDraw.Draw(img)
    label(d, (16, 12), 'Swing timing (seconds after the click reaches the swing start)', 18, bold=True)
    x0, x1, scale_max = 300, w - 30, 0.95
    X = lambda t: x0 + (x1 - x0) * t / scale_max
    top = 58; row = 62
    for k in range(0, 10):
        t = k / 10; x = X(t)
        d.line([(x, top - 6), (x, top + row * 3 - 10)], fill=(225, 225, 222), width=1)
        label(d, (x, top + row * 3 - 4), f'{t:.1f}', 12, fill=(110, 110, 105), anchor='ma')
    for r, (name, segs, contact, window) in enumerate(TIMELINE):
        y = top + r * row
        label(d, (16, y + 12), name, 14, fill=(30, 30, 30))
        for i, (a, b) in enumerate(segs):
            xa, xb = X(a) + 1, X(b) - 1                       # 2 px surface gap between segments
            d.rounded_rectangle([xa, y + 4, xb, y + 34], radius=4, fill=PCOL[i])
            txt = f'{b - a:.2f}'
            if xb - xa > 34: label(d, ((xa + xb) / 2, y + 19), txt, 12, fill=(15, 15, 15), anchor='mm')
        if window:
            d.rectangle([X(window[0]), y + 1, X(window[1]), y + 37], outline=(15, 15, 15), width=2)
            label(d, (X(window[1]) + 6, y + 38), 'hit window .24-.36', 11, fill=(60, 60, 60), anchor='la')
        xc = X(contact); d.polygon([(xc - 6, y - 4), (xc + 6, y - 4), (xc, y + 5)], fill=(15, 15, 15))
        label(d, (xc + 8, y - 8), 'contact' + (' (bat in front)' if r == 0 else ' = server hit time' if r == 1 else ''), 11, fill=(40, 40, 40))
    # legend (always present for >= 2 series)
    lx = 300; ly = h - 26
    for i, p in enumerate(PHASES):
        d.rounded_rectangle([lx, ly, lx + 14, ly + 14], radius=3, fill=PCOL[i]); label(d, (lx + 20, ly), p, 13, fill=(40, 40, 40)); lx += 30 + int(d.textlength(p, font=font(13)))
    label(d, (16, h - 26), 'numbers = seconds', 12, fill=(110, 110, 105))
    return img

def sheet(rdir, refdir, out):
    LW = 150; W = LW + PW * len(COLS) + 10
    rows = [('REFERENCE\nvideo', 'ref'), ('TODAY\nR15', 'today_R15'), ('PROPOSED\nR15', 'proposed_R15'), ('PROPOSED\nR6', 'proposed_R6')]
    head = 116; rowh = PH + 26; bottom = 400
    H = head + rowh * len(rows) + bottom + 20
    img = Image.new('RGB', (W, H), 'white'); d = ImageDraw.Draw(img)
    label(d, (16, 12), 'Bat swing: the reference video vs today vs the proposal', 26, bold=True)
    label(d, (16, 48), 'APPROXIMATE renders: a blocky R15 / R6 rig at the game\'s 1.25 scale with the fallback bat (x1.5); real BatSwingPose (today) and the proposed '
          'BatSwingPose158 sampled on an exact CFrame. Legs stand still here; in the game they keep running / jumping (the swing is upper body only).', 13, fill=(70, 70, 70))
    label(d, (16, 66), 'White ribbon = the proposed swing trail (strike only). Reference = the owner\'s video, swing 1 (0.39-1.28 s), camera in front of the player.', 13, fill=(70, 70, 70))
    for c, (phase, rt, (tt, tname), pt) in enumerate(COLS):
        x = LW + c * PW
        label(d, (x + PW / 2, head - 4), phase, 16, bold=True, fill=(200, 30, 30) if phase == 'CONTACT' else (25, 25, 25), anchor='md')
    for r, (rname, key) in enumerate(rows):
        y = head + r * rowh
        label(d, (14, y + PH / 2 - 18), rname, 17, bold=True, fill=(25, 25, 25))
        for c, (phase, rt, (tt, tname), pt) in enumerate(COLS):
            x = LW + c * PW
            src = os.path.join(refdir, f'ref_{c}.png') if key == 'ref' else os.path.join(rdir, f'{key}_{c}.png')
            img.paste(Image.open(src).convert('RGB').resize((PW, PH)), (x, y))
            if key == 'ref': cap = f'{PTS[rt] - SWING_START:+.2f} s  (video {PTS[rt]:.2f})'
            elif key == 'today_R15': cap = f'{tt:.3f} s  {tname}'
            else: cap = f'{pt:.3f} s'
            if phase == 'CONTACT' and key != 'ref': cap += '  = server hit'
            label(d, (x + 6, y + PH + 4), cap, 12, fill=(60, 60, 60))
            d.rectangle([x, y, x + PW - 1, y + PH - 1], outline=(255, 255, 255), width=2)
    # bottom: timeline + top views + effects
    y = head + rowh * len(rows) + 10
    tl = timeline(W - 3 * 340 - 30, bottom - 20); img.paste(tl, (10, y))
    x = W - 3 * 340 - 10
    for name, cap in [('top_today.png', 'Today from above: grey = bat tip path,\nblue = tip at 0.30 s (the only moment that\nhits); blue box = today\'s hit box 16x14'),
                      ('top_proposed.png', 'Proposed from above: red = tip path in the\nhit window .24-.36 s (behind -> right -> front\n-> left); a hit counts in the orange sector'),
                      ('fx_proposed.png', 'Proposed effects at contact: the white\ntrail (strike only) + the impact star\n(pooled), shown here as if it hit')]:
        img.paste(Image.open(os.path.join(rdir, name)).convert('RGB'), (x, y))
        d.multiline_text((x + 4, y + 334), cap, font=font(12), fill=(50, 50, 50), spacing=2)
        x += 340
    img.save(out, optimize=True)

def gif(rdir, refdir, fdir, out):
    os.makedirs(fdir, exist_ok=True)
    names = [('REFERENCE (video)', 'ref'), ('TODAY', 'today'), ('PROPOSED', 'proposed')]
    def phase_of(sys, t):
        if sys == 'today':
            return 'wind back' if t < .135 else 'hold' if t < .165 else 'whip' if t < .30 - 1e-6 else 'CONTACT' if t < .334 else 'follow-through' if t < .432 else 'settle' if t < .74 else 'idle'
        if sys == 'proposed':
            return 'load' if t < .07 else 'coil' if t < .22 else 'strike' if t < .30 - 1e-6 else 'CONTACT' if t < .32 else 'through' if t < .335 else 'follow-through' if t < .60 else 'recovery' if t < .85 else 'idle'
        r = t + REF_START - SWING_START
        return 'idle' if r < 0 else 'load' if r < .06 else 'coil' if r < .26 else 'strike' if r < .275 else 'CONTACT' if r < .305 else 'strike' if r < .32 else 'follow-through' if r < .59 else 'recovery' if r < .89 else 'idle'
    for k in range(30):
        t = k / 30
        frame = Image.new('RGB', (GW * 3 + 20, GH + 74), 'white'); d = ImageDraw.Draw(frame)
        for i, (title, key) in enumerate(names):
            x = 5 + i * (GW + 5)
            src = os.path.join(refdir, f'g_ref_{k:02d}.png') if key == 'ref' else os.path.join(rdir, f'g_{key}_{k:02d}.png')
            frame.paste(Image.open(src).convert('RGB').resize((GW, GH)), (x, 30))
            label(d, (x + GW / 2, 6), title, 16, bold=True, fill=(25, 25, 25), anchor='ma')
            ph = phase_of(key, t)
            label(d, (x + GW / 2, GH + 36), ph, 16, bold=ph == 'CONTACT', fill=(200, 30, 30) if ph == 'CONTACT' else (40, 40, 40), anchor='ma')
        label(d, (8, GH + 56), f't = {t:.3f} s   shown at HALF speed   approximate renders (blocky rig, fallback bat)', 12, fill=(90, 90, 90))
        frame.save(os.path.join(fdir, f'f_{k:02d}.png'))
    pal = os.path.join(fdir, 'palette.png')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-framerate', '15', '-i', os.path.join(fdir, 'f_%02d.png'), '-vf', 'palettegen=max_colors=128', pal], check=True)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-framerate', '15', '-i', os.path.join(fdir, 'f_%02d.png'), '-i', pal,
                    '-lavfi', 'paletteuse=dither=bayer:bayer_scale=4', '-loop', '0', out], check=True)

if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'jobs': jobs(sys.argv[2])
    elif cmd == 'refs': refs(sys.argv[2], sys.argv[3])
    elif cmd == 'sheet': sheet(*sys.argv[2:5])
    elif cmd == 'gif': gif(*sys.argv[2:6])
