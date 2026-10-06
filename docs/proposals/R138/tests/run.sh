#!/bin/sh
# Usage: sh run.sh [scratch dir]. R138 checks on the Roblox mock with the real scripts:
#  test_lowtier.luau        - Common / Uncommon / Rare small reveal pop (RevealFlourish) and the 2D sparkle pop.
#  test_index_alerts.luau   - Index reward badges (INDEX, MENU, biome tabs), claim sounds, no pedestal box.
#  test_starter.luau        - the free 2x-luck Forest pack for finishing the tutorial (real PlayerDataService).
#  tools/tests tutorial set - test_guide_flow, test_guide_layout (26 screens), test_tutorial (R152: every step's look,
#                             pointer and trigger, the pop, input, safe area, finish / skip / replay / returning players,
#                             no leftovers, write-on-change), all against the working copy.
# Reveal sounds: docs/proposals/audio_R123/tests. Previews: docs/proposals/R138/preview.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT/t"
INV=$REPO/docs/proposals/inventory_R113/tests;C=$REPO/src/StarterPlayer/StarterPlayerScripts;T=$REPO/tools/tests
cp "$T/roblox.luau" "$INV/world.luau" "$HERE"/test_lowtier.luau "$HERE"/test_index_alerts.luau "$OUT/"
mkdir -p "$OUT/srv";TB=$REPO/docs/proposals/treadmill_bonus_R123/tests
cp "$T/roblox.luau" "$TB/world.luau" "$HERE"/test_starter.luau "$OUT/srv/";python3 "$TB/mkbundle.py" "$OUT/srv" >/dev/null
python3 "$INV/mkbundle.py" "$OUT/rs_bundle.luau" ChestIndex="$C/ChestIndex.client.lua" PackOpeningFeedback="$C/PackOpeningFeedback.client.lua" >/dev/null
cp "$T/roblox.luau" "$T/test_tutorial.luau" "$T/test_guide_flow.luau" "$T/test_guide_layout.luau" "$OUT/t/"
cp "$REPO/src/ReplicatedStorage/BeginnerGuide.lua" "$OUT/t/new_Guide.luau";cp "$REPO/src/ReplicatedStorage/BeginnerGuide.lua" "$OUT/t/old_Guide.luau";cp "$REPO/src/ReplicatedStorage/HudLayout.lua" "$OUT/t/Hud.luau"
python3 "$T/bundle.py" "$OUT/t/tut_bundle.luau" BeginnerTutorial="$C/BeginnerTutorial.client.lua" BeginnerGuide="$REPO/src/ReplicatedStorage/BeginnerGuide.lua" HudLayout="$REPO/src/ReplicatedStorage/HudLayout.lua" PropCache152="$REPO/src/ReplicatedStorage/PropCache152.lua" >/dev/null
# R150 review: the Index badge pops silently (a chime at the badge change fired when a pack was OPENED, before the reveal shows the seed)
! grep -nE "alertsFrom|total>alertTotal and .*Audio.Play" "$C/ChestIndex.client.lua"
cd "$OUT"
for t in test_lowtier test_index_alerts;do echo "== $t";/opt/luau/luau $t.luau > $t.log 2>&1 || { tail -25 $t.log;exit 1; };tail -1 $t.log;done
(cd srv && echo "== test_starter" && { /opt/luau/luau test_starter.luau > starter.log 2>&1 || { tail -25 starter.log;exit 1; }; } && tail -1 starter.log)
cd "$OUT/t"
echo "== test_guide_flow";/opt/luau/luau test_guide_flow.luau > flow.log 2>&1;tail -1 flow.log;grep -q 'FLOW OK' flow.log
echo "== test_guide_layout";/opt/luau/luau test_guide_layout.luau > layout.log 2>&1;tail -1 layout.log;grep -q 'ALL PASS' layout.log
echo "== test_tutorial";/opt/luau/luau test_tutorial.luau > tut.log 2>&1 || { tail -25 tut.log;exit 1; };tail -1 tut.log;grep -q ', 0 failures' tut.log
