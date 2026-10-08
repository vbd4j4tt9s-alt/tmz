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
-- R153 (owner: "at some points like the side of the garden bed players have to jump to pass it"). The wooden bed borders are walk-through
-- (WalkthroughProps90), but the soil beds are not: they stand 0.8 over the pad, and the rear bed 1.8 over the hub floor (it is flush with the pad's
-- three outer edges). The game's own runner sweep (RunnerSweep.Hull) steps over anything within 1.1 studs of the feet, so those 1.8 faces stopped a
-- runner until they jumped. Fix: every exposed soil face gets an invisible low ramp (a wedge from the outside surface up to the soil top, 2.5 studs of
-- run per stud of rise: a 22 degree slope). The soil itself, the borders, the plants and the planting frames are untouched. A ramp is a floor like the
-- pad and the soil (solid and queryable, so the Humanoid and the runner sweep both treat it as ground; not touchable), invisible, and lies wholly under
-- the soil's plane: a ray that ends on soil or on a plant (planting's "KEEP A CLEAR VIEW OF THE SOIL" check, digging, inspection) comes from above that
-- plane and never crosses one. They stand in Workspace.ChestChaseMap.GardenBedRamps153 (not under a base: WalkthroughProps90 would make them walk-through).
L.RampFolder='GardenBedRamps153'
L.Ramp={Slope=2.5,PadRun=2,MinLength=1.2,MinRise=.15,MinRun=1.5,RimMargin=1.2}
-- The ramps of one base, as {Name, Cf (world), Size} (pure: reads the pad and the plots).
function L.RampSpecs(base)
 local pad=base:FindFirstChild('Pad');local plots=base:FindFirstChild('GardenPlots');local out={}
 if not pad or not plots or not pad:IsA('BasePart')then return out end
 local cf=pad.CFrame;local hx,hy,hz=pad.Size.X/2,pad.Size.Y/2,pad.Size.Z/2;local R=L.Ramp
 local rects,faces={},{}
 for _,plot in ipairs(plots:GetChildren())do if plot:IsA('BasePart')and plot.CanCollide then
  local at=cf:PointToObjectSpace(plot.Position)
  table.insert(rects,{X0=rounded(at.X-plot.Size.X/2),X1=rounded(at.X+plot.Size.X/2),Z0=rounded(at.Z-plot.Size.Z/2),Z1=rounded(at.Z+plot.Size.Z/2),Top=rounded(at.Y+plot.Size.Y/2),Name=plot.Name})
 end end
 for _,r in ipairs(rects)do
  -- the four sides: axis (1 = X, 2 = Z), outward sign, the face's coordinate and its span along the other axis
  for _,side in ipairs({{1,-1,r.X0,r.Z0,r.Z1},{1,1,r.X1,r.Z0,r.Z1},{2,-1,r.Z0,r.X0,r.X1},{2,1,r.Z1,r.X0,r.X1}})do
   local axis,sign,c,a,b=side[1],side[2],side[3],side[4],side[5]
   local spans={{a,b}}
   for _,q in ipairs(rects)do if q~=r then -- a neighbour covering the face (touching it from outside) hides that part of it
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
   for _,s in ipairs(spans)do if s[2]-s[1]>=R.MinLength then
    local mid=(s[1]+s[2])/2
    local px,pz=c+sign*.05,mid;if axis==2 then px,pz=mid,c+sign*.05 end
    local inPad=math.abs(px)<hx-.02 and math.abs(pz)<hz-.02
    local ground=inPad and hy or -hy -- (local y of the surface just outside the face: the pad's top, or the hub floor under the pad)
    local rise=r.Top-ground
    if rise>=R.MinRise then
     local half=axis==1 and hx or hz
     local run=inPad and math.min(R.PadRun,sign>0 and half-c or c+half)or rise*R.Slope
     if run>=R.MinRun then table.insert(faces,{Axis=axis,Sign=sign,C=c,A=s[1],B=s[2],Ground=ground,Rise=rise,Run=run,OnPad=inPad})end
    end
   end end
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
 for i,f in ipairs(merged)do
  local axis,sign,c,run,rise,ground=f.Axis,f.Sign,f.C,f.Run,f.Rise,f.Ground
  -- the ramp runs `run` past each end of its face (mitred with its neighbour's at a corner: no uncovered diagonal); on the pad it stops RimMargin
  -- short of the pad's rim, so the rim's own 1.0 step and the ramp's height never add up
  local s0,s1=f.A-run,f.B+run
  if f.OnPad then local along=(axis==1 and hz or hx)-R.RimMargin;s0,s1=math.max(s0,-along),math.min(s1,along)end
  local len,mid=s1-s0,(s0+s1)/2;local d=run+.02 -- (.02 under the soil: no seam at the top)
  local centre=c+sign*(run/2-.01)
  local pos=axis==1 and Vector3.new(centre,ground+rise/2,mid)or Vector3.new(mid,ground+rise/2,centre)
  local back=axis==1 and Vector3.new(-sign,0,0)or Vector3.new(0,0,-sign) -- the tall end points at the soil
  local up=Vector3.new(0,1,0);local right=up:Cross(back)
  table.insert(out,{Name='Bed ramp '..(axis==1 and'X'or'Z')..(sign>0 and'+'or'-')..' '..i,Cf=cf*CFrame.fromMatrix(pos,right,up,back),Size=Vector3.new(len,rise,d),Rise=rise,Run=run,OnPad=f.OnPad})
 end
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
