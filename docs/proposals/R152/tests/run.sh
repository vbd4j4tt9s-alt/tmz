#!/bin/sh
# Usage: sh run.sh [scratch dir] [mutate]. R152 (SFX tidy-up, hotbar double-click, fruit-of-the-hour cylinder) on the Roblox mock (/opt/luau/luau) with the REAL
# modules / scripts of this checkout.
#  test_hotbar_click.luau - the real Hotbar: one press is one action (equip / unequip / slot move) for mouse and touch in every event order, rolled clicks,
#                           first-try drops (gap, edges, swap, shovel slot), the Bag, number keys with the Bag open, and total silence.
#  test_hotbar_stress.luau - a seeded random run (600 steps): clicks / taps (clean, rolled, flicked, in every event order), keys, L1 / R1, slot moves, Bag opens, card clicks
#                           and drops, items added / removed (also the frame before a click), the held item destroyed, cancelled presses, respawns; every action takes effect
#                           exactly once and the hotbar always equals a model of it (other seeds: an optional stress_cfg.luau returning {Seed=,N=} next to the test).
#  test_hold_race.luau    - the server half (R151's pack harness): a pack the player equipped is not thrown back into the Backpack by a second hold (quick unequip / re-equip while
#                           its shape loads) or by the previous pack's opening that has not finished yet.
#  test_silence.luau      - treadmills silent, InteractionFeedback keeps its real cues but not the hold-begin click.
#  test_chase_trim.luau   - ChaseMusicTrim152 cuts the secret keeper chase theme to its first 4 s (regions 0-4, loop), later sounds too, others untouched.
#  static checks          - the removed cues are gone from the scripts; the fruit-of-the-hour pedestal has no tube (docs/proposals/R135/tests covers the model).
# "mutate" bundles the R151 Hotbar instead (BASE=<commit before R152>) and expects the click test to FAIL: proof it catches the double-click.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=$2;BASE=${BASE:-24ed94b};mkdir -p "$OUT/cl"
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;SP=$S/StarterPlayer/StarterPlayerScripts;INV=$P/inventory_R113/tests
echo "== static checks"
fail=0
bad() { echo "FAIL: $1";fail=1; }
grep -nE "Audio\.Play\(" "$SP/Hotbar.client.lua" | grep -v "Bubble06" && bad "the Hotbar plays a cue other than the harvest landing (Bubble06)"
grep -nE "Equip|Bubble04" "$SP/Hotbar.client.lua" | grep -E "Audio\.|Play\(" && bad "the Hotbar still plays Equip / Bubble04"
grep -nE "Audio\.Play\('Equip'\)|Transaction\('Equip'\)" "$SP/InteractionFeedback.client.lua" && bad "InteractionFeedback still plays Equip (treadmill)"
grep -n "PromptButtonHoldBegan" "$SP/InteractionFeedback.client.lua" | grep -v "^[0-9]*:--" && bad "the hold-begin click is back"
grep -n "Audio" "$SP/PlantInspection.client.lua" && bad "PlantInspection plays a cue again"
# the treadmill code makes no sound of its own
for f in $S/ReplicatedStorage/TreadmillLook151.lua $S/ReplicatedStorage/TreadmillFx.lua $S/ReplicatedStorage/TreadmillPlayback.lua $S/ReplicatedStorage/TreadmillBeltArt151.lua \
 $SP/TreadmillAnimation.client.lua $S/ServerScriptService/ChestChaseServer/ActiveTraining81.lua; do
 if grep -nE "Instance\.new\(.Sound.\)|SoundId|InteractionAudio|LocalSfx|Audio\.Play" "$f";then bad "$f makes a sound";fi
done
# the one remaining Equip cue is the shop's (EconomyClient: Transaction('Equip'))
others=$(grep -rln "Play('Equip')\|Transaction('Equip')" "$S" | grep -v "InteractionAudio.lua" || true)
[ "$others" = "$S/StarterPlayer/StarterPlayerScripts/EconomyClient.client.lua" ] || bad "the Equip cue is played from: $others"
# the pedestal has no tube
grep -nE "drum\('Projector beam'" "$S/ServerScriptService/ChestChaseServer/MarketLayout.lua" && bad "the projector beam is back"
[ "$fail" = 0 ]
echo "ok: removed cues are gone, treadmill code is silent, the pedestal has no tube"
bad=0;for f in "$SP/Hotbar.client.lua" "$SP/InteractionFeedback.client.lua" "$SP/PlantInspection.client.lua" "$SP/ChaseMusicTrim152.client.lua" "$S/ServerScriptService/ChestChaseServer/MarketLayout.lua";do
 /opt/luau/luau-compile --null "$f" >/dev/null 2>&1 || { echo "FAIL: $f does not compile";bad=1; };done
[ "$bad" = 0 ]
echo "ok: the edited scripts compile"
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests"/*.luau "$HERE"/*.luau "$OUT/cl/"
if [ "$MODE" = "mutate" ]; then
 git -C "$REPO" show "$BASE:src/StarterPlayer/StarterPlayerScripts/Hotbar.client.lua" > "$OUT/Hotbar_old.lua"
 python3 "$P/R150/tests/mkbundle_sfx.py" "$OUT/cl" all-client NotificationService="$S/ServerScriptService/ChestChaseServer/NotificationService.lua" Hotbar="$OUT/Hotbar_old.lua" >/dev/null
 cd "$OUT/cl";echo "== mutate: test_hotbar_click against the $BASE Hotbar (must FAIL)"
 if timeout 600 /opt/luau/luau test_hotbar_click.luau > mutate.log 2>&1; then echo "FAIL: the click test passes on the old Hotbar";exit 1; fi
 grep -c "^FAIL" mutate.log | sed 's/$/ failed checks on the old Hotbar (expected)/'
 echo "== mutate: test_hotbar_stress against the $BASE Hotbar (must FAIL)"
 if timeout 600 /opt/luau/luau test_hotbar_stress.luau > mutate_stress.log 2>&1; then echo "FAIL: the stress test passes on the old Hotbar";exit 1; fi
 grep -c "^FAIL" mutate_stress.log | sed 's/$/ failed checks on the old Hotbar (expected)/'
 echo "== mutate: test_hold_race against the $BASE ChestService (must FAIL)"
 SRV=$OUT/srv;mkdir -p "$SRV";R151=$P/R151/tests
 git -C "$REPO" show "$BASE:src/ServerScriptService/ChestChaseServer/ChestService.lua" > "$OUT/ChestService_old.lua"
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$R151/pack_world.luau" "$R151/pack_templates.luau" "$R151/pouch_mock.luau" "$R151/pack_shape_samples.luau" "$HERE/test_hold_race.luau" "$SRV/"
 python3 "$R151/mkbundle_packs.py" "$SRV" "$S" --server ChestService="$OUT/ChestService_old.lua" >/dev/null
 cd "$SRV";if timeout 900 /opt/luau/luau test_hold_race.luau > mutate.log 2>&1; then echo "FAIL: the hold race test passes on the old ChestService";exit 1; fi
 grep -c "^FAIL" mutate.log | sed 's/$/ failed checks on the old ChestService (expected)/'
 echo "R152 mutation check passed";exit 0
fi
python3 "$P/R150/tests/mkbundle_sfx.py" "$OUT/cl" all-client NotificationService="$S/ServerScriptService/ChestChaseServer/NotificationService.lua" >/dev/null
cd "$OUT/cl"
for t in test_hotbar_click test_hotbar_stress test_silence test_chase_trim; do
 echo "== $t"
 timeout 600 /opt/luau/luau $t.luau > $t.log 2>&1 || { grep -v '^WARN' $t.log | tail -40;exit 1; }
 grep -v '^WARN' $t.log | tail -1
done
# the server half: ChestService:_holdPack on R151's pack harness
SRV=$OUT/srv;mkdir -p "$SRV";R151=$P/R151/tests
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$R151/pack_world.luau" "$R151/pack_templates.luau" "$R151/pouch_mock.luau" "$R151/pack_shape_samples.luau" "$HERE/test_hold_race.luau" "$SRV/"
python3 "$R151/mkbundle_packs.py" "$SRV" "$S" --server >/dev/null
cd "$SRV";echo "== test_hold_race"
timeout 900 /opt/luau/luau test_hold_race.luau > test_hold_race.log 2>&1 || { grep -v '^WARN' test_hold_race.log | tail -40;exit 1; }
grep -v '^WARN' test_hold_race.log | tail -1
echo "R152 suites passed"
