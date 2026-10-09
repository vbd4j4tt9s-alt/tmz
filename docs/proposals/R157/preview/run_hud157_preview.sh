#!/bin/sh
# Usage: sh run_hud157_preview.sh <scratch dir> [out png, default docs/proposals/R157/hud157.png]
# R157 preview of what was BUILT (docs/proposals/R157/hud157.md): the R156 preview scripts, unchanged, run on this branch's REAL src/ (no patch, no patched copies: the
# change is in src/ now), then one sheet:
#  1. the pity bars: R156's pity_scene156.luau (MODE 'fresh': the one shade left; the scene's Pity.Use line is dropped, src has no second shade to pick), PC / landscape / portrait;
#  2. the reveal: R156's reveal_frames156.luau on R155's preview_cinematic155.luau (a Common card waiting with its hint, a story scene with its SKIP pill: Cosmic on the PC, King on
#     the landscape phone, Secret on the portrait phone), drawn by render_cinematic155.mjs (three.js) and R152's patched render_gui.mjs, as run_reveal_fixes_preview.sh does;
#  3. the menu wheel: R156's menu_wheel_scene156.luau (closed with a daily reward waiting, open with the Index's rewards too), PC / landscape / portrait;
#  4. compose_hud157.py draws the GUI scenes (render_gui155.mjs) and lays out the sheet.
# The hotbar slots, balances, status card, MENU (in the bars and reveal scenes), jump / stick, BONUS ROLL and Roblox's own top bar are STAND-INS placed by HudLayout's metrics; the
# world is a stand-in garden. APPROXIMATE: not a Studio screenshot. Needs /opt/luau, python3 + Pillow, node + playwright (global, PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and npm
# (three@0.169.0 and the @fontsource fonts, installed in the scratch dir; without the fonts DejaVu Sans stands in).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R157/hud157.png}
P=$REPO/docs/proposals;R156=$P/R156/preview;INV=$P/inventory_R113/tests;R152=$P/R152/preview;R154=$P/R154/preview;R155=$P/R155/preview
mkdir -p "$S"
if [ ! -d "$S/fonts/node_modules/@fontsource/fredoka-one" ];then
 mkdir -p "$S/fonts";npm install --prefix "$S/fonts" @fontsource/fredoka-one @fontsource/montserrat >/dev/null 2>&1 || echo "no font package: DejaVu Sans stands in"
fi
python3 -I "$R156/decode_clover156.py" "$REPO/src/ReplicatedStorage/CloverPassImage153.lua" "$S/clover.png"
# 1. the bars
for view in pc land port;do
 D=$S/pity/$view;rm -rf "$D";mkdir -p "$D"
 cp "$REPO/tools/tests/roblox.luau" "$P/treadmill_bonus_R123/tests/world.luau" "$P/R153/preview/dump_tree153.luau" "$D/"
 python3 "$P/R150/tests/mkbundle.py" "$D" >/dev/null
 printf "VIEW='%s'\nMODE='fresh'\n" "$view" > "$D/scenes.luau"
 grep -v "^if MODE=='deep'then Pity.Use" "$R156/pity_scene156.luau" >> "$D/scenes.luau"
 (cd "$D" && /opt/luau/luau scenes.luau > scenes.log 2>&1) || { tail -20 "$D/scenes.log";exit 1; }
 grep '^PLACE\|^CHECK' "$D/scenes.log" || true
done
# 2. the wheel
for view in pc land port;do
 D=$S/wheel/$view;rm -rf "$D";mkdir -p "$D"
 cp "$REPO/tools/tests/roblox.luau" "$INV/world.luau" "$P/R153/preview/dump_tree153.luau" "$D/"
 python3 "$R156/mkbundle_menu156.py" "$D" "$REPO/src" >/dev/null
 printf "VIEW='%s'\n" "$view" > "$D/scene.luau";cat "$R156/menu_wheel_scene156.luau" >> "$D/scene.luau"
 (cd "$D" && /opt/luau/luau scene.luau > scene.log 2> scene.err) || { tail -20 "$D/scene.err";exit 1; }
 grep 'LOADFAIL\|wheelClashes\|dailyInWheel\|tapDaily\|tapInvite' "$D/scene.log" || true
done
# 3. the reveal
C=$S/rev/cl;mkdir -p "$C" "$S/art"
cp "$REPO/tools/tests/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$P/R151/tests/rare_env.luau" \
 "$P/R150/preview/dump_tree.luau" "$R152/dump_tree152.luau" "$R152/dump_art.luau" "$R155/preview_cinematic155.luau" "$R156/reveal_frames156.luau" "$R156/check_fit156.luau" "$C/"
python3 "$P/R151/tests/mkbundle_rare.py" "$C" all-client >/dev/null
(cd "$C" && /opt/luau/luau check_fit156.luau | tail -1)
if [ ! -f "$S/art/runes.png" ];then
 (cd "$C" && timeout 900 /opt/luau/luau dump_art.luau > art.txt)
 python3 "$R152/art_to_png.py" "$C/art.txt" "$S/art" >/dev/null
fi
# (two renderer gaps the R156 sheets had, closed here in the scratch copies only: the renderer does not know CanvasGroup.GroupTransparency, so a group faded out - the pity
# bars' clover under a reveal card - is dumped hidden; and it drew a TextLabel's Contextual UIStroke as a box when the label had no text - Roblox puts it on the text)
cat > "$C/group_fade157.luau" <<'LUA'
do local inner=dumpTree
 dumpTree=function(root,w,h)
  local hidden={}
  for _,o in ipairs(root:GetDescendants())do if o._class=='CanvasGroup'and(o._props.GroupTransparency or 0)>=.99 and o._props.Visible~=false then hidden[#hidden+1]=o;o._props.Visible=false end end
  local out=inner(root,w,h)
  for _,o in ipairs(hidden)do o._props.Visible=true end
  return out
 end
end
LUA
for view in pc land port;do
 (cd "$C" && { printf "SET='fixes156'\nVIEW='%s'\nWAIT=1\nONLY156={common=true,scene=true}\n" "$view";cat preview_cinematic155.luau group_fade157.luau reveal_frames156.luau; } > "set_$view.luau" \
  && timeout 3000 /opt/luau/luau "set_$view.luau" > "frames_$view.txt" 2> "set_$view.err") || { tail -30 "$C/set_$view.err";exit 1; }
 echo "reveal $view: $(grep -c '^FRAME' "$C/frames_$view.txt") frames; $(grep '^PILLBUTTON' "$C/frames_$view.txt" | tr '\n' ' ')"
done
if [ ! -d "$S/node_modules/three" ];then npm install --prefix "$S" three@0.169.0 @fontsource/montserrat @fontsource/sarpanch @fontsource/michroma @fontsource/grenze-gotisch @fontsource/fredoka-one @fontsource/luckiest-guy >/dev/null;fi
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright" 2>/dev/null || true
cp "$R154/cinematic.html" "$R155/render_cinematic155.mjs" "$S/"
awk "/^python3 - .*<<'PY'/{f=1;next} /^PY\$/{f=0} f" "$R152/run_seed_opening_preview.sh" > "$S/patch_gui152.py"
python3 "$S/patch_gui152.py" "$P/R150/preview/render_gui.mjs" "$S/render_gui152.mjs" "$S/node_modules/@fontsource" "$S/art"
python3 - "$S/render_gui152.mjs" <<'PY'
import sys
p=sys.argv[1];s=open(p,encoding='utf-8').read()
old="if(st.mode!=='Border'&&n.text) continue;"
assert s.count(old)==1
open(p,'w',encoding='utf-8').write(s.replace(old,"if(st.mode!=='Border'&&(n.text||n.k==='TextLabel'||n.k==='TextButton')) continue;"))
PY
export PLAYWRIGHT_NODE_ROOT=$(npm root -g);export PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}
for view in pc land port;do
 FORCE=1 node "$S/render_cinematic155.mjs" "$S" "$C/frames_$view.txt" "$S/out/$view" >/dev/null
 node "$S/render_gui152.mjs" "$S/out/$view/gui_scenes.json" "$S/out/$view" "$S/node_modules/@fontsource/montserrat/files" >/dev/null
 echo "rendered the reveal, $view"
done
# 4. the sheet
python3 -W ignore "$HERE/compose_hud157.py" "$S" "$OUT"
