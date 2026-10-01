--!nocheck
-- R118 head pieces: Royal crown, Nebula space dust, Aurora halo (RunnerTrailArt.HeadPiece + RunnerTrailAuraFx).
-- Run with: sh run.sh <repo root>   (bundles the modules with tools/tests/bundle.py, then /opt/luau/luau)
local R=require('./roblox');local B=require('./aura_bundle')
local new,V3,CF=R.new,R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end end
local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-3)end
-- Roblox behaviour the mock lacks: emitter methods, and a destroyed instance's Parent is locked.
local emitted={}
R.Inst.Emit=function(self,n)emitted[self]=(emitted[self]or 0)+n end
R.Inst.Clear=function(self)end
local rawDestroy=R.Inst.Destroy
R.Inst.Destroy=function(self)rawDestroy(self);rawset(self,'_locked',true)end
local rawSet=R.instMeta.__newindex
R.instMeta.__newindex=function(o,k,v)if k=='Parent'and rawget(o,'_locked')then error('The Parent property of '..tostring(o)..' is locked')end;rawSet(o,k,v)end
-- World ----------------------------------------------------------------------------------------------------------------
local game=new('DataModel');local services={}
local function service(name)local s=services[name];if not s then s=new(name);s.Name=name;s.Parent=game;services[name]=s end;return s end
function game.GetService(_,n)return service(n)end
local workspace=service('Workspace')
local camera=new('Camera');camera.CFrame=CF(0,10,0);camera.Parent=workspace;workspace.CurrentCamera=camera
function camera.WorldToViewportPoint(_,p)return p,p.Z<0 end -- looks down -Z
local Run=service('RunService');Run.Heartbeat=R.signal();Run.RenderStepped=R.signal();Run.IsClient=function()return false end
local UIS=service('UserInputService');UIS.TouchEnabled=false;UIS.KeyboardEnabled=true
local Players=service('Players');Players.PlayerRemoving=R.signal()
local RS=service('ReplicatedStorage')
local modules={};local env
local function load(name,scriptInst)local fn=assert(loadstring(B[name],'='..name));setfenv(fn,setmetatable({script=scriptInst},{__index=env}));return fn()end
local function req(m)if modules[m]~=nil then return modules[m]end;if m._source then modules[m]=load(m._source,m);return modules[m]end;error('unknown module '..tostring(m))end
for _,n in ipairs({'RunnerTrailArt','RunnerTrailAuraFx','ClientFxBudget','RunnerBootArt','ShopProductArt'})do local m=new('ModuleScript');m.Name=n;m.Parent=RS;m._source=n end
env=setmetatable({game=game,workspace=workspace,Instance=R.Instance,Vector3=R.Vector3,Vector2=R.Vector2,CFrame=R.CFrame,Color3=R.Color3,Enum=R.Enum,
 ColorSequence=R.ColorSequence,ColorSequenceKeypoint=R.ColorSequenceKeypoint,NumberSequence=R.NumberSequence,NumberSequenceKeypoint=R.NumberSequenceKeypoint,
 NumberRange=R.NumberRange,typeof=R.typeof,task=R.task,require=req,os={clock=function()return R.clock end,time=os.time}},{__index=_G})
local Art=req(RS.RunnerTrailArt);local Fx=req(RS.RunnerTrailAuraFx);local Shop=req(RS.ShopProductArt)
local ORDER={'MintTrail','ArcTrail','SolarTrail','AuroraTrail','NebulaTrail','RoyalTrail'}
local KIND={AuroraTrail='Halo',NebulaTrail='Dust',RoyalTrail='Crown'}
-- Helpers ----------------------------------------------------------------------------------------------------------------
local list={};local nextId=1
local function addPlayer(name)local p=new('Player');p.Name=name;p.UserId=nextId;nextId+=1;p.Parent=Players;table.insert(list,p);return p end
local function setFolder(character,id)
 local old=character:FindFirstChild('ChestChaseCosmetics');if old then old:Destroy()end
 local f=new('Folder');f.Name='ChestChaseCosmetics'
 if id then f:SetAttribute('TrailId84',id);f:SetAttribute('TrailLow84',-2.9);f:SetAttribute('TrailHigh84',2.4)end
 f.Parent=character;return f
end
-- rig: 'R15' (1.2 cube MeshPart-style head) or 'R6' (2x1x1 head drawn through a 1.25 head mesh).
local function spawn(p,pos,id,rig)
 local character=new('Model');character.Name=p.Name;character.Parent=workspace
 local h=new('Humanoid');h.Health=100;h.Sit=false;h.PlatformStand=false;h.FloorMaterial=R.Enum.Material.Plastic;h.Parent=character
 local root=new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.CFrame=CF(pos.X,pos.Y,pos.Z);root.AssemblyLinearVelocity=V3(0,0,0);root.Parent=character
 local head=new('Part');head.Name='Head';head.LocalTransparencyModifier=0
 if rig=='R6'then head.Size=V3(2,1,1);local m=new('SpecialMesh');m.MeshType=R.Enum.MeshType.Head;m.Scale=V3(1.25,1.25,1.25);m.Parent=head;head.CFrame=CF(pos.X,pos.Y+1.5,pos.Z)
 else head.Size=V3(1.2,1.2,1.2);head.CFrame=CF(pos.X,pos.Y+2.6,pos.Z)end
 head.Parent=character
 p.Character=character;setFolder(character,id);return character,root,head,h
end
local function weldOf(part)for _,c in ipairs(part:GetChildren())do if c._class=='Weld'then return c end end end
-- World CFrame through the weld chain (Weld: Part1 = Part0 * C0 * C1^-1, C1 unused = identity).
local function world(part,depth)
 local w=weldOf(part);if not w or(depth or 0)>4 then return part.CFrame end
 return world(w.Part0,(depth or 0)+1)*w.C0
end
local function headSpace(head,part)return head.CFrame:Inverse()*world(part).Position end
local function visible(pc)local out={};for _,p in ipairs(pc.Parts)do out[#out+1]=p end;return out end
local function named(pc,name)local out={};for _,p in ipairs(pc.Parts)do if p.Name==name then out[#out+1]=p end end;return out end
local function layer(rec,name)for _,L in ipairs(rec.Rig.Layers)do if L.Spec.Name==name then return L end end end
local function pieceModel(head)return head:FindFirstChild('TrailAura_HeadPiece')end
local fx=Fx.new();local me=addPlayer('Me')
local HIGH,MED,LOW,REDUCED=Fx.Budget(3,false),Fx.Budget(2,false),Fx.Budget(1,false),Fx.Budget(3,true)
local budget=HIGH
local function frames(n,dt)dt=dt or 1/30;for i=1,n do R.advance(dt);if i%4==1 then fx:Scan(list,me,camera,budget)end;fx:Step(dt,R.clock)end end
-- 1. Which trails get a head piece -----------------------------------------------------------------------------------------
for _,id in ipairs(ORDER)do
 local spec=Art.HeadPiece(id,1.2,1.2,false)
 check((spec~=nil)==(KIND[id]~=nil),id..(KIND[id]and' has a head piece'or' has no head piece'))
 check(Fx.HasHeadPiece(id)==(KIND[id]~=nil),id..' HasHeadPiece')
 if spec then
  check(spec.Kind==KIND[id],id..' head piece kind '..tostring(spec.Kind))
  local simple=Art.HeadPiece(id,1.2,1.2,true);check(#simple.Parts<#spec.Parts,id..' low-quality piece is simpler ('..#simple.Parts..' < '..#spec.Parts..')')
  print(id..' head piece: '..#spec.Parts..' parts ('..#simple.Parts..' simple)')
 end
end
for name,src in pairs(B)do if name~='ShopProductArt'and name~='RunnerBootArt'then check(not src:find('rbxassetid'),name..' has no uploaded asset ids')end end
check(Art.HeadSize(new('Part'))~=nil,'HeadSize copes with a bare part')
-- 2. Geometry on R6 and R15 heads, attachment ------------------------------------------------------------------------------
for _,rig in ipairs({'R15','R6'})do
 for _,id in ipairs({'RoyalTrail','NebulaTrail','AuroraTrail'})do
  list={me};local char,root,head=spawn(me,V3(0,5,-10),id,rig);frames(2)
  local rec=fx.Records[me];local pc=rec and rec.Piece
  check(pc~=nil and pc.Spec.Kind==KIND[id],rig..' '..id..': local runner wears the head piece')
  if pc then
   local w,h=Art.HeadSize(head);local top=h/2;local tag=rig..' '..id..': '
   check(near(w,rig=='R6'and 1.25 or 1.2)and near(h,rig=='R6'and 1.25 or 1.2),tag..'visible head size '..w..'x'..h)
   check(pieceModel(head)==pc.Model and pc.Model.Parent==head,tag..'model lives under the Head')
   local okProps,okWeld=true,true
   for _,p in ipairs(pc.Model:GetDescendants())do
    if p._class=='Part'then
     if p.Anchored or p.CanCollide or p.CanQuery or p.CanTouch or p.CastShadow or not p.Massless then okProps=false end
     local wd=weldOf(p);if not wd or wd.Part1~=p then okWeld=false
     elseif p.Name=='TrailAura_Pivot'then if wd.Part0~=head then okWeld=false end
     elseif not(wd.Part0 and wd.Part0.Name=='TrailAura_Pivot'and weldOf(wd.Part0).Part0==head)then okWeld=false end
    end
   end
   check(okProps,tag..'parts unanchored, massless, no collide/query/touch/shadow')
   check(okWeld,tag..'every part welded (via a pivot) to the Head')
   -- Initial CFrames already match the weld solution (no one-frame snap).
   local fresh=fx:_buildPiece(id,head,false);local snap=0;for _,p in ipairs(visible(fresh))do snap=math.max(snap,(world(p).Position-p.CFrame.Position).Magnitude)end
   fresh.Model:Destroy()
   check(snap<1e-3,tag..'parts start where the welds put them')
   if id=='RoyalTrail'then
    local lo,hi,rMin,rMax,cx,cz,n=math.huge,-math.huge,math.huge,0,0,0,0
    for _,p in ipairs(named(pc,'Crown band'))do
     local q=headSpace(head,p);lo=math.min(lo,q.Y-p.Size.Y/2);hi=math.max(hi,q.Y+p.Size.Y/2)
     local r=math.sqrt(q.X^2+q.Z^2);rMin=math.min(rMin,r);rMax=math.max(rMax,r);cx+=q.X;cz+=q.Z;n+=1
    end
    check(n==10,tag..'ten band segments')
    check(lo<top and hi>top and lo>top-.3*w,tag..'band sits on the top of the head (from '..string.format('%.2f',lo)..' to '..string.format('%.2f',hi)..', top '..top..')')
    check(rMin>.45*w and rMax<.62*w,tag..'band wraps the head like a hat (r '..string.format('%.2f..%.2f',rMin,rMax)..')')
    check(near(cx/n,0,.01)and near(cz/n,0,.01),tag..'crown centred on the head')
    local pts=named(pc,'Crown point');local above=true;for _,p in ipairs(pts)do if headSpace(head,p).Y<=top then above=false end end
    check(#pts==5 and above,tag..'five points rise above the head')
    local gems=named(pc,'Crown gem');local jewels=named(pc,'Crown jewel')
    check(#gems==5 and #jewels==5,tag..'jewels on tips and band')
    local purple,red=false,false
    for _,p in ipairs(jewels)do if p.Color.B>p.Color.R then purple=true elseif p.Color.R>.8 and p.Color.B<.5 then red=true end end
    check(purple and red,tag..'purple and red jewels')
    local front=headSpace(head,jewels[1]);check(front.Z< -.5*w,tag..'front jewel faces forward (-Z)')
    local neon=0;for _,p in ipairs(pc.Parts)do if p.Material==R.Enum.Material.Neon then neon+=1 end end;check(neon>=20,tag..'neon glow accents ('..neon..')')
    -- The crown glints moved from the floating ring above the body onto the crown tips.
    local glint=layer(rec,'Crown');local onHead=true;local tipTop=-math.huge
    for _,e in ipairs(glint.Emitters)do local a=e.Parent;if a.Parent~=head then onHead=false end;tipTop=math.max(tipTop,a.Position.Y)end
    check(onHead and tipTop>top and tipTop<top+.6*w,tag..'crown glints sit on the crown tips, on the Head')
    check(layer(rec,'Idle').Emitters[1].Parent.Parent==head,tag..'idle crown sparkle on the Head')
   elseif id=='AuroraTrail'then
    local ok,lo,hi=true,math.huge,-math.huge
    for _,p in ipairs(named(pc,'Aurora halo'))do local q=headSpace(head,p);lo=math.min(lo,q.Y);hi=math.max(hi,q.Y);local r=math.sqrt(q.X^2+q.Z^2);if r<.3*w or r>.6*w then ok=false end end
    check(#named(pc,'Aurora halo')==12 and ok,tag..'12-segment halo ring around the head axis')
    check(lo>top and hi<top+.45*w,tag..'halo floats just above the head ('..string.format('%.2f',lo-top)..' above)')
    check(layer(rec,'HaloMotes').Emitters[1].Parent.Parent==head,tag..'halo motes on the Head')
   else
    local ok=true;local specks=named(pc,'Space dust');local stars=named(pc,'Dust star')
    for _,p in ipairs(pc.Parts)do local q=headSpace(head,p);local r=math.sqrt(q.X^2+q.Z^2);if r<.55*w or r>.95*w or q.Y<-.35*h or q.Y>top+.4*w then ok=false end end
    check(#specks>=10 and #stars>=4 and ok,tag..'dust specks and stars orbit closely around the head')
    local purple=0;for _,p in ipairs(specks)do if p.Color.B>p.Color.G then purple+=1 end end;check(purple>=#specks/2,tag..'dust is purple/blue')
    check(layer(rec,'HeadDust').Emitters[1].Parent.Parent==head and layer(rec,'HeadStars').Emitters[1].Parent.Parent==head,tag..'dust emitters on the Head')
   end
   -- Follows the head: run, jump, turn. Head-space offsets never change.
   local refs={};for i,p in ipairs(pc.Parts)do refs[i]=headSpace(head,p)end
   local moved=pc.Model and true
   for _,frame in ipairs({CF(30,9,-60),CF(-12,20,-14)*R.CFrame.Angles(0,1.3,0),CF(4,6.5,-11)*R.CFrame.Angles(.4,-.7,.1)})do
    head.CFrame=frame
    for i,p in ipairs(pc.Parts)do
     if pc.Spec.Kind~='Dust'then local d=(world(p).Position-frame*refs[i]).Magnitude;if d>1e-3 then moved=false end
     else local q=head.CFrame:Inverse()*world(p).Position;if math.abs(math.sqrt(q.X^2+q.Z^2)-math.sqrt(refs[i].X^2+refs[i].Z^2))>1e-3 then moved=false end end
    end
   end
   check(moved,tag..'piece follows the head through running, jumping and turning')
  end
  list={};frames(2)
  check(fx.Records[me]==nil and pieceModel(head)==nil,rig..' '..id..': released when the runner goes away')
  char:Destroy()
 end
end
-- 3. Lifecycle: trail change, unequip, sitting, treadmill, respawn, leaving --------------------------------------------------
list={me};local myChar,myRoot,myHead,myHum=spawn(me,V3(0,5,-10),'RoyalTrail','R15');frames(3)
local crown=fx.Records[me].Piece;check(crown and crown.Spec.Kind=='Crown','Royal: crown on')
for _,id in ipairs(ORDER)do
 setFolder(myChar,id);frames(4)
 local rec=fx.Records[me];local m=pieceModel(myHead)
 check((rec.Piece~=nil)==(KIND[id]~=nil)and(m~=nil)==(KIND[id]~=nil),id..': head piece '..(KIND[id]and'shown'or'absent')..' after a trail change')
 if KIND[id]then check(rec.Piece.Spec.Kind==KIND[id],id..': right head piece after change')end
 local count=0;for _,c in ipairs(myHead:GetChildren())do if c.Name=='TrailAura_HeadPiece'then count+=1 end end
 check(count<=1,id..': never two head pieces')
end
check(rawget(crown.Model,'_locked')==true,'old crown destroyed on trail change')
setFolder(myChar,'RoyalTrail');frames(4)
local pc=fx.Records[me].Piece
myHead.Size=V3(1.5,1.5,1.5);frames(4);local grown=fx.Records[me].Piece
check(grown~=pc and grown.Model.Parent==myHead and rawget(pc.Model,'_locked')==true,'rescaled head: crown rebuilt to the new size')
local band=named(grown,'Crown band')[1];check(near(math.sqrt(headSpace(myHead,band).X^2+headSpace(myHead,band).Z^2),.53*1.5,.02),'rescaled head: band radius follows head width')
pc=grown;myHum.Sit=true;frames(10);check(fx.Records[me].Piece==pc and pc.Model.Parent==myHead,'crown stays on while sitting')
myHum.Sit=false;me:SetAttribute('TreadmillTraining',true);myRoot.AssemblyLinearVelocity=V3(0,0,-40);frames(10)
check(fx.Records[me].Piece==pc and pc.Model.Parent==myHead,'crown stays on during treadmill training')
me:SetAttribute('TreadmillTraining',nil)
setFolder(myChar,nil);frames(4)
check(fx.Records[me]==nil and pieceModel(myHead)==nil and rawget(pc.Model,'_locked')==true,'unequip removes the crown')
setFolder(myChar,'NebulaTrail');frames(4);pc=fx.Records[me].Piece
myChar:Destroy();local c2,r2,h2=spawn(me,V3(0,5,-10),'NebulaTrail','R6');myChar,myRoot,myHead=c2,r2,h2;frames(4)
local rec=fx.Records[me]
check(rec.Piece and rec.Piece~=pc and rec.Piece.Model.Parent==h2 and rec.Head==h2,'respawn: new dust cloud on the new head')
check(rawget(pc.Model,'_locked')==true,'respawn: old piece gone with the old character')
local other=addPlayer('Other');local oc,orr,oh=spawn(other,V3(2,5,-30),'AuroraTrail','R15');frames(4)
local opc=fx.Records[other]and fx.Records[other].Piece
check(opc and opc.Model.Parent==oh,'near on-screen runner shows a halo')
for i,p in ipairs(list)do if p==other then table.remove(list,i);break end end
fx:Release(other)
check(fx.Records[other]==nil and pieceModel(oh)==nil and rawget(opc.Model,'_locked')==true,'leaving player loses the head piece at once')
oc:Destroy()
-- 4. Budgets -------------------------------------------------------------------------------------------------------------
local crowd={}
for i=1,7 do local p=addPlayer('Crowd'..i);local _,r,hd=spawn(p,V3(i,5,-12-i*5),ORDER[4+(i-1)%3],'R15');crowd[i]={P=p,Root=r,Head=hd}end
local function pieces()local n=0;for p,r in pairs(fx.Records)do if p~=me and r.Piece and not r.Piece.Stashed then n+=1 end end;return n end
budget=HIGH;frames(8);check(pieces()<=HIGH.Heads and pieces()>0,'high quality: others capped at '..HIGH.Heads..' ('..pieces()..')')
for p,r in pairs(fx.Records)do if p~=me and r.Piece and not r.Piece.Stashed then check(r.Detail>=2,'only near/on-screen runners get head pieces')end end
budget=MED;frames(8);check(pieces()<=MED.Heads,'medium quality: others capped at '..MED.Heads..' ('..pieces()..')')
frames(60);local stashed=0;for p,r in pairs(fx.Records)do if p~=me and r.Piece then stashed+=1 end end
check(stashed<=MED.Heads,'unwanted pieces are destroyed after a moment')
-- Off-screen runner: piece hidden at once.
budget=HIGH;frames(8);local c1=crowd[1];local p1=fx.Records[c1.P].Piece;check(p1 and not p1.Stashed,'nearest crowd runner has a piece')
c1.Root.CFrame=CF(1,5,25);c1.Head.CFrame=CF(1,7.6,25);frames(8)
check(p1.Model.Parent==nil,'off-screen runner: head piece hidden')
frames(60);check(fx.Records[c1.P]==nil or fx.Records[c1.P].Piece==nil,'off-screen runner: head piece freed')
-- Low quality / FastMode: own simplified piece, no head particles, nobody else.
budget=LOW;frames(8)
rec=fx.Records[me];check(pieces()==0,'low quality: no head pieces on others')
check(rec.Piece and rec.Piece.Simple==true and #rec.Piece.Parts<#Art.HeadPiece('NebulaTrail',1.25,1.25,false).Parts,'low quality: own piece, simplified')
local on=0;for _,L in ipairs(rec.Rig.Layers)do if L.Spec.Head then for _,e in ipairs(L.Emitters)do if e.Enabled then on+=1 end end end end
check(on==0,'low quality: no head particles')
budget=HIGH;frames(8);rec=fx.Records[me]
check(rec.Piece and rec.Piece.Simple==false,'back to the full piece')
-- Motion: rings orbit, dust emitters circle and run; Reduced Motion holds everything still.
local pv=rec.Piece.Pivots[2];local c0=pv.Weld.C0;local dustAtt=layer(rec,'HeadDust').Emitters[1].Parent;local a0=dustAtt.Position
frames(6)
check(pv.Weld.C0.R[1][1]~=c0.R[1][1],'dust ring orbits the head')
check(dustAtt.Position~=a0,'dust emitter circles the head')
check(layer(rec,'HeadDust').Emitters[1].Enabled and layer(rec,'HeadStars').Emitters[1].Enabled,'dust and star particles run (standing)')
myRoot.AssemblyLinearVelocity=V3(0,0,-30);frames(6);check(layer(rec,'HeadDust').Emitters[1].Enabled,'dust particles run while running')
myRoot.AssemblyLinearVelocity=V3(0,0,0)
budget=REDUCED;frames(8);rec=fx.Records[me]
local still=true;for _,q in ipairs(rec.Piece.Pivots)do if q.Weld.C0~=q.Base then still=false end end
local p0={};for i,q in ipairs(rec.Piece.Pivots)do p0[i]=q.Weld.C0 end;local a1=dustAtt.Position;frames(10)
for i,q in ipairs(rec.Piece.Pivots)do if q.Weld.C0~=p0[i]then still=false end end
check(still and dustAtt.Position==a1,'reduced motion: no orbiting')
local base=true;for _,sh in ipairs(rec.Piece.Shimmer)do if sh.Part.Transparency~=sh.Alpha or sh.Part.Color~=sh.Color then base=false end end
check(base,'reduced motion: no twinkle/shimmer')
check(rec.Piece.Model.Parent==myHead and not layer(rec,'HeadDust').Emitters[1].Enabled,'reduced motion: static piece stays, dust particles off')
budget=HIGH;frames(8)
-- Royal shimmer and Aurora colour flow.
setFolder(myChar,'RoyalTrail');frames(4);rec=fx.Records[me]
local rim=named(rec.Piece,'Crown rim');local cols={};for i,p in ipairs(rim)do cols[i]=p.Color end;frames(12)
local changed=false;for i,p in ipairs(rim)do if p.Color~=cols[i]then changed=true end end;check(changed,'crown sheen sweeps the rim')
local glints=0;for _,e in ipairs(layer(rec,'Crown').Emitters)do glints+=emitted[e]or 0 end;frames(60)
local glints2=0;for _,e in ipairs(layer(rec,'Crown').Emitters)do glints2+=emitted[e]or 0 end;check(glints2>glints,'crown sparkles')
setFolder(myChar,'AuroraTrail');frames(4);rec=fx.Records[me]
local halo=named(rec.Piece,'Aurora halo');local hc=halo[1].Color;local y0=rec.Piece.Pivots[1].Weld.C0.Position.Y;frames(12)
check(halo[1].Color~=hc,'halo colours flow');check(rec.Piece.Pivots[1].Weld.C0.Position.Y~=y0,'halo bobs gently')
-- 5. First person -------------------------------------------------------------------------------------------------------
setFolder(myChar,'RoyalTrail');frames(4);rec=fx.Records[me]
myHead.LocalTransparencyModifier=1;local before=0;for _,e in ipairs(layer(rec,'Crown').Emitters)do before+=emitted[e]or 0 end;frames(40)
local hidden=true;for _,p in ipairs(rec.Piece.Parts)do if p.LocalTransparencyModifier~=1 then hidden=false end end
check(hidden,'first person: crown hidden with the head')
local after=0;for _,e in ipairs(layer(rec,'Crown').Emitters)do after+=emitted[e]or 0 end;check(after==before,'first person: no crown glints')
check(not layer(rec,'Idle').Emitters[1].Enabled,'first person: no idle crown sparkle')
myHead.LocalTransparencyModifier=.4;frames(2)
local half=true;for _,p in ipairs(rec.Piece.Parts)do if p.LocalTransparencyModifier~=.4 then half=false end end;check(half,'zooming out: piece fades with the head')
myHead.LocalTransparencyModifier=0;frames(30)
local shown=true;for _,p in ipairs(rec.Piece.Parts)do if p.LocalTransparencyModifier~=0 then shown=false end end;check(shown,'third person: crown visible again')
check(layer(rec,'Idle').Emitters[1].Enabled,'third person: idle crown sparkle back')
-- 6. Cleanup -------------------------------------------------------------------------------------------------------------
fx:Destroy()
local alive=0;for _,o in ipairs(R.created)do if o._props.Name:sub(1,10)=='TrailAura_'and not rawget(o,'_locked')and o._parent then alive+=1 end end
check(alive==0,'Destroy frees every head piece and aura instance ('..alive..' left)')
-- 7. Shop preview ---------------------------------------------------------------------------------------------------------
for _,id in ipairs(ORDER)do
 local names={};local crownY={};for _,sp in ipairs(Shop.Specs({Id=id,Type='Trail'}))do names[sp.Name]=true;if sp.Name=='Crown band'then table.insert(crownY,sp.Frame.Position.Y)end end
 local has=names['Crown band']or names['Aurora halo']or names['Space dust']
 check((has~=nil)==(KIND[id]~=nil),id..' preview '..(KIND[id]and'shows'or'has no')..' a head piece')
 if id=='RoyalTrail'then
  check(names['Crown point']and names['Crown gem']and names['Crown jewel'],'Royal preview: crown with points and jewels')
  local ok=#crownY==10;for _,y in ipairs(crownY)do if math.abs(y-(3.65+.425))>.12 then ok=false end end
  check(ok,'Royal preview: crown sits on the preview head')
 elseif id=='NebulaTrail'then check(names['Space dust']and names['Dust star'],'Nebula preview: space dust around the head')
 elseif id=='AuroraTrail'then check(names['Aurora halo'],'Aurora preview: halo')end
end
print(string.format('%d checks, %d failed',checks,fails))
if fails>0 then error('head piece test failed')end
