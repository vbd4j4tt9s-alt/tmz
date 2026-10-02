#!/bin/sh
# R123 rarity borders. Usage: sh run.sh [scratch dir]
# Reuses the R113 inventory mock world + fixtures; bundles ReplicatedStorage + the client scripts that show rarity.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);SRC=$HERE/../../../../src;INV=$HERE/../../inventory_R113/tests
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
cp "$SRC/../tools/tests/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/test_borders.luau" "$OUT/"
P=$SRC/StarterPlayer/StarterPlayerScripts
python3 "$INV/mkbundle.py" "$OUT/rs_bundle.luau" Hotbar=$P/Hotbar.client.lua PlantInspection=$P/PlantInspection.client.lua ChestIndex=$P/ChestIndex.client.lua \
 SeedPackClient=$P/SeedPackClient.client.lua PackOpeningFeedback=$P/PackOpeningFeedback.client.lua FruitGiftClient=$P/FruitGiftClient.client.lua EconomyClient=$P/EconomyClient.client.lua
cd "$OUT" && /opt/luau/luau test_borders.luau
