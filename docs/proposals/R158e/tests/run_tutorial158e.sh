#!/bin/sh
# Usage: sh run_tutorial158e.sh [scratch dir]. R158e (owner: "shorten it even more ... a red arrow that points players towards the pack when they spawn ... the track tp button ...
# steal ... the visual mouse indicator ... tp back to base ... plant ... the first fruit is always 10 seconds ... harvest and sell ... the treadmill makes them run faster and every
# 6 mins gives them a bonus roll ... EVERYTHING ... must be visual so no words all just arrows and pointing"), on the Roblox mock with the real scripts of this checkout:
#  static              - line 1 of the tutorial client is the load guard; the frozen files are byte-identical (R151 frozen.sha256); no function over 180 registers (check_compile_O0);
#                        the client has no card / skip / avatar / confetti / chevrons / beam / ring / key bubble / sound left and writes no bonus clock; BeginnerGuide has no card code;
#                        the server refuses the 'Skip' request;
#  test_guide_flow     - the saved steps (old masks -> new steps), events only in their turn, Resolve over every moment (R158g: step 10 goes on to the BONUS ROLL arrow), a look is only
#                        pointers (one purpose each, no icon / row / bubble), no skip action, the 10-second first fruit (pure);
#  test_tutorial       - the client on a perspective camera (R158g): at every moment EXACTLY the pointers it wants: for a world goal ONE arrow (over it when near and on screen, the big
#                        floating arrow when far and in sight, the edge arrow when it would be out of sight: in no frame two of them), a red arrow + pressing hand on a screen button
#                        (BONUS ROLL: the arrow alone), the hand on the dirt, the small ring timer, the clicking hand; and NOTHING else: no card, no word, nothing to click (no skip), no
#                        sound, no chevrons / beam / ring; Reduced Motion, no writes while hidden or idle, phone, finish, returning players, the owner's reset;
#  test_tutorial158e   - the server on the real player data: the ten steps, only a stolen pack ticks the steal step (any pack opens), the first fruit in 10 s once, the Skip request
#                        refused (nothing changes), old saves;
#  teeth               - mutants of the real scripts that each of the checks above must catch (a skip button back, a word on the clicking hand, two arrows for one goal, no hovering
#                        arrow, a look with two purposes, any pack ticking the steal step, the quick fruit twice, the Skip request accepted, all fruit quick, the other fruit jumping at 10 s; R158i: the free roll not given at step 10, lost at the 2-ready cap, never promoted, the flag spent on a throw).
#                        Skip them with TEETH=0.
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
if sed 's/--.*$//' "$C/BeginnerTutorial.client.lua" | grep -nE "6:00|IntervalSeconds|GuideCard|StepPill|'Skip'|Confetti|InteractionAudio|TutorialCardBottom|GoalBeam|GoalSpot|'Avatar'|GetUserThumbnailAsync";then fail "a piece of the card, the skip, a sound or the bonus clock is back in the client";fi
if sed 's/--.*$//' "$RSD/BeginnerGuide.lua" | grep -nE "Title *=|Chip *=|EquippedTitle|'NICE|YOU GOT|PACKS COMING|G[.]Card|G[.]Obstacles|G[.]Nice|G[.]Finished|G[.]Progress|G[.]Clock|Icon=|Row=|Rows=|action=='Skip'";then fail "a tutorial word, the card or the skip is back in BeginnerGuide";fi
grep -q "if action=='Skip'then return false end" "$SRV/TutorialProgress.lua" || fail "TutorialAction must refuse the Skip request"
if sed 's/--.*$//' "$SRV/PremiumService.lua" | grep -n "'Skip'";then fail "PremiumService has a Skip path";fi
grep -q "playerData.TreadmillBonus = treadmillBonus" "$S/ServerScriptService/ChestChaseServerMain.server.lua" || fail "ChestChaseServerMain must hand the bonus service to the player data (the tutorial's free roll)"
if sed 's/--.*$//' "$C/BeginnerTutorial.client.lua" | grep -n "BonusGift";then fail "R158i: the client must not ask for the free bonus roll (the server gives it at step 10)";fi
sed 's/--.*$//' "$SRV/TutorialProgress.lua" | grep -q "if not state.Done and not state.Bonus and G.Step(state)==10 then self:TutorialBonusGift(player)end" || fail "R158i: PublishTutorial must give the free roll at step 10"
sed 's/--.*$//' "$SRV/TutorialProgress.lua" | grep -q "bonus.GrantGift" || fail "R158i: the free roll must go through TreadmillBonusService:GrantGift"
if sed 's/--.*$//' "$SRV/PremiumService.lua" | grep -n "BonusGift";then fail "R158i: PremiumService must not know the free roll (no request is needed)";fi
echo "ok: no card, no skip (the server refuses it), no sound, no bonus clock in the tutorial; the free bonus roll is the server's (step 10), no client ask"
prep_client() { # $1 = a src tree, $2 = the run dir
 mkdir -p "$2";cp "$T/roblox.luau" "$T/test_tutorial.luau" "$T/test_guide_flow.luau" "$2/"
 cp "$1/ReplicatedStorage/BeginnerGuide.lua" "$2/new_Guide.luau";cp "$1/ReplicatedStorage/HudLayout.lua" "$2/Hud.luau"
 python3 "$T/bundle.py" "$2/tut_bundle.luau" BeginnerTutorial="$1/StarterPlayer/StarterPlayerScripts/BeginnerTutorial.client.lua" BeginnerGuide="$1/ReplicatedStorage/BeginnerGuide.lua" HudLayout="$1/ReplicatedStorage/HudLayout.lua" PropCache152="$1/ReplicatedStorage/PropCache152.lua" >/dev/null
}
prep_server() { # $1 = a src tree, $2 = the run dir
 mkdir -p "$2";cp "$T/roblox.luau" "$TB/world.luau" "$HERE/test_tutorial158e.luau" "$2/"
 sed "s#'../../../../src'#'$1'#" "$TB/mkbundle.py" > "$2/mkbundle.py";python3 "$2/mkbundle.py" "$2" >/dev/null
}
run_client() { (cd "$1" && /opt/luau/luau test_guide_flow.luau > flow.log 2>&1;grep -q 'FLOW OK' flow.log) && (cd "$1" && /opt/luau/luau test_tutorial.luau > tut.log 2>&1;grep -q ', 0 failures' tut.log); }
run_server() { (cd "$1" && timeout 600 /opt/luau/luau test_tutorial158e.luau > server.log 2>&1); }
prep_client "$S" "$OUT/client";prep_server "$S" "$OUT/server"
echo "== test_guide_flow / test_tutorial"
run_client "$OUT/client" || { for f in flow tut;do grep -h 'FAIL' "$OUT/client/$f.log" | head -20;tail -2 "$OUT/client/$f.log";done;fail "client tests"; }
tail -1 "$OUT/client/flow.log";tail -1 "$OUT/client/tut.log"
echo "== test_tutorial158e"
run_server "$OUT/server" || { grep -v '^WARN' "$OUT/server/server.log" | tail -25;fail "server test"; }
grep '^INFO' "$OUT/server/server.log" || true
grep -v '^WARN' "$OUT/server/server.log" | tail -1
[ "${TEETH:-1}" = 0 ] && { echo "R158i tutorial suite passed (teeth skipped)";exit 0; }
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
mutant skip_button StarterPlayer/StarterPlayerScripts/BeginnerTutorial.client.lua "local tap=frame(tapGui,'TapHand',20);tap.Size=UDim2.fromScale(1,1);tap.Visible=false" "local tap=frame(tapGui,'TapHand',20);tap.Size=UDim2.fromScale(1,1);tap.Visible=false;do local sk=Instance.new('TextButton');sk.Name='Skip';sk.Parent=tapGui end" client
mutant clicking_word ReplicatedStorage/BeginnerGuide.lua "Gamepad={Hand='🎮',Key='R2'}" "Gamepad={Hand='🎮',Key='SKIP'}" client
mutant two_arrows StarterPlayer/StarterPlayerScripts/BeginnerTutorial.client.lua "if mode=='Edge'or(over and look.Timer)then parkArrow()else drawArrow(root,target,now,over)end" "if over and look.Timer then parkArrow()else drawArrow(root,target,now,over)end" client
mutant never_over StarterPlayer/StarterPlayerScripts/BeginnerTutorial.client.lua "if onScreen and dist<(S.mode=='Over'and Guide.NearArrow+4 or Guide.NearArrow)then return'Over'end" "if false then return'Over'end" client
mutant two_purposes ReplicatedStorage/BeginnerGuide.lua "Track={Step=2,Button='TrackButton'}," "Track={Step=2,Button='TrackButton',World='Pack'}," client
mutant bonus_twice ServerScriptService/ChestChaseServer/TutorialProgress.lua "state.Done or state.Bonus or G.Step(state)~=10" "state.Done or G.Step(state)~=10" server
mutant bonus_any_step ServerScriptService/ChestChaseServer/TutorialProgress.lua "state.Done or state.Bonus or G.Step(state)~=10" "state.Done or state.Bonus" server
mutant bonus_not_on_step10 ServerScriptService/ChestChaseServer/TutorialProgress.lua "if not state.Done and not state.Bonus and G.Step(state)==10 then self:TutorialBonusGift(player)end" "" server
mutant bonus_lost_at_cap ServerScriptService/ChestChaseServer/TreadmillBonusService.lua " self.Pending[player]=true;self.Data:GetPremium(player)[PENDING_FIELD]=true;self.Data:MarkDirty(player);self:_publish(player)
 return true,'pending'" " return true,'full'" server
mutant bonus_never_promoted ServerScriptService/ChestChaseServer/TreadmillBonusService.lua " self:_promote(player) -- R158i: a gift roll that was waiting for room" " -- (mutant)" server
mutant bonus_flag_spent_on_throw ServerScriptService/ChestChaseServer/TutorialProgress.lua "if not ok or not granted then state.Bonus=nil;return false end" "if not ok or not granted then return false end" server
mutant skip_accepted ServerScriptService/ChestChaseServer/TutorialProgress.lua "if action=='Skip'then return false end" "if action=='Skip'then local pr=self:GetPremium(player);pr.Tutorial=pr.Tutorial or G.Read();pr.Tutorial.Done=true;changed(self,player);return true end" server
mutant gift_ticks_steal ServerScriptService/ChestChaseServer/PlayerDataService.lua "if type(options) == \"table\" and options.Banked == true then self:TutorialEvent(player,'Pack') end" "self:TutorialEvent(player,'Pack')" server
mutant fast_twice ServerScriptService/ChestChaseServer/TutorialProgress.lua "if not state or state.Done or state.Fast or G.Step(state)~=6 then return false end" "if not state or state.Done or G.Step(state)~=6 then return false end" server
mutant early_fruit_jump ReplicatedStorage/PlantGrowth.lua "local early=own and own.Duration and readyAt-own.Duration<=start" "local early=false" server
mutant fast_all_fruit ReplicatedStorage/BeginnerGuide.lua "if count>1 and def.Mode~='whole'and def.Regrows~=false then" "if false then" client
echo "R158i tutorial suite passed"
