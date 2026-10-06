#!/bin/sh
# Usage: sh run_jitter.sh [scratch dir]. R153 (owner: "fix all jittery type effects that are in the game like mutation and what not"): every effect R153
# fixed, on the Roblox mock (/opt/luau/luau, tools/tests/roblox.luau + the R113 world + R149's zfight_world) with the REAL scripts of this checkout:
# what is drawn (read right after RenderStepped) advances on every frame at 30 / 60 / 144 fps while it is visible and near, followers move in
# RenderStepped (not in the physics half of the frame) or on a smoothed / attached frame, and nothing decorative is written by the server per frame.
#  test_jitter_world   - mutation / weather item effects, track packs (hover, aura rings incl. Gold / Diamond), lava glows, the home marker;
#  test_jitter_runners - runner trails (ground ribbons, idle aura, boot coils), the trail aura's halo and veil, the speed popups' flight;
#  test_jitter_keepers - keeper speed signs (R153 owner spec: pinned at the keeper's spawn point, they do not move at all while it runs; run_keeper_label.sh has the rest), The Darkened's smoothed body,
#                        the world Void pack and its effects, keepers 160-350 studs (CosmeticBudget);
#  test_jitter_misc    - Verity's hop, held fruit, seed auras, GUI shine / card borders / rainbow, the upgrade button press on the client, and
#                        the static checks (connection sites);
#  server              - the server connects per-frame signals only in its gameplay services and tweens no part (decorative motion is the clients').
# Elsewhere (their own suites): the hub showcase on tier 2 (R151 test_hub_client), the giveaway pack in / out of view (R152 test_giveaway_client),
# the tutorial chevrons' fade (tools/tests/test_tutorial), a flying fruit's shrink (R149 test_growth_fx).
# JITTER_BASE=<commit> (the teeth): the same dynamic checks against that commit's src (d73905e = R152 as installed): they must FAIL there (the jitter
# is real and the checks see it); that run passes when every check set fails on the base.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
CLIENTS="ItemCosmetics SeedPackRender SeedPackClient HeldHarvests RunnerTrailClient RunnerTrailAura KeeperSpeedLabels BeastAnimation VeiledEventClient81
 SpeedGainPopup GardenVisuals LavaFlow HomeMarker VerityClient BeginnerTutorial OfflineGrowthNotice InteractionFeedback HubDisplayClient VoidGiveawayClient152"
prep() { # $1 = a src tree, $2 = the run dir: the mock, the tests and a bundle of that tree's modules and scripts
 mkdir -p "$2"
 cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" \
  "$REPO/docs/proposals/inventory_R113/tests/fixtures.luau" "$HERE"/jitter_world.luau "$HERE"/test_*.luau "$2/"
 sed "s#'/home/user/tmz/src'#'$1'#" "$REPO/docs/proposals/inventory_R113/tests/mkbundle.py" > "$2/mkbundle.py"
 X="";for n in $CLIENTS;do X="$X $n=$1/StarterPlayer/StarterPlayerScripts/$n.client.lua";done
 python3 "$2/mkbundle.py" "$2/rs_bundle.luau" $X GardenUpgradeService=$1/ServerScriptService/ChestChaseServer/GardenUpgradeService.lua >/dev/null
}
if [ -n "$JITTER_BASE" ];then
 rm -rf "$OUT/base";mkdir -p "$OUT/base"
 git -C "$REPO" archive "$JITTER_BASE" src | tar -x -C "$OUT/base"
 prep "$OUT/base/src" "$OUT/base/run";cd "$OUT/base/run";rc=0
 for t in test_jitter_*.luau;do
  timeout 900 /opt/luau/luau "$t" > "$t.log" 2>&1 || true
  f=$(grep -c '^FAIL' "$t.log" || true);e=$(grep -c 'stacktrace' "$t.log" || true)
  echo "base $JITTER_BASE: $t: $f failed checks$( [ "$e" -gt 0 ] && echo ', stopped by an error' )";grep '^FAIL' "$t.log" | head -40
  [ "$f" -gt 0 ] || [ "$e" -gt 0 ] || rc=1
 done
 [ $rc = 0 ] && echo "every check set fails on $JITTER_BASE: the jitter it looks for is there"
 exit $rc
fi
prep "$REPO/src" "$OUT";cd "$OUT"
rc=0
for t in test_jitter_*.luau;do echo "== $t";if timeout 900 /opt/luau/luau "$t" > "$t.log" 2>&1;then grep -v '^WARN' "$t.log" | tail -1;else grep -v '^WARN' "$t.log" | tail -25;rc=1;fi;done
# static: the server draws nothing decorative per frame and tweens no part. Its per-frame connections are the gameplay services' (timers, the chase,
# keepers, training, holes, bats, storms, the fling); MapService's tween is the legacy course's stage fade (Transparency, tied to its collision change).
echo "== server"
ALLOW=" BaseService BatService ChaseService ConcurrentKeeperService FruitOfHourService MovementGuard MysteryPackService RagdollService ServerClearService StormService TrackHoleService TreadmillBonusService WeatherService "
n=0
for f in $(grep -rlE "(Heartbeat|Stepped|PreSimulation|PostSimulation|RenderStepped):Connect|BindToRenderStep" "$REPO/src/ServerScriptService" || true);do
 b=$(basename "$f" .lua);b=${b%.server};n=$((n+1))
 case "$ALLOW" in *" $b "*) ;; *) echo "FAIL: $b connects a per-frame signal on the server";rc=1;; esac
done
for f in $(grep -rl "TweenService" "$REPO/src/ServerScriptService" || true);do
 b=$(basename "$f" .lua);case $b in MapService) ;; *) echo "FAIL: $b uses TweenService on the server";rc=1;; esac
done
echo "server: $n per-frame users, all gameplay services; no server tween but the legacy course fade"
[ $rc = 0 ] && echo "R153 jitter suites passed"
exit $rc
