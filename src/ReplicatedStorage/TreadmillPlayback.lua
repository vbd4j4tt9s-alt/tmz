-- R61: one owner-started run track on the server-created Animator.
-- Playback replicates normally; server training/awards still own gameplay.
local Policy=require(script.Parent.DefaultCharacterAnimations)
local T={};T.__index=T
function T.new(player,character)
 return setmetatable({Player=player,Character=character,Clock=0,NextLoad=0,Attempts=0,Rate=2.5,Dead=false},T)
end
function T:ClearTrack()
 if self.Track then self.Track:Stop(.18);self.Track:Destroy();self.Track=nil end
 if self.Animation then self.Animation:Destroy();self.Animation=nil end
end
function T:Active()
 local c=self.Character;local p=self.Player;local h=c:FindFirstChildOfClass('Humanoid');local root=c:FindFirstChild('HumanoidRootPart')
 return not self.Dead and p.Character==c and c.Parent and h and h.Health>0 and root and root.Anchored
  and p:GetAttribute('TreadmillTraining')==true and not c:GetAttribute('ChestChaseRagdollActive')
  and not p:GetAttribute('GuardianFlingActive')and not p:GetAttribute('GuardianRagdollActive')and not h.PlatformStand and not h.Sit
end
function T:Step(dt)
 if self.Dead then return end;self.Clock+=math.max(0,dt)
 local active=self:Active()
 if not active then
  if self.Track and self.Track.IsPlaying then self.Track:Stop(.18)end
  if self.Running then self.Attempts=0;self.NextLoad=0;self.Warned=false end
  self.Running=false;return
 end
 self.Running=true
 local hum=self.Character:FindFirstChildOfClass('Humanoid');local animator=hum:FindFirstChildOfClass('Animator')
 -- Never create a local Animator: it would prevent replication to other players.
 if not animator then return end
 if animator~=self.Animator then self:ClearTrack();self.Animator=animator;self.Attempts=0;self.NextLoad=0 end
 local speed=tonumber(self.Player:GetAttribute('OwnerAnimationRate82')or self.Player:GetAttribute('TreadmillAnimationRate'))or 2.5
 if speed~=speed then speed=2.5 end;speed=math.clamp(speed,.1,10)
 self.Rate+=(speed-self.Rate)*(1-math.exp(-math.min(dt,.25)*8))
 if not self.Track and self.Clock>=self.NextLoad and self.Attempts<3 then
  self.Attempts+=1;self.NextLoad=self.Clock+3
  local animation=Instance.new('Animation');animation.Name='TreadmillRun';animation:SetAttribute('ChestChaseGameplayAnimation',true)
  local rig=hum.RigType==Enum.HumanoidRigType.R6 and'R6'or'R15'
  animation.AnimationId='rbxassetid://'..Policy.Clips[rig].run[1]
  local ok,track=pcall(animator.LoadAnimation,animator,animation)
  if ok and track then
   self.Animation=animation;self.Track=track;self.LoadAt=self.Clock
   track.Looped=true;track.Priority=Enum.AnimationPriority.Action
  else animation:Destroy()end
 end
 local track=self.Track
 if track then
  if track.Length>0 then
   if not track.IsPlaying then track:Play(.18,1,self.Rate)end
   if math.abs(track.Speed-self.Rate)>.005 then track:AdjustSpeed(self.Rate)end
   if track.WeightTarget<.99 then track:AdjustWeight(1,.18)end
  elseif self.Clock-self.LoadAt>8 then self:ClearTrack()end
 end
 if self.Attempts>=3 and not self.Track and not self.Warned then
  self.Warned=true;warn('[R61] Treadmill run clip unavailable on this client; check animation asset access in Studio Output.')
 end
end
function T:Destroy()if self.Dead then return end;self.Dead=true;self:ClearTrack()end
return T
