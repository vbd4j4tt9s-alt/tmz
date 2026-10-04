#!/bin/sh
# Usage: sh port_fruit_models.sh [scratch dir]   (needs /opt/luau/luau and python3)
# Regenerates the seven redesigned fruit in the art modules from FruitDesigns149.luau, reading the modules from the BASE commit
# (PORT_BASE, default 38b1afa = the R149 proposal commit, the last commit before the port) and writing the edited ones into this
# checkout's src/. Idempotent: the result does not depend on what src/ holds now.
#   TreeReworkData2 (Apple), TreeReworkData4 (Elderbloom's apple), ApprovedPlantArt6 (Prickly Pear, both designs),
#   PlantArtForest (Watermelon, Blueberry), PlantArtSnow (Snow Melon, Iceberry), PlantArtLava (Ember Pumpkin).
# Lantern Fern, Amethyst Grape and the Ash Tomato's look are not touched; the Ash Tomato gains three variations of its current art
# (gen_ash_tomato_variants.luau: ApprovedPlantArt5 keeps its design byte for byte and gets designs 2-4).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
BASE=${PORT_BASE:-38b1afa}
S=${1:-$(mktemp -d)};mkdir -p "$S/base"
git -C "$REPO" archive "$BASE" src | tar -x -C "$S/base"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE/port_fruit_models.luau" "$HERE/gen_ash_tomato_variants.luau" "$S/"
# bundle the BASE commit's ReplicatedStorage (mkbundle_verity.py would bundle this checkout) plus the design module
python3 - "$S" "$HERE/FruitDesigns149.luau" <<'EOF'
import sys, os
s, design = sys.argv[1], sys.argv[2]
src = os.path.join(s, 'base', 'src', 'ReplicatedStorage')
pairs = [(f[:-4], os.path.join(src, f)) for f in sorted(os.listdir(src)) if f.endswith('.lua')] + [('FruitDesigns149', design)]
parts = ['return {']
for name, path in pairs:
    t = open(path, 'rb').read().decode('utf-8')
    level = 1
    while (']' + '=' * level + ']') in t: level += 1
    eq = '=' * level
    parts.append('["%s"]=[%s[\n%s]%s],' % (name, eq, t, eq))
parts.append('}')
open(os.path.join(s, 'rs_bundle.luau'), 'w', encoding='utf-8').write('\n'.join(parts))
EOF
(cd "$S" && /opt/luau/luau port_fruit_models.luau > plan.txt)
grep -c '^PLAN' "$S/plan.txt"
python3 "$HERE/port_fruit_models.py" "$S/plan.txt" "$S/base/src" "$REPO/src"
(cd "$S" && /opt/luau/luau gen_ash_tomato_variants.luau > variants.txt)
python3 "$HERE/gen_ash_tomato_variants.py" "$S/variants.txt" "$S/base/src" "$REPO/src"
