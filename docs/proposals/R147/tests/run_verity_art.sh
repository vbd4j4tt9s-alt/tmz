#!/bin/sh
# Usage: sh run_verity_art.sh [scratch dir]. R147 Verity seed / plant art checks on the Roblox mock with the REAL modules of this
# checkout (VerityPlantArt, VerityGrowth, ApprovedPlantArt, PlantGrowth, PlantVisuals, SeedPackVisuals); needs /opt/luau and python3.
# "Existing plants unchanged" compares against the base commit's PlantVisuals / PlantGrowth / ApprovedPlantArt (git show BASE:...),
# loaded as PlantVisualsBase / PlantGrowthBase / ApprovedPlantArtBase.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
BASE=${VERITY_BASE:-5752986}
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/inventory_R113/tests/fixtures.luau" "$HERE/test_verity_art.luau" "$OUT/"
git -C "$REPO" show "$BASE:src/ReplicatedStorage/PlantVisuals.lua" | sed -e "s/WaitForChild('PlantGrowth')/WaitForChild('PlantGrowthBase')/" -e "s/WaitForChild('ApprovedPlantArt')/WaitForChild('ApprovedPlantArtBase')/" > "$OUT/PlantVisualsBase.lua"
# R149: the growing DRAWING (PlantGrowth) changed on purpose (docs/proposals/R149/tests/run_growth.sh proves it); this suite is about art, so both
# pipelines draw growth with this checkout's PlantGrowth (the "growing" comparisons then still show that no existing plant's ART changed).
cp "$REPO/src/ReplicatedStorage/PlantGrowth.lua" "$OUT/PlantGrowthBase.lua"
git -C "$REPO" show "$BASE:src/ReplicatedStorage/ApprovedPlantArt.lua" > "$OUT/ApprovedPlantArtBase.lua"
python3 "$HERE/mkbundle_verity.py" "$OUT/rs_bundle.luau" PlantVisualsBase="$OUT/PlantVisualsBase.lua" PlantGrowthBase="$OUT/PlantGrowthBase.lua" ApprovedPlantArtBase="$OUT/ApprovedPlantArtBase.lua" >/dev/null
cd "$OUT"
echo "== test_verity_art";/opt/luau/luau test_verity_art.luau > test_verity_art.log 2>&1 || { tail -40 test_verity_art.log;exit 1; }
grep -v '^WARN' test_verity_art.log
