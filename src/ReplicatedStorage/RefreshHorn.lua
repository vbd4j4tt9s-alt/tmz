-- R89: deeper starting horn with a bounded resonant tail. Effects settings apply.
local H={}
function H.New()
 local sound=Instance.new('Sound');sound.Name='TrackStartHorn';sound.SoundId=script:GetAttribute('SoundId')or'rbxassetid://9120386436';sound.Volume=.82;sound.PlaybackSpeed=.68;sound.Looped=false
 sound.SoundGroup=require(script.Parent.AudioMixer).Group('Effects');sound.Parent=game:GetService('SoundService')
 local reverb=Instance.new('ReverbSoundEffect');reverb.DecayTime=1.6;reverb.Density=.85;reverb.Diffusion=.9;reverb.DryLevel=0;reverb.WetLevel=-9;reverb.Parent=sound
 local echo=Instance.new('EchoSoundEffect');echo.Delay=.23;echo.Feedback=.28;echo.DryLevel=0;echo.WetLevel=-12;echo.Parent=sound
 local dead=false;local serial=0;local tween
 task.spawn(function()pcall(function()game:GetService('ContentProvider'):PreloadAsync({sound})end)end)
 local object={Sound=sound}
 function object:Stop()serial+=1;if tween then tween:Cancel();tween=nil end;sound:Stop()end
 function object:Play()
  if dead or not sound.IsLoaded then return false end
  self:Stop();local token=serial;sound.Volume=.82;sound.TimePosition=tonumber(script:GetAttribute('StartTime'))or 0;sound:Play()
  task.delay(2.1,function()
   if dead or token~=serial then return end
   tween=game:GetService('TweenService'):Create(sound,TweenInfo.new(.5),{Volume=0});tween:Play()
  end)
  task.delay(2.7,function()if not dead and token==serial then self:Stop()end end)
  return true
 end
 function object:Destroy()if dead then return end;dead=true;self:Stop();sound:Destroy()end
 return object
end
return H
