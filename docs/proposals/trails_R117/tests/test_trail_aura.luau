--!nocheck
-- R117 trail tiers: ribbon looks (RunnerTrailArt), client auras (RunnerTrailAuraFx + RunnerTrailAura.client) and the
-- shop preview (ShopProductArt). Run from a scratch folder holding roblox.luau and the bundle:
--   cp <repo>/tools/tests/roblox.luau .
--   python3 <repo>/tools/tests/bundle.py aura_bundle.luau \
--     RunnerTrailArt=<src>/ReplicatedStorage/RunnerTrailArt.lua RunnerTrailAuraFx=<src>/ReplicatedStorage/RunnerTrailAuraFx.lua \
--     ClientFxBudget=<src>/ReplicatedStorage/ClientFxBudget.lua RunnerBootArt=<src>/ReplicatedStorage/RunnerBootArt.lua \
--     ShopProductArt=<src>/ReplicatedStorage/ShopProductArt.lua \
--     RunnerTrailAura=<src>/StarterPlayer/StarterPlayerScripts/RunnerTrailAura.client.lua
--   /opt/luau/luau test_trail_aura.luau      (or: sh run.sh <repo>)
local R=require('./roblox');local B=require('./aura_bundle')
local new,V3,CF=R.new,R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end end
-- Roblox behaviour the mock lacks: emitter/trail methods, and a destroyed instance's Parent is locked.
local emitted={}
R.Inst.Emit=function(self,n)emitted[self]=(emitted[self]or 0)+n end
R.Inst.Clear=function(self)end
local rawDestroy=R.Inst.Destroy
R.Inst.Destroy=function(self)rawDestroy(self);rawset(self,'_locked',true)end
local rawSet=R.instMeta.__newindex
R.instMeta.__newindex=function(o,k,v)if k=='Parent'and rawget(o,'_locked')then error('The Parent property of '..tostring(o)..' is locked')end;rawSet(o,k,v)end
-- World -------------------------------------------------------------------------------------------------------------
local game=new('DataModel');local services={}
local function service(name)local s=services[name];if not s then s=new(name);s.Name=name;s.Parent=game;services[name]=s end;return s end
function game.GetService(_,n)return service(n)end
local workspace=service('Workspace')
local camera=new('Camera');camera.CFrame=CF(0,10,0);camera.Parent=workspace;workspace.CurrentCamera=camera
-- Camera looks down -Z: anything with Z<0 is on screen.
function camera.WorldToViewportPoint(_,p)return p,p.Z<0 end
local Run=service('RunService');Run.Heartbeat=R.signal();Run.RenderStepped=R.signal();Run.IsClient=function()return false end
local UIS=service('UserInputService');UIS.TouchEnabled=false;UIS.KeyboardEnabled=true
local Gui=service('GuiService');Gui.ReducedMotionEnabled=false
local Players=service('Players');Players.PlayerRemoving=R.signal()
local RS=service('ReplicatedStorage')
local list={}
function Players.GetPlayers()return table.clone(list)end
local modules={};local env
local function load(name,scriptInst)local fn=assert(loadstring(B[name],'='..name));setfenv(fn,setmetatable({script=scriptInst},{__index=env}));return fn()end
local function req(m)if modules[m]~=nil then return modules[m]end;if m._source then modules[m]=load(m._source,m);return modules[m]end;error('unknown module '..tostring(m))end
local function module(name)local m=new('ModuleScript');m.Name=name;m.Parent=RS;m._source=name;return m end
for _,n in ipairs({'RunnerTrailArt','RunnerTrailAuraFx','ClientFxBudget','RunnerBootArt','ShopProductArt'})do module(n)end
env=setmetatable({game=game,workspace=workspace,Instance=R.Instance,Vector3=R.Vector3,Vector2=R.Vector2,CFrame=R.CFrame,Color3=R.Color3,Enum=R.Enum,
 ColorSequence=R.ColorSequence,ColorSequenceKeypoint=R.ColorSequenceKeypoint,NumberSequence=R.NumberSequence,NumberSequenceKeypoint=R.NumberSequenceKeypoint,
 NumberRange=R.NumberRange,typeof=R.typeof,task=R.task,require=req,os={clock=function()return R.clock end,time=os.time}},{__index=_G})
local Art=req(RS.RunnerTrailArt);local Fx=req(RS.RunnerTrailAuraFx)
local ORDER={'MintTrail','ArcTrail','SolarTrail','AuroraTrail','NebulaTrail','RoyalTrail'}
-- 1. Ribbon looks ----------------------------------------------------------------------------------------------------
local lastGlow,lastReach,lastAlpha=-1,-1,2
for i,id in ipairs(ORDER)do
 check(Art.Tier(id)==i,id..' tier '..i)
 for layer=1,2 do
  local t=new('Trail');Art.Configure(t,R.Color3.new(1,1,1),layer,id)
  check(#t.Color.A>=(layer==1 and 9 or 5),id..' layer '..layer..' multi-stop gradient')
  check(#t.Transparency.A>=4 and #t.WidthScale.A==5,id..' layer '..layer..' transparency/width curves')
  check(t.Texture==''and t.FaceCamera==true and t.Enabled==false,id..' plain, camera-facing, starts disabled')
  check(t:GetAttribute('TrailLayer117')==layer and t:GetAttribute('PlainColourTrail91')==true,id..' attributes')
  if layer==1 then
   check(t.LightEmission>lastGlow,id..' glows more than the tier below');lastGlow=t.LightEmission
   check(t.MaxLength>lastReach,id..' reaches further than the tier below');lastReach=t.MaxLength
   local head=t.Transparency.A[1].V;check(head<lastAlpha,id..' more solid head than the tier below');lastAlpha=head
  end
 end
 local base=Art.Sequence(id,1,0);local moved=Art.Sequence(id,1,.5)
 local same=true;for k=1,#base.A do local a,b=base.A[k].V,moved.A[k].V;if math.abs(a.R-b.R)+math.abs(a.G-b.G)+math.abs(a.B-b.B)>.01 then same=false end end
 check(same==(i<4),id..(i<4 and' has no colour drift'or' shimmers (colour drift/sheen)'))
end
-- 2. Effect layers per tier ------------------------------------------------------------------------------------------
local probe=Fx.new();local lastLayers,lastParts=0,0
for _,id in ipairs(ORDER)do
 local n=Fx.LayerCount(id);print(id..': '..n..' effect layers');check(n>lastLayers,id..' has more effect layers ('..n..') than the tier below ('..lastLayers..')');lastLayers=n
 local rig=probe:_build(id);local parts=0
 for _,L in ipairs(rig.Layers)do parts+=#L.Emitters+(L.Trail and 1 or 0)+(L.Light and 1 or 0)end
 check(parts>lastParts,id..' builds more effect pieces ('..parts..')');lastParts=parts
 for _,L in ipairs(rig.Layers)do for _,e in ipairs(L.Emitters)do
  check(type(e.Texture)=='string'and e.Texture:match('^rbxasset://textures/particles/[%w_]+%.dds$')~=nil,id..' '..e.Name..' uses a built-in texture')
 end end
 probe:_destroyRig(rig)
end
for name,src in pairs(B)do if name~='ShopProductArt'and name~='RunnerBootArt'then check(not src:find('rbxassetid'),name..' has no uploaded asset ids')end end
local sh=Fx.Specs.NebulaTrail.Layers;local hasIdle=false;for _,l in ipairs(sh)do if l.When=='Idle'then hasIdle=true end end;check(hasIdle,'Nebula idle shimmer')
for _,id in ipairs({'MintTrail','ArcTrail','SolarTrail','AuroraTrail'})do for _,l in ipairs(Fx.Specs[id].Layers)do check(l.When~='Idle','no idle shimmer below Nebula ('..id..')')end end
-- Budgets
local b3,b2,b1,br=Fx.Budget(3,false),Fx.Budget(2,false),Fx.Budget(1,false),Fx.Budget(3,true)
check(b1.Characters==1 and b1.MaxDetail==1 and b1.Range==0,'low quality: own motes only')
check(b2.Characters<b3.Characters and b2.Full<b3.Full and b2.Range<b3.Range and b2.Rate<b3.Rate,'medium quality is cheaper than high')
check(br.MaxDetail==2 and br.Motion==false and br.Rate<b3.Rate,'reduced motion: no animation, fewer particles')
check(Fx.Budget(3,false,2).Tier==1 and Fx.Budget(3,false,5).Tier==2,'graphics level caps the tier')
check(Fx.Detail(false,30,false,1,b3)==0,'off-screen runner parked')
check(Fx.Detail(false,200,true,1,b3)==0,'far runner gets nothing')
check(Fx.Detail(false,30,true,1,b3)==3 and Fx.Detail(false,30,true,4,b3)==2,'only the nearest few get full detail')
check(Fx.Detail(false,130,true,1,b3)==1,'distant on-screen runner gets motes only')
-- 3. Client end to end ---------------------------------------------------------------------------------------------
local nextId=1
local function addPlayer(name,isLocal)
 local p=new('Player');p.Name=name;p.UserId=nextId;nextId+=1;p.Parent=Players;table.insert(list,p)
 if isLocal then Players.LocalPlayer=p end
 return p
end
local function setFolder(character,id)
 local old=character:FindFirstChild('ChestChaseCosmetics');if old then old:Destroy()end
 local f=new('Folder');f.Name='ChestChaseCosmetics';f:SetAttribute('CosmeticVersion',91)
 if id then
  f:SetAttribute('TrailId84',id);f:SetAttribute('TrailLow84',-2.9);f:SetAttribute('TrailHigh84',2.4)
  for i=1,2 do local t=new('Trail');t.Name='RunnerRibbon'..i;t:SetAttribute('RunnerMovementTrail',true);Art.Configure(t,R.Color3.new(1,1,1),i,id);t.Parent=f end
 end
 f.Parent=character;return f
end
local function spawn(p,pos,id)
 local character=new('Model');character.Name=p.Name;character.Parent=workspace
 local h=new('Humanoid');h.Health=100;h.Sit=false;h.PlatformStand=false;h.FloorMaterial=R.Enum.Material.Plastic;h.Parent=character
 local root=new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.CFrame=CF(pos.X,pos.Y,pos.Z);root.AssemblyLinearVelocity=V3(0,0,0);root.Parent=character
 -- R118: an R15 head (head pieces and the crown glints live on it).
 local head=new('Part');head.Name='Head';head.Size=V3(1.2,1.2,1.2);head.CFrame=CF(pos.X,pos.Y+2.6,pos.Z);head.LocalTransparencyModifier=0;head.Parent=character
 p.Character=character;setFolder(character,id);return character,root
end
local me=addPlayer('Me',true);local myChar,myRoot=spawn(me,V3(0,5,-10),'RoyalTrail')
local others={}
-- 9 on-screen runners at increasing distance, 2 behind the camera, 1 far away.
for i=1,9 do local p=addPlayer('On'..i);local _,root=spawn(p,V3(i,5,-12-i*6),ORDER[(i-1)%6+1]);others[#others+1]={P=p,Root=root}end
local behind={};for i=1,2 do local p=addPlayer('Behind'..i);local _,root=spawn(p,V3(0,5,20+i*5),'NebulaTrail');behind[i]={P=p,Root=root}end
local far=addPlayer('Far');spawn(far,V3(0,5,-400),'RoyalTrail')
local clientScript=new('LocalScript');clientScript.Name='RunnerTrailAura'
-- Capture the manager the script builds.
local fx;local realNew=Fx.new;Fx.new=function()fx=realNew();return fx end
load('RunnerTrailAura',clientScript)
local function frames(n,dt)dt=dt or 1/20;for _=1,n do R.advance(dt);Run.RenderStepped:Fire(dt);Run.Heartbeat:Fire(dt)end end -- (R153: the aura steps in RenderStepped)
local function children(root)local n=0;for _,c in ipairs(root:GetChildren())do if c.Name:sub(1,10)=='TrailAura_'then n+=1 end end;return n end
local function layer(rec,name)for _,L in ipairs(rec.Rig.Layers)do if L.Spec.Name==name then return L end end end
local function setSpeed(root,s)root.AssemblyLinearVelocity=V3(0,0,-s)end
frames(2)
local mine=fx.Records[me]
check(mine and mine.Rig and mine.Detail==3,'local Royal runner gets a full rig')
check(children(myRoot)+children(myChar.Head)>=10,'aura attachments live on the local root and head')
local s=fx:Stats()
check(s.Rigs<=8,'at most 8 auras ('..s.Rigs..')')
local full=0;for p,rec in pairs(fx.Records)do if rec.Detail==3 and p~=me then full+=1 end end
check(full<=3,'at most 3 other runners at full detail ('..full..')')
check(fx.Records[far]==nil,'far runner not tracked')
for _,b in ipairs(behind)do local rec=fx.Records[b.P];check(not rec or rec.Detail==0,'runner behind the camera parked');check(children(b.Root)==0,'no aura built for an off-screen runner')end
-- Standing still -> idle shimmer (Royal), nothing moving-only.
frames(20)
check(layer(mine,'Idle').Emitters[1].Enabled==true,'Royal idle shimmer while standing')
check(layer(mine,'Glitter').Emitters[1].Enabled==false,'no moving glitter while standing')
local crownBefore=0;for _,e in ipairs(layer(mine,'Crown').Emitters)do crownBefore+=emitted[e]or 0 end
check(crownBefore>0,'crown twinkles while idle')
-- Start running -> burst, crown flash, glitter, both helix ribbons, light, swirl motion, sheen on the main ribbon.
local baseColor=myChar.ChestChaseCosmetics.RunnerRibbon1.Color
setSpeed(myRoot,40);local before=table.clone(emitted)
local helix=layer(mine,'GoldHelix');local p0=helix.A0.Position
frames(6)
local burst=layer(mine,'Burst').Emitters[1]
check((emitted[burst]or 0)>(before[burst]or 0),'start burst when you start running')
local crown=0;for _,e in ipairs(layer(mine,'Crown').Emitters)do crown+=(emitted[e]or 0)-(before[e]or 0)end;check(crown>=5,'crown flash on the start burst')
check(layer(mine,'Glitter').Emitters[1].Enabled and layer(mine,'Glitter').Emitters[1].Rate>0,'glitter while running')
check(layer(mine,'Idle').Emitters[1].Enabled==false,'idle shimmer stops while running')
check(helix.Trail.Enabled and layer(mine,'PurpleHelix').Trail.Enabled,'gold and purple helix ribbons while running')
check(helix.A0.Position~=p0,'helix ribbons swirl')
check(layer(mine,'Light').Light.Enabled,'local regal light')
check(myChar.ChestChaseCosmetics.RunnerRibbon1.Color~=baseColor,'gold sheen sweeps the main ribbon')
local steps=0;for _,e in ipairs(layer(mine,'Steps').Emitters)do steps+=(emitted[e]or 0)-(before[e]or 0)end;check(steps>0,'footstep glints while running on the ground')
local burstCount=emitted[burst];frames(10);check(emitted[burst]==burstCount,'no repeated bursts while running')
-- Other full-detail runners never get the local-only light.
for p,rec in pairs(fx.Records)do if p~=me and rec.Rig then local L=layer(rec,'Light');if L then check(not L.Light.Enabled,'no light for other runners')end end end
-- Changed trail: the server rebuilds the folder with another trail.
local royalRig=mine.Rig
setFolder(myChar,'MintTrail');frames(6)
mine=fx.Records[me]
check(mine and mine.Rig and mine.Rig.Id=='MintTrail','aura follows the new trail')
for _,a in ipairs(royalRig.All)do check(a.Parent==nil,'old Royal pieces left the root')end
check(children(myRoot)==#mine.Rig.All,'only the Mint aura on the root')
-- Removed trail.
setFolder(myChar,nil);frames(6)
check(fx.Records[me]==nil and children(myRoot)==0,'no aura without a trail')
-- Respawn: old character destroyed, new one with Royal.
setFolder(myChar,'RoyalTrail');frames(6);local oldRig=fx.Records[me].Rig
myChar:Destroy();local myChar2,myRoot2=spawn(me,V3(0,5,-10),'RoyalTrail');myChar=myChar2;myRoot=myRoot2
frames(6)
mine=fx.Records[me]
check(mine and mine.Rig and mine.Rig~=oldRig and mine.Root==myRoot2,'aura rebuilt on the new character')
check(oldRig.Dead==true,'destroyed rig is not pooled')
-- Player leaving.
local leaver=others[1];local leaverRec=fx.Records[leaver.P]
check(leaverRec~=nil,'near runner tracked before leaving')
for i,p in ipairs(list)do if p==leaver.P then table.remove(list,i);break end end
Players.PlayerRemoving:Fire(leaver.P)
check(fx.Records[leaver.P]==nil and children(leaver.Root)==0,'leaving player loses the aura at once')
frames(6)
-- FastMode (ClientFxBudget -> 1): own motes only, nobody else.
setSpeed(myRoot,40);frames(6)
me:SetAttribute('FastMode',true);frames(8)
s=fx:Stats()
check(s.Records==1 and fx.Records[me].Detail==1,'FastMode: only the local runner keeps an aura')
check(s.Emitting==1 and s.Ribbons==0 and s.Lights==0,'FastMode: a single mote emitter, no extra ribbons or light ('..s.Emitting..'/'..s.Ribbons..'/'..s.Lights..')')
check(layer(fx.Records[me],'Glitter').Emitters[1].Rate<Fx.Specs.RoyalTrail.Layers[1].Rate,'FastMode: lower particle rate')
me:SetAttribute('FastMode',nil);frames(8)
check(fx.Records[me].Detail==3,'back to full detail')
-- Reduced Motion: no bursts, no swirl/sheen, and the main ribbon goes back to its base colours.
Gui.ReducedMotionEnabled=true;setSpeed(myRoot,0);frames(20)
mine=fx.Records[me];local burstE=layer(mine,'Burst').Emitters[1];local was=emitted[burstE]or 0
check(mine.Detail==2,'reduced motion lowers detail')
setSpeed(myRoot,40);local q0=layer(mine,'GoldHelix').A0.Position;frames(8)
check((emitted[burstE]or 0)==was,'reduced motion: no start burst')
check(layer(mine,'GoldHelix').A0.Position==q0,'reduced motion: helix holds still')
local now=myChar.ChestChaseCosmetics.RunnerRibbon1.Color;local base1=Art.Sequence('RoyalTrail',1,0)
local same=true;for k=1,#base1.A do local a,b=now.A[k].V,base1.A[k].V;if a.R~=b.R or a.G~=b.G or a.B~=b.B then same=false end end
check(same,'reduced motion: main ribbon back to the base gradient')
Gui.ReducedMotionEnabled=false;frames(8)
-- Off-screen: a runner walks behind the camera and is parked (emitters off).
local o2=others[2];local rec2=fx.Records[o2.P]
check(rec2 and rec2.Rig,'second runner has an aura');setSpeed(o2.Root,30);frames(6)
local on=0;for _,L in ipairs(rec2.Rig.Layers)do for _,e in ipairs(L.Emitters)do if e.Enabled then on+=1 end end end
check(on>0,'on-screen runner emits')
o2.Root.CFrame=CF(2,5,25);frames(8)
on=0;for _,L in ipairs(rec2.Rig.Layers)do for _,e in ipairs(L.Emitters)do if e.Enabled then on+=1 end end;if L.Trail and L.Trail.Enabled then on+=1 end end
check(fx.Records[o2.P].Detail==0 and on==0,'off-screen runner parked')
o2.Root.CFrame=CF(0,5,-400);frames(6)
check(fx.Records[o2.P]==nil and children(o2.Root)==0,'runner out of range released')
-- Leaks: every aura instance is either on a live rig or pooled; Destroy frees all of them.
local live={};for _,rec in pairs(fx.Records)do if rec.Rig then for _,a in ipairs(rec.Rig.All)do live[a]=true end end end
for _,l in pairs(fx.Free)do for _,rig in ipairs(l)do for _,a in ipairs(rig.All)do live[a]=true end end end
local stray=0
for _,o in ipairs(R.created)do
 if o._props.Name:sub(1,10)=='TrailAura_'and o._class=='Attachment'and not rawget(o,'_locked')and not live[o]and o._parent then stray+=1 end
end
check(stray==0,'no stray aura attachments ('..stray..')')
local pooled=0;for _,l in pairs(fx.Free)do pooled+=#l;check(#l<=fx.PoolMax,'pool capped')end
clientScript:Destroy()
local alive=0
local kinds={}
for _,o in ipairs(R.created)do if o._props.Name:sub(1,10)=='TrailAura_'and not rawget(o,'_locked')then alive+=1;local k=o._class..' '..tostring(o._parent and o._parent:GetFullName());kinds[k]=(kinds[k]or 0)+1 end end
if alive>0 then for k,n in pairs(kinds)do print('  left:',k,n)end end
check(alive==0,'script removal destroys every aura instance ('..alive..' left)')
check(next(fx.Records)==nil and fx.Pool==0,'manager empty after removal')
local hb=0;for _,c in ipairs(Run.Heartbeat._c)do if c.Connected then hb+=1 end end;for _,c in ipairs(Run.RenderStepped._c)do if c.Connected then hb+=1 end end;check(hb==0,'per-frame connection disconnected (R153: RenderStepped)')
local pr=0;for _,c in ipairs(Players.PlayerRemoving._c)do if c.Connected then pr+=1 end end;check(pr==0,'PlayerRemoving disconnected')
-- 4. Shop preview ------------------------------------------------------------------------------------------------------
local Shop=req(RS.ShopProductArt);local lastCount=0
for _,id in ipairs(ORDER)do
 local specs=Shop.Specs({Id=id,Type='Trail',Color={R=200,G=200,B=200}});local names={}
 for _,sp in ipairs(specs)do names[sp.Name]=true end
 print(id..' preview: '..#specs..' parts');check(#specs>lastCount,id..' preview has more detail ('..#specs..' parts)');lastCount=#specs
 check(names['Ribbon core'],id..' preview shows the core ribbon')
 local model=Shop.Build({Id=id,Name=id,Type='Trail'});check(#model:GetChildren()==#specs,id..' preview builds')
end
local royal={};for _,sp in ipairs(Shop.Specs({Id='RoyalTrail',Type='Trail'}))do royal[sp.Name]=true end
check(royal['Crown point']and royal['Royal gold helix']and royal['Royal purple helix']and royal['Royal trim']and royal['Royal jewel'],'Royal preview: crown, double helix, trim, jewels')
local neb={};for _,sp in ipairs(Shop.Specs({Id='NebulaTrail',Type='Trail'}))do neb[sp.Name]=true end
check(neb['Nebula swirl']and neb['Nebula star'],'Nebula preview: swirl and stars')
local legacy=Shop.Specs({Id='OldTrail',Type='Trail'});check(#legacy>=48,'unknown trail id still previews')
local boots=Shop.Specs({Id='Boot',Type='Accessory',Biome='Lava',Color={R=255,G=120,B=40}},'Lava');check(#boots>0,'boots preview still works')
print(string.format('%d checks, %d failed',checks,fails))
if fails>0 then error('trail aura test failed')end
