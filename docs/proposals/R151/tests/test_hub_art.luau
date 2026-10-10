--!nocheck
-- R151 hub displays (rebuilt in R152): HubDisplayArt on the Roblox mock with the REAL game builders (SeedPackVisuals for seeds, HarvestPresentation / PlantVisuals for fruit, MarketLayout.Pedestal
-- for the look to match). The place's own layout against the map is check_hub_scene.py (the whole hub after the real start-up builders); this is the display alone:
--  1. the frame: just the market's Fruit of the Hour pedestal, bigger (same names, colours, shapes and proportions as MarketLayout.Pedestal x 3.2), and nothing else: NO sign board, posts,
--     slab, halo, disc, plinth for the avatar or tube, and (R153) no plaque: ONE big label (BillboardGui in studs, DistanceLowerLimit) with its five rows laid out by HubDisplayRules, over
--     the item; a handful of static parts, 4 of them solid;
--     everything inside the stand's footprint, inside the corner reserved for it (HubDecorKit151.Reserved) and clear of the hub's walls and the market, under the walls' height; no z-fighting
--     (no two same-facing faces within .02 stud where they overlap: the frame checked face by face);
--  2. the showcase item for EVERY seed of the game (54) and EVERY fruit of the rotation, plain and with Gold / Diamond coats: at most 150 parts, static anchored inert parts, no scripts or
--     emitters, scaled to about 12 studs, floating over the pedestal's prongs and under the label; an item over the cap is trimmed or built with the plant builder's simplified fruit; a
--     builder that fails gives a gem, never an empty display;
--  3. the effects are ON the item: an invisible core part inside it with the PointLight (the accent colour; off when calm), nothing in the frame lights or glows, nothing flat behind it;
--  4. the words: the label says the title, the winner, the seed / weight, the rarity and chance / the fruit of the day and the countdown; the empty state invites;
--  5. cost: the numbers of parts, lights, guis and emitters of a finished display.
local HH=require('./hub_harness');local H=HH.H;local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
-- the place's baked fruit meshes live in ServerStorage: stand-ins (one part each), as the other previews do
local Meshes=W.module('ApprovedPlantMeshes')
Meshes.Get=function(key)return {Clone=function()local p=R.new('MeshPart');p.Name=key;p.Size=V3(1,1,1);p:SetAttribute('ApprovedMesh',key);return p end}end
Meshes.Status=function()return 'Ready'end
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end
local rawWarn=W.env.warn;W.env.warn=function(msg,...)if tostring(msg):find('fruit meshes',1,true)then return end;rawWarn(msg,...)end -- (the mock cannot bake the R149 fruit meshes: the part-built fruit is the fallback, as on a server that cannot bake)
local Rules=W.module('HubDisplayRules');local P=W.module('SeedPackRules');local Catalog=W.module('PlantCatalog');local Kit=W.module('HubDecorKit151')
local Art=H.server('HubDisplayArt')
local list=Rules.EligibleFruits()
local CS=W.CS
local function all(root,class)local out={};for _,d in ipairs(root:GetDescendants())do if d:IsA(class)then out[#out+1]=d end end;return out end
local function parts(root)return all(root,'BasePart')end
local function isLight(x)return x._class=='PointLight'or x._class=='SpotLight'or x._class=='SurfaceLight'end
local function lightsIn(root)local out={};for _,x in ipairs(root:GetDescendants())do if isLight(x)then out[#out+1]=x end end;return out end

-- 1. The frame -----------------------------------------------------------------------------------------------------------------------------------------------------------
local holder=R.new('Folder');holder.Name='ChestChaseMap';holder.Parent=W.workspace
local pullD=Art.BuildFrame(holder,'Pull',Rules.Layout,4)
local fruitD=Art.BuildFrame(holder,'Fruit',Rules.Layout,4)
local function extentsOf(p)
 local c=p.CFrame;local s=p.Size;local r=c.R
 return V3((math.abs(r[1][1])*s.X+math.abs(r[1][2])*s.Y+math.abs(r[1][3])*s.Z)/2,(math.abs(r[2][1])*s.X+math.abs(r[2][2])*s.Y+math.abs(r[2][3])*s.Z)/2,(math.abs(r[3][1])*s.X+math.abs(r[3][2])*s.Y+math.abs(r[3][3])*s.Z)/2)
end
local function worldBox(model)
 local lo,hi
 for _,p in ipairs(parts(model))do
  local ex=extentsOf(p);local a,b=p.CFrame.Position-ex,p.CFrame.Position+ex
  lo=lo and V3(math.min(lo.X,a.X),math.min(lo.Y,a.Y),math.min(lo.Z,a.Z))or a
  hi=hi and V3(math.max(hi.X,b.X),math.max(hi.Y,b.Y),math.max(hi.Z,b.Z))or b
 end
 return lo,hi
end
local function toLocal(d,v)return d.F:PointToObjectSpace(v)end
local S=Art.Dim.Scale
do
 check(pullD.Model.Name=='BestPullDisplay'and fruitD.Model.Name=='BiggestFruitDisplay','two displays: BestPullDisplay and BiggestFruitDisplay')
 check(pullD.Model.ModelStreamingMode==R.Enum.ModelStreamingMode.Persistent and fruitD.Model.ModelStreamingMode==R.Enum.ModelStreamingMode.Persistent,'both models are Persistent (a landmark seen from afar: never streamed out and back as new instances)')
 check(CS:HasTag(pullD.Model,Rules.Tag)and CS:HasTag(fruitD.Model,Rules.Tag),'both carry the tag the client finds them by')
 check(pullD.Model:GetAttribute('Kind')=='Pull'and fruitD.Model:GetAttribute('Kind')=='Fruit'and pullD.Model:GetAttribute('HubDisplay')==Rules.Version and pullD.Model:GetAttribute('State')=='Empty','attributes: Kind, HubDisplay, State')
 local n=Art.Counts(pullD)
 check(n.Frame>=14 and n.Frame<=24 and n.Item==0 and n.Avatar==0,'the frame is '..n.Frame..' static parts (the item and the avatar come later; the old stage, sign board and posts were about 100)')
 -- NO board, no slab, no halo, no discs, no tube: only the pedestal
 local banned={'Sign board','Sign frame','Post','Post foot','Post collar','Post cap','Post gem','Crown band','Crown jewel','Apron','Stage','Stage skirt','Front step','Plinth','Plinth skirt','Plinth glow','Halo','ItemAnchor','Projector beam','Cradle glow'}
 local found={};for _,p in ipairs(parts(pullD.Model))do for _,b in ipairs(banned)do if p.Name==b then found[#found+1]=p.Name end end end
 check(#found==0,'no board, posts, stage slab, halo, plinth disc or tube: nothing but the pedestal ('..table.concat(found,',')..')')
 local see,round,neon=0,0,0
 for _,p in ipairs(parts(pullD.Model))do
  if p.Transparency>0 then see+=1 end
  if p.Shape==R.Enum.PartType.Cylinder or p.Shape==R.Enum.PartType.Ball then round+=1 end
  if p.Material==R.Enum.Material.Neon or p.Material==R.Enum.Material.Glass then neon+=1 end
 end
 check(see==0 and round==0 and neon==0,'every part is opaque, block-shaped and plain (no translucent tube, no round disc, no neon or glass plate)')
 local nonParts=0;for _,d in ipairs(pullD.Model:GetDescendants())do
  if not(d:IsA('BasePart')or d:IsA('Model')or d:IsA('Folder')or d:IsA('BillboardGui')or d:IsA('TextLabel'))then nonParts+=1;print('   unexpected '..d._class)end
 end
 check(nonParts==0,'the frame is parts and one gui with its text labels: no scripts, emitters, lights, joints or sounds')
 check(#all(pullD.Model,'SurfaceGui')==0 and #all(pullD.Model,'BillboardGui')==1 and #lightsIn(pullD.Model)==0 and #all(pullD.Model,'ParticleEmitter')==0 and #all(pullD.Model,'Script')==0,'R153: no plaque (no SurfaceGui), one label, no light, no emitters, no scripts')
 local plates=0;for _,p in ipairs(parts(pullD.Model))do if p.Name=='Pedestal plaque'then plates+=1 end end
 check(plates==0,'the plaque\'s plate is gone from the column')
 local bad=0;for _,p in ipairs(parts(pullD.Model))do if not p.Anchored or p.CanTouch then bad+=1 end end
 check(bad==0,'every part is anchored and untouchable')
 local solid={};local solids=0;for _,p in ipairs(parts(pullD.Model))do if p.CanCollide then solid[p.Name]=(solid[p.Name]or 0)+1;solids+=1;if not p.CanQuery then bad+=1 end elseif p.CanQuery then bad+=1 end end
 check(bad==0 and solids==4 and solid['Pedestal plinth']==1 and solid['Pedestal column']==1 and solid['Pedestal capital']==1 and solid['Capital top']==1,'solid: the plinth, the column, the capital and its top (and only those: queryable exactly when solid)')
 -- the same format and look as the Fruit of the Hour pedestal ------------------------------------------------------------------------------------------------
 local okM,Market=pcall(H.server,'MarketLayout')
 if check(okM and type(Market)=='table'and Market.Pedestal,'MarketLayout (the Fruit of the Hour pedestal\'s builder) is in the game') then
  local fold=R.new('Folder');fold.Parent=W.workspace
  local foh=Market.Pedestal(fold,CF(0,0,0));local base=Market.FruitOfHour
  local theirs={};for _,p in ipairs(parts(foh))do theirs[#theirs+1]={Name=p.Name,Size=p.Size,Pos=p.CFrame.Position-base,Color=p.Color}end
  local mine={};for _,p in ipairs(parts(pullD.Model.Pedestal))do local q=toLocal(pullD,p.CFrame.Position);mine[#mine+1]={Name=p.Name,Size=p.Size,Pos=V3(q.X-Art.Dim.Pedestal.X,q.Y,q.Z),Color=p.Color}end
  local skip={['Projector beam']=true,['Cradle glow']=true,['FruitAnchor']=true,['Pedestal plaque']=true} -- (R153: the words are on the big label; the market's own plaque says FRUIT OF THE HOUR)
  local missing,wrong,compared={},{},0
  for _,t in ipairs(theirs)do if not skip[t.Name]then
   local hit
   for _,m in ipairs(mine)do
    if m.Name==t.Name and not m.Used then
     local exact=near(m.Pos.X,t.Pos.X*S,.001)and near(m.Pos.Y,t.Pos.Y*S,.001)and near(m.Pos.Z,t.Pos.Z*S,.001)
     if exact then hit=m;break end
    end
   end
   if not hit then missing[#missing+1]=t.Name else
    hit.Used=true;compared+=1
    if not near(hit.Color.R,t.Color.R,1e-6)then wrong[#wrong+1]=t.Name..' colour'end
    if not(near(hit.Size.X,t.Size.X*S,.001)and near(hit.Size.Y,t.Size.Y*S,.001)and near(hit.Size.Z,t.Size.Z*S,.001))then wrong[#wrong+1]=t.Name..' size'end
   end
  end end
  check(#missing==0 and #wrong==0 and compared>=16,'every part of the Fruit of the Hour pedestal (except its projector tube, its flat cradle glow and, R153, its plaque) is there at 3.2 times the size, in the same place, size and colour: plinth, trim, studs, column, inlays, band, capital, top, prongs ('..compared..' compared; missing: '..table.concat(missing,',')..'; wrong: '..table.concat(wrong,',')..')')
  local used=0;for _,m in ipairs(mine)do if m.Used then used+=1 end end
  check(#mine-used==0,'and the pedestal has nothing of its own ('..(#mine-used)..' extra)')
  fold:Destroy()
 end
 -- where it stands
 local lo,hi=worldBox(pullD.Model)
 check(near(lo.Y,4,.001),'the pedestal stands on the floor (its lowest point is the hub floor, y 4)')
 local top=Art.CapitalTop()
 check(top>=15 and top<=17 and near(top,4.955*S,.001)and hi.Y-4>top and hi.Y-4<=Art.ItemBase(),'its top slab is '..string.format('%.1f',top)..' studs up (the market\'s 4.96 x 3.2) and the prongs\' tips reach '..string.format('%.1f',hi.Y-4)..', just under the item')
 local topY=-1e9;for _,p in ipairs(parts(pullD.Model))do if p.Name=='Capital top'then topY=toLocal(pullD,p.CFrame.Position).Y+p.Size.Y/2 end end
 check(near(topY,top,.01),'its top slab\'s top is at '..string.format('%.2f',top))
 local widest=0;for _,p in ipairs(parts(pullD.Model))do if p.Name=='Plinth trim'then widest=math.max(p.Size.X,p.Size.Z)end end
 check(widest>=19 and widest<=21,'its plinth is '..string.format('%.1f',widest)..' studs wide (a big landmark)')
 local look=pullD.F.LookVector
 local toTarget=(Rules.Layout.Target-pullD.F.Position);toTarget=V3(toTarget.X,0,toTarget.Z).Unit
 check(near(look.X,toTarget.X,1e-6)and near(look.Z,toTarget.Z,1e-6),'the display\'s front faces the market (the layout\'s target)')
 local fl=fruitD.F.LookVector;local ft=(Rules.Layout.Target-fruitD.F.Position);ft=V3(ft.X,0,ft.Z).Unit
 check(near(fl.X,ft.X,1e-6)and near(fl.Z,ft.Z,1e-6),'and so does the other')
 check(pullD.F.Position.X>0 and fruitD.F.Position.X<0 and near(pullD.F.Position.X,-fruitD.F.Position.X)and near(pullD.F.Position.Z,fruitD.F.Position.Z),'BEST PULL in the +X corner, BIGGEST FRUIT in the -X corner, mirror images')
 -- the label: everything the R152 plaque said, big, over the item
 local label=pullD.LabelGui;local LB=Rules.Label
 check(R.typeof(label)=='Instance'and label:IsA('BillboardGui')and label.Adornee~=nil and label.Adornee:IsA('BasePart')and label.Parent==label.Adornee and label.LightInfluence==0 and label.MaxDistance==LB.MaxDistance and label.AlwaysOnTop==false,'the label is a BillboardGui over the item, like the Fruit of the Hour\'s')
 check(near(label.Size.X.Scale,LB.W)and near(label.Size.Y.Scale,LB.H)and label.Size.X.Offset==0 and label.Size.Y.Offset==0,'sized in studs: '..LB.W..' x '..LB.H..' (it shrinks with distance like the world)')
 check(label.DistanceLowerLimit==LB.Near and LB.Near>0,'closer than '..LB.Near..' studs it stops growing (DistanceLowerLimit: never silly-large up close)')
 local lrows=0
 for i,key in ipairs(LB.Order)do
  local row=LB.Rows[key];local l=pullD.Tag[key]
  if l then lrows+=1
   check(near(l.Position.X.Scale,row.X/LB.W,1e-9)and near(l.Position.Y.Scale,row.Y/LB.H,1e-9)and near(l.Size.X.Scale,row.W/LB.W,1e-9)and near(l.Size.Y.Scale,row.H/LB.H,1e-9)and l.TextScaled and l.Font==R.Enum.Font.FredokaOne and l.Parent==label,'the label\'s "'..key..'" row sits in its box (scaled Fredoka One)')
  end
 end
 check(lrows==5 and pullD.Tag.Footer and pullD.Tag.Footer.Name=='Footer','five rows: title, winner, seed / weight, rarity and chance / fruit of the day, countdown (the client finds the countdown by the name Footer)')
 check(pullD.Tag.Name.Size.Y.Scale>pullD.Tag.Info.Size.Y.Scale and pullD.Tag.Title.Size.Y.Scale>pullD.Tag.Line.Size.Y.Scale and pullD.Tag.Line.Size.Y.Scale>pullD.Tag.Footer.Size.Y.Scale,'the winner and the title are the biggest rows')
 local foot=0;for _,d in ipairs(pullD.Model:GetDescendants())do if d.Name=='Footer'then foot+=1 end end
 check(foot==1,'one countdown in the display (the plaque\'s is gone)')
 -- the label floats above the item and about as high as the walls
 local labelBottom=Art.ItemBase()+Rules.ItemHeight+Art.Dim.LabelGap
 local offsetY=label.StudsOffsetWorldSpace.Y+4.78*S
 check(near(offsetY-LB.H/2,labelBottom,.01)and labelBottom>=Art.ItemBase()+Rules.ItemHeight+.6+.5 and labelBottom+LB.H<=48.01,'it hangs '..Art.Dim.LabelGap..' studs over the item\'s top (clear of its bob), its own top at '..string.format('%.1f',labelBottom+LB.H)..' (the hub\'s walls are 48)')
 check(near(label.StudsOffsetWorldSpace.X,0,1e-9)and near(label.StudsOffsetWorldSpace.Z,0,1e-9),'right over the item (the pedestal\'s top, where the item turns)')
 -- the stand's numbers
 local base=Art.ItemBase()
 check(base>Art.CapitalTop()+2 and base<=Art.CapitalTop()+7 and near(base,Art.Dim.ItemTop*S),'the item floats '..string.format('%.1f',base-Art.CapitalTop())..' studs over the pedestal\'s top, over the prongs\' tips')
 check(near(toLocal(pullD,pullD.FeetAt.Position).Y,0,1e-6)and near(toLocal(pullD,pullD.FeetAt.Position).X,Art.Dim.Avatar.X,1e-6)and Art.Dim.Avatar.X<0 and Art.Dim.Pedestal.X>0,'the avatar\'s soles are on the floor, beside the pedestal (to the viewers\' right of it)')
 check(near(toLocal(pullD,pullD.ItemAt.Position).Y,base,1e-6)and near(toLocal(pullD,pullD.ItemAt.Position).X,Art.Dim.Pedestal.X,1e-6),'the item\'s spot is over the pedestal')
end

-- 1b. The corner and the walls --------------------------------------------------------------------------------------------------------------------------------------------
do
 local zone=Kit.Reserved
 local function inZone(x,z,margin,mirrored)
  for _,r in ipairs(zone)do if x>=r.X0+margin and x<=r.X1-margin and z>=r.Z0+margin and z<=r.Z1-margin then return true end end
  return false
 end
 local L=Rules.Layout;local Fp=L.Footprint
 check(L.Corner.X0==zone[1].X0 and L.Corner.X1==zone[1].X1 and L.Corner.Z0==zone[1].Z0 and L.Corner.Z1==zone[1].Z1,'Layout.Corner is HubDecorKit151.K.Reserved\'s corner (x 145 .. 335, z -618 .. -420)')
 local worst=1e9
 for _,d in ipairs({pullD,fruitD})do
  -- the footprint rectangle (half sizes in the display's own frame) in the world: all four corners inside the reserved corner, with room to the walls
  for _,sx in ipairs({-1,1})do for _,sz in ipairs({-1,1})do
   local w=d.F*CF(sx*Fp.HalfX,0,sz*Fp.HalfZ).Position
   if not inZone(w.X,w.Z,0)then check(false,d.Kind..' footprint corner ('..string.format('%.0f, %.0f',w.X,w.Z)..') is outside the reserved corner')end
   local toWall=math.min(335-math.abs(w.X),w.Z+618);worst=math.min(worst,toWall)
  end end
  local lo,hi=worldBox(d.Model)
  check(inZone(lo.X,lo.Z,0)and inZone(hi.X,hi.Z,0)and inZone(lo.X,hi.Z,0)and inZone(hi.X,lo.Z,0),d.Kind..': every pedestal part is inside the reserved corner')
  -- the pedestal and the avatar's reach inside the footprint, in the display's own frame
  local inside=true
  for _,p in ipairs(parts(d.Model))do
   local c=d.F:ToObjectSpace(p.CFrame);local q=c.Position;local ex=extentsOf({CFrame=c,Size=p.Size})
   if math.abs(q.X)+ex.X>Fp.HalfX+.001 or math.abs(q.Z)+ex.Z>Fp.HalfZ+.001 then inside=false;print('   outside: '..p.Name)end
  end
  check(inside,d.Kind..': every part is inside the stand\'s '..(Fp.HalfX*2)..' x '..(Fp.HalfZ*2)..' footprint')
 end
 check(worst>=30,'the footprint stays at least 30 studs from the hub\'s walls ('..string.format('%.0f',worst)..')')
 -- the avatar's reach: the widest an R15 avatar gets with its arms out, scaled to AvatarHeight (shoulder 1.5 + arm 2.6 of 5.3 tall, x 4.7), from its spot, inside the footprint
 local reach=(1.5+2.6)*Rules.AvatarHeight/5.3
 check(math.abs(Art.Dim.Avatar.X)+reach<=Fp.HalfX and Art.Dim.Pedestal.X+9.9<=Fp.HalfX,'a dancing avatar\'s arms ('..string.format('%.1f',reach)..' studs out) and the pedestal fit the footprint\'s '..Fp.HalfX..' studs each side')
 check(Rules.Layout.Pull.Center.X>0 and Rules.Layout.Fruit.Center.X<0 and near(Rules.Layout.Pull.Center.X,-Rules.Layout.Fruit.Center.X),'the two stands are mirrored')
end

-- 1c. No z-fighting: every pair of faces that point the same way, lie within .02 stud of one plane and overlap ------------------------------------------------------------
-- (yaw-only parts, which is all of them but the four prongs, whose slanted faces are tiny and meet nothing flat; a face is a rectangle: centre, two tangents and half sizes)
local function faces(p,d)
 local c=d.F:ToObjectSpace(p.CFrame);local r=c.R
 -- the part's own axes in the display's frame; it must be yaw-only (its Y axis stays up)
 if math.abs(r[2][2])<.9999 then return nil end
 local ax=V3(r[1][1],r[2][1],r[3][1]);local ay=V3(r[1][2],r[2][2],r[3][2]);local az=V3(r[1][3],r[2][3],r[3][3])
 local half={p.Size.X/2,p.Size.Y/2,p.Size.Z/2};local axes={ax,ay,az}
 local out={}
 for i=1,3 do for _,sign in ipairs({-1,1})do
  local n=axes[i]*sign
  local o=c.Position+n*half[i]
  local t1,t2,h1,h2
  if i==1 then t1,t2,h1,h2=ay,az,half[2],half[3]elseif i==2 then t1,t2,h1,h2=ax,az,half[1],half[3]else t1,t2,h1,h2=ax,ay,half[1],half[2]end
  out[#out+1]={N=n,O=o,T1=t1,T2=t2,H1=h1,H2=h2,Part=p}
 end end
 return out
end
local function corners(f,u,v)
 local out={}
 for _,s in ipairs({{-1,-1},{1,-1},{1,1},{-1,1}})do
  local q=f.O+f.T1*(s[1]*f.H1)+f.T2*(s[2]*f.H2)
  out[#out+1]={q:Dot(u),q:Dot(v)}
 end
 return out
end
local function clip(poly,a,b) -- Sutherland-Hodgman against the half plane left of a->b
 local out={}
 for i=1,#poly do
  local p,q=poly[i],poly[i%#poly+1]
  local sp=(b[1]-a[1])*(p[2]-a[2])-(b[2]-a[2])*(p[1]-a[1]);local sq=(b[1]-a[1])*(q[2]-a[2])-(b[2]-a[2])*(q[1]-a[1])
  if sp>=0 then out[#out+1]=p end
  if(sp>=0)~=(sq>=0)then local t=sp/(sp-sq);out[#out+1]={p[1]+(q[1]-p[1])*t,p[2]+(q[2]-p[2])*t}end
 end
 return out
end
local function area(poly)local a=0;for i=1,#poly do local p,q=poly[i],poly[i%#poly+1];a+=p[1]*q[2]-q[1]*p[2]end;return math.abs(a)/2 end
local function overlapArea(f,g)
 -- in the plane of f: any two perpendicular axes
 local u,v=f.T1,f.T2
 local A=corners(f,u,v);local B=corners(g,u,v)
 -- make B counter-clockwise for the clip
 local function ccw(poly)local s=0;for i=1,#poly do local p,q=poly[i],poly[i%#poly+1];s+=p[1]*q[2]-q[1]*p[2]end;if s<0 then local r={};for i=#poly,1,-1 do r[#r+1]=poly[i]end;return r end;return poly end
 A=ccw(A);B=ccw(B)
 local poly=A
 for i=1,#B do
  poly=clip(poly,B[i],B[i%#B+1]);if #poly==0 then return 0 end
 end
 return area(poly)
end
local function zfight(d)
 local found={};local fs={};local skipped=0
 for _,p in ipairs(parts(d.Model))do local f=faces(p,d);if f then for _,x in ipairs(f)do fs[#fs+1]=x end else skipped+=1 end end
 for i=1,#fs do for j=i+1,#fs do
  local a,b=fs[i],fs[j]
  if a.Part~=b.Part and a.N:Dot(b.N)>.99995 then
   local off=math.abs((b.O-a.O):Dot(a.N))
   if off<=.02 and overlapArea(a,b)>.02 then found[#found+1]=string.format('%s <-> %s (%.4f apart)',a.Part.Name,b.Part.Name,off)end
  end
 end end
 return found,#fs,skipped
end
do
 local found,nfaces,skipped=zfight(pullD)
 check(#found==0,'no z-fighting on the pedestal: no two same-facing faces within .02 stud overlap ('..table.concat(found,'; ')..')')
 check(nfaces>=12*6 and skipped==4,'(the check looked at '..nfaces..' faces; the '..skipped..' slanted prongs are left out)')
 -- the checker has teeth: a slab lying 0.01 stud above the plinth's top, and a flush plate on the column's front, both flicker
 local plinth;for _,p in ipairs(parts(pullD.Model))do if p.Name=='Pedestal plinth'then plinth=p end end
 local fake=R.new('Part');fake.Name='Fake';fake.Size=V3(5,.2,5);fake.Parent=pullD.Model.Pedestal
 fake.CFrame=plinth.CFrame*CF(0,plinth.Size.Y/2-.1+.01,0) -- (its top is .01 over the plinth's top)
 local f2=zfight(pullD)
 check(#f2>=1,'(the checker finds a slab whose top lies .01 over the plinth\'s top)')
 fake:Destroy()
 local plank=R.new('Part');plank.Name='Plank';plank.Size=V3(4,4,.5);plank.CFrame=pullD.F*CF(Art.Dim.Pedestal.X,2.2*S,-1.9*S+.25);plank.Parent=pullD.Model.Pedestal
 check(#zfight(pullD)>=1,'(and one flush with the column\'s front)')
 plank:Destroy()
 check(#zfight(pullD)==0,'(and finds nothing again once they are gone)')
 local found2=zfight(fruitD)
 check(#found2==0,'the other display too')
end

-- 2. The showcase item ---------------------------------------------------------------------------------------------------------------------------------------------------
local function auditItem(d,model,info,label)
 local plist={};for _,p in ipairs(parts(model))do if p.Name~='ItemCore'then plist[#plist+1]=p end end
 local ok=true;local why=''
 local total=#parts(model)
 if #plist==0 or total>Rules.ItemParts then ok=false;why=why..' parts='..total end
 local anchored,inert,foreign=true,true,0
 for _,p in ipairs(parts(model))do
  if not p.Anchored then anchored=false end
  if p.CanCollide or p.CanTouch or p.CanQuery then inert=false end
 end
 for _,x in ipairs(model:GetDescendants())do
  if x:IsA('LuaSourceContainer')or x:IsA('ParticleEmitter')or x:IsA('Sound')or x:IsA('Attachment')or x:IsA('WeldConstraint')or x:IsA('BillboardGui')or x:IsA('SurfaceGui')then foreign+=1;why=why..' '..x._class
  elseif isLight(x)and not(x.Name=='Glow'and x.Parent and x.Parent.Name=='ItemCore')then foreign+=1;why=why..' stray light' end
 end
 local tags=true
 for _,x in ipairs(model:GetDescendants())do for _,t in ipairs(CS:GetTags(x))do if t~='GiantVisualPart'then tags=false;why=why..' tag '..t end end end
 for _,t in ipairs(CS:GetTags(model))do tags=false;why=why..' modeltag '..t end
 if not anchored then ok=false;why=why..' unanchored' end
 if not inert then ok=false;why=why..' not inert' end
 if foreign>0 then ok=false end
 if not tags then ok=false end
 -- the box in display-local space (the visible parts)
 local lo2=V3(1e9,1e9,1e9);local hi2=V3(-1e9,-1e9,-1e9)
 for _,p in ipairs(plist)do
  local c=d.F:ToObjectSpace(p.CFrame);local s=p:GetAttribute('ArtSize')or p.Size;local r=c.R
  local ex=V3((math.abs(r[1][1])*s.X+math.abs(r[1][2])*s.Y+math.abs(r[1][3])*s.Z)/2,(math.abs(r[2][1])*s.X+math.abs(r[2][2])*s.Y+math.abs(r[2][3])*s.Z)/2,(math.abs(r[3][1])*s.X+math.abs(r[3][2])*s.Y+math.abs(r[3][3])*s.Z)/2)
  local a,b=c.Position-ex,c.Position+ex
  lo2=V3(math.min(lo2.X,a.X),math.min(lo2.Y,a.Y),math.min(lo2.Z,a.Z));hi2=V3(math.max(hi2.X,b.X),math.max(hi2.Y,b.Y),math.max(hi2.Z,b.Z))
 end
 local a,b=lo2,hi2
 local height=b.Y-a.Y;local width=math.max(b.X-a.X,b.Z-a.Z)
 if height>Rules.ItemHeight+.6 or width>14.6 then ok=false;why=why..string.format(' size %.1f x %.1f',height,width)end
 if a.Y<Art.ItemBase()-.2 or a.Y>Art.ItemBase()+.6 then ok=false;why=why..string.format(' bottom %.2f (want %.2f)',a.Y,Art.ItemBase())end
 local cx=(a.X+b.X)/2;local cz=(a.Z+b.Z)/2
 if math.abs(cx-Art.Dim.Pedestal.X)>3.5 or math.abs(cz)>3.5 then ok=false;why=why..string.format(' off the pedestal (%.1f,%.1f)',cx-Art.Dim.Pedestal.X,cz)end
 if b.Y>Art.ItemBase()+Rules.ItemHeight+.6 then ok=false;why=why..string.format(' top %.1f reaches the label (%.1f)',b.Y,Art.ItemBase()+Rules.ItemHeight+Art.Dim.LabelGap)end
 -- the core: invisible, inert, at the item's centre, carrying the light
 local core=model:FindFirstChild('ItemCore')
 if not core or core.Transparency<1 or core.CanCollide or core.CanQuery or core.CanTouch or not core.Anchored then ok=false;why=why..' core'
 else
  local q=d.F:ToObjectSpace(core.CFrame).Position
  if math.abs(q.X-cx)>.5 or math.abs(q.Z-cz)>.5 or q.Y<a.Y or q.Y>b.Y then ok=false;why=why..' core off the item' end
  if #lightsIn(core)~=1 then ok=false;why=why..' light' end
 end
 return ok,why,height,width,total
end
do
 local seedOk,seedBad,minH,maxH,maxParts=0,{},1e9,0,0
 for _,spec in ipairs(P.SeedDesigns)do
  local model,info=Art.BuildItem(pullD,{Kind='Seed',Id=spec.id,Coat='None'})
  local ok,why,height,_,n=auditItem(pullD,model,info,spec.id)
  if ok and info.Source=='art'then seedOk+=1 else seedBad[#seedBad+1]=spec.id..':'..tostring(info.Source)..why end
  minH=math.min(minH,height);maxH=math.max(maxH,height);maxParts=math.max(maxParts,n)
  model:Destroy()
 end
 check(seedOk==#P.SeedDesigns,'all '..#P.SeedDesigns..' seeds of the game build a clean showcase item ('..table.concat(seedBad,'; ')..')')
 check(maxParts<=Rules.ItemParts,'the biggest seed model is '..maxParts..' parts (cap '..Rules.ItemParts..')')
 print(string.format('  (seed items are %.1f to %.1f studs tall, at most %d parts)',minH,maxH,maxParts))
 local fruitOk,fruitBad,fminH,fmaxH,fmaxParts=0,{},1e9,0,0
 for _,id in ipairs(list)do
  local model,info=Art.BuildItem(fruitD,{Kind='Fruit',Id=id,Coat='None'})
  local ok,why,height,width,n=auditItem(fruitD,model,info,id)
  if ok and info.Source=='art'then fruitOk+=1 else fruitBad[#fruitBad+1]=id..':'..tostring(info.Source)..why end
  fminH=math.min(fminH,height);fmaxH=math.max(fmaxH,height);fmaxParts=math.max(fmaxParts,n)
  model:Destroy()
 end
 check(fruitOk==#list,'all '..#list..' fruit of the rotation build a clean showcase item ('..table.concat(fruitBad,'; ')..')')
 print(string.format('  (fruit items are %.1f to %.1f studs tall, at most %d parts)',fminH,fmaxH,fmaxParts))
 check(fminH>=3,'even the flattest fruit stands at least 3 studs tall ('..string.format('%.1f',fminH)..')')
 check(fmaxH>=Rules.ItemHeight-1.5,'and the tallest about '..Rules.ItemHeight..' ('..string.format('%.1f',fmaxH)..')')
 -- coats
 for _,coat in ipairs({'Gold','Diamond'})do
  local model=Art.BuildItem(fruitD,{Kind='Fruit',Id='SunflowerSeed',Coat=coat})
  local material=coat=='Gold'and R.Enum.Material.Metal or R.Enum.Material.Glass
  local coated,total=0,0
  for _,p in ipairs(parts(model))do if p.Name~='ItemCore'then total+=1;if p.Material==material then coated+=1 end end end
  check(coated>=total*.5,'a '..coat..' fruit is coated ('..coated..' of '..total..' parts)')
  model:Destroy()
  local seed=Art.BuildItem(pullD,{Kind='Seed',Id='FirePepperSeed',Coat=coat})
  local c2=0;for _,p in ipairs(parts(seed))do if p.Material==material then c2+=1 end end
  check(c2>=1,'a '..coat..' seed is coated')
  seed:Destroy()
 end
 -- over the cap
 local model,info=Art.BuildItem(fruitD,{Kind='Fruit',Id='AmethystSeed',Coat='None'})
 check(info.Parts<=Rules.ItemParts,'the Amethyst Grape (718 parts as a plant, 163 as a harvested fruit) is cut to '..info.Parts..' parts (cap '..Rules.ItemParts..'; the detail it loses is the smallest parts)')
 model:Destroy()
 local geode,ginfo=Art.BuildItem(fruitD,{Kind='Fruit',Id='HollowGeodeSeed',Coat='None'})
 check(ginfo.Parts<=Rules.ItemParts,'so is the Hollow Geode ('..ginfo.Parts..' parts)')
 geode:Destroy()
 -- a mystery seed
 local mystery=Art.BuildItem(pullD,{Kind='Seed',Id='SunflowerSeed',Mystery=true,Calm=true})
 local dark=true;for _,p in ipairs(parts(mystery))do if p.Name~='ItemCore'and(p.Color.R>.1 or p.Color.G>.1 or p.Color.B>.15)then dark=false end end
 check(dark and #all(mystery,'Decal')==0,'the empty BEST PULL shows a black mystery seed')
 mystery:Destroy()
 -- on a display turned another way the item still stands over its pedestal and under the label
 local turned=Art.BuildFrame(holder,'Pull',{Target=V3(100,4,-300),Pull={Center=V3(-50,4,20)},Fruit={Center=V3(0,4,0)}},4)
 local m=Art.BuildItem(turned,{Kind='Seed',Id='FirePepperSeed',Coat='None'})
 local ok,why=auditItem(turned,m,{},'turned')
 check(ok,'on a display turned another way the item still floats over its pedestal'..why)
 m:Destroy();turned.Model:Destroy()
 -- a builder that fails gives a gem
 local Visuals=W.module('SeedPackVisuals');local rawSeed=Visuals.Seed
 Visuals.Seed=function()error('mesh library missing')end
 local gem,ginfo2=Art.BuildItem(pullD,{Kind='Seed',Id='FirePepperSeed',Coat='None',Accent={255,100,50}})
 check(ginfo2.Source=='gem'and #parts(gem)>=3,'when the seed builder fails the display gets a gem on a ring (never nothing)')
 gem:Destroy();Visuals.Seed=rawSeed
 local H2=W.module('HarvestPresentation');local rawBuild=H2.Build
 H2.Build=function()error('no meshes yet')end
 local gem2,ginfo3=Art.BuildItem(fruitD,{Kind='Fruit',Id='SunflowerSeed',Coat='None'})
 check(ginfo3.Source=='gem'and #parts(gem2)>=3,'and when the fruit builder fails')
 gem2:Destroy();H2.Build=rawBuild
 local none,ninfo=Art.BuildItem(fruitD,{Kind='Fruit',Id='NoSuchPlantSeed',Coat='None'})
 check(ninfo.Source=='gem','an unknown plant is a gem too (no error)')
 none:Destroy()
 -- placing
 local item=Art.BuildItem(pullD,{Kind='Seed',Id='FirePepperSeed',Coat='None'})
 Art.SetItem(pullD,item);check(item.Parent==pullD.ItemFolder and item.Name=='GiantItem'and item:GetAttribute('Spin')==true and item.ModelStreamingMode==R.Enum.ModelStreamingMode.Persistent,'the item goes in the display\'s Item slot')
 local item2=Art.BuildItem(pullD,{Kind='Seed',Id='AppleSeed',Coat='None'})
 Art.SetItem(pullD,item2);check(item.Parent==nil and #pullD.ItemFolder:GetChildren()==1,'a new item replaces the old one (no leftovers)')
 Art.SetItem(pullD,nil);check(#pullD.ItemFolder:GetChildren()==0,'nil empties the slot')
 local c=pullD.Model:GetAttribute('ItemCenter')
 check(R.typeof(c)=='Vector3'and near(toLocal(pullD,c).Y,Art.ItemBase()+Rules.ItemHeight/2,.01)and near(toLocal(pullD,c).X,Art.Dim.Pedestal.X,.01),'the display tells the client where the item\'s centre is (ItemCenter: over the pedestal)')
end

-- 3. The effects are on the item ---------------------------------------------------------------------------------------------------------------------------------------------
do
 local item=Art.BuildItem(pullD,{Kind='Seed',Id='FirePepperSeed',Coat='None',Accent={255,100,50}})
 Art.SetItem(pullD,item)
 local core=item:FindFirstChild('ItemCore');local light=core and core:FindFirstChildOfClass('PointLight')
 check(core and light and light.Name=='Glow'and light:IsDescendantOf(item)and light.Parent==core,'the item carries its own light: a PointLight on its ItemCore, inside the item')
 check(light.Enabled and near(light.Color.R,1,.01)and near(light.Color.G,100/255,.01)and light.Range>=30 and light.Range<=60 and light.Shadows==false,'in the accent colour, big enough for a 12 stud item, no shadows')
 check(core.Transparency==1 and not core.CanCollide and not core.CanQuery and core.Anchored,'the core itself is invisible, anchored and inert (it is not a disc or a plate)')
 local cs=core.Size
 check(cs.X<=Rules.ItemHeight and cs.Y<=Rules.ItemHeight and cs.Y>=Rules.ItemHeight*.4,'about 70% of the item\'s size: the sparkles the client adds spawn round the item')
 -- nothing outside the item glows or lights: no light in the frame, no neon, no halo
 local lights=0;for _,x in ipairs(pullD.Model:GetDescendants())do if isLight(x)and not x:IsDescendantOf(item)then lights+=1 end end
 check(lights==0,'and nothing else in the display is a light (no halo, no glow disc behind it)')
 -- Tint: the light follows the state; a calm display has it off
 Art.Tint(pullD,{40,200,90},'Ready')
 check(light.Enabled and near(light.Color.G,200/255,.01)and pullD.Model:GetAttribute('Calm')==false and pullD.Model:GetAttribute('Accent')~=nil,'Tint: the light wears the champion\'s colour (and the client reads it from Accent)')
 Art.Tint(pullD,{40,200,90},'Empty')
 check(light.Enabled==false and pullD.Model:GetAttribute('Calm')==true,'a calm display (nobody holds the spot): light off, Calm set (no sparkles)')
 local calm=Art.BuildItem(pullD,{Kind='Seed',Id='SunflowerSeed',Mystery=true,Calm=true})
 check(lightsIn(calm)[1].Enabled==false,'a calm item is built with its light off')
 calm:Destroy()
 Art.SetItem(pullD,nil)
end

-- 4. The words -----------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local text=Rules.SignText('Pull',nil,nil,462) -- (R153: BEST PULL's clock is a 10-minute window: 462 s left = "7:42")
 Art.SetSign(pullD,text)
 check(pullD.Plate==nil and pullD.Tag.Name.Text=='Nobody yet'and pullD.Model:GetAttribute('State')=='Empty','the empty BEST PULL says nobody yet')
 check(pullD.Tag.Line.Text:find('Open a pack',1,true)and pullD.Tag.Info.Text=='???'and pullD.Tag.Footer.Text=='new board in 7:42'and pullD.Tag.Title.Text=='BEST PULL','and invites the first pull, under the mystery seed, with the countdown (R153: "new board in 7:42")')
 local rec=Rules.CleanPull({Uid=1,Name='Jess',Id='FirePepperSeed',Seed='Fire Pepper',Rarity='Mythic',Odds=.125,Scale=1,At=5})
 local t2=Rules.SignText('Pull',rec,nil,462)
 Art.SetSign(pullD,t2)
 local want=R.Color3.fromRGB(t2.Accent[1],t2.Accent[2],t2.Accent[3])
 check(pullD.Tag.Title.Text=='BEST PULL'and pullD.Tag.Name.Text=='Jess'and pullD.Tag.Info.Text=='Fire Pepper'and pullD.Tag.Line.Text==t2.Label.Line.Text and pullD.Tag.Line.Text=='Mythic · 1/800'and pullD.Tag.Footer.Text=='new board in 7:42','the label says the title, the winner, the seed, the rarity and chance (HubDisplayRules\' own text) and the countdown')
 check(near(pullD.Tag.Info.TextColor3.R,want.R,.01)and near(pullD.Tag.Info.TextColor3.G,want.G,.01)and near(pullD.Tag.Line.TextColor3.R,want.R,.01),'the seed and its chance are in the rarity\'s colour')
 check(pullD.Model:GetAttribute('State')=='Champion','the model says Champion')
 -- the fruit board
 local f=Rules.CleanFruit({Uid=2,Name='Sam',Id='SunflowerSeed',Scale=2.5,Coat='Gold',At=5})
 local ft=Rules.SignText('Fruit',f,'SunflowerSeed',100,'Watermelon')
 Art.SetSign(fruitD,ft)
 check(fruitD.Tag.Title.Text=='BIGGEST FRUIT TODAY'and fruitD.Tag.Name.Text=='Sam'and fruitD.Tag.Info.Text==Rules.KgText(f.Kg)..' · Gold'and fruitD.Tag.Line.Text=='Today: 🍉 Watermelon'and fruitD.Tag.Footer.Text=='New fruit in 1m 40s','the fruit label: the title, the winner, the weight and the coat, the fruit of the day, the countdown')
 Art.SetSign(nil,ft)
 Art.SetSign(pullD,{Plaque={},Label={}});Art.SetSign(fruitD,nil)
 check(pullD.Tag.Title.Text==''and pullD.Tag.Name.Text==''and fruitD.Tag.Footer.Text=='','missing rows are blank (never an error)')
end

-- 5. Cost ---------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local item=Art.BuildItem(pullD,{Kind='Seed',Id='HoloAppleTreeSeed',Coat='None'}) -- (the biggest seed model)
 Art.SetItem(pullD,item)
 local avatar=HH.rig(10);avatar.Parent=pullD.AvatarFolder
 local n=Art.Counts(pullD)
 check(n.Frame+n.Item+n.Avatar<=230,'a finished display with the biggest seed and an avatar with 10 hats is '..(n.Frame+n.Item+n.Avatar)..' parts (frame '..n.Frame..', item '..n.Item..', avatar '..n.Avatar..'; the old one was up to 400)')
 check(#lightsIn(pullD.Model)==1 and #all(pullD.Model,'SurfaceGui')==0 and #all(pullD.Model,'BillboardGui')==1,'one light (the item\'s), one label, no plaque')
 check(#all(pullD.Model,'ParticleEmitter')==0,'no emitters on the server (the client adds sparkles to the item near the camera)')
 local fns=0;for k,v in pairs(Art)do if type(v)=='function'then fns+=1 end end
 check(next(Art.Dim)~=nil and fns>=8,'the art module is functions and constants (no connections, no state)')
 -- nothing happens over time
 local before=#parts(pullD.Model);for _=1,40 do R.advance(.5)end
 check(#parts(pullD.Model)==before,'nothing is added or removed over time')
end
print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('FAILED')end
