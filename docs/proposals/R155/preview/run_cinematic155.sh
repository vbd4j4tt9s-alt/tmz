#!/bin/sh
# Usage: sh run_cinematic155.sh <scratch dir> [node_modules dir with three@0.169.0 and the @fontsource fonts below]
#   env: SETS (default "secret cosmic king board"), FPS (25), WAIT (seconds on the hero shot before the click, 3), ONLY (a Luau list of clock
#        times, for a quick look: then a check sheet <scratch>/check_<set>.png instead of the video), NOCOMPOSE=1
# R155 previews (docs/proposals/R155/cinematic_camera.md), drawn from the REAL implementation: the camera, its dutch tilt, its lens and its depth
# of field are read off the game's Camera every frame (RarePullCinematic driving RarePullCamera155), not computed by the preview.
#   cinematic_secret.mp4, cinematic_cosmic.mp4, cinematic_king.mp4   the whole scene, a few seconds of the result waiting on the hero shot, the
#                                                                    click, the fade, the world (as before) and the seed's flight to its hotbar slot
#   cinematic_storyboard.png                                         keyframes per tier; the SKIP button; phone / low quality; Reduced Motion; an onlooker
#  1. dump_art.luau (R152) draws the RarePullArt images with the real pattern code; art_to_png.py (R152) writes the PNGs.
#  2. preview_cinematic155.luau plays the REAL reveals on the Roblox mock (R151's test environment, the real Hotbar) and prints every frame.
#  3. render_cinematic155.mjs draws them with three.js (R154's cinematic.html: the dutch tilt, the depth of field as a bokeh pass, the stand-in
#     garden; headless Chromium via playwright, swiftshader); R150's render_gui.mjs, patched as in R152, draws the GUI (letterbox, fades, title,
#     "1 in N", the "click to collect!" hint, the hotbar).
#  4. compose155.py composes the layers, adds the caption and the beat ruler and encodes with ffmpeg; it lays out the storyboard.
# Needs /opt/luau, python3 + Pillow, ffmpeg, node + playwright (global; PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and three.js + the fonts (npm, or
# THREE_MODULES / the 2nd argument).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};NM=${2:-$THREE_MODULES};SETS=${SETS:-secret cosmic king board};FPS=${FPS:-25};WAIT=${WAIT:-3}
P=$REPO/docs/proposals;INV=$P/inventory_R113/tests;R152=$P/R152/preview;R154=$P/R154/preview;OUT=$P/R155
mkdir -p "$S/cl" "$S/art"
cp "$REPO/tools/tests/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$P/R151/tests/rare_env.luau" \
 "$P/R150/preview/dump_tree.luau" "$R152/dump_tree152.luau" "$R152/dump_art.luau" "$HERE/preview_cinematic155.luau" "$S/cl/"
python3 "$P/R151/tests/mkbundle_rare.py" "$S/cl" all-client >/dev/null
# 1. the images (once)
if [ ! -f "$S/art/runes.png" ];then
 (cd "$S/cl" && timeout 900 /opt/luau/luau dump_art.luau > art.txt)
 python3 "$R152/art_to_png.py" "$S/cl/art.txt" "$S/art" >/dev/null
fi
# 2. the frames
for set in $SETS;do
 (cd "$S/cl" && { printf "SET='%s'\nFPS=%s\nWAIT=%s\n" "$set" "$FPS" "$WAIT";[ -n "$ONLY" ] && printf "ONLY=%s\n" "$ONLY";cat preview_cinematic155.luau; } > "set_$set.luau" \
  && timeout 3600 /opt/luau/luau "set_$set.luau" > "frames_$set.txt" 2> "set_$set.err") || { tail -20 "$S/cl/set_$set.err";exit 1; }
 echo "$set: $(grep -c '^FRAME' "$S/cl/frames_$set.txt") frames"
done
# 3. render
if [ -n "$NM" ];then ln -sfn "$NM" "$S/node_modules"
else [ -d "$S/node_modules/three" ] || npm install --prefix "$S" three@0.169.0 @fontsource/montserrat @fontsource/sarpanch @fontsource/michroma @fontsource/grenze-gotisch @fontsource/fredoka-one @fontsource/luckiest-guy >/dev/null;fi
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright" 2>/dev/null || true
cp "$R154/cinematic.html" "$HERE/render_cinematic155.mjs" "$S/"
# R150's GUI renderer with the tier fonts, text gradients and the client-drawn images: the patch R152's run_seed_opening_preview.sh applies
awk "/^python3 - .*<<'PY'/{f=1;next} /^PY\$/{f=0} f" "$R152/run_seed_opening_preview.sh" > "$S/patch_gui152.py"
python3 "$S/patch_gui152.py" "$P/R150/preview/render_gui.mjs" "$S/render_gui152.mjs" "$S/node_modules/@fontsource" "$S/art"
export PLAYWRIGHT_NODE_ROOT=$(npm root -g);export PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}
for set in $SETS;do
 FORCE=1 node "$S/render_cinematic155.mjs" "$S" "$S/cl/frames_$set.txt" "$S/out_$set" >/dev/null
 node "$S/render_gui152.mjs" "$S/out_$set/gui_scenes.json" "$S/out_$set" "$S/node_modules/@fontsource/montserrat/files" >/dev/null
 echo "rendered $set"
done
[ -n "$NOCOMPOSE" ] && exit 0
# 4. compose
for set in $SETS;do
 if [ -n "$ONLY" ];then python3 "$HERE/compose155.py" check "$S/out_$set" "$S/check_$set.png" 3;echo "check sheet: $S/check_$set.png";continue;fi
 case $set in
  secret|cosmic|king) python3 "$HERE/compose155.py" video "$S/out_$set" "$OUT/cinematic_$set.mp4" "$S/frames_$set";;
  board) python3 "$HERE/compose155.py" board "$S/out_board" "$OUT/cinematic_storyboard.png";;
 esac
done
