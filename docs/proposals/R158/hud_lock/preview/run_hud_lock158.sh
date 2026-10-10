#!/bin/sh
# Usage: sh run_hud_lock158.sh <scratch dir> [out dir, default docs/proposals/R158/hud_lock]      -> <out dir>/menu_higher.png and <out dir>/pc_scale.png
# R158 PREVIEW (not a release; src/ is not touched). The owner's PC HUD (docs/proposals/R158/hud_lock/hud_lock.md), drawn from this checkout's REAL scripts:
#  1. make_variants158.py writes two patched copies of HudLayout.lua into <scratch>/variant: A (MENU's centre 1/3 down) and B (the open wheel's top at the HUD's top margin);
#  2. hud_scene158.luau runs the REAL Hotbar, GardenWallet, WorldStatusHud, PityBars155, the wheel (HudLayout.Navigation + SettingsClient / ChestIndex / GamePassClient /
#     DailyRewardsClient) and TravelButtons on the Roblox mock, in the numbers of the owner's screenshot, and dumps the GUI trees as JSON (R153's dump_tree153):
#       - "cur" (this checkout's HudLayout), "A" and "B", at the real PC sizes 1920x1080, 1366x768, 1280x720, 1024x768, 800x600, wheel open  -> menu_higher.png;
#       - "scale": the "scale, don't rearrange" idea: the HUD is laid out as a window of (width / s) x (height / s) px - 1920 wide or more, 720 tall or more, so the layout of
#         the screenshot - with A's MENU height, and drawn shrunk by s = min(1, width / 1920, height / 720). Roblox's own top bar (and BASE / TRACK) stays its true size
#         -> pc_scale.png. (A 4:3 window gets a taller 1920 px wide HUD; a 16:9 one is laid out as 1920 x 1080.);
#  3. compose_hud_lock158.py draws them with headless Chromium (R155's render_gui155.mjs) and lays out the two sheets.
# Only Roblox's own top bar and the sky are stand-ins. APPROXIMATE: not a Studio screenshot. Needs /opt/luau, python3 + Pillow, node + playwright (global,
# PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and, for the fonts, npm (@fontsource/fredoka-one and @fontsource/montserrat in <scratch>/fonts; without them DejaVu Sans stands in).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../../.." && pwd)
S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R158/hud_lock}
P=$REPO/docs/proposals
mkdir -p "$S" "$OUT"
if [ ! -d "$S/fonts/node_modules/@fontsource/fredoka-one" ];then
 mkdir -p "$S/fonts";npm install --prefix "$S/fonts" @fontsource/fredoka-one @fontsource/montserrat >/dev/null 2>&1 || echo "no font package: DejaVu Sans stands in"
fi
python3 "$HERE/make_variants158.py" "$REPO/src" "$S/variant"
# one bundle per layout (the real scripts of this checkout; A and B swap in their HudLayout)
for v in cur A B;do
 D=$S/v_$v;rm -rf "$D";mkdir -p "$D"
 cp "$REPO/tools/tests/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/inventory_R113/tests/fixtures.luau" "$P/R153/preview/dump_tree153.luau" "$D/"
 if [ "$v" = cur ];then python3 "$HERE/mkbundle158.py" "$D" "$REPO/src" >/dev/null
 else python3 "$HERE/mkbundle158.py" "$D" "$REPO/src" HudLayout="$S/variant/HudLayout_$v.lua" >/dev/null;fi
done
rm -rf "$S/runs";mkdir -p "$S/runs"
# the layout numbers on more PC sizes (today / A / B; no pictures): <scratch>/sweep.tsv
for v in cur A B;do
 printf "LABEL='%s'\n" "$v" > "$S/v_$v/sweep_$v.luau";cat "$HERE/sweep_menu158.luau" >> "$S/v_$v/sweep_$v.luau"
 (cd "$S/v_$v" && /opt/luau/luau "sweep_$v.luau") > "$S/sweep_$v.tsv"
done
(head -n 1 "$S/sweep_cur.tsv";for v in cur A B;do tail -n +2 "$S/sweep_$v.tsv";done) > "$S/sweep.tsv"
# run <variant> <run name> <HUD width> <HUD height> <wheel: open | closed | both> <scenes: all,hud,top>
run(){
 D=$S/v_$1;R=$S/runs/$2;mkdir -p "$R"
 printf "SW=%s;SH=%s;TB=52;LEFT=140;RIGHT=%s;WHEEL='%s';ONLY='%s'\n" "$3" "$4" "$3" "$5" "$6" > "$D/scene_$2.luau"
 cat "$HERE/hud_scene158.luau" >> "$D/scene_$2.luau"
 (cd "$D" && /opt/luau/luau "scene_$2.luau" > "$R/scene.log" 2> "$R/scene.err") || { tail -20 "$R/scene.err";exit 1; }
 grep 'LOADFAIL' "$R/scene.log" || true
 grep '^INFO wheelClashes' "$R/scene.log" | sed "s/^/$2: /"
}
for size in 1920x1080 1366x768 1280x720 1024x768 800x600;do
 w=${size%x*};h=${size#*x}
 run cur "cur_$size" "$w" "$h" open all
 run B "B_$size" "$w" "$h" open all
 # (A also gives the true-size top bar row of the scale picture; at 1920 x 1080 also the closed wheel: the screenshot's picture)
 if [ "$size" = 1920x1080 ];then run A "A_$size" "$w" "$h" both all,top;else run A "A_$size" "$w" "$h" open all,top;fi
done
# the scale picture: the HUD laid out at (w / s) x (h / s) with A's MENU height, s = min(1, w / 1920, h / 720)
for size in 1920x1080 1366x768 1280x720 800x600;do
 w=${size%x*};h=${size#*x}
 set -- $(awk -v w="$w" -v h="$h" 'BEGIN{s=w/1920;t=h/720;if(t<s)s=t;if(s>1)s=1;printf "%d %d",int(w/s+.999999),int(h/s+.999999)}')
 run A "scale_$size" "$1" "$2" open hud
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
python3 -W ignore "$HERE/compose_hud_lock158.py" "$S" "$OUT"
