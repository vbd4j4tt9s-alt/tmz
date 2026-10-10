#!/bin/sh
# Tutorial previews: sh run.sh <scratch dir> -> docs/proposals/R138/tutorial_*.png. The REAL BeginnerTutorial (committed
# = before, working copy = after) on the tools/tests mock, drawn with Pillow (DejaVu stands in for FredokaOne, Noto Color
# Emoji for emoji). Approximate: no 3D world (the red arrow trail and the goal marker are not drawn), no real font metrics.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};DOCS=$HERE/..
T=$REPO/tools/tests
for which in before after;do
 mkdir -p "$S/$which";cp "$T/roblox.luau" "$HERE/dump_gui.luau" "$S/$which/"
 if [ $which = before ];then
  git -C "$REPO" show HEAD:src/StarterPlayer/StarterPlayerScripts/BeginnerTutorial.client.lua > "$S/before/BT.lua"
  git -C "$REPO" show HEAD:src/ReplicatedStorage/BeginnerGuide.lua > "$S/before/BG.lua"
 else
  cp "$REPO/src/StarterPlayer/StarterPlayerScripts/BeginnerTutorial.client.lua" "$S/after/BT.lua";cp "$REPO/src/ReplicatedStorage/BeginnerGuide.lua" "$S/after/BG.lua"
 fi
 python3 "$T/bundle.py" "$S/$which/tut_bundle.luau" BeginnerTutorial="$S/$which/BT.lua" BeginnerGuide="$S/$which/BG.lua" HudLayout="$REPO/src/ReplicatedStorage/HudLayout.lua" >/dev/null
 (sed -n '1,/^-- Run ---/p' "$T/test_tutorial.luau" | sed '$d';cat "$HERE/tutorial_tail.luau") > "$S/$which/preview.luau"
 (cd "$S/$which" && /opt/luau/luau preview.luau > out.log 2>&1 || { tail -20 out.log;exit 1; })
 grep '^JSON ' "$S/$which/out.log" | while read -r _ name json;do echo "$json" > "$S/$which/$name.json";python3 "$HERE/render_gui138.py" "$S/$which/$name.json" "$S/$which/$name.png" 1 74,128,86 >/dev/null;done
done
python3 - "$S" "$DOCS" <<'PY'
import sys,os
from PIL import Image,ImageDraw,ImageFont
S,D=sys.argv[1],sys.argv[2];f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',22)
def crop(which,name,box):
    p=os.path.join(S,which,name+'.png')
    return Image.open(p).convert('RGB').crop(box) if os.path.exists(p) else None
def sheet(rows,out):
    W=max(sum(i.width for _,i in r)+20*(len(r)+1) for r in rows);H=sum(max(i.height for _,i in r)+60 for r in rows)+10
    im=Image.new('RGB',(W,H),(14,18,30));d=ImageDraw.Draw(im);y=10
    for r in rows:
        x=20
        for label,i in r:d.text((x,y),label,font=f,fill=(230,236,240));im.paste(i,(x,y+34));x+=i.width+20
        y+=max(i.height for _,i in r)+60
    im.save(out);print('wrote',out)
top=(300,0,980,250)
sheet([[('NOW: welcome',crop('before','welcome',(330,0,950,430))),('R138: welcome',crop('after','welcome',(330,0,950,430)))]],D+'/tutorial_welcome.png')
sheet([[('NOW: step 1',crop('before','step1',top)),('R138: step 1',crop('after','step1',top))],
       [('R138: step 2',crop('after','step2',top)),('R138: step 3',crop('after','step3',top))],
       [('R138: step 4',crop('after','step4',top)),('R138: slide',crop('after','slide1',top))]],D+'/tutorial_steps.png')
sheet([[('R138: open the pack (keep clicking)',crop('after','click',(0,0,1280,720)))],[('R138: done',crop('after','finish',(160,0,1120,520)))]],D+'/tutorial_click_finish.png')
PY
