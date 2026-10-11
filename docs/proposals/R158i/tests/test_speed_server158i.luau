--!nocheck
-- R158i (owner: "increase the base speed of new players to 20k in-game speed but of course this is still displayed as 1 speed on their screen"), the server half, on the REAL player data (the R123 world):
--  1  Config: SpeedFloor = DefaultSpeed = 20000 = SpeedDisplay.Floor, the speed curve still starts at 0 points (Validate), ProfileVersion still 22;
--  2  a brand-new profile starts at 20,000 points; its player-list cell (leaderstats.Speed, the display string) reads 1; gains stay deltas (+60 -> 20,060 points, the cell reads 61);
--  3  an older profile below the floor (a saved SpeedExact 0 / 5000 / 19,999, or a legacy number-only save) is raised to 20,000 on load and SAVED (Dirty, SpeedExact '20000'); one at or above is untouched;
--  4  the shown number: 50,000 points read 30,001; the walk speed (a gameplay comparison) still comes from the real points.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={}
function Players.GetPlayers()local out={};for _,p in pairs(present)do out[#out+1]=p end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
local DS=W.service('DataStoreService');local stores={}
local function dsCopy(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=dsCopy(x)end;return o end
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(dsCopy(self.Data[key]),nil);if v~=nil then self.Data[key]=dsCopy(v)end;return dsCopy(self.Data[key])end,
  GetAsync=function(self,key)return dsCopy(self.Data[key])end,SetAsync=function(self,key,v)self.Data[key]=dsCopy(v)end}
 return stores[name]
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end;return o end end
R.clock=20727*86400+3600*5
local Config=server('Config');local Display=W.module('SpeedDisplay');local Points=W.module('SpeedPoints');local Progress=W.module('Progression81')
local Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
local Data=server('PlayerDataService').new(Config,Map,{Show=function()end})
local function makePlayer(id,name)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 Data:PreparePlayer(p);assert(Data:Load(p),'load '..name)
 return p
end
local function points(p)return Data:GetOrCreateSpeedValue(p).Value end
local function cell(p)return p:FindFirstChild('leaderstats'):FindFirstChild('Speed').Value end

-- 1. Config -----------------------------------------------------------------------------------------------------------------------------------------------------------
check(Config.SpeedFloor==20000 and Config.DefaultSpeed==20000 and Display.Floor==20000 and Display.Offset==19999,'1: SpeedFloor = DefaultSpeed = SpeedDisplay.Floor = 20000, offset 19,999')
check(Config.SpeedMilestones[1][1]==0 and Config.SpeedMilestones[1][2]==Config.BaseWalkSpeed,'1: the speed curve still starts at 0 points (the floor is a start, not a curve change)')
local okV,errV=pcall(Config.Validate);check(okV,'1: Config.Validate still passes ('..tostring(errV)..')')
check(Config.ProfileVersion==22,'1: ProfileVersion is still 22')

-- 2. A brand-new profile ----------------------------------------------------------------------------------------------------------------------------------------------
local N=makePlayer(401,'Newbie')
check(points(N)=='20000','2: a new profile starts with 20,000 speed points ('..tostring(points(N))..')')
check(cell(N)=='1','2: ... and its player-list cell reads 1 ('..tostring(cell(N))..')')
check(Data:AddSpeed(N,60)==60 and points(N)=='20060' and cell(N)=='61','2: +60 is a delta: 20,060 points, the cell reads 61 ('..points(N)..' / '..cell(N)..')')
check(Data:AddSpeed(N,30000)==30000 and points(N)=='50060' and cell(N)=='30.1K','2: 50,060 points: the cell reads 30.1K (30,061 shown, rounded for the narrow cell) ('..cell(N)..')')
check(Config.GetWalkSpeed('20000')>Config.BaseWalkSpeed and math.abs(Config.GetWalkSpeed('20000')-Progress.Speed('20000'))<1e-9,'4: the walk speed comes from the REAL points (20,000 points walk faster than 24) ('..Config.GetWalkSpeed('20000')..')')
local saved=Data:_buildSaveData(N)
check(saved.SpeedExact=='50060','2: the save holds the real points, not the shown number ('..tostring(saved.SpeedExact)..')')

-- 3. Older profiles ---------------------------------------------------------------------------------------------------------------------------------------------------
local function profile(id,mutate)
 local base=makePlayer(id,'Base'..id);local s=Data:_buildSaveData(base);mutate(s)
 Data.Store.Data['Player_'..(id+100)]=s
 local back=makePlayer(id+100,'Old'..id);return back
end
for _,case in ipairs({{'0'},{'5000'},{'19999'},{'1'}})do
 local id=500+tonumber(case[1])%97
 local p=profile(id,function(s)s.SpeedExact=case[1]end)
 check(points(p)=='20000' and cell(p)=='1','3: an older profile with '..case[1]..' points is raised to 20,000 and reads 1 ('..points(p)..' / '..cell(p)..')')
 check(Data.Dirty[p]==true and Data:_buildSaveData(p).SpeedExact=='20000','3: ... and it is saved that way (Dirty, SpeedExact 20000)')
end
do local p=profile(610,function(s)s.SpeedExact=nil;s.Speed=100;s.SpeedSystemVersion=Config.SpeedSystemVersion end)
 check(Points.Compare(points(p),'20000')>=0 and cell(p)=='1','3: a legacy save with only the old number is raised to the floor too ('..points(p)..')')
end
for _,case in ipairs({{'20000','1'},{'20001','2'},{'50000','30001'},{'123456789','123436790'}})do
 local p=profile(620+#case[1]+tonumber(case[1])%7,function(s)s.SpeedExact=case[1]end)
 check(points(p)==case[1] and Display.Shown(points(p))==case[2],'3: '..case[1]..' points stay as they are and read '..case[2]..' ('..points(p)..' / '..Display.Shown(points(p))..')')
end
local rich=profile(700,function(s)s.SpeedExact='50000' end)
check(cell(rich)=='30K' and Data:GetOrCreateSpeedValue(rich).Value=='50000','4: 50,000 points: the cell reads 30K (30,001 shown, rounded for the narrow cell), the raw stat is untouched')

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
