#!/bin/sh
# Usage: sh run_mech_coats_preview.sh <scratch dir> <python with bpy 4.5> [samples, default 32]
# Makes docs/proposals/R155/mech_coats.png: a plain / Gold / Diamond Mech pack (hero, hotbar size, held, a frame of the opening), a Gold and a Diamond Mech plant with their coated fruit,
# the seeds, and the shop card live and ended, all from the REAL modules, the way the R153 Mech previews were made (docs/proposals/R153/mech_pack/run_mech_built_preview.sh):
#  1. dump_mech_coats.luau   builds the packs / opening copy / plants with the real modules on the Roblox mock (R151's pack world: the owner's templates; VerityPouch151 baked on the
#                            EditableMesh mock) and prints every part (dump.txt)
#  2. render_mech_coats.py   renders the tiles in Blender (Cycles CPU), reusing render_mech_pack.py's scene / lights / camera
#  3. run_shop_states.sh     the shop card from R120's shop harness at two server clocks (live / ended)
#  4. compose_mech_coats.py  lays the sheet out (Pillow)
# Needs /opt/luau and python3 + Pillow. Use a scratch dir with no stray .py files in it.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};BPY=${2:?python with bpy};SAMPLES=${3:-32}
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests;R151=$REPO/docs/proposals/R151/tests
mkdir -p "$S/dump" "$S/tiles"
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$R151/pack_world.luau" "$R151/pack_templates.luau" "$R151/pouch_mock.luau" "$HERE/dump_mech_coats.luau" "$S/dump/"
python3 -I "$R151/mkbundle_packs.py" "$S/dump" "$REPO/src" >/dev/null
(cd "$S/dump" && /opt/luau/luau dump_mech_coats.luau > dump.txt)
(cd "$REPO" && "$BPY" "$HERE/render_mech_coats.py" --dump "$S/dump/dump.txt" --out "$S/tiles" --samples "$SAMPLES")
sh "$HERE/run_shop_states.sh" "$S/shop"
python3 -I "$HERE/compose_mech_coats.py" "$S/tiles" "$S/shop" "$S/dump/dump.txt" "$REPO/docs/proposals/R155/mech_coats.png"
