#!/bin/sh
# Usage: sh run_verity_ui.sh [scratch dir]. R147 Verity pack art + Index tab 9 (client side) on the Roblox mock (/opt/luau/luau) with
# the REAL modules / scripts of this checkout (SeedPackVisuals, SeedPackRenderer, EclipsePackArt, VerityPackArt, VoidPackFx,
# ItemPictures, VeiledEventClient81, SeedPackRender, ChestIndex). "Nothing existing changed" compares against the base commit
# (VERITY_UI_BASE, default 15e4a50 = the branch head before the face-card pack), whose SeedPackVisuals / SeedPackRenderer / EclipsePackArt / VoidPackFx /
# ChestIndex come from git, are renamed (...Base) and run beside the new ones part by part.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
BASE=${VERITY_UI_BASE:-15e4a50}
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests;C=$REPO/src/StarterPlayer/StarterPlayerScripts
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/test_verity_ui.luau" "$OUT/"
show(){ git -C "$REPO" show "$BASE:$1"; }
show src/ReplicatedStorage/SeedPackVisuals.lua | sed -e "s/script.Parent.SeedPackRenderer/script.Parent.SeedPackRendererBase/g" -e "s/script.Parent.EclipsePackArt/script.Parent.EclipsePackArtBase/g" > "$OUT/SeedPackVisualsBase.lua"
show src/ReplicatedStorage/SeedPackRenderer.lua | sed -e "s/script.Parent.EclipsePackArt/script.Parent.EclipsePackArtBase/g" > "$OUT/SeedPackRendererBase.lua"
show src/ReplicatedStorage/EclipsePackArt.lua | sed -e "s/script.Parent.SeedPackRenderer/script.Parent.SeedPackRendererBase/g" > "$OUT/EclipsePackArtBase.lua"
show src/ReplicatedStorage/VoidPackFx.lua > "$OUT/VoidPackFxBase.lua"
show src/StarterPlayer/StarterPlayerScripts/ChestIndex.client.lua > "$OUT/ChestIndexBase.lua"
# (the R113 bundler has this checkout's path hard-coded: point it at this worktree's src)
sed "s#/home/user/tmz/src#$REPO/src#" "$INV/mkbundle.py" > "$OUT/mkbundle_cl.py"
python3 "$OUT/mkbundle_cl.py" "$OUT/rs_bundle.luau" SeedPackVisualsBase="$OUT/SeedPackVisualsBase.lua" SeedPackRendererBase="$OUT/SeedPackRendererBase.lua" \
 EclipsePackArtBase="$OUT/EclipsePackArtBase.lua" VoidPackFxBase="$OUT/VoidPackFxBase.lua" ChestIndexBase="$OUT/ChestIndexBase.lua" \
 ChestIndex="$C/ChestIndex.client.lua" VeiledEventClient81="$C/VeiledEventClient81.client.lua" SeedPackRender="$C/SeedPackRender.client.lua" \
 PackOpeningFeedback="$C/PackOpeningFeedback.client.lua" SeedPackClient="$C/SeedPackClient.client.lua" >/dev/null
cd "$OUT";echo "== test_verity_ui";timeout 600 /opt/luau/luau test_verity_ui.luau > test_verity_ui.log 2>&1 || { grep -v '^WARN' test_verity_ui.log | tail -60;exit 1; }
grep -v '^WARN' test_verity_ui.log
