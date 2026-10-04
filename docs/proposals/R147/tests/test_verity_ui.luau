--!nocheck
-- R147 (owner: Verity gives a "Verity pack" for a Void pack, and the Verity seed has its own Index category): the CLIENT half on the
-- Roblox mock with the real SeedPackVisuals / SeedPackRenderer / EclipsePackArt / VerityPackArt / VoidPackFx / ItemPictures /
-- VeiledEventClient81 / SeedPackRender / ChestIndex of this checkout. The comparison "before" modules are the base commit's
-- (git show BASE:..., loaded as SeedPackVisualsBase / SeedPackRendererBase / EclipsePackArtBase / VoidPackFxBase / ChestIndexBase).
--  1. the Verity pack art (owner, R148: "verity pack should be using our default pack mesh and sizes and painting it yellow and adding a
--     smiley face on top of it, keep it simple"): the plain pack (the Standard design and scale, so Bounds / carry / tear are an
--     ordinary pack's, part for part), every mesh yellow 255,255,0 (the seal and tear strips a darker yellow), VerityConfig's
--     picture as Decals on a plate on its front and on its back (Decals: SurfaceGuis do not render in the hotbar / Bag viewports);
--     Gold / Diamond coats paint it like any pack and the Decals stay white on top; on every path: world, dropped, carried,
--     CarryBag, opening copy, inventory picture, viewport;
--  2. the Void pack, the Mech pack and the ordinary packs build part for part what the base commit built (and bound the same);
--  3. VoidPackFx: Void effects identical to the base's; Verity effects gold sparkles and a warm light only (no smoke, debris, comets
--     or outline, nothing purple); the real VeiledEventClient81 loop gives a carried Verity pack those; SeedPackRender leaves it alone;
--     the opening scripts and GiantVisualSafety hide / fade its Decals too (they follow only their own properties);
--  4. (the Index checks - tab 9 VERITY, its card, rewards, alerts, the tab row - moved to docs/proposals/R148/tests/test_index_limited.luau: R148 made
--     MECH and VERITY one LIMITED tab).
local W=require('./world');local F=require('./fixtures');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local function rgb(c)return math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)end
local function colorIs(c,r,g,b)local x,y,z=rgb(c);return x==r and y==g and z==b end
local function rgbKey(c)return table.concat({rgb(c)},',')end
-- Mock gaps for the seed / picture builders (as in the R137 pictures test).
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
F.packAssets(W)
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=147;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local Cat=W.module('VerityCatalog');local Rules=W.module('SeedPackRules')
local Visuals=W.module('SeedPackVisuals');local VisualsBase=W.module('SeedPackVisualsBase')
local Eclipse=W.module('EclipsePackArt');local EclipseBase=W.module('EclipsePackArtBase');local VerityArt=W.module('VerityPackArt')
local PackFx=W.module('VoidPackFx');local PackFxBase=W.module('VoidPackFxBase')
local VERITY=Cat.Variant;local VOID='EclipseReliquary'
assert(VERITY=='VerityReliquary')

-- Serialising for before / after comparisons (numbers rounded, instances by class + name, Color3 by 0..255).
local function ser(v,depth)
 depth=depth or 0
 local t=type(v)
 if t=='number'then return('%.4f'):format(v)elseif t~='table'then return tostring(v)end
 if v._class then return'<'..v._class..':'..tostring(v._props.Name)..'>'end
 if depth>4 then return'{...}'end
 if v.__type=='Color3'then return'c('..rgbKey(v)..')'end
 local keys={};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 local out={};for _,k in ipairs(keys)do if type(v[k])~='function'then out[#out+1]=tostring(k)..'='..ser(v[k],depth+1)end end
 return'{'..table.concat(out,',')..'}'
end
local function partLine(d)
 local out={d._class,d._props.Name}
 local keys={};for k in pairs(d._props)do keys[#keys+1]=k end;table.sort(keys)
 for _,k in ipairs(keys)do if k~='Name'and k~='Parent'then out[#out+1]=k..'='..ser(d._props[k])end end
 local akeys={};for k in pairs(d._attrs)do akeys[#akeys+1]=k end;table.sort(akeys)
 for _,k in ipairs(akeys)do out[#out+1]='@'..k..'='..ser(d._attrs[k])end
 return table.concat(out,'|')
end
local function fingerprint(model)
 local out={'MODEL|'..partLine(model)}
 for _,d in ipairs(model:GetDescendants())do out[#out+1]=partLine(d)end
 return out
end
local function sameFingerprint(a,b)
 if #a~=#b then return false,'count '..#a..' vs '..#b end
 for i=1,#a do if a[i]~=b[i]then return false,'#'..i..'\n   '..a[i]..'\n   '..b[i]end end
 return true
end
local function parts(bag)local out={};for _,p in ipairs(bag:GetDescendants())do if p:IsA('BasePart')and p~=bag.PrimaryPart then out[#out+1]=p end end;return out end
local function extents(bag)
 local lo,hi=V3(1e9,1e9,1e9),V3(-1e9,-1e9,-1e9)
 for _,p in ipairs(parts(bag))do
  local c=p.CFrame.Position;local h=p.Size*.5
  lo=V3(math.min(lo.X,c.X-h.X),math.min(lo.Y,c.Y-h.Y),math.min(lo.Z,c.Z-h.Z));hi=V3(math.max(hi.X,c.X+h.X),math.max(hi.Y,c.Y+h.Y),math.max(hi.Z,c.Z+h.Z))
 end
 return hi-lo
end
local function warm(c)local r,g,b=rgb(c);return r>=g and g>=b end
local function boundsLine(b)return ser(b)end

-- 0. The Void art module itself is the base commit's ---------------------------------------------------------------------------------------
local voidSpecs,baseSpecs=Eclipse.Specs(),EclipseBase.Specs()
do
 local same,why=#voidSpecs==#baseSpecs and #voidSpecs>100,nil
 for i,s in ipairs(voidSpecs)do
  local b=baseSpecs[i];local line=function(x)return table.concat({x.Name,ser(x.Size),ser(x.Frame),rgbKey(x.Color),x.Material.Name,tostring(x.Shape and x.Shape.Name),ser(x.Transparency),ser(x.Spin),ser(x.Pivot),ser(x.Pulse),ser(x.Phase)},'|')end
  if line(s)~=line(b)then same=false;why=line(s)..' vs '..line(b);break end
 end
 check(same,'EclipsePackArt.Specs() is the base commit\'s, spec for spec ('..#voidSpecs..' parts)'..(why and(': '..why)or''))
 local pal=true;for k,v in pairs(EclipseBase.Palette)do if rgbKey(Eclipse.Palette[k])~=rgbKey(v)then pal=false end end
 check(pal,'the Void palette values are unchanged')
end

-- 1. The yellow pack with a smiley --------------------------------------------------------------------------------------------------------
local IMAGE='rbxassetid://102712963740896'
local Config=W.module('VerityConfig')
local Pic=W.module('HarvestGeometry')
local KEY=Rules.DesignKey(7,VERITY)
check(VerityArt.Image==IMAGE and Config.Image==IMAGE,'the picture is VerityConfig.Image, rbxassetid://102712963740896 (the NPC card\'s)')
check(not W.B.VerityPackArt:find('102712963740896',1,true)and W.B.VerityCatalog:find("FaceImageId='rbxassetid://102712963740896'",1,true)~=nil,'(source: the pack art takes the id from VerityConfig; VerityCatalog holds it as the FaceImageId literal for the ball, test_verity_art keeps the two equal)')
check(colorIs(VerityArt.Yellow,255,255,0)and select(3,rgb(VerityArt.Dark))==0 and select(1,rgb(VerityArt.Dark))>180 and warm(VerityArt.Dark),'yellow 255,255,0, and a slightly darker yellow for the trims')
do
 local fx=VerityArt.Fx;local allWarm=true
 for _,k in ipairs({'Haze','Nebula','Stars'})do check(fx[k].Texture:find('sparkles_main')~=nil,'Fx.'..k..': a built-in sparkle texture');for _,c in ipairs(fx[k].Colors)do if not warm(c)then allWarm=false end end end
 check(allWarm and warm(fx.Light),'every effect colour is warm gold / cream, nothing purple')
 check(fx.Debris==nil and fx.Comet==nil and fx.Trail==nil and fx.Fill==nil and fx.Outline==nil,'no debris, comets or outline')
end
-- our default pack: the Standard design and scale, so size / Bounds / carry are an ordinary pack's
local pv,std=Rules.GetVariant(VERITY),Rules.GetVariant('Standard')
check(pv.BagScale==std.BagScale and pv.BagScale==1 and Rules.DesignKey(7,VERITY)==Rules.DesignKey(7,'Standard')and KEY=='Storm_02','the Verity record is the plain pack: BagScale 1 and the Standard design ('..KEY..')')
check(pv.Name==Cat.PackName and Rules.PackLabel(7,VERITY,1,'None')=='Verity Pack'and Rules.GetPackTier(VERITY).Name=='Verity','(its name, label and tier are the Verity pack\'s)')
for _,size in ipairs({1,2.5,.5,25})do
 check(boundsLine(Visuals.Bounds(7,VERITY,size))==boundsLine(Visuals.Bounds(7,'Standard',size)),'Visuals.Bounds is the plain pack\'s at size '..size)
end

-- 2. Building: every path ---------------------------------------------------------------------------------------------------------------
local function bagAt(mod,y,stage,variant,size,coat)return mod.Bag(CF(0,y,0),W.workspace,1,nil,stage,variant,1,size,coat or'None')end
-- zslack: the picture plates stand (depth - sink) proud of the pouch's front / back, the one place a part leaves the plain pack's Bounds
local function inside(bag,b,label,zslack)
 local root=bag.PrimaryPart.CFrame;local worst,worstZ=0,0
 for _,p in ipairs(parts(bag))do
  local frame=root:Inverse()*p.CFrame;local h=p.Size*.5
  for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
   local q=frame*V3(h.X*x,h.Y*y,h.Z*z);local r=math.sqrt(q.X*q.X+q.Z*q.Z)
   worst=math.max(worst,r-b.Radius,q.Y-b.MaxY,b.MinY-q.Y);worstZ=math.max(worstZ,q.Z-b.MaxZ,b.MinZ-q.Z)
  end end end
 end
 return check(worst<=1e-3 and worstZ<=(zslack or 0)+1e-3,label..': all parts inside Bounds (worst overshoot '..string.format('%.4f, z %.4f of %.4f allowed',worst,worstZ,zslack or 0)..')')
end
local function decalsOf(inst)local out={};for _,d in ipairs(inst:GetDescendants())do if d:IsA('Decal')then out[#out+1]=d end end;return out end
local function others(bag)local out={};for _,p in ipairs(parts(bag))do if not p.Name:match('^VerityFace')then out[#out+1]=p end end;return out end
local voidBags,verityBags={},{}
for _,case in ipairs({{1,'None'},{2.5,'Gold'},{25,'Diamond'},{.5,'None'}})do
 local size,coat=case[1],case[2];local label=('%sx %s'):format(size,coat)
 local void=bagAt(Visuals,10,7,VOID,size,coat);local vr=bagAt(Visuals,10,7,VERITY,size,coat);local plain=bagAt(Visuals,10,7,'Standard',size,coat)
 local pr,po=parts(vr),others(vr);local scale=vr:GetAttribute('VisualScale')
 check(vr:GetAttribute('BagVariant')==VERITY and vr:GetAttribute('Stage')==7 and vr:GetAttribute('PackRarity')=='Verity'and vr:GetAttribute('PackRank')==7,label..': Verity record attributes (variant, stage 7, tier Verity, rank 7)')
 check(vr:GetAttribute('VerityPack')==true and vr:GetAttribute('CompactPackReady')==true and vr:GetAttribute('EclipsePack')==nil and vr:GetAttribute('SpecialPackDesign89')==nil,label..': an ordinary pack build (VerityPack; not the reliquary)')
 check(vr:GetAttribute('CompactPackPartCount')==#pr+1 and near(scale,plain:GetAttribute('VisualScale')),label..': CompactPackPartCount counts every part ('..tostring(vr:GetAttribute('CompactPackPartCount'))..'); the plain pack\'s VisualScale')
 -- it IS the ordinary pack: the same parts, sizes and places, plus the two picture plates
 local same=#po==#parts(plain)
 for i=1,math.min(#po,#parts(plain))do local a,b=po[i],parts(plain)[i];if a._class~=b._class or a.Name~=b.Name or ser(a.Size)~=ser(b.Size)or ser(a.CFrame)~=ser(b.CFrame)then same=false end end
 check(same,label..': the plain pack\'s parts, sizes and places ('..#po..' parts: mesh, seal, 8 tear strips, root) plus two plates')
 local tear=0;for _,p in ipairs(vr:GetChildren())do if p:GetAttribute('TearIndex')then tear+=1 end end
 check(tear==8 and vr:FindFirstChild('BottomSeal')~=nil,label..': the normal tear strips and seal are there (the tear / opening work as on any pack)')
 local stray=0;for _,p in ipairs(pr)do if p.Name:match('^Galaxy')or p.Name:match('^Rune')or p.Name:match('^Photon')or p.Name:match('^EventHorizon')or p.Name:match('^HaloDebris')or p.Name:match('^Void')or p.Name:match('^VerityRim')or p.Name=='VerityCard'then stray+=1 end end
 check(stray==0,label..': no reliquary pieces, rings, runes, eye, halo, rim or card')
 -- yellow, or the coat
 local c=Rules.PackMutations[coat]
 if coat=='None'then
  local meshes,yellow,warmAll=0,0,true
  for _,p in ipairs(pr)do
   if p:IsA('MeshPart')then meshes+=1;if colorIs(p.Color,255,255,0)and p.Material.Name=='SmoothPlastic'and p.TextureID==''then yellow+=1 end end
   local r,g,b=rgb(p.Color);if not(b==0 and r>=g)then warmAll=false end
  end
  check(meshes>=1 and yellow==meshes,label..': every mesh of the pouch is yellow 255,255,0, SmoothPlastic, no texture ('..yellow..'/'..meshes..')')
  check(warmAll,label..': every part is yellow or darker yellow: no biome colour anywhere')
  local darkOk=true;for _,p in ipairs(vr:GetChildren())do if p.Name=='BottomSeal'or p:GetAttribute('TearIndex')then darkOk=darkOk and rgbKey(p.Color)==rgbKey(VerityArt.Dark)end end
  check(darkOk,label..': seal and tear strips in the darker yellow')
  check(colorIs(vr:GetAttribute('PaperColor'),255,255,0),label..': PaperColor (the opening paper) is yellow')
  local noApp=true;for _,d in ipairs(vr:GetDescendants())do if d:IsA('SurfaceAppearance')then noApp=false end end;check(noApp,label..': no SurfaceAppearance left from the biome art')
 else
  local painted=true;for _,p in ipairs(pr)do if rgbKey(p.Color)~=rgbKey(c.Color)or p.Material~=c.Material then painted=false end end
  check(painted,label..': the '..coat..' coat paints the whole pack, plates included, like any other pack')
  check(rgbKey(vr:GetAttribute('PaperColor'))==rgbKey(c.Color),label..': PaperColor is the coat\'s')
 end
 -- the picture: a plate on each outer face, each with its Decal
 local front,back=vr:FindFirstChild('VerityFaceFront',true),vr:FindFirstChild('VerityFaceBack',true)
 if check(front and back and front:IsA('Part')and back:IsA('Part'),label..': a front plate and a back plate')then
  local side=VerityArt.Side(KEY)*scale
  check(near(front.Size.X,side,1e-6)and near(front.Size.Y,side,1e-6)and near(back.Size.X,side,1e-6)and near(front.Size.Z,VerityArt.PlateDepth*scale,1e-6),label..(': square plates %.3f studs a side, thin'):format(side))
  check(front.Transparency==(coat=='Diamond'and .10 or 0)and back.Transparency==front.Transparency,label..': opaque (the coat\'s own transparency at most)')
  check(front.Anchored and front.CanCollide==false and front.CanQuery==false and front.CanTouch==false and front.Massless,label..': inert world parts, anchored')
  local rootCF=vr.PrimaryPart.CFrame
  local fz,bz=(rootCF:Inverse()*front.CFrame).Position.Z,(rootCF:Inverse()*back.CFrame).Position.Z
  local fx0,fy0=(rootCF:Inverse()*front.CFrame).Position.X,(rootCF:Inverse()*front.CFrame).Position.Y
  check(fz<0 and bz>0 and near(fx0,0,1e-6)and near(fy0,0,1e-6),label..': centred on the pack, one on the front (-Z), one on the back (+Z)')
  -- nothing of the pouch is in front of them
  local clear=true
  for _,p in ipairs(po)do if p~=vr.PrimaryPart then
   local lo,hi=1e9,-1e9
   for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do local q=(rootCF:Inverse()*p.CFrame)*V3(p.Size.X*.5*x,p.Size.Y*.5*y,p.Size.Z*.5*z);lo=math.min(lo,q.Z);hi=math.max(hi,q.Z)end end end
   if lo<fz-front.Size.Z/2+.004*scale-1e-6 or hi>bz+back.Size.Z/2-.004*scale+1e-6 then clear=false end
  end end
  check(clear,label..': the plates are the outermost surfaces: no part of the pack covers the picture')
  local fd,bd=decalsOf(front),decalsOf(back)
  check(#fd==1 and #bd==1 and #decalsOf(vr)==2 and fd[1].Face.Name=='Front'and bd[1].Face.Name=='Back','exactly one Decal per plate, on its outer face (Front / Back)')
  for _,d in ipairs({fd[1],bd[1]})do
   check(d.Texture==IMAGE and d.Transparency==0 and colorIs(d.Color3,255,255,255),label..': the '..d.Face.Name..' Decal is the Verity picture, white (untinted), on top, whatever the coat')
  end
 end
 local br=Visuals.Bounds(7,VERITY,size);inside(vr,br,label,(VerityArt.PlateDepth-VerityArt.PlateSink)*scale)
 check(boundsLine(br)==boundsLine(Visuals.Bounds(7,'Standard',size)),label..': Bounds are the plain pack\'s ('..string.format('R %.3f, Y %.3f..%.3f',br.Radius,br.MinY,br.MaxY)..')')
 check(W.CS:HasTag(vr,'BiomeSeedPackVisual'),label..': tagged BiomeSeedPackVisual (the effects owner finds it)')
 if size>10 then local tagged=0;for _,p in ipairs({front,back})do if W.CS:HasTag(p,'GiantVisualPart')then tagged+=1 end end;check(tagged==2,label..': a giant pack\'s plates are GiantVisualParts (the camera fade reaches the picture)')end
 local ids=0;for _,d in ipairs(vr:GetDescendants())do for _,k in ipairs({'TextureID','Texture','Image'})do local v=d._props[k];if type(v)=='string'and v:find('rbxassetid')and v~=IMAGE then ids+=1 end end end
 check(ids==0,label..': no uploaded asset but the picture')
 plain:Destroy()
 voidBags[#voidBags+1]=void;verityBags[#verityBags+1]=vr
end
-- Carried: welded to the character, CarryBag, the layout from the same bounds, the opening copy.
local char=R.new('Model');char.Name='Carrier';char.Parent=W.workspace
local torso=R.new('Part');torso.Name='UpperTorso';torso.Size=V3(2,2,1);torso.CFrame=CF(0,5,0);torso.Anchored=false;torso.Parent=char
local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.Size=V3(2,2,1);hrp.CFrame=CF(0,4,0);hrp.Parent=char
local held=Visuals.Bag(CF(0,5,1),char,1,torso,7,VERITY,1,1,'None')
do
 local welded=true;for _,p in ipairs(parts(held))do if p.Anchored or not p:FindFirstChildOfClass('WeldConstraint')then welded=false end end
 check(welded,'held: every part (the plates too) is welded to the carrier ('..#parts(held)..' parts)')
 local ok,carry=pcall(Visuals.CarryBag,char,7,VERITY,1,1,'None');local okS,carryS=pcall(Visuals.CarryBag,char,7,'Standard',1,1,'None')
 check(ok and carry and carry.Name=='CarriedSeed'and carry:GetAttribute('SeedPackCarry')==true and carry:GetAttribute('BagVariant')==VERITY,'CarryBag builds the carried Verity pack: '..tostring(carry))
 check(okS and carryS and ser(carry:GetAttribute('CarryRootOffset'))==ser(carryS:GetAttribute('CarryRootOffset'))and near(carry:GetAttribute('CarryBackZ')or 0,carryS:GetAttribute('CarryBackZ')or 1e9)and near(carry:GetAttribute('CarryDisplayMultiplier'),carryS:GetAttribute('CarryDisplayMultiplier')),'the carry layout (offset, back Z, size) is the plain pack\'s')
 check(carry.PrimaryPart:FindFirstChild('LeftGrip')and carry.PrimaryPart:FindFirstChild('RightGrip'),'both hand grips exist')
 local wcount=0;for _,d in ipairs(carry:GetDescendants())do if d:IsA('WeldConstraint')then wcount+=1 end end
 check(wcount==#parts(carry)+1 and #decalsOf(carry)==2,'the carried pack is welded (and the root to the torso); both Decals came along ('..wcount..' welds)')
 carry:Destroy();carryS:Destroy()
 -- the opening copy (SeedPackClient / PackOpeningFeedback clone the bag): the plates and both Decals are there
 local copy=held:Clone();copy.Name='OpeningBag'
 for _,d in ipairs(copy:GetDescendants())do if d:IsA('WeldConstraint')then d:Destroy()elseif d:IsA('BasePart')then d.Anchored=true end end
 local cds=decalsOf(copy)
 check(#cds==2 and cds[1].Texture==IMAGE and cds[2].Texture==IMAGE and copy:FindFirstChild('VerityFaceFront',true)~=nil,'the opening copy keeps the plates and their two Decals')
end
-- Inventory / hotbar / Bag pictures (ItemPictures builds exactly Visuals.Bag, into a ViewportFrame) and a viewport preview.
do
 local P=W.module('ItemPictures')
 local tool=F.pack(W,W.workspace,7,VERITY,1,'None','Verity Pack')
 check(P.Key(tool)=='Pack|7|VerityReliquary|None','the picture key for a Verity pack Tool: '..tostring(P.Key(tool)))
 local gui=R.Instance.new('ScreenGui');gui.Name='Pictures';gui.Parent=pg
 local function holderAt(x)local h=R.new('Frame');h.Size=R.UDim2.fromOffset(60,60);h.Parent=gui;h.AbsoluteSize=R.Vector2.new(60,60);h.AbsolutePosition=R.Vector2.new(x,0);return h end
 local holder,holder2,holder3,holder4=holderAt(0),holderAt(70),holderAt(140),holderAt(210)
 local voidTool=F.pack(W,W.workspace,7,VOID,1,'None','Void Pack')
 local goldTool=F.pack(W,W.workspace,7,VERITY,1,'Gold','Gold Verity Pack')
 local stdTool=F.pack(W,W.workspace,7,'Standard',1,'None','Standard Pack')
 P.Show(holder,tool,1);P.Show(holder2,voidTool,1);P.Show(holder3,goldTool,1);P.Show(holder4,stdTool,1)
 for _=1,200 do W.frames(1)end
 local view,view2,view3,view4=holder:FindFirstChild('ItemViewport'),holder2:FindFirstChild('ItemViewport'),holder3:FindFirstChild('ItemViewport'),holder4:FindFirstChild('ItemViewport')
 check(view and view2 and view3 and view4,'the Verity pack, a Gold Verity pack, a Void pack and a plain pack all get their real 3D picture (hotbar / Bag slot)')
 local function stats(v)local n,yellow,plates=0,0,0;for _,d in ipairs(v:GetDescendants())do if d:IsA('BasePart')then n+=1;if colorIs(d.Color,255,255,0)then yellow+=1 end;if d.Name:match('^VerityFace')then plates+=1 end end end;return n,yellow,plates end
 local n,yellow,plates=stats(view);local n4=stats(view4)
 check(plates==2 and #decalsOf(view)==2 and yellow>=3 and n==n4+2,('the Verity picture is the plain pack plus the two plates, yellow, with both Decals (%d parts, plain %d, %d yellow)'):format(n,n4,yellow))
 for _,d in ipairs(view and decalsOf(view)or{})do check(d.Texture==IMAGE,'the viewport Decal shows the Verity picture ('..d.Face.Name..')')end
 local _,_,platesG=stats(view3)
 check(platesG==2 and #decalsOf(view3)==2 and colorIs(decalsOf(view3)[1].Color3,255,255,255),'a Gold Verity picture keeps both white Decals')
 local c1,s1=Pic.Bounds(view:GetChildren()[2]or view);local c2,s2=Pic.Bounds(view4:GetChildren()[2]or view4)
 check(s1.X>0 and near(s1.X,s2.X,.02)and near(s1.Y,s2.Y,.02),'the picture is framed like a plain pack\'s ('..string.format('%.2f x %.2f',s1.X,s1.Y)..' vs '..string.format('%.2f x %.2f',s2.X,s2.Y)..')')
 local n2=0;for _,d in ipairs(view2 and view2:GetDescendants()or{})do if d:IsA('BasePart')then n2+=1 end end
 check(n2>100,'(the Void picture is still its 100+ parts: '..n2..')')
 local wm=R.new('WorldModel');local vf=R.new('ViewportFrame');wm.Parent=vf
 local prev=Visuals.Bag(CF(0,0,0),wm,1,nil,7,VERITY,1,1,'None')
 check(prev.Parent==wm and #decalsOf(prev)==2 and prev:FindFirstChild('VerityFaceFront',true)~=nil,'a viewport preview (WorldModel parent) builds the plates and their Decals')
end

-- 3. Everything that is not the Verity pack builds exactly what it did ------------------------------------------------------------------
do
 local compared,partsTotal,boundsSame=0,0,0
 local function both(stage,variant,size,coat)
  local okA,a=pcall(bagAt,Visuals,10,stage,variant,size,coat);local okB,b=pcall(bagAt,VisualsBase,10,stage,variant,size,coat)
  local label=('%s stage %d %sx %s'):format(variant,stage,size,coat)
  if not check(okA==okB,label..': builds the same way before and after ('..tostring(okA)..'/'..tostring(okB)..')')then return end
  if okA then
   local same,why=sameFingerprint(fingerprint(a),fingerprint(b))
   check(same and #fingerprint(a)>1,label..': '..#fingerprint(a)..' instances, identical before and after'..(why and('\n   first difference: '..why)or''))
   compared+=1;partsTotal+=#parts(a);a:Destroy();b:Destroy()
  end
  local bn,bo=Visuals.Bounds(stage,variant,size),VisualsBase.Bounds(stage,variant,size)
  if check(boundsLine(bn)==boundsLine(bo),label..': Bounds identical') then boundsSame+=1 end
 end
 for _,case in ipairs({{1,'None'},{2.5,'Gold'},{25,'Diamond'},{.5,'None'},{10,'Gold'}})do both(7,VOID,case[1],case[2])end
 for _,case in ipairs({{1,'None'},{1.5,'Gold'},{3,'Diamond'}})do both(8,'MechLimited',case[1],case[2])end
 for stage=1,7 do for d=1,6 do both(stage,string.format('Pack%02d',d),1,'None')end end
 for _,legacy in ipairs({'Small','Standard','Grand'})do both(1,legacy,1,'None')end
 both(3,'Pack04',4,'Gold');both(5,'Pack06',2.5,'Diamond');both(2,'Pack02',.5,'Gold');both(6,'Pack05',25,'None');both(4,'Pack03',1,'Diamond')
 print(('existing packs: %d built identically before / after (%d parts), %d Bounds identical'):format(compared,partsTotal,boundsSame))
 check(compared>=50 and boundsSame>=compared,compared..' packs compared part by part ('..partsTotal..' parts); '..boundsSame..' Bounds compared')
 -- the Mech and Void carry layouts
 for _,v in ipairs({{7,VOID},{8,'MechLimited'},{3,'Pack03'}})do
  local a,b=pcall(Visuals.CarryBag,char,v[1],v[2],1,1,'None');local c,d=pcall(VisualsBase.CarryBag,char,v[1],v[2],1,1,'None')
  if check(a==c,v[2]..': CarryBag works the same before and after')and a then
   local same,why=sameFingerprint(fingerprint(b),fingerprint(d));check(same,v[2]..': the carried pack is identical before and after'..(why and('\n  '..why)or''))
   b:Destroy();d:Destroy()
  end
 end
 -- the Void art module itself
 local specsOk=true;for i,s in ipairs(voidSpecs)do if s.Name~=baseSpecs[i].Name then specsOk=false end end
 local b1,b2=Eclipse.Bounds(1.5),EclipseBase.Bounds(1.5)
 check(specsOk and boundsLine(b1)==boundsLine(b2),'EclipsePackArt.Bounds is the base\'s')
 check(boundsLine(Visuals.Bounds(7,VERITY,2))==boundsLine(Visuals.Bounds(7,'Standard',2))and boundsLine(Visuals.Bounds(7,VERITY,2))~=boundsLine(Visuals.Bounds(7,VOID,2)),'(and the Verity bounds are the plain pack\'s, no longer the Void\'s)')
end

-- 4. Effects (VoidPackFx) ---------------------------------------------------------------------------------------------------------------
local function fxDump(r)
 local out={}
 for _,d in ipairs(r.Fx.Folder:GetDescendants())do out[#out+1]=partLine(d)end
 return out
end
local function fxFolderFor(mod,bag,tier)
 local cap=mod.Capture(bag);mod.Create(cap,tier);return cap
end
do
 local voidBag=voidBags[1];local verityBag=verityBags[1]
 local cv,cb=PackFx.Capture(voidBag),PackFxBase.Capture(voidBag)
 check(cv.Palette==PackFx.Void and cv.Spinners==cb.Spinners and #cv.Pulsers==#cb.Pulsers and #cv.Parts==#cb.Parts,'Void capture: the Void fx palette, the same spinners / pulsers / parts as the base')
 local cr=PackFx.Capture(verityBag)
 local plainBag=bagAt(Visuals,80,7,'Standard',1,'None');local cp=PackFx.Capture(plainBag)
 check(cr and cr.Palette==VerityArt.Fx and cr.Spinners==0 and #cr.Pulsers==0 and #cr.Parts==#cp.Parts+2,'Verity capture: the Verity fx palette; no spin / pulse hints; the plain pack\'s parts and the two plates ('..#cr.Parts..')')
 plainBag:Destroy()
 check(PackFx.PaletteFor(verityBag)==VerityArt.Fx and PackFx.PaletteFor(voidBag)==PackFx.Void and PackFx.PaletteFor(bagAt(Visuals,70,3,'Pack03',1,'None'))==PackFx.Void,'PaletteFor: Verity -> its own, everything else -> the Void set')
 for tier=1,3 do
  local a=fxFolderFor(PackFx,voidBag,tier);local b=fxFolderFor(PackFxBase,voidBag,tier)
  local da,db=fxDump(a),fxDump(b)
  local same,why=sameFingerprint(da,db)
  check(same and #da>5,('tier %d: the Void effects (%d objects, every property) are identical to the base\'s'):format(tier,#da)..(why and('\n   '..why)or''))
  -- and step / pulse give the same poses and colours
  local la,fa,lb,fb={},{},{},{}
  PackFx.Pulse(a,3.3,false);PackFxBase.Pulse(b,3.3,false);PackFx.Step(a,3.3,voidBag.PrimaryPart.CFrame,tier,false,true,la,fa);PackFxBase.Step(b,3.3,voidBag.PrimaryPart.CFrame,tier,false,true,lb,fb)
  local poses=#fa==#fb;for i=1,#fa do if ser(fa[i])~=ser(fb[i])then poses=false end end
  local da2,db2=fxDump(a),fxDump(b);local same2=sameFingerprint(da2,db2)
  local colors=true;for i,e in ipairs(a.Pulsers)do if rgbKey(e.Part.Color)~=rgbKey(b.Pulsers[i].Part.Color)then colors=false end end
  check(poses and same2 and colors,'tier '..tier..': Step and Pulse leave the Void effects exactly as the base does')
  PackFx.Clear(a);PackFxBase.Clear(b)
 end
 -- Verity: gold sparkles and a warm light, no void haze, no debris, comets or outline.
 for tier=1,3 do
  local c=PackFx.Capture(verityBag);local fx=PackFx.Create(c,tier)
  check(#fx.Debris==0 and #fx.Comets==0 and fx.Highlight==nil,'tier '..tier..': no orbiting debris, no comets, no outline around the face')
  local sparkles,smoke=0,0
  for _,e in ipairs({fx.Haze,fx.Nebula,fx.Stars})do if e.Texture:find('sparkles_main')then sparkles+=1 end;if e.Texture:find('smoke')then smoke+=1 end end
  check(sparkles==3 and smoke==0,'tier '..tier..': three gold sparkle emitters, no smoke / void haze')
  local okColors=true;local bad=''
  local function seq(cs)if cs.A and cs.A.R then return{cs.A,cs.B}end;return{}end
  for _,e in ipairs({fx.Haze,fx.Nebula,fx.Stars})do for _,col in ipairs(seq(e.Color))do if not warm(col)then okColors=false;bad=e.Name end end end
  if not warm(fx.Light.Color)then okColors=false;bad='light'end
  check(okColors,'tier '..tier..': every effect colour is warm gold / cream, nothing purple ('..bad..')')
  check(colorIs(fx.Light.Color,255,196,70),'tier '..tier..': a warm gold light')
  local others=0;for _,d in ipairs(fx.Folder:GetChildren())do if d.Name~='VoidFxCore'then others+=1 end end
  check(others==0 and fx.Folder.Name=='_VoidPackFx122'and fx.Nebula.Texture:match('^rbxasset://textures/')~=nil,'tier '..tier..': the folder holds only the core with the emitters and the light; built-in textures only')
  local list,frames={},{};PackFx.Step(c,10,verityBag.PrimaryPart.CFrame,tier,false,true,list,frames)
  check(#list==1 and fx.Light.Enabled==(tier==3)and fx.Nebula.Enabled==(tier>1)and fx.Stars.Enabled==(tier==3),'tier '..tier..': the same gating as the Void pack (light only at full quality); only the core moves')
  local a,b={},{};local la,lb={},{}
  PackFx.Step(c,3,verityBag.PrimaryPart.CFrame,tier,true,false,la,a);PackFx.Step(c,7,verityBag.PrimaryPart.CFrame,tier,true,false,lb,b)
  check(not fx.Nebula.Enabled,'tier '..tier..': Reduced Motion: no swirl')
  PackFx.Pulse(c,1.234,false);PackFx.Clear(c)
  check(fx.Folder.Parent==nil and c.Fx==nil,'tier '..tier..': clearing removes the effects')
 end
end

-- 5. The real client loops --------------------------------------------------------------------------------------------------------------
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local remote=R.new('RemoteEvent');remote.Name='VeiledArrival81';remote._props.OnClientEvent=R.signal();remote.Parent=remotes
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
W.stub('NoticeFeed83',{Push=function()end})
W.stub('VeiledArrivalFx',{Preload=function()end,Arrive=function()end,Stop=function()end})
for _,b in ipairs(voidBags)do b:Destroy()end;for _,b in ipairs(verityBags)do b:Destroy()end;held:Destroy()
do
 local cam=W.workspace.CurrentCamera;cam.CFrame=CF(0,10,0)
 -- A carried (anchored-less) pack never sits in the world, so the loop's "carried" branch is the one a Verity pack uses.
 local verity=bagAt(Visuals,10,7,VERITY,1,'None');local void=bagAt(Visuals,10,7,VOID,1,'None')
 for _,p in ipairs({verity,void})do p:SetAttribute('WorldPack',false)end
 local sc=R.new('LocalScript');sc.Name='VeiledEventClient81';W.load('VeiledEventClient81',sc)
 W.frames(20,1/30)
 local folders={};for _,f in ipairs(W.workspace:GetChildren())do if f.Name=='_VoidPackFx122'then folders[#folders+1]=f end end
 check(#folders==2,'the real VeiledEventClient81 gives both a carried Verity pack and a carried Void pack effects ('..#folders..')')
 local goldFx,voidFx
 for _,f in ipairs(folders)do
  local h=f:FindFirstChild('VoidDistortion')
  if h and h.Adornee==void and colorIs(h.OutlineColor,150,80,230)then voidFx=f elseif not h then goldFx=f end
 end
 check(voidFx~=nil and goldFx~=nil,'the Void pack\'s effects are still violet with their outline; the Verity pack\'s have no outline')
 if goldFx then
  local emitters,debris,comets,others=0,0,0,0
  for _,d in ipairs(goldFx:GetDescendants())do
   if d:IsA('ParticleEmitter')then emitters+=1;check(d.Texture:find('sparkles_main')~=nil,'a Verity emitter uses the sparkle texture')
   elseif d.Name=='VoidDebris'then debris+=1 elseif d.Name=='VoidComet'then comets+=1 elseif d:IsA('BasePart')and d.Name~='VoidFxCore'then others+=1 end
  end
  local light=goldFx:FindFirstChild('VoidFxCore')and goldFx.VoidFxCore:FindFirstChild('VoidPulseLight')
  check(emitters==3 and debris==0 and comets==0 and others==0,'the Verity effects: gold sparkle emitters only (3), no debris or comets ('..emitters..' / '..debris..' / '..comets..')')
  check(light and colorIs(light.Color,255,196,70),'and the warm gold light')
 end
 local lights=0;for _,f in ipairs(folders)do local core=f:FindFirstChild('VoidFxCore');local l=core and core:FindFirstChild('VoidPulseLight');if l and l.Enabled then lights+=1 end end
 check(lights==1,'one pulsing light in the scene')
 -- a non-reliquary pack is never tracked
 local plain=bagAt(Visuals,10,3,'Pack03',1,'None');plain:SetAttribute('WorldPack',false);W.frames(10,1/30)
 local n=0;for _,f in ipairs(W.workspace:GetChildren())do if f.Name=='_VoidPackFx122'then n+=1 end end
 check(n==2,'an ordinary pack gets no void / verity effects')
 plain:Destroy()
 verity:Destroy();void:Destroy();W.frames(5,1/30)
 n=0;for _,f in ipairs(W.workspace:GetChildren())do if f.Name=='_VoidPackFx122'then n+=1 end end
 check(n==0,'destroyed packs release their effects')
 sc.Destroying:Fire()
end
-- SeedPackRender (the generic rarity glints / aura): ordinary packs are tracked, the Void and the Verity pack are not.
do
 local function withAura(bag)local e=R.new('ParticleEmitter');e.Name='PackRarityAura';e.Enabled=true;e.Parent=bag;return e end
 local plain=bagAt(Visuals,10,3,'Pack03',1,'None');local void=bagAt(Visuals,10,7,VOID,1,'None');local verity=bagAt(Visuals,10,7,VERITY,1,'None')
 local ep,ev,er=withAura(plain),withAura(void),withAura(verity)
 for _,b in ipairs({plain,void,verity})do b:SetAttribute('CompactPackReady',true)end
 local ok,err=pcall(function()local sc=R.new('LocalScript');sc.Name='SeedPackRender';W.load('SeedPackRender',sc)end)
 if check(ok,'the real SeedPackRender loads on the mock: '..tostring(err))then
  W.frames(30,1/30)
  check(ep.Enabled==false,'an ordinary pack is tracked (its aura emitter is taken over)')
  check(ev.Enabled==true and er.Enabled==true,'the Void pack and the Verity pack are left alone (their own effects)')
 end
 check((W.B.SeedPackRender:find("v=='EclipseReliquary'or v==VerityVariant then return end",1,true))~=nil,'(source: the early return names both reliquary variants)')
end
-- Source wiring.
check(W.B.SeedPackRenderer:find("VerityPackArt",1,true)~=nil and W.B.SeedPackVisuals:find("VerityPackArt",1,true)==nil and W.B.SeedPackVisuals:find("CoatSkip",1,true)==nil and W.B.VeiledEventClient81:find("VerityVariant",1,true)~=nil,'(source: only the renderer and the effects owner name the Verity variant: Bounds and the coat loop are the plain pack\'s)')

-- 5b. The opening. A Decal follows only its own properties, not its part's: the two scripts that hide the carried pack (the click copy,
-- the tear) and fade its copy treat the picture's Decals like parts. The real scripts on the mock, with a carried Verity pack.
do
 local noop=function()end
 function R.Inst:Play()end;function R.Inst:Stop()end;function R.Inst:Pause()end
 W.service('Debris').AddItem=noop;W.service('ContentProvider').PreloadAsync=noop
 function Players.GetPlayers()return{player}end;Players.PlayerRemoving=R.signal()
 player.CharacterAdded=R.signal();player.CharacterRemoving=R.signal()
 local binds={};function W.Run.BindToRenderStep(_,name,_,fn)binds[name]=fn end;function W.Run.UnbindFromRenderStep(_,name)binds[name]=nil end
 W.Run.PreAnimation=R.signal()
 W.stub('SeedCarryPose',{new=function()return{Reset=noop,IsReady=function()return true end,Apply=noop}end})
 W.stub('RarityRevealAudio',{Preload=noop,Stop=noop,Begin=noop,Burst=noop,Update=noop})
 W.stub('RarityRevealScreen',{Create=function()return setmetatable({},{__index=function()return noop end})end})
 local me=R.new('Model');me.Name='Tester';me.Parent=W.workspace;player.Character=me
 local t2=R.new('Part');t2.Name='UpperTorso';t2.Size=V3(2,2,1);t2.CFrame=CF(0,5,0);t2.Anchored=false;t2.Parent=me
 local h2=R.new('Part');h2.Name='HumanoidRootPart';h2.Size=V3(2,2,1);h2.CFrame=CF(0,4,0);h2.Parent=me
 local hum=R.new('Humanoid');hum.Health=100;hum.Parent=me
 local art=R.new('Folder');art.Name='SeedArt';art.Parent=remotes
 local seeds=R.new('Folder');seeds.Name='Seeds';seeds.Parent=art
 local cat=R.new('Folder');cat.Name='SeedCatalog';cat.Parent=remotes
 local def=R.new('Folder');def.Name='SunflowerSeed';def:SetAttribute('DisplayName','Sunflower Seed');def.Parent=cat
 local seedModel=Visuals.Seed({Id='SunflowerSeed'},1,CF(0,0,0),nil,1,nil,'None');seedModel.Name='SunflowerSeed';seedModel.Parent=seeds
 local function zero(model)for _,d in ipairs(model:GetDescendants())do if d:IsA('BasePart')or d:IsA('Decal')then d.LocalTransparencyModifier=0 end end end
 local function cardDecals(model)return model:FindFirstChild('VerityFaceFront',true),decalsOf(model)end
 -- (a) PackOpeningFeedback: clicking the held pack shakes a copy and hides the real one
 local sc1=R.new('LocalScript');sc1.Name='PackOpeningFeedback'
 local okA,errA=pcall(W.load,'PackOpeningFeedback',sc1)
 if check(okA,'the real PackOpeningFeedback loads on the mock: '..tostring(errA))then
  local tool=F.tool(W,'Verity Pack',{SeedPackTool=true,SeedInventoryId='v1',BagVariant=VERITY,Stage=7},nil);tool.Activated=R.signal();tool.Parent=me
  local carry=Visuals.CarryBag(me,7,VERITY,1,1,'None');zero(carry)
  binds.ChestChasePackPresentation();tool.Activated:Fire();binds.ChestChasePackPresentation()
  local copy=W.workspace:FindFirstChild('_LocalClickingPack')
  local card,ds=cardDecals(carry)
  check(copy~=nil and copy:FindFirstChild('VerityFaceFront',true)~=nil and #decalsOf(copy)==2,'clicking the held Verity pack makes the shaking copy with the plates and both Decals')
  check(card and card.LocalTransparencyModifier==1 and #ds==2 and ds[1].LocalTransparencyModifier==1 and ds[2].LocalTransparencyModifier==1,'and hides the real pack: its plate and both of its Decals')
  local shown=true;for _,d in ipairs(copy and decalsOf(copy)or{})do if(d.LocalTransparencyModifier or 0)~=0 then shown=false end end
  check(shown,'while the copy\'s Decals stay shown')
  tool.Parent=nil;binds.ChestChasePackPresentation()
  check(W.workspace:FindFirstChild('_LocalClickingPack')==nil and card.LocalTransparencyModifier==0 and ds[1].LocalTransparencyModifier==0 and ds[2].LocalTransparencyModifier==0,'putting the pack away drops the copy and shows the real plate and Decals again')
  carry:Destroy();sc1.Destroying:Fire()
 end
 -- (b) SeedPackClient: the tear. The copy is the card and its Decals; the real pack is hidden; the copy fades out with the wrapper.
 local sc2=R.new('LocalScript');sc2.Name='SeedPackClient'
 local okB,errB=pcall(W.load,'SeedPackClient',sc2)
 if check(okB,'the real SeedPackClient loads on the mock: '..tostring(errB))then
  local carry=Visuals.CarryBag(me,7,VERITY,1,1,'None');zero(carry);W.frames(10,1/30)
  carry:SetAttribute('RevealSeedId','SunflowerSeed');carry:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
  local card,ds=cardDecals(carry)
  local function copyDecals()
   local effects=W.workspace:FindFirstChild('_LocalSeedPackEffects');local reveal=effects and effects:FindFirstChild('SeedReveal');local copy=reveal and reveal:FindFirstChild('OpeningBag')
   return copy,copy and decalsOf(copy)or{}
  end
  local okRun,errRun=pcall(W.frames,3,1/30)
  check(okRun,'the reveal runs without an error: '..tostring(errRun))
  local copy,cds=copyDecals()
  check(copy~=nil and copy:FindFirstChild('VerityFaceFront',true)~=nil and #cds==2,'the tear works on a copy of the Verity pack: the plates and both Decals')
  check(card.LocalTransparencyModifier==1 and ds[1].LocalTransparencyModifier==1 and ds[2].LocalTransparencyModifier==1,'the real pack (plate and both Decals) is hidden while the copy plays')
  check(cds[1]and cds[1].Transparency==0 and cds[2].Transparency==0,'the picture is fully visible while the paper tears')
  W.frames(24,1/30);copy,cds=copyDecals()
  check(cds[1]and cds[1].Transparency>0 and cds[1].Transparency<1 and near(cds[1].Transparency,cds[2].Transparency),'the picture fades out with the wrapper ('..(cds[1]and string.format('%.2f',cds[1].Transparency)or'-')..')')
  W.frames(24,1/30);copy,cds=copyDecals()
  check(cds[1]and cds[1].Transparency==1 and cds[2].Transparency==1,'and is gone before the seed rises')
  W.frames(120,1/30);copy=copyDecals()
  check(copy==nil,'the copy is released when the reveal ends')
  carry:Destroy();sc2.Destroying:Fire()
 end
 check((W.B.SeedPackClient:find('p:IsA("Decal")',1,true))~=nil and W.B.SeedPackClient:find('record.DecalFade',1,true)~=nil and(W.B.PackOpeningFeedback:find("p:IsA('Decal')",1,true))~=nil,'(source: both scripts name the Decal)')
 art:Destroy();cat:Destroy();player.Character=nil;me:Destroy()
end

-- 6. The Index: moved to docs/proposals/R148/tests/test_index_limited.luau. R148 (owner: "this index section should also be combined and named LIMITED") made MECH and
-- VERITY one tab, so "nine tabs, VERITY last" no longer holds; that test holds the Verity seed's card, progress and category-9 rewards (now the VERITY row of LIMITED),
-- the alerts, the tab row on every screen and "the other tabs unchanged" against the R147 release.
-- 6b. GiantVisualSafety: a giant pack's surfaces fade near the camera; a Decal (the Verity picture) ignores its part's modifier, so it is
-- faded the same way, and a Decal an opening hid (modifier 1) stays hidden.
do
 local gb={};local oldB,oldU=W.Run.BindToRenderStep,W.Run.UnbindFromRenderStep
 W.Run.BindToRenderStep=function(_,name,_,fn)gb[name]=fn end;W.Run.UnbindFromRenderStep=function(_,name)gb[name]=nil end
 local cam=W.workspace.CurrentCamera;cam.CFrame=CF(0,10,0)
 local p=R.new('Part');p.Name='VerityFaceFront';p.Size=V3(40,40,.4);p.CFrame=CF(0,10,4);p.LocalTransparencyModifier=0;p.Parent=W.workspace
 local front=R.new('Decal');front.LocalTransparencyModifier=0;front.Parent=p
 local hidden=R.new('Decal');hidden.LocalTransparencyModifier=1;hidden.Parent=p
 W.service('CollectionService'):AddTag(p,'GiantVisualPart')
 local sc=R.new('LocalScript');sc.Name='GiantVisualSafety'
 local ok,err=pcall(W.load,'GiantVisualSafety',sc)
 if check(ok and gb.GiantVisualSafety~=nil,'the real GiantVisualSafety loads on the mock: '..tostring(err))then
  gb.GiantVisualSafety(.1)
  check(p.LocalTransparencyModifier>.4 and near(front.LocalTransparencyModifier,p.LocalTransparencyModifier),'a giant Verity card next to the camera fades, and its picture Decal fades with it')
  check(hidden.LocalTransparencyModifier==1,'a Decal an opening hid stays hidden')
  p.CFrame=CF(0,10,200);gb.GiantVisualSafety(.1)
  check(p.LocalTransparencyModifier==0 and front.LocalTransparencyModifier==0 and hidden.LocalTransparencyModifier==1,'far away again: the card and its picture are back, the hidden Decal stays hidden')
  p.CFrame=CF(0,10,4);gb.GiantVisualSafety(.1);sc.Destroying:Fire()
  check(p.LocalTransparencyModifier==0 and front.LocalTransparencyModifier==0,'removing the script restores the card and its picture')
 end
 p:Destroy();W.Run.BindToRenderStep,W.Run.UnbindFromRenderStep=oldB,oldU
end
print(('Verity pack: the plain pack, yellow, with two %.2f-stud picture plates (the Void pack has %d parts); effects compared at 3 tiers'):format(VerityArt.Side(KEY),#voidSpecs))
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
