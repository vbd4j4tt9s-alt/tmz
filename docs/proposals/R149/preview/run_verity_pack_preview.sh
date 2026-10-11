#!/bin/sh
# Usage: sh run_verity_pack_preview.sh <scratch dir> [node_modules dir with three@0.169 and playwright] [out dir, default docs/proposals/R149]
# Renders verity_pack.png (the Verity pack BEFORE = the base commit's R148 art, AFTER = this checkout's R149 art, and AFTER in a Gold coat; front, side,
# back, in-hand and hotbar-sized views) and writes the part table of every context to preview/verity_pack_parts.txt.
#  1. dump_verity_pack.luau builds the pack with the REAL SeedPackVisuals / SeedPackRenderer / VerityPackArt on the Roblox mock, once with the base
#     commit's VerityPackArt (VERITY_BASE, default 0b08836 = R148) and once with this checkout's, on the REAL Storm_02 template (one MeshPart,
#     tests/verity_template.luau), and prints the scenes and the part table (class, colour, material, transparency, size, centre, z range, Decals).
#  2. render_verity_pack.mjs draws the scenes with three.js (verity_pack.html, headless Chromium via playwright, swiftshader).
#  3. make_verity_pack_sheet.py composes the sheet (Pillow).
# Needs /opt/luau, python3 + Pillow, node + playwright (global) and three.js (npm install three@0.169.0 in the scratch dir, or pass a node_modules).
# Approximate: plain materials, no Roblox textures / Future lighting. The Verity picture is a STAND-IN smiley (the Roblox image cannot be downloaded
# here); the approved pouch mesh is not available offline, so BEFORE draws it as a rounded pouch with a SIMULATED vertex-colour print.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};OUT=${3:-$REPO/docs/proposals/R149}
BASE=${VERITY_BASE:-0b08836}
mkdir -p "$S/after" "$S/before" "$S/out"
for d in after before; do
 cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/inventory_R113/tests/fixtures.luau" "$REPO/docs/proposals/R149/tests/verity_template.luau" "$HERE/dump_verity_pack.luau" "$S/$d/"
done
git -C "$REPO" show "$BASE:src/ReplicatedStorage/VerityPackArt.lua" > "$S/before/VerityPackArtBase.lua"
python3 "$REPO/docs/proposals/R147/tests/mkbundle_verity.py" "$S/after/rs_bundle.luau" >/dev/null
python3 "$REPO/docs/proposals/R147/tests/mkbundle_verity.py" "$S/before/rs_bundle.luau" VerityPackArt="$S/before/VerityPackArtBase.lua" >/dev/null
for d in before after; do
 (cd "$S/$d" && /opt/luau/luau dump_verity_pack.luau > out.txt && grep '^SCENE' out.txt > scenes.txt && grep '^DIAG' out.txt | sed 's/^DIAG //' > diag.txt)
done
{ echo "R149 Verity pack: every part of the pack in every context it is shown (Roblox mock, the real Storm_02 template: one MeshPart)."
  echo "Positions / z ranges are in the pack's own frame (front is -Z); pack scale 1.12 = the Verity stage-7 theme."
  echo;echo "######## BEFORE: the base commit's art ($BASE, R148)";cat "$S/before/diag.txt"
  echo;echo "######## AFTER: this checkout (R149)";cat "$S/after/diag.txt"; } > "$HERE/verity_pack_parts.txt"
cp "$HERE/verity_pack.html" "$HERE/render_verity_pack.mjs" "$S/"
if [ -n "$2" ]; then [ -e "$S/node_modules" ] || ln -s "$2" "$S/node_modules"
else [ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null); [ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"; fi
for d in before after; do
 PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_verity_pack.mjs" "$S" "$S/$d/scenes.txt" "$S/out" "$d" >/dev/null
done
python3 "$HERE/make_verity_pack_sheet.py" "$S/out" "$OUT/verity_pack.png"
