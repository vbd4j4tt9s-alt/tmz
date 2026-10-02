-- V0.85 keeps the obby-free biome map compatible with legacy course bindings.
-- Binds the permanent map and owns course visibility/tween state.

local TweenService = game:GetService("TweenService")

local MapService = {}
MapService.__index = MapService

local function requireChild(config, parent, name, className)
	local child = parent:WaitForChild(name, 10)
	assert(child, string.format("[%s] Missing %s inside %s", config.Version, name, parent:GetFullName()))
	if className then
		assert(
			child:IsA(className),
			string.format("[%s] %s must be a %s", config.Version, child:GetFullName(), className)
		)
	end
	return child
end

local function getBillboardText(config, part)
	local billboard = requireChild(config, part, "Label", "BillboardGui")
	return requireChild(config, billboard, "Text", "TextLabel"), billboard
end

local function consumeTeleportMarker(economyHub, markerName, station)
	local marker = economyHub:FindFirstChild(markerName)
	if marker and marker:IsA("BasePart") then
		local markerCFrame = marker.CFrame
		marker:Destroy()
		return markerCFrame
	end

	local forwardDistance = math.max(station.Size.X, station.Size.Z) / 2 + 8
	local position = station.Position
		+ station.CFrame.LookVector * forwardDistance
		+ Vector3.new(0, 2, 0)
	return CFrame.new(position)
end

local function updateStationPresentation(station, prompt, title, subtitle)
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.ActionText = title
	prompt.ObjectText = subtitle
	for _, descendant in ipairs(station:GetDescendants()) do
		if descendant:IsA("TextLabel") then
			descendant.Text = string.format("%s\n%s", string.upper(title), string.upper(subtitle))
		end
	end
end

local function raiseMapBoundaries(mapRoot)
    local barriers=assert(mapRoot:FindFirstChild('InvisibleMapBarriersV071'),'Invisible map barriers missing')
    -- Run once after route/base alignment. Keep the ground edge and all entrances intact.
    for _,wall in ipairs(barriers:GetChildren())do
        if wall:IsA('BasePart')then
            local size=wall.Size;local height=math.max(size.Y,1024)
            local frame=wall.CFrame
            wall.Size=Vector3.new(size.X,height,size.Z)
            wall.CFrame=frame+Vector3.new(0,(height-size.Y)/2,0)
            wall.Anchored=true;wall.Transparency=1;wall.CanCollide=true
            wall.CanTouch=false;wall.CastShadow=false
        end
    end
end

function MapService.new(config)
	local self = setmetatable({}, MapService)
	self.Config = config
	self.CourseTweens = {}

	local mapRoot = workspace:WaitForChild(config.MapName, 15)
	assert(mapRoot, string.format("[%s] Workspace.%s was not found.", config.Version, config.MapName))
	assert(
		not mapRoot:GetAttribute("GameplayControllerActive"),
		string.format("[%s] Another gameplay controller is already active.", config.Version)
	)
	mapRoot:SetAttribute("GameplayControllerActive", true)
	self.MapRoot = mapRoot
    -- Build scenery before ChestService caches pack-placement obstacles.
    local art=require(script.Parent.BiomeVisuals)
    art.ApplyVolcanoV129(mapRoot)
    -- Do this before any seed, keeper, hazard or obstacle coordinate is cached.
    art.ApplyRoutesV134(mapRoot)
    art.ApplyRoutePolishV136(mapRoot)
    require(script.Parent.GardenBaseLayout).Apply(mapRoot)
    require(script.Parent.TrackExpansion83).Apply(mapRoot)
    require(script.Parent.ForestLayout87).Apply(mapRoot)
    require(script.Parent.RouteDress84).Apply(mapRoot)
    require(script.Parent.FloorSafety86).Apply(mapRoot)
    require(script.Parent.HideBushes124).Apply(mapRoot) -- R124: Forest/Jungle bushes big enough to hide in
    raiseMapBoundaries(mapRoot)


	local oldRuntime = mapRoot:FindFirstChild(config.RuntimeFolderName)
	if oldRuntime then
		oldRuntime:Destroy()
	end
	local runtimeFolder = Instance.new("Folder")
	runtimeFolder.Name = config.RuntimeFolderName
	runtimeFolder.Parent = mapRoot
	self.RuntimeFolder = runtimeFolder

	self.LobbyFolder = requireChild(config, mapRoot, "Lobby", "Folder")
	self.BasesFolder = requireChild(config, mapRoot, "Bases", "Folder")
	self.ObbyFolder = requireChild(config, mapRoot, "Obby", "Folder")
	-- The current map is a biome field; older places may still retain empty
	-- course folders, while newer edits may remove them entirely. Course state
	-- is therefore optional and binds only to parts that still exist.
	self.StagesFolder = self.ObbyFolder:FindFirstChild("Stages")
	if self.StagesFolder and not self.StagesFolder:IsA("Folder") then
		self.StagesFolder = nil
	end
	self.RoadsFolder = self.ObbyFolder:FindFirstChild("EscapeRoads")
	if self.RoadsFolder and not self.RoadsFolder:IsA("Folder") then
		self.RoadsFolder = nil
	end
	-- New maps use Seeds. Chests is accepted only long enough for the V0.66
	-- permanent installer and old saved places to migrate safely.
	self.SeedsFolder = mapRoot:FindFirstChild("Seeds")
		or mapRoot:FindFirstChild("Chests")
	assert(self.SeedsFolder and self.SeedsFolder:IsA("Folder"), string.format(
		"[%s] Workspace.%s needs a Seeds folder.",
		config.Version,
		config.MapName
		))
	self.ChestsFolder = self.SeedsFolder -- legacy server alias; never player-facing
	require(script.Parent.MarketLayout).Apply(mapRoot)
 require(game:GetService('ReplicatedStorage').WalkthroughProps90).Bind(mapRoot)
	self.EconomyHub = requireChild(config, mapRoot, "EconomyHub", "Folder")
	self.BuyStation = requireChild(config, self.EconomyHub, "BuyStation", "BasePart")
	self.SellStation = requireChild(config, self.EconomyHub, "SellStation", "BasePart")
	self.BuyPrompt = requireChild(config, self.BuyStation, "OpenBuyPrompt", "ProximityPrompt")
	self.SellPrompt = requireChild(config, self.SellStation, "OpenSellPrompt", "ProximityPrompt")
	self.BuyTeleportCFrame = consumeTeleportMarker(self.EconomyHub, "BuyTeleport", self.BuyStation)
	self.SellTeleportCFrame = consumeTeleportMarker(self.EconomyHub, "SellTeleport", self.SellStation)
	updateStationPresentation(self.BuyStation, self.BuyPrompt, "SHOP", "PICK A BOOST!")
	updateStationPresentation(self.SellStation, self.SellPrompt, "SELL", "SELL CROPS!")
 self.BuyPrompt.ActionText="MARKET";self.BuyPrompt.ObjectText="";self.BuyPrompt.HoldDuration=0
 self.BuyPrompt.RequiresLineOfSight=false;self.BuyPrompt.MaxActivationDistance=config.EconomyInteractionDistance
 self.SellPrompt.Enabled=false
 for _,station in ipairs({self.BuyStation,self.SellStation})do for _,gui in ipairs(station:GetChildren())do if gui:IsA("BillboardGui")or gui:IsA("SurfaceGui")then gui.Enabled=false end end end

	self.BaseBoundaryLine = requireChild(config, self.LobbyFolder, "BaseBoundaryLine", "BasePart")
    local movement=game:GetService('ReplicatedStorage'):WaitForChild('RunnerMotion')
    movement:SetAttribute('TrackBoundaryZ',self.BaseBoundaryLine.Position.Z)
    movement:SetAttribute('TrackCenterX',self.BaseBoundaryLine.Position.X)
    movement:SetAttribute('TrackHalfWidth',math.max(90,self.BaseBoundaryLine.Size.X/2)+24)
	self.FallbackSpawn = requireChild(config, self.LobbyFolder, "FallbackSpawn", "SpawnLocation")
	local obbyStartPad = self.LobbyFolder:FindFirstChild("ObbyStartPad")
	if obbyStartPad and obbyStartPad:IsA("BasePart") then
		self.ObbyStartPad = obbyStartPad
	else
		-- ObbyStartPad belonged to the retired obby. Use the permanent lobby
		-- spawn as the expedition return point instead of restoring old geometry.
		self.ObbyStartPad = self.FallbackSpawn
		self.ObbyStartPadFallback = true
		print(string.format("[%s] INFO - Lobby.ObbyStartPad is absent; using Lobby.FallbackSpawn for returns.", config.Version))
	end
	local fallReturnPlane = self.ObbyFolder:FindFirstChild("FallReturnPlane")
	if fallReturnPlane and fallReturnPlane:IsA("BasePart") then
		self.FallReturnPlane = fallReturnPlane
	else
		-- Falling is also polled by ChaseService, so no legacy touch plane is
		-- needed when the obby was removed from the map.
		self.FallReturnPlane = nil
		self.FallReturnPlaneOptional = true
	end

	self.BaseRecords = {}
	self.BaseRecordsByIndex = {}
	self:_bindBases()
	self:_bindCourse()
	self:_bindChests()

	return self
end

function MapService:_bindBases()
	for _, baseModel in ipairs(self.BasesFolder:GetChildren()) do
		if baseModel:IsA("Model") and baseModel:GetAttribute("BaseIndex") then
			local index = baseModel:GetAttribute("BaseIndex")
			local pad = requireChild(self.Config, baseModel, "Pad", "BasePart")
			local baseLabel = getBillboardText(self.Config, pad)
			local treadmill
            if self.Config.TreadmillsEnabled ~= false then
                treadmill = require(script.Parent.BiomeVisuals).BuildTreadmillV131(baseModel,1)
            end
			local baseSpawn = requireChild(self.Config, baseModel, "Spawn", "SpawnLocation")
			-- The V0.66 garden has no opening pad or loot display. Keep these
			-- optional only so a place can start before its visual migration runs.
			local openPad = baseModel:FindFirstChild("ChestOpenPad")
			local openLabel
			local openPrompt
			if openPad and openPad:IsA("BasePart") then
				local labelGui = openPad:FindFirstChild("Label")
				openLabel = labelGui and labelGui:FindFirstChild("Text")
				openPrompt = openPad:FindFirstChild("OpenSecuredChestPrompt")
			end
			local lootDisplay = baseModel:FindFirstChild("LastLootDisplay")
			local lootLight = lootDisplay and lootDisplay:FindFirstChild("LootLight")
            assert(not baseModel:FindFirstChild("CashPedestal"), "[V0.78] Run the complete expanded-garden installer; cash pedestal still exists")
			local treasureDisplaySlots = {}
			local treasureSlotsFolder = baseModel:FindFirstChild("TreasureDisplaySlots")
			if treasureSlotsFolder then
				for _, slot in ipairs(treasureSlotsFolder:GetChildren()) do
					if slot:IsA("BasePart") and slot:GetAttribute("TreasureDisplaySlot") then
						table.insert(treasureDisplaySlots, slot)
					end
				end
				table.sort(treasureDisplaySlots, function(left, right)
					return left:GetAttribute("TreasureDisplaySlot")
						< right:GetAttribute("TreasureDisplaySlot")
				end)
			end

			local ownerSignLabels = {}
			local ownerSign = baseModel:FindFirstChild("OwnerSign")
			if ownerSign then
				for _, descendant in ipairs(ownerSign:GetDescendants()) do
					if descendant:IsA("TextLabel") and descendant.Name == "Text" then
						table.insert(ownerSignLabels, descendant)
					end
				end
			end

			local record = {
				Index = index,
				Model = baseModel,
				Pad = pad,
				Label = baseLabel,
				Treadmill = treadmill,
				Spawn = baseSpawn,
				OpenPad = openPad,
				OpenLabel = openLabel,
				OpenPrompt = openPrompt,
				LootDisplay = lootDisplay,
				LootLight = lootLight,
				TreasureDisplaySlots = treasureDisplaySlots,
				OwnerSignLabels = ownerSignLabels,
			}

			table.insert(self.BaseRecords, record)
			self.BaseRecordsByIndex[index] = record
		end
	end

	table.sort(self.BaseRecords, function(left, right)
		return left.Index < right.Index
	end)
	assert(#self.BaseRecords > 0, string.format("[%s] No permanent bases were found.", self.Config.Version))
end

function MapService:_bindCourse()
	self.StageObstacles = {}
	self.ObstacleStates = {}
	self.StageGuis = {}
	self.StageGuiStates = {}
	self.EscapeRoads = {}
	self.EscapeRoadStates = {}

	for stage = 1, self.Config.StageCount do
		self.StageObstacles[stage] = {}
		self.StageGuis[stage] = {}
		local stageFolder = self.StagesFolder and self.StagesFolder:FindFirstChild(string.format("Stage_%d", stage))
		if stageFolder and stageFolder:IsA("Folder") then
			for _, descendant in ipairs(stageFolder:GetDescendants()) do
				if descendant:IsA("BasePart") then
					table.insert(self.StageObstacles[stage], descendant)
					self.ObstacleStates[descendant] = {
						Transparency = descendant.Transparency,
						CanCollide = descendant.CanCollide,
					}
				elseif descendant:IsA("BillboardGui") or descendant:IsA("SurfaceGui") then
					table.insert(self.StageGuis[stage], descendant)
					self.StageGuiStates[descendant] = descendant.Enabled
				end
			end
		end

		local road = self.RoadsFolder and self.RoadsFolder:FindFirstChild(string.format("EscapeRoad_%d", stage))
		if road and road:IsA("BasePart") then
			self.EscapeRoads[stage] = road
			self.EscapeRoadStates[road] = {
				Transparency = road.Transparency,
				CanCollide = road.CanCollide,
			}
		end
	end
end

function MapService:_bindChests()
	self.Chests = {}
	self.ChestsByStage = {}
	self.ChestGroupsByStage = {}
	self.GuardiansByStage = {}

	local guardianFolder = self.MapRoot:FindFirstChild("GuardianEncounters")
	if guardianFolder then
		for _, guardian in ipairs(guardianFolder:GetChildren()) do
			if guardian:IsA("Model") then
				local stage = tonumber(guardian:GetAttribute("Stage"))
				local root = guardian:FindFirstChild("HumanoidRootPart")
					or guardian.PrimaryPart
					or guardian:FindFirstChildWhichIsA("BasePart", true)
				if stage and stage >= 1 and stage <= self.Config.StageCount and root then
					assert(not self.GuardiansByStage[stage], string.format(
						"[%s] More than one guardian placeholder is assigned to Stage %d.",
						self.Config.Version,
						stage
						))
					guardian.PrimaryPart = root
					self.GuardiansByStage[stage] = guardian
				end
			end
		end
	end

	for _, model in ipairs(self.ChestsFolder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("Stage") then
			local stage = tonumber(model:GetAttribute("Stage"))
			assert(stage and stage >= 1 and stage <= self.Config.StageCount, string.format(
				"[%s] %s has an invalid Stage attribute.",
				self.Config.Version,
				model:GetFullName()
				))
			local body = requireChild(self.Config, model, "Body", "BasePart")
			local hinge = requireChild(self.Config, model, "LidHinge", "BasePart")
			local latch = requireChild(self.Config, model, "Latch", "BasePart")
			local prompt = requireChild(self.Config, latch, "ClaimPrompt", "ProximityPrompt")
			prompt.ActionText = "STEAL"
			prompt.ObjectText = ""
			prompt.HoldDuration = self.Config.StealHoldSeconds or 1 -- R125: hold E to steal
			local label, billboard = getBillboardText(self.Config, hinge)
			local glow = requireChild(self.Config, body, "ChestGlow", "PointLight")
			local accentColor = model:GetAttribute("AccentColor") or glow.Color
			local seedIndex = tonumber(model:GetAttribute("SeedIndex"))
				or tonumber(model:GetAttribute("GuardChestIndex"))
				or 1
			local seedDefinition = self.Config.GetSeedDefinition(stage, seedIndex)

			local partState = {}
			for _, descendant in ipairs(model:GetDescendants()) do
				if descendant:IsA("BasePart") then
					partState[descendant] = {
						Transparency = descendant.Transparency,
						CanCollide = descendant.CanCollide,
					}
				end
			end

			local chest = {
				Name = model.Name,
				Stage = stage,
				GuardChestIndex = tonumber(model:GetAttribute("GuardChestIndex")) or 1,
				SeedIndex = seedIndex,
				SeedId = model:GetAttribute("SeedId") or seedDefinition.Id,
				SeedName = model:GetAttribute("SeedName") or seedDefinition.Name,
				SeedEmoji = model:GetAttribute("SeedEmoji") or seedDefinition.Emoji,
				GuardianCampChest = model:GetAttribute("GuardianCampChest") == true,
				Model = model,
				Body = body,
				Hinge = hinge,
				Prompt = prompt,
				Billboard = billboard,
				Label = label,
				Glow = glow,
				AccentColor = accentColor,
				ClosedCFrame = model:GetAttribute("ClosedHingeCFrame") or hinge.CFrame,
				OpenCFrame = model:GetAttribute("OpenHingeCFrame")
					or (hinge.CFrame * CFrame.Angles(math.rad(70), 0, 0)),
				PartState = partState,
			}

			table.insert(self.Chests, chest)
			self.ChestGroupsByStage[stage] = self.ChestGroupsByStage[stage] or {}
			table.insert(self.ChestGroupsByStage[stage], chest)
			self.ChestsByStage[stage] = self.ChestsByStage[stage] or chest
		end
	end

	table.sort(self.Chests, function(left, right)
		if left.Stage ~= right.Stage then
			return left.Stage < right.Stage
		end
		if left.GuardChestIndex ~= right.GuardChestIndex then
			return left.GuardChestIndex < right.GuardChestIndex
		end
		return left.Name < right.Name
	end)

	for stage = 1, self.Config.StageCount do
		local group = self.ChestGroupsByStage[stage]
		assert(group and #group >= 1, string.format(
			"[%s] Stage %d must contain at least one permanent chest.",
			self.Config.Version,
			stage
			))
		table.sort(group, function(left, right)
			return left.GuardChestIndex < right.GuardChestIndex
		end)
	end

	local guardianStageCount = tonumber(self.MapRoot:GetAttribute("GuardianCampStages"))
	local guardianChestCount = tonumber(self.MapRoot:GetAttribute("GuardianChestCountPerStage"))
	if guardianStageCount and guardianChestCount then
		for stage = 1, guardianStageCount do
			local guardianGroup = self.ChestGroupsByStage[stage]
			assert(self.GuardiansByStage[stage], string.format(
				"[%s] Stage %d is missing its guardian placeholder.",
				self.Config.Version,
				stage
				))
			assert(guardianGroup and #guardianGroup == guardianChestCount, string.format(
				"[%s] Guardian camp expected %d chests at Stage %d, found %d.",
				self.Config.Version,
				guardianChestCount,
				stage,
				guardianGroup and #guardianGroup or 0
				))
		end
	else
		local guardianStage = tonumber(self.MapRoot:GetAttribute("GuardianCampStage"))
		guardianChestCount = tonumber(self.MapRoot:GetAttribute("GuardianChestCount"))
		if not guardianStage or not guardianChestCount then
			return
		end
		local guardianGroup = self.ChestGroupsByStage[guardianStage]
		assert(guardianGroup and #guardianGroup == guardianChestCount, string.format(
			"[%s] Guardian camp expected %d chests at Stage %d, found %d.",
			self.Config.Version,
			guardianChestCount,
			guardianStage,
			guardianGroup and #guardianGroup or 0
			))
	end
end

function MapService:CreateRuntimePart(properties)
	local part = Instance.new(properties.ClassName or "Part")
	part.Name = properties.Name or "Part"
	part.Size = properties.Size or Vector3.new(4, 1, 4)
	part.CFrame = properties.CFrame or CFrame.new()
	part.Anchored = properties.Anchored ~= false
	part.CanCollide = properties.CanCollide ~= false
	part.Material = properties.Material or Enum.Material.SmoothPlastic
	part.Color = properties.Color or Color3.fromRGB(163, 162, 165)
	part.Transparency = properties.Transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if properties.Shape then
		part.Shape = properties.Shape
	end
	part.Parent = properties.Parent or self.RuntimeFolder
	return part
end

function MapService:_stopCourseTweens()
	for _, tween in ipairs(self.CourseTweens) do
		tween:Cancel()
	end
	table.clear(self.CourseTweens)
end

function MapService:_playCourseTween(instance, goal, duration)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	table.insert(self.CourseTweens, tween)
	tween:Play()
end

function MapService:SetChestVisible(chest, isVisible)
	-- Converted spawn anchors never display their legacy loose-seed artwork.
	-- Pack availability/refresh visibility belongs to ChestService.
	if chest.Model:GetAttribute("BiomeSeedPack") then
		for part in pairs(chest.PartState) do
			if part.Parent then part.Transparency=1;part.CanCollide=false end
		end
		chest.Billboard.Enabled=false;chest.Glow.Enabled=false
		return
	end
	for part, state in pairs(chest.PartState) do
		if part.Parent then
			part.Transparency = isVisible and state.Transparency or 1
			part.CanCollide = isVisible and state.CanCollide or false
		end
	end
	local usesSeedArt = chest.Model:FindFirstChild("SeedPacket") ~= nil
	chest.Billboard.Enabled = isVisible and not usesSeedArt
	if usesSeedArt then
		for _, descendant in ipairs(chest.Model:GetDescendants()) do
			if descendant:IsA("SurfaceGui") then descendant.Enabled = isVisible end
		end
	end
	chest.Glow.Enabled = isVisible
end

function MapService:ResetCourse()
	self:_stopCourseTweens()

	for stage = 1, self.Config.StageCount do
		local road = self.EscapeRoads[stage]
		if road then
			local roadState = self.EscapeRoadStates[road]
			road.Transparency = roadState.Transparency
			road.CanCollide = roadState.CanCollide
		end

		for _, obstacle in ipairs(self.StageObstacles[stage]) do
			local state = self.ObstacleStates[obstacle]
			if state then
				obstacle.Transparency = state.Transparency
				obstacle.CanCollide = state.CanCollide
			end
		end

		for _, worldGui in ipairs(self.StageGuis[stage]) do
			if worldGui.Parent then
				worldGui.Enabled = self.StageGuiStates[worldGui]
			end
		end
	end

	for _, chest in ipairs(self.Chests) do
		chest.Hinge.CFrame = chest.ClosedCFrame
		chest.Glow.Brightness = 0.8
		self:SetChestVisible(chest, true)
		chest.Prompt.Enabled = true
	end
end

function MapService:FlattenCompletedStages(stageReached)
	self:_stopCourseTweens()

	for stage = 1, stageReached do
		local road = self.EscapeRoads[stage]
		if road then
			road.CanCollide = true
			self:_playCourseTween(road, {Transparency = 0.08}, 0.35)
		end

		for _, obstacle in ipairs(self.StageObstacles[stage]) do
			obstacle.CanCollide = false
			self:_playCourseTween(obstacle, {Transparency = 1}, 0.3)
		end

		for _, worldGui in ipairs(self.StageGuis[stage]) do
			if worldGui.Parent then
				worldGui.Enabled = false
			end
		end
	end
end

function MapService:GetStageAccent(stage)
    if stage==8 then return Color3.fromRGB(63,224,255)end
	local chest = self.ChestsByStage[stage]
	return chest and chest.AccentColor or Color3.fromRGB(255, 224, 103)
end

-- One shared track entrance closes every connected biome together.
function MapService:IsInsideBiomeTrack(position)
    local line=self.BaseBoundaryLine
    local halfWidth=math.max(90,line.Size.X/2)+24
    return math.abs(position.X-line.Position.X)<=halfWidth
        and position.Z>=math.min(self.Config.BiomeTrackStartZ,line.Position.Z)-2
        and position.Z<=(self.Config.BiomeTrackEndZ or 1445)+60
end
function MapService:GetRefreshReturnCFrame(slot)
    local line=self.BaseBoundaryLine
    local lobbyFloor=self.LobbyFolder:FindFirstChild("LobbyFloor")
    local floorY=lobbyFloor and lobbyFloor.Position.Y+lobbyFloor.Size.Y/2 or line.Position.Y
    local column=(slot-1)%9-4
    local row=math.floor((slot-1)/9)
    local point=Vector3.new(line.Position.X+column*6,floorY+4,line.Position.Z-18-row*6)
    return CFrame.lookAt(point,point+Vector3.new(0,0,1))
end
function MapService:SetBiomeRefreshing(closed,seconds)
    if closed and not self.RefreshCover then self.RefreshCover=require(game:GetService('ReplicatedStorage').TrackBlackout).Build(self.MapRoot,self.RuntimeFolder,self.Config.FieldWidth)end
    if not closed and self.RefreshCover then self.RefreshCover:Destroy();self.RefreshCover=nil end
    self.Refreshing=closed==true
    self.MapRoot:SetAttribute("BiomesRefreshing",self.Refreshing)
    self.MapRoot:SetAttribute("BiomeRefreshSeconds",self.Refreshing and math.max(0,math.ceil(seconds or 0)) or 0)
    local biomes=self.ObbyFolder:FindFirstChild("Biomes")
    if biomes then for _,biome in ipairs(biomes:GetChildren()) do biome:SetAttribute("Refreshing",self.Refreshing) end end
    if closed and not self.RefreshWall then
        self.RefreshWall,self.RefreshLabels=require(game:GetService('ReplicatedStorage').RefreshBarrier).Build(self.BaseBoundaryLine,self.Config.BiomeTrackStartZ,self.RuntimeFolder)
    elseif not closed and self.RefreshWall then
        self.RefreshWall:Destroy();self.RefreshWall=nil;self.RefreshLabels=nil
    end
    for _,label in ipairs(self.RefreshLabels or {}) do label.Text=tostring(math.max(0,math.ceil(seconds or 0))) end
end

return MapService
