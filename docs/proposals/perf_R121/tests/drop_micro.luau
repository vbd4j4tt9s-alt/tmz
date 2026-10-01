--!nocheck
-- R121 micro-check: dropped-pack countdown label writes per second, and the text shown.
local R=require('./roblox');local new=R.new
local which=...
local B=require('./kb_'..which)
local game=new('DataModel');local services={}
function game.GetService(_,n)local s=services[n];if not s then s=new(n);s.Name=n;s.Parent=game;services[n]=s end;return s end
local RS=game:GetService('ReplicatedStorage');game:GetService('Players').GetPlayers=function()return {}end
local holder=new('Folder');local sc=new('ModuleScript');sc.Name='K';sc.Parent=holder
for _,n in ipairs({'RagdollService','KeeperContact','BatService','SecurityGate','MovementGuard','VeiledEvent81'})do local x=new('ModuleScript');x.Name=n;x.Parent=holder end
local clock=0
local env=setmetatable({game=game,script=sc,workspace=game:GetService('Workspace'),Instance=R.Instance,task=R.task,os={clock=function()return clock end},
 require=function(mod)return {}end},{__index=_G})
for _,n in ipairs({'SeedPackRules','KeeperCombat','KeeperRecoveryDash','StormConfig','KnockbackConfig'})do local x=new('ModuleScript');x.Name=n;x.Parent=RS end
local fn=assert(loadstring(B.K,'=K'));setfenv(fn,env);local factory=fn()
local Service=factory({})
local self=setmetatable({Runs={},KeeperTargets={},Drops={},GuardianMaintenanceAccumulator=0,Config={DroppedChestClaimGrace=.35}},Service)
function self:_updateBiomeRefresh()end;function self:_updateReturningGuardians()end;function self:_maintainGuardians()end
local expired=false;function self:_expireDroppedChest(t)expired=true;self.Drops[t]=nil end
local label=new('TextLabel');label.Parent=new('Folder')
local writes=0;local mt=getmetatable(label);local raw=mt.__newindex
mt.__newindex=function(o,k,v)if o==label and k=='Text'then writes+=1 end;return raw(o,k,v)end
self.Drops[1]={Label=label,ExpiresAt=5}
local seen={}
for i=1,60*6 do clock+=1/60;self:_heartbeat(1/60);seen[label.Text]=true end
local texts={};for t in pairs(seen)do table.insert(texts,t)end;table.sort(texts)
print(which,'label writes over 6 s',writes,'texts',table.concat(texts,' '),'expired',expired)
