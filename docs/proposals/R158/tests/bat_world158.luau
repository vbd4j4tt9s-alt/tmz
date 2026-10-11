--!nocheck
-- R158 bats: a small SERVER world on the Roblox mock (tools/tests/roblox.luau) that runs the REAL BatService of a checkout with its REAL helpers
-- (BatConfig, BatHitbox, BatLagComp, SecurityGate) on a clock the test drives. Faked: MovementGuard (always fine), BatArt (a plain Tool), the chase
-- (its _validCharacter is ConcurrentKeeperService's, HitByBat records the call), the map (the track starts at Z = LineZ), walls (Raycast against
-- vertical wall segments). Two variants can live side by side: 'now' (this checkout) and 'base' (today's code from git, for the comparisons).
-- Usage: local World=require('./bat_world158'); local w=World.new('now') ... w:frame(dt) ...
local R=require('./roblox');local B=require('./bat_bundle')
local V3,CF=R.Vector3.new,R.CFrame.new
local World={R=R,B=B}
World.__index=World
local clock={T=1000}
World.clock=clock
local function now()return clock.T end
function World.new(variant,opts)
 opts=opts or{}
 local w=setmetatable({Variant=variant,Hits={},Fired={},Down={},Walls={},Players={},Ping={},LineZ=opts.LineZ or-100,Inside=opts.Inside},World)
 local suffix=variant=='base'and'_base'or''
 local game=R.new('DataModel')
 local services={}
 local function service(n)local s=services[n];if not s then s=R.new(n);s.Name=n;services[n]=s end;return s end
 game.GetService=function(_,n)return service(n)end
 local Players=service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
 Players.GetPlayers=function()local out={};for _,p in ipairs(w.Players)do out[#out+1]=p end;return out end
 local Run=service('RunService');Run.Heartbeat=R.signal()
 local RS=service('ReplicatedStorage')
 local ws=service('Workspace');ws.GetServerTimeNow=function()return clock.T end
 ws.Raycast=function(_,origin,dir,params)
  -- vertical walls: 2D segments (x0,z0)-(x1,z1); the ray is the 2D segment origin..origin+dir
  local ax,az,bx,bz=origin.X,origin.Z,origin.X+dir.X,origin.Z+dir.Z
  for _,wall in ipairs(w.Walls)do
   local cx,cz,dx,dz=wall[1],wall[2],wall[3],wall[4]
   local r1x,r1z,r2x,r2z=bx-ax,bz-az,dx-cx,dz-cz
   local den=r1x*r2z-r1z*r2x
   if math.abs(den)>1e-9 then
    local t=((cx-ax)*r2z-(cz-az)*r2x)/den;local u=((cx-ax)*r1z-(cz-az)*r1x)/den
    if t>=0 and t<=1 and u>=0 and u<=1 then w.RayHits=(w.RayHits or 0)+1;return {Position=V3(ax+r1x*t,origin.Y,az+r1z*t)}end
   end
  end
  return nil
 end
 w.game,w.PlayersService,w.Run,w.RS,w.workspace=game,Players,Run,RS,ws
 local folder=R.new('Folder');folder.Name='ChestChaseServer'
 local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes'
 local alert=R.new('RemoteEvent');alert.Name='RunAlert';alert.Parent=remotes
 local swing=R.new('RemoteEvent');swing.Name='BatSwing';swing.OnServerEvent=R.signal();swing.Parent=remotes
 swing.FireAllClients=function(_,packet)w.Fired[#w.Fired+1]=packet end
 w.Remote=swing
 local loaded={}
 local env
 local function load(name,scriptInst)
  local src=B[name..suffix]or B[name];if not src then error('no source for '..name..suffix)end
  local fn,err=loadstring(src,'='..name..suffix);if not fn then error(err)end
  setfenv(fn,setmetatable({script=scriptInst},{__index=env}));return fn()
 end
 local function req(m)
  if loaded[m]~=nil then return loaded[m]end
  local v
  if m._stub~=nil then v=m._stub else v=load(m.Name,m)end
  loaded[m]=v;return v
 end
 local function module(parent,name,stub)local m=R.new('ModuleScript');m.Name=name;m._stub=stub;m.Parent=parent;return m end
 module(RS,'BatConfig');module(RS,'BatHitbox')
 module(folder,'BatService');module(folder,'BatLagComp');module(folder,'SecurityGate')
 module(folder,'MovementGuard',{Check=function()return true end})
 module(folder,'BatArt',{Create=function()local t=R.new('Tool');t.Name='Bat';t.Enabled=true;t:SetAttribute('ChestChaseBat',true)
  local h=R.new('Part');h.Name='Handle';h.Parent=t;return t end})
 env=setmetatable({game=game,workspace=ws,Instance=R.Instance,Vector3=R.Vector3,CFrame=R.CFrame,Enum=R.Enum,
  RaycastParams={new=function()return {}end},typeof=R.typeof,task=R.task,require=req,
  os={clock=now,time=function()return math.floor(clock.T)end},warn=function(...)w.Warns=(w.Warns or 0)+1 end},{__index=_G})
 w.Config=req(RS.BatConfig);w.Gate=req(folder.SecurityGate)
 if variant~='base'then w.Lag=req(folder.BatLagComp);w.Hitbox=req(RS.BatHitbox)else w.Hitbox=req(RS.BatHitbox)end
 local chase={RunAlertRemote=alert,Map={Refreshing=false,BaseBoundaryLine={Position=V3(0,0,w.LineZ)},
   IsInsideBiomeTrack=function(_,p)if w.Inside then return w.Inside(p)end;return p.Z>=w.LineZ-2 end},
  Ragdoll={CanHit=function(_,p)return p~=nil and p.Parent~=nil and not w.Down[p]end},Chests={IsOpening=function()return false end}}
 function chase:_validCharacter(player)
  if not player or not player.Parent then return nil end
  local character=player.Character
  local humanoid=character and character:FindFirstChildOfClass('Humanoid')
  local root=character and character:FindFirstChild('HumanoidRootPart')
  if not humanoid or not root or humanoid.Health<=0 then return nil end
  return character,humanoid,root
 end
 function chase:HitByBat(attacker,victim,character)w.Hits[#w.Hits+1]={A=attacker,V=victim,C=character,T=clock.T};return true end
 w.Chase=chase
 local Service=req(folder.BatService)
 w.Service=Service.new(chase);w.Service:Start()
 return w
end
-- a player with an R15-ish character (root + humanoid) at (x,3,z) facing (fx,fz); the bat is given and equipped.
-- (R158 review) Player:GetNetworkPing() answers w.Ping[player] (seconds; 0 when unset; 'fail' makes it error; p.GetNetworkPing=nil removes it)
function World:player(name,x,z,fx,fz,id)
 local p=R.new('Player');p.Name=name;p.UserId=id or(#self.Players+1)
 p.CharacterAdded=R.signal();p.CharacterRemoving=R.signal()
 local w=self
 p.GetNetworkPing=function(q)local v=w.Ping[q];if v=='fail'then error('GetNetworkPing failed')end;return v or 0 end
 local bag=R.new('Backpack');bag.Name='Backpack';bag.Parent=p
 p.Parent=self.PlayersService;table.insert(self.Players,p)
 self:character(p,x,z,fx,fz,true)
 self.PlayersService.PlayerAdded:Fire(p)
 local tool=self.Service.Tools[p];if tool then tool.Parent=p.Character end
 return p
end
function World:character(p,x,z,fx,fz,silent)
 local c=R.new('Model');c.Name=p.Name
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Parent=c
 local hum=R.new('Humanoid');hum.Health=100;hum.WalkSpeed=24;hum.PlatformStand=false;hum.Parent=c
 c.Parent=self.workspace;p.Character=c
 self:place(p,x or 0,3,z or 0,fx or 0,fz or 1)
 if not silent then p.CharacterAdded:Fire(c)local tool=self.Service.Tools[p];if tool then tool.Parent=c end end
 return c
end
function World:place(p,x,y,z,fx,fz)
 local root=p.Character.HumanoidRootPart
 if fx then root.CFrame=R.CFrame.lookAt(V3(x,y,z),V3(x+fx,y,z+fz))else root.CFrame=R.CFrame.new(x,y,z)*setmetatable({Position=V3(),R=root.CFrame.R},getmetatable(root.CFrame))end
end
function World:root(p)return p.Character.HumanoidRootPart end
-- one server frame at the current clock
function World:step()self.Run.Heartbeat:Fire(1/60)end
function World:remove(p)
 for i,q in ipairs(self.Players)do if q==p then table.remove(self.Players,i)break end end
 self.PlayersService.PlayerRemoving:Fire(p);p.Parent=nil
end
-- the client sends: a swing request / a hit claim (as BatClient does)
function World:request(p,start,id)return self.Service:Request(p,{Kind='Swing',Start=start,Id=id})end
function World:claim(p,t)
 local packet={Kind='Hit',Id=t.Id,Victim=t.Victim,ViewTime=t.ViewTime,Own=t.Own,Look=t.Look}
 return self.Service:Claim(p,packet)
end
return World
