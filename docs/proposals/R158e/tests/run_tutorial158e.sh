#!/bin/sh
# Usage: sh run_tutorial158e.sh [scratch dir]. R158e (owner: "shorten it even more ... a red arrow that points players towards the pack when they spawn ... the track tp button ...
# steal ... the visual mouse indicator ... tp back to base ... plant ... the first fruit is always 10 seconds ... harvest and sell ... the treadmill makes them run faster and every
# 6 mins gives them a bonus roll ... EVERYTHING ... must be visual so no words all just arrows and pointing"), on the Roblox mock with the real scripts of this checkout:
#  static              - line 1 of the tutorial client is the load guard; the frozen files are byte-identical (R151 frozen.sha256); no function over 180 registers (check_compile_O0);
#                        the bonus interval is read, never written in the client; BeginnerGuide has no title / chip words left;
#  test_guide_flow     - the saved steps (old masks -> new steps), events only in their turn, Resolve over every moment, NO WORD in any look on any device, key glyphs only in key caps,
#                        the clock, the 10-second first fruit (pure);
#  test_guide_layout   - the card on 26 screens (one and two picture rows) clear of the HUD and your character;
#  test_tutorial       - the client: the ten steps one at a time with every pointer, no word on screen at any moment, skip, finish, Reduced Motion, no writes
#                        while hidden or idle, phone safe area, returning players;
#  test_tutorial158e   - the server on the real player data: the ten steps, only a stolen pack ticks the steal step (any pack opens), the first fruit in 10 s once, old saves;
#  teeth               - mutants of the real scripts that each of the checks above must catch (a word on the ⏭, a word in a look, any pack ticking the steal step, the quick fruit twice,
#                        a hard-coded 6:00, all fruit quick, the other fruit jumping at 10 s).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
S=$REPO/src;C=$S/StarterPlayer/StarterPlayerScripts;RSD=$S/ReplicatedStorage;SRV=$S/ServerScriptService/ChestChaseServer;T=$REPO/tools/tests
TB=$REPO/docs/proposals/treadmill_bonus_R123/tests
fail(){ echo "FAIL: $*";exit 1; }
echo "== static"
[ "$(head -1 "$C/BeginnerTutorial.client.lua")" = "do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)" ] || fail "line 1 of BeginnerTutorial is not the load guard"
(cd "$REPO" && grep -v '^#' docs/proposals/R151/tests/frozen.sha256 | sha256sum -c --quiet) || fail "a frozen file changed"
echo "ok: the frozen files are byte-identical"
sh "$T/check_compile_O0.sh" "$REPO" > "$OUT/o0.log" 2>&1 || { tail -5 "$OUT/o0.log";fail "check_compile_O0"; }
tail -1 "$OUT/o0.log"
if sed 's/--.*$//' "$C/BeginnerTutorial.client.lua" | grep -nE "6:00|IntervalSeconds *(=|or) *[0-9]|Clock[(] *360|'360'";then fail "the client writes the bonus interval itself";fi
if grep -nE "Title *=|Chip *=|EquippedTitle|'NICE|YOU GOT|PACKS COMING" "$RSD/BeginnerGuide.lua";then fail "a tutorial word is left in BeginnerGuide";fi
echo "ok: no title / chip words, the interval is read"
prep_client() { # $1 = a src tree, $2 = the run dir
 mkdir -p "$2";cp "$T/roblox.luau" "$T/test_tutorial.luau" "$T/test_guide_flow.luau" "$T/test_guide_layout.luau" "$2/"
 cp "$1/ReplicatedStorage/BeginnerGuide.lua" "$2/new_Guide.luau";cp "$1/ReplicatedStorage/HudLayout.lua" "$2/Hud.luau"
 python3 "$T/bundle.py" "$2/tut_bundle.luau" BeginnerTutorial="$1/StarterPlayer/StarterPlayerScripts/BeginnerTutorial.client.lua" BeginnerGuide="$1/ReplicatedStorage/BeginnerGuide.lua" HudLayout="$1/ReplicatedStorage/HudLayout.lua" PropCache152="$1/ReplicatedStorage/PropCache152.lua" >/dev/null
}
prep_server() { # $1 = a src tree, $2 = the run dir
 mkdir -p "$2";cp "$T/roblox.luau" "$TB/world.luau" "$HERE/test_tutorial158e.luau" "$2/"
 sed "s#'../../../../src'#'$1'#" "$TB/mkbundle.py" > "$2/mkbundle.py";python3 "$2/mkbundle.py" "$2" >/dev/null
}
run_client() { (cd "$1" && /opt/luau/luau test_guide_flow.luau > flow.log 2>&1;grep -q 'FLOW OK' flow.log) && (cd "$1" && /opt/luau/luau test_guide_layout.luau > layout.log 2>&1;grep -q 'ALL PASS' layout.log) && (cd "$1" && /opt/luau/luau test_tutorial.luau > tut.log 2>&1;grep -q ', 0 failures' tut.log); }
run_server() { (cd "$1" && timeout 600 /opt/luau/luau test_tutorial158e.luau > server.log 2>&1); }
prep_client "$S" "$OUT/client";prep_server "$S" "$OUT/server"
echo "== test_guide_flow / test_guide_layout / test_tutorial"
run_client "$OUT/client" || { for f in flow layout tut;do grep -h 'FAIL' "$OUT/client/$f.log" | head -20;tail -2 "$OUT/client/$f.log";done;fail "client tests"; }
tail -1 "$OUT/client/flow.log";tail -1 "$OUT/client/layout.log";tail -1 "$OUT/client/tut.log"
echo "== test_tutorial158e"
run_server "$OUT/server" || { grep -v '^WARN' "$OUT/server/server.log" | tail -25;fail "server test"; }
grep '^INFO' "$OUT/server/server.log" || true
grep -v '^WARN' "$OUT/server/server.log" | tail -1
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
mutant skip_word StarterPlayer/StarterPlayerScripts/BeginnerTutorial.client.lua "U.skip.Text='⏭'" "U.skip.Text='SKIP'" client
mutant look_word ReplicatedStorage/BeginnerGuide.lua "Row={'🏃','➜','🎒'}" "Row={'GO','➜','🎒'}" client
mutant clock_written StarterPlayer/StarterPlayerScripts/BeginnerTutorial.client.lua "return seconds and Guide.Clock(seconds)or''" "return'6:00'" client
mutant gift_ticks_steal ServerScriptService/ChestChaseServer/PlayerDataService.lua "if type(options) == \"table\" and options.Banked == true then self:TutorialEvent(player,'Pack') end" "self:TutorialEvent(player,'Pack')" server
mutant fast_twice ServerScriptService/ChestChaseServer/TutorialProgress.lua "if not state or state.Done or state.Fast or G.Step(state)~=6 then return false end" "if not state or state.Done or G.Step(state)~=6 then return false end" server
mutant early_fruit_jump ReplicatedStorage/PlantGrowth.lua "local early=own and own.Duration and readyAt-own.Duration<=start" "local early=false" server
mutant fast_all_fruit ReplicatedStorage/BeginnerGuide.lua "if count>1 and def.Mode~='whole'and def.Regrows~=false then" "if false then" client
echo "R158e tutorial suite passed"
