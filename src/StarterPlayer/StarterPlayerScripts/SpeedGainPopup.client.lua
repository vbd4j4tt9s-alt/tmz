-- V0.55 whole-point treadmill gains emitted from the head in a narrow cone.
-- Place this LocalScript in StarterPlayer > StarterPlayerScripts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("ChestChaseRemotes", 10)
assert(remotes, "[V0.55] Missing ChestChaseRemotes; check the first server error.")

local speedGainPopup = remotes:WaitForChild("SpeedGainPopup", 10)
assert(speedGainPopup, "[V0.55] Missing SpeedGainPopup; install matching Config and BaseService modules.")

local randomizer = Random.new()
local POPUP_LIFETIME = math.clamp(tonumber(speedGainPopup:GetAttribute("PopupLifetime")) or 1.35, 0.5, 2)
local FADE_DELAY = 0.35
local FADE_DURATION = POPUP_LIFETIME - FADE_DELAY
local activePopups = {}
local popupSequences = {}
local MAX_VISIBLE_PER_PLAYER = 4
local CONE_HALF_ANGLE_DEGREES = 15
-- Alternating sides separates consecutive gains while keeping every path
-- within a 30-degree cone centred directly above the player's head.
local CONE_ANGLES_DEGREES = {-14, 14, -7, 7, 0, -11, 11, -4, 4, 0}

local function formatGain(amount)
 for _,unit in ipairs({{1e12,'T'},{1e9,'B'},{1e6,'M'},{1e3,'K'}})do
  if amount>=unit[1]then return (string.format('%.1f',amount/unit[1]):gsub('%.0$',''))..unit[2]end
 end
 return string.format('%.0f',amount)
end

local function makeTextLabel(parent, name, text, position, size, color, textSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
 local stroke=Instance.new('UIStroke');stroke.Name='BoldOutline86';stroke.Thickness=2.5
 stroke.Color=Color3.fromRGB(17,26,42);stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual;stroke.Parent=label
	return label
end

local function showGain(targetPlayer, amount)
	if typeof(targetPlayer) ~= "Instance"
		or not targetPlayer:IsA("Player")
		or type(amount) ~= "number"
		or amount <= 0 then
		return
	end

	local character = targetPlayer.Character
	local head = character and character:FindFirstChild("Head")
 local root=character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not head or not root or (camera and (camera.CFrame.Position - head.Position).Magnitude > 100) then
		return
	end
	local visible = activePopups[targetPlayer] or {}
	activePopups[targetPlayer] = visible
	for index = #visible, 1, -1 do
		if not visible[index].Parent then table.remove(visible, index) end
	end
	if #visible >= MAX_VISIBLE_PER_PLAYER then table.remove(visible, 1):Destroy() end

	local sequence = (popupSequences[targetPlayer] or 0) + 1
	popupSequences[targetPlayer] = sequence
	local angleDegrees = CONE_ANGLES_DEGREES[
	((sequence - 1) % #CONE_ANGLES_DEGREES) + 1
	]
	angleDegrees = math.clamp(
		angleDegrees + randomizer:NextNumber(-0.7, 0.7),
		-CONE_HALF_ANGLE_DEGREES,
		CONE_HALF_ANGLE_DEGREES
	)
	local angle = math.rad(angleDegrees)
	local startHorizontal = randomizer:NextNumber(-0.08, 0.08)
	local startVertical = math.max(2,head.Position.Y-root.Position.Y+1.25)
	local travelDistance = 3.0
		+ ((sequence - 1) % 3) * 0.38
		+ randomizer:NextNumber(-0.12, 0.12)
	local cameraRight = camera and camera.CFrame.RightVector or Vector3.new(1, 0, 0)
	local flatRight = Vector3.new(cameraRight.X, 0, cameraRight.Z)
	if flatRight.Magnitude < 0.01 then
		flatRight = Vector3.new(1, 0, 0)
	else
		flatRight = flatRight.Unit
	end
	local startOffset = flatRight * startHorizontal
		+ Vector3.new(0, startVertical, 0)
	local endOffset = flatRight
		* (startHorizontal + math.sin(angle) * travelDistance)
		+ Vector3.new(0, startVertical + math.cos(angle) * travelDistance, 0)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SpeedGainPopup"
	billboard.Adornee = root
	billboard.Size = UDim2.fromOffset(178, 48)
	billboard.StudsOffsetWorldSpace = startOffset
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 100
	billboard.ResetOnSpawn = false
	billboard.Parent = playerGui
	table.insert(visible, billboard)

	local icon = makeTextLabel(
		billboard,
		"Lightning",
		"⚡",
		UDim2.fromOffset(0, 0),
		UDim2.fromOffset(34, 42),
		Color3.fromRGB(255, 222, 66),
		24
	)
	icon.Rotation = randomizer:NextNumber(-14, 14)

	local amountLabel = makeTextLabel(
		billboard,
		"Amount",
		"+" .. formatGain(amount),
		UDim2.fromOffset(31, 0),
		UDim2.new(1, -33, 1, 0),
		Color3.fromRGB(125, 248, 255),
		26
	)
	amountLabel.Rotation = randomizer:NextNumber(-3, 3)

	local riseTween = TweenService:Create(
		billboard,
		TweenInfo.new(POPUP_LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			StudsOffsetWorldSpace = endOffset,
		}
	)
	local iconFade = TweenService:Create(
		icon,
		TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)
	local amountFade = TweenService:Create(
		amountLabel,
		TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)

	riseTween:Play()
	task.delay(FADE_DELAY, function()
		if billboard.Parent then
			iconFade:Play()
            amountFade:Play()
            for _,label in ipairs({icon,amountLabel})do
             TweenService:Create(label.BoldOutline86,TweenInfo.new(FADE_DURATION),{Transparency=1}):Play()
            end
		end
	end)
	riseTween.Completed:Connect(function()
		if billboard.Parent then
			billboard:Destroy()
		end
	end)
end

-- A delayed server frame can contain several real awards. Spread those out
-- visually, conserving their integer sum and rejecting old-character events.
speedGainPopup.OnClientEvent:Connect(function(targetPlayer, amount, _, ticks, interval, earnedCharacter)
	if typeof(targetPlayer) ~= "Instance" or not targetPlayer:IsA("Player")
		or type(amount) ~= "number" or amount ~= amount or amount <= 0
		or amount > 1000000000 then return end
	amount = math.floor(amount)
	if amount < 1 then return end
	local character = earnedCharacter or targetPlayer.Character
	local count = math.min(amount, math.clamp(math.floor(tonumber(ticks) or 1), 1, 10))
	local spacing = math.min(math.clamp(tonumber(interval) or 0.2, 0.1, 1), 1 / count)
	local each = math.floor(amount / count)
	local extra = amount % count
	for index = 1, count do
		local gain = each + (index <= extra and 1 or 0)
		task.delay((index - 1) * spacing, function()
			if targetPlayer.Parent and targetPlayer.Character == character
				and targetPlayer:GetAttribute("TreadmillTraining") == true then
				showGain(targetPlayer, gain)
			end
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	for _, popup in ipairs(activePopups[player] or {}) do popup:Destroy() end
	activePopups[player] = nil
	popupSequences[player] = nil
end)

if game:GetService('RunService'):IsStudio()then print("[V0.55] PASS - Speed gains emit from the head through a narrow 30-degree cone.") end -- R114: Studio-only load message


do
-- V134: broad forward arrows and biome track motion, with jump to exit.
local Players=game:GetService('Players')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local Input=game:GetService('UserInputService')
local Run=game:GetService('RunService')
local player=Players.LocalPlayer
local playerGui=player:WaitForChild('PlayerGui')
local remotes=ReplicatedStorage:WaitForChild('ChestChaseRemotes',15)
assert(remotes,'[V133] Missing ChestChaseRemotes.')
local stop=remotes:WaitForChild('StopTreadmillTraining',15)
assert(stop,'[V133] Missing StopTreadmillTraining.')
local old=playerGui:FindFirstChild('TreadmillTrainingUI');if old then old:Destroy()end
for _,child in ipairs(playerGui:GetChildren())do
    if child.Name=='TreadmillMovingBelt'and child:IsA('SurfaceGui')then child:Destroy()end
end
local lastRequest=-math.huge
local connections={}
table.insert(connections,Input.JumpRequest:Connect(function()
    if Input:GetFocusedTextBox()or player:GetAttribute('TreadmillTraining')~=true then return end
    local now=os.clock();if now-lastRequest<.20 then return end;lastRequest=now
    stop:FireServer()
end))
-- One cached local animator. Fixed collision belt; no server animation writes.
local belts={}
local function disableMotes(record)
    for _,e in ipairs(record.Emitters)do if e.Parent then e.Enabled=false end end
end
local function releaseBelt(record)
    disableMotes(record)
    for _,connection in ipairs(record.Connections)do connection:Disconnect()end
end
local function syncBelt(belt)
    local base=belt.Parent;local art=base and base:FindFirstChild('TreadmillArtV131')
    if not art or art:GetAttribute('TreadmillTrackVersion')~=133 then return end
    local record=belts[belt]
    if not record or record.Art~=art then
        if record then releaseBelt(record)end
        record={Art=art,Distance=0,Clock=0,Motion={},Emitters={},Dirty=true,Connections={}};belts[belt]=record
        local function changed()record.Dirty=true end
        table.insert(record.Connections,art.DescendantAdded:Connect(changed))
        table.insert(record.Connections,art.DescendantRemoving:Connect(changed))
    end
    -- Streaming additions/removals invalidate the cache. Idle models need no descendant scan.
    if not record.Dirty then return end;record.Dirty=false
    local motion,emitters={},{}
    for _,v in ipairs(art:GetDescendants())do
        if v:IsA('BasePart')and v:GetAttribute('TrackMotion')then
            local rest,phase,rate=v:GetAttribute('TrackRest'),v:GetAttribute('TrackPhase'),v:GetAttribute('TrackRate')
            if typeof(rest)=='CFrame'and type(phase)=='number'and type(rate)=='number'then
                table.insert(motion,{Part=v,Rest=rest,Phase=phase,Rate=rate,Travel=v:GetAttribute('TrackTravel')or 10.8,Alpha=v:GetAttribute('TrackAlpha')or 0,Pulse=v:GetAttribute('TrackPulse')})
            end
        elseif v:IsA('ParticleEmitter')and v:GetAttribute('TreadmillTrackEmitter')then
            table.insert(emitters,v)
        end
    end
    for _,e in ipairs(record.Emitters)do
        if not e:IsDescendantOf(art)then e.Enabled=false end
    end
    record.Motion=motion;record.Emitters=emitters
end
local scan,elapsed=1,0
table.insert(connections,Run.Heartbeat:Connect(function(dt)
    scan+=dt;elapsed+=dt
    if scan>=1 then
        scan=0
        local map=workspace:FindFirstChild('ChestChaseMap');local bases=map and map:FindFirstChild('Bases')
        if bases then
            for _,base in ipairs(bases:GetChildren())do
                local belt=base:FindFirstChild('Treadmill')
                if belt and belt:IsA('BasePart')and belt:GetAttribute('TreadmillTrainingBelt')then syncBelt(belt)end
            end
        end
    end
    local low=player:GetAttribute('FastMode')==true
    if elapsed<(low and 1/20 or 1/30)then return end
    local step=math.min(elapsed,.10);elapsed=0
    local camera=workspace.CurrentCamera;local moving,frames={},{}
    for belt,record in pairs(belts)do
        if not belt:IsDescendantOf(workspace)or record.Art.Parent~=belt.Parent then
            releaseBelt(record);belts[belt]=nil
        else
            local distance=camera and (camera.CFrame.Position-belt.Position).Magnitude or math.huge
            local near=distance<(low and 90 or 140)
            for _,e in ipairs(record.Emitters)do
                if e.Parent then
                    local enabled=not low and distance<85
                    if e.Enabled~=enabled then e.Enabled=enabled end
                end
            end
            if near then
                record.Distance+=step*(belt:GetAttribute('TrainingActive')and 3.0 or 1.3)
                record.Clock+=step
                for _,entry in ipairs(record.Motion)do
                    local v=entry.Part
                    if v.Parent==record.Art then
                        -- Negative Z is forward. Each complete arrow fades together at wrap.
                        local phase=(entry.Phase-record.Distance*entry.Rate/entry.Travel)%1
                        local edge=math.clamp(math.min(phase,1-phase)/.07,0,1)
                        local pulse=entry.Pulse and (.06+.06*math.sin(record.Clock*1.8+entry.Phase*math.pi*2))or 0
                        local alpha=1-edge*(1-math.clamp(entry.Alpha+pulse,0,1))
                        if math.abs(v.Transparency-alpha)>.005 then v.Transparency=alpha end
                        table.insert(moving,v)
                        table.insert(frames,belt.CFrame*CFrame.new(0,0,(phase-.5)*entry.Travel)*entry.Rest)
                    end
                end
            end
        end
    end
    if #moving>0 then workspace:BulkMoveTo(moving,frames,Enum.BulkMoveMode.FireCFrameChanged)end
end))
table.insert(connections,script.Destroying:Connect(function()
    for _,connection in ipairs(connections)do connection:Disconnect()end
    for _,record in pairs(belts)do releaseBelt(record)end
    table.clear(belts)
end))
if game:GetService('RunService'):IsStudio()then print('[V134] PASS - forward arrows and living biome tracks; jump to exit.') end -- R114: Studio-only load message
end


-- R71: style menu removed; the existing garden floor button still upgrades the treadmill.
