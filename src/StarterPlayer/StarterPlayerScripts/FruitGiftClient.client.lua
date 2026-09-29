-- R79: equip a crop and click/tap a nearby player. No recipient menu or acceptance dialog.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Input=game:GetService('UserInputService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui');local Remote=RS:WaitForChild('ChestChaseRemotes'):WaitForChild('FruitGift')
local Theme=require(RS.GardenTheme);local Audio=require(RS.InteractionAudio)
local gui=Instance.new('ScreenGui');gui.Name='FruitGifts';gui.ResetOnSpawn=false;gui.DisplayOrder=36;gui.Parent=pg
local status=Instance.new('TextLabel');status.Name='GiftStatus';status.Text='';status.Visible=false;status.AnchorPoint=Vector2.new(.5,0);status.Position=UDim2.new(.5,0,1,-220);status.Size=UDim2.new(.8,0,0,38);status.BackgroundTransparency=1;status.TextWrapped=true;Theme.Text(status,17,true,Theme.Colors.Gold);status.Parent=gui
local serial,last=0,-10;local connections={};local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
local function give(point)
 if os.clock()-last<.65 or pg:GetAttribute('SeedMenu')or player:GetAttribute('ChestChaseRunActive')then return end
 local character=player.Character;local held
 for _,t in ipairs(character and character:GetChildren()or{})do if t:IsA('Tool')and t.Enabled and t:GetAttribute('HarvestItemTool')then held=t;break end end
 local id=held and held:GetAttribute('HarvestInventoryId');local camera=workspace.CurrentCamera
 if not id or not camera then return end
 local ray=camera:ViewportPointToRay(point.X,point.Y);params.FilterDescendantsInstances={character}
 local result=workspace:Raycast(ray.Origin,ray.Direction*250,params);if not result then return end
 local node=result.Instance;local target
 while node and node~=workspace do if node:IsA('Model')then target=Players:GetPlayerFromCharacter(node);if target then break end end;node=node.Parent end
 local root=character:FindFirstChild('HumanoidRootPart');local other=target and target.Character and target.Character:FindFirstChild('HumanoidRootPart')
 if target and target~=player and root and other and(root.Position-other.Position).Magnitude<=18 then last=os.clock();Remote:FireServer('Give',target.UserId,id)end
end
table.insert(connections,Input.InputBegan:Connect(function(input,processed)
 if processed or Input:GetFocusedTextBox()then return end
 if input.UserInputType==Enum.UserInputType.MouseButton1 then give(Input:GetMouseLocation())
 elseif input.KeyCode==Enum.KeyCode.ButtonR2 then local camera=workspace.CurrentCamera;if camera then give(camera.ViewportSize*.5)end end
end))
table.insert(connections,Input.TouchTapInWorld:Connect(function(point,processed)if not processed then give(point)end end))
table.insert(connections,Remote.OnClientEvent:Connect(function(action,message)
 if action~='Status'and action~='Received'then return end
 serial+=1;local current=serial;status.Text=tostring(message or'');status.Visible=status.Text~=''
 if action=='Received'then Audio.Transaction('Equip')end
 task.delay(2.5,function()if gui.Parent and serial==current then status.Text='';status.Visible=false end end)
end))
script.Destroying:Connect(function()for _,c in ipairs(connections)do c:Disconnect()end;gui:Destroy()end)
