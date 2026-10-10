#!/bin/sh
# Usage: sh run_pyramid156.sh [scratch dir] [place.rbxl] [mutate]
# R156 the Desert's secret pyramid (owner: "a pyramid can have the mythic pack of that biome its a one time thing so players collect it once and its gone. the snake will
# still chase them tho and its same and mutations are all fixed"; "it will just be in the pyramid model no secret passage and no pedestal just a floating pack in the
# pyramid model ... we can replace the current pyramid in the game"; "hollow the inside and make sure that players can hold e when looking inside the pyramid"), on the
# Roblox mock (/opt/luau/luau) with the REAL modules / scripts of this checkout:
#  static                       the new files and the manifest, every touched script compiles at -O0, the client's line 1 is the load guard, the hooks are where they
#                               belong (the map pass, the bank, the catch hooks on the chase object, the start, the owner command), ConcurrentKeeperService (R149),
#                               Config.lua / BackgroundMusic / BiomeMood untouched, no model names
#  test_pyramid_server156.luau  the map pass on a Sunscar stand-in; the prompt (the world packs' Hold E); joining (new, old and broken saves); reach from the 4 sides and the
#                               4 corners at ground level, not from twice that; the take (the normal steal checks, a Desert Mythic world pack's record, the Sand Snake
#                               chases); caught / a bat / lightning / a hole / a fall / leaving: back in the pyramid; banked: the claim (saved), the pack-size pity and the
#                               pack pity count it; a claimed player's trigger; the 200 cap's refusal; one each; save / load; the refresh closure; /test pyramid (+ reset);
#                               R157 review fix, the biome refresh on the REAL refresh code: a secret carrier inside the track / outside it (the stale-runs loop) / waiting in the
#                               keeper queue goes back (not banked, not claimed, not saved, 'Refresh' notice), a normal pack is kept as before, and Hold E is refused (nothing changed,
#                               a notice) while the refresh runs and in the RefreshGuard seconds before it, and works just outside that window
#  test_pyramid_client156.luau  the floating pack (built per player, the Desert Mythic art, at the centre), the turn and the bob (4 tweens, nothing per frame), the prompt
#                               from the sides / corners / steps / inside and not from twice the reach, 'Out' / 'Claimed' / reset, far away, streaming
#  pyramid_map156.luau          the owner's place after the REAL start-up passes: the Sunscar Pyramid replaced in place, every slab of the owner's model (read from his
#                               .rbxm dump, not from PyramidRules156) at the scale, hollow and sealed, the fit (walls, camp, pack spots, spawns, props), the Hold E zone
#                               holds no other building, the keyboard leaves out every key under it
#  check_pyramid_zfight156.py   the same place with R152's sweep world (the keyboard client around the pyramid): R149's detector finds nothing on the pyramid, and no
#                               two pyramid faces share a plane facing the same way
# Without the place file the place steps are skipped (the server and client suites still run). With "mutate" as the 3rd argument, broken copies of src must each make
# a step fail (the checks have teeth).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};PLACE=${2:-/root/.cl""aude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};MODE=$3;BASE=${BASE:-c432356}
mkdir -p "$OUT"
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;SS=$S/ServerScriptService/ChestChaseServer;SP=$S/StarterPlayer/StarterPlayerScripts;RS=$S/ReplicatedStorage
CLIENT=StarterPlayer/StarterPlayerScripts/SecretPyramidClient156.client.lua
run() { # $1 dir, $2 file, $3 label
 if (cd "$1" && timeout 900 /opt/luau/luau "$2" > "$2.log" 2>&1);then echo "  $3: $(grep -v '^WARN' "$1/$2.log" | tail -1)";return 0
 else echo "  $3: FAILED";grep '^FAIL' "$1/$2.log" | head -15;grep -v '^WARN' "$1/$2.log" | grep -iE 'error|stack|:[0-9]+:' | head -5;return 1;fi
}
server() { # $1 dir, $2 src
 mkdir -p "$1";cp "$T/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/inventory_R113/tests/fixtures.luau" "$P/R151/tests/pack_world.luau" "$P/R151/tests/pack_templates.luau" "$P/R151/tests/pouch_mock.luau" "$HERE/test_pyramid_server156.luau" "$1/"
 python3 "$P/R151/tests/mkbundle_packs.py" "$1" "$2" --server >/dev/null
 run "$1" test_pyramid_server156.luau "server"
}
client() { # $1 dir, $2 src
 mkdir -p "$1";cp "$T/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/inventory_R113/tests/fixtures.luau" "$P/R151/tests/pack_world.luau" "$P/R151/tests/pack_templates.luau" "$HERE/test_pyramid_client156.luau" "$1/"
 python3 "$P/R151/tests/mkbundle_packs.py" "$1" "$2" --server SecretPyramidClient156="$2/$CLIENT" >/dev/null
 run "$1" test_pyramid_client156.luau "client"
}
mapscene() { # $1 dir, $2 src
 mkdir -p "$1";cp "$T/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/R149/tests/zfight_world.luau" "$1/"
 python3 "$P/R149/tests/zfight_bundle.py" "$2" "$1" >/dev/null
 [ -f "$OUT/place_tree.luau" ] || python3 "$P/R149/tools/rbxl_geom.py" --tree "$PLACE" "$OUT/place_tree.luau" Workspace/ChestChaseMap >/dev/null
 cp "$OUT/place_tree.luau" "$1/"
 python3 "$HERE/owner_slabs.py" "$REPO/docs/proposals/R156/pyramid/classic_pyramid_parts.json" "$1/owner_slabs.luau" >/dev/null
 (echo '--!nocheck';sed -n 11,63p "$P/R149/tests/zfight_scene.luau";cat "$HERE/pyramid_map156.luau") > "$1/run_map.luau"
 if (cd "$1" && timeout 900 /opt/luau/luau run_map.luau > map.log 2>&1);then grep '^GEO' "$1/map.log";echo "  map: $(tail -1 "$1/map.log")";return 0
 else echo "  map: FAILED";grep -E '^FAIL|STEP .* FAILED' "$1/map.log" | head -15;grep -v '^WARN' "$1/map.log" | grep -iE 'error|stack' | head -5;return 1;fi
}
zscene() { # $1 dir, $2 src
 sh "$P/R152/tests/build_sweep_env.sh" "$1" "$PLACE" "$2" >/dev/null
 sh "$P/R152/tests/run_variant.sh" "$1" pyramid "RUNNER={-20,1005};HUB_STATE='empty'" >/dev/null
 python3 "$HERE/check_pyramid_zfight156.py" "$1/pyramid.json"
}
if [ "$MODE" != "mutate" ];then
echo "== static"
fail=0;bad() { echo "FAIL: $1";fail=1; }
for rel in ReplicatedStorage/PyramidRules156.lua ServerScriptService/ChestChaseServer/SecretPyramid156.lua $CLIENT;do
 [ -f "$S/$rel" ] || bad "$rel is missing"
 grep -q "	${rel%.lua}	$rel$" "$S/MANIFEST.tsv" 2>/dev/null || grep -q "	${rel%.client.lua}	$rel$" "$S/MANIFEST.tsv" || bad "$rel is not in src/MANIFEST.tsv"
done
for f in "$RS/PyramidRules156.lua" "$SS/SecretPyramid156.lua" "$S/$CLIENT" "$RS/KeyboardSkip152.lua" "$RS/StudioTestHelp.lua" "$SS/MapService.lua" "$SS/ChestService.lua" "$SS/ConcurrentKeeperService.lua" "$SS/OwnerUpdateCommands82.lua" "$SS/OwnerCommandTargets82.lua" "$S/ServerScriptService/ChestChaseServerMain.server.lua";do
 /opt/luau/luau-compile -O0 --binary "$f" >/dev/null 2>"$OUT/compile.err" || bad "$f does not compile at -O0: $(head -1 "$OUT/compile.err")"
done
head -1 "$S/$CLIENT" | grep -q "R152: start once the whole game has arrived" || bad "the client's line 1 is not the load guard"
grep -q "require(script.Parent.SecretPyramid156).Apply(mapRoot)" "$SS/MapService.lua" || bad "MapService.new does not run the pyramid's map pass"
grep -q "self.Pyramid156.Banked, self.Pyramid156, player, seed, record" "$SS/ChestService.lua" || bad "ChestService:Bank does not claim the pyramid pack"
grep -q "self:_returnPackToOrigin(run.Chest,hit and hit.Cause or'Keeper')" "$SS/SecretPyramid156.lua" || bad "a caught pyramid pack is not sent back to the pyramid"
grep -q "if type(chest)=='table'and chest.Pyramid156~=nil then return self.Pyramid156~=nil and self.Pyramid156:Returned(chest,cause)==true end" "$SS/SecretPyramid156.lua" || bad "a lost pyramid pack is not sent back to the pyramid"
grep -q "self.Chase.Pyramid156=self;self.Chests.Pyramid156=self;M.HookChase(self.Chase)" "$SS/SecretPyramid156.lua" || bad "Start does not hook the chase service"
grep -q "local ok,err=pcall(self.Pyramid156.RefreshReturns,self.Pyramid156)" "$SS/SecretPyramid156.lua" && grep -q "pcall(chase.Finish,chase,false,false,run)" "$SS/SecretPyramid156.lua" || bad "the biome refresh does not send the secret carries back first (Finish(false,false,run))"
grep -q "if self:RefreshNear(now)then say(self,player,Rules.Text.RefreshSoon,AMBER);return refuse(self,'refresh')end" "$SS/SecretPyramid156.lua" || bad "Trigger does not refuse near the biome refresh"
# the chase hooks sit on the chase service object: ConcurrentKeeperService itself (frozen by R149's run_tiger_gear) is not touched
# (R158, on purpose: apart from the owner's "no SMACK" pack-drop notice and the bat packet's AttackerUserId, exact lines: tools/tests/r152_real_diff.sh)
sh "$T/r152_real_diff.sh" "$REPO" "$BASE" src/ServerScriptService/ChestChaseServer/ConcurrentKeeperService.lua >/dev/null || bad "ConcurrentKeeperService.lua changed (R149 freezes it: the pyramid hooks the chase service object instead)"
grep -q "require(modules.SecretPyramid156).new(Config,playerData,chestService,chaseService,notifications,mapService):Start()" "$S/ServerScriptService/ChestChaseServerMain.server.lua" || bad "the server does not start the pyramid"
grep -q "^X.Actions.pyramid=true" "$SS/OwnerUpdateCommands82.lua" && grep -q "action=='pyramid'then return require(script.Parent.SecretPyramid156).Command" "$SS/OwnerUpdateCommands82.lua" || bad "/test pyramid is not dispatched"
grep -q "'/test pyramid @username reset'" "$RS/StudioTestHelp.lua" || bad "/test pyramid is not in the F4 help"
# (BASE = the R156 release R157 is built on; Config may differ only in its Version line, which every release bumps)
for f in src/ServerScriptService/ChestChaseServer/Config.lua src/StarterPlayer/StarterPlayerScripts/BackgroundMusic.client.lua src/ReplicatedStorage/BiomeMood.lua;do
 git -C "$REPO" show "$BASE:$f" | sed "s/Config.Version='V150 R1[0-9a-z]*'/Config.Version='V150 R1xx'/" > "$OUT/base_file.txt"
 sed "s/Config.Version='V150 R1[0-9a-z]*'/Config.Version='V150 R1xx'/" "$REPO/$f" | cmp -s - "$OUT/base_file.txt" || { [ "$f" = src/StarterPlayer/StarterPlayerScripts/BackgroundMusic.client.lua ] && sh "$T/bgm_frozen.sh" "$REPO"; } || bad "$f changed (the pyramid must not touch it)" # R157b fix (on purpose): the track music fix in BackgroundMusic is accepted by its frozen hash
done
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|(op[u]s|sonn[e]t|haik[u])[ -]?[0-9]" "$HERE" "$P/R156/pyramid.md" "$P/R156/preview" "$RS/PyramidRules156.lua" "$SS/SecretPyramid156.lua" "$S/$CLIENT" 2>/dev/null;then bad "a model name in the R156 pyramid files";fi
[ "$fail" = 0 ]
echo "  static: ok (3 new files in the manifest, 11 scripts compile at -O0, the load guard, the hooks, ConcurrentKeeperService, Config / BackgroundMusic / BiomeMood untouched)"
echo "== server";server "$OUT/server" "$S"
echo "== client";client "$OUT/client" "$S"
if [ -f "$PLACE" ];then
 echo "== the owner's place";mapscene "$OUT/map" "$S"
 echo "== z-fighting around the pyramid (the keyboard drawn around it)";zscene "$OUT/z" "$S"
else echo "== the owner's place: SKIPPED (no place file at $PLACE)";fi
echo "R156 pyramid suites passed"
exit 0
fi
# --- mutations: one break at a time in a copy of src; a step must fail ------------------------------------------------------------------------------------------------
M=$OUT/mut_src;caught=0;total=0
mutate() { # $1 = name, $2 = file under src, $3 = old text, $4 = new text, $5 = the step that must fail (server | client | map | z)
 rm -rf "$M";mkdir -p "$M";cp -r "$S/." "$M/"
 python3 - "$M/$2" "$3" "$4" <<'PY'
import sys
p,old,new=sys.argv[1:4]
s=open(p,encoding='utf-8').read()
assert s.count(old)>=1,'mutation target not found: '+old
open(p,'w',encoding='utf-8').write(s.replace(old,new,1))
PY
 total=$((total+1))
 case $5 in server) step() { server "$OUT/m_$total" "$M"; };; client) step() { client "$OUT/m_$total" "$M"; };; map) step() { mapscene "$OUT/m_$total" "$M"; };; z) step() { zscene "$OUT/m_$total" "$M"; };; esac
 if step >"$OUT/mut_$total.log" 2>&1;then echo "MUTATION SURVIVED: $1";else echo "mutation caught: $1";caught=$((caught+1));fi
}
C=ServerScriptService/ChestChaseServer
mutate "a caught pyramid pack is dropped on the track (no way back into the pyramid)" $C/SecretPyramid156.lua "if not(run and type(run.Chest)=='table'and run.Chest.Pyramid156~=nil)then return drop(self,run,hit)end" "do return drop(self,run,hit)end" server
mutate "a lost pyramid pack goes to the normal return code (never back into the pyramid)" $C/SecretPyramid156.lua "if type(chest)=='table'and chest.Pyramid156~=nil then return self.Pyramid156~=nil and self.Pyramid156:Returned(chest,cause)==true end" "" server
mutate "the bank does not claim it" $C/ChestService.lua "if seed.Pyramid156 ~= nil and self.Pyramid156 then" "if false then" server
mutate "a claimed player may take it again" $C/SecretPyramid156.lua "if self:Claimed(player)then self:_publish(player);return refuse(self,'claimed')end" "" server
mutate "the biome refresh banks a secret carry again (the refresh hook is gone)" $C/SecretPyramid156.lua "local ok,err=pcall(self.Pyramid156.RefreshReturns,self.Pyramid156)" "local ok,err=true,nil" server
mutate "the refresh return banks the pack (Finish(true))" $C/SecretPyramid156.lua "pcall(chase.Finish,chase,false,false,run)" "pcall(chase.Finish,chase,true,false,run)" server
mutate "only a secret carrier inside the biome track is sent back for the refresh (the stale-runs loop banks the others)" $C/SecretPyramid156.lua "run.Chest.Pyramid156~=nil then ended[#ended+1]=run end" "run.Chest.Pyramid156~=nil and chase.Map:IsInsideBiomeTrack(run.HumanoidRootPart.Position)then ended[#ended+1]=run end" server
mutate "the refresh return shows the 'lost' notice, not the refresh notice" $C/SecretPyramid156.lua " cause=cause or chest.Pyramid156End
" "
" server
mutate "Hold E works while the biomes refresh and just before (no guard)" $C/SecretPyramid156.lua " if self:RefreshNear(now)then say(self,player,Rules.Text.RefreshSoon,AMBER);return refuse(self,'refresh')end" "" server
mutate "the guard is only 1 second" ReplicatedStorage/PyramidRules156.lua "P.RefreshGuard=15 " "P.RefreshGuard=1 " server
mutate "the zone reaches 40 studs past the base" ReplicatedStorage/PyramidRules156.lua "P.Margin=6 " "P.Margin=40 " server
mutate "the steal rules are skipped (no 200 cap)" $C/SecretPyramid156.lua "local c,h,r=chase:_canTake(player,root.Position)" "local c,h,r=player.Character,player.Character:FindFirstChildOfClass('Humanoid'),root" server
mutate "the client shows the pack to a claimed player" StarterPlayer/StarterPlayerScripts/SecretPyramidClient156.client.lua "local open=state()==Rules.State.Open" "local open=state()~=nil" client
mutate "the pack is no longer the Desert Mythic (Pack05)" ReplicatedStorage/PyramidRules156.lua "BagVariant='Pack06'" "BagVariant='Pack05'" client
if [ -f "$PLACE" ];then
 mutate "the pyramid is not hollow (every slab solid)" ReplicatedStorage/PyramidRules156.lua "if i==1 or i>n-P.Caps then" "if true then" map
 mutate "the keyboard keeps the keys under the pyramid" ReplicatedStorage/KeyboardSkip152.lua "if item.Clear and(flat or prop)then" "if false then" map
 mutate "the ring walls overlap (the side walls run the full width)" ReplicatedStorage/PyramidRules156.lua "Size={a-c,h,2*d},Pos={(a+c)/2,y,0}}" "Size={a-c,h,2*b},Pos={(a+c)/2,y,0}}" z
fi
echo "$caught of $total mutations caught"
[ "$caught" = "$total" ]
