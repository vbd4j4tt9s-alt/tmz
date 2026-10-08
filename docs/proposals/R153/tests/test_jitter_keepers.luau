--!nocheck
-- R153 jitter, keepers and the Void, on the mock with the REAL scripts. The server moves a keeper's anchored root in packet steps (here: an irregular
-- ~20 Hz with 30 studs/s of travel); the client draws the body from KeeperMotion's smoothed frame.
--  1. KeeperSpeedLabels + BeastAnimation: the "SPEED NEEDED" sign is pinned at the keeper's spawn point (R153 owner spec, run_keeper_label.sh): it does
--     not follow the keeper, so it does not move at all while the keeper runs in packet steps (nothing to smooth), at 30 / 60 / 144 fps;
--  2. CosmeticBudget.KeeperDue: an awake keeper on screen within 350 studs is posed every frame (30 / 20 Hz before); asleep / off screen keep the saving;
--  3. VeiledEventClient81: The Darkened's body (posed on a smoothed root) advances every drawn frame while the server root steps (it makes no sign anchor: the signs are pinned);
--  4. VeiledEventClient81: a Void pack in the world with its effects (the nearest 1 / 2 / 4 by tier) is posed and stepped every frame on every tier
--     (30 Hz, 15 Hz low before); its debris orbit every frame.
local J=require('./jitter_world');local W,R=J.W,J.R;local V3,CF=R.Vector3.new,R.CFrame.new
local F=require('./fixtures')
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local CS=W.CS
local me=J.player('Me',7,true);J.character(me,V3(0,3,-30))
me:SetAttribute('PhysicalWalkSpeed',20)
if not rawget(R.Inst,'Stop')then rawset(R.Inst,'Stop',function(self)self.Playing=false end)end
if not rawget(R.Inst,'Play')then rawset(R.Inst,'Play',function(self)self.Playing=true end)end
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='Sound'then o.IsLoaded=true;o.TimeLength=3;o.TimePosition=0;o.Loaded=R.signal();o.Ended=R.signal()end
 if class=='RemoteEvent'then o.OnClientEvent=R.signal()end
 return o end;W.env.Instance=R.Instance end
W.service('Debris').AddItem=function(_,o,t)R.task.delay(t or 10,function()o:Destroy()end)end
W.stub('KeeperAudio',{Voice=function()return nil,0,1 end});W.stub('SoundTiming',{Play=function()end})
W.stub('KeeperVoices',setmetatable({},{__index=function()return {Gap=6}end}))
W.stub('NoticeFeed83',{Push=function()end});W.stub('VeiledArrivalFx',{Preload=function()end,Arrive=function()end,Stop=function()end})
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local arrival=R.new('RemoteEvent');arrival.Name='VeiledArrival81';arrival._props.OnClientEvent=R.signal();arrival.Parent=remotes
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
-- The server's packets: the root jumps to where the keeper is now, at irregular ~20 Hz (40 - 65 ms), 30 studs/s along +x.
local function packets(root,from,speed)
 local start=R.clock-.05;local nextAt=R.clock;local k=0 -- (the first packet already carries the keeper 1.5 studs on)
 return function()
  if R.clock>=nextAt then k+=1;nextAt=R.clock+.04+.025*((k*7)%5)/4;root.CFrame=from*CF(speed*(R.clock-start),0,0)end
 end
end

-- 1. The speed sign over a keeper ------------------------------------------------------------------------------------------------------------------------
local Cfg=W.module('KeeperRigConfig')
local function keeper(stage,at)
 local m=R.new('Model');m.Name='Guardian_Stage'..stage
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.CFrame=at;root.Anchored=true;root.Parent=m;m.PrimaryPart=root
 local body=R.new('Model');body.Name='BeastBody';body:SetAttribute('VisualVersion',99)
 for _,s in ipairs(Cfg[stage].Parts)do
  local p=R.new('Part');p.Name=s.Name;p.Size=V3(s.Size[1],s.Size[2],s.Size[3]);local rest=CF(s.Center[1],s.Center[2],s.Center[3]);p.CFrame=at*rest;p.Anchored=true
  p:SetAttribute('RestCFrame',rest);p:SetAttribute('BeastGroup',s.Group);p:SetAttribute('KeeperEyeGlow',s.EyeGlow);p.Parent=body
 end
 body.Parent=m
 for k,v in pairs({GardenerArtVersion=99,CreatureStage=stage,GuardianBehavior='CHASING',KeeperEscapeSpeed=40,KeeperTravelSpeed=30,KeeperClientAnimated=true})do m:SetAttribute(k,v)end
 m.Parent=W.workspace;CS:AddTag(m,'BiomeKeeper');return m
end
local K=keeper(2,CF(-20,6,20))
J.look(V3(0,15,-30),V3(0,6,20))
local ba=R.new('LocalScript');ba.Name='BeastAnimation';W.load('BeastAnimation',ba)
local ks=R.new('LocalScript');ks.Name='KeeperSpeedLabels';W.load('KeeperSpeedLabels',ks)
J.run(.5,60)
-- Client bug review, finding 5: nothing reads a keeper's follow anchor now that the signs are pinned, so BeastAnimation builds and moves none (no part named
-- KeeperFollow anywhere in the world, no _KeeperFollow153 folder, and the module is gone); the keeper's body is still smoothed (the checks below and in section 2).
local function followParts()
 local n=0;for _,d in ipairs(W.workspace:GetDescendants())do if d.Name=='KeeperFollow'or d.Name=='_KeeperFollow153'then n+=1 end end;return n
end
check(followParts()==0 and W.RS:FindFirstChild('KeeperFollow153')==nil,'a keeper makes no per-frame follow anchor (no KeeperFollow part, no _KeeperFollow153 folder, no KeeperFollow153 module)')
-- R153 (the owner's spawn-pinned spec): the sign no longer follows the keeper at all (KeeperSpeedLabels does not use KeeperFollow153): a pinned sign never
-- moves, so there is nothing to smooth. Its own suite is run_keeper_label.sh; here it must stay exactly where it is while the packet-stepped, smoothed
-- keeper runs, on every drawn frame at 30 / 60 / 144 fps.
local function signOf(m)
 local f=W.workspace:FindFirstChild('KeeperSignAnchors');if not f then return nil end
 for _,a in ipairs(f:GetChildren())do local link=a:FindFirstChild('Keeper');if link and link.Value==m then return a:FindFirstChild('SpeedReq'),a end end
 return nil
end
local sign,anchor=signOf(K);local root=K.HumanoidRootPart
if check(sign~=nil,'the speed sign is there (on its own anchor, not under the keeper)')then
 check(anchor~=nil and sign.Adornee==anchor and anchor~=root and anchor.Name=='SpeedSign'and anchor.Transparency==1 and anchor.Anchored==true and anchor.CanCollide==false and anchor.CanTouch==false and anchor.CanQuery==false and not anchor:IsDescendantOf(K),
  'it hangs on its own invisible anchored part (no collision / touch / query), not on the keeper\'s root and not on the smoothed body\'s anchor')
 local home=anchor.Position;local off0=sign.StudsOffsetWorldSpace
 local stepRoot=packets(root,root.CFrame,30)
 local worst=0
 for _,fps in ipairs({30,60,144})do
  J.sample(fps,fps*2,function()worst=math.max(worst,(anchor.Position-home).Magnitude,(sign.StudsOffsetWorldSpace-off0).Magnitude);return 0 end,function()stepRoot()end)
 end
 check(worst==0 and (root.Position-home).Magnitude>30,string.format('the keeper runs %.0f studs away (packets, smoothed body) at 30 / 60 / 144 fps: the sign does not move at all (drift %.3f)',(root.Position-home).Magnitude,worst))
 local before=anchor.CFrame;J.physicsOnly(10);check(J.same(anchor.CFrame,before),'nothing moves it in the physics half of a frame either')
 -- the animator lets go (the keeper's rig is removed): the sign stays where it was
 K.BeastBody:Destroy();J.run(.2,60)
 check(sign.Adornee==anchor and J.same(anchor.CFrame,before),'a keeper that is no longer animated here: the sign is still pinned at the spawn point')
end
ba:Destroy();ks:Destroy();K:Destroy()

-- 2. CosmeticBudget.KeeperDue ------------------------------------------------------------------------------------------------------------------------------
do
 local B=W.module('CosmeticBudget')
 local function rate(distance,asleep,onScreen,low)
  local n,last=0,nil
  for i=1,60 do local now=i/60;if B.KeeperDue(distance,asleep,asleep and 0 or 1,onScreen,now,last,low)then n+=1;last=now end end
  return n
 end
 for _,low in ipairs({false,true})do
  check(rate(200,false,true,low)==60 and rate(340,false,true,low)==60,'KeeperDue: an awake keeper on screen 200 / 340 studs away is posed every frame'..(low and' (low tier)'or'')..' (was 30 / 20 Hz)')
  check(rate(200,true,true,low)<=10,'KeeperDue: an asleep one there keeps its slow rate ('..rate(200,true,true,low)..' a second)')
  check(rate(200,false,false,low)<=10,'KeeperDue: one off screen keeps its slow rate ('..rate(200,false,false,low)..' a second)')
  check(rate(500,false,true,low)<=10,'KeeperDue: one 500 studs away keeps its slow rate ('..rate(500,false,true,low)..' a second)')
 end
 check(rate(100,true,false,false)==60,'KeeperDue: within 160 studs every frame, as before')
end

-- 3 + 4. VeiledEventClient81: The Darkened and the Void packs ---------------------------------------------------------------------------------------------
do
 local Art=W.module('VeiledKeeper81')
 local D=Art.Build(CF(40,6,40),W.workspace)
 D:SetAttribute('GuardianBehavior','CHASING');D:SetAttribute('VeiledAwakeAt',R.clock-5);D:SetAttribute('KeeperTravelSpeed',30)
 F.packAssets(W)
 local Visuals=W.module('SeedPackVisuals')
 local void=Visuals.Bag(CF(-12,6,30),W.workspace,1,nil,7,'EclipseReliquary',1,1,'None')
 void:SetAttribute('WorldPack',true);void:SetAttribute('HoverOrigin',CF(-12,6,30))
 J.look(V3(0,15,-20),V3(10,6,35))
 local sc=R.new('LocalScript');sc.Name='VeiledEventClient81';W.load('VeiledEventClient81',sc)
 J.run(.6,60)
 local root=D.PrimaryPart;local chest=D:FindFirstChild('BroadChest')
 local stepRoot=packets(root,root.CFrame,30)
 J.everyFrame(check,'The Darkened\'s body while it chases (server root in ~20 Hz packets)',1.5,nil,function()return chest.CFrame.Position end,function()stepRoot()end)
 -- finding 5: the sign is pinned at the spawn point, so The Darkened makes no follow anchor either (it used to move one every frame for nothing)
 check(followParts()==0,'The Darkened makes no per-frame follow anchor (no KeeperFollow part, no _KeeperFollow153 folder)')
 -- the Void pack: every tier, its pieces and its debris every frame
 local pr=void.PrimaryPart
 for _,tier in ipairs({3,2,1})do
  J.tier=tier;J.run(.3,60)
  local fx;for _,f in ipairs(W.workspace:GetChildren())do if f.Name=='_VoidPackFx122'then fx=f end end
  local debris=fx and fx:FindFirstChild('VoidDebris')
  local piece;for _,p in ipairs(void:GetDescendants())do if p:IsA('BasePart')and p~=pr then piece=p;break end end
  J.everyFrame(check,'tier '..tier..': a Void pack in the world (was 30 Hz, 15 Hz low)',1,nil,function()return piece.CFrame end)
  if check(debris~=nil,'tier '..tier..': its effects are on (debris)')then
   J.everyFrame(check,'tier '..tier..': the Void pack\'s orbiting debris',1,nil,function()return debris.CFrame end)
  end
 end
 J.tier=3
 local before=pr.CFrame;J.physicsOnly(10);check(J.same(pr.CFrame,before),'the Void pack moves in RenderStepped only')
 -- a Void pack 300 studs away (a slow hover, no spin, no effects) keeps the tick
 local far=Visuals.Bag(CF(-12,6,330),W.workspace,1,nil,7,'EclipseReliquary',1,1,'None');far:SetAttribute('WorldPack',true);far:SetAttribute('HoverOrigin',CF(-12,6,330))
 J.run(.3,60);local fp=far.PrimaryPart;local moves,last=0,fp.CFrame
 for _=1,120 do J.frame(1/60);if not J.same(fp.CFrame,last)then moves+=1 end;last=fp.CFrame end
 check(moves>=50 and moves<=70,'a Void pack 300 studs away keeps the 30 Hz tick ('..moves..' moves in 2 s)')
 sc:Destroy()
 check(followParts()==0,'after the script\'s removal no follow anchor is left either')
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
