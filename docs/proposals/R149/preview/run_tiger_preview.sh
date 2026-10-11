#!/bin/sh
# Usage: sh run_tiger_preview.sh <scratch dir> [node_modules dir with three@0.169 and playwright]. Renders docs/proposals/R149/tiger_gear.png (BEFORE / AFTER:
# front, front 3/4, rear 3/4, chase stride) and tiger_gear_poses.png (head close-up, asleep, pounce wind-up, pounce impact) from the REAL
# KeeperAccents (+ BeastPose / KeeperSignatureStrike frames) on the Roblox mock. Needs /opt/luau, node + playwright (global) and three.js
# (npm install three@0.169.0 in the scratch dir, or pass an existing node_modules). Approximate render: the mesh files cannot be downloaded
# here, so the tiger body is the convex hull of the rig's FloorSamples, the tail (Bounds only) an approximate tube; no Roblox materials.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir}
mkdir -p "$S";cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE/dump_tiger.luau" "$HERE/tiger.html" "$HERE/render_tiger.mjs" "$S/"
python3 "$REPO/docs/proposals/R147/tests/mkbundle_verity.py" "$S/rs_bundle.luau" >/dev/null
cd "$S"
if [ -n "$2" ]; then [ -e node_modules ] || ln -s "$2" node_modules
else [ -d node_modules/three ] || npm install three@0.169.0 >/dev/null; [ -e node_modules/playwright ] || ln -s "$(npm root -g)/playwright" node_modules/playwright; fi
/opt/luau/luau dump_tiger.luau > scene.json
node render_tiger.mjs "$S" "$HERE/.."
