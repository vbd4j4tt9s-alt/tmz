"""Triangle counts per keeper (no rendering). KEEPER_DETAIL=0.6 estimates the lighter 'lite' build."""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, proposed

out = {}
for st in proposed.ORDER:
    k = proposed.BUILDERS[st]()
    parts = list(k.parts())
    out[k.key] = {'name': k.name, 'tris': k.tris(), 'on_screen': k.tris_visible(), 'largest_part': max(g.tris() for _, _, _, g in parts),
                  'parts': len(parts)}
    print('%-16s %6d tris on screen, %6d with all face states, %2d mesh parts, largest part %5d' % (
        k.name, k.tris_visible(), k.tris(), len(parts), out[k.key]['largest_part']))
if len(sys.argv) > 1:
    json.dump(out, open(sys.argv[1], 'w'), indent=1)
