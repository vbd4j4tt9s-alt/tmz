--!nocheck
-- Mock client world for the planting-effect tests: real ReplicatedStorage sources, lazy require.
local R=require('./roblox')
local B=require('./rs_bundle')
local new,V3,CF=R.new,R.Vector3.new,R.CFrame.new
local W={R=R}
-- Roblox Random (xorshift; deterministic per seed).
local RandomMT={};RandomMT.__index=RandomMT
local function rnew(seed)
 local s=math.floor(tonumber(seed)or os.clock()*1e6)%2147483646+1
 return setmetatable({s=s},RandomMT)
end
function RandomMT:_next()self.s=(self.s*48271)%2147483647;return self.s/2147483647 end
function RandomMT:NextNumber(a,b)local u=self:_next();if a==nil then return u end;return a+(b-a)*u end
function RandomMT:NextInteger(a,b)return a+math.floor(self:_next()*(b-a+1))%(b-a+1)end
W.Random={new=rnew}
-- Extra Instance methods the effect uses.
local Inst=R.Inst
Inst.Play=function(self)self._playing=true;self._plays=(self._plays or 0)+1;W.plays[#W.plays+1]={Name=self.Name,Id=self.SoundId,Speed=self.PlaybackSpeed,Volume=self.Volume,Parent=self.Parent}end
Inst.Stop=function(self)self._playing=false end
Inst.Emit=function(self,n)self._emitted=(self._emitted or 0)+n;W.emits[#W.emits+1]={Name=self.Name,Count=n}end
Inst.Clear=function(self)end
Inst.GetServerTimeNow=function()return W.serverNow end
function W.build(opts)
 opts=opts or{}
 W.plays={};W.emits={};W.serverNow=opts.Now or 1800000000;W.moves=0
 local game=new('DataModel');local services={}
 local function service(name)local s=services[name];if not s then s=new(name);s.Name=name;s.Parent=game;services[name]=s end;return s end
 function game.GetService(_,n)return service(n)end
 local workspace=service('Workspace')
 workspace.GetServerTimeNow=function()return W.serverNow end
 local terrain=new('Terrain');terrain.Name='Terrain';terrain.Parent=workspace;workspace.Terrain=terrain
 local camera=new('Camera');camera.Name='Camera';camera.ViewportSize=R.Vector2.new(1280,720);camera.CFrame=CF(0,20,-30);camera.Parent=workspace;workspace.CurrentCamera=camera
 function camera.WorldToViewportPoint(self,p)
  local q=self.CFrame:Inverse()*p
  return V3(640+q.X*20,360-q.Y*20,-q.Z),-q.Z>0
 end
 function workspace.BulkMoveTo(_,parts,cframes)
  assert(#parts==#cframes,'BulkMoveTo sizes')
  for i,p in ipairs(parts)do p._props.CFrame=cframes[i];p._props.Position=cframes[i].Position end;W.moves+=#parts
 end
 local Run=service('RunService');Run.RenderStepped=R.signal();Run.Heartbeat=R.signal();Run.Stepped=R.signal()
 Run.IsStudio=function()return false end;Run.IsClient=function()return true end;Run.IsRunning=function()return true end
 local Gui=service('GuiService');Gui.ReducedMotionEnabled=opts.Reduced==true
 local UIS=service('UserInputService');UIS.TouchEnabled=false;UIS.KeyboardEnabled=true
 local Content=service('ContentProvider');function Content.PreloadAsync(_,list,cb)for _,s in ipairs(list)do s.IsLoaded=true;s.TimeLength=1.5;if cb then cb(s.SoundId,R.Enum.AssetFetchStatus.Success)end end end
 service('SoundService');service('Debris').AddItem=function()end
 local Players=service('Players')
 local player=new('Player');player.Name='Tester';player.UserId=opts.UserId or 1;player.Parent=Players;Players.LocalPlayer=player
 function Players.GetPlayers()return {player}end
 Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
 local RS=service('ReplicatedStorage')
 local modules={}
 for name in pairs(B)do local m=new('ModuleScript');m.Name=name;m._src=name;m.Parent=RS end
 local env
 local function load(name,scriptInst)
  local fn=assert(loadstring(B[name],'='..name))
  local e=setmetatable({script=scriptInst},{__index=env});setfenv(fn,e);return fn()
 end
 local function req(m)
  if modules[m]~=nil then return modules[m]end
  if m._src then local v=load(m._src,m);modules[m]=v;return v end
  error('require of unknown module '..tostring(m))
 end
 local quality=opts.Quality or 0
 local userSettings={GetService=function()return {SavedQualityLevel={Value=quality}}end}
 env=setmetatable({game=game,workspace=workspace,Instance=R.Instance,Vector3=R.Vector3,Vector2=R.Vector2,CFrame=R.CFrame,UDim=R.UDim,UDim2=R.UDim2,
  Color3=R.Color3,ColorSequence=R.ColorSequence,ColorSequenceKeypoint=R.ColorSequenceKeypoint,NumberSequence=R.NumberSequence,NumberSequenceKeypoint=R.NumberSequenceKeypoint,
  NumberRange=R.NumberRange,TweenInfo=R.TweenInfo,Enum=R.Enum,Random=W.Random,RaycastParams={new=function()return {}end},typeof=R.typeof,task=R.task,require=req,
  UserSettings=function()return userSettings end,
  os={clock=function()return R.clock end,time=function()return math.floor(W.serverNow)end},utf8=utf8,debug={profilebegin=function()end,profileend=function()end},
  warn=function(...)W.warnings=(W.warnings or 0)+1;print('WARN',...)end},{__index=_G})
 W.game=game;W.workspace=workspace;W.RS=RS;W.Run=Run;W.Gui=Gui;W.player=player;W.camera=camera;W.env=env;W.req=req;W.load=load;W.modules=modules
 return W
end
function W.frames(n,dt)
 dt=dt or 1/60
 for _=1,n do W.serverNow+=dt;R.advance(dt);W.Run.RenderStepped:Fire(dt);W.Run.Heartbeat:Fire(dt)end
end
return W
