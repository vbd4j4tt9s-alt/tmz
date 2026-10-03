--!nocheck
-- Index preview (not a test): the REAL ChestIndex client under the mock, opened on the Forest tab, with a made-up
-- discovery state (some seeds found, some grown, one reward to claim, some still unknown). Prints JSON for
-- render_index.py and the ids still unknown (drawn as silhouettes, like the game).
local W=require('./world');local R=W.R;local dump=require('./dump_gui')
local VW,VH=1040,800
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=5;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local realNew=R.Instance.new
R.Instance.new=function(class,parent)local o=realNew(class,parent);if class=='ScreenGui'then o.AbsoluteSize=R.Vector2.new(VW,VH)end;return o end
W.env.Instance=R.Instance
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local catalog=R.new('Folder');catalog.Name='SeedCatalog';catalog.Parent=remotes
local req=R.new('RemoteFunction');req.Name='PremiumRequest';req.Parent=remotes
local Rules=W.module('SeedPackRules')
local config={SeedCatalogByStage=Rules.BuildSeedCatalog()}
local index=0
for _,stage in ipairs({1,6,2,3,4,5,7})do
 local odds=Rules.SeedOdds(config,stage,'Pack01',1)
 for _,seed in ipairs(Rules.ObtainablePool(config,stage))do
  index+=1;local e=R.new('Folder');e.Name=seed.Id
  e:SetAttribute('SeedId',seed.Id);e:SetAttribute('DisplayName',seed.Name);e:SetAttribute('Rarity',(Rules.GetRarity(seed.Id)))
  e:SetAttribute('Stage',stage);e:SetAttribute('SeedIndex',index);e:SetAttribute('BaseChance',odds[seed.Id]);e.Parent=catalog
 end
end
local seeds=R.new('Folder');seeds.Name='DiscoveredSeeds';seeds.Parent=player
local plants=R.new('Folder');plants.Name='DiscoveredPlants';plants.Parent=player
local function found(folder,id,cash)local v=R.new('BoolValue');v.Name=id;v.Value=true;if cash then v:SetAttribute('RewardCash',cash)end;v.Parent=folder end
for _,id in ipairs({'SunflowerSeed','BluebellSeed','AppleSeed','MooncapSeed'})do found(seeds,id,id=='MooncapSeed'and 240000 or nil)end
for _,id in ipairs({'SunflowerSeed','BluebellSeed'})do found(plants,id)end
for _,id in ipairs({'CocoaSeed','PineappleSeed','VenomVineSeed'})do found(seeds,id);found(plants,id)end
local s=R.new('LocalScript');s.Name='ChestIndex';W.load('ChestIndex',s)
W.frames(5);pg:SetAttribute('SeedMenu','Index');W.frames(20)
local gui=pg:FindFirstChild('ChestIndexGui')
local unknown={};for _,e in ipairs(catalog:GetChildren())do local id=e:GetAttribute('SeedId');local v=seeds:FindFirstChild(id);if not v then unknown[#unknown+1]=id end end
print('UNKNOWN '..table.concat(unknown,' '))
print('JSON '..dump(gui,VW,VH))
