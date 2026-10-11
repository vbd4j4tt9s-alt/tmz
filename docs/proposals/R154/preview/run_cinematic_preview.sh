#!/bin/sh
# Usage: sh run_cinematic_preview.sh <scratch dir> [node_modules dir with three@0.169.0 and the @fontsource fonts below]
#   env: SETS (default "secret cosmic king today board"), FPS (default 25), ONLY (a Luau list of clock times, for a quick look), NOCOMPOSE=1
# R154 previews (docs/proposals/R154/cinematic_camera.md): the proposed cinematic camera on today's Secret / Cosmic / King scenes.
#   cinematic_secret.mp4 / .gif, cinematic_cosmic.*, cinematic_king.*   the whole scene, 640x360, 25 fps, through the proposed camera
#   cinematic_king_compare.mp4                                          today's camera | the proposed camera, side by side, same clock
#   cinematic_storyboard.png                                            keyframes per tier with labels; phones / tablet; Reduced Motion; onlookers
#  1. dump_art.luau (R152) draws the RarePullArt images with the real pattern code; art_to_png.py (R152) writes the PNGs.
#  2. preview_cinematic154.luau plays the REAL reveals on the Roblox mock (R151's test environment) and prints every frame through the
#     proposed camera (cinecam154.luau); SET=today prints today's camera.
#  3. render_cinematic154.mjs draws them with three.js (cinematic.html: R152's page plus the dutch tilt, depth of field and stand-in garden
#     props; headless Chromium via playwright, swiftshader); R150's render_gui.mjs, patched as in R152 (tier fonts, text gradients, images),
#     draws the GUI (letterbox, fades, title, "1 in N", skip hint).
#  check_camera154.luau prints the comfort / sync / framing numbers of the design doc.
#  4. compose154.py composes the layers, adds the caption and the beat ruler, encodes with ffmpeg and lays out the storyboard.
# Needs /opt/luau, python3 + Pillow, ffmpeg, node + playwright (global; PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and three.js + the fonts
# (npm, or THREE_MODULES / the 2nd argument).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};NM=${2:-$THREE_MODULES};SETS=${SETS:-secret cosmic king today board};FPS=${FPS:-25}
P=$REPO/docs/proposals;INV=$P/inventory_R113/tests;R152=$P/R152/preview;OUT=$P/R154
mkdir -p "$S/cl" "$S/art"
cp "$REPO/tools/tests/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$P/R151/tests/rare_env.luau" \
 "$P/R150/preview/dump_tree.luau" "$R152/dump_tree152.luau" "$R152/dump_art.luau" "$HERE/cinecam154.luau" "$HERE/preview_cinematic154.luau" "$HERE/check_camera154.luau" "$S/cl/"
python3 "$P/R151/tests/mkbundle_rare.py" "$S/cl" all-client >/dev/null
# 1. the images (once)
if [ ! -f "$S/art/runes.png" ];then
 (cd "$S/cl" && timeout 900 /opt/luau/luau dump_art.luau > art.txt)
 python3 "$R152/art_to_png.py" "$S/cl/art.txt" "$S/art" >/dev/null
fi
# the numbers the design doc quotes (comfort, cuts on sounds, framing, skip): $S/check_camera.txt
(cd "$S/cl" && timeout 600 /opt/luau/luau check_camera154.luau > "$S/check_camera.txt") && cat "$S/check_camera.txt"
# 2. the frames
for set in $SETS;do
 (cd "$S/cl" && { printf "SET='%s'\nFPS=%s\n" "$set" "$FPS";[ -n "$ONLY" ] && printf "ONLY=%s\n" "$ONLY";cat preview_cinematic154.luau; } > "set_$set.luau" \
  && timeout 3600 /opt/luau/luau "set_$set.luau" > "frames_$set.txt" 2> "set_$set.err") || { tail -20 "$S/cl/set_$set.err";exit 1; }
 echo "$set: $(grep -c '^FRAME' "$S/cl/frames_$set.txt") frames"
done
# 3. render
if [ -n "$NM" ];then ln -sfn "$NM" "$S/node_modules"
else [ -d "$S/node_modules/three" ] || npm install --prefix "$S" three@0.169.0 @fontsource/montserrat @fontsource/sarpanch @fontsource/michroma @fontsource/grenze-gotisch @fontsource/fredoka-one @fontsource/luckiest-guy >/dev/null;fi
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright" 2>/dev/null || true
cp "$HERE/cinematic.html" "$HERE/render_cinematic154.mjs" "$S/"
# R150's GUI renderer with the tier fonts, text gradients and the client-drawn images: the patch R152's run_seed_opening_preview.sh applies
awk "/^python3 - .*<<'PY'/{f=1;next} /^PY\$/{f=0} f" "$R152/run_seed_opening_preview.sh" > "$S/patch_gui152.py"
python3 "$S/patch_gui152.py" "$P/R150/preview/render_gui.mjs" "$S/render_gui152.mjs" "$S/node_modules/@fontsource" "$S/art"
export PLAYWRIGHT_NODE_ROOT=$(npm root -g);export PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}
for set in $SETS;do
 node "$S/render_cinematic154.mjs" "$S" "$S/cl/frames_$set.txt" "$S/out_$set" >/dev/null
 node "$S/render_gui152.mjs" "$S/out_$set/gui_scenes.json" "$S/out_$set" "$S/node_modules/@fontsource/montserrat/files" >/dev/null
 echo "rendered $set"
done
[ -n "$NOCOMPOSE" ] && exit 0
# 4. compose
for set in $SETS;do
 case $set in
  secret|cosmic|king) python3 "$HERE/compose154.py" video "$S/out_$set" "$OUT/cinematic_$set" "$S/frames_$set";;
  today) python3 "$HERE/compose154.py" compare "$S/out_today" "$OUT/cinematic_king_compare" "$S/frames_compare" "$S/out_king";;
  board) python3 "$HERE/compose154.py" board "$S/out_board" "$OUT/cinematic_storyboard.png";;
 esac
done
