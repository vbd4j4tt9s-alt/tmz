#!/bin/sh
# R124 previews: sh preview.sh [scratch dir] -> PNGs in docs/proposals/polish_R124/ (approximate renders of the real GUIs).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);DOCS=$HERE/..
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
cp "$HERE/../../../../tools/tests/roblox.luau" "$HERE"/*.luau "$OUT/"
python3 "$HERE/mkbundle.py" "$OUT" >/dev/null
cd "$OUT"
run(){ printf '%s\n' "$1" > pre.luau; cat preview.luau >> pre.luau; /opt/luau/luau pre.luau > "$2.log" 2>&1 || { tail -20 "$2.log"; exit 1; }; grep '^JSON ' "$2.log" | sed 's/^JSON //' > "$2.json"; }
run "MODE='roll'" roll;python3 "$HERE/render_gui.py" roll.json "$DOCS/roll_window.png" 1 70,110,80
run "MODE='phone'" phone;python3 "$HERE/render_gui.py" phone.json "$DOCS/roll_window_phone.png" 1.5 70,110,80
run "MODE='wall';SECONDS=3;DOTS_AT=1.3" wall3;python3 "$HERE/render_gui.py" wall3.json "$DOCS/refresh_wall_3s.png" .6 242,242,242
run "MODE='wall';SECONDS=10;DOTS_AT=0.5" wall10;python3 "$HERE/render_gui.py" wall10.json "$DOCS/refresh_wall_10s.png" .6 242,242,242
run "MODE='gems'" gems;python3 "$HERE/render_gui.py" gems.json "$DOCS/borders_after.png" 3 20,46,35
for st in 1 6 5 7;do run "MODE='notifier';STAGE=$st" note$st;python3 "$HERE/render_gui.py" note$st.json "$OUT/note$st.png" 1.5 96,150,220 380,40,520,170;done
python3 - "$OUT" "$DOCS/biome_titles.png" <<'PY'
import sys
from PIL import Image
out,dst=sys.argv[1],sys.argv[2];ims=[Image.open(f'{out}/note{s}.png') for s in (1,6,5,7)]
w,h=ims[0].size;sheet=Image.new('RGB',(w*2,h*2))
for i,im in enumerate(ims):sheet.paste(im,((i%2)*w,(i//2)*h))
sheet.save(dst);print('wrote',dst)
PY
run "MODE='featured'" feat;python3 "$HERE/render_gui.py" feat.json "$DOCS/featured_logo.png" 3 34,40,52
run "MODE='offline'" off;python3 "$HERE/render_gui.py" off.json "$DOCS/offline_growth.png" 1 40,44,52 0,520,1280,200
