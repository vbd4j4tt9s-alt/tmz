--!nocheck
-- R151 test environment for the pull reveals, on top of the R113 mock world (real ReplicatedStorage modules from rs_bundle) and the R150
-- SFX environment (every Sound recorded). Adds what the reveal touches and must restore:
--  * Lighting (snapshot of every property and child), the Camera (type, CFrame, Focus, FieldOfView, subject, viewport size),
--  * StarterGui Core GUI states, the PlayerModule controls (Disable / Enable counted), Humanoid:GetState / Died,
--  * Models that really move and scale (PivotTo / ScaleTo move every part, as on Roblox), ParticleEmitter:Emit counts,
--  * the published seed art + catalog (real SeedPackVisuals seeds), keepers (BiomeKeeper), a few HUD ScreenGuis,
--  * helpers: run(seconds), live listeners on a signal, the screen-space rectangles of a GUI object.
-- Usage: local W=require('./world');local E=require('./sfx_env')(W);local F=require('./fixtures');local X=require('./rare_env')(W,E,F)
return function(W,E,F)
 local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
 local X={W=W,E=E,R=R}
 -- CFrame helpers ---------------------------------------------------------------------------------------------------------------------
 R.CFrame.lookAt=function(p,t,up)
  local f=(t-p).Unit;local u0=up or V3(0,1,0)
  if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
  local r=f:Cross(u0).Unit;local u=r:Cross(f)
  return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
 end
 R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
 W.env.CFrame=R.CFrame
 -- Models: PivotTo / ScaleTo move and scale every part (the shared mock only sets a property) ------------------------------------------------
 local Inst=R.Inst
 local function parts(m)local out={};for _,d in ipairs(m:GetDescendants())do if d:IsA('BasePart')then out[#out+1]=d end end;return out end
 -- (each part's offset from the pivot is taken once and reused, as an exact rigid move: chaining the mock's approximate inverse frame
 -- after frame would drift and blow up)
 function Inst:GetPivot()
  if self._class=='Model'then
   if self._pivot then return self._pivot end
   local pp=self._props.PrimaryPart;if pp and pp._props.CFrame then return pp._props.CFrame end
   if self._props.WorldPivot then return self._props.WorldPivot end
   local cf=self:GetBoundingBox();return cf
  end
  return self._props.CFrame
 end
 function Inst:PivotTo(c)
  if self._class~='Model'then self.CFrame=c;return end
  local list=parts(self)
  if not self._offsets or self._offsetCount~=#list then
   local inv=self:GetPivot():Inverse();self._offsets={};self._offsetCount=#list
   for _,p in ipairs(list)do self._offsets[p]=inv*p._props.CFrame end
  end
  for _,p in ipairs(list)do local o=self._offsets[p];if o then p.CFrame=c*o end end
  self._pivot=c;self._props.CFrame=c
 end
 function Inst:ScaleTo(s)
  if self._class~='Model'then return end
  local cur=self._scale or 1;local k=s/cur;if k==1 then return end
  local piv=self:GetPivot()
  for _,p in ipairs(parts(self))do
   local rel=piv:Inverse()*p._props.CFrame
   p.CFrame=piv*CF(rel.Position.X*k,rel.Position.Y*k,rel.Position.Z*k)*rel.Rotation
   p.Size=p._props.Size*k
  end
  self._scale=s;self._offsets=nil;X.scaled=(X.scaled or 0)+1
 end
 function Inst:GetScale()return self._scale or 1 end
 -- Clone copies attributes and points a Model's PrimaryPart at its own copy, as Roblox does (the shared mock keeps neither)
 function Inst:Clone()
  local map={}
  local function copy(o)
   local c=R.new(o._class,table.clone(o._props));c._attrs=table.clone(o._attrs);map[o]=c
   for _,ch in ipairs(o._children)do copy(ch).Parent=c end
   return c
  end
  local root=copy(self)
  for o,c in pairs(map)do local pp=o._props.PrimaryPart;if pp and map[pp]then c._props.PrimaryPart=map[pp]end end
  return root
 end
 function Inst:Emit(n)self._emitted=(self._emitted or 0)+(n or 0);X.emits=(X.emits or 0)+(n or 0)end
 -- the client effects budget (ClientFxBudget) is fixed by the test (the mock's 30 fps frames would otherwise read as a slow device)
 X.lowFx=false
 do local B=W.module('ClientFxBudget');B.Low=function()return X.lowFx==true end;B.Get=function()return X.lowFx and 1 or 3 end end
 -- Lighting ------------------------------------------------------------------------------------------------------------------------
 local Lighting=W.service('Lighting')
 Lighting.Brightness=2;Lighting.ClockTime=14;Lighting.Ambient=R.Color3.fromRGB(70,70,80);Lighting.OutdoorAmbient=R.Color3.fromRGB(120,120,130);Lighting.ExposureCompensation=0
 do local cc=R.new('ColorCorrectionEffect');cc.Name='BiomeGrade';cc.Brightness=.02;cc.Saturation=.1;cc.Parent=Lighting end
 do local a=R.new('Atmosphere');a.Name='Atmosphere';a.Density=.3;a.Parent=Lighting end
 local function shot(o)
  local t={};for k,v in pairs(o._props)do t[k]=tostring(v)end
  local kids={};for _,c in ipairs(o:GetChildren())do kids[#kids+1]=c.Name..'#'..tostring(c)end
  t.__children=table.concat(kids,',');return t
 end
 function X.lighting()
  local out={Root=shot(Lighting)}
  for _,c in ipairs(Lighting:GetChildren())do out[c.Name]=shot(c)end
  return out
 end
 function X.same(a,b)
  for k,v in pairs(a)do
   if type(v)=='table'then if type(b[k])~='table'or not X.same(v,b[k])then return false,k end
   elseif b[k]~=v then return false,k end
  end
  for k in pairs(b)do if a[k]==nil then return false,k end end
  return true
 end
 -- Camera ------------------------------------------------------------------------------------------------------------------------
 local camera=W.workspace.CurrentCamera
 camera.CameraType=R.Enum.CameraType.Custom;camera.FieldOfView=70;camera.CFrame=CF(3,9,112);camera.Focus=CF(0,3,100);camera.ViewportSize=R.Vector2.new(1280,720)
 function X.camera()local c=W.workspace.CurrentCamera;return {Camera=c,Type=c.CameraType,CFrame=tostring(c.CFrame.Position)..'|'..tostring(c.CFrame.LookVector),Focus=tostring(c.Focus and c.Focus.Position),Fov=c.FieldOfView,Subject=c.CameraSubject}end
 -- Core GUI ------------------------------------------------------------------------------------------------------------------------
 local SG=W.service('StarterGui');X.core={PlayerList=true,Chat=true,EmotesMenu=true,Health=true,Backpack=false};X.coreWrites=0
 function SG.GetCoreGuiEnabled(_,ty)return X.core[ty.Name]end
 function SG.SetCoreGuiEnabled(_,ty,on)X.core[ty.Name]=on;X.coreWrites+=1 end
 -- Player, character, controls -------------------------------------------------------------------------------------------------------
 E.player('Tester')
 local player,pg,char,root,hum=E.Player,E.pg,E.char,E.root,E.hum
 player.UserId=7
 root.Size=V3(2,2,1);root.CFrame=CF(0,3,100)
 do local t=R.new('Part');t.Name='UpperTorso';t.Size=V3(2,2,1);t.CFrame=CF(0,5,100);t.Parent=char end
 hum.Died=R.signal();X.state=R.Enum.HumanoidStateType.Running
 hum.GetState=function()return X.state end
 camera.CameraSubject=hum
 local ps=R.new('Folder');ps.Name='PlayerScripts';ps.Parent=player
 X.controls={Enabled=true,Disables=0,Enables=0}
 function X.controls.Disable(self)self.Enabled=false;self.Disables+=1 end
 function X.controls.Enable(self)self.Enabled=true;self.Enables+=1 end
 local pm=W.stub('PlayerModule',{GetControls=function()return X.controls end});pm.Parent=ps
 -- HUD: two ScreenGuis on (one is re-enabled by its own script while hidden), one already off, the touch controls
 local function sg(name,on)local g=R.Instance.new('ScreenGui');g.Name=name;g.Enabled=on;g.Parent=pg;return g end
 X.hud={Main=sg('HudMain',true),Hotbar=sg('Hotbar',true),Menu=sg('SeedMenuGui',false),Touch=sg('TouchGui',true)}
 -- Published seed art and catalog ----------------------------------------------------------------------------------------------------
 F.packAssets(W)
 local Visuals=W.module('SeedPackVisuals');local Packs=W.module('SeedPackRules')
 local remotes=W.RS:FindFirstChild('ChestChaseRemotes')or R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
 local art=R.new('Folder');art.Name='SeedArt';art.Parent=remotes
 local seeds=R.new('Folder');seeds.Name='Seeds';seeds.Parent=art
 local cat=R.new('Folder');cat.Name='SeedCatalog';cat.Parent=remotes
 X.seedIds={}
 function X.seed(id,chance)
  local spec=Packs.SeedDesignById[id];local def=R.new('Folder');def.Name=id;def:SetAttribute('DisplayName',spec and spec.name or id);def:SetAttribute('BaseChance',chance or 1);def.Parent=cat
  local m=Visuals.Seed({Id=id},1,CF(0,0,0),nil,1,nil,'None');m.Name=id;m.Parent=seeds
  X.seedIds[#X.seedIds+1]=id;return m
 end
 -- one seed of every rarity (ids from the roster; GetRarity is the authority)
 X.byRank={}
 local want={Common=1,Uncommon=2,Rare=3,Legendary=4,Mythic=5,Secret=6,Cosmic=7,King=8}
 for _,spec in ipairs(Packs.SeedDesigns)do
  local name=Packs.GetRarity(spec.id);local rank=want[name]
  if rank and not X.byRank[rank]then X.byRank[rank]=spec.id;X.seed(spec.id,({50,25,6,1.6,.25,.05,.004,.00006})[rank])end
 end
 -- Keepers ------------------------------------------------------------------------------------------------------------------------
 local CS=W.CS
 function X.keeper(pos,attrs)
  local k=R.new('Model');k.Name='Keeper';local r=R.new('Part');r.Name='HumanoidRootPart';r.CFrame=CF(pos.X,pos.Y,pos.Z);r.Parent=k;k.PrimaryPart=r;k.Parent=W.workspace
  for a,v in pairs(attrs or{})do k:SetAttribute(a,v)end
  CS:AddTag(k,'BiomeKeeper');return k
 end
 -- Helpers ------------------------------------------------------------------------------------------------------------------------
 X.player,X.pg,X.char,X.root,X.hum=player,pg,char,root,hum
 function X.run(seconds,dt,each)
  dt=dt or 1/30
  for _=1,math.max(1,math.floor(seconds/dt+.5))do W.frames(1,dt);if each then each(R.clock)end end
 end
 function X.live(signal)local n=0;for _,c in ipairs(signal._c)do if c.Connected then n+=1 end end;return n end
 -- absolute rectangle of a GuiObject on a W x H screen (scale + offset against the parent, AnchorPoint; UIScale and rotation ignored)
 function X.rect(o,Wd,Ht)
  local chain={};local x=o;while x and x:IsA('GuiObject')do table.insert(chain,1,x);x=x.Parent end
  local px,py,pw,ph=0,0,Wd,Ht
  for _,g in ipairs(chain)do
   local s,p=g.Size,g.Position;local ap=g.AnchorPoint or R.Vector2.new(0,0)
   local w=s.X.Scale*pw+s.X.Offset;local h=s.Y.Scale*ph+s.Y.Offset
   local ax=px+p.X.Scale*pw+p.X.Offset;local ay=py+p.Y.Scale*ph+p.Y.Offset
   px,py,pw,ph=ax-ap.X*w,ay-ap.Y*h,w,h
  end
  return px,py,pw,ph
 end
 function X.find(root,name)return root and root:FindFirstChild(name,true)end
 return X
end
