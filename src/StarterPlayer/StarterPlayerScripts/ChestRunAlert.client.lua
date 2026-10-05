-- V104: clearer green reward wash; existing one-shot token and cleanup guards.
-- Replace the complete ChestRunAlert LocalScript in StarterPlayerScripts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local presentation = require(ReplicatedStorage:WaitForChild("StormConfig"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("ChestChaseRemotes", 15)
assert(remotes, "[V0.60] Missing remotes; check the first server error.")
local remote = remotes:WaitForChild("ChestRunAlert", 15)
assert(remote, "[V0.60] Install matching Config and ChaseService first.")

-- Set these to false/zero for reduced effects or quiet testing.
local SHOW_CHASE_EFFECTS = true
local HEARTBEAT_VOLUME_SCALE = 1
for _, name in ipairs({"ChestRunAlertUI", "ChestChaseCornerFX"}) do
	local old = playerGui:FindFirstChild(name)
	if old then old:Destroy() end
end
for _, name in ipairs({"ChestRunAlarm", "ChestChaseHeartbeat", "ChestChaseSuccess"}) do
	local old = SoundService:FindFirstChild(name)
	if old then old:Destroy() end
end

local alarm = Instance.new("Sound")
alarm.Name = "ChestRunAlarm"
alarm.Volume = 0.16
alarm.Looped = false
-- R123: the server publishes the alarm id so it is loaded before the first run (it used to download on the
-- first "Show" and start late against the RUN!! label, or not at all).
do
	local preset = remote:GetAttribute("AlarmSoundId")
	if type(preset) == "string" and preset:match("^rbxassetid://%d+$") then alarm.SoundId = preset end
end
alarm.Parent = SoundService
local SoundTiming = require(ReplicatedStorage:WaitForChild("SoundTiming"))
local heartbeat = Instance.new("Sound")
heartbeat.Name = "ChestChaseHeartbeat"
heartbeat.SoundId = remote:GetAttribute("HeartbeatSoundId") or ""
heartbeat.Volume = 0
heartbeat.Looped = true
heartbeat.Parent = SoundService
local heartbeatMaxVolume = math.clamp(
	tonumber(remote:GetAttribute("HeartbeatMaxVolume")) or 0.16, 0, 0.25)
local heartbeatDistance = math.max(10, tonumber(remote:GetAttribute("HeartbeatDistance")) or 65)
local catchDistance = tonumber(remote:GetAttribute("CatchDistance")) or 5.5
local successSound = Instance.new("Sound")
successSound.Name = "ChestChaseSuccess"
successSound.SoundId = remote:GetAttribute("SuccessSoundId") or ""
successSound.Volume = math.clamp(
	tonumber(remote:GetAttribute("SuccessSoundVolume")) or 0.18, 0, 0.35)
successSound.Looped = false
successSound.Parent = SoundService

local function preloadSound(sound, label)
	if sound.SoundId == "" then return false end
	local ok = pcall(function() ContentProvider:PreloadAsync({sound}) end)
	local ready = ok and sound.IsLoaded
	if not ready then
		-- Emptying the ID prevents repeated engine retries after a temporary or
		-- permission-related content failure. Visual feedback remains available.
		sound.SoundId = ""
		warn(string.format(
			"[V0.60] %s audio unavailable; it has been disabled for this session.",
			label
			))
	end
	return ready
end

local heartbeatReady = false
local successSoundReady = false
task.spawn(function() heartbeatReady = preloadSound(heartbeat, "Heartbeat") end)
task.spawn(function() successSoundReady = preloadSound(successSound, "Success") end)
task.spawn(function()
	if alarm.SoundId ~= "" then pcall(function() ContentProvider:PreloadAsync({alarm}) end) end
end)

local function newScreen(name, order)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = order
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	return gui
end
-- Corner effects sit below the existing economy/biome/notification UI.
local effectsGui = newScreen("ChestChaseCornerFX", 5)
local warningGui = newScreen("ChestRunAlertUI", 90)
-- A short world tint leaves the HUD readable and has no border frames.
local successColor = Instance.new("ColorCorrectionEffect")
successColor.Name = "SeedSuccessV103"
successColor.Enabled = false
local successFlashDuration = presentation.SuccessSeconds
local successWash=Instance.new("Frame")
successWash.Name="SeedSuccessWashV104";successWash.Size=UDim2.fromScale(1,1)
successWash.BackgroundColor3=Color3.fromRGB(49,240,106)
successWash.BackgroundTransparency=1;successWash.BorderSizePixel=0
successWash.Active=false;successWash.Parent=effectsGui
local label = Instance.new("TextLabel")
label.Name = "RunWarning"
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0, 58)
label.Size = UDim2.new(0.6, 0, 0, 46)
label.BackgroundTransparency = 1
label.Font = Enum.Font.FredokaOne
label.Text = "RUN!!"
label.TextColor3 = Color3.fromRGB(255, 62, 74)
label.TextStrokeColor3 = Color3.new(0, 0, 0)
label.TextStrokeTransparency = 0
label.TextSize = 38
label.Visible = false
label.Parent = warningGui

local visualParts = {}
local speedLines = {}


local function addEdgeVignette(name, position, size, rotation, color)
	local edge = Instance.new("Frame")
	edge.Name = name
	edge.Position = position
	edge.Size = size
	edge.BackgroundColor3 = color
	edge.BackgroundTransparency = 1
	edge.BorderSizePixel = 0
	edge.Active = false
	edge.Parent = effectsGui

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(0.45, 0.70),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = edge
	table.insert(visualParts, {Part = edge, Opacity = 0.58})
end

-- The gradients fade before their inner edge, so no rectangular panels show.
addEdgeVignette(
	"DangerLeft",
	UDim2.fromScale(0, 0),
	UDim2.new(0, 150, 1, 0),
	0,
	Color3.fromRGB(255, 70, 55)
)
addEdgeVignette(
	"DangerRight",
	UDim2.new(1, -150, 0, 0),
	UDim2.new(0, 150, 1, 0),
	180,
	Color3.fromRGB(255, 70, 55)
)
addEdgeVignette(
	"DangerTop",
	UDim2.fromScale(0, 0),
	UDim2.new(1, 0, 0, 105),
	90,
	Color3.fromRGB(255, 116, 48)
)
addEdgeVignette(
	"DangerBottom",
	UDim2.new(0, 0, 1, -105),
	UDim2.new(1, 0, 0, 105),
	270,
	Color3.fromRGB(255, 116, 48)
)

local speedLineDefinitions = {
	{-1, 0.16, 82, 3, 12},
	{-1, 0.31, 118, 4, 9},
	{-1, 0.69, 104, 3, -9},
	{-1, 0.84, 72, 3, -12},
	{1, 0.16, 82, 3, -12},
	{1, 0.31, 118, 4, -9},
	{1, 0.69, 104, 3, 9},
	{1, 0.84, 72, 3, 12},
}
for index, definition in ipairs(speedLineDefinitions) do
	local side = definition[1]
	local yScale = definition[2]
	local width = definition[3]
	local thickness = definition[4]
	local rotation = definition[5]
	local streak = Instance.new("Frame")
	streak.Name = "SpeedStreak"
	streak.AnchorPoint = Vector2.new(side == 1 and 1 or 0, 0.5)
	streak.Size = UDim2.fromOffset(width, thickness)
	streak.Rotation = rotation
	streak.BackgroundColor3 = index % 2 == 0
		and Color3.fromRGB(255, 238, 150)
		or Color3.fromRGB(255, 255, 255)
	streak.BackgroundTransparency = 1
	streak.BorderSizePixel = 0
	streak.Active = false
	streak.Parent = effectsGui
	table.insert(speedLines, {
		Part = streak,
		Side = side,
		YScale = yScale,
		PhaseOffset = (index - 1) / #speedLineDefinitions,
		Opacity = 0.92,
	})
end


local lastClosedToken = 0
local activeToken = 0
local pendingAlarm
local playedAlarmToken = 0
local playedSuccessToken = 0
local distanceToken, distanceValue, distanceReceived, distanceStage = 0, math.huge, 0,1
local nearAlarm=require(ReplicatedStorage:WaitForChild("KeeperNearAlarm")).new()
local visualStrength, soundVolume, phase, layoutTimer = 0, 0, 0, 0
local successElapsed = math.huge
local fovCamera = nil
local fovOffset = 0
local function releaseCamera()
	if fovCamera then fovCamera.FieldOfView -= fovOffset end
	fovCamera, fovOffset = nil, 0
end
local function currentToken()
	return tonumber(player:GetAttribute("ChestChaseRunToken")) or 0
end
local function liveRun()
	local token = currentToken()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return player:GetAttribute("ChestChaseRunActive") == true and token > lastClosedToken
		and humanoid ~= nil and humanoid.Health > 0, token
end
local function stopNow()
	label.Visible = false
    nearAlarm:Stop()
	alarm:Stop()
	heartbeat:Stop()
	soundVolume = 0
	heartbeat.Volume = 0
end

local function stopSuccess()
	successElapsed = math.huge
	successColor.Enabled = false
	successColor.Brightness = 0
	successWash.BackgroundTransparency = 1
	successColor.TintColor = Color3.new(1, 1, 1)
	successSound:Stop()
	releaseCamera()
end

local function showSuccess()
	successElapsed = 0
	-- Remove the chase zoom immediately so the reward reads as a small zoom in.
	releaseCamera()
	visualStrength = 0
	if successSoundReady then
		successSound:Stop()
		SoundTiming.Play(successSound) -- R150: through the shared lead-in table like the alarm (0 until 82180364878410 is measured)
	end
end

remote.OnClientEvent:Connect(function(action,a,b,token,character)
	token = tonumber(token) or 0
	if action == "Hide" then
		lastClosedToken = math.max(lastClosedToken,token)
		if currentToken() <= lastClosedToken then stopNow() end
	elseif action == "Show" then
		-- A delayed Show from an escaped or previous-character run cannot revive it.
		if token > lastClosedToken and (not character or character == player.Character) then
			pendingAlarm = {Token=token,SoundId=a,Volume=b}
		end
	elseif action == "Proximity" then
		if token > lastClosedToken and token >= distanceToken
			and type(a) == "number" and a == a and a >= 0 then
			distanceToken, distanceValue, distanceReceived = token,a,os.clock()
            distanceStage=tonumber(character)or 1
		end
	elseif action == "Success" then
		-- Hide and Success are sent in order. Equal-to-lastClosed is intentional;
		-- it permits the celebration while still rejecting older run tokens.
		if token > playedSuccessToken and token == currentToken()
			and (not character or character == player.Character) then
			playedSuccessToken = token
			pendingAlarm = nil
			stopNow()
			showSuccess()
		end
	end
end)
player.CharacterRemoving:Connect(function()
	lastClosedToken = math.max(lastClosedToken,currentToken())
	pendingAlarm = nil
	stopNow()
	stopSuccess()
end)
player:GetAttributeChangedSignal("ChestChaseRunActive"):Connect(function()
	if player:GetAttribute("ChestChaseRunActive") ~= true then stopNow() end
end)


local connection
connection = RunService.RenderStepped:Connect(function(dt)
	if not warningGui.Parent or not effectsGui.Parent then
		connection:Disconnect()
		releaseCamera()
		successColor:Destroy()
		nearAlarm:Destroy()
		alarm:Destroy()
		heartbeat:Destroy()
		successSound:Destroy()
		return
	end
	local active,token = liveRun()
	if activeToken ~= token then
		activeToken = token
		phase = 0
		stopNow()
		if active then stopSuccess() end
	end
	label.Visible = active
	if active and pendingAlarm and pendingAlarm.Token == token and playedAlarmToken ~= token then
		playedAlarmToken = token
		if type(pendingAlarm.SoundId) == "string" and pendingAlarm.SoundId:match("^rbxassetid://%d+$") then
			if alarm.SoundId ~= pendingAlarm.SoundId then alarm.SoundId = pendingAlarm.SoundId end
			alarm.Volume = math.clamp(tonumber(pendingAlarm.Volume) or 0.16,0,0.35)
			-- Same frame as the RUN!! label; a cold load that arrives more than 0.5 s late is dropped, not played late.
			alarm:Stop()
			SoundTiming.Play(alarm)
		end
	end
	if not active and successElapsed>=successFlashDuration and visualStrength<.001 and math.abs(fovOffset)<.001 then return end
	local danger = 0
	if active and distanceToken == token and os.clock()-distanceReceived < 1 then
		danger = math.clamp((heartbeatDistance-distanceValue)/(heartbeatDistance-catchDistance),0,1)
	end
	nearAlarm:Update(active and distanceToken==token and os.clock()-distanceReceived<1,distanceValue,distanceStage,os.clock())
	local targetStrength = active and (0.28+0.72*danger) or 0
	visualStrength = visualStrength+(targetStrength-visualStrength)*(1-math.exp(-dt*7))
	phase = (phase+dt*(0.9+danger*0.8))%1
	local pulse = 0.82+0.18*(0.5+0.5*math.cos(phase*math.pi*2))
	for _, item in ipairs(visualParts) do
		item.Part.BackgroundTransparency = 1-(SHOW_CHASE_EFFECTS and item.Opacity*visualStrength*pulse or 0)
	end
	for _, item in ipairs(speedLines) do
		local travel = (phase + item.PhaseOffset) % 1
		local inset = 8 + travel * 100
		local yOffset = math.sin((travel + item.PhaseOffset) * math.pi * 2) * 5
		item.Part.Position = UDim2.new(
			item.Side == 1 and 1 or 0,
			item.Side == 1 and -inset or inset,
			item.YScale,
			yOffset
		)
		local travelFade = math.max(0, math.sin(travel * math.pi)) ^ 0.65
		item.Part.BackgroundTransparency = 1-(SHOW_CHASE_EFFECTS
			and item.Opacity*visualStrength*travelFade or 0)
	end
	local targetVolume = active and danger*heartbeatMaxVolume*math.clamp(HEARTBEAT_VOLUME_SCALE,0,1) or 0
	soundVolume = soundVolume+(targetVolume-soundVolume)*(1-math.exp(-dt*8))
	heartbeat.Volume = soundVolume
	heartbeat.PlaybackSpeed = 0.9+0.55*danger
	if heartbeatReady and active and soundVolume > 0.002 then
		if not heartbeat.IsPlaying then heartbeat:Play() end
	elseif not active or soundVolume <= 0.002 then
		heartbeat:Stop()
	end

	local reward = 0
	if successElapsed < successFlashDuration then
		successElapsed += dt
		local t = math.clamp(successElapsed / successFlashDuration, 0, 1)
		-- Fast, gentle rise; smooth return to the original picture.
		local rise = math.clamp(t / .14, 0, 1)
		local fall = math.clamp((1 - t) / .70, 0, 1)
		reward = rise * rise * (3 - 2 * rise) * fall * fall * (3 - 2 * fall)
	end
	local camera = workspace.CurrentCamera
	if camera ~= fovCamera then
		releaseCamera()
		fovCamera = camera
	end
	successColor.Parent = camera
	successColor.Enabled = reward > 0 and camera ~= nil
	successColor.Brightness = presentation.SuccessBrightness * reward
	successWash.BackgroundTransparency = 1 - presentation.SuccessOpacity * reward
	successColor.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(189, 255, 209), reward * .62)
	if camera then
		local baseFov = camera.FieldOfView - fovOffset
		local target = active and (2 + 4.5 * danger) or 0
		local nextOffset = reward > 0 and -presentation.SuccessZoom * reward
			or fovOffset + (target - fovOffset) * (1 - math.exp(-dt * 8))
		if not active and reward == 0 and math.abs(nextOffset) < .001 then nextOffset = 0 end
		camera.FieldOfView = math.clamp(baseFov + nextOffset, 1, 120)
		-- Record the amount actually applied; clamping cannot accumulate drift.
		fovOffset = camera.FieldOfView - baseFov
	end
	if SHOW_CHASE_EFFECTS and active and danger > 0.08
		and camera and camera.CFrame then
		local now = os.clock()
		local shakeX = math.noise(now * 11, 0, 0) * 0.13 * danger
		local shakeY = math.noise(0, now * 13, 0) * 0.10 * danger
		local roll = math.rad(math.noise(now * 8, 2, 0) * 0.60 * danger)
		camera.CFrame = camera.CFrame
			* CFrame.new(shakeX, shakeY, 0)
			* CFrame.Angles(0, 0, roll)
	end
	
end)
script.Destroying:Connect(function()
 nearAlarm:Destroy()
	if connection then connection:Disconnect() end
	releaseCamera()
	successColor:Destroy()
	alarm:Destroy()
	heartbeat:Destroy()
	successSound:Destroy()
	warningGui:Destroy()
	effectsGui:Destroy()
end)
if game:GetService('RunService'):IsStudio()then print("[V103] PASS - chase warnings and seed reward effects loaded.") end -- R114: Studio-only load message
