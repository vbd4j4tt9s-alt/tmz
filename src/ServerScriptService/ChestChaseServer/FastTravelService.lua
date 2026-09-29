-- Owns the server-validated BASE [V] teleport request.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FastTravelService = {}
FastTravelService.__index = FastTravelService

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
	return self
end

function FastTravelService:_canTravel(player)
    if player:GetAttribute('GuardianRagdollActive') or player:GetAttribute('GuardianFlingActive')then return false end
	if self.Chase:IsPlayerBusy(player) then
		self.Notifications:Show(
			player,
			"FAST TRAVEL IS DISABLED WHILE CARRYING A SEED",
			Color3.fromRGB(255, 187, 91),
			2.5
		)
		return false
	end

	local now = os.clock()
	if now - (self.LastTravelTime[player] or -math.huge) < self.Config.FastTravelCooldown then
		return false
	end
	return true, now
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
	character:PivotTo(targetCFrame);require(script.Parent.MovementGuard).Reset(player)
	return true
end

function FastTravelService:_returnToBase(player)
	local allowed, now = self:_canTravel(player)
	if not allowed then
		return
	end

	local record = self.Bases:GetPlayerBase(player)
	if not record then
		self.Notifications:Show(player, "YOU DO NOT HAVE AN ASSIGNED BASE", Color3.fromRGB(255, 125, 125), 2.5)
		return
	end

	if self:_teleportLivingCharacter(player, record.Spawn.CFrame * CFrame.new(0, 4, 0)) then
		self.LastTravelTime[player] = now
		self.Notifications:Show(
			player,
			string.format("RETURNED TO BASE %d", record.Index),
			Color3.fromRGB(118, 255, 187),
			2
		)
	end
end

function FastTravelService:Start()
	self.RequestBase.OnServerEvent:Connect(function(player)
        if not require(script.Parent.SecurityGate).Allow(player,'RequestBase')then return end
		self:_returnToBase(player)
	end)
end

function FastTravelService:CleanupPlayer(player)
	self.LastTravelTime[player] = nil
end

return FastTravelService
