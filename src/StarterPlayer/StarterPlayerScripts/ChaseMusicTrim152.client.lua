-- R152 (owner: "darkened chase is the whole audio but ... skip to the 0:22 part of the song"): The Darkened's chase theme (BackgroundMusic's 'Intense', the Sound
-- ChestChaseSpecialTrack84 in SoundService) skips its first SKIP seconds: it plays from 0:22 to the end of the song, and every loop restarts at 0:22, never at 0.
-- A script of its own on purpose: the owner's live BackgroundMusic was hand-edited (the music ids typed in), so it is not replaced. Any Sound in
-- SoundService whose SoundId carries the id is cut, now, when it appears, if its id is set later, and again once its length is known.
-- BackgroundMusic needs no change: it fades only Volume, Pauses / Resumes the track (the position is kept) and its once-a-second "recover an unexpected end"
-- guard only restarts a track that is not playing. It does start a chase with `TimePosition=0; Play()`: the region start (22 s) is what plays, and this script
-- also moves the position up to 22 on Played and every frame while the track plays, in case the engine does not clamp it, so 0:00-0:22 is never heard.
local SoundService=game:GetService('SoundService');local Run=game:GetService('RunService')
local TRACKS={ -- id digits as they appear in SoundId; Skip = seconds cut from the front (the region runs from there to the end of the file)
 {Id='127003062753525',Skip=22}, -- the secret keeper chase theme ('Intense')
}
local function trackOf(sound)
 local id=tostring(sound.SoundId)
 for _,t in ipairs(TRACKS)do if id:find(t.Id,1,true)then return t end end
end
local function apply(sound)
 if not sound:IsA('Sound')then return end
 local t=trackOf(sound);if not t then return end
 pcall(function()
  local length=sound.TimeLength
  if length>0 and length<=t.Skip+1 then return end -- a file this short has nothing past the skip: leave it whole rather than silent
  local to=length>t.Skip and length or math.huge -- (the end of the file; unknown until it loads, then re-applied)
  if sound.PlaybackRegionsEnabled~=true then sound.PlaybackRegionsEnabled=true end
  local a,b=sound.PlaybackRegion,sound.LoopRegion
  if not a or a.Min~=t.Skip or a.Max~=to then sound.PlaybackRegion=NumberRange.new(t.Skip,to)end
  if not b or b.Min~=t.Skip or b.Max~=to then sound.LoopRegion=NumberRange.new(t.Skip,to)end
  if sound.TimePosition<t.Skip then sound.TimePosition=t.Skip end
 end)
end
local function clamp(sound)
 local t=trackOf(sound);if not t or sound.PlaybackRegionsEnabled~=true then return end
 if sound.TimePosition<t.Skip then pcall(function()sound.TimePosition=t.Skip end)end
end
local watched,tracked=setmetatable({},{__mode='k'}),setmetatable({},{__mode='k'});local connections={}
local function connect(signal,fn)if signal then table.insert(connections,signal:Connect(fn))end end
local function consider(sound) -- a sound that carries a listed id is cut and followed
 if not trackOf(sound)then return end
 if not tracked[sound]then
  tracked[sound]=true
  connect(sound:GetPropertyChangedSignal('TimeLength'),function()apply(sound)end)
  pcall(function()connect(sound.Loaded,function()apply(sound)end)end)
  pcall(function()connect(sound.Played,function()clamp(sound)end)end)
 end
 apply(sound)
end
local function watch(sound) -- every Sound is watched for its id (it may be set after it is parented)
 if not sound:IsA('Sound')or watched[sound]then return end
 watched[sound]=true;connect(sound:GetPropertyChangedSignal('SoundId'),function()consider(sound)end);consider(sound)
end
for _,s in ipairs(SoundService:GetDescendants())do watch(s)end
connect(SoundService.DescendantAdded,watch)
-- one cheap check a frame (one or two sounds): a playing track that sits before the skip is moved to it
connect(Run.Heartbeat,function()for sound in pairs(tracked)do if sound.Parent and sound.IsPlaying then clamp(sound)end end end)
script.Destroying:Connect(function()for _,c in ipairs(connections)do c:Disconnect()end end)
