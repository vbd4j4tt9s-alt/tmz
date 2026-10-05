--!nocheck
-- R151 studded hub trees (owner: "tress can also use this" + "there are different variations of trees that we can use make sure they are
-- studded" + "make sure they are collision is off as we dont want players jumping around bugging with it in highspeeds"), on the Roblox mock
-- with the REAL ChestChaseServer.HubTreeLoader151, ReplicatedStorage.HubStudTrees151 / HubLifeArt151 and HubLife151.client of this
-- checkout, and FAKE studded tree models (the owner's Creator Store trees cannot be downloaded here):
--  * the load routes: AssetService:LoadAssetAsync works / is refused / errors / is missing, InsertService:LoadAsset works / is refused, the
--    owner's hand-placed models, nothing at all;
--  * safety: every script and non-geometry instance removed and counted, every BasePart of every tree (loaded, hand-placed, part-built,
--    bushes, topiary) Anchored with CanCollide / CanTouch / CanQuery off and the Default collision group, also for parts added later;
--  * templates of several part counts, broken ones, the per-tier budget rule, fitting (height, crown width, grounded, on the slot), leaf
--    colours, fruit, determinism, the attributes, the rebuild when the folder changes, the '/test hubtrees' text;
--  * the part-built trees, bushes and topiary are studded (Plastic, Studs on the face that points up, Inlet under it).
-- Prints "ok <name>" / "FAIL <name>: why"; errors at the end if anything failed.
local Z=require('./zfight_world');local W=Z.W;local R=Z.R;local V3,CF=R.Vector3.new,R.CFrame.new
local RS=W.RS
-- Clone copies attributes on Roblox (the shared mock does not): the templates mark their leaves with one.
do local raw=R.Inst.Clone;R.Inst.Clone=function(self)local c=raw(self);c._attrs=table.clone(self._attrs);return c end end
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal();function Players.GetPlayers()return{}end
local srv=R.new('Folder');srv.Name='ChestChaseServer';srv.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=srv end
local K=W.module('HubDecorKit151');local T=W.module('HubStudTrees151');local Art=W.module('HubLifeArt151')
local Loader=W.require(srv.HubTreeLoader151)
local passed,failed=0,0
local function check(name,cond,why)if cond then passed+=1;print('ok '..name)else failed+=1;print('FAIL '..name..(why~=nil and(': '..tostring(why))or''))end end
local function first(list)return list[1]and(list[1]..(#list>1 and(' (+'..(#list-1)..' more)')or''))or nil end
local function parts(root)local out={};if root:IsA('BasePart')then out[1]=root end;for _,d in ipairs(root:GetDescendants())do if d:IsA('BasePart')then out[#out+1]=d end end;return out end
local function codeIn(root)local n=0;for _,d in ipairs(root:GetDescendants())do if d._class=='Script'or d._class=='LocalScript'or d._class=='ModuleScript'then n+=1 end end;return n end
-- the four properties (plus the collision group) on every BasePart under root
local function unsafe(root)
 local bad={}
 for _,p in ipairs(parts(root))do
  if p._props.Anchored~=true or p._props.CanCollide~=false or p._props.CanTouch~=false or p._props.CanQuery~=false or(p._props.CollisionGroup~=nil and p._props.CollisionGroup~='Default')then
   bad[#bad+1]=Z.path(p)..string.format(' (Anchored %s, CanCollide %s, CanTouch %s, CanQuery %s)',tostring(p._props.Anchored),tostring(p._props.CanCollide),tostring(p._props.CanTouch),tostring(p._props.CanQuery))
  end
 end
 return bad
end

-- Fake studded trees ------------------------------------------------------------------------------------------------------------------------
-- n parts: a trunk, leaf blocks (green, studded, CanCollide on as a free model would have it), far from the hub. o.scripts adds a Script, a
-- LocalScript in a leaf and a ModuleScript in a folder; o.junk adds a weld, a sound, a light, a click detector and a value; o.mesh makes one
-- leaf a MeshPart.
local function fakeTree(name,n,o)
 o=o or{}
 local m=R.new('Model');m.Name=name
 local t=R.new('Part');t.Name='Trunk';t.Size=V3(2,9,2);t.CFrame=CF(600,4.5,600);t.Color=R.Color3.fromRGB(120,82,50);t.Parent=m
 for i=1,n-1 do
  local p=R.new((o.mesh and i==1)and'MeshPart'or'Part');p.Name='Leaves';p.Size=V3(7-i%3,3+i%2,7-i%3)
  p.CFrame=CF(600+((i%3)-1)*2.5,10+i*.9,600+((i%2)*2-1))*R.CFrame.Angles(0,i*.4,0);p.Color=R.Color3.fromRGB(70,150+i%40,60)
  p.TopSurface=R.Enum.SurfaceType.Studs;if o.mesh and i==1 then p.TextureID='rbxassetid://1'end;p.Parent=m
 end
 if o.scripts then
  local s=R.new('Script');s.Name='Spreader';s.Parent=m
  local ls=R.new('LocalScript');ls.Name='Sway';ls.Parent=m:FindFirstChild('Leaves')or t
  local f=R.new('Folder');f.Name='Lib';f.Parent=m;local ms=R.new('ModuleScript');ms.Name='Util';ms.Parent=f
 end
 if o.junk then
  local w=R.new('Weld');w.Parent=t;local snd=R.new('Sound');snd.Parent=t;local l=R.new('PointLight');l.Parent=t
  local cd=R.new('ClickDetector');cd.Parent=t;local v=R.new('StringValue');v.Parent=m
 end
 return m
end
local function folder()local f=RS:FindFirstChild(K.TreeFolder);if f then f:Destroy()end;f=R.new('Folder');f.Name=K.TreeFolder;f.Parent=RS;return f end
local AS,IS=W.service('AssetService'),W.service('InsertService')
local function container(model)local c=R.new('Model');c.Name='Model';model.Parent=c;return c end
local function routes(asFn,isFn)AS.LoadAssetAsync=asFn;IS.LoadAsset=isFn end
local refused=function()error('Asset is not trusted for this place')end

-- 1. load routes ---------------------------------------------------------------------------------------------------------------------------
do
 local f=folder()
 routes(function(_,id)return container(fakeTree('Stud Tree '..id,12,{scripts=true,junk=true}))end,function()error('should not be asked')end)
 Loader.Run(true)
 local a,b=f:FindFirstChild('Asset16637971059'),f:FindFirstChild('Asset17280628013')
 check('load: AssetService:LoadAssetAsync first - both ids parked in ReplicatedStorage.HubTreeTemplates151',a~=nil and b~=nil)
 check('load: the route is published per id (Route<id> = AssetService) and Ready',f:GetAttribute('Route16637971059')=='AssetService'and f:GetAttribute('Route17280628013')=='AssetService'and f:GetAttribute('Ready')==true)
 check('load: the asset is unwrapped from LoadAsset\'s container and keeps its name as AssetName',a and a._class=='Model'and a:GetAttribute('AssetName')=='Stud Tree 16637971059'and a:GetAttribute('R151AssetId')==16637971059)
 check('safety: every script of the loaded models removed and counted (3 each)',codeIn(f)==0 and f:GetAttribute('ScriptsRemoved')==6,f:GetAttribute('ScriptsRemoved'))
 local junk=0;for _,d in ipairs(f:GetDescendants())do if not(d:IsA('BasePart')or d._class=='Model'or d._class=='Folder')then junk+=1 end end
 check('safety: welds, sounds, lights, click detectors and values removed from the loaded models',junk==0,junk)
 local bad=unsafe(f);check('safety: every part of the loaded models anchored, CanCollide / CanTouch / CanQuery off',#bad==0,first(bad))
 check('load: Loaded = 2, Manual = 0',f:GetAttribute('Loaded')==2 and f:GetAttribute('Manual')==0)
end
do
 local f=folder()
 routes(refused,function(_,id)return container(fakeTree('Owned tree',8))end)
 Loader.Run(true)
 check('load: AssetService refused -> InsertService:LoadAsset (the owner owns the model)',f:GetAttribute('Route16637971059')=='InsertService'and f:FindFirstChild('Asset16637971059')~=nil,f:GetAttribute('Route16637971059'))
end
do
 local f=folder()
 routes(nil,function()error('HTTP 403 (Forbidden)')end) -- (AssetService without LoadAssetAsync: an older engine)
 local hand=fakeTree('MyStudTree',10,{scripts=true});hand.Parent=f
 Loader.Run(true)
 check('load: both routes fail -> Route<id> = failed, the owner\'s hand-placed model stays',f:GetAttribute('Route16637971059')=='failed'and f:GetAttribute('Route17280628013')=='failed'and f:FindFirstChild('MyStudTree')~=nil)
 check('safety: the hand-placed model is cleaned too (Manual 1, its 3 scripts removed, every part locked)',f:GetAttribute('Manual')==1 and codeIn(f)==0 and f:GetAttribute('ScriptsRemoved')==3 and #unsafe(f)==0,f:GetAttribute('ScriptsRemoved'))
 local late=fakeTree('Late',4,{scripts=true});late.Parent=f
 check('safety: a model added to the folder later is cleaned at once (DescendantAdded)',codeIn(f)==0 and #unsafe(f)==0 and(f:GetAttribute('ScriptsRemoved')or 0)>=6)
 late:Destroy()
 local ok,text=Loader.Command({},nil,{})
 check('/test hubtrees: the routes, the models and each tier\'s plan',ok and text:find('16637971059: failed',1,true)~=nil and text:find('MyStudTree 10',1,true)~=nil and text:find('tier 3:',1,true)~=nil,text)
end
do
 local f=folder()
 routes(function()return container(R.new('Model'))end,refused)
 Loader.Run(true)
 check('load: an asset with no parts is refused (failed), nothing parked',f:GetAttribute('Route16637971059')=='failed'and #f:GetChildren()==0)
end

-- 2. templates: sanitize, measure, broken ones -------------------------------------------------------------------------------------------------
local f=folder()
local function put(m)m.Parent=f;return m end
put(fakeTree('A small',5,{scripts=true,junk=true}));put(fakeTree('B medium',14,{mesh=true}));put(fakeTree('C big',60))
put(R.new('Model')).Name='D empty'
local s=R.new('Script');s.Name='E script';s.Parent=f
do local m=fakeTree('F bad size',3);m:GetChildren()[2].Size=V3(0/0,1,1);put(m)end
local infos,sum=T.Collect(f)
local byName={};for _,i in ipairs(infos)do byName[i.Name]=i end
check('templates: sorted by name, 3 usable (5, 14, 60 parts), 3 broken reported (empty, a script, an impossible size)',sum.Templates==3 and #sum.Broken==3 and byName['A small'].Parts==5 and byName['B medium'].Parts==14 and byName['C big'].Parts==60,#sum.Broken..' broken: '..table.concat(sum.Broken,'; '))
check('templates: the private copy has no scripts (3 counted) and the source in ReplicatedStorage is never parented to the world',codeIn(byName['A small'].Model)==0 and byName['A small'].ScriptsRemoved==3 and byName['A small'].Model.Parent==nil)
check('templates: leaves found by name / colour (the trunk is not a leaf)',byName['B medium'].Leaves==13 and byName['B medium'].Recolourable==false,byName['B medium'].Leaves..' leaves, recolourable '..tostring(byName['B medium'].Recolourable)..' (a textured MeshPart leaf)')
check('templates: a model of plain parts can take the slot\'s leaf colour',byName['A small'].Recolourable==true)

-- 3. the budget rule -----------------------------------------------------------------------------------------------------------------------
local slots=Art.TreeSlots()
local plans={}
for tier=1,3 do local _,p=T.Plan(infos,tier,slots);plans[tier]=p end
check('budget: 30 leafy slots (oaks, blossoms, fruit trees); pines, palms, cacti, ember trees and rocks stay part-built',plans[3].Eligible==30,plans[3].Eligible)
check('budget: tier 1 (phones on low) - only a clone of at most 6 parts, at most 90 parts in all',plans[1].Parts<=90 and plans[1].Used==18 and plans[1].ByKind.oak~=nil,plans[1].Used..' trees, '..plans[1].Parts..' parts')
check('budget: tier 2 - clones up to 16 parts, at most 300 in all',plans[2].Parts<=300 and plans[2].Used>18,plans[2].Used..' trees, '..plans[2].Parts..' parts')
check('budget: tier 3 (desktop) - the 60-part model is too big for one tree (over 40), the rest fill all 30 slots within 600',plans[3].Used==30 and plans[3].Parts<=600 and table.find(plans[3].TooBig,'C big')~=nil,plans[3].Used..' trees, '..plans[3].Parts..' parts')
do local only={byName['C big']};local _,p3=T.Plan(only,3,slots);local _,p2=T.Plan(only,2,slots)
 local mid=fakeTree('G thirty',30);mid.Parent=nil;local gi=T.Prepare(mid);local _,q3=T.Plan({gi},3,slots);local _,q2=T.Plan({gi},2,slots)
 check('budget: a 30-part model is used on the desktop only, for the first 20 slots (600 / 30), none on phones',q3.Used==20 and q3.Parts==600 and q2.Used==0,q3.Used..' / '..q2.Used)
 check('budget: a model over every tier\'s limit is never used',p3.Used==0 and p2.Used==0)
end
do local plan=T.Plan({byName['B medium']},3,slots);local blossom=0
 for i,s in ipairs(slots)do if s.Kind=='blossom'and plan[i]then blossom+=1 end end
 check('budget: a model whose leaves cannot be recoloured (textured) never takes a blossom slot (it would be green)',blossom==0)
end
do local a=T.Plan(infos,3,slots);local b=T.Plan(infos,3,slots);local same,spread=true,{}
 for i in pairs(a)do if a[i]~=b[i]then same=false end;spread[a[i].Name]=true end
 local n=0;for _ in pairs(spread)do n+=1 end
 check('variety: the models are spread over the slots by a hash, the same on every client',same and n==2,n)
end

-- 4. the client builds the square with them ------------------------------------------------------------------------------------------------
Run.IsClient=function()return true end;Run.IsServer=function()return false end
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
local dec=R.new('Folder');dec.Name=K.FolderName;dec.Parent=map
local player=R.new('Player');player.Name='Tester';player.UserId=1001;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
W.service('ContentProvider').PreloadAsync=function()end
local budget={Tier=3};W.stub('ClientFxBudget',{Get=function()return budget.Tier end,Low=function()return budget.Tier==1 end})
W.workspace.CurrentCamera.CFrame=CF(0,12,-300)
local function client()
 local old=W.workspace:FindFirstChild('HubLife151');if old then old:Destroy()end
 local sc=R.new('LocalScript');sc.Name='HubLife151';sc:SetAttribute('R151TestHook',true);sc.Parent=pg
 local api=W.load('HubLife151Client',sc);assert(api,'no test hook');assert(api.Build(),'build failed')
 api.Near.detail=1e6;api.Near.fine=1e6;api.ApplyLod()
 return api,sc,W.workspace:FindFirstChild('HubLife151')
end
local function clones(life)local out={};for _,d in ipairs(life:GetDescendants())do if d._class=='Model'and d.Name=='Studded tree'then out[#out+1]=d end end;return out end
local FL=K.Floor
local api,sc,life=client()
local cl=clones(life)
check('client: the leafy slots get the owner\'s models (desktop: 30 clones)',#cl==30,#cl)
check('client: attributes TemplateParts / UsedFor / ScriptsRemoved on workspace.HubLife151',life:GetAttribute('TemplateParts'):find('A small 5',1,true)~=nil and life:GetAttribute('UsedFor'):find('30 of 30 leafy trees',1,true)~=nil and life:GetAttribute('ScriptsRemoved')==3,
 tostring(life:GetAttribute('TemplateParts'))..' | '..tostring(life:GetAttribute('UsedFor'))..' | '..tostring(life:GetAttribute('ScriptsRemoved')))
check('safety: no script anywhere in the square',codeIn(life)==0)
do local bad=unsafe(life);check('safety: EVERY part of the square (clones, fruit, part-built trees, bushes, topiary, props) anchored, CanCollide / CanTouch / CanQuery off',#bad==0,first(bad))end
-- fitting: height and crown width of the slot, standing on the floor, on the slot
do local bad={}
 local byPos={};for i,s in ipairs(slots)do byPos[s.X..','..s.Z]=s end
 for _,m in ipairs(cl)do
  local c,size=T.Box(m);local lo=c.Y-size.Y/2
  local best,bd=nil,1e9;for _,s in ipairs(slots)do local d=(V3(s.X,0,s.Z)-V3(c.X,0,c.Z)).Magnitude;if d<bd then best,bd=s,d end end
  local h,w=T.Fit[best.Kind][1]and T.Fit[best.Kind][1]or T.Fit[best.Kind][best.Variant][1],T.Fit[best.Kind][2]or T.Fit[best.Kind][best.Variant][2]
  if lo>FL-.15 or lo<FL-1.2 then bad[#bad+1]=string.format('%s,%s floats / sinks: bottom %.2f',best.X,best.Z,lo)end
  if size.Y<h*.8 or size.Y>h*1.25 then bad[#bad+1]=string.format('%s,%s height %.1f for %.1f',best.X,best.Z,size.Y,h)end
  if math.max(size.X,size.Z)>w*1.5 then bad[#bad+1]=string.format('%s,%s width %.1f for %.1f',best.X,best.Z,math.max(size.X,size.Z),w)end
  if bd>2.5 then bad[#bad+1]=string.format('%s,%s off its slot by %.1f',best.X,best.Z,bd)end
 end
 check('fit: every clone scaled to its slot (height within 80-125 %, crown no wider than 1.5 x the slot\'s, which a turn can add), grounded and on its slot',#bad==0,first(bad))
end
do local pink,fruit=0,0
 for _,m in ipairs(cl)do if m:GetAttribute('Template')=='A small'then for _,p in ipairs(parts(m))do if p:GetAttribute('R151Leaf')and p.Color.R>p.Color.G+.15 then pink+=1 end end end end
 for _,d in ipairs(life:GetDescendants())do if d.Name=='Fruit'then fruit+=1 end end
 check('look: blossom slots recolour the model\'s leaves (pink / white / lilac), fruit trees keep their fruit',pink>0 and fruit>=32,pink..' pink leaves, '..fruit..' fruit')
end
do local a={};for _,m in ipairs(cl)do local c=T.Box(m);a[#a+1]=string.format('%.3f,%.3f,%.3f',c.X,c.Y,c.Z)end
 local api2,sc2,life2=client();local b={};for _,m in ipairs(clones(life2))do local c=T.Box(m);b[#b+1]=string.format('%.3f,%.3f,%.3f',c.X,c.Y,c.Z)end
 check('variety: deterministic (a second client builds the same clones in the same places)',table.concat(a,'|')==table.concat(b,'|'))
 local yaws={};for _,m in ipairs(clones(life2))do local t=parts(m)[1];yaws[string.format('%.2f',t.CFrame.RightVector.X)]=true end
 local n=0;for _ in pairs(yaws)do n+=1 end
 check('variety: every clone has its own turn',n>=25,n)
 sc:Destroy();api,sc,life=api2,sc2,life2;cl=clones(life)
end
-- anything added to the square later is locked too
do local tree=cl[1]
 local p=R.new('Part');p.Name='Late branch';p.Size=V3(1,1,4);p.CanCollide=true;p.Anchored=false;p.Parent=tree
 local m=fakeTree('Late model',3,{scripts=true});m.Parent=tree
 check('safety: a part added to a tree later is locked at once (DescendantAdded)',p._props.CanCollide==false and p._props.Anchored==true and p._props.CanTouch==false and p._props.CanQuery==false)
 check('safety: a model with scripts dropped into the square later loses its scripts and collision',codeIn(tree)==0 and #unsafe(m)==0)
 p:Destroy();m:Destroy()
end
-- the guard on the square only strips code: its signs, lamp lights and particles survive the detail folders coming and going
do local function count(cls)local n=0;for _,d in ipairs(life:GetDescendants())do if d._class==cls then n+=1 end end;return n end
 local g0,l0,e0=count('SurfaceGui'),count('PointLight'),count('ParticleEmitter')
 local cam=W.workspace.CurrentCamera
 cam.CFrame=CF(0,12,1200);api.ApplyLod();cam.CFrame=CF(0,12,-300);api.ApplyLod()
 check('safety: the square keeps its signs, lamp lights and particles when its detail folders come and go (the guard strips only code)',
  g0>0 and l0>0 and e0>0 and count('SurfaceGui')==g0 and count('PointLight')==l0 and count('ParticleEmitter')==e0,g0..'/'..count('SurfaceGui')..' guis, '..l0..'/'..count('PointLight')..' lights, '..e0..'/'..count('ParticleEmitter')..' emitters')
end
-- tiers
for _,t in ipairs({1,2})do budget.Tier=t
 local a,s2,l=client();local n=#clones(l)
 check('client tier '..t..': '..(t==1 and'18 clones of the 5-part model'or'the 5- and 14-part models within 300 parts'),t==1 and n==18 or t==2 and n>18 and n<=30,n..' clones, '..tostring(l:GetAttribute('UsedFor')))
 local bad=unsafe(l);check('client tier '..t..': every part locked',#bad==0,first(bad))
 s2:Destroy()
end
budget.Tier=3
-- the folder changes: the client rebuilds by itself
do sc:Destroy()
 local f2=folder()
 local a,s2,l=client()
 check('missing / empty folder: no clones, UsedFor says so, the part-built studded trees stand',#clones(l)==0 and l:GetAttribute('UsedFor'):find('none',1,true)~=nil and l:FindFirstChild('Tree trunk',true)~=nil,l:GetAttribute('UsedFor'))
 a.Tick(.6) -- (settles the client: built for this decor folder)
 local before=W.workspace:FindFirstChild('HubLife151')
 a.Tick(.6)
 check('client: no rebuild while nothing changes',W.workspace:FindFirstChild('HubLife151')==before)
 fakeTree('Owner tree',9).Parent=f2
 a.Tick(.6)
 local l2=W.workspace:FindFirstChild('HubLife151')
 check('client: a tree model placed in the folder later -> the square rebuilds with it',l2~=nil and #clones(l2)==30,l2 and#clones(l2))
 s2:Destroy()
 f2:Destroy()
 local a3,s3,l3=client()
 check('missing folder: no clones, all 58 part-built trees',#clones(l3)==0 and l3:GetAttribute('UsedFor'):find('none: no tree templates',1,true)~=nil)
 s3:Destroy()
 -- only broken models
 local f3=folder();R.new('Model').Parent=f3
 local a4,s4,l4=client()
 check('broken models only: the part-built studded trees, the broken one reported',#clones(l4)==0 and l4:GetAttribute('TemplateParts'):find('broken',1,true)~=nil,l4:GetAttribute('TemplateParts'))
 s4:Destroy()
 -- a model that cannot be placed (ScaleTo fails) falls back slot by slot
 fakeTree('Unscalable',6).Parent=f3
 local raw=R.Inst.ScaleTo;R.Inst.ScaleTo=function()error('ScaleTo failed')end
 local a5,s5,l5=client()
 R.Inst.ScaleTo=raw
 local trunks=0;for _,d in ipairs(l5:GetDescendants())do if d.Name=='Tree trunk'then trunks+=1 end end
 check('a model that cannot be placed: every leafy slot falls back to its part-built tree (no gap)',#clones(l5)==0 and trunks==43,trunks..' trunks (43 = 14 oaks + 8 poplars + 8 blossoms + 8 fruit trees + 5 ember trees)')
 s5:Destroy()
end

-- 5. the part-built trees, bushes and topiary are studded ---------------------------------------------------------------------------------------
do local f4=folder()
 local a,s2,l=client()
 local studded,flat,wrongFace,notPlastic=0,{},{},{}
 local TREEY={['Tree trunk']=1,['Tree crown']=1,['Tree crown top']=1,['Root flare']=1,['Poplar crown']=1,['Blossom crown']=1,['Leaf tuft']=1,['Pine trunk']=1,['Pine tier']=1,['Snow rim']=1,['Pine snow']=1,
  ['Palm trunk']=1,['Palm leaf']=1,['Cactus']=1,['Cactus top']=1,['Cactus arm']=1,['Barrel cactus']=1,['Ember crown']=1,['Charred branch']=1,Bush=1,['Topiary cone']=1,['Topiary ball']=1,['Topiary stem']=1}
 local FACE={RightSurface=function(c)return c.RightVector.Y end,LeftSurface=function(c)return-c.RightVector.Y end,TopSurface=function(c)return c.UpVector.Y end,
  BottomSurface=function(c)return-c.UpVector.Y end,BackSurface=function(c)return-c.LookVector.Y end,FrontSurface=function(c)return c.LookVector.Y end}
 for _,p in ipairs(parts(l))do if TREEY[p.Name]then
  local face;for k in pairs(FACE)do local v=p._props[k];if v and(v.Name or tostring(v)):find('Studs')then face=k end end
  if not face then flat[#flat+1]=Z.path(p)
  else studded+=1
   local up=FACE[face](p._props.CFrame);for k,fn in pairs(FACE)do if fn(p._props.CFrame)>up+1e-6 then wrongFace[#wrongFace+1]=Z.path(p)..' studs on '..face..', '..k..' points up more';break end end
  end
  local m=p._props.Material;if not(m and(m.Name or tostring(m)):find('Plastic'))or(m.Name or tostring(m))=='SmoothPlastic'then notPlastic[#notPlastic+1]=Z.path(p)end
 end end
 check('studs: every part-built tree, bush and topiary part has Studs ('..studded..' parts)',#flat==0 and studded>300,first(flat))
 check('studs: always on the face that points up (Inlet under it)',#wrongFace==0,first(wrongFace))
 check('studs: Plastic (the material the stud surfaces show on, like the place\'s track trees)',#notPlastic==0,first(notPlastic))
 s2:Destroy()
end

print(string.format('R151 hub trees: %d passed, %d failed',passed,failed))
if failed>0 then error('R151 hub trees: '..failed..' failed')end
