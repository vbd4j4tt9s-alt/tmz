-- R151: the pull-reveal sounds. Every cue names a SLOT of RarePullSounds; a slot with an uploaded Id plays that one sound, otherwise its
-- layered design made only of sounds the game already has (below). Same beat either way: the cue sheets come from RarePullRules.
-- 2D voices in SoundService on the Effects group (AudioMixer: Effects 0 mutes); the lead-in silence of every file comes from SoundTiming
-- (or the slot's Start). One voice per layer: a cue that plays again stops its previous play first (no stacking).
-- Driven by its owner's clock: Begin(cues) -> Update(t) every frame -> Seek(t) on a skip -> Stop(). No task.delay, so a skip, a death or an
-- error can always silence everything at once; nothing runs per frame once Stop() is called.
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
 Heartbeat={{Id=HEART,Volume=.3,Pitch=.9,Length=.55}},
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
local voices={} -- [slot] = {layer voices}
local function mixer()local ok,m=pcall(require,script.Parent.AudioMixer);return ok and m or nil end
-- The layers a slot plays right now (the owner's single sound when its Id is set).
function A.Layers(slot)
 local def=Slots.Get(slot);if not def then return {}end
 if def.Id then return {{Id=def.Id,Volume=def.Volume,Pitch=def.Pitch,Start=def.Start,Loop=def.Loop,Owner=true,Content=def.Length,AlignEnd=def.AlignEnd,Region=def.Region}}end
 return A.Fallback[slot]or{}
end
local function voicesFor(slot)
 local layers=A.Layers(slot);local list=voices[slot]
 local key=''
 for _,l in ipairs(layers)do key..=tostring(l.Id)..(l.Region and('@'..l.Region[1]..'-'..l.Region[2])or'')..';'end
 if list and list.Key==key then return list,layers end
 if list then for _,v in ipairs(list)do v:Destroy()end end
 list={Key=key}
 local m=mixer()
 for i,l in ipairs(layers)do
  local s=Instance.new('Sound');s.Name='RarePull_'..slot..'_'..i;s.SoundId=l.Id;s.Volume=0;s.Looped=l.Loop==true
  if l.Region then pcall(function()s.PlaybackRegionsEnabled=true;s.PlaybackRegion=NumberRange.new(l.Region[1],l.Region[2]);s.LoopRegion=NumberRange.new(l.Region[1],l.Region[2])end)end
  if m then m.Route(s,'Effects')end
  s.Parent=SoundService;list[i]=s
 end
 voices[slot]=list;return list,layers
end
function A.Preload(slotNames)
 local all={}
 for _,slot in ipairs(slotNames or Slots.Order)do local list=voicesFor(slot);for _,v in ipairs(list)do all[#all+1]=v end end
 task.spawn(function()pcall(function()Content:PreloadAsync(all)end)end)
end
-- State of the running sheet.
local sheet,events,cursor=nil,{},1
local active={} -- voice -> event (loops / ramps that need envelope updates)
local function stopVoice(v)if v then v:Stop();active[v]=nil end end
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
   out[#out+1]={At=at,Until=stop,Voice=list[i],Layer=l,Slot=c.Slot,Pitch=(l.Pitch or 1)*(c.Pitch or 1),PitchTo=l.PitchTo and l.PitchTo*(c.Pitch or 1),
    Volume=(l.Volume or .3)*(c.Volume or 1),FadeIn=c.FadeIn or(l.Loop and .25 or 0),FadeOut=(l.Length and not c.Until)and .3 or c.FadeOut or(stop and .06 or 0),Loop=l.Loop==true or(l.Owner and Slots.Get(c.Slot).Loop),Skip=skip}
  end
 end
 table.sort(out,function(a,b)return a.At<b.At end)
 return out
end
A.Late=.25 -- a one-shot reaching its beat later than this (a frame stall, a late packet) is dropped, never played late
local function start(e,t)
 local v=e.Voice;if not v or not v.Parent then return end
 v:Stop();v.Looped=e.Loop;v.PlaybackSpeed=e.Pitch;v.Volume=e.FadeIn>0 and 0 or e.Volume
 local Timing=require(script.Parent.SoundTiming)
 local into=math.max(0,t-e.At)
 local base=e.Layer.Region and e.Layer.Region[1]or(e.Layer.Start~=nil and e.Layer.Start or Timing.Offset(v))
 local ok=pcall(function()Timing.Play(v,base+(e.Skip or 0)+into*e.Pitch,.35)end)
 if not ok then v:Play()end
 e.Started=true;active[v]=e
end
function A.Begin(cues,t)
 A.Stop()
 sheet=cues;events=expand(cues);cursor=1
 A.Update(t or 0,true)
end
-- t: the sheet's clock. first: the call from Begin (a cue already past its beat by more than Late is skipped, a loop joins mid-way).
function A.Update(t,first)
 if not sheet then return end
 while cursor<=#events and events[cursor].At<=t do
  local e=events[cursor];cursor+=1
  local late=t-e.At
  if e.Loop or e.PitchTo then
   if not e.Until or t<e.Until then start(e,t)end
  elseif late<=A.Late then start(e,t)end
 end
 for v,e in pairs(active)do
  if not v.Parent then active[v]=nil
  else
   local a=t-e.At
   if e.Until and t>=e.Until-e.FadeOut then
    -- the fade ENDS on Until: a cue that stops for the silence is already silent when the silence starts
    local left=e.Until-t
    if left<=0 then stopVoice(v)else v.Volume=e.Volume*math.min(1,left/math.max(1e-3,e.FadeOut))end
   else
    local fade=e.FadeIn>0 and math.clamp(a/e.FadeIn,0,1)or 1
    v.Volume=e.Volume*fade
    if e.PitchTo and e.Until then v.PlaybackSpeed=e.Pitch+(e.PitchTo-e.Pitch)*math.clamp(a/math.max(.01,e.Until-e.At),0,1)end
    if not e.Loop and not e.PitchTo and not e.Until then active[v]=nil end
   end
  end
 end
end
-- A skip: everything stops, the sheet jumps to t (cues before t are skipped, loops that span t join, cues at t play).
function A.Seek(t)
 if not sheet then return end
 for v in pairs(active)do stopVoice(v)end
 for _,e in ipairs(events)do if e.Voice then e.Voice:Stop()end end
 cursor=1
 while cursor<=#events and events[cursor].At<t-.001 do
  local e=events[cursor];cursor+=1
  if e.Loop and e.Until and t<e.Until then start(e,t)end
 end
 A.Update(t)
end
function A.Stop()
 sheet=nil;events={};cursor=1
 for v in pairs(active)do active[v]=nil end
 for _,list in pairs(voices)do for _,v in ipairs(list)do v:Stop()end end
end
function A.Active()local n=0;for _ in pairs(active)do n+=1 end;return n end
function A.Running()return sheet~=nil end
-- Owner audition (/test raresound <Slot>): one slot alone, loops for 4 s.
function A.PlaySlot(slot)
 if not Slots.Get(slot)then return false end
 local loop=Slots.Get(slot).Loop or(A.Fallback[slot]and A.Fallback[slot][1]and A.Fallback[slot][1].Loop)
 A.Begin({{At=0,Slot=slot,Until=loop and 4 or(A.Fallback[slot]and A.Fallback[slot][1].PitchTo and 1.4)or nil}},0)
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
    local v=list[i];v:Stop();v.PlaybackSpeed=l.Pitch or 1;v.Volume=(l.Volume or .3)
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
