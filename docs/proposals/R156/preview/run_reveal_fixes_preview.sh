#!/bin/sh
# Usage: sh run_reveal_fixes_preview.sh <scratch dir> [out png, default docs/proposals/R156/reveal_fixes.png]
#   env: VIEWS (default "pc land port own1 own2"), TREES (default "before after"), NOCOMPOSE=1, ONLY156 (a Luau table of the drives to run, e.g. "{common=true}")
# R156 PREVIEW (docs/proposals/R156/reveal_fixes.md): the pack-opening reveal's fixes, BEFORE (this checkout: R155 as released) and AFTER (the same tree with reveal_fixes.patch
# applied in the scratch dir: src/ here is NOT changed), drawn from the REAL GUI trees. Not a release; the owner approves first.
#  1. the two trees are bundled for the Roblox mock (R151's mkbundle_rare.py); R152's dump_art.luau draws the client images once.
#  2. reveal_frames156.luau, appended to R155's preview_cinematic155.luau (SET='fixes156', VIEW), plays REAL openings at one screen size on each tree (the real RarePullCinematic /
#     RarePullCard, the real hotbar, pity bars and BASE / TRACK; stand-ins for the rest of the HUD) and prints every moment as a FRAME line, plus GUIDE / PILL / FIT numbers.
#  3. render_cinematic155.mjs draws the world / stage and the card's seed viewport with three.js (headless Chromium, swiftshader); R152's patched copy of R150's render_gui.mjs
#     draws the GUI.
#  4. compose_reveal_fixes156.py lays out the sheet. (check_fit156.luau runs on the AFTER tree first: the fit on 19 screen sizes.)
# Needs /opt/luau, python3 + Pillow, node + playwright (global; PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers), npm (three@0.169.0 and the @fontsource fonts, installed in the scratch dir) and
# patch. APPROXIMATE: not a Studio screenshot.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R156/reveal_fixes.png}
VIEWS=${VIEWS:-"pc land port own1 own2"};TREES=${TREES:-"before after"}
P=$REPO/docs/proposals;INV=$P/inventory_R113/tests;R152=$P/R152/preview;R154=$P/R154/preview;R155=$P/R155/preview
mkdir -p "$S/before/cl" "$S/after/cl" "$S/art"
env_files() { cp "$REPO/tools/tests/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$P/R151/tests/rare_env.luau" \
 "$P/R150/preview/dump_tree.luau" "$R152/dump_tree152.luau" "$R152/dump_art.luau" "$R155/preview_cinematic155.luau" "$HERE/reveal_frames156.luau" "$1/"; }
# 1. the trees: BEFORE is this checkout; AFTER is a scratch copy of its src with the patch applied
env_files "$S/before/cl"
python3 "$P/R151/tests/mkbundle_rare.py" "$S/before/cl" all-client >/dev/null
rm -rf "$S/after/tree";mkdir -p "$S/after/tree/docs/proposals/R151/tests"
cp -r "$REPO/src" "$S/after/tree/src";cp "$P/R151/tests/mkbundle_rare.py" "$S/after/tree/docs/proposals/R151/tests/"
(cd "$S/after/tree" && patch -p1 -s < "$HERE/reveal_fixes.patch")
env_files "$S/after/cl"
python3 "$S/after/tree/docs/proposals/R151/tests/mkbundle_rare.py" "$S/after/cl" all-client >/dev/null
# the fit holds on 19 screen sizes x every rank (check_fit156.luau: the band, the rows in order, nothing outside it)
cp "$HERE/check_fit156.luau" "$S/after/cl/";(cd "$S/after/cl" && /opt/luau/luau check_fit156.luau | tail -1)
# the client images (once; RarePullArt is the same in both trees)
if [ ! -f "$S/art/runes.png" ];then
 (cd "$S/before/cl" && timeout 900 /opt/luau/luau dump_art.luau > art.txt)
 python3 "$R152/art_to_png.py" "$S/before/cl/art.txt" "$S/art" >/dev/null
fi
# 2. the frames
for tree in $TREES;do for view in $VIEWS;do
 (cd "$S/$tree/cl" && { printf "SET='fixes156'\nVIEW='%s'\nWAIT=1\n" "$view";[ -n "$ONLY156" ] && printf "ONLY156=%s\n" "$ONLY156";cat preview_cinematic155.luau reveal_frames156.luau; } > "set_$view.luau" \
  && timeout 3000 /opt/luau/luau "set_$view.luau" > "frames_$view.txt" 2> "set_$view.err") || { tail -30 "$S/$tree/cl/set_$view.err";exit 1; }
 echo "$tree $view: $(grep -c '^FRAME' "$S/$tree/cl/frames_$view.txt") frames"
done;done
# 3. render
if [ ! -d "$S/node_modules/three" ];then npm install --prefix "$S" three@0.169.0 @fontsource/montserrat @fontsource/sarpanch @fontsource/michroma @fontsource/grenze-gotisch @fontsource/fredoka-one @fontsource/luckiest-guy >/dev/null;fi
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright" 2>/dev/null || true
cp "$R154/cinematic.html" "$R155/render_cinematic155.mjs" "$S/"
# R150's GUI renderer with the tier fonts, text gradients and the client-drawn images: the patch R152's run_seed_opening_preview.sh applies
awk "/^python3 - .*<<'PY'/{f=1;next} /^PY\$/{f=0} f" "$R152/run_seed_opening_preview.sh" > "$S/patch_gui152.py"
python3 "$S/patch_gui152.py" "$P/R150/preview/render_gui.mjs" "$S/render_gui152.mjs" "$S/node_modules/@fontsource" "$S/art"
export PLAYWRIGHT_NODE_ROOT=$(npm root -g);export PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}
for tree in $TREES;do for view in $VIEWS;do
 FORCE=1 node "$S/render_cinematic155.mjs" "$S" "$S/$tree/cl/frames_$view.txt" "$S/out/$tree/$view" >/dev/null
 node "$S/render_gui152.mjs" "$S/out/$tree/$view/gui_scenes.json" "$S/out/$tree/$view" "$S/node_modules/@fontsource/montserrat/files" >/dev/null
 echo "rendered $tree $view"
done;done
[ -n "$NOCOMPOSE" ] && exit 0
# 4. compose
python3 "$HERE/compose_reveal_fixes156.py" "$S" "$OUT"
