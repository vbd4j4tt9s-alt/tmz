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
	-- R156 (owner): three more base tracks (the real titles are not known); the playlist logic is unchanged.
	{
		Name = "Base track 1837487700",
		SoundId = "rbxassetid://1837487700",
	},
	{
		Name = "Base track 1837487818",
		SoundId = "rbxassetid://1837487818",
	},
	{
		Name = "Base track 1836280952",
		SoundId = "rbxassetid://1836280952",
	},
}

-- APMOfficial / Bruno Jose Marc Le Roux: Playful Chase (92-second version).
-- Creator Store identity checked 2026-09-17; experience audio permissions still apply.
-- R151 (owner): the keeper chase theme is the owner's uploaded "kulakovka-gta" track.
local CHASE_TRACK = {
	Name = "GTA Chase",
	SoundId = "rbxassetid://90864299965930",
}

-- R151 (owner): The Darkened's (secret keeper) chase theme is the owner's uploaded "tunetank-intense" track.
local SPECIAL_TRACK={Name='Intense',SoundId='rbxassetid://127003062753525'}
-- Recovered from the pre-R73 BiomeAmbience source: the original track-entry music (the first of the list).
-- R156 (owner): the track music is a playlist of three that alternate in order (1 > 2 > 3 > 1). Each plays once to its end; the next one starts
-- PLAYLIST_CROSSFADE_SECONDS before that end and the two cross over. One Sound per track, all named BiomeScenicMusic (AudioMixer.Route maps that name to the Music slider).
local SCENIC_PLAYLIST={
	{Name='Nature Inspiration',SoundId='rbxassetid://96110001912212'},
	{Name='Track music 74095461107598',SoundId='rbxassetid://74095461107598'},
	{Name='Track music 132448918728086',SoundId='rbxassetid://132448918728086'},
}
local SCENIC_VOLUME=.07 -- R156 (owner: "increase the volume by a bit"): .055 -> .07 for all three tracks
local specialTrackReady=false
local scenicTrackReady=false -- R156: true once at least one of the three has loaded
local scenicSounds={} -- R156: [i] = the Sound of track i
local scenicReady={} -- R156: [i] = true once track i has loaded
local scenicTweens={} -- R156: [i] = the running volume tween of track i
local scenicIndex=1 -- R156: the track in the ear: playing, or paused where it was
local scenicNext=nil -- R156: the incoming track while two cross over
local scenicOn=false -- R156: true while the track music is meant to be heard
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

-- R156 (owner): one Sound per track of the track playlist, all in the Music group. Looped is false: a track plays once to its end (only a track alone loops).
for index,trackData in ipairs(SCENIC_PLAYLIST) do
	local music = Instance.new('Sound')
	music.Name = 'BiomeScenicMusic'
	music.SoundId = trackData.SoundId
	music.Volume = 0
	music.Looped = false
	music.PlaybackSpeed = 1
	music.SoundGroup = peacefulGroup
	music:SetAttribute('TrackName', trackData.Name)
	music.Parent = SoundService
	scenicSounds[index] = music
end

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

-- R157b fix (owner: "at some points in the track the track music will be replaced with the base music, this happens when entering desert"): the place streams
-- (Workspace.StreamingEnabled, StreamingTargetRadius 1024, StreamOutBehavior Opportunistic) and Lobby.BaseBoundaryLine is a plain Part at the track's start (Z -99.3),
-- so a client drops it once the player is that far down the track: past Z 925 with the full radius (inside the Desert, Z 530 to 1180), and from Z 501 on when the engine
-- shrinks the radius to 600 (the Desert's door is Z 530). With no line trackIsActive said "not on the track" and the base music came back; walking back brought the line
-- (and the track music) back. Nothing else trackIsActive reads can stream out (the map and its attributes are Folders, the character is the player's own), and the line's
-- Z and X are also on ReplicatedStorage.RunnerMotion (TrackBoundaryZ / TrackCenterX: MapService.new writes them from the line, and the runner's own speed zones read
-- them on the client too). The live line still wins when it is there (the same numbers), the attributes stand in when it is not, and with neither the answer is false, as before.
local function trackLine(lobby)
 local line=lobby and lobby:FindFirstChild('BaseBoundaryLine')
 if line then return line.Position.Z,line.Position.X end
 local motion=game:GetService('ReplicatedStorage'):FindFirstChild('RunnerMotion')
 local z,x=motion and motion:GetAttribute('TrackBoundaryZ'),motion and motion:GetAttribute('TrackCenterX')
 if type(z)=='number'and type(x)=='number'then return z,x end
 return nil,nil
end
local function trackIsActive()
 local character=not characterRemoving and player.Character
 local root=character and character:FindFirstChild('HumanoidRootPart')
 local hum=character and character:FindFirstChildOfClass('Humanoid')
 local map=workspace:FindFirstChild('ChestChaseMap');local lobby=map and map:FindFirstChild('Lobby')
 local lineZ,lineX=trackLine(lobby)
 if not root or not hum or hum.Health<=0 or not map or not lineZ then return false end
 local p=root.Position;local edge=lineZ+(insideTrack and-.5 or .5)
 return p.Z>edge and p.Z<=(tonumber(map:GetAttribute('BiomeTrackEndZ'))or 1475)
  and math.abs(p.X-lineX)<=(tonumber(map:GetAttribute('FieldWidth'))or 180)/2+2 and p.Y> -20 and p.Y<=300
end
-- R156 (owner): the track playlist. scenicIndex is the track in the ear: playing, or paused where it was. A track plays once to its end; with
-- PLAYLIST_CROSSFADE_SECONDS left the next loaded one starts from 0 and the two cross over (the old one is stopped and rewound once silent). Leaving the
-- track in the middle of a crossfade makes the incoming one the track in the ear. Nothing here runs per frame: stepScenic (every 0.1 s) only reads
-- properties, and tweens are made only when something changes.
local function nextScenic(from)
	for step = 1, #scenicSounds - 1 do
		local index = (from + step - 1) % #scenicSounds + 1
		if scenicReady[index] then return index end
	end
	return nil
end

-- A track that has no loaded companion loops instead of waiting for one.
local function setScenicLooping()
	local alone = nextScenic(scenicIndex) == nil
	for index = 1, #scenicSounds do
		scenicSounds[index].Looped = alone and index == scenicIndex
	end
end

-- Fades the track music in (on) or out over `seconds`; on also starts or resumes the track in the ear. A crossfade that is running is left to finish.
local function fadeScenic(on, seconds)
	scenicOn = on
	if on then
		if not scenicReady[scenicIndex] then scenicIndex = nextScenic(scenicIndex) or scenicIndex end
		setScenicLooping()
		if scenicNext then return end
		local current = scenicSounds[scenicIndex]
		if not current.IsPlaying then
			if current.IsPaused then current:Resume() else current:Play() end
		end
	elseif scenicNext then
		scenicIndex, scenicNext = scenicNext, nil
	end
	for index = 1, #scenicSounds do
		cancelTween(scenicTweens[index])
		scenicTweens[index] = tween(scenicSounds[index], {Volume = on and index == scenicIndex and SCENIC_VOLUME or 0}, seconds)
	end
end

local function startScenicCrossfade(nextIndex)
	local outgoing, incoming = scenicSounds[scenicIndex], scenicSounds[nextIndex]
	scenicNext = nextIndex
	cancelTween(scenicTweens[scenicIndex])
	cancelTween(scenicTweens[nextIndex])
	incoming.Volume = 0
	incoming.TimePosition = 0
	incoming:Play()
	scenicTweens[scenicIndex] = tween(outgoing, {Volume = 0}, PLAYLIST_CROSSFADE_SECONDS)
	scenicTweens[nextIndex] = tween(incoming, {Volume = SCENIC_VOLUME}, PLAYLIST_CROSSFADE_SECONDS)
end

local function stepScenic()
	local current = scenicSounds[scenicIndex]
	if scenicOn then
		if scenicNext then
			if current.Volume <= 0 or not current.IsPlaying then
				-- the crossfade is over: the incoming track is the track in the ear
				cancelTween(scenicTweens[scenicIndex])
				current:Stop()
				current.TimePosition = 0
				current.Volume = 0
				scenicIndex, scenicNext = scenicNext, nil
				setScenicLooping()
			end
		elseif current.IsPlaying and current.TimeLength - current.TimePosition <= PLAYLIST_CROSSFADE_SECONDS then
			local nextIndex = nextScenic(scenicIndex)
			if nextIndex then startScenicCrossfade(nextIndex) end
		end
	end
	-- a silent track: the one in the ear pauses where it is (never while it is being heard), any other is stopped and rewound
	for index = 1, #scenicSounds do
		local sound = scenicSounds[index]
		if sound.Volume == 0 and sound.IsPlaying and index ~= scenicNext then
			if index ~= scenicIndex then
				sound:Stop()
				sound.TimePosition = 0
			elseif not scenicOn then
				sound:Pause()
			end
		end
	end
end

-- Once a second: a track in the ear that stopped by itself (a stall longer than the crossfade ran past its end) goes on with the next loaded one.
local function recoverScenic()
	if not scenicOn or scenicNext then return end
	local current = scenicSounds[scenicIndex]
	if current.IsPlaying or current.IsPaused then return end
	scenicIndex = nextScenic(scenicIndex) or scenicIndex
	scenicSounds[scenicIndex].TimePosition = 0
	fadeScenic(true, PLAYLIST_CROSSFADE_SECONDS)
end

local function setChaseMusicActive(isActive)
 if destroyed then return end
 transitionSerial+=1;local serial=transitionSerial
 cancelTween(peacefulGainTween);cancelTween(chaseVolumeTween);cancelTween(specialVolumeTween)
 local selected,ready=selectedMusic();local audible=isActive and ready
 if audible then ensureChasePlayback()end
 local scenic=insideTrack and scenicTrackReady and not audible and not characterRemoving
 peacefulGainTween=tween(peacefulGain,{Value=(audible or scenic)and 0 or 1},audible and CHASE_FADE_IN_SECONDS or PEACEFUL_RESUME_SECONDS)
 fadeScenic(scenic,audible and CHASE_FADE_IN_SECONDS or 1.2) -- R156 (owner): the track playlist (was one looped Sound)
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
     stepScenic() -- R156 (owner): the track playlist's step (was: pause the one scenic Sound at 0)
    end
    loopCheck+=dt
    if loopCheck>=1 then loopCheck=0;ensureChasePlayback();recoverScenic()end
end)
script.Destroying:Connect(function()
    destroyed=true;transitionSerial+=1
    endedConnection:Disconnect();specialEnded:Disconnect();loopConnection:Disconnect()
    for _,connection in ipairs(connections)do connection:Disconnect()end
    cancelTween(peacefulGainTween);cancelTween(chaseVolumeTween);cancelTween(specialVolumeTween)
    for index=1,#scenicSounds do cancelTween(scenicTweens[index])end
    for sound in pairs(peacefulVoices)do sound:Destroy()end
    gainConnection:Disconnect();peacefulGain:Destroy();chaseMusic:Destroy();specialMusic:Destroy()
    for _,sound in ipairs(scenicSounds)do sound:Destroy()end
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

-- R156 (owner): each track of the track playlist loads on its own, so one that does not load is skipped (with the usual warning) and never holds the
-- others back. The first loaded track starts the music if the player is already on the track; a later one joins the rotation.
local function noteScenicReady(index,ready)
	scenicReady[index]=ready;scenicTrackReady=false
	for i=1,#SCENIC_PLAYLIST do if scenicReady[i] then scenicTrackReady=true end end
	insideTrack=trackIsActive();setChaseMusicActive(chaseIsActive())
end
for index,trackData in ipairs(SCENIC_PLAYLIST) do
	local music=scenicSounds[index]
	watch(music.Loaded,function()
		if music.TimeLength>2 then noteScenicReady(index,true)end
	end)
	task.spawn(function()
		for attempt=1,3 do
			if destroyed then return end
			local ready,reason=waitForTrack(music,2);noteScenicReady(index,ready)
			if ready then return end
			reportLoadFailure(trackData,reason)
			if attempt<3 then task.wait(RETRY_DELAY_SECONDS*attempt)end
		end
	end)
end

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
