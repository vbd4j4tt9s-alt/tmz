--!nocheck
-- Category card placement on many screens: outside the sheet, on screen, >=44 px, clear of every HUD box.
local W=require('./world');local F=require('./fixtures');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end end
F.packAssets(W)
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local bag=R.new('Backpack');bag.Name='Backpack';bag.Parent=player
local char=R.new('Model');char.Parent=W.workspace;player.Character=char
local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char;player.CharacterAdded=R.signal()
F.shovel(W,bag);F.pack(W,bag,1,'Pack01',1,'None')
W.load('Hotbar',R.new('LocalScript'))
local L=W.module('HudLayout');local gui=pg.ChestToolHotbar;local panel=gui.Inventory;local camera=W.workspace.CurrentCamera
W.UIS.InputBegan:Fire({KeyCode=R.Enum.KeyCode.B,UserInputType=R.Enum.UserInputType.Keyboard},false);W.frames(2)
local function ov(a,b,pad)return a.X<b.X+b.W+pad and a.X+a.W>b.X-pad and a.Y<b.Y+b.H+pad and a.Y+a.H>b.Y-pad end
local function controls(w,h)
 local small=math.min(w,h)<=500
 if small then return {Joystick={X=20,Y=h-90-20,W=90,H=90},Jump={X=w-95,Y=h-90,W=70,H=70}}end
 return {Joystick={X=60,Y=h-60-120,W=120,H=120},Jump={X=w-170,Y=h-210,W=120,H=120}}
end
-- Independent HUD box list (mirrors tools/tests/hud_overlap_harness.luau), incl. travel pair and owner tile.
local function boxes(m,w,h)
 local b={};local shift=m.MenuShiftY or 0
 b[#b+1]={N='Hub',X=m.MenuX,Y=h/2+shift-m.MenuSize/2,W=m.MenuSize,H=m.MenuSize}
 local bw=(m.Slots+1)*m.SlotSize+m.Slots*6
 b[#b+1]={N='Hotbar',X=w/2+(m.HotbarShiftX or 0)-bw/2,Y=h-m.HotbarBottom-m.SlotSize,W=bw,H=m.SlotSize}
 for _,k in ipairs({'Speed','Cash','Gem'})do b[#b+1]={N='Wallet'..k,X=m[k..'X']or m.WalletX,Y=m[k..'Y'],W=m.WalletWidth,H=m.WalletHeight}end
 if m.Phone then
  local sw=(m.StatusHorizontal and 388 or 190)*m.StatusScale;local sh=(m.StatusHorizontal and 39 or 82)*m.StatusScale
  b[#b+1]={N='Status',X=w-12-sw,Y=8,W=sw,H=sh}
  for i,z in ipairs(m.ThumbZones)do b[#b+1]={N=i==1 and'ThumbL'or'ThumbR',X=z.X,Y=z.Y,W=z.W,H=z.H}end
 else
  local sw=(m.StatusStacked and 190 or 337)*m.StatusScale;local sh=(m.StatusStacked and 211 or 125)*m.StatusScale
  b[#b+1]={N='Status',X=w-12-sw,Y=h-m.StatusBottom-sh,W=sw,H=sh};b[#b+1]={N='OwnerTools',X=10,Y=8,W=48,H=48}
 end
 if m.Travel then b[#b+1]={N='Travel',X=m.Travel.X,Y=m.Travel.Y,W=m.Travel.W,H=m.Travel.H}end
 return b
end
local views={}
for _,v in ipairs({{1920,1080},{1366,768},{1280,720},{1024,768},{800,600},{1280,540},{960,480},{700,400}})do views[#views+1]={v[1],v[2],false}end
for _,v in ipairs({{568,320},{667,375},{740,360},{812,375},{844,390},{896,414},{932,430},{800,360},{1024,768},{1180,820},{1366,1024},{320,568},{375,667},{390,844},{430,932},{360,740},{768,1024},{820,1180}})do views[#views+1]={v[1],v[2],true}end
local rows={}
for _,v in ipairs(views)do
 local w,h,touch=v[1],v[2],v[3]
 for _,ctl in ipairs(touch and{false,true}or{false})do
  W.UIS.TouchEnabled=touch
  L.Controls=function()return ctl and controls(w,h)or nil end
  gui.AbsoluteSize=R.Vector2.new(w,h);camera.ViewportSize=R.Vector2.new(w,h);W.frames(1)
  local m=L.Read({X=w,Y=h},touch,ctl and controls(w,h)or nil)
  local ps,pp=panel.Size,panel.Position
  local sheet={X=pp.X.Offset-ps.X.Offset/2,Y=pp.Y.Offset-ps.Y.Offset/2,W=ps.X.Offset,H=ps.Y.Offset}
  local f=panel.Categories;local fx,fy=sheet.X+f.Position.X.Offset,sheet.Y+f.Position.Y.Offset
  local mode=f.Position.X.Offset<0 and(f.Size.X.Offset>f.Size.Y.Offset*.8 and'left2x2'or'left')or'row'
  local problems={};local tab
  for _,name in ipairs({'All','Seeds','Fruit','Tools'})do
   local b=f[name];tab=b.Size.X.Offset
   local r={N=name,X=fx+b.Position.X.Offset,Y=fy+b.Position.Y.Offset,W=b.Size.X.Offset,H=b.Size.Y.Offset}
   if ov(r,sheet,0)then problems[#problems+1]=name..' inside sheet'end
   if r.X<0 or r.Y<0 or r.X+r.W>w or r.Y+r.H>h then problems[#problems+1]=name..' offscreen'end
   if r.W<44 then problems[#problems+1]=name..' <44px'end
   for _,x in ipairs(boxes(m,w,h))do if ov(r,x,0)then problems[#problems+1]=name..'x'..x.N end end
  end
  for _,x in ipairs(boxes(m,w,h))do if x.N=='Hotbar'and ov(sheet,x,0)then problems[#problems+1]='sheet over hotbar'end end
  local grid=panel.Items;local gw=sheet.W+grid.Size.X.Offset;local gh=sheet.H+grid.Size.Y.Offset
  if gw<84 or gh<72 then problems[#problems+1]='grid too small '..gw..'x'..gh end
  check(#problems==0,string.format('%dx%d %s %s',w,h,touch and'touch'or'pc',ctl and'ctl'or''))
  rows[#rows+1]=string.format('%s %4dx%-4d %s %-6s tab=%2d sheet=%4dx%-3d grid=%4dx%-3d | %s',touch and'TOUCH'or'PC   ',w,h,ctl and'ctl'or'   ',mode,tab,sheet.W,sheet.H,gw,gh,#problems==0 and'ok'or table.concat(problems,', '))
 end
end
for _,r in ipairs(rows)do print(r)end
print(('%d checks, %d failures'):format(checks,fails))
