local LootToolService = {}
LootToolService.__index = LootToolService

local function disconnectAll(connections)
	for _, connection in ipairs(connections or {}) do
		connection:Disconnect()
	end
end

local function styleHandleForItem(handle, itemName)
	local lowerName = string.lower(itemName)
	if string.find(lowerName, "key", 1, true) or string.find(lowerName, "blade", 1, true) then
		handle.Shape = Enum.PartType.Block
		handle.Size = Vector3.new(0.3, 1.65, 0.38)
	elseif string.find(lowerName, "map", 1, true) then
		handle.Shape = Enum.PartType.Block
		handle.Size = Vector3.new(1.35, 0.18, 0.9)
	elseif string.find(lowerName, "compass", 1, true)
		or string.find(lowerName, "crown", 1, true) then
		handle.Shape = Enum.PartType.Cylinder
		handle.Size = Vector3.new(0.34, 1.25, 1.25)
	elseif string.find(lowerName, "boots", 1, true)
		or string.find(lowerName, "pouch", 1, true)
		or string.find(lowerName, "idol", 1, true)
		or string.find(lowerName, "relic", 1, true)
		or string.find(lowerName, "treasure", 1, true) then
		handle.Shape = Enum.PartType.Block
		handle.Size = Vector3.new(0.9, 1.15, 0.75)
	else
		handle.Shape = Enum.PartType.Ball
		handle.Size = Vector3.new(1.05, 1.05, 1.05)
	end
end

function LootToolService.new(config, playerData)
	local self = setmetatable({}, LootToolService)
	self.Config = config
	self.PlayerData = playerData
	self.PlayerConnections = {}
	self.SyncQueued = {}
	return self
end

function LootToolService:_getContainers(player)
	local containers = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		table.insert(containers, backpack)
	end
	if player.Character then
		table.insert(containers, player.Character)
	end
	return containers, backpack
end

function LootToolService:_makeTool(lootValue, backpack)
	if not backpack then
		return nil
	end

	local rarity = lootValue:GetAttribute("Rarity") or "Common"
	local income = self.Config.CashPerSecondByRarity[rarity]
		or self.Config.CashPerSecondByRarity.Common
	local rarityColor = self.Config.RarityColors[rarity]
		or self.Config.RarityColors.Common

	local tool = Instance.new("Tool")
	tool.Name = lootValue.Value
	tool.ToolTip = string.format("%s  •  SELL $%d", rarity, self.Config.SellValueByRarity[rarity] or self.Config.SellValueByRarity.Common)
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true
	tool.GripPos = Vector3.new(0, -0.25, 0)
	tool:SetAttribute("LootItemTool", true)
	tool:SetAttribute("LootInstanceName", lootValue.Name)
	tool:SetAttribute("LootName", lootValue.Value)
	tool:SetAttribute("Rarity", rarity)
	tool:SetAttribute("ChestStage", lootValue:GetAttribute("ChestStage") or 1)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	styleHandleForItem(handle, lootValue.Value)
	handle.Color = rarityColor
	handle.Material = Enum.Material.Neon
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.CastShadow = false
	handle.Parent = tool

	local light = Instance.new("PointLight")
	light.Name = "LootGlow"
	light.Color = rarityColor
	light.Brightness = 1.35
	light.Range = 8
	light.Parent = handle

	tool.Parent = backpack
	return tool
end

function LootToolService:SyncTools(player)
	if not player.Parent or not self.PlayerData:IsLoaded(player) then
		return
	end

	local recordsById = {}
	local orderedRecords = {}
	for _, lootValue in ipairs(self.PlayerData:GetOrCreateLootInventory(player):GetChildren()) do
		if lootValue:IsA("StringValue") then
			recordsById[lootValue.Name] = lootValue
			table.insert(orderedRecords, lootValue)
		end
	end
	table.sort(orderedRecords, function(left, right)
		return left.Name < right.Name
	end)

	local containers, backpack = self:_getContainers(player)
	local foundIds = {}
	for _, container in ipairs(containers) do
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("LootItemTool") then
				local lootId = child:GetAttribute("LootInstanceName")
				if not lootId or not recordsById[lootId] or foundIds[lootId] then
					child:Destroy()
				else
					foundIds[lootId] = true
				end
			end
		end
	end

	for _, lootValue in ipairs(orderedRecords) do
		if not foundIds[lootValue.Name] then
			self:_makeTool(lootValue, backpack)
		end
	end
end

function LootToolService:_queueSync(player)
	if self.SyncQueued[player] then
		return
	end
	self.SyncQueued[player] = true
	task.defer(function()
		self.SyncQueued[player] = nil
		self:SyncTools(player)
	end)
end

function LootToolService:SetupPlayer(player)
	disconnectAll(self.PlayerConnections[player])
	local inventory = self.PlayerData:GetOrCreateLootInventory(player)
	self.PlayerConnections[player] = {
		inventory.ChildAdded:Connect(function()
			self:_queueSync(player)
		end),
		inventory.ChildRemoved:Connect(function()
			self:_queueSync(player)
		end),
	}
	self:SyncTools(player)
end

function LootToolService:OnCharacterAdded(player)
	task.delay(0.35, function()
		if player.Parent then
			self:SyncTools(player)
		end
	end)
end

function LootToolService:CleanupPlayer(player)
	disconnectAll(self.PlayerConnections[player])
	self.PlayerConnections[player] = nil
	self.SyncQueued[player] = nil
end

return LootToolService
