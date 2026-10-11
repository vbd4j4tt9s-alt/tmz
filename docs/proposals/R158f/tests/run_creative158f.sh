#!/bin/sh
# Usage: sh run_creative158f.sh [scratch dir]
# R158f (owner: "give me cmds to test everything, remove restrictions for my cmds, my cmds are absolute, basically give me creative mode"): the game owner's commands without limits, creative mode,
# and the test commands for everything new, on the Roblox mock (the R152 giveaway harness: /opt/luau/luau, tools/tests/roblox.luau) with the REAL scripts of this checkout, on a LIVE server
# (RunService:IsStudio() is false) whose place was created by the owner:
#  wiring            - the new module and its manifest row, the dispatcher, Config.ProfileVersion 22, the frozen files byte-identical, line 1 of the three client scripts touched is still its load guard,
#                      creative is never saved (OwnerCreative158f / OwnerTestState82 hold no profile field), the owner check is the one OwnerCommandAccess makes;
#  test_creative158f - the owner runs a formerly Studio-only command on a live server and an admin still cannot; the owner's grants past the Bag cap; creative on / off (can't be hit, no Bag cap,
#                      no rate limit, no movement correction, no bat cooldown, a high speed, ripe plants), per player, ended by leaving; only the owner can set it; the tutorial for the owner
#                      (reset clears Fast / FastCrop and shows step 1, step N, done); newplayer; verityevent; droppack; the help lists the new commands.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
S=$REPO/src;SRV=$S/ServerScriptService/ChestChaseServer;CL=$S/StarterPlayer/StarterPlayerScripts;RSD=$S/ReplicatedStorage
wiring() {
 f=ServerScriptService/ChestChaseServer/OwnerCreative158f
 test -f "$S/$f.lua" || { echo "missing $f";return 1; }
 grep -q "	$f	$f.lua" "$S/MANIFEST.tsv" || { echo "$f is not in src/MANIFEST.tsv";return 1; }
 /opt/luau/luau-compile --null "$S/$f.lua" >/dev/null 2>&1 || { echo "$f does not compile";return 1; }
 grep -q "OwnerCreative158f).Execute(ctx,p,action,a,requester)" "$SRV/OwnerUpdateCommands82.lua" || { echo "the creative commands are not dispatched from OwnerUpdateCommands82";return 1; }
 grep -q "UpdateCommands.Execute(ctx,player,action,a,requester)" "$SRV/StudioTestCommands.lua" || { echo "the dispatcher does not pass the requester on";return 1; }
 grep -q "Config.ProfileVersion=22" "$SRV/Config.lua" || { echo "Config.ProfileVersion changed";return 1; }
 # line 1 of the three client scripts touched here is still its load guard
 for c in "$CL/BatClient.client.lua" "$CL/BeginnerTutorial.client.lua" "$CL/StudioTestClient.client.lua";do head -1 "$c" | grep -q "^do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end" || { echo "line 1 of $c is not the load guard";return 1; };done
 # the owner check is OwnerCommandAccess.IsOwner (the creator, or the group's owner): admins are not owners
 sed -n '/^function Access.IsAllowed/,/^end/p' "$SRV/OwnerCommandAccess.lua" | grep -q "return Access.IsOwner(player)" || { echo "IsAllowed must end in IsOwner (the creator)";return 1; }
 sed -n '/^function Access.IsOwner/,/^end/p' "$SRV/OwnerCommandAccess.lua" | grep -q "AdminUserIds" && { echo "IsOwner must not count AdminUserIds";return 1; }
 # creative is session memory only: no profile field, no save in the module that holds it
 if sed 's/--.*$//' "$SRV/OwnerTestState82.lua" | grep -n "Premium\|MarkDirty\|DataStore\|QueueGardenSave";then echo "creative must not be saved (OwnerTestState82)";return 1;fi
 # only the owner can set it, tutorial / newplayer / verityevent too
 grep -q "M.OwnerOnly={creative=true,tutorial=true,newplayer=true,verityevent=true}" "$SRV/OwnerCreative158f.lua" || { echo "creative, tutorial, newplayer and verityevent must be owner-only";return 1; }
 # the tutorial: a normal player's Replay request is still refused first (R158c)
 grep -q "if action=='Replay'then return false end" "$SRV/TutorialProgress.lua" || { echo "TutorialAction must still refuse Replay";return 1; }
 # the commands are in the F4 help and the docs
 for w in creative droppack tutorial newplayer fastfruit verityevent bonusrolls holo walls batstats;do grep -q "/test $w" "$RSD/StudioTestHelp.lua" && grep -q "\`$w" "$REPO/docs/COMMANDS.md" || { echo "$w is not in the F4 help / docs/COMMANDS.md";return 1; };done
 grep -q "Creative mode and testing everything (R158f)" "$REPO/docs/COMMANDS.md" || { echo "docs/COMMANDS.md has no R158f section";return 1; }
 echo "wiring ok"
}
frozen() {
 (cd "$REPO" && grep -v '^#' "$REPO/docs/proposals/R151/tests/frozen.sha256" | sha256sum -c --quiet > "$OUT/frozen.log" 2>&1) || { cat "$OUT/frozen.log";return 1; }
 echo "the gameplay files are byte-identical (R151's frozen.sha256)"
}
echo "== wiring";wiring;frozen
mkdir -p "$OUT/w"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/inventory_R113/tests/fixtures.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$REPO/docs/proposals/R150/tests/pedestal_harness.luau" "$REPO/docs/proposals/R151/tests/announce_env.luau" "$REPO/docs/proposals/R152/tests/giveaway_harness.luau" "$HERE/test_creative158f.luau" "$OUT/w/"
python3 "$REPO/docs/proposals/R152/tests/bundle_giveaway.py" "$S" "$OUT/w" >/dev/null
echo "== test_creative158f"
(cd "$OUT/w" && timeout 600 /opt/luau/luau test_creative158f.luau > "$OUT/creative.log" 2>&1) || { grep -v '^WARN' "$OUT/creative.log" | tail -40;exit 1; }
grep -v '^WARN' "$OUT/creative.log" | tail -2
echo "R158f creative suite passed"
