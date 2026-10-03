-- V119. Server rolls rewards; clients only render the published result.
local Rules = {}
Rules.Version = 139
Rules.MaxPackSize = 25
Rules.MaxSeedScale = 25
Rules.PacksPerBiome = 5
Rules.RefreshInterval = 300
Rules.RefreshClosedSeconds = 10
Rules.GuardianReturnMultiplier = 2.5
Rules.RevealSeconds = 3.5
Rules.TearSeconds = .10
Rules.OpenClicks = 5
Rules.ClickInterval = .065
Rules.TearSoundId = "rbxassetid://9125725227"
Rules.TearVolume = 0.45
Rules.TearSoundStart = 0.10
-- Soft built-in bell sample: no new external audio permission is needed.
Rules.RevealBellSoundId = "rbxasset://sounds/electronicpingshort.wav"
Rules.RevealBellVolume = .055
Rules.RevealAudioCooldown = 2.4
Rules.PackTiers = {
    {Name="Common",Color=Color3.fromRGB(220,230,235),Rate=1},
    {Name="Uncommon",Color=Color3.fromRGB(100,232,130),Rate=2},
    {Name="Rare",Color=Color3.fromRGB(95,172,255),Rate=3},
    {Name="Epic",Color=Color3.fromRGB(177,116,255),Rate=4},
    {Name="Legendary",Color=Color3.fromRGB(255,212,108),Rate=5},
    {Name="Mythic",Color=Color3.fromRGB(243,135,255),Rate=6},
}
function Rules.GetPackTier(key)
    if key=='EclipseReliquary'then return {Name='Secret+',Color=Color3.fromRGB(190,144,255),Rate=7},7 end
    if key=='MechLimited'then return {Name='Limited',Color=Color3.fromRGB(88,225,255),Rate=6},6 end
    local variant=Rules.Variants[key]
    local rank=variant and (variant.Design or ({Small=1,Standard=2,Grand=3})[key]) or 2
    for _,spec in ipairs(Rules.SeedDesigns)do if spec.id=='SupernovaBloomSeed'then spec.name='Boom Bloom'end end
return Rules.PackTiers[rank] or Rules.PackTiers[#Rules.PackTiers],rank
end
function Rules.GetRevealDuration(name)
 local rarity=Rules.Rarities[name]or Rules.Rarities.Common
 local b=require(script.Parent.BalanceRules)
 return require(script.Parent.RarityRevealSequence).SeedAt(rarity.Rank)+b.SeedRiseSeconds+b.SeedHoverSeconds+b.SeedSlideSeconds
end
-- One registry drives world spawns, saved identities, appearance and server odds.
-- Small/Standard/Grand are stable save keys; display names may change freely.
Rules.Variants = {
    Pack01 = {Name="Seed Pack", BagScale=.86, SeedScale=0.85, RareBias=1, SpawnWeight=50, Trim=1, Design=1, OddsLabel="Sealed biome pack"},
    Pack02 = {Name="Seed Pack", BagScale=.92, SeedScale=0.95, RareBias=1.05, SpawnWeight=27, Trim=2, Design=2, OddsLabel="Sealed biome pack"},
    Pack03 = {Name="Seed Pack", BagScale=1, SeedScale=1, RareBias=1.12, SpawnWeight=14, Trim=3, Design=3, OddsLabel="Sealed biome pack"},
    Pack04 = {Name="Seed Pack", BagScale=1.06, SeedScale=1.1, RareBias=1.22, SpawnWeight=6, Trim=4, Design=4, OddsLabel="Sealed biome pack"},
    Pack05 = {Name="Seed Pack", BagScale=.896, SeedScale=1.2, RareBias=1.35, SpawnWeight=2.5, Trim=5, Design=5, OddsLabel="Sealed biome pack"},
    Pack06 = {Name="Seed Pack", BagScale=.96, SeedScale=1.35, RareBias=1.5, SpawnWeight=.5, Trim=6, Design=6, OddsLabel="Sealed biome pack"},
    -- Preserve legacy saved pack keys and their already-promised reward rules.
    -- Only VariantOrder is eligible for new world spawns.
    Small = {Name="Small Sack", BagScale=.78, SeedScale=.72, RareBias=.65, SpawnWeight=30, Trim=1, OddsLabel="Common-focused"},
    Standard = {Name="Seed Sack", BagScale=1, SeedScale=1, RareBias=1, SpawnWeight=55, Trim=2, OddsLabel="Balanced odds"},
    Grand = {Name="Grand Sack", BagScale=1.25, SeedScale=1.38, RareBias=1.7, SpawnWeight=15, Trim=3, OddsLabel="Better rare odds"},
}
Rules.VariantOrder = {"Pack01","Pack02","Pack03","Pack04","Pack05","Pack06"}
Rules.DesignBiomes = {[1]="Forest",[2]="Desert",[3]="Snow",[4]="Lava",[5]="Crystal",[6]="Jungle",[7]="Storm"}
function Rules.DesignKey(stage,key)
    local legacy={Small=1,Standard=2,Grand=3}
    local variant=Rules.Variants[key]
    return (Rules.DesignBiomes[stage] or "Forest").."_"..string.format("%02d",variant and (variant.Design or legacy[key]) or 2)
end
Rules.BiomeThemes = {
    [1]={Body=Color3.fromRGB(179,138,85), Ink=Color3.fromRGB(57,103,48), Trim=Color3.fromRGB(108,135,61), Mark="Leaf", Scale=1},
    [6]={Body=Color3.fromRGB(114,143,65), Ink=Color3.fromRGB(35,83,50), Trim=Color3.fromRGB(220,182,78), Mark="Vine", Scale=1.02},
    [2]={Body=Color3.fromRGB(212,171,105), Ink=Color3.fromRGB(146,77,43), Trim=Color3.fromRGB(235,208,135), Mark="Sun", Scale=1.04},
    [3]={Body=Color3.fromRGB(185,210,218), Ink=Color3.fromRGB(57,108,144), Trim=Color3.fromRGB(230,239,236), Mark="Snowflake", Scale=1.06},
    [4]={Body=Color3.fromRGB(88,74,68), Ink=Color3.fromRGB(250,136,52), Trim=Color3.fromRGB(177,66,42), Mark="Flame", Scale=1.08},
    [5]={Body=Color3.fromRGB(137,117,171), Ink=Color3.fromRGB(227,211,250), Trim=Color3.fromRGB(101,189,191), Mark="Crystal", Scale=1.10},
    [7]={Body=Color3.fromRGB(105,113,146), Ink=Color3.fromRGB(237,212,128), Trim=Color3.fromRGB(173,150,220), Mark="Lightning", Scale=1.12},
}
function Rules.VariantKey(key)
    return type(key)=="string" and Rules.Variants[key] and key or "Standard"
end
function Rules.GetVariant(key) for _,spec in ipairs(Rules.SeedDesigns)do if spec.id=='SupernovaBloomSeed'then spec.name='Boom Bloom'end end
return Rules.Variants[Rules.VariantKey(key)] end
function Rules.GetTheme(stage) for _,spec in ipairs(Rules.SeedDesigns)do if spec.id=='SupernovaBloomSeed'then spec.name='Boom Bloom'end end
return Rules.BiomeThemes[stage] or Rules.BiomeThemes[1] end
function Rules.SanitizeSeedScale(value)
    if type(value)~="number" or value~=value or math.abs(value)==math.huge then return 1 end
    return math.floor(math.clamp(value,.35,Rules.MaxSeedScale)*1000+.5)/1000
end
-- Loose-seed appearance only: planting/growth/value do not read these size rules.
function Rules.SeedBaseScale(stage,key)
    for _,spec in ipairs(Rules.SeedDesigns)do if spec.id=='SupernovaBloomSeed'then spec.name='Boom Bloom'end end
return Rules.GetVariant(key).SeedScale*Rules.GetTheme(stage).Scale
end
function Rules.SeedSizeCap(stage,key,packSize)
    local size=Rules.SanitizePackSize(packSize)
    return math.min(Rules.MaxSeedScale,Rules.SeedBaseScale(stage,key)*(1.4+math.max(0,size-1)))
end
function Rules.NewSeedScale(stage,key,packSize)
    -- R126: Mech packs now roll a size too; their seeds follow it like any pack (a 1x Mech pack still gives scale 1).
    local size=Rules.SanitizePackSize(packSize)
    for _,spec in ipairs(Rules.SeedDesigns)do if spec.id=='SupernovaBloomSeed'then spec.name='Boom Bloom'end end
return require(script.Parent.SizeNumbers).Half(math.min(Rules.SeedBaseScale(stage,key)*size,Rules.SeedSizeCap(stage,key,size)))
end
function Rules.RollVariant(unitRoll)
    local total=0
    for _,key in ipairs(Rules.VariantOrder) do total+=Rules.Variants[key].SpawnWeight end
    local value=tonumber(unitRoll) or 0
    if value~=value then value=0 end
    local ticket=math.clamp(value,0,1-1e-12)*total
    for _,key in ipairs(Rules.VariantOrder) do
        ticket-=Rules.Variants[key].SpawnWeight
        if ticket<0 then return key end
    end
    return "Standard"
end
-- Add future rarities here and assign their names in SeedRarityById.
Rules.RarityOrder={"Common","Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"}
Rules.Rarities = {
 Common={Rank=1,Weight=62,Color=Color3.fromRGB(223,236,242),Motion="Float",Duration=3.5},
 Uncommon={Rank=2,Weight=26,Color=Color3.fromRGB(98,235,130),Motion="Sprout",Duration=3.7},
 Rare={Rank=3,Weight=9,Color=Color3.fromRGB(91,173,255),Motion="Spiral",Duration=4.1},
 Legendary={Rank=4,Weight=2,Color=Color3.fromRGB(255,207,89),Motion="Sunburst",Duration=4.6},
 Mythic={Rank=5,Weight=.8,Color=Color3.fromRGB(230,125,255),Motion="DoubleHelix",Duration=5.0},
 Secret={Rank=6,Weight=.16,Color=Color3.fromRGB(255,119,160),Motion="Eclipse",Duration=5.3},
 Cosmic={Rank=7,Weight=.035,Color=Color3.fromRGB(159,178,255),Motion="Orbit",Duration=6.4},
 King={Rank=8,Weight=.005,Color=Color3.fromRGB(255,236,161),Motion="Coronation",Duration=7.6},
}
-- Shared approved V131 designs. Stable first-five IDs preserve old saves.
Rules.SeedDesigns={{["biome"]="Forest",["index"]=1,["name"]="Watermelon",["rarity"]="Common",["design"]="fresh green to pale mint, three dark wavy stripes",["pattern"]="Stripes",["top"]="74b967",["bottom"]="d7eea1",["ink"]="245434",["addition"]="none",["stage"]=1,["id"]="SunflowerSeed"},{["biome"]="Forest",["index"]=2,["name"]="Pea",["rarity"]="Common",["design"]="lime to butter yellow, three round pea dots",["pattern"]="Dots",["top"]="b8e878",["bottom"]="e9f5b7",["ink"]="598a36",["addition"]="none",["stage"]=1,["id"]="CloverSeed"},{["biome"]="Forest",["index"]=3,["name"]="Blueberry",["rarity"]="Uncommon",["design"]="indigo to cornflower, pale speckles and tiny leaf tuft",["pattern"]="Specks",["top"]="666dce",["bottom"]="acd1ff",["ink"]="d6efff",["addition"]="leaves",["stage"]=1,["id"]="BluebellSeed"},{["biome"]="Forest",["index"]=4,["name"]="Strawberry",["rarity"]="Uncommon",["design"]="red to rose, cream seed specks, leafy green cap",["pattern"]="Specks",["top"]="ee5366",["bottom"]="ffa9b1",["ink"]="ffebae",["addition"]="cap",["stage"]=1,["id"]="StrawberrySeed"},{["biome"]="Forest",["index"]=5,["name"]="Apple",["rarity"]="Rare",["design"]="ruby to warm peach, apple leaf emblem and a short brown stem",["pattern"]="Leaf",["top"]="c9384b",["bottom"]="ffc387",["ink"]="4b9f42",["addition"]="stem",["stage"]=1,["id"]="AppleSeed"},{["biome"]="Forest",["index"]=6,["name"]="Mooncap",["rarity"]="Rare",["design"]="lavender to midnight, crescent marking and two tiny pale mushrooms",["pattern"]="Dots",["top"]="b2a2e4",["bottom"]="393860",["ink"]="ecedff",["addition"]="mushrooms",["stage"]=1,["id"]="MooncapSeed"},{["biome"]="Forest",["index"]=7,["name"]="Sunflower",["rarity"]="Legendary",["design"]="amber to lemon, short petal collar like a little sun, gentle gold rays",["pattern"]="Star",["top"]="ffb94a",["bottom"]="fff0a0",["ink"]="fff6c7",["addition"]="petals",["stage"]=1,["id"]="SunflowerBloomSeed"},{["biome"]="Forest",["index"]=8,["name"]="Elderbloom",["rarity"]="Mythic",["design"]="deep emerald to jade, two branching wooden antlers, white blossom buds, mint wisps",["pattern"]="Leaf",["top"]="206e56",["bottom"]="8aefba",["ink"]="e9ffe8",["addition"]="antlers",["stage"]=1,["id"]="ElderbloomSeed"},{["biome"]="Jungle",["index"]=1,["name"]="Banana",["rarity"]="Common",["design"]="yellow to chartreuse, three curved lime stripes",["pattern"]="Stripes",["top"]="f2d556",["bottom"]="f6f2ab",["ink"]="769d30",["addition"]="none",["stage"]=6,["id"]="BananaSeed"},{["biome"]="Jungle",["index"]=2,["name"]="Cocoa",["rarity"]="Common",["design"]="copper to cocoa brown, three cream dots",["pattern"]="Dots",["top"]="b17a45",["bottom"]="513528",["ink"]="f1d391",["addition"]="none",["stage"]=6,["id"]="CocoaSeed"},{["biome"]="Jungle",["index"]=3,["name"]="Pineapple",["rarity"]="Uncommon",["design"]="amber to yellow, diamond specks, compact spiky green leaf tuft",["pattern"]="Specks",["top"]="dc9b27",["bottom"]="ffeaaa",["ink"]="926031",["addition"]="cap",["stage"]=6,["id"]="PineappleSeed"},{["biome"]="Jungle",["index"]=4,["name"]="Monstera",["rarity"]="Uncommon",["design"]="jade to lime, dark split-leaf emblem, one curled leaf on side",["pattern"]="Leaf",["top"]="26ad83",["bottom"]="b4eb70",["ink"]="146644",["addition"]="leaves",["stage"]=6,["id"]="MonsteraSeed"},{["biome"]="Jungle",["index"]=5,["name"]="Venom Vine",["rarity"]="Rare",["design"]="plum to acid green, thorn nubs and lime droplet dots",["pattern"]="Dots",["top"]="81388e",["bottom"]="b7ed57",["ink"]="d3ff72",["addition"]="thorns",["stage"]=6,["id"]="VenomVineSeed"},{["biome"]="Jungle",["index"]=6,["name"]="Lantern Fern",["rarity"]="Rare",["design"]="emerald to teal, two hanging amber lantern buds, leaf emblem",["pattern"]="Leaf",["top"]="168a65",["bottom"]="74dcb9",["ink"]="e6f395",["addition"]="lanterns",["stage"]=6,["id"]="LanternFernSeed"},{["biome"]="Jungle",["index"]=7,["name"]="Tiger Orchid",["rarity"]="Legendary",["design"]="orange to ivory, bold black tiger stripes and two orchid petal fins",["pattern"]="Stripes",["top"]="f09b39",["bottom"]="fff1c7",["ink"]="433236",["addition"]="petals",["stage"]=6,["id"]="TigerOrchidSeed"},{["biome"]="Jungle",["index"]=8,["name"]="Ancient Worldroot",["rarity"]="Mythic",["design"]="teal to deep jungle green, root antlers curling around core, amber resin gems",["pattern"]="Leaf",["top"]="27bca8",["bottom"]="164f3d",["ink"]="ffd27f",["addition"]="antlers",["stage"]=6,["id"]="AncientWorldrootSeed"},{["biome"]="Desert",["index"]=1,["name"]="Prickly Pear",["rarity"]="Common",["design"]="sage to lime, cream dotted areoles",["pattern"]="Dots",["top"]="8ba850",["bottom"]="daeca4",["ink"]="fff2c1",["addition"]="none",["stage"]=2,["id"]="CactusSeed"},{["biome"]="Desert",["index"]=2,["name"]="Aloe",["rarity"]="Uncommon",["design"]="turquoise to sage, single leaf emblem and two aloe blades",["pattern"]="Leaf",["top"]="4bada3",["bottom"]="b2dab2",["ink"]="24736a",["addition"]="leaves",["stage"]=2,["id"]="AloeSeed"},{["biome"]="Desert",["index"]=4,["name"]="Crown Cactus",["rarity"]="Legendary",["design"]="green to warm jade, gold spines and short golden flower crest",["pattern"]="Dots",["top"]="64a468",["bottom"]="cdeea5",["ink"]="ffd378",["addition"]="crest",["stage"]=2,["id"]="AgaveSeed"},{["biome"]="Desert",["index"]=5,["name"]="Dune Lotus",["rarity"]="Mythic",["design"]="terracotta to rose gold, layered sandy lotus petals and sun disc",["pattern"]="Star",["top"]="cc7749",["bottom"]="ffe1a4",["ink"]="fff2c7",["addition"]="petals",["stage"]=2,["id"]="DatePalmSeed"},{["biome"]="Desert",["index"]=6,["name"]="Mirage Fig",["rarity"]="Secret",["design"]="midnight blue to sand, one luminous slit, broken hovering amber halo",["pattern"]="Leaf",["top"]="27354f",["bottom"]="d0ad80",["ink"]="fff2b4",["addition"]="brokenHalo",["stage"]=2,["id"]="MirageFigSeed"},{["biome"]="Desert",["index"]=7,["name"]="Solar Starfruit",["rarity"]="Cosmic",["design"]="indigo to amber, little stars, tilted golden orbital ring and sun motes",["pattern"]="Star",["top"]="59417f",["bottom"]="ffd582",["ink"]="fff4c5",["addition"]="orbit",["stage"]=2,["id"]="SolarStarfruitSeed"},{["biome"]="Desert",["index"]=8,["name"]="Sun King Palm",["rarity"]="King",["design"]="ivory to gold, tall sun crown, two jade palm fronds and red central gem",["pattern"]="Star",["top"]="ffcf69",["bottom"]="fff5c8",["ink"]="fff7dd",["addition"]="crown",["stage"]=2,["id"]="SunKingPalmSeed"},{["biome"]="Snow",["index"]=1,["name"]="Snow Melon",["rarity"]="Common",["design"]="mint to snow white, thin icy stripes",["pattern"]="Stripes",["top"]="9bceca",["bottom"]="efffff",["ink"]="579baf",["addition"]="none",["stage"]=3,["id"]="SnowdropSeed"},{["biome"]="Snow",["index"]=2,["name"]="Frost Fern",["rarity"]="Uncommon",["design"]="teal to frost blue, two short frosted fern leaves",["pattern"]="Leaf",["top"]="59a8a0",["bottom"]="d4f8f7",["ink"]="efffff",["addition"]="leaves",["stage"]=3,["id"]="FrostFernSeed"},{["biome"]="Snow",["index"]=3,["name"]="Iceberry",["rarity"]="Rare",["design"]="azure to baby blue, tiny translucent blue ice cluster on one side",["pattern"]="Dots",["top"]="468dcc",["bottom"]="c0efff",["ink"]="eeffff",["addition"]="crystals",["stage"]=3,["id"]="IceberrySeed"},{["biome"]="Snow",["index"]=4,["name"]="Aurora Lily",["rarity"]="Legendary",["design"]="violet to mint, translucent petal collar, restrained aurora ribbons",["pattern"]="Star",["top"]="7f75d6",["bottom"]="a8ffd8",["ink"]="efffff",["addition"]="petals",["stage"]=3,["id"]="WinterPineSeed"},{["biome"]="Snow",["index"]=5,["name"]="Glacier Lotus",["rarity"]="Mythic",["design"]="deep glacial blue to white, tall transparent ice petal spikes",["pattern"]="Leaf",["top"]="2784b8",["bottom"]="e6ffff",["ink"]="abffff",["addition"]="crystals",["stage"]=3,["id"]="CrystalLilySeed"},{["biome"]="Snow",["index"]=6,["name"]="Silent Frostbell",["rarity"]="Secret",["design"]="navy to silver, frosted bell cap and detached broken ice halo",["pattern"]="Dots",["top"]="354864",["bottom"]="d4e5ef",["ink"]="d4ffff",["addition"]="brokenHalo",["stage"]=3,["id"]="SilentFrostbellSeed"},{["biome"]="Snow",["index"]=7,["name"]="Polar Starbloom",["rarity"]="Cosmic",["design"]="midnight indigo to icy cyan, tiny stars, tilted ice orbit, floating shards",["pattern"]="Star",["top"]="363c91",["bottom"]="99e9ff",["ink"]="edffff",["addition"]="orbit",["stage"]=3,["id"]="PolarStarbloomSeed"},{["biome"]="Snow",["index"]=8,["name"]="Winter Crownwood",["rarity"]="King",["design"]="ice blue to pearl, huge clear glacier crown, sapphire jewel, white frosty rays",["pattern"]="Star",["top"]="79bedb",["bottom"]="f1ffff",["ink"]="ddffff",["addition"]="crown",["stage"]=3,["id"]="WinterCrownwoodSeed"},{["biome"]="Lava",["index"]=1,["name"]="Fire Pepper",["rarity"]="Common",["design"]="red to orange, small cream pepper flecks",["pattern"]="Specks",["top"]="c63929",["bottom"]="ffb45b",["ink"]="ffedac",["addition"]="none",["stage"]=4,["id"]="FirePepperSeed"},{["biome"]="Lava",["index"]=2,["name"]="Ember Pumpkin",["rarity"]="Uncommon",["design"]="orange to amber, dark pumpkin stripes and burnt stem",["pattern"]="Stripes",["top"]="df6824",["bottom"]="ffca60",["ink"]="663722",["addition"]="stem",["stage"]=4,["id"]="EmberBloomSeed"},{["biome"]="Lava",["index"]=3,["name"]="Ash Tomato",["rarity"]="Rare",["design"]="charcoal to ash rose, small glowing orange crack pattern and obsidian spikes",["pattern"]="Specks",["top"]="574650",["bottom"]="bc7070",["ink"]="ffc16a",["addition"]="thorns",["stage"]=4,["id"]="AshRoseSeed"},{["biome"]="Lava",["index"]=4,["name"]="Lava Lotus",["rarity"]="Legendary",["design"]="orange to yellow, four chunky black petals with glowing edges",["pattern"]="Star",["top"]="f15b21",["bottom"]="ffd872",["ink"]="ffef91",["addition"]="petals",["stage"]=4,["id"]="LavaLotusSeed"},{["biome"]="Lava",["index"]=5,["name"]="Dragonfruit",["rarity"]="Mythic",["design"]="magenta to scarlet, two curled black dragon horns and green scales",["pattern"]="Specks",["top"]="c73577",["bottom"]="fc8b75",["ink"]="b5d55a",["addition"]="horns",["stage"]=4,["id"]="DragonfruitSeed"},{["biome"]="Lava",["index"]=6,["name"]="Obsidian Maw",["rarity"]="Secret",["design"]="near black to purple, glowing orange slit, jagged broken obsidian halo",["pattern"]="Leaf",["top"]="292232",["bottom"]="695178",["ink"]="ff9d38",["addition"]="brokenHalo",["stage"]=4,["id"]="ObsidianMawSeed"},{["biome"]="Lava",["index"]=7,["name"]="Supernova Bloom",["rarity"]="Cosmic",["design"]="indigo to hot pink, fiery tilted orbit, tiny orange stars",["pattern"]="Star",["top"]="574099",["bottom"]="ff8baf",["ink"]="ffd76b",["addition"]="orbit",["stage"]=4,["id"]="SupernovaBloomSeed"},{["biome"]="Lava",["index"]=8,["name"]="Ember Emperor",["rarity"]="King",["design"]="black to molten gold, large black crown with lava seams, orange ruby and great horns",["pattern"]="Star",["top"]="51312c",["bottom"]="ffb358",["ink"]="ffe38e",["addition"]="crownHorns",["stage"]=4,["id"]="EmberEmperorSeed"},{["biome"]="Crystal",["index"]=1,["name"]="Amethyst Grape",["rarity"]="Common",["design"]="violet to lavender, three pale grape dots",["pattern"]="Dots",["top"]="965ec2",["bottom"]="dbc1fb",["ink"]="f4e5ff",["addition"]="none",["stage"]=5,["id"]="AmethystSeed"},{["biome"]="Crystal",["index"]=2,["name"]="Prism Pepper",["rarity"]="Uncommon",["design"]="teal to lilac, tiny diamond flecks and short quartz point",["pattern"]="Specks",["top"]="6cbecd",["bottom"]="d5b5f2",["ink"]="f4ffff",["addition"]="crystals",["stage"]=5,["id"]="PrismOrchidSeed"},{["biome"]="Crystal",["index"]=3,["name"]="Moon Melon",["rarity"]="Rare",["design"]="lavender to pearl, moon mark and two small silver leaf fins",["pattern"]="Leaf",["top"]="a296c9",["bottom"]="f4eafa",["ink"]="e7fdff",["addition"]="leaves",["stage"]=5,["id"]="MoonflowerSeed"},{["biome"]="Crystal",["index"]=4,["name"]="Starfruit",["rarity"]="Legendary",["design"]="gold to pale yellow, broad crystal star crest and tiny gold sparkles",["pattern"]="Star",["top"]="eab956",["bottom"]="fff1ab",["ink"]="ffffdf",["addition"]="crest",["stage"]=5,["id"]="StarfruitSeed"},{["biome"]="Crystal",["index"]=5,["name"]="Diamond Vine",["rarity"]="Mythic",["design"]="azure to clear ice, long transparent diamond cluster and silver vine curl",["pattern"]="Leaf",["top"]="75b6db",["bottom"]="e4fbff",["ink"]="fcffff",["addition"]="crystals",["stage"]=5,["id"]="DiamondVineSeed"},{["biome"]="Crystal",["index"]=6,["name"]="Hollow Geode",["rarity"]="Secret",["design"]="graphite to violet, oval face geode seam with bright violet crystals, broken ring",["pattern"]="Dots",["top"]="514363",["bottom"]="aa7acf",["ink"]="ebbbff",["addition"]="brokenHalo",["stage"]=5,["id"]="HollowGeodeSeed"},{["biome"]="Crystal",["index"]=7,["name"]="Orbit Lotus",["rarity"]="Cosmic",["design"]="indigo to lilac, stars, two tilted lavender orbit rings, floating prism gems",["pattern"]="Star",["top"]="4b438e",["bottom"]="cbadf3",["ink"]="fbebff",["addition"]="orbit",["stage"]=5,["id"]="OrbitLotusSeed"},{["biome"]="Crystal",["index"]=8,["name"]="Prism Monarch",["rarity"]="King",["design"]="pearl to violet, massive asymmetrical quartz crown with gold setting and rainbow core",["pattern"]="Star",["top"]="b08be0",["bottom"]="fff2fb",["ink"]="c8ffff",["addition"]="crown",["stage"]=5,["id"]="PrismMonarchSeed"},{["biome"]="Storm",["index"]=1,["name"]="Static Grass",["rarity"]="Common",["design"]="slate blue to pale cyan, three yellow flecks",["pattern"]="Specks",["top"]="63889e",["bottom"]="c9e9ee",["ink"]="ffde69",["addition"]="none",["stage"]=7,["id"]="StaticGrassSeed"},{["biome"]="Storm",["index"]=2,["name"]="Spark Reed",["rarity"]="Uncommon",["design"]="teal to electric blue, two reed-like yellow antennae",["pattern"]="Stripes",["top"]="337a9e",["bottom"]="9feff1",["ink"]="ffe783",["addition"]="antennae",["stage"]=7,["id"]="SparkReedSeed"},{["biome"]="Storm",["index"]=3,["name"]="Thunder Tulip",["rarity"]="Rare",["design"]="blue to cyan, thick yellow lightning mark and short electric arc",["pattern"]="Star",["top"]="377bbc",["bottom"]="a0f6ff",["ink"]="fff06e",["addition"]="bolts",["stage"]=7,["id"]="ThunderTulipSeed"},{["biome"]="Storm",["index"]=4,["name"]="Volt Orchid",["rarity"]="Legendary",["design"]="violet to electric blue, thick bolt-shaped yellow petals, bright small arcs",["pattern"]="Star",["top"]="7861c4",["bottom"]="73d8f4",["ink"]="fff388",["addition"]="bolts",["stage"]=7,["id"]="VoltOrchidSeed"},{["biome"]="Storm",["index"]=5,["name"]="Tempest Lotus",["rarity"]="Mythic",["design"]="cobalt to white, three swept lightning fins and circular electric arc",["pattern"]="Star",["top"]="3d69c9",["bottom"]="d9fcff",["ink"]="ffec6e",["addition"]="bolts",["stage"]=7,["id"]="TempestLotusSeed"},{["biome"]="Storm",["index"]=6,["name"]="Blackout Bloom",["rarity"]="Secret",["design"]="black navy to purple, one white electric slit, broken violet electric halo",["pattern"]="Leaf",["top"]="242a48",["bottom"]="7771bc",["ink"]="eef1ff",["addition"]="brokenHalo",["stage"]=7,["id"]="BlackoutBloomSeed"},{["biome"]="Storm",["index"]=7,["name"]="Pulsar Starfruit",["rarity"]="Cosmic",["design"]="midnight blue to lavender, star flecks, yellow charged orbital ring and sparks",["pattern"]="Star",["top"]="343e89",["bottom"]="afc9ff",["ink"]="ffe970",["addition"]="orbit",["stage"]=7,["id"]="PulsarStarfruitSeed"},{["biome"]="Storm",["index"]=8,["name"]="Storm Sovereign",["rarity"]="King",["design"]="royal blue to pale cyan, tall thick lightning crown, central diamond and orbiting electric bolts",["pattern"]="Star",["top"]="326ad0",["bottom"]="c8fbff",["ink"]="fff36c",["addition"]="crownBolts",["stage"]=7,["id"]="StormSovereignSeed"}}
-- V139: preserve all eight identities per biome; promote the old lower entries.
-- Stage numbers are stable save IDs, not physical progression order.
Rules.MinimumSeedRarityByStage={[1]="Common",[6]="Common",[2]="Uncommon",[3]="Uncommon",[4]="Rare",[5]="Rare",[7]="Rare"}
function Rules.MinimumSeedRank(stage)
 for _,spec in ipairs(Rules.SeedDesigns)do if spec.id=='SupernovaBloomSeed'then spec.name='Boom Bloom'end end
return Rules.Rarities[Rules.MinimumSeedRarityByStage[stage]or "Common"].Rank
end
Rules.SeedMotion={Tag="ChestChaseLooseSeed",MaxDistance=120,DetailDistance=65,MaxActive=12,MaxDetailed=6,UpdateInterval=1/30,SelectionInterval=.25}
Rules.SeedRarityById={};Rules.SeedDesignById={}
for _,spec in ipairs(Rules.SeedDesigns)do
 if spec.id == "StaticGrassSeed" then spec.name = "Bolt Bean" end
 if Rules.Rarities[spec.rarity].Rank<Rules.MinimumSeedRank(spec.stage)then
  spec.rarity=Rules.MinimumSeedRarityByStage[spec.stage]
 end
 Rules.SeedRarityById[spec.id]=spec.rarity;Rules.SeedDesignById[spec.id]=spec
end
-- V149 final: hidden compatibility definition, excluded from obtainable designs.
Rules.RetiredSeedIds = {AgaveSeed=true,DragonfruitSeed=true,MonsteraSeed=true,AloeSeed=true,BananaSeed=true,StrawberrySeed=true,FrostFernSeed=true,DesertRoseSeed=true,CloverSeed=true,StaticGrassSeed=true,SunKingPalmSeed=true}
function Rules.IsRetired(id) for _,spec in ipairs(Rules.SeedDesigns)do if spec.id=='SupernovaBloomSeed'then spec.name='Boom Bloom'end end
return Rules.RetiredSeedIds[id] == true end
local legacyPear = table.clone(Rules.SeedDesignById.CactusSeed)
legacyPear.id = "DesertRoseSeed"; legacyPear.index = 3; legacyPear.rarity = "Rare"
legacyPear.retired = true
Rules.SeedDesignById.DesertRoseSeed = legacyPear
Rules.SeedRarityById.DesertRoseSeed = "Rare"
-- Old saved bean IDs display existing crops; no pod art or bean collection entries remain.
for id,target in pairs({CloverSeed='StrawberrySeed',StaticGrassSeed='SparkReedSeed',SunKingPalmSeed='SolarStarfruitSeed'})do
 local old=Rules.SeedDesignById[id];local replacement=table.clone(Rules.SeedDesignById[target])
 replacement.id=id;replacement.index=old.index;replacement.stage=old.stage;replacement.biome=old.biome;replacement.rarity=old.rarity;replacement.retired=true
 Rules.SeedDesignById[id]=replacement
end
-- Keep original stage/index slots for old records and fallback lookups.
-- Acquisition is a separate map; moving a crop must never reinterpret an old save.
for _,spec in pairs(Rules.SeedDesignById)do spec.SaveStage=spec.stage end
for id,fields in pairs({DragonfruitSeed={stage=2,biome='Desert'},StarfruitSeed={stage=2,biome='Desert',name='Dune Starfruit'}})do
 local spec=Rules.SeedDesignById[id]
 for key,value in pairs(fields)do spec[key]=value end
end
-- R37: presentation and roll weights share the same rarity identity.
for id,rarity in pairs({SolarStarfruitSeed='King',MirageFigSeed='Cosmic',StarfruitSeed='Secret',PulsarStarfruitSeed='King',StormSovereignSeed='Cosmic'})do
 Rules.SeedRarityById[id]=rarity;Rules.SeedDesignById[id].rarity=rarity
end
function Rules.ObtainableStage(id)
 local spec=Rules.SeedDesignById[id];return spec and spec.stage
end
for i=#Rules.SeedDesigns,1,-1 do if Rules.IsRetired(Rules.SeedDesigns[i].id)then table.remove(Rules.SeedDesigns,i)end end
function Rules.BuildSeedCatalog()
 local catalog={{},{},{},{},{},{},{},{}}
 for id,spec in pairs(Rules.SeedDesignById)do
  local hex=spec.top
  catalog[spec.SaveStage][spec.index]={Id=id,Name=spec.name..' Seed',Emoji='🌱',Retired=Rules.IsRetired(id),ObtainStage=spec.stage,
   Color=Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16))}
 end
 return catalog
end
local obtainableCache=setmetatable({},{__mode='k'})
function Rules.ObtainablePool(config,stage)
 local pools=obtainableCache[config]
 if not pools then
  pools={{},{},{},{},{},{},{},{}}
  for _,catalog in ipairs(config.SeedCatalogByStage)do for _,seed in ipairs(catalog)do
   if not Rules.IsRetired(seed.Id)then table.insert(pools[Rules.ObtainableStage(seed.Id)],seed)end
  end end
  obtainableCache[config]=pools
 end
 return pools[stage]
end
local styles = {
    SunflowerSeed = {{178,235,148},{30,110,51},"Stripes",{24,83,33}},
    CloverSeed = {{240,246,137},{115,165,35},"Dots",{62,122,32}},
    BluebellSeed = {{192,163,244},{47,70,156},"Star",{220,206,255}},
    StrawberrySeed = {{255,180,189},{186,36,60},"Specks",{255,237,187}},
    AppleSeed = {{255,221,130},{215,85,42},"Leaf",{255,240,189}},
}
function Rules.GetRarity(seedId)
    local name = Rules.SeedRarityById[seedId] or "Common"
    return name, Rules.Rarities[name] or Rules.Rarities.Common
end
function Rules.GetStyle(seed, index)
    local spec=Rules.SeedDesignById[seed.Id]
    if spec then
        local function rgb(h)return Color3.fromRGB(tonumber(h:sub(1,2),16),tonumber(h:sub(3,4),16),tonumber(h:sub(5,6),16))end
        return rgb(spec.top),rgb(spec.bottom),spec.pattern,rgb(spec.ink)
    end
    local preset = styles[seed.Id]
    if preset then
        return Color3.fromRGB(table.unpack(preset[1])), Color3.fromRGB(table.unpack(preset[2])),
            preset[3], Color3.fromRGB(table.unpack(preset[4]))
    end
    local patterns = {"Stripes","Dots","Star","Specks","Leaf"}
    return seed.Color:Lerp(Color3.new(1,1,1),0.48), seed.Color:Lerp(Color3.new(0,0,0),0.27),
        patterns[((index or 1)-1)%#patterns+1], Color3.fromRGB(255,238,194)
end
function Rules.SeedWeights(pool,stage,variant,luck)
    local weights,total,counts={},0,{}
    for _,seed in ipairs(pool)do
        if not Rules.IsRetired(seed.Id) then
            local name=Rules.GetRarity(seed.Id);counts[name]=(counts[name]or 0)+1
        end
    end
    for i, seed in ipairs(pool) do
        if Rules.IsRetired(seed.Id) then weights[i]=0; continue end
        local name, rarity = Rules.GetRarity(seed.Id)
        -- Rarity weights are shared by duplicate-rarity seeds, not multiplied by their count.
        local weight=rarity.Weight/counts[name]
        -- Luck improves the chances above this biome's minimum, including late biomes.
        weight=weight*(1+(variant.RareBias-1)*(rarity.Rank-1)/7)*(rarity.Rank>Rules.MinimumSeedRank(stage) and luck or 1)
        weights[i] = weight; total += weight
    end
    return weights,total
end
function Rules.SeedOdds(config,stage,variantKey,luck)
 local out={}
 if stage==8 then for _,s in ipairs(require(script.Parent.MechCatalog).Seeds)do out[s.Id]=s.Chance end;return out end
 local pool=Rules.ObtainablePool(config,stage)or{};local weights,total=Rules.SeedWeights(pool,stage,Rules.GetVariant(variantKey),math.clamp(tonumber(luck)or 1,1,5))
 if total>0 then for i,s in ipairs(pool)do out[s.Id]=weights[i]/total*100 end end;return out
end
function Rules.Roll(config, stage, unitRoll, luck, variantKey)
    if variantKey=='MechLimited'then
        if stage~=8 then return nil end
        local item=require(script.Parent.MechCatalog).Roll(unitRoll)
        return item and config.GetSeedById(item.Id),item and item.Rarity
    end
    if stage==8 then return nil end
    local pool = Rules.ObtainablePool(config,stage)
    if not pool or #pool == 0 then return nil end
    if type(unitRoll) ~= "number" or unitRoll ~= unitRoll then return nil end
    luck = tonumber(luck) or 1
    if luck ~= luck then luck = 1 end
    luck = math.clamp(luck,1,5)
    local variant = Rules.GetVariant(variantKey)
    local weights,total=Rules.SeedWeights(pool,stage,variant,luck)
    if total <= 0 then return nil end
    local ticket = math.clamp(unitRoll,0,1-1e-12) * total
    for i, weight in ipairs(weights) do
        if ticket < weight then return pool[i], Rules.GetRarity(pool[i].Id) end
        ticket -= weight
    end
    return nil
end
-- V126: independent cosmetic traits; seed rewards/economy remain unchanged.
Rules.PackSizes=require(script.Parent.BalanceRules).PackSizes
Rules.PackMutations={
    None={Weight=95},
    Gold={Weight=4.5,Color=Color3.fromRGB(255,201,70),Aura=Color3.fromRGB(255,210,79),Material=Enum.Material.Metal},
    Diamond={Weight=.5,Color=Color3.fromRGB(213,247,255),Aura=Color3.fromRGB(214,250,255),Material=Enum.Material.Glass},
}
Rules.MutationOrder={'None','Gold','Diamond'}
function Rules.SanitizePackSize(value)
    if type(value)~='number'or value~=value or math.abs(value)==math.huge then return 1 end
    return math.floor(math.clamp(value,.5,Rules.MaxPackSize)*1000+.5)/1000
end
-- Retired Wicked saves become ordinary packs; biome, tier, size and inventory ID survive.
function Rules.MutationKey(value)return type(value)=='string'and Rules.PackMutations[value]and value or 'None'end
local function ticket(value)
    return type(value)=='number'and value==value and math.clamp(value,0,1-1e-12)*100 or 0
end
function Rules.RollPackSize(value)
    local t=ticket(value)
    for _,entry in ipairs(Rules.PackSizes)do t-=entry.Weight;if t<0 then return entry.Scale end end
    return 1
end
function Rules.RollMutation(value)
    local t=ticket(value)
    for _,key in ipairs(Rules.MutationOrder)do t-=Rules.PackMutations[key].Weight;if t<0 then return key end end
    return 'None'
end
function Rules.PackLabel(stage,variant,size,mutation)
    if variant=='EclipseReliquary'then local m=Rules.MutationKey(mutation);return(m~='None'and m..' 'or'')..'Void Pack'end
    if variant=='MechLimited'then return 'Limited Mech Pack'end
    mutation=Rules.MutationKey(mutation)
    return (mutation~='None'and mutation..' 'or '')..
        (Rules.DesignBiomes[stage]or 'Biome')..' Seed Pack'
end

-- V138. Shared pure animation math; seed rarity, never pack tier, selects the reveal.
function Rules.RevealPose(rank,age,ease)
    local V,CF=Vector3.new,CFrame.new
    local y=.05*math.sin(age*2);local x,z,roll=0,0,0;local yaw=age*.45
    if rank==2 then y=math.abs(math.sin(age*2.5))*.15;yaw=age*.7;roll=math.sin(age*2)*.06
    elseif rank==3 then x=math.sin(age*2)*.16;z=math.cos(age*2)*.12;y=.12+math.sin(age*2)*.09;yaw=age*1.25
    elseif rank==4 then y=.28+math.sin(age*1.8)*.07;yaw=age*.55;roll=math.sin(age*1.5)*.06
    elseif rank==5 then x=math.sin(age*1.4)*.12;y=.4+math.sin(age*2)*.12;yaw=age*.85;roll=math.sin(age*1.7)*.09
    elseif rank==6 then y=.26+math.sin(age*1.2)*.06;yaw=math.sin(age*.8)*.32
    elseif rank==7 then x=math.sin(age)*.22;z=math.cos(age)*.14;y=.44+math.sin(age*1.7)*.12;yaw=age*.72;roll=math.sin(age)*.15
    elseif rank>=8 then y=.58+math.sin(age*1.3)*.04;yaw=.20*math.sin(age*.7) end
    return CF(V(x,y,z)*ease)*CFrame.Angles(0,yaw,roll)
end
function Rules.RevealAuraPoint(rank,index,count,age,radius)
    local V=Vector3.new
    local t=(index-1)*math.pi*2/count
    if rank==1 then return V(math.cos(t+age*.3)*radius,math.sin(t*2+age)*radius*.24,math.sin(t+age*.3)*radius),false
    elseif rank==2 then return V(math.cos(t-age*.65)*radius,math.sin(t+age)*radius*.45,math.sin(t-age*.65)*radius),false
    end
    -- Legacy callers also get drifting points, never the rejected short straight rays.
    local phase=(index-1)*2.39996+.4
    local life=(age*(.085+((index-1)%5)*.012)+((index-1)*.618034)%1)%1
    return V(math.cos(phase)*radius+math.sin(age*.48+phase)*radius*.12,
        (-.86+life*2.3)*radius,math.sin(phase)*radius*.8),false
end

for _,spec in ipairs(Rules.SeedDesigns)do if spec.id=='SupernovaBloomSeed'then spec.name='Boom Bloom'end end
local rarityTheme=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenTheme'))
for name,style in pairs(Rules.Rarities)do if rarityTheme.Rarities[name]then style.Color=rarityTheme.Rarity(name).Color end end
-- Limited inventory category; excluded from world VariantOrder and StageCount.
local Mech=require(script.Parent.MechCatalog)
Rules.Variants.MechLimited={Name=Mech.Name,BagScale=1,SeedScale=1,RareBias=1,SpawnWeight=0,Trim=6,Design=1}
Rules.DesignBiomes[8]='Mech'
Rules.BiomeThemes[8]={Body=Color3.fromRGB(31,43,57),Ink=Color3.fromRGB(63,224,255),Trim=Color3.fromRGB(244,178,57),Mark='Mech',Scale=1}
for index,s in ipairs(Mech.Seeds)do
 local spec={id=s.Id,name=s.Name,rarity=s.Rarity,stage=8,SaveStage=8,biome='Mech',index=index,top='36a6ff',bottom='1f2b39',ink='60dbff',pattern='Leaf',addition='none'}
 table.insert(Rules.SeedDesigns,spec);Rules.SeedDesignById[s.Id]=spec;Rules.SeedRarityById[s.Id]=s.Rarity
end
for name,weight in pairs(require(script.Parent.BalanceRules).RarityWeights)do Rules.Rarities[name].Weight=weight;Rules.Rarities[name].Duration=Rules.GetRevealDuration(name)end

-- Versioned R81 world packs. Legacy unversioned and Small/Standard/Grand keep old Roll.
local oldRoll=Rules.Roll
local oldOdds=Rules.SeedOdds
local O=require(script.Parent.PackOdds81)
local approved=require(script.Parent.BalanceValues81)
for i,key in ipairs(Rules.VariantOrder)do Rules.Variants[key].SpawnWeight=approved.SpawnWeights[i]end
Rules.Variants.EclipseReliquary={Name='Void Pack',BagScale=.96,SeedScale=1.35,RareBias=1,SpawnWeight=0,Trim=7,Design=6,OddsLabel='All Secret / Cosmic / King seeds + 1/200 Mech roll'}
function Rules.RewardPool(config,stage,variant)
 if variant=='EclipseReliquary'then local _,all=require(script.Parent.VoidPackOdds85).Pools(config,Rules);return all end
 return Rules.ObtainablePool(config,stage)
end
function Rules.SeedOdds(config,stage,variantKey,luck,version)
 if variantKey=='EclipseReliquary'then return stage==7 and require(script.Parent.VoidPackOdds85).Odds(config,Rules)or{}end
 if stage==8 or(version~=nil and version~=81)or(not approved.SeedWeights[variantKey]and variantKey~='EclipseReliquary')then return oldOdds(config,stage,variantKey,luck)end
 if variantKey=='EclipseReliquary'and stage~=7 then return {}end
 local pool=Rules.ObtainablePool(config,stage)or{}
 local weights,total=O.Weights(pool,Rules.GetRarity,variantKey,luck)
 local out={};if total and total>0 then for i,seed in ipairs(pool)do out[seed.Id]=100*weights[i]/total end end
 return out
end
function Rules.Roll(config,stage,unitRoll,luck,variantKey,version)
 if variantKey=='EclipseReliquary'then
  if stage~=7 then return nil end
  return require(script.Parent.VoidPackOdds85).Roll(config,Rules,unitRoll)
 end
 if version~=81 or stage==8 or(not approved.SeedWeights[variantKey]and variantKey~='EclipseReliquary')then return oldRoll(config,stage,unitRoll,luck,variantKey)end
 if variantKey=='EclipseReliquary'and stage~=7 then return nil end
 if type(unitRoll)~='number'or unitRoll~=unitRoll or math.abs(unitRoll)==math.huge then return nil end
 local pool=Rules.ObtainablePool(config,stage)or{}
 local weights,total=O.Weights(pool,Rules.GetRarity,variantKey,luck)
 if not total or total<=0 then return nil end
 local ticket=math.clamp(unitRoll,0,1-1e-12)*total
 for i,weight in ipairs(weights)do if ticket<weight then return pool[i],Rules.GetRarity(pool[i].Id)end;ticket-=weight end
 return nil
end
-- R112: new world/event packs carry OddsVersion 112 (PackOdds112, King 1/1T in a Common pack, exact staged roll).
-- Earlier packs keep their version and their old odds, with luck mapped back to the old boots (x1.15..x2).
-- Roll takes a draw function (e.g. function() return random:NextNumber() end); old paths use one number from it.
local N=require(script.Parent.PackOdds112)
Rules.OddsVersion=N.Version
local roll81,odds81=Rules.Roll,Rules.SeedOdds
local function current(stage,variantKey,version)
 return version==N.Version and stage~=8 and(N.PackFloor[variantKey]~=nil or variantKey=='EclipseReliquary'and stage==7)
end
Rules.SeedOdds=function(config,stage,variantKey,luck,version)
 if version==nil then version=N.Version end
 if not current(stage,variantKey,version)then return odds81(config,stage,variantKey,N.LegacyLuck(luck),version)end
 local void=variantKey=='EclipseReliquary'
 local pool=void and require(script.Parent.VoidPackOdds85).Pools(config,Rules)or Rules.ObtainablePool(config,stage)or{}
 local out={};local odds=N.SeedOdds(pool,Rules.GetRarity,Rules.MinimumSeedRarityByStage[stage]or'Common',variantKey,luck)
 for id,p in pairs(odds or{})do out[id]=100*p*(void and 1-N.Void.MechChance or 1)end
 if void then for _,s in ipairs(require(script.Parent.MechCatalog).Seeds)do
  if config.GetSeedById(s.Id)then out[s.Id]=(out[s.Id]or 0)+N.Void.MechChance*s.Chance end
 end end
 return out
end
Rules.Roll=function(config,stage,draw,luck,variantKey,version)
 if not current(stage,variantKey,version)then
  return roll81(config,stage,type(draw)=='function'and draw()or draw,N.LegacyLuck(luck),variantKey,version)
 end
 if type(draw)~='function'then return nil end -- one number cannot roll 1 in 1T exactly
 if variantKey=='EclipseReliquary'then
  if N.Chance(N.Void.MechChance,draw)then
   local item=require(script.Parent.MechCatalog).Roll(draw())
   return item and config.GetSeedById(item.Id),item and item.Rarity
  end
  return N.Roll(require(script.Parent.VoidPackOdds85).Pools(config,Rules),Rules.GetRarity,'Rare',variantKey,1,draw)
 end
 return N.Roll(Rules.ObtainablePool(config,stage)or{},Rules.GetRarity,Rules.MinimumSeedRarityByStage[stage]or'Common',variantKey,luck,draw)
end

-- R137 (owner-approved, docs/proposals/pity_R136): new world/event packs carry OddsVersion 137 (PackOdds137: Legendary and
-- Mythic rarer down the biome list, no pass-up into Mythic, a missing floor steps down). 112 packs keep PackOdds112 and
-- older packs their old odds, exactly as before (Void and Mech packs too).
local N137=require(script.Parent.PackOdds137)
Rules.OddsVersion=N137.Version
Rules.OddsVersions={[81]=true,[N.Version]=true,[N137.Version]=true}
function Rules.ValidOddsVersion(version)return Rules.OddsVersions[version]==true end
local roll112,odds112=Rules.Roll,Rules.SeedOdds
local function current137(stage,variantKey,version)
 return version==N137.Version and stage~=8 and N137.PackFloor[variantKey]~=nil
end
local function older(version)return version==N137.Version and N.Version or version end
Rules.SeedOdds=function(config,stage,variantKey,luck,version)
 if version==nil then version=N137.Version end
 if not current137(stage,variantKey,version)then return odds112(config,stage,variantKey,luck,older(version))end
 local out={};local odds=N137.SeedOdds(Rules.ObtainablePool(config,stage)or{},Rules.GetRarity,Rules.MinimumSeedRarityByStage[stage]or'Common',variantKey,luck,stage)
 for id,p in pairs(odds or{})do out[id]=100*p end
 return out
end
Rules.Roll=function(config,stage,draw,luck,variantKey,version)
 if not current137(stage,variantKey,version)then return roll112(config,stage,draw,luck,variantKey,older(version))end
 if type(draw)~='function'then return nil end
 return N137.Roll(Rules.ObtainablePool(config,stage)or{},Rules.GetRarity,Rules.MinimumSeedRarityByStage[stage]or'Common',variantKey,luck,draw,stage)
end

return Rules
