#!/bin/sh
# Index previews: sh run.sh <scratch dir> -> docs/proposals/R137/index_before.png (the committed ChestIndex) and
# index_after.png (the working copy). Approximate: the real ChestIndex GUI under the mock, drawn with Pillow; the
# seed pictures are the real seed models rendered with three.js (seeds_R133/preview). Needs /opt/luau, python3 + Pillow,
# node + playwright (global) + three.js (npm install three@0.169.0 in the scratch dir).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};DOCS=$HERE/..
SP=$REPO/docs/proposals/seeds_R133/preview;INV=$REPO/docs/proposals/inventory_R113/tests
mkdir -p "$S/seeds" "$S/before" "$S/after"
# 1. Seed pictures: the real seed builder (SeedPackVisuals) for the Forest tab.
cp "$REPO/tools/tests/roblox.luau" "$INV/world.luau" "$SP/dump_seeds.luau" "$SP/seeds.html" "$HERE/shoot_seeds.mjs" "$S/seeds/"
python3 "$INV/mkbundle.py" "$S/seeds/rs_bundle.luau" >/dev/null
IDS="SunflowerSeed BluebellSeed AppleSeed MooncapSeed SunflowerBloomSeed ElderbloomSeed"
cd "$S/seeds"
LIST=$(for i in $IDS;do printf "'%s'," "$i";done)
(echo "WHICH='old';ONLY={$LIST};COLS=6";cat dump_seeds.luau)>d.luau;/opt/luau/luau d.luau>forest.out 2>&1;grep '^{' forest.out>forest.json
[ -d node_modules/three ] || npm install three@0.169.0 >/dev/null 2>&1
[ -e node_modules/playwright ] || ln -s "$(npm root -g)/playwright" node_modules/playwright
node shoot_seeds.mjs "$S/seeds" forest.json row.png
python3 "$HERE/cut_seeds.py" row.png "$S/seeds/img" $IDS
# 2. The Index before and after.
C=$REPO/src/StarterPlayer/StarterPlayerScripts
git -C "$REPO" show HEAD:src/StarterPlayer/StarterPlayerScripts/ChestIndex.client.lua > "$S/before/ChestIndexOld.lua"
for which in before after;do
 cp "$REPO/tools/tests/roblox.luau" "$INV/world.luau" "$HERE/dump_gui.luau" "$HERE/index_preview.luau" "$S/$which/"
 if [ $which = before ];then F="$S/before/ChestIndexOld.lua";else F="$C/ChestIndex.client.lua";fi
 python3 "$INV/mkbundle.py" "$S/$which/rs_bundle.luau" ChestIndex="$F" >/dev/null
 (cd "$S/$which" && /opt/luau/luau index_preview.luau > out.log 2>&1 || { tail -20 out.log;exit 1; })
 grep '^JSON ' "$S/$which/out.log" | sed 's/^JSON //' > "$S/$which/gui.json"
 rm -rf "$S/$which/img";cp -r "$S/seeds/img" "$S/$which/img"
 for id in $(grep '^UNKNOWN ' "$S/$which/out.log" | sed 's/^UNKNOWN //');do [ -f "$S/$which/img/${id}_dark.png" ] && cp "$S/$which/img/${id}_dark.png" "$S/$which/img/$id.png";done
 IMGDIR="$S/$which/img" python3 "$HERE/render_index.py" "$S/$which/gui.json" "$DOCS/index_$which.png" 1 18,26,40
done
python3 - "$DOCS" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont
d=sys.argv[1];a,b=Image.open(d+'/index_before.png').convert('RGB'),Image.open(d+'/index_after.png').convert('RGB')
f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',26)
sheet=Image.new('RGB',(a.width+b.width+24,a.height+50),(12,16,28));sheet.paste(a,(0,50));sheet.paste(b,(a.width+24,50))
dr=ImageDraw.Draw(sheet);dr.text((20,12),'NOW',font=f,fill=(230,230,230));dr.text((a.width+44,12),'R137',font=f,fill=(150,255,110))
sheet.save(d+'/index_compare.png');print('wrote index_compare.png')
PY
