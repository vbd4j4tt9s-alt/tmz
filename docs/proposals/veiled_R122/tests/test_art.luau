--!nocheck
-- R122 Void Pack art: builds through SeedPackVisuals.Bag (the shared entry used by world, dropped, carried,
-- ItemPictures, previews and the opening copy) + bounds + part budget + client FX budgets (VoidPackFx and the
-- real VeiledEventClient81 loop) on the Roblox mock with fake approved pack meshes.
local W=require('./world');local F=require('./fixtures');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new;local CFrame=R.CFrame
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
F.packAssets(W)
local Visuals=W.module('SeedPackVisuals');local Art=W.module('EclipsePackArt');local PackFx=W.module('VoidPackFx');local Rules=W.module('SeedPackRules')
local specs=Art.Specs()
local function parts(bag)local out={};for _,p in ipairs(bag:GetDescendants())do if p:IsA('BasePart')and p~=bag.PrimaryPart then out[#out+1]=p end end;return out end
local function named(bag)local n,set=0,{};for _,s in ipairs(specs)do set[s.Name]=true end;for _,p in ipairs(parts(bag))do if set[p.Name]then n+=1 end end;return n end
print(('spec parts %d (budget %d)'):format(#specs,Art.Budget.MaxParts))
check(#specs<=Art.Budget.MaxParts,'part budget')
local kinds=setmetatable({},{__index=function(_,k)local n=0;for _,s in ipairs(specs)do if s.Name:sub(1,#k)==k then n+=1 end end;return n end})
for _,k in ipairs({'VoidNebula','GalaxyArm','VoidSingularity','PhotonRing','AccretionDisc','VoidPupil','VoidIris','StarV','StarSpeck','RuneSigil','EventHorizon','HaloDebris'})do
 check((kinds[k]or 0)>0,'design element present: '..k)
end
local spin,pulse=0,0;for _,s in ipairs(specs)do if s.Spin then spin+=1 end;if s.Pulse then pulse+=1 end end
check(spin>0 and pulse>0,'motion hints: '..spin..' spinning, '..pulse..' pulsing parts')
-- Bounds hold every part (including spin sweeps) at several sizes.
local function inside(bag,b,label)
 local root=bag.PrimaryPart.CFrame;local worst=0
 for _,p in ipairs(parts(bag))do
  local frame=root:Inverse()*p.CFrame;local h=p.Size*.5
  for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
   local q=frame*V3(h.X*x,h.Y*y,h.Z*z);local r=math.sqrt(q.X*q.X+q.Z*q.Z)
   worst=math.max(worst,r-b.Radius,q.Y-b.MaxY,b.MinY-q.Y,q.Z-b.MaxZ,b.MinZ-q.Z)
  end end end
 end
 return check(worst<=1e-3,label..': all parts inside Bounds (worst overshoot '..string.format('%.4f',worst)..')')
end
local function noUploads(bag,label)
 local bad=0
 for _,d in ipairs(bag:GetDescendants())do
  for _,k in ipairs({'TextureID','Texture','Image'})do local v=d._props[k];if type(v)=='string'and v:find('rbxassetid')then bad+=1 end end
 end
 check(bad==0,label..': no uploaded asset ids')
end
-- World pack (also the dropped-pack path: ChestService:BuildSeedPacket -> Visuals.Bag, anchored).
for _,case in ipairs({{1,'None'},{2.5,'Gold'},{25,'Diamond'},{.5,'None'}})do
 local size,coat=case[1],case[2];local label=('world %sx %s'):format(size,coat)
 local bag=Visuals.Bag(CF(0,10,0),W.workspace,1,nil,7,'EclipseReliquary',1,size,coat)
 check(bag:GetAttribute('VoidDesignRevision')==122 and bag:GetAttribute('EclipsePack'),label..': new design built')
 check(named(bag)==#specs,label..': every design part present ('..named(bag)..')')
 local anchored=true;for _,p in ipairs(parts(bag))do if not p.Anchored then anchored=false end end;check(anchored,label..': world parts anchored')
 inside(bag,Visuals.Bounds(7,'EclipseReliquary',size),label);noUploads(bag,label)
 if coat~='None'then local ok=true;for _,p in ipairs(parts(bag))do if p.Color~=Rules.PackMutations[coat].Color then ok=false end end;check(ok,label..': coat applied to the whole pack')end
 bag:Destroy()
end
-- Carried / held (welded to the character) and the opening copy made from it.
local char=R.new('Model');char.Name='Carrier';char.Parent=W.workspace
local torso=R.new('Part');torso.Name='UpperTorso';torso.Size=V3(2,2,1);torso.CFrame=CF(0,5,0);torso.Anchored=false;torso.Parent=char
local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.Size=V3(2,2,1);hrp.CFrame=CF(0,4,0);hrp.Parent=char
local held=Visuals.Bag(CF(0,5,1),char,1,torso,7,'EclipseReliquary',1,1,'None')
local welded=true;for _,p in ipairs(parts(held))do if p.Anchored or not p:FindFirstChildOfClass('WeldConstraint')then welded=false end end
check(welded and named(held)==#specs,'carried: every part welded to the carrier')
local ok,carry=pcall(Visuals.CarryBag,char,7,'EclipseReliquary',1,1,'None')
check(ok and carry and named(carry)==#specs and carry.Name=='CarriedSeed','CarryBag (carried pack) builds the full design: '..tostring(carry))
if ok and carry then local b=Visuals.Bounds(7,'EclipseReliquary',1);check(carry:GetAttribute('CarryBackZ')~=nil,'carry layout used the new bounds (MaxZ '..string.format('%.2f',b.MaxZ)..')');carry:Destroy()end
local copy=held:Clone();copy.Name='OpeningBag'
for _,d in ipairs(copy:GetDescendants())do if d:IsA('WeldConstraint')then d:Destroy()elseif d:IsA('BasePart')then d.Anchored=true end end
check(named(copy)==#specs,'opening copy keeps the full design')
-- Inventory picture / index (ItemPictures builds exactly this) and a viewport preview (WorldModel parent).
local Pictures=W.module('ItemPictures')
local tool=F.pack(W,W.workspace,7,'EclipseReliquary',1,'None','Void Pack')
check(Pictures.Key(tool)=='Pack|7|EclipseReliquary|None','inventory picture key for the Void Pack')
local picture=Visuals.Bag(CFrame.Angles(0,.22,-.025),nil,1,nil,7,'EclipseReliquary',1,1,'None')
check(named(picture)==#specs and picture.Parent==nil,'inventory picture template builds unparented')
local view=R.new('ViewportFrame');local wm=R.new('WorldModel');wm.Parent=view
local preview=Visuals.Bag(CFrame.Angles(0,.22,-.025),wm,1,nil,7,'EclipseReliquary',1,1,'None')
check(named(preview)==#specs,'viewport preview builds')
-- Client FX module: capture, tiers, reduced motion.
local bag=Visuals.Bag(CF(0,10,40),W.workspace,1,nil,7,'EclipseReliquary',1,1,'None')
local cap=PackFx.Capture(bag)
check(cap and cap.Spinners==spin and #cap.Pulsers==pulse,'capture finds the motion hints')
for tier=1,3 do
 local fx=PackFx.Create(cap,tier)
 check(#fx.Debris==PackFx.Budget.Debris[tier]and #fx.Comets==PackFx.Budget.Comets[tier],'tier '..tier..' debris/comets within budget')
 local textures=true;for _,e in ipairs({fx.Haze,fx.Nebula,fx.Stars})do if not e.Texture:match('^rbxasset://textures/')then textures=false end end
 check(textures,'tier '..tier..' only built-in particle textures')
 local list,frames={},{}
 PackFx.Step(cap,10,bag.PrimaryPart.CFrame,tier,false,true,list,frames)
 check(fx.Light.Enabled==(tier==3),'tier '..tier..' light only at full quality')
 check(fx.Nebula.Enabled==(tier>1)and fx.Stars.Enabled==(tier==3),'tier '..tier..' emitters gated')
 local a,b={},{};local la,lb={},{}
 PackFx.Step(cap,3,bag.PrimaryPart.CFrame,tier,true,false,la,a);PackFx.Step(cap,7,bag.PrimaryPart.CFrame,tier,true,false,lb,b)
 local still=true;for i=1,#a do if a[i].Position~=b[i].Position then still=false end end
 check(still and not fx.Nebula.Enabled,'tier '..tier..' Reduced Motion: orbits frozen, no swirl')
 PackFx.Pulse(cap,1.234,false);PackFx.Clear(cap)
 local restored=true;for _,e in ipairs(cap.Pulsers)do if e.Part.Color~=e.Color then restored=false end end
 check(restored and fx.Folder.Parent==nil,'tier '..tier..' clear destroys effects and restores colours')
end
do
 local a,b={},{};local pa,pb={},{}
 PackFx.Pose(cap,2,pa,a,true);PackFx.Pose(cap,2,pb,b,false)
 local moved=0;for i,p in ipairs(pa)do if p:GetAttribute('VoidSpin')and a[i].Position~=b[i].Position then moved+=1 end end
 check(moved>0,'galaxy / halo spin near the camera ('..moved..' parts)')
 local c,d={},{};PackFx.Pose(cap,2,{},c,false);PackFx.Pose(cap,9,{},d,false)
 local same=0;for i=1,#c do if pa[i]:GetAttribute('VoidSpin')and(c[i].Position-d[i].Position).Magnitude<.5 then same+=1 end end
 check(same==spin,'no spin when far / reduced (only the shared hover moves)')
end
bag:Destroy()
-- The real client loop: effect budget per tier, FastMode, effects-off, distance culling, single light.
local Players=W.service('Players');local player=R.new('Player');player.Name='Me';player.Parent=Players;Players.LocalPlayer=player
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local remote=R.new('RemoteEvent');remote.Name='VeiledArrival81';remote._props.OnClientEvent=R.signal();remote.Parent=remotes
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
W.stub('NoticeFeed83',{Push=function()end})
W.stub('VeiledArrivalFx',{Preload=function()end,Arrive=function()end,Stop=function()end})
local cam=W.workspace.CurrentCamera;cam.CFrame=CF(0,10,0)
local bags={}
for i,d in ipairs({10,20,30,45,60,90,140,200,400})do bags[i]=Visuals.Bag(CF(d,10,0),W.workspace,1,nil,7,'EclipseReliquary',1,1,'None')end
local sc=R.new('LocalScript');sc.Name='VeiledEventClient81';W.load('VeiledEventClient81',sc)
local function fxCount()local n,lights=0,0
 for _,f in ipairs(W.workspace:GetChildren())do if f.Name=='_VoidPackFx122'then n+=1
  local core=f:FindFirstChild('VoidFxCore');local l=core and core:FindFirstChild('VoidPulseLight');if l and l.Enabled then lights+=1 end end end
 return n,lights end
W.frames(20,1/30)
local n,lights=fxCount();check(n==PackFx.Budget.Bags[3]and lights==1,'full quality: '..n..' packs with effects (budget '..PackFx.Budget.Bags[3]..'), '..lights..' light')
for _,f in ipairs(W.workspace:GetChildren())do if f.Name=='_VoidPackFx122'then
 local core=f.VoidFxCore;check(core.CFrame.Position.X<160,'no effects beyond 160 studs')end end
player:SetAttribute('FastMode',true);W.frames(20,1/30)
n,lights=fxCount();check(n==1 and lights==0,'FastMode: one pack, no light ('..n..')')
player:SetAttribute('FastMode',nil);player:SetAttribute('StudioPlantEffects','off');W.frames(20,1/30)
n=fxCount();check(n==0,'effects off: none')
player:SetAttribute('StudioPlantEffects',nil);W.Gui.ReducedMotionEnabled=true;W.frames(20,1/30)
n=fxCount();check(n==PackFx.Budget.Bags[3],'Reduced Motion keeps static effects')
for _,b in ipairs(bags)do b:Destroy()end;held:Destroy();W.frames(5,1/30)
n=fxCount();check(n==0,'destroyed packs release their effects')
sc.Destroying:Fire()
print(('art checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
