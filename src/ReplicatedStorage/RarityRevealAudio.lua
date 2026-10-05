-- R66: preloaded, opener-only build / impact / fanfare, synchronised to the screen timeline.
local Sound=game:GetService('SoundService');local Content=game:GetService('ContentProvider')
local A={};local pool={};local beat=0
-- R150: no per-cue Start any more. The lead-in silence of every file comes from SoundTiming (one place); the optional
-- script attribute <Key>Start still overrides it for one cue. (Pop used to be forced to 0 and sounded ~90 ms after the
-- burst; Whoosh .44 and Impact / Spark .04 moved to SoundTiming.Starts unchanged.)
local sources={Whoosh={Id='rbxassetid://9120768742',Volume=.09},Impact={Id='rbxassetid://9120769331',Volume=.12},Royal={Id='rbxassetid://12222253',Volume=.10},Chime={Id='rbxasset://sounds/electronicpingshort.wav',Volume=.04},
 -- R138: Common / Uncommon / Rare pulls (the bubble pop from InteractionAudio, two clearer notes, a soft sparkle).
 Pop={Id='rbxassetid://96764044228884',Volume=.18},Note={Id='rbxasset://sounds/electronicpingshort.wav',Volume=.07},
 Note2={Id='rbxasset://sounds/electronicpingshort.wav',Volume=.07},Spark={Id='rbxassetid://9120769331',Volume=.06}}
function A.Preload()
 if next(pool)then return end
 local all={}
 for key,def in pairs(sources)do
  local voice=Instance.new('Sound');voice.Name='Reveal_'..key;voice.SoundId=script:GetAttribute(key..'SoundId')or def.Id;voice.Volume=def.Volume;voice.Parent=Sound
  require(script.Parent.AudioMixer).Route(voice,'Effects');pool[key]=voice;all[#all+1]=voice
 end
 task.spawn(function()pcall(function()Content:PreloadAsync(all)end)end)
end
-- skip: seconds of the cue already elapsed on the screen timeline (file seconds = skip x pitch).
-- volume (R138): optional, for this play only (Secret / Cosmic / King play louder).
function A.Play(key,pitch,skip,volume)
 A.Preload();local sound=pool[key];if not sound or not sound.IsLoaded then return false end
 sound:Stop();sound.PlaybackSpeed=pitch or 1;sound.Volume=volume or tonumber(script:GetAttribute(key..'Volume'))or sources[key].Volume
 local Timing=require(script.Parent.SoundTiming)
 local start=tonumber(script:GetAttribute(key..'Start'))or Timing.Offset(sound)
 Timing.Play(sound,start+math.max(0,tonumber(skip)or 0)*(pitch or 1))
 return true
end
function A.Stop()beat=0;for _,s in pairs(pool)do s:Stop()end end
-- R123: elapsed = server-timeline seconds already shown when the reveal reaches this client (replication delay).
-- The whoosh joins mid-build so its peak still lands on the seed burst; a stale opener chime is dropped.
A.ChimeGrace=.35
-- R136 (owner: Legendary / Mythic pulls get sound effects): a quick rising whoosh during their short charge-up, one
-- (Legendary) or two (Mythic) rising chimes, then an impact with a bright chime on the burst.
A.CuePitch={[4]=1.6,[5]=1.35}
-- R138 (owner: "add sound effects for getting common and uncommon, rare"): each low tier sounds different, played when
-- the seed pops out. Common: a pop. Uncommon: a pop and a rising note. Rare: a sparkle and two rising notes.
A.Low={[1]={{'Pop',1.08,0}},[2]={{'Pop',1.22,0},{'Note',1.3,.08}},[3]={{'Spark',1.7,0},{'Note',1.12,0},{'Note2',1.5,.09}}}
A.LowGrace=.6
-- R138 (owner: "make the sounds for cosmic and secret and king more noticeable or audible"): their build, beats and
-- burst play 2-3x louder than before (they were .04-.12), and King adds a second, lower impact under the fanfare.
A.Loud={[6]={Whoosh=.22,Chime=.13,Impact=.30},[7]={Whoosh=.24,Chime=.15,Impact=.34},[8]={Whoosh=.26,Chime=.16,Impact=.36,Royal=.32,Spark=.2}}
local function loud(rank,key)local t=A.Loud[rank];return t and t[key]end
function A.Begin(rank,elapsed)
 A.Stop();A.Preload()
 elapsed=math.max(0,tonumber(elapsed)or 0)
 local seconds=require(script.Parent.RarityRevealSequence).SeedAt(rank)
 if rank>=6 then
  if elapsed<seconds-.05 then A.Play('Whoosh',math.clamp(2.8/seconds,.75,2),elapsed,loud(rank,'Whoosh'))end
 elseif rank>=4 then
  if elapsed<seconds-.05 then A.Play('Whoosh',A.CuePitch[rank],elapsed)end
 end -- R138: Common..Rare sound on the burst (A.Low), not here.
end
function A.Step(rank,t)
 if rank<4 then return end
 local q=t/require(script.Parent.RarityRevealSequence).SeedAt(rank)
 local target
 if rank>=6 then target=q>=.86 and 3 or q>=.63 and 2 or q>=.34 and 1 or 0
 else target=(rank==5 and q>=.75)and 2 or q>=.45 and 1 or 0 end
 if target>beat and q<1 then
  beat=target
  if rank>=6 then A.Play('Chime',(.55+beat*.17)*(rank==8 and .85 or 1),nil,loud(rank,'Chime'))else A.Play('Chime',(rank==5 and .8 or .95)+beat*.15)end
 end
end
-- t: seconds since the reveal began (a low-tier cue reaching this client too late is dropped).
A.HighGrace=.35 -- R150: a rank 4+ burst reaching this client more than this long after its seed moment is dropped
function A.Burst(rank,t)
 if pool.Whoosh then pool.Whoosh:Stop()end
 -- R150: Legendary+ used to play its impact and chime at any lateness, long after the screen's burst ring had ended.
 if rank>=4 and tonumber(t)and t>require(script.Parent.RarityRevealSequence).SeedAt(rank)+A.HighGrace then return end
 local low=A.Low[rank]
 if low then
  if tonumber(t)and t>require(script.Parent.RarityRevealSequence).SeedAt(rank)+A.LowGrace then return end
  for _,cue in ipairs(low)do
   if cue[3]<=0 then A.Play(cue[1],cue[2])else task.delay(cue[3],function()A.Play(cue[1],cue[2])end)end
  end
  return
 end
 if rank>=6 then
  if not A.Play('Impact',rank==8 and .88 or rank==7 and 1 or 1.15,nil,loud(rank,'Impact'))then A.Play('Chime',.65,nil,loud(rank,'Chime'))end
  if rank==8 then A.Play('Royal',.92,nil,loud(rank,'Royal'));A.Play('Spark',.6,nil,loud(rank,'Spark'))end
 elseif rank>=4 then
  A.Play('Impact',rank==5 and 1.05 or 1.3)
  A.Play('Chime',rank==5 and .75 or 1.15)
 end
end
return A
