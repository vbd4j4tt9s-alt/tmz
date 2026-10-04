--!nocheck
-- R147 (owner: Verity gives a "Verity pack" for a Void pack, and the Verity seed has its own Index category): the CLIENT half on the
-- Roblox mock with the real SeedPackVisuals / SeedPackRenderer / EclipsePackArt / VerityPackArt / VoidPackFx / ItemPictures /
-- VeiledEventClient81 / SeedPackRender / ChestIndex of this checkout. The comparison "before" modules are the base commit's
-- (git show BASE:..., loaded as SeedPackVisualsBase / SeedPackRendererBase / EclipsePackArtBase / VoidPackFxBase / ChestIndexBase).
--  1. the Verity pack art (owner: "VERITY PACK CAN JUST BE THE VERITY'S SMILING FACE"): one square, almost see-through card inside the
--     Void pack's bounds with VerityConfig's picture as Decals on its front and back (Decals: SurfaceGuis do not render in the hotbar /
--     Bag viewports); nothing else (no pouch, rings, runes, eye, halo, debris); Gold / Diamond coats tint the Decals and add a rim
--     without painting the card; on every path: world, dropped, carried, CarryBag, opening copy, inventory picture, viewport;
--  2. the Void pack, the Mech pack and the ordinary packs build part for part what the base commit built (and bound the same);
--  3. VoidPackFx: Void effects identical to the base's; Verity effects gold sparkles and a warm light only (no smoke, debris, comets
--     or outline, nothing purple); the real VeiledEventClient81 loop gives a carried Verity pack those; SeedPackRender leaves it alone;
--     the opening scripts hide / fade its Decals too (they follow only their own properties);
--  4. the Index: nine tabs, VERITY last and gold, its card, progress, the halfway / completion rewards from BalanceValues81, alerts,
--     tabs fitting and not overlapping from a 360 px phone to 1920x1080, and the the Index unchanged against the base's script.
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

-- 1. The face card ----------------------------------------------------------------------------------------------------------------------
local IMAGE='rbxassetid://102712963740896'
local Config=W.module('VerityConfig')
local Pic=W.module('HarvestGeometry')
check(VerityArt.Image==IMAGE and Config.Image==IMAGE,'the picture is VerityConfig.Image, rbxassetid://102712963740896 (the NPC card\'s)')
check(not W.B.VerityPackArt:find('102712963740896',1,true)and not W.B.VerityCatalog:find('102712963740896',1,true),'(source: the id is written once, in VerityConfig)')
check(VerityArt.CardTransparency>=.9 and VerityArt.CardTransparency<.95,'the card is almost see-through, under the 0.95 "invisible" cut-off of the picture code ('..VerityArt.CardTransparency..')')
check(colorIs(VerityArt.CoatTint.Gold,255,225,150)and colorIs(VerityArt.CoatTint.Diamond,200,235,255)and colorIs(VerityArt.Tint('None'),255,255,255),'coat tints: Gold 255,225,150, Diamond 200,235,255, plain white')
local side1,b1=VerityArt.Side(),Eclipse.Bounds(1)
check(side1>0 and side1<=2*b1.Radius and side1<=b1.MaxY-b1.MinY+1e-9 and near(side1,math.min(2*b1.Radius,b1.MaxY-b1.MinY),.01),('the card is as wide as the Void pack\'s bounds are wide or high, whichever is less (%.3f of %.3f x %.3f)'):format(side1,2*b1.Radius,b1.MaxY-b1.MinY))
check(near(VerityArt.CentreY(),(b1.MaxY+b1.MinY)/2),'and centred in the height of those bounds')
do
 local fx=VerityArt.Fx;local allWarm=true
 for _,k in ipairs({'Haze','Nebula','Stars'})do check(fx[k].Texture:find('sparkles_main')~=nil,'Fx.'..k..': a built-in sparkle texture');for _,c in ipairs(fx[k].Colors)do if not warm(c)then allWarm=false end end end
 check(allWarm and warm(fx.Light),'every effect colour is warm gold / cream, nothing purple')
 check(fx.Debris==nil and fx.Comet==nil and fx.Trail==nil and fx.Fill==nil and fx.Outline==nil,'no debris, comets or outline: the face is not surrounded by pieces')
end
check(near(Rules.GetVariant(VERITY).BagScale,Rules.GetVariant(VOID).BagScale)and Rules.DesignKey(7,VERITY)==Rules.DesignKey(7,VOID),'the Verity record has the Void pack\'s scale and design key')

-- 2. Building: every path ---------------------------------------------------------------------------------------------------------------
local function bagAt(mod,y,stage,variant,size,coat)return mod.Bag(CF(0,y,0),W.workspace,1,nil,stage,variant,1,size,coat or'None')end
local function inside(bag,b,label)
 local root=bag.PrimaryPart.CFrame;local worst=0
 for _,p in ipairs(parts(bag))do
  local frame=root:Inverse()*p.CFrame;local h=p.Size*.5
  for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
   local q=frame*V3(h.X*x,h.Y*y,h.Z*z);local r=math.sqrt(q.X*q.X+q.Z*q.Z)
   worst=math.max(worst,r-b.Radius,q.Y-b.MaxY,b.MinY-q.Y,q.Z-b.MaxZ,b.MinZ-q.Z)
  end end end
 end
 return check(worst<=1e-3,label..': all parts inside Bounds (worst overshoot '..string.format('%.4f',worst)..')')
end
local function decalsOf(inst)local out={};for _,d in ipairs(inst:GetDescendants())do if d:IsA('Decal')then out[#out+1]=d end end;return out end
local voidBags,verityBags={},{}
for _,case in ipairs({{1,'None'},{2.5,'Gold'},{25,'Diamond'},{.5,'None'}})do
 local size,coat=case[1],case[2];local label=('%sx %s'):format(size,coat)
 local void=bagAt(Visuals,10,7,VOID,size,coat);local vr=bagAt(Visuals,10,7,VERITY,size,coat)
 local pr=parts(vr);local rims=coat=='None'and 0 or 4
 check(vr:GetAttribute('BagVariant')==VERITY and vr:GetAttribute('Stage')==7 and vr:GetAttribute('PackRarity')=='Verity'and vr:GetAttribute('PackRank')==7,label..': Verity record attributes (variant, stage 7, tier Verity, rank 7)')
 check(vr:GetAttribute('VerityPack')==true and vr:GetAttribute('SpecialPackDesign89')==true and vr:GetAttribute('CompactPackReady')==true and vr:GetAttribute('EclipsePack')==nil,label..': built by the face-card art (VerityPack, not the reliquary)')
 check(vr:GetAttribute('CompactPackPartCount')==#pr+1,label..': CompactPackPartCount counts every part ('..tostring(vr:GetAttribute('CompactPackPartCount'))..')')
 check(coat=='None'and colorIs(vr:GetAttribute('PaperColor'),255,213,46)or coat~='None'and rgbKey(vr:GetAttribute('PaperColor'))==rgbKey(Rules.PackMutations[coat].Color),label..': PaperColor (the opening paper) is the Verity gold, or the coat\'s')
 -- just the face: a card (and a rim for a coat), nothing else
 check(#pr==1+rims,label..': one card'..(rims>0 and' and four rim bars'or'')..', nothing else ('..#pr..' parts; the Void pack has '..#parts(void)..')')
 local stray=0;for _,p in ipairs(pr)do if p.Name~='VerityCard'and not p.Name:match('^VerityRim%d$')then stray+=1 end end
 for _,d in ipairs(vr:GetDescendants())do if d:IsA('MeshPart')or d.Name=='BottomSeal'or d:GetAttribute('TearIndex')then stray+=1 end end
 check(stray==0,label..': no pouch, seal, tear strips, rings, runes, eye, halo or debris')
 local card=vr:FindFirstChild('VerityCard',true);local scale=vr:GetAttribute('VisualScale')
 if check(card~=nil and card:IsA('Part'),label..': the VerityCard part')then
  check(near(card.Size.X,VerityArt.Side()*scale,1e-6)and near(card.Size.Y,card.Size.X,1e-9),label..(': a square %.3f studs a side'):format(card.Size.X))
  check(near(card.Size.Z,VerityArt.CardDepth*scale,1e-6)and card.Size.Z<card.Size.X*.05,label..': and thin ('..string.format('%.3f',card.Size.Z)..')')
  check(near(card.Transparency,VerityArt.CardTransparency)and card.Transparency<.95,label..': almost see-through, still counted as visible by the picture code')
  check(card.Material.Name=='SmoothPlastic'and card.Reflectance==0 and colorIs(card.Color,255,213,46)and card:GetAttribute('CoatSkip')==true,label..': the coat does not paint the card')
  check((card.CFrame.Position-vr.PrimaryPart.CFrame.Position-V3(0,VerityArt.CentreY()*scale,0)).Magnitude<1e-6,label..': centred on the bounds, over the pack\'s root')
  check(card.CanCollide==false and card.CanQuery==false and card.CanTouch==false and card.Massless and card.Anchored,label..': inert world part, anchored')
  local ds=decalsOf(card);local front,back
  for _,d in ipairs(ds)do if d.Face.Name=='Front'then front=d elseif d.Face.Name=='Back'then back=d end end
  check(#ds==2 and front and back and #decalsOf(vr)==2,label..': exactly two Decals, on the front and the back face')
  local tint=coat=='None'and{255,255,255}or coat=='Gold'and{255,225,150}or{200,235,255}
  for _,d in ipairs({front,back})do
   check(d.Texture==IMAGE and d.Transparency==0 and colorIs(d.Color3,tint[1],tint[2],tint[3]),label..': the '..d.Face.Name..' Decal: the Verity picture'..(coat=='None'and', untinted'or(', tinted for '..coat)))
  end
 end
 for _,p in ipairs(pr)do if p.Name:match('^VerityRim%d$')then
  local c=Rules.PackMutations[coat];check(rgbKey(p.Color)==rgbKey(c.Color)and p.Material==c.Material,label..': '..p.Name..' is painted by the '..coat..' coat')
  check(p.Transparency==(coat=='Diamond'and .10 or 0),label..': '..p.Name..' transparency')
 end end
 local bv,br=Visuals.Bounds(7,VOID,size),Visuals.Bounds(7,VERITY,size)
 check(boundsLine(bv)==boundsLine(br)and br.Radius>0,label..': Visuals.Bounds is the Void pack\'s ('..string.format('R %.3f, Y %.3f..%.3f',br.Radius,br.MinY,br.MaxY)..')')
 inside(vr,br,label);inside(vr,bv,label..' (the Void\'s)')
 check(W.CS:HasTag(vr,'BiomeSeedPackVisual'),label..': tagged BiomeSeedPackVisual (the effects owner finds it)')
 local ids=0;for _,d in ipairs(vr:GetDescendants())do for _,k in ipairs({'TextureID','Texture','Image'})do local v=d._props[k];if type(v)=='string'and v:find('rbxassetid')and v~=IMAGE then ids+=1 end end end
 check(ids==0,label..': no uploaded asset but the picture')
 voidBags[#voidBags+1]=void;verityBags[#verityBags+1]=vr
end
-- Carried: welded to the character, CarryBag, the layout from the same bounds, the opening copy.
local char=R.new('Model');char.Name='Carrier';char.Parent=W.workspace
local torso=R.new('Part');torso.Name='UpperTorso';torso.Size=V3(2,2,1);torso.CFrame=CF(0,5,0);torso.Anchored=false;torso.Parent=char
local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.Size=V3(2,2,1);hrp.CFrame=CF(0,4,0);hrp.Parent=char
local held=Visuals.Bag(CF(0,5,1),char,1,torso,7,VERITY,1,1,'None')
do
 local welded=true;for _,p in ipairs(parts(held))do if p.Anchored or not p:FindFirstChildOfClass('WeldConstraint')then welded=false end end
 check(welded and #parts(held)==1,'held: the card is welded to the carrier')
 local ok,carry=pcall(Visuals.CarryBag,char,7,VERITY,1,1,'None');local okV,carryV=pcall(Visuals.CarryBag,char,7,VOID,1,1,'None')
 check(ok and carry and carry.Name=='CarriedSeed'and carry:GetAttribute('SeedPackCarry')==true and carry:GetAttribute('BagVariant')==VERITY,'CarryBag builds the carried Verity pack: '..tostring(carry))
 check(okV and carryV and carry:GetAttribute('CarryRootOffset')~=nil and ser(carry:GetAttribute('CarryRootOffset'))==ser(carryV:GetAttribute('CarryRootOffset'))and near(carry:GetAttribute('CarryBackZ')or 0,carryV:GetAttribute('CarryBackZ')or 1e9)and near(carry:GetAttribute('CarryDisplayMultiplier'),carryV:GetAttribute('CarryDisplayMultiplier')),'the carry layout (offset, back Z, size) is the Void pack\'s')
 check(carry.PrimaryPart:FindFirstChild('LeftGrip')and carry.PrimaryPart:FindFirstChild('RightGrip'),'both hand grips exist')
 local wcount=0;for _,d in ipairs(carry:GetDescendants())do if d:IsA('WeldConstraint')then wcount+=1 end end
 check(wcount==#parts(carry)+1 and #decalsOf(carry)==2,'the carried card is welded (and the root to the torso); its two Decals came along ('..wcount..' welds)')
 carry:Destroy();carryV:Destroy()
 -- the opening copy (SeedPackClient / PackOpeningFeedback clone the bag): the card and both Decals are there
 local copy=held:Clone();copy.Name='OpeningBag'
 for _,d in ipairs(copy:GetDescendants())do if d:IsA('WeldConstraint')then d:Destroy()elseif d:IsA('BasePart')then d.Anchored=true end end
 local cds=decalsOf(copy)
 check(#cds==2 and cds[1].Texture==IMAGE and cds[2].Texture==IMAGE and copy:FindFirstChild('VerityCard',true)~=nil,'the opening copy keeps the card and its two Decals')
end
-- Inventory / hotbar / Bag pictures (ItemPictures builds exactly Visuals.Bag, into a ViewportFrame) and a viewport preview.
do
 local P=W.module('ItemPictures')
 local tool=F.pack(W,W.workspace,7,VERITY,1,'None','Verity Pack')
 check(P.Key(tool)=='Pack|7|VerityReliquary|None','the picture key for a Verity pack Tool: '..tostring(P.Key(tool)))
 local gui=R.Instance.new('ScreenGui');gui.Name='Pictures';gui.Parent=pg
 local holder=R.new('Frame');holder.Size=R.UDim2.fromOffset(60,60);holder.Parent=gui;holder.AbsoluteSize=R.Vector2.new(60,60);holder.AbsolutePosition=R.Vector2.new(0,0)
 local voidTool=F.pack(W,W.workspace,7,VOID,1,'None','Void Pack');local holder2=R.new('Frame');holder2.Size=R.UDim2.fromOffset(60,60);holder2.Parent=gui;holder2.AbsoluteSize=R.Vector2.new(60,60);holder2.AbsolutePosition=R.Vector2.new(70,0)
 local goldTool=F.pack(W,W.workspace,7,VERITY,1,'Gold','Gold Verity Pack');local holder3=R.new('Frame');holder3.Size=R.UDim2.fromOffset(60,60);holder3.Parent=gui;holder3.AbsoluteSize=R.Vector2.new(60,60);holder3.AbsolutePosition=R.Vector2.new(140,0)
 P.Show(holder,tool,1);P.Show(holder2,voidTool,1);P.Show(holder3,goldTool,1)
 for _=1,160 do W.frames(1)end
 local view,view2,view3=holder:FindFirstChild('ItemViewport'),holder2:FindFirstChild('ItemViewport'),holder3:FindFirstChild('ItemViewport')
 check(view and view2 and view3,'the Verity pack, a Gold Verity pack and a Void pack all get their real 3D picture (hotbar / Bag slot)')
 local card=view and view:FindFirstChild('VerityCard',true)
 check(card~=nil and #decalsOf(view)==2,'the Verity picture holds the card and both Decals (the picture code keeps a part under the 0.95 cut-off)')
 for _,d in ipairs(view and decalsOf(view)or{})do check(d.Texture==IMAGE,'the viewport Decal shows the Verity picture ('..d.Face.Name..')')end
 local model=card and card.Parent;while model and model.Parent~=view do model=model.Parent end
 local center,size=Pic.Bounds(model or view)
 check(card and size.X>=card.Size.X*.99 and size.X<=card.Size.X*1.05 and size.Y>=card.Size.Y*.99 and size.Y<=card.Size.Y*1.06 and size.Z<card.Size.X*.3,'the picture is framed on the card (the bounds the camera aims at are the card\'s, a little turned: '..string.format('%.2f x %.2f x %.2f',size.X,size.Y,size.Z)..')')
 local gv=view3 and view3:FindFirstChild('VerityCard',true)
 check(gv and #decalsOf(view3)==2 and colorIs(decalsOf(view3)[1].Color3,255,225,150),'a Gold pack\'s picture shows the tinted Decals')
 local n2=0;for _,d in ipairs(view2 and view2:GetDescendants()or{})do if d:IsA('BasePart')then n2+=1 end end
 check(n2>100,'(the Void picture is still its 100+ parts: '..n2..')')
 local wm=R.new('WorldModel');local vf=R.new('ViewportFrame');wm.Parent=vf
 local prev=Visuals.Bag(CF(0,0,0),wm,1,nil,7,VERITY,1,1,'None')
 check(prev.Parent==wm and #parts(prev)==1 and #decalsOf(prev)==2,'a viewport preview (WorldModel parent) builds the card and its Decals')
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
 check(Visuals.Bounds(7,VERITY,2)and boundsLine(Visuals.Bounds(7,VERITY,2))==boundsLine(Visuals.Bounds(7,VOID,2)),'(and the Verity bounds are the Void\'s)')
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
 check(cr and cr.Palette==VerityArt.Fx and cr.Spinners==0 and #cr.Pulsers==0 and #cr.Parts==2,'Verity capture: the Verity fx palette; no spin / pulse hints (a card), its root and card')
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
check(W.B.SeedPackRenderer:find("VerityPackArt",1,true)~=nil and W.B.SeedPackVisuals:find("VerityPackArt",1,true)~=nil and W.B.VeiledEventClient81:find("VerityVariant",1,true)~=nil,'(source: renderer, bounds and the effects owner all route the Verity variant)')

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
 local function cardDecals(model)local c=model:FindFirstChild('VerityCard',true);return c,c and decalsOf(c)or{}end
 -- (a) PackOpeningFeedback: clicking the held pack shakes a copy and hides the real one
 local sc1=R.new('LocalScript');sc1.Name='PackOpeningFeedback'
 local okA,errA=pcall(W.load,'PackOpeningFeedback',sc1)
 if check(okA,'the real PackOpeningFeedback loads on the mock: '..tostring(errA))then
  local tool=F.tool(W,'Verity Pack',{SeedPackTool=true,SeedInventoryId='v1',BagVariant=VERITY,Stage=7},nil);tool.Activated=R.signal();tool.Parent=me
  local carry=Visuals.CarryBag(me,7,VERITY,1,1,'None');zero(carry)
  binds.ChestChasePackPresentation();tool.Activated:Fire();binds.ChestChasePackPresentation()
  local copy=W.workspace:FindFirstChild('_LocalClickingPack')
  local card,ds=cardDecals(carry)
  check(copy~=nil and copy:FindFirstChild('VerityCard',true)~=nil and #decalsOf(copy)==2,'clicking the held Verity pack makes the shaking copy with the card and both Decals')
  check(card and card.LocalTransparencyModifier==1 and #ds==2 and ds[1].LocalTransparencyModifier==1 and ds[2].LocalTransparencyModifier==1,'and hides the real pack: the card and both of its Decals')
  local shown=true;for _,d in ipairs(copy and decalsOf(copy)or{})do if(d.LocalTransparencyModifier or 0)~=0 then shown=false end end
  check(shown,'while the copy\'s Decals stay shown')
  tool.Parent=nil;binds.ChestChasePackPresentation()
  check(W.workspace:FindFirstChild('_LocalClickingPack')==nil and card.LocalTransparencyModifier==0 and ds[1].LocalTransparencyModifier==0 and ds[2].LocalTransparencyModifier==0,'putting the pack away drops the copy and shows the real card and Decals again')
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
  check(copy~=nil and copy:FindFirstChild('VerityCard',true)~=nil and #cds==2,'the tear works on a copy of the Verity pack: the card and both Decals')
  check(card.LocalTransparencyModifier==1 and ds[1].LocalTransparencyModifier==1 and ds[2].LocalTransparencyModifier==1,'the real pack (card and both Decals) is hidden while the copy plays')
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

-- 6. The Index --------------------------------------------------------------------------------------------------------------------------
local catalog=R.new('Folder');catalog.Name='SeedCatalog';catalog.Parent=remotes
local req=R.new('RemoteFunction');req.Name='PremiumRequest';req.Parent=remotes
local calls={};function req.InvokeServer(_,action,value)calls[#calls+1]={action,value};return {Success=true,Message='Claimed!'}end
local config={SeedCatalogByStage=Rules.BuildSeedCatalog()}
local stageSeeds={}
for stage,defs in ipairs(config.SeedCatalogByStage)do for index,seed in ipairs(defs)do
 if not Rules.IsRetired(seed.Id)then
  local entry=R.new('Folder');entry.Name=seed.Id;entry:SetAttribute('SeedId',seed.Id);entry:SetAttribute('DisplayName',seed.Name)
  local rarity=Rules.GetRarity(seed.Id);entry:SetAttribute('Rarity',rarity)
  local at=Rules.ObtainableStage(seed.Id)or stage;entry:SetAttribute('BaseChance',Rules.SeedOdds(config,at,'Pack01',1)[seed.Id])
  entry:SetAttribute('Stage',at);entry:SetAttribute('SeedIndex',index);entry.Parent=catalog;stageSeeds[at]=(stageSeeds[at]or 0)+1
 end
end end
check(stageSeeds[9]==1 and stageSeeds[8]and stageSeeds[8]>=1,'(the catalog fixture: one seed in stage 9, Mech seeds in stage 8)')
local seedsFolder=R.new('Folder');seedsFolder.Name='DiscoveredSeeds';seedsFolder.Parent=player
local plantsFolder=R.new('Folder');plantsFolder.Name='DiscoveredPlants';plantsFolder.Parent=player
local function found(folder,id)local v=R.new('BoolValue');v.Name=id;v.Value=true;v.Parent=folder end
for _,id in ipairs({'SunflowerSeed','BluebellSeed','AppleSeed'})do found(seedsFolder,id)end
for _,id in ipairs({'SunflowerSeed'})do found(plantsFolder,id)end
-- Layout emulation (absolute rects from UDim2 + AnchorPoint + UISizeConstraint, as the R113 inventory test).
local function set(o,k,v)local c=o._props[k];if not c or c.X~=v.X or c.Y~=v.Y then o[k]=v end end
local function lay(o,px,py,pw,ph)
 for _,c in ipairs(o._children)do if c:IsA('GuiObject')then
  local s,p=c._props.Size,c._props.Position;local a=c._props.AnchorPoint or R.Vector2.new(0,0)
  if s and p then
   local w=s.X.Scale*pw+s.X.Offset;local h=s.Y.Scale*ph+s.Y.Offset
   local lim=c:FindFirstChildOfClass('UISizeConstraint');if lim and lim.MaxSize then w=math.min(w,lim.MaxSize.X);h=math.min(h,lim.MaxSize.Y)end
   local x=px+p.X.Scale*pw+p.X.Offset-a.X*w;local y=py+p.Y.Scale*ph+p.Y.Offset-a.Y*h
   set(c,'AbsoluteSize',R.Vector2.new(w,h));set(c,'AbsolutePosition',R.Vector2.new(x,y))
   lay(c,x,y,w,h)
  end
 end end
end
local screen=R.Vector2.new(1280,720)
local function frames(n)
 for _=1,n do
  for _,g in ipairs(pg:GetChildren())do if g:IsA('ScreenGui')and g.Name=='ChestIndexGui'then if g.AbsoluteSize~=screen then g.AbsoluteSize=screen end;lay(g,0,0,screen.X,screen.Y)end end
  W.frames(1)
 end
end
local function resize(w,h)screen=R.Vector2.new(w,h);frames(4)end
local STAGES={1,6,2,3,5,4,7,8}
local NAMES={[1]='FOREST',[6]='JUNGLE',[2]='DESERT',[3]='SNOW',[5]='CRYSTAL',[4]='LAVA',[7]='STORM',[8]='MECH',[9]='VERITY'}
local function loadIndex(name)
 local s=R.new('LocalScript');s.Name='ChestIndex';W.load(name,s);frames(5);pg:SetAttribute('SeedMenu',nil);frames(2);pg:SetAttribute('SeedMenu','Index');frames(20)
 local gui=pg:FindFirstChild('ChestIndexGui');return gui
end
local function tabOf(gui,stage)return gui:FindFirstChild('Biome'..stage,true)end
-- A snapshot of everything a tab (or the open panel) shows; the base and the new script are compared on it.
local function tabSnap(gui,stage)
 local b=tabOf(gui,stage);if not b then return'(none)'end
 local out={ser(b.Size),ser(b.LayoutOrder),rgbKey(b.BackgroundColor3),tostring(b:GetAttribute('BiomeName')),b.BrightOutline and ser(b.BrightOutline.Thickness)..rgbKey(b.BrightOutline.Color)or'-'}
 for _,c in ipairs(b:GetChildren())do out[#out+1]=c._class..':'..c.Name..':'..(c._props.Size and ser(c._props.Size)or'')..':'..(c._props.Position and ser(c._props.Position)or'')..':'..tostring(c._props.Text or'')..':'..tostring(c._props.Visible)end
 return table.concat(out,'|')
end
local function panelSnap(gui)
 local out={}
 for _,n in ipairs({'Progress','CompletionBar','Fill','MiddleGem','GemReward','SeedCards','Header','Title','BiomeProgress'})do
  local o=gui:FindFirstChild(n,true);out[#out+1]=n..'='..(o and(ser(o._props.Size)..'|'..ser(o._props.Position)..'|'..tostring(o._props.Text or'')..'|'..tostring(o._props.Visible)..'|'..ser(o._attrs))or'-')
 end
 local cards={};local list=gui:FindFirstChild('SeedCards',true)
 for _,c in ipairs(list:GetChildren())do if c:IsA('TextButton')then cards[#cards+1]=c.Name..':'..c.LayoutOrder end end;table.sort(cards)
 out[#out+1]='cards='..table.concat(cards,',')
 return table.concat(out,'\n')
end
local SIZES={{360,640},{390,844},{412,915},{640,360},{768,1024},{1024,768},{1280,720},{1366,768},{1920,1080}}
local function record(gui)
 local snap={tabs={},panel={}}
 for _,sz in ipairs(SIZES)do
  resize(sz[1],sz[2]);local k=sz[1]..'x'..sz[2];snap.tabs[k]={}
  for _,stage in ipairs({1,6,2,3,5,4,7,8})do
   tabOf(gui,stage).Activated:Fire();frames(4)
   snap.tabs[k][stage]=tabSnap(gui,stage);snap.panel[k..':'..stage]=panelSnap(gui)
  end
  for _,stage in ipairs({1,6,2,3,5,4,7,8})do snap.tabs[k][stage]=tabSnap(gui,stage)end
 end
 return snap
end
resize(1280,720)
local oldGui=loadIndex('ChestIndexBase')
check(oldGui and oldGui:FindFirstChild('Biome8',true)~=nil and tabOf(oldGui,9)~=nil,'(the base Index script already has the VERITY tab: this release leaves the Index as it was)')
local oldTotal=oldGui:FindFirstChild('TotalFound',true).Count.Text:gsub('%s+',' ')
local before=record(oldGui)
local gui=loadIndex('ChestIndex')
check(gui~=oldGui and gui and gui.Parent==pg,'the new Index loads (and replaces the old gui)')
resize(1280,720)
local tabs=gui:FindFirstChild('BiomeProgress',true);local layout=tabs:FindFirstChildOfClass('UIListLayout')
-- 6a. nine tabs in the right order, VERITY last
local list={};for _,c in ipairs(tabs:GetChildren())do if c:IsA('TextButton')then list[#list+1]=c end end
table.sort(list,function(a,b)return a.LayoutOrder<b.LayoutOrder end)
local order={};local biomeNames={};for _,b in ipairs(list)do order[#order+1]=b.Name;biomeNames[#biomeNames+1]=b:GetAttribute('BiomeName')end
check(#list==9,'nine tabs ('..#list..')')
check(table.concat(biomeNames,',')=='FOREST,JUNGLE,DESERT,SNOW,CRYSTAL,LAVA,STORM,MECH,VERITY','the order: Forest, Jungle, Desert, Snow, Crystal, Lava, Storm, Mech, VERITY last ('..table.concat(biomeNames,',')..')')
check(table.concat(order,',')=='Biome1,Biome6,Biome2,Biome3,Biome5,Biome4,Biome7,Biome8,Biome9','tabs are Biome<stage>: stage 9 is the VERITY tab')
local layoutOk=true;for i,b in ipairs(list)do if b.LayoutOrder~=i then layoutOk=false end end;check(layoutOk,'LayoutOrder 1..9 in a row')
check(layout and layout.FillDirection.Name=='Horizontal'and layout.SortOrder.Name=='LayoutOrder'and layout.Padding.Offset==8,'the row is one horizontal UIListLayout in LayoutOrder, 8 px apart')
check(tabs:IsA('ScrollingFrame')and tabs.ScrollingDirection.Name=='X'and tabs.AutomaticCanvasSize.Name=='X','the row scrolls sideways with an automatic canvas (the way all nine stay reachable)')
local src=W.B.ChestIndex
local _,loops=src:gsub('for stage=1,9 do','');local _,old=src:gsub('for stage=1,8 do','')
check(loops==2 and old==0,'both stage loops (alert dots, reward attribute listeners) run to 9')
check(src:find("{8,'MECH'},{9,'VERITY'}}",1,true)~=nil,'(source: {9,\'VERITY\'} follows {8,\'MECH\'})')
check(src:find('Bright.Card(card,Theme.Rarity(rarity).Accent,selected==8,rarity)',1,true)~=nil,'cards keep their rarity border call')
-- 6b. the VERITY tab: gold, its own icon
local vt=tabOf(gui,9);local logo=vt and vt:FindFirstChild('BiomeLogo')
check(vt and logo and logo._class=='Frame','the VERITY tab has a BiomeLogo (a drawn icon, no raster)')
local ball=logo and logo:FindFirstChild('Ball')
check(ball and colorIs(ball.BackgroundColor3,255,213,46)and logo:FindFirstChild('Gloss')and logo:FindFirstChild('LeafL')and logo:FindFirstChild('LeafR'),'a gold ball with a gloss and leaves, from the Verity palette')
local anyArt=false;for _,d in ipairs(vt:GetDescendants())do if d.Name:find('^Generated')and d.Name~='GeneratedVerity'then anyArt=true end end;check(not anyArt,'(no BiomeArtwork raster on it)')
local function colorOfTab(stage)return rgbKey(tabOf(gui,stage).BackgroundColor3)end
-- 6c. selecting tabs: colours and rings
tabOf(gui,1).Activated:Fire();frames(4)
check(colorOfTab(1)=='80,149,194'and colorOfTab(8)=='73,109,204'and colorOfTab(9)=='222,160,20','Forest open (blue), Mech idle (blue), VERITY idle: a darker gold')
vt.Activated:Fire();frames(4)
check(colorOfTab(9)=='255,214,84'and colorOfTab(1)=='73,109,204','VERITY open: a bright gold, Forest back to blue')
local ring=vt.BrightOutline;check(ring and ring.Thickness==3 and colorIs(ring.Color,255,255,255)and tabOf(gui,1).BrightOutline.Thickness==2,'the open tab is ringed in white, also VERITY')
-- 6d. its card, progress and rewards
local listFrame=gui:FindFirstChild('SeedCards',true);local cards={};for _,c in ipairs(listFrame:GetChildren())do if c:IsA('TextButton')then cards[#cards+1]=c end end
check(#cards==1 and cards[1].Name=='VeritySeed','the VERITY tab lists exactly the Verity seed ('..#cards..' card'..(cards[1]and(': '..cards[1].Name)or'')..')')
local card=cards[1]
local rarity=card:FindFirstChild('RarityChip')and card.RarityChip:FindFirstChild('Rarity');local odds=card:FindFirstChild('OddsChip')and card.OddsChip:FindFirstChild('Odds')
check(rarity and rarity.Text=='KING','the card shows the KING chip')
check(odds and odds.Text==W.module('OddsText85').Format(Rules.SeedOdds(config,9,'Pack01',1).VeritySeed)and odds.Text=='1/100','and 1/100 (the Verity pack\'s 1%): '..tostring(odds and odds.Text))
check(card.Name=='VeritySeed'and card:FindFirstChild('Name').Text=='???'and card:FindFirstChild('Preview'),'an unknown seed shows ??? and its model viewport')
local function progressText()return(gui:FindFirstChild('Progress',true).Text:gsub('%s+',' '))end
check(progressText()=='0/1 SEEDS • 0/1 PLANTS','progress: 0/1 SEEDS • 0/1 PLANTS ('..progressText()..')')
check(vt.Count.Text=='0 / 2','the tab counts 0 / 2 ('..vt.Count.Text..')')
local Tuning=W.module('BalanceValues81')
local mid=gui:FindFirstChild('MiddleGem',true);local bonus=gui:FindFirstChild('GemReward',true)
check(mid:GetAttribute('RewardGems')==Tuning.HalfwayGems and Tuning.HalfwayGems==10 and mid.RewardAmount.Text=='+10','the halfway reward is BalanceValues81.HalfwayGems = 10 ('..tostring(mid:GetAttribute('RewardGems'))..')')
check(bonus:GetAttribute('RewardGems')==Tuning.CompletionGems[9]and Tuning.CompletionGems[9]==100 and bonus.RewardAmount.Text=='+100','the completion reward is BalanceValues81.CompletionGems[9] = 100 ('..tostring(bonus:GetAttribute('RewardGems'))..')')
check(not mid.Active and not bonus.Active,'neither is claimable yet')
check(not src:find('%f[%d]100%f[%D]')and src:find('tuning.CompletionGems[selected]',1,true)and src:find('tuning.HalfwayGems',1,true),'(source: the Index script hard-codes neither reward: it reads BalanceValues81 for the selected category)')
local wasTotal=gui:FindFirstChild('TotalFound',true).Count.Text:gsub('%s+',' ')
check(wasTotal==oldTotal and wasTotal:find('/ 104'),'FOUND counts the Verity seed and its plant too, as in the base ('..oldTotal..' -> '..wasTotal..')')
-- find the seed: halfway (seed + plant = 2 of 2 half is >= 1 of 1 total)
found(seedsFolder,'VeritySeed');frames(6)
card=listFrame:FindFirstChild('VeritySeed')
check(card:FindFirstChild('Name').Text=='Verity Seed'and vt.Count.Text=='1 / 2'and progressText()=='1/1 SEEDS • 0/1 PLANTS','finding the seed: its name, 1 / 2, 1/1 SEEDS')
check(mid.Active==true and mid:GetAttribute('RewardReady')==true and bonus.Active==false,'one of two is the halfway point: the halfway gem lights up')
local dot=vt:FindFirstChild('RewardDot');check(dot and dot.Visible==true,'a reward dot on the VERITY tab')
local badge=pg:FindFirstChild('RewardBadge',true) -- (HudLayout moves the INDEX button into the navigation wheel)
check(badge and badge.Visible and tonumber(badge.Count.Text)and tonumber(badge.Count.Text)>=1,'and on the INDEX button')
mid.Activated:Fire();frames(4)
check(calls[#calls]and calls[#calls][1]=='ClaimBiomeHalf'and calls[#calls][2]==9,'clicking it claims the halfway reward for category 9')
found(plantsFolder,'VeritySeed');frames(6)
check(vt.Count.Text=='2 / 2'and bonus.Active==true and bonus:GetAttribute('RewardReady')==true,'seed and plant found: the completion gem lights up')
bonus.Activated:Fire();frames(4)
check(calls[#calls][1]=='ClaimBiome'and calls[#calls][2]==9,'clicking it claims the completion reward for category 9')
check(listFrame:FindFirstChild('VeritySeed'):FindFirstChild('Reward').Text:find('COMPLETE')~=nil,'the card says COMPLETE')
-- Server attributes (IndexBiomeReward9 ...) are listened to.
player:SetAttribute('IndexBiomeBackpay9',100);frames(6);check(bonus:GetAttribute('RewardGems')==100,'backpay on category 9 is shown through the same attribute listeners')
player:SetAttribute('IndexBiomeBackpay9',nil);frames(3)
-- 6e. screens
-- GiantVisualSafety: a giant pack's surfaces fade near the camera; a Decal (the Verity picture) ignores its part's modifier, so it is
-- faded the same way, and a Decal an opening hid (modifier 1) stays hidden.
do
 local gb={};local oldB,oldU=W.Run.BindToRenderStep,W.Run.UnbindFromRenderStep
 W.Run.BindToRenderStep=function(_,name,_,fn)gb[name]=fn end;W.Run.UnbindFromRenderStep=function(_,name)gb[name]=nil end
 local cam=W.workspace.CurrentCamera;cam.CFrame=CF(0,10,0)
 local p=R.new('Part');p.Name='VerityCard';p.Size=V3(40,40,.4);p.CFrame=CF(0,10,4);p.LocalTransparencyModifier=0;p.Parent=W.workspace
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
print(('Verity pack: a %.2f-stud card with 2 Decals (the Void pack has %d parts); effects compared at 3 tiers'):format(VerityArt.Side(),#voidSpecs))
print('tab row (strip width / canvas width) by screen:')
local NOTE={}
for _,sz in ipairs(SIZES)do
 local w,h=sz[1],sz[2];resize(w,h);tabOf(gui,1).Activated:Fire();frames(3)
 local panel=gui:FindFirstChild('IndexPanel');local strip=tabs.AbsoluteSize
 local buttons={};for _,b in ipairs(tabs:GetChildren())do if b:IsA('TextButton')then buttons[#buttons+1]=b end end
 table.sort(buttons,function(a,b)return a.LayoutOrder<b.LayoutOrder end)
 local x=0;local overlap=false;local sameSize=true;local fitsHeight=true;local contentOk=true;local prevRight=-1e9
 local pad=layout.Padding.Offset
 for i,b in ipairs(buttons)do
  local bw,bh=b.Size.X.Offset,b.Size.Y.Offset
  if x<prevRight+pad-1e-9 and i>1 then overlap=true end
  prevRight=x+bw
  if bw~=buttons[1].Size.X.Offset or bh~=buttons[1].Size.Y.Offset then sameSize=false end
  if bh+tabs.ScrollBarThickness>strip.Y+1e-9 then fitsHeight=false end
  local lg,cnt=b:FindFirstChild('BiomeLogo'),b:FindFirstChild('Count')
  local lx,lw,lh=lg.Position.X.Offset,lg.Size.X.Offset,lg.Size.Y.Offset;local cx=cnt.Position.X.Offset;local cwidth=bw+cnt.Size.X.Offset -- (Size = scale 1 + offset)
  if lx+lw>cx+1e-9 or cx+cwidth>bw+1e-9 or cwidth<20 or lg.Position.Y.Offset+lh>bh+1e-9 then contentOk=false;print('  logo / count collide: '..b.Name)end
  local textW=utf8.len(cnt.Text)*cnt.TextSize*.52;if textW>cwidth+1e-9 then contentOk=false;print('  count text too wide: '..b.Name..' '..cnt.Text)end
  x=x+bw+pad
 end
 local canvas=x-pad
 local panelW=math.min(980,w*.94)
 check(#buttons==9 and not overlap and sameSize,('%dx%d: nine equal tabs, none overlapping (8 px gaps)'):format(w,h))
 check(fitsHeight and contentOk,('%dx%d: every tab fits its row (%dpx high strip) and its icon / count do not collide'):format(w,h,strip.Y))
 check(near(strip.X,panelW-24,1),('%dx%d: the strip is the panel width - 24 (%.0f)'):format(w,h,strip.X))
 local needs=canvas>strip.X
 check(not needs or(tabs.ScrollingDirection.Name=='X'and tabs.AutomaticCanvasSize.Name=='X'),('%dx%d: canvas %.0f vs strip %.0f: %s'):format(w,h,canvas,strip.X,needs and'scrolls sideways to reach VERITY'or'fits without scrolling'))
 print(('  %4dx%-4d strip %4.0f  canvas %4.0f  %s'):format(w,h,strip.X,canvas,needs and'scrolls'or'fits'))
 -- the reward gems and card list stay below the row on this screen
 local listA=listFrame.AbsolutePosition.Y;check(listA>=tabs.AbsolutePosition.Y+tabs.AbsoluteSize.Y,('%dx%d: the cards start below the tab row'):format(w,h))
end
-- 6f. existing tabs unchanged against the base commit's script
local after=record(gui)
local sameTabs,samePanels,compared=true,true,0
for _,sz in ipairs(SIZES)do
 local k=sz[1]..'x'..sz[2]
 for _,stage in ipairs({1,6,2,3,5,4,7,8})do
  local a,b=before.tabs[k][stage],after.tabs[k][stage]
  if a~=b then sameTabs=false;print('  tab '..stage..' at '..k..' differs:\n   '..a..'\n   '..b)end
  local pa,pb=before.panel[k..':'..stage],after.panel[k..':'..stage]
  if pa~=pb then samePanels=false;print('  panel for stage '..stage..' at '..k..' differs:\n   '..pa:gsub('\n','\n   ')..'\n  vs\n   '..pb:gsub('\n','\n   '))end
  compared+=1
 end
end
check(sameTabs,'tabs 1..8 (the ones whose state the test does not change): size, colour, ring, icon, count and children identical to the base script on every screen ('..compared..' tab states)')
check(samePanels,'the open panel for each of the eight (progress, bar, rewards, cards, header) identical to the base script')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
