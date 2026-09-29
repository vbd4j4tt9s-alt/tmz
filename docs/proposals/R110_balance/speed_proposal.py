"""R110 speed proposal: keeper speeds x1.6 per biome, player needs floor x1.10, points curve tuned by sim."""
from data import *
KEEPER_P = {}
FLOORS = {1: 20, 6: 32, 2: 50, 3: 80, 4: 128, 5: 205, 7: 330}
for s, f in FLOORS.items():
    KEEPER_P[s] = (f, round(f * 1.15), round(f * 1.30))
NEED = {s: round(f * 1.10) for s, f in FLOORS.items()}   # speed a player needs to farm biome s comfortably
# Rule: reaching the next biome takes STEP_MIN minutes on the treadmill with the machine named for the biome
# you are in (and the trail one tier below). Points = 100/s * machine * trail * minutes * 60, rounded.
STEP_MIN = {6: 1, 2: 3, 3: 6, 4: 10, 5: 20, 7: 40}
def rule_points():
    pts, prev = {}, 0
    for k, s in enumerate(BIOME_ORDER[1:]):
        m = MACHINE_MULT[k]
        tr = TRAIL_MULT[k - 1] if k >= 1 else 1
        prev = prev + 100 * m * tr * STEP_MIN[s] * 60
        pts[s] = prev
    return pts
# rounded rule_points() -> {6: 6000, 2: 114000, 3: 1554000, 4: 19554000, 5: 307554000, 7: 5107554000}
POINTS_AT = {6: 6000, 2: 120000, 3: 1500000, 4: 20000000, 5: 300000000, 7: 5000000000}
# tail keeps today's 500 @ 100B so no top player's speed drops

def curve(points_at=None):
    pa = points_at or POINTS_AT
    knots = [(0, 24)] + [(pa[s], NEED[s]) for s in BIOME_ORDER[1:]] + [(100000000000, 500)]
    return knots

def speed_fn(points_at=None):
    k = curve(points_at)
    return lambda p: speed_from_points(p, k, SPEED_TAIL)
