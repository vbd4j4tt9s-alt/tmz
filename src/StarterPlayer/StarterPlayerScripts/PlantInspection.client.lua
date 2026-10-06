do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R53: one selected plant; the pointer chooses its individual ripe fruit.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Input=game:GetService('UserInputService');local Prompts=game:GetService('ProximityPromptService')
local Names=require(RS:WaitForChild('GardenDisplayNames'));local Theme=require(RS:WaitForChild('GardenTheme'));local Catalog=require(RS:WaitForChild('PlantCatalog'));local Growth=require(RS:WaitForChild('PlantGrowth'))
local Rules=require(RS:WaitForChild('PlantRules'));local Traits=require(RS.ItemTraitNames) -- (R152: selecting a plant is silent; R150 clicked Bubble04 for it)
local fruitTarget=require(RS:WaitForChild('FruitCursorTarget')).new();local touchPointer;local overHarvest=false
local Picker=require(RS:WaitForChild('PlantShovelPicker'));local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui')
local picker,releasePicker=Picker.Acquire(workspace:WaitForChild('ChestChaseMap'))
local gui=Instance.new('ScreenGui');gui.Name='PlantInspection';gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=24;gui.Parent=pg
local connections={};local function connect(signal,fn)table.insert(connections,signal:Connect(fn))end
local function label(parent,name,y,height,size)
 local t=Instance.new('TextLabel');t.Name=name;t.BackgroundTransparency=1;t.Position=UDim2.fromOffset(12,y);t.Size=UDim2.new(1,-24,0,height);t.TextXAlignment=Enum.TextXAlignment.Left;t.TextWrapped=false;t.Text='';Theme.Text(t,size,false);t.Parent=parent;return t
end
local function panel(name,width,height)
 local p=Instance.new('Frame');p.Name=name;p.Size=UDim2.fromOffset(width,height);p.BackgroundColor3=Theme.Colors.Panel;p.BackgroundTransparency=.08;p.BorderSizePixel=0;p.Visible=false;p.Parent=gui;Theme.Corner(p,10)
 Theme.CardBorder(p,'Common');return p -- R123: rarity border (set per fruit) instead of a plain edge
end
local indicator=Instance.new('BillboardGui');indicator.Name='SelectedPlant';indicator.Size=UDim2.fromOffset(228,46);indicator.Enabled=false;indicator.AlwaysOnTop=true;indicator.LightInfluence=0;indicator.MaxDistance=math.huge;indicator.ClipsDescendants=false;indicator.Parent=pg
local title=Instance.new('Frame');title.Name='Title';title.AnchorPoint=Vector2.new(.5,0);title.Position=UDim2.fromScale(.5,0);title.Size=UDim2.fromOffset(204,23);title.BackgroundTransparency=1;title.Parent=indicator
local nameLabel=label(title,'PlantName',0,23,14);nameLabel.Position=UDim2.fromOffset(0,0);nameLabel.Size=UDim2.fromScale(1,1);nameLabel.TextScaled=true;nameLabel.TextXAlignment=Enum.TextXAlignment.Center -- R123: no emblem; the name takes the whole title
local fit=Instance.new('UITextSizeConstraint');fit.MinTextSize=12;fit.MaxTextSize=14;fit.Parent=nameLabel
local plantTraits=label(indicator,'PlantTraits',24,0,11);plantTraits.TextWrapped=true;plantTraits.TextXAlignment=Enum.TextXAlignment.Center;plantTraits.TextYAlignment=Enum.TextYAlignment.Top
local timer=label(indicator,'GrowthTime',24,20,12);timer.TextXAlignment=Enum.TextXAlignment.Center;timer.TextStrokeColor3=Color3.new(0,0,0);timer.TextStrokeTransparency=.25
local selected,selectedAnchor;local targetHeight=1;local displayedHeight=1;local nextMeasure=0;local lastProgress
local harvestWorld=Instance.new('BillboardGui');harvestWorld.Name='HarvestFruit';harvestWorld.Size=UDim2.fromOffset(220,50);harvestWorld.Enabled=false;harvestWorld.Active=true;harvestWorld.AlwaysOnTop=true;harvestWorld.LightInfluence=0;harvestWorld.MaxDistance=math.huge;harvestWorld.SizeOffset=Vector2.new(0,.5);harvestWorld.StudsOffset=Vector3.new(0,.25,0);harvestWorld.StudsOffsetWorldSpace=Vector3.new(0,.25,0);harvestWorld.Parent=pg
local harvest=panel('Harvest',220,50);harvest.Parent=harvestWorld;harvest.Position=UDim2.fromOffset(0,0)
local harvestName=label(harvest,'FruitName',3,17,13);harvestName.Position=UDim2.fromOffset(46,3);harvestName.Size=UDim2.new(1,-52,0,17);harvestName.TextScaled=true
local harvestFit=Instance.new('UITextSizeConstraint');harvestFit.MinTextSize=10;harvestFit.MaxTextSize=13;harvestFit.Parent=harvestName
local traits=label(harvest,'FruitTraits',21,13,10);traits.Position=UDim2.fromOffset(46,21);traits.Size=UDim2.new(1,-52,0,13);traits.TextScaled=true;traits.TextWrapped=true;traits.TextYAlignment=Enum.TextYAlignment.Top
local traitsFit=Instance.new('UITextSizeConstraint');traitsFit.MinTextSize=9;traitsFit.MaxTextSize=10;traitsFit.Parent=traits
local action=label(harvest,'Action',36,11,10);action.Position=UDim2.fromOffset(46,36);action.Size=UDim2.new(1,-52,0,11);action.TextColor3=Theme.Colors.Mint
local keyButton=Instance.new('TextButton');keyButton.Name='HarvestKey';keyButton:SetAttribute('ButtonSound',false);keyButton.Position=UDim2.fromOffset(7,8);keyButton.Size=UDim2.fromOffset(34,34);keyButton.BackgroundColor3=Theme.Colors.Card;keyButton.Text='E';Theme.Text(keyButton,17,true);keyButton.Parent=harvest;Theme.Corner(keyButton,7)
local edge=Instance.new('UIStroke');edge.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;edge.Color=Color3.new(1,1,1);edge.Transparency=.25;edge.Parent=keyButton
local displayedPrompt;local shown={};local currentPrompt;local lastTraits
connect(harvest.MouseEnter,function()overHarvest=true end);connect(harvest.MouseLeave,function()overHarvest=false end)
local selectionView=require(RS:WaitForChild('PlantSelectionView')).new('PlantSelection',Color3.new(1,1,1),.90,.20)
local selectedPart
local fruitFocus=Instance.new('Highlight');fruitFocus.Name='HoveredHarvestFruit';fruitFocus.FillColor=Color3.new(1,1,1);fruitFocus.OutlineColor=Color3.new(1,1,1);fruitFocus.FillTransparency=.88;fruitFocus.OutlineTransparency=.12;fruitFocus.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop;fruitFocus.Enabled=false;fruitFocus.Parent=workspace
local function available()
 local char=player.Character;local hum=char and char:FindFirstChildOfClass('Humanoid');local tool=char and char:FindFirstChildOfClass('Tool')
 return char and hum and hum.Health>0 and not pg:GetAttribute('SeedMenu')and not Input:GetFocusedTextBox()and not(tool and tool:GetAttribute('GardenShovel'))
end
local function cropData(model)return require(RS.GardenViewState).Read(model)end
local function plantTraitLabel(model)
 local item={Mutation=model:GetAttribute('Mutation'),Weather=model:GetAttribute('Weather')}
 local text,lines=Traits.Lines(item,26);plantTraits.Text=text;plantTraits.Visible=lines>0;Traits.Style(plantTraits,item)
 local height=lines*13;plantTraits.Size=UDim2.new(1,-24,0,height)
 timer.Position=UDim2.fromOffset(12,24+height);indicator.Size=UDim2.fromOffset(228,46+height)
end
local function ownedPrompt(prompt)
 return selected and pg:GetAttribute('SelectedGardenCropId')==prompt:GetAttribute('GardenCropId') and prompt:GetAttribute('GardenCropId')==selected:GetAttribute('CropId') and prompt.Parent and prompt.Enabled and prompt:GetAttribute('GardenPrompt')and prompt:GetAttribute('GardenStage')==4 and prompt:GetAttribute('GardenFruitIndex')and prompt:GetAttribute('GardenOwnerId')==player.UserId
end
connect(Prompts.PromptShown,function(prompt,inputType)
 if ownedPrompt(prompt)then shown[prompt]=inputType end
end)
connect(Prompts.PromptHidden,function(prompt)shown[prompt]=nil;if currentPrompt==prompt then currentPrompt=nil;harvest.Visible=false end end)
connect(keyButton.Activated,function()
 local p=currentPrompt;if p and harvest.Visible and available()and ownedPrompt(p)then p:InputHoldBegin();p:InputHoldEnd()end
end)
local function fruitAnchor(prompt)
 local art=selected and selected:FindFirstChild('LocalPlantArt')
 local index=prompt:GetAttribute('GardenFruitIndex')
 local group=art and art:FindFirstChild('Harvest_'..tostring(index))
 local native=prompt.Parent
 if not group then return native,.25 end
 local position=native:IsA('Attachment')and native.WorldPosition or native.Position
 local target,distance=nil,math.huge;local top=position.Y
 for _,part in ipairs(group:GetDescendants())do
  if part:IsA('BasePart')and part.Transparency<.95 and part.Name~='Effect anchor'and not part:FindFirstAncestor('ApprovedFruitEffects')then
   local z,f=part.Size,part.CFrame
   top=math.max(top,part.Position.Y+(math.abs(f.RightVector.Y)*z.X+math.abs(f.UpVector.Y)*z.Y+math.abs(f.LookVector.Y)*z.Z)*.5)
   local gap=(part.Position-position).Magnitude
   if gap<distance then distance=gap;target=part end
  end
 end
 local chosen=target or native;local y=chosen:IsA('Attachment')and chosen.WorldPosition.Y or chosen.Position.Y
 return chosen,math.max(.25,top-y+.25)
end
local function clearSelection()
 if selected or pg:GetAttribute('SelectedGardenCropId')then
  pg:SetAttribute('SelectedGardenFruitIndex',nil);fruitTarget:Clear();overHarvest=false
  pg:SetAttribute('SelectedGardenCropId',nil);pg:SetAttribute('GardenSelectionEpoch',(pg:GetAttribute('GardenSelectionEpoch')or 0)+1)
 end
 harvest.Visible=false;harvestWorld.Enabled=false;harvestWorld.Adornee=nil;currentPrompt=nil;displayedPrompt=nil;lastTraits=nil
 fruitFocus.Enabled=false;fruitFocus.Adornee=nil
 selected=nil;selectedAnchor=nil;indicator.Enabled=false;indicator.Adornee=nil;selectionView:Clear();selectedPart=nil;lastProgress=nil
end
local function valid(model)
 if not model or not model.Parent then return false end
 local def=Catalog[model:GetAttribute('SeedId')];local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 if not def or not root then return false end
 return picker:WithinRange(model,root.Position,90)
end
local function topHeight(model,anchor)
 local top=anchor.Position.Y+.3
 for _,part in ipairs(model:GetDescendants())do
  if part:IsA('BasePart')and part.Transparency<.95 and part.LocalTransparencyModifier<.95 and not part:FindFirstAncestor('PlantRarityEffects')then
   local size=part.Size;local frame=part.CFrame
   local half=(math.abs(frame.RightVector.Y)*size.X+math.abs(frame.UpVector.Y)*size.Y+math.abs(frame.LookVector.Y)*size.Z)*.5
   top=math.max(top,part.Position.Y+half)
  end
 end
 return math.max(.8,top-anchor.Position.Y+.65)
end
local function selectAt(pointer)
 if not available()then return end
 touchPointer=pointer
 local camera=workspace.CurrentCamera;if not camera then return end
 local ray=camera:ViewportPointToRay(pointer.X,pointer.Y)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances=picker:RayExclusions(player.Character);params.IgnoreWater=true
 local hit=workspace:Raycast(ray.Origin,ray.Direction*500,params)
 local target,hitPart=picker:Pick(ray.Origin,ray.Direction,500,hit)
 -- A new seed can be smaller than one screen pixel. Resolve a tap near its soil position.
 if not target and hit and hit.Instance:GetAttribute('GardenSoil')then
  local distance=1.6
  for _,model in ipairs(hit.Instance:GetChildren())do
   if model:GetAttribute('GardenPlantV141')and valid(model)then
    local at=model:GetPivot():PointToObjectSpace(hit.Position);local gap=math.sqrt(at.X*at.X+at.Z*at.Z)
    if gap<distance then distance=gap;target=model end
   end
  end
 end
 if not valid(target)then clearSelection();return end
 local anchor=target:FindFirstChild('CropAnchor')or target.PrimaryPart
 if not anchor then clearSelection();return end
 selected=target;selectedAnchor=anchor;local id=target:GetAttribute('SeedId');local def=Catalog[id]
 nameLabel.Text=Names.Plant(id,def.Name);Theme.RarityText(nameLabel,def.Rarity,14);plantTraitLabel(target)
 -- Compact centered title, lettering only (R123: rarity emblems removed).
 title.Size=UDim2.fromOffset(math.clamp(#nameLabel.Text*8+8,72,204),23)
 targetHeight=topHeight(target,anchor);displayedHeight=targetHeight;lastProgress=nil
 indicator.Adornee=anchor;indicator.StudsOffsetWorldSpace=Vector3.new(0,displayedHeight+.3,0);indicator.Enabled=true
 selectedPart=hitPart;selectionView:Set(target,selectedPart,camera)
 harvest.Visible=false;harvestWorld.Enabled=false;harvestWorld.Adornee=nil;currentPrompt=nil;displayedPrompt=nil;lastTraits=nil
 pg:SetAttribute('SelectedGardenFruitIndex',nil);
 pg:SetAttribute('SelectedGardenCropId',target:GetAttribute('CropId'));pg:SetAttribute('GardenSelectionEpoch',(pg:GetAttribute('GardenSelectionEpoch')or 0)+1)
 local text=Growth.Timer(cropData(target),def,workspace:GetServerTimeNow());timer.Text=text
end
local mouseDown
connect(Input.InputBegan,function(input,processed)
 if processed or Input:GetFocusedTextBox()then return end
 if input.UserInputType==Enum.UserInputType.MouseButton1 then mouseDown=Input:GetMouseLocation()
 elseif input.KeyCode==Enum.KeyCode.Escape then clearSelection()
 elseif input.KeyCode==Enum.KeyCode.ButtonL3 and available()and workspace.CurrentCamera then selectAt(workspace.CurrentCamera.ViewportSize/2)end
end)
connect(Input.InputEnded,function(input,processed)
 if input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
 local start=mouseDown;mouseDown=nil;local pointer=Input:GetMouseLocation()
 if start and not processed and(pointer-start).Magnitude<=8 then selectAt(pointer)end
end)
connect(Input.TouchTapInWorld,function(position,processed)if not processed then selectAt(position)end end)
local elapsed=0
connect(Run.Heartbeat,function(dt)
 if selected and indicator.Enabled and displayedHeight~=targetHeight then
  displayedHeight+=(targetHeight-displayedHeight)*math.min(1,dt*5)
  indicator.StudsOffsetWorldSpace=Vector3.new(0,displayedHeight+.3,0)
 end
 elapsed+=dt;if elapsed<.05 then return end;elapsed=0
 local camera=workspace.CurrentCamera
 if not camera or not available()then clearSelection();harvest.Visible=false;currentPrompt=nil;return end
 local view=camera.ViewportSize;local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 if selected then
  if not valid(selected)or not selectedAnchor or not selectedAnchor.Parent then clearSelection()
  else
   selectionView:Set(selected,selectedPart,camera);plantTraitLabel(selected)
   local def=Catalog[selected:GetAttribute('SeedId')];local text,progress=Growth.Timer(cropData(selected),def,workspace:GetServerTimeNow());timer.Text=text
   -- The mature label never bobs with animated foliage. Re-measure only actual growth.
   if progress~=lastProgress and os.clock()>=nextMeasure then targetHeight=topHeight(selected,selectedAnchor);lastProgress=progress;nextMeasure=os.clock()+.5 end
  end
 end
 local device=tostring(Input:GetLastInputType())
 local pointer=device:find('Gamepad',1,true)and camera.ViewportSize/2 or(device:find('Touch',1,true)and touchPointer)or Input:GetMouseLocation()
 if not(overHarvest and currentPrompt and ownedPrompt(currentPrompt))then
  local focus
  currentPrompt,focus=fruitTarget:Pick(selected,camera,pointer,root and root.Position or Vector3.zero,player.UserId)
  if focus then selectedPart=focus end
 end
 local fruitIndex=currentPrompt and currentPrompt:GetAttribute('GardenFruitIndex')or nil
 if pg:GetAttribute('SelectedGardenFruitIndex')~=fruitIndex then pg:SetAttribute('SelectedGardenFruitIndex',fruitIndex)end
 local focusArt=selected and selected:FindFirstChild('LocalPlantArt')
 fruitFocus.Adornee=currentPrompt and focusArt and focusArt:FindFirstChild('Harvest_'..tostring(fruitIndex))or nil;fruitFocus.Enabled=fruitFocus.Adornee~=nil
 harvest.Visible=currentPrompt~=nil;harvestWorld.Enabled=harvest.Visible
 if not currentPrompt then harvestWorld.Adornee=nil end
 if currentPrompt then
  keyButton.Text=device:find('Touch',1,true)and'Tap'or device:find('Gamepad',1,true)and'X'or'E'
  local localArt=selected:FindFirstChild('LocalPlantArt')
  local group=localArt and localArt:FindFirstChild('Harvest_'..tostring(currentPrompt:GetAttribute('GardenFruitIndex')))
  local target=harvestWorld.Adornee
  if displayedPrompt~=currentPrompt or not target or not target.Parent or(group and not target:IsDescendantOf(group))then
   local anchor,height=fruitAnchor(currentPrompt);harvestWorld.Adornee=anchor;harvestWorld.StudsOffsetWorldSpace=Vector3.new(0,height,0)
  end
  if displayedPrompt~=currentPrompt then
   displayedPrompt=currentPrompt;local model=Picker.Plant(currentPrompt);local def=model and Catalog[model:GetAttribute('SeedId')];local rarity=def and def.Rarity or'Common'
   local fruitName=def and Names.Fruit(model:GetAttribute('SeedId'),def.HarvestName)
   harvestName.Text=fruitName or currentPrompt.ObjectText;Theme.RarityText(harvestName,rarity,13);Theme.CardBorder(harvest,rarity) -- R123: the panel border carries the rarity

  end
  local crop=cropData(selected);local def=Catalog[crop.SeedId];local fruit=Rules.Fruit(crop,currentPrompt:GetAttribute('GardenFruitIndex'),def)
  local panelWidth=math.min(220,view.X-24)
  local text,lines=Traits.Lines(fruit,math.max(8,math.floor((panelWidth-52)/6.5)));if text==''then text='Normal';lines=1 end
  Traits.Style(traits,fruit)
  if def.Regrows==false or def.Mode=='whole'then text..='\nSingle harvest';lines+=1 end
  if lastTraits~=text then traits.Text=text;lastTraits=text end
  action.Text=(keyButton.Text=='E'and'Press E'or keyButton.Text)..' to harvest'
  local traitHeight=13*lines;traits.Size=UDim2.new(1,-52,0,traitHeight);action.Position=UDim2.fromOffset(46,23+traitHeight)
  local size=UDim2.fromOffset(panelWidth,37+traitHeight)
  if harvest.Size~=size then harvest.Size=size;harvestWorld.Size=size end
 end
end)
script.Destroying:Connect(function()
 clearSelection();fruitFocus:Destroy();fruitTarget:Destroy();indicator:Destroy();harvestWorld:Destroy();releasePicker();for _,c in ipairs(connections)do c:Disconnect()end;table.clear(shown);selectionView:Destroy();gui:Destroy()
end)
