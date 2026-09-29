local Config={RarityColors={},RarityOrder={},LootChancesByStage={},GuardianSettingsByStage={}}
for i=1,5 do Config.GuardianSettingsByStage[i]={} end
Config.MythicEncounters = {{["Home"]={-70,8,-20.2},["Yaw"]=-90,["Seeds"]={{-54.786,6.68,-52.827},{-39.638,6.68,-39.543},{-34,6.68,-20.2},{-39.638,6.68,-0.85721},{-54.786,6.68,12.427}},["Landmark"]={62,4,50}},{["Home"]={70,8,215},["Yaw"]=90,["Seeds"]={{54.786,6.68,182.37},{39.638,6.68,195.66},{34,6.68,215},{39.638,6.68,234.34},{54.786,6.68,247.63}},["Landmark"]={-62,4,260}},{["Home"]={-70,8,425},["Yaw"]=-90,["Seeds"]={{-54.786,6.68,392.37},{-39.638,6.68,405.66},{-34,6.68,425},{-39.638,6.68,444.34},{-54.786,6.68,457.63}},["Landmark"]={62,4,470}},{["Home"]={70,8,635},["Yaw"]=90,["Seeds"]={{54.786,6.68,602.37},{39.638,6.68,615.66},{34,6.68,635},{39.638,6.68,654.34},{54.786,6.68,667.63}},["Landmark"]={-62,4,680}},{["Home"]={-70,8,845},["Yaw"]=-90,["Seeds"]={{-54.786,6.68,812.37},{-39.638,6.68,825.66},{-34,6.68,845},{-39.638,6.68,864.34},{-54.786,6.68,877.63}},["Landmark"]={62,4,890}}}
-- Preserve encounter clusters and model proportions; shift each camp with its longer biome.
for stage, encounter in ipairs(Config.MythicEncounters) do
    local dz = (stage - 0.5) * (315 - 210)
    encounter.Home[3] = encounter.Home[3] + dz
    encounter.Landmark[3] = encounter.Landmark[3] + dz
    for _, position in ipairs(encounter.Seeds) do position[3] = position[3] + dz end
end
-- V088_PROGRESSIVE_TRACKS: applied after V0.87's uniform expansion.
Config.Version = "V0.89"
Config.BiomeRunLength = 150
Config.BiomeRunLengths = {150,180,210,240,270}
Config.BiomeTrackStartZ = -100
local nextStartV088 = Config.BiomeTrackStartZ
for stage, length in ipairs(Config.BiomeRunLengths) do
    local encounter = Config.MythicEncounters[stage]
    local dz = nextStartV088 + length/2 - (-100 + (stage-.5)*315)
    encounter.Home[3] = encounter.Home[3] + dz
    encounter.Landmark[3] = encounter.Landmark[3] + dz
    for _, point in ipairs(encounter.Seeds) do point[3] = point[3] + dz end
    nextStartV088 = nextStartV088 + length
end
local BE=(function() -- V090: physical order is separate from saved stage IDs. No new seed IDs.
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
 end)()
Config=BE(Config)
RS_MOD('RouteBalance83').ApplyConfig(Config)
local R=RS_MOD('RouteBalance83')
for _,id in ipairs(R.Order) do local e=Config.MythicEncounters[id]; print('CAMP',id,R.NewStart[id],R.NewStart[id]+R.Lengths[id],e.Home[1],e.Home[3]) end
