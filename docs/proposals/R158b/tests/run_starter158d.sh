#!/bin/sh
# Usage: sh run_starter158d.sh [scratch dir]
# R158d (owner: "new players receive a [Verity] pack on spawn ... guaranteed mythic or above"; "2 bonus rolls"; "only till the Verity event ends"; notice "Thanks for playing! Here's a gift"): the new-player gift.
#  wiring               - the files, src/MANIFEST.tsv, the main script's one guarded line, the owner command (Actions, dispatcher, per-player, F4 help, docs/COMMANDS.md), ProfileVersion 22, the frozen files
#                         byte-identical, the saved fields are optional Premium fields / optional record fields, the floor is set by server code only (no remote, no test command knows it), the
#                         Void giveaway files and the odds files are untouched, no new client script / sound / remote;
#  test_starter158d     - on the real player data (the R123 world): see the header of that file (new profile once, second join nothing, old profile nothing, interrupted grants, event ended, 2,000 floored
#                         opens never below Mythic and the renormalised tier mix, ordinary Verity odds unchanged, floor not settable, not giftable, own stack, owner tool).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
S=$REPO/src;SRV=$S/ServerScriptService/ChestChaseServer;RSD=$S/ReplicatedStorage
wiring() {
 for f in ReplicatedStorage/StarterVerityRules158d ServerScriptService/ChestChaseServer/StarterVerity158d;do
  test -f "$S/$f.lua" || { echo "missing $f";return 1; }
  grep -q "	$f	$f.lua" "$S/MANIFEST.tsv" || { echo "$f is not in src/MANIFEST.tsv";return 1; }
  /opt/luau/luau-compile --null "$S/$f.lua" >/dev/null 2>&1 || { echo "$f does not compile";return 1; }
 done
 M=$S/ServerScriptService/ChestChaseServerMain.server.lua
 [ "$(grep -c "StarterVerity158d" "$M")" = 1 ] || { echo "the main script must mention StarterVerity158d on exactly one line";return 1; }
 grep -q "pcall(function()require(modules.StarterVerity158d).new(Config,playerData,chestService,notifications,treadmillBonus):Start()end)" "$M" || { echo "the main script does not start the gift (guarded: a failure must never stop the server)";return 1; }
 grep -q "X.Actions.starterverity=true" "$SRV/OwnerUpdateCommands82.lua" && grep -q "StarterVerity158d).Command(ctx,p,a)" "$SRV/OwnerUpdateCommands82.lua" || { echo "starterverity is not wired into OwnerUpdateCommands82";return 1; }
 if sed -n '/^function T.IsGlobal/,/^end/p' "$SRV/OwnerCommandTargets82.lua" | grep -q starterverity;then echo "starterverity takes an @name: it must not be a server-wide command";return 1;fi
 grep -q "/test starterverity" "$RSD/StudioTestHelp.lua" && grep -q "starterverity" "$REPO/docs/COMMANDS.md" || { echo "starterverity is not in the F4 help / docs/COMMANDS.md";return 1; }
 [ -f "$REPO/docs/proposals/R158b/starter_verity158d.md" ] || { echo "docs/proposals/R158b/starter_verity158d.md is missing";return 1; }
 grep -q "Config.ProfileVersion=22" "$SRV/Config.lua" || { echo "Config.ProfileVersion changed";return 1; }
 # the saved Premium fields are plain optional fields (an older server keeps them as they are): the profile reader, PremiumProgress and Config never name them
 for f in "$SRV/PlayerDataService.lua" "$SRV/PremiumProgress.lua" "$SRV/Config.lua";do if grep -n "StarterRolls158d\|RollsField" "$f";then echo "$f must not know the optional Premium fields";return 1;fi;done
 # the floor is set by server code only: only these files know the gift
 for f in $(grep -rl "StarterVerity158d\|StarterVerityRules158d" "$S" --include=*.lua | sed "s#^$S/##" | sort);do
  case "$f" in ReplicatedStorage/StarterVerityRules158d.lua|ServerScriptService/ChestChaseServer/StarterVerity158d.lua|ServerScriptService/ChestChaseServer/PlayerDataService.lua|ServerScriptService/ChestChaseServer/ChestService.lua|ServerScriptService/ChestChaseServer/TreadmillBonusService.lua|ServerScriptService/ChestChaseServer/OwnerUpdateCommands82.lua|ServerScriptService/ChestChaseServerMain.server.lua|ReplicatedStorage/StudioTestHelp.lua|ServerScriptService/ChestChaseServer/OwnerCommandTargets82.lua) ;; *) echo "unexpected file knows the gift: $f";return 1;; esac
 done
 if sed 's/--.*$//' "$SRV/StarterVerity158d.lua" | grep -n "TestGrant\|RemoteEvent\|RemoteFunction\|OnServerEvent\|OnServerInvoke\|FireClient\|Heartbeat\|RenderStepped";then echo "the gift service must have no TestGrant, no remote and no per-frame loop";return 1;fi
 for f in OwnerTestPacks RarePackTests StudioTestCommands PremiumService FruitGiftService;do if sed 's/--.*$//' "$SRV/$f.lua" | grep -n "Floor";then echo "$f must not touch a pack's Floor";return 1;fi;done
 # PlayerDataService: the floor is used in AddChest, the open (2 lines), the loader and the serializer, nowhere else
 [ "$(grep -c "StarterVerity.PackFloor\|StarterVerity.CleanFloor\|StarterVerity.RollFloored" "$SRV/PlayerDataService.lua")" = 5 ] || { echo "PlayerDataService must use the floor in exactly AddChest, the open (2), the loader and the serializer";return 1; }
 grep -q "local floor = testSeed == nil and StarterVerity.PackFloor(pack) or nil" "$SRV/PlayerDataService.lua" || { echo "the open must ignore the floor for an owner TEST reveal";return 1; }
 grep -q "self:PackPityRoll(pity,StarterVerity.RollFloored,PackRules,floor,self.Config,pack.Stage,unitRoll,luck,pack.BagVariant,pack.OddsVersion,pack.RateBoost,passLuck)" "$SRV/PlayerDataService.lua" || { echo "the floored roll must go through the pack pity scope with the pack's own arguments";return 1; }
 # the Void giveaway pedestal and its pool are untouched
 if git -C "$REPO" diff --name-only HEAD -- src | grep -q "VoidGiveaway";then echo "the Void giveaway files must not change";return 1;fi
 # no asset id and no Instance in the gift's files
 for f in "$RSD/StarterVerityRules158d.lua" "$SRV/StarterVerity158d.lua";do if sed 's/--.*$//' "$f" | grep -n "rbxassetid\|Instance.new";then echo "the gift adds an asset or an Instance: $f";return 1;fi;done
 echo "wiring ok"
}
frozen() {
 (cd "$REPO" && grep -v '^#' "$REPO/docs/proposals/R151/tests/frozen.sha256" | sha256sum -c --quiet > "$OUT/frozen.log" 2>&1) || { cat "$OUT/frozen.log";return 1; }
 echo "the gameplay files are byte-identical (R151's frozen.sha256)"
}
echo "== wiring";wiring;frozen
mkdir -p "$OUT/w"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$REPO/docs/proposals/R151/tests/announce_env.luau" "$HERE/test_starter158d.luau" "$OUT/w/"
python3 "$REPO/docs/proposals/R152/tests/bundle_giveaway.py" "$S" "$OUT/w" >/dev/null
echo "== test_starter158d"
(cd "$OUT/w" && timeout 900 /opt/luau/luau test_starter158d.luau > "$OUT/starter.log" 2>&1) || { grep -v '^WARN' "$OUT/starter.log" | tail -40;exit 1; }
grep '^INFO' "$OUT/starter.log" || true
grep -v '^WARN\|^INFO' "$OUT/starter.log" | tail -2
echo "R158d starter gift suite passed"
