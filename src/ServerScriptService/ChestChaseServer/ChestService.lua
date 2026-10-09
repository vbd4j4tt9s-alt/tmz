-- V118: biome packs, atomic opening rewards, loose seeds and existing gardens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PackRules = require(ReplicatedStorage:WaitForChild("SeedPackRules"))
local PackVisuals = require(ReplicatedStorage:WaitForChild("SeedPackVisuals"))

local Weather=require(ReplicatedStorage.WeatherTraits);local FX=require(ReplicatedStorage.ItemEffectAnchor)
local PackShapes=require(ReplicatedStorage.PackShapes151) -- R151: each pack rolls one of six chip-bag shapes and keeps it for life (PlayerDataService.AddChest, RefreshWorldPack)
local VerityReasons=require(ReplicatedStorage.VerityConfig).Reasons -- R152: what Verity says when a hand-in is refused (ConvertVoidPack)
local ChestService = {}
ChestService.__index = ChestService

function ChestService.new(config, mapService, playerData, baseService, notifications)
	local self = setmetatable({}, ChestService)
	self.Config = config
	self.Map = mapService
	self.PlayerData = playerData
	self.Bases = baseService
	self.Notifications = notifications
	self.GardenPlots = {}
	self.Openings = {}
 local alerts=ReplicatedStorage:WaitForChild(config.RemoteFolderName):FindFirstChild('RarePackSpawn')or Instance.new('RemoteEvent');alerts.Name='RarePackSpawn';alerts.Parent=ReplicatedStorage:WaitForChild(config.RemoteFolderName);self.RarePackSpawn=alerts
	self.PackRandom = Random.new()
	self.GardenRequests = {}
	self.GardenRequestIds = {}
	self.GardenRenderKeys = {}
	local remotes = ReplicatedStorage:FindFirstChild(config.RemoteFolderName)
	assert(remotes, "BaseService must create the remote folder before ChestService")
	local previousCatalog = remotes:FindFirstChild("SeedCatalog")
	if previousCatalog then previousCatalog:Destroy() end
	local catalog = Instance.new("Folder")
	catalog.Name = "SeedCatalog"
	local count = 0
	for stage, definitions in ipairs(config.SeedCatalogByStage) do
        if config.StageSeedPools and config.StageSeedPools[stage] then continue end -- shared packs, not new seed types
		for index, seed in ipairs(definitions) do
            if PackRules.IsRetired(seed.Id) then continue end
			local entry = Instance.new("Folder")
			entry.Name = seed.Id
			entry:SetAttribute("SeedId", seed.Id)
			entry:SetAttribute("DisplayName", seed.Name)
			entry:SetAttribute("Emoji", seed.Emoji)
			entry:SetAttribute("Color", seed.Color)
            local rarity, style = PackRules.GetRarity(seed.Id)
            entry:SetAttribute("Rarity",rarity)
            entry:SetAttribute('BaseChance',require(ReplicatedStorage.SeedRarity153).Percent(seed.Id)) -- R153: the seed's one fixed chance (its home pack's), the same text everywhere
            entry:SetAttribute("RarityColor",style.Color)
			entry:SetAttribute("Stage", PackRules.ObtainableStage(seed.Id) or stage)
			entry:SetAttribute("SeedIndex", index)
			entry:SetAttribute("BiomeName", config.BiomeNames[PackRules.ObtainableStage(seed.Id) or stage])
            entry:SetAttribute("BiomeRank", config.BiomeRank[PackRules.ObtainableStage(seed.Id) or stage])
			local growing = config.GardenPlants[seed.Id]
			entry:SetAttribute("Plantable",growing~=nil)
			entry:SetAttribute("GrowSeconds", growing and growing.Seconds or 0)
			entry:SetAttribute("HarvestValue", growing and growing.Value or 0)
			entry.Parent = catalog
			count = count + 1
		end
	end
	catalog:SetAttribute("ExpectedCount", count)
	catalog:SetAttribute("Ready", true)
	catalog.Parent = remotes
	local gardenAction = remotes:FindFirstChild("GardenInteract") or Instance.new("RemoteFunction")
	assert(gardenAction:IsA("RemoteFunction"), "GardenInteract must be a RemoteFunction")
	gardenAction.Name = "GardenInteract"
	gardenAction.Parent = remotes
	self.GardenAction = gardenAction
	self.Remotes = remotes
	self:BuildArtLibrary()
	return self
end

function ChestService:_getToolContainers(player)
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

function ChestService:_createTool(seedRecord, backpack)
    if seedRecord.Kind == "Pack" then return self:_createPackTool(seedRecord,backpack) end
	if not backpack then
		return nil
	end

	local fallback = self.Config.GetSeedDefinition(
		seedRecord.Stage,
		seedRecord.ChestNumber
	)
	local canonical = self.Config.GetSeedById(seedRecord.SeedId) or fallback
	local seedName = canonical.Name
	local seedEmoji = canonical.Emoji

	local tool = Instance.new("Tool")
	tool.Name = (PackRules.MutationKey(seedRecord.PackMutation) ~= "None" and seedRecord.PackMutation.." " or "")..seedName
    local rarity = PackRules.GetRarity(canonical.Id)
    tool.ToolTip = rarity.." | "..(self.Config.GardenPlants[canonical.Id] and "Click or tap the soil to plant! Controller: RT" or "A seed to collect. Planting is coming soon!")
    tool:SetAttribute("Weather",Weather.Key(seedRecord.Weather))
    tool:SetAttribute("Mutation", PackRules.MutationKey(seedRecord.PackMutation))
    tool:SetAttribute("SeedScale",PackRules.SanitizeSeedScale(seedRecord.SeedScale))
    tool:SetAttribute("Rarity",rarity)
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true
	tool:SetAttribute("GardenSeed", true)
	tool:SetAttribute("SeedInventoryId", seedRecord.Id)
	tool:SetAttribute("SeedNumber", seedRecord.ChestNumber)
	tool:SetAttribute("SeedId", seedRecord.SeedId or fallback.Id)
	tool:SetAttribute("SeedName", seedName)
	tool:SetAttribute("SeedEmoji", seedEmoji)
	tool:SetAttribute("Stage", seedRecord.Stage)
	tool:SetAttribute("AccentColor", seedRecord.AccentColor or fallback.Color)

	-- Backpack seeds only need a handle. Build decoration only while equipped.
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.Transparency = 1
	handle.Anchored = false
	handle.Massless = true
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Parent = tool
	local packet
	tool.Equipped:Connect(function()
		if packet then packet:Destroy() end
		packet = self:BuildLooseSeed(tool:GetAttribute("SeedId"), handle.CFrame, tool, PackRules.SanitizeSeedScale(seedRecord.SeedScale), handle, seedRecord.PackMutation)
        FX.Set(packet,seedRecord.Weather,nil,seedRecord.SeedScale or 1,2*(seedRecord.SeedScale or 1))
	end)
	tool.Unequipped:Connect(function()
		if packet then packet:Destroy(); packet = nil end
	end)
	tool.Parent = backpack
	return tool
end

function ChestService:SyncTools(player)
	if not player.Parent or not self.PlayerData:IsLoaded(player) then return end
	local records = self.PlayerData:GetChestRecords(player)
	local recordsById = {}
	for _, seedRecord in ipairs(records) do
		recordsById[seedRecord.Id] = seedRecord
	end

	local containers, backpack = self:_getToolContainers(player)
	local foundIds = {}
	for _, container in ipairs(containers) do
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool")
				and (child:GetAttribute("GardenSeed")
					or child:GetAttribute("SecuredChest") or child:GetAttribute("SeedPackTool")) then
				local seedId = child:GetAttribute("SeedInventoryId")
					or child:GetAttribute("ChestInventoryId")
				if not seedId or not recordsById[seedId] or foundIds[seedId] then
					child:Destroy()
                elseif self.Openings[player] and self.Openings[player].Tool == child then
                    foundIds[seedId] = true -- committed reward waits for its presentation to finish
                elseif (recordsById[seedId].Kind == "Pack" and child:GetAttribute("SeedPackTool"))
                    or (recordsById[seedId].Kind ~= "Pack" and child:GetAttribute("GardenSeed")) then
					foundIds[seedId] = true
				else
					-- Replace legacy chest Tools with their seed representation.
					child:Destroy()
				end
			end
		end
	end

	for _, seedRecord in ipairs(records) do
		if not foundIds[seedRecord.Id] then
			self:_createTool(seedRecord, backpack)
		end
	end
end

function ChestService:OnCharacterAdded(player)
    self:_finishOpening(player,self.Openings[player])
	task.delay(0.25, function()
		if player.Parent then
			self:SyncTools(player)
		end
	end)
end

function ChestService:Bank(player, seed)
	local record, reason = self.PlayerData:AddChest(player, seed, {Luck=true}) -- R137: hidden pack-size pity
	if not record then return nil, reason end
	if seed.TestGrant == true then record.TestGrant = true end -- R151: a world pack an owner command spawned (a forced event) is a TEST pack: never announced when opened
	self.PlayerData:QuestEvent(player,'Steal',1) -- R140 daily quest: a pack stolen from the track and banked
	self:SyncTools(player)
	return record
end

function ChestService:Start()
    self:SelectBiomePacks()
	self:PrepareMythicBiomes()
	self:SkinWorldSeeds()
	self:StartGardens()
	-- Remove any old opening interaction that remains before the permanent map
	-- cleanup is run. The garden now owns planting and growth.
	for _, record in ipairs(self.Map.BaseRecords) do
		if record.OpenPrompt then
			record.OpenPrompt.Enabled = false
		end
	end
end

function ChestService:CleanupPlayer(player)
    self:_finishOpening(player,self.Openings[player],true)
	self.GardenRequests[player] = nil
	self.GardenRequestIds[player] = nil
	local base = self.Bases:GetPlayerBase(player)
	if base then self:RenderGarden(base, nil) end
end
-- V0.77 original native-part art. No external mesh, image or animation asset IDs.
local function artVector(values, scale)
	return Vector3.new(values[1], values[2], values[3]) * (scale or 1)
end

local function artWeld(root, part)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

function ChestService:BuildArtParts(specs, parent, origin, scale, anchored)
	local parts, names = {}, {}
	scale = scale or 1
	for _, spec in ipairs(specs) do
		local part = Instance.new(spec.k == "W" and "WedgePart" or "Part")
		part.Name = spec.n
		part.Size = artVector(spec.s, scale)
		part:SetAttribute("ArtSize", part.Size)
		local rotation = CFrame.Angles(math.rad(spec.r[1]), math.rad(spec.r[2]), math.rad(spec.r[3]))
		if spec.k == "C" then
			part.Shape = Enum.PartType.Cylinder
			part.Size = Vector3.new(spec.s[2], spec.s[1], spec.s[3]) * scale
			rotation = rotation * CFrame.Angles(0, 0, math.pi / 2)
		elseif spec.k == "B" then
			-- Keep the carrier cubic; explicit mesh scaling controls all three axes.
			-- This avoids relying on stretched Part.Shape=Ball rendering.
			part.Size = Vector3.new(1, 1, 1)
			local mesh = Instance.new("SpecialMesh")
			mesh.Name = "ShapeMesh"
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Scale = artVector(spec.s, scale)
			mesh.Parent = part
		end
		part.CFrame = origin * CFrame.new(artVector(spec.p, scale)) * rotation
		part.Color = Color3.fromRGB(spec.c[1], spec.c[2], spec.c[3])
		part.Material = Enum.Material[spec.m or "SmoothPlastic"]
		part.Anchored = anchored == true
		part.Massless = true
		part.Transparency = 0
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = parent
		table.insert(parts, part)
		names[spec.n] = part
	end
	return parts, names
end

function ChestService:BuildSeedPacket(_seedId, origin, parent, scale, weldRoot,stage,variantKey,seedScale,packSize,mutation,shape)
    return PackVisuals.Bag(origin,parent,scale,weldRoot,stage,variantKey,seedScale,packSize,mutation,nil,nil,shape) -- R151: shape = the pack's roll (nil = the default shape)
end
function ChestService:BuildLooseSeed(seedId,origin,parent,scale,weldRoot,mutation)
    local definition,_,index = self.Config.GetSeedById(seedId)
    assert(definition,"Unknown seed art: "..tostring(seedId))
    return PackVisuals.Seed(definition,index,origin,parent,scale,weldRoot,mutation)
end

-- Only explicitly audited, static owner-installed templates may override stages 2-4.
-- Stage 1 always uses the small disturbed-soil circle.
function ChestService:GetApprovedGardenTemplate(seedId, growthStage)
	if growthStage == 1 then return nil end
	local storage = game:GetService("ServerStorage")
	local folder = storage:FindFirstChild("ApprovedGardenAssets")
	local family = folder and folder:FindFirstChild(seedId)
	local template = family and family:FindFirstChild("Stage"..growthStage)
	if not template then return nil end
	self.GardenAssetChecks = self.GardenAssetChecks or {}
	if self.GardenAssetChecks[template] == false then return nil end
	-- Recheck admitted templates before every clone, so later script/package additions cannot bypass inspection.
	local ok, failure = pcall(function()
		assert(template:IsA("Model") and template:GetAttribute("Approved") == true
			and type(template:GetAttribute("AuditId")) == "string" and #template:GetAttribute("AuditId") > 0,
			"requires Model, Approved=true and an AuditId matching the release asset manifest")
		local allowed = {Model=true, Folder=true, Part=true, WedgePart=true, MeshPart=true, SurfaceAppearance=true}
		local children, count = template:GetDescendants(), 0
		assert(#children <= self.Config.GardenMaxPlantParts * 2, "too many descendants")
		local pivot = template:GetPivot()
		for _, child in ipairs(children) do
			assert(allowed[child.ClassName], "remove scripts, packages, loaders and non-static dependencies: "..child.ClassName)
			if child:IsA("BasePart") then
				count += 1
				assert(child.Transparency < 1, "hidden carrier not allowed")
				for _, x in ipairs({-0.5,0.5}) do for _, y in ipairs({-0.5,0.5}) do for _, z in ipairs({-0.5,0.5}) do
					local point = pivot:PointToObjectSpace(child.CFrame:PointToWorldSpace(Vector3.new(child.Size.X*x,child.Size.Y*y,child.Size.Z*z)))
					assert(point.X^2 + point.Z^2 <= self.Config.GardenCropRadius^2 and point.Y >= -0.1
						and point.Y <= self.Config.GardenMaxPlantHeight, "pivot/footprint/height outside approved crop envelope")
				end end end
			end
		end
		assert(count >= 1 and count <= self.Config.GardenMaxPlantParts, "invalid part count")
	end)
	self.GardenAssetChecks[template] = ok
	if not ok then warn("[V0.85] Garden asset rejected; native fallback active for "..seedId..": "..tostring(failure)) end
	return ok and template or nil
end

-- R153 (architecture review, item 2): BuildPlantAt, BuildGrowthModel and BuildArtLibrary are GardenPlantRuntime's. GardenPlantRuntime.Install
-- (the end of this file) puts them on ChestService as it loads, so the R85-era bodies that stood here never ran; they were removed. Read and edit
-- them in GardenPlantRuntime.lua (docs/proposals/R153/tests/test_live_methods153.luau checks which functions are live).

function ChestService:SelectBiomePacks()
    -- Keep all five authored spawn locations and their identity. Pickups are finite per cycle.
    local active={}
    for stage=1,self.Config.StageCount do
        local group=assert(self.Map.ChestGroupsByStage[stage],"Missing biome spawn group")
        assert(#group==PackRules.PacksPerBiome,"Each biome needs exactly five authored pack locations")
        for _,item in ipairs(group) do
            item.Kind="Pack";item.SeedId=nil;item.SeedName="Seed Pack";item.GuaranteedRarity=nil
            item.Available=false;item.Prompt.Enabled=false
            item.Model:SetAttribute("BiomeSeedPack",true)
            item.Model.ModelStreamingMode=Enum.ModelStreamingMode.Persistent
            item.Model:SetAttribute("SeedId",nil);item.Model:SetAttribute("SeedName","Seed Pack")
            for _,desc in ipairs(item.Model:GetDescendants()) do
                if desc:IsA("BasePart") then
                    desc.Transparency=1;desc.CanCollide=false;desc.CanTouch=false;desc.CanQuery=false
                    item.PartState[desc]={Transparency=1,CanCollide=false}
                elseif desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") or desc:IsA("PointLight") then desc.Enabled=false end
            end
            table.insert(active,item)
        end
        self.Map.ChestsByStage[stage]=group[math.ceil(#group/2)]
    end
    self.Map.Chests=active
end
function ChestService:SetWorldPackAvailable(seed,available)
    seed.Available=available==true
    seed.Prompt.Enabled=seed.Available and not self.Map.Refreshing
    seed.Model:SetAttribute("PackAvailable",seed.Available)
    local packet=seed.Model:FindFirstChild("SeedPacket")
    if packet then
        local visible=seed.Available and not self.Map.Refreshing
        packet:SetAttribute("PackVisible",visible)
        for _,part in ipairs(packet:GetDescendants()) do
            if part:IsA("BasePart") then
                local original=part:GetAttribute("PackTransparency")
                if original==nil then original=part.Transparency;part:SetAttribute("PackTransparency",original) end
                part.Transparency=visible and original or 1
            elseif part:IsA("PointLight") or part:IsA("ParticleEmitter") then part.Enabled=false end
        end
    end
end
-- Conservatively enclose every camera-facing rotation, decorations and hover sway.
function ChestService:GetPackBounds(stage,variant,multiplier)
    local size=PackRules.SanitizePackSize(multiplier)
    local bounds=PackVisuals.Bounds(stage,variant,size)
    bounds.Radius=math.max(bounds.Radius,PackVisuals.PlatformDimensions(stage,variant,size).Radius)
    return bounds
end
function ChestService:GetPackPickupPosition(prompt,fallback)
    local parent=prompt and prompt.Parent
    if parent and parent:IsA('Attachment')then return parent.WorldPosition end
    return fallback
end
function ChestService:_maximumPackRadius(stage)
    self.PackMaxRadii=self.PackMaxRadii or {}
    if not self.PackMaxRadii[stage]then
        local radius=0
        for _,variant in ipairs(PackRules.VariantOrder)do radius=math.max(radius,self:GetPackBounds(stage,variant,PackRules.MaxPackSize).Radius)end
        self.PackMaxRadii[stage]=radius
    end
    return self.PackMaxRadii[stage]
end
function ChestService:_packSceneryIndex()
    if self.PackSceneryIndex then return self.PackSceneryIndex end
    local grid,wide={},{}
    local skip={self.Map.ChestsFolder,self.Map.RuntimeFolder}
    for _,keeper in pairs(self.Map.GuardiansByStage or {})do table.insert(skip,keeper)end
    for _,part in ipairs(self.Map.MapRoot:GetDescendants())do
        if not part:IsA('BasePart')or part.Transparency>=.98 then continue end
        local ignored=false
        for _,folder in ipairs(skip)do if folder and part:IsDescendantOf(folder)then ignored=true;break end end
        if ignored then continue end
        local cf,half=part.CFrame,part.Size*.5
        local x,y,z=cf.RightVector,cf.UpVector,cf.LookVector
        local extent=Vector3.new(math.abs(x.X)*half.X+math.abs(y.X)*half.Y+math.abs(z.X)*half.Z,
            math.abs(x.Y)*half.X+math.abs(y.Y)*half.Y+math.abs(z.Y)*half.Z,
            math.abs(x.Z)*half.X+math.abs(y.Z)*half.Y+math.abs(z.Z)*half.Z)
        local entry={Part=part,Low=cf.Position-extent,High=cf.Position+extent}
        local lx,hx=math.floor(entry.Low.X/32),math.floor(entry.High.X/32)
        local lz,hz=math.floor(entry.Low.Z/32),math.floor(entry.High.Z/32)
        if (hx-lx+1)*(hz-lz+1)>64 then table.insert(wide,entry)
        else for gx=lx,hx do for gz=lz,hz do
            local key=gx..':'..gz;grid[key]=grid[key]or {};table.insert(grid[key],entry)
        end end end
    end
    self.PackSceneryIndex={Grid=grid,Wide=wide};return self.PackSceneryIndex
end
function ChestService:_packSceneryClear(point,bounds,platform)
    local index=self:_packSceneryIndex();local r=bounds.Radius+.35
    local low=point+Vector3.new(-r,bounds.MinY-(platform and .58 or 0),-r);local high=point+Vector3.new(r,bounds.MaxY+.3,r)
    local seen={}
    local function blocked(list)
        for _,e in ipairs(list or {})do
            if not seen[e]and e.Part.Parent then
                seen[e]=true
                if low.X<e.High.X and high.X>e.Low.X and low.Y<e.High.Y and high.Y>e.Low.Y and low.Z<e.High.Z and high.Z>e.Low.Z then return true end
            end
        end
        return false
    end
    if blocked(index.Wide)then return false end
    for x=math.floor(low.X/32),math.floor(high.X/32)do for z=math.floor(low.Z/32),math.floor(high.Z/32)do
        if blocked(index.Grid[x..':'..z])then return false end
    end end
    return true
end
function ChestService:_packGround(stage)
    self.PackGrounds=self.PackGrounds or {}
    if self.PackGrounds[stage]and self.PackGrounds[stage].Parent then return self.PackGrounds[stage]end
    local obby=self.Map.MapRoot:FindFirstChild('Obby')
    local biomes=obby and obby:FindFirstChild('Biomes')
    if biomes then for _,biome in ipairs(biomes:GetChildren())do
        if tonumber(biome.Name:match('^Biome_(%d+)_'))==stage then
            local ground=biome:FindFirstChild('BiomeGround_'..stage,true)
            if ground and ground:IsA('BasePart')then self.PackGrounds[stage]=ground;return ground end
        end
    end end
end
function ChestService:FindPackPlacement(preferred,stage,variant,size,ownSlot,drops)
    local bounds=self:GetPackBounds(stage,variant,size)
    if ownSlot and not drops then
        local ground=self:_packGround(stage)
        -- User-approved scenery clipping: never shrink or discard a rolled pack.
        if ground then return CFrame.new(preferred.X,ground.Position.Y+ground.Size.Y/2+.6-bounds.MinY,preferred.Z),bounds end
    end
    local excluded={self.Map.ChestsFolder,self.Map.RuntimeFolder}
    for _,player in ipairs(game:GetService('Players'):GetPlayers())do if player.Character then table.insert(excluded,player.Character)end end
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances=excluded;params.RespectCanCollide=true
    local hit=workspace:Raycast(preferred+Vector3.new(0,30,0),Vector3.new(0,-100,0),params)
    if hit and hit.Normal.Y>.7 then return CFrame.new(preferred.X,hit.Position.Y+.6-bounds.MinY,preferred.Z),bounds end
    return nil
end

-- rolledSize (R137): the size SkinWorldSeeds already rolled for this spot (after the hidden track pity); it is an
-- ordinary roll, unlike testSize, so alerts and odds treat it as natural.
-- rolledShape (R151): the chip-bag shape SkinWorldSeeds rolled for this spot (its pair is baked ahead of the refresh); a spawn without one (a forced test pack) rolls its own.
-- deferred (R153 perf, lag audit D9; SkinWorldSeedsStep only): a list. The pack is built but left hidden and unavailable, and the rest - made
-- available, the weather roll, the rare-pack alert - is added to the list, for the reopening (SkinWorldSeeds) to run in the same frame and order as before.
function ChestService:RefreshWorldPack(seed,forcedVariant,testSize,testMutation,spawnOdds,rolledSize,rolledShape,deferred)
    seed.Prompt.MaxActivationDistance=24;seed.Prompt.RequiresLineOfSight=false
    PackShapes.Unpin(seed) -- the slot's previous pack is gone
    seed.Weather='None';seed.WeatherCheckedEvent=nil;seed.Model:SetAttribute('WeatherTrait','None')
    local variant=forcedVariant or PackRules.RollVariant(self.PackRandom:NextNumber())
    local size=testSize and PackRules.SanitizePackSize(testSize)or rolledSize and PackRules.SanitizePackSize(rolledSize)or PackRules.RollPackSize(self.PackRandom:NextNumber())
    local mutation=testMutation and PackRules.MutationKey(testMutation)or PackRules.RollMutation(self.PackRandom:NextNumber())
    seed.PackHome=seed.PackHome or seed.Body.Position
    -- Keep the rolled size: search forward into clear ground instead of shrinking it.
    local frame,bounds=self:FindPackPlacement(seed.PackHome,seed.Stage,variant,size,seed)
    local seedScale=PackRules.NewSeedScale(seed.Stage,variant,size)
    -- R151: the pack's chip-bag shape, rolled once, kept for life. A pack that takes none (the Void, the Mech) has nil; a pack whose pair is not baked yet keeps the
    -- default shape for life (0; Settle), so it never changes shape between the ground, the carry, a drop and the Bag. The seed table carries it (the carry clones it).
    local shape
    if PackShapes.Applies(variant)then
        local design=PackRules.DesignKey(seed.Stage,variant)
        shape=PackShapes.Settle(design,rolledShape~=nil and rolledShape or PackShapes.Roll(variant))
        if shape==nil then shape=0 end -- (variations off: this pack is the default shape, also after they are switched on again)
    end
    if not frame then
        seed.Generation=(seed.Generation or 0)+1
        self:SetWorldPackAvailable(seed,false)
        local oldPlatform=seed.Model:FindFirstChild('PackPlatform');if oldPlatform then oldPlatform:Destroy()end
        warn('[V129] No clear pack space at '..seed.Model.Name..'; slot stays empty this refresh.')
        return
    end
    -- Carry/drop records are independent copies; commit only after the complete visual is ready.
    local packet=self:BuildSeedPacket(nil,frame,nil,nil,nil,seed.Stage,variant,seedScale,size,mutation,shape)
    local platform=PackVisuals.Platform(frame,seed.Stage,variant,size)
    packet:SetAttribute("PackVisible",not self.Map.Refreshing)
    local oldPlatform=seed.Model:FindFirstChild('PackPlatform')
    if oldPlatform then oldPlatform:Destroy()end
    platform.Parent=seed.Model
    local old=seed.Model:FindFirstChild("SeedPacket")
    if old then old:Destroy() end
    packet.Parent=seed.Model
    seed.Body.CFrame=frame
    seed.PackPosition=frame.Position;seed.PackRadius=bounds.Radius
    seed.PackSize=size;seed.PackMutation=mutation
    seed.PackShape=shape -- R151
    if shape and shape>0 then PackShapes.Pin(seed,PackRules.DesignKey(seed.Stage,variant),shape) end -- its pair stays baked while this pack can be stolen, dropped and carried
    seed.BagVariant=variant;seed.SeedScale=seedScale;seed.OddsVersion=PackRules.OddsVersion
    seed.Generation=(seed.Generation or 0)+1
    seed.Model:SetAttribute("SeedArtVersion",123)
    seed.Model:SetAttribute("BagVariant",variant);seed.Model:SetAttribute("SeedScale",seedScale)
    seed.Model:SetAttribute('PackSize',size);seed.Model:SetAttribute('PackMutation',mutation);seed.Model:SetAttribute('PackShape',shape)
    -- The interaction sits at the reachable near edge, even on a ten-times pack.
    local promptAnchor=seed.Body:FindFirstChild('PackPickupPoint')or Instance.new('Attachment')
    promptAnchor.Name='PackPickupPoint'
    promptAnchor.CFrame=CFrame.new(0,bounds.MinY+1.5,size>10 and 0 or -bounds.Radius*.82)
    promptAnchor.Parent=seed.Body
    seed.Prompt.Parent=promptAnchor
    seed.Billboard.Enabled=false
    seed.Glow.Enabled=false
    seed.Prompt.ActionText='STEAL';seed.Prompt.ObjectText=''
    local function finish()
    self:SetWorldPackAvailable(seed,true)
    local weatherProbability=1
    if self.Weather and not seed.EventKeeper then
        local kind,event=self.Weather:State(workspace:GetServerTimeNow())
        if Weather.Events[kind]then self.Weather:ApplyPack(seed,kind,event);weatherProbability=Weather.Key(seed.Weather)=='None'and(1-Weather.PackChance)or Weather.PackChance end
    end
    local odds={TierProbability=spawnOdds or(forcedVariant and 1 or nil),ForcedSize=testSize~=nil,ForcedMutation=testMutation~=nil,Weather=seed.Weather,WeatherProbability=weatherProbability}
    local alert=require(ReplicatedStorage.RarePackRules).Message(seed.Stage,variant,size,mutation,odds)
    if alert and not seed.EventKeeper then alert.SpawnId=seed.Model.Name..':'..seed.Generation;alert.At=workspace:GetServerTimeNow();self.RarePackSpawn:FireAllClients(alert)end
    end
    if deferred then self:SetWorldPackAvailable(seed,false);table.insert(deferred,finish)else finish()end
end
-- R151: the plan of one refresh: every spot's tier, size (after the hidden track pity) and chip-bag shape. The NEXT refresh's plan is made right after this one is
-- applied and the pairs of its shapes are asked for at once, so they are baked long before the refresh (5 minutes, the closure is 10 s); a spawn whose pair is still
-- not baked keeps the default shape for life (PackShapes.Settle). The first refresh of a server has no earlier plan: its packs are the default shape.
function ChestService:PlanWorldPacks(cycle)
    local variants={}
    for i in ipairs(self.Map.Chests)do variants[i]=PackRules.RollVariant(self.PackRandom:NextNumber())end
    variants=require(ReplicatedStorage.PackSchedule81).Plan(cycle or 0,variants,function(a,b)return self.PackRandom:NextInteger(a,b)end)
    local odds=require(ReplicatedStorage.RarePackRules).TierProbabilities(cycle or 0,#variants)
    -- R137: every spot's size is rolled first so the hidden track pity (PackSizePity) can make one random spot big
    -- after a dry spell. Its counters move with the packs that actually spawned.
    local Pity=require(ReplicatedStorage.PackSizePity)
    local sizes={};for i in ipairs(self.Map.Chests)do sizes[i]=PackRules.RollPackSize(self.PackRandom:NextNumber())end
    sizes=Pity.PlanTrack(self.TrackLuck,sizes,function()return self.PackRandom:NextNumber()end)
    local shapes,wanted={},{}
    for i,seed in ipairs(self.Map.Chests)do
        shapes[i]=PackShapes.Roll(variants[i])
        if shapes[i]then table.insert(wanted,{Key=PackRules.DesignKey(seed.Stage,variants[i]),Id=shapes[i]})end
    end
    pcall(PackShapes.Prefetch,wanted)
    return {Cycle=cycle or 0,Variants=variants,Odds=odds,Sizes=sizes,Shapes=shapes}
end
-- R153 perf (lag audit D9): the 35 world packs were all rebuilt in the one server frame the track reopens (a burst of new instances to replicate:
-- a hitch on every client every 5 minutes). Now the closed window's last SkinSpread seconds build them SkinPerStep a frame (SkinWorldSeedsStep;
-- they are hidden, their prompts off and they are unavailable while the map is refreshing), and the reopening finishes them: each is made
-- available, takes the weather and sends its rare-pack alert in the same frame and order as before. The plan, the rolls and their order are the same.
ChestService.SkinSpread,ChestService.SkinPerStep=2,2
function ChestService:SkinWorldSeedsStep(cycle,count)
    local job=self.SkinJob
    if job and job.Cycle~=(cycle or 0)then return true end
    if not job then
        local plan=self.WorldPlan
        self.WorldPlan=nil
        if not plan or plan.Cycle~=(cycle or 0)then plan=ChestService.PlanWorldPacks(self,cycle)end
        job={Cycle=cycle or 0,Plan=plan,Next=1,Finish={}};self.SkinJob=job
    end
    local plan,list=job.Plan,self.Map.Chests
    for _=1,count do
        local i=job.Next;local seed=list[i];if not seed then break end
        self:RefreshWorldPack(seed,plan.Variants[i],nil,nil,plan.Odds[plan.Variants[i]],plan.Sizes[i],plan.Shapes[i],job.Finish)
        job.Next=i+1
    end
    return job.Next>#list
end
-- (called when the track closes for a refresh: from SkinSpread seconds before it reopens, a few packs a frame until all are built or it reopens)
function ChestService:_spreadWorldSkins()
    local token={};self.SkinToken=token;self.SkinJob=nil
    local root=self.Map.MapRoot
    local endsAt=root and root:GetAttribute('BiomeRefreshEndsAt')
    if type(endsAt)~='number'then return end
    task.spawn(function()
        local wait=endsAt-ChestService.SkinSpread-workspace:GetServerTimeNow()
        if wait>0 then task.wait(wait)end
        local cycle=(root:GetAttribute('BiomeRefreshCycle')or 0)+1
        while self.SkinToken==token and self.Map.Refreshing do
            local ok,done=pcall(self.SkinWorldSeedsStep,self,cycle,ChestService.SkinPerStep)
            if not ok then warn('[R153] Pack re-skin left to the reopening: '..tostring(done))end
            if not ok or done then break end
            task.wait()
        end
    end)
end
function ChestService:SkinWorldSeeds(cycle)
    -- (R153 perf: the packs the closed window already built are finished first, in order; the rest are built and finished as before)
    local job=self.SkinJob;self.SkinJob=nil;self.SkinToken=nil
    local plan,from
    if job and job.Cycle==(cycle or 0)then plan,from=job.Plan,job.Next else
    plan=self.WorldPlan
    self.WorldPlan=nil
    if not plan or plan.Cycle~=(cycle or 0)then plan=ChestService.PlanWorldPacks(self,cycle)end
    from=1;job=nil
    end
    local variants,odds,sizes=plan.Variants,plan.Odds,plan.Sizes
    local Pity=require(ReplicatedStorage.PackSizePity)
    if job then for _,finish in ipairs(job.Finish)do finish()end end
    for i,seed in ipairs(self.Map.Chests)do if i>=from then self:RefreshWorldPack(seed,variants[i],nil,nil,odds[variants[i]],sizes[i],plan.Shapes[i])end end
    local biggest=0
    for _,seed in ipairs(self.Map.Chests)do
        if seed.Available and table.find(PackRules.VariantOrder,seed.BagVariant)then biggest=math.max(biggest,seed.PackSize or 1)end
    end
    self.TrackLuck=Pity.After(Pity.Track,self.TrackLuck,biggest)
    -- the next refresh's plan (its shapes' pairs are baked while this refresh's packs are on the track)
    local ok,upcoming=pcall(ChestService.PlanWorldPacks,self,(cycle or 0)+1)
    if ok then self.WorldPlan=upcoming end
end
function ChestService:SetWorldPacksClosed(closed)
    for _,seed in ipairs(self.Map.Chests) do self:SetWorldPackAvailable(seed,seed.Available) end
    if closed then pcall(self._spreadWorldSkins,self)else self.SkinToken=nil end -- R153 perf (D9)
end

function ChestService:DressGuardian(model, stage)
    return require(script.Parent.BeastModels).Dress(model, stage)
end

-- V0.77 encounter staging happens before seed prompts and guardian home capture.
function ChestService:PrepareMythicBiomes()
	local root = assert(self.Map.MapRoot, "Missing permanent map root")
	for stage, encounter in ipairs(self.Config.MythicEncounters) do
		local home = CFrame.new(artVector(encounter.Home)) * CFrame.Angles(0, math.rad(encounter.KeeperYaw or encounter.Yaw), 0)
		local guardian = assert(self.Map.GuardiansByStage[stage], "Missing biome keeper")
		guardian:PivotTo(home)
		guardian:SetAttribute("GuardianHomeCFrame", home)
		for _, descendant in ipairs(guardian:GetDescendants()) do
			if descendant:IsA("BillboardGui") or descendant:IsA("SurfaceGui") then descendant:Destroy() end
		end
		for _, seed in ipairs(self.Map.ChestGroupsByStage[stage]) do
			local position = artVector(encounter.Seeds[seed.SeedIndex])
            seed.PackHome=position;seed.PackPosition=nil;seed.PackRadius=nil
			-- Offset the model pivot by the desired Body transform; authored pivots may differ.
			local bodyTarget = CFrame.new(position) * CFrame.Angles(0, math.rad(encounter.Yaw), 0)
			seed.Model:PivotTo(bodyTarget * seed.Body.CFrame:Inverse() * seed.Model:GetPivot())
			seed.ClosedCFrame = seed.Hinge.CFrame
			seed.OpenCFrame = seed.Hinge.CFrame * CFrame.Angles(math.rad(70), 0, 0)
		end
	end
    -- V102: Studio owns scenery; deleted decorations stay deleted.
    if root:GetAttribute("SceneryOwnershipVersion") == 1 then return end
    if root:GetAttribute("SevenBiomesVersion") == 90 and root:FindFirstChild("MythicLandmarks") then return end
    if self.BiomeVisuals then
        local old = root:FindFirstChild("MythicLandmarks")
        if old and old:GetAttribute("ArtVersion") == self.BiomeVisuals.Version then return end
        local staged = self.BiomeVisuals.Build(self.Config)
        if old then old:Destroy() end
        staged.Parent = root
        return
    end
	local existing = root:FindFirstChild("MythicLandmarks")
	if existing and existing:GetAttribute("ArtVersion") == 77 then return end
	if existing then existing:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "MythicLandmarks"
	for stage, encounter in ipairs(self.Config.MythicEncounters) do
		local definition = self.Config.ArtModels.Landmarks[tostring(stage)]
		local model = Instance.new("Model")
		model.Name = "Biome"..stage.."_Landmark"
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		model:SetAttribute("Stage", stage)
		model:SetAttribute("LandmarkName", definition.Name)
		local origin = CFrame.new(artVector(encounter.Landmark)) * CFrame.Angles(0, math.rad(-encounter.Yaw), 0)
		local parts = self:BuildArtParts(definition.Parts, model, origin, 1, true)
		model.PrimaryPart = parts[1]
		model.Parent = folder
	end
	folder:SetAttribute("ArtVersion", 77)
	folder.Parent = root
end

local function gardenText(value, maxLength)
	return type(value) == "string" and #value > 0 and #value <= maxLength
end

function ChestService:_checkGardenInteraction(player)
	local base = self.Bases:GetPlayerBase(player)
	if not base or not self.Bases:IsOwner(player, base) then return nil, "RETURN TO YOUR OWN GARDEN" end
	if not self.PlayerData:IsLoaded(player) then return nil, "YOUR DATA IS STILL LOADING" end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return nil, "RETURN TO YOUR GARDEN FIRST" end
	if self.Bases.BusyChecker(player) or player:GetAttribute("GuardianRagdollActive")
		or self.Bases.TrainingSessions[player] or root.Anchored or humanoid.PlatformStand then
		return nil, "FINISH YOUR CURRENT ACTION FIRST"
	end
	return base, nil, root
end

-- Explicit V2 contract. No BaseId/PlotId/SeedId/value/quantity comes from the client.
-- Place: {RequestId, Character, Soil, Position, SeedInventoryId}
-- Harvest: {RequestId, Character, CropId, FruitIndex}
-- PlantTop: {RequestId, Character, CropId}; server derives the only permitted destination.
function ChestService:InteractGarden(player, action, payload)
	local function reject(message) return {Success = false, Message = message} end
	local now = os.clock()
	if now - (self.GardenRequests[player] or -math.huge) < self.Config.GardenPlacementCooldown then
		return reject("PLEASE WAIT A MOMENT")
	end
	self.GardenRequests[player] = now
	if (action ~= "Place" and action ~= "Harvest" and action ~= "PlantTop" and action ~= "Remove") or type(payload) ~= "table"
		or not gardenText(payload.RequestId, 80) then return reject("INVALID GARDEN REQUEST") end
	local allowed = action == "Place" and {RequestId=true, Character=true, Soil=true, Position=true, SeedInventoryId=true}
		or ((action == "PlantTop" or action == "Remove") and {RequestId=true, Character=true, CropId=true})
        or {RequestId=true, Character=true, CropId=true, FruitIndex=true}
	local count = 0
	for key in pairs(payload) do
		count += 1
		if count > 5 or not allowed[key] then return reject("INVALID GARDEN REQUEST") end
	end
	local base, reason, root = self:_checkGardenInteraction(player)
	if not base then return reject(reason) end
	if payload.Character ~= player.Character then return reject("YOUR CHARACTER CHANGED — TRY AGAIN") end
	local recent = self.GardenRequestIds[player]
	if not recent then recent = {}; self.GardenRequestIds[player] = recent end
	if table.find(recent, payload.RequestId) then return reject("THIS REQUEST WAS ALREADY HANDLED") end
	table.insert(recent, payload.RequestId)
	if #recent > 32 then table.remove(recent, 1) end
	local infos = self.GardenPlots[base.Index]
	if not infos then return reject("GARDEN IS NOT READY") end
	local slot, info, crop, point, placement, equippedId
	local garden = self.PlayerData.Gardens[player]
	if not garden or garden.Version ~= self.Config.GardenSchemaVersion then return reject("GARDEN IS NOT READY") end
	if action == "Place" then
		if typeof(payload.Position) ~= "Vector3" or not gardenText(payload.SeedInventoryId, 100) then
			return reject("EQUIP A SEED AND AIM AT YOUR SOIL")
		end
		point = payload.Position
		for _, v in ipairs({point.X, point.Y, point.Z}) do
			if not self.Config.IsFiniteGardenNumber(v) then return reject("INVALID PLANT POSITION") end
		end
		for index, item in ipairs(infos) do
			if payload.Soil == item.Part then slot, info = index, item; break end
		end
		if not info then return reject("PLANT ON SOIL IN YOUR OWN GARDEN") end
		local localPoint = info.Part.CFrame:PointToObjectSpace(point)
		if math.abs(localPoint.Y - info.Part.Size.Y / 2) > self.Config.GardenSurfaceTolerance then
			return reject("AIM AT THE TOP OF THE SOIL")
		end
		local valid, why = self.Config.ValidateGardenPlacement(garden.Plots[tostring(slot)] or {},
			localPoint.X, localPoint.Z, info.Part.Size.X, info.Part.Size.Z)
		if not valid then return reject(why) end
		point = info.Part.CFrame:PointToWorldSpace(Vector3.new(localPoint.X, info.Part.Size.Y / 2, localPoint.Z))
		placement = {OffsetX = localPoint.X, OffsetZ = localPoint.Z}
		for _, tool in ipairs(player.Character:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("GardenSeed") and tool.Enabled
				and tool:GetAttribute("SeedInventoryId") == payload.SeedInventoryId then
				equippedId = tool:GetAttribute("SeedInventoryId"); break
			end
		end
		if not equippedId then return reject("EQUIP THAT SEED BEFORE PLANTING") end
	else
		if not gardenText(payload.CropId, 100) then return reject("INVALID PLANT") end
		for index, item in ipairs(infos) do
			for _, candidate in ipairs(garden.Plots[tostring(index)] or {}) do
				if candidate.Id == payload.CropId then slot, info, crop = index, item, candidate; break end
			end
			if crop then break end
		end
		if not crop then return reject("THIS PLANT HAS CHANGED — TRY AGAIN") end
		if action == "PlantTop" then return self:TeleportGardenPlant(player, info, crop, root) end
        if action == "Remove" then
         local shovel=player.Character:FindFirstChildOfClass('Tool')
         if not shovel or not shovel:GetAttribute('GardenShovel')or not shovel.Enabled then return reject('EQUIP YOUR SHOVEL FIRST')end
         local def=self.Config.GardenPlants[crop.SeedId];local scale=crop.PlantScale or 1
         local at=info.Part.CFrame*CFrame.new(crop.OffsetX,info.Part.Size.Y/2,crop.OffsetZ)
         local q=at:PointToObjectSpace(root.Position)
         local closest=Vector3.new(math.clamp(q.X,-def.Radius*scale,def.Radius*scale),math.clamp(q.Y,0,def.Height*scale),math.clamp(q.Z,-def.Radius*scale,def.Radius*scale))
         if(q-closest).Magnitude>self.Config.GardenPlacementDistance then return reject('MOVE CLOSER TO THIS PLANT')end
         local okay,result=self.PlayerData:RemovePlant(player,slot,crop.Id)
         if not okay then return reject(result)end
         self.PlayerData:QueueGardenSave(player);local rendered,why=pcall(self.RenderGarden,self,base,player,slot)
         if not rendered then warn('[V149] Removed crop refresh: '..tostring(why))end
         return {Success=true,Message='Plant removed.',CropId=result.Id}
        end
		if payload.FruitIndex ~= nil and (type(payload.FruitIndex) ~= "number" or payload.FruitIndex % 1 ~= 0 or payload.FruitIndex < 1 or payload.FruitIndex > 6) then return reject("INVALID FRUIT") end
        point = self:GardenFruitPoint(info.Part, crop, payload.FruitIndex)
	end
	local distance = (root.Position - point).Magnitude
	local allowedDistance = action == "Place" and self.Config.GardenPlacementDistance or self:GardenFruitReach(crop, payload.FruitIndex)
	if not self.Config.IsFiniteGardenNumber(distance) or distance > allowedDistance then
		return reject("MOVE CLOSER TO THIS PLANTING SPOT")
	end
	if action == "Place" then
		-- Ray starts at the real character, not an arbitrary client camera position.
		local head = player.Character:FindFirstChild("Head")
		local origin = head and head:IsA("BasePart") and head.Position or root.Position
		local delta = point - origin
		if delta.Magnitude < 0.01 then return reject("STEP BACK AND AIM AT THE SOIL") end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {player.Character}
		params.IgnoreWater = true
		local hit = workspace:Raycast(origin, delta.Unit * (delta.Magnitude + 0.3), params)
		if not hit or hit.Instance ~= info.Part or (hit.Position - point).Magnitude > 0.25
			or hit.Normal:Dot(info.Part.CFrame.UpVector) < 0.95 then
			return reject("KEEP A CLEAR VIEW OF THE SOIL")
		end
	end
	local success, result
	if action == "Place" then
		success, result = self.PlayerData:PlantSeed(player, slot, equippedId, placement, os.time())
	else
		success, result = self.PlayerData:HarvestPlant(player, slot, crop.Id, os.time(), payload.FruitIndex)
	end
	if not success then return reject(result) end
	-- R151: a fruit picked by hand counts for the hub's BIGGEST FRUIT TODAY board (HubDisplayService.NoteHarvest; set by the main script). Owner test harvests (/test harvestall) do not come through here.
	if action == "Harvest" and self.HarvestHook then pcall(self.HarvestHook, player, result) end
	self.PlayerData:QueueGardenSave(player)
	local refreshed, failure = pcall(function()
		self:SyncTools(player)
		self:RenderGarden(base, player)
	end)
	if not refreshed then warn("[V0.85] Garden visual refresh will retry: "..tostring(failure)) end
	local seed = self.Config.GetSeedById(result.SeedId)
	local name = seed and seed.Name:gsub(" Seed$", "") or "Plant"
	return {Success = true, CropId = result.Id,
		Message = action == "Harvest" and (name.." harvested! Visit Sell to earn cash.") or (name.." planted!")}
end

-- R153 (architecture review, item 2): RenderGarden is GardenPlantRuntime's (installed at the end of this file; it renders only the slot it is
-- asked for). The older body that stood here never ran and was removed: read and edit GardenPlantRuntime.lua.

function ChestService:StartGardens()
	if self.GardensRunning then return end
	for _, base in ipairs(self.Map.BaseRecords) do
		local folder = base.Model:FindFirstChild("GardenPlots")
		assert(folder, "[V0.85] Missing GardenPlots in "..base.Model:GetFullName())
		local infos = {}
		self.GardenPlots[base.Index] = infos
		for slot = 1, self.Config.GardenPlotCount do
			local plot = folder:FindFirstChild("DirtPlot_"..slot)
			assert(plot and plot:IsA("BasePart"), "[V0.85] Missing DirtPlot_"..slot)
			local width,depth=self.Config.GetGardenBedSize(slot)
            assert(math.abs(plot.Size.X-width)<0.01 and math.abs(plot.Size.Z-depth)<0.01,
				"[V0.85] Soil size differs from saved-placement bounds; audit the map before play")
			for _, child in ipairs(plot:GetChildren()) do
				if child:GetAttribute("GardenGenerated") then child:Destroy() end
			end
			plot:SetAttribute("GardenSoil", true)
			plot:SetAttribute("GardenEdgePadding", self.Config.GardenPlotEdgePadding)
			plot:SetAttribute("GardenPlantSpacing", self.Config.GardenMinimumPlantSpacing)
			plot:SetAttribute("GardenPlantCapacity", nil)
            plot:SetAttribute("GardenPlantLimitMode", "Space")
			table.insert(infos, {Part = plot, Rendered = {}})
		end
		self:RenderGarden(base, self.Bases:GetOwner(base))
	end
	self.GardenAction:SetAttribute("ContractVersion", 2)
	self.GardenAction:SetAttribute("PlacementDistance", self.Config.GardenPlacementDistance)
	self.GardenAction:SetAttribute("PlacementCooldown", self.Config.GardenPlacementCooldown)
	self.GardenAction.OnServerInvoke = function(player, action, payload)
        if not require(script.Parent.SecurityGate).Allow(player,'GardenAction',action,payload)or not require(script.Parent.MovementGuard).Check(player)then return {Success=false,Message='Please try again.'}end
		return self:InteractGarden(player, action, payload)
	end
	self.GardensRunning = true
	task.spawn(function()
		while self.GardensRunning do
            local slots = self.Config.GardenPlotCount
            local interval = math.max(1/60, 1/math.max(1, #self.Map.BaseRecords*slots))
            for slot = 1, slots do
                for _, base in ipairs(self.Map.BaseRecords) do
                    task.wait(interval)
                    if not self.GardensRunning then return end
                    local ok, failure = pcall(function() self:RenderGarden(base, self.Bases:GetOwner(base), slot) end)
                    -- R114: a repeating failure is reported at most once every 30 s instead of every refresh.
                    if not ok and os.clock() >= (self.NextGardenWarn or 0) then
                        self.NextGardenWarn = os.clock() + 30
                        warn("[V149] Garden refresh: "..tostring(failure))
                    end
                end
            end
		end
	end)
	print("[V0.85] PASS - 10 widened connected beds per base, capped entrance posts, space-based planting at 3 studs, Garden V6 and independent harvests connected.")
end

function ChestService:IsOpening(player)
    local opening=self.Openings[player]
    return opening~=nil and opening.Committed==true
end
-- R147: the Verity NPC gives a Verity Pack for a Void Pack. id = the pack's inventory Id (the NPC passes the one the player
-- chose); without one, the Void Pack in the player's hand, else the first Void Pack in the bag. Returns the new record, or nil
-- and the reason with nothing changed. A pack whose opening is committed (the reveal is playing) is refused; an opening that
-- has only been started (held, clicks) is finished first, then the Tool is rebuilt for the new pack.
function ChestService:ConvertVoidPack(player, id)
	if not player or not self.PlayerData:IsLoaded(player) then return nil, VerityReasons.Loading end
	if id == nil then
		local character = player.Character
		if character then
			for _, child in ipairs(character:GetChildren()) do
				if child:IsA("Tool") and child:GetAttribute("SeedPackTool") and child:GetAttribute("BagVariant") == "EclipseReliquary" then
					local held = child:GetAttribute("SeedInventoryId")
					if self.PlayerData:CheckVoidPack(player, held) then id = held; break end
				end
			end
		end
		if id == nil then
			for _, record in ipairs(self.PlayerData:GetChestRecords(player)) do
				if record.Kind == "Pack" and record.BagVariant == "EclipseReliquary" and record.Stage == 7 then id = record.Id; break end
			end
		end
		if id == nil then return nil, VerityReasons.NoVoid end
	end
	local target, reason = self.PlayerData:CheckVoidPack(player, id)
	if not target then return nil, reason end
	local opening = self.Openings[player]
	if opening and opening.Tool and opening.Tool:GetAttribute("SeedInventoryId") == target.Id then
		if opening.Committed then return nil, VerityReasons.Opening end
		self:_finishOpening(player, opening)
	end
	local record, why = self.PlayerData:ConvertVoidPack(player, target.Id)
	if not record then return nil, why end
	self:SyncTools(player)
	return record
end
function ChestService:_finishOpening(player, opening, skipSync)
    if not opening or self.Openings[player] ~= opening then return end
    self.Openings[player]=nil
    for _,connection in ipairs(opening.Connections) do connection:Disconnect() end
    if opening.Bag then opening.Bag:Destroy() end
    if opening.Committed and opening.Tool.Parent then opening.Tool:Destroy() end
    if not skipSync then task.defer(function()
        if not player.Parent then return end
        self:SyncTools(player)
        local c=player.Character;local h=c and c:FindFirstChildOfClass('Humanoid');local backpack=player:FindFirstChildOfClass('Backpack')
        -- (R153: not when the player already holds something else: they chose it during the reveal, and this hand-off threw it back into the Backpack)
        if opening.Committed and opening.RewardId and c==opening.Character and h and h.Health>0 and not h.PlatformStand and not player:GetAttribute('GuardianRagdollActive')and backpack and not c:FindFirstChildOfClass('Tool')then
            for _,seed in ipairs(backpack:GetChildren())do
                if seed:IsA('Tool')and seed:GetAttribute('GardenSeed')and seed:GetAttribute('SeedInventoryId')==opening.RewardId then h:EquipTool(seed);break end
            end
        end
    end)end
end
function ChestService:_canOpenPack(player,tool)
    local character=player.Character
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    return self.PlayerData:IsLoaded(player) and tool.Parent==character and humanoid and humanoid.Health>0
        and not humanoid.PlatformStand and not player:GetAttribute("GuardianRagdollActive")
        and not player:GetAttribute("GuardianFlingActive") and not player:GetAttribute("ChestChaseSeedCarrying")
        and not player:GetAttribute("ChestChaseRunActive") and not player:GetAttribute("ChestChaseQueued")
end
-- R152 (hotbar reliability): two ways a pack the player equipped was thrown back into the Backpack although nothing was wrong:
--  * a quick unequip + re-equip while its chip-bag shape was loading starts a SECOND hold of the same pack; the first one to finish held it, the second saw
--    that opening and bounced the pack out of the hand (R151 known issue). A hold for the pack that is already held does nothing now.
--  * equipping pack B while pack A is in hand: if B.Equipped is handled before A.Unequipped has finished A's opening, B saw A's opening and bounced. An opening
--    that is not committed and whose pack is no longer in the hand is stale: it is finished here, then B is held. (Committed openings, whose reveal is playing, still win.)
-- Returns true when this pack is already the held one.
-- R153 (hotbar debug aid): a pack sent back says why on the tool (HoldRefused = reason@server time: the hotbar logs it, and says FINISH THAT FIRST! for busy, or
-- holds it after the reveal / the knock-down) and in a short per-player list /test hotbar prints; a hold that waited for its shape is listed too.
local function holdNote(self,player,text)
    self.HoldLog=self.HoldLog or setmetatable({},{__mode="k"});local list=self.HoldLog[player] or {};self.HoldLog[player]=list
    table.insert(list,("%.1f %s"):format(os.clock(),text));if #list>12 then table.remove(list,1) end
end
local function bounce(self,player,tool)
    local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local why=self.Openings[player] and "opening" or not self.PlayerData:IsLoaded(player) and "loading" or tool.Parent~=player.Character and "moved"
        or (player:GetAttribute("GuardianRagdollActive") or player:GetAttribute("GuardianFlingActive") or not h or h.Health<=0 or h.PlatformStand) and "knocked" or "busy"
    holdNote(self,player,tool.Name.." refused: "..why)
    local backpack=player:FindFirstChildOfClass("Backpack")
    if backpack and tool.Parent==player.Character then tool:SetAttribute("HoldRefused",why.."@"..("%.2f"):format(workspace:GetServerTimeNow()));tool.Parent=backpack end
end
local function settleHold(self,player,tool)
    local existing=self.Openings[player]
    if type(existing)~="table" then return false end
    if existing.Tool==tool and tool.Parent==player.Character then return true end
    if not existing.Committed and existing.Tool.Parent~=player.Character then ChestService._finishOpening(self,player,existing) end
    return false
end
function ChestService:_holdPack(player,tool)
    local record
    for _,candidate in ipairs(self.PlayerData:GetChestRecords(player))do if candidate.Id==tool:GetAttribute('SeedInventoryId')then record=candidate;break end end
    if record then
        -- R139 (owner): the free starter pack's 2x luck is secret, so its tooltip shows the plain pack odds.
        -- R154: the pack's real odds: the 80% rule (SeedPackRules) and the 4 Leaf Clover's x2 on the Void / Verity / Mech packs (PassLuck, the passes alone) too.
        local odds=PackRules.SeedOdds(self.Config,record.Stage,record.BagVariant,player:GetAttribute('ChestLuckMultiplier'),record.OddsVersion or 0,nil,self.PlayerData:PassLuck(player))
        -- R155 (owner): the pack pity. When this pack's open would be its group's lucky 10th, its odds are the lucky roll's (x1.5) and a line says so; the rule is listed with the odds.
        local lucky,before,after=nil,{},{}
        if self.PlayerData.PackPityTooltip then lucky,before,after=self.PlayerData:PackPityTooltip(player,record,function(luck,passLuck)return PackRules.SeedOdds(self.Config,record.Stage,record.BagVariant,luck,record.OddsVersion or 0,nil,passLuck)end)end
        if lucky then odds=lucky end
        local rows={PackRules.PackLabel(record.Stage,record.BagVariant,record.PackSize,record.PackMutation)}
        for _,line in ipairs(before)do table.insert(rows,line)end
        for _,seed in ipairs(PackRules.OddsRows(self.Config,record.Stage,record.BagVariant,odds))do -- R148: by rarity rank, then name
            table.insert(rows,seed.Name..': '..require(ReplicatedStorage.OddsText85).Format(odds[seed.Id]))
        end
        for _,line in ipairs(after)do table.insert(rows,line)end
        tool.ToolTip=table.concat(rows,'\n')
    end
    if settleHold(self,player,tool) then return end
    if self.Openings[player] or not self:_canOpenPack(player,tool) then bounce(self,player,tool);return end
    -- R151: a pack with a chip-bag shape is put in the hand once its (design, variation) pair is baked: a short bounded wait BEFORE anything of the opening exists (the
    -- checks run again after it), so the pack in the hand is the shape its picture shows. Past the wait it is built in the default shape this once (never yields).
    local shape=tool:GetAttribute("PackShape")
    if shape~=nil then
        local design=PackRules.DesignKey(tool:GetAttribute("Stage"),tool:GetAttribute("BagVariant"))
        local neutral=PackRules.VariantKey(tool:GetAttribute("BagVariant"))==require(ReplicatedStorage.VerityCatalog).Variant
        if PackShapes.State(design,shape,neutral)~="Ready" then
            local waited=os.clock();pcall(PackShapes.Await,design,shape,neutral);holdNote(self,player,("%s waited %.2f s for its shape"):format(tool.Name,os.clock()-waited))
            if settleHold(self,player,tool) then return end -- (R152: a second hold of this very pack began while this one waited)
            if self.Openings[player] or not self:_canOpenPack(player,tool) then bounce(self,player,tool);return end
        end
    end
    local opening={Tool=tool,Character=player.Character,Connections={},Committed=false,Clicks=0,LastClick=-math.huge}
    self.Openings[player]=opening
    local ok,err=xpcall(function()
        opening.Bag=PackVisuals.CarryBag(opening.Character,tool:GetAttribute("Stage"),tool:GetAttribute("BagVariant"),tool:GetAttribute("SeedScale"),tool:GetAttribute("PackSize"),tool:GetAttribute("PackMutation"),shape)
        assert(opening.Bag,"Character torso is not ready")
        FX.Set(opening.Bag,tool:GetAttribute("Weather"),nil,tool:GetAttribute("PackSize"),2*(tool:GetAttribute("PackSize")or 1));opening.Bag:SetAttribute("Weather",tool:GetAttribute("Weather"))
        opening.Bag:SetAttribute("PackClickCount",0)
        opening.Bag:SetAttribute("PackClicksRequired",PackRules.OpenClicks)
        local humanoid=opening.Character:FindFirstChildOfClass("Humanoid")
        table.insert(opening.Connections,humanoid.Died:Connect(function() self:_finishOpening(player,opening) end))
        table.insert(opening.Connections,player.CharacterRemoving:Connect(function(character)
            if character==opening.Character then self:_finishOpening(player,opening) end
        end))
        table.insert(opening.Connections,player:GetAttributeChangedSignal("GuardianRagdollActive"):Connect(function()
            if player:GetAttribute("GuardianRagdollActive") then self:_finishOpening(player,opening) end
        end))
        -- Equip only holds the sack. Tool.Activated is the sole opening path.
    end,debug.traceback)
    if not ok then self:_finishOpening(player,opening);warn("[V119] Sack carry recovered: "..tostring(err)) end
end
function ChestService:_activatePack(player,tool)
    local opening=self.Openings[player]
    if not opening or opening.Tool~=tool or opening.Committed or not tool.Enabled then return end
    if player.Character~=opening.Character or not self:_canOpenPack(player,tool) then
        self:_finishOpening(player,opening);return
    end
    local now=os.clock()
    if now-opening.LastClick<PackRules.ClickInterval then return end
    opening.LastClick=now;opening.Clicks+=1
    opening.Bag:SetAttribute("PackClickAt",workspace:GetServerTimeNow())
    opening.Bag:SetAttribute("PackClickCount",opening.Clicks)
    if opening.Clicks<PackRules.OpenClicks then return end
    local success,failure=xpcall(function()
        -- Atomic server-owned transaction: repeated clicks cannot reroll or duplicate.
        -- R112: a draw function, not one number: King odds reach 1 in 1T and are rolled in stages.
        local reward,reason=self.PlayerData:OpenSeedPack(player,tool:GetAttribute("SeedInventoryId"),function()return self.PackRandom:NextNumber()end)
        if not reward then
            self.Notifications:Show(player,reason,Color3.fromRGB(255,185,100),2,"Denied")
            self:_finishOpening(player,opening);return
        end
        opening.Committed=true;opening.RewardId=reward.Id;tool.Enabled=false
        opening.Bag:SetAttribute("RevealSeedId",reward.SeedId)
        opening.Bag:SetAttribute("SeedScale",reward.SeedScale)
        opening.Bag:SetAttribute("Rarity",reward.Rarity)
        opening.Bag:SetAttribute("Weather",reward.Weather)
        local duration=PackRules.GetRevealDuration(reward.Rarity)
        opening.Bag:SetAttribute("RevealDuration",duration)
        opening.Bag:SetAttribute("RevealAt",workspace:GetServerTimeNow())
        task.delay(duration,function() self:_finishOpening(player,opening) end)
    end,debug.traceback)
    if not success then
        self:_finishOpening(player,opening)
        warn("[V119] Sack opening presentation recovered: "..tostring(failure))
        self:SyncTools(player)
    end
end
function ChestService:_createPackTool(record,backpack)
    if not backpack then return nil end
    local player=backpack.Parent
    local tool=Instance.new("Tool")
    tool.Name=PackRules.PackLabel(record.Stage,record.BagVariant,record.PackSize,record.PackMutation)
    tool.ToolTip=PackRules.PackLabel(record.Stage,record.BagVariant,record.PackSize,record.PackMutation).." • Click / tap / RT 5 times to open"
    local okTest,expected=pcall(function()return require(script.Parent.RarePackTests).Expected(self.PlayerData,player,record.Id)end) -- R153: a broken owner test hook means "no test override", never a missing pack tool
    if not okTest then warn("[R153] RarePackTests.Expected failed (the pack tool is the normal one): "..tostring(expected));expected=nil end
    if expected then
        local rarity=PackRules.GetRarity(expected);tool.Name='TEST '..rarity..' Pack'
        tool.ToolTip='Guaranteed '..rarity..' reveal • Click / tap / RT 5 times to open'
    end
    tool.RequiresHandle=false;tool.CanBeDropped=false;tool.ManualActivationOnly=false;tool.Enabled=true
    tool:SetAttribute("SeedPackTool",true);tool:SetAttribute("SeedInventoryId",record.Id)
    tool:SetAttribute("PackNumber",record.ChestNumber) -- R139: above the player's PackSerialAtJoin = new this visit (hotbar rainbow)
    tool:SetAttribute("PackSize",PackRules.SanitizePackSize(record.PackSize));tool:SetAttribute("PackMutation",PackRules.MutationKey(record.PackMutation));tool:SetAttribute("Weather",Weather.Key(record.Weather))
    tool:SetAttribute("Stage",record.Stage)
    tool:SetAttribute("BagVariant",PackRules.VariantKey(record.BagVariant))
    tool:SetAttribute("SeedScale",PackRules.SanitizeSeedScale(record.SeedScale))
    local shape=PackShapes.Sanitize(record.PackShape);if shape>0 then tool:SetAttribute("PackShape",shape) end -- R151: the pack's own chip-bag shape (absent = the default: every record saved before it)
    tool.Equipped:Connect(function() self:_holdPack(player,tool) end)
    tool.Activated:Connect(function() self:_activatePack(player,tool) end)
    tool.Unequipped:Connect(function()
        local opening=self.Openings[player]
        if opening and opening.Tool==tool and not opening.Committed then self:_finishOpening(player,opening) end
    end)
    tool.Destroying:Connect(function()
        local opening=self.Openings[player]
        if opening and opening.Tool==tool then self:_finishOpening(player,opening) end
    end)
    tool.Parent=backpack
    return tool
end

require(script.Parent.GardenPlantRuntime).Install(ChestService)
require(script.Parent.HarvestToolService).Install(ChestService)
return ChestService
