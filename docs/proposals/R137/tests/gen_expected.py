"""Writes expected.luau: today's odds (the real PackOdds112 dump) and the owner-approved R137 odds, both from the
proposal's model (docs/proposals/pity_R136/sim.py, which checks itself against the real dump first)."""
import os, sys
here = os.path.dirname(os.path.abspath(__file__))
prop = os.path.normpath(os.path.join(here, '../../pity_R136'))
sys.path.insert(0, prop)
import sim
rows, worst, _ = sim.biome_odds(os.path.join(prop, 'odds_now.json'))
assert worst < 1e-6
def table(d):
    return '{' + ','.join('%s=%.17g' % (t, p) for t, p in sorted(d.items())) + '}'
out = ['return {']
for label in ('now', 'new'):
    out.append(' %s={' % label)
    for stage, name, pack, now, new in rows:
        out.append('  {Stage=%d,Pack="%s",Odds=%s},' % (stage, pack, table(now if label == 'now' else new)))
    out.append(' },')
out.append('}')
open(sys.argv[1] if len(sys.argv) > 1 else 'expected.luau', 'w').write('\n'.join(out) + '\n')
