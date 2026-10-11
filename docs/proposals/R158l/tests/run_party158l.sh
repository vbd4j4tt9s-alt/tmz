#!/bin/sh
# Usage: sh run_party158l.sh [scratch dir]
# R158l (owner: "give me a command that can make me giant and I can give packs and I can make them rain from the sky and disco all over", then packs that fall everywhere and are taken by touch, and a
# server-wide sound): the owner's party commands (giant, givepack, packrain, disco, sound; NO combined party command), on the Roblox mock (the R152 giveaway harness: the REAL scripts of this checkout)
# with a LIVE server whose place was created by the owner:
#  wiring            - the new files and their manifest rows, the dispatch, owner-only, the server-wide commands take no @name, no /test party anywhere, the 10 s / 100 constants, no Lighting property is
#                      written by the disco, no unknown asset id, line 1 of the two new client scripts is the load guard, ProfileVersion 22, the frozen files byte-identical;
#  test_party158l    - the owner runs each command and an admin / a player cannot; giant scales, keeps the speed, survives respawn and clears; givepack; packrain: at most 100 at once, taken once by touch,
#                      gone 10 s after landing, random look size and spots, off, a full Bag, the screen's fall / trail / shrink; disco: the attribute, the scene in full / Fast Mode / Reduced Motion and
#                      Lighting exactly as it was; sound: one at a time, stop, bad ids, a sound that cannot load.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
S=$REPO/src;SRV=$S/ServerScriptService/ChestChaseServer;CL=$S/StarterPlayer/StarterPlayerScripts;RSD=$S/ReplicatedStorage
GUARD='^do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end'
wiring() {
 for row in "ModuleScript ReplicatedStorage/PartyRules158l ReplicatedStorage/PartyRules158l.lua" "ModuleScript ServerScriptService/ChestChaseServer/OwnerParty158l ServerScriptService/ChestChaseServer/OwnerParty158l.lua" \
  "ModuleScript ServerScriptService/ChestChaseServer/PackRain158l ServerScriptService/ChestChaseServer/PackRain158l.lua" "LocalScript StarterPlayer/StarterPlayerScripts/DiscoClient158l StarterPlayer/StarterPlayerScripts/DiscoClient158l.client.lua" \
  "LocalScript StarterPlayer/StarterPlayerScripts/PackRainFx158l StarterPlayer/StarterPlayerScripts/PackRainFx158l.client.lua";do
  set -- $row;class=$1;place=$2;file=$3
  test -f "$S/$file" || { echo "missing $file";return 1; }
  grep -q "^$class	$place	$file$" "$S/MANIFEST.tsv" || { echo "$file is not in src/MANIFEST.tsv as a $class";return 1; }
  /opt/luau/luau-compile --null "$S/$file" >/dev/null 2>&1 || { echo "$file does not compile";return 1; }
 done
 # line 1 of the two new client scripts is the load guard
 for c in DiscoClient158l PackRainFx158l;do head -1 "$CL/$c.client.lua" | grep -q "$GUARD" || { echo "line 1 of $c is not the load guard";return 1; };done
 # the dispatch: OwnerUpdateCommands82 -> OwnerParty158l; the four commands, owner only; the three server commands take no @name
 grep -q "OwnerParty158l).Execute(ctx,p,action,a,requester)" "$SRV/OwnerUpdateCommands82.lua" || { echo "the party commands are not dispatched from OwnerUpdateCommands82";return 1; }
 grep -q "OwnerParty158l).Actions)do X.Actions\[name\]=true" "$SRV/OwnerUpdateCommands82.lua" || { echo "the party actions are not registered";return 1; }
 grep -q "M.OwnerOnly={giant=true,packrain=true,disco=true,sound=true}" "$SRV/OwnerParty158l.lua" || { echo "giant, packrain, disco and sound must be owner-only";return 1; }
 grep -q "if M.OwnerOnly\[action\]and not isOwner(requester)then return false" "$SRV/OwnerParty158l.lua" || { echo "OwnerParty158l must refuse a requester who is not the game owner";return 1; }
 for w in packrain disco sound;do grep -q "s:match('^$w')~=nil" "$SRV/OwnerCommandTargets82.lua" || { echo "$w is not a server command (OwnerCommandTargets82.IsGlobal)";return 1; };done
 # givepack = the normal grant commands, TEST packs
 grep -q "if action=='givepack'then" "$SRV/StudioTestCommands.lua" || { echo "givepack is not in StudioTestCommands";return 1; }
 grep -q "givepack=true}" "$SRV/StudioTestCommands.lua" || { echo "givepack is not in GrantsItems (the BEST PULL mark)";return 1; }
 # no combined party command, anywhere
 if grep -rniE "/test party|party=true|action=='party'|'party'|party off|\"party\"" "$S" "$REPO/docs/COMMANDS.md";then echo "there must be no combined /test party";return 1;fi
 # the numbers the owner gave: a pack lies 10 s after it landed, at most 100 at once, a look of 0.6x-2x; the 4 commands in the docs
 grep -q "LingerSeconds=10" "$RSD/PartyRules158l.lua" && grep -q "MaxAtOnce=100" "$RSD/PartyRules158l.lua" && grep -q "ScaleMin=.6,ScaleMax=2" "$RSD/PartyRules158l.lua" || { echo "PartyRules158l: 10 s / 100 / 0.6-2";return 1; }
 # taking is by touch, not by a prompt
 if sed 's/--.*$//' "$SRV/PackRain158l.lua" | grep -n "ProximityPrompt";then echo "a rain pack is taken by touch: no prompt";return 1;fi
 grep -q "touch.Touched:Connect" "$SRV/PackRain158l.lua" || { echo "PackRain158l must take a pack on Touched";return 1; }
 # the disco never writes a Lighting property (the tint is one added effect): "restore exactly" cannot fail
 if sed 's/--.*$//' "$CL/DiscoClient158l.client.lua" | grep -nE "Lighting\.[A-Za-z_]+ *=[^=]";then echo "DiscoClient158l must not write a Lighting property";return 1;fi
 # no asset id of any kind is added: the only sound / image paths are the engine's own particle texture
 if sed 's/--.*$//' "$RSD/PartyRules158l.lua" "$SRV/OwnerParty158l.lua" "$SRV/PackRain158l.lua" "$CL/DiscoClient158l.client.lua" "$CL/PackRainFx158l.client.lua" | grep -nE "rbxassetid://[0-9]";then echo "no unknown asset id may be added";return 1;fi
 # the guard leaves a giant's walls alone; ProfileVersion stays 22; creative is still session memory only
 grep -q "if distance>1 and not giant then" "$SRV/MovementGuard.lua" || { echo "MovementGuard must not sweep a giant against the barriers";return 1; }
 grep -q "Config.ProfileVersion=22" "$SRV/Config.lua" || { echo "Config.ProfileVersion changed";return 1; }
 if sed 's/--.*$//' "$SRV/OwnerTestState82.lua" | grep -n "Premium\|MarkDirty\|DataStore\|QueueGardenSave";then echo "the owner's session state must not be saved (OwnerTestState82)";return 1;fi
 # the commands are in the F4 help and the docs
 for w in giant givepack packrain disco sound;do grep -q "/test $w" "$RSD/StudioTestHelp.lua" && grep -q "\`$w" "$REPO/docs/COMMANDS.md" || { echo "$w is not in the F4 help / docs/COMMANDS.md";return 1; };done
 grep -q "## Party commands (R158l)" "$REPO/docs/COMMANDS.md" || { echo "docs/COMMANDS.md has no R158l party section";return 1; }
 # the runner is registered in the suite list, before the pyramid suite
 grep -q "docs/proposals/R158l/tests/run_party158l.sh docs/proposals/R156/tests/run_pyramid156.sh" "$REPO/tools/tests/run_all_suites.sh" || { echo "run_party158l.sh is not registered in tools/tests/run_all_suites.sh before run_pyramid156.sh";return 1; }
 echo "wiring ok"
}
frozen() {
 (cd "$REPO" && for f in docs/proposals/R150/tests/frozen.sha256 docs/proposals/R151/tests/frozen.sha256;do grep -v '^#' "$f" | sha256sum -c --quiet;done > "$OUT/frozen.log" 2>&1) || { cat "$OUT/frozen.log";return 1; }
 echo "the gameplay files are byte-identical (the frozen.sha256 lists of R150 and R151)"
}
echo "== wiring";wiring;frozen
mkdir -p "$OUT/w"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/inventory_R113/tests/fixtures.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$REPO/docs/proposals/R150/tests/pedestal_harness.luau" "$REPO/docs/proposals/R151/tests/announce_env.luau" "$REPO/docs/proposals/R152/tests/giveaway_harness.luau" "$HERE/test_party158l.luau" "$OUT/w/"
python3 "$REPO/docs/proposals/R152/tests/bundle_giveaway.py" "$S" "$OUT/w" >/dev/null
python3 "$HERE/bundle_party158l.py" "$S" "$OUT/w" >/dev/null
echo "== test_party158l"
(cd "$OUT/w" && timeout 600 /opt/luau/luau test_party158l.luau > "$OUT/party.log" 2>&1) || { grep -v '^WARN' "$OUT/party.log" | tail -40;exit 1; }
grep -v '^WARN' "$OUT/party.log" | tail -2
echo "R158l party suite passed"
