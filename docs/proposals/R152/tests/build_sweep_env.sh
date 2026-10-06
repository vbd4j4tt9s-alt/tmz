#!/bin/sh
# Usage: sh build_sweep_env.sh <scratch dir> <place.rbxl> [src dir, default this checkout's src]
# R152 z-fighting sweep, step 1: the world every sweep scene runs in - the owner's place as a Luau tree (tools/rbxl_geom.py), the Roblox mock, R149's zfight_world, R151's hub rig, the
# bundled modules of the src dir (zfight_bundle.py + the client scripts the sweep loads) and sweep_scene.luau (make_sweep_scene.py). run_variant.sh then runs one scene with its globals.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};PLACE=${2:?place.rbxl};SRC=${3:-$REPO/src}
mkdir -p "$S"
python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$S/place_tree.luau" Workspace/ChestChaseMap > /dev/null
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$REPO/docs/proposals/R151/tests/hub_rig.luau" "$S/"
python3 "$HERE/make_sweep_scene.py" "$REPO/docs/proposals/R149/tests/zfight_scene.luau" "$S/sweep_scene.luau" > /dev/null
python3 "$REPO/docs/proposals/R149/tests/zfight_bundle.py" "$SRC" "$S" > /dev/null
echo "sweep world ready in $S"
