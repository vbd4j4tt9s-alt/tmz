#!/bin/sh
# Usage: sh run_verity.sh [scratch dir]. R147 Verity NPC checks on the Roblox mock with the real scripts:
#  test_verity.luau        - the real VerityService / VerityConfig / SecurityGate / PlayerDataService: the model built behind the market
#                            (R148: a solid yellow Ball with her smiley as Decals on its Front and Back faces, on a dais; its position
#                            checked against the REAL MarketLayout's footprint, the lobby bounds, the bases and the spawn), the Open
#                            message, the hand-in (one Void record and its Tool -> one Verity pack through a stubbed
#                            ChestService:ConvertVoidPack, Count saved / loaded), the pick order, and every refusal (no Void pack, too
#                            far, no body, carrying / running / queued / ragdolled, mid-opening, spam, data not loaded / not saving,
#                            ConvertVoidPack missing / failing / throwing).
#  test_verity_client.luau - the real VerityClient with the real ItemPictures / SeedPackVisuals / AudioMixer: her body turning to the
#                            camera, bobbing and swelling, the ! / ? marker in her name sign, her greeting voice (Talk, proximity +
#                            cooldown, no overlap, Effects volume, load failure), the dialog states (Open / Done / Refused), the
#                            portrait (R149: her 3D model in a ViewportFrame; no "EVENT ENDS" line; the quest sentence in full), the Void -> Verity
#                            pack pictures built from the real pack models, the GIVE button only with a Void tool, SeedMenu set and cleared, and
#                            the window fitting 13 screen sizes from 360x600 to 1920x1080 (R149: with and without The Darkened's line, on every Open).
#                            The greeting's cut and the lip sync are tested in docs/proposals/R149/tests (run_verity.sh there runs both).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT/srv" "$OUT/cl"
T=$REPO/tools/tests;TB=$REPO/docs/proposals/treadmill_bonus_R123/tests;INV=$REPO/docs/proposals/inventory_R113/tests;C=$REPO/src/StarterPlayer/StarterPlayerScripts
cp "$T/roblox.luau" "$TB/world.luau" "$HERE"/test_verity.luau "$OUT/srv/";python3 "$TB/mkbundle.py" "$OUT/srv" >/dev/null
# (the R113 bundler has this checkout's path hard-coded: point it at this worktree's src)
sed "s#/home/user/tmz/src#$REPO/src#" "$INV/mkbundle.py" > "$OUT/mkbundle_cl.py"
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE"/test_verity_client.luau "$OUT/cl/"
python3 "$OUT/mkbundle_cl.py" "$OUT/cl/rs_bundle.luau" VerityClient="$C/VerityClient.client.lua" >/dev/null
cd "$OUT/srv";echo "== test_verity";/opt/luau/luau test_verity.luau > verity.log 2>&1 || { tail -30 verity.log;exit 1; };tail -1 verity.log
cd "$OUT/cl";echo "== test_verity_client";/opt/luau/luau test_verity_client.luau > client.log 2>&1 || { tail -30 client.log;exit 1; };tail -1 client.log
