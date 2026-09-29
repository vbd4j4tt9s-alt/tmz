-- Presentation only. Seed IDs, saved names, values and owner command aliases stay intact.
local N={}
local plants={
 AncientWorldrootSeed='Worldroot',WinterCrownwoodSeed='Frostcrown',StormSovereignSeed='Stormlord',
 PrismMonarchSeed='Prism King',EmberEmperorSeed='Ember King',SilentFrostbellSeed='Hushbell',
 PolarStarbloomSeed='Starbloom',PulsarStarfruitSeed='Pulsar',SolarStarfruitSeed='Sunstar',SunKingPalmSeed='Sun King',
 ObsidianMawSeed='Obsidian Maw',BlackoutBloomSeed='Blackbloom',HollowGeodeSeed='Hollow Geode',
 AmethystSeed='Amethyst',VenomVineSeed='Venomcup',LanternFernSeed='Lantern',
 SupernovaBloomSeed='Boom Bloom',PrismOrchidSeed='Prism Pepper',
}
local fruits={
 AncientWorldrootSeed='Amberheart',WinterCrownwoodSeed='Frostgem',StormSovereignSeed='Stormbolt',
 PrismMonarchSeed='Prism Jewel',EmberEmperorSeed='Emberfruit',SilentFrostbellSeed='Hushbell',
 PolarStarbloomSeed='Starbloom',PulsarStarfruitSeed='Pulsar',SolarStarfruitSeed='Sunstar',SunKingPalmSeed='Crownstar',
 ObsidianMawSeed='Obsidian Maw',BlackoutBloomSeed='Blackbloom',HollowGeodeSeed='Geode',
 TigerOrchidSeed='Tiger Orchid',WinterPineSeed='Aurora Lily',BluebellSeed='Blueberry',MooncapSeed='Mooncap',PineappleSeed='Pineapple',AmethystSeed='Amethyst',
 VenomVineSeed='Venomcup',LanternFernSeed='Lantern',SupernovaBloomSeed='Boom Bloom',
 AgaveSeed='Crownfruit',CactusSeed='Prickly Pear',DesertRoseSeed='Prickly Pear',
 SparkReedSeed='Spark Reed',StaticGrassSeed='Spark Reed',ElderbloomSeed='Elder Apple',
 DiamondVineSeed='Diamond',IceberrySeed='Iceberry',
}
local function tidy(name)
 name=(name or'Plant'):gsub(' [Ss]eed$',''):gsub(' [Ff]lower$',''):gsub(' [Bb]unch$',''):gsub(' [Pp]lant$',''):gsub(' [Hh]ead$','')
 return(name:gsub('(%a)([%w\']*)',function(a,b)return a:upper()..b end))
end
function N.Plant(id,fallback)return plants[id]or tidy(fallback)end
function N.Fruit(id,fallback)return fruits[id]or tidy(fallback)end
function N.Seed(id,fallback)return N.Plant(id,fallback)..' Seed'end
function N.Tool(tool,catalog)
 local id=tool:GetAttribute('SeedId');local def=catalog[id]
 if tool:GetAttribute('HarvestItemTool')and require(script.Parent.HologramProjection).Is(id)and tool:GetAttribute('FruitName')then return tool:GetAttribute('FruitName')end
 if tool:GetAttribute('HarvestItemTool')then return N.Fruit(id,def and def.HarvestName or tool:GetAttribute('FruitName')or tool.Name)end
 if tool:GetAttribute('GardenSeed')then return N.Seed(id,def and def.Name or tool:GetAttribute('SeedName')or tool.Name)end
 return tool.Name
end
function N.Search(tool,catalog)return(tool.Name..' '..N.Tool(tool,catalog)..' '..(tool:GetAttribute('Mutation')or'')..' '..(tool:GetAttribute('Weather')or'')):lower()end
return N
