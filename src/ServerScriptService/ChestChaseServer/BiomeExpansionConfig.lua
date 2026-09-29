-- V090: physical order is separate from saved stage IDs. No new seed IDs.
return function(Config)
    Config.Version = "V1.20"
    Config.StageCount = 7
    Config.BiomeOrder = {1,6,2,3,4,5,7}
    Config.BiomeNames = {"Forest", "Desert", "Snow", "Lava", "Crystal", "Jungle", "Storm Peaks"}
    Config.BiomeIcons = {"🌲", "🌵", "❄️", "🌋", "💎", "🌿", "⚡"}
    Config.BiomeRank = {[1]=1,[6]=2,[2]=3,[3]=4,[4]=5,[5]=6,[7]=7}
    Config.BiomeRunLengths = {150,195,210,240,270,180,300}
    Config.StageSeedPools = {} -- Stable stage/index slots include hidden retired save entries.
    Config.SeedCatalogByStage = require(game:GetService("ReplicatedStorage"):WaitForChild("SeedPackRules")).BuildSeedCatalog()
    Config.SeedTypeCount = #require(game:GetService("ReplicatedStorage"):WaitForChild("SeedPackRules")).SeedDesigns
    Config.SeedCatalogVersion = 149
    for name,style in pairs(require(game:GetService("ReplicatedStorage"):WaitForChild("SeedPackRules")).Rarities)do Config.RarityColors[name]=style.Color;Config.RarityOrder[name]=style.Rank end
    Config.GardenPlacementDistance = 50
    Config.LootChancesByStage[6] = Config.LootChancesByStage[2]
    Config.LootChancesByStage[7] = Config.LootChancesByStage[5]
    Config.GuardianSettingsByStage[6] = table.clone(Config.GuardianSettingsByStage[2])
    Config.GuardianSettingsByStage[6].MinimumSpeed = 33
    Config.GuardianSettingsByStage[6].AdaptiveHeadroom = 5
    Config.GuardianSettingsByStage[6].CatchupBonus = 1.5
    -- Preserve the effective V103 hit strength while fixing the speed lookup.
    for _,key in ipairs({"FlingHorizontal","FlingVertical","RagdollDuration"}) do
        Config.GuardianSettingsByStage[6][key] = Config.GuardianSettingsByStage[5][key]
    end
    Config.GuardianSettingsByStage[6].PlayerSpeedRatio = .8
    Config.GuardianSettingsByStage[7] = table.clone(Config.GuardianSettingsByStage[5])
    Config.GuardianSettingsByStage[7].MinimumSpeed = 66
    Config.GuardianSettingsByStage[7].PlayerSpeedRatio = .90
    Config.GuardianSettingsByStage[7].AdaptiveHeadroom = 8
    Config.GuardianSettingsByStage[7].CatchupBonus = 3
    -- Existing five packs and crops keep their IDs, values, growth times and save schema.
    for _,stage in ipairs({3,4,5}) do
        local e = Config.MythicEncounters[stage]
        e.Home[3] += 195; e.Landmark[3] += 195
        for _,point in ipairs(e.Seeds) do point[3] += 195 end
    end
    for _,stage in ipairs({6,7}) do
        local z = stage == 6 and 327.5 or 1295
        local side = stage == 6 and -1 or 1
        local e = {Home={side*64,8,z},Yaw=side*90,Landmark={-side*63,4,z+35},Seeds={}}
        for i=1,5 do
            local angle = math.rad(-60+(i-1)*30)
            e.Seeds[i] = {side*(64-math.cos(angle)*29),6.68,z+math.sin(angle)*32}
        end
        Config.MythicEncounters[stage] = e
    end
    -- V105: preserve animal hit tuning; only trade the rank-based pace fields.
    for _,key in ipairs({"MinimumSpeed","PlayerSpeedRatio","AdaptiveHeadroom","CatchupBonus"}) do
        Config.GuardianSettingsByStage[2][key],Config.GuardianSettingsByStage[6][key] =
            Config.GuardianSettingsByStage[6][key],Config.GuardianSettingsByStage[2][key]
    end
    for stage,dz in pairs({[2]=187.5,[6]=-187.5}) do
        local e=Config.MythicEncounters[stage]
        e.Home[3]+=dz;e.Landmark[3]+=dz
        for _,point in ipairs(e.Seeds) do point[3]+=dz end
    end
    Config.BiomeTrackEndZ = 1445
    -- V134: preserve camp spacing and stable stage IDs on 50% longer routes.
    local function z(v)return -100+(v+100)*1.5 end
    for stage,length in ipairs(Config.BiomeRunLengths)do Config.BiomeRunLengths[stage]=length*1.5 end
    Config.BiomeRunLength=225;Config.BiomeTrackEndZ=z(1445)
    for stage,encounter in ipairs(Config.MythicEncounters)do
        local oldHome=encounter.Home[3];local delta=z(oldHome)-oldHome
        encounter.Home[3]+=delta
        for _,seed in ipairs(encounter.Seeds)do seed[3]+=delta end
        encounter.Landmark[3]=stage==4 and encounter.Landmark[3]+427.5 or z(encounter.Landmark[3])
    end
    -- R109: Forest camp is placed by RouteBalance83.ApplyConfig; the old R45 mirror put packs past the walls.
    for _,seeds in pairs(Config.SeedCatalogByStage)do
 for _,seed in ipairs(seeds)do if seed.Id=='SupernovaBloomSeed'then seed.Name='Boom Bloom Seed'end end
end
return Config
end
