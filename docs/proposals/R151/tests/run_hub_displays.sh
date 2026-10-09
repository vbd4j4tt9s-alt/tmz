#!/bin/sh
# Usage: sh run_hub_displays.sh [scratch dir] [mutate] [place.rbxl]
# R151 (owner: "a best pull today display onto one of the empty corners of the map and a biggest fruit display on the other side ... that rotates every day ... a giant
# display and the persons avatar will be standing beside it"): the two hub displays, on the Roblox mock with the real scripts (every module bundled from THIS checkout's src).
# R152 (owner: "the avatar is sized up and dancing while the seed rotates around and the effects are actually on the seed not behind ... a billboard is not needed ... the same format
# and look as the fruit of the hour type pedestal"): a display is the market's Fruit of the Hour pedestal built 3.2 times bigger (no board, no slab, no posts, no tube), the winning
# seed / fruit turning over its prongs with its light and sparkles ON it, and the champion's avatar, 25 studs tall, dancing on its Animator beside it:
# R153 (owner's Studio: the giant stood posed, then "violently shaking ... not on the ground", "or it would stop", "and freeze"; and of the plaque: "this detail here should be put on
# top of the fruit and it should be big"): each CLIENT plays the dance (the server only makes the rig ready: an Animator, joints at rest, the root alone anchored, the state machine off,
# DanceId; it plays nothing), retries with the next ids and poses the rig when it cannot, a watchdog keeps ONE looped track playing, nothing culls or freezes it, the soles stand on the
# floor through the joints, the same champion keeps its avatar, the clients report to the owner's `/test hubdisplays`; and the plaque is gone: ONE big label over the item says it all.
# R153 (owner: "make the best pull of the day refresh every 10 minutes and its a local server only thing to increase performance"): BEST PULL is each server's own board and lasts one
# wall-clock 10-minute window (os.time() // 600: :00, :10, :20 ...). Nothing about it is stored or sent: no MemoryStore, no save, no MessagingService (BIGGEST FRUIT is shared and daily, as it was).
# The mark empties the board and the avatar (the silhouette stands where the champion was; every client drops the dance), the label reads "BEST PULL" and "new board in 7:42", and its record
# line is told in this server only. check_best_pull_local.py (run by the wiring step) reads the sources for all of that; the suites below test it.
#  wiring                - the files, src/MANIFEST.tsv, the hooks in PlayerDataService / ChestService, the main script, the owner commands and docs/COMMANDS.md; no DataStore,
#                          no per-frame server loop in the hub scripts; the gameplay files (odds, economy, daily rewards, plant catalog, Config: ProfileVersion 22) are unchanged;
#                          R153: check_best_pull_local.py (no store / save / MessagingService for a best pull, a window clears the pull board alone, the loop sleeps through the mark);
#                          R153: the pull window numbers (os.time() // 600, 600 s, the end, the seconds left), "7:42", the footer words per board, a pull has no store form, the shared document
#                          holds the fruit only (an old `pull` in it is ignored), the pull board has no Remote and is never Unsynced, a window empties it alone, a day the fruit board alone;
#  test_hub_rules.luau   - the ranking (rarity, then smaller chance, then bigger weight, then earlier: a strict total order), the exclusions' building blocks (record cleaning), the UTC day,
#                          the fruit rotation (one fruit a day, no quick repeats, only weighted fruit), the plaque and label texts (title + winner + seed / weight, the fruit of the day, every
#                          one fits its row), the layout numbers (the reserved corner, the footprint, the 25 stud avatar);
#  test_hub_store.luau   - the MemoryStore wrapper against a mock of the shared backend: compare-and-set races, expiry, quota / throttle / errors (backoff, budget), pcall everywhere;
#                          R153: it is the fruit's alone: a pull is refused before any request, an old `pull` in the document is never read or written back or deleted;
#  test_hub_service.luau - the service: events, ranking across servers (two servers on one backend), polling with jitter, one write per gap, the day rollover, the record line
#                          (ONE PullAnnouncer.Announce, no notice of its own, AfterReveal for a pull, the chime in step, private owner tests), the owner tools, fallback to the server's
#                          own best, a champion change rebuilds once, the avatar is placed, put in the display and THEN made ready to dance (one that is overtaken is dropped); R153: the same
#                          champion keeps the avatar; the clients' dance reports (checked, rate-limited) and the owner's status line (AvatarMode, dance id, your screen's track and Length);
#                          R153: per server and per window: the board and the avatar clear at the :00 / :10 / :20 mark (the silhouette, the mystery seed, "Nobody yet", "new board in 10:00"), the fruit board
#                          stays, the next pull is the new record whatever the last window's was, a better pull replaces it, test packs / owner grants / injected tests, an empty board that stays empty is
#                          not rebuilt, a pull right after the mark is the new window's, the loop wakes at the mark, 48 windows leak no rig, item or table, a preview day leaves it alone, and a recording
#                          store + traps on DataStoreService / MessagingService / MemoryStoreService prove a pull never reaches them;
#  test_hub_avatar.luau  - the avatar: description cache, rig build, scale (Model:ScaleTo, 25 studs, 4-5 times a normal avatar; R153: the soles on the floor in the rest pose THROUGH THE
#                          JOINTS), anchored / inert, no name or health bar, READY TO DANCE (R153: an Animator, joints at rest and enabled, limbs unanchored, the state machine off, no
#                          server track, DanceId one of Roblox's three default R15 dances; the static pose only for a rig with nothing to dance with), the blocky fallback and the
#                          silhouette (the same giant size, static), user ids that are not users;
#  test_hub_art.luau     - the frame: just the Fruit of the Hour pedestal x 3.2 compared part by part with MarketLayout.Pedestal (no board, posts, slab, halo, disc or tube; R153: no plaque),
#                          the ONE big label (five rows, in studs, DistanceLowerLimit, over the item), the pedestal checked FACE BY FACE for z-fighting, inside the reserved corner and the footprint; the showcase item (cap 150 parts, 12 studs, over the prongs)
#                          with its light on an ItemCore inside it, nothing flat behind it;
#  test_hub_client.luau  - the client: near / far (260 / 300 studs), the item turns and floats, the sparkles are an emitter on the item's core; R153: the client plays ONE looped dance
#                          track on the rig's Animator (no joint writes while it plays), retries the next ids and then poses the rig here and cheers, the watchdog, nothing culls it,
#                          paused only with reduced motion / Fast Mode (never by the automatic tier), the same champion keeps its track, no leaks, the reports; the countdown on the label
#                          (R153: BEST PULL's "new board in 7:42" once a second near, every 5 s far, never negative); R153: the 10-minute mark drops the dance (track, Animator) and the silhouette stays, 12 cycles leak nothing;
#                          the burst on a new champion (no ring), the sound, nothing per frame when far;
#  test_hub_hooks.luau   - how it is wired into the game: the pack-opened hook, TEST packs and owner grants never count, the harvest hook, the owner commands (R153: bestpull refuses `share`); and the REAL
#                          PullAnnouncer behind the real hub: a real Mythic / Secret open says the pull line then the record line only after the puller's reveal (R153: the record in this server only,
#                          only a Secret's pull line goes to the other servers), the next window announces its record again, the mark says nothing, no hub notice,
#                          owner test packs / bestpull / bigfruit never speak to the server, a leaving puller, a fruit record, a preview day;
#  check_hub_scene.py    - the displays in the FINISHED hub of the owner's place file (build_hub_scenes.sh): the R149 z-fight detector finds nothing on the pedestal, nothing but a pedestal, an
#                          item and an avatar, inside the reserved corner and 30+ studs from the walls, nothing overlaps the map, 40+ studs from every other piece, the avatar 22-28 studs
#                          tall on the floor, each plaque faces the market and is in plain view from the spawns, part counts (needs the place file; skipped without).
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
 # R153: BEST PULL is this server's own: no store, no save, no MessagingService for it (the checker reads the sources)
 python3 -I "$HERE/check_best_pull_local.py" "$REPO" > "$OUT/local.log" 2>&1 || { cat "$OUT/local.log";return 1; }
 echo "wiring ok: best pull is local ($(grep -c '^ok:' "$OUT/local.log") static checks)"
 # saves / economy / odds unchanged: ProfileVersion and the version string are the base's, and the gameplay files are byte-identical (sha256 list)
 grep -q "Config.ProfileVersion=22" "$SRV/Config.lua" && grep -q "Config.Version='V150 R154'" "$SRV/Config.lua" || { echo "Config.ProfileVersion / Version changed";return 1; }
 (cd "$REPO" && sha256sum -c "$HERE/frozen.sha256" > "$OUT/frozen.log" 2>&1) || { cat "$OUT/frozen.log";return 1; }
 echo "wiring ok ($(grep -vc "^#" "$HERE/frozen.sha256") gameplay files byte-identical)"
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
BO=ServerScriptService/ChestChaseServer/HubDisplayBoard.lua
mutate "R153 best pull: a new window does not empty the pull board" $BO "self.Window=window;self.Boards.Pull=fresh()" "self.Window=window" rules
mutate "R153 best pull: a new window empties the fruit board too" $BO "self.Window=window;self.Boards.Pull=fresh()" "self.Window=window;self.Boards={Pull=fresh(),Fruit=fresh()}" rules
mutate "R153 best pull: a new day empties the pull board too" $BO "self.Day=day;self.FruitId=fruitId;self.Boards.Fruit=fresh()" "self.Day=day;self.FruitId=fruitId;self.Boards={Pull=fresh(),Fruit=fresh()}" rules
mutate "R153 best pull: a pull needs a shared write" $BO "function B:Unsynced(kind)
 if kind~='Fruit'then return false end" "function B:Unsynced(kind)
 if not valid(kind)then return false end" rules
mutate "R153 best pull: a shared pull becomes the champion" $BO "function B:MergeRemote(kind,rec)
 if kind~='Fruit'then return false end" "function B:MergeRemote(kind,rec)
 if not valid(kind)then return false end" rules
mutate "R153 best pull: the store takes a pull" $ST " if kind~='Fruit'then return false,'local only'end -- (R153: BEST PULL is this server's alone)" "" store
mutate "R153 best pull: the shared document keeps an old pull" $RU " if type(v.fruit)=='table'then out.fruit=R.CleanFruit(v.fruit)end
 return out" " if type(v.pull)=='table'then out.pull=R.CleanPull(v.pull)end
 if type(v.fruit)=='table'then out.fruit=R.CleanFruit(v.fruit)end
 return out" rules
mutate "R153 best pull: the window is not on the wall clock" $RU "function R.PullWindowIndex(t)return wholeSeconds(t)//R.PullWindow end" "function R.PullWindowIndex(t)return(wholeSeconds(t)+7)//R.PullWindow end" rules
mutate "R153 best pull: the window is a day" $RU "R.PullWindow=600 " "R.PullWindow=86400 " rules
mutate "R153 best pull: the countdown reads like the day's" $RU "function R.FooterCountdown(kind,seconds)return kind=='Pull'and R.WindowCountdown(seconds)or R.Countdown(seconds)end" "function R.FooterCountdown(kind,seconds)return R.Countdown(seconds)end" rules
mutate "R153 best pull: the title says today again" $RU "local title=kind=='Pull'and'BEST PULL'or'BIGGEST FRUIT TODAY'" "local title=kind=='Pull'and'BEST PULL TODAY'or'BIGGEST FRUIT TODAY'" rules
mutate "R153 best pull: the step does not look at the window" $SV " self:_syncWindow() -- (R153: before the preview check: the pull board has nothing to do with a previewed day)" "" service
mutate "R153 best pull: a pull right after the mark joins the old window" $SV " self:_syncWindow() -- (R153: a pull that comes right after a window mark is the new window's first, even before the loop has noticed the mark)" "" service
mutate "R153 best pull: an empty board is rebuilt at every window" $SV " if not self:_refresh('Pull')then self:_restamp('Pull')end" " self:_refresh('Pull',true)" service
mutate "R153 best pull: an empty window leaves the countdown stale" $SV " guard('sign',self.Art.SetSign,d,self:_text(kind,self.Board:Best(kind)))
 self:_stamp(kind)" " guard('sign',self.Art.SetSign,d,self:_text(kind,self.Board:Best(kind)))" service
mutate "R153 best pull: the pull's identity includes the window" $SV " local key=kind=='Pull'and Rules.Key(rec)or(" " local key=kind=='Pull'and Rules.Key(rec)..'|'..tostring(self.Board.Window)or(" service
mutate "R153 best pull: the loop sleeps through the mark" $SV " return math.min(S.LoopSeconds,left)" " return S.LoopSeconds" service
mutate "R153 best pull: a pull is offered to the shared store" $SV " self.Events[kind]+=1
" " self.Events[kind]+=1;if kind=='Pull'then pcall(self.Store.Merge,self.Store,self.Board.Day,kind,rec,nil)end
" service
mutate "R153 best pull: the client counts the pull's clock like the day's" $CL "Rules.FooterCountdown(entry.Model:GetAttribute('Kind'),at-now())" "Rules.Countdown(at-now())" client
mutate "R153 best pull: the client writes the pull's clock only every five seconds" $CL "if text or(entry.Distance~=nil and entry.Distance<=Rules.Label.MaxDistance and entry.Model:GetAttribute('Kind')=='Pull')then safe(entry,footer)end" "if text then safe(entry,footer)end" client
mutate "R153 best pull: the owner can share a best pull" ServerScriptService/ChestChaseServer/OwnerUpdateCommands82.lua "   if share then return false,'BEST PULL is this server only now" "   if false then return false,'BEST PULL is this server only now" hooks
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
mutate "another list's fruit is replaced by a heavier one" $ST "foreign=kind=='Fruit'and current~=nil and current.Id~=rec.Id" "foreign=false" store
mutate "a fruit board with another list's fruit stays unsynced for ever" ServerScriptService/ChestChaseServer/HubDisplayBoard.lua "return b.Local~=nil and not b.Foreign and Rules.Better(kind,b.Local,b.Remote)" "return b.Local~=nil and Rules.Better(kind,b.Local,b.Remote)" rules
mutate "a board that a write did not settle is retried at every step" $SV "if self.Board:Unsynced(kind)then self.Blocked[kind]=now+Rules.PollSeconds end" "" service
mutate "a failed request does not back off" $ST "self.NextTryAt=self.Clock()+wait" "self.NextTryAt=0" store
mutate "the request budget is not kept" $ST "if #self.Calls>=Rules.RequestsPerMinute then return false,'budget'end" "" store
mutate "a store error escapes (no pcall)" $ST "local ok,a,b=pcall(fn,map)" "local ok,a,b=true,fn(map)" store
mutate "a fruit grown from an owner-given seed counts" $SV "if harvest.TestGrant==true then return false,'test seed'end" "" service
mutate "a pull with owner-given boots counts" ServerScriptService/ChestChaseServer/PlayerDataService.lua "Test=testSeed~=nil or pack.TestGrant==true or luckTest" "Test=testSeed~=nil or pack.TestGrant==true" hooks
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
mutate "reduced motion still moves the display" $CL "local allowed=not paused and tier()>=2" "local allowed=tier()>=2" client
mutate "far displays move too" $CL "local active=allowed and(wasActive and d<=NEAR_OUT or d<=NEAR_IN)" "local active=allowed" client
mutate "the lowest quality tier still gets the motion" $CL "local allowed=not paused and tier()>=2" "local allowed=not paused and tier()>=0" client
mutate "the pack-opened hook is gone" ServerScriptService/ChestChaseServer/PlayerDataService.lua "local hook=self.OnPackOpened" "local hook=nil" hooks
mutate "the harvest hook is gone" ServerScriptService/ChestChaseServer/ChestService.lua "if action == \"Harvest\" and self.HarvestHook then" "if false then" hooks
mutate "the Best Pull display stands in the Base 4 garden" $RU "Pull={Center=Vector3.new(236,4,-516)}," "Pull={Center=Vector3.new(180,4,-440)}," scene
mutate "the Best Pull display crowds the back wall" $RU "Pull={Center=Vector3.new(236,4,-516)}," "Pull={Center=Vector3.new(236,4,-590)}," scene
mutate "the column band's sides lie in the column's faces (z-fighting)" $AR "u('Column band',4.1,.25,4.1,0,3.5,0,GOLD)" "u('Column band',3.8,.25,3.8,0,3.5,0,GOLD)" scene
mutate "the column band's sides lie in the column's faces (z-fighting, the part's own test)" $AR "u('Column band',4.1,.25,4.1,0,3.5,0,GOLD)" "u('Column band',3.8,.25,3.8,0,3.5,0,GOLD)" art
mutate "a sign board comes back" $AR " d.Top=top" " d.Top=top;part(ped,'Sign board',V3(48,20,1.2),L(0,35,11.5),RGB(24,28,54))" art
mutate "a sign board comes back (in the finished hub)" $AR " d.Top=top" " d.Top=top;part(ped,'Sign board',V3(48,20,1.2),L(0,35,11.5),RGB(24,28,54))" scene
mutate "a flat glow disc comes back behind the item" $AR " d.Top=top" " d.Top=top;local halo=part(model,'Halo',V3(.3,16,16),L(15,26,6),GOLD,Enum.Material.Neon);halo.Shape=Enum.PartType.Cylinder" art
mutate "the Fruit of the Hour's projector tube comes back" $AR " d.Top=top" " d.Top=top;local tube=part(ped,'Projector beam',V3(14,3,3),L(15,12,0),GOLD,Enum.Material.Neon);tube.Transparency=.86" art
mutate "the plaque comes back on the column" $AR " d.Top=top" " d.Top=top;part(ped,'Pedestal plaque',V3(10,5,.2),L(px,2.2*S,-(1.96*S+.1)),RGB(30,34,50))" art
mutate "the plaque comes back on the column (in the finished hub)" $AR " d.Top=top" " d.Top=top;part(ped,'Pedestal plaque',V3(10,5,.2),L(px,2.2*S,-(1.96*S+.1)),RGB(30,34,50))" scene
mutate "the label is the small R152 one" $RU "R.Label={W=32,H=14,Near=40,MaxDistance=420}" "R.Label={W=26,H=8,Near=40,MaxDistance=420}" rules
mutate "the label grows without limit up close" $AR "gui.DistanceLowerLimit=S.Near;" "" art
mutate "the label hangs inside the item" $AR "gui.StudsOffsetWorldSpace=V3(0,itemTop+A.Dim.LabelGap+S.H/2-4.78*A.Dim.Scale,0)" "gui.StudsOffsetWorldSpace=V3(0,itemTop-S.H/2-4.78*A.Dim.Scale,0)" art
mutate "the countdown is not on the label" $RU "L.Line=P.Line;L.Footer=P.Footer" "L.Line=P.Line" rules
mutate "the rarity and chance are not on the label" $RU "L.Line=P.Line;L.Footer=P.Footer" "L.Footer=P.Footer" art
mutate "the item's light is on the frame, not on the item" $AR "light.Enabled=spec.Calm~=true;light.Parent=core" "light.Enabled=spec.Calm~=true;light.Parent=model" art
mutate "the avatar is the old size" $RU "R.AvatarHeight=25 " "R.AvatarHeight=10.5 " rules
mutate "the avatar's scale is not applied" $AV "local ok=pcall(function()model:ScaleTo(k)end)" "local ok=true" avatar
mutate "the server plays a dance too (two tracks on every screen)" $AV "pcall(function()for _,t in ipairs(animator:GetPlayingAnimationTracks())do t:Stop(0)end end)" "pcall(function()animator:LoadAnimation(Instance.new('Animation')):Play()end)" avatar
mutate "a dancing avatar is posed too (the dance would be turned)" $AV "  mode='dance'
" "  mode='dance';pcall(Pose.Apply,model)
" avatar
mutate "the humanoid's state machine stays on while it dances" $AV "   humanoid.EvaluateStateMachine=false
   pcall(function()humanoid.AutoRotate=false end)" "   pcall(function()humanoid.AutoRotate=false end)" avatar
mutate "a limb stays anchored (its joint cannot move it)" $AV "   for p in pairs(moved)do if p.Name~='HumanoidRootPart'and p.Anchored then p.Anchored=false end end" "" avatar
mutate "the feet are measured on the parts, not through the joints (it floats)" $AV "local function settle(model)
 local at=restPose(model);if not at then return 0 end" "local function settle(model)
 do return 0 end;local at=restPose(model)" avatar
mutate "the client never loads the dance" $CL "local track=animator:LoadAnimation(anim);d.Track=track" "local track=nil;d.Track=track;error('no load')" client
mutate "a dance that cannot load is never retried" $CL "if d.Try>=Rules.DanceTries then fallBack(entry,d);return end" "if d.Try>=1 then fallBack(entry,d);return end" client
mutate "a dance that cannot load leaves the rig unposed" $CL " if not posedHere[rig]then posedHere[rig]=true;pcall(Pose.Apply,rig)end" "" client
mutate "the watchdog does not restart a stopped track" $CL "  pcall(function()track:Play(FADE)end)
 else d.Restarts=0 end" " else d.Restarts=0 end" client
mutate "the watchdog does not loop the track" $CL " if track.Looped~=true then pcall(function()track.Looped=true end)end" "" client
mutate "another track keeps playing beside the dance (the shaking)" $CL " quiet(d.Animator,track)
end
-- The avatar the server put" "end
-- The avatar the server put" client
mutate "the client cheers (writes the joints of) a dancing avatar" $CL "d.Loaded=true;d.Restarts=0;entry.Local='dance'" "d.Loaded=true;d.Restarts=0;entry.Local='pose';cheerJoints(entry,d.Rig)" client
mutate "the dance is paused while the item is culled" $CL "      local r=entry.CoreRec;if r and r.Part.Parent then entry.Batch:Set(r.Part,turn*r.Rel)end" "      local r=entry.CoreRec;if r and r.Part.Parent then entry.Batch:Set(r.Part,turn*r.Rel)end;if entry.Dance and entry.Dance.Track then entry.Dance.Track:AdjustSpeed(0)end" client
mutate "the automatic quality tier freezes the dance" $CL "local paused=reduced()or fastMode()" "local paused=reduced()or fastMode()or tier()<2" client
mutate "the old champion's track is not let go" $CL " stopDance(entry);entry.Joints=nil;entry.Mode=nil;entry.Local=nil" " entry.Joints=nil;entry.Mode=nil;entry.Local=nil" client
mutate "the dance is never reported" $CL " pcall(function()reportRemote:FireServer(info)end)" "" client
mutate "the same champion gets a new avatar (every screen's dance restarts)" $SV " if rec and shown and shown.Uid==rec.Uid and shown.Source=='avatar'and shown.Model and shown.Model.Parent then" " if false then" service
mutate "a client's report is believed as sent" $SV " for _,known in ipairs(Rules.DanceIds)do if info.Id==known then id=known end end" " id=info.Id" service
mutate "the reports are not rate-limited" $SV " if r.Count>=S.ReportBurst then return false end" "" service
mutate "the dance starts before the avatar is in the display" $SV "   self.Art.SetAvatar(d,avatar)
   -- in the world now" "   if self.Avatars.Animate then pcall(self.Avatars.Animate,self.Avatars,avatar,0)end
   self.Art.SetAvatar(d,avatar)
   -- in the world now" service
mutate "a champion overtaken while its avatar is made ready is not dropped" $SV "   if self:_stale(kind,gen)then return end
  else avatar:Destroy()" "  else avatar:Destroy()" service
mutate "the showcase item does not turn" $CL "entry.Angle=(entry.Angle+itemClock*SPIN)%(math.pi*2)" "entry.Angle=entry.Angle" client
mutate "the sparkles are not on the item" $CL "e.Parent=core;entry.Emitter=e" "e.Parent=entry.Model;entry.Emitter=e" client
mutate "reduced motion does not pause the dance" $CL "local want=paused and 0 or 1" "local want=1" client
mutate "a ring comes back on a new champion" $CL " Debris:AddItem(spot,1.8)" " Debris:AddItem(spot,1.8);local ring=Instance.new('Part');ring.Name='HubPopRing';ring.Parent=workspace;Debris:AddItem(ring,1)" client
echo "$caught of $total mutations caught"
[ "$caught" = "$total" ]
