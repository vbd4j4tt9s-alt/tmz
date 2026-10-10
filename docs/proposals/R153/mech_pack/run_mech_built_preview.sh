#!/bin/sh
# Usage: sh run_mech_built_preview.sh <scratch dir> <python with bpy 4.5> [samples, default 32]
# Makes docs/proposals/R153/mech_pack_built.png: the Mech pack as BUILT (R153 look B) from the REAL parts, next to today's (R152), plus hotbar-size icons.
#  1. dump_mech_built.luau builds the pack with the REAL modules on the Roblox mock (R151's pack world: the owner's templates; VerityPouch151 baked on the
#     EditableMesh mock) and prints every part + the pouch's triangles (built_parts.json).
#  2. render_mech_built.py renders the tiles in Blender (Cycles CPU), reusing render_mech_pack.py's scene / lights / camera.
#  3. compose_mech_built.py lays out the sheet (Pillow).
# Needs /opt/luau and python3 + Pillow. Use a scratch dir with no stray .py files in it.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};BPY=${2:?python with bpy};SAMPLES=${3:-32}
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests;R151=$REPO/docs/proposals/R151/tests
mkdir -p "$S/dump" "$S/tiles"
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$R151/pack_world.luau" "$R151/pack_templates.luau" "$R151/pouch_mock.luau" "$HERE/dump_mech_built.luau" "$S/dump/"
python3 -I "$R151/mkbundle_packs.py" "$S/dump" "$REPO/src" >/dev/null
(cd "$S/dump" && /opt/luau/luau dump_mech_built.luau > built.txt)
grep '^BUILT ' "$S/dump/built.txt" | cut -c7- > "$S/built_parts.json"
(cd "$REPO" && "$BPY" "$HERE/render_mech_built.py" --built "$S/built_parts.json" --out "$S/tiles" --samples "$SAMPLES")
python3 -I "$HERE/compose_mech_built.py" "$S/tiles" "$S/built_parts.json" "$REPO/docs/proposals/R153/mech_pack_built.png"
