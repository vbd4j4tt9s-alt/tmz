-- V0.75 owns biome-seed theft runs, guardian recovery, and success effects.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local KeeperCombat=require(ReplicatedStorage:WaitForChild("KeeperCombat"))
-- V090: only the root moves on the server; cosmetic parts follow locally.
local function pivotKeeper(model, frame)
    if (model:GetAttribute("GardenerArtVersion") == 91 or model:GetAttribute("KeeperClientAnimated") == true) and model.PrimaryPart then
        model.PrimaryPart.CFrame = frame
    else model:PivotTo(frame) end
end

local Workspace = game:GetService("Workspace")

local ChaseService = {}
ChaseService.__index = ChaseService

-- Safe values keep the chase working when an older Config ModuleScript is
-- accidentally paired with this newer ChaseService. They match V0.40's
-- intended guardian balance and do not restore the removed speed offset.
local DEFAULT_GUARDIAN_SETTINGS_BY_STAGE = {
	[1] = {MinimumSpeed = 14, PlayerSpeedRatio = 0.66, CatchupBonus = 3, FlingHorizontal = 32, FlingVertical = 15, RagdollDuration = 0.65},
	[2] = {MinimumSpeed = 16, PlayerSpeedRatio = 0.70, CatchupBonus = 3, FlingHorizontal = 44, FlingVertical = 18, RagdollDuration = 0.80},
	[3] = {MinimumSpeed = 18, PlayerSpeedRatio = 0.74, CatchupBonus = 3, FlingHorizontal = 58, FlingVertical = 21, RagdollDuration = 0.95},
	[4] = {MinimumSpeed = 20, PlayerSpeedRatio = 0.78, CatchupBonus = 3, FlingHorizontal = 74, FlingVertical = 24, RagdollDuration = 1.10},
	[5] = {MinimumSpeed = 22, PlayerSpeedRatio = 0.82, CatchupBonus = 3, FlingHorizontal = 92, FlingVertical = 28, RagdollDuration = 1.25},
}

function ChaseService.new(config, mapService, playerData, baseService, chestService, notifications)
	assert(type(config) == "table", "ChaseService.new requires the Config table")
	local self = setmetatable({}, ChaseService)
	self.Config = config
	self.Map = mapService
	self.PlayerData = playerData
	self.Bases = baseService
	self.Chests = chestService
	self.Notifications = notifications
	self.State = "IDLE"
	self.ActiveRun = nil
	self.DroppedChest = nil
	self.DropSerial = 0
	self.StartingPlayer = nil
	self.RecentFalls = {}
	self.HeartbeatConnection = nil
	self.FallConnection = nil
	self.GuardianSettingsCache = {}
	self.GuardianHomeCFrames = {}
	self.GuardianBlueprints = {}
	self.GuardianParents = {}
	self.GuardianNames = {}
	self.GuardianLeaseSerial = 0
	self.GuardianMaintenanceAccumulator = 0
	self.ReturningGuardians = {}
	self.Randomizer = Random.new()

	local remoteFolderName = type(config.RemoteFolderName) == "string"
		and config.RemoteFolderName
		or "ChestChaseRemotes"
	local runAlertRemoteName = type(config.ChestRunAlertRemote) == "string"
		and config.ChestRunAlertRemote
		or "ChestRunAlert"
	if config.ChestRunAlertRemote == nil then
		warn("[ChestChase] Config.ChestRunAlertRemote was missing; using ChestRunAlert.")
	end

	local remoteFolder = ReplicatedStorage:FindFirstChild(remoteFolderName)
	if not remoteFolder then
		remoteFolder = Instance.new("Folder")
		remoteFolder.Name = remoteFolderName
		remoteFolder.Parent = ReplicatedStorage
	end
	assert(remoteFolder:IsA("Folder"), string.format(
		"[%s] ReplicatedStorage.%s must be a Folder.",
		tostring(config.Version or "ChestChase"),
		remoteFolderName
		))

	local runAlertRemote = remoteFolder:FindFirstChild(runAlertRemoteName)
	if not runAlertRemote then
		runAlertRemote = Instance.new("RemoteEvent")
		runAlertRemote.Name = runAlertRemoteName
		runAlertRemote.Parent = remoteFolder
	end
	assert(runAlertRemote:IsA("RemoteEvent"), string.format(
		"[%s] %s must be a RemoteEvent.",
		tostring(config.Version or "ChestChase"),
		runAlertRemoteName
		))
	self.RunAlertRemote = runAlertRemote
	assert(type(config.GetGuardianChaseSpeed) == "function", "[V0.51] Install the matching Config with ChaseService.")
	runAlertRemote:SetAttribute("HeartbeatSoundId", config.ChaseHeartbeatSoundId)
	runAlertRemote:SetAttribute("HeartbeatMaxVolume", config.ChaseHeartbeatMaxVolume)
	runAlertRemote:SetAttribute("HeartbeatDistance", config.ChaseHeartbeatDistance)
	runAlertRemote:SetAttribute("CatchDistance", config.ChaserCatchDistance)
	runAlertRemote:SetAttribute("SuccessSoundId", config.ChaseSuccessSoundId or "")
	-- R123: publish the run alarm id up front so clients preload it (it was only sent with the first "Show").
	local alarmSoundId = config.GuardianAlertSoundId
	if type(alarmSoundId) ~= "string" or not string.match(alarmSoundId, "^rbxassetid://%d+$") then
		alarmSoundId = config.ChestAlarmSoundId
	end
	runAlertRemote:SetAttribute("AlarmSoundId", type(alarmSoundId) == "string" and alarmSoundId or "")
	runAlertRemote:SetAttribute("SuccessSoundVolume", config.ChaseSuccessSoundVolume or 0.18)
	runAlertRemote:SetAttribute("SuccessFlashStrength", config.ChaseSuccessFlashStrength or 0.32)
	runAlertRemote:SetAttribute("SuccessFlashDuration", config.ChaseSuccessFlashDuration or 0.9)
	return self
end

function ChaseService:_clearRunEffects(run)
	if not run or not run.Player then return end
	run.Player:SetAttribute("ChestChaseRunActive", false)
	if run.Player.Parent then
		self.RunAlertRemote:FireClient(run.Player, "Hide", nil, nil, run.GuardianLeaseToken)
	end
end

function ChaseService:_publishRunEffects(run, distance, deltaTime)
	run.EffectsElapsed = (run.EffectsElapsed or 0) + deltaTime
	if run.EffectsElapsed < self.Config.ChaseEffectsUpdateInterval then return end
	run.EffectsElapsed = run.EffectsElapsed % self.Config.ChaseEffectsUpdateInterval
	self.RunAlertRemote:FireClient(run.Player, "Proximity", distance,
		run.LastGuardianTravelSpeed, run.GuardianLeaseToken,run.Stage)
end

function ChaseService:_getGuardianHomeCFrame(stage, fallbackPosition)
	local cached = self.GuardianHomeCFrames[stage]
	if cached then
		return cached
	end

	local guardian = self.Map.GuardiansByStage and self.Map.GuardiansByStage[stage]
	local root = guardian and (
		guardian:FindFirstChild("HumanoidRootPart")
			or guardian.PrimaryPart
			or guardian:FindFirstChildWhichIsA("BasePart", true)
	)
	if root and root:IsA("BasePart") then
		local homeCFrame = guardian:GetPivot()
		self.GuardianHomeCFrames[stage] = homeCFrame
		return homeCFrame
	end

	local fallbackCFrame = CFrame.new(fallbackPosition or Vector3.new(0, 6.5, 0))
	self.GuardianHomeCFrames[stage] = fallbackCFrame
	return fallbackCFrame
end

function ChaseService:_getGuardianSettings(stage)
	local normalizedStage = math.clamp(
		math.floor(tonumber(stage) or 1),
		1,
		self.Config.StageCount
	)
	local cached = self.GuardianSettingsCache[normalizedStage]
	if cached then
		return cached
	end

	local defaults = DEFAULT_GUARDIAN_SETTINGS_BY_STAGE[math.min(normalizedStage,#DEFAULT_GUARDIAN_SETTINGS_BY_STAGE)]
	local settingsByStage = self.Config.GuardianSettingsByStage
	local configured = type(settingsByStage) == "table"
		and (settingsByStage[normalizedStage] or settingsByStage[tostring(normalizedStage)])
		or nil
	if type(configured) ~= "table" then
		configured = {}
	end

	local sanitized = {
        AdaptiveHeadroom = math.clamp(tonumber(configured.AdaptiveHeadroom) or 4,0,20),
		MinimumSpeed = math.max(
			1,
			tonumber(configured.MinimumSpeed) or defaults.MinimumSpeed
		),
		PlayerSpeedRatio = math.clamp(
			tonumber(configured.PlayerSpeedRatio) or defaults.PlayerSpeedRatio,
			0.10,
			0.95
		),
		CatchupBonus = math.max(
			0,
			tonumber(configured.CatchupBonus) or defaults.CatchupBonus
		),
		FlingHorizontal = math.max(
			1,
			tonumber(configured.FlingHorizontal) or defaults.FlingHorizontal
		),
		FlingVertical = math.max(
			0,
			tonumber(configured.FlingVertical) or defaults.FlingVertical
		),
		RagdollDuration = math.clamp(
			tonumber(configured.RagdollDuration) or defaults.RagdollDuration,
			0.40,
			2
		),
	}

	if configured.MinimumSpeed == nil
		or configured.PlayerSpeedRatio == nil
		or configured.CatchupBonus == nil
		or configured.FlingHorizontal == nil
		or configured.FlingVertical == nil
		or configured.RagdollDuration == nil then
		warn(string.format(
			"[%s] Guardian settings for Stage %d were incomplete; safe defaults filled the missing values.",
			tostring(self.Config.Version or "ChestChase"),
			normalizedStage
			))
	end

	self.GuardianSettingsCache[normalizedStage] = sanitized
	return sanitized
end

function ChaseService:IsPlayerBusy(player)
	return (self.ActiveRun and self.ActiveRun.Player == player)
		or self.StartingPlayer == player
end

function ChaseService:_createCarriedChest(character, _rootPart, chest)
    local humanoid=character:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid:UnequipTools() end
    local old=character:FindFirstChild("CarriedSeed");if old then old:Destroy() end
    local model=require(ReplicatedStorage.SeedPackVisuals).CarryBag(character,chest.Stage,chest.BagVariant,chest.SeedScale,chest.PackSize,chest.PackMutation,chest.PackShape) -- R151: chest.PackShape = the pack's chip-bag shape (the world seed's roll, cloned with the seed)
    if model then require(ReplicatedStorage.ItemEffectAnchor).Set(model,chest.Weather,nil,chest.PackSize,2*(chest.PackSize or 1))end
    assert(model,"Character torso is not ready")
    model:SetAttribute("Stage",chest.Stage)
    return model
end

function ChaseService:_getGroundedDropPosition(run)
	local rootPart = run.HumanoidRootPart
	local fallback = rootPart.Position - Vector3.new(0, 2.25, 0)
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = {
		run.Character,
		self.Map.RuntimeFolder,
	}

	local result = Workspace:Raycast(
		rootPart.Position + Vector3.new(0, 5, 0),
		Vector3.new(0, -35, 0),
		parameters
	)
	if result then
		return Vector3.new(rootPart.Position.X, result.Position.Y + 2.2, rootPart.Position.Z)
	end
	return fallback
end

function ChaseService:_createDroppedChest(position, chest, dropToken)
    local frame=self.Chests:FindPackPlacement(position,chest.Stage,chest.BagVariant,chest.PackSize,chest.OriginSlot,self.Drops)
    if not frame then return nil end
    position=frame.Position
	local model = Instance.new("Model")
	model.Name = string.format("DroppedSeed_Stage%d", chest.Stage)
	model:SetAttribute("DroppedChest", true)
	model.ModelStreamingMode=Enum.ModelStreamingMode.Persistent
	model:SetAttribute("DroppedSeed", true)
	model:SetAttribute("BiomeSeedPack", true)
	model:SetAttribute("Stage", chest.Stage)
	model:SetAttribute("SeedName", "Seed Sack")
    model:SetAttribute("BagVariant",chest.BagVariant)
    model:SetAttribute("SeedScale",chest.SeedScale)
    model:SetAttribute("PackSize",chest.PackSize);model:SetAttribute("PackMutation",chest.PackMutation);model:SetAttribute("PackShape",chest.PackShape)
	model.Parent = self.Map.RuntimeFolder

	local body = self.Map:CreateRuntimePart({Name = "Body", Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(position), Anchored = true, CanCollide = false, Parent = model})
	body.Transparency = 1
	body.CanTouch = false
	body.CanQuery = false
	local packet = self.Chests:BuildSeedPacket(nil,body.CFrame,model,nil,nil,chest.Stage,chest.BagVariant,chest.SeedScale,chest.PackSize,chest.PackMutation,chest.PackShape)
    require(ReplicatedStorage.ItemEffectAnchor).Set(packet,chest.Weather,nil,chest.PackSize,2*(chest.PackSize or 1))
	local latch = packet.PrimaryPart

	local glow = Instance.new("PointLight")
	glow.Name = "DropGlow"
	glow.Color = chest.AccentColor or Color3.fromRGB(100, 210, 112)
	glow.Brightness = 0
	glow.Range = 14
	glow.Parent = body

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RecoverPrompt"
	prompt.ActionText = "STEAL"
	prompt.ObjectText = ""
	prompt.HoldDuration = self.Config.DroppedStealHoldSeconds or .5 -- R125: hold E to steal (short: a drop lasts 5 s)
	prompt.MaxActivationDistance = 24
	prompt.RequiresLineOfSight = false
    local bounds=self.Chests:GetPackBounds(chest.Stage,chest.BagVariant,chest.PackSize)
    local pickup=Instance.new('Attachment');pickup.Name='PackPickupPoint'
    pickup.CFrame=CFrame.new(0,bounds.MinY+1.5,chest.PackSize>10 and 0 or -bounds.Radius*.82);pickup.Parent=body
    prompt.Parent=pickup

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DropTimer"
	billboard.Adornee = body
	billboard.Size = UDim2.fromOffset(220, 58)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Parent = body

	local label = Instance.new("TextLabel")
	label.Name = "Timer"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = string.format(
		"%ds",
		math.ceil(self.Config.DroppedChestDuration)
	)
	label.TextColor3 = chest.AccentColor or Color3.fromRGB(100, 210, 112)
	label.TextSize = 20
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Parent = billboard

	model.PrimaryPart = body
	prompt.Triggered:Connect(function(player)
		self:_claimDroppedChest(player, dropToken)
	end)
	return model, prompt, label
end

function ChaseService:_createFallbackGuardian(position, stage)
	local model = Instance.new("Model")
	model.Name = string.format("ActiveGuardian_Stage%d", stage)
	model:SetAttribute("Stage", stage)
	model:SetAttribute("FallbackGuardian", true)
	model.Parent = self.Map.RuntimeFolder

	local root = self.Map:CreateRuntimePart({
		Name = "HumanoidRootPart",
		Size = Vector3.new(2, 2, 1),
		CFrame = CFrame.new(position),
		CanCollide = false,
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(40, 40, 48),
		Parent = model,
	})
	root.Transparency = 1
	root.CanTouch = false
	root.CanQuery = false

	local accent = self.Map:GetStageAccent(stage)
	self.Map:CreateRuntimePart({
		Name = "TorsoPlaceholder",
		Size = Vector3.new(4, 5, 2.4),
		CFrame = CFrame.new(position + Vector3.new(0, 2.2, 0)),
		CanCollide = false,
		Material = Enum.Material.Metal,
		Color = accent:Lerp(Color3.fromRGB(36, 40, 50), 0.65),
		Parent = model,
	})
	self.Map:CreateRuntimePart({
		Name = "HeadPlaceholder",
		Size = Vector3.new(3.2, 3.2, 3.2),
		CFrame = CFrame.new(position + Vector3.new(0, 6.1, 0)),
		CanCollide = false,
		Material = Enum.Material.Neon,
		Color = accent,
		Shape = Enum.PartType.Ball,
		Parent = model,
	})

	for _, side in ipairs({-1, 1}) do
		self.Map:CreateRuntimePart({
			Name = side < 0 and "LeftArmPlaceholder" or "RightArmPlaceholder",
			Size = Vector3.new(1.4, 5, 1.4),
			CFrame = CFrame.new(position + Vector3.new(side * 2.8, 2.1, 0)),
			CanCollide = false,
			Material = Enum.Material.Metal,
			Color = accent:Lerp(Color3.fromRGB(36, 40, 50), 0.65),
			Parent = model,
		})
		self.Map:CreateRuntimePart({
			Name = side < 0 and "LeftLegPlaceholder" or "RightLegPlaceholder",
			Size = Vector3.new(1.5, 4, 1.5),
			CFrame = CFrame.new(position + Vector3.new(side * 1.05, -1.4, 0)),
			CanCollide = false,
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(45, 46, 57),
			Parent = model,
		})
	end

	model.PrimaryPart = root
	self.Chests:DressGuardian(model, stage)
	return model
end

function ChaseService:_ensureGuardianVisibility(model, stage, root)
	local hasVisibleGeometry = false
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart")
			and (descendant ~= root or descendant.Name ~= "HumanoidRootPart")
			and descendant.Name ~= "GuardianVisibilityCore"
			and descendant.Name ~= "GuardianEmergencyBody"
			and descendant.Name ~= "GuardianEmergencyHead"
			and descendant.Transparency < 0.98 then
			hasVisibleGeometry = true
			break
		end
	end

	if hasVisibleGeometry and (model:GetAttribute("GardenerArtVersion") == 76 or model:GetAttribute("GardenerArtVersion") == 91 or model:GetAttribute("KeeperClientAnimated") == true) then return end

	local accent = self.Map:GetStageAccent(stage)
	local pivot = model:GetPivot()

	if not hasVisibleGeometry then
		-- A future NPC can accidentally contain only transparent parts. Supply a
		-- full placeholder body so the chaser is still readable in that session.
		local body = model:FindFirstChild("GuardianEmergencyBody")
		if not body or not body:IsA("BasePart") then
			body = self.Map:CreateRuntimePart({
				Name = "GuardianEmergencyBody",
				Size = Vector3.new(3.8, 4.8, 2.2),
				CFrame = pivot * CFrame.new(0, 2.5, 0),
				Anchored = true,
				CanCollide = false,
				Material = Enum.Material.Metal,
				Color = accent:Lerp(Color3.fromRGB(34, 37, 49), 0.64),
				Parent = model,
			})
		end
		local head = model:FindFirstChild("GuardianEmergencyHead")
		if not head or not head:IsA("BasePart") then
			head = self.Map:CreateRuntimePart({
				Name = "GuardianEmergencyHead",
				Size = Vector3.new(3.1, 3.1, 3.1),
				CFrame = pivot * CFrame.new(0, 6.35, 0),
				Anchored = true,
				CanCollide = false,
				Material = Enum.Material.Neon,
				Color = accent,
				Shape = Enum.PartType.Ball,
				Parent = model,
			})
		end
		body.Transparency = 0
		head.Transparency = 0
		model:SetAttribute("GuardianEmergencyVisuals", true)
	end

	-- This small glowing core is created for every guardian, even when the NPC
	-- body is valid. It makes invisibility impossible to miss and gives future
	-- models a consistent alert marker.
	local visibleCore = model:FindFirstChild("GuardianVisibilityCore")
	if not visibleCore or not visibleCore:IsA("BasePart") then
		visibleCore = self.Map:CreateRuntimePart({
			Name = "GuardianVisibilityCore",
			Size = Vector3.new(1.5, 1.5, 1.5),
			CFrame = pivot * CFrame.new(0, 5.2, -1.25),
			Anchored = true,
			CanCollide = false,
			Material = Enum.Material.Neon,
			Color = accent,
			Shape = Enum.PartType.Ball,
			Parent = model,
		})
	end
	visibleCore.Transparency = 0
	visibleCore.Color = accent
	local coreLight = visibleCore:FindFirstChild("GuardianCoreLight")
	if coreLight and not coreLight:IsA("PointLight") then
		coreLight:Destroy()
		coreLight = nil
	end
	if not coreLight then
		coreLight = Instance.new("PointLight")
		coreLight.Name = "GuardianCoreLight"
		coreLight.Parent = visibleCore
	end
	coreLight.Color = accent
	coreLight.Brightness = 0.9
	coreLight.Range = 12

	local highlight = model:FindFirstChild("GuardianVisibilityHighlight")
	if highlight and not highlight:IsA("Highlight") then
		highlight:Destroy()
		highlight = nil
	end
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "GuardianVisibilityHighlight"
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model
	end
	highlight.Adornee = model
	highlight.FillColor = accent
	highlight.FillTransparency = 0.82
	highlight.OutlineColor = accent
	highlight.OutlineTransparency = 0.08
	highlight.Enabled = true
end

-- R121: the chase calls this every Heartbeat for each active keeper. Scan a guardian once, then again
-- only after a BillboardGui/SurfaceGui is added under it (same result, no per-frame GetDescendants).
local noticeWatch = setmetatable({}, {__mode = "k"})
function ChaseService:_setGuardianNoticeVisual(guardian, isVisible)
	-- Pose, RUN!! and the existing sound communicate notice without floating NPC tags.
	if not guardian then return end
	local watch = noticeWatch[guardian]
	if watch and not watch.Dirty then return end
	if not watch then
		watch = {Dirty = true}
		watch.Connection = guardian.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BillboardGui") or descendant:IsA("SurfaceGui") then watch.Dirty = true end
		end)
		noticeWatch[guardian] = watch
	end
	watch.Dirty = false
	for _, descendant in ipairs(guardian:GetDescendants()) do
		if descendant:IsA("BillboardGui") or descendant:IsA("SurfaceGui") then descendant:Destroy() end
	end
end

function ChaseService:_preparePersistentGuardian(model, stage)
	if not model or not model.Parent then
		return false
	end

	local root = model:FindFirstChild("HumanoidRootPart")
		or model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart", true)
	if not root or not root:IsA("BasePart") then
		return false
	end

	model.PrimaryPart = root
	model.Archivable = true
	model:SetAttribute("PersistentBiomeGuardian", true)
	model:SetAttribute("Stage", stage)
	-- R141: the walk speed that outruns this keeper (KeeperSpeedLabels shows the Speed it takes over its head).
	model:SetAttribute("KeeperEscapeSpeed", require(ReplicatedStorage.KeeperPursuit).EscapeSpeed(stage))
	local homes = self.GuardianHomeCFrames; if homes and homes[stage] then model:SetAttribute("KeeperHome", homes[stage].Position) end -- R153: the spawn point the SPEED NEEDED sign is pinned to (KeeperSpeedLabels)
	game:GetService("CollectionService"):AddTag(model, "BiomeKeeper")
	local isPlaceholder = model:GetAttribute("FutureNPCModelSlot") == true
		or model:GetAttribute("FallbackGuardian") == true

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BaseScript") then
			descendant.Disabled = true
		elseif descendant:IsA("ProximityPrompt") then
			descendant.Enabled = false
		elseif descendant:IsA("BasePart") then
			local savedTransparency = descendant:GetAttribute(
				"PersistentGuardianTransparency"
			)
			local hiddenTransparency = descendant:GetAttribute(
				"GuardianOriginalTransparency"
			)
			if savedTransparency == nil then
				savedTransparency = hiddenTransparency
				if savedTransparency == nil then
					savedTransparency = descendant.Transparency
				end
				descendant:SetAttribute(
					"PersistentGuardianTransparency",
					savedTransparency
				)
			end

			if isPlaceholder and descendant ~= root then
				-- The map currently uses a deliberately simple NPC placeholder.
				-- It must stay visible regardless of a previous hide-state attribute.
				descendant.Transparency = 0
			else
				descendant.Transparency = savedTransparency
			end
			descendant:SetAttribute("GuardianOriginalTransparency", nil)
			descendant:SetAttribute("GuardianOriginalCanCollide", nil)
			descendant:SetAttribute("GuardianOriginalCanTouch", nil)
			descendant:SetAttribute("GuardianOriginalCanQuery", nil)
			descendant.Anchored = descendant == root or model:GetAttribute("GardenerArtVersion") ~= 76
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("Highlight")
			or descendant:IsA("Light") then
			descendant.Enabled = true
		elseif descendant:IsA("BillboardGui")
			and descendant.Name ~= "GuardianNoticeBillboard" then
			descendant.Enabled = true
		end
	end
	self:_ensureGuardianVisibility(model, stage, root)

	return true
end

function ChaseService:_captureGuardianBlueprints()
	for stage = 1, self.Config.StageCount do
		local guardian = self.Map.GuardiansByStage
			and self.Map.GuardiansByStage[stage]
		if guardian and guardian.Parent then
			self.Chests:DressGuardian(guardian, stage)
			self.GuardianParents[stage] = guardian.Parent
			self.GuardianNames[stage] = guardian.Name
			self.GuardianHomeCFrames[stage] = guardian:GetPivot()

			guardian.Archivable = true
			local blueprint = guardian:Clone()
			blueprint.Parent = nil
			self.GuardianBlueprints[stage] = blueprint
			self:_preparePersistentGuardian(guardian, stage)
			pivotKeeper(guardian, self.GuardianHomeCFrames[stage])
			guardian:SetAttribute("GuardianBehavior", "GUARDING")
			guardian:SetAttribute("GuardianLeaseToken", 0)
		end
	end
end

function ChaseService:_adoptGuardianAsPersistent(stage, guardian, homeCFrame)
	if not guardian or not guardian.Parent or not guardian.PrimaryPart then
		return nil
	end

	local previous = self.Map.GuardiansByStage
		and self.Map.GuardiansByStage[stage]
	if previous and previous ~= guardian and previous.Parent then
		local previousLease = tonumber(
			previous:GetAttribute("GuardianLeaseToken")
		) or 0
		if previousLease ~= 0 then
			return previous
		end
		previous:Destroy()
	end

	self.Map.GuardiansByStage = self.Map.GuardiansByStage or {}
	self.Map.GuardiansByStage[stage] = guardian
	self.GuardianParents[stage] = guardian.Parent
	self.GuardianNames[stage] = guardian.Name
	self.GuardianHomeCFrames[stage] = homeCFrame
		or self.GuardianHomeCFrames[stage]
		or guardian:GetPivot()
	guardian:SetAttribute("DisposableGuardianFallback", nil)
	self:_preparePersistentGuardian(guardian, stage)

	if not self.GuardianBlueprints[stage] then
		guardian.Archivable = true
		local blueprint = guardian:Clone()
		blueprint.Parent = nil
		self.GuardianBlueprints[stage] = blueprint
	end

	return guardian
end

function ChaseService:_ensurePersistentGuardian(stage)
	local guardian = self.Map.GuardiansByStage
		and self.Map.GuardiansByStage[stage]
	if guardian and self:_preparePersistentGuardian(guardian, stage) then
		return guardian
	end

	local blueprint = self.GuardianBlueprints[stage]
	if not blueprint then
		local stageChest = self.Map.ChestsByStage
			and self.Map.ChestsByStage[stage]
		local fallbackPosition = stageChest
			and (stageChest.Body.Position + Vector3.new(0, 0, 8))
			or Vector3.new(0, 6.5, 0)
		local homeCFrame = self.GuardianHomeCFrames[stage]
			or CFrame.new(fallbackPosition)
		local fallback = self:_createFallbackGuardian(
			homeCFrame.Position,
			stage
		)
		fallback.Name = self.GuardianNames[stage]
			or string.format("Guardian_Stage%d", stage)
		local adopted = self:_adoptGuardianAsPersistent(
			stage,
			fallback,
			homeCFrame
		)
		warn(string.format(
			"[%s] Built a permanent fallback for missing Stage %d guardian data.",
			tostring(self.Config.Version or "ChestChase"),
			stage
			))
		return adopted
	end
	if guardian and guardian.Parent then
		guardian:Destroy()
	end

	local replacement = blueprint:Clone()
	replacement.Name = self.GuardianNames[stage]
		or string.format("Guardian_Stage%d", stage)
	local savedParent = self.GuardianParents[stage]
	if not savedParent or not savedParent.Parent then
		savedParent = self.Map.MapRoot:FindFirstChild("GuardianEncounters")
			or self.Map.MapRoot
	end
	replacement.Parent = savedParent
	self.Map.GuardiansByStage[stage] = replacement
	self:_preparePersistentGuardian(replacement, stage)
	pivotKeeper(replacement, self:_getGuardianHomeCFrame(stage))
	replacement:SetAttribute("GuardianBehavior", "GUARDING")
	replacement:SetAttribute("GuardianLeaseToken", 0)

	warn(string.format(
		"[%s] Restored the persistent Stage %d guardian from its backup.",
		tostring(self.Config.Version or "ChestChase"),
		stage
		))
	return replacement
end

function ChaseService:_createChaser(position, stage)
	local model = self:_ensurePersistentGuardian(stage)
	if not model then
		model = self:_createFallbackGuardian(position, stage)
		model = self:_adoptGuardianAsPersistent(
			stage,
			model,
			CFrame.new(position)
		)
	end

	model:SetAttribute("ActiveGuardianChaser", true)
	local homeRotation = self:_getGuardianHomeCFrame(stage).Rotation
	pivotKeeper(model, CFrame.new(position) * homeRotation)
	return model
end

-- Compatibility shim for older call sites. The permanent biome guardian is
-- never hidden anymore; the same model guards, chases, and returns to camp.
function ChaseService:_setGuardianTemplateVisible(stage, _isVisible)
	self:_ensurePersistentGuardian(stage)
end

function ChaseService:_releaseGuardian(stage, guardian, leaseToken)
	if not guardian then
		return
	end

	local persistent = self.Map.GuardiansByStage
		and self.Map.GuardiansByStage[stage]
	if guardian ~= persistent and guardian.Parent and guardian.PrimaryPart then
		local persistentLease = persistent
			and tonumber(persistent:GetAttribute("GuardianLeaseToken"))
			or 0
		if persistentLease == 0 or persistentLease == leaseToken then
			guardian = self:_adoptGuardianAsPersistent(
				stage,
				guardian,
				self:_getGuardianHomeCFrame(stage)
			) or guardian
			persistent = self.Map.GuardiansByStage[stage]
		end
	end
	if guardian == persistent then
		local currentLease = tonumber(guardian:GetAttribute("GuardianLeaseToken")) or 0
		if leaseToken and currentLease ~= leaseToken then
			return
		end
		self:_preparePersistentGuardian(guardian, stage)
		self:_setGuardianNoticeVisual(guardian, false)
		pivotKeeper(guardian, self:_getGuardianHomeCFrame(stage))
		guardian:SetAttribute("GuardianBehavior", "GUARDING")
		guardian:SetAttribute("ReturningToCamp", false)
		guardian:SetAttribute("ActiveGuardianChaser", false)
		guardian:SetAttribute("GuardianLeaseToken", 0)
		return
	end

	-- Never destroy a visible guardian during a late expiry/reclaim handoff.
	-- A newer leased guardian owns the stage, so this stale model is parked at
	-- camp and left visible instead of disappearing in front of the player.
	if guardian.Parent and guardian.PrimaryPart then
		self:_preparePersistentGuardian(guardian, stage)
		self:_setGuardianNoticeVisual(guardian, false)
		pivotKeeper(guardian, self:_getGuardianHomeCFrame(stage))
		guardian:SetAttribute("GuardianBehavior", "GUARDING_STALE")
		guardian:SetAttribute("ReturningToCamp", false)
		guardian:SetAttribute("ActiveGuardianChaser", false)
	end
	self:_ensurePersistentGuardian(stage)
end

function ChaseService:_stepGuardianToCFrame(
	guardian,
	targetCFrame,
	travelSpeed,
	deltaTime
)
	local core = guardian and guardian.PrimaryPart
	if not guardian or not guardian.Parent or not core then
		return false
	end

	local offset = targetCFrame.Position - core.Position
	local distance = offset.Magnitude
	if distance <= 0.12 then
        guardian:SetAttribute("KeeperTravelSpeed",0)
		pivotKeeper(guardian, targetCFrame)
		return true
	end

	guardian:SetAttribute("KeeperTravelSpeed", math.floor(math.max(1,tonumber(travelSpeed) or 1)*2+.5)/2)
	local stepDistance = math.min(
		math.max(1, tonumber(travelSpeed) or 1) * deltaTime,
		distance
	)
	if stepDistance >= distance - 0.001 then
		guardian:SetAttribute("KeeperTravelSpeed",0)
		-- Never call CFrame.lookAt(target, target). A zero direction can create an
		-- invalid transform and make the model appear to vanish on its final step.
		pivotKeeper(guardian, targetCFrame)
		return true
	end

	local newPosition = core.Position + offset.Unit * stepDistance
	pivotKeeper(guardian, CFrame.lookAt(newPosition, targetCFrame.Position))
	return false
end

function ChaseService:_finishGuardianAtHome(
	stage,
	guardian,
	homeCFrame,
	leaseToken
)
	if not guardian or not guardian.Parent or not guardian.PrimaryPart then
		guardian = self:_ensurePersistentGuardian(stage)
	end
	if not guardian then
		return
	end

	local currentLease = tonumber(
		guardian:GetAttribute("GuardianLeaseToken")
	) or 0
	if leaseToken and currentLease ~= leaseToken then
		return
	end

	guardian = self:_adoptGuardianAsPersistent(
		stage,
		guardian,
		homeCFrame
	) or guardian
	pivotKeeper(guardian, homeCFrame)
	self:_ensureGuardianVisibility(guardian, stage, guardian.PrimaryPart)
	self:_setGuardianNoticeVisual(guardian, false)
	guardian:SetAttribute("GuardianBehavior", "GUARDING")
	guardian:SetAttribute("KeeperTravelSpeed",0)
	guardian:SetAttribute("ReturningToCamp", false)
	guardian:SetAttribute("ActiveGuardianChaser", false)
	guardian:SetAttribute("GuardianLeaseToken", 0)
	guardian:SetAttribute("GuardianReturnedAt", os.clock())
end

function ChaseService:_beginGuardianReturn(
	stage,
	guardian,
	homeCFrame,
	leaseToken,
	returnSpeed
)
	if not guardian or not guardian.Parent or not guardian.PrimaryPart then
		guardian = self:_ensurePersistentGuardian(stage)
	end
	if not guardian then
		return
	end
	guardian = self:_adoptGuardianAsPersistent(
		stage,
		guardian,
		homeCFrame or self:_getGuardianHomeCFrame(stage)
	) or guardian

	guardian:SetAttribute("GuardianBehavior", "RETURNING")
	guardian:SetAttribute("ReturningToCamp", true)
	guardian:SetAttribute("GuardianLeaseToken", leaseToken or 0)
	self:_setGuardianNoticeVisual(guardian, false)
	self.ReturningGuardians[stage] = {
		Guardian = guardian,
		HomeCFrame = homeCFrame or self:_getGuardianHomeCFrame(stage),
		LeaseToken = leaseToken,
		Speed = require(ReplicatedStorage.RouteBalance83).KeeperSpeeds[stage][3],
	}
end

function ChaseService:_updateReturningGuardians(deltaTime)
	for stage, record in pairs(self.ReturningGuardians) do
		local guardian = record.Guardian
		local core = guardian and guardian.PrimaryPart
		if not guardian or not guardian.Parent or not core then
			guardian = self:_ensurePersistentGuardian(stage)
			if not guardian then
				self.ReturningGuardians[stage] = nil
				continue
			end
			record.Guardian = guardian
			core = guardian.PrimaryPart
			guardian:SetAttribute("GuardianLeaseToken", record.LeaseToken or 0)
		end

		-- Let the visible strike finish before turning home; the player is already flung.
		if KeeperCombat.HoldAfterHit(stage,workspace:GetServerTimeNow(),guardian:GetAttribute('KeeperAttackAt'),guardian:GetAttribute('KeeperLastHitAt'))then
			guardian:SetAttribute('GuardianBehavior','ATTACKING');guardian:SetAttribute('KeeperTravelSpeed',0);continue
		end
		guardian:SetAttribute('GuardianBehavior','RETURNING')
		guardian:SetAttribute("KeeperTravelSpeed",record.Speed)
		local homeCFrame = record.HomeCFrame
		local arrived = self:_stepGuardianToCFrame(
			guardian,
			homeCFrame,
			record.Speed,
			deltaTime
		)
		if arrived then
			self.ReturningGuardians[stage] = nil
			self:_finishGuardianAtHome(
				stage,
				guardian,
				homeCFrame,
				record.LeaseToken
			)
		end
	end
end

function ChaseService:_maintainGuardians()
	for stage = 1, self.Config.StageCount do
		local guardian = self:_ensurePersistentGuardian(stage)
		if guardian then
			local isActiveGuardian = self.ActiveRun
				and self.ActiveRun.Stage == stage
				and self.ActiveRun.Chaser == guardian
			local isDroppedGuardian = self.DroppedChest
				and self.DroppedChest.Stage == stage
				and self.DroppedChest.Chaser == guardian
			local isReturningGuardian = self.ReturningGuardians[stage]
				and self.ReturningGuardians[stage].Guardian == guardian
			if not isActiveGuardian
				and not isDroppedGuardian
				and not isReturningGuardian then
				pivotKeeper(guardian, self:_getGuardianHomeCFrame(stage))
				guardian:SetAttribute("GuardianBehavior", "GUARDING")
				guardian:SetAttribute("GuardianLeaseToken", 0)
			end
		end
	end
end

function ChaseService:_restorePhysicalSpeed(player, humanoid)
	if self.Ragdoll and self.Ragdoll:IsActive(player) then return end
	if not humanoid or not humanoid.Parent or humanoid.Health <= 0 then
		return
	end
	local currentSpeedStat = self.PlayerData:GetOrCreateSpeedValue(player).Value
	local earned=self.Config.GetPlayerWalkSpeed(player,currentSpeedStat)
    local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
    humanoid.WalkSpeed=require(game:GetService('ReplicatedStorage').RunnerMotion).AtPosition(earned,root and root.Position)
    player:SetAttribute('PhysicalWalkSpeed',math.floor(earned*100+.5)/100)
end

function ChaseService:_activateRun(
	player,
	chest,
	character,
	humanoid,
	rootPart,
	guardianSourcePosition,
	guardianStartDistance,
	existingChaser
)
	local carriedChest = self:_createCarriedChest(character, rootPart, chest)
	self.Map:SetChestVisible(chest, false)
	self.Map:FlattenCompletedStages(chest.Stage)

	local fallbackDistance = tonumber(guardianStartDistance) or 0
	local fallbackPosition = guardianSourcePosition
		+ Vector3.new(0, 0, fallbackDistance)
	local guardianHomeCFrame = self:_getGuardianHomeCFrame(
		chest.Stage,
		fallbackPosition
	)
	local chaser = existingChaser
	if not chaser or not chaser.Parent or not chaser.PrimaryPart then
		local returning = self.ReturningGuardians[chest.Stage]
		if returning and returning.Guardian
			and returning.Guardian.Parent
			and returning.Guardian.PrimaryPart then
			chaser = returning.Guardian
			self.ReturningGuardians[chest.Stage] = nil
		end
	end
	local reusedChaser = chaser ~= nil
	if not chaser or not chaser.Parent or not chaser.PrimaryPart then
		chaser = self:_createChaser(guardianHomeCFrame.Position, chest.Stage)
	end
	chaser = self:_adoptGuardianAsPersistent(
		chest.Stage,
		chaser,
		guardianHomeCFrame
	) or chaser
	self.GuardianLeaseSerial = self.GuardianLeaseSerial + 1
	local guardianLeaseToken = self.GuardianLeaseSerial
	local noticeDelay = math.max(
		0,
		tonumber(self.Config.GuardianNoticeDelay) or 0.5
	)
	local chaseStartsAt = os.clock() + noticeDelay
	chaser:SetAttribute("GuardianBehavior", "ALERTED")
	chaser:SetAttribute("ReturningToCamp", false)
	chaser:SetAttribute("GuardianLeaseToken", guardianLeaseToken)
	self:_setGuardianNoticeVisual(chaser, true)

	self.ActiveRun = {
		Player = player,
		Character = character,
		Humanoid = humanoid,
		HumanoidRootPart = rootPart,
		Chest = chest,
		Stage = chest.Stage,
		CarriedChest = carriedChest,
		Chaser = chaser,
		GuardianHomeCFrame = guardianHomeCFrame,
		GuardianLeaseToken = guardianLeaseToken,
		ChaseStartsAt = chaseStartsAt,
		CatchEnabledAt = chaseStartsAt + (reusedChaser and 0.85 or 0.35),
		LastGuardianTravelSpeed = self:_getGuardianSettings(
			chest.Stage
		).MinimumSpeed,
	}
	self:_setGuardianTemplateVisible(chest.Stage, false)
	self.StartingPlayer = nil
	self.State = "ACTIVE"
	if not player:GetAttribute("GuardianRagdollActive") then
		player:SetAttribute("GuardianFlingActive", false)
	end
	player:SetAttribute("ChestChaseRunToken", guardianLeaseToken)
	player:SetAttribute("ChestChaseRunActive", true)
	local guardianAlertSoundId = self.Config.GuardianAlertSoundId
	if type(guardianAlertSoundId) ~= "string"
		or not string.match(guardianAlertSoundId, "^rbxassetid://%d+$") then
		guardianAlertSoundId = self.Config.ChestAlarmSoundId
	end
	local guardianAlertVolume = tonumber(self.Config.GuardianAlertVolume)
		or tonumber(self.Config.ChestAlarmVolume)
		or 0.16
	self.RunAlertRemote:FireClient(
		player,
		"Show",
		guardianAlertSoundId,
		guardianAlertVolume,
		guardianLeaseToken,
		character
	)
end

function ChaseService:_applyGuardianFling(run)
    local root=run.HumanoidRootPart
    local keeper=run.Chaser
    local keeperRoot=keeper and keeper.PrimaryPart
    if not root or not root.Parent or not keeperRoot then return false end
    local offset=root.Position-keeperRoot.Position
    local direction=Vector3.new(offset.X,0,offset.Z)
    if direction.Magnitude<.01 then
        local forward=keeperRoot.CFrame.LookVector
        direction=Vector3.new(forward.X,0,forward.Z)
    end
    direction=direction.Magnitude>.01 and direction.Unit or Vector3.new(0,0,-1)
    local settings=self:_getGuardianSettings(run.Stage)
    local special=keeper:GetAttribute('VeiledKeeper81')or(run.Chest and run.Chest.EventKeeper)
    local launch=special and require(game:GetService('ReplicatedStorage').KnockbackConfig).SpecialKeeper
    local horizontal=launch and launch.Horizontal or settings.FlingHorizontal
    local vertical=launch and launch.Vertical or settings.FlingVertical
    local hit=self.Ragdoll:Apply(run.Player,direction*horizontal+Vector3.new(0,vertical,0),"Keeper")
    if not hit then return false end
    local now=workspace:GetServerTimeNow()
    keeper:SetAttribute('KeeperLastHitAt',now)
    self.HitSerial+=1
    self.HitRemote:FireAllClients({Id=self.HitSerial,At=now,Position=root.Position,Stage=run.Stage,
        VoiceId=keeper:GetAttribute('KeeperVoiceId'),VictimUserId=run.Player.UserId,Direction=direction,Veiled=special and true or nil}) -- R124: The Darkened's own catch effect
    return true
end

function ChaseService:_expireDroppedChest(dropToken)
	local dropped = self.DroppedChest
	if self.State ~= "DROPPED"
		or not dropped
		or dropped.Claimed == true
		or dropped.Token ~= dropToken then
		return
	end

	dropped.Claimed = true
	if dropped.Prompt and dropped.Prompt.Parent then
		dropped.Prompt.Enabled = false
	end
	if dropped.Model and dropped.Model.Parent then
		dropped.Model:Destroy()
	end
	local stage = dropped.Stage
	local chaser = dropped.Chaser
	local guardianLeaseToken = dropped.GuardianLeaseToken
	local guardianHomeCFrame = dropped.GuardianHomeCFrame
	dropped.Chaser = nil
	self.DropSerial = self.DropSerial + 1
	self.DroppedChest = nil
	self.State = "IDLE"
	self.StartingPlayer = nil
	self:_beginGuardianReturn(
		stage,
		chaser,
		guardianHomeCFrame,
		guardianLeaseToken,
		dropped.ReturnSpeed
	)
	self.Map:ResetCourse()
end

function ChaseService:_dropChestAfterCatch(run)
	local dropPosition = self:_getGroundedDropPosition(run)
	self.DropSerial = self.DropSerial + 1
	local dropToken = self.DropSerial
	local model, prompt, label = self:_createDroppedChest(
		dropPosition,
		run.Chest,
		dropToken
	)

	self.ActiveRun = nil
	self.StartingPlayer = nil
	self.State = "DROPPED"
	self.DroppedChest = {
		Token = dropToken,
		Chest = run.Chest,
		Stage = run.Stage,
		Position = dropPosition,
		Model = model,
		Prompt = prompt,
		Label = label,
		ExpiresAt = os.clock() + self.Config.DroppedChestDuration,
		Chaser = run.Chaser,
		GuardianLeaseToken = run.GuardianLeaseToken,
		GuardianHomeCFrame = run.GuardianHomeCFrame
			or self:_getGuardianHomeCFrame(run.Stage, dropPosition),
		ReturnSpeed = run.LastGuardianTravelSpeed,
	}
	if run.Chaser and run.Chaser.Parent then
		run.Chaser:SetAttribute("GuardianBehavior", "RETURNING")
		run.Chaser:SetAttribute("ReturningToCamp", true)
	end

	self:_applyGuardianFling(run)
	self.Notifications:Show(
		run.Player,
		string.format(
			"CAUGHT! SEED DROPPED FOR %d SECONDS",
			math.ceil(self.Config.DroppedChestDuration)
		),
		Color3.fromRGB(255, 130, 92),
		3
	)

	task.spawn(function()
		while self.State == "DROPPED"
			and self.DroppedChest
			and self.DroppedChest.Token == dropToken do
			local secondsLeft = math.max(
				0,
				math.ceil(self.DroppedChest.ExpiresAt - os.clock())
			)
			if label.Parent then
				label.Text = secondsLeft > 0
					and string.format("SEED! 🌱 %ds", secondsLeft)
					or "DROPPED SEED  •  LAST CHANCE"
			end
			task.wait(0.1)
		end
	end)

	task.delay(
		self.Config.DroppedChestDuration
			+ (tonumber(self.Config.DroppedChestClaimGrace) or 0.35),
		function()
			self:_expireDroppedChest(dropToken)
		end
	)
end

function ChaseService:_claimDroppedChest(player, dropToken)
	local canReceive, capacityReason = self.PlayerData:CanReceiveSeed(player)
	if not canReceive then
		self.Notifications:Show(player, capacityReason, Color3.fromRGB(255, 187, 91), 3)
		return
	end
	local dropped = self.DroppedChest
	if self.State ~= "DROPPED"
		or not dropped
		or dropped.Token ~= dropToken then
		return
	end
	if not self.PlayerData:IsLoaded(player) then
		self.Notifications:Show(player, "PLAYER DATA IS STILL LOADING", Color3.fromRGB(151, 225, 255), 2)
		return
	end
	if not self.Bases:GetPlayerBase(player) then
		self.Notifications:Show(player, "NO EMPTY BASE IS AVAILABLE", Color3.fromRGB(255, 125, 125), 3)
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end
	if (rootPart.Position - dropped.Position).Magnitude > 26 then
		return
	end
	local claimGrace = math.clamp(
		tonumber(self.Config.DroppedChestClaimGrace) or 0.35,
		0,
		1
	)
	if os.clock() > dropped.ExpiresAt + claimGrace then
		self:_expireDroppedChest(dropToken)
		return
	end

	self.State = "STARTING"
	self.StartingPlayer = player
	dropped.Claimed = true
	dropped.Prompt.Enabled = false
	self.DropSerial = self.DropSerial + 1
	local returningChaser = dropped.Chaser
	if not returningChaser
		or not returningChaser.Parent
		or not returningChaser.PrimaryPart then
		returningChaser = self:_ensurePersistentGuardian(dropped.Stage)
	end
	returningChaser = self:_adoptGuardianAsPersistent(
		dropped.Stage,
		returningChaser,
		dropped.GuardianHomeCFrame
	) or returningChaser
	dropped.Chaser = nil
	if dropped.Model and dropped.Model.Parent then
		dropped.Model:Destroy()
	end
	self.DroppedChest = nil
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero

	self:_activateRun(
		player,
		dropped.Chest,
		character,
		humanoid,
		rootPart,
		dropped.GuardianHomeCFrame.Position,
		0,
		returningChaser
	)
	self.Notifications:Show(
		player,
		"SEED RECLAIMED - RUN!",
		Color3.fromRGB(255, 222, 83),
		2
	)
end

function ChaseService:_crossedBoundary(worldPosition)
	return worldPosition.Z <= self.Map.BaseBoundaryLine.Position.Z
end

function ChaseService:ReturnToIdle()
	if self.ActiveRun then
		if self.ActiveRun.Player then
			self:_clearRunEffects(self.ActiveRun)
			self.ActiveRun.Player:SetAttribute("GuardianFlingActive", false)
		end
		self:_setGuardianTemplateVisible(self.ActiveRun.Stage, true)
		self:_releaseGuardian(
			self.ActiveRun.Stage,
			self.ActiveRun.Chaser,
			self.ActiveRun.GuardianLeaseToken
		)
		if self.ActiveRun.CarriedChest and self.ActiveRun.CarriedChest.Parent then
			self.ActiveRun.CarriedChest:Destroy()
		end
	end
	if self.DroppedChest then
		self:_setGuardianTemplateVisible(self.DroppedChest.Stage, true)
		self:_releaseGuardian(
			self.DroppedChest.Stage,
			self.DroppedChest.Chaser,
			self.DroppedChest.GuardianLeaseToken
		)
		if self.DroppedChest.Model and self.DroppedChest.Model.Parent then
			self.DroppedChest.Model:Destroy()
		end
	end

	self.DropSerial = self.DropSerial + 1
	self.ActiveRun = nil
	self.DroppedChest = nil
	self.StartingPlayer = nil
	self.State = "IDLE"
	self.Map:ResetCourse()
end

function ChaseService:Finish(success, caughtByChaser)
	if self.State ~= "ACTIVE" or not self.ActiveRun then
		return
	end

	self.State = "ENDING"
	local run = self.ActiveRun
	self:_clearRunEffects(run)
	self:_restorePhysicalSpeed(run.Player, run.Humanoid)

	if caughtByChaser then
		if run.CarriedChest and run.CarriedChest.Parent then
			run.CarriedChest:Destroy()
		end
		self:_dropChestAfterCatch(run)
		return
	end

	self:_setGuardianTemplateVisible(run.Stage, true)

	if success then
		self:_beginGuardianReturn(
			run.Stage,
			run.Chaser,
			run.GuardianHomeCFrame,
			run.GuardianLeaseToken,
			run.LastGuardianTravelSpeed
		)
		local secured, bankReason = self.Chests:Bank(run.Player, run.Chest)
		if not secured then
			if run.CarriedChest and run.CarriedChest.Parent then run.CarriedChest:Destroy() end
			self.ActiveRun = nil
			self.StartingPlayer = nil
			self.State = "IDLE"
			self.Map:ResetCourse()
			self.Notifications:Show(run.Player, bankReason or "SEED COULD NOT BE STORED", Color3.fromRGB(255, 187, 91), 3)
			return
		end
		if run.Player.Parent then
			self.RunAlertRemote:FireClient(
				run.Player,
				"Success",
				nil,
				nil,
				run.GuardianLeaseToken,
				run.Character
			)
		end
		if run.CarriedChest and run.CarriedChest.Parent then
			run.CarriedChest:Destroy()
		end
		self.ActiveRun = nil
		self.StartingPlayer = nil
		self.State = "IDLE"
		self.Map:ResetCourse()
		-- V103: the bank-confirmed Success event owns celebration feedback.
		return
	end

	self:_releaseGuardian(run.Stage, run.Chaser, run.GuardianLeaseToken)

	if run.CarriedChest and run.CarriedChest.Parent then
		run.CarriedChest:Destroy()
	end
	self.Notifications:Show(
		run.Player,
		"ESCAPE FAILED - TRY AGAIN",
		Color3.fromRGB(255, 112, 112),
		3
	)

	task.delay(1.5, function()
		self:ReturnToIdle()
	end)
end

function ChaseService:_updateDroppedGuardian(deltaTime)
	if self.State ~= "DROPPED" or not self.DroppedChest then
		return
	end

	local dropped = self.DroppedChest
	if dropped.Claimed == true then
		return
	end
	local chaser = dropped.Chaser
	local core = chaser and chaser.PrimaryPart
	if not chaser or not core or not chaser.Parent then
		chaser = self:_createChaser(
			dropped.GuardianHomeCFrame.Position,
			dropped.Stage
		)
		dropped.Chaser = chaser
		core = chaser.PrimaryPart
		chaser:SetAttribute("GuardianBehavior", "RETURNING")
		chaser:SetAttribute("ReturningToCamp", true)
		chaser:SetAttribute("GuardianLeaseToken", dropped.GuardianLeaseToken)
	end

	local targetCFrame = dropped.GuardianHomeCFrame
	local settings = self:_getGuardianSettings(dropped.Stage)
	local returnSpeed = math.max(
		1,
		tonumber(dropped.ReturnSpeed) or settings.MinimumSpeed
	)
	local arrived = self:_stepGuardianToCFrame(
		chaser,
		targetCFrame,
		returnSpeed,
		deltaTime
	)
	if arrived then
		chaser:SetAttribute("GuardianBehavior", "GUARDING_DROPPED_CHEST")
		chaser:SetAttribute("ReturningToCamp", false)
		return
	end
end

function ChaseService:Begin(player, chest)
	local canReceive, capacityReason = self.PlayerData:CanReceiveSeed(player)
	if not canReceive then
		self.Notifications:Show(player, capacityReason, Color3.fromRGB(255, 187, 91), 3)
		return
	end
	if not self.PlayerData:IsLoaded(player) then
		self.Notifications:Show(player, "PLAYER DATA IS STILL LOADING", Color3.fromRGB(151, 225, 255), 2)
		return
	end
	if not self.Bases:GetPlayerBase(player) then
		self.Notifications:Show(player, "NO EMPTY BASE IS AVAILABLE", Color3.fromRGB(255, 125, 125), 3)
		return
	end
	if self.State ~= "IDLE" then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end
	if (rootPart.Position - chest.Body.Position).Magnitude > 26 then
		return
	end

	self.State = "STARTING"
	self.StartingPlayer = player
	for _, otherChest in ipairs(self.Map.Chests) do
		otherChest.Prompt.Enabled = false
	end
	-- Yield one frame so simultaneous prompt events settle. The visible 0.5
	-- second reaction pause begins after the chest is actually attached.
	task.wait()
	if self.State ~= "STARTING" or self.StartingPlayer ~= player then
		return
	end

	character = player.Character
	humanoid = character and character:FindFirstChildOfClass("Humanoid")
	rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not rootPart or humanoid.Health <= 0 then
		self:ReturnToIdle()
		return
	end

	self:_activateRun(
		player,
		chest,
		character,
		humanoid,
		rootPart,
		chest.Body.Position,
		18
	)
end

function ChaseService:ReturnFallenCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not humanoid or not rootPart or humanoid.Health <= 0 or self.RecentFalls[character] then
		return
	end

	self.RecentFalls[character] = true
	local lostChest = self.State == "ACTIVE" and self.ActiveRun and self.ActiveRun.Player == player
	if lostChest then
		self:Finish(false, false)
	elseif self.State == "STARTING" and self.StartingPlayer == player then
		self:ReturnToIdle()
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
	character:PivotTo(CFrame.new(self.Map.ObbyStartPad.Position + Vector3.new(0, 4, 0)));require(script.Parent.MovementGuard).Reset(player)

	if player then
		self.Notifications:Show(
			player,
			lostChest and "SEED LOST - RETURNED TO START" or "RETURNED TO EXPEDITION START",
			Color3.fromRGB(158, 208, 255),
			2.5
		)
	end

	task.delay(1, function()
		self.RecentFalls[character] = nil
	end)
end

function ChaseService:_updateActiveRun(deltaTime)
	if self.State ~= "ACTIVE" or not self.ActiveRun then
		return
	end

	local run = self.ActiveRun
	local character = run.Player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if character ~= run.Character or not humanoid or not rootPart or humanoid.Health <= 0 then
		self:Finish(false, false)
		return
	end
	if self:_crossedBoundary(rootPart.Position) then
		self:Finish(true, false)
		return
	end

	local chaser = run.Chaser
	local core = chaser and chaser.PrimaryPart
	if not chaser or not core or not chaser.Parent then
		local guardianHomeCFrame = run.GuardianHomeCFrame
			or self:_getGuardianHomeCFrame(run.Stage, rootPart.Position)
		chaser = self:_createChaser(guardianHomeCFrame.Position, run.Stage)
		run.Chaser = chaser
		run.GuardianHomeCFrame = guardianHomeCFrame
		run.CatchEnabledAt = os.clock() + 1
		core = chaser.PrimaryPart
		chaser:SetAttribute("GuardianLeaseToken", run.GuardianLeaseToken)
		chaser:SetAttribute("GuardianBehavior", "ALERTED")
		self:_setGuardianNoticeVisual(chaser, true)
		self:_setGuardianTemplateVisible(run.Stage, false)
		warn(string.format(
			"[%s] Recreated a missing active Stage %d guardian at its camp.",
			tostring(self.Config.Version or "ChestChase"),
			run.Stage
			))
	end

	local targetPosition = Vector3.new(rootPart.Position.X, core.Position.Y, rootPart.Position.Z)
	local chaseStartsAt = tonumber(run.ChaseStartsAt) or 0
	if os.clock() < chaseStartsAt then
		chaser:SetAttribute("GuardianBehavior", "ALERTED")
		self:_setGuardianNoticeVisual(chaser, true)
		local lookOffset = targetPosition - core.Position
		if lookOffset.Magnitude > 0.01 then
			pivotKeeper(chaser, CFrame.lookAt(core.Position, targetPosition))
		end
		return
	end
	chaser:SetAttribute("GuardianBehavior", "CHASING")
	self:_setGuardianNoticeVisual(chaser, false)
	local offset = targetPosition - core.Position
	local distance = offset.Magnitude
	self:_publishRunEffects(run, distance, deltaTime)
	local catchEnabledAt = tonumber(run.CatchEnabledAt) or 0
	if require(script.Parent.KeeperContact).Touching(chaser,character)
		and os.clock() >= catchEnabledAt then
		self:Finish(false, true)
		return
	end
	if distance > 0.01 then
		local guardianSettings = self:_getGuardianSettings(run.Stage)
		local targetSpeed = self.Config.GetGuardianChaseSpeed(guardianSettings, humanoid.WalkSpeed, distance,run.Stage)
		local currentChaserSpeed = self.Config.SmoothGuardianSpeed(
			run.LastGuardianTravelSpeed or targetSpeed, targetSpeed, deltaTime)
		run.LastGuardianTravelSpeed = currentChaserSpeed
		local stepDistance = math.min(currentChaserSpeed * deltaTime, distance)
		local newPosition = core.Position + offset.Unit * stepDistance
		local facingTarget = targetPosition
		if (facingTarget - newPosition).Magnitude <= 0.001 then
			facingTarget = newPosition + offset.Unit
		end
		pivotKeeper(chaser, CFrame.lookAt(newPosition, facingTarget))
	end
end

function ChaseService:Start()
	self:_captureGuardianBlueprints()
	self:_maintainGuardians()

	for _, chest in ipairs(self.Map.Chests) do
		chest.Prompt.Triggered:Connect(function(player)
			self:Begin(player, chest)
		end)
	end

	if self.Map.FallReturnPlane then
		self.FallConnection = self.Map.FallReturnPlane.Touched:Connect(function(hit)
			self:ReturnFallenCharacter(hit:FindFirstAncestorOfClass("Model"))
		end)
	else
		-- The obby fall plane is retired on the open-biome map. The heartbeat
		-- Y-threshold below still returns genuinely fallen characters.
		self.FallConnection = nil
	end

	local fallAccumulator = 0
	self.HeartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		self:_updateActiveRun(deltaTime)
		self:_updateDroppedGuardian(deltaTime)
		self:_updateReturningGuardians(deltaTime)
		self.GuardianMaintenanceAccumulator = self.GuardianMaintenanceAccumulator
			+ deltaTime
		if self.GuardianMaintenanceAccumulator >= 0.25 then
			self.GuardianMaintenanceAccumulator = 0
			self:_maintainGuardians()
		end
		fallAccumulator = fallAccumulator + deltaTime
		if fallAccumulator < 0.1 then
			return
		end
		fallAccumulator = 0
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if humanoid and rootPart and humanoid.Health > 0
				and rootPart.Position.Y <= self.Config.FallReturnY then
				self:ReturnFallenCharacter(character)
			end
		end
	end)
	print(string.format(
		"[%s] PASS - stable proximity audio, success flash, and guardian return loaded.",
		tostring(self.Config.Version or "ChestChase")
		))
end

function ChaseService:CleanupPlayer(player)
	player:SetAttribute("GuardianFlingActive", false)
	if self:IsPlayerBusy(player) then
		self:ReturnToIdle()
	end
end

-- V087_CONCURRENT_KEEPERS
ChaseService=require(script.Parent:WaitForChild("ConcurrentKeeperService"))(ChaseService)
-- R153 (architecture review): the owner / test commands no longer start from here (they used to, without a pcall, so an error in the most-edited test file stopped ChaseService:Start
-- and with it the whole server). ChestChaseServerMain starts them after the game is up, inside a pcall.
return ChaseService
	
