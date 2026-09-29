local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Input=game:GetService('UserInputService');local Run=game:GetService('RunService');local Http=game:GetService('HttpService');local CAS=game:GetService('ContextActionService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui');local remote=RS:WaitForChild('ChestChaseRemotes'):WaitForChild('GardenInteract');local Catalog=require(RS:WaitForChild('PlantCatalog'))
local Picker=require(RS:WaitForChild('PlantShovelPicker'));local picker,releasePicker=Picker.Acquire(workspace:WaitForChild('ChestChaseMap'))
local gui=Instance.new('ScreenGui');gui.Name='GardenShovelUI';gui.ResetOnSpawn=false;gui.DisplayOrder=40;gui.Parent=pg
local selectionView=require(RS:WaitForChild('PlantSelectionView')).new('ShovelHover',Color3.fromRGB(245,61,61),.65,0)
local highlight=selectionView.Whole
local box=Instance.new('Frame');box.AnchorPoint=Vector2.new(.5,.5);box.Position=UDim2.fromScale(.5,.5);box.Size=UDim2.new(.85,0,0,180);box.BackgroundColor3=Color3.fromRGB(29,44,36);box.Visible=false;box.Parent=gui
local constraint=Instance.new('UISizeConstraint');constraint.MaxSize=Vector2.new(430,180);constraint.Parent=box
local title=Instance.new('TextLabel');title.BackgroundTransparency=1;title.Position=UDim2.fromOffset(16,12);title.Size=UDim2.new(1,-32,0,98);title.Font=Enum.Font.FredokaOne;title.TextColor3=Color3.fromRGB(245,244,222);title.TextSize=17;title.TextWrapped=true;title.Parent=box
local function button(name,x,color)
 local b=Instance.new('TextButton');b.Text=name;b.Position=UDim2.new(x,12,1,-58);b.Size=UDim2.new(.5,-24,0,42);b.BackgroundColor3=color;b.TextSize=16;b.Font=Enum.Font.FredokaOne;b.Parent=box;return b
end
local remove=button('Remove',0,Color3.fromRGB(248,135,109));local cancel=button('Keep plant',.5,Color3.fromRGB(162,219,165))
local feedback=Instance.new('TextLabel');feedback.Name='ShovelFeedback';feedback.BackgroundTransparency=1;feedback.Size=UDim2.new(.9,0,0,46);feedback.AnchorPoint=Vector2.new(.5,1);feedback.Position=UDim2.new(.5,0,1,-122);feedback.TextColor3=Color3.fromRGB(255,236,218);feedback.TextStrokeTransparency=.3;feedback.Font=Enum.Font.FredokaOne;feedback.TextSize=16;feedback.TextWrapped=true;feedback.Text='';feedback.Parent=gui
local target,pending;local busy=false;local elapsed=0;local feedbackUntil=0;local conns={}
local function connect(signal,fn)table.insert(conns,signal:Connect(fn))end
local function equipped()
 local char=player.Character;local hum=char and char:FindFirstChildOfClass('Humanoid');local tool=char and char:FindFirstChildOfClass('Tool')
 return hum and hum.Health>0 and tool and tool.Enabled and tool:GetAttribute('GardenShovel')
end
local function close()
 pending=nil;box.Visible=false;if pg:GetAttribute('SeedMenu')=='Shovel'then pg:SetAttribute('SeedMenu',nil)end
end
local function valid(model)
 if not model or not model.Parent or model:GetAttribute('GardenOwnerId')~=player.UserId then return false end
 local def=Catalog[model:GetAttribute('SeedId')];local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 if not def or not root then return false end
 local scale=model:GetAttribute('PlantScale')or 1;local q=model:GetPivot():PointToObjectSpace(root.Position)
 local nearest=Vector3.new(math.clamp(q.X,-def.Radius*scale,def.Radius*scale),math.clamp(q.Y,0,def.Height*scale),math.clamp(q.Z,-def.Radius*scale,def.Radius*scale))
 return(q-nearest).Magnitude<=(remote:GetAttribute('PlacementDistance')or 24)
end
local function aim(position,center)
 if not equipped()or pg:GetAttribute('SeedMenu')or Input:GetFocusedTextBox()then return nil end
 local camera=workspace.CurrentCamera;if not camera then return nil end
 local ray
 if position then ray=camera:ViewportPointToRay(position.X,position.Y)
 elseif center or(Input.GamepadEnabled and not Input.MouseEnabled)then local p=camera.ViewportSize/2;ray=camera:ViewportPointToRay(p.X,p.Y)
 else local p=Input:GetMouseLocation();ray=camera:ViewportPointToRay(p.X,p.Y)end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances=picker:RayExclusions(player.Character);params.IgnoreWater=true
 local hit=workspace:Raycast(ray.Origin,ray.Direction*500,params)
 local visual=picker:Pick(ray.Origin,ray.Direction,500,hit)
 if visual then return valid(visual)and visual or nil end
 local item=hit and hit.Instance
 -- Baby plants are deliberately non-queryable. Select their seed position on owned soil.
 if item and item:GetAttribute('GardenSoil')then
  local nearest;local distance=1.6
  for _,model in ipairs(item:GetChildren())do if model:GetAttribute('GardenPlantV141')and valid(model)then
   local at=model:GetPivot():PointToObjectSpace(hit.Position);local gap=math.sqrt(at.X*at.X+at.Z*at.Z)
   if gap<distance then nearest=model;distance=gap end
  end end
  if nearest then return nearest end
 end
 while item and item~=workspace do
  if item:GetAttribute('GardenPlantV141')then return valid(item)and item or nil end;item=item.Parent
 end
end
local function prompt(position,center)
 if busy then return end;local model=aim(position,center);if not model then return end
 pending=model;box.Visible=true;pg:SetAttribute('SeedMenu','Shovel');selectionView:Clear()
 local def=Catalog[model:GetAttribute('SeedId')];title.Text='Remove '..(def.Name or def.HarvestName)..'?\nThis removes the plant and its unpicked fruit. The seed is not returned.'
end
connect(remove.Activated,function()
 local model=pending;if busy or not equipped()or not valid(model)then close();return end
 local payload={RequestId=Http:GenerateGUID(false),Character=player.Character,CropId=model:GetAttribute('CropId')};busy=true;close()
 local okay,result=pcall(function()return remote:InvokeServer('Remove',payload)end);busy=false
 feedback.Text=okay and type(result)=='table'and result.Message or'Could not remove the plant. Try again.';feedbackUntil=os.clock()+3
end)
connect(cancel.Activated,close)
connect(Input.InputBegan,function(input,processed)
 if processed then return end
 if input.UserInputType==Enum.UserInputType.MouseButton1 then prompt()
 elseif input.KeyCode==Enum.KeyCode.Escape and box.Visible then close()end
end)
connect(Input.TouchTapInWorld,function(position,processed)if not processed then prompt(position)end end)
CAS:BindActionAtPriority('GardenShovelRemove',function(_,state)
 if not equipped()then return Enum.ContextActionResult.Pass end
 if state==Enum.UserInputState.Begin then prompt(nil,true)end;return Enum.ContextActionResult.Sink
end,false,2100,Enum.KeyCode.ButtonR2)
connect(pg:GetAttributeChangedSignal('SeedMenu'),function()if box.Visible and pg:GetAttribute('SeedMenu')~='Shovel'then close()end end)
connect(Run.Heartbeat,function(dt)
 elapsed+=dt;if elapsed<.1 then return end;elapsed=0
 if box.Visible and(not equipped()or not valid(pending))then close()end
 target=aim();selectionView:Set(target,nil,workspace.CurrentCamera)
 if feedback.Text~=''and os.clock()>feedbackUntil then feedback.Text=''end
end)
script.Destroying:Connect(function()close();releasePicker();for _,c in ipairs(conns)do c:Disconnect()end;CAS:UnbindAction('GardenShovelRemove');selectionView:Destroy();gui:Destroy()end)
