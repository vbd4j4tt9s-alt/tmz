--!nocheck
-- R153 performance patch, lag audit D9: the world packs' re-skin spread over the end of the closed window, with the REAL ChestService and the real pack
-- builders / templates (R151 pack harness: pack_world.luau, pouch_mock.luau, the server modules of this checkout). Two servers with the same random
-- streams and the same 35 spots:
--   A  the reopening re-skins all 35 in one frame (SkinWorldSeeds, as before R153 and as any caller without the spread still does)
--   B  ChestService:_spreadWorldSkins (called by SetWorldPacksClosed(true)): from 2 s before the reopening, 2 packs a frame (a real yielding
--      task.wait here), then the reopening (SkinWorldSeeds)
-- Checked: while B spreads, every pack it re-skinned is hidden (PackVisible false, every part Transparency 1), unavailable, its prompt off, has no
-- weather and sent no rare-pack alert; nothing starts before the last 2 s. After the reopening A and B are identical: each spot's tier, size,
-- mutation, shape, odds version, generation, weather, availability, visibility, prompt; the same rare-pack alerts in the same order (and frame);
-- the same next plan; the same pity counters. A step that errors leaves the rest to the reopening, which finishes them all the same.
local H=require('./pack_world');local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local Mock=require('./pouch_mock')(W)
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
function Players.GetPlayers()return{}end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='ProximityPrompt'then o.Triggered=R.signal()end
 return o end end
local ChestService=server('ChestService');local Shapes=W.module('PackShapes151');local Weather=W.module('WeatherTraits')
-- (the shape roll draws from one generator shared by both servers: here it takes a fixed draw, so A and B plan the same shapes)
do local raw=Shapes.Roll;Shapes.Roll=function(v,u)return raw(v,u or .37)end end
local assets=RS.SeedPackMeshAssets
for _,model in ipairs(assets:GetChildren())do for _,p in ipairs(model:GetChildren())do p.MeshSize=p.Size end end
-- a scheduler where task.wait really yields (the spread's loop), driven by advance()
local sleeping={}
local T=table.clone(R.task)
T.spawn=function(f,...)local co=type(f)=='thread'and f or coroutine.create(f);local ok,e=coroutine.resume(co,...);if not ok then error(debug.traceback(co,tostring(e)),0)end;return co end
T.wait=function(t)t=t or 0;if not coroutine.isyieldable()then return t end;table.insert(sleeping,{At=R.clock+math.max(t,1/60),Co=coroutine.running()});coroutine.yield();return t end
W.env.task=T
local function advance(dt) -- one server frame of dt
 R.advance(dt)
 local due,keep={},{}
 for _,s in ipairs(sleeping)do if s.At<=R.clock+1e-9 then due[#due+1]=s else keep[#keep+1]=s end end
 sleeping=keep
 for _,s in ipairs(due)do local ok,e=coroutine.resume(s.Co);if not ok then error(debug.traceback(s.Co,tostring(e)),0)end end
end
-- the world: 35 spots (7 biomes x 5), the map attributes the refresh writes, a weather that is on (so packs can take it), recorded alerts
local function makeServer(label)
 local runtime=R.new('Folder');runtime.Name='Runtime_'..label;runtime.Parent=W.workspace
 local root=R.new('Folder');root.Name='Map_'..label;root.Parent=W.workspace
 local alerts={}
 local applied={}
 local weather={Glows={},PackSeen={}}
 function weather:State()return 'Rain',3 end
 function weather:ApplyPack(seed,kind,cycle)
  if not seed.Available then return false end
  applied[#applied+1]=seed.Model.Name..':'..seed.Generation
  if(seed.SeedIndex*7+seed.Generation)%3==0 then seed.Weather='Rain';seed.Model:SetAttribute('WeatherTrait','Rain')end
  return true
 end
 local fake0={}
 local fake=setmetatable({Map={Refreshing=false,Chests={},MapRoot=root},PackRandom=W.env.Random.new(11),Weather=weather,
  RarePackSpawn={FireAllClients=function(_,a)alerts[#alerts+1]=string.format('%s @%.3f',tostring(a.SpawnId),R.clock-(fake0.T0 or 0))end}},ChestService)
 fake.FindPackPlacement=function(self,preferred,stage,variant,size)return CF(preferred),self:GetPackBounds(stage,variant,size)end
 for i=1,35 do
  local stage=1+(i-1)%7
  local model=R.new('Model');model.Name='Seed_'..i;model.Parent=runtime
  local body=R.new('Part');body.Name='Body';body.CFrame=CF(i*10,0,stage*10);body.Anchored=true;body.Parent=model
  fake.Map.Chests[i]={Stage=stage,SeedIndex=i,Model=model,Body=body,Prompt=R.new('ProximityPrompt'),Billboard=R.new('BillboardGui'),Glow=R.new('PointLight'),PartState={},PackHome=body.Position,Available=false}
 end
 fake.Alerts,fake.Applied=alerts,applied
 fake0=fake -- (alerts are timed from the start of the refresh: A and B run one after the other)
 return fake
end
check(Weather.Events.Rain~=nil,'(Rain is a weather event, so the packs roll for it)')
local A,B=makeServer('A'),makeServer('B')
-- both start from the same first refresh (as a server's start does)
for _,s in ipairs({A,B})do s:SkinWorldSeeds(0);table.clear(s.Alerts);table.clear(s.Applied)end
local function state(s)
 local out={}
 for i,seed in ipairs(s.Map.Chests)do
  local packet=seed.Model:FindFirstChild('SeedPacket')
  local hidden=0;if packet then for _,p in ipairs(packet:GetDescendants())do if p:IsA('BasePart')and p.Transparency>=1 then hidden+=1 end end end
  out[i]=table.concat({tostring(seed.BagVariant),tostring(seed.PackSize),tostring(seed.PackMutation),tostring(seed.PackShape),tostring(seed.OddsVersion),tostring(seed.Generation),
   tostring(seed.Weather),tostring(seed.Available),tostring(seed.Prompt.Enabled),tostring(packet and packet:GetAttribute('PackVisible')),tostring(hidden),tostring(seed.Model:GetAttribute('PackAvailable'))},' ')
 end
 return out
end
local CLOSED=10;local DT=1/60
-- the refresh: closes at t0, reopens at t0 + 10 s
local function refresh(s,spread)
 local t0=R.clock;s.T0=t0;local cycle=(s.Map.MapRoot:GetAttribute('BiomeRefreshCycle')or 0)+1
 s.Map.MapRoot:SetAttribute('BiomeRefreshEndsAt',W.workspace:GetServerTimeNow()+CLOSED)
 s.Map.Refreshing=true
 if spread then s:SetWorldPacksClosed(true)else for _,seed in ipairs(s.Map.Chests)do s:SetWorldPackAvailable(seed,seed.Available)end end
 return t0,cycle
end
local function reopen(s,cycle)
 s:SkinWorldSeeds(cycle)
 s.Map.Refreshing=false
 s:SetWorldPacksClosed(false)
 s.Map.MapRoot:SetAttribute('BiomeRefreshCycle',cycle)
end
for round=1,3 do
 -- A: the old way (no spread: the closure does not start one), all in the reopening frame
 local t0A,cycleA=refresh(A,false)
 local framesA=math.floor(CLOSED/DT+.5)
 for _=1,framesA do advance(DT)end
 reopen(A,cycleA)
 -- B: the spread
 local t0B,cycleB=refresh(B,true)
 local early,leaks,firstAt,lastAt=0,0,nil,nil
 local framesB=math.floor(CLOSED/DT+.5)
 local before=B.Map.Chests[1].Generation
 for f=1,framesB do
  advance(DT)
  local job=B.SkinJob
  if job and job.Next>1 then
   firstAt=firstAt or R.clock-t0B;if job.Next==36 and not lastAt then lastAt=R.clock-t0B end
   if R.clock-t0B<CLOSED-ChestService.SkinSpread-1e-6 then early+=1 end
   for i=1,job.Next-1 do
    local seed=B.Map.Chests[i];local packet=seed.Model:FindFirstChild('SeedPacket')
    local hidden=packet and packet:GetAttribute('PackVisible')==false
    if packet then for _,p in ipairs(packet:GetDescendants())do if p:IsA('BasePart')and p.Transparency<1 then hidden=false end end end
    if not hidden or seed.Available or seed.Prompt.Enabled or seed.Weather~='None'then leaks+=1 end
   end
  end
 end
 check(#B.Alerts==0 and #B.Applied==0,'round '..round..': while the spread builds, no rare-pack alert and no weather roll ('..#B.Alerts..' alerts, '..#B.Applied..' rolls)')
 check(firstAt~=nil and early==0,'round '..round..': nothing is built before the last '..ChestService.SkinSpread..' s (first at '..tostring(firstAt and string.format('%.2f',firstAt))..' s)')
 check(B.SkinJob and B.SkinJob.Next==36,'round '..round..': all 35 packs were built before the reopening (next '..tostring(B.SkinJob and B.SkinJob.Next)..')')
 check(lastAt and lastAt<=CLOSED-ChestService.SkinSpread+.4,'round '..round..': ... 2 a frame: done '..string.format('%.2f',(lastAt or 0)-(CLOSED-ChestService.SkinSpread))..' s after it started')
 check(leaks==0,'round '..round..': every pack built during the closure stayed hidden, unavailable, prompt off, without weather ('..leaks..' frames x packs showed something)')
 reopen(B,cycleB)
 local sa,sb=state(A),state(B);local diff=0;local first
 for i=1,35 do if sa[i]~=sb[i]then diff+=1;first=first or('spot '..i..': '..sa[i]..' / '..sb[i])end end
 check(diff==0,'round '..round..': after the reopening every spot is the same as the old one-frame re-skin ('..diff..' differ'..(first and('; '..first)or'')..')')
 check(table.concat(A.Alerts,',')==table.concat(B.Alerts,','),'round '..round..': the same rare-pack alerts, same order, same moment ('..#A.Alerts..' / '..#B.Alerts..')')
 check(table.concat(A.Applied,',')==table.concat(B.Applied,','),'round '..round..': the same weather rolls in the same order ('..#A.Applied..')')
 check(A.WorldPlan and B.WorldPlan and A.WorldPlan.Cycle==B.WorldPlan.Cycle and table.concat(A.WorldPlan.Variants,',')==table.concat(B.WorldPlan.Variants,',')
  and table.concat(A.WorldPlan.Sizes,',')==table.concat(B.WorldPlan.Sizes,','),'round '..round..': the same plan for the next refresh')
 check(A.TrackLuck==B.TrackLuck or(type(A.TrackLuck)=='table'and type(B.TrackLuck)=='table'),'round '..round..': the track pity moved the same way')
 table.clear(A.Alerts);table.clear(B.Alerts);table.clear(A.Applied);table.clear(B.Applied)
end
-- a step that errors: the rest is left to the reopening, which finishes everything the same
do
 local C=makeServer('C');local D=makeServer('D')
 for _,s in ipairs({C,D})do s:SkinWorldSeeds(0);table.clear(s.Alerts);table.clear(s.Applied)end
 local _,cycleC=refresh(C,false);for _=1,600 do advance(DT)end;reopen(C,cycleC)
 local raw=D.RefreshWorldPack;local calls=0
 D.RefreshWorldPack=function(self,seed,...)calls+=1;if calls==9 and select(7,...)~=nil then error('a bad spot')end;return raw(self,seed,...)end
 local warned=0;local w=W.env.warn;W.env.warn=function()warned+=1 end
 local _,cycleD=refresh(D,true);for _=1,600 do advance(DT)end
 W.env.warn=w
 check(warned==1 and D.SkinJob and D.SkinJob.Next==9,'a failing spot stops the spread (warned '..warned..', next '..tostring(D.SkinJob and D.SkinJob.Next)..')')
 reopen(D,cycleD)
 local sc,sd=state(C),state(D);local diff=0;for i=1,35 do if sc[i]~=sd[i]then diff+=1 end end
 check(diff==0 and table.concat(C.Alerts,',')==table.concat(D.Alerts,','),'... and the reopening finishes the rest: the same packs and alerts as the one-frame re-skin ('..diff..' differ)')
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
