-- R151 (owner: "add a pack index in the index and state rate of spawn and drop rates ... can just use the default pack shape"): what the Index's PACKS tab lists, as
-- pure data: every pack that can be obtained, where it comes from and what it can give. NOTHING here is typed in: every number is read from the same tables the
-- server rolls from, so the Index cannot drift from the game:
--  * spawn (a track pack): SeedPackRules.Variants[Pack0n].SpawnWeight (the R127 owner weights, RouteBalance83.SpawnWeights, 42.92 / 28.24 / 16.94 / 7.9 / 3 / 1)
--    over their sum, i.e. what SeedPackRules.RollVariant does for every world slot (ChestService:SkinWorldSeeds, DailyProgress:GrantDailyPack);
--  * drops: SeedPackRules.SeedOdds(config, stage, variant, 1, OddsVersion) (the PackOdds137 tier odds for ordinary packs, VoidPackOdds85 for the Void pack,
--    VerityPackOdds for the Verity pack, MechCatalog's chances for the Mech pack) and SeedPackRules.OddsRows for the order, which is exactly what the hold tooltip and
--    the owner's `odds` command print; the chance of a rarity is the sum of its seeds' chances, so the two always agree;
--  * other sources: TreadmillBonusRules.Odds (bonus roll), MysteryPackRules.Odds (mystery pedestal), DailyRewards (login reward packs), MechCatalog.Offers
--    (shop), PackSchedule81.Event + SeedPackRules.RefreshInterval (The Darkened), BalanceRules.PackSizes (SeedPackRules.PackSizes).
-- Shown like the game shows odds everywhere (R136 / R148 owner rule): 1/N, N a whole number, by OddsText85.Format.
-- WHAT IS NOT HERE ON PURPOSE: boots luck (the Index shows the plain odds, like the hold tooltip's base), the free starter pack's hidden rate boost (R139: its odds
-- are the ordinary Forest pack's, no 2x anywhere), the hidden pack-size pity (PackSizePity) and owner TEST packs (records with TestGrant; there is no entry that
-- stands for one). The legacy Small / Standard / Grand sacks are not listed: nothing in the game makes one any more (RollVariant only picks VariantOrder, the daily
-- reward only Pack01-06, a bonus roll / mystery pack only Pack01-06 and the Void pack), they live on only in old saves.
local RS=game:GetService('ReplicatedStorage')
local Rules=require(RS:WaitForChild('SeedPackRules'))
local Odds=require(RS:WaitForChild('OddsText85'))
local Bonus=require(RS:WaitForChild('TreadmillBonusRules'))
local Mystery=require(RS:WaitForChild('MysteryPackRules'))
local Daily=require(RS:WaitForChild('DailyRewards'))
local Mech=require(RS:WaitForChild('MechCatalog'))
local Verity=require(RS:WaitForChild('VerityCatalog'))
local Sizes=require(RS:WaitForChild('SizeNumbers'))
local Schedule=require(RS:WaitForChild('PackSchedule81'))
local D={Revision=151}
D.VoidVariant='EclipseReliquary'
-- The client's copy of the server's config for the odds code (Config.SeedCatalogByStage is SeedPackRules.BuildSeedCatalog(), see BiomeExpansionConfig; the odds
-- code only reads the catalog and GetSeedById). Built once.
local config
function D.Config()
 if config then return config end
 local catalog=Rules.BuildSeedCatalog();local byId={}
 for _,seeds in ipairs(catalog)do for _,seed in ipairs(seeds)do if not byId[seed.Id]then byId[seed.Id]=seed end end end
 config={SeedCatalogByStage=catalog,GetSeedById=function(id)return byId[id]end}
 return config
end
local function pct(n)return type(n)=='number'and n==n and n or 0 end
local function tierColor(name)local r=Rules.Rarities[name];return r and r.Color or Color3.new(1,1,1)end
-- The groups of a pack's drops: the seeds it can give grouped by rarity (the Mech seeds a Void / Verity pack can roll are one group, MECH; the Verity seed is its own,
-- VERITY), each with its share and its seeds. Returns the groups in reading order (Verity seed, then Common ... King, then Mech) and the total.
local function groups(cfg,stage,variant,version)
 local odds=Rules.SeedOdds(cfg,stage,variant,1,version) -- luck 1, no rate boost: the plain odds
 local out,byKey,total={},{},0
 for _,seed in ipairs(Rules.OddsRows(cfg,stage,variant,odds))do
  local p=pct(odds[seed.Id])
  if p>0 then
   local rarity=Rules.GetRarity(seed.Id)
   local key=Verity.Is(seed.Id)and'Verity'or(Mech.Is(seed.Id)and variant~='MechLimited')and'Mech'or rarity
   local g=byKey[key]
   if not g then
    local rank=key=='Verity'and 0 or key=='Mech'and 100 or(Rules.Rarities[key]and Rules.Rarities[key].Rank or 50)
    g={Key=key,Label=string.upper(key),Rank=rank,Percent=0,Seeds={},Color=key=='Mech'and Color3.fromRGB(88,225,255)or key=='Verity'and Color3.fromRGB(255,213,46)or tierColor(key)}
    byKey[key]=g;out[#out+1]=g
   end
   g.Percent+=p;total+=p
   g.Seeds[#g.Seeds+1]={Id=seed.Id,Name=((seed.Name or seed.Id):gsub(' Seed$','')),Rarity=rarity,Percent=p,Text=Odds.Format(p)}
  end
 end
 table.sort(out,function(a,b)return a.Rank<b.Rank end)
 for _,g in ipairs(out)do g.Text=Odds.Format(g.Percent);g.Count=#g.Seeds end
 return out,total
end
-- A tier name for the pack picture's chip: the pack tiers are Common .. Mythic (Rules.PackTiers); the specials have their own.
local function tierOf(variant)
 local tier,rank=Rules.GetPackTier(variant)
 return{Name=tier.Name,Rank=rank,Color=tier.Color}
end
local function track(cfg,stage,variant,version,spawn,bonus,mystery)
 local key=Rules.DesignKey(stage,variant)
 local drops,total=groups(cfg,stage,variant,version)
 local also={}
 if bonus[variant]then also[#also+1]={Source='Bonus roll',Text=Odds.Format(bonus[variant]),Percent=bonus[variant]}end
 if Daily.SeedPackVariants[variant]then also[#also+1]={Source='Daily reward'}end
 if mystery[variant]then also[#also+1]={Source='Mystery pedestal',Text=Odds.Format(mystery[variant]),Percent=mystery[variant]}end
 return{Key=key,Kind='Track',Stage=stage,Variant=variant,Section=stage,Name=Rules.PackLabel(stage,variant,1,'None'),Biome=Rules.DesignBiomes[stage]or'Forest',Tier=tierOf(variant),
  Spawn={Percent=spawn[variant],Text=Odds.Format(spawn[variant]),Of='of packs on its track'},Also=also,DropTitle='DROPS',Drops=drops,DropTotal=total}
end
local function when(n)return n==1 and'every refresh'or('every '..n..(n==2 and'nd'or n==3 and'rd'or'th')..' refresh')end
-- The whole list. opts.Order: biome stages in the order the Index's tabs show them (default: the physical order of the tracks).
function D.Build(opts)
 opts=opts or{};local cfg=opts.Config or D.Config();local version=Rules.OddsVersion
 local order=opts.Order or{1,6,2,3,4,5,7}
 -- spawn: SpawnWeight over the sum, as RollVariant picks (percent)
 local spawn,weight={},0
 for _,key in ipairs(Rules.VariantOrder)do weight+=Rules.Variants[key].SpawnWeight end
 for _,key in ipairs(Rules.VariantOrder)do spawn[key]=100*Rules.Variants[key].SpawnWeight/weight end
 -- bonus roll (per roll, any biome) and mystery pedestal (per pack): percent of the table
 local bonus,mystery={},{}
 for k,p in pairs(Bonus.VariantOdds())do bonus[k]=100*p end
 local mTotal=0;for _,k in ipairs(Mystery.Order)do mTotal+=Mystery.Odds[k]end
 for _,k in ipairs(Mystery.Order)do mystery[k]=100*Mystery.Odds[k]/mTotal end
 local entries,sections={},{}
 for _,stage in ipairs(order)do
  local section={Key=stage,Title=string.upper(Rules.DesignBiomes[stage]or'Forest'),Entries={}}
  for _,variant in ipairs(Rules.VariantOrder)do
   local e=track(cfg,stage,variant,version,spawn,bonus,mystery);entries[#entries+1]=e;section.Entries[#section.Entries+1]=e
  end
  sections[#sections+1]=section
 end
 local special={Key='Special',Title='SPECIAL PACKS',Entries={}}
 local function add(e)entries[#entries+1]=e;special.Entries[#special.Entries+1]=e end
 -- the free tutorial pack: the ordinary Forest pack (Pack01), plain odds (its hidden rate boost is never shown)
 do
  local d,t=groups(cfg,1,'Pack01',version)
  add{Key='Starter',Kind='Starter',Stage=1,Variant='Pack01',Section='Special',Name='Starter Pack',Biome='Forest',Tier={Name='Free',Rank=0,Color=Color3.fromRGB(147,255,69)},
   Spawn=nil,How={{Source='Free tutorial gift'},{Source='Once per player'}},DropTitle='DROPS',Drops=d,DropTotal=t}
 end
 -- the daily mystery pack: its pack tier is rolled when it unlocks (MysteryPackRules.Odds), never Common
 do
  local rows,t={},0
  for _,k in ipairs(Mystery.Order)do
   local label=k==D.VoidVariant and'VOID'or string.upper(tierOf(k).Name)
   rows[#rows+1]={Key=k,Label=label,Percent=mystery[k],Text=Odds.Format(mystery[k]),Seeds={},Count=0,Color=k==D.VoidVariant and Color3.fromRGB(190,144,255)or tierOf(k).Color};t+=mystery[k]
  end
  add{Key='Mystery',Kind='Mystery',Stage=3,Variant='Pack03',Section='Special',Name='Mystery Pack',Biome='Your biome',Tier={Name='Mystery',Rank=0,Color=Color3.fromRGB(176,118,255)},
   Spawn=nil,How={{Source='Mystery pedestal in your base'},{Source='Free daily',Text=(Mystery.UnlockSeconds//60)..' min online'}},DropTitle='IT TURNS OUT TO BE',Drops=rows,DropTotal=t,Silhouette=true}
 end
 -- The Darkened's Void pack
 do
  local d,t=groups(cfg,7,D.VoidVariant,version)
  local n=1;while n<60 and not Schedule.Event(n)do n+=1 end
  local interval=n*Rules.RefreshInterval//60
  add{Key='Void',Kind='Void',Stage=7,Variant=D.VoidVariant,Section='Special',Name=Rules.PackLabel(7,D.VoidVariant,1,'None'),Biome='Storm',Tier=tierOf(D.VoidVariant),
   Spawn=nil,How={{Source='The Darkened event',Text=when(n)..' (about '..interval..' min)'},{Source='Bonus roll',Text=Odds.Format(bonus[D.VoidVariant])},{Source='Mystery pedestal',Text=Odds.Format(mystery[D.VoidVariant])}},
   DropTitle='DROPS',Drops=d,DropTotal=t}
 end
 -- limited packs
 do
  local d,t=groups(cfg,Mech.Stage,Mech.Variant,version)
  local day;for i,reward in ipairs(Daily.Login)do if reward.MechPack then day=i end end
  local how={{Source='Shop (Robux)'}}
  if day then how[#how+1]={Source='Daily reward',Text='day '..day}end
  add{Key='Mech',Kind='Mech',Stage=Mech.Stage,Variant=Mech.Variant,Section='Special',Name=Rules.PackLabel(Mech.Stage,Mech.Variant,1,'None'),Biome='Limited',Tier=tierOf(Mech.Variant),
   Spawn=nil,How=how,DropTitle='DROPS',Drops=d,DropTotal=t,Limited=true}
 end
 do
  local d,t=groups(cfg,Verity.PackStage,Verity.Variant,version)
  add{Key='Verity',Kind='Verity',Stage=Verity.PackStage,Variant=Verity.Variant,Section='Special',Name=Rules.PackLabel(Verity.PackStage,Verity.Variant,1,'None'),Biome='Limited',Tier=tierOf(Verity.Variant),
   Spawn=nil,How={{Source='Verity quest',Text='hand her a Void Pack'}},DropTitle='DROPS',Drops=d,DropTotal=t,Limited=true}
 end
 sections[#sections+1]=special
 -- pack sizes: how often a pack is bigger (the table every roll uses; 1x, the usual size, is left out)
 local sizes={}
 for _,row in ipairs(Rules.PackSizes)do
  if row.Weight<50 then sizes[#sizes+1]={Scale=row.Scale,Label=Sizes.Format(row.Scale)..'x',Percent=row.Weight,Text=Odds.Format(row.Weight)}end
 end
 return{Entries=entries,Sections=sections,Sizes=sizes,Version=version,Spawn=spawn,Config=cfg}
end
-- Every string the tab can show for an entry, flattened (tests scan them; the view draws from the same fields).
function D.Texts(entry)
 local t={entry.Name,entry.Biome,entry.Tier.Name,entry.DropTitle}
 if entry.Spawn then t[#t+1]=entry.Spawn.Text;t[#t+1]=entry.Spawn.Of end
 for _,a in ipairs(entry.Also or{})do t[#t+1]=a.Source;if a.Text then t[#t+1]=a.Text end end
 for _,a in ipairs(entry.How or{})do t[#t+1]=a.Source;if a.Text then t[#t+1]=a.Text end end
 for _,g in ipairs(entry.Drops)do t[#t+1]=g.Label;t[#t+1]=g.Text;for _,s in ipairs(g.Seeds)do t[#t+1]=s.Name;t[#t+1]=s.Text end end
 return t
end
return D
