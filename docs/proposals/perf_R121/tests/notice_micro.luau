--!nocheck
-- R121 micro-check: ChaseService:_setGuardianNoticeVisual per-Heartbeat cost and result.
local R=require('./roblox');local new=R.new
local which=...
local B=require('./cb_'..which)
local game=new('DataModel');local services={}
function game.GetService(_,n)local s=services[n];if not s then s=new(n);s.Name=n;s.Parent=game;services[n]=s end;return s end
local RS=game:GetService('ReplicatedStorage');local m=new('ModuleScript');m.Name='KeeperCombat';m.Parent=RS
local holder=new('Folder');local sc=new('ModuleScript');sc.Name='ChaseService';sc.Parent=holder
for _,n in ipairs({'ConcurrentKeeperService','StudioTestCommands'})do local x=new('ModuleScript');x.Name=n;x.Parent=holder end
local env=setmetatable({game=game,script=sc,workspace=game:GetService('Workspace'),Instance=R.Instance,task=R.task,
 require=function(mod)if mod.Name=='ConcurrentKeeperService'then return function(L)return L end end;return {}end},{__index=_G})
local fn=assert(loadstring(B.ChaseService,'=ChaseService'));setfenv(fn,env);local Chase=fn()
local guardian=new('Model');guardian.Name='Guardian'
for i=1,40 do local p=new('Part');p.Parent=guardian end
local tag=new('BillboardGui');tag.Parent=guardian.HumanoidRootPart or guardian
local scans=0;local raw=R.Inst.GetDescendants;R.Inst.GetDescendants=function(self)if self==guardian then scans+=1 end;return raw(self)end
local function guis()local n=0;for _,d in ipairs(raw(guardian))do if d:IsA('BillboardGui')or d:IsA('SurfaceGui')then n+=1 end end;return n end
Chase:_setGuardianNoticeVisual(guardian,true)
local first=guis()
scans=0;for i=1,600 do Chase:_setGuardianNoticeVisual(guardian,false)end
local idle=scans
local s=new('SurfaceGui');s.Parent=guardian
Chase:_setGuardianNoticeVisual(guardian,false)
local after=guis()
print(which,'guis after first call',first,'| GetDescendants over 600 heartbeats',idle,'| added SurfaceGui removed on next call',after==0)
