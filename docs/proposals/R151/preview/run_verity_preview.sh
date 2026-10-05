#!/bin/sh
# Usage: sh run_verity_preview.sh <scratch dir> [before revision, default c1e8829 = the R150 build the owner played]
# Renders the window's portrait of Verity (rest / mid / peak of "Hello, my name is Verity") of the R150 build ("before": the dark mouth oval) and of this
# checkout ("after": no mouth, the ball bounces) from the numbers the REAL VerityClient.client.lua produces on the Roblox mock (dump_verity_tail.luau
# appended to the first 158 lines of docs/proposals/R149/tests/test_verity_lipsync.luau), draws them with three.js (headless Chromium via playwright,
# swiftshader) and writes docs/proposals/R151/verity_fix.png. Needs /opt/luau, git, python3 + Pillow, node + playwright (global), `npm install three`.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};BEFORE=${2:-c1e8829}
INV=$REPO/docs/proposals/inventory_R113/tests;T=$REPO/tools/tests
mkdir -p "$S/before" "$S/after" "$S/before_src" "$S/out"
cp -r "$REPO/src/." "$S/before_src/"
for f in ReplicatedStorage/VerityConfig.lua ReplicatedStorage/VerityVoice.lua StarterPlayer/StarterPlayerScripts/VerityClient.client.lua; do
 git -C "$REPO" show "$BEFORE:src/$f" > "$S/before_src/$f"
done
for v in before after; do
 if [ "$v" = before ]; then SRC=$S/before_src; else SRC=$REPO/src; fi
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$S/$v/"
 { head -158 "$REPO/docs/proposals/R149/tests/test_verity_lipsync.luau"; cat "$HERE/dump_verity_tail.luau"; } > "$S/$v/dump.luau"
 sed "s#/home/user/tmz/src#$SRC#" "$INV/mkbundle.py" > "$S/$v/mkbundle_cl.py"
 python3 "$S/$v/mkbundle_cl.py" "$S/$v/rs_bundle.luau" VerityClient="$SRC/StarterPlayer/StarterPlayerScripts/VerityClient.client.lua" >/dev/null
 (cd "$S/$v" && /opt/luau/luau dump.luau > frames.txt 2>&1) || { grep -v '^WARN' "$S/$v/frames.txt" | tail -20;exit 1; }
done
cp "$HERE/verity_portrait.html" "$HERE/render_verity_portrait.mjs" "$S/"
[ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null)
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
for v in before after; do
 if [ "$v" = before ]; then L="R150 build ($BEFORE): the dark mouth oval follows the voice"; else L="R151: no mouth; the ball swells and bounces with the voice (portrait viewport dashed)"; fi
 PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_verity_portrait.mjs" "$S" "$S/$v/frames.txt" "$S/out/$v.png" "$L"
done
python3 "$HERE/make_verity_sheet.py" "$S/out" "$REPO/docs/proposals/R151"
