--!nocheck
-- R137 (owner: "polish up the index"): the real ChestIndex on the mock, Forest tab open, some seeds found.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=5;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local catalog=R.new('Folder');catalog.Name='SeedCatalog';catalog.Parent=remotes
local req=R.new('RemoteFunction');req.Name='PremiumRequest';req.Parent=remotes
local calls={};function req.InvokeServer(_,action,value)calls[#calls+1]={action,value};return {Success=true,Message='Claimed!'}end
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
local s=R.new('LocalScript');s.Name='ChestIndex';W.load('ChestIndex',s)
W.frames(5);pg:SetAttribute('SeedMenu','Index');W.frames(20)
local gui=pg:FindFirstChild('ChestIndexGui');local list=gui and gui:FindFirstChild('SeedCards',true)
if not check(list,'the Index opens')then error('no index')end
local cards={};for _,c in ipairs(list:GetChildren())do if c:IsA('TextButton')then cards[#cards+1]=c end end
check(#cards==6,'six Forest cards ('..#cards..')')
table.sort(cards,function(a,b)return a.LayoutOrder<b.LayoutOrder end)
local ranks={};local sorted=true
for i,c in ipairs(cards)do local e=catalog[c.Name];ranks[i]=Rules.Rarities[e:GetAttribute('Rarity')].Rank;if i>1 and ranks[i]<ranks[i-1]then sorted=false end end
check(sorted,'cards run from Common to the rarest')
local okOdds,okRarity=true,true
for _,c in ipairs(cards)do
 local odds=c:FindFirstChild('OddsChip')and c.OddsChip:FindFirstChild('Odds');if not odds or odds.Text~=expectOdds[c.Name]or not odds.Text:match('^1/')then okOdds=false end
 local r=c:FindFirstChild('RarityChip')and c.RarityChip:FindFirstChild('Rarity');if not r or r.Text~=string.upper(catalog[c.Name]:GetAttribute('Rarity'))then okRarity=false end
end
check(okOdds,'every card shows its chance as 1/N in a chip')
check(okRarity,'every card shows its rarity in a chip')
local function chipText(c,name)local f=c:FindFirstChild(name);return f and f.Label.Text or''end
local water=list:FindFirstChild('SunflowerSeed');local apple=list:FindFirstChild('AppleSeed');local sun=list:FindFirstChild('SunflowerBloomSeed')
check(chipText(water,'SeedChip'):find('✓')and chipText(water,'GrownChip'):find('✓')and water.Reward.Text:find('COMPLETE'),'a fully found seed: SEED ✓, GROWN ✓, COMPLETE')
check(chipText(apple,'SeedChip'):find('✓')and chipText(apple,'GrownChip'):find('?'),'a seed not grown yet: SEED ✓, GROWN ?')
check(sun:FindFirstChild('Name').Text=='???'and chipText(sun,'SeedChip'):find('?'),'an unknown seed stays ??? with empty chips')
check(sun:FindFirstChild('Glow')and sun:FindFirstChild('Pedestal')and sun:FindFirstChild('Preview'),'glow, pedestal and the 3D model on every card')
local moon=list:FindFirstChild('MooncapSeed');local claimPill=moon:FindFirstChild('ClaimPill')
check(claimPill and claimPill.Reward.Text:find('^CLAIM %$'),'a reward to claim shows a gold CLAIM pill')
moon.Activated:Fire();W.frames(3)
check(calls[1]and calls[1][1]=='ClaimSeed'and calls[1][2]=='MooncapSeed','clicking it claims')
local totalText=gui:FindFirstChild('TotalFound',true)
local total=totalText and totalText.Count.Text:gsub('%s+',' ')or'' -- (the mock's text fitter adds line breaks)
check(total=='FOUND 6 / 90','the header shows everything found ('..total..')')
local forest=gui:FindFirstChild('Biome1',true);local jungle=gui:FindFirstChild('Biome6',true)
local ring=forest.BrightOutline.Color
check(ring.R==1 and ring.G==1 and ring.B==1 and forest.BrightOutline.Thickness==3 and jungle.BrightOutline.Thickness==2,'the open biome tab is ringed in white')
check(W.B.ChestIndex:find('Bright.Card(card,Theme.Rarity(rarity).Accent,selected==8,rarity)',1,true)~=nil,'cards keep their rarity border')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
