do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R127 (owner): mutation highlights.
--  * A seed pack that weather mutates carries a server Highlight (tag MutationGlow) that every player sees; here it pulses
--    and hides while the pack is taken.
--  * When weather mutates one of MY plants or fruits, that plant (or the fruit itself) gets a rainbow neon outline and a
--    rainbow label naming it, for a few seconds. Only the owner gets the WeatherAdopted 'Owned' notice, so only they see it.
local RS=game:GetService('ReplicatedStorage');local Players=game:GetService('Players');local Run=game:GetService('RunService')
local CS=game:GetService('CollectionService')
local Glow=require(RS:WaitForChild('MutationGlow127'));local Weather=require(RS:WaitForChild('WeatherTraits'))
local Names=require(RS:WaitForChild('GardenDisplayNames'));local Catalog=require(RS:WaitForChild('PlantCatalog'))
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui')
local Emoji={Drippy='💧',Frosted='❄️',Charged='⚡'}
local glows={};local plants={};local loop;local clock=0;local alive=true
local folder=Instance.new('Folder');folder.Name='MutationLabels';folder.Parent=pg
local function anyActive()return next(glows)~=nil or #plants>0 end
local step
local function ensureLoop()if not loop and alive and anyActive()then loop=Run.RenderStepped:Connect(function(dt)step(dt)end)end end
-- Pack glows (server Highlights) --------------------------------------------------------------------------------------
local function addGlow(h)
 if not h:IsA('Highlight')then return end
 glows[h]={Fill=h.FillTransparency,Outline=h.OutlineTransparency};ensureLoop()
end
local function removeGlow(h)glows[h]=nil end
-- My plants -------------------------------------------------------------------------------------------------------------
local plots;local plotsAt=-math.huge
local function cropModel(id)
 local map=workspace:FindFirstChild('ChestChaseMap');if not map then return nil end
 local name='Crop_'..id
 if plots then for _,p in ipairs(plots)do if p.Parent and p:GetAttribute('GardenOwnerId')==player.UserId then local m=p:FindFirstChild(name);if m then return m end end end end
 if os.clock()-plotsAt<2 then return nil end;plotsAt=os.clock() -- full map scan at most every 2 s
 plots={};for _,d in ipairs(map:GetDescendants())do if d:IsA('BasePart')and d:GetAttribute('GardenPlantCount')~=nil then table.insert(plots,d)end end
 for _,p in ipairs(plots)do if p:GetAttribute('GardenOwnerId')==player.UserId then local m=p:FindFirstChild(name);if m then return m end end end
 return nil
end
local function fruitModel(model,index)
 local art=model:FindFirstChild('LocalPlantArt');if not art then return nil end
 for _,d in ipairs(art:GetDescendants())do if d:IsA('Model')and d.Name=='Harvest_'..index and d:GetAttribute('HarvestIndex')==index then return d end end
 return nil
end
local function makeLabel(entry)
 local gui=Instance.new('BillboardGui');gui.Name='Mutation_'..entry.CropId;gui.AlwaysOnTop=true;gui.LightInfluence=0;gui.MaxDistance=math.huge -- R129: seen through walls from any distance
 gui.Size=UDim2.fromOffset(300,64);gui.ResetOnSpawn=false;gui.Parent=folder
 local text=Instance.new('TextLabel');text.Name='Text';text.BackgroundTransparency=1;text.Size=UDim2.fromScale(1,1);text.Font=Enum.Font.FredokaOne
 text.TextScaled=true;text.TextColor3=Color3.new(1,1,1);text.Text=entry.Text;text.Parent=gui
 local fit=Instance.new('UITextSizeConstraint');fit.MaxTextSize=30;fit.MinTextSize=12;fit.Parent=text
 local edge=Instance.new('UIStroke');edge.Color=Color3.fromRGB(20,10,40);edge.Thickness=3;edge.Parent=text
 local shine=Instance.new('UIGradient');shine.Name='Rainbow';shine.Parent=text
 local pop=Instance.new('UIScale');pop.Scale=.4;pop.Parent=gui
 entry.Label=gui;entry.Text_=text;entry.Edge=edge;entry.Shine=shine;entry.Pop=pop
end
local function resolve(entry)
 local model=cropModel(entry.CropId)
 if not model then return false end
 local targets={}
 -- At most two fruit outlines per plant keeps every client well under Roblox's 31-highlight limit.
 if not entry.Plant then for _,i in ipairs(entry.Fruits)do local f=fruitModel(model,i);if f and #targets<2 then table.insert(targets,f)end end end
 if #targets==0 then targets={model}end
 for _,h in ipairs(entry.Highlights)do h:Destroy()end;table.clear(entry.Highlights)
 for _,t in ipairs(targets)do
  local h=Instance.new('Highlight');h.Name='MutationRainbow';h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
  h.FillTransparency=.3;h.OutlineTransparency=0;h.Adornee=t;h.Parent=t;table.insert(entry.Highlights,h)
 end
 entry.Model=model
 local anchor=model.PrimaryPart or model:FindFirstChildWhichIsA('BasePart')
 local ok,size=pcall(function()return model:GetExtentsSize()end)
 entry.Label.Adornee=anchor;entry.Label.StudsOffsetWorldSpace=Vector3.new(0,(ok and size and size.Y or 6)+2.5,0)
 return true
end
local function finish(entry)
 for _,h in ipairs(entry.Highlights)do h:Destroy()end;table.clear(entry.Highlights)
 if entry.Label then entry.Label:Destroy()end
end
local function addPlant(item,trait)
 local def=Catalog[item.SeedId];if not def then return end
 for i=#plants,1,-1 do if plants[i].CropId==item.CropId then finish(plants[i]);table.remove(plants,i)end end
 while #plants>=Glow.MaxLocal do finish(plants[1]);table.remove(plants,1)end
 local name=item.Plant and Names.Plant(item.SeedId,def.Name)or Names.Fruit(item.SeedId,def.HarvestName)
 local entry={CropId=item.CropId,Plant=item.Plant,Fruits=item.Fruits,Highlights={},Age=0,Retry=0,Trait=trait,
  Text=(Emoji[Weather.List(trait)[1]]or'✨')..' '..Weather.Display(trait)..' '..name..'!'}
 makeLabel(entry);resolve(entry);table.insert(plants,entry);ensureLoop()
end
local function onNotice(m)
 if not alive or type(m)~='table'or m.Kind~='WeatherAdopted'or m.Scope~='Owned'or type(m.Items)~='table'then return end
 local trait=Weather.Key(m.Trait);if Weather.Count(trait)<1 then return end
 for _,item in ipairs(Glow.Items(m.Items,Catalog))do addPlant(item,trait)end
end
-- Frame step: pack glows pulse; plant rainbows cycle, pop in, fade out, and re-find their plant if its art was rebuilt.
function step(dt)
 clock+=dt
 local now=workspace:GetServerTimeNow();local pulse=.5+.5*math.sin(clock*4)
 for h,base in pairs(glows)do
  if not h.Parent then glows[h]=nil;continue end
  local host=h.Parent;local hidden=host:GetAttribute('PackVisible')==false
  local left=(h:GetAttribute('Until')or now+99)-now;local fade=math.clamp(left/Glow.FadeSeconds,0,1)
  h.Enabled=not hidden and left>0
  h.FillTransparency=1-(1-(.25+.3*pulse))*fade;h.OutlineTransparency=1-(1-base.Outline)*fade
 end
 for i=#plants,1,-1 do
  local e=plants[i];e.Age+=dt
  if e.Age>=Glow.PlantSeconds then finish(e);table.remove(plants,i);continue end
  local alivePart=e.Model and e.Model.Parent and #e.Highlights>0 and e.Highlights[1].Parent
  if not alivePart then e.Retry-=dt;if e.Retry<=0 then e.Retry=.5;resolve(e)end end
  local fade=math.clamp((Glow.PlantSeconds-e.Age)/Glow.FadeSeconds,0,1)
  local c1,c2=Glow.Rainbow(clock),Glow.Rainbow(clock,.5)
  for _,h in ipairs(e.Highlights)do h.FillColor=c1;h.OutlineColor=c2;h.FillTransparency=1-.7*fade;h.OutlineTransparency=1-fade end
  e.Pop.Scale=math.min(1,.4+e.Age*3)*(1+.05*math.sin(clock*5))
  e.Text_.TextTransparency=1-fade;e.Edge.Transparency=1-fade
  local keys={};for k=0,6 do keys[k+1]=ColorSequenceKeypoint.new(k/6,Glow.Rainbow(clock,k/6))end
  e.Shine.Color=ColorSequence.new(keys)
 end
 if not anyActive()and loop then loop:Disconnect();loop=nil end
end
for _,h in ipairs(CS:GetTagged(Glow.Tag))do addGlow(h)end
local conns={CS:GetInstanceAddedSignal(Glow.Tag):Connect(addGlow),CS:GetInstanceRemovedSignal(Glow.Tag):Connect(removeGlow)}
task.spawn(function()
 local remotes=RS:WaitForChild('ChestChaseRemotes');local remote=remotes:WaitForChild('WeatherAdopted')
 if alive then table.insert(conns,remote.OnClientEvent:Connect(onNotice))end
end)
script.Destroying:Connect(function()
 alive=false;for _,c in ipairs(conns)do c:Disconnect()end;if loop then loop:Disconnect()end
 for _,e in ipairs(plants)do finish(e)end;table.clear(plants);folder:Destroy()
end)
