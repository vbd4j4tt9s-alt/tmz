-- Owns random base assignment, owner indicators, spawning, and treadmill training.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Motion=require(ReplicatedStorage:WaitForChild("RunnerMotion"))

local BaseService = {}
BaseService.__index = BaseService

function BaseService.new(config, mapService, playerData, notifications)
	assert(type(config) == "table", "BaseService.new requires the Config table")
	local self = setmetatable({}, BaseService)
	self.Config = config
	self.Map = mapService
	self.PlayerData = playerData
	self.Notifications = notifications
	self.BaseOwners = {}
	self.PlayerBaseIndex = {}
	self.TrainingTime = {}
	self.TrainingGainRemainder = {}
	self.TrainingSessions = {}
	self.TrainingMustLeave = {}
	self.TrainingCooldown = {}
	self.Randomizer = Random.new()
	self.BusyChecker = function()
		return false
	end
	self.TrainingConnection = nil

	local remoteFolderName = type(config.RemoteFolderName) == "string"
		and config.RemoteFolderName
		or "ChestChaseRemotes"
	local speedGainRemoteName = type(config.SpeedGainPopupRemote) == "string"
		and config.SpeedGainPopupRemote
		or "SpeedGainPopup"
	if config.SpeedGainPopupRemote == nil then
		warn("[ChestChase] Config.SpeedGainPopupRemote was missing; using SpeedGainPopup.")
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

	local speedGainRemote = remoteFolder:FindFirstChild(speedGainRemoteName)
	if speedGainRemote and not speedGainRemote:IsA("RemoteEvent") then
		speedGainRemote:Destroy()
		speedGainRemote = nil
	end
	if not speedGainRemote then
		speedGainRemote = Instance.new("RemoteEvent")
		speedGainRemote.Name = speedGainRemoteName
		speedGainRemote.Parent = remoteFolder
	end
	self:SetupTreadmillRemotes(remoteFolder)
	self.SpeedGainRemote = speedGainRemote
	speedGainRemote:SetAttribute("PopupLifetime", config.TreadmillPopupLifetime)
	local stopRemote = remoteFolder:FindFirstChild(config.StopTreadmillRemote)
	if not stopRemote then
		stopRemote = Instance.new("RemoteEvent")
		stopRemote.Name = config.StopTreadmillRemote
		stopRemote.Parent = remoteFolder
	end
	assert(stopRemote:IsA("RemoteEvent"), "StopTreadmillTraining must be a RemoteEvent")
	-- This remote can ONLY stop the sender's session. Clients never submit gains.
	stopRemote.OnServerEvent:Connect(function(player)
        if not require(script.Parent.SecurityGate).Allow(player,'StopTreadmill')then return end
		self:StopTraining(player, true)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:StopTraining(player, false)
		self.TrainingMustLeave[player] = nil
		self.TrainingCooldown[player] = nil
		self.TrainingGainRemainder[player] = nil
    if self.ActiveTraining81 then self.ActiveTraining81[player]=nil end
        self.TreadmillRequests[player]=nil
	end)
	return self
end

function BaseService:SetBusyChecker(callback)
	self.BusyChecker = callback
end
-- R153 (owner: "make it so that players can also roll and open packs whilst on the treadmill"): the chase's IsPlayerBusy also counts a pack reveal (ChestService:IsOpening), so the
-- fifth click of a pack used to end the treadmill session on the spot. Training asks this checker instead: a chase (running or starting) still stops it, a reveal does not.
-- Everything else (the garden, the treadmill upgrade) keeps BusyChecker. Without a training checker it is BusyChecker.
function BaseService:SetTrainingBusyChecker(callback)
	self.TrainingBusyChecker = callback
end
function BaseService:_trainingBusy(player)
	return (self.TrainingBusyChecker or self.BusyChecker)(player)
end

function BaseService:ResetLootDisplay(record)
	-- Chest opening was removed in V0.66. These checks only clean up a place
	-- that has not run the permanent station-removal installer yet.
	if record.OpenLabel then
		record.OpenLabel.Text = ""
	end
	if record.LootDisplay then
		record.LootDisplay.Transparency = 1
		record.LootDisplay.CanCollide = false
	end
	if record.LootLight then
		record.LootLight.Enabled = false
		record.LootLight.Brightness = 0
	end
	if record.OpenPrompt then
		record.OpenPrompt.Enabled = false
	end
end

function BaseService:_updateOwnerDisplay(record, ownerDisplayName, ownerUserId)
	local shortText
	local signText
	if ownerDisplayName then
		local cleanName = string.upper(ownerDisplayName)
		shortText = cleanName .. "'S BASE"
		signText = string.format("BASE %d\n%s", record.Index, cleanName)
	else
		shortText = string.format("EMPTY BASE %d", record.Index)
		signText = string.format("BASE %d\nEMPTY", record.Index)
	end

	record.Model:SetAttribute("BaseOwnerUserId", ownerUserId or 0)
    require(script.Parent.GardenFenceArt).UpdateOwner(record.Model,ownerDisplayName or "")
	record.Label.Text = shortText
    record.Label.Visible=false
	for _, label in ipairs(record.OwnerSignLabels) do
		if label.Parent then
			label.Text = signText
            label.Visible=false
		end
	end

end

function BaseService:AssignPlayer(player)
	local currentIndex = self.PlayerBaseIndex[player]
	if currentIndex and self.BaseOwners[currentIndex] == player then
		return self.Map.BaseRecordsByIndex[currentIndex]
	end

	local available = {}
	for _, record in ipairs(self.Map.BaseRecords) do
		if not self.BaseOwners[record.Index] then
			table.insert(available, record)
		end
	end

	if #available == 0 then
		player.RespawnLocation = self.Map.FallbackSpawn
		warn(string.format("[%s] No empty base was available for %s", self.Config.Version, player.Name))
		return nil
	end

	local record = available[self.Randomizer:NextInteger(1, #available)]
	self.BaseOwners[record.Index] = player
	self.PlayerBaseIndex[player] = record.Index
	player.RespawnLocation = record.Spawn
	self:_updateOwnerDisplay(record, player.DisplayName, player.UserId)
	self:ResetLootDisplay(record)
    self:RefreshTreadmill(player)
	return record
end

function BaseService:ReleasePlayer(player)
	self:StopTraining(player, false)
	local index = self.PlayerBaseIndex[player]
	if index and self.BaseOwners[index] == player then
		self.BaseOwners[index] = nil
		local record = self.Map.BaseRecordsByIndex[index]
		if record then
			self:_updateOwnerDisplay(record, nil, nil)
    local _,prompt=require(script.Parent.BiomeVisuals).BuildTreadmillV131(record.Model,1)
    prompt.Enabled=false
    require(script.Parent.GardenUpgradeService).Clear(self,record)
    require(script.Parent.GardenFenceArt).Build(record.Model,1)
			self:ResetLootDisplay(record)
		end
	end
	self.PlayerBaseIndex[player] = nil
	self.TrainingTime[player] = nil
	self.TrainingGainRemainder[player] = nil
    if self.ActiveTraining81 then self.ActiveTraining81[player]=nil end
	self.TrainingMustLeave[player] = nil
	self.TrainingCooldown[player] = nil
end

function BaseService:GetPlayerBase(player)
	local index = self.PlayerBaseIndex[player]
	if not index or self.BaseOwners[index] ~= player then
		return nil
	end
	return self.Map.BaseRecordsByIndex[index]
end

function BaseService:IsOwner(player, record)
	return record
		and self.PlayerBaseIndex[player] == record.Index
		and self.BaseOwners[record.Index] == player
end

function BaseService:GetOwner(record)
	return record and self.BaseOwners[record.Index] or nil
end

-- Model scaling supports both R6 and R15 without replacing the player's outfit.
-- Roblox may call setup both before and after profile load; never multiply twice.
function BaseService:ApplyCharacterScale(player, character, appearanceReady)
    if player.Character ~= character or not character.Parent then return false end
    if character:GetAttribute("ChestChaseAvatarScale") ~= nil then return true end
    if not appearanceReady and player.CanLoadCharacterAppearance
        and not player:HasAppearanceLoaded() then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 then return false end
    local multiplier = self.Config.PlayerScaleMultiplier or 1
    assert(type(multiplier) == "number" and multiplier > 0 and multiplier < math.huge,
        "PlayerScaleMultiplier must be a positive finite number")
    local function standingHeight()
        local leg = humanoid.RigType == Enum.HumanoidRigType.R6 and character:FindFirstChild("Left Leg")
        return root.Size.Y / 2 + humanoid.HipHeight + (leg and leg.Size.Y or 0)
    end
    local beforeHeight = standingHeight()
    local walk, jumpPower, jumpHeight = humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight
    local ok, message = pcall(function() character:ScaleTo(character:GetScale() * multiplier) end)
    -- ScaleTo also adjusts physical movement properties. Size must not award speed.
    humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = walk, jumpPower, jumpHeight
    if not ok then warn("[V115] Avatar scaling failed: " .. tostring(message)); return false end
    -- The root pivot stays fixed while legs grow: lift by the added standing height.
    character:PivotTo(character:GetPivot() + Vector3.new(0, standingHeight() - beforeHeight, 0))
    character:SetAttribute("ChestChaseAvatarScale", multiplier)
    return true
end

function BaseService:ApplyCharacter(player, character)
	self:StopTraining(player, false)
	local humanoid = character:WaitForChild("Humanoid", 5)
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
	if not humanoid or not humanoidRootPart or player.Character ~= character then
		return
	end

	self:ApplyCharacterScale(player, character, false)

	local speedValue = self.PlayerData:GetOrCreateSpeedValue(player)
	self:_applyPhysicalSpeed(player,humanoid,speedValue.Value)
	local record = self:GetPlayerBase(player)
	if record then
		character:PivotTo(record.Spawn.CFrame * CFrame.new(0, 4, 0));require(script.Parent.MovementGuard).Reset(player)
	end
	self.TrainingTime[player] = 0
	self.TrainingGainRemainder[player] = 0
	self.TrainingMustLeave[player] = nil
	self.TrainingCooldown[player] = nil
end

function BaseService:_isStandingOnTreadmill(worldPosition, treadmill)
	local localPosition = treadmill.CFrame:PointToObjectSpace(worldPosition)
	return math.abs(localPosition.X) <= treadmill.Size.X / 2
		and math.abs(localPosition.Z) <= treadmill.Size.Z / 2
		and localPosition.Y >= 0
		and localPosition.Y <= 12
end

function BaseService:_stabilizeHorizontalVelocity(player, rootPart, humanoid)
	if rootPart.Anchored or humanoid.PlatformStand or humanoid.Sit or player:GetAttribute("GuardianRagdollActive") or player:GetAttribute("GuardianFlingActive") or ((RunService:IsStudio() or require(script.Parent.OwnerTestState82).MovementGranted(player) or require(script.Parent.OwnerCommandAccess).IsAllowed(player)) and player:GetAttribute("StudioTestFlying")) then
		return
	end

	local velocity = rootPart.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local earned=self.Config.GetPlayerWalkSpeed(player,self.PlayerData:GetOrCreateSpeedValue(player).Value)
    local ceiling=Motion.AtPosition(earned,rootPart.Position)
    if humanoid.WalkSpeed~=ceiling then humanoid.WalkSpeed=ceiling end
    local rounded=math.floor(earned*100+.5)/100
    if player:GetAttribute('PhysicalWalkSpeed')~=rounded then player:SetAttribute('PhysicalWalkSpeed',rounded)end
    local maxHorizontalSpeed=ceiling*self.Config.MaxHorizontalVelocityMultiplier

	if horizontal.Magnitude > maxHorizontalSpeed then
		local clamped = horizontal.Unit * maxHorizontalSpeed
		rootPart.AssemblyLinearVelocity = Vector3.new(clamped.X, velocity.Y, clamped.Z)
	end
end

function BaseService:_applyPhysicalSpeed(player, humanoid, speedStat)
	local physicalSpeed = self.Config.GetPlayerWalkSpeed(player,speedStat)
    local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
	humanoid.WalkSpeed = Motion.AtPosition(physicalSpeed,root and root.Position)
	player:SetAttribute(
		"PhysicalWalkSpeed",
		math.floor(physicalSpeed * 100 + 0.5) / 100
	)
end

function BaseService:_getTreadmillAnimationSpeed(_multiplier)
 return self.Config.TreadmillAnimationSpeed
end

function BaseService:StopTraining(player, jumpOff)
	local session = self.TrainingSessions[player]
	if not session then
		return
	end
	-- Remove ownership first, so death/exit callbacks cannot stop a newer session.
	self.TrainingSessions[player] = nil
	self.TrainingTime[player] = nil
	self.TrainingMustLeave[player] = true
	self.TrainingCooldown[player] = os.clock() + self.Config.TreadmillReentryCooldown
	player:SetAttribute("TreadmillTraining", false)
	player:SetAttribute("TreadmillAnimationRate", nil)
	player:SetAttribute("TreadmillGainPerSecond", nil)
	if session.Treadmill.Parent then
		session.Treadmill:SetAttribute("TrainingActive", false)
	end
	for _, connection in ipairs(session.Connections) do
		connection:Disconnect()
	end
	if session.Track then
		session.Track:Stop(0.15)
		local track = session.Track
		task.delay(0.2, function() track:Destroy() end)
	end
	local root = session.Root
	local humanoid = session.Humanoid
	if root.Parent then
		root.Anchored = session.WasAnchored
	end
	if humanoid.Parent then
		humanoid.AutoRotate = session.AutoRotate
	end
	if player.Character == session.Character and humanoid.Parent
		and humanoid.Health > 0 and not self:_trainingBusy(player) then
		self:_applyPhysicalSpeed(player, humanoid,
			self.PlayerData:GetOrCreateSpeedValue(player).Value)
		if jumpOff and root.Parent then
			humanoid.Jump = true
		end
	end
end

function BaseService:_startTraining(player, record, character, humanoid, root)
	if self.Config.TreadmillsEnabled == false or self.TrainingSessions[player] or root.Anchored then
		return
	end
	local belt = record.Treadmill
	-- R6 includes leg height; R15 encodes it in HipHeight.
	local height = root.Size.Y / 2 + humanoid.HipHeight
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		local leg = character:FindFirstChild("Left Leg")
		height = height + (leg and leg.Size.Y or 2)
	end
	local target = belt.CFrame * CFrame.new(0, belt.Size.Y / 2 + height + 0.05, 0)
		* CFrame.Angles(0, math.rad(tonumber(belt:GetAttribute("TrainingFacingDegrees")) or 0), 0)
	local session = {
		Character = character, Humanoid = humanoid, Root = root,
		Treadmill = belt, Record = record, Target = target,
		BeltCFrame = belt.CFrame, WasAnchored = root.Anchored,
		AutoRotate = humanoid.AutoRotate, Connections = {},
		AnimationSpeed = self:_getTreadmillAnimationSpeed(
			self:GetTreadmillMultiplier(player)
		),
	}
	self.TrainingSessions[player] = session
	self.TrainingTime[player] = 0
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = target
	root.Anchored = true
	humanoid.AutoRotate = false
	humanoid.Jump = false
	belt:SetAttribute("TrainingActive", true)
	-- The owner plays the cached track; this Animator must originate on the server.
	if not humanoid:FindFirstChildOfClass('Animator')then local animator=Instance.new('Animator');animator.Parent=humanoid end
	player:SetAttribute('TreadmillAnimationRate',session.AnimationSpeed)
	player:SetAttribute("TreadmillTraining", true)

	table.insert(session.Connections, humanoid.Died:Connect(function()
		if self.TrainingSessions[player] == session then
			self:StopTraining(player, false)
		end
	end))
	table.insert(session.Connections, character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(workspace)
			and self.TrainingSessions[player] == session then
			self:StopTraining(player, false)
		end
	end))


end

function BaseService:_canEnterTreadmill(character, humanoid, root, belt)
	if self.Config.TreadmillsEnabled == false or not belt or not belt.Parent or root.Anchored
		or humanoid.Sit or humanoid.PlatformStand or humanoid.Jump then
		return false
	end
	-- Require actual ground underneath, not a volume that can award while airborne.
	if not self:_isStandingOnTreadmill(root.Position, belt) then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	return hit ~= nil and hit.Instance == belt
		and humanoid.FloorMaterial ~= Enum.Material.Air
end

function BaseService:_collectTreadmillGain(player, elapsed, multiplier)
	local time = (self.TrainingTime[player] or 0) + elapsed
	local ticks = math.floor((time + 0.0000001) / self.Config.TrainingInterval)
	self.TrainingTime[player] = math.max(0, time - ticks * self.Config.TrainingInterval)
	if ticks == 0 then
		return 0, 0
	end
	local gain, remainder = self.Config.GetTrainingAward(
		self.TrainingGainRemainder[player] or 0, multiplier, ticks)
	self.TrainingGainRemainder[player] = remainder
	return gain, ticks
end

function BaseService:_updateTrainingPlayer(player, deltaTime)
    if self.Config.TreadmillsEnabled == false then
        if self.TrainingSessions[player] then self:StopTraining(player, false) end
        return
    end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local record = self:GetPlayerBase(player)
	local belt = record and record.Treadmill
	local canTrain = humanoid and root and humanoid.Health > 0
		and self.PlayerData:IsLoaded(player) and not self:_trainingBusy(player)
        and not (player:GetAttribute("StudioTestFlying") or player:GetAttribute("StudioTestNoclip"))
		and not player:GetAttribute("GuardianFlingActive")
		and not player:GetAttribute("GuardianRagdollActive")

	local session = self.TrainingSessions[player]
	if session then
		-- In particular: external teleports RELEASE the lock, never snap back.
		local valid = canTrain and session.Character == character
			and record == session.Record and belt and belt.Parent
			and session.Root == root and root.Anchored and not humanoid.Sit
			and not humanoid.PlatformStand
			and (root.Position - session.Target.Position).Magnitude < 1.5
			and belt.CFrame == session.BeltCFrame
		if not valid or humanoid.Jump then
			self:StopTraining(player, false)
			return
		end
	else
		if not canTrain or not belt or not belt.Parent then
			return
		end
		if self.TrainingMustLeave[player] then
			local localPosition = belt.CFrame:PointToObjectSpace(root.Position)
			if math.abs(localPosition.X) > belt.Size.X / 2 + 0.5
				or math.abs(localPosition.Z) > belt.Size.Z / 2 + 0.5 then
				self.TrainingMustLeave[player] = nil
			end
			return
		end
		if os.clock() < (self.TrainingCooldown[player] or 0)
			or not self:_canEnterTreadmill(character, humanoid, root, belt) then
			return
		end
		self:_startTraining(player, record, character, humanoid, root)
		return -- Start at zero elapsed; never credit the frame before entry.
	end

	local multiplier = self:GetTreadmillMultiplier(player)
	if multiplier ~= multiplier or multiplier == math.huge then multiplier = 1 end
	multiplier = math.max(1, multiplier)
	-- R148: friends in the server speed up the speed GAINED here (not the walk speed, and not the treadmill animation).
	local gainMultiplier = multiplier * self:GetFriendGainMultiplier(player)
	local gainRate = self.Config.TrainingPointsPerSecond * gainMultiplier
	if player:GetAttribute("TreadmillGainPerSecond") ~= gainRate then player:SetAttribute("TreadmillGainPerSecond", gainRate) end
	local animationSpeed = self:_getTreadmillAnimationSpeed(multiplier)
	local previousAnimationSpeed = session.AnimationSpeed or animationSpeed
	if session.Track and math.abs(animationSpeed - previousAnimationSpeed) > 0.001 then
		session.Track:AdjustSpeed(animationSpeed)
	end
	if math.abs(animationSpeed-previousAnimationSpeed)>.001 then player:SetAttribute('TreadmillAnimationRate',animationSpeed)end
	session.AnimationSpeed = animationSpeed
    if not session.TutorialTrained then
        session.TutorialSeconds=(session.TutorialSeconds or 0)+math.max(0,deltaTime)
        if session.TutorialSeconds>=3 then session.TutorialTrained=true;self.PlayerData:TutorialEvent(player,'Train')end
    end
	local speed = self.PlayerData:GetOrCreateSpeedValue(player)
	local gain, ticks = self:_collectTreadmillGain(player, deltaTime, gainMultiplier)
	if gain <= 0 then return end
	local actualGain = self.PlayerData:AddSpeed(player,gain)
	self:_applyPhysicalSpeed(player, humanoid, speed.Value)
	self.PlayerData:MarkDirty(player)
	self.SpeedGainRemote:FireAllClients(player, actualGain, speed.Value,
		ticks, self.Config.TrainingInterval, character)
end

function BaseService:StartTraining()
	if self.TrainingConnection then return end
	for _, record in ipairs(self.Map.BaseRecords) do
		local belt = record.Treadmill
		if belt and self.Config.TreadmillsEnabled ~= false then
			belt:SetAttribute("TreadmillTrainingBelt", true)
			belt:SetAttribute("TrainingActive", false)
			for _, descendant in ipairs(belt:GetDescendants()) do
				if descendant:IsA("TextLabel") then
					descendant.Text = ""
				end
			end
		end
	end
	-- Keep the existing high-speed movement stabilizer when training is paused.
	self.TrainingConnection = RunService.Heartbeat:Connect(function(deltaTime)
		for _, player in ipairs(Players:GetPlayers()) do
			self:_updateTrainingPlayer(player, deltaTime)
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if humanoid and root and humanoid.Health > 0
				and not self.TrainingSessions[player] then
				self:_stabilizeHorizontalVelocity(player, root, humanoid)
			end
		end
	end)
	print(self.Config.TreadmillsEnabled == false and "[V114] Training paused; movement stabilization active."
        or "[V0.50] Treadmill training loaded.")
end

-- R148 (owner: "the speed boost should only apply to the speed gain, not how fast the player goes"): the friend boost
-- (SocialService sets FriendSpeedBoost; DailyRewards has the numbers: +10% per friend, 3 friends at most) multiplies the
-- speed points earned from treadmill training, 1 .. DailyRewards.MaxMultiplier() whatever the attribute says. Bought
-- speed, gifts, owner commands and treadmill bonus rolls never go through here.
function BaseService:GetFriendGainMultiplier(player)
    local boost=player and player:GetAttribute('FriendSpeedBoost')
    return type(boost)=='number'and boost==boost
        and math.clamp(boost,1,require(ReplicatedStorage.DailyRewards).MaxMultiplier())or 1
end

function BaseService:GetTreadmillMultiplier(player)
    local tier=self.PlayerData:GetTreadmillData(player).Tier
    local boost=tonumber(player:GetAttribute('TreadmillMultiplier'))or 1
    if boost~=boost or boost==math.huge or boost==-math.huge then boost=1 end
    -- R121: the timed x2 boost multiplies with machine, trail and the permanent x2 Speed pass.
    local timed=self.PlayerData.SpeedBoostFactor and self.PlayerData:SpeedBoostFactor(player)or 1
    return require(game:GetService('ReplicatedStorage').BalanceRules).Training(self.Config.TreadmillTiers[tier].Multiplier,boost,player:GetAttribute('DoubleSpeedOwned')==true)*timed
end
function BaseService:TreadmillSnapshot(player,message)
    local data=self.PlayerData:GetTreadmillData(player);local tiers={}
    for i,t in ipairs(self.Config.TreadmillTiers)do
        tiers[i]={Name=t.Name,Biome=t.Biome,Cost=t.Cost,Multiplier=t.Multiplier,
            Unlocked=true,Owned=i<=data.Tier}
    end
    return {Tier=data.Tier,Skin=data.Skin,Tiers=tiers,Cash=self.PlayerData:GetCash(player),
        Rate=self.Config.TrainingPointsPerSecond*self:GetTreadmillMultiplier(player)*self:GetFriendGainMultiplier(player),Message=message} -- R148: the friend boost is part of the gain
end
function BaseService:CanManageTreadmill(player)
    local record=self:GetPlayerBase(player)
    local character=player.Character
    local root=character and character:FindFirstChild('HumanoidRootPart')
    local humanoid=character and character:FindFirstChildOfClass('Humanoid')
    if not record or self.BaseOwners[record.Index]~=player or not record.Treadmill or not root
        or not humanoid or humanoid.Health<=0 or not self.PlayerData:IsLoaded(player)
        or self.BusyChecker(player)or player:GetAttribute('GuardianRagdollActive')
        or (root.Position-record.Treadmill.Position).Magnitude>14 then return false end
    return true
end
function BaseService:RefreshTreadmill(player)
    local record=self:GetPlayerBase(player);if not record then return end
    self:StopTraining(player,false)
    local Art=require(script.Parent.BiomeVisuals)
    local data=self.PlayerData:GetTreadmillData(player)
    local belt,prompt=Art.BuildTreadmillV131(record.Model,data.Skin,data.Tier) -- R151: the level sets the dressing grade and the "+N/step" label
    record.Treadmill=belt;prompt:SetAttribute('OwnerUserId',player.UserId)
    prompt.Enabled=false
    require(script.Parent.GardenUpgradeService).Refresh(self,player)
end
function BaseService:SetupTreadmillRemotes(folder)
    local function remote(name,class)
        local r=folder:FindFirstChild(name)
        assert(not r or r:IsA(class),'Unexpected treadmill remote: '..name)
        if not r then r=Instance.new(class);r.Name=name;r.Parent=folder end
        return r
    end
    self.TreadmillRequests={}
    self.TreadmillOpenRemote=remote('OpenTreadmillMenu','RemoteEvent')
    local request=remote('ManageTreadmill','RemoteFunction')
    request.OnServerInvoke=function(player,action,expected)
        if not require(script.Parent.SecurityGate).Allow(player,'ManageTreadmill',action,expected)or not require(script.Parent.MovementGuard).Check(player)then return {Error='Please try again.'}end
        if not self:CanManageTreadmill(player)then return {Error='Go to your own treadmill!'}end
        local now=os.clock()
        if now-(self.TreadmillRequests[player]or -math.huge)<.25 then return {Error='Wait a sec!'}end
        self.TreadmillRequests[player]=now
        if action=='Info'then return self:TreadmillSnapshot(player)end
        local ok,message
        if action=='Upgrade'then ok,message=self.PlayerData:BuyTreadmill(player,expected)
        else return {Error='Try again!'}end
        if ok then
            local rendered,why=pcall(function()self:RefreshTreadmill(player)end)
            if not rendered then warn('[V131] Treadmill appearance needs retry: '..tostring(why))end
        end
        return self:TreadmillSnapshot(player,message)
    end
end

return BaseService
