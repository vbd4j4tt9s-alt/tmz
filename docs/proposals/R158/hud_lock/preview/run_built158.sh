#!/bin/sh
# Usage: sh run_built158.sh <scratch dir> [out dir, default docs/proposals/R158/hud_lock]      -> <out dir>/built_menu.png and <out dir>/built_scale.png
# R158 BUILT pictures (not a test; src/ is not touched): the PC HUD as the BUILT code draws it - HudLayout's scaled 1920 x 1080 arrangement (the HUD at min(1, w / 1920, h / 720)), MENU a third of
# the way down at max(that scale, 85%) - from this checkout's REAL scripts (Hotbar, GardenWallet, WorldStatusHud, PityBars155, the five-option wheel, TravelButtons) on the Roblox mock:
#  1. built_scene158.luau dumps the GUI trees as JSON (R153's dump_tree153) for the five PC sizes 1920x1080, 1366x768, 1280x720, 1024x768, 800x600, wheel closed and open, with the
#     rectangles of every piece (HudLayout.HudBoxes: real screen px) and the numbers;
#  2. compose_built158.py draws them with headless Chromium (R155's render_gui155.mjs, which knows UIScale and AnchorPoint) and lays out the two sheets.
# Only Roblox's own top bar and the sky are stand-ins. APPROXIMATE: not a Studio screenshot. Needs /opt/luau, python3 + Pillow, node + playwright (global, PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers)
# and, for the fonts, npm (@fontsource/fredoka-one in <scratch>/fonts; without it DejaVu Sans stands in). The sizes are the game area under Roblox's top bar (the picture adds that 52 px bar).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../../.." && pwd)
S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R158/hud_lock}
P=$REPO/docs/proposals
mkdir -p "$S" "$OUT"
if [ ! -d "$S/fonts/node_modules/@fontsource/fredoka-one" ];then
 mkdir -p "$S/fonts";npm install --prefix "$S/fonts" @fontsource/fredoka-one @fontsource/montserrat >/dev/null 2>&1 || echo "no font package: DejaVu Sans stands in"
fi
# one bundle: the real scripts of this checkout
D=$S/v_built;rm -rf "$D";mkdir -p "$D"
cp "$REPO/tools/tests/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/inventory_R113/tests/fixtures.luau" "$P/R153/preview/dump_tree153.luau" "$D/"
python3 "$HERE/mkbundle158.py" "$D" "$REPO/src" >/dev/null
rm -rf "$S/runs";mkdir -p "$S/runs"
for size in 1920x1080 1366x768 1280x720 1024x768 800x600;do
 w=${size%x*};h=${size#*x};R=$S/runs/$size;mkdir -p "$R"
 printf "SW=%s;SH=%s;TB=52;LEFT=140;RIGHT=%s;WHEEL='both';ONLY='all'\n" "$w" "$h" "$w" > "$D/scene_$size.luau"
 cat "$HERE/built_scene158.luau" >> "$D/scene_$size.luau"
 (cd "$D" && /opt/luau/luau "scene_$size.luau" > "$R/scene.log" 2> "$R/scene.err") || { tail -20 "$R/scene.err";exit 1; }
 grep 'LOADFAIL' "$R/scene.log" || true
 grep '^INFO wheelClashes' "$R/scene.log" | sed "s/^/$size: /"
done
# the renderer: R155's, plus R157's fix for a text label's Contextual stroke with no text (Roblox draws it on the text, not as a box)
python3 - "$P/R155/preview/render_gui155.mjs" "$S/render_gui158.mjs" <<'PY'
import sys
s=open(sys.argv[1],encoding='utf-8').read()
old="if(st.mode!=='Border'&&n.text) continue;"
assert s.count(old)==1
open(sys.argv[2],'w',encoding='utf-8').write(s.replace(old,"if(st.mode!=='Border'&&(n.text||n.k==='TextLabel'||n.k==='TextButton')) continue;"))
PY
export PLAYWRIGHT_NODE_ROOT=$(npm root -g);export PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}
python3 -W ignore "$HERE/compose_built158.py" "$S" "$OUT"
