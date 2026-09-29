-- A quiet local ping only while the current keeper is close. No remote can start it by itself.
local SoundService=game:GetService('SoundService')
local Content=game:GetService('ContentProvider')
local Pursuit=require(script.Parent.KeeperPursuit)
local M={};M.__index=M
function M.new()
 local old=SoundService:FindFirstChild('KeeperCloseWarning');if old then old:Destroy()end
 local sound=Instance.new('Sound');sound.Name='KeeperCloseWarning'
 sound.SoundId='rbxasset://sounds/electronicpingshort.wav';sound.Volume=.055;sound.PlaybackSpeed=.85;sound.Looped=false;sound.Parent=SoundService
 local eq=Instance.new('EqualizerSoundEffect');eq.HighGain=-12;eq.MidGain=-4;eq.LowGain=-2;eq.Parent=sound
 local self=setmetatable({Sound=sound,Next=0,Ready=false,Near=false},M)
 task.spawn(function()local ok=pcall(function()Content:PreloadAsync({sound})end);if not self.Destroyed then self.Ready=ok and sound.IsLoaded end end)
 return self
end
function M:Stop()
 self.Near=false;self.Next=0
 if not self.Destroyed then self.Sound:Stop()end
end
function M:Update(active,distance,stage,now)
 if self.Destroyed then return end
 local threshold=Pursuit.AlarmDistance(stage)
 if not active or distance~=distance or distance>threshold+(self.Near and 2 or 0)then self:Stop();return end
 self.Near=true
 if not self.Ready or now<self.Next then return end
 local pressure=math.clamp((threshold-distance)/7,0,1)
 self.Next=now+1.25-pressure*.45
 self.Sound.Volume=.045+.025*pressure
 self.Sound.PlaybackSpeed=.82+.12*pressure
 self.Sound.TimePosition=0;self.Sound:Play()
end
function M:Destroy()if self.Destroyed then return end;self:Stop();self.Destroyed=true;self.Sound:Destroy()end
return M
