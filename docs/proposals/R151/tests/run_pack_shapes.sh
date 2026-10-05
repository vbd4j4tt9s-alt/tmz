#!/bin/sh
# Usage: sh run_pack_shapes.sh [scratch dir] [--mutations]
# R151 (owner: "make pack shape variations in blender; the pack shape will still be a chip shape but will be slightly different", then "every pack can spawn with
# either of those variations ... shapes for visual representation in the index can just use the default pack shape"): PackShapes151 (six gentle deformation fields
# over each design's normalised box, applied at run time to the owner's own pouch meshes through the EditableMesh route so every print survives; one roll PER PACK,
# kept for life), its hooks (SeedPackRenderer.Build, VerityPackArt, ItemPictures, ChestService, ChaseService, PlayerDataService, MysteryPackService, the /test
# packshape command) on the Roblox mock (/opt/luau/luau) with the REAL modules of this checkout, the REAL pack templates of the owner's place (pack_templates.luau)
# and a mock EditableMesh route with a switch for every failure (pouch_mock.luau).
#  static                   check_shape_plumbing.py: where the shape is passed and where it is not (the Index / catalogues / shops), the hotbar stack key, ProfileVersion 22
#  test_pack_shapes.luau    the field against the Blender design's samples, the roll and its distribution, the bake of all 252 (design, variation) pairs, every context, builds
#                           that never yield, the fallbacks (sticky), the LRU budget (eviction, pins, grace, idle sweep, hard cap), the switches, the real ItemPictures, Verity
#  test_pack_shapes_server.luau   every way a pack enters the world: AddChest, the optional record field (save / load / gift / old records), the track spawn and the plan
#                           ahead, steal / carry / drop / bank / tool / hand / opening copy, the mystery pedestal, hand-made test packs
#  --mutations  breaks the code about fifty ways (see mutate_shapes.py) and expects the check that owns each one to notice it.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=$(mktemp -d);MUT=0
if [ -n "$1" ] && [ "${1#--}" = "$1" ];then OUT=$1;shift;fi
[ "$1" = "--mutations" ] && MUT=1
mkdir -p "$OUT"
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests
LUAU=${LUAU:-/opt/luau/luau}
stage() { mkdir -p "$1";cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/pack_world.luau" "$HERE/pack_templates.luau" "$HERE/pouch_mock.luau" "$HERE/pack_shape_samples.luau" "$HERE/test_pack_shapes.luau" "$HERE/test_pack_shapes_server.luau" "$1/"; }
S=$REPO/src;SS=$S/ServerScriptService/ChestChaseServer
echo "== static: the hooks, the plumbing, the manifest"
grep -qE "^X.Actions.packshape=true" "$SS/OwnerUpdateCommands82.lua" || { echo "FAIL: packshape is not in OwnerUpdateCommands82.Actions";exit 1; }
grep -q "action=='packshape'then return require(script.Parent.PackShapeCommand151)" "$SS/OwnerUpdateCommands82.lua" || { echo "FAIL: OwnerUpdateCommands82 does not dispatch packshape";exit 1; }
grep -q "PackShapes151" "$S/ServerScriptService/ApprovedPlantsBootstrap.server.lua" || { echo "FAIL: the bootstrap does not load PackShapes151 (the status folder)";exit 1; }
grep -q "/test packshape" "$S/ReplicatedStorage/StudioTestHelp.lua" || { echo "FAIL: /test packshape is not in the F4 help";exit 1; }
grep -q "ReplicatedStorage/PackShapes151" "$S/MANIFEST.tsv" && grep -q "ChestChaseServer/PackShapeCommand151" "$S/MANIFEST.tsv" || { echo "FAIL: the manifest lacks PackShapes151 / PackShapeCommand151";exit 1; }
for f in "$S/ReplicatedStorage/PackShapes151.lua" "$SS/PackShapeCommand151.lua" "$SS/OwnerUpdateCommands82.lua" "$S/ReplicatedStorage/VerityPouch151.lua" "$S/ReplicatedStorage/VerityPackArt.lua" "$S/ReplicatedStorage/ItemPictures.lua" "$S/ReplicatedStorage/StudioTestHelp.lua" "$S/ReplicatedStorage/SeedPackRenderer.lua" "$S/ReplicatedStorage/SeedPackVisuals.lua" "$S/StarterPlayer/StarterPlayerScripts/Hotbar.client.lua" "$SS/ChestService.lua" "$SS/ChaseService.lua" "$SS/PlayerDataService.lua" "$SS/MysteryPackService.lua" "$SS/StudioTestCommands.lua" "$SS/RarePackTests.lua" "$S/ServerScriptService/ApprovedPlantsBootstrap.server.lua";do
 /opt/luau/luau-compile --null "$f" >/dev/null 2>&1 || { echo "FAIL: $f does not compile";exit 1; }
done
python3 "$HERE/check_shape_plumbing.py" "$S"
echo "ok: the command, the help, the manifest, the bootstrap are in place; every touched script compiles"
echo "== test_pack_shapes (this checkout)"
stage "$OUT/run";python3 "$HERE/mkbundle_packs.py" "$OUT/run" "$REPO/src" --server >/dev/null
(cd "$OUT/run" && timeout 900 $LUAU test_pack_shapes.luau > test_pack_shapes.log 2>&1) || { grep -v '^WARN' "$OUT/run/test_pack_shapes.log" | tail -60;exit 1; }
grep -v '^WARN' "$OUT/run/test_pack_shapes.log"
echo "== test_pack_shapes_server (this checkout)"
(cd "$OUT/run" && timeout 900 $LUAU test_pack_shapes_server.luau > test_pack_shapes_server.log 2>&1) || { grep -v '^WARN' "$OUT/run/test_pack_shapes_server.log" | tail -60;exit 1; }
grep -v '^WARN' "$OUT/run/test_pack_shapes_server.log"
if [ "$MUT" = 1 ];then
 echo "== mutations: the check that owns each broken copy must notice it"
 for m in ${SHAPES_MUTANTS:-$(python3 "$HERE/mutate_shapes.py" x list)};do # (SHAPES_MUTANTS="a b c" runs just those)
  kind=$(python3 "$HERE/mutate_shapes.py" x kind "$m")
  rm -rf "$OUT/mut";mkdir -p "$OUT/mut";cp -r "$REPO/src" "$OUT/mut/src"
  python3 "$HERE/mutate_shapes.py" "$OUT/mut/src" "$m" >/dev/null
  noticed=0
  if [ "$kind" = static ];then
   python3 "$HERE/check_shape_plumbing.py" "$OUT/mut/src" >/dev/null 2>&1 || noticed=1
   [ "$noticed" = 1 ] && echo "ok: mutant $m noticed (static)" || { echo "FAIL: mutant $m was NOT noticed (static)";exit 1; }
   continue
  fi
  stage "$OUT/mut/run";python3 "$HERE/mkbundle_packs.py" "$OUT/mut/run" "$OUT/mut/src" --server >/dev/null
  if [ "$kind" = server ];then test=test_pack_shapes_server.luau;else test=test_pack_shapes.luau;fi
  if (cd "$OUT/mut/run" && timeout 900 $LUAU $test > t.log 2>&1);then echo "FAIL: mutant $m was NOT noticed ($kind)";exit 1;else echo "ok: mutant $m noticed ($kind: $(grep -c '^FAIL' "$OUT/mut/run/t.log") failed checks)";fi
 done
fi
echo "all pack shape checks passed"
