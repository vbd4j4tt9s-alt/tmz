"""R151 speed popups: the numbers measured from the owner's reference clip (another game, a player running on a treadmill, "+3.5K" popups with a
shoe icon). Usage: python3 reference_fit.py [OUT.json]   (needs numpy; no video needed: the hand-tracked samples are below).

The clip is 2560x1344 at 30 fps (frame spacing 33.3 ms, 113 frames, the first 1.9 s show the treadmill). Frames were extracted at native timing,
cropped around the player, and every popup was followed by hand and by blue-icon (shoe) colour segmentation:
  * head centre in the stable window (frames 30-57, camera nearly still): (344, 239) in the 700x440 crop at (920, 420); hair width 55 px.
  * a popup's icon centroid per frame -> TRACKS (px in that crop); the popup's centre is the icon + 47 px (icon left edge .. text right edge).
  * text darkness (the 6th percentile of luminance over the text box against its 80th percentile -> 1 - ratio) per frame -> ALPHA samples.
  * icon bounding-box width per frame since birth -> SCALE samples (full size = 23.5 px).
Nothing from the clip is copied into the repo: only these numbers.
"""
import json
import math
import sys

import numpy as np

FRAME = 1 / 30.0
HEAD = (344.0, 239.0)
HEAD_PX = 55.0              # hair width in the crop
ICON_TO_CENTER = 47.0       # popup centre = icon centroid + this (x)
PX1080 = 1080 / 1344.0      # clip px -> px of a 1080 p screen

# icon centroids, (frame, x, y); the last samples are the rest position
TRACKS = {
    'A': [(30, 324, 233), (31, 307, 222), (32, 293, 211), (33, 283, 204), (34, 276, 197), (35, 273, 192), (36, 269, 188), (37, 269, 186),
          (38, 268, 184), (39, 268, 182), (40, 269, 182), (41, 268, 181), (42, 267, 181), (43, 267, 180), (44, 268, 180)],
    'B': [(33, 323, 242), (34, 304, 234), (35, 290, 225), (36, 278, 220), (37, 271, 215), (38, 266, 212), (39, 263, 209), (40, 261, 207),
          (41, 260, 206)],
    'D2': [(28, 342, 209), (29, 340, 194), (30, 338, 182), (31, 338, 174), (32, 339, 167), (33, 340, 162), (34, 343, 158), (35, 345, 155),
           (36, 346, 153), (37, 346, 151), (38, 347, 151), (39, 347, 151), (40, 348, 151), (41, 347, 151)],
    'F': [(44, 305, 193), (45, 303, 181), (46, 291, 171), (47, 287, 162), (48, 286, 156), (49, 286, 152), (50, 285, 149), (51, 285, 145),
          (52, 287, 143), (53, 287, 143), (54, 287, 143), (55, 287, 142)],
}
# icons that were already at rest when the stable window began (only the rest position is known)
STATIC_REST = {'C': (202, 145), 'G': (402, 204), 'D1': (375, 147)}

# icon width (px) per frame after the first sighting, for three popups; full size = 23.5 px
SCALE_SAMPLES = {'A': [9, 16, 20, 24, 26, 22, 24], 'B': [10, 14, 22, 26, 25, 27], 'D2': [16, 20, 22, 22, 24, 26, 24, 24]}

# text darkness (1 = opaque) at the rest position of a popup, (frame, alpha)
ALPHA_SAMPLES = {
    'G': [(35, .96), (36, .79), (37, .57), (38, .41), (39, .23), (40, .03)],
    'D1': [(41, .93), (42, .76), (43, .54), (44, .08)],
    'D2': [(40, .97), (41, .96), (42, .84), (43, .65), (44, .45), (45, .29)],
}
# spawn cadence: the frame in which a new, small popup first shows next to the head (clip crop at (700, 150), frames 1..26 and 27..48)
BIRTH_FRAMES = [6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39, 42, 45, 48]


def fit_ease(max_power=5):
    """Least squares of  d(t) = D * (1 - (t - t0) / T) ** p  over the four tracks (T shared, t0 and D per track)."""
    out = {}
    for p in range(1, max_power + 1):
        best = None
        for T in np.arange(0.15, 0.7, 0.01):
            err, det = 0.0, {}
            for name, tr in TRACKS.items():
                fr = np.array([a for a, _, _ in tr], float)
                xy = np.array([[x, y] for _, x, y in tr], float)
                rest = xy[-3:].mean(0)
                d = np.linalg.norm(xy - rest, axis=1)
                tt = fr * FRAME
                be, bp = 1e18, None
                for t0 in np.arange(tt[0] - 0.20, tt[0] + 0.05, 0.005):
                    for D in np.arange(d[0] * 0.9, d[0] * 2.2, 2.0):
                        u = np.clip((tt - t0) / T, 0, 1)
                        e = float(((D * (1 - u) ** p - d) ** 2).sum())
                        if e < be:
                            be, bp = e, (t0 - tt[0], D)
                err += be
                det[name] = {'spawn_before_first_sight_s': round(float(-bp[0]), 3), 'travel_px': round(float(bp[1]), 1)}
            if best is None or err < best[0]:
                best = (err, float(T), det)
        out[p] = {'T': round(best[1], 2), 'sse': round(best[0], 1), 'tracks': best[2]}
    return out


def rest_offsets():
    rows = {}
    pts = {k: (v[-1][1], v[-1][2]) for k, v in TRACKS.items()}
    pts.update(STATIC_REST)
    for name, (x, y) in sorted(pts.items()):
        cx, cy = x + ICON_TO_CENTER, y
        dx, dy = cx - HEAD[0], HEAD[1] - cy             # dy > 0 = above the head
        rows[name] = {'dx': round(dx), 'up': round(dy), 'radius': round(math.hypot(dx, dy)), 'angle_from_vertical_deg': round(math.degrees(math.atan2(dx, dy)))}
    return rows


def main():
    rows = rest_offsets()
    ang = np.array([r['angle_from_vertical_deg'] for r in rows.values()], float)
    rad = np.array([r['radius'] for r in rows.values()], float)
    up = np.array([r['up'] for r in rows.values()], float)
    adx = np.array([abs(r['dx']) for r in rows.values()], float)
    gaps = np.diff(BIRTH_FRAMES) * FRAME
    fits = fit_ease()
    # fade: time from opaque to clear, linear extrapolation of the three popups
    fade_len = []
    for name, rows_ in ALPHA_SAMPLES.items():
        t = np.array([f * FRAME for f, _ in rows_]); a = np.array([v for _, v in rows_])
        sel = (a < 0.93) & (a > 0.05)
        slope = np.polyfit(t[sel], a[sel], 1)[0]
        fade_len.append(0.95 / -slope)
    out = {
        'clip': {'size': [2560, 1344], 'fps': 30, 'frame_ms': 33.3, 'head_px': HEAD_PX},
        'spawn': {'interval_s': round(float(gaps.mean()), 3), 'interval_min_max_s': [round(float(gaps.min()), 3), round(float(gaps.max()), 3)],
                  'per_second': round(float(1 / gaps.mean()), 1), 'at_head_centre_jitter_px': 8},
        'rest_offsets_px': rows,
        'rest_stats': {'angle_from_vertical_deg': {'mean': round(float(ang.mean())), 'sd': round(float(ang.std())), 'min': int(ang.min()), 'max': int(ang.max())},
                       'radius_px': {'mean': round(float(rad.mean())), 'min': int(rad.min()), 'max': int(rad.max())},
                       'up_px': {'mean': round(float(up.mean())), 'min': int(up.min()), 'max': int(up.max())},
                       'abs_dx_px': {'mean': round(float(adx.mean())), 'max': int(adx.max())},
                       'radius_in_head_widths': round(float(rad.mean() / HEAD_PX), 2),
                       'radius_in_1080p_px': round(float(rad.mean() * PX1080))},
        'ease_fit': fits,
        'fade': {'length_s_per_popup': [round(float(x), 3) for x in fade_len], 'length_s_mean': round(float(np.mean(fade_len)), 3)},
        'scale_samples_icon_width_px': SCALE_SAMPLES,
        'alpha_samples': {k: [(round(f * FRAME, 3), v) for f, v in vals] for k, vals in ALPHA_SAMPLES.items()},
        'tracks_px': TRACKS,
    }
    text = json.dumps(out, indent=1)
    if len(sys.argv) > 1:
        open(sys.argv[1], 'w').write(text)
    print(text if len(sys.argv) < 2 else 'wrote ' + sys.argv[1])
    print('\nspawn every %.3f s (%.1f per second); rest radius %.0f px (%.2f head widths); angle %.0f +- %.0f deg' % (
        gaps.mean(), 1 / gaps.mean(), rad.mean(), rad.mean() / HEAD_PX, ang.mean(), ang.std()), file=sys.stderr)
    for p, f in fits.items():
        print('ease-out power %d: best T = %.2f s, SSE %.1f' % (p, f['T'], f['sse']), file=sys.stderr)


if __name__ == '__main__':
    main()
