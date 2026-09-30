-- R100: base playlist / original Nature Inspiration track, with independent fades and chase priority.
-- Replace the ENTIRE Source of the existing BackgroundMusic LocalScript in:
-- StarterPlayer > StarterPlayerScripts

local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Peaceful base-game music. These tracks continue rotating silently during a
-- chase, then fade back in at their current position when the chase ends.
local PEACEFUL_PLAYLIST = {
	{
		Name = "Edvard Grieg - Morning Mood",
		SoundId = "rbxassetid://1846088038",
	},
	{
		Name = "Claude Debussy - Clair de Lune",
		SoundId = "rbxassetid://1844513698",
	},
}

-- APMOfficial / Bruno Jose Marc Le Roux: Playful Chase (92-second version).
-- Creator Store identity checked 2026-09-17; experience audio permissions still apply.
local CHASE_TRACK = {
	Name = "Playful Chase",
	SoundId = "rbxassetid://1839530854",
}

-- Creator Store: APMOfficial Chaser, a tense percussion/electronic chase score.
local SPECIAL_TRACK={Name='Chaser',SoundId='rbxassetid://9042664292'}
-- Recovered from the pre-R73 BiomeAmbience source: the original track-entry music.
local SCENIC_TRACK={Name='Nature Inspiration',SoundId='rbxassetid://96110001912212'}
local SCENIC_VOLUME=.055
local specialTrackReady=false
local scenicTrackReady=false
local insideTrack=false
local destroyed=false
local PEACEFUL_VOLUME = 0.2                                                                
local CHASE_VOLUME = 0.10
local PLAYLIST_CROSSFADE_SECONDS = 3
local CHASE_FADE_IN_SECONDS = 0.65
local CHASE_FADE_OUT_SECONDS = 0.8
local PEACEFUL_RESUME_SECONDS = 1.25
local LOAD_TIMEOUT_SECONDS = 10
local RETRY_DELAY_SECONDS = 8
local loadRequests = {}
local lastLoadWarning = {}

local function reportLoadFailure(trackData, reason)
	local now=os.clock()
	if now-(lastLoadWarning[trackData.SoundId] or -math.huge)<60 then return end
	lastLoadWarning[trackData.SoundId]=now
	warn('[V123 FIX1] Music not ready: '..trackData.Name..' ('..trackData.SoundId..'; '..tostring(reason)
		..'). This can be a loading or asset-access failure; check Roblox Output for the asset error.')
end

-- Remove sounds left behind if an older copy of this LocalScript ran.
for _, child in ipairs(SoundService:GetChildren()) do
	if child:IsA("Sound") and (
		child.Name == "ChestChaseBackgroundMusic"
			or child.Name == "ChestChaseActionTrack"
            or child.Name == "ChestChaseSpecialTrack84"
            or child.Name == "BiomeScenicMusic"
		) then
		child:Destroy()
	end
end

local function getOrCreateSoundGroup(name)
	local group = SoundService:FindFirstChild(name)
	if group and not group:IsA("SoundGroup") then
		group:Destroy()
		group = nil
	end
	if not group then
		group = Instance.new("SoundGroup")
		group.Name = name
		group.Parent = SoundService
	end
	group.Volume = require(game:GetService("ReplicatedStorage").AudioMixer).Get(name=="ChestChaseMusic"and"Music"or"Chase")/100
	return group
end

local peacefulGroup = getOrCreateSoundGroup("ChestChaseMusic")
local chaseGroup = getOrCreateSoundGroup("ChestChaseActionMusic")

-- Slider gain belongs only to the Music SoundGroup. Zone fades affect each
-- base-track envelope so changing the Music slider cannot reopen muted base music.
local peacefulGain=Instance.new('NumberValue');peacefulGain.Value=1
local peacefulVoices={}
local function paintPeaceful()
 for sound,entry in pairs(peacefulVoices)do if sound.Parent then sound.Volume=entry.Envelope.Value*peacefulGain.Value end end
end
local gainConnection=peacefulGain:GetPropertyChangedSignal('Value'):Connect(paintPeaceful)
local function createPeacefulTrack(trackData)
	local music = Instance.new("Sound")
	music.Name = "ChestChaseBackgroundMusic"
	music.SoundId = trackData.SoundId
	music.Volume = 0
	music.Looped = false
	music.PlaybackSpeed = 1
	music.SoundGroup = peacefulGroup
	music:SetAttribute("ClassicalTrackName", trackData.Name)
	music.Parent = SoundService
 local envelope=Instance.new('NumberValue');envelope.Value=0
 local entry={Envelope=envelope};peacefulVoices[music]=entry
 entry.Connection=envelope:GetPropertyChangedSignal('Value'):Connect(paintPeaceful)
 music.Destroying:Connect(function()entry.Connection:Disconnect();peacefulVoices[music]=nil;envelope:Destroy()end)
 return music
end

local chaseMusic = Instance.new("Sound")
chaseMusic.Name = "ChestChaseActionTrack"
chaseMusic.SoundId = CHASE_TRACK.SoundId
chaseMusic.Volume = 0
chaseMusic.Looped = true
chaseMusic.PlaybackSpeed = 1
chaseMusic.SoundGroup = chaseGroup
chaseMusic:SetAttribute("ChaseTrackName", CHASE_TRACK.Name)
chaseMusic.Parent = SoundService

local specialMusic=Instance.new('Sound');specialMusic.Name='ChestChaseSpecialTrack84'
specialMusic.SoundId=SPECIAL_TRACK.SoundId;specialMusic.Volume=0;specialMusic.Looped=true
specialMusic.PlaybackSpeed=1;specialMusic.SoundGroup=chaseGroup;specialMusic.Parent=SoundService
specialMusic:SetAttribute('ChaseTrackName',SPECIAL_TRACK.Name)

local scenicMusic=Instance.new('Sound');scenicMusic.Name='BiomeScenicMusic';scenicMusic.SoundId=SCENIC_TRACK.SoundId
scenicMusic.Volume=0;scenicMusic.Looped=true;scenicMusic.PlaybackSpeed=1;scenicMusic.SoundGroup=peacefulGroup;scenicMusic.Parent=SoundService
scenicMusic:SetAttribute('TrackName',SCENIC_TRACK.Name)

local function tween(instance, targetProperties, duration)
 local entry=peacefulVoices[instance]
 if entry then instance=entry.Envelope;targetProperties={Value=targetProperties.Volume}end
	local animation = TweenService:Create(
		instance,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		targetProperties
	)
	animation:Play()
	return animation
end

local function waitForTrack(sound, minimumLength)
	-- A loaded Sound is usable even if an earlier preload request has stalled.
	if sound.Parent and sound.IsLoaded and sound.TimeLength>minimumLength then return true,'Loaded' end
	local deadline = os.clock() + LOAD_TIMEOUT_SECONDS
	local id=sound.SoundId
	local request=loadRequests[id]
	if not request or request.Done then
		request={Done=false};loadRequests[id]=request
		task.spawn(function()
			local ok,err=pcall(function()
				ContentProvider:PreloadAsync({sound},function(_,status) request.Status=tostring(status) end)
			end)
			request.Error=not ok and tostring(err) or nil;request.Done=true
		end)
	end
	while sound.Parent
		and not (sound.IsLoaded and sound.TimeLength > minimumLength)
		and os.clock() < deadline do
		task.wait(0.1)
	end
	return sound.Parent~=nil and sound.IsLoaded and sound.TimeLength>minimumLength,
		request.Error or request.Status or 'load timeout'
end

local function findPlayablePeacefulTrack(startIndex, cachedTrack)
	for offset = 0, #PEACEFUL_PLAYLIST - 1 do
        if destroyed then return nil,startIndex end
		local index = (startIndex + offset - 1) % #PEACEFUL_PLAYLIST + 1
		local trackData = PEACEFUL_PLAYLIST[index]
		if cachedTrack and cachedTrack.Parent and cachedTrack.IsLoaded and cachedTrack.SoundId==trackData.SoundId then
			return cachedTrack,index
		end
		local candidate = createPeacefulTrack(trackData)
		candidate:Play()

		local ready,reason=waitForTrack(candidate, PLAYLIST_CROSSFADE_SECONDS + 2)
		if ready then
			return candidate, index
		end

		reportLoadFailure(trackData,reason)
		candidate:Stop()
		candidate:Destroy()
	end

	return nil, startIndex
end

local characterRemoving = false
local chaseTrackReady = false
local chaseLoadFinished = false
local transitionSerial = 0
local peacefulGainTween
local scenicVolumeTween
local connections={}
local function watch(signal,fn)local c=signal:Connect(fn);connections[#connections+1]=c;return c end
local chaseVolumeTween
local specialVolumeTween

local function cancelTween(animation)
	if animation then
		animation:Cancel()
	end
end

local function chaseIsActive()
	return not destroyed and not characterRemoving and player:GetAttribute("ChestChaseRunActive") == true
end

local function selectedMusic()
 if player:GetAttribute('SpecialKeeperChase84')==true and specialTrackReady then return specialMusic,true end
 return chaseMusic,chaseTrackReady
end
local function ensureChasePlayback()
 local sound,ready=selectedMusic()
 if not chaseIsActive()or not ready or not sound.Parent then return end
 sound.Looped=true
 if not sound.IsPlaying then
  if sound.IsPaused then sound:Resume()else sound.TimePosition=0;sound:Play()end
 end
end

local function trackIsActive()
 local character=not characterRemoving and player.Character
 local root=character and character:FindFirstChild('HumanoidRootPart')
 local hum=character and character:FindFirstChildOfClass('Humanoid')
 local map=workspace:FindFirstChild('ChestChaseMap');local lobby=map and map:FindFirstChild('Lobby')
 local line=lobby and lobby:FindFirstChild('BaseBoundaryLine')
 if not root or not hum or hum.Health<=0 or not line then return false end
 local p=root.Position;local edge=line.Position.Z+(insideTrack and-.5 or .5)
 return p.Z>edge and p.Z<=(tonumber(map:GetAttribute('BiomeTrackEndZ'))or 1475)
  and math.abs(p.X-line.Position.X)<=(tonumber(map:GetAttribute('FieldWidth'))or 180)/2+2 and p.Y> -20 and p.Y<=300
end
local function setChaseMusicActive(isActive)
 if destroyed then return end
 transitionSerial+=1;local serial=transitionSerial
 cancelTween(peacefulGainTween);cancelTween(scenicVolumeTween);cancelTween(chaseVolumeTween);cancelTween(specialVolumeTween)
 local selected,ready=selectedMusic();local audible=isActive and ready
 if audible then ensureChasePlayback()end
 local scenic=insideTrack and scenicTrackReady and not audible and not characterRemoving
 if scenic and not scenicMusic.IsPlaying then if scenicMusic.IsPaused then scenicMusic:Resume()else scenicMusic:Play()end end
 peacefulGainTween=tween(peacefulGain,{Value=(audible or scenic)and 0 or 1},audible and CHASE_FADE_IN_SECONDS or PEACEFUL_RESUME_SECONDS)
 scenicVolumeTween=tween(scenicMusic,{Volume=scenic and SCENIC_VOLUME or 0},audible and CHASE_FADE_IN_SECONDS or 1.2)
 chaseVolumeTween=tween(chaseMusic,{Volume=audible and selected==chaseMusic and CHASE_VOLUME or 0},.45)
 specialVolumeTween=tween(specialMusic,{Volume=audible and selected==specialMusic and .16 or 0},.45)
 task.delay(.5,function()
  if destroyed or serial~=transitionSerial then return end
  for _,sound in ipairs({chaseMusic,specialMusic})do
   if sound.Parent and (not audible or sound~=selected)then sound:Pause()end
  end
 end)
end

-- Native Looped playback is seamless. These guards recover an unexpected end/stop
-- without restarting an inactive chase or running a second playback thread.
local endedConnection=chaseMusic.Ended:Connect(function()task.defer(ensureChasePlayback)end)
local specialEnded=specialMusic.Ended:Connect(function()task.defer(ensureChasePlayback)end)
local loopCheck=0;local zoneCheck=0
local loopConnection=RunService.Heartbeat:Connect(function(dt)
    zoneCheck+=dt
    if zoneCheck>=.1 then
     zoneCheck=0;local inside=trackIsActive()
     if inside~=insideTrack then insideTrack=inside;setChaseMusicActive(chaseIsActive())end
     if scenicMusic.Volume==0 and scenicMusic.IsPlaying then scenicMusic:Pause()end
    end
    loopCheck+=dt
    if loopCheck>=1 then loopCheck=0;ensureChasePlayback()end
end)
script.Destroying:Connect(function()
    destroyed=true;transitionSerial+=1
    endedConnection:Disconnect();specialEnded:Disconnect();loopConnection:Disconnect()
    for _,connection in ipairs(connections)do connection:Disconnect()end
    cancelTween(peacefulGainTween);cancelTween(scenicVolumeTween);cancelTween(chaseVolumeTween);cancelTween(specialVolumeTween)
    for sound in pairs(peacefulVoices)do sound:Destroy()end
    gainConnection:Disconnect();peacefulGain:Destroy();chaseMusic:Destroy();specialMusic:Destroy();scenicMusic:Destroy()
end)

watch(player:GetAttributeChangedSignal("ChestChaseRunActive"),function()
	setChaseMusicActive(chaseIsActive())
end)

watch(player:GetAttributeChangedSignal('SpecialKeeperChase84'),function()setChaseMusicActive(chaseIsActive())end)

watch(player.CharacterAdded,function()
    characterRemoving = false
    insideTrack=trackIsActive()
    setChaseMusicActive(chaseIsActive())
end)

watch(player.CharacterRemoving,function()
    characterRemoving = true
    insideTrack=false
	-- Clear the local music immediately even if the server's attribute update
	-- reaches the client a frame later.
	setChaseMusicActive(false)
end)

watch(specialMusic.Loaded,function()
 if specialMusic.TimeLength>2 then specialTrackReady=true;setChaseMusicActive(chaseIsActive())end
end)
task.spawn(function()
 for attempt=1,3 do
  if destroyed then return end
  local ready,reason=waitForTrack(specialMusic,2);specialTrackReady=ready
  setChaseMusicActive(chaseIsActive())
  if ready then return end
  reportLoadFailure(SPECIAL_TRACK,reason)
  if attempt<3 then task.wait(RETRY_DELAY_SECONDS*attempt)end
 end
end)

watch(chaseMusic.Loaded,function()
	if chaseMusic.TimeLength>2 then
		chaseTrackReady=true;chaseLoadFinished=true
		setChaseMusicActive(chaseIsActive())
	end
end)
task.spawn(function()
	for attempt=1,3 do
		if not chaseMusic.Parent then return end
		local ready,reason=waitForTrack(chaseMusic,2)
		chaseTrackReady=ready;chaseLoadFinished=true
		setChaseMusicActive(chaseIsActive())
		if ready then return end
		reportLoadFailure(CHASE_TRACK,reason)
		if attempt<3 then task.wait(RETRY_DELAY_SECONDS*2^(attempt-1)) end
	end
	-- Keep SoundId intact: Sound.Loaded can still recover after a late download.
end)

watch(scenicMusic.Loaded,function()
 if scenicMusic.TimeLength>2 then scenicTrackReady=true;insideTrack=trackIsActive();setChaseMusicActive(chaseIsActive())end
end)
task.spawn(function()
 for attempt=1,3 do
  if destroyed then return end
  local ready,reason=waitForTrack(scenicMusic,2);scenicTrackReady=ready
  insideTrack=trackIsActive();setChaseMusicActive(chaseIsActive())
  if ready then return end
  reportLoadFailure(SCENIC_TRACK,reason)
  if attempt<3 then task.wait(RETRY_DELAY_SECONDS*attempt)end
 end
end)

task.spawn(function()
	local randomizer = Random.new()
	local nextIndex = randomizer:NextInteger(1, #PEACEFUL_PLAYLIST)
	local currentTrack
	local failedCycles=0

	while not destroyed do
		if not currentTrack or not currentTrack.Parent then
			currentTrack, nextIndex = findPlayablePeacefulTrack(nextIndex)
			if currentTrack then
				failedCycles=0
				tween(
					currentTrack,
					{Volume = PEACEFUL_VOLUME},
					PLAYLIST_CROSSFADE_SECONDS
				)
			else
				failedCycles+=1
				task.wait(math.min(300,30*2^math.min(failedCycles-1,4)))
				nextIndex = nextIndex % #PEACEFUL_PLAYLIST + 1
			end
		end

		if currentTrack and currentTrack.Parent then
			task.wait(math.max(
				10,
				currentTrack.TimeLength
				- currentTrack.TimePosition
				- PLAYLIST_CROSSFADE_SECONDS
				))

			if destroyed then break end
            if currentTrack and currentTrack.Parent then
				local requestedIndex = nextIndex % #PEACEFUL_PLAYLIST + 1
				local incomingTrack, loadedIndex = findPlayablePeacefulTrack(requestedIndex,currentTrack)
				if incomingTrack==currentTrack then
					currentTrack.TimePosition=0;currentTrack:Play();nextIndex=loadedIndex
					task.wait(RETRY_DELAY_SECONDS)
				elseif incomingTrack then
					local fadeOut = tween(
						currentTrack,
						{Volume = 0},
						PLAYLIST_CROSSFADE_SECONDS
					)
					tween(
						incomingTrack,
						{Volume = PEACEFUL_VOLUME},
						PLAYLIST_CROSSFADE_SECONDS
					)
					fadeOut.Completed:Wait()

					if currentTrack and currentTrack.Parent then
						currentTrack:Stop()
						currentTrack:Destroy()
					end
					currentTrack = incomingTrack
					nextIndex = loadedIndex
				else
					-- Replay the already loaded track while the next one is unavailable.
					currentTrack.TimePosition=0
					currentTrack:Play()
					nextIndex = requestedIndex
					task.wait(RETRY_DELAY_SECONDS)
				end
			end
		end
	end
end)

-- Apply the current state immediately. The preload task applies it again once
-- the chase track is confirmed ready.
insideTrack=trackIsActive()
setChaseMusicActive(chaseIsActive())

if game:GetService('RunService'):IsStudio()then print('[V123 FIX1] Music controller ready; audio availability is checked separately.') end -- R114: Studio-only load message
