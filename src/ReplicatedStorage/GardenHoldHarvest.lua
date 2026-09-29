-- R53: one press collects the cursor-selected fruit. Holding E never sweeps other fruit.
local Input=game:GetService('UserInputService')
local Hold={};Hold.__index=Hold
function Hold.new(options)
 local self=setmetatable({Options=options,Connections={},Pending=false,RequireRelease=false},Hold)
 local function connect(signal,fn)table.insert(self.Connections,signal:Connect(fn))end
 connect(Input.InputBegan,function(input)if input.KeyCode==Enum.KeyCode.E or input.KeyCode==Enum.KeyCode.ButtonX then self.InputHeld=true end end)
 connect(Input.InputEnded,function(input)if input.KeyCode==Enum.KeyCode.E or input.KeyCode==Enum.KeyCode.ButtonX then self.InputHeld=false;self.RequireRelease=false end end)
 connect(options.SelectionChanged,function()self.RequireRelease=Input:IsKeyDown(Enum.KeyCode.E)or self.InputHeld==true end)
 connect(Input.WindowFocusReleased,function()self.InputHeld=false;self.RequireRelease=false end)
 return self
end
function Hold:CanContinue()
 local options=self.Options;local player=options.Player;local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass('Humanoid');local root=character and character:FindFirstChild('HumanoidRootPart')
 local tool=character and character:FindFirstChildOfClass('Tool')
 if not options.SelectedCrop()or not root or not humanoid or humanoid.Health<=0 or humanoid.PlatformStand or root.Anchored
  or(tool and tool:GetAttribute('GardenShovel'))or Input:GetFocusedTextBox()or options.IsMenuOpen()then return false end
 for _,name in ipairs({'GuardianRagdollActive','GuardianFlingActive','ChestChaseSeedCarrying','StudioTestFlying'})do if player:GetAttribute(name)then return false end end
 return true,root
end
function Hold:Eligible(prompt,root)
 if not prompt.Parent or not prompt.Enabled or not prompt:GetAttribute('GardenPrompt')or prompt:GetAttribute('GardenStage')~=4
  or prompt:GetAttribute('GardenOwnerId')~=self.Options.Player.UserId or prompt:GetAttribute('GardenCropId')~=self.Options.SelectedCrop()
  or prompt:GetAttribute('GardenFruitIndex')~=self.Options.SelectedFruit()then return false end
 local anchor=prompt.Parent;local point=anchor:IsA('Attachment')and anchor.WorldPosition or anchor:IsA('BasePart')and anchor.Position
 return point~=nil and(point-root.Position).Magnitude<=prompt.MaxActivationDistance
end
function Hold:NativeTrigger(prompt)
 local okay,root=self:CanContinue()
 if self.RequireRelease or self.Pending or self.Options.IsBusy()or not okay or not self:Eligible(prompt,root)then return false end
 self.Pending=true;self.RequireRelease=Input:IsKeyDown(Enum.KeyCode.E)or self.InputHeld==true
 return true
end
function Hold:RecordResult()self.Pending=false end
function Hold:Destroy()for _,c in ipairs(self.Connections)do c:Disconnect()end;table.clear(self.Connections)end
return Hold
