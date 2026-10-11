#!/bin/sh
# Usage: sh run_speed158i.sh [scratch dir]. R158i (owner: "increase the base speed of new players to 20k in-game speed but of course this is still displayed as 1 speed on their screen"), on the Roblox
# mock with the real scripts of this checkout:
#  static            - Config.SpeedFloor / DefaultSpeed = 20000 = SpeedDisplay.Floor; ProfileVersion 22; the frozen files are byte-identical (R151 frozen.sha256; Config's line is the R158i one); no function
#                      over 180 registers (check_compile_O0); line 1 of the edited client scripts is the load guard; every screen that shows a speed goes through SpeedDisplay (the HUD wallet, the
#                      player list, the hub's TOP SPEED board, the keeper signs, the hub gate keys, the owner's / test commands) and none of them formats the raw stat itself;
#  test_speed_client - SpeedPoints.Sub, SpeedDisplay (Shown / Compact / Exact / PlayerList / NeedText / NeedForWalkSpeed / Both), the real GardenWallet HUD readout (20,000 reads 1, +60 reads 61), gains
#                      stay deltas;
#  test_speed_server - the real player data: a new profile starts at 20,000 (its cell reads 1), an older profile below the floor is raised on load and saved, one above it is untouched, the save holds
#                      the real points, the walk speed comes from the real points;
#  teeth             - mutants of the real scripts that each of the checks above must catch (the offset off by one, the floor not applied on load, the default back to 0, the player list or the HUD showing
#                      the raw points). Skip them with TEETH=0. (The keeper signs' numbers are pinned in docs/proposals/R147/tests/run.sh.)
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
S=$REPO/src;C=$S/StarterPlayer/StarterPlayerScripts;RSD=$S/ReplicatedStorage;SRV=$S/ServerScriptService/ChestChaseServer;T=$REPO/tools/tests
TB=$REPO/docs/proposals/treadmill_bonus_R123/tests;INV=$REPO/docs/proposals/inventory_R113/tests
fail(){ echo "FAIL: $*";exit 1; }
echo "== static"
(cd "$REPO" && grep -v '^#' docs/proposals/R151/tests/frozen.sha256 | sha256sum -c --quiet) || fail "a frozen file changed"
echo "ok: the frozen files are byte-identical"
sh "$T/check_compile_O0.sh" "$REPO" > "$OUT/o0.log" 2>&1 || { tail -5 "$OUT/o0.log";fail "check_compile_O0"; }
tail -1 "$OUT/o0.log"
for f in KeeperSpeedLabels BeginnerTutorial;do head -1 "$C/$f.client.lua" | grep -q "^do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived" || fail "line 1 of $f is not the load guard";done
head -2 "$C/Hotbar.client.lua" | grep -q "R152" || fail "Hotbar lines 1-2 changed"
echo "ok: line 1 of the edited client scripts is the load guard (Hotbar untouched)"
FLOOR=$(sed -n 's/^Config.SpeedFloor = \([0-9]*\)$/\1/p' "$SRV/Config.lua");DEF=$(sed -n 's/^Config.DefaultSpeed = \(.*\)$/\1/p' "$SRV/Config.lua");DFLOOR=$(sed -n "s/^local D={Version='158i',Floor=\([0-9]*\)}$/\1/p" "$RSD/SpeedDisplay.lua")
[ "$FLOOR" = 20000 ] && [ "$DEF" = "Config.SpeedFloor" ] && [ "$DFLOOR" = 20000 ] || fail "Config.SpeedFloor ($FLOOR) / DefaultSpeed ($DEF) / SpeedDisplay.Floor ($DFLOOR) must all be 20000"
grep -q "Config.ProfileVersion=22" "$SRV/Config.lua" || fail "ProfileVersion must stay 22"
for f in "$RSD/GardenWallet.lua" "$SRV/PlayerDataService.lua" "$SRV/SpeedBoardService.lua" "$SRV/HubDecor151.lua" "$SRV/StudioTestCommands.lua" "$SRV/OwnerUpdateCommands82.lua" "$C/KeeperSpeedLabels.client.lua";do
 grep -q "SpeedDisplay" "$f" || fail "$(basename "$f") must show a speed through SpeedDisplay"
done
grep -q "SpeedDisplay" "$S/MANIFEST.tsv" || fail "SpeedDisplay is not in MANIFEST.tsv"
# nothing else formats the raw speed stat for a screen: the only readers of ChestChaseStats.Speed / the player-list cell go through SpeedDisplay
if sed 's/--.*$//' "$RSD/GardenWallet.lua" | grep -n "SetValue(now)";then fail "GardenWallet writes the raw points to the HUD";fi
if sed 's/--.*$//' "$SRV/SpeedBoardService.lua" | grep -n "Prefix\.\.Cash.Compact(entry.Score)";then fail "SpeedBoardService writes the raw points to the board";fi
echo "ok: Config / SpeedDisplay agree (20000), ProfileVersion 22, every speed display goes through SpeedDisplay"
prep_client() { # $1 = a src tree, $2 = the run dir
 mkdir -p "$2";cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/test_speed_client158i.luau" "$2/"
 sed "s#'/home/user/tmz/src'#'$1'#" "$INV/mkbundle.py" > "$2/mkbundle.py";python3 "$2/mkbundle.py" "$2/rs_bundle.luau" >/dev/null
}
prep_server() { # $1 = a src tree, $2 = the run dir
 mkdir -p "$2";cp "$T/roblox.luau" "$TB/world.luau" "$HERE/test_speed_server158i.luau" "$2/"
 sed "s#'../../../../src'#'$1'#" "$TB/mkbundle.py" > "$2/mkbundle.py";python3 "$2/mkbundle.py" "$2" >/dev/null
}
run_client() { (cd "$1" && timeout 300 /opt/luau/luau test_speed_client158i.luau > client.log 2>&1); }
run_server() { (cd "$1" && timeout 300 /opt/luau/luau test_speed_server158i.luau > server.log 2>&1); }
prep_client "$S" "$OUT/client";prep_server "$S" "$OUT/server"
echo "== test_speed_client"
run_client "$OUT/client" || { grep -v '^WARN' "$OUT/client/client.log" | tail -25;fail "client test"; }
grep -v '^WARN' "$OUT/client/client.log" | tail -1
echo "== test_speed_server"
run_server "$OUT/server" || { grep -v '^WARN' "$OUT/server/server.log" | tail -25;fail "server test"; }
grep -v '^WARN' "$OUT/server/server.log" | tail -1
[ "${TEETH:-1}" = 0 ] && { echo "R158i speed suite passed (teeth skipped)";exit 0; }
echo "== teeth"
mutant() { # $1 name, $2 file (relative to src), $3 from (fixed string), $4 to, $5 client|server
 M=$OUT/mut_$1;rm -rf "$M";mkdir -p "$M";cp -r "$S" "$M/src"
 python3 - "$M/src/$2" "$3" "$4" <<'PY' || fail "mutant $1: pattern not found"
import sys
p,a,b=sys.argv[1:4];s=open(p,encoding='utf-8').read()
if a not in s: sys.exit(1)
open(p,'w',encoding='utf-8').write(s.replace(a,b,1))
PY
 if [ "$5" = client ];then prep_client "$M/src" "$M/run";if run_client "$M/run";then fail "mutant $1 was not caught";fi
 else prep_server "$M/src" "$M/run";if run_server "$M/run";then fail "mutant $1 was not caught";fi;fi
 echo "caught: $1";rm -rf "$M"
}
mutant offset_off_by_one ReplicatedStorage/SpeedDisplay.lua "D.Offset=D.Floor-1" "D.Offset=D.Floor" client
mutant below_one ReplicatedStorage/SpeedDisplay.lua "if P.Compare(p,tostring(D.Floor))<=0 then return'1'end" "if P.Compare(p,tostring(D.Floor))<=0 then return'0'end" client
mutant hud_raw ReplicatedStorage/GardenWallet.lua "self.Speed:SetValue(require(RS.SpeedDisplay).Shown(now))" "self.Speed:SetValue(now)" client
mutant need_raw ReplicatedStorage/SpeedDisplay.lua " local shown=D.Shown(points)
 if shown=='1'then return'1'end
 return P.NeedText(shown)" " return P.NeedText(P.Normalize(points))" client
mutant floor_not_on_load ServerScriptService/ChestChaseServer/PlayerDataService.lua "if Points.Compare(loadedSpeed, floor) < 0 then loadedSpeed = floor;speedMigrationNeeded = true end" "if false then end" server
mutant floor_not_saved ServerScriptService/ChestChaseServer/PlayerDataService.lua "if Points.Compare(loadedSpeed, floor) < 0 then loadedSpeed = floor;speedMigrationNeeded = true end" "if Points.Compare(loadedSpeed, floor) < 0 then loadedSpeed = floor end" server
mutant default_zero ServerScriptService/ChestChaseServer/Config.lua "Config.DefaultSpeed = Config.SpeedFloor" "Config.DefaultSpeed = 0" server
mutant list_raw ServerScriptService/ChestChaseServer/PlayerDataService.lua "name=='Speed'and require(RS.SpeedDisplay).PlayerList(value.Value)or require(RS.CashNumbers).PlayerList(value.Value)" "require(RS.CashNumbers).PlayerList(value.Value)" server
echo "R158i speed suite passed"
