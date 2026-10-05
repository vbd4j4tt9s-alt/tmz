--!nocheck
-- R149 (owner: "regarding verity pack i just need it to be pure yellow and the face plastered nice onto the pack thats the only design
-- needed"; then "make sure the face is not floating on the pack ... make sure its nicely plastered on to the pack"): the Verity pack on the
-- Roblox mock with the real SeedPackVisuals / SeedPackRenderer / VerityPackArt / VoidPackFx / ItemPictures / VeiledEventClient81 /
-- SeedPackRender of this checkout. The design's template (Storm_02) is the REAL one (verity_template.luau): ONE MeshPart whose print is in its
-- vertex colours - which a part's Color only multiplies, so R148's "paint the mesh yellow" showed a black panel; the pack is now plain parts.
--  1. the module: yellow 255,255,0, no dark yellow, no effect set, no mesh / texture / SurfaceGui / emitter / light code, revision 149;
--  2. the layout: a square face block centred on the pack's footprint, the body around it at the same depth (no step), nothing in front
--     of the face, inside the plain pack's Bounds, the pinched ends start on the face plane;
--  3. every context (ground, held, CarryBag, hotbar / Bag picture, ViewportFrame, the real ItemPictures, the opening copy; sizes .5 .. 25;
--     no coat / Gold / Diamond): every visible part pure yellow SmoothPlastic (the seal and tear strips too), nothing but the picture's two
--     Decals (Front, Back, white, on the face block's own surface), the face outermost on each side, the right part counts, welds and tags;
--  4. no effects: the real VeiledEventClient81 loop gives a carried Void pack its fx and the Verity pack none; SeedPackRender leaves it alone;
--  5. every other pack (Void, Mech, the ordinary ones) builds exactly what the base commit's code built.
local W=require('./world');local F=require('./fixtures');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local function rgb(c)return math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)end
local function colorIs(c,r,g,b)local x,y,z=rgb(c);return x==r and y==g and z==b end
local function rgbKey(c)return table.concat({rgb(c)},',')end
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
F.packAssets(W);require('./verity_template')(W)
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=149;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local Cat=W.module('VerityCatalog');local Rules=W.module('SeedPackRules');local Config=W.module('VerityConfig')
local Visuals=W.module('SeedPackVisuals');local VisualsBase=W.module('SeedPackVisualsBase')
local Eclipse=W.module('EclipsePackArt');local EclipseBase=W.module('EclipsePackArtBase')
local VerityArt=W.module('VerityPackArt');local VerityArtBase=W.module('VerityPackArtBase')
local PackFx=W.module('VoidPackFx');local PackFxBase=W.module('VoidPackFxBase')
local VERITY=Cat.Variant;local VOID='EclipseReliquary'
assert(VERITY=='VerityReliquary')
local IMAGE='rbxassetid://102712963740896'
local KEY=Rules.DesignKey(7,VERITY)
assert(KEY=='Storm_02')
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
local function parts(root,except)local out={};for _,p in ipairs(root:GetDescendants())do if p:IsA('BasePart')and p~=except then out[#out+1]=p end end;return out end
local function decalsOf(inst)local out={};for _,d in ipairs(inst:GetDescendants())do if d:IsA('Decal')then out[#out+1]=d end end;return out end
-- the z range / box of a part in the pack's own (root) frame
local function boxIn(rootCF,p)
 local f=rootCF:Inverse()*p.CFrame;local h=p.Size*.5
 local lo,hi=V3(1e9,1e9,1e9),V3(-1e9,-1e9,-1e9)
 for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
  local q=f*V3(h.X*x,h.Y*y,h.Z*z)
  lo=V3(math.min(lo.X,q.X),math.min(lo.Y,q.Y),math.min(lo.Z,q.Z));hi=V3(math.max(hi.X,q.X),math.max(hi.Y,q.Y),math.max(hi.Z,q.Z))
 end end end
 return lo,hi,f
end
local BANNED={MeshPart=1,SpecialMesh=1,SurfaceAppearance=1,SurfaceGui=1,Texture=1,ParticleEmitter=1,PointLight=1,SpotLight=1,SurfaceLight=1,Highlight=1,Beam=1,Trail=1,
 Sparkles=1,Fire=1,Smoke=1,BillboardGui=1,ForceField=1,Explosion=1,ImageLabel=1}
local function boundsLine(b)return ser(b)end

-- 1. The module ----------------------------------------------------------------------------------------------------------------------------
check(VerityArt.Image==IMAGE and Config.Image==IMAGE,'the picture is VerityConfig.Image, rbxassetid://102712963740896 (the NPC card\'s), unaltered')
check(colorIs(VerityArt.Yellow,255,255,0),'yellow is 255,255,0')
check(VerityArt.Dark==nil and VerityArt.Fx==nil and VerityArt.Side==nil and VerityArt.PlateZ==nil and VerityArt.PlateDepth==nil,'no darker yellow, no effect set, no plates any more')
check(VerityArt.Revision==149,'the art revision is 149')
do
 local src=W.B.VerityPackArt;local bad={}
 -- (R151: below buildPouch the module holds the real-pouch build, which uses the standard pack's mesh on purpose; this checks the R149 sachet, the fallback)
 local cut=src:find('local function buildPouch',1,true);if cut then src=src:sub(1,cut-1)end
 for _,word in ipairs({'SurfaceGui','ParticleEmitter','PointLight','Highlight','Sparkles','Beam','Trail',"Instance.new('MeshPart')",'TextureID','SurfaceAppearance','BuildStandard','214,190','Neon','Glass'})do if src:find(word,1,true)then
  -- (the header comment may name the old design: look at the code lines only)
  for line in src:gmatch('[^\n]+')do if not line:match('^%s*%-%-')and line:find(word,1,true)then bad[#bad+1]=word end end
 end end
 check(#bad==0,'(source: the art code names no mesh, texture, SurfaceGui, emitter, light, highlight or darker yellow: '..table.concat(bad,',')..')')
 check(src:find('Instance.new(\'Decal\')',1,true)~=nil and src:find('Enum.NormalId.Front',1,true)~=nil and src:find('Enum.NormalId.Back',1,true)~=nil,'(source: the picture is a Decal on the Front and the Back face)')
end
-- the base commit's art, for the record: it painted the template's MeshPart and stood two plates in front of it
do
 local old=Visuals.Bag and VisualsBase.Bag(CF(0,0,0),nil,1,nil,7,VERITY,1,1,'None')
 local meshes,plates=0,0
 for _,p in ipairs(parts(old,old.PrimaryPart))do if p:IsA('MeshPart')then meshes+=1 end;if p.Name:match('^VerityFace')then plates+=1 end end
 check(meshes==1 and plates==2 and VerityArtBase.Revision==148 and VerityArtBase.Dark~=nil,'(base: R148 painted the one template MeshPart and stood two plates on it; now '..meshes..' mesh, '..plates..' plates)')
 old:Destroy()
end

-- 2. The layout ----------------------------------------------------------------------------------------------------------------------------
local tpl=W.RS.SeedPackMeshAssets:FindFirstChild(KEY):GetChildren()[1]
check(#W.RS.SeedPackMeshAssets:FindFirstChild(KEY):GetChildren()==1 and tpl:IsA('MeshPart')and tpl.TextureID==''and #tpl:GetChildren()==0 and colorIs(tpl.Color,255,255,255),'(the real template: one MeshPart, white, no texture, no SurfaceAppearance - its print is the mesh\'s vertex colours)')
do
 local specs,m=VerityArt.Layout(KEY)
 local byName={};for _,s in ipairs(specs)do byName[s.Name]=s end
 local face=byName.VerityFace
 check(face~=nil and face.Picture==true and near(face.Size.X,face.Size.Y)and near(face.Size.X,m.Face)and near(face.Size.Z,m.Depth),'a square face block, as deep as the body')
 check(near(m.Width,1.97,1e-3)and near(m.Height,2.06,1e-3),('the pack\'s footprint is the template\'s: %.3f x %.3f'):format(m.Width,m.Height))
 check(near(face.Frame.Position.X,0,1e-6)and near(face.Frame.Position.Y,-.01,1e-6)and near(face.Frame.Position.Z,0,1e-6),'the face block is centred on the pouch')
 check(m.Face/m.Width>=.7 and m.Face/m.Height>=.65,('the face is big: %.0f%% of the width, %.0f%% of the height'):format(100*m.Face/m.Width,100*m.Face/m.Height))
 local pics=0;for _,s in ipairs(specs)do if s.Picture then pics+=1 end end;check(pics==1,'only the face block carries the picture')
 -- nothing in front of the face block: every other part's z range inside the face block's (equal at most), both sides
 local frontZ,backZ=-face.Size.Z/2,face.Size.Z/2;local inFront=0;local stepMax=0
 for _,s in ipairs(specs)do if s~=face then
  local h=s.Size*.5;local lo,hi=1e9,-1e9
  for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do local q=s.Frame*V3(h.X*x,h.Y*y,h.Z*z);lo=math.min(lo,q.Z);hi=math.max(hi,q.Z)end end end
  if lo<frontZ-1e-6 or hi>backZ+1e-6 then inFront+=1 end
 end end
 check(inFront==0,'no part of the pack is in front of the face block, front or back ('..inFront..')')
 -- the body is the same depth (no step): top / bottom blocks differ by the hidden recess only; the edges are tangent to the faces
 local top,bottom,left,right=byName.VerityBodyTop,byName.VerityBodyBottom,byName.VerityEdgeLeft,byName.VerityEdgeRight
 check(top and bottom and near(top.Size.Z,face.Size.Z-2*VerityArt.Recess,1e-6)and near(bottom.Size.Z,top.Size.Z,1e-9),'the blocks above and below are the face\'s depth less the hidden recess ('..VerityArt.Recess..')')
 check(near(top.Size.X,face.Size.X)and near(bottom.Size.X,face.Size.X),'(and as wide as the face block)')
 check(top.Frame.Position.Y-top.Size.Y/2<=face.Frame.Position.Y+face.Size.Y/2-VerityArt.Overlap+1e-9 and bottom.Frame.Position.Y+bottom.Size.Y/2>=face.Frame.Position.Y-face.Size.Y/2+VerityArt.Overlap-1e-9,'the blocks overlap the face block (no seam)')
 check(near(top.Frame.Position.Y+top.Size.Y/2,.0+(-.01+1.03),1e-6)and near(bottom.Frame.Position.Y-bottom.Size.Y/2,-.01-1.03,1e-6),'the body spans the pouch\'s whole height')
 check(left and right and left.Shape==R.Enum.PartType.Cylinder and near(left.Size.Y,m.Depth)and near(left.Size.Z,m.Depth)and near(left.Size.X,m.Height)and near(left.Frame.Position.X,-m.Face/2)and near(right.Frame.Position.X,m.Face/2),'two rounded edges: cylinders as deep as the body, standing, centred on the face block\'s sides')
 check(near(left.Frame.Position.X-m.Depth/2,-m.Width/2,1e-6),'(together as wide as the pouch)')
 -- the pinched ends start exactly on the body's outer edge (the face plane) and slope in
 for _,n in ipairs({'VerityTaperTopFront','VerityTaperTopBack','VerityTaperBottomFront','VerityTaperBottomBack'})do
  local s=byName[n];local h=s.Size*.5;local zmin,zmax=1e9,-1e9
  for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do local q=s.Frame*V3(h.X*x,h.Y*y,h.Z*z);zmin=math.min(zmin,q.Z);zmax=math.max(zmax,q.Z)end end end
  local outer=n:find('Front')and zmin or zmax
  check(s~=nil and near(math.abs(outer),m.Depth/2,1e-6),n..': its outer edge is on the face plane ('..string.format('%.5f vs %.5f',math.abs(outer),m.Depth/2)..')')
 end
 -- the template missing: the default pouch (the pack still builds)
 local _,dm=VerityArt.Layout('Missing_99')
 check(near(dm.Width,1.97,1e-3)and near(dm.Height,2.06,1e-3)and dm.Depth>0 and dm.Face>0,'a design without a template falls back to the default pouch')
end

-- 3. Every context -------------------------------------------------------------------------------------------------------------------------
local char=R.new('Model');char.Name='Carrier';char.Parent=W.workspace
local torso=R.new('Part');torso.Name='UpperTorso';torso.Size=V3(2,2,1);torso.CFrame=CF(0,5,0);torso.Anchored=false;torso.Parent=char
local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.Size=V3(2,2,1);hrp.CFrame=CF(0,4,0);hrp.Parent=char
local specs,meta=VerityArt.Layout(KEY)
local EXPECT=#specs+10 -- the face block, the body blocks, the edges, the pinched ends + the ordinary pack's root, seal and 8 tear strips
local contexts=0
-- inspect: one built pack (a Model holding VisualRoot, BottomSeal, 8 tear strips, PackGeometry)
local function inspect(bag,label,size,coat,opts)
 opts=opts or{}
 contexts+=1
 local root=bag.PrimaryPart;local all=parts(bag,root);local scale=bag:GetAttribute('VisualScale')or 1
 local c=Rules.PackMutations[coat]
 check(bag:GetAttribute('BagVariant')==VERITY and bag:GetAttribute('VerityPack')==true and bag:GetAttribute('VerityPackDesign')==149 and bag:GetAttribute('CompactPackReady')==true and bag:GetAttribute('EclipsePack')==nil,label..': a Verity pack (revision 149), an ordinary-pack build')
 check(#all==EXPECT-1 and bag:GetAttribute('CompactPackPartCount')==EXPECT and #parts(bag)==EXPECT,label..': '..#all..' parts + root = CompactPackPartCount '..tostring(bag:GetAttribute('CompactPackPartCount')))
 -- nothing but parts and Decals: no mesh, texture, appearance, gui, emitter, light, highlight, beam
 local banned={};for _,d in ipairs(bag:GetDescendants())do if BANNED[d._class]then banned[#banned+1]=d._class end end
 check(#banned==0,label..': no mesh / texture / SurfaceAppearance / SurfaceGui / emitter / light / highlight / beam anywhere ('..table.concat(banned,',')..')')
 local ids=0;for _,d in ipairs(bag:GetDescendants())do for _,k in ipairs({'TextureID','Texture','Image','MeshId'})do local v=d._props[k];if type(v)=='string'and v~=''and v~=IMAGE then ids+=1 end end end
 check(ids==0,label..': no uploaded asset or texture but the picture')
 -- colour
 local seal,tear=0,0;for _,p in ipairs(bag:GetChildren())do if p.Name=='BottomSeal'then seal+=1 elseif p:GetAttribute('TearIndex')then tear+=1 end end
 check(seal==1 and tear==8,label..': the ordinary seal and 8 tear strips are there (the tear works as on any pack)')
 if coat=='None'then
  local pure=0;local why=''
  for _,p in ipairs(all)do
   if colorIs(p.Color,255,255,0)and p.Material.Name=='SmoothPlastic'and p.Reflectance==0 and p.Transparency==0 then pure+=1 else why=why..' '..p.Name..'('..rgbKey(p.Color)..' '..p.Material.Name..')'end
  end
  check(pure==#all,label..': every part is exactly 255,255,0 SmoothPlastic, opaque - the seal and tear strips too, no darker yellow ('..pure..'/'..#all..why..')')
  check(colorIs(bag:GetAttribute('PaperColor'),255,255,0),label..': PaperColor (the opening paper) is yellow')
 else
  local painted=true;for _,p in ipairs(all)do if rgbKey(p.Color)~=rgbKey(c.Color)or p.Material~=c.Material then painted=false end end
  check(painted,label..': the '..coat..' coat paints the whole pack like any other pack')
  check(rgbKey(bag:GetAttribute('PaperColor'))==rgbKey(c.Color),label..': PaperColor is the coat\'s')
  if coat=='Diamond'then local t=true;for _,p in ipairs(all)do if not near(p.Transparency,.10,1e-6)then t=false end end;check(t,label..': Diamond: .10 transparency on every part, as any pack')end
 end
 -- the picture: Front and Back Decals on the face block's own surface
 local face=bag:FindFirstChild('VerityFace',true)
 local ds=decalsOf(bag)
 if check(face and face:IsA('Part')and face.Parent.Name=='PackGeometry','' ..label..': a VerityFace part')then
  local fd=decalsOf(face)
  local faces={};for _,d in ipairs(fd)do faces[d.Face.Name]=(faces[d.Face.Name]or 0)+1 end
  check(#ds==2 and #fd==2 and faces.Front==1 and faces.Back==1,label..': exactly two Decals, both on the face block: one Front, one Back')
  for _,d in ipairs(ds)do check(d.Texture==IMAGE and d.Transparency==0 and colorIs(d.Color3,255,255,255),label..': the '..d.Face.Name..' Decal is Verity\'s picture, white (untinted), opaque, whatever the coat')end
  local lo,hi,f=boxIn(root.CFrame,face)
  check(near(face.Size.X,meta.Face*scale,1e-6)and near(face.Size.Y,face.Size.X,1e-6)and near(face.Size.Z,meta.Depth*scale,1e-6),label..(': the face block scales with the pack: %.3f studs a side'):format(face.Size.X))
  check(near(f.Position.X,0,1e-6)and near(f.Position.Y,-.01*scale,1e-6)and near(f.Position.Z,0,1e-6),label..': centred on the pack (front -Z, back +Z)')
  -- nothing in front of the picture, front or back; and the body is as deep as the face (no step: not a plate)
  local clear,deepest=true,0
  for _,p in ipairs(all)do if p~=face and not(p.Parent==bag)then
   local plo,phi=boxIn(root.CFrame,p)
   if plo.Z<lo.Z-1e-6*scale or phi.Z>hi.Z+1e-6*scale then clear=false end
  end end
  for _,p in ipairs(bag:GetChildren())do if p:IsA('BasePart')and p~=root then local plo,phi=boxIn(root.CFrame,p);if plo.Z<lo.Z-1e-6*scale or phi.Z>hi.Z+1e-6*scale then clear=false end end end
  check(clear,label..': the face is the outermost surface on both sides: no part (seal, strips included) in front of it')
  local step=0
  for _,n in ipairs({'VerityBodyTop','VerityBodyBottom','VerityEdgeLeft','VerityEdgeRight'})do
   local p=bag:FindFirstChild(n,true);local plo,phi=boxIn(root.CFrame,p)
   step=math.max(step,plo.Z-lo.Z,hi.Z-phi.Z)
  end
  check(step<=VerityArt.Recess*scale+1e-6,label..(': side view: the body beside the face is as deep as the face - a step of at most %.4f studs (the hidden recess)'):format(step))
  local gap=true
  local top,bottom=bag:FindFirstChild('VerityBodyTop',true),bag:FindFirstChild('VerityBodyBottom',true)
  local tlo=boxIn(root.CFrame,top);local _,bhi=boxIn(root.CFrame,bottom)
  if tlo.Y>hi.Y*0+(f.Position.Y+face.Size.Y/2)or bhi.Y<f.Position.Y-face.Size.Y/2 then gap=false end
  check(gap,label..': the body blocks reach the face block (no gap around the face)')
  if opts.giant then check(W.CS:HasTag(face,'GiantVisualPart'),label..': a giant pack\'s face block is a GiantVisualPart (the camera fade reaches the picture)')end
 end
 if size>10 then local tagged=0;for _,p in ipairs(all)do if W.CS:HasTag(p,'GiantVisualPart')then tagged+=1 end end
  check(tagged>=#specs,label..': every part of the pouch is a GiantVisualPart ('..tagged..')')
 end
 -- inside the plain pack's Bounds (carry layout, hold, picture framing are the plain pack's)
 local b=Visuals.Bounds(7,VERITY,size);local worst,worstZ=0,0
 for _,p in ipairs(all)do
  local f=root.CFrame:Inverse()*p.CFrame;local h=p.Size*.5
  for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
   local q=f*V3(h.X*x,h.Y*y,h.Z*z);local r=math.sqrt(q.X*q.X+q.Z*q.Z)
   worst=math.max(worst,r-b.Radius,q.Y-b.MaxY,b.MinY-q.Y);worstZ=math.max(worstZ,q.Z-b.MaxZ,b.MinZ-q.Z)
  end end end
 end
 check(worst<=1e-3 and worstZ<=1e-3,label..': every part is inside the plain pack\'s Bounds (worst overshoot '..string.format('%.4f / z %.4f',worst,worstZ)..')')
 check(boundsLine(b)==boundsLine(Visuals.Bounds(7,'Standard',size)),label..': Bounds are the plain pack\'s')
end
local cases={{1,'None'},{2.5,'Gold'},{25,'Diamond'},{.5,'None'},{10,'None'}}
for _,case in ipairs(cases)do
 local size,coat=case[1],case[2];local base=('%sx %s'):format(size,coat)
 -- on the ground / dropped (anchored world pack), and a hotbar / Bag picture's bag (rotated, unparented: exactly what ItemPictures builds)
 local ground=Visuals.Bag(CF(0,10,0),W.workspace,1,nil,7,VERITY,1,size,coat)
 inspect(ground,'ground '..base,size,coat,{giant=size>10})
 check(ground:GetDescendants()[1]~=nil and W.CS:HasTag(ground,'BiomeSeedPackVisual')and ground.PrimaryPart.Anchored and ground:FindFirstChild('VerityFace',true).Anchored,'ground '..base..': tagged BiomeSeedPackVisual, anchored')
 local pic=Visuals.Bag(R.CFrame.Angles(0,.22,-.025),nil,1,nil,7,VERITY,1,size,coat)
 inspect(pic,'picture '..base,size,coat)
 -- held: welded to a character
 local held=Visuals.Bag(CF(0,5,1),char,1,torso,7,VERITY,1,size,coat)
 inspect(held,'held '..base,size,coat)
 local welded=true;for _,p in ipairs(parts(held,nil))do if p.Anchored or not p:FindFirstChildOfClass('WeldConstraint')then welded=false end end
 check(welded,'held '..base..': every part, the face block and the body included, is welded to the carrier ('..#parts(held)..' parts)')
 -- the opening copy (SeedPackClient / PackOpeningFeedback clone the bag and anchor it)
 local copy=held:Clone();copy.Name='OpeningBag'
 -- (the mock's Clone keeps neither the attributes nor the PrimaryPart of a Model: put them back, as Roblox's Clone would have them)
 for k,v in pairs(held:GetAttributes())do copy:SetAttribute(k,v)end
 do local a,b=held:GetDescendants(),copy:GetDescendants();for i,d in ipairs(a)do for k,v in pairs(d:GetAttributes())do b[i]:SetAttribute(k,v)end end end
 for _,d in ipairs(copy:GetDescendants())do if d:IsA('WeldConstraint')then d:Destroy()elseif d:IsA('BasePart')then d.Anchored=true end end
 copy.PrimaryPart=copy:FindFirstChild('VisualRoot')
 inspect(copy,'opening copy '..base,size,coat)
 for _,b in ipairs({ground,pic,held,copy})do b:Destroy()end
end
-- CarryBag (the layout from the same bounds as an ordinary pack's)
for _,size in ipairs({1,25})do
 local ok,carry=pcall(Visuals.CarryBag,char,7,VERITY,1,size,'None');local okS,carryS=pcall(Visuals.CarryBag,char,7,'Standard',1,size,'None')
 if check(ok and carry and okS and carryS,'CarryBag builds a Verity pack at size '..size..': '..tostring(carry))then
  inspect(carry,'CarryBag '..size..'x',size,'None')
  check(carry.Name=='CarriedSeed'and carry:GetAttribute('SeedPackCarry')==true and carry.PrimaryPart:FindFirstChild('LeftGrip')and carry.PrimaryPart:FindFirstChild('RightGrip'),'CarryBag '..size..'x: a carried seed pack with both hand grips')
  check(ser(carry:GetAttribute('CarryRootOffset'))==ser(carryS:GetAttribute('CarryRootOffset'))and near(carry:GetAttribute('CarryBackZ')or 0,carryS:GetAttribute('CarryBackZ')or 1e9)and near(carry:GetAttribute('CarryDisplayMultiplier'),carryS:GetAttribute('CarryDisplayMultiplier')),'CarryBag '..size..'x: the carry layout (offset, back Z, size) is the plain pack\'s')
  carry:Destroy();carryS:Destroy()
 end
end
-- A viewport preview (a WorldModel parent) and the real ItemPictures (the hotbar / Bag picture of a Verity pack, a Gold one, a plain one).
do
 local wm=R.new('WorldModel');local vf=R.new('ViewportFrame');wm.Parent=vf
 local prev=Visuals.Bag(CF(0,0,0),wm,1,nil,7,VERITY,1,1,'None')
 inspect(prev,'ViewportFrame WorldModel',1,'None')
 check(prev.Parent==wm,'(the preview is parented under the WorldModel)')
 local P=W.module('ItemPictures')
 local tool=F.pack(W,W.workspace,7,VERITY,1,'None','Verity Pack');local goldTool=F.pack(W,W.workspace,7,VERITY,1,'Gold','Gold Verity Pack')
 local stdTool=F.pack(W,W.workspace,7,'Standard',1,'None','Standard Pack')
 check(P.Key(tool)=='Pack|7|VerityReliquary|None'and P.Key(goldTool)=='Pack|7|VerityReliquary|Gold','the picture keys (stage, variant, coat): a pack picture is built once per session from the live art, never saved')
 local gui=R.Instance.new('ScreenGui');gui.Name='Pictures';gui.Parent=pg
 local function holderAt(x)local h=R.new('Frame');h.Size=R.UDim2.fromOffset(60,60);h.Parent=gui;h.AbsoluteSize=R.Vector2.new(60,60);h.AbsolutePosition=R.Vector2.new(x,0);return h end
 local h1,h2,h3=holderAt(0),holderAt(70),holderAt(140)
 P.Show(h1,tool,1);P.Show(h2,goldTool,1);P.Show(h3,stdTool,1)
 for _=1,200 do W.frames(1)end
 local v1,v2,v3=h1:FindFirstChild('ItemViewport'),h2:FindFirstChild('ItemViewport'),h3:FindFirstChild('ItemViewport')
 if check(v1 and v2 and v3,'the Verity pack, a Gold Verity pack and a plain pack all get their real 3D picture (hotbar / Bag slot)')then
  local function look(v)
   local n,yellow,mesh,visible=0,0,0,0
   for _,d in ipairs(v:GetDescendants())do if d:IsA('BasePart')then n+=1;if d:IsA('MeshPart')then mesh+=1 end;if d.Transparency<1 then visible+=1;if colorIs(d.Color,255,255,0)and d.Material.Name=='SmoothPlastic'then yellow+=1 end end end end
   return n,yellow,mesh,visible
  end
  local n,yellow,mesh,visible=look(v1)
  check(mesh==0 and yellow==visible and visible==n and n==EXPECT-1,('the hotbar / Bag picture of the Verity pack: %d parts (the invisible root is left out), every one pure yellow, no mesh (%d/%d)'):format(n,yellow,visible))
  local ds=decalsOf(v1);local okD=#ds==2
  for _,d in ipairs(ds)do if d.Texture~=IMAGE or d.Parent.Name~='VerityFace'or d.Transparency~=0 then okD=false end end
  check(okD and ds[1].Face~=ds[2].Face,'the picture shows both Decals of Verity\'s face (Decals render in a ViewportFrame; SurfaceGuis do not)')
  local _,_,_,gv=look(v2);local gd=decalsOf(v2)
  check(gv>0 and #gd==2 and colorIs(gd[1].Color3,255,255,255)and colorIs(gd[2].Color3,255,255,255),'a Gold Verity picture keeps both white Decals on the face')
  local Pic=W.module('HarvestGeometry')
  local c1,s1=Pic.Bounds(v1:GetChildren()[2]or v1);local c2,s2=Pic.Bounds(v3:GetChildren()[2]or v3)
  check(s1.X>0 and s1.Y>0 and s1.X<=s2.X*1.02 and s1.Y<=s2.Y*1.15,('the picture is framed like a plain pack\'s ('..string.format('%.2f x %.2f',s1.X,s1.Y)..' vs '..string.format('%.2f x %.2f',s2.X,s2.Y)..')'))
 end
end
-- a missing template: the pack still builds (the default pouch)
do
 local bag=Visuals.Bag(CF(0,0,0),W.workspace,1,nil,7,VERITY,1,1,'None');bag:SetAttribute('VerityPack',nil)
 for _,d in ipairs(bag:GetChildren())do if d.Name=='PackGeometry'then d:Destroy()end end
 bag:SetAttribute('PackArtKey','Missing_99');bag:SetAttribute('CompactPackReady',nil)
 local ok,err=pcall(VerityArt.Build,bag,function()return true end)
 check(ok and err==true and bag:FindFirstChild('VerityFace',true)~=nil,'a design without a template still builds the pack: '..tostring(err))
 local gone=pcall(VerityArt.Build,bag,function()return false end)
 check(gone==true,'(and an invalidated build returns false without a pack)')
 bag:Destroy()
 local bag2=Visuals.Bag(CF(0,0,0),W.workspace,1,nil,7,VERITY,1,1,'None');local count=#bag2:GetDescendants()
 check(VerityArt.Build(bag2,function()return true end)==true and #bag2:GetDescendants()==count,'building twice adds nothing (VerityPack flag)')
 bag2:Destroy()
end
print(('Verity pack: %d built packs inspected in every context (face block %.3f x %.3f studs at scale 1, %d parts + root)'):format(contexts,meta.Face,meta.Face,#specs))

-- 4. No effects ---------------------------------------------------------------------------------------------------------------------------
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local remote=R.new('RemoteEvent');remote.Name='VeiledArrival81';remote._props.OnClientEvent=R.signal();remote.Parent=remotes
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
W.stub('NoticeFeed83',{Push=function()end})
W.stub('VeiledArrivalFx',{Preload=function()end,Arrive=function()end,Stop=function()end})
do
 local cam=W.workspace.CurrentCamera;cam.CFrame=CF(0,10,0)
 local verity=Visuals.Bag(CF(0,10,0),W.workspace,1,nil,7,VERITY,1,1,'None');local void=Visuals.Bag(CF(0,10,0),W.workspace,1,nil,7,VOID,1,1,'None')
 local gold=Visuals.Bag(CF(0,10,0),W.workspace,1,nil,7,VERITY,1,1,'Gold')
 for _,p in ipairs({verity,void,gold})do p:SetAttribute('WorldPack',false)end
 check(PackFx.PaletteFor(verity)==PackFx.Void and PackFx.PaletteFor(void)==PackFx.Void and boundsLine(PackFx.Void)==boundsLine(PackFxBase.Void),'VoidPackFx has only the Void set (and it is the base\'s)')
 check(PackFx.Capture(verity)~=nil and PackFx.Capture(verity).Palette==PackFx.Void,'(a captured Verity pack would take the Void set: nothing gold is left to pick)')
 local sc=R.new('LocalScript');sc.Name='VeiledEventClient81';W.load('VeiledEventClient81',sc)
 W.frames(20,1/30)
 local folders={};for _,f in ipairs(W.workspace:GetChildren())do if f.Name=='_VoidPackFx122'then folders[#folders+1]=f end end
 check(#folders==1,'the real VeiledEventClient81 loop: effects for the carried Void pack only ('..#folders..' effect set)')
 local h=folders[1]and folders[1]:FindFirstChild('VoidDistortion')
 check(h and h.Adornee==void and colorIs(h.OutlineColor,150,80,230),'(and it is the Void pack\'s, violet outline)')
 -- nothing anywhere in the workspace that belongs to a Verity pack: no emitter / light / highlight / beam
 local stray=0
 for _,d in ipairs(W.workspace:GetDescendants())do
  if d:IsA('Highlight')and(d.Adornee==verity or d.Adornee==gold)then stray+=1 end
  if(d:IsA('ParticleEmitter')or d:IsA('PointLight')or d:IsA('Beam')or d:IsA('Trail'))and(d:IsDescendantOf(verity)or d:IsDescendantOf(gold))then stray+=1 end
 end
 check(stray==0,'no highlight, emitter, light or beam on a Verity pack ('..stray..')')
 local lights=0;for _,f in ipairs(folders)do local core=f:FindFirstChild('VoidFxCore');local l=core and core:FindFirstChild('VoidPulseLight');if l and l.Enabled then lights+=1 end end
 check(lights<=1,'(at most the Void pack\'s one pulsing light in the scene)')
 -- a non-reliquary pack is never tracked
 local plain=Visuals.Bag(CF(0,10,0),W.workspace,1,nil,3,'Pack03',1,1,'None');plain:SetAttribute('WorldPack',false);W.frames(10,1/30)
 local n=0;for _,f in ipairs(W.workspace:GetChildren())do if f.Name=='_VoidPackFx122'then n+=1 end end
 check(n==1,'an ordinary pack gets no void effects either')
 plain:Destroy();void:Destroy();W.frames(5,1/30)
 n=0;for _,f in ipairs(W.workspace:GetChildren())do if f.Name=='_VoidPackFx122'then n+=1 end end
 check(n==0,'a destroyed Void pack releases its effects')
 sc.Destroying:Fire();verity:Destroy();gold:Destroy()
 check(W.B.VeiledEventClient81:find('VerityVariant',1,true)==nil and W.B.VeiledEventClient81:find('VerityPackArt',1,true)==nil and W.B.VoidPackFx:find('VerityPackArt',1,true)==nil and W.B.VoidPackFx:find('VerityCatalog',1,true)==nil,'(source: the effects owner and VoidPackFx no longer name the Verity pack)')
end
-- SeedPackRender (the generic rarity glints / aura): ordinary packs are tracked, the Void and the Verity pack are not.
do
 local function withAura(bag)local e=R.new('ParticleEmitter');e.Name='PackRarityAura';e.Enabled=true;e.Parent=bag;return e end
 local plain=Visuals.Bag(CF(0,10,0),W.workspace,1,nil,3,'Pack03',1,1,'None');local void=Visuals.Bag(CF(0,10,0),W.workspace,1,nil,7,VOID,1,1,'None');local verity=Visuals.Bag(CF(0,10,0),W.workspace,1,nil,7,VERITY,1,1,'None')
 local ep,ev,er=withAura(plain),withAura(void),withAura(verity)
 for _,b in ipairs({plain,void,verity})do b:SetAttribute('CompactPackReady',true)end
 local ok,err=pcall(function()local sc=R.new('LocalScript');sc.Name='SeedPackRender';W.load('SeedPackRender',sc)end)
 if check(ok,'the real SeedPackRender loads on the mock: '..tostring(err))then
  W.frames(30,1/30)
  check(ep.Enabled==false,'an ordinary pack is tracked (its aura emitter is taken over)')
  check(ev.Enabled==true and er.Enabled==true,'the Void pack and the Verity pack are left alone: no generic rarity glints / aura / highlight for the Verity pack')
  local hl=0;for _,d in ipairs(W.workspace:GetDescendants())do if d:IsA('Highlight')and d.Adornee==verity then hl+=1 end end
  check(hl==0,'no highlight was put on the Verity pack')
 end
 check(W.B.SeedPackRender:find("v=='EclipseReliquary'or v==VerityVariant then return end",1,true)~=nil,'(source: the early return names both reliquary variants)')
 for _,b in ipairs({plain,void,verity})do b:Destroy()end
end

-- 5. Everything that is not the Verity pack builds exactly what it did --------------------------------------------------------------------
do
 local compared,partsTotal,boundsSame=0,0,0
 local function bagAt(mod,stage,variant,size,coat)return mod.Bag(CF(0,10,0),W.workspace,1,nil,stage,variant,1,size,coat or'None')end
 local function both(stage,variant,size,coat)
  local okA,a=pcall(bagAt,Visuals,stage,variant,size,coat);local okB,b=pcall(bagAt,VisualsBase,stage,variant,size,coat)
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
 for _,v in ipairs({{7,VOID},{8,'MechLimited'},{3,'Pack03'}})do
  local a,b=pcall(Visuals.CarryBag,char,v[1],v[2],1,1,'None');local c,d=pcall(VisualsBase.CarryBag,char,v[1],v[2],1,1,'None')
  if check(a==c,v[2]..': CarryBag works the same before and after')and a then
   local same,why=sameFingerprint(fingerprint(b),fingerprint(d));check(same,v[2]..': the carried pack is identical before and after'..(why and('\n  '..why)or''))
   b:Destroy();d:Destroy()
  end
 end
 -- the Void effects (VoidPackFx) are the base's, byte for byte in what they build
 local voidBag=bagAt(Visuals,7,VOID,1,'None');voidBag:SetAttribute('WorldPack',false)
 for tier=1,3 do
  local a=PackFx.Capture(voidBag);PackFx.Create(a,tier);local b=PackFxBase.Capture(voidBag);PackFxBase.Create(b,tier)
  local da,db={},{};for _,d in ipairs(a.Fx.Folder:GetDescendants())do da[#da+1]=partLine(d)end;for _,d in ipairs(b.Fx.Folder:GetDescendants())do db[#db+1]=partLine(d)end
  local same,why=sameFingerprint(da,db);check(same and #da>5,('tier %d: the Void effects (%d objects, every property) are the base\'s'):format(tier,#da)..(why and('\n   '..why)or''))
  PackFx.Clear(a);PackFxBase.Clear(b)
 end
 voidBag:Destroy()
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
