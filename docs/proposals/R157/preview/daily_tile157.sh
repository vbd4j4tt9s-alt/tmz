#!/bin/sh
# Usage: sh daily_tile157.sh <scratch dir> [before ref]   -> docs/proposals/R157/daily_tile157.png
# R157 (owner: "remove the white background" behind the mystery pack in the DAILY window): the REAL TravelButtons + DailyRewardsClient (and ItemPictures) on the Roblox mock,
# drawn with the R138 renderer (DejaVu stands in for FredokaOne, Noto Color Emoji), BEFORE (the ref's src: the white tile) and AFTER (this checkout: no tile, a thin light
# edge on the silhouette). APPROXIMATE: the mock cannot render the 3D pack, so the pack's slot ('VP:Art' / 'VP:PackTile') gets a STAND-IN pouch shape drawn by daily_tile157.py
# in the exact silhouette colour (10,9,16) and, after, with the exact edge colour (228,222,255) and size (14% bigger, behind) ItemPictures gives it. The gem art shows as 💎.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};BEFORE=${2:-e47715f}
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests;P=$REPO/docs/proposals/R138/preview;TESTS=$REPO/docs/proposals/R140/tests
mkdir -p "$S/before_src" "$S/after" "$S/before"
git -C "$REPO" archive "$BEFORE" src | tar -x -C "$S/before_src"
sed "s#/home/user/tmz/src#$S/before_src/src#;s#^_here = .*#_here = '/nonexistent'#" "$INV/mkbundle.py" > "$S/mkbundle_before.py"
build() { # $1 = work dir, $2 = mkbundle.py, $3 = src dir
 d=$1;mkdir -p "$d"
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/dump_gui.luau" "$d/"
 python3 "$2" "$d/rs_bundle.luau" TravelButtons="$3/StarterPlayer/StarterPlayerScripts/TravelButtons.client.lua" DailyRewardsClient="$3/StarterPlayer/StarterPlayerScripts/DailyRewardsClient.client.lua" >/dev/null
 # setup = the client test up to the first check block of section 1, GemIcon stubbed to its emoji stand-in
 (sed -n '1,/^-- 1\. R157: BASE/p' "$TESTS/test_daily_client.luau" | sed '$d' \
   | sed "s|^local tb=R.new('LocalScript')|W.stub('GemIcon',{new=function()error('preview')end})\nlocal tb=R.new('LocalScript')|";cat "$HERE/daily_tile157_tail.luau") > "$d/preview.luau"
 (cd "$d" && /opt/luau/luau preview.luau > out.log 2>&1 || { tail -20 out.log;exit 1; })
 grep '^JSON ' "$d/out.log" | while read -r _ name json;do printf '%s\n' "$json" > "$d/$name.json";done
}
build "$S/after" "$INV/mkbundle.py" "$REPO/src"
build "$S/before" "$S/mkbundle_before.py" "$S/before_src/src"
python3 "$HERE/daily_tile157.py" "$S" "$REPO/docs/proposals/R157/daily_tile157.png" "$P/render_gui138.py"
