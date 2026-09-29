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
function A.Play(key,pitch)
 A.Preload();local sound=pool[key];if not sound or not sound.IsLoaded then return false end
 sound:Stop();sound.PlaybackSpeed=pitch or 1
 require(script.Parent.SoundTiming).Play(sound,tonumber(script:GetAttribute(key..'Start'))or sources[key].Start)
 return true
end
function A.Stop()beat=0;for _,s in pairs(pool)do s:Stop()end end
function A.Begin(rank)
 A.Stop();A.Preload()
 if rank>=6 then
  local seconds=require(script.Parent.RarityRevealSequence).SeedAt(rank)
  A.Play('Whoosh',math.clamp(2.8/seconds,.75,2))
 else A.Play('Chime',rank==5 and .88 or 1.12)end
end
function A.Step(rank,t)
 if rank<6 then return end
 local q=t/require(script.Parent.RarityRevealSequence).SeedAt(rank)
 local target=q>=.86 and 3 or q>=.63 and 2 or q>=.34 and 1 or 0
 if target>beat and q<1 then beat=target;A.Play('Chime',(.55+beat*.17)*(rank==8 and .85 or 1))end
end
function A.Burst(rank)
 if pool.Whoosh then pool.Whoosh:Stop()end
 if rank>=6 then
  if not A.Play('Impact',rank==8 and .88 or rank==7 and 1 or 1.15)then A.Play('Chime',.65)end
  if rank==8 then A.Play('Royal',.92)end
 elseif rank>=4 then A.Play('Chime',rank==5 and .75 or 1.15)end
end
return A
