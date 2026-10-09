"""R156 preview: lays out docs/proposals/R156/reveal_fixes.png from the rendered layers of run_reveal_fixes_preview.sh (BEFORE = R155 as released, AFTER = the proposed change).
Usage: python3 compose_reveal_fixes156.py <scratch dir> <out.png>
For every frame the layers are composed as R155's compose155.py does (the world or the story stage with its colour grade, the HUD and the card's GUI under and over the
seed's viewport); the numbers on the sheet (where the pill is, the band the card is fitted to, the rows) are the ones the Luau side printed (PILL / FIT / GUIDE lines).
APPROXIMATE: the GUI trees are the real ones on the Roblox mock, drawn by Chromium; the hotbar, BASE / TRACK and the pity bars are real, the balances, status stack, MENU,
tools and the touch controls are stand-ins placed by HudLayout's metrics; the world is a stand-in garden. Not a Studio screenshot."""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
PAPER, INK, MUTED, RULE = (246, 247, 251), (24, 28, 44), (92, 100, 124), (200, 204, 216)
RED, GREEN, GOLD, CYAN, MAGENTA = (200, 58, 58), (24, 140, 76), (255, 214, 0), (0, 200, 230), (255, 70, 200)
W_, PAD, GAP = 1900, 24, 12


def font(px, bold=True):
    try:
        return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf' if bold else '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', px)
    except Exception:
        return ImageFont.load_default()


F_TITLE, F_HEAD, F_BAN, F_CAP, F_NOTE, F_SMALL = font(34), font(25), font(16), font(14, False), font(15, False), font(12)
PROBE = ImageDraw.Draw(Image.new('RGB', (10, 10)))


def wrap(text, f, width):
    lines = []
    for para in text.split('\n'):
        line = ''
        for w in para.split():
            t = (line + ' ' + w).strip()
            if PROBE.textlength(t, font=f) > width and line:
                lines.append(line)
                line = w
            else:
                line = t
        lines.append(line)
    return lines


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
# layers
def grade(img, g, blur, scale):
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


def compose(d, m):
    img = grade(Image.open(os.path.join(d, m['name'] + '_world.png')), m['grade'], m['blur'], m['h'] / 720).convert('RGBA')
    for i in range(m.get('under', 0)):
        overlay(img, os.path.join(d, '%s_under%d.png' % (m['name'], i)))
    vp = m.get('vp')
    if vp and os.path.exists(os.path.join(d, m['name'] + '_vp.png')):  # the card's seed (its ViewportFrame)
        x, y, w, h = vp['rect']
        s = max(1, int(w * vp['scale']))
        card = Image.open(os.path.join(d, m['name'] + '_vp.png')).convert('RGBA').resize((s, s), Image.LANCZOS)
        if vp['alpha'] < 1:
            card.putalpha(card.split()[3].point(lambda v: int(v * vp['alpha'])))
        img.alpha_composite(card, (int(x + w / 2 - s / 2), int(y + h / 2 - s / 2)))
    for i in range(m['guis']):
        overlay(img, os.path.join(d, '%s_gui%d.png' % (m['name'], i)))
    return img.convert('RGB')


DATA = {}


def data(tree, view):
    key = (tree, view)
    if key not in DATA:
        d = os.path.join(S, 'out', tree, view)
        meta = {m['name']: m for m in json.load(open(os.path.join(d, 'meta.json')))}
        info = {'pill': {}, 'fit': {}, 'guide': None, 'button': {}}
        for line in open(os.path.join(S, tree, 'cl', 'frames_%s.txt' % view), encoding='utf-8'):
            if line.startswith('GUIDE '):
                info['guide'] = json.loads(line.split(' ', 2)[2])
            elif line.startswith('PILL '):
                p = line.split(' ', 3)
                info['pill'][p[2]] = json.loads(p[3])
            elif line.startswith('FIT '):
                p = line.split(' ', 3)
                info['fit'][p[2]] = json.loads(p[3])
            elif line.startswith('PILLBUTTON '):
                p = line.split()
                info['button'][p[2]] = p[3] == 'yes'
        DATA[key] = (d, meta, info)
    return DATA[key]


def panel(tree, view, name, scale, mark_pill=False, guides=False, crop=None, no_pill_tag=False):
    """one frame as an image, scaled; the pill outlined (mark_pill), the band's two edges drawn (guides), cropped to crop = (x, y, w, h) in screen px first"""
    d, meta, info = data(tree, view)
    img = compose(d, meta[name])
    ox, oy = (crop[0], crop[1]) if crop else (0, 0)
    if crop:
        img = img.crop((crop[0], crop[1], crop[0] + crop[2], crop[1] + crop[3]))
    if scale != 1:
        img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    dr = ImageDraw.Draw(img, 'RGBA')
    if mark_pill and name in info['pill']:
        p = info['pill'][name]
        x0, y0 = (p['x'] - ox) * scale, (p['y'] - oy) * scale
        x1, y1 = x0 + p['w'] * scale, y0 + p['h'] * scale
        e = max(3, 5 * scale)
        dr.rectangle([x0 - e, y0 - e, x1 + e, y1 + e], outline=GOLD + (255,), width=max(2, round(3 * scale)))
    if guides and info['guide']:
        g = info['guide']
        for y, col, text in ((g['travel'], CYAN, 'BASE / TRACK bottom'), (min(g['pity'], g['hotbar']), MAGENTA, 'pity bars / hotbar top')):
            yy = (y - oy) * scale
            x = 0
            while x < img.width:
                dr.line([(x, yy), (min(img.width, x + 9), yy)], fill=col + (255,), width=2)
                x += 15
            f = F_SMALL
            tw = PROBE.textlength(text, font=f)
            ty = yy - 15 if col == CYAN else yy - 15
            if col == CYAN:
                ty = yy + 2
            dr.rectangle([3, ty - 1, 3 + tw + 6, ty + 14], fill=(0, 0, 0, 170))
            dr.text((6, ty), text, font=f, fill=col + (255,))
    if no_pill_tag:
        t = 'no SKIP pill'
        f = F_BAN
        tw = PROBE.textlength(t, font=f)
        dr.rectangle([img.width - tw - 20, img.height - 30, img.width - 6, img.height - 6], fill=(0, 0, 0, 180))
        dr.text((img.width - tw - 13, img.height - 28), t, font=f, fill=(255, 255, 255, 255))
    return img


def captioned(img, banner, color, caption, width=None):
    """banner (coloured strip) above, caption (wrapped) below"""
    width = width or img.width
    lines = wrap(caption, F_CAP, width) if caption else []
    h = 24 + img.height + 4 + len(lines) * 18
    out = Image.new('RGB', (width, h), PAPER)
    d = ImageDraw.Draw(out)
    d.rectangle([0, 0, width - 1, 21], fill=color)
    d.text((8, 2), banner, font=F_BAN, fill=(255, 255, 255))
    out.paste(img, (0, 24))
    d.rectangle([0, 23, width - 1, 24 + img.height], outline=color)
    for i, l in enumerate(lines):
        d.text((0, 24 + img.height + 4 + i * 18), l, font=F_CAP, fill=MUTED)
    return out


def note(width, title, body, tint=(255, 255, 255)):
    lines = []
    for para in body:
        lines += wrap(para, F_NOTE, width - 24) + ['']
    lines = lines[:-1]
    h = 14 + (28 if title else 0) + len(lines) * 20 + 10
    out = Image.new('RGB', (width, h), tint)
    d = ImageDraw.Draw(out)
    d.rectangle([0, 0, width - 1, h - 1], outline=RULE)
    y = 10
    if title:
        d.text((12, y), title, font=F_BAN, fill=INK)
        y += 28
    for l in lines:
        d.text((12, y), l, font=F_NOTE, fill=INK)
        y += 20
    return out


def hstack(images, gap=GAP):
    out = Image.new('RGB', (sum(i.width for i in images) + gap * (len(images) - 1), max(i.height for i in images)), PAPER)
    x = 0
    for i in images:
        out.paste(i, (x, 0))
        x += i.width + gap
    return out


def vstack(images, gap=10):
    out = Image.new('RGB', (max(i.width for i in images), sum(i.height for i in images) + gap * (len(images) - 1)), PAPER)
    y = 0
    for i in images:
        out.paste(i, (0, y))
        y += i.height + gap
    return out


rows = []  # [(heading or None, [images])]


def row(blocks, heading=None):
    rows.append((heading, blocks))


def ba(view, name, scale, before_cap, after_cap, **kw):
    """a BEFORE / AFTER pair of the same frame"""
    kb = dict(kw)
    ka = dict(kw)
    if kw.get('no_pill_after'):
        kb.pop('no_pill_after')
        ka.pop('no_pill_after')
        ka['no_pill_tag'] = True
    b = captioned(panel('before', view, name, scale, **kb), 'BEFORE: R155 as it is today', RED, before_cap)
    a = captioned(panel('after', view, name, scale, **ka), 'AFTER: proposed', GREEN, after_cap)
    return [b, a]


def pillcap(tree, view, name, extra=''):
    p = data(tree, view)[2]['pill'].get(name)
    if not p:
        return 'no pill' + extra
    return 'pill %dx%d px, %d px from the right edge, %d px from the bottom%s' % (p['w'], p['h'], p['right'], p['bottom'], extra)


def fitcap(tree, view, name):
    d = data(tree, view)[2]
    f = d['fit'].get(name)
    g = d['guide']
    if not f:
        t = 'title, seed, "1 in N", name run from the top of the screen to the hotbar; the hint is in the bottom-right corner'
        return t
    return 'band %d..%d px (of %d): BASE / TRACK ends at %d, the pity bars start at %d; k = %.2f' % (f['top'], f['bottom'], g['h'], g['travel'], g['pity'], f['k'])


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
PCS, PHS = .475, .72  # PC panels, phone panels
PC = ('pc', 1920, 1080)
# 1 ------------------------------------------------------------------------------------------------------------------------------------------------------------
row(ba('pc', 'scene_skip', PCS, '1920 x 1080, a Cosmic story scene (the HUD is hidden): ' + pillcap('before', 'pc', 'scene_skip', ', up and left of where the hidden status stack is'),
       '1920 x 1080: ' + pillcap('after', 'pc', 'scene_skip'), mark_pill=True),
    '1.  The SKIP pill goes to the bottom-right corner of the screen (story scenes: Secret / Cosmic / King)')
own = (1251, 403, 640, 330)
b1 = captioned(panel('before', 'own1', 'scene_skip', 1, mark_pill=True, crop=own), 'BEFORE: your window, 1891 x 733 (bottom-right 640 x 330, 1:1)', RED,
               pillcap('before', 'own1', 'scene_skip'))
a1 = captioned(panel('after', 'own1', 'scene_skip', 1, mark_pill=True, crop=own), 'AFTER: the same window', GREEN, pillcap('after', 'own1', 'scene_skip'))
cause = note(W_ - 2 * PAD - 2 * 640 - 2 * GAP, 'Why it was not in the corner', [
    'RarePullCard.SkipRect keeps the pill 8 px clear of every box HudLayout.HudBoxes lists (the status / timers stack in the bottom-right corner, the hotbar, the balances, a '
    'phone\'s thumb zones) and of the pity bars (PityBars155.Reserved). It does so from the screen\'s size alone: it never asks whether that HUD is on screen. A story '
    'scene hides the whole HUD (RarePullCinematic.hideHud), but the boxes are still there, so the pill was pushed left and up from the corner by things that are not drawn.',
    'On the mock the push is 360 px from the right and 148 px up at 1920 x 1080; your Studio window measured about 450 and 220: the same mechanism, the exact spot '
    'follows the window\'s size.'], (255, 250, 232))
row([b1, a1, cause])
land_b = ba('land', 'scene_skip', PHS, '844 x 390, a King story scene: ' + pillcap('before', 'land', 'scene_skip'), '844 x 390: ' + pillcap('after', 'land', 'scene_skip'), mark_pill=True)
port_b = ba('port', 'scene_skip', PHS, '390 x 844, a Secret story scene: ' + pillcap('before', 'port', 'scene_skip'), '390 x 844: ' + pillcap('after', 'port', 'scene_skip'), mark_pill=True)
jb = ba('land', 'jump_skip', PHS, 'the same scene on a phone whose jump button stays visible: the pill stays where it was (the jump zone was always counted)',
        'the pill keeps clear of the REAL jump button (left of it, same bottom row); a control that is not on screen is ignored', mark_pill=True)
row([vstack([hstack(land_b), hstack(jb)], 14), hstack(port_b)])
rule1 = note(W_ - 2 * PAD, 'The new rule for where SKIP goes', [
    'Story scene (the director hides the HUD): the corner of the device\'s safe area, 14 px from the right and the bottom edge (was 12). The only thing it keeps clear of is a '
    'thumb control that is really on screen (HudLayout.Controls: it ignores one that is hidden or not there). On a phone the director holds the controls (ControlModule:Disable), '
    'which hides the stick and the jump button, so the corner is free; if a build leaves one visible, the pill steps clear of it, as in the lower left pair.',
    'A card that leaves the HUD up (a Secret / Cosmic / King opening in place) keeps today\'s rule: clear of the visible HUD (section 2).'], (234, 248, 238))
row([rule1])
# 2 ------------------------------------------------------------------------------------------------------------------------------------------------------------
row(ba('pc', 'common_susp', PCS, 'a Common opening, a moment into the suspense: the pill is up from 0.35 s to the hit', 'the same moment: nothing to skip (Common..Mythic take 1 to 4 s)', mark_pill=True,
       no_pill_after=True),
    '2.  SKIP only for Secret, Cosmic and King: a Common..Mythic opening has no pill at all')
mb = ba('land', 'mythic_susp', PHS, 'a Mythic opening, 844 x 390: the pill above the hotbar', 'the same: no pill', mark_pill=True, no_pill_after=True)
set_note = note(W_ - 2 * PAD - 2 * mb[0].width - 2 * GAP, 'What it does to the settings and keys', [
    'Common..Mythic: the card has no SkipFrom (RarePullRules.CardTimeline), so no pill is built, and RarePullCinematic.Skip answers false before the hit. Enter, gamepad B / R2 and '
    'a click or tap still COLLECT the result once it is shown (they never skipped it before the hit since R155: a click does not skip).',
    '"Skip pack animations" is untouched: it still gives Common..Mythic the Quick timing (a 0.35 to 0.75 s suspense) and still turns a Secret / Cosmic / King story into the '
    'in-place card. So a Common..Mythic is simply not skippable mid-animation; the collect click works as before.'], (234, 248, 238))
row(mb + [set_note])
ib = ba('land', 'inplace_res', PHS, 'a Secret opening in place ("Skip pack animations" on, HUD up), 844 x 390, the result: the title sits on BASE / TRACK',
        'the compact card is fitted the same way (upper part of the screen, below BASE / TRACK); the hint is under the name', guides=False)
ip = ba('land', 'inplace_skip', PHS, 'the same opening, a moment before the hit: ' + pillcap('before', 'land', 'inplace_skip'),
        'still skippable, still clear of the visible HUD (2 px: the margin is 14, was 12): ' + pillcap('after', 'land', 'inplace_skip'), mark_pill=True)
row([vstack([hstack(ib), hstack(ip)], 14), note(W_ - 2 * PAD - 2 * ib[0].width - 2 * GAP - 12, 'Secret / Cosmic / King in place', [
    'Their compact card keeps the pill: the HUD is up there, so it keeps clear of it (hotbar, pity bars, status stack, jump button) as today. Only the story scene, which hides the '
    'HUD, takes the plain corner.',
    'The compact card had the same bug as the Common one on a phone: its title sat on BASE / TRACK. It now uses the same fit, with its own sizes (title .075, seed .15, odds .05, '
    'name .035, hint .03 of the height) and a band that ends at 45 % of the height (at least 140 px tall), so the middle of the screen stays clear. Not in your screenshots: say if '
    'you would rather leave it as it was.'], (255, 255, 255))])
# 3 ------------------------------------------------------------------------------------------------------------------------------------------------------------
row(ba('pc', 'common_res', PCS, '1920 x 1080, a Common waiting to be collected. ' + fitcap('before', 'pc', 'common_res'),
       '1920 x 1080: ' + fitcap('after', 'pc', 'common_res'), guides=True),
    '3.  The seed display is fitted between BASE / TRACK and the pity bars / hotbar; "click to collect!" is under the name')
row(ba('pc', 'mythic_res', PCS, 'a Mythic (the biggest title and seed). ' + fitcap('before', 'pc', 'mythic_res'), 'a Mythic: ' + fitcap('after', 'pc', 'mythic_res'), guides=True))
o2b = ba('own2', 'common_res', 1, 'your second screenshot\'s window, 530 x 593: COMMON on BASE / TRACK, the name on the hotbar', '530 x 593: ' + fitcap('after', 'own2', 'common_res'), guides=True)
rule3 = note(W_ - 2 * PAD - 2 * o2b[0].width - 2 * GAP, 'The new card size rule, per screen', [
    'RarePullCard.FitBand gives the band, RarePullRules.FitLayout fits the card in it.',
    'Top = the bottom edge of BASE / TRACK (HudLayout.TravelBottom: the top bar row\'s centre + half the pair\'s height + 3 px shadow, the same arithmetic TravelButtons draws '
    'them by; 51 px with the default 52 px row) + a margin of 1.2 % of the height (at least 8 px). Mythic is also kept under its letterbox bar.',
    'Bottom = the highest of the hotbar\'s top (HudLayout: slots + the held item\'s name line), the pity bars\' top (PityBars155.Reserved: glow and the held bar\'s scale included) and, '
    'in a narrow window that lifts the balances and the status stack up beside the hotbar, their top where they reach into the middle column the words fill (.4 of the height wide); '
    'less the same margin. (This window: the balances, so the card ends at 328.)',
    'Five rows, top to bottom: the rarity word, the seed, "1 in N", the seed\'s name, the hint. Each keeps the size it had (title .07-.12 of the height, seed .26-.38, odds .08, name '
    '.045, hint .034). If they do not fit, all shrink alike (k), the words down to 24 / 20 / 15 / 13 px, the seed to 44 px and at most 62 % of the width, so the seed gives the rest. '
    'Spare room goes into the gaps (up to .04 of the height) and the stack is centred in the band.',
    'Measured on the screen it is on, again if the window changes size. The pity bars are dimmed under a card in R155 (their place is reserved anyway).'], (234, 248, 238))
row(o2b + [rule3])
row(ba('land', 'common_res', PHS, '844 x 390, Common. ' + fitcap('before', 'land', 'common_res'), '844 x 390: ' + fitcap('after', 'land', 'common_res'), guides=True)
    + ba('land', 'mythic_res', PHS, 'Mythic. ' + fitcap('before', 'land', 'mythic_res'), 'Mythic: ' + fitcap('after', 'land', 'mythic_res'), guides=True))
row(ba('port', 'common_res', PHS, '390 x 844, Common. ' + fitcap('before', 'port', 'common_res'), '390 x 844: ' + fitcap('after', 'port', 'common_res'), guides=True)
    + ba('port', 'mythic_res', PHS, 'Mythic. ' + fitcap('before', 'port', 'mythic_res'), 'Mythic: ' + fitcap('after', 'port', 'mythic_res'), guides=True))
# 3b -----------------------------------------------------------------------------------------------------------------------------------------------------------
row(ba('pc', 'scene_res', PCS, 'the Secret+ result after the story (the HUD is hidden): the hint was in the bottom-right corner, away from the name',
       'the hint is directly under the seed\'s name, centred ("tap to collect!" on a phone)'),
    '3b.  The Secret / Cosmic / King result after the story: the same hint, under the name')
row(ba('land', 'scene_res', PHS, '844 x 390, King', '844 x 390') + ba('port', 'scene_res', PHS, '390 x 844, Secret', '390 x 844'))


def table_rows():
    out = []
    for view, label in (('pc', '1920 x 1080'), ('own1', '1891 x 733'), ('own2', '530 x 593'), ('land', '844 x 390 (phone)'), ('port', '390 x 844 (phone)')):
        fit = data('after', view)[2]['fit']
        c, m = fit['common_res'], fit['mythic_res']
        h = data('after', view)[2]['guide']['h']
        out.append((label, '%d .. %d' % (c['top'], c['bottom']), '%d px (%d %% of the height), k %.2f' % (c['seed'][1], round(100 * c['seed'][1] / h), c['k']),
                    '%d px (%d %%), k %.2f, from %d' % (m['seed'][1], round(100 * m['seed'][1] / h), m['k'], m['top'])))
    return out


T = table_rows()
tw = W_ - 2 * PAD
tab = Image.new('RGB', (tw, 40 + 26 * (len(T) + 1)), (255, 255, 255))
dd = ImageDraw.Draw(tab)
dd.rectangle([0, 0, tw - 1, tab.height - 1], outline=RULE)
dd.text((12, 8), 'The card per screen (AFTER, measured on the mock): the band, the seed and the shrink factor k (1.00 = the sizes the card always had)', font=F_BAN, fill=INK)
cols = [12, 250, 520, 1050]
for j, t in enumerate(('screen', 'band top .. bottom (px)', 'Common: seed height', 'Mythic: seed height (its band starts under the letterbox bar)')):
    dd.text((cols[j], 36), t, font=F_NOTE, fill=MUTED)
for i, r in enumerate(T):
    for j, t in enumerate(r):
        dd.text((cols[j], 62 + 26 * i), t, font=F_NOTE, fill=INK)
at = next(i for i, (h, _) in enumerate(rows) if h and h.startswith('3b'))
rows.insert(at, (None, [tab]))
FOOT = ('APPROXIMATE, not a Studio screenshot: the GUI trees (the reveal card and its SKIP pill, the hotbar, the pity bars, BASE / TRACK) are the real ones on the Roblox mock, '
        'run by the real RarePullCinematic, drawn by headless Chromium; the balances, the status stack, MENU, the tools tile and the touch controls are stand-ins placed by HudLayout\'s '
        'metrics, the world is a stand-in garden, fonts are stand-ins. BASE / TRACK are placed in the top bar row\'s 52 px fallback (TravelButtons uses GuiService.TopbarInset when it '
        'has it; the card reads the same value). The pity bars are dimmed under a card by R155 (not drawn here); their place is the pink line. A UIAspectRatioConstraint is drawn as '
        'FitWithinMaxSize (Roblox\'s default). BEFORE = this checkout (R155 release); AFTER = the same src with preview/reveal_fixes.patch applied in a scratch copy: src/ is not changed.')
# layout ---------------------------------------------------------------------------------------------------------------------------------------------------------
y = PAD + 80
placed = []
for heading, blocks in rows:
    if heading:
        y += 10
        placed.append(('H', heading, PAD, y))
        y += 46
    total = sum(b.width for b in blocks) + GAP * (len(blocks) - 1)
    x = PAD
    h = max(b.height for b in blocks)
    for b in blocks:
        placed.append(('I', b, x, y))
        x += b.width + GAP
    y += h + 16
foot = wrap(FOOT, F_SMALL, W_ - 2 * PAD)
H_ = y + 10 + len(foot) * 16 + PAD
sheet = Image.new('RGB', (W_, H_), PAPER)
d = ImageDraw.Draw(sheet)
d.text((PAD, PAD), 'R156 PREVIEW: pack-opening reveal fixes, BEFORE (R155 today) and AFTER (proposed)', font=F_TITLE, fill=INK)
d.text((PAD, PAD + 44), 'Not a release; the owner approves first; src/ is unchanged. BEFORE = the current R155 look, AFTER = proposed. Yellow box = the SKIP pill. Cyan line = BASE / TRACK bottom. Pink line = the top of the pity bars / hotbar.', font=F_NOTE, fill=MUTED)
for kind, a, x, yy in placed:
    if kind == 'H':
        d.rectangle([PAD, yy, W_ - PAD, yy + 34], fill=(232, 236, 248))
        d.text((PAD + 10, yy + 4), a, font=F_HEAD, fill=INK)
    else:
        sheet.paste(a, (x, yy))
for i, l in enumerate(foot):
    d.text((PAD, y + 10 + i * 16), l, font=F_SMALL, fill=MUTED)
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
sheet.save(OUT, optimize=True)
print('wrote', OUT, sheet.size)
