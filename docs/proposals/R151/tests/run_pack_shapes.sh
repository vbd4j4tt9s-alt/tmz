#!/bin/sh
# Usage: sh run_pack_shapes.sh [scratch dir] [--mutations]
# R151 (owner: "make pack shape variations in blender; the pack shape will still be a chip shape but will be slightly different"): PackShapes151 (six gentle
# deformation fields over each design's normalised box, applied at run time to the owner's own pouch meshes through the EditableMesh route so every print survives;
# one fixed variation per design name), its hooks (SeedPackRenderer.Build, ItemPictures, VerityPouch151, the /test packshape command) on the Roblox mock
# (/opt/luau/luau) with the REAL modules of this checkout, the REAL pack templates of the owner's place (pack_templates.luau) and a mock EditableMesh route with a
# switch for every failure (pouch_mock.luau). test_pack_shapes.luau also compares the field with the Blender design's samples (pack_shape_samples.luau).
#  --mutations  breaks the code sixteen ways (a crimp that moves, y that moves, growth over 5%, neighbouring tiers with the same variation, vertex colours set,
#               the EditableMesh not destroyed, a hard-coded asset id, a client that waits, a stuck bake that stalls every pack, a failure forgotten, the off switch ignored, a part that does not
#               follow its mesh's centre, a stretched mesh, two bakes at once, a Verity pouch of another shape / not re-baked) and expects the test to notice each one.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=$(mktemp -d);MUT=0
if [ -n "$1" ] && [ "${1#--}" = "$1" ];then OUT=$1;shift;fi
[ "$1" = "--mutations" ] && MUT=1
mkdir -p "$OUT"
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests
LUAU=${LUAU:-/opt/luau/luau}
stage() { mkdir -p "$1";cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/pack_world.luau" "$HERE/pack_templates.luau" "$HERE/pouch_mock.luau" "$HERE/pack_shape_samples.luau" "$HERE/test_pack_shapes.luau" "$1/"; }
echo "== static: the hooks are where the owner's command and the status are expected"
S=$REPO/src;SS=$S/ServerScriptService/ChestChaseServer
grep -qE "^X.Actions.packshape=true" "$SS/OwnerUpdateCommands82.lua" || { echo "FAIL: packshape is not in OwnerUpdateCommands82.Actions";exit 1; }
grep -q "action=='packshape'then return require(script.Parent.PackShapeCommand151)" "$SS/OwnerUpdateCommands82.lua" || { echo "FAIL: OwnerUpdateCommands82 does not dispatch packshape";exit 1; }
grep -q "PackShapes151" "$S/ServerScriptService/ApprovedPlantsBootstrap.server.lua" || { echo "FAIL: the bootstrap does not load PackShapes151 (the status folder)";exit 1; }
grep -q "/test packshape" "$S/ReplicatedStorage/StudioTestHelp.lua" || { echo "FAIL: /test packshape is not in the F4 help";exit 1; }
grep -q "ReplicatedStorage/PackShapes151" "$S/MANIFEST.tsv" && grep -q "ChestChaseServer/PackShapeCommand151" "$S/MANIFEST.tsv" || { echo "FAIL: the manifest lacks PackShapes151 / PackShapeCommand151";exit 1; }
grep -q "PackShapes151" "$S/ReplicatedStorage/SeedPackRenderer.lua" && grep -q "PackShapes151" "$S/ReplicatedStorage/ItemPictures.lua" || { echo "FAIL: SeedPackRenderer / ItemPictures do not use PackShapes151";exit 1; }
n=$(grep -c "PackShapes151" "$S/ReplicatedStorage/SeedPackRenderer.lua")
[ "$n" = 2 ] || { echo "FAIL: SeedPackRenderer must reach PackShapes151 from the ordinary build only (found $n mentions: the comment and the call)";exit 1; }
for f in "$S/ReplicatedStorage/PackShapes151.lua" "$SS/PackShapeCommand151.lua" "$SS/OwnerUpdateCommands82.lua" "$S/ReplicatedStorage/VerityPouch151.lua" "$S/ReplicatedStorage/ItemPictures.lua" "$S/ReplicatedStorage/StudioTestHelp.lua" "$S/ReplicatedStorage/SeedPackRenderer.lua" "$S/ServerScriptService/ApprovedPlantsBootstrap.server.lua";do
 /opt/luau/luau-compile --null "$f" >/dev/null 2>&1 || { echo "FAIL: $f does not compile";exit 1; }
done
echo "ok: the command, the help, the manifest, the bootstrap and the hooks are in place; every touched script compiles"
echo "== test_pack_shapes (this checkout)"
stage "$OUT/run";python3 "$HERE/mkbundle_packs.py" "$OUT/run" "$REPO/src" >/dev/null
(cd "$OUT/run" && timeout 900 $LUAU test_pack_shapes.luau > test_pack_shapes.log 2>&1) || { grep -v '^WARN' "$OUT/run/test_pack_shapes.log" | tail -60;exit 1; }
grep -v '^WARN' "$OUT/run/test_pack_shapes.log"
if [ "$MUT" = 1 ];then
 echo "== mutations: the test must notice each broken copy"
 for m in $(python3 "$HERE/mutate_shapes.py" x list);do
  rm -rf "$OUT/mut";mkdir -p "$OUT/mut";cp -r "$REPO/src" "$OUT/mut/src"
  python3 "$HERE/mutate_shapes.py" "$OUT/mut/src" "$m" >/dev/null
  stage "$OUT/mut/run";python3 "$HERE/mkbundle_packs.py" "$OUT/mut/run" "$OUT/mut/src" >/dev/null
  if (cd "$OUT/mut/run" && timeout 900 $LUAU test_pack_shapes.luau > t.log 2>&1);then echo "FAIL: mutant $m was NOT noticed";exit 1;else echo "ok: mutant $m noticed ($(grep -c '^FAIL' "$OUT/mut/run/t.log") failed checks)";fi
 done
fi
echo "all pack shape checks passed"
