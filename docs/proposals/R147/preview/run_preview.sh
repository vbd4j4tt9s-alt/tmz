#!/bin/sh
# Usage: sh run_preview.sh <scratch dir> [out dir, default docs/proposals/R148]. Renders verity_plant.png (seed, 33%, 66%, 100%), verity_growth.png and
# verity_coats.png: dump_verity.luau builds the seed and the plant with the REAL modules on the Roblox mock and prints the parts;
# render_verity.mjs draws them with three.js (headless Chromium via playwright, swiftshader) and make_sheet.py (Pillow) composes the
# sheets. Needs /opt/luau, python3 + Pillow, node + playwright (global) and `npm install three@0.169.0` (done here). Approximate:
# boxes / wedges / balls with plain materials, no Roblox textures or Future lighting.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir}
mkdir -p "$S/out"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE/dump_verity.luau" "$HERE/verity.html" "$HERE/render_verity.mjs" "$S/"
python3 "$REPO/docs/proposals/R147/tests/mkbundle_verity.py" "$S/rs_bundle.luau" >/dev/null
/opt/luau/luau "$S/dump_verity.luau" > "$S/scenes.txt"
[ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null)
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_verity.mjs" "$S" "$S/out" >/dev/null
OUT=${2:-$REPO/docs/proposals/R148};mkdir -p "$OUT"
python3 "$HERE/make_sheet.py" "$S/out" "$OUT"
