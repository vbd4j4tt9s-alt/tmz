#!/bin/sh
# Usage: sh run_seed_opening_preview.sh <scratch dir> [node_modules dir with three@0.169.0 and the @fontsource fonts below] [sets]
# R152 previews (docs/proposals/R152/seed_opening.md):
#   seed_opening.png         every tier: the suspense, the reveal, the seed (Common / Rare / Legendary / Mythic, Secret / Cosmic / King desktop,
#                            King phone, a Secret seen by others)
#   seed_opening_king.gif    the King scene every 0.1 s (smoothness)
#   seed_opening_planets.png the Cosmic stage and its planets close up
#   seed_opening_beam.png    the sky beam: coming down, landing, impact, holding, thinning (wide and close), Secret / Cosmic / King; the
#                            King's gold beams; a Mythic flourish's smaller beam
#   seed_opening_assets.png  before (the R151 tree, 24ed94b) / after for the main assets
#  1. dump_art.luau draws every RarePullArt image with the real pattern code; art_to_png.py writes the PNGs the renderer uses.
#  2. preview_frames152.luau plays the REAL reveals on the Roblox mock (this checkout; and the R151 tree for the before frames) and prints
#     every chosen moment as a FRAME line.
#  3. render_frames152.mjs draws them with three.js (seed_opening.html; headless Chromium via playwright, swiftshader); R150's
#     render_gui.mjs (patched here only: the tier fonts, text gradients and the client-drawn images) draws the GUI.
#  4. compose152.py composes the layers and lays out the sheets and the GIF.
# Needs /opt/luau, python3 + Pillow, node + playwright (global; PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and three.js + the fonts (npm).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};NM=$2;SETS=${3:-main king planets beam assets};BASE=${BASE:-24ed94b}
P=$REPO/docs/proposals;INV=$P/inventory_R113/tests;OUT=$P/R152
mkdir -p "$S/cl" "$S/art" "$S/before/tree" "$S/before/cl"
env_files() { cp "$REPO/tools/tests/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$P/R151/tests/rare_env.luau" \
 "$P/R150/preview/dump_tree.luau" "$HERE/dump_tree152.luau" "$HERE/preview_frames152.luau" "$HERE/dump_art.luau" "$1/"; }
env_files "$S/cl"
python3 "$P/R151/tests/mkbundle_rare.py" "$S/cl" all-client >/dev/null
# 1. the images
(cd "$S/cl" && timeout 600 /opt/luau/luau dump_art.luau > art.txt)
python3 "$HERE/art_to_png.py" "$S/cl/art.txt" "$S/art" "$S/art_sheet.png" >/dev/null
# 2. the frames
for set in $SETS;do
 (cd "$S/cl" && { printf "SET='%s'\n" "$set";cat preview_frames152.luau; } > "set_$set.luau" && timeout 1800 /opt/luau/luau "set_$set.luau" > "frames_$set.txt" 2> "set_$set.err") || { tail -20 "$S/cl/set_$set.err";exit 1; }
 echo "$set: $(grep -c '^FRAME' "$S/cl/frames_$set.txt") frames"
done
case " $SETS " in *" assets "*)
 (cd "$REPO" && git archive "$BASE" src docs/proposals/R151/tests/mkbundle_rare.py | tar -x -C "$S/before/tree")
 env_files "$S/before/cl"
 python3 "$S/before/tree/docs/proposals/R151/tests/mkbundle_rare.py" "$S/before/cl" all-client >/dev/null
 (cd "$S/before/cl" && { printf "SET='assets'\n";cat preview_frames152.luau; } > set_assets.luau && timeout 1800 /opt/luau/luau set_assets.luau > frames_before.txt 2> set_before.err) || { tail -20 "$S/before/cl/set_before.err";exit 1; }
 cp "$S/before/cl/frames_before.txt" "$S/cl/frames_before.txt";echo "before: $(grep -c '^FRAME' "$S/cl/frames_before.txt") frames";;
esac
# 3. render
cd "$S"
if [ -n "$NM" ];then [ -e "$S/node_modules" ] || ln -s "$NM" "$S/node_modules"
else [ -d "$S/node_modules/three" ] || npm install --prefix "$S" three@0.169.0 @fontsource/montserrat @fontsource/sarpanch @fontsource/michroma @fontsource/grenze-gotisch @fontsource/fredoka-one @fontsource/luckiest-guy >/dev/null;fi
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright" 2>/dev/null || true
cp "$HERE/seed_opening.html" "$HERE/render_frames152.mjs" "$S/"
# R150's GUI renderer with the tier fonts, text gradients and the client-drawn images (the R150 file itself is not changed)
python3 - "$P/R150/preview/render_gui.mjs" "$S/render_gui152.mjs" "$S/node_modules/@fontsource" "$S/art" <<'PY'
import sys,os
src,dst,fs,art=sys.argv[1:5]
s=open(src).read()
fams={'Sarpanch':('sarpanch','Sarpanch',700),'Michroma':('michroma','Michroma',400),'GrenzeGotisch':('grenze-gotisch','Grenze Gotisch',800),
 'FredokaOne':('fredoka-one','Fredoka One',400),'LuckiestGuy':('luckiest-guy','Luckiest Guy',400)}
css=''
for k,(pkg,fam,w) in fams.items():
  f=os.path.join(fs,pkg,'files','%s-latin-%d-normal.woff2'%(pkg,w))
  if os.path.exists(f):css+="@font-face{font-family:'%s';src:url('file://%s') format('woff2');}\\n"%(fam,f)
old="const PAGE = (scene) => `<!doctype html><html><head><meta charset=\"utf-8\"><style>\n${fontCss()}"
assert old in s
s=s.replace(old,"const EXTRA_FONTS = \""+css+"\";\nconst ARTDIR="+repr(art)+";\nconst ART={};for(const f of fs.existsSync(ARTDIR)?fs.readdirSync(ARTDIR):[])if(f.endsWith('.png'))ART[f.slice(0,-4)]='data:image/png;base64,'+fs.readFileSync(path.join(ARTDIR,f)).toString('base64');\n"
 +"const artFor=(scene)=>{const out={};const j=JSON.stringify(scene);for(const k of Object.keys(ART))if(j.includes('\"name\":\"'+k+'\"'))out[k]=ART[k];return out};\n"+old+"${EXTRA_FONTS}")
old="const SCENE=${JSON.stringify(scene)};"
assert old in s
s=s.replace(old,old+"const ARTIMG=${JSON.stringify(artFor(scene))};")
old="const font=t.font==='GothamBlack'?900:t.font==='GothamBold'?700:400;"
assert old in s
fam="{"+",".join("%s:\"'%s'\""%(k,v[1]) for k,v in fams.items())+"}"
s=s.replace(old,"const FAM="+fam+";const font=t.font==='GothamBlack'?900:t.font==='GothamBold'?700:FAM[t.font]?700:400;if(FAM[t.font])box.style.fontFamily=FAM[t.font]+\",'RbxFont',sans-serif\";")
old="if(t.rich) span.innerHTML=richHtml(t.s); else span.textContent=t.s;"
assert old in s
s=s.replace(old,old+"if(n.grad){span.style.backgroundImage=gradientCss(n.grad,t.color,0);span.style.webkitBackgroundClip='text';span.style.backgroundClip='text';span.style.color='transparent';span.style.display='inline-block';span.style.opacity=String(1-t.alpha);}")
# the client-drawn images: drawn as the frame's picture, tinted by ImageColor3 (a white image: as it is), faded by ImageTransparency
old="  parent.appendChild(el);\n"
assert old in s
s=s.replace(old,old+"  if(n.img&&ARTIMG[n.img.name]){const im=document.createElement('div');im.style.cssText='position:absolute;left:0;top:0;width:100%;height:100%;';const u='url('+ARTIMG[n.img.name]+')';const c=n.img.color;\n"
 +"   if(c[0]>=250&&c[1]>=250&&c[2]>=250){im.style.backgroundImage=u;im.style.backgroundSize='100% 100%'}else{im.style.backgroundColor=rgb(c,1);im.style.webkitMaskImage=u;im.style.webkitMaskSize='100% 100%';im.style.maskImage=u;im.style.maskSize='100% 100%'}\n"
 +"   im.style.opacity=String(1-n.img.a);el.appendChild(im)}\n",1)
open(dst,'w').write(s)
PY
export PLAYWRIGHT_NODE_ROOT=$(npm root -g);export PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}
for f in $SETS $(case " $SETS " in *" assets "*) echo before;;esac);do
 node "$S/render_frames152.mjs" "$S" "$S/cl/frames_$f.txt" "$S/out_$f" >/dev/null
 node "$S/render_gui152.mjs" "$S/out_$f/gui_scenes.json" "$S/out_$f" "$S/node_modules/@fontsource/montserrat/files" >/dev/null
 echo "rendered $f"
done
# 4. compose
for set in $SETS;do
 case $set in
  main) python3 "$HERE/compose152.py" "$S/out_main" "$OUT/seed_opening.png" strips 'R152 seed opening: the suspense, the reveal and the seed, Common to King (desktop 1280x720; King also phone 844x390; a Secret seen by others)';;
  king) python3 "$HERE/compose152.py" "$S/out_king" "$OUT/seed_opening_king.gif" gif;;
  planets) python3 "$HERE/compose152.py" "$S/out_planets" "$OUT/seed_opening_planets.png" grid 'R152 Cosmic: the deep-space stage and its textured planets (client-drawn images, real pattern code)';;
  beam) python3 "$HERE/compose152.py" "$S/out_beam" "$OUT/seed_opening_beam.png" strips "R152 sky beam: it slams down, lands on the burst, holds and thins out (wide and close, as others see it); the King's gold beams; a Mythic flourish";;
  assets) python3 "$HERE/compose152.py" "$S/out_assets" "$OUT/seed_opening_assets.png" pairs 'R152 assets: before (R151) and after, the same moment of the same reveal' "$S/out_before";;
 esac
done
