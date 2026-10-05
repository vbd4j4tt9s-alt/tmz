--!nocheck
-- R152 test environment, on top of the R151 one (rare_env: Lighting, Camera, Core GUI, controls, seed art, keepers):
--  * sounds that END by themselves at their real length (the owner's files: sound_levels.luau) and every stop logged with its time;
--  * a frame recorder: for every frame, the presentation's own clock and every voice that sounds (file position, volume x group volume),
--    so a test can read when each hit is HEARD and how loud the mix is;
--  * files that load late (cold) on demand.
-- Usage: local Y=require('./rare152_env')(W,E,F,X)
return function(W,E,F,X)
 local R=W.R
 local Y={}
 local Levels=require('./sound_levels')
 Y.Levels=Levels;Y.ById={}
 for slot,l in pairs(Levels.Slots)do l.Slot=slot;Y.ById['rbxassetid://'..string.format('%.0f',l.Id)]=l end
 -- Play / Stop through the per-instance functions sfx_env installs (as the R151 tests do)
 function R.Inst:Play()local own=rawget(self,'_props').Play;if own then return own(self)end end
 function R.Inst:Stop()local own=rawget(self,'_props').Stop;if own then return own(self)end end
 function R.Inst:Pause()end
 local inew=R.Instance.new
 Y.sounds={}
 R.Instance.new=function(class,parent)
  local o=inew(class,parent)
  if class=='Sound'then
   o.StopLog={};Y.sounds[#Y.sounds+1]=o
   local props=rawget(o,'_props');local play,stop=props.Play,props.Stop -- (sfx_env's own; o.Play would be the class method)
   o.Play=function(self)play(self);self.StartPos=self.TimePosition;self.EndedAt=nil end
   o.Stop=function(self)if self.IsPlaying then self.StopLog[#self.StopLog+1]={At=R.clock}end;stop(self)end
   o.Changed:Connect(function(k)if k=='SoundId'then local l=Y.ById[o.SoundId];if l then o._props.TimeLength=l.Duration end end end)
  end
  return o
 end
 -- the file position a playing sound is at now
 function Y.position(s)return(s.StartPos or 0)+(R.clock-(s.PlayedAt or R.clock))*(s.PlaybackSpeed or 1)end
 function Y.endPos(s)
  if s.PlaybackRegionsEnabled and s.PlaybackRegion then return s.PlaybackRegion.Max end
  return tonumber(s.TimeLength)or 12
 end
 -- natural ends + the frame log (a RenderStepped listener: it runs after the bound render steps, i.e. after the director's frame)
 Y.frames={};Y.clockFn=nil
 local function group(s)local g=s.SoundGroup;return g and tonumber(g.Volume)or 1 end
 W.Run.RenderStepped:Connect(function()
  for _,s in ipairs(Y.sounds)do
   if s.IsPlaying and not s.Looped and s.PlayedAt then
    local e=Y.endPos(s)
    if Y.position(s)>=e then s.IsPlaying=false;s.EndedAt=s.PlayedAt+(e-(s.StartPos or 0))/math.max(.01,s.PlaybackSpeed or 1)end
   end
  end
  if Y.recording then
   local f={Clock=R.clock,T=Y.clockFn and Y.clockFn()or nil,Voices={}}
   for _,s in ipairs(Y.sounds)do
    if s.IsPlaying and s.Parent and s.Name:match('^RarePull_')then
     f.Voices[#f.Voices+1]={Sound=s,Pos=Y.position(s),Gain=(tonumber(s.Volume)or 0)*group(s),Id=s.SoundId}
    end
   end
   Y.frames[#Y.frames+1]=f
  end
 end)
 function Y.record(clockFn)Y.frames={};Y.clockFn=clockFn;Y.recording=true end
 function Y.stop()Y.recording=false;return Y.frames end
 -- momentary loudness of a file at a position (LUFS), or nil for a file that was not measured (the game's own sounds)
 function Y.fileLoudness(id,pos)
  local l=Y.ById[id];if not l then return nil end
  local i=pos/Levels.Step;local a=math.floor(i);local f=i-a
  local env=l.Env;local x=env[math.clamp(a+1,1,#env)];local y=env[math.clamp(a+2,1,#env)]
  return x+(y-x)*f
 end
 Y.AssumedLoudness=-16 -- (LUFS) the game's own short sounds (heartbeat, rumble, whoosh, ping...) were never available to measure
 -- what one voice adds: its file's loudness at that point plus its gain in dB
 function Y.voiceLoudness(v)
  if v.Gain<=1e-4 then return -99 end
  local m=Y.fileLoudness(v.Id,v.Pos)or Y.AssumedLoudness
  return m+20*math.log10(v.Gain)
 end
 -- the mix of a frame: energy sum of its voices
 function Y.mixLoudness(f)
  local e=0;for _,v in ipairs(f.Voices)do e+=10^(Y.voiceLoudness(v)/10)end
  return e>0 and 10*math.log10(e)or -99
 end
 -- every play of every RarePull voice since `since` (clock), with when it was heard to end
 function Y.plays(since)
  local out={}
  for _,s in ipairs(Y.sounds)do
   if s.Name:match('^RarePull_')then
    for i,l in ipairs(s.PlayLog)do
     if l.At>=(since or -math.huge)-1e-9 then
      local nextAt=s.PlayLog[i+1]and s.PlayLog[i+1].At or math.huge
      local stopAt=math.huge;for _,st in ipairs(s.StopLog)do if st.At>=l.At-1e-9 and st.At<=nextAt+1e-9 and st.At<stopAt then stopAt=st.At end end
      local e=Y.endPos(s);local natural=l.At+(e-l.TimePosition)/math.max(.01,l.Speed or 1)
      if s.Looped then natural=math.huge end
      out[#out+1]={Sound=s,Slot=s.Name:match('^RarePull_(.-)_%d+b?$'),At=l.At,Pos=l.TimePosition,Speed=l.Speed or 1,Volume=l.Volume,Ends=math.min(stopAt,natural),Id=s.SoundId}
     end
    end
   end
  end
  table.sort(out,function(a,b)return a.At<b.At end)
  return out
 end
 -- make a file cold (IsLoaded false) / load it
 function Y.cold(s)s._props.IsLoaded=false end
 function Y.load(s)if not s._props.IsLoaded then s._props.IsLoaded=true;s.Loaded:Fire()end end
 return Y
end
