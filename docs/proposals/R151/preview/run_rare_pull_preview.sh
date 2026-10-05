#!/bin/sh
# Usage: sh run_rare_pull_preview.sh <scratch dir> [node_modules dir with three@0.169.0 and the @fontsource fonts below]
# R151 previews -> docs/proposals/R151/rare_pull.png (a frame strip per tier: the suspense, the reveal, the seed ending; Common..Mythic on
# desktop, Secret / Cosmic / King on desktop AND phone) and docs/proposals/R151/rare_pull_king.gif (the King scene every 0.2 s).
#  1. preview_frames.luau plays the REAL reveals on the Roblox mock (the R151 test environment: real RarePull* modules, PackOpeningFeedback,
#     SeedPackClient) and prints every chosen moment as a FRAME line: parts / emitters / lights / soft glows / beams, the camera, the colour
#     grade and blur on the camera, the GUI trees (R150 dump_tree format) and the seed card's viewport.
#  2. render_frames.mjs draws the world / hidden stage with three.js (rare_pull.html; headless Chromium via playwright, swiftshader) and the
#     seed card's viewport; R150's render_gui.mjs draws the GUI overlays (patched here only to load the tier fonts: Sarpanch for SECRET,
#     Michroma for COSMIC, Grenze Gotisch for KING, Fredoka One / Luckiest Guy for the lower tiers; Montserrat stands in for Gotham).
#  3. compose.py applies the grade / blur, pastes the viewport and the overlays, and lays out the strips (Pillow) and the GIF.
# Needs /opt/luau, python3 + Pillow, node + playwright (global; PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and three.js + the fonts (npm).
# Approximate: plain materials (no Roblox textures or Future lighting), the pack art is a stand-in pouch in its paper colour (the approved
# meshes are not available offline), a blocky stand-in avatar and a grass plane for the world frames, particles as dots, no trails,
# the post effects approximated in Pillow.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};NM=$2
T=$REPO/docs/proposals/R151/tests;P=$REPO/docs/proposals
mkdir -p "$S/cl" "$S/strips" "$S/gif"
cp "$REPO/tools/tests/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/inventory_R113/tests/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$T/rare_env.luau" \
 "$P/R150/preview/dump_tree.luau" "$HERE/preview_frames.luau" "$S/cl/"
python3 "$T/mkbundle.py" "$S/cl" all-client >/dev/null
cd "$S/cl"
printf "SET='strips'\n" > strips.luau;cat preview_frames.luau >> strips.luau
printf "SET='gif'\n" > gif.luau;cat preview_frames.luau >> gif.luau
timeout 1200 /opt/luau/luau strips.luau > frames_strips.txt 2> strips.err || { tail -20 strips.err;exit 1; }
timeout 1200 /opt/luau/luau gif.luau > frames_gif.txt 2> gif.err || { tail -20 gif.err;exit 1; }
echo "frames: $(grep -c '^FRAME' frames_strips.txt) strip frames, $(grep -c '^FRAME' frames_gif.txt) gif frames"
cd "$S"
if [ -n "$NM" ];then [ -e "$S/node_modules" ] || ln -s "$NM" "$S/node_modules"
else [ -d "$S/node_modules/three" ] || npm install --prefix "$S" three@0.169.0 @fontsource/montserrat @fontsource/sarpanch @fontsource/michroma @fontsource/grenze-gotisch @fontsource/fredoka-one @fontsource/luckiest-guy >/dev/null;fi
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright" 2>/dev/null || true
cp "$HERE/rare_pull.html" "$HERE/render_frames.mjs" "$S/"
# R150's GUI renderer, with the tier fonts added (the R150 file itself is not changed)
python3 - "$P/R150/preview/render_gui.mjs" "$S/render_gui_fonts.mjs" "$S/node_modules/@fontsource" <<'PY'
import sys,os
src,dst,fs=sys.argv[1:4]
s=open(src).read()
fams={'Sarpanch':('sarpanch','Sarpanch',700),'Michroma':('michroma','Michroma',400),'GrenzeGotisch':('grenze-gotisch','Grenze Gotisch',800),
 'FredokaOne':('fredoka-one','Fredoka One',400),'LuckiestGuy':('luckiest-guy','Luckiest Guy',400)}
css=''
for k,(pkg,fam,w) in fams.items():
  f=os.path.join(fs,pkg,'files','%s-latin-%d-normal.woff2'%(pkg,w))
  if os.path.exists(f):css+="@font-face{font-family:'%s';src:url('file://%s') format('woff2');}\\n"%(fam,f)
old="const PAGE = (scene) => `<!doctype html><html><head><meta charset=\"utf-8\"><style>\n${fontCss()}"
assert old in s
s=s.replace(old,"const EXTRA_FONTS = \""+css+"\";\n"+old+"${EXTRA_FONTS}")
old="const font=t.font==='GothamBlack'?900:t.font==='GothamBold'?700:400;"
assert old in s
fam="{"+",".join("%s:\"'%s'\""%(k,v[1]) for k,v in fams.items())+"}"
s=s.replace(old,"const FAM="+fam+";const font=t.font==='GothamBlack'?900:t.font==='GothamBold'?700:FAM[t.font]?700:400;if(FAM[t.font])box.style.fontFamily=FAM[t.font]+\",'RbxFont',sans-serif\";")
# text with a UIGradient: Roblox colours the text with it (render_gui.mjs only paints backgrounds)
old="if(t.rich) span.innerHTML=richHtml(t.s); else span.textContent=t.s;"
assert old in s
s=s.replace(old,old+"if(n.grad){span.style.backgroundImage=gradientCss(n.grad,t.color,0);span.style.webkitBackgroundClip='text';span.style.backgroundClip='text';span.style.color='transparent';span.style.display='inline-block';span.style.opacity=String(1-t.alpha);}")
open(dst,'w').write(s)
PY
export PLAYWRIGHT_NODE_ROOT=$(npm root -g);export PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}
for set in strips gif;do
 node "$S/render_frames.mjs" "$S" "$S/cl/frames_$set.txt" "$S/$set" >/dev/null
 node "$S/render_gui_fonts.mjs" "$S/$set/gui_scenes.json" "$S/$set" "$S/node_modules/@fontsource/montserrat/files" >/dev/null
done
python3 "$HERE/compose.py" "$S/strips" "$REPO/docs/proposals/R151/rare_pull.png" strips
python3 "$HERE/compose.py" "$S/gif" "$REPO/docs/proposals/R151/rare_pull_king.gif" gif
