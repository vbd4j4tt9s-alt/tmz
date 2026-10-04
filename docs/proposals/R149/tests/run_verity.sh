#!/bin/sh
# Usage: sh run_verity.sh [scratch dir] [all|mutate]. R149 Verity checks (greeting cut to "Hello, my name is Verity", lip sync, the 3D portrait in her
# window, no "EVENT ENDS" line, the owner's /test verityvoice) on the Roblox mock with the REAL scripts of this checkout; needs /opt/luau and python3.
#  test_verity_voice.luau   - VerityVoice (pure maths: the cut, the fade, the lip sync, the mouth), VerityConfig, the real VerityService (the live cut on
#                             her model, the 'Greet' message), the real owner command `verityvoice <end> [start]` / `verityvoice` / `verityvoice reset`
#                             (OwnerUpdateCommands82 and the dispatcher: no @target, every bad input refused), the help row.
#  test_verity_lipsync.luau - the real VerityClient with a Sound that behaves like the engine's: PlaybackRegion on EVERY greeting, the end of the cut, the
#                             fade, a refused region, a clip that is not loaded yet, the lip sync in the world (loudness drives a mouth, pauses close it,
#                             it stops with the sound, a rhythm if no loudness is reported), no work idle / far / ReducedMotion / Effects 0, and the
#                             window's ViewportFrame portrait with the same lip sync, built when the window opens and destroyed when it closes.
#  then the R147 client / server suites (run_verity.sh: the dialog without the EVENT ENDS line, the 3D portrait, the quest sentence in full at 13 screen
#  sizes, no empty row) and static checks on the docs.
# "all" also runs every other Verity suite (R147 pack / UI / art, R148 LIMITED Index and roster).
# "mutate" breaks the sources one thing at a time and expects a suite to fail each time.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=$2;mkdir -p "$OUT/srv" "$OUT/cl"
P=$REPO/docs/proposals
T=$REPO/tools/tests;TB=$P/treadmill_bonus_R123/tests;INV=$P/inventory_R113/tests;C=$REPO/src/StarterPlayer/StarterPlayerScripts
if [ "$MODE" = "mutate" ]; then
 python3 "$HERE/mutate_verity.py" "$REPO" "$OUT"
 exit $?
fi
echo "== static checks"
for f in src/ReplicatedStorage/VerityVoice.lua src/ReplicatedStorage/VerityConfig.lua src/ServerScriptService/ChestChaseServer/VerityService.lua src/ServerScriptService/ChestChaseServer/OwnerUpdateCommands82.lua src/StarterPlayer/StarterPlayerScripts/VerityClient.client.lua; do
 /opt/luau/luau-compile --null "$REPO/$f" >/dev/null || { echo "FAIL: $f does not compile"; exit 1; }
done
echo "ok: luau-compile clean"
grep -q 'verityvoice' "$REPO/docs/COMMANDS.md" && grep -q 'GreetingEnd' "$REPO/docs/COMMANDS.md" || { echo "FAIL: docs/COMMANDS.md has no verityvoice row"; exit 1; }
echo "ok: docs/COMMANDS.md documents verityvoice"
grep -q 'VerityVoice' "$REPO/src/MANIFEST.tsv" || { echo "FAIL: src/MANIFEST.tsv has no VerityVoice row"; exit 1; }
echo "ok: src/MANIFEST.tsv lists VerityVoice"
grep -q 'TUNE IN STUDIO' "$REPO/src/ReplicatedStorage/VerityConfig.lua" || { echo "FAIL: VerityConfig does not say the greeting cut is to be tuned in Studio"; exit 1; }
echo "ok: VerityConfig marks GreetingStart / GreetingEnd as TUNE IN STUDIO"
# server world (every ReplicatedStorage and ChestChaseServer module of this checkout)
cp "$T/roblox.luau" "$TB/world.luau" "$HERE/test_verity_voice.luau" "$OUT/srv/";python3 "$TB/mkbundle.py" "$OUT/srv" >/dev/null
# client world (the R113 bundler has this checkout's path hard-coded: point it at this worktree's src)
sed "s#/home/user/tmz/src#$REPO/src#" "$INV/mkbundle.py" > "$OUT/mkbundle_cl.py"
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/test_verity_lipsync.luau" "$OUT/cl/"
python3 "$OUT/mkbundle_cl.py" "$OUT/cl/rs_bundle.luau" VerityClient="$C/VerityClient.client.lua" >/dev/null
cd "$OUT/srv";echo "== test_verity_voice";timeout 600 /opt/luau/luau test_verity_voice.luau > voice.log 2>&1 || { grep -v '^WARN' voice.log | tail -40;exit 1; };grep -v '^WARN' voice.log | tail -1
cd "$OUT/cl";echo "== test_verity_lipsync";timeout 600 /opt/luau/luau test_verity_lipsync.luau > lipsync.log 2>&1 || { grep -v '^WARN' lipsync.log | tail -40;exit 1; };grep -v '^WARN' lipsync.log | tail -1
echo "######## R147 Verity (server + client)";sh "$P/R147/tests/run_verity.sh" "$OUT/r147"
if [ "$MODE" = "all" ]; then
 echo "######## R147 Verity pack";sh "$P/R147/tests/run_verity_pack.sh" "$OUT/r147pack"
 echo "######## R147 Verity UI";sh "$P/R147/tests/run_verity_ui.sh" "$OUT/r147ui" | tail -1
 echo "######## R147 Verity art";sh "$P/R147/tests/run_verity_art.sh" "$OUT/r147art" | tail -1
 echo "######## R148 LIMITED Index";sh "$P/R148/tests/run_index_limited.sh" "$OUT/r148idx" | tail -1
 echo "######## R148 roster";sh "$P/R148/tests/run_roster.sh" "$OUT/r148roster"
fi
echo "all Verity suites passed"
