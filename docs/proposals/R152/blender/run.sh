#!/bin/sh
# R152: regenerate the game's keeper mesh data and KeeperRigConfig152 from the approved R151 rev 6 models (docs/proposals/R151/keepers).
# Usage: sh run.sh <scratch dir> <bpy python>
#   <bpy python>: a Python with the bpy 4.5 module (Blender as a module); nothing is rendered here.
# Steps: (1) dump_meshes.py (bpy): run the R151 generators exactly as their FBX export does and dump every part (vertices, triangles,
#            palette cells, flat / smooth, the convex hulls per rig group, the sleep Z), checking the winding and the colour formula's inputs;
#        (2) floor_candidates.py + select_floor.luau (the game's own pose code on the repo's Roblox mock): pick the floor samples;
#        (3) encode_meshes.py: write src/ServerScriptService/ChestChaseServer/KeeperMeshData152*.lua and src/ReplicatedStorage/KeeperRigConfig152.lua.
# Then run docs/proposals/R152/tests/run_keepers.sh <out>; for docs/proposals/R152/keepers_roundtrip.png:
#   <bpy python> render_roundtrip.py -- <out>/obj/decoded.json <R151 poses.json (R151 run.sh step 1)> <panels>
#   python3 compose_roundtrip.py <panels> ../keepers_roundtrip.png
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};PY=${2:?python with bpy}
mkdir -p "$S/lu"
(cd "$HERE" && "$PY" dump_meshes.py "$S/meshes.json")
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE/select_floor.luau" "$S/lu/"
python3 "$REPO/docs/proposals/R149/tests/mkbundle_any.py" "$REPO/src/ReplicatedStorage" "$S/lu/rs_bundle.luau" >/dev/null
python3 "$HERE/floor_candidates.py" "$S/meshes.json" "$S/lu/candidates.luau"
(cd "$S/lu" && /opt/luau/luau select_floor.luau > floor.json)
python3 "$HERE/encode_meshes.py" "$S/meshes.json" "$S/lu/floor.json" "$REPO"
