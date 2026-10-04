#!/bin/sh
# Usage: sh run_limited.sh <scratch dir> -> docs/proposals/R148/index_limited.png (the new icon large, the tab row before / after, the LIMITED panel).
# The real ChestIndex (R147's from git for "before": LIMITED_INDEX_BASE, default 23235ce; this checkout's for "after") under the Roblox mock, drawn with
# Pillow by the R137 renderer (approximate), with the real logo pixels pasted in. Needs /opt/luau, python3 + Pillow + zstandard (pip install zstandard).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir}
BASE=${LIMITED_INDEX_BASE:-23235ce}
INV=$REPO/docs/proposals/inventory_R113/tests;P=$REPO/docs/proposals/R137/preview;C=$REPO/src/StarterPlayer/StarterPlayerScripts
mkdir -p "$S"
cp "$REPO/tools/tests/roblox.luau" "$INV/world.luau" "$P/dump_gui.luau" "$S/"
git -C "$REPO" show "$BASE:src/StarterPlayer/StarterPlayerScripts/ChestIndex.client.lua" > "$S/ChestIndexBase.lua"
sed "s#/home/user/tmz/src#$REPO/src#" "$INV/mkbundle.py" > "$S/mkbundle_cl.py"
python3 "$S/mkbundle_cl.py" "$S/rs_bundle.luau" ChestIndexBase="$S/ChestIndexBase.lua" ChestIndex="$C/ChestIndex.client.lua" >/dev/null
for m in old new;do
 (echo "MODE='$m'";cat "$HERE/limited_preview.luau") > "$S/preview_$m.luau"
 (cd "$S" && /opt/luau/luau preview_$m.luau > out_$m.log 2>&1 || { tail -20 out_$m.log;exit 1; })
 grep '^JSON ' "$S/out_$m.log" | sed 's/^JSON //' > "$S/gui_$m.json"
done
python3 "$HERE/render_preview.py" "$S/gui_old.json" "$S/gui_new.json" "$REPO/docs/proposals/R148/index_limited.png"
