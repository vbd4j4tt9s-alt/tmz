--!nocheck
-- R137 (owner: "sometimes the lower icon versions of the packs and seeds show up [in the hotbar and spinning things]
-- remove those from the game"): the real ItemPictures on the mock. No flat 2D icon is ever made; every holder on screen
-- gets the real 3D picture, with Low graphics too and past the old 60-view cap; looks can be built ahead (P.Warm);
-- the bonus reel warms its cards; Index cards never use the far-away plant stand-in.
local W=require('./world');local F=require('./fixtures');local R=W.R;local V3=R.Vector3.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
-- Mock gaps for the seed builders (as in the R134 seed test).
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
F.packAssets(W)
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=9;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
player:SetAttribute('QualityChoice','Low') -- used to turn every picture into a flat icon
local P=W.module('ItemPictures')
local gui=R.Instance.new('ScreenGui');gui.Name='Pictures';gui.Parent=pg
local tools=R.new('Folder');tools.Parent=W.workspace
local holders={};local looks={}
local n=0
for stage=1,7 do for d=1,6 do
 n+=1;local t=F.pack(W,tools,stage,string.format('Pack%02d',d),1,'None');looks[#looks+1]=t
end end
for _,id in ipairs({'SunflowerSeed','IceberrySeed','LavaLotusSeed','PrismMonarchSeed','StormSovereignSeed','DiamondVineSeed'})do looks[#looks+1]=F.seed(W,tools,id,1,'None')end
-- 120 holders on screen (more than the old 60-view cap), many sharing a look.
for i=1,120 do
 local h=R.new('Frame');h.Name='Holder'..i;h.Size=R.UDim2.fromOffset(60,60);h.Parent=gui
 h.AbsoluteSize=R.Vector2.new(60,60);h.AbsolutePosition=R.Vector2.new((i-1)%20*62,math.floor((i-1)/20)*62)
 holders[i]=h
end
local flatSeen=0
local function scan()for _,d in ipairs(pg:GetDescendants())do if d.Name=='FlatIcon'then flatSeen+=1 end end end
for i,h in ipairs(holders)do P.Show(h,looks[(i-1)%#looks+1],i<=10 and 1 or 2);scan()end
check(flatSeen==0,'nothing flat while the looks are still building (holders stay empty)')
local filledAt=nil
for frame=1,240 do
 W.frames(1);scan()
 local views=0;for _,h in ipairs(holders)do if h:FindFirstChild('ItemViewport')then views+=1 end end
 if views==#holders and not filledAt then filledAt=frame end
end
check(flatSeen==0,'no flat icon is ever made (Low graphics on)')
check(filledAt~=nil,'every one of the 120 holders shows its real 3D picture'..(filledAt and(' after '..filledAt..' frames')or''))
check(P.Low()==false,'Low graphics no longer swaps pictures')
local stats=P.Stats()
check(stats.Views==120,'120 views at once (the old cap was 60): '..stats.Views)
-- A look that is ready attaches at once.
local h=R.new('Frame');h.Size=R.UDim2.fromOffset(60,60);h.Parent=gui;h.AbsoluteSize=R.Vector2.new(60,60);h.AbsolutePosition=R.Vector2.new(0,400)
P.Show(h,looks[1],1);check(h:FindFirstChild('ItemViewport')~=nil,'a built look shows immediately')
-- Off screen views are released (nothing flat replaces them).
P.Grace=0 -- (recently hidden pictures normally stay 3 real seconds)
for i=61,120 do holders[i].Visible=false end
for _=1,30 do W.frames(1)end;scan()
local hiddenViews=0;for i=61,120 do if holders[i]:FindFirstChild('ItemViewport')then hiddenViews+=1 end end
check(hiddenViews==0 and flatSeen==0,'hidden holders let their views go and get nothing flat')
-- Warm: looks built ahead with no holder.
local before=P.Stats().Templates
local extra={};for d=1,6 do extra[#extra+1]=F.pack(W,tools,3,string.format('Pack%02d',d),1,'Gold')end
P.Warm(extra);for _=1,60 do W.frames(1)end
check(P.Stats().Templates>=before+6,('P.Warm builds looks ahead (%d -> %d templates)'):format(before,P.Stats().Templates))
-- Static checks on the callers (sources from the test bundle).
check((W.B.TreadmillBonusClient or''):find('Pictures.Warm',1,true)~=nil,'the bonus reel builds all its card pictures before it spins')
check(W.B.CollectionViewport~=nil and not W.B.CollectionViewport:find('DistantPlantView).Build',1,true),'Index cards never use the far-away plant stand-in')
check(not W.B.ItemPictures:find("'FlatIcon'",1,true),'the flat icon drawing code is gone')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
