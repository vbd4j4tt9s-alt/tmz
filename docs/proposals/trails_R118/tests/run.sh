#!/bin/sh
# Usage: sh run.sh <repo root>. R118 head pieces; also re-runs the R117 trail aura suite.
set -e
REPO=${1:-$(cd "$(dirname "$0")/../../../.." && pwd)};SRC=$REPO/src;T=$(mktemp -d)
cp "$REPO/tools/tests/roblox.luau" "$(dirname "$0")/test_head_pieces.luau" "$T/"
python3 "$REPO/tools/tests/bundle.py" "$T/aura_bundle.luau" \
 RunnerTrailArt=$SRC/ReplicatedStorage/RunnerTrailArt.lua RunnerTrailAuraFx=$SRC/ReplicatedStorage/RunnerTrailAuraFx.lua \
 ClientFxBudget=$SRC/ReplicatedStorage/ClientFxBudget.lua RunnerBootArt=$SRC/ReplicatedStorage/RunnerBootArt.lua \
 ShopProductArt=$SRC/ReplicatedStorage/ShopProductArt.lua \
 RunnerTrailAura=$SRC/StarterPlayer/StarterPlayerScripts/RunnerTrailAura.client.lua
(cd "$T" && /opt/luau/luau test_head_pieces.luau)
sh "$REPO/docs/proposals/trails_R117/tests/run.sh" "$REPO"
