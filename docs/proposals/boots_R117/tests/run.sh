#!/bin/sh
# R117 boot tests: run from anywhere. Usage: sh docs/proposals/boots_R117/tests/run.sh [scratch-dir]
# Bundles the real modules, copies the shared Roblox mock (tools/tests/roblox.luau) and runs both suites
# with the Luau CLI (/opt/luau/luau).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
S=$REPO/src
OUT=${1:-$(mktemp -d)}
mkdir -p "$OUT"
cp "$REPO/tools/tests/roblox.luau" "$OUT/roblox.luau"
cp "$HERE/test_boot_fx_r111.luau" "$HERE/test_boots_r117.luau" "$OUT/"
python3 "$REPO/tools/tests/bundle.py" "$OUT/boot_bundle.luau" \
 RunnerTrailRules=$S/ReplicatedStorage/RunnerTrailRules.lua \
 RunnerTrailStyles=$S/ReplicatedStorage/RunnerTrailStyles.lua \
 RunnerTrailEffects=$S/ReplicatedStorage/RunnerTrailEffects.lua \
 RunnerBootFx=$S/ReplicatedStorage/RunnerBootFx.lua \
 ClientFxBudget=$S/ReplicatedStorage/ClientFxBudget.lua \
 RunnerTrailClient=$S/StarterPlayer/StarterPlayerScripts/RunnerTrailClient.client.lua \
 RunnerBootArt=$S/ReplicatedStorage/RunnerBootArt.lua \
 ShopProductArt=$S/ReplicatedStorage/ShopProductArt.lua \
 RunnerTrailArt=$S/ReplicatedStorage/RunnerTrailArt.lua
cd "$OUT"
echo '== R111 suite (updated for R117) =='
/opt/luau/luau test_boot_fx_r111.luau
echo '== R117 suite =='
/opt/luau/luau test_boots_r117.luau
