-- R153 (owner: "this fast swoosh sound effect also plays when players get hit and fly through the air"): a fast swoosh as a KEEPER's hit sends a
-- player flying. FlingSwoosh153.client.lua hands every KeeperHit packet to M.Hit; nothing else calls it.
--  * Only a real keeper launch: the packet is sent after RagdollService accepted the launch and carries the keeper's Stage (the Darkened too).
--    A bat hit has Cause='Bat'; jumps, track-hole falls, lightning and the trampoline never send one, so they never swoosh.
--  * The flung player hears it 2D (SoundService); everyone else hears it 3D from the flung body (the Sound sits in its HumanoidRootPart, so it
--    travels with it) with roll-off, never both. Effects group: the Effects slider mutes it (0 makes no sound at all).
--  * After the impact: it starts no earlier than MinGap after the hit, entered so its Swell (its loudest moment) lands on PeakAfter, the moment
--    the body moves fastest (the launch is the next physics step after the packet; the speed only falls from there). A late packet joins later.
--  * Quieter than every hit: Volume <= MaxVolume = 8 dB under the generic impact (KeeperAudio.ImpactVolume .48; the slams / The Darkened are .5).
--    At most MaxVoices live at once (yours always sounds: the oldest of someone else's gives way).
-- THE NUMBERS TO TUNE BY EAR (nobody could hear the file when this was written): Start, Swell, Volume, PeakAfter, MinGap. In Studio a number
-- attribute of the same name on this ModuleScript wins over this table. Start (the file's lead-in silence, seconds) left nil = SoundTiming's:
-- set the number attribute Start_102531686500130 on SoundTiming, or add it to SoundTiming.Starts (R150: the one place for lead-ins).
local Players=game:GetService('Players')
local Debris=game:GetService('Debris')
local SoundService=game:GetService('SoundService')
local M={}
M.Id='rbxassetid://102531686500130'
M.Volume=.17      -- (-9 dB under the .48 impact)
M.MaxVolume=.19   -- hard cap: 8 dB under KeeperAudio.ImpactVolume (the R152 rule for whooshes); the attribute cannot lift Volume past it
M.Pitch=1
M.Start=nil       -- seconds of silence before the first sound (nil = SoundTiming's table / Start_<id> attribute, 0 when never measured)
M.Swell=.20       -- seconds into the file (the first sound is Start) where it is loudest: assumed, unmeasured
M.PeakAfter=.12   -- seconds after the hit's server time when the flung body is fastest
M.MinGap=.04      -- never earlier than this after the hit: the impact sound goes first
M.MaxAge=.35      -- a packet older than this (seconds after the hit) makes no swoosh: the body is already flying
M.ColdAge=.25     -- a cold file that finishes loading later than this after its start is dropped, never played late
M.MaxVoices=4     -- live swooshes at once, everyone's
M.Cooldown=.6     -- the same player swooshes at most once per this many seconds
M.MaxStuds=130    -- camera to the hit: farther away, nobody else hears it (the flung player always does)
M.RollMin=14;M.RollMax=130 -- 3D roll-off (InverseTapered)
M.Lifetime=3      -- seconds a swoosh may live after it starts (Debris)
local voices={};local last={}
local function num(key)local v=script:GetAttribute(key);if type(v)=='number'and v==v then return v end;return M[key]end
local function dep(name)return require(script.Parent:WaitForChild(name))end
-- wait = seconds from now until the sound starts; entry = file seconds it starts at. age = seconds since the hit's server time, bound = the lead-in.
function M.Plan(age,bound)
 local p=math.clamp(M.Pitch,.6,1.4);local swell=math.max(num('Swell'),bound)
 local peak=num('PeakAfter')-age
 local wait=math.max(num('MinGap')-age,0,peak-(swell-bound)/p)
 return wait,math.max(bound,swell-(peak-wait)*p)
end
local function prune(now)for i=#voices,1,-1 do local v=voices[i];if not v.Sound.Parent or v.Until<=now then table.remove(voices,i)end end end
function M.Voices()prune(os.clock());return #voices end
local function release(i)local v=table.remove(voices,i);if v and v.Owner.Parent then v.Owner:Destroy()end end
local function room(own)
 prune(os.clock());if #voices<M.MaxVoices then return true end
 if not own then return false end
 for i,v in ipairs(voices)do if not v.Own then release(i);return true end end
 release(1);return true
end
function M.Clear()while #voices>0 do release(#voices)end;table.clear(last)end
-- hit = one KeeperHit packet, player = the local player. Returns the Sound it started (or will start), nil when none.
function M.Hit(hit,player)
 if type(hit)~='table'or type(hit.Stage)~='number'or hit.Cause~=nil or type(hit.VictimUserId)~='number'or typeof(hit.Position)~='Vector3'or type(hit.At)~='number'then return nil end
 local age=math.max(workspace:GetServerTimeNow()-hit.At,0);if age>num('MaxAge')then return nil end
 local now=os.clock();local seen=last[hit.VictimUserId];if seen and now-seen<M.Cooldown then return nil end
 local mixer=dep('AudioMixer');if mixer.Get('Effects')<=0 then return nil end
 local own=player~=nil and hit.VictimUserId==player.UserId
 if not own then
  local camera=workspace.CurrentCamera;if not camera or(camera.CFrame.Position-hit.Position).Magnitude>M.MaxStuds then return nil end
 end
 if not room(own)then return nil end
 last[hit.VictimUserId]=now
 local parent,anchor=SoundService,nil
 if not own then
  local ok,victim=pcall(Players.GetPlayerByUserId,Players,hit.VictimUserId)
  local character=ok and victim and victim.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
  if root then parent=root
  else -- not streamed in: a point where the hit landed
   anchor=Instance.new('Part');anchor.Name='ChestChaseSfx';anchor.Size=Vector3.one;anchor.Transparency=1;anchor.Anchored=true;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false
   anchor.Position=hit.Position;anchor.Parent=workspace;parent=anchor
  end
 end
 local sound=Instance.new('Sound');sound.Name='KeeperFlingSwoosh';sound.SoundId=M.Id
 sound.Volume=math.clamp(num('Volume'),0,M.MaxVolume);sound.PlaybackSpeed=math.clamp(M.Pitch,.6,1.4)
 sound.RollOffMode=Enum.RollOffMode.InverseTapered;sound.RollOffMinDistance=M.RollMin;sound.RollOffMaxDistance=M.RollMax
 mixer.Route(sound,'Effects');sound.Parent=parent
 local owner=anchor or sound
 local timing=dep('SoundTiming')
 local wait,entry=M.Plan(age,num('Start')or timing.Offset(sound))
 table.insert(voices,{Sound=sound,Owner=owner,Until=now+wait+M.Lifetime,Own=own})
 Debris:AddItem(owner,wait+M.Lifetime);sound.Ended:Connect(function()owner:Destroy()end)
 local function go()if sound.Parent then timing.Play(sound,entry,M.ColdAge)end end
 if wait>.002 then task.delay(wait,go)else go()end
 return sound
end
return M
