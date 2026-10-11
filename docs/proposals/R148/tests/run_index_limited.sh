#!/bin/sh
# Usage: sh run_index_limited.sh [scratch dir]. R148 LIMITED Index tab (MECH + VERITY combined) on the Roblox mock (/opt/luau/luau) with the REAL
# ChestIndex / BiomeArtwork / ArtworkRuntime87 / BiomeIconData / ArtworkFallbackData89 of this checkout. "Unchanged" compares against the R147
# release (LIMITED_INDEX_BASE, default 23235ce), whose ChestIndex / BiomeIconData / ArtworkFallbackData89 come from git (as ...Base).
# Also checks the icon with the real zstd library (check_limited_icon.py; needs `pip install zstandard`, installed under the scratch dir if missing).
# Mutation checks: CHESTINDEX=/path/to/mutated/ChestIndex.client.lua and/or OVERRIDES="ArtworkFallbackData89=/path/to/mutated.lua ..." replace modules.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
BASE=${LIMITED_INDEX_BASE:-23235ce}
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests;C=$REPO/src/StarterPlayer/StarterPlayerScripts
cp "$T/roblox.luau" "$INV/world.luau" "$HERE/test_index_limited.luau" "$OUT/"
show(){ git -C "$REPO" show "$BASE:$1"; }
show src/StarterPlayer/StarterPlayerScripts/ChestIndex.client.lua > "$OUT/ChestIndexBase.lua"
show src/ReplicatedStorage/BiomeIconData.lua > "$OUT/BiomeIconDataBase.lua"
show src/ReplicatedStorage/ArtworkFallbackData89.lua > "$OUT/ArtworkFallbackData89Base.lua"
# (the R113 bundler has this checkout's path hard-coded: point it at this checkout's src)
sed "s#/home/user/tmz/src#$REPO/src#" "$INV/mkbundle.py" > "$OUT/mkbundle_cl.py"
python3 "$OUT/mkbundle_cl.py" "$OUT/rs_bundle.luau" ChestIndexBase="$OUT/ChestIndexBase.lua" BiomeIconDataBase="$OUT/BiomeIconDataBase.lua" \
 ArtworkFallbackData89Base="$OUT/ArtworkFallbackData89Base.lua" ChestIndex="${CHESTINDEX:-$C/ChestIndex.client.lua}" $OVERRIDES >/dev/null
echo "== check_limited_icon (real zstd)";python3 "$HERE/check_limited_icon.py" "$OUT/limited_raw.luau"
cd "$OUT";echo "== test_index_limited";timeout 600 /opt/luau/luau test_index_limited.luau > test_index_limited.log 2>&1 || { grep -v '^WARN' test_index_limited.log | tail -60;exit 1; }
grep -v '^WARN' test_index_limited.log
