#!/bin/sh
# R140 previews: sh run.sh <scratch dir> -> docs/proposals/R140/daily_*.png. The REAL TravelButtons + DailyRewardsClient
# on the mock (setup from ../tests/test_daily_client.luau), drawn with the R138 renderer (DejaVu for FredokaOne, Noto
# Color Emoji). Approximate: no real font metrics; the 3D Mech pack and the gem art show as 🤖 / 💎 here.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};DOCS=$HERE/..
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests;C=$REPO/src/StarterPlayer/StarterPlayerScripts;P=$REPO/docs/proposals/R138/preview
mkdir -p "$S";cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/dump_gui.luau" "$S/"
python3 "$INV/mkbundle.py" "$S/rs_bundle.luau" TravelButtons="$C/TravelButtons.client.lua" DailyRewardsClient="$C/DailyRewardsClient.client.lua" >/dev/null
# Setup = the client test up to its first check block, with the picture modules stubbed to their emoji stand-ins.
(sed -n '1,/^-- 1\. The top bar row/p' "$HERE/../tests/test_daily_client.luau" | sed '$d' \
  | sed "s|^local tb=R.new('LocalScript')|W.stub('GemIcon',{new=function()error('preview')end});W.module('ItemPictures').Show=function()error('preview')end\nlocal tb=R.new('LocalScript')|";cat "$HERE/tail.luau") > "$S/preview.luau"
(cd "$S" && /opt/luau/luau preview.luau > out.log 2>&1 || { tail -20 out.log;exit 1; })
grep '^JSON ' "$S/out.log" | while read -r _ name json;do echo "$json" > "$S/$name.json";python3 "$P/render_gui138.py" "$S/$name.json" "$S/$name.png" 1 74,128,86 >/dev/null;done
python3 - "$S" "$DOCS" <<'PY'
import sys,os
from PIL import Image,ImageDraw,ImageFont
S,D=sys.argv[1],sys.argv[2];f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',22)
def crop(name,box=None):
    im=Image.open(os.path.join(S,name+'.png')).convert('RGB');return im.crop(box) if box else im
def sheet(rows,out):
    W=max(sum(i.width for _,i in r)+20*(len(r)+1) for r in rows);H=sum(max(i.height for _,i in r)+60 for r in rows)+10
    im=Image.new('RGB',(W,H),(14,18,30));d=ImageDraw.Draw(im);y=10
    for r in rows:
        x=20
        for label,i in r:d.text((x,y),label,font=f,fill=(230,236,240));im.paste(i,(x,y+34));x+=i.width+20
        y+=max(i.height for _,i in r)+60
    im.save(out);print('wrote',out)
sheet([[('Computer: top bar (badge 2, 2 friends here)',crop('top_desktop',(280,0,1000,70)))],[('Phone: top bar',crop('top_phone',(0,0,390,70)))]],D+'/daily_topbar.png')
sheet([[('LOGIN (days 1-2 claimed, day 3 today)',crop('login_desktop',(150,40,1130,680)))],[('Day 7: the Mech pack',crop('login_day7',(150,40,1130,680)))]],D+'/daily_login.png')
sheet([[('QUESTS',crop('quests_desktop',(150,40,1130,680)))]],D+'/daily_quests.png')
sheet([[('Phone: LOGIN',crop('login_phone')),('Phone: QUESTS',crop('quests_phone'))],[('Phone landscape: LOGIN',crop('login_landscape'))]],D+'/daily_phone.png')
PY
