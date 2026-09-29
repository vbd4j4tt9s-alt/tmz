-- R46: keep the original Mythic trees; redesign flowers, other plants, Moon Melon and Hollow Geode.
local RS=game:GetService('ReplicatedStorage')
local Index={MoonflowerSeed="MoonflowerSeedArt45",SunflowerBloomSeed="SunflowerBloomSeedArt45",TigerOrchidSeed="TigerOrchidSeedArt45",VoltOrchidSeed="VoltOrchidSeedArt45",AgaveSeed="AgaveSeedArt45",WinterPineSeed="WinterPineSeedArt45",LavaLotusSeed="LavaLotusSeedArt45",DatePalmSeed="DatePalmSeedArt45",CrystalLilySeed="CrystalLilySeedArt45",TempestLotusSeed="TempestLotusSeedArt45",DiamondVineSeed="DiamondVineSeedArt45",HollowGeodeSeed="HollowGeodeSeedArt45"}
local A={};local loaded={}
function A.Has(id)return Index[id]~=nil end
function A.Key(id)return id..':rarity45' end
function A.Get(id)
 if not Index[id]then return nil end
 if not loaded[id]then loaded[id]=require(RS:WaitForChild(Index[id]))end
 return loaded[id]
end
function A.ApplyCatalog(catalog)
 for id in pairs(Index)do
  local d=catalog[id];local art=A.Get(id)
  d.Sockets=art.Sockets;d.FruitCenters=art.FruitCenters;d.FruitRadii=art.FruitRadii
  d.Height=art.Height;d.AuthoredHeight=art.Height;d.Radius=art.Radius;d.BaseScale=1
 end
end
return A
