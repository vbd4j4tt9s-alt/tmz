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

-- BEGIN STARTUP_GUARD_153
-- R153 (architecture review; owner: "if a server fails just kick them out"): a server that did not start does not run a game, so it must not keep players waiting on a half-built
-- one. The SERVER decides (no client is asked or trusted): when ChestChaseStartupState reads "Failed", or is still not "Ready" after STARTUP_TIMEOUT seconds, every player is kicked
-- with a short message and so is everybody who joins afterwards, so the broken server empties and Roblox closes it. In Studio nobody is kicked: the reason is warned in the Output and
-- the same message is shown on screen (StartupNotice153 shows the ChestChaseStartupNotice attribute), so the owner can debug.
-- A healthy start takes seconds: every wait in the boot path is a bounded WaitForChild or a loop that runs in its own thread (the hub displays, the social service, the free Void Pack pedestal ...),
-- and the asset loads (trampolines, hub trees) are spawned. STARTUP_TIMEOUT is 90 s, far above that, so a slow but healthy start is never kicked.
local STARTUP_TIMEOUT = 90
local STARTUP_KICK_TEXT = "this server broke while loading 😭 pls rejoin"
local function guardStartup()
	local RunService = game:GetService("RunService")
	task.spawn(function()
		local waited = 0 -- seconds waited so far: summed from what task.wait really waited (wall time; os.clock may count CPU time, which does not advance while the boot sits in a yield)
		local reason
		while reason == nil do
			local state = ReplicatedStorage:GetAttribute("ChestChaseStartupState")
			if state == "Ready" then return end -- a healthy start: the guard ends here and never kicks anyone
			if state == "Failed" then
				reason = tostring(ReplicatedStorage:GetAttribute("ChestChaseStartupError") or "the start-up failed")
			elseif waited >= STARTUP_TIMEOUT then
				reason = string.format("this server was still not ready after %d s (stuck while: %s)", STARTUP_TIMEOUT, startupPhase)
			else
				waited += task.wait(1) or 1
			end
		end
		warn("[R153] THIS SERVER DID NOT START: " .. reason)
		if RunService:IsStudio() then
			-- Studio: no kick. The message goes on screen (and stays until the Output is read); a start that was only slow clears it when it finishes after all.
			local firstLine = string.sub(string.match(reason, "^[^\n]*"), 1, 160)
			ReplicatedStorage:SetAttribute("ChestChaseStartupNotice", STARTUP_KICK_TEXT .. "\n(Studio: not kicking. " .. firstLine .. ")")
			while ReplicatedStorage:GetAttribute("ChestChaseStartupState") == "Starting" do
				task.wait(1)
				if ReplicatedStorage:GetAttribute("ChestChaseStartupState") == "Ready" then
					ReplicatedStorage:SetAttribute("ChestChaseStartupNotice", nil)
					warn("[R153] The server finished starting after all (it was only slow).")
				end
			end
			return
		end
		-- Live: stay failed for good (main must not mark Ready later), kick everybody now and everybody who joins later.
		ReplicatedStorage:SetAttribute("ChestChaseStartupState", "Failed")
		if ReplicatedStorage:GetAttribute("ChestChaseStartupError") == nil then ReplicatedStorage:SetAttribute("ChestChaseStartupError", reason) end
		local kicked = setmetatable({}, { __mode = "k" }) -- (each player once: a Kick that worked is not repeated every sweep; one that errored is tried again)
		local function kick(player)
			if kicked[player] then return end
			if pcall(function() player:Kick(STARTUP_KICK_TEXT) end) then kicked[player] = true end
		end
		Players.PlayerAdded:Connect(kick)
		while true do
			for _, player in ipairs(Players:GetPlayers()) do kick(player) end
			task.wait(2)
		end
	end)
end
-- END STARTUP_GUARD_153

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
	do local okGuard,guardError = pcall(guardStartup);if not okGuard then warn("[R153] The start-up guard could not start: "..tostring(guardError)) end end

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
	-- R155: the Bag's server half (discarding items, the saved hotbar layout). A failure here never stops the server: no discarding, the layout is not saved.
	do local ok,err=pcall(function()require(modules.InventoryService155).new(Config,playerData,chestService,gifts,notifications):Start()end);if not ok then warn('[R155] Inventory service failed to start: '..tostring(err))end end
	-- R156: the Desert pyramid's secret Mythic pack (Hold E from outside, carried home past the Sand Snake, one per player once banked). A failure here never stops the server: no secret pack.
	do local ok,err=pcall(function()require(modules.SecretPyramid156).new(Config,playerData,chestService,chaseService,notifications,mapService):Start()end);if not ok then warn('[R156] Secret pyramid failed to start: '..tostring(err))end end
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
	-- BEGIN OWNER_TOOLS_START_153
	-- R153 (architecture review): the owner / test commands start here, last, in their own thread and inside a pcall. They used to start inside ChaseService:Start, so an error anywhere in
	-- the most-edited test file (or a hang on a missing module) stopped ChaseService, and with it the whole server. Now a failure is a warning and the game runs without the commands.
	task.spawn(function()
		local okTools, toolsError = pcall(function()
			require(modules.StudioTestCommands).Start(Config, playerData, chestService, chaseService, baseService, notifications, mapService)
		end)
		if not okTools then warn("[R153] Owner test commands failed to start (the game runs without them): " .. tostring(toolsError)) end
	end)
	-- END OWNER_TOOLS_START_153
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

	if ReplicatedStorage:GetAttribute("ChestChaseStartupState") == "Failed" then
		warn("[R153] This server was already marked failed (the start-up guard gave up on it): it stays failed.")
		return
	end
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
