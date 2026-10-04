#!/bin/sh
# Usage: sh run_fruit_models.sh [scratch dir]   (needs /opt/luau/luau, python3 + numpy)
# R149 fruit models on the Roblox mock with the REAL modules of this checkout, proved against the BASE commit (FRUIT_BASE, default 0b08836 = the branch commit just before the redesigns were merged; it was 38b1afa, the R149
# proposal commit, in the agent worktree):
#  0. files: only the 8 art / key modules below (and, since the growth-style change, the files run_growth.sh covers: PlantGrowth, PlantGrowthFx,
#     HarvestArrival, GardenVisuals, Hotbar, EconomyClient, PlantAnimationBatch, PlantingEffects) differ from the base under src/ (Lantern Fern's
#     ApprovedPlantArt2, PlantArtCrystal (Amethyst Grape), PlantVisuals, the R148 seeds, Verity ... are byte for byte the base's). The art suites draw
#     growth with the BASE's PlantGrowth (the growing drawing changed on purpose; run_growth.sh proves that);
#  1. regression diff: dump_plants.luau runs on the BASE and on this checkout (every plant of the catalog, 2 crops each, 8 for the Ash Tomato and the
#     Prickly Pear, every mode: art, ripe, growing, coats, harvest items, proxies, supports, prompts); check_plants_diff.py allows only the 8 redesigned
#     fruit (art / plant / harvest lines) and the Ash Tomato's variations (a design-1 crop must stay identical);
#  2. test_fruit_models.luau: the redesigns, the Ash Tomato's designs, the unchanged ones, pictures, every build mode;
#  3. floating parts: check_floating.py (R134) on the plants (nothing new floats against the base) and on every redesigned fruit alone (strict).
# Set FRUIT_KEEP_GOING=1 to run every stage after a failure (the exit status stays non-zero).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
BASE=${FRUIT_BASE:-0b08836}
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
RC=0
stop(){ if [ -n "$FRUIT_KEEP_GOING" ];then RC=1;else exit 1;fi; }
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests;FL=$REPO/docs/proposals/seeds_R133/preview/check_floating.py
# --- 0. files -------------------------------------------------------------------------------------------------------------------------------
cat > "$OUT/allowed.txt" <<'EOF'
src/ReplicatedStorage/ApprovedPlantArt.lua
src/ReplicatedStorage/ApprovedPlantArt5.lua
src/ReplicatedStorage/ApprovedPlantArt6.lua
src/ReplicatedStorage/PlantArtForest.lua
src/ReplicatedStorage/PlantArtLava.lua
src/ReplicatedStorage/PlantArtSnow.lua
src/ReplicatedStorage/TreeReworkData2.lua
src/ReplicatedStorage/TreeReworkData4.lua
EOF
# R149 growth style (phase 1, run_growth.sh) changed these files as well. They are not art: the art suites below draw growth with the BASE's PlantGrowth.
cat >> "$OUT/allowed.txt" <<'EOF'
src/MANIFEST.tsv
src/ReplicatedStorage/HarvestArrival.lua
src/ReplicatedStorage/PlantAnimationBatch.lua
src/ReplicatedStorage/PlantGrowth.lua
src/ReplicatedStorage/PlantGrowthFx.lua
src/ReplicatedStorage/PlantingEffects.lua
src/StarterPlayer/StarterPlayerScripts/EconomyClient.client.lua
src/StarterPlayer/StarterPlayerScripts/GardenVisuals.client.lua
src/StarterPlayer/StarterPlayerScripts/Hotbar.client.lua
EOF
LC_ALL=C sort -o "$OUT/allowed.txt" "$OUT/allowed.txt"
git -C "$REPO" diff --name-only "$BASE" -- src | LC_ALL=C sort > "$OUT/changed.txt"
echo "== files against $BASE"
if diff "$OUT/allowed.txt" "$OUT/changed.txt" > "$OUT/files.diff";then echo "only the 8 art / key modules and the R149 growth-style files differ under src/ (Lantern Fern, Amethyst Grape, PlantVisuals, the R148 seeds, Verity: byte for byte)"
else echo "unexpected src/ changes:";cat "$OUT/files.diff";stop;fi
# --- 1. worlds: the base commit and this checkout ----------------------------------------------------------------------------------------------
rm -rf "$OUT/base" "$OUT/new" "$OUT/srcbase";mkdir -p "$OUT/base" "$OUT/new" "$OUT/srcbase"
git -C "$REPO" archive "$BASE" src | tar -x -C "$OUT/srcbase"
B=$OUT/srcbase/src/ReplicatedStorage
for d in base new;do cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/dump_plants.luau" "$HERE/scene_base.luau" "$OUT/$d/";done
python3 "$HERE/mkbundle_any.py" "$B" "$OUT/base/rs_bundle.luau" >/dev/null
python3 "$HERE/mkbundle_any.py" "$REPO/src/ReplicatedStorage" "$OUT/new/rs_bundle.luau" \
 PlantGrowth="$B/PlantGrowth.lua" PlantArtForestBase="$B/PlantArtForest.lua" PlantArtSnowBase="$B/PlantArtSnow.lua" PlantArtLavaBase="$B/PlantArtLava.lua" PlantArtCrystalBase="$B/PlantArtCrystal.lua" \
 TreeReworkData2Base="$B/TreeReworkData2.lua" TreeReworkData4Base="$B/TreeReworkData4.lua" ApprovedPlantArt2Base="$B/ApprovedPlantArt2.lua" ApprovedPlantArt5Base="$B/ApprovedPlantArt5.lua" \
 ApprovedPlantArt6Base="$B/ApprovedPlantArt6.lua" ApprovedPlantArtBase="$B/ApprovedPlantArt.lua" >/dev/null
echo "== regression diff against $BASE (every plant, every mode)"
(cd "$OUT/base" && /opt/luau/luau dump_plants.luau > dump.txt 2> err.txt) || { tail -20 "$OUT/base/err.txt";exit 1; }
(cd "$OUT/new" && /opt/luau/luau dump_plants.luau > dump.txt 2> err.txt) || { tail -20 "$OUT/new/err.txt";exit 1; }
python3 "$HERE/check_plants_diff.py" "$OUT/base/dump.txt" "$OUT/new/dump.txt" > "$OUT/diff.log" || true
tail -${DIFF_LINES:-4} "$OUT/diff.log"
tail -1 "$OUT/diff.log" | grep -q 'only the allowed lines differ' || { cat "$OUT/diff.log";stop; }
# --- 2. the tests ------------------------------------------------------------------------------------------------------------------------------------
cp "$HERE/test_fruit_models.luau" "$OUT/new/"
echo "== test_fruit_models"
(cd "$OUT/new" && timeout 1800 /opt/luau/luau test_fruit_models.luau > fruit.log 2> fruit.err) || { grep -v '^WARN\|^SCENE' "$OUT/new/fruit.log" | tail -40;tail -3 "$OUT/new/fruit.err";stop; }
grep -v '^WARN\|^SCENE' "$OUT/new/fruit.log" | tail -${FRUIT_LINES:-1}
# --- 3. floating parts ------------------------------------------------------------------------------------------------------------------------------
grep '^SCENE_PLANTS ' "$OUT/new/fruit.log" | sed 's/^SCENE_PLANTS //' > "$OUT/plants.json"
grep '^SCENE_FRUIT ' "$OUT/new/fruit.log" | sed 's/^SCENE_FRUIT //' > "$OUT/fruit.json"
(cd "$OUT/base" && /opt/luau/luau scene_base.luau 2>&1 | grep '^SCENE ' | sed 's/^SCENE //' > "$OUT/plants_base.json")
echo "== floating parts (R134 check_floating.py)"
python3 "$HERE/check_scenes.py" "$FL" plants "$OUT/plants.json" "$OUT/plants_base.json" || stop
python3 "$HERE/check_scenes.py" "$FL" fruit "$OUT/fruit.json" || stop
exit $RC
