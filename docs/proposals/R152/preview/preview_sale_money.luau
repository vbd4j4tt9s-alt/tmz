--!nocheck
-- R152 preview data: plays the REAL SaleMoneyEffects + GardenWallet + HudLayout on the Roblox mock for one sale (8 cash coins and 4 gem coins) in three layouts and prints one
-- FRAME line per sampled frame: `FRAME <layout> <t> <json>` with the screen size, the three counters' boxes, the balances (ticking up as claims land, a 0.12 s round trip is
-- simulated), each counter's bump (0..1), every coin (x, y, size, rotation, currency) and the sale total. render_sale_money.mjs draws them.
-- Run from a folder holding roblox.luau, world.luau, fixtures.luau, sfx_env.luau and rs_bundle.luau (run_sale_money_preview.sh).
local W=require('./world');local F=require('./fixtures');local E=require('./sfx_env')(W);local R=W.R
local V2=R.Vector2.new
F.packAssets(W);W.env.bit32=bit32
getmetatable(R.Vector2.new(0,0)).__mul=function(a,b)return R.Vector2.new(a.X*b,a.Y*b)end
E.recorder();W.stub('LocalSfx',{Play=function()return true end,Preload=function()end,WhooshId='rbxassetid://9120768742'})
E.player('Tester');local pg=E.pg
local Effects=W.module('SaleMoneyEffects');local Wallet=W.module('GardenWallet');local Rules=W.module('SaleReceiptRules')
local function num(x)return string.format('%.1f',x)end
local function layout(name,size,touch,fps)
 W.UIS.TouchEnabled=touch;pg:SetAttribute('SeedMenu',nil)
 local screen=R.Instance.new('ScreenGui');screen.Name='Host_'..name;screen.Parent=pg;screen.AbsoluteSize=size
 local wallet=Wallet.new(screen)
 local boxes={}
 for key,row in pairs({Speed=wallet.Speed,Cash=wallet,Gems=wallet.Gems})do
  local rp,rs,ip,isz=row.Root.Position,row.Root.Size,row.Icon.Position,row.Icon.Size
  row.Icon._props.AbsolutePosition=V2(rp.X.Offset+ip.X.Offset,rp.Y.Offset+ip.Y.Offset);row.Icon._props.AbsoluteSize=V2(isz.X.Offset,isz.Y.Offset)
  boxes[key]={x=rp.X.Offset,y=rp.Y.Offset,w=rs.X.Offset,h=rs.Y.Offset,ix=ip.X.Offset,iy=ip.Y.Offset,iw=isz.X.Offset,ih=isz.Y.Offset}
 end
 local bal={Cash=0,Gems=0};local lastPulse={Cash=-9,Gems=-9}
 local pulseOf=wallet.Pulse;local gemPulse=wallet.Gems.Pulse
 wallet.Pulse=function(self)lastPulse.Cash=R.clock;return pulseOf(self)end;wallet.Gems.Pulse=function(self)lastPulse.Gems=R.clock;return gemPulse(self)end
 local fx=Effects.new(screen,wallet,function(id,index)
  local kind=id:sub(1,1)=='g'and'Gems'or'Cash'
  local amount=Rules.Share(kind=='Gems'and{Amount=40,Count=4}or{Amount=1000,Count=8},index)
  R.task.delay(.12,function()bal[kind]+=amount;if kind=='Gems'then wallet.Gems:SetValue(bal.Gems)else wallet:SetValue(bal.Cash)end end)
  return {Success=true}
 end)
 fx.Layer.AbsoluteSize=size;fx.Layer.AbsolutePosition=V2(0,0)
 local t0=R.clock
 fx:Sync({{Id='cash1',Amount=1000,Count=8,Claimed=0,Currency='Cash'},{Id='gem1',Amount=40,Count=4,Claimed=0,Currency='Gems'}},V2(size.X*.5,size.Y*.62))
 local dt=1/fps;local frames=math.floor(2.4*fps)
 for i=0,frames do
  local t=R.clock-t0
  local coins={}
  for _,it in ipairs(fx.Icons)do coins[#coins+1]=string.format('{"x":%s,"y":%s,"s":%s,"r":%s,"c":"%s"}',num(it.Position.X),num(it.Position.Y),num(it.Frame.Size.X.Offset),num(it.Frame.Rotation),it.Currency)end
  local labels={}
  for _,rc in ipairs(fx.Receipts)do labels[#labels+1]=string.format('{"x":%s,"y":%s,"t":"%s","a":%s}',num(rc.Label.Position.X.Offset),num(rc.Label.Position.Y.Offset),rc.Label.Text,num(1-rc.Label.TextTransparency))end
  local function bump(k)return num(math.max(0,1-(R.clock-lastPulse[k])/.18))end
  print(string.format('FRAME %s %s {"w":%d,"h":%d,"boxes":{"Speed":%s,"Cash":%s,"Gems":%s},"cash":"%s","gems":"%s","bumpCash":%s,"bumpGems":%s,"coins":[%s],"labels":[%s]}',name,num(t),size.X,size.Y,
   '{"x":'..boxes.Speed.x..',"y":'..boxes.Speed.y..',"w":'..boxes.Speed.w..',"h":'..boxes.Speed.h..',"ix":'..boxes.Speed.ix..',"iy":'..boxes.Speed.iy..',"iw":'..boxes.Speed.iw..',"ih":'..boxes.Speed.ih..'}',
   '{"x":'..boxes.Cash.x..',"y":'..boxes.Cash.y..',"w":'..boxes.Cash.w..',"h":'..boxes.Cash.h..',"ix":'..boxes.Cash.ix..',"iy":'..boxes.Cash.iy..',"iw":'..boxes.Cash.iw..',"ih":'..boxes.Cash.ih..'}',
   '{"x":'..boxes.Gems.x..',"y":'..boxes.Gems.y..',"w":'..boxes.Gems.w..',"h":'..boxes.Gems.h..',"ix":'..boxes.Gems.ix..',"iy":'..boxes.Gems.iy..',"iw":'..boxes.Gems.iw..',"ih":'..boxes.Gems.ih..'}',
   wallet.Amount.Text,wallet.Gems.Amount.Text,bump('Cash'),bump('Gems'),table.concat(coins,','),table.concat(labels,',')))
  W.frames(1,dt)
 end
 fx:Destroy();screen:Destroy()
end
layout('desktop',V2(1280,720),false,30)
layout('phone_landscape',V2(844,390),true,30)
layout('phone_portrait',V2(390,844),true,30)
