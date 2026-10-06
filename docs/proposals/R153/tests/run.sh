#!/bin/sh
# Usage: sh run.sh [scratch dir] [mutate]. R153 (the hotbar: one press = one equip, drag to reorder, the order kept) on the Roblox mock (/opt/luau/luau) with the
# REAL modules / scripts of this checkout.
#  test_hotbar_real.luau    - the real Hotbar (+ the real HeldHarvests) through engine153.luau, a closer model of the engine (hit test over every ScreenGui,
#                             MouseButton1Down / Up / Activated / InputBegan / UserInputService as the engine derives them from a pointer) and of the server
#                             (pack holds after the shape bake, refusals, the reward hand-off, respawns), in 6 engine variants x 2 event orders.
#  test_hold_server153.luau - the server half on R151's pack harness: the reward hand-off leaves an item the player picked during the reveal in the hand;
#                             a refused pack says why (HoldRefused, ChestService.HoldLog for /test hotbar); a hold that waited for its shape is listed.
#  static checks            - the edited scripts compile, Config.Version unchanged, the load guard lines of Hotbar (lines 1 / 2) untouched, no model names.
# "mutate" bundles the R152 Hotbar, GardenInventoryState and HeldHarvests (BASE=<the R152 release head>) and the R152 ChestService, and expects every run to FAIL:
# proof the tests catch what the owner reported.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=$2;BASE=${BASE:-e36b71b};mkdir -p "$OUT/cl" "$OUT/srv"
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;SP=$S/StarterPlayer/StarterPlayerScripts;INV=$P/inventory_R113/tests;R151=$P/R151/tests
echo "== static checks"
fail=0;bad() { echo "FAIL: $1";fail=1; }
for f in "$SP/Hotbar.client.lua" "$SP/HeldHarvests.client.lua" "$S/ReplicatedStorage/GardenInventoryState.lua" "$S/ServerScriptService/ChestChaseServer/ChestService.lua" \
 "$S/ServerScriptService/ChestChaseServer/StudioTestCommands.lua" "$S/ReplicatedStorage/StudioTestHelp.lua";do
 /opt/luau/luau-compile --null "$f" >/dev/null 2>&1 || bad "$f does not compile"
done
head -1 "$SP/Hotbar.client.lua" | grep -q "SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false)" || bad "Hotbar line 1 must hide Roblox's backpack (R152 load guard)"
sed -n 2p "$SP/Hotbar.client.lua" | grep -q "R152: start once the whole game has arrived" || bad "Hotbar line 2 must be the R152 load guard"
[ "$(git -C "$REPO" show "$BASE:src/ServerScriptService/ChestChaseServer/Config.lua" | grep 'Config.Version')" = "$(grep 'Config.Version' "$S/ServerScriptService/ChestChaseServer/Config.lua")" ] || bad "Config.Version changed"
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|(op[u]s|sonn[e]t|haik[u])[ -]?[0-9]" "$HERE" "$P/R153"/*.md 2>/dev/null;then bad "a model name in the R153 files";fi
[ "$fail" = 0 ]
echo "ok: the edited scripts compile, Config.Version unchanged, Hotbar lines 1 / 2 are the R152 load guard, no model names"
client() { # $1 dir, extra Name=path overrides after
 d=$1;shift
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$HERE/engine153.luau" "$HERE/test_hotbar_real.luau" "$d/"
 python3 "$P/R150/tests/mkbundle_sfx.py" "$d" all-client NotificationService="$S/ServerScriptService/ChestChaseServer/NotificationService.lua" "$@" >/dev/null
}
serverside() { # $1 dir, extra Name=path overrides after
 d=$1;shift
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$R151/pack_world.luau" "$R151/pack_templates.luau" "$R151/pouch_mock.luau" "$R151/pack_shape_samples.luau" "$HERE/test_hold_server153.luau" "$d/"
 python3 "$R151/mkbundle_packs.py" "$d" "$S" --server "$@" >/dev/null
}
kinds() { # the failed checks of a log, by what they are about
 f=$1;c() { grep '^FAIL' "$f" | grep -ciE "$1"; }
 echo "one press=one equip $(c 'one press|single click|shows in the hand'), drag $(c 'drag:|drag onto|flick onto'), Bag $(c 'Bag card|onto the open Bag|Bag button|stay off|dragged back'), order $(c 'respawn|holds across|keeps its slot|new item does not'), server moves $(c 'reveal|carrying|chase|knocked'), re-sort/stacking $(c 're-sorts|ScreenGui'), log $(c 'log'), random $(c 'random run')"
}
variants() { # $1 dir, $2 hand-off rule; prints one line per run; returns the number of runs that failed
 d=$1;n=0;for v in began nobegan stale anywhere objscreen nobegan_gui;do for o in "activated first" "release first";do
  name=$(echo "real_${v}_$o" | tr ' ' '_')
  printf "VARIANT='%s';ORDER='%s';HANDOFF='%s'\n" "$v" "$o" "$2" > "$d/$name.luau";cat "$d/test_hotbar_real.luau" >> "$d/$name.luau"
  if (cd "$d" && timeout 900 /opt/luau/luau "$name.luau" > "$name.log" 2>&1);then echo "  $v / $o: $(grep -v '^WARN' "$d/$name.log" | grep -v '^\[Hotbar\]' | tail -1)"
  else n=$((n+1));echo "  $v / $o: FAILED ($(grep -c '^FAIL' "$d/$name.log") checks): $(kinds "$d/$name.log")";fi
 done;done
 return $n
}
if [ "$MODE" = "mutate" ]; then
 for f in StarterPlayer/StarterPlayerScripts/Hotbar.client.lua:Hotbar ReplicatedStorage/GardenInventoryState.lua:GardenInventoryState StarterPlayer/StarterPlayerScripts/HeldHarvests.client.lua:HeldHarvests ServerScriptService/ChestChaseServer/ChestService.lua:ChestService;do
  git -C "$REPO" show "$BASE:src/${f%%:*}" > "$OUT/${f##*:}_old.lua"
 done
 client "$OUT/cl" Hotbar="$OUT/Hotbar_old.lua" GardenInventoryState="$OUT/GardenInventoryState_old.lua" HeldHarvests="$OUT/HeldHarvests_old.lua"
 echo "== mutate: test_hotbar_real against the $BASE Hotbar (every run must FAIL)"
 set +e;variants "$OUT/cl" always;failed=$?;set -e
 [ "$failed" = 12 ] || { echo "FAIL: only $failed of 12 runs fail on the old Hotbar";exit 1; }
 serverside "$OUT/srv" ChestService="$OUT/ChestService_old.lua"
 echo "== mutate: test_hold_server153 against the $BASE ChestService (must FAIL)"
 if (cd "$OUT/srv" && timeout 900 /opt/luau/luau test_hold_server153.luau > mutate.log 2>&1);then echo "FAIL: the server test passes on the old ChestService";exit 1;fi
 grep -c "^FAIL" "$OUT/srv/mutate.log" | sed 's/$/ failed checks on the old ChestService (expected)/'
 echo "R153 mutation check passed";exit 0
fi
client "$OUT/cl"
echo "== test_hotbar_real (6 engine variants x 2 event orders)"
set +e;variants "$OUT/cl" empty;failed=$?;set -e
[ "$failed" = 0 ] || { echo "FAIL: $failed run(s) failed";exit 1; }
serverside "$OUT/srv"
echo "== test_hold_server153"
(cd "$OUT/srv" && timeout 900 /opt/luau/luau test_hold_server153.luau > test_hold_server153.log 2>&1) || { grep -v '^WARN' "$OUT/srv/test_hold_server153.log" | tail -30;exit 1; }
grep -v '^WARN' "$OUT/srv/test_hold_server153.log" | tail -1
echo "R153 suites passed"
