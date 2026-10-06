do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
local Fx=require(game:GetService('ReplicatedStorage'):WaitForChild('ClientFxBudget'))
-- R72: screen-aware, part-budgeted effects with staggered creation and one transform batch.
local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService');local Tags=game:GetService('CollectionService');local Players=game:GetService('Players')
local Weather=require(RS.WeatherTraits);local Effects=require(RS.ItemVisualEffects);local Budget=require(RS.CosmeticBudget);local View=require(RS.PlantDetailPlanner)
local Batch=require(RS.PlantAnimationBatch);local batch=Batch.new(workspace);local player=Players.LocalPlayer
local folder=Instance.new('Folder');folder.Name='_ItemCosmeticsR59';folder.Parent=workspace
local targets={};local records={};local selected={};local pending={};local pendingIndex=1;local scan=1;local elapsed=0
local function remove(p)targets[p]=nil;selected[p]=nil;if records[p]then Effects.Destroy(records[p]);records[p]=nil end end
local function add(p)if p:IsA('BasePart')then targets[p]=true end end
for _,p in ipairs(Tags:GetTagged('GardenItemFX'))do add(p)end
local added=Tags:GetInstanceAddedSignal('GardenItemFX'):Connect(add);local removed=Tags:GetInstanceRemovedSignal('GardenItemFX'):Connect(remove)
-- R128 (owner): an item someone is carrying (inside a character) has its effect stepped every frame so the rings
-- and orbits stay on it while running; items lying in the world keep the cheaper 20 Hz (10 Hz low) animation.
local function carried(p)local m=p:FindFirstAncestorOfClass('Model');while m do if m:FindFirstChildOfClass('Humanoid')then return true end;m=m:FindFirstAncestorOfClass('Model')end;return false end
local function visible(p)
 if not p:IsDescendantOf(workspace)then return false end
 local a=p.Parent
 while a and a~=workspace do
  if a:GetAttribute('PackVisible')==false or a:GetAttribute('RevealAt')then return false end
  a=a.Parent
 end
 return true
end
local c=Run.Heartbeat:Connect(function(dt)
 scan+=dt;elapsed+=dt;local camera=workspace.CurrentCamera;if not camera then return end
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
   if records[p]then records[p].Carried=carried(p)end
  end
  for p,e in pairs(records)do if not selected[p]then Effects.Destroy(e);records[p]=nil end end
 end
 -- Cap allocations on each heartbeat instead of creating an entire crowd in one scan.
 local created=0;local createLimit=low and 1 or 2
 while pendingIndex<=#pending and created<createLimit do
  local item=pending[pendingIndex];pendingIndex+=1;local p=item.Part
  if selected[p]and not records[p]and p.Parent and visible(p)then
   records[p]=Effects.New(folder,item.Weather,item.Mech);records[p].Carried=carried(p);created+=1
  end
 end
 local full=elapsed>=(low and .1 or .05);if full then elapsed=0 end;local t=workspace:GetServerTimeNow();local stepped=false
 for p,e in pairs(records)do
  if full or e.Carried then
   if p.Parent and visible(p)then Effects.Step(e,p.CFrame*CFrame.new(p:GetAttribute('EffectOffset')or Vector3.zero),p:GetAttribute('EffectRadius'),p:GetAttribute('EffectHeight'),t,nil,batch);stepped=true
   else Effects.Destroy(e);records[p]=nil end
  end
 end
 if stepped then batch:Flush()end
end)
script.Destroying:Connect(function()c:Disconnect();added:Disconnect();removed:Disconnect();folder:Destroy();table.clear(records);table.clear(targets);table.clear(pending)end)
