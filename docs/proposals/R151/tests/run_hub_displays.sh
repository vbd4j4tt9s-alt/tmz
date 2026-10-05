#!/bin/sh
# Usage: sh run_hub_displays.sh [scratch dir] [mutate] [place.rbxl]
# R151 (owner: "a best pull today display onto one of the empty corners of the map and a biggest fruit display on the other side ... that rotates every day ... a giant
# display and the persons avatar will be standing beside it"): the two hub displays, on the Roblox mock with the real scripts (every module bundled from THIS checkout's src):
#  wiring                - the files, src/MANIFEST.tsv, the hooks in PlayerDataService / ChestService, the main script, the owner commands and docs/COMMANDS.md; no DataStore,
#                          no per-frame server loop in the hub scripts; the gameplay files (odds, economy, daily rewards, plant catalog, Config: ProfileVersion 22) are unchanged;
#  test_hub_rules.luau   - the ranking (rarity, then smaller chance, then bigger weight, then earlier: a strict total order), the exclusions' building blocks (record cleaning), the UTC day,
#                          the fruit rotation (one fruit a day, no quick repeats, only weighted fruit), the sign texts, the layout numbers;
#  test_hub_store.luau   - the MemoryStore wrapper against a mock of the shared backend: compare-and-set races, expiry, quota / throttle / errors (backoff, budget), pcall everywhere;
#  test_hub_service.luau - the service: events, ranking across servers (two servers on one backend), polling with jitter, one write per gap, the day rollover, the record line
#                          (ONE PullAnnouncer.Announce, no notice of its own, AfterReveal for a pull, the chime in step, private owner tests), the owner tools, fallback to the server's
#                          own best, a champion change rebuilds once;
#  test_hub_avatar.luau  - the avatar: description cache, rig build, pose, scale, anchored / inert, no name or health bar, the blocky fallback, user ids that are not users;
#  test_hub_art.luau     - the frame and the giant item (cap 150 parts, 8-12 studs tall, rarity colours), the layout against the map's pieces, collisions, sizes;
#  test_hub_client.luau  - the client: near / far, motion only near, reduced motion, quality tiers, streaming, the pop and the sound, nothing per frame when far;
#  test_hub_hooks.luau   - how it is wired into the game: the pack-opened hook, TEST packs and owner grants never count, the harvest hook, the owner commands; and the REAL PullAnnouncer
#                          behind the real hub: a real Mythic / Secret open says the pull line then the record line only after the puller's reveal (other servers too), no hub notice,
#                          owner test packs / bestpull / bigfruit never speak to the server, a leaving puller, a fruit record, a preview day;
#  check_hub_scene.py    - the displays in the FINISHED hub of the owner's place file (build_hub_scenes.sh): the R149 z-fight detector finds nothing on the frame, nothing overlaps
#                          the map, 40+ studs from every other piece, each sign faces the market and is in plain view from the spawns, part counts (needs the place file; skipped without).
# The older suites that touch the changed files, and R149's whole-map z-fight check (R149/tests/run_zfight.sh), are run by their own scripts.
# With "mutate" as the 2nd argument, broken copies of src must each make a check fail (the tests have teeth; ONLY=<words of one mutation's name> runs just that one).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=$2;PLACE=${3:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl}
mkdir -p "$OUT"
S=$REPO/src;SRV=$S/ServerScriptService/ChestChaseServer
prep() { # $1 = src dir, $2 = work dir (the suites on the R150 pedestal world)
 mkdir -p "$2"
 cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/inventory_R113/tests/fixtures.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$REPO/docs/proposals/R150/tests/pedestal_harness.luau" "$2/"
 cp "$HERE/hub_rig.luau" "$HERE/hub_harness.luau" "$HERE"/test_hub_rules.luau "$HERE"/test_hub_store.luau "$HERE"/test_hub_service.luau "$HERE"/test_hub_avatar.luau "$HERE"/test_hub_art.luau "$HERE"/test_hub_client.luau "$2/"
 python3 "$HERE/bundle_hub.py" "$1" "$2" >/dev/null
}
prep_hooks() { # the hook suite runs on the R123 world (the real PlayerDataService / ChestService need its Config fixtures)
 mkdir -p "$2"
 cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$HERE/test_hub_hooks.luau" "$HERE/announce_env.luau" "$2/"
 python3 "$HERE/bundle_hub.py" "$1" "$2" >/dev/null
}
suite() { # $1 = work dir, $2 = test, $3 = log
 (cd "$1" && timeout 600 /opt/luau/luau "$2" > "$3" 2>&1) || { tail -25 "$3";return 1; }
 tail -1 "$3"
}
scene() { # $1 = scratch dir for the scene build: builds the finished hub twice and checks it
 [ -f "$PLACE" ] || { echo "SKIPPED (no place file at $PLACE)";return 0; }
 mkdir -p "$1"
 sh "$HERE/build_hub_scenes.sh" "$1" "$PLACE" > "$1/build.log" 2>&1 || { tail -20 "$1/build.log";return 1; }
 (cd "$1/scene" && python3 "$HERE/check_hub_scene.py" scene_empty.json scene_champions.json champions.steps place_geom.json > "$1/check.log" 2>&1) || { tail -30 "$1/check.log";return 1; }
 tail -1 "$1/check.log"
}
wiring() {
 for f in ReplicatedStorage/HubDisplayRules ReplicatedStorage/HubAvatarPose ServerScriptService/ChestChaseServer/HubDisplayArt ServerScriptService/ChestChaseServer/HubDisplayAvatar ServerScriptService/ChestChaseServer/HubDisplayBoard ServerScriptService/ChestChaseServer/HubDisplayService ServerScriptService/ChestChaseServer/HubDisplayStore StarterPlayer/StarterPlayerScripts/HubDisplayClient;do
  test -f "$S/$f.lua" -o -f "$S/$f.client.lua" || { echo "missing $f";return 1; }
  grep -q "	$f	" "$S/MANIFEST.tsv" || { echo "$f is not in src/MANIFEST.tsv";return 1; }
 done
 grep -q "HubDisplayClient	StarterPlayer/StarterPlayerScripts/HubDisplayClient.client.lua" "$S/MANIFEST.tsv" || { echo "the client script's manifest row is wrong";return 1; }
 M=$S/ServerScriptService/ChestChaseServerMain.server.lua
 grep -q "modules.HubDisplayService).new(" "$M" && grep -q ":Start()" "$M" && grep -q "playerData.OnPackOpened=" "$M" && grep -q "chestService.HarvestHook=" "$M" && grep -q "chaseService.HubDisplays=hubDisplays" "$M" || { echo "the main script does not build / start / hook up / expose the displays";return 1; }
 grep -q "OnPackOpened" "$SRV/PlayerDataService.lua" || { echo "PlayerDataService has no pack-opened hook";return 1; }
 grep -q "HarvestHook" "$SRV/ChestService.lua" || { echo "ChestService has no harvest hook";return 1; }
 for w in bestpull bigfruit hubdisplays;do
  grep -q "$w" "$SRV/OwnerUpdateCommands82.lua" || { echo "owner command $w missing";return 1; }
  grep -q "$w" "$REPO/docs/COMMANDS.md" || { echo "$w is not in docs/COMMANDS.md";return 1; }
  grep -q "$w" "$S/ReplicatedStorage/StudioTestHelp.lua" || { echo "$w is not in the F4 help";return 1; }
 done
 grep -q "hubdisplays" "$SRV/OwnerCommandTargets82.lua" || { echo "hubdisplays is not a server-wide command";return 1; }
 # the hub scripts use MemoryStore only (no DataStore: saves are untouched) and no per-frame loop on the server
 for f in HubDisplayStore HubDisplayBoard HubDisplayService HubDisplayArt HubDisplayAvatar;do
  if grep -q "DataStore" "$SRV/$f.lua";then echo "$f touches a DataStore";return 1;fi
  if grep -q -E "Heartbeat|RenderStepped|Stepped" "$SRV/$f.lua";then echo "$f has a per-frame loop";return 1;fi
 done
 grep -q "MemoryStoreService" "$SRV/HubDisplayStore.lua" || { echo "the store does not use MemoryStoreService";return 1; }
 # saves / economy / odds unchanged: ProfileVersion and the version string are the base's, and the gameplay files are byte-identical (sha256 list)
 grep -q "Config.ProfileVersion=22" "$SRV/Config.lua" && grep -q "Config.Version='V150 R151'" "$SRV/Config.lua" || { echo "Config.ProfileVersion / Version changed";return 1; }
 (cd "$REPO" && sha256sum -c "$HERE/frozen.sha256" > "$OUT/frozen.log" 2>&1) || { cat "$OUT/frozen.log";return 1; }
 echo "wiring ok ($(wc -l < "$HERE/frozen.sha256") gameplay files byte-identical)"
}
if [ "$MODE" != "mutate" ];then
 echo "== wiring";wiring
 prep "$S" "$OUT/w";prep_hooks "$S" "$OUT/h"
 echo "== test_hub_rules";suite "$OUT/w" test_hub_rules.luau "$OUT/rules.log"
 echo "== test_hub_store";suite "$OUT/w" test_hub_store.luau "$OUT/store.log"
 echo "== test_hub_service";suite "$OUT/w" test_hub_service.luau "$OUT/service.log"
 echo "== test_hub_avatar";suite "$OUT/w" test_hub_avatar.luau "$OUT/avatar.log"
 echo "== test_hub_art";suite "$OUT/w" test_hub_art.luau "$OUT/art.log"
 echo "== test_hub_client";suite "$OUT/w" test_hub_client.luau "$OUT/client.log"
 echo "== test_hub_hooks";suite "$OUT/h" test_hub_hooks.luau "$OUT/hooks.log"
 echo "== the displays in the finished hub (z-fighting, placement, signs, size)";scene "$OUT/s"
 exit 0
fi
# --- mutation checks: break one thing at a time in a copy of src; the named check must fail ----------------------------------------------------------------
M=$OUT/mut_src;caught=0;total=0
mutate() { # $1 = name, $2 = file under src, $3 = old text, $4 = new text, $5 = the check that must catch it: rules | store | service | avatar | art | client | hooks | scene
 if [ -n "$ONLY" ];then case "$1" in *"$ONLY"*);;*) return 0;; esac;fi # (ONLY=<words of a mutation's name> runs just that one)
 rm -rf "$M";mkdir -p "$M";cp -r "$S/." "$M/"
 python3 - "$M/$2" "$3" "$4" <<'PY'
import sys
p,old,new=sys.argv[1:4]
s=open(p,encoding='utf-8').read()
assert s.count(old)>=1,'mutation target not found: '+old
open(p,'w',encoding='utf-8').write(s.replace(old,new,1))
PY
 total=$((total+1))
 case "$5" in
  hooks) prep_hooks "$M" "$OUT/mh" 2>/dev/null;(cd "$OUT/mh" && timeout 600 /opt/luau/luau test_hub_hooks.luau) >"$OUT/mut.log" 2>&1 && r=0 || r=1;;
  scene) rm -rf "$OUT/ms";mkdir -p "$OUT/ms"
   if [ ! -f "$PLACE" ];then echo "mutation skipped (no place file): $1";total=$((total-1));return 0;fi
   # the scene build bundles src from $REPO/src: point it at the mutated copy
   (sh "$HERE/build_hub_scenes.sh" "$OUT/ms" "$PLACE" "$M") >"$OUT/mut.log" 2>&1 && (cd "$OUT/ms/scene" && python3 "$HERE/check_hub_scene.py" scene_empty.json scene_champions.json champions.steps place_geom.json) >>"$OUT/mut.log" 2>&1 && r=0 || r=1;;
  *) prep "$M" "$OUT/mw" 2>/dev/null;(cd "$OUT/mw" && timeout 600 /opt/luau/luau test_hub_$5.luau) >"$OUT/mut.log" 2>&1 && r=0 || r=1;;
 esac
 if [ "$r" = 0 ];then echo "MUTATION SURVIVED: $1";else echo "mutation caught: $1";caught=$((caught+1));fi
}
RU=ReplicatedStorage/HubDisplayRules.lua;ST=ServerScriptService/ChestChaseServer/HubDisplayStore.lua;SV=ServerScriptService/ChestChaseServer/HubDisplayService.lua
AR=ServerScriptService/ChestChaseServer/HubDisplayArt.lua;AV=ServerScriptService/ChestChaseServer/HubDisplayAvatar.lua;CL=StarterPlayer/StarterPlayerScripts/HubDisplayClient.client.lua
mutate "the lower rarity wins a pull" $RU "if a.Rank~=b.Rank then return a.Rank>b.Rank end" "if a.Rank~=b.Rank then return a.Rank<b.Rank end" rules
mutate "the likelier pull wins a rarity tie" $RU "if not same(a.Odds,b.Odds)then return a.Odds<b.Odds end" "if not same(a.Odds,b.Odds)then return a.Odds>b.Odds end" rules
mutate "the later pull wins a full tie" $RU "if a.At~=b.At then return a.At<b.At end" "if a.At~=b.At then return a.At>b.At end" rules
mutate "the lighter fruit wins" $RU "if not same(a.Kg,b.Kg)then return a.Kg>b.Kg end
 if a.At~=b.At then return a.At<b.At end
 if a.Uid~=b.Uid then return a.Uid<b.Uid end
 if a.Coat" "if not same(a.Kg,b.Kg)then return a.Kg<b.Kg end
 if a.At~=b.At then return a.At<b.At end
 if a.Uid~=b.Uid then return a.Uid<b.Uid end
 if a.Coat" rules
mutate "the same fruit comes two days in a row" $RU "local index=(math.floor(day)*step)%n+1" "local index=(math.floor(day//2)*step)%n+1" rules
mutate "the board's day is off by one" $RU "function R.Day(t)return D.Day(t)end" "function R.Day(t)return D.Day(t)+1 end" rules
mutate "limited-time plants can be the fruit of the day" $RU "return verity.Is(id)or mech.Is(id)" "return false" rules
mutate "a stored record may claim any rank" $RU "local rec={Uid=uid,Name=name,Id=id,Seed=seed,Rarity=v.Rarity,Rank=style.Rank," "local rec={Uid=uid,Name=name,Id=id,Seed=seed,Rarity=v.Rarity,Rank=tonumber(v.Rank)or style.Rank," rules
mutate "the store overwrites a better record (no compare-and-set)" $ST "if current and not Rules.Better(kind,rec,current)then took=false;return nil end" "" store
mutate "a failed request does not back off" $ST "self.NextTryAt=self.Clock()+wait" "self.NextTryAt=0" store
mutate "the request budget is not kept" $ST "if #self.Calls>=Rules.RequestsPerMinute then return false,'budget'end" "" store
mutate "a store error escapes (no pcall)" $ST "local ok,a,b=pcall(fn,map)" "local ok,a,b=true,fn(map)" store
mutate "a TEST pack counts" $SV "if info.Test==true then return false,'test pack'end" "" service
mutate "an owner-granted seed counts" $SV "if self.Tainted[player]then return false,'owner-granted'end" "" service
mutate "a pull record is announced before the puller's reveal" $SV "elseif kind=='Pull'then spec.AfterReveal=true end" "elseif false then spec.AfterReveal=true end" service
mutate "an owner's bestpull is announced to the whole server" $SV "  spec.To=player" "  spec.To=nil" service
mutate "a preview day announces its records" $SV " if self:_preview()then return false end" "" service
mutate "the hub shows a notice of its own again" $SV " self:_celebrate(kind,rec,wait,spec.To)" " pcall(function()self.Notes:Show(player,'x',nil,5)end);self:_celebrate(kind,rec,wait,spec.To)" service
mutate "the chime plays before the line" $SV "if type(wait)=='number'and wait>0 then task.delay(wait,fire)else fire()end" "fire()" service
mutate "a refused record uses up the gap" $SV " local called,ok,wait=pcall(self.Announce,spec)" " self.LastNotice[kind]=now;local called,ok,wait=pcall(self.Announce,spec)" service
mutate "an announcer that throws breaks the event" $SV " local called,ok,wait=pcall(self.Announce,spec)" " local called,ok,wait=true,self.Announce(spec)" service
mutate "an owner-made (TestGrant) pack counts as a real pull" ServerScriptService/ChestChaseServer/PlayerDataService.lua "Test=testSeed~=nil or pack.TestGrant==true" "Test=testSeed~=nil" hooks
mutate "the display is rebuilt on every refresh" $SV "if key==self.Shown[kind]and not force then return false end" "" service
mutate "a stale item build is not dropped" $SV "function S:_stale(kind,gen)return self.Dead or self.Gen[kind]~=gen end" "function S:_stale(kind,gen)return self.Dead end" service
mutate "the shared board is read at every step" $SV "self.NextPoll=now+Rules.PollSeconds+self.Random:NextNumber()*Rules.PollJitter" "self.NextPoll=now" service
mutate "the shared board is written at every step" $SV "if now>=self.NextWrite and self:_needsWrite()then" "if self:_needsWrite()then" service
mutate "the avatar is built for any id" $AV "if type(userId)~='number'or userId~=userId or userId<=0 or userId%1~=0 then return nil,'not a real user id'end" "" avatar
mutate "the avatar description is not cached" $AV "local hit=self.Cache[userId];if hit then return hit end" "local hit=nil" avatar
mutate "the giant item has no part cap" $AR "if #list<=limit then return 0 end" "if true then return 0 end" art
mutate "the giant item is solid" $AR "item.Anchored=true;item.CanCollide=false;item.CanQuery=false" "item.Anchored=true;item.CanCollide=true;item.CanQuery=false" art
mutate "reduced motion still moves the display" $CL "local allowed=not reduced()and tier()>=2" "local allowed=tier()>=2" client
mutate "far displays move too" $CL "local active=allowed and(wasActive and d<=NEAR_OUT or d<=NEAR_IN)" "local active=allowed" client
mutate "the lowest quality tier still gets the motion" $CL "local allowed=not reduced()and tier()>=2" "local allowed=not reduced()and tier()>=0" client
mutate "the pack-opened hook is gone" ServerScriptService/ChestChaseServer/PlayerDataService.lua "local hook=self.OnPackOpened" "local hook=nil" hooks
mutate "the harvest hook is gone" ServerScriptService/ChestChaseServer/ChestService.lua "if action == \"Harvest\" and self.HarvestHook then" "if false then" hooks
mutate "the Best Pull display stands in the Base 4 garden" $RU "Pull={Center=Vector3.new(236,4,-516)}," "Pull={Center=Vector3.new(180,4,-440)}," scene
mutate "the sign frame lies in the board's plane (z-fighting)" $AR "part(back,'Sign frame',V3(B.W+1.2,B.H+1.6,B.Thick+.5),L(0,boardMid,B.Z+.5),GOLD)" "part(back,'Sign frame',V3(B.W+1.2,B.H+1.6,B.Thick),L(0,boardMid,B.Z),GOLD)" scene
echo "$caught of $total mutations caught"
[ "$caught" = "$total" ]
