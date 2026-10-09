#!/bin/sh
# Usage: sh run_clover.sh [scratch dir] [mutate]       (needs /opt/luau/luau, python3 with Pillow + numpy, git history with the R152 release)
# R153, the 4 Leaf Clover game pass (2x luck on every pack), on the Roblox mock (/opt/luau/luau) with the REAL modules of this checkout:
#  0. static    - every changed / new script compiles; the pass id is in ONE place (the DefaultId line of GamePassCatalog, no copy anywhere else);
#                 Config.Version and ProfileVersion 22 as in R152; the new modules are in src/MANIFEST.tsv; the load guard is still line 1 of every client script; KeeperMeshes152 is
#                 byte-identical to R152 and the clover has no decoder of its own (EmbeddedImage153); the picture module is under 20 KB and an independent Python decoder agrees with the game's (size, alpha, Adler of the RGBA)
#  1. server    - test_clover.luau: the catalog row / Gem price 999 / the id (default, attribute, 0); luck x1 without, x2 with the pass (Gems, Robux, a purchase in the game, a gift), stacked with
#                 the boots, owner test boots stay TEST luck, the cap, the friend boost (a speed gain) untouched, every pack opening; the Gem purchase (999 off, a second one refused, too few Gems,
#                 id 0 still sells); Robux ownership and PromptGamePassPurchaseFinished; save / load (version 22, the optional Premium.Later153, nothing extra without the pass, junk refused);
#                 gifting (Gem gift, credit receipt, credit use, a pending gift)
#  2. R152      - test_clover_r152.luau in a world made from the R152 release (git archive): an R152 server loads what the R153 server saved (no kick, nothing lost, its own save keeps
#                 Later153) and refuses the shape a plain port would have written; test_clover_back.luau: the R153 server reads what R152 wrote back (the pass is still owned)
#  3. picture   - test_clover_icon.luau: the embedded clover (size, alpha, clean edges, tamper errors), the source priority (pass icon > drawn EditableImage > shapes / emoji), no EditableImage
#                 leak (one per client, destroyed on Release / when the pass icon is everywhere / when a draw half fails), slices, cancel, the real engine path
#  4. client    - test_clover_shop.luau: the card (third PASSES card, "x2 Luck", Gem 999 | Robux live price, picture, buying, OWNED, Checking...), the id switched off (no Robux button, Gem
#                 button full width, ROBUX SOON, OWNED by Gems), the HUD luck row (picture, x2, the cap), the purchase pop; renders the preview (render_clover.py) into $OUT/renders/clover.png
#                 (CLOVER_PREVIEW=1 also copies it to docs/proposals/R153/clover.png)
# R154: the cap is the boots' cap x the pass (the clover's x2 also applies on top of Thunder Boots: x100M); the old_cap mutation puts the R153 cap back.
# "mutate" also breaks the game on purpose (the luck, the saved shape, the id default, the Robux button rule, the picture's priority ...): every break must make a suite fail.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=$2;mkdir -p "$OUT"
R152=${R152_COMMIT:-e36b71b}
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== 0. static"
CATALOG=$S/ReplicatedStorage/GamePassCatalog.lua
NEW="src/ReplicatedStorage/CloverIcon153.lua src/ReplicatedStorage/CloverPassImage153.lua"
CHANGED="src/ReplicatedStorage/GamePassCatalog.lua src/ReplicatedStorage/MechCatalog.lua src/ReplicatedStorage/PremiumBoostCard.lua src/ReplicatedStorage/PremiumEmblems.lua src/ReplicatedStorage/WorldStatusHud.lua src/ServerScriptService/ChestChaseServer/PlayerDataService.lua src/ServerScriptService/ChestChaseServer/PremiumProgress.lua src/ServerScriptService/ChestChaseServer/PurchaseAnnouncer.lua src/ReplicatedStorage/EmbeddedImage153.lua src/StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua src/StarterPlayer/StarterPlayerScripts/PurchaseCelebration.client.lua"
for f in $NEW $CHANGED;do /opt/luau/luau-compile --null "$REPO/$f" >/dev/null 2>&1 || fail "$f does not compile";done;echo "ok: $(echo $NEW $CHANGED | wc -w) new / changed scripts compile"
# the pass id: one place
ID=$(sed -n 's/.*Key=.Clover.*DefaultId=\([0-9][0-9]*\).*/\1/p' "$CATALOG")
[ -n "$ID" ] || fail "the Clover row of GamePassCatalog has no DefaultId=<number>"
[ "$(grep -c 'DefaultId=' "$CATALOG")" = 1 ] || fail "DefaultId= must appear exactly once in GamePassCatalog"
if [ -n "$ID" ] && [ "$ID" != 0 ];then
 COPIES=$(grep -rIlw "$ID" "$REPO/src" "$REPO/docs" "$REPO/tools" "$REPO/installers" 2>/dev/null | grep -v "^$CATALOG$" | grep -vE "/docs/releases/|/docs/HANDOFF" || true) # (R154: the release notes and the handoff name it for the owner's publish checklist; code never copies it)
 [ -z "$COPIES" ] && echo "ok: the pass id ($ID) is in exactly one place: the DefaultId of the Clover row in GamePassCatalog.lua" || { fail "the pass id is copied outside the catalog:";echo "$COPIES"; }
fi
V=$(grep -c "Config.Version='V150 R153b';Config.ProfileVersion=22" "$S/ServerScriptService/ChestChaseServer/Config.lua")
[ "$V" = 1 ] && echo "ok: Config.Version is 'V150 R153b' and ProfileVersion 22" || fail "Config.Version / ProfileVersion changed"
for p in CloverIcon153 CloverPassImage153;do grep -q "ReplicatedStorage/$p	" "$S/MANIFEST.tsv" || fail "$p is not in src/MANIFEST.tsv";done;echo "ok: the 2 new modules are in src/MANIFEST.tsv"
sh "$P/R152/tests/run_load_guard.sh" "$OUT/guard" > "$OUT/guard.log" 2>&1 && echo "ok: the R152 load guard is still line 1 of every client script ($(tail -1 "$OUT/guard.log"))" || { fail "the load guard test fails";tail -5 "$OUT/guard.log"; }
BYTES=$(wc -c < "$S/ReplicatedStorage/CloverPassImage153.lua");[ "$BYTES" -lt 20480 ] && echo "ok: the picture module is $BYTES bytes (under 20 KB)" || fail "the picture module is $BYTES bytes"
# KeeperMeshes152 is byte-identical to the R152 release; the clover has NO decoder of its own: it is drawn through EmbeddedImage153 (the game's one embedded-image decoder)
KEEPER=src/ServerScriptService/ChestChaseServer/KeeperMeshes152.lua
git -C "$REPO" show "$R152:$KEEPER" > "$OUT/keeper_r152.txt"
cmp -s "$OUT/keeper_r152.txt" "$REPO/$KEEPER" && echo "ok: KeeperMeshes152 is byte-identical to the R152 release (the keepers are untouched)" || fail "KeeperMeshes152 differs from the R152 release"
if grep -qE "local function (inflate|base64)|LBASE|DBASE" "$S/ReplicatedStorage/CloverIcon153.lua" "$S/ReplicatedStorage/CloverPassImage153.lua";then fail "the clover files hold a decoder of their own";else echo "ok: no second decoder: CloverIcon153 / CloverPassImage153 hold none, the picture goes through EmbeddedImage153";fi
grep -q "require(script.Parent.EmbeddedImage153)" "$S/ReplicatedStorage/CloverIcon153.lua" && grep -q "^return {Key='CloverPass153'" "$S/ReplicatedStorage/CloverPassImage153.lua" || fail "CloverIcon153 must use EmbeddedImage153 and CloverPassImage153 must have its Key"
python3 -I "$P/R153/tools/encode_clover.py" --adler > "$OUT/py_adler.txt" || fail "the independent Python decoder rejects the picture module"
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|(op[u]s|sonn[e]t|haik[u])[ -]?[0-9]|gp[t]-?[0-9]" "$HERE" "$P/R153/tools" $(for f in $NEW $CHANGED;do echo "$REPO/$f";done) 2>/dev/null | grep -v "Binary file" | grep -v '/run_clover.sh:' | grep -q .;then fail "a model name in the R153 files";else echo "ok: no model names in the R153 files";fi
# worlds -------------------------------------------------------------------------------------------------------------------------------------------
build(){ # dir srcdir
 mkdir -p "$1";cp "$T/roblox.luau" "$P/treadmill_bonus_R123/tests/world.luau" "$HERE"/*.luau "$1/"
 python3 "$HERE/mkbundle_clover.py" "$1" --src "$2" --font "$P/shop_R120/tests/FredokaOne.ttf" > /dev/null
}
run(){ # dir test
 ( cd "$1" && timeout 900 /opt/luau/luau "$2.luau" > "$2.log" 2>&1 ) || { grep -v '^WARN\|^PROFILE\|^RESAVED\|^DUMP\|^CLOVERRGBA' "$1/$2.log" | tail -30;fail "$2 FAILED";return 1; }
 echo "$2: $(grep -v '^WARN\|^PROFILE\|^RESAVED\|^DUMP\|^CLOVERRGBA\|^ADLER' "$1/$2.log" | tail -1)"
}
table(){ # prefix in out name
 { echo 'return {';sed -n "s/^$1 \([a-z0-9]*\) \(.*\)\$/ \1=\2,/p" "$2";echo '}'; } > "$3"
}
echo "== 1. server (R153)"
W153=$OUT/w153;rm -rf "$W153";build "$W153" "$S"
run "$W153" test_clover
echo "== 2. an R152 server"
rm -rf "$OUT/r152_src";mkdir -p "$OUT/r152_src"
git -C "$REPO" archive "$R152" src | tar -x -C "$OUT/r152_src" || { fail "git archive $R152 (the R152 release must be in the history)";exit 1; }
W152=$OUT/w152;rm -rf "$W152";build "$W152" "$OUT/r152_src/src"
table PROFILE "$W153/test_clover.log" "$W152/profiles.luau"
run "$W152" test_clover_r152
table RESAVED "$W152/test_clover_r152.log" "$W153/resaved.luau";cp "$W152/profiles.luau" "$W153/profiles.luau"
run "$W153" test_clover_back
echo "== 3. the picture"
run "$W153" test_clover_icon
LUA_ADLER=$(sed -n 's/^ADLER //p' "$W153/test_clover_icon.log");PY_ADLER=$(sed -n 's/^ADLER //p' "$OUT/py_adler.txt")
[ -n "$LUA_ADLER" ] && [ "$LUA_ADLER" = "$PY_ADLER" ] && echo "ok: the game's decoder (EmbeddedImage153) and the independent Python decoder make the same RGBA (Adler-32 $LUA_ADLER)" || fail "the decoders disagree (game $LUA_ADLER, python $PY_ADLER)"
echo "== 4. the shop, the HUD, the purchase pop"
run "$W153" test_clover_shop
mkdir -p "$OUT/renders";python3 "$P/R153/tools/render_clover.py" "$W153/test_clover_shop.log" "$OUT/renders" > "$OUT/renders.log" 2>&1 && echo "ok: preview rendered: $OUT/renders/clover.png" || { fail "render_clover.py";tail -5 "$OUT/renders.log"; }
[ -n "$CLOVER_PREVIEW" ] && cp "$OUT/renders/clover.png" "$P/R153/clover.png" && echo "(copied to docs/proposals/R153/clover.png)"
# mutations ----------------------------------------------------------------------------------------------------------------------------------------
if [ "$MODE" = "mutate" ];then
 echo "== mutations (each break must be noticed by a suite)"
 MUT=$OUT/mut;mkdir -p "$MUT";SSS=$S/ServerScriptService/ChestChaseServer;RSD=$S/ReplicatedStorage;SP=$S/StarterPlayer/StarterPlayerScripts
 mutate(){ # name file old new suite world
  name=$1;file=$2;old=$3;new=$4;suite=$5
  python3 - "$file" "$old" "$new" "$MUT/$name.lua" <<'PY' || { fail "mutation $name: the pattern is not in the file";return; }
import sys
f,old,new,out=sys.argv[1:5]
s=open(f,encoding='utf-8').read()
assert old in s,old
open(out,'w',encoding='utf-8').write(s.replace(old,new,1))
PY
  rm -rf "$MUT/w_$name";mkdir -p "$MUT/w_$name";cp "$T/roblox.luau" "$P/treadmill_bonus_R123/tests/world.luau" "$HERE"/*.luau "$MUT/w_$name/"
  [ -f "$W153/profiles.luau" ] && cp "$W153/profiles.luau" "$W153/resaved.luau" "$MUT/w_$name/"
  modname=$(basename "$file" .lua);modname=${modname%.client}
  python3 "$HERE/mkbundle_clover.py" "$MUT/w_$name" "$modname=$MUT/$name.lua" --font "$P/shop_R120/tests/FredokaOne.ttf" > /dev/null
  if ( cd "$MUT/w_$name" && timeout 900 /opt/luau/luau "$suite.luau" > "$suite.log" 2>&1 );then fail "mutation $name was NOT noticed by $suite";else echo "ok: $name -> $suite fails ($(grep -c '^FAIL' "$MUT/w_$name/$suite.log") failing checks)";fi
 }
 mutate no_luck "$SSS/PlayerDataService.lua" "bestLuckMultiplier=math.clamp(bestLuckMultiplier*passLuck," "bestLuckMultiplier=math.clamp(bestLuckMultiplier," test_clover
 mutate old_cap "$SSS/PlayerDataService.lua" "BalanceValues81).MaxLuck*passLuck)" "BalanceValues81).MaxLuck)" test_clover
 mutate no_signal "$SSS/PlayerDataService.lua" "player:GetAttributeChangedSignal(pass.Attribute):Connect(" "player:GetAttributeChangedSignal('NeverSet'):Connect(" test_clover
 mutate unsplit_save "$SSS/PremiumProgress.lua" " premium.Later153=any and out or nil" " premium.Later153=nil;for k,v in pairs(out.Entitlements)do premium.Entitlements[k]=v end" test_clover
 mutate gem_price "$RSD/MechCatalog.lua" "Clover=999" "Clover=99" test_clover
 mutate default_id "$RSD/GamePassCatalog.lua" "if id==nil then id=pass.DefaultId end" "" test_clover
 mutate announcer_icon "$SSS/PurchaseAnnouncer.lua" "Icon=row and row.Icon or nil" "Icon=nil" test_clover
 mutate robux_button "$SP/GamePassClient.client.lua" "if v.Robux.Visible==soon then v.Robux.Visible=not soon;reflow=true end" "" test_clover_shop
 mutate pass_icon "$RSD/CloverIcon153.lua" "local usePass=pass~=nil and pass.IsLoaded==true" "local usePass=false" test_clover_icon
 mutate leak "$RSD/CloverIcon153.lua" "pcall(function()embedded().Release(emb)end)" "" test_clover_icon
 mutate no_start "$RSD/CloverIcon153.lua" "if not(pass and pass.IsLoaded==true)then startRoot(root)end" "" test_clover_icon
 mutate write_leak "$RSD/EmbeddedImage153.lua" "if not written then pcall(image.Destroy,image);error(why,0)end" "if not written then error(why,0)end" test_clover_icon
 mutate no_ensure "$RSD/WorldStatusHud.lua" "if i==2 and active then pcall(function()require(RS.CloverIcon153).Ensure()end)end" "" test_clover_shop
 mutate tag_title "$RSD/PremiumBoostCard.lua" "Clover={Title='x2 Luck'" "Clover={Title='Lucky Clover Pass Deluxe'" test_clover_shop
 mutate old_server_ok "$SSS/PremiumProgress.lua" "saved=P.Unpack(saved);if not saved then return nil end" "" test_clover
fi
[ $RC = 0 ] && echo "R153 clover suites: PASS" || echo "R153 clover suites: FAIL"
exit $RC
