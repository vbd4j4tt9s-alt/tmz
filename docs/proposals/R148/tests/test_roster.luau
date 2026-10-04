--!nocheck
-- R148 (owner): the seed roster change, data + server side, on the Roblox mock with the real modules (SeedPackRules, Roster149,
-- DesertPlantArt149, PlantCatalog, GrowthPace125, BalanceValues81, FruitOfHour, Config, PlayerDataService, PremiumProgress, ChestService,
-- OwnerUpdateCommands82, StudioTestCommands, RarePackTests, StudioTestHelp):
--  Desert gets a Rare "Aloe" (DesertAloeSeed) and a Legendary "Sand Fruit" round cactus (SandFruitSeed); Fire Pepper becomes Lava's Mythic (x2 size,
--  more cash); Moon Melon becomes Crystal's Legendary. Owner decisions on top of the plan: banked packs get NO windfall (a pack made before
--  the update cannot roll Fire Pepper or Moon Melon at all: the seeds of their old Rare tier absorb the share) and the Rare Aloe out-earns the
--  Uncommon Prickly Pear (Value 1.0e7).
--  1. constants and catalogs: 54 designs (Verity last), the two specs, the promoted rarities, Desert's 10 save slots / 7 obtainable seeds,
--     retired ids still decode, "Aloe Sprout", Config.Validate, ProfileVersion 22;
--  2. the plants: the exact numbers (and the pacing leaves them alone), Fire Pepper exactly x2, geometry = DesertPlantArt149, ladders;
--  3. odds: every v149 row of the plan's tables, 137 = 149 where the roster is the same, Void / Verity / Mech unchanged, banked packs (none rolls a new
--     or a promoted seed; their old tier-mates absorb the share), the hold tooltip (sorted by rarity, then name), 1M Monte Carlo rolls;
--  4. PlayerDataService: save / load / gift of 149 packs and the new seeds, planting and harvesting them, a Fire Pepper crop saved under the
--     old catalog, ProfileVersion 22 and a version-23 save;
--  5. the Index: first / repeat cash, BaseChance, milestones: a player who had reached one under the old 5-seed Desert roster keeps it (a saved flag), a new
--     player needs all seven seeds, nothing is claimed twice;
--  6. the owner commands (rarepacks roster, seed, seeds, odds) and the help row;
--  7. Fruit of the Hour: 53 candidates.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,rel)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(rel or 1e-12)*math.max(1,math.abs(b))end
local function relnear(a,b,rel)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(rel or 2e-5)*math.abs(b)+1e-12 end
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={};local order={}
function Players.GetPlayers()local out={};for _,p in ipairs(order)do if present[p.UserId]==p then out[#out+1]=p end end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
local DS=W.service('DataStoreService');local stores={}
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(self.Data[key],nil);if v~=nil then self.Data[key]=v end;return self.Data[key]end,
  GetAsync=function(self,key)return self.Data[key]end,SetAsync=function(self,key,v)self.Data[key]=v end}
 return stores[name]
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
W.stub('OwnerCommandAccess',{IsAllowed=function(p)return Run.IsStudio()and p~=nil end}) -- (allowed while the test says it is Studio)
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do if n~='OwnerCommandAccess'then RS[n].Parent=folder end end
RS.OwnerCommandAccess.Parent=folder
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 return o end end
local Config=server('Config');local Rules=W.module('SeedPackRules');local R149=W.module('Roster149');local Art=W.module('DesertPlantArt149')
local T=W.module('BalanceValues81');local Pace=W.module('GrowthPace125');local Hour=W.module('FruitOfHour');local Odds=W.module('OddsText85')
local O137=W.module('PackOdds137');local Void=W.module('VoidPackOdds85')
local function ids(list)local out={};for i,x in ipairs(list)do out[i]=x.Id end;return out end
local function join(list)return table.concat(list,',')end
local function sorted(list)local c=table.clone(list);table.sort(c);return c end
local function equalOdds(a,b)for k,v in pairs(a)do if math.abs((b[k]or 0)-v)>1e-12 then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
local function drawConstant(x)return function()return x end end

-- 1. Constants and catalogs ---------------------------------------------------------------------------------------------------
do
check(#Rules.SeedDesigns==54 and Rules.SeedDesigns[#Rules.SeedDesigns].id=='VeritySeed','54 designs = 47 biome + 6 Mech + Verity, Verity still last')
local aloe,sand=Rules.SeedDesignById.DesertAloeSeed,Rules.SeedDesignById.SandFruitSeed
check(aloe and aloe.stage==2 and aloe.SaveStage==2 and aloe.index==9 and aloe.biome=='Desert'and aloe.rarity=='Rare'and aloe.name=='Aloe'and aloe.pattern=='Dots'
 and aloe.top=='4a9e88'and aloe.bottom=='c3dcc0'and aloe.ink=='f2f6e6'and aloe.addition=='none','the Aloe spec: Desert save slot 9, Rare, "Aloe", rich sea green / pale sage / cream, Dots')
check(sand and sand.stage==2 and sand.SaveStage==2 and sand.index==10 and sand.biome=='Desert'and sand.rarity=='Legendary'and sand.name=='Sand Fruit'and sand.pattern=='Specks'
 and sand.top=='d6a35c'and sand.bottom=='f6e3b4'and sand.ink=='a8733c'and sand.addition=='none','the Sand Fruit spec: Desert save slot 10, Legendary, "Sand Fruit", sand gold / warm cream, sandy Specks')
check(Rules.SeedRarityById.DesertAloeSeed=='Rare'and Rules.SeedRarityById.SandFruitSeed=='Legendary'and Rules.GetRarity('DesertAloeSeed')=='Rare'and Rules.GetRarity('SandFruitSeed')=='Legendary','GetRarity: Aloe Rare, Sand Fruit Legendary')
check(Rules.GetRarity('FirePepperSeed')=='Mythic'and Rules.GetRarity('MoonflowerSeed')=='Legendary'and Rules.SeedRarityById.FirePepperSeed=='Mythic'and Rules.SeedRarityById.MoonflowerSeed=='Legendary'
 and Rules.SeedDesignById.FirePepperSeed.rarity=='Mythic'and Rules.SeedDesignById.MoonflowerSeed.rarity=='Legendary','GetRarity: Fire Pepper Mythic, Moon Melon Legendary (the design rows follow)')
check(Rules.SeedDesignById.FirePepperSeed.design:find('flame wisps',1,true)~=nil and Rules.SeedDesignById.FirePepperSeed.top=='c63929'and Rules.SeedDesignById.FirePepperSeed.bottom=='ffb45b'and Rules.SeedDesignById.FirePepperSeed.ink=='ffedac'
 and Rules.SeedDesignById.FirePepperSeed.pattern=='Specks','Fire Pepper keeps its colours and pattern; its design text mentions the flame wisps')
check(Rules.NewInR149.DesertAloeSeed==true and Rules.NewInR149.SandFruitSeed==true and Rules.PromotedInR149.FirePepperSeed=='Mythic'and Rules.PromotedInR149.MoonflowerSeed=='Legendary'and Rules.RarityBeforeR149==nil,
 'Rules.NewInR149 = the two new seeds; Rules.PromotedInR149 = Fire Pepper (Mythic) and Moon Melon (Legendary); no per-version rarity table (owner: banked packs cannot roll the promoted seeds at all)')
-- Retired ids keep their identity and still decode.
for _,id in ipairs({'AgaveSeed','DesertRoseSeed','AloeSeed','SunKingPalmSeed'})do
 check(Rules.IsRetired(id)==true and Config.GetSeedById(id)~=nil,id..' is still retired and still decodes (GetSeedById)')
end
check(Rules.IsRetired('DesertAloeSeed')==false and Rules.IsRetired('SandFruitSeed')==false,'the new ids are not retired')
check(Rules.SeedDesignById.AloeSeed.name=='Aloe Sprout'and Rules.SeedDesignById.AloeSeed.SaveStage==2 and Rules.SeedDesignById.AloeSeed.index==2 and Config.GetSeedById('AloeSeed').Name=='Aloe Sprout Seed',
 'the retired Uncommon AloeSeed shows as "Aloe Sprout Seed" (id and slot unchanged)')
check(Config.GetSeedById('DesertAloeSeed').Name=='Aloe Seed'and Config.GetSeedById('SandFruitSeed').Name=='Sand Fruit Seed','catalog names: "Aloe Seed" and "Sand Fruit Seed"')
local _,stageA,indexA=Config.GetSeedById('DesertAloeSeed');local _,stageS,indexS=Config.GetSeedById('SandFruitSeed')
check(stageA==2 and indexA==9 and stageS==2 and indexS==10,'GetSeedById: stage 2, slots 9 and 10')
-- Catalog by stage.
check(join(ids(Config.SeedCatalogByStage[2]))=='CactusSeed,AloeSeed,DesertRoseSeed,AgaveSeed,DatePalmSeed,MirageFigSeed,SolarStarfruitSeed,SunKingPalmSeed,DesertAloeSeed,SandFruitSeed',
 'SeedCatalogByStage[2]: the eight old slots in order, then the Aloe (9) and the Sand Fruit (10)')
local sizes={};for st=1,9 do sizes[st]=#Config.SeedCatalogByStage[st]end
check(join(sizes)=='8,10,8,8,8,8,8,6,1','catalog sizes by stage: 8,10,8,8,8,8,8,6,1 (only Desert grew)')
check(pcall(Config.Validate),'Config.Validate passes (Desert may hold ten seeds)')
local pool2=Rules.ObtainablePool(Config,2)
check(#pool2==7 and join(sorted(ids(pool2)))=='CactusSeed,DatePalmSeed,DesertAloeSeed,MirageFigSeed,SandFruitSeed,SolarStarfruitSeed,StarfruitSeed','ObtainablePool(2): 7 seeds, the five old ones plus the Aloe and the Sand Fruit')
local pool4,pool5=Rules.ObtainablePool(Config,4),Rules.ObtainablePool(Config,5)
check(join(sorted(ids(pool4)))=='AshRoseSeed,EmberBloomSeed,EmberEmperorSeed,FirePepperSeed,LavaLotusSeed,ObsidianMawSeed,SupernovaBloomSeed'
 and join(sorted(ids(pool5)))=='AmethystSeed,DiamondVineSeed,HollowGeodeSeed,MoonflowerSeed,OrbitLotusSeed,PrismMonarchSeed,PrismOrchidSeed','Lava and Crystal pools: the same 7 seeds each as before')
for _,st in ipairs({1,3,6,7})do check(#Rules.ObtainablePool(Config,st)==({[1]=6,[3]=7,[6]=6,[7]=7})[st],'pool '..st..' unchanged')end
check(Rules.ObtainableStage('DesertAloeSeed')==2 and Rules.ObtainableStage('SandFruitSeed')==2,'obtain stage 2 for both')
check(Config.ProfileVersion==22,'ProfileVersion 22 (one more than R147\'s 21)')
check(Rules.OddsVersion==149 and Rules.ValidOddsVersion(149)==true and Rules.ValidOddsVersion(137)and Rules.ValidOddsVersion(112)and Rules.ValidOddsVersion(81)and not Rules.ValidOddsVersion(150)and not Rules.ValidOddsVersion(148),
 'OddsVersion 149, valid; 81 / 112 / 137 still valid; 148 and 150 are not')
end

-- 2. The plants ------------------------------------------------------------------------------------------------------------------
local P=Config.GardenPlants
do
local a,s,f,m=P.DesertAloeSeed,P.SandFruitSeed,P.FirePepperSeed,P.MoonflowerSeed
check(a and a.Name=='Aloe'and a.HarvestName=='Aloe bloom'and a.Biome=='Desert'and a.Stage==2 and a.Rarity=='Rare'and a.Rank==3 and a.Tree==false and a.Mode=='repeat'and a.FruitCount==3
 and a.Seconds==960 and a.RegrowSeconds==530 and a.Value==10000000 and a.Roster149==true and a.BaseScale==1,'Aloe: Rare, 3 flower spikes, 960 s / regrow 530 s, 10,000,000 per fruit, flagged Roster149')
check(s and s.Name=='Sand Fruit'and s.HarvestName=='Sand fruit'and s.Biome=='Desert'and s.Stage==2 and s.Rarity=='Legendary'and s.Rank==4 and s.Tree==false and s.Mode=='repeat'and s.FruitCount==4
 and s.Seconds==2760 and s.RegrowSeconds==1520 and s.Value==26400000 and s.Roster149==true and s.BaseScale==1,'Sand Fruit: Legendary round cactus (not a tree: no trunk collision), 4 sand fruits, 2760 s / regrow 1520 s, 26,400,000 per fruit')
check(f.Rarity=='Mythic'and f.Rank==5 and f.Seconds==4300 and f.RegrowSeconds==2370 and f.Value==285000000 and f.FruitCount==4 and f.Roster149==true and f.Name=='Fire Pepper'and f.HarvestName=='Fire pepper',
 'Fire Pepper: Mythic, 4300 s / regrow 2370 s, 285,000,000, FruitCount stays 4 (a saved crop validates its FruitStates against it)')
check(m.Rarity=='Legendary'and m.Rank==4 and m.Seconds==3400 and m.RegrowSeconds==1870 and m.Value==509000000 and m.FruitCount==2 and m.Roster149==true and m.Name=='Moon Melon',
 'Moon Melon: Legendary, 3400 s / regrow 1870 s, 509,000,000, FruitCount stays 2')
for _,id in ipairs({'DesertAloeSeed','SandFruitSeed','FirePepperSeed','MoonflowerSeed'})do
 local d=P[id]
 check(d.BaseSeconds==nil and d.GrowthFactor==nil,id..': no pacing marks (BaseSeconds / GrowthFactor): its numbers are Roster149\'s final ones, written after GrowthPace125')
 check(d.FruitCount==#d.Sockets and #d.FruitCenters==d.FruitCount and #d.FruitRadii==d.FruitCount,id..': sockets, fruit centres and radii match FruitCount')
end
-- The ORDER keeps the pacing off them (PlantCatalog applies Roster149 after GrowthPace125; the Roster149 flag is not an exemption any more):
-- every other paced plant still has its pacing marks, and GrowthPace125.Exempt does not look at the flag.
check(Pace.Exempt({Rarity='Rare',Roster149=true})==false,'GrowthPace125.Exempt ignores the Roster149 flag (the dead exemption is gone)')
local pacedOk,paced=true,0
for id,d in pairs(P)do if type(d)=='table'and d.Roster149~=true and d.BaseSeconds~=nil then paced+=1;if d.GrowthFactor==nil then pacedOk=false end end end
check(pacedOk and paced==38,'the other 38 paced plants keep their pacing marks ('..paced..')')
local flagged=0;for _,d in pairs(P)do if type(d)=='table'and d.Roster149==true then flagged+=1 end end
check(flagged==4,'exactly four plants carry Roster149')
-- Fire Pepper: exactly twice the base (base: H 6.3090, R 3.1725, socket 4 at (1.34, 2.65, -1.10), radius 1.6046).
check(near(f.Height,2*6.309,3e-4)and near(f.Radius,2*3.1725,3e-4),('Fire Pepper Height / Radius are x2 (%.4f / %.4f)'):format(f.Height,f.Radius))
local s4,c4=f.Sockets[4],f.FruitCenters[4]
check(near(s4[1],2*1.34,1e-3)and near(s4[2],2*2.65,1e-3)and near(s4[3],2*-1.10,1e-3)and near(f.FruitRadii[4],2*1.6046,1e-3),('Fire Pepper socket 4 and its radius are x2 (%.3f, %.3f, %.3f / %.4f)'):format(s4[1],s4[2],s4[3],f.FruitRadii[4]))
-- ... and the tables are new ones (the approved catalog's are never mutated in place).
local approvedCatalog=W.module('ApprovedPlantCatalog')
check(approvedCatalog.FirePepperSeed and approvedCatalog.FirePepperSeed.Height~=f.Height and approvedCatalog.FirePepperSeed.Sockets~=f.Sockets and near(approvedCatalog.FirePepperSeed.Height*2,f.Height,3e-4),
 'ApprovedPlantCatalog.FirePepperSeed still has the base size (the plant catalog got its own x2 copy)')
local pp=P.PrismOrchidSeed
check(near(pp.Height,approvedCatalog.PrismOrchidSeed.Height,1e-9)and pp.Rarity=='Rare'and pp.Value==76179861,'Prism Pepper (same meshes, other module) is not scaled')
-- New plants' geometry = DesertPlantArt149: the sockets are design 1's (a crop's own come from its design); the bounds are the biggest of the four designs x 1.05,
-- the margin the approved plants' bounds carry for the per-crop size jitter (Fire Pepper: 6.009 x 1.05 x 2).
for _,id in ipairs({'DesertAloeSeed','SandFruitSeed'})do
 local d,art=P[id],Art.Get(id);local maxH,maxR=0,0
 for _,design in ipairs(Art.Designs(id))do maxH=math.max(maxH,design.Height);maxR=math.max(maxR,design.Radius)end
 local sameGeo=#Art.Designs(id)==4 and near(d.Height,maxH*1.05,1e-12)and near(d.Radius,maxR*1.05,1e-12)and d.AuthoredHeight==d.Height
 for i=1,d.FruitCount do for k=1,3 do sameGeo=sameGeo and near(d.Sockets[i][k],art.Sockets[i][k],1e-12)and near(d.FruitCenters[i][k],art.FruitCenters[i][k],1e-12)end;sameGeo=sameGeo and d.FruitRadii[i]==art.FruitRadii[i]end
 check(sameGeo,id..': 4 designs; Height / Radius = the biggest design x 1.05; Sockets / FruitCenters / FruitRadii = design 1\'s (DesertPlantArt149)')
end
local aloe1,sand1=Art.Get('DesertAloeSeed'),Art.Get('SandFruitSeed')
check(near(aloe1.Height,8.261,1e-9)and near(aloe1.Radius,5.211,1e-9)and near(sand1.Height,10.607,1e-9)and near(sand1.Radius,6.777,1e-9),'design 1 bounds: Aloe 8.261 / 5.211, Sand Fruit 10.607 / 6.777 (the base designs)')
check(near(a.Height,9.822*1.05,1e-9)and near(a.Radius,5.485*1.05,1e-9)and near(s.Height,13.979*1.05,1e-9)and near(s.Radius,8.075*1.05,1e-9),'catalog bounds: Aloe 10.313 / 5.759 (the tall design x 1.05), Sand Fruit 14.678 / 8.479 (the tall and the squat design x 1.05)')
check(#Art.Get('DesertAloeSeed').Specs==127 and #Art.Get('SandFruitSeed').Specs==95,'127 and 95 art parts')
-- Saving rules: integers, within the per-fruit cap, times within a day.
for _,id in ipairs({'DesertAloeSeed','SandFruitSeed','FirePepperSeed','MoonflowerSeed'})do
 local d=P[id]
 check(d.Value%1==0 and d.Value>0 and d.Value<=Pace.MaxValue and d.Value*100<=9e12 and d.Seconds%1==0 and d.Seconds<=86400 and d.RegrowSeconds%1==0 and d.RegrowSeconds<=86400,id..': integer value within the 9e10 per-fruit cap, times within 24 h')
end
-- The income ladders (value per hour = Value x FruitCount / RegrowSeconds x 3600) are strictly increasing, as the plan says.
local function income(id)local d=P[id];return d.Value*d.FruitCount/(d.Regrows==false and d.Seconds or d.RegrowSeconds)*3600 end -- (a single-harvest plant, like Lava Lotus, earns once per growth)
local function ladder(label,list)
 local good=true;for i=2,#list do if not(income(list[i])>income(list[i-1]))then good=false;print('  not increasing at '..list[i-1]..' -> '..list[i])end end
 check(good,label..' ladder strictly increases ('..string.format('%.3g',income(list[1]))..' ... '..string.format('%.3g',income(list[#list]))..' per hour)')
end
ladder('Desert',{'DesertAloeSeed','SandFruitSeed','DatePalmSeed','StarfruitSeed','MirageFigSeed','SolarStarfruitSeed'})
ladder('Rare',{'VenomVineSeed','DesertAloeSeed','IceberrySeed','EmberBloomSeed','AmethystSeed','SparkReedSeed'})
ladder('Lava',{'EmberBloomSeed','LavaLotusSeed','FirePepperSeed','ObsidianMawSeed','SupernovaBloomSeed','EmberEmperorSeed'})
ladder('Mythic',{'AncientWorldrootSeed','DatePalmSeed','CrystalLilySeed','FirePepperSeed','DiamondVineSeed','TempestLotusSeed'})
ladder('Crystal',{'AmethystSeed','MoonflowerSeed','DiamondVineSeed','HollowGeodeSeed'})
ladder('Legendary',{'TigerOrchidSeed','SandFruitSeed','WinterPineSeed','LavaLotusSeed','MoonflowerSeed','VoltOrchidSeed'})
check(near(income('DesertAloeSeed'),1e7*3/530*3600,1e-12)and income('DesertAloeSeed')>2.0377e8 and income('DesertAloeSeed')<2.0378e8,('Aloe earns %.4g per hour'):format(income('DesertAloeSeed')))
check(income('DesertAloeSeed')>income('CactusSeed'),('OWNER: the Rare Aloe out-earns the Uncommon Prickly Pear per hour (%.5g vs %.5g, +%.1f%%)'):format(income('DesertAloeSeed'),income('CactusSeed'),(income('DesertAloeSeed')/income('CactusSeed')-1)*100))
check(9.9e6*3/530*3600>income('CactusSeed')and 9.8e6*3/530*3600<income('CactusSeed'),'(the plan\'s threshold: 9.9e6 per fruit is the least that does it)')
check(income('DesertAloeSeed')<income('IceberrySeed')and income('DesertAloeSeed')<income('SandFruitSeed'),'... and the Aloe still earns less than Iceberry and than the Sand Fruit')
check(income('FirePepperSeed')>5e8*3 and near(income('FirePepperSeed'),285e6*4/2370*3600,1e-12)and near(income('MoonflowerSeed'),509e6*2/1870*3600,1e-12),
 ('Fire Pepper %.3g and Moon Melon %.3g per hour (the plan: 1.73e9 and 1.96e9)'):format(income('FirePepperSeed'),income('MoonflowerSeed')))
check(near(income('SandFruitSeed'),2.5e8,2e-3)and near(income('FirePepperSeed'),1.73e9,2e-3)and near(income('MoonflowerSeed'),1.96e9,2e-3),'income per hour as in the plan: Sand Fruit 2.50e8, Fire Pepper 1.73e9, Moon Melon 1.96e9')
-- Index cash.
check(T.IndexFirst.DesertAloeSeed==10000000 and T.IndexRepeat.DesertAloeSeed==2000000 and T.IndexFirst.DesertAloeSeed==P.DesertAloeSeed.Value and T.IndexRepeat.DesertAloeSeed==P.DesertAloeSeed.Value/5,
 'Aloe index cash: one base fruit (1e7) first, a fifth (2e6) on a repeat (OWNER: derived from the 1.0e7 fruit)')
check(T.IndexFirst.SandFruitSeed==26400000 and T.IndexRepeat.SandFruitSeed==5280000 and T.IndexFirst.SandFruitSeed==P.SandFruitSeed.Value and T.IndexRepeat.SandFruitSeed==P.SandFruitSeed.Value/5,'Sand Fruit index cash: 26,400,000 first / 5,280,000 repeat (one base fruit / a fifth)')
check(T.IndexFirst.FirePepperSeed==360000000 and T.IndexRepeat.FirePepperSeed==72000000 and T.IndexFirst.MoonflowerSeed==475000000 and T.IndexRepeat.MoonflowerSeed==95000000,'Fire Pepper 360M / 72M, Moon Melon 475M / 95M index cash')
check(T.SeedValues.DesertAloeSeed==nil and T.SeedValues.SandFruitSeed==nil,'the new ids are NOT in BalanceValues81.SeedValues (the PlantCatalog loop asserts a plant exists for each)')
check(T.CompletionGems[2]==20 and T.CompletionGems[4]==20 and T.CompletionGems[5]==20 and T.HalfwayGems==10,'completion / halfway Gems unchanged')
end

-- 3. Odds -----------------------------------------------------------------------------------------------------------------------------
local PACKS={'Pack01','Pack02','Pack03','Pack04','Pack05','Pack06'}
-- The plan's section 4 tables: percent per seed for Pack01..Pack06 of a NEW (149) pack, boots x1 (the plan prints 6 digits).
local E={
 Desert={CactusSeed={86.2121,77.3359,54.0664,0,0,0},DesertAloeSeed={12.5,20,40,78.1313,66.894,0},SandFruitSeed={1.11111,2.22222,4.7619,16.6667,20,77.98},
  DatePalmSeed={.166667,.416667,1.11111,5,12.5,20},StarfruitSeed={.01,.025,.06,.2,.6,2},MirageFigSeed={1e-4,2.5e-4,6e-4,2e-3,6e-3,.02},SolarStarfruitSeed={1e-10,2.5e-10,6e-10,2e-9,6e-9,2e-8}},
 Lava={EmberBloomSeed={49.5158,48.9978,47.7673,41.2323,36.697,0},AshRoseSeed={49.5158,48.9978,47.7673,41.2323,36.697,0},LavaLotusSeed={.833333,1.66667,3.57143,13.3333,16,81.98},
  FirePepperSeed={.125,.3125,.833333,4,10,16},ObsidianMawSeed={.01,.025,.06,.2,.6,2},SupernovaBloomSeed={1e-4,2.5e-4,6e-4,2e-3,6e-3,.02},EmberEmperorSeed={1e-10,2.5e-10,6e-10,2e-9,6e-9,2e-8}},
 Crystal={AmethystSeed={49.6116,49.1957,48.2078,42.6768,38.8637,0},PrismOrchidSeed={49.6116,49.1957,48.2078,42.6768,38.8637,0},MoonflowerSeed={.666667,1.33333,2.85714,11.1111,13.3333,84.6467},
  DiamondVineSeed={.1,.25,.666667,3.33333,8.33333,13.3333},HollowGeodeSeed={.01,.025,.06,.2,.6,2},OrbitLotusSeed={1e-4,2.5e-4,6e-4,2e-3,6e-3,.02},PrismMonarchSeed={1e-10,2.5e-10,6e-10,2e-9,6e-9,2e-8}},
}
local STAGE={Desert=2,Lava=4,Crystal=5}
do
for biome,rows in pairs(E)do
 local wrong={}
 for p,pack in ipairs(PACKS)do
  local odds=Rules.SeedOdds(Config,STAGE[biome],pack,1,149)
  local sum=0
  for id,list in pairs(rows)do
   local got=odds[id]or 0;sum+=got
   if not(relnear(got,list[p],3e-5)or(list[p]==0 and got==0))then wrong[#wrong+1]=('%s %s %s: %.10g want %.10g'):format(biome,pack,id,got,list[p])end
  end
  for id in pairs(odds)do if rows[id]==nil then wrong[#wrong+1]='unexpected seed '..id end end
  if not near(sum,100,1e-9)then wrong[#wrong+1]=biome..' '..pack..' adds up to '..sum end
 end
 check(#wrong==0,'v149 '..biome..': all 6 packs x '..#(function()local n={};for id in pairs(rows)do n[#n+1]=id end;return n end)()..' seeds match the plan\'s table, each pack adds up to 100% ('..table.concat(wrong,'; ')..')')
end
-- Version nil is "current" (149) and a 149 pack passes PackOdds137's numbers down.
local same=true
for _,st in ipairs({1,2,3,4,5,6,7})do for _,pack in ipairs(PACKS)do for _,luck in ipairs({1,50,5e7})do for _,boost in ipairs({0,2})do
 if not equalOdds(Rules.SeedOdds(Config,st,pack,luck,149,boost==2 and 2 or nil),Rules.SeedOdds(Config,st,pack,luck,nil,boost==2 and 2 or nil))then same=false end
end end end end
check(same,'odds with no version = odds at 149 (the Index chips and the hold tooltip read "current")')
-- A 149 pack = a 137 pack wherever the roster is the same (Forest, Snow, Jungle, Storm). Desert grew; Lava and Crystal promoted a seed.
local eq137,diffs=true,{}
for _,st in ipairs({1,3,6,7})do for _,pack in ipairs(PACKS)do for _,luck in ipairs({1,50,1e6,5e7})do for _,boost in ipairs({0,2})do
 if not equalOdds(Rules.SeedOdds(Config,st,pack,luck,149,boost==2 and 2 or nil),Rules.SeedOdds(Config,st,pack,luck,137,boost==2 and 2 or nil))then eq137=false;diffs[#diffs+1]=st..'/'..pack end
end end end end
check(eq137,'stages 1 / 3 / 6 / 7 at 149 equal 137 (the roster is the same there) '..table.concat(diffs,' '))
local deserts=true
for _,pack in ipairs(PACKS)do local old=Rules.SeedOdds(Config,2,pack,1,137);if old.DesertAloeSeed~=nil or old.SandFruitSeed~=nil then deserts=false end end
check(deserts,'a banked 137 Desert pack lists no Aloe and no Sand Fruit')
-- Banked Desert packs: every row exactly as before (the old five seeds, the old tier math): the numbers of R137 (plan: "Desert before (137)").
local banked=Rules.SeedOdds(Config,2,'Pack01',1,137)
check(relnear(banked.CactusSeed,99.8232,3e-5)and relnear(Rules.SeedOdds(Config,2,'Pack02',1,137).CactusSeed,99.5581,3e-5)and relnear(Rules.SeedOdds(Config,2,'Pack03',1,137).CactusSeed,98.8283,3e-5)
 and relnear(Rules.SeedOdds(Config,2,'Pack04',1,137).CactusSeed,94.798,3e-5)and relnear(Rules.SeedOdds(Config,2,'Pack05',1,137).CactusSeed,86.894,3e-5)and relnear(Rules.SeedOdds(Config,2,'Pack06',1,137).CactusSeed,77.98,3e-5),
 'banked 137 Desert: Prickly Pear 99.8232 / 99.5581 / 98.8283 / 94.798 / 86.894 / 77.98 (the plan\'s "Desert before")')
-- Void / Verity / Mech: identical for every version.
local voidV={};for _,v in ipairs({'nil',0,81,112,137,149})do voidV[v]=Rules.SeedOdds(Config,7,'EclipseReliquary',1,v~='nil'and v or nil)end
check(equalOdds(voidV['nil'],voidV[112])and equalOdds(voidV[112],voidV[137])and equalOdds(voidV[137],voidV[149]),'Void odds: nil = 112 = 137 = 149 (a 149 Void pack rolls the 137 odds, byte for byte)')
check(equalOdds(voidV[0],voidV[81])and not equalOdds(voidV[0],voidV[137]),'Void odds: 0 = 81 (the old table), different from 137')
local verityOk,mechOk=true,true
local v0=Rules.SeedOdds(Config,7,'VerityReliquary',1);local m0=Rules.SeedOdds(Config,8,'MechLimited',1)
for _,v in ipairs({0,81,112,137,149})do
 if not equalOdds(Rules.SeedOdds(Config,7,'VerityReliquary',1,v),v0)then verityOk=false end
 if not equalOdds(Rules.SeedOdds(Config,8,'MechLimited',1,v),m0)then mechOk=false end
end
check(verityOk and mechOk and next(v0)~=nil and next(m0)~=nil,'Verity and Mech odds: the same for every version, including 149')
-- No new seed is Secret or better, so the Void / Verity pools are the same as before.
local voidPool,voidAll=Void.Pools(Config,Rules)
local leaked=false;for _,seed in ipairs(voidAll or voidPool or{})do if seed.Id=='DesertAloeSeed'or seed.Id=='SandFruitSeed'or seed.Id=='FirePepperSeed'or seed.Id=='MoonflowerSeed'then leaked=true end end
check(not leaked,'the Void pool never contains the four roster seeds')
end

-- Banked Lava / Crystal packs (owner: NO windfall): a pack made before the update cannot roll Fire Pepper or Moon Melon at all. The seeds of their old
-- Rare tier absorb the share; every other seed keeps exactly the odds it had (the regression diff against the base commit proves it for every version,
-- variant, luck level and boost; here the numbers are pinned).
do
-- Pinned (percent, luck 1, boots x1): the old Rare tier's seeds in a Common pack of each banked odds version, before the update and now.
local pinned={ -- {Ember/Ash before, now, Amethyst/Prism Orchid before, now}
 [0]={25,37.5,30.3030303030,45.4545454545},[81]={31.3333333333,47,31.3333333333,47},[112]={32.2188555555,48.3282833333,32.0521888889,48.0782833333},[137]={33.0521888889,49.5782833333,33.2966333333,49.9449499999}}
for _,ver in ipairs({0,81,112,137})do
 local lava=Rules.SeedOdds(Config,4,'Pack01',1,ver);local crystal=Rules.SeedOdds(Config,5,'Pack01',1,ver);local want=pinned[ver]
 check(lava.FirePepperSeed==nil and crystal.MoonflowerSeed==nil and near(lava.EmberBloomSeed,want[2],1e-9)and near(lava.AshRoseSeed,want[2],1e-9)and near(crystal.AmethystSeed,want[4],1e-9)and near(crystal.PrismOrchidSeed,want[4],1e-9),
  ('banked %d Common packs: no Fire Pepper, no Moon Melon; Ember / Ash %.4f%% (was %.4f%%), Amethyst / Orchid %.4f%% (was %.4f%%)'):format(ver,lava.EmberBloomSeed or 0,want[1],crystal.AmethystSeed or 0,want[3]))
end
local lavaCommon,crystalCommon=Rules.SeedOdds(Config,4,'Pack01',1,137),Rules.SeedOdds(Config,5,'Pack01',1,137)
check(near(lavaCommon.LavaLotusSeed,.833333333333,1e-9)and lavaCommon.ObsidianMawSeed==.01 and near(lavaCommon.SupernovaBloomSeed,1e-4,1e-12)and near(lavaCommon.EmberEmperorSeed,1e-10,1e-12)
 and near(crystalCommon.DiamondVineSeed,.1,1e-9)and crystalCommon.HollowGeodeSeed==.01 and near(crystalCommon.OrbitLotusSeed,1e-4,1e-12)and near(crystalCommon.PrismMonarchSeed,1e-10,1e-12),
 'banked 137 Common packs: every seed above the old Rare tier (Lava Lotus, Obsidian, Boom Bloom, Ember Emperor; Diamond Vine, Geode, Orbit Lotus, Monarch) has exactly the odds it had')
-- A banked Mythic pack: Crystal = the old numbers with Moon Melon taken out; Lava (where Fire Pepper was never in a Mythic pack) is exactly as it was.
local lavaMythic=Rules.SeedOdds(Config,4,'Pack06',1,137);local crystalMythic=Rules.SeedOdds(Config,5,'Pack06',1,137)
check(lavaMythic.FirePepperSeed==nil and near(lavaMythic.LavaLotusSeed,97.97999998,1e-9)and near(lavaMythic.ObsidianMawSeed,2,1e-12)and near(crystalMythic.AmethystSeed,42.3233333233,1e-9)and near(crystalMythic.PrismOrchidSeed,42.3233333233,1e-9)
 and near(crystalMythic.DiamondVineSeed,13.3333333333,1e-9)and crystalMythic.MoonflowerSeed==nil,
 'banked 137 Mythic packs: Lava as before (97.98% Lava Lotus), Crystal Amethyst / Orchid 42.3233% (was 28.2156%) without Moon Melon')
-- Every banked version x variant x luck x boost: no promoted or new seed, adds up to 100%.
local bad={}
for _,st in ipairs({4,5})do for _,ver in ipairs({0,81,112,137})do for _,pack in ipairs({'Pack01','Pack02','Pack03','Pack04','Pack05','Pack06','Small','Standard','Grand'})do for _,luck in ipairs({1,50,1e6,5e7})do for _,boost in ipairs({0,2})do
 local odds=Rules.SeedOdds(Config,st,pack,luck,ver,boost==2 and 2 or nil);local sum=0;for _,p in pairs(odds)do sum+=p end
 if odds.FirePepperSeed~=nil or odds.MoonflowerSeed~=nil or odds.DesertAloeSeed~=nil or odds.SandFruitSeed~=nil or not near(sum,100,1e-9)then bad[#bad+1]=st..'/'..ver..'/'..pack..'/'..luck..'/'..boost end
end end end end end
check(#bad==0,'every banked Lava / Crystal row (4 versions x 9 variants x 4 luck x 2 boosts): no Fire Pepper, no Moon Melon, no new seed, 100% ('..table.concat(bad,' ',1,math.min(#bad,4))..')')
-- No banked roll ever gives a promoted or new seed, at any draw, version or variant.
local leaked={}
for _,st in ipairs({2,4,5})do for _,ver in ipairs({'nil',0,81,112,137})do for _,pack in ipairs({'Pack01','Pack03','Pack06'})do
 for step=0,2000 do
  local seed,label=Rules.Roll(Config,st,drawConstant(step/2000),1,pack,ver~='nil'and ver or nil)
  if seed and(seed.Id=='FirePepperSeed'or seed.Id=='MoonflowerSeed'or seed.Id=='DesertAloeSeed'or seed.Id=='SandFruitSeed')then leaked[#leaked+1]=st..'/'..tostring(ver)..'/'..pack..'/'..seed.Id end
  if seed and label~=Rules.GetRarity(seed.Id)then leaked[#leaked+1]='label '..seed.Id end
 end
end end end
check(#leaked==0,'banked rolls (Desert, Lava, Crystal x versions none / 0 / 81 / 112 / 137 x Pack01 / 03 / 06 x 2001 draws): never a promoted or new seed, labels as the live rarity ('..table.concat(leaked,' ',1,math.min(#leaked,3))..')')
-- The live roster still has them (the legacy scope is closed again), and a new (149) pack has them at the new tiers.
check(Rules.SeedOdds(Config,4,'Pack06',1,149).FirePepperSeed==16 and relnear(Rules.SeedOdds(Config,5,'Pack06',1,149).MoonflowerSeed,84.6467,5e-6)and Rules.GetRarity('FirePepperSeed')=='Mythic'and Rules.GetRarity('MoonflowerSeed')=='Legendary',
 'a new (149) Mythic pack still has Fire Pepper 16% / Moon Melon 84.65%, after all those banked ones (Mythic / Legendary)')
end

-- Monte Carlo: the real rolls follow the tables. 1,000,000 math.random rolls each.
do
math.randomseed(149)
local N=1000000
local function sample(stage,pack,version,luck)
 local counts,labels={},{};luck=luck or 1
 for _=1,N do
  local seed,rarity=Rules.Roll(Config,stage,math.random,luck,pack,version)
  local id=seed and seed.Id or'nil';counts[id]=(counts[id]or 0)+1;labels[id..':'..tostring(rarity)]=true
 end
 return counts,labels
end
local c149,l149=sample(2,'Pack01',149)
check(math.abs(c149.DesertAloeSeed/N*100-12.5)<.2 and math.abs(c149.SandFruitSeed/N*100-1.11111)<.05,('149 Desert Common pack, 1M rolls: Aloe %.3f%% (12.5), Sand Fruit %.3f%% (1.111)'):format(c149.DesertAloeSeed/N*100,c149.SandFruitSeed/N*100))
check(l149['DesertAloeSeed:Rare']and l149['SandFruitSeed:Legendary']and l149['CactusSeed:Uncommon']and l149['DatePalmSeed:Mythic'],'... the rolls come back labelled Rare / Legendary / Uncommon / Mythic')
local cLava,lLava=sample(4,'Pack01',137)
check((cLava.FirePepperSeed or 0)==0 and math.abs(cLava.EmberBloomSeed/N*100-49.5783)<.4 and math.abs(cLava.AshRoseSeed/N*100-49.5783)<.4 and lLava['EmberBloomSeed:Rare']and not lLava['FirePepperSeed:Mythic']and not lLava['FirePepperSeed:Rare'],
 ('banked 137 Lava Common pack, 1M rolls: no Fire Pepper (was 33%%), Ember %.2f%% (49.58)'):format(cLava.EmberBloomSeed/N*100))
local cCr,lCr=sample(5,'Pack01',137)
check((cCr.MoonflowerSeed or 0)==0 and math.abs(cCr.AmethystSeed/N*100-49.9449)<.4 and lCr['AmethystSeed:Rare']and not lCr['MoonflowerSeed:Legendary']and not lCr['MoonflowerSeed:Rare'],
 ('banked 137 Crystal Common pack, 1M rolls: no Moon Melon (was 33%%), Amethyst %.2f%% (49.94)'):format(cCr.AmethystSeed/N*100))
-- A pack with no odds version (made before R81) and the old ones never give a new seed, even with the best boots.
local leak=0
for _,version in ipairs({'nil',0,81,112,137})do
 for _=1,40000 do
  local seed=Rules.Roll(Config,2,math.random,5e7,'Pack06',version~='nil'and version or nil);if seed and(seed.Id=='DesertAloeSeed'or seed.Id=='SandFruitSeed')then leak+=1 end
  local seed2=Rules.Roll(Config,2,math.random,5e7,'Pack01',version~='nil'and version or nil);if seed2 and(seed2.Id=='DesertAloeSeed'or seed2.Id=='SandFruitSeed')then leak+=1 end
 end
end
check(leak==0,'200,000 legacy Desert rolls at luck 5e7 (versions none / 0 / 81 / 112 / 137) never give a new seed')
-- The same roll goes the same way with a forced draw at every step (the pool never changes shape under the scope).
local stable=true
for step=0,400 do local d=step/400;local a=Rules.Roll(Config,2,drawConstant(d),1,'Pack03',137);local b=Rules.Roll(Config,2,drawConstant(d),1,'Pack03',137);if(a and a.Id)~=(b and b.Id)then stable=false end end
check(stable,'a legacy roll twice with the same draw gives the same seed (the legacy scope leaves no state behind)')
check(#Rules.ObtainablePool(Config,2)==7 and #Rules.ObtainablePool(Config,2)==7,'... and the live pool is 7 again right after a legacy roll (the scope is closed)')
local okErr=pcall(Rules.Roll,Config,2,function()error('boom')end,1,'Pack01',137)
check(not okErr and #Rules.ObtainablePool(Config,2)==7 and Rules.GetRarity('FirePepperSeed')=='Mythic','a draw function that errors in a legacy roll still closes the scope (the live pool and rarities are right afterwards)')
end

-- The hold tooltip, the Index chips (BaseChance) and the SeedCatalog remote.
local Map={GetStageAccent=function(_,s)return R.Color3.new(.5,.5,s/10)end}
local shown={};local Notes={Show=function(_,p,text)shown[#shown+1]={P=p,Text=text}end}
local PDS=server('PlayerDataService')
local Data=PDS.new(Config,Map,Notes)
R.clock=20000*86400+3600
local function makePlayer(id,name,data)
 data=data or Data
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p;order[#order+1]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 data:PreparePlayer(p);assert(data:Load(p),'load '..name)
 return p
end
local Chests=server('ChestService')
local fake=setmetatable({PlayerData=Data,Config=Config,Openings={}},{__index=Chests})
local function find(player,id)for i,r in ipairs(Data:GetChestRecords(player))do if r.Id==id then return r,i end end end
local function toolFor(player,id)
 for _,container in ipairs({player:FindFirstChildOfClass('Backpack'),player.Character})do if container then for _,t in ipairs(container:GetChildren())do if t:IsA('Tool')and t:GetAttribute('SeedInventoryId')==id then return t end end end end
end
local function tipOf(player,record)
 Chests.SyncTools(fake,player);local tool=toolFor(player,record.Id);fake.Openings[player]=true
 Chests._holdPack(fake,player,tool);fake.Openings[player]=nil
 local rows={};for line in tool.ToolTip:gmatch('[^\n]+')do rows[#rows+1]=line end;return rows,tool.ToolTip
end
local function addPack(player,stage,variant,version)return Data:AddChest(player,{Stage=stage,BagVariant=variant,PackSize=1,PackMutation='None',OddsVersion=version})end
local function giveSeed(player,id)
 local pack=addPack(player,Rules.SeedDesignById[id].SaveStage,'Pack01',Rules.OddsVersion)
 Data.StudioPackRewards=Data.StudioPackRewards or setmetatable({},{__mode='k'})
 Data.StudioPackRewards[player]=Data.StudioPackRewards[player]or{};Data.StudioPackRewards[player][pack.Id]=id
 return Data:OpenSeedPack(player,pack.Id,drawConstant(.5))
end
local D=makePlayer(710,'Dee')
do
local lava149,lava137,lava0=addPack(D,4,'Pack01',149),addPack(D,4,'Pack01',137),addPack(D,4,'Pack01',137)
lava0.OddsVersion=nil -- (a pack saved before odds versions existed has none; AddChest stamps the current one)
local desert149,desert137,desert112=addPack(D,2,'Pack01',149),addPack(D,2,'Pack01',137),addPack(D,2,'Pack01',112)
local crystal149=addPack(D,5,'Pack01',149)
check(lava149.OddsVersion==149 and lava137.OddsVersion==137 and lava0.OddsVersion==nil and desert112.OddsVersion==112,'AddChest keeps the odds version it is given (149 / 137 / none / 112)')
local function row(rows,name)for _,l in ipairs(rows)do if l:sub(1,#name+1)==name..':'then return l end end;return nil end
local r1=tipOf(D,lava149);local r2=tipOf(D,lava137)
check(row(r1,'Fire Pepper Seed')=='Fire Pepper Seed: 1/800','a 149 Lava Common pack\'s tooltip: "'..tostring(row(r1,'Fire Pepper Seed'))..'"')
check(row(r2,'Fire Pepper Seed')==nil,'a banked 137 Lava Common pack\'s tooltip has NO Fire Pepper row (OWNER: no windfall; it was 1/3): "'..tostring(row(r2,'Fire Pepper Seed'))..'"')
local r0=tipOf(D,lava0)
check(row(r0,'Fire Pepper Seed')==nil and row(r0,'Ember Pumpkin Seed')~=nil,'... nor has a pack with no odds version (read as 0)')
local tipSeedNames={};for stage=1,7 do for _,seed in ipairs(Rules.ObtainablePool(Config,stage))do tipSeedNames[seed.Name]=seed.Id end end
local function sortedTip(rows,label)
 local lastRank,lastName=0,'';local ok,why=true,''
 for i=2,#rows do
  local name=rows[i]:match('^(.-): ');local id=tipSeedNames[name];local style;if id then style=select(2,Rules.GetRarity(id))end
  if not id then ok=false;why='unknown row '..rows[i]
  elseif style.Rank<lastRank or(style.Rank==lastRank and name<lastName)then ok=false;why=rows[i]..' after '..lastName end
  lastRank,lastName=style and style.Rank or 0,name
 end
 check(ok and #rows>2,'hold tooltip rows are sorted by rarity rank, then name: '..label..' ('..why..')')
end
sortedTip(r1,'149 Lava Common');sortedTip(r2,'banked 137 Lava Common')
local rc=tipOf(D,crystal149)
check(row(rc,'Moon Melon Seed')=='Moon Melon Seed: 1/150','a 149 Crystal Common pack\'s tooltip: Moon Melon 1/150 ("'..tostring(row(rc,'Moon Melon Seed'))..'")')
local crystal137=addPack(D,5,'Pack01',137);local crystal112=addPack(D,5,'Pack01',112)
check(row(tipOf(D,crystal137),'Moon Melon Seed')==nil and row(tipOf(D,crystal112),'Moon Melon Seed')==nil and row(tipOf(D,crystal137),'Amethyst Grape Seed')~=nil,'banked 137 / 112 Crystal packs list no Moon Melon')
local d149=tipOf(D,desert149);local d137=tipOf(D,desert137);local d112=tipOf(D,desert112)
check(row(d149,'Aloe Seed')=='Aloe Seed: 1/8'and row(d149,'Sand Fruit Seed')=='Sand Fruit Seed: 1/90','a 149 Desert Common pack lists "Aloe Seed: 1/8" and "Sand Fruit Seed: 1/90"')
check(row(d137,'Aloe Seed')==nil and row(d137,'Sand Fruit Seed')==nil and row(d112,'Aloe Seed')==nil and row(d112,'Sand Fruit Seed')==nil and row(d137,'Prickly Pear Seed')=='Prickly Pear Seed: 1/1','banked 137 / 112 Desert packs list no Aloe and no Sand Fruit (their odds are 0, the row is skipped)')
sortedTip(d149,'149 Desert Common');sortedTip(d137,'banked 137 Desert Common')
do
 -- ... and the Aloe (Rare) sits between the Uncommon Prickly Pear and the Legendary Sand Fruit, which comes before the Mythic Date Palm
 local at={};for i,l in ipairs(d149)do at[l:match('^(.-): ')or l]=i end
 check(at['Prickly Pear Seed']<at['Aloe Seed']and at['Aloe Seed']<at['Sand Fruit Seed']and at['Sand Fruit Seed']<at['Dune Lotus Seed'],'the 149 Desert tooltip reads Prickly Pear, Aloe, Sand Fruit, Dune Lotus (rarity order, not save-slot order)')
end
check(d149[1]==d137[1]and d149[1]=='Common Desert Pack'or d149[1]==d137[1],'(the pack label is the same)')
local d149Rare=addPack(D,2,'Pack03',149)
local rr=tipOf(D,d149Rare)
check(row(rr,'Aloe Seed')=='Aloe Seed: 1/3','the Rare Desert pack: "Aloe Seed: '..tostring(row(rr,'Aloe Seed'))..'" (1/2.5 rounds to 1/3: R148 shows whole numbers under a million)')
-- Index chips: BaseChance = Pack01 at the current version, built exactly like ChestService does.
check(Odds.Format(Rules.SeedOdds(Config,2,'Pack01',1).DesertAloeSeed)=='1/8'and Odds.Format(Rules.SeedOdds(Config,2,'Pack01',1).SandFruitSeed)=='1/90'
 and Odds.Format(Rules.SeedOdds(Config,4,'Pack01',1).FirePepperSeed)=='1/800'and Odds.Format(Rules.SeedOdds(Config,5,'Pack01',1).MoonflowerSeed)=='1/150','Index chips: Aloe 1/8, Sand Fruit 1/90, Fire Pepper 1/800, Moon Melon 1/150')
check(Odds.Format(Rules.SeedOdds(Config,2,'Pack01',1).CactusSeed)=='1/1'and relnear(Rules.SeedOdds(Config,2,'Pack01',1).CactusSeed,86.2121,3e-5)and relnear(Rules.SeedOdds(Config,4,'Pack01',1).EmberBloomSeed,49.5158,3e-5),'Prickly Pear 86.2% (1/1.2: was 99.8%), Lava Rares 49.5% (was 33%)')
local ok,svc=pcall(Chests.new,Config,Map,Data,{},Notes)
check(ok,'the real ChestService builds its SeedCatalog remote ('..tostring(svc)..')')
local catalog=remotes:FindFirstChild('SeedCatalog')
local function entry(id)return catalog and catalog:FindFirstChild(id)end
local ea,es,ef,em=entry('DesertAloeSeed'),entry('SandFruitSeed'),entry('FirePepperSeed'),entry('MoonflowerSeed')
check(ea and ea:GetAttribute('Stage')==2 and ea:GetAttribute('SeedIndex')==9 and ea:GetAttribute('Rarity')=='Rare'and near(ea:GetAttribute('BaseChance'),12.5,1e-12)and ea:GetAttribute('DisplayName')=='Aloe Seed'
 and ea:GetAttribute('Plantable')==true and ea:GetAttribute('GrowSeconds')==960 and ea:GetAttribute('HarvestValue')==10000000 and ea:GetAttribute('BiomeName')=='Desert','SeedCatalog: the Aloe (Desert, index 9, Rare, BaseChance 12.5, plantable, 960 s)')
check(es and es:GetAttribute('Stage')==2 and es:GetAttribute('SeedIndex')==10 and es:GetAttribute('Rarity')=='Legendary'and near(es:GetAttribute('BaseChance'),1.11111111111,1e-9)and es:GetAttribute('GrowSeconds')==2760 and es:GetAttribute('HarvestValue')==26400000,
 'SeedCatalog: the Sand Fruit (Desert, index 10, Legendary, BaseChance 1.1111, 2760 s)')
check(ef and ef:GetAttribute('Stage')==4 and ef:GetAttribute('Rarity')=='Mythic'and near(ef:GetAttribute('BaseChance'),.125,1e-12)and em and em:GetAttribute('Stage')==5 and em:GetAttribute('Rarity')=='Legendary'and near(em:GetAttribute('BaseChance'),.666666666667,1e-9),
 'SeedCatalog: Fire Pepper (Mythic, 0.125) and Moon Melon (Legendary, 0.667) keep their biome and slot')
local retired=entry('AloeSeed')
check(retired==nil and catalog:GetAttribute('ExpectedCount')==54 and #catalog:GetChildren()==54,'SeedCatalog: 54 seeds in all (the retired ones are not listed)')
local desertEntries=0;for _,e in ipairs(catalog:GetChildren())do if e:GetAttribute('Stage')==2 then desertEntries+=1 end end
check(desertEntries==7,'SeedCatalog: 7 Desert entries')
end

-- 4. PlayerDataService --------------------------------------------------------------------------------------------------------------
local A=makePlayer(701,'Ava')
local B0=makePlayer(702,'Ben')
local nowT=math.floor(R.clock)
do
-- 149 packs and banked packs through save / load / gift.
local p149=addPack(A,4,'Pack03',149);local p137=addPack(A,4,'Pack06',137);local p112=addPack(A,2,'Pack04',112);local pNone=addPack(A,5,'Pack02',137);pNone.OddsVersion=nil
local aloeSeed=giveSeed(A,'DesertAloeSeed');local sandSeed=giveSeed(A,'SandFruitSeed');local fireSeed=giveSeed(A,'FirePepperSeed');local melonSeed=giveSeed(A,'MoonflowerSeed')
check(aloeSeed and aloeSeed.Kind=='Seed'and aloeSeed.SeedId=='DesertAloeSeed'and aloeSeed.Stage==2 and aloeSeed.Rarity=='Rare','opening a pack that reveals the Aloe: a Rare Desert seed')
check(sandSeed and sandSeed.SeedId=='SandFruitSeed'and sandSeed.Stage==2 and sandSeed.Rarity=='Legendary'and fireSeed.Stage==4 and fireSeed.Rarity=='Mythic'and melonSeed.Stage==5 and melonSeed.Rarity=='Legendary','... Sand Fruit Legendary (stage 2), Fire Pepper Mythic (stage 4), Moon Melon Legendary (stage 5)')
local saved=Data:_buildSaveData(A)
local rows={};for _,r in ipairs(saved.Seeds)do rows[r.Id]=r end
check(rows[p149.Id].OddsVersion==149 and rows[p137.Id].OddsVersion==137 and rows[p112.Id].OddsVersion==112 and rows[pNone.Id].OddsVersion==nil,'the save rows keep every pack\'s odds version (149 / 137 / 112 / none)')
check(saved.Version==22,'the saved profile is Version 22 ('..tostring(saved.Version)..')')
check(Data:Save(A,'test',true),'real save')
local Data2=PDS.new(Config,Map,Notes)
local A2=makePlayer(701,'Ava',Data2)
local function got(data,player,id)for _,r in ipairs(data:GetChestRecords(player))do if r.Id==id then return r end end end
check(got(Data2,A2,p149.Id).OddsVersion==149 and got(Data2,A2,p137.Id).OddsVersion==137 and got(Data2,A2,p112.Id).OddsVersion==112 and got(Data2,A2,pNone.Id).OddsVersion==nil,'a real save and load keeps every odds version: the 149 pack is still 149')
local l1,l2,l3,l4=got(Data2,A2,aloeSeed.Id),got(Data2,A2,sandSeed.Id),got(Data2,A2,fireSeed.Id),got(Data2,A2,melonSeed.Id)
check(l1 and l1.SeedId=='DesertAloeSeed'and l1.Stage==2 and l2 and l2.SeedId=='SandFruitSeed'and l2.Stage==2 and l3 and l3.SeedId=='FirePepperSeed'and l3.Stage==4 and l4 and l4.SeedId=='MoonflowerSeed'and l4.Stage==5,'the four seeds survive save and load (ids and stages)')
check(Data2:GetOrCreateDiscoveredSeeds(A2):FindFirstChild('DesertAloeSeed')~=nil and Data2:GetOrCreateDiscoveredSeeds(A2):FindFirstChild('SandFruitSeed')~=nil,'... and so does their discovery')
-- Gifts.
local Bn=makePlayer(704,'Bea');Bn:SetAttribute('PaidTradingAllowed',true);Bn:SetAttribute('PaidRandomAllowed',true)
local gp=Data:DecodeGiftedSeed(Bn,Data:SerializeSeedRecord(p149))
check(gp and gp.Kind=='Pack'and gp.OddsVersion==149 and gp.Stage==4,'a gifted 149 pack keeps 149')
local gp137=Data:DecodeGiftedSeed(Bn,Data:SerializeSeedRecord(p137))
check(gp137 and gp137.OddsVersion==137,'a gifted banked 137 pack keeps 137')
for _,rec in ipairs({aloeSeed,sandSeed,fireSeed,melonSeed})do
 local g=Data:DecodeGiftedSeed(Bn,Data:SerializeSeedRecord(rec))
 check(g and g.Kind=='Seed'and g.SeedId==rec.SeedId and g.Stage==rec.Stage,'a gifted '..rec.SeedId..' decodes as the same seed at stage '..rec.Stage)
end
local Gifts=server('FruitGiftService')
local synced=0;local giver={Data=Data,Chests={SyncTools=function()synced+=1 end}}
local staged=Data:SerializeSeedRecord(sandSeed);staged.Id='gift-sand-seed'
local okG,resG=pcall(Gifts._receiveSeed,giver,Bn,Data.Gardens[Bn]or{},{},'gift-r1',{Seed=staged})
check(okG and resG==true and got(Data,Bn,'gift-sand-seed')and got(Data,Bn,'gift-sand-seed').SeedId=='SandFruitSeed'and Data:GetOrCreateDiscoveredSeeds(Bn):FindFirstChild('SandFruitSeed')~=nil,'the recipient receives a Sand Fruit seed and discovers it ('..tostring(resG)..')')
-- An unknown future odds version (150) is not valid, and the row decodes without it (legacy odds).
local futurePack=Data:_decodeSavedSeedRecord(A,{Id='701_future',Kind='Pack',Stage=2,BagVariant='Pack04',OddsVersion=150,PackSize=1,ChestNumber=90},90)
check(futurePack and futurePack.OddsVersion==nil and futurePack.Kind=='Pack','a v150 pack decodes with no odds version (what an older server would do to a 149 pack: hence ProfileVersion 22)')
-- Banked packs cannot give the promoted seeds: a banked 137 Mythic Lava / Crystal pack opens to something else, at every draw.
local bankedFire,bankedMelon=0,0
for step=0,200 do
 local d=step/200
 local pf=addPack(A,4,'Pack06',137);local of=Data:OpenSeedPack(A,pf.Id,drawConstant(d));if of and of.SeedId=='FirePepperSeed'then bankedFire+=1 end
 local pm=addPack(A,5,'Pack06',137);local om=Data:OpenSeedPack(A,pm.Id,drawConstant(d));if om and om.SeedId=='MoonflowerSeed'then bankedMelon+=1 end
 local pc=addPack(A,4,'Pack01',137);local oc=Data:OpenSeedPack(A,pc.Id,drawConstant(d));if oc and oc.SeedId=='FirePepperSeed'then bankedFire+=1 end
end
check(bankedFire==0 and bankedMelon==0,'opening 201 banked 137 Mythic and Common Lava packs and 201 Crystal ones, one per draw: never Fire Pepper, never Moon Melon')
local pd=addPack(A,2,'Pack06',137);local openedD=Data:OpenSeedPack(A,pd.Id,drawConstant(.5))
check(openedD and openedD.SeedId~='DesertAloeSeed'and openedD.SeedId~='SandFruitSeed','a banked Desert pack never opens to a new seed')

-- Planting and harvesting the four seeds: times, values, regrow.
local plots={DesertAloeSeed=1,SandFruitSeed=2,FirePepperSeed=3,MoonflowerSeed=4}
local want={DesertAloeSeed={960,530,10000000,3},SandFruitSeed={2760,1520,26400000,4},FirePepperSeed={4300,2370,285000000,4},MoonflowerSeed={3400,1870,509000000,2}}
local seedRec={DesertAloeSeed=aloeSeed,SandFruitSeed=sandSeed,FirePepperSeed=fireSeed,MoonflowerSeed=melonSeed}
for _,id in ipairs({'DesertAloeSeed','SandFruitSeed','FirePepperSeed','MoonflowerSeed'})do
 local w=want[id];local slot=plots[id]
 local planted,crop=Data:PlantSeed(A,slot,seedRec[id].Id,{OffsetX=0,OffsetZ=0},nowT)
 check(planted and crop.SeedId==id and crop.ReadyAt-crop.PlantedAt==w[1]and crop.Value==w[3],id..': planted, ready after '..w[1]..' s, base value '..w[3])
 local early=Data:HarvestPlant(A,slot,crop.Id,nowT+w[1]-1)
 check(not early,id..': one second early is refused')
 -- every fruit is worth the plant's Value times its own size roll (PlantRules.Fruit: 0.6x .. 1.75x, deterministic per crop and fruit)
 local PR=W.module('PlantRules');local g=Data.Gardens[A].Plots[tostring(slot)][1];local def=Config.GardenPlants[id]
 local exp={};local inRange=true;for i=1,w[4]do exp[i]=PR.Fruit(g,i,def).Value;if exp[i]<w[3]*.5 or exp[i]>w[3]*2.2 then inRange=false end end
 check(inRange,id..': each fruit is worth its Value x a size roll between 0.5x and 2.2x of '..w[3]..' ('..table.concat(exp,' / ')..')')
 local okH,fruit=Data:HarvestPlant(A,slot,crop.Id,nowT+w[1])
 check(okH and fruit.SeedId==id and fruit.Value==exp[1],id..': harvested at the right time for '..tostring(exp[1])..' ('..tostring(fruit and fruit.Value)..')')
 local count=0;for _ in pairs(g.FruitStates or{})do count+=1 end
 check(count==w[4]and g.FruitStates['1'].ReadyAt==nowT+w[1]+w[2],id..': '..w[4]..' fruit states; the picked fruit regrows in '..w[2]..' s')
 -- pick the other fruits too (all are ripe together), then nothing is ready until the regrow time is up
 local all=true;for i=2,w[4]do local okMore,more=Data:HarvestPlant(A,slot,crop.Id,nowT+w[1]);if not okMore or more.Value~=exp[i]then all=false end end
 check(all,id..': all '..w[4]..' fruits can be picked, each at its own roll')
 check(not Data:HarvestPlant(A,slot,crop.Id,nowT+w[1]),id..': then none is ready')
 local tooSoon=Data:HarvestPlant(A,slot,crop.Id,nowT+w[1]+w[2]-1)
 check(not tooSoon,id..': the regrown fruit is not ready a second early')
 local again,fruit2=Data:HarvestPlant(A,slot,crop.Id,nowT+w[1]+w[2])
 check(again and fruit2.SeedId==id and fruit2.Value>=w[3]*.5 and fruit2.Value<=w[3]*2.2,id..': ... and is ready when the regrow time is up (worth '..tostring(fruit2 and fruit2.Value)..')')
 check(Data:GetPremium(A).Plants[id]==true,id..': its adult plant is discovered (Index)')
end
-- The whole garden saves and loads with the new plants.
local gardenSave=Data:CopyGarden(Data.Gardens[A]);local decodedGarden,whyG=Data:DecodeGarden(gardenSave)
check(decodedGarden~=nil,'the garden with all four plants and their fruit saves and loads ('..tostring(whyG)..')')
local maxV=0;for _,h in ipairs(Data.Gardens[A].Harvests)do maxV=math.max(maxV,h.Value)end
check(maxV<=9e12,'harvest records stay within the 9e12 cap')

-- A Fire Pepper crop saved under the OLD catalog (1140 s / regrow 630 s, 4 fruit states, an old ReadyAt) still loads, validates and
-- harvests at the new value. (FruitCount stays 4: a saved crop's FruitStates are checked against it.)
local oldPlant=Data:PlantSeed(B0,1,giveSeed(B0,'FirePepperSeed').Id,{OffsetX=0,OffsetZ=0},nowT-5000)
local oldCrop=Data.Gardens[B0].Plots['1'][1]
oldCrop.PlantedAt=nowT-5000;oldCrop.MatureAt=nowT-5000+1140;oldCrop.ReadyAt=oldCrop.MatureAt;oldCrop.HarvestCycle=1;oldCrop.PickedMask=0
oldCrop.FruitStates={['1']={ReadyAt=nowT+100,Cycle=1},['2']={ReadyAt=nowT-50,Cycle=1},['3']={ReadyAt=oldCrop.MatureAt,Cycle=0},['4']={ReadyAt=oldCrop.MatureAt,Cycle=0}}
oldCrop.ReadyAt=nowT-50
check(oldPlant and Data:DecodeGarden(Data:CopyGarden(Data.Gardens[B0]))~=nil,'a Fire Pepper crop in the old shape (4 fruit states, old ReadyAt) decodes and validates')
check(Data:Save(B0,'old-crop',true),'(saved)')
local Data3=PDS.new(Config,Map,Notes);local B3=makePlayer(702,'Ben',Data3)
local loadedCrop=Data3.Gardens[B3]and Data3.Gardens[B3].Plots['1']and Data3.Gardens[B3].Plots['1'][1]
check(loadedCrop and loadedCrop.SeedId=='FirePepperSeed'and loadedCrop.FruitStates and loadedCrop.FruitStates['4']~=nil and loadedCrop.MatureAt==nowT-5000+1140,'a real save and load keeps the crop with its old timers and four fruit states')
local okOld,fruitOld=Data3:HarvestPlant(B3,1,loadedCrop.Id,nowT)
check(okOld and fruitOld.SeedId=='FirePepperSeed'and fruitOld.Value==285000000,'... and a fruit that was ready under the old timers is picked at the NEW value (285,000,000: "current growing plants earn current rates")')
local after=Data3.Gardens[B3].Plots['1'][1]
check(after.FruitStates['2'].ReadyAt==nowT+2370 and after.FruitStates['1'].ReadyAt==nowT+100,'... the next regrow of that fruit uses the new 2370 s; the other fruits keep their saved ReadyAt')
-- Why FruitCount must not change: the same saved crop is refused if the definition says three fruits.
local savedGarden=Data:CopyGarden(Data3.Gardens[B3])
local fireDef=Config.GardenPlants.FirePepperSeed;local was=fireDef.FruitCount;fireDef.FruitCount=3
local refused,why=Data3:DecodeGarden(savedGarden)
fireDef.FruitCount=was
check(refused==nil and tostring(why):find('Invalid plant traits',1,true)~=nil,'(a changed FruitCount would make DecodeGarden reject the whole garden: "'..tostring(why)..'")')
check(Data3:DecodeGarden(savedGarden)~=nil,'(restored)')
-- ProfileVersion 22: a version-23 save is refused and left exactly as it was.
local profile,key
for name,store in pairs(stores)do for k,v in pairs(store.Data)do if type(v)=='table'and v.Version and k:find('702',1,true)then profile=v;key=k end end end
check(profile and profile.Version==22,'the stored profile is Version 22')
local function deep(t)if type(t)~='table'then return t end;local o={};for k,v in pairs(t)do o[k]=deep(v)end;return o end
local function same(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not same(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
profile.Version=23;local before=deep(profile)
local Data4=PDS.new(Config,Map,Notes)
local p4=R.new('Player');p4.Name='Ben';p4.UserId=702;p4.Parent=Players;R.new('Backpack').Parent=p4;function p4.Kick(_,why)error('kicked: '..tostring(why),0)end
Data4:PreparePlayer(p4)
local okLoad,loadErr=pcall(function()return Data4:Load(p4)end)
check((not okLoad and tostring(loadErr):find('newer server',1,true)~=nil)or okLoad==true and loadErr==false,'a version-23 save is refused: "'..tostring(loadErr)..'"')
check(same(before,profile)and profile.Version==23,'... and the stored data is exactly as it was')
pcall(function()Data4:Save(p4,'blocked',true)end)
check(same(before,profile)and profile.Version==23,'... and a save attempt does not overwrite it')
profile.Version=22
end

-- 5. The Index -----------------------------------------------------------------------------------------------------------------------------
do
local E=makePlayer(720,'Eve')
-- First / repeat index cash for all four ids.
for _,id in ipairs({'DesertAloeSeed','SandFruitSeed','FirePepperSeed','MoonflowerSeed'})do
 local first,repeats=T.IndexFirst[id],T.IndexRepeat[id]
 giveSeed(E,id)
 local r1=Data:GetPremium(E).SeedRewards[id]
 giveSeed(E,id)
 local r2=Data:GetPremium(E).SeedRewards[id]
 check(r1==first and r2==first+repeats,('%s: the first pull pays %d, a repeat adds %d (%s -> %s)'):format(id,first,repeats,tostring(r1),tostring(r2)))
end
-- Milestones. Desert's old roster was five seeds; it is seven now. A milestone reached with the OLD roster stays claimable ONLY for a player who had
-- already reached it before the update: the server records that once, on the first load after it (Premium.OldRoster148, saved, published as
-- IndexOldHalf2 / IndexOldFull2). Everyone else, new players and old players who had not got there, needs the live seven.
local OLD5={'CactusSeed','DatePalmSeed','MirageFigSeed','SolarStarfruitSeed','StarfruitSeed'}
local function discoverOn(data,player,id,adult)data:MarkSeedDiscovered(player,id,true);if adult then data:MarkAdultDiscovered(player,id)end end
local function discover(player,id,adult)discoverOn(Data,player,id,adult)end
local function savedRow(userId)local row;for _,store in pairs(stores)do for k,v in pairs(store.Data)do if type(v)=='table'and v.Version and k:find(tostring(userId),1,true)then row=v end end end;return row end
-- A player whose profile was saved BEFORE the roster change (so it has no OldRoster148) with the first n old Desert seeds found and grown, loading it
-- for the first time now. mutate(row) may change the saved row first (e.g. mark a reward claimed).
local function oldPlayer(userId,name,n,mutate)
 local d0=PDS.new(Config,Map,Notes);local p0=makePlayer(userId,name,d0)
 for i=1,n do discoverOn(d0,p0,OLD5[i],true)end
 check(d0:Save(p0,'pre-R148',true),name..': saved before the roster change')
 local row=savedRow(userId);row.Premium.OldRoster148=nil;if mutate then mutate(row)end
 local d1=PDS.new(Config,Map,Notes);local p1=makePlayer(userId,name,d1)
 return d1,p1,row
end
local function pendingGems(data,player)local gems={};for _,rc in ipairs(data.Gardens[player].PendingSales or{})do if rc.Currency=='Gems'then gems[#gems+1]=rc.Amount end end;return table.concat(gems,',')end
-- (1) Fay: 2 of the old 5 before the update (nothing reached under either roster).
local dF,F=oldPlayer(751,'Fay',2)
local recF=dF:GetPremium(F).OldRoster148
check(type(recF)=='table'and next(recF.Half)==nil and next(recF.Full)==nil and F:GetAttribute('IndexOldHalf2')==false and F:GetAttribute('IndexOldFull2')==false,'the first load after the update records the old milestones: Fay (2 of 5) had reached none')
check(dF.Dirty[F]==true,'... and the profile is marked for saving because of it')
local s,p,t=dF:IndexProgress(F,2);local so,po,to=dF:IndexProgress(F,2,true)
check(s==2 and p==2 and t==7 and so==2 and po==2 and to==5,'IndexProgress: live total 7, the old roster (beforeR149) total 5')
check(not dF:IndexMilestone(F,2,false)and not dF:IndexMilestone(F,2,true),'Fay, 2 of 5 found and grown: no halfway, no completion')
local okH,whyH=dF:ClaimIndexBiomeHalf(F,2);local okC,whyC=dF:ClaimIndexBiome(F,2)
check(not okH and whyH=='REACH HALF OF THIS INDEX'and not okC and whyC=='COLLECT EACH SEED AND GROW EACH PLANT','... and both claims are refused ('..tostring(whyH)..' / '..tostring(whyC)..')')
discoverOn(dF,F,OLD5[3],true)
check(not dF:IndexMilestone(F,2,false),'she finds a third old seed AFTER the update: 6 of 14 points is not halfway (the old 6 of 10 would have been, but she had not reached it before: no fallback)')
discoverOn(dF,F,OLD5[4],true)
check(dF:IndexMilestone(F,2,false)and not dF:IndexMilestone(F,2,true),'a fourth: 8 of 14 is halfway under the live roster')
discoverOn(dF,F,OLD5[5],true)
check(not dF:IndexMilestone(F,2,true)and not dF:BiomeComplete(F,2)and not select(1,dF:ClaimIndexBiome(F,2)),'all five old seeds found after the update: NOT complete (the Aloe and the Sand Fruit are missing; no old-roster fallback for her)')
discoverOn(dF,F,'DesertAloeSeed',true);discoverOn(dF,F,'SandFruitSeed',true)
check(dF:IndexMilestone(F,2,true)and dF:BiomeComplete(F,2)and select(1,dF:ClaimIndexBiome(F,2)),'... all seven found and grown: complete, and the completion reward claims')
-- (2) Gil: 3 of the old 5 before the update = halfway reached (unclaimed), not complete.
local dG,G=oldPlayer(752,'Gil',3)
local recG=dG:GetPremium(G).OldRoster148
check(recG.Half['2']==true and recG.Full['2']==nil and G:GetAttribute('IndexOldHalf2')==true and G:GetAttribute('IndexOldFull2')==false,'Gil (3 of 5, saved before the update): halfway recorded, completion not (published as IndexOldHalf2)')
check(dG:IndexMilestone(G,2,false)and not dG:IndexMilestone(G,2,true),'... so the halfway reward stays claimable (live 3+3 of 14 is not halfway) and the completion does not')
local h1,h1why=dG:ClaimIndexBiomeHalf(G,2);local h2,h2why=dG:ClaimIndexBiomeHalf(G,2)
check(h1 and not h2 and h2why=='ALREADY CLAIMED','the halfway reward claims once, the second claim says ALREADY CLAIMED ('..tostring(h2why)..')')
check(not select(1,dG:ClaimIndexBiome(G,2)),'(completion is still refused)')
discoverOn(dG,G,OLD5[4],true);discoverOn(dG,G,OLD5[5],true)
check(not dG:IndexMilestone(G,2,true)and not select(1,dG:ClaimIndexBiome(G,2)),'the other two old seeds found after the update: still not complete (the flag only ever covers what was reached before)')
-- The flag is saved and survives a real save and load (and is not recomputed).
check(dG:Save(G,'flag',true),'(saved)')
local rowG=savedRow(752)
check(type(rowG.Premium.OldRoster148)=='table'and rowG.Premium.OldRoster148.Half['2']==true,'the saved profile holds Premium.OldRoster148 ({Half={["2"]=true}})')
local dG2=PDS.new(Config,Map,Notes);local G2=makePlayer(752,'Gil',dG2)
check(dG2:GetPremium(G2).OldRoster148.Half['2']==true and dG2:IndexMilestone(G2,2,false)and G2:GetAttribute('IndexOldHalf2')==true,'... and a fresh load keeps it')
-- (3) Hana: all five old seeds before the update (complete, nothing claimed): both rewards stay claimable, once each.
local dH,H=oldPlayer(753,'Hana',5)
local recH=dH:GetPremium(H).OldRoster148
check(recH.Half['2']==true and recH.Full['2']==true and H:GetAttribute('IndexOldFull2')==true,'Hana (5 of 5 before the update): halfway and completion recorded')
check(dH:IndexMilestone(H,2,true)and dH:BiomeComplete(H,2),'old 5/5: complete, so BiomeComplete is true (no reward is taken away)')
local hh,hhWhy=dH:ClaimIndexBiomeHalf(H,2)
local c1,c1why=dH:ClaimIndexBiome(H,2);local c2,c2why=dH:ClaimIndexBiome(H,2)
check(hh and c1 and not c2 and c2why=='ALREADY CLAIMED'and H:GetAttribute('IndexBiomeReward2')==true and H:GetAttribute('IndexBiomeHalfReward2')==true,'both rewards claim once, then ALREADY CLAIMED; the claimed attributes follow ('..tostring(c2why)..')')
check(pendingGems(dH,H)=='10,20','the Gems: 10 (halfway) and 20 (completion) once each ('..pendingGems(dH,H)..')')
discoverOn(dH,H,'DesertAloeSeed',true);discoverOn(dH,H,'SandFruitSeed',true)
check(not select(1,dH:ClaimIndexBiome(H,2))and not select(1,dH:ClaimIndexBiomeHalf(H,2))and pendingGems(dH,H)=='10,20','finding the two new seeds later pays nothing more')
-- (4) A player who claimed both before the update cannot claim again, whatever they have found.
local dI,I=oldPlayer(754,'Ian',5,function(row)row.Premium.Biomes['2']=true;row.Premium.BiomeHalfRewards=row.Premium.BiomeHalfRewards or{};row.Premium.BiomeHalfRewards['2']=true end)
local g1,g1why=dI:ClaimIndexBiomeHalf(I,2);local g2,g2why=dI:ClaimIndexBiome(I,2)
check(not g1 and g1why=='ALREADY CLAIMED'and not g2 and g2why=='ALREADY CLAIMED'and pendingGems(dI,I)=='','a player who claimed both rewards before the update gets ALREADY CLAIMED (no duplicate)')
-- (5) A new player (created after the update): nothing is recorded, and they need the seven.
local N5=makePlayer(755,'Nia')
local recN=Data:GetPremium(N5).OldRoster148
check(type(recN)=='table'and next(recN)==nil and N5:GetAttribute('IndexOldHalf2')==false and N5:GetAttribute('IndexOldFull2')==false,'a new player starts with an empty record (no old-roster milestones: settled, nothing to carry over)')
for _,id in ipairs(OLD5)do discover(N5,id,true)end
check(Data:IndexMilestone(N5,2,false)and not Data:IndexMilestone(N5,2,true)and not Data:BiomeComplete(N5,2),'a new player with the five old Desert seeds found and grown: halfway (10 of 14), NOT complete')
local nc,ncWhy=Data:ClaimIndexBiome(N5,2)
check(not nc and ncWhy=='COLLECT EACH SEED AND GROW EACH PLANT','... and the completion claim is refused: a new player needs all seven ('..tostring(ncWhy)..')')
discover(N5,'DesertAloeSeed',true)
check(not Data:IndexMilestone(N5,2,true),'six of seven: still not complete')
discover(N5,'SandFruitSeed',true)
local sN,pN,tN=Data:IndexProgress(N5,2)
check(sN==7 and pN==7 and tN==7 and Data:BiomeComplete(N5,2)and select(1,Data:ClaimIndexBiome(N5,2)),'all seven Desert seeds found and grown: complete (7 / 7) and the reward claims')
-- Only the Aloe and the Sand Fruit: nothing to claim.
local H2=makePlayer(756,'Hal')
discover(H2,'DesertAloeSeed',true);discover(H2,'SandFruitSeed',true)
check(not Data:IndexMilestone(H2,2,false)and not Data:IndexMilestone(H2,2,true),'only the Aloe and the Sand Fruit (found and grown): 4 of 14 points, nothing to claim')
-- (6) Decode sanitises the record; Decode(nil) is "settled, nothing".
do
 local PP=server('PremiumProgress')
 local function deepCopy(t)if type(t)~='table'then return t end;local o={};for k,v in pairs(t)do o[k]=deepCopy(v)end;return o end
 local base=deepCopy(Data:GetPremium(H2));base.OldRoster148=nil
 local function decoded(rec)local x=deepCopy(base);x.OldRoster148=rec;return PP.Decode(x)end
 check(next(PP.Decode(nil).OldRoster148)==nil and PP.Decode(nil).OldRoster148~=nil,'Decode(nil): an empty record (a new player; nothing is settled later)')
 check(PP.Decode(base)~=nil and PP.Decode(base).OldRoster148==nil,'Decode of a profile saved before the update: no record yet (the load settles it)')
 check(decoded('junk').OldRoster148==nil and decoded(5).OldRoster148==nil,'a record that is not a table is treated as not recorded yet')
 local kept=decoded({Half={['2']=true,['9']=true,['x']=true,['0']=true,['3']=false,['5']='yes'},Full={['2']=1,['3']=true},Extra=true}).OldRoster148
 local halves=0;for _ in pairs(kept.Half)do halves+=1 end;local fulls=0;for _ in pairs(kept.Full)do fulls+=1 end
 check(kept.Half['2']==true and halves==1 and fulls==0 and kept.Extra==nil,'a record keeps only Desert\'s true flags: other stages, bad keys, non-true values and extra fields are dropped')
 check(decoded({Half={['2']=true},Full={['2']=true}}).OldRoster148.Full['2']==true,'a good record round-trips')
 check(PP.RosterChangeStages()[2]==true and next(PP.RosterChangeStages(),2)==nil,'the roster change touched Desert (stage 2) only')
end
-- Lava and Crystal: the Index membership is unchanged (7 each), so their milestones are as before.
local L=makePlayer(724,'Lin')
local lavaSeeds,crystalSeeds={'FirePepperSeed','EmberBloomSeed','AshRoseSeed','LavaLotusSeed','ObsidianMawSeed','SupernovaBloomSeed','EmberEmperorSeed'},{'AmethystSeed','PrismOrchidSeed','MoonflowerSeed','DiamondVineSeed','HollowGeodeSeed','OrbitLotusSeed','PrismMonarchSeed'}
for i=1,3 do discover(L,lavaSeeds[i],true);discover(L,crystalSeeds[i],false)end
local sl,pl,tl=Data:IndexProgress(L,4);local sc,pc,tc=Data:IndexProgress(L,5)
check(tl==7 and tc==7 and sl==3 and pl==3 and sc==3 and pc==0 and Data:IndexProgress(L,4,true)==3 and select(3,Data:IndexProgress(L,4,true))==7,'Lava and Crystal still have 7 entries each (the old roster count is the same)')
check(not Data:IndexMilestone(L,4,false)and not Data:IndexMilestone(L,5,false),'Lava 6 of 14 and Crystal 3 of 14: no halfway yet')
discover(L,lavaSeeds[4],true);discover(L,crystalSeeds[4],true);discover(L,crystalSeeds[5],true)
check(Data:IndexMilestone(L,4,false)and Data:IndexMilestone(L,5,false)and not Data:IndexMilestone(L,4,true),'Lava 8 of 14 and Crystal 7 of 14: halfway, not complete')
for i=5,7 do discover(L,lavaSeeds[i],true);discover(L,crystalSeeds[i],true)end
for i=1,3 do Data:MarkAdultDiscovered(L,crystalSeeds[i])end
check(Data:BiomeComplete(L,4)and Data:BiomeComplete(L,5),'all seven of each: Lava and Crystal complete (as before)')
-- The rest of the categories: Mech (8) and Verity (9) behave as before.
check(select(3,Data:IndexProgress(L,8))==6 and select(3,Data:IndexProgress(L,9))==1 and select(3,Data:IndexProgress(L,1))==6 and select(3,Data:IndexProgress(L,7))==7,'other categories keep their sizes (Forest 6, Storm 7, Mech 6, Verity 1)')
end

-- 6. Owner commands -------------------------------------------------------------------------------------------------------------------------
do
local X=server('OwnerUpdateCommands82');local RPT=server('RarePackTests');local Cmd=server('StudioTestCommands')
local C=makePlayer(730,'Cal')
local ctx={Config=Config,Data=Data,Map={MapRoot=R.new('Folder')},Chase={IsPlayerBusy=function()return false end},Bases={GetPlayerBase=function()return nil end},
 Chests=setmetatable({IsOpening=function()return false end,SyncTools=function()end,RenderGarden=function()end},{__index=Chests})}
Run.IsStudio=function()return true end
local nBefore=#Data:GetChestRecords(C)
local okR,textR=RPT.Grant(Data,C,'roster',C)
Run.IsStudio=function()return false end
check(okR and #Data:GetChestRecords(C)==nBefore+4,'rarepacks roster adds four TEST packs ('..tostring(textR)..')')
local reveals={}
for _,r in ipairs(Data:GetChestRecords(C))do if r.Kind=='Pack'then local e=RPT.Expected(Data,C,r.Id);if e then reveals[#reveals+1]={Pack=r,Id=e}end end end
check(#reveals==4 and reveals[1].Id=='FirePepperSeed'and reveals[2].Id=='MoonflowerSeed'and reveals[3].Id=='DesertAloeSeed'and reveals[4].Id=='SandFruitSeed','the four packs reveal Fire Pepper, Moon Melon, Aloe, Sand Fruit (in that order)')
local rarities={}
for _,v in ipairs(reveals)do local o=Data:OpenSeedPack(C,v.Pack.Id,drawConstant(.7));rarities[#rarities+1]=(o and o.Rarity or'?')..':'..(o and o.SeedId or'?')end
check(table.concat(rarities,' ')=='Mythic:FirePepperSeed Legendary:MoonflowerSeed Rare:DesertAloeSeed Legendary:SandFruitSeed','opening them reveals Mythic, Legendary, Rare, Legendary ('..table.concat(rarities,' ')..')')
Run.IsStudio=function()return true end
local okOld=RPT.Grant(Data,C,'mythic',C);local okBad,textBad=RPT.Grant(Data,C,'nonsense',C)
Run.IsStudio=function()return false end
check(okOld and not okBad and textBad:find('roster',1,true)~=nil,'the older selectors still work; an unknown one answers with the usage line that now lists roster ('..tostring(textBad)..')')
local Help=W.module('StudioTestHelp');local helpRow
for _,e in ipairs(Help)do if e[1]:find('/test rarepacks',1,true)then helpRow=e end end
check(helpRow and helpRow[2]:find('rarepacks verity a TEST Verity Pack that reveals the Verity seed; rarepacks roster four TEST packs that reveal Fire Pepper, Moon Melon, Aloe and Sand Fruit.',1,true)~=nil,'the /test rarepacks help row mentions rarepacks roster (and keeps the verity text)')
-- seed / seeds / odds.
Run.IsStudio=function()return true end
local nSeeds=#Data:GetChestRecords(C)
local okS,textS=Cmd.Execute(ctx,C,'/test seed DesertAloeSeed')
local added;for _,r in ipairs(Data:GetChestRecords(C))do if r.Kind=='Seed'and r.SeedId=='DesertAloeSeed'then added=r end end
check(okS and added and added.Stage==2 and #Data:GetChestRecords(C)==nSeeds+1,'/test seed DesertAloeSeed gives the Aloe seed ('..tostring(textS)..')')
local okSF,textSF=Cmd.Execute(ctx,C,'/test seed SandFruitSeed')
local sandAdded;for _,r in ipairs(Data:GetChestRecords(C))do if r.Kind=='Seed'and r.SeedId=='SandFruitSeed'then sandAdded=r end end
check(okSF and sandAdded,'/test seed SandFruitSeed gives the Sand Fruit seed ('..tostring(textSF)..')')
local before=#Data:GetChestRecords(C)
local okAll,textAll=Cmd.Execute(ctx,C,'/test seeds desert')
local desertIds={};for i=before+1,#Data:GetChestRecords(C)do desertIds[Data:GetChestRecords(C)[i].SeedId or'?']=true end
check(okAll and desertIds.DesertAloeSeed and desertIds.SandFruitSeed and desertIds.CactusSeed and desertIds.DatePalmSeed and desertIds.StarfruitSeed and #Data:GetChestRecords(C)==before+7,'/test seeds desert gives all seven Desert seeds including the two new ones ('..tostring(textAll)..')')
local okOdds,textOdds=X.Execute(ctx,C,'odds',{'desert','rare'})
check(okOdds and textOdds:find('Aloe Seed: 1/3',1,true)~=nil and textOdds:find('Prickly Pear Seed: 1/2',1,true)~=nil and textOdds:find('Sand Fruit Seed:',1,true)~=nil,'odds desert rare shows "Aloe Seed: 1/3" (1/2.5, whole numbers under a million) and the Sand Fruit ('..tostring(textOdds):gsub('\n',' | ')..')')
local okL,textL=X.Execute(ctx,C,'odds',{'lava','common'})
check(okL and textL:find('Fire Pepper Seed: 1/800',1,true)~=nil,'odds lava common: Fire Pepper 1/800')
-- R148: the rows of `odds` are sorted by rarity rank (commonest first), then name.
local function ordered(text)
 local names={};for stage=1,7 do for _,seed in ipairs(Rules.ObtainablePool(Config,stage))do names[seed.Name]=seed.Id end end
 local lastRank,lastName,rows=0,'',0
 for line in text:gmatch('[^\n]+')do
  local name=line:match('^(.-): ')
  if name and names[name]then
   rows+=1;local _,style=Rules.GetRarity(names[name])
   if style.Rank<lastRank or(style.Rank==lastRank and name<lastName)then return false,rows end
   lastRank,lastName=style.Rank,name
  end
 end
 return rows>2,rows
end
local okO1,n1=ordered(textL);local okO2,n2=ordered(textOdds);local _,textStorm=X.Execute(ctx,C,'odds',{'storm','mythic'});local okO3,n3=ordered(textStorm)
check(okO1 and okO2 and okO3,('`odds` rows are sorted by rarity rank, then name (lava common %d rows, desert rare %d, storm mythic %d)'):format(n1,n2,n3))
Run.IsStudio=function()return false end
check(Config.GetSeedById('DesertAloeSeed')and ctx.Data==Data,'(commands ran on the real modules)')
end

-- 7. Fruit of the Hour --------------------------------------------------------------------------------------------------------------------------
do
local cands=Hour.Candidates()
check(#cands==53 and table.find(cands,'DesertAloeSeed')and table.find(cands,'SandFruitSeed')and not table.find(cands,'VeritySeed'),'Fruit of the Hour: 53 candidates, the two new ones included, never Verity')
local seen={}
for h=0,24*400 do local pick=Hour.At(h*3600);if pick and pick.SeedId then seen[pick.SeedId]=true end end
check(seen.DesertAloeSeed and seen.SandFruitSeed and not seen.VeritySeed,'400 days of hourly picks reach both new fruits and never Verity')
check(Hour.Name('DesertAloeSeed')=='Aloe bloom'or Hour.Name('DesertAloeSeed')=='Aloe Bloom'or Hour.Name('DesertAloeSeed')~=nil,'(the Aloe fruit has a display name: '..tostring(Hour.Name('DesertAloeSeed'))..')')
end

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
