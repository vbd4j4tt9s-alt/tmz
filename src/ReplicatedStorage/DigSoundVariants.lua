-- R122: shovel dig sound variants cut from one long recording (TrackHoleConfig.DigSound).
-- Client playback is positional at the hole and routed through AudioMixer ('Effects') like other SFX. The segment
-- start is set here instead of SoundTiming.Play because SoundTiming clamps offsets to 10 s (the recording is longer);
-- the same stale-load guard is kept. Pure helpers (Resolve, Pick, Detect) are shared with the Studio analyzer and tests.
local RS=game:GetService('ReplicatedStorage')
local Http=game:GetService('HttpService')
local Debris=game:GetService('Debris')
local configModule=script.Parent:WaitForChild('TrackHoleConfig')
local C=require(configModule).DigSound
local V={Config=C}

local function number(n)return type(n)=='number'and n==n and n>-math.huge and n<math.huge end

-- Owner-saved list: JSON '[{"Start":1.2,"Length":0.5},...]' or '[[1.2,0.5],...]'.
function V.Parse(text)
 if type(text)~='string'or text==''then return nil end
 local ok,data=pcall(function()return Http:JSONDecode(text)end)
 if not ok or type(data)~='table'then return nil end
 local out={}
 for _,e in ipairs(data)do
  if type(e)=='table'then
   local s,l=e.Start or e[1],e.Length or e[2]
   if number(s)and number(l)then out[#out+1]={Start=s,Length=l}end
  end
 end
 return out
end
function V.Encode(segments)
 local rows={}
 for _,s in ipairs(segments)do rows[#rows+1]=string.format('{"Start":%.3f,"Length":%.3f}',s.Start,s.Length)end
 return '['..table.concat(rows,',')..']'
end

-- Usable variant list for a sound of timeLength seconds (0 / nil = not loaded yet).
function V.Resolve(timeLength,saved,list,config)
 config=config or C;timeLength=number(timeLength)and timeLength or 0
 local source=saved
 if not source or #source==0 then source=list or config.Segments end
 local out={}
 for _,s in ipairs(source or{})do
  if number(s.Start)and number(s.Length)and s.Start>=0 and s.Length>.03 then
   local start,length=s.Start,math.min(s.Length,config.MaxLength)
   if timeLength>0 then length=math.min(length,timeLength-start)end
   if timeLength<=0 or length>.03 then out[#out+1]={Start=start,Length=length}end
  end
 end
 if #out==0 and timeLength>0 then
  local n=math.max(1,math.floor(config.FallbackVariants or 6));local w=timeLength/n
  for i=1,n do out[i]={Start=(i-1)*w,Length=math.min(w,config.MaxLength)}end
 end
 return out
end

-- Random index in 1..count, never equal to last when there is a choice.
function V.Pick(count,last,rng)
 if count<=0 then return nil end
 if count==1 then return 1 end
 local function int(a,b)if rng then return rng:NextInteger(a,b)end;return math.random(a,b)end
 if type(last)~='number'or last<1 or last>count then return int(1,count)end
 local roll=int(1,count-1);if roll>=last then roll+=1 end
 return roll
end

-- Onset detector on a level series {{T=seconds,Level=0..1},...} (AudioAnalyzer Peak/Rms per frame).
-- An onset = level reaches the threshold after at least QuietGap seconds below the release level (or at the start).
-- Segment = onset - Preroll .. min(decay end + Tail, next onset - Preroll), clamped to MaxLength.
function V.Detect(samples,options)
 local o=setmetatable(options or{},{__index=C.Analyzer})
 local n=#samples;if n==0 then return {},{}end
 local sorted={};for i,s in ipairs(samples)do sorted[i]=s.Level end;table.sort(sorted)
 local floor=sorted[math.max(1,math.floor(n*.2))];local peak=sorted[n]
 local threshold=o.Threshold or(floor+(peak-floor)*o.Sensitivity)
 local release=floor+(threshold-floor)*.5
 local events={};local active;local quietSince=samples[1].T;local belowSince
 for _,s in ipairs(samples)do
  local t,l=s.T,s.Level
  if active then
   if l>active.Peak then active.Peak=l end
   if l<release then
    belowSince=belowSince or t
    if t-belowSince>=o.QuietGap then active.End=belowSince;events[#events+1]=active;active=nil;quietSince=belowSince end
   else belowSince=nil end
  else
   if l>=threshold and(#events==0 or t-quietSince>=o.QuietGap)then active={Onset=t,Peak=l};belowSince=nil
   elseif l>=release then quietSince=t end -- still ringing: the gap restarts
  end
 end
 if active then active.End=samples[n].T;events[#events+1]=active end
 local segments={}
 for i,e in ipairs(events)do
  local start=math.max(0,e.Onset-o.Preroll)
  local stop=e.End+o.Tail
  local nextEvent=events[i+1];if nextEvent then stop=math.min(stop,nextEvent.Onset-o.Preroll)end
  local length=math.min(stop-start,o.MaxLength)
  if length>=o.MinLength then segments[#segments+1]={Start=start,Length=length,Onset=e.Onset,Peak=e.Peak}end
 end
 return segments,{Threshold=threshold,Release=release,Floor=floor,Peak=peak}
end

-- Client player ------------------------------------------------------------------------------------------------------
local Player={};Player.__index=Player
function V.new(config)
 return setmetatable({Config=config or C,Rng=Random.new(),Last=nil,TimeLength=0},Player)
end
function Player:Segments()
 return V.Resolve(self.TimeLength,V.Parse(configModule:GetAttribute(self.Config.Attribute or'DigSegments')),nil,self.Config)
end
-- Picks the next variant: segment, index, pitch. nil when nothing is known yet (no list, sound not loaded).
function Player:Choose(pitchScale)
 local list=self:Segments();local index=V.Pick(#list,self.Last,self.Rng)
 if not index then return nil end
 self.Last=index
 local pitch=self.Rng:NextNumber(self.Config.PitchMin,self.Config.PitchMax)*(pitchScale or 1)
 return list[index],index,pitch
end
-- Plays one variant at position. Returns the Sound (or nil). stopAt is driven by Length / pitch.
-- index (optional, Studio preview) plays that exact variant at pitch 1.
function Player:Play(position,pitchScale,index)
 local cfg=self.Config
 local anchor=Instance.new('Part');anchor.Name='DigSoundAnchor';anchor.Size=Vector3.one;anchor.Transparency=1
 anchor.Anchored=true;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false;anchor.Position=position
 local sound=Instance.new('Sound');sound.Name='TrackHoleDig';sound.SoundId=cfg.Id;sound.Volume=math.clamp(cfg.Volume,0,1)
 sound.RollOffMode=Enum.RollOffMode.InverseTapered;sound.RollOffMinDistance=cfg.RollOffMin;sound.RollOffMaxDistance=cfg.RollOffMax
 sound.Parent=anchor;anchor.Parent=workspace
 local ok,mixer=pcall(require,RS:WaitForChild('AudioMixer'));if ok then mixer.Route(sound,'Effects')end
 local at=os.clock();local started=false
 local function start()
  if started or not sound.Parent then return end
  if self.TimeLength<=0 and sound.TimeLength>0 then self.TimeLength=sound.TimeLength end
  local segment,_,pitch
  if index then segment=self:Segments()[index];pitch=1 else segment,_,pitch=self:Choose(pitchScale)end
  if not segment then anchor:Destroy();return end
  started=true
  sound.PlaybackSpeed=math.clamp(pitch,.5,2);sound.TimePosition=segment.Start;sound:Play()
  local seconds=segment.Length/sound.PlaybackSpeed
  task.delay(seconds,function()if sound.Parent then sound:Stop()end;anchor:Destroy()end)
 end
 if sound.IsLoaded then start()
 else
  sound.Loaded:Once(function()if os.clock()-at<=cfg.LoadGrace then start()elseif anchor.Parent then anchor:Destroy()end end)
  Debris:AddItem(anchor,cfg.LoadGrace+cfg.MaxLength/.5+1)
 end
 return sound
end
V.Player=Player
return V
