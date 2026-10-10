--!nocheck
-- R150 pedestal harness (shared by test_pedestal_look, test_pedestal_fx and the previews' dump scripts): the R149 zfight_world mock (Model pivots, ScaleTo,
-- bounding boxes, full CFrames, scene dump) with the real MysteryPackService / MysteryPedestalArt on bases, the real MysteryPackClient / MysteryPedestalFx
-- as the local player, and the helpers to drive a pedestal the way MysteryPackService.Publish does (attributes first, then the pack and the look).
local Z=require('./zfight_world');local W=Z.W;local R=Z.R;local V3,CF=R.Vector3.new,R.CFrame.new
local F=require('./fixtures')
local H={Z=Z,W=W,R=R}
local RS=W.RS
local Run=W.service('RunService')
W.env.bit32=bit32
-- The mock's CFrame:Inverse is a transpose (right for an exact rotation only): a model moved with PivotTo every frame multiplies its own rounding error
-- by two each frame and blows up in about 60 frames. A real inverse (cofactors) keeps it steady, like Roblox's.
do
 local mt=getmetatable(CF(0,0,0))
 rawset(mt,'Inverse',function(c)
  local m=c.R;local a,b,cc,d,e,f,g,h,i=m[1][1],m[1][2],m[1][3],m[2][1],m[2][2],m[2][3],m[3][1],m[3][2],m[3][3]
  local det=a*(e*i-f*h)-b*(d*i-f*g)+cc*(d*h-e*g)
  local r11,r12,r13=(e*i-f*h)/det,(cc*h-b*i)/det,(b*f-cc*e)/det
  local r21,r22,r23=(f*g-d*i)/det,(a*i-cc*g)/det,(cc*d-a*f)/det
  local r31,r32,r33=(d*h-e*g)/det,(b*g-a*h)/det,(a*e-b*d)/det
  local p=c.Position
  return R.CFrame.new(-(r11*p.X+r12*p.Y+r13*p.Z),-(r21*p.X+r22*p.Y+r23*p.Z),-(r31*p.X+r32*p.Y+r33*p.Z),r11,r12,r13,r21,r22,r23,r31,r32,r33)
 end)
end
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='Sound'then o.IsLoaded=true;o.TimeLength=3;o.TimePosition=0;o.Loaded=R.signal();o.Ended=R.signal()end
 if class=='ProximityPrompt'then o.Triggered=R.signal();o.PromptShown=R.signal();o.PromptHidden=R.signal();o.TriggerEnded=R.signal()end
 return o end
 W.env.Instance=R.Instance
end
-- Instance:Clone keeps attributes and points a clone's PrimaryPart at the CLONE's own part (the mock copied the property as it was: a cloned pack's PivotTo then
-- measured itself against the original pack's part and drifted).
do
 local raw=R.Inst.Clone
 local function pathTo(root,target)
  local path={};local x=target
  while x and x~=root do local p=x._parent;if not p then return nil end;for i,c in ipairs(p._children)do if c==x then table.insert(path,1,i)end end;x=p end
  if x~=root then return nil end;return path
 end
 function R.Inst.Clone(self)
  local c=raw(self)
  for k,v in pairs(self._attrs)do c._attrs[k]=v end
  local pp=self._props.PrimaryPart
  if pp then local path=pathTo(self,pp);if path then local t=c;for _,i in ipairs(path)do t=t._children[i]end;c._props.PrimaryPart=t end end
  return c
 end
end
-- TweenService: tweens really run over their time (a Heartbeat step), for numbers, Vector3, Color3 and UDim2 properties; Quad-out by default, Back
-- overshoots. H.tweens() = how many are running.
do
 local Tween=W.service('TweenService');local active={}
 local function ease(style,u)
  u=math.clamp(u,0,1);local name=type(style)=='table'and style.Name or tostring(style)
  if name=='Back'then local s=1.70158;return 1+(s+1)*(u-1)^3+s*(u-1)^2 end
  return 1-(1-u)^2
 end
 local function lerp(a,b,e)
  if type(a)=='number'then return a+(b-a)*e end
  if type(a)=='table'and a.__type=='UDim2'then return R.UDim2.new(a.X.Scale+(b.X.Scale-a.X.Scale)*e,a.X.Offset+(b.X.Offset-a.X.Offset)*e,a.Y.Scale+(b.Y.Scale-a.Y.Scale)*e,a.Y.Offset+(b.Y.Offset-a.Y.Offset)*e)end
  if type(a)=='table'and a.__type=='Color3'then return a:Lerp(b,e)end
  return a+(b-a)*e -- Vector3
 end
 function Tween.Create(_,obj,info,props)
  local t={Obj=obj,Props=props,Info=info,Completed=R.signal(),Done=false}
  function t:Play()self.Start={};for k in pairs(self.Props)do self.Start[k]=obj[k]end;self.T0=R.clock;self.Playing=true;active[#active+1]=self end
  function t:Cancel()self.Playing=false end
  return t
 end
 W.Run.Heartbeat:Connect(function()
  for i=#active,1,-1 do
   local t=active[i]
   if not t.Playing or t.Obj._destroyed then table.remove(active,i)
   else
    local u=(R.clock-t.T0)/math.max(t.Info.Time or .001,.001);local e=ease(t.Info.Style,u)
    for k,v in pairs(t.Props)do t.Obj[k]=u>=1 and v or lerp(t.Start[k],v,e)end
    if u>=1 then t.Playing=false;table.remove(active,i);t.Completed:Fire()end
   end
  end
 end)
 function H.tweens()return #active end
end
-- Debris removes things after their time; ParticleEmitter:Emit counts what was emitted.
W.service('Debris').AddItem=function(_,o,t)R.task.delay(t,function()o:Destroy()end)end
function R.Inst.Emit(self,n)self._emitted=(self._emitted or 0)+(n or 1)end
W.service('ContentProvider').PreloadAsync=function()end
-- The place's SeedPackMeshAssets (stand-in meshes) so Visuals.Bag builds packs.
F.packAssets(W)
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
function H.server(n)return W.require(folder[n])end
H.workspace=W.workspace;H.CS=W.CS
-- Sounds, all recorded in H.sounds: InteractionAudio.Play(key) as key; RarityRevealAudio.Play(key) as 'Reveal:<key>'; a Sound instance played (SoundTiming
-- -> Sound:Play, the real AudioMixer routing it) as 'Sound:<name>' with its SoundGroup. ClientFxBudget.Get() is whatever H.tier says (3 high, 2 medium, 1 low).
H.sounds={};H.tier=3
W.stub('InteractionAudio',{Play=function(key)H.sounds[#H.sounds+1]={Key=key,At=R.clock};return true end})
W.stub('RarityRevealAudio',{Play=function(key,pitch,skip,volume)H.sounds[#H.sounds+1]={Key='Reveal:'..key,At=R.clock,Pitch=pitch,Volume=volume};return true end,Preload=function()end})
function R.Inst.Play(self)self._plays=(self._plays or 0)+1;H.sounds[#H.sounds+1]={Key='Sound:'..self.Name,At=R.clock,Group=self.SoundGroup,Sound=self}end
W.stub('ClientFxBudget',{Get=function()return H.tier end,Low=function()return H.tier==1 end})
function H.soundCount(key)local n=0;for _,s in ipairs(H.sounds)do if s.Key==key then n+=1 end end;return n end
-- Players ---------------------------------------------------------------------------------------------------------------------------------------
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
H.players={}
function Players.GetPlayers()local out={};for _,p in ipairs(H.players)do out[#out+1]=p end;return out end
function Players.GetPlayerByUserId(_,id)for _,p in ipairs(H.players)do if p.UserId==id then return p end end;return nil end
function H.player(id,name,local_)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;H.players[#H.players+1]=p
 if local_ then Players.LocalPlayer=p;local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=p end
 return p
end
-- A character standing at `at` (a Vector3): HumanoidRootPart + Humanoid.
function H.character(p,at)
 local m=R.new('Model');m.Name=p.Name
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.CFrame=CF(at.X,at.Y,at.Z);root.Parent=m
 local hum=R.new('Humanoid');hum.Health=100;hum.Parent=m;m.PrimaryPart=root;m.Parent=W.workspace;p.Character=m
 return m,root,hum
end
-- Bases and pedestals -----------------------------------------------------------------------------------------------------------------------------
H.records={}
function H.service()
 if not H.svc then H.svc=H.server('MysteryPackService').new({},{},{Map=nil},{},{},{MapRoot=W.workspace})end
 return H.svc
end
-- A base: a Model with a 200 x 2 x 200 Pad, its pedestal built by the real service. cframe: the pad's CFrame (turn it to try a rotated base).
function H.base(index,cframe)
 local model=R.new('Model');model.Name='Base'..index;model:SetAttribute('BaseIndex',index);model.Parent=W.workspace
 local pad=R.new('Part');pad.Name='Pad';pad.Size=V3(118,1,180);pad.Color=R.Color3.fromRGB(88,142,66);pad.Material=R.Enum.Material.Plastic -- (the real base pad: 118 x 1 x 180)
 pad.CFrame=cframe or CF(300*index,4.5,0);pad.Parent=model
 local rec={Index=index,Model=model,Pad=pad};H.records[#H.records+1]=rec
 H.service():_build(rec);return rec
end
function H.pedestal(rec)return H.svc.Pedestals[rec]end
-- Drives a pedestal the way MysteryPackService.Publish does: the attributes (in Publish's order), the prompt, then the pack and the look.
-- state: Empty / Locked / Ready / Claimed. o: {Owner, Name, Stage, Variant, UnlockIn, NextIn}.
function H.publish(rec,state,o)
 o=o or{};local p=H.svc.Pedestals[rec];local m=p.Model
 local function set(k,v)if m:GetAttribute(k)~=v then m:SetAttribute(k,v)end end
 if state=='Empty'then
  for _,k in ipairs({'OwnerUserId','OwnerName','UnlockAt','Variant'})do m:SetAttribute(k,nil)end
  m:SetAttribute('State','Empty');p.Prompt.Enabled=false;H.svc:_look(p,'Empty');return
 end
 local stage=o.Stage or 1
 set('OwnerUserId',o.Owner);set('OwnerName',o.Name or'Tester');set('State',state);set('Stage',stage)
 set('Variant',state~='Locked'and(o.Variant or'Pack03')or nil);set('NextAt',math.floor(R.clock+(o.NextIn or 40000)))
 if state=='Locked'then set('UnlockAt',math.floor(R.clock+(o.UnlockIn or 900)))else set('UnlockAt',nil)end
 if p.Prompt.Enabled~=(state=='Ready')then p.Prompt.Enabled=state=='Ready'end
 H.svc:_look(p,state,stage,state~='Locked'and(o.Variant or'Pack03')or nil)
end
function H.model(rec)return H.svc.Pedestals[rec].Model end
function H.fxFolder(rec)return H.model(rec):FindFirstChild('MysteryFx')end
function H.pack(rec)local h=H.model(rec):FindFirstChild('MysteryPack');return h and h:FindFirstChildWhichIsA('Model')end
-- The client ---------------------------------------------------------------------------------------------------------------------------------------
function H.loadClient()
 local sc=R.new('LocalScript');sc.Name='MysteryPackClient';W.load('MysteryPackClient',sc);H.client=sc;return sc
end
-- The camera: standing at `from`, looking at `at`.
function H.look(from,at)W.workspace.CurrentCamera.CFrame=R.CFrame.lookAt(from,at)end
-- Time: `seconds` of game time in frames (the render loop runs when connected) and half-second steps in between (the client's tick, tweens and delays).
function H.run(seconds,dt)
 dt=dt or 1/30;local n=math.floor(seconds/dt+.5)
 for _=1,n do W.frames(1,dt)end
end
-- How many functions are connected to RenderStepped right now.
function H.renderConnections()local n=0;for _,c in ipairs(W.Run.RenderStepped._c)do if c.Connected then n+=1 end end;return n end
-- Parts of a model / folder by name prefix.
function H.parts(root,prefix)
 local out={};for _,d in ipairs(root:GetDescendants())do if d:IsA('BasePart')and(prefix==nil or d.Name:sub(1,#prefix)==prefix)then out[#out+1]=d end end;return out
end
function H.count(root,class)local n=0;for _,d in ipairs(root:GetDescendants())do if d:IsA(class)then n+=1 end end;return n end
function H.bursts()local n=0;for _,c in ipairs(W.workspace:GetChildren())do if c.Name=='MysteryBurst'then n+=1 end end;return n end
function H.named(name)local n=0;for _,c in ipairs(W.workspace:GetChildren())do if c.Name==name then n+=1 end end;return n end
return H
