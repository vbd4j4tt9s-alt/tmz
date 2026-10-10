#!/bin/sh
# Usage: sh run_roster.sh [scratch dir]. R148 seed roster change on the Roblox mock (/opt/luau/luau, python3 + numpy) with the REAL modules of
# this checkout: Desert's Rare Aloe and Legendary Sand Fruit, Fire Pepper Mythic (twice the size), Moon Melon Legendary.
#  1. Regression diff: dump_roster.luau runs on the BASE (the commit before the change: ROSTER_BASE, default cba4032) and on this checkout;
#     check_roster_diff.py allows ONLY: the 4 plants (Aloe Sprout's display name, Fire Pepper, Moon Melon, the 2 new ones), the Lava /
#     Crystal rows of banked packs (owner decision, no windfall: a banked pack cannot roll Fire Pepper or Moon Melon at all, so in those rows
#     ONLY the seeds of their old Rare tier may differ, and they absorb the share; all banked versions nil / 0 / 81 / 112 / 137 x Small /
#     Standard / Grand / Pack01-06), VOID 149 and the Fruit of the Hour list (51 -> 53). Everything else (every other biome's banked odds,
#     every other seed in those rows, the Void / Mech / Verity odds, every seeded roll) must be byte-identical.
#  2. test_roster.luau     - server world: constants, catalog, plants, odds, banked packs, hold tooltips and `odds` (sorted), save / load / gift,
#                            Index (old-roster milestones only through the saved flag), commands, Fruit of the Hour.
#  3. test_roster_art.luau - client world: the new plants (4 designs each: parts, bounds, sockets, determinism, spread, jitter, growth and regrow) and the
#                            x2 Fire Pepper in every build mode, seeds, effects, the Index and ChestIndex,
#                            and GardenVisuals' effect slots (by rarity rank, then distance). Its plant scene goes through check_floating.py
#                            (R134): no floating part in any plant.
# ROSTER_KEEP_GOING=1 runs every stage even after a failure (the exit status is still non-zero).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
BASE=${ROSTER_BASE:-cba4032}
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
T=$REPO/tools/tests;TBR=docs/proposals/treadmill_bonus_R123/tests;TB=$REPO/$TBR;INV=$REPO/docs/proposals/inventory_R113/tests
RC=0
stop(){ if [ -n "$ROSTER_KEEP_GOING" ];then RC=1;else exit 1;fi; }
# --- 1. regression diff ---------------------------------------------------------------------------------------------------------
rm -rf "$OUT/base" "$OUT/new";mkdir -p "$OUT/base" "$OUT/new"
git -C "$REPO" archive "$BASE" src | tar -x -C "$OUT/base"
mkdir -p "$OUT/base/$TBR";cp "$TB/mkbundle.py" "$TB/world.luau" "$OUT/base/$TBR/"
for d in base new;do cp "$T/roblox.luau" "$TB/world.luau" "$HERE/dump_roster.luau" "$OUT/$d/";done
python3 "$OUT/base/$TBR/mkbundle.py" "$OUT/base" >/dev/null
python3 "$TB/mkbundle.py" "$OUT/new" >/dev/null
echo "== regression diff against $BASE"
(cd "$OUT/base" && /opt/luau/luau dump_roster.luau > dump.txt 2> err.txt) || { tail -20 "$OUT/base/err.txt";exit 1; }
if (cd "$OUT/new" && /opt/luau/luau dump_roster.luau > dump.txt 2> err.txt);then
 python3 "$HERE/check_roster_diff.py" "$OUT/base/dump.txt" "$OUT/new/dump.txt" > "$OUT/diff.log" || true
 tail -${DIFF_LINES:-4} "$OUT/diff.log"
 tail -1 "$OUT/diff.log" | grep -q 'only the allowed lines differ' || stop
else tail -20 "$OUT/new/err.txt";stop;fi
# --- 2. server world ----------------------------------------------------------------------------------------------------------------
cp "$HERE/test_roster.luau" "$OUT/new/"
echo "== test_roster"
(cd "$OUT/new" && timeout 900 /opt/luau/luau test_roster.luau > roster.log 2>&1) || { grep -v '^WARN' "$OUT/new/roster.log" | tail -40;stop; }
grep -v '^WARN' "$OUT/new/roster.log" | tail -${ROSTER_LINES:-1}
# --- 3. client world -------------------------------------------------------------------------------------------------------------------
mkdir -p "$OUT/art";cd "$OUT/art"
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/test_roster_art.luau" "$REPO/docs/proposals/seeds_R133/preview/check_floating.py" "$OUT/art/"
git -C "$REPO" show "$BASE:src/ReplicatedStorage/PlantVisuals.lua" | sed -e "s/WaitForChild('PlantGrowth')/WaitForChild('PlantGrowthBase')/" -e "s/WaitForChild('ApprovedPlantArt')/WaitForChild('ApprovedPlantArtBase')/" > PlantVisualsBase.lua
# R149: the growing DRAWING (PlantGrowth) changed on purpose (docs/proposals/R149/tests/run_growth.sh proves it); this suite is about art, so both
# pipelines draw growth with this checkout's PlantGrowth (the "growing" comparisons then still show that no existing plant's ART changed).
cp "$REPO/src/ReplicatedStorage/PlantGrowth.lua" PlantGrowthBase.lua
git -C "$REPO" show "$BASE:src/ReplicatedStorage/ApprovedPlantArt.lua" > ApprovedPlantArtBase.lua
# (ChestIndex and GardenVisuals = the real client scripts the test drives)
python3 "$REPO/docs/proposals/R147/tests/mkbundle_verity.py" rs_bundle.luau PlantVisualsBase=PlantVisualsBase.lua PlantGrowthBase=PlantGrowthBase.lua ApprovedPlantArtBase=ApprovedPlantArtBase.lua ChestIndex="$REPO/src/StarterPlayer/StarterPlayerScripts/ChestIndex.client.lua" GardenVisuals="$REPO/src/StarterPlayer/StarterPlayerScripts/GardenVisuals.client.lua" >/dev/null
echo "== test_roster_art"
timeout 900 /opt/luau/luau test_roster_art.luau > art.log 2>&1 || { grep -v '^WARN\|^SCENE' art.log | tail -40;stop; }
grep -v '^WARN\|^SCENE' art.log | tail -${ART_LINES:-1}
grep '^SCENE ' art.log | sed 's/^SCENE //' > plants.json
echo "== floating parts (plants; the summary line says 'seeds' but each scene entry is one plant)"
python3 check_floating.py plants.json || stop
exit $RC
