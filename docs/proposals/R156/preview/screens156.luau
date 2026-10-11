--!nocheck
-- R156 preview data (not a test): the bars' place on the 36 screens R155's test uses, R155 as it is (MODE 'current') and the proposal (MODE 'fresh'): the gap to the slots, whether a clear
-- spot was found, and whether the item's name / traits rows (which sit ABOVE the bars in the proposal, so they are taller) run into another HUD box (HudLayout's own test for hiding
-- them: its boxes + 4 px). Prints SCREEN lines; run_pity_v2_preview156.sh collects them into SCRATCH/screens.log.
local W=require('./world');local R=W.R
local V2=R.Vector2.new
local B=W.module('PityBars155');local Hud=W.module('HudLayout')
local NEW=MODE~='current'
local SCREENS={
 {1920,1080,false,'PC 1080p'},{2560,1440,false,'PC 1440p'},{1366,768,false,'laptop'},{1280,720,false,'PC 720p'},{1024,768,false,'small window'},{800,600,false,'tiny window'},{1600,900,false,'PC 900p'},
 {844,390,true,'iPhone 14 landscape'},{932,430,true,'iPhone Pro Max landscape'},{667,375,true,'iPhone 8 landscape'},{568,320,true,'iPhone SE landscape'},{740,360,true,'Android landscape'},{800,360,true,'Android wide'},{896,414,true,'iPhone 11 landscape'},
 {390,844,true,'iPhone 14 portrait'},{375,667,true,'iPhone 8 portrait'},{360,640,true,'Android portrait'},{414,896,true,'iPhone 11 portrait'},{320,568,true,'iPhone SE portrait'},{360,800,true,'Android tall'},
 {1024,768,true,'iPad landscape'},{768,1024,true,'iPad portrait'},{1180,820,true,'iPad Air landscape'},{820,1180,true,'iPad Air portrait'},{1366,1024,true,'iPad Pro landscape'},
 {1280,800,true,'Android tablet'},{800,1280,true,'Android tablet portrait'},{1920,1080,true,'touch PC'},{1440,900,false,'MacBook'},{1280,1024,false,'5:4 monitor'},
 {1280,540,false,'short PC window'},{960,480,false,'narrow short window'},{700,400,false,'tiny landscape window'},{812,375,true,'iPhone X landscape'},{430,932,true,'iPhone Pro Max portrait'},{360,740,true,'Android portrait 740'},
}
local function overlaps(a,b,pad)pad=pad or 0;return a.X<b.X+b.W+pad and a.X+a.W>b.X-pad and a.Y<b.Y+b.H+pad and a.Y+a.H>b.Y-pad end
for _,sc in ipairs(SCREENS)do
 local w,h,touch,name=sc[1],sc[2],sc[3],sc[4]
 W.UIS.TouchEnabled=touch;W.UIS.KeyboardEnabled=not touch
 local m=Hud.Read(V2(w,h),touch,nil)
 local dock=B.DefaultDock(m,w,h)
 local place=B.Place(w,h,m,dock);local pair=place.Pair
 local details=m.HotbarDetails~=false
 local row=NEW and B.NameRow(w,h,m,dock)or 2
 local band={X=dock.X,Y=dock.Y-row-42,W=dock.W,H=42}
 -- (the rows' label box is as wide as the hotbar, but its text is centred and short: "text" = the middle 240 px, a long name like "Limited Mech Pack (12.34 kg)" at 14 px)
 local text={X=dock.X+dock.W/2-120,Y=band.Y,W=240,H=42}
 local hit,hitText={},{}
 if details then
  for _,b in ipairs(Hud.HudBoxes(m,w,h,false))do
   if b.N~='Hotbar'and overlaps(band,b,4)then hit[#hit+1]=b.N end
   if b.N~='Hotbar'and overlaps(text,b,4)then hitText[#hitText+1]=b.N end
  end
  if m.Travel then
   local t={X=m.Travel.X,Y=m.Travel.Y,W=m.Travel.W,H=m.Travel.H}
   if overlaps(band,t,4)then hit[#hit+1]='BASE/TRACK'end
   if overlaps(text,t,4)then hitText[#hitText+1]='BASE/TRACK'end
  end
 end
 print(('SCREEN %s|%s|%dx%d%s|bars %dx%d%s|clear=%s|gap %d|rows %s|hit %s|text %s'):format(MODE,name,w,h,touch and' touch'or'',place.Bar.W,place.Bar.H,place.Stacked and' stacked'or'',tostring(place.Clear),
  dock.Y-(pair.Y+pair.H),details and'shown'or'hidden',#hit>0 and table.concat(hit,',')or'-',#hitText>0 and table.concat(hitText,',')or'-'))
end
