#!/bin/sh
# Usage: sh run_pack_preview.sh <scratch dir>. Renders docs/proposals/R147/verity_pack.png (the Void pack and the Verity pack side by side):
# dump_pack.luau builds both with the REAL modules on the Roblox mock and prints the parts; render_pack.mjs draws them with three.js
# (headless Chromium via playwright, swiftshader) and make_pack_sheet.py (Pillow) composes the sheet. Needs /opt/luau, python3 + Pillow,
# node + playwright (global) and `npm install three@0.169.0` (done here). Approximate: plain materials, a stand-in pouch body (the approved
# mesh is not available offline), no particles / light / Roblox lighting.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir}
mkdir -p "$S/out"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/inventory_R113/tests/fixtures.luau" "$HERE/dump_pack.luau" "$HERE/pack.html" "$HERE/render_pack.mjs" "$S/"
python3 "$REPO/docs/proposals/R147/tests/mkbundle_verity.py" "$S/rs_bundle.luau" >/dev/null
(cd "$S" && /opt/luau/luau dump_pack.luau > scenes.txt)
[ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null)
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_pack.mjs" "$S" "$S/out" >/dev/null
python3 "$HERE/make_pack_sheet.py" "$S/out" "$HERE/.."
