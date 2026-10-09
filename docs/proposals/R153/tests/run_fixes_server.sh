#!/bin/sh
# Usage: sh run_fixes_server.sh [scratch dir] [base|mutate]     (needs /opt/luau/luau, python3, git history with the R152 release and the commit before the fixes)
# R153 server fixes from the server bug review (docs/proposals/R153/bug_review_server.md: M1, M2, L4) and the architecture review (items 3 and 4, and the BEST PULL loop), on the Roblox mock
# (/opt/luau/luau, tools/tests/roblox.luau, the R123 world and clover_env.luau on top) with the REAL modules of this checkout:
#  0. static       - every changed / new script compiles; Config.Version and ProfileVersion 22 as in R152; the frozen files match R151's frozen.sha256 (Config.lua and DailyRewards.lua were changed ON PURPOSE:
#                    their new hashes carry a comment there); the new client script is in src/MANIFEST.tsv and starts with the R152 load guard; BackgroundMusic is untouched; the wiring is where the
#                    tests expect it; no model names in the R153 files
#  1. test_fixes_server  - [M1] owner `daily` commands make TEST packs (done / next / week / reset, any claim order, the whole test day, never announced, never BEST PULL, real players unchanged);
#                    [M2] the giveaway lock follows pack -> seed -> plant -> fruit, saved and loaded, refused by FruitGiftService at every step (fruit gifting exists, so the fruit is locked: the lock
#                    goes with the value); [L4] the day-7 login Void Pack is GiftLocked and DailyRewards.LockDay7Void = false lets it be gifted; [H6] the BEST PULL loop survives a bad pass;
#                    [A3] the walk-speed and pack-open/pack-tool test hooks can fail without breaking the game
#  2. test_fixes_boot    - [A3] the owner commands start from the main script (last, own thread, pcall): an error or a hang in them can't stop the server; [A4] the start-up guard: Failed, or not Ready
#                    after 90 s => the server kicks everybody (and every later joiner) with the owner's message; a normal / slow start never kicks; Studio warns and shows the message instead;
#                    the REAL main script run against a broken install (a Config that throws / never loads), live and in Studio
#  3. test_fixes_notice  - [A4] the client script that draws the message in Studio
#  4. R152 server  - test_fixes_r152.luau in a world made from the R152 release (git archive): it loads what the R153 server saved (no kick), keeps the lock on a pack, ignores it on a seed and keeps it
#                    on the plant and the fruit
# "base" runs the same tests on the tree BEFORE the fixes (git archive of the commit in R153_FIXES_BASE, default 6bd1ff4) and requires every tag (M1 M2 L4 H6 A3 A4) to fail there: the bugs are reproduced.
# "mutate" also breaks the fixes one at a time in a copy of src: every break must make a test fail.
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=$2;mkdir -p "$OUT"
S=${SRC:-$REPO/src}
R152=${R152_COMMIT:-e36b71b};BASE=${R153_FIXES_BASE:-6bd1ff4}
T=$REPO/tools/tests;P=$REPO/docs/proposals
SRV=ServerScriptService/ChestChaseServer
RC=0;fail(){ echo "FAIL: $1";RC=1; }
sfail(){ echo "FAIL: [$1] $2";RC=1; }
TAGS="M1 M2 L4 H6 A3 A4"

static(){ # $1 = the src tree to check; $2 = "full" also checks what only this checkout has (frozen hashes, load guard, BackgroundMusic)
 D=$1;SS=$D/$SRV;CL=$D/StarterPlayer/StarterPlayerScripts;MAIN=$D/ServerScriptService/ChestChaseServerMain.server.lua;NOTICE=$CL/StartupNotice153.client.lua
 for f in ServerScriptService/ChestChaseServerMain.server.lua $SRV/OwnerTestPacks.lua $SRV/DailyProgress.lua $SRV/OwnerUpdateCommands82.lua $SRV/PlayerDataService.lua $SRV/FruitGiftService.lua $SRV/HubDisplayService.lua $SRV/Config.lua $SRV/ChestService.lua $SRV/ChaseService.lua ReplicatedStorage/DailyRewards.lua ReplicatedStorage/PlantRules.lua StarterPlayer/StarterPlayerScripts/StartupNotice153.client.lua;do
  [ -f "$D/$f" ] || { sfail A4 "missing $f";continue; }
  /opt/luau/luau-compile --null "$D/$f" >/dev/null 2>&1 || sfail A4 "$f does not compile"
 done
 grep -q "Config.Version='V150 R154';Config.ProfileVersion=22" "$SS/Config.lua" && echo "ok: Config.Version is 'V150 R154' and ProfileVersion 22" || sfail A4 "Config.Version / ProfileVersion changed"
 # [A4] the notice: its own client script, load guard on line 1, in the manifest, no module / remote
 if [ -f "$NOTICE" ];then
  head -1 "$NOTICE" | grep -qF "R152: start once the whole game has arrived" && echo "ok: StartupNotice153 starts with the R152 load guard" || sfail A4 "StartupNotice153: line 1 is not the load guard"
  grep -q "StartupNotice153	StarterPlayer/StarterPlayerScripts/StartupNotice153.client.lua" "$D/MANIFEST.tsv" && echo "ok: StartupNotice153 is in src/MANIFEST.tsv" || sfail A4 "StartupNotice153 is not in src/MANIFEST.tsv"
  if sed 's/--.*$//' "$NOTICE" | grep -n "require(\|RemoteEvent\|OnClientEvent\|InvokeServer";then sfail A4 "StartupNotice153 must need no module and no remote";fi
 else sfail A4 "StartupNotice153.client.lua does not exist";fi
 # [A4] the guard in the main script: the server decides alone
 if grep -qF "BEGIN STARTUP_GUARD_153" "$MAIN" && grep -qF "STARTUP_TIMEOUT = 90" "$MAIN" && grep -qF "pls rejoin" "$MAIN" && grep -qF "player:Kick(STARTUP_KICK_TEXT)" "$MAIN" && grep -qF "pcall(guardStartup)" "$MAIN";then echo "ok: the main script has the start-up guard (90 s, kicks, started in a pcall)"
 else sfail A4 "the main script has no start-up guard (STARTUP_GUARD_153 block, 90 s, Kick, pcall(guardStartup))";fi
 if sed -n '/BEGIN STARTUP_GUARD_153/,/END STARTUP_GUARD_153/p' "$MAIN" | sed 's/--.*$//' | grep -n "RemoteEvent\|OnServerEvent\|FireServer\|InvokeServer";then sfail A4 "the start-up guard must not listen to a client";fi
 # [A4] "no healthy boot path takes that long": the main script itself waits nowhere in its boot (its only yields are WaitForChild with a 10 s limit); the waits inside the services' Start
 # functions are loops in their own threads (checked by hand at R153: SocialService, SpeedBoardService, VoidGiveaway152, HubDisplayService, and the asset loads are spawned)
 bootOk=1
 if sed -n '/^local function runServer/,/^local ok, message = xpcall/p' "$MAIN" | sed 's/--.*$//' | grep -n "task.wait(\|:Wait()\|os.clock";then sfail A4 "runServer (the boot) must not wait: a slow boot would meet the 90 s limit";bootOk=0;fi
 if sed -n '/^local function runServer/,/^local ok, message = xpcall/p' "$MAIN" | sed 's/--.*$//' | grep "WaitForChild(" | grep -v "WaitForChild([^()]*, 10)";then sfail A4 "every WaitForChild in the boot must have a 10 s limit";bootOk=0;fi
 if sed -n '/BEGIN STARTUP_GUARD_153/,/END STARTUP_GUARD_153/p' "$MAIN" | sed 's/--.*$//' | grep -n "os.clock";then sfail A4 "the guard must time itself with what task.wait waited (os.clock may be CPU time)";bootOk=0;fi
 [ $bootOk = 1 ] && grep -qF "BEGIN STARTUP_GUARD_153" "$MAIN" && echo "ok: the boot itself never waits (only WaitForChild with a 10 s limit) and the guard times itself with task.wait: a healthy start is far from 90 s"
 # [A3] the owner commands start from the main script, not from ChaseService
 if grep -qF "BEGIN OWNER_TOOLS_START_153" "$MAIN" && sed -n '/BEGIN OWNER_TOOLS_START_153/,/END OWNER_TOOLS_START_153/p' "$MAIN" | grep -q "pcall(" && sed -n '/BEGIN OWNER_TOOLS_START_153/,/END OWNER_TOOLS_START_153/p' "$MAIN" | grep -q "task.spawn(" && ! grep -q "StudioTestCommands\|startV142" "$SS/ChaseService.lua";then echo "ok: the owner commands start from the main script in a spawned pcall; ChaseService has no Start override"
 else sfail A3 "the owner commands must start from the main script (OWNER_TOOLS_START_153: task.spawn + pcall) and not from ChaseService";fi
 grep -q "pcall(ownerTestSpeed" "$SS/Config.lua" && grep -q "RarePackTests).Expected(self,player,pack.Id)end)" "$SS/PlayerDataService.lua" && grep -q "RarePackTests).Expected(self.PlayerData,player,record.Id)end)" "$SS/ChestService.lua" && echo "ok: the walk-speed hook and both RarePackTests.Expected hooks are inside a pcall" || sfail A3 "a gameplay test hook is not inside a pcall"
 # [M1] [M2] [L4] [H6] wiring
 grep -q "DailyQuest=true" "$SS/OwnerTestPacks.lua" && grep -qF "GrantDailyPack(player,false,'DailyQuest')" "$SS/DailyProgress.lua" && grep -qF "TestPacks.Arm(p,'DailyQuest'" "$SS/OwnerUpdateCommands82.lua" && echo "ok: the quest packs have their own owner-test source (DailyQuest)" || sfail M1 "the daily quest packs have no source of their own"
 grep -qF "NoteOwnerGrant" "$SS/OwnerUpdateCommands82.lua" && echo "ok: the daily commands taint the target for the hub boards" || sfail M1 "the daily commands do not taint the target for the hub boards"
 grep -q "GiftLocked=pack.GiftLocked==true or nil" "$SS/PlayerDataService.lua" && grep -q "GiftLocked=seed.GiftLocked==true or nil" "$D/ReplicatedStorage/PlantRules.lua" && grep -q "LockedFruitText" "$SS/FruitGiftService.lua" && echo "ok: the lock goes pack -> seed -> plant -> fruit and FruitGiftService checks the fruit" || sfail M2 "the lock does not follow pack -> seed -> plant -> fruit"
 grep -q "^D.LockDay7Void=true" "$D/ReplicatedStorage/DailyRewards.lua" && grep -q "GiftLocked=D.LockDay7Void~=false or nil" "$SS/DailyProgress.lua" && echo "ok: DailyRewards.LockDay7Void (true) locks the day-7 Void Pack" || sfail L4 "the day-7 Void Pack has no lock switch (DailyRewards.LockDay7Void)"
 grep -q "if not ok then" "$SS/HubDisplayService.lua" && sed -n '/if not self.Opts.NoLoop then/,/return self/p' "$SS/HubDisplayService.lua" | grep -q "pcall(function()" && echo "ok: the BEST PULL loop body is inside a pcall" || sfail H6 "the BEST PULL loop body is not inside a pcall"
 # no model names in the R153 files of this fix
 if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|(op[u]s|sonn[e]t|haik[u])[ -]?[0-9]|gp[t]-?[0-9]" "$HERE"/test_fixes_*.luau "$HERE"/mutate_fixes_server.py "$MAIN" "$NOTICE" "$SS/OwnerTestPacks.lua" "$SS/DailyProgress.lua" "$SS/FruitGiftService.lua" "$SS/HubDisplayService.lua" "$SS/OwnerUpdateCommands82.lua" 2>/dev/null | grep -v "Binary file" | grep -q .;then sfail A4 "a model name in the files of this fix";else echo "ok: no model names in the files of this fix";fi
 if [ "$2" = full ];then
  (cd "$REPO" && sha256sum -c docs/proposals/R151/tests/frozen.sha256 > "$OUT/frozen.log" 2>&1) && echo "ok: the frozen files match R151's frozen.sha256 ($(grep -c '  src/' "$REPO/docs/proposals/R151/tests/frozen.sha256") files; Config.lua and DailyRewards.lua changed on purpose, with a comment there)" || { cat "$OUT/frozen.log";fail "a frozen file changed without a new hash"; }
  sh "$P/R152/tests/run_load_guard.sh" "$OUT/guard" > "$OUT/guard.log" 2>&1 && echo "ok: the R152 load guard is line 1 of every client script ($(tail -1 "$OUT/guard.log"))" || { fail "the load guard test fails";tail -5 "$OUT/guard.log"; }
  if git -C "$REPO" cat-file -e "$BASE:src/StarterPlayer/StarterPlayerScripts/BackgroundMusic.client.lua" 2>/dev/null;then
   git -C "$REPO" show "$BASE:src/StarterPlayer/StarterPlayerScripts/BackgroundMusic.client.lua" > "$OUT/bgm_base.txt"
   cmp -s "$OUT/bgm_base.txt" "$CL/BackgroundMusic.client.lua" && echo "ok: BackgroundMusic.client.lua is byte-identical to the commit before the fixes" || fail "BackgroundMusic.client.lua changed"
  else echo "SKIP: BackgroundMusic check (commit $BASE not in the history)";fi
 fi
}
build(){ # $1 = work dir, $2 = the src tree to bundle
 mkdir -p "$1";cp "$T/roblox.luau" "$P/treadmill_bonus_R123/tests/world.luau" "$HERE"/*.luau "$1/"
 extra=""
 [ -f "$2/ServerScriptService/ChestChaseServerMain.server.lua" ] && extra="ChestChaseServerMain=$2/ServerScriptService/ChestChaseServerMain.server.lua"
 [ -f "$2/StarterPlayer/StarterPlayerScripts/StartupNotice153.client.lua" ] && extra="$extra StartupNotice153=$2/StarterPlayer/StarterPlayerScripts/StartupNotice153.client.lua"
 python3 "$HERE/mkbundle_clover.py" "$1" --src "$2" $extra > /dev/null
}
run(){ # $1 = work dir, $2 = test name
 ( cd "$1" && timeout 900 /opt/luau/luau "$2.luau" > "$2.log" 2>&1 ) || { grep -v '^WARN\|^PROFILE\|^RESAVED' "$1/$2.log" | tail -30;fail "$2 FAILED";return 1; }
 echo "$2: $(grep -v '^WARN\|^PROFILE\|^RESAVED' "$1/$2.log" | tail -1)"
}
table(){ # prefix in out
 { echo 'return {';sed -n "s/^$1 \([a-z0-9]*\) \(.*\)\$/ \1=\2,/p" "$2";echo '}'; } > "$3"
}

if [ "$MODE" = base ];then
 echo "== base: the same tests on the tree before the fixes ($BASE) must FAIL, every tag"
 rm -rf "$OUT/base_src";mkdir -p "$OUT/base_src"
 git -C "$REPO" archive "$BASE" src | tar -x -C "$OUT/base_src" || { echo "FAIL: git archive $BASE (the commit before the fixes must be in the history)";exit 1; }
 static "$OUT/base_src/src" > "$OUT/base_static.log" 2>&1
 W=$OUT/wbase;rm -rf "$W";build "$W" "$OUT/base_src/src"
 for test in test_fixes_server test_fixes_boot test_fixes_notice;do ( cd "$W" && timeout 900 /opt/luau/luau "$test.luau" > "$test.log" 2>&1 );done
 cat "$OUT/base_static.log" "$W/test_fixes_server.log" "$W/test_fixes_boot.log" "$W/test_fixes_notice.log" > "$OUT/base_all.log"
 RC=0
 for tag in $TAGS;do
  n=$(grep -c "^FAIL: \[$tag\]" "$OUT/base_all.log")
  if [ "$n" -ge 1 ];then echo "ok: [$tag] reproduced on the pre-fix scripts ($n failing checks)";else fail "[$tag] is NOT reproduced: nothing fails on the pre-fix scripts";fi
 done
 echo "(failing checks on the pre-fix scripts: $(grep -c '^FAIL: ' "$OUT/base_all.log"); per file: server $(grep -c '^FAIL: ' "$W/test_fixes_server.log"), boot $(grep -c '^FAIL: ' "$W/test_fixes_boot.log"), notice $(grep -c '^FAIL: ' "$W/test_fixes_notice.log"), static $(grep -c '^FAIL: ' "$OUT/base_static.log"))"
 [ $RC = 0 ] && echo "R153 server fixes (base): every bug reproduced" || echo "R153 server fixes (base): NOT all reproduced"
 exit $RC
fi

echo "== 0. static";static "$S" full
echo "== 1. server (M1 M2 L4 H6 A3)"
W=$OUT/w153;rm -rf "$W";build "$W" "$S"
run "$W" test_fixes_server
echo "== 2. start-up (A3 A4)"
run "$W" test_fixes_boot
echo "== 3. the notice (A4)"
run "$W" test_fixes_notice
echo "== 4. an R152 server"
rm -rf "$OUT/r152_src";mkdir -p "$OUT/r152_src"
git -C "$REPO" archive "$R152" src | tar -x -C "$OUT/r152_src" || { fail "git archive $R152 (the R152 release must be in the history)";exit 1; }
W152=$OUT/w152;rm -rf "$W152";build "$W152" "$OUT/r152_src/src"
table PROFILE "$W/test_fixes_server.log" "$W152/profiles.luau"
run "$W152" test_fixes_r152
if [ "$MODE" = mutate ];then
 echo "== mutations (each break must make a test fail)"
 python3 "$HERE/mutate_fixes_server.py" "$S" "$OUT/mut" "$HERE" "$T" "$P" || RC=1
fi
[ $RC = 0 ] && echo "R153 server fixes: PASS" || echo "R153 server fixes: FAIL"
exit $RC
