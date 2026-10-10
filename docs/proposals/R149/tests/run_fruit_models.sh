#!/bin/sh
# Usage: sh run_fruit_models.sh [scratch dir]   (needs /opt/luau/luau, python3 + numpy)
# R149 fruit models on the Roblox mock with the REAL modules of this checkout, proved against the BASE commit (FRUIT_BASE, default 0b08836 = the branch commit just before the redesigns were merged; it was 38b1afa, the R149
# proposal commit, in the agent worktree) and against the R149 part-built fruit (FALLBACK_BASE, default 3484f31: the branch before the baked meshes):
#  R151 (owner: no white shine dots on fruit, one Verity face): the shine parts of nine plants are gone (Watermelon, Snow Melon, Ember Pumpkin, Apple, Elderbloom, Blueberry,
#     Iceberry, Moon Melon, Verity), so PlantArtCrystal / Desert / Jungle (dead fallback lists), PlantSurfaceStyle (it keeps the position-based tints of the parts after a
#     removed one), VerityPlantArt and PlantVisuals (`Skipped`, the face side) differ too; the diffs below allow those plants to differ ONLY by the removed parts ("~ng" twins).
#  0. files: among the PLANT-ART files only (every other R149 change - growth style, keyboard, Verity, z-fighting ... - has its own
#     suite; growth is drawn with the BASE's PlantGrowth on every side, run_growth.sh covers the new one), only the art / key modules below, PlantVisuals (routes the fruit-mesh keys), the bootstrap (bakes them), the new FruitMeshes149 and
#     src/MANIFEST.tsv differ from the base under src/ (the Prickly Pear's ApprovedPlantArt6, Lantern Fern's ApprovedPlantArt2, PlantArtCrystal
#     (Amethyst Grape), ApprovedPlantMeshes, PlantGrowth, GardenVisuals, the R148 seeds, Verity ... are byte for byte the base's);
#  1. regression diff: dump_plants.luau runs on the BASE and on this checkout (every plant of the catalog, 2 crops each, 8 for the Ash Tomato and the
#     Prickly Pear, every mode: art, ripe, growing, coats, harvest items, proxies, supports, prompts; the fruit-mesh bake ran on the mock);
#     check_plants_diff.py allows only the 7 redesigned fruit (art / plant / harvest lines) and the Ash Tomato's variations (a design-1 crop must stay
#     identical); the Prickly Pear must be identical (owner: back to its current look);
#     1b. fallback: the same dump with NO bake (parts) and with EVERY bake failing (fail) against FALLBACK_BASE: every plant identical, so a server
#     that cannot bake shows exactly the R149 part-built Watermelon / Snow Melon / Ember Pumpkin (only the reverted Prickly Pear differs);
#  2. test_fruit_models.luau: the redesigns, the baked meshes (generator, bake, templates, PlantVisuals routing, coats, pictures, growth), the Ash
#     Tomato's designs, the unchanged ones, every build mode; test_fruit_mesh_fallback.luau: failures (one key, every key, a content error, a failure
#     in the middle of a server build), a server baking on demand and the real GardenVisuals while the templates load / after, each in its own world;
#  3. floating parts: check_floating.py (R134) on the plants (nothing new floats against the base) and on every redesigned fruit alone (strict).
# Set FRUIT_KEEP_GOING=1 to run every stage after a failure (the exit status stays non-zero).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
BASE=${FRUIT_BASE:-0b08836};FALLBACK=${FALLBACK_BASE:-3484f31}
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
RC=0
stop(){ if [ -n "$FRUIT_KEEP_GOING" ];then RC=1;else exit 1;fi; }
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests;FL=$REPO/docs/proposals/seeds_R133/preview/check_floating.py
# --- 0. files -------------------------------------------------------------------------------------------------------------------------------
cat > "$OUT/allowed.txt" <<'EOF'
src/MANIFEST.tsv
src/ReplicatedStorage/ApprovedPlantArt.lua
src/ReplicatedStorage/ApprovedPlantArt5.lua
src/ReplicatedStorage/FruitMeshes149.lua
src/ReplicatedStorage/HologramForms.lua
src/ReplicatedStorage/PlantArtCrystal.lua
src/ReplicatedStorage/PlantArtDesert.lua
src/ReplicatedStorage/PlantArtForest.lua
src/ReplicatedStorage/PlantArtJungle.lua
src/ReplicatedStorage/PlantArtLava.lua
src/ReplicatedStorage/PlantArtSnow.lua
src/ReplicatedStorage/PlantSurfaceStyle.lua
src/ReplicatedStorage/PlantVisuals.lua
src/ReplicatedStorage/TreeReworkData2.lua
src/ReplicatedStorage/TreeReworkData4.lua
src/ReplicatedStorage/VerityPlantArt.lua
src/ServerScriptService/ApprovedPlantsBootstrap.server.lua
EOF
# Only plant-art files are this suite's business (the manifest too, for FruitMeshes149's row); other R149 work has its own suites.
ART='/(ApprovedPlantArt[0-9]*|PlantArt[A-Za-z]*|TreeReworkData[0-9]*|TreeReworkArt|RarityPlantArt|PlantVisuals|ApprovedPlantMeshes|ApprovedPlantIndex|ApprovedPlantsBootstrap\.server|FruitMeshes149|DesertPlantArt149|VerityPlantArt|MechArt|HologramForms|PlantSupportArt[A-Za-z]*|PlantSurfaceStyle)\.lua$|/MANIFEST\.tsv$'
{ git -C "$REPO" diff --name-only "$BASE" -- src;git -C "$REPO" ls-files --others --exclude-standard -- src; } | grep -E "$ART" | LC_ALL=C sort -u > "$OUT/changed.txt"
echo "== files against $BASE"
if diff "$OUT/allowed.txt" "$OUT/changed.txt" > "$OUT/files.diff";then echo "only the art / key modules (R149's 7; R151's shine removal: PlantArtCrystal / Desert / Jungle, PlantSurfaceStyle, VerityPlantArt), PlantVisuals, the bootstrap, FruitMeshes149 (new) and the manifest differ under src/ (Prickly Pear, Lantern Fern, Amethyst Grape, ApprovedPlantMeshes, PlantGrowth, GardenVisuals, the R148 seeds: byte for byte)"
else echo "unexpected src/ changes:";cat "$OUT/files.diff";stop;fi
grep -q 'ReplicatedStorage/FruitMeshes149	ReplicatedStorage/FruitMeshes149.lua' "$REPO/src/MANIFEST.tsv" || { echo "FruitMeshes149 is not in src/MANIFEST.tsv";stop; }
# --- 1. worlds: the base commit, the R149 part-built commit and this checkout ---------------------------------------------------------------------
rm -rf "$OUT/base" "$OUT/new" "$OUT/srcbase" "$OUT/fb" "$OUT/srcfb";mkdir -p "$OUT/base" "$OUT/new" "$OUT/srcbase" "$OUT/fb" "$OUT/srcfb"
git -C "$REPO" archive "$BASE" src | tar -x -C "$OUT/srcbase"
git -C "$REPO" archive "$FALLBACK" src | tar -x -C "$OUT/srcfb"
B=$OUT/srcbase/src/ReplicatedStorage
for d in base new fb;do cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/dump_plants.luau" "$HERE/scene_base.luau" "$HERE/fruit_mesh_mock.luau" "$OUT/$d/";done
python3 "$HERE/mkbundle_any.py" "$B" "$OUT/base/rs_bundle.luau" >/dev/null
python3 "$HERE/mkbundle_any.py" "$OUT/srcfb/src/ReplicatedStorage" "$OUT/fb/rs_bundle.luau" >/dev/null
python3 "$HERE/mkbundle_any.py" "$REPO/src/ReplicatedStorage" "$OUT/new/rs_bundle.luau" \
 PlantGrowth="$B/PlantGrowth.lua" PlantArtForestBase="$B/PlantArtForest.lua" PlantArtSnowBase="$B/PlantArtSnow.lua" PlantArtLavaBase="$B/PlantArtLava.lua" PlantArtCrystalBase="$B/PlantArtCrystal.lua" \
 TreeReworkData2Base="$B/TreeReworkData2.lua" TreeReworkData4Base="$B/TreeReworkData4.lua" ApprovedPlantArt2Base="$B/ApprovedPlantArt2.lua" ApprovedPlantArt5Base="$B/ApprovedPlantArt5.lua" \
 ApprovedPlantArt6Base="$B/ApprovedPlantArt6.lua" ApprovedPlantArtBase="$B/ApprovedPlantArt.lua" PlantArtForest149="$OUT/srcfb/src/ReplicatedStorage/PlantArtForest.lua" \
 PlantArtSnow149="$OUT/srcfb/src/ReplicatedStorage/PlantArtSnow.lua" PlantArtLava149="$OUT/srcfb/src/ReplicatedStorage/PlantArtLava.lua" \
 GardenVisuals="$REPO/src/StarterPlayer/StarterPlayerScripts/GardenVisuals.client.lua" >/dev/null
# The fallback scenarios run the real GardenVisuals, which needs the checkout's own growth modules (the art comparisons above draw growth with
# the BASE's PlantGrowth), so they get their own world with nothing swapped for PlantGrowth.
rm -rf "$OUT/live";mkdir -p "$OUT/live";cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/fruit_mesh_mock.luau" "$OUT/live/"
python3 "$HERE/mkbundle_any.py" "$REPO/src/ReplicatedStorage" "$OUT/live/rs_bundle.luau" \
 PlantArtForestBase="$B/PlantArtForest.lua" PlantArtSnowBase="$B/PlantArtSnow.lua" PlantArtLavaBase="$B/PlantArtLava.lua" PlantArtCrystalBase="$B/PlantArtCrystal.lua" \
 TreeReworkData2Base="$B/TreeReworkData2.lua" TreeReworkData4Base="$B/TreeReworkData4.lua" ApprovedPlantArt2Base="$B/ApprovedPlantArt2.lua" ApprovedPlantArt5Base="$B/ApprovedPlantArt5.lua" \
 ApprovedPlantArt6Base="$B/ApprovedPlantArt6.lua" ApprovedPlantArtBase="$B/ApprovedPlantArt.lua" PlantArtForest149="$OUT/srcfb/src/ReplicatedStorage/PlantArtForest.lua" \
 PlantArtSnow149="$OUT/srcfb/src/ReplicatedStorage/PlantArtSnow.lua" PlantArtLava149="$OUT/srcfb/src/ReplicatedStorage/PlantArtLava.lua" \
 GardenVisuals="$REPO/src/StarterPlayer/StarterPlayerScripts/GardenVisuals.client.lua" >/dev/null
echo "== regression diff against $BASE (every plant, every mode)"
(cd "$OUT/base" && /opt/luau/luau dump_plants.luau > dump.txt 2> err.txt) || { tail -20 "$OUT/base/err.txt";exit 1; }
(cd "$OUT/new" && /opt/luau/luau dump_plants.luau -a mesh > dump.txt 2> err.txt) || { tail -20 "$OUT/new/err.txt";exit 1; }
python3 "$HERE/check_plants_diff.py" "$OUT/base/dump.txt" "$OUT/new/dump.txt" > "$OUT/diff.log" || true
tail -${DIFF_LINES:-4} "$OUT/diff.log"
tail -1 "$OUT/diff.log" | grep -q 'only the allowed lines differ' || { cat "$OUT/diff.log";stop; }
echo "== fallback: no bake / every bake failing against $FALLBACK (the R149 part-built fruit)"
(cd "$OUT/fb" && /opt/luau/luau dump_plants.luau > dump.txt 2> err.txt) || { tail -20 "$OUT/fb/err.txt";exit 1; }
for m in parts fail;do
 (cd "$OUT/new" && /opt/luau/luau dump_plants.luau -a $m > dump_$m.txt 2> err_$m.txt) || { tail -20 "$OUT/new/err_$m.txt";exit 1; }
 python3 "$HERE/check_plants_diff.py" --fallback "$OUT/fb/dump.txt" "$OUT/new/dump_$m.txt" > "$OUT/diff_$m.log" || true
 echo "-- $m: $(grep -c '^WARN' "$OUT/new/dump_$m.txt") warning(s) logged";tail -${DIFF_LINES:-3} "$OUT/diff_$m.log"
 tail -1 "$OUT/diff_$m.log" | grep -q 'only the allowed lines differ' || { cat "$OUT/diff_$m.log";stop; }
done
[ "$(grep -c '^WARN' "$OUT/new/dump_parts.txt")" = 0 ] && [ "$(grep -c '^WARN' "$OUT/new/dump_fail.txt")" = 1 ] || { echo "expected 0 warnings without a bake and exactly 1 when every bake fails";stop; }
# --- 2. the tests ------------------------------------------------------------------------------------------------------------------------------------
cp "$HERE/test_fruit_models.luau" "$OUT/new/";cp "$HERE/test_fruit_mesh_fallback.luau" "$OUT/live/"
echo "== test_fruit_models"
(cd "$OUT/new" && timeout 1800 /opt/luau/luau test_fruit_models.luau > fruit.log 2> fruit.err) || { grep -v '^WARN\|^SCENE' "$OUT/new/fruit.log" | tail -40;tail -3 "$OUT/new/fruit.err";stop; }
grep -v '^WARN\|^SCENE\|^INFO' "$OUT/new/fruit.log" | tail -${FRUIT_LINES:-1}
grep '^INFO' "$OUT/new/fruit.log" || true
echo "== test_fruit_mesh_fallback"
for s in neutral every content server serverok garden;do
 (cd "$OUT/live" && timeout 900 /opt/luau/luau test_fruit_mesh_fallback.luau -a $s > fallback_$s.log 2>&1) || { grep -v '^WARN' "$OUT/live/fallback_$s.log" | tail -30;stop; }
 grep -v '^WARN' "$OUT/live/fallback_$s.log" | tail -1
done
# --- 3. floating parts ------------------------------------------------------------------------------------------------------------------------------
grep '^SCENE_PLANTS ' "$OUT/new/fruit.log" | sed 's/^SCENE_PLANTS //' > "$OUT/plants.json"
grep '^SCENE_FRUIT ' "$OUT/new/fruit.log" | sed 's/^SCENE_FRUIT //' > "$OUT/fruit.json"
(cd "$OUT/base" && /opt/luau/luau scene_base.luau 2>&1 | grep '^SCENE ' | sed 's/^SCENE //' > "$OUT/plants_base.json")
echo "== floating parts (R134 check_floating.py)"
python3 "$HERE/check_scenes.py" "$FL" plants "$OUT/plants.json" "$OUT/plants_base.json" || stop
python3 "$HERE/check_scenes.py" "$FL" fruit "$OUT/fruit.json" || stop
exit $RC
