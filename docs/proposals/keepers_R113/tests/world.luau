--!nocheck
-- A small client world on the tools/tests Roblox mock, with exact CFrame math (cfmath) and real module loading.
local R=require('./roblox');local Mx=require('./cfmath')
local W={}
local Inst=R.Inst
Inst.Emit=function(self,n)self._emitted=(self._emitted or 0)+n;W.emitted+=n;W.emits+=1 end
Inst.Play=function(self)self._props.IsPlaying=true end
Inst.Stop=function(self)self._props.IsPlaying=false end
W.emitted=0;W.emits=0
function W.new(bundle,stubs)
 local new=R.new;local world={Now=100,Clock=0,Stubs=stubs or {}}
 local game=new('DataModel');local services={}
 local function service(n)local s=services[n];if not s then s=new(n);s.Name=n;s.Parent=game;services[n]=s end;return s end
 function game.GetService(_,n)return service(n)end
 local workspace=service('Workspace');local RS=service('ReplicatedStorage');local Run=service('RunService')
 Run.RenderStepped=R.signal();Run.Heartbeat=R.signal();world.Bound={}
 function Run.IsClient()return true end;function Run.IsServer()return false end
 function Run.BindToRenderStep(_,name,priority,fn)world.Bound[name]={P=priority,F=fn}end
 function Run.UnbindFromRenderStep(_,name)world.Bound[name]=nil end
 function workspace.GetServerTimeNow()return world.Now end
 local moved={};world.Moved=moved
 function workspace.BulkMoveTo(_,ps,fs)for i,p in ipairs(ps)do moved[p]=fs[i];p._props.CFrame=fs[i]end;world.LastBulk=#ps end
 local cam=new("Camera");cam.CFrame=Mx.CFrame.new(0,10,40);workspace.CurrentCamera=cam;function cam.WorldToViewportPoint(_,p)return p,true end
 local gs=service('GuiService');gs.ReducedMotionEnabled=false;local deb=service('Debris');function deb.AddItem(_,o,t)R.task.delay(t,function()o:Destroy()end)end
 local players=service('Players');local lp=new('Player');lp.Name='Me';lp.UserId=77;lp.Parent=players;players.LocalPlayer=lp
 function players.GetPlayerByUserId(_,id)if id==77 then return lp end end
 lp.CharacterRemoving=R.signal()
 local char=new('Model');char.Name='Me';local hrp=new('Part');hrp.Name='HumanoidRootPart';hrp.CFrame=Mx.CFrame.new(0,4,-60);hrp.Parent=char;char.Parent=workspace;lp.Character=char
 world.Me=hrp
 for name in pairs(bundle)do local m=new('ModuleScript');m.Name=name;m.Parent=RS end
 local cache={}
 local osx=setmetatable({clock=function()return world.Clock end},{__index=os})
 local env
 local function req(m)
  local name=type(m)=='string'and m or m.Name
  if world.Stubs[name]then return world.Stubs[name]end
  if cache[name]~=nil then return cache[name]end
  local fn=assert(loadstring(assert(bundle[name],'no module '..name),'='..name))
  setfenv(fn,setmetatable({script=RS:FindFirstChild(name)},{__index=env}))
  local v=fn();cache[name]=v;return v
 end
 env=setmetatable({game=game,workspace=workspace,Instance=R.Instance,Vector3=Mx.Vector3,CFrame=Mx.CFrame,Color3=R.Color3,Vector2=R.Vector2,UDim2=R.UDim2,UDim=R.UDim,
  ColorSequence=R.ColorSequence,ColorSequenceKeypoint=R.ColorSequenceKeypoint,NumberSequence=R.NumberSequence,NumberSequenceKeypoint=R.NumberSequenceKeypoint,NumberRange=R.NumberRange,
  Enum=R.Enum,typeof=R.typeof,task=R.task,require=req,os=osx,warn=function()end,print=print},{__index=_G})
 world.Game=game;world.Workspace=workspace;world.RS=RS;world.Run=Run;world.Env=env;world.require=req;world.Player=lp
 function world.run(name)
  local sc=new('LocalScript');sc.Name=name
  local fn=assert(loadstring(bundle[name],'='..name));setfenv(fn,setmetatable({script=sc},{__index=env}));fn();return sc
 end
 function world.step(dt)
  world.Now+=dt;world.Clock+=dt;R.advance(dt)
  local list={};for n,b in pairs(world.Bound)do table.insert(list,b)end;table.sort(list,function(a,b)return a.P<b.P end)
  local cam=workspace.CurrentCamera;local before=cam.CFrame
  for _,b in ipairs(list)do if b.P<Enum_Camera then b.F(dt)end end
  Run.RenderStepped:Fire(dt)
  for _,b in ipairs(list)do if b.P>=Enum_Camera then b.F(dt)end end
 end
 return world
end
Enum_Camera=R.Enum.RenderPriority.Camera.Value
W.R=R;W.Mx=Mx
return W
