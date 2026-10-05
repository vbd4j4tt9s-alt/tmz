#!/bin/sh
# Rebuild the R151 keeper previews.
# Usage: sh run.sh <scratch dir> <bpy python>
#   <bpy python>: a Python with the bpy 4.5 module (Blender as a module); renders use Cycles on the CPU.
# Steps: (1) dump the REAL pose frames + accent parts from the repo's Luau modules on the repo's Roblox mock,
#        (2) build every keeper in Blender, export FBX + manifests, render the panels,
#        (3) lay the panels out with Pillow (plain python3).
set -e
HERE=$(cd "$(dirname "$0")" && pwd); REPO=$(cd "$HERE/../../../../.." && pwd)
S=${1:?scratch dir}; PY=${2:?python with bpy}
mkdir -p "$S/lu" "$S/panels"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE/dump_poses.luau" "$S/lu/"
python3 "$REPO/docs/proposals/R147/tests/mkbundle_verity.py" "$S/lu/rs_bundle.luau" >/dev/null
(cd "$S/lu" && /opt/luau/luau dump_poses.luau > poses.json)
(cd "$HERE" && SAMPLES=${SAMPLES:-40} "$PY" render_all.py -- "$S/lu/poses.json" "$S/panels" "$HERE/.." fbx sheets ba lineup)
python3 "$HERE/compose_sheets.py" "$S/panels" "$HERE/.."
"$PY" "$HERE/tricount.py"
KEEPER_DETAIL=0.6 "$PY" "$HERE/tricount.py"
