#!/bin/sh
# Re-runs every R112 balancing check (spec: docs/proposals/R111_balancing_spec.md). Needs /opt/luau and python3.
# Baseline ("live") data comes from the scripts at commit 17f1921 (R110, before this change).
set -e
HERE=$(cd "$(dirname "$0")" && pwd); REPO=$(cd "$HERE/../../.." && pwd); T=${TMPDIR:-/tmp}/r112_checks; mkdir -p "$T/base"
cd "$HERE"
git -C "$REPO" archive 17f1921 src/ReplicatedStorage | tar -x -C "$T/base"
for d in current econ mix; do CC_SRC="$T/base/src/ReplicatedStorage" python3 bundle.py dump_$d.luau "$T/$d.luau"; /opt/luau/luau "$T/$d.luau" > ${d}_dump.tsv; done
python3 current_odds.py
SS="$REPO/src/ServerScriptService/ChestChaseServer"
python3 bundle.py dump112.luau "$T/d.luau" && /opt/luau/luau "$T/d.luau" > dump112.tsv && python3 xcheck112.py | tee out_xcheck112.txt
python3 bundle.py open112.luau "$T/o.luau" ChestService="$SS/ChestService.lua" PlayerDataService="$SS/PlayerDataService.lua" PlantRules="$REPO/src/ReplicatedStorage/PlantRules.lua"
/opt/luau/luau -O2 "$T/o.luau" | tee out_open112.txt
python3 bundle.py speed112.luau "$T/s.luau" && /opt/luau/luau "$T/s.luau" > speed112.tsv && python3 tables112.py > /dev/null
mkdir -p "$T/motion" && cp "$REPO/tools/tests/roblox.luau" motion112.luau "$T/motion/"
python3 "$REPO/tools/tests/bundle.py" "$T/motion/motion_src.luau" RunnerMotion="$REPO/src/ReplicatedStorage/RunnerMotion.lua" \
  RunnerSweep="$REPO/src/ReplicatedStorage/RunnerSweep.lua" MovementGuard="$SS/MovementGuard.lua" BaseService="$SS/BaseService.lua" SecurityGate="$SS/SecurityGate.lua"
(cd "$T/motion" && /opt/luau/luau motion112.luau) | tee out_motion112.txt
python3 bundle.py roll112.luau "$T/r.luau" && /opt/luau/luau -O2 "$T/r.luau" | tee out_roll112.txt   # ~3 minutes
