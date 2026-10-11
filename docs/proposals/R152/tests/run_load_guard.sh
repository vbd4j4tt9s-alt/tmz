#!/bin/sh
# R152 load guard. Owner's Studio log: ReplicatedStorage.InteractionAudio ran require(script.Parent.SoundTiming) before SoundTiming had
# replicated, so it errored and every client script requiring it (Hotbar, EconomyClient, ChestIndex, SettingsClient, PackOpeningFeedback ...)
# failed with "Requested module experienced an error while loading": the hotbar was gone and Roblox's default backpack showed.
# Checks: 1. every StarterPlayerScripts client script starts with the guard (Hotbar: its Backpack line first), BackgroundMusic excepted
# (hand-edited in the owner's place, never touched by an installer); 2. InteractionAudio waits for SoundTiming; 3. the guard line itself on
# the Luau mock: it waits for game.Loaded only while the game is not loaded, and a stand-in without IsLoaded (older test mocks) runs on.
# Usage: sh run_load_guard.sh [scratch dir]
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
C=$REPO/src/StarterPlayer/StarterPlayerScripts;RC=0;fail(){ echo "FAIL: $1";RC=1; }
GUARD='R152: start once the whole game has arrived'
n=0
for f in "$C"/*.client.lua;do b=$(basename "$f")
 if [ "$b" = BackgroundMusic.client.lua ];then grep -q "$GUARD" "$f" && fail "$b must stay untouched (hand-edited in the owner's place)";continue;fi
 n=$((n+1))
 if [ "$b" = Hotbar.client.lua ];then
  head -1 "$f" | grep -q "SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false)" || fail "Hotbar: line 1 must hide Roblox's backpack"
  sed -n 2p "$f" | grep -q "$GUARD" || fail "Hotbar: line 2 must be the load guard"
 else head -1 "$f" | grep -q "$GUARD" || fail "$b: line 1 is not the load guard";fi
 [ "$(grep -c "$GUARD" "$f")" = 1 ] || fail "$b: the guard must appear exactly once"
done
echo "ok: $n client scripts start with the load guard (Hotbar hides the backpack first), BackgroundMusic untouched"
grep -q "require(script.Parent:WaitForChild('SoundTiming'))" "$REPO/src/ReplicatedStorage/InteractionAudio.lua" || fail "InteractionAudio must WaitForChild('SoundTiming')"
grep -q "require(script.Parent.SoundTiming)" "$REPO/src/ReplicatedStorage/InteractionAudio.lua" && fail "InteractionAudio still indexes SoundTiming directly"
echo "ok: InteractionAudio waits for SoundTiming"
G=$(head -1 "$C/HudNotices.client.lua")
cat > "$OUT/guard.luau" <<EOF
local checks,failures=0,0
local function check(c,m)checks+=1;if not c then failures+=1;print('FAIL '..m)end end
local function run(game)
 local env=setmetatable({game=game},{__index=_G})
 local f=loadstring and loadstring([==[$G
 return 'ran']==]) or load([==[$G
 return 'ran']==],'guard','t',env)
 if setfenv then setfenv(f,env)end
 return f()
end
-- loaded already: no wait
local waits=0
local g1={IsLoaded=function()return true end,Loaded={Wait=function()waits+=1 end}}
check(run(g1)=='ran' and waits==0,'a loaded game runs on at once')
-- not loaded yet: waits once for Loaded, then runs
local g2={IsLoaded=function()return false end,Loaded={Wait=function()waits+=1 end}}
check(run(g2)=='ran' and waits==1,'a game still loading waits for Loaded once')
-- a stand-in without IsLoaded (older suites' mocks): runs on, no error
check(run(setmetatable({},{__index=function(_,k)error(k..' is not a valid member')end}))=='ran','a stand-in without IsLoaded runs on')
check(run({})=='ran','an empty stand-in runs on')
print(('R152 load guard: %d checks, %d failures'):format(checks,failures))
if failures>0 then error('failed')end
EOF
/opt/luau/luau "$OUT/guard.luau" || fail "the guard line misbehaves on the mock"
[ $RC = 0 ] && echo "R152 load guard: PASS" || echo "R152 load guard: FAIL"
exit $RC
