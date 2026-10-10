#!/bin/sh
# Usage: sh run_mech_pack_preview.sh <scratch dir> <python with bpy 4.5> [samples, default 16]
# Makes docs/proposals/R153/mech_pack.png (the R153 Mech pack proposal sheet).
#  1. R151's tests/dump_packs.luau builds every pack with the REAL modules on the Roblox mock; extract_today.py keeps the Mech pack's front parts
#     (today_parts.json, committed: R152's parts. R153 built look B, so this step now dumps a given commit's src: TODAY_FROM=<commit>, e.g. 8208603;
#     without it the committed file is used. The built look has its own sheet: run_mech_built_preview.sh -> mech_pack_built.png).
#  2. render_mech_pack.py renders the tiles in Blender (Cycles CPU): today / A / B / C (three-quarter + side), the hotbar icons, the reveal storyboard.
#  3. compose_mech_pack.py lays out the sheet and writes the labels (Pillow).
# Needs /opt/luau and python3 + Pillow. Use a scratch dir with no stray .py files in it (a bisect.py there shadows the stdlib).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};BPY=${2:?python with bpy};SAMPLES=${3:-16}
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests;R151=$REPO/docs/proposals/R151/tests
mkdir -p "$S/dump" "$S/tiles"
if [ -n "$TODAY_FROM" ];then
 mkdir -p "$S/today_src";git -C "$REPO" archive "$TODAY_FROM" src | tar -x -C "$S/today_src"
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$R151/pack_world.luau" "$R151/pack_templates.luau" "$R151/dump_packs.luau" "$S/dump/"
 python3 -I "$R151/mkbundle_packs.py" "$S/dump" "$S/today_src/src" >/dev/null
 (cd "$S/dump" && /opt/luau/luau dump_packs.luau > scenes.txt)
 python3 -I "$HERE/extract_today.py" "$S/dump/scenes.txt" "$HERE/today_parts.json"
fi
(cd "$REPO" && "$BPY" "$HERE/render_mech_pack.py" --out "$S/tiles" --samples "$SAMPLES")
python3 -I "$HERE/compose_mech_pack.py" "$S/tiles" "$REPO/docs/proposals/R153/mech_pack.png"
