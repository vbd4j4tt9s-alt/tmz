-- Owns the server-validated BASE and TRACK teleport requests (R113: HUD buttons, shared checks).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FastTravelService = {}
FastTravelService.__index = FastTravelService

-- R113: the TRACK drop point sits this far past the base boundary line, on the Forest start.
FastTravelService.TrackEntryOffset = 12

local function getOrCreateRemote(folder, name)
	local remote = folder:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	return remote
end

function FastTravelService.new(config, mapService, baseService, chaseService, notifications)
	assert(type(config) == "table", "FastTravelService.new requires the Config table")
	local self = setmetatable({}, FastTravelService)
	self.Config = config
	self.Map = mapService
	self.Bases = baseService
	self.Chase = chaseService
	self.Notifications = notifications
	self.LastTravelTime = {}

	local remoteFolderName = type(config.RemoteFolderName) == "string"
		and config.RemoteFolderName
		or "ChestChaseRemotes"
	local requestBaseRemoteName = type(config.RequestBaseTeleportRemote) == "string"
		and config.RequestBaseTeleportRemote
		or "RequestBaseTeleport"

	local folder = ReplicatedStorage:FindFirstChild(remoteFolderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = remoteFolderName
		folder.Parent = ReplicatedStorage
	end
	self.RemoteFolder = folder
	self.RequestBase = getOrCreateRemote(folder, requestBaseRemoteName)
	self.RequestTrack = getOrCreateRemote(folder, "RequestTrackTeleport")
	return self
end

local WARN = Color3.fromRGB(255, 187, 91)

-- Returns nil when travel is allowed, otherwise the refusal text. Every rule is server state.
function FastTravelService:_refusal(player, destination)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return ""
	end
	-- Carrying a stolen pack (also covers the tutorial "run home" step, which only exists while carrying).
	if self.Chase:IsPlayerBusy(player) or player:GetAttribute("ChestChaseSeedCarrying")
		or player:GetAttribute("ChestChaseRunActive") or player:GetAttribute("ChestChaseQueued") then
		return "FAST TRAVEL IS DISABLED WHILE CARRYING A SEED"
	end
	if player:GetAttribute("GuardianRagdollActive") or player:GetAttribute("GuardianFlingActive")
		or humanoid.PlatformStand then
		return "WAIT UNTIL YOU CAN MOVE!"
	end
	if self.Bases.TrainingSessions and self.Bases.TrainingSessions[player] then
		return "STEP OFF THE TREADMILL FIRST!"
	end
	if root.Anchored then
		return "FINISH YOUR CURRENT ACTION FIRST"
	end
	local chests = self.Chase.Chests
	if chests and chests.IsOpening and chests:IsOpening(player) then
		return "FINISH OPENING YOUR PACK FIRST!"
	end
	if humanoid.SeatPart then
		return "GET UP FIRST!"
	end
	if destination == "Track" and self.Map.Refreshing then
		return "THE TRACK IS REFRESHING!"
	end
	local left = self.Config.FastTravelCooldown - (os.clock() - (self.LastTravelTime[player] or -math.huge))
	if left > 0 then
		return string.format("TELEPORT READY IN %ds", math.ceil(left))
	end
	return nil
end

-- Front of the track: centred on the boundary line, just on the track side, facing down the track (+Z).
function FastTravelService:GetTrackCFrame()
	local line = self.Map.BaseBoundaryLine
	local startZ = tonumber(self.Config.BiomeTrackStartZ) or line.Position.Z
	local z = math.max(line.Position.Z + line.Size.Z / 2, startZ) + FastTravelService.TrackEntryOffset
	local x = line.Position.X
	local groundY = line.Position.Y
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {self.Map.MapRoot}
	params.RespectCanCollide = true
	local hit = workspace:Raycast(Vector3.new(x, line.Position.Y + 8, z), Vector3.new(0, -40, 0), params)
	if hit then
		groundY = hit.Position.Y
	end
	local point = Vector3.new(x, groundY + 4, z)
	return CFrame.lookAt(point, point + Vector3.new(0, 0, 1))
end

function FastTravelService:_teleportLivingCharacter(player, targetCFrame)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not rootPart or humanoid.Health <= 0 then
		return false
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
	-- Longer grace than the 0.25 s default: in-flight client positions from before the jump must not
	-- be taken as the new baseline and then "corrected" back to.
	character:PivotTo(targetCFrame);require(script.Parent.MovementGuard).Reset(player, 0.6)
	return true
end

function FastTravelService:_travel(player, destination)
	local refusal = self:_refusal(player, destination)
	if refusal then
		if refusal ~= "" then
			self.Notifications:Show(player, refusal, WARN, 2)
		end
		return false
	end

	local target, record
	if destination == "Base" then
		record = self.Bases:GetPlayerBase(player)
		if not record then
			self.Notifications:Show(player, "YOU DO NOT HAVE AN ASSIGNED BASE", Color3.fromRGB(255, 125, 125), 2.5)
			return false
		end
		target = record.Spawn.CFrame * CFrame.new(0, 4, 0)
	else
		target = self:GetTrackCFrame()
	end

	if not self:_teleportLivingCharacter(player, target) then
		return false
	end
	local now = os.clock()
	self.LastTravelTime[player] = now
	-- Lets the HUD show the shared cooldown; the server clock above stays authoritative.
	player:SetAttribute("FastTravelCooldown", self.Config.FastTravelCooldown)
	player:SetAttribute("FastTravelReadyAt", workspace:GetServerTimeNow() + self.Config.FastTravelCooldown)
	if record then
		self.Notifications:Show(player, string.format("RETURNED TO BASE %d", record.Index), Color3.fromRGB(118, 255, 187), 2)
	end
	return true
end

function FastTravelService:_returnToBase(player)
	return self:_travel(player, "Base")
end

function FastTravelService:Start()
	self.RequestBase.OnServerEvent:Connect(function(player)
		if not require(script.Parent.SecurityGate).Allow(player, 'FastTravel') then return end
		self:_travel(player, "Base")
	end)
	self.RequestTrack.OnServerEvent:Connect(function(player)
		if not require(script.Parent.SecurityGate).Allow(player, 'FastTravel') then return end
		self:_travel(player, "Track")
	end)
end

function FastTravelService:CleanupPlayer(player)
	self.LastTravelTime[player] = nil
end

return FastTravelService
