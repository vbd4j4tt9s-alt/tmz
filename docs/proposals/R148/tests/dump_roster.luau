--!nocheck
-- R148 roster change: dumps the plants, every banked-pack odds row, the Void / Verity / Mech rows, seeded rolls and the Fruit of the Hour list. Run on the base and on the change; check_roster_diff.py compares.
local W=require('./world');local R=W.R;local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal();function Players.GetPlayers()return {}end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
W.env.bit32=bit32
local Config=W.require(folder.Config);local Rules=W.module('SeedPackRules');local Hour=W.module('FruitOfHour')
print('VALIDATE',pcall(Config.Validate))
local ids={};for id in pairs(Config.GardenPlants)do ids[#ids+1]=id end;table.sort(ids)
local function pts(t)local o={};for _,p in ipairs(t or{})do o[#o+1]=('%.4f,%.4f,%.4f'):format(p[1],p[2],p[3])end;return table.concat(o,';')end
for _,id in ipairs(ids)do local d=Config.GardenPlants[id];local r={};for _,x in ipairs(d.FruitRadii or{})do r[#r+1]=('%.4f'):format(x)end
 print(('PLANT %s|%s|%s|%s|%s|%s|%s|%s|%s|%.4f|%.4f|%s|%s|%s|%s'):format(id,tostring(d.Seconds),tostring(d.RegrowSeconds),tostring(d.Value),tostring(d.Rarity),tostring(d.Rank),
  tostring(d.FruitCount),tostring(d.Name),tostring(d.HarvestName),d.Height,d.Radius,pts(d.Sockets),pts(d.FruitCenters),table.concat(r,';'),tostring(d.Regrows)))end
local function canon(t)local k={};for id,p in pairs(t or{})do k[#k+1]=id..'='..string.format('%.12g',p)end;table.sort(k);return table.concat(k,' ')end
for stage=1,7 do for _,v in ipairs({'Pack01','Pack02','Pack03','Pack04','Pack05','Pack06','Small','Standard','Grand'})do for _,ver in ipairs({0,81,112,137})do
 for _,l in ipairs({1,50,500,20000,1000000,50000000})do for _,b in ipairs({0,2})do
  print(('ODDS %d %s v%d L%g B%d %s'):format(stage,v,ver,l,b,canon(Rules.SeedOdds(Config,stage,v,l,ver,b==2 and 2 or nil))))
 end end end end end
for _,ver in ipairs({'nil',0,81,112,137,149})do local version=ver~='nil'and ver or nil
 print('VOID '..tostring(ver)..' '..canon(Rules.SeedOdds(Config,7,'EclipseReliquary',1,version)))
 print('VERITY '..tostring(ver)..' '..canon(Rules.SeedOdds(Config,7,'VerityReliquary',1,version)))
 print('MECH '..tostring(ver)..' '..canon(Rules.SeedOdds(Config,8,'MechLimited',1,version)))end
for _,ver in ipairs({'nil',81,112,137})do for _,stage in ipairs({1,2,3,4,5,6,7})do for _,v in ipairs({'Pack01','Pack04','Pack06'})do
 local s=12345;local function draw()s=(s*1103515245+12345)%2147483648;return s/2147483648 end
 local counts={}
 for _=1,4000 do local seed,rar=Rules.Roll(Config,stage,ver=='nil'and draw()or draw,1,v,ver~='nil'and ver or nil);local k=(seed and seed.Id or'nil')..':'..tostring(rar);counts[k]=(counts[k]or 0)+1 end
 local k={};for id,n in pairs(counts)do k[#k+1]=id..'='..n end;table.sort(k)
 print(('ROLL %s %d %s %s'):format(tostring(ver),stage,v,table.concat(k,' ')))end end end
print('FOH '..#Hour.Candidates()..' '..table.concat(Hour.Candidates(),','))
