#!/bin/sh
# Usage: sh run.sh [scratch dir]. R139 checks on the Roblox mock with the real scripts:
#  test_newglow.luau  - the rainbow ring on new packs (real Hotbar): packs you joined with stay plain, a new pack's
#                       slot / Bag card glows, waits until you can see it, holds 4 s, fades over 2 s, never twice.
#  test_starter.luau  - the free tutorial pack: still 2x on the server, but named, announced and priced like any
#                       Forest pack (no luck in the tooltip), once per account, and a gift of it arrives as a normal pack.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT/srv"
INV=$REPO/docs/proposals/inventory_R113/tests;C=$REPO/src/StarterPlayer/StarterPlayerScripts;T=$REPO/tools/tests
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE"/test_newglow.luau "$OUT/"
python3 "$INV/mkbundle.py" "$OUT/rs_bundle.luau" Hotbar="$C/Hotbar.client.lua" >/dev/null
TB=$REPO/docs/proposals/treadmill_bonus_R123/tests
cp "$T/roblox.luau" "$TB/world.luau" "$HERE"/test_starter.luau "$OUT/srv/";python3 "$TB/mkbundle.py" "$OUT/srv" >/dev/null
cd "$OUT"
echo "== test_newglow";/opt/luau/luau test_newglow.luau > newglow.log 2>&1 || { tail -25 newglow.log;exit 1; };tail -1 newglow.log
cd srv;echo "== test_starter";/opt/luau/luau test_starter.luau > starter.log 2>&1 || { tail -25 starter.log;exit 1; };tail -1 starter.log
