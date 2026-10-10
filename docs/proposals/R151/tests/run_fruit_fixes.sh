#!/bin/sh
# Usage: sh run_fruit_fixes.sh [scratch dir] [all]   (needs /opt/luau/luau, python3, git; "all" also runs the older fruit / growth / Verity / SFX suites; ONLY="2 4" in the
# environment runs just those stages, mutation_fruit_fixes.sh uses it)
# R151 (the owner, live: "verity fruit also has 2 faces and some plants and fruits dont float into the players inventory. looking at watermelon remove those white dots ik its for
# shine but its just really ugly do so for all similar fruyits"): the three fixes, on the Roblox mock with the REAL modules of this checkout:
#  0. static   check_fixes_static.py: every touched file compiles, no shine part / decor spec / Verity back decal left in src, the harvest path is wired (mark -> runtime -> client ->
#              arrival) in the order the flight needs;
#  1. shine    docs/proposals/R149/tests/dump_plants.luau runs on the BASE commit (SHINE_BASE, default a669234 = the branch head before this change) and on this checkout: EVERY plant of the
#              catalog, 2 crops each, every mode (art, ripe, growing, coats, harvest items, proxies, supports, prompts), the Watermelon / Snow Melon / Ember Pumpkin with their baked meshes
#              (the bake runs on the mock). check_shine_diff.py: 56 plants identical line for line; the nine that had shine parts differ ONLY by them (their "~ng" twins are identical) and
#              their ripe plants lose exactly the parts the owner's screenshots showed (2 / 2 / 2 / 4 / 5 / 12 / 12 / 2 / 4);
#  2. verity   test_verity_face.luau: one face, on the right side, in every place (plant at every stage, regrow, proxies, the flight's copy, the item / hotbar / held, the Index card, the
#              seed, Gold / Diamond), no gloss, a plot turned any way, the pack keeps both faces;
#  3. marks    test_harvest_marks.luau: the REAL PlayerDataService marks the harvest that removes a plant (10 seeds) and no other (the shovel, a refused harvest, a full bag);
#  4. flights  test_fruit_flight.luau: EVERY seed of the catalog (65) through every path (regrow, removal, no model of the fruit, no model of the plant, observer), the real server runtime
#              + client + HarvestArrival + Hotbar: a flight that starts at the plant and ends at the harvester, the inventory held until it lands and flashed, nothing left behind; many at
#              once, a full bag, the shovel, reduced motion, the lowest tier, a dead harvester, a plant that streams out.
# With "all": the R149 fruit / growth / Verity / market / z-fight suites, the R147 Verity suites, the R148 roster art suite and the R150 SFX suite (they are unchanged except where they pinned the old behaviour).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
BASE=${SHINE_BASE:-a669234}
OUT=${1:-$(mktemp -d)};MODE=$2;mkdir -p "$OUT"
want() { if [ -z "$ONLY" ];then return 0;fi;case " $ONLY " in *" $1 "*) return 0;; esac;return 1; }
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests;R149=$REPO/docs/proposals/R149/tests;R123=$REPO/docs/proposals/treadmill_bonus_R123/tests
SP=StarterPlayer/StarterPlayerScripts;SRV=ServerScriptService/ChestChaseServer
if want 0;then
echo "== 0. static checks"
python3 "$HERE/check_fixes_static.py" "$REPO" "$BASE"
fi
# --- 1. no shine, nothing else changed -------------------------------------------------------------------------------------------------------------------------------------------
if want 1;then
echo "== 1. every plant of the catalog against $BASE (the shine parts only)"
rm -rf "$OUT/srcbase" "$OUT/dbase" "$OUT/dnew";mkdir -p "$OUT/srcbase" "$OUT/dbase" "$OUT/dnew"
git -C "$REPO" archive "$BASE" src | tar -x -C "$OUT/srcbase"
for d in dbase dnew;do cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$R149/dump_plants.luau" "$R149/fruit_mesh_mock.luau" "$OUT/$d/";done
python3 "$R149/mkbundle_any.py" "$OUT/srcbase/src/ReplicatedStorage" "$OUT/dbase/rs_bundle.luau" >/dev/null
python3 "$R149/mkbundle_any.py" "$REPO/src/ReplicatedStorage" "$OUT/dnew/rs_bundle.luau" >/dev/null
(cd "$OUT/dbase" && /opt/luau/luau dump_plants.luau -a mesh > dump.txt 2> err.txt) || { tail -20 "$OUT/dbase/err.txt";exit 1; }
(cd "$OUT/dnew" && /opt/luau/luau dump_plants.luau -a mesh > dump.txt 2> err.txt) || { tail -20 "$OUT/dnew/err.txt";exit 1; }
python3 "$HERE/check_shine_diff.py" "$OUT/dbase/dump.txt" "$OUT/dnew/dump.txt"
fi
# --- the worlds of the client suites ----------------------------------------------------------------------------------------------------------------------------------------------
world() { # $1 = dir: the mock + every ReplicatedStorage module + the client scripts and the server runtime the suites load
 mkdir -p "$1"
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$R149/growth_common.luau" "$R149/fruit_mesh_mock.luau" "$HERE/test_verity_face.luau" "$HERE/test_fruit_flight.luau" "$1/"
 python3 "$R149/mkbundle_any.py" "$REPO/src/ReplicatedStorage" "$1/rs_bundle.luau" PlantGrowthBase="$REPO/src/ReplicatedStorage/PlantGrowth.lua" GardenVisuals="$REPO/src/$SP/GardenVisuals.client.lua" \
  Hotbar="$REPO/src/$SP/Hotbar.client.lua" GardenPlantRuntime="$REPO/src/$SRV/GardenPlantRuntime.lua" >/dev/null
}
suite() { # $1 = dir, $2 = test file, $3.. = args; prints the last line
 d=$1;t=$2;shift 2
 (cd "$d" && timeout 3000 /opt/luau/luau "$t.luau" "$@" > "$t.log" 2>&1) || { grep -v '^WARN\|^SCENE\|^SEED\|^PATHS' "$d/$t.log" | cut -c1-260 | tail -30;return 1; }
 grep -v '^WARN\|^SCENE\|^SEED\|^PATHS' "$d/$t.log" | tail -1
}
world "$OUT/world"
if want 2;then
echo "== 2. the Verity fruit has one face"
suite "$OUT/world" test_verity_face
fi
if want 3;then
echo "== 3. the harvest that removes a plant is marked (the real PlayerDataService)"
mkdir -p "$OUT/marks";cp "$T/roblox.luau" "$R123/world.luau" "$HERE/test_harvest_marks.luau" "$OUT/marks/"
python3 "$HERE/mkbundle.py" "$OUT/marks" >/dev/null
suite "$OUT/marks" test_harvest_marks
fi
if want 4;then
echo "== 4. every seed, every harvest path: the fruit flies into the player"
suite "$OUT/world" test_fruit_flight
grep '^PATHS' "$OUT/world/test_fruit_flight.log"
fi
if [ "$MODE" != "all" ];then echo "R151 fruit fixes passed (pass \"all\" as the 2nd argument to run the older suites too)";exit 0;fi
# --- the older suites ----------------------------------------------------------------------------------------------------------------------------------------------------------------
P=$REPO/docs/proposals
for r in R149/tests/run_fruit_models.sh R149/tests/run_growth.sh R149/tests/run_verity.sh R149/tests/run_verity_pack.sh R147/tests/run_verity.sh R147/tests/run_verity_art.sh R147/tests/run_verity_pack.sh \
 R150/tests/run_sfx.sh R149/tests/run_market.sh R149/tests/run_zfight.sh R148/tests/run_roster.sh;do
 echo "== $r"
 n=$(echo "$r" | tr '/' '_')
 if sh "$P/$r" "$OUT/$n" > "$OUT/$n.log" 2>&1;then grep -E "checks|passed|FAIL|mutation|ALL PASS|identical|only the" "$OUT/$n.log" | tail -${ALL_LINES:-12}
 else grep -v '^WARN\|^SCENE' "$OUT/$n.log" | cut -c1-240 | tail -40;echo "FAILED: $r";exit 1;fi
done
echo "R151 fruit fixes and the older suites passed"
