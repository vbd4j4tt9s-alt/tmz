--!nocheck
-- R153 jitter, world effects, on the mock with the REAL scripts: what is drawn (read right after RenderStepped) moves on every frame at 30 / 60 / 144 fps.
--  1. ItemCosmetics: a weather-mutated item lying in the world (it stepped at 20 Hz, 10 Hz low) and one carried by a running player (stays on it);
--     nothing moves in the physics half of a frame (Heartbeat / Stepped only);
--  2. SeedPackRender: a track pack hovers every frame within 240 studs on every tier (30 / 20 Hz before), its Gold mutation halo and rarity rays turn
--     every frame (30 Hz before); a pack past 240 studs keeps the cheap rate;
--  3. LavaFlow: the glows that flow down a route within 160 studs move every frame (20 Hz before), a farther route keeps the tick;
--  4. HomeMarker: the bob is written in RenderStepped, every frame, nothing past its MaxDistance.
local J=require('./jitter_world');local W,R=J.W,J.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local CS=W.CS
local me=J.player('Me',7,true);local char=J.character(me,V3(0,3,20))
J.look(V3(0,10,-10),V3(0,4,20))

-- 1. ItemCosmetics ------------------------------------------------------------------------------------------------------------------------------------------
do
 local function item(parent,pos,name,trait)
  local p=R.new('Part');p.Name=name;p.Size=V3(1,1,1);p.CFrame=CF(pos.X,pos.Y,pos.Z);p.Parent=parent
  p:SetAttribute('WeatherTrait',trait);p:SetAttribute('EffectRadius',1.2);p:SetAttribute('EffectHeight',2);CS:AddTag(p,'GardenItemFX');return p
 end
 local world=item(W.workspace,V3(6,4,24),'MutatedFruit','Drippy')
 local tool=R.new('Tool');tool.Name='Fruit';tool.Parent=char
 local held=item(tool,char.HumanoidRootPart.Position+V3(1,0,-1),'Handle','Frosted')
 local sc=R.new('LocalScript');sc.Name='ItemCosmetics';W.load('ItemCosmetics',sc)
 J.run(1,60)
 local folder=W.workspace:FindFirstChild('_ItemCosmeticsR59')
 local sets=folder and folder:GetChildren()or{}
 check(#sets==2,'ItemCosmetics: two effect sets ('..#sets..')')
 local worldSet,heldSet
 for _,f in ipairs(sets)do local first=f:GetChildren()[1];if first then if first.Name=='Drippy'then worldSet=f else heldSet=f end end end
 if check(worldSet and heldSet,'ItemCosmetics: the world item\'s drips and the carried item\'s frost')then
  local drip=worldSet:GetChildren()[1];local frost=heldSet:GetChildren()[1]
  J.everyFrame(check,'a Drippy item lying in the world (was 20 Hz)',1.5,nil,function()return drip.CFrame end)
  J.tier=1;J.everyFrame(check,'the same on the low tier (was 10 Hz)',1,nil,function()return drip.CFrame end);J.tier=3
  -- a player running with a Frosted fruit: every drawn frame the frost is around the fruit (it never trails behind)
  local worst=0
  J.everyFrame(check,'a carried Frosted item while its carrier runs 20 studs/s',1,nil,function()
   local c=held.CFrame.Position;local d=0
   for _,p in ipairs(heldSet:GetChildren())do d=math.max(d,(V3(p.CFrame.Position.X,c.Y,p.CFrame.Position.Z)-c).Magnitude)end
   worst=math.max(worst,d);return frost.CFrame end,
   function(_,dt)J.move(char,V3(0,0,20*dt),dt)end)
  check(worst<=1.2*1.1+.25,string.format('ItemCosmetics: the frost stays around the running fruit on every drawn frame (worst %.2f studs from it)',worst))
  local before=drip.CFrame;J.physicsOnly(12)
  check(J.same(drip.CFrame,before),'ItemCosmetics: nothing moves in the physics half of a frame (Heartbeat / Stepped only): it is drawn in RenderStepped')
 end
 sc:Destroy();world:Destroy();tool:Destroy()
end

-- 2. SeedPackRender ----------------------------------------------------------------------------------------------------------------------------------------
do
 local function pack(at,mutation,rank)
  local m=R.new('Model');m.Name='BiomeSeedPack'
  local specs={{'Body',V3(1.9,2.3,.5),CF(0,0,0)},{'Band',V3(1.95,.3,.55),CF(0,.9,0)},{'Label',V3(1.2,.8,.05),CF(0,0,-.27)}}
  for i,s in ipairs(specs)do
   local p=R.new('Part');p.Name=s[1];p.Size=s[2];p.CFrame=at*s[3];p.Anchored=true;p:SetAttribute('PackLocalFrame',s[3]);p.Parent=m
   if i==1 then m.PrimaryPart=p end
  end
  for k,v in pairs({CompactPackReady=true,CompactPackPartCount=#specs,WorldPack=true,HoverOrigin=at,PackRank=rank,Stage=1,VisualScale=1,PackMutation=mutation,HoverPhase=.3,PackArtKey='Forest_01'})do m:SetAttribute(k,v)end
  m.Parent=W.workspace;CS:AddTag(m,'BiomeSeedPackVisual');return m
 end
 local near=pack(CF(-4,5,30),'Gold',5)
 J.look(V3(0,8,0),V3(-4,5,30))
 local sc=R.new('LocalScript');sc.Name='SeedPackRender';W.load('SeedPackRender',sc)
 J.run(1,60)
 local root=near.PrimaryPart
 J.everyFrame(check,'a Gold track pack 30 studs away hovers (was 30 Hz)',1.5,nil,function()return root.CFrame end)
 local fxRoot=W.workspace:FindFirstChild('_LocalPackPolishV128')
 local halo,ray
 for _,d in ipairs(fxRoot and fxRoot:GetDescendants()or{})do
  if d:IsA('Attachment')and d.Name=='GoldenMutationHaloA1'then halo=d end
  if d:IsA('Attachment')and d.Name=='SunRayEnd1'then ray=d end
 end
 if check(halo and ray,'SeedPackRender: the Gold mutation halo and the Legendary rays are built for the near pack')then
  J.everyFrame(check,'its Gold mutation halo turns (was 30 Hz)',1.5,nil,function()return halo.CFrame end)
  J.everyFrame(check,'its rarity rays pulse (was 30 Hz)',1.5,nil,function()return ray.CFrame end)
  J.tier=1;J.everyFrame(check,'the halo on the low tier (was 20 Hz)',1,nil,function()return halo.CFrame end);J.tier=3
 end
 -- every tier: a pack 100 studs away (inside 240) hovers every frame
 near:Destroy();J.run(.5,60)
 local mid=pack(CF(0,5,100),'None',2);J.look(V3(0,8,0),V3(0,5,100));J.run(.6,60)
 for _,tier in ipairs({3,2,1})do
  J.tier=tier;J.everyFrame(check,'tier '..tier..': a pack 100 studs away hovers',1,nil,function()return mid.PrimaryPart.CFrame end)
 end
 J.tier=3
 local before=mid.PrimaryPart.CFrame;J.physicsOnly(10);check(J.same(mid.PrimaryPart.CFrame,before),'SeedPackRender: nothing moves in the physics half of a frame')
 -- past 240 studs it keeps PackDue (no bob there; it only turns to the camera, a few times a second)
 mid:Destroy();local far=pack(CF(0,5,400),'None',2);J.look(V3(0,8,0),V3(0,5,400));J.run(1,60)
 local moves=0;local last=far.PrimaryPart.CFrame
 for i=1,120 do J.frame(1/60);J.look(V3(i*.05,8,0),V3(0,5,400));if not J.same(far.PrimaryPart.CFrame,last)then moves+=1 end;last=far.PrimaryPart.CFrame end
 check(moves<=10,'SeedPackRender: a pack 400 studs away keeps the cheap rate ('..moves..' moves in 2 s while the camera drifts)')
 far:Destroy();sc:Destroy()
end

-- 3. LavaFlow -------------------------------------------------------------------------------------------------------------------------------------------------
do
 local map=W.workspace:FindFirstChild('ChestChaseMap')or R.new('Folder');map.Name='ChestChaseMap';map:SetAttribute('RoutesExpandedV134',true);map.Parent=W.workspace
 local function route(x)
  local m=R.new('Model');m.Name='LavaRoute';m:SetAttribute('LavaRouteV128',true);m:SetAttribute('NodeCount',3)
  m:SetAttribute('Node1',V3(x,0,0));m:SetAttribute('Node2',V3(x,1,20));m:SetAttribute('Node3',V3(x+5,0,40));m:SetAttribute('FlowSpeed',7)
  for i=1,4 do local p=R.new('Part');p.Name='Glow'..i;p:SetAttribute('FlowPhase',i/4);p.Parent=m end
  m.Parent=map;return m
 end
 local near=route(0);local far=route(220)
 J.look(V3(0,12,-20),V3(0,0,20))
 local sc=R.new('LocalScript');sc.Name='LavaFlow';W.load('LavaFlow',sc)
 J.run(.5,60)
 local g=near:FindFirstChild('Glow1')
 J.everyFrame(check,'a lava glow flowing down a route 25 studs away (was 20 Hz)',1.5,nil,function()return g.CFrame end)
 local fg=far:FindFirstChild('Glow1');local moves=0;local last=fg.CFrame
 for _=1,120 do J.frame(1/60);if not J.same(fg.CFrame,last)then moves+=1 end;last=fg.CFrame end
 check(moves>=35 and moves<=45,'LavaFlow: a route 220 studs away keeps the 20 Hz tick ('..moves..' moves in 2 s)')
 sc:Destroy();near:Destroy();far:Destroy()
end

-- 4. HomeMarker ----------------------------------------------------------------------------------------------------------------------------------------------
do
 local map=W.workspace:FindFirstChild('ChestChaseMap')
 local bases=R.new('Folder');bases.Name='Bases';bases.Parent=map
 local base=R.new('Model');base.Name='Base1';base:SetAttribute('BaseOwnerUserId',7);base.Parent=bases
 local pad=R.new('Part');pad.Name='Pad';pad.Size=V3(40,1,40);pad.CFrame=CF(0,0,60);pad.Parent=base
 J.look(V3(0,20,0),V3(0,0,60))
 local sc=R.new('LocalScript');sc.Name='HomeMarker';W.load('HomeMarker',sc)
 J.run(1.2,60)
 local gui=me.PlayerGui:FindFirstChild('HomeMarker')
 if check(gui and gui.Adornee==pad,'HomeMarker: the marker is on your pad')then
  J.everyFrame(check,'the home marker bobs',1.5,nil,function()return gui.StudsOffsetWorldSpace end)
  local before=gui.StudsOffsetWorldSpace;J.physicsOnly(10);check(J.same(gui.StudsOffsetWorldSpace,before),'HomeMarker: written in RenderStepped, not in the physics half')
  J.look(V3(0,20,-1000),V3(0,0,60));J.run(.2,60);before=gui.StudsOffsetWorldSpace;J.run(.5,60)
  check(J.same(gui.StudsOffsetWorldSpace,before),'HomeMarker: past its MaxDistance (900 studs) nothing is written')
 end
 sc:Destroy()
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
