"""R158 bats: solve the PROPOSED swing keys (joint angles) from where the bat should be at each key.
Usage: python3 solve_keys158.py > keys158.txt   (numpy only)
Each key is designed as: the waist (lean / twist), where the right hand holds the bat (grip, character space, studs) and where the bat points.
The right arm angles (shoulder XYZ, elbow X, wrist XYZ, as CFrame.Angles degrees, parent space like BatSwingPose) are solved by a small
Nelder-Mead fit on an APPROXIMATE blocky R15 rig (and the rigid R6 arm: shoulder only). The rig numbers match swing_render158.html.
Character space: x = right, y = up, z = back (the character faces -z), feet at y = 0. The bat lies along the hand's front (-z) axis, as in
BatSwingPose's note (R15 RightGripAttachment / R6 RightGrip turn the handle's +y onto the hand's -z).
"""
import json, math, sys
import numpy as np

def rx(a):
    c, s = math.cos(a), math.sin(a); return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
def ry(a):
    c, s = math.cos(a), math.sin(a); return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
def rz(a):
    c, s = math.cos(a), math.sin(a); return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
def angles(x, y, z):  # CFrame.Angles in degrees: Rx * Ry * Rz
    return rx(math.radians(x)) @ ry(math.radians(y)) @ rz(math.radians(z))

# --- approximate rigs (keep in sync with swing_render158.html) ---------------------------------------------------------------------------
R15 = dict(waist=np.array([0, 2.4, 0.0]), ut_center=np.array([0, 0.8, 0.0]), shoulder=np.array([1.0, 0.55, 0.0]),
           elbow=np.array([0.5, -0.9, 0.0]), wrist=np.array([0, -0.8, 0.0]), grip=np.array([0, -0.2, 0.0]))
R6 = dict(root=np.array([0, 3.0, 0.0]), shoulder=np.array([1.0, 0.5, 0.0]), grip=np.array([0.5, -1.5, 0.0]))
FRONT = np.array([0, 0, -1.0])

def r15_hand(waist, s, e, w):
    """grip position, bat direction (unit) for waist / shoulder / elbow / wrist rotation matrices"""
    W = waist
    sh = R15['waist'] + W @ (R15['ut_center'] + R15['shoulder'])  # shoulder joint: UpperTorso centre (0, .8 above the waist) + (1, .55, 0)
    S = W @ s
    el = sh + S @ R15['elbow']
    SE = S @ e
    wr = el + SE @ R15['wrist']
    SEW = SE @ w
    return wr + SEW @ R15['grip'], SEW @ FRONT, (sh, el, wr)

def r6_hand(root, s):
    sh = R6['root'] + root @ R6['shoulder']
    S = root @ s
    return sh + S @ R6['grip'], S @ FRONT, (sh,)

def nelder_mead(f, x0, step=20.0, iters=3000, tol=1e-9):
    n = len(x0); pts = [np.array(x0, float)]
    for i in range(n):
        p = np.array(x0, float); p[i] += step; pts.append(p)
    vals = [f(p) for p in pts]
    for _ in range(iters):
        order = np.argsort(vals); pts = [pts[i] for i in order]; vals = [vals[i] for i in order]
        if abs(vals[-1] - vals[0]) < tol: break
        c = np.mean(pts[:-1], axis=0)
        xr = c + (c - pts[-1]); fr = f(xr)
        if fr < vals[0]:
            xe = c + 2 * (c - pts[-1]); fe = f(xe)
            if fe < fr: pts[-1], vals[-1] = xe, fe
            else: pts[-1], vals[-1] = xr, fr
        elif fr < vals[-2]: pts[-1], vals[-1] = xr, fr
        else:
            xc = c + 0.5 * (pts[-1] - c); fc = f(xc)
            if fc < vals[-1]: pts[-1], vals[-1] = xc, fc
            else:
                for i in range(1, len(pts)):
                    pts[i] = pts[0] + 0.5 * (pts[i] - pts[0]); vals[i] = f(pts[i])
    i = int(np.argmin(vals)); return pts[i], vals[i]

def unit(v):
    v = np.array(v, float); return v / np.linalg.norm(v)

# --- the PROPOSED keys: (name, time s, waist Angles, grip target, bat direction target, left shoulder Angles, left elbow Angles) ------------
# Times: load .00-.07 (fast), coil .07-.22 (slow drift), strike .22-.30 (accelerating: B at .26), contact .30 (bat straight ahead),
# through .30-.335 (D: bat out to the left), follow-through .335-.52 (E: wrapped low to the left, decelerating), hold to .60,
# recovery .60-.85 (F at .72: rising in front, then blend back to the tool hold).
KEYS = [
    ('A',  .07, (-4, -25, 3),  (0.95, 4.55, -0.15), (-0.80, -0.05, 0.60), (20, 0, -6), (20, 0, 0)),
    ('A2', .22, (-5, -35, 4),  (1.05, 4.45, 0.15),  (-0.70, -0.20, 0.68), (28, 6, -6), (25, 0, 0)),
    ('B',  .26, (-8, -15, 1),  (1.35, 3.35, -0.45), (0.80, -0.02, 0.60),  (12, 0, -10), (20, 0, 0)),
    ('C',  .30, (-12, 12, -3), (0.55, 3.00, -1.65), (-0.15, -0.08, -1.0), (-20, 0, -18), (15, 0, 0)),
    ('D',  .335, (-12, 38, -5), (-0.45, 2.95, -1.35), (-1.0, -0.12, -0.15), (-28, -5, -26), (20, 0, 0)),
    ('E',  .52, (-10, 55, -6), (-1.00, 2.80, -0.55), (-0.45, -0.55, 0.70), (-25, -5, -24), (22, 0, 0)),
    ('F',  .72, (-4, 22, -2),  (0.70, 3.40, -1.45), (-0.20, 0.80, -0.55), (0, 0, -8), (12, 0, 0)),
]
REST = dict(shoulder=(90, 0, 0), grip=None)

def solve_r15(prev, waist, grip, bat):
    W = angles(*waist); g = np.array(grip); d = unit(bat)
    def cost(x):
        s = angles(x[0], x[1], x[2]); e = angles(x[3], 0, 0); w = angles(x[4], x[5], x[6])
        gp, dp, _ = r15_hand(W, s, e, w)
        c = 4 * np.sum((gp - g) ** 2) + 30 * np.sum((dp - d) ** 2)
        c += 2e-4 * (x[4] ** 2 + x[5] ** 2 + x[6] ** 2)           # the wrist does little; shoulder and elbow carry the bat
        c += 3e-5 * np.sum((x - prev) ** 2)                          # stay close to the previous key (no flips between keys)
        if x[3] < 0: c += 0.05 * x[3] ** 2                           # the elbow only bends one way
        if x[3] > 150: c += 0.05 * (x[3] - 150) ** 2
        return c
    best = None
    rng = np.random.default_rng(158)
    for k in range(40):
        x0 = prev + (rng.normal(0, 35, 7) if k else 0)
        x, v = nelder_mead(cost, x0)
        x, v = nelder_mead(cost, x, step=5)
        if best is None or v < best[1]: best = (x, v)
    return best

def solve_r6(prev, root, bat, grip):
    R = angles(*root); d = unit(bat); g = np.array(grip)
    def cost(x):
        s = angles(x[0], x[1], x[2]); gp, dp, _ = r6_hand(R, s)
        return 30 * np.sum((dp - d) ** 2) + 0.6 * np.sum((gp - g) ** 2) + 3e-5 * np.sum((x - prev) ** 2)
    best = None; rng = np.random.default_rng(6)
    for k in range(40):
        x0 = prev + (rng.normal(0, 40, 3) if k else 0)
        x, v = nelder_mead(cost, x0); x, v = nelder_mead(cost, x, step=5)
        if best is None or v < best[1]: best = (x, v)
    return best

def main():
    out = {'R15': [], 'R6': []}
    prev = np.array([90.0, 0, 0, 0, 0, 0, 0])          # the tool hold: arm straight forward
    prev6 = np.array([90.0, 0, 0])
    for name, t, waist, grip, bat, ls, le in KEYS:
        x, v = solve_r15(prev, waist, grip, bat); prev = x
        W = angles(*waist); gp, dp, _ = r15_hand(W, angles(*x[:3]), angles(x[3], 0, 0), angles(*x[4:]))
        r = [round(float(a)) for a in x]
        out['R15'].append(dict(Key=name, Time=t, Waist=list(waist), RightShoulder=r[0:3], RightElbow=[r[3], 0, 0], RightWrist=r[4:7],
                               LeftShoulder=list(ls), LeftElbow=list(le),
                               GripError=round(float(np.linalg.norm(gp - np.array(grip))), 2),
                               BatAngleError=round(math.degrees(math.acos(max(-1, min(1, float(dp @ unit(bat)))))), 1)))
        # R6: the whole body turns on RootJoint (legs too), so 60 % of the twist and no lean; the rigid arm only matches the bat direction
        root = (0, waist[1] * 0.6, 0)
        y, w6 = solve_r6(prev6, root, bat, grip); prev6 = y
        R = angles(*root); g6, d6, _ = r6_hand(R, angles(*y))
        out['R6'].append(dict(Key=name, Time=t, RootJoint=list(root), RightShoulder=[round(float(a)) for a in y],
                              LeftShoulder=[ls[0], ls[1], ls[2]],
                              GripOffset=round(float(np.linalg.norm(g6 - np.array(grip))), 2),
                              BatAngleError=round(math.degrees(math.acos(max(-1, min(1, float(d6 @ unit(bat)))))), 1)))
    json.dump(out, sys.stdout, indent=1)

if __name__ == '__main__':
    main()
