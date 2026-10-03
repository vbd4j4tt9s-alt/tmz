-- R66: preloaded, opener-only build / impact / fanfare, synchronised to the screen timeline.
local Sound=game:GetService('SoundService');local Content=game:GetService('ContentProvider')
local A={};local pool={};local beat=0
local sources={Whoosh={Id='rbxassetid://9120768742',Volume=.09,Start=.44},Impact={Id='rbxassetid://9120769331',Volume=.12,Start=.04},Royal={Id='rbxassetid://12222253',Volume=.10,Start=0},Chime={Id='rbxasset://sounds/electronicpingshort.wav',Volume=.04,Start=0}}
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
function A.Play(key,pitch,skip)
 A.Preload();local sound=pool[key];if not sound or not sound.IsLoaded then return false end
 sound:Stop();sound.PlaybackSpeed=pitch or 1
 local start=tonumber(script:GetAttribute(key..'Start'))or sources[key].Start
 require(script.Parent.SoundTiming).Play(sound,start+math.max(0,tonumber(skip)or 0)*(pitch or 1))
 return true
end
function A.Stop()beat=0;for _,s in pairs(pool)do s:Stop()end end
-- R123: elapsed = server-timeline seconds already shown when the reveal reaches this client (replication delay).
-- The whoosh joins mid-build so its peak still lands on the seed burst; a stale opener chime is dropped.
A.ChimeGrace=.35
-- R136 (owner: Legendary / Mythic pulls get sound effects): a quick rising whoosh during their short charge-up, one
-- (Legendary) or two (Mythic) rising chimes, then an impact with a bright chime on the burst.
A.CuePitch={[4]=1.6,[5]=1.35}
function A.Begin(rank,elapsed)
 A.Stop();A.Preload()
 elapsed=math.max(0,tonumber(elapsed)or 0)
 local seconds=require(script.Parent.RarityRevealSequence).SeedAt(rank)
 if rank>=6 then
  if elapsed<seconds-.05 then A.Play('Whoosh',math.clamp(2.8/seconds,.75,2),elapsed)end
 elseif rank>=4 then
  if elapsed<seconds-.05 then A.Play('Whoosh',A.CuePitch[rank],elapsed)end
 elseif elapsed<=A.ChimeGrace then A.Play('Chime',1.12)end
end
function A.Step(rank,t)
 if rank<4 then return end
 local q=t/require(script.Parent.RarityRevealSequence).SeedAt(rank)
 local target
 if rank>=6 then target=q>=.86 and 3 or q>=.63 and 2 or q>=.34 and 1 or 0
 else target=(rank==5 and q>=.75)and 2 or q>=.45 and 1 or 0 end
 if target>beat and q<1 then
  beat=target
  if rank>=6 then A.Play('Chime',(.55+beat*.17)*(rank==8 and .85 or 1))else A.Play('Chime',(rank==5 and .8 or .95)+beat*.15)end
 end
end
function A.Burst(rank)
 if pool.Whoosh then pool.Whoosh:Stop()end
 if rank>=6 then
  if not A.Play('Impact',rank==8 and .88 or rank==7 and 1 or 1.15)then A.Play('Chime',.65)end
  if rank==8 then A.Play('Royal',.92)end
 elseif rank>=4 then
  A.Play('Impact',rank==5 and 1.05 or 1.3)
  A.Play('Chime',rank==5 and .75 or 1.15)
 end
end
return A
