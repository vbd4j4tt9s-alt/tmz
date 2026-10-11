-- Runs HudLayout.Read over many viewports and reports overlapping HUD boxes.
local L=require(MODULE)
local function ov(a,b,pad)return a.X<b.X+b.W+pad and a.X+a.W>b.X-pad and a.Y<b.Y+b.H+pad and a.Y+a.H>b.Y-pad end
-- Approximate Roblox default touch controls (small screen: min side<=500).
local function controls(w,h)
 local small=math.min(w,h)<=500
 if small then return {Joystick={X=20,Y=h-90-20,W=90,H=90},Jump={X=w-95,Y=h-90,W=70,H=70}}end
 return {Joystick={X=60,Y=h-60-120,W=120,H=120},Jump={X=w-170,Y=h-210,W=120,H=120}}
end
local function boxes(m,w,h,touch)
 local b={}
 local shift=m.MenuShiftY or 0
 b[#b+1]={N='Hub',X=m.MenuX,Y=h/2+shift-m.MenuSize/2,W=m.MenuSize,H=m.MenuSize}
 for i,o in ipairs(m.MenuOffsets)do b[#b+1]={N='Opt'..i,X=m.MenuX+(m.MenuSize-m.MenuOptionSize)/2+o.X,Y=h/2+shift-m.MenuOptionSize/2+o.Y,W=m.MenuOptionSize,H=m.MenuOptionSize}end
 local bw=(m.Slots+1)*m.SlotSize+m.Slots*6
 local bar={N='Hotbar',X=w/2+(m.HotbarShiftX or 0)-bw/2,Y=h-m.HotbarBottom-m.SlotSize,W=bw,H=m.SlotSize};b[#b+1]=bar
 if m.HotbarDetails~=false then b[#b+1]={N='Details',X=bar.X,Y=bar.Y-44,W=bw,H=42,Soft=true}end
 for i,k in ipairs({'Speed','Cash','Gem'})do b[#b+1]={N='Wallet'..k,X=m[k..'X']or m.WalletX,Y=m[k..'Y'],W=m.WalletWidth,H=m.WalletHeight}end
 if m.PhoneWide then
  -- R129: landscape phones: corner status stack (above the jump button) and the jump button.
  b[#b+1]={N='Status',X=m.StatusBox.X,Y=m.StatusBox.Y,W=m.StatusBox.W,H=m.StatusBox.H}
  for _,z in ipairs(m.ThumbZones)do b[#b+1]={N='Jump',X=z.X,Y=z.Y,W=z.W,H=z.H,Zone=true}end
 elseif m.Phone then
  local sw=(m.StatusHorizontal and 388 or 190)*m.StatusScale;local sh=(m.StatusHorizontal and 39 or 82)*m.StatusScale
  b[#b+1]={N='Status',X=w-12-sw,Y=8,W=sw,H=sh}
  for i,z in ipairs(m.ThumbZones)do b[#b+1]={N=i==1 and'ThumbL'or'ThumbR',X=z.X,Y=z.Y,W=z.W,H=z.H,Zone=true}end
 else
  local sw=(m.StatusStacked and 190 or 337)*m.StatusScale;local sh=(m.StatusStacked and 211 or 125)*m.StatusScale
  b[#b+1]={N='Status',X=w-12-sw,Y=h-m.StatusBottom-sh,W=sw,H=sh}
  --owner tools metric is unused by any consumer
  b[#b+1]={N='OwnerTools',X=10,Y=8,W=48,H=48}
 end
 -- R113: BASE/TRACK pair. UnderWheel pairs hide while the wheel is open, so they may share space with options.
 local t=m.Travel
 if t then for i,n in ipairs({'TravelBase','TravelTrack'})do
  local k=i-1;b[#b+1]={N=n,X=t.X+(t.Horizontal and k*(t.Size+t.Gap)or 0),Y=t.Y+(t.Horizontal and 0 or k*(t.Size+t.Gap)),W=t.Size,H=t.Size,Under=t.UnderWheel,Travel=true}
 end end
 return b
end
local views={}
for _,v in ipairs({{1920,1080},{1366,768},{1280,720},{1024,768},{800,600},{1280,540},{960,480},{700,400}})do views[#views+1]={v[1],v[2],false}end
for _,v in ipairs({{568,320},{667,375},{740,360},{812,375},{844,390},{896,414},{932,430},{800,360},{1024,768},{1180,820},{1366,1024},{320,568},{375,667},{390,844},{430,932},{360,740},{768,1024},{820,1180}})do views[#views+1]={v[1],v[2],true}end
local total=0;local sizes={}
for _,v in ipairs(views)do
 local w,h,touch=v[1],v[2],v[3]
 for _,ctl in ipairs(touch and{false,true}or{false})do
  local m=L.Read({X=w,Y=h},touch,ctl and controls(w,h)or nil)
  local b=boxes(m,w,h,touch);local problems={}
  for i=1,#b do local a=b[i]
   if a.X<-0.5 or a.Y<-0.5 or a.X+a.W>w+.5 or a.Y+a.H>h+.5 then problems[#problems+1]=a.N..' offscreen' end
   for j=i+1,#b do local c=b[j]
    local wheel=(a.Under and c.N:sub(1,3)=='Opt')or(c.Under and a.N:sub(1,3)=='Opt')
    if not(a.Zone and c.Zone)and not wheel and(not(a.Soft or c.Soft)or a.Travel or c.Travel)and ov(a,c,(a.Travel or c.Travel)and 4 or 0)then
     -- Thumb zones only matter for real controls; details row is soft (hidden automatically if flagged).
     problems[#problems+1]=a.N..'x'..c.N
    end
   end
  end
  if not m.Travel then problems[#problems+1]='no travel spot' elseif m.Travel.Size<44 then problems[#problems+1]='travel too small' end
  total+=#problems
  print(string.format('%s %4dx%-4d %s hub=%d opt=%d slot=%d slots=%d wallet=%dx%d tp=%s | %s',touch and'TOUCH'or'PC   ',w,h,ctl and'ctl'or'   ',m.MenuSize,m.MenuOptionSize,m.SlotSize,m.Slots,m.WalletWidth,m.WalletHeight,m.Travel and string.format('%d,%d %d%s',m.Travel.X,m.Travel.Y,m.Travel.Size,m.Travel.UnderWheel and'W'or'')or'-',#problems==0 and'ok'or table.concat(problems,', ')))
 end
end
print('TOTAL OVERLAPS',total)
