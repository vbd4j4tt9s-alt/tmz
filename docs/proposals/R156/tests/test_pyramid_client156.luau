--!nocheck
-- R156 the Desert's secret pyramid, the CLIENT, on the Roblox mock with the REAL SecretPyramidClient156 script, PyramidRules156, SecretPyramid156.Build (the
-- server's pyramid and its anchor) and the REAL pack builders with the owner's pack templates (pack_world.luau).
--  1. the floating pack: built only while YOUR state is 'Open' and the camera is near; the same art as a Desert Mythic world pack (every part, size, colour and
--     place of SeedPackVisuals.Bag(Desert, Pack06, size 1, plain)), tagged for the game's pack renderer as a held pack; it floats at the chamber's centre,
--     3.5 studs over the floor, clear of the floor and the caps, inside the walls
--  2. the turn and the bob: one hub, one weld, 4 tweens made once per pack; nothing connected per frame for them (no RenderStepped / BindToRenderStep); the
--     script's only per-frame callback (the 5-a-second check) makes nothing; Reduced Motion: still
--  3. the prompt: on from the 4 sides and the 4 corners at ground level, the steps and inside; off at twice the reach; off for 'Out' and 'Claimed'
--  4. per player: 'Out' (carrying) and 'Claimed' hide the pack; 'Open' again (caught, or the owner's reset) brings it back; far away it is let go
--  5. streamed out: the pack goes, the check stops
local H=require('./pack_world');local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(e or 1e-6)end
local RS=W.RS;local Run=W.Run;local CS=W.CS
local Rules=W.module('PyramidRules156');local Pyr=W.module('SecretPyramid156')
local player=W.service('Players').LocalPlayer
local G=Rules.Geometry()
-- the tweens the script makes (the mock's TweenService plays a tween to its end at once)
local tweens={};local Tween=W.service('TweenService');local create=Tween.Create
Tween.Create=function(svc,obj,info,props)local t=create(svc,obj,info,props);t.Obj,t.Info,t.Props,t.Plays=obj,info,props,0;local play=t.Play;t.Play=function(...)t.Plays+=1;return play(...)end;tweens[#tweens+1]=t;return t end
-- The server's pyramid at the Desert spot, its prompt as SecretPyramid156:Start makes it
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
local landmarks=R.new('Folder');landmarks.Name='MythicLandmarks';landmarks.Parent=map
local spot=V3(-62.0675,4,1005)
local model=Pyr.Build(spot);model.Parent=landmarks
local anchor=model:FindFirstChild(Rules.AnchorName);local zone=Rules.ReadZone(anchor)
local prompt=R.new('ProximityPrompt');prompt.Name='Steal';prompt.MaxActivationDistance=zone.Reach;prompt.RequiresLineOfSight=false;prompt.Enabled=true;prompt.Parent=anchor
-- the local player stands next to the pyramid, the camera behind him
local char,hrp=H.character('R15',CF(spot.X,7,spot.Z-G.Half-3));player.Character=char
local camera=W.workspace.CurrentCamera;camera.CFrame=CF(spot.X+10,12,spot.Z-G.Half-25)
local function live(sig)local n=0;for _,c in ipairs(sig._c)do if c.Connected then n+=1 end end;return n end -- (connections still connected)
local beatsBefore=live(Run.Heartbeat);local renderBefore=live(Run.RenderStepped)
local Gui=W.service('GuiService');Gui.ReducedMotionEnabled=true -- (first with Reduced Motion: the pack stays in its built pose, which the mock can read exactly)
local sc=R.new('LocalScript');sc.Name='SecretPyramidClient156';W.load('SecretPyramidClient156',sc)
local function frames(n)W.frames(n or 15)end
local function packModel()local f=W.workspace:FindFirstChild('SecretPyramidPack156');return f and f:FindFirstChild('SecretPyramidPack')end
frames()
check(packModel()==nil and prompt.Enabled==false,'before the profile has loaded (no state yet): no pack, no prompt')
player:SetAttribute(Rules.Attr,'Open');frames()
local bag=packModel()
check(bag~=nil,'state Open and the camera near: the pack is built')
if not bag then error('no pack: the rest cannot be checked')end

-- 1. The art and where it floats ----------------------------------------------------------------------------------------------------------------------------------
check(bag:GetAttribute('Stage')==2 and bag:GetAttribute('BagVariant')=='Pack06'and bag:GetAttribute('PackRarity')=='Mythic'and bag:GetAttribute('PackMutation')=='None'and bag:GetAttribute('PackSize')==1,
 'the Desert Mythic pack: Stage 2, Pack06 (Mythic), plain, size 1')
check(Rules.Mutation=='None','its coat is the one constant PyramidRules156.Mutation (plain by default)')
check(CS:HasTag(bag,'BiomeSeedPackVisual')and bag:GetAttribute('WorldPack')==false,'tagged for the game\'s pack renderer (SeedPackRender), as a held pack: it turns on its own hub')
-- the same parts as a Desert Mythic world pack on the track (SeedPackVisuals.Bag, as ChestService:BuildSeedPacket builds it)
local world=H.ground(2,'Pack06',1,'None',nil,0)
local function sig(b)
 local root=b.PrimaryPart;local out={};local n=0
 for _,p in ipairs(H.partsOf(b,false))do
  n+=1;local f=root.CFrame:Inverse()*p.CFrame
  out[(p.Parent==b and''or p.Parent.Name..'/')..p.Name..'#'..n]={Size=p.Size,Pos=f.Position,Color=p.Color,Mat=H.enumName(p.Material),T=p.Transparency,Class=p._class}
 end
 return out,n
end
local a,na=sig(bag);local b,nb=sig(world)
local same=na==nb and na>5
if same then
 local la,lb={},{};for k,v in pairs(a)do la[#la+1]={k,v}end;for k,v in pairs(b)do lb[#lb+1]={k,v}end
 table.sort(la,function(x,y)return x[1]<y[1]end);table.sort(lb,function(x,y)return x[1]<y[1]end)
 for i=1,#la do local x,y=la[i][2],lb[i][2]
  if la[i][1]~=lb[i][1]or(x.Size-y.Size).Magnitude>1e-6 or(x.Pos-y.Pos).Magnitude>1e-5 or x.Mat~=y.Mat or x.T~=y.T or x.Class~=y.Class or math.abs(x.Color.R-y.Color.R)+math.abs(x.Color.G-y.Color.G)+math.abs(x.Color.B-y.Color.B)>1e-6 then
   same=false;print('  differs: '..la[i][1])
  end
 end
end
check(same,('the same art as a Desert Mythic world pack: %d parts, every size, place, colour and material (%d on the track)'):format(na,nb))
world:Destroy()
local root=bag.PrimaryPart
local lo,hi=math.huge,-math.huge;local xz=0
for _,p in ipairs(H.partsOf(bag,false))do if p.Transparency<1 then
 lo=math.min(lo,p.Position.Y-p.Size.Magnitude/2);hi=math.max(hi,p.Position.Y+p.Size.Magnitude/2)
 xz=math.max(xz,math.abs(p.Position.X-spot.X)+p.Size.Magnitude/2,math.abs(p.Position.Z-spot.Z)+p.Size.Magnitude/2)
end end
check(near(root.Position.X,spot.X,1e-6)and near(root.Position.Z,spot.Z,1e-6)and near(root.Position.Y,spot.Y+G.FloorTop+Rules.Lift,1e-6),
 ('it floats at the chamber\'s centre, its centre %.2f studs over the floor (%.2f over the ground)'):format(root.Position.Y-spot.Y-G.FloorTop,root.Position.Y-spot.Y))
check(lo-(spot.Y+G.FloorTop)>=1 and hi<spot.Y+G.CeilingY-1 and xz<G.FloorHalf-1,('clear of everything: %.2f studs over the floor, %.2f under the caps, %.2f inside the walls (a bounding ball of every part)'):format(lo-(spot.Y+G.FloorTop),spot.Y+G.CeilingY-hi,G.FloorHalf-xz))
local plays=0;for _,t in ipairs(tweens)do plays+=t.Plays end
local hub0=W.workspace.SecretPyramidPack156:FindFirstChild('SecretPackHub156')
check(#tweens==4 and plays==0 and hub0 and near(hub0.CFrame.Position.Y,zone.Pack.Y,1e-9),'Reduced Motion: the pack stands still (its 4 tweens made, none played)')
Gui.ReducedMotionEnabled=false;frames() -- (the setting changes while the pack is there: it starts to turn and bob)

-- 2. The turn and the bob ------------------------------------------------------------------------------------------------------------------------------------------------
local hub=W.workspace.SecretPyramidPack156:FindFirstChild('SecretPackHub156')
local weld=hub and hub:FindFirstChild('SpinWeld156')
check(hub and hub.Anchored and hub.Transparency==1 and not hub.CanCollide and weld and weld:IsA('Weld')and weld.Part0==hub and weld.Part1==root,'the pack hangs on one invisible anchored hub by one Weld')
local mine={};for _,t in ipairs(tweens)do if t.Obj==weld or t.Obj==hub then mine[#mine+1]=t end end
local spins,bob=0,nil;for _,t in ipairs(mine)do if t.Obj==weld then spins+=1 elseif t.Obj==hub then bob=t end end
check(#mine==4 and spins==3 and bob and bob.Info.Style==R.Enum.EasingStyle.Sine,'4 tweens for this pack: 3 thirds of a turn on the weld, 1 bob on the hub')
local thirds=true;for _,t in ipairs(mine)do if t.Obj==weld then
 if not near(t.Info.Time,Rules.Spin.Period/3,1e-9)or t.Info.Style~=R.Enum.EasingStyle.Linear then thirds=false end
end end
check(thirds,('each third of the turn takes %.2f s (a full turn in %d s), linear'):format(Rules.Spin.Period/3,Rules.Spin.Period))
check(near(bob.Props.CFrame.Position.Y-zone.Pack.Y,Rules.Spin.Bob,1e-6)and near(bob.Info.Time,Rules.Spin.BobPeriod/2,1e-9),('the bob: %.2f studs up and down, %d s a cycle'):format(Rules.Spin.Bob,Rules.Spin.BobPeriod))
check(live(Run.RenderStepped)==renderBefore and next(W.rsBound)==nil,'nothing is bound to the render step')
local myBeats=live(Run.Heartbeat)-beatsBefore
check(myBeats==1,'one Heartbeat callback: the 5-a-second check ('..myBeats..')')
-- the per-frame callback makes nothing (it only adds up the time until the next check)
local tick=Run.Heartbeat._c[#Run.Heartbeat._c]._f
collectgarbage('collect');local m0=collectgarbage('count')
for _=1,20000 do tick(1e-6)end
local grew=collectgarbage('count')-m0
check(grew<1,('20,000 frames between checks make nothing (%.3f KB)'):format(grew))
local n0=#tweens;frames(120)
check(#tweens==n0,'frames go by: no new tweens (they are made once per pack)')

-- 3. The prompt ---------------------------------------------------------------------------------------------------------------------------------------------------------
local half=G.Half;local groundY=spot.Y+3
local function promptAt(pos)hrp.CFrame=CF(pos.X,pos.Y,pos.Z);frames();return prompt.Enabled,(pos-zone.Pack).Magnitude end
local spots={{'north side',V3(spot.X,groundY,spot.Z+half+3)},{'south side',V3(spot.X,groundY,spot.Z-half-3)},{'east side',V3(spot.X+half+3,groundY,spot.Z)},{'west side',V3(spot.X-half-3,groundY,spot.Z)},
 {'NE corner',V3(spot.X+half+2,groundY,spot.Z+half+2)},{'NW corner',V3(spot.X-half-2,groundY,spot.Z+half+2)},{'SE corner',V3(spot.X+half+2,groundY,spot.Z-half-2)},{'SW corner',V3(spot.X-half-2,groundY,spot.Z-half-2)},
 {'a step',V3(spot.X+half-2*G.SlabHeight,spot.Y+3*G.SlabHeight+3,spot.Z)},{'inside',V3(spot.X+4,groundY,spot.Z+4)}}
local allOn=true;local farOff=true
for _,s in ipairs(spots)do
 local on,d=promptAt(s[2]);if not on or d>prompt.MaxActivationDistance then allOn=false;print(('  off at %s (%.2f)'):format(s[1],d))end
 if s[1]:find('side')or s[1]:find('corner')then
  local dir=V3(s[2].X-zone.Pack.X,0,s[2].Z-zone.Pack.Z).Unit;local far=V3(zone.Pack.X,groundY,zone.Pack.Z)+dir*(2*zone.Reach)
  local onFar,dFar=promptAt(far);if onFar or dFar<=prompt.MaxActivationDistance then farOff=false;print('  on at twice the distance: '..s[1])end
 end
end
check(allOn,'the prompt is on from the 4 sides and the 4 corners at ground level, a step and inside')
check(farOff,'... and off at twice the reach in each of those directions (also past the prompt\'s own distance)')
promptAt(V3(spot.X,groundY,spot.Z-half-3))
player:SetAttribute(Rules.Attr,'Out');frames()
check(prompt.Enabled==false and packModel()==nil,'carrying it (\'Out\'): no prompt, no pack in the pyramid')
player:SetAttribute(Rules.Attr,'Open');frames()
check(prompt.Enabled==true and packModel()~=nil,'back in the pyramid (caught / lost): the pack and the prompt are back')

-- 4. Claimed, and far away -------------------------------------------------------------------------------------------------------------------------------------------------
player:SetAttribute(Rules.Attr,'Claimed');frames(60)
check(packModel()==nil and prompt.Enabled==false,'claimed: the pack is gone from the pyramid for this player and the prompt is off')
check(model.Parent~=nil and #model:GetChildren()==61,'(the pyramid itself stays: 60 parts and the anchor)')
player:SetAttribute(Rules.Attr,'Open');frames()
check(packModel()~=nil,'the owner\'s reset (\'Open\' again): it is back')
camera.CFrame=CF(spot.X,12,spot.Z-(Rules.Client.BuildOut+20));frames()
check(packModel()==nil,'the camera '..(Rules.Client.BuildOut+20)..' studs away: the pack is let go')
camera.CFrame=CF(spot.X,12,spot.Z-(Rules.Client.BuildIn-20));frames()
check(packModel()~=nil,'back within '..Rules.Client.BuildIn..' studs: built again')

-- 5. Streamed out ---------------------------------------------------------------------------------------------------------------------------------------------------------------
CS:RemoveTag(anchor,Rules.Tag);frames()
check(packModel()==nil and live(Run.Heartbeat)==beatsBefore,'the pyramid streams out: the pack goes and the check stops')
CS:AddTag(anchor,Rules.Tag);frames()
check(packModel()~=nil and live(Run.Heartbeat)==beatsBefore+1,'it streams back in: the pack and the check are back')
print(('R156 pyramid client: %d checks, %d failures'):format(checks,fails))
if fails>0 then error('failed')end
