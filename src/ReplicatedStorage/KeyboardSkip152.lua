-- R152 (owner: "for some areas on the track like this make sure that there is no keyboard tiles there": the Desert oasis, a shallow translucent pool, had keys inside and
-- under its water and a palm tree at its edge). Which cells of the keyboard grid (KeyboardTrack.Geometry) the keys leave out, found ONCE on the server in the finished
-- map (after TrackExpansion83 has moved every scenery group) and written to the map attribute KeyboardSkip (K.EncodeSkip): every client, key, letter and press then agrees,
-- and it does not depend on what the client has streamed in.
--   FLAT features = water / oasis / pond / pool / lava / magma / river / ice pond ... by part or group name (S.Config.Liquid), or Material Water, standing on the floor: a key
--      is left out when at least Flat (10%) of its footprint lies over one (a pool's edge is not covered by a half-key).
--   PROPS = any other scenery part standing on the floor high enough to meet a key (its top above the floor + PropMinTop, its foot no higher than the resting key top):
--      rocks, logs, roots, palm trunks and their stone bases, wall banks, cliffs, landmarks ... a key is left out only when it is mostly BURIED: at least Prop (60%) of its
--      footprint is covered. A partly covered key (a wall bank along the edge column) stays, poking into the prop as in R151, so the track edge shows no bare gaps.
-- Only scenery counts (the roots in S.Roots); floors, walls, barriers, bases, the hub, seeds, keepers and anything invisible do not. Footprint = the convex hull of the part's
-- projected box (a circle for a ball / a standing disc); coverage = a Grid x Grid sample of the key's footprint, the union over every feature. Spacebar rows are never touched.
local K=require(script.Parent.KeyboardTrack)
local S={}
S.Config={
 Flat=.10,Prop=.60,Grid=8,
 PropMinTop=.3,                  -- a prop's top must stand this far above the floor top to meet a key (a flush patch sits under the keys)
 InvisibleAt=.95,                -- parts at least this transparent (barriers, anchors) are not scenery
 MaxFootprint=60000,             -- bigger footprints (a whole-biome slab) are floors, not features
 Liquid={'water','oasis','pond','pool','lava','magma','molten','puddle','lake','river','stream','frozen','slush','quicksand','swamp','bog','sinkhole','crater','tar pit','mud'},
 -- Lower-case words: a part (or a model above it) whose name has one is never a feature. Empty by default: {'wall bank','rocky edge'} would also keep the edge keys the
 -- banks bury by 60% or more.
 Ignore={},
}
-- Roots under the map whose parts are scenery (a '/' walks down: Obby/Biomes).
S.Roots={'Obby/Biomes','EnvironmentPolishV127','MythicLandmarks','PresentationV128','RouteSceneryV134','SparseRouteSceneryV136'}

local function hasWord(list,name)
 name=string.lower(name)
 for _,w in ipairs(list)do if string.find(name,w,1,true)then return true end end
 return false
end
local function isLiquidName(name)return hasWord(S.Config.Liquid,name)end
-- Convex hull (monotone chain) of {x, z} points.
local function hull(pts)
 table.sort(pts,function(a,b)if a[1]~=b[1]then return a[1]<b[1]end;return a[2]<b[2]end)
 local function cross(o,a,b)return(a[1]-o[1])*(b[2]-o[2])-(a[2]-o[2])*(b[1]-o[1])end
 local lower={}
 for _,p in ipairs(pts)do
  while #lower>=2 and cross(lower[#lower-1],lower[#lower],p)<=1e-9 do lower[#lower]=nil end
  lower[#lower+1]=p
 end
 local upper={}
 for i=#pts,1,-1 do
  local p=pts[i]
  while #upper>=2 and cross(upper[#upper-1],upper[#upper],p)<=1e-9 do upper[#upper]=nil end
  upper[#upper+1]=p
 end
 lower[#lower]=nil;upper[#upper]=nil
 for _,p in ipairs(upper)do lower[#lower+1]=p end
 return lower
end
-- The footprint of a part: {Kind='poly', Pts, X0, X1, Z0, Z1, Y0, Y1} or {Kind='disc', X, Z, R, ...}; nil when it has no usable size.
function S.Footprint(part)
 local okC,cx,cy,cz,r00,r01,r02,r10,r11,r12,r20,r21,r22=pcall(function()return part.CFrame:GetComponents()end)
 if not okC then return nil end
 local size=part.Size;local sx,sy,sz=size.X/2,size.Y/2,size.Z/2
 if sx<=0 and sy<=0 and sz<=0 then return nil end
 local ey=math.abs(r10)*sx+math.abs(r11)*sy+math.abs(r12)*sz
 local fp={Y0=cy-ey,Y1=cy+ey}
 local okS,shape=pcall(function()return part.Shape.Name end) -- (a MeshPart has no Shape)
 shape=okS and tostring(shape)or''
 if shape:find('Ball',1,true)then
  local rad=math.max(sx,sy,sz);fp.Kind='disc';fp.X,fp.Z,fp.R=cx,cz,rad;fp.X0,fp.X1,fp.Z0,fp.Z1=cx-rad,cx+rad,cz-rad,cz+rad;return fp
 end
 if shape:find('Cylinder',1,true)and math.abs(r00)<.1 and math.abs(r10)>.9 then -- a standing disc: its axis (local X) points up
  local rad=math.max(sy,sz);fp.Kind='disc';fp.X,fp.Z,fp.R=cx,cz,rad;fp.X0,fp.X1,fp.Z0,fp.Z1=cx-rad,cx+rad,cz-rad,cz+rad;return fp
 end
 local pts={}
 for _,ax in ipairs({-1,1})do for _,ay in ipairs({-1,1})do for _,az in ipairs({-1,1})do
  local lx,ly,lz=ax*sx,ay*sy,az*sz
  pts[#pts+1]={cx+r00*lx+r01*ly+r02*lz,cz+r20*lx+r21*ly+r22*lz}
 end end end
 local h=hull(pts);if #h<3 then return nil end
 fp.Kind='poly';fp.Pts=h
 local x0,x1,z0,z1=math.huge,-math.huge,math.huge,-math.huge
 for _,p in ipairs(h)do x0=math.min(x0,p[1]);x1=math.max(x1,p[1]);z0=math.min(z0,p[2]);z1=math.max(z1,p[2])end
 fp.X0,fp.X1,fp.Z0,fp.Z1=x0,x1,z0,z1
 return fp
end
function S.Covers(fp,x,z)
 if fp.Kind=='disc'then local dx,dz=x-fp.X,z-fp.Z;return dx*dx+dz*dz<=fp.R*fp.R end
 local pts=fp.Pts;local n=#pts;local sign=0
 for i=1,n do
  local a,b=pts[i],pts[i%n+1]
  local c=(b[1]-a[1])*(z-a[2])-(b[2]-a[2])*(x-a[1])
  if c>1e-9 then if sign<0 then return false end;sign=1 elseif c<-1e-9 then if sign>0 then return false end;sign=-1 end
 end
 return true
end

local function find(root,path)
 for name in string.gmatch(path,'[^/]+')do root=root and root:FindFirstChild(name)end
 return root
end
-- Scenery parts under the roots: {Part, Group, Flat}. Group = the feature the part belongs to (the report's name): under Obby/Biomes the model two levels below the biome
-- (Small oasis), under another root its first two levels (IrregularMagmaPools/LavaPool_2_Irregular). Flat = the part or any model / folder above it has a liquid name.
local function sceneryParts(map)
 local out={}
 for _,rootPath in ipairs(S.Roots)do
  local root=find(map,rootPath)
  if root then
   for _,d in ipairs(root:GetDescendants())do
    if d:IsA('BasePart')and d.Transparency<S.Config.InvisibleAt and not d.Name:match('^BiomeGround_')and d.Name~='LeftBiomeEdge'and d.Name~='RightBiomeEdge'then
     local chain={};local a=d.Parent
     while a and a~=root do table.insert(chain,1,a.Name);a=a.Parent end
     local flat=isLiquidName(d.Name);local ignored=hasWord(S.Config.Ignore,d.Name)
     for _,n in ipairs(chain)do if isLiquidName(n)then flat=true end;if hasWord(S.Config.Ignore,n)then ignored=true end end
     local group
     if rootPath=='Obby/Biomes'then group=chain[3]or chain[#chain]or d.Name
     else group=chain[2]and(chain[1]..'/'..chain[2])or chain[1]or d.Name end
     local okM,mat=pcall(function()return d.Material end)
     if okM and mat==Enum.Material.Water then flat=true end
     if not ignored then out[#out+1]={Part=d,Group=group,Flat=flat}end
    end
   end
  end
 end
 return out
end

-- Scan(map, geo): the cells to leave out. geo = K.Geometry of the same map (without KeyboardSkip). Returns {Cells = set (row * 64 + col), Count, Report}.
-- Report[stage] = list of {Name, Class = 'flat' | 'prop', Cells} (cells credited to the first feature that covers them), Parts = scenery parts looked at.
function S.Scan(map,geo)
 local C=S.Config;local KC=K.Config
 local F=KC.FloorTop;local KW=K.KeySize(geo.Pitch);local G=C.Grid;local N=G*G;local WORDS=(N+31)//32
 local sampleX,sampleZ={}, {}
 for i=1,G do local o=((i-.5)/G-.5)*KW;sampleX[i]=o;sampleZ[i]=o end
 local flatMask,propMask={},{}      -- cell key -> the covered samples as a bit set of WORDS 32-bit words
 local flatBy,propBy={}, {}         -- cell key -> group name of the first feature that covered it
 local looked=0
 for _,item in ipairs(sceneryParts(map))do
  local fp=S.Footprint(item.Part)
  if fp and(fp.X1-fp.X0)*(fp.Z1-fp.Z0)<=C.MaxFootprint then
   local flat=item.Flat and fp.Y0<=F+1.0 and fp.Y1>=F-.5
   local prop=not item.Flat and fp.Y0<=K.KeyTop(0)and fp.Y1>=F+C.PropMinTop
   if flat or prop then
    looked+=1
    local c1,c2,r1,r2=geo.CellRange(fp.X0,fp.X1,fp.Z0,fp.Z1)
    local masks,by=flat and flatMask or propMask,flat and flatBy or propBy
    for r=r1,r2 do if not geo.BarOfRow[r]then
     local za,zb=geo.RowZ(r);local zc=(za+zb)/2
     for c=c1,c2 do
      local xc=geo.ColCenter(c);local key=r*64+c;local m=masks[key];local grew=false
      for i=1,G do for j=1,G do
       local bit=(i-1)*G+j-1;local w=bit//32+1;local flag=bit32.lshift(1,bit%32)
       if not(m and bit32.band(m[w],flag)~=0)and S.Covers(fp,xc+sampleX[i],zc+sampleZ[j])then
        if not m then m=table.create(WORDS,0);masks[key]=m end
        m[w]=bit32.bor(m[w],flag);grew=true
       end
      end end
      if grew and not by[key]then by[key]=item.Group end
     end
    end end
   end
  end
 end
 local function count(m)local n=0;for _,w in ipairs(m)do while w~=0 do n+=bit32.band(w,1);w=bit32.rshift(w,1)end end;return n end
 local cells,total={},0;local report={}
 local seen={}
 for key,m in pairs(flatMask)do
  if count(m)/N>=C.Flat then cells[key]=true;seen[key]='flat' end
 end
 for key,m in pairs(propMask)do
  if not cells[key]and count(m)/N>=C.Prop then cells[key]=true;seen[key]='prop' end
 end
 local perStage={}
 for key,class in pairs(seen)do
  total+=1
  local row=key//64;local stage=geo.RowStage[row]or 0
  local name=class=='flat'and flatBy[key]or propBy[key]or'?'
  local st=perStage[stage];if not st then st={};perStage[stage]=st end
  local id=class..'|'..name;local e=st[id];if not e then e={Name=name,Class=class,Cells=0};st[id]=e end
  e.Cells+=1
 end
 for stage,st in pairs(perStage)do
  local list={};for _,e in pairs(st)do list[#list+1]=e end
  table.sort(list,function(a,b)if a.Cells~=b.Cells then return a.Cells>b.Cells end;return a.Name<b.Name end)
  report[stage]=list
 end
 return{Cells=cells,Count=total,Report=report,Parts=looked}
end

-- Apply(map, centerX): scan the finished map and publish the cells as map.KeyboardSkip. Returns the scan.
function S.Apply(map,centerX)
 local attrs=map:GetAttributes();attrs.KeyboardSkip=nil
 local geo=K.Geometry(attrs,centerX)
 if geo.Rows<1 then map:SetAttribute('KeyboardSkip',K.EncodeSkip({},geo.Cols,0,geo.CenterX));return nil end
 local res=S.Scan(map,geo)
 map:SetAttribute('KeyboardSkip',K.EncodeSkip(res.Cells,geo.Cols,geo.Rows,geo.CenterX))
 print(string.format('[R152] keyboard: %d key cells left out for water / lava / pools / props (%d scenery parts looked at)',res.Count,res.Parts))
 return res
end
return S
