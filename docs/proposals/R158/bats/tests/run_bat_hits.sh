#!/bin/sh
# Usage: sh run_bat_hits.sh [scratch dir] [swings per cell, default 1500]   (needs /opt/luau/luau and python3)
# R158 bats (owner: "improve hitbox consistency especially with fast moving players"), offline, nothing in src/ changes:
#  1. sim_bat_hits.luau - TODAY (the REAL src BatHitbox.lua + BatConfig.lua, BatService's timing) vs PROPOSED (BatLagComp158.luau) on a network
#     model (30 Hz character packets, 60 Hz frames, client interpolation delay); 5 scenarios x 7 speeds x 4 pings -> results.txt (hitbox.md quotes it)
#  2. test_bat_anticheat.luau - the proposed server check refuses forged / late / far / behind / through-a-wall / repeated claims and accepts
#     honest ones up to 575 studs/s (32 checks)
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../../.." && pwd)
OUT=${1:-$(mktemp -d)};N=${2:-1500};mkdir -p "$OUT"
# (R158 built: src now holds the built bats; "today" is the approved checkout's code, read from git: BATS_BASE, default e9c0900 = V150 R157b + notes.
#  The built code has its own suite: docs/proposals/R158/tests/run_bats158.sh)
BASE=${BATS_BASE:-e9c0900}
git -C "$REPO" show "$BASE:src/ReplicatedStorage/BatConfig.lua" > "$OUT/BatConfig_today.lua";git -C "$REPO" show "$BASE:src/ReplicatedStorage/BatHitbox.lua" > "$OUT/BatHitbox_today.lua"
python3 "$REPO/tools/tests/bundle.py" "$OUT/bat_bundle.luau" BatConfig="$OUT/BatConfig_today.lua" BatHitbox="$OUT/BatHitbox_today.lua"
cp "$REPO/tools/tests/roblox.luau" "$HERE/BatLagComp158.luau" "$HERE/sim_bat_hits.luau" "$HERE/test_bat_anticheat.luau" "$OUT/"
/opt/luau/luau-compile --binary "$HERE/BatLagComp158.luau" >/dev/null && echo "ok: BatLagComp158 compiles"
(cd "$OUT" && /opt/luau/luau test_bat_anticheat.luau) || { echo "FAIL: anti-cheat test";exit 1; }
(cd "$OUT" && /opt/luau/luau sim_bat_hits.luau -a "$N") > "$HERE/results.txt" || { echo "FAIL: simulation";exit 1; }
echo "ok: simulation -> $HERE/results.txt ($N swings per cell)"
