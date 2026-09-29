-- Check the shared station range only while its menu is open. Purchases remain server validated.
local Run=game:GetService('RunService')
local G={};G.__index=G
function G.Allowed(player,position,distance)
 local char=player.Character;local root=char and char:FindFirstChild('HumanoidRootPart');local hum=char and char:FindFirstChildOfClass('Humanoid')
 return root~=nil and hum~=nil and hum.Health>0 and typeof(position)=='Vector3'
  and(root.Position-position).Magnitude<=distance and not player:GetAttribute('ChestChaseRunActive')
end
function G.new(player,panel,station,close,remotes)
 local self=setmetatable({Player=player,Panel=panel,Station=station,Close=close,Remotes=remotes,Elapsed=0},G)
 local function visibility()
  if self.StepConnection then self.StepConnection:Disconnect();self.StepConnection=nil end
  if panel.Visible then
   self.Grace=os.clock()+.35;self.Elapsed=0
   self.StepConnection=Run.Heartbeat:Connect(function(dt)self.Elapsed+=dt;if self.Elapsed>=.15 then self.Elapsed=0;self:Check()end end)
  end
 end
 self.Visibility=panel:GetPropertyChangedSignal('Visible'):Connect(visibility)
 self.Character=player.CharacterRemoving:Connect(function()if panel.Visible then close()end end)
 self.Destroying=panel.Destroying:Connect(function()self:Destroy()end);visibility();return self
end
function G:Check()
 if not self.Panel.Visible then return end
 local position=self.Remotes:GetAttribute(self.Station()..'StationPosition')
 local distance=self.Remotes:GetAttribute('StationInteractionDistance')or 24
 if os.clock()>=(self.Grace or 0)and not G.Allowed(self.Player,position,distance)then self.Close()end
end
function G:Destroy()
 for _,key in ipairs({'StepConnection','Visibility','Character','Destroying'})do if self[key]then self[key]:Disconnect();self[key]=nil end end
end
return G
