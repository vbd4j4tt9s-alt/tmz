--!nocheck
-- R153 (owner: "make it so that speed needed thing is dislocated from the keeper and is way above the keepers head"; then "for the secret
-- keeper just put the inf speed like above him really high up but stays at his spawn point so when he chases the player it doesnt follow
-- the keeper, for other keepers adopt this same thing"): the REAL KeeperSpeedLabels on the Roblox mock, with keepers built from the REAL
-- rev 6 data (KeeperRigConfig152: every part, size and rest frame of the 7 biome keepers and The Darkened, VeiledKeeper81's real pose code):
--  1. every keeper whose body appears late / is swapped (a small model first, then the baked one) / streams in part by part ends with the
--     sign >= 15 studs above the top of its body at rest (checked against the real mesh bounds, not the script's own formula)
--  2. effect parts (the colossus's surge arcs, KeeperFx parts, KeeperFxKind parts, invisible hitboxes, an oversized root) never raise it
--  3. the sign hangs on its own invisible anchored part at the spawn point and never follows the keeper (moves, chases, poses, wakes up)
--  4. The Darkened: placed at its spawn for that appearance, taller than it ever stands, removed when it despawns, a new place next time
--  5. measuring is debounced, stops once the model is quiet, comes back for a swap, writes only on change, and there is no per-frame work
--  6. clean-up: no anchor is ever leaked
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local V,CF=R.Vector3.new,R.CFrame.new
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=77;player.Parent=Players;Players.LocalPlayer=player
local workspace=W.workspace;local CS=W.CS;local Run=W.service('RunService')
R.clock=20000*86400+3600
local function adv(seconds)for _=1,math.floor(seconds/.25+.5)do R.advance(.25)end end
local Cfg=W.module('KeeperRigConfig152');local K=W.module('VeiledKeeper81')
local LIFT_MIN=15 -- the owner's / coordinator's floor: the sign at least this far above the resting top of the body
-- (the mock's CollectionService does not fire InstanceRemoved on Destroy, Roblox does: a despawn is both)
local function despawn(m)CS:RemoveTag(m,'BiomeKeeper');m:Destroy()end

-- 0. No per-frame connection: what the frame signals hold before the script, and after everything below --------------------------------
local function live(sig)local n=0;for _,c in ipairs(sig._c)do if c.Connected then n+=1 end end;return n end
local FRAME={'RenderStepped','Heartbeat','Stepped','PreSimulation','PostSimulation'}
local frameBase={};for _,k in ipairs(FRAME)do frameBase[k]=live(Run[k])end
local boundBase=0;for _ in pairs(W.rsBound)do boundBase+=1 end
local ks=R.new('LocalScript');ks.Name='KeeperSpeedLabels'
local okK,errK=pcall(W.load,'KeeperSpeedLabels',ks);check(okK,'KeeperSpeedLabels loads: '..tostring(errK))
local function frameClean()
 for _,k in ipairs(FRAME)do if live(Run[k])~=frameBase[k]then return false,k end end
 local n=0;for _ in pairs(W.rsBound)do n+=1 end
 return n==boundBase
end
check(frameClean(),'loading the script connects nothing to RenderStepped / Heartbeat / Stepped / PreSimulation / PostSimulation and binds no render step')

-- helpers ---------------------------------------------------------------------------------------------------------------------------------
local function signOf(m)
 local f=workspace:FindFirstChild('KeeperSignAnchors');if not f then return nil end
 for _,a in ipairs(f:GetChildren())do local link=a:FindFirstChild('Keeper');if link and link.Value==m then return a:FindFirstChild('SpeedReq'),a end end
 return nil
end
local function anchorCount()local f=workspace:FindFirstChild('KeeperSignAnchors');return f and #f:GetChildren()or 0 end
-- the sign's centre in the world
local function signPos(m)local gui,a=signOf(m);if not gui then return nil end;return a.Position+gui.StudsOffsetWorldSpace end
local function signY(m)local p=signPos(m);return p and p.Y or -math.huge end -- (-inf: no sign, every height check fails instead of crashing)
local function newKeeper(name,home,fields)
 local m=R.new('Model');m.Name=name
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V(2,2,1);root.CFrame=CF(home.X,home.Y,home.Z);root.Parent=m;m.PrimaryPart=root
 m:SetAttribute('KeeperEscapeSpeed',100)
 if fields~='nohome'then m:SetAttribute('KeeperHome',home)end
 m.Parent=workspace;CS:AddTag(m,'BiomeKeeper');return m,root
end
local function halfY(cf,size)return(math.abs(cf.RightVector.Y)*size.X+math.abs(cf.UpVector.Y)*size.Y+math.abs(cf.LookVector.Y)*size.Z)/2 end
-- Roblox fires DescendantAdded / DescendantRemoving on the model for EVERY descendant of a subtree that is parented / removed; the mock only
-- fires them for the instance itself, so a rig that is built first and parented in one go is announced here the way Roblox does it.
local function attach(m,rig)rig.Parent=m;for _,d in ipairs(rig:GetDescendants())do m.DescendantAdded:Fire(d)end;return rig end
local function drop(m,inst)for _,d in ipairs(inst:GetDescendants())do m.DescendantRemoving:Fire(d)end;m.DescendantRemoving:Fire(inst);inst:Destroy()end
-- Today's smaller keeper (before the baked model is swapped in): one body piece, `height` tall, rest top = height - 4 over the root.
local function addLegacy(m,root,height)
 local rig=R.new('Model');rig.Name='BeastBody';rig:SetAttribute('KeeperMeshVariant','Legacy')
 local p=R.new('Part');p.Name='Body';p.Size=V(4,height,3);local rest=CF(0,height/2-4,0);p:SetAttribute('RestCFrame',rest);p.CFrame=root.CFrame*rest;p.Parent=rig
 return attach(m,rig)
end
-- The baked rev 6 rig, built the way KeeperMeshes152.BuildRig + BeastModels.place do (rest frames as attributes, the golem placed in its tree form).
local function rigPart(s,root)
 local p=R.new('MeshPart');p.Name=s.Name;p.Size=V(s.Size[1],s.Size[2],s.Size[3]);local rest=CF(s.Center[1],s.Center[2],s.Center[3])
 p:SetAttribute('RestCFrame',rest);p:SetAttribute('BeastGroup',s.Group);p:SetAttribute('KeeperMeshKind',s.Kind)
 local tree=s.TreeRest and CF(table.unpack(s.TreeRest))
 if tree then p:SetAttribute('TreeRestCFrame',tree);p:SetAttribute('TreeRestSize',V(table.unpack(s.TreeSize)))end
 p.CFrame=root.CFrame*(tree or rest);return p
end
local function addRig(m,root,stage,only)
 local rig=R.new('Model');rig.Name='BeastBody';rig:SetAttribute('VisualVersion',152);rig:SetAttribute('KeeperMeshVariant','R152')
 for _,s in ipairs(Cfg.Stages[stage].Parts)do if not only or only[s.Name]then rigPart(s,root).Parent=rig end end
 return attach(m,rig)
end
-- The real mesh bounds of the stage (Blender's, from the config): the top of the body at rest, over the root.
local function boundsTop(stage)
 local top=-math.huge;for _,b in pairs(Cfg.Stages[stage].Bounds)do top=math.max(top,b[2][2])end
 return top
end
local function allParts(m,fn)for _,d in ipairs(m:GetDescendants())do if d:IsA('BasePart')then fn(d)end end end
local function moveAll(m,delta)allParts(m,function(p)p.CFrame=CF(delta.X,delta.Y,delta.Z)*p.CFrame end)end

-- 1. Every biome keeper: a small model first, then the baked one, then streamed in part by part ------------------------------------------
local ORDER={1,6,2,3,4,5,7}
local sizesOk,propsOk,effOk=true,true,true
for i,stage in ipairs(ORDER)do
 local name=Cfg.Stages[stage].Name
 local home=V(i%2==0 and 70 or -70,8+i,300*i)
 local m,root=newKeeper(name,home)
 check(signOf(m)==nil and anchorCount()==0,'['..name..'] tagged with no body yet: no sign, no anchor')
 local legacy=addLegacy(m,root,12);adv(1)
 local gui,anchor=signOf(m)
 check(gui~=nil and near(signY(m),home.Y+8+18,1e-6),'['..name..'] today\'s small model (top 8 over the root): the sign is 18 over it ('..tostring(gui and signY(m))..')')
 -- the bake finished: the old body goes, the baked one comes (what BeastModels.Swap does)
 drop(m,legacy);local rig=addRig(m,root,stage)
 local top=boundsTop(stage)
 local before=signY(m)
 check(near(before,home.Y+8+18,1e-6),'['..name..'] (the swap itself writes nothing: the sign waits for the debounce)')
 adv(1)
 local y=signY(m);local above=y-(home.Y+top)
 check(above>=LIFT_MIN and above<=LIFT_MIN+12,'['..name..'] after the swap the sign is '..string.format('%.1f',above)..' studs above the real top of the body ('..string.format('%.1f',top)..' over the root), between '..LIFT_MIN..' and '..(LIFT_MIN+12))
 sizesOk=sizesOk and gui~=nil and gui.Size.X.Offset==104 and gui.Size.Y.Offset==36 and gui.Size.X.Scale==0 and gui.Size.Y.Scale==0
 propsOk=propsOk and gui~=nil and anchor.Anchored==true and anchor.CanCollide==false and anchor.CanTouch==false and anchor.CanQuery==false and anchor.Transparency==1 and not anchor:IsDescendantOf(m)
  and gui.Adornee==anchor and gui.Parent==anchor and gui.AlwaysOnTop==false and gui.MaxDistance>=200 and near(gui.StudsOffsetWorldSpace.X,0)and near(gui.StudsOffsetWorldSpace.Z,0)
  and near(anchor.Position.X,home.X)and near(anchor.Position.Y,home.Y)and near(anchor.Position.Z,home.Z)
 -- effects arrive while it is still watched: nothing raises it
 local fold=R.new('Folder');fold.Name='ColossusSurges';fold.Parent=m
 for k=1,4 do local s=R.new('Part');s.Name='Electrical surge';s.Size=V(.13,.13,3);s.CFrame=root.CFrame*CF(k,top+60,0);s.Parent=fold end
 local bolt=R.new('Part');bolt.Name='KeeperFxBolt';bolt.Size=V(.5,24,.5);bolt.CFrame=root.CFrame*CF(0,top+80,0);bolt.Parent=m
 local flame=R.new('Part');flame.Name='Flame';flame:SetAttribute('KeeperFxKind','Flame');flame.Size=V(2,2,2);flame.CFrame=root.CFrame*CF(0,top+90,0);flame.Parent=rig
 local ghost=R.new('Part');ghost.Name='Hitbox';ghost.Transparency=1;ghost.Size=V(8,200,8);ghost.CFrame=root.CFrame*CF(0,100,0);ghost.Parent=m
 root.Size=V(14,260,14) -- an oversized root / hitbox
 adv(1)
 effOk=effOk and near(signY(m),y,1e-6)
 -- quiet: it stops listening
 adv(6)
 local watching=live(m.DescendantAdded)+live(m.DescendantRemoving)
 check(watching==0,'['..name..'] quiet for 5 s: the script no longer listens to the model ('..watching..' connections left)')
 -- it chases: the keeper runs far away, jumps, its parts pose; the sign does not move
 moveAll(m,V(-300,0,900));root.CFrame=CF(-380,40,1200)
 allParts(rig,function(p)p.CFrame=p.CFrame*CF(0,12,0)end)
 adv(3)
 local g2,a2=signOf(m)
 check(g2==gui and a2==anchor and near(a2.Position.X,home.X)and near(a2.Position.Y,home.Y)and near(a2.Position.Z,home.Z)and near(signY(m),y,1e-6),'['..name..'] chasing a runner 900 studs away: the sign stays at its spawn point, same height')
 despawn(m)
end
check(sizesOk,'[size] all 7 biome keepers: the sign is the same fixed 104x36 pixels (R148)')
check(propsOk,'all 7 biome keepers: the sign hangs on an anchored, invisible, non-colliding, non-touch, non-query part at the keeper\'s spawn point (not on the keeper, not AlwaysOnTop, range >= 200), centred over it')
check(effOk,'surge arcs, KeeperFx parts, a KeeperFxKind part, an invisible hitbox and an oversized root never raise the sign (7 keepers)')
check(anchorCount()==0,'all 7 keepers despawned: no anchor is left behind')

-- 2. Parts that stream in one by one: the sign follows the body up, never lags more than one debounce -----------------------------------
do
 local stage=7;local home=V(64,18,1992);local m,root=newKeeper('StreamingColossus',home)
 local cloud={Head_Cloud=true,Head_Glow_Cloud=true}
 local without={};for _,s in ipairs(Cfg.Stages[stage].Parts)do if not cloud[s.Name]then without[s.Name]=true end end
 local rig=addRig(m,root,stage,without);adv(1)
 local noCloudTop=0;for _,s in ipairs(Cfg.Stages[stage].Parts)do if without[s.Name]then noCloudTop=math.max(noCloudTop,s.Center[2]+s.Size[2]/2)end end
 check(near(signY(m),home.Y+noCloudTop+18,.3),'[streaming] the colossus without its cloud crown yet: the sign is 18 over the head ('..string.format('%.1f',signY(m)-home.Y)..' over the root)')
 for _,s in ipairs(Cfg.Stages[stage].Parts)do if cloud[s.Name]then rigPart(s,root).Parent=rig end end
 adv(1)
 check(signY(m)-(home.Y+boundsTop(stage))>=LIFT_MIN,'[streaming] the cloud crown streams in late: the sign rises over it, '..string.format('%.1f',signY(m)-(home.Y+boundsTop(stage)))..' above the top of the mesh')
 despawn(m)
end

-- 3. A model without rig attributes (a placeholder / unknown build): its visible parts count, the hitbox and the effects do not -----------
do
 local home=V(-70,8,100);local m,root=newKeeper('PlainKeeper',home)
 local body=R.new('Part');body.Name='Body';body.Size=V(4,10,2);body.CFrame=root.CFrame*CF(0,4,0);body.Parent=m
 local surge=R.new('Part');surge.Name='Electrical surge';surge.CFrame=root.CFrame*CF(0,70,0);surge.Parent=R.new('Folder')
 surge.Parent.Name='ColossusSurges';surge.Parent.Parent=m
 local fx=R.new('Part');fx.Name='KeeperFxSpark';fx.CFrame=root.CFrame*CF(0,90,0);fx.Parent=m
 local hit=R.new('Part');hit.Name='Hitbox';hit.Transparency=1;hit.Size=V(10,150,10);hit.CFrame=root.CFrame*CF(0,70,0);hit.Parent=m
 adv(1)
 check(near(signY(m),home.Y+9+18,1e-6),'a keeper with no rig attributes: the sign is 18 over its visible body (top 9), not over the surge arcs, KeeperFx parts or the hitbox ('..tostring(signPos(m)and signY(m))..')')
 despawn(m)
end

-- 4. The server has not stamped KeeperHome (yet): the keeper is pinned where it was first seen, then moves once to the real spawn --------
do
 local first=V(30,9,640);local m,root=newKeeper('UnstampedKeeper',first,'nohome');addLegacy(m,root,12);adv(1)
 local gui,anchor=signOf(m)
 check(gui~=nil and near(anchor.Position.X,30)and near(anchor.Position.Z,640),'no KeeperHome yet: the sign waits where the keeper was first seen')
 moveAll(m,V(0,0,200));root.CFrame=CF(30,9,840);adv(2)
 check(near(anchor.Position.Z,640),'(and does not follow it)')
 m:SetAttribute('KeeperHome',V(30,9,600));adv(.5)
 check(near(anchor.Position.Z,600)and signOf(m)==gui and near(signY(m),9+8+18,1e-6),'the server stamps KeeperHome: the sign moves once to the real spawn point')
 despawn(m)
end

-- 5. Debounce: one measurement for a burst, at most 2 a second for a stream, silence when nothing changes -----------------------------------
do
 local home=V(-70,8,2300);local m,root=newKeeper('DebounceKeeper',home);addLegacy(m,root,12);adv(1)
 local gui=signOf(m);local writes=0
 gui.Changed:Connect(function(k)if k=='StudsOffsetWorldSpace'then writes+=1 end end)
 local rig=R.new('Model');rig.Name='BeastBody';rig.Parent=m
 for k=1,40 do local p=R.new('Part');p.Name='P'..k;p.Size=V(2,2,2);local rest=CF(0,k,0);p:SetAttribute('RestCFrame',rest);p.CFrame=root.CFrame*rest;p.Parent=rig end
 adv(2)
 check(writes==1 and near(signY(m),home.Y+40+1+18,1e-6),'40 parts in one go: measured once (1 write of the offset), sign at the tallest ('..writes..' writes)')
 local stamps={}
 gui.Changed:Connect(function(k)if k=='StudsOffsetWorldSpace'then stamps[#stamps+1]=R.clock end end)
 for k=41,60 do local p=R.new('Part');p.Name='P'..k;p.Size=V(2,2,2);local rest=CF(0,k,0);p:SetAttribute('RestCFrame',rest);p.CFrame=root.CFrame*rest;p.Parent=rig;adv(.25)end
 adv(1)
 local gap=math.huge;for i=2,#stamps do gap=math.min(gap,stamps[i]-stamps[i-1])end
 check(#stamps>=2 and #stamps<=11 and gap>=.49 and near(signY(m),home.Y+60+1+18,1e-6),'20 parts, one every 0.25 s (5 s): never more than 2 measurements a second ('..#stamps..' writes, at least '..string.format('%.2f',gap)..' s apart), ends at the top ('..string.format('%.1f',signY(m)-home.Y)..')')
 -- nothing changes: nothing is written (to the sign, to the anchor)
 local _,anchor=signOf(m);local silent=0
 gui.Changed:Connect(function()silent+=1 end);anchor.Changed:Connect(function()silent+=1 end)
 adv(60)
 check(silent==0,'60 s with nothing changing: no property of the sign or its anchor is written ('..silent..')')
 -- the swap to the baked model: KeeperMeshVariant changes after the quiet time, the model is watched again
 check(live(m.DescendantAdded)==0,'(it had stopped listening)')
 m:SetAttribute('KeeperMeshVariant','R152')
 check(live(m.DescendantAdded)==1 and live(m.DescendantRemoving)==1,'KeeperMeshVariant changing (the baked model arrives) makes it listen again')
 drop(m,rig);local big=R.new('Model');big.Name='BeastBody';big.Parent=m
 local p=R.new('Part');p.Name='Big';p.Size=V(2,2,2);local rest=CF(0,30,0);p:SetAttribute('RestCFrame',rest);p.CFrame=root.CFrame*rest;p.Parent=big
 adv(1)
 check(near(signY(m),home.Y+31+18,1e-6),'and measures the new body ('..string.format('%.1f',signY(m)-home.Y)..')')
 -- parts leaving count too (Roblox fires DescendantRemoving before the part goes; the mock does not fire it by itself)
 local tallRest=CF(0,60,0);local tall=R.new('Part');tall.Name='Tall';tall.Size=V(2,2,2);tall:SetAttribute('RestCFrame',tallRest);tall.CFrame=root.CFrame*tallRest;tall.Parent=big;adv(1)
 check(near(signY(m),home.Y+61+18,1e-6),'a tall part streams in: the sign rises')
 m.DescendantRemoving:Fire(tall);tall.Parent=nil;adv(1)
 check(near(signY(m),home.Y+31+18,1e-6),'the part streams out (DescendantRemoving): the sign comes back down ('..string.format('%.1f',signY(m)-home.Y)..')')
 adv(6)
 check(live(m.DescendantAdded)==0,'then goes quiet again')
 despawn(m)
 -- removed before the debounce fires: no error, nothing left
 local m2,r2=newKeeper('Fleeting',V(0,8,2600));addLegacy(m2,r2,12);adv(1)
 local extra=R.new('Part');extra.Name='Late';extra:SetAttribute('RestCFrame',CF(0,5,0));extra.Parent=m2
 despawn(m2);adv(3)
 check(anchorCount()==0,'a keeper removed with a measurement pending: no error, no anchor left')
end

-- 6. The Darkened (the secret keeper): real rev 6 pieces, real VeiledKeeper81 poses -------------------------------------------------------
local function veiledTop(m,root)local top=-math.huge;allParts(m,function(p)if p~=root then top=math.max(top,p.Position.Y-root.Position.Y+halfY(p.CFrame,p.Size))end end);return top end
local function veiledRig(home,parts)
 local m=R.new('Model');m.Name='TheVeiledOne';m:SetAttribute('KeeperClientAnimated',true);m:SetAttribute('VeiledKeeper81',true);m:SetAttribute('GuardianBehavior','GUARDING');m:SetAttribute('Stage',7)
 local root=R.new('Part');root.Name='VeiledRoot';root.Size=V(2,2,2);root.Transparency=1;root.Anchored=true;root.CFrame=CF(home.X,home.Y,home.Z);root.Parent=m;m.PrimaryPart=root
 for _,s in ipairs(parts)do
  local p=R.new('MeshPart');p.Name=s.Name;p.Size=V(s.Size[1],s.Size[2],s.Size[3]);p:SetAttribute('VeiledGroup',s.Group);p:SetAttribute('VeiledFrame',CF(s.Center[1],s.Center[2],s.Center[3]));p.Parent=m
 end
 return m,root
end
do
 -- How tall it really stands: the real pose code, every awake state, many phases (never below what the sign must clear)
 local probe,pr=veiledRig(V(0,0,0),Cfg.Stages[0].Parts);probe.Parent=workspace
 local standing,asleep=-math.huge,-math.huge
 for _,st in ipairs({'ALERT','CHASING','RETURNING','DASHING'})do
  probe:SetAttribute('GuardianBehavior',st);probe:SetAttribute('VeiledAwakeAt',0)
  for t=0,24,.1 do K.Apply(probe,200+t);standing=math.max(standing,veiledTop(probe,pr))end
 end
 probe:SetAttribute('GuardianBehavior','GUARDING');K.Apply(probe,200);asleep=veiledTop(probe,pr)
 probe:Destroy()
 check(standing>12 and standing<14 and asleep<6,'(the real Darkened: standing top '..string.format('%.2f',standing)..' over its root, asleep '..string.format('%.2f',asleep)..': asleep it lies low, so the sign must not use that)')
 -- appears asleep at P1, wakes, chases, despawns, comes back at P2
 local P1=V(60,13,1970)
 local m,root=veiledRig(P1,Cfg.Stages[0].Parts);m:SetAttribute('KeeperEscapeSpeed',600);m:SetAttribute('KeeperHome',P1);m:SetAttribute('KeeperMeshVariant','R152')
 m.Parent=workspace;K.Apply(m,R.clock);CS:AddTag(m,'BiomeKeeper');adv(1)
 local gui,anchor=signOf(m)
 check(gui~=nil and gui.Pill.Value.Text=='⚡ ∞'and gui.Enabled==true,'The Darkened: its sign shows ⚡ ∞ ('..tostring(gui and gui.Pill.Value.Text)..')')
 check(near(anchor.Position.X,P1.X)and near(anchor.Position.Y,P1.Y)and near(anchor.Position.Z,P1.Z),'The Darkened\'s sign is pinned at its spawn point')
 check(signY(m)-(P1.Y+standing)>=LIFT_MIN,'it is '..string.format('%.1f',signY(m)-(P1.Y+standing))..' studs over the head even when The Darkened stands up (it spawns asleep: lying, 4 studs high)')
 local yRest=signY(m)
 m:SetAttribute('GuardianBehavior','CHASING');m:SetAttribute('VeiledAwakeAt',0)
 local maxDrift=0
 for step=0,40 do
  local t=R.clock+step*.5;root.CFrame=CF(P1.X-step*8,P1.Y,P1.Z-step*30);K.Apply(m,t)
  R.advance(.5)
  maxDrift=math.max(maxDrift,(anchor.Position-V(P1.X,P1.Y,P1.Z)).Magnitude,math.abs(signY(m)-yRest))
 end
 check(maxDrift==0,'it wakes and chases a player 1200 studs away: the sign does not move at all (drift '..maxDrift..')')
 check(signOf(m)==gui and anchorCount()==1,'(one sign, one anchor)')
 despawn(m);adv(1)
 check(anchorCount()==0 and anchor.Parent==nil and gui.Parent==nil,'The Darkened despawns: its sign and its anchor are removed')
 local P2=V(-55,13,1930)
 local m2,root2=veiledRig(P2,Cfg.Stages[0].Parts);m2:SetAttribute('KeeperEscapeSpeed',600);m2:SetAttribute('KeeperHome',P2)
 m2.Parent=workspace;K.Apply(m2,R.clock);CS:AddTag(m2,'BiomeKeeper');adv(1)
 local g2,a2=signOf(m2)
 check(g2~=nil and g2~=gui and near(a2.Position.X,P2.X)and near(a2.Position.Z,P2.Z)and anchorCount()==1,'its next appearance at another spawn point: a new sign pinned there ('..tostring(a2 and a2.Position)..')')
 despawn(m2)
 -- today's Darkened (blocks): the real builder, the real pose
 local P3=V(10,13,1900);local folder=R.new('Folder');folder.Parent=workspace
 local legacy=K.Build(CF(P3.X,P3.Y,P3.Z),folder,nil)
 legacy:SetAttribute('KeeperEscapeSpeed',600);legacy:SetAttribute('KeeperHome',P3);CS:AddTag(legacy,'BiomeKeeper');adv(1)
 local lroot=legacy.PrimaryPart
 legacy:SetAttribute('GuardianBehavior','CHASING');legacy:SetAttribute('VeiledAwakeAt',0)
 local lstand=-math.huge;for t=0,24,.1 do K.Apply(legacy,300+t);lstand=math.max(lstand,veiledTop(legacy,lroot))end
 check(signOf(legacy)~=nil and signY(legacy)-(P3.Y+lstand)>=LIFT_MIN,'today\'s block Darkened: the sign is '..string.format('%.1f',signPos(legacy)and signY(legacy)-(P3.Y+lstand)or -1)..' studs over its standing head ('..string.format('%.1f',lstand)..')')
 despawn(legacy);folder:Destroy()
end

-- 7. Clean-up and per-frame work ---------------------------------------------------------------------------------------------------------
check(anchorCount()==0,'every keeper gone: no anchor part is left in the world')
local live1=newKeeper('Last',V(0,8,5000));local lroot1=live1.PrimaryPart;addLegacy(live1,lroot1,12);adv(1)
check(anchorCount()==1,'(one more keeper, one anchor)')
ks.Destroying:Fire()
check(workspace:FindFirstChild('KeeperSignAnchors')==nil and signOf(live1)==nil,'the script is removed: every sign and the anchors folder go with it')
check(frameClean(),'after all of this (keepers, swaps, chases, streams, despawns) the script still holds no per-frame connection and no render step')
adv(10)

print(('R153 keeper label: %d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
