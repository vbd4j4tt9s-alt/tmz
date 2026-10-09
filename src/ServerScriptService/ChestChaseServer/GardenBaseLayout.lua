-- One static layout per base. Plot identities and planting frames are never moved.
local L={}
local function part(parent,name,size,frame,color,material,collide)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color;p.Material=material or Enum.Material.Wood;p.Anchored=true;p.CanCollide=collide==true;p.CanTouch=false;p.CanQuery=collide==true;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
local function rounded(n)return math.round(n*1000)/1000 end
local function add(lines,at,a,b)
 at=rounded(at);a=rounded(a);b=rounded(b);lines[at]=lines[at]or{};table.insert(lines[at],{a,b})
end
local function merge(lines)
 for at,spans in pairs(lines)do
  table.sort(spans,function(a,b)return a[1]<b[1]end);local out={}
  for _,s in ipairs(spans)do local last=out[#out]
   if last and s[1]<=last[2]+.002 then last[2]=math.max(last[2],s[2])else table.insert(out,{s[1],s[2]})end
  end
  lines[at]=out
 end
end
function L.Base(base)
 if base:FindFirstChild('GardenDesign36')then
  local fence=base:FindFirstChild('GardenFence34');require(script.Parent.GardenFenceArt).Build(base,fence and fence:GetAttribute('Tier')or 1);return
 end
 local pad=assert(base:FindFirstChild('Pad'),'Garden pad missing');local plots=assert(base:FindFirstChild('GardenPlots'),'Garden plots missing')
 local cf=pad.CFrame;local ground=pad.Size.Y/2;local top=ground
 -- Retire the old reserve, its rails and the earlier decorative layout together.
 for _,name in ipairs({'GardenLayout32','GardenDesign34','GardenBedBorders'})do local old=base:FindFirstChild(name);if old then old:Destroy()end end
 local design=Instance.new('Folder');design.Name='GardenDesign36';design.Parent=base
 local trim=Instance.new('Folder');trim.Name='GardenBedBorders';trim.Parent=base
 local rects={};local byPlot={}
 for _,plot in ipairs(plots:GetChildren())do if plot:IsA('BasePart')then
  local at=cf:PointToObjectSpace(plot.Position);local r={X0=rounded(at.X-plot.Size.X/2),X1=rounded(at.X+plot.Size.X/2),Z0=rounded(at.Z-plot.Size.Z/2),Z1=rounded(at.Z+plot.Size.Z/2)}
  top=math.max(top,at.Y+plot.Size.Y/2);table.insert(rects,r);byPlot[plot.Name]=r
 end end
 -- Finish the three-stud front-left recess at the same edge as the right bed.
 -- This is a visual infill; the saved plot and crop coordinates stay unchanged.
 local left,right=byPlot.DirtPlot_5,byPlot.DirtPlot_9
 if left and right and right.Z1>left.Z1+.01 then
  local source=plots.DirtPlot_5;local y=cf:PointToObjectSpace(source.Position).Y
  part(design,'Soil edge finish',Vector3.new(source.Size.X,source.Size.Y,right.Z1-left.Z1),cf*CFrame.new((left.X0+left.X1)/2,y,(left.Z1+right.Z1)/2),source.Color,source.Material,false)
  left.Z1=right.Z1
 end
 local hLines,vLines={},{}
 for _,r in ipairs(rects)do
  add(hLines,r.Z0,r.X0,r.X1);add(hLines,r.Z1,r.X0,r.X1)
  add(vLines,r.X0,r.Z0,r.Z1);add(vLines,r.X1,r.Z0,r.Z1)
 end
 merge(hLines);merge(vLines)
 local thickness=.6;local half=thickness/2;local bottom=ground-.04;local height=top+.22-bottom;local y=bottom+height/2
 local wood=Color3.fromRGB(145,109,69)
 for z,spans in pairs(hLines)do for _,s in ipairs(spans)do
  part(trim,'Bed divider',Vector3.new(s[2]-s[1]+thickness,height,thickness),cf*CFrame.new((s[1]+s[2])/2,y,z),wood)
 end end
 -- Vertical pieces stop at horizontal edges, producing flush corners without doubled top faces.
 for x,spans in pairs(vLines)do for _,s in ipairs(spans)do
  local pieces={{s[1],s[2]}}
  for z,rows in pairs(hLines)do for _,row in ipairs(rows)do if x>=row[1]-.001 and x<=row[2]+.001 then
   local nextPieces={}
   for _,p in ipairs(pieces)do
    if z+half<=p[1] or z-half>=p[2]then table.insert(nextPieces,p)
    else
     if z-half>p[1]+.001 then table.insert(nextPieces,{p[1],z-half})end
     if z+half<p[2]-.001 then table.insert(nextPieces,{z+half,p[2]})end
    end
   end
   pieces=nextPieces
  end end end
  for _,p in ipairs(pieces)do if p[2]-p[1]>.001 then
   part(trim,'Bed divider',Vector3.new(thickness,height,p[2]-p[1]),cf*CFrame.new(x,y,(p[1]+p[2])/2),wood)
  end end
 end end
 part(design,'Treadmill apron',Vector3.new(17,.18,22),cf*CFrame.new(-34,ground+.09,75),Color3.fromRGB(105,117,106),Enum.Material.Slate,false)
 for _,z in ipairs({81,69,55,40,25,10,-5,-20,-35,-49})do
  part(design,'Aisle paver',Vector3.new(17,.16,10),cf*CFrame.new(0,ground+.08,z),Color3.fromRGB(163,158,136),Enum.Material.Cobblestone,false)
 end
 require(script.Parent.GardenFenceArt).Build(base,1)
end
L.Design=L.Base
local function restoreExpandedHub(map)
 if not map:GetAttribute('GardenLayout32')then return end
 local amount=42
 for _,name in ipairs({'ChestChaseWalls','InvisibleMapBarriersV071','GardenHubDesign'})do
  local folder=map:FindFirstChild(name)
  if folder then for _,p in ipairs(folder:GetDescendants())do if p:IsA('BasePart')then
   local n=p.Name;local dx,dz=0,0;local x,z=p.Size.X,p.Size.Z
   if n:find('LobbyLeftWall',1,true)then dx=-amount;dz=-amount/2;z-=amount
   elseif n:find('LobbyRightWall',1,true)then dx=amount;dz=-amount/2;z-=amount
   elseif n:find('LobbyBackWall',1,true)then dz=-amount;x-=amount*2
   elseif n:find('LobbyFrontWallLeft',1,true)then dx=-amount/2;x-=amount
   elseif n:find('LobbyFrontWallRight',1,true)then dx=amount/2;x-=amount end
   if dx~=0 or dz~=0 then p.Size=Vector3.new(x,p.Size.Y,z);p.CFrame=CFrame.new(-dx,0,-dz)*p.CFrame end
  end end end
 end
 local lobby=map:FindFirstChild('Lobby');local floor=lobby and lobby:FindFirstChild('LobbyFloor')
 if floor then floor.Size-=Vector3.new(amount*2,0,amount);floor.CFrame=CFrame.new(0,0,amount/2)*floor.CFrame end
 map:SetAttribute('GardenLayout32',nil);map:SetAttribute('GardenDesign34',nil)
end
-- R153 (owner: "at some points like the side of the garden bed players have to jump to pass it"; then "these garden sides also have not been fixed and players cant
-- walk over them"). Every step the soil makes is a ledge to the Humanoid: the beds stand 0.8 over the pad (and the rim 1.0 over the hub floor, the rear bed
-- 1.8 over the floor: it is flush with the pad's three outer edges). The first R153 ramps only covered what stopped the runner sweep's hull (RunnerSweep.Hull
-- steps over 1.1 studs) and skipped the pad's 1.0-stud aprons beside the rows, so the 0.8 step to the soil stayed exactly where the fence stands: a player on the
-- apron could not walk onto the bed. Now the whole walkable skirt around every raised block (each soil bed AND the pad itself) is one continuous 22 degree slope
-- (2.5 studs of run per stud of rise): a wedge along every exposed face and a fan of 8 wedges at every convex corner (a cone, so a diagonal approach climbs too;
-- a straight wedge would end in a cliff beside the wall). The skirt is the soil's top minus 0.4 per stud of distance from the soil, on top of the pad and the
-- floor, so across a 1.0 apron and over the pad's rim it is one slope from the hub floor to the soil. The soil, the borders, the fence (walk-through, never
-- touched), the plants and the planting frames are untouched. A ramp is a floor like the pad and the soil (solid and queryable, so the Humanoid and the runner
-- sweep both treat it as ground; not touchable), invisible, and lies wholly under the soil's plane: a ray that ends on soil or on a plant (planting's "KEEP A
-- CLEAR VIEW OF THE SOIL" check, digging, inspection) comes from above that plane and never crosses one. They stand in Workspace.ChestChaseMap.GardenBedRamps153
-- (not under a base: WalkthroughProps90 would make them walk-through).
L.RampFolder='GardenBedRamps153'
L.Ramp={Slope=2.5,MinLength=.5,MinRise=.15,Blades=6,Overlap=1.15}
-- The ramps of one base, as {Name, Cf (world), Size} (pure: reads the pad and the plots).
function L.RampSpecs(base)
 local pad=base:FindFirstChild('Pad');local plots=base:FindFirstChild('GardenPlots');local out={}
 if not pad or not plots or not pad:IsA('BasePart')then return out end
 local cf=pad.CFrame;local hx,hy,hz=pad.Size.X/2,pad.Size.Y/2,pad.Size.Z/2;local R=L.Ramp
 local floorY=-hy -- (local y of the hub floor under the pad)
 local soil={}
 for _,plot in ipairs(plots:GetChildren())do if plot:IsA('BasePart')and plot.CanCollide then
  local at=cf:PointToObjectSpace(plot.Position)
  table.insert(soil,{X0=rounded(at.X-plot.Size.X/2),X1=rounded(at.X+plot.Size.X/2),Z0=rounded(at.Z-plot.Size.Z/2),Z1=rounded(at.Z+plot.Size.Z/2),Top=rounded(at.Y+plot.Size.Y/2),Name=plot.Name})
 end end
 local padRect={X0=-hx,X1=hx,Z0=-hz,Z1=hz,Top=hy,Name='Pad',Pad=true}
 local rects={padRect};for _,r in ipairs(soil)do table.insert(rects,r)end
 local faces={}
 for _,r in ipairs(rects)do
  local rise=r.Top-floorY
  -- the four sides: axis (1 = X, 2 = Z), outward sign, the face's coordinate and its span along the other axis
  for _,side in ipairs({{1,-1,r.X0,r.Z0,r.Z1},{1,1,r.X1,r.Z0,r.Z1},{2,-1,r.Z0,r.X0,r.X1},{2,1,r.Z1,r.X0,r.X1}})do
   local axis,sign,c,a,b=side[1],side[2],side[3],side[4],side[5]
   local spans={{a,b}}
   for _,q in ipairs(soil)do if q~=r then -- a bed covering the face (touching it from outside, or flush with the pad's rim) hides that part of it
    local lo,hi,qa,qb=q.X0,q.X1,q.Z0,q.Z1;if axis==2 then lo,hi,qa,qb=q.Z0,q.Z1,q.X0,q.X1 end
    if lo-.02<=c and c<=hi+.02 then
     local nextSpans={}
     for _,s in ipairs(spans)do
      if qb<=s[1]+.001 or qa>=s[2]-.001 then table.insert(nextSpans,s)
      else
       if qa>s[1]+.001 then table.insert(nextSpans,{s[1],qa})end
       if qb<s[2]-.001 then table.insert(nextSpans,{qb,s[2]})end
      end
     end
     spans=nextSpans
    end
   end end
   if rise>=R.MinRise then for _,s in ipairs(spans)do if s[2]-s[1]>=R.MinLength then
    table.insert(faces,{Axis=axis,Sign=sign,C=c,A=s[1],B=s[2],Rise=rise,Run=rise*R.Slope,Pad=r.Pad})
   end end end
  end
 end
 -- neighbouring faces on one line (a row of beds) become one ramp
 table.sort(faces,function(p,q)
  if p.Axis~=q.Axis then return p.Axis<q.Axis end;if p.Sign~=q.Sign then return p.Sign<q.Sign end
  if math.abs(p.C-q.C)>.02 then return p.C<q.C end;if p.Rise~=q.Rise then return p.Rise<q.Rise end;return p.A<q.A
 end)
 local merged={}
 for _,f in ipairs(faces)do
  local last=merged[#merged]
  if last and last.Axis==f.Axis and last.Sign==f.Sign and math.abs(last.C-f.C)<=.02 and math.abs(last.Rise-f.Rise)<.01 and f.A<=last.B+.02 then last.B=math.max(last.B,f.B)
  else table.insert(merged,table.clone(f))end
 end
 local up=Vector3.new(0,1,0)
 for i,f in ipairs(merged)do
  local axis,sign,c,run,rise=f.Axis,f.Sign,f.C,f.Run,f.Rise
  local len,mid=f.B-f.A,(f.A+f.B)/2;local d=run+.02 -- (.02 under the soil: no seam at the top)
  local centre=c+sign*(run/2-.01)
  local pos=axis==1 and Vector3.new(centre,floorY+rise/2,mid)or Vector3.new(mid,floorY+rise/2,centre)
  local back=axis==1 and Vector3.new(-sign,0,0)or Vector3.new(0,0,-sign) -- the tall end points at the soil
  table.insert(out,{Name=(f.Pad and'Pad ramp 'or'Bed ramp ')..(axis==1 and'X'or'Z')..(sign>0 and'+'or'-')..' '..i,Cf=cf*CFrame.fromMatrix(pos,up:Cross(back),up,back),Size=Vector3.new(len,rise,d),Rise=rise,Run=run,Face=true})
 end
 -- a convex corner (the block in exactly one of the four quadrants round it): a fan of wedges over the free quadrant, each rising toward the corner
 local seen={}
 local function solid(list,x,z)for _,q in ipairs(list)do if x>q.X0+.001 and x<q.X1-.001 and z>q.Z0+.001 and z<q.Z1-.001 then return true end end return false end
 local function corners(list,r)
  local rise=r.Top-floorY;local run=rise*R.Slope
  if rise<R.MinRise then return end
  for _,sx in ipairs({-1,1})do for _,sz in ipairs({-1,1})do
   local px,pz=sx<0 and r.X0 or r.X1,sz<0 and r.Z0 or r.Z1 -- (the free quadrant is the one on the (sx, sz) side)
   local n=0
   for _,qx in ipairs({-1,1})do for _,qz in ipairs({-1,1})do if solid(list,px+qx*.05,pz+qz*.05)then n+=1 end end end
   local key=string.format('%.2f,%.2f,%d,%d',px,pz,sx,sz)
   if n==1 and not seen[key]then
    seen[key]=true
    for k=0,R.Blades-1 do
     local th=(k+.5)*math.pi/2/R.Blades;local dx,dz=sx*math.cos(th),sz*math.sin(th)
     local wide=2*run*math.tan(math.pi/4/R.Blades)*R.Overlap
     local back=Vector3.new(-dx,0,-dz)
     table.insert(out,{Name=(r.Pad and'Pad corner 'or'Bed corner ')..#out,Cf=cf*CFrame.fromMatrix(Vector3.new(px+dx*(run/2-.01),floorY+rise/2,pz+dz*(run/2-.01)),up:Cross(back),up,back),
      Size=Vector3.new(wide,rise,run+.02),Rise=rise,Run=run,Corner=true})
    end
   end
  end end
 end
 for _,r in ipairs(soil)do corners(soil,r)end
 -- (a pad corner a bed already stands in is the bed's: the taller skirt covers it)
 for _,r in ipairs(rects)do if r.Pad then
  for _,sx in ipairs({-1,1})do for _,sz in ipairs({-1,1})do
   local px,pz=sx<0 and r.X0 or r.X1,sz<0 and r.Z0 or r.Z1
   for _,q in ipairs(soil)do if math.abs((sx<0 and q.X0 or q.X1)-px)<.02 and math.abs((sz<0 and q.Z0 or q.Z1)-pz)<.02 then seen[string.format('%.2f,%.2f,%d,%d',px,pz,sx,sz)]=true end end
  end end
  corners({r},r)
 end end
 return out
end
function L.Ramps(map)
 local old=map:FindFirstChild(L.RampFolder);if old then old:Destroy()end
 local folder=Instance.new('Model');folder.Name=L.RampFolder;folder.ModelStreamingMode=Enum.ModelStreamingMode.Persistent
 local n=0
 for _,base in ipairs(map.Bases:GetChildren())do if base:IsA('Model')and base:GetAttribute('BaseIndex')then
  for _,spec in ipairs(L.RampSpecs(base))do
   local p=Instance.new('WedgePart');p.Name=spec.Name;p.Size=spec.Size;p.CFrame=spec.Cf;p.Anchored=true;p.CanCollide=true;p.CanTouch=false;p.CanQuery=true
   p.Transparency=1;p.CastShadow=false;p.Material=Enum.Material.Plastic;p:SetAttribute('BaseIndex',base:GetAttribute('BaseIndex'));p.Parent=folder;n+=1
  end
 end end
 folder:SetAttribute('Ramps',n);folder.Parent=map
 return folder
end
function L.Apply(map)
 if not map:GetAttribute('GardenDesign36')then restoreExpandedHub(map)end
 for _,base in ipairs(assert(map:FindFirstChild('Bases'),'Bases missing'):GetChildren())do if base:IsA('Model')and base:GetAttribute('BaseIndex')then L.Base(base)end end
 map:SetAttribute('GardenDesign36',true)
 local ok,err=pcall(L.Ramps,map);if not ok then warn('[R153] Garden bed ramps skipped: '..tostring(err))end
end
return L
