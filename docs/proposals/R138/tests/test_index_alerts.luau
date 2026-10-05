--!nocheck
-- R138 (owner: "whenever there are unclaimed rewards it notifies the player in the index and also add sfx for claiming
-- the rewards ... why is there an empty gray box above the texts in the index remove that"): the real ChestIndex on the
-- mock. Reward badges on INDEX / MENU / biome tabs, claim sounds, no pedestal box.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=5;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local catalog=R.new('Folder');catalog.Name='SeedCatalog';catalog.Parent=remotes
local req=R.new('RemoteFunction');req.Name='PremiumRequest';req.Parent=remotes
local calls={};local refuse=false
function req.InvokeServer(_,action,value)calls[#calls+1]={action,value};if refuse then return {Success=false,Message='TRY AGAIN IN A MOMENT'}end;return {Success=true,Message='Claimed!'}end
local Rules=W.module('SeedPackRules')
local config={SeedCatalogByStage=Rules.BuildSeedCatalog()}
local index=0;local expectOdds={}
for _,stage in ipairs({1,6,2,3,4,5,7})do
 local odds=Rules.SeedOdds(config,stage,'Pack01',1)
 for _,seed in ipairs(Rules.ObtainablePool(config,stage))do
  index+=1;local e=R.new('Folder');e.Name=seed.Id
  e:SetAttribute('SeedId',seed.Id);e:SetAttribute('DisplayName',seed.Name);e:SetAttribute('Rarity',(Rules.GetRarity(seed.Id)))
  e:SetAttribute('Stage',stage);e:SetAttribute('SeedIndex',index);e:SetAttribute('BaseChance',odds[seed.Id]);e.Parent=catalog
  expectOdds[seed.Id]=W.module('OddsText85').Format(odds[seed.Id])
 end
end
local seeds=R.new('Folder');seeds.Name='DiscoveredSeeds';seeds.Parent=player
local plants=R.new('Folder');plants.Name='DiscoveredPlants';plants.Parent=player
local function found(folder,id,cash)local v=R.new('BoolValue');v.Name=id;v.Value=true;if cash then v:SetAttribute('RewardCash',cash)end;v.Parent=folder end
for _,id in ipairs({'SunflowerSeed','BluebellSeed','AppleSeed','MooncapSeed'})do found(seeds,id,id=='MooncapSeed'and 240000 or nil)end
for _,id in ipairs({'SunflowerSeed','BluebellSeed'})do found(plants,id)end
local played={};W.stub('InteractionAudio',{Play=function(k)played[#played+1]=k;return true end,Preload=function()end})
local s=R.new('LocalScript');s.Name='ChestIndex';W.load('ChestIndex',s)
W.frames(10)
local gui=pg:FindFirstChild('ChestIndexGui');local toggle=pg:FindFirstChild('IndexButton',true)
-- HudLayout moves the INDEX button into its menu wheel and builds the MENU button.
local hub=pg:FindFirstChild('GardenNavigation')and pg.GardenNavigation:FindFirstChild('MenuButton')
check(toggle and hub,'INDEX in the menu wheel, MENU button built')
local function shown(b)return b and b.Visible and b.Count.Text or nil end
check(shown(toggle:FindFirstChild('RewardBadge'))=='2','two rewards waiting (Mooncap cash + Forest half-way gems): INDEX shows 2 ('..tostring(shown(toggle:FindFirstChild('RewardBadge')))..')')
check(shown(hub:FindFirstChild('IndexRewardAlert'))=='!','the MENU button shows ! while the menu is closed')
local forest=gui:FindFirstChild('Biome1',true);local jungle=gui:FindFirstChild('Biome6',true)
check(forest:FindFirstChild('RewardDot')and forest.RewardDot.Visible and not(jungle:FindFirstChild('RewardDot')and jungle.RewardDot.Visible),'a dot on the Forest tab only')
-- A new find with a reward adds to the count.
seeds.AppleSeed:SetAttribute('RewardCash',5000);W.frames(5)
check(shown(toggle.RewardBadge)=='3','a new reward bumps it to 3 ('..tostring(shown(toggle.RewardBadge))..')')
seeds.AppleSeed:SetAttribute('RewardCash',nil);W.frames(5)
-- Claiming plays a sound and the count drops.
pg:SetAttribute('SeedMenu','Index');W.frames(20)
local list=gui:FindFirstChild('SeedCards',true);local moon=list:FindFirstChild('MooncapSeed')
-- R150: a refused claim clicks Denied (never the reward cue); the gem pills press with the normal click like the seed cards (no ButtonSound=false).
refuse=true;played={};moon.Activated:Fire();W.frames(5)
check(calls[#calls]and calls[#calls][1]=='ClaimSeed'and played[#played]=='Denied'and not table.find(played,'KaChing'),'R150: a refused seed claim clicks Denied ('..table.concat(played,',')..')')
refuse=false;calls={};played={};W.frames(10)
local midBtn=gui:FindFirstChild('MiddleGem',true);local endBtn=gui:FindFirstChild('GemReward',true)
check(midBtn and endBtn and midBtn:GetAttribute('ButtonSound')==nil and endBtn:GetAttribute('ButtonSound')==nil,'R150: the halfway and completion gems keep the generic press click (they had ButtonSound=false: no press sound, only the claim cue)')
moon.Activated:Fire();seeds.MooncapSeed:SetAttribute('RewardCash',nil);W.frames(5)
check(calls[1]and calls[1][1]=='ClaimSeed'and table.find(played,'KaChing'),'claiming a cash reward rings the till (KaChing)')
check(shown(toggle.RewardBadge)=='1','one left after claiming ('..tostring(shown(toggle.RewardBadge))..')')
local middle=gui:FindFirstChild('MiddleGem',true);middle.Activated:Fire();player:SetAttribute('IndexBiomeHalfReward1',true);W.frames(5)
check(table.find(played,'GemClaim')~=nil,'claiming a gem reward plays the gem sound')
check(not toggle.RewardBadge.Visible and not hub.IndexRewardAlert.Visible and not forest.RewardDot.Visible,'nothing left: every badge goes away')
local apple=list:FindFirstChild('AppleSeed')
check(apple and not apple:FindFirstChild('Pedestal'),'no empty gray box above the names any more')
-- R150: a reward that becomes claimable AFTER the join-time burst of saved data pops its badge with the reward cue (the burst itself is silent).
played={};R.advance(7);seeds.AppleSeed:SetAttribute('RewardCash',9000);W.frames(5)
check(table.find(played,'GemClaim')~=nil,'R150: a new reward badge pops with the reward cue (GemClaim)')
played={};seeds.AppleSeed:SetAttribute('RewardCash',9500);W.frames(5)
check(table.find(played,'GemClaim')==nil,'R150: a change of the same reward is not a new one (no repeat cue)')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
