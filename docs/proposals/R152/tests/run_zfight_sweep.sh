#!/bin/sh
# Usage: sh run_zfight_sweep.sh [scratch dir] [place.rbxl] [mutate]
# R152 whole-game z-fighting sweep (owner: "after finishing implementation and fixes look for z fighting cases fix them"). Z-fighting = two visible faces that point the same way, lie in
# (nearly) one plane, overlap and look different: they flicker. R149's detector (docs/proposals/R149/tools/zfight.py: coplanar <= 0.002, near <= 0.02, far < 4 steps of a 24-bit depth buffer at
# the distance the overlap is seen from = 0.02 - 0.043 stud) on the finished game, on the Roblox mock with the REAL scripts of this checkout:
#  1. maps    - the owner's place after every real start-up builder (R149's zfight_scene + R151's hub displays + the R152 Void giveaway pedestal): the hub decor (rook battlements, the rook track
#               gate), the displays, the pedestal on the plaza, the market, the treadmills, and the KEYBOARD client around a runner at eight places (the start with the spacebar and the
#               hub, and every biome: the skipped cells and their local floor copies, the Desert oasis, the lava river, the arena at the end). No counted finding that is not on
#               check_zfight_sweep.py's short list of things that are not ours; MeshParts count (their boxes); no two Decals / Textures with one ZIndex on a face; the hub decor's
#               own tight rule (check_hub_zfight.py); every letter strip >= .049 over its keys.
#  2. verity  - the Verity pack (generated flat pouch, seal, strips, the two face Decals) in every context, size and coat.
#  3. opening - the pack-opening scenes: the void vault, the space stage and the throne room (with / without the drawn images, lite), the sky beam's landing on a floor at all three tiers
#               (rings, cracks, debris) and the Legendary / Mythic flourish at three pack scales, sampled through the whole impact; the layer gaps are checked frame by frame.
#  4. keepers - docs/proposals/R152/tests/run_keepers.sh step 4 (the baked models' triangles).
# With "mutate" as the 3rd argument, broken copies of src must each make the sweep fail (the checks have teeth): the letter strips back at .04 over the keys, the opening's ring / crack /
# rim layers back at their old heights ("mutate-only" runs just those, after a full run).
# Without the place file the maps are skipped (verity and opening still run).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:-$(mktemp -d)};PLACE=${2:-/root/.cl""aude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};MODE=$3
mkdir -p "$S"
P=$REPO/docs/proposals
verity() { # $1 = work dir, $2 = src dir
 mkdir -p "$1"
 cp "$REPO/tools/tests/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/inventory_R113/tests/fixtures.luau" "$P/R151/tests/pack_world.luau" "$P/R151/tests/pack_templates.luau" "$P/R151/tests/pouch_mock.luau" "$P/R149/tests/zfight_world.luau" "$HERE/dump_verity_zscene.luau" "$1/"
 python3 "$P/R151/tests/mkbundle_packs.py" "$1" "$2" > /dev/null
 (cd "$1" && timeout 900 /opt/luau/luau dump_verity_zscene.luau > dump.txt 2> dump.err) || { tail -20 "$1/dump.err";return 1; }
}
opening() { # $1 = work dir, $2... = Name=path overrides (a mutant)
 d=$1;shift
 mkdir -p "$d"
 cp "$REPO/tools/tests/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/inventory_R113/tests/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$P/R151/tests/rare_env.luau" "$P/R152/tests/rare152_env.luau" "$P/R152/tests/sound_levels.luau" "$P/R149/tests/zfight_world.luau" "$HERE/dump_opening_zscene.luau" "$d/"
 python3 "$P/R151/tests/mkbundle_rare.py" "$d" all-client "$@" > /dev/null
 (cd "$d" && timeout 1800 /opt/luau/luau dump_opening_zscene.luau > dump.txt 2> dump.err) || { tail -20 "$d/dump.err";return 1; }
}
main_steps() {
if [ -f "$PLACE" ];then
 echo "== 1. maps (the finished map + hub + keyboard at 8 places)"
 sh "$HERE/build_sweep_env.sh" "$S/w" "$PLACE" > /dev/null
 sh "$HERE/run_variant.sh" "$S/w" hub "RUNNER={0,-60};HUB_STATE='champions'" > "$S/w/hub.out" 2>&1 &
 sh "$HERE/run_variant.sh" "$S/w" kb1 "RUNNER={0,600};HUB_STATE='empty'" > "$S/w/kb1.out" 2>&1 &
 sh "$HERE/run_variant.sh" "$S/w" kb2 "RUNNER={0,1500};HUB_STATE='empty'" > "$S/w/kb2.out" 2>&1 &
 wait
 sh "$HERE/run_variant.sh" "$S/w" kb3 "RUNNER={0,2400};HUB_STATE='empty'" > "$S/w/kb3.out" 2>&1 &
 sh "$HERE/run_variant.sh" "$S/w" kb4 "RUNNER={0,3300};HUB_STATE='empty'" > "$S/w/kb4.out" 2>&1 &
 sh "$HERE/run_variant.sh" "$S/w" kb5 "RUNNER={0,3900};HUB_STATE='empty'" > "$S/w/kb5.out" 2>&1 &
 wait
 sh "$HERE/run_variant.sh" "$S/w" kb6 "RUNNER={0,4700};HUB_STATE='empty'" > "$S/w/kb6.out" 2>&1 &
 sh "$HERE/run_variant.sh" "$S/w" kb7 "RUNNER={0,5700};HUB_STATE='empty'" > "$S/w/kb7.out" 2>&1 &
 wait
 for v in hub kb1 kb2 kb3 kb4 kb5 kb6 kb7;do cat "$S/w/$v.out";done
 python3 "$HERE/check_zfight_sweep.py" maps "$S/w" hub kb1 kb2 kb3 kb4 kb5 kb6 kb7
else
 echo "== 1. maps: SKIPPED (no place file at $PLACE)"
fi
echo "== 2. verity pack"
verity "$S/verity" "$REPO/src"
python3 "$HERE/check_zfight_sweep.py" verity "$S/verity/dump.txt"
echo "== 3. pack-opening scenes"
opening "$S/opening"
python3 "$HERE/check_zfight_sweep.py" opening "$S/opening/dump.txt"
}
# (mutate-only: just the mutations, for a quick look)
[ "$MODE" = "mutate-only" ] || main_steps
if [ "$MODE" != "mutate" ] && [ "$MODE" != "mutate-only" ];then exit 0;fi
echo "== mutations: broken copies must make the sweep fail"
RC=0
M=$S/mut;rm -rf "$M";mkdir -p "$M/src"
cp -r "$REPO/src/." "$M/src/"
mutate() { # $1 = name, $2 = file under src, $3 = old, $4 = new (every one replaced once)
 python3 - "$M/src/$2" "$3" "$4" <<'PY'
import sys
p,old,new=sys.argv[1:4]
s=open(p,encoding='utf-8').read()
assert s.count(old)>=1,'mutation target not found: '+old
open(p,'w',encoding='utf-8').write(s.replace(old,new,1))
PY
}
caught() { echo "mutation caught: $1"; }
survived() { echo "MUTATION SURVIVED: $1";RC=1; }
if [ -f "$PLACE" ];then
 mutate kb ReplicatedStorage/KeyboardTrack.lua "Legend={PixelsPerStud=16,TextHeight=4.6,Margin=.05," "Legend={PixelsPerStud=16,TextHeight=4.6,Margin=.04,"
 sh "$HERE/build_sweep_env.sh" "$M/w" "$PLACE" "$M/src" > /dev/null
 sh "$HERE/run_variant.sh" "$M/w" hub "RUNNER={0,-60};HUB_STATE='empty'" > /dev/null 2>&1
 if python3 "$HERE/check_zfight_sweep.py" maps "$M/w" hub > "$M/maps.log" 2>&1;then survived "letter strips .04 over the keys (they and the keys' tops are one plane to the depth rule)";else caught "letter strips .04 over the keys ($(grep -c FLICKER "$M/maps.log") flickers)";fi
 cp "$REPO/src/ReplicatedStorage/KeyboardTrack.lua" "$M/src/ReplicatedStorage/KeyboardTrack.lua"
fi
mutate fx ReplicatedStorage/RarePullFx.lua "CF(g+V(0,.025+.05*i,0))" "CF(g+V(0,.05+.01*i,0))"
mutate fx ReplicatedStorage/RarePullFx.lua "placeRing(self.Ring2,g+V(0,.125,0)," "placeRing(self.Ring2,g+V(0,.04,0),"
mutate flourish ReplicatedStorage/RevealFlourish.lua ".05*s+(r-1)*math.max(.05,.06*s)," ".05*s,"
mutate scenes ReplicatedStorage/RarePullScenes.lua "CF(pack.X,.06,pack.Z)*ANG(0,0,math.pi/2),violet" "CF(pack.X,.04,pack.Z)*ANG(0,0,math.pi/2),violet"
opening "$M/opening" RarePullFx="$M/src/ReplicatedStorage/RarePullFx.lua" RevealFlourish="$M/src/ReplicatedStorage/RevealFlourish.lua" RarePullScenes="$M/src/ReplicatedStorage/RarePullScenes.lua"
python3 "$HERE/check_zfight_sweep.py" opening "$M/opening/dump.txt" > "$M/opening.log" 2>&1 && survived "the opening's layers back at their old heights" || { n=$(grep -c "TOO CLOSE\|FLICKER" "$M/opening.log");[ "$n" -ge 4 ] && caught "the opening's ring / crack / rim layers at their old heights ($n findings)" || survived "the opening mutants: only $n of the 4 layer groups noticed"; }
[ "$RC" = 0 ] && echo "all mutations caught"
exit $RC
