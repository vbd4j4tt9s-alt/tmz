#!/bin/sh
# Rebuild the R151 keeper previews (rev 2: faces with five states, connectivity check, stud texture, effects).
# Usage: sh run.sh <scratch dir> <bpy python>
#   <bpy python>: a Python with the bpy 4.5 module (Blender as a module); renders use Cycles on the CPU.
# Steps: (1) dump the REAL pose frames + accent parts from the repo's Luau modules on the repo's Roblox mock,
#        (2) contact-graph check: every keeper in the rest pose and every rendered pose must be one piece
#            (Storm Colossus: only its storm-linked pieces may float, listed as "by design"),
#        (3) build every keeper in Blender, export FBX + manifests, render the panels, face close-ups,
#            today vs proposed and the lineup,
#        (4) lay the panels out with Pillow (plain python3),
#        (5) triangle counts (full and lite) and an FBX re-import check.
set -e
HERE=$(cd "$(dirname "$0")" && pwd); REPO=$(cd "$HERE/../../../../.." && pwd)
S=${1:?scratch dir}; PY=${2:?python with bpy}
mkdir -p "$S/lu" "$S/panels"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE/dump_poses.luau" "$S/lu/"
python3 "$REPO/docs/proposals/R147/tests/mkbundle_verity.py" "$S/lu/rs_bundle.luau" >/dev/null
(cd "$S/lu" && /opt/luau/luau dump_poses.luau > poses.json)
(cd "$HERE" && "$PY" connectivity.py -- "$S/lu/poses.json" "$S/connectivity.json")
(cd "$HERE" && SAMPLES=${SAMPLES:-24} "$PY" render_all.py -- "$S/lu/poses.json" "$S/panels" "$HERE/.." fbx sheets faces ba lineup)
python3 "$HERE/compose_sheets.py" "$S/panels" "$HERE/.."
(cd "$HERE" && "$PY" tricount.py)
(cd "$HERE" && KEEPER_DETAIL=0.6 "$PY" tricount.py)
(cd "$HERE" && "$PY" check_fbx.py "$HERE/../fbx")
