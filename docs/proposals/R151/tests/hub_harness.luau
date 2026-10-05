--!nocheck
-- R151 hub display harness (shared by every hub suite and the preview dump): the R150 pedestal harness (the R149 zfight_world mock: Model pivots, ScaleTo, bounding boxes,
-- full CFrames; Tween, Debris, Players, characters) plus
--   * a MemoryStoreService mock of one shared backend that several "servers" talk to: GetAsync / UpdateAsync / RemoveAsync with Roblox's compare-and-set (the transform runs
--     again when the key changed between its read and its commit: HH.race hooks an interference at exactly that moment), expiry, request counts, and injected failures;
--   * Players:GetHumanoidDescriptionFromUserId / CreateHumanoidModelFromDescription (an R15 rig with real Motor6D joint names, accessories, a Humanoid) with call counts and
--     failure modes;
--   * helpers: players with user ids, a fake clock, the fruit list, deep copy.
local H=require('./pedestal_harness');local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local HH={H=H,W=W,R=R}
local function copy(v)
 if type(v)~='table'then return v end
 local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
end
HH.copy=copy
-- MemoryStore ---------------------------------------------------------------------------------------------------------------------------------------
-- backend: {Maps = name -> key -> {Value, Version, Expires}, Now = function() -> seconds, Calls = {Get, Update, Remove, Set}, Fail = function(op, key) -> message | nil,
--           Race = function() | nil (runs once, between an UpdateAsync's read and its commit), Transforms = how many times UpdateAsync transforms ran}
function HH.backend()
 local b={Maps={},Calls={Get=0,Update=0,Remove=0,Set=0,GetMap=0},Transforms=0,Now=function()return R.clock end}
 function b.map(name)b.Maps[name]=b.Maps[name]or{};return b.Maps[name]end
 function b.peek(name,key)local e=b.map(name)[key];return e and copy(e.Value)or nil end
 return b
end
-- A service object for one server (HubDisplayStore's `Service`). Counts requests per instance in svc.Requests.
function HH.memoryService(backend)
 local svc={Requests=0,Maps={}}
 function svc.GetHashMap(_,name)
  backend.Calls.GetMap+=1
  if backend.FailGetMap then error(backend.FailGetMap,2)end
  local data=backend.map(name)
  local map={}
  local function live(key)local e=data[key];if e and e.Expires and backend.Now()>=e.Expires then data[key]=nil;return nil end;return e end
  local function check(op,key)
   svc.Requests+=1
   local why=backend.Fail and backend.Fail(op,key)
   if why then error(why,3)end
  end
  function map.GetAsync(_,key)backend.Calls.Get+=1;check('Get',key);local e=live(key);return e and copy(e.Value)or nil end
  function map.SetAsync(_,key,value,expiration)backend.Calls.Set+=1;check('Set',key);local e=data[key];data[key]={Value=copy(value),Version=(e and e.Version or 0)+1,Expires=expiration and backend.Now()+expiration or nil};return true end
  function map.RemoveAsync(_,key)backend.Calls.Remove+=1;check('Remove',key);data[key]=nil end
  function map.UpdateAsync(_,key,transform,expiration)
   backend.Calls.Update+=1;check('Update',key)
   for _=1,5 do
    local e=live(key);local version=e and e.Version or 0
    local old=e and copy(e.Value)or nil
    local interfere=backend.Race;if interfere then backend.Race=nil;interfere()end
    backend.Transforms+=1
    local new=transform(old)
    local current=live(key);local nowVersion=current and current.Version or 0
    if nowVersion==version then -- (nobody wrote in between: commit)
     if new==nil then return nil end
     data[key]={Value=copy(new),Version=version+1,Expires=expiration and backend.Now()+expiration or nil}
     return copy(new)
    end
    -- someone wrote in between: the transform runs again on the fresh value
   end
   error('UpdateAsync: too many retries',2)
  end
  svc.Maps[name]=map
  return map
 end
 return svc
end
-- Avatars -----------------------------------------------------------------------------------------------------------------------------------------------
-- hub_rig.luau: an R15-shaped rig (the 15 body parts + a HumanoidRootPart with Motor6D joints named as Roblox names them, a Humanoid, accessories, an Animate script) and the
-- two Players methods HubDisplayAvatar calls. HH.avatars = {Describe = n calls, Create = n calls, Mode = 'ok' | 'describe fails' | 'create fails' | 'throws', Accessories = n worn, Scale}.
local Rig=require('./hub_rig')(W,R)
HH.rig=Rig.rig
HH.avatars={Describe=0,Create=0,Mode='ok',Accessories=3,Scale=1,Last=nil}
function HH.installPlayers()return Rig.install(W.service('Players'),HH.avatars)end
-- Time ------------------------------------------------------------------------------------------------------------------------------------------------------
-- A fake clock for a server: seconds (timers) and Unix time (the day); set .unix to move the day.
function HH.clock(unix)
 local c={t=1000,unix=unix or 20000*86400+3600}
 c.now=function()return c.t end;c.time=function()return c.unix end
 function c.advance(s)c.t+=s;c.unix+=s end
 return c
end
HH.day0=20000 -- a day number (1 Oct 2026 is about 20,727)
function HH.player(id,name)
 local p=H.player(id,name or('Player'..id))
 p.DisplayName=name or('Player'..id)
 return p
end
return HH
