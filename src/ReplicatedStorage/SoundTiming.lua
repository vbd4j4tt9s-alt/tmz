-- R42. Conservative offsets measured from supplied original audio, in seconds.
-- Both cropped bubble IDs use the smaller measured offset to preserve either transient.
local M={Starts={['100834376603587']=.225,['138131702183716']=.040,
 ['87218932219010']=.015,['96764044228884']=.100,['131731955363530']=.100}}
local pending=setmetatable({},{__mode='k'})
function M.Offset(sound,override)
 local key=tostring(sound.SoundId):match('rbxassetid://(%d+)')
 local value=override
 if value==nil and key then value=script:GetAttribute('Start_'..key)end
 if value==nil then value=key and M.Starts[key]or 0 end
 if type(value)~='number'or value~=value or value==math.huge then return 0 end
 local seconds=math.clamp(value,0,10)
 if sound.IsLoaded and sound.TimeLength>0 then seconds=math.min(seconds,math.max(0,sound.TimeLength-.025))end
 return seconds
end
function M.Play(sound,override)
 require(script.Parent.AudioMixer).Route(sound)
 local previous=pending[sound];if previous then previous:Disconnect();pending[sound]=nil end
 local id=sound.SoundId;local at=os.clock()
 sound.TimePosition=M.Offset(sound,override)
 if not sound.IsLoaded then
  pending[sound]=sound.Loaded:Once(function()
   pending[sound]=nil
   if not sound.Parent or sound.SoundId~=id or not sound.IsPlaying then return end
   -- Do not play a stale button/impact sound long after its visual event.
   if os.clock()-at>.50 then sound:Stop();return end
   sound.TimePosition=M.Offset(sound,override)
  end)
 end
 sound:Play()
 return sound
end
return M
