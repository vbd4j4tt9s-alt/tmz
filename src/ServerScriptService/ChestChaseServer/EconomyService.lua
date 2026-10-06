local Gate=require(script.Parent.SecurityGate)
local Movement=require(script.Parent.MovementGuard)
-- V0.73 seed inventory response; legacy keepsakes retained for migration.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyService = {}
EconomyService.__index = EconomyService

local CATEGORY_ORDER = {"Trails", "Accessories"}

local function getOrCreateRemote(folder, name, className)
	local remote = folder:FindFirstChild(name)
	if remote and not remote:IsA(className) then
		remote:Destroy()
		remote = nil
	end
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
	end
	return remote
end

local function colorToTable(color)
	return {
		R = math.floor(color.R * 255 + 0.5),
		G = math.floor(color.G * 255 + 0.5),
		B = math.floor(color.B * 255 + 0.5),
	}
end

local function styleTreasureShape(part, itemName)
	local lowerName = string.lower(itemName)
	if string.find(lowerName, "key", 1, true)
		or string.find(lowerName, "blade", 1, true) then
		part.Shape = Enum.PartType.Block
		part.Size = Vector3.new(0.55, 3.2, 0.7)
	elseif string.find(lowerName, "map", 1, true) then
		part.Shape = Enum.PartType.Block
		part.Size = Vector3.new(3, 0.35, 2)
	elseif string.find(lowerName, "compass", 1, true)
		or string.find(lowerName, "crown", 1, true) then
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.65, 2.5, 2.5)
	elseif string.find(lowerName, "boots", 1, true)
		or string.find(lowerName, "pouch", 1, true)
		or string.find(lowerName, "idol", 1, true)
		or string.find(lowerName, "relic", 1, true)
		or string.find(lowerName, "treasure", 1, true) then
		part.Shape = Enum.PartType.Block
		part.Size = Vector3.new(2.1, 2.5, 1.8)
	else
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(2.3, 2.3, 2.3)
	end
end

function EconomyService.new(config, mapService, playerData, baseService, chestService, chaseService, notifications)
	assert(type(config) == "table", "EconomyService.new requires the Config table")
	local self = setmetatable({}, EconomyService)
	self.Config = config
	self.Map = mapService
	self.PlayerData = playerData
	self.Bases = baseService
	self.Chests = chestService
	self.Chase = chaseService
	self.Notifications = notifications
	self.ProductById = {}
	self.Running = false
	self.LastStationTravel = {}
    self.LastEquip = {}
	self.ShowcaseConnections = {}

	for _, category in ipairs(CATEGORY_ORDER) do
		for _, product in ipairs(config.ShopCatalog[category]) do
			self.ProductById[product.Id] = product
		end
	end

	local remoteFolderName = type(config.RemoteFolderName) == "string"
		and config.RemoteFolderName
		or "ChestChaseRemotes"
	local remoteNames = {
		GetShopState = config.GetShopStateFunction or "GetShopState",
		PurchaseShopItem = config.PurchaseShopItemFunction or "PurchaseShopItem",
		SellLootItem = config.SellLootItemFunction or "SellLootItem",
		ManagePedestalItem = config.ManagePedestalItemFunction or "ManagePedestalItem",
		RequestStationTeleport = config.RequestStationTeleportRemote or "RequestStationTeleport",
		OpenEconomyUI = config.OpenEconomyUIRemote or "OpenEconomyUI",
	}

	local remoteFolder = ReplicatedStorage:FindFirstChild(remoteFolderName)
	if not remoteFolder then
		remoteFolder = Instance.new("Folder")
		remoteFolder.Name = remoteFolderName
		remoteFolder.Parent = ReplicatedStorage
	end
	remoteFolder:SetAttribute("StationInteractionDistance",config.EconomyInteractionDistance)
	remoteFolder:SetAttribute("BuyStationPosition",mapService.BuyStation.Position)
	remoteFolder:SetAttribute("SellStationPosition",mapService.SellStation.Position)
	self.GetShopState = getOrCreateRemote(remoteFolder, remoteNames.GetShopState, "RemoteFunction")
	self.PurchaseShopItem = getOrCreateRemote(remoteFolder, remoteNames.PurchaseShopItem, "RemoteFunction")
	self.EquipShopItem = getOrCreateRemote(remoteFolder, "EquipShopItem", "RemoteFunction")
	self.SellLootItem = getOrCreateRemote(remoteFolder, remoteNames.SellLootItem, "RemoteFunction")
	self.ManagePedestalItem = getOrCreateRemote(
		remoteFolder,
		remoteNames.ManagePedestalItem,
		"RemoteFunction"
	)
	self.RequestStationTeleport = getOrCreateRemote(
		remoteFolder,
		remoteNames.RequestStationTeleport,
		"RemoteEvent"
	)
	self.OpenEconomyUI = getOrCreateRemote(remoteFolder, remoteNames.OpenEconomyUI, "RemoteEvent")
	return self
end

function EconomyService:_isNear(player, part)
	local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return part
		and rootPart
		and (rootPart.Position - part.Position).Magnitude <= self.Config.EconomyInteractionDistance
end

function EconomyService:_buildLootList(player)
	local loot = {}
	for _, child in ipairs(self.PlayerData:GetOrCreateLootInventory(player):GetChildren()) do
		if child:IsA("StringValue") then
			local rarity = child:GetAttribute("Rarity") or "Common"
			table.insert(loot, {
				InstanceName = child.Name,
				Name = child.Value,
				Rarity = rarity,
				Stage = child:GetAttribute("ChestStage") or 1,
				SellValue = self.Config.SellValueByRarity[rarity]
					or self.Config.SellValueByRarity.Common,
				Color = colorToTable(self.Config.RarityColors[rarity]
					or self.Config.RarityColors.Common),
			})
		end
	end
	table.sort(loot, function(left, right)
		local leftRank = self.Config.RarityOrder[left.Rarity] or 1
		local rightRank = self.Config.RarityOrder[right.Rarity] or 1
		return leftRank == rightRank and left.Name < right.Name or leftRank > rightRank
	end)
	return loot
end

function EconomyService:_purchaseBlockReason(product)
    if product.Enabled == false then return "COMING SOON" end
    if self.Config.TreadmillsEnabled == false and product.SpeedMultiplier then return "TRAINING PAUSED" end
    return nil
end

function EconomyService:_bootBiome(player)
 local tier=tonumber(player:GetAttribute('TreadmillTier'))or 1
 if tier~=tier or math.abs(tier)==math.huge then tier=1 end
 local spec=self.Config.TreadmillTiers[math.clamp(math.floor(tier),1,#self.Config.TreadmillTiers)]
 return spec and spec.Biome or'Forest'
end

function EconomyService:_buildState(player, message)
	local nearSell = self:_isNear(player, self.Map.SellStation) == true
	local state = {
		Success = true,
		Message = message,
		Cash = self.PlayerData:GetCash(player),
		Multiplier = tonumber(player:GetAttribute("TreadmillMultiplier")) or 1,
		LuckMultiplier = tonumber(player:GetAttribute("ChestLuckMultiplier")) or 1,
		Products = {},
        BootBiome = self:_bootBiome(player),
		Harvests = self.PlayerData:GetHarvestInventory(player),
        PendingSales=self.PlayerData:GetPendingSales(player),
		CanSell = nearSell,
	}

	local wornTrail=self.PlayerData:GetEquippedBoost(player,'Trail');local wornBoots=self.PlayerData:GetEquippedBoost(player,'Accessory')
	for _, category in ipairs(CATEGORY_ORDER) do
		state.Products[category] = {}
		for _, product in ipairs(self.Config.ShopCatalog[category]) do
			local color = product.Color or Color3.fromRGB(111, 203, 255)
			local blocked = self:_purchaseBlockReason(product)
            if not blocked and not self:_isNear(player,self.Map.BuyStation)and not self.PlayerData:OwnsBoost(player,product.Id)then blocked="Visit shop"end
			table.insert(state.Products[category], {
				Id = product.Id,
				Name = product.Name,
				Type = product.Type,
                Biome = product.Biome,
				Price = product.Price,
				Description = product.Description,
				SpeedMultiplier = product.SpeedMultiplier,
				LuckMultiplier = product.LuckMultiplier,
				Enabled = blocked == nil,
				UnavailableReason = blocked,
				Owned = self.PlayerData:OwnsBoost(player, product.Id),
                Equipped = (wornTrail and wornTrail.Id==product.Id)or(wornBoots and wornBoots.Id==product.Id)or false,
				Color = colorToTable(color),
			})
		end
	end
	return state
end

function EconomyService:_equip(player, id, equipped)
 if not self.PlayerData:IsLoaded(player)then return {Success=false,Message='YOUR DATA IS STILL LOADING'}end
 if not self.PlayerData.CanSave[player]then return {Success=false,Message='Your save is not ready.'}end
 if type(id)~='string'or(equipped~=nil and type(equipped)~='boolean')then return {Success=false,Message='Choose an item.'}end
 if not(self:_isNear(player,self.Map.BuyStation)or self:_isNear(player,self.Map.SellStation))then return {Success=false,Message='VISIT THE SHOP OR SELL STATION'}end
 local humanoid=player.Character and player.Character:FindFirstChildOfClass('Humanoid')
 if not humanoid or humanoid.Health<=0 or(self.Chase and self.Chase:IsPlayerBusy(player))then return {Success=false,Message='FINISH YOUR CHASE FIRST'}end
 local now=os.clock();if now-(self.LastEquip[player]or -math.huge)<.25 then return {Success=false,Message='PLEASE WAIT A MOMENT'}end
 self.LastEquip[player]=now
 if not self.PlayerData:EquipBoost(player,id,equipped)then return {Success=false,Message='Buy this item first.'}end
 self:ApplyCosmetics(player,player.Character)
 self.PlayerData:QueueGardenSave(player)
 return self:_buildState(player,equipped==false and'Unequipped'or'Equipped')
end

function EconomyService:_purchase(player, productId)
	if not self.PlayerData:IsLoaded(player) then
		return {Success = false, Message = "PLAYER DATA IS STILL LOADING"}
	end
	if not self:_isNear(player, self.Map.BuyStation) then
		return {Success = false, Message = "VISIT THE BUY STATION FIRST"}
	end

	local product = type(productId) == "string" and self.ProductById[productId] or nil
	if not product then
		return {Success = false, Message = "UNKNOWN SHOP ITEM"}
	end
	local blocked = self:_purchaseBlockReason(product)
    if blocked then return {Success = false, Message = blocked} end
	if self.PlayerData:OwnsBoost(player, product.Id) then
		return {Success = false, Message = "YOU ALREADY OWN THIS"}
	end
	if not self.PlayerData:SpendCash(player, product.Price) then
		return {Success = false, Message = "NOT ENOUGH CASH"}
	end

	if not self.PlayerData:AddBoost(player, product.Id) then
		-- Roll back the rejected transaction immediately; this is not a currency award.
        self.PlayerData:GetOrCreateCashValue(player).Value += product.Price
        self.PlayerData:MarkDirty(player)
		return {Success = false, Message = "PURCHASE COULD NOT BE APPLIED"}
	end
	self:ApplyCosmetics(player, player.Character)

	local state = self:_buildState(player, "PURCHASED " .. string.upper(product.Name))
	self.Notifications:Show(player, state.Message, Color3.fromRGB(113, 255, 174), 2.5)
	return state
end

function EconomyService:_sell(player, lootInstanceName)
	if not self.PlayerData:IsLoaded(player) then
		return {Success = false, Message = "PLAYER DATA IS STILL LOADING"}
	end
	if not self:_isNear(player, self.Map.SellStation) then
		return {Success = false, Message = "VISIT THE SELL STATION FIRST"}
	end
	local success, result = self.PlayerData:SellLoot(player, lootInstanceName)
	if not success then
		return {Success = false, Message = result}
	end
	local state = self:_buildState(player, string.format("SOLD FOR $%d CASH", result))
	self.Notifications:Show(player, state.Message, Color3.fromRGB(255, 221, 92), 2.5)
	return state
end

function EconomyService:_managePedestal(_player, _action, _lootInstanceName)
    return {Success=false, Message="CASH PEDESTALS HAVE BEEN REMOVED"}
end

function EconomyService:_teleport(player, stationName)
	if player:GetAttribute("GuardianRagdollActive") or player:GetAttribute("GuardianFlingActive") then return end
	if self.Chase:IsPlayerBusy(player) then
		self.Notifications:Show(player, "STATION TRAVEL IS DISABLED DURING A CHASE", Color3.fromRGB(255, 174, 87), 2.5, "Denied")
		return
	end
	local now = os.clock()
	if now - (self.LastStationTravel[player] or -math.huge) < self.Config.FastTravelCooldown then
		return
	end
	local targetCFrame = stationName == "Buy" and self.Map.BuyTeleportCFrame
		or stationName == "Sell" and self.Map.SellTeleportCFrame
		or nil
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not targetCFrame or not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
	character:PivotTo(targetCFrame + Vector3.new(0, 4, 0));Movement.Reset(player)
	self.LastStationTravel[player] = now
	task.delay(0.2, function()
		if player.Parent then
			self.OpenEconomyUI:FireClient(player, stationName == "Buy" and "Trails" or "Sell")
		end
	end)
end

function EconomyService:_clearTreasureShowcase(record)
	for _, slot in ipairs(record.TreasureDisplaySlots or {}) do
		local oldDecoration = slot:FindFirstChild("LootDecoration")
		if oldDecoration then
			oldDecoration:Destroy()
		end
	end
end

function EconomyService:_refreshTreasureShowcase(player)
	local record = self.Bases:GetPlayerBase(player)
	if not record or #(record.TreasureDisplaySlots or {}) == 0 then
		return
	end

	self:_clearTreasureShowcase(record)
	local lootValues = {}
	for _, lootValue in ipairs(self.PlayerData:GetOrCreateLootInventory(player):GetChildren()) do
		if lootValue:IsA("StringValue") then
			table.insert(lootValues, lootValue)
		end
	end
	table.sort(lootValues, function(left, right)
		local leftRarity = left:GetAttribute("Rarity") or "Common"
		local rightRarity = right:GetAttribute("Rarity") or "Common"
		local leftRank = self.Config.RarityOrder[leftRarity] or 1
		local rightRank = self.Config.RarityOrder[rightRarity] or 1
		return leftRank == rightRank and left.Value < right.Value or leftRank > rightRank
	end)

	local shownNames = {}
	local slotIndex = 0
	for _, lootValue in ipairs(lootValues) do
		if not shownNames[lootValue.Value] then
			shownNames[lootValue.Value] = true
			slotIndex = slotIndex + 1
			local slot = record.TreasureDisplaySlots[slotIndex]
			if not slot then
				break
			end

			local rarity = lootValue:GetAttribute("Rarity") or "Common"
			local decoration = Instance.new("Part")
			decoration.Name = "LootDecoration"
			styleTreasureShape(decoration, lootValue.Value)
			decoration.Anchored = true
			decoration.CanCollide = false
			decoration.CanTouch = false
			decoration.CanQuery = false
			decoration.CastShadow = true
			decoration.Material = Enum.Material.Neon
			decoration.Color = self.Config.RarityColors[rarity]
				or self.Config.RarityColors.Common
			decoration.CFrame = slot.CFrame * CFrame.new(
				0,
				slot.Size.Y / 2 + decoration.Size.Y / 2 + 0.25,
				0
			)
			decoration:SetAttribute("LootName", lootValue.Value)
			decoration:SetAttribute("Rarity", rarity)
			decoration.Parent = slot

			local glow = Instance.new("PointLight")
			glow.Name = "ShowcaseGlow"
			glow.Color = decoration.Color
			glow.Brightness = 0.65
			glow.Range = 7
			glow.Parent = decoration
		end
	end
end

function EconomyService:_bestOwnedProduct(player, productType)
	local best = nil
	local bestValue = -math.huge
	for productId in pairs(self.PlayerData:GetOwnedBoosts(player)) do
		local product = self.ProductById[productId]
		if product and product.Type == productType and product.Enabled ~= false then
			local value = product.SpeedMultiplier or product.LuckMultiplier or 1
			if value > bestValue then
				best = product
				bestValue = value
			end
		end
	end
	return best
end

function EconomyService:ApplyCosmetics(player, character)
 if not character or not self.PlayerData:IsLoaded(player)then return end
 local old=character:FindFirstChild('ChestChaseCosmetics');if old then old:Destroy()end
 local root=character:FindFirstChild('HumanoidRootPart')
 if root then for _,name in ipairs({'ChestChaseTrailTop','ChestChaseTrailBottom','RunnerTrailA1','RunnerTrailB1','RunnerTrailA2','RunnerTrailB2'})do
  local p=root:FindFirstChild(name);if p then p:Destroy()end
 end end
 local folder=Instance.new('Folder');folder.Name='ChestChaseCosmetics';folder:SetAttribute('CosmeticVersion',91)
 local trailProduct=self.PlayerData:GetEquippedBoost(player,'Trail')
 if root and trailProduct then
  local art=require(ReplicatedStorage:WaitForChild('RunnerTrailArt'))
  local lo,hi=art.BodyRange(character,root);folder:SetAttribute('TrailId84',trailProduct.Id);folder:SetAttribute('TrailLow84',lo);folder:SetAttribute('TrailHigh84',hi)
  for i=1,2 do
   local top,bottom=art.Attachments(root.Size,i,lo,hi)
   local a=Instance.new('Attachment');a.Name='RunnerTrailA'..i;a.Position=top;a.Parent=root
   local b=Instance.new('Attachment');b.Name='RunnerTrailB'..i;b.Position=bottom;b.Parent=root
   local trail=Instance.new('Trail');trail.Name='RunnerRibbon'..i;trail:SetAttribute('RunnerMovementTrail',true);trail:SetAttribute('BackMounted',true)
   trail.Attachment0=a;trail.Attachment1=b;art.Configure(trail,trailProduct.Color,i,trailProduct.Id);trail.Parent=folder
  end
 end
 local accessory=self.PlayerData:GetEquippedBoost(player,'Accessory')
 if accessory then
  local biome=accessory.Biome or'Desert'
  local count=require(ReplicatedStorage:WaitForChild('RunnerBootArt')).Create(character,folder,biome,accessory.Color)
  folder:SetAttribute('BootCount',count);folder:SetAttribute('BootBiome',biome)
  if count==2 and require(ReplicatedStorage:WaitForChild('RunnerTrailRules')).Theme(self:_bootBiome(player))and require(ReplicatedStorage:WaitForChild('RunnerTrailRules')).Theme(biome)then folder:SetAttribute('BootGroundTheme',biome)end
 end
 folder.Parent=character
end

function EconomyService:SetupPlayer(player)
	for _, connection in ipairs(self.ShowcaseConnections[player] or {}) do
		connection:Disconnect()
	end
	self.ShowcaseConnections[player] = nil

	local record = self.Bases:GetPlayerBase(player)
	local inventory = self.PlayerData:GetOrCreateLootInventory(player)
	local function queueShowcaseRefresh()
		task.defer(function()
			if player.Parent then
				self:_refreshTreasureShowcase(player)
			end
		end)
	end
	self.ShowcaseConnections[player] = {
		inventory.ChildAdded:Connect(queueShowcaseRefresh),
		inventory.ChildRemoved:Connect(queueShowcaseRefresh),
        player:GetAttributeChangedSignal('TreadmillTier'):Connect(function()
            if player.Parent then self:ApplyCosmetics(player,player.Character)end
        end),
	}
	self:_refreshTreasureShowcase(player)
	self.PlayerData:RefreshBoostMultipliers(player)
	self:ApplyCosmetics(player, player.Character)
end

function EconomyService:Start()
	if self.Running then
		return
	end
	self.Running = true
	local folder = ReplicatedStorage:FindFirstChild(self.Config.RemoteFolderName)
 self.CollectSaleCash=getOrCreateRemote(folder,'CollectSaleCash','RemoteFunction')
 self.CollectSaleCash.OnServerInvoke=function(player,id,index)if not Gate.Allow(player,'CollectSaleCash',id,index)then return {Success=false}end;return self.PlayerData:CollectSaleCash(player,id,index)end
 self.GetPendingSales=getOrCreateRemote(folder,'GetPendingSales','RemoteFunction')
 self.GetPendingSales.OnServerInvoke=function(player)
  if not Gate.Allow(player,'GetPendingSales')then return nil end
  if not self.PlayerData:IsLoaded(player)then return nil end
  return self.PlayerData:GetPendingSales(player)
 end
	self.SellHarvest = getOrCreateRemote(folder, "SellHarvest", "RemoteFunction")
	self.SellHarvest.OnServerInvoke = function(player, harvestId)
        if not Gate.Allow(player,'SellHarvest', harvestId)then return {Success=false,Message='Please wait.'}end
		return self:_sellHarvest(player, harvestId)
	end

	self.GetShopState.OnServerInvoke = function(player)
        if not Gate.Allow(player,'GetShopState')then return {Success=false,Message='Please wait.'}end
		return self:_buildState(player)
	end
	self.PurchaseShopItem.OnServerInvoke = function(player, productId)
        if not Gate.Allow(player,'PurchaseShopItem', productId)then return {Success=false,Message='Please wait.'}end
		return self:_purchase(player, productId)
	end
	self.EquipShopItem.OnServerInvoke = function(player, id, equipped)if not Gate.Allow(player,'EquipShopItem',id,equipped)then return {Success=false}end;return self:_equip(player,id,equipped)end
	self.SellLootItem.OnServerInvoke = function(player, lootInstanceName)
        if not Gate.Allow(player,'SellLootItem', lootInstanceName)then return {Success=false,Message='Please wait.'}end
		return self:_sell(player, lootInstanceName)
	end
	self.ManagePedestalItem.OnServerInvoke = function(player, action, lootInstanceName)
        if not Gate.Allow(player,'ManagePedestalItem', action, lootInstanceName)then return {Success=false,Message='Please wait.'}end
		return self:_managePedestal(player, action, lootInstanceName)
	end
	self.RequestStationTeleport.OnServerEvent:Connect(function(player, stationName)
        if not Gate.Allow(player,'RequestStationTeleport',stationName)then return end
		self:_teleport(player, stationName)
	end)
	self.Map.BuyPrompt.Triggered:Connect(function(player)
		self.OpenEconomyUI:FireClient(player, "Trails")
	end)
	self.Map.SellPrompt.Triggered:Connect(function(player)
		self.OpenEconomyUI:FireClient(player, "Sell")
	end)
	for _, record in ipairs(self.Map.BaseRecords) do
		self:_clearTreasureShowcase(record)
	end

    -- V0.78: no cash-pedestal payout timer.

end

function EconomyService:CleanupPlayer(player)
	local record = self.Bases:GetPlayerBase(player)
	if record then
		self:_clearTreasureShowcase(record)
	end
	for _, connection in ipairs(self.ShowcaseConnections[player] or {}) do
		connection:Disconnect()
	end
	self.ShowcaseConnections[player] = nil
	self.LastStationTravel[player] = nil
    self.LastEquip[player] = nil
end
function EconomyService:_sellHarvest(player, harvestId)
	if not self.PlayerData:IsLoaded(player) then return {Success = false, Message = "YOUR DATA IS STILL LOADING"} end
	if self.Chase:IsPlayerBusy(player) then return {Success = false, Message = "FINISH YOUR CHASE FIRST"} end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or not self:_isNear(player, self.Map.SellStation) then
		return {Success = false, Message = "VISIT THE SELL STATION FIRST"}
	end
	local success,result
 if harvestId=='ALL'then success,result=self.PlayerData:SellAllHarvests(player)
 else success,result=self.PlayerData:SellHarvest(player,harvestId)end
	if not success then return {Success = false, Message = result} end
	self.PlayerData:QueueGardenSave(player)
 self.Chests:SyncTools(player)
 local state=self:_buildState(player, string.format("SOLD FOR $%d CASH", result))
 state.SaleAmount=result -- Proceeds stay in PendingSales until each cash icon is claimed.
 return state
end

return EconomyService
