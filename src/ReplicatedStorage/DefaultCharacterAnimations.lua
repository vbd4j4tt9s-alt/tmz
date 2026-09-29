-- R67: temporary owner locomotion override. Avatar rig, outfit and saved package stay intact.
local Policy={}
Policy.Clips={
 R6={idle={180435571,180435792},walk={180426354},run={180426354},jump={125750702},fall={180436148},climb={180436334},sit={178130996}},
 R15={idle={507766666,507766951},walk={507777826},run={507767714},jump={507765000},fall={507767968},climb={507765644},swim={507784897},swimidle={507785072},sit={507768133}},
}
local records=setmetatable({},{__mode='k'})
function Policy.Required(player,character)
 if player and (player:GetAttribute('TreadmillTraining')==true or player:GetAttribute('ChestChaseSeedCarrying')==true)then return true end
 for _,child in ipairs(character:GetChildren())do
  if child:GetAttribute('SeedPackCarry')==true or(child:IsA('Tool')and child:GetAttribute('SeedPackTool')==true)then return true end
 end
 return false
end
function Policy.Bind(character,localOwner,owner)
 if not localOwner then return {Refresh=function()end,Destroy=function()end}end
 if records[character]then return records[character]end
 local player=owner or game:GetService('Players'):GetPlayerFromCharacter(character)
 local r={Connections={},Active=false,Dead=false,Clock=0,NextLoad=0};records[character]=r
 function r:ClearTrack()
  if self.Track then self.Track:Stop(.12);self.Track:Destroy();self.Track=nil end
  if self.Animation then self.Animation:Destroy();self.Animation=nil end
  self.Kind=nil
 end
 function r:Refresh()
  if self.Dead then return end
  self.Active=Policy.Required(player,character)
  local h=character:FindFirstChildOfClass('Humanoid');local root=character:FindFirstChild('HumanoidRootPart')
  local training=player and player:GetAttribute('TreadmillTraining')==true
  character:SetAttribute('ChestChaseAnimationPolicy',self.Active and 'Gameplay defaults' or 'Avatar')
  if not self.Active or training or not h or not root or h.Health<=0 or h.PlatformStand or h.Sit or character:GetAttribute('ChestChaseRagdollActive')then self:ClearTrack();self.RequestedKind=nil;return end
  local v=root.AssemblyLinearVelocity;local speed=Vector3.new(v.X,0,v.Z).Magnitude
  local kind=speed>1 and 'run'or'idle';local animator=h:FindFirstChildOfClass('Animator')
  if animator~=self.Animator or kind~=self.RequestedKind then self:ClearTrack();self.Animator=animator;self.RequestedKind=kind;self.NextLoad=0 end
  if not animator then return end
  if not self.Track and self.Clock>=self.NextLoad then
   self.NextLoad=self.Clock+3
   local animation=Instance.new('Animation');animation.Name='CarryDefault'..kind;animation:SetAttribute('ChestChaseGameplayAnimation',true)
   animation.AnimationId='rbxassetid://'..Policy.Clips[h.RigType==Enum.HumanoidRigType.R6 and 'R6'or'R15'][kind][1]
   local ok,track=pcall(animator.LoadAnimation,animator,animation)
   if ok and track then self.Animation=animation;self.Track=track;self.Kind=kind;track.Looped=true;track.Priority=Enum.AnimationPriority.Action
   else animation:Destroy()end
  end
  if self.Track then
   local rate=kind=='idle'and 1 or math.clamp(1+speed/180,1,2.25)
   if not self.Track.IsPlaying then self.Track:Play(.12,1,rate)else self.Track:AdjustSpeed(rate)end
  end
 end
 function r:Step(dt)self.Clock+=math.max(0,dt);self:Refresh()end
 function r:Destroy()
  if self.Dead then return end;self.Dead=true;self:ClearTrack()
  for _,c in ipairs(self.Connections)do c:Disconnect()end
  records[character]=nil
 end
 r.Connections[#r.Connections+1]=game:GetService('RunService').PreAnimation:Connect(function(dt)r:Step(dt)end)
 r.Connections[#r.Connections+1]=character.Destroying:Connect(function()r:Destroy()end)
 r:Refresh();return r
end
return Policy
