#!/bin/sh
# Usage: sh run_verity_pack.sh [scratch dir] [--mutations]. R149 Verity pack (owner: "pure yellow and the face plastered nice onto the pack",
# then "not floating on the pack ... nicely plastered") on the Roblox mock (/opt/luau/luau) with the REAL modules / scripts of this checkout
# (SeedPackVisuals, SeedPackRenderer, VerityPackArt, VoidPackFx, ItemPictures, VeiledEventClient81, SeedPackRender). The template of the
# Verity pack's design (Storm_02) is the REAL one, read out of the place file: ONE MeshPart, its print in vertex colours
# (verity_template.luau). "Every other pack unchanged" compares against the base commit (VERITY_BASE, default 0b08836 = R148 as installed):
# its SeedPackVisuals / SeedPackRenderer / EclipsePackArt / VoidPackFx / VerityPackArt come from git, are renamed (...Base) and run beside
# the new ones part by part.
#  test_verity_pack.luau - every part pure yellow 255,255,0 SmoothPlastic (seal and tear strips too), no mesh / texture / SurfaceAppearance /
#                          SurfaceGui / emitter / light / highlight; Verity's picture as a Decal on the face block's own Front and Back;
#                          nothing in front of it, no step to the body (side view), in every context (ground, carried, hotbar / Bag
#                          picture, ViewportFrame, the real ItemPictures, opening copy, giant, tiny, Gold / Diamond coat); no effects;
#                          every other pack identical to the base.
#                          (R151: these run with no neutral pouch template, so they check the sachet, the fallback. The real pouch has its own
#                          suite, ../../R151/tests/run_verity_pouch.sh, run at the end.)
#  --mutations           - also breaks VerityPackArt six ways (the R148 art, a darker seal, a floating face plate, an emitter, a tinted Decal,
#                          an extra mesh) and expects the test to notice each one.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
BASE=${VERITY_BASE:-0b08836}
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests;C=$REPO/src/StarterPlayer/StarterPlayerScripts
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/test_verity_pack.luau" "$HERE/verity_template.luau" "$OUT/"
show(){ git -C "$REPO" show "$BASE:$1"; }
show src/ReplicatedStorage/SeedPackVisuals.lua | sed -e "s/script.Parent.SeedPackRenderer/script.Parent.SeedPackRendererBase/g" -e "s/script.Parent.EclipsePackArt/script.Parent.EclipsePackArtBase/g" > "$OUT/SeedPackVisualsBase.lua"
show src/ReplicatedStorage/SeedPackRenderer.lua | sed -e "s/script.Parent.EclipsePackArt/script.Parent.EclipsePackArtBase/g" -e "s/script.Parent.VerityPackArt/script.Parent.VerityPackArtBase/g" > "$OUT/SeedPackRendererBase.lua"
show src/ReplicatedStorage/EclipsePackArt.lua | sed -e "s/script.Parent.SeedPackRenderer/script.Parent.SeedPackRendererBase/g" > "$OUT/EclipsePackArtBase.lua"
show src/ReplicatedStorage/VoidPackFx.lua > "$OUT/VoidPackFxBase.lua"
show src/ReplicatedStorage/VerityPackArt.lua > "$OUT/VerityPackArtBase.lua"
# R151: the base copies carry the three documented R151 pack fixes (giant packs' seal / strips tagged, the Void's print backed, the pads' moss / ice thicker), so "identical" still means "nothing else changed"
python3 "$HERE/../../R151/tests/rebase_r151.py" "$OUT/SeedPackVisualsBase.lua" "$OUT/EclipsePackArtBase.lua" >/dev/null
bundle(){ # $1 = the VerityPackArt source to test
 python3 "$HERE/../../R147/tests/mkbundle_verity.py" "$OUT/rs_bundle.luau" VerityPackArt="$1" SeedPackVisualsBase="$OUT/SeedPackVisualsBase.lua" SeedPackRendererBase="$OUT/SeedPackRendererBase.lua" \
  EclipsePackArtBase="$OUT/EclipsePackArtBase.lua" VoidPackFxBase="$OUT/VoidPackFxBase.lua" VerityPackArtBase="$OUT/VerityPackArtBase.lua" \
  VeiledEventClient81="$C/VeiledEventClient81.client.lua" SeedPackRender="$C/SeedPackRender.client.lua" \
  PackOpeningFeedback="$C/PackOpeningFeedback.client.lua" SeedPackClient="$C/SeedPackClient.client.lua" GiantVisualSafety="$C/GiantVisualSafety.client.lua" >/dev/null
}
bundle "$REPO/src/ReplicatedStorage/VerityPackArt.lua"
cd "$OUT";echo "== test_verity_pack";timeout 600 /opt/luau/luau test_verity_pack.luau > test_verity_pack.log 2>&1 || { grep -v '^WARN' test_verity_pack.log | tail -60;exit 1; }
grep -v '^WARN' test_verity_pack.log
if [ "$2" = "--mutations" ]; then
 python3 - "$REPO/src/ReplicatedStorage/VerityPackArt.lua" "$OUT" "$OUT/VerityPackArtBase.lua" <<'PY'
import sys
src=open(sys.argv[1]).read();out=sys.argv[2]
def mutant(name,text,old=None,new=None):
    if old is not None:
        assert old in text,name;text=text.replace(old,new,1)
    open('%s/mut_%s.lua'%(out,name),'w').write(text)
mutant('r148',open(sys.argv[3]).read())
mutant('dark_seal',src,"p.Color=A.Yellow;p.Material=Enum.Material.SmoothPlastic;p.Reflectance=0\n end end","p.Color=Color3.fromRGB(214,190,0);p.Material=Enum.Material.SmoothPlastic;p.Reflectance=0\n end end")
mutant('floating_face',src,"add('VerityFace',V(S,S,D),CF(cx,cy,0),nil,true)","add('VerityFace',V(S,S,D*1.15),CF(cx,cy,0),nil,true)")
mutant('emitter',src," bag:SetAttribute('VerityPack',true)"," Instance.new('ParticleEmitter').Parent=root;bag:SetAttribute('VerityPack',true)")
mutant('tinted_decal',src,"d.Color3=Color3.new(1,1,1)","d.Color3=Color3.fromRGB(255,255,200)")
mutant('mesh',src,"  p.Parent=folder\n"," p.Parent=folder;if s.Picture then Instance.new('MeshPart').Parent=folder end\n")
PY
 for m in r148 dark_seal floating_face emitter tinted_decal mesh; do
  bundle "$OUT/mut_$m.lua"
  if timeout 600 /opt/luau/luau test_verity_pack.luau > "mut_$m.log" 2>&1; then echo "FAIL: mutant $m was NOT noticed";exit 1;else echo "ok: mutant $m noticed ($(grep -c '^FAIL' "mut_$m.log") failed checks)";fi
 done
fi
# R151: the Verity pack is the real chip-bag pouch in pure yellow when the server's runtime bake (VerityPouch151) succeeded; everything above runs with NO neutral
# template, i.e. it checks the R149 sachet, which is the fallback. The pouch path and its failure modes have their own suite.
echo "== R151: the real pouch (VerityPouch151) and the sachet as the fallback";sh "$HERE/../../R151/tests/run_verity_pouch.sh" "$(pwd)/pouch" ${2:+"$2"}
