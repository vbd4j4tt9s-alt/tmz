do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local H=require(RS:WaitForChild('HarvestPresentation'));local Rig=require(RS:WaitForChild('HeldHarvestRig'));local Visuals=require(RS:WaitForChild('PlantVisuals'))
local Catalog=require(RS:WaitForChild('PlantCatalog'));local retry=setmetatable({},{__mode='k'})
local function equipped(tool)return tool.Parent and Players:GetPlayerFromCharacter(tool.Parent)~=nil end
local Planner=require(RS:WaitForChild('PlantDetailPlanner'))
local player=Players.LocalPlayer;local states={};local selected={};local job;local scanClock=1
local function dispose(tool)
 local s=states[tool];if s then if s.Rig then Rig.Destroy(s.Rig)end;states[tool]=nil end
end
local function cancel()
 if not job then return end
 for _,m in ipairs(job.Models)do if not m.Parent then m:Destroy()end end
 if coroutine.status(job.Thread)~='dead'then coroutine.close(job.Thread)end
 job=nil
end
local function item(tool)
 return {SeedId=tool:GetAttribute('SeedId'),InventoryId=tool:GetAttribute('HarvestInventoryId'),Mutation=tool:GetAttribute('Mutation'),Weather=tool:GetAttribute('Weather'),FruitScale=tool:GetAttribute('FruitScale'),VisualCrop={SourceCropId=tool:GetAttribute('SourceCropId'),FruitIndex=tool:GetAttribute('FruitIndex'),HarvestCycle=tool:GetAttribute('HarvestCycle')}}
end
local function scan()
 local camera=workspace.CurrentCamera;if not camera then return end
 local list={};local view=Planner.View(camera)
 for _,p in ipairs(Players:GetPlayers())do
  local character=p.Character;local tool=character and character:FindFirstChildOfClass('Tool');local root=character and character:FindFirstChild('HumanoidRootPart')
  if tool and root and tool:GetAttribute('HarvestItemTool')and tool:FindFirstChild('Handle')and Catalog[tool:GetAttribute('SeedId')]then
   local distance=(root.Position-camera.CFrame.Position).Magnitude
   local def=Catalog[tool:GetAttribute('SeedId')];local index=tool:GetAttribute('FruitIndex')or 1
   local radius=(def.FruitRadii[index]or def.Radius)*(tool:GetAttribute('FruitScale')or 1)
   local visible,pixels=Planner.Coverage(camera,root.Position,radius,view)
   local range=math.max(220,math.min(Planner.FarRange,radius*18))
   if p==player or(visible and distance-radius<range)then
    local i=item(tool);local meta=Visuals.Metadata(i.SeedId);local cost=8
    for _,s in ipairs(meta.Groups[i.VisualCrop.FruitIndex or 1]or{})do cost+=Visuals.PartCost(s)end
    table.insert(list,{Tool=tool,Distance=distance,Score=p==player and -1 or distance/math.max(1,pixels/60),Cost=cost})
   end
  end
 end
 table.sort(list,function(a,b)return a.Score<b.Score end);selected={};local cost,count=0,0
 for _,e in ipairs(list)do if count<6 and cost+e.Cost<=900 then selected[e.Tool]=e;cost+=e.Cost;count+=1 end end
 for tool in pairs(states)do if not selected[tool]then dispose(tool)end end
 if job and not selected[job.Tool]then cancel()end
 if Run:IsStudio()then player:SetAttribute('HeldHarvestModels',count);player:SetAttribute('HeldHarvestBudget',cost)end
end
-- R153 (owner: "fix all jittery type effects"): one RenderStepped step a frame. A held fruit's own motion (the jaw, the bells, the idle sway: its
-- joints' Transform, applied in PreSimulation below) and its effects follow the hand every rendered frame; the joints used to change at 20 Hz.
-- Bounded by the selection: 6 held fruits (900 parts), effects for the 3 nearest within 90 studs.
local connection=Run.RenderStepped:Connect(function(dt)
 for tool in pairs(states)do if not equipped(tool)then dispose(tool)end end
 scanClock+=dt;if scanClock>=.25 then scanClock=0;scan()end
 if job and(not equipped(job.Tool)or not selected[job.Tool])then cancel()end
 if not job then
  for tool,e in pairs(selected)do if not states[tool]and equipped(tool)and os.clock()>=(retry[tool]or 0) then
   local current={Tool=tool,Models={}};local work={Model=function(m)table.insert(current.Models,m)end}
   work.BeforePart=function(cost)if current.Parts<cost or os.clock()>current.Deadline then coroutine.yield()end;current.Parts-=cost end
   current.Thread=coroutine.create(function()
    local model,crop,index=H.Build(item(tool),{WorldSize=true,Work=work})
    if not equipped(tool)or not selected[tool]or not tool:FindFirstChild('Handle')then model:Destroy();return end
    states[tool]={Rig=Rig.Create(model,crop,index,tool.Handle)}
   end);job=current;break
  end end
 end
 if job then
  local own=job.Tool.Parent==player.Character;job.Parts=own and 64 or 16;job.Deadline=os.clock()+(own and .003 or .001);local okay,why=coroutine.resume(job.Thread)
  if not okay then retry[job.Tool]=os.clock()+5;warn('[V149] Held fruit: '..tostring(why));cancel()
  elseif coroutine.status(job.Thread)=='dead'then job=nil end
 end
 local now=workspace:GetServerTimeNow();local fx=0
 debug.profilebegin('Held fruit animation')
 for tool,state in pairs(states)do local e=selected[tool];if e and state.Rig and equipped(tool)then
  local effects=e.Distance<90 and fx<3;if effects then fx+=1 end;Rig.Step(state.Rig,now,effects,effects and e.Distance<32)
 end end
 debug.profileend()
end)
-- R153 (owner: "i need to put in inputs twice to equip something"): the fruit you just took out used to show up to a second later (a scan every 0.25 s, then
-- 16 parts a frame), so a second press put it away again. Your own new fruit is scanned at once and built 4x faster; everyone else's is unchanged.
local ownLink
local function own(character)
 if ownLink then ownLink:Disconnect();ownLink=nil end
 if character then ownLink=character.ChildAdded:Connect(function(c)if c:IsA('Tool')and c:GetAttribute('HarvestItemTool')then scanClock=1 end end)end
end
local ownAdded=player.CharacterAdded:Connect(own);own(player.Character)
local jointConnection=Run.PreSimulation:Connect(function()for tool,s in pairs(states)do if equipped(tool)and s.Rig then Rig.Apply(s.Rig)end end end)
script.Destroying:Connect(function()connection:Disconnect();jointConnection:Disconnect();ownAdded:Disconnect();own(nil);cancel();for tool in pairs(states)do dispose(tool)end end)
