--!nocheck
-- R129 (owner reference): landscape phones keep the HUD on the edges. Real HudLayout + GardenWallet + WorldStatusHud.
local W=require('./world');local F=require('./fixtures');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local L=W.module('HudLayout')
local function ov(a,b)return a.X<b.X+b.W and a.X+a.W>b.X and a.Y<b.Y+b.H and a.Y+a.H>b.Y end
local function controls(w,h)
 local small=math.min(w,h)<=500
 if small then return {Joystick={X=20,Y=h-110,W=90,H=90},Jump={X=w-95,Y=h-90,W=70,H=70}}end
 return {Joystick={X=60,Y=h-180,W=120,H=120},Jump={X=w-170,Y=h-210,W=120,H=120}}
end
for _,v in ipairs({{568,320},{667,375},{740,360},{812,375},{844,390},{896,414},{932,430},{800,360},{1024,768},{1366,1024}})do
 local w,h=v[1],v[2];local c=controls(w,h);local m=L.Read({X=w,Y=h},true,c);local tag=w..'x'..h
 check(m.PhoneWide==true and m.Phone==true,tag..' landscape phone layout')
 check(m.MenuMode==nil and m.MenuSize>=52,tag..' one MENU button (wheel), not a stack')
 local bw=(m.Slots+1)*m.SlotSize+m.Slots*6;local bar={X=w/2-bw/2,Y=h-m.HotbarBottom-m.SlotSize,W=bw,H=m.SlotSize}
 check(m.HotbarShiftX==0,tag..' hotbar centred on the screen')
 check(m.Slots==5 and(w<600 or m.SlotSize>=56),tag..' 5 slots ('..m.SlotSize..' px)')
 local wallet={X=m.WalletX,Y=m.SpeedY,W=m.WalletWidth,H=m.GemY+m.WalletHeight-m.SpeedY}
 check(m.WalletX==10 and m.GemY+m.WalletHeight<=h-6+1e-6 and m.WalletPassive==true,tag..' balances in the bottom-left corner')
 check(not ov(wallet,bar),tag..' balances clear of the hotbar')
 local jz=m.ThumbZones[1]
 check(m.StatusBox.Y+m.StatusBox.H<=c.Jump.Y-8+1e-6 and m.StatusBox.X+m.StatusBox.W<=w-12+1e-6,tag..' timers bottom-right, above the jump button')
 check(not ov(m.StatusBox,bar)and not ov(m.StatusBox,jz),tag..' timers clear of the hotbar and the jump button')
 check(m.StatusBox.H>=(5*43-4)*m.StatusScale-1e-6,tag..' room for boosts + The Darkened + 2 timers in one stack')
 local hub={X=m.MenuX,Y=h/2+m.MenuShiftY-m.MenuSize/2,W=m.MenuSize,H=m.MenuSize}
 check(not ov(hub,wallet)and hub.Y>=0,tag..' MENU button left middle, above the balances')
 check(not ov(bar,jz),tag..' hotbar clear of the jump button')
end
-- Portrait phones and computers keep their layouts.
check(L.Read({X=390,Y=844},true,controls(390,844)).PhoneWide==nil,'portrait phones unchanged')
check(L.Read({X=1920,Y=1080},false,nil).PhoneWide==nil,'computers unchanged')
-- Real widgets on an 844x390 phone
local Players=W.service('Players');local player=R.new('Player');player.Name='P';player.UserId=3;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
W.UIS.TouchEnabled=true;L.Controls=function()return controls(844,390)end
local real=R.Instance.new;R.Instance.new=function(class,parent)local o=real(class,parent);if class=='ScreenGui'then o.AbsoluteSize=R.Vector2.new(844,390)end;return o end
W.workspace.CurrentCamera.ViewportSize=R.Vector2.new(844,390)
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace;map:SetAttribute('VeiledEventActive',true)
player:SetAttribute('TreadmillTier',6);player:SetAttribute('TreadmillMultiplier',60);player:SetAttribute('ChestLuckMultiplier',5e7)
local econ=R.Instance.new('ScreenGui');econ.Name='GardenEconomy';econ.Parent=pg
local wallet=W.module('GardenWallet').new(econ)
local status=W.module('WorldStatusHud').Create(pg,player);W.frames(30)
local m=L.Read({X=844,Y=390},true,controls(844,390))
local gems=econ:FindFirstChild('GemHud');check(gems and gems.Active==false,'gem row lets a thumb drag start on it (not a button on phones)')
check(gems and gems:FindFirstChild('MoreGems').Visible~=false,'the + button still works')
local root=status.Gui.StatusStack
check(root.AnchorPoint.X==1 and root.AnchorPoint.Y==1 and root.Position.X.Offset==-12 and root.Position.Y.Offset==-m.StatusBottom,'timers anchored above the jump button')
check(root.Weather.BackgroundTransparency==1 and root.Track.BackgroundTransparency==1,'plain text timers (no card)')
local sp,wy,ty=root.SpecialKeeper.Position.Y.Offset,root.Weather.Position.Y.Offset,root.Track.Position.Y.Offset
local by=root.LuckBoost.Position.Y.Offset
check(root.SpecialKeeper.Visible and by<sp and sp<wy and wy<ty,'one stack: boosts, The Darkened, then the two timers ('..by..','..sp..','..wy..','..ty..')')
check(root.Size.Y.Offset==ty+39 and root.Size.Y.Offset*m.StatusScale<=m.StatusBox.H+1e-6,'the stack fits its reserved corner')
-- Back to a computer: cards return
W.UIS.TouchEnabled=false;L.Controls=function()return nil end;status.Update()
check(root.Weather.BackgroundTransparency==.73,'computer timers keep their cards')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
