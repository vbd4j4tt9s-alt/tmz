--!nocheck
-- R147 (owner: Verity gives a "Verity pack" for a Void pack, and the Verity seed has its own Index category): the CLIENT half on the
-- Roblox mock with the real SeedPackVisuals / SeedPackRenderer / EclipsePackArt / VerityPackArt / VoidPackFx / ItemPictures /
-- VeiledEventClient81 / SeedPackRender / ChestIndex of this checkout. The comparison "before" modules are the base commit's
-- (git show BASE:..., loaded as SeedPackVisualsBase / SeedPackRendererBase / EclipsePackArtBase / VoidPackFxBase / ChestIndexBase).
--  1. the Verity pack art: EclipsePackArt's parts in a gold / white palette (no purple, body 255,213,46), sized like the Void pack
--     (parts, bounds, extents, carry layout), on every path: world, dropped, carried, CarryBag, opening copy, inventory picture,
--     viewport; coats; a base record fell through to a plain Storm pack;
--  2. the Void pack, the Mech pack and the ordinary packs build part for part what the base commit built (and bound the same);
--  3. VoidPackFx: Void effects identical to the base's; Verity effects gold sparkles (no smoke, nothing purple), same budgets; the
--     real VeiledEventClient81 loop gives a carried Verity pack its own gold effects; SeedPackRender leaves it alone like the Void;
--  4. the Index: nine tabs, VERITY last and gold, its card, progress, the halfway / completion rewards from BalanceValues81, alerts,
--     tabs fitting and not overlapping from a 360 px phone to 1920x1080, and the existing tabs unchanged against the base's script.
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

-- 1. The palette art, spec by spec ------------------------------------------------------------------------------------------------------
local voidSpecs,baseSpecs,paintedSpecs=Eclipse.Specs(),EclipseBase.Specs(),VerityArt.Specs()
check(#voidSpecs==#baseSpecs and #voidSpecs==#paintedSpecs and #voidSpecs>100,'the Verity art has the Void art\'s parts ('..#paintedSpecs..')')
do
 local same,why=true,nil
 for i,s in ipairs(voidSpecs)do
  local b=baseSpecs[i];local line=function(x)return table.concat({x.Name,ser(x.Size),ser(x.Frame),rgbKey(x.Color),x.Material.Name,tostring(x.Shape and x.Shape.Name),ser(x.Transparency),ser(x.Spin),ser(x.Pivot),ser(x.Pulse),ser(x.Phase)},'|')end
  if line(s)~=line(b)then same=false;why=line(s)..' vs '..line(b);break end
 end
 check(same,'EclipsePackArt.Specs() (the Void palette) is the base commit\'s, spec for spec'..(why and(': '..why)or''))
 local pal=true;for k,v in pairs(EclipseBase.Palette)do if rgbKey(Eclipse.Palette[k])~=rgbKey(v)then pal=false end end
 check(pal,'the Void palette values are unchanged')
 check(Eclipse.Specs()==Eclipse.Specs(Eclipse.Palette)and Eclipse.Specs()~=VerityArt.Specs(),'specs are cached per palette (the default one is the Void\'s)')
 check(VerityArt.Specs()==VerityArt.Specs(),'the Verity specs are cached too')
end
do
 -- Same shape: everything but the colour is the Void spec; the colour is the Verity palette entry standing in for the Void one.
 local map,clash={},false
 for k,v in pairs(Eclipse.Palette)do local key=rgbKey(v);if map[key]and map[key]~=rgbKey(VerityArt.Palette[k])then clash=true end;map[key]=rgbKey(VerityArt.Palette[k])end
 check(not clash,'(no two Void palette entries share a colour but not a Verity colour)')
 local geometry,colors=true,true
 for i,s in ipairs(voidSpecs)do
  local p=paintedSpecs[i]
  if s.Name~=p.Name or ser(s.Size)~=ser(p.Size)or ser(s.Frame)~=ser(p.Frame)or s.Material~=p.Material or s.Shape~=p.Shape or ser(s.Transparency)~=ser(p.Transparency)
   or ser(s.Spin)~=ser(p.Spin)or ser(s.Pivot)~=ser(p.Pivot)or ser(s.Pulse)~=ser(p.Pulse)or ser(s.Phase)~=ser(p.Phase)then geometry=false end
  -- exact palette entries map one to one; the gradients (galaxy arms, event horizon) are lerps between Verity palette entries
  local function between(c,keys)
   for _,ch in ipairs({'R','G','B'})do local lo,hi=2,-1;for _,k in ipairs(keys)do local v=VerityArt.Palette[k][ch];lo=math.min(lo,v);hi=math.max(hi,v)end;if c[ch]<lo-1e-6 or c[ch]>hi+1e-6 then return false end end
   return true
  end
  if s.Name:find('^GalaxyArm')then if not between(p.Color,{'ArmInner','ArmMid','ArmOuter'})then colors=false end
  elseif s.Name:find('^EventHorizon')then if not between(p.Color,{'Halo','HaloHot'})then colors=false end
  elseif map[rgbKey(s.Color)]~=rgbKey(p.Color)then colors=false;print('  colour of '..s.Name..': '..rgbKey(s.Color)..' -> '..rgbKey(p.Color)..' expected '..tostring(map[rgbKey(s.Color)]))end
 end
 check(geometry,'the Verity parts are the Void parts: names, sizes, frames, materials, shapes, transparency, spin and pulse hints')
 check(colors,'and only the colours change, each through the palette')
 local missing=0;for k in pairs(Eclipse.Palette)do if VerityArt.Palette[k]==nil then missing+=1 end end
 check(missing==0,'the Verity palette has every key of the Void palette')
 local allWarm,anyBlue=true,false
 for k,v in pairs(VerityArt.Palette)do if not warm(v)then allWarm=false;print('  not warm: '..k)end;local r,_,b=rgb(v);if b>r then anyBlue=true end end
 check(allWarm and not anyBlue,'every Verity palette colour is warm (R >= G >= B): no purple, violet, blue or pink')
 check(colorIs(VerityArt.Palette.Body,255,213,46)and colorIs(Cat.Palette.Ball,255,213,46)and colorIs(Cat.Palette.Gloss,255,252,232),'the body is the Verity gold 255,213,46 (and the catalog\'s Ball / Gloss are as they were)')
 check(colorIs(Cat.Palette.LeafOuter,68,160,72)and colorIs(Cat.Palette.LeafInner,96,188,88),'(the catalog\'s leaf colours are as they were)')
 local cream=0;for _,v in pairs(VerityArt.Palette)do local r,g,b=rgb(v);if r>=250 and g>=240 and b>=190 then cream+=1 end end
 check(cream>=3,'cream / white highlights are used ('..cream..' palette entries)')
 check(VerityArt.Budget==Eclipse.Budget and #paintedSpecs<=VerityArt.Budget.MaxParts,'same part budget (<= '..Eclipse.Budget.MaxParts..')')
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
local voidBags,verityBags={},{}
for _,case in ipairs({{1,'None'},{2.5,'Gold'},{25,'Diamond'},{.5,'None'}})do
 local size,coat=case[1],case[2];local label=('%sx %s'):format(size,coat)
 local void=bagAt(Visuals,10,7,VOID,size,coat);local vr=bagAt(Visuals,10,7,VERITY,size,coat)
 local pv,pr=parts(void),parts(vr)
 check(vr:GetAttribute('BagVariant')==VERITY and vr:GetAttribute('Stage')==7 and vr:GetAttribute('PackRarity')=='Verity'and vr:GetAttribute('PackRank')==7,label..': Verity record attributes (variant, stage 7, tier Verity, rank 7)')
 check(vr:GetAttribute('EclipsePack')==true and vr:GetAttribute('VoidDesignRevision')==122 and vr:GetAttribute('VerityPack')==true and void:GetAttribute('VerityPack')==nil,label..': built by the reliquary art, flagged VerityPack (the Void pack is not)')
 local keysV,keysR={},{};for k in pairs(void:GetAttributes())do keysV[k]=true end;for k in pairs(vr:GetAttributes())do keysR[k]=true end
 local extra,lost={},{};for k in pairs(keysR)do if not keysV[k]then extra[#extra+1]=k end end;for k in pairs(keysV)do if not keysR[k]then lost[#lost+1]=k end end
 check(#extra==1 and extra[1]=='VerityPack'and #lost==0,label..': the same attributes as the Void pack plus VerityPack ('..table.concat(extra,',')..' / lost '..table.concat(lost,',')..')')
 check(#pv==#pr,label..': same part count as the Void pack ('..#pr..')')
 local shape=#pv==#pr;local colorsOk=true;local warmOk=true
 for i=1,math.min(#pv,#pr)do
  local a,b=pv[i],pr[i]
  if a._class~=b._class or a.Name~=b.Name or ser(a.Size)~=ser(b.Size)or ser(a.CFrame)~=ser(b.CFrame)or a.Material~=b.Material and coat=='None'or ser(a.Transparency)~=ser(b.Transparency)then shape=false end
  if coat=='None'then if a:IsA('MeshPart')then colorsOk=colorsOk and colorIs(b.Color,255,213,46)end;warmOk=warmOk and warm(b.Color)
  else colorsOk=colorsOk and rgbKey(a.Color)==rgbKey(b.Color)end
 end
 check(shape,label..': part for part the Void pack\'s shape, size and place')
 if coat=='None'then
  check(colorsOk,label..': the pouch body is gold 255,213,46')
  check(warmOk,label..': every part is warm (no purple / blue anywhere)')
  check(colorIs(vr:GetAttribute('PaperColor'),255,213,46),label..': PaperColor (the opening paper) is the gold')
  local trimOk=true;for _,p in ipairs(vr:GetChildren())do if p.Name=='BottomSeal'or p:GetAttribute('TearIndex')then trimOk=trimOk and colorIs(p.Color,190,124,12)and p.Material.Name=='Metal'end end
  check(trimOk,label..': seal and tear strip in the amber trim')
  local byName={};for _,p in ipairs(pr)do byName[p.Name]=p end
  check(colorIs(byName.VoidSingularityF.Color,112,70,6)and colorIs(byName.PhotonRingF1.Color,255,170,30)and colorIs(byName.PhotonRingF3.Color,255,255,248)and colorIs(byName.VoidPupilF.Color,255,252,232),label..': the dark amber core, the white-hot photon ring and the cream pupil')
 else
  check(colorsOk,label..': the '..coat..' coat covers the whole Verity pack exactly as it does the Void pack')
 end
 local ev,er=extents(void),extents(vr)
 check(near(ev.X,er.X,1e-6)and near(ev.Y,er.Y,1e-6)and near(ev.Z,er.Z,1e-6),label..(': Verity pack is as big as the Void pack (%.2f x %.2f x %.2f)'):format(er.X,er.Y,er.Z))
 check(near(vr:GetAttribute('VisualScale'),void:GetAttribute('VisualScale')),label..': same VisualScale')
 local bv,br=Visuals.Bounds(7,VOID,size),Visuals.Bounds(7,VERITY,size)
 check(boundsLine(bv)==boundsLine(br)and br.Radius>0,label..': Visuals.Bounds is the Void pack\'s ('..string.format('R %.3f, Y %.3f..%.3f',br.Radius,br.MinY,br.MaxY)..')')
 inside(vr,br,label)
 local anchored=true;for _,p in ipairs(pr)do if not p.Anchored then anchored=false end end;check(anchored,label..': world parts anchored (a dropped pack is built the same way)')
 local up=0;for _,d in ipairs(vr:GetDescendants())do for _,k in ipairs({'TextureID','Texture','Image'})do local v=d._props[k];if type(v)=='string'and v:find('rbxassetid')then up+=1 end end end
 check(up==0,label..': no uploaded asset ids')
 check(W.CS:HasTag(vr,'BiomeSeedPackVisual'),label..': tagged BiomeSeedPackVisual (the effects owner finds it)')
 voidBags[#voidBags+1]=void;verityBags[#verityBags+1]=vr
end
-- The base commit had no art for the record: it fell through to an ordinary Storm pack.
do
 local old=bagAt(VisualsBase,10,7,VERITY,1,'None');local void=bagAt(VisualsBase,10,7,VOID,1,'None')
 check(old:GetAttribute('EclipsePack')==nil and #parts(old)<#parts(void)/3,'(before: the base built a plain pouch for a VerityReliquary record: '..#parts(old)..' parts, no reliquary)')
 old:Destroy();void:Destroy()
end
-- Carried: welded to the character, CarryBag, the layout from the same bounds, the opening copy.
local char=R.new('Model');char.Name='Carrier';char.Parent=W.workspace
local torso=R.new('Part');torso.Name='UpperTorso';torso.Size=V3(2,2,1);torso.CFrame=CF(0,5,0);torso.Anchored=false;torso.Parent=char
local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.Size=V3(2,2,1);hrp.CFrame=CF(0,4,0);hrp.Parent=char
local held=Visuals.Bag(CF(0,5,1),char,1,torso,7,VERITY,1,1,'None')
do
 local welded=true;for _,p in ipairs(parts(held))do if p.Anchored or not p:FindFirstChildOfClass('WeldConstraint')then welded=false end end
 check(welded,'held: every part welded to the carrier')
 local voidHeld=Visuals.Bag(CF(0,5,1),char,1,torso,7,VOID,1,1,'None')
 check(#parts(held)==#parts(voidHeld),'held: as many parts as a held Void pack ('..#parts(held)..')')
 voidHeld:Destroy()
 local ok,carry=pcall(Visuals.CarryBag,char,7,VERITY,1,1,'None');local okV,carryV=pcall(Visuals.CarryBag,char,7,VOID,1,1,'None')
 check(ok and carry and carry.Name=='CarriedSeed'and carry:GetAttribute('SeedPackCarry')==true and carry:GetAttribute('BagVariant')==VERITY,'CarryBag builds the carried Verity pack: '..tostring(carry))
 check(okV and carryV and #parts(carry)==#parts(carryV)and carry:GetAttribute('CarryRootOffset')~=nil and ser(carry:GetAttribute('CarryRootOffset'))==ser(carryV:GetAttribute('CarryRootOffset'))and near(carry:GetAttribute('CarryBackZ')or 0,carryV:GetAttribute('CarryBackZ')or 1e9)and near(carry:GetAttribute('CarryDisplayMultiplier'),carryV:GetAttribute('CarryDisplayMultiplier')),'the carry layout (offset, back Z, size) is the Void pack\'s')
 local grips=carry.PrimaryPart:FindFirstChild('LeftGrip')and carry.PrimaryPart:FindFirstChild('RightGrip')
 check(grips,'both hand grips exist')
 local wcount=0;for _,d in ipairs(carry:GetDescendants())do if d:IsA('WeldConstraint')then wcount+=1 end end
 check(wcount==#parts(carry)+1,'every carried part is welded, and the root to the torso ('..wcount..' welds for '..#parts(carry)..' parts)')
 carry:Destroy();carryV:Destroy()
 local copy=held:Clone();copy.Name='OpeningBag'
 for _,d in ipairs(copy:GetDescendants())do if d:IsA('WeldConstraint')then d:Destroy()elseif d:IsA('BasePart')then d.Anchored=true end end
 local names={};for _,p in ipairs(parts(copy))do names[p.Name]=true end;local all=true;for _,s in ipairs(paintedSpecs)do if not names[s.Name]then all=false end end
 check(all,'the opening copy keeps the whole design')
end
-- Inventory / hotbar / Bag pictures (ItemPictures builds exactly Visuals.Bag) and a viewport preview.
do
 local P=W.module('ItemPictures')
 local tool=F.pack(W,W.workspace,7,VERITY,1,'None','Verity Pack')
 check(P.Key(tool)=='Pack|7|VerityReliquary|None','the picture key for a Verity pack Tool: '..tostring(P.Key(tool)))
 local gui=R.Instance.new('ScreenGui');gui.Name='Pictures';gui.Parent=pg
 local holder=R.new('Frame');holder.Size=R.UDim2.fromOffset(60,60);holder.Parent=gui;holder.AbsoluteSize=R.Vector2.new(60,60);holder.AbsolutePosition=R.Vector2.new(0,0)
 local voidTool=F.pack(W,W.workspace,7,VOID,1,'None','Void Pack');local holder2=R.new('Frame');holder2.Size=R.UDim2.fromOffset(60,60);holder2.Parent=gui;holder2.AbsoluteSize=R.Vector2.new(60,60);holder2.AbsolutePosition=R.Vector2.new(70,0)
 P.Show(holder,tool,1);P.Show(holder2,voidTool,1)
 for _=1,120 do W.frames(1)end
 local view=holder:FindFirstChild('ItemViewport');local view2=holder2:FindFirstChild('ItemViewport')
 check(view and view2,'both packs get their real 3D picture (hotbar / Bag slot)')
 local function stats(v)
  local n,goldBody,purple=0,0,0
  for _,d in ipairs(v:GetDescendants())do if d:IsA('BasePart')then n+=1;if d:IsA('MeshPart')and colorIs(d.Color,255,213,46)then goldBody+=1 end;local r,_,b=rgb(d.Color);if b>r then purple+=1 end end end
  return n,goldBody,purple
 end
 local n,gold,purple=stats(view);local n2,_,purple2=stats(view2)
 check(n>100 and gold>=1 and purple==0,('the Verity picture is the gold pack: %d parts, %d gold body parts, %d purple'):format(n,gold,purple))
 check(n==n2 and purple2>0,'(the Void picture has the same parts, in purple: '..purple2..')')
 local wm=R.new('WorldModel');local vf=R.new('ViewportFrame');wm.Parent=vf
 local prev=Visuals.Bag(CF(0,0,0),wm,1,nil,7,VERITY,1,1,'None')
 check(#parts(prev)>#paintedSpecs and prev.Parent==wm,'a viewport preview (WorldModel parent) builds')
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
 check(cr.Palette==VerityArt.Fx and cr.Spinners==cv.Spinners and #cr.Pulsers==#cv.Pulsers and #cr.Parts==#cv.Parts,'Verity capture: the Verity fx palette; the same motion hints (spin / pulse) as the Void pack')
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
 -- Verity: gold sparkles, no void haze.
 local counts={}
 for tier=1,3 do
  local c=PackFx.Capture(verityBag);local fx=PackFx.Create(c,tier);local cvoid=PackFx.Capture(voidBag);local fv=PackFx.Create(cvoid,tier)
  check(#fx.Debris==#fv.Debris and #fx.Comets==#fv.Comets and #fx.Debris==PackFx.Budget.Debris[tier]and #fx.Comets==PackFx.Budget.Comets[tier],'tier '..tier..': the Verity effects stay inside the same budget')
  local sparkles,smoke=0,0
  for _,e in ipairs({fx.Haze,fx.Nebula,fx.Stars})do if e.Texture:find('sparkles_main')then sparkles+=1 end;if e.Texture:find('smoke')then smoke+=1 end end
  check(sparkles==3 and smoke==0,'tier '..tier..': three gold sparkle emitters, no smoke / void haze')
  local okColors=true;local bad=''
  local function seq(cs)if cs.A and cs.A.R then return{cs.A,cs.B}end;return{}end
  for _,e in ipairs({fx.Haze,fx.Nebula,fx.Stars})do for _,col in ipairs(seq(e.Color))do if not warm(col)then okColors=false;bad=e.Name end end end
  for _,d in ipairs(fx.Debris)do if not warm(d.Color)then okColors=false;bad='debris'end end
  for _,cm in ipairs(fx.Comets)do for _,col in ipairs(seq(cm.Trail.Color))do if not warm(col)then okColors=false;bad='trail'end end;if not warm(cm.Part.Color)then okColors=false;bad='comet'end end
  if not warm(fx.Highlight.FillColor)or not warm(fx.Highlight.OutlineColor)or not warm(fx.Light.Color)then okColors=false;bad='highlight / light'end
  check(okColors,'tier '..tier..': every effect colour is warm gold / cream, nothing purple ('..bad..')')
  check(colorIs(fx.Light.Color,255,196,70)and colorIs(fx.Highlight.OutlineColor,255,213,46),'tier '..tier..': a warm gold light and a gold outline')
  check(fx.Folder.Name=='_VoidPackFx122'and fx.Nebula.Texture:match('^rbxasset://textures/')~=nil,'tier '..tier..': same folder name, built-in textures only')
  local list,frames={},{};PackFx.Step(c,10,verityBag.PrimaryPart.CFrame,tier,false,true,list,frames)
  check(fx.Light.Enabled==(tier==3)and fx.Nebula.Enabled==(tier>1)and fx.Stars.Enabled==(tier==3),'tier '..tier..': the same gating as the Void pack (light only at full quality)')
  local a,b={},{};local la,lb={},{}
  PackFx.Step(c,3,verityBag.PrimaryPart.CFrame,tier,true,false,la,a);PackFx.Step(c,7,verityBag.PrimaryPart.CFrame,tier,true,false,lb,b)
  local still=true;for i=1,#a do if a[i].Position~=b[i].Position then still=false end end
  check(still and not fx.Nebula.Enabled,'tier '..tier..': Reduced Motion freezes the orbits, no swirl')
  PackFx.Pulse(c,1.234,false);PackFx.Clear(c);PackFx.Clear(cvoid)
  local restored=true;for _,e in ipairs(c.Pulsers)do if e.Part.Color~=e.Color then restored=false end end
  check(restored and fx.Folder.Parent==nil,'tier '..tier..': clearing removes the effects and restores the colours')
  counts[tier]=#c.Pulsers
 end
 -- the pulse lightens the gold towards white; never towards a hue
 local c=PackFx.Capture(verityBag);PackFx.Pulse(c,.9,false)
 local lighter=true;for _,e in ipairs(c.Pulsers)do local r0,g0,b0=rgb(e.Color);local r1,g1,b1=rgb(e.Part.Color);if r1<r0 or g1<g0 or b1<b0 or not warm(e.Part.Color)and warm(e.Color)then lighter=false end end
 PackFx.Restore(c);check(lighter and #c.Pulsers>0,'the heartbeat glow lightens the gold, never turns it a colour ('..#c.Pulsers..' pulsing parts)')
 local pa,pb={},{};local a,b={},{};PackFx.Pose(c,2,pa,a,true);PackFx.Pose(c,2,pb,b,false)
 local moved=0;for i,p in ipairs(pa)do if p:GetAttribute('VoidSpin')and a[i].Position~=b[i].Position then moved+=1 end end
 check(moved>0,'the Verity halo / galaxy spins near the camera too ('..moved..' parts)')
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
 local gold,violet=0,0
 for _,f in ipairs(folders)do
  local h=f:FindFirstChild('VoidDistortion');if h and h.Adornee==verity and colorIs(h.OutlineColor,255,213,46)then gold+=1 end;if h and h.Adornee==void and colorIs(h.OutlineColor,150,80,230)then violet+=1 end
 end
 check(gold==1 and violet==1,'the Verity pack\'s effects are gold, the Void pack\'s still violet')
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
local STAGES={1,6,2,3,5,4,7,8,9}
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
check(oldGui and oldGui:FindFirstChild('Biome8',true)~=nil and tabOf(oldGui,9)==nil,'(the base Index script has eight tabs and no tab 9)')
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
check(wasTotal==oldTotal:gsub('/ (%d+)',function(n)return'/ '..(tonumber(n)+2)end),'FOUND counts the Verity seed and its plant too ('..oldTotal..' -> '..wasTotal..')')
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
print(('Verity pack: %d parts (Void pack %d); palette %d colours; effects compared at 3 tiers'):format(#paintedSpecs,#voidSpecs,(function()local n=0;for _ in pairs(VerityArt.Palette)do n+=1 end;return n end)()))
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
check(sameTabs,'tabs 1..8: size, colour, ring, icon, count and children identical to the base script on every screen ('..compared..' tab states)')
check(samePanels,'the open panel for each of the eight (progress, bar, rewards, cards, header) identical to the base script')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
