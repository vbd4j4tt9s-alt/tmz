#!/bin/sh
# Usage: sh run.sh <scratch dir> [render]. Builds every seed with the REAL seed builders on the mock: the game now
# (SeedPackVisuals), the R132 proposal the owner saw (seeds_R132) and this proposal (SeedPackVisuals133 +
# SeedSignatures133 + SeedShapes133); checks every seed for floating parts (check_floating.py); with `render`, draws the
# preview sheets into docs/proposals/seeds_R133/. Needs /opt/luau, python3 + numpy; for render also node + playwright
# (global) and three.js (npm install three@0.169.0). Approximate renders. Mech seeds are separate models, not shown.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir}
mkdir -p "$S";cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE"/* "$S/"
P2=$REPO/docs/proposals/seeds_R132;P3=$HERE/..
python3 "$REPO/docs/proposals/inventory_R113/tests/mkbundle.py" "$S/rs_bundle.luau" \
 SeedPackVisuals132="$P2/SeedPackVisuals132.lua" SeedSignatures132="$P2/SeedSignatures132.lua" SeedShapes132="$P2/SeedShapes132.lua" \
 SeedPackVisuals133="$P3/SeedPackVisuals133.lua" SeedSignatures133="$P3/SeedSignatures133.lua" SeedShapes133="$P3/SeedShapes133.lua" >/dev/null
cd "$S"
dump(){ (echo "$1";cat dump_seeds.luau)>"d_$2.luau";/opt/luau/luau "d_$2.luau" >"$2.out" 2>&1 || { tail -5 "$2.out";exit 1; };grep '^{' "$2.out" >"$2.json";grep '^ERR' "$2.out" || true; }
dump "WHICH='old'" old;dump "WHICH='v2'" v2;dump "WHICH='new'" new
for w in old v2 new;do echo "== floating parts: $w";python3 check_floating.py $w.json || true;done
[ "$2" = render ] || exit 0
CLOSE="ONLY={'DiamondVineSeed','PrismOrchidSeed','AshRoseSeed','IceberrySeed','VenomVineSeed','PrismMonarchSeed'};COLS=6"
dump "WHICH='v2';$CLOSE" close_v2;dump "WHICH='new';$CLOSE" close_new
FX="ONLY={'IceberrySeed','LavaLotusSeed','DiamondVineSeed','BlackoutBloomSeed','SupernovaBloomSeed','PrismMonarchSeed'};COLS=6;GAP=4.6;EFFECTS=true"
for t in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15;do dump "WHICH='new';$FX;AGE=$t*.25+.2" fx_$t;done
[ -d node_modules/three ] || npm install three@0.169.0 >/dev/null
[ -e node_modules/playwright ] || ln -s "$(npm root -g)/playwright" node_modules/playwright
node render_seeds.mjs "$S" "$P3"
python3 - "$S" "$P3" <<'PY'
import sys,glob
from PIL import Image
S,out=sys.argv[1],sys.argv[2]
frames=[Image.open(f).convert('RGB') for f in sorted(glob.glob(S+'/fx/fx_*.png'))]
frames[0].save(out+'/seeds_effects.gif',save_all=True,append_images=frames[1:],duration=140,loop=0)
frames[4].save(out+'/seeds_effects.png')
a,b=Image.open(out+'/seeds_fixes_before.png').convert('RGB'),Image.open(out+'/seeds_fixes_after.png').convert('RGB')
sheet=Image.new('RGB',(a.width,a.height+b.height+8),(10,20,15));sheet.paste(a,(0,0));sheet.paste(b,(0,a.height+8));sheet.save(out+'/seeds_fixes.png')
print('gif',len(frames),'frames')
PY
