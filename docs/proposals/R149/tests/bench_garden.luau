--!nocheck
-- R149 growth style: property writes of the REAL client scheduler (GardenVisuals) on one growing plant, before and after. run_growth.sh runs this file twice, on
-- the BASE commit's modules and on this checkout's, and prints the two side by side (BENCH lines). One plant at 50 % of its growth, standing near the camera
-- for 5 s of 60 fps frames (the scheduler's animation step is 20 Hz): every property write on a part (Size, CFrame, Transparency, Color, Material, CanQuery,
-- CanCollide) is counted, and the CFrames that go through the PlantAnimationBatch / BulkMoveTo are counted as moves. `sway` = the player's reduced-motion
-- setting off (growing plants sway after the change); `still` = reduced motion on (the pure effect of "write only what moved").
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
do local mt=getmetatable(R.Color3.new(0,0,0));mt.__eq=function(a,b)return a.R==b.R and a.G==b.G and a.B==b.B end end
local counting,writes,moves=false,0,0
local rawNewindex=R.instMeta.__newindex
local partClass={Part=true,MeshPart=true,WedgePart=true,CornerWedgePart=true}
local counted={Size=true,CFrame=true,Transparency=true,Color=true,Material=true,CanQuery=true,CanCollide=true}
R.instMeta.__newindex=function(o,k,v)
 if counting and counted[k]and partClass[o._class]then writes+=1 end
 return rawNewindex(o,k,v)
end
W.workspace.BulkMoveTo=function(_,parts,frames)if counting then moves+=#parts end;for i,p in ipairs(parts)do rawNewindex(p,'CFrame',frames[i])end end
local Meshes=W.module('ApprovedPlantMeshes')
Meshes.Get=function(key)return {Clone=function()local p=R.new('Part');p:SetAttribute('ApprovedMesh',key);return p end}end
Meshes.Status=function()return 'Ready'end
local Catalog=W.module('PlantCatalog')
local Players=W.service('Players');local Gui=W.service('GuiService')
local me=R.new('Player');me.Name='Tester';me.UserId=5;me.Parent=Players;Players.LocalPlayer=me
Players.GetPlayerByUserId=function(_,id)return id==5 and me or nil end
me:SetAttribute('ChestChaseCommandsAllowed',true)
local camera=W.workspace.CurrentCamera;camera.CFrame=R.CFrame.lookAt(V3(0,12,-30),V3(0,4,0))
function camera.WorldToViewportPoint(self,p)local q=self.CFrame:Inverse()*p;return V3(640+q.X*20,360-q.Y*20,-q.Z),-q.Z>0 end
local waiting={}
local realAdvance=R.advance;local mainThread=coroutine.running()
R.task.wait=function(t)if coroutine.running()==mainThread then return t or 0 end;table.insert(waiting,{At=R.clock+(t or 0),Co=coroutine.running()});return coroutine.yield()end
R.advance=function(dt)realAdvance(dt);local due,keep={},{};for _,w in ipairs(waiting)do if w.At<=R.clock then due[#due+1]=w else keep[#keep+1]=w end end;waiting=keep;for _,w in ipairs(due)do local ok,e=coroutine.resume(w.Co,dt);if not ok then error(e,0)end end end
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
local gv=R.new('LocalScript');gv.Name='GardenVisuals';gv.Parent=me
assert(pcall(W.load,'GardenVisuals',gv))
local function run(seconds)for _=1,math.floor(seconds*60+.5)do W.frames(1)end end
run(4)
local made=0
local function plant(id)
 made+=1;local d=Catalog[id];local m=R.new('Model');m.Name='Crop_'..made
 local now=W.workspace:GetServerTimeNow();local planted=now-.5*d.Seconds
 for k,v in pairs({GardenPlantV141=true,CropId='c'..made,SeedId=id,GrowthStage=2,PlantScale=1,SeedScale=1,Mutation='None',Weather='None',PlantedAt=planted,MatureAt=planted+d.Seconds,ReadyAt=planted+d.Seconds,
  HarvestCycle=0,PickedMask=0,FruitReady=false,FruitGrowing=false,FruitRevision=1,GardenOwnerId=5})do m:SetAttribute(k,v)end
 local a=R.new('Part');a.Name='CropAnchor';a.CFrame=CF(0,0,0);a.Parent=m;m.Parent=map;return m
end
local ids={'SunflowerSeed','BluebellSeed','AppleSeed','AshRoseSeed','LanternFernSeed','AmethystSeed'}
for _,id in ipairs(ids)do
 for _,mode in ipairs({'still','sway'})do
  Gui.ReducedMotionEnabled=mode=='still'
  local m=plant(id);run(6)
  local art=m:FindFirstChild('LocalPlantArt');local parts=0
  if art then for _,p in ipairs(art:GetDescendants())do if p:IsA('BasePart')then parts+=1 end end end
  local before={me:GetAttribute('PlantGrowthApplies')or 0,me:GetAttribute('PlantGrowthRewrites')or 0}
  writes,moves=0,0;counting=true;run(5);counting=false
  print(('BENCH %s %s parts=%d seconds=%d writes=%.0f moves=%.0f total=%.0f'):format(id,mode,parts,Catalog[id].Seconds,writes/5,moves/5,(writes+moves)/5))
  map.DescendantRemoving:Fire(m);m:Destroy();run(1)
 end
end
