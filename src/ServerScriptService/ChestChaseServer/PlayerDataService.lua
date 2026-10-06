-- V0.73 permanent seed discoveries, lossless seed serialization, and save conflict checks.
-- Owns persistent player progress: speed, Cash, loot, permanent discoveries,
-- boosts, pedestals, and biome seeds. The legacy Chests save key is retained.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local PlantRules = require(game:GetService("ReplicatedStorage"):WaitForChild("PlantRules"))
local Weather=require(game:GetService('ReplicatedStorage').WeatherTraits)
local Points=require(game:GetService('ReplicatedStorage').SpeedPoints)
local Progression=require(game:GetService('ReplicatedStorage').Progression81)
local PackRules = require(game:GetService("ReplicatedStorage"):WaitForChild("SeedPackRules"))
local VerityCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("VerityCatalog")) -- R147
local VerityReasons = require(game:GetService("ReplicatedStorage"):WaitForChild("VerityConfig")).Reasons -- R152: what Verity says when a hand-in is refused (CheckVoidPack / ConvertVoidPack)
local PackShapes = require(game:GetService("ReplicatedStorage"):WaitForChild("PackShapes151")) -- R151: a pack's chip-bag shape (an optional field of its record)
-- R151: the optional PackShape of a saved / gifted Pack row: 1-6, or nil (absent, 0, or anything else = the default shape).
local function savedPackShape(row)
	if row.Kind ~= "Pack" or not PackShapes.Applies(PackRules.VariantKey(row.BagVariant)) then return nil end -- R152: the Verity pack (flat pouch) and the Void / Mech never carry a shape, whatever an older record says
	local shape = PackShapes.Sanitize(row.PackShape)
	return shape > 0 and shape or nil
end

local function gardenClonePremium(t)local o={};for k,v in pairs(t)do o[k]=type(v)=='table'and gardenClonePremium(v)or v end;return o end
local PlayerDataService = {}
PlayerDataService.__index = PlayerDataService

function PlayerDataService.new(config, mapService, notifications)
	local self = setmetatable({}, PlayerDataService)
	self.Config = config
	self.Map = mapService
	self.Notifications = notifications
	self.IsStudio = RunService:IsStudio()
	self.Store = DataStoreService:GetDataStore(config.GetDataStoreName(self.IsStudio))

	self.Loaded = {}
	self.CanSave = {}
	self.Dirty = {}
	self.Saving = {}
	self.Finalizing = {}
	self.SaveHeads = {}
	self.Gardens = {}
	self.GardenSaveQueued = {}
	self.Revision = {}
	self.ChestRecords = {}
	self.OwnedBoosts = {}
    self.TestBoosts = {};self.TestLuck = {} -- R152: boots an owner command gave (TestGrant), and whether the luck in use comes from them
    self.EquippedBoosts = {}
    self.Treadmills = {}
	self.PedestalItems = {}
	self.AutosaveRunning = false
	return self
end

local function statFolder(player,name)
 local folder=player:FindFirstChild(name)
 if not folder then folder=Instance.new('Folder');folder.Name=name;folder.Parent=player end
 return folder
end
local function disconnectStat(link)
 for _,connection in ipairs(link.Connections)do connection:Disconnect()end
end
function PlayerDataService:_disconnectStatLinks(player)
 local links=self.StatLinks and self.StatLinks[player];if not links then return end
 self.StatLinks[player]=nil
 for _,link in pairs(links.Values)do disconnectStat(link)end
 links.Destroying:Disconnect()
end
local function rawStat(self,player,name,class,default,priority)
 local folder=statFolder(player,'ChestChaseStats');local leader=statFolder(player,'leaderstats')
 self.StatLinks=self.StatLinks or{}
 local links=self.StatLinks[player]
 if not links then
  links={Values={}};self.StatLinks[player]=links
  links.Destroying=player.Destroying:Connect(function()self:_disconnectStatLinks(player)end)
 end
 local previous=links.Values[name];local value=folder:FindFirstChild(name)
 if not value and previous and previous.Raw then value=previous.Raw;value.Parent=folder end
 if not value then
  local legacy=leader:FindFirstChild(name)
  -- Reparent the original raw object. Never reconstruct progress from a rounded
  -- PlayerList string, even when that string happens to contain only digits.
  if legacy and legacy:GetAttribute('ChestChaseDisplayStat')~=true then
   if legacy:IsA(class)and(name~='Speed'or Points.Valid(legacy.Value))then value=legacy;value.Parent=folder
   elseif legacy:IsA('IntValue')or legacy:IsA('NumberValue')then
    default=name=='Speed'and self.Config.NormalizeSpeedStat(legacy.Value)or legacy.Value
   end
  end
 end
 if not value then value=Instance.new(class);value.Name=name;value.Value=default;value.Parent=folder end
 local display=leader:FindFirstChild(name)
 if display and not display:IsA('StringValue')then display:Destroy();display=nil end
 if not display then display=Instance.new('StringValue');display.Name=name;display.Parent=leader end
 display:SetAttribute('ChestChaseDisplayStat',true)
 local order=display:FindFirstChild('Priority')
 if order and not order:IsA('NumberValue')then order:Destroy();order=nil end
 if not order then order=Instance.new('NumberValue');order.Name='Priority';order.Parent=display end
 order.Value=priority
 local primary=display:FindFirstChild('IsPrimary');if primary and primary:IsA('BoolValue')then primary.Value=false end
 if not previous or previous.Raw~=value or previous.Display~=display then
  if previous then disconnectStat(previous)end
  local link={Raw=value,Display=display,Connections={}};links.Values[name]=link
  local function update()
   if self.StatLinks[player]~=links or links.Values[name]~=link then return end
   local text=require(game:GetService('ReplicatedStorage').CashNumbers).PlayerList(value.Value)
   if display.Value~=text then display.Value=text end
  end
  local function unbind()
   if links.Values[name]==link then links.Values[name]=nil end
   link.Raw=nil;disconnectStat(link)
  end
  link.Connections={value:GetPropertyChangedSignal('Value'):Connect(update),value.Destroying:Connect(unbind),display.Destroying:Connect(unbind)}
  update()
 end
 return value
end
function PlayerDataService:GetOrCreateCashValue(player)
 return rawStat(self,player,'Cash','IntValue',0,1)
end
function PlayerDataService:GetOrCreateSpeedValue(player)
 return rawStat(self,player,'Speed','StringValue',self.Config.NormalizeSpeedStat(self.Config.DefaultSpeed),2)
end

function PlayerDataService:AddSpeed(player,amount)
 if not self:IsLoaded(player)or type(amount)~='number'or amount~=amount or amount<0 or amount==math.huge then return 0 end
 amount=math.floor(amount);if amount==0 then return 0 end
 local value=self:GetOrCreateSpeedValue(player);value.Value=Points.Add(value.Value,amount)
 self:MarkDirty(player);return amount
end

function PlayerDataService:GetOrCreateLootInventory(player)
	local inventory = player:FindFirstChild("LootInventory")
	if not inventory then
		inventory = Instance.new("Folder")
		inventory.Name = "LootInventory"
		inventory.Parent = player
	end
	return inventory
end

function PlayerDataService:GetOrCreateDiscoveredLoot(player)
	local discoveries = player:FindFirstChild("DiscoveredLoot")
	if not discoveries then
		discoveries = Instance.new("Folder")
		discoveries.Name = "DiscoveredLoot"
		discoveries.Parent = player
	end
	return discoveries
end

function PlayerDataService:IsKnownLootItem(itemName)
	if type(itemName) ~= "string" or itemName == "" then
		return false
	end

	for _, itemNames in pairs(self.Config.LootItemsByRarity) do
		for _, knownName in ipairs(itemNames) do
			if knownName == itemName then
				return true
			end
		end
	end

	return false
end

function PlayerDataService:MarkItemDiscovered(player, itemName, skipDirty)
	if not self:IsKnownLootItem(itemName) then
		return false
	end

	local discoveries = self:GetOrCreateDiscoveredLoot(player)
	local existing = discoveries:FindFirstChild(itemName)
	if existing and existing:IsA("BoolValue") and existing.Value then
		return false
	end
	if existing then
		existing:Destroy()
	end

	local discoveredValue = Instance.new("BoolValue")
	discoveredValue.Name = itemName
	discoveredValue.Value = true
	discoveredValue.Parent = discoveries

	if not skipDirty then
		self:MarkDirty(player)
	end
	return true
end

function PlayerDataService:GetDiscoveredItems(player)
	local discoveredItems = {}
	for _, value in ipairs(self:GetOrCreateDiscoveredLoot(player):GetChildren()) do
		if value:IsA("BoolValue") and value.Value and self:IsKnownLootItem(value.Name) then
			table.insert(discoveredItems, value.Name)
		end
	end
	table.sort(discoveredItems)
	return discoveredItems
end

function PlayerDataService:GetOrCreateDiscoveredSeeds(player)
	local folder = player:FindFirstChild("DiscoveredSeeds")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "DiscoveredSeeds"
		folder.Parent = player
	end
	return folder
end

function PlayerDataService:MarkSeedDiscovered(player, seedId, skipDirty)
	if not self.Config.GetSeedById(seedId) then return false end
	local folder = self:GetOrCreateDiscoveredSeeds(player)
	local value = folder:FindFirstChild(seedId)
	if value and value:IsA("BoolValue") and value.Value then return false end
	if value then value:Destroy() end
	value = Instance.new("BoolValue")
	value.Name = seedId
	value.Value = true
	value.Parent = folder
	player:SetAttribute("DiscoveredSeedCount", #folder:GetChildren())
	if not skipDirty then self:MarkDirty(player) end
	return true
end

function PlayerDataService:GetDiscoveredSeeds(player)
	local result = {}
	for _, value in ipairs(self:GetOrCreateDiscoveredSeeds(player):GetChildren()) do
		if value:IsA("BoolValue") and value.Value then
			table.insert(result, value.Name)
		end
	end
	table.sort(result)
	return result
end

function PlayerDataService:CanReceiveSeed(player)
	if not self:IsLoaded(player) then return false, "YOUR DATA IS STILL LOADING" end
	if #self:GetChestRecords(player) >= self.Config.MaxSavedChests then
		return false, "BAG FULL - MAKE ROOM IN UR BAG FIRST"
	end
	return true
end

function PlayerDataService:_notifySeedInventory(player)
	player:SetAttribute("SeedInventoryCount", #self:GetChestRecords(player))
	player:SetAttribute("SeedInventoryRevision", (player:GetAttribute("SeedInventoryRevision") or 0) + 1)
end

function PlayerDataService:GetSeedInventory(player)
	local groups, result = {}, {}
	for _, record in ipairs(self:GetChestRecords(player)) do
		local seed, stage, index = self.Config.GetSeedById(record.SeedId)
        stage = PackRules.ObtainableStage(record.SeedId) or stage
		if seed then
			local seedScale = PackRules.SanitizeSeedScale(record.SeedScale)
            local mutation = PackRules.MutationKey(record.PackMutation)
            local weather=Weather.Key(record.Weather)
            local key = seed.Id..":"..tostring(seedScale)..":"..mutation..":"..weather
            local group = groups[key]
			if not group then
				group = {
					SeedId = seed.Id, Weather=weather, Name = (weather~="None"and Weather.Display(weather).." "or"")..(mutation ~= "None" and mutation.." " or "")..seed.Name, Mutation = mutation, Emoji = seed.Emoji,
					Stage = stage, SeedIndex = index, BiomeName = self.Config.BiomeNames[stage],
					InventoryId = record.Id, Count = 0, SeedScale = seedScale,
					Plantable = self.Config.GardenPlants[seed.Id] ~= nil,
                    Rarity = PackRules.GetRarity(seed.Id),
                    GrowSeconds = self.Config.GardenPlants[seed.Id] and self.Config.GardenPlants[seed.Id].Seconds or 0,
					HarvestValue = self.Config.GardenPlants[seed.Id] and self.Config.GardenPlants[seed.Id].Value or 0,
					Color = {R = math.floor(seed.Color.R * 255 + 0.5),
						G = math.floor(seed.Color.G * 255 + 0.5), B = math.floor(seed.Color.B * 255 + 0.5)},
				}
				groups[key] = group
				table.insert(result, group)
			end
			group.Count = group.Count + 1
		end
	end
	table.sort(result, function(a, b)
		if a.Stage ~= b.Stage then return a.Stage < b.Stage end
		return a.SeedIndex < b.SeedIndex
	end)
	return result
end

-- A commit ID detects a different server writing after this session's load.
-- This is optimistic conflict detection, not an exclusive session lease.
local function getSaveHead(data)
	return {
		Exists = data ~= nil,
		Commit = type(data) == "table" and data.SeedSaveCommitId or nil,
		SavedAt = type(data) == "table" and data.SavedAt or nil,
		Version = type(data) == "table" and data.Version or nil,
	}
end

local function sameSaveHead(a, b)
	return a and b and a.Exists == b.Exists and a.Commit == b.Commit
		and a.SavedAt == b.SavedAt and a.Version == b.Version
end

function PlayerDataService:PreparePlayer(player)
	self:GetOrCreateSpeedValue(player)
	self:GetOrCreateCashValue(player)
	self:GetOrCreateLootInventory(player)
	self:GetOrCreateDiscoveredLoot(player)
	self:GetOrCreateDiscoveredSeeds(player)
	self.ChestRecords[player] = {}
	self.Gardens[player] = {Version = 7, Plots = {}, Harvests = {}}
	player:SetAttribute("GardenRevision", 0)
	self.OwnedBoosts[player] = {}
    self.TestBoosts[player] = {};self.TestLuck[player] = nil
    self.EquippedBoosts[player] = {}
    self.Treadmills[player]={Tier=1,Skin=1,Cleared={}}
    self:PublishTreadmillData(player)
    self:LoadFenceData(player,nil)
	self.PedestalItems[player] = nil
	self.Loaded[player] = false
	self.CanSave[player] = false
	self.Dirty[player] = false
	self.Revision[player] = 0
	player:SetAttribute("DataStatus", "Loading")
	player:SetAttribute("TreadmillMultiplier", 1)
	player:SetAttribute("ChestLuckMultiplier", 1)
	-- R153: owning a luck pass (any way) changes the luck at once, not at the next boots change.
	for _, pass in ipairs(require(game:GetService('ReplicatedStorage').GamePassCatalog)) do
		if (pass.Luck or 1) > 1 then
			player:GetAttributeChangedSignal(pass.Attribute):Connect(function() if self.OwnedBoosts[player] then self:RefreshBoostMultipliers(player) end end)
		end
	end
	player:SetAttribute("SeedInventoryCount", 0)
	player:SetAttribute("SeedInventoryRevision", 0)
	player:SetAttribute("DiscoveredSeedCount", 0)
end

function PlayerDataService:MarkDirty(player)
	self.Dirty[player] = true
	self.Revision[player] = (self.Revision[player] or 0) + 1
end

function PlayerDataService:IsLoaded(player)
	return self.Loaded[player] == true and not (self.Finalizing and self.Finalizing[player])
end

function PlayerDataService:GetChestRecords(player)
	if not self.ChestRecords[player] then
		self.ChestRecords[player] = {}
	end
	return self.ChestRecords[player]
end

function PlayerDataService:GetOldestChest(player)
	local oldest = nil
	for _, chestRecord in ipairs(self:GetChestRecords(player)) do
		if not oldest or chestRecord.ChestNumber < oldest.ChestNumber then
			oldest = chestRecord
		end
	end
	return oldest
end

function PlayerDataService:HasChest(player, chestId)
	for _, chestRecord in ipairs(self:GetChestRecords(player)) do
		if chestRecord.Id == chestId then
			return true
		end
	end
	return false
end

-- R137: options.Luck = a pack the player earned (track steal, event pack, treadmill bonus): its size goes through
-- the hidden pack-size pity (PackSizePityData). Bought, gifted and test packs pass no options.
-- R151: options.TestGrant = a pack an owner / admin command made (OwnerTestPacks): the record carries TestGrant=true and its open is never announced.
-- R151: chest.PackShape = the pack's chip-bag shape (PackShapes151): a world pack brings the one it rolled when it spawned (0 = the default shape, kept for life);
-- a pack made here (bonus rolls, daily rewards, the mystery pedestal, owner commands ...) rolls its own, once. The record keeps it as an OPTIONAL field (absent = the
-- default shape, which is every record saved before it), so ProfileVersion stays 22.
function PlayerDataService:AddChest(player, chest, options)
	local canReceive, reason = self:CanReceiveSeed(player)
	if not canReceive then return nil, reason end
	local packSize = chest.PackSize
	if type(options) == "table" and options.Luck then packSize = self:RollPackLuck(player, chest.Stage, PackRules.VariantKey(chest.BagVariant), PackRules.SanitizePackSize(chest.PackSize)) end
	local chestNumber = (player:GetAttribute("ChestInventorySerial") or 0) + 1
	player:SetAttribute("ChestInventorySerial", chestNumber)
	-- Escaping banks a biome pack; no seed is rolled or discovered yet.
	local record = {
		Id = string.format("%d_%d", player.UserId, chestNumber),
		ChestNumber = chestNumber, ChestName = "Seed Pack", Kind = "Pack",
		Stage = chest.Stage, AccentColor = self.Map:GetStageAccent(chest.Stage),
        BagVariant = PackRules.VariantKey(chest.BagVariant),OddsVersion=chest.OddsVersion or 81,
            PackSize=PackRules.SanitizePackSize(packSize),PackMutation=PackRules.MutationKey(chest.PackMutation),Weather=Weather.Key(chest.Weather),WeatherCheckedEvent=Weather.CheckedEvent(chest.WeatherCheckedEvent),
        SeedScale = PackRules.NewSeedScale(chest.Stage,chest.BagVariant,packSize),
        RateBoost = PackRules.SanitizeRateBoost(chest.RateBoost), -- R138: the free starter pack's 2x rates
        TestGrant = (type(options) == "table" and options.TestGrant == true) or nil, -- R151: made by an owner command (never announced when opened)
        GiftLocked = chest.GiftLocked == true or nil, -- R152: a free giveaway pack (VoidGiveaway152): it can't be gifted (an optional field, like PackShape)
	}
	do local shape = chest.PackShape;if shape == nil then shape = PackShapes.Roll(chest.BagVariant) end;shape = PackShapes.Sanitize(shape);if shape > 0 and PackShapes.Applies(chest.BagVariant) then record.PackShape = shape end end
	table.insert(self:GetChestRecords(player), record)
    if chest.Stage<=self.Config.StageCount then self:MarkTreadmillBiome(player,chest.Stage)end
	self:_notifySeedInventory(player)
	self:MarkDirty(player)
	self:TutorialEvent(player,'Pack')
	return record
end

-- One non-yielding inventory transaction. Replays find a Seed, not a Pack.
function PlayerDataService:OpenSeedPack(player, inventoryId, unitRoll)
    if not self:IsLoaded(player) then return nil, "YOUR DATA IS STILL LOADING" end
    if type(inventoryId) ~= "string" or #inventoryId > 80 then return nil, "TRY AGAIN!" end
    local records = self:GetChestRecords(player)
    for index, pack in ipairs(records) do
        if pack.Id ~= inventoryId then continue end
        if pack.Kind ~= "Pack" then return nil, "U ALREADY OPENED THIS PACK!" end
        if pack.PaidRandom and player:GetAttribute('PaidRandomAllowed')~=true then return nil,'THIS BOUGHT PACK DOESN\'T WORK ON THIS ACCOUNT' end
        local seed, rarity = PackRules.Roll(self.Config,pack.Stage,unitRoll,player:GetAttribute("ChestLuckMultiplier"),pack.BagVariant,pack.OddsVersion,pack.RateBoost)
        local testSeed=require(script.Parent.RarePackTests).Expected(self,player,pack.Id)
        local luckTest=self:HasTestLuck(player) -- R152: the luck comes from owner-given boots (/test boots): a TEST open, like an owner-made pack (its seed is a TEST seed too)
        if testSeed then seed=self.Config.GetSeedById(testSeed);rarity=PackRules.GetRarity(testSeed)end
        if not seed then return nil, "REJOIN TO OPEN THIS PACK!" end
        local rewardCash,reason=self:SeedCollectReward(player,seed.Id)
        if not rewardCash then return nil,reason end
        local reward = {
            Id=pack.Id, ChestNumber=pack.ChestNumber, ChestName=seed.Name, Kind="Seed",
            PaidRandom=pack.PaidRandom==true,Stage=(pack.BagVariant=='EclipseReliquary'or VerityCatalog.IsPack(pack.BagVariant))and PackRules.SeedDesignById[seed.Id].SaveStage or pack.Stage, SeedId=seed.Id, SeedName=seed.Name, SeedEmoji=seed.Emoji,
            AccentColor=seed.Color, Rarity=rarity, SeedScale=PackRules.NewSeedScale(pack.Stage,pack.BagVariant,pack.PackSize),
            BagVariant=PackRules.VariantKey(pack.BagVariant),OddsVersion=pack.OddsVersion,
            PackSize=PackRules.SanitizePackSize(pack.PackSize),PackMutation=PackRules.MutationKey(pack.PackMutation),Weather=Weather.Key(pack.Weather),WeatherCheckedEvent=Weather.CheckedEvent(pack.WeatherCheckedEvent),
            TestGrant=(pack.TestGrant==true or luckTest) or nil, -- R152: the seed of a TEST open is a TEST seed (the fruit it grows never counts for the hub / announcements)
        }
        records[index] = reward
        self:_gardenChanged(player)
        if testSeed then self.StudioPackRewards[player][pack.Id]=nil end
        self:MarkDirty(player)
        self:MarkSeedDiscovered(player,seed.Id,true)
        self:CommitSeedReward(player,seed.Id,rewardCash)
        self:_notifySeedInventory(player)
        self:QueueGardenSave(player)
        self:TutorialEvent(player,'Seed')
        self:QuestEvent(player,'Open',1) -- R140 daily quest
        pcall(function()require(script.Parent.PullAnnouncer).OnOpened(player,pack,reward,testSeed~=nil or luckTest)end) -- R151: a real open of a Legendary+ seed is announced (a TEST pack never is)
        -- R151: the hub's BEST PULL TODAY board (HubDisplayService.NotePull; set by the main script). It never yields or throws here; a TEST pack (/test rarepacks, or any pack an owner command made:
        -- TestGrant) is flagged so it is not counted and never announced as a record.
        local hook=self.OnPackOpened
        if hook then pcall(hook,player,reward,{Stage=pack.Stage,Variant=pack.BagVariant,Version=pack.OddsVersion,Boost=pack.RateBoost,Luck=player:GetAttribute("ChestLuckMultiplier"),Test=testSeed~=nil or pack.TestGrant==true or luckTest}) end
        return reward
    end
    return nil, "THAT PACK IS GONE FROM UR BAG!"
end

-- R147: the Verity NPC turns a Void Pack into a Verity Pack. CheckVoidPack finds the record or says why not (changes nothing).
function PlayerDataService:CheckVoidPack(player, inventoryId)
	if not self:IsLoaded(player) then return nil, VerityReasons.Loading end
	if type(inventoryId) ~= "string" or #inventoryId > 80 then return nil, VerityReasons.Invalid end
	for _, pack in ipairs(self:GetChestRecords(player)) do
		if pack.Id == inventoryId then
			if pack.Kind ~= "Pack" or pack.BagVariant ~= "EclipseReliquary" or pack.Stage ~= 7 then return nil, VerityReasons.NotVoid end
			return pack
		end
	end
	return nil, VerityReasons.Gone
end

-- One non-yielding inventory transaction, like OpenSeedPack. The Verity Pack takes the Void Pack's slot (the bag keeps its
-- order) with a fresh Id from the serial; size, coat, weather and the paid flag carry over. Returns the new record, or nil
-- and the reason with nothing changed.
function PlayerDataService:ConvertVoidPack(player, inventoryId)
	local old, reason = self:CheckVoidPack(player, inventoryId)
	if not old then return nil, reason end
	local records = self:GetChestRecords(player)
	for index, pack in ipairs(records) do
		if pack ~= old then continue end
		local chestNumber = (player:GetAttribute("ChestInventorySerial") or 0) + 1
		player:SetAttribute("ChestInventorySerial", chestNumber)
		local size = PackRules.SanitizePackSize(pack.PackSize)
		local record = {
			Id = string.format("%d_%d", player.UserId, chestNumber),
			ChestNumber = chestNumber, ChestName = "Seed Pack", Kind = "Pack",
			Stage = VerityCatalog.PackStage, AccentColor = pack.AccentColor or self.Map:GetStageAccent(VerityCatalog.PackStage),
			BagVariant = VerityCatalog.Variant, OddsVersion = PackRules.OddsVersion,
			PackSize = size, PackMutation = PackRules.MutationKey(pack.PackMutation), Weather = Weather.Key(pack.Weather),
			WeatherCheckedEvent = Weather.CheckedEvent(pack.WeatherCheckedEvent), PaidRandom = pack.PaidRandom == true,
			SeedScale = PackRules.NewSeedScale(VerityCatalog.PackStage, VerityCatalog.Variant, size),
			TestGrant = pack.TestGrant == true or nil, -- R151: an owner-made Void pack stays a test pack as a Verity pack
			GiftLocked = pack.GiftLocked == true or nil, -- R152: so does a free giveaway pack: the Verity Pack it becomes can't be gifted either
		}
		records[index] = record
		local tests = self.StudioPackRewards and self.StudioPackRewards[player]
		if tests then tests[pack.Id] = nil end -- an owner-test guarantee on the old pack does not carry over
		self:_notifySeedInventory(player)
		self:MarkDirty(player)
		return record
	end
	return nil, VerityReasons.Gone
end

function PlayerDataService:AddCash(player, amount)
 if type(amount)~='number'or amount~=amount or math.abs(amount)==math.huge then return false end
 amount=math.ceil(amount);if amount<=0 then return false end
 return self:QueueCurrency(player,amount,'Cash')
end

function PlayerDataService:SpendCash(player, amount)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	local cashValue = self:GetOrCreateCashValue(player)
	if amount <= 0 or not self:IsLoaded(player) or cashValue.Value < amount then
		return false
	end
	cashValue.Value = cashValue.Value - amount
	self:MarkDirty(player)
	return true
end

function PlayerDataService:GetCash(player)
	return self:GetOrCreateCashValue(player).Value
end

function PlayerDataService:RemoveChest(player, chestId)
	local records = self:GetChestRecords(player)
	for index, chestRecord in ipairs(records) do
		if chestRecord.Id == chestId then
			table.remove(records, index)
			self:_notifySeedInventory(player)
			self:MarkDirty(player)
			return true
		end
	end
	return false
end

function PlayerDataService:AwardLoot(player, stage, rarity, itemName)
	local inventory = self:GetOrCreateLootInventory(player)
	local lootNumber = (player:GetAttribute("LootCount") or 0) + 1
	player:SetAttribute("LootCount", lootNumber)

	local lootValue = Instance.new("StringValue")
	lootValue.Name = string.format("Loot_%03d", lootNumber)
	lootValue.Value = itemName
	lootValue:SetAttribute("Rarity", rarity)
	lootValue:SetAttribute("ChestStage", stage)
	lootValue.Parent = inventory
	self:MarkItemDiscovered(player, itemName, true)
	self:MarkDirty(player)
	return lootValue
end

function PlayerDataService:_lootRecordFromValue(lootValue)
	return {
		Name = lootValue.Value,
		Rarity = lootValue:GetAttribute("Rarity") or "Common",
		Stage = lootValue:GetAttribute("ChestStage") or 1,
	}
end

function PlayerDataService:ReturnLootRecord(player, item)
	if type(item) ~= "table" or type(item.Name) ~= "string" then
		return nil
	end
	return self:AwardLoot(
		player,
		math.clamp(math.floor(tonumber(item.Stage) or 1), 1, self.Config.StageCount),
		self.Config.RarityColors[item.Rarity] and item.Rarity or "Common",
		string.sub(item.Name, 1, 80)
	)
end

function PlayerDataService:TakeBestLoot(player)
	local selected = nil
	local selectedRank = -1
	for _, child in ipairs(self:GetOrCreateLootInventory(player):GetChildren()) do
		if child:IsA("StringValue") then
			local rarity = child:GetAttribute("Rarity") or "Common"
			local rank = self.Config.RarityOrder[rarity] or 1
			if rank > selectedRank then
				selected = child
				selectedRank = rank
			end
		end
	end
	if not selected then
		return nil
	end
	local item = self:_lootRecordFromValue(selected)
	selected:Destroy()
	self:MarkDirty(player)
	return item
end

function PlayerDataService:PlaceLootOnPedestal(_player, _lootInstanceName)
    return false, "CASH PEDESTALS HAVE BEEN REMOVED"
end

function PlayerDataService:RemovePedestalItem(player)
	if not self:IsLoaded(player) then
		return false, "PLAYER DATA IS STILL LOADING"
	end
	local current = self.PedestalItems[player]
	if not current then
		return false, "THE PEDESTAL IS EMPTY!"
	end
	self.PedestalItems[player] = nil
	self:ReturnLootRecord(player, current)
	self:MarkDirty(player)
	return true, current
end

function PlayerDataService:SellLoot(player, lootInstanceName)
	if type(lootInstanceName) ~= "string" or not self:IsLoaded(player) then
		return false, "INVALID ITEM"
	end
	local lootValue = self:GetOrCreateLootInventory(player):FindFirstChild(lootInstanceName)
	if not lootValue or not lootValue:IsA("StringValue") then
		return false, "ITEM NOT FOUND"
	end
	local rarity = lootValue:GetAttribute("Rarity") or "Common"
	local value = self.Config.SellValueByRarity[rarity] or self.Config.SellValueByRarity.Common
	lootValue:Destroy()
	local cashValue = self:GetOrCreateCashValue(player)
	cashValue.Value = cashValue.Value + value
	self:MarkDirty(player)
	return true, value
end

function PlayerDataService:GetPedestalItem(player)
	return self.PedestalItems[player]
end

function PlayerDataService:SetPedestalItem(player, item)
	self.PedestalItems[player] = item
	self:MarkDirty(player)
end

function PlayerDataService:GetOwnedBoosts(player)
	if not self.OwnedBoosts[player] then
		self.OwnedBoosts[player] = {}
	end
	return self.OwnedBoosts[player]
end

function PlayerDataService:OwnsBoost(player, productId)
	return self:GetOwnedBoosts(player)[productId] == true
end

function PlayerDataService:_findShopProduct(productId)
	for _, products in pairs(self.Config.ShopCatalog) do
		for _, product in ipairs(products) do
			if product.Id == productId then
				return product
			end
		end
	end
	return nil
end

-- Appearance is selectable; permanent bonuses still use the best owned upgrade.
function PlayerDataService:GetEquippedBoost(player, kind)
 if kind~='Trail'and kind~='Accessory'then return nil end
 local choices=self.EquippedBoosts[player]or{};self.EquippedBoosts[player]=choices
 if choices[kind]==false then return nil end
 local selected=self:_findShopProduct(choices[kind])
 if selected and selected.Type==kind and selected.Enabled~=false and self:OwnsBoost(player,selected.Id)then return selected end
 local best,value=nil,-math.huge
 for id in pairs(self:GetOwnedBoosts(player))do
  local product=self:_findShopProduct(id)
  if product and product.Type==kind and product.Enabled~=false then
   local score=product.SpeedMultiplier or product.LuckMultiplier or 1
   if score>value then best,value=product,score end
  end
 end
 choices[kind]=best and best.Id or nil
 return best
end
function PlayerDataService:RestoreEquippedBoosts(player, saved)
 local clean={}
 if type(saved)=='table'then for _,kind in ipairs({'Trail','Accessory'})do
  local id=saved[kind];local p=type(id)=='string'and self:_findShopProduct(id)
  if id==false then clean[kind]=false
  elseif p and p.Type==kind and p.Enabled~=false and self:OwnsBoost(player,id)then clean[kind]=id end
 end end
 self.EquippedBoosts[player]=clean
 self:GetEquippedBoost(player,'Trail');self:GetEquippedBoost(player,'Accessory')
end
function PlayerDataService:CopyEquippedBoosts(player)
 local result={}
 for _,kind in ipairs({'Trail','Accessory'})do
  local p=self:GetEquippedBoost(player,kind)
  if p then result[kind]=p.Id elseif self.EquippedBoosts[player][kind]==false then result[kind]=false end
 end
 return result
end
function PlayerDataService:EquipBoost(player, id, equipped)
 if not self:IsLoaded(player)or type(id)~='string'or(equipped~=nil and type(equipped)~='boolean')then return false end
 local product=self:_findShopProduct(id)
 if not product or(product.Type~='Trail'and product.Type~='Accessory')or product.Enabled==false or not self:OwnsBoost(player,id)then return false end
 local choices=self.EquippedBoosts[player]or{};self.EquippedBoosts[player]=choices
 if equipped==false then
  local worn=self:GetEquippedBoost(player,product.Type)
  if worn and worn.Id==id then choices[product.Type]=false;self:MarkDirty(player)end
 elseif choices[product.Type]~=id then choices[product.Type]=id;self:MarkDirty(player)end
 return true
end

-- R152: the luck in use comes from boots an owner command gave (/test boots): no bought boots reach it. A pull made with that luck is a TEST pull (never announced, never on the hub's boards).
function PlayerDataService:HasTestLuck(player)
	return self.TestLuck[player] == true
end
-- R153: the product of the luck passes the player owns (a pass counts when its Owned attribute is on, which the Robux check, a game-pass purchase, a Gem purchase and a gift all set, or when the saved Gem / gift entitlement is there).
function PlayerDataService:PassLuck(player)
	local luck = 1
	local premium = self.Premium and self.Premium[player]
	for _, pass in ipairs(require(game:GetService('ReplicatedStorage').GamePassCatalog)) do
		if (pass.Luck or 1) > 1 and (player:GetAttribute(pass.Attribute) == true or (premium and type(premium.Entitlements) == "table" and premium.Entitlements[pass.Key] == true)) then luck = luck * pass.Luck end
	end
	return luck
end
function PlayerDataService:RefreshBoostMultipliers(player)
	local bestSpeedMultiplier = 1
	local bestLuckMultiplier = 1
	local realLuck, testLuck, tests = 1, 1, self.TestBoosts[player] or {}
	for productId in pairs(self:GetOwnedBoosts(player)) do
		local product = self:_findShopProduct(productId)
		if product and product.Enabled ~= false then
			if product.Type == "Trail" and product.SpeedMultiplier then
				bestSpeedMultiplier = math.max(bestSpeedMultiplier, product.SpeedMultiplier)
			elseif product.Type == "Accessory" and product.LuckMultiplier then
				bestLuckMultiplier = math.max(bestLuckMultiplier, product.LuckMultiplier)
				if tests[productId] then testLuck = math.max(testLuck, product.LuckMultiplier) else realLuck = math.max(realLuck, product.LuckMultiplier) end
			end
		end
	end
	player:SetAttribute("TreadmillMultiplier", bestSpeedMultiplier)
	-- R153: the best boots (owner test boots too) x every luck pass the player owns (GamePassCatalog Luck: the 4 Leaf Clover = x2, bought with Robux or Gems), then the one cap (MaxLuck).
	-- The pass multiplies real and test luck alike, so HasTestLuck still says whether the BOOTS in use are the owner's.
	bestLuckMultiplier=math.clamp(bestLuckMultiplier*self:PassLuck(player),1,require(game:GetService('ReplicatedStorage').BalanceValues81).MaxLuck)
	player:SetAttribute("ChestLuckMultiplier", bestLuckMultiplier)
	self.TestLuck[player] = testLuck > realLuck
	return bestSpeedMultiplier, bestLuckMultiplier
end

function PlayerDataService:RefreshTreadmillMultiplier(player)
	return self:RefreshBoostMultipliers(player)
end

-- R152: options.TestGrant = boots an owner command gave (/test boots): remembered (and saved, as the optional TestBoosts list) so pulls made with their luck count as TEST pulls.
function PlayerDataService:AddBoost(player, productId, options)
	local product = self:_findShopProduct(productId)
	if not product or product.Enabled == false
		or (product.Type ~= "Trail" and product.Type ~= "Accessory") then
		return false
	end
	local owned = self:GetOwnedBoosts(player)
	if owned[productId] then
		return false
	end
	owned[productId] = true
	if type(options) == "table" and options.TestGrant == true then self.TestBoosts[player] = self.TestBoosts[player] or {};self.TestBoosts[player][productId] = true end
    self.EquippedBoosts[player]=self.EquippedBoosts[player]or{}
    self.EquippedBoosts[player][product.Type]=productId
	self:RefreshBoostMultipliers(player)
	self:MarkDirty(player)
	return true
end

function PlayerDataService:_getKey(player)
	return "Player_" .. tostring(player.UserId)
end

function PlayerDataService:_runRequest(callback)
	local lastError = nil
	for attempt = 1, self.Config.DataStoreRetryCount do
		local success, result = pcall(callback)
		if success then
			return true, result
		end

		lastError = result
		if attempt < self.Config.DataStoreRetryCount then
			task.wait(2 ^ (attempt - 1))
		end
	end
	return false, lastError
end

function PlayerDataService:_clearLootInventory(inventory)
	for _, child in ipairs(inventory:GetChildren()) do
		if child:IsA("StringValue") then
			child:Destroy()
		end
	end
end

function PlayerDataService:_clearDiscoveredLoot(discoveries)
	for _, child in ipairs(discoveries:GetChildren()) do
		if child:IsA("BoolValue") then
			child:Destroy()
		end
	end
end

-- R122: one saved seed/pack row -> live record. Shared by Load and seed/pack gifts so a
-- gifted item decodes exactly like a reloaded one (traits are never re-rolled).
function PlayerDataService:_decodeSavedSeedRecord(player, savedChest, fallbackNumber)
	local stage = math.clamp(
		math.floor((tonumber(savedChest.Stage) or 1) + 0.5),
		1,
		(savedChest.BagVariant=='MechLimited'or require(game:GetService('ReplicatedStorage').MechCatalog).Is(savedChest.SeedId))and 8
			or VerityCatalog.Is(savedChest.SeedId)and VerityCatalog.Stage or self.Config.StageCount -- R147: the Verity seed keeps its Index category 9
	)
	local chestNumber = math.max(
		1,
		math.floor((tonumber(savedChest.ChestNumber) or fallbackNumber) + 0.5)
	)
	local fallbackSeedIndex = (chestNumber - 1) % 5 + 1
	local fallbackSeed = self.Config.GetSeedDefinition(stage, fallbackSeedIndex)
	local accentColor = self.Map:GetStageAccent(stage)
	if type(savedChest.AccentR) == "number"
		and type(savedChest.AccentG) == "number"
		and type(savedChest.AccentB) == "number" then
		accentColor = Color3.new(
			math.clamp(savedChest.AccentR, 0, 1),
			math.clamp(savedChest.AccentG, 0, 1),
			math.clamp(savedChest.AccentB, 0, 1)
		)
	end

	return {
		Id = type(savedChest.Id) == "string" and string.sub(savedChest.Id, 1, 80)
			or string.format("%d_%d", player.UserId, chestNumber),
		Kind = savedChest.Kind == "Pack" and "Pack" or "Seed",
                PaidRandom=savedChest.PaidRandom==true,RateBoost=PackRules.SanitizeRateBoost(savedChest.RateBoost),
                TestGrant=savedChest.TestGrant==true or nil, -- R151 (optional; an older server drops it); R152: on a Seed record too (an owner-given seed, or the seed of a TEST opening)
                PackShape=savedPackShape(savedChest), -- R151 (optional chip-bag shape 1-6; absent / anything else = the default shape)
                GiftLocked=(savedChest.Kind=="Pack" and savedChest.GiftLocked==true) or nil, -- R152 (optional; an R151 server drops it)
                BagVariant = PackRules.VariantKey(savedChest.BagVariant),OddsVersion=PackRules.ValidOddsVersion(savedChest.OddsVersion)and savedChest.OddsVersion or nil, -- R137: 81, 112 and 137 all load
            PackSize=PackRules.SanitizePackSize(savedChest.PackSize),PackMutation=PackRules.MutationKey(savedChest.PackMutation),Weather=Weather.Key(savedChest.Weather),WeatherCheckedEvent=Weather.CheckedEvent(savedChest.WeatherCheckedEvent),
                SeedScale = PackRules.SanitizeSeedScale(savedChest.SeedScale),
		ChestNumber = chestNumber,
		ChestName = type(savedChest.ChestName) == "string"
			and string.sub(savedChest.ChestName, 1, 80)
			or string.format("Stage_%d_Chest", stage),
		Stage = stage,
		AccentColor = accentColor,
		GuaranteedRarity = type(savedChest.GuaranteedRarity) == "string"
			and self.Config.RarityColors[savedChest.GuaranteedRarity]
			and savedChest.GuaranteedRarity
			or nil,
		SeedId = type(savedChest.SeedId) == "string"
			and string.sub(savedChest.SeedId, 1, 80)
			or fallbackSeed.Id,
		SeedName = type(savedChest.SeedName) == "string"
			and string.sub(savedChest.SeedName, 1, 80)
			or fallbackSeed.Name,
		SeedEmoji = type(savedChest.SeedEmoji) == "string"
			and string.sub(savedChest.SeedEmoji, 1, 16)
			or fallbackSeed.Emoji,
	}
end

function PlayerDataService:_canonicalizeSeedRecord(record)
	if record.Kind == "Pack" then
		record.SeedScale=PackRules.NewSeedScale(record.Stage,record.BagVariant,record.PackSize)
		record.SeedId, record.SeedName, record.SeedEmoji, record.GuaranteedRarity = nil, nil, nil, nil
		return record
	end
	local canonical = self.Config.GetSeedById(record.SeedId)
	if canonical then record.SeedName, record.SeedEmoji, record.AccentColor = canonical.Name, canonical.Emoji, canonical.Color end
	return record
end

function PlayerDataService:Load(player)
	local success, storedData = self:_runRequest(function()
		return self.Store:GetAsync(self:_getKey(player))
	end)

	if not player.Parent or (self.Finalizing and self.Finalizing[player]) then
		return false
	end

	if not success then
		player:SetAttribute("DataStatus", "LoadFailed")
		self.Loaded[player] = self.IsStudio == true
		self.CanSave[player] = false
		warn(string.format(
			"[%s] Data load failed for %s. Saving is disabled for this session: %s",
			self.Config.Version,
			player.Name,
			tostring(storedData)
			))
		if not self.IsStudio then
			player:Kick("Couldn't load ur progress. Rejoin to try again! Ur saved data is safe.")
			return false
		end
		task.delay(0.75, function()
			if player.Parent then
				self.Notifications:Show(
					player,
					self.IsStudio
						and "SAVING IS OFF - PUBLISH THE GAME AND ENABLE STUDIO API SERVICES"
						or "PLAYER DATA COULD NOT LOAD - SAVING IS DISABLED THIS SESSION",
					Color3.fromRGB(255, 118, 118),
					8
				)
			end
		end)
		return false
	end

	if (storedData ~= nil and type(storedData) ~= "table")
		or (type(storedData) == "table" and (tonumber(storedData.Version) or 0) > self.Config.ProfileVersion) then
		self.CanSave[player] = false
		player:SetAttribute("DataStatus", "UnsupportedProfile")
		player:Kick("Ur saved garden needs a newer server. Rejoin and u'll be good! Ur data is safe.")
		return false
	end
	local premium=require(script.Parent.PremiumProgress).Decode(type(storedData)=='table'and storedData.Premium or nil)
    if not premium then self.CanSave[player]=false;player:SetAttribute('DataStatus','UnsupportedPremium');player:Kick('Ur progress needs a newer server. Rejoin! Ur save is safe.');return false end
    self.Premium=self.Premium or{};self.Premium[player]=premium
    -- R150: publish the saved audio mix on the Player right away (replicated attributes, no remote): the client's AudioMixer applies it before
    -- SettingsState answers, so a saved Music / Effects of 0 is not heard at 100% at the start of the session. A new player gets the defaults.
    pcall(function()
        local config=require(game:GetService('ReplicatedStorage'):WaitForChild('SettingsConfig'))
        local mix=config.Read(premium.Settings)
        for key,attribute in pairs(config.AudioAttributes)do player:SetAttribute(attribute,mix[key])end
    end)
    if not premium.Tutorial then premium.Tutorial={Version=1,Mask=0,Done=storedData~=nil}end
    local garden, gardenError = self:DecodeGarden(type(storedData) == "table" and storedData.Garden or nil)
	if not garden then
		self.CanSave[player] = false
		player:SetAttribute("DataStatus", "UnsupportedGarden")
		player:Kick("Couldn't read ur garden safely. Ur save is safe. Please tell the developer!")
		warn("[V0.73] Garden load rejected: "..tostring(gardenError))
		return false
	end
	if type(storedData) == "table" and storedData.PedestalItem ~= nil then
        local item=storedData.PedestalItem
        if type(item) ~= "table" or type(item.Name) ~= "string" or #item.Name<1 or #item.Name>80
            or (item.Stage ~= nil and (not self.Config.IsFiniteGardenNumber(item.Stage) or item.Stage<1 or item.Stage>self.Config.StageCount)) then
            self.CanSave[player]=false; player:SetAttribute("DataStatus","UnsupportedPedestal")
            player:Kick("Couldn't get back ur old display item safely. Ur save is safe.")
            return false
        end
        garden.RetiredPedestalItem = item
        local checked=self:DecodeGarden(garden)
        if not checked then
            self.CanSave[player]=false; player:SetAttribute("DataStatus","UnsupportedPedestal")
            player:Kick("Ur old display item needs a safe update. Ur save is safe.")
            return false
        end
        garden=checked
    end
    self.Gardens[player] = garden
    self.SaveHeads[player] = getSaveHead(storedData)
	local speedValue = self:GetOrCreateSpeedValue(player)
	local cashValue = self:GetOrCreateCashValue(player)
	local lootInventory = self:GetOrCreateLootInventory(player)
	local discoveredLoot = self:GetOrCreateDiscoveredLoot(player)
	self:_clearLootInventory(lootInventory)
	self:_clearDiscoveredLoot(discoveredLoot)
	self.ChestRecords[player] = {}

	local loadedSpeed = Points.Normalize(self.Config.DefaultSpeed)
	local loadedCash = 0
	local loadedItems = {}
	local loadedChests = {}
	local loadedBoosts, loadedTestBoosts = {}, {}
	local loadedPedestalItem = nil
	local loadedDiscoveries = {}
	local loadedSeedDiscoveries = {}
	local speedMigrationNeeded = false
	local seedMigrationNeeded = false
	if type(storedData) == "table" then
		if storedData.SpeedExact~=nil then
            if not Points.Valid(storedData.SpeedExact)then self.CanSave[player]=false;player:SetAttribute('DataStatus','UnsupportedSpeed');player:Kick('Ur Speed data needs a newer server. Ur save is safe.');return false end
            loadedSpeed=Points.Normalize(storedData.SpeedExact)
        elseif type(storedData.Speed) == "number" then
			if storedData.SpeedSystemVersion == self.Config.SpeedSystemVersion then
				loadedSpeed = Progression.Migrate(storedData.Speed)
				speedMigrationNeeded = loadedSpeed ~= storedData.Speed
			else
				loadedSpeed = Progression.Migrate(self.Config.LegacySpeedToStat(storedData.Speed))
				speedMigrationNeeded = true
			end
		end
		if type(storedData.Cash) == "number" then
			loadedCash = math.max(0, math.floor(storedData.Cash + 0.5))
		end
		if type(storedData.DiscoveredSeeds) == "table" then
			for key, value in pairs(storedData.DiscoveredSeeds) do
				local id = type(key) == "number" and value or key
				if type(id) == "string" and (type(key) == "number" or value == true) then
					loadedSeedDiscoveries[id] = true
				end
			end
		end
		if type(storedData.Items) == "table" then
			loadedItems = storedData.Items
		end
		if type(storedData.Seeds) == "table" then
			loadedChests = storedData.Seeds
		elseif type(storedData.Chests) == "table" then
			loadedChests = storedData.Chests
			seedMigrationNeeded = true
		end
		if type(storedData.OwnedBoosts) == "table" then
			loadedBoosts = storedData.OwnedBoosts
		end
		if type(storedData.TestBoosts) == "table" then loadedTestBoosts = storedData.TestBoosts end -- R152 (optional; an R151 server drops it)
		if type(storedData.PedestalItem) == "table" then
			loadedPedestalItem = storedData.PedestalItem
		end
		if type(storedData.DiscoveredItems) == "table" then
			for key, value in pairs(storedData.DiscoveredItems) do
				local itemName = type(key) == "number" and value or key
				local isDiscovered = type(key) == "number" or value == true
				if isDiscovered and self:IsKnownLootItem(itemName) then
					loadedDiscoveries[itemName] = true
				end
			end
		end
	end

	speedValue.Value = loadedSpeed
	cashValue.Value = loadedCash
	local loadedItemCount = 0
	for _, savedItem in ipairs(loadedItems) do
		if type(savedItem) == "table" and type(savedItem.Name) == "string" and savedItem.Name ~= "" then
			loadedItemCount = loadedItemCount + 1
			local rarity = type(savedItem.Rarity) == "string" and savedItem.Rarity or "Common"
			if not self.Config.RarityColors[rarity] then
				rarity = "Common"
			end
			local stage = math.clamp(
				math.floor((tonumber(savedItem.Stage) or 1) + 0.5),
				1,
				self.Config.StageCount
			)

			local lootValue = Instance.new("StringValue")
			lootValue.Name = string.format("Loot_%03d", loadedItemCount)
			lootValue.Value = string.sub(savedItem.Name, 1, 80)
			lootValue:SetAttribute("Rarity", rarity)
			lootValue:SetAttribute("ChestStage", stage)
			lootValue.Parent = lootInventory
		end
	end

	local loadedChestCount = 0
	local highestChestNumber = 0
	for _, savedChest in ipairs(loadedChests) do
		if type(savedChest) == "table" then
			local record = self:_decodeSavedSeedRecord(player, savedChest, loadedChestCount + 1)
			loadedChestCount = loadedChestCount + 1
			highestChestNumber = math.max(highestChestNumber, record.ChestNumber)
			table.insert(self.ChestRecords[player], record)
		end
	end

	for _, record in ipairs(self.ChestRecords[player]) do
		self:_canonicalizeSeedRecord(record)
	end

	self.OwnedBoosts[player] = {}
    self.EquippedBoosts[player] = {}
	for _, productId in ipairs(loadedBoosts) do
		if type(productId) == "string" and self:_findShopProduct(productId) then
			self.OwnedBoosts[player][productId] = true
		end
	end
	self.TestBoosts[player] = {}
	for _, productId in ipairs(loadedTestBoosts) do
		if type(productId) == "string" and self.OwnedBoosts[player][productId] then self.TestBoosts[player][productId] = true end
	end

    self:RestoreEquippedBoosts(player,type(storedData)=='table'and storedData.EquippedBoosts or nil)
	self.PedestalItems[player] = nil
	if loadedPedestalItem and type(loadedPedestalItem.Name) == "string" then
		local rarity = type(loadedPedestalItem.Rarity) == "string"
			and loadedPedestalItem.Rarity
			or "Common"
		if not self.Config.RarityColors[rarity] then
			rarity = "Common"
		end
		self.PedestalItems[player] = {
			Name = string.sub(loadedPedestalItem.Name, 1, 80),
			Rarity = rarity,
			Stage = math.clamp(math.floor(tonumber(loadedPedestalItem.Stage) or 1), 1, self.Config.StageCount),
		}
	end

	-- V0.34 migration: merge saved discovery history with every item still held
	-- or displayed. Selling an item after this point never removes its discovery.
	local discoveryMigrationNeeded = type(storedData) == "table"
		and type(storedData.DiscoveredItems) ~= "table"
	for _, lootValue in ipairs(lootInventory:GetChildren()) do
		if lootValue:IsA("StringValue") and self:IsKnownLootItem(lootValue.Value) then
			if not loadedDiscoveries[lootValue.Value] then
				discoveryMigrationNeeded = true
			end
			loadedDiscoveries[lootValue.Value] = true
		end
	end
	if self.PedestalItems[player]
		and self:IsKnownLootItem(self.PedestalItems[player].Name) then
		local itemName = self.PedestalItems[player].Name
		if not loadedDiscoveries[itemName] then
			discoveryMigrationNeeded = true
		end
		loadedDiscoveries[itemName] = true
	end
	for itemName in pairs(loadedDiscoveries) do
		self:MarkItemDiscovered(player, itemName, true)
	end
	-- Union persisted discoveries with currently owned seeds. Never infer old
	-- sold seed IDs for which there is no historical evidence.
	local seedDiscoveryMigrationNeeded = type(storedData) ~= "table"
		or type(storedData.DiscoveredSeeds) ~= "table"
	for _, record in ipairs(self.ChestRecords[player]) do
		if self.Config.GetSeedById(record.SeedId) and not loadedSeedDiscoveries[record.SeedId] then
			loadedSeedDiscoveries[record.SeedId] = true
			seedDiscoveryMigrationNeeded = true
		end
	end
	local seedDiscoveryFolder = self:GetOrCreateDiscoveredSeeds(player)
	for id in pairs(loadedSeedDiscoveries) do
		-- Keep unrecognized saved discovery IDs in storage for future compatibility;
		-- the public Index displays only entries in the current catalog.
		if not seedDiscoveryFolder:FindFirstChild(id) then
			local value = Instance.new("BoolValue")
			value.Name = id
			value.Value = true
			value.Parent = seedDiscoveryFolder
		end
	end
	player:SetAttribute("DiscoveredSeedCount", #seedDiscoveryFolder:GetChildren())
	self:RefreshBoostMultipliers(player)

	table.sort(self.ChestRecords[player], function(left, right)
		return left.ChestNumber < right.ChestNumber
	end)
	player:SetAttribute("ChestInventorySerial", math.max(highestChestNumber,
		type(storedData) == "table" and tonumber(storedData.SeedInventorySerial) or 0))
	player:SetAttribute("PackSerialAtJoin", player:GetAttribute("ChestInventorySerial")) -- R139: packs numbered above this are new (hotbar rainbow)
	player:SetAttribute("SeedInventoryCount", #self.ChestRecords[player])
	player:SetAttribute("LootCount", loadedItemCount)
    local pedestalMigrationNeeded = self.PedestalItems[player] ~= nil
    if pedestalMigrationNeeded then
        self:ReturnLootRecord(player,self.PedestalItems[player])
        self.PedestalItems[player]=nil
    end
	self:LoadTreadmillData(player,type(storedData)=="table" and storedData.Treadmill or nil)
    self:LoadFenceData(player,type(storedData)=='table'and storedData.Fence or nil)
    self:LoadPackLuck(player,type(storedData)=='table'and storedData.PackLuck or nil)
	player:SetAttribute("DataStatus", "Loaded")
	self.Loaded[player] = true
	self.CanSave[player] = true
    local oldRosterSettled=self:SettleOldRoster148(player) -- R148: which Index milestones were met before the Aloe and the Sand Fruit joined Desert (saved below)
    self:PublishPremium(player);self:PublishTutorial(player)
	self.Dirty[player] = storedData == nil
		or oldRosterSettled
		or discoveryMigrationNeeded
		or speedMigrationNeeded
        or (type(storedData)=="table" and (storedData.SpeedExact==nil or type(storedData.Premium)~='table' or storedData.Premium.BalanceVersion81~=81))
		or seedMigrationNeeded
		or seedDiscoveryMigrationNeeded
		or type(storedData) ~= "table" or storedData.Garden == nil or storedData.Garden.Version ~= self.Config.GardenSchemaVersion
        or pedestalMigrationNeeded
        or type(storedData)~="table" or type(storedData.Treadmill)~="table"
	if self.Dirty[player] then
		self.Revision[player] = 1
	end
	return true
end

-- R122: the exact saved row for one live seed/pack record (DataStore-safe: no Color3).
function PlayerDataService:SerializeSeedRecord(chestRecord)
	local accentColor = chestRecord.AccentColor or self.Map:GetStageAccent(chestRecord.Stage)
	return {
		Id = string.sub(chestRecord.Id, 1, 80),
		Kind = chestRecord.Kind or "Seed",
            PaidRandom=chestRecord.PaidRandom==true,RateBoost=PackRules.SanitizeRateBoost(chestRecord.RateBoost),
            TestGrant=chestRecord.TestGrant==true or nil, -- R151 (optional; an older server drops it); R152: Seed records too
            PackShape=savedPackShape(chestRecord), -- R151 (optional chip-bag shape 1-6)
            GiftLocked=(chestRecord.Kind=="Pack" and chestRecord.GiftLocked==true) or nil, -- R152 (optional; an R151 server drops it)
            BagVariant = PackRules.VariantKey(chestRecord.BagVariant),OddsVersion=chestRecord.OddsVersion,
            PackSize=PackRules.SanitizePackSize(chestRecord.PackSize),PackMutation=PackRules.MutationKey(chestRecord.PackMutation),Weather=Weather.Key(chestRecord.Weather),WeatherCheckedEvent=Weather.CheckedEvent(chestRecord.WeatherCheckedEvent),
            SeedScale = PackRules.SanitizeSeedScale(chestRecord.SeedScale),
		ChestNumber = chestRecord.ChestNumber,
		ChestName = string.sub(chestRecord.ChestName, 1, 80),
		Stage = chestRecord.Stage,
		AccentR = accentColor.R,
		AccentG = accentColor.G,
		AccentB = accentColor.B,
		GuaranteedRarity = chestRecord.GuaranteedRarity,
		SeedId = string.sub(chestRecord.SeedId or "UnknownSeed", 1, 80),
		SeedName = string.sub(chestRecord.SeedName or "Unknown Seed", 1, 80),
		SeedEmoji = string.sub(chestRecord.SeedEmoji or "🌱", 1, 16),
	}
end

-- R122: strict decode of a seed/pack row that arrives as a gift. Anything a normal save
-- could not have produced is refused (the gift stays in the inbox for review).
function PlayerDataService:DecodeGiftedSeed(player, saved)
	if type(saved) ~= "table" or (saved.Kind ~= "Pack" and saved.Kind ~= "Seed")
		or type(saved.Id) ~= "string" or #saved.Id < 1 or #saved.Id > 80
		or type(saved.ChestName) ~= "string" or #saved.ChestName > 80
		or type(saved.Stage) ~= "number" or saved.Stage ~= saved.Stage or saved.Stage % 1 ~= 0 or saved.Stage < 1 or saved.Stage > 9
		or type(saved.ChestNumber) ~= "number" or saved.ChestNumber ~= saved.ChestNumber or saved.ChestNumber < 1 or saved.ChestNumber > 1e12 then
		return nil
	end
	for _, key in ipairs({"AccentR", "AccentG", "AccentB", "SeedScale", "PackSize"}) do
		local v = saved[key]
		if v ~= nil and (type(v) ~= "number" or v ~= v or math.abs(v) == math.huge) then return nil end
	end
	if saved.Kind == "Seed" and (type(saved.SeedId) ~= "string" or not self.Config.GetSeedById(saved.SeedId)) then return nil end
	local record = self:_canonicalizeSeedRecord(self:_decodeSavedSeedRecord(player, saved, 1))
	if record.Kind == "Seed" and record.SeedId ~= saved.SeedId then return nil end
	record.RateBoost = nil -- R139: a gifted starter pack arrives as a normal pack (gifts staged before R139 too)
	return record
end

function PlayerDataService:_buildSaveData(player)
	local items = {}
	local lootChildren = self:GetOrCreateLootInventory(player):GetChildren()
	table.sort(lootChildren, function(left, right)
		return left.Name < right.Name
	end)

	for _, lootValue in ipairs(lootChildren) do
		if lootValue:IsA("StringValue") then
			table.insert(items, {
				Name = string.sub(lootValue.Value, 1, 80),
				Rarity = lootValue:GetAttribute("Rarity") or "Common",
				Stage = lootValue:GetAttribute("ChestStage") or 1,
			})
		end
	end

	local savedChests = {}
	for _, chestRecord in ipairs(self:GetChestRecords(player)) do
		table.insert(savedChests, self:SerializeSeedRecord(chestRecord))
	end

	local savedBoosts = {}
	for productId in pairs(self:GetOwnedBoosts(player)) do
		table.insert(savedBoosts, productId)
	end
	table.sort(savedBoosts)
	local savedTestBoosts = {}
	for productId in pairs(self.TestBoosts[player] or {}) do if self:OwnsBoost(player, productId) then table.insert(savedTestBoosts, productId) end end
	table.sort(savedTestBoosts)

	local discoveredItems = self:GetDiscoveredItems(player)

	local pedestalItem = self:GetPedestalItem(player)
	local savedPedestalItem = nil
	if pedestalItem then
		savedPedestalItem = {
			Name = string.sub(pedestalItem.Name, 1, 80),
			Rarity = pedestalItem.Rarity,
			Stage = pedestalItem.Stage,
		}
	end

	return {
		Version = self.Config.ProfileVersion,
        Premium = require(script.Parent.PremiumProgress).Pack(gardenClonePremium(self:GetPremium(player))), -- R153: late passes' data goes to the optional Later153 (an R152 server ignores it)
		Garden = self:CopyGarden(self.Gardens[player]),
		DiscoveredSeeds = self:GetDiscoveredSeeds(player),
		SeedInventorySerial = player:GetAttribute("ChestInventorySerial") or 0,
		SpeedSystemVersion = self.Config.SpeedSystemVersion,
		SpeedExact = Points.Normalize(self:GetOrCreateSpeedValue(player).Value),
        SpeedPointFormat='decimal-v1',BalanceMigrationVersion=81,
        Speed = Progression.LegacySave(self:GetOrCreateSpeedValue(player).Value),
		Cash = self:GetOrCreateCashValue(player).Value,
		Items = items,
		Seeds = savedChests,
		OwnedBoosts = savedBoosts,
		TestBoosts = #savedTestBoosts > 0 and savedTestBoosts or nil, -- R152 (optional; an R151 server drops it)
        EquippedBoosts = self:CopyEquippedBoosts(player),
        Treadmill = self:CopyTreadmillData(player),
        Fence = self:CopyFenceData(player),
        PackLuck = self:CopyPackLuck(player),
		DiscoveredItems = discoveredItems,
		PedestalItem = savedPedestalItem,
		SavedAt = os.time(),
	}
end

function PlayerDataService:Save(player, reason, forceSave, finalization)
	local closing = self.Finalizing and self.Finalizing[player]
	if closing and closing ~= finalization then return false end
	if not self.Loaded[player] or not self.CanSave[player] or self.Saving[player] then return false end
	if not forceSave and not self.Dirty[player] then return true end
	local expectedHead = self.SaveHeads[player]
	if not expectedHead then return false end
	local saveData = self:_buildSaveData(player)
	saveData.SeedSaveCommitId = HttpService:GenerateGUID(false)
	local revisionAtStart = self.Revision[player] or 0
	-- R114: remembered so quick garden saves keep to one write per ~7 s per player (DataStore allows one per 6 s per key).
	self.LastSaveAt = self.LastSaveAt or setmetatable({}, { __mode = "k" })
	self.LastSaveAt[player] = os.clock()
	self.Saving[player] = true
	local conflict = false
	local success, savedOrError = self:_runRequest(function()
		return self.Store:UpdateAsync(self:_getKey(player), function(current, keyInfo)
			-- Network retries may arrive after this very commit already succeeded.
			if type(current) == "table" and current.SeedSaveCommitId == saveData.SeedSaveCommitId then
				if keyInfo then return current, keyInfo:GetUserIds(), keyInfo:GetMetadata() end
				return current
			end
			if not sameSaveHead(expectedHead, getSaveHead(current)) then
				conflict = true
				return nil -- Cancel rather than overwrite a newer session.
			end
			local merged = type(current) == "table" and table.clone(current) or {}
			for key, value in pairs(saveData) do merged[key] = value end
			merged.PedestalItem = saveData.PedestalItem -- nil also clears a removed item.
			if keyInfo then return merged, keyInfo:GetUserIds(), keyInfo:GetMetadata() end
			return merged
		end)
	end)
	self.Saving[player] = nil
	if success and type(savedOrError) == "table"
		and savedOrError.SeedSaveCommitId == saveData.SeedSaveCommitId then
		self.SaveHeads[player] = getSaveHead(savedOrError)
		if (self.Revision[player] or 0) == revisionAtStart then self.Dirty[player] = false end
		if player.Parent then player:SetAttribute("LastDataSave", os.time()) end
		return true
	end
	self.Dirty[player] = true
	if conflict then
		self.CanSave[player] = false
		self.Loaded[player] = false
		player:SetAttribute("DataStatus", "SaveConflict")
		if player.Parent then
			player:Kick("Ur garden was updated in another server. Rejoin to load the newest save!")
		end
	end
	warn(string.format("[%s] Save did not complete for %s (%s): %s", self.Config.Version,
		player.Name, reason or "Unknown", conflict and "newer save protected" or tostring(savedOrError)))
	return false
end

function PlayerDataService:WaitForSave(player, maxSeconds)
	local deadline = os.clock() + (maxSeconds or 5)
	while self.Saving[player] and os.clock() < deadline do
		task.wait(0.1)
	end
end

-- One shared close operation owns the last snapshot. A slow in-flight request
-- must finish before that snapshot is taken; its timeout is not permission to
-- discard a newer revision. Shutdown applies its deadline around this operation.
function PlayerDataService:FinalizePlayer(player, reason)
	self.Finalizing = self.Finalizing or {}
	local closing = self.Finalizing[player]
	if closing then
		while not closing.Done do task.wait(0.1) end
		return closing.Saved
	end
	closing = {Done = false, Saved = false}
	self.Finalizing[player] = closing
	while self.Saving[player] do task.wait(0.1) end
	local okay, saved
	repeat
		okay, saved = pcall(self.Save, self, player, reason or "PlayerRemoving", true, closing)
		-- A previously started receipt/gift task may finish while UpdateAsync yields.
		-- Save its revision too before allowing the profile to be discarded.
	until not okay or saved ~= true or not self.Dirty[player]
	closing.Saved = okay and saved == true
	closing.Done = true
	if not okay then warn("[Player final save] "..tostring(saved)) end
	return closing.Saved
end

function PlayerDataService:StartAutosave()
	if self.AutosaveRunning then
		return
	end
	self.AutosaveRunning = true
	task.spawn(function()
		while self.AutosaveRunning do
			task.wait(self.Config.AutosaveInterval)
			for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
				if self.Dirty[player] and not self.Saving[player] then
					task.spawn(function()
						self:Save(player, "Autosave", false)
					end)
				end
			end
		end
	end)
end

function PlayerDataService:Shutdown(players)
	self.AutosaveRunning = false
	local closingPlayers, included = {}, {}
	for _, player in ipairs(players) do
		if not included[player] then included[player] = true; table.insert(closingPlayers, player) end
	end
	-- PlayerRemoving may already have removed a player from Players:GetPlayers().
	for player in pairs(self.Finalizing or {}) do
		if not included[player] then included[player] = true; table.insert(closingPlayers, player) end
	end
	local pending = #closingPlayers
	for _, player in ipairs(closingPlayers) do
		task.spawn(function()
			self:FinalizePlayer(player, "BindToClose")
			pending = pending - 1
		end)
	end

	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

function PlayerDataService:CleanupPlayer(player)
	local closing = self.Finalizing and self.Finalizing[player]
	if self.Saving[player] or (closing and not closing.Done) then return false end
	self:_disconnectStatLinks(player)
	if self.Finalizing then self.Finalizing[player] = nil end
	self.Loaded[player] = nil
	self.CanSave[player] = nil
	self.Dirty[player] = nil
	self.Saving[player] = nil
	self.SaveHeads[player] = nil
	self.Gardens[player] = nil
	self.GardenSaveQueued[player] = nil
	self.Revision[player] = nil
	self.ChestRecords[player] = nil
	self.OwnedBoosts[player] = nil
    self.TestBoosts[player] = nil;self.TestLuck[player] = nil
    self.EquippedBoosts[player] = nil
    self.Treadmills[player] = nil
    if self.Fences then self.Fences[player]=nil end
    if self.Premium then self.Premium[player]=nil end
	self.PedestalItems[player] = nil
	return true
end
-- All garden transactions run without yielding. Seed, plot, harvest and cash
-- changes enter the same profile snapshot; no separate crop DataStore exists.
local function gardenInteger(value, minimum, maximum)
	return type(value) == "number" and value == value and value % 1 == 0
		and value >= minimum and value <= maximum
end

local function gardenClone(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for key, item in pairs(value) do copy[key] = gardenClone(item) end
	return copy
end

function PlayerDataService:CopyGarden(garden)
	return gardenClone(garden or {Version = 7, Plots = {}, Harvests = {}})
end

function PlayerDataService:DecodeGarden(saved)
	if saved == nil then return self:CopyGarden(nil) end
	if type(saved) ~= "table" or (saved.Version ~= 1 and saved.Version ~= 2 and saved.Version ~= 3 and saved.Version ~= 4 and saved.Version ~= 5 and saved.Version ~= 6 and saved.Version ~= 7)
		or type(saved.Plots) ~= "table" or type(saved.Harvests) ~= "table" then
		return nil, "Unsupported garden structure"
	end
	-- Bound traversal before cloning unknown metadata; reject cycles/non-finite data.
	local visited, budget, stringBytes = {}, 100000, 0
	local function safe(value, depth)
		budget -= 1
		if budget < 0 or depth > 20 then return false end
		if type(value) == "number" then return self.Config.IsFiniteGardenNumber(value) end
		if type(value) == "string" then stringBytes += #value; return #value <= 10000 and stringBytes <= 2500000 end
		if type(value) ~= "table" then return value == nil or type(value) == "boolean" end
		if visited[value] then return false end
		visited[value] = true
		for key, item in pairs(value) do
			if (type(key) ~= "string" and type(key) ~= "number") or not safe(key, depth + 1)
				or not safe(item, depth + 1) then return false end
		end
		visited[value] = nil
		return true
	end
	if not safe(saved, 0) then return nil, "Unsafe garden data; original save retained" end
	if not require(game:GetService('ReplicatedStorage').SaleReceiptRules).Valid(saved.PendingSales)then return nil,'Invalid pending sale receipts; original save retained'end
	local copy, identities = self:CopyGarden(saved), {}
	local function validCrop(crop)
		if type(crop) ~= "table" or type(crop.Id) ~= "string" or #crop.Id < 1 or #crop.Id > 100
			or identities[crop.Id] or type(crop.SeedId) ~= "string" or #crop.SeedId > 80 or #crop.SeedId < 1
			or not gardenInteger(crop.PlantedAt, 0, 7258118400)
			or not gardenInteger(crop.ReadyAt, crop.PlantedAt + 1, 7258118400)
			or not gardenInteger(crop.Value, 1, 9000000000000) then return false end
		identities[crop.Id] = true
		return true
	end
	local function dense(array, cap)
		if type(array) ~= "table" then return false end
		local count = 0
		for index in pairs(array) do
			count += 1
			if not gardenInteger(index, 1, #array) or count > cap then return false end
		end
		return count == #array
	end
	for slot, contents in pairs(copy.Plots) do
		local number = type(slot) == "string" and tonumber(slot)
        local limit = saved.Version < 3 and 4 or self.Config.GardenPlotCount
        if not number or not gardenInteger(number,1,limit) or tostring(number) ~= slot then return nil, "Invalid bed key" end
		local crops
		if saved.Version == 1 then
			if not validCrop(contents) then return nil, "Invalid or duplicate V1 crop" end
			-- V1 had exactly one center crop. All original fields are retained.
			contents.OffsetX, contents.OffsetZ = 0, 0
			crops = {contents}
		else
            local width, depth
            if saved.Version < 3 then width, depth = 16, 18
            elseif saved.Version < 5 then width, depth = self.Config.GetLegacyGardenBedSize(number)
            elseif saved.Version < 6 then width, depth = self.Config.GetLegacyV080GardenBedSize(number)
            else width, depth = self.Config.GetGardenBedSize(number) end
            local storageBound = saved.Version < 4 and 6 or self.Config.GardenStorageBound(width, depth)
            if not dense(contents, storageBound) then return nil, "Sparse or geometrically impossible bed" end
			crops = contents
			local checked = {}
			for _, crop in ipairs(crops) do
				if not validCrop(crop) then return nil, "Invalid or duplicate V2 crop" end
                local width, depth
                if saved.Version < 3 then width, depth = 16, 18
                elseif saved.Version < 5 then width, depth = self.Config.GetLegacyGardenBedSize(number)
                elseif saved.Version < 6 then width, depth = self.Config.GetLegacyV080GardenBedSize(number)
                else width, depth = self.Config.GetGardenBedSize(number) end
                local ok = self.Config.ValidateGardenPlacement(checked, crop.OffsetX, crop.OffsetZ,width,depth,saved.Version < 4 and 4.5 or nil)
				if not ok then return nil, "Invalid bounds or spacing; original save retained" end
				table.insert(checked, crop)
			end
		end
		copy.Plots[slot] = crops
	end
	if not dense(copy.Harvests, self.Config.MaxSavedHarvests) then return nil, "Sparse or over-capacity harvest bag" end
	for _, crop in ipairs(copy.Harvests) do
		if not validCrop(crop) or not gardenInteger(crop.HarvestedAt, crop.ReadyAt, 7258118400) then
			return nil, "Invalid or duplicate harvested crop"
		end
	end
	for slot=1,self.Config.GardenPlotCount do copy.Plots[tostring(slot)] = copy.Plots[tostring(slot)] or {} end
    for _, crops in pairs(copy.Plots) do for _, crop in ipairs(crops) do
        if saved.Version < 7 then PlantRules.Migrate(crop) end
        local def = self.Config.GardenPlants[crop.SeedId]
        if not PlantRules.ValidTraits(crop, def and def.FruitCount or 6) then return nil, "Invalid plant traits; original save retained" end
    end end
    for _, crop in ipairs(copy.Harvests) do
        if saved.Version < 7 then PlantRules.Migrate(crop) end
        local def = self.Config.GardenPlants[crop.SeedId]
        if not PlantRules.ValidTraits(crop, def and def.FruitCount or 6) then return nil, "Invalid harvest traits; original save retained" end
    end
    copy.Version = 7
	return copy -- unknown crop IDs/metadata remain stored; rendering uses a safe placeholder
end

function PlayerDataService:_gardenChanged(player)
	self:MarkDirty(player)
	player:SetAttribute("GardenRevision", (player:GetAttribute("GardenRevision") or 0) + 1)
end

function PlayerDataService:QueueGardenSave(player)
	if self.GardenSaveQueued[player] or not self.CanSave[player] then return end
	local ticket = {}
	self.GardenSaveQueued[player] = ticket
	local last = self.LastSaveAt and self.LastSaveAt[player]
	task.delay(math.max(2, last and 7 - (os.clock() - last) or 0), function()
		if self.GardenSaveQueued[player] ~= ticket then return end
		self.GardenSaveQueued[player] = nil
		if not player.Parent or not self:IsLoaded(player) or not self.CanSave[player] then return end
		if self.Saving[player] then self:QueueGardenSave(player); return end
		self:Save(player, "GardenTransaction", false)
	end)
end

-- Internal API; caller has independently resolved the player's base/soil/equipped Tool.
-- No engine, network or DataStore yield is allowed before the transaction commits.
function PlayerDataService:PlantSeed(player, slot, seedInventoryId, placement, now)
	if not self:IsLoaded(player) then return false, "YOUR DATA IS STILL LOADING" end
	if not gardenInteger(slot, 1, self.Config.GardenPlotCount) or type(seedInventoryId) ~= "string"
		or #seedInventoryId < 1 or #seedInventoryId > 100 or type(placement) ~= "table"
		or not gardenInteger(now, 0, 7258032000) then return false, "INVALID PLANT REQUEST" end
	local garden = self.Gardens[player]
	if not garden or garden.Version ~= self.Config.GardenSchemaVersion then return false, "GARDEN IS NOT READY" end
	local crops = garden.Plots[tostring(slot)] or {}
	local width, depth = self.Config.GetGardenBedSize(slot)
    local valid, reason = self.Config.ValidateGardenPlacement(crops, placement.OffsetX, placement.OffsetZ,width,depth)
	if not valid then return false, reason end
	local records, seed, seedIndex = self:GetChestRecords(player)
	for index, record in ipairs(records) do
		if record.Id == seedInventoryId then seed, seedIndex = record, index; break end
	end
	if not seed then return false, "THAT SEED IS NO LONGER IN YOUR INVENTORY" end
	if seed.Kind == "Pack" then return false, "OPEN THE PACK FIRST!" end
	local growing = self.Config.GardenPlants[seed.SeedId]
	if not growing then return false, "THIS SEED CANNOT BE PLANTED YET" end
	if not gardenInteger(growing.Seconds, 1, 86400) or not gardenInteger(growing.Value, 1, 9000000000000) then
		return false, "THIS SEED NEEDS A TUNING FIX"
	end
	local crop = PlantRules.NewCrop(seed, HttpService:GenerateGUID(false), growing, now, placement.OffsetX, placement.OffsetZ)
    require(game:GetService('ReplicatedStorage'):WaitForChild('GardenFenceRules')).ApplyPlant(crop,growing,self:GetFenceTier(player))
 require(game:GetService('ReplicatedStorage'):WaitForChild('GrowthBoostRules')).Apply(crop,player:GetAttribute('DoubleGrowthOwned')and 2 or 1,now)

	-- Both tables commit before revision signals or optional presentation work.
	table.insert(crops, crop)
	garden.Plots[tostring(slot)] = crops
	table.remove(records, seedIndex)
	self:MarkDirty(player)
	self:_notifySeedInventory(player)
	self:_gardenChanged(player)
	self:TutorialEvent(player,'Plant')
	self:QuestEvent(player,'Plant',1) -- R140 daily quest
	return true, gardenClone(crop)
end

function PlayerDataService:HarvestPlant(player, slot, expectedCropId, now, fruitIndex)
	if not self:IsLoaded(player) then return false, "YOUR DATA IS STILL LOADING" end
	if not gardenInteger(slot, 1, self.Config.GardenPlotCount) or type(expectedCropId) ~= "string"
		or #expectedCropId < 1 or #expectedCropId > 100
		or not gardenInteger(now, 0, 7258118400) then return false, "INVALID HARVEST REQUEST" end
	local garden = self.Gardens[player]
	local crops = garden and garden.Plots[tostring(slot)] or {}
	local crop, cropIndex
	for index, item in ipairs(crops) do
		if item.Id == expectedCropId then crop, cropIndex = item, index; break end
	end
	if not crop then return false, "THIS PLANT HAS CHANGED — TRY AGAIN" end
	if not self.Config.GardenPlants[crop.SeedId] then return false, "THIS PLANT NEEDS A NEWER UPDATE" end
	if now < crop.ReadyAt then return false, "YOUR PLANT IS STILL GROWING" end
	if #garden.Harvests >= self.Config.MaxSavedHarvests then return false, "HARVEST BAG FULL — SELL SOME HARVESTS FIRST" end
    local definition = self.Config.GardenPlants[crop.SeedId]
    fruitIndex = fruitIndex or PlantRules.NextFruit(crop, definition, now)
    if not gardenInteger(fruitIndex, 1, definition.FruitCount) or not PlantRules.FruitReady(crop, fruitIndex, now) then
        return false, "THAT FRUIT IS ALREADY PICKED!"
    end
    local trait = PlantRules.Fruit(crop, fruitIndex, definition)
    local harvest = gardenClone(crop)
    harvest.Id = HttpService:GenerateGUID(false)
    harvest.SourceCropId = crop.Id
    harvest.HarvestCycle = PlantRules.FruitCycle(crop, fruitIndex)
    harvest.ReadyAt = PlantRules.FruitReadyAt(crop, fruitIndex)
    harvest.FruitStates = nil
    harvest.HarvestedAt = now
    harvest.FruitIndex = fruitIndex
    harvest.PaidRandom = crop.PaidRandom==true
    harvest.FruitScale = trait.Scale
    harvest.Mutation = trait.Mutation
    harvest.Weather = trait.Weather;harvest.FruitWeather=nil
    harvest.Value = trait.Value
    table.insert(garden.Harvests, harvest)
    self:MarkAdultDiscovered(player,crop.SeedId)
    if PlantRules.FinishFruit(crop,definition,fruitIndex,now,self:GetFenceTier(player))then
     table.remove(crops,cropIndex)
     -- R151: this harvest removed the plant (a single-harvest plant, or the last fruit of one that does not regrow). GardenPlantRuntime reads this when it takes the
     -- plant's model out of the garden: the model stays for a beat, marked HarvestedBy / HarvestedIndex, so every client sees the fruit fly to the harvester (a shovel
     -- removal never comes through here).
     local marks=self.HarvestRemovals or{};self.HarvestRemovals=marks
     marks[crop.Id]={Index=fruitIndex,By=player.UserId,At=os.clock()}
     for id,mark in pairs(marks)do if os.clock()-mark.At>30 then marks[id]=nil end end
    end
	self:_gardenChanged(player)
	self:TutorialEvent(player,'Harvest')
	self:QuestEvent(player,'Harvest',1) -- R140 daily quest
	return true, gardenClone(harvest)
end

-- Receipt creation, crop removal, and claim debit/credit are non-yielding profile transactions.
function PlayerDataService:_prepareSale(player,amount)
 local garden=self.Gardens[player];if garden then garden.PendingSales=garden.PendingSales or{}end
 return self:CurrencyReceipt(player,math.ceil(amount),'Cash')
end
function PlayerDataService:GetPendingSales(player)
 local garden=self.Gardens[player];return gardenClone(garden and garden.PendingSales or{})
end
function PlayerDataService:CollectSaleCash(player,id,index)
 if not self:IsLoaded(player)then return {Success=false}end
 if type(id)~='string'or #id<1 or #id>100 or not gardenInteger(index,1,13)then return {Success=false}end
 local rules=require(game:GetService('ReplicatedStorage').SaleReceiptRules)
 local garden=self.Gardens[player];if not garden then return {Success=false}end
 for at,receipt in ipairs(garden.PendingSales or{})do if receipt.Id==id then
  if index>receipt.Count then return {Success=false}end
  if rules.Claimed(receipt,index)then return {Success=true,Amount=0}end
  local amount=rules.Share(receipt,index)
  local currency=receipt.Currency or 'Cash';local premium=self:GetPremium(player)
  local balance=currency=='Gems'and premium.Gems or self:GetCash(player)
  local limit=currency=='Gems'and require(game:GetService('ReplicatedStorage').MechCatalog).MaxGems or rules.MaxCash
  if balance+amount>limit then return {Success=false}end
  receipt.Claimed=bit32.bor(receipt.Claimed,bit32.lshift(1,index-1))
  if receipt.Claimed==2^receipt.Count-1 then table.remove(garden.PendingSales,at)end
  if currency=='Gems'then premium.Gems+=amount;self:PublishPremium(player)
  else self:GetOrCreateCashValue(player).Value+=amount;if amount>0 then self:TutorialEvent(player,'Cash')end end
  self:MarkDirty(player);self:QueueGardenSave(player)
  return {Success=true,Amount=amount,Currency=currency,Cash=self:GetCash(player),Gems=premium.Gems}
 end end
 -- A lost response may be retried after the final icon removed its receipt.
 return {Success=true,Amount=0}
end
function PlayerDataService:SellHarvest(player, harvestId)
	if not self:IsLoaded(player) then return false, "YOUR DATA IS STILL LOADING" end
	if type(harvestId) ~= "string" or #harvestId > 100 then return false, "INVALID HARVEST" end
	local garden = self.Gardens[player]
	for index, crop in ipairs(garden and garden.Harvests or {}) do
		if crop.Id == harvestId then
			if not self.Config.GardenPlants[crop.SeedId] then return false, "THIS HARVEST NEEDS A NEWER UPDATE" end
			-- R132: the Fruit of the Hour sells for its bonus (x1.5 to x3).
			local value=require(game:GetService('ReplicatedStorage').FruitOfHour).SaleValue(crop.SeedId,crop.Value,workspace:GetServerTimeNow())
			local receipt,reason=self:_prepareSale(player,value);if not receipt then return false,reason end
			table.remove(garden.Harvests, index)
			table.insert(garden.PendingSales,receipt)
			self:_gardenChanged(player)
			self:TutorialEvent(player,'Sell')
			self:QuestEvent(player,'Sell',1) -- R140 daily quest
			return true, value
		end
	end
	return false, "THAT HARVEST WAS ALREADY SOLD OR IS NOT YOURS"
end

function PlayerDataService:RemovePlant(player,slot,cropId)
 if not self:IsLoaded(player)then return false,'YOUR DATA IS STILL LOADING'end
 if not gardenInteger(slot,1,self.Config.GardenPlotCount)or type(cropId)~='string'or #cropId>100 then return false,'INVALID PLANT'end
 local garden=self.Gardens[player];local crops=garden and garden.Plots[tostring(slot)]or{}
 for index,crop in ipairs(crops)do if crop.Id==cropId then
  table.remove(crops,index);self:_gardenChanged(player);return true,gardenClone(crop)
 end end
 return false,'THIS PLANT HAS CHANGED — TRY AGAIN'
end
function PlayerDataService:SellAllHarvests(player)
 if not self:IsLoaded(player)then return false,'YOUR DATA IS STILL LOADING'end
 local garden=self.Gardens[player];local crops=garden and garden.Harvests or{}
 if #crops==0 then return false,'NO CROPS TO SELL YET!'end
 local total=0;local Hour=require(game:GetService('ReplicatedStorage').FruitOfHour);local now=workspace:GetServerTimeNow()
 for _,crop in ipairs(crops)do
  if not self.Config.GardenPlants[crop.SeedId]or not gardenInteger(crop.Value,1,9000000000000)then return false,'THIS HARVEST NEEDS A NEWER UPDATE'end
  total+=Hour.SaleValue(crop.SeedId,crop.Value,now) -- R132: Fruit of the Hour bonus
 end
 local receipt,reason=self:_prepareSale(player,total);if not receipt then return false,reason end
 local count=#crops;garden.Harvests={};table.insert(garden.PendingSales,receipt);self:_gardenChanged(player)
 self:TutorialEvent(player,'Sell')
 self:QuestEvent(player,'Sell',count) -- R140 daily quest (every fruit sold counts)
 return true,total,count
end

function PlayerDataService:GetGardenState(player, now)
	local result = {}
	local garden = self.Gardens[player]
	for slot = 1, self.Config.GardenPlotCount do
		local bed = {Slot = slot, Crops = {}, Count = 0, LimitMode = "Space"}
		for _, crop in ipairs(garden and garden.Plots[tostring(slot)] or {}) do
			local seed = self.Config.GetSeedById(crop.SeedId)
			local progress, stage, remaining = self.Config.GetGardenGrowth(crop, now)
			table.insert(bed.Crops, {CropId = crop.Id, SeedId = crop.SeedId,
				Name = seed and seed.Name:gsub(" Seed$", "") or "Unknown plant",
				Emoji = seed and seed.Emoji or "🌱", Progress = progress, Stage = stage,
				PlantScale=crop.PlantScale, SeedScale=crop.SeedScale, Mutation=crop.Mutation, Remaining = remaining, ReadyAt = crop.ReadyAt, OffsetX = crop.OffsetX, OffsetZ = crop.OffsetZ})
		end
		bed.Count = #bed.Crops
		table.insert(result, bed)
	end
	return result
end

function PlayerDataService:GetHarvestInventory(player)
	local garden, groups, result = self.Gardens[player], {}, {}
	for _, crop in ipairs(garden and garden.Harvests or {}) do
		local seed, stage = self.Config.GetSeedById(crop.SeedId)
		if seed then
			local mutation = PlantRules.Mutation(crop.Mutation)
            local fruitScale = crop.FruitScale or crop.PlantScale or 1
            local holo=require(game:GetService('ReplicatedStorage').HologramProjection)
            local fruitName=holo.Name(crop,crop.FruitIndex)or self.Config.GardenPlants[crop.SeedId].HarvestName
            local weather=Weather.Key(crop.Weather)
            local key = crop.SeedId..":"..crop.Value..":"..mutation..":"..weather..":"..fruitScale..(holo.Is(crop.SeedId)and(":"..holo.Form(crop,crop.FruitIndex))or'')
			local group = groups[key]
			if not group then
				-- R132: the list shows what it sells for now (Fruit of the Hour bonus included).
				local hourBonus=require(game:GetService('ReplicatedStorage').FruitOfHour).Multiplier(crop.SeedId,workspace:GetServerTimeNow())
				group = {SeedId = crop.SeedId, InventoryId = crop.Id, Count = 0, SellValue = math.floor(crop.Value*hourBonus+.5), HourMultiplier = hourBonus>1 and hourBonus or nil,
                    VisualCrop = {SourceCropId=crop.SourceCropId or crop.Id,FruitIndex=crop.FruitIndex or 1,HarvestCycle=crop.HarvestCycle or 0},
					Name = (weather~="None"and Weather.Display(weather).." "or"")..(mutation ~= "None" and mutation.." " or "")..fruitName, Mutation=mutation,Weather=weather,WeatherMultiplier=Weather.Traits[weather].Multiplier, FruitScale=fruitScale, Emoji = seed.Emoji, Stage = stage,
					Color = {R = seed.Color.R * 255, G = seed.Color.G * 255, B = seed.Color.B * 255}}
				groups[key] = group
				table.insert(result, group)
			end
			local def=self.Config.GardenPlants[crop.SeedId]
            group.FruitName=fruitName;group.BaseValue=def.Value
            group.MutationMultiplier=mutation=='Diamond'and 3 or mutation=='Gold'and 2 or 1
            group.SizeMultiplier=require(game:GetService('ReplicatedStorage').BalanceRules).SizeCash(fruitScale);group.CashMultiplier=crop.Value/def.Value
            group.Count = group.Count + 1
		end
	end
	table.sort(result, function(a, b)
		if a.Stage ~= b.Stage then return a.Stage < b.Stage end
		if a.SeedId ~= b.SeedId then return a.SeedId < b.SeedId end
		return a.SellValue < b.SellValue
	end)
	return result
end

-- V131: biome unlocks and machine level are independent of paid shop boosts.
function PlayerDataService:GetTreadmillData(player)
    if not self.Treadmills[player]then self.Treadmills[player]={Tier=1,Skin=1,Cleared={}}end
    return self.Treadmills[player]
end
function PlayerDataService:LoadTreadmillData(player,saved)
    local data={Tier=1,Skin=1,Cleared={}}
    local function level(v,max)
        if type(v)~='number'or v~=v or v==math.huge or v==-math.huge then return 1 end
        return math.clamp(math.floor(v),1,max)
    end
    if type(saved)=='table'then
        data.Tier=level(saved.Tier,#self.Config.TreadmillTiers);data.Skin=level(saved.Skin,data.Tier)
        if type(saved.Cleared)=='table'then
            for _,tier in ipairs(self.Config.TreadmillTiers)do
                if saved.Cleared[tostring(tier.Stage)]==true then data.Cleared[tostring(tier.Stage)]=true end
            end
        end
    else
        -- Previously banked inventory is evidence of escaping; never guess sold history.
        for _,record in ipairs(self:GetChestRecords(player))do
            for _,tier in ipairs(self.Config.TreadmillTiers)do
                if record.Stage==tier.Stage then data.Cleared[tostring(tier.Stage)]=true end
            end
        end
    end
    self.Treadmills[player]=data
    self:PublishTreadmillData(player)
end
function PlayerDataService:PublishTreadmillData(player)
    local data=self:GetTreadmillData(player)
    player:SetAttribute('TreadmillTier',data.Tier);player:SetAttribute('TreadmillSkin',data.Skin)
end
function PlayerDataService:MarkTreadmillBiome(player,stage)
    local data=self:GetTreadmillData(player)
    for _,tier in ipairs(self.Config.TreadmillTiers)do
        if tier.Stage==stage and not data.Cleared[tostring(stage)]then
            data.Cleared[tostring(stage)]=true;self:MarkDirty(player)
            player:SetAttribute('TreadmillUnlockRevision',(player:GetAttribute('TreadmillUnlockRevision')or 0)+1)
        end
    end
end
function PlayerDataService:CopyTreadmillData(player)
    local d=self:GetTreadmillData(player);local cleared={}
    for k,v in pairs(d.Cleared)do if v==true then cleared[k]=true end end
    return {Tier=d.Tier,Skin=d.Skin,Cleared=cleared}
end
function PlayerDataService:BuyTreadmill(player,expectedTier)
    if not self:IsLoaded(player)or not self.CanSave[player]then return false,'Ur save isn\'t ready yet!'end
    local d=self:GetTreadmillData(player)
    if expectedTier~=d.Tier+1 then return false,'The upgrade changed! Try again.'end
    local nextTier=self.Config.TreadmillTiers[expectedTier]
    if not nextTier then return false,'Fully upgraded!'end
    if not self:SpendCash(player,nextTier.Cost)then return false,'Not enough cash!'end
    -- Spend and level change do not yield; duplicate clicks cannot buy this level twice.
    d.Tier=expectedTier;d.Skin=expectedTier;self:PublishTreadmillData(player)
    self:MarkDirty(player);self:QueueGardenSave(player)
    return true,'Upgraded to '..nextTier.Name..'!'
end
function PlayerDataService:SelectTreadmillSkin(player,tier)
    if not self:IsLoaded(player)or not self.CanSave[player]then return false,'Ur save isn\'t ready yet!'end
    local d=self:GetTreadmillData(player)
    if type(tier)~='number'or tier~=math.floor(tier)or tier<1 or tier>d.Tier then return false,'That style is still locked!'end
    d.Skin=tier;self:PublishTreadmillData(player);self:MarkDirty(player);self:QueueGardenSave(player)
    return true,'Style changed! Ur training power stays the same.'
end

require(script.Parent.GardenFenceData).Install(PlayerDataService)
require(script.Parent.PackSizePityData).Install(PlayerDataService)
require(script.Parent.PremiumProgress).Attach(PlayerDataService)
require(script.Parent.TutorialProgress).Attach(PlayerDataService)
require(script.Parent.DailyProgress).Attach(PlayerDataService) -- R140: login rewards + daily quests
return PlayerDataService
