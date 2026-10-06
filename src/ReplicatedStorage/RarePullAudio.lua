-- R151: the pull-reveal sounds. Every cue names a SLOT of RarePullSounds; a slot with an uploaded Id plays that one sound, otherwise its
-- layered design made only of sounds the game already has (below). Same beat either way: the cue sheets come from RarePullRules.
-- 2D voices in SoundService on the Effects group (AudioMixer: Effects 0 mutes); the lead-in silence of every file comes from SoundTiming
-- (or the slot's Start).
-- Driven by its owner's clock: Begin(cues) -> Update(t) every frame -> Seek(t) on a skip -> Stop(). No task.delay, so a skip, a death or an
-- error can always silence everything at once; nothing runs per frame once Stop() is called.
-- R152 (owner: "audio syncing issues"): one clock for picture and sound, and nothing late:
--  * every slot is preloaded when the client starts (Preload() with no list, from RarePullCinematic.Bind), not as the reveal begins;
--  * a file still loading on its beat is never played from its start late: it waits and joins on the sheet's clock once loaded (a bed /
--    loop / riser at the right point; a one-shot only within Late of its beat, else it is dropped);
--  * a one-shot starts on the frame the picture shows its beat, from just before its measured Hit (RarePullSounds; else its lead-in),
--    so the hit is heard with that frame and its attack is never skipped (R151 skipped the frame's lateness into the file);
--  * two voices per layer: a cue that comes again while the last one still rings does not cut it (a third takes the oldest);
--  * at most MaxVoices sound at once (the oldest one-shot gives way); every voice has faded out by the end of its presentation;
--  * the game's music is ducked under a reveal (Duck: an EqualizerSoundEffect on the Music / Chase groups, gone with Stop).
local SoundService=game:GetService('SoundService');local Content=game:GetService('ContentProvider')
local Slots=require(script.Parent.RarePullSounds)
local A={}
local PING='rbxasset://sounds/electronicpingshort.wav'
local WHOOSH,IMPACT,THUNDER='rbxassetid://9120768742','rbxassetid://9120769331','rbxassetid://9120016037'
local HUM,RUMBLE,WIND,HEART='rbxassetid://9125719267','rbxassetid://9120018695','rbxassetid://3308152153','rbxassetid://6724333590'
local TEAR,POP,GEM,ROYAL,HORN='rbxassetid://9125725227','rbxassetid://96764044228884','rbxassetid://82559527540705','rbxassetid://12222253','rbxassetid://9120386436'
local SLAM,CLICK='rbxassetid://73468358342062','rbxassetid://96591611478915'
-- Layers: {Id, Volume, Pitch, PitchTo (ramped to by the cue's Until), Delay, Loop, Length (seconds of a long file to use, then it fades)}.
-- Ids already used elsewhere in the game (sfx_audit.md).
A.Fallback={
 Riser={{Id=WHOOSH,Volume=.26,Pitch=.55,PitchTo=1.3},{Id=HUM,Volume=.10,Pitch=.8,PitchTo=1.6,Loop=true}},
 SuckIn={{Id=WHOOSH,Volume=.24,Pitch=1.5,PitchTo=2.4}},
 Impact={{Id=IMPACT,Volume=.42,Pitch=.62},{Id=THUNDER,Volume=.2,Pitch=.75,Length=2.5}},
 GroundImpact={{Id=SLAM,Volume=.3,Pitch=.8},{Id=IMPACT,Volume=.2,Pitch=.9}},
 TitleSlam={{Id=IMPACT,Volume=.16,Pitch=1.45},{Id=PING,Volume=.12,Pitch=.9}},
 Sparkle={{Id=PING,Volume=.07,Pitch=2.0},{Id=PING,Volume=.06,Pitch=1.5,Delay=.09},{Id=PING,Volume=.05,Pitch=2.52,Delay=.18}},
 PackShake={{Id=TEAR,Volume=.22,Pitch=1.35}},
 PackBurst={{Id=TEAR,Volume=.4,Pitch=.85},{Id=POP,Volume=.16,Pitch=1.1}},
 Heartbeat={{Id=HEART,Volume=.25,Pitch=.9,Length=.55}},
 Flight={{Id=WHOOSH,Volume=.08,Pitch=1,Swell=.70}}, -- (the R150 whoosh; its swell assumed .26 s after its .44 s lead-in)
 AuraHum={{Id=HUM,Volume=.06,Pitch=1.2,Loop=true}},
 KingChoir={{Id=HUM,Volume=.2,Pitch=.667,Loop=true},{Id=HUM,Volume=.1,Pitch=1.0,Loop=true}},
 KingFanfare={{Id=HORN,Volume=.36,Pitch=1.0,Length=2.6},{Id=ROYAL,Volume=.3,Pitch=1.0}},
 KingBell={{Id=PING,Volume=.16,Pitch=.5},{Id=PING,Volume=.12,Pitch=.75},{Id=GEM,Volume=.22,Pitch=1}},
 CosmicPad={{Id=HUM,Volume=.18,Pitch=.6,Loop=true},{Id=RUMBLE,Volume=.08,Pitch=.8,Loop=true}},
 CosmicWhoosh={{Id=WHOOSH,Volume=.26,Pitch=.9}},
 CosmicBoom={{Id=THUNDER,Volume=.3,Pitch=.9,Length=2.5},{Id=IMPACT,Volume=.3,Pitch=.8}},
 CosmicStar={{Id=PING,Volume=.08,Pitch=2.6},{Id=PING,Volume=.06,Pitch=3.1,Delay=.07}},
 SecretDrone={{Id=HEART,Volume=.22,Pitch=.8,Loop=true},{Id=RUMBLE,Volume=.12,Pitch=.55,Loop=true}},
 SecretGlitch={{Id=PING,Volume=.06,Pitch=3.2},{Id=PING,Volume=.05,Pitch=2.4,Delay=.045},{Id=CLICK,Volume=.25,Pitch=.5,Delay=.02}},
 SecretVault={{Id=SLAM,Volume=.35,Pitch=.55},{Id=RUMBLE,Volume=.2,Pitch=.7,Length=1.6}},
 SecretWhisper={{Id=WIND,Volume=.12,Pitch=.6,Loop=true}},
}
-- [slot] = {Key, [layer] = {main, alt}}: two voices per layer, so a cue that comes again while the last one still rings does not cut it
local voices={}
local function mixer()local ok,m=pcall(require,script.Parent.AudioMixer);return ok and m or nil end
-- The layers a slot plays right now (the owner's single sound when its Id is set).
function A.Layers(slot)
 local def=Slots.Get(slot);if not def then return {}end
 if def.Id then return {{Id=def.Id,Volume=def.Volume,Pitch=def.Pitch,Start=def.Start,Loop=def.Loop,Owner=true,Content=def.Length,AlignEnd=def.AlignEnd,Region=def.Region,Hit=def.Hit,Swell=def.Swell}}end
 return A.Fallback[slot]or{}
end
local function newVoice(slot,i,l,suffix,m)
 local s=Instance.new('Sound');s.Name='RarePull_'..slot..'_'..i..suffix;s.SoundId=l.Id;s.Volume=0;s.Looped=l.Loop==true
 if l.Region then pcall(function()s.PlaybackRegionsEnabled=true;s.PlaybackRegion=NumberRange.new(l.Region[1],l.Region[2]);s.LoopRegion=NumberRange.new(l.Region[1],l.Region[2])end)end
 if m then m.Route(s,'Effects')end
 s.Parent=SoundService;return s
end
local function voicesFor(slot)
 local layers=A.Layers(slot);local list=voices[slot]
 local key=''
 for _,l in ipairs(layers)do key..=tostring(l.Id)..(l.Region and('@'..l.Region[1]..'-'..l.Region[2])or'')..';'end
 if list and list.Key==key then return list,layers end
 if list then for _,pair in ipairs(list)do for _,v in ipairs(pair)do v:Destroy()end end end
 list={Key=key}
 local m=mixer()
 for i,l in ipairs(layers)do list[i]={newVoice(slot,i,l,'',m),newVoice(slot,i,l,'b',m)}end
 voices[slot]=list;return list,layers
end
-- Loads the files (no list: every slot). Called once when the client starts, so the first reveal of a session is not late; never waited on.
local asked={}
function A.Preload(slotNames)
 local all={}
 for _,slot in ipairs(slotNames or Slots.Order)do
  local list=voicesFor(slot)
  if asked[slot]~=list.Key then asked[slot]=list.Key;for _,pair in ipairs(list)do all[#all+1]=pair[1]end end
 end
 if #all>0 then task.spawn(function()pcall(function()Content:PreloadAsync(all)end)end)end
 return #all
end
-- State of the running sheet.
local sheet,events,cursor=nil,{},1
local length=math.huge
local playing={} -- voice -> event, for every voice of this sheet that may still sound
local cold={} -- events whose file was still loading on their beat
A.Late=.25 -- a one-shot reaching its beat (or its file loading) later than this is dropped, never played late
A.Attack=.008 -- a one-shot with a measured Hit starts this long (real time) before it: the front of the attack, then the hit on the frame
A.MaxVoices=10 -- voices sounding at once (the oldest one-shot gives way)
A.EndFade=.25 -- a voice still ringing at the end of its presentation fades out over this, ending on the presentation's Length
local function stopVoice(v)if v then v:Stop();playing[v]=nil end end
-- R152 perf: the level each voice was last given (only this module sets its voices' Volume): a held level is not written again every frame
local wrote=setmetatable({},{__mode='k'})
local function setLevel(v,x)if wrote[v]~=x then wrote[v]=x;v.Volume=x end end
local function expand(cues)
 local out={}
 for _,c in ipairs(cues)do
  local list,layers=voicesFor(c.Slot)
  for i,l in ipairs(layers)do
   local at=c.At+(l.Delay or 0);local stop=c.Until
   if l.Length then stop=math.min(stop or math.huge,at+l.Length)end
   -- an uploaded riser / reverse whoosh is entered late so that its END lands on the cue's end (Content = its seconds after Start)
   local skip=0
   if l.AlignEnd and l.Content and c.Until then skip=math.max(0,l.Content-(c.Until-at)*(l.Pitch or 1)*(c.Pitch or 1))end
   local loop=l.Loop==true or(l.Owner and Slots.Get(c.Slot).Loop)or false
   -- a whoosh on a flight (PeakAt): entered so its Swell lands ON PeakAt, never starting before the cue's At (the flight's start)
   local entry=nil
   if c.PeakAt and l.Swell then
    local p=(l.Pitch or 1)*(c.Pitch or 1);local bound=l.Region and l.Region[1]or l.Start or 0
    at=math.max(at,c.PeakAt-(l.Swell-bound)/p);entry=l.Swell-(c.PeakAt-at)*p
   end
   out[#out+1]={At=at,Until=stop,Pair=list[i],Layer=l,Slot=c.Slot,Pitch=(l.Pitch or 1)*(c.Pitch or 1),PitchTo=l.PitchTo and l.PitchTo*(c.Pitch or 1),
    Volume=(l.Volume or .3)*(c.Volume or 1),FadeIn=c.FadeIn or(l.Loop and .25 or 0),FadeOut=(l.Length and not c.Until)and .3 or c.FadeOut or(stop and .06 or 0),Loop=loop,Skip=skip,
    Sustained=loop or l.PitchTo~=nil or l.AlignEnd==true or entry~=nil,Entry=entry,PeakAt=entry and c.PeakAt or nil}
  end
 end
 table.sort(out,function(a,b)return a.At<b.At end)
 return out
end
-- the voice of a pair to use: a free one, else the one that started first
local function pick(pair)
 local a,b=pair[1],pair[2]
 if not(a and a.Parent)then return nil end
 if not playing[a]then return a end
 if not(b and b.Parent)then return a end
 if not playing[b]then return b end
 return playing[a].StartedAt<=playing[b].StartedAt and a or b
end
-- (a Sound's IsPlaying can read false for a frame or two after Play(): a voice that started this recently still sounds, else the one-shots of one frame -- the King's four climax hits -- stopped each other)
A.PlayLag=.1
local function cap(t)
 local n,oldest=0,nil
 for v,e in pairs(playing)do
  if t<e.EndsAt and(v.IsPlaying or t-e.StartedAt<=A.PlayLag)then n+=1;if not e.Loop and(not oldest or e.StartedAt<playing[oldest].StartedAt)then oldest=v end
  else stopVoice(v)end -- (ended, or due to end: stopped, never just forgotten while still sounding)
 end
 if n>=A.MaxVoices and oldest then stopVoice(oldest)end
end
local function play(e,v,t,into)
 local Timing=require(script.Parent.SoundTiming)
 playing[v]=nil
 v:Stop();v.Looped=e.Loop;v.PlaybackSpeed=e.Pitch;setLevel(v,e.FadeIn>0 and 0 or e.Volume)
 local l=e.Layer;local base
 if e.Entry then base=e.Entry
 elseif l.Hit and not e.Sustained then base=math.max(l.Region and l.Region[1]or 0,l.Hit-A.Attack*e.Pitch)
 else base=l.Region and l.Region[1]or(l.Start~=nil and l.Start or Timing.Offset(v))end
 local pos=base+(e.Skip or 0)+math.max(0,into)*e.Pitch
 v.TimePosition=pos;v:Play()
 local stop=e.Layer.Region and e.Layer.Region[2]or((tonumber(v.TimeLength)or 0)>0 and v.TimeLength or math.huge)
 e.Voice=v;e.StartedAt=t;e.Started=true;e.Into=into
 e.EndsAt=e.Loop and(e.Until or math.huge)or math.min(e.Until or math.huge,t+(stop-pos)/math.max(.05,e.Pitch))
 -- nothing outlives its presentation: a voice still ringing at the end fades out and ends ON Length
 if e.EndsAt>length then e.EndsAt=length;e.Until=length;e.FadeOut=math.max(e.FadeOut or 0,math.min(A.EndFade,math.max(.05,length-t)))end
 playing[v]=e
end
-- an event reaches its beat (t-e.At = how late this frame is)
local function begin(e,t)
 local late=t-e.At
 if e.Until and t>=e.Until then return end
 if not e.Sustained and late>A.Late then e.Dropped=true;return end
 local v=pick(e.Pair);if not v then return end
 if not v.IsLoaded then e.Cold=true;cold[#cold+1]=e;return end
 -- a bed / loop / riser joins where the clock is; a one-shot starts from its attack on this frame, the frame that shows its beat
 cap(t);play(e,v,t,e.Sustained and late or 0)
end
-- cues: the sheet (RarePullRules); t: its clock now; total: the presentation's Length (every voice has faded out by then).
function A.Begin(cues,t,total)
 A.Stop()
 sheet=cues;events=expand(cues);cursor=1;length=tonumber(total)or math.huge
 A.Update(t or 0)
end
-- t: the sheet's clock (the presentation's own: the same t the picture is drawn with this frame).
function A.Update(t)
 if not sheet then return end
 while cursor<=#events and events[cursor].At<=t do local e=events[cursor];cursor+=1;begin(e,t)end
 -- files that were still loading on their beat join now, where the picture is
 for i=#cold,1,-1 do
  local e=cold[i];local v=pick(e.Pair)
  if not v then table.remove(cold,i)
  elseif v.IsLoaded then
   table.remove(cold,i);e.Cold=false;local late=t-e.At
   if e.Until and t>=e.Until then e.Dropped=true
   elseif e.Sustained or late<=A.Late then cap(t);play(e,v,t,late);e.JoinedLate=late
   else e.Dropped=true end
  end
 end
 for v,e in pairs(playing)do
  if not v.Parent then playing[v]=nil
  elseif t>=e.EndsAt then stopVoice(v)
  elseif e.Until and t>=e.Until-e.FadeOut then
   -- the fade ENDS on Until: a cue that stops for the silence is already silent when the silence starts
   local left=e.Until-t
   if left<=0 then stopVoice(v)else setLevel(v,e.Volume*math.min(1,left/math.max(1e-3,e.FadeOut)))end
  else
   local fade=e.FadeIn>0 and math.clamp((t-e.At)/e.FadeIn,0,1)or 1
   setLevel(v,e.Volume*fade)
   if e.PitchTo and e.Until then v.PlaybackSpeed=e.Pitch+(e.PitchTo-e.Pitch)*math.clamp((t-e.At)/math.max(.01,e.Until-e.At),0,1)end
  end
 end
end
-- A skip: everything stops, the sheet jumps to t (cues before t are skipped, beds / risers that span t join, cues at t play).
function A.Seek(t)
 if not sheet then return end
 for v in pairs(playing)do v:Stop()end;table.clear(playing);table.clear(cold)
 for _,list in pairs(voices)do for _,pair in ipairs(list)do for _,v in ipairs(pair)do v:Stop()end end end
 cursor=1
 while cursor<=#events and events[cursor].At<t-.001 do
  local e=events[cursor];cursor+=1
  if e.Sustained and e.Until and t<e.Until then begin(e,t)end
 end
 A.Update(t)
end
-- The music under a reveal: level 0..1 of DuckDb off the Music and Chase groups (an EqualizerSoundEffect on each; the sliders are untouched).
A.DuckDb=10;A.DuckLevel=0
local ducks={}
function A.Duck(level)
 level=math.clamp(tonumber(level)or 0,0,1)
 if level<=.001 then
  for key,fx in pairs(ducks)do fx:Destroy();ducks[key]=nil end
  A.DuckLevel=0;return
 end
 local m
 for _,key in ipairs({'Music','Chase'})do
  local fx=ducks[key]
  if not fx or not fx.Parent then
   m=m or mixer();local g=m and m.Group(key)
   if g then fx=Instance.new('EqualizerSoundEffect');fx.Name='RarePullDuck';fx.Priority=10;fx.Parent=g;ducks[key]=fx end
  end
  if fx then local db=-A.DuckDb*level;if wrote[fx]~=db then wrote[fx]=db;fx.LowGain=db;fx.MidGain=db;fx.HighGain=db end end -- (the duck is this module's own too)
 end
 A.DuckLevel=level
end
function A.Stop()
 sheet=nil;events={};cursor=1;length=math.huge
 table.clear(playing);table.clear(cold)
 for _,list in pairs(voices)do for _,pair in ipairs(list)do for _,v in ipairs(pair)do v:Stop()end end end
 A.Duck(0)
end
function A.Active()local n=0;for v in pairs(playing)do if v.IsPlaying then n+=1 end end;return n end
function A.Running()return sheet~=nil end
function A.Waiting()return #cold end
-- Owner audition (/test raresound <Slot>): one slot alone, loops for 4 s.
function A.PlaySlot(slot)
 if not Slots.Get(slot)then return false end
 local loop=Slots.Get(slot).Loop or(A.Fallback[slot]and A.Fallback[slot][1]and A.Fallback[slot][1].Loop)
 A.Begin({{At=0,Slot=slot,Until=loop and 4 or(A.Fallback[slot]and A.Fallback[slot][1].PitchTo and 1.4)or nil}},0,6)
 local clock=os.clock()
 local conn;conn=game:GetService('RunService').Heartbeat:Connect(function()
  local t=os.clock()-clock
  if not sheet or t>6 then conn:Disconnect();if t>6 then A.Stop()end;return end
  A.Update(t)
 end)
 return true
end
-- R151 hook for the treadmill bonus roll: a Secret result gets the Secret glitch sting under its own fanfare (one-shots, no loop).
function A.Sting(rank)
 if rank~=6 then return false end
 for _,slot in ipairs({'SecretGlitch'})do
  local list,layers=voicesFor(slot)
  for i,l in ipairs(layers)do
   if not l.Loop and(l.Delay or 0)==0 then
    local v=list[i][1];v:Stop();v.PlaybackSpeed=l.Pitch or 1;setLevel(v,l.Volume or .3)
    pcall(function()local T=require(script.Parent.SoundTiming);T.Play(v,l.Start,.35)end)
   end
  end
 end
 return true
end
-- A 3D voice for the afterglow hum around a puller (RarePullWorld): parented by the caller, routed to Effects, looped.
function A.AuraVoice(parent)
 local l=A.Layers('AuraHum')[1];if not l then return nil end
 local s=Instance.new('Sound');s.Name='RarePull_AuraHum';s.SoundId=l.Id;s.Looped=true;s.Volume=0;s.PlaybackSpeed=l.Pitch or 1
 s.RollOffMinDistance=4;s.RollOffMaxDistance=34
 if l.Region then pcall(function()s.PlaybackRegionsEnabled=true;s.PlaybackRegion=NumberRange.new(l.Region[1],l.Region[2]);s.LoopRegion=NumberRange.new(l.Region[1],l.Region[2])end)end
 s.TimePosition=l.Region and l.Region[1]or l.Start or 0
 local m=mixer();if m then m.Route(s,'Effects')end
 s.Parent=parent;return s,(l.Volume or .06)
end
return A
