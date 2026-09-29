-- V149: local-only bell motion; one quiet existing reveal chime, no physics constraints.
local Packs=require(game:GetService('ReplicatedStorage'):WaitForChild('SeedPackRules'))
local Motion={}
local function move(part,frame,batch)if batch then batch:Set(part,frame)else part.CFrame=frame end end
function Motion.Phase(id,time)
 local h=23;for i=1,#tostring(id or '')do h=(h*31+string.byte(tostring(id or ''),i))%1009 end
 local period=14+h%9;local shifted=time+h*.137;local cycle=math.floor(shifted/period)
 local phase=shifted%period
 return phase,cycle,period
end
function Motion.Capture(model,origin)
 local state={Groups={},Model=model,LastCycle=nil}
 for _,part in ipairs(model:GetDescendants())do
  local index=part:GetAttribute('BellIndex');local world=part:GetAttribute('BellPivot')
  if part:IsA('BasePart')and index and world then
   local group=state.Groups[index]
   if not group then group={Pivot=origin:PointToObjectSpace(world),Parts={}};group.Frame=CFrame.new(group.Pivot);group.Inverse=group.Frame:Inverse();state.Groups[index]=group end
   table.insert(group.Parts,{Part=part,Frame=origin:ToObjectSpace(part.CFrame)})
  end
 end
 return state
end
function Motion.Reset(state,origin,batch)
 if not state then return end
 for _,group in pairs(state.Groups)do group.LastAngle=nil;group.LastOrigin=nil;for _,p in ipairs(group.Parts)do if p.Part.Parent then move(p.Part,origin*p.Frame,batch) end end end
 if state.Sound then state.Sound:Stop();state.Sound:Destroy();state.Sound=nil end
end
function Motion.Step(state,origin,id,time,audible,batch)
 local phase,cycle=Motion.Phase(id,time);local ringing=phase<1.7
 for index,group in pairs(state.Groups)do
  local localTime=math.max(0,phase-(index-1)*.035)
  local angle=ringing and math.sin(localTime*16+index*.35)*math.exp(-localTime*2.5)*.13 or 0
  if group.LastAngle~=angle or group.LastOrigin~=origin then
   local rotate=origin*group.Frame*CFrame.Angles(0,0,angle)*group.Inverse
   for _,p in ipairs(group.Parts)do if p.Part.Parent then move(p.Part,rotate*p.Frame,batch)end end
   group.LastAngle=angle;group.LastOrigin=origin
  end
 end
 -- Start sound only on a newly observed strike, never when entering an old animation mid-cycle.
 if state.LastCycle~=nil and cycle~=state.LastCycle and phase<.35 and audible then
  if not state.Sound then
   local anchor
   for _,group in pairs(state.Groups)do if group.Parts[1]and group.Parts[1].Part.Parent then anchor=group.Parts[1].Part;break end end
   if anchor then
    local sound=Instance.new('Sound');sound.Name='Frostbell jingle';sound.SoundId=Packs.RevealBellSoundId
    sound.Volume=.08;sound.RollOffMinDistance=4;sound.RollOffMaxDistance=32;sound.PlaybackSpeed=1.35;sound.Parent=anchor;state.Sound=sound
   end
  end
  if state.Sound and state.Sound.Parent then state.Sound:Play()end
 end
 state.LastCycle=cycle
 return ringing
end
return Motion
