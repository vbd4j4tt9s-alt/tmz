--!nocheck
-- R153: dumps every real roll table of the game: SeedOdds for every stage x variant x odds version x luck x boost (the banked packs' versions too), the Void / Verity / Mech rows, the
-- Index chip numbers (Pack01 at the current version, as ChestService printed them before R153) and seeded rolls (version-less numbers and draw functions) for every pack kind.
-- Run on the base (before R153) and on this checkout: run_seed_rarity.sh requires the two dumps to be IDENTICAL, byte for byte (nothing the server rolls changed).
-- When SeedRarity153 exists it also prints CANON lines (the new fixed chance of every seed, as text): those are checked separately, not part of the comparison.
local W=require('./world');local R=W.R;local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal();function Players.GetPlayers()return {}end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
W.env.bit32=bit32
local Config=W.require(folder.Config);local Rules=W.module('SeedPackRules');local Odds=W.module('OddsText85')
print('VALIDATE',pcall(Config.Validate))
local function canon(t)local k={};for id,p in pairs(t or{})do k[#k+1]=id..'='..string.format('%.12g',p)end;table.sort(k);return table.concat(k,' ')end
for stage=1,9 do for _,v in ipairs({'Pack01','Pack02','Pack03','Pack04','Pack05','Pack06','Small','Standard','Grand','EclipseReliquary','VerityReliquary','MechLimited'})do for _,ver in ipairs({'nil',0,81,112,137,149})do
 for _,l in ipairs({1,50,500,20000,1000000,50000000})do for _,b in ipairs({0,2})do
  local ok,t=pcall(Rules.SeedOdds,Config,stage,v,l,ver~='nil'and ver or nil,b==2 and 2 or nil)
  print(('ODDS %d %s v%s L%g B%d %s'):format(stage,v,tostring(ver),l,b,ok and canon(t)or'ERROR'))
 end end end end end
-- the Index chips as ChestService printed them before R153 (BaseChance = Pack01, luck 1, at the current version)
for stage,defs in ipairs(Config.SeedCatalogByStage)do for index,seed in ipairs(defs)do if not Rules.IsRetired(seed.Id)then
 local at=Rules.ObtainableStage(seed.Id)or stage
 local p=Rules.SeedOdds(Config,at,'Pack01',1)[seed.Id]
 print(('INDEX %s %d %.12g %s'):format(seed.Id,at,p or -1,Odds.Format(p)))
end end end
-- the hold tooltips' rows (OddsRows + Format, as ChestService:_holdPack builds them): a pack's own odds, unchanged
for _,pack in ipairs({{1,'Pack01'},{4,'Pack03'},{7,'Pack06'},{7,'EclipseReliquary'},{7,'VerityReliquary'},{8,'MechLimited'}})do
 local stage,v=pack[1],pack[2];local odds=Rules.SeedOdds(Config,stage,v,1,Rules.OddsVersion);local rows={}
 for _,seed in ipairs(Rules.OddsRows(Config,stage,v,odds))do rows[#rows+1]=seed.Name..': '..Odds.Format(odds[seed.Id])end
 print('TIP '..stage..' '..v..' '..table.concat(rows,' | '))
end
for _,ver in ipairs({'nil',0,81,112,137,149})do local version=ver~='nil'and ver or nil
 print('VOID '..tostring(ver)..' '..canon(Rules.SeedOdds(Config,7,'EclipseReliquary',1,version)))
 print('VERITY '..tostring(ver)..' '..canon(Rules.SeedOdds(Config,7,'VerityReliquary',1,version)))
 print('MECH '..tostring(ver)..' '..canon(Rules.SeedOdds(Config,8,'MechLimited',1,version)))end
local function rolls(ver,stage,v,luck,n)
 local s=12345;local function draw()s=(s*1103515245+12345)%2147483648;return s/2147483648 end
 local counts={}
 for _=1,n do local seed,rar=Rules.Roll(Config,stage,ver=='nil'and draw()or draw,luck,v,ver~='nil'and ver or nil);local k=(seed and seed.Id or'nil')..':'..tostring(rar);counts[k]=(counts[k]or 0)+1 end
 local k={};for id,c in pairs(counts)do k[#k+1]=id..'='..c end;table.sort(k)
 print(('ROLL %s %d %s L%g %s'):format(tostring(ver),stage,v,luck,table.concat(k,' ')))
end
for _,ver in ipairs({'nil',81,112,137,149})do for _,stage in ipairs({1,2,3,4,5,6,7})do for _,v in ipairs({'Pack01','Pack04','Pack06'})do rolls(ver,stage,v,1,3000);rolls(ver,stage,v,500,1000)end end end
for _,ver in ipairs({'nil',112,137,149})do rolls(ver,7,'EclipseReliquary',1,6000);rolls(ver,7,'VerityReliquary',1,6000);rolls(ver,8,'MechLimited',1,3000)end
-- the rarity of every seed (what the announcements decide by)
for _,spec in ipairs(Rules.SeedDesigns)do print('RARITY '..spec.id..' '..tostring(Rules.GetRarity(spec.id)))end
-- the new module (absent on the base)
local ok,Canon=pcall(function()return W.module('SeedRarity153')end)
if ok and Canon then for _,r in ipairs(Canon.All())do print(('CANON %s %s %.12g'):format(r.Id,r.Text,r.Percent))end end
