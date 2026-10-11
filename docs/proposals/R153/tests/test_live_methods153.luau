--!nocheck
-- R153 (architecture review, item 2: code that never runs): which functions are LIVE, with the REAL server modules on the mock (clover_env).
--  * ChestService's garden methods are GardenPlantRuntime's (GardenPlantRuntime.Install, at the end of ChestService.lua), its tool hooks are
--    HarvestToolService's; ChestService.lua no longer carries the old copies (R153 replaced them with a pointer).
--  * ChaseService is wrapped by ConcurrentKeeperService (the end of ChaseService.lua): every method the wrapper defines is the one that runs. The
--    old copies of those methods are still in ChaseService.lua (that file is frozen by the keeper suites); this test lists them by name so an edit
--    goes to ConcurrentKeeperService.lua.
local E=require('./clover_env');local W,R,check=E.W,E.R,E.check
local function from(fn,chunk)
 if type(fn)~='function'then return false end
 local ok,s=pcall(debug.info,fn,'s');return ok and tostring(s):find(chunk,1,true)~=nil
end
local Chests=E.server('ChestService')
for _,name in ipairs({'RenderGarden','BuildArtLibrary','BuildGrowthModel','BuildPlantAt'})do
 check(from(Chests[name],'GardenPlantRuntime'),'ChestService.'..name..' is GardenPlantRuntime\'s')
end
for _,name in ipairs({'SyncTools','CleanupPlayer'})do
 check(from(Chests[name],'HarvestToolService'),'ChestService.'..name..' is HarvestToolService\'s wrapper')
end
local src=W.B and W.B.ChestService or''
for _,name in ipairs({'RenderGarden','BuildArtLibrary','BuildGrowthModel','BuildPlantAt'})do
 check(not src:find('function ChestService:'..name..'(',1,true),'ChestService.lua no longer defines its never-run '..name)
end
local Chase=E.server('ChaseService')
local Legacy=getmetatable(Chase)and getmetatable(Chase).__index
check(type(Legacy)=='table'and Legacy~=Chase,'ChaseService is the ConcurrentKeeperService wrapper over the old ChaseService table')
local live,shadowed={},{}
for name,fn in pairs(Chase)do
 if type(fn)=='function'then
  check(from(fn,'ConcurrentKeeperService'),'ChaseService.'..name..' runs from ConcurrentKeeperService')
  live[#live+1]=name
  if name~='new'and type(Legacy)=='table'and type(rawget(Legacy,name))=='function'then shadowed[#shadowed+1]=name end -- (new: the wrapper's calls the old one)
 end
end
table.sort(live);table.sort(shadowed)
check(#shadowed>=10,'the wrapper replaces the old Begin / Finish / Start / ... ('..#shadowed..' methods)')
for _,name in ipairs({'Begin','Finish','Start','_updateActiveRun','_maintainGuardians','_dropChestAfterCatch'})do
 check(table.find(shadowed,name)~=nil,'ChaseService:'..name..' in ChaseService.lua never runs (ConcurrentKeeperService\'s does)')
end
print('INFO live ChaseService methods (ConcurrentKeeperService.lua): '..table.concat(live,', '))
print('INFO never-run copies still in ChaseService.lua (frozen file): '..table.concat(shadowed,', '))
print(('%d checks, %d failures'):format(E.Checks,E.Fails))
if E.Fails>0 then error('FAILED')end
