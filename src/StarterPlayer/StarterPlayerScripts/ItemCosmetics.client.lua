do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
local Fx=require(game:GetService('ReplicatedStorage'):WaitForChild('ClientFxBudget'))
-- R72: screen-aware, part-budgeted effects with staggered creation and one transform batch.
local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService');local Tags=game:GetService('CollectionService');local Players=game:GetService('Players')
local Weather=require(RS.WeatherTraits);local Effects=require(RS.ItemVisualEffects);local Budget=require(RS.CosmeticBudget);local View=require(RS.PlantDetailPlanner)
local Batch=require(RS.PlantAnimationBatch);local batch=Batch.new(workspace);local player=Players.LocalPlayer
local folder=Instance.new('Folder');folder.Name='_ItemCosmeticsR59';folder.Parent=workspace
-- R154 (a seed from the opener's own pack is held out of their hand until it has flown into the hotbar): its weather / Mech effects are held back
-- with it; SeedCollect154 says which tools it hides (the effects are drawn outside the tool, in the folder above).
local Collect do local m=RS:FindFirstChild('SeedCollect154');local ok,c=pcall(function()return m and require(m)end);Collect=ok and c or nil end
local targets={};local records={};local selected={};local pending={};local pendingIndex=1;local scan=1
local function remove(p)targets[p]=nil;selected[p]=nil;if records[p]then Effects.Destroy(records[p]);records[p]=nil end end
local function add(p)if p:IsA('BasePart')then targets[p]=true end end
for _,p in ipairs(Tags:GetTagged('GardenItemFX'))do add(p)end
local added=Tags:GetInstanceAddedSignal('GardenItemFX'):Connect(add);local removed=Tags:GetInstanceRemovedSignal('GardenItemFX'):Connect(remove)
-- R128 (owner): an item someone is carrying has its effect stepped every frame so the rings and orbits stay on it while running.
-- R153 (owner: "fix all jittery type effects ... like mutation"): every selected effect steps every rendered frame in RenderStepped, carried or
-- lying in the world (world items stepped at 20 Hz / 10 Hz low: the drips, frost and arcs moved in steps). The saving stays in the selection:
-- on screen, within 180 studs, inside CosmeticBudget's parts (96 low / 240), so the per-frame cost is at most those parts in one batch.
local function visible(p)
 if not p:IsDescendantOf(workspace)then return false end
 if Collect and Collect.Hidden(p)then return false end -- (R154: the seed in the hand that has not landed yet; its effects come back with it)
 local a=p.Parent
 while a and a~=workspace do
  if a:GetAttribute('PackVisible')==false or a:GetAttribute('RevealAt')then return false end
  a=a.Parent
 end
 return true
end
local c=Run.RenderStepped:Connect(function(dt)
 scan+=dt;local camera=workspace.CurrentCamera;if not camera then return end
 local low=Fx.Low()
 if scan>=.3 then
  scan=0;local list={};local view=View.View(camera)
  for p in pairs(targets)do if p.Parent and visible(p)then
   local weather=Weather.Key(p:GetAttribute('WeatherTrait'));local mech=p:GetAttribute('MechFX')==true
   if weather~='None'or mech then
    local center=p.CFrame:PointToWorldSpace(p:GetAttribute('EffectOffset')or Vector3.zero)
    local radius=p:GetAttribute('EffectRadius')or 1;local height=p:GetAttribute('EffectHeight')or radius*2
    local distance=(center-camera.CFrame.Position).Magnitude-radius
    local held=player.Character and p:IsDescendantOf(player.Character)
    -- A sphere includes the complete effect, so oversized items crossing a screen edge survive.
    if distance<180 and(held or View.Coverage(camera,center,math.max(radius,height*.5)*1.3+1,view))then
     table.insert(list,{Part=p,Distance=distance-(held and 1000 or 0)-(records[p]and 4 or 0),Weather=weather,Mech=mech})
    end
   end
  end end
  table.sort(list,function(a,b)return a.Distance<b.Distance end);selected={}
  pending=Budget.SelectItems(list,low);pendingIndex=1
  for _,item in ipairs(pending)do
   local p=item.Part;selected[p]=true;local e=records[p]
   if e and(e.Weather~=item.Weather or e.Mech~=item.Mech)then Effects.Destroy(e);records[p]=nil end
  end
  for p,e in pairs(records)do if not selected[p]then Effects.Destroy(e);records[p]=nil end end
 end
 -- Cap allocations on each heartbeat instead of creating an entire crowd in one scan.
 local created=0;local createLimit=low and 1 or 2
 while pendingIndex<=#pending and created<createLimit do
  local item=pending[pendingIndex];pendingIndex+=1;local p=item.Part
  if selected[p]and not records[p]and p.Parent and visible(p)then
   records[p]=Effects.New(folder,item.Weather,item.Mech);created+=1
  end
 end
 local t=workspace:GetServerTimeNow();local stepped=false
 for p,e in pairs(records)do
  if p.Parent and visible(p)then Effects.Step(e,p.CFrame*CFrame.new(p:GetAttribute('EffectOffset')or Vector3.zero),p:GetAttribute('EffectRadius'),p:GetAttribute('EffectHeight'),t,nil,batch);stepped=true
  else Effects.Destroy(e);records[p]=nil end
 end
 if stepped then batch:Flush()end
end)
-- (R154: the seed lands, or its hold ends: the next frame looks again instead of up to .3 s later; nothing runs per frame for it)
local landed=Collect and Collect.OnRelease(function()scan=1 end)
script.Destroying:Connect(function()c:Disconnect();added:Disconnect();removed:Disconnect();if landed then landed:Disconnect()end;folder:Destroy();table.clear(records);table.clear(targets);table.clear(pending)end)
