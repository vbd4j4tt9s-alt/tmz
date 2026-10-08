-- V0.77 seed foundation bootstrap. Replace the existing ChestChaseServerMain Script.
-- Studio path: ServerScriptService > ChestChaseServerMain.
-- Keep exactly one enabled main server Script.
-- Keep the ChestChaseServer MODULE FOLDER and existing map folder names.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local STARTUP_VERSION = "V0.85"
local startupPhase = "checking installation"

local function startupFailure(message)
	return string.format("[%s] STARTUP FAILED during %s:\n%s", STARTUP_VERSION,
		startupPhase, debug.traceback(tostring(message), 2))
end

local function runServer()
	-- This check precedes shared status writes, so a duplicate cannot overwrite a
	-- running server's Ready status. Disable duplicates manually; do not delete data.
	for _, other in ipairs(script.Parent:GetChildren()) do
		if other ~= script and other:IsA("Script") and not other.Disabled
			and (other.Name == "SimpleObbyDemo" or other.Name == "ObbyDemoServer"
				or other.Name == "ChestChaseServerMain"
				or other:GetAttribute("ChestChaseBootstrap") == true) then
			error("Another enabled Chest Chase startup script exists: "..other:GetFullName()
				..". Keep ONE main server Script; rename the existing one instead of adding another.",0)
		end
	end
	script:SetAttribute("ChestChaseBootstrap",true)
	ReplicatedStorage:SetAttribute("ChestChaseStartupState","Starting")
	ReplicatedStorage:SetAttribute("ChestChaseStartupError",nil)

	local modules = script.Parent:WaitForChild("ChestChaseServer", 10)
	assert(modules and modules:IsA("Folder"),
		"ServerScriptService needs a FOLDER named ChestChaseServer containing the ModuleScripts.")

	local function loadModule(name, requiredFunctions)
		startupPhase = "loading "..name
		local moduleScript = modules:WaitForChild(name, 10)
		assert(moduleScript and moduleScript:IsA("ModuleScript"),
			"Missing ModuleScript: ServerScriptService.ChestChaseServer."..name)
		local ok, exported = pcall(require, moduleScript)
		assert(ok, "Module "..name.." could not load. Original error: "..tostring(exported))
		assert(type(exported)=="table", name.." must return its module table. Replace its COMPLETE Source.")
		for _, method in ipairs(requiredFunctions) do
			assert(type(exported[method])=="function",
				name.."."..method.." is missing or is not a function. This module is incomplete, outdated,"
					.." or contains the wrong script. Replace the ENTIRE Source of "..name.." with the matching file.")
		end
		return exported
	end

	-- Check all exports before constructing services or creating game remotes.
	-- Never hide a failed validation by skipping it or substituting an empty table.
	local Config = loadModule("Config", {"Validate","GetWalkSpeed","NormalizeSpeedStat",
		"GetTrainingAward","GetGuardianChaseSpeed","SmoothGuardianSpeed","GetDataStoreName","LegacySpeedToStat","GetSeedById","GetSeedDefinition","GetGardenGrowth"})
	startupPhase = "validating Config"
	Config.Validate()
	local NotificationService = loadModule("NotificationService", {"new","Show"})
	local MapService = loadModule("MapService", {"new","ResetCourse","CreateRuntimePart"})
	local PlayerDataService = loadModule("PlayerDataService", {"new","PreparePlayer","Load",
		"StartAutosave","Shutdown","Save","WaitForSave","FinalizePlayer","CleanupPlayer","GetOrCreateSpeedValue","GetDiscoveredItems",
		"GetDiscoveredSeeds","MarkSeedDiscovered","CanReceiveSeed","GetSeedInventory","PlantSeed","HarvestPlant","SellHarvest","GetGardenState","GetHarvestInventory"})
	local LootToolService = loadModule("LootToolService", {"new","OnCharacterAdded","SetupPlayer","CleanupPlayer"})
	local BaseService = loadModule("BaseService", {"new","SetBusyChecker","StartTraining",
		"StopTraining","ApplyCharacter","AssignPlayer","ReleasePlayer"})
	local ChestService = loadModule("ChestService", {"new","Start","OnCharacterAdded","SyncTools","CleanupPlayer","Bank","StartGardens","RenderGarden","BuildSeedPacket","BuildArtLibrary","DressGuardian"})
	local ChaseService = loadModule("ChaseService", {"new","Start","IsPlayerBusy","CleanupPlayer",
		"_stepGuardianToCFrame","_publishRunEffects"})
	local StormService = loadModule("StormService", {"new","Start"})
	local FastTravelService = loadModule("FastTravelService", {"new","Start","CleanupPlayer"})
	local EconomyService = loadModule("EconomyService", {"new","Start","ApplyCosmetics","SetupPlayer","CleanupPlayer"})
	local SpeedBoardService = loadModule("SpeedBoardService", {"new"})

	local function construct(name, factory, ...)
		startupPhase = "constructing "..name
		local instance = factory(...)
		assert(type(instance)=="table", name..".new must return a service instance")
		return instance
	end

	Players.RespawnTime = 1.5
	-- R75: offer Roblox's native Shift Lock switch to keyboard/mouse players.
	game:GetService("StarterPlayer").EnableMouseLockOption = true

	local notifications = construct("NotificationService", NotificationService.new)
	local mapService = construct("MapService", MapService.new, Config)
	local playerData = construct("PlayerDataService", PlayerDataService.new, Config, mapService, notifications)
	local lootToolService = construct("LootToolService", LootToolService.new, Config, playerData)
	local baseService = construct("BaseService", BaseService.new, Config, mapService, playerData, notifications)
	local BiomeVisuals = loadModule("BiomeVisuals", {"Build"})
	local chestService = construct("ChestService", ChestService.new, Config, mapService, playerData, baseService, notifications)
	chestService.BiomeVisuals = BiomeVisuals
	local chaseService = construct("ChaseService", ChaseService.new,
		Config,
		mapService,
		playerData,
		baseService,
		chestService,
		notifications
	)
	local stormService = construct("StormService", StormService.new, mapService, chaseService)
	local speedBoard = construct("SpeedBoardService", SpeedBoardService.new, playerData)
	local fastTravelService = construct("FastTravelService", FastTravelService.new,
		Config,
		mapService,
		baseService,
		chaseService,
		notifications
	)
	local economyService = construct("EconomyService", EconomyService.new,
		Config,
		mapService,
		playerData,
		baseService,
		chestService,
		chaseService,
		notifications
	)

	local gifts=require(modules.FruitGiftService).new(playerData,chestService,chaseService,notifications)
	local gamePasses=require(modules.GamePassService).new(playerData,baseService,chestService)
    local premium=require(modules.PremiumService).new(playerData,chestService,gamePasses)
    local social=require(modules.SocialService).new(playerData,notifications):Start() -- R140: friend boost, plant-ready notifications, daily rollover
    local mystery=require(modules.MysteryPackService).new(Config,playerData,baseService,chestService,notifications,mapService):Start() -- R141: daily mystery pack pedestal
    local verity;do local ok,err=pcall(function()verity=require(modules.VerityService).new(Config,playerData,chestService,notifications,mapService):Start()end);if not ok then warn('[R147] Verity failed to start: '..tostring(err))end end -- R147: Verity NPC behind the market (a Void pack becomes a Verity pack)
	do local ok,err=pcall(function()require(modules.PullAnnouncer).Start(playerData)end);if not ok then warn('[R151] Pull announcements failed to start: '..tostring(err))end end -- R151
	-- R151: the hub's two corner displays (BEST PULL: this server's own 10-minute board, R153; BIGGEST FRUIT TODAY). A failure here never stops the server: no displays, nothing counted.
	local hubDisplays;do local ok,err=pcall(function()
		hubDisplays=require(modules.HubDisplayService).new(Config,playerData,notifications,mapService):Start()
		playerData.OnPackOpened=function(player,reward,info)hubDisplays:NotePull(player,reward,info)end
		chestService.HarvestHook=function(player,harvest)hubDisplays:NoteHarvest(player,harvest)end
	end);if not ok then warn('[R151] Hub displays failed to start: '..tostring(err));hubDisplays=nil end end
	-- R152: the free Void Pack pedestal in the middle of the plaza (500 claims across ALL servers: a DataStore key + MessagingService). A failure here never stops the server: no pedestal.
	do local ok,err=pcall(function()require(modules.VoidGiveaway152).new(Config,playerData,chestService,notifications,mapService):Start()end);if not ok then warn('[R152] Void giveaway failed to start: '..tostring(err))end end
	require(modules.MovementGuard).Start(Config,playerData,baseService)
	-- R153: a body that rests on a track wall top (or in the blockers on it) is put back on the track; four looks a second. A failure here never stops the server.
	do local ok,err=pcall(function()require(modules.TrackWalls153).Start()end);if not ok then warn('[R153] Track wall guard failed to start: '..tostring(err))end end
	startupPhase = "connecting chase and training"
	baseService:SetBusyChecker(function(player)
		return chaseService:IsPlayerBusy(player)
	end)
	-- R153: opening a pack (its reveal: IsPlayerBusy counts ChestService:IsOpening) no longer ends treadmill training; a chase (a run, or one that is starting) still does.
	baseService:SetTrainingBusyChecker(function(player)
		if type(chaseService.Runs) == "table" and type(chaseService.Starting) == "table" then return chaseService.Runs[player] ~= nil or chaseService.Starting[player] == true end
		return chaseService:IsPlayerBusy(player)
	end)

	startupPhase = "starting ChestService"
	chestService:Start()
    local weather=require(modules.WeatherService).new(playerData,chestService);weather:Start()
    require(modules.FruitOfHourService).new(notifications):Start() -- R132
    require(ReplicatedStorage.GardenTypography).Apply(mapService.MapRoot)
	startupPhase = "starting ChaseService"
	chaseService:Start()
	stormService:Start()
	-- R122: shovel holes on the track (only pack carriers fall in).
	local TrackHoleService = loadModule("TrackHoleService", {"new","Start","Request","Step","ClearAll","CleanupPlayer"})
	local trackHoles = construct("TrackHoleService", TrackHoleService.new, Config, mapService, chaseService, notifications)
	trackHoles:Start()
	startupPhase = "starting FastTravelService"
	fastTravelService:Start()
	startupPhase = "starting EconomyService"
	economyService:Start()
	speedBoard:Start()
	startupPhase = "starting treadmill training"
	baseService:StartTraining()
	-- R123: treadmill bonus rolls (every 10 min of treadmill time; TreadmillBonusRules).
	local TreadmillBonusService = loadModule("TreadmillBonusService", {"new","Start","Setup","Cleanup","Roll"})
	local treadmillBonus = construct("TreadmillBonusService", TreadmillBonusService.new, Config, playerData, baseService, chestService, notifications)
	treadmillBonus:Start()
	-- R123: owner test commands reach these services through the chase service (ctx.Chase).
	chaseService.TrackHoles=trackHoles;chaseService.Gifts=gifts;chaseService.TreadmillBonus=treadmillBonus;chaseService.Mystery=mystery;chaseService.Verity=verity;chaseService.HubDisplays=hubDisplays
	startupPhase = "starting autosave and resetting field"
	playerData:StartAutosave()
	mapService:ResetCourse()
	-- BEGIN CHEST_CHASE_STUDIO_SEED_COMMANDS_V1
	if game:GetService("RunService"):IsStudio()then
		local testModule=modules:FindFirstChild("StudioSeedCommands")
		if testModule then
			local okay,why=pcall(function()require(testModule).Start(Config,playerData,chestService,chaseService,notifications)end)
			if not okay then warn("[Seed Test] Could not start: "..tostring(why))end
		end
	end
	-- END CHEST_CHASE_STUDIO_SEED_COMMANDS_V1


	local function setupPlayer(player)
		player.DevEnableMouseLock = true
		playerData:PreparePlayer(player)
		baseService:AssignPlayer(player)

		local function setupCharacter(character)
            require(ReplicatedStorage.DefaultCharacterAnimations).Bind(character,false)
			chaseService.Ragdoll:Clear(player)
			baseService:ApplyCharacter(player, character)
			chestService:OnCharacterAdded(player)
			lootToolService:OnCharacterAdded(player)
			task.delay(0.35, function()
				if player.Parent and character.Parent and player.Character == character then
					economyService:ApplyCosmetics(player, character)
				end
			end)
		end

        player.CharacterAppearanceLoaded:Connect(function(character)
            require(ReplicatedStorage.DefaultCharacterAnimations).Bind(character,false)
            baseService:ApplyCharacterScale(player, character, true)
            economyService:ApplyCosmetics(player, character)
        end)
		player.CharacterAdded:Connect(setupCharacter)
		if player.Character then
			task.spawn(setupCharacter, player.Character)
		end

		playerData:Load(player)
		if not player.Parent or not playerData:IsLoaded(player) then
			return
		end

		task.spawn(function()gamePasses:Refresh(player)end)
        task.spawn(function()premium:Setup(player)end)
		baseService:RefreshTreadmill(player)
		chestService:SyncTools(player)
		chestService:RenderGarden(baseService:GetPlayerBase(player), player)
		lootToolService:SetupPlayer(player)
		economyService:SetupPlayer(player)
        task.spawn(function()gifts:Recover(player)end)
        treadmillBonus:Setup(player)
        social:Setup(player)
        mystery:Setup(player)
		if player.Character then
			task.spawn(setupCharacter, player.Character)
		end
	end

	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(setupPlayer, player)
	end

	Players.PlayerRemoving:Connect(function(player)
        require(modules.SecurityGate).Cleanup(player);require(modules.MovementGuard).Cleanup(player)
        task.spawn(function()speedBoard:Publish(player)end)
        gifts:Cleanup(player)
        treadmillBonus:Cleanup(player)
        premium:Cleanup(player)
        social:Leaving(player) -- (reads the garden, so before the profile is finalized; never yields)
        mystery:Leaving(player)
		playerData:FinalizePlayer(player, "PlayerRemoving")
		trackHoles:CleanupPlayer(player)
		chaseService:CleanupPlayer(player)
		chestService:CleanupPlayer(player)
		economyService:CleanupPlayer(player)
		lootToolService:CleanupPlayer(player)
		baseService:ReleasePlayer(player)
		fastTravelService:CleanupPlayer(player)
		playerData:CleanupPlayer(player)
	end)

	game:BindToClose(function()
		stormService:Destroy()
		speedBoard:Destroy()
		playerData:Shutdown(Players:GetPlayers())
	end)
	-- R151: a closing server (update, shut down all servers) still queues every player's "your plant is ready"; its own
	-- callback, so it runs beside the profile saves (Shutdown reads gardens that are finalizing, never yields them).
	game:BindToClose(function()social:Shutdown(Players:GetPlayers())end)

	ReplicatedStorage:SetAttribute("ChestChaseStartupState","Ready")
	print(string.format("[%s] PASS - ChestChaseServerMain started; gameplay config %s.",
		STARTUP_VERSION,tostring(Config.Version)))
end

local ok, message = xpcall(runServer,startupFailure)
if not ok then
	-- A duplicate refusal must not mark the other instance as failed.
	if startupPhase ~= "checking installation" then
		ReplicatedStorage:SetAttribute("ChestChaseStartupState","Failed")
		ReplicatedStorage:SetAttribute("ChestChaseStartupError",message)
	end
	error(message,0)
end
