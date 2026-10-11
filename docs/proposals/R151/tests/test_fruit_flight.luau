--!nocheck
-- R151 (owner: "some plants and fruits dont float into the players inventory"): EVERY seed of the catalog, through EVERY harvest path, on the Roblox mock with the REAL
-- GardenPlantRuntime (the server's plant models: attributes, prompts, the harvest marks), the REAL GardenVisuals (the client scheduler), PlantGrowthFx, HarvestArrival,
-- PlantVisuals, PlantRules, HarvestItemInfo and (for one seed of every kind) the REAL Hotbar. The "server" is the garden's data list changed the way
-- PlayerDataService:HarvestPlant changes it (the real PlantRules.FinishFruit, and the mark it leaves for a plant the harvest removed: test_harvest_marks.luau runs the
-- real PlayerDataService); the "client" is everything under StarterPlayerScripts.
-- For every seed of the catalog and each path that applies to it:
--   regrow    a fruit picked from a plant that regrows (the first and the last fruit of the plant)
--   removal   a harvest that removes the plant: a single-harvest plant (Mode 'whole') and the last fruit of a plant that does not regrow (the server's HarvestedBy mark)
--   nomodel   the fruit has no model of its own here (the detail planner left it out) / the plant has no model at all (it is out of the camera's range)
--   observer  somebody else's garden: the fruit flies to THEM
-- it asserts: a flight starts at the plant, it ends at the harvester (within 3 studs of their upper torso), HarvestArrival holds the item while it flies and releases it
-- once, with a cue, when it lands, the tool key of the real harvested item (HarvestItemInfo) is the flight's key, nothing is left in the world, and what kind of flight it
-- was: the fruit's own parts (plants without motion of their own), a detached copy (Mech, Verity, Lantern Fern, Amethyst Grape, Obsidian Maw, Frostbell, Orbit Lotus,
-- Supernova, Dune Starfruit) or one ball (only when the budget is spent). Then: a harvest of many fruit at once (nothing just vanishes), a full bag (refused: no flight, no
-- hold), the shovel (no flight), reduced motion / the lowest quality tier / a dead harvester / a plant that streams out, and the Hotbar flash.
-- Usage: luau test_fruit_flight.luau [SeedId,SeedId,...]   (only those seeds in the per-seed sections; the other sections always run)
local only=...
local C=require('./growth_common');local W,R,V3,CF=C.W,C.R,C.V3,C.CF;local check,near=C.check,C.near
local F=require('./fixtures')
local Catalog,Rules,Visuals=C.Catalog,C.Rules,C.Visuals
local Arrival=W.module('HarvestArrival');local FxM=W.module('PlantGrowthFx');local Info=W.module('HarvestItemInfo');local Names=W.module('GardenDisplayNames')
local Players=W.service('Players');local Gui=W.service('GuiService')
R.clock=100000
F.packAssets(W)
local onlySet;if only and only~=''then onlySet={};for id in string.gmatch(only,'[^,]+')do onlySet[id]=true end end
-- the engine fires DescendantRemoving (before the instance and its descendants go); the mock does not
do
 local raw=R.Inst.Destroy
 R.Inst.Destroy=function(self)
  if self._destroyed then return end
  if self._parent then local a=self._parent;while a do a.DescendantRemoving:Fire(self);a=a._parent end end
  return raw(self)
 end
end
-- players: me (the local player: a character, a backpack, a gui) and another player in another garden ----------------------------------------------------------------------
local me=R.new('Player');me.Name='Tester';me.UserId=5;me.Parent=Players;Players.LocalPlayer=me
local other=R.new('Player');other.Name='Other';other.UserId=6;other.Parent=Players
Players.GetPlayerByUserId=function(_,id)return id==5 and me or id==6 and other or nil end
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
local bag=R.new('Backpack');bag.Name='Backpack';bag.Parent=me
local function character(player,at)
 local model=R.new('Model');model.Name=player.Name
 local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=CF(at.X,at.Y,at.Z);root.Parent=model
 local hum=R.new('Humanoid');hum.Name='Humanoid';hum.Health=100;hum.Parent=model
 model.Parent=W.workspace;player.Character=model;return model,root,hum
end
local ME_AT,OTHER_AT=V3(0,3,-13),V3(150,3,-13)
local myChar,myRoot,myHum=character(me,ME_AT)
local otherChar,otherRoot,otherHum=character(other,OTHER_AT)
me.CharacterAdded=R.signal()
myHum.EquipTool=function(_,tool)for _,t in ipairs(myChar:GetChildren())do if t:IsA('Tool')then t.Parent=bag end end;tool.Parent=myChar end
myHum.UnequipTools=function()for _,t in ipairs(myChar:GetChildren())do if t:IsA('Tool')then t.Parent=bag end end end
me:SetAttribute('ChestChaseCommandsAllowed',true)
local camera=W.workspace.CurrentCamera
local function aimCamera(at,looking)camera.CFrame=R.CFrame.lookAt(at,looking or at+V3(0,-10,30))end
aimCamera(V3(0,14,-34))
function camera.WorldToViewportPoint(self,p)local q=self.CFrame:Inverse()*p;return V3(640+q.X*20,360-q.Y*20,-q.Z),-q.Z>0 end
-- the real scheduler's loops wait; here a spawned loop really waits
local waiting={}
local realWait,realAdvance=R.task.wait,R.advance
local mainThread=coroutine.running()
R.task.wait=function(t)if coroutine.running()==mainThread then return t or 0 end;table.insert(waiting,{At=R.clock+(t or 0),Co=coroutine.running()});return coroutine.yield()end
R.advance=function(dt)realAdvance(dt);local due,keep={},{};for _,w in ipairs(waiting)do if w.At<=R.clock then due[#due+1]=w else keep[#keep+1]=w end end;waiting=keep;for _,w in ipairs(due)do local ok,e=coroutine.resume(w.Co,dt);if not ok then error(e,0)end end end
-- the stubs of the baked meshes (the way every plant test does it)
do local Meshes=W.module('ApprovedPlantMeshes');Meshes.Get=function(key)return {Clone=function()local p=R.new('Part');p:SetAttribute('ApprovedMesh',key);return p end}end;Meshes.Status=function()return 'Ready'end end
-- the garden: the REAL server runtime on fake data, two gardens (mine, another player's) --------------------------------------------------------------------------------
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
local function soil(x,z)local p=R.new('Part');p.Name='DirtPlot_1';p.Size=V3(150,1,150);p.CFrame=CF(x,-.5,z);p.Anchored=true;p:SetAttribute('GardenSoil',true);p.Parent=map;return p end
local mySoil,otherSoil=soil(0,0),soil(150,0)
local PD={Gardens={[me]={Plots={['1']={}}},[other]={Plots={['1']={}}}}}
function PD:IsLoaded()return true end;function PD:MarkAdultDiscovered()end;function PD:MarkDirty()end
local Service={PlayerData=PD,Config={GardenInteractionDistance=12},GardenPlots={[1]={{Part=mySoil,Rendered={}}},[2]={{Part=otherSoil,Rendered={}}}}}
local Runtime=W.module('GardenPlantRuntime');Runtime.Install(Service)
local BASES={[me]={Index=1},[other]={Index=2}}
local function nowS()return math.floor(R.clock)end
local function render(owner)Service:RenderGarden(BASES[owner],owner)end
-- the client scripts: the real GardenVisuals and the real Hotbar (its layout is the test's: the mock has no layout engine) -------------------------------------------------
local function set(o,k,v)local c=o._props[k];if not c or c.X~=v.X or c.Y~=v.Y then o[k]=v end end
local function lay(o,px,py,pw,ph,cx,cy)
 for _,c in ipairs(o._children)do if c:IsA('GuiObject')then
  local s,p=c._props.Size,c._props.Position;local a=c._props.AnchorPoint or R.Vector2.new(0,0)
  local w=s.X.Scale*pw+s.X.Offset;local h=s.Y.Scale*ph+s.Y.Offset
  local x=px+p.X.Scale*pw+p.X.Offset-a.X*w-cx;local y=py+p.Y.Scale*ph+p.Y.Offset-a.Y*h-cy
  set(c,'AbsoluteSize',R.Vector2.new(w,h));set(c,'AbsolutePosition',R.Vector2.new(x,y))
  local ox,oy=0,0;if c._class=='ScrollingFrame'then local cp=c._props.CanvasPosition or R.Vector2.new(0,0);ox,oy=cp.X,cp.Y end
  lay(c,x,y,w,h,ox,oy)
 end end
end
local function step()local gui=pg:FindFirstChild('ChestToolHotbar');if gui then lay(gui,0,0,1280,720,0,0)end;W.frames(1)end
local function run(seconds)for _=1,math.floor(seconds*60+.5)do step()end end
local gv=R.new('LocalScript');gv.Name='GardenVisuals';gv.Parent=me
local okGV,errGV=pcall(W.load,'GardenVisuals',gv);check(okGV,'GardenVisuals loads in the test world ('..tostring(errGV)..')')
W.Run.IsStudio=function()return true end
local shovel=F.shovel(W,bag)
local hb=R.new('LocalScript');hb.Name='Hotbar'
local okHB,errHB=pcall(W.load,'Hotbar',hb);check(okHB,'the Hotbar loads in the test world ('..tostring(errHB)..')')
run(4)
-- helpers ----------------------------------------------------------------------------------------------------------------------------------------------------------------------
local fxFolder
local function folder()fxFolder=fxFolder and fxFolder.Parent and fxFolder or W.workspace:FindFirstChild('LocalPlantGrowthFx');return fxFolder end
local function flyers()local f=folder();local out={};if f then for _,c in ipairs(f:GetChildren())do if c:IsA('Model')or(c:IsA('Part')and c.Name=='HarvestBall')then out[#out+1]=c end end end;return out end
local function centroid(inst)
 local n,x,y,z=0,0,0,0
 local list=inst:IsA('BasePart')and{inst}or inst:GetDescendants()
 for _,p in ipairs(list)do if p:IsA('BasePart')then local c=p.CFrame.Position;x+=c.X;y+=c.Y;z+=c.Z;n+=1 end end
 if n==0 then return nil,0 end
 return V3(x/n,y/n,z/n),n
end
local function artOf(model)return model and model:FindFirstChild('LocalPlantArt')end
local function modelOf(owner,crop)local s=owner==me and mySoil or otherSoil;return s:FindFirstChild('Crop_'..crop.Id)end
local spawned=0
local function cropFor(id,x,z,extra)
 spawned+=1;local d=Catalog[id];local now=nowS()
 local crop={Id='ff-'..spawned..'-'..id,SeedId=id,PlantedAt=now-d.Seconds*3,MatureAt=now-d.Seconds*2,ReadyAt=now-d.Seconds*2,PlantScale=1,SeedScale=1,Mutation='None',HarvestCycle=0,PickedMask=0,
  TraitVersion=1,OffsetX=x or 0,OffsetZ=z or 0}
 for k,v in pairs(extra or{})do crop[k]=v end
 return crop
end
local function plantCrop(owner,crop)table.insert(PD.Gardens[owner].Plots['1'],crop);render(owner);return modelOf(owner,crop)end
-- the server's side of a harvest, as PlayerDataService:HarvestPlant leaves the crop (real PlantRules): the crop regrows / is marked picked / is removed with a mark
local NOMARK=false -- (a server that leaves no HarvestedBy mark: see the section after the shovel)
local function serverHarvest(owner,crop,index)
 local def=Catalog[crop.SeedId];local now=nowS()
 index=index or Rules.NextFruit(crop,def,now)
 if not index or not Rules.FruitReady(crop,index,now)then return nil,'not ready' end
 local removed=Rules.FinishFruit(crop,def,index,now,1)
 if removed then
  local list=PD.Gardens[owner].Plots['1'];table.remove(list,table.find(list,crop))
  if not NOMARK then PD.HarvestRemovals=PD.HarvestRemovals or{};PD.HarvestRemovals[crop.Id]={Index=index,By=owner.UserId,At=os.clock()}end
 end
 return index,removed
end
local function shovelOut(owner,crop)local list=PD.Gardens[owner].Plots['1'];local at=table.find(list,crop);if at then table.remove(list,at)end;render(owner)end -- (no mark)
local function waitBuilt(model,frames)
 for _=1,frames or 2400 do
  step()
  local a=artOf(model);if a and not me:GetAttribute('PlantBuildInProgress')and #a:GetDescendants()>0 then run(.3);return a end
 end
 return nil
end
-- a harvested item tool exactly as HarvestToolService makes it (the real HarvestItemInfo), for the key HarvestArrival matches
local function toolFor(crop,index)
 local def=Catalog[crop.SeedId]
 local harvest={Id='h-'..crop.Id..'-'..index..'-'..spawned,SeedId=crop.SeedId,SourceCropId=crop.Id,FruitIndex=index,HarvestCycle=0,Mutation='None',Weather='None',FruitScale=1,Value=100,ReadyAt=0,PlantScale=1,SeedScale=1,PickedMask=0,PlantedAt=0,MatureAt=1}
 local item=Info.From(harvest,def)
 local tool=R.new('Tool');tool.Name=item.Name;tool:SetAttribute('HarvestItemTool',true);tool:SetAttribute('HarvestInventoryId',harvest.Id);tool:SetAttribute('InventoryKey',harvest.Id)
 for _,key in ipairs({'SeedId','Mutation','Weather','FruitScale','SellValue','FruitName'})do tool:SetAttribute(key,item[key])end
 for key,value in pairs(item.VisualCrop)do tool:SetAttribute(key,value)end
 tool:SetAttribute('Rarity',def.Rarity)
 return tool
end
local events={}
Arrival.OnRelease(function(k,cue)events[#events+1]={Key=k,Cue=cue,At=R.clock}end)
local AIM=FxM.Tuning.AimUp
local function aimAt(root)return root.Position+V3(0,AIM,0)end
-- starts `fire()` (the server's change) and watches the flyers frame by frame until they are all gone
local function watch(fire,tool,maxFrames)
 events={};local seen={};local order={}
 local heldDuring,heldAfter
 fire()
 local endFrame
 for frame=1,maxFrames or 150 do
  step()
  local list=flyers()
  for _,f in ipairs(list)do
   if not seen[f]then seen[f]={Start=R.clock,First=centroid(f),Frames=0,Ball=f:IsA('BasePart'),Instance=f};order[#order+1]=f;if tool and heldDuring==nil then heldDuring=Arrival.Holds(tool)end end
   local c=centroid(f);if c then seen[f].Last=c;seen[f].Frames+=1;seen[f].LastAt=R.clock end
  end
  if #order>0 and #list==0 then endFrame=frame;break end
 end
 run(.05)
 if tool then heldAfter=Arrival.Holds(tool)end
 return {Flights=order,Info=seen,End=endFrame,Events=events,HeldDuring=heldDuring,HeldAfter=heldAfter}
end
local function eventsFor(res,key)local ev={};for _,e in ipairs(res.Events)do if e.Key==key then ev[#ev+1]=e end end;return ev end
-- the common assertions of one flight; returns its kind ('own' / 'copy' / 'ball'), nil when nothing flew
local function expectFlight(label,res,root,key,owned,child,startAt)
 local n=#res.Flights
 if not check(n>=1,label..': a flight starts ('..n..' flyer(s))')then return nil end
 local f=res.Flights[1];local i=res.Info[f]
 check(res.End~=nil,label..': it ends (it does not hang in the air)')
 check(i.Last~=nil and(i.Last-aimAt(root)).Magnitude<=3,label..string.format(': it ends at the harvester (%.2f studs from their upper torso)',i.Last and(i.Last-aimAt(root)).Magnitude or-1))
 if startAt then check(i.First~=nil and(i.First-startAt.Center).Magnitude<=startAt.Radius,label..string.format(': it starts at the plant (%.1f studs from its middle, bound %.1f)',i.First and(i.First-startAt.Center).Magnitude or-1,startAt.Radius))end
 check(i.Frames>=12 and i.Frames<=60,label..': it flies for 0.2 - 1 s ('..i.Frames..' frames)')
 local ev=eventsFor(res,key)
 if owned then
  check(#ev==1 and ev[1].Cue==true,label..': the inventory is released once, with a cue ('..#ev..' release(s))')
  if #ev==1 and i.LastAt then check(math.abs(ev[1].At-i.LastAt)<=.1,label..string.format(': ... when it lands (%.3f s from the last frame in the air)',ev[1].At-i.LastAt))end
  check(res.HeldDuring==true and res.HeldAfter==false,label..': the item is held while the fruit flies and shown when it has landed')
 else check(#ev==0 and not res.HeldDuring,label..': an observer\'s inventory is never held')end
 return i.Ball and'ball'or(f==child and'own'or'copy')
end
local KINDS={own=0,copy=0,ball=0}
local function plantBox(model,def)
 local a=model:FindFirstChild('CropAnchor');local p=a.Position
 return {Center=p+V3(0,def.Height*.5,0),Radius=math.sqrt((def.Height*.5)^2+def.Radius^2)+4}
end
-- one pick: the server changes the crop, the client's own model of that fruit is `child` (nil: it has none, e.g. the planner left it out)
local function pick(label,owner,crop,index,child,hold)
 local def=Catalog[crop.SeedId];local model=modelOf(owner,crop)
 local root=owner==me and myRoot or otherRoot
 local key=crop.Id..':'..index
 local tool=toolFor(crop,index)
 check(Arrival.ToolKey(tool)==key,label..': the real harvested item\'s tool key is the flight\'s key ('..tostring(Arrival.ToolKey(tool))..')')
 if owner==me and hold~=false then Arrival.Expect(crop.Id,index)end
 local box=plantBox(model,def)
 local res=watch(function()serverHarvest(owner,crop,index);render(owner)end,owner==me and tool or nil,160)
 local kind=expectFlight(label,res,root,key,owner==me and hold~=false,child,box)
 if kind then KINDS[kind]+=1 end
 return kind,res
end
-- the roster ----------------------------------------------------------------------------------------------------------------------------------------------------------------------
local ids=C.ids()
check(#ids>=65,'the roster has all '..#ids..' seeds of the catalog (65 at R151)')
local function wants(id)return onlySet==nil or onlySet[id]==true end
local summary={};local tested=0
for _,id in ipairs(ids)do if wants(id)then
 local def=Catalog[id];local removal=def.Mode=='whole'or def.Regrows==false
 local own=FxM.OwnParts(C.crop(id));local want=own and'own'or'copy'
 local tag=id..(removal and' (single harvest)'or' (regrows)')
 -- A. the plant has a model of its own here; the harvester picks (regrowing plant: the first and the last fruit; single harvest: the plant goes)
 do
  local crop=cropFor(id,0,0);local model=plantCrop(me,crop);local art=waitBuilt(model)
  if check(art~=nil,tag..': the client built the plant')then
   local first=art:FindFirstChild('Harvest_1')
   check(first~=nil,tag..': the plant has its own model of fruit 1')
   local k=pick(tag..' / '..(removal and'removal'or'regrow'),me,crop,1,first)
   check(k==want,tag..': what flies is '..(own and'the fruit\'s own parts'or'a detached copy')..' ('..tostring(k)..')')
   if k=='own'then check(first.Parent==nil,tag..': the plant\'s own fruit model is gone after it landed')end
   if removal then
    run(.6)
    check(modelOf(me,crop)==nil and #flyers()==0,tag..': the plant is gone from the garden and nothing is left in the air')
   elseif def.FruitCount>1 then
    local last=def.FruitCount;local a2=artOf(modelOf(me,crop));local lastChild=a2 and a2:FindFirstChild('Harvest_'..last)
    local k2=pick(tag..' / regrow (fruit '..last..')',me,crop,last,lastChild)
    check(k2==want,tag..': ... the last fruit too ('..tostring(k2)..')')
   end
   if modelOf(me,crop)then shovelOut(me,crop)end;run(.4)
  end
 end
 -- B. the plant has no model of THAT fruit here (the detail planner left it out): the fruit flies as a copy built where it hung
 do
  local crop=cropFor(id,0,0);local model=plantCrop(me,crop);local art=waitBuilt(model)
  if check(art~=nil,tag..': (built again for the no-model path)')then
   local child=art:FindFirstChild('Harvest_1');if child then child:Destroy()end
   local k=pick(tag..' / no model of the fruit',me,crop,1,nil)
   check(k=='copy'or k=='ball',tag..': it flies as a copy built where the fruit hung ('..tostring(k)..')')
  end
  if modelOf(me,crop)then shovelOut(me,crop)end;run(.5)
 end
 -- C. the plant has no model at all (the camera is far away: out of the detail range)
 do
  aimCamera(V3(0,14,-5200))
  local crop=cropFor(id,0,0);local model=plantCrop(me,crop);run(1.2)
  check(artOf(model)==nil,tag..': (far from the camera the plant has no model of its own)')
  local k=pick(tag..' / plant without a model',me,crop,1,nil)
  check(k=='copy'or k=='ball',tag..': it flies as a copy ('..tostring(k)..')')
  if modelOf(me,crop)then shovelOut(me,crop)end;run(.5)
  aimCamera(V3(0,14,-34));run(.5)
 end
 -- D. somebody else's garden, in view: the fruit flies to THEM, and nobody's inventory is held
 do
  aimCamera(V3(150,14,-34))
  local crop=cropFor(id,0,0);local model=plantCrop(other,crop);local art=waitBuilt(model)
  if check(art~=nil,tag..': (the other garden\'s plant is built)')then
   local child=art:FindFirstChild('Harvest_1')
   local k=pick(tag..' / observer',other,crop,1,child)
   check(k==want,tag..': what flies for the observer is '..(own and'the fruit\'s own parts'or'a detached copy')..' ('..tostring(k)..')')
  end
  if modelOf(other,crop)then shovelOut(other,crop)end;run(.5)
  aimCamera(V3(0,14,-34));run(.5)
 end
 tested+=1
 summary[#summary+1]=string.format('%-22s %-8s %s',id,removal and'removal'or'regrow',want)
end end
print('PATHS '..#summary..' seeds: '..KINDS.own..' own-parts flights, '..KINDS.copy..' copies, '..KINDS.ball..' balls')
for _,l in ipairs(summary)do print('SEED '..l)end
if onlySet==nil then
 check(tested==#ids and tested>=65,'every seed of the catalog was harvested through every path ('..tested..')')
 -- the plants whose own parts never move (an independent list: what the R149 director refused; now they fly as copies)
 local copies={AmethystSeed=1,LanternFernSeed=1,CrowncoreTreeSeed=1,HoloAppleTreeSeed=1,HoloMelonSeed=1,NebulaVineSeed=1,PlasmaPepperSeed=1,PrismLotusSeed=1,VeritySeed=1,
  ObsidianMawSeed=1,SilentFrostbellSeed=1,OrbitLotusSeed=1,SupernovaBloomSeed=1,StarfruitSeed=1}
 local listed={};for _,l in ipairs(summary)do local id,_,kind=l:match('^(%S+)%s+(%S+)%s+(%S+)$');if kind=='copy'then listed[id]=1 end end
 local same=true
 for id in pairs(copies)do if not listed[id]then same=false;print('FAIL list: '..id..' did not fly as a copy')end end
 for id in pairs(listed)do if not copies[id]then same=false;print('FAIL list: '..id..' flew as a copy')end end
 check(same,'exactly the 14 plants of R149\'s exclusion list fly as copies (6 Mech, Verity, Lantern Fern, Amethyst Grape, Maw, Frostbell, Orbit Lotus, Supernova, Dune Starfruit); every other seed flies its own parts')
 local removals=0;for _,l in ipairs(summary)do if l:find('removal')then removals+=1 end end
 check(removals==10,'10 seeds are single-harvest (6 whole plants + DatePalm, LavaLotus, SunflowerBloom, WinterPine: the last fruit removes the plant) ('..removals..')')
end

-- a harvest of many fruit at once: nothing just vanishes while the budget lasts; beyond it the inventory is told at once ------------------------------------------------------
do
 local function plantsOf(id,count,x0)
  local list={}
  for i=1,count do local crop=cropFor(id,x0+(i-1)*34,0);local model=plantCrop(me,crop);list[#list+1]={Crop=crop,Model=model}end
  for _,e in ipairs(list)do waitBuilt(e.Model)end
  return list
 end
 local function pickAll(list)
  events={};local seen={};local order={};local maxReal,maxBall=0,0;local picks=0
  for _,e in ipairs(list)do for index=1,Catalog[e.Crop.SeedId].FruitCount do Arrival.Expect(e.Crop.Id,index);picks+=1 end end
  for _,e in ipairs(list)do for index=1,Catalog[e.Crop.SeedId].FruitCount do serverHarvest(me,e.Crop,index)end;render(me)end
  for _=1,200 do
   step();local real,balls=0,0
   for _,f in ipairs(flyers())do if not seen[f]then seen[f]=true;order[#order+1]=f end;if f:IsA('BasePart')then balls+=1 else real+=1 end end
   maxReal=math.max(maxReal,real);maxBall=math.max(maxBall,balls)
   local open=0;for _,e in ipairs(list)do for index=1,Catalog[e.Crop.SeedId].FruitCount do if Arrival.Pending(e.Crop.Id,index)then open+=1 end end end
   if open==0 and #flyers()==0 then break end -- (the plants refresh one after the other: all picks released and nothing in the air)
  end
  run(.2)
  return picks,#order,maxReal,maxBall
 end
 local budget=FxM.Budget(3,false,false)
 -- 15 fruit (Elderbloom 5 + Winter Crownwood 6 + Holo Apple Tree 4, a copy): a flight each
 local list={}
 for _,e in ipairs(plantsOf('ElderbloomSeed',1,-40))do list[#list+1]=e end
 for _,e in ipairs(plantsOf('WinterCrownwoodSeed',1,0))do list[#list+1]=e end
 for _,e in ipairs(plantsOf('HoloAppleTreeSeed',1,40))do list[#list+1]=e end
 local picks,flights,maxReal,maxBall=pickAll(list)
 check(picks==15 and flights==15,'15 fruit picked at once (3 plants): every one flies ('..flights..' flights; nothing just vanishes)')
 check(maxReal<=budget.Flights and maxBall<=budget.Tokens,('... at most %d as fruit and %d as balls at a time (%d and %d)'):format(budget.Flights,budget.Tokens,maxReal,maxBall))
 local released=0;for _,e in ipairs(events)do if e.Cue==true then released+=1 end end
 local pending=0;for _,e in ipairs(list)do for i=1,Catalog[e.Crop.SeedId].FruitCount do if Arrival.Pending(e.Crop.Id,i)then pending+=1 end end end
 check(released==15 and pending==0 and #flyers()==0,'... every pick is released with a cue when it lands, nothing is held or left ('..released..' releases)')
 for _,e in ipairs(list)do if modelOf(me,e.Crop)then shovelOut(me,e.Crop)end end;run(.5)
 -- 36 fruit (six six-fruit trees): the budget (8 fruit + 16 balls) is spent, the rest just go and the inventory is told AT ONCE (never held for a flight that does not start)
 list=plantsOf('WinterCrownwoodSeed',6,-100)
 picks,flights,maxReal,maxBall=pickAll(list)
 check(picks==36 and flights>=budget.Flights+budget.Tokens-4 and flights<=36,('36 fruit at once: %d fly (8 fruit + 16 balls at most at a time), the rest just go'):format(flights))
 released=0;for _,e in ipairs(events)do if e.Cue==true then released+=1 end end
 pending=0;for _,e in ipairs(list)do for i=1,6 do if Arrival.Pending(e.Crop.Id,i)then pending+=1 end end end
 check(released==36 and pending==0 and #flyers()==0 and maxReal<=budget.Flights and maxBall<=budget.Tokens,'... all 36 picks are released with a cue and none is left held ('..released..'; at most '..maxReal..' fruit and '..maxBall..' balls at once)')
 for _,e in ipairs(list)do if modelOf(me,e.Crop)then shovelOut(me,e.Crop)end end;run(.5)
end

-- a full bag: the server refuses, EconomyClient cancels the hold: no flight, nothing held, the plant is untouched --------------------------------------------------------------
do
 local crop=cropFor('AppleSeed',0,0);local model=plantCrop(me,crop);local art=waitBuilt(model);events={}
 local before=art and art:FindFirstChild('Harvest_1')
 Arrival.Expect(crop.Id,1);check(Arrival.Pending(crop.Id,1),'the request is sent: the item will be held')
 Arrival.Cancel(crop.Id,1)  -- "HARVEST BAG FULL - SELL SOME HARVESTS FIRST": the refused request
 run(1)
 check(#flyers()==0 and not Arrival.Pending(crop.Id,1)and #events==1 and events[1].Cue==false,'a full bag: no flight, the hold ends at once without a cue')
 check(before~=nil and before.Parent~=nil,'... and the fruit stays on the plant')
 shovelOut(me,crop);run(.4)
end
-- the shovel: a removal nobody asked for (no mark, no request) flies nothing and holds nothing ----------------------------------------------------------------------------------
do
 for _,id in ipairs({'AppleSeed','MooncapSeed','VeritySeed','LanternFernSeed'})do
  local crop=cropFor(id,0,0);local model=plantCrop(me,crop);waitBuilt(model);events={}
  shovelOut(me,crop);run(1)
  check(#flyers()==0 and #events==0 and modelOf(me,crop)==nil,id..': a plant dug out with the shovel: nothing flies, nothing is held, the plant is gone')
 end
end
-- a server that leaves no mark (an older server, or one whose mark was dropped): the harvester's own client still flies the fruit it asked for (HarvestArrival.Pending) when the
-- plant goes with the harvest. Only the harvester's client can do this: it is the one that knows; the others need the mark (the observer section above).
do
 NOMARK=true
 for _,id in ipairs({'MooncapSeed','FrostFernSeed','ObsidianMawSeed'})do
  local want=FxM.OwnParts(C.crop(id))and'own'or'copy'
  local crop=cropFor(id,0,0);local model=plantCrop(me,crop);local art=waitBuilt(model)
  local first=art and art:FindFirstChild('Harvest_1')
  check(first~=nil,id..' (no mark): the plant has its own model of the fruit')
  local k=pick(id..' / removal without a mark',me,crop,1,first)
  check(k==want,id..' (no mark): the harvester still sees the fruit fly ('..want..'), the plant going with the harvest ('..tostring(k)..')')
  run(.6);check(modelOf(me,crop)==nil and #flyers()==0,id..' (no mark): the plant is gone and nothing is left in the air')
 end
 NOMARK=false
end
-- the modes: reduced motion, the Studio switch, the lowest quality tier, a harvester who dies, a plant that streams out --------------------------------------------------------------
do
 local function ownPick(label,expectFly)
  local crop=cropFor('AppleSeed',0,0);local model=plantCrop(me,crop);waitBuilt(model);events={}
  Arrival.Expect(crop.Id,1);local tool=toolFor(crop,1)
  local res=watch(function()serverHarvest(me,crop,1);render(me)end,tool,150)
  if expectFly then
   check(#res.Flights>=1,label..': the fruit flies')
  else
   check(#res.Flights==0,label..': nothing flies')
   local ev=eventsFor(res,crop.Id..':1');check(#ev==1 and ev[1].Cue==true and not Arrival.Pending(crop.Id,1),label..': the inventory is told at once ('..#ev..' release(s))')
  end
  if modelOf(me,crop)then shovelOut(me,crop)end;run(.4)
  return res
 end
 Gui.ReducedMotionEnabled=true;run(.5)
 ownPick('reduced motion',false)
 Gui.ReducedMotionEnabled=false;run(.5)
 me:SetAttribute('StudioPlantEffects','off');run(.6)
 ownPick('the Studio effects switch off',false)
 me:SetAttribute('StudioPlantEffects','low');run(.6)
 local res=ownPick('the lowest quality tier (your own fruit)',true)
 check(res.Flights[1]~=nil and not res.Info[res.Flights[1]].Ball,'... the fruit itself flies there too (no bounce, no glints, a small budget)')
 -- an observer on the lowest tier gets no flight (it has no Range) and no hold
 do
  aimCamera(V3(150,14,-34));local crop=cropFor('AppleSeed',0,0);local model=plantCrop(other,crop);waitBuilt(model);events={}
  local r2=watch(function()serverHarvest(other,crop,1);render(other)end,nil,90)
  check(#r2.Flights==0 and #events==0,'the lowest tier: another player\'s fruit just goes (observers need a Range)')
  shovelOut(other,crop);run(.4);aimCamera(V3(0,14,-34));run(.4)
 end
 me:SetAttribute('StudioPlantEffects','normal');run(.6)
 -- an observer too far from the camera
 do
  local crop=cropFor('AppleSeed',0,0);local model=plantCrop(other,crop);waitBuilt(model);events={}
  local r2=watch(function()serverHarvest(other,crop,1);render(other)end,nil,90)
  check(#r2.Flights==0 and #events==0,'another player\'s fruit far from the camera (150 studs): no flight, nothing held')
  shovelOut(other,crop);run(.4)
 end
 -- the harvester dies in the air: the fruit goes, the inventory is released
 do
  local crop=cropFor('AppleSeed',0,0);local model=plantCrop(me,crop);waitBuilt(model);events={};Arrival.Expect(crop.Id,1)
  serverHarvest(me,crop,1);render(me)
  for _=1,30 do step();if #flyers()>0 then break end end
  check(#flyers()==1,'(a fruit in the air)');myHum.Health=0;run(.1)
  check(#flyers()==0 and not Arrival.Pending(crop.Id,1)and #events==1,'the harvester died: the fruit disappears and the inventory is released');myHum.Health=100
  shovelOut(me,crop);run(.4)
 end
 -- a regrowing plant that streams out while its fruit flies: the fruit goes with it
 do
  local crop=cropFor('AppleSeed',0,0);local model=plantCrop(me,crop);waitBuilt(model);events={};Arrival.Expect(crop.Id,1)
  serverHarvest(me,crop,1);render(me)
  for _=1,30 do step();if #flyers()>0 then break end end
  check(#flyers()==1,'(a fruit in the air)');shovelOut(me,crop);run(.2)
  check(#flyers()==0 and not Arrival.Pending(crop.Id,1),'the plant left (streamed out) while its fruit flew: the fruit goes and the inventory is released')
 end
end

-- the Hotbar: the REAL script shows the item when the fruit has landed, and flashes its slot ---------------------------------------------------------------------------------------
do
 local gui=pg:FindFirstChild('ChestToolHotbar');local dock=gui and gui:FindFirstChild('Dock')
 check(gui~=nil and dock~=nil,'(the Hotbar built its dock)')
 local function slotOf(tool)for i=1,10 do local slot=dock['Slot'..i];if slot.Visible and slot.ItemName.Text==Names.Tool(tool,Catalog)then return slot,i end end end
 local function flashOf(b)return b and b:FindFirstChild('ArrivalFlash')end
 local cases={{'AppleSeed','regrow, the fruit\'s own parts'},{'MooncapSeed','a whole plant'},{'SunflowerBloomSeed','the last fruit of a plant that does not regrow'},{'VeritySeed','a copy (Verity)'},
  {'LanternFernSeed','a copy (Lantern Fern)'},{'HoloMelonSeed','a copy (a Mech hologram)'},{'ObsidianMawSeed','a copy (a whole plant with its own rig)'}}
 for _,case in ipairs(cases)do if wants(case[1])then
  local id,what=case[1],case[2]
  local crop=cropFor(id,0,0);local model=plantCrop(me,crop);waitBuilt(model);events={}
  local tool=toolFor(crop,1);Arrival.Expect(crop.Id,1)
  serverHarvest(me,crop,1)
  tool.Parent=bag  -- the server adds the item first (SyncTools), then re-renders the garden
  render(me)
  for _=1,120 do step();if #flyers()>=1 then break end end
  for _=1,6 do step()end
  check(#flyers()>=1 and Arrival.Holds(tool),id..' ('..what..'): the fruit is in the air and the item is held back')
  check(slotOf(tool)==nil,id..': ... the Hotbar does not show it yet')
  for _=1,90 do step();if #flyers()==0 then break end end
  step();step()
  local slot=slotOf(tool)
  check(slot~=nil,id..': the fruit landed: the Hotbar shows the item')
  local flash=flashOf(slot)
  check(flash~=nil and flash.BackgroundTransparency<.6,id..': ... and its slot flashes ('..tostring(flash and flash.BackgroundTransparency)..')')
  run(.6);tool:Destroy();if modelOf(me,crop)then shovelOut(me,crop)end;run(.3)
 end end
end
check(#flyers()==0,'nothing is left flying at the end')
C.done('fruit flight')
